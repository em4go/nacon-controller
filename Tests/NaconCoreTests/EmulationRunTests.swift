import XCTest
@testable import NaconCore

/// The composition the window used to spell out with eleven wires, now a value a test can drive.
///
/// The engine is injected, so every case runs the same composition the app runs: a recording emitter, an
/// injected clock and a `deliver` that runs the hop inline. The four sources are the only fakes, which is
/// the point — the rules are the production ones.
final class EmulationRunTests: XCTestCase {
    private var emitter: RecordingEmitter!
    private var engine: EmulationEngine!
    private var run: EmulationRun!
    private var now: TimeInterval = 1_000

    private var profileSource: InputProfile = .standard
    private var titleSource: String? = "Ratón"
    private var isPermitted = true
    private var stepperCalls: [ProfileStep] = []
    private var stepAnswer: InputProfile?
    private var summaryRequests = 0

    /// The two profiles a start and a step are told apart with: same shape, different key.
    private var profileA: InputProfile {
        InputProfile(
            mappings: [
                .buttonA: .key(KeyCombo(.escape)),
                .buttonB: .profileStep(.next),
            ],
            layer: ProfileLayer(key: .leftThumb)
        )
    }

    private var profileB: InputProfile {
        InputProfile(
            mappings: [
                .buttonA: .key(KeyCombo(.tab)),
                .buttonB: .profileStep(.next),
            ],
            layer: ProfileLayer(key: .leftThumb)
        )
    }

