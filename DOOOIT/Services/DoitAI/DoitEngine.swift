import UIKit

/// 두잇 AI 엔진 (외부 AI·API 없이 직접 만든 규칙형)
/// 문장을 분석해서 무엇을 원하는지(의도) 고르고, 날짜·시간·이름 같은 값을 뽑아 앱 기능을 실행함
@MainActor
enum DoitEngine {
    struct Reply {
        var text: String
        var suggestions: [String] = []
    }

    /// 사진에서 읽어 둔 내용 (다음 말에서도 쓸 수 있게 기억)
    struct PhotoContext {
        var image: UIImage
        var text: String
        var words: [ParsedWord]
    }

    static let examples = [
        "오늘 할 일 알려줘",
        "내일 오후 4시에 수학 공부 2시간 추가해줘",
        "영어 단어 25분 타이머 시작해줘",
        "단어 추가: abundant 풍부한, resilient 회복력 있는",
        "이번 주 공부 통계",
        "x²-5x+6=0 풀어줘"
    ]

    // MARK: 진입점

    static func respond(to raw: String, photo: PhotoContext?) -> Reply {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = text.lowercased()

        // 사진이 있을 때
        if let photo {
            if let reply = handlePhoto(t, photo: photo) { return reply }
        }
        if text.isEmpty { return help() }

        if has(t, ["안녕", "하이", "hello", "hi "]) && t.count < 12 {
            return Reply(text: "안녕하세요! 두잇 AI예요. 일정, 타이머, 단어, 메모, 목표, 수학 계산을 도와드릴게요.", suggestions: Array(examples.prefix(4)))
        }
        if has(t, ["뭐 할 수", "뭘 할 수", "할 수 있는", "도움말", "사용법", "기능 알려", "뭐해줄", "뭐 해줄"]) {
            return help()
        }

        // 여러 부탁을 한 번에: "A 하고 B 해줘" / "A 그리고 B"
        let parts = splitRequests(text)
        if parts.count > 1 {
            let replies = parts.map { handle($0) }
            return Reply(text: replies.map(\.text).joined(separator: "\n\n"),
                         suggestions: replies.last?.suggestions ?? [])
        }
        return handle(text)
    }

    private static func handle(_ text: String) -> Reply {
        let t = text.lowercased()

        if has(t, ["메모"]) { return memo(text) }
        if has(t, ["d-day", "디데이", "dday", "d day"]) { return dDay(text) }
        if has(t, ["목표"]) && has(t, ["시간", "분", "개", "단어"]) && !has(t, ["추가해", "일정"]) { return goals(text) }
        if has(t, ["타이머", "스톱워치"]) || (has(t, ["공부"]) && has(t, ["시작할게", "시작해줘", "그만할게", "끝낼게", "종료해"])) {
            return timer(text)
        }
        if has(t, ["단어"]) && has(t, ["추가", "넣어", "저장", "등록"]) { return addWords(text) }
        if let lookup = wordLookup(text) { return lookup }
        if has(t, ["통계", "얼마나 공부", "공부 시간", "공부시간", "공부한 시간", "기록 보여"]) { return stats(text) }
        if has(t, ["틀린 단어", "단어 현황", "단어장 현황", "외운 단어", "단어 몇"]) {
            return Reply(text: DoitActions.shared.records(kind: "words"), suggestions: ["단어 화면 열어줘"])
        }
        if has(t, ["오답노트", "오답 노트", "오답 몇"]) && !has(t, ["저장", "넣어", "추가"]) {
            return Reply(text: DoitActions.shared.records(kind: "notes"))
        }
        if let navigation = navigate(t) { return navigation }
        if has(t, ["삭제", "지워", "빼줘", "없애"]) && !has(t, ["추가"]) { return updatePlan(text, action: "delete") }
        if has(t, ["완료 취소", "안 했", "체크 해제", "체크 풀"]) { return updatePlan(text, action: "uncomplete") }
        if has(t, ["완료", "끝냈", "다 했", "했어", "끝났", "체크해"]) && !has(t, ["추가", "타이머"]) {
            return updatePlan(text, action: "complete")
        }
        if has(t, ["추가", "넣어", "잡아", "등록", "만들어", "예약", "계획 세워", "일정 잡"]) { return addPlan(text) }
        if has(t, ["할 일", "할일", "일정", "플랜", "스케줄", "계획", "뭐 있"]) { return overview(text) }
        if DoitMath.looksLikeMath(text), let result = DoitMath.solve(text) { return mathReply(result) }
        if findDate(in: text) != nil && findTime(in: text) != nil { return addPlan(text) }

        return Reply(
            text: "아직 그 말은 이해하지 못했어요. 저는 일정·타이머·단어·메모·목표·기록 같은 앱 기능과 수학 계산을 도와드릴 수 있어요. 이렇게 말해보세요.",
            suggestions: examples
        )
    }

