import XCTest

@testable import NaconCore

/// The click count a real mouse declares: a double click is a press whose event says "second click",
/// not two presses the system quietly pairs up by itself.
///
/// The tracker is pure so this can be tested at all: the emitter needs a live event tap, so the
/// counting rules live here, where coordinates and time arrive as arguments.
final class ClickTrackerTests: XCTestCase {
    private let interval = 0.5

    func testTwoPressesWithinTheIntervalCountTwo() {
        var tracker = ClickTracker()
        XCTAssertEqual(tracker.press(of: .left, x: 100, y: 200, now: 10, interval: interval), 1)
        XCTAssertEqual(tracker.press(of: .left, x: 100, y: 200, now: 10.2, interval: interval), 2)
    }

    func testAGapLongerThanTheIntervalStartsAgain() {
        var tracker = ClickTracker()
        XCTAssertEqual(tracker.press(of: .left, x: 100, y: 200, now: 10, interval: interval), 1)
        XCTAssertEqual(tracker.press(of: .left, x: 100, y: 200, now: 10.6, interval: interval), 1)
    }

    func testDriftBeyondTheMaximumStartsAgain() {
        var tracker = ClickTracker()
        let far = ClickTracker.maximumDrift + 1
        XCTAssertEqual(tracker.press(of: .left, x: 100, y: 200, now: 10, interval: interval), 1)
        XCTAssertEqual(tracker.press(of: .left, x: 100 + far, y: 200, now: 10.1, interval: interval), 1)
    }

    func testADifferentButtonStartsAgain() {
        var tracker = ClickTracker()
        XCTAssertEqual(tracker.press(of: .left, x: 100, y: 200, now: 10, interval: interval), 1)
        XCTAssertEqual(tracker.press(of: .right, x: 100, y: 200, now: 10.1, interval: interval), 1)
    }

    func testAThirdPressCountsThree() {
        var tracker = ClickTracker()
        XCTAssertEqual(tracker.press(of: .left, x: 100, y: 200, now: 10, interval: interval), 1)
        XCTAssertEqual(tracker.press(of: .left, x: 100, y: 200, now: 10.2, interval: interval), 2)
        XCTAssertEqual(tracker.press(of: .left, x: 100, y: 200, now: 10.4, interval: interval), 3)
    }

    func testTheReleaseCarriesTheCountAndResetStartsAgain() {
        var tracker = ClickTracker()
        XCTAssertEqual(tracker.press(of: .left, x: 100, y: 200, now: 10, interval: interval), 1)
        XCTAssertEqual(tracker.press(of: .left, x: 100, y: 200, now: 10.2, interval: interval), 2)
        // The up of a double click says "second click" too, otherwise the view sees a count of one.
        XCTAssertEqual(tracker.releaseState(), 2)
        tracker.reset()
        XCTAssertEqual(tracker.press(of: .left, x: 100, y: 200, now: 10.3, interval: interval), 1)
    }
}
