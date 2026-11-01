import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 두잇 AI + Apple Intelligence 병행
/// - 두잇 AI(직접 만든 엔진): 앱 기능 실행, 수학 풀이, 영어·과학·사회 내장 지식, 퀴즈 → 정확하고 빠른 일
/// - Apple Intelligence(기기 안 모델): 자유로운 대화, 엔진에 없는 개념 설명, 학습 자료 만들기 → 열린 질문
/// 서버로 아무것도 보내지 않아요. 지원하지 않는 기기에서는 두잇 AI만 동작해요.
enum DoitAppleAI {
    enum AIError: LocalizedError {
        case unavailable(String)
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let message): return message
            case .failed(let reason): return "Apple Intelligence가 답을 만들지 못했어요.\n\(reason)"
            }
        }
    }

    /// 화면에 붙이는 안내 (AI가 만든 내용)
    static let caution = "Apple Intelligence가 만든 내용이라 틀릴 수 있어요."

    static let tutorInstructions = """
    너는 한국 고등학생을 돕는 친절한 과외 선생님이야.
    2022 개정 교육과정 수준에 맞춰 정확하고 간결한 한국어(해요체)로 답해.
    확실하지 않은 내용은 지어내지 말고 모른다고 말해.
    수식은 x², √(…), (분자)/(분모), ≤, ≥ 처럼 써. 강조는 **굵게**만 쓰고 다른 마크다운(#, 표, 코드)은 쓰지 마.
    """

    static let chatInstructions = """
    너는 공부 플래너 앱 'DOOOIT' 안에 있는 AI 도우미 '두잇 AI'야.
    한국 고등학생과 친구처럼 따뜻하게, 해요체로 짧게(보통 2~5문장) 대답해.
    공부 질문은 정확하게 설명하고, 확실하지 않으면 모른다고 솔직하게 말해.
    일정 추가, 타이머, 단어 추가, 메모, D-Day 같은 앱 기능은 네가 직접 실행할 수 없어. 그런 부탁을 받으면
    "내일 오후 4시에 수학 공부 2시간 추가해줘"처럼 말하면 된다고 예시를 알려줘.
    강조는 **굵게**만 쓰고 다른 마크다운(#, 표, 코드)은 쓰지 마.
    자해나 위험한 이야기가 나오면 공감하고, 자살예방상담전화 109와 청소년상담 1388을 꼭 안내해.
    """

    // MARK: - 사용할 수 있는지

    /// nil이면 사용 가능, 아니면 사용자에게 보여줄 안내 문구
    static var unavailableMessage: String? {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "이 기기는 Apple Intelligence를 지원하지 않아요 (아이폰 15 Pro 이상). 두잇 AI 기본 기능은 그대로 쓸 수 있어요."
            case .appleIntelligenceNotEnabled:
                return "설정 > Apple Intelligence 및 Siri에서 Apple Intelligence를 켜면 더 자유롭게 대화할 수 있어요."
            case .modelNotReady:
                return "Apple Intelligence 모델을 내려받는 중이에요. Wi-Fi에 연결해 두고 잠시 후 다시 시도해주세요."
            @unknown default:
                return "지금은 Apple Intelligence를 사용할 수 없어요."
            }
        }
        #else
        return "이 기기에서는 Apple Intelligence를 사용할 수 없어요."
        #endif
    }

    static var isAvailable: Bool { unavailableMessage == nil }

    // MARK: - 한 번 묻고 답하기

    static func answer(_ prompt: String, instructions: String = tutorInstructions) async throws -> String {
        #if canImport(FoundationModels)
        if let message = unavailableMessage { throw AIError.unavailable(message) }
        let session = LanguageModelSession(instructions: instructions)
        do {
            let text = try await session.respond(to: prompt).content
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw describe(error)
        }
        #else
        throw AIError.unavailable(unavailableMessage ?? "")
        #endif
    }

    // MARK: - 대화 (이전 대화를 기억)

    @MainActor
    final class Chat {
        #if canImport(FoundationModels)
        private var session: LanguageModelSession?
        #endif

        func reset() {
            #if canImport(FoundationModels)
            session = nil
            #endif
        }

        /// context: 오늘 공부 상황 같은 앱 정보 (대답에 참고)
        func reply(_ text: String, context: String) async throws -> String {
            #if canImport(FoundationModels)
            if let message = DoitAppleAI.unavailableMessage { throw AIError.unavailable(message) }
            let prompt = context.isEmpty ? text : "[앱 정보: \(context)]\n\(text)"
            for attempt in 0..<2 {
                if session == nil { session = LanguageModelSession(instructions: DoitAppleAI.chatInstructions) }
                do {
                    let reply = try await session!.respond(to: prompt).content
                    return reply.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    // 대화가 길어져 기억할 공간이 꽉 차면 새로 시작해서 한 번 더
                    session = nil
                    if attempt == 0, String(describing: error).contains("exceededContext") { continue }
                    throw DoitAppleAI.describe(error)
                }
            }
            throw AIError.failed("잠시 후 다시 시도해주세요.")
            #else
            throw AIError.unavailable(DoitAppleAI.unavailableMessage ?? "")
            #endif
        }
    }

    // MARK: - 학습 자료 만들기 (가이드 생성)

    static func concept(subject: String, unit: String, booster: Bool) async throws -> ConceptNote {
        #if canImport(FoundationModels)
        let made = try await generate(AIConcept.self, prompt:
            "\(subject) '\(unit)' 단원의 핵심 개념을 \(booster ? "시험 직전용으로 3~4개만 아주 짧게" : "4~6개로") 정리해줘. 용어와 공식은 교과서대로 정확하게 써.")
        return ConceptNote(title: made.title, keyPoints: made.keyPoints, example: made.example + "\n\n" + caution)
        #else
        throw AIError.unavailable(unavailableMessage ?? "")
        #endif
    }

    static func cloze(subject: String, unit: String, count: Int) async throws -> ClozeSet {
        #if canImport(FoundationModels)
        let made = try await generate(AIClozeSet.self, prompt:
            "\(subject) '\(unit)' 단원에서 꼭 외워야 할 용어·공식으로 빈칸 문제 \(count)개를 만들어줘. 문장 속 핵심 용어 하나만 ____ 로 가려.")
        let items = made.items.filter { $0.sentence.contains("__") && !$0.answer.isEmpty }.map { ClozeItem(sentence: $0.sentence, answer: $0.answer) }
        guard !items.isEmpty else { throw AIError.failed("빈칸 문제를 만들지 못했어요. 다시 시도해주세요.") }
        return ClozeSet(items: items)
        #else
        throw AIError.unavailable(unavailableMessage ?? "")
        #endif
    }

    static func ox(subject: String, unit: String, count: Int) async throws -> OXSet {
        #if canImport(FoundationModels)
        let made = try await generate(AIOXSet.self, prompt:
            "\(subject.isEmpty ? "" : "\(subject) ")'\(unit)'에 대한 개념 확인 O/X 문제 \(count)개를 만들어줘. 맞는 문장과 틀린 문장을 섞고, 틀린 문장은 학생이 자주 헷갈리는 내용으로 만들어.")
        let items = made.items.map { OXItem(statement: $0.statement, isTrue: $0.isTrue, explanation: $0.explanation) }
        guard !items.isEmpty else { throw AIError.failed("O/X 문제를 만들지 못했어요. 다시 시도해주세요.") }
        return OXSet(items: items)
        #else
        throw AIError.unavailable(unavailableMessage ?? "")
        #endif
    }

    static func problems(subject: String, unit: String, count: Int, hard: Bool) async throws -> ProblemSet {
        #if canImport(FoundationModels)
        let made = try await generate(AIProblemSet.self, prompt:
            "\(subject) '\(unit)' 단원의 \(hard ? "응용·실전" : "기본") 5지선다 문제 \(count)개를 만들어줘. 정답이 하나뿐이도록 하고, 풀이를 꼭 검산해.")
        let items = made.items.compactMap { p -> Problem? in
            guard p.choices.count >= 2, (1...p.choices.count).contains(p.answerNumber) else { return nil }
            return Problem(question: p.question, choices: p.choices, answerNumber: p.answerNumber, steps: p.steps, finalAnswer: p.finalAnswer)
        }
        guard !items.isEmpty else { throw AIError.failed("문제를 만들지 못했어요. 다시 시도해주세요.") }
        return ProblemSet(items: items)
        #else
        throw AIError.unavailable(unavailableMessage ?? "")
        #endif
    }

    static func solution(for problem: String) async throws -> WrittenSolution {
        #if canImport(FoundationModels)
        let made = try await generate(AISolution.self, prompt:
            "다음 문제를 서술형 모범 답안처럼 단계별로 풀어줘. 각 단계는 생각할 점(힌트)과 풀이 식으로 나누고, 계산을 꼭 검산해.\n\n문제:\n\(problem)")
        return WrittenSolution(concept: made.concept + "\n" + caution,
                               steps: made.steps.map { SolutionStep(hint: $0.hint, work: $0.work) },
                               finalAnswer: made.finalAnswer)
        #else
        throw AIError.unavailable(unavailableMessage ?? "")
        #endif
    }

    static func similar(to problem: String) async throws -> SimilarProblemSet {
        #if canImport(FoundationModels)
        let made = try await generate(AISimilarSet.self, prompt: """
            다음 문제와 같은 개념과 유형을 연습할 수 있는 비슷한 문제 3개를 만들어줘.
            숫자, 계수, 조건을 바꿔 새 문제로 만들고, 1번은 조금 쉽게, 3번은 조금 어렵게. 정답은 직접 계산해서 확인해.

            원래 문제:
            \(problem)
            """)
        let items = made.problems.map { SimilarProblem(question: $0.question, answer: $0.answer, explanation: $0.explanation) }
        guard !items.isEmpty else { throw AIError.failed("비슷한 문제를 만들지 못했어요. 다시 시도해주세요.") }
        return SimilarProblemSet(problems: Array(items.prefix(3)))
        #else
        throw AIError.unavailable(unavailableMessage ?? "")
        #endif
    }

    // MARK: - 공통

    #if canImport(FoundationModels)
    private static func generate<T: Generable>(_ type: T.Type, prompt: String) async throws -> T {
        if let message = unavailableMessage { throw AIError.unavailable(message) }
        let session = LanguageModelSession(instructions: tutorInstructions)
        do {
            return try await session.respond(to: prompt, generating: type).content
        } catch {
            throw describe(error)
        }
    }
    #endif

    /// 기기 AI 오류를 이해할 수 있는 문장으로
    static func describe(_ error: Error) -> AIError {
        if let known = error as? AIError { return known }
        let raw = String(describing: error)
        let reason: String
        if raw.contains("guardrail") {
            reason = "안전 필터에 걸렸어요. 표현을 조금 바꿔서 다시 물어봐 주세요."
        } else if raw.contains("unsupportedLanguage") || raw.contains("Locale") {
            reason = "지금 언어 설정을 지원하지 않아요. 설정 > Apple Intelligence 및 Siri의 언어를 확인해주세요."
        } else if raw.contains("exceededContext") {
            reason = "내용이 너무 길어요. 조금 줄여서 다시 시도해주세요."
        } else if raw.contains("assetsUnavailable") {
            reason = "모델을 아직 내려받는 중이에요. Wi-Fi에 연결해 두고 잠시 후 다시 시도해주세요."
        } else if raw.contains("rateLimited") || raw.contains("concurrent") {
            reason = "요청이 겹쳤어요. 잠시 후 다시 시도해주세요."
        } else {
            reason = "잠시 후 다시 시도해주세요."
        }
        return .failed(reason)
    }
}

