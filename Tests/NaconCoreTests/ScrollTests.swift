import XCTest

@testable import NaconCore

/// Smooth scrolling is a unit problem: a line event can only carry whole lines, so at walking pace
/// the view jumps once every few ticks. These pin the pixel path that replaced it, on both axes.
final class ScrollTests: XCTestCase {
    func testALineIsAWholeNumberOfPixels() {
        XCTAssertEqual(Scroll.pixels(forLines: 1), 16)
        XCTAssertEqual(Scroll.pixels(forLines: 3), 48)
        XCTAssertEqual(Scroll.pixels(forLines: -2), -32, "scrolling up must keep its sign")
        XCTAssertEqual(Scroll.pixels(forLines: 0), 0)
    }

    func testTheAccumulatorCarriesTheFractionInPixels() {
        var accumulator = ScrollAccumulator()
        // Half a pixel per tick is the slowest a hand can ask for; it must still arrive.
        XCTAssertEqual(accumulator.consume(pixelsPerSecondX: 0, pixelsPerSecondY: 100, seconds: 0.005).y, 0)
        XCTAssertEqual(accumulator.consume(pixelsPerSecondX: 0, pixelsPerSecondY: 100, seconds: 0.005).y, 1)
    }

    func testTheAccumulatorKeepsOneFractionPerAxis() {
        // A fraction belongs to its own axis: a sideways push must never pay for the vertical one.
        var accumulator = ScrollAccumulator()
        let first = accumulator.consume(pixelsPerSecondX: 100, pixelsPerSecondY: 0, seconds: 0.005)
        XCTAssertEqual(first.x, 0)
        XCTAssertEqual(first.y, 0)
        let second = accumulator.consume(pixelsPerSecondX: 100, pixelsPerSecondY: 0, seconds: 0.005)
        XCTAssertEqual(second.x, 1, "the horizontal half-pixel must arrive")
        XCTAssertEqual(second.y, 0, "and must not appear on the vertical axis")
    }

    func testTheWheelSignMatchesWhatTheUserSeesOnEachAxis() {
        // What the system receives, not what the engine decided: this is the one place where the
        // sign can be wrong without any test noticing, and it was. Pushing the stick right moved the
        // content left, while pushing it down moved the content down.
        let right = Scroll.wheelDeltas(for: ScrollPixels(x: 24, y: 0))
        XCTAssertEqual(right.x, -24, "pushing right must move the content right, not left")
        XCTAssertEqual(right.y, 0)

        let down = Scroll.wheelDeltas(for: ScrollPixels(x: 0, y: 24))
        XCTAssertEqual(down.y, 24, "the vertical axis keeps the sign it always had")
        XCTAssertEqual(down.x, 0)

        let diagonal = Scroll.wheelDeltas(for: ScrollPixels(x: -8, y: 16))
        XCTAssertEqual(diagonal.x, 8, "a leftward push is the mirror image of a rightward one")
        XCTAssertEqual(diagonal.y, 16)
    }

    func testPushingTheRightStickRightScrollsHorizontally() {
        let events = scrollEvents(rightX: 32_767, rightY: 0)
        let horizontal = events.reduce(0) { $0 + $1.x }
        let vertical = events.reduce(0) { $0 + $1.y }
        XCTAssertGreaterThan(horizontal, 0, "pushing the stick right must scroll right")
        XCTAssertEqual(vertical, 0, "a sideways push must not move the page vertically")
    }

    func testPushingTheRightStickDownStillScrollsVertically() {
        // The axis that already worked. It is here so the new one cannot quietly take its place.
        let events = scrollEvents(rightX: 0, rightY: 32_767)
        let horizontal = events.reduce(0) { $0 + $1.x }
        let vertical = events.reduce(0) { $0 + $1.y }
        XCTAssertNotEqual(vertical, 0)
        XCTAssertEqual(horizontal, 0, "a vertical push must not move the page sideways")
    }

    func testADiagonalPushArrivesInOneEventWithBothAxes() {
        let events = scrollEvents(rightX: 32_767, rightY: 32_767)
        XCTAssertGreaterThan(events.count, 0)
        // One event carrying both axes, not two events: some views treat two wheel events as two
        // separate gestures, and a diagonal would arrive as a stagger.
        XCTAssertTrue(
            events.contains { $0.x != 0 && $0.y != 0 },
            "a diagonal push must reach the system as a single two-axis event"
        )
    }

