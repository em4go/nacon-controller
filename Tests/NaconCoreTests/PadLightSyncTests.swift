import XCTest
@testable import NaconCore

/// S11: the light follows the run and the profile's colour, except when the user took it over.
final class PadLightSyncTests: XCTestCase {
    func testStartingARunLightsTheLightInTheProfilesColour() {
        var light = PadLight()
        light.sync(colour: .red, isEmulationActive: true)
        XCTAssertTrue(light.isOn)
        XCTAssertEqual(light.packet, XInputOutputReport.led(.player2))
    }

    func testStoppingTheRunTurnsTheLightOff() {
        var light = PadLight()
        light.sync(colour: .green, isEmulationActive: true)
        light.sync(colour: .green, isEmulationActive: false)
        XCTAssertFalse(light.isOn)
        XCTAssertEqual(light.packet, XInputOutputReport.led(.off))
    }

    func testAManualLightIgnoresTheRun() {
        // The exception that a caller of `sync` could otherwise lose: a hand-set light is not an
        // indicator, so starting the emulation must not light it in the profile's colour.
        var light = PadLight(source: .manual)
        light.sync(colour: .purple, isEmulationActive: true)
        XCTAssertFalse(light.isOn)
        XCTAssertEqual(light.packet, XInputOutputReport.led(.off))
    }

    func testAManualLightThatIsOnKeepsItsColourWhileTheRunChanges() {
        var light = PadLight(source: .manual, isManuallyOn: true)
        light.sync(colour: .purple, isEmulationActive: false)
        XCTAssertTrue(light.isOn)
        XCTAssertEqual(light.packet, XInputOutputReport.led(.player4))
    }
}