// MARK: - 가이드 생성용 모양 (Apple Intelligence가 이 모양대로 답을 채움)

#if canImport(FoundationModels)
@Generable
struct AIConcept {
    @Guide(description: "단원 또는 개념 이름")
    var title: String
    @Guide(description: "핵심 개념 3~6개. 각 항목은 한두 문장의 쉬운 한국어 설명")
    var keyPoints: [String]
    @Guide(description: "개념을 적용한 짧은 예시나 대표 문제와 풀이")
    var example: String
}

@Generable
struct AIClozeItem {
    @Guide(description: "핵심 용어 하나를 ____ 로 가린 한국어 문장")
    var sentence: String
    @Guide(description: "빈칸에 들어갈 정답 용어 (짧게)")
    var answer: String
}

@Generable
struct AIClozeSet {
    @Guide(description: "빈칸 문제 목록")
    var items: [AIClozeItem]
}

@Generable
struct AIOXItem {
    @Guide(description: "참 또는 거짓을 판단할 한국어 문장")
    var statement: String
    @Guide(description: "문장이 맞으면 true, 틀리면 false")
    var isTrue: Bool
    @Guide(description: "왜 맞거나 틀린지 한두 문장 해설")
    var explanation: String
}

@Generable
struct AIOXSet {
    @Guide(description: "O/X 문제 목록")
    var items: [AIOXItem]
}

