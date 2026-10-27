import XCTest

@testable import NaconCore

private final class RecordingEmitter: InputEmitter {
    enum Event: Equatable {
        case press(MappedAction)
        case release(MappedAction)
        case move(deltaX: Double, deltaY: Double)
        case scroll(Int)
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

    func scroll(lines: Int) {
        events.append(.scroll(lines))
    }

    func reset() {
        events.removeAll()
    }
}

final class EmulationEngineTests: XCTestCase {
    private var emitter: RecordingEmitter!
    private var engine: EmulationEngine!

    override func setUp() {
        super.setUp()
        emitter = RecordingEmitter()
        engine = EmulationEngine(emitter: emitter)
    }

    private func report(
        buttons: XInputButtons = [],
        left: XInputStick = .center,
        right: XInputStick = .center
    ) -> XInputReport {
        XInputReport(
            rawBytes: [],
            buttons: buttons,
            leftTrigger: 0,
            rightTrigger: 0,
            leftStick: left,
            rightStick: right
        )
    }

    private func stick(normalizedX: Double, normalizedY: Double = 0) -> XInputStick {
        XInputStick(
            rawX: Int16((normalizedX * 32_767).rounded()),
            rawY: Int16((-normalizedY * 32_767).rounded())
        )
    }

    func testDisabledEngineProducesNoEvents() {
        engine.setEnabledNow(false)
        engine.handle(report())
        engine.handle(report(buttons: [.buttonA]))
        XCTAssertTrue(emitter.events.isEmpty)
    }

    func testPressIsEmittedOnceAndReleasedOnce() {
        engine.setEnabledNow(true)
        engine.handle(report())
        engine.handle(report(buttons: [.buttonA]))
        engine.handle(report(buttons: [.buttonA]))
        engine.handle(report())

        XCTAssertEqual(emitter.events, [
            .press(.mouseButton(.left)),
            .release(.mouseButton(.left)),
        ])
    }

    func testGuideDisablesEmulationAndReleasesHeldActions() {
        engine.setEnabledNow(true)
        engine.handle(report())
        engine.handle(report(buttons: [.buttonA]))
        engine.handle(report(buttons: [.buttonA, .guide]))
        emitter.reset()

        engine.handle(report(buttons: [.buttonB]))
        XCTAssertTrue(emitter.events.isEmpty, "emulation must stay off after the emergency stop")
        XCTAssertTrue(emitter.events.contains { if case .release = $0 { return true } else { return false } } == false)
    }

    func testDisablingReleasesHeldActions() {
        engine.setEnabledNow(true)
        engine.handle(report())
        engine.handle(report(buttons: [.buttonA]))
        emitter.reset()

        engine.setEnabledNow(false)
        XCTAssertEqual(emitter.events, [.release(.mouseButton(.left))])
    }

    func testTickMovesCursorOnlyWhenEnabled() {
        engine.handle(report(left: stick(normalizedX: 1)))
        engine.tick(seconds: 0.1)
        XCTAssertTrue(emitter.events.isEmpty, "a disabled engine must not move the cursor")

        engine.setEnabledNow(true)
        engine.tick(seconds: 0.1)
        guard case .move(let deltaX, let deltaY)? = emitter.events.first else {
            return XCTFail("expected a cursor move")
        }
        XCTAssertGreaterThan(deltaX, 0)
        XCTAssertEqual(deltaY, 0, accuracy: 1e-9)
    }

    func testCursorMovementScalesWithElapsedTime() {
        engine.setEnabledNow(true)
        engine.handle(report(left: stick(normalizedX: 1)))
        engine.tick(seconds: 0.5)
        engine.tick(seconds: 0.5)
        let total = emitter.events.reduce(0.0) { partial, event in
            if case .move(let deltaX, _) = event { return partial + deltaX }
            return partial
        }
        XCTAssertEqual(total, 1_400, accuracy: 5)
    }

    func testCenteredStickProducesNoCursorEvent() {
        engine.setEnabledNow(true)
        engine.handle(report())
        engine.tick(seconds: 0.1)
        XCTAssertTrue(emitter.events.isEmpty)
    }

    func testScrollEmitsWholeLinesOnly() {
        engine.setEnabledNow(true)
        engine.handle(report(right: stick(normalizedX: 0, normalizedY: 1)))
        engine.tick(seconds: 0.05)
        XCTAssertTrue(emitter.events.isEmpty, "half a line must not be emitted")
        engine.tick(seconds: 0.05)
        XCTAssertEqual(emitter.events, [.scroll(1)])
    }
}
