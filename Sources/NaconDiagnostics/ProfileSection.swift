import NaconCore
import SwiftUI

/// S1, S3, S4, S5, S6, S8: the saved profiles and the mapping of the selected one, in the app window.
///
/// The section only renders state and forwards intents. Every rule (unique names, the standard
/// mapping for a new profile, refusing to delete the last profile, which neighbour to select, which
/// controls may be remapped) lives in `ProfileLibrary` and `MappingRules` and is covered by tests.
struct ProfileSection: View {
    @ObservedObject var profiles: ProfileLibraryController
    /// S3: the mapping editor has to be locked while emulation runs, so the section reads that state.
    @EnvironmentObject private var emulation: EmulationController
    /// The graphical view shows the pressed controls. It is handed the feed and reads it inside its
    /// own highlight layer, so this section — and the assign menu it contains — never rebuilds for a
    /// report.
    let feed: ReportFeed

    /// Which of the two views the user last chose. Remembered between launches like the rest of the
    /// preferences, because the choice is about how the window is read, not about this profile.
    @AppStorage("padViewMode") private var viewMode: PadViewMode = .graph

    @State private var isRenaming = false
    /// Deleting takes the whole profile with it — mappings, layer, sensitivity — and nothing brings it
    /// back, so it asks first: the button sits one click away from the picker.
    @State private var isConfirmingDelete = false
    @State private var draftName = ""

