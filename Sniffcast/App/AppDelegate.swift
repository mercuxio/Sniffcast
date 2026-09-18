import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let coffeeURL = URL(string: "https://buymeacoffee.com/benjamintan")!
    private static let locationPrivacyURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!

    private let state = AppState()
    private let settings = SettingsStore()
    private let locations = LocationsStore()
    private let provider = OpenMeteoClient()
    private lazy var alerts = AlertService(settings: settings)
    private lazy var scheduler = RefreshScheduler(
        state: state, settings: settings, locations: locations, provider: provider, alerts: alerts)
    private let locationProvider = LocationProvider()

    private var statusItem: StatusItemController?
    private var popover: PopoverController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        wireLocation()

        let popover = PopoverController { [unowned self] in AnyView(self.panel()) }
        popover.onShow = { [unowned self] in scheduler.refreshOnPanelOpen() }
        self.popover = popover

        let statusItem = StatusItemController(state: state, settings: settings)
        statusItem.onClick = { [unowned self, unowned statusItem] in
            guard let button = statusItem.item.button else { return }
            self.popover?.toggle(from: button)
        }
        self.statusItem = statusItem

        settingsWindow = SettingsWindowController { [unowned self] navigation in
            AnyView(SettingsView(navigation: navigation, settings: settings, locations: locations,
                                 alerts: alerts, state: state, provider: provider))
        }

        scheduler.start()
        if settings.alertsEnabled { Task { await alerts.requestAuthorizationIfNeeded() } }
    }

    /// Location Services run only while "Current Location" is the active selection.
    private func wireLocation() {
        locationProvider.onUpdate = { [unowned self] coordinate in state.currentCoordinate = coordinate }
        locationProvider.onStatus = { [unowned self] status in state.locationStatus = status }
        locationProvider.onPlaceName = { [unowned self] name in locations.currentName = name }
        Sniffcast.observe { [locations] in locations.active } apply: { [unowned self] active in
            if active == .current { locationProvider.start() } else { locationProvider.stop() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.locationProvider.requestFix() }
        }
    }

    private func panel() -> some View {
        PanelView(state: state, settings: settings, locations: locations, actions: PanelActions(
            openSettings: { [unowned self] tab in
                popover?.close()
                settingsWindow?.show(tab: tab)
            },
            refresh: { [unowned self] in scheduler.refreshNow() },
            buyCoffee: { [unowned self] in
                // Close first so the panel doesn't sit over the browser window.
                popover?.close()
                NSWorkspace.shared.open(Self.coffeeURL)
            },
            quit: { NSApp.terminate(nil) },
            openLocationSettings: { [unowned self] in
                popover?.close()
                NSWorkspace.shared.open(Self.locationPrivacyURL)
            }))
    }
}
