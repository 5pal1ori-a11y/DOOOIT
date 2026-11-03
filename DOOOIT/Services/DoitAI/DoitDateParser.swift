import Foundation

/// 모티 AI가 넘겨준 날짜·시간 표현을 실제 날짜로 바꿈
/// (AI가 날짜를 직접 계산하면 틀릴 수 있어서 "내일", "다음주 월요일", "오후 3시" 같은 말을 그대로 받아 앱에서 계산)
enum DoitDateParser {
    private static let weekdays: [(String, Int)] = [
        ("일요일", 1), ("월요일", 2), ("화요일", 3), ("수요일", 4), ("목요일", 5), ("금요일", 6), ("토요일", 7),
        ("일", 1), ("월", 2), ("화", 3), ("수", 4), ("목", 5), ("금", 6), ("토", 7)
    ]

    /// 날짜 (하루의 시작). 못 읽으면 nil
    static func date(_ text: String?, now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let raw = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw == "오늘" || raw.lowercased() == "today" { return today }
        let t = raw.replacingOccurrences(of: " ", with: "")

        let relative: [String: Int] = ["어제": -1, "내일": 1, "모레": 2, "내일모레": 2, "글피": 3, "tomorrow": 1]
        if let days = relative[t.lowercased()] { return calendar.date(byAdding: .day, value: days, to: today) }

        // N일 후 / N일 뒤 / N주 후
        if let match = t.firstMatch(of: #/(\d+)일(후|뒤)/#), let n = Int(match.1) {
            return calendar.date(byAdding: .day, value: n, to: today)
        }
        if let match = t.firstMatch(of: #/(\d+)주(후|뒤)/#), let n = Int(match.1) {
            return calendar.date(byAdding: .day, value: n * 7, to: today)
        }

        // yyyy-MM-dd, yyyy.MM.dd, yyyy/MM/dd
        if let match = t.firstMatch(of: #/(\d{4})[-.\/](\d{1,2})[-.\/](\d{1,2})/#),
           let y = Int(match.1), let m = Int(match.2), let d = Int(match.3) {
            return calendar.date(from: DateComponents(year: y, month: m, day: d))
        }
        // M월 d일
        if let match = t.firstMatch(of: #/(\d{1,2})월(\d{1,2})일/#), let m = Int(match.1), let d = Int(match.2) {
            return upcoming(month: m, day: d, from: today)
        }
        // M/d, M-d, M.d
        if let match = t.firstMatch(of: #/^(\d{1,2})[-.\/](\d{1,2})$/#), let m = Int(match.1), let d = Int(match.2) {
            return upcoming(month: m, day: d, from: today)
        }
        // d일 (이번 달, 지났으면 다음 달)
        if let match = t.firstMatch(of: #/^(\d{1,2})일$/#), let d = Int(match.1) {
            var parts = calendar.dateComponents([.year, .month], from: today)
            parts.day = d
            if let date = calendar.date(from: parts) {
                return date < today ? calendar.date(byAdding: .month, value: 1, to: date) : date
            }
        }

        // (이번주|다음주|다다음주) X요일
        let weekOffset: Int
        var rest = t
        if rest.hasPrefix("다다음주") { weekOffset = 2; rest.removeFirst(4) }
        else if rest.hasPrefix("다음주") { weekOffset = 1; rest.removeFirst(3) }
        else if rest.hasPrefix("이번주") { weekOffset = 0; rest.removeFirst(3) }
        else { weekOffset = -1 }
        if weekOffset >= 0 && rest.isEmpty {
            return calendar.date(byAdding: .day, value: 7 * weekOffset, to: today)
        }
        for (name, weekday) in weekdays where rest == name || rest == name + "날" {
            let current = calendar.component(.weekday, from: today)
            // 월요일을 한 주의 시작으로 계산
            let mondayBased = { (w: Int) in (w + 5) % 7 }
            if weekOffset < 0 {
                // 그냥 "금요일": 오늘 포함 가장 가까운 그 요일
                let diff = (weekday - current + 7) % 7
                return calendar.date(byAdding: .day, value: diff, to: today)
            }
            let diff = mondayBased(weekday) - mondayBased(current) + 7 * weekOffset
            return calendar.date(byAdding: .day, value: diff, to: today)
        }
        return nil
    }

    /// 시간 (시, 분). "15:30", "오후 3시 30분", "3시 반", "오전 9시". 못 읽으면 nil
    static func time(_ text: String?) -> (hour: Int, minute: Int)? {
        let raw = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let t = raw.replacingOccurrences(of: " ", with: "").lowercased()
        var hour: Int?
        var minute = 0
        if let match = t.firstMatch(of: #/(\d{1,2}):(\d{2})/#) {
            hour = Int(match.1)
            minute = Int(match.2) ?? 0
        } else if let match = t.firstMatch(of: #/(\d{1,2})시(\d{1,2})?분?/#) {
            hour = Int(match.1)
            if let m = match.2, let value = Int(m) { minute = value }
            if t.contains("반") { minute = 30 }
        } else if let match = t.firstMatch(of: #/^(\d{1,2})(am|pm)?$/#) {
            hour = Int(match.1)
        }
        guard var h = hour, (0...24).contains(h), (0...59).contains(minute) else { return nil }
        let pm = t.contains("오후") || t.contains("저녁") || t.contains("밤") || t.contains("pm")
        let am = t.contains("오전") || t.contains("아침") || t.contains("새벽") || t.contains("am")
        if pm && h < 12 { h += 12 }
        if am && h == 12 { h = 0 }
        // 오전/오후 표시가 없고 1~7시면 공부 시간대로 보고 오후로
        if !pm && !am && (1...7).contains(h) { h += 12 }
        return (h % 24, minute)
    }

    private static func upcoming(month: Int, day: Int, from today: Date) -> Date? {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: today)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        // 이미 많이 지난 날짜면 내년으로
        if date < calendar.date(byAdding: .day, value: -30, to: today) ?? today {
            return calendar.date(from: DateComponents(year: year + 1, month: month, day: day))
        }
        return date
    }
}
