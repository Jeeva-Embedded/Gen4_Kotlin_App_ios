import SwiftUI
import Combine

// MARK: - Motor model

private struct PidMotor {
    let label: String
    let id: UInt8
}

private func pidMotors(for machine: String) -> [PidMotor] {
    switch machine {
    case "carding":
        return [
            PidMotor(label: "Cylinder",        id: 0x01),
            PidMotor(label: "Beater",          id: 0x02),
            PidMotor(label: "Cage",            id: 0x03),
            PidMotor(label: "Cylinder Feed",   id: 0x04),
            PidMotor(label: "Beater Feed",     id: 0x05),
            PidMotor(label: "Coiler",          id: 0x06),
            PidMotor(label: "Picker Cylinder", id: 0x07),
            PidMotor(label: "AF Feed",         id: 0x08),
        ]
    case "df":
        return [
            PidMotor(label: "Front Roller", id: 0x01),
            PidMotor(label: "Back Roller",  id: 0x02),
            PidMotor(label: "Creel",        id: 0x03),
        ]
    case "flyer":
        return [
            PidMotor(label: "Flyer",        id: 0x01),
            PidMotor(label: "Bobbin",       id: 0x02),
            PidMotor(label: "Front Roller", id: 0x03),
            PidMotor(label: "Back Roller",  id: 0x04),
        ]
    default:
        return [PidMotor(label: "Calender", id: 0x01)]
    }
}

// MARK: - ViewModel

private class PidViewModel: ObservableObject {
    @Published var kp: String = ""
    @Published var ki: String = ""
    @Published var ff: String = ""
    @Published var so: String = ""
    @Published var pidReceived = false
    @Published var pidSaved: Bool? = nil

    private let session: BtSessionManager
    private var cancellables = Set<AnyCancellable>()

    init(session: BtSessionManager) {
        self.session = session

        session.inboundFrames
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in
                guard frame.info == 0x0E, let self else { return }
                for tlv in frame.tlvs {
                    switch tlv.type {
                    case 0x02: self.kp = "\(tlv.valueAsUInt16())"
                    case 0x03: self.ki = "\(tlv.valueAsUInt16())"
                    case 0x04: self.ff = "\(tlv.valueAsUInt16())"
                    case 0x05: self.so = "\(tlv.valueAsUInt16())"
                    default: break
                    }
                }
                self.pidReceived = true
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    self?.pidReceived = false
                }
            }
            .store(in: &cancellables)

        session.saveResponse
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ok in
                guard let self else { return }
                self.pidSaved = ok
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    self?.pidSaved = nil
                }
            }
            .store(in: &cancellables)
    }

    func requestPid(motorId: UInt8) {
        session.sendFrame(FrameCodec.buildPidRequest(motorId: motorId))
    }

    func sendPid(motorId: UInt8) {
        guard let kpV = UInt16(kp), let kiV = UInt16(ki),
              let ffV = UInt16(ff), let soV = UInt16(so) else { return }
        let frame = FrameCodec.build(info: 0x0F, subState: 0x00, tlvs: [
            FrameCodec.buildTlvCompact(type: 0x01, value: motorId),
            FrameCodec.buildTlvInt(type: 0x02, value: kpV),
            FrameCodec.buildTlvInt(type: 0x03, value: kiV),
            FrameCodec.buildTlvInt(type: 0x04, value: ffV),
            FrameCodec.buildTlvInt(type: 0x05, value: soV),
        ])
        session.sendFrame(frame)
    }
}

// MARK: - PidView (sheet entry point)

struct PidView: View {
    let machine: String
    let session: BtSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var pinError = false
    @State private var unlocked = false

    var body: some View {
        NavigationView {
            Group {
                if unlocked {
                    PidContentView(machine: machine, session: session)
                } else {
                    PinGateView(pin: $pin, pinError: $pinError) {
                        if pin == "123456" { unlocked = true } else { pinError = true }
                    }
                }
            }
            .navigationTitle("PID Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - PIN gate

private struct PinGateView: View {
    @Binding var pin: String
    @Binding var pinError: Bool
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Enter PIN")
                .font(.title2).fontWeight(.semibold)
            SecureField("PIN", text: $pin)
                .keyboardType(.numberPad)
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(pinError ? Color.red : Color.gray, lineWidth: 1))
                .padding(.horizontal, 32)
            if pinError {
                Text("Incorrect PIN").font(.caption).foregroundColor(.red)
            }
            GradientButton(text: "Unlock", action: onUnlock)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

// MARK: - PID content

private struct PidContentView: View {
    let motors: [PidMotor]
    @StateObject private var vm: PidViewModel
    @State private var selectedIndex = 0

    init(machine: String, session: BtSessionManager) {
        self.motors = pidMotors(for: machine)
        _vm = StateObject(wrappedValue: PidViewModel(session: session))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 12) {
                    if motors.count > 1 {
                        Picker("Motor", selection: $selectedIndex) {
                            ForEach(motors.indices, id: \.self) { i in
                                Text(motors[i].label).tag(i)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .onChange(of: selectedIndex) { _ in
                            vm.kp = ""; vm.ki = ""; vm.ff = ""; vm.so = ""
                            vm.requestPid(motorId: motors[selectedIndex].id)
                        }
                    }

                    VStack(spacing: 8) {
                        FieldInput(label: "Kp",                value: $vm.kp)
                        FieldInput(label: "Ki",                value: $vm.ki)
                        FieldInput(label: "FF (Feed Forward)", value: $vm.ff)
                        FieldInput(label: "SO (Start Offset)", value: $vm.so)
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        GradientButton(text: "Request PID", action: {
                            vm.requestPid(motorId: motors[selectedIndex].id)
                        })
                        GradientButton(text: "Send PID", action: {
                            vm.sendPid(motorId: motors[selectedIndex].id)
                        })
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 80)
                }
                .padding(.top, 16)
            }

            if vm.pidReceived {
                SaveBanner(message: "PID received", success: true)
            } else if let saved = vm.pidSaved {
                SaveBanner(message: saved ? "PID saved successfully" : "PID save failed", success: saved)
            }
        }
        .onAppear {
            vm.requestPid(motorId: motors[selectedIndex].id)
        }
    }
}
