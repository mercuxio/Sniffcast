# Changelog

All notable changes to Sniffcast are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
