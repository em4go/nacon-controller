import CoreGraphics
import XCTest

@testable import NaconCore

final class ScreenGeometryTests: XCTestCase {
    private let main = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)

    func testPointInsideDisplayIsUnchanged() {
        let point = CGPoint(x: 640, y: 480)
        XCTAssertEqual(ScreenGeometry.clamped(point, to: [main]), point)
    }

    func testPointBeyondRightEdgeIsClampedToLastPixel() {
        let clamped = ScreenGeometry.clamped(CGPoint(x: 5_000, y: 500), to: [main])
        XCTAssertEqual(clamped.x, 1_919)
        XCTAssertEqual(clamped.y, 500)
    }

    func testPointBeyondTopLeftIsClampedToOrigin() {
        let clamped = ScreenGeometry.clamped(CGPoint(x: -400, y: -900), to: [main])
        XCTAssertEqual(clamped.x, 0)
        XCTAssertEqual(clamped.y, 0)
    }

    func testPointInGapBetweenDisplaysLandsOnTheNearestOne() {
        let second = CGRect(x: 2_000, y: 0, width: 1_920, height: 1_080)
        // x = 1950 is 31 points from the first display's last pixel and 50 from the second's first.
        let clamped = ScreenGeometry.clamped(CGPoint(x: 1_950, y: 500), to: [main, second])
        XCTAssertEqual(clamped.x, 1_919)
        XCTAssertTrue(main.contains(clamped))
    }

    func testNoDisplaysLeavesThePointUnchanged() {
        let point = CGPoint(x: 12, y: 34)
        XCTAssertEqual(ScreenGeometry.clamped(point, to: []), point)
    }

    func testClampingIsIdempotentAtTheEdge() {
        let once = ScreenGeometry.clamped(CGPoint(x: 9_999, y: 9_999), to: [main])
        XCTAssertEqual(ScreenGeometry.clamped(once, to: [main]), once)
    }
}
