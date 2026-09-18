import Foundation

struct Coordinate: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}

struct SavedLocation: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var detail: String
    var coordinate: Coordinate
}

struct GeocodeResult: Hashable, Identifiable, Sendable {
    var id: Int
    var name: String
    var detail: String
    var coordinate: Coordinate
}

/// One refresh worth of data. Temperatures are °C and wind km/h, as fetched.
struct Snapshot: Equatable, Sendable {
    var fetchedAt: Date
    /// The location's time zone; hours and weekdays are shown in it.
    var timeZone: TimeZone
    var current: CurrentConditions
    var hourly: [HourlyPoint]
    var daily: [DailyPoint]
    /// Nil when the air-quality request failed.
    var air: AirQuality?
}

struct CurrentConditions: Equatable, Sendable {
    var temperature: Double
    var apparentTemperature: Double
    var humidity: Int
    var weatherCode: Int
    var windSpeed: Double
    var isDay: Bool
}

struct HourlyPoint: Equatable, Sendable, Identifiable {
    var time: Date
    var temperature: Double
    var weatherCode: Int
    var usAQI: Int?
    var euAQI: Int?

    var id: Date { time }

    func aqi(_ scale: AQIScaleKind) -> Int? { scale == .us ? usAQI : euAQI }
}

struct DailyPoint: Equatable, Sendable, Identifiable {
    var date: Date
    var weatherCode: Int
    var high: Double
    var low: Double
    var pollen: Pollen?

    var id: Date { date }
}

struct AirQuality: Equatable, Sendable {
    var usAQI: Int?
    var euAQI: Int?
    var pollutants: Pollutants

    func aqi(_ scale: AQIScaleKind) -> Int? { scale == .us ? usAQI : euAQI }
}

/// Concentrations in μg/m³.
struct Pollutants: Equatable, Sendable {
    var pm25: Double?
    var pm10: Double?
    var ozone: Double?
    var no2: Double?
    var so2: Double?
    var co: Double?
}

/// Grains/m³, per-day maximum of hourly values. Only available in Europe.
struct Pollen: Equatable, Sendable {
    var alder: Double?
    var birch: Double?
    var grass: Double?
    var mugwort: Double?
    var olive: Double?
    var ragweed: Double?

    struct Entry: Equatable, Sendable {
        var name: String
        var value: Double
    }

    var entries: [Entry] {
        [("Alder", alder), ("Birch", birch), ("Grass", grass),
         ("Mugwort", mugwort), ("Olive", olive), ("Ragweed", ragweed)]
            .compactMap { name, value in value.map { Entry(name: name, value: $0) } }
    }
}
