import XCTest

@testable import NaconCore

/// Precision as an ordinary assignment: the action, the claim it makes on the speed, and the file.
///
/// Precision is no longer a setting that names a control. It is one more thing a control can be
/// assigned, so the tests below drive it through the same path a key or a click takes: a mapping, the
/// engine's press and release, and the performance's record of what is held.
final class PrecisionTests: XCTestCase {
    private let stick = XInputStick(rawX: 32_767, rawY: 0)
    private let upwardScroll = XInputStick(rawX: 0, rawY: -32_767)

    private func movement(_ effects: [PerformanceEffect]) -> Double {
        effects.reduce(0) { total, effect in
            guard case .moveCursor(let deltaX, _) = effect else { return total }
            return total + deltaX
        }
    }

    private func scrolled(_ effects: [PerformanceEffect]) -> Int {
        effects.reduce(0) { total, effect in
            guard case .scroll(let pixels) = effect else { return total }
            return total + abs(pixels.y)
        }
    }

    private func cursorMovement(_ emitter: RecordingEmitter) -> Double {
        emitter.events.reduce(0) { total, event in
            guard case .move(let deltaX, _) = event else { return total }
            return total + deltaX
        }
    }

    private func scrolledY(_ emitter: RecordingEmitter) -> Int {
        emitter.scrolledY
    }

    // MARK: - The setting

    func testTheScaleIsKeptInsideItsRange() {
        XCTAssertEqual(PrecisionSettings(scale: 0.001).scale, PrecisionSettings.minimumScale)
        XCTAssertEqual(PrecisionSettings(scale: 9).scale, PrecisionSettings.maximumScale)
    }

    func testTheActionHasALabelForTheMenu() {
        XCTAssertEqual(MappedAction.precision.displayName(in: Locale(identifier: "en")), "Precision (hold)")
    }

    // MARK: - The claim

    func testTheActionMovesNothingByItself() {
        // It is a claim on the speed, not an emission: no key, no click, no wheel event and nothing to
        // repeat, however long it stays down.
        var performance = PadPerformance(
            profile: InputProfile(
                mappings: [.leftThumb: .precision],
                precision: PrecisionSettings(scale: 0.5)
            )
        )

        XCTAssertEqual(performance.press(.leftThumb, action: .precision), [])
        XCTAssertTrue(performance.isPrecisionHeld)
        // Both sticks centred, so the only thing that could produce an effect is the claim itself.
        XCTAssertEqual(performance.advance(seconds: 1, leftStick: .center, rightStick: .center), [])
        XCTAssertEqual(performance.release(.leftThumb), [])
        XCTAssertFalse(performance.isPrecisionHeld)
        XCTAssertEqual(performance.reset(), [])
    }

    func testThePrecisionControlSendsNothingThroughTheEngine() {
        let emitter = RecordingEmitter()
        let engine = EmulationEngine(
            emitter: emitter,
            profile: InputProfile(
                mappings: [.leftThumb: .precision],
                precision: PrecisionSettings(scale: 0.5)
            )
        )
        engine.setEnabledNow(true)
        engine.handle(Self.report(buttons: []))
        engine.handle(Self.report(buttons: [.leftThumb]))
        engine.tick(seconds: 0.25)
        engine.handle(Self.report(buttons: []))
        engine.tick(seconds: 0.25)

        XCTAssertEqual(emitter.events, [])
    }

    func testTheScaleDoesNotLeakIntoTheNormalSpeed() {
        // A profile can carry a scale with no control assigned to precision. The pointer must move at
        // exactly the speed it always did: a factor applied to the normal path would slow every profile.
        var slowByDefault = PadPerformance(
            profile: InputProfile(mappings: [:], precision: PrecisionSettings(scale: 0.2))
        )
        var reference = PadPerformance(
            profile: InputProfile(mappings: [:], precision: PrecisionSettings(scale: 1))
        )

        let effects = slowByDefault.advance(seconds: 0.5, leftStick: stick, rightStick: upwardScroll)
        let referenceEffects = reference.advance(seconds: 0.5, leftStick: stick, rightStick: upwardScroll)

        XCTAssertGreaterThan(movement(effects), 0, "the test needs a stick that actually moves")
        XCTAssertFalse(slowByDefault.isPrecisionHeld)
        XCTAssertEqual(movement(effects), movement(referenceEffects), accuracy: 0.001)
        XCTAssertEqual(scrolled(effects), scrolled(referenceEffects))
    }

