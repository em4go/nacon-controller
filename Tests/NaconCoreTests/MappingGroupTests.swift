import XCTest
@testable import NaconCore

/// S9: the table's sections must account for every row, exactly once.
///
/// A control missing from every group is the quiet failure this rule exists to stop: the editor would
/// draw one row fewer and nothing would complain.
final class MappingGroupTests: XCTestCase {
    func testEveryRemappableControlAppearsExactlyOnce() {
        let drawn = MappingRules.groupedRemappableControls.flatMap(\.controls)
        XCTAssertEqual(drawn.count, MappingRules.remappableControls.count)
        XCTAssertEqual(Set(drawn), Set(MappingRules.remappableControls))
        XCTAssertEqual(drawn.count, Set(drawn).count, "a control was drawn twice")
    }

    func testTheOrderInsideEachGroupFollowsTheEditor() {
        // Within a group the rows keep the order they have everywhere else, so a reader who learned
        // the table does not have to relearn it. Across groups the order does change, and it has to:
        // grouping is exactly the act of moving a control to where its neighbours are.
        let editor = MappingRules.remappableControls
        for section in MappingRules.groupedRemappableControls {
            let expected = editor.filter { section.controls.contains($0) }
            XCTAssertEqual(section.controls, expected, "\(section.group.rawValue) reordered its rows")
        }
    }

    func testTheReservedControlIsInNoGroup() {
        XCTAssertFalse(
            MappingRules.groupedRemappableControls.contains { $0.controls.contains(MappingRules.reservedControl) }
        )
    }

    func testNoGroupIsEmptyAndEachHasAName() {
        for section in MappingRules.groupedRemappableControls {
            XCTAssertFalse(section.controls.isEmpty, "\(section.group.rawValue) was drawn with no rows")
            XCTAssertFalse(section.group.title.isEmpty)
        }
    }

    func testTheGroupsCoverTheControlsTheEditorExpects() {
        // Named expectations, not a count: if a control is ever added to the pad, this fails and forces
        // a decision about where it belongs, instead of dropping it into whatever group exists.
        let byGroup = Dictionary(
            uniqueKeysWithValues: MappingRules.groupedRemappableControls.map { ($0.group, $0.controls) }
        )
        XCTAssertEqual(byGroup[.dpad], [.dpadUp, .dpadDown, .dpadLeft, .dpadRight])
        XCTAssertEqual(byGroup[.face], [.buttonA, .buttonB, .buttonX, .buttonY])
        XCTAssertEqual(byGroup[.shoulders], [.leftBumper, .rightBumper, .leftTrigger, .rightTrigger])
        XCTAssertEqual(byGroup[.sticks], [.leftThumb, .rightThumb])
        XCTAssertEqual(byGroup[.system], [.back, .start])
    }
}
