import Combine
import Foundation

/// The live values the window shows, coalesced to a rate a person can see.
///
/// The pad reports more than a hundred times per second and publishing every report made the whole
/// window rebuild itself at that rate. That is invisible in a static panel but ruinous for a menu:
/// an open `NSMenu` whose SwiftUI content is rebuilt underneath it flickers and drops its submenus,
/// which is exactly what the assign menu did. Nothing on screen needs more than a handful of updates
/// per second, so this keeps the newest snapshot and publishes it once per interval, trailing, so the
/// last report always lands instead of the display freezing on an older one.
public final class ReportFeed: ObservableObject {
    /// One coherent set of values, so a view never renders the count of one report beside the packet
    /// of another.
    public struct Snapshot: Equatable, Sendable {
        public let report: XInputReport?
        public let count: Int
        public let rawPacketHex: String
        public let receivedAt: Date?

        public init(report: XInputReport?, count: Int, rawPacketHex: String, receivedAt: Date?) {
            self.report = report
            self.count = count
            self.rawPacketHex = rawPacketHex
            self.receivedAt = receivedAt
        }

        public static let empty = Snapshot(report: nil, count: 0, rawPacketHex: "", receivedAt: nil)
    }

    @Published public private(set) var latest = Snapshot.empty

    private let interval: TimeInterval
    private let schedule: (TimeInterval, @escaping () -> Void) -> Void
    private var pending: Snapshot?
    private var isScheduled = false

    /// `schedule` exists so a test can run the coalescing rule without waiting for the clock.
    public init(
        interval: TimeInterval = 0.05,
        schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    ) {
        self.interval = interval
        self.schedule = schedule
    }

    /// Offers the newest snapshot. Called on the main queue for every decoded report.
    public func submit(_ snapshot: Snapshot) {
        pending = snapshot
        guard !isScheduled else { return }
        isScheduled = true
        schedule(interval) { [weak self] in
            self?.flush()
        }
    }

    private func flush() {
        isScheduled = false
        guard let queued = pending else { return }
        pending = nil
        // Republishing an identical snapshot would rebuild the views for nothing.
        guard queued != latest else { return }
        latest = queued
    }
}
