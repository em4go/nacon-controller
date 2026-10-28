import XCTest

@testable import NaconCore

private final class RecordingEmitter: InputEmitter {
    enum Event: Equatable {
        case press(MappedAction)
        case release(MappedAction)
        case move(deltaX: Double, deltaY: Double)
        case scroll(Int)
    }

    private(set) var events: [Event] = []

    func press(_ action: MappedAction) {
        events.append(.press(action))
    }

    func release(_ action: MappedAction) {
        events.append(.release(action))
    }

    func moveCursor(deltaX: Double, deltaY: Double) {
        events.append(.move(deltaX: deltaX, deltaY: deltaY))
    }

    func scroll(lines: Int) {
        events.append(.scroll(lines))
    }

    func reset() {
        events.removeAll()
    }
}

final class EmulationEngineTests: XCTestCase {
    private var emitter: RecordingEmitter!
    private var engine: EmulationEngine!

    override func setUp() {
        super.setUp()
        emitter = RecordingEmitter()
        engine = EmulationEngine(emitter: emitter)
    }

    private func report(
        buttons: XInputButtons = [],
        left: XInputStick = .center,
        right: XInputStick = .center
    ) -> XInputReport {
        XInputReport(
            rawBytes: [],
            buttons: buttons,
            leftTrigger: 0,
            rightTrigger: 0,
            leftStick: left,
            rightStick: right
        )
    }

    private func stick(normalizedX: Double, normalizedY: Double = 0) -> XInputStick {
        XInputStick(
            rawX: Int16((normalizedX * 32_767).rounded()),
            rawY: Int16((-normalizedY * 32_767).rounded())
        )
    }

    func testDisabledEngineProducesNoEvents() {
        engine.setEnabledNow(false)
        engine.handle(report())
        engine.handle(report(buttons: [.buttonA]))
        XCTAssertTrue(emitter.events.isEmpty)
    }

    func testPressIsEmittedOnceAndReleasedOnce() {
        engine.setEnabledNow(true)
        engine.handle(report())
        engine.handle(report(buttons: [.buttonA]))
        engine.handle(report(buttons: [.buttonA]))
        engine.handle(report())

        XCTAssertEqual(emitter.events, [
            .press(.mouseButton(.left)),
            .release(.mouseButton(.left)),
        ])
    }

    func testGuideDisablesEmulationAndReleasesHeldActions() {
        engine.setEnabledNow(true)
        engine.handle(report())
        engine.handle(report(buttons: [.buttonA]))
        engine.handle(report(buttons: [.buttonA, .guide]))
        emitter.reset()

        engine.handle(report(buttons: [.buttonB]))
        XCTAssertTrue(emitter.events.isEmpty, "emulation must stay off after the emergency stop")
        XCTAssertTrue(emitter.events.contains { if case .release = $0 { return true } else { return false } } == false)
    }

    func testGuideIsReportedWhileTheEmulationIsStopped() {
        var presses = 0
        engine.onGuidePress = { presses += 1 }

        engine.handle(report(buttons: [.guide]))

        XCTAssertEqual(presses, 1, "a stopped emulation has to hear Guide to be able to start it")
    }

    func testHoldingGuideReportsOnePressOnly() {
        // The engine clears `previousReport` when it stops, so an edge computed from nil would see the
        // same physical press again and start the emulation back up the instant it stopped.
        var presses = 0
        engine.onGuidePress = { presses += 1 }

        engine.handle(report(buttons: [.guide]))
        engine.handle(report(buttons: [.guide]))
        engine.handle(report(buttons: [.guide]))

        XCTAssertEqual(presses, 1)
    }

    func testGuideReportsAgainAfterBeingReleased() {
        var presses = 0
        engine.onGuidePress = { presses += 1 }

        engine.handle(report(buttons: [.guide]))
        engine.handle(report())
        engine.handle(report(buttons: [.guide]))

        XCTAssertEqual(presses, 2)
    }

    func testGuideStopsTheEmulationWithoutReportingAStart() {
        // While it runs, Guide is the engine's own emergency stop; only the stopped case needs the
        // app layer, so reporting both would toggle twice on one press.
        var presses = 0
        engine.onGuidePress = { presses += 1 }
        engine.setEnabledNow(true)
        engine.handle(report())

        engine.handle(report(buttons: [.guide]))

        XCTAssertEqual(presses, 0)
    }

    func testDisablingReleasesHeldActions() {
        engine.setEnabledNow(true)
        engine.handle(report())
        engine.handle(report(buttons: [.buttonA]))
        emitter.reset()

        engine.setEnabledNow(false)
        XCTAssertEqual(emitter.events, [.release(.mouseButton(.left))])
    }

    func testStopReleasesHeldActionsSynchronously() {
        engine.setEnabledNow(true)
        engine.handle(report())
        engine.handle(report(buttons: [.buttonA]))
        emitter.reset()

        engine.stop()

        // The release must already be posted when stop() returns: the process may exit next.
        XCTAssertEqual(emitter.events, [.release(.mouseButton(.left))])
    }

    private func makeEngine(profile: InputProfile) -> (EmulationEngine, RecordingEmitter) {
        let localEmitter = RecordingEmitter()
        let localEngine = EmulationEngine(emitter: localEmitter, profile: profile)
        localEngine.setEnabledNow(true)
        return (localEngine, localEmitter)
    }

