import Foundation

/// Human-readable names for `CGKeyCode` values.
///
/// Shortcuts are captured from the real keyboard, so the model has to carry any key code, not
/// only the small `VirtualKey` set. The catalog names the common keys and always renders
/// something for the rest, so the UI never has to deal with an empty label.
public enum KeyCatalog {
    /// Name for a key code. Unknown codes render as "Key <code>" instead of failing.
    public static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }

    static let names: [UInt16: String] = [
        // Letters.
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U",
        34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        // Digits.
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
        // Punctuation.
        24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\", 43: ",", 44: "/",
        47: ".", 50: "`",
        // Editing and whitespace. The interface is Spanish, so the names are Spanish words or the
        // glyph macOS already prints on the key itself: ↩ for return, ⇥ for tab, ⌤ for the keypad
        // enter and ⌦ for forward delete.
        36: "↩", 48: "⇥", 49: "Espacio", 51: "Borrar", 53: "Esc", 76: "⌤",
        117: "⌦", 114: "Ayuda",
        // Arrows and navigation.
        115: "Inicio", 116: "Re Pág", 119: "Fin", 121: "Av Pág",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        // Modifiers on their own. A mapping to one of these is a hold, and the label has to say so
        // without the interface looking like a shortcut.
        55: "⌘", 56: "⇧", 58: "⌥", 59: "⌃", 63: "fn",
        // Function keys.
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7",
        100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}

extension KeyCombo {
    /// Human-readable form of the combo, modifiers first, e.g. "⌃⌥⇧⌘Q".
    ///
    /// A hold has no key to name, so it prints only its modifiers, in the same order. Printing the
    /// key last would render ⌃⇧ as "⇧⌃", which reads like a shortcut somebody built the wrong way.
    public var displayName: String {
        // A hold's key is one of its modifiers, so the set to print is the key plus its companions.
        let shown = isModifierHold ? KeyStrokePlan.heldModifiers(for: self) : modifiers
        var result = shown.contains(.function) ? "fn" : ""
        if shown.contains(.control) {
            result += "⌃"
        }
        if shown.contains(.option) {
            result += "⌥"
        }
        if shown.contains(.shift) {
            result += "⇧"
        }
        if shown.contains(.command) {
            result += "⌘"
        }
        guard !isModifierHold else { return result }
        return result + KeyCatalog.name(for: keyCode)
    }
}
