import AppKit
import NaconCore

/// Owns the key-capture session so the event monitor exists only while a capture is armed.
///
/// The decisions are not here: `KeyCaptureSession` decides whether arming is safe, what a press
/// becomes, when the capture ends and which profile the mapping belongs to. This object is the
/// AppKit translation layer -- it installs the monitor, reads the key code and modifiers, and hands
/// the outcome to the view -- plus the observable wrapper SwiftUI needs to redraw the rows.
///
/// One instance belongs to `ProfileSection`, which hands it to the table and to the graphical view:
/// both arms are therefore the same session, and a capture started in one view follows the same rules
/// as the other.
///
/// The session is the implementation, not the interface: no view reads it. The two mapping surfaces
/// ask this object which control is armed, whether anything is armed at all, and which column of a
/// given control is waiting, so «which cell is waiting for a key» is derived in one place instead of
/// in every drawing that needs it.
///
/// A local monitor is used on purpose: it sees the press before the rest of the app and can swallow
/// it, so the captured shortcut never reaches a text field or a menu. Normal typing is untouched
/// because nothing is installed outside a capture, and `end()` always removes the monitor, whether
/// the capture succeeds, is cancelled with Escape, emulation starts, or the view disappears.
@MainActor
final class MappingCapture: ObservableObject {
    /// Private on purpose: the session is the implementation. Views ask the questions below.
    ///
    /// It stays published even though nothing outside this file reads it: mutating it is what makes
    /// the rows and the drawing re-render when the state machine moves.
    @Published private var session = KeyCaptureSession()

    /// Called once per finished capture with the outcome, which carries the profile the capture was
    /// armed for.
    var onFinish: ((KeyCaptureSession.Outcome) -> Void)?

    private var monitor: Any?

    /// The control the strip talks about while a capture waits for a key, and `nil` otherwise.
    var armedControl: XInputControl? {
        session.armedControl
    }

    /// Whether any capture is armed at all.
    ///
    /// A derived boolean rather than the optional control on purpose: the drawing observes this to
    /// clear its last pick when a capture ends, and re-arming a different control must not fire it,
    /// which testing the optional would.
    var isArmed: Bool {
        session.isArmed
    }

    /// S2: whether the capture is waiting for a key in one particular column. `nil` means this
    /// control is not the armed one.
    ///
    /// The armed control and the intent both have to match, so arming the same control from the other
    /// column lights the other cell and leaves this one reading its normal label.
    func armedColumn(for candidate: XInputControl) -> MappingColumn? {
        guard session.isArmed(candidate) else { return nil }
        return (session.intent ?? .base).column
    }

    /// Arms a control for one profile with the destination the button declared, or disarms it when it
    /// is already the one being captured. This is what the two capture buttons and the drawing tap do,
    /// so cancelling stays reachable: the button says «Cancelar» as soon as its control is armed.
    /// The refusal while emulation runs is a result, so the caller never has to guess.
    func toggle(
        _ candidate: XInputControl,
        for profileID: UUID,
        intent: CaptureIntent = .base,
        isEmulationRunning: Bool
    ) {
        follow(
            session.toggle(
                candidate,
                for: profileID,
                intent: intent,
                isEmulationRunning: isEmulationRunning
            )
        )
    }

    /// Arms a control with one destination and never cancels, which is what a menu entry does:
    /// choosing a destination is not a request to cancel the capture in flight, so a pick while one is
    /// armed re-arms it instead of ending it.
    func arm(
        _ candidate: XInputControl,
        for profileID: UUID,
        intent: CaptureIntent = .base,
        isEmulationRunning: Bool
    ) {
        follow(
            session.arm(
                candidate,
                for: profileID,
                intent: intent,
                isEmulationRunning: isEmulationRunning
            )
        )
    }

    /// Keeps the monitor alive exactly while a capture is armed, whichever call got there.
    private func follow(_ result: KeyCaptureSession.ArmResult) {
        switch result {
        case .armed:
            installMonitor()
        case .disarmed, .refusedWhileEmulating:
            removeMonitor()
        }
    }

    /// Removes the monitor and forgets the armed control and profile. Safe to call at any time.
    func end() {
        session.disarm()
        removeMonitor()
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            // Only sendable values cross into the isolated block; the event itself is main-thread
            // only and must not be captured there.
            let keyCode = event.keyCode
            let modifiers = ModifierSet(event.modifierFlags)
            let consumed = MainActor.assumeIsolated {
                self.handle(keyCode: keyCode, modifiers: modifiers)
            }
            // Swallowing the press keeps the shortcut out of the rest of the app.
            return consumed ? nil : event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handle(keyCode: UInt16, modifiers: ModifierSet) -> Bool {
        let outcome = session.handleKey(keyCode: keyCode, modifiers: modifiers)
        guard outcome != .ignored else { return false }
        // A finished capture always disarms, so the monitor goes away with it. The destination has
        // already travelled out inside the outcome, so nothing about it is left to clear here.
        removeMonitor()
        onFinish?(outcome)
        return true
    }
}

extension ModifierSet {
    /// The modifiers held in an `NSEvent`, ignoring caps lock, fn and the device-dependent bits.
    init(_ flags: NSEvent.ModifierFlags) {
        var modifiers: ModifierSet = []
        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        self = modifiers
    }
}
