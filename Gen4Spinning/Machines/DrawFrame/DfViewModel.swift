import Foundation
import Combine

struct DfSettings {
    var deliverySpeed:      String = "80"
    var draft:              String = "8.0"
    var lengthLimit:        String = "400"
    var rampUpTime:         String = "6"
    var rampDownTime:       String = "6"
    var creelTensionFactor: String = "1.0"
}

struct DfRunState {
    var substate:           UInt8  = 0x00
    var deliveryMtrsPerMin: Float  = 0
    var currentLength:      Float  = 0
    var alSensorActive:     Bool   = false
    var pauseReason:        String = ""
    var pauseLength:        Float  = 0
    var errorSource:        String = ""
    var errorReason:        String = ""
}

struct DfAlSettings {
    var kp:      String = ""
    var sliver6: String = ""
    var sliver5: String = ""
    var sliver4: String = ""
    var target:  String = ""
}

enum CalibrationStatus { case idle, collecting, done }

struct DfCalibrationState {
    var status:   CalibrationStatus = .idle
    var avgValue: Int = 0
    var count:    Int = 0
}

struct DfDiagnosisState {
    var isDiagnosing: Bool   = false
    var motorLabel:   String = ""
    var rpm:          String = "-"
    var pwm:          String = "-"
    var current:      String = "-"
    var power:        String = "-"
}

class DfViewModel: ObservableObject {
    @Published var settings        = DfSettings()
    @Published var runState        = DfRunState()
    @Published var alSettings      = DfAlSettings()
    @Published var calibrationState = DfCalibrationState()
    @Published var saveResult:     Bool? = nil
    @Published var readResult:     Bool? = nil
    @Published var alSaveResult:   Bool? = nil
    @Published var alReadResult:   Bool? = nil
    @Published var carouselData:   [UInt8: [String: String]] = [:]
    @Published var diagnosisState  = DfDiagnosisState()
    @Published var defaultApplied: Bool? = nil
    @Published var logEnabled:     Bool   = false
    @Published var logMessage:     String? = nil
    @Published var alEnabled:      Bool   = false
    @Published var alMessage:      String? = nil

    private let session: BtSessionManager
    private var cancellables = Set<AnyCancellable>()
    private var readPending    = false
    private var alGetPending   = false
    private var alSavePending  = false

    init(session: BtSessionManager) {
        self.session = session
        session.inboundFrames.receive(on: DispatchQueue.main)
            .sink { [weak self] f in self?.handleFrame(f) }.store(in: &cancellables)
        session.saveResponse.receive(on: DispatchQueue.main)
            .sink { [weak self] ok in self?.handleSaveResponse(ok) }.store(in: &cancellables)
    }

