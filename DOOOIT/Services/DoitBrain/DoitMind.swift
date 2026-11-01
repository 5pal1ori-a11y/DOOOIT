import Foundation

/// 두잇 AI 생각 정리: 근거(앱 지식 · 내 기억 · 인터넷 자료)를 모아 두뇌(언어 모델)에게 주고,
/// 그대로 베끼지 않고 자기 말로 설명하게 함. 만든 답은 검사해서 이상하면 버리고 규칙형 엔진 답을 씀.
/// AI 학습(개념 정리·빈칸·O/X·객관식)도 같은 방식으로 새로 만들어요.
enum DoitMind {
    // MARK: - 근거

    struct Context {
        var knowledge: [DoitKnowledge.Entry] = []
        var memories: [DoitMemory.Note] = []
        var web: [DoitWeb.Source] = []
        /// 규칙형 엔진이 먼저 만든 답 (있으면 참고)
        var draft: String?
        /// 앱 상황 (오늘 공부 시간, 남은 일정 등)
        var app: String?

        var isEmpty: Bool { knowledge.isEmpty && memories.isEmpty && web.isEmpty && (draft ?? "").isEmpty }
        var sourceLabels: [String] {
            var labels: [String] = []
            for entry in knowledge { labels.append("두잇 지식 「\(entry.title)」") }
            if !memories.isEmpty { labels.append("두잇 AI가 배운 내용") }
            labels += web.map(\.label)
            return labels
        }
    }

    struct Turn {
        let fromUser: Bool
        let text: String
    }

    static let persona = """
    너는 '두잇 AI'야. 학생의 공부와 생활을 돕는 다정하고 똑똑한 AI 선생님이야.
    지켜야 할 것:
    - 항상 한국어 해요체로 답해요. 학생이 영어로 물으면 영어로 답해요.
    - [참고 자료]가 있으면 먼저 읽고 이해한 다음, 문장을 그대로 옮기지 말고 학생 눈높이에 맞게 자기 말로 풀어서 설명해요.
    - 참고 자료와 확실히 아는 것만 말해요. 모르는 것은 지어내지 말고 "확실하지 않아요"라고 솔직하게 말해요.
    - 핵심부터 짧고 분명하게: 핵심 한두 문장 → 쉬운 예시나 비유 → 한 줄 정리. 보통 3~8문장.
    - 중요한 용어는 **굵게** 써요. 목록이 필요하면 • 로 시작해요.
    - 일상 대화는 친구처럼 자연스럽고 따뜻하게, 짧게 답해요.
    - 위험하거나 해로운 부탁은 정중하게 거절해요.
    - 중국어나 한자로 답하지 않아요.
    """

    /// 인터넷에서 더 찾아봐야 하는지
    static func shouldSearchWeb(question: String, bestKnowledgeScore: Double, hasMemory: Bool, disliked: Bool) -> Bool {
        let t = question.lowercased().replacingOccurrences(of: " ", with: "")
        let explicit = ["검색", "찾아줘", "찾아봐", "인터넷", "최신", "요즘", "최근", "뉴스", "위키"].contains { t.contains($0) }
        if explicit || disliked { return true }
        if hasMemory || bestKnowledgeScore >= 0.5 { return false }
        let asking = ["뭐야", "뭔가요", "무엇", "누구", "언제", "어디", "왜", "어떻게", "설명", "알려", "이란", "란?", "뜻", "의미", "원리", "차이", "?", "what", "who", "why", "how"]
        let small = ["안녕", "심심", "고마워", "ㅋㅋ", "ㅎㅎ", "배고", "졸려", "힘들", "피곤", "사랑", "좋아해", "잘자", "굿모닝", "반가"]
        return asking.contains { t.contains($0) } && !small.contains { t.contains($0) } && t.count >= 3
    }

    // MARK: - 대화 답

