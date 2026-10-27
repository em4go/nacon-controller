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
        guard let library = try? JSONDecoder().decode(ProfileLibrary.self, from: data) else {
            return .seeded
        }
        return library.normalized()
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

    private enum CodingKeys: String, CodingKey {
        case version
        case profiles
        case selectedProfileID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            profiles: try container.decodeIfPresent([StoredProfile].self, forKey: .profiles) ?? [],
            selectedProfileID: try container.decodeIfPresent(UUID.self, forKey: .selectedProfileID)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ProfileLibrary.currentVersion, forKey: .version)
        try container.encode(profiles, forKey: .profiles)
        try container.encodeIfPresent(selectedProfileID, forKey: .selectedProfileID)
    }
}
