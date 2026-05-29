import Foundation

struct DfProtocol {
    // Settings TLV types
    static let TLV_DELIVERY_SPEED:        UInt8 = 0x70
    static let TLV_DRAFT:                 UInt8 = 0x71
    static let TLV_LENGTH_LIMIT:          UInt8 = 0x72
    static let TLV_RAMP_UP_TIME:          UInt8 = 0x73
    static let TLV_RAMP_DOWN_TIME:        UInt8 = 0x74
    static let TLV_CREEL_TENSION_FACTOR:  UInt8 = 0x75

    // Running state TLV types
    static let TLV_MOTOR_TEMP:            UInt8 = 0x04
    static let TLV_MOSFET_TEMP:           UInt8 = 0x05
    static let TLV_CURRENT:               UInt8 = 0x06
    static let TLV_RPM:                   UInt8 = 0x07
    static let TLV_OUTPUT_MTRS:           UInt8 = 0x08
    static let TLV_WHAT_INFO:             UInt8 = 0x09
    static let TLV_TOTAL_POWER:           UInt8 = 0x0A
    static let TLV_DELIVERY_MTRS_PER_MIN: UInt8 = 0x0D
    static let TLV_CURRENT_LENGTH:        UInt8 = 0x0E
    static let TLV_AL_SENSOR:             UInt8 = 0x0F

    // AL settings TLV types
    static let TLV_AL_KP:      UInt8 = 0x20
    static let TLV_AL_SLIVER6: UInt8 = 0x21
    static let TLV_AL_SLIVER5: UInt8 = 0x22
    static let TLV_AL_SLIVER4: UInt8 = 0x23
    static let TLV_AL_TARGET:  UInt8 = 0x24

    // Calibration result TLV types
    static let TLV_CAL_AVG:   UInt8 = 0x30
    static let TLV_CAL_COUNT: UInt8 = 0x31

    // Info bytes from mainboard → app
    static let INFO_AL_RESPONSE: UInt8 = 0x12
    static let INFO_CAL_RESULT:  UInt8 = 0x15

    // Motor IDs
    static let MOTOR_FRONT_ROLLER:  UInt8 = 0x01
    static let MOTOR_BACK_ROLLER:   UInt8 = 0x02
    static let MOTOR_CREEL:         UInt8 = 0x03
    static let MOTOR_DRAFTING:      UInt8 = 0x05
    static let CAROUSEL_PRODUCTION: UInt8 = 0x0A

    static func buildSettingsFrame(
        deliverySpeed: Int, draft: Float, lengthLimit: Int,
        rampUpTime: Int, rampDownTime: Int, creelTensionFactor: Float
    ) -> String {
        FrameCodec.build(info: 0x01, subState: 0x01, tlvs: [
            FrameCodec.buildTlvInt(type: TLV_DELIVERY_SPEED,       value: UInt16(deliverySpeed)),
            FrameCodec.buildTlvFloat(type: TLV_DRAFT,              value: draft),
            FrameCodec.buildTlvInt(type: TLV_LENGTH_LIMIT,         value: UInt16(lengthLimit)),
            FrameCodec.buildTlvInt(type: TLV_RAMP_UP_TIME,         value: UInt16(rampUpTime)),
            FrameCodec.buildTlvInt(type: TLV_RAMP_DOWN_TIME,       value: UInt16(rampDownTime)),
            FrameCodec.buildTlvFloat(type: TLV_CREEL_TENSION_FACTOR, value: creelTensionFactor),
        ])
    }

    static func buildAlGetFrame() -> String {
        FrameCodec.build(info: 0x13, subState: 0x01)
    }

    static func buildAlSaveFrame(
        kp: Float, sliver6: Int, sliver5: Int, sliver4: Int, target: Float
    ) -> String {
        FrameCodec.build(info: 0x11, subState: 0x01, tlvs: [
            FrameCodec.buildTlvFloat(type: TLV_AL_KP,      value: kp),
            FrameCodec.buildTlvInt(type: TLV_AL_SLIVER6,   value: UInt16(sliver6)),
            FrameCodec.buildTlvInt(type: TLV_AL_SLIVER5,   value: UInt16(sliver5)),
            FrameCodec.buildTlvInt(type: TLV_AL_SLIVER4,   value: UInt16(sliver4)),
            FrameCodec.buildTlvFloat(type: TLV_AL_TARGET,  value: target),
        ])
    }
}
