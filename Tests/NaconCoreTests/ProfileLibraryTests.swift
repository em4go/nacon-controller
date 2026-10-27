import XCTest

@testable import NaconCore

/// Rules for creating, duplicating, renaming, deleting and selecting profiles.
///
/// These live in `ProfileLibrary` so they can be checked without SwiftUI or the filesystem.
final class ProfileLibraryTests: XCTestCase {
    // MARK: - Fixtures

    /// A library whose selected profile is deliberately *not* the standard mapping, so a copy taken
    /// from the wrong source is visible in the assertions.
    private func libraryWithCustomSelection() -> ProfileLibrary {
        let standard = StoredProfile(name: "Estándar", profile: .standard)
        let custom = StoredProfile(
            name: "Trabajo",
            profile: InputProfile(mappings: [.buttonA: .key(KeyCombo(.tab))])
        )
        return ProfileLibrary(profiles: [standard, custom], selectedProfileID: custom.id)
    }

    private func library(names: [String]) -> ProfileLibrary {
        let profiles = names.map { StoredProfile(name: $0, profile: .standard) }
        return ProfileLibrary(profiles: profiles, selectedProfileID: profiles.first?.id)
    }

    private func assertSelectionIsValid(
        _ library: ProfileLibrary,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let selectedID = library.selectedProfileID else {
            XCTFail("selection is empty \(message)", file: file, line: line)
            return
        }
        XCTAssertTrue(
            library.profiles.contains(where: { $0.id == selectedID }),
            "selection dangles \(message)",
            file: file,
            line: line
        )
        XCTAssertNotNil(library.selectedProfile, message, file: file, line: line)
        XCTAssertFalse(
            library.profiles.isEmpty,
            "library holds no profiles \(message)",
            file: file,
            line: line
        )
    }

    // MARK: - Create (S4, S5)

    func testAddingAProfileCopiesTheStandardMappingInsteadOfAnEmptyOne() {
        var library = libraryWithCustomSelection()

        let created = library.addProfile()

        XCTAssertEqual(created.profile, .standard)
        XCTAssertFalse(created.profile.mappings.isEmpty)
        XCTAssertEqual(created.profile.action(for: .buttonA), .mouseButton(.left))
        XCTAssertEqual(library.profiles.count, 3)
    }

    func testAddingAProfileNeverTakesAnExistingName() {
        var library = ProfileLibrary.seeded

        let first = library.addProfile()
        let second = library.addProfile()
        let third = library.addProfile()

        XCTAssertEqual(library.profiles.map(\.name), ["Estándar", "Perfil", "Perfil 2", "Perfil 3"])
        XCTAssertEqual(Set([first.name, second.name, third.name]).count, 3)
        XCTAssertEqual(library.profiles.filter { $0.name == "Perfil" }.count, 1)
    }

    func testAddingAProfileSelectsIt() {
        var library = ProfileLibrary.seeded

        let created = library.addProfile()

        XCTAssertEqual(library.selectedProfileID, created.id)
        assertSelectionIsValid(library)
    }

    func testAddedProfilesHaveDistinctIdentifiers() {
        var library = ProfileLibrary.seeded

        let first = library.addProfile()
        let second = library.addProfile()

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(Set(library.profiles.map(\.id)).count, library.profiles.count)
    }

    // MARK: - Duplicate (S4)

    func testDuplicatingCopiesTheSelectedProfileUnderANewName() {
        var library = libraryWithCustomSelection()
        let source = library.selectedProfile!

        let copy = library.duplicateSelectedProfile()

        XCTAssertNotNil(copy)
        XCTAssertEqual(copy?.profile, source.profile)
        XCTAssertEqual(copy?.profile.action(for: .buttonA), .key(KeyCombo(.tab)))
        XCTAssertNotEqual(copy?.id, source.id)
        XCTAssertNotEqual(copy?.name, source.name)
        XCTAssertEqual(library.profiles.count, 3)
        XCTAssertEqual(Set(library.profiles.map(\.name)).count, 3)
    }

    func testDuplicatingTwiceKeepsBothNamesUnique() {
        var library = libraryWithCustomSelection()

        let first = library.duplicateSelectedProfile()
        library.selectProfile(id: first!.id)
        let second = library.duplicateSelectedProfile()

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertNotEqual(first?.name, second?.name)
        XCTAssertEqual(Set(library.profiles.map(\.name)).count, library.profiles.count)
    }

    func testDuplicatingSelectsTheCopy() {
        var library = libraryWithCustomSelection()

        let copy = library.duplicateSelectedProfile()

        XCTAssertEqual(library.selectedProfileID, copy?.id)
        assertSelectionIsValid(library)
    }

    func testDuplicatingAnEmptyLibraryFallsBackToTheStandardProfile() {
        var library = ProfileLibrary(profiles: [])

        let copy = library.duplicateSelectedProfile()

        XCTAssertNotNil(copy)
        XCTAssertEqual(copy?.profile, .standard)
        assertSelectionIsValid(library)
    }

    // MARK: - Delete (S4)

