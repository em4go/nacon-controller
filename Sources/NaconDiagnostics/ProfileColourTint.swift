import NaconCore
import SwiftUI

/// The profile colour, as the window paints it.
///
/// The core owns the colour: the value, its name and the LED pattern it means. It knows nothing about
/// SwiftUI, because the menu bar, the store and the self-test all read the same value without ever
/// drawing it. This is the only place that turns it into something the window can show, so the dot in
/// the sidebar and any later swatch cannot disagree about what «azul» looks like.
extension ProfileColour {
    /// The tint used wherever a profile has to be recognised by its colour.
    ///
    /// The system colours and not fixed values: they are the ones the rest of the window already uses
    /// for state, and they stay legible when the system switches between the light and dark appearance.
    var tint: Color {
        switch self {
        case .blue: return .blue
        case .red: return .red
        case .green: return .green
        case .purple: return .purple
        }
    }
}
