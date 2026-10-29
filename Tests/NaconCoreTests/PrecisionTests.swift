import XCTest

@testable import NaconCore

/// The control that slows the pointer, from the setting to the pointer itself.
final class PrecisionTests: XCTestCase {
    private let stick = XInputStick(rawX: 32_767, rawY: 0)

    private func movement(_ effects: [PerformanceEffect]) -> Double {
        effects.reduce(0) { total, effect in
            guard case .moveCursor(let deltaX, _) = effect else { return total }
            return total + deltaX
        }
    }

    private func scrolled(_ effects: [PerformanceEffect]) -> Int {
        effects.reduce(0) { total, effect in
            guard case .scroll(let pixels) = effect else { return total }
            return total + abs(pixels)
        }
    }

    func testTheFactorIsOneWithoutAKey() {
        // A profile with no precision control must move at exactly the speed it always did: a factor
        // that leaked into the normal path would slow the whole app down.
        XCTAssertEqual(PrecisionSettings.off.factor, 1)
        XCTAssertFalse(PrecisionSettings.off.isActive)
    }

    func testTheScaleIsKeptInsideItsRange() {
        XCTAssertEqual(PrecisionSettings(key: .leftBumper, scale: 0.001).scale, PrecisionSettings.minimumScale)
        XCTAssertEqual(PrecisionSettings(key: .leftBumper, scale: 9).scale, PrecisionSettings.maximumScale)
    }

    func testHoldingTheKeySlowsThePointerAndTheScroll() {
        // Both, with the same factor: slowing the pointer but not the wheel would make the two disagree
        // while the same control is held.
        let profile = InputProfile(
            mappings: [:],
            precision: PrecisionSettings(key: .leftThumb, scale: 0.5)
        )
        let rightStick = XInputStick(rawX: 0, rawY: -32_767)

        var normal = PadPerformance(profile: profile)
        let normalEffects = normal.advance(seconds: 0.5, leftStick: stick, rightStick: rightStick)

        var slow = PadPerformance(profile: profile)
        let slowEffects = slow.advance(
            seconds: 0.5,
            leftStick: stick,
            rightStick: rightStick,
            precisionActive: true
        )

        XCTAssertGreaterThan(movement(normalEffects), 0, "the test needs a stick that actually moves")
        XCTAssertEqual(movement(slowEffects), movement(normalEffects) * 0.5, accuracy: 0.001)
        XCTAssertLessThan(scrolled(slowEffects), scrolled(normalEffects))
    }

    func testThePrecisionControlEmitsNothing() {
        // It is a selector, like the MOD key: pressing it must not send a keystroke or a click.
        let emitter = RecordingEmitter()
        let engine = EmulationEngine(
            emitter: emitter,
            profile: InputProfile(
                mappings: [.leftThumb: .key(KeyCombo(.escape))],
                precision: PrecisionSettings(key: .leftThumb, scale: 0.5)
            )
        )
        engine.setEnabledNow(true)
        engine.handle(Self.report(buttons: []))
        engine.handle(Self.report(buttons: [.leftThumb]))

        XCTAssertEqual(emitter.events, [])
    }

    func testTheProfileCarriesTheSetting() throws {
        let profile = InputProfile(
            mappings: [:],
            precision: PrecisionSettings(key: .leftBumper, scale: 0.25)
        )
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(InputProfile.self, from: data)

        XCTAssertEqual(decoded.precision.key, .leftBumper)
        XCTAssertEqual(decoded.precision.scale, 0.25, accuracy: 0.0001)
    }

    func testAProfileWithoutTheSettingOpensWithItOff() throws {
        let json = """
        {"mappings":{"buttonA":{"kind":"mouseButton","button":"left"}}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))

        XCTAssertEqual(profile.precision, .off)
    }

    func testAFileCannotMakePsTheSlowKey() throws {
        // The same invariant the base mapping and the layer hold, in the model.
        let json = """
        {"mappings":{},"precision":{"key":"guide","scale":0.5}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))

        XCTAssertNil(profile.precision.key)
    }

    func testTheLibraryRefusesAPrecisionKeyThatIsTheModKey() throws {
        var profile = StoredProfile(name: "Prueba", profile: InputProfile(mappings: [:]))
        profile.profile.layer.key = .leftThumb
        var library = ProfileLibrary(profiles: [profile], selectedProfileID: profile.id)

        XCTAssertFalse(library.setPrecisionKey(.leftThumb, for: profile.id))
        XCTAssertTrue(library.setPrecisionKey(.rightThumb, for: profile.id))
        XCTAssertEqual(library.selectedProfile?.profile.precision.key, XInputControl.rightThumb)
    }

    func testTheLibraryClampsTheFactorAndRefusesPS() throws {
        var profile = StoredProfile(name: "Prueba", profile: InputProfile(mappings: [:]))
        profile.profile.precision.key = .leftBumper
        var library = ProfileLibrary(profiles: [profile], selectedProfileID: profile.id)

        XCTAssertFalse(library.setPrecisionKey(.guide, for: profile.id))
        XCTAssertTrue(library.setPrecisionScale(0.0001, for: profile.id))
        XCTAssertEqual(
            library.selectedProfile?.profile.precision.scale,
            PrecisionSettings.minimumScale
        )
    }

    private static func report(buttons: XInputButtons) -> XInputReport {
        XInputReport(
            rawBytes: [],
            buttons: buttons,
            leftTrigger: 0,
            rightTrigger: 0,
            leftStick: .center,
            rightStick: .center
        )
    }
}
