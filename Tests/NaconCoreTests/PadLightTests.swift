import XCTest

@testable import NaconCore

/// Records the packets a caller would hand to `ControllerService.sendOutput`.
///
/// It stands in for the real service so the light decisions can be exercised without a pad. With no
/// pad attached the real service only publishes "sin endpoint de salida"; it never answers the
/// caller, so these tests also assert that no decision depends on a reply.
private final class RecordingOutput {
    private(set) var packets: [[UInt8]] = []
    private(set) var lastWriteStatus = "sin endpoint de salida"

    func sendOutput(_ packet: [UInt8]) {
        packets.append(packet)
    }
}

final class PadLightTests: XCTestCase {
    private let onPacket = XInputOutputReport.led(.player1)
    private let offPacket = XInputOutputReport.led(.off)

    // MARK: - S3: the indicator toggle is on by default

    func testIndicatorFollowsEmulationByDefault() {
        let light = PadLight()
        XCTAssertEqual(light.source, .emulation, "el indicador debe venir activado")
        XCTAssertFalse(light.isOn, "sin emulación activa la luz empieza apagada")
        XCTAssertEqual(light.packet, offPacket)
    }

    // MARK: - S1: emulation active + indicator on means the light is on

    func testLightIsOnWhileEmulationIsActiveAndFollowing() {
        var light = PadLight()
        light.isEmulationActive = true

        XCTAssertTrue(light.isOn)
        XCTAssertEqual(light.packet, onPacket)
    }

    // MARK: - S2: emulation stops, the light goes off

    func testLightTurnsOffWhenEmulationStops() {
        var light = PadLight()
        light.isEmulationActive = true
        let whileRunning = light.packet

        light.isEmulationActive = false

        XCTAssertEqual(whileRunning, onPacket)
        XCTAssertFalse(light.isOn)
        XCTAssertEqual(light.packet, offPacket)
    }

    // MARK: - S4: manual control when the indicator toggle is off

    func testManualToggleControlsLightWhileFollowingIsDisabled() {
        var light = PadLight()
        light.source = .manual

        light.isManuallyOn = true
        XCTAssertTrue(light.isOn)
        XCTAssertEqual(light.packet, onPacket)

        light.isManuallyOn = false
        XCTAssertFalse(light.isOn)
        XCTAssertEqual(light.packet, offPacket)
    }

    func testEmulationChangesAreIgnoredWhileManualControlIsSelected() {
        var light = PadLight()
        light.source = .manual
        light.isEmulationActive = true

        XCTAssertFalse(light.isOn, "con el indicador desactivado la emulación no toca la luz")
        XCTAssertEqual(light.packet, offPacket)

        light.isManuallyOn = true
        light.isEmulationActive = false

        XCTAssertTrue(light.isOn, "la luz manual sobrevive al parar la emulación")
        XCTAssertEqual(light.packet, onPacket)
    }

    // MARK: - S5: the app must not leave the light on when it exits

    func testTerminationPacketTurnsLightOff() {
        XCTAssertEqual(PadLight.offPacket, offPacket)
        XCTAssertEqual(PadLight.offPacket, XInputOutputReport.led(.off))
    }

    // MARK: - Packet follows the visible state in every combination

    func testPacketMatchesVisibleStateForEveryCombination() {
        for source in [PadLight.Source.emulation, .manual] {
            for emulation in [true, false] {
                for manual in [true, false] {
                    var light = PadLight()
                    light.source = source
                    light.isEmulationActive = emulation
                    light.isManuallyOn = manual

                    let expected = source == .emulation ? emulation : manual
                    XCTAssertEqual(
                        light.isOn,
                        expected,
                        "source=\(source) emulacion=\(emulation) manual=\(manual)"
                    )
                    XCTAssertEqual(light.packet, expected ? onPacket : offPacket)
                }
            }
        }
    }

    // MARK: - S6: toggling with no pad must not crash or leave stale state

    func testSendingWithNoPadKeepsStateTruthful() {
        let output = RecordingOutput()
        var light = PadLight()
        light.source = .manual

        light.isManuallyOn = true
        output.sendOutput(light.packet)

        XCTAssertEqual(output.lastWriteStatus, "sin endpoint de salida")
        XCTAssertTrue(light.isOn, "el estado visible no espera respuesta del mando")
        XCTAssertEqual(output.packets, [onPacket])

        light.isManuallyOn = false
        output.sendOutput(light.packet)

        XCTAssertFalse(light.isOn)
        XCTAssertEqual(output.packets, [onPacket, offPacket])
    }
}
