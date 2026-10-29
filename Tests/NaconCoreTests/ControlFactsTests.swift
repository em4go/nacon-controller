import XCTest

@testable import NaconCore

/// S2, S5: every fact the app knows about one control, answered by one lookup.
///
/// The expectations are written down here on purpose. They are the values the old per-control tables
/// held — the stored key, the label, the colour and the pointer radius — so this suite is what proves
/// the move changed nothing, and a rename or a re-tint has to be a deliberate edit in two places
/// instead of slipping through a refactor.
final class ControlFactsTests: XCTestCase {
    /// The keys the persisted format uses. Renaming one rewrites every `profiles.json`, so the set is
    /// written down rather than derived from the code under test (S3).
    private let profileKeys: [XInputControl: String] = [
        .dpadUp: "dpadUp",
        .dpadDown: "dpadDown",
        .dpadLeft: "dpadLeft",
        .dpadRight: "dpadRight",
        .buttonA: "buttonA",
        .buttonB: "buttonB",
        .buttonX: "buttonX",
        .buttonY: "buttonY",
        .leftBumper: "leftBumper",
        .rightBumper: "rightBumper",
        .leftTrigger: "leftTrigger",
        .rightTrigger: "rightTrigger",
        .back: "back",
        .start: "start",
        .guide: "guide",
        .leftThumb: "leftThumb",
        .rightThumb: "rightThumb",
    ]

    /// The English base, which is the catalog key. Four controls name a shape, so they differ.
    private let englishLabels: [XInputControl: String] = [
        .dpadUp: "D-pad ↑", .dpadDown: "D-pad ↓", .dpadLeft: "D-pad ←", .dpadRight: "D-pad →",
        .buttonA: "✕ Cross", .buttonB: "○ Circle", .buttonX: "□ Square", .buttonY: "△ Triangle",
    ]

    /// The Spanish translation the editor prints today.
    private let labels: [XInputControl: String] = [
        .dpadUp: "Cruceta ↑",
        .dpadDown: "Cruceta ↓",
        .dpadLeft: "Cruceta ←",
        .dpadRight: "Cruceta →",
        .buttonA: "✕ Cruz",
        .buttonB: "○ Círculo",
        .buttonX: "□ Cuadrado",
        .buttonY: "△ Triángulo",
        .leftBumper: "L1",
        .rightBumper: "R1",
        .leftTrigger: "L2",
        .rightTrigger: "R2",
        .back: "Share",
        .start: "Options",
        .guide: "PS",
        .leftThumb: "L3",
        .rightThumb: "R3",
    ]

    /// Radii in pixels of the artwork the drawing is cut from.
    private let hitRadii: [XInputControl: Double] = {
        var radii: [XInputControl: Double] = [:]
        for control in [XInputControl.buttonA, .buttonB, .buttonX, .buttonY] {
            radii[control] = 46
        }
        for control in [XInputControl.dpadUp, .dpadDown, .dpadLeft, .dpadRight] {
            radii[control] = 42
        }
        for control in [XInputControl.leftThumb, .rightThumb] {
            radii[control] = 62
        }
        radii[.guide] = 40
        for control in [XInputControl.leftBumper, .rightBumper, .leftTrigger, .rightTrigger] {
            radii[control] = 60
        }
        for control in [XInputControl.back, .start] {
            radii[control] = 34
        }
        return radii
    }()

    // MARK: - One answer for every case (S5)

    func testEveryCaseAnswersWithFacts() {
        for control in XInputControl.allCases {
            let facts = ControlFacts.of(control)

            XCTAssertFalse(facts.profileKey.isEmpty, "\(control) has no stored key")
            XCTAssertFalse(Localization.resolve(facts.label).isEmpty, "\(control) has no label")
            XCTAssertGreaterThan(facts.hitRadius, 0, "\(control) has no pointer radius")
        }
    }

    func testTheLookupIsTheSameValueEveryTime() {
        for control in XInputControl.allCases {
            XCTAssertEqual(ControlFacts.of(control), ControlFacts.of(control))
        }
    }

