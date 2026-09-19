import Foundation

// Property names mirror Open-Meteo's JSON keys exactly (snake_case), so no CodingKeys are needed.
// Every value is optional: Open-Meteo returns null for unavailable data points.

struct ForecastResponse: Decodable, Sendable {
    struct Current: Decodable, Sendable {
        var temperature_2m: Double?
        var apparent_temperature: Double?
        var relative_humidity_2m: Int?
        var weather_code: Int?
        var wind_speed_10m: Double?
        var is_day: Int?
    }
    struct Hourly: Decodable, Sendable {
        var time: [Int]
        var temperature_2m: [Double?]?
        var weather_code: [Int?]?
        var is_day: [Int?]?
    }
    struct Daily: Decodable, Sendable {
        var time: [Int]
        var weather_code: [Int?]?
        var temperature_2m_max: [Double?]?
        var temperature_2m_min: [Double?]?
    }
    var latitude: Double?
    var timezone: String?
    var utc_offset_seconds: Int?
    var current: Current
    var hourly: Hourly?
    var daily: Daily?
}

struct AirQualityResponse: Decodable, Sendable {
    struct Current: Decodable, Sendable {
        var us_aqi: Int?
        var european_aqi: Int?
        var pm2_5: Double?
        var pm10: Double?
        var ozone: Double?
        var nitrogen_dioxide: Double?
        var sulphur_dioxide: Double?
        var carbon_monoxide: Double?
    }
    struct Hourly: Decodable, Sendable {
        var time: [Int]
        var us_aqi: [Int?]?
        var european_aqi: [Int?]?
        var alder_pollen: [Double?]?
        var birch_pollen: [Double?]?
        var grass_pollen: [Double?]?
        var mugwort_pollen: [Double?]?
        var olive_pollen: [Double?]?
        var ragweed_pollen: [Double?]?
    }
    var current: Current?
    var hourly: Hourly?
}

struct GeocodeResponse: Decodable, Sendable {
    struct Result: Decodable, Sendable {
        var id: Int
        var name: String
        var latitude: Double
        var longitude: Double
        var country: String?
        var admin1: String?
    }
    var results: [Result]?
}

struct APIErrorResponse: Decodable, Sendable {
    var error: Bool
    var reason: String
}
