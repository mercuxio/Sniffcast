import Foundation
import Testing

struct MenubarFormatterTests {
    func snapshot(air: Bool = true) throws -> Snapshot {
        let forecast = try SnapshotMapper.decodeForecast(Fixture.data("forecast_london"))
        let a = air ? try SnapshotMapper.decodeAir(Fixture.data("air_london")) : nil
        return SnapshotMapper.make(forecast: forecast, air: a, fetchedAt: .now)
    }

    func content(_ s: Snapshot?, _ style: MenubarStyle, phase: MenubarPhase = .weather,
                 unit: TemperatureUnit = .fahrenheit, scale: AQIScaleKind = .us, stale: Bool = false,
                 monochrome: Bool = false) -> MenubarContent {
        MenubarFormatter.content(snapshot: s, style: style, phase: phase, temperatureUnit: unit, scale: scale,
                                 stale: stale, monochrome: monochrome)
    }

    @Test func monochromeFullDropsTint() throws {
        let c = content(try snapshot(), .full, monochrome: true)
        #expect(c.aqiText == "AQI 31")
        #expect(c.band == nil)
    }

    /// A colorless dot says nothing, so compact falls back to the number.
    @Test func monochromeCompactShowsNumber() throws {
        let c = content(try snapshot(), .compact, monochrome: true)
        #expect(c.aqiText == "31")
        #expect(c.band == nil)
    }

    @Test func monochromeRotatingAirPhase() throws {
        let c = content(try snapshot(), .rotating, phase: .air, monochrome: true)
        #expect(c.aqiText == "31")
        #expect(c.band == nil)
    }

    @Test(arguments: MenubarStyle.allCases)
    func placeholderBeforeData(style: MenubarStyle) {
        let c = content(nil, style)
        #expect(c.text == "—")
        #expect(c.aqiText == nil)
        #expect(c.band == nil)
    }

    @Test func full() throws {
        let c = content(try snapshot(), .full)
        #expect(c == MenubarContent(symbol: "cloud.sun.fill", text: "60°", aqiText: "AQI 31", band: .good, stale: false))
    }

    @Test func twoRowsStacksBareNumber() throws {
        let c = content(try snapshot(), .twoRows)
        #expect(c == MenubarContent(symbol: "cloud.sun.fill", text: "60°", aqiText: "31", band: .good,
                                    stacked: true, stale: false))
    }

    @Test func twoRowsWithoutAirIsSingleRow() throws {
        let c = content(try snapshot(air: false), .twoRows)
        #expect(c.aqiText == nil)
        #expect(!c.stacked)
    }

    @Test(arguments: [MenubarStyle.full, .compact, .rotating])
    func onlyTwoRowsStacks(style: MenubarStyle) throws {
        #expect(!content(try snapshot(), style).stacked)
    }

    @Test func compactUsesDot() throws {
        let c = content(try snapshot(), .compact, unit: .celsius)
        #expect(c.text == "16°")
        #expect(c.aqiText == "●")
        #expect(c.band == .good)
    }

    @Test func rotatingAlternates() throws {
        let s = try snapshot()
        let weather = content(s, .rotating, phase: .weather)
        #expect(weather.text == "60°")
        #expect(weather.aqiText == nil)
        let air = content(s, .rotating, phase: .air)
        #expect(air.symbol == "aqi.medium")
        #expect(air.text == "")
        #expect(air.aqiText == "31")
    }

    @Test func rotatingAirPhaseWithoutAirShowsWeather() throws {
        let c = content(try snapshot(air: false), .rotating, phase: .air)
        #expect(c.text == "60°")
        #expect(c.aqiText == nil)
    }

    @Test func euScale() throws {
        var s = try snapshot()
        s.air?.euAQI = 45
        let c = content(s, .full, scale: .eu)
        #expect(c.aqiText == "AQI 45")
        #expect(c.band == .sensitive)
    }

    @Test(arguments: MenubarStyle.allCases)
    func missingAirHidesAQI(style: MenubarStyle) throws {
        let c = content(try snapshot(air: false), style)
        #expect(c.aqiText == nil)
        #expect(c.band == nil)
    }

    @Test func staleFlagPassesThrough() throws {
        #expect(content(try snapshot(), .full, stale: true).stale)
    }
}
