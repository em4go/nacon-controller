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
        autoHide?.invalidate()
        autoHide = nil
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

        // A summary read at a glance must not need a matching gesture to go away. Long enough to
        // read two columns, short enough that forgetting it is harmless.
        autoHide = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.hide() }
        }
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
            let base = profile.action(for: control)
            // Unassigned controls are absent: a summary is read at a glance, and empty rows are noise.
            guard base != .none else { return nil }
            let mod = profile.layer.action(for: control)
            return Row(
                control: control,
                base: base.displayName,
                mod: mod.map(\.displayName)
            )
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