    // MARK: 사진

    private static func handlePhoto(_ t: String, photo: PhotoContext) -> Reply? {
        if has(t, ["오답", "노트", "문제 저장", "저장해"]) && !has(t, ["단어", "메모"]) {
            let problem = photo.text
            let answer = MathGrader.extractAnswer(from: problem)
            let result = DoitActions.shared.addMathNote(title: nil, problem: problem, answer: answer, image: photo.image)
            return Reply(text: result + (problem.isEmpty ? "\n글자는 읽지 못해서 사진만 저장했어요." : ""),
                         suggestions: ["오답노트 현황 알려줘"])
        }
        if has(t, ["단어"]) && !t.contains(":") {
            guard !photo.words.isEmpty else {
                return Reply(text: "사진에서 '영어 단어 - 뜻' 짝을 찾지 못했어요. 단어장이 잘 보이게 다시 찍어주세요.")
            }
            return Reply(text: DoitActions.shared.addWords(photo.words.map { ($0.term, $0.meaning) }), suggestions: ["단어 현황 알려줘"])
        }
        if has(t, ["메모"]) {
            return Reply(text: DoitActions.shared.addMemo(photo.text.isEmpty ? "(사진)" : photo.text))
        }
        if has(t, ["풀어", "계산", "답"]) || DoitMath.looksLikeMath(photo.text) && t.isEmpty {
            if let result = DoitMath.solve(photo.text) { return mathReply(result) }
        }
        guard t.isEmpty || has(t, ["읽어", "분석", "뭐야", "뭐라고", "보여"]) else { return nil }

        // 사진만 보냈을 때: 읽은 내용과 할 수 있는 일을 알려줌
        if photo.words.count >= 3 {
            let preview = photo.words.prefix(5).map { "\($0.term) – \($0.meaning)" }.joined(separator: "\n")
            return Reply(text: "단어장 사진 같아요. 단어 \(photo.words.count)개를 찾았어요.\n\(preview)\(photo.words.count > 5 ? "\n…" : "")",
                         suggestions: ["단어 추가해줘", "메모로 저장해줘"])
        }
        if photo.text.isEmpty {
            return Reply(text: "사진에서 글자를 찾지 못했어요. 글자가 잘 보이게 다시 찍어주세요.")
        }
        var suggestions = ["오답노트에 저장해줘", "메모로 저장해줘"]
        if DoitMath.looksLikeMath(photo.text) { suggestions.insert("이 식 풀어줘", at: 0) }
        return Reply(text: "사진에서 읽은 글자예요.\n\n\(MathSymbolBar.pretty(String(photo.text.prefix(600))))", suggestions: suggestions)
    }

    // MARK: 일정

    private static func overview(_ text: String) -> Reply {
        let date = findDate(in: text)
        let isToday = date == nil || date == "오늘"
        return Reply(text: DoitActions.shared.overview(dateText: date),
                     suggestions: isToday ? ["내일 일정 알려줘", "오늘 공부 통계"] : ["오늘 할 일 알려줘"])
    }