    func testHoldingAPrecisionControlSlowsThePointerAndTheScroll() {
        // Both, with the same factor: slowing the pointer but not the wheel would make the two disagree
        // while the same control is held.
        let profile = InputProfile(
            mappings: [.leftThumb: .precision],
            precision: PrecisionSettings(scale: 0.5)
        )

        let fullEmitter = RecordingEmitter()
        let fullEngine = EmulationEngine(emitter: fullEmitter, profile: profile)
        fullEngine.setEnabledNow(true)
        fullEngine.handle(report(buttons: [], left: stick, right: upwardScroll))
        fullEngine.tick(seconds: 0.5)

        let slowEmitter = RecordingEmitter()
        let slowEngine = EmulationEngine(emitter: slowEmitter, profile: profile)
        slowEngine.setEnabledNow(true)
        slowEngine.handle(report(buttons: [], left: stick, right: upwardScroll))
        slowEngine.handle(report(buttons: [.leftThumb], left: stick, right: upwardScroll))
        slowEngine.tick(seconds: 0.5)

        XCTAssertGreaterThan(cursorMovement(fullEmitter), 0, "the test needs a stick that actually moves")
        XCTAssertEqual(cursorMovement(slowEmitter), cursorMovement(fullEmitter) * 0.5, accuracy: 0.001)
        XCTAssertLessThan(scrolledY(slowEmitter), scrolledY(fullEmitter))

        // Letting go restores the full speed on the next slice of time.
        slowEmitter.reset()
        slowEngine.handle(report(buttons: [], left: stick, right: upwardScroll))
        slowEngine.tick(seconds: 0.5)

        XCTAssertEqual(cursorMovement(slowEmitter), cursorMovement(fullEmitter), accuracy: 0.001)
        XCTAssertGreaterThan(scrolledY(slowEmitter), scrolledY(fullEmitter) / 2)
    }

    func testAClickOnAnotherControlStillWorksWhilePrecisionIsHeld() {
        let emitter = RecordingEmitter()
        let engine = EmulationEngine(
            emitter: emitter,
            profile: InputProfile(
                mappings: [.leftThumb: .precision, .buttonA: .mouseButton(.left)],
                precision: PrecisionSettings(scale: 0.5)
            )
        )
        engine.setEnabledNow(true)
        engine.handle(Self.report(buttons: []))
        engine.handle(Self.report(buttons: [.leftThumb]))
        engine.handle(Self.report(buttons: [.leftThumb, .buttonA]))

        XCTAssertEqual(emitter.events, [.press(.mouseButton(.left))])

        engine.handle(Self.report(buttons: [.leftThumb]))

        XCTAssertEqual(emitter.events, [
            .press(.mouseButton(.left)),
            .release(.mouseButton(.left)),
        ])
    }

    // MARK: - The MOD layer

    func testPrecisionHeldThroughTheModLayerOutlivesTheModKey() {
        // Releasing the layer does not swap the action under a button that is still down, which is the
        // rule every other action follows: precision therefore lasts until its own control is released,
        // even though the MOD key is already up. A sudden speed jump mid-movement is worse than a
        // precision that ends a moment later.
        let profile = InputProfile(
            mappings: [.back: .key(KeyCombo(.space))],
            layer: ProfileLayer(key: .rightBumper, mappings: [.back: .precision]),
            precision: PrecisionSettings(scale: 0.5)
        )

        let emitter = RecordingEmitter()
        let engine = EmulationEngine(emitter: emitter, profile: profile)
        engine.setEnabledNow(true)
        engine.handle(report(buttons: [], left: stick))
        engine.tick(seconds: 0.25)
        let fullMovement = cursorMovement(emitter)
        XCTAssertGreaterThan(fullMovement, 0, "the test needs a stick that actually moves")

        // The MOD key opens the layer first, and the control is pressed while it is open: what it
        // claims is the layer's precision, not its base key.
        engine.handle(report(buttons: [.rightBumper], left: stick))
        engine.handle(report(buttons: [.rightBumper, .back], left: stick))
        emitter.reset()
        engine.tick(seconds: 0.25)
        XCTAssertEqual(cursorMovement(emitter), fullMovement * 0.5, accuracy: 0.001)

        // The MOD key goes up and the precision control stays down: the speed does not jump back.
        emitter.reset()
        engine.handle(report(buttons: [.back], left: stick))
        engine.tick(seconds: 0.25)
        XCTAssertEqual(cursorMovement(emitter), fullMovement * 0.5, accuracy: 0.001)

        // Releasing the precision control is what ends it.
        emitter.reset()
        engine.handle(report(buttons: [], left: stick))
        engine.tick(seconds: 0.25)
        XCTAssertEqual(cursorMovement(emitter), fullMovement, accuracy: 0.001)

        // Without the layer, the same control sends its base key and slows nothing: the layer is the
        // reading that claimed precision, not the control.
        emitter.reset()
        engine.handle(report(buttons: [.back], left: stick))
        XCTAssertEqual(emitter.events, [.press(.key(KeyCombo(.space)))])
    }

