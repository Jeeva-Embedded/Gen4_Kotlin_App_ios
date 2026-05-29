import Foundation
import Combine

struct FlyerSettings {
    var spindleSpeed:    String = "650"
    var draft:           String = "8.8"
    var twistPerInch:    String = "1.4"
    var rtf:             String = "1.0"
    var layers:          String = "50"
    var maxHeight:       String = "270"
    var rovingWidth:     String = "1.2"
    var deltaBobbinDia:  String = "1.1"
    var bareBobbinDia:   String = "48"
    var rampUpTime:      String = "12"
    var rampDownTime:    String = "12"
    var changeLayerTime: String = "800"
    var coneAngleFactor: String = "1.0"
}

struct FlyerRunState {
    var substate:         UInt8  = 0x00
    var leftLift:         Float  = 0
    var rightLift:        Float  = 0
    var layers:           UInt16 = 0
    var pauseReason:      String = ""
    var pauseLayer:       UInt16 = 0
    var errorInformation: String = ""
    var errorCode:        String = ""
    var errorSource:      String = ""
    var errorLayer:       UInt16 = 0
    var frontCutCount:    Int    = 0
    var backCutCount:     Int    = 0
}

struct FlyerDiagnosisState {
    var isDiagnosing: Bool   = false
    var motorLabel:   String = ""
    var rpm:          String = "-"
    var pwm:          String = "-"
    var current:      String = "-"
    var power:        String = "-"
}

class FlyerViewModel: ObservableObject {
    @Published var settings       = FlyerSettings()
    @Published var runState       = FlyerRunState()
    @Published var saveResult:    Bool? = nil
    @Published var readResult:    Bool? = nil
    @Published var carouselData:  [UInt8: [String: String]] = [:]
    @Published var diagnosisState = FlyerDiagnosisState()
    @Published var gearboxLeft:   String = "-"
    @Published var gearboxRight:  String = "-"
    @Published var defaultApplied: Bool? = nil
    @Published var logEnabled:    Bool   = false
    @Published var logMessage:    String? = nil

    private let session: BtSessionManager
    private var cancellables = Set<AnyCancellable>()
    private var readPending = false

