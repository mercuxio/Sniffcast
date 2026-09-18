import Foundation

/// WMO weather interpretation codes, as returned in Open-Meteo's `weather_code`.
enum WeatherCode {
    static func symbol(_ code: Int, isDay: Bool) -> String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 61, 63, 66: "cloud.rain.fill"
        case 65, 67: "cloud.heavyrain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 80, 81: isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case 82: "cloud.heavyrain.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "questionmark.circle"
        }
    }

    static func description(_ code: Int) -> String {
        switch code {
        case 0: "Clear sky"
        case 1: "Mainly clear"
        case 2: "Partly cloudy"
        case 3: "Overcast"
        case 45: "Fog"
        case 48: "Rime fog"
        case 51, 53, 55: "Drizzle"
        case 56, 57: "Freezing drizzle"
        case 61: "Light rain"
        case 63: "Rain"
        case 65: "Heavy rain"
        case 66, 67: "Freezing rain"
        case 71: "Light snow"
        case 73: "Snow"
        case 75: "Heavy snow"
        case 77: "Snow grains"
        case 80, 81: "Rain showers"
        case 82: "Violent showers"
        case 85, 86: "Snow showers"
        case 95: "Thunderstorm"
        case 96, 99: "Thunderstorm with hail"
        default: "Unknown"
        }
    }
}
