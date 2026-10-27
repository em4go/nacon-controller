import Foundation

/// Reads and writes the profile library on disk.
///
/// The directory is injected so tests (and any other caller) never touch the real
/// `~/Library/Application Support`. The store only does I/O: every fallback decision lives in
/// `ProfileLibrary`.
public struct ProfileStore {
    /// File that holds the library inside `directory`.
    public static let fileName = "profiles.json"

    /// Default location used by the app.
    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("NaconController", isDirectory: true)
    }

    public let directory: URL

    public init(directory: URL = ProfileStore.defaultDirectory) {
        self.directory = directory
    }

    public var fileURL: URL {
        directory.appendingPathComponent(ProfileStore.fileName, isDirectory: false)
    }

    /// Loads the library without ever throwing.
    ///
    /// A missing, empty, corrupt or foreign file yields the seeded standard profile, so the app
    /// always starts with a usable mapping.
    public func load() -> ProfileLibrary {
        guard let data = try? Data(contentsOf: fileURL) else { return .seeded }
        return ProfileLibrary.decode(from: data)
    }

    /// Writes the library atomically, creating the directory when needed.
    ///
    /// There is no user-facing save step: callers save on every change.
    public func save(_ library: ProfileLibrary) throws {
        let data = try library.encoded()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // `.atomic` writes a temporary file and renames it, so a crash cannot leave half a file.
        try data.write(to: fileURL, options: .atomic)
    }
}
