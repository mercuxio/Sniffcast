import Foundation
import Testing

struct MapperTests {
    let fetchedAt = Date(timeIntervalSince1970: 1_789_723_900)

    func london(air: Bool = true) throws -> Snapshot {
        let forecast = try SnapshotMapper.decodeForecast(Fixture.data("forecast_london"))
        let airResponse = air ? try SnapshotMapper.decodeAir(Fixture.data("air_london")) : nil
        return SnapshotMapper.make(forecast: forecast, air: airResponse, fetchedAt: fetchedAt)
    }

    @Test func mapsCurrentConditions() throws {
        let s = try london()
        #expect(s.fetchedAt == fetchedAt)
        #expect(s.current.temperature == 15.5)
        #expect(s.current.apparentTemperature == 13.1)
        #expect(s.current.humidity == 61)
        #expect(s.current.weatherCode == 1)
        #expect(s.current.windSpeed == 12.6)
        #expect(s.current.isDay)
    }

    @Test func mapsHourlyAndDaily() throws {
        let s = try london()
        #expect(s.hourly.count == 12)
        #expect(s.hourly[0].time == Date(timeIntervalSince1970: 1_789_722_000))
        #expect(s.hourly[0].temperature == 14.7)
        #expect(s.daily.count == 7)
        #expect(s.daily[0].date == Date(timeIntervalSince1970: 1_789_686_000))
        #expect(s.daily[0].high == 20.1)
        #expect(s.daily[0].low == 11.6)
        #expect(s.daily[0].weatherCode == 51)
    }

    @Test func mapsAirQuality() throws {
        let air = try #require(try london().air)
        #expect(air.usAQI == 31)
        #expect(air.euAQI == 31)
        #expect(air.pollutants.pm25 == 8.3)
        #expect(air.pollutants.pm10 == 17.2)
        #expect(air.pollutants.ozone == 50)
        #expect(air.pollutants.no2 == 18.6)
        #expect(air.pollutants.so2 == 1.0)
        #expect(air.pollutants.co == 225)
    }

    @Test func joinsHourlyAQIByTimestamp() throws {
        let s = try london()
        let raw = try SnapshotMapper.decodeAir(Fixture.data("air_london"))
        let index = try #require(raw.hourly?.time.firstIndex(of: 1_789_722_000))
        #expect(s.hourly[0].usAQI == raw.hourly?.us_aqi?[index] ?? nil)
        #expect(s.hourly.allSatisfy { $0.usAQI != nil && $0.euAQI != nil })
    }

    @Test func dailyPollenIsPerDayMax() throws {
        let s = try london()
        let pollen = try #require(s.daily[0].pollen)
        let raw = try SnapshotMapper.decodeAir(Fixture.data("air_london"))
        let hourly = try #require(raw.hourly)
        let dayEnd = 1_789_686_000 + 86_400
        let grass = zip(hourly.time, hourly.grass_pollen ?? [])
            .filter { $0.0 < dayEnd }.compactMap(\.1).max()
        #expect(pollen.grass == grass)
        // Air quality covers 5 days; days 6–7 have no pollen.
        #expect(s.daily[6].pollen == nil)
    }

    @Test func noPollenOutsideEurope() throws {
        let forecast = try SnapshotMapper.decodeForecast(Fixture.data("forecast_london"))
        let air = try SnapshotMapper.decodeAir(Fixture.data("air_sf_nopollen"))
        let s = SnapshotMapper.make(forecast: forecast, air: air, fetchedAt: fetchedAt)
        #expect(s.daily.allSatisfy { $0.pollen == nil })
    }

    @Test func missingAirLeavesAQIUnavailable() throws {
        let s = try london(air: false)
        #expect(s.air == nil)
        #expect(s.hourly.allSatisfy { $0.usAQI == nil && $0.euAQI == nil })
        #expect(s.daily.allSatisfy { $0.pollen == nil })
    }

    @Test func decodesGeocoding() throws {
        let results = try SnapshotMapper.decodeGeocode(Fixture.data("geocode_portland"))
        let first = try #require(results.first)
        #expect(first.name == "Portland")
        #expect(first.detail == "Oregon, United States")
        #expect(first.coordinate == Coordinate(latitude: 45.52345, longitude: -122.67621))
    }

    @Test func emptyGeocodingIsEmptyList() throws {
        #expect(try SnapshotMapper.decodeGeocode(Data(#"{"generationtime_ms":0.5}"#.utf8)).isEmpty)
    }

    @Test func decodesAPIError() throws {
        #expect(SnapshotMapper.apiError(from: try Fixture.data("error"))
            == .api("Latitude must be in range of -90 to 90°. Given: 999.0."))
        #expect(SnapshotMapper.apiError(from: try Fixture.data("forecast_london")) == nil)
    }

    @Test func pollenEntriesSkipNil() {
        let p = Pollen(alder: nil, birch: 3, grass: 12.5, mugwort: nil, olive: nil, ragweed: 0)
        #expect(p.entries.map(\.name) == ["Birch", "Grass", "Ragweed"])
    }
}
