import Foundation
import CoreBluetooth
import Combine

// MARK: - BLE UUIDs
// These must match the GATT service defined in the STM32 firmware.
// Nordic UART Service (NUS) — de facto standard for SPP-over-BLE.
private extension CBUUID {
    // Advertised service — used as scan filter so only Gen4 machines appear
    static let gen4Service = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    // RX characteristic — phone writes frames to device (write without response)
    static let rxWrite     = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    // TX characteristic — device sends frames to phone (notify)
    static let txNotify    = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
}

// MARK: - BtSessionManager

class BtSessionManager: NSObject, ObservableObject {

    // MARK: - Published state (same interface as ExternalAccessory version)

    @Published var connectionState: ConnectionState = .disconnected
    @Published var availablePeripherals: [CBPeripheral] = []

    // MARK: - Publishers consumed by every ViewModel

    let inboundFrames = PassthroughSubject<BtFrame, Never>()
    let saveResponse  = PassthroughSubject<Bool, Never>()

    // MARK: - Private BLE state

    private var central: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var rxChar: CBCharacteristic?   // phone → device
    private var txChar: CBCharacteristic?   // device → phone

    // MARK: - Private protocol state

    private var inputAccumulator = ""
    private var lastFrameTime: Date?
    private var watchdogTimer: Timer?
    private var isScanning = false

    // MARK: - Timeouts (match ExternalAccessory version)

    private let reconnectWarnTimeout: TimeInterval = 3
    private let reconnectLostTimeout: TimeInterval = 15

    // MARK: - Init

