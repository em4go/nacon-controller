import Foundation

/// One physical key event the emitter has to post.
public struct KeyStroke: Equatable, Sendable {
    public let keyCode: UInt16
    public let isDown: Bool
    public let modifiers: ModifierSet

    public init(keyCode: UInt16, isDown: Bool, modifiers: ModifierSet) {
        self.keyCode = keyCode
        self.isDown = isDown
        self.modifiers = modifiers
    }
}

/// Turns a mapped combo into the key events a real keyboard would produce.
///
/// Attaching the modifier flags to the key and never posting the modifier key itself tells the
/// system "Command is held" and never tells it that Command was released. The shortcut fires and
/// Command stays down: the application switcher never closes, and every later keystroke is read as
/// Command-something. A keyboard presses the modifier, presses the key, releases the key, and
/// releases the modifier, in that order, so that is what this plans.
public enum KeyStrokePlan {
    /// Left-hand modifier key codes, in the order a keyboard reports them and the order Apple
    /// prints them in a shortcut: ⌃⌥⇧⌘.
    static let modifiers: [(set: ModifierSet, keyCode: UInt16)] = [
        (.control, 59),
        (.option, 58),
        (.shift, 56),
        (.command, 55),
    ]

    /// The four modifiers as mappings of their own, so one control can hold what another triggers.
    public static var holdCombos: [KeyCombo] {
        modifiers.map { KeyCombo(keyCode: $0.keyCode) }
    }

    /// The strokes that produce, or release, `combo`.
    public static func strokes(for combo: KeyCombo, isDown: Bool) -> [KeyStroke] {
        // A combo whose key is itself a modifier is a hold, not a shortcut. One stroke is the whole
        // truth, and it makes "hold Command on the pad, tap Tab on the pad" possible.
        if let own = modifiers.first(where: { $0.keyCode == combo.keyCode }) {
            let others = combo.modifiers.subtracting(own.set)
            return [
                KeyStroke(
                    keyCode: combo.keyCode,
                    isDown: isDown,
                    modifiers: isDown ? others.union(own.set) : others
                )
            ]
        }

        let held = modifiers.filter { combo.modifiers.contains($0.set) }

        guard isDown else {
            // Reverse order: the key first, then the modifiers from the innermost outwards. Each
            // stroke carries the modifiers still held when it happens, so the last one carries none;
            // computing each from the full set instead would leave flags behind on the final release.
            var remaining = combo.modifiers
            var strokes = [KeyStroke(keyCode: combo.keyCode, isDown: false, modifiers: remaining)]
            for pair in held.reversed() {
                remaining.remove(pair.set)
                strokes.append(
                    KeyStroke(keyCode: pair.keyCode, isDown: false, modifiers: remaining)
                )
            }
            return strokes
        }

        var accumulated: ModifierSet = []
        var strokes = held.map { pair -> KeyStroke in
            accumulated.insert(pair.set)
            return KeyStroke(keyCode: pair.keyCode, isDown: true, modifiers: accumulated)
        }
        strokes.append(KeyStroke(keyCode: combo.keyCode, isDown: true, modifiers: combo.modifiers))
        return strokes
    }

    /// The stroke an auto-repeat posts: the key alone.
    ///
    /// A keyboard repeating a held key does not press its modifiers again, so neither does this;
    /// doing so would stack modifier presses that no release ever balances.
    public static func repeatStroke(for combo: KeyCombo) -> KeyStroke {
        KeyStroke(keyCode: combo.keyCode, isDown: true, modifiers: combo.modifiers)
    }
}
