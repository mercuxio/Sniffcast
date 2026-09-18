# Contributing to Sniffcast

## Building and testing

```bash
brew install xcodegen
./scripts/build.sh
./scripts/test.sh
```

Both scripts regenerate `Sniffcast.xcodeproj` from `project.yml` first. The
project file isn't committed, so edit `project.yml`, not the `.xcodeproj`.
Changes made in Xcode's project editor disappear the next time either script
runs.

The scripts default to `/Applications/Xcode-beta.app`. Set `DEVELOPER_DIR` to
use another Xcode.

The project has no dependencies beyond Apple's frameworks. Keep it that way.

## Don't hit Open-Meteo from the test suite

The tests make no network requests. The decoder is tested against the
responses in `SniffcastTests/Fixtures/`, and the refresh and alert logic are
tested as pure functions with the time passed in. Don't edit the fixtures by
hand, because they're evidence of what Open-Meteo actually sent. Capture a new
one with `curl` against the same URL the client builds.

## Resource use is a requirement

Sniffcast is meant to run all day unnoticed, and the design spec
(`docs/superpowers/specs/2026-09-18-sniffcast-design.md`, §6) sets budgets: idle
CPU of about 0%, under 40 MB of memory with the dropdown closed, and no
wakeups between refreshes except the Rotating style's timer. Keep these in
mind when you change anything:

- **No polling and no repeating timers.** Refreshes go through
  `NSBackgroundActivityScheduler`. The one repeating timer is the Rotating
  style's 8-second flip, which only exists in that style and stops on screen
  lock and display sleep.
- **Redraw the menu bar only when its content changes.** `MenubarContent` is
  `Equatable` for this reason.
- **Create UI when it's shown and release it when it's hidden.** The
  dropdown's hosting controller and the settings window are both built on
  demand.
- **Units are converted locally.** Changing a unit must never trigger a fetch.

If you touch any of this, measure it: `footprint Sniffcast` with the dropdown
closed, and Activity Monitor's Energy tab.

## Layering

`Sniffcast/Domain` is pure Swift: no AppKit, no networking, no `UserDefaults`,
and no reading the clock. Anything that depends on time gets the current time
passed in, which is how the refresh policy is tested across every interval
without waiting.

`OpenMeteoClient` holds the only `URLSession`. Network and location sit behind
protocols (`WeatherProviding`, `LocationProviding`) so tests can use fakes.

Some rules the app keeps:

- **Stale data is dimmed, never blanked.**
- **Colour is never the only signal.** Every AQI band also has a label, and
  turning colour off makes Compact show the number instead of the dot.
- **No `default:` in a `switch` over the project's own enums.** When a case is
  added, the compiler should point to every place that needs a decision.

## Swift 6 gotcha: `observe` inside `NSObject`

The global `observe(_:apply:)` helper that re-runs a closure whenever
Observation-tracked state changes is shadowed by KVO's `observe` inside any
`NSObject` subclass. Call it as `Sniffcast.observe` there, or the compiler
picks the KVO overload and the error message won't point you at the cause.

## Style

Comments explain why a line is written the way it is, usually because the
obvious alternative is wrong in a way that takes an afternoon to rediscover.
Keep that up. A comment that just repeats the code is noise; a comment that
names the trap is the point.

`docs/superpowers/specs/2026-09-18-sniffcast-design.md` is the final word on
behaviour. When the code and the spec disagree, the spec wins unless you
change it deliberately.

## Pull requests

- Keep `main` passing: `./scripts/test.sh`.
- Say what you checked against the live app. Menu bar rendering, sleep and
  wake, the lock screen, and Location Services can't be fully tested by the
  suite.
- New behaviour needs a test. After writing it, break the code on purpose and
  watch the test fail. A test you've never seen fail hasn't been shown to test
  anything.
