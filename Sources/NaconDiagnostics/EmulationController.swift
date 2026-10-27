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

    private let engine = EmulationEngine(emitter: CGEventEmitter())
    /// Supplies the mapping to run. The app points it at the saved profiles, so a start uses the
    /// selected one (S1, S8); the standard mapping keeps the controller usable on its own.
    private var profileSource: @MainActor () -> InputProfile = { .standard }
    private var cancellables: Set<AnyCancellable> = []
    private var permissionTimer: Timer?
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
    }

    func attach(to service: ControllerService, profiles: ProfileLibraryController) {
        // A second `onAppear` must not install a second timer, a second observer or a second report
        // hook. `shutdown` clears the flag, so attaching again after a real teardown still works.
        guard !isAttached else { return }
        isAttached = true

        // S1, S8: the engine reads the library every time emulation starts, so the profile selected
        // in the window — including the one restored from disk after a relaunch — is the one used.
        profileSource = { profiles.runtimeProfile }

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
    }

    func setEnabled(_ newValue: Bool) {
        stoppedByPad = false
        guard newValue else {
            isEnabled = false
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
