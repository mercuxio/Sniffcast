import Foundation

enum MenubarStyle: String, CaseIterable, Sendable, Identifiable {
    case full, threeRows, compact, rotating
    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: "Full"
        case .threeRows: "Three Rows"
        case .compact: "Compact"
        case .rotating: "Rotating"
        }
    }
}

enum MenubarPhase: Sendable {
    case weather, air
}

/// What the status item should show. The AppKit layer turns this into an attributed string
/// and only redraws when the value changes.
struct MenubarContent: Equatable, Sendable {
    var symbol: String
    var text: String
    /// Rendered after `text`, tinted by `band`. Nil when AQI is not shown.
    var aqiText: String?
    /// Nil means untinted: no AQI, or the user chose monochrome.
    var band: AQIBand?
    /// Rendered after the AQI, tinted by `uvBand`. Nil when the UV index is unknown or 0 (overnight),
    /// so the stack falls back to two rows.
    var uvText: String?
    var uvBand: AQIBand?
    /// Temperature, AQI and UV in rows (Three Rows style), instead of side by side.
    var stacked: Bool = false
    var stale: Bool
}

enum MenubarFormatter {
    static let placeholderSymbol = "cloud.sun"
    static let airSymbol = "aqi.medium"

    static func content(
        snapshot: Snapshot?,
        style: MenubarStyle,
        phase: MenubarPhase,
        temperatureUnit: TemperatureUnit,
        scale: AQIScaleKind,
        stale: Bool,
        monochrome: Bool = false,
        moonPhaseOnPartlyCloudy: Bool = false
    ) -> MenubarContent {
        guard let snapshot else {
            return MenubarContent(symbol: placeholderSymbol, text: "—", aqiText: nil, band: nil, stale: stale)
        }
        // The phase follows the fetch time, so it moves on at the next refresh after it changes.
        let symbol = WeatherCode.symbol(snapshot.current.weatherCode, isDay: snapshot.current.isDay,
                                        date: snapshot.fetchedAt, latitude: snapshot.latitude,
                                        phaseOnPartlyCloudy: moonPhaseOnPartlyCloudy)
        let temp = Units.formatTemperature(snapshot.current.temperature, in: temperatureUnit)
        let aqi = snapshot.air?.aqi(scale)
        let band = monochrome ? nil : aqi.map { AQIScale.band(for: $0, scale: scale) }
        // A UV of 0 is left out everywhere: "UV 0" is just noise, and Three Rows drops back to two.
        let uv = snapshot.current.uvIndex.flatMap { value -> (value: Int, band: AQIBand)? in
            UVIndex.rounded(value) > 0 ? (UVIndex.rounded(value), UVIndex.level(for: value).band) : nil
        }
        let uvBand = monochrome ? nil : uv?.band
        let inlineUV = uv.map { "UV\($0.value)" }

        func inline(aqiText: String?) -> MenubarContent {
            MenubarContent(symbol: symbol, text: temp, aqiText: aqiText, band: aqiText == nil ? nil : band,
                           uvText: inlineUV, uvBand: inlineUV == nil ? nil : uvBand, stale: stale)
        }

        switch style {
        case .full:
            return inline(aqiText: aqi.map { "AQI \($0)" })
        case .threeRows:
            // Stacked, the color and position say which row is which; the labels don't need to.
            let rows = 1 + (aqi == nil ? 0 : 1) + (uv == nil ? 0 : 1)
            return MenubarContent(symbol: symbol, text: temp, aqiText: aqi.map { "\($0)" }, band: aqi == nil ? nil : band,
                                  uvText: uv.map { "UV\($0.value)" }, uvBand: uvBand, stacked: rows > 1, stale: stale)
        case .compact:
            // Without color the dot carries no information, so show the number instead.
            return inline(aqiText: aqi.map { monochrome ? "\($0)" : "●" })
        case .rotating:
            switch phase {
            case .weather: return inline(aqiText: nil)
            case .air:
                guard let aqi else { return inline(aqiText: nil) }
                return MenubarContent(symbol: airSymbol, text: "", aqiText: "\(aqi)", band: band, stale: stale)
            }
        }
    }

    /// "29°" → ("29", "°"); "219" → ("219", ""). A string with no digits ("—") is all number,
    /// so it right-aligns with the digits above or below it.
    static func splitTrailingUnit(_ string: String) -> (number: String, unit: String) {
        guard let lastDigit = string.lastIndex(where: \.isNumber) else { return (string, "") }
        let end = string.index(after: lastDigit)
        return (String(string[..<end]), String(string[end...]))
    }
}
