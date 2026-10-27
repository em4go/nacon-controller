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
        // Editing and whitespace.
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape", 76: "Enter",
        117: "Forward Delete", 114: "Help",
        // Arrows and navigation.
        115: "Home", 116: "Page Up", 119: "End", 121: "Page Down",
        123: "Left Arrow", 124: "Right Arrow", 125: "Down Arrow", 126: "Up Arrow",
        // Function keys.
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7",
        100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}

extension KeyCombo {
    /// Human-readable form of the combo, modifiers first, e.g. "⌃⌥⇧⌘Q".
    public var displayName: String {
        var result = ""
        if modifiers.contains(.control) {
            result += "⌃"
        }
        if modifiers.contains(.option) {
            result += "⌥"
        }
        if modifiers.contains(.shift) {
            result += "⇧"
        }
        if modifiers.contains(.command) {
            result += "⌘"
        }
        return result + KeyCatalog.name(for: keyCode)
    }
}
