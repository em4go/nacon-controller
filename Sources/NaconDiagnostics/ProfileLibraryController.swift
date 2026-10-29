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

    /// S2: the vertical-axis setting belongs to the profile, so flipping the toggle edits the
    /// selected profile and saves it straight away like any other change.
    func setInvertVerticalAxis(_ newValue: Bool) {
        mutate { $0.setInvertVerticalAxis(newValue) }
    }

    // MARK: - MOD layer (S3, S4, S5)

    /// S5: the layer of the profile being edited, as the selector and both views read it.
    var selectedLayer: ProfileLayer { library.selectedLayer }

    /// S5: chooses the control that opens the layer, saving it like any other change. `nil` is
    /// «Ninguna», which closes the layer and keeps its entries.
    func setLayerKey(_ control: XInputControl?) {
        guard let id = library.selectedProfile?.id else { return }
        mutate { $0.setLayerKey(control, for: id) }
    }

    /// S2: applies the write a finished capture resolved to and saves it straight away.
    ///
    /// The resolve itself, the profile guard and the column decision all live in `NaconCore`, so the
    /// controller only sequences "change, then save" like every other edit.
    func apply(_ write: MappingWrite) {
        mutate { $0.apply(write) }
    }

    /// Drops the key and every entry of the layer, returning the profile to having no layer at all.
    func clearLayer() {
        guard let id = library.selectedProfile?.id else { return }
        mutate { $0.clearLayer(for: id) }
    }

    /// S3: the layer's own assignment for one control, or `nil` when it has none and uses the base.
    func layerValue(for control: XInputControl) -> MappedAction? {
        library.layerValue(for: control)
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
            saveFailure = AppText.format(
                "The profiles could not be saved to %@. The changes are still on screen, but they will be lost when the app closes: %@",
                store.fileURL.path,
                error.localizedDescription
            )
        }
    }
}