    // MARK: - Stored key (S3)

    func testProfileKeysMatchThePersistedFormat() {
        for control in XInputControl.allCases {
            XCTAssertEqual(
                ControlFacts.of(control).profileKey,
                profileKeys[control],
                "\(control) writes a different key into profiles.json"
            )
        }
        XCTAssertEqual(profileKeys.count, XInputControl.allCases.count, "a control is missing a key")
    }

    func testProfileKeysAreUniqueAndNonEmpty() {
        let keys = XInputControl.allCases.map { ControlFacts.of($0).profileKey }

        XCTAssertEqual(Set(keys).count, keys.count, "two controls share a stored key")
        XCTAssertFalse(keys.contains(where: \.isEmpty))
    }

    // MARK: - Labels

    func testLabelsFollowTheLanguage() {
        let english = Locale(identifier: "en")
        let spanish = Locale(identifier: "es")
        for control in XInputControl.allCases {
            let label = ControlFacts.of(control).label
            XCTAssertEqual(
                Localization.resolve(label, locale: english),
                englishLabels[control] ?? labels[control],
                "\(control) reads differently in English"
            )
            XCTAssertEqual(
                Localization.resolve(label, locale: spanish),
                labels[control],
                "\(control) reads differently in Spanish"
            )
        }
    }

    // MARK: - Pointer radius

    func testHitRadiiMatchTheDrawing() {
        for control in XInputControl.allCases {
            XCTAssertEqual(
                ControlFacts.of(control).hitRadius,
                hitRadii[control],
                "\(control) answers a different pointer radius"
            )
        }
        XCTAssertTrue(XInputControl.allCases.allSatisfy { ControlFacts.of($0).hitRadius > 0 })
    }

    // MARK: - Colour

    func testOnlyTheEightControlsWithAColourOfTheirOwnAreColoured() {
        let expected: [XInputControl: ControlTint] = [
            .dpadUp: ControlTint(red: 0.184, green: 0.749, blue: 0.427),
            .dpadDown: ControlTint(red: 0.604, green: 0.361, blue: 1.000),
            .dpadLeft: ControlTint(red: 0.145, green: 0.780, blue: 0.851),
            .dpadRight: ControlTint(red: 0.961, green: 0.651, blue: 0.137),
            .buttonA: ControlTint(red: 0.239, green: 0.435, blue: 0.878),
            .buttonB: ControlTint(red: 0.886, green: 0.231, blue: 0.231),
            .buttonX: ControlTint(red: 0.878, green: 0.439, blue: 0.722),
            .buttonY: ControlTint(red: 0.043, green: 0.478, blue: 0.220),
        ]

        for control in XInputControl.allCases {
            XCTAssertEqual(
                ControlFacts.of(control).tint,
                expected[control],
                "\(control) \(expected[control] == nil ? "should not" : "should") carry its own colour"
            )
        }
        XCTAssertEqual(expected.count, 8, "the coloured set is the four directions and the four buttons")
    }

    func testTheEightColoursAreDistinct() {
        let packed = XInputControl.allCases.compactMap { ControlFacts.of($0).tint?.packed }

        XCTAssertEqual(packed.count, 8)
        XCTAssertEqual(Set(packed).count, packed.count, "two controls share a colour")
    }

    /// S6: the drawing resolves each mask by the control's stored key, and nothing in the compiler
    /// connects the two: `prototype/tools/make-masks.py` writes the PNGs and the bundle is only read
    /// at runtime. The files on disk are pinned here, so renaming an asset or adding a control
    /// without its mask fails the suite instead of leaving a control silently untinted.
    func testEveryControlHasItsMaskFile() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let masks = repositoryRoot.appending(path: "Sources/NaconDiagnostics/Resources/masks")

        let shipped = try FileManager.default
            .contentsOfDirectory(atPath: masks.path)
            .filter { $0.hasSuffix(".png") }
        let expected = XInputControl.allCases.map {
            "diagram-\(ControlFacts.of($0).profileKey).png"
        }

        XCTAssertEqual(Set(shipped), Set(expected))
    }
}
