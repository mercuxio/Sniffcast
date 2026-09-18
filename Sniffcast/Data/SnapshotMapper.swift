import Foundation

enum OpenMeteoError: Error, Equatable, Sendable {
    case api(String)
    case http(Int)
    case decoding
}

/// Pure DTO → domain mapping, kept free of networking so it is fully testable with fixtures.
enum SnapshotMapper {
    static func decodeForecast(_ data: Data) throws -> ForecastResponse {
        try decode(data)
    }

    static func decodeAir(_ data: Data) throws -> AirQualityResponse {
        try decode(data)
    }

    static func decodeGeocode(_ data: Data) throws -> [GeocodeResult] {
        let response: GeocodeResponse = try decode(data)
        return (response.results ?? []).map { r in
            GeocodeResult(
                id: r.id,
                name: r.name,
                detail: [r.admin1, r.country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "),
                coordinate: Coordinate(latitude: r.latitude, longitude: r.longitude)
            )
        }
    }

    static func apiError(from data: Data) -> OpenMeteoError? {
        guard let body = try? JSONDecoder().decode(APIErrorResponse.self, from: data), body.error else { return nil }
        return .api(body.reason)
    }

    static func make(forecast: ForecastResponse, air: AirQualityResponse?, fetchedAt: Date) -> Snapshot {
        let c = forecast.current
        let current = CurrentConditions(
            temperature: c.temperature_2m ?? 0,
            apparentTemperature: c.apparent_temperature ?? c.temperature_2m ?? 0,
            humidity: c.relative_humidity_2m ?? 0,
            weatherCode: c.weather_code ?? -1,
            windSpeed: c.wind_speed_10m ?? 0,
            isDay: (c.is_day ?? 1) == 1
        )

        // Air-quality hourly data starts at local midnight; index it by timestamp and join.
        let airHourly = air?.hourly
        var airIndex: [Int: Int] = [:]
        for (i, t) in (airHourly?.time ?? []).enumerated() { airIndex[t] = i }

        var hourly: [HourlyPoint] = []
        if let h = forecast.hourly {
            for (i, t) in h.time.enumerated() {
                guard let temp = value(h.temperature_2m, i) else { continue }
                let ai = airIndex[t]
                hourly.append(HourlyPoint(
                    time: Date(timeIntervalSince1970: TimeInterval(t)),
                    temperature: temp,
                    weatherCode: value(h.weather_code, i) ?? -1,
                    usAQI: ai.flatMap { value(airHourly?.us_aqi, $0) },
                    euAQI: ai.flatMap { value(airHourly?.european_aqi, $0) }
                ))
            }
        }

        var daily: [DailyPoint] = []
        if let d = forecast.daily {
            for (i, t) in d.time.enumerated() {
                guard let high = value(d.temperature_2m_max, i),
                      let low = value(d.temperature_2m_min, i) else { continue }
                // Day runs to the next day's local midnight (handles DST-length days).
                let end = d.time[safe: i + 1] ?? t + 86_400
                daily.append(DailyPoint(
                    date: Date(timeIntervalSince1970: TimeInterval(t)),
                    weatherCode: value(d.weather_code, i) ?? -1,
                    high: high,
                    low: low,
                    pollen: airHourly.flatMap { pollen(in: $0, from: t, to: end) }
                ))
            }
        }

        let airQuality = air?.current.map { a in
            AirQuality(
                usAQI: a.us_aqi,
                euAQI: a.european_aqi,
                pollutants: Pollutants(
                    pm25: a.pm2_5, pm10: a.pm10, ozone: a.ozone,
                    no2: a.nitrogen_dioxide, so2: a.sulphur_dioxide, co: a.carbon_monoxide
                )
            )
        }

        return Snapshot(fetchedAt: fetchedAt, current: current, hourly: hourly, daily: daily, air: airQuality)
    }

    /// Per-day max of each hourly pollen series; nil when the day has no pollen data at all.
    private static func pollen(in h: AirQualityResponse.Hourly, from start: Int, to end: Int) -> Pollen? {
        let indices = h.time.indices.filter { h.time[$0] >= start && h.time[$0] < end }
        func dayMax(_ series: [Double?]?) -> Double? {
            guard let series else { return nil }
            return indices.compactMap { value(series, $0) }.max()
        }
        let p = Pollen(
            alder: dayMax(h.alder_pollen), birch: dayMax(h.birch_pollen), grass: dayMax(h.grass_pollen),
            mugwort: dayMax(h.mugwort_pollen), olive: dayMax(h.olive_pollen), ragweed: dayMax(h.ragweed_pollen)
        )
        return p.entries.isEmpty ? nil : p
    }

    /// Element `i` of a nullable Open-Meteo series, flattening "missing" and "null" into nil.
    private static func value<T>(_ series: [T?]?, _ i: Int) -> T? {
        guard let series, series.indices.contains(i) else { return nil }
        return series[i]
    }

    private static func decode<T: Decodable>(_ data: Data) throws -> T {
        if let error = apiError(from: data) { throw error }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw OpenMeteoError.decoding
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
