import AppKit
import NaconCore
import SwiftUI

/// S3: the per-control mapping editor for the profile being edited.
///
/// The editor only renders state and forwards intents. Everything that decides what a press means
/// (which controls are remappable, whether arming is safe, what a captured key becomes, when a
/// capture ends, how an action reads) lives in `MappingRules` and `KeyCaptureSession`, and the write
/// itself is handed in by the caller so this view never touches persistence. Two safety rules shape
/// the layout:
///
/// - PS has no editor row at all, because it is the emulation switch and must stay reachable.
/// - The whole editor is disabled while emulation runs: swapping a mapping with a button held can
///   leave a key stuck down.
///
/// Each row carries the base and the MOD layer side by side (S3): the two layers are the same
/// controls read twice, so they belong on the same line instead of behind a mode switcher that would
/// hide half of what a control does.
struct MappingEditor: View {
    /// The mapping of the selected profile.
    let profile: InputProfile
    /// Identifier of the profile that mapping belongs to. A capture is bound to it, so a key press
    /// arriving after a profile switch cannot land on the newly selected profile.
    let profileID: UUID
    /// Whether emulation is running, which locks the editor.
    let isEmulationEnabled: Bool
    /// Applies one write to the profile on screen: a menu choice, a shortened command, or a capture
    /// the section has already resolved. The section turns it into a `MappingWrite` and lets the
    /// library apply it, so the profile guard is not duplicated here.
    let onWrite: (UUID, XInputControl, MappingColumn, MappedAction) -> Void
    /// The one capture of the section, shared with the graphical view. The section owns it so a
    /// capture armed in either view is the same session, with the same monitor and the same rules.
    @ObservedObject var capture: MappingCapture

    /// S3: the MOD column only exists when a key can open it.
    ///
    /// Without a key the layer can never apply, so a column of assignments the user could set and
    /// never reach would be a trap. The note below the table says how to get the column instead.
    private var showsLayer: Bool {
        profile.layer.isActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Mapeo de controles")
            Text(
                "Pulsa «Capturar» y después la combinación que quieras asignar, con los modificadores "
                + "que necesites (⌘, ⌥, ⌃, ⇧). Escape cancela la captura y deja el mapeo anterior."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            if isEmulationEnabled {
                lockedCaption
            }
            VStack(alignment: .leading, spacing: 6) {
                if showsLayer {
                    columnHeader
                }
                ForEach(MappingRules.remappableControls, id: \.self) { control in
                    MappingRow(
                        control: control,
                        action: profile.action(for: control),
                        // Only asked when the column exists: an entry of a closed layer is inert, and
                        // the row would be showing what can never happen.
                        layerAction: showsLayer ? profile.layer.action(for: control) : nil,
                        showsLayer: showsLayer,
                        // The row asks the capture itself which cell is waiting and keeps the two
                        // verbs apart: its buttons cancel, its menu entries only arm.
                        capture: capture,
                        profileID: profileID,
                        isEmulationRunning: isEmulationEnabled,
                        onWrite: { column, action in onWrite(profileID, control, column, action) }
                    )
                }
                reservedRow
            }
            .disabled(isEmulationEnabled)
            if !showsLayer {
                Text(
                    "Para tener una segunda capa, elige una tecla MOD arriba, en «Tecla MOD:». Con ella "
                        + "pulsada, cada botón envía lo que diga la columna MOD y, si no has cambiado "
                        + "nada, lo mismo que en la base."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Text(
                "El botón PS no se puede reasignar: es el interruptor que activa y desactiva la "
                + "emulación sin tocar el ratón ni el teclado, así que debe seguir siempre a mano."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .onDisappear {
            // Leaving the table (a switch to «Gráfica», a profile change) removes this view, so the
            // pending press and its monitor must go with it: the section installs the write, and a
            // capture must never land on a control the user is no longer looking at.
            capture.end()
        }
    }

    /// S3: one header line for the whole table, naming the two columns once instead of on every row.
    ///
    /// «Base» starts exactly where the base value starts, because both lines begin with the same empty
    /// control-name column. «MOD» sits at the trailing end, above the MOD column it names.
    private var columnHeader: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 96, height: 1)
            Text("Base")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("MOD")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
    }

    private var lockedCaption: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.orange)
            Text(
                "La emulación está activa, así que el mapeo está bloqueado. Detén la emulación para "
                + "cambiarlo: cambiar una asignación con un botón pulsado puede dejar una tecla "
                + "atascada."
            )
            .font(.caption)
            .foregroundStyle(.orange)
        }
    }

    private var reservedRow: some View {
        HStack(spacing: 10) {
            Text(MappingRules.controlLabel(for: MappingRules.reservedControl))
                .font(.callout.weight(.medium))
                .frame(width: 96, alignment: .leading)
            Label("Reservado: activa y desactiva la emulación al instante", systemImage: "power")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }
}

