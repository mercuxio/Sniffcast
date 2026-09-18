import AppKit

/// Renders the menubar item. Uses `NSStatusItem` rather than `MenuBarExtra` because the
/// AQI must be colored, and `MenuBarExtra` labels render as template (monochrome) images.
@MainActor
final class StatusItemController: NSObject {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var onClick: (() -> Void)?

    private let state: AppState
    private let settings: SettingsStore
    private var phase: MenubarPhase = .weather
    private var lastContent: MenubarContent?
    private var rotationTimer: Timer?
    private var screenLocked = false
    private var displaysAsleep = false

    private static let rotationPeriod: TimeInterval = 8
    private static let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)

    init(state: AppState, settings: SettingsStore) {
        self.state = state
        self.settings = settings
        super.init()

        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }

        Sniffcast.observe { [state, settings] in
            (state.snapshot, state.isStale, settings.menubarStyle, settings.temperatureUnit, settings.aqiScale)
        } apply: { [weak self] _ in
            self?.updateRotation()
            self?.render()
        }
        observeScreenState()
    }

    @objc private func clicked() { onClick?() }

    // MARK: Rendering

    private func render() {
        let content = MenubarFormatter.content(
            snapshot: state.snapshot, style: settings.menubarStyle, phase: phase,
            temperatureUnit: settings.temperatureUnit, scale: settings.aqiScale, stale: state.isStale)
        // Redraw only when the rendered output actually changes.
        guard content != lastContent, let button = item.button else { return }
        lastContent = content

        button.image = NSImage(systemSymbolName: content.symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(Self.symbolConfig)
        button.image?.isTemplate = true
        button.attributedTitle = Self.title(for: content)
        button.imagePosition = content.text.isEmpty && content.aqiText == nil ? .imageOnly : .imageLeading
        // Dimmed, never blank, when data is stale.
        button.appearsDisabled = content.stale
        button.setAccessibilityLabel(accessibilityLabel(for: content))
    }

    private static func title(for content: MenubarContent) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let result = NSMutableAttributedString()
        if !content.text.isEmpty {
            result.append(NSAttributedString(string: " " + content.text, attributes: [.font: font]))
        }
        if let aqiText = content.aqiText, let band = content.band {
            let isDot = aqiText == "●"
            let color = AQIColors.nsColor(band).withAlphaComponent(content.stale ? 0.5 : 1)
            let aqiFont = isDot
                ? NSFont.systemFont(ofSize: 9)
                : NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            var attributes: [NSAttributedString.Key: Any] = [.font: aqiFont, .foregroundColor: color]
            if isDot { attributes[.baselineOffset] = 1.5 }
            result.append(NSAttributedString(string: " " + aqiText, attributes: attributes))
        }
        return result
    }

    private func accessibilityLabel(for content: MenubarContent) -> String {
        guard let snapshot = state.snapshot else { return "Sniffcast, loading" }
        var parts = [
            Units.formatTemperature(snapshot.current.temperature, in: settings.temperatureUnit),
            WeatherCode.description(snapshot.current.weatherCode),
        ]
        if let aqi = snapshot.air?.aqi(settings.aqiScale) {
            let band = AQIScale.band(for: aqi, scale: settings.aqiScale)
            parts.append("AQI \(aqi), \(AQIScale.label(for: band, scale: settings.aqiScale))")
        }
        if content.stale { parts.append("out of date") }
        return parts.joined(separator: ", ")
    }

    // MARK: Rotation (rotating style only)

    private func updateRotation() {
        let shouldRun = settings.menubarStyle == .rotating
            && state.snapshot?.air?.aqi(settings.aqiScale) != nil
            && !screenLocked && !displaysAsleep
        if shouldRun, rotationTimer == nil {
            let timer = Timer(timeInterval: Self.rotationPeriod, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.rotate() }
            }
            timer.tolerance = Self.rotationPeriod / 10
            RunLoop.main.add(timer, forMode: .common)
            rotationTimer = timer
        } else if !shouldRun, let timer = rotationTimer {
            timer.invalidate()
            rotationTimer = nil
            phase = .weather
        }
    }

    private func rotate() {
        phase = phase == .weather ? .air : .weather
        render()
    }

    private func observeScreenState() {
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked = true; self?.updateRotation() }
        }
        distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked = false; self?.updateRotation() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.displaysAsleep = true; self?.updateRotation() }
        }
        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.displaysAsleep = false; self?.updateRotation() }
        }
    }
}
