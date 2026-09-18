import Charts
import SwiftUI

/// Next 12 hours: a temperature sparkline drawn over evenly spaced columns so each
/// point sits directly above its hour label.
struct HourlyChart: View {
    let snapshot: Snapshot
    let settings: SettingsStore

    var body: some View {
        let points = Array(snapshot.hourly.prefix(12))
        let unit = settings.temperatureUnit
        let temps = points.map { Units.temperature($0.temperature, in: unit) }
        let low = (temps.min() ?? 0) - 1, high = (temps.max() ?? 1) + 1

        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Next 12 hours")
            Chart(Array(points.enumerated()), id: \.offset) { index, point in
                LineMark(x: .value("Hour", Double(index) + 0.5),
                         y: .value("Temp", Units.temperature(point.temperature, in: unit)))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.orange)
                PointMark(x: .value("Hour", Double(index) + 0.5),
                          y: .value("Temp", Units.temperature(point.temperature, in: unit)))
                    .symbolSize(12)
                    .foregroundStyle(.orange)
            }
            .chartXScale(domain: 0...Double(max(points.count, 1)))
            .chartYScale(domain: low...high)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 34)
            .accessibilityHidden(true)

            HStack(spacing: 0) {
                ForEach(points) { point in
                    VStack(spacing: 3) {
                        Text(Units.formatTemperature(point.temperature, in: unit))
                            .font(.caption.weight(.medium).monospacedDigit())
                        Image(systemName: WeatherCode.symbol(
                            point.weatherCode, isDay: isDay(point.time), date: point.time,
                            latitude: snapshot.latitude, phaseOnPartlyCloudy: settings.moonPhaseOnPartlyCloudy))
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 12))
                            .frame(height: 14)
                        if let aqi = point.aqi(settings.aqiScale) {
                            Circle()
                                .fill(AQIColors.color(AQIScale.band(for: aqi, scale: settings.aqiScale)))
                                .frame(width: 5, height: 5)
                        } else {
                            Color.clear.frame(width: 5, height: 5)
                        }
                        Text(Formatting.hour(point.time, in: snapshot.timeZone))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(point))
                }
            }
        }
    }

    private func isDay(_ date: Date) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = snapshot.timeZone
        let hour = calendar.component(.hour, from: date)
        return (6..<20).contains(hour)
    }

    private func accessibilityLabel(_ point: HourlyPoint) -> String {
        var text = "\(Formatting.hour(point.time, in: snapshot.timeZone)), "
            + "\(Units.formatTemperature(point.temperature, in: settings.temperatureUnit)), "
            + WeatherCode.description(point.weatherCode)
        if let aqi = point.aqi(settings.aqiScale) { text += ", AQI \(aqi)" }
        return text
    }
}
