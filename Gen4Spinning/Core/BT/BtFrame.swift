import Foundation

struct Tlv {
    let type: UInt8
    let length: UInt8
    let rawValue: String

    func valueAsUInt8() -> UInt8 {
        UInt8(rawValue, radix: 16) ?? 0
    }
    func valueAsUInt16() -> UInt16 {
        UInt16(rawValue.prefix(4), radix: 16) ?? 0
    }
    func valueAsFloat() -> Float {
        guard let bits = UInt32(rawValue.prefix(8), radix: 16) else { return 0 }
        return Float(bitPattern: bits)
    }
}

struct BtFrame {
    let info: UInt8
    let subState: UInt8
    let attributeCount: Int
    let tlvs: [Tlv]
}

let SAVE_RESPONSE_SUCCESS = "7E017E"
let SAVE_RESPONSE_FAILURE = "7E007E"
let FSC_CONNECT_STRING    = "CONNECT"
let FSC_DISCONN_STRING    = "DISCONN"
