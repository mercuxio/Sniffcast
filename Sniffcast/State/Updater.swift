import Foundation
import Sparkle

/// Wraps Sparkle so the rest of the app sees a small observable: check now, and the auto-check switch.
/// Updates come from the appcast named by `SUFeedURL` and are verified against `SUPublicEDKey`.
@MainActor
@Observable
final class Updater {
    @ObservationIgnored private let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var automaticallyChecks: Bool {
        get { access(keyPath: \.automaticallyChecks); return controller.updater.automaticallyChecksForUpdates }
        set {
            withMutation(keyPath: \.automaticallyChecks) { controller.updater.automaticallyChecksForUpdates = newValue }
        }
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }
}
