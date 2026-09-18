import Foundation
import Observation
import UserNotifications

/// Evaluates the AQI threshold inline after each refresh (no timers) and posts a notification.
@MainActor
@Observable
final class AlertService {
    private(set) var notificationsDenied = false

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var evaluator = AlertEvaluator()
    @ObservationIgnored private var lastScale: AQIScaleKind

    init(settings: SettingsStore) {
        self.settings = settings
        lastScale = settings.aqiScale
    }

    func handle(snapshot: Snapshot, key: String, locationName: String) {
        let scale = settings.aqiScale
        if scale != lastScale {
            // Hysteresis state from one scale means nothing on the other.
            evaluator.reset()
            lastScale = scale
        }
        guard settings.alertsEnabled, let aqi = snapshot.air?.aqi(scale) else { return }
        let fire = evaluator.evaluate(
            aqi: aqi, threshold: settings.alertThreshold, margin: AQIScale.rearmMargin(scale), key: key)
        guard fire else { return }
        let label = AQIScale.label(for: AQIScale.band(for: aqi, scale: scale), scale: scale)
        Task { await post(title: "Air quality: \(label)", body: "AQI \(aqi) in \(locationName)", key: key) }
    }

    /// Called when the user turns alerts on. Never prompts again once decided.
    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            notificationsDenied = !granted
        case .denied:
            notificationsDenied = true
        default:
            notificationsDenied = false
        }
    }

    private func post(title: String, body: String, key: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // Same identifier per location: a newer alert replaces an older one in Notification Center.
        let request = UNNotificationRequest(identifier: "aqi.\(key)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
