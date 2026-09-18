import Foundation
import Testing

struct UnitsTests {
    @Test func celsiusToFahrenheit() {
        #expect(Units.temperature(0, in: .fahrenheit) == 32)
        #expect(Units.temperature(100, in: .fahrenheit) == 212)
        #expect(Units.temperature(21.5, in: .celsius) == 21.5)
    }

    @Test(arguments: [
        (15.5, TemperatureUnit.fahrenheit, "60°"),
        (15.5, .celsius, "16°"),
        (-0.4, .celsius, "0°"),
        (-12.2, .celsius, "-12°"),
        (-40, .fahrenheit, "-40°"),
    ])
    func formatsTemperature(celsius: Double, unit: TemperatureUnit, expected: String) {
        #expect(Units.formatTemperature(celsius, in: unit) == expected)
    }

    @Test func formatsWind() {
        #expect(Units.formatWind(12.6, in: .mph) == "8 mph")
        #expect(Units.formatWind(12.6, in: .kmh) == "13 km/h")
        #expect(Units.formatWind(0, in: .mph) == "0 mph")
    }

    @Test(arguments: [
        ("en_US", TemperatureUnit.fahrenheit, WindUnit.mph, AQIScaleKind.us),
        ("en_GB", .celsius, .mph, .eu),
        ("de_DE", .celsius, .kmh, .eu),
        ("en_IN", .celsius, .kmh, .us),
        ("fr_CA", .celsius, .kmh, .us),
    ])
    func localeDefaults(id: String, temp: TemperatureUnit, wind: WindUnit, scale: AQIScaleKind) {
        let d = Units.defaults(for: Locale(identifier: id))
        #expect(d.temperature == temp)
        #expect(d.wind == wind)
        #expect(d.scale == scale)
    }
}
