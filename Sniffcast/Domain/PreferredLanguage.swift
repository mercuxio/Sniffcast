import Foundation

/// The Mac's first preferred language, for services that return place names.
///
/// Read from `Locale.preferredLanguages` rather than `Locale.current`: the app ships only
/// English strings, so `Locale.current` resolves to English whatever the user prefers. And
/// passed explicitly rather than left to the service's default, because Apple's geocoder
/// given no locale skips a regional English it has no names for (en-MY) and answers in the
/// *next* preferred language, which turned Kuala Lumpur into "吉隆坡".
enum PreferredLanguage {
    /// Full identifier, e.g. "en-MY" or "zh-Hans".
    static func identifier(_ preferred: [String] = Locale.preferredLanguages) -> String {
        preferred.first ?? "en"
    }

    /// Bare ISO 639 code, e.g. "en" or "zh", for APIs such as Open-Meteo's that take only that.
    static func code(_ preferred: [String] = Locale.preferredLanguages) -> String {
        Locale(identifier: identifier(preferred)).language.languageCode?.identifier ?? "en"
    }
}
