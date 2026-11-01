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
            // The one action the window exists for has to be reachable from every destination. Leaving
            // the switch only inside «Ajustes» would be a real regression: the first thing a newcomer
            // needs is exactly what the new structure would hide. Same control, same rule, in the bar.
            ToolbarItem(placement: .primaryAction) {
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
        }
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

            List(selection: $destination) {
                ForEach(ShellDestination.allCases, id: \.self) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }
            .listStyle(.sidebar)
        }
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