    private static func addPlan(_ text: String) -> Reply {
        var rest = text
        let date = findDate(in: rest)
        if let date { rest = rest.replacingOccurrences(of: date, with: " ") }
        let time = findTime(in: rest)
        if let time { rest = rest.replacingOccurrences(of: time, with: " ") }
        let duration = findDuration(in: rest)
        if let duration { rest = rest.replacingOccurrences(of: duration.text, with: " ") }

        let lower = text.lowercased()
        var repeatRule: String?
        for (word, rule) in [("매일", "daily"), ("매주", "weekly"), ("매달", "monthly"), ("매월", "monthly")] where lower.contains(word) {
            repeatRule = rule
            rest = rest.replacingOccurrences(of: word, with: " ")
        }

        let title = cleanTitle(rest)
        let isStudy = looksLikeStudy(text)
        let finalTitle = title.isEmpty ? (isStudy ? "공부" : "새 일정") : title
        let result = DoitActions.shared.addPlan(title: finalTitle, dateText: date, timeText: time,
                                                minutes: duration?.minutes, isStudy: isStudy, allDay: false,
                                                repeatText: repeatRule)
        var note = ""
        if time == nil { note = "\n시간을 말하지 않아서 하루 종일 일정으로 넣었어요." }
        if isStudy { note += "\n공부 플랜이라 시작 시간이 되면 타이머가 자동으로 켜져요." }
        return Reply(text: result + note, suggestions: ["\(date ?? "오늘") 일정 알려줘"])
    }

    private static func updatePlan(_ text: String, action: String) -> Reply {
        let date = findDate(in: text)
        let day = DoitDateParser.date(date) ?? Date()
        let plans = DoitActions.shared.plans(on: day)
        guard !plans.isEmpty else {
            return Reply(text: "\(day.kr("M월 d일"))에는 플랜이 없어요.", suggestions: ["오늘 할 일 알려줘"])
        }
        guard let title = bestMatch(text, among: plans) else {
            let verb = action == "delete" ? "지울" : "체크할"
            return Reply(text: "어떤 플랜을 \(verb)지 모르겠어요. 플랜 이름을 같이 말해주세요.",
                         suggestions: plans.prefix(3).map { "\($0) \(action == "delete" ? "삭제해줘" : "완료했어")" })
        }
        return Reply(text: DoitActions.shared.updatePlan(title: title, dateText: date, action: action))
    }

    /// 말 속에서 가장 잘 맞는 플랜 이름 (이름이 그대로 들어있거나, 겹치는 단어가 가장 많은 것)
    private static func bestMatch(_ text: String, among titles: [String]) -> String? {
        let compact = text.replacingOccurrences(of: " ", with: "")
        if let exact = titles.first(where: { compact.contains($0.replacingOccurrences(of: " ", with: "")) }) { return exact }
        let words = Set(text.split(whereSeparator: { $0 == " " || $0 == "," }).map { strip(String($0)) }.filter { $0.count >= 2 })
        var best: (String, Int)?
        for title in titles {
            let titleWords = title.split(separator: " ").map(String.init)
            let score = titleWords.filter { word in words.contains { $0.contains(word) || word.contains($0) } }.count
            if score > 0, score > (best?.1 ?? 0) { best = (title, score) }
        }
        return best?.0
    }

    // MARK: 타이머

    private static func timer(_ text: String) -> Reply {
        let t = text.lowercased()
        if has(t, ["끝", "종료", "그만", "멈춰", "꺼", "stop", "스톱"]) && !has(t, ["일시"]) {
            return Reply(text: DoitActions.shared.timer(action: "stop", title: nil, minutes: nil), suggestions: ["오늘 공부 통계"])
        }
        if has(t, ["일시정지", "일시 정지", "잠깐", "쉬", "다시 시작", "재개"]) {
            return Reply(text: DoitActions.shared.timer(action: "pause", title: nil, minutes: nil))
        }
        let duration = findDuration(in: text)
        var rest = text
        if let duration { rest = rest.replacingOccurrences(of: duration.text, with: " ") }
        for word in ["타이머", "스톱워치", "시작해줘", "시작해", "시작할게", "시작", "켜줘", "켜", "돌려줘", "공부할게"] {
            rest = rest.replacingOccurrences(of: word, with: " ")
        }
        let title = cleanTitle(rest)
        return Reply(text: DoitActions.shared.timer(action: "start", title: title.isEmpty ? nil : title, minutes: duration?.minutes),
                     suggestions: ["타이머 일시정지", "타이머 종료해줘", "타이머 화면 열어줘"])
    }

    // MARK: 단어

