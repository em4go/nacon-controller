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
        case windows
        case apps
        case system

        /// Spanish heading.
        public var title: String {
            switch self {
            case .windows: return "Ventanas y escritorios"
            case .apps: return "Aplicaciones"
            case .system: return "Sistema"
            }
        }
    }

    /// Stable slug, used as the menu identity.
    public let id: String
    /// Spanish name shown in the menu.
    public let name: String
    public let category: Category
    /// The keys the system will receive.
    public let combo: KeyCombo

    /// What the editor must write. An ordinary `.key` mapping, the same a captured press produces.
    public var action: MappedAction {
        .key(combo)
    }

    private init(_ id: String, _ name: String, _ category: Category, _ keyCode: UInt16, _ modifiers: ModifierSet) {
        self.id = id
        self.name = name
        self.category = category
        self.combo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
    }

    /// Every shortcut the editor offers, in menu order.
    ///
    /// Kept to combinations macOS ships enabled by default, so the catalog works on a fresh system.
    /// Bare keys are absent on purpose: the engine sends them while the user may be typing.
    public static let all: [SystemShortcut] = [
        // Windows and desktops.
        SystemShortcut("mission-control", "Mission Control", .windows, 126, [.control]),
        SystemShortcut("app-windows", "Mostrar las ventanas de la app", .windows, 125, [.control]),
        SystemShortcut("space-left", "Escritorio a la izquierda", .windows, 123, [.control]),
        SystemShortcut("space-right", "Escritorio a la derecha", .windows, 124, [.control]),
        SystemShortcut("close-window", "Cerrar la ventana", .windows, 13, [.command]),

        // Applications.
        SystemShortcut("switch-app", "Cambiar de aplicación", .apps, 48, [.command]),
        SystemShortcut("next-window", "Ventana siguiente de la misma app", .apps, 50, [.command]),
        SystemShortcut("quit-app", "Cerrar la aplicación", .apps, 12, [.command]),
        SystemShortcut("force-quit", "Forzar la salida de la aplicación", .apps, 53, [.option, .command]),

        // System.
        SystemShortcut("spotlight", "Buscar (Spotlight)", .system, 49, [.command]),
        SystemShortcut("screenshot-screen", "Capturar la pantalla completa", .system, 20, [.command, .shift]),
        SystemShortcut("screenshot-area", "Capturar una zona", .system, 21, [.command, .shift]),
        SystemShortcut("screenshot-options", "Opciones de captura y grabación", .system, 23, [.command, .shift]),
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
        return text + Self.keyGlyph(for: keyCode)
    }

    /// Symbols for the keys this app can produce. An unknown code stays honest instead of guessing.
    private static func keyGlyph(for keyCode: UInt16) -> String {
        switch keyCode {
        case 12: return "Q"
        case 13: return "W"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Espacio"
        case 50: return "`"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "tecla \(keyCode)"
        }
    }
}
