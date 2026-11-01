import UIKit

/// 두잇 AI 선생님: 직접 만든 수학·영어·과학·사회 엔진과 지식 사전으로 학습 자료를 만듦 (외부 AI 없음)
/// 인터넷은 쓰지 않아요 (영어 단어 사전만 예외)
enum DoitTutor {
    enum TutorError: LocalizedError {
        case cannotSolve(String)
        case notEnough(String)

        var errorDescription: String? {
            switch self {
            case .cannotSolve(let message), .notEnough(let message): return message
            }
        }
    }

    // MARK: - 1. 개념 정리

    static func concept(subject: String, unit: String, booster: Bool) async throws -> ConceptNote {
        // 수학은 직접 정리한 교과서 핵심 + 예제
        if isMath(subject: subject, unit: unit), DoitKnowledge.entries(inUnit: unit).count < 2, let math = DoitMathConcepts.note(for: unit) {
            var example = ""
            if let problem = MathProblems.make(unit: unit, hard: false) {
                example = "예제: \(problem.question)\n풀이: \(problem.steps.joined(separator: " → "))\n답: \(problem.finalAnswer)"
            }
            return ConceptNote(title: math.title, keyPoints: Array(math.points.prefix(booster ? 4 : 8)), example: example)
        }
        // 앱 안 지식(영어 문법, 과학·사회 개념)
        if let note = builtInNote(subject: subject, unit: unit, booster: booster) { return note }
        if let note = builtInNote(subject: subject, unit: unit, booster: booster, force: true) { return note }
        // 이름이 정확히 안 맞아도 지식 사전에서 비슷한 개념
        let related = knowledgeSet(subject: subject, unit: unit)
        guard let first = related.first else { throw notFound(unit) }
        var points = first.body.components(separatedBy: "\n").map { line -> String in
            var l = line.trimmingCharacters(in: .whitespaces)
            for bullet in ["• ", "- ", "· "] where l.hasPrefix(bullet) { l.removeFirst(bullet.count) }
            return l
        }.filter { !$0.isEmpty && !$0.hasPrefix("예") }
        // 함께 보면 좋은 개념의 첫 문장도 덧붙임
        for entry in related.dropFirst().prefix(booster ? 1 : 3) {
            if let line = entry.body.components(separatedBy: "\n").first { points.append("[\(entry.title)] " + line) }
        }
        let example = first.body.components(separatedBy: "\n").first(where: { $0.hasPrefix("예") }) ?? ""
        return ConceptNote(title: first.title, keyPoints: Array(points.prefix(booster ? 4 : 8)), example: example)
    }

    /// 단원 이름으로 지식 사전에서 찾은 관련 개념들 (가장 가까운 것부터)
    private static func knowledgeSet(subject: String, unit: String) -> [DoitKnowledge.Entry] {
        let subjectKey = ["수학", "과학", "사회", "영어"].first { subject.contains($0) } ?? (subject.contains("역사") || subject.contains("한국사") ? "사회" : nil)
        // 교육과정 단원 이름 그대로면 그 단원의 개념 전체
        let inUnit = DoitKnowledge.entries(inUnit: unit, subject: subjectKey)
        if inUnit.count >= 2 { return inUnit.shuffled() }
        var matches = DoitKnowledge.search(unit, limit: 10).filter { $0.score >= 0.3 }
        if let subjectKey {
            let same = matches.filter { $0.entry.subject == subjectKey }
            if !same.isEmpty { matches = same }
        }
        return inUnit + matches.map(\.entry).filter { m in !inUnit.contains { $0.title == m.title } }
    }

