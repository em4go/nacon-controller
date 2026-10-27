import XCTest

@testable import NaconCore

/// S12: Guide toggles the emulation, and the one direction that can go wrong is the start.
///
/// Stopping is always safe: it releases everything. Starting injects events, so doing it without the
/// Accessibility permission would look exactly like the app ignoring the pad. That rule lives here so
/// it can be checked without a window or a system permission.
final class GuideToggleTests: XCTestCase {
    func testStartingFromThePadNeedsTheAccessibilityPermission() {
        XCTAssertFalse(GuideToggle.canStartFromPad(hasAccessibility: false))
    }

    func testWithThePermissionAGuidePressMayStartTheEmulation() {
        XCTAssertTrue(GuideToggle.canStartFromPad(hasAccessibility: true))
    }
}
