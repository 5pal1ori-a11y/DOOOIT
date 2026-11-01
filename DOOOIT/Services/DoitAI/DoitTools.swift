import Foundation
import FoundationModels

/// 두잇 AI가 부를 수 있는 앱 기능 (Apple 기기 안 AI의 도구 호출)
/// 기기 안 AI는 한 번에 볼 수 있는 글자 수가 적어서 도구 수와 설명을 짧게 유지
enum DoitTools {
    static var all: [any Tool] {
        [OverviewTool(), AddPlanTool(), UpdatePlanTool(), TimerTool(), AddWordsTool(),
         RecordsTool(), MemoTool(), SettingsTool(), OpenScreenTool()]
    }
}

struct OverviewTool: Tool {
    let name = "getDay"
    let description = "특정 날짜의 플랜 목록과 완료 여부, 오늘 공부 시간, D-Day를 확인"

    @Generable
    struct Arguments {
        @Guide(description: "날짜. 예: 오늘, 내일, 금요일, 다음주 월요일, 11월 5일")
        var date: String?
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { DoitActions.shared.overview(dateText: arguments.date) }
    }
}

struct AddPlanTool: Tool {
    let name = "addPlan"
    let description = "플래너에 일정(플랜)을 추가"

    @Generable
    struct Arguments {
        @Guide(description: "플랜 이름. 예: 수학 문제집 3단원")
        var title: String
        @Guide(description: "날짜. 예: 오늘, 내일, 수요일, 다음주 금요일, 11월 5일")
        var date: String?
        @Guide(description: "시작 시간. 예: 오후 3시, 19:30. 없으면 하루 종일")
        var time: String?
        @Guide(description: "걸리는 시간(분). 기본 60")
        var minutes: Int?
        @Guide(description: "공부 플랜이면 true (타이머 자동 시작)")
        var isStudy: Bool
        @Guide(description: "반복: none, daily, weekly, monthly")
        var repeatRule: String?
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            DoitActions.shared.addPlan(title: arguments.title, dateText: arguments.date, timeText: arguments.time,
                                       minutes: arguments.minutes, isStudy: arguments.isStudy, allDay: false,
                                       repeatText: arguments.repeatRule)
        }
    }
}

struct UpdatePlanTool: Tool {
    let name = "updatePlan"
    let description = "플랜을 완료 체크, 완료 취소, 삭제"

    @Generable
    struct Arguments {
        @Guide(description: "플랜 이름 (일부만 써도 됨)")
        var title: String
        @Guide(description: "날짜. 기본 오늘")
        var date: String?
        @Guide(description: "complete, uncomplete, delete 중 하나", .anyOf(["complete", "uncomplete", "delete"]))
        var action: String
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            DoitActions.shared.updatePlan(title: arguments.title, dateText: arguments.date, action: arguments.action)
        }
    }
}

struct TimerTool: Tool {
    let name = "studyTimer"
    let description = "공부 타이머 시작, 일시정지, 종료"

    @Generable
    struct Arguments {
        @Guide(description: "start, pause, stop 중 하나", .anyOf(["start", "pause", "stop"]))
        var action: String
        @Guide(description: "공부 내용. 예: 영어 단어")
        var title: String?
        @Guide(description: "목표 시간(분)")
        var minutes: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            DoitActions.shared.timer(action: arguments.action, title: arguments.title, minutes: arguments.minutes)
        }
    }
}

struct AddWordsTool: Tool {
    let name = "addWords"
    let description = "영어 단어장에 단어와 뜻을 추가"

    @Generable
    struct Pair {
        var term: String
        @Guide(description: "한국어 뜻")
        var meaning: String
    }

    @Generable
    struct Arguments {
        var words: [Pair]
    }

    func call(arguments: Arguments) async throws -> String {
        let pairs = arguments.words.map { ($0.term, $0.meaning) }
        return await MainActor.run { DoitActions.shared.addWords(pairs) }
    }
}

struct RecordsTool: Tool {
    let name = "getRecords"
    let description = "기록 보기: 공부 통계, 단어장 현황, 오답노트 현황, 메모 목록"

    @Generable
    struct Arguments {
        @Guide(description: "stats, words, notes, memos 중 하나", .anyOf(["stats", "words", "notes", "memos"]))
        var kind: String
        @Guide(description: "통계 기간(일). 기본 7")
        var days: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            arguments.kind == "stats"
                ? DoitActions.shared.stats(days: arguments.days ?? 7)
                : DoitActions.shared.records(kind: arguments.kind)
        }
    }
}

struct MemoTool: Tool {
    let name = "memo"
    let description = "메모장에 메모 저장 또는 메모 검색"

    @Generable
    struct Arguments {
        @Guide(description: "add 또는 search", .anyOf(["add", "search"]))
        var action: String
        @Guide(description: "저장할 내용 또는 검색어")
        var text: String
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            arguments.action == "search"
                ? DoitActions.shared.searchMemos(arguments.text)
                : DoitActions.shared.addMemo(arguments.text)
        }
    }
}

struct SettingsTool: Tool {
    let name = "setGoals"
    let description = "D-Day, 하루 공부 목표 시간, 하루 단어 목표 개수 설정"

    @Generable
    struct Arguments {
        @Guide(description: "D-Day 이름. 예: 기말고사")
        var dDayTitle: String?
        @Guide(description: "D-Day 날짜. 예: 12월 10일")
        var dDayDate: String?
        @Guide(description: "하루 공부 목표(분)")
        var studyGoalMinutes: Int?
        @Guide(description: "하루 외울 단어 수")
        var wordGoal: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            DoitActions.shared.settings(dDayTitle: arguments.dDayTitle, dDayDate: arguments.dDayDate,
                                        studyGoalMinutes: arguments.studyGoalMinutes, wordGoal: arguments.wordGoal)
        }
    }
}

struct OpenScreenTool: Tool {
    let name = "openScreen"
    let description = "앱 화면으로 이동"

    @Generable
    struct Arguments {
        @Guide(description: "home, planner, study, timer, account 중 하나", .anyOf(["home", "planner", "study", "timer", "account"]))
        var screen: String
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { DoitActions.shared.open(arguments.screen) }
    }
}
