import XCTest

@testable import NaconCore

final class InputProfileCodingTests: XCTestCase {
    private func roundTrip(_ profile: InputProfile) throws -> InputProfile {
        let data = try JSONEncoder().encode(profile)
        return try JSONDecoder().decode(InputProfile.self, from: data)
    }

    func testEveryMappedActionKindSurvivesJSONRoundTrip() throws {
        let actions: [MappedAction] = [
            .none,
            .key(KeyCombo(keyCode: 12)),
            .key(KeyCombo(keyCode: 12, modifiers: [.command, .option])),
            .mouseButton(.left),
            .mouseButton(.right),
            .mouseButton(.middle),
            .scrollLines(3),
            .scrollLines(-7),
        ]

        for action in actions {
            let profile = InputProfile(mappings: [.buttonA: action])
            XCTAssertEqual(try roundTrip(profile), profile, "round trip changed \(action)")
        }
    }

    func testEveryModifierCombinationSurvivesJSONRoundTrip() throws {
        for rawValue in UInt8(0)...UInt8(15) {
            let combo = KeyCombo(keyCode: 40, modifiers: ModifierSet(rawValue: rawValue))
            let profile = InputProfile(mappings: [.buttonB: .key(combo)])
            XCTAssertEqual(try roundTrip(profile).action(for: .buttonB), .key(combo))
        }
    }

    func testRoundTripPreservesCursorSettings() throws {
        let cursor = CursorSettings(
            deadzone: 0.31,
            fullSpeedFraction: 0.7,
            maxSpeed: 900,
            curveExponent: 2.5,
            scrollLinesPerSecond: 9,
            invertVerticalAxis: true
        )
        let profile = InputProfile(mappings: InputProfile.standard.mappings, cursor: cursor)

        XCTAssertEqual(try roundTrip(profile).cursor, cursor)
    }

    func testRoundTripPreservesKeyRepeatSettings() throws {
        let keyRepeat = KeyRepeatSettings(initialDelay: 0.6, interval: 0.02)
        let profile = InputProfile(mappings: InputProfile.standard.mappings, keyRepeat: keyRepeat)

        XCTAssertEqual(try roundTrip(profile).keyRepeat, keyRepeat)
    }

    func testRoundTripPreservesTheWholeStandardProfile() throws {
        let profile = InputProfile.standard
        XCTAssertEqual(try roundTrip(profile), profile)
    }

    func testMappingsEncodeAsAJSONObjectKeyedByControlName() throws {
        let profile = InputProfile(mappings: [.buttonA: .mouseButton(.left), .dpadUp: .none])
        let data = try JSONEncoder().encode(profile)

        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let mappings = try XCTUnwrap(root["mappings"] as? [String: Any])

        // Keys are strings derived from the control, never from its ordinal position.
        XCTAssertEqual(Set(mappings.keys), ["buttonA", "dpadUp"])
    }

    func testEncodingIsStableRegardlessOfDictionaryInsertionOrder() throws {
        let first = InputProfile(mappings: [
            .buttonA: .mouseButton(.left),
            .buttonB: .key(KeyCombo(keyCode: 0)),
            .start: .scrollLines(2),
        ])
        let second = InputProfile(mappings: [
            .start: .scrollLines(2),
            .buttonB: .key(KeyCombo(keyCode: 0)),
            .buttonA: .mouseButton(.left),
        ])

        // Encode through the library, which is the encoder that actually reaches the disk.
        let libraryA = try library(holding: first)
        let libraryB = try library(holding: second)

        XCTAssertEqual(try libraryA.encoded(), try libraryB.encoded())
        XCTAssertEqual(try libraryA.encoded(), try libraryA.encoded())
    }

    /// Same profile wrapped in a library with a fixed identifier, so bytes are comparable.
    private func library(holding profile: InputProfile) throws -> ProfileLibrary {
        let id = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        return ProfileLibrary(
            profiles: [StoredProfile(id: id, name: "Stable", profile: profile)],
            selectedProfileID: id
        )
    }

    func testUnknownControlNameInFileIsIgnored() throws {
        let json = """
        {"mappings":{"buttonA":{"kind":"none"},"turboButton":{"kind":"none"}}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))

        XCTAssertEqual(profile.mappings.count, 1)
        XCTAssertEqual(profile.action(for: .buttonA), .none)
        XCTAssertEqual(profile.cursor, .standard)
        XCTAssertEqual(profile.keyRepeat, .standard)
    }

    func testUnknownActionKindDecodesAsNoAction() throws {
        let json = """
        {"mappings":{"buttonA":{"kind":"macro","steps":["a","b"]}}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))

        XCTAssertEqual(profile.action(for: .buttonA), .none)
    }
}
