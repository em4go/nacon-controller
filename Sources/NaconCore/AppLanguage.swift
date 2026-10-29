import Foundation

/// The language the interface speaks.
///
/// `system` is the default and the pattern Apple recommends; the two explicit values exist because this
/// app is read by someone who may run the whole system in one language and want the pad's copy in the
/// other.
public enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case english = "en"
    case spanish = "es"

    /// What to pass to a lookup, or nil to let the system decide.
    public var locale: Locale? {
        switch self {
        case .system: return nil
        case .english: return Locale(identifier: "en")
        case .spanish: return Locale(identifier: "es")
        }
    }

    /// Name of the option as the picker prints it. Each language names itself in its own language, so
    /// these three are the same text in both catalogs and are marked verbatim in the view.
    public var name: String {
        switch self {
        case .system: return ""
        case .english: return "English"
        case .spanish: return "Español"
        }
    }
}

/// Where the choice is stored, so the next launch starts in the language the user left.
public enum LanguagePreference {
    public static let defaultsKey = "appLanguage"

    public static func load(from defaults: UserDefaults = .standard) -> AppLanguage {
        guard let raw = defaults.string(forKey: defaultsKey) else { return .system }
        return AppLanguage(rawValue: raw) ?? .system
    }

    public static func save(_ language: AppLanguage, to defaults: UserDefaults = .standard) {
        defaults.set(language.rawValue, forKey: defaultsKey)
    }
}