    private func handleFrame(_ frame: BtFrame) {
        switch frame.info {
        case 0x06:
            let ss = frame.subState
            var st = runState; st.substate = ss
            var pauseReason = ""; var pauseLength: Float = 0
            var errSrc = ""; var errReason = ""
            var carouselId: UInt8 = 0; var cf: [String: String] = [:]

            for tlv in frame.tlvs {
                switch tlv.type {
                case DfProtocol.TLV_WHAT_INFO:
                    carouselId = tlv.valueAsUInt8()
                case DfProtocol.TLV_RPM:
                    cf["rpm"]          = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_CURRENT:
                    cf["current"]      = String(format: "%.2f", tlv.valueAsFloat())
                case DfProtocol.TLV_MOTOR_TEMP:
                    cf["motorTemp"]    = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_MOSFET_TEMP:
                    cf["mosfetTemp"]   = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_OUTPUT_MTRS:
                    cf["outputMtrs"]   = String(format: "%.1f", tlv.valueAsFloat())
                case DfProtocol.TLV_TOTAL_POWER:
                    cf["totalPower"]   = String(format: "%.1f", tlv.valueAsFloat())
                case DfProtocol.TLV_DELIVERY_MTRS_PER_MIN:
                    st.deliveryMtrsPerMin = tlv.valueAsFloat()
                    cf["deliveryMtrsPerMin"] = String(format: "%.1f", tlv.valueAsFloat())
                case DfProtocol.TLV_CURRENT_LENGTH:
                    st.currentLength = tlv.valueAsFloat()
                    cf["currentLength"] = String(format: "%.1f", tlv.valueAsFloat())
                case DfProtocol.TLV_AL_SENSOR:
                    st.alSensorActive = tlv.valueAsUInt16() == 1
                case 0x01:
                    if ss == 0x02 { pauseReason = dfPauseReason(Int(tlv.valueAsUInt16())) }
                    if ss == 0x03 { errReason   = dfErrorReason(Int(tlv.valueAsUInt16())) }
                case 0x02:
                    if ss == 0x02 { pauseLength = tlv.valueAsFloat() }
                    if ss == 0x03 { errSrc      = dfErrorSource(Int(tlv.valueAsUInt16())) }
                default: break
                }
            }
            st.pauseReason = pauseReason; st.pauseLength = pauseLength
            st.errorSource = errSrc; st.errorReason = errReason
            runState = st
            if carouselId != 0 { carouselData[carouselId] = cf }

        case 0x02:
            var s = settings
            for tlv in frame.tlvs {
                switch tlv.type {
                case DfProtocol.TLV_DELIVERY_SPEED:       s.deliverySpeed      = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_DRAFT:                s.draft              = String(format: "%.2f", tlv.valueAsFloat())
                case DfProtocol.TLV_LENGTH_LIMIT:         s.lengthLimit        = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_RAMP_UP_TIME:         s.rampUpTime         = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_RAMP_DOWN_TIME:       s.rampDownTime       = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_CREEL_TENSION_FACTOR: s.creelTensionFactor = String(format: "%.2f", tlv.valueAsFloat())
                default: break
                }
            }
            settings = s; readPending = false; showReadResult(true)

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

        case 0x07:
            var motorId: UInt8 = 0; var data: [String: String] = [:]
            for tlv in frame.tlvs {
                switch tlv.type {
                case DfProtocol.TLV_WHAT_INFO:              motorId                      = tlv.valueAsUInt8()
                case DfProtocol.TLV_OUTPUT_MTRS:            data["outputMtrs"]           = String(format: "%.1f", tlv.valueAsFloat())
                case DfProtocol.TLV_TOTAL_POWER:            data["totalPower"]           = String(format: "%.1f", tlv.valueAsFloat())
                case DfProtocol.TLV_MOTOR_TEMP:             data["motorTemp"]            = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_MOSFET_TEMP:            data["mosfetTemp"]           = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_CURRENT:                data["current"]              = String(format: "%.2f", tlv.valueAsFloat())
                case DfProtocol.TLV_RPM:                    data["rpm"]                  = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_DELIVERY_MTRS_PER_MIN: data["deliveryMtrsPerMin"]   = String(format: "%.1f", tlv.valueAsFloat())
                case DfProtocol.TLV_CURRENT_LENGTH:         data["currentLength"]        = String(format: "%.1f", tlv.valueAsFloat())
                default: break
                }
            }
            if motorId != 0 { carouselData[motorId] = data }

        case DfProtocol.INFO_AL_RESPONSE:
            var al = alSettings
            for tlv in frame.tlvs {
                switch tlv.type {
                case DfProtocol.TLV_AL_KP:      al.kp      = String(format: "%.4f", tlv.valueAsFloat())
                case DfProtocol.TLV_AL_SLIVER6: al.sliver6 = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_AL_SLIVER5: al.sliver5 = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_AL_SLIVER4: al.sliver4 = "\(tlv.valueAsUInt16())"
                case DfProtocol.TLV_AL_TARGET:  al.target  = String(format: "%.2f", tlv.valueAsFloat())
                default: break
                }
            }
            alSettings = al
            if alGetPending {
                alGetPending = false
                showAlReadResult(true)
            } else if alSavePending {
                alSavePending = false
                showAlSaveResult(true)
            }

        case DfProtocol.INFO_CAL_RESULT:
            var avg = 0; var count = 0
            for tlv in frame.tlvs {
                switch tlv.type {
                case DfProtocol.TLV_CAL_AVG:   avg   = Int(tlv.valueAsUInt16())
                case DfProtocol.TLV_CAL_COUNT: count = Int(tlv.valueAsUInt16())
                default: break
                }
            }
            calibrationState = DfCalibrationState(status: .done, avgValue: avg, count: count)

        default: break
        }
    }

    private func handleSaveResponse(_ ok: Bool) {
        if alSavePending {
            alSavePending = false
            showAlSaveResult(ok)
        } else {
            showSaveResult(ok)
        }
    }

