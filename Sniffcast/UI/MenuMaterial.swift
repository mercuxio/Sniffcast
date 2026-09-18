import AppKit
import SwiftUI

/// The `.menu` vibrancy material Squiggle's dropdown uses. `NSPopover`'s own `.popover`
/// material is noticeably more see-through; drawing this behind the panel makes the two
/// apps' dropdowns read at the same density.
struct MenuMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
