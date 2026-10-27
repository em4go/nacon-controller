import AppKit
import NaconCore
import SwiftUI

@main
struct NaconDiagnosticsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var service = ControllerService()
    @StateObject private var emulation = EmulationController()

    var body: some Scene {
        WindowGroup("NACON Diagnostics") {
            ContentView()
                .environmentObject(service)
                .environmentObject(emulation)
                .frame(minWidth: 780, minHeight: 780)
                .onAppear {
                    service.start()
                    emulation.attach(to: service)
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
