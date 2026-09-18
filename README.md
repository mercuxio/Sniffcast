# Sniffcast

A macOS menu bar app for the weather and the air. The temperature and the air
quality index (AQI) sit next to the clock, and the forecast, the pollutants
behind the AQI, and the pollen count are in the dropdown.

Sniffcast is built to run all day without you noticing it. It fetches every 30
minutes by default, draws nothing between fetches, and uses about 30 MB of
memory with the dropdown closed. Weather and air quality come from
[Open-Meteo](https://open-meteo.com), which needs no API key and no account.

Requires **macOS 15 or later**. The release is a universal build, for Apple
silicon and Intel.

---

## Install

**Download the release.** Get `Sniffcast-1.0.2.zip` from
[Releases](https://github.com/mercuxio/Sniffcast/releases), unzip it, and drag
`Sniffcast.app` into `/Applications`.

The app is ad-hoc signed, not notarized, because I don't pay for an Apple
Developer account. macOS quarantines downloaded apps that aren't notarized, so
the first launch fails with "Sniffcast is damaged and can't be opened" or
"cannot be verified". The app isn't damaged. Clear the quarantine flag once:

```bash
xattr -dr com.apple.quarantine /Applications/Sniffcast.app
```

Then open it as usual. If you'd rather not run that on a stranger's app, which
is fair, you can build it yourself instead; see [Building](#building).

Sniffcast has no Dock icon and doesn't appear in the app switcher. Its whole
interface is the menu bar item, and you quit it from the dropdown.

One side effect of ad-hoc signing: macOS identifies the app by a hash of its
code, so each new version looks like a new app to Location Services and asks
for your location once more. Relaunching the same version doesn't.

## What it does

- **Four menu bar styles.**
  - **Full**: weather symbol, temperature, and `AQI 42`.
  - **Two Rows**: the temperature over the AQI number, both at 10pt, the same
    stacked layout Squiggle uses.
  - **Compact**: the temperature and a coloured dot for the AQI band.
  - **Rotating**: switches between the weather and the AQI every 8 seconds.
    The timer stops while the screen is locked or the display is asleep.
- **Colour that means something.** The AQI is tinted by its band, from good to
  hazardous, with separate colours tuned for light and dark menu bars. Turn
  off **Color-code AQI in menubar** for plain text. Compact then shows the
  number instead of the dot, since a dot with no colour tells you nothing.
- **A dropdown** with current conditions, the six pollutants (PM2.5, PM10,
  ozone, NO₂, SO₂, CO), the next 12 hours with an AQI for each, and 7 days
  with highs, lows, and pollen where Open-Meteo has it (mostly Europe). The
  footer has Settings…, Add Location…, Refresh Now, a link to buy me a
  coffee, and Quit.
- **Your location or any city.** Current location is the default. Add cities
  by searching, reorder them, and switch between them from the dropdown's
  header. Saved cities never touch Location Services. Your current location is
  shown by name, and place names, both for it and in city search, follow your
  Mac's first preferred language.
- **AQI alerts.** One notification when the AQI reaches your threshold, and
  another only after it has fallen back well below it, so an AQI hovering
  around the line doesn't turn into a stream of alerts.

Stale data is dimmed, never blanked, because an empty menu bar item looks like
a crash.

### Settings

- **Menubar style**: Full, Two Rows, Compact, or Rotating.
- **Color-code AQI in menubar**: on by default.
- **Refresh every** 15, 30 (the default), 45, or 60 minutes. Air-quality data
  only updates hourly, so shorter intervals mainly freshen the current
  weather.
- **Units**: °F or °C, mph or km/h, and US or European AQI. The defaults come
  from your region. Changing units never costs a request; everything is
  fetched in metric and converted locally.
- **Locations**: current location plus any saved cities.
- **Alerts**: on or off, and the threshold (100 US AQI or 60 European AQI by
  default).
- **Launch at login**, via `SMAppService`.

Settings and saved cities live in `UserDefaults`. Forecasts are never written
to disk.

## Where the data comes from

Two requests per refresh, sent together: Open-Meteo's
[forecast](https://open-meteo.com/en/docs) and
[air quality](https://open-meteo.com/en/docs/air-quality-api) APIs, asking only
for the fields the app shows. City search uses Open-Meteo's
[geocoding](https://open-meteo.com/en/docs/geocoding-api) API.

- Refreshes are scheduled with `NSBackgroundActivityScheduler`, with enough
  tolerance that macOS can batch them with other work.
- Waking from sleep or getting a network connection back only triggers a fetch
  if the data is already older than your interval. Nothing is fetched while
  you're offline.
- Opening the dropdown refreshes only if the data is more than 10 minutes old.
- A failed fetch keeps the last good data and retries after 2, 4, then 8
  minutes, never more often than your interval.
- If the air-quality request fails but the forecast succeeds, you get the
  weather without an AQI rather than nothing.

Open-Meteo's free tier is for non-commercial use, which is what this is.
Weather data by [Open-Meteo.com](https://open-meteo.com), licensed
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

## Resource use

Measured on the 1.0.0 build with the dropdown closed:

| | |
| --- | --- |
| Memory (physical footprint) | about 31 MB |
| CPU when idle | 0.0% |
| Wakeups | 3 in 30 seconds, all from the system |

The dropdown's SwiftUI view and the settings window are created when you open
them and released when you close them, so none of that memory stays around
while the app is idle. Location uses kilometre accuracy, one fix at launch,
and significant-change monitoring after that, never continuous updates.

## Building

Sniffcast is an Xcode project generated by [XcodeGen](https://github.com/yonaskolb/XcodeGen)
from `project.yml`. The `.xcodeproj` isn't committed.

```bash
brew install xcodegen
./scripts/build.sh            # Debug build
./scripts/package-app.sh      # Release build, zipped for a release
```

The scripts use `/Applications/Xcode-beta.app` by default. Point
`DEVELOPER_DIR` somewhere else to use a different Xcode:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build.sh
```

The Debug app ends up in `build/Build/Products/Debug/Sniffcast.app`, and
`package-app.sh` writes `build/Sniffcast-<version>.zip`. The signature is
ad-hoc: good enough to run the app yourself, not good enough to distribute it.
Distribution would need a Developer ID and notarization.

## Layout

| Path | What lives there |
| --- | --- |
| `Sniffcast/Domain` | The decision core: units, AQI scales and bands, weather codes, refresh policy, alert hysteresis, the menu bar formatter. No AppKit and no networking. |
| `Sniffcast/Data` | `OpenMeteoClient`, the only `URLSession`, and the mapping from API responses to a `Snapshot`. |
| `Sniffcast/State` | `AppState`, `SettingsStore`, and `LocationsStore`, all `@Observable` and `@MainActor`. |
| `Sniffcast/Services` | `RefreshScheduler`, `AlertService`, and the login item. |
| `Sniffcast/Location` | A thin CoreLocation wrapper. |
| `Sniffcast/StatusBar` | The `NSStatusItem`, the popover, and the AQI colours. |
| `Sniffcast/UI` | The SwiftUI dropdown and the settings window. |
| `Sniffcast/AppIcon.icon` | The app icon, an Icon Composer bundle: Lucide's cloud-sun as two SVG layers on a gradient fill. Open it in Icon Composer to edit. |
| `SniffcastTests/Fixtures` | Open-Meteo responses recorded live, used to test the decoder offline. |
| `docs/superpowers/specs/` | The design spec, which is the final word on behaviour. |

The menu bar uses `NSStatusItem` rather than SwiftUI's `MenuBarExtra` because
`MenuBarExtra` renders its label as a template image, and a template image
can't be coloured.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md).

```bash
./scripts/test.sh
```

## Status

Version 1.0.2. The test suite passes, and the app is in daily use against live
Open-Meteo data.

Releases include an ad-hoc signed `Sniffcast.app` in a zip; see
[Install](#install) for the one command that gets it past Gatekeeper.

Sniffcast isn't affiliated with or endorsed by Open-Meteo.

## License

[MIT](LICENSE).

The app icon is Lucide's [cloud-sun](https://lucide.dev/icons/cloud-sun),
used under the [ISC license](https://github.com/lucide-icons/lucide/blob/main/LICENSE).
