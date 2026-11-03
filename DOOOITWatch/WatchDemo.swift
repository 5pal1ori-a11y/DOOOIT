import Foundation

/// 화면 사진 찍기용 예시 상태 (Debug 빌드에서 `-uiShot timer|today|words` 로 켤 때만)
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
        case "today": return .today
        case "words", "wordsBack": return .words
        default: return .timer
        }
    }

    #if DEBUG
    static var snapshot: WatchSnapshot? {
        guard let screen else { return nil }
        let now = Date()
        let day = WatchLink.dayKey(now)
        var s = WatchSnapshot()
        s.updatedAt = now
        s.dayKey = day
        s.savedSeconds = 95 * 60
        s.goalMinutes = 180
        if screen == "timer" {
            s.timer = WatchTimerState(phase: .running, title: "자유 공부", targetSeconds: 25 * 60,
                                      runningSince: now.addingTimeInterval(-(9 * 60 + 24)))
        }
        s.plans = [
            WatchPlanItem(id: "a_\(day)", planID: "a", dayKey: day, title: "수학 문제집 3단원", time: "오후 4:00", colorHex: "#3D9BE0", isDone: true, isStudy: true),
            WatchPlanItem(id: "b_\(day)", planID: "b", dayKey: day, title: "영어 단어 30개", time: "오후 7:00", colorHex: "#7B68EE", isDone: false, isStudy: true),
            WatchPlanItem(id: "c_\(day)", planID: "c", dayKey: day, title: "국어 비문학", time: "오후 9:00", colorHex: "#4CAF63", isDone: false, isStudy: true)
        ]
        s.words = [
            WatchWordItem(id: "w1", term: "abundant", meaning: "풍부한"),
            WatchWordItem(id: "w2", term: "resilient", meaning: "회복력 있는"),
            WatchWordItem(id: "w3", term: "diligent", meaning: "부지런한")
        ]
        return s
    }
    #endif
}
