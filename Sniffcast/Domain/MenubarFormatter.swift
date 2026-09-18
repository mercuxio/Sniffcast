import Foundation

enum MenubarStyle: String, CaseIterable, Sendable, Identifiable {
    case full, twoRows, compact, rotating
    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: "Full"
        case .twoRows: "Two Rows"
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
    /// Temperature over AQI in two rows (full style), instead of side by side.
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
        monochrome: Bool = false
    ) -> MenubarContent {
        guard let snapshot else {
            return MenubarContent(symbol: placeholderSymbol, text: "—", aqiText: nil, band: nil, stale: stale)
        }
        let symbol = WeatherCode.symbol(snapshot.current.weatherCode, isDay: snapshot.current.isDay)
        let temp = Units.formatTemperature(snapshot.current.temperature, in: temperatureUnit)
        let aqi = snapshot.air?.aqi(scale)
        let band = monochrome ? nil : aqi.map { AQIScale.band(for: $0, scale: scale) }

        let weatherOnly = MenubarContent(symbol: symbol, text: temp, aqiText: nil, band: nil, stale: stale)
        guard let aqi else { return weatherOnly }

        switch style {
        case .full:
            return MenubarContent(symbol: symbol, text: temp, aqiText: "AQI \(aqi)", band: band, stale: stale)
        case .twoRows:
            // Stacked under the temperature, the color and position say "AQI"; the label doesn't need to.
            return MenubarContent(symbol: symbol, text: temp, aqiText: "\(aqi)", band: band, stacked: true, stale: stale)
        case .compact:
            // Without color the dot carries no information, so show the number instead.
            return MenubarContent(symbol: symbol, text: temp, aqiText: monochrome ? "\(aqi)" : "●", band: band, stale: stale)
        case .rotating:
            switch phase {
            case .weather: return weatherOnly
            case .air: return MenubarContent(symbol: airSymbol, text: "", aqiText: "\(aqi)", band: band, stale: stale)
            }
        }
    }
}
