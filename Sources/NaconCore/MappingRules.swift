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
        case .scrollLines(let lines):
            let amount = abs(lines)
            let unit = amount == 1 ? "línea" : "líneas"
            return lines > 0
                ? "Desplazar arriba \(amount) \(unit)"
                : "Desplazar abajo \(amount) \(unit)"
        }
    }

    /// Name of a control as shown in the editor. Spanish, like the rest of the user-facing copy.
    public static func controlLabel(for control: XInputControl) -> String {
        switch control {
        case .dpadUp: return "Cruceta ↑"
        case .dpadDown: return "Cruceta ↓"
        case .dpadLeft: return "Cruceta ←"
        case .dpadRight: return "Cruceta →"
        case .buttonA: return "✕ Cruz"
        case .buttonB: return "○ Círculo"
        case .buttonX: return "□ Cuadrado"
        case .buttonY: return "△ Triángulo"
        case .leftBumper: return "L1"
        case .rightBumper: return "R1"
        case .leftTrigger: return "L2"
        case .rightTrigger: return "R2"
        case .back: return "Share"
        case .start: return "Options"
        case .guide: return "PS"
        case .leftThumb: return "L3"
        case .rightThumb: return "R3"
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

extension ProfileLibrary {
    /// S3: edits one mapping of the profile being edited, and only that one.
    ///
    /// The library is the unit that reaches disk, so the editor mutates through it and the caller
    /// persists the result with the usual controller.
    /// - Returns: whether the library changed.
    @discardableResult
    public mutating func setAction(_ action: MappedAction, for control: XInputControl) -> Bool {
        guard MappingRules.isRemappable(control) else { return false }
        guard let selectedID = selectedProfile?.id,
              let index = profiles.firstIndex(where: { $0.id == selectedID })
        else { return false }
        guard profiles[index].profile.setAction(action, for: control) else { return false }
        return true
    }
}
