import NaconCore
import SwiftUI

/// S2: the first run, from prototype 04, which the user asked for.
///
/// It is a sheet and not a window of its own: the reader has already opened the app, and a second
/// window would ask them to manage two. The steps show live state — whether the pad is here, whether
/// the permission is granted — because a guide that says «connect the pad» without saying whether the
/// pad is connected makes the reader check for themselves what the app already knows.
///
/// The permission step carries the button that requests it. Sending someone to Ajustes to explain
/// them a problem and letting them find the button there is the dead end this slice removes.
struct FirstRunView: View {
    @ObservedObject var profiles: ProfileLibraryController
    @EnvironmentObject private var emulation: EmulationController
    let isPadConnected: Bool
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    step(
                        1,
                        AppText.resolve("Connect the pad"),
                        AppText.resolve(
                            "Plug it in with the cable and turn it on. It appears on its own; there is "
                            + "nothing to install."
                        ),
                        state: isPadConnected
                            ? AppText.resolve("Pad detected")
                            : AppText.resolve("Pad not detected"),
                        stateIsGood: isPadConnected
                    )
                    step(
                        2,
                        AppText.resolve("Let it send clicks and keys"),
                        AppText.resolve(
                            "It is a macOS permission called Accessibility. Without it the pad moves the "
                            + "cursor, but clicks and keystrokes never leave this app."
                        ),
                        state: emulation.hasAccessibility
                            ? AppText.resolve("Permission granted")
                            : AppText.resolve("Permission missing"),
                        stateIsGood: emulation.hasAccessibility
                    ) {
                        if !emulation.hasAccessibility {
                            Button(AppText.resolve("Request permission")) {
                                emulation.requestAccessibility()
                            }
                        }
                    }
                    step(
                        3,
                        AppText.resolve("Turn the emulation on"),
                        AppText.resolve(
                            "The switch is in the toolbar, top right. While it is off the pad only shows "
                            + "what it reads; while it is on, it sends what the active profile says."
                        ),
                        state: emulation.isEnabled
                            ? AppText.resolve("Emulation active")
                            : AppText.resolve("Emulation stopped"),
                        stateIsGood: emulation.isEnabled
                    )
                    step(
                        4,
                        AppText.resolve("Check that it answers"),
                        AppText.resolve(
                            "In Mapping, press a button and its row lights up. MOD+PS opens the summary of "
                            + "what every button does and closes it again."
                        ),
                        state: AppText.resolve("Nothing to enable: it always answers, even stopped"),
                        stateIsGood: true
                    )
                    howItWorks
                    footerNote
                }
                .padding(24)
            }
            Divider()
            HStack {
                Spacer()
                Button(AppText.resolve("Start")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 640, height: 720)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppText.resolve("Four steps"))
                .font(.largeTitle.weight(.semibold))
            Text(AppText.resolve("You can leave this at any time, and reopen it from Settings."))
                .foregroundStyle(.secondary)
        }
    }

    /// One numbered step. The number is drawn rather than typed so a step cannot be skipped in the
    /// text while the count in the title still says four.
    private func step(
        _ number: Int,
        _ title: String,
        _ body: String,
        state: String,
        stateIsGood: Bool,
        @ViewBuilder action: () -> some View = { EmptyView() }
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(stateIsGood ? Color.accentColor : Color.secondary))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: stateIsGood ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(stateIsGood ? Color.green : Color.secondary)
                    Text(state)
                        .font(.callout)
                }
                action()
            }
        }
    }

    /// The two ideas the prototype ends with. Named «ideas» on purpose: the mapping table reads like a
    /// form, and nothing in a form says that the whole table changes when the profile changes.
    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppText.resolve("Two ideas and that is it"))
                .font(.headline)
            idea(
                "square.grid.2x2",
                AppText.resolve(
                    "A profile is what each button does. A «Mouse» profile turns the pad into a mouse; "
                    + "another can turn the same buttons into writing or shortcuts. Switching profile "
                    + "changes the whole table, not one row."
                )
            )
            idea(
                "light.max",
                AppText.resolve(
                    "The pad's light says which profile is active — blue, green, red or purple — so you "
                    + "know without opening the window."
                )
            )
            idea(
                "layers",
                AppText.resolve(
                    "One button, L2 by default, works as a second layer: while you hold it, the other "
                    + "buttons send what the MOD column says."
                )
            )
        }
    }

    private func idea(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 20)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerNote: some View {
        Text(
            AppText.resolve(
                "Nothing here changes what you configure: the guide only explains. You can reopen it "
                + "from Settings."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}
