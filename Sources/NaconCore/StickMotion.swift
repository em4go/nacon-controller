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

/// Scroll distance in pixels, one value per axis.
public struct ScrollPixels: Equatable, Sendable {
    public let x: Int
    public let y: Int

    public static let zero = ScrollPixels(x: 0, y: 0)

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public var isZero: Bool { x == 0 && y == 0 }
}

/// Scroll velocity in lines per second, one value per axis.
public struct ScrollVelocity: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public static let zero = ScrollVelocity(x: 0, y: 0)

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var isZero: Bool { x == 0 && y == 0 }
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

    /// Scroll amount in lines per second, one value per axis.
    ///
    /// Unlike the cursor, each axis is judged on its own: a wheel has two independent axes, and a
    /// diagonal push should move the page as far as the hand asks on each axis, not split one speed
    /// between the two. Only the vertical axis can be inverted; a horizontal inversion nobody asked
    /// for would be one more setting to explain.
    public static func scrollVelocity(stick: XInputStick, settings: CursorSettings) -> ScrollVelocity {
        let axisY = settings.invertVerticalAxis ? -stick.normalizedY : stick.normalizedY
        return ScrollVelocity(
            x: linesPerSecond(axis: stick.normalizedX, settings: settings),
            y: linesPerSecond(axis: axisY, settings: settings)
        )
    }

    private static func linesPerSecond(axis: Double, settings: CursorSettings) -> Double {
        let magnitude = abs(axis)
        guard magnitude > settings.deadzone else { return 0 }
        let span = max(settings.fullSpeedFraction - settings.deadzone, 0.000_1)
        let normalized = min((magnitude - settings.deadzone) / span, 1)
        let shaped = pow(normalized, max(settings.curveExponent, 0.1))
        return shaped * settings.scrollLinesPerSecond * (axis < 0 ? -1 : 1)
    }
}

/// Turns a continuous scroll rate into whole pixel units, keeping a remainder per axis.
public struct ScrollAccumulator: Sendable {
    private var remainderX: Double = 0
    private var remainderY: Double = 0

    public init() {}

    /// Whole pixels for this step, carrying each axis' fraction into the next one so a slow scroll
    /// still moves instead of being rounded away every tick.
    ///
    /// The fractions are kept apart on purpose: one shared remainder would let a sideways push pay
    /// for the vertical axis and arrive as a movement nobody asked for.
    public mutating func consume(
        pixelsPerSecondX: Double,
        pixelsPerSecondY: Double,
        seconds: Double
    ) -> ScrollPixels {
        ScrollPixels(
            x: Self.take(&remainderX, pixelsPerSecond: pixelsPerSecondX, seconds: seconds),
            y: Self.take(&remainderY, pixelsPerSecond: pixelsPerSecondY, seconds: seconds)
        )
    }

    private static func take(_ remainder: inout Double, pixelsPerSecond: Double, seconds: Double) -> Int {
        remainder += pixelsPerSecond * seconds
        let whole = remainder.rounded(.towardZero)
        remainder -= whole
        return Int(whole)
    }

    public mutating func reset() {
        remainderX = 0
        remainderY = 0
    }
}
