import AppKit
import NaconCore
import SwiftUI

/// S3: the graphical view of the profile being edited — the DualShock 4 drawing plus one badge per
/// control.
///
/// The view decides no rule. The positions come from `PadLayout`, the labels from `MappingRules`, the
/// pressed state from the report it receives and the lock from `isEmulationEnabled`; the caller hands
/// in the profile, the identifier of that profile and the capture that owns the key session. Tapping
/// a remappable badge arms the capture for it, exactly like pressing «Capturar» in the table: it is
/// the same `MappingCapture` and therefore the same `KeyCaptureSession`, so both views share one
/// armed control, one set of rules and one event monitor.
struct PadGraphView: View {
    /// The mapping the badges show.
    let profile: InputProfile
    /// Identifier of the profile on screen. A capture is armed for it, so a key press arriving after
    /// a profile switch cannot land on the profile the user has just selected.
    let profileID: UUID
    /// Last report of the connected pad, or nil while there is no pad or no report yet.
    let report: XInputReport?
    /// Whether emulation runs. A mapping cannot change then, so the overlay is dimmed and inert.
    let isEmulationEnabled: Bool
    /// The one capture of the section. Armed by a tap here, by «Capturar» in the table, or by neither.
    @ObservedObject var capture: MappingCapture

    /// The drawing is an editor, not a poster: it keeps `PadLayout.aspectRatio` but stops growing, so
    /// the view picker, the hints and the profile list stay on screen instead of scrolling past a
    /// wall of artwork. Below this width it shrinks with the window and is never cropped.
    private static let maxDrawingWidth: CGFloat = 520

    /// Badge metrics. At the 520 points the drawing is capped to, fifteen badges of this size still
    /// keep their distance; a longer action is truncated and its full text stays reachable as a
    /// tooltip, which is better than two badges growing into each other.
    private static let badgeFontSize: CGFloat = 8.5
    private static let badgeMaxWidth: CGFloat = 62

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let artwork = Artwork.image {
                // Centring has to happen outside the aspect-ratio box: the cap limits the drawing,
                // this frame takes the rest of the width so the section keeps its leading column.
                drawing(artwork)
                    .frame(maxWidth: Self.maxDrawingWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                unavailableArtwork
            }
            hint
        }
    }

    /// The artwork with the badges on top, keeping its proportions at whatever width it is given.
    private func drawing(_ artwork: NSImage) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                overlay(in: proxy.size)
            }
        }
        // The drawing keeps its proportions, so badges stay on the controls they belong to no matter
        // how wide the window is.
        .aspectRatio(PadLayout.aspectRatio, contentMode: .fit)
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
                        // The pressed and the armed badge are drawn last so a highlight or a capture
                        // ring is never half covered.
                        .zIndex(pressed || isArmed(control) ? 1 : 0)
                        .position(
                            x: point.horizontal * size.width,
                            y: point.vertical * size.height
                        )
                        // The shoulder and the trigger sit 17 points apart on the drawing, so the pair
                        // is pushed apart from their midpoint instead of overlapping.
                        .offset(y: Self.verticalOffset(for: control))
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
        let label = shortLabel(for: control)
        let isArmed = isArmed(control)
        let shape = RoundedRectangle(cornerRadius: 4)
        return Text(label)
            .font(.system(size: Self.badgeFontSize, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(badgeForeground(isPressed: isPressed, isArmed: isArmed))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(maxWidth: isArmed ? 104 : Self.badgeMaxWidth)
            .background(shape.fill(badgeFill(isPressed: isPressed, isArmed: isArmed)))
            .overlay(
                shape.strokeBorder(
                    // The armed badge is the one waiting for a key, so it carries the accent colour
                    // and twice the outline: a press is a filled badge, a capture is a ring.
                    isPressed || isArmed ? Color.accentColor : Color.secondary.opacity(0.35),
                    lineWidth: isArmed ? 2 : 1
                )
            )
            // The truncated label and the control it belongs to stay readable on hover.
            .help("\(MappingRules.controlLabel(for: control)): \(badgeExplanation(for: control))")
            // A tap arms the capture, through the same `toggle` the «Capturar» button uses: a second
            // tap on the armed badge cancels it. The overlay above already removes hit testing while
            // emulation runs, and PS is reserved, so this does nothing for it.
            .onTapGesture {
                guard MappingRules.isRemappable(control) else { return }
                capture.toggle(
                    control,
                    for: profileID,
                    isEmulationRunning: isEmulationEnabled
                )
            }
    }

    /// Whether this control is the one waiting for a key press.
    private func isArmed(_ control: XInputControl) -> Bool {
        capture.isCapturing(control)
    }

    private func badgeFill(isPressed: Bool, isArmed: Bool) -> Color {
        if isPressed {
            return .accentColor
        }
        return isArmed
            ? Color.accentColor.opacity(0.22)
            : Color(nsColor: .controlBackgroundColor).opacity(0.92)
    }

    private func badgeForeground(isPressed: Bool, isArmed: Bool) -> Color {
        if isPressed {
            return .white
        }
        return isArmed ? .accentColor : .primary
    }

    /// What the badge under a control says.
    ///
    /// Guide is reserved and never stored in the profile, so asking the profile would print «Sin
    /// asignar» on the one control that always does something. A badge waiting for a key says so in
    /// words rather than showing the assignment the next press is about to replace.
    /// What the badge shows.
    ///
    /// The drawing is 520 points wide, so the full label either truncates or covers the control next
    /// to it. The long form stays in the tooltip, which is where it can be read without stealing room.
    private func shortLabel(for control: XInputControl) -> String {
        // The armed badge is the only one that may grow: it is telling the user what to do next.
        if isArmed(control) { return "Pulsa una tecla…" }
        // Guide is reserved, and the row under the drawing already says what it does, so the badge
        // only has to say which button it is.
        guard control != MappingRules.reservedControl else { return "PS" }
        switch profile.action(for: control) {
        case .none: return "—"
        case .mouseButton(.left): return "Izq."
        case .mouseButton(.right): return "Der."
        case .mouseButton(.middle): return "Centro"
        case .scrollLines(let lines): return lines > 0 ? "Scroll ↑" : "Scroll ↓"
        case .key(let combo): return combo.displayName
        }
    }

    /// How far a badge is nudged from its measured point.
    private static func verticalOffset(for control: XInputControl) -> CGFloat {
        switch control {
        case .leftBumper, .rightBumper: return -9
        case .leftTrigger, .rightTrigger: return 9
        default: return 0
        }
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

    /// The line under the drawing: the capture hint while a badge waits for a key, the lock while
    /// emulation runs, and how to read the drawing otherwise.
    @ViewBuilder private var hint: some View {
        if isEmulationEnabled {
            Text(
                "La emulación está activa, así que el mapeo está bloqueado: la gráfica solo muestra "
                    + "el estado de los controles."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if let armed = capture.session.armedControl {
            Text("Pulsa una tecla… Esc cancela")
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
                .help(
                    "Se asignará la próxima pulsación a "
                        + MappingRules.controlLabel(for: armed) + "."
                )
        } else {
            Text(
                "Cada etiqueta es la asignación actual del perfil. Pulsa una para asignarle una "
                    + "tecla, o cámbiala en la vista «Tabla»."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
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