    /// 두뇌에게 줄 글 (질문 + 근거 + 이전 대화)
    static func answerPrompt(question: String, context: Context, history: [Turn]) -> String {
        var parts: [String] = []
        let references = referenceText(context)
        if !references.isEmpty {
            parts.append("[참고 자료]\n" + references)
        }
        if let app = context.app, !app.isEmpty { parts.append("[학생의 오늘 상황]\n" + app) }
        let recent = history.suffix(6).map { ($0.fromUser ? "학생: " : "두잇: ") + DoitMemory.trimmed($0.text, max: 260) }
        if !recent.isEmpty { parts.append("[이전 대화]\n" + recent.joined(separator: "\n")) }
        parts.append("[질문]\n" + question)
        if !references.isEmpty {
            parts.append("참고 자료를 바탕으로, 그대로 베끼지 말고 이해한 내용을 자기 말로 쉽게 설명해 주세요.")
        }
        return parts.joined(separator: "\n\n")
    }

    static func referenceText(_ context: Context, maxEach: Int = 600) -> String {
        var lines: [String] = []
        for entry in context.knowledge.prefix(3) {
            lines.append("(두잇 지식 · \(entry.label)) \(entry.title): " + DoitMemory.trimmed(entry.body, max: maxEach))
        }
        for note in context.memories.prefix(3) {
            let who = note.kind == .learned ? "두잇이 전에 배운 내용" : "학생이 알려준 내용"
            lines.append("(\(who)) \(note.topic): " + DoitMemory.trimmed(note.summary, max: maxEach))
        }
        for source in context.web.prefix(2) {
            lines.append("(인터넷 · \(source.label)) " + DoitMemory.trimmed(source.text, max: maxEach + 200))
        }
        if let draft = context.draft?.trimmingCharacters(in: .whitespacesAndNewlines), !draft.isEmpty {
            lines.append("(두잇 기본 답) " + DoitMemory.trimmed(draft.replacingOccurrences(of: "**", with: ""), max: maxEach))
        }
        return lines.joined(separator: "\n")
    }

