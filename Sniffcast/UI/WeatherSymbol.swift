import AppKit
import SwiftUI

/// A weather symbol for the dropdown.
///
/// Most weather symbols carry their own multicolor palette. The moon phases have none, so
/// multicolor draws them in the text color, which makes a full moon a black disc in light
/// mode. They get a palette instead: the lit part in moonlight, the shadow faint.
struct WeatherSymbol: View {
    let name: String

    var body: some View {
        if name.hasPrefix("moonphase.") {
            Image(systemName: name)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Self.moonlight, Self.moonShadow)
        } else {
            Image(systemName: name)
                .symbolRenderingMode(.multicolor)
        }
    }

    /// Gold on a light background, where cream washes out; cream on a dark one.
    static let moonlight = Color(nsColor: NSColor(name: "moonlight") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1, green: 0xF1 / 255, blue: 0xC4 / 255, alpha: 1)
            : NSColor(srgbRed: 0xE3 / 255, green: 0xB0 / 255, blue: 0x2E / 255, alpha: 1)
    })

    static let moonShadow = Color(nsColor: NSColor(name: "moonShadow") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1, alpha: 0.18)
            : NSColor(white: 0, alpha: 0.14)
    })
}
