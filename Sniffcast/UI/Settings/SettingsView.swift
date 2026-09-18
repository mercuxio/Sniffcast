import SwiftUI

struct SettingsView: View {
    @Bindable var navigation: SettingsNavigation
    let settings: SettingsStore
    let locations: LocationsStore
    let alerts: AlertService
    let state: AppState
    let provider: WeatherProviding

    var body: some View {
        TabView(selection: $navigation.tab) {
            GeneralSettings(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            LocationsSettings(locations: locations, state: state, provider: provider)
                .tabItem { Label("Locations", systemImage: "map") }
                .tag(SettingsTab.locations)
            AlertsSettings(settings: settings, alerts: alerts)
                .tabItem { Label("Alerts", systemImage: "bell") }
                .tag(SettingsTab.alerts)
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: General

private struct GeneralSettings: View {
    @Bindable var settings: SettingsStore
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Picker("Menubar style", selection: $settings.menubarStyle) {
                ForEach(MenubarStyle.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Color-code AQI in menubar", isOn: Binding(
                get: { !settings.aqiMonochrome }, set: { settings.aqiMonochrome = !$0 }))
            Picker("Refresh every", selection: $settings.refreshInterval) {
                ForEach(RefreshInterval.allCases) { Text("\($0.rawValue) min").tag($0) }
            }
            Text("Air-quality data updates hourly, so shorter intervals mainly freshen current weather.")
                .font(.caption).foregroundStyle(.secondary)

            Section("Units") {
                Picker("Temperature", selection: $settings.temperatureUnit) {
                    Text("°F").tag(TemperatureUnit.fahrenheit)
                    Text("°C").tag(TemperatureUnit.celsius)
                }
                .pickerStyle(.segmented)
                Picker("Wind", selection: $settings.windUnit) {
                    Text("mph").tag(WindUnit.mph)
                    Text("km/h").tag(WindUnit.kmh)
                }
                .pickerStyle(.segmented)
                Picker("AQI scale", selection: $settings.aqiScale) {
                    Text("US AQI").tag(AQIScaleKind.us)
                    Text("European AQI").tag(AQIScaleKind.eu)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LoginItem.setEnabled(enabled)
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
            }

            Section {
                Link("Weather data by Open-Meteo.com (CC BY 4.0)", destination: URL(string: "https://open-meteo.com/")!)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Locations

private struct LocationsSettings: View {
    let locations: LocationsStore
    let state: AppState
    let provider: WeatherProviding

    @State private var query = ""
    @State private var results: [GeocodeResult] = []
    @State private var searching = false
    @State private var searchError: String?

    var body: some View {
        Form {
            Section("Saved") {
                List {
                    HStack {
                        Label {
                            VStack(alignment: .leading) {
                                Text(locations.currentName ?? LocationsStore.currentFallbackName)
                                if locations.currentName != nil {
                                    Text("Current Location").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "location.fill")
                        }
                        Spacer()
                        if state.locationStatus == .denied {
                            Text("Access off").font(.caption).foregroundStyle(.secondary)
                        }
                        if locations.active == .current { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { locations.active = .current }
                    .moveDisabled(true)

                    ForEach(locations.saved) { location in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(location.name)
                                if !location.detail.isEmpty {
                                    Text(location.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if locations.active == .saved(location.id) {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                            Button {
                                locations.remove(id: location.id)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove \(location.name)")
                            .accessibilityLabel("Remove \(location.name)")
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { locations.active = .saved(location.id) }
                    }
                    .onMove { locations.move(from: $0, to: $1) }
                }
                .frame(minHeight: 120)
            }

            Section("Add a city") {
                TextField("Search", text: $query, prompt: Text("City name"))
                    .textFieldStyle(.roundedBorder)
                if searching {
                    ProgressView().controlSize(.small)
                } else if let searchError {
                    Text(searchError).font(.caption).foregroundStyle(.secondary)
                } else if query.trimmingCharacters(in: .whitespaces).count >= 2 && results.isEmpty {
                    Text("No matches").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(results) { result in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(result.name)
                            Text(result.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Add") {
                            let location = locations.add(result)
                            locations.active = .saved(location.id)
                            query = ""
                            results = []
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        // `.task(id:)` cancels the previous search when the query changes: the sleep is the debounce.
        .task(id: query) { await search(query) }
    }

    private func search(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            searchError = nil
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(300))
        } catch { return }
        searching = true
        defer { searching = false }
        do {
            let found = try await provider.search(trimmed)
            guard !Task.isCancelled else { return }
            results = found
            searchError = nil
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            searchError = "Search failed. Check your connection."
        }
    }
}

// MARK: Alerts

private struct AlertsSettings: View {
    @Bindable var settings: SettingsStore
    let alerts: AlertService

    private var thresholdRange: ClosedRange<Int> { settings.aqiScale == .us ? 50...300 : 20...100 }
    private var step: Int { settings.aqiScale == .us ? 10 : 5 }

    var body: some View {
        Form {
            Toggle("Notify when air quality gets worse", isOn: $settings.alertsEnabled)
                .onChange(of: settings.alertsEnabled) { _, enabled in
                    if enabled { Task { await alerts.requestAuthorizationIfNeeded() } }
                }
            Stepper(value: $settings.alertThreshold, in: thresholdRange, step: step) {
                HStack {
                    Text("Threshold")
                    Spacer()
                    let band = AQIScale.band(for: settings.alertThreshold, scale: settings.aqiScale)
                    Text("AQI \(settings.alertThreshold)").monospacedDigit()
                        .foregroundStyle(AQIColors.color(band))
                    Text(AQIScale.label(for: band, scale: settings.aqiScale))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(!settings.alertsEnabled)
            Text("You'll get one notification when the AQI reaches the threshold, and another only after it has dropped back down.")
                .font(.caption).foregroundStyle(.secondary)
            if alerts.notificationsDenied {
                Text("Notifications are turned off for Sniffcast. Enable them in System Settings › Notifications.")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .formStyle(.grouped)
    }
}
