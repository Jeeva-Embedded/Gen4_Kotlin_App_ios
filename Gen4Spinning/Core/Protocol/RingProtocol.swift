import Foundation

struct RingProtocol {
    // Settings TLV types (0x90–0x97)
    static let TLV_INPUT_YARN:           UInt8 = 0x90
    static let TLV_OUTPUT_YARN_DIA:      UInt8 = 0x91
    static let TLV_SPINDLE_SPEED:        UInt8 = 0x92
    static let TLV_TWIST_PER_INCH:       UInt8 = 0x93
    static let TLV_PACKAGE_HEIGHT:       UInt8 = 0x94
    static let TLV_DIA_BUILD_FACTOR:     UInt8 = 0x95
    static let TLV_WINDING_CLOSENESS:    UInt8 = 0x96
    static let TLV_WINDING_OFFSET_COILS: UInt8 = 0x97

    // Running state TLV types
    static let TLV_MOTOR_TEMP:  UInt8 = 0x04
    static let TLV_MOSFET_TEMP: UInt8 = 0x05
    static let TLV_CURRENT:     UInt8 = 0x06
    static let TLV_RPM:         UInt8 = 0x07
    static let TLV_OUTPUT_MTRS: UInt8 = 0x08
    static let TLV_WHAT_INFO:   UInt8 = 0x09
    static let TLV_TOTAL_POWER: UInt8 = 0x0A
    static let TLV_WEIGHT:      UInt8 = 0x10

    // Motor IDs
    static let MOTOR_CALENDER:   UInt8 = 0x01
    static let MOTOR_LIFT:       UInt8 = 0x07
    static let MOTOR_LIFT_LEFT:  UInt8 = 0x08
    static let MOTOR_LIFT_RIGHT: UInt8 = 0x09
    static let CAROUSEL_PRODUCTION: UInt8 = 0x0A

    static func calcOutputYarnDia(_ inputYarn: Int) -> Float {
        -0.10284 + 1.592 / sqrt(Float(inputYarn) / 2.0)
    }

    static func buildSettingsFrame(
        inputYarn: Int, outputYarnDia: Float, spindleSpeed: Int, twistPerInch: Int,
        packageHeight: Int, diaBuildFactor: Float, windingCloseness: Int, windingOffsetCoils: Int
    ) -> String {
        FrameCodec.build(info: 0x01, subState: 0x01, tlvs: [
            FrameCodec.buildTlvInt(type: TLV_INPUT_YARN,           value: UInt16(inputYarn)),
            FrameCodec.buildTlvFloat(type: TLV_OUTPUT_YARN_DIA,    value: outputYarnDia),
            FrameCodec.buildTlvInt(type: TLV_SPINDLE_SPEED,        value: UInt16(spindleSpeed)),
            FrameCodec.buildTlvInt(type: TLV_TWIST_PER_INCH,       value: UInt16(twistPerInch)),
            FrameCodec.buildTlvInt(type: TLV_PACKAGE_HEIGHT,       value: UInt16(packageHeight)),
            FrameCodec.buildTlvFloat(type: TLV_DIA_BUILD_FACTOR,   value: diaBuildFactor),
            FrameCodec.buildTlvInt(type: TLV_WINDING_CLOSENESS,    value: UInt16(windingCloseness)),
            FrameCodec.buildTlvInt(type: TLV_WINDING_OFFSET_COILS, value: UInt16(windingOffsetCoils)),
        ])
    }
}
