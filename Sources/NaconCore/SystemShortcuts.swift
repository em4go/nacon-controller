import Foundation

/// A macOS action that is expressed as a keystroke, offered ready-made instead of memorised.
///
/// Everything here is a plain key combination: the system interprets it exactly as if the user had
/// pressed it, so the app needs no new permission, no Apple Event and no private API. That is also
/// the limit, and it is honest to say it in one line: a shortcut works only while it is enabled in
/// System Settings, and the ones that move between desktops or applications do whatever the user
/// configured there (how many desktops exist, whether the application switcher is Cmd+Tab).
///
/// The catalog is data, so it carries the risks of data: a duplicated identifier, two names for the
/// same keys, or a bare key that would fire while the user is typing. The tests pin those invariants
/// rather than the individual entries.
public struct SystemShortcut: Identifiable, Hashable, Sendable {
    /// Menu grouping.
    public enum Category: String, CaseIterable, Hashable, Sendable {
        case editing
        case windows
        case apps
        case system

        /// Heading, resolved from this module's catalog.
        public var title: LocalizedStringResource {
            switch self {
            case .editing: return Localization.resource("Editing and documents")
            case .windows: return Localization.resource("Windows and desktops")
            case .apps: return Localization.resource("Applications")
            case .system: return Localization.resource("System")
            }
        }
    }

    /// Stable slug, used as the menu identity.
    public let id: String
    /// The catalog key of the name, which is its English base text.
    ///
    /// The key is what makes two shortcuts equal and what identifies the entry; the translated name is
    /// derived from it. Keeping the text out of the stored value is also what keeps this type
    /// `Hashable`, which `LocalizedStringResource` is not.
    public let nameKey: String
    public let category: Category
    /// The keys the system will receive.
    public let combo: KeyCombo

    /// Name shown in the menu, resolved from this module's catalog when it is needed.
    public var name: LocalizedStringResource {
        Localization.resource(nameKey)
    }

    /// What the editor must write. An ordinary `.key` mapping, the same a captured press produces.
    public var action: MappedAction {
        .key(combo)
    }

    private init(_ id: String, _ name: String, _ category: Category, _ keyCode: UInt16, _ modifiers: ModifierSet) {
        self.id = id
        self.nameKey = name
        self.category = category
        self.combo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
    }

    /// Every shortcut the editor offers, in menu order.
    ///
    /// Kept to combinations macOS ships enabled by default, so the catalog works on a fresh system.
    /// Bare keys are absent on purpose: the engine sends them while the user may be typing.
    public static let all: [SystemShortcut] = [
        // Editing and documents. These are conventions rather than system-wide shortcuts: every macOS
        // application that edits text answers to them, which is why they save memorising a combination.
        SystemShortcut("copy", "Copy", .editing, 8, [.command]),
        SystemShortcut("paste", "Paste", .editing, 9, [.command]),
        SystemShortcut("paste-plain", "Paste and Match Style", .editing, 9, [.shift, .option, .command]),
        SystemShortcut("cut", "Cut", .editing, 7, [.command]),
        SystemShortcut("undo", "Undo", .editing, 6, [.command]),
        SystemShortcut("redo", "Redo", .editing, 6, [.shift, .command]),
        SystemShortcut("select-all", "Select All", .editing, 0, [.command]),
        SystemShortcut("save", "Save", .editing, 1, [.command]),
        SystemShortcut("find", "Find in Document", .editing, 3, [.command]),
        SystemShortcut("print", "Print", .editing, 35, [.command]),
        SystemShortcut("new-tab", "New Tab", .editing, 17, [.command]),
        SystemShortcut("delete-word", "Delete Previous Word", .editing, 51, [.option]),
        SystemShortcut("line-start", "Move to Beginning of Line", .editing, 123, [.command]),
        SystemShortcut("line-end", "Move to End of Line", .editing, 124, [.command]),

        // Windows and desktops.
        SystemShortcut("mission-control", "Mission Control", .windows, 126, [.control]),
        SystemShortcut("app-windows", "Show App Windows", .windows, 125, [.control]),
        SystemShortcut("space-left", "Desktop Left", .windows, 123, [.control]),
        SystemShortcut("space-right", "Desktop Right", .windows, 124, [.control]),
        SystemShortcut("close-window", "Close Window", .windows, 13, [.command]),

        // Applications.
        SystemShortcut("switch-app", "Switch Application", .apps, 48, [.command]),
        SystemShortcut("next-window", "Next Window of the Same App", .apps, 50, [.command]),
        SystemShortcut("quit-app", "Quit App", .apps, 12, [.command]),
        SystemShortcut("force-quit", "Force Quit", .apps, 53, [.option, .command]),

        // System.
        SystemShortcut("spotlight", "Search (Spotlight)", .system, 49, [.command]),
        SystemShortcut("screenshot-screen", "Capture the Full Screen", .system, 20, [.command, .shift]),
        SystemShortcut("screenshot-area", "Capture an Area", .system, 21, [.command, .shift]),
        SystemShortcut("screenshot-options", "Capture and Recording Options", .system, 23, [.command, .shift]),
    ]

    /// The shortcuts of one category, in catalog order.
    public static func inCategory(_ category: Category) -> [SystemShortcut] {
        all.filter { $0.category == category }
    }
}

extension KeyCombo {
    /// The combination as macOS writes it: control, option, shift, command, then the key.
    public var glyph: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + KeyCatalog.glyph(for: keyCode)
    }

}

