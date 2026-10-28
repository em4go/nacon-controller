import Foundation

/// A named profile as it lives in the library on disk.
public struct StoredProfile: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var profile: InputProfile

    public init(id: UUID = UUID(), name: String, profile: InputProfile) {
        self.id = id
        self.name = name
        self.profile = profile
    }
}

/// The whole persisted state: every saved profile plus which one is selected.
///
/// The type is pure data. Reading and writing files belongs to `ProfileStore`, so the tolerant
/// fallback rules can be exercised without touching the filesystem.
public struct ProfileLibrary: Equatable, Codable, Sendable {
    /// Format version written to disk. Decoding is deliberately best-effort and does not gate on
    /// it, so a file from an older or newer build still opens.
    public static let currentVersion = 1

    /// Name of the profile created when there is nothing usable on disk.
    /// Shown in the profile picker, so it follows the UI language rather than the code language.
    public static let standardProfileName = "Estándar"

    public var profiles: [StoredProfile]
    public var selectedProfileID: UUID?

    public init(profiles: [StoredProfile], selectedProfileID: UUID? = nil) {
        self.profiles = profiles
        self.selectedProfileID = selectedProfileID
    }

    /// A usable library for a first run or for an unreadable file.
    public static let seeded = makeSeed()

    private static func makeSeed() -> ProfileLibrary {
        let profile = StoredProfile(name: standardProfileName, profile: .standard)
        return ProfileLibrary(profiles: [profile], selectedProfileID: profile.id)
    }

    /// The selected profile, falling back to the first one so callers always get something.
    public var selectedProfile: StoredProfile? {
        if let selectedProfileID, let match = profiles.first(where: { $0.id == selectedProfileID }) {
            return match
        }
        return profiles.first
    }

    /// S1, S8: the mapping the emulation engine runs with.
    ///
    /// It is the selected profile, so whatever the user last chose — including after a relaunch,
    /// because the selection is persisted with the library — is exactly what the engine gets. A
    /// library that cannot resolve any profile yields the standard mapping instead of nothing: an
    /// unreadable file must never leave the pad dead.
    public var runtimeProfile: InputProfile {
        selectedProfile?.profile ?? .standard
    }

    /// The library with a usable selection, or the seeded library when it holds no profiles.
    public func normalized() -> ProfileLibrary {
        guard let first = profiles.first else { return ProfileLibrary.makeSeed() }
        if let selectedProfileID, profiles.contains(where: { $0.id == selectedProfileID }) {
            return self
        }
        return ProfileLibrary(profiles: profiles, selectedProfileID: first.id)
    }

    /// Decodes a library, returning the seeded library for anything that cannot be read.
    public static func decode(from data: Data) -> ProfileLibrary {
        recover(from: data) ?? .seeded
    }

    /// Decodes a library, returning `nil` when nothing usable can be recovered from the data.
    ///
    /// "Usable" means at least one profile survived decoding: a library with no profile cannot run
    /// the pad, so the caller falls back to the seed. The distinction matters to `ProfileStore`,
    /// which keeps a file that yielded nothing instead of letting the next save overwrite it.
    public static func recover(from data: Data) -> ProfileLibrary? {
        guard let decoded = try? JSONDecoder().decode(ProfileLibrary.self, from: data) else { return nil }
        guard !decoded.profiles.isEmpty else { return nil }
        return decoded.normalized()
    }

    /// Encodes a library in the on-disk format.
    public func encoded() throws -> Data {
        try JSONEncoder.profileEncoder.encode(normalized())
    }

    // MARK: - Profile management (S4, S5, S8)

    /// Base name of a new profile. Shown in the profile picker, so it follows the UI language.
    public static let newProfileNameBase = "Perfil"

    /// Prefix of a duplicated profile, so a copy is recognisable in the picker.
    public static let duplicateNamePrefix = "Copia de "

    /// Deleting the last profile is impossible: the app always needs one to work with.
    public var canDeleteProfile: Bool {
        profiles.count > 1
    }

    /// `base` when no profile uses it, otherwise the smallest free `"base N"`.
    public func uniqueName(basedOn base: String) -> String {
        let root = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let taken = Set(profiles.map(\.name))
        let candidate = root.isEmpty ? ProfileLibrary.newProfileNameBase : root
        guard taken.contains(candidate) else { return candidate }
        var suffix = 2
        while taken.contains("\(candidate) \(suffix)") {
            suffix += 1
        }
        return "\(candidate) \(suffix)"
    }

    /// Appends a profile and selects it.
    ///
    /// A new profile copies an existing mapping instead of starting empty (S5): an empty mapping
    /// would leave the pad dead until the user reassigned every control.
    @discardableResult
    public mutating func addProfile(copying source: InputProfile = .standard) -> StoredProfile {
        let created = StoredProfile(
            name: uniqueName(basedOn: ProfileLibrary.newProfileNameBase),
            profile: source
        )
        profiles.append(created)
        selectedProfileID = created.id
        return created
    }

