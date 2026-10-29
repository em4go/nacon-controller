import XCTest

@testable import NaconCore

/// The catalog and the one seam that reads it.
final class LocalizationTests: XCTestCase {
    private let english = Locale(identifier: "en")
    private let spanish = Locale(identifier: "es")

    func testTheCatalogResolvesInBothLanguages() {
        // English is the base, so the key is the text and English needs no entry at all.
        XCTAssertEqual(Localization.resolve("Unassigned", locale: english), "Unassigned")
        XCTAssertEqual(Localization.resolve("Unassigned", locale: spanish), "Sin asignar")
        XCTAssertEqual(Localization.resolve("Left click", locale: spanish), "Clic izquierdo")
    }

    func testAnUntranslatedKeyFallsBackToItsEnglishBase() {
        // A missing translation must never blank the interface: the key is the text.
        XCTAssertEqual(
            Localization.resolve("Nothing here yet", locale: spanish),
            "Nothing here yet"
        )
    }

    func testTheSupportedLanguagesAreEnglishAndSpanish() {
        XCTAssertEqual(Localization.supported, ["en", "es"])
        XCTAssertEqual(Localization.locale(for: "es").identifier, "es")
        XCTAssertEqual(
            Localization.locale(for: "fr").identifier,
            "en",
            "an unsupported language falls back to the base instead of half-translating"
        )
    }
}
