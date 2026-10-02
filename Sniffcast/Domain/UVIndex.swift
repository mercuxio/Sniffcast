import Foundation

/// WHO / EPA exposure categories. The index is shown as a whole number, so the category
/// follows the rounded value: 2.6 reads "UV 3" and is Moderate.
enum UVIndex {
    static func rounded(_ value: Double) -> Int { Int(value.rounded()) }

    /// Colors reuse the AQI bands: green, yellow, orange, red, purple.
    /// The UV level at which sun protection starts to matter.
    static let protectionThreshold = 3

    /// "3–9": from the protection threshold up to the day's peak. Below the threshold there is
    /// no range, just the peak.
    static func rangeLabel(peak: Double) -> String {
        let high = rounded(peak)
        return high > protectionThreshold ? "\(protectionThreshold)–\(high)" : "\(high)"
    }

    static func level(for value: Double) -> (label: String, band: AQIBand) {
        switch rounded(value) {
        case ..<3: ("Low", .good)
        case 3...5: ("Moderate", .moderate)
        case 6...7: ("High", .sensitive)
        case 8...10: ("Very high", .unhealthy)
        default: ("Extreme", .veryUnhealthy)
        }
    }
}
