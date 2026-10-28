import Foundation

/// How the right stick and the scroll mappings become wheel events.
public enum Scroll {
    /// How far one line scrolls, in the unit `CGEvent` accepts.
    ///
    /// macOS has no single answer: a line is whatever the receiving view decides, roughly 12 to 20
    /// pixels at default text sizes. Line-based wheel events can only carry whole lines, so at
    /// walking pace the view jumps once every few ticks and the movement looks like it is catching.
    /// Emitting pixels removes that granularity, and this constant keeps the configured unit in
    /// lines per second, which is what the user understands and what profiles already store.
    public static let pixelsPerLine = 16.0

    /// Pixels for a whole number of lines, for the discrete scroll mappings.
    public static func pixels(forLines lines: Int) -> Int {
        Int((Double(lines) * pixelsPerLine).rounded())
    }
}
