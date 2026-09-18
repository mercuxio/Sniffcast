import AppKit
import SwiftUI

/// Everything the panel can ask the app to do. Keeps the views free of AppKit plumbing.
struct PanelActions {
    var openSettings: (SettingsTab) -> Void
    var refresh: () -> Void
    var buyCoffee: () -> Void
    var quit: () -> Void
    var openLocationSettings: () -> Void
}

struct PanelView: View {
    let state: AppState
    let settings: SettingsStore
    let locations: LocationsStore
    let actions: PanelActions

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                header
                prompt
                if let snapshot = state.snapshot {
                    CurrentCard(snapshot: snapshot, settings: settings)
                    if let air = snapshot.air {
                        Divider()
                        PollutantGrid(pollutants: air.pollutants)
                    }
                    if !snapshot.hourly.isEmpty {
                        Divider()
                        HourlyChart(snapshot: snapshot, settings: settings)
                    }
                    if !snapshot.daily.isEmpty {
                        Divider()
                        DailyList(snapshot: snapshot, settings: settings)
                    }
                } else if state.isFetching {
                    ProgressView().controlSize(.small).frame(maxWidth: .infinity, minHeight: 80)
                }
                statusLine
            }
            .padding(14)

            Divider()
            FooterBar(isRefreshing: state.isFetching) { command in
                switch command {
                case .settings: actions.openSettings(.general)
                case .addLocation: actions.openSettings(.locations)
                case .refresh: actions.refresh()
                case .buyCoffee: actions.buyCoffee()
                case .quit: actions.quit()
                }
            }
        }
        .frame(width: 340)
    }

    // MARK: Header — location picker

    private var header: some View {
        Menu {
            Button {
                locations.active = .current
            } label: {
                Label("Current Location", systemImage: "location.fill")
            }
            if !locations.saved.isEmpty { Divider() }
            ForEach(locations.saved) { location in
                Button(location.name) { locations.active = .saved(location.id) }
            }
            Divider()
            Button("Manage Locations…") { actions.openSettings(.locations) }
        } label: {
            HStack(spacing: 4) {
                if locations.active == .current && !state.isFallback {
                    Image(systemName: "location.fill").font(.caption)
                }
                Text(state.targetName ?? "Sniffcast").font(.headline)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: Prompts — fallback, denied, or nothing to show

    @ViewBuilder private var prompt: some View {
        if state.isFallback {
            promptRow("Location access is off — showing \(state.targetName ?? "a saved city").",
                      button: "Open Settings", action: actions.openLocationSettings)
        } else if state.targetName == nil {
            if state.locationStatus == .denied {
                promptRow("Location access is off. Allow it in System Settings or add a city.",
                          button: "Add City") { actions.openSettings(.locations) }
            } else {
                promptRow("Finding your location…", button: "Add City") { actions.openSettings(.locations) }
            }
        }
    }

    private func promptRow(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Button(button, action: action).controlSize(.small)
        }
    }

    // MARK: Status line

    @ViewBuilder private var statusLine: some View {
        if let snapshot = state.snapshot {
            // Re-renders once a minute while the panel is open; nothing runs when it is closed.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                HStack(spacing: 4) {
                    if state.isStale { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                    Text(Formatting.updated(snapshot.fetchedAt, now: context.date))
                    if let error = state.lastError { Text("· \(error)") }
                    Spacer()
                    Link("Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                        .foregroundStyle(.tertiary)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        } else if let error = state.lastError {
            Text(error).font(.caption).foregroundStyle(.secondary)
        }
    }
}
