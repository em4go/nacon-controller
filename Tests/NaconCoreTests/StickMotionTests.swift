import XCTest

@testable import NaconCore

final class StickMotionTests: XCTestCase {
    private func stick(normalizedX: Double, normalizedY: Double) -> XInputStick {
        XInputStick(
            rawX: Int16((normalizedX * 32_767).rounded()),
            rawY: Int16((-normalizedY * 32_767).rounded())
        )
    }

    private let settings = CursorSettings.standard

    func testCenteredStickProducesNoMotion() {
        let velocity = StickMotion.cursorVelocity(stick: .center, settings: settings)
        XCTAssertEqual(velocity, .zero)
    }

    func testDeflectionInsideDeadzoneProducesNoMotion() {
        let inside = stick(normalizedX: settings.deadzone - 0.05, normalizedY: 0)
        XCTAssertEqual(StickMotion.cursorVelocity(stick: inside, settings: settings), .zero)
    }

    func testJustOutsideDeadzoneProducesMotion() {
        // The exact deadzone boundary is not representable through the stick's 16-bit integers,
        // so the meaningful assertion is that a small step outside it starts the cursor.
        let outside = stick(normalizedX: settings.deadzone + 0.02, normalizedY: 0)
        XCTAssertGreaterThan(StickMotion.cursorVelocity(stick: outside, settings: settings).dx, 0)
    }

    func testFullDeflectionReachesMaximumSpeed() {
        let full = stick(normalizedX: 1, normalizedY: 0)
        let velocity = StickMotion.cursorVelocity(stick: full, settings: settings)
        XCTAssertEqual(velocity.dx, settings.maxSpeed, accuracy: 0.5)
        XCTAssertEqual(velocity.dy, 0, accuracy: 1e-9)
    }

    func testDiagonalDeflectionKeepsDirectionAndTotalSpeed() {
        let diagonal = (1.0 / 2.0).squareRoot()
        let velocity = StickMotion.cursorVelocity(
            stick: stick(normalizedX: diagonal, normalizedY: diagonal),
            settings: settings
        )
        XCTAssertEqual(velocity.dx, -velocity.dy, accuracy: 0.5)
        let magnitude = (velocity.dx * velocity.dx + velocity.dy * velocity.dy).squareRoot()
        XCTAssertEqual(magnitude, settings.maxSpeed, accuracy: 1.0)
    }

    func testSpeedGrowsMonotonicallyWithDeflection() {
        let mid = StickMotion.cursorVelocity(
            stick: stick(normalizedX: 0.4, normalizedY: 0),
            settings: settings
        )
        let high = StickMotion.cursorVelocity(
            stick: stick(normalizedX: 0.8, normalizedY: 0),
            settings: settings
        )
        XCTAssertGreaterThan(mid.dx, 0)
        XCTAssertGreaterThan(high.dx, mid.dx)
    }

    func testUpwardDeflectionMovesCursorUp() {
        let upward = stick(normalizedX: 0, normalizedY: 1)
        XCTAssertLessThan(StickMotion.cursorVelocity(stick: upward, settings: settings).dy, 0)
    }

    func testInvertedVerticalAxisFlipsCursorDirection() {
        var settings = CursorSettings.standard
        settings.invertVerticalAxis = true
        let upward = stick(normalizedX: 0, normalizedY: 1)
        XCTAssertGreaterThan(StickMotion.cursorVelocity(stick: upward, settings: settings).dy, 0)
    }

    func testInvertedVerticalAxisFlipsScrollDirection() {
        var settings = CursorSettings.standard
        settings.invertVerticalAxis = true
        let upward = stick(normalizedX: 0, normalizedY: 1)
        XCTAssertLessThan(StickMotion.scrollVelocity(stick: upward, settings: settings).y, 0)
    }

    func testInversionDoesNotAffectHorizontalAxis() {
        var settings = CursorSettings.standard
        settings.invertVerticalAxis = true
        let rightward = stick(normalizedX: 1, normalizedY: 0)
        XCTAssertGreaterThan(StickMotion.cursorVelocity(stick: rightward, settings: settings).dx, 0)
    }

    func testScrollIsZeroInsideDeadzone() {
        let inside = stick(normalizedX: 0, normalizedY: settings.deadzone - 0.05)
        XCTAssertEqual(StickMotion.scrollVelocity(stick: inside, settings: settings), .zero)
    }

    func testScrollDirectionFollowsStick() {
        let upward = stick(normalizedX: 0, normalizedY: 1)
        let downward = stick(normalizedX: 0, normalizedY: -1)
        XCTAssertGreaterThan(StickMotion.scrollVelocity(stick: upward, settings: settings).y, 0)
        XCTAssertLessThan(StickMotion.scrollVelocity(stick: downward, settings: settings).y, 0)
    }

    func testScrollAccumulatorKeepsRemainderBetweenTicks() {
        var accumulator = ScrollAccumulator()
        XCTAssertEqual(accumulator.consume(pixelsPerSecondX: 0, pixelsPerSecondY: 10, seconds: 0.05).y, 0)
        XCTAssertEqual(accumulator.consume(pixelsPerSecondX: 0, pixelsPerSecondY: 10, seconds: 0.06).y, 1)
        accumulator.reset()
        XCTAssertEqual(accumulator.consume(pixelsPerSecondX: 0, pixelsPerSecondY: 10, seconds: 0.05).y, 0)
    }
}
