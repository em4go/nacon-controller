import Foundation

/// Where every control sits on the DualShock 4 drawing, in normalized image coordinates.
///
/// The graphical view draws the artwork once and lights up the pixels of the control under the
/// pointer on top of it. The positions are part of the model, not of the view, so they can be
/// checked without a window and re-derived by anyone who changes the artwork.
///
/// ## How the table was measured
///
/// The source is `Sources/NaconDiagnostics/Resources/PS4_Controller.png` (1452 x 940, white line
/// drawing over a transparent background): the labelled Xelu diagram, the one that already prints
/// ✕ ○ □ △ and the PS logo. The table was re-measured against that file and every value but
/// `guide` came out the same; the old drawing had no PS button at all, so that one row moved. The
/// measurement is reproducible with the standard library only:
///
/// 1. `sips -s format bmp PS4_Controller.png --out pad.bmp`. `sips` writes a top-down 32-bit BMP
///    with the alpha channel in the fourth byte, so no image library is needed.
/// 2. Threshold the alpha channel at 128 (the drawing is pure white; only its opacity varies) and
///    label the connected components with 8-connectivity.
/// 3. Take the centroid of each component and divide by the image size. The origin is the top-left
///    corner of the image, x to the right, y downwards, both in `0...1`.
///
/// Twenty seven components came out: the body outline, the two shoulder caps merged into it, twelve
/// small shapes and four single-pixel specks (ignored). Each control was then assigned to the shape
/// a user would point at:
///
/// | Control | Shape that was measured |
/// | --- | --- |
/// | `dpadUp/Down/Left/Right` | The four rounded squares of the d-pad cross, one component each |
/// | `buttonA/B/X/Y` | The four empty face-button circles, one component each (drawn empty on purpose) |
/// | `leftBumper` / `rightBumper` | The ellipse in front of each shoulder. L1 is the front button, the one nearest the player, so it is the ellipse and not the dome behind it |
/// | `leftTrigger` / `rightTrigger` | The dome behind the ellipse: that is the trigger, L2 |
/// | `back` / `start` | The two vertical pills beside the touchpad, left (Share) and right (Options) |
/// | `guide` | The PS logo the labelled artwork prints between the two sticks. The earlier drawing printed no such button, so this row was the only one that moved when the artwork was replaced |
/// | `leftThumb` / `rightThumb` | The innermost ring inside each stick well: the stick cup, not the well itself |
///
/// ## The table (normalized)
///
/// | Control | x | y | Pixels |
/// | --- | --- | --- | --- |
/// | `dpadUp` | 0.2205 | 0.3606 | 320.1, 339.0 |
/// | `dpadDown` | 0.2204 | 0.4981 | 320.0, 468.2 |
/// | `dpadLeft` | 0.1740 | 0.4297 | 252.6, 403.9 |
/// | `dpadRight` | 0.2669 | 0.4296 | 387.6, 403.8 |
/// | `buttonA` (✕) | 0.7837 | 0.5224 | 1138.0, 491.0 |
/// | `buttonB` (○) | 0.8484 | 0.4299 | 1231.9, 404.1 |
/// | `buttonX` (□) | 0.7196 | 0.4296 | 1044.8, 403.8 |
/// | `buttonY` (△) | 0.7838 | 0.3373 | 1138.0, 317.1 |
/// | `leftBumper` (L1) | 0.2253 | 0.1692 | 327.2, 159.0 |
/// | `rightBumper` (R1) | 0.7787 | 0.1693 | 1130.7, 159.2 |
/// | `leftTrigger` (L2) | 0.2305 | 0.1187 | 334.7, 111.6 |
/// | `rightTrigger` (R2) | 0.7730 | 0.1189 | 1122.4, 111.8 |
/// | `back` (Share) | 0.3172 | 0.2941 | 460.6, 276.5 |
/// | `start` (Options) | 0.6857 | 0.2941 | 995.6, 276.5 |
/// | `guide` (PS) | 0.5022 | 0.6072 | 729.2, 571.0 |
/// | `leftThumb` (L3) | 0.3594 | 0.6259 | 521.9, 588.3 |
/// | `rightThumb` (R3) | 0.6445 | 0.6259 | 935.9, 588.3 |
public struct PadLayout: Equatable, Sendable {
    /// A point in the drawing, normalized to `0...1` with the origin at the top-left corner.
    ///
    /// `horizontal` grows to the right and `vertical` grows downwards, so the two can be scaled by the
    /// width and the height of the rendered drawing respectively.
    public struct Point: Equatable, Sendable {
        public let horizontal: Double
        public let vertical: Double