    /// 두뇌가 만든 글 다듬기
    static func clean(_ raw: String) -> String {
        var t = raw
        t = t.replacingOccurrences(of: #"(?s)<think>.*?</think>"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "<think>", with: "").replacingOccurrences(of: "</think>", with: "")
        t = t.replacingOccurrences(of: "<|im_end|>", with: "")
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["두잇:", "두잇 AI:", "답변:", "답:", "Answer:"] where t.hasPrefix(prefix) {
            t = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        t = t.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        // "### 제목" → "**제목**"
        t = t.replacingOccurrences(of: #"(?m)^#{1,4}\s*(.+)$"#, with: "**$1**", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?m)^\s*[-*]\s+"#, with: "• ", options: .regularExpression)
        return t
    }

    /// 쓸 만한 답인지 (비었거나, 한자·중국어로 새거나, 같은 말을 되풀이하면 버림)
    static func isUsable(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 4 else { return false }
        let han = t.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        if Double(han) / Double(max(1, t.count)) > 0.04 { return false }
        // 같은 문장을 세 번 넘게 되풀이
        let sentences = t.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count >= 6 }
        var counts: [String: Int] = [:]
        for s in sentences { counts[s, default: 0] += 1 }
        if counts.values.contains(where: { $0 >= 3 }) { return false }
        return true
    }

    /// 기억에 남길 주제 이름
    static func topic(for question: String, context: Context) -> String {
        if let first = context.knowledge.first { return first.title }
        if let web = context.web.first { return web.title }
        let q = DoitWeb.searchQuery(from: question)
        return q.isEmpty ? String(question.prefix(20)) : q
    }

    // MARK: - AI 학습 자료 만들기 (형식이 정해진 줄 글로 받아서 검사)

    static func studyReference(subject: String, unit: String, context: Context) -> String {
        let refs = referenceText(context, maxEach: 450)
        return "[과목] \(subject)\n[단원] \(unit)" + (refs.isEmpty ? "" : "\n[참고 자료]\n" + refs)
    }

    static func conceptPrompt(subject: String, unit: String, context: Context, booster: Bool) -> String {
        """
        \(studyReference(subject: subject, unit: unit, context: context))

        위 단원의 개념 정리 노트를 만들어 주세요. 참고 자료를 그대로 베끼지 말고 학생이 이해하기 쉽게 자기 말로 정리해요.
        반드시 아래 형식으로만 써요.
        제목: (단원 제목)
        - (핵심 1)
        - (핵심 2)
        (핵심은 \(booster ? "4" : "6")개, 한 줄에 하나씩, 해요체)
        예시: (이해를 돕는 예시 한두 문장)
        """
    }

    static func parseConcept(_ raw: String, fallbackTitle: String) -> ConceptNote? {
        let lines = clean(raw).components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var title = fallbackTitle
        var points: [String] = []
        var example = ""
        for line in lines {
            let l = line.replacingOccurrences(of: "**", with: "")
            if l.hasPrefix("제목:") || l.hasPrefix("제목 :") {
                let value = l.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { title = value }
            } else if l.hasPrefix("예시:") || l.hasPrefix("예:") || l.hasPrefix("예시 :") {
                example = l.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            } else if let point = bullet(l) {
                if point.count >= 6 { points.append(point) }
            } else if !example.isEmpty, example.count < 200 {
                example += " " + l
            }
        }
        guard points.count >= 3, points.allSatisfy(isUsable) else { return nil }
        return ConceptNote(title: title, keyPoints: Array(points.prefix(8)), example: example)
    }

    static func oxPrompt(subject: String, unit: String, context: Context, count: Int) -> String {
        """
        \(studyReference(subject: subject, unit: unit, context: context))

        위 단원으로 O/X 문제 \(count)개를 새로 만들어 주세요. 맞는 문장(O)과 틀린 문장(X)을 섞어요.
        틀린 문장은 핵심 낱말이나 숫자를 살짝 바꿔서 만들어요. 참고 자료와 확실한 사실만 써요.
        한 줄에 문제 하나, 반드시 이 형식으로만:
        O | (문장) | (짧은 해설)
        X | (문장) | (왜 틀렸는지 짧은 해설)
        """
    }

    static func parseOX(_ raw: String) -> OXSet? {
        var items: [OXItem] = []
        for line in clean(raw).components(separatedBy: "\n") {
            let parts = line.replacingOccurrences(of: "**", with: "").components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }
            var mark = parts[0].uppercased()
            mark = mark.replacingOccurrences(of: #"^\d+[.)]\s*"#, with: "", options: .regularExpression)
            guard ["O", "X", "○", "×"].contains(mark) else { continue }
            let statement = parts[1]
            guard statement.count >= 8, isUsable(statement) else { continue }
            let explanation = parts.count >= 3 ? parts[2] : ""
            items.append(OXItem(statement: statement, isTrue: mark == "O" || mark == "○", explanation: explanation))
        }
        guard items.count >= 2 else { return nil }
        return OXSet(items: items)
    }

    static func clozePrompt(subject: String, unit: String, context: Context, count: Int) -> String {
        """
        \(studyReference(subject: subject, unit: unit, context: context))

        위 단원의 핵심 낱말을 외우는 빈칸 문제 \(count)개를 만들어 주세요.
        문장에서 꼭 외워야 할 낱말 하나를 (   )로 가려요. 참고 자료와 확실한 사실만 써요.
        한 줄에 문제 하나, 반드시 이 형식으로만:
        (빈칸이 있는 문장) | (빈칸에 들어갈 낱말)
        """
    }

    static func parseCloze(_ raw: String) -> ClozeSet? {
        var items: [ClozeItem] = []
        for line in clean(raw).components(separatedBy: "\n") {
            let parts = line.replacingOccurrences(of: "**", with: "").components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }
            var sentence = parts[0].replacingOccurrences(of: #"^(\d+[.)]|•)\s*"#, with: "", options: .regularExpression)
            let answer = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " ()[]'\"."))
            guard !answer.isEmpty, answer.count <= 24, sentence.count >= 8 else { continue }
            // 빈칸 표시를 (   )로 맞춤
            sentence = sentence.replacingOccurrences(of: #"\(\s*\)|_{2,}|\[\s*\]|\(\s*빈칸\s*\)|\(\s*\?\s*\)"#, with: "(   )", options: .regularExpression)
            if !sentence.contains("(   )") {
                guard sentence.contains(answer) else { continue }
                sentence = sentence.replacingOccurrences(of: answer, with: "(   )")
            }
            // 정답이 문장에 그대로 남아 있으면 문제가 안 됨
            if sentence.contains(answer) { continue }
            guard isUsable(sentence) else { continue }
            items.append(ClozeItem(sentence: sentence, answer: answer))
        }
        guard items.count >= 2 else { return nil }
        return ClozeSet(items: items)
    }

    static func problemPrompt(subject: String, unit: String, context: Context, count: Int, hard: Bool) -> String {
        """
        \(studyReference(subject: subject, unit: unit, context: context))

        위 단원으로 \(hard ? "생각을 조금 해야 하는" : "기본 개념을 확인하는") 5지선다 객관식 문제 \(count)개를 새로 만들어 주세요.
        정답은 하나뿐이어야 하고, 오답 보기도 그럴듯하게 만들어요. 참고 자료와 확실한 사실만 써요.
        문제마다 반드시 이 형식으로만:
        문제: (질문)
        1) (보기)
        2) (보기)
        3) (보기)
        4) (보기)
        5) (보기)
        정답: (번호)
        해설: (짧은 해설)
        """
    }

    static func parseProblems(_ raw: String) -> ProblemSet? {
        var items: [Problem] = []
        var question = ""
        var choices: [String] = []
        var answer: Int?
        var explanation = ""
        func flush() {
            defer { question = ""; choices = []; answer = nil; explanation = "" }
            guard question.count >= 6, choices.count == 5, let answer, (1...5).contains(answer),
                  Set(choices).count == 5, isUsable(question) else { return }
            let finalAnswer = "\(answer)번 \(choices[answer - 1])"
            let steps = explanation.isEmpty ? ["정답은 \(finalAnswer)이에요"] : [explanation, "정답은 \(finalAnswer)이에요"]
            items.append(Problem(question: question, choices: choices, answerNumber: answer, steps: steps, finalAnswer: finalAnswer))
        }
        for rawLine in clean(raw).components(separatedBy: "\n") {
            let line = rawLine.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if let m = line.firstMatch(of: #/^(?:문제\s*\d*\s*[:.]|Q\d*\s*[:.])\s*(.+)$/#) {
                if !question.isEmpty { flush() }
                question = String(m.1)
            } else if let m = line.firstMatch(of: #/^(?:[(]?[1-5][).]|[①②③④⑤])\s*(.+)$/#) {
                if choices.count < 5 { choices.append(String(m.1).trimmingCharacters(in: .whitespaces)) }
            } else if let m = line.firstMatch(of: #/^정답\s*[:：]\s*[(]?([1-5①②③④⑤])/#) {
                answer = circled(String(m.1))
            } else if line.hasPrefix("해설") {
                explanation = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            } else if choices.isEmpty, !question.isEmpty {
                question += "\n" + line
            }
        }
        flush()
        guard !items.isEmpty else { return nil }
        return ProblemSet(items: items)
    }

    private static func circled(_ s: String) -> Int? {
        if let n = Int(s) { return n }
        return ["①": 1, "②": 2, "③": 3, "④": 4, "⑤": 5][s]
    }

    private static func bullet(_ line: String) -> String? {
        for mark in ["- ", "• ", "· ", "* "] where line.hasPrefix(mark) {
            return String(line.dropFirst(mark.count)).trimmingCharacters(in: .whitespaces)
        }
        if let m = line.firstMatch(of: #/^\d+[.)]\s*(.+)$/#) { return String(m.1) }
        return nil
    }
}

// MARK: - 실제로 근거 모으고 두뇌 쓰기 (앱에서)

@MainActor
extension DoitMind {
    /// 두뇌를 쓸 수 있는지 (내려받았고 켜 둠)
    static var isAvailable: Bool { DoitBrain.shared.isAvailable }

    /// 질문에 필요한 근거 모으기 (필요하면 인터넷 검색)
    static func gather(question: String, draft: String?, app: String? = nil, allowWeb: Bool = true) async -> Context {
        var context = Context(draft: draft, app: app)
        let matches = DoitKnowledge.search(question, limit: 3)
        context.knowledge = matches.filter { $0.score >= 0.42 }.map(\.entry)
        context.memories = DoitMemory.shared.recall(question, limit: 3)
        let topicGuess = matches.first?.entry.title ?? DoitWeb.searchQuery(from: question)
        let disliked = DoitMemory.shared.isDisliked(topicGuess)
        if allowWeb, shouldSearchWeb(question: question, bestKnowledgeScore: matches.first?.score ?? 0,
                                     hasMemory: !context.memories.isEmpty, disliked: disliked) {
            context.web = await DoitWeb.research(question)
        }
        return context
    }

    /// 답을 만든 뒤 스스로 배우기: 인터넷에서 찾아 정리한 내용은 기억에 남김
    static func learn(question: String, answer: String, context: Context) {
        guard !context.web.isEmpty, isUsable(answer) else { return }
        DoitMemory.shared.remember(topic: topic(for: question, context: context), summary: answer,
                                   sources: context.web.map(\.label), kind: .learned)
    }

    /// 학습 자료용 근거: 교육과정 단원 개념 + 기억 + (모자라면) 인터넷
    static func studyContext(subject: String, unit: String) async -> Context {
        var context = Context()
        var entries = DoitKnowledge.entries(inUnit: unit, subject: subject)
        if entries.count < 2 {
            entries += DoitKnowledge.search(unit, limit: 4).filter { $0.score >= 0.35 }.map(\.entry)
                .filter { e in !entries.contains { $0.title == e.title } }
        }
        context.knowledge = Array(entries.shuffled().prefix(3))
        context.memories = DoitMemory.shared.recall(unit, limit: 2)
        if context.knowledge.count < 2 && context.memories.isEmpty {
            context.web = await DoitWeb.research("\(unit) \(subject.components(separatedBy: " ").last ?? "")", limit: 2)
        }
        return context
    }

    static func makeConcept(subject: String, unit: String, booster: Bool) async -> ConceptNote? {
        guard isAvailable else { return nil }
        let context = await studyContext(subject: subject, unit: unit)
        guard let raw = try? await DoitBrain.shared.complete(system: persona, prompt: conceptPrompt(subject: subject, unit: unit, context: context, booster: booster), maxTokens: 700),
              let note = parseConcept(raw, fallbackTitle: unit) else { return nil }
        // 인터넷에서 찾아 정리한 단원은 기억해 두고 다음에 씀
        if !context.web.isEmpty {
            DoitMemory.shared.remember(topic: unit, summary: note.keyPoints.joined(separator: "\n"), sources: context.web.map(\.label))
        }
        return note
    }

    static func makeOX(subject: String, unit: String, count: Int) async -> OXSet? {
        guard isAvailable else { return nil }
        let context = await studyContext(subject: subject, unit: unit)
        guard let raw = try? await DoitBrain.shared.complete(system: persona, prompt: oxPrompt(subject: subject, unit: unit, context: context, count: count), maxTokens: 600, temperature: 0.7) else { return nil }
        return parseOX(raw).map { OXSet(items: Array($0.items.prefix(count))) }
    }

    static func makeCloze(subject: String, unit: String, count: Int) async -> ClozeSet? {
        guard isAvailable else { return nil }
        let context = await studyContext(subject: subject, unit: unit)
        guard let raw = try? await DoitBrain.shared.complete(system: persona, prompt: clozePrompt(subject: subject, unit: unit, context: context, count: count), maxTokens: 500, temperature: 0.7) else { return nil }
        return parseCloze(raw).map { ClozeSet(items: Array($0.items.prefix(count))) }
    }

    static func makeProblems(subject: String, unit: String, count: Int, hard: Bool) async -> ProblemSet? {
        guard isAvailable else { return nil }
        let context = await studyContext(subject: subject, unit: unit)
        guard let raw = try? await DoitBrain.shared.complete(system: persona, prompt: problemPrompt(subject: subject, unit: unit, context: context, count: count, hard: hard), maxTokens: 900, temperature: 0.7) else { return nil }
        return parseProblems(raw).map { ProblemSet(items: Array($0.items.prefix(count))) }
    }
}

@MainActor
extension DoitMind {
    /// 한 번에 답 만들기 (AI에게 질문하기 화면용). 두뇌가 없거나 답이 이상하면 nil
    static func reply(question: String, draft: String?, history: [Turn] = []) async -> (text: String, sources: [String])? {
        guard isAvailable else { return nil }
        let context = await gather(question: question, draft: draft)
        guard let raw = try? await DoitBrain.shared.complete(system: persona, prompt: answerPrompt(question: question, context: context, history: history)) else { return nil }
        let text = clean(raw)
        guard isUsable(text) else { return nil }
        learn(question: question, answer: text, context: context)
        return (text, context.sourceLabels)
    }
}
