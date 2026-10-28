import XCTest

@testable import NaconCore

private final class RecordingEmitter: InputEmitter {
    enum Event: Equatable {
        case press(MappedAction)
        case release(MappedAction)
        case move(deltaX: Double, deltaY: Double)
        case scroll(Int)
        case repeatKey(MappedAction)
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

    func repeatKey(_ action: MappedAction) {
        events.append(.repeatKey(action))
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
        XCTAssertEqual(
            localEmitter.events,
            [.press(.key(KeyCombo(.upArrow))), .repeatKey(.key(KeyCombo(.upArrow)))],
            "the repeat must not press the modifiers again"
        )
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

    /// The seam that once made the cursor crawl: a fixed step per callback.
    ///
    /// Same stick, same wall-clock second, two cadences: 60 Hz and 10 Hz. The slow one is what macOS
    /// does to the timer once the app is not in front, which is where this tool is used, and the
    /// distance travelled must not notice.
    func testTheSameStickForTheSameSecondMovesTheSameDistanceWhateverTheCadence() {
        func travelled(cadence: Double) -> Double {
            let recorder = RecordingEmitter()
            var now: TimeInterval = 0
            let clocked = EmulationEngine(emitter: recorder, uptime: { now })
            // Prime the clock while stopped so the first real advance measures a step instead of the
            // nominal fallback, which belongs to the first callback only.
            clocked.advance(now: 0)
            clocked.setEnabledNow(true)
            clocked.handle(report(left: stick(normalizedX: 1)))
            let step = 1.0 / cadence
            for index in 1...Int(cadence) {
                now = Double(index) * step
                clocked.advance(now: now)
            }
            return recorder.events.reduce(0) { total, event in
                if case .move(let deltaX, _) = event { return total + deltaX }
                return total
            }
        }

        let fast = travelled(cadence: 60)
        let slow = travelled(cadence: 10)

        XCTAssertGreaterThan(fast, 0, "the test must not pass on an engine that never moves")
        XCTAssertEqual(slow, fast, accuracy: fast * 0.001)
    }

    func testAStallAdvancesAtMostTheCap() {
        // Waking after five seconds must not fling the pointer across the screen: the step is capped at
        // 100 ms, so the engine moves as if a tenth of a second had passed.
        engine.advance(now: 0)
        engine.setEnabledNow(true)
        engine.handle(report(left: stick(normalizedX: 1)))
        emitter.reset()

        engine.advance(now: 5)

        let moves = emitter.events.compactMap { event -> Double? in
            if case .move(let deltaX, _) = event { return deltaX }
            return nil
        }
        let expected = StickMotion.cursorVelocity(
            stick: stick(normalizedX: 1),
            settings: InputProfile.standard.cursor
        ).dx * 0.1
        XCTAssertEqual(moves.count, 1)
        XCTAssertEqual(moves.first ?? 0, expected, accuracy: abs(expected) * 0.001)
    }

    func testTheFirstCallbackAndNonsenseElapsedFallBackToTheNominalStep() {
        // `nil` is the first callback: no previous reading, so the nominal step is the only sane one.
        for elapsed in [nil, 0, -1, Double.nan, Double.infinity] as [TimeInterval?] {
            XCTAssertEqual(
                EmulationEngine.tickStep(elapsed: elapsed, nominal: 1.0 / 60.0, limit: 0.1),
                1.0 / 60.0,
                accuracy: 1e-9,
                "\(elapsed)"
            )
        }
    }
}
