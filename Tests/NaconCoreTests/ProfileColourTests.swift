import XCTest

@testable import NaconCore

/// The colour is the profile's only visible mark, so two things matter and are tested here: that each colour
/// drives a different LED pattern, and that a profile written before colours existed still opens in the colour
/// the app has always shown.
final class ProfileColourTests: XCTestCase {
    func testEveryColourDrivesADifferentPattern() {
        let patterns = ProfileColour.allCases.map(\.pattern)
        XCTAssertEqual(Set(patterns).count, ProfileColour.allCases.count, "two colours sharing a pattern")
    }

    func testTheColoursMatchWhatTheHardwareShowed() {
        // Measured on the unit by walking every pattern with a probe: these four, in this order.
        XCTAssertEqual(ProfileColour.blue.pattern, .player1)
        XCTAssertEqual(ProfileColour.red.pattern, .player2)
        XCTAssertEqual(ProfileColour.green.pattern, .player3)
        XCTAssertEqual(ProfileColour.purple.pattern, .player4)
    }

    func testEveryColourHasANameForTheWindow() {
        for colour in ProfileColour.allCases {
            XCTAssertFalse(colour.label.isEmpty, "\(colour) has no label")
        }
    }

    func testAProfileWithoutAColourOpensBlue() throws {
        let json = """
        {"mappings":{}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.color, .standard)
        XCTAssertEqual(profile.color, .blue)
    }

    func testTheColourSurvivesASaveAndLoad() throws {
        let profile = InputProfile(mappings: [.buttonA: .mouseButton(.left)], color: .purple)
        let data = try JSONEncoder().encode(profile)
        let loaded = try JSONDecoder().decode(InputProfile.self, from: data)
        XCTAssertEqual(loaded.color, .purple)
    }

    func testAProfileThatStaysBlueWritesNoColourAtAll() throws {
        // The file of an existing user must not change just because the field exists.
        let data = try JSONEncoder().encode(InputProfile(mappings: [:], color: .blue))
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("color"), "a blue profile wrote a colour: \(text)")
    }
}
