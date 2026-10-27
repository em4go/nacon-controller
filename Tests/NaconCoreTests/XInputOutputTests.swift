import XCTest

@testable import NaconCore

final class XInputOutputTests: XCTestCase {
    func testLedPacketLayout() {
        XCTAssertEqual(XInputOutputReport.led(.player1), [0x01, 0x03, 0x06])
        XCTAssertEqual(XInputOutputReport.led(.off), [0x01, 0x03, 0x00])
        XCTAssertEqual(XInputOutputReport.led(.player1).count, XInputOutputReport.ledPacketLength)
    }

    func testEveryLedPatternHasADistinctByte() {
        let values = Set(XInputOutputReport.LEDPattern.allCases.map(\.rawValue))
        XCTAssertEqual(values.count, XInputOutputReport.LEDPattern.allCases.count)
    }

    func testRumblePacketLayout() {
        let packet = XInputOutputReport.rumble(left: 200, right: 40)
        XCTAssertEqual(packet, [0x00, 0x08, 0x00, 200, 40, 0x00, 0x00, 0x00])
        XCTAssertEqual(packet.count, XInputOutputReport.rumblePacketLength)
    }
}