    /// Copies the selected profile next to it and selects the copy.
    ///
    /// Returns `nil` only when there is nothing to copy and no standard mapping to fall back on,
    /// which cannot happen because an empty library still copies `InputProfile.standard`.
    @discardableResult
    public mutating func duplicateSelectedProfile() -> StoredProfile? {
        guard let source = selectedProfile else { return addProfile() }
        let copy = StoredProfile(
            name: uniqueName(basedOn: ProfileLibrary.duplicateNamePrefix + source.name),
            profile: source.profile
        )
        if let index = profiles.firstIndex(where: { $0.id == source.id }) {
            profiles.insert(copy, at: profiles.index(after: index))
        } else {
            profiles.append(copy)
        }
        selectedProfileID = copy.id
        return copy
    }

    /// Removes a profile, refusing to leave the library empty.
    ///
    /// When the deleted profile was the selected one, the selection moves to the following
    /// neighbour, or to the previous one when the deleted profile was last.
    @discardableResult
    public mutating func deleteProfile(id: UUID) -> Bool {
        guard canDeleteProfile else { return false }
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return false }
        profiles.remove(at: index)
        if !profiles.contains(where: { $0.id == selectedProfileID }) {
            selectedProfileID = profiles[min(index, profiles.count - 1)].id
        }
        return true
    }

    /// Renames a profile, rejecting names that would leave it nameless.
    @discardableResult
    public mutating func renameProfile(id: UUID, to proposedName: String) -> Bool {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return false }
        profiles[index].name = name
        return true
    }

    /// Selects a known profile; an unknown identifier leaves a still-valid selection alone.
    public mutating func selectProfile(id: UUID) {
        if profiles.contains(where: { $0.id == id }) {
            selectedProfileID = id
        } else {
            selectedProfileID = selectedProfile?.id
        }
    }

    // MARK: - Cursor settings (S2)

    /// Position of the profile being edited, or `nil` when the library cannot resolve one.
    private var selectedIndex: Int? {
        guard let selectedID = selectedProfile?.id else { return nil }
        return profiles.firstIndex(where: { $0.id == selectedID })
    }

    /// S2: the vertical-axis setting of the profile being edited.
    ///
    /// The setting belongs to the profile, not to the running app, so a toggle that shows this value
    /// always agrees with what would be used on the next start.
    public var selectedInvertVerticalAxis: Bool {
        selectedProfile?.profile.cursor.invertVerticalAxis ?? false
    }

    /// S2: flips the vertical direction on the profile being edited, leaving every sibling alone.
    /// - Returns: whether the library changed.
    @discardableResult
    public mutating func setInvertVerticalAxis(_ newValue: Bool) -> Bool {
        guard let index = selectedIndex else { return false }
        guard profiles[index].profile.cursor.invertVerticalAxis != newValue else { return false }
        profiles[index].profile.cursor.invertVerticalAxis = newValue
        return true
    }

    // MARK: - S9: cursor sensitivity of the profile being edited

    /// The value the slider must show, or `nil` when there is no profile to edit.
    public func selectedValue(for sensitivity: CursorSensitivity) -> Double? {
        selectedProfile.map { sensitivity.value(in: $0.profile.cursor) }
    }

    /// Writes one cursor setting into the profile being edited, clamped to its range.
    /// - Returns: whether the library changed.
    @discardableResult
    public mutating func setCursorSensitivity(_ sensitivity: CursorSensitivity, to raw: Double) -> Bool {
        guard let index = selectedIndex else { return false }
        var cursor = profiles[index].profile.cursor
        guard sensitivity.apply(raw, to: &cursor) else { return false }
        profiles[index].profile.cursor = cursor
        return true
    }

    /// Restores the standard sensitivity on the profile being edited, leaving every sibling alone.
    ///
    /// The vertical-axis flag is kept. It corrects a property of the unit, not a preference of the
    /// user, so resetting the numbers must not silently flip the cursor back to the wrong direction.
    @discardableResult
    public mutating func resetCursorSensitivity() -> Bool {
        guard let index = selectedIndex else { return false }
        let standard = InputProfile.standard.cursor
        let current = profiles[index].profile.cursor
        let restored = CursorSettings(
            deadzone: standard.deadzone,
            fullSpeedFraction: standard.fullSpeedFraction,
            maxSpeed: standard.maxSpeed,
            curveExponent: standard.curveExponent,
            scrollLinesPerSecond: standard.scrollLinesPerSecond,
            invertVerticalAxis: current.invertVerticalAxis
        )
        guard restored != current else { return false }
        profiles[index].profile.cursor = restored
        return true
    }

    // MARK: - MOD layer (S3, S4, S5, S6)

    /// The MOD layer of the profile being edited, or the empty layer when there is nothing to edit.
    ///
    /// The UI reads the key and the entries from here, so a profile without a layer looks the same to
    /// it as one that has never had one.
    public var selectedLayer: ProfileLayer {
        selectedProfile?.profile.layer ?? .empty
    }

    /// S5: chooses the control that opens the layer of one profile.
    ///
    /// `nil` is «Ninguna»: the layer closes but keeps its entries, so a slip of the menu cannot delete
    /// a whole set of assignments — `clearLayer` is the deliberate way to throw them away.
    /// - Returns: whether the library changed. A control that may not select the layer (PS) is
    ///   refused without touching anything.
    @discardableResult
    public mutating func setLayerKey(_ control: XInputControl?, for profileID: UUID) -> Bool {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return false }
        if let control, !MappingRules.isLayerKeyEligible(control) {
            return false
        }
        guard profiles[index].profile.layer.key != control else { return false }
        profiles[index].profile.layer.key = control
        return true
    }

    /// S3: writes one assignment into the layer of one profile, leaving the base alone.
    ///
    /// `.none` removes the entry instead of storing it, exactly like the base: a control the layer
    /// does not redefine falls back to the base (S2), and an empty entry would mean something else.
    /// - Returns: whether the library changed.
    @discardableResult
    public mutating func setLayerAction(
        _ action: MappedAction,
        for control: XInputControl,
        in profileID: UUID
    ) -> Bool {
        // The same invariant the base holds: PS is never stored as an assignment.
        guard MappingRules.isRemappable(control) else { return false }
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return false }
        var layer = profiles[index].profile.layer
        if case .none = action {
            guard layer.mappings[control] != nil else { return false }
            layer.mappings.removeValue(forKey: control)
        } else {
            guard layer.mappings[control] != action else { return false }
            layer.mappings[control] = action
        }
        profiles[index].profile.layer = layer
        return true
    }

    /// Drops the key and every entry of one profile's layer: the profile goes back to having no layer
    /// at all, which is what a profile saved before the layer existed looks like (S6).
    /// - Returns: whether the library changed.
    @discardableResult
    public mutating func clearLayer(for profileID: UUID) -> Bool {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return false }
        guard !profiles[index].profile.layer.isEmpty else { return false }
        profiles[index].profile.layer = .empty
        return true
    }

    /// The layer's own assignment for one control of the profile being edited.
    ///
    /// `nil` means the control has no entry and uses its base action (S2); it is not the same as
    /// `.none`, which is an entry that deliberately sends nothing.
    public func layerValue(for control: XInputControl) -> MappedAction? {
        selectedProfile?.profile.layer.action(for: control)
    }

    // MARK: - Mapping write (S2, S4, S5)

    /// S2: applies the write a finished capture resolved to, and nothing else.
    ///
    /// A drop changes nothing, and a write aimed at a profile that is not the selected one is
    /// dropped here too: the guard lives in the unit that reaches disk, so no view can bypass it
    /// (F5). Where the action lands is the write's column, never a flag read at the call site.
    /// - Returns: whether the library changed.
    @discardableResult
    public mutating func apply(_ write: MappingWrite) -> Bool {
        switch write {
        case .drop:
            return false
        case let .apply(profileID, control, column, action):
            guard profileID == selectedProfile?.id else { return false }
            switch column {
            case .base:
                return setAction(action, for: control)
            case .mod:
                return setLayerAction(action, for: control, in: profileID)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case profiles
        case selectedProfileID
    }

    /// One array element that never throws, so a single malformed profile cannot take its siblings
    /// down with it. `value` is `nil` exactly when that entry could not be decoded.
    private struct Salvageable<Wrapped: Decodable>: Decodable {
        let value: Wrapped?

        init(from decoder: Decoder) throws {
            value = try? Wrapped(from: decoder)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Per-entry decoding: one profile from another version, or a hand-edited entry with a
        // broken mapping, loses only itself. Everything that decodes is kept.
        let entries = (try? container.decodeIfPresent(
            [Salvageable<StoredProfile>].self,
            forKey: .profiles
        )) ?? nil
        self.init(
            profiles: (entries ?? []).compactMap(\.value),
            // An unreadable selection is not a reason to drop the profiles around it either; the
            // normalisation below falls back to the first one.
            selectedProfileID: (try? container.decodeIfPresent(UUID.self, forKey: .selectedProfileID)) ?? nil
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ProfileLibrary.currentVersion, forKey: .version)
        try container.encode(profiles, forKey: .profiles)
        try container.encodeIfPresent(selectedProfileID, forKey: .selectedProfileID)
    }
}
