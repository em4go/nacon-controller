import Foundation

/// The MOD layer of a profile: a second set of assignments that only applies while one pad control
/// is held.
///
/// It stores only the assignments that differ from the base. A layer is a second reading of the same
/// controls, not a second profile, so a control without an entry keeps its base action and clearing
/// an entry is exactly like never having made it — the file stays small and the base stays the
/// single source of truth for everything the layer does not touch.
public struct ProfileLayer: Equatable, Sendable {
    /// The control that selects the layer, when the profile has one.
    ///
    /// It is not a held modifier: while it is held it emits nothing at all, it only chooses which
    /// assignments the presses of the other controls are read against.
    public var key: XInputControl?
    /// The assignments that differ from the base.
    public var mappings: [XInputControl: MappedAction]

    public init(key: XInputControl? = nil, mappings: [XInputControl: MappedAction] = [:]) {
        self.key = key
        self.mappings = mappings
    }

    /// A profile with no MOD key: the base is the whole mapping.
    public static let empty = ProfileLayer()

    public var isEmpty: Bool {
        key == nil && mappings.isEmpty
    }

    /// Whether the layer can ever apply. Without a key nothing can hold it open, so any entries it
    /// carries are inert and the UI should not offer them.
    public var isActive: Bool {
        key != nil
    }

    /// The layer's own action for one control, or nil when the caller has to fall back to the base.
    ///
    /// The nil is deliberate: `.none` means "redefined to nothing" and must win over the base, so a
    /// missing entry and an empty one cannot be the same value here.
    public func action(for control: XInputControl) -> MappedAction? {
        mappings[control]
    }
}
