import Testing
@testable import Sniffcast

@Suite struct AQIMapTests {
    @Test func templateEmbedsTokenAndMapKitPlaceholders() {
        #expect(AQIMap.tileTemplate(token: "abc123")
            == "https://tiles.aqicn.org/tiles/usepa-aqi/{z}/{x}/{y}.png?token=abc123")
    }

    @Test func blankTokenGivesNoMap() {
        #expect(AQIMap.tileTemplate(token: "") == nil)
        #expect(AQIMap.tileTemplate(token: "  \n") == nil)
    }

    @Test func tokenIsTrimmedAndEscaped() {
        #expect(AQIMap.tileTemplate(token: " a&b ")?.hasSuffix("token=a%26b") == true)
    }
}
