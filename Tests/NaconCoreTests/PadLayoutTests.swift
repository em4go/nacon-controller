import XCTest

@testable import NaconCore

/// The graphical pad view lights up the pixels of the control under the pointer on the DualShock 4
/// artwork, so this table is what decides whether a highlight and its hit area land on the right part
/// of the drawing.
///
/// The checks below are the invariants a later nudge must not break: every control placed exactly
/// once, inside the picture, on the correct side of the pad, far enough apart to stay readable, away
/// from the edges, and the values themselves pinned so an accidental edit fails the suite.
final class PadLayoutTests: XCTestCase {
    private let layout = PadLayout.standard

    private func point(_ control: XInputControl) -> PadLayout.Point {
        guard let point = layout.point(for: control) else {
            XCTFail("\(control) has no position on the artwork")
            return PadLayout.Point(horizontal: -1, vertical: -1)
        }
        return point
    }

    // MARK: - Every control, once

    func testEveryControlAppearsExactlyOnce() {
        XCTAssertEqual(XInputControl.allCases.count, 17, "the pad has 17 renderable controls")
        XCTAssertEqual(layout.points.count, XInputControl.allCases.count)

        for control in XInputControl.allCases {
            XCTAssertNotNil(layout.point(for: control), "\(control) is missing from the layout")
        }
    }

    func testNoControlIsPlacedTwice() {
        let positions = XInputControl.allCases.map { point($0) }

        // Two controls sharing a point would stack two badges, which reads as a single control.
        for (index, position) in positions.enumerated() {
            let rest = positions[(index + 1)...]
            XCTAssertFalse(
                rest.contains(position),
                "\(XInputControl.allCases[index]) shares its position with another control"
            )
        }
    }

    // MARK: - Inside the picture

    func testEveryPointLiesInsideTheImage() {
        for control in XInputControl.allCases {
            let position = point(control)
            XCTAssertTrue(
                (0.0...1.0).contains(position.horizontal),
                "\(control) horizontal=\(position.horizontal) is outside 0...1"
            )
            XCTAssertTrue(
                (0.0...1.0).contains(position.vertical),
                "\(control) vertical=\(position.vertical) is outside 0...1"
            )
        }
    }

    func testTheEightExtremesStayAwayFromTheEdges() {
        let margin = 0.05
        let xs = XInputControl.allCases.map { point($0).horizontal }
        let ys = XInputControl.allCases.map { point($0).vertical }

        // Leftmost, rightmost, topmost and bottommost control, each on both of its axes.
        for control in XInputControl.allCases {
            let position = point(control)
            if position.horizontal == xs.min() || position.horizontal == xs.max() {
                XCTAssertGreaterThanOrEqual(position.horizontal, margin, "\(control) touches the left/right edge")
                XCTAssertLessThanOrEqual(position.horizontal, 1 - margin, "\(control) touches the left/right edge")
            }
            if position.vertical == ys.min() || position.vertical == ys.max() {
                XCTAssertGreaterThanOrEqual(position.vertical, margin, "\(control) touches the top/bottom edge")
                XCTAssertLessThanOrEqual(position.vertical, 1 - margin, "\(control) touches the top/bottom edge")
            }
        }

        // The artwork has a transparent border of its own; a badge there would float outside the pad.
        XCTAssertGreaterThanOrEqual(xs.min() ?? 0, margin)
        XCTAssertLessThanOrEqual(xs.max() ?? 1, 1 - margin)
        XCTAssertGreaterThanOrEqual(ys.min() ?? 0, margin)
        XCTAssertLessThanOrEqual(ys.max() ?? 1, 1 - margin)
    }

    // MARK: - The sides of the pad

    func testFaceButtonsSitRightOfTheSticksAndTheDpadLeftOfThem() {
        let sticksMidpoint = (point(.leftThumb).horizontal + point(.rightThumb).horizontal) / 2
        let faceButtons = [XInputControl.buttonA, .buttonB, .buttonX, .buttonY]
        let dpad = [XInputControl.dpadUp, .dpadDown, .dpadLeft, .dpadRight]

        for control in faceButtons {
            XCTAssertGreaterThan(
                point(control).horizontal,
                sticksMidpoint,
                "\(control) is part of the face-button cluster and must sit right of the sticks"
            )
        }
        for control in dpad {
            XCTAssertLessThan(
                point(control).horizontal,
                sticksMidpoint,
                "\(control) is part of the d-pad and must sit left of the sticks"
            )
        }

        // The clusters as a whole, not just their members: this is the picture a reader checks.
        let faceCentroid = faceButtons.map { point($0).horizontal }.reduce(0, +) / Double(faceButtons.count)
        let dpadCentroid = dpad.map { point($0).horizontal }.reduce(0, +) / Double(dpad.count)
        XCTAssertGreaterThan(faceCentroid, sticksMidpoint)
        XCTAssertLessThan(dpadCentroid, sticksMidpoint)
    }

