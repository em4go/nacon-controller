import XCTest

@testable import NaconCore

/// Records what the engine decides to emit, so tests can assert on effects instead of on the system.
final class RecordingEmitter: InputEmitter {
    enum Event: Equatable {
        case press(MappedAction)
        case release(MappedAction)
        case move(deltaX: Double, deltaY: Double)
        case scroll(ScrollPixels)
        case repeatKey(MappedAction)
        case toggleMouseButton(MouseButton)
        case releaseAllMouseButtons
    }

    private(set) var events: [Event] = []
    /// How many times the engine asked for the modifiers this emitter holds to be let go.
    private(set) var releasedHeldModifiers = 0

    func press(_ action: MappedAction) {
        events.append(.press(action))
    }

    func release(_ action: MappedAction) {
        events.append(.release(action))
    }

    func moveCursor(deltaX: Double, deltaY: Double) {
        events.append(.move(deltaX: deltaX, deltaY: deltaY))
    }

    func scroll(pixels: ScrollPixels) {
        events.append(.scroll(pixels))
    }

    func repeatKey(_ action: MappedAction) {
        events.append(.repeatKey(action))
    }

    func reset() {
        events.removeAll()
    }

    func toggleMouseButton(_ button: MouseButton) {
        events.append(.toggleMouseButton(button))
    }

    func releaseAllMouseButtons() {
        events.append(.releaseAllMouseButtons)
    }

    func releaseHeldModifiers() {
        releasedHeldModifiers += 1
    }

    /// Every scroll the engine asked for, in order, for tests that inspect the two axes separately.
    var scrollPixels: [ScrollPixels] {
        events.compactMap { event in
            if case .scroll(let value) = event { return value }
            return nil
        }
    }

    /// Total pixels per axis, for tests that compare cadences.
    var scrolledX: Int { scrollPixels.reduce(0) { $0 + $1.x } }
    var scrolledY: Int { scrollPixels.reduce(0) { $0 + $1.y } }
}