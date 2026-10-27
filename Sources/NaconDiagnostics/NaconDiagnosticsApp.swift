import AppKit
import NaconCore
import SwiftUI

@main
struct NaconDiagnosticsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var service = ControllerService()
    @StateObject private var emulation = EmulationController()
    @StateObject private var profiles = ProfileLibraryController()

    var body: some Scene {
        WindowGroup("NACON Diagnostics") {
            ContentView()
                .environmentObject(service)
                .environmentObject(emulation)
                .environmentObject(profiles)
                .frame(minWidth: 780, minHeight: 780)
                .onAppear {
                    service.start()
                    // S1, S8: the engine runs the profile the library has selected.
                    emulation.attach(to: service, profiles: profiles)
                }
                .onDisappear {
                    emulation.shutdown()
                    service.stop()
                }
        }
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
