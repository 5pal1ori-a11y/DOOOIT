import Foundation

/// 친구끼리 같은 기준으로 "오늘"과 "이번 주"를 셈: 한국 시간(UTC+9, 서머타임 없음), 주는 월요일 시작 ISO 주
/// (랭킹의 주간 리더보드와 같은 기준)
enum SocialClock {
    static let timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? TimeZone(identifier: "UTC")!

    static var calendar: Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = timeZone
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }

    /// "2026-11-07"
    static func dayKey(_ date: Date) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }

    /// "2026-W45" (ISO 주 번호)
    static func weekKey(_ date: Date) -> String {
        let p = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", p.yearForWeekOfYear ?? 0, p.weekOfYear ?? 0)
    }

    static func dayRange(_ date: Date) -> (start: Date, end: Date) {
        interval(.day, date, fallback: 86_400)
    }

    static func weekRange(_ date: Date) -> (start: Date, end: Date) {
        interval(.weekOfYear, date, fallback: 7 * 86_400)
    }

    private static func interval(_ component: Calendar.Component, _ date: Date, fallback: TimeInterval) -> (start: Date, end: Date) {
        if let i = calendar.dateInterval(of: component, for: date) { return (i.start, i.end) }
        return (date, date.addingTimeInterval(fallback))
    }

    /// 한 번의 공부 [start, start+seconds) 가운데 구간과 겹치는 초 (자정을 넘긴 공부는 날마다 나눠서 셈)
    static func overlap(start: Date, seconds: Int, range: (start: Date, end: Date)) -> Int {
        guard seconds > 0 else { return 0 }
        let end = start.addingTimeInterval(TimeInterval(seconds))
        let lo = max(start, range.start)
        let hi = min(end, range.end)
        return hi > lo ? Int(hi.timeIntervalSince(lo)) : 0
    }

    struct Totals: Equatable {
        var today: Int
        var week: Int
    }

    /// 공부 기록들(+ 지금 하는 공부)에서 오늘 · 이번 주 공부 시간
    static func totals(sessions: [(start: Date, seconds: Int)], now: Date) -> Totals {
        let day = dayRange(now), week = weekRange(now)
        var today = 0, thisWeek = 0
        for s in sessions {
            today += overlap(start: s.start, seconds: s.seconds, range: day)
            thisWeek += overlap(start: s.start, seconds: s.seconds, range: week)
        }
        return Totals(today: min(today, SocialLimits.daySecondsMax), week: min(thisWeek, SocialLimits.weekSecondsMax))
    }
}