    override func setUp() {
        super.setUp()
        emitter = RecordingEmitter()
        engine = EmulationEngine(
            emitter: emitter,
            profile: .standard,
            uptime: { [weak self] in self?.now ?? 0 }
        )
        run = EmulationRun(engine: engine, deliver: { work in work() })
        profileSource = profileA
        titleSource = "Ratón"
        isPermitted = true
        stepperCalls = []
        stepAnswer = nil
        summaryRequests = 0
        run.attach(
            profile: { [weak self] in self?.profileSource ?? .standard },
            profileTitle: { [weak self] in self?.titleSource },
            step: { [weak self] step in
                guard let self else { return nil }
                stepperCalls.append(step)
                return stepAnswer
            },
            hasAccessibility: { [weak self] in self?.isPermitted ?? false }
        )
        run.onSummaryRequest = { [weak self] in self?.summaryRequests += 1 }
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

    // MARK: - The permission gate

    func testAStartWithoutThePermissionIsRefusedAndLeavesThePadInert() {
        isPermitted = false

        XCTAssertFalse(run.setEnabled(true), "a refused start must say so")
        XCTAssertFalse(run.status.isRunning)

        engine.drain()
        engine.handle(report(buttons: [.buttonA]))

        XCTAssertEqual(emitter.events, [], "nothing may reach the system without the permission")
    }

    func testAStartRecordsThatThePadAskedForIt() {
        // Guide is the pad's own start. The flag is what the window says out loud afterwards.
        engine.handle(report(buttons: [.guide]))

        XCTAssertTrue(run.status.isRunning)
        XCTAssertTrue(run.status.startedByPad)
        XCTAssertFalse(run.status.stoppedByPad)
    }

    func testGuideWhileRunningStopsTheRun() {
        run.setEnabled(true)
        engine.drain()

        engine.handle(report(buttons: [.guide]))
        // The engine reports its own emergency stop on the main queue, because that is where the window
        // lives; the run's hop lands behind it.
        drainMainQueue()

        XCTAssertFalse(run.status.isRunning)
        XCTAssertTrue(run.status.stoppedByPad)
        XCTAssertFalse(run.status.startedByPad)
    }

    // MARK: - The profile in force

    func testAStartRunsTheProfileInForceAtTheStartNotTheLaterOne() {
        XCTAssertTrue(run.setEnabled(true))
        engine.drain()

        // The window may switch profiles or edit a mapping while the run is going. The in-flight press
        // keeps the mapping it started with, because that is what was captured.
        profileSource = profileB
        engine.handle(report(buttons: [.buttonA]))

        XCTAssertEqual(emitter.events, [.press(.key(KeyCombo(.escape)))])
    }

    func testAStepWhileRunningSwitchesToTheProfileTheSourceAnswers() {
        stepAnswer = profileB
        run.setEnabled(true)
        engine.drain()

        engine.handle(report(buttons: [.buttonB]))
        XCTAssertEqual(stepperCalls, [.next], "the source is asked once, with the step the control carried")

        engine.drain()
        emitter.reset()
        engine.handle(report(buttons: [.buttonA]))

        XCTAssertEqual(emitter.events, [.press(.key(KeyCombo(.tab)))], "the new profile is the one running")
        XCTAssertTrue(run.status.isRunning, "a step is a change of mapping, not a stop")
    }

    func testAStepThatArrivesAfterTheRunStoppedAsksNothing() {
        // The run and the engine stop separately: the flag changes first, and a report already queued
        // inside the engine can still carry a step afterwards. That is the race the guard is for, so the
        // engine is left running on purpose while the run is stopped.
        engine.setProfile(profileA)
        engine.drain()
        engine.setEnabledNow(true)

        engine.handle(report(buttons: [.buttonB]))

        XCTAssertFalse(run.status.isRunning)
        XCTAssertEqual(stepperCalls, [], "a step must ask nothing once the run has stopped")
    }

    // MARK: - Silence

    func testThePadGoingSilentIsReportedAndTheReturnClearsIt() {
        run.setEnabled(true)
        engine.drain()
        engine.handle(report(buttons: []))

        now += EmulationEngine.silenceReleaseAfter + 0.05
        engine.advance(now: now)

        XCTAssertTrue(run.status.padSilent, "a hub stall is reported, not treated as a stop")
        XCTAssertTrue(run.status.isRunning, "nothing was disabled: the user did not ask to stop")

        engine.handle(report(buttons: []))

        XCTAssertFalse(run.status.padSilent)
    }

    // MARK: - Disconnection

    func testDisconnectingStopsTheRunAndClearsTheSilence() {
        run.setEnabled(true)
        engine.drain()
        engine.handle(report(buttons: []))
        now += EmulationEngine.silenceReleaseAfter + 0.05
        engine.advance(now: now)
        XCTAssertTrue(run.status.padSilent)

        run.padDisconnected()

        XCTAssertFalse(run.status.isRunning)
        XCTAssertFalse(run.status.padSilent)
    }

    // MARK: - The mapping summary

    func testTheSummaryUsesTheTitleSourceAndTheProfileInForce() {
        let summary = run.summary()

        XCTAssertEqual(summary.title, "Ratón")
        XCTAssertEqual(summary.profile, profileA)
    }

    func testTheSummaryFallsBackToTheStandardTitleWhenNothingIsSelected() {
        // The fallback is resolved through the catalog, so it follows the interface language instead of
        // shipping an English string into a Spanish window. Pinned here, restored after.
        let previous = Localization.language
        defer { Localization.language = previous }

        titleSource = nil

        Localization.language = .english
        XCTAssertEqual(run.summary().title, "Standard profile")

        Localization.language = .spanish
        XCTAssertEqual(run.summary().title, "Perfil estándar")
    }

    // MARK: - Helpers

    /// Waits for the work the engine posted to the main queue, so a status updated from there can be read.
    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }

    func testModPlusPsAsksForTheSummaryWithoutTouchingTheToggle() {
        run.setEnabled(true)
        engine.drain()

        engine.handle(report(buttons: [.leftThumb, .guide]))

        XCTAssertEqual(summaryRequests, 1, "reading the map must never toggle the emulation")
        XCTAssertTrue(run.status.isRunning)
        XCTAssertFalse(run.status.stoppedByPad)
    }
}