    func testShareIsLeftOfOptionsAndTheDpadLeftOfTheFaceButtons() {
        XCTAssertLessThan(point(.back).horizontal, point(.start).horizontal, "Share sits left of Options")
        XCTAssertLessThan(point(.dpadRight).horizontal, point(.buttonX).horizontal, "the d-pad is left of the face cluster")
        XCTAssertLessThan(point(.buttonY).vertical, point(.buttonX).vertical, "triangle sits above square")
        XCTAssertGreaterThan(point(.buttonA).vertical, point(.buttonX).vertical, "cross sits below square")
        XCTAssertGreaterThan(point(.buttonB).horizontal, point(.buttonX).horizontal, "circle sits right of square")
    }

    func testSticksSitBelowTheButtonsAndTheSeamsStaySymmetric() {
        XCTAssertGreaterThan(point(.leftThumb).vertical, point(.dpadUp).vertical)
        XCTAssertGreaterThan(point(.rightThumb).vertical, point(.buttonY).vertical)
        XCTAssertLessThan(point(.leftThumb).horizontal, point(.rightThumb).horizontal)
        XCTAssertEqual(point(.leftThumb).vertical, point(.rightThumb).vertical, accuracy: 0.002)
        XCTAssertEqual(point(.leftTrigger).vertical, point(.rightTrigger).vertical, accuracy: 0.002)
        XCTAssertEqual(point(.leftBumper).vertical, point(.rightBumper).vertical, accuracy: 0.002)
    }

    // MARK: - Distinguishable at the size the view uses

    func testNoTwoControlsAreCloserThanTheBadgeSeparation() {
        for (index, control) in XInputControl.allCases.enumerated() {
            for other in XInputControl.allCases[(index + 1)...] {
                guard let separation = layout.separation(between: control, and: other) else {
                    return XCTFail("\(control) or \(other) has no position")
                }
                XCTAssertGreaterThanOrEqual(
                    separation,
                    PadLayout.minimumBadgeSeparation,
                    "\(control) and \(other) are \(separation) apart, too close to tell apart"
                )
            }
        }
    }

    func testTheShoulderPairIsTheTightestGapAndStillClearsTheThreshold() {
        let shoulderGap = layout.separation(between: .leftBumper, and: .leftTrigger)

        XCTAssertNotNil(shoulderGap)
        // Documented expectation: the trigger arc sits right under the shoulder cap.
        XCTAssertLessThan(shoulderGap ?? 1, 0.05, "L1 and L2 have to stay in the same corner")
        XCTAssertGreaterThanOrEqual(shoulderGap ?? 0, PadLayout.minimumBadgeSeparation)
    }

    // MARK: - Pinned measurements

    func testMeasuredValuesAreUnchanged() {
        // Measured from the artwork (see the derivation in PadLayout.swift). Changing a value has to
        // be a deliberate, re-measured edit: these four pin the corners and the centre of the pad.
        assert(point(.dpadLeft), expectedX: 0.1740, expectedY: 0.4297)
        assert(point(.buttonB), expectedX: 0.8484, expectedY: 0.4299)
        assert(point(.leftTrigger), expectedX: 0.2305, expectedY: 0.1187)
        // The labelled artwork prints the PS logo, which the drawing before it did not, so this is the
        // one row that had to move when the file was replaced.
        assert(point(.guide), expectedX: 0.5022, expectedY: 0.6072)

        // Two more, so the vertical extent of the drawing is covered as well.
        assert(point(.leftBumper), expectedX: 0.2253, expectedY: 0.1692)
        assert(point(.leftThumb), expectedX: 0.3594, expectedY: 0.6259)
    }

    func testTheArtworkSizeMatchesTheFile() {
        XCTAssertEqual(PadLayout.imageWidth, 1452)
        XCTAssertEqual(PadLayout.imageHeight, 940)
        XCTAssertEqual(PadLayout.aspectRatio, 1452.0 / 940.0, accuracy: 0.000001)
    }

    private func assert(
        _ position: PadLayout.Point,
        expectedX: Double,
        expectedY: Double,
        accuracy: Double = 0.001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            position.horizontal,
            expectedX,
            accuracy: accuracy,
            "horizontal moved",
            file: file,
            line: line
        )
        XCTAssertEqual(
            position.vertical,
            expectedY,
            accuracy: accuracy,
            "vertical moved",
            file: file,
            line: line
        )
    }
}
