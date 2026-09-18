import Foundation
import Observation

enum LocationStatus: Sendable {
    case unknown, authorized, denied
}

/// Single source of truth for what the menubar and panel show.
@MainActor
@Observable
final class AppState {
    var snapshot: Snapshot?
    /// Which location `snapshot` belongs to (`LocationTarget.key`).
    var snapshotKey: String?
    var targetName: String?
    /// True when the target is a saved city standing in for a denied current location.
    var isFallback = false
    var isFetching = false
    var isStale = false
    var lastError: String?
    var currentCoordinate: Coordinate?
    var locationStatus: LocationStatus = .unknown
    /// Bumped to ask the panel to show location setup (e.g. from the footer "+" button).
    var settingsRequest: SettingsTab?
}

enum SettingsTab: String, Hashable, Sendable {
    case general, locations, alerts
}
