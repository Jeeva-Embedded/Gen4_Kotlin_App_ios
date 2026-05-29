import Foundation
import Combine

struct RingSettings {
    var inputYarn:          String = "30"
    var outputYarnDia:      String = ""   // blank = auto-computed from inputYarn
    var spindleSpeed:       String = "8000"
    var twistPerInch:       String = "20"
    var packageHeight:      String = "150"
    var diaBuildFactor:     String = "0.5"
    var windingCloseness:   String = "100"
    var windingOffsetCoils: String = "2"
}

struct RingRunState {
    var substate:    UInt8  = 0x00
    var weight:      Float  = 0     // doff percent
    var pauseReason: String = ""
    var errorSource: String = ""
    var errorReason: String = ""
}

struct RingDiagnosisState {
    var isDiagnosing: Bool   = false
    var motorLabel:   String = ""
    var rpm:          String = "-"
    var pwm:          String = "-"
    var current:      String = "-"
    var power:        String = "-"
}

class RingViewModel: ObservableObject {
    @Published var settings       = RingSettings()
    @Published var runState       = RingRunState()
    @Published var saveResult:    Bool? = nil
    @Published var readResult:    Bool? = nil
    @Published var carouselData:  [UInt8: [String: String]] = [:]
    @Published var diagnosisState = RingDiagnosisState()
    @Published var logEnabled:    Bool    = false
    @Published var logMessage:    String? = nil

    private let session: BtSessionManager
    private var cancellables = Set<AnyCancellable>()

    init(session: BtSessionManager) {
        self.session = session
        session.inboundFrames.receive(on: DispatchQueue.main)
            .sink { [weak self] f in self?.handleFrame(f) }.store(in: &cancellables)
        session.saveResponse.receive(on: DispatchQueue.main)
            .sink { [weak self] ok in self?.showSaveResult(ok) }.store(in: &cancellables)
    }

    private func handleFrame(_ frame: BtFrame) {
        switch frame.info {
        case 0x06:
            let ss = frame.subState
            var weight = runState.weight
            var pauseReason = ""; var errorSource = ""; var errorReason = ""
            for tlv in frame.tlvs {
                switch ss {
                case 0x01:
                    if tlv.type == RingProtocol.TLV_WEIGHT { weight = tlv.valueAsFloat() }
                case 0x02:
                    if tlv.type == 0x01 { pauseReason = ringPauseReason(Int(tlv.valueAsUInt16())) }
                case 0x03:
                    if tlv.type == 0x01 { errorReason = ringErrorReason(Int(tlv.valueAsUInt16())) }
                    if tlv.type == 0x02 { errorSource = ringErrorSource(Int(tlv.valueAsUInt16())) }
                default: break
                }
            }
            runState = RingRunState(substate: ss, weight: weight,
                                    pauseReason: pauseReason, errorSource: errorSource, errorReason: errorReason)

        case 0x07:
            var motorId: UInt8 = 0; var data: [String: String] = [:]
            for tlv in frame.tlvs {
                switch tlv.type {
                case RingProtocol.TLV_WHAT_INFO:   motorId          = tlv.valueAsUInt8()
                case RingProtocol.TLV_OUTPUT_MTRS: data["outputMtrs"] = String(format: "%.1f", tlv.valueAsFloat())
                case RingProtocol.TLV_TOTAL_POWER: data["totalPower"] = String(format: "%.1f", tlv.valueAsFloat())
                case RingProtocol.TLV_MOTOR_TEMP:  data["motorTemp"]  = "\(tlv.valueAsUInt16())"
                case RingProtocol.TLV_MOSFET_TEMP: data["mosfetTemp"] = "\(tlv.valueAsUInt16())"
                case RingProtocol.TLV_CURRENT:     data["current"]    = String(format: "%.2f", tlv.valueAsFloat())
                case RingProtocol.TLV_RPM:         data["rpm"]        = "\(tlv.valueAsUInt16())"
                default: break
                }
            }
            if motorId != 0 { carouselData[motorId] = data }

        case 0x02:
            var s = settings
            for tlv in frame.tlvs {
                switch tlv.type {
                case RingProtocol.TLV_INPUT_YARN:           s.inputYarn          = "\(tlv.valueAsUInt16())"
                case RingProtocol.TLV_OUTPUT_YARN_DIA:      s.outputYarnDia      = String(format: "%.3f", tlv.valueAsFloat())
                case RingProtocol.TLV_SPINDLE_SPEED:        s.spindleSpeed       = "\(tlv.valueAsUInt16())"
                case RingProtocol.TLV_TWIST_PER_INCH:       s.twistPerInch       = "\(tlv.valueAsUInt16())"
                case RingProtocol.TLV_PACKAGE_HEIGHT:       s.packageHeight      = "\(tlv.valueAsUInt16())"
                case RingProtocol.TLV_DIA_BUILD_FACTOR:     s.diaBuildFactor     = String(format: "%.2f", tlv.valueAsFloat())
                case RingProtocol.TLV_WINDING_CLOSENESS:    s.windingCloseness   = "\(tlv.valueAsUInt16())"
                case RingProtocol.TLV_WINDING_OFFSET_COILS: s.windingOffsetCoils = "\(tlv.valueAsUInt16())"
                default: break
                }
            }
            settings = s; showReadResult(true)

        case 0x05:
            guard diagnosisState.isDiagnosing else { break }
            var d = diagnosisState
            for tlv in frame.tlvs {
                switch tlv.type {
                case 0x01: d.rpm     = "\(tlv.valueAsUInt16())"
                case 0x02: d.pwm     = tlv.length == 0x04 ? "\(tlv.valueAsUInt16())" : String(format: "%.1f", tlv.valueAsFloat())
                case 0x03: d.current = String(format: "%.2f", tlv.valueAsFloat())
                case 0x04: d.power   = String(format: "%.1f", tlv.valueAsFloat())
                default: break
                }
            }
            diagnosisState = d

        default: break
        }
    }

