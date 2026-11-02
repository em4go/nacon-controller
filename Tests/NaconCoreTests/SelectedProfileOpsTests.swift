import XCTest

@testable import NaconCore

/// The selected-profile variants of the library's write operations.
///
/// `ProfileLibrary` takes an explicit profile identifier for the operations that can reach any
/// profile, and an explicit identifier is the right shape for a unit that owns the storage. Callers
/// that only ever act on "the profile on screen" would have to resolve that identifier themselves,
/// which is one repeated lookup too many and one rule with two homes. These variants do the lookup
/// once, inside the type that already knows how a selection is resolved.
///
/// Every test checks both halves of that contract: the operation lands on the selected profile and
/// leaves its siblings alone, and an operation with no profile to aim at changes nothing and says so.
final class SelectedProfileOpsTests: XCTestCase {
    // MARK: - Fixtures

    /// Three profiles whose mappings, layer, precision and colour all differ, so an edit that landed
    /// on the wrong profile — or on every profile — is visible in the assertions.
    ///
    /// The second one is selected on purpose: with the first selected, "the selected profile" and
    /// "the first profile" would be the same index and a lookup that fell back to it would pass.
    private func library() -> ProfileLibrary {
        let first = StoredProfile(
            name: "Uno",
            profile: InputProfile(
                mappings: [.buttonA: .key(KeyCombo(.tab))],
                layer: ProfileLayer(key: .rightBumper, mappings: [.buttonB: .key(KeyCombo(.space))]),
                precision: PrecisionSettings(scale: 0.2),
                color: .standard
            )
        )
        let selected = StoredProfile(
            name: "Dos",
            profile: InputProfile(
                mappings: [.buttonB: .mouseButton(.right)],
                layer: ProfileLayer(key: .leftBumper, mappings: [.buttonA: .key(KeyCombo(.space))]),
                precision: PrecisionSettings(scale: 0.5),
                color: .standard
            )
        )
        let last = StoredProfile(
            name: "Tres",
            profile: InputProfile(
                mappings: [.buttonX: .mouseButton(.left)],
                layer: ProfileLayer(mappings: [.buttonY: .key(KeyCombo(.escape))]),
                precision: PrecisionSettings(scale: 0.9),
                color: .standard
            )
        )
        return ProfileLibrary(profiles: [first, selected, last], selectedProfileID: selected.id)
    }

    /// A library with nothing to act on: no profiles, so no selection either.
    ///
    /// `selectedProfile` falls back to the first profile, which means the only way to have no
    /// profile on screen is to have none at all. That is the state these operations must refuse.
    private func emptyLibrary() -> ProfileLibrary {
        ProfileLibrary(profiles: [], selectedProfileID: nil)
    }

    /// The siblings of the selected profile, as the tests compare them before and after an edit.
    private func siblings(of library: ProfileLibrary) -> [StoredProfile] {
        library.profiles.filter { $0.id != library.selectedProfile?.id }
    }

    // MARK: - setLayerKey

    func testSettingTheLayerKeyEditsTheSelectedProfileAndLeavesItsSiblingsAlone() {
        var library = library()
        let before = siblings(of: library)

        XCTAssertTrue(library.setLayerKey(.start))

        XCTAssertEqual(library.selectedLayer.key, .start)
        XCTAssertEqual(siblings(of: library), before, "a layer key belongs to one profile")
        XCTAssertEqual(library.selectedProfile?.profile.layer.mappings[.buttonA], .key(KeyCombo(.space)),
                       "choosing the key must not touch the entries the layer already holds")
    }

    func testSettingTheLayerKeyChangesNothingWithoutASelection() {
        var library = emptyLibrary()
        let before = library

        XCTAssertFalse(library.setLayerKey(.start))
        XCTAssertEqual(library, before)
    }

    // MARK: - setPrecisionScale

    func testSettingThePrecisionScaleEditsTheSelectedProfileAndLeavesItsSiblingsAlone() {
        var library = library()
        let before = siblings(of: library)

        XCTAssertTrue(library.setPrecisionScale(0.7))

        XCTAssertEqual(library.selectedProfile?.profile.precision.scale, 0.7)
        XCTAssertEqual(siblings(of: library), before, "a speed belongs to one profile")
    }

    func testSettingThePrecisionScaleChangesNothingWithoutASelection() {
        var library = emptyLibrary()
        let before = library

        XCTAssertFalse(library.setPrecisionScale(0.7))
        XCTAssertEqual(library, before)
    }

    // MARK: - clearLayer

    func testClearingTheLayerEmptiesTheSelectedLayerAndLeavesItsSiblingsAlone() {
        var library = library()
        let before = siblings(of: library)

        XCTAssertTrue(library.clearLayer())

        XCTAssertTrue(library.selectedLayer.isEmpty)
        XCTAssertEqual(siblings(of: library), before, "a layer belongs to one profile")
    }

    func testClearingTheLayerChangesNothingWithoutASelection() {
        var library = emptyLibrary()
        let before = library

        XCTAssertFalse(library.clearLayer())
        XCTAssertEqual(library, before)
    }

    // MARK: - deleteSelectedProfile

    func testDeletingTheSelectedProfileRemovesOnlyItAndMovesTheSelection() {
        var library = library()
        let before = siblings(of: library)

        XCTAssertTrue(library.deleteSelectedProfile())

        XCTAssertEqual(library.profiles, before, "only the selected profile goes")
        XCTAssertEqual(library.selectedProfile?.name, "Tres", "the selection moves to the next neighbour")
    }

    func testDeletingTheSelectedProfileChangesNothingWithoutASelection() {
        var library = emptyLibrary()
        let before = library

        XCTAssertFalse(library.deleteSelectedProfile(), "a library with no profiles has nothing to delete")
        XCTAssertEqual(library, before)
    }

    // MARK: - renameSelectedProfile

    func testRenamingTheSelectedProfileRenamesOnlyIt() {
        var library = library()
        let before = siblings(of: library)

        XCTAssertTrue(library.renameSelectedProfile(to: "  Trabajo  "))

        XCTAssertEqual(library.selectedProfile?.name, "Trabajo", "the name is trimmed like the id-taking rename")
        XCTAssertEqual(siblings(of: library), before, "a name belongs to one profile")
    }

    func testRenamingTheSelectedProfileChangesNothingWithoutASelection() {
        var library = emptyLibrary()
        let before = library

        XCTAssertFalse(library.renameSelectedProfile(to: "Trabajo"))
        XCTAssertEqual(library, before)
    }
}
