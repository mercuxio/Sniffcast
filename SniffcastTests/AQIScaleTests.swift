import Testing

struct AQIScaleTests {
    @Test(arguments: [
        (0, AQIBand.good), (50, .good), (51, .moderate), (100, .moderate),
        (101, .sensitive), (150, .sensitive), (151, .unhealthy), (200, .unhealthy),
        (201, .veryUnhealthy), (300, .veryUnhealthy), (301, .hazardous), (500, .hazardous),
    ])
    func usBands(value: Int, band: AQIBand) {
        #expect(AQIScale.band(for: value, scale: .us) == band)
    }

    @Test(arguments: [
        (0, AQIBand.good), (20, .good), (21, .moderate), (40, .moderate),
        (41, .sensitive), (60, .sensitive), (61, .unhealthy), (80, .unhealthy),
        (81, .veryUnhealthy), (100, .veryUnhealthy), (101, .hazardous),
    ])
    func euBands(value: Int, band: AQIBand) {
        #expect(AQIScale.band(for: value, scale: .eu) == band)
    }

    @Test func labels() {
        #expect(AQIScale.label(for: .good, scale: .us) == "Good")
        #expect(AQIScale.label(for: .sensitive, scale: .us) == "Unhealthy for sensitive groups")
        #expect(AQIScale.label(for: .hazardous, scale: .us) == "Hazardous")
        #expect(AQIScale.label(for: .moderate, scale: .eu) == "Fair")
        #expect(AQIScale.label(for: .sensitive, scale: .eu) == "Moderate")
        #expect(AQIScale.label(for: .unhealthy, scale: .eu) == "Poor")
        #expect(AQIScale.label(for: .veryUnhealthy, scale: .eu) == "Very poor")
        #expect(AQIScale.label(for: .hazardous, scale: .eu) == "Extremely poor")
    }

    @Test func alertDefaults() {
        #expect(AQIScale.defaultThreshold(.us) == 100)
        #expect(AQIScale.defaultThreshold(.eu) == 60)
        #expect(AQIScale.rearmMargin(.us) == 10)
        #expect(AQIScale.rearmMargin(.eu) == 5)
    }

    @Test func weatherCodes() {
        #expect(WeatherCode.symbol(0, isDay: true) == "sun.max.fill")
        #expect(WeatherCode.symbol(0, isDay: false) == "moon.stars.fill")
        #expect(WeatherCode.symbol(95, isDay: true) == "cloud.bolt.rain.fill")
        #expect(WeatherCode.description(1) == "Mainly clear")
        #expect(WeatherCode.description(12345) == "Unknown")
    }
}
