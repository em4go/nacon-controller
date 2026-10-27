import Foundation

/// Decides the LED state of the pad from the app state, and which packet expresses it.
///
/// The pad's small blue light doubles as an emulation indicator: while the emulation is running a lit
/// light tells the user that the stick is driving the cursor and the buttons are clicking. That
/// coupling is useful but not always wanted, so the light has two sources:
///
/// - `.emulation`: the light mirrors `isEmulationActive`. This is the default (`S3`).
/// - `.manual`: the light mirrors `isManuallyOn` and ignores the emulation (`S4`).
///
/// The type is a plain value with no I/O: the caller reads `packet` after changing the state and
/// hands it to `ControllerService.sendOutput(_:)`. That keeps the decision testable and keeps the
/// UI honest when no pad is attached, because nothing depends on a write ever succeeding (`S6`).
public struct PadLight: Equatable, Sendable {
    /// Where the lit/unlit decision comes from.
    public enum Source: Equatable, Sendable {
        /// The light follows the emulation on/off state.
        case emulation
        /// The light follows the manual toggle and ignores the emulation.
        case manual
    }

    /// Whether the light follows the emulation or the manual toggle.
    public var source: Source
    /// Mirrors `EmulationController.isEnabled`.
    public var isEmulationActive: Bool
    /// State of the manual toggle. Kept while `.emulation` is selected so switching back restores it.
    public var isManuallyOn: Bool

    public init(
        source: Source = .emulation,
        isEmulationActive: Bool = false,
        isManuallyOn: Bool = false
    ) {
        self.source = source
        self.isEmulationActive = isEmulationActive
        self.isManuallyOn = isManuallyOn
    }

    /// Whether the light should be lit right now.
    public var isOn: Bool {
        switch source {
        case .emulation: return isEmulationActive
        case .manual: return isManuallyOn
        }
    }

    /// The packet that expresses `isOn`. Repeating it is harmless, so no change tracking is needed.
    public var packet: [UInt8] {
        XInputOutputReport.led(isOn ? .player1 : .off)
    }

    /// The packet the app sends while terminating (`S5`).
    ///
    /// It is sent unconditionally: at exit the app cannot know whether the pad still holds a lit
    /// light, so the only safe command is the one that turns it off.
    public static var offPacket: [UInt8] {
        XInputOutputReport.led(.off)
    }
}
