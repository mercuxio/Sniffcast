import CoreLocation

/// Coarse, low-power location: one fix at kilometer accuracy, then significant-change
/// monitoring (cell/Wi-Fi based, no GPS). Never continuous updates.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    var onUpdate: ((Coordinate) -> Void)?
    var onStatus: ((LocationStatus) -> Void)?
    /// A human-readable name for the latest fix ("Kowloon", "Brooklyn").
    var onPlaceName: ((String) -> Void)?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastEmitted: CLLocation?
    private var running = false
    private var retryTask: Task<Void, Never>?
    private var retryDelay = LocationProvider.firstRetryDelay
    private static let firstRetryDelay: Duration = .seconds(15)

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 1_000
    }

    var status: LocationStatus { Self.map(manager.authorizationStatus) }

    func start() {
        guard !running else { return }
        running = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()  // continues in didChangeAuthorization
        case .denied, .restricted:
            onStatus?(.denied)
        default:
            onStatus?(.authorized)
            beginUpdates()
        }
    }

    func stop() {
        guard running else { return }
        running = false
        cancelRetry()
        manager.stopMonitoringSignificantLocationChanges()
    }

    /// Starts the jitter filter from a persisted fix, so the first fix of a launch refetches
    /// only if the Mac has actually moved since.
    func seed(_ coordinate: Coordinate?) {
        guard lastEmitted == nil, let coordinate else { return }
        lastEmitted = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// One-shot re-fix (e.g. after wake), without changing monitoring.
    func requestFix() {
        guard running, status == .authorized else { return }
        manager.requestLocation()
    }

    private func beginUpdates() {
        manager.requestLocation()
        manager.startMonitoringSignificantLocationChanges()
    }

    private nonisolated static func map(_ status: CLAuthorizationStatus) -> LocationStatus {
        switch status {
        case .notDetermined: .unknown
        case .denied, .restricted: .denied
        default: .authorized
        }
    }

    /// A failed fix is retried at 15 s, 30 s, 1 min… up to 5 min. Waiting on significant-change
    /// monitoring instead can take minutes, and at login the first request always fails:
    /// Wi-Fi, which a Mac locates itself by, isn't up yet.
    private func scheduleRetry() {
        guard running, retryTask == nil else { return }
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, .seconds(300))
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            retryTask = nil
            requestFix()
        }
    }

    private func cancelRetry() {
        retryTask?.cancel()
        retryTask = nil
        retryDelay = Self.firstRetryDelay
    }

    private func handle(_ location: CLLocation) {
        cancelRetry()
        // Ignore jitter below a kilometer: a new coordinate means a new fetch.
        if let lastEmitted, location.distance(from: lastEmitted) < 1_000 { return }
        lastEmitted = location
        onUpdate?(Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
        name(location)
    }

    /// One reverse geocode per emitted fix, so at most one per kilometre moved. Failures are
    /// ignored: the last good name (or "Current Location") stays up, and the next fix retries.
    private func name(_ location: CLLocation) {
        geocoder.cancelGeocode()
        // Explicit, never nil: see PreferredLanguage for why the default gets this wrong.
        let locale = Locale(identifier: PreferredLanguage.identifier())
        geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { [weak self] placemarks, _ in
            let placemark = placemarks?.first
            // The neighbourhood-to-city ladder: the most specific name a person would recognise.
            let name = placemark?.locality ?? placemark?.subAdministrativeArea
                ?? placemark?.administrativeArea ?? placemark?.name
            MainActor.assumeIsolated {
                if let name { self?.onPlaceName?(name) }
            }
        }
    }

    // CLLocationManager calls its delegate on the thread it was created on — main here.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = Self.map(manager.authorizationStatus)
        MainActor.assumeIsolated {
            onStatus?(status)
            if running, status == .authorized { beginUpdates() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated { handle(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let denied = (error as? CLError)?.code == .denied
        MainActor.assumeIsolated {
            if denied { onStatus?(.denied) } else { scheduleRetry() }
        }
    }
}