    override init() {
        super.init()
        // Queue: main — all callbacks land on main thread, safe for @Published
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API (same surface as ExternalAccessory version)

    /// Scan for Gen4 machines nearby. Call when the device list appears.
    func refreshAccessories() {
        guard central.state == .poweredOn else { return }
        availablePeripherals = []
        isScanning = true
        // Filter by service UUID so only Gen4 machines appear in the list
        central.scanForPeripherals(withServices: [.gen4Service],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        guard isScanning else { return }
        isScanning = false
        central.stopScan()
    }

    func connect(to peripheral: CBPeripheral) {
        guard case .disconnected = connectionState else { return }
        stopScan()
        let name = peripheral.name?.isEmpty == false ? peripheral.name! : peripheral.identifier.uuidString
        connectionState = .connecting(name: name)
        connectedPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let p = connectedPeripheral { central.cancelPeripheralConnection(p) }
        cleanup()
        connectionState = .disconnected
    }

    func reconnect() {
        guard case .lost(let name) = connectionState else { return }
        connectionState = .disconnected
        if let p = availablePeripherals.first(where: { ($0.name ?? "") == name }) {
            connect(to: p)
        } else {
            refreshAccessories()
        }
    }

    /// Send an ASCII-hex frame to the machine. Chunks automatically if frame > MTU.
    func sendFrame(_ hex: String) {
        guard let p = connectedPeripheral,
              let rx = rxChar,
              p.state == .connected,
              let data = hex.data(using: .ascii) else { return }

        let mtu = p.maximumWriteValueLength(for: .withoutResponse)
        var offset = data.startIndex
        while offset < data.endIndex {
            let end = data.index(offset, offsetBy: mtu, limitedBy: data.endIndex) ?? data.endIndex
            p.writeValue(data[offset..<end], for: rx, type: .withoutResponse)
            offset = end
        }
    }

    // MARK: - Frame accumulator (identical logic to ExternalAccessory version)

    private func processAccumulator() {
        let acc = inputAccumulator
        var searchFrom = acc.startIndex
        var consumed   = acc.startIndex

        while true {
            guard let sofRange = acc.range(of: "7E", range: searchFrom..<acc.endIndex) else {
                consumed = acc.endIndex; break
            }
            let sofIdx = sofRange.lowerBound

            // Save-response short frames ("7E017E" / "7E007E")
            if acc.distance(from: sofIdx, to: acc.endIndex) >= 6 {
                let six = String(acc[sofIdx..<acc.index(sofIdx, offsetBy: 6)])
                if six == SAVE_RESPONSE_SUCCESS {
                    saveResponse.send(true)
                    consumed = acc.index(sofIdx, offsetBy: 6); searchFrom = consumed; continue
                }
                if six == SAVE_RESPONSE_FAILURE {
                    saveResponse.send(false)
                    consumed = acc.index(sofIdx, offsetBy: 6); searchFrom = consumed; continue
                }
            }

            // Need SOF(2) + length(2) = 4 chars minimum
            guard acc.distance(from: sofIdx, to: acc.endIndex) >= 4 else { break }
            let lenStart = acc.index(sofIdx, offsetBy: 2)
            let lenEnd   = acc.index(sofIdx, offsetBy: 4)
            guard let length = Int(String(acc[lenStart..<lenEnd]), radix: 16) else {
                searchFrom = acc.index(sofIdx, offsetBy: 2); continue
            }
            guard acc.distance(from: sofIdx, to: acc.endIndex) >= 4 + length else { break }
            let frameEnd = acc.index(sofIdx, offsetBy: 4 + length)

            processRaw(String(acc[sofIdx..<frameEnd]))
            consumed   = frameEnd
            searchFrom = consumed
        }

        if consumed > acc.startIndex { inputAccumulator = String(acc[consumed...]) }
        if inputAccumulator.count > 1024 { inputAccumulator = "" }
    }

    private func processRaw(_ raw: String) {
        if raw.contains(FSC_CONNECT_STRING) { return }
        if raw.contains(FSC_DISCONN_STRING) { handleLinkLost(); return }
        if raw == SAVE_RESPONSE_SUCCESS { saveResponse.send(true); return }
        if raw == SAVE_RESPONSE_FAILURE { saveResponse.send(false); return }

        switch FrameCodec.parse(raw) {
        case .ok(let frame):
            lastFrameTime = Date()
            if case .reconnecting(let name) = connectionState {
                connectionState = .connected(name: name)
            }
            inboundFrames.send(frame)
        case .skip, .error:
            break
        }
    }

    // MARK: - Session lifecycle

    private func onFullyConnected(name: String) {
        connectionState = .connected(name: name)
        lastFrameTime = Date()
        startWatchdog(name: name)
        // Announce phone presence to machine
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.sendFrame(FrameCodec.buildPairedFromPhone())
        }
    }

    private func handleLinkLost() {
        let currentName: String
        switch connectionState {
        case .connected(let n), .reconnecting(let n), .connecting(let n): currentName = n
        default: cleanup(); return
        }
        cleanup()
        connectionState = .lost(name: currentName)
    }

    private func cleanup() {
        watchdogTimer?.invalidate(); watchdogTimer = nil
        connectedPeripheral?.delegate = nil
        connectedPeripheral = nil
        rxChar = nil
        txChar = nil
        inputAccumulator = ""
        lastFrameTime = nil
    }

    private func startWatchdog(name: String) {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let silence = -(self.lastFrameTime?.timeIntervalSinceNow ?? -999)
            switch self.connectionState {
            case .connected where silence > self.reconnectWarnTimeout:
                self.connectionState = .reconnecting(name: name)
                self.sendFrame(FrameCodec.buildPairedFromPhone())
            case .reconnecting where silence > self.reconnectLostTimeout:
                if let p = self.connectedPeripheral { self.central.cancelPeripheralConnection(p) }
                self.cleanup()
                self.connectionState = .lost(name: name)
            default: break
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BtSessionManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Auto-scan when BT turns on so device list is ready
            refreshAccessories()
        case .poweredOff, .unauthorized, .unsupported:
            cleanup()
            connectionState = .disconnected
            availablePeripherals = []
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        guard !availablePeripherals.contains(where: { $0.identifier == peripheral.identifier }) else { return }
        availablePeripherals.append(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Discover only our service to speed up the process
        peripheral.discoverServices([.gen4Service])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral, error: Error?) {
        cleanup()
        connectionState = .disconnected
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        handleLinkLost()
    }
}

// MARK: - CBPeripheralDelegate

extension BtSessionManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == .gen4Service }) else {
            cleanup(); connectionState = .disconnected; return
        }
        peripheral.discoverCharacteristics([.rxWrite, .txNotify], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { cleanup(); connectionState = .disconnected; return }

        for char in service.characteristics ?? [] {
            switch char.uuid {
            case .rxWrite:  rxChar = char
            case .txNotify: txChar = char; peripheral.setNotifyValue(true, for: char)
            default: break
            }
        }

        guard rxChar != nil, txChar != nil else {
            cleanup(); connectionState = .disconnected; return
        }

        let name = peripheral.name?.isEmpty == false ? peripheral.name! : peripheral.identifier.uuidString
        onFullyConnected(name: name)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == .txNotify,
              error == nil,
              let data = characteristic.value,
              let chunk = String(data: data, encoding: .ascii) else { return }
        inputAccumulator += chunk
        processAccumulator()
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Notification subscription confirmed — nothing extra needed
    }

    // Called when write-without-response buffer is ready for more data
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) { }
}
