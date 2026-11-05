import Foundation

// 앱 화면 전용 번역 도우미 (엔진의 한국어 답·Linux 테스트와는 따로: 엔진은 TimeText.duration · Date.kr 그대로)

extension TimeText {
    /// 화면용 시간 글자: "1시간 20분" / "1h 20m" / "1小时20分钟" / "1時間20分"
    static func durationL(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return L("\(h)시간 \(m)분") }
        if h > 0 { return L("\(h)시간") }
        return L("\(m)분")
    }

    static func durationL(seconds: Int) -> String {
        durationL(minutes: seconds / 60)
    }
}

extension WordReview {
    /// 화면용 "내일", "3일 뒤", "11월 9일" (고른 언어로)
    static func describeL(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case ...0: return L("오늘")
        case 1: return L("내일")
        case 2...6: return L("\(days)일 뒤")
        default: return date.ui("M월 d일")
        }
    }
}

extension BadgeBook.Badge {
    /// 화면용 "3 / 7일" (고른 언어로)
    func progressTextL(_ stats: BadgeBook.Stats) -> String {
        let v = min(value(stats), target), t = target
        switch metric {
        case .streak: return L("\(v) / \(t)일")
        case .hours, .bestDay: return L("\(v) / \(t)시간")
        case .words, .fixed, .notes: return L("\(v) / \(t)개")
        case .ai, .mock, .perfect, .focus: return L("\(v) / \(t)번")
        }
    }
}

extension Greeting {
    /// 화면용 시간대 인사 (고른 언어로)
    static func textL(name: String, at date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<12: return L("\(name)님, 오늘도 힘내보아요!")
        case 12..<13: return L("\(name)님, 즐거운 점심시간 되세요.")
        case 13..<18: return L("\(name)님, 즐거운 오후에요.")
        case 18..<19: return L("\(name)님, 즐거운 저녁시간이에요.")
        case 19..<24: return L("\(name)님, 남은 하루도 힘내세요!")
        default: return L("\(name)님, 조용한 새벽이에요.")
        }
    }
}
