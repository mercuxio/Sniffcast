import Foundation
import Observation

enum ActiveLocation: Hashable, Sendable {
    case current
    case saved(UUID)
}

/// The location a refresh should fetch, after resolving selection and fallbacks.
struct LocationTarget: Equatable, Sendable {
    var key: String
    var name: String
    var coordinate: Coordinate
    var isCurrent: Bool
}

/// Saved cities (ordered) plus the active selection. Current location is the default.
@MainActor
@Observable
final class LocationsStore {
    private enum Key {
        static let saved = "savedLocations", active = "activeLocation"
    }
    static let currentKey = "current"

    @ObservationIgnored private let defaults: UserDefaults

    private(set) var saved: [SavedLocation] { didSet { persistSaved() } }
    var active: ActiveLocation { didSet { persistActive() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: Key.saved)
            .flatMap { try? JSONDecoder().decode([SavedLocation].self, from: $0) } ?? []
        self.saved = saved
        // A stored selection that no longer exists (or none at all) means current location.
        if let raw = defaults.string(forKey: Key.active), let id = UUID(uuidString: raw),
           saved.contains(where: { $0.id == id }) {
            active = .saved(id)
        } else {
            active = .current
        }
    }

    var activeSaved: SavedLocation? {
        guard case .saved(let id) = active else { return nil }
        return saved.first { $0.id == id }
    }

    @discardableResult
    func add(_ result: GeocodeResult) -> SavedLocation {
        if let existing = saved.first(where: { $0.coordinate == result.coordinate }) { return existing }
        let location = SavedLocation(id: UUID(), name: result.name, detail: result.detail, coordinate: result.coordinate)
        saved.append(location)
        return location
    }

    func remove(id: UUID) {
        saved.removeAll { $0.id == id }
        if active == .saved(id) { active = .current }
    }

    func move(from source: IndexSet, to destination: Int) {
        // Same semantics as SwiftUI's move(fromOffsets:toOffset:), without importing SwiftUI.
        let moving = source.map { saved[$0] }
        let insertAt = destination - source.count(in: 0..<destination)
        var remaining = saved
        for index in source.reversed() { remaining.remove(at: index) }
        remaining.insert(contentsOf: moving, at: insertAt)
        saved = remaining
    }

    /// Resolves what to fetch. Current location falls back to the first saved city only when
    /// location access is denied; while a fix is pending there is no target yet.
    func target(currentCoordinate: Coordinate?, locationDenied: Bool) -> LocationTarget? {
        if let location = activeSaved {
            return LocationTarget(key: location.id.uuidString, name: location.name,
                                  coordinate: location.coordinate, isCurrent: false)
        }
        if let currentCoordinate {
            return LocationTarget(key: Self.currentKey, name: "Current Location",
                                  coordinate: currentCoordinate, isCurrent: true)
        }
        if locationDenied, let first = saved.first {
            return LocationTarget(key: first.id.uuidString, name: first.name,
                                  coordinate: first.coordinate, isCurrent: false)
        }
        return nil
    }

    private func persistSaved() {
        defaults.set(try? JSONEncoder().encode(saved), forKey: Key.saved)
    }

    private func persistActive() {
        switch active {
        case .current: defaults.removeObject(forKey: Key.active)
        case .saved(let id): defaults.set(id.uuidString, forKey: Key.active)
        }
    }
}
