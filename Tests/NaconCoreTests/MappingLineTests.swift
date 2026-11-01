import XCTest
@testable import NaconCore

/// What one control sends, asked through the module's own interface.
///
/// The three surfaces print this line and used to derive it each in its own way; these cases pin the
/// derivation they now share, including the two conditions that keep the MOD part off a line where the
/// layer redefines nothing. The language is pinned per case and restored after, because the reserved
/// sentence and the composed pattern are catalog text.
final class MappingLineTests: XCTestCase {
    /// A control mapped in the base and redefined by the layer.
    private static let redefined: XInputControl = .buttonA
    /// A control mapped in the base that the layer leaves alone.
    private static let untouched: XInputControl = .buttonB
    /// A control that sends nothing at all.
    private static let unmapped: XInputControl = .buttonX

    /// A profile whose layer has a key and redefines exactly one control.
    private var layered: InputProfile {
        InputProfile(
            mappings: [
                Self.redefined: .mouseButton(.left),
                Self.untouched: .mouseButton(.right),
            ],
            layer: ProfileLayer(
                key: .leftThumb,
                mappings: [Self.redefined: .mouseButton(.right)]
            )
        )
    }

    /// The same mappings with no MOD key, so the layer can never open.
    private var unlayered: InputProfile {
        InputProfile(mappings: [
            Self.redefined: .mouseButton(.left),
            Self.untouched: .mouseButton(.right),
        ])
    }

    func testTheReservedSentenceIsTheShortOneInBothLanguages() {
        let previous = Localization.language
        defer { Localization.language = previous }

        Localization.language = .english
        XCTAssertEqual(MappingLine.reserved, "Reserved: turns emulation on and off")

        Localization.language = .spanish
        XCTAssertEqual(MappingLine.reserved, "Reservado: activa y apaga la emulación")
    }

    func testTheReservedControlAnswersTheReservedSentenceInsteadOfAnAssignment() {
        let previous = Localization.language
        defer { Localization.language = previous }

        Localization.language = .english
        let reserved = MappingRules.reservedControl

        XCTAssertEqual(MappingLine.base(for: reserved, in: layered), MappingLine.reserved)
        XCTAssertNil(MappingLine.mod(for: reserved, in: layered))
        XCTAssertEqual(MappingLine.line(for: reserved, in: layered), MappingLine.reserved)
    }

    func testTheBaseOfAControlThatSendsNothingIsTheUnassignedLabel() {
        let previous = Localization.language
        defer { Localization.language = previous }

        Localization.language = .english
        XCTAssertEqual(MappingLine.base(for: Self.unmapped, in: layered), "Unassigned")
    }

    func testTheBaseOfAMappedControlIsItsOwnLabel() {
        let previous = Localization.language
        defer { Localization.language = previous }

        Localization.language = .english
        XCTAssertEqual(MappingLine.base(for: Self.redefined, in: layered), "Left click")
    }

    func testTheModOfAProfileWithNoLayerIsNothing() {
        XCTAssertNil(MappingLine.mod(for: Self.redefined, in: unlayered))
    }

    func testTheModOfALayerThatDoesNotRedefineTheControlIsNothing() {
        let previous = Localization.language
        defer { Localization.language = previous }

        Localization.language = .english
        XCTAssertNil(MappingLine.mod(for: Self.untouched, in: layered))
        // The layer leaves this control alone, so the base is the whole line with MOD held.
        XCTAssertEqual(MappingLine.line(for: Self.untouched, in: layered), "Right click")
    }

    func testTheModOfALayerThatRedefinesTheControlIsTheLayeredLabel() {
        let previous = Localization.language
        defer { Localization.language = previous }

        Localization.language = .english
        XCTAssertEqual(MappingLine.mod(for: Self.redefined, in: layered), "Right click")
        XCTAssertEqual(
            MappingLine.line(for: Self.redefined, in: layered),
            "Left click · MOD Right click"
        )
    }

    func testTheComposedLineFollowsTheInterfaceLanguage() {
        let previous = Localization.language
        defer { Localization.language = previous }

        Localization.language = .spanish
        XCTAssertEqual(
            MappingLine.line(for: Self.redefined, in: layered),
            "Clic izquierdo · MOD Clic derecho"
        )
    }
}
