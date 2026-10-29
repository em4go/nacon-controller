import Foundation

/// The one place that turns a localizable reference into text.
///
/// Prepared text lives in the catalog of this module, so every resource here names `bundle: .module`:
/// without it the lookup would go to the main bundle — the application's — where a library's catalog
/// is not, and every string would silently fall back to its key.
///
/// The language of the lookup is a parameter, not an ambient fact. Tests pin it, and the in-app
/// selector of a later slice only has to pass a different `Locale` through this seam.
public enum Localization {
    /// Languages the app ships: English is the base, Spanish the translation.
    public static let supported = ["en", "es"]

    /// The language the interface speaks, set once at launch from the stored preference.
    ///
    /// It is read by every lookup that is not given a locale explicitly, so the whole interface follows
    /// one value instead of each view deciding for itself.
    public static var language: AppLanguage = .system

    /// A prepared text from this module's catalog.
    public static func resource(_ key: String) -> LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(stringLiteral: key), bundle: .module)
    }

    /// Resolves a resource, in the given language, the chosen one, or the system's.
    public static func resolve(_ resource: LocalizedStringResource, locale: Locale? = nil) -> String {
        guard let locale = locale ?? language.locale else { return String(localized: resource) }
        var pinned = resource
        pinned.locale = locale
        return String(localized: pinned)
    }

    /// Resolves a key of this module's catalog.
    public static func resolve(_ key: String, locale: Locale? = nil) -> String {
        resolve(resource(key), locale: locale)
    }

    /// Fills a translated pattern with already prepared text.
    ///
    /// A sentence that names something is one key with holes: two concatenated fragments cannot be
    /// reordered by a translator.
    public static func format(_ key: String, _ arguments: String...) -> String {
        String(format: resolve(key), arguments: arguments)
    }

    /// Spanish and English are the languages this project promises; anything else is a fallback to the
    /// base, which the interface is expected to survive.
    public static func locale(for language: String) -> Locale {
        supported.contains(language) ? Locale(identifier: language) : Locale(identifier: "en")
    }
}
