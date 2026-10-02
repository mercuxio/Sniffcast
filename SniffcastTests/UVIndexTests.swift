import Testing

struct UVIndexTests {
    @Test func roundsToWholeNumbers() {
        #expect(UVIndex.rounded(0.95) == 1)
        #expect(UVIndex.rounded(2.4) == 2)
        #expect(UVIndex.rounded(7.5) == 8)
    }

    /// The category follows the number shown, so "UV 3" is always Moderate.
    @Test func levelsFollowTheRoundedValue() {
        #expect(UVIndex.level(for: 0).label == "Low")
        #expect(UVIndex.level(for: 2.4).label == "Low")
        #expect(UVIndex.level(for: 2.6).label == "Moderate")
        #expect(UVIndex.level(for: 5.4).label == "Moderate")
        #expect(UVIndex.level(for: 6).label == "High")
        #expect(UVIndex.level(for: 7.4).label == "High")
        #expect(UVIndex.level(for: 8).label == "Very high")
        #expect(UVIndex.level(for: 10.4).label == "Very high")
        #expect(UVIndex.level(for: 11).label == "Extreme")
        #expect(UVIndex.level(for: 14.8).label == "Extreme")
    }

    @Test func levelColorsRiseWithExposure() {
        let bands = [0.0, 3, 6, 8, 11].map { UVIndex.level(for: $0).band.rawValue }
        #expect(bands == bands.sorted() && Set(bands).count == 5)
    }
}

@Suite struct UVRangeTests {
    @Test func rangeRunsFromThreeUpToThePeak() {
        #expect(UVIndex.rangeLabel(peak: 8.6) == "3–9")
        #expect(UVIndex.rangeLabel(peak: 3.6) == "3–4")
    }

    @Test func singleNumberAtOrBelowTheThreshold() {
        #expect(UVIndex.rangeLabel(peak: 3.0) == "3")
        #expect(UVIndex.rangeLabel(peak: 2.4) == "2")
        #expect(UVIndex.rangeLabel(peak: 0.2) == "0")
    }
}