    /// The one key capture of the section. Both views arm it, so whichever one is on screen has the
    /// same armed control, the same rules and the same event monitor -- and switching between them
    /// cannot leave two captures alive.
    @StateObject private var capture = MappingCapture()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(AppText.resolve("Profiles"))
            profilePicker
            actions
            viewPicker
            // S3: the view for the profile being edited, right below the picker that selects it.
            if let selected = profiles.selectedProfile {
                Divider()
                // S5: the key that opens the layer is chosen once, above whichever view is on screen.
                // Both views read the same layer, so two selectors would sooner or later offer two
                // different lists and the layer would depend on which view the user happened to open.
                modKeyRow
                Divider()
                switch viewMode {
                case .graph:
                    // The graphical view only renders and forwards the tap: the profile comes in, and
                    // the only thing that can go out is an armed capture, as in the table.
                    PadGraphView(
                        profile: selected.profile,
                        profileID: selected.id,
                        feed: feed,
                        isEmulationEnabled: emulation.isEnabled,
                        capture: capture,
                        onWrite: { control, column, action in
                            // The row names the column; the write itself is one seam, so a menu pick
                            // and a capture land the same way.
                            write(action, to: column, for: control, profileID: selected.id)
                        }
                    )
                    // The graph is rebuilt when the profile changes, so no cell can wear the state of
                    // the profile the user has just left. Ending a pending capture is the graph's own
                    // job — it owns no session, so a rebuild alone would leave one armed
                    // (`.onChange(of: profileID)` in `PadGraphView`).
                    .id(selected.id)
                    // PS is not a row in the table either, and it must stay visible in both views:
                    // it is the emulation switch and has to remain reachable.
                    reservedControlRow
                case .table:
                    MappingEditor(
                        profile: selected.profile,
                        profileID: selected.id,
                        isEmulationEnabled: emulation.isEnabled,
                        onWrite: { profileID, control, column, action in
                            write(action, to: column, for: control, profileID: profileID)
                        },
                        capture: capture
                    )
                    // Switching profiles rebuilds the editor, which ends any armed capture: a pending
                    // press must never land on the profile the user has just selected.
                    .id(selected.id)
                }
            }
            Text(
                AppText.resolve(
                    "Changes are saved as you make them; there is no save button. A new profile starts from the standard profile, and the active profile is remembered the next time you open the app."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            if let saveFailure = profiles.saveFailure {
                Text(saveFailure)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onAppear {
            // The section owns the capture, so it also owns what a finished capture means: one write
            // per key press, into the profile the capture was armed for. Installing it here instead
            // of in one of the two views keeps that true whichever view is showing.
            capture.onFinish = { outcome in
                // One rule decides everything else: the intent that came back with the press says
                // which column and whether it extends, and the profile guard in `ProfileLibrary`
                // drops a write aimed at a profile that is no longer selected.
                profiles.apply(
                    MappingWrite.resolve(outcome, editing: profiles.selectedProfile)
                )
            }
        }
        .onChange(of: emulation.isEnabled) { isRunning in
            // A capture started before emulation began would keep swallowing key presses, and the
            // table's guard is no longer the only place that can arm one.
            if isRunning {
                capture.end()
            }
        }
        .alert(AppText.resolve("Rename profile"), isPresented: $isRenaming) {
            TextField(AppText.resolve("Profile name"), text: $draftName)
            Button(AppText.resolve("Cancel"), role: .cancel) {
                draftName = ""
            }
            Button(AppText.resolve("Save")) {
                // A blank name is refused by the library, so the profile keeps its old name.
                profiles.renameSelectedProfile(to: draftName)
                draftName = ""
            }
        } message: {
            Text(AppText.resolve("The name cannot be empty."))
        }
        // A confirmation dialog and not a second alert: two `.alert` modifiers on the same view can
        // shadow each other, and the rename alert is attached right above.
        .confirmationDialog(
            AppText.resolve("Delete profile?"),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(AppText.resolve("Delete"), role: .destructive) {
                profiles.deleteSelectedProfile()
            }
            Button(AppText.resolve("Cancel"), role: .cancel) {}
        } message: {
            // The name is data, inserted through the hole: the sentence is one key, so a translator
            // can move the name where their grammar needs it.
            Text(
                AppText.format(
                    "“%@” and everything it holds — its mappings, the MOD layer and its sensitivity — will be deleted. This cannot be undone.",
                    profiles.selectedProfile?.name ?? ""
                )
            )
        }
    }

    /// Writes one action into one column of one control, through the one write seam.
    ///
    /// A menu choice, a shortened command and a capture the section resolved all come through here,
    /// so the profile guard, the column decision and the save are the same for the table and for the
    /// drawing. `ProfileLibrary` refuses a write aimed at a profile that is not selected, which is
    /// what keeps F5 true whichever view armed the capture.
    private func write(
        _ action: MappedAction,
        to column: MappingColumn,
        for control: XInputControl,
        profileID: UUID
    ) {
        profiles.apply(
            .apply(profileID: profileID, control: control, column: column, action: action)
        )
    }

    /// S5: the control that opens the layer, and the one way to remove the layer entirely.
    ///
    /// The entries are not listed here: they belong to the rows of the view below, in the MOD column,
    /// so the layer is edited where the controls are instead of in two places at once.
    private var modKeyRow: some View {
        let layer = profiles.selectedLayer
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(AppText.resolve("MOD key:"))
                    .font(.callout)
                Text(layer.key.map { AppText.resolve(ControlFacts.of($0).label) } ?? AppText.resolve("None"))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(layer.isActive ? Color.primary : Color.secondary)
                    .lineLimit(1)
                Menu {
                    // «Ninguna» closes the layer but keeps its entries; «Quitar capa» is the one that
                    // throws them away, so a slip of this menu cannot undo a whole set of assignments.
                    Button(AppText.resolve("None")) {
                        profiles.setLayerKey(nil)
                    }
                    Divider()
                    // S5: PS is not in this list. It is the emergency stop, and as a selector it would
                    // be spent choosing a layer instead of stopping the emulation.
                    ForEach(
                        XInputControl.allCases.filter { MappingRules.isLayerKeyEligible($0) },
                        id: \.self
                    ) { control in
                        Button(ControlFacts.of(control).label) {
                            profiles.setLayerKey(control)
                        }
                    }
                } label: {
                    Label(AppText.resolve("Choose…"), systemImage: "chevron.up.chevron.down")
                        .labelStyle(.titleAndIcon)
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)
                .fixedSize()
                Button(AppText.resolve("Remove layer")) {
                    profiles.clearLayer()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(layer.isEmpty)
                .help(
                    AppText.resolve("Removes the MOD key and all its assignments. The base does not change.")
                )
                Button(AppText.resolve("Show mapping")) {
                    emulation.toggleSummary()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                // Reading the map is allowed while emulating: it changes nothing.
                .help(AppText.resolve("Shows what each control sends. It stays open until you close it."))
                Spacer(minLength: 0)
            }
            // S7: the layer is frozen with the rest of the profile once emulation starts, so the
            // selector goes with the editor it belongs to instead of staying clickable.
            .disabled(emulation.isEnabled)
            if layer.isActive {
                Text(AppText.resolve("While you hold the MOD key down, the buttons send what the MOD column says; the MOD key itself sends nothing."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // The gesture needs a layer to open. Saying it here is what stops someone pressing
                // MOD+PS on a profile without one and turning the emulation off instead.
                Text(AppText.resolve("Without a MOD key there is no layer and no MOD+PS on the pad: PS alone turns emulation on and off. Use “Show mapping” to see the map."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var profilePicker: some View {
        Picker(AppText.resolve("Active profile"), selection: Binding(
            get: { profiles.selectedProfile?.id },
            set: { id in
                guard let id else { return }
                profiles.select(id)
            }
        )) {
            ForEach(profiles.profiles) { profile in
                Text(profile.name).tag(Optional(profile.id))
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 320, alignment: .leading)
    }

    /// «Gráfica» or «Tabla», the two ways to look at the profile being edited.
    ///
    /// Leaving the table removes `MappingEditor`, whose `onDisappear` disarms the capture and drops
    /// its key-event monitor: a pending press can never survive the switch and land later on a
    /// control the user is no longer looking at.
    private var viewPicker: some View {
        HStack(spacing: 8) {
            Text(AppText.resolve("View"))
                .font(.callout)
            Picker(AppText.resolve("View"), selection: $viewMode) {
                ForEach(PadViewMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
        }
    }

    /// The PS row of the graphical view. The table draws its own, identical one.
    private var reservedControlRow: some View {
        HStack(spacing: 10) {
            Text(ControlFacts.of(MappingRules.reservedControl).label)
                .font(.callout.weight(.medium))
                .frame(width: 96, alignment: .leading)
            Label(AppText.resolve("Reserved: turns emulation on and off instantly"), systemImage: "power")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(AppText.resolve("New profile")) {
                profiles.addProfile()
            }
            Button(AppText.resolve("Duplicate")) {
                profiles.duplicateSelectedProfile()
            }
            .disabled(profiles.selectedProfile == nil)
            Button(AppText.resolve("Rename…")) {
                draftName = profiles.selectedProfile?.name ?? ""
                isRenaming = true
            }
            .disabled(profiles.selectedProfile == nil)
            Button(AppText.resolve("Delete")) {
                isConfirmingDelete = true
            }
            .disabled(!profiles.canDeleteProfile)
        }
    }
}

/// The two ways to read the profile being edited.
///
/// Raw values are what `@AppStorage` persists, so they must not be renamed without a migration.
private enum PadViewMode: String, CaseIterable {
    case graph
    case table

    var title: String {
        switch self {
        case .graph: return AppText.resolve("Graph")
        case .table: return AppText.resolve("Table")
        }
    }
}
