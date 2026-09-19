import Foundation

protocol WeatherProviding: Sendable {
    func fetch(_ coordinate: Coordinate) async throws -> Snapshot
    func search(_ query: String) async throws -> [GeocodeResult]
}

/// Open-Meteo client. Requests only the fields the UI displays, always in °C / km/h.
struct OpenMeteoClient: WeatherProviding {
    /// One shared session with a small cache; no per-request sessions.
    static let sharedSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 1 << 20, diskCapacity: 5 << 20)
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    var session: URLSession = Self.sharedSession
    var now: @Sendable () -> Date = { Date() }

    func fetch(_ coordinate: Coordinate) async throws -> Snapshot {
        async let forecastData = get(Self.forecastURL(coordinate))
        async let airData = get(Self.airURL(coordinate))

        // Forecast must succeed; air-quality failure yields a snapshot with AQI unavailable.
        let forecast = try SnapshotMapper.decodeForecast(try await forecastData)
        let air = try? SnapshotMapper.decodeAir(try await airData)
        return SnapshotMapper.make(forecast: forecast, air: air, fetchedAt: now())
    }

    func search(_ query: String) async throws -> [GeocodeResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        c.queryItems = [
            .init(name: "name", value: trimmed),
            .init(name: "count", value: "8"),
            .init(name: "language", value: PreferredLanguage.code()),
        ]
        return try SnapshotMapper.decodeGeocode(try await get(c.url!))
    }

    private func get(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SnapshotMapper.apiError(from: data) ?? .http(http.statusCode)
        }
        return data
    }

    private static func coordinateItems(_ c: Coordinate) -> [URLQueryItem] {
        [
            .init(name: "latitude", value: String(format: "%.4f", c.latitude)),
            .init(name: "longitude", value: String(format: "%.4f", c.longitude)),
            .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime"),
        ]
    }

    static func forecastURL(_ coordinate: Coordinate) -> URL {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = coordinateItems(coordinate) + [
            .init(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"),
            .init(name: "hourly", value: "temperature_2m,weather_code,is_day"),
            .init(name: "forecast_hours", value: "12"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            .init(name: "forecast_days", value: "7"),
        ]
        return c.url!
    }

    static func airURL(_ coordinate: Coordinate) -> URL {
        var c = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        c.queryItems = coordinateItems(coordinate) + [
            .init(name: "current", value: "us_aqi,european_aqi,pm2_5,pm10,ozone,nitrogen_dioxide,sulphur_dioxide,carbon_monoxide"),
            .init(name: "hourly", value: "us_aqi,european_aqi,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen"),
            .init(name: "forecast_days", value: "5"),
        ]
        return c.url!
    }
}
