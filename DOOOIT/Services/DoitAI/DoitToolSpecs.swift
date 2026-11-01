import UIKit

/// 두잇 AI가 부를 수 있는 앱 기능 목록(서버로 보냄)과, 호출을 실제 동작으로 연결하는 부분
@MainActor
enum DoitToolSpecs {
    private static func tool(_ name: String, _ description: String,
                             _ properties: [String: [String: Any]], required: [String] = []) -> [String: Any] {
        [
            "name": name,
            "description": description,
            "input_schema": ["type": "object", "properties": properties, "required": required]
        ]
    }

    private static func text(_ description: String) -> [String: Any] { ["type": "string", "description": description] }
    private static func number(_ description: String) -> [String: Any] { ["type": "integer", "description": description] }
    private static func choice(_ values: [String], _ description: String) -> [String: Any] {
        ["type": "string", "enum": values, "description": description]
    }

    static let dateHint = "사용자가 말한 그대로. 예: 오늘, 내일, 모레, 금요일, 다음주 월요일, 11월 5일, 2026-11-05"

    static var all: [[String: Any]] {
        [
            tool("get_day", "특정 날짜의 플랜 목록과 완료 여부, 오늘 공부 시간, 타이머 상태, D-Day를 확인한다.",
                 ["date": text(dateHint)]),
            tool("add_plan", "플래너에 일정(플랜)을 추가한다. 공부 일정이면 is_study를 true로.",
                 ["title": text("플랜 이름. 예: 수학 문제집 3단원"),
                  "date": text(dateHint),
                  "time": text("시작 시간. 예: 오후 3시, 19:30. 생략하면 하루 종일"),
                  "minutes": number("걸리는 시간(분). 기본 60"),
                  "is_study": ["type": "boolean", "description": "공부 플랜이면 true (시간이 되면 타이머 자동 시작)"],
                  "repeat": choice(["none", "daily", "weekly", "monthly"], "반복")],
                 required: ["title", "is_study"]),
            tool("update_plan", "플랜을 완료 체크, 완료 취소, 또는 삭제한다.",
                 ["title": text("플랜 이름 (일부만 써도 됨)"),
                  "date": text(dateHint + ". 기본 오늘"),
                  "action": choice(["complete", "uncomplete", "delete"], "할 일")],
                 required: ["title", "action"]),
            tool("study_timer", "공부 타이머를 시작, 일시정지(다시 누르면 재개), 종료한다. 종료하면 공부 기록이 저장된다.",
                 ["action": choice(["start", "pause", "stop"], "할 일"),
                  "title": text("공부 내용. 예: 영어 단어"),
                  "minutes": number("목표 시간(분)")],
                 required: ["action"]),
            tool("add_words", "영어 단어장에 단어와 한국어 뜻을 추가한다. 사진 속 단어장도 읽어서 넣을 수 있다.",
                 ["words": ["type": "array", "description": "추가할 단어들",
                            "items": ["type": "object",
                                      "properties": ["term": text("영어 단어"), "meaning": text("한국어 뜻")],
                                      "required": ["term", "meaning"]]]],
                 required: ["words"]),
            tool("save_wrong_note", "사용자가 보낸 문제 사진(또는 문제 글)을 수학 오답노트에 저장한다. 사진 속 인쇄된 문제를 정확히 옮겨 적어서 넣는다.",
                 ["title": text("짧은 제목. 예: 이차함수 최댓값"),
                  "problem": text("문제 전체를 옮겨 적은 글. 수식은 x², √(…), (분자)/(분모)"),
                  "answer": text("사진에 정답이 있으면 그 값")],
                 required: ["problem"]),
            tool("get_records", "기록을 본다: 공부 통계(stats), 단어장 현황(words), 오답노트 현황(notes), 메모 목록(memos).",
                 ["kind": choice(["stats", "words", "notes", "memos"], "볼 기록"),
                  "days": number("통계 기간(일). 기본 7")],
                 required: ["kind"]),
            tool("memo", "메모장에 메모를 저장하거나 메모를 검색한다.",
                 ["action": choice(["add", "search"], "할 일"),
                  "text": text("저장할 내용 또는 검색어")],
                 required: ["action", "text"]),
            tool("set_goals", "D-Day, 하루 공부 목표 시간, 하루 외울 단어 수를 설정한다.",
                 ["d_day_title": text("D-Day 이름. 예: 기말고사"),
                  "d_day_date": text(dateHint),
                  "study_goal_minutes": number("하루 공부 목표(분)"),
                  "word_goal": number("하루 외울 단어 수")]),
            tool("open_screen", "앱의 다른 화면을 연다.",
                 ["screen": choice(["home", "planner", "study", "timer", "account"], "열 화면")],
                 required: ["screen"])
        ]
    }

    /// AI가 고른 도구를 실제로 실행하고, 결과를 짧은 문장으로 돌려줌
    static func run(name: String, input: [String: Any], image: UIImage?) -> String {
        let actions = DoitActions.shared
        func str(_ key: String) -> String? {
            let value = input[key] as? String
            return value?.isEmpty == true ? nil : value
        }
        func int(_ key: String) -> Int? {
            if let value = input[key] as? Int { return value }
            if let value = input[key] as? Double { return Int(value) }
            if let value = input[key] as? String { return Int(value) }
            return nil
        }
        switch name {
        case "get_day":
            return actions.overview(dateText: str("date"))
        case "add_plan":
            return actions.addPlan(title: str("title") ?? "", dateText: str("date"), timeText: str("time"),
                                   minutes: int("minutes"), isStudy: input["is_study"] as? Bool ?? false,
                                   allDay: false, repeatText: str("repeat"))
        case "update_plan":
            return actions.updatePlan(title: str("title") ?? "", dateText: str("date"), action: str("action") ?? "complete")
        case "study_timer":
            return actions.timer(action: str("action") ?? "start", title: str("title"), minutes: int("minutes"))
        case "add_words":
            let list = (input["words"] as? [[String: Any]]) ?? []
            let pairs = list.compactMap { item -> (String, String)? in
                guard let term = item["term"] as? String, let meaning = item["meaning"] as? String else { return nil }
                return (term, meaning)
            }
            return actions.addWords(pairs)
        case "save_wrong_note":
            return actions.addMathNote(title: str("title"), problem: str("problem") ?? "", answer: str("answer"), image: image)
        case "get_records":
            let kind = str("kind") ?? "stats"
            return kind == "stats" ? actions.stats(days: int("days") ?? 7) : actions.records(kind: kind)
        case "memo":
            return str("action") == "search" ? actions.searchMemos(str("text") ?? "") : actions.addMemo(str("text") ?? "")
        case "set_goals":
            return actions.settings(dDayTitle: str("d_day_title"), dDayDate: str("d_day_date"),
                                    studyGoalMinutes: int("study_goal_minutes"), wordGoal: int("word_goal"))
        case "open_screen":
            return actions.open(str("screen") ?? "home")
        default:
            return "알 수 없는 기능: \(name)"
        }
    }
}
