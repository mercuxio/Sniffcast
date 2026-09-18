import Foundation
import Observation

/// User preferences, persisted to UserDefaults on every change.
@MainActor
@Observable
final class SettingsStore {
    private enum Key {
        static let style = "menubarStyle", interval = "refreshInterval", temperature = "temperatureUnit"
        static let wind = "windUnit", scale = "aqiScale", alerts = "alertsEnabled", threshold = "alertThreshold"
        static let monochrome = "aqiMonochrome", moonPartlyCloudy = "moonPhaseOnPartlyCloudy"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var menubarStyle: MenubarStyle { didSet { defaults.set(menubarStyle.rawValue, forKey: Key.style) } }
    var refreshInterval: RefreshInterval { didSet { defaults.set(refreshInterval.rawValue, forKey: Key.interval) } }
    var temperatureUnit: TemperatureUnit { didSet { defaults.set(temperatureUnit.rawValue, forKey: Key.temperature) } }
    var windUnit: WindUnit { didSet { defaults.set(windUnit.rawValue, forKey: Key.wind) } }
    var aqiScale: AQIScaleKind {
        didSet {
            defaults.set(aqiScale.rawValue, forKey: Key.scale)
            // Thresholds are not comparable across scales.
            if oldValue != aqiScale { alertThreshold = AQIScale.defaultThreshold(aqiScale) }
        }
    }
    /// Menubar AQI drawn in the label color instead of its band color.
    var aqiMonochrome: Bool { didSet { defaults.set(aqiMonochrome, forKey: Key.monochrome) } }
    /// Partly cloudy nights show the moon's phase too, not only clear ones.
    var moonPhaseOnPartlyCloudy: Bool { didSet { defaults.set(moonPhaseOnPartlyCloudy, forKey: Key.moonPartlyCloudy) } }
    var alertsEnabled: Bool { didSet { defaults.set(alertsEnabled, forKey: Key.alerts) } }
    var alertThreshold: Int { didSet { defaults.set(alertThreshold, forKey: Key.threshold) } }

    private static func stored<T: RawRepresentable>(_ defaults: UserDefaults, _ key: String) -> T? {
        guard let raw = defaults.object(forKey: key) as? T.RawValue else { return nil }
        return T(rawValue: raw)
    }

    init(defaults: UserDefaults = .standard, locale: Locale = .current) {
        self.defaults = defaults
        let d = Units.defaults(for: locale)
        func raw<T: RawRepresentable>(_ key: String, _ fallback: T) -> T {
            Self.stored(defaults, key) ?? fallback
        }
        menubarStyle = raw(Key.style, MenubarStyle.full)
        refreshInterval = raw(Key.interval, RefreshInterval.default)
        temperatureUnit = raw(Key.temperature, d.temperature)
        windUnit = raw(Key.wind, d.wind)
        let scale = raw(Key.scale, d.scale)
        aqiScale = scale
        aqiMonochrome = defaults.bool(forKey: Key.monochrome)
        moonPhaseOnPartlyCloudy = defaults.bool(forKey: Key.moonPartlyCloudy)
        alertsEnabled = defaults.bool(forKey: Key.alerts)
        alertThreshold = (defaults.object(forKey: Key.threshold) as? Int) ?? AQIScale.defaultThreshold(scale)

        // Pin locale-derived defaults on first launch so a later locale change doesn't flip units.
        defaults.set(temperatureUnit.rawValue, forKey: Key.temperature)
        defaults.set(windUnit.rawValue, forKey: Key.wind)
        defaults.set(aqiScale.rawValue, forKey: Key.scale)
    }
}