    private static func addWords(_ text: String) -> Reply {
        var body = text
        if let colon = body.firstIndex(where: { $0 == ":" || $0 == "：" }) {
            body = String(body[body.index(after: colon)...])
        } else {
            for word in ["단어장에", "단어를", "단어", "추가해줘", "추가해", "추가", "넣어줘", "넣어", "저장해줘", "저장", "등록해줘", "등록"] {
                body = body.replacingOccurrences(of: word, with: " ")
            }
        }
        let chunks = body.split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == ";" || $0 == "/" })
        var pairs: [(String, String)] = []
        for chunk in chunks {
            let split = WordParser.split(String(chunk).trimmingCharacters(in: .whitespaces))
            if !split.term.isEmpty && !split.meaning.isEmpty { pairs.append((split.term, split.meaning)) }
        }
        guard !pairs.isEmpty else {
            return Reply(text: "단어와 뜻을 이렇게 알려주세요.\n예: 단어 추가: apple 사과, run 달리다\n단어장 사진을 보내도 돼요.",
                         suggestions: ["단어 추가: apple 사과, run 달리다"])
        }
        return Reply(text: DoitActions.shared.addWords(pairs), suggestions: ["단어 현황 알려줘"])
    }

    /// "abundant 뜻", "resilient 뜻이 뭐야" → 내 단어장에서 찾기
    private static func wordLookup(_ text: String) -> Reply? {
        guard text.contains("뜻") else { return nil }
        let english = text.split(separator: " ").map(String.init).first { word in
            let letters = word.filter(\.isLetter)
            return !letters.isEmpty && letters.allSatisfy { $0.isASCII }
        }?.filter { $0.isLetter || $0 == "-" }
        guard let english, !english.isEmpty else { return nil }
        return Reply(text: DoitActions.shared.lookupWord(english))
    }

    // MARK: 메모 · 목표 · 기록

    private static func memo(_ text: String) -> Reply {
        let t = text.lowercased()
        if has(t, ["찾아", "검색", "어디"]) {
            var query = text
            for word in ["메모에서", "메모", "찾아줘", "찾아", "검색해줘", "검색", "어디 있어", "있어?"] { query = query.replacingOccurrences(of: word, with: " ") }
            let q = cleanTitle(query)
            guard !q.isEmpty else { return Reply(text: "무엇을 찾을까요? 예: '준비물 메모 찾아줘'") }
            return Reply(text: DoitActions.shared.searchMemos(q))
        }
        if has(t, ["보여", "목록", "뭐 있", "알려"]) && !t.contains(":") {
            return Reply(text: DoitActions.shared.records(kind: "memos"))
        }
        var content = text
        if let colon = content.firstIndex(where: { $0 == ":" || $0 == "：" }) {
            content = String(content[content.index(after: colon)...])
        } else {
            for word in ["메모해줘", "메모해", "메모 저장해줘", "메모로 저장해줘", "메모로 남겨줘", "메모 남겨줘", "메모"] {
                content = content.replacingOccurrences(of: word, with: " ")
            }
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Reply(text: "메모할 내용을 알려주세요. 예: 메모해줘: 수행평가 준비물 챙기기") }
        return Reply(text: DoitActions.shared.addMemo(trimmed), suggestions: ["메모 목록 보여줘"])
    }

    private static func dDay(_ text: String) -> Reply {
        guard let date = findDate(in: text) else {
            return Reply(text: "D-Day 날짜를 알려주세요. 예: 기말고사 D-Day 12월 10일로 설정해줘")
        }
        var rest = text.replacingOccurrences(of: date, with: " ")
        for word in ["D-Day", "d-day", "D-DAY", "디데이", "DDay", "dday", "설정해줘", "설정", "으로", "로", "바꿔줘", "만들어줘"] {
            rest = rest.replacingOccurrences(of: word, with: " ")
        }
        let title = cleanTitle(rest)
        return Reply(text: DoitActions.shared.settings(dDayTitle: title.isEmpty ? "시험" : title, dDayDate: date,
                                                       studyGoalMinutes: nil, wordGoal: nil))
    }

    private static func goals(_ text: String) -> Reply {
        let t = text.lowercased()
        if has(t, ["단어"]), let match = text.firstMatch(of: #/(\d+)\s*개/#), let count = Int(match.1) {
            return Reply(text: DoitActions.shared.settings(dDayTitle: nil, dDayDate: nil, studyGoalMinutes: nil, wordGoal: count))
        }
        if let duration = findDuration(in: text) {
            return Reply(text: DoitActions.shared.settings(dDayTitle: nil, dDayDate: nil, studyGoalMinutes: duration.minutes, wordGoal: nil))
        }
        return Reply(text: "목표를 숫자로 알려주세요. 예: 하루 공부 목표 4시간, 단어 목표 30개")
    }

    private static func stats(_ text: String) -> Reply {
        let t = text.lowercased()
        let days: Int
        if has(t, ["오늘"]) { days = 1 }
        else if has(t, ["한 달", "한달", "이번 달", "이번달", "30일"]) { days = 30 }
        else if let match = text.firstMatch(of: #/(\d+)\s*일/#), let n = Int(match.1) { days = n }
        else { days = 7 }
        return Reply(text: DoitActions.shared.stats(days: days), suggestions: ["틀린 단어 알려줘", "오답노트 현황"])
    }

    private static func navigate(_ t: String) -> Reply? {
        guard has(t, ["열어", "보여줘", "가줘", "이동", "켜줘", "들어가"]) else { return nil }
        let targets: [(String, [String])] = [
            ("timer", ["타이머"]), ("planner", ["플래너", "달력", "캘린더"]),
            ("study", ["단어 화면", "단어장 열", "공부 화면", "공부 탭", "오답노트 열", "메모장"]),
            ("account", ["계정", "설정", "크레딧"]), ("home", ["홈"])
        ]
        for (screen, words) in targets where has(t, words) {
            return Reply(text: DoitActions.shared.open(screen))
        }
        return nil
    }

    private static func mathReply(_ result: DoitMath.Result) -> Reply {
        let steps = result.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        return Reply(text: "**\(result.title)**\n\(steps)\n\n**답: \(result.answer)**")
    }

    private static func help() -> Reply {
        Reply(text: """
        두잇 AI가 할 수 있는 일이에요.
        • 일정: "오늘 할 일 알려줘", "금요일 오후 7시 영어 학원 추가", "수학 완료했어", "영어 일정 삭제해줘"
        • 타이머: "수학 50분 타이머 시작", "타이머 종료"
        • 단어: "단어 추가: apple 사과", 단어장 사진 + "단어 추가해줘", "abundant 뜻"
        • 오답노트: 문제 사진 + "오답노트에 저장해줘"
        • 메모: "메모해줘: 준비물", "준비물 메모 찾아줘"
        • 목표: "기말고사 D-Day 12월 10일", "하루 공부 목표 4시간"
        • 기록: "이번 주 공부 통계", "틀린 단어 알려줘"
        • 수학: "2x+3=11 풀어줘", "x²-5x+6=0", "(x+1)² 전개"
        """, suggestions: Array(examples.prefix(4)))
    }

    // MARK: 문장 분석 도구

    private static func has(_ text: String, _ words: [String]) -> Bool {
        words.contains { text.contains($0) }
    }

    /// "A 하고 B 해줘", "A 그리고 B" → 부탁 여러 개
    private static func splitRequests(_ text: String) -> [String] {
        let separators = ["그리고 ", " 그리고", "하고 나서 ", "\n"]
        var parts = [text]
        for separator in separators {
            parts = parts.flatMap { $0.components(separatedBy: separator) }
        }
        // "추가하고 타이머" 처럼 동사+고 로 이어진 경우
        parts = parts.flatMap { part -> [String] in
            let joints = ["추가하고 ": "추가해줘", "넣고 ": "넣어줘", "저장하고 ": "저장해줘", "시작하고 ": "시작해줘",
                          "알려주고 ": "알려줘", "삭제하고 ": "삭제해줘", "완료하고 ": "완료했어"]
            for (joint, verb) in joints where part.contains(joint) {
                let pieces = part.components(separatedBy: joint)
                guard pieces.count == 2 else { continue }
                return [pieces[0] + verb, pieces[1]]
            }
            return [part]
        }
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.count >= 2 }
    }

    /// 날짜 표현 찾기 → DoitDateParser가 이해하는 그대로 돌려줌
    static func findDate(in text: String) -> String? {
        let patterns = [
            #"\d{4}[-./]\d{1,2}[-./]\d{1,2}"#,
            #"\d{1,2}\s*월\s*\d{1,2}\s*일"#,
            #"(다다음\s?주|다음\s?주|이번\s?주)\s*[월화수목금토일]요일"#,
            #"\d+\s*(일|주)\s*(후|뒤)"#,
            #"[월화수목금토일]요일"#,
            #"내일\s?모레|오늘|내일|모레|글피"#
        ]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range])
            }
        }
        return nil
    }

    /// 시작 시간 표현 찾기
    static func findTime(in text: String) -> String? {
        let patterns = [
            #"(오전|오후|아침|저녁|밤|새벽)?\s*\d{1,2}\s*:\s*\d{2}"#,
            #"(오전|오후|아침|저녁|밤|새벽)?\s*\d{1,2}\s*시\s*(\d{1,2}\s*분|반)?(?!간)"#
        ]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// 걸리는 시간 ("2시간", "1시간 30분", "50분", "90분 동안")
    static func findDuration(in text: String) -> (text: String, minutes: Int)? {
        if let range = text.range(of: #"\d+\s*시간\s*(\d+\s*분)?(\s*(동안|정도|간))?"#, options: .regularExpression) {
            let part = String(text[range])
            let numbers = part.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            let minutes = (numbers.first ?? 0) * 60 + (numbers.count > 1 ? numbers[1] : 0)
            return (part, minutes)
        }
        if let range = text.range(of: #"\d+\s*분\s*(동안|정도|간)?"#, options: .regularExpression) {
            let part = String(text[range])
            let minutes = part.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.first ?? 0
            return (part, minutes)
        }
        return nil
    }

    private static let subjects = ["국어", "영어", "수학", "과학", "사회", "한국사", "역사", "물리", "화학", "생명", "생물", "지구과학",
                                   "통합과학", "통합사회", "문학", "독서", "화법", "작문", "언어", "미적분", "확통", "기하", "제2외국어", "한문"]

    private static func looksLikeStudy(_ text: String) -> Bool {
        let studyWords = ["공부", "복습", "예습", "문제집", "단원", "숙제", "과제", "시험", "모의고사", "인강", "강의", "단어", "문제 풀",
                          "자습", "독서실", "스터디", "기출"]
        let categories = DoitActions.shared.studyCategoryNames()
        return has(text, studyWords) || has(text, subjects) || has(text, categories)
    }

    /// 플랜 이름만 남기기: 명령어·조사 제거
    private static func cleanTitle(_ raw: String) -> String {
        var text = raw
        let commands = ["추가해줘", "추가해 줘", "추가해", "추가", "넣어줘", "넣어", "잡아줘", "잡아", "등록해줘", "등록", "만들어줘",
                        "예약해줘", "일정으로", "일정에", "일정", "플랜으로", "플랜에", "플랜", "해줘", "해 줘", "할게", "하기",
                        "좀", "부탁해", "부터", "까지", "동안", "에서", "정도", "제발", "요"]
        for command in commands { text = text.replacingOccurrences(of: command, with: " ") }
        let particles: Set<String> = ["에", "에서", "을", "를", "로", "으로", "은", "는", "이", "가", "랑", "과", "와", "의", "에는"]
        let words = text.split(whereSeparator: { $0 == " " || $0 == "," }).map { strip(String($0)) }
            .filter { !$0.isEmpty && !particles.contains($0) }
        return words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    /// 단어 끝의 조사 떼기 ("수학을" → "수학", "학원에" → "학원")
    private static func strip(_ word: String) -> String {
        var w = word.trimmingCharacters(in: CharacterSet(charactersIn: ".?!~\"'"))
        for suffix in ["으로", "에서", "에게", "을", "를", "에", "로", "은", "는", "이", "가"] where w.count > suffix.count + 1 && w.hasSuffix(suffix) {
            w.removeLast(suffix.count)
            break
        }
        return w
    }
}
