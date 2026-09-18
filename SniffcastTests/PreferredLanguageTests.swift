import Testing

struct PreferredLanguageTests {
    @Test func usesFirstPreferredLanguage() {
        #expect(PreferredLanguage.identifier(["en-MY", "zh-Hans"]) == "en-MY")
        #expect(PreferredLanguage.code(["en-MY", "zh-Hans"]) == "en")
    }

    @Test func reducesScriptVariantToLanguageCode() {
        #expect(PreferredLanguage.code(["zh-Hans-MY"]) == "zh")
    }

    @Test func fallsBackToEnglish() {
        #expect(PreferredLanguage.identifier([]) == "en")
        #expect(PreferredLanguage.code([]) == "en")
    }
}
