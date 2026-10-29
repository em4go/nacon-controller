import NaconCore
import SwiftUI

struct EmulationSection: View {
    @ObservedObject var emulation: EmulationController
    @EnvironmentObject private var service: ControllerService
    /// S2: the vertical-axis setting belongs to the profile being edited, like the mapping does.
    @EnvironmentObject private var profiles: ProfileLibraryController

    /// The pad light state owned by this section.
    @State private var padLight = PadLight()
    /// S10: the rumble strength. Runtime state like the light, not a profile setting: it is feedback,
    /// not mapping, so it is not written to disk.
    @State private var padRumble = PadRumble()
    /// S10: whether starting and stopping the emulation should be felt.
    @State private var rumbleFeedback = false
    /// Runs the bursts, so the view owns no timing of its own.
    @State private var burstPlayer = RumbleBurstPlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(AppText.resolve("Mouse and keyboard emulation"))
            permissionRow
            if !emulation.hasAccessibility {
                staleEntryHint
            }
            Toggle(AppText.resolve("Emulation active"), isOn: Binding(
                get: { emulation.isEnabled },
                set: { emulation.setEnabled($0) }
            ))
            .toggleStyle(.switch)
            .disabled(!emulation.hasAccessibility)
            lightControls
            rumbleControls
            // S2: the switch shows the value stored in the selected profile, not a leftover global
            // flag, and flipping it edits that profile so two profiles can differ.
            Toggle(AppText.resolve("Invert vertical axis"), isOn: Binding(
                get: { profiles.selectedInvertVerticalAxis },
                set: { profiles.setInvertVerticalAxis($0) }
            ))
            .toggleStyle(.switch)
            // The value only reaches the engine when emulation starts, so flipping it mid-run would
            // silently do nothing. Disabled while running, like the mapping editor.
            .disabled(emulation.isEnabled)
            Text(
                AppText.resolve(
                    "Turn it on if pushing the stick up moves the cursor down. It affects the cursor and "
                    + "scrolling, not the on-screen stick indicator. It is saved in the active profile and "
                    + "applied when emulation starts: stop it to change the setting."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(
                AppText.resolve(
                    "The left stick moves the cursor and the right stick scrolls. ✕/○/□ are the mouse "
                    + "buttons and the D-pad sends arrow keys. The PS button turns emulation on and off "
                    + "instantly."
                )
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            if emulation.stoppedByPad {
                Text(AppText.resolve("Emulation stopped from the pad."))
                    .font(.callout.bold())
                    .foregroundStyle(.orange)
            }
            if emulation.startedByPad {
                Text(AppText.resolve("Emulation started from the pad."))
                    .font(.callout.bold())
                    .foregroundStyle(.green)
            }
        }
        .onAppear {
            padLight.isEmulationActive = emulation.isEnabled
        }
        .onChange(of: emulation.isEnabled) { isEnabled in
            padLight.isEmulationActive = isEnabled
            guard rumbleFeedback else { return }
            burstPlayer.fire(padRumble) { service.sendOutput($0) }
        }
        .onDisappear {
            // A burst must not outlive the section that started it.
            burstPlayer.stop { service.sendOutput($0) }
        }
        .onChange(of: padLight.isOn) { _ in
            // S1/S2/S4: one send point, driven only by the state; a missing pad is harmless.
            service.sendOutput(padLight.packet)
        }
    }

    // MARK: - S3, S4: the pad light

    private var lightControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(AppText.resolve("Light as emulation indicator"), isOn: Binding(
                get: { padLight.source == .emulation },
                set: { padLight.source = $0 ? .emulation : .manual }
            ))
            .toggleStyle(.switch)
            Toggle(AppText.resolve("Light on"), isOn: $padLight.isManuallyOn)
                .toggleStyle(.switch)
                .disabled(padLight.source == .emulation)
            Text(
                AppText.resolve(
                    "With the indicator on, the small light under the PS button comes on while "
                    + "emulation is active and goes off when you stop it. Turn it off to switch the light "
                    + "on and off by hand."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - S10: the rumble

    private var rumbleControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(AppText.resolve("Rumble when emulation starts and stops"), isOn: $rumbleFeedback)
                .toggleStyle(.switch)
            HStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { padRumble.intensity },
                        set: { padRumble.intensity = $0 }
                    ),
                    in: 0...1
                )
                Text(
                    padRumble.isSilent
                        ? AppText.resolve("Off")
                        : "\(Int((padRumble.intensity * 100).rounded())) %"
                )
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
                Button(AppText.resolve("Test")) {
                    burstPlayer.fire(padRumble) { service.sendOutput($0) }
                }
                .disabled(padRumble.isSilent)
            }
            Text(
                AppText.resolve(
                    "A short burst confirms that the pad rumbles. With the feedback on, the same burst "
                    + "is felt when emulation starts and stops. The app sends the stop command when it "
                    + "finishes, but a forced quit can leave the motors spinning: set the intensity to "
                    + "zero before you force it closed."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var staleEntryHint: some View {
        Text(
            AppText.resolve(
                "If the app already appears as enabled in that list and the indicator is still orange, "
                + "the entry is stale: select it, remove it with the − button and add it again, or run "
                + "tccutil reset Accessibility dev.nacon.diagnostics and request the permission again."
            )
        )
        .font(.caption)
        .foregroundStyle(.orange)
    }

    private var permissionTitle: String {
        emulation.hasAccessibility
            ? AppText.resolve("Accessibility permission granted")
            : AppText.resolve("Accessibility permission missing")
    }

    private var permissionRow: some View {
        HStack(spacing: 10) {
            Image(systemName: emulation.hasAccessibility ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(emulation.hasAccessibility ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(permissionTitle)
                    .font(.callout.bold())
                if !emulation.hasAccessibility {
                    Text(
                        AppText.resolve(
                            "macOS drops the events without this permission. Grant it in System Settings "
                            + "› Privacy & Security › Accessibility, then return to this window."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !emulation.hasAccessibility {
                HStack(spacing: 8) {
                    Button(AppText.resolve("Check again")) {
                        emulation.refreshPermission()
                    }
                    Button(AppText.resolve("Request permission")) {
                        emulation.requestAccessibility()
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((emulation.hasAccessibility ? Color.green : Color.orange).opacity(0.1))
        )
    }
}
