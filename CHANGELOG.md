# Changelog

All notable changes to Sniffcast are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.2] — 2026-10-07

### Fixed
- The AQI heat map no longer has a hard straight edge inside the map, and the blotchy patches around each station are gone. The colour now shifts smoothly across the AQI scale instead of jumping between bands, and the coverage area is larger.

## [1.5.1] — 2026-10-07

### Changed
- The WAQI token in Settings is now shown as plain text instead of being masked, so you can see what you pasted.

## [1.5.0] — 2026-10-07

### Added
- The AQI map is now a heat map: station readings from WAQI are blended into a smooth colour field in the AQI band colours, fading out where no station is close.
- With a WAQI token, the headline AQI (menu bar, current card, alerts) comes from the nearest WAQI station on the US scale, so it matches the map. The European scale, hourly dots and pollutant values stay on the Open-Meteo model, and without a token (or if WAQI fails) everything falls back to the model.

### Fixed
- Pasting into the WAQI token field in Settings did nothing, because a menu bar app has no Edit menu. A hidden one now provides ⌘V, ⌘C, ⌘X, ⌘A and undo.

## [1.4.0] — 2026-10-07

### Added
- An AQI map in the panel: a small map centred on the location with live AQI colours from WAQI (aqicn.org) over it, worldwide. It needs a free WAQI token, pasted in Settings → General → AQI map; with no token the map stays hidden and nothing else changes. Tiles load from `tiles.aqicn.org` using your token (the base map comes from Apple Maps), and the map carries the required "Air Quality Tiles © waqi.info" credit.

## [1.3.1] — 2026-10-02

### Changed
- Full, Compact and Rotating menu bar text is now 11 pt instead of 13 pt, so the added UV fits more comfortably.

## [1.3.0] — 2026-10-02

### Added
- UV in the menu bar, in every style: `UV5` after the temperature in Full, Compact and Rotating, coloured by exposure level.
- Two Rows is now **Three Rows**: temperature, UV, then AQI, stacked. When UV is 0 (overnight) it drops back to the regular two rows. An existing Two Rows setting migrates automatically.

## [1.2.1] — 2026-10-02

### Added

- UV in the next-12-hours strip: a small coloured number under each hour, blank overnight.
- The 7-day list shows UV as a range from 3, where sun protection starts, up to the day's peak (for example "UV 3–9"). Days that never reach 3 show just the peak.

## [1.2.0] — 2026-10-02

### Added

- UV index. The current card shows the UV reading, hidden at night when it would read 0, and each day in the 7-day list shows its peak UV. Both are coloured by exposure level (Low, Moderate, High, Very high, Extreme).

## [1.1.5] — 2026-09-22

### Fixed

- In the Two Rows menu bar style, the temperature and AQI now line up on their last digit. The degree sign sits past the edge instead of lining up with the AQI.

## [1.1.4] — 2026-09-21

### Fixed

- Weather loads right away at launch, even just after the Mac starts up. Until a new location fix arrives, the app uses your last known position. Before, it waited for a fix that doesn't come until Wi-Fi is up.
- A failed location fix is retried after 15 seconds, then with backoff, instead of waiting minutes for macOS to report a move.
- If the network comes back during a fetch that then fails, the fetch is retried at once instead of after the backoff.

## [1.1.3] — 2026-09-19

### Fixed

- Scheduled refreshes no longer skip ticks. macOS may run the refresh a little
  early, and those early ticks were ignored, so a 30-minute interval often
  updated only every hour.
- The hourly forecast shows the sun and moon by real daylight from Open-Meteo,
  not a fixed 06:00–20:00 window. Winter evenings now show the moon (and its
  phase) instead of a sun.
- Turning location access back on no longer leaves the fallback city's weather
  on screen without a name while your position is found.

## [1.1.2] — 2026-09-18

### Added

- The app version at the bottom of Settings, on the same row as the
  Open-Meteo credit.

## [1.1.1] — 2026-09-18

### Changed

- The moon in the dropdown is now coloured: gold in light mode and cream in
  dark mode, with the shadowed part faint. Before, it was drawn in the text
  colour, so in light mode a full moon was a black disc. The menu bar icon is
  unchanged.

## [1.1.0] — 2026-09-18

### Added

- On clear and mainly clear nights, the weather symbol shows the current moon
  phase: in the menu bar, the current conditions, and the night hours of the
  hourly forecast. The phase is worked out locally from the date, and is
  mirrored for locations in the southern hemisphere.
- A **Show moon phase on partly cloudy nights** setting, off by default.

## [1.0.2] — 2026-09-18

### Fixed

- The app icon no longer sits inside a grey frame on macOS 26 and later. It is
  now an Icon Composer icon, so the system draws the shape and the glass
  lighting itself, and older systems get a fallback generated from the same
  source.

## [1.0.1] — 2026-09-18

### Added

- An app icon: Lucide's cloud-sun, with an amber sun and a white cloud on
  the same dark tile as Squiggle's icon.

## [1.0.0] — 2026-09-18

First public release.

### Added

- A menu bar item showing the weather and the AQI in four styles: **Full**,
  **Two Rows**, **Compact**, and **Rotating**.
- AQI colours by band, tuned separately for light and dark menu bars, with an
  option to turn them off.
- A dropdown with current conditions, six pollutants, a 12-hour forecast with
  hourly AQI, and a 7-day forecast with pollen where available.
- Current location by default, plus saved cities found by search, reordered in
  Settings and switched from the dropdown.
- AQI alerts with a threshold and hysteresis, tracked per location.
- Settings for style, refresh interval (15, 30, 45, or 60 minutes), units
  (°F/°C, mph/km/h, US/European AQI), alerts, and Launch at Login.
- A footer matching Squiggle's: Settings…, Add Location…, Refresh Now, Buy me a
  coffee, and Quit.
