import Foundation

enum AQIScaleKind: String, CaseIterable, Sendable {
    case us, eu
}

/// Six severity bands shared by both scales, so colors and alerts can be scale-agnostic.
/// The EU scale's names differ (Good, Fair, Moderate, Poor, Very poor, Extremely poor).
enum AQIBand: Int, CaseIterable, Sendable, Comparable {
    case good, moderate, sensitive, unhealthy, veryUnhealthy, hazardous

    static func < (lhs: AQIBand, rhs: AQIBand) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum AQIScale {
    /// Inclusive upper bounds of the first five bands; anything above is `.hazardous`.
    private static func upperBounds(_ scale: AQIScaleKind) -> [Int] {
        switch scale {
        case .us: [50, 100, 150, 200, 300]
        case .eu: [20, 40, 60, 80, 100]
        }
    }

    static func band(for value: Int, scale: AQIScaleKind) -> AQIBand {
        let index = upperBounds(scale).firstIndex { value <= $0 } ?? 5
        return AQIBand(rawValue: index)!
    }

    static func label(for band: AQIBand, scale: AQIScaleKind) -> String {
        switch scale {
        case .us:
            ["Good", "Moderate", "Unhealthy for sensitive groups", "Unhealthy", "Very unhealthy", "Hazardous"][band.rawValue]
        case .eu:
            ["Good", "Fair", "Moderate", "Poor", "Very poor", "Extremely poor"][band.rawValue]
        }
    }

    static func defaultThreshold(_ scale: AQIScaleKind) -> Int {
        scale == .us ? 100 : 60
    }

    /// Hysteresis margin: an alert re-arms only once AQI falls to threshold − margin.
    static func rearmMargin(_ scale: AQIScaleKind) -> Int {
        scale == .us ? 10 : 5
    }
}
