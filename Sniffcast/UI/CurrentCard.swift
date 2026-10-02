import SwiftUI

struct CurrentCard: View {
    let snapshot: Snapshot
    let settings: SettingsStore

    var body: some View {
        let current = snapshot.current
        let scale = settings.aqiScale
        HStack(alignment: .center, spacing: 12) {
            WeatherSymbol(name: WeatherCode.symbol(current.weatherCode, isDay: current.isDay,
                                                   date: snapshot.fetchedAt, latitude: snapshot.latitude,
                                                   phaseOnPartlyCloudy: settings.moonPhaseOnPartlyCloudy))
                .font(.system(size: 34))
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(Units.formatTemperature(current.temperature, in: settings.temperatureUnit))
                    .font(.system(size: 30, weight: .medium).monospacedDigit())
                Text(WeatherCode.description(current.weatherCode))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let aqi = snapshot.air?.aqi(scale) {
                let band = AQIScale.band(for: aqi, scale: scale)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("AQI \(aqi)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AQIColors.color(band))
                    Text(AQIScale.label(for: band, scale: scale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        HStack(spacing: 14) {
            Label("Feels \(Units.formatTemperature(current.apparentTemperature, in: settings.temperatureUnit))",
                  systemImage: "thermometer.medium")
            Label("\(current.humidity)%", systemImage: "humidity")
            Label(Units.formatWind(current.windSpeed, in: settings.windUnit), systemImage: "wind")
            // Hidden at night and under heavy cloud, when it would just read "UV 0".
            if let uv = current.uvIndex, UVIndex.rounded(uv) > 0 {
                let level = UVIndex.level(for: uv)
                Label("UV \(UVIndex.rounded(uv))", systemImage: "sun.max")
                    .foregroundStyle(AQIColors.color(level.band))
                    .accessibilityLabel("UV index \(UVIndex.rounded(uv)), \(level.label)")
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }
}
