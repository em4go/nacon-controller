import CoreGraphics
import XCTest

@testable import NaconCore

/// A key event carries its own flags and the receiving side reads those, not the state behind them.
///
/// Two defects lived here. First, a stroke posted while another control held a modifier carried no
/// modifiers at all, so ⌘ + ⇥ arrived as a plain Tab. Then the fix copied the system's reported state
/// into every event, and that report lags: the event that released ⌃ came after the one that released
/// ⇧ and read ⇧ as still down, so from then on everything claimed Shift was held. The pad is its own
/// keyboard: it combines exactly the modifiers it holds itself.
final class InputEmitterFlagsTests: XCTestCase {
    /// The rule the wheel now depends on as well: a mouse event says which modifiers this app holds.
    ///
    /// Clicks and movements already read it; the wheel did not, which is why no scroll could carry ⌘ and
    /// ⌘+scroll could not zoom. Pinning all five here means the three call sites cannot drift apart.
    func testMouseFlagsCarryEveryModifierThePadCanHold() {
        XCTAssertEqual(CGEventEmitter.mouseFlags(held: [.control]), .maskControl)
        XCTAssertEqual(CGEventEmitter.mouseFlags(held: [.option]), .maskAlternate)
        XCTAssertEqual(CGEventEmitter.mouseFlags(held: [.shift]), .maskShift)
        XCTAssertEqual(CGEventEmitter.mouseFlags(held: [.command]), .maskCommand)
        XCTAssertEqual(CGEventEmitter.mouseFlags(held: [.function]), .maskSecondaryFn)
        XCTAssertEqual(
            CGEventEmitter.mouseFlags(held: [.command, .shift]),
            [.maskCommand, .maskShift],
            "two held modifiers must arrive together, in either order"
        )
        XCTAssertEqual(CGEventEmitter.mouseFlags(held: []), [], "nothing held is nothing claimed")
    }

    private let tab = KeyStroke(keyCode: 48, isDown: true, modifiers: [])
    private let controlDown = KeyStroke(keyCode: 59, isDown: true, modifiers: [.control])
    private let shiftDown = KeyStroke(keyCode: 56, isDown: true, modifiers: [.control, .shift])
    private let shiftUp = KeyStroke(keyCode: 56, isDown: false, modifiers: [.control])
    private let controlUp = KeyStroke(keyCode: 59, isDown: false, modifiers: [])
    private let commandDown = KeyStroke(keyCode: 55, isDown: true, modifiers: [.command])
    private let commandUp = KeyStroke(keyCode: 55, isDown: false, modifiers: [])

    func testAStrokeCarriesTheModifiersThisAppHolds() {
        XCTAssertEqual(CGEventEmitter.strokeFlags(for: tab, held: [.command]), .maskCommand)
        XCTAssertEqual(CGEventEmitter.strokeFlags(for: tab, held: []), [])
    }

    func testTheStrokesOwnModifiersSurviveTheMerge() {
        // A mapped ⌘⇥ pressed while the pad also holds ⇧ must arrive as ⇧⌘⇥, like on a keyboard.
        let own = KeyStroke(keyCode: 48, isDown: true, modifiers: [.command])
        XCTAssertEqual(CGEventEmitter.strokeFlags(for: own, held: [.shift]), [.maskCommand, .maskShift])
    }

    func testAModifiersOwnReleaseNeverClaimsItIsStillHeld() {
        // The system reports Command as held at the instant its key-up is posted; an event that repeats
        // that leaves the switcher on screen after the button was let go.
        XCTAssertEqual(CGEventEmitter.strokeFlags(for: commandUp, held: [.command]), [])
        XCTAssertEqual(CGEventEmitter.strokeFlags(for: shiftUp, held: [.control, .shift]), .maskControl)
    }

    /// The reported defect: after holding ⌃⇧ and releasing it, Shift stayed on everything that came
    /// next, so ⌘⇥ behaved like ⇧⌘⇥.
    func testReleasingAHoldLeavesNothingBehindForTheNextShortcut() {
        var held: ModifierSet = []

        XCTAssertEqual(CGEventEmitter.strokeFlags(for: controlDown, held: held), .maskControl)
        held.insert(.control)
        XCTAssertEqual(
            CGEventEmitter.strokeFlags(for: shiftDown, held: held),
            [.maskControl, .maskShift]
        )
        held.insert(.shift)

        XCTAssertEqual(CGEventEmitter.strokeFlags(for: shiftUp, held: held), .maskControl)
        held.remove(.shift)
        XCTAssertEqual(CGEventEmitter.strokeFlags(for: controlUp, held: held), [])
        held.remove(.control)

        XCTAssertEqual(CGEventEmitter.strokeFlags(for: commandDown, held: held), .maskCommand)
        held.insert(.command)
        let nextShortcut = CGEventEmitter.strokeFlags(for: tab, held: held)
        XCTAssertEqual(nextShortcut, .maskCommand)
        XCTAssertFalse(nextShortcut.contains(.maskShift), "Shift must not survive the release of its hold")
    }
}
