import CoreLocation

/// Coarse, low-power location: one fix at kilometer accuracy, then significant-change
/// monitoring (cell/Wi-Fi based, no GPS). Never continuous updates.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    var onUpdate: ((Coordinate) -> Void)?
    var onStatus: ((LocationStatus) -> Void)?

    private let manager = CLLocationManager()
    private var lastEmitted: CLLocation?
    private var running = false

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
        manager.stopMonitoringSignificantLocationChanges()
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

    private func handle(_ location: CLLocation) {
        // Ignore jitter below a kilometer: a new coordinate means a new fetch.
        if let lastEmitted, location.distance(from: lastEmitted) < 1_000 { return }
        lastEmitted = location
        onUpdate?(Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
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
        // kCLErrorLocationUnknown is transient; significant-change monitoring will retry.
        guard (error as? CLError)?.code == .denied else { return }
        MainActor.assumeIsolated { onStatus?(.denied) }
    }
}
