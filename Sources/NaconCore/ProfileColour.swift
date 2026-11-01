import Foundation

/// The colour of a profile, shown on the pad's light while that profile is the active one.
///
/// The pad has one LED and the XInput protocol carries no colour: it carries a *pattern*, and this unit maps
/// four of those patterns to four colours. Measured on the hardware with a probe that walks every pattern:
/// `player1` gives blue, `player2` red, `player3` green and `player4` purple.
///
/// So a colour here is a name for a pattern, never an RGB value, and the set is closed: a fifth colour would
/// need a pattern the unit does not have.
public enum ProfileColour: String, CaseIterable, Hashable, Sendable, Codable {
    case blue
    case red
    case green
    case purple

    /// The profile a file without a colour gets: the one the app has always shown.
    public static let standard = ProfileColour.blue

    /// The LED pattern that lights the pad in this colour.
    public var pattern: XInputOutputReport.LEDPattern {
        switch self {
        case .blue: return .player1
        case .red: return .player2
        case .green: return .player3
        case .purple: return .player4
        }
    }

    /// The name shown in the window. Translated at the core's own seam, like every other user-facing name,
    /// so the window and a menu built from the same value cannot disagree.
    public var label: String {
        switch self {
        case .blue: return Localization.resolve("Blue")
        case .red: return Localization.resolve("Red")
        case .green: return Localization.resolve("Green")
        case .purple: return Localization.resolve("Purple")
        }
    }
}