    init(session: BtSessionManager) {
        self.session = session
        session.inboundFrames
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in self?.handleFrame(frame) }
            .store(in: &cancellables)
        session.saveResponse
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ok in self?.showSaveResult(ok) }
            .store(in: &cancellables)
    }

    // MARK: - Frame handler

    private func handleFrame(_ frame: BtFrame) {
        switch frame.info {
        case 0x06:
            let ss = frame.subState
            var st = runState
            st.substate = ss
            var pauseReason = ""; var pauseLayer: UInt16 = 0
            var errorInfo   = ""; var errorCode = ""; var errorSource = ""; var errorLayer: UInt16 = 0
            var carouselMotorId: UInt8 = 0
            var carouselFields: [String: String] = [:]

            for tlv in frame.tlvs {
                switch tlv.type {
                case FlyerProtocol.TLV_WHAT_INFO:   carouselMotorId = tlv.valueAsUInt8()
                case FlyerProtocol.TLV_MOSFET_TEMP: carouselFields["mosfetTemp"] = "\(tlv.valueAsUInt16())"
                case FlyerProtocol.TLV_CURRENT:     carouselFields["current"]    = String(format: "%.2f", tlv.valueAsFloat())
                case FlyerProtocol.TLV_RPM:         carouselFields["rpm"]        = "\(tlv.valueAsUInt16())"
                case FlyerProtocol.TLV_OUTPUT_MTRS: carouselFields["outputMtrs"] = String(format: "%.1f", tlv.valueAsFloat())
                case FlyerProtocol.TLV_TOTAL_POWER: carouselFields["totalPower"] = String(format: "%.1f", tlv.valueAsFloat())
                case FlyerProtocol.TLV_LEFT_LIFT:
                    switch ss {
                    case 0x01, 0x04: st.leftLift   = tlv.valueAsFloat()
                    case 0x02:       pauseReason    = flyerPauseReason(Int(tlv.valueAsUInt16()))
                    case 0x03:       errorInfo      = flyerErrorReason(Int(tlv.valueAsUInt16()))
                    default: break
                    }
                case FlyerProtocol.TLV_RIGHT_LIFT:
                    switch ss {
                    case 0x01, 0x04: st.rightLift   = tlv.valueAsFloat()
                    case 0x02:       pauseLayer      = tlv.valueAsUInt16()
                    case 0x03:       errorSource     = flyerErrorSource(Int(tlv.valueAsUInt16()))
                    default: break
                    }
                case FlyerProtocol.TLV_RUN_LAYERS:
                    switch ss {
                    case 0x01: st.layers  = tlv.valueAsUInt16()
                    case 0x03: errorCode  = "\(tlv.valueAsUInt16())"
                    default: break
                    }
                case FlyerProtocol.TLV_MOTOR_TEMP:
                    if ss == 0x03 { errorLayer = tlv.valueAsUInt16() }
                    else          { carouselFields["motorTemp"] = "\(tlv.valueAsUInt16())" }
                case 0x0F: st.frontCutCount = Int(tlv.valueAsUInt16())
                case 0x10: st.backCutCount  = Int(tlv.valueAsUInt16())
                default: break
                }
            }
            st.pauseReason      = pauseReason
            st.pauseLayer       = pauseLayer
            st.errorInformation = errorInfo
            st.errorCode        = errorCode
            st.errorSource      = errorSource
            st.errorLayer       = errorLayer
            runState = st
            if carouselMotorId != 0 { carouselData[carouselMotorId] = carouselFields }

        case 0x02:
            var s = settings
            for tlv in frame.tlvs {
                switch tlv.type {
                case FlyerProtocol.TLV_SPINDLE_SPEED:     s.spindleSpeed    = "\(tlv.valueAsUInt16())"
                case FlyerProtocol.TLV_DRAFT:             s.draft           = String(format: "%.2f", tlv.valueAsFloat())
                case FlyerProtocol.TLV_TWIST_PER_INCH:   s.twistPerInch    = String(format: "%.2f", tlv.valueAsFloat())
                case FlyerProtocol.TLV_RTF:               s.rtf             = String(format: "%.2f", tlv.valueAsFloat())
                case FlyerProtocol.TLV_LAYERS:            s.layers          = "\(tlv.valueAsUInt16())"
                case FlyerProtocol.TLV_MAX_HEIGHT:        s.maxHeight       = "\(tlv.valueAsUInt16())"
                case FlyerProtocol.TLV_ROVING_WIDTH:      s.rovingWidth     = String(format: "%.2f", tlv.valueAsFloat())
                case FlyerProtocol.TLV_DELTA_BOBBIN_DIA:  s.deltaBobbinDia  = String(format: "%.2f", tlv.valueAsFloat())
                case FlyerProtocol.TLV_BARE_BOBBIN_DIA:   s.bareBobbinDia   = "\(tlv.valueAsUInt16())"
                case FlyerProtocol.TLV_RAMP_UP_TIME:      s.rampUpTime      = "\(tlv.valueAsUInt16())"
                case FlyerProtocol.TLV_RAMP_DOWN_TIME:    s.rampDownTime    = "\(tlv.valueAsUInt16())"
                case FlyerProtocol.TLV_CHANGE_LAYER_TIME: s.changeLayerTime = "\(tlv.valueAsUInt16())"
                case FlyerProtocol.TLV_CONE_ANGLE_FACTOR: s.coneAngleFactor = String(format: "%.2f", tlv.valueAsFloat())
                default: break
                }
            }
            settings = s
            readPending = false
            showReadResult(true)

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

        case 0x09:
            for tlv in frame.tlvs {
                switch tlv.type {
                case 0x01: gearboxLeft  = tlv.length == 0x04 ? "\(tlv.valueAsUInt16())" : String(format: "%.2f", tlv.valueAsFloat())
                case 0x02: gearboxRight = tlv.length == 0x04 ? "\(tlv.valueAsUInt16())" : String(format: "%.2f", tlv.valueAsFloat())
                default: break
                }
            }

        case 0x07:
            var motorId: UInt8 = 0
            var data: [String: String] = [:]
            for tlv in frame.tlvs {
                switch tlv.type {
                case FlyerProtocol.TLV_WHAT_INFO:   motorId             = tlv.valueAsUInt8()
                case FlyerProtocol.TLV_OUTPUT_MTRS: data["outputMtrs"]  = String(format: "%.1f", tlv.valueAsFloat())
                case FlyerProtocol.TLV_TOTAL_POWER: data["totalPower"]  = String(format: "%.1f", tlv.valueAsFloat())
                case FlyerProtocol.TLV_MOTOR_TEMP:  data["motorTemp"]   = "\(tlv.valueAsUInt16())"
                case FlyerProtocol.TLV_MOSFET_TEMP: data["mosfetTemp"]  = "\(tlv.valueAsUInt16())"
                case FlyerProtocol.TLV_CURRENT:     data["current"]     = String(format: "%.2f", tlv.valueAsFloat())
                case FlyerProtocol.TLV_RPM:         data["rpm"]         = "\(tlv.valueAsUInt16())"
                default: break
                }
            }
            if motorId != 0 { carouselData[motorId] = data }

        default: break
        }
    }

    // MARK: - Commands

    func sendRead() {
        readPending = true
        session.sendFrame(FrameCodec.buildReqSettings())
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.readPending { self.readPending = false; self.showReadResult(false) }
        }
    }

    func sendSave() {
        guard let frame = buildFrame() else { return }
        session.sendFrame(frame)
    }

    func resetToDefaults() {
        settings = FlyerSettings()
        Task { @MainActor in
            self.defaultApplied = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.defaultApplied = nil
        }
    }

    func sendDiagnostic(motorId: UInt8, controlType: UInt8, direction: UInt8, speedPct: Int, durationSec: Int, bedDistanceMm: Int? = nil) {
        session.sendFrame(FrameCodec.buildDiagnostic(
            motorId: motorId, controlType: controlType, direction: direction,
            speedPct: UInt16(speedPct), durationSec: UInt16(durationSec),
            bedDistanceMm: bedDistanceMm.map { UInt16($0) }
        ))
    }

    func startDiagnosis(motorLabel: String) { diagnosisState = FlyerDiagnosisState(isDiagnosing: true, motorLabel: motorLabel) }
    func clearDiagnosis()                   { diagnosisState = FlyerDiagnosisState() }
    func sendStopDiagnosis()                { session.sendFrame(FrameCodec.build(info: 0x04, subState: 0x06)) }
    func sendCarouselRequest(motorId: UInt8){ session.sendFrame(FrameCodec.buildCarouselRequest(motorId: motorId)) }
    func sendGearbox(_ substate: UInt8)     { session.sendFrame(FrameCodec.build(info: 0x08, subState: substate)) }
    func sendRtf(enabled: Bool)             { session.sendFrame(FrameCodec.build(info: 0x0B, subState: enabled ? 0x01 : 0x00)) }
    func sendResetCutCounts() {
        session.sendFrame(FrameCodec.build(info: 0x11, subState: 0x00))
        runState.frontCutCount = 0
        runState.backCutCount  = 0
    }

    func sendLog(enabled: Bool) {
        logEnabled = enabled
        session.sendFrame(FrameCodec.build(info: 0x0C, subState: enabled ? 0x01 : 0x00))
        Task { @MainActor in
            self.logMessage = enabled ? "Log Enabled" : "Log Disabled"
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.logMessage = nil
        }
    }

    func disconnect() { session.disconnect() }

    // MARK: - Helpers

    private func showReadResult(_ ok: Bool) {
        readResult = ok
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.readResult = nil
        }
    }

    private func showSaveResult(_ ok: Bool) {
        saveResult = ok
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.saveResult = nil
        }
    }

    private func buildFrame() -> String? {
        let s = settings
        guard let ss = Int(s.spindleSpeed),
              let dr = Float(s.draft),
              let tp = Float(s.twistPerInch),
              let rt = Float(s.rtf),
              let ly = Int(s.layers),
              let mh = Int(s.maxHeight),
              let rw = Float(s.rovingWidth),
              let dd = Float(s.deltaBobbinDia),
              let bd = Int(s.bareBobbinDia),
              let ru = Int(s.rampUpTime),
              let rd = Int(s.rampDownTime),
              let cl = Int(s.changeLayerTime),
              let ca = Float(s.coneAngleFactor) else { return nil }
        return FlyerProtocol.buildSettingsFrame(
            spindleSpeed: ss, draft: dr, twistPerInch: tp, rtf: rt,
            layers: ly, maxHeight: mh, rovingWidth: rw, deltaBobbinDia: dd,
            bareBobbinDia: bd, rampUpTime: ru, rampDownTime: rd,
            changeLayerTime: cl, coneAngleFactor: ca
        )
    }

    // MARK: - Decode tables

    private func flyerPauseReason(_ code: Int) -> String {
        switch code {
        case 1: return "User Paused"
        case 2: return "Front Sliver Cut"
        case 3: return "Back Sliver Cut"
        case 4: return "Lapping"
        default: return "Unknown"
        }
    }

    private func flyerErrorReason(_ code: Int) -> String {
        switch code {
        case 2:     return "Over Current"
        case 4:     return "Over Voltage"
        case 8:     return "Under Voltage"
        case 16:    return "Motor Thermistor Fault"
        case 32:    return "MOSFET Thermistor Fault"
        case 64:    return "Motor Over Temperature"
        case 96:    return "SMPS Error"
        case 97:    return "Ack Error"
        case 98:    return "Can Cut Error"
        case 99:    return "Lift Relative Position Error"
        case 128:   return "MOSFET Over Temperature"
        case 256:   return "EEPROM Write Error"
        case 512:   return "EEPROM Bad Values"
        case 1024:  return "Tracking Error"
        case 2048:  return "Motor Encoder Setup Error"
        case 4096:  return "Lift Pos Tracking Error"
        case 8192:  return "Lift Synchronicity Fail"
        case 16384: return "Lift Out Of Bounds Error"
        case 32768: return "EEPROM Bad Homing Position"
        default:    return "Unknown Error"
        }
    }

    private func flyerErrorSource(_ code: Int) -> String {
        switch code {
        case 1:  return "Flyer"
        case 2:  return "Bobbin"
        case 3:  return "FR"
        case 4:  return "BR"
        case 5:  return "Lift Left"
        case 6:  return "Lift Right"
        case 11: return "MotherBoard"
        case 12: return "Can Bus"
        case 13: return "Lifts"
        case 14: return "System"
        default: return "Unknown"
        }
    }
}
