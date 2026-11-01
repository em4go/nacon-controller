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

    /// The colour the light shows while it is on. It is the profile's, so the light says *which* profile is
    /// running and not only that one is.
    public var colour: ProfileColour
    /// Whether the light follows the emulation or the manual toggle.
    public var source: Source
    /// Mirrors `EmulationController.isEnabled`.
    public var isEmulationActive: Bool
    /// State of the manual toggle. Kept while `.emulation` is selected so switching back restores it.
    public var isManuallyOn: Bool

    public init(
        colour: ProfileColour = .standard,
        source: Source = .emulation,
        isEmulationActive: Bool = false,
        isManuallyOn: Bool = false
    ) {
        self.colour = colour
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
        XInputOutputReport.led(isOn ? colour.pattern : .off)
    }

    /// The packet the app sends while terminating (`S5`).
    ///
    /// It is sent unconditionally: at exit the app cannot know whether the pad still holds a lit
    /// light, so the only safe command is the one that turns it off.
    public static var offPacket: [UInt8] {
        XInputOutputReport.led(.off)
    }
}

extension PadLight {
    /// S11: the light's state when a run starts, stops, or the profile changes.
    ///
    /// It exists because the caller no longer owns this decision: a screen used to compute it, and a
    /// screen can be unmounted, which is how the light stopped following the emulation when the window
    /// gained destinations. Keeping the rule here means the answer is the same wherever it is asked
    /// from, and that the `.manual` exception below cannot be forgotten by a new caller.
    ///
    /// A manual light ignores the run: someone who set it by hand did not ask for an indicator.
    public mutating func sync(colour: ProfileColour, isEmulationActive: Bool) {
        self.colour = colour
        self.isEmulationActive = isEmulationActive
    }
}
