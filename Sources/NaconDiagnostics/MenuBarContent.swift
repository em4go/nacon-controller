import AppKit
import NaconCore
import SwiftUI

/// What the menu bar item offers: the state at a glance, the switch, the profile, the window, the exit.
///
/// It is not a second controls panel. Every row here calls the same thing the window calls, because a
/// menu that decides on its own would drift from the window the first time one of them changed.
struct MenuBarContent: View {
    @ObservedObject var service: ControllerService
    @ObservedObject var emulation: EmulationController
    @ObservedObject var profiles: ProfileLibraryController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Resolved through the seam, not handed to SwiftUI: a resource given to `Text` would follow the
        // process language and ignore the one chosen in the window (R13).
        Text(Localization.resolve(service.state.title))
            .font(.caption)
            .foregroundStyle(.secondary)

        Divider()

        Button(emulation.isEnabled ? AppText.resolve("Turn emulation off") : AppText.resolve("Turn emulation on")) {
            emulation.setEnabled(!emulation.isEnabled)
        }
        .disabled(!service.state.isConnected)

        Menu(AppText.format("Profile: %@", profiles.selectedProfile?.name ?? "—")) {
            ForEach(profiles.profiles) { profile in
                Button(profile.name) {
                    profiles.select(profile.id)
                }
            }
        }
        .disabled(emulation.isEnabled)

        Divider()

        Button(AppText.resolve("Show mapping")) {
            emulation.toggleSummary()
        }

        Button(AppText.resolve("Open window")) {
            openWindow(id: WindowID.main)
            NSApp.activate(ignoringOtherApps: true)
        }

        Button(AppText.resolve("Quit")) {
            NSApplication.shared.terminate(nil)
        }
    }
}

enum WindowID {
    static let main = "main"
}