    func updateSettings(_ s: RingSettings) {
        let inputChanged = s.inputYarn != settings.inputYarn
        if inputChanged && s.outputYarnDia.isEmpty, let iv = Int(s.inputYarn) {
            var updated = s
            updated.outputYarnDia = String(format: "%.3f", RingProtocol.calcOutputYarnDia(iv))
            settings = updated
        } else {
            settings = s
        }
    }

    func sendRead()  { session.sendFrame(FrameCodec.buildReqSettings()) }
    func sendSave()  {
        guard let iy  = Int(settings.inputYarn),
              let ss  = Int(settings.spindleSpeed),
              let tpi = Int(settings.twistPerInch),
              let ph  = Int(settings.packageHeight),
              let dbf = Float(settings.diaBuildFactor),
              let wc  = Int(settings.windingCloseness),
              let woc = Int(settings.windingOffsetCoils) else { return }
        let oyd: Float = settings.outputYarnDia.isEmpty
            ? RingProtocol.calcOutputYarnDia(iy)
            : (Float(settings.outputYarnDia) ?? RingProtocol.calcOutputYarnDia(iy))
        session.sendFrame(RingProtocol.buildSettingsFrame(
            inputYarn: iy, outputYarnDia: oyd, spindleSpeed: ss, twistPerInch: tpi,
            packageHeight: ph, diaBuildFactor: dbf, windingCloseness: wc, windingOffsetCoils: woc))
    }

    func sendResetGrams() { session.sendFrame(FrameCodec.build(info: 0x0A, subState: 0x00)) }
    func sendLog(enabled: Bool) {
        logEnabled = enabled
        session.sendFrame(FrameCodec.build(info: 0x0C, subState: enabled ? 0x01 : 0x00))
        Task { @MainActor in
            self.logMessage = enabled ? "Log Enabled" : "Log Disabled"
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.logMessage = nil
        }
    }
    func sendCarouselRequest(motorId: UInt8) { session.sendFrame(FrameCodec.buildCarouselRequest(motorId: motorId)) }
    func startDiagnosis(motorLabel: String)  { diagnosisState = RingDiagnosisState(isDiagnosing: true, motorLabel: motorLabel) }
    func clearDiagnosis()                    { diagnosisState = RingDiagnosisState() }
    func sendStopDiagnosis()                 { session.sendFrame(FrameCodec.build(info: 0x04, subState: 0x06)) }
    func sendDiagnostic(motorId: UInt8, controlType: UInt8, direction: UInt8, speedPct: Int, durationSec: Int, bedDistanceMm: Int? = nil) {
        session.sendFrame(FrameCodec.buildDiagnostic(motorId: motorId, controlType: controlType, direction: direction,
                                                      speedPct: UInt16(speedPct), durationSec: UInt16(durationSec),
                                                      bedDistanceMm: bedDistanceMm.map { UInt16($0) }))
    }
    func disconnect() { session.disconnect() }

    private func showReadResult(_ ok: Bool) {
        readResult = ok; Task { @MainActor in try? await Task.sleep(nanoseconds: 2_000_000_000); self.readResult = nil }
    }
    private func showSaveResult(_ ok: Bool) {
        saveResult = ok; Task { @MainActor in try? await Task.sleep(nanoseconds: 2_000_000_000); self.saveResult = nil }
    }

    private func ringPauseReason(_ c: Int) -> String {
        switch c { case 1: return "User Paused"; case 2: return "Creel Sliver Cut"; default: return "Unknown" }
    }
    private func ringErrorReason(_ c: Int) -> String {
        switch c {
        case 2: return "Over Current"; case 4: return "Over Voltage"; case 8: return "Under Voltage"
        case 16: return "Motor Thermistor Fault"; case 32: return "MOSFET Thermistor Fault"
        case 64: return "Motor Over Temperature"; case 96: return "SMPS Error"
        case 97: return "Ack Error"; case 98: return "Can Cut Error"
        case 99: return "Lift Relative Position Error"
        case 128: return "MOSFET Over Temperature"; case 256: return "EEPROM Write Error"
        case 512: return "EEPROM Bad Values"; case 1024: return "Tracking Error"
        case 2048: return "Motor Encoder Setup Error"; case 4096: return "Lift Pos Tracking Error"
        case 8192: return "Lift Synchronicity Fail"; case 16384: return "Lift Out Of Bounds Error"
        case 32768: return "EEPROM Bad Homing Position"; default: return "Unknown Error"
        }
    }
    private func ringErrorSource(_ c: Int) -> String {
        switch c {
        case 1: return "Calender"; case 2: return "Lift"
        case 8: return "Lift Left"; case 9: return "Lift Right"
        case 11: return "Mother Board"; case 12: return "Can Bus"
        case 13: return "Lifts"; case 14: return "System"
        default: return "Unknown"
        }
    }
}
