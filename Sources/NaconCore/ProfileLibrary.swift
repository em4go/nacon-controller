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
