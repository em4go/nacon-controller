import NaconCore
import SwiftUI

/// S1, S3, S4, S5, S6, S8: the mapping of the profile on screen, in the app window.
///
/// The section only renders state and forwards intents. Every rule (unique names, the standard
/// mapping for a new profile, refusing to delete the last profile, which neighbour to select, which
/// controls may be remapped) lives in `ProfileLibrary` and `MappingRules` and is covered by tests.
///
/// T2, S5: it no longer chooses or manages profiles. The list lives in the shell's sidebar and the
/// four actions in its toolbar menu, so this section starts at the profile that is already active.
///
/// T3, S4: it no longer holds the profile's settings either. The light colour, the next profile and
/// the MOD key moved to the inspector beside it, together with the cursor numbers; what stays here
/// is what belongs to the mapping itself — how it is read, the assignment editor, the PS row and the
/// footnotes that explain them.
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

    /// The one key capture of the section. Both views arm it, so whichever one is on screen has the
    /// same armed control, the same rules and the same event monitor -- and switching between them
    /// cannot leave two captures alive.
    @StateObject private var capture = MappingCapture()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(AppText.resolve("Mapping"))
            viewPicker
            if let selected = profiles.selectedProfile {
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
