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
    private let updater = Updater()

    private var statusItem: StatusItemController?
    private var popover: PopoverController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
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
                                 alerts: alerts, state: state, provider: provider, updater: updater))
        }

        scheduler.start()
        if settings.alertsEnabled { Task { await alerts.requestAuthorizationIfNeeded() } }
    }

    /// Location Services run only while "Current Location" is the active selection.
    private func wireLocation() {
        locationProvider.onUpdate = { [unowned self] coordinate in
            state.currentCoordinate = coordinate
            locations.lastCurrentCoordinate = coordinate
        }
        locationProvider.seed(locations.lastCurrentCoordinate)
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

    /// An accessory app has no menu bar of its own, so the standard editing shortcuts (⌘V, ⌘C,
    /// ⌘X, ⌘A, ⌘Z) have nothing to dispatch to and text fields, such as the token field in
    /// Settings, can't be pasted into. A main menu with an Edit menu restores them; it is never
    /// shown because the app stays out of the menu bar and Dock.
    private func installEditMenu() {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = edit
        let main = NSMenu()
        main.addItem(NSMenuItem(title: "", action: nil, keyEquivalent: ""))
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}
