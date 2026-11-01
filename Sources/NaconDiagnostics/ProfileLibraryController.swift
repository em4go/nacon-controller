import Combine
import Foundation
import NaconCore

/// Owns the saved profile library and the file it lives in.
///
/// Every mutation writes the library straight away (S6): there is no save button and no unsaved
/// state. A failed write is reported as a message instead of crashing, because an unwritable disk
/// must not take the pad down with it. Reading and the fallback rules stay in `ProfileLibrary` and
/// `ProfileStore`; this type only sequences "change, then save".
///
/// It publishes the library itself and forwards nothing: a getter per setting would restate an
/// interface that already exists one layer down, and every one of them would be a place for the
/// two to disagree. The window reads `library`, and writes through `edit`.
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

    /// The one write seam: every change the window makes to the library arrives here.
    ///
    /// The order is the whole reason this type exists. The change runs first, on a copy, so a writer
    /// cannot leave a half-edited library behind and every rule stays in `ProfileLibrary`. A library
    /// that comes out unchanged is dropped next: no publication, no write to disk and no failure
    /// sentence for a save that was never needed. What survives is normalized before it is
    /// published, so nothing on screen can show a selection that does not resolve. Publication comes
    /// before the save because the change the user asked for stays visible even when the disk refuses
    /// it, and the save is the last step: its failure becomes one sentence beside the change instead
    /// of replacing it, so an unwritable file never takes the pad down with it.
    func edit(_ change: (inout ProfileLibrary) -> Void) {
        var updated = library
        change(&updated)
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
