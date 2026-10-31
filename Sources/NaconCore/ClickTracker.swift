import Foundation

/// How many clicks the press being posted is, in the sense a real mouse declares to the system.
///
/// A double click is not two single clicks the system pairs up on its own: WindowServer reads the
/// click count stamped on the event, and two presses that each claim "first click" stay two separate
/// singles no matter how quick they are. So the emitter has to say which click this is, and the
/// counting rules live here.
///
/// Pure on purpose. The emitter needs a live event tap and cannot be unit tested, so coordinates and
/// time arrive as arguments instead of being read from CoreGraphics and the clock.
public struct ClickTracker: Sendable {
    /// Points the pointer may move between two clicks of the same gesture. A real double click is
    /// made without moving the mouse; a stick that drifts while the button is pressed is not.
    public static let maximumDrift: Double = 4

    /// The last press, kept to decide whether the next one continues the gesture.
    private var lastPress: Press?

    private struct Press: Sendable {
        let button: MouseButton
        let positionX: Double
        let positionY: Double
        let now: TimeInterval
        let state: Int
    }

    public init() {}

    /// The click state for a press of `button` at this position and time: `1` for a fresh click, one
    /// more than the previous press when it continues the same gesture.
    public mutating func press(
        of button: MouseButton,
        x positionX: Double,
        y positionY: Double,
        now: TimeInterval,
        interval: TimeInterval
    ) -> Int {
        let state: Int
        if let last = lastPress,
           last.button == button,
           now - last.now <= interval,
           abs(positionX - last.positionX) <= Self.maximumDrift,
           abs(positionY - last.positionY) <= Self.maximumDrift {
            state = last.state + 1
        } else {
            state = 1
        }
        lastPress = Press(button: button, positionX: positionX, positionY: positionY, now: now, state: state)
        return state
    }

    /// The click state for the release that follows the last press. A real click carries the same
    /// count down and up; a release that said `1` would end a double click as a single one.
    public func releaseState() -> Int {
        lastPress?.state ?? 1
    }

    /// Forgets the gesture in progress, so the next press starts again at one.
    public mutating func reset() {
        lastPress = nil
    }
}
