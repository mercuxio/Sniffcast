// Renders the app icon into a .iconset directory, which `scripts/make-icon.sh`
// then hands to `iconutil` to produce Sniffcast/Resources/AppIcon.icns.
//
// A standalone script, not a target: it is build tooling, run when the icon
// changes, and the .icns it produces is committed.
//
// The glyph is Lucide's `cloud-sun` (https://lucide.dev/icons/cloud-sun, ISC
// license), transcribed from its SVG path data. The two SVG arcs are written
// as centre + angles, worked out from the endpoints and radii in the source.
//
// Usage: swift Tools/GenerateIcon.swift <output.iconset>

import AppKit
import Foundation

private enum Tile {
    /// Proportions of the macOS icon grid, matching Squiggle's icon: the
    /// rounded square takes the middle ~80% of the canvas.
    static let inset: CGFloat = 100.0 / 1024.0
    static let cornerRadius: CGFloat = 185.0 / 1024.0
    static let glyphFraction: CGFloat = 0.66

    static let top = NSColor(srgbRed: 0.106, green: 0.184, blue: 0.290, alpha: 1)
    static let bottom = NSColor(srgbRed: 0.035, green: 0.055, blue: 0.098, alpha: 1)
    static let sun = NSColor(srgbRed: 0.980, green: 0.780, blue: 0.330, alpha: 1)
    static let cloud = NSColor(srgbRed: 0.925, green: 0.945, blue: 0.965, alpha: 1)
}

/// Lucide's 24-unit viewBox, in SVG coordinates (y grows downward).
private enum Glyph {
    static let viewBox: CGFloat = 24
    static let strokeWidth: CGFloat = 2

    private static func degrees(_ d: CGFloat) -> CGFloat { d * .pi / 180 }

    /// Rays plus the part of the sun that shows above the cloud.
    static var sun: CGPath {
        let p = CGMutablePath()
        // M12 2v2
        p.move(to: CGPoint(x: 12, y: 2)); p.addLine(to: CGPoint(x: 12, y: 4))
        // m4.93 4.93 1.41 1.41
        p.move(to: CGPoint(x: 4.93, y: 4.93)); p.addLine(to: CGPoint(x: 6.34, y: 6.34))
        // M20 12h2
        p.move(to: CGPoint(x: 20, y: 12)); p.addLine(to: CGPoint(x: 22, y: 12))
        // m19.07 4.93-1.41 1.41
        p.move(to: CGPoint(x: 19.07, y: 4.93)); p.addLine(to: CGPoint(x: 17.66, y: 6.34))
        // M15.947 12.65a4 4 0 0 0-5.925-4.128: radius 4 about (12, 12), sweep 0,
        // so the angle decreases (in y-down space) from 9.35° to -119.6°.
        p.move(to: CGPoint(x: 15.947, y: 12.65))
        p.addArc(center: CGPoint(x: 12, y: 12), radius: 4,
                 startAngle: atan2(0.65, 3.947), endAngle: atan2(-3.478, -1.978), clockwise: true)
        return p
    }

    /// M13 22H7a5 5 0 1 1 4.9-6H13a3 3 0 0 1 0 6Z
    static var cloud: CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 13, y: 22))
        p.addLine(to: CGPoint(x: 7, y: 22))
        // Large arc, radius 5 about (7, 17), sweep 1: 90° round through the left
        // and top to -11.5° (the point 11.9, 16).
        p.addArc(center: CGPoint(x: 7, y: 17), radius: 5,
                 startAngle: degrees(90), endAngle: atan2(-1, 4.9) + 2 * .pi, clockwise: false)
        p.addLine(to: CGPoint(x: 13, y: 16))
        // Radius 3 about (13, 19), sweep 1: from the top round the right side.
        p.addArc(center: CGPoint(x: 13, y: 19), radius: 3,
                 startAngle: degrees(-90), endAngle: degrees(90), clockwise: false)
        p.closeSubpath()
        return p
    }
}

private func render(pixels: Int) -> NSBitmapImageRep? {
    let side = CGFloat(pixels)
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: rep)
    else { return nil }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    context.shouldAntialias = true

    let inset = side * Tile.inset
    let tile = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let radius = side * Tile.cornerRadius
    NSGradient(starting: Tile.bottom, ending: Tile.top)?
        .draw(in: NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius), angle: 90)

    // Map the viewBox onto a square centred in the tile, flipping y because
    // the SVG grows downward and the bitmap context grows upward.
    let box = tile.width * Tile.glyphFraction
    let scale = box / Glyph.viewBox
    var transform = CGAffineTransform(translationX: tile.midX - box / 2, y: tile.midY + box / 2)
        .scaledBy(x: scale, y: -scale)

    let cg = context.cgContext
    cg.setLineCap(.round)
    cg.setLineJoin(.round)
    // Lucide's stroke is 2 of 24 units. Below about 32 px that falls under a
    // pixel and the glyph fades, so hold it at one pixel minimum.
    cg.setLineWidth(max(Glyph.strokeWidth * scale, 1))

    for (path, color) in [(Glyph.sun, Tile.sun), (Glyph.cloud, Tile.cloud)] {
        guard let placed = path.copy(using: &transform) else { return nil }
        cg.addPath(placed)
        cg.setStrokeColor(color.cgColor)
        cg.strokePath()
    }
    return rep
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: GenerateIcon.swift <output.iconset>\n".utf8))
    exit(2)
}
let output = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for multiplier in [1, 2] {
        let name = multiplier == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        guard let rep = render(pixels: points * multiplier),
              let png = rep.representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("failed to render \(name)\n".utf8))
            exit(1)
        }
        try png.write(to: output.appendingPathComponent(name))
    }
}
