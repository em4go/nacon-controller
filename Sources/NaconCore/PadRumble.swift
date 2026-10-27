import Foundation

/// The rumble command the app sends, built from an intensity the user can see and hear.
///
/// The motors keep spinning after the packet is sent, unlike the light, which simply holds a state.
/// That makes this the one output where a malformed value would be felt directly, so the intensity is
/// clamped inside the type and every packet is built from the clamped value. `isSilent` decides
/// whether a burst is worth starting at all, and `PadRumble.stopPacket` is the only command the app
/// uses to stop the motors.
///
/// The timing of a burst lives outside on purpose: it needs a clock and a view, and the only rule
/// that can be checked without either is "the packet is well formed", which is exactly what the
/// tests pin.
public struct PadRumble: Equatable, Sendable {
    /// How long a burst lasts before the stop packet follows it.
    public static let burstSeconds: Double = 0.2

    /// Strength from 0 (silent) to 1 (both motors at maximum). Assigning outside the range clamps.
    public var intensity: Double {
        didSet { intensity = Self.clamp(intensity) }
    }

    public init(intensity: Double = 0.5) {
        self.intensity = Self.clamp(intensity)
    }

    /// The nearest strength inside 0...1. A non-finite number becomes silence.
    public static func clamp(_ raw: Double) -> Double {
        guard raw.isFinite else { return 0 }
        return min(max(raw, 0), 1)
    }

    /// Whether a burst would produce no movement at all.
    public var isSilent: Bool {
        intensity <= 0
    }

    /// `00 08 00 <left> <right> 00 00 00` with both motors at the same strength.
    public var packet: [UInt8] {
        XInputOutputReport.rumble(left: byte, right: byte)
    }

    /// The command that stops the motors. Sent after every burst, and at termination unconditionally.
    public static var stopPacket: [UInt8] {
        XInputOutputReport.rumble(left: 0, right: 0)
    }

    private var byte: UInt8 {
        UInt8((Self.clamp(intensity) * 255).rounded())
    }
}

/// Runs one short burst and always follows it with the stop packet.
///
/// This is the glue the app needs and the tests cannot reach: it owns a clock. It lives here, next to
/// `PadRumble`, so the view keeps no timing state of its own. A newer burst wins over an older one,
/// which is why the generation counter exists: the stop of a superseded burst must never silence the
/// burst that replaced it.
///
/// Deliberately not main-actor isolated: a `View`'s stored properties are initialised from a
/// non-isolated `init`, and the only thing this type reaches is `ControllerService.sendOutput`, which
/// is documented safe from any thread. The state is touched from the main thread and from the task it
/// spawns, which is what `@unchecked Sendable` asserts.
public final class RumbleBurstPlayer: @unchecked Sendable {
    private var generation = 0
    private var pendingStop: Task<Void, Never>?

    public init() {}

    /// Vibrates for `PadRumble.burstSeconds` and stops. A silent setting sends nothing.
    public func fire(_ rumble: PadRumble, send: @escaping ([UInt8]) -> Void) {
        pendingStop?.cancel()
        generation += 1
        let mine = generation
        guard !rumble.isSilent else { return }
        send(rumble.packet)
        pendingStop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(PadRumble.burstSeconds))
            guard !Task.isCancelled, let self, mine == self.generation else { return }
            send(PadRumble.stopPacket)
        }
    }

    /// Stops immediately, for termination and for leaving the section.
    public func stop(send: ([UInt8]) -> Void) {
        pendingStop?.cancel()
        pendingStop = nil
        generation += 1
        send(PadRumble.stopPacket)
    }
}
