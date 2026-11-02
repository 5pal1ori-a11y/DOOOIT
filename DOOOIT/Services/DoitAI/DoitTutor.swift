import UIKit

/// 두잇 AI 선생님: AI 학습 자료(DoitStudy), 오답노트 풀이, 비슷한 문제, 질문 답하기
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

    // MARK: - 1~4. AI 학습 (개념 → 빈칸 → O/X → 문제)
    // 고른 단원의 자료만으로 만들고 따로 검증해요 (자세한 순서는 DoitStudy)

    // 교육과정에 없는 주제(과목 = DoitStudy.freeSubject)는 모델이 만들고 검사해요 (DoitStudyFree)

    static func concept(subject: String, unit: String, booster: Bool) async throws -> ConceptNote {
        if DoitStudy.isFree(subject) { return try await DoitStudy.freeConcept(topic: unit) }
        return try await DoitStudy.makePack(subject: subject, unit: unit, booster: booster).concept
    }

    static func cloze(subject: String, unit: String, count: Int) async throws -> ClozeSet {
        if DoitStudy.isFree(subject) { return try await DoitStudy.freeCloze(topic: unit, count: count) }
        return try await DoitStudy.cloze(subject: subject, unit: unit, count: count)
    }

    static func ox(subject: String, unit: String, count: Int) async throws -> OXSet {
        if DoitStudy.isFree(subject) { return try await DoitStudy.freeOX(topic: unit, count: count) }
        return try await DoitStudy.ox(subject: subject, unit: unit, count: count)
    }

    static func problems(subject: String, unit: String, count: Int, hard: Bool) async throws -> ProblemSet {
        if DoitStudy.isFree(subject) { return try await DoitStudy.freeProblems(topic: unit, count: count) }
        return try await DoitStudy.problems(subject: subject, unit: unit, count: count, hard: hard)
    }

    // MARK: - 5. 오답노트 단계별 풀이

    static func solution(for problem: String) async throws -> WrittenSolution {
        // 풀이 엔진이 직접 푼 단계에 "쓰는 개념·이유·다음 단계"를 붙임 (못 푸는 문제는 풀이를 지어내지 않음)
        if let solved = MathSolver.solve(problem) {
            return DoitSolutionWriter.write(solved)
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
        let builtIn = DoitEnglish.answer(text) ?? DoitScience.answer(text) ?? DoitSocial.answer(text)
        // 모델이 있으면 근거(앱 지식·기억·인터넷)를 읽고 자기 말로 설명 (숫자 계산 질문은 엔진 답 그대로)
        if !text.contains(where: \.isNumber) || builtIn == nil,
           let thought = await DoitMind.reply(question: text, draft: builtIn ?? DoitKnowledge.answer(text)) {
            return thought.text + (thought.sources.isEmpty ? "" : "\n\n출처: " + thought.sources.joined(separator: ", "))
        }
        if let known = builtIn { return known }
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
}
