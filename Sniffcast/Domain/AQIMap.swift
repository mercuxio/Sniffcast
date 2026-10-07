import Foundation

/// A WAQI monitoring station's AQI (US EPA scale).
struct StationReading: Equatable, Sendable {
    var name: String
    var latitude: Double
    var longitude: Double
    var aqi: Int
}

/// The nearest station's AQI for a location, from WAQI's geolocated feed.
struct StationFeed: Equatable, Sendable {
    var name: String
    var aqi: Int
}

/// WAQI parsing and the interpolation behind the panel's AQI heat map. Pure, so it is testable.
enum AQIMap {
    static let attribution = "Data © waqi.info"
    static let tokenRequestURL = URL(string: "https://aqicn.org/data-platform/token/")!

    // MARK: Parsing

    /// WAQI sends `aqi` as a number or a string, and "-" when a station has no reading.
    private struct Flexible: Decodable {
        let value: Int?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let i = try? c.decode(Int.self) { value = i }
            else if let d = try? c.decode(Double.self) { value = Int(d.rounded()) }
            else if let s = try? c.decode(String.self) { value = Int(s.trimmingCharacters(in: .whitespaces)) }
            else { value = nil }
        }
    }

    private struct FeedResponse: Decodable {
        struct Data: Decodable {
            struct City: Decodable { let name: String? }
            let aqi: Flexible?
            let city: City?
        }
        let status: String
        let data: Data?
    }

    private struct BoundsResponse: Decodable {
        struct Item: Decodable {
            struct Station: Decodable { let name: String? }
            let lat: Double?
            let lon: Double?
            let aqi: Flexible?
            let station: Station?
        }
        let status: String
        let data: [Item]?
    }

    /// Nil on an error response (bad token, unknown location) or a station with no reading.
    static func parseFeed(_ data: Data) -> StationFeed? {
        guard let r = try? JSONDecoder().decode(FeedResponse.self, from: data), r.status == "ok",
              let aqi = r.data?.aqi?.value else { return nil }
        return StationFeed(name: r.data?.city?.name ?? "", aqi: aqi)
    }

    /// Stations without a position or a reading are dropped.
    static func parseStations(_ data: Data) -> [StationReading] {
        guard let r = try? JSONDecoder().decode(BoundsResponse.self, from: data), r.status == "ok" else { return [] }
        return (r.data ?? []).compactMap { item in
            guard let lat = item.lat, let lon = item.lon, let aqi = item.aqi?.value else { return nil }
            return StationReading(name: item.station?.name ?? "", latitude: lat, longitude: lon, aqi: aqi)
        }
    }

    // MARK: Interpolation

    /// A point's AQI by inverse-distance weighting of the stations, with how much to trust it.
    /// `confidence` is 1 within `fullKm` of a station and fades to 0 at `fadeKm`, so the heat map
    /// goes transparent where no station is near instead of painting a guess.
    static func interpolate(latitude: Double, longitude: Double, stations: [StationReading],
                            fullKm: Double = 8, fadeKm: Double = 35) -> (aqi: Double, confidence: Double)? {
        var weightSum = 0.0, valueSum = 0.0, nearest = Double.infinity
        for s in stations {
            let d = max(distanceKm(latitude, longitude, s.latitude, s.longitude), 0.5)
            nearest = min(nearest, d)
            let w = 1 / (d * d)
            weightSum += w
            valueSum += w * Double(s.aqi)
        }
        guard weightSum > 0, nearest < fadeKm else { return nil }
        let confidence = nearest <= fullKm ? 1 : 1 - (nearest - fullKm) / (fadeKm - fullKm)
        return (valueSum / weightSum, confidence)
    }

    /// Great-circle distance, accurate enough over tens of kilometres.
    static func distanceKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6371.0, rad = Double.pi / 180
        let dLat = (lat2 - lat1) * rad, dLon = (lon2 - lon1) * rad
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * rad) * cos(lat2 * rad) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }
}

extension Snapshot {
    /// The nearest station's reading replaces the model's US AQI everywhere the US scale is shown,
    /// and the station's name is kept for the map caption. The European scale is left alone: the
    /// station reports US AQI only.
    func applying(station: StationFeed) -> Snapshot {
        var copy = self
        var air = copy.air ?? AirQuality(usAQI: nil, euAQI: nil, pollutants: Pollutants())
        air.stationUS = station.aqi
        air.stationName = station.name
        copy.air = air
        return copy
    }
}