    func sendRead() {
        readPending = true; session.sendFrame(FrameCodec.buildReqSettings())
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.readPending { self.readPending = false; self.showReadResult(false) }
        }
    }

    func sendSave() {
        guard let ds = Int(settings.deliverySpeed),
              let dr = Float(settings.draft),
              let ll = Int(settings.lengthLimit),
              let ru = Int(settings.rampUpTime),
              let rd = Int(settings.rampDownTime),
              let ct = Float(settings.creelTensionFactor) else { return }
        session.sendFrame(DfProtocol.buildSettingsFrame(
            deliverySpeed: ds, draft: dr, lengthLimit: ll, rampUpTime: ru, rampDownTime: rd, creelTensionFactor: ct))
    }

    func resetToDefaults() {
        settings = DfSettings()
        Task { @MainActor in self.defaultApplied = true; try? await Task.sleep(nanoseconds: 2_000_000_000); self.defaultApplied = nil }
    }

    func sendAutoLeveller(enabled: Bool) {
        alEnabled = enabled
        session.sendFrame(FrameCodec.build(info: 0x16, subState: enabled ? 0x01 : 0x00))
        Task { @MainActor in
            self.alMessage = enabled ? "Auto Leveller Enabled" : "Auto Leveller Disabled"
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.alMessage = nil
        }
    }

    func sendAlGet() {
        alGetPending = true
        session.sendFrame(DfProtocol.buildAlGetFrame())
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.alGetPending { self.alGetPending = false; self.showAlReadResult(false) }
        }
    }

    func sendAlSave() -> Bool {
        guard let kp      = Float(alSettings.kp),
              let sliver6 = Int(alSettings.sliver6),
              let sliver5 = Int(alSettings.sliver5),
              let sliver4 = Int(alSettings.sliver4),
              let target  = Float(alSettings.target) else { return false }
        guard kp > 0 && kp <= 1 else { return false }
        guard sliver6 < sliver5 && sliver5 < sliver4 else { return false }
        guard target > 4 && target <= 6 else { return false }
        alSavePending = true
        session.sendFrame(DfProtocol.buildAlSaveFrame(kp: kp, sliver6: sliver6, sliver5: sliver5, sliver4: sliver4, target: target))
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.alSavePending { self.alSavePending = false; self.showAlSaveResult(false) }
        }
        return true
    }

    func sendCalibrationStart() {
        calibrationState = DfCalibrationState(status: .collecting)
        session.sendFrame(FrameCodec.build(info: 0x04, subState: 0x05))
    }

    func sendCalibrationStop() {
        calibrationState = DfCalibrationState(status: .idle)
        session.sendFrame(FrameCodec.build(info: 0x04, subState: 0x02))
    }

    func sendDiagnostic(motorId: UInt8, controlType: UInt8, direction: UInt8, speedPct: Int, durationSec: Int) {
        session.sendFrame(FrameCodec.buildDiagnostic(motorId: motorId, controlType: controlType, direction: direction,
                                                      speedPct: UInt16(speedPct), durationSec: UInt16(durationSec)))
    }

    func startDiagnosis(motorLabel: String) { diagnosisState = DfDiagnosisState(isDiagnosing: true, motorLabel: motorLabel) }
    func clearDiagnosis()                   { diagnosisState = DfDiagnosisState() }
    func sendStopDiagnosis()                { session.sendFrame(FrameCodec.build(info: 0x04, subState: 0x06)) }
    func sendCarouselRequest(motorId: UInt8){ session.sendFrame(FrameCodec.buildCarouselRequest(motorId: motorId)) }
    func sendResetLengthCounter()           { session.sendFrame(FrameCodec.buildResetLengthCounter()) }
    func sendLog(enabled: Bool) {
        logEnabled = enabled
        session.sendFrame(FrameCodec.build(info: 0x0C, subState: enabled ? 0x01 : 0x00))
        Task { @MainActor in self.logMessage = enabled ? "Log Enabled" : "Log Disabled"
            try? await Task.sleep(nanoseconds: 2_000_000_000); self.logMessage = nil }
    }
    func disconnect() { session.disconnect() }

    private func showReadResult(_ ok: Bool) {
        readResult = ok; Task { @MainActor in try? await Task.sleep(nanoseconds: 2_000_000_000); self.readResult = nil }
    }
    private func showSaveResult(_ ok: Bool) {
        saveResult = ok; Task { @MainActor in try? await Task.sleep(nanoseconds: 2_000_000_000); self.saveResult = nil }
    }
    private func showAlReadResult(_ ok: Bool) {
        alReadResult = ok; Task { @MainActor in try? await Task.sleep(nanoseconds: 2_000_000_000); self.alReadResult = nil }
    }
    private func showAlSaveResult(_ ok: Bool) {
        alSaveResult = ok; Task { @MainActor in try? await Task.sleep(nanoseconds: 2_000_000_000); self.alSaveResult = nil }
    }

    private func dfPauseReason(_ c: Int) -> String {
        switch c { case 1: return "User Paused"; case 2: return "Creel Sliver Cut"
                   case 3: return "Coiler Sliver Cut"; case 4: return "Lapping"; default: return "Unknown" }
    }
    private func dfErrorSource(_ c: Int) -> String {
        switch c { case 1: return "Front Roller"; case 2: return "Back Roller"; case 3: return "Creel"
                   case 11: return "Mother Board"; case 12: return "Can Bus"; case 13: return "Lifts"
                   case 14: return "System"; default: return "Unknown" }
    }
    private func dfErrorReason(_ c: Int) -> String {
        switch c {
        case 2:     return "Over Current"
        case 4:     return "Over Voltage"
        case 8:     return "Under Voltage"
        case 16:    return "Motor Thermistor Fault"
        case 32:    return "MOSFET Thermistor Fault"
        case 64:    return "Motor Over Temperature"
        case 128:   return "MOSFET Over Temperature"
        case 256:   return "EEPROM Write Error"
        case 512:   return "EEPROM Bad Values"
        case 1024:  return "Tracking Error"
        case 2048:  return "Motor Encoder Setup Error"
        case 4096:  return "Lift Pos Tracking Error"
        case 8192:  return "Lift Synchronicity Fail"
        case 16384: return "Lift Out Of Bounds"
        case 32768: return "EEPROM Bad Homing Position"
        case 96:    return "SMPS Error"
        case 97:    return "Ack Error"
        case 98:    return "Can Cut Error"
        case 99:    return "Lift Relative Position Error"
        default: return "Error Code \(c)"
        }
    }
}
