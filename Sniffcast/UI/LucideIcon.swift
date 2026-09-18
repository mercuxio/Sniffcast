import AppKit

/// A Lucide glyph, transcribed from the upstream SVG.
///
/// Copied from Squiggle's `LucideIcon.swift` (itself from Pitch, from InOut) so the
/// footer icons match Squiggle's exactly. Geometry is Lucide's 24-unit grid, y down,
/// drawn into a flipped image context.
struct LucideIcon {
    /// Appends the glyph in Lucide's own 24-unit space.
    let trace: (NSBezierPath) -> Void

    static let grid: CGFloat = 24
    /// Lucide's own stroke width, in grid units.
    static let strokeUnits: CGFloat = 2

    /// lucide/icons/coffee.svg
    static var coffee: LucideIcon {
        LucideIcon { path in
            // "M16 8a1 1 0 0 1 1 1v8a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V9a1 1 0 0 1
            //  1-1h14a4 4 0 1 1 0 8h-1" — the cup, as one unbroken subpath.
            //
            // Tangent arcs, not centre-and-angle ones: a tangent arc is
            // specified by the corner it rounds, so the question of which way it
            // sweeps never arises. Every radius equals the distance from its
            // corner to the neighbouring vertex, so each tangent point lands
            // exactly on a vertex.
            path.move(to: CGPoint(x: 16, y: 8))
            path.appendArc(  // top-right lip
                from: CGPoint(x: 17, y: 8), to: CGPoint(x: 17, y: 17), radius: 1)
            path.appendArc(  // bottom-right of the cup
                from: CGPoint(x: 17, y: 21), to: CGPoint(x: 7, y: 21), radius: 4)
            path.appendArc(  // bottom-left of the cup
                from: CGPoint(x: 3, y: 21), to: CGPoint(x: 3, y: 9), radius: 4)
            path.appendArc(  // top-left lip
                from: CGPoint(x: 3, y: 8), to: CGPoint(x: 18, y: 8), radius: 1)
            path.line(to: CGPoint(x: 18, y: 8))

            // The handle: endpoints 8 apart on a radius of 4, so an exact
            // half-circle about (18,12). Increasing angle passes through 0
            // degrees — rightwards — which is the side the handle bulges.
            path.appendArc(
                withCenter: CGPoint(x: 18, y: 12),
                radius: 4,
                startAngle: 270,
                endAngle: 450,
                clockwise: false)
            path.line(to: CGPoint(x: 17, y: 16))

            // "M6 2v2", "M10 2v2", "M14 2v2" — steam.
            for x in [6.0, 10.0, 14.0] as [CGFloat] {
                path.move(to: CGPoint(x: x, y: 2))
                path.line(to: CGPoint(x: x, y: 4))
            }
        }
    }

    /// lucide/icons/log-out.svg
    static var logOut: LucideIcon {
        LucideIcon { path in
            // "m16 17 5-5-5-5" — the arrowhead.
            path.move(to: CGPoint(x: 16, y: 17))
            path.line(to: CGPoint(x: 21, y: 12))
            path.line(to: CGPoint(x: 16, y: 7))

            // "M21 12H9" — its shaft.
            path.move(to: CGPoint(x: 21, y: 12))
            path.line(to: CGPoint(x: 9, y: 12))

            // "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" — the open side of the
            // door, as a bracket with two tangent-arc corners.
            path.move(to: CGPoint(x: 9, y: 21))
            path.appendArc(from: CGPoint(x: 3, y: 21), to: CGPoint(x: 3, y: 5), radius: 2)
            path.appendArc(from: CGPoint(x: 3, y: 3), to: CGPoint(x: 9, y: 3), radius: 2)
            path.line(to: CGPoint(x: 9, y: 3))
        }
    }

    /// lucide/icons/plus.svg
    static var plus: LucideIcon {
        LucideIcon { path in
            // "M5 12h14" and "M12 5v14". Two strokes, and the only glyph in the
            // set with nothing to approximate.
            path.move(to: CGPoint(x: 5, y: 12))
            path.line(to: CGPoint(x: 19, y: 12))
            path.move(to: CGPoint(x: 12, y: 5))
            path.line(to: CGPoint(x: 12, y: 19))
        }
    }

    /// lucide/icons/refresh-cw.svg
    ///
    /// The one transcription here that is not exact. Lucide draws each half of
    /// the ring as a 9-radius quarter followed by a 9.75-radius sliver, which
    /// puts its arrow roots about 0.15 units outside the circle the rest of the
    /// stroke follows. At a 13pt render that is a fifth of a pixel, so both
    /// halves are drawn as plain arcs on the 9-radius circle instead.
    static var refreshCw: LucideIcon {
        LucideIcon { path in
            // "M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" — from the
            // left of the ring, over the top, to the root of the upper arrow.
            path.appendArc(
                withCenter: CGPoint(x: 12, y: 12),
                radius: 9,
                startAngle: 180,
                endAngle: 317,
                clockwise: false)
            path.line(to: CGPoint(x: 21, y: 8))

            // "M21 3v5h-5" — the upper arrowhead, an open corner.
            path.move(to: CGPoint(x: 21, y: 3))
            path.line(to: CGPoint(x: 21, y: 8))
            path.line(to: CGPoint(x: 16, y: 8))

            // "M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" — the same
            // sweep rotated half a turn.
            path.move(to: CGPoint(x: 21, y: 12))
            path.appendArc(
                withCenter: CGPoint(x: 12, y: 12),
                radius: 9,
                startAngle: 0,
                endAngle: 137,
                clockwise: false)
            path.line(to: CGPoint(x: 3, y: 16))

            // "M8 16H3v5" — the lower arrowhead.
            path.move(to: CGPoint(x: 8, y: 16))
            path.line(to: CGPoint(x: 3, y: 16))
            path.line(to: CGPoint(x: 3, y: 21))
        }
    }

    /// A template image of this glyph, stroked at `size` points.
    ///
    /// Template, so the button tints it the same way it tints the SF Symbol
    /// beside it — otherwise the gear would follow the theme and these would not.
    ///
    /// - Parameter weight: optical correction against SF Symbols, which carry a
    ///   little more weight than Lucide at the same nominal size. InOut uses
    ///   1.15 for exactly this reason, and the gear sits next to these icons
    ///   here too.
    func image(size: CGFloat, weight: CGFloat = 1.15) -> NSImage {
        let image = NSImage(
            size: NSSize(width: size, height: size), flipped: true
        ) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            defer { context.restoreGState() }

            // Draw through the CTM rather than transforming the path, so the
            // stroke scales with it. That lets the line width stay Lucide's
            // literal 2 grid units instead of a point value that would have to
            // be recomputed for every size.
            let scale = min(rect.width, rect.height) / LucideIcon.grid
            context.translateBy(x: rect.midX, y: rect.midY)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -LucideIcon.grid / 2, y: -LucideIcon.grid / 2)

            let path = NSBezierPath()
            self.trace(path)
            path.lineWidth = LucideIcon.strokeUnits * weight
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
