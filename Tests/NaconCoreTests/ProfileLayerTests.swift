import XCTest

@testable import NaconCore

final class ProfileLayerTests: XCTestCase {
    private func layeredProfile() -> InputProfile {
        InputProfile(
            mappings: [.buttonA: .mouseButton(.left), .buttonB: .mouseButton(.right)],
            layer: ProfileLayer(
                key: .leftBumper,
                mappings: [.buttonA: .key(KeyCombo(.tab))]
            )
        )
    }

    // MARK: - Resolution

    func testTheLayerActionWinsOnlyWhileTheLayerIsActive() {
        // S2: the layer is a second reading of the same controls, so the same press means two
        // different things depending on whether the selector is held.
        let profile = layeredProfile()

        XCTAssertEqual(profile.action(for: .buttonA, layerActive: true), .key(KeyCombo(.tab)))
        XCTAssertEqual(profile.action(for: .buttonA, layerActive: false), .mouseButton(.left))
        XCTAssertEqual(profile.action(for: .buttonA), .mouseButton(.left), "base-only callers keep the base")
    }

    func testAControlMissingFromTheLayerUsesTheBaseAction() {
        // S2: MOD only changes what it redefines; everything else keeps working while it is held.
        let profile = layeredProfile()

        XCTAssertNil(profile.layer.action(for: .buttonB))
        XCTAssertEqual(profile.action(for: .buttonB, layerActive: true), .mouseButton(.right))
    }

    func testAControlTheBaseLeavesUnassignedStillFallsBackToNoAction() {
        let profile = InputProfile(
            mappings: [:],
            layer: ProfileLayer(key: .leftBumper, mappings: [.buttonA: .key(KeyCombo(.tab))])
        )

        XCTAssertEqual(profile.action(for: .buttonB, layerActive: true), .none)
        XCTAssertEqual(profile.action(for: .buttonA, layerActive: true), .key(KeyCombo(.tab)))
    }

    func testLayerActionIsNilWhenTheLayerHasNoEntry() {
        // The nil is the contract that makes the fallback possible: an empty entry would read as
        // "this control does nothing in the layer" instead of "ask the base".
        let layer = ProfileLayer(key: .leftBumper, mappings: [.buttonA: .key(KeyCombo(.tab))])

        XCTAssertEqual(layer.action(for: .buttonA), .key(KeyCombo(.tab)))
        XCTAssertNil(layer.action(for: .buttonB))
    }

    func testLayerIsActiveOnlyWithAKey() {
        XCTAssertTrue(ProfileLayer(key: .rightBumper).isActive)
        XCTAssertFalse(ProfileLayer(mappings: [.buttonA: .key(KeyCombo(.tab))]).isActive)
        XCTAssertFalse(ProfileLayer.empty.isActive)
    }

    func testLayerIsEmptyOnlyWithoutKeyAndMappings() {
        XCTAssertTrue(ProfileLayer.empty.isEmpty)
        XCTAssertTrue(ProfileLayer().isEmpty)
        XCTAssertFalse(ProfileLayer(key: .leftBumper).isEmpty, "a key alone already changes what the pad does")
        XCTAssertFalse(ProfileLayer(mappings: [.buttonA: .key(KeyCombo(.tab))]).isEmpty)
    }

    // MARK: - Eligibility (S5)

    func testIsLayerKeyEligibleRefusesTheReservedControlAndAcceptsTheOthers() {
        // S5: PS is the emergency stop. As a selector it would be spendable in the layer instead of
        // stopping the emulation, which is the one thing that must always work.
        XCTAssertFalse(MappingRules.isLayerKeyEligible(.guide))

        for control in XInputControl.allCases where control != .guide {
            XCTAssertTrue(MappingRules.isLayerKeyEligible(control), "\(control)")
        }
    }

    // MARK: - Persistence (S6)

    private func roundTrip(_ profile: InputProfile) throws -> InputProfile {
        let decoder = JSONDecoder()
        return try decoder.decode(InputProfile.self, from: try JSONEncoder().encode(profile))
    }

    func testLayerSurvivesJSONRoundTrip() throws {
        let profile = layeredProfile()

        XCTAssertEqual(try roundTrip(profile).layer, profile.layer)
        XCTAssertEqual(try roundTrip(profile).action(for: .buttonA, layerActive: true), .key(KeyCombo(.tab)))
    }

    func testAProfileWithoutALayerEncodesWithoutTheLayerKey() throws {
        // S6: a profile saved before the layer existed keeps the bytes it had, so nothing on disk
        // changes until the user actually builds a layer.
        let data = try JSONEncoder().encode(InputProfile(mappings: [.buttonA: .mouseButton(.left)]))
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(root["layer"])
    }

    func testADocumentWithoutTheLayerKeyDecodesToAnEmptyLayer() throws {
        // S6: every profile already on disk is one of these.
        let json = """
        {"mappings":{"buttonA":{"kind":"mouseButton","button":"left"}}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))

        XCTAssertEqual(profile.layer, .empty)
        XCTAssertFalse(profile.layer.isActive)
        XCTAssertEqual(profile.action(for: .buttonA, layerActive: true), .mouseButton(.left))
    }

    func testLayerMappingsEncodeAsAJSONObjectKeyedByControlName() throws {
        let data = try JSONEncoder().encode(layeredProfile())
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let layer = try XCTUnwrap(root["layer"] as? [String: Any])
        let mappings = try XCTUnwrap(layer["mappings"] as? [String: Any])

        XCTAssertEqual(layer["key"] as? String, "leftBumper")
        XCTAssertEqual(Set(mappings.keys), ["buttonA"], "the layer must not duplicate the base entries")
    }

    func testALayerKeyThatIsNotEligibleIsDroppedWhenDecoding() throws {
        // Same invariant as the Guide mapping: a hand-edited or foreign file must not be able to
        // spend the emergency stop on something else (S5).
        let json = """
        {"mappings":{"buttonA":{"kind":"mouseButton","button":"left"}},\
        "layer":{"key":"guide","mappings":{"buttonB":{"kind":"key","key":{"keyCode":48,"modifiers":0}}}}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))

        XCTAssertNil(profile.layer.key, "PS must never become the layer selector")
        XCTAssertFalse(profile.layer.isActive, "without a key the layer can never open")
        XCTAssertEqual(profile.action(for: .buttonB), .none, "so its entries never apply to the base")
    }
}