    func testDeletingRefusesTheLastProfile() {
        var library = ProfileLibrary.seeded
        let only = library.profiles[0]

        XCTAssertFalse(library.canDeleteProfile)
        XCTAssertFalse(library.deleteProfile(id: only.id))
        XCTAssertEqual(library.profiles.map(\.id), [only.id])
        XCTAssertEqual(library.selectedProfileID, only.id)
    }

    func testDeletingIsAvailableWithMoreThanOneProfile() {
        let library = libraryWithCustomSelection()

        XCTAssertTrue(library.canDeleteProfile)
    }

    func testDeletingTheSelectedProfileReselectsTheFollowingNeighbour() {
        var library = library(names: ["A", "B", "C"])
        let middle = library.profiles[1]
        library.selectProfile(id: middle.id)

        XCTAssertTrue(library.deleteProfile(id: middle.id))

        XCTAssertEqual(library.profiles.map(\.name), ["A", "C"])
        XCTAssertEqual(library.selectedProfile?.name, "C")
        assertSelectionIsValid(library)
    }

    func testDeletingTheLastSelectedProfileReselectsThePreviousNeighbour() {
        var library = library(names: ["A", "B", "C"])
        let last = library.profiles[2]
        library.selectProfile(id: last.id)

        XCTAssertTrue(library.deleteProfile(id: last.id))

        XCTAssertEqual(library.profiles.map(\.name), ["A", "B"])
        XCTAssertEqual(library.selectedProfile?.name, "B")
        assertSelectionIsValid(library)
    }

    func testDeletingAnUnselectedProfileKeepsTheSelection() {
        var library = library(names: ["A", "B", "C"])
        library.selectProfile(id: library.profiles[2].id)

        XCTAssertTrue(library.deleteProfile(id: library.profiles[0].id))

        XCTAssertEqual(library.profiles.map(\.name), ["B", "C"])
        XCTAssertEqual(library.selectedProfile?.name, "C")
        assertSelectionIsValid(library)
    }

    func testDeletingAnUnknownIdentifierChangesNothing() {
        let library = library(names: ["A", "B"])

        var changed = library
        XCTAssertFalse(changed.deleteProfile(id: UUID()))
        XCTAssertEqual(changed, library)
    }

    // MARK: - Rename (S4)

    func testRenamingRejectsEmptyAndBlankNames() {
        var library = library(names: ["A", "B"])
        let target = library.profiles[0].id

        XCTAssertFalse(library.renameProfile(id: target, to: ""))
        XCTAssertFalse(library.renameProfile(id: target, to: "   "))
        XCTAssertFalse(library.renameProfile(id: target, to: " \n\t "))
        XCTAssertEqual(library.profiles.map(\.name), ["A", "B"])
    }

    func testRenamingKeepsTheTrimmedName() {
        var library = library(names: ["A", "B"])
        let target = library.profiles[0].id

        XCTAssertTrue(library.renameProfile(id: target, to: "  Trabajo  "))

        XCTAssertEqual(library.profiles.map(\.name), ["Trabajo", "B"])
        XCTAssertEqual(library.selectedProfileID, target)
    }

    func testRenamingAnUnknownProfileIsRefusedWithoutChangingAnything() {
        let library = library(names: ["A", "B"])

        var changed = library
        XCTAssertFalse(changed.renameProfile(id: UUID(), to: "Cualquiera"))
        XCTAssertEqual(changed, library)
    }

    // MARK: - Selection (S8)

    func testSelectingAnUnknownIdentifierLeavesTheSelectionValid() {
        var library = library(names: ["A", "B"])

        library.selectProfile(id: UUID())

        assertSelectionIsValid(library)
        XCTAssertEqual(library.selectedProfile?.name, "A")
    }

    func testSelectionStaysValidAfterEveryMutation() {
        var library = ProfileLibrary.seeded
        assertSelectionIsValid(library, "after seeding")

        let created = library.addProfile()
        assertSelectionIsValid(library, "after create")

        library.selectProfile(id: created.id)
        assertSelectionIsValid(library, "after select")

        _ = library.renameProfile(id: created.id, to: "Trabajo")
        assertSelectionIsValid(library, "after rename")

        let copy = library.duplicateSelectedProfile()
        assertSelectionIsValid(library, "after duplicate")

        _ = library.deleteProfile(id: copy!.id)
        assertSelectionIsValid(library, "after delete")

        _ = library.renameProfile(id: created.id, to: "   ")
        assertSelectionIsValid(library, "after rejected rename")

        _ = library.deleteProfile(id: created.id)
        _ = library.deleteProfile(id: library.profiles[0].id)
        assertSelectionIsValid(library, "after deleting every profile but one")

        XCTAssertFalse(library.deleteProfile(id: library.profiles[0].id))
        assertSelectionIsValid(library, "after refusing to delete the last profile")
    }

    // MARK: - Unique names

    func testUniqueNameReturnsTheBaseWhenItIsFree() {
        let library = library(names: ["A"])

        XCTAssertEqual(library.uniqueName(basedOn: "B"), "B")
    }

    func testUniqueNameAppendsTheSmallestFreeNumber() {
        let library = library(names: ["B", "B 2", "B 3"])

        XCTAssertEqual(library.uniqueName(basedOn: "B"), "B 4")
    }
}
