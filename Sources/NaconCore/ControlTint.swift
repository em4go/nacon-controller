import Foundation

/// The colour a control is tinted with while it is lit.
///
/// The controls that have a colour of their own keep it: the four d-pad directions, because four
/// similar petals inside one circle are hard to tell apart, and the four face buttons, because
/// PlayStation gives them one — triangle green, circle red, cross blue, square pink.
///
/// The accent is deliberately absent from this type. It follows the system setting, and a hard-coded
/// copy here would quietly stop matching it, so `color(for:)` answers `nil` for every control that
/// should simply use the accent.
public struct ControlTint: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// `#RRGGBB`, for comparing palettes without depending on colour types.
    public var packed: String {
        let channels = [red, green, blue].map { Int(($0 * 255).rounded()) }
        return "#" + channels.map { String(format: "%02X", $0) }.joined()
    }

    /// The colour of one control, or `nil` when it takes the accent.
    public static func color(for control: XInputControl) -> ControlTint? {
        switch control {
        case .dpadUp:
            return ControlTint(red: 0.184, green: 0.749, blue: 0.427)      // verde
        case .dpadDown:
            return ControlTint(red: 0.604, green: 0.361, blue: 1.000)      // violeta
        case .dpadLeft:
            return ControlTint(red: 0.145, green: 0.780, blue: 0.851)      // cian
        case .dpadRight:
            return ControlTint(red: 0.961, green: 0.651, blue: 0.137)      // ámbar
        case .buttonA:                                                 // ✕
            return ControlTint(red: 0.239, green: 0.435, blue: 0.878)      // azul
        case .buttonB:                                                 // ○
            return ControlTint(red: 0.886, green: 0.231, blue: 0.231)      // rojo
        case .buttonX:                                                 // □
            return ControlTint(red: 0.878, green: 0.439, blue: 0.722)      // rosa
        case .buttonY:                                                 // △
            return ControlTint(red: 0.043, green: 0.478, blue: 0.220)      // verde oscuro
        default:
            return nil
        }
    }
}
