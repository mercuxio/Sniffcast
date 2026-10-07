import Foundation

/// WAQI (aqicn.org) lookups. Both calls need the user's free token and fail soft: a bad token, no
/// station, or no network just means the app keeps the Open-Meteo model value.
struct WAQIClient: Sendable {
    var session: URLSession = OpenMeteoClient.sharedSession

    /// The station nearest to the coordinate.
    func nearest(to c: Coordinate, token: String) async -> StationFeed? {
        guard let url = Self.feedURL(c, token: token),
              let (data, _) = try? await session.data(from: url) else { return nil }
        return AQIMap.parseFeed(data)
    }

    /// Every station inside a box of `halfSpanDegrees` around the coordinate.
    func stations(around c: Coordinate, halfSpanDegrees: Double, token: String) async -> [StationReading] {
        guard let url = Self.boundsURL(c, halfSpanDegrees: halfSpanDegrees, token: token),
              let (data, _) = try? await session.data(from: url) else { return [] }
        return AQIMap.parseStations(data)
    }

    static func feedURL(_ c: Coordinate, token: String) -> URL? {
        guard let token = clean(token) else { return nil }
        var comps = URLComponents(string: "https://api.waqi.info/feed/geo:\(c.latitude);\(c.longitude)/")
        comps?.queryItems = [.init(name: "token", value: token)]
        return comps?.url
    }

    static func boundsURL(_ c: Coordinate, halfSpanDegrees h: Double, token: String) -> URL? {
        guard let token = clean(token) else { return nil }
        let lonH = h / max(cos(c.latitude * .pi / 180), 0.2)
        var comps = URLComponents(string: "https://api.waqi.info/v2/map/bounds")
        comps?.queryItems = [
            .init(name: "latlng", value: String(format: "%.4f,%.4f,%.4f,%.4f",
                                                c.latitude - h, c.longitude - lonH, c.latitude + h, c.longitude + lonH)),
            .init(name: "networks", value: "all"),
            .init(name: "token", value: token),
        ]
        return comps?.url
    }

    private static func clean(_ token: String) -> String? {
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
