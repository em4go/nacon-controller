import XCTest

@testable import NaconCore

/// S2, S3, S6: what one press does over time, asserted on the effects instead of on the system.
///
/// `PadPerformance` returns what should be emitted, so these tests need no emitter, no timer and no
/// queue: they hand it seconds and sticks and read the ordered list back. That is the whole point of
/// the split — the engine keeps the clock, this value only answers what that clock produced.
final class PadPerformanceTests: XCTestCase {
    private let key = KeyCombo(.upArrow)

    private func stick(normalizedX: Double, normalizedY: Double = 0) -> XInputStick {
        XInputStick(
            rawX: Int16((normalizedX * 32_767).rounded()),
            rawY: Int16((-normalizedY * 32_767).rounded())
        )
    }

    private func advance(
        _ performance: inout PadPerformance,
        seconds: Double = 0.1
    ) -> [PerformanceEffect] {
        performance.advance(seconds: seconds, leftStick: .center, rightStick: .center)
    }

    // MARK: - Holding one action

    func testPressingAKeyHoldsItUntilItIsReleased() {
        var performance = PadPerformance()

        XCTAssertEqual(performance.press(.dpadUp, action: .key(key)), [.press(.key(key))])
        XCTAssertEqual(performance.release(.dpadUp), [.release(.key(key))])
    }

    func testReleasingAControlThatHoldsNothingEmitsNothing() {
        var performance = PadPerformance()

        XCTAssertEqual(performance.release(.dpadUp), [])
    }

    func testAMouseButtonIsHeldAndNeverRepeats() {
        var performance = PadPerformance()

        XCTAssertEqual(
            performance.press(.buttonA, action: .mouseButton(.left)),
            [.press(.mouseButton(.left))]
        )
        XCTAssertEqual(advance(&performance, seconds: 2.0), [], "a mouse button has no repeat")
        XCTAssertEqual(performance.release(.buttonA), [.release(.mouseButton(.left))])
    }

    // MARK: - Scrolling

    func testAMappedScrollActionScrollsOnPressAndHoldsNothing() {
        var performance = PadPerformance()

        XCTAssertEqual(
            performance.press(.dpadUp, action: .scrollLines(2)),
            [.scroll(pixels: Scroll.pixels(forLines: 2))]
        )
        XCTAssertEqual(performance.release(.dpadUp), [], "a press that only scrolled holds nothing")
        XCTAssertEqual(advance(&performance), [])
    }

    func testTheRightStickScrollsThroughTheAccumulator() {
        var performance = PadPerformance()

        let first = performance.advance(
            seconds: 0.05,
            leftStick: .center,
            rightStick: stick(normalizedX: 0, normalizedY: 1)
        )
        let second = performance.advance(
            seconds: 0.05,
            leftStick: .center,
            rightStick: stick(normalizedX: 0, normalizedY: 1)
        )

        // Same cadence the engine used: the fraction of a pixel is carried, not dropped, so slow
        // scrolling moves smoothly instead of stepping a whole line every few ticks.
        XCTAssertEqual(first, [.scroll(pixels: 11)])
        XCTAssertEqual(second, [.scroll(pixels: 11)])
    }

    // MARK: - Commands

    func testACommandEmitsItsFirstStepOnPressAndOneStepPerAdvance() {
        let steps = [KeyCombo(keyCode: 0, modifiers: [.command]), KeyCombo(keyCode: 8, modifiers: [.command])]
        var performance = PadPerformance()

        XCTAssertEqual(
            performance.press(.buttonA, action: .sequence(steps)),
            [.press(.key(steps[0])), .release(.key(steps[0]))],
            "the first step answers the press without waiting for a tick"
        )
        XCTAssertEqual(
            advance(&performance),
            [.press(.key(steps[1])), .release(.key(steps[1]))]
        )
        XCTAssertEqual(advance(&performance), [], "the run is over after its last step")
        XCTAssertEqual(performance.release(.buttonA), [], "a command is a run, not a hold")
    }

    func testReleasingDropsTheStepsThatWereStillPending() {
        let steps = [
            KeyCombo(keyCode: 0, modifiers: [.command]),
            KeyCombo(keyCode: 8, modifiers: [.command]),
            KeyCombo(keyCode: 9, modifiers: [.command]),
        ]
        var performance = PadPerformance()
        _ = performance.press(.buttonA, action: .sequence(steps))
        _ = advance(&performance)

        XCTAssertEqual(performance.release(.buttonA), [])
        XCTAssertEqual(advance(&performance), [], "the remaining steps belong to a press that ended")
    }

    // MARK: - Repeats

    func testAHeldKeyRepeatsOnlyAfterTheInitialDelay() {
        let profile = InputProfile(
            mappings: [.dpadUp: .key(key)],
            keyRepeat: KeyRepeatSettings(initialDelay: 0.2, interval: 0.05)
        )
        var performance = PadPerformance(profile: profile)
        _ = performance.press(.dpadUp, action: .key(key))

        XCTAssertEqual(advance(&performance, seconds: 0.1), [], "must not repeat before the delay")
        XCTAssertEqual(advance(&performance, seconds: 0.15), [.repeatKey(.key(key))])
    }

