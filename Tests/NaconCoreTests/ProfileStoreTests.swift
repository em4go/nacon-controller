import XCTest

@testable import NaconCore

final class ProfileStoreTests: XCTestCase {
    private var directory: URL!
    private var store: ProfileStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("nacon-profile-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = ProfileStore(directory: directory)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
        store = nil
        try super.tearDownWithError()
    }

    // MARK: - Seeding and fallback (S7)

    func testMissingFileSeedsTheStandardProfile() {
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))

        let library = store.load()

        XCTAssertEqual(library, .seeded)
        XCTAssertEqual(library.profiles.count, 1)
        let profile = library.selectedProfile
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.id, library.profiles.first?.id)
        XCTAssertEqual(profile?.profile, .standard)
        XCTAssertFalse(profile?.name.isEmpty ?? true)
    }

    func testCorruptFileFallsBackToTheStandardProfileWithoutThrowing() throws {
        try Data([0x00, 0xFF, 0x42, 0x13, 0x0A, 0x7F]).write(to: store.fileURL)

        let library = store.load()

        XCTAssertEqual(library, .seeded)
        XCTAssertEqual(library.profiles.count, 1)
    }

    func testTruncatedFileFallsBackToTheStandardProfileWithoutThrowing() throws {
        let data = try ProfileLibrary.seeded.encoded()
        try data.prefix(data.count / 2).write(to: store.fileURL)

        XCTAssertEqual(store.load(), .seeded)
    }

    func testValidJSONOfTheWrongShapeFallsBackToTheStandardProfile() throws {
        let json = #"{"profiles": 42, "selectedProfileID": ["nope"]}"#
        try Data(json.utf8).write(to: store.fileURL)

        let library = store.load()

        XCTAssertEqual(library.profiles.count, 1)
        XCTAssertEqual(library.selectedProfile?.profile, .standard)
    }

    func testEmptyProfileListFallsBackToTheStandardProfile() throws {
        let json = #"{"profiles": [], "selectedProfileID": null}"#
        try Data(json.utf8).write(to: store.fileURL)

        XCTAssertEqual(store.load().selectedProfile?.profile, .standard)
    }

    func testUnknownSelectedIdentifierFallsBackToTheFirstProfile() throws {
        let library = ProfileLibrary(
            profiles: [
                StoredProfile(name: "Working", profile: .standard),
                StoredProfile(name: "Gaming", profile: .standard),
            ],
            selectedProfileID: UUID()
        )
        try store.save(library)

        let loaded = store.load()

        XCTAssertEqual(loaded.profiles.map(\.name), ["Working", "Gaming"])
        XCTAssertEqual(loaded.selectedProfileID, loaded.profiles.first?.id)
        XCTAssertEqual(loaded.selectedProfile?.name, "Working")
    }

    func testFileWithAnUnknownSelectedIdentifierFallsBackToTheFirstProfile() throws {
        let json = """
        {"version":1,"selectedProfileID":"00000000-0000-0000-0000-000000000000","profiles":[\
        {"id":"11111111-1111-1111-1111-111111111111","name":"Working","profile":{"mappings":{}}},\
        {"id":"22222222-2222-2222-2222-222222222222","name":"Gaming","profile":{"mappings":{}}}]}
        """
        try Data(json.utf8).write(to: store.fileURL)

        let loaded = store.load()

        XCTAssertEqual(loaded.profiles.map(\.name), ["Working", "Gaming"])
        XCTAssertEqual(loaded.selectedProfileID, UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
    }

    func testSaveWritesTheSameBytesEveryTime() throws {
        let library = ProfileLibrary(
            profiles: [StoredProfile(name: "Only", profile: .standard)],
            selectedProfileID: nil
        )

        try store.save(library)
        let firstWrite = try Data(contentsOf: store.fileURL)
        try store.save(library)

        XCTAssertEqual(try Data(contentsOf: store.fileURL), firstWrite)
    }

    // MARK: - Save and load round trip (S1, S2, S6)

    func testSaveThenLoadPreservesOrderNamesIdentifiersAndSelection() throws {
        let first = StoredProfile(name: "Working", profile: .standard)
        var second = StoredProfile(name: "Gaming", profile: .standard)
        var third = StoredProfile(name: "Reading", profile: .standard)

        second.profile.mappings[.buttonY] = .scrollLines(-3)
        third.profile.mappings[.buttonA] = .key(KeyCombo(keyCode: 12, modifiers: [.command, .shift]))
        third.profile.cursor = CursorSettings(deadzone: 0.4, maxSpeed: 600, invertVerticalAxis: true)
        third.profile.keyRepeat = KeyRepeatSettings(initialDelay: 0.5, interval: 0.03)

        let library = ProfileLibrary(
            profiles: [first, second, third],
            selectedProfileID: second.id
        )

        try store.save(library)
        let reloaded = ProfileStore(directory: directory).load()

        XCTAssertEqual(reloaded.profiles.map(\.id), [first.id, second.id, third.id])
        XCTAssertEqual(reloaded.profiles.map(\.name), ["Working", "Gaming", "Reading"])
        XCTAssertEqual(reloaded.selectedProfileID, second.id)
        XCTAssertEqual(reloaded, library)
    }

    func testSavedFileIsReadableJSONInTheInjectedDirectory() throws {
        try store.save(.seeded)

        XCTAssertEqual(store.fileURL.deletingLastPathComponent().standardizedFileURL, directory.standardizedFileURL)
        let data = try Data(contentsOf: store.fileURL)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testSaveCreatesTheDirectoryWhenItDoesNotExist() throws {
        let nested = directory.appendingPathComponent("a/b/c", isDirectory: true)
        let nestedStore = ProfileStore(directory: nested)
        let library = ProfileLibrary(profiles: [StoredProfile(name: "Only", profile: .standard)])

        try nestedStore.save(library)

        XCTAssertEqual(nestedStore.load().profiles.map(\.name), ["Only"])
    }

    // MARK: - Pure decision logic

    func testNormalizedKeepsAValidSelectionUnchanged() {
        let library = ProfileLibrary(
            profiles: [StoredProfile(name: "A", profile: .standard), StoredProfile(name: "B", profile: .standard)],
            selectedProfileID: nil
        )
        let normalized = library.normalized()

        XCTAssertEqual(normalized.selectedProfileID, normalized.profiles.first?.id)
        XCTAssertEqual(normalized.normalized(), normalized)
    }

    func testDecodeOfGarbageReturnsTheSeed() {
        let library = ProfileLibrary.decode(from: Data("not json at all".utf8))

        XCTAssertEqual(library.selectedProfile?.profile, .standard)
        XCTAssertEqual(library.profiles.count, 1)
    }
}
