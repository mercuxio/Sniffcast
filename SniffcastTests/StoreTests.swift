import Foundation
import Testing

@MainActor
struct LocationsStoreTests {
    let defaults: UserDefaults
    let here = Coordinate(latitude: 51.5, longitude: -0.13)
    let portland = GeocodeResult(id: 1, name: "Portland", detail: "Oregon, United States",
                                 coordinate: Coordinate(latitude: 45.5, longitude: -122.7))
    let paris = GeocodeResult(id: 2, name: "Paris", detail: "Île-de-France, France",
                              coordinate: Coordinate(latitude: 48.9, longitude: 2.35))

    init() {
        let suite = "sniffcast.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    @Test func defaultsToCurrentLocation() {
        let store = LocationsStore(defaults: defaults)
        #expect(store.active == .current)
        let t = store.target(currentCoordinate: here, locationDenied: false)
        #expect(t == LocationTarget(key: "current", name: "Current Location", coordinate: here, isCurrent: true))
    }

    @Test func addingDoesNotChangeSelection() {
        let store = LocationsStore(defaults: defaults)
        store.add(portland)
        #expect(store.active == .current)
        #expect(store.saved.map(\.name) == ["Portland"])
    }

    @Test func addingSameCityTwiceIsIgnored() {
        let store = LocationsStore(defaults: defaults)
        store.add(portland)
        store.add(portland)
        #expect(store.saved.count == 1)
    }

    @Test func selectedSavedLocationIsTarget() throws {
        let store = LocationsStore(defaults: defaults)
        let saved = store.add(portland)
        store.active = .saved(saved.id)
        let t = try #require(store.target(currentCoordinate: here, locationDenied: false))
        #expect(t.key == saved.id.uuidString)
        #expect(t.name == "Portland")
        #expect(!t.isCurrent)
    }

    @Test func deniedCurrentFallsBackToFirstSaved() {
        let store = LocationsStore(defaults: defaults)
        store.add(paris)
        store.add(portland)
        #expect(store.target(currentCoordinate: nil, locationDenied: true)?.name == "Paris")
    }

    @Test func noTargetWhileWaitingForFix() {
        let store = LocationsStore(defaults: defaults)
        store.add(paris)
        #expect(store.target(currentCoordinate: nil, locationDenied: false) == nil)
    }

    @Test func deniedWithNoSavedCitiesHasNoTarget() {
        let store = LocationsStore(defaults: defaults)
        #expect(store.target(currentCoordinate: nil, locationDenied: true) == nil)
    }

    @Test func deletingSelectedRevertsToCurrent() {
        let store = LocationsStore(defaults: defaults)
        let saved = store.add(portland)
        store.active = .saved(saved.id)
        store.remove(id: saved.id)
        #expect(store.active == .current)
        #expect(store.saved.isEmpty)
    }

    @Test func missingSelectedLocationFallsBackToCurrent() {
        defaults.set(UUID().uuidString, forKey: "activeLocation")
        let store = LocationsStore(defaults: defaults)
        #expect(store.active == .current)
    }

    @Test func persistsAcrossInstances() {
        let a = LocationsStore(defaults: defaults)
        let saved = a.add(portland)
        a.add(paris)
        a.active = .saved(saved.id)
        a.move(from: IndexSet(integer: 1), to: 0)
        let b = LocationsStore(defaults: defaults)
        #expect(b.saved.map(\.name) == ["Paris", "Portland"])
        #expect(b.active == .saved(saved.id))
    }
}

@MainActor
struct SettingsStoreTests {
    let defaults = UserDefaults(suiteName: "sniffcast.tests.\(UUID().uuidString)")!

    @Test func defaults_() {
        let s = SettingsStore(defaults: defaults, locale: Locale(identifier: "en_US"))
        #expect(s.menubarStyle == .full)
        #expect(s.refreshInterval == .thirty)
        #expect(s.temperatureUnit == .fahrenheit)
        #expect(s.windUnit == .mph)
        #expect(s.aqiScale == .us)
        #expect(s.alertThreshold == 100)
        #expect(!s.alertsEnabled)
        #expect(!s.aqiMonochrome)
    }

    @Test func persistsMonochrome() {
        let a = SettingsStore(defaults: defaults, locale: Locale(identifier: "en_US"))
        a.aqiMonochrome = true
        let b = SettingsStore(defaults: defaults, locale: Locale(identifier: "en_US"))
        #expect(b.aqiMonochrome)
    }

    @Test func switchingScaleResetsThreshold() {
        let s = SettingsStore(defaults: defaults, locale: Locale(identifier: "en_US"))
        s.alertThreshold = 150
        s.aqiScale = .eu
        #expect(s.alertThreshold == 60)
    }

    @Test func persists() {
        let a = SettingsStore(defaults: defaults, locale: Locale(identifier: "en_US"))
        a.menubarStyle = .rotating
        a.refreshInterval = .fortyFive
        a.temperatureUnit = .celsius
        a.alertsEnabled = true
        a.alertThreshold = 120
        let b = SettingsStore(defaults: defaults, locale: Locale(identifier: "de_DE"))
        #expect(b.menubarStyle == .rotating)
        #expect(b.refreshInterval == .fortyFive)
        #expect(b.temperatureUnit == .celsius)
        #expect(b.windUnit == .mph) // saved from first launch's locale
        #expect(b.alertsEnabled)
        #expect(b.alertThreshold == 120)
    }
}
