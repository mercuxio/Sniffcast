import Foundation
import Testing
@testable import Sniffcast

@Suite struct AQIMapTests {
    @Test func feedParsesNumberOrStringAqi() {
        let a = Data(#"{"status":"ok","data":{"aqi":95,"city":{"name":"Klang"}}}"#.utf8)
        let b = Data(#"{"status":"ok","data":{"aqi":"96","city":{"name":"Klang"}}}"#.utf8)
        #expect(AQIMap.parseFeed(a) == StationFeed(name: "Klang", aqi: 95))
        #expect(AQIMap.parseFeed(b)?.aqi == 96)
    }

    @Test func feedRejectsErrorsAndMissingReadings() {
        #expect(AQIMap.parseFeed(Data(#"{"status":"error","data":"Invalid key"}"#.utf8)) == nil)
        #expect(AQIMap.parseFeed(Data(#"{"status":"ok","data":{"aqi":"-"}}"#.utf8)) == nil)
    }

    @Test func stationsDropEntriesWithoutAReading() {
        let json = #"{"status":"ok","data":[{"lat":3.1,"lon":101.6,"aqi":"88","station":{"name":"A"}},{"lat":3.2,"lon":101.7,"aqi":"-","station":{"name":"B"}}]}"#
        #expect(AQIMap.parseStations(Data(json.utf8)) == [StationReading(name: "A", latitude: 3.1, longitude: 101.6, aqi: 88)])
        #expect(AQIMap.parseStations(Data(#"{"status":"error","data":"x"}"#.utf8)).isEmpty)
    }

    private let near = StationReading(name: "N", latitude: 3.0, longitude: 101.0, aqi: 50)
    private let far = StationReading(name: "F", latitude: 3.0, longitude: 101.2, aqi: 150)

    @Test func interpolationPrefersTheCloserStation() throws {
        let v = try #require(AQIMap.interpolate(latitude: 3.0, longitude: 101.02, stations: [near, far]))
        #expect(v.aqi < 70)
        #expect(v.confidence == 1)
    }

    @Test func confidenceFadesAwayFromStationsAndVanishes() throws {
        let mid = try #require(AQIMap.interpolate(latitude: 3.0, longitude: 101.2, stations: [near]))
        #expect(mid.confidence == 0 || mid.confidence < 1)
        #expect(AQIMap.interpolate(latitude: 3.0, longitude: 102.0, stations: [near]) == nil)
        #expect(AQIMap.interpolate(latitude: 3.0, longitude: 101.0, stations: []) == nil)
    }

    @Test func distanceOfOneDegreeLatitudeIsAbout111Km() {
        #expect(abs(AQIMap.distanceKm(0, 0, 1, 0) - 111.2) < 0.5)
    }
}

@Suite struct StationOverrideTests {
    private func london() throws -> Snapshot {
        SnapshotMapper.make(forecast: try SnapshotMapper.decodeForecast(Fixture.data("forecast_london")),
                            air: nil, fetchedAt: .now)
    }

    @Test func stationReplacesTheUSModelValueOnly() throws {
        let air = AirQuality(usAQI: 40, euAQI: 30, pollutants: Pollutants())
        var snap = try london()
        snap.air = air
        let merged = snap.applying(station: StationFeed(name: "Klang", aqi: 96))
        #expect(merged.air?.aqi(.us) == 96)
        #expect(merged.air?.aqi(.eu) == 30)
        #expect(merged.air?.stationName == "Klang")
    }

    @Test func stationAloneStillGivesAnAir() throws {
        var snap = try london()
        snap.air = nil
        #expect(snap.applying(station: StationFeed(name: "K", aqi: 60)).air?.aqi(.us) == 60)
    }
}
