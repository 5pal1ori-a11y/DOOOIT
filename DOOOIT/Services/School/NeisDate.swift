import Foundation

/// 날짜 도우미 (한국 시간 기준, 주는 월요일 시작). 날짜는 "yyyyMMdd" 글자로 다뤄요.
enum NeisDate {
    static let timeZone = TimeZone(identifier: "Asia/Seoul") ?? TimeZone(secondsFromGMT: 9 * 3600)!

    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return c
    }()

    static func ymd(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "yyyyMMdd" → 그날 한국 시간 낮 12시 (Date). 잘못된 날짜면 nil
    static func date(_ ymd: String) -> Date? {
        guard let parts = components(ymd) else { return nil }
        var c = DateComponents()
        c.year = parts.y; c.month = parts.m; c.day = parts.d; c.hour = 12
        c.timeZone = timeZone
        guard let date = calendar.date(from: c) else { return nil }
        // 2월 30일 같은 날짜는 넘어가므로 되돌려 확인
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        guard back.year == parts.y, back.month == parts.m, back.day == parts.d else { return nil }
        return date
    }

    static func components(_ ymd: String) -> (y: Int, m: Int, d: Int)? {
        let chars = Array(ymd)
        guard chars.count == 8, chars.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        guard let y = Int(String(chars[0..<4])), let m = Int(String(chars[4..<6])), let d = Int(String(chars[6..<8])) else { return nil }
        guard (1...12).contains(m), (1...31).contains(d), y >= 1900 else { return nil }
        return (y, m, d)
    }

    static func isValid(_ ymd: String) -> Bool { date(ymd) != nil }

    static func addDays(_ ymd: String, _ days: Int) -> String? {
        guard let base = date(ymd), let moved = calendar.date(byAdding: .day, value: days, to: base) else { return nil }
        return Self.ymd(moved)
    }

    /// 요일 번호: 월 0 … 일 6
    static func weekdayIndex(_ date: Date) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    static func weekdayIndex(ymd: String) -> Int? {
        date(ymd).map(weekdayIndex)
    }

    /// 그 날이 들어 있는 주의 월요일
    static func weekStart(containing date: Date) -> String {
        let monday = calendar.date(byAdding: .day, value: -weekdayIndex(date), to: date) ?? date
        return ymd(monday)
    }

    /// 지금(또는 주어진 날)에서 offset주 뒤의 월요일
    static func weekStart(offset: Int, from date: Date) -> String {
        let monday = weekStart(containing: date)
        return addDays(monday, offset * 7) ?? monday
    }

    /// 월~금 (includeSaturday면 월~토) 날짜 목록
    static func weekDays(start: String, includeSaturday: Bool = false) -> [String] {
        (0..<(includeSaturday ? 6 : 5)).compactMap { addDays(start, $0) }
    }

    /// 시간표를 한 번에 받는 범위: 월 ~ 토 (토요일 수업/휴업일도 같이 받음)
    static func timetableRange(weekStart: String) -> (from: String, to: String) {
        (weekStart, addDays(weekStart, 5) ?? weekStart)
    }

    /// 급식을 받는 범위: 월 ~ 일 한 주
    static func mealRange(weekStart: String) -> (from: String, to: String) {
        (weekStart, addDays(weekStart, 6) ?? weekStart)
    }

    static let weekdayShort = ["월", "화", "수", "목", "금", "토", "일"]

    /// "yyyyMMdd" → 일 숫자
    static func dayNumber(_ ymd: String) -> Int? { components(ymd)?.d }

    /// 학년도 (3월 시작): 1·2월은 전년도
    static func academicYear(_ date: Date) -> Int {
        let c = calendar.dateComponents([.year, .month], from: date)
        let y = c.year ?? 0
        return (c.month ?? 3) < 3 ? y - 1 : y
    }
}
