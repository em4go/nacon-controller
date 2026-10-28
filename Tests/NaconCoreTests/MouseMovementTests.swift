import CoreGraphics
import XCTest

@testable import NaconCore

/// A mouse that travels with a button down reports a drag, not a move. Views that compute a selection
/// inside their own mouse-down loop only react to dragged events, so a selection tool opened and the
/// movement never reached it.
final class MouseMovementTests: XCTestCase {
    func testMovementWithNothingPressedIsAPlainMove() {
        XCTAssertEqual(CGEventEmitter.movementType(pressed: []), .mouseMoved)
    }

    func testMovementWithTheLeftButtonPressedIsALeftDrag() {
        XCTAssertEqual(CGEventEmitter.movementType(pressed: [.left]), .leftMouseDragged)
    }

    func testMovementWithTheRightButtonPressedIsARightDrag() {
        XCTAssertEqual(CGEventEmitter.movementType(pressed: [.right]), .rightMouseDragged)
    }

    func testMovementWithTheMiddleButtonPressedIsAnOtherDrag() {
        XCTAssertEqual(CGEventEmitter.movementType(pressed: [.middle]), .otherMouseDragged)
    }

    func testTheDragNamesTheButtonThatIsPressed() {
        XCTAssertEqual(CGEventEmitter.cgButton(for: [.left]), .left)
        XCTAssertEqual(CGEventEmitter.cgButton(for: [.right]), .right)
        XCTAssertEqual(CGEventEmitter.cgButton(for: [.middle]), .center)
        XCTAssertEqual(CGEventEmitter.cgButton(for: []), .left, "a plain move still names a button")
    }

    func testTwoButtonsPressedResolveToOneDeterministicDrag() {
        // The order is fixed, so the same gesture always produces the same event instead of depending
        // on how a Set happens to iterate.
        XCTAssertEqual(CGEventEmitter.movementType(pressed: [.left, .right]), .leftMouseDragged)
        XCTAssertEqual(CGEventEmitter.movementType(pressed: [.right, .middle]), .rightMouseDragged)
    }

    func testAClickCarriesTheModifiersThisAppHolds() {
        // A view that reacts to ⌘-click reads the flags of the event. A click that claims no modifiers
        // is a plain click no matter what the pad is holding, which is why a link that needs ⌘ stayed
        // inert while the buttons around it worked.
        XCTAssertEqual(CGEventEmitter.mouseFlags(held: [.command]), .maskCommand)
        XCTAssertEqual(CGEventEmitter.mouseFlags(held: []), [])
        XCTAssertEqual(CGEventEmitter.mouseFlags(held: [.command, .shift]), [.maskCommand, .maskShift])
    }
}
