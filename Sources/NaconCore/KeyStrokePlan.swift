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
///
/// A combo whose key is itself a modifier is a hold instead of a shortcut: pressing it holds the
/// modifiers, pressing nothing else. That is how a tool that listens for a modifiers-only
/// combination, such as a dictation app waiting for ⌃⇧, can be driven by one control.
public enum KeyStrokePlan {
    /// Left-hand modifier key codes, in the order a keyboard reports them and the order Apple
    /// prints them in a shortcut: ⌃⌥⇧⌘.
    static let modifiers: [(set: ModifierSet, keyCode: UInt16)] = [
        (.control, 59),
        (.option, 58),
        (.shift, 56),
        (.command, 55),
    ]

    /// True when the key is a modifier, so the mapping holds it rather than typing it.
    public static func isModifier(_ keyCode: UInt16) -> Bool {
        modifiers.contains { $0.keyCode == keyCode }
    }

    /// Every modifier a hold actually presses: the key itself plus whatever it is combined with.
    public static func heldModifiers(for combo: KeyCombo) -> ModifierSet {
        guard let own = modifiers.first(where: { $0.keyCode == combo.keyCode }) else {
            return combo.modifiers
        }
        return combo.modifiers.union(own.set)
    }

    /// The modifiers as mappings of their own: each one alone, then every pair.
    ///
    /// One control holding a modifier is what makes "hold it here, tap that there" possible, and the
    /// pairs exist because a real tool may listen for a combination of two, as dictation apps do.
    public static var holdCombos: [KeyCombo] {
        let singles = modifiers.map { KeyCombo(keyCode: $0.keyCode) }
        var pairs: [KeyCombo] = []
        for (index, first) in modifiers.enumerated() {
            for second in modifiers[(index + 1)...] {
                pairs.append(KeyCombo(keyCode: first.keyCode, modifiers: second.set))
            }
        }
        return singles + pairs
    }

    /// The strokes that produce, or release, `combo`.
    public static func strokes(for combo: KeyCombo, isDown: Bool) -> [KeyStroke] {
        guard !isModifier(combo.keyCode) else {
            return modifierStrokes(heldModifiers(for: combo), isDown: isDown)
        }
        let key = KeyStroke(keyCode: combo.keyCode, isDown: isDown, modifiers: combo.modifiers)
        let held = modifierStrokes(combo.modifiers, isDown: isDown)
        return isDown ? held + [key] : [key] + held
    }

    /// The stroke an auto-repeat posts, or `nil` for a hold.
    ///
    /// A keyboard repeating a held key does not press its modifiers again, so neither does this;
    /// doing so would stack modifier presses that no release ever balances. A held modifier does not
    /// repeat at all.
    public static func repeatStroke(for combo: KeyCombo) -> KeyStroke? {
        guard !isModifier(combo.keyCode) else { return nil }
        return KeyStroke(keyCode: combo.keyCode, isDown: true, modifiers: combo.modifiers)
    }

    private static func modifierStrokes(_ sets: ModifierSet, isDown: Bool) -> [KeyStroke] {
        let ordered = modifiers.filter { sets.contains($0.set) }

        guard isDown else {
            // Inside out. Each release carries the modifiers still held when it happens, so the last
            // one carries none; computing them from the full set would leave flags behind.
            var remaining = sets
            var strokes: [KeyStroke] = []
            for pair in ordered.reversed() {
                remaining.remove(pair.set)
                strokes.append(KeyStroke(keyCode: pair.keyCode, isDown: false, modifiers: remaining))
            }
            return strokes
        }

        var accumulated: ModifierSet = []
        return ordered.map { pair in
            accumulated.insert(pair.set)
            return KeyStroke(keyCode: pair.keyCode, isDown: true, modifiers: accumulated)
        }
    }
}

extension KeyCombo {
    /// True when the key is itself a modifier, so the mapping holds it instead of typing a key.
    public var isModifierHold: Bool {
        KeyStrokePlan.isModifier(keyCode)
    }
}
