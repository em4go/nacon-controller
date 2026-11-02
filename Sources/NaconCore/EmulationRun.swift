import Combine
import Foundation

/// The emulation as one run: the engine plus the rules the window used to spell out around it.
///
/// The engine turns reports into events and knows nothing about permissions, profiles or the panel. The
/// rules that decide *when* it may act — a start needs the Accessibility permission, Guide toggles, the
/// pad going silent is not the user asking to stop, MOD+PS reads the map instead of toggling — used to be
/// eleven wires inside the window, a target with no tests, so the only way to check a change to them was
/// to drive a pad by hand.
///
/// They live here instead, as one run with one published status. The engine is injected rather than
/// created, so a test runs the same composition against a recording emitter and an injected clock, and
/// the four things the run needs to know about the rest of the app — the profile to run, its title, the
/// profile a step leads to, and whether the permission is granted — are injected as sources, so the
/// answer is read when the rule needs it instead of being copied in.
///
/// The queues the engine calls back on stay the engine's business: every callback it fires arrives
/// through `deliver` before it touches `status`, so the published value is only ever written on the queue
/// that owns the view. `deliver` is injected for the reason `ReportFeed` injects its scheduler: a test
/// runs the hop inline and asserts without waiting for a clock.
public final class EmulationRun: ObservableObject {
    /// Everything the window says about the run, as one value: a view cannot render the running flag of
    /// one moment beside the silence flag of another.
    public struct Status: Equatable, Sendable {
        public var isRunning = false
        /// The pad's own emergency stop: Guide while the emulation ran.
        public var stoppedByPad = false
        /// Guide started the run while it was stopped.
        public var startedByPad = false
        /// The pad stopped sending. Nothing was disabled: a hub stall is not the user asking to stop.
        public var padSilent = false

        public init(
            isRunning: Bool = false,
            stoppedByPad: Bool = false,
            startedByPad: Bool = false,
            padSilent: Bool = false
        ) {
            self.isRunning = isRunning
            self.stoppedByPad = stoppedByPad
            self.startedByPad = startedByPad
            self.padSilent = padSilent
        }
    }

    /// What the mapping summary must show: the Perfil in force and the title for it.
    ///
    /// The decision is made here, not in the panel: the title falls back to the standard one when nothing
    /// is selected, and the profile is the one that would run — so the panel only renders what it is
    /// given, and the fallback is a value a test can read.
    public struct Summary: Equatable, Sendable {
        public let title: String
        public let profile: InputProfile

        public init(title: String, profile: InputProfile) {
            self.title = title
            self.profile = profile
        }
    }

    @Published public private(set) var status = Status()

    /// The pad asked for the mapping summary (MOD+PS). One callback: the panel is the app's.
    ///
    /// Reading the map must never stop the pad, so this path bypasses the toggle entirely — the run only
    /// says it was asked, and whoever owns the panel decides what that means.
    public var onSummaryRequest: (() -> Void)?

    private let engine: EmulationEngine
    /// Takes a callback the engine fired on its own queue and runs it where the published state lives.
    private let deliver: (@escaping () -> Void) -> Void

    /// Supplies the mapping to run. A source rather than a value, because a start reads it: the profile
    /// in force is the one captured at start, and editing a mapping while the emulation runs therefore
    /// cannot disturb an in-flight press.
    private var profileSource: () -> InputProfile = { .standard }
    /// What the summary shows by name. A separate source because it wants the profile's display name too,
    /// which the engine does not carry; `nil` means nothing is selected.
    private var profileTitleSource: () -> String? = { nil }
    /// The profile a step from the pad leads to, or `nil` when the selection did not change.
    private var profileStepper: (ProfileStep) -> InputProfile? = { _ in nil }
    /// Whether this process may synthesize input. Asked when a start needs it: the app keeps the published
    /// copy for its own messages, but the decision is made against the system, not against a cache.
    private var hasAccessibilitySource: () -> Bool = { AccessibilityPermission.isGranted }

    public init(
        engine: EmulationEngine,
        deliver: @escaping (@escaping () -> Void) -> Void = { work in DispatchQueue.main.async(execute: work) }
    ) {
        self.engine = engine
        self.deliver = deliver

        engine.onEmergencyStop = { [weak self] in
            self?.deliver { [weak self] in
                self?.status.isRunning = false
                self?.status.stoppedByPad = true
            }
        }
        // S12: the opposite direction. It also fires on the USB I/O queue, so the hop comes first: the
        // published state must not be touched from there.
        engine.onGuidePress = { [weak self] in
            self?.deliver { [weak self] in
                self?.startFromPad()
            }
        }
        // The pad stopped sending, and reports are arriving again. Same hop as the other callbacks, for
        // the same reason.
        engine.onPadSilence = { [weak self] in
            self?.deliver { [weak self] in self?.status.padSilent = true }
        }
        engine.onPadResume = { [weak self] in
            self?.deliver { [weak self] in self?.status.padSilent = false }
        }
        // MOD+PS: the floating summary. Same hop as the other callbacks: the pad reports arrive on the USB
        // I/O queue, and the panel is main-thread only.
        engine.onSummaryPress = { [weak self] in
            self?.deliver { [weak self] in
                self?.onSummaryRequest?()
            }
        }
        // S5, S6: a control assigned to a profile step. It arrives on the engine's queue like the rest of
        // the report-driven callbacks, so the hop comes first: the library and the published state are
        // main-thread only.
        engine.onProfileStep = { [weak self] step in
            self?.deliver { [weak self] in
                self?.switchProfile(step)
            }
        }
    }

