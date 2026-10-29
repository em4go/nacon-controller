import XCTest

@testable import NaconCore

/// S11: the ready-made macOS shortcuts are plain key combinations with a Spanish name.
///
/// The catalog is data, so the risks it carries are data risks: a duplicated identifier that makes the
/// menu ambiguous, two names for the same combination, or a bare key that would fire while the user is
/// typing. Those are the invariants pinned here.
final class SystemShortcutTests: XCTestCase {
    func testIdentifiersAreUniqueAndStable() {
        let ids = SystemShortcut.all.map(\.id)

        XCTAssertEqual(Set(ids).count, ids.count, "two shortcuts share an identifier")
        // A slug may be a single word; what matters is that it is stable, lowercase and free of
        // spaces, because it doubles as the menu identity.
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        XCTAssertTrue(
            ids.allSatisfy { id in
                id.allSatisfy(allowed.contains) && !id.hasPrefix("-") && !id.hasSuffix("-")
            },
            "ids are slugs"
        )
    }

    func testEveryShortcutHasASpanishNameAndAModifier() {
        for shortcut in SystemShortcut.all {
            XCTAssertFalse(shortcut.nameKey.isEmpty, shortcut.id)
            // A combination without a modifier would fire on its own while the user types, so every
            // entry in the catalog must be a real shortcut, not a bare key.
            XCTAssertFalse(shortcut.combo.modifiers.isEmpty, "\(shortcut.id) has no modifier")
            XCTAssertFalse(shortcut.combo.glyph.isEmpty, shortcut.id)
        }
    }

    func testNoTwoShortcutsShareACombination() {
        let combos = SystemShortcut.all.map(\.combo)

        XCTAssertEqual(Set(combos).count, combos.count, "two names for the same keys")
    }

    func testEveryCategoryIsRepresentedAndFilteringKeepsTheGroup() {
        for category in SystemShortcut.Category.allCases {
            let shortcuts = SystemShortcut.inCategory(category)

            XCTAssertFalse(shortcuts.isEmpty, category.rawValue)
            XCTAssertTrue(shortcuts.allSatisfy { $0.category == category }, category.rawValue)
        }
    }

    func testTheGlyphsFollowTheMacOSOrdering() {
        // Control, option, shift, command, then the key: the order Apple uses everywhere.
        XCTAssertEqual(SystemShortcut.all.first { $0.id == "mission-control" }?.combo.glyph, "⌃↑")
        XCTAssertEqual(SystemShortcut.all.first { $0.id == "switch-app" }?.combo.glyph, "⌘⇥")
        XCTAssertEqual(SystemShortcut.all.first { $0.id == "force-quit" }?.combo.glyph, "⌥⌘⎋")
        XCTAssertEqual(SystemShortcut.all.first { $0.id == "screenshot-area" }?.combo.glyph, "⇧⌘4")
    }

    func testNoShortcutIsPlainEscape() {
        // Plain Escape ends a capture, so offering it here would be a trap: choosing it would look
        // like a mapping and then cancel instead.
        for shortcut in SystemShortcut.all {
            XCTAssertNotEqual(shortcut.combo, KeyCombo(.escape), shortcut.id)
        }
    }

    func testAShortcutIsWrittenAsAnOrdinaryKeyMapping() {
        // No new action case and no new permission: the catalog writes the same `.key` mapping a
        // captured press would.
        var library = ProfileLibrary(profiles: [StoredProfile(name: "Prueba", profile: .standard)])
        let shortcut = SystemShortcut.inCategory(.windows)[0]

        library.selectedProfileID = library.profiles[0].id

        XCTAssertTrue(library.setAction(shortcut.action, for: .buttonA))
        XCTAssertEqual(library.selectedProfile?.profile.action(for: .buttonA), .key(shortcut.combo))
    }

    func testTheEditingCatalogNamesTheCommandsEveryoneUses() {
        // Asked for by name: «copiar (cmd + c), pegar (cmd + v)». They are offered as data so the user
        // does not have to memorise the combination and capture it by hand.
        let editing = SystemShortcut.inCategory(.editing)
        let byID = Dictionary(uniqueKeysWithValues: editing.map { ($0.id, $0) })

        XCTAssertEqual(byID["copy"]?.combo.glyph, "⌘C")
        XCTAssertEqual(byID["paste"]?.combo.glyph, "⌘V")
        XCTAssertEqual(byID["cut"]?.combo.glyph, "⌘X")
        XCTAssertEqual(byID["select-all"]?.combo.glyph, "⌘A")
        XCTAssertEqual(byID["paste-plain"]?.combo.glyph, "⌥⇧⌘V")
        // The stored value is the English key; the name is resolved in whichever language is asked.
        let spanish = Locale(identifier: "es")
        XCTAssertEqual(byID["copy"]?.nameKey, "Copy")
        XCTAssertEqual(Localization.resolve(byID["copy"]!.name, locale: spanish), "Copiar")
        XCTAssertEqual(Localization.resolve(byID["paste"]!.name, locale: spanish), "Pegar")
    }

    func testEveryCatalogEntryWritesWhatACaptureWouldWrite() {
        // S7: choosing a catalog entry must produce exactly the mapping a captured press produces, so
        // the two paths cannot drift into different actions for the same keys.
        for shortcut in SystemShortcut.all {
            let captured = MappingRules.capture(
                forKeyCode: shortcut.combo.keyCode,
                modifiers: shortcut.combo.modifiers
            )

            XCTAssertEqual(captured, .mapped(shortcut.action), shortcut.id)
        }
    }
}
