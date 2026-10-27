import Foundation

/// Controls that changed state between two reports.
public struct ControlTransitions: Equatable, Sendable {
    public let pressed: Set<XInputControl>
    public let released: Set<XInputControl>

    public init(pressed: Set<XInputControl>, released: Set<XInputControl>) {
        self.pressed = pressed
        self.released = released
    }

    public static let none = ControlTransitions(pressed: [], released: [])
    public var isEmpty: Bool { pressed.isEmpty && released.isEmpty }
}

public enum ControlEdges {
    /// Compares two reports and reports which controls went down and which went up.
    ///
    /// `previous` is nil on the first report: every control already held at that moment is
    /// reported as pressed so the first press is not lost.
    public static func transitions(
        from previous: XInputReport?,
        to current: XInputReport
    ) -> ControlTransitions {
        var pressed: Set<XInputControl> = []
        var released: Set<XInputControl> = []
        for control in XInputControl.allCases {
            let wasPressed = previous.map { control.isPressed(in: $0) } ?? false
            let isPressed = control.isPressed(in: current)
            if isPressed, !wasPressed { pressed.insert(control) }
            if !isPressed, wasPressed { released.insert(control) }
        }
        return ControlTransitions(pressed: pressed, released: released)
    }
}
