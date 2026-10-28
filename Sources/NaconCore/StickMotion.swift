import Foundation

/// Cursor velocity in points per second.
public struct CursorVelocity: Equatable, Sendable {
    public let dx: Double
    public let dy: Double

    public static let zero = CursorVelocity(dx: 0, dy: 0)

    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }

    public var isZero: Bool { dx == 0 && dy == 0 }
}

public enum StickMotion {
    /// Converts a stick position into a cursor velocity.
    ///
    /// The result is in screen coordinates, the same space `CGEvent` uses: `dx` grows to the right
    /// and `dy` grows downwards, so pushing the stick up yields a negative `dy`.
    ///
    /// The dead zone is radial, so a diagonal deflection is judged by its magnitude and not by
    /// each axis separately; that avoids the axis-shaped gaps a per-axis dead zone produces.
    /// After the dead zone the remaining magnitude is rescaled to 0...1, shaped by the curve and
    /// multiplied by `maxSpeed`.
    public static func cursorVelocity(stick: XInputStick, settings: CursorSettings) -> CursorVelocity {
        let axisX = stick.normalizedX
        let axisY = settings.invertVerticalAxis ? -stick.normalizedY : stick.normalizedY
        let magnitude = (axisX * axisX + axisY * axisY).squareRoot()
        guard magnitude > settings.deadzone, magnitude > 0 else { return .zero }

        let usable = min(magnitude, max(settings.fullSpeedFraction, settings.deadzone))
        let span = max(settings.fullSpeedFraction - settings.deadzone, 0.000_1)
        let normalized = (usable - settings.deadzone) / span
        let shaped = pow(min(normalized, 1), max(settings.curveExponent, 0.1))
        let speed = shaped * settings.maxSpeed

        // Direction comes from the stick itself, so the curve never changes the heading.
        return CursorVelocity(dx: speed * (axisX / magnitude), dy: -speed * (axisY / magnitude))
    }

    /// Scroll amount in lines per second. Only the vertical axis of the right stick is used.
    public static func scrollLinesPerSecond(stick: XInputStick, settings: CursorSettings) -> Double {
        let axisY = settings.invertVerticalAxis ? -stick.normalizedY : stick.normalizedY
        let magnitude = abs(axisY)
        guard magnitude > settings.deadzone else { return 0 }
        let span = max(settings.fullSpeedFraction - settings.deadzone, 0.000_1)
        let normalized = min((magnitude - settings.deadzone) / span, 1)
        let shaped = pow(normalized, max(settings.curveExponent, 0.1))
        return shaped * settings.scrollLinesPerSecond * (axisY < 0 ? -1 : 1)
    }
}

/// Turns a continuous scroll rate into whole line units, keeping the remainder.
public struct ScrollAccumulator: Sendable {
    private var remainder: Double = 0

    public init() {}

    /// Whole pixels for this step, carrying the fraction into the next one so a slow scroll still
    /// moves instead of being rounded away every tick.
    public mutating func consume(pixelsPerSecond: Double, seconds: Double) -> Int {
        remainder += pixelsPerSecond * seconds
        let whole = remainder.rounded(.towardZero)
        remainder -= whole
        return Int(whole)
    }

    public mutating func reset() {
        remainder = 0
    }
}
