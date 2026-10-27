import XCTest

@testable import NaconCore

final class KeyCatalogTests: XCTestCase {
    func testLettersDigitsAndPunctuationHaveNames() {
        XCTAssertEqual(KeyCatalog.name(for: 0), "A")
        XCTAssertEqual(KeyCatalog.name(for: 12), "Q")
        XCTAssertEqual(KeyCatalog.name(for: 50), "`")
        XCTAssertEqual(KeyCatalog.name(for: 18), "1")
        XCTAssertEqual(KeyCatalog.name(for: 29), "0")
        XCTAssertEqual(KeyCatalog.name(for: 43), ",")
        XCTAssertEqual(KeyCatalog.name(for: 47), ".")
    }

    /// The whole catalog is read by a Spanish interface, so every name here is either a Spanish
    /// word or the glyph macOS already prints on the keyboard. These are the names the badges of the
    /// graphical pad view show, which is where the English ones were visible.
    func testNavigationAndEditingKeysUseSpanishNamesOrGlyphs() {
        XCTAssertEqual(KeyCatalog.name(for: 36), "↩")
        XCTAssertEqual(KeyCatalog.name(for: 48), "⇥")
        XCTAssertEqual(KeyCatalog.name(for: 49), "Espacio")
        XCTAssertEqual(KeyCatalog.name(for: 51), "Borrar")
        XCTAssertEqual(KeyCatalog.name(for: 53), "Esc")
        XCTAssertEqual(KeyCatalog.name(for: 123), "←")
        XCTAssertEqual(KeyCatalog.name(for: 124), "→")
        XCTAssertEqual(KeyCatalog.name(for: 125), "↓")
        XCTAssertEqual(KeyCatalog.name(for: 126), "↑")
    }

    func testTheRestOfTheNavigationKeysAreNamedToo() {
        XCTAssertEqual(KeyCatalog.name(for: 115), "Inicio")
        XCTAssertEqual(KeyCatalog.name(for: 119), "Fin")
        XCTAssertEqual(KeyCatalog.name(for: 116), "Re Pág")
        XCTAssertEqual(KeyCatalog.name(for: 121), "Av Pág")
        XCTAssertEqual(KeyCatalog.name(for: 76), "⌤")
        XCTAssertEqual(KeyCatalog.name(for: 117), "⌦")
        XCTAssertEqual(KeyCatalog.name(for: 114), "Ayuda")
    }

    /// Copy guard: the interface is Spanish, and the old catalog printed English words on the
    /// badges. Glyphs and single characters are language neutral, so only whole words are checked.
    func testNoKnownNameIsAnEnglishWord() {
        let englishWords = [
            "Arrow", "Space", "Tab", "Return", "Delete", "Escape", "Enter", "Help",
            "Home", "End", "Page", "Up", "Down", "Left", "Right",
        ]

        let offenders = KeyCatalog.names.filter { _, name in
            let words = name.split(whereSeparator: { !$0.isLetter }).map(String.init)
            return words.contains { englishWords.contains($0) }
        }

        XCTAssertTrue(offenders.isEmpty, "English names left in the catalog: \(offenders)")
    }

    func testFunctionKeysHaveNames() {
        let expected = ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"]
        let keyCodes: [UInt16] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]

        XCTAssertEqual(keyCodes.map(KeyCatalog.name(for:)), expected)
    }

    func testUnknownKeyCodeStillRendersANonEmptyName() {
        let name = KeyCatalog.name(for: 200)

        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(name.contains("200"), "unexpected name for an unknown key: \(name)")
    }

    func testComboDisplayNameListsModifiersBeforeTheKey() {
        let combo = KeyCombo(keyCode: 12, modifiers: [.command, .shift, .option, .control])
        XCTAssertEqual(combo.displayName, "⌃⌥⇧⌘Q")

        XCTAssertEqual(KeyCombo(keyCode: 48).displayName, "⇥")
        XCTAssertEqual(KeyCombo(keyCode: 200).displayName, KeyCatalog.name(for: 200))
    }

    /// A shortcut is rendered modifiers-first around the Spanish key name, which is what the table
    /// and the badges show once a capture lands.
    func testComboDisplayNameWrapsTheSpanishKeyName() {
        XCTAssertEqual(KeyCombo(keyCode: 48, modifiers: [.command]).displayName, "⌘⇥")
        XCTAssertEqual(KeyCombo(keyCode: 126, modifiers: [.shift, .option]).displayName, "⌥⇧↑")
        XCTAssertEqual(KeyCombo(keyCode: 51, modifiers: [.control]).displayName, "⌃Borrar")
    }

    func testComboKeepsAnyKeyCode() {
        let combo = KeyCombo(keyCode: 500, modifiers: [.command])
        XCTAssertEqual(combo.keyCode, 500)
        XCTAssertTrue(combo.displayName.hasSuffix(KeyCatalog.name(for: 500)))
    }
}
