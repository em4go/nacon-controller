import XCTest

/// Every key the window resolves must exist in the window's own catalog.
///
/// `CatalogTests` proves that a key which is in the catalog has Spanish; it cannot see a key that was
/// never added, and that is the failure which reaches the user: the interface prints English while every
/// other key is translated, and no test complains. This reads the sources and the catalog, so a new
/// string cannot ship without its entry.
final class AppCatalogCoverageTests: XCTestCase {
    private static let sources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // NaconCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // the package root
        .appendingPathComponent("Sources/NaconDiagnostics")

    /// `AppText.resolve("...")` with a literal key. A key built at run time is skipped on purpose: it
    /// cannot be checked without running the code.
    private static let resolveCallPattern = #"AppText\.resolve\("((?:[^"\\]|\\.)*)""#

    func testEveryResolvedKeyExistsInTheAppCatalogWithSpanish() throws {
        let catalog = try loadCatalog()
        let keys = try resolvedKeys()

        XCTAssertFalse(keys.isEmpty, "the scan found no keys at all, so it is not proving anything")
        let missing = keys.subtracting(catalog.keys)
        XCTAssertEqual(missing.sorted(), [], "keys used by the window that the catalog does not have")

        let untranslated = catalog.filter { !$0.value }.keys
        XCTAssertEqual(untranslated.sorted(), [], "keys in the catalog with no Spanish")
    }

    private func resolvedKeys() throws -> Set<String> {
        let expression = try NSRegularExpression(pattern: Self.resolveCallPattern)
        guard let walker = FileManager.default.enumerator(at: Self.sources, includingPropertiesForKeys: nil) else {
            return []
        }
        var keys: Set<String> = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            let range = NSRange(source.startIndex..., in: source)
            for match in expression.matches(in: source, range: range) {
                guard let captured = Range(match.range(at: 1), in: source) else { continue }
                keys.insert(String(source[captured]))
            }
        }
        return keys
    }

    /// The catalog's keys, mapped to whether each one has a Spanish translation.
    private func loadCatalog() throws -> [String: Bool] {
        let path = Self.sources.appendingPathComponent("Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any]
        let strings = json?["strings"] as? [String: Any] ?? [:]
        return strings.mapValues { entry in
            let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any]
            let spanish = localizations?["es"] as? [String: Any]
            let unit = spanish?["stringUnit"] as? [String: Any]
            return !((unit?["value"] as? String) ?? "").isEmpty
        }
    }
}
