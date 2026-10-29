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
        XCTAssertEqual(KeyCatalog.name(for: 49, locale: Locale(identifier: "es")), "Espacio")
        XCTAssertEqual(KeyCatalog.name(for: 51, locale: Locale(identifier: "es")), "Borrar")
        XCTAssertEqual(KeyCatalog.name(for: 53), "Esc")
        XCTAssertEqual(KeyCatalog.name(for: 123), "←")
        XCTAssertEqual(KeyCatalog.name(for: 124), "→")
        XCTAssertEqual(KeyCatalog.name(for: 125), "↓")
        XCTAssertEqual(KeyCatalog.name(for: 126), "↑")
    }

    func testTheRestOfTheNavigationKeysAreNamedToo() {
        XCTAssertEqual(KeyCatalog.name(for: 115, locale: Locale(identifier: "es")), "Inicio")
        XCTAssertEqual(KeyCatalog.name(for: 119, locale: Locale(identifier: "es")), "Fin")
        XCTAssertEqual(KeyCatalog.name(for: 116, locale: Locale(identifier: "es")), "Re Pág")
        XCTAssertEqual(KeyCatalog.name(for: 121, locale: Locale(identifier: "es")), "Av Pág")
        XCTAssertEqual(KeyCatalog.name(for: 76), "⌤")
        XCTAssertEqual(KeyCatalog.name(for: 117), "⌦")
        XCTAssertEqual(KeyCatalog.name(for: 114, locale: Locale(identifier: "es")), "Ayuda")
    }

    /// Copy guard: the interface is Spanish, and the old catalog printed English words on the
    /// badges. Glyphs and single characters are language neutral, so only whole words are checked.
    func testEveryWordIsTranslated() {
        // The base text is English now, so what this test guards is the other direction: a word that
        // the editor shows in Spanish must differ from its English base, or it is untranslated.
        let english = Locale(identifier: "en")
        let spanish = Locale(identifier: "es")
        for code: UInt16 in [49, 51, 114, 115, 116, 119, 121] {
            XCTAssertNotEqual(
                KeyCatalog.name(for: code, locale: spanish),
                KeyCatalog.name(for: code, locale: english),
                "key \(code) reads the same in both languages"
            )
        }
    }

    func testWordsHaveAnEnglishNameToo() {
        // The base text is English; the Spanish translation is the one the editor shows today.
        let english = Locale(identifier: "en")
        XCTAssertEqual(KeyCatalog.name(for: 49, locale: english), "Space")
        XCTAssertEqual(KeyCatalog.name(for: 51, locale: english), "Delete")
        XCTAssertEqual(KeyCatalog.name(for: 116, locale: english), "Page Up")
        XCTAssertEqual(KeyCatalog.name(for: 114, locale: english), "Help")
    }
}
