import Foundation

/// 단어 복습 일정 (간격 반복): 외운 날부터 1일 → 3일 → 7일 → 14일 → 30일 뒤에 다시 물어봄.
/// 복습에서 한 번에 맞히면 다음 간격으로, 틀리면 1일 뒤부터 다시. 30일 복습까지 통과하면 "완전히 외움"
enum WordReview {
    /// 단계별 간격 (일). 단계 1 = 1일 뒤 복습을 기다리는 중
    static let intervals = [1, 3, 7, 14, 30]
    /// 다섯 번 복습을 모두 통과
    static let mastered = intervals.count + 1

    struct Schedule: Equatable {
        let stage: Int
        let next: Date?
    }

    private static func day(_ date: Date, plus days: Int, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: days, to: start) ?? start.addingTimeInterval(Double(days) * 86400)
    }

    /// 처음 외운 직후 → 내일 첫 복습
    static func afterLearning(now: Date = Date(), calendar: Calendar = .current) -> Schedule {
        Schedule(stage: 1, next: day(now, plus: intervals[0], calendar: calendar))
    }

    /// 복습 결과 (correct: 처음 물었을 때 바로 맞힘)
    static func afterReview(stage: Int, correct: Bool, now: Date = Date(), calendar: Calendar = .current) -> Schedule {
        guard correct else { return afterLearning(now: now, calendar: calendar) }
        let next = max(stage, 1) + 1
        if next > intervals.count { return Schedule(stage: mastered, next: nil) }
        return Schedule(stage: next, next: day(now, plus: intervals[next - 1], calendar: calendar))
    }

    /// 오늘 복습할 차례인지
    static func isDue(stage: Int, next: Date?, now: Date = Date()) -> Bool {
        guard (1...intervals.count).contains(stage), let next else { return false }
        return next <= now
    }

    /// 예전에 외운 단어(일정 없음): 외운 날 기준으로 첫 복습 일정을 잡음
    static func legacy(learnedAt: Date, calendar: Calendar = .current) -> Schedule {
        afterLearning(now: learnedAt, calendar: calendar)
    }

    /// "내일", "3일 뒤", "11월 9일"
    static func describe(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case ...0: return "오늘"
        case 1: return "내일"
        case 2...6: return "\(days)일 뒤"
        default:
            let parts = calendar.dateComponents([.month, .day], from: date)
            return "\(parts.month ?? 0)월 \(parts.day ?? 0)일"
        }
    }
}
