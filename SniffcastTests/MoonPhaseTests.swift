import AppKit
import Foundation
import Testing

struct MoonPhaseTests {
    static func utc(_ iso: String) -> Date {
        try! Date(iso, strategy: .iso8601)
    }

    /// A known new moon, used to walk through the cycle.
    static let newMoon = utc("2024-04-08T18:21:00Z")

    @Test func knownNewMoon() {
        #expect(MoonPhase.at(Self.newMoon) == .newMoon)
    }

    /// Far from the reference epoch, so drift in the mean month would show here.
    @Test func knownFullMoons() {
        #expect(MoonPhase.at(Self.utc("2024-01-25T17:54:00Z")) == .full)
        #expect(MoonPhase.at(Self.utc("2026-03-03T11:38:00Z")) == .full)
    }

    /// Each eighth of the month, at its centre, lands on its own phase in order.
    @Test func walksTheCycleInOrder() {
        let eighth = MoonPhase.synodicMonth / 8 * 86_400
        for (i, phase) in MoonPhase.allCases.enumerated() {
            #expect(MoonPhase.at(Self.newMoon.addingTimeInterval(eighth * Double(i))) == phase)
        }
    }

    @Test func wrapsAfterAFullMonth() {
        let later = Self.newMoon.addingTimeInterval(MoonPhase.synodicMonth * 86_400 * 3)
        #expect(MoonPhase.at(later) == .newMoon)
    }

    @Test(arguments: MoonPhase.allCases)
    func everySymbolExists(phase: MoonPhase) {
        for south in [false, true] {
            let name = phase.symbol(southernHemisphere: south)
            #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
        }
    }

    /// Seen from the south the moon is mirrored, which is the opposite waxing/waning shape.
    @Test func southernHemisphereMirrors() {
        #expect(MoonPhase.waxingCrescent.symbol(southernHemisphere: false) == "moonphase.waxing.crescent.inverse")
        #expect(MoonPhase.waxingCrescent.symbol(southernHemisphere: true) == "moonphase.waning.crescent.inverse")
        #expect(MoonPhase.firstQuarter.symbol(southernHemisphere: true) == "moonphase.last.quarter.inverse")
        #expect(MoonPhase.waningGibbous.symbol(southernHemisphere: true) == "moonphase.waxing.gibbous.inverse")
        #expect(MoonPhase.full.symbol(southernHemisphere: true) == "moonphase.full.moon.inverse")
        #expect(MoonPhase.newMoon.symbol(southernHemisphere: true) == "moonphase.new.moon.inverse")
    }
}

struct WeatherCodeNightTests {
    let fullMoon = MoonPhaseTests.utc("2024-01-25T17:54:00Z")

    @Test func clearNightShowsThePhase() {
        #expect(WeatherCode.symbol(0, isDay: false, date: fullMoon, latitude: 51) == "moonphase.full.moon.inverse")
        #expect(WeatherCode.symbol(1, isDay: false, date: fullMoon, latitude: 51) == "moonphase.full.moon.inverse")
    }

    @Test func dayIsUnchanged() {
        #expect(WeatherCode.symbol(0, isDay: true, date: fullMoon, latitude: 51) == "sun.max.fill")
        #expect(WeatherCode.symbol(1, isDay: true, date: fullMoon, latitude: 51) == "cloud.sun.fill")
    }

    /// Without a date there is no phase to show, so the old symbols stand.
    @Test func noDateKeepsTheOldSymbols() {
        #expect(WeatherCode.symbol(0, isDay: false) == "moon.stars.fill")
        #expect(WeatherCode.symbol(1, isDay: false) == "cloud.moon.fill")
    }

    @Test func partlyCloudyFollowsTheSetting() {
        #expect(WeatherCode.symbol(2, isDay: false, date: fullMoon, latitude: 51) == "cloud.moon.fill")
        #expect(WeatherCode.symbol(2, isDay: false, date: fullMoon, latitude: 51, phaseOnPartlyCloudy: true)
                == "moonphase.full.moon.inverse")
    }

    /// Overcast and anything falling from the sky keep their icon, setting or not.
    @Test(arguments: [3, 45, 61, 71, 80, 95])
    func weatherWinsOverTheMoon(code: Int) {
        let plain = WeatherCode.symbol(code, isDay: false)
        #expect(WeatherCode.symbol(code, isDay: false, date: fullMoon, latitude: 51, phaseOnPartlyCloudy: true) == plain)
    }

    @Test func southernLatitudeMirrors() {
        let waxing = MoonPhaseTests.newMoon.addingTimeInterval(MoonPhase.synodicMonth / 8 * 86_400)
        #expect(WeatherCode.symbol(0, isDay: false, date: waxing, latitude: 51) == "moonphase.waxing.crescent.inverse")
        #expect(WeatherCode.symbol(0, isDay: false, date: waxing, latitude: -33.9) == "moonphase.waning.crescent.inverse")
    }
}