/// One remappable control: its two readings, the capture button and the fixed alternatives.
///
/// The base half is the editor it has always been; the MOD half only appears when the profile has a
/// key that opens the layer (S3), and it mirrors the base so the same control is read left to right
/// instead of in two places.
private struct MappingRow: View {
    let control: XInputControl
    let action: MappedAction
    /// The layer's own assignment, or `nil` when the layer has no entry for this control — which is
    /// not the same as an entry that sends nothing (S2).
    let layerAction: MappedAction?
    /// Whether the MOD half of the row exists at all.
    let showsLayer: Bool
    /// The one capture of the section. The row asks it which cell is waiting and arms or cancels it,
    /// so it needs no flag of its own.
    let capture: MappingCapture
    /// Profile the row's controls belong to; a capture is armed for it, never for another.
    let profileID: UUID
    /// Whether emulation is running, which refuses the arming.
    let isEmulationRunning: Bool
    /// Writes one action into one column of this control.
    let onWrite: (MappingColumn, MappedAction) -> Void

    /// Whether the base cell is the one waiting for a key. Only one control and one column at a time
    /// can be armed, so the other cell keeps its normal label: two buttons reading «Cancelar» would
    /// say both are armed.
    private var isWaitingInBase: Bool {
        capture.isCapturing(control, in: .base)
    }

