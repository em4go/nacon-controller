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
        case .scrollSpeed: return 2...40
        case .curve: return 1...4
        }
    }

    /// Spanish label shown above the slider.
    public var label: String {
        switch self {
        case .maxSpeed: return "Velocidad máxima"
        case .deadzone: return "Zona muerta"
        case .scrollSpeed: return "Velocidad de desplazamiento"
        case .curve: return "Curva de respuesta"
        }
    }

    /// One line, in Spanish, explaining what the setting changes.
    public var detail: String {
        switch self {
        case .maxSpeed:
            return "Puntos por segundo con el stick a fondo. Más alto, el cursor cruza la pantalla "
                + "antes."
        case .deadzone:
            return "Recorrido del stick que se ignora, para que la mano pueda descansar sin mover el "
                + "cursor."
        case .scrollSpeed:
            return "Líneas por segundo al empujar el stick derecho a fondo."
        case .curve:
            return "1 es lineal; los valores altos dan más precisión cerca del centro y más velocidad "
                + "en el borde."
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
    public func formatted(_ raw: Double) -> String {
        let value = clamp(raw)
        switch self {
        case .maxSpeed:
            return "\(value.formatted(.number.precision(.fractionLength(0)))) pt/s"
        case .deadzone:
            return value.formatted(.number.precision(.fractionLength(2)))
        case .scrollSpeed:
            return "\(value.formatted(.number.precision(.fractionLength(0)))) líneas/s"
        case .curve:
            return "\(value.formatted(.number.precision(.fractionLength(1))))×"
        }
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
