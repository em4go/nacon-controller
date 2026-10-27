import Foundation

/// The one decision behind making Guide a toggle instead of a stop button.
///
/// Stopping is always safe: it releases everything that was held. Starting injects events, and doing
/// it without the Accessibility permission would look exactly like the app ignoring the pad, so the
/// pad must not be able to start what the system will discard. The rule lives here, as a value
/// function, because the app layer that calls it needs a window and a system permission to exist.
public enum GuideToggle {
    /// Whether a Guide press that arrived while the emulation was stopped may start it.
    ///
    /// The engine keeps handling the opposite direction on its own: while the emulation runs, Guide is
    /// the emergency stop, and it must keep working even if the app layer is busy.
    public static func canStartFromPad(hasAccessibility: Bool) -> Bool {
        hasAccessibility
    }
}
