import NaconCore
import SwiftUI

/// S1, S4, S5, S6, S8: the saved profiles, listed and switchable from the app window.
///
/// The section only renders state and forwards intents. Every rule (unique names, the standard
/// mapping for a new profile, refusing to delete the last profile, which neighbour to select) lives
/// in `ProfileLibrary` and is covered by its tests.
struct ProfileSection: View {
    @ObservedObject var profiles: ProfileLibraryController

    @State private var isRenaming = false
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Perfiles")
            profilePicker
            actions
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
