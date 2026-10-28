import Foundation

/// Result of one key press during a mapping capture.
public enum CaptureOutcome: Equatable, Sendable {
    /// The user asked to abort; the previous mapping must stay as it was.
    case cancel
    /// The captured press, ready to be stored as the new mapping.
    case mapped(MappedAction)
}

/// S3: the pure rules behind the per-control mapping editor.
///
/// The editor is SwiftUI and needs an event monitor to read the pressed key, but nothing that
/// decides *what* a press means belongs there: which controls may be remapped, what a captured key
/// press turns into, when a capture is cancelled and how an action is labelled all live here, so the
/// rules can be checked without a window.
public enum MappingRules {
    /// The control that is never remappable.
    ///
    /// PS is the emulation switch: it starts and stops emulation without touching the mouse or the
    /// keyboard, so it must always stay reachable even when every other mapping has been broken.
    public static let reservedControl: XInputControl = .guide

    /// Controls the editor shows a row for, in the same stable order as the rest of the UI.
    public static var remappableControls: [XInputControl] {
        XInputControl.allCases.filter(isRemappable)
    }

    public static func isRemappable(_ control: XInputControl) -> Bool {
        control != reservedControl
    }

    /// Whether a control may select the MOD layer.
    ///
    /// Same rule as the editor's rows: PS is the emergency stop, and a MOD key is spent choosing the
    /// layer instead of acting, so letting PS be one would put the way out of the emulation behind a
    /// button that no longer does what it says.
    public static func isLayerKeyEligible(_ control: XInputControl) -> Bool {
        isRemappable(control)
    }

    /// Scroll amount used by the editor's "scroll" choices.
    public static let scrollStepLines = 3

    /// Scroll towards the top of the document. `CGEvent` counts positive wheel values upwards.
    public static let scrollUpAction = MappedAction.scrollLines(scrollStepLines)

    /// Scroll towards the bottom of the document.
    public static let scrollDownAction = MappedAction.scrollLines(-scrollStepLines)

    /// Turns one key press into the mapping it should produce.
    ///
    /// Plain Escape cancels instead of becoming the mapping: without it the user could not abandon a
    /// capture. Escape combined with a modifier is a legitimate shortcut and is mapped normally, so
    /// a key the user really wants to assign stays reachable.
    public static func capture(forKeyCode keyCode: UInt16, modifiers: ModifierSet) -> CaptureOutcome {
        if keyCode == VirtualKey.escape.rawValue, modifiers.isEmpty {
            return .cancel
        }
        return .mapped(.key(KeyCombo(keyCode: keyCode, modifiers: modifiers)))
    }

    /// Whether a command can take one more step. A command is made of keystrokes, so a mouse button or
    /// a scroll amount has nothing to chain.
    public static func canAppendStep(to action: MappedAction) -> Bool {
        switch action {
        case .key, .sequence: return true
        default: return false
        }
    }

    /// The action with one more step at the end, normalised: appending to nothing is a plain key and
    /// appending to a key starts the chain.
    public static func appending(step combo: KeyCombo, to action: MappedAction) -> MappedAction {
        switch action {
        case .key(let existing): return .chained([existing, combo])
        case .sequence(let steps): return .chained(steps + [combo])
        default: return action
        }
    }

    /// The action without its last step, normalised: two steps become a plain key again, and an action
    /// that is not a chain is left alone.
    public static func droppingLastStep(from action: MappedAction) -> MappedAction {
        guard case .sequence(let steps) = action else { return action }
        return .chained(Array(steps.dropLast()))
    }

    /// Readable label for a mapping. Never empty, so a row always shows something.
    ///
    /// Keys defer to `KeyCombo.displayName`, which already covers every key code including the ones
    /// the catalog does not know.
    public static func label(for action: MappedAction) -> String {
        switch action {
        case .none:
            return "Sin asignar"
        case .key(let combo):
            return combo.displayName
        case .mouseButton(.left):
            return "Clic izquierdo"
        case .mouseButton(.right):
            return "Clic derecho"
        case .mouseButton(.middle):
            return "Clic central"
        case .scrollLines(0):
            return "Sin desplazamiento"
        case .sequence(let steps):
            return steps.map(\.displayName).joined(separator: " luego ")
        case .scrollLines(let lines):
            let amount = abs(lines)
            let unit = amount == 1 ? "línea" : "líneas"
            return lines > 0
                ? "Desplazar arriba \(amount) \(unit)"
                : "Desplazar abajo \(amount) \(unit)"
        }
    }
}


extension InputProfile {
    /// Assigns one control, refusing the reserved control.
    ///
    /// `.none` removes the entry instead of storing it, so a cleared mapping looks exactly like a
    /// control that was never assigned and the persisted file stays small.
    /// - Returns: whether the profile changed.
    @discardableResult
    public mutating func setAction(_ action: MappedAction, for control: XInputControl) -> Bool {
        guard MappingRules.isRemappable(control) else { return false }
        if case .none = action {
            mappings.removeValue(forKey: control)
        } else {
            mappings[control] = action
        }
        return true
    }
}
