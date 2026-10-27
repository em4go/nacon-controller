import XCTest

@testable import NaconCore

final class ControlEdgesTests: XCTestCase {
    private func report(
        buttons: XInputButtons = [],
        leftTrigger: UInt8 = 0,
        rightTrigger: UInt8 = 0
    ) -> XInputReport {
        XInputReport(
            rawBytes: [],
            buttons: buttons,
            leftTrigger: leftTrigger,
            rightTrigger: rightTrigger,
            leftStick: .center,
            rightStick: .center
        )
    }

    func testFirstReportReportsHeldControlsAsPressed() {
        let transitions = ControlEdges.transitions(from: nil, to: report(buttons: [.buttonA]))
        XCTAssertEqual(transitions.pressed, [.buttonA])
        XCTAssertTrue(transitions.released.isEmpty)
    }

    func testPressIsDetectedOnce() {
        let idle = report()
        let pressed = report(buttons: [.buttonA])
        XCTAssertEqual(ControlEdges.transitions(from: idle, to: pressed).pressed, [.buttonA])
        XCTAssertTrue(ControlEdges.transitions(from: pressed, to: pressed).isEmpty)
    }

    func testReleaseIsDetected() {
        let pressed = report(buttons: [.buttonA])
        let idle = report()
        let transitions = ControlEdges.transitions(from: pressed, to: idle)
        XCTAssertEqual(transitions.released, [.buttonA])
        XCTAssertTrue(transitions.pressed.isEmpty)
    }

    func testSeveralControlsChangeInOneReport() {
        let transitions = ControlEdges.transitions(
            from: report(buttons: [.buttonA]),
            to: report(buttons: [.buttonB, .dpadUp])
        )
        XCTAssertEqual(transitions.pressed, [.buttonB, .dpadUp])
        XCTAssertEqual(transitions.released, [.buttonA])
    }

    func testTriggerCrossingTheThresholdCountsAsAPress() {
        let transitions = ControlEdges.transitions(
            from: report(leftTrigger: 0),
            to: report(leftTrigger: XInputControl.triggerPressedThreshold + 1)
        )
        XCTAssertEqual(transitions.pressed, [.leftTrigger])
    }
}
