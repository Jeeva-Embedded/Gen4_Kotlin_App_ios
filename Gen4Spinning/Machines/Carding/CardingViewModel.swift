import Foundation
import Combine

struct CardingSettings {
    var deliverySpeed:   String = "8.0"
    var cardFeedRatio:   String = "5.0"
    var lengthLimit:     String = "1000"
    var cylSpeed:        String = "750"
    var btrSpeed:        String = "600"
    var pickerCylSpeed:  String = "600"
    var btrFeed:         String = "10"
    var afFeed:          String = "7"
}

struct CardingRunState {
    var substate:         UInt8  = 0x00
    var deliveryMtrsPerMin: Float = 0
    var ductSensor:       Bool   = false
    var coilerSensor:     Bool   = false
    var pauseReason:      String = ""
    var errorInformation: String = ""
    var errorCode:        String = ""
    var errorSource:      String = ""
}

struct CardingDiagnosisState {
    var isDiagnosing: Bool   = false
    var motorLabel:   String = ""
    var rpm:          String = "-"
    var pwm:          String = "-"
    var current:      String = "-"
    var power:        String = "-"
}

class CardingViewModel: ObservableObject {
    @Published var settings          = CardingSettings()
    @Published var runState          = CardingRunState()
    @Published var saveResult:       Bool? = nil
    @Published var readResult:       Bool? = nil
    @Published var carouselData:     [UInt8: [String: String]] = [:]
    @Published var diagnosisState    = CardingDiagnosisState()
    @Published var defaultApplied:   Bool? = nil
    @Published var logEnabled:       Bool  = false
    @Published var logMessage:       String? = nil
    @Published var settingsChangeAllowed: Bool = true

    private let session: BtSessionManager
    private var cancellables = Set<AnyCancellable>()
    private var readPending = false

