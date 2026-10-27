import Foundation

/// Reads and writes the profile library on disk.
///
/// The directory is injected so tests (and any other caller) never touch the real
/// `~/Library/Application Support`. The store only does I/O: every fallback decision lives in
/// `ProfileLibrary`.
public struct ProfileStore {
    /// File that holds the library inside `directory`.
    public static let fileName = "profiles.json"

    /// Prefix of the sibling file that keeps a library the store could not read.
    public static let unreadableFilePrefix = "profiles.unreadable-"

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
    /// always starts with a usable mapping. A file that exists but yields no usable profile is moved
    /// aside first: whatever the user had stays recoverable by hand, and the autosave that follows a
    /// load cannot destroy it. That rule is why the file I/O lives here and not in `ProfileLibrary`.
    public func load() -> ProfileLibrary {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .seeded }
        let data = try? Data(contentsOf: fileURL)
        if let data, let library = ProfileLibrary.recover(from: data) {
            return library
        }
        moveAsideUnreadableFile(bytes: data)
        return .seeded
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

    // MARK: - Unreadable file

    /// Moves the current file to a free sibling name, so the next save cannot overwrite it.
    ///
    /// Best effort by design: a file that cannot be moved must not stop the app from starting with
    /// the seed. If the move fails — a permission problem, for example — the bytes are copied to the
    /// sibling name instead, which still leaves the user's data recoverable by hand.
    private func moveAsideUnreadableFile(bytes: Data?) {
        let destination = freeUnreadableFileURL()
        do {
            try FileManager.default.moveItem(at: fileURL, to: destination)
        } catch {
            guard let bytes else { return }
            try? bytes.write(to: destination, options: .atomic)
        }
    }

    /// First free sibling name: `profiles.unreadable-<timestamp>.json`, then `…-2.json`, `…-3.json`.
    private func freeUnreadableFileURL() -> URL {
        let stamp = ProfileStore.timestampFormatter.string(from: Date())
        let base = ProfileStore.unreadableFilePrefix + stamp
        var candidate = directory.appendingPathComponent("\(base).json", isDirectory: false)
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base)-\(suffix).json", isDirectory: false)
            suffix += 1
        }
        return candidate
    }

    /// Timestamp used in the sibling name. Colons are avoided so the name is portable.
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
