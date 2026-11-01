import Combine
import NaconCore

/// S11: the pad's light and rumble, owned by the app instead of by a screen.
///
/// They lived in `EmulationSection`, and that was fine while the section was always drawn. When the
/// window gained destinations the section started existing only while «Ajustes» was on screen, and the
/// light stopped following the emulation: nothing was mounted to send the packet. Ownership moves
/// here, where the lifetime is the app's, and the section becomes one more reader of the value.
final class PadLightStore: ObservableObject {
    @Published var light = PadLight()
    @Published var rumble = PadRumble()
    @Published var rumbleFeedback = false

    /// Runs the bursts. It lives with the state so a change of destination no longer cancels one.
    let burstPlayer = RumbleBurstPlayer()
}
