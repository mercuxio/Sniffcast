import Foundation

/// Threshold alerts with hysteresis, tracked per key (location).
/// Fires once when AQI reaches the threshold; re-arms only after it drops to threshold − margin,
/// so AQI hovering around the threshold never produces a notification storm.
struct AlertEvaluator: Sendable {
    private var disarmed: Set<String> = []

    mutating func evaluate(aqi: Int, threshold: Int, margin: Int, key: String) -> Bool {
        if disarmed.contains(key) {
            if aqi <= threshold - margin { disarmed.remove(key) }
            return false
        }
        guard aqi >= threshold else { return false }
        disarmed.insert(key)
        return true
    }

    mutating func reset() { disarmed.removeAll() }
}
