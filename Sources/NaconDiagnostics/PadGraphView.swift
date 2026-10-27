import AppKit
import NaconCore
import SwiftUI

/// S3: the graphical view of the profile being edited — the DualShock 4 drawing, used as the control
/// panel itself.
///
/// Nothing is drawn on top of the artwork: no badge, no rectangle with text. The drawing already
/// prints the ✕ ○ □ △ glyphs and the PS logo, so the view lights up the pixels the artwork itself
/// paints for a control, by tinting it through one alpha mask per control. The pointer finds each
/// control through an invisible circle centred on the point `PadLayout` measured for it, and one strip
/// below the drawing says which control is under the pointer and what it currently sends.
///
/// The view decides no rule. The positions come from `PadLayout`, the labels from `MappingRules`, the
/// pressed state from the report it receives and the lock from `isEmulationEnabled`; the caller hands
/// in the profile, the identifier of that profile and the capture that owns the key session. Tapping a
/// control arms the capture for it, exactly like pressing «Capturar» in the table: it is the same
/// `MappingCapture` and therefore the same `KeyCaptureSession`, so both views share one armed control,
/// one set of rules and one event monitor.
struct PadGraphView: View {
    /// The mapping the strip shows.
    let profile: InputProfile
    /// Identifier of the profile on screen. A capture is armed for it, so a key press arriving after
    /// a profile switch cannot land on the profile the user has just selected.
    let profileID: UUID
    /// Last report of the connected pad, or nil while there is no pad or no report yet.
    let report: XInputReport?
    /// Whether emulation runs. A mapping cannot change then, so the interactive layer is dimmed and
    /// inert.
    let isEmulationEnabled: Bool
    /// The one capture of the section. Armed by a tap here, by «Capturar» in the table, or by neither.
    @ObservedObject var capture: MappingCapture
    /// Writes an assignment the capture cannot express: mouse buttons, scrolling, clearing and the
    /// ready-made macOS shortcuts. The section applies the same profile guard it applies to a capture.
    let onAssign: (XInputControl, MappedAction) -> Void

    /// The control under the pointer, cleared when it leaves. Hovering only previews a control: it
    /// never arms anything, so moving the mouse across the drawing is safe.
    @State private var hovered: XInputControl?
    /// The control the last tap picked. It keeps its highlight and its line in the strip while the
    /// pointer is elsewhere, which is what makes the strip readable without chasing the mouse.
    @State private var selected: XInputControl?

    /// The drawing is an editor, not a poster: it keeps `PadLayout.aspectRatio` but stops growing, so
    /// the view picker, the strip and the profile list stay on screen instead of scrolling past a
    /// wall of artwork. Below this width it shrinks with the window and is never cropped.
    private static let maxDrawingWidth: CGFloat = 520

    /// How strongly a control is tinted: under the pointer, waiting for a key, or down on the pad.
    ///
    /// One strength for all three, because the difference between them is when they end, not how they
    /// look: hovering stops when the pointer leaves, waiting stops when a key lands or Escape cancels,
    /// and a press stops when the button comes back up. Distinguishing them by opacity made hovering
    /// look like a stuck capture. The masks are the artwork's own strokes, so a strong accent still
    /// reads through the line work instead of hiding the button underneath.
    private static let highlightOpacity: Double = 0.6

    /// How much of the interactive layer survives while emulation runs. The drawing itself stays at
    /// full contrast: what is locked is the editing, not the picture.
    private static let lockedOpacity: Double = 0.4

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
            panel
                .frame(maxWidth: Self.maxDrawingWidth)
                .frame(maxWidth: .infinity, alignment: .center)
            if Masks.isIncomplete {
                // One note for the whole drawing: the picture is still useful without the tint, and
                // seventeen copies of the same sentence would not be.
                Text(
                    "No se han podido cargar todas las máscaras de resaltado: el dibujo se ve, pero "
                        + "algún control no se ilumina al pasar el ratón."
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: Self.maxDrawingWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            hint
        }
        .onChange(of: isEmulationEnabled) { isRunning in
            // The interactive layer stops answering while emulation runs, so a hover that was live
            // when it started would otherwise stay in the strip forever.
            if isRunning {
                hovered = nil
            }
        }
        .onChange(of: capture.session.isArmed) { armed in
            // A capture that ended, whether a key landed or Escape cancelled it, must leave the
            // drawing as it found it: the tint means «waiting for a key», not «last one touched».
            if !armed {
                selected = nil
            }
        }
    }

