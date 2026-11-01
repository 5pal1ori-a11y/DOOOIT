import Foundation

enum KoreanDate {
    private static var cache: [String: DateFormatter] = [:]
    private static let lock = NSLock()

    /// 날짜 키 전용 (DateFormatter는 만든 뒤 바꾸지 않으면 여러 스레드에서 읽어도 안전)
    static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func formatter(_ pattern: String) -> DateFormatter {
        lock.lock(); defer { lock.unlock() }
        if let f = cache[pattern] { return f }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        // 사용자가 시간대를 바꿔도 바로 따라가도록 autoupdating 사용
        f.calendar = .autoupdatingCurrent
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = pattern
        cache[pattern] = f
        return f
    }
}

extension Date {
    /// 한국어 날짜 문자열 (예: "M월 d일 EEEE")
    func kr(_ pattern: String) -> String {
        KoreanDate.formatter(pattern).string(from: self)
    }

    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var startOfMonth: Date {
        let comps = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: comps) ?? self
    }

    /// "yyyy-MM-dd" (저장용 키: 기기 달력 설정(불기·일본력 등)과 상관없이 양력 숫자로)
    var dayKey: String { KoreanDate.dayKeyFormatter.string(from: self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func isSameMonth(as other: Date) -> Bool {
        let c = Calendar.current
        return c.component(.year, from: self) == c.component(.year, from: other)
            && c.component(.month, from: self) == c.component(.month, from: other)
    }

    /// 날짜(self)에 시간(time)의 시/분을 합침
    func combined(withTime time: Date) -> Date {
        let c = Calendar.current
        let t = c.dateComponents([.hour, .minute], from: time)
        return c.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: self) ?? self
    }
}

enum TimeText {
    /// 01:23:45
    static func clock(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    /// 1시간 20분 / 45분
    static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h)시간 \(m)분" }
        if h > 0 { return "\(h)시간" }
        return "\(m)분"
    }

    static func duration(seconds: Int) -> String {
        duration(minutes: seconds / 60)
    }
}

enum Greeting {
    /// 시간대별 인사말
    static func text(name: String, at date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<12: return "\(name)님, 오늘도 힘내보아요!"
        case 12..<13: return "\(name)님, 즐거운 점심시간 되세요."
        case 13..<18: return "\(name)님, 즐거운 오후에요."
        case 18..<19: return "\(name)님, 즐거운 저녁시간이에요."
        case 19..<24: return "\(name)님, 남은 하루도 힘내세요!"
        default: return "\(name)님, 조용한 새벽이에요."
        }
    }

    static func symbol(at date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<12: return "sun.max.fill"
        case 12..<13: return "fork.knife"
        case 13..<18: return "sun.haze.fill"
        case 18..<19: return "sunset.fill"
        case 19..<24: return "moon.stars.fill"
        default: return "moon.zzz.fill"
        }
    }
}
