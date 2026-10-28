import XCTest

@testable import NaconCore

/// Records what the engine decides to emit, so tests can assert on effects instead of on the system.
final class RecordingEmitter: InputEmitter {
    enum Event: Equatable {
        case press(MappedAction)
        case release(MappedAction)
        case move(deltaX: Double, deltaY: Double)
        case scroll(Int)
        case repeatKey(MappedAction)
    }

    private(set) var events: [Event] = []

    func press(_ action: MappedAction) {
        events.append(.press(action))
    }

    func release(_ action: MappedAction) {
        events.append(.release(action))
    }

    func moveCursor(deltaX: Double, deltaY: Double) {
        events.append(.move(deltaX: deltaX, deltaY: deltaY))
    }

    func scroll(pixels: Int) {
        events.append(.scroll(pixels))
    }

    func repeatKey(_ action: MappedAction) {
        events.append(.repeatKey(action))
    }

    func reset() {
        events.removeAll()
    }

    /// Total pixels the engine asked to scroll, for tests that compare cadences.
    var pixels: Int {
        events.reduce(0) { total, event in
            if case .scroll(let value) = event { return total + value }
            return total
        }
    }
}