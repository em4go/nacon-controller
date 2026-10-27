import AppKit
import NaconCore
import SwiftUI

@main
struct NaconDiagnosticsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var service = ControllerService()

    var body: some Scene {
        WindowGroup("NACON Diagnostics") {
            ContentView()
                .environmentObject(service)
                .frame(minWidth: 780, minHeight: 740)
                .onAppear { service.start() }
                .onDisappear { service.stop() }
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
