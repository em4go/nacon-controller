import Foundation
import NaconCore

/// The application's own string catalog.
///
/// `Localization` in the core resolves against the core's bundle, because that is where the labels the
/// core produces live. The interface text of the app lives in the app's bundle, so it needs its own
/// entry point with the same two rules: the base text is the key, and the language is a parameter so a
/// test — or the selector of a later slice — can pin it.
enum AppText {
    /// A prepared text from this target's catalog.
    static func resource(_ key: String) -> LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(stringLiteral: key), bundle: .module)
    }

    /// Resolves one of this target's keys, in the running language or one the caller pins.
    static func resolve(_ key: String, locale: Locale? = nil) -> String {
        resolve(resource(key), locale: locale)
    }

    /// Resolves a resource of this target, optionally in a pinned language.
    static func resolve(_ resource: LocalizedStringResource, locale: Locale? = nil) -> String {
        guard let locale else { return String(localized: resource) }
        var pinned = resource
        pinned.locale = locale
        return String(localized: pinned)
    }

    /// Fills a translated pattern with already prepared text.
    ///
    /// Interface sentences that name a control or an action are one key with holes, never a
    /// concatenation: the translator has to be able to move the hole, and a concatenated sentence
    /// cannot be reordered without reading wrong.
    static func format(_ key: String, _ arguments: String...) -> String {
        String(format: resolve(key), arguments: arguments)
    }
}