    func testInsideTheDeadzoneNeitherAxisScrolls() {
        let inside = Int16(Double(Int16.max) * 0.05)
        let events = scrollEvents(rightX: inside, rightY: inside)
        XCTAssertEqual(events.count, 0, "a stick resting near the centre must not scroll at all")
    }

    func testTheSameDeflectionForTheSameSecondScrollsTheSameDistanceWhateverTheCadence() {
        func travelled(cadence: Double) -> (x: Int, y: Int) {
            let recorder = RecordingEmitter()
            var now: TimeInterval = 0
            let engine = EmulationEngine(emitter: recorder, uptime: { now })
            engine.advance(now: 0)
            engine.setEnabledNow(true)
            let report = Self.report(rightX: 32_767, rightY: 32_767)
            let step = 1.0 / cadence
            for index in 1...Int(cadence) {
                now = Double(index) * step
                // A live pad reports continuously; without a report the engine freezes by design.
                engine.handle(report)
                engine.advance(now: now)
            }
            return (recorder.scrolledX, recorder.scrolledY)
        }

        let fast = travelled(cadence: 60)
        let slow = travelled(cadence: 10)

        XCTAssertGreaterThan(fast.x, 0, "the test must not pass on an engine that never scrolls")
        XCTAssertEqual(slow.x, fast.x, accuracy: 4, "10 Hz must travel what 60 Hz travels horizontally")
        XCTAssertEqual(slow.y, fast.y, accuracy: 4, "10 Hz must travel what 60 Hz travels vertically")
    }

    func testNoSingleEventIsBiggerThanALineAndTheyArriveOften() {
        // The jerking the user reported: few, large jumps. Sixty small steps per second is smooth.
        let recorder = RecordingEmitter()
        var now: TimeInterval = 0
        let engine = EmulationEngine(emitter: recorder, uptime: { now })
        engine.advance(now: 0)
        engine.setEnabledNow(true)
        let report = Self.report(rightX: 32_767, rightY: 32_767)
        for index in 1...60 {
            now = Double(index) / 60.0
            // A live pad reports every 4 ms; without a report the engine freezes by design.
            engine.handle(report)
            engine.advance(now: now)
        }

        XCTAssertGreaterThanOrEqual(recorder.events.count, 50, "one event per frame, not one per line")
        for event in recorder.events {
            if case .scroll(let pixels) = event {
                XCTAssertLessThanOrEqual(abs(pixels.y), 16, "a single event must not jump a whole line")
                XCTAssertLessThanOrEqual(abs(pixels.x), 16, "and not sideways either")
            }
        }
    }

    func testTheSpeedRangeReachesAFastScroll() {
        XCTAssertEqual(CursorSensitivity.scrollSpeed.range.upperBound, 80)
        XCTAssertEqual(CursorSensitivity.scrollSpeed.clamp(500), 80)
        XCTAssertEqual(CursorSensitivity.scrollSpeed.clamp(60), 60)
    }

    // MARK: - Helpers

    /// Runs the engine for one second at 60 Hz with the right stick held at the given deflection.
    private func scrollEvents(rightX: Int16, rightY: Int16) -> [ScrollPixels] {
        let recorder = RecordingEmitter()
        var now: TimeInterval = 0
        let engine = EmulationEngine(emitter: recorder, uptime: { now })
        engine.advance(now: 0)
        engine.setEnabledNow(true)
        let report = Self.report(rightX: rightX, rightY: rightY)
        for index in 1...60 {
            now = Double(index) / 60.0
            engine.handle(report)
            engine.advance(now: now)
        }
        return recorder.scrollPixels
    }

    private static func report(rightX: Int16, rightY: Int16) -> XInputReport {
        XInputReport(
            rawBytes: [],
            buttons: [],
            leftTrigger: 0,
            rightTrigger: 0,
            leftStick: .center,
            rightStick: XInputStick(rawX: rightX, rawY: rightY)
        )
    }
}
