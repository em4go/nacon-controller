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
    /// The graphical view shows the pressed controls, so the section reads the last report.
    @EnvironmentObject private var service: ControllerService

    /// Which of the two views the user last chose. Remembered between launches like the rest of the
    /// preferences, because the choice is about how the window is read, not about this profile.
    @AppStorage("padViewMode") private var viewMode: PadViewMode = .graph

    @State private var isRenaming = false
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Perfiles")
            profilePicker
            actions
            viewPicker
            // S3: the view for the profile being edited, right below the picker that selects it.
            if let selected = profiles.selectedProfile {
                Divider()
                switch viewMode {
                case .graph:
                    // The graphical view only renders: the profile comes in, nothing goes out. Press
                    // states come from the report of the connected pad.
                    PadGraphView(
                        profile: selected.profile,
                        report: service.report,
                        isEmulationEnabled: emulation.isEnabled
                    )
                    // PS is not a row in the table either, and it must stay visible in both views:
                    // it is the emulation switch and has to remain reachable.
                    reservedControlRow
                case .table:
                    MappingEditor(
                        profile: selected.profile,
                        profileID: selected.id,
                        isEmulationEnabled: emulation.isEnabled,
                        setAction: { armedProfileID, control, action in
                            // F5: a capture belongs to the profile it was armed for. `KeyCaptureSession`
                            // reports that identifier with the mapping, so a selection that moved while
                            // a key was in flight drops the write instead of landing on the profile the
                            // user has just selected.
                            guard armedProfileID == profiles.selectedProfile?.id else { return }
                            // The controller persists every change, so the edit survives a restart (S6).
                            profiles.setAction(action, for: control)
                        }
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