    /// 영어·과학·사회 엔진에 들어 있는 설명으로 개념 정리 만들기
    private static func builtInNote(subject: String, unit: String, booster: Bool, force: Bool = false) -> ConceptNote? {
        // 교과서 단원 이름이 여러 개념을 묶은 경우 (예: 시제와 태 → 시제 + 수동태)
        let combined: [String: [String]] = [
            "시제와 태": ["12시제", "현재완료", "수동태"], "분사와 분사구문": ["분사", "분사구문"],
            "관계사": ["관계대명사", "관계부사"], "가정법": ["가정법 과거", "가정법 과거완료"]
        ]
        let topics = combined[unit] ?? [unit]
        let useEnglish = subject.contains("영어") || force
        var title = ""
        var points: [String] = []
        var examples: [String] = []
        for topic in topics {
            let question = "\(topic) 설명해줘"
            guard let text = (useEnglish ? DoitEnglish.answer(question) : nil) ?? DoitScience.answer(question) ?? DoitSocial.answer(question) else { continue }
            var lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "**", with: "") }
                .filter { !$0.isEmpty }
            let heading = lines.first ?? topic
            if !lines.isEmpty { lines.removeFirst() }
            title = title.isEmpty ? heading : title
            // 예문(1) …, 예: …)은 예시로, 나머지는 핵심 정리로
            let isExample: (String) -> Bool = { line in
                line.hasPrefix("예:") || line.hasPrefix("예)") || line.range(of: #"^\d\)"#, options: .regularExpression) != nil
            }
            var part = lines.filter { !isExample($0) && $0 != "예문" && !$0.hasPrefix("※") }.map { line -> String in
                var l = line
                for bullet in ["• ", "- ", "· "] where l.hasPrefix(bullet) { l.removeFirst(bullet.count) }
                return l
            }
            // 한 문단짜리 설명은 문장으로 나눔
            if part.count < 2 {
                part = part.flatMap { $0.components(separatedBy: "요. ").map { $0.hasSuffix(".") || $0.hasSuffix("요") ? $0 : $0 + "요." } }
                    .filter { $0.count > 3 }
            }
            if topics.count > 1 { part = part.map { "[\(heading)] " + $0 } }
            points += part.prefix(topics.count > 1 ? 4 : 8)
            examples += lines.filter(isExample).prefix(topics.count > 1 ? 1 : 2)
        }
        guard !points.isEmpty else { return nil }
        if topics.count > 1 { title = unit }
        let limit = booster ? 4 : 8
        return ConceptNote(title: title, keyPoints: Array(points.prefix(limit)),
                           example: examples.isEmpty ? (points.count > limit ? points[limit] : "") : numbered(examples))
    }

    /// 예문 번호를 1), 2), 3) 순서로 다시 매김
    private static func numbered(_ lines: [String]) -> String {
        lines.enumerated().map { index, line in
            let body = line.replacingOccurrences(of: #"^\d\)\s*"#, with: "", options: .regularExpression)
            return body.hasPrefix("예") ? body : "\(index + 1)) \(body)"
        }.joined(separator: "\n")
    }

    // MARK: - 2. 빈칸 암기

    static func cloze(subject: String, unit: String, count: Int) async throws -> ClozeSet {
        let builtIn = builtInPoints(subject: subject, unit: unit)
        // 수학은 공식으로 직접 만든 빈칸이 충분하면 그것부터
        if isMath(subject: subject, unit: unit), let set = clozeFromPoints(builtIn, count: count), set.items.count >= min(3, count) { return set }
        // 관련 개념들의 설명에서 개념 이름을 가린 빈칸
        var items = termCloze(knowledgeSet(subject: subject, unit: unit), count: count)
        if items.count < count, let more = clozeFromPoints(builtIn, count: count - items.count) { items += more.items }
        guard items.count >= 2 else { throw notFound(unit) }
        return ClozeSet(items: Array(items.prefix(count)))
    }

    private static func termCloze(_ entries: [DoitKnowledge.Entry], count: Int) -> [ClozeItem] {
        var items: [ClozeItem] = []
        for entry in entries where items.count < count {
            guard var line = entry.body.components(separatedBy: "\n").first(where: { $0.count >= 12 }) else { continue }
            var hidden = false
            for name in entry.names.sorted(by: { $0.count > $1.count }) where name.count >= 2 && line.contains(name) {
                line = line.replacingOccurrences(of: name, with: "____")
                hidden = true
            }
            if hidden { items.append(ClozeItem(sentence: line, answer: entry.title)) }
            else { items.append(ClozeItem(sentence: "____: " + line, answer: entry.title)) }
        }
        return items
    }

    /// 핵심 정리 문장에서 빈칸 만들기 ("A = B" 의 B, "용어: 설명" 의 용어)
    private static func clozeFromPoints(_ points: [String], count: Int) -> ClozeSet? {
        var items: [ClozeItem] = []
        for point in points where items.count < count {
            let first = point.components(separatedBy: CharacterSet(charactersIn: ",;")).first ?? point
            if let range = first.range(of: " = ", options: .backwards) {
                let answer = String(first[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                guard (1...24).contains(answer.count) else { continue }
                items.append(ClozeItem(sentence: first.replacingCharacters(in: range.upperBound..<first.endIndex, with: "____"), answer: answer))
            } else if let colon = point.firstIndex(of: ":") {
                let term = String(point[..<colon]).trimmingCharacters(in: .whitespaces)
                guard (2...14).contains(term.count) else { continue }
                items.append(ClozeItem(sentence: "____:" + point[point.index(after: colon)...], answer: term))
            }
        }
        return items.count >= 2 ? ClozeSet(items: items) : nil
    }

    // MARK: - 3. O/X

    static func ox(subject: String, unit: String, count: Int) async throws -> OXSet {
        let builtIn = builtInPoints(subject: subject, unit: unit)
        if isMath(subject: subject, unit: unit), let set = oxFromPoints(builtIn, count: count), set.items.count >= min(3, count) { return set }
        // 관련 개념: 맞는 설명 / 다른 개념 이름으로 바꾼 틀린 설명
        let entries = knowledgeSet(subject: subject, unit: unit)
        var items: [OXItem] = []
        for (index, entry) in entries.enumerated() where items.count < count {
            guard let line = entry.body.components(separatedBy: "\n").first(where: { $0.count >= 12 }) else { continue }
            let statement = line.contains(entry.title) ? line : "\(entry.title): \(line)"
            if index % 2 == 1, let other = entries.first(where: { $0.title != entry.title && !line.contains($0.title) }) {
                let wrong = statement.replacingOccurrences(of: entry.title, with: other.title)
                items.append(OXItem(statement: wrong, isTrue: false, explanation: "틀린 문장이에요. '\(entry.title)'에 대한 설명이에요."))
            } else {
                items.append(OXItem(statement: statement, isTrue: true, explanation: "맞는 문장이에요."))
            }
        }
        if items.count < count, let more = oxFromPoints(builtIn, count: count - items.count) { items += more.items }
        guard items.count >= 2 else { throw notFound(unit) }
        return OXSet(items: Array(items.prefix(count)).shuffled())
    }

    private static func oxFromPoints(_ points: [String], count: Int) -> OXSet? {
        var items: [OXItem] = []
        for (index, point) in points.enumerated() where items.count < count {
            if index % 2 == 1, let falsified = falsify(point, terms: []) , falsified != point {
                items.append(OXItem(statement: falsified, isTrue: false, explanation: "틀린 문장이에요. 바른 문장: \(point)"))
            } else {
                items.append(OXItem(statement: point, isTrue: true, explanation: "맞는 문장이에요."))
            }
        }
        return items.count >= 2 ? OXSet(items: items.shuffled()) : nil
    }

    /// 맞는 문장을 그럴듯하게 틀리게 바꿈 (반대말, 숫자, 다른 용어)
    private static func falsify(_ sentence: String, terms: [String]) -> String? {
        let opposites: [(String, String)] = [
            ("증가", "감소"), ("크다", "작다"), ("많다", "적다"), ("높다", "낮다"), ("있다", "없다"), ("같다", "다르다"),
            ("양수", "음수"), ("최대", "최소"), ("최댓값", "최솟값"), ("위로", "아래로"), ("가능", "불가능"),
            ("포함", "제외"), ("이전", "이후"), ("내부", "외부"), ("직접", "간접"), ("유리수", "무리수"), ("실수", "허수")
        ]
        for (a, b) in opposites {
            if sentence.contains(a) { return sentence.replacingOccurrences(of: a, with: b) }
            if sentence.contains(b) { return sentence.replacingOccurrences(of: b, with: a) }
        }
        if let range = sentence.range(of: #"\d+"#, options: .regularExpression), let number = Int(sentence[range]) {
            let changed = number >= 10 ? number + (number / 10 + 1) * 3 : number + 2
            return sentence.replacingCharacters(in: range, with: String(changed))
        }
        if let term = terms.first(where: { sentence.contains($0) }),
           let other = terms.first(where: { $0 != term && !sentence.contains($0) }) {
            return sentence.replacingOccurrences(of: term, with: other)
        }
        return nil
    }

    // MARK: - 4. 객관식 문제

    static func problems(subject: String, unit: String, count: Int, hard: Bool) async throws -> ProblemSet {
        // 수학 계산 단원은 직접 만든 계산 문제 (정답이 항상 맞음). 문제 생성기가 없는 단원은 개념 문제로
        if isMath(subject: subject, unit: unit), MathProblems.topic(for: unit) != nil {
            let made = (0..<count).compactMap { _ in MathProblems.make(unit: unit, hard: hard) }
            if made.count >= max(1, count - 1) { return ProblemSet(items: made) }
        }
        // 관련 개념으로 "알맞은 용어 고르기" 문제
        let entries = knowledgeSet(subject: subject, unit: unit)
        var items: [Problem] = []
        for entry in entries where items.count < count {
            guard var line = entry.body.components(separatedBy: "\n").first(where: { $0.count >= 12 }) else { continue }
            for name in entry.names where name.count >= 2 { line = line.replacingOccurrences(of: name, with: "(   )") }
            var others = entries.map(\.title).filter { $0 != entry.title }
            others += DoitKnowledge.entries.filter { $0.subject == entry.subject && $0.title != entry.title }.shuffled().prefix(6).map(\.title)
            var seen = Set<String>()
            let distractors = others.filter { seen.insert($0).inserted }.prefix(4)
            guard distractors.count == 4 else { continue }
            let choices = (Array(distractors) + [entry.title]).shuffled()
            let number = (choices.firstIndex(of: entry.title) ?? 0) + 1
            items.append(Problem(question: "다음 설명에 알맞은 것은?\n\(line)", choices: choices, answerNumber: number,
                                 steps: ["설명의 핵심 단서를 찾아요", "알맞은 개념은 '\(entry.title)'이에요"], finalAnswer: "\(number)번 \(entry.title)"))
        }
        guard !items.isEmpty else { throw notFound(unit) }
        return ProblemSet(items: items)
    }

    // MARK: - 5. 오답노트 단계별 풀이

    static func solution(for problem: String) async throws -> WrittenSolution {
        if let solved = MathSolver.solve(problem) {
            return WrittenSolution(concept: solved.concept, steps: solved.steps, finalAnswer: solved.answer)
        }
        throw TutorError.cannotSolve(
            "이 문제는 두잇 AI가 직접 풀 수 없는 유형이에요. 문제 글자가 정확히 읽혔는지 '문제' 탭에서 확인해 보세요.\n두잇 AI가 푸는 유형: 방정식(일차·이차·고차·연립·절댓값), 부등식, 인수분해, 이차함수 최대·최소, 근과 계수, 나머지정리, 복소수, 경우의 수, 좌표·직선·원, 집합, 합성·역함수, 유리·무리함수, 산술·기하평균, 미분·적분, 수열, 통계, 도형 공식"
        )
    }

    // MARK: - 6. 비슷한 문제

    static func similar(to problem: String) async throws -> SimilarProblemSet {
        if let kind = MathSolver.kind(of: problem), MathProblems.topic(for: kind) != nil {
            let made = (0..<3).compactMap { level in MathProblems.similar(kind: kind, level: level) }
            if made.count == 3 { return SimilarProblemSet(problems: made) }
        }
        throw TutorError.cannotSolve("이 문제의 유형을 알아보지 못했어요. 문제 글자를 확인해 주세요. (방정식·부등식·인수분해·이차함수·경우의 수·좌표·함수·미적분·수열 등에서 비슷한 문제를 만들 수 있어요)")
    }

    // MARK: - 7. 질문에 답하기 (AI에게 질문하기, 두잇 AI 대화)

    static func answer(_ question: String, subject: String? = nil, image: UIImage? = nil) async throws -> String {
        var text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if let image {
            let photoText = await OCRService.readMathProblem(image).text
            if !photoText.isEmpty { text += (text.isEmpty ? "" : "\n") + photoText }
        }
        guard !text.isEmpty else { throw TutorError.notEnough("사진에서 글자를 찾지 못했어요. 글자가 잘 보이게 다시 찍어주세요.") }
        // 수학이면 두잇 AI가 직접 풀이
        if let solved = MathSolver.solve(text) {
            var lines = ["**\(solved.topic)**", "💡 " + solved.concept]
            lines += solved.steps.enumerated().map { "\($0.offset + 1). \($0.element.hint)" + ($0.element.work.isEmpty ? "" : " → \($0.element.work)") }
            lines.append("**답: \(solved.answer)**")
            return lines.joined(separator: "\n")
        }
        // 앱 안 지식: 영어 → 과학 → 사회
        if let known = DoitEnglish.answer(text) ?? DoitScience.answer(text) ?? DoitSocial.answer(text) { return known }
        if text.contains("뜻"), let word = DoitEnglish.lookupWord(in: text), let entry = await DoitEnglish.define(word) {
            return (DoitEnglish.koreanMeaning(of: word).map { "**\(word)**: \($0)\n\n" } ?? "") + entry
        }
        // 지식 사전에서 비슷한 개념 → 그래도 없으면 대화 엔진
        if let known = DoitKnowledge.answer(text) { return known }
        return DoitConversation.reply(text).text
    }

    /// 같은 주제를 더 자세히: 지식 사전의 전체 설명 + 함께 보면 좋은 개념
    static func more(about topic: String, previous: String) -> String {
        let key = topic.lowercased().filter { !$0.isWhitespace }
        let exact = DoitKnowledge.entries.first { entry in entry.names.contains { $0.lowercased().filter { !$0.isWhitespace } == key } }
        let entry = exact ?? DoitKnowledge.search(topic, limit: 1).first.flatMap { $0.score >= 0.4 ? $0.entry : nil }
        var lines: [String] = []
        if let entry, !previous.contains(entry.body.prefix(30)) {
            lines.append("**\(entry.title)** 자세히")
            lines.append(entry.body)
        } else {
            lines.append("**\(topic)** 더 알아보기")
        }
        let related = DoitKnowledge.related(to: entry?.title ?? topic, limit: 3)
        if !related.isEmpty {
            lines.append("\n함께 알아두면 좋은 개념")
            for item in related {
                let first = item.body.components(separatedBy: "\n").first ?? ""
                lines.append("• **\(item.title)**: \(first)")
            }
        }
        if lines.count == 1 {
            lines.append("이 주제는 제가 아는 내용을 이미 다 알려드렸어요. 퀴즈로 확인해 볼까요?")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - 공통

    private static func isMath(subject: String, unit: String) -> Bool {
        subject.contains("수학") || MathProblems.topic(for: unit) != nil
    }

    /// 앱 안에 정리된 핵심 문장 (수학 개념 정리 또는 영어·과학·사회 노트)
    private static func builtInPoints(subject: String, unit: String) -> [String] {
        if isMath(subject: subject, unit: unit), DoitKnowledge.entries(inUnit: unit).count < 2, let math = DoitMathConcepts.note(for: unit) { return math.points }
        return builtInNote(subject: subject, unit: unit, booster: false, force: true)?.keyPoints
            .map { $0.replacingOccurrences(of: #"^\[[^\]]*\]\s*"#, with: "", options: .regularExpression) } ?? []
    }

    private static func notFound(_ unit: String) -> TutorError {
        .notEnough("'\(unit)'에 대한 자료가 두잇 AI에 아직 없어요. 단원 이름을 조금 다르게 써보세요.\n예: 이차방정식, 인수분해, 광합성, 뉴턴 운동 법칙, 임진왜란, 수요와 공급, 현재완료, 관계대명사")
    }
}
