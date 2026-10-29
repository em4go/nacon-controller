import XCTest

@testable import NaconCore

/// The language preference: what it stores, and what it means for a lookup.
final class AppLanguageTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "nacon.tests.language"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testSystemMeansNoLocaleAtAll() {
        // Nil is what tells the lookup to use the running language; pinning "en" here would make the
        // default behave like an explicit choice and ignore the system.
        XCTAssertNil(AppLanguage.system.locale)
        XCTAssertEqual(AppLanguage.english.locale, Locale(identifier: "en"))
        XCTAssertEqual(AppLanguage.spanish.locale, Locale(identifier: "es"))
    }

    func testTheChoiceSurvivesTheProcess() {
        LanguagePreference.save(.spanish, to: defaults)
        XCTAssertEqual(LanguagePreference.load(from: defaults), .spanish)
    }

    func testNoChoiceOrAnUnknownOneMeansFollowTheSystem() {
        XCTAssertEqual(LanguagePreference.load(from: defaults), .system)
        defaults.set("fr", forKey: LanguagePreference.defaultsKey)
        XCTAssertEqual(LanguagePreference.load(from: defaults), .system)
    }

    func testTheChosenLanguageDrivesEveryLookup() {
        // The seam the whole interface goes through: with a language set, a lookup without a locale
        // answers in it.
        let previous = Localization.language
        defer { Localization.language = previous }

        Localization.language = .spanish
        XCTAssertEqual(Localization.resolve("Unassigned"), "Sin asignar")
        Localization.language = .english
        XCTAssertEqual(Localization.resolve("Unassigned"), "Unassigned")
    }
}
