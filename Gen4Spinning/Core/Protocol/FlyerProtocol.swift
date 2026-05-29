import Foundation

struct FlyerProtocol {
    // Settings TLV types (0x50–0x62)
    static let TLV_SPINDLE_SPEED:     UInt8 = 0x50
    static let TLV_DRAFT:             UInt8 = 0x51
    static let TLV_TWIST_PER_INCH:    UInt8 = 0x52
    static let TLV_RTF:               UInt8 = 0x53
    static let TLV_LAYERS:            UInt8 = 0x54
    static let TLV_MAX_HEIGHT:        UInt8 = 0x55
    static let TLV_ROVING_WIDTH:      UInt8 = 0x56
    static let TLV_DELTA_BOBBIN_DIA:  UInt8 = 0x57
    static let TLV_BARE_BOBBIN_DIA:   UInt8 = 0x58
    static let TLV_RAMP_UP_TIME:      UInt8 = 0x59
    static let TLV_RAMP_DOWN_TIME:    UInt8 = 0x60
    static let TLV_CHANGE_LAYER_TIME: UInt8 = 0x61
    static let TLV_CONE_ANGLE_FACTOR: UInt8 = 0x62

    // Running state TLV types
    static let TLV_LEFT_LIFT:   UInt8 = 0x01
    static let TLV_RIGHT_LIFT:  UInt8 = 0x02
    static let TLV_RUN_LAYERS:  UInt8 = 0x03
    static let TLV_MOTOR_TEMP:  UInt8 = 0x04
    static let TLV_MOSFET_TEMP: UInt8 = 0x05
    static let TLV_CURRENT:     UInt8 = 0x06
    static let TLV_RPM:         UInt8 = 0x07
    static let TLV_OUTPUT_MTRS: UInt8 = 0x08
    static let TLV_WHAT_INFO:   UInt8 = 0x09
    static let TLV_TOTAL_POWER: UInt8 = 0x0A

    // Motor IDs
    static let MOTOR_FLYER:        UInt8 = 0x01
    static let MOTOR_BOBBIN:       UInt8 = 0x02
    static let MOTOR_FRONT_ROLLER: UInt8 = 0x03
    static let MOTOR_BACK_ROLLER:  UInt8 = 0x04
    static let MOTOR_DRAFTING:     UInt8 = 0x05
    static let MOTOR_WINDING:      UInt8 = 0x06
    static let MOTOR_LIFT:         UInt8 = 0x07
    static let MOTOR_LIFT_LEFT:    UInt8 = 0x08
    static let MOTOR_LIFT_RIGHT:   UInt8 = 0x09
    static let CAROUSEL_PRODUCTION: UInt8 = 0x0A

    static func buildSettingsFrame(
        spindleSpeed: Int, draft: Float, twistPerInch: Float, rtf: Float,
        layers: Int, maxHeight: Int, rovingWidth: Float, deltaBobbinDia: Float,
        bareBobbinDia: Int, rampUpTime: Int, rampDownTime: Int,
        changeLayerTime: Int, coneAngleFactor: Float
    ) -> String {
        FrameCodec.build(info: 0x01, subState: 0x00, tlvs: [
            FrameCodec.buildTlvInt(type: TLV_SPINDLE_SPEED,     value: UInt16(spindleSpeed)),
            FrameCodec.buildTlvFloat(type: TLV_DRAFT,           value: draft),
            FrameCodec.buildTlvFloat(type: TLV_TWIST_PER_INCH,  value: twistPerInch),
            FrameCodec.buildTlvFloat(type: TLV_RTF,             value: rtf),
            FrameCodec.buildTlvInt(type: TLV_LAYERS,            value: UInt16(layers)),
            FrameCodec.buildTlvInt(type: TLV_MAX_HEIGHT,        value: UInt16(maxHeight)),
            FrameCodec.buildTlvFloat(type: TLV_ROVING_WIDTH,    value: rovingWidth),
            FrameCodec.buildTlvFloat(type: TLV_DELTA_BOBBIN_DIA, value: deltaBobbinDia),
            FrameCodec.buildTlvInt(type: TLV_BARE_BOBBIN_DIA,   value: UInt16(bareBobbinDia)),
            FrameCodec.buildTlvInt(type: TLV_RAMP_UP_TIME,      value: UInt16(rampUpTime)),
            FrameCodec.buildTlvInt(type: TLV_RAMP_DOWN_TIME,    value: UInt16(rampDownTime)),
            FrameCodec.buildTlvInt(type: TLV_CHANGE_LAYER_TIME, value: UInt16(changeLayerTime)),
            FrameCodec.buildTlvFloat(type: TLV_CONE_ANGLE_FACTOR, value: coneAngleFactor),
        ])
    }
}
