import UIKit

/// 두잇 AI 선생님: 외부 AI 없이 위키백과 검색 + 직접 만든 수학 엔진으로 학습 자료를 만듦
/// - 개념 정리 / 빈칸 / O·X / 객관식: 검색한 글의 문장을 골라 가공
/// - 수학 계산 문제·풀이·비슷한 문제: 수학 엔진이 직접 만들고 풂
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
        let article = try await topicArticle(subject: subject, unit: unit)
        let sentences = article.sentences
        guard !sentences.isEmpty else { throw TutorError.notEnough("'\(unit)' 자료가 너무 짧아요. 단원 이름을 조금 바꿔보세요.") }
        let points = Array(sentences.prefix(booster ? 3 : 6))
        var example = ""
        if isMath(subject: subject, unit: unit), let problem = MathProblems.make(unit: unit, hard: false) {
            example = "예제: \(problem.question)\n풀이: \(problem.steps.joined(separator: " → "))\n답: \(problem.finalAnswer)"
        } else if sentences.count > points.count {
            example = sentences[points.count]
        }
        example += (example.isEmpty ? "" : "\n\n") + article.source
        return ConceptNote(title: article.title, keyPoints: points, example: example)
    }

    // MARK: - 2. 빈칸 암기

    static func cloze(subject: String, unit: String, count: Int) async throws -> ClozeSet {
        let (article, terms) = try await material(subject: subject, unit: unit)
        var items: [ClozeItem] = []
        var used = Set<String>()
        for sentence in article.sentences where items.count < count {
            guard let term = terms.first(where: { sentence.contains($0) && !used.contains($0 + sentence) }) else { continue }
            used.insert(term + sentence)
            let blanked = sentence.replacingOccurrences(of: term, with: "____")
            items.append(ClozeItem(sentence: blanked, answer: term))
        }
        guard items.count >= 2 else { throw TutorError.notEnough("빈칸 문제를 만들 만한 문장이 부족해요. 다른 단원 이름으로 해보세요.") }
        return ClozeSet(items: items)
    }

    // MARK: - 3. O/X

    static func ox(subject: String, unit: String, count: Int) async throws -> OXSet {
        let (article, terms) = try await material(subject: subject, unit: unit)
        var items: [OXItem] = []
        for (index, sentence) in article.sentences.enumerated() where items.count < count {
            if index % 2 == 1, let falsified = falsify(sentence, terms: terms) {
                items.append(OXItem(statement: falsified, isTrue: false,
                                    explanation: "틀린 문장이에요. 바른 문장: \(sentence)"))
            } else {
                items.append(OXItem(statement: sentence, isTrue: true, explanation: "맞는 문장이에요. (\(article.source))"))
            }
        }
        guard items.count >= 2 else { throw TutorError.notEnough("O/X 문제를 만들 만한 문장이 부족해요.") }
        return OXSet(items: items.shuffled())
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
        // 수학 계산 단원은 직접 만든 계산 문제
        if isMath(subject: subject, unit: unit) {
            let made = (0..<count).compactMap { _ in MathProblems.make(unit: unit, hard: hard) }
            if made.count >= max(1, count - 1) { return ProblemSet(items: made) }
        }
        let (article, terms) = try await material(subject: subject, unit: unit)
        var items: [Problem] = []
        for sentence in article.sentences where items.count < count {
            guard let term = terms.first(where: { sentence.contains($0) }) else { continue }
            let distractors = terms.filter { $0 != term && !sentence.contains($0) }.shuffled().prefix(4)
            guard distractors.count == 4 else { continue }
            var choices = Array(distractors) + [term]
            choices.shuffle()
            let answer = (choices.firstIndex(of: term) ?? 0) + 1
            items.append(Problem(
                question: "다음 설명의 빈칸에 알맞은 것은?\n\(sentence.replacingOccurrences(of: term, with: "(   )"))",
                choices: choices,
                answerNumber: answer,
                steps: ["설명 속 단서를 찾아요: \(clue(in: sentence, excluding: term))", "단서에 맞는 용어는 '\(term)'이에요."],
                finalAnswer: "\(answer)번 \(term)"
            ))
        }
        guard !items.isEmpty else { throw TutorError.notEnough("문제를 만들 만한 자료가 부족해요. 다른 단원 이름으로 해보세요.") }
        return ProblemSet(items: items)
    }

    private static func clue(in sentence: String, excluding term: String) -> String {
        let words = sentence.replacingOccurrences(of: term, with: " ").split(separator: " ").map(String.init)
        return words.filter { $0.count >= 3 }.prefix(4).joined(separator: ", ")
    }

    // MARK: - 5. 오답노트 단계별 풀이

    static func solution(for problem: String) async throws -> WrittenSolution {
        guard let solved = MathSolver.solve(problem) else {
            let concept = (try? await conceptLine(for: problem)) ?? ""
            throw TutorError.cannotSolve(
                "이 문제는 아직 두잇 AI가 직접 풀 수 없는 유형이에요.\n지금은 방정식(일차·이차), 이차함수의 꼭짓점·최대최소, 두 근의 합·곱, 나머지정리, 식 계산·전개를 풀 수 있어요."
                + (concept.isEmpty ? "" : "\n\n관련 개념: \(concept)")
            )
        }
        var concept = solved.concept
        if let line = try? await conceptLine(for: solved.topic) { concept += "\n" + line }
        return WrittenSolution(concept: concept, steps: solved.steps, finalAnswer: solved.answer)
    }

    // MARK: - 6. 비슷한 문제

    static func similar(to problem: String) throws -> SimilarProblemSet {
        guard let kind = MathSolver.kind(of: problem) else {
            throw TutorError.cannotSolve("비슷한 문제는 지금 방정식, 이차함수, 두 근의 합·곱, 나머지정리 문제에서 만들 수 있어요.")
        }
        let made = (0..<3).compactMap { level in MathProblems.similar(kind: kind, level: level) }
        guard made.count == 3 else { throw TutorError.notEnough("비슷한 문제를 만들지 못했어요. 다시 시도해주세요.") }
        return SimilarProblemSet(problems: made)
    }

    // MARK: - 7. 질문에 답하기 (AI에게 질문하기, 두잇 AI 대화)

    static func answer(_ question: String, subject: String? = nil, image: UIImage? = nil) async throws -> String {
        var text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        var photoText = ""
        if let image {
            let lines = (try? await OCRService.recognizeMath(image)) ?? []
            photoText = MathOCRFixer.fix(OCRService.printedText(from: lines))
            if !photoText.isEmpty { text += (text.isEmpty ? "" : "\n") + photoText }
        }
        guard !text.isEmpty else { throw TutorError.notEnough("사진에서 글자를 찾지 못했어요. 글자가 잘 보이게 다시 찍어주세요.") }
        // 수학이면 직접 풀이
        if let solved = MathSolver.solve(text) {
            var lines = ["**\(solved.topic)**", solved.concept]
            lines += solved.steps.enumerated().map { "\($0.offset + 1). \($0.element.hint) \($0.element.work)" }
            lines.append("**답: \(solved.answer)**")
            return lines.joined(separator: "\n")
        }
        // 그 밖에는 검색해서 설명
        // 질문이 짧거나 없으면 사진 글자의 첫 줄로 검색
        let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = keywords(from: asked.count >= 2 ? asked : photoText, subject: subject)
        guard !query.isEmpty else {
            throw TutorError.cannotSolve("무엇을 찾아야 할지 모르겠어요. 궁금한 개념 이름을 넣어서 다시 물어봐 주세요. 예: 광합성이 뭐야?")
        }
        let article = try await DoitSearch.bestArticle(for: query, intro: true)
        let sentences = article.sentences.prefix(5)
        guard !sentences.isEmpty else { throw DoitSearch.SearchError.notFound(query) }
        return "**\(article.title)**\n" + sentences.joined(separator: "\n") + "\n\n" + article.source
    }

    /// 같은 주제를 더 자세히 (본문 뒤쪽 문장들)
    static func more(about topic: String) async throws -> String {
        let article = try await DoitSearch.article(topic)
        let sentences = Array(article.sentences.dropFirst(5).prefix(8))
        guard !sentences.isEmpty else { throw DoitSearch.SearchError.notFound(topic) }
        return "**\(article.title)** 더 알아보기\n" + sentences.joined(separator: "\n") + "\n\n" + article.source
    }

    /// 질문에서 검색어만 남김 ("광합성이 뭐야?" → "광합성")
    static func keywords(from text: String, subject: String? = nil) -> String {
        var t = text.components(separatedBy: "\n").first ?? text
        let remove = ["에 대해서", "에 대해", "에대해", "설명해줘", "설명해 줘", "설명", "알려줘", "알려 줘", "가르쳐줘", "뭐야", "뭔가요",
                      "무엇인가요", "무엇", "이란", "란", "개념", "정의", "의미", "뜻이", "뜻", "궁금해", "어떻게", "왜", "?", "!", "좀", "해줘"]
        for word in remove { t = t.replacingOccurrences(of: word, with: " ") }
        let particles = ["은", "는", "이", "가", "을", "를", "의", "에", "이야", "야", "요"]
        let words = t.split(separator: " ").map { word -> String in
            var w = String(word)
            for p in particles where w.count > p.count + 1 && w.hasSuffix(p) {
                w.removeLast(p.count)
                break
            }
            return w
        }.filter { !$0.isEmpty }
        return words.prefix(4).joined(separator: " ")
    }

    // MARK: - 공통

    private static func isMath(subject: String, unit: String) -> Bool {
        subject.contains("수학") || MathProblems.topic(for: unit) != nil
    }

    /// 단원에 맞는 글 (단원 이름 → 과목+단원 순서로 검색)
    private static func topicArticle(subject: String, unit: String) async throws -> DoitSearch.Article {
        do {
            return try await DoitSearch.bestArticle(for: unit)
        } catch DoitSearch.SearchError.notFound {
            return try await DoitSearch.bestArticle(for: "\(subject) \(unit)")
        }
    }

    /// 글 + 빈칸·보기로 쓸 핵심 용어
    private static func material(subject: String, unit: String) async throws -> (DoitSearch.Article, [String]) {
        let article = try await topicArticle(subject: subject, unit: unit)
        let related = (try? await DoitSearch.search(unit, limit: 10)) ?? []
        var terms: [String] = [article.title]
        terms += related.map(\.title).filter { $0 != article.title && $0.count <= 12 }
        terms += frequentTerms(in: article.text)
        var seen = Set<String>()
        terms = terms.filter { term in
            let key = term.replacingOccurrences(of: " ", with: "")
            guard key.count >= 2, !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
        // 긴 용어부터 (짧은 말이 긴 말 속에 들어가는 경우 방지)
        return (article, terms.sorted { $0.count > $1.count })
    }

    /// 글에서 여러 번 나온 핵심 낱말 (조사 떼고, 흔한 말 제외)
    private static func frequentTerms(in text: String) -> [String] {
        let stop: Set<String> = ["있다", "한다", "된다", "것이", "이다", "또한", "그러나", "따라서", "경우", "때문", "이러한", "그리고",
                                 "하는", "있는", "되는", "하여", "대한", "통해", "가장", "모든", "사이", "등의", "다른", "같은", "위해"]
        var counts: [String: Int] = [:]
        for raw in text.split(whereSeparator: { !$0.isLetter }) {
            var word = String(raw)
            guard word.range(of: "^[가-힣]+$", options: .regularExpression) != nil else { continue }
            for p in ["으로", "에서", "에게", "이다", "은", "는", "이", "가", "을", "를", "의", "에", "와", "과", "로", "도"]
            where word.count > p.count + 1 && word.hasSuffix(p) {
                word.removeLast(p.count)
                break
            }
            guard (2...8).contains(word.count), !stop.contains(word) else { continue }
            counts[word, default: 0] += 1
        }
        return counts.filter { $0.value >= 2 }.sorted { $0.value > $1.value }.prefix(20).map(\.key)
    }

    /// 주제 낱말로 위키백과 첫 문장 (풀이 화면의 개념 설명용)
    private static func conceptLine(for topic: String) async throws -> String {
        let query = keywords(from: topic)
        guard !query.isEmpty else { return "" }
        let article = try await DoitSearch.bestArticle(for: String(query.prefix(30)), intro: true)
        guard let first = article.sentences.first else { return "" }
        return first + " (\(article.source))"
    }
}
