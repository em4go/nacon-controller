import CoreGraphics
import Foundation

/// Keeps the synthesized cursor inside the real display layout.
///
/// Without this the engine accumulates an unbounded virtual position: the physical cursor stops at
/// the edge of the screen but the next delta is computed from the out-of-bounds coordinate, so the
/// pointer appears to need a long travel back.
public enum ScreenGeometry {
    /// Bounds of every active display, in the global display coordinate space (origin top left,
    /// the same space `CGEvent` uses).
    public static func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var identifiers = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &identifiers, &count) == .success else { return [] }
        return identifiers.prefix(Int(count)).map { CGDisplayBounds($0) }
    }

    /// Returns the point moved onto the nearest display.
    ///
    /// A point already inside a display is returned unchanged. A point outside every display, or in
    /// a gap between displays, is clamped to the closest pixel that is actually addressable.
    public static func clamped(_ point: CGPoint, to displays: [CGRect]) -> CGPoint {
        guard !displays.isEmpty else { return point }
        var bestPoint = point
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for rect in displays {
            let candidate = CGPoint(
                x: min(max(point.x, rect.minX), max(rect.minX, rect.maxX - 1)),
                y: min(max(point.y, rect.minY), max(rect.minY, rect.maxY - 1))
            )
            let distance = hypot(point.x - candidate.x, point.y - candidate.y)
            if distance < bestDistance {
                bestDistance = distance
                bestPoint = candidate
            }
        }
        return bestPoint
    }

    /// Convenience wrapper that reads the live display layout.
    public static func clampedToActiveDisplays(_ point: CGPoint) -> CGPoint {
        clamped(point, to: activeDisplayBounds())
    }
}
