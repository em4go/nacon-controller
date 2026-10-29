import AppKit
import NaconCore
import SwiftUI

@main
struct NaconDiagnosticsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var service = ControllerService()
    @StateObject private var emulation = EmulationController()
    @StateObject private var profiles = ProfileLibraryController()
    /// Read here as well as in the section that changes it, because the root view is rebuilt from it.
    @AppStorage(LanguagePreference.defaultsKey) private var storedLanguage = AppLanguage.system.rawValue

    init() {
        // Before the first view is drawn: every string is resolved while drawing, so the preference has
        // to be in place before there is anything to draw.
        Localization.language = LanguagePreference.load()
    }

    var body: some Scene {
        WindowGroup("NACON Diagnostics") {
            ContentView()
                .environmentObject(service)
                .environmentObject(emulation)
                .environmentObject(profiles)
                .frame(minWidth: 780, minHeight: 780)
                .onAppear {
                    appDelegate.service = service
                    service.start()
                    // Dev aid: opens the mapping summary without a pad, so its layout can be
                    // checked with a screenshot.
                    if CommandLine.arguments.contains("--show-summary") {
                        // A beat after appearing: the library loads its profiles in the same pass, and
                        // the summary must show the selected one, not the fallback.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            emulation.toggleSummaryFromPad()
                        }
                    }
                    // S1, S8: the engine runs the profile the library has selected.
                    emulation.attach(to: service, profiles: profiles)
                }
                // A language change rebuilds the window: the strings were resolved while it was drawn,
                // and SwiftUI has no way to know that a value outside its state changed underneath.
                .id(storedLanguage)
                .onChange(of: storedLanguage) { raw in
                    Localization.language = AppLanguage(rawValue: raw) ?? .system
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
    /// Set by the app once the service exists, so a quit can order the pad to go dark.
    weak var service: ControllerService?
    private var didFlush = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// S13: quitting must leave the pad dark, including Cmd+Q.
    ///
    /// `willTerminate` arrives too late: the process is gone before the asynchronous write reaches the
    /// endpoint, which is why the light used to stay on. Here the quit is held, the two "off" packets
    /// are flushed, and only then does the app exit. `terminateLater` keeps the app responsive while
    /// that happens, and `didFlush` stops a second quit request from starting a second flush.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let service, !didFlush else { return .terminateNow }
        didFlush = true
        DispatchQueue.global(qos: .userInitiated).async {
            service.sendOutputAndWait(PadLight.offPacket, timeout: 0.3)
            service.sendOutputAndWait(PadRumble.stopPacket, timeout: 0.3)
            DispatchQueue.main.async {
                sender.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }
}