    func testAtMostOneRepeatPerAdvance() {
        let profile = InputProfile(
            mappings: [.dpadUp: .key(key)],
            keyRepeat: KeyRepeatSettings(initialDelay: 0.1, interval: 0.05)
        )
        var performance = PadPerformance(profile: profile)
        _ = performance.press(.dpadUp, action: .key(key))

        // A stalled callback must not burst several key-downs at once: one advance, one repeat.
        XCTAssertEqual(advance(&performance, seconds: 2.0), [.repeatKey(.key(key))])
        XCTAssertEqual(advance(&performance, seconds: 0.001), [], "the next repeat is a full interval away")
    }

    func testAModifierHoldNeverRepeats() {
        let profile = InputProfile(
            mappings: [.dpadUp: .key(KeyCombo(keyCode: 59, modifiers: [.shift]))],
            keyRepeat: KeyRepeatSettings(initialDelay: 0.2, interval: 0.05)
        )
        var performance = PadPerformance(profile: profile)
        _ = performance.press(.dpadUp, action: .key(KeyCombo(keyCode: 59, modifiers: [.shift])))

        XCTAssertEqual(advance(&performance, seconds: 2.0), [])
    }

    func testAReleaseStopsTheRepeatsAndStillReleasesTheKey() {
        let profile = InputProfile(
            mappings: [.dpadUp: .key(key)],
            keyRepeat: KeyRepeatSettings(initialDelay: 0.2, interval: 0.05)
        )
        var performance = PadPerformance(profile: profile)
        _ = performance.press(.dpadUp, action: .key(key))
        _ = advance(&performance, seconds: 0.3)

        XCTAssertEqual(performance.release(.dpadUp), [.release(.key(key))])
        XCTAssertEqual(advance(&performance, seconds: 1.0), [])
    }

    // MARK: - Cursor

    func testTheLeftStickMovesTheCursorByTheTimeThatPassed() {
        var performance = PadPerformance()
        let left = stick(normalizedX: 1)
        let expected = StickMotion.cursorVelocity(stick: left, settings: CursorSettings.standard)

        XCTAssertEqual(
            performance.advance(seconds: 0.25, leftStick: left, rightStick: .center),
            [.moveCursor(deltaX: expected.dx * 0.25, deltaY: expected.dy * 0.25)]
        )
    }

    func testACentredLeftStickMovesNothingAndNonPositiveTimeDoesNothing() {
        var performance = PadPerformance()

        XCTAssertEqual(advance(&performance), [])
        XCTAssertEqual(
            performance.advance(seconds: 0, leftStick: stick(normalizedX: 1), rightStick: .center),
            []
        )
        XCTAssertEqual(
            performance.advance(seconds: -1, leftStick: stick(normalizedX: 1), rightStick: .center),
            []
        )
    }

    // MARK: - The safety net

    func testResetReleasesEverythingHeldAndDropsTheRun() {
        let steps = [KeyCombo(keyCode: 0, modifiers: [.command]), KeyCombo(keyCode: 8, modifiers: [.command])]
        var performance = PadPerformance()
        _ = performance.press(.buttonA, action: .mouseButton(.left))
        _ = performance.press(.dpadUp, action: .key(key))
        _ = performance.press(.buttonB, action: .sequence(steps))
        _ = advance(&performance)

        let released = performance.reset()

        XCTAssertEqual(released.count, 2, "each held action is released once")
        // The order of the releases follows the held actions, which is unspecified; what matters is
        // that every one of them is let go, exactly once.
        XCTAssertTrue(released.contains(.release(.mouseButton(.left))))
        XCTAssertTrue(released.contains(.release(.key(key))))
        XCTAssertEqual(advance(&performance), [], "the command stopped with the reset")
        XCTAssertEqual(performance.release(.buttonA), [], "nothing is held any more")
        XCTAssertEqual(performance.release(.dpadUp), [])
    }

    func testResetAlsoForgetsTheRepeatAndScrollState() {
        let profile = InputProfile(
            mappings: [.dpadUp: .key(key)],
            keyRepeat: KeyRepeatSettings(initialDelay: 0.2, interval: 0.05)
        )
        var performance = PadPerformance(profile: profile)
        _ = performance.press(.dpadUp, action: .key(key))
        _ = advance(&performance, seconds: 0.1)
        _ = performance.advance(
            seconds: 0.05,
            leftStick: .center,
            rightStick: stick(normalizedX: 0, normalizedY: 0.2)
        )

        _ = performance.reset()

        // No carried scroll fraction and no repeat elapsed time survive the reset.
        XCTAssertEqual(advance(&performance, seconds: 0.05), [])
        XCTAssertEqual(
            performance.advance(seconds: 0.05, leftStick: .center, rightStick: .center),
            []
        )
    }

    func testResetOnAFreshPerformanceEmitsNothing() {
        var performance = PadPerformance()

        XCTAssertEqual(performance.reset(), [])
    }
}