        public init(horizontal: Double, vertical: Double) {
            self.horizontal = horizontal
            self.vertical = vertical
        }
    }

    /// Size of the artwork these points are normalized against.
    public static let imageWidth: Double = 1452
    public static let imageHeight: Double = 940

    public static var aspectRatio: Double {
        imageWidth / imageHeight
    }

    /// Smallest gap two controls may have, normalized by the image width like
    /// `separation(between:and:)`.
    ///
    /// The view puts the hit area and the highlight of each control over the artwork, so two controls
    /// closer than this would answer to the same pointer and light up together. The tightest real gap
    /// is the shoulder pair at 0.033.
    public static let minimumBadgeSeparation = 0.025

    /// One point per control. Every case of `XInputControl` is present exactly once; `PadLayoutTests`
    /// guards both the presence and the values.
    public let points: [XInputControl: Point]

    public init(points: [XInputControl: Point]) {
        self.points = points
    }

    public func point(for control: XInputControl) -> Point? {
        points[control]
    }

    /// Gap between two badges in the image's own scale.
    ///
    /// Both axes are measured in pixels of the original drawing and the result is divided by its
    /// width, not by its height: normalizing y by the height would stretch the picture's proportions
    /// and make two points look further apart than they are on screen.
    public func separation(between first: XInputControl, and second: XInputControl) -> Double? {
        guard let start = point(for: first), let end = point(for: second) else { return nil }
        let gapX = (start.horizontal - end.horizontal) * Self.imageWidth
        let gapY = (start.vertical - end.vertical) * Self.imageHeight
        return (gapX * gapX + gapY * gapY).squareRoot() / Self.imageWidth
    }

    /// The measured table. Values are the centroids from the derivation above, rounded to four
    /// decimals; four decimals are under two pixels on the original drawing, far below a badge.
    public static let standard = PadLayout(points: [
        .dpadUp: Point(horizontal: 0.2205, vertical: 0.3606),
        .dpadDown: Point(horizontal: 0.2204, vertical: 0.4981),
        .dpadLeft: Point(horizontal: 0.1740, vertical: 0.4297),
        .dpadRight: Point(horizontal: 0.2669, vertical: 0.4296),
        .buttonA: Point(horizontal: 0.7837, vertical: 0.5224),
        .buttonB: Point(horizontal: 0.8484, vertical: 0.4299),
        .buttonX: Point(horizontal: 0.7196, vertical: 0.4296),
        .buttonY: Point(horizontal: 0.7838, vertical: 0.3373),
        // L1 is the front button, the ellipse; L2 is the dome behind it.
        .leftBumper: Point(horizontal: 0.2253, vertical: 0.1692),
        .rightBumper: Point(horizontal: 0.7787, vertical: 0.1693),
        .leftTrigger: Point(horizontal: 0.2305, vertical: 0.1187),
        .rightTrigger: Point(horizontal: 0.7730, vertical: 0.1189),
        .back: Point(horizontal: 0.3172, vertical: 0.2941),
        .start: Point(horizontal: 0.6857, vertical: 0.2941),
        .guide: Point(horizontal: 0.5022, vertical: 0.6072),
        .leftThumb: Point(horizontal: 0.3594, vertical: 0.6259),
        .rightThumb: Point(horizontal: 0.6445, vertical: 0.6259),
    ])
}
