import Foundation

/// 화면 사진 찍기용 예시 상태 (Debug 빌드에서 `-uiShot <화면>` 으로 켤 때만)
/// timer · picker · tasks · focus · rest · summary · settings · today · words · wordsBack · quiz · ask
enum WatchDemo {
    static let screen: String? = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-uiShot"), i + 1 < args.count else { return nil }
        return args[i + 1]
        #else
        return nil
        #endif
    }()

    static var tab: WatchTab {
        switch screen {
        case "summary", "settings": return .summary
        case "today": return .today
        case "words", "wordsBack", "quiz": return .words
        case "ask": return .ask
        default: return .timer
        }
    }

    #if DEBUG
    static var snapshot: WatchSnapshot? {
        guard let screen else { return nil }
        let now = Date()
        let day = WatchLink.dayKey(now)
        let tomorrowDate = now.addingTimeInterval(86_400)
        let tomorrow = WatchLink.dayKey(tomorrowDate)
        var s = WatchSnapshot()
        s.updatedAt = now
        s.dayKey = day
        s.savedSeconds = 95 * 60
        s.goalMinutes = 180
        s.week = [2 * 3600, 3 * 3600 + 600, 40 * 60, 0, 2 * 3600 + 1800, 3 * 3600 + 1200, 95 * 60]
        s.streak = 3
        s.wordsToday = 12
        s.mistakes = 4
        switch screen {
        case "timer":
            s.timer = WatchTimerState(phase: .running, title: "수학 문제집 3단원", targetSeconds: 25 * 60,
                                      runningSince: now.addingTimeInterval(-(9 * 60 + 24)))
        case "focus":
            s.timer = WatchTimerState(phase: .running, title: "뽀모도로", targetSeconds: 25 * 60,
                                      runningSince: now.addingTimeInterval(-(17 * 60 + 5)))
        default:
            break
        }
        s.plans = [
            WatchPlanItem(id: "a_\(day)", planID: "a", dayKey: day, title: "수학 문제집 3단원", time: "오후 4:00", colorHex: "#3D9BE0",
                          isDone: true, isStudy: true, start: now.addingTimeInterval(-3_600)),
            WatchPlanItem(id: "b_\(day)", planID: "b", dayKey: day, title: "영어 단어 30개", time: "오후 7:00", colorHex: "#7B68EE",
                          isDone: false, isStudy: true, start: now.addingTimeInterval(25 * 60)),
            WatchPlanItem(id: "c_\(day)", planID: "c", dayKey: day, title: "국어 비문학", time: "오후 9:00", colorHex: "#4CAF63",
                          isDone: false, isStudy: true, start: now.addingTimeInterval(3 * 3600))
        ]
        s.tomorrow = [
            WatchPlanItem(id: "d_\(tomorrow)", planID: "d", dayKey: tomorrow, title: "수학 모의고사", time: "오전 9:00", colorHex: "#3D9BE0",
                          isDone: false, isStudy: true, start: tomorrowDate),
            WatchPlanItem(id: "e_\(tomorrow)", planID: "e", dayKey: tomorrow, title: "스터디 모임", time: "오후 6:00", colorHex: "#F2994A",
                          isDone: false, isStudy: false, start: tomorrowDate)
        ]
        s.ddays = [
            WatchDDay(id: "x", title: "기말고사", dayKey: WatchLink.dayKey(now.addingTimeInterval(86_400 * 5))),
            WatchDDay(id: "y", title: "수능", dayKey: WatchLink.dayKey(now.addingTimeInterval(86_400 * 15)))
        ]
        s.words = [
            WatchWordItem(id: "w1", term: "abundant", meaning: "풍부한", choices: ["부지런한", "풍부한", "드문", "회복력 있는"]),
            WatchWordItem(id: "w2", term: "resilient", meaning: "회복력 있는", choices: ["회복력 있는", "풍부한", "조용한", "부지런한"]),
            WatchWordItem(id: "w3", term: "diligent", meaning: "부지런한", choices: ["드문", "조용한", "부지런한", "풍부한"])
        ]
        s.practice = [
            WatchWordItem(id: "p1", term: "scarce", meaning: "드문", choices: ["드문", "풍부한", "조용한", "부지런한"])
        ]
        s.answer = WatchAnswer(id: "demo", question: "오늘 할 일 알려줘",
                               text: "오늘 할 일 3개 중 1개 완료\n다음: 오후 7:00 영어 단어 30개")
        return s
    }

    static var pending: [WatchCommand] { [] }

    static var focus: WatchFocusCycle? {
        let now = Date()
        switch screen {
        case "focus":
            return WatchFocusCycle()
        case "rest":
            var c = WatchFocusCycle()
            c.stage = .rest
            c.restUntil = now.addingTimeInterval(3 * 60 + 12)
            return c
        default:
            return nil
        }
    }
    #endif
}