    func testHeldKeyRepeatsAfterTheInitialDelay() {
        let profile = InputProfile(
            mappings: [.dpadUp: .key(KeyCombo(.upArrow))],
            keyRepeat: KeyRepeatSettings(initialDelay: 0.2, interval: 0.05)
        )
        let (localEngine, localEmitter) = makeEngine(profile: profile)
        localEngine.handle(report())
        localEngine.handle(report(buttons: [.dpadUp]))
        XCTAssertEqual(localEmitter.events, [.press(.key(KeyCombo(.upArrow)))])

        localEngine.tick(seconds: 0.1)
        XCTAssertEqual(localEmitter.events.count, 1, "must not repeat before the initial delay")

        localEngine.tick(seconds: 0.15)
        XCTAssertEqual(localEmitter.events.count, 2, "must repeat once the delay has passed")
    }

    func testReleaseStopsTheRepeats() {
        let profile = InputProfile(
            mappings: [.dpadUp: .key(KeyCombo(.upArrow))],
            keyRepeat: KeyRepeatSettings(initialDelay: 0.2, interval: 0.05)
        )
        let (localEngine, localEmitter) = makeEngine(profile: profile)
        localEngine.handle(report())
        localEngine.handle(report(buttons: [.dpadUp]))
        localEngine.tick(seconds: 0.3)
        localEngine.handle(report())
        let countAfterRelease = localEmitter.events.count

        localEngine.tick(seconds: 1.0)
        XCTAssertEqual(localEmitter.events.count, countAfterRelease)
        XCTAssertEqual(localEmitter.events.last, .release(.key(KeyCombo(.upArrow))))
    }

    func testHeldMouseButtonDoesNotRepeat() {
        let (localEngine, localEmitter) = makeEngine(profile: .standard)
        localEngine.handle(report())
        localEngine.handle(report(buttons: [.buttonA]))
        localEngine.tick(seconds: 1.0)
        XCTAssertEqual(localEmitter.events, [.press(.mouseButton(.left))])
    }

    func testTickMovesCursorOnlyWhenEnabled() {
        engine.handle(report(left: stick(normalizedX: 1)))
        engine.tick(seconds: 0.1)
        XCTAssertTrue(emitter.events.isEmpty, "a disabled engine must not move the cursor")

        engine.setEnabledNow(true)
        engine.tick(seconds: 0.1)
        guard case .move(let deltaX, let deltaY)? = emitter.events.first else {
            return XCTFail("expected a cursor move")
        }
        XCTAssertGreaterThan(deltaX, 0)
        XCTAssertEqual(deltaY, 0, accuracy: 1e-9)
    }

    func testCursorMovementScalesWithElapsedTime() {
        engine.setEnabledNow(true)
        engine.handle(report(left: stick(normalizedX: 1)))
        engine.tick(seconds: 0.5)
        engine.tick(seconds: 0.5)
        let total = emitter.events.reduce(0.0) { partial, event in
            if case .move(let deltaX, _) = event { return partial + deltaX }
            return partial
        }
        XCTAssertEqual(total, 1_400, accuracy: 5)
    }

    func testCenteredStickProducesNoCursorEvent() {
        engine.setEnabledNow(true)
        engine.handle(report())
        engine.tick(seconds: 0.1)
        XCTAssertTrue(emitter.events.isEmpty)
    }

    func testScrollEmitsWholeLinesOnly() {
        engine.setEnabledNow(true)
        engine.handle(report(right: stick(normalizedX: 0, normalizedY: 1)))
        engine.tick(seconds: 0.05)
        XCTAssertTrue(emitter.events.isEmpty, "half a line must not be emitted")
        engine.tick(seconds: 0.05)
        XCTAssertEqual(emitter.events, [.scroll(1)])
    }

    // MARK: - The timer is a hint, not a metronome

    func testTheStepIsTheTimeThatReallyPassed() {
        // macOS coalesces the timer and throttles the app when it is in the background, which is
        // exactly when the emulation is used. A fixed step per callback made the cursor crawl there.
        XCTAssertEqual(
            EmulationEngine.tickStep(elapsed: 0.032, nominal: 1.0 / 60.0, limit: 0.1),
            0.032,
            accuracy: 1e-9
        )
    }

    func testTheFirstCallbackUsesTheNominalStep() {
        XCTAssertEqual(
            EmulationEngine.tickStep(elapsed: nil, nominal: 1.0 / 60.0, limit: 0.1),
            1.0 / 60.0,
            accuracy: 1e-9
        )
    }

    func testAStallCannotFlingThePointerAcrossTheScreen() {
        XCTAssertEqual(
            EmulationEngine.tickStep(elapsed: 5, nominal: 1.0 / 60.0, limit: 0.1),
            0.1,
            accuracy: 1e-9
        )
    }

    func testNonsenseElapsedFallsBackToTheNominalStep() {
        for elapsed in [0, -1, Double.nan, Double.infinity] {
            XCTAssertEqual(
                EmulationEngine.tickStep(elapsed: elapsed, nominal: 1.0 / 60.0, limit: 0.1),
                1.0 / 60.0,
                accuracy: 1e-9,
                "\(elapsed)"
            )
        }
    }
}
