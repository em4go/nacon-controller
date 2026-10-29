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
    @State private var draftName = ""

    /// The one key capture of the section. Both views arm it, so whichever one is on screen has the
    /// same armed control, the same rules and the same event monitor -- and switching between them
    /// cannot leave two captures alive.
    @StateObject private var capture = MappingCapture()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Perfiles")
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
                "Los cambios se guardan solos, sin botón de guardar. Un perfil nuevo parte del perfil "
                + "estándar, y el perfil activo se recuerda la próxima vez que abras la app."
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
        .alert("Renombrar perfil", isPresented: $isRenaming) {
            TextField("Nombre del perfil", text: $draftName)
            Button("Cancelar", role: .cancel) {
                draftName = ""
            }
            Button("Guardar") {
                // A blank name is refused by the library, so the profile keeps its old name.
                profiles.renameSelectedProfile(to: draftName)
                draftName = ""
            }
        } message: {
            Text("El nombre no puede quedar vacío.")
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
                Text("Tecla MOD:")
                    .font(.callout)
                Text(layer.key.map(MappingRules.controlLabel(for:)) ?? "Ninguna")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(layer.isActive ? Color.primary : Color.secondary)
                    .lineLimit(1)
                Menu {
                    // «Ninguna» closes the layer but keeps its entries; «Quitar capa» is the one that
                    // throws them away, so a slip of this menu cannot undo a whole set of assignments.
                    Button("Ninguna") {
                        profiles.setLayerKey(nil)
                    }
                    Divider()
                    // S5: PS is not in this list. It is the emergency stop, and as a selector it would
                    // be spent choosing a layer instead of stopping the emulation.
                    ForEach(
                        XInputControl.allCases.filter { MappingRules.isLayerKeyEligible($0) },
                        id: \.self
                    ) { control in
                        Button(MappingRules.controlLabel(for: control)) {
                            profiles.setLayerKey(control)
                        }
                    }
                } label: {
                    Label("Elegir…", systemImage: "chevron.up.chevron.down")
                        .labelStyle(.titleAndIcon)
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)
                .fixedSize()
                Button("Quitar capa") {
                    profiles.clearLayer()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(layer.isEmpty)
                .help(
                    "Elimina la tecla MOD y todas sus asignaciones. La base no cambia."
                )
                Spacer(minLength: 0)
            }
            // S7: the layer is frozen with the rest of the profile once emulation starts, so the
            // selector goes with the editor it belongs to instead of staying clickable.
            .disabled(emulation.isEnabled)
            if layer.isActive {
                Text(
                    "Mientras mantengas pulsada la tecla MOD, los botones envían lo que dice la "
                        + "columna MOD; la propia tecla MOD no envía nada."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var profilePicker: some View {
        Picker("Perfil activo", selection: Binding(
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
            Text("Vista")
                .font(.callout)
            Picker("Vista", selection: $viewMode) {
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
            Text(MappingRules.controlLabel(for: MappingRules.reservedControl))
                .font(.callout.weight(.medium))
                .frame(width: 96, alignment: .leading)
            Label("Reservado: activa y desactiva la emulación al instante", systemImage: "power")
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
            Button("Nuevo perfil") {
                profiles.addProfile()
            }
            Button("Duplicar") {
                profiles.duplicateSelectedProfile()
            }
            .disabled(profiles.selectedProfile == nil)
            Button("Renombrar…") {
                draftName = profiles.selectedProfile?.name ?? ""
                isRenaming = true
            }
            .disabled(profiles.selectedProfile == nil)
            Button("Eliminar") {
                profiles.deleteSelectedProfile()
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
        case .graph: return "Gráfica"
        case .table: return "Tabla"
        }
    }
}
