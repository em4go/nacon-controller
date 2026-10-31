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

    /// The deltas a wheel event must carry, given the movement the user asked for.
    ///
    /// `ScrollPixels` is in screen terms — positive `x` is right, positive `y` is down — but the
    /// system's second wheel axis grows the opposite way: a positive axis-2 delta moves the content
    /// left. Passing the user's sign straight through is what made pushing the right stick right
    /// scroll the other way while pushing it down scrolled down.
    ///
    /// This is a function and not a line inside the emitter because the emitter needs a live event
    /// tap: a sign that lives only there is a sign no test can hold.
    public static func wheelDeltas(for pixels: ScrollPixels) -> (x: Int32, y: Int32) {
        (x: Int32(-pixels.x), y: Int32(pixels.y))
    }
}
