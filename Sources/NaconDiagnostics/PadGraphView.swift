import AppKit
import NaconCore
import SwiftUI

/// S3: the graphical view of the profile being edited — the DualShock 4 drawing plus one badge per
/// control.
///
/// The view decides nothing. The positions come from `PadLayout`, the labels from `MappingRules`, the
/// pressed state from the report it receives and the lock from `isEmulationEnabled`; the caller hands
/// in the profile. Badges are informative only: the mapping is still changed in the table view, so
/// there is no click target here and nothing can be edited by accident on a drawing.
struct PadGraphView: View {
    /// The mapping the badges show.
    let profile: InputProfile
    /// Last report of the connected pad, or nil while there is no pad or no report yet.
    let report: XInputReport?
    /// Whether emulation runs. A mapping cannot change then, so the overlay is dimmed and inert.
    let isEmulationEnabled: Bool

    /// Badge metrics. The app's window allows roughly 620 points of drawing width, where fifteen
    /// badges of this size still keep their distance; a longer action is truncated and its full text
    /// stays reachable as a tooltip, which is better than two badges growing into each other.
    private static let badgeFontSize: CGFloat = 9
    private static let badgeMaxWidth: CGFloat = 78

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let artwork = Artwork.image {
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        Image(nsImage: artwork)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                        overlay(in: proxy.size)
                    }
                }
                // The drawing keeps its proportions, so badges stay on the controls they belong to
                // no matter how wide the window is.
                .aspectRatio(PadLayout.aspectRatio, contentMode: .fit)
            } else {
                unavailableArtwork
            }
            caption
        }
    }

    /// One badge per control, at the point `PadLayout` measured for it.
    ///
    /// `position` places the badge's centre, so every label sits on its own control instead of being
    /// pushed around by its neighbours.
    private func overlay(in size: CGSize) -> some View {
        let layout = PadLayout.standard
        return ZStack(alignment: .topLeading) {
            ForEach(XInputControl.allCases, id: \.self) { control in
                if let point = layout.point(for: control) {
                    let pressed = isPressed(control)
                    badge(for: control, isPressed: pressed)
                        // The pressed badge is drawn last so a highlight is never half covered.
                        .zIndex(pressed ? 1 : 0)
                        .position(
                            x: point.horizontal * size.width,
                            y: point.vertical * size.height
                        )
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        // While emulation runs the mappings are locked, so the whole overlay reads as inactive and
        // stops taking hover events; the tooltips would otherwise suggest something can be changed.
        .opacity(isEmulationEnabled ? 0.4 : 1)
        .allowsHitTesting(!isEmulationEnabled)
    }

    private func badge(for control: XInputControl, isPressed: Bool) -> some View {
        let label = badgeLabel(for: control)
        let shape = RoundedRectangle(cornerRadius: 4)
        return Text(label)
            .font(.system(size: Self.badgeFontSize, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(isPressed ? Color.white : Color.primary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(maxWidth: Self.badgeMaxWidth)
            .background(
                shape.fill(
                    isPressed
                        ? Color.accentColor
                        : Color(nsColor: .controlBackgroundColor).opacity(0.92)
                )
            )
            .overlay(
                shape.strokeBorder(
                    isPressed ? Color.accentColor : Color.secondary.opacity(0.35),
                    lineWidth: 1
                )
            )
            // The truncated label and the control it belongs to stay readable on hover.
            .help("\(MappingRules.controlLabel(for: control)): \(badgeExplanation(for: control))")
    }

    /// What the badge under a control says.
    ///
    /// Guide is reserved and never stored in the profile, so asking the profile would print «Sin
    /// asignar» on the one control that always does something.
    private func badgeLabel(for control: XInputControl) -> String {
        control == MappingRules.reservedControl
            ? "Activa/apaga"
            : MappingRules.label(for: profile.action(for: control))
    }

    /// The same answer, spelled out, for the tooltip.
    private func badgeExplanation(for control: XInputControl) -> String {
        control == MappingRules.reservedControl
            ? "activa y apaga la emulación, y no se puede reasignar"
            : MappingRules.label(for: profile.action(for: control))
    }

    /// Whether the control is down in the report.
    ///
    /// Only while emulation is stopped: with emulation running the mappings are locked, and a moving
    /// highlight would suggest a control can be picked.
    private func isPressed(_ control: XInputControl) -> Bool {
        guard !isEmulationEnabled, let report else { return false }
        return control.isPressed(in: report)
    }

    private var caption: some View {
        Text(
            isEmulationEnabled
                ? "La emulación está activa, así que el mapeo está bloqueado: la gráfica solo muestra "
                    + "el estado de los controles."
                : "Cada etiqueta es la asignación actual del perfil. Para cambiarla, usa la vista «Tabla»."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var unavailableArtwork: some View {
        Text("No se ha podido cargar el dibujo del mando.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 180)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.06)))
    }
}

/// The drawing, read once from the target's resource bundle.
///
/// A nil image means the bundle is missing or the PNG cannot be read — a hand-made `.app` that forgot
/// `scripts/build-app.sh`, for instance — which is reported in words instead of an empty rectangle.
/// Load failures are not retryable at runtime, so caching the result costs nothing.
@MainActor
private enum Artwork {
    static let image: NSImage? = {
        guard let url = Bundle.module.url(forResource: "PS4_Controller", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()
}
