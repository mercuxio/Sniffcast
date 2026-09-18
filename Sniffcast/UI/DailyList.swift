import SwiftUI

struct DailyList: View {
    let snapshot: Snapshot
    let settings: SettingsStore

    var body: some View {
        let unit = settings.temperatureUnit
        let lows = snapshot.daily.map(\.low), highs = snapshot.daily.map(\.high)
        let range = (lows.min() ?? 0)...(max(highs.max() ?? 1, (lows.min() ?? 0) + 1))

        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "7 days")
            ForEach(snapshot.daily) { day in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(Formatting.weekday(day.date, in: snapshot.timeZone))
                            .frame(width: 44, alignment: .leading)
                        Image(systemName: WeatherCode.symbol(day.weatherCode, isDay: true))
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 20)
                        Text(Units.formatTemperature(day.low, in: unit))
                            .foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .trailing)
                        RangeBar(range: range, low: day.low, high: day.high)
                        Text(Units.formatTemperature(day.high, in: unit))
                            .frame(width: 34, alignment: .leading)
                    }
                    .font(.callout.monospacedDigit())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(Formatting.weekday(day.date, in: snapshot.timeZone)), "
                        + "\(WeatherCode.description(day.weatherCode)), low "
                        + "\(Units.formatTemperature(day.low, in: unit)), high \(Units.formatTemperature(day.high, in: unit))")

                    if let pollen = day.pollen, !pollen.entries.isEmpty {
                        PollenRow(entries: pollen.entries)
                            .padding(.leading, 52)
                    }
                }
            }
        }
    }
}

private struct RangeBar: View {
    let range: ClosedRange<Double>
    let low: Double
    let high: Double

    var body: some View {
        GeometryReader { proxy in
            let span = range.upperBound - range.lowerBound
            let start = (low - range.lowerBound) / span * proxy.size.width
            let width = max((high - low) / span * proxy.size.width, 4)
            Capsule().fill(.quaternary)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [.teal, .orange], startPoint: .leading, endPoint: .trailing))
                        .frame(width: width)
                        .offset(x: start)
                }
        }
        .frame(height: 4)
    }
}

/// Only species with a notable count are listed, highest first.
private struct PollenRow: View {
    let entries: [Pollen.Entry]

    var body: some View {
        let notable = entries.filter { $0.value >= 1 }.sorted { $0.value > $1.value }.prefix(3)
        if !notable.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "leaf").foregroundStyle(.secondary)
                ForEach(Array(notable), id: \.name) { entry in
                    let level = Formatting.pollenLevel(entry.value)
                    HStack(spacing: 3) {
                        Circle().fill(AQIColors.color(level.band)).frame(width: 5, height: 5)
                        Text("\(entry.name) \(level.label.lowercased())")
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Pollen: " + notable.map { "\($0.name) \(Formatting.pollenLevel($0.value).label)" }
                .joined(separator: ", "))
        }
    }
}
