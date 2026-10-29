import NaconCore
import SwiftUI

/// The contents of the assign menu: one definition, shared by the table row and the strip under the
/// drawing.
///
/// They used to be two copies, and a copy is what diverged: the modifier holds were added to the
/// table and the drawing never got them, so the same control offered different destinations depending
/// on which view the user happened to be in. The classes of choice are the same in both views because
/// there is now one list, not two that happen to agree.
///
/// The capture button is not here: in the table it is a button of its own beside the menu, and in the
/// strip it is a tap on the drawing. Only the menu is shared.
struct AssignMenuItems: View {
    /// Whether the menu offers the key capture and the step entries at all.
    ///
    /// The menu that arms decides where a capture writes, so every column offers the same list.
    ///
    /// Arms the capture for the control the menu belongs to: a key macOS swallows never reaches a
    /// local monitor, and a menu entry is then the only way to express it.
    let onCapture: () -> Void
    let onChoose: (MappedAction) -> Void
    /// What the control has now, so the menu can offer to extend a command or shorten one.
    var current: MappedAction = .none
    /// Arms a capture whose key becomes one more step of the command in `current`.
    var onAppendStep: (() -> Void)?
    /// Removes the last step of a command. A plain `onChoose` write already expresses the result.
    var onDropLastStep: (() -> Void)?

    var body: some View {
        Button(AppText.resolve("Capture a key…")) {
            onCapture()
        }
        if MappingRules.canAppendStep(to: current), let onAppendStep {
            Button(AppText.resolve("Add a step to the command…")) {
                onAppendStep()
            }
            if case .sequence = current, let onDropLastStep {
                Button(AppText.resolve("Remove the last step")) {
                    onDropLastStep()
                }
            }
        }
        Divider()
        ForEach([MouseButton.left, .middle, .right], id: \.self) { button in
            Button(MappedAction.mouseButton(button).displayName) {
                onChoose(.mouseButton(button))
            }
        }
        // Dragging something across the screen with a stick is the one gesture a click cannot do
        // comfortably, so the toggle sits next to it in the same list.
        ForEach([MouseButton.left, .middle, .right], id: \.self) { button in
            Button(MappedAction.toggledMouseButton(button).displayName) {
                onChoose(.toggledMouseButton(button))
            }
        }
        Divider()
        Button(MappingRules.scrollUpAction.displayName) {
            onChoose(MappingRules.scrollUpAction)
        }
        Button(MappingRules.scrollDownAction.displayName) {
            onChoose(MappingRules.scrollDownAction)
        }
        Divider()
        // macOS actions that are really keystrokes. Offering them saves memorising a combination, and
        // the submenu says which ones depend on a setting in System Settings.
        ForEach(SystemShortcut.Category.allCases, id: \.self) { category in
            Menu(Localization.resolve(category.title)) {
                ForEach(SystemShortcut.inCategory(category)) { shortcut in
                    Button(AppText.format("%@ — %@", Localization.resolve(shortcut.name), shortcut.combo.glyph)) {
                        onChoose(shortcut.action)
                    }
                }
            }
        }
        Divider()
        // Cycling the application switcher needs the modifier held while another key is tapped, which
        // one button cannot do. These map a single control to the modifier so two controls can, and a
        // tool that listens for a combination of modifiers with no key — a dictation app on ⌃⇧ — needs
        // exactly this.
        Menu(AppText.resolve("Hold a modifier")) {
            // Identity is the combo, not its key code: ⌃, ⌃⌥, ⌃⇧, ⌃⌘ and ⌃fn share code 59, and a
            // ForEach keyed on that renders five rows for the same identifier with the labels mixed.
            ForEach(KeyStrokePlan.holdCombos, id: \.self) { combo in
                // The full name, not the key alone: ⌃ and ⌃⇧ share a key code and would print twice as
                // "⌃", two entries the user cannot tell apart.
                Button(combo.displayName) {
                    onChoose(.key(combo))
                }
            }
        }
        Divider()
        Button(MappedAction.none.displayName) {
            onChoose(.none)
        }
    }
}
