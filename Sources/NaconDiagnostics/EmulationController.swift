import AppKit
import Combine
import Foundation
import NaconCore

/// The emulation, as the window needs it: the run in `NaconCore` plus the parts that are genuinely AppKit.
///
/// The rules — permission gate, Guide toggle, silence, profile step, the mapping summary's content — live
/// in `EmulationRun`, where they are tested. What stays here is what needs a window or the system: the
/// permission prompt and its poll, the two activation observers, the panel, and the quit flush.
@MainActor
final class EmulationController: ObservableObject {
    /// The run's status, kept current by one sink instead of four restatements of its flags.
    @Published private(set) var status = EmulationRun.Status()
    @Published private(set) var hasAccessibility = AccessibilityPermission.isGranted

    /// The window asks these four; the run owns them, so the answer cannot drift from its state.
    var isEnabled: Bool { status.isRunning }
    var stoppedByPad: Bool { status.stoppedByPad }
    var startedByPad: Bool { status.startedByPad }
    /// The pad stopped sending. Nothing was disabled: a hub stall is not the user asking to stop.
    var padSilent: Bool { status.padSilent }

    private let run: EmulationRun
    private let summary = MappingSummaryWindow()
    private var cancellables: Set<AnyCancellable> = []
    private var permissionTimer: Timer?
    private var terminationObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    /// Whether the run and its observers are already wired to a service.
    private var isAttached = false

    /// `run` is injectable so the composition can be driven without a pad; the app builds the one that
    /// posts real events and reads the real profiles.
    init(run: EmulationRun = EmulationRun(engine: EmulationEngine(emitter: CGEventEmitter()))) {
        self.run = run
        run.$status.assign(to: &$status)
    }

    /// Opens or closes the mapping summary. One entry point for the pad gesture, the window button, the
    /// menu bar item and the `--show-summary` launch argument, so the four cannot diverge.
    func toggleSummary() {
        // The content is the run's decision — the Perfil in force and its title, with the standard title
        // when nothing is selected — and the panel only renders what it is given.
        let shown = run.summary()
        summary.toggle(with: MappingSummaryWindow.Content(title: shown.title, profile: shown.profile))
    }

    /// Switches to a profile chosen in the window while the emulation runs.
    func switchToProfile(_ profile: InputProfile) {
        run.switchToProfile(profile)
    }

    func attach(to service: ControllerService, profiles: ProfileLibraryController) {
        // A second `onAppear` must not install a second timer, a second observer or a second report hook.
        // `shutdown` clears the flag, so attaching again after a real teardown still works.
        guard !isAttached else { return }
        isAttached = true

        // S1, S8: the run reads the library every time emulation starts, so the profile selected in the
        // window — including the one restored from disk after a relaunch — is the one used. The title is a
        // source of its own because the summary wants the profile's display name too, which the engine
        // does not carry.
        // S6: the step is a step of the library selection, in list order with wraparound, and the new
        // selection is saved like any other change so the picker and the next start agree with it. The
        // step is pure inside `ProfileLibrary`; the seam that publishes and saves the result is the same
        // one every other write in the window uses.
        run.attach(
            profile: { profiles.library.runtimeProfile },
            profileTitle: { profiles.library.selectedProfile?.name },
            step: { step in
                var stepped = false
                profiles.edit { library in
                    stepped = library.stepProfile(step)
                }
                // A refused step leaves the library untouched and reports nothing to switch to.
                return stepped ? profiles.library.runtimeProfile : nil
            },
            // The system is asked, not the cached copy this window publishes: a start that trusts a stale
            // flag either injects nothing or refuses a pad that is allowed to start.
            hasAccessibility: { AccessibilityPermission.isGranted }
        )

        // The pad asked for the summary (MOD+PS). The callback is the run's; the panel is this window's.
        run.onSummaryRequest = { [weak self] in
            self?.toggleSummary()
        }

        // S6: stopping the emulation — from the pad, the button or an unplugged pad — closes the summary
        // along with everything else the run had open.
        // dropFirst: the subscription delivers the current value as soon as it is installed, and at attach
        // time the summary may be open from the `--show-summary` launch argument — closing it then would
        // make the panel flicker away the instant the window appears.
        run.$status
            .map(\.isRunning)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] running in
                if !running {
                    self?.summary.hide()
                }
            }
            .store(in: &cancellables)

        // Capture the run, not self: this closure runs on the USB I/O queue. Forwarding a report touches
        // no published state — `ingest` only hands it to the engine's own queue.
        let run = self.run
        service.reportObserver = { report in
            run.ingest(report)
        }
        run.start()

        // S4: an unplugged pad stops the run. A run cannot outlive the thing it reads.
        service.$state
            .sink { [weak self] state in
                guard !state.isConnected else { return }
                self?.run.padDisconnected()
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
        // The run stops synchronously: the key releases must be posted before the process ends.
        run.shutdown()
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
    }

    func setEnabled(_ newValue: Bool) {
        guard run.setEnabled(newValue) else {
            // Refused: the Accessibility permission is missing and nothing was started. The prompt is the
            // app's, because it is a system sheet and this is the process that owns a window.
            hasAccessibility = AccessibilityPermission.requestPrompt()
            return
        }
        if newValue {
            hasAccessibility = true
        }
    }

    func requestAccessibility() {
        hasAccessibility = AccessibilityPermission.requestPrompt()
    }

    /// Re-reads the trust state without prompting. Useful after changing System Settings.
    func refreshPermission() {
        hasAccessibility = AccessibilityPermission.isGranted
    }
}
