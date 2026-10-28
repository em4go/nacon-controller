import AppKit
import NaconCore
import SwiftUI

/// The floating panel that shows what every control does, called up with MOD+PS.
///
/// It is a non-activating panel on purpose: like Spotlight, it must answer without stealing the
/// focus or the clicks, because it is read while the user is working in another application. It
/// ignores the mouse entirely, so it cannot be dragged or dismissed with a click — MOD+PS or
/// stopping the emulation close it.
@MainActor
final class MappingSummaryWindow {
    /// The visible panel, if any. Toggling replaces it, so a profile change while open is fine.
    private var panel: NSPanel?
    private var autoHide: Timer?

    /// What the panel shows: the profile by name, and its mapping.
    struct Content {
        let title: String
        let profile: InputProfile
    }

    func toggle(with content: Content) {
        if panel?.isVisible == true {
            hide()
            return
        }
        show(content)
    }

    func hide() {
        autoHide?.invalidate()
        autoHide = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func show(_ content: Content) {
        hide()

        let content = MappingSummaryView(name: content.title, profile: content.profile)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 10),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let hosting = NSHostingView(rootView: content.fixedSize())
        panel.contentView = hosting
        panel.contentView?.setFrameSize(hosting.fittingSize)
        panel.center()
        panel.orderFrontRegardless()
        self.panel = panel

        // A summary read at a glance must not need a matching gesture to go away. Long enough to
        // read two columns, short enough that forgetting it is harmless.
        autoHide = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.hide() }
        }
    }
}

/// The contents of the summary: the controls with an assignment, and what they send in each column.
private struct MappingSummaryView: View {
    let name: String
    let profile: InputProfile

    /// One control as the summary reads it: what it sends, and what it sends with the layer open.
    ///
    /// `mod` is optional on purpose: a control with no entry in the layer keeps its base action, so
    /// the column shows a dash — the same rule the table uses.
    private struct Row: Identifiable {
        let control: XInputControl
        let base: String
        let mod: String?
        var id: XInputControl { control }
    }

    private var rows: [Row] {
        MappingRules.remappableControls.compactMap { control in
            let base = profile.action(for: control)
            // Unassigned controls are absent: a summary is read at a glance, and empty rows are noise.
            guard base != .none else { return nil }
            let mod = profile.layer.action(for: control)
            return Row(
                control: control,
                base: MappingRules.label(for: base),
                mod: mod.map(MappingRules.label(for:))
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name.isEmpty ? "Perfil" : name)
                .font(.headline)
            Text("Resumen de mapeos")
                .font(.caption)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16) {
                GridRow {
                    Text("Control").font(.caption.weight(.semibold))
                    Text("Base").font(.caption.weight(.semibold))
                    if profile.layer.isActive {
                        Text("MOD").font(.caption.weight(.semibold))
                    }
                }
                ForEach(rows) { row in
                    GridRow {
                        Text(MappingRules.controlLabel(for: row.control))
                            .font(.callout.weight(.medium))
                        Text(row.base)
                            .font(.system(.callout, design: .monospaced))
                        if profile.layer.isActive {
                            Text(row.mod ?? "—")
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(row.mod == nil ? Color.secondary : Color.primary)
                        }
                    }
                }
            }

            Text("PS: encender o apagar · MOD + PS: este resumen")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
