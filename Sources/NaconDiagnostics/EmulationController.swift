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
    private var cancellables: Set<AnyCancellable> = []
    private var permissionTimer: Timer?
    private var terminationObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?

    init() {
        engine.onEmergencyStop = { [weak self] in
            DispatchQueue.main.async {
                self?.isEnabled = false
                self?.stoppedByPad = true
            }
        }
    }

    func attach(to service: ControllerService) {
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
