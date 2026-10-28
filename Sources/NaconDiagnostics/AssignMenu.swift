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
    /// Whether the menu offers the key capture at all.
    ///
    /// It is only meaningful for the base: a capture arms the base layer (the capture path does not
    /// know about the layer), so a menu assigning to the layer shows the same catalog without an entry
    /// that would write somewhere else. Omitting the entry and its divider is what keeps the two
    /// submenus honest instead of greying out a button that must not be pressed.
    var includesCapture: Bool = true
    /// Arms the capture for the control the menu belongs to, for the same reason the capture button
    /// exists: a key macOS swallows never reaches a local monitor, and a menu entry is then the only
    /// way to express it. Only read when `includesCapture` is true.
    var onCapture: () -> Void = {}
    let onChoose: (MappedAction) -> Void

    var body: some View {
        if includesCapture {
            Button("Capturar tecla…") {
                onCapture()
            }
            Divider()
        }
        ForEach([MouseButton.left, .middle, .right], id: \.self) { button in
            Button(MappingRules.label(for: .mouseButton(button))) {
                onChoose(.mouseButton(button))
            }
        }
        Divider()
        Button(MappingRules.label(for: MappingRules.scrollUpAction)) {
            onChoose(MappingRules.scrollUpAction)
        }
        Button(MappingRules.label(for: MappingRules.scrollDownAction)) {
            onChoose(MappingRules.scrollDownAction)
        }
        Divider()
        // macOS actions that are really keystrokes. Offering them saves memorising a combination, and
        // the submenu says which ones depend on a setting in System Settings.
        ForEach(SystemShortcut.Category.allCases, id: \.self) { category in
            Menu(category.title) {
                ForEach(SystemShortcut.inCategory(category)) { shortcut in
                    Button("\(shortcut.name) — \(shortcut.combo.glyph)") {
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
        Menu("Mantener modificador") {
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
        Button(MappingRules.label(for: .none)) {
            onChoose(.none)
        }
    }
}
