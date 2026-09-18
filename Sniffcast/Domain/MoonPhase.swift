import Foundation

/// The moon's phase, worked out from the date alone: no request, no location.
///
/// Uses the mean synodic month counted from a known new moon, which is within about
/// half a day of the true phase. Each case covers the eighth of the month centred on it.
enum MoonPhase: Int, CaseIterable, Sendable {
    case newMoon, waxingCrescent, firstQuarter, waxingGibbous, full, waningGibbous, lastQuarter, waningCrescent

    /// Mean length of a lunation, in days.
    static let synodicMonth = 29.530588853
    /// 6 January 2000, 18:14 UTC.
    private static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)

    static func at(_ date: Date) -> MoonPhase {
        let days = date.timeIntervalSince(referenceNewMoon) / 86_400
        let age = days.truncatingRemainder(dividingBy: synodicMonth)
        let fraction = (age < 0 ? age + synodicMonth : age) / synodicMonth
        // Adding half an eighth before truncating centres each bucket on its phase.
        return MoonPhase(rawValue: Int(fraction * 8 + 0.5) % 8)!
    }

    /// SF Symbols draw the moon as seen from the northern hemisphere. From the south it is
    /// mirrored, and a mirrored waxing moon is the waning shape, so swapping is enough.
    ///
    /// The `.inverse` variants fill the lit part. The plain ones fill the shadow, which in the
    /// template menu bar image makes a new moon look full.
    func symbol(southernHemisphere: Bool) -> String {
        let shown = southernHemisphere ? MoonPhase(rawValue: (8 - rawValue) % 8)! : self
        return shown.baseSymbol + ".inverse"
    }

    private var baseSymbol: String {
        switch self {
        case .newMoon: return "moonphase.new.moon"
        case .waxingCrescent: return "moonphase.waxing.crescent"
        case .firstQuarter: return "moonphase.first.quarter"
        case .waxingGibbous: return "moonphase.waxing.gibbous"
        case .full: return "moonphase.full.moon"
        case .waningGibbous: return "moonphase.waning.gibbous"
        case .lastQuarter: return "moonphase.last.quarter"
        case .waningCrescent: return "moonphase.waning.crescent"
        }
    }
}
