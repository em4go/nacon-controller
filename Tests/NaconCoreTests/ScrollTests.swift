import XCTest

@testable import NaconCore

/// Smooth scrolling is a unit problem: a line event can only carry whole lines, so at walking pace
/// the view jumps once every few ticks. These pin the pixel path that replaced it.
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
        XCTAssertEqual(accumulator.consume(pixelsPerSecond: 100, seconds: 0.005), 0)
        XCTAssertEqual(accumulator.consume(pixelsPerSecond: 100, seconds: 0.005), 1)
    }

    func testTheSameDeflectionForTheSameSecondScrollsTheSameDistanceWhateverTheCadence() {
        func travelled(cadence: Double) -> Int {
            let recorder = RecordingEmitter()
            var now: TimeInterval = 0
            let engine = EmulationEngine(emitter: recorder, uptime: { now })
            engine.advance(now: 0)
            engine.setEnabledNow(true)
            engine.handle(Self.fullDownReport)
            let step = 1.0 / cadence
            for index in 1...Int(cadence) {
                now = Double(index) * step
                // Same reason as the cursor test: reports keep arriving while the stick is held.
                engine.handle(Self.fullDownReport)
                engine.advance(now: now)
            }
            return recorder.pixels
        }

        // Pushing the stick down reports a negative wheel delta, hence the magnitudes here.
        let fast = abs(travelled(cadence: 60))
        let slow = abs(travelled(cadence: 10))

        XCTAssertGreaterThan(fast, 0, "the test must not pass on an engine that never scrolls")
        XCTAssertEqual(slow, fast, accuracy: 4, "10 Hz must travel what 60 Hz travels")
    }

    func testNoSingleEventIsBiggerThanALineAndTheyArriveOften() {
        // The jerking the user reported: few, large jumps. Sixty small steps per second is smooth.
        let recorder = RecordingEmitter()
        var now: TimeInterval = 0
        let engine = EmulationEngine(emitter: recorder, uptime: { now })
        engine.advance(now: 0)
        engine.setEnabledNow(true)
        engine.handle(Self.fullDownReport)
        for index in 1...60 {
            now = Double(index) / 60.0
            // A live pad reports every 4 ms; without a report the engine freezes by design.
            engine.handle(Self.fullDownReport)
            engine.advance(now: now)
        }

        XCTAssertGreaterThanOrEqual(recorder.events.count, 50, "one event per frame, not one per line")
        for event in recorder.events {
            if case .scroll(let pixels) = event {
                XCTAssertLessThanOrEqual(abs(pixels), 16, "a single event must not jump a whole line")
            }
        }
    }

    func testTheSpeedRangeReachesAFastScroll() {
        XCTAssertEqual(CursorSensitivity.scrollSpeed.range.upperBound, 80)
        XCTAssertEqual(CursorSensitivity.scrollSpeed.clamp(500), 80)
        XCTAssertEqual(CursorSensitivity.scrollSpeed.clamp(60), 60)
    }

    private static var fullDownReport: XInputReport {
        XInputReport(
            rawBytes: [],
            buttons: [],
            leftTrigger: 0,
            rightTrigger: 0,
            leftStick: .center,
            rightStick: XInputStick(rawX: 0, rawY: 32_767)
        )
    }
}
