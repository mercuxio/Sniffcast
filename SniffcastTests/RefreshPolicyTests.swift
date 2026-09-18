import Foundation
import Testing

struct RefreshPolicyTests {
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test func defaultIsThirtyMinutes() {
        #expect(RefreshInterval.default == .thirty)
        #expect(RefreshInterval.allCases.map(\.rawValue) == [15, 30, 45, 60])
    }

    @Test(arguments: RefreshInterval.allCases)
    func timing(interval: RefreshInterval) {
        let policy = RefreshPolicy(interval: interval)
        let s = interval.seconds
        #expect(s == TimeInterval(interval.rawValue * 60))
        #expect(policy.tolerance == s / 6)

        #expect(policy.isDue(lastFetch: nil, now: now))
        #expect(!policy.isDue(lastFetch: now - s, now: now))
        #expect(policy.isDue(lastFetch: now - s - 1, now: now))

        #expect(!policy.isStale(lastFetch: now - s * 1.5, now: now))
        #expect(policy.isStale(lastFetch: now - s * 1.5 - 1, now: now))
        #expect(!policy.isStale(lastFetch: nil, now: now))

        #expect(policy.isDueOnPanelOpen(lastFetch: nil, now: now))
        #expect(!policy.isDueOnPanelOpen(lastFetch: now - 599, now: now))
        #expect(policy.isDueOnPanelOpen(lastFetch: now - 601, now: now))
    }

    @Test(arguments: RefreshInterval.allCases)
    func backoffDoublesAndCaps(interval: RefreshInterval) {
        let policy = RefreshPolicy(interval: interval)
        #expect(policy.backoff(attempt: 1) == min(120, interval.seconds))
        #expect(policy.backoff(attempt: 2) == min(240, interval.seconds))
        #expect(policy.backoff(attempt: 3) == min(480, interval.seconds))
        #expect(policy.backoff(attempt: 10) == interval.seconds)
        #expect(policy.backoff(attempt: 64) == interval.seconds)
    }
}
