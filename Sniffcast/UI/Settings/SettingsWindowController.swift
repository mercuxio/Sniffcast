import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsNavigation {
    var tab: SettingsTab = .general
}

/// AppKit-owned settings window, created on demand and released on close (spec §8).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let navigation = SettingsNavigation()
    private let makeContent: (SettingsNavigation) -> AnyView

    init(makeContent: @escaping (SettingsNavigation) -> AnyView) {
        self.makeContent = makeContent
    }

    func show(tab: SettingsTab) {
        navigation.tab = tab
        if window == nil {
            let hosting = NSHostingController(rootView: makeContent(navigation))
            hosting.sizingOptions = .preferredContentSize
            let window = NSWindow(contentViewController: hosting)
            window.title = "Sniffcast Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Drop the SwiftUI hierarchy; the next `show` builds a fresh one.
        window?.contentViewController = nil
        window = nil
    }
}
