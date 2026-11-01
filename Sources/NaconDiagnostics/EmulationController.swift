import AppKit
import Combine
import Foundation
import NaconCore

/// Owns the emulation engine and the UI state that protects it.
@MainActor
final class EmulationController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var hasAccessibility = AccessibilityPermission.isGranted
    @Published private(set) var stoppedByPad = false
    @Published private(set) var startedByPad = false
    /// The pad stopped sending. Nothing was disabled: a hub stall is not the user asking to stop.
    @Published private(set) var padSilent = false

    private let engine = EmulationEngine(emitter: CGEventEmitter())
    /// Supplies the mapping to run. The app points it at the saved profiles, so a start uses the
    /// selected one (S1, S8); the standard mapping keeps the controller usable on its own.
    private var profileSource: @MainActor () -> InputProfile = { .standard }
    /// What the summary shows. A separate source because it wants the profile's display name too,
    /// which the engine does not carry.
    private var summarySource: @MainActor () -> MappingSummaryWindow.Content = {
        MappingSummaryWindow.Content(title: AppText.resolve("Standard profile"), profile: .standard)
    }
    private let summary = MappingSummaryWindow()
    private var cancellables: Set<AnyCancellable> = []
    private var permissionTimer: Timer?
    /// The profile a step from the pad leads to, or `nil` when the selection did not change.
    /// The library decides which profile that is; the controller only carries the answer across.
    private var profileStepper: @MainActor (ProfileStep) -> InputProfile? = { _ in nil }
    private var terminationObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    /// Whether the engine and its observers are already wired to a service.
    private var isAttached = false

    init() {
        engine.onEmergencyStop = { [weak self] in
            DispatchQueue.main.async {
                self?.isEnabled = false
                self?.stoppedByPad = true
            }
        }
        // S12: the opposite direction. It also fires on the USB I/O queue, so the hop to the main
        // queue comes first: the published state must not be touched from there.
        engine.onGuidePress = { [weak self] in
            DispatchQueue.main.async {
                self?.startFromPad()
            }
        }
        // MOD+PS: the floating summary. Same hop as the other callbacks: the pad reports arrive on
        // the USB I/O queue, and the panel is main-thread only.
        engine.onPadSilence = { [weak self] in
            DispatchQueue.main.async { self?.padSilent = true }
        }
        engine.onPadResume = { [weak self] in
            DispatchQueue.main.async { self?.padSilent = false }
        }
        engine.onSummaryPress = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleSummary()
            }
        }
        // S5, S6: a control assigned to a profile step. It arrives on the engine's queue like the rest
        // of the report-driven callbacks, so the hop to the main queue comes first: the library and the
        // published state are main-thread only.
        engine.onProfileStep = { [weak self] step in
            DispatchQueue.main.async {
                self?.switchProfile(step)
            }
        }
    }

    /// S5, S6: makes the profile one step away the active one, without stopping the emulation.
    ///
    /// The library chooses which profile that is (S6) and the engine performs the atomic switch (S5):
    /// it releases what the old profile claimed and only then applies the new one. Nothing here stops
    /// or restarts the run, so a step in the middle of a movement does not even blink — and a step
    /// while the emulation is stopped does nothing at all, because there is no mapping to switch.
    private func switchProfile(_ step: ProfileStep) {
        guard isEnabled else { return }
        guard let profile = profileStepper(step) else { return }
        engine.switchProfile(to: profile)
    }

    /// Switches to a profile chosen in the window while the emulation runs.
    ///
    /// It goes through `EmulationEngine.switchProfile(to:)`, the same path the pad's profile step uses,
    /// so the atomic part — release everything the old profile claimed, then apply the new one — is not
    /// reimplemented here. A call while emulation is stopped does nothing: there is no mapping to swap.
    func switchToProfile(_ profile: InputProfile) {
        guard isEnabled else { return }
        engine.switchProfile(to: profile)
    }

    /// Opens or closes the mapping summary. One entry point for the pad gesture, the window button, the
    /// menu bar item and the `--show-summary` launch argument, so the four cannot diverge.
    func toggleSummary() {
        summary.toggle(with: summarySource())
    }

    /// S12: Guide asked to start the emulation.
    ///
    /// A denied Accessibility permission leaves everything untouched: starting without it would
    /// inject nothing, and the pad would look ignored instead of blocked by a missing permission.
    private func startFromPad() {
        guard !isEnabled, GuideToggle.canStartFromPad(hasAccessibility: hasAccessibility) else { return }
        setEnabled(true)
        startedByPad = isEnabled
    }

    func attach(to service: ControllerService, profiles: ProfileLibraryController) {
        // A second `onAppear` must not install a second timer, a second observer or a second report
        // hook. `shutdown` clears the flag, so attaching again after a real teardown still works.
        guard !isAttached else { return }
        isAttached = true

        // S1, S8: the engine reads the library every time emulation starts, so the profile selected
        // in the window — including the one restored from disk after a relaunch — is the one used.
        profileSource = { profiles.library.runtimeProfile }
        summarySource = {
            MappingSummaryWindow.Content(
                title: profiles.library.selectedProfile?.name ?? AppText.resolve("Standard profile"),
                profile: profiles.library.runtimeProfile
            )
        }
        // S6: the step is a step of the library selection, in list order with wraparound, and the new
        // selection is saved like any other change so the picker and the next start agree with it.
        // The step is pure inside `ProfileLibrary`; the seam that publishes and saves the result is
        // the same one every other write in the window uses.
        profileStepper = { step in
            var stepped = false
            profiles.edit { library in
                stepped = library.stepProfile(step)
            }
            // A refused step leaves the library untouched and reports nothing to switch to.
            return stepped ? profiles.library.runtimeProfile : nil
        }

        // S6: stopping the emulation — from the pad, the button or an unplugged pad — closes the
        // summary along with everything else the run had open.
        // dropFirst: the subscription delivers the current value as soon as it is installed, and at
        // attach time the summary may be open from the `--show-summary` launch argument — closing it
        // then would make the panel flicker away the instant the window appears.
        $isEnabled.dropFirst()
            .sink { [weak self] running in
                if !running {
                    self?.summary.hide()
                }
            }
            .store(in: &cancellables)

        // Capture the engine, not self: this closure runs on the USB I/O queue.
        let engine = self.engine
        service.reportObserver = { report in
            engine.ingest(report)
        }
        engine.start()

        service.$state
            .sink { [weak self] state in
                guard let self, !state.isConnected, self.isEnabled else { return }
                self.isEnabled = false
                engine.setEnabled(false)
            }
            .store(in: &cancellables)

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.shutdown()
            }
        }

        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshPermission()
            }
        }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.hasAccessibility = AccessibilityPermission.isGranted
            }
        }
    }

    func shutdown() {
        engine.stop()
        isAttached = false
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
            self.terminationObserver = nil
        }
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        permissionTimer?.invalidate()
        permissionTimer = nil
        cancellables.removeAll()
        isEnabled = false
        padSilent = false
    }

    func setEnabled(_ newValue: Bool) {
        stoppedByPad = false
        startedByPad = false
        guard newValue else {
            isEnabled = false
            padSilent = false
            engine.setEnabled(false)
            return
        }
        guard AccessibilityPermission.isGranted else {
            hasAccessibility = AccessibilityPermission.requestPrompt()
            isEnabled = false
            engine.setEnabled(false)
            return
        }
        hasAccessibility = true
        // S1, S8: the profile in force is the one captured at start. Editing a mapping or switching
        // profiles while emulation runs therefore cannot disturb an in-flight press: the next start
        // reads the library again.
        engine.setProfile(profileSource())
        isEnabled = true
        engine.setEnabled(true)
    }

    func requestAccessibility() {
        hasAccessibility = AccessibilityPermission.requestPrompt()
    }

    /// Re-reads the trust state without prompting. Useful after changing System Settings.
    func refreshPermission() {
        hasAccessibility = AccessibilityPermission.isGranted
    }
}
