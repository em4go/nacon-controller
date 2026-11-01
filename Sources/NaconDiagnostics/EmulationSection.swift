import NaconCore
import SwiftUI

struct EmulationSection: View {
    @ObservedObject var emulation: EmulationController
    @EnvironmentObject private var service: ControllerService
    /// S2: the vertical-axis setting belongs to the profile being edited, like the mapping does.
    @EnvironmentObject private var profiles: ProfileLibraryController

    /// S11: the light and the rumble are the app's, not this section's. They used to be `@State` here,
    /// which worked only while this view was always on screen; when the window gained destinations the
    /// light stopped following the emulation, because nothing was mounted to send the packet. This
    /// section now edits a value it does not own.
    @EnvironmentObject private var padLightStore: PadLightStore

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
            // The vertical-axis inversion left this section for the inspector, with its control and its
            // explanation: a caption about a switch that is no longer here is worse than no caption.
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
    }

    // MARK: - S3, S4: the pad light

    private var lightControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(AppText.resolve("Light as emulation indicator"), isOn: Binding(
                get: { padLightStore.light.source == .emulation },
                set: { padLightStore.light.source = $0 ? .emulation : .manual }
            ))
            .toggleStyle(.switch)
            Toggle(AppText.resolve("Light on"), isOn: $padLightStore.light.isManuallyOn)
                .toggleStyle(.switch)
                .disabled(padLightStore.light.source == .emulation)
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
            Toggle(AppText.resolve("Rumble when emulation starts and stops"), isOn: $padLightStore.rumbleFeedback)
                .toggleStyle(.switch)
            HStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { padLightStore.rumble.intensity },
                        set: { padLightStore.rumble.intensity = $0 }
                    ),
                    in: 0...1
                )
                Text(
                    padLightStore.rumble.isSilent
                        ? AppText.resolve("Off")
                        : "\(Int((padLightStore.rumble.intensity * 100).rounded())) %"
                )
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
                Button(AppText.resolve("Test")) {
                    padLightStore.burstPlayer.fire(padLightStore.rumble) { service.sendOutput($0) }
                }
                .disabled(padLightStore.rumble.isSilent)
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

    /// The command itself moved to the diagnostics destination: reading a shell command is a
    /// troubleshooting step, and this section is what someone sees while trying to start the emulation.
    private var staleEntryHint: some View {
        Text(
            AppText.resolve(
                "The permission looks granted and nothing happens? The fix is under Diagnostics."
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
