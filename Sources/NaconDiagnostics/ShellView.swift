import NaconCore
import SwiftUI

/// S1, S3, S6: the three zones of the main window — navigate, work, adjust.
///
/// The first slice only moves what was already in the window: same controls, same rules, same strings,
/// in a different place. Navigation goes to the sidebar, so the content column can hold one destination
/// at a time instead of the single long column that made the emulation switch fall off screen.
struct ShellView: View {
    @EnvironmentObject private var service: ControllerService
    @EnvironmentObject private var emulation: EmulationController
    @EnvironmentObject private var profiles: ProfileLibraryController

    /// Window state, not a stored preference: the window opens on the mapping, where it opens today,
    /// and a launch never resumes somewhere the user did not choose.
    @State private var destination: ShellDestination = .mapping

    /// S5: the two edits that ask before they act live with the menu that starts them, because the
    /// menu is what opens them. They stay window state and not section state: the section no longer
    /// has a picker or the four buttons, so it would have nothing to ask about.
    @State private var isRenaming = false
    /// Deleting takes the whole profile with it — mappings, layer, sensitivity — and nothing brings it
    /// back, so it asks first: the menu item sits one click away from the profile list.
    @State private var isConfirmingDelete = false
    @State private var draftName = ""

    var body: some View {
        NavigationSplitView {
            sidebar
                // S4: the content rules. The sidebar stays plastic and narrow, because every point it
                // keeps for itself is a point the mapping does not have at the 780 minimum width.
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            // S5: the profile actions stay next to the action the window exists for, in the bar and
            // not in the content column, so they are reachable from every destination without the
            // mapping table giving up a row for them.
            ToolbarItem(placement: .primaryAction) {
                profileMenu
            }
            ToolbarItem(placement: .primaryAction) {
                emulationButton
            }
        }
        // T2: the same questions, with the same text, the same buttons and the same destructive role,
        // now asked by the menu that replaced the buttons. They are attached here because the alert
        // takes the state of the view that presents it, and this is the view that owns the menu.
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
        // shadow each other, so the destructive question keeps the shape it already had.
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

    /// The one action the window exists for has to be reachable from every destination. Leaving the
    /// switch only inside «Ajustes» would be a real regression: the first thing a newcomer needs is
    /// exactly what the new structure would hide. Same control, same rule, in the bar.
    private var emulationButton: some View {
        Button(emulation.isEnabled ? AppText.resolve("Stop emulation") : AppText.resolve("Start emulation")) {
            emulation.setEnabled(!emulation.isEnabled)
        }
        .disabled(!emulation.hasAccessibility)
        .help(
            emulation.hasAccessibility
                ? AppText.resolve("Starts or stops sending what the pad does to the system.")
                : AppText.resolve("Accessibility permission missing")
        )
    }

    /// S5, S6: the four profile actions, collected in one menu beside the emulation switch.
    ///
    /// Every rule the four buttons had is the one it keeps. Delete is out when the library refuses to
    /// leave the window with zero profiles, and rename and duplicate need a profile on screen. None of
    /// them was disabled while emulation runs — a profile is only read when emulation starts — so none
    /// of them is now.
    private var profileMenu: some View {
        Menu {
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
        } label: {
            // The icon alone: the bar already carries the action the window exists for, and the menu
            // is an errand about the library, not a second primary action shouting beside it.
            Label(AppText.resolve("Profiles"), systemImage: "person.crop.rectangle.stack")
        }
        .labelStyle(.iconOnly)
        .menuIndicator(.visible)
        .accessibilityLabel(AppText.resolve("Profiles"))
    }

    /// The state of the pad sits above the navigation, not inside a destination: "is the controller
    /// there?" is a question asked from anywhere in the window, and the answer has to be visible from
    /// anywhere too.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                StatusBanner(state: service.state)
                if emulation.padSilent {
                    PadSilenceBanner()
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            // One list, two sections: destinations and profiles scroll together, so the sidebar never
            // ends up with a scrolling half and a fixed half at the window's minimum height.
            List(selection: $destination) {
                ForEach(ShellDestination.allCases, id: \.self) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
                Section {
                    profileRows
                } header: {
                    Text(AppText.resolve("Profiles"))
                }
            }
            .listStyle(.sidebar)
        }
    }