    /// Points the run at the rest of the app: the Perfil to run, its title, the profile a step leads to,
    /// and the permission fact.
    ///
    /// The sources are read when a rule needs them, never copied here: a stop, a step or a start reads
    /// the value of that moment, which is what keeps the window's editing and an in-flight press from
    /// disagreeing.
    public func attach(
        profile: @escaping () -> InputProfile,
        profileTitle: @escaping () -> String?,
        step: @escaping (ProfileStep) -> InputProfile?,
        hasAccessibility: @escaping () -> Bool
    ) {
        profileSource = profile
        profileTitleSource = profileTitle
        profileStepper = step
        hasAccessibilitySource = hasAccessibility
    }

    /// Starts the engine's timer. The rules live in `setEnabled`, not here.
    public func start() {
        engine.start()
    }

    /// Stops the engine — synchronously, so a caller on the way out can be sure the key releases were
    /// posted before the process ends — and forgets the run's own state.
    public func shutdown() {
        engine.stop()
        status.isRunning = false
        status.padSilent = false
    }

    /// Feeds one input report. Called for every report, before any UI throttling.
    public func ingest(_ report: XInputReport) {
        engine.ingest(report)
    }

    /// Starts or stops the emulation. Returns `false` when the start was refused, so the caller knows the
    /// Accessibility permission is missing and nothing was changed.
    ///
    /// A refused start is not a failure to report: starting without the permission would inject nothing,
    /// and the pad would look ignored instead of blocked by a missing permission. The prompt belongs to
    /// the app — it is a system sheet, and this module has no window to hang it on.
    @discardableResult
    public func setEnabled(_ on: Bool) -> Bool {
        status.stoppedByPad = false
        status.startedByPad = false
        guard on else {
            status.isRunning = false
            status.padSilent = false
            engine.setEnabled(false)
            return true
        }
        guard hasAccessibilitySource() else {
            status.isRunning = false
            engine.setEnabled(false)
            return false
        }
        // S1, S8: the profile in force is the one captured at start. Editing a mapping or switching
        // profiles while emulation runs therefore cannot disturb an in-flight press: the next start reads
        // the source again.
        engine.setProfile(profileSource())
        status.isRunning = true
        engine.setEnabled(true)
        return true
    }

    /// Switches to a profile chosen in the window while the emulation runs.
    ///
    /// It goes through `EmulationEngine.switchProfile(to:)`, the same path the pad's profile step uses, so
    /// the atomic part — release everything the old profile claimed, then apply the new one — is not
    /// reimplemented here. A call while emulation is stopped does nothing: there is no mapping to swap.
    public func switchToProfile(_ profile: InputProfile) {
        guard status.isRunning else { return }
        engine.switchProfile(to: profile)
    }

    /// The pad disconnected. A run cannot outlive its pad: the profile in force would keep describing
    /// controls nobody is pressing, and the silence flag would describe a pad that is not coming back.
    public func padDisconnected() {
        guard status.isRunning else { return }
        status.isRunning = false
        status.padSilent = false
        engine.setEnabled(false)
    }

    /// What the summary must show: the title of the Perfil in force, and the Perfil itself.
    public func summary() -> Summary {
        Summary(
            title: profileTitleSource() ?? Localization.resolve("Standard profile"),
            profile: profileSource()
        )
    }

    /// S5, S6: makes the profile one step away the active one, without stopping the emulation.
    ///
    /// The library chooses which profile that is (S6) and the engine performs the atomic switch (S5): it
    /// releases what the old profile claimed and only then applies the new one. Nothing here stops or
    /// restarts the run, so a step in the middle of a movement does not even blink — and a step while the
    /// emulation is stopped does nothing at all, because there is no mapping to switch. The guard is not
    /// redundant: stopping the run sets the flag before the engine hears about it, so a report that
    /// arrives in between must not swap a mapping that is on its way out.
    private func switchProfile(_ step: ProfileStep) {
        guard status.isRunning else { return }
        guard let profile = profileStepper(step) else { return }
        engine.switchProfile(to: profile)
    }

    /// S12: Guide asked to start the emulation.
    ///
    /// A denied Accessibility permission leaves everything untouched: starting without it would inject
    /// nothing, and the pad would look ignored instead of blocked by a missing permission.
    private func startFromPad() {
        guard !status.isRunning,
              GuideToggle.canStartFromPad(hasAccessibility: hasAccessibilitySource())
        else { return }
        setEnabled(true)
        status.startedByPad = status.isRunning
    }
}
