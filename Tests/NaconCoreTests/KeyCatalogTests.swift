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

    func testNavigationAndEditingKeysHaveNames() {
        XCTAssertEqual(KeyCatalog.name(for: 36), "Return")
        XCTAssertEqual(KeyCatalog.name(for: 48), "Tab")
        XCTAssertEqual(KeyCatalog.name(for: 49), "Space")
        XCTAssertEqual(KeyCatalog.name(for: 51), "Delete")
        XCTAssertEqual(KeyCatalog.name(for: 53), "Escape")
        XCTAssertEqual(KeyCatalog.name(for: 123), "Left Arrow")
        XCTAssertEqual(KeyCatalog.name(for: 124), "Right Arrow")
        XCTAssertEqual(KeyCatalog.name(for: 125), "Down Arrow")
        XCTAssertEqual(KeyCatalog.name(for: 126), "Up Arrow")
        XCTAssertEqual(KeyCatalog.name(for: 115), "Home")
        XCTAssertEqual(KeyCatalog.name(for: 119), "End")
        XCTAssertEqual(KeyCatalog.name(for: 116), "Page Up")
        XCTAssertEqual(KeyCatalog.name(for: 121), "Page Down")
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

        XCTAssertEqual(KeyCombo(keyCode: 48).displayName, "Tab")
        XCTAssertEqual(KeyCombo(keyCode: 200).displayName, KeyCatalog.name(for: 200))
    }

    func testComboKeepsAnyKeyCode() {
        let combo = KeyCombo(keyCode: 500, modifiers: [.command])
        XCTAssertEqual(combo.keyCode, 500)
        XCTAssertTrue(combo.displayName.hasSuffix(KeyCatalog.name(for: 500)))
    }
}