    // MARK: - The file

    func testAProfileWithoutTheSettingOpensWithTheStandardScale() throws {
        let json = """
        {"mappings":{"buttonA":{"kind":"mouseButton","button":"left"}}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))

        XCTAssertEqual(profile.precision, .standard)
        XCTAssertEqual(profile.action(for: .leftThumb), .none)
    }

    func testTheProfileWritesTheScaleAndNoKey() throws {
        let profile = InputProfile(
            mappings: [.leftThumb: .precision],
            precision: PrecisionSettings(scale: 0.4)
        )
        let data = try JSONEncoder().encode(profile)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let stored = try XCTUnwrap(object["precision"] as? [String: Any])

        XCTAssertNil(stored["key"], "the control belongs to the mapping now, not to the setting")
        XCTAssertEqual(stored["scale"] as? Double, 0.4)

        let decoded = try JSONDecoder().decode(InputProfile.self, from: data)
        XCTAssertEqual(decoded.precision.scale, 0.4, accuracy: 0.0001)
        XCTAssertEqual(decoded.action(for: .leftThumb), .precision)
    }

    func testALegacyPrecisionKeyBecomesAnAssignment() throws {
        // A file from the version that named one control inside the setting still opens with what it
        // said: the scale it stored and the action on that control.
        let json = """
        {"mappings":{"buttonA":{"kind":"mouseButton","button":"left"}},
        "precision":{"key":"leftBumper","scale":0.4}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))

        XCTAssertEqual(profile.action(for: .leftBumper), .precision)
        XCTAssertEqual(profile.precision.scale, 0.4, accuracy: 0.0001)
        // The rest of the file is untouched.
        XCTAssertEqual(profile.action(for: .buttonA), .mouseButton(.left))
    }

    func testALegacyPrecisionKeyNeverOverwritesAnAssignment() throws {
        // Only a control with no mapping of its own takes the action: an assignment the user made is
        // theirs, and the old setting only contributes the scale.
        let json = """
        {"mappings":{"leftBumper":{"kind":"key","key":{"keyCode":48,"modifiers":0}}},
        "precision":{"key":"leftBumper","scale":0.4}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))

        XCTAssertEqual(profile.action(for: .leftBumper), .key(KeyCombo(.tab)))
        XCTAssertEqual(profile.precision.scale, 0.4, accuracy: 0.0001)
    }

    func testAFileCannotGivePsThePrecisionAction() throws {
        // The same invariant the base mapping and the layer hold: PS is the switch, so a hand-edited
        // file cannot turn it into a control that slows the pointer.
        let json = """
        {"mappings":{},"precision":{"key":"guide","scale":0.5}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))

        XCTAssertEqual(profile.action(for: .guide), .none)
        XCTAssertEqual(profile.precision.scale, 0.5, accuracy: 0.0001)
    }

    // MARK: - The library

    func testPrecisionIsAssignableLikeAnyOtherAction() throws {
        let profile = StoredProfile(name: "Prueba", profile: InputProfile(mappings: [:]))
        var library = ProfileLibrary(profiles: [profile], selectedProfileID: profile.id)

        XCTAssertTrue(library.setAction(.precision, for: .leftBumper))
        XCTAssertEqual(library.selectedProfile?.profile.action(for: .leftBumper), .precision)
        // PS stays the switch, here as everywhere else.
        XCTAssertFalse(library.setAction(.precision, for: .guide))
    }

    func testTheLibraryClampsTheFactor() throws {
        let profile = StoredProfile(name: "Prueba", profile: InputProfile(mappings: [:]))
        var library = ProfileLibrary(profiles: [profile], selectedProfileID: profile.id)

        XCTAssertTrue(library.setPrecisionScale(0.0001, for: profile.id))
        XCTAssertEqual(
            library.selectedProfile?.profile.precision.scale,
            PrecisionSettings.minimumScale
        )
        XCTAssertFalse(library.setPrecisionScale(PrecisionSettings.minimumScale, for: profile.id))
    }

    // MARK: - Fixtures

    private func report(
        buttons: XInputButtons,
        left: XInputStick = .center,
        right: XInputStick = .center
    ) -> XInputReport {
        XInputReport(
            rawBytes: [],
            buttons: buttons,
            leftTrigger: 0,
            rightTrigger: 0,
            leftStick: left,
            rightStick: right
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
