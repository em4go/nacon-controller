import Foundation

/// The colour a control is tinted with while it is lit.
///
/// Everything uses the app's accent except the four d-pad directions, which get a colour each: on the
/// drawing they are four similar petals inside one circle, and a single colour made it impossible to
/// tell which one the pointer was on.
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
        default:
            return nil
        }
    }
}