    /// S5, S6: every stored profile, with the colour its light shows and a mark of which one is active.
    ///
    /// Pressing a row is the whole gesture: the library writes the selection, so the profile on screen
    /// and the profile the pad will run are one concept and never a pair. While emulation runs the
    /// rows do nothing, exactly as S5 asks: the profile is captured when emulation starts.
    private var profileRows: some View {
        ForEach(profiles.profiles) { stored in
            let isActive = stored.id == profiles.selectedProfile?.id
            Button {
                profiles.select(stored.id)
            } label: {
                ProfileRow(profile: stored, isActive: isActive)
            }
            .buttonStyle(.plain)
            // The dot carries the colour, and colour alone must not be the information: the label
            // spells the colour in words, and the active row also says it as a selection.
            .accessibilityLabel(AppText.format("%@ — %@", stored.name, stored.profile.color.label))
            .accessibilityAddTraits(isActive ? [.isSelected] : [])
        }
        .disabled(emulation.isEnabled)
    }

    /// Every destination scrolls its own column: the window has to be usable at its minimum size, where
    /// the sections are taller than the window, and scrolling keeps the window from clipping them.
    private var detail: some View {
        ScrollView {
            destinationContent
                .padding(20)
                // The mapping is a table of control, action and two buttons per row. It needs a width
                // before it starts truncating labels, and a split view that opens narrower than that
                // trades the reader's comprehension for a sidebar nobody asked to keep visible.
                .frame(minWidth: 620, idealWidth: 940, maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch destination {
        case .mapping: mappingDestination
        case .diagnostics: diagnosticsDestination
        case .settings: settingsDestination
        }
    }

    /// The mapping is what the window is for, so the device list and the per-profile sensitivity stay
    /// beside it rather than becoming destinations of their own: both describe the profile being
    /// mapped, and this slice does not decide where they belong for good.
    private var mappingDestination: some View {
        VStack(alignment: .leading, spacing: 18) {
            DeviceListSection(devices: service.devices)
            ProfileSection(profiles: profiles, feed: service.feed)
            SensitivitySection(profiles: profiles)
        }
    }

    /// S7: the technical material lives here from now on, out of the daily view.
    private var diagnosticsDestination: some View {
        VStack(alignment: .leading, spacing: 18) {
            if service.state.isConnected {
                // Their own view, so a report rebuilds only this subtree and not the whole column.
                LiveReportSections(feed: service.feed)
            }
            LegendSection(devices: service.devices)
        }
    }

    private var settingsDestination: some View {
        VStack(alignment: .leading, spacing: 18) {
            EmulationSection(emulation: emulation)
            LanguageSection()
        }
    }
}

/// One profile of the sidebar: its colour, its name, and whether it is the one running.
///
/// It only draws. What a press means belongs to the library, so this view cannot invent a selection
/// the rest of the window would not agree with.
private struct ProfileRow: View {
    let profile: StoredProfile
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            // The same mark the pad's light shows, so the row and the hardware say the same thing.
            Circle()
                .fill(profile.profile.color.tint)
                .frame(width: 9, height: 9)
            Text(profile.name)
                .fontWeight(isActive ? .semibold : .regular)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            // A mark and not only the colour: which profile runs must not depend on telling blue from
            // purple, or on being able to see the dot at all.
            if isActive {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The whole row is the target, not just the letters: a sidebar row is one click, wherever the
        // pointer lands inside it.
        .contentShape(Rectangle())
    }
}

/// One destination of the sidebar.
///
/// Each destination names itself, so the sidebar reads as navigation and not as a list of sections.
private enum ShellDestination: CaseIterable, Hashable {
    case mapping
    case diagnostics
    case settings

    var title: String {
        switch self {
        case .mapping: return AppText.resolve("Mapping")
        case .diagnostics: return AppText.resolve("Diagnostics")
        case .settings: return AppText.resolve("Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .mapping: return "gamecontroller"
        case .diagnostics: return "waveform.path.ecg"
        case .settings: return "gearshape"
        }
    }
}
