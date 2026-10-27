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
/// - Guide has no editor row at all, because it is the emergency stop.
/// - The whole editor is disabled while emulation runs: swapping a mapping with a button held can
///   leave a key stuck down.
struct MappingEditor: View {
    /// The mapping of the selected profile.
    let profile: InputProfile
    /// Identifier of the profile that mapping belongs to. A capture is bound to it, so a key press
    /// arriving after a profile switch cannot land on the newly selected profile.
    let profileID: UUID
    /// Whether emulation is running, which locks the editor.
    let isEmulationEnabled: Bool
    /// Applies one mapping to the profile the capture was armed for. Supplied by the section, which
    /// drops the write when that profile is no longer the selected one.
    let setAction: (UUID, XInputControl, MappedAction) -> Void

    @StateObject private var capture = MappingCapture()

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
                ForEach(MappingRules.remappableControls, id: \.self) { control in
                    MappingRow(
                        control: control,
                        action: profile.action(for: control),
                        isCapturing: capture.isCapturing(control),
                        onCapture: {
                            capture.toggle(
                                control,
                                for: profileID,
                                isEmulationRunning: isEmulationEnabled
                            )
                        },
                        // A menu choice applies to the profile on screen, so it carries that id.
                        onChoose: { setAction(profileID, control, $0) }
                    )
                }
                reservedRow
            }
            .disabled(isEmulationEnabled)
            Text(
                "El botón Guide no se puede reasignar: es el freno de emergencia que detiene la "
                + "emulación sin tocar el ratón ni el teclado."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .onChange(of: isEmulationEnabled) { isRunning in
            // A capture started before emulation began would keep swallowing key presses.
            if isRunning {
                capture.end()
            }
        }
        .onDisappear {
            capture.end()
        }
        .onAppear {
            capture.onFinish = { outcome in
                guard case let .mapped(armedProfileID, control, action) = outcome else { return }
                setAction(armedProfileID, control, action)
            }
        }
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
            Label("Reservado: detiene la emulación al instante", systemImage: "stop.circle")
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

/// One remappable control: its current mapping, the capture button and the fixed alternatives.
private struct MappingRow: View {
    let control: XInputControl
    let action: MappedAction
    let isCapturing: Bool
    let onCapture: () -> Void
    let onChoose: (MappedAction) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(MappingRules.controlLabel(for: control))
                .font(.callout.weight(.medium))
                .frame(width: 96, alignment: .leading)
            Text(isCapturing ? "Pulsa una tecla…" : MappingRules.label(for: action))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(isCapturing ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(isCapturing ? "Cancelar" : "Capturar") {
                onCapture()
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
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCapturing ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
        )
    }

    /// What the capture button cannot express: mouse buttons, scroll and clearing the mapping.
    @ViewBuilder private var alternatives: some View {
        Button("Capturar pulsación…") {
            onCapture()
        }
        Divider()
        ForEach([MouseButton.left, .middle, .right], id: \.self) { button in
            Button(MappingRules.label(for: .mouseButton(button))) {
                onChoose(.mouseButton(button))
            }
        }
        Divider()
        Button(MappingRules.label(for: MappingRules.scrollUpAction)) {
            onChoose(MappingRules.scrollUpAction)
        }
        Button(MappingRules.label(for: MappingRules.scrollDownAction)) {
            onChoose(MappingRules.scrollDownAction)
        }
        Divider()
        // S11: macOS actions that are really keystrokes. Offering them here saves memorising a
        // combination, and the submenu says which ones depend on a setting in System Settings.
        ForEach(SystemShortcut.Category.allCases, id: \.self) { category in
            Menu(category.title) {
                ForEach(SystemShortcut.inCategory(category)) { shortcut in
                    Button("\(shortcut.name) — \(shortcut.combo.glyph)") {
                        onChoose(shortcut.action)
                    }
                }
            }
        }
        Divider()
        Button(MappingRules.label(for: .none)) {
            onChoose(.none)
        }
    }
}

/// Owns the key-capture session so the event monitor exists only while a capture is armed.
///
/// The decisions are not here: `KeyCaptureSession` decides whether arming is safe, what a press
/// becomes, when the capture ends and which profile the mapping belongs to. This object is the
/// AppKit translation layer -- it installs the monitor, reads the key code and modifiers, and hands
/// the outcome to the view -- plus the observable wrapper SwiftUI needs to redraw the rows.
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

    /// Arms a control for one profile, or disarms it when it is already the one being captured.
    /// The refusal while emulation runs is a result, so the caller never has to guess.
    func toggle(_ candidate: XInputControl, for profileID: UUID, isEmulationRunning: Bool) {
        switch session.toggle(candidate, for: profileID, isEmulationRunning: isEmulationRunning) {
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
        // A finished capture always disarms, so the monitor goes away with it.
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
