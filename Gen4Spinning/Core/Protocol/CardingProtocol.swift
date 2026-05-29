import Foundation

struct CardingProtocol {
    // Settings TLV types
    static let TLV_DELIVERY_SPEED:    UInt8 = 0x80
    static let TLV_CARD_FEED_RATIO:   UInt8 = 0x81
    static let TLV_LENGTH_LIMIT:      UInt8 = 0x82
    static let TLV_CYL_SPEED:         UInt8 = 0x83
    static let TLV_BTR_SPEED:         UInt8 = 0x84
    static let TLV_PICKER_CYL_SPEED:  UInt8 = 0x85
    static let TLV_BTR_FEED:          UInt8 = 0x86
    static let TLV_AF_FEED:           UInt8 = 0x87

    // Running state TLV types
    static let TLV_MOTOR_TEMP:           UInt8 = 0x04
    static let TLV_MOSFET_TEMP:          UInt8 = 0x05
    static let TLV_CURRENT:              UInt8 = 0x06
    static let TLV_RPM:                  UInt8 = 0x07
    static let TLV_OUTPUT_MTRS:          UInt8 = 0x08
    static let TLV_WHAT_INFO:            UInt8 = 0x09
    static let TLV_TOTAL_POWER:          UInt8 = 0x0A
    static let TLV_DUCT_SENSOR:          UInt8 = 0x0B
    static let TLV_COILER_SENSOR:        UInt8 = 0x0C
    static let TLV_DELIVERY_MTRS_PER_MIN: UInt8 = 0x0D

    // Motor IDs
    static let MOTOR_CYLINDER:        UInt8 = 0x01
    static let MOTOR_BEATER:          UInt8 = 0x02
    static let MOTOR_CAGE:            UInt8 = 0x03
    static let MOTOR_CYLINDER_FEED:   UInt8 = 0x04
    static let MOTOR_BEATER_FEED:     UInt8 = 0x05
    static let MOTOR_COILER:          UInt8 = 0x06
    static let MOTOR_PICKER_CYLINDER: UInt8 = 0x07
    static let MOTOR_AF_FEED:         UInt8 = 0x08
    static let CAROUSEL_PRODUCTION:   UInt8 = 0x0A

    static func buildSettingsFrame(
        deliverySpeed: Float, cardFeedRatio: Float, lengthLimit: Int,
        cylSpeed: Int, btrSpeed: Int, pickerCylSpeed: Int,
        btrFeed: Int, afFeed: Int, save: Bool
    ) -> String {
        let subState: UInt8 = save ? 0x00 : 0x01
        return FrameCodec.build(info: 0x01, subState: subState, tlvs: [
            FrameCodec.buildTlvFloat(type: TLV_DELIVERY_SPEED,   value: deliverySpeed),
            FrameCodec.buildTlvFloat(type: TLV_CARD_FEED_RATIO,  value: cardFeedRatio),
            FrameCodec.buildTlvInt(type: TLV_LENGTH_LIMIT,        value: UInt16(lengthLimit)),
            FrameCodec.buildTlvInt(type: TLV_CYL_SPEED,           value: UInt16(cylSpeed)),
            FrameCodec.buildTlvInt(type: TLV_BTR_SPEED,           value: UInt16(btrSpeed)),
            FrameCodec.buildTlvInt(type: TLV_PICKER_CYL_SPEED,    value: UInt16(pickerCylSpeed)),
            FrameCodec.buildTlvInt(type: TLV_BTR_FEED,            value: UInt16(btrFeed)),
            FrameCodec.buildTlvInt(type: TLV_AF_FEED,             value: UInt16(afFeed)),
        ])
    }
}
