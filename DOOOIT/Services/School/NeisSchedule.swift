import Foundation

// MARK: - 시도교육청

enum NeisOffice {
    /// (교육청 코드, 짧은 이름)
    static let all: [(code: String, name: String)] = [
        ("B10", "서울"), ("C10", "부산"), ("D10", "대구"), ("E10", "인천"), ("F10", "광주"), ("G10", "대전"),
        ("H10", "울산"), ("I10", "세종"), ("J10", "경기"), ("K10", "강원"), ("M10", "충북"), ("N10", "충남"),
        ("P10", "전북"), ("Q10", "전남"), ("R10", "경북"), ("S10", "경남"), ("T10", "제주")
    ]

    static func name(_ code: String) -> String? { all.first { $0.code == code }?.name }
}

// MARK: - 지금 몇 교시인지 (대략)

/// 학교마다 시간은 다르지만, 학교급별로 흔한 시간표로 "지금 교시"를 어림잡아요 (표시용)
enum NeisPeriodClock {
    /// 1교시 시작(분), 수업(분), 쉬는 시간(분), 점심 전 교시 수, 점심(분)
    static func rule(_ kind: SchoolKind) -> (start: Int, lesson: Int, rest: Int, lunchAfter: Int, lunch: Int) {
        switch kind {
        case .elementary: return (9 * 60, 40, 10, 4, 50)
        case .middle, .other: return (8 * 60 + 50, 45, 10, 4, 50)
        case .high: return (8 * 60 + 40, 50, 10, 4, 70)
        }
    }

    /// 교시 시작 시각(자정부터 분)
    static func startMinute(period: Int, kind: SchoolKind) -> Int {
        let r = rule(kind)
        var t = r.start
        if period > 1 {
            for p in 1..<period {
                t += r.lesson + r.rest
                if p == r.lunchAfter { t += r.lunch - r.rest }
            }
        }
        return t
    }

    /// 지금(자정부터 분)이 속한 교시. 첫 교시 10분 전보다 이르거나 마지막 교시 뒤면 nil. 쉬는 시간·점심은 다음 교시로 침
    static func currentPeriod(minute: Int, kind: SchoolKind, maxPeriod: Int = 10) -> Int? {
        guard maxPeriod >= 1 else { return nil }
        let r = rule(kind)
        guard minute >= r.start - 10 else { return nil }
        for p in 1...maxPeriod where minute < startMinute(period: p, kind: kind) + r.lesson {
            return p
        }
        return nil
    }

    static func minuteOfDay(_ date: Date) -> Int {
        let c = NeisDate.calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
