import AppKit

// Pure AppKit entry point: no SwiftUI App/Scene machinery, which keeps idle memory low.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
