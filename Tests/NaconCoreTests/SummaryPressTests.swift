import XCTest

@testable import NaconCore

/// MOD+PS asks for the mapping summary; PS alone still toggles the emulation.
final class SummaryPressTests: XCTestCase {
    private var summaryPresses = 0
    private var starts = 0

    private var emitter: RecordingEmitter!

    private func makeEngine() -> EmulationEngine {
        emitter = RecordingEmitter()
        let engine = EmulationEngine(
            emitter: emitter,
            profile: InputProfile(
                mappings: [.buttonA: .key(KeyCombo(.escape))],
                layer: ProfileLayer(key: .leftThumb)
            )
        )
        engine.onSummaryPress = { [weak self] in self?.summaryPresses += 1 }
        engine.onGuidePress = { [weak self] in self?.starts += 1 }
        return engine
    }

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

    func testModAndPsShowTheSummaryWithoutTouchingTheToggle() {
        // Reading the map must never stop the pad: with the emulation running, MOD+PS shows the
        // summary and leaves the emulation alone.
        let engine = makeEngine()
        engine.setEnabledNow(true)
        engine.handle(report(buttons: [.leftThumb, .guide]))

        XCTAssertEqual(summaryPresses, 1)
        XCTAssertEqual(starts, 0)

        // Still enabled: a mapped control keeps emitting after the summary was shown.
        emitter.reset()
        engine.handle(report(buttons: [.leftThumb]))
        engine.handle(report(buttons: [.buttonA]))
        XCTAssertEqual(emitter.events.first, .press(.key(KeyCombo(.escape))))
    }

    func testModAndPsWorkWhileStopped() {
        // S3: the summary answers even when the pad is not emulating, without starting anything.
        let engine = makeEngine()
        engine.handle(report(buttons: [.leftThumb, .guide]))

        XCTAssertEqual(summaryPresses, 1)
        XCTAssertEqual(starts, 0)

        // Still stopped: the summary did not start anything.
        emitter.reset()
        engine.handle(report(buttons: [.buttonA]))
        XCTAssertEqual(emitter.events, [])
    }

    func testPsAloneStillToggles() {
        let engine = makeEngine()
        engine.handle(report(buttons: [.guide]))

        XCTAssertEqual(summaryPresses, 0)
        XCTAssertEqual(starts, 1)
    }

    func testOnePressOfModAndPsAsksOnce() {
        // The Guide latch holds the press until the buttons are released, so holding MOD+PS cannot
        // open and close the summary at report rate.
        let engine = makeEngine()
        for _ in 0..<20 {
            engine.handle(report(buttons: [.leftThumb, .guide]))
        }

        XCTAssertEqual(summaryPresses, 1)
    }
}
