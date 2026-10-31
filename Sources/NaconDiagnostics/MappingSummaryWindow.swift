import AppKit
import NaconCore
import SwiftUI

/// The floating panel that shows what every control does, called up with MOD+PS.
///
/// It is a non-activating panel on purpose: like Spotlight, it must answer without stealing the
/// focus or the clicks, because it is read while the user is working in another application. It
/// ignores the mouse entirely, so it cannot be dragged. It stays up until the user closes it — Escape, a
/// click anywhere, the same gesture again, or stopping the emulation — because a panel that hides itself
/// is exactly wrong for someone who has to look down at the pad and back up.
@MainActor
final class MappingSummaryWindow {
    /// The visible panel, if any. Toggling replaces it, so a profile change while open is fine.
    private var panel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

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
        removeClosingMonitors()
        panel?.orderOut(nil)
        panel = nil
    }

    /// Esc, or a click anywhere else, closes the summary.
    ///
    /// Two monitors, because neither alone is enough: a global monitor reports only events delivered to
    /// **other** applications, and a local one only events delivered to ours. When this app is in front,
    /// Escape reaches it as a normal key press and the global monitor never sees it — which is exactly
    /// what happened the first time this was tried: the panel ignored Escape. Together they cover the
    /// case of the user who is still in this window and the one who has moved on to another app.
    ///
    /// Only Escape closes a key press; every other key is left alone, and the local monitor returns it
    /// untouched. The keyboard half of the global monitor needs the Accessibility permission the
    /// emulation already uses; without it the panel still closes with MOD+PS, on its own, or when the
    /// emulation stops.
    private func installClosingMonitors() {
        removeClosingMonitors()
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents.union(.keyDown)) {
            [weak self] event in
            if event.type == .keyDown, event.keyCode != 53 { return }
            DispatchQueue.main.async { self?.hide() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents.union(.keyDown)) {
            [weak self] event in
            if event.type == .keyDown {
                guard event.keyCode == 53 else { return event }
                self?.hide()
                return nil
            }
            self?.hide()
            return event
        }
    }

    private func removeClosingMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
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

        installClosingMonitors()
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
            // Every remappable control appears. Omitting the empty ones turned the panel into a list of
            // what exists instead of a map of the pad, and a control that is missing reads as broken.
            let base = profile.action(for: control)
            let mod = profile.layer.action(for: control)
            return Row(control: control, base: base.displayName, mod: mod.map(\.displayName))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? AppText.resolve("Profile") : name)
                    .font(.title2.weight(.semibold))
                Text(AppText.resolve("Mapping summary"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text(AppText.resolve("Control"))
                    Text(AppText.resolve("Base"))
                    if profile.layer.isActive {
                        Text(verbatim: "MOD")
                    }
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)

                ForEach(rows) { row in
                    GridRow {
                        Text(Localization.resolve(ControlFacts.of(row.control).label))
                            .font(.body.weight(.medium))
                        Text(row.base)
                            .font(.system(.title3, design: .monospaced))
                        if profile.layer.isActive {
                            Text(row.mod ?? "—")
                                .font(.system(.title3, design: .monospaced))
                                .foregroundStyle(row.mod == nil ? Color.secondary : Color.primary)
                        }
                    }
                }
            }

            Text(AppText.resolve("PS: turn emulation on and off · MOD + PS: this summary · Esc or a click outside: close"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 760, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}
