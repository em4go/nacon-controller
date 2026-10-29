import XCTest

@testable import NaconCore

/// The click that stays down until it is pressed again.
final class StickyClickTests: XCTestCase {
    private func report(buttons: XInputButtons) -> XInputReport {
        XInputReport(
            rawBytes: [],
            buttons: buttons,
            leftTrigger: 0,
            rightTrigger: 0,
            leftStick: .center,
            rightStick: .center
        )
    }

    private func makeEngine(_ emitter: RecordingEmitter) -> EmulationEngine {
        let engine = EmulationEngine(
            emitter: emitter,
            profile: InputProfile(mappings: [.buttonY: .toggledMouseButton(.left)])
        )
        engine.setEnabledNow(true)
        return engine
    }

    func testTheLabelSaysItTogglesInBothLanguages() {
        let spanish = Locale(identifier: "es")
        let english = Locale(identifier: "en")

        XCTAssertEqual(MappedAction.toggledMouseButton(.left).displayName(in: spanish), "Alternar clic izquierdo")
        XCTAssertEqual(MappedAction.toggledMouseButton(.left).displayName(in: english), "Toggle left click")
        XCTAssertEqual(MappedAction.toggledMouseButton(.middle).displayName(in: spanish), "Alternar clic central")
        XCTAssertEqual(MappedAction.toggledMouseButton(.right).displayName(in: spanish), "Alternar clic derecho")
    }

    func testTheActionSurvivesASave() throws {
        let profile = InputProfile(mappings: [.buttonY: .toggledMouseButton(.right)])
        let decoded = try JSONDecoder().decode(
            InputProfile.self,
            from: JSONEncoder().encode(profile)
        )

        XCTAssertEqual(decoded.action(for: .buttonY), .toggledMouseButton(.right))
    }

    func testAPressTogglesOnceAndTheReleaseDoesNothing() {
        let emitter = RecordingEmitter()
        let engine = makeEngine(emitter)
        engine.handle(report(buttons: []))
        engine.handle(report(buttons: [.buttonY]))

        XCTAssertEqual(emitter.events, [.toggleMouseButton(.left)])
        engine.handle(report(buttons: []))
        XCTAssertEqual(
            emitter.events,
            [.toggleMouseButton(.left)],
            "letting go of the control must not undo what the press did"
        )
    }

    func testHoldingTheControlTogglesOnce() {
        let emitter = RecordingEmitter()
        let engine = makeEngine(emitter)
        engine.handle(report(buttons: []))
        for _ in 0..<30 {
            engine.tick(seconds: 1.0 / 60)
            engine.handle(report(buttons: [.buttonY]))
        }

        XCTAssertEqual(emitter.events, [.toggleMouseButton(.left)])
    }

    func testStoppingTheEmulationLetsGoOfEveryButton() {
        // The safety net: a toggled button left down would keep the system dragging after the user
        // asked the emulation to stop.
        let emitter = RecordingEmitter()
        let engine = makeEngine(emitter)
        engine.handle(report(buttons: []))
        engine.handle(report(buttons: [.buttonY]))
        engine.setEnabledNow(false)

        XCTAssertTrue(emitter.events.contains(.releaseAllMouseButtons))
    }

    func testPressingTwiceReturnsToWhereItStarted() {
        let emitter = RecordingEmitter()
        let engine = makeEngine(emitter)
        engine.handle(report(buttons: []))
        engine.handle(report(buttons: [.buttonY]))
        engine.handle(report(buttons: []))
        engine.handle(report(buttons: [.buttonY]))

        XCTAssertEqual(emitter.events, [.toggleMouseButton(.left), .toggleMouseButton(.left)])
    }
}
