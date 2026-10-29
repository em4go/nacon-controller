import XCTest
@testable import NaconCore

/// A command of several steps: how it runs, and what stops it.
final class SequenceEngineTests: XCTestCase {
    private var selectAll: KeyCombo { KeyCombo(keyCode: 0, modifiers: [.command]) }
    private var copy: KeyCombo { KeyCombo(keyCode: 8, modifiers: [.command]) }

    private func makeEngine() -> (EmulationEngine, RecordingEmitter) {
        let emitter = RecordingEmitter()
        let engine = EmulationEngine(
            emitter: emitter,
            profile: InputProfile(mappings: [.buttonY: .sequence([selectAll, copy])])
        )
        engine.setEnabledNow(true)
        return (engine, emitter)
    }

    private func report(buttons: XInputButtons = []) -> XInputReport {
        XInputReport(
            rawBytes: [],
            buttons: buttons,
            leftTrigger: 0,
            rightTrigger: 0,
            leftStick: .center,
            rightStick: .center
        )
    }

    private func step(_ combo: KeyCombo) -> [RecordingEmitter.Event] {
        [.press(.key(combo)), .release(.key(combo))]
    }

    func testTheFirstStepGoesOutWithThePress() {
        let (engine, emitter) = makeEngine()
        engine.handle(report())
        engine.handle(report(buttons: [.buttonY]))

        XCTAssertEqual(emitter.events, step(selectAll), "the press must answer without waiting for a tick")
    }

    func testTheRemainingStepsGoOutOnePerTick() {
        let (engine, emitter) = makeEngine()
        engine.handle(report())
        engine.handle(report(buttons: [.buttonY]))
        engine.tick(seconds: 1.0 / 60)

        XCTAssertEqual(emitter.events, step(selectAll) + step(copy))
    }

    func testHoldingTheControlDoesNotRepeatTheCommand() {
        let (engine, emitter) = makeEngine()
        engine.handle(report())
        engine.handle(report(buttons: [.buttonY]))
        for _ in 0..<60 {
            engine.handle(report(buttons: [.buttonY]))
            engine.tick(seconds: 1.0 / 60)
        }

        XCTAssertEqual(emitter.events, step(selectAll) + step(copy), "a command is a run, not a repeat")
    }

    func testReleasingStopsTheStepsThatAreLeft() {
        let (engine, emitter) = makeEngine()
        engine.handle(report())
        engine.handle(report(buttons: [.buttonY]))
        engine.handle(report())

        XCTAssertEqual(emitter.events, step(selectAll), "the remaining steps belong to a press that ended")
        engine.tick(seconds: 1.0 / 60)
        XCTAssertEqual(emitter.events, step(selectAll))
    }

    func testStoppingTheEmulationDropsTheCommandAndNothingStaysHeld() {
        let (engine, emitter) = makeEngine()
        engine.handle(report())
        engine.handle(report(buttons: [.buttonY]))
        engine.setEnabledNow(false)

        // Stopping emits the mouse-button safety net as well; what matters is that no step fired.
        let fired = emitter.events.filter { $0 != .releaseAllMouseButtons }
        XCTAssertEqual(fired, step(selectAll), "no step may fire after the user stops the emulation")
        XCTAssertEqual(emitter.releasedHeldModifiers, 1)
    }
}
