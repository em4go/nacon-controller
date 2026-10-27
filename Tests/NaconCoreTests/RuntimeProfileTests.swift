import XCTest

@testable import NaconCore

/// S1, S2, S8: which saved profile the emulation engine runs with, and the vertical-axis setting
/// that belongs to that profile.
///
/// The engine never names a concrete mapping: it asks the library for the one in force, and the
/// library answers with the selection, or with the standard mapping when the selection cannot be
/// resolved. Both rules are pure data, so they are checked here without a window and without a file.
final class RuntimeProfileTests: XCTestCase {
    // MARK: - Fixtures

    /// A library whose selected profile is deliberately *not* the standard mapping, so running a
    /// hard-coded profile is visible in the assertions.
    private func libraryWithCustomSelection() -> ProfileLibrary {
        let standard = StoredProfile(name: "Estándar", profile: .standard)
        let custom = StoredProfile(
            name: "Trabajo",
            profile: InputProfile(mappings: [.buttonA: .key(KeyCombo(.tab))])
        )
        return ProfileLibrary(profiles: [standard, custom], selectedProfileID: custom.id)
    }

    // MARK: - S1, S8: the profile in force

    func testEmulationRunsTheSelectedProfileAndFollowsAChangeOfSelection() {
        var library = libraryWithCustomSelection()

        XCTAssertEqual(library.runtimeProfile.action(for: .buttonA), .key(KeyCombo(.tab)))
        XCTAssertNotEqual(library.runtimeProfile, .standard)

        // S8: the selection is what reached disk, so restoring another profile is what the engine
        // must run on the next start.
        library.selectProfile(id: library.profiles[0].id)

        XCTAssertEqual(library.runtimeProfile, .standard)
    }

    func testRuntimeProfileReadsTheSelectedProfileIncludingItsCursorSettings() {
        var library = libraryWithCustomSelection()
        library.setInvertVerticalAxis(true)

        XCTAssertEqual(library.runtimeProfile.cursor, library.selectedProfile?.profile.cursor)
        XCTAssertTrue(library.runtimeProfile.cursor.invertVerticalAxis)
    }

    // MARK: - Unresolvable selection

    func testRuntimeProfileFallsBackToTheStandardMappingWhenTheLibraryHoldsNoProfiles() {
        let empty = ProfileLibrary(profiles: [], selectedProfileID: UUID())

        XCTAssertNil(empty.selectedProfile)
        XCTAssertEqual(empty.runtimeProfile, .standard)
    }

    func testRuntimeProfileUsesTheFirstProfileWhenTheSelectionDangles() {
        var library = libraryWithCustomSelection()
        library.selectedProfileID = UUID()

        XCTAssertEqual(library.runtimeProfile, library.profiles[0].profile)
        XCTAssertEqual(library.runtimeProfile.action(for: .buttonA), .mouseButton(.left))
    }

    // MARK: - S2: the vertical axis belongs to the profile

    func testInvertingTheVerticalAxisEditsOnlyTheSelectedProfile() {
        var library = libraryWithCustomSelection()

        XCTAssertTrue(library.setInvertVerticalAxis(true))

        XCTAssertTrue(library.selectedInvertVerticalAxis)
        XCTAssertTrue(library.profiles[1].profile.cursor.invertVerticalAxis)
        // The sibling keeps its own value, so two profiles can differ in this setting.
        XCTAssertFalse(library.profiles[0].profile.cursor.invertVerticalAxis)
    }

    func testInvertingTheVerticalAxisLeavesTheOtherMappingsAlone() {
        var library = libraryWithCustomSelection()
        let before = library.profiles[1].profile

        library.setInvertVerticalAxis(true)

        XCTAssertEqual(library.profiles[1].profile.mappings, before.mappings)
        XCTAssertEqual(library.profiles[1].profile.keyRepeat, before.keyRepeat)
    }

    func testInvertingIsRefusedWhenThereIsNoProfileToEdit() {
        var empty = ProfileLibrary(profiles: [])

        XCTAssertFalse(empty.setInvertVerticalAxis(true))
        XCTAssertFalse(empty.selectedInvertVerticalAxis)
    }

    func testInvertingToTheValueAlreadyStoredReportsNoChange() {
        var library = libraryWithCustomSelection()

        XCTAssertFalse(library.setInvertVerticalAxis(false))
        XCTAssertEqual(library.profiles[1].profile.cursor.invertVerticalAxis, false)
    }
}
