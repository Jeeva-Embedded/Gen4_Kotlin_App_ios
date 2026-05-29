import Foundation

enum ParseResult {
    case ok(BtFrame)
    case skip(String)
    case error(String)
}

struct FrameCodec {
    private static let SOF = "7E"
    private static let EOF = "7E"

    static func parse(_ raw: String) -> ParseResult {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.contains(FSC_CONNECT_STRING) { return .skip("FSC CONNECT") }
        if s.contains(FSC_DISCONN_STRING) { return .skip("FSC DISCONN") }
        if s == SAVE_RESPONSE_SUCCESS     { return .skip("save-ack SUCCESS") }
        if s == SAVE_RESPONSE_FAILURE     { return .skip("save-ack FAILURE") }
        guard s.count >= 12              else { return .error("too short: \(s.count)") }
        guard s.hasPrefix(SOF)           else { return .error("no SOF") }

        let idx = s.index(s.startIndex, offsetBy: 2)
        let lengthHex = String(s[idx..<s.index(idx, offsetBy: 2)])
        guard let length = Int(lengthHex, radix: 16) else { return .error("bad length: \(lengthHex)") }
        let expectedTotal = 4 + length
        guard s.count >= expectedTotal else { return .error("truncated: expected \(expectedTotal) got \(s.count)") }

        let eofOffset = 4 + length - 2
        let eofStart = s.index(s.startIndex, offsetBy: eofOffset)
        let eofEnd   = s.index(eofStart, offsetBy: 2)
        guard String(s[eofStart..<eofEnd]) == EOF else { return .error("EOF mismatch") }

        func sub(_ from: Int, _ to: Int) -> String {
            String(s[s.index(s.startIndex, offsetBy: from)..<s.index(s.startIndex, offsetBy: to)])
        }
        guard let info           = UInt8(sub(4, 6), radix: 16),
              let subState       = UInt8(sub(6, 8), radix: 16),
              let attributeCount = Int(sub(8, 10),  radix: 16)
        else { return .error("bad header") }

        var tlvs: [Tlv] = []
        var cursor = 10
        while cursor < eofOffset {
            guard cursor + 4 <= eofOffset else { return .error("TLV overruns EOF at \(cursor)") }
            guard let type    = UInt8(sub(cursor, cursor + 2), radix: 16),
                  let wireLen = UInt8(sub(cursor + 2, cursor + 4), radix: 16)
            else { return .error("bad TLV at \(cursor)") }
            let valueChars = Int(wireLen)
            guard valueChars >= 2, valueChars % 2 == 0, valueChars <= 32 else {
                return .error("invalid wireLen \(wireLen) at \(cursor)")
            }
            guard cursor + 4 + valueChars <= eofOffset else { return .error("value overruns EOF") }
            let value = sub(cursor + 4, cursor + 4 + valueChars)
            tlvs.append(Tlv(type: type, length: wireLen, rawValue: value))
            cursor += 4 + valueChars
        }
        return .ok(BtFrame(info: info, subState: subState, attributeCount: attributeCount, tlvs: tlvs))
    }

    static func build(info: UInt8, subState: UInt8, tlvs: [String] = []) -> String {
        var body = String(format: "%02X%02X%02X", info, subState, tlvs.count)
        for tlv in tlvs { body += tlv }
        body += EOF
        return SOF + String(format: "%02X", body.count) + body
    }

    static func buildTlvCompact(type: UInt8, value: UInt8) -> String {
        String(format: "%02X02%02X", type, value)
    }
    static func buildTlvInt(type: UInt8, value: UInt16) -> String {
        String(format: "%02X04%04X", type, value)
    }
    static func buildTlvFloat(type: UInt8, value: Float) -> String {
        let bits = value.bitPattern
        return String(format: "%02X08%08X", type, bits)
    }

    static func buildPairedFromPhone()        -> String { build(info: 0x99, subState: 0x00) }
    static func buildReqSettings()            -> String { build(info: 0x03, subState: 0x00) }
    static func buildResetLengthCounter()     -> String { build(info: 0x0A, subState: 0x00) }
    static func buildCarouselRequest(motorId: UInt8) -> String { build(info: 0x07, subState: motorId) }
    static func buildPidRequest(motorId: UInt8) -> String {
        build(info: 0x0D, subState: 0x00, tlvs: [buildTlvCompact(type: 0x01, value: motorId)])
    }

    static func buildDiagnostic(motorId: UInt8, controlType: UInt8, direction: UInt8,
                                 speedPct: UInt16, durationSec: UInt16,
                                 bedDistanceMm: UInt16? = nil) -> String {
        if let bed = bedDistanceMm {
            return build(info: 0x04, subState: 0x01, tlvs: [
                buildTlvCompact(type: 0x40, value: motorId),
                buildTlvCompact(type: 0x44, value: direction),
                buildTlvCompact(type: 0x41, value: controlType),
                buildTlvInt(type: 0x45, value: bed),
            ])
        } else {
            return build(info: 0x04, subState: 0x01, tlvs: [
                buildTlvCompact(type: 0x40, value: motorId),
                buildTlvCompact(type: 0x44, value: direction),
                buildTlvCompact(type: 0x41, value: controlType),
                buildTlvInt(type: 0x42, value: speedPct),
                buildTlvInt(type: 0x43, value: durationSec),
            ])
        }
    }
}
