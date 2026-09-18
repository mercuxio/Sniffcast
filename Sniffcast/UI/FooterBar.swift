import AppKit
import SwiftUI

/// The icon row at the bottom of the panel, matching Squiggle's `MenuFooterView`
/// metrics exactly so the two apps look like siblings in the menubar.
struct FooterBar: View {
    enum Command: CaseIterable {
        case settings, addLocation, refresh, buyCoffee, quit

        var title: String {
            switch self {
            case .settings: "Settings…"
            case .addLocation: "Add Location…"
            case .refresh: "Refresh Now"
            case .buyCoffee: "Buy me a coffee"
            case .quit: "Quit Sniffcast"
            }
        }

        var image: NSImage? {
            switch self {
            case .settings:
                NSImage(systemSymbolName: "gearshape", accessibilityDescription: title)?
                    .withSymbolConfiguration(.init(pointSize: Metrics.glyph, weight: .regular))
            case .addLocation: LucideIcon.plus.image(size: Metrics.glyph)
            case .refresh: LucideIcon.refreshCw.image(size: Metrics.glyph)
            case .buyCoffee: LucideIcon.coffee.image(size: Metrics.glyph)
            case .quit: LucideIcon.logOut.image(size: Metrics.glyph)
            }
        }
    }

    enum Metrics {
        static let height: CGFloat = 31
        static let visibleInset: CGFloat = 14
        static let spacing: CGFloat = 2
        static let glyph: CGFloat = 13
        static let hitSlop: CGFloat = 4
    }

    static let leading: [Command] = [.settings, .addLocation, .refresh, .buyCoffee]

    let isRefreshing: Bool
    let perform: (Command) -> Void

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            ForEach(Self.leading, id: \.self) { command in
                FooterButton(command: command,
                             spinning: command == .refresh && isRefreshing,
                             action: { perform(command) })
            }
            Spacer(minLength: 0)
            FooterButton(command: .quit, spinning: false, action: { perform(.quit) })
        }
        .padding(.horizontal, Metrics.visibleInset - Metrics.hitSlop)
        .frame(height: Metrics.height)
    }
}

private struct FooterButton: View {
    let command: FooterBar.Command
    let spinning: Bool
    let action: () -> Void

    @State private var hovering = false
    @State private var angle: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let turnSeconds = 0.9

    var body: some View {
        let side = FooterBar.Metrics.glyph + FooterBar.Metrics.hitSlop * 2
        Button(action: action) {
            Group {
                if let image = command.image {
                    Image(nsImage: image).renderingMode(.template)
                }
            }
            .rotationEffect(.degrees(angle))
            .frame(width: side, height: side)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Live (spinning) or hovered reads as the primary label color, like Squiggle.
        .foregroundStyle(hovering || spinning ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))
        .onHover { hovering = $0 }
        .help(command.title)
        .accessibilityLabel(command.title)
        .onChange(of: spinning, initial: true) { _, isSpinning in
            // Reduce Motion: the brighter tint alone says a fetch is running.
            guard !reduceMotion else { return }
            if isSpinning {
                angle = 0
                withAnimation(.linear(duration: Self.turnSeconds).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            } else {
                withAnimation(.linear(duration: 0)) { angle = 0 }
            }
        }
    }
}