@Generable
struct AIProblem {
    @Guide(description: "문제 본문")
    var question: String
    @Guide(description: "보기 정확히 5개")
    var choices: [String]
    @Guide(description: "정답 보기의 번호 1~5")
    var answerNumber: Int
    @Guide(description: "단계별 풀이. 각 단계는 한 줄")
    var steps: [String]
    @Guide(description: "최종 답")
    var finalAnswer: String
}

@Generable
struct AIProblemSet {
    @Guide(description: "문제 목록")
    var items: [AIProblem]
}

@Generable
struct AIStep {
    @Guide(description: "이 단계에서 생각할 점 (질문 형태의 힌트)")
    var hint: String
    @Guide(description: "이 단계의 풀이 식이나 서술")
    var work: String
}

@Generable
struct AISolution {
    @Guide(description: "문제를 푸는 데 필요한 개념 요약")
    var concept: String
    @Guide(description: "2~4단계의 서술형 풀이")
    var steps: [AIStep]
    @Guide(description: "최종 답")
    var finalAnswer: String
}

@Generable
struct AISimilar {
    @Guide(description: "원래 문제와 같은 개념·유형으로 숫자나 조건만 바꾼 새 문제. 혼자 풀 수 있게 완결된 문장")
    var question: String
    @Guide(description: "정답. 숫자나 식으로 짧게")
    var answer: String
    @Guide(description: "2~3문장 해설")
    var explanation: String
}

@Generable
struct AISimilarSet {
    @Guide(description: "비슷한 문제 정확히 3개")
    var problems: [AISimilar]
}
#endif
