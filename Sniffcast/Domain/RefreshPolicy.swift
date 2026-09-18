import Foundation

enum RefreshInterval: Int, CaseIterable, Sendable, Identifiable {
    case fifteen = 15, thirty = 30, fortyFive = 45, sixty = 60

    static let `default` = RefreshInterval.thirty

    var seconds: TimeInterval { TimeInterval(rawValue * 60) }
    var id: Int { rawValue }
}

/// Pure timing decisions for the refresh scheduler; no clocks or timers here.
struct RefreshPolicy: Sendable, Equatable {
    var interval: RefreshInterval

    /// Panel opens refresh only data older than this.
    static let panelOpenThreshold: TimeInterval = 600

    /// Scheduler tolerance: lets the OS coalesce our wakeup with others.
    var tolerance: TimeInterval { interval.seconds / 6 }

    func isDue(lastFetch: Date?, now: Date) -> Bool {
        guard let lastFetch else { return true }
        return now.timeIntervalSince(lastFetch) > interval.seconds
    }

    func isDueOnPanelOpen(lastFetch: Date?, now: Date) -> Bool {
        guard let lastFetch else { return true }
        return now.timeIntervalSince(lastFetch) > Self.panelOpenThreshold
    }

    func isStale(lastFetch: Date?, now: Date) -> Bool {
        guard let lastFetch else { return false }
        return now.timeIntervalSince(lastFetch) > interval.seconds * 1.5
    }

    /// 2, 4, 8… minutes, capped at the refresh interval. `attempt` is 1-based.
    func backoff(attempt: Int) -> TimeInterval {
        let exponent = min(max(attempt - 1, 0), 16)
        return min(120 * pow(2, Double(exponent)), interval.seconds)
    }
}
