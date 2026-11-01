import NaconCore
import SwiftUI

/// S11: keeps the pad's light in step with the emulation, wherever the window happens to be.
///
/// This modifier is attached to the root view, which exists for as long as the app does, and it is the
/// only place that sends the LED packet. Attaching it to a screen is what broke the light once: a
/// screen can be unmounted, and an unmounted screen sends nothing.
struct PadLightBridge: ViewModifier {
    @EnvironmentObject private var service: ControllerService
    @EnvironmentObject private var emulation: EmulationController
    @EnvironmentObject private var profiles: ProfileLibraryController
    @EnvironmentObject private var store: PadLightStore

    func body(content: Content) -> some View {
        content
            .onAppear {
                // State only, no packet: launching must not touch a light someone set by hand.
                store.light.sync(colour: profiles.selectedColor, isEmulationActive: emulation.isEnabled)
            }
            // One send point, driven by the packet itself: the light's state is the whole decision, and
            // repeating a packet is harmless, so nothing here needs to compare states by hand.
            .onChange(of: store.light.packet) { _ in
                service.sendOutput(store.light.packet)
            }
            .onChange(of: emulation.isEnabled) { isEnabled in
                store.light.sync(colour: profiles.selectedColor, isEmulationActive: isEnabled)
                guard store.rumbleFeedback else { return }
                store.burstPlayer.fire(store.rumble) { service.sendOutput($0) }
            }
            .onChange(of: profiles.selectedColor) { colour in
                // The colour reaches the pad even mid-run: a light that lagged would name the wrong profile.
                store.light.sync(colour: colour, isEmulationActive: emulation.isEnabled)
            }
    }
}
