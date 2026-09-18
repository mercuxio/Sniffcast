import AppKit
import SwiftUI

/// Band colors, tuned separately for light and dark appearances so the menubar text keeps
/// at least 3:1 contrast against either menubar (spec §4). Resolved lazily at draw time.
enum AQIColors {
    private static let light: [NSColor] = [
        rgb(0x1E8E3E), rgb(0xA67C00), rgb(0xD9660A), rgb(0xD12B20), rgb(0x8E24AA), rgb(0x7E0023),
    ]
    private static let dark: [NSColor] = [
        rgb(0x34C759), rgb(0xFFD60A), rgb(0xFF9F0A), rgb(0xFF453A), rgb(0xBF5AF2), rgb(0xE0607E),
    ]

    private static let cache: [NSColor] = AQIBand.allCases.map { band in
        NSColor(name: "aqi.\(band.rawValue)") { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark[band.rawValue] : light[band.rawValue]
        }
    }

    static func nsColor(_ band: AQIBand) -> NSColor { cache[band.rawValue] }
    static func color(_ band: AQIBand) -> Color { Color(nsColor: nsColor(band)) }

    private static func rgb(_ hex: Int) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
