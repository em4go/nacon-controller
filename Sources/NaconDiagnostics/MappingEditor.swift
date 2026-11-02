import NaconCore
import SwiftUI

/// S3: the per-control mapping editor for the profile being edited.
///
/// The editor only renders state and forwards intents. Everything that decides what a press means
/// (which controls are remappable, whether arming is safe, what a captured key becomes, when a
/// capture ends, how an action reads) lives in `MappingRules` and `KeyCaptureSession`, and the write
/// itself is handed in by the caller so this view never touches persistence. Two safety rules shape
/// the layout:
///
/// - PS has no editor row at all, because it is the emulation switch and must stay reachable.
/// - The whole editor is disabled while emulation runs: swapping a mapping with a button held can
///   leave a key stuck down.
///
/// Each row carries the base and the MOD layer side by side (S3): the two layers are the same
/// controls read twice, so they belong on the same line instead of behind a mode switcher that would
/// hide half of what a control does.
struct MappingEditor: View {
    /// The mapping of the selected profile.
    let profile: InputProfile
    /// Identifier of the profile that mapping belongs to. A capture is bound to it, so a key press
    /// arriving after a profile switch cannot land on the newly selected profile.
    let profileID: UUID
    /// Whether emulation is running, which locks the editor.
    let isEmulationEnabled: Bool
    /// Applies one write to the profile on screen: a menu choice, a shortened command, or a capture
    /// the section has already resolved. The section turns it into a `MappingWrite` and lets the
    /// library apply it, so the profile guard is not duplicated here.
    let onWrite: (UUID, XInputControl, MappingColumn, MappedAction) -> Void
    /// The one capture of the section, shared with the graphical view. The section owns it so a
    /// capture armed in either view is the same session, with the same monitor and the same rules.
    @ObservedObject var capture: MappingCapture

