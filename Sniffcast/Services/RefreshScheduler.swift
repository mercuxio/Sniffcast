import AppKit
import Network

/// Decides when to fetch and writes results into `AppState`.
///
/// Efficiency rules (spec §6): one OS-coalesced repeating activity at the user's interval,
/// no polling; wake and reconnect only fetch if data is older than the interval; retries use
/// a one-shot activity with capped exponential backoff.
@MainActor
final class RefreshScheduler {
    private let state: AppState
    private let settings: SettingsStore
    private let locations: LocationsStore
    private let provider: WeatherProviding
    private let alerts: AlertService
    private let now: () -> Date

    private var periodic: NSBackgroundActivityScheduler?
    private var retry: NSBackgroundActivityScheduler?
    private var attempt = 0
    private var installedInterval: RefreshInterval?
    private var lastTarget: LocationTarget?
    private var fetchTask: Task<Void, Never>?
    private var online = true
    private let pathMonitor = NWPathMonitor()

    init(state: AppState, settings: SettingsStore, locations: LocationsStore,
         provider: WeatherProviding, alerts: AlertService, now: @escaping () -> Date = Date.init) {
        self.state = state
        self.settings = settings
        self.locations = locations
        self.provider = provider
        self.alerts = alerts
        self.now = now
    }

    private var policy: RefreshPolicy { RefreshPolicy(interval: settings.refreshInterval) }

    func start() {
        observe { [settings] in settings.refreshInterval } apply: { [weak self] interval in
            guard let self, interval != installedInterval else { return }
            installPeriodic(interval)
        }
        observe { [locations, state] in
            locations.target(currentCoordinate: state.currentCoordinate,
                             locationDenied: state.locationStatus == .denied)
        } apply: { [weak self] target in
            self?.targetChanged(target)
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshIfDue() }
        }

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.setOnline(online) }
        }
        pathMonitor.start(queue: DispatchQueue(label: "com.houlanyit.Sniffcast.path", qos: .utility))
    }

    // MARK: Triggers

    /// Scheduled tick, wake, reconnect: fetch only when the interval has elapsed.
    func refreshIfDue() {
        updateStale()
        if policy.isDue(lastFetch: lastFetch, now: now()) { fetch() }
    }

    func refreshOnPanelOpen() {
        updateStale()
        if policy.isDueOnPanelOpen(lastFetch: lastFetch, now: now()) { fetch() }
    }

    /// Footer refresh button: always fetch.
    func refreshNow() { fetch() }

    // MARK: Internals

    private var lastFetch: Date? {
        state.snapshotKey == lastTarget?.key ? state.snapshot?.fetchedAt : nil
    }

    private func installPeriodic(_ interval: RefreshInterval) {
        periodic?.invalidate()
        installedInterval = interval
        let activity = NSBackgroundActivityScheduler(identifier: "com.houlanyit.Sniffcast.refresh")
        activity.repeats = true
        activity.interval = interval.seconds
        activity.tolerance = RefreshPolicy(interval: interval).tolerance
        activity.qualityOfService = .utility
        activity.schedule { [weak self] completion in
            Task { @MainActor in
                self?.refreshIfDue()
                completion(.finished)
            }
        }
        periodic = activity
        // A shorter interval may make existing data due now; a longer one never forces a fetch.
        refreshIfDue()
    }

    private func targetChanged(_ target: LocationTarget?) {
        guard target != lastTarget else { return }
        let keyChanged = target?.key != lastTarget?.key
        lastTarget = target
        state.targetName = target?.name
        state.isFallback = target.map { !$0.isCurrent && locations.active == .current } ?? false
        guard target != nil else { return }
        if keyChanged, state.snapshotKey != target?.key {
            // Never show one place's weather under another place's name.
            state.snapshot = nil
            state.snapshotKey = nil
        }
        attempt = 0
        cancelRetry()
        fetch()
    }

    private func setOnline(_ isOnline: Bool) {
        let regained = isOnline && !online
        online = isOnline
        if regained { refreshIfDue() }
    }

    private func fetch() {
        guard fetchTask == nil, let target = lastTarget else { return }
        guard online else {
            state.lastError = "Offline"
            updateStale()
            return
        }
        state.isFetching = true
        let provider = self.provider
        fetchTask = Task { [weak self] in
            let result: Result<Snapshot, any Error>
            do {
                result = .success(try await provider.fetch(target.coordinate))
            } catch {
                result = .failure(error)
            }
            self?.finish(result, for: target)
        }
    }

    private func finish(_ result: Result<Snapshot, any Error>, for target: LocationTarget) {
        fetchTask = nil
        state.isFetching = false
        // Selection changed mid-flight: discard and fetch for the new target.
        guard target.key == lastTarget?.key else {
            fetch()
            return
        }
        switch result {
        case .success(let snapshot):
            state.snapshot = snapshot
            state.snapshotKey = target.key
            state.lastError = nil
            attempt = 0
            cancelRetry()
            alerts.handle(snapshot: snapshot, key: target.key, locationName: target.name)
        case .failure(let error):
            state.lastError = Self.message(for: error)
            attempt += 1
            scheduleRetry()
        }
        updateStale()
    }

    private func scheduleRetry() {
        cancelRetry()
        let delay = policy.backoff(attempt: attempt)
        let activity = NSBackgroundActivityScheduler(identifier: "com.houlanyit.Sniffcast.retry")
        activity.repeats = false
        activity.interval = delay
        activity.tolerance = delay / 6
        activity.qualityOfService = .utility
        activity.schedule { [weak self] completion in
            Task { @MainActor in
                self?.retry = nil
                self?.fetch()
                completion(.finished)
            }
        }
        retry = activity
    }

    private func cancelRetry() {
        retry?.invalidate()
        retry = nil
    }

    private func updateStale() {
        let stale = policy.isStale(lastFetch: state.snapshot?.fetchedAt, now: now())
        if state.isStale != stale { state.isStale = stale }
    }

    private static func message(for error: any Error) -> String {
        switch error {
        case OpenMeteoError.api(let reason): reason
        case OpenMeteoError.http(let code): "Server error (\(code))"
        case OpenMeteoError.decoding: "Unexpected response"
        case let error as URLError where error.code == .notConnectedToInternet: "Offline"
        case let error as URLError where error.code == .timedOut: "Request timed out"
        default: "Couldn't update"
        }
    }
}
