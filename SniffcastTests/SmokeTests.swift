import Testing

@Test func fixturesLoad() throws {
    #expect(try !Fixture.data("forecast_london").isEmpty)
}
