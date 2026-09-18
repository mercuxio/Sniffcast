import Testing

struct AlertEvaluatorTests {
    @Test func notifiesOnceThenRearmsBelowMargin() {
        var e = AlertEvaluator()
        let results = [90, 100, 120, 95, 100, 90, 101].map {
            e.evaluate(aqi: $0, threshold: 100, margin: 10, key: "a")
        }
        // Fires at 100; stays quiet until AQI falls to 90 (threshold − margin); fires again at 101.
        #expect(results == [false, true, false, false, false, false, true])
    }

    @Test func keysAreIndependent() {
        var e = AlertEvaluator()
        let london = e.evaluate(aqi: 70, threshold: 60, margin: 5, key: "london")
        let paris = e.evaluate(aqi: 70, threshold: 60, margin: 5, key: "paris")
        let londonAgain = e.evaluate(aqi: 70, threshold: 60, margin: 5, key: "london")
        #expect(london && paris && !londonAgain)
    }
}
