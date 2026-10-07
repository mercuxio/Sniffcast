import Foundation

/// The WAQI real-time AQI tile layer drawn over the panel's map. Needs the user's own free token.
enum AQIMap {
    static let attribution = "Air Quality Tiles © waqi.info"
    static let tokenRequestURL = URL(string: "https://aqicn.org/data-platform/token/")!

    /// MapKit's `{z}/{x}/{y}` template for the composite US EPA AQI layer, or nil without a usable token.
    static func tileTemplate(token: String) -> String? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return "https://tiles.aqicn.org/tiles/usepa-aqi/{z}/{x}/{y}.png?token=\(encoded)"
    }
}
