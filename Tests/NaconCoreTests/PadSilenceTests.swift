import XCTest

@testable import NaconCore

/// What happens when the pad stops talking: freeze, then let go, then come back without clicking.
final class PadSilenceTests: XCTestCase {
    private var emitter: RecordingEmitter!
    private var engine: EmulationEngine!
    private var now: TimeInterval = 1_000
    private var silences = 0
    private var resumes = 0

    override func setUp() {
        super.setUp()
        emitter = RecordingEmitter()
        var clock = 0.0
        clock = 0
        engine = EmulationEngine(
            emitter: emitter,
            profile: InputProfile(mappings: [.buttonY: .key(KeyCombo(.escape))]),
            uptime: { [weak self] in self?.now ?? 0 }
        )
        engine.onPadSilence = { [weak self] in self?.silences += 1 }
        engine.onPadResume = { [weak self] in self?.resumes += 1 }
        engine.setEnabledNow(true)
        engine.handle(report(buttons: []))
        emitter.reset()
    }

    private func report(buttons: XInputButtons = [], left: XInputStick = .center) -> XInputReport {
        XInputReport(
            rawBytes: [],
            buttons: buttons,
            leftTrigger: 0,
            rightTrigger: 0,
            leftStick: left,
            rightStick: .center
        )
    }

    private func away(from offset: TimeInterval) -> XInputStick {
        XInputStick(rawX: Int16(32_767), rawY: 0)
    }

    func testAShortStallStopsMovingThePointer() {
        // The stick the engine moves with is the last one it was told, however old.
        engine.handle(report(left: away(from: 0)))
        emitter.reset()
        now += EmulationEngine.silenceFreezeAfter + 0.05
        engine.advance(now: now)

        XCTAssertEqual(emitter.events, [], "a stale stick must not keep moving the cursor")
    }

    func testALongSilenceLetsGoOfEverythingAndSaysSo() {
        engine.handle(report(buttons: [.buttonY]))
        emitter.reset()
        now += EmulationEngine.silenceReleaseAfter + 0.05
        engine.advance(now: now)

        XCTAssertTrue(emitter.events.contains(.release(.key(KeyCombo(.escape)))))
        XCTAssertTrue(emitter.events.contains(.releaseAllMouseButtons))
        XCTAssertEqual(emitter.releasedHeldModifiers, 1)
        XCTAssertEqual(silences, 1, "the window must be able to say the pad went quiet")
    }

    func testTheReleaseHappensOncePerSilence() {
        now += EmulationEngine.silenceReleaseAfter + 0.05
        engine.advance(now: now)
        let afterFirst = emitter.events.count
        engine.advance(now: now + 0.5)
        engine.advance(now: now + 1.0)

        XCTAssertEqual(emitter.events.count, afterFirst, "a silent pad must not be released over and over")
        XCTAssertEqual(silences, 1)
    }

    func testAControlHeldThroughTheSilenceIsNotPressedAgain() {
        // The user never let go: a fresh press on resume would be a click they did not make.
        engine.handle(report(buttons: [.buttonY]))
        now += EmulationEngine.silenceReleaseAfter + 0.05
        engine.advance(now: now)
        emitter.reset()

        now += 0.1
        engine.handle(report(buttons: [.buttonY]))

        XCTAssertEqual(emitter.events, [], "coming back must not re-press what was already down")
        XCTAssertEqual(resumes, 1)

        // Once released, the control behaves normally again.
        engine.handle(report(buttons: []))
        engine.handle(report(buttons: [.buttonY]))
        XCTAssertEqual(emitter.events, [.press(.key(KeyCombo(.escape)))])
    }

    func testStoppingClearsTheSilenceState() {
        now += EmulationEngine.silenceReleaseAfter + 0.05
        engine.advance(now: now)
        emitter.reset()
        engine.setEnabledNow(false)
        now += 5
        engine.advance(now: now)

        XCTAssertEqual(silences, 1, "a stopped engine has nothing to release")
    }
}
