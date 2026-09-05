import Foundation

enum RelativeTimestamp {
    static func string(from date: Date, now: Date = .now) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(date)))
        switch elapsed {
        case 0..<60:
            return "1 dakikadan az"
        case 60..<3_600:
            return "\(elapsed / 60) dakika önce"
        case 3_600..<86_400:
            return "\(elapsed / 3_600) saat önce"
        case 86_400..<604_800:
            return "\(elapsed / 86_400) gün önce"
        case 604_800..<2_592_000:
            return "\(elapsed / 604_800) hafta önce"
        case 2_592_000..<31_536_000:
            return "\(elapsed / 2_592_000) ay önce"
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "tr_TR")
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}