    init(session: BtSessionManager) {
        self.session = session
        session.inboundFrames
            .receive(on: DispatchQueue.main)
            .sink { [weak self] f in self?.handleFrame(f) }
            .store(in: &cancellables)
        session.saveResponse
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ok in self?.showSaveResult(ok) }
            .store(in: &cancellables)
    }

    private func handleFrame(_ frame: BtFrame) {
        switch frame.info {
        case 0x06:
            let ss = frame.subState
            var st = runState; st.substate = ss
            var pauseReason = ""; var errInfo = ""; var errCode = ""; var errSrc = ""
            var carouselId: UInt8 = 0; var cf: [String: String] = [:]

            for tlv in frame.tlvs {
                switch tlv.type {
                case CardingProtocol.TLV_WHAT_INFO:             carouselId = tlv.valueAsUInt8()
                case CardingProtocol.TLV_RPM:                   cf["rpm"]            = "\(tlv.valueAsUInt16())"
                case CardingProtocol.TLV_CURRENT:               cf["current"]        = String(format: "%.2f", tlv.valueAsFloat())
                case CardingProtocol.TLV_MOTOR_TEMP:            cf["motorTemp"]      = "\(tlv.valueAsUInt16())"
                case CardingProtocol.TLV_MOSFET_TEMP:           cf["mosfetTemp"]     = "\(tlv.valueAsUInt16())"
                case CardingProtocol.TLV_OUTPUT_MTRS:           cf["outputMtrs"]     = String(format: "%.1f", tlv.valueAsFloat())
                case CardingProtocol.TLV_TOTAL_POWER:           cf["totalPower"]     = String(format: "%.1f", tlv.valueAsFloat())
                case CardingProtocol.TLV_DELIVERY_MTRS_PER_MIN:
                    st.deliveryMtrsPerMin = tlv.valueAsFloat()
                    cf["deliveryMtrsPerMin"] = String(format: "%.1f", tlv.valueAsFloat())
                case CardingProtocol.TLV_DUCT_SENSOR:   st.ductSensor   = tlv.valueAsUInt8() == 1
                case CardingProtocol.TLV_COILER_SENSOR: st.coilerSensor = tlv.valueAsUInt8() == 1
                case 0x01:
                    if ss == 0x02 { pauseReason = cardingPauseReason(Int(tlv.valueAsUInt16())) }
                    if ss == 0x03 { errInfo     = cardingErrorReason(Int(tlv.valueAsUInt16())) }
                case 0x02: if ss == 0x03 { errSrc  = cardingErrorSource(Int(tlv.valueAsUInt16())) }
                case 0x03: if ss == 0x03 { errCode = "\(tlv.valueAsUInt16())" }
                default: break
                }
            }
            st.pauseReason = pauseReason; st.errorInformation = errInfo
            st.errorCode = errCode; st.errorSource = errSrc
            runState = st
            settingsChangeAllowed = ss == 0x00
            if carouselId != 0 { carouselData[carouselId] = cf }

        case 0x02:
            var s = settings
            for tlv in frame.tlvs {
                switch tlv.type {
                case CardingProtocol.TLV_DELIVERY_SPEED:   s.deliverySpeed  = String(format: "%.2f", tlv.valueAsFloat())
                case CardingProtocol.TLV_CARD_FEED_RATIO:  s.cardFeedRatio  = String(format: "%.2f", tlv.valueAsFloat())
                case CardingProtocol.TLV_LENGTH_LIMIT:     s.lengthLimit    = "\(tlv.valueAsUInt16())"
                case CardingProtocol.TLV_CYL_SPEED:        s.cylSpeed       = "\(tlv.valueAsUInt16())"
                case CardingProtocol.TLV_BTR_SPEED:        s.btrSpeed       = "\(tlv.valueAsUInt16())"
                case CardingProtocol.TLV_PICKER_CYL_SPEED: s.pickerCylSpeed = "\(tlv.valueAsUInt16())"
                case CardingProtocol.TLV_BTR_FEED:         s.btrFeed        = "\(tlv.valueAsUInt16())"
                case CardingProtocol.TLV_AF_FEED:          s.afFeed         = "\(tlv.valueAsUInt16())"
                default: break
                }
            }
            settings = s; readPending = false; showReadResult(true)

        case 0x05:
            guard diagnosisState.isDiagnosing else { break }
            var d = diagnosisState
            for tlv in frame.tlvs {
                let isInt = tlv.length == 0x04
                switch tlv.type {
                case 0x01: d.rpm     = isInt ? "\(tlv.valueAsUInt16())" : String(format: "%.0f", tlv.valueAsFloat())
                case 0x02: d.pwm     = isInt ? "\(tlv.valueAsUInt16())" : String(format: "%.1f", tlv.valueAsFloat())
                case 0x03: d.current = isInt ? "\(tlv.valueAsUInt16())" : String(format: "%.2f", tlv.valueAsFloat())
                case 0x04: d.power   = isInt ? "\(tlv.valueAsUInt16())" : String(format: "%.1f", tlv.valueAsFloat())
                default: break
                }
            }
            diagnosisState = d

        case 0x07:
            var motorId: UInt8 = 0; var data: [String: String] = [:]
            for tlv in frame.tlvs {
                switch tlv.type {
                case CardingProtocol.TLV_WHAT_INFO:   motorId          = tlv.valueAsUInt8()
                case CardingProtocol.TLV_OUTPUT_MTRS: data["outputMtrs"] = String(format: "%.1f", tlv.valueAsFloat())
                case CardingProtocol.TLV_TOTAL_POWER: data["totalPower"] = String(format: "%.1f", tlv.valueAsFloat())
                case CardingProtocol.TLV_MOTOR_TEMP:  data["motorTemp"]  = "\(tlv.valueAsUInt16())"
                case CardingProtocol.TLV_MOSFET_TEMP: data["mosfetTemp"] = "\(tlv.valueAsUInt16())"
                case CardingProtocol.TLV_CURRENT:     data["current"]    = String(format: "%.2f", tlv.valueAsFloat())
                case CardingProtocol.TLV_RPM:         data["rpm"]        = "\(tlv.valueAsUInt16())"
                default: break
                }
            }
            if motorId != 0 { carouselData[motorId] = data }

        default: break
        }
    }

    func sendRead() {
        readPending = true
        session.sendFrame(FrameCodec.buildReqSettings())
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.readPending { self.readPending = false; self.showReadResult(false) }
        }
    }

    func sendSave() {
        guard let ds = Float(settings.deliverySpeed),
              let cf = Float(settings.cardFeedRatio),
              let ll = Int(settings.lengthLimit),
              let cs = Int(settings.cylSpeed),
              let bs = Int(settings.btrSpeed),
              let ps = Int(settings.pickerCylSpeed),
              let bf = Int(settings.btrFeed),
              let af = Int(settings.afFeed) else { return }
        session.sendFrame(CardingProtocol.buildSettingsFrame(
            deliverySpeed: ds, cardFeedRatio: cf, lengthLimit: ll,
            cylSpeed: cs, btrSpeed: bs, pickerCylSpeed: ps,
            btrFeed: bf, afFeed: af, save: true))
    }

    func resetToDefaults() {
        settings = CardingSettings()
        Task { @MainActor in
            self.defaultApplied = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.defaultApplied = nil
        }
    }

    func sendDiagnostic(motorId: UInt8, controlType: UInt8, direction: UInt8, speedPct: Int, durationSec: Int) {
        session.sendFrame(FrameCodec.buildDiagnostic(
            motorId: motorId, controlType: controlType, direction: direction,
            speedPct: UInt16(speedPct), durationSec: UInt16(durationSec)))
    }

    func startDiagnosis(motorLabel: String) { diagnosisState = CardingDiagnosisState(isDiagnosing: true, motorLabel: motorLabel) }
    func clearDiagnosis()                   { diagnosisState = CardingDiagnosisState() }
    func sendStopDiagnosis()                { session.sendFrame(FrameCodec.build(info: 0x04, subState: 0x06)) }
    func sendCarouselRequest(motorId: UInt8){ session.sendFrame(FrameCodec.buildCarouselRequest(motorId: motorId)) }
    func sendResetLengthCounter()           { session.sendFrame(FrameCodec.buildResetLengthCounter()) }

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

    private func showReadResult(_ ok: Bool) {
        readResult = ok
        Task { @MainActor in try? await Task.sleep(nanoseconds: 2_000_000_000); self.readResult = nil }
    }
    private func showSaveResult(_ ok: Bool) {
        saveResult = ok
        Task { @MainActor in try? await Task.sleep(nanoseconds: 2_000_000_000); self.saveResult = nil }
    }

    private func cardingPauseReason(_ c: Int) -> String {
        switch c { case 1: return "User Paused"; case 2: return "Creel Sliver Cut"
                   case 3: return "Coiler Sliver Cut"; case 4: return "Lapping"; default: return "Unknown" }
    }
    private func cardingErrorReason(_ c: Int) -> String {
        switch c {
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
        default: return "Unknown Error"
        }
    }
    private func cardingErrorSource(_ c: Int) -> String {
        switch c {
        case 1:  return "Cylinder"
        case 2:  return "Beater"
        case 3:  return "Cage"
        case 4:  return "Card Feed"
        case 5:  return "Beater Feed"
        case 6:  return "Coiler"
        case 11: return "MotherBoard"
        case 12: return "Can Bus"
        case 13: return "Lifts"
        case 14: return "System"
        default: return "Unknown"
        }
    }
}