    /// Whether the MOD cell is the one waiting for a key.
    private var isWaitingInMod: Bool {
        capture.isCapturing(control, in: .mod)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(MappingRules.controlLabel(for: control))
                .font(.callout.weight(.medium))
                .frame(width: 96, alignment: .leading)
            Text(isWaitingInBase ? "Pulsa una tecla…" : MappingRules.label(for: action))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(isWaitingInBase ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(isWaitingInBase ? "Cancelar" : "Capturar") {
                capture.toggle(
                    control,
                    for: profileID,
                    intent: .base,
                    isEmulationRunning: isEmulationRunning
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Menu {
                alternatives
            } label: {
                Label("Elegir…", systemImage: "chevron.up.chevron.down")
                    .labelStyle(.titleAndIcon)
            }
            .menuStyle(.borderlessButton)
            .controlSize(.small)
            .fixedSize()
            if showsLayer {
                layerCell
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isWaitingInBase || isWaitingInMod
                        ? Color.accentColor.opacity(0.12)
                        : Color.secondary.opacity(0.06)
                )
        )
    }

    /// The MOD reading of the control: the layer's assignment, or a dash that says «the base wins».
    ///
    /// The dash is secondary, not empty, because a control with no entry in the layer still does
    /// something with MOD held: it does what the base says (S2).
    private var layerCell: some View {
        HStack(spacing: 10) {
            Text(isWaitingInMod ? "Pulsa una tecla…" : layerAction.map(MappingRules.label(for:)) ?? "—")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(layerAction == nil || isWaitingInMod ? Color.secondary : Color.primary)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)
                .help(layerHelp)
            // The same button the base column has, because the columns are the same thing read twice.
            // Without it the only way into the layer was a menu entry, which is not how the base
            // column teaches the gesture.
            Button(isWaitingInMod ? "Cancelar" : "Capturar") {
                capture.toggle(
                    control,
                    for: profileID,
                    intent: .mod,
                    isEmulationRunning: isEmulationRunning
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            // The same list as the base, aimed at the column: a capture armed here writes into the
            // layer because that is the intent the arming menu declares, not a property of capture.
            Menu {
                AssignMenuItems(
                    onCapture: { arm(.mod) },
                    onChoose: { onWrite(.mod, $0) },
                    current: layerAction ?? .none,
                    onAppendStep: { arm(.modCommand) },
                    onDropLastStep: {
                        onWrite(.mod, MappingRules.droppingLastStep(from: layerAction ?? .none))
                    }
                )
            } label: {
                Label("Elegir…", systemImage: "chevron.up.chevron.down")
                    .labelStyle(.titleAndIcon)
            }
            .menuStyle(.borderlessButton)
            .controlSize(.small)
            .fixedSize()
            .help("Elige qué envía este control con la tecla MOD pulsada")
        }
    }

    private var layerHelp: String {
        guard let layerAction else {
            return "Con la tecla MOD usa la acción de la base"
        }
        return "Con la tecla MOD pulsada envía «\(MappingRules.label(for: layerAction))»"
    }

    /// What the capture button cannot express: mouse buttons, scrolling, the system catalog, the
    /// modifier holds and clearing the mapping. Shared with the drawing, so the two views cannot
    /// offer different destinations for the same control.
    private var alternatives: some View {
        AssignMenuItems(
            onCapture: { arm(.base) },
            onChoose: { onWrite(.base, $0) },
            current: action,
            onAppendStep: { arm(.baseCommand) },
            // Shortening a command is an ordinary write, so it goes through the same path a menu
            // choice takes and the profile is saved once, the same way.
            onDropLastStep: { onWrite(.base, MappingRules.droppingLastStep(from: action)) }
        )
    }

    /// Arms a capture from a menu entry. The entries name a destination, never a cancel, so this goes
    /// through `arm`: a pick while a capture is armed re-arms it instead of ending it.
    private func arm(_ intent: CaptureIntent) {
        capture.arm(
            control,
            for: profileID,
            intent: intent,
            isEmulationRunning: isEmulationRunning
        )
    }
}

/// Owns the key-capture session so the event monitor exists only while a capture is armed.
///
/// The decisions are not here: `KeyCaptureSession` decides whether arming is safe, what a press
/// becomes, when the capture ends and which profile the mapping belongs to. This object is the
/// AppKit translation layer -- it installs the monitor, reads the key code and modifiers, and hands
/// the outcome to the view -- plus the observable wrapper SwiftUI needs to redraw the rows.
///
/// One instance belongs to `ProfileSection`, which hands it to the table and to the graphical view:
/// both arms are therefore the same session, and a capture started in one view follows the same rules
/// as the other.
///
/// A local monitor is used on purpose: it sees the press before the rest of the app and can swallow
/// it, so the captured shortcut never reaches a text field or a menu. Normal typing is untouched
/// because nothing is installed outside a capture, and `end()` always removes the monitor, whether
/// the capture succeeds, is cancelled with Escape, emulation starts, or the view disappears.
@MainActor
final class MappingCapture: ObservableObject {
    /// The armed capture. Mutating it publishes, so the rows follow the state machine.
    @Published private(set) var session = KeyCaptureSession()

    /// Called once per finished capture with the outcome, which carries the profile the capture was
    /// armed for.
    var onFinish: ((KeyCaptureSession.Outcome) -> Void)?

    private var monitor: Any?

    func isCapturing(_ candidate: XInputControl) -> Bool {
        session.isArmed(candidate)
    }

    /// S2: whether the capture is waiting for a key in one particular column.
    ///
    /// The armed control and the intent both have to match, so arming the same control from the other
    /// column lights the other cell and leaves this one reading its normal label.
    func isCapturing(_ candidate: XInputControl, in column: MappingColumn) -> Bool {
        guard session.isArmed(candidate) else { return false }
        return (session.intent ?? .base).column == column
    }

    /// Arms a control for one profile with the destination the button declared, or disarms it when it
    /// is already the one being captured. This is what the two capture buttons and the drawing tap do,
    /// so cancelling stays reachable: the button says «Cancelar» as soon as its control is armed.
    /// The refusal while emulation runs is a result, so the caller never has to guess.
    func toggle(
        _ candidate: XInputControl,
        for profileID: UUID,
        intent: CaptureIntent = .base,
        isEmulationRunning: Bool
    ) {
        follow(
            session.toggle(
                candidate,
                for: profileID,
                intent: intent,
                isEmulationRunning: isEmulationRunning
            )
        )
    }

    /// Arms a control with one destination and never cancels, which is what a menu entry does:
    /// choosing a destination is not a request to cancel the capture in flight, so a pick while one is
    /// armed re-arms it instead of ending it.
    func arm(
        _ candidate: XInputControl,
        for profileID: UUID,
        intent: CaptureIntent = .base,
        isEmulationRunning: Bool
    ) {
        follow(
            session.arm(
                candidate,
                for: profileID,
                intent: intent,
                isEmulationRunning: isEmulationRunning
            )
        )
    }

    /// Keeps the monitor alive exactly while a capture is armed, whichever call got there.
    private func follow(_ result: KeyCaptureSession.ArmResult) {
        switch result {
        case .armed:
            installMonitor()
        case .disarmed, .refusedWhileEmulating:
            removeMonitor()
        }
    }

    /// Removes the monitor and forgets the armed control and profile. Safe to call at any time.
    func end() {
        session.disarm()
        removeMonitor()
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            // Only sendable values cross into the isolated block; the event itself is main-thread
            // only and must not be captured there.
            let keyCode = event.keyCode
            let modifiers = ModifierSet(event.modifierFlags)
            let consumed = MainActor.assumeIsolated {
                self.handle(keyCode: keyCode, modifiers: modifiers)
            }
            // Swallowing the press keeps the shortcut out of the rest of the app.
            return consumed ? nil : event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handle(keyCode: UInt16, modifiers: ModifierSet) -> Bool {
        let outcome = session.handleKey(keyCode: keyCode, modifiers: modifiers)
        guard outcome != .ignored else { return false }
        // A finished capture always disarms, so the monitor goes away with it. The destination has
        // already travelled out inside the outcome, so nothing about it is left to clear here.
        removeMonitor()
        onFinish?(outcome)
        return true
    }
}

extension ModifierSet {
    /// The modifiers held in an `NSEvent`, ignoring caps lock, fn and the device-dependent bits.
    init(_ flags: NSEvent.ModifierFlags) {
        var modifiers: ModifierSet = []
        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        self = modifiers
    }
}
