import XCTest

@testable import NaconCore

/// The catalog itself: every key it promises, resolved in both languages.
///
/// This is the test that a missing or mistyped entry cannot slip past, because it reads the file that
/// ships and asks the same seam the app asks. The interface strings of the app target have their own
/// catalog, which no test can read from here because that target is an executable; those are covered by
/// running the app in each language.
final class CatalogTests: XCTestCase {
    private var catalog: [String: Any] = [:]

    override func setUpWithError() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/NaconCore/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        catalog = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        try super.setUpWithError()
    }

    private var entries: [String: [String: Any]] {
        (catalog["strings"] as? [String: [String: Any]]) ?? [:]
    }

    func testTheCatalogDeclaresEnglishAsItsBaseLanguage() {
        XCTAssertEqual(catalog["sourceLanguage"] as? String, "en")
    }

    func testEveryKeyResolvesToItsSpanishTranslation() throws {
        let spanish = Locale(identifier: "es")
        var checked = 0
        for (key, entry) in entries {
            let localizations = entry["localizations"] as? [String: Any]
            let unit = localizations?["es"] as? [String: Any]
            // Plural entries carry variations instead of a single string; they are asserted by the
            // scroll label tests, which exercise the count in both languages.
            guard let value = (unit?["stringUnit"] as? [String: Any])?["value"] as? String else { continue }
            XCTAssertEqual(
                Localization.resolve(key, locale: spanish),
                value,
                "key “\(key)” does not resolve to its stored Spanish"
            )
            checked += 1
        }
        XCTAssertGreaterThan(checked, 80, "the catalog should be read, not skipped")
    }

    func testEveryKeyFallsBackToItsOwnTextInEnglish() {
        // English is the base and the key is its text, so an English lookup must return the key even
        // though most entries have no English translation at all.
        //
        // Plural entries are excluded: resolving one without a count hands back the catalog's plural
        // template, which is the mechanism working, not a missing translation. The scroll label tests
        // resolve those with a count in both languages.
        let english = Locale(identifier: "en")
        let flat = entries.filter { _, entry in
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            return localizations.values.allSatisfy { $0 is [String: Any] && (($0 as? [String: Any])?["variations"] == nil) }
        }
        XCTAssertGreaterThan(flat.count, 80, "the catalog should be read, not skipped")
        for key in flat.keys {
            XCTAssertEqual(Localization.resolve(key, locale: english), key)
        }
    }

    func testNoKeyIsLeftWithoutSpanish() {
        let missing = entries.filter { _, entry in
            let localizations = entry["localizations"] as? [String: Any]
            return localizations?["es"] == nil
        }.keys.sorted()
        XCTAssertEqual(missing, [], "keys without Spanish: \(missing)")
    }
}
