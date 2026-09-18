import Foundation

enum TemperatureUnit: String, CaseIterable, Sendable {
    case celsius, fahrenheit
}

enum WindUnit: String, CaseIterable, Sendable {
    case kmh, mph
}

/// Open-Meteo is always queried in °C and km/h; conversion happens here so that
/// changing a unit setting never costs a network request.
enum Units {
    static func temperature(_ celsius: Double, in unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius: celsius
        case .fahrenheit: celsius * 9 / 5 + 32
        }
    }

    static func formatTemperature(_ celsius: Double, in unit: TemperatureUnit) -> String {
        // Int(rounded) avoids printing "-0°" for values like -0.4.
        "\(Int(temperature(celsius, in: unit).rounded()))°"
    }

    static func wind(_ kmh: Double, in unit: WindUnit) -> Double {
        switch unit {
        case .kmh: kmh
        case .mph: kmh / 1.609344
        }
    }

    static func formatWind(_ kmh: Double, in unit: WindUnit) -> String {
        let value = Int(wind(kmh, in: unit).rounded())
        return switch unit {
        case .kmh: "\(value) km/h"
        case .mph: "\(value) mph"
        }
    }

    /// EU + EEA + UK + CH regions default to the European AQI.
    private static let europeanRegions: Set<String> = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE",
        "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE",
        "IS", "LI", "NO", "GB", "CH",
    ]

    static func defaults(for locale: Locale) -> (temperature: TemperatureUnit, wind: WindUnit, scale: AQIScaleKind) {
        let system = locale.measurementSystem
        let temperature: TemperatureUnit = system == .us ? .fahrenheit : .celsius
        let wind: WindUnit = (system == .us || system == .uk) ? .mph : .kmh
        let region = locale.region?.identifier ?? ""
        let scale: AQIScaleKind = europeanRegions.contains(region) ? .eu : .us
        return (temperature, wind, scale)
    }
}
