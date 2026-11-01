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

    /// S4: what the user asked the inspector to do. It is remembered while the window is narrow even
    /// though the width overrules it, so narrowing and widening the window does not lose the answer.
    @State private var showsInspector = true

    /// The width the shell is drawn in, measured below. It starts at zero, so the first frame is the
    /// narrow case: opening the window must never show a column that the width has not allowed yet.
    @State private var shellWidth: CGFloat = 0

    /// S4: below this many points of window width the inspector stays folded, whatever the button
    /// says. The mapping is what the window is for, and at that width the three zones stop fitting
    /// one beside the other without taking the width the table needs to be read.
    /// The narrowest window that can hold the sidebar, the content and the inspector at once: about
    /// 240 for the sidebar, 620 for a mapping row that still fits, 300 for the inspector and the
    /// dividers. Below this the column could only exist by squeezing the table it is meant to serve.
    private static let inspectorMinimumWindowWidth: CGFloat = 1240

    /// The width of the inspector, taken from the prototype: a field label and a slider need a
    /// width to be read at, and a column that stretched with the window would move under the pointer.
    /// Wide enough for a slider row to show its label and its value at once: at 300 the two fought
    /// and the label lost its last word («Velocidad de desplazamien»), which is how a measurement, not
    /// a guess, set this number.
    private static let inspectorWidth: CGFloat = 340

    /// S5: the two edits that ask before they act live with the menu that starts them, because the
    /// menu is what opens them. They stay window state and not section state: the section no longer
    /// has a picker or the four buttons, so it would have nothing to ask about.
    @State private var isRenaming = false
    /// Deleting takes the whole profile with it — mappings, layer, sensitivity — and nothing brings it
    /// back, so it asks first: the menu item sits one click away from the profile list.
    @State private var isConfirmingDelete = false
    @State private var draftName = ""

    /// S2: whether this Mac has been shown the guide. It is a preference and not window state: it has
    /// to survive the launch that first showed it, or every launch would be a first one.
    @AppStorage("hasSeenFirstRunGuide") private var hasSeenFirstRunGuide = false
    /// The sheet is driven by this, so the Settings button and the first launch open the same thing
    /// instead of two sheets that could both be asked for at once.
    @State private var showsGuide = false

    var body: some View {
        NavigationSplitView {
            sidebar
                // S4: the content rules. The sidebar stays plastic and narrow, because every point it
                // keeps for itself is a point the mapping does not have at the 780 minimum width.
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            detailArea
        }
        .navigationSplitViewStyle(.balanced)
        // S4: the collapse rule reads the width from here, because this is the one view that sees the
        // whole window. It measures in a background, which takes no part in layout, so the number
        // cannot change because of the column it decides — a reader inside the detail area would
        // shrink itself the moment the inspector took its space from the same column.
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        shellWidth = proxy.size.width
                        // A window restored narrower than the threshold opens with the column folded,
                        // which is the state a fresh reader needs: the mapping, not the settings.
                        showsInspector = proxy.size.width >= Self.inspectorMinimumWindowWidth
                    }
                    .onChange(of: proxy.size.width) { width in
                        // One way only, on the crossing: forcing the column open on a small window is
                        // a decision the user is allowed to keep.
                        if shellWidth >= Self.inspectorMinimumWindowWidth,
                           width < Self.inspectorMinimumWindowWidth {
                            showsInspector = false
                        }
                        shellWidth = width
                    }
            }
        }
        .toolbar {
            // S5: the profile actions stay next to the action the window exists for, in the bar and
            // not in the content column, so they are reachable from every destination without the
            // mapping table giving up a row for them.
            ToolbarItem(placement: .primaryAction) {
                profileMenu
            }
            ToolbarItem(placement: .primaryAction) {
                if emulation.hasAccessibility {
                    emulationButton
                } else {
                    // A disabled button with no reason is a dead end, and the reason lives in another
                    // destination. This one says the reason and takes the reader where it is fixed.
                    Button {
                        destination = .settings
                    } label: {
                        Label(
                            AppText.resolve("Accessibility permission missing"),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        // The bar would otherwise draw the icon alone, and an orange triangle without
                        // words is a hint, not a reason.
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.orange)
                    }
                    .help(AppText.resolve("Accessibility permission missing"))
                }
            }
            if destination == .mapping {
                // No column, no button: a toggle that opens nothing is a promise the window breaks.
                ToolbarItem(placement: .primaryAction) {
                    inspectorButton
                }
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
                profiles.edit { $0.renameSelectedProfile(to: draftName) }
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
                profiles.edit { $0.deleteSelectedProfile() }
            }
            Button(AppText.resolve("Cancel"), role: .cancel) {}
        } message: {
            // The name is data, inserted through the hole: the sentence is one key, so a translator
            // can move the name where their grammar needs it.
            Text(
                AppText.format(
                    "“%@” and everything it holds — its mappings, the MOD layer and its sensitivity — will be deleted. This cannot be undone.",
                    profiles.library.selectedProfile?.name ?? ""
                )
            )
        }
        // S2: the guide appears once, and the flag that hides it is written on every way out of the
        // sheet — the button, Escape and the click outside — because otherwise closing it with the
        // wrong key would make the next launch a first one again.
        .sheet(isPresented: $showsGuide) {
            FirstRunView(
                profiles: profiles,
                isPadConnected: service.state.isConnected
            ) {
                showsGuide = false
            }
        }
        .onChange(of: showsGuide) { presented in
            if !presented { hasSeenFirstRunGuide = true }
        }
        .onAppear {
            if !hasSeenFirstRunGuide { showsGuide = true }
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

    /// S4: the one way to the third zone, and its title says what the press does in the window the
    /// user has.
    ///
    /// Below the threshold the column stays folded: the press writes the choice, which the window
    /// obeys as soon as it is wide enough again, so pressing it here loses nothing and inventing a
    /// disabled button would only ask the user to guess why.
    private var inspectorButton: some View {
        Button(isInspectorVisible ? AppText.resolve("Hide inspector") : AppText.resolve("Show inspector")) {
            // The choice and not the state: pressing it while the window is too narrow still has to
            // mean “I want it open”, or a change of width would silently undo the user's answer.
            showsInspector = !isInspectorVisible
        }
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
                profiles.edit { $0.addProfile() }
            }
            Button(AppText.resolve("Duplicate")) {
                profiles.edit { $0.duplicateSelectedProfile() }
            }
            .disabled(profiles.library.selectedProfile == nil)
            Button(AppText.resolve("Rename…")) {
                draftName = profiles.library.selectedProfile?.name ?? ""
                isRenaming = true
            }
            .disabled(profiles.library.selectedProfile == nil)
            Button(AppText.resolve("Delete")) {
                isConfirmingDelete = true
            }
            .disabled(!profiles.library.canDeleteProfile)
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
    /// and the profile the pad will run are one concept and never a pair. If the emulation is running,
    /// the press also swaps the mapping — through the engine's atomic switch, the same one the pad's
    /// profile step uses — so the window is not more restricted than the pad it configures.
    private var profileRows: some View {
        ForEach(profiles.library.profiles) { stored in
            let isActive = stored.id == profiles.library.selectedProfile?.id
            Button {
                profiles.edit { $0.selectProfile(id: stored.id) }
                // A no-op while the emulation is stopped, so one call covers both states.
                if let profile = profiles.library.selectedProfile?.profile {
                    emulation.switchToProfile(profile)
                }
            } label: {
                ProfileRow(profile: stored, isActive: isActive)
            }
            .buttonStyle(.plain)
            // The dot carries the colour, and colour alone must not be the information: the label
            // spells the colour in words, and the active row also says it as a selection.
            .accessibilityLabel(AppText.format("%@ — %@", stored.name, stored.profile.color.label))
            .accessibilityAddTraits(isActive ? [.isSelected] : [])
        }
    }

    /// S1, S4: the content column and, beside it, the inspector.
    ///
    /// A trailing column of the detail area and not `NavigationSplitView`'s `.inspector`: that API
    /// arrived in macOS 14 and this package builds for macOS 13, and a column of our own keeps the
    /// collapse rule in the shell — the one view that can see the window — instead of dividing it
    /// between the split view and a modifier that only knows its own column.
    private var detailArea: some View {
        HStack(spacing: 0) {
            detail
            // The inspector is the profile's, and only the mapping destination is about that profile:
            // showing it beside the packet dump would offer settings next to a screen that cannot use
            // them, and pay for the width twice.
            if isInspectorVisible, destination == .mapping {
                Divider()
                InspectorView(profiles: profiles)
                    .frame(width: Self.inspectorWidth)
            }
        }
    }

    /// S4: the user's choice, with one automatic exception — the column folds by itself when the
    /// window narrows past what it can hold. It is not hidden *because* the window is narrow: the
    /// toolbar button brings it back, because a rule that made the settings unreachable on a small
    /// screen would trade a layout problem for a functional one.
    private var isInspectorVisible: Bool {
        showsInspector
    }

    /// Every destination scrolls its own column: the window has to be usable at its minimum size, where
    /// the sections are taller than the window, and scrolling keeps the window from clipping them.
    private var detail: some View {
        ScrollView {
            destinationContent
                .padding(20)
                // No width is demanded here. A column that asks for a width makes the whole window
                // overflow when the inspector is forced open on a small screen, and overflow is not a
                // layout: it is content clipped at the edge, sidebar included. The rows wrap, so the
                // column is free to give way; how wide the window opens is the scene's business.
                .frame(maxWidth: .infinity, alignment: .leading)
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

    /// The mapping is what the window is for, so the device list stays beside it rather than becoming
    /// a destination of its own: it describes the pad being mapped, and this slice does not decide
    /// where it belongs for good.
    private var mappingDestination: some View {
        VStack(alignment: .leading, spacing: 18) {
            DeviceListSection(devices: service.devices)
            ProfileSection(profiles: profiles, feed: service.feed)
        }
    }

    /// S7: the technical material lives here from now on, out of the daily view.
    /// S7: everything technical, and an explanation of why it is here, so the area does not read as a
    /// leftover of the interface but as the place to come when something does not work.
    private var diagnosticsDestination: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(
                AppText.resolve(
                    "What the pad sends, for when something does not work. Nothing here is needed to use it."
                )
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            diagnosticsPermissionHint
            if service.state.isConnected {
                // Their own view, so a report rebuilds only this subtree and not the whole column.
                LiveReportSections(feed: service.feed)
            }
            LegendSection(devices: service.devices)
        }
    }

    /// The technical half of the permission problem lives here, not in the everyday view: the command
    /// resets a system entry, and reading it is a troubleshooting step, not a setting.
    @ViewBuilder
    private var diagnosticsPermissionHint: some View {
        if !emulation.hasAccessibility {
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle(AppText.resolve("Accessibility, for when it refuses to work"))
                Text(
                    AppText.resolve(
                        "If the app already appears as enabled in that list and the indicator is still orange, "
                        + "the entry is stale: select it, remove it with the − button and add it again, or run "
                        + "tccutil reset Accessibility dev.nacon.diagnostics and request the permission again."
                    )
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .textSelection(.enabled)
            }
        }
    }

    private var settingsDestination: some View {
        VStack(alignment: .leading, spacing: 18) {
            EmulationSection(emulation: emulation)
            LanguageSection()
            guideSection
        }
    }

    /// The guide is readable a second time, as the guide itself promises: it explains, and what it
    /// explains is worth finding again without reinstalling anything.
    private var guideSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(AppText.resolve("Guide"))
            Text(
                AppText.resolve(
                    "The first-run guide explains the four steps and the two ideas behind the mapping."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Button(AppText.resolve("Show the guide again")) { showsGuide = true }
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
