import XCTest
@testable import NaconCore

/// The pass that used to be only reachable by unplugging the Mando.
///
/// Every case states the values the scan and the link would have, so the rule is checked in
/// milliseconds instead of in seconds of silence, and a boundary that would need a 2-second wait
/// becomes one line.
final class PadReconnectTests: XCTestCase {
    // MARK: - The healthy link wins over the scan

    func testAQuietLinkInsideTheThresholdIsKept() {
        let action = PadReconnect.decide(
            found: [xinputPad()],
            link: .quiet(0.5)
        )

        XCTAssertEqual(action, .keepLink)
    }

    func testALinkExactlyAtTheThresholdIsStillKept() {
        let action = PadReconnect.decide(
            found: [],
            link: .quiet(PadReconnect.staleAfter)
        )

        XCTAssertEqual(action, .keepLink, "the threshold is inclusive, as the service had it")
    }

    func testTheThresholdStaysTheTwoSecondsTheServiceHad() {
        // S5: silence of two seconds was what the service treated as a dead link, and moving the rule
        // must not quietly widen or narrow it.
        XCTAssertEqual(PadReconnect.staleAfter, 2.0)
    }

    // MARK: - A stale link is replaced in the same pass

    func testAQuietLinkPastTheThresholdIsReleasedBeforeConnectingTheNextDevice() {
        let action = PadReconnect.decide(
            found: [xinputPad()],
            link: .quiet(PadReconnect.staleAfter + 0.1)
        )

        XCTAssertEqual(action, .connect(index: 0, releaseLinkFirst: true))
    }

    func testAQuietLinkPastTheThresholdWithNoDeviceIsTornDown() {
        let action = PadReconnect.decide(
            found: [],
            link: .quiet(PadReconnect.staleAfter + 0.1)
        )

        XCTAssertEqual(action, .tearDownOnly)
    }

    func testAQuietLinkPastTheThresholdWithOnlyUnreadableDevicesIsTornDown() {
        let action = PadReconnect.decide(
            found: [bootloaderPad(), ps4Pad()],
            link: .quiet(PadReconnect.staleAfter + 0.1)
        )

        XCTAssertEqual(action, .tearDownOnly, "a device that cannot be read is not a candidate")
    }

    // MARK: - No link

    func testNoLinkAndNoDeviceReportsSearching() {
        let action = PadReconnect.decide(found: [], link: .none)

        XCTAssertEqual(action, .search)
    }

    func testNoLinkConnectsToTheFirstReadableDevice() {
        let action = PadReconnect.decide(
            found: [ps4Pad(), xinputPad()],
            link: .none
        )

        XCTAssertEqual(action, .connect(index: 1, releaseLinkFirst: false))
    }

    func testNoLinkWithOnlyUnreadableDevicesReportsSearching() {
        let action = PadReconnect.decide(
            found: [bootloaderPad(), ps4Pad()],
            link: .none
        )

        XCTAssertEqual(action, .search)
    }

    // MARK: - The threshold belongs to the caller

    func testTheCallerSetsTheThreshold() {
        let action = PadReconnect.decide(
            found: [xinputPad()],
            link: .quiet(0.3),
            staleAfter: 0.2
        )

        XCTAssertEqual(action, .connect(index: 0, releaseLinkFirst: true))
    }

    // MARK: - Fixtures

    private func xinputPad(id: UInt64 = 1) -> NaconDevice {
        NaconDevice(
            id: id,
            productName: "NACON Compact Controller",
            vendorID: NaconIDs.bigbenVendorID,
            productID: NaconIDs.xinputProductID,
            serialNumber: nil,
            locationID: 0
        )
    }

    private func ps4Pad(id: UInt64 = 2) -> NaconDevice {
        NaconDevice(
            id: id,
            productName: "NACON Compact Controller",
            vendorID: NaconIDs.bigbenVendorID,
            productID: NaconIDs.ps4ProductID,
            serialNumber: nil,
            locationID: 0
        )
    }

    private func bootloaderPad(id: UInt64 = 3) -> NaconDevice {
        NaconDevice(
            id: id,
            productName: "NACON update mode",
            vendorID: NaconIDs.bootloaderVendorID,
            productID: NaconIDs.bootloaderProductID,
            serialNumber: nil,
            locationID: 0
        )
    }
}
