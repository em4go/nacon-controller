import Foundation

/// The colour a control is tinted with while it is lit.
///
/// The controls that have a colour of their own keep it: the four d-pad directions, because four
/// similar petals inside one circle are hard to tell apart, and the four face buttons, because
/// PlayStation gives them one — triangle green, circle red, cross blue, square pink.
///
/// The accent is deliberately absent from this type. It follows the system setting, and a hard-coded
/// copy here would quietly stop matching it, so `ControlFacts.tint` answers `nil` for every control
/// that should simply use the accent.
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
}
