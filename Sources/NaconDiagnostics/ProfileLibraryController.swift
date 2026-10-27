import Combine
import Foundation
import NaconCore

/// Owns the saved profile library and the file it lives in.
///
/// Every mutation writes the library straight away (S6): there is no save button and no unsaved
/// state. A failed write is reported as a message instead of crashing, because an unwritable disk
/// must not take the pad down with it. Reading and the fallback rules stay in `ProfileLibrary` and
/// `ProfileStore`; this type only sequences "change, then save".
@MainActor
final class ProfileLibraryController: ObservableObject {
    @Published private(set) var library: ProfileLibrary
    /// Message shown in the UI when the last write failed. `nil` means everything is on disk.
    @Published private(set) var saveFailure: String?

    private let store: ProfileStore

    init(store: ProfileStore = ProfileStore()) {
        self.store = store
        self.library = store.load()
    }

    var profiles: [StoredProfile] { library.profiles }
    var selectedProfile: StoredProfile? { library.selectedProfile }
    var canDeleteProfile: Bool { library.canDeleteProfile }
    /// S1, S8: the mapping the emulation engine must start with.
    ///
    /// Read-only on purpose: the engine asks once at start, so an edit made while it runs only
    /// applies the next time emulation is started.
    var runtimeProfile: InputProfile { library.runtimeProfile }
    /// S2: the vertical-axis value of the profile being edited, shown by the toggle.
    var selectedInvertVerticalAxis: Bool { library.selectedInvertVerticalAxis }

    /// S8: the selection is part of the library, so it is written like any other change.
    func select(_ id: UUID) {
        guard library.selectedProfile?.id != id else { return }
        mutate { library in
            library.selectProfile(id: id)
            return true
        }
    }

    /// S5: a new profile copies the standard mapping, never an empty one.
    func addProfile() {
        mutate { library in
            library.addProfile()
            return true
        }
    }

    func duplicateSelectedProfile() {
        mutate { library in
            library.duplicateSelectedProfile() != nil
        }
    }

    /// The library refuses to remove the last profile, so the UI can never reach zero profiles.
    func deleteSelectedProfile() {
        guard let id = library.selectedProfile?.id else { return }
        mutate { library in library.deleteProfile(id: id) }
    }

    /// The library rejects blank names, so a refused rename keeps the previous one.
    func renameSelectedProfile(to name: String) {
        guard let id = library.selectedProfile?.id else { return }
        mutate { library in library.renameProfile(id: id, to: name) }
    }

    /// S3: applies one mapping to the profile being edited and saves it straight away.
    ///
    /// The rule that refuses Guide and the meaning of `.none` live in `ProfileLibrary.setAction`,
    /// so the controller only sequences "change, then save".
    func setAction(_ action: MappedAction, for control: XInputControl) {
        mutate { $0.setAction(action, for: control) }
    }

    /// S2: the vertical-axis setting belongs to the profile, so flipping the toggle edits the
    /// selected profile and saves it straight away like any other change.
    func setInvertVerticalAxis(_ newValue: Bool) {
        mutate { $0.setInvertVerticalAxis(newValue) }
    }

    // MARK: - S9: cursor sensitivity

    /// S9: the value a slider must show for the profile being edited.
    func selectedValue(for sensitivity: CursorSensitivity) -> Double? {
        library.selectedValue(for: sensitivity)
    }

    /// S9: writes one setting into the selected profile and saves it straight away.
    func setCursorSensitivity(_ sensitivity: CursorSensitivity, to raw: Double) {
        mutate { $0.setCursorSensitivity(sensitivity, to: raw) }
    }

    /// S9: restores the standard numbers on the selected profile only.
    func resetCursorSensitivity() {
        mutate { $0.resetCursorSensitivity() }
    }

    func rename(_ id: UUID, to name: String) {
        mutate { library in library.renameProfile(id: id, to: name) }
    }

    // MARK: - Saving

    private func mutate(_ change: (inout ProfileLibrary) -> Bool) {
        var updated = library
        guard change(&updated) else { return }
        let normalized = updated.normalized()
        guard normalized != library else { return }
        library = normalized
        persist()
    }

    private func persist() {
        do {
            try store.save(library)
            saveFailure = nil
        } catch {
            saveFailure = "No se pudieron guardar los perfiles en \(store.fileURL.path). "
                + "Los cambios siguen en pantalla, pero se perderán al cerrar la app: "
                + error.localizedDescription
        }
    }
}
