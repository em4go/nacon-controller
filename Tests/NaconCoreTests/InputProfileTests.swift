import XCTest

@testable import NaconCore

final class InputProfileTests: XCTestCase {
    func testStandardProfileMapsFaceButtonsToMouse() {
        let profile = InputProfile.standard
        XCTAssertEqual(profile.action(for: .buttonA), .mouseButton(.left))
        XCTAssertEqual(profile.action(for: .buttonB), .mouseButton(.right))
        XCTAssertEqual(profile.action(for: .buttonX), .mouseButton(.middle))
    }

    func testGuideIsReservedAndProducesNoAction() {
        XCTAssertEqual(InputProfile.standard.action(for: .guide), .none)
        XCTAssertFalse(InputProfile.standard.discreteControls.contains(.guide))
    }

    func testUnmappedControlFallsBackToNoAction() {
        let empty = InputProfile(mappings: [:])
        XCTAssertEqual(empty.action(for: .buttonA), .none)
        XCTAssertTrue(empty.discreteControls.isEmpty)
    }

    func testKeyActionCarriesModifiers() {
        let combo = KeyCombo(.tab, modifiers: [.command, .shift])
        XCTAssertEqual(combo.keyCode, VirtualKey.tab.rawValue)
        XCTAssertTrue(combo.modifiers.contains(.command))
        XCTAssertFalse(combo.modifiers.contains(.control))
    }
}
