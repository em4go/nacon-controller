import Foundation

/// S3, F5: the state machine behind the mapping editor's key capture.
///
/// The editor is SwiftUI and needs an `NSEvent` monitor to read a real press, but nothing that
/// decides *what* a press means belongs there. This value type owns the armed control, the profile
/// that control was armed for, and the end of a capture, so the behaviour can be checked without a
/// window, AppKit or an event loop. The view only translates: event → key code and modifiers →
/// outcome → one write.
///
/// Two invariants shape it:
///
/// - Arming is refused while emulation runs. Swapping a mapping underneath a held button can leave a
///   key stuck down, so the refusal is an ordinary result the caller can render, not a crash.
/// - A capture remembers the profile it was armed for and hands that identifier back with the
///   mapping. The profile selected when the key arrives is not necessarily the one the user was
///   looking at when they pressed «Capturar», so the caller can drop the write.
public struct KeyCaptureSession: Equatable, Sendable {
    /// What arming or toggling a control did.
    public enum ArmResult: Equatable, Sendable {
        /// The control now waits for one key press.
        case armed
        /// The control was already armed and the capture ended instead.
        case disarmed
        /// Refused because emulation is running.
        case refusedWhileEmulating
    }

    /// What one key press did.
    public enum Outcome: Equatable, Sendable {
        /// A mapping for the control and the profile the capture was armed for.
        case mapped(profileID: UUID, control: XInputControl, action: MappedAction)
        /// The user aborted; the previous mapping must stay as it was.
        case cancelled(XInputControl)
        /// Nothing was armed, so nothing happened and nothing may be written.
        case ignored
    }

    /// Control whose next key press is being captured, if any.
    public private(set) var armedControl: XInputControl?

    /// Profile the armed capture belongs to, if any.
    public private(set) var armedProfileID: UUID?

    public init() {}

    public var isArmed: Bool {
        armedControl != nil
    }

    public func isArmed(_ control: XInputControl) -> Bool {
        armedControl == control
    }

    /// Arms a control for one profile.
    ///
    /// Any capture already in flight is replaced, so a second «Capturar» press never leaves two
    /// controls waiting.
    /// - Returns: `.armed`, or `.refusedWhileEmulating` when a mapping swap would be unsafe.
    @discardableResult
    public mutating func arm(
        _ control: XInputControl,
        for profileID: UUID,
        isEmulationRunning: Bool
    ) -> ArmResult {
        guard !isEmulationRunning else {
            disarm()
            return .refusedWhileEmulating
        }
        armedControl = control
        armedProfileID = profileID
        return .armed
    }

    /// Arms a control, or ends its capture when it is already the armed one.
    ///
    /// This is what the «Capturar» / «Cancelar» button does, so the button never has to reason about
    /// the state itself.
    @discardableResult
    public mutating func toggle(
        _ control: XInputControl,
        for profileID: UUID,
        isEmulationRunning: Bool
    ) -> ArmResult {
        if armedControl == control, armedProfileID == profileID {
            disarm()
            return .disarmed
        }
        return arm(control, for: profileID, isEmulationRunning: isEmulationRunning)
    }

    /// Ends the capture without a mapping. Safe to call at any time; a later key press does nothing.
    ///
    /// The editor calls this when emulation starts, when the view disappears and when the profile
    /// selection changes, because a capture left armed would keep swallowing key presses.
    public mutating func disarm() {
        armedControl = nil
        armedProfileID = nil
    }

    /// Turns one key press into what the editor should do next.
    ///
    /// The decision of what a press *means* stays in `MappingRules`, which is the single place where
    /// plain Escape aborts and everything else becomes a shortcut that includes the modifiers held.
    /// A finished capture always disarms, so one press can produce at most one mapping.
    public mutating func handleKey(keyCode: UInt16, modifiers: ModifierSet) -> Outcome {
        guard let control = armedControl, let profileID = armedProfileID else { return .ignored }
        let outcome = MappingRules.capture(forKeyCode: keyCode, modifiers: modifiers)
        disarm()
        switch outcome {
        case .cancel:
            return .cancelled(control)
        case .mapped(let action):
            return .mapped(profileID: profileID, control: control, action: action)
        }
    }
}