    /// S3: the MOD column only exists when a key can open it.
    ///
    /// Without a key the layer can never apply, so a column of assignments the user could set and
    /// never reach would be a trap. The note below the table says how to get the column instead.
    private var showsLayer: Bool {
        profile.layer.isActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(AppText.resolve("Control mapping"))
            Text(AppText.resolve(
                """
                Press “Capture” and then the combination you want to assign, with the modifiers you \
                need (⌘, ⌥, ⌃, ⇧). Escape cancels the capture and keeps the previous mapping.
                """
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            if isEmulationEnabled {
                lockedCaption
            }
            VStack(alignment: .leading, spacing: 6) {
                if showsLayer {
                    columnHeader
                }
                // S9: the rows arrive in named sections. Seventeen identical lines made a reader
                // scan for «the D-pad»; a header says where the D-pad starts.
                ForEach(MappingRules.groupedRemappableControls) { section in
                    groupHeader(section.group)
                    ForEach(section.controls, id: \.self) { control in
                    MappingRow(
                        control: control,
                        action: profile.action(for: control),
                        // Only asked when the column exists: an entry of a closed layer is inert, and
                        // the row would be showing what can never happen.
                        layerAction: showsLayer ? profile.layer.action(for: control) : nil,
                        showsLayer: showsLayer,
                        // The row asks the capture itself which cell is waiting and keeps the two
                        // verbs apart: its buttons cancel, its menu entries only arm.
                        capture: capture,
                        profileID: profileID,
                        isEmulationRunning: isEmulationEnabled,
                        onWrite: { column, action in onWrite(profileID, control, column, action) }
                    )
                    }
                }
                ReservedControlRow()
            }
            .disabled(isEmulationEnabled)
            if !showsLayer {
                Text(AppText.resolve(
                    """
                    To get a second layer, choose a MOD key above, in “MOD key:”. With it held, each \
                    button sends what the MOD column says and, if you have changed nothing, the same \
                    as the base.
                    """
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Text(AppText.resolve(
                """
                The PS button cannot be reassigned: it is the switch that turns emulation on and off \
                without touching the mouse or the keyboard, so it must always stay within reach.
                """
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .onDisappear {
            // Leaving the table (a switch to «Gráfica», a profile change) removes this view, so the
            // pending press and its monitor must go with it: the section installs the write, and a
            // capture must never land on a control the user is no longer looking at.
            capture.end()
        }
    }

    /// S3: one header line for the whole table, naming the two columns once instead of on every row.
    ///
    /// «Base» starts exactly where the base value starts, because both lines begin with the same empty
    /// control-name column. «MOD» sits at the trailing end, above the MOD column it names.
    private var columnHeader: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 96, height: 1)
            Text(AppText.resolve("Base"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: "MOD")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
    }

    /// The name of a section, drawn above its first row.
    private func groupHeader(_ group: MappingGroup) -> some View {
        Text(AppText.resolve(group.title))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.top, 6)
    }

    private var lockedCaption: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.orange)
            Text(AppText.resolve("Emulation is running, so the mapping is locked. Stop emulation to change it: changing an assignment with a button held down can leave a key stuck."))
            .font(.caption)
            .foregroundStyle(.orange)
        }
    }
}

/// One remappable control: its two readings, the capture button and the fixed alternatives.
///
/// The base half is the editor it has always been; the MOD half only appears when the profile has a
/// key that opens the layer (S3), and it mirrors the base so the same control is read left to right
/// instead of in two places.
private struct MappingRow: View {
    let control: XInputControl
    let action: MappedAction
    /// The layer's own assignment, or `nil` when the layer has no entry for this control — which is
    /// not the same as an entry that sends nothing (S2).
    let layerAction: MappedAction?
    /// Whether the MOD half of the row exists at all.
    let showsLayer: Bool
    /// The one capture of the section. The row asks it which cell is waiting and arms or cancels it,
    /// so it needs no flag of its own.
    let capture: MappingCapture
    /// Profile the row's controls belong to; a capture is armed for it, never for another.
    let profileID: UUID
    /// Whether emulation is running, which refuses the arming.
    let isEmulationRunning: Bool
    /// Writes one action into one column of this control.
    let onWrite: (MappingColumn, MappedAction) -> Void

    /// Whether the base cell is the one waiting for a key. Only one control and one column at a time
    /// can be armed, so the other cell keeps its normal label: two buttons reading «Cancelar» would
    /// say both are armed.
    private var isWaitingInBase: Bool {
        capture.armedColumn(for: control) == .base
    }

    /// Whether the MOD cell is the one waiting for a key.
    private var isWaitingInMod: Bool {
        capture.armedColumn(for: control) == .mod
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(Localization.resolve(ControlFacts.of(control).label))
                .font(.callout.weight(.medium))
                .frame(width: 96, alignment: .leading)
            Text(isWaitingInBase ? AppText.resolve("Press a key…") : action.displayName)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(isWaitingInBase ? Color.accentColor : Color.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(isWaitingInBase ? AppText.resolve("Cancel") : AppText.resolve("Capture")) {
                capture.toggle(
                    control,
                    for: profileID,
                    intent: .base,
                    isEmulationRunning: isEmulationRunning
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            // The button was drawn in whatever width was left, and «Capturar» arrived as «Capt…».
            // A control that names its action asks for the width its words need.
            .fixedSize()
            Menu {
                alternatives
            } label: {
                Label(AppText.resolve("Choose…"), systemImage: "chevron.up.chevron.down")
                    .labelStyle(.titleAndIcon)
            }
            .menuStyle(.borderlessButton)
            .controlSize(.small)
            .fixedSize()
            if showsLayer {
                layerCell
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isWaitingInBase || isWaitingInMod
                        ? Color.accentColor.opacity(0.12)
                        : Color.secondary.opacity(0.06)
                )
        )
    }

    /// The MOD reading of the control: the layer's assignment, or a dash that says «the base wins».
    ///
    /// The dash is secondary, not empty, because a control with no entry in the layer still does
    /// something with MOD held: it does what the base says (S2).
    private var layerCell: some View {
        HStack(spacing: 10) {
            Text(isWaitingInMod ? AppText.resolve("Press a key…") : layerAction.map(\.displayName) ?? "—")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(layerAction == nil || isWaitingInMod ? Color.secondary : Color.primary)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)
                .help(layerHelp)
            // The same button the base column has, because the columns are the same thing read twice.
            // Without it the only way into the layer was a menu entry, which is not how the base
            // column teaches the gesture.
            Button(isWaitingInMod ? AppText.resolve("Cancel") : AppText.resolve("Capture")) {
                capture.toggle(
                    control,
                    for: profileID,
                    intent: .mod,
                    isEmulationRunning: isEmulationRunning
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .fixedSize()
            // The same list as the base, aimed at the column: a capture armed here writes into the
            // layer because that is the intent the arming menu declares, not a property of capture.
            Menu {
                AssignMenuItems(
                    onCapture: { arm(.mod) },
                    onChoose: { onWrite(.mod, $0) },
                    current: layerAction ?? .none,
                    onAppendStep: { arm(.modCommand) },
                    onDropLastStep: {
                        onWrite(.mod, MappingRules.droppingLastStep(from: layerAction ?? .none))
                    }
                )
            } label: {
                Label(AppText.resolve("Choose…"), systemImage: "chevron.up.chevron.down")
                    .labelStyle(.titleAndIcon)
            }
            .menuStyle(.borderlessButton)
            .controlSize(.small)
            .fixedSize()
            .help(AppText.resolve("Choose what this control sends while the MOD key is held"))
        }
    }

    private var layerHelp: String {
        guard let layerAction else {
            return AppText.resolve("With the MOD key it uses the base action")
        }
        return AppText.format("With the MOD key held it sends “%@”", layerAction.displayName)
    }

    /// What the capture button cannot express: mouse buttons, scrolling, the system catalog, the
    /// modifier holds and clearing the mapping. Shared with the drawing, so the two views cannot
    /// offer different destinations for the same control.
    private var alternatives: some View {
        AssignMenuItems(
            onCapture: { arm(.base) },
            onChoose: { onWrite(.base, $0) },
            current: action,
            onAppendStep: { arm(.baseCommand) },
            // Shortening a command is an ordinary write, so it goes through the same path a menu
            // choice takes and the profile is saved once, the same way.
            onDropLastStep: { onWrite(.base, MappingRules.droppingLastStep(from: action)) }
        )
    }

    /// Arms a capture from a menu entry. The entries name a destination, never a cancel, so this goes
    /// through `arm`: a pick while a capture is armed re-arms it instead of ending it.
    private func arm(_ intent: CaptureIntent) {
        capture.arm(
            control,
            for: profileID,
            intent: intent,
            isEmulationRunning: isEmulationRunning
        )
    }
}
