import Foundation

/// What one reconciliation pass should do with the link to the Mando.
///
/// The branch used to live inside `ControllerService`, next to the IOKit scan and the read loop, so
/// the only way to watch it decide was to unplug the pad. It is a decision about values — what the
/// scan found, whether a link is open and how long it has been quiet — so it belongs in one function
/// a test can state on a single line. The service keeps every IOKit and IOUSBHost call: this decides,
/// the service performs.
public enum PadReconnect {
    /// A link quiet for longer than this is treated as gone.
    public static let staleAfter: TimeInterval = 2.0

    /// What is known about the open link.
    public enum LinkAge: Equatable, Sendable {
        /// No link is open.
        case none
        /// A link is open and has been quiet for this many seconds.
        case quiet(TimeInterval)
    }

    /// What the pass must do, in order.
    public enum Action: Equatable, Sendable {
        /// The link is healthy: the scan results are not needed and must be released.
        case keepLink
        /// Open the device at this index, releasing the current link first when it is stale.
        case connect(index: Int, releaseLinkFirst: Bool)
        /// The link is stale and there is nothing to attach to: tear it down and report the pad gone.
        case tearDownOnly
        /// Nothing is open and nothing readable was found: report that the app is searching.
        case search
    }

    /// Decides what the pass does.
    ///
    /// A quiet link inside the threshold always wins: the freshly scanned services are not needed, and
    /// reopening a healthy pad would drop the Informes the user is producing. Past the threshold the
    /// link is gone, so the same pass that tears it down attaches the next readable device instead of
    /// waiting one more round.
    ///
    /// - Parameters:
    ///   - found: every NACON device the scan returned, in scan order.
    ///   - link: whether a link is open and how long it has been quiet.
    ///   - staleAfter: threshold, stated by the caller so a test does not have to wait for it.
    public static func decide(
        found: [NaconDevice],
        link: LinkAge,
        staleAfter: TimeInterval = PadReconnect.staleAfter
    ) -> Action {
        let isLinked: Bool
        if case let .quiet(idle) = link {
            if idle <= staleAfter { return .keepLink }
            isLinked = true
        } else {
            isLinked = false
        }
        guard let candidate = found.firstIndex(where: { $0.isReadable }) else {
            return isLinked ? .tearDownOnly : .search
        }
        return .connect(index: candidate, releaseLinkFirst: isLinked)
    }
}
