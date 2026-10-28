import Foundation

/// Which column of a profile an edit writes to.
///
/// The table shows both readings of a control side by side, and the drawing offers the same two
/// destinations, so "base or MOD" is a fact of the edit and not of the view that started it.
public enum MappingColumn: Equatable, Sendable {
    /// The mapping the control always sends.
    case base
    /// The entry of the MOD layer, which applies only while the layer key is held.
    case mod
}

/// Whether a capture replaces the action of its column or adds one more step to it.
public enum CaptureMode: Equatable, Sendable {
    case replace
    /// The captured key becomes the last step of the existing command.
    case appendStep
}

/// S2: where and how a capture writes, decided when the capture is armed.
///
/// The intent travels with the armed capture instead of living in the view, so a press can never be
/// read against a flag that changed while the user was looking elsewhere — and the two columns can
/// offer the capture and the steps without a second capture path.
public struct CaptureIntent: Equatable, Sendable {
    public var column: MappingColumn
    public var mode: CaptureMode

    public init(column: MappingColumn = .base, mode: CaptureMode = .replace) {
        self.column = column
        self.mode = mode
    }

    /// Replaces the base action, which is what «Capturar» in the base column does.
    public static let base = CaptureIntent()
    /// Adds a step to the base command.
    public static let baseCommand = CaptureIntent(mode: .appendStep)
    /// Replaces the MOD layer entry.
    public static let mod = CaptureIntent(column: .mod)
    /// Adds a step to the MOD layer command.
    public static let modCommand = CaptureIntent(column: .mod, mode: .appendStep)
}

/// S2, S4, S5: the one rule that turns a finished capture into the write to apply.
///
/// The view only forwards: it hands the outcome and the profile on screen to `resolve` and applies
/// whatever comes back through `ProfileLibrary.apply`. Everything that is not a mapping for the
/// profile still on screen resolves to `.drop`, and a drop changes nothing, so a capture armed before
/// a profile switch can never land on the newly selected profile (F5).
///
/// The append rule is here and nowhere else, which is what makes both columns agree (S5): a step
/// appended in the MOD column chains onto the MOD entry and never the base one, and appending to a
/// control with nothing assigned — or with something that is not a command — replaces instead of
/// clearing it.
public enum MappingWrite: Equatable, Sendable {
    /// Write this action into this column of this profile.
    case apply(profileID: UUID, control: XInputControl, column: MappingColumn, action: MappedAction)
    /// Write nothing at all.
    case drop

    /// The write a finished capture asks for, or `.drop` when it must not write.
    ///
    /// - Parameters:
    ///   - outcome: what `KeyCaptureSession.handleKey` returned, carrying the arming intent.
    ///   - profile: the profile being edited right now, or `nil` when there is none.
    ///   - selectedProfileID: identifier of the profile being edited right now.
    public static func resolve(
        _ outcome: KeyCaptureSession.Outcome,
        editing profile: InputProfile?,
        selectedProfileID: UUID?
    ) -> MappingWrite {
        guard case let .mapped(profileID, control, action, intent) = outcome else { return .drop }
        guard profileID == selectedProfileID else { return .drop }
        // Without a profile there is nothing to extend, so the captured action simply replaces.
        guard intent.mode == .appendStep, let profile else {
            return .apply(profileID: profileID, control: control, column: intent.column, action: action)
        }
        let existing: MappedAction
        switch intent.column {
        case .base:
            existing = profile.action(for: control)
        case .mod:
            // The layer falls back to the base when it has no entry, but a step appended here must
            // extend the MOD entry: an empty one means there is nothing to chain onto.
            existing = profile.layer.action(for: control) ?? .none
        }
        // Only a key can be a step, and only a command can take one. Anything else is stored as it
        // came, so an append never silently clears or rewrites what the control had.
        guard case let .key(combo) = action, MappingRules.canAppendStep(to: existing) else {
            return .apply(profileID: profileID, control: control, column: intent.column, action: action)
        }
        return .apply(
            profileID: profileID,
            control: control,
            column: intent.column,
            action: MappingRules.appending(step: combo, to: existing)
        )
    }
}
