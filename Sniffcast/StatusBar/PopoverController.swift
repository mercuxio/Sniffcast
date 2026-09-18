import AppKit
import SwiftUI

/// Owns the dropdown. The SwiftUI hierarchy is built each time the popover opens and
/// released when it closes, so SwiftUI/Charts memory isn't retained while idle.
@MainActor
final class PopoverController: NSObject, NSPopoverDelegate {
    var onShow: (() -> Void)?
    private let makeContent: () -> AnyView
    private var popover: NSPopover?

    init(makeContent: @escaping () -> AnyView) {
        self.makeContent = makeContent
    }

    var isShown: Bool { popover?.isShown ?? false }

    func toggle(from button: NSStatusBarButton) {
        if isShown { close() } else { show(from: button) }
    }

    func close() {
        popover?.performClose(nil)
    }

    private func show(from button: NSStatusBarButton) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let hosting = NSHostingController(rootView: makeContent())
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        self.popover = popover
        onShow?()
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func popoverDidClose(_ notification: Notification) {
        popover?.contentViewController = nil
        popover = nil
    }
}
