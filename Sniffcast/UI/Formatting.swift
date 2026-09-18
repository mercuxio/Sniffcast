import Foundation

/// Display helpers for the panel. Times are shown in the location's own time zone.
enum Formatting {
    static func hour(_ date: Date, in zone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .narrow))
        style.timeZone = zone
        return date.formatted(style)
    }

    static func weekday(_ date: Date, in zone: TimeZone, now: Date = .now) -> String {
        var calendar = Calendar.current
        calendar.timeZone = zone
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated)
        style.timeZone = zone
        return date.formatted(style)
    }

    static func concentration(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value < 10 ? value.formatted(.number.precision(.fractionLength(1))) : String(Int(value.rounded()))
    }

    /// Rough pollen level buckets (grains/m³) shared across species.
    static func pollenLevel(_ value: Double) -> (label: String, band: AQIBand) {
        switch value {
        case ..<1: ("None", .good)
        case ..<20: ("Low", .good)
        case ..<50: ("Moderate", .moderate)
        case ..<200: ("High", .sensitive)
        default: ("Very high", .unhealthy)
        }
    }

    static func updated(_ date: Date, now: Date = .now) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        switch minutes {
        case ..<1: return "Updated just now"
        case ..<60: return "Updated \(minutes) min ago"
        default:
            let hours = minutes / 60
            return "Updated \(hours) h ago"
        }
    }
}