    /// The artwork with its highlights and its hit areas on top, keeping its proportions at whatever
    /// width it is given.
    private func drawing(_ artwork: NSImage) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                ZStack(alignment: .topLeading) {
                    highlights(in: proxy.size)
                    hitLayer(in: proxy.size)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                // While emulation runs the mappings are locked, so the layer that can change them
                // reads as inactive and stops taking hover events; the artwork itself keeps its
                // contrast.
                .opacity(isEmulationEnabled ? Self.lockedOpacity : 1)
                .allowsHitTesting(!isEmulationEnabled)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        // The drawing keeps its proportions, so a mask stays on the button it was cut from no matter
        // how wide the window is.
        .aspectRatio(PadLayout.aspectRatio, contentMode: .fit)
    }

    /// One tinted layer per highlighted control, masked by that control's own alpha.
    ///
    /// The masks are full-canvas, like the artwork, so each one is laid over the same frame and the
    /// accent only shows through the strokes the drawing already paints for that button. A mask that
    /// cannot be loaded simply leaves its control untinted; the drawing still works.
    private func highlights(in size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(XInputControl.allCases, id: \.self) { control in
                if isHighlighted(control), let mask = Masks.image(for: control) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .opacity(Self.highlightOpacity)
                        .mask(
                            Image(nsImage: mask)
                                .resizable()
                                .interpolation(.high)
                        )
                        .frame(width: size.width, height: size.height)
                        // The highlight is paint, not a target: the hit areas below own the pointer.
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// The one hit area of the drawing: a transparent layer that turns a pointer position into the
    /// control it belongs to.
    ///
    /// Each control keeps the circle the prototype gives it — a radius in pixels of the 1452 x 940
    /// artwork, scaled with the frame — but the circles are resolved by distance instead of by
    /// stacking order. The shoulder caps and their trigger arcs are 17 pixels apart while both circles
    /// are 60 pixels in radius, so a plain stack would hand every hover in that corner to whichever
    /// control came last, and a tap on L1 would arm the capture for L2. Picking the nearest centre
    /// keeps the radii and makes every control reachable.
    private func hitLayer(in size: CGSize) -> some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: size.width, height: size.height)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hovered = control(at: location, in: size)
                case .ended:
                    hovered = nil
                }
            }
            .gesture(
                SpatialTapGesture().onEnded { value in
                    if let control = control(at: value.location, in: size) {
                        select(control)
                    }
                }
            )
    }

    /// The control whose circle contains `location`, choosing the nearest centre when several do.
    private func control(at location: CGPoint, in size: CGSize) -> XInputControl? {
        let layout = PadLayout.standard
        var closest: (control: XInputControl, distance: CGFloat)?
        for control in XInputControl.allCases {
            guard let point = layout.point(for: control) else { continue }
            let centerX = point.horizontal * size.width
            let centerY = point.vertical * size.height
            let radius = Self.hitRadius(for: control) / PadLayout.imageWidth * size.width
            let gapX = location.x - centerX
            let gapY = location.y - centerY
            let distance = (gapX * gapX + gapY * gapY).squareRoot()
            guard distance <= radius else { continue }
            if closest == nil || distance < closest!.distance {
                closest = (control, distance)
            }
        }
        return closest?.control
    }

    /// Radius of a control's hit circle, in pixels of the 1452 x 940 artwork.
    private static func hitRadius(for control: XInputControl) -> Double {
        switch control {
        case .buttonA, .buttonB, .buttonX, .buttonY: return 46
        case .dpadUp, .dpadDown, .dpadLeft, .dpadRight: return 42
        case .leftThumb, .rightThumb: return 62
        case .guide: return 40
        case .leftBumper, .rightBumper, .leftTrigger, .rightTrigger: return 60
        case .back, .start: return 34
        }
    }

    /// Picks a control and, unless it is the reserved one, arms the capture for it.
    ///
    /// Selection and arming are one gesture on purpose: a tap on the drawing is the same intent as
    /// pressing «Capturar» in the table for that row. PS is the exception — it is the emulation switch,
    /// so it can be inspected but never rebound.
    private func select(_ control: XInputControl) {
        selected = control
        guard MappingRules.isRemappable(control) else { return }
        capture.toggle(
            control,
            for: profileID,
            isEmulationRunning: isEmulationEnabled
        )
    }

    /// Whether this control is tinted right now: under the pointer, waiting for a key, or down.
    ///
    /// Picking a control does not tint by itself; it arms the capture, and the armed state is what
    /// lights it. When that capture ends — a key lands, Escape cancels — the light goes with it.
    private func isHighlighted(_ control: XInputControl) -> Bool {
        isArmed(control) || isPressed(control) || hovered == control
    }

    /// Whether this control is the one waiting for a key press.
    private func isArmed(_ control: XInputControl) -> Bool {
        capture.isCapturing(control)
    }

    /// Whether the control is down in the report.
    ///
    /// Only while emulation is stopped: with emulation running the mappings are locked, and a moving
    /// highlight would suggest a control can be picked.
    private func isPressed(_ control: XInputControl) -> Bool {
        guard !isEmulationEnabled, let report else { return false }
        return control.isPressed(in: report)
    }

    // MARK: - The strip under the drawing

    /// The control the strip talks about: the armed one while a capture waits for a key, and otherwise
    /// the hovered one, falling back to the last one picked.
    private var describedControl: XInputControl? {
        capture.session.armedControl ?? hovered ?? selected
    }

    /// Name and current assignment of one control, in one line under the drawing.
    ///
    /// The printed glyph on the artwork cannot follow a remapping, so this strip is where the mapping
    /// is read. It is not decoration: without it the drawing alone would lie about ✕ once the user
    /// assigns something else to it.
    private var panel: some View {
        let control = describedControl
        let isArmed = control.map(isArmed) ?? false
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(control.map(MappingRules.controlLabel(for:)) ?? "Sin seleccionar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(isArmed ? "Pulsa una tecla…" : assignment(for: control))
                .font(.callout.weight(.semibold))
                .foregroundStyle(isArmed ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            if let control, MappingRules.isRemappable(control), !isEmulationEnabled {
                Menu {
                    Button("Capturar tecla…") { select(control) }
                    Divider()
                    ForEach([MouseButton.left, .middle, .right], id: \.self) { button in
                        Button(MappingRules.label(for: .mouseButton(button))) {
                            assign(control, .mouseButton(button))
                        }
                    }
                    Divider()
                    Button(MappingRules.label(for: MappingRules.scrollUpAction)) {
                        assign(control, MappingRules.scrollUpAction)
                    }
                    Button(MappingRules.label(for: MappingRules.scrollDownAction)) {
                        assign(control, MappingRules.scrollDownAction)
                    }
                    Divider()
                    // The catalog from the table, so a system combination that macOS would swallow
                    // before any local monitor sees it can still be assigned here.
                    ForEach(SystemShortcut.Category.allCases, id: \.self) { category in
                        Menu(category.title) {
                            ForEach(SystemShortcut.inCategory(category)) { shortcut in
                                Button("\(shortcut.name) — \(shortcut.combo.glyph)") {
                                    assign(control, shortcut.action)
                                }
                            }
                        }
                    }
                    Divider()
                    Button(MappingRules.label(for: .none)) { assign(control, .none) }
                } label: {
                    Label("Asignar…", systemImage: "ellipsis.circle")
                        .labelStyle(.titleAndIcon)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 34)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .help(control.map { "\(MappingRules.controlLabel(for: $0)): \(assignment(for: $0))" } ?? "")
    }

    /// Writes one assignment and returns the drawing to its normal state.
    ///
    /// The selection exists to arm one thing; once it is done, keeping the control tinted would say
    /// «still waiting» when nothing is waiting.
    private func assign(_ control: XInputControl, _ action: MappedAction) {
        onAssign(control, action)
        selected = nil
        hovered = nil
    }

    /// What a control sends today, in the words the table uses.
    ///
    /// Guide is reserved and never stored in the profile, so asking the profile would print «Sin
    /// asignar» on the one control that always does something.
    private func assignment(for control: XInputControl?) -> String {
        guard let control else { return "—" }
        guard MappingRules.isRemappable(control) else {
            return "Reservado: activa y apaga la emulación"
        }
        return MappingRules.label(for: profile.action(for: control))
    }

    // MARK: - The line under the strip

    /// The hint under the drawing: the capture hint while a control waits for a key, the lock while
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
                "Pasa el ratón por un botón del dibujo: se ilumina su propia forma, y la franja de "
                    + "arriba dice qué envía. Pulsa para asignarle una tecla. El glifo impreso no "
                    + "cambia al reasignar, así que la asignación se lee en esa franja y en la vista "
                    + "«Tabla»."
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

/// The per-control alpha masks that decide which pixels of the drawing light up.
///
/// They are the artwork's own alpha restricted to one control, cut by `prototype/tools/make-masks.py`
/// and shipped flat in `Resources/masks`. A mask that will not load leaves its control untinted and
/// unreported one by one: `isIncomplete` is what turns that into the single note under the drawing.
@MainActor
private enum Masks {
    static let images: [XInputControl: NSImage] = {
        var loaded: [XInputControl: NSImage] = [:]
        for control in XInputControl.allCases {
            if let image = load(control) {
                loaded[control] = image
            }
        }
        return loaded
    }()

    /// Whether at least one mask is missing from the bundle.
    static var isIncomplete: Bool {
        images.count != XInputControl.allCases.count
    }

    static func image(for control: XInputControl) -> NSImage? {
        images[control]
    }

    /// `Bundle.module` is built by SwiftPM and then copied into the `.app` by `scripts/build-app.sh`,
    /// so the mask may sit at the bundle root or keep its folder depending on how it was processed.
    /// Both are tried; a miss is what the single note below the drawing reports.
    private static func load(_ control: XInputControl) -> NSImage? {
        let name = "diagram-\(fileName(for: control))"
        let url = Bundle.module.url(forResource: name, withExtension: "png")
            ?? Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "masks")
        guard let url else { return nil }
        return NSImage(contentsOf: url)
    }

    /// The name of the mask file, which is the control's case name: `diagram-buttonA.png` and
    /// `diagram-leftThumb.png` follow the prototype's naming so the two stay comparable.
    private static func fileName(for control: XInputControl) -> String {
        switch control {
        case .dpadUp: return "dpadUp"
        case .dpadDown: return "dpadDown"
        case .dpadLeft: return "dpadLeft"
        case .dpadRight: return "dpadRight"
        case .buttonA: return "buttonA"
        case .buttonB: return "buttonB"
        case .buttonX: return "buttonX"
        case .buttonY: return "buttonY"
        case .leftBumper: return "leftBumper"
        case .rightBumper: return "rightBumper"
        case .leftTrigger: return "leftTrigger"
        case .rightTrigger: return "rightTrigger"
        case .back: return "back"
        case .start: return "start"
        case .guide: return "guide"
        case .leftThumb: return "leftThumb"
        case .rightThumb: return "rightThumb"
        }
    }
}
