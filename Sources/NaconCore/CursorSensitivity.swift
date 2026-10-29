import Foundation

/// One cursor setting the user may tune: its range, its wording and its formatted value.
///
/// `CursorSettings` stores six values, but the app only reached `invertVerticalAxis`, so two profiles
/// could not actually differ in speed even though the model and the file allowed it. This type
/// carries the rest of the surface: the view becomes a slider factory and the clamping rule stays
/// testable without SwiftUI.
///
/// Clamping instead of rejecting is deliberate. A slider cannot leave its range, but a stored file
/// can carry any number, and a value that reached the engine as 0 points per second would be
/// indistinguishable from a frozen cursor.
public enum CursorSensitivity: String, CaseIterable, Equatable, Sendable {
    case maxSpeed
    case deadzone
    case scrollSpeed
    case curve

    /// Range a written value is clamped to.
    public var range: ClosedRange<Double> {
        switch self {
        case .maxSpeed: return 200...3_000
        case .deadzone: return 0.05...0.6
        case .scrollSpeed: return 2...80
        case .curve: return 1...4
        }
    }

    /// Spanish label shown above the slider.
    public var label: String {
        switch self {
        case .maxSpeed: return Localization.resolve("Maximum speed")
        case .deadzone: return Localization.resolve("Dead zone")
        case .scrollSpeed: return Localization.resolve("Scroll speed")
        case .curve: return Localization.resolve("Response curve")
        }
    }

    /// One line, in Spanish, explaining what the setting changes.
    public var detail: String {
        switch self {
        case .maxSpeed:
            return Localization.resolve(
                "Points per second with the stick pushed all the way. Higher values make the cursor "
                + "cross the screen sooner."
            )
        case .deadzone:
            return Localization.resolve(
                "Stick travel that is ignored, so the hand can rest without moving the cursor."
            )
        case .scrollSpeed:
            return Localization.resolve(
                "Lines per second with the right stick pushed all the way."
            )
        case .curve:
            return Localization.resolve(
                "1 is linear; higher values give more precision near the centre and more speed at "
                + "the edge."
            )
        }
    }

    /// Current value of this setting in a profile.
    public func value(in settings: CursorSettings) -> Double {
        switch self {
        case .maxSpeed: return settings.maxSpeed
        case .deadzone: return settings.deadzone
        case .scrollSpeed: return settings.scrollLinesPerSecond
        case .curve: return settings.curveExponent
        }
    }

    /// The value as the slider must show it. A bare number would not say what it measures.
    public func formatted(_ raw: Double, locale: Locale? = nil) -> String {
        let value = clamp(raw)
        switch self {
        case .maxSpeed:
            return unit(value.formatted(.number.precision(.fractionLength(0))), pattern: "%@ pt/s", locale: locale)
        case .deadzone:
            return value.formatted(.number.precision(.fractionLength(2)))
        case .scrollSpeed:
            return unit(value.formatted(.number.precision(.fractionLength(0))), pattern: "%@ lines/s", locale: locale)
        case .curve:
            return "\(value.formatted(.number.precision(.fractionLength(1))))×"
        }
    }

    /// Fills a localized pattern with an already formatted number. The unit is translated; the number
    /// is formatted by the same language, so the two cannot disagree.
    private func unit(_ number: String, pattern: String, locale: Locale?) -> String {
        var resource = Localization.resource(pattern)
        if let locale { resource.locale = locale }
        return String(format: String(localized: resource), number)
    }

    /// The nearest value inside `range`. A non-finite number becomes the lower bound.
    public func clamp(_ raw: Double) -> Double {
        guard raw.isFinite else { return range.lowerBound }
        return min(max(raw, range.lowerBound), range.upperBound)
    }

    /// Writes the clamped value into `settings`.
    /// - Returns: whether anything changed.
    @discardableResult
    public func apply(_ raw: Double, to settings: inout CursorSettings) -> Bool {
        let clamped = clamp(raw)
        guard value(in: settings) != clamped else { return false }
        switch self {
        case .maxSpeed: settings.maxSpeed = clamped
        case .deadzone: settings.deadzone = clamped
        case .scrollSpeed: settings.scrollLinesPerSecond = clamped
        case .curve: settings.curveExponent = clamped
        }
        return true
    }
}
