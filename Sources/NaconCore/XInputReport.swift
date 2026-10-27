import Foundation

/// Button bits of an Xbox 360 (XInput) report: byte 2 is the low byte, byte 3 the high byte.
public struct XInputButtons: OptionSet, Hashable, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let dpadUp = XInputButtons(rawValue: 1 << 0)
    public static let dpadDown = XInputButtons(rawValue: 1 << 1)
    public static let dpadLeft = XInputButtons(rawValue: 1 << 2)
    public static let dpadRight = XInputButtons(rawValue: 1 << 3)
    public static let start = XInputButtons(rawValue: 1 << 4)
    public static let back = XInputButtons(rawValue: 1 << 5)
    public static let leftThumb = XInputButtons(rawValue: 1 << 6)
    public static let rightThumb = XInputButtons(rawValue: 1 << 7)
    public static let leftBumper = XInputButtons(rawValue: 1 << 8)
    public static let rightBumper = XInputButtons(rawValue: 1 << 9)
    public static let guide = XInputButtons(rawValue: 1 << 10)
    // Bit 11 (0x08 of byte 3) is not used by Xbox 360 pads.
    public static let buttonA = XInputButtons(rawValue: 1 << 12)
    public static let buttonB = XInputButtons(rawValue: 1 << 13)
    public static let buttonX = XInputButtons(rawValue: 1 << 14)
    public static let buttonY = XInputButtons(rawValue: 1 << 15)
}

/// One analog stick. Raw values are the signed 16-bit values reported by the pad.
public struct XInputStick: Equatable, Sendable {
    public let rawX: Int16
    public let rawY: Int16

    public init(rawX: Int16, rawY: Int16) {
        self.rawX = rawX
        self.rawY = rawY
    }

    public static let center = XInputStick(rawX: 0, rawY: 0)

    /// -1...1 position, with the vertical axis inverted so that up is positive on screen.
    public var normalizedX: Double {
        max(-1, min(1, Double(rawX) / 32_767.0))
    }

    public var normalizedY: Double {
        // The pad reports y growing downwards, so negate it for display.
        max(-1, min(1, -Double(rawY) / 32_767.0))
    }
}

/// A decoded 20-byte XInput input report.
///
/// Layout (little endian), as used by the Linux `xpad` driver and documented by prior art:
/// byte 0 message type (must be 0x00), byte 1 length marker (0x14), bytes 2-3 buttons,
/// byte 4 left trigger, byte 5 right trigger, bytes 6-13 the four stick axes as Int16,
/// bytes 14-19 unused by wired Xbox 360 pads.
public struct XInputReport: Equatable, Sendable {
    public static let minimumLength = 14
    public static let expectedLength = 20
    public static let messageTypeByte: UInt8 = 0x00
    public static let lengthMarkerByte: UInt8 = 0x14

    public let rawBytes: [UInt8]
    public let buttons: XInputButtons
    public let leftTrigger: UInt8
    public let rightTrigger: UInt8
    public let leftStick: XInputStick
    public let rightStick: XInputStick

    public init(
        rawBytes: [UInt8],
        buttons: XInputButtons,
        leftTrigger: UInt8,
        rightTrigger: UInt8,
        leftStick: XInputStick,
        rightStick: XInputStick
    ) {
        self.rawBytes = rawBytes
        self.buttons = buttons
        self.leftTrigger = leftTrigger
        self.rightTrigger = rightTrigger
        self.leftStick = leftStick
        self.rightStick = rightStick
    }

    public var leftTriggerNormalized: Double { Double(leftTrigger) / 255.0 }
    public var rightTriggerNormalized: Double { Double(rightTrigger) / 255.0 }

    /// Decodes an input report, or returns nil for any packet that is not one.
    ///
    /// The pad also sends short status packets on the same endpoint (for example the
    /// `01 03 0e` LED message), so callers must tolerate nil.
    public static func decode(_ bytes: [UInt8]) -> XInputReport? {
        guard bytes.count >= minimumLength,
              bytes[0] == messageTypeByte,
              bytes[1] == lengthMarkerByte
        else {
            return nil
        }

        func signed16(at index: Int) -> Int16 {
            let low = UInt16(bytes[index])
            let high = UInt16(bytes[index + 1]) << 8
            return Int16(bitPattern: low | high)
        }

        let lowButtons = UInt16(bytes[2])
        let highButtons = UInt16(bytes[3]) << 8

        return XInputReport(
            rawBytes: bytes,
            buttons: XInputButtons(rawValue: lowButtons | highButtons),
            leftTrigger: bytes[4],
            rightTrigger: bytes[5],
            leftStick: XInputStick(rawX: signed16(at: 6), rawY: signed16(at: 8)),
            rightStick: XInputStick(rawX: signed16(at: 10), rawY: signed16(at: 12))
        )
    }
}

/// A control the UI can render and query against a report.
public enum XInputControl: String, CaseIterable, Sendable {
    case dpadUp = "D-Pad ↑"
    case dpadDown = "D-Pad ↓"
    case dpadLeft = "D-Pad ←"
    case dpadRight = "D-Pad →"
    case buttonA = "✕"
    case buttonB = "○"
    case buttonX = "□"
    case buttonY = "△"
    case leftBumper = "L1"
    case rightBumper = "R1"
    case leftTrigger = "L2"
    case rightTrigger = "R2"
    case back = "Share"
    case start = "Options"
    case guide = "PS"
    case leftThumb = "L3"
    case rightThumb = "R3"

    /// Triggers are analog, so they count as pressed above this raw threshold.
    public static let triggerPressedThreshold: UInt8 = 30

    public var mask: XInputButtons {
        switch self {
        case .dpadUp: return .dpadUp
        case .dpadDown: return .dpadDown
        case .dpadLeft: return .dpadLeft
        case .dpadRight: return .dpadRight
        case .buttonA: return .buttonA
        case .buttonB: return .buttonB
        case .buttonX: return .buttonX
        case .buttonY: return .buttonY
        case .leftBumper: return .leftBumper
        case .rightBumper: return .rightBumper
        case .back: return .back
        case .start: return .start
        case .guide: return .guide
        case .leftThumb: return .leftThumb
        case .rightThumb: return .rightThumb
        case .leftTrigger, .rightTrigger: return []
        }
    }

    public func isPressed(in report: XInputReport) -> Bool {
        switch self {
        case .leftTrigger:
            return report.leftTrigger > Self.triggerPressedThreshold
        case .rightTrigger:
            return report.rightTrigger > Self.triggerPressedThreshold
        default:
            return report.buttons.contains(mask)
        }
    }
}
