import Foundation
import FoundationModels

// MARK: - AI가 만들어내는 학습 자료 형식 (기기 안 Apple Foundation Models 가이드 생성)

@Generable
struct ConceptNote: Codable {
    @Guide(description: "단원 이름")
    var title: String
    @Guide(description: "핵심 개념 3~6개. 각 항목은 한두 문장의 쉬운 한국어 설명")
    var keyPoints: [String]
    @Guide(description: "개념을 적용한 짧은 예시나 대표 문제와 풀이")
    var example: String
}

@Generable
struct ClozeItem: Codable {
    @Guide(description: "핵심 용어 하나를 ____ 로 가린 한국어 문장")
    var sentence: String
    @Guide(description: "빈칸에 들어갈 정답 용어 (짧게)")
    var answer: String
}

@Generable
struct ClozeSet: Codable {
    @Guide(description: "빈칸 문제 목록")
    var items: [ClozeItem]
}

@Generable
struct OXItem: Codable {
    @Guide(description: "참 또는 거짓을 판단할 한국어 문장")
    var statement: String
    @Guide(description: "문장이 맞으면 true, 틀리면 false")
    var isTrue: Bool
    @Guide(description: "왜 맞거나 틀린지 한두 문장 해설")
    var explanation: String
}

@Generable
struct OXSet: Codable {
    @Guide(description: "O/X 문제 목록")
    var items: [OXItem]
}

@Generable
struct Problem: Codable {
    @Guide(description: "문제 본문")
    var question: String
    @Guide(description: "보기 정확히 5개")
    var choices: [String]
    @Guide(description: "정답 보기의 번호 1~5")
    var answerNumber: Int
    @Guide(description: "단계별 풀이. 각 단계는 '생각할 점: 식' 형태의 한 줄")
    var steps: [String]
    @Guide(description: "최종 답")
    var finalAnswer: String
}

@Generable
struct ProblemSet: Codable {
    @Guide(description: "문제 목록")
    var items: [Problem]
}

@Generable
struct SolutionStep: Codable {
    @Guide(description: "이 단계에서 생각할 점 (질문 형태의 힌트)")
    var hint: String
    @Guide(description: "이 단계의 풀이 식이나 서술")
    var work: String
}

@Generable
struct WrittenSolution: Codable {
    @Guide(description: "문제를 푸는 데 필요한 개념 요약")
    var concept: String
    @Guide(description: "2~4단계의 서술형 풀이")
    var steps: [SolutionStep]
    @Guide(description: "최종 답")
    var finalAnswer: String
}

// MARK: - 기기 안 AI 과외 선생님

enum AITutorError: LocalizedError {
    case unavailable(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message): return message
        case .failed(let reason): return "AI가 답을 만들지 못했어요.\n\(reason)"
        }
    }

    /// 기기 AI 오류를 사용자가 이해할 수 있는 문장 + 원래 오류 이름으로
    static func describe(_ error: Error) -> AITutorError {
        let raw = String(describing: error)
        let reason: String
        if raw.contains("guardrail") {
            reason = "안전 필터에 걸렸어요. 단원 이름을 조금 바꿔서 다시 시도해보세요."
        } else if raw.contains("unsupportedLanguage") || raw.contains("Locale") {
            reason = "기기 AI가 지금 언어 설정을 지원하지 않아요. 설정 > Apple Intelligence 및 Siri의 언어를 확인해주세요."
        } else if raw.contains("exceededContext") {
            reason = "내용이 너무 길어요. 문제 텍스트를 줄여서 다시 시도해주세요."
        } else if raw.contains("assetsUnavailable") {
            reason = "AI 모델을 아직 내려받는 중이에요. Wi-Fi에 연결해 두고 잠시 후 다시 시도해주세요."
        } else if raw.contains("rateLimited") || raw.contains("concurrent") {
            reason = "요청이 겹쳤어요. 잠시 후 다시 시도해주세요."
        } else if raw.contains("Cancellation") || raw.contains("cancelled") {
            reason = "중간에 멈췄어요. 다시 시도해주세요."
        } else {
            reason = "잠시 후 다시 시도해주세요."
        }
        return .failed("\(reason)\n(오류: \(String(raw.prefix(120))))")
    }
}

@MainActor
enum AITutor {
    static let instructions = """
    너는 한국 고등학생을 돕는 친절한 과외 선생님이야.
    2022 개정 교육과정 수준에 맞춰 정확하고 간결한 한국어로 답해.
    확실하지 않은 내용은 지어내지 말고 모른다고 말해.
    """

    /// nil이면 사용 가능, 아니면 사용자에게 보여줄 안내 문구
    static var unavailableMessage: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "이 기기는 기기 안 AI(Apple Intelligence)를 지원하지 않아요. 아이폰 15 Pro 이상에서 쓸 수 있어요."
            case .appleIntelligenceNotEnabled:
                return "설정 > Apple Intelligence 및 Siri에서 Apple Intelligence를 켜주세요."
            case .modelNotReady:
                return "AI 모델을 내려받는 중이에요. 잠시 후 다시 시도해주세요."
            @unknown default:
                return "지금은 AI를 사용할 수 없어요."
            }
        }
    }

    static func generate<T: Generable>(_ type: T.Type, prompt: String) async throws -> T {
        if let message = unavailableMessage { throw AITutorError.unavailable(message) }
        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: prompt, generating: type)
            return response.content
        } catch {
            print("AI 생성 실패: \(error)")
            throw AITutorError.describe(error)
        }
    }

    static func answer(_ question: String) async throws -> String {
        if let message = unavailableMessage { throw AITutorError.unavailable(message) }
        let session = LanguageModelSession(instructions: instructions)
        do {
            return try await session.respond(to: question).content
        } catch {
            print("AI 답변 실패: \(error)")
            throw AITutorError.describe(error)
        }
    }

    // MARK: 프롬프트

    static func conceptPrompt(subject: String, unit: String, booster: Bool) -> String {
        "\(subject) '\(unit)' 단원의 핵심 개념을 \(booster ? "시험 직전용으로 3개만 아주 짧게" : "4~6개로") 정리해줘. 공식과 용어를 정확하게 써."
    }

    static func clozePrompt(subject: String, unit: String, count: Int) -> String {
        "\(subject) '\(unit)' 단원에서 꼭 외워야 할 용어·공식으로 빈칸 문제 \(count)개를 만들어줘. 문장 속 핵심 용어 하나만 ____ 로 가려."
    }

    static func oxPrompt(subject: String, unit: String, count: Int) -> String {
        "\(subject) '\(unit)' 단원 개념을 확인하는 O/X 문제 \(count)개를 만들어줘. 맞는 문장과 틀린 문장을 섞고, 틀린 문장은 학생이 자주 헷갈리는 내용으로 만들어."
    }

    static func problemPrompt(subject: String, unit: String, count: Int, hard: Bool) -> String {
        "\(subject) '\(unit)' 단원의 \(hard ? "응용·실전" : "기본") 5지선다 문제 \(count)개를 만들어줘. 정답이 하나뿐이도록 하고, 단계별 풀이를 꼭 검산해."
    }

    static func solutionPrompt(problem: String) -> String {
        "다음 문제를 서술형 모범 답안처럼 단계별로 풀어줘. 각 단계는 생각할 점(힌트)과 풀이 식으로 나눠.\n\n문제:\n\(problem)"
    }
}
