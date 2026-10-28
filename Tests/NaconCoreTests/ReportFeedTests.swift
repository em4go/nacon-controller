import XCTest

@testable import NaconCore

/// The pad reports hundreds of times per second. Publishing each one rebuilt the whole window,
/// including any open menu, and an open menu rebuilt underneath itself flickers and closes its
/// submenus. The feed keeps the newest snapshot and publishes it once per interval.
final class ReportFeedTests: XCTestCase {
    /// Runs the coalescing rule without waiting for the clock.
    private final class Scheduler {
        private(set) var work: [(delay: TimeInterval, run: () -> Void)] = []

        func schedule(_ delay: TimeInterval, _ block: @escaping () -> Void) {
            work.append((delay, block))
        }

        func runNext() {
            guard !work.isEmpty else { return }
            work.removeFirst().run()
        }
    }

    private func snapshot(_ count: Int) -> ReportFeed.Snapshot {
        ReportFeed.Snapshot(report: nil, count: count, rawPacketHex: "\(count)", receivedAt: nil)
    }

    func testManyReportsPublishOnceAndTheNewestWins() {
        let scheduler = Scheduler()
        let feed = ReportFeed(interval: 0.05, schedule: scheduler.schedule)

        for count in 1...20 {
            feed.submit(snapshot(count))
        }

        XCTAssertEqual(scheduler.work.count, 1, "one publish for twenty reports")
        XCTAssertEqual(feed.latest, .empty, "nothing is published before the interval passes")

        scheduler.runNext()

        XCTAssertEqual(feed.latest.count, 20, "the newest snapshot is the one that lands")
    }

    func testTheIntervalIsTheOneAsked() {
        let scheduler = Scheduler()
        let feed = ReportFeed(interval: 0.05, schedule: scheduler.schedule)

        feed.submit(snapshot(1))

        XCTAssertEqual(scheduler.work.first?.delay, 0.05)
    }

    func testAnotherReportAfterAPublishIsScheduledAgain() {
        let scheduler = Scheduler()
        let feed = ReportFeed(interval: 0.05, schedule: scheduler.schedule)

        feed.submit(snapshot(1))
        scheduler.runNext()
        feed.submit(snapshot(2))

        XCTAssertEqual(scheduler.work.count, 1, "a later report must not be dropped for good")
        scheduler.runNext()
        XCTAssertEqual(feed.latest.count, 2)
    }

    func testAnIdenticalSnapshotIsNotRepublished() {
        let scheduler = Scheduler()
        let feed = ReportFeed(interval: 0.05, schedule: scheduler.schedule)

        feed.submit(snapshot(1))
        scheduler.runNext()
        feed.submit(snapshot(1))
        scheduler.runNext()

        XCTAssertEqual(feed.latest.count, 1)
    }
}
