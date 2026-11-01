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

    /// 글자 인식 결과 복원 전용 지시문: 수학 문제에서 자주 나오는 잘못 읽기 경우를 전부 알려줌
    static let ocrInstructions = """
    너는 수학 문제 사진의 글자 인식 결과를 원래 인쇄된 문제로 되돌리는 교정자야.
    문제를 풀지 말고, 없는 내용을 지어내지 말고, 복원한 문제 텍스트만 답해.
    여러 읽기 결과가 있으면 서로 비교해 공통된 부분을 믿어. 끝까지 모르겠으면 [?]로 표시해.
    손글씨 풀이, 채점 표시, 낙서, 쪽 번호, 출처 문구는 지워. 배점 [3점] [4점]은 남겨.
    한글 문장은 한국어 읽기 결과에서, 수식은 [영어 전용 읽기] 결과에서 가져와 합쳐.

    자주 틀리는 경우 (문맥을 보고 되돌려):
    [기울어진 변수] x→2, ×, X, χ, ㅈ / y→J, V, v, u, ν / a→0, o, α, d, ㅁ / b→6, h, ㅂ / n→ㅁ, r / k→K, 片 / t→十, + / f(x)→「(x), F(x), ƒ / m→rn
     예: 2축→x축, J축→y축, J=2²→y=x², 실수 0, 6→실수 a, b, 0+6의 값→a+b의 값, 2+J→x+y, 2²→x², 22+1→x²+1
    [지수] 변수 바로 뒤 2·3은 대부분 지수: x2→x², x3→x³, (x+1)2→(x+1)², 2^→², 10의 n제곱 10n→10ⁿ
    [첨자] 수열 an→aₙ, a1→a₁, an+1→aₙ₊₁, Sn→Sₙ, log2 8→log₂8
    [루트] √→V, v, J, /, ✓, ~, ㄷ: 2-V5→2-√5, V3x→√(3x), 3V2→3√2
    [분수] 가로선이 사라져 분자·분모가 다른 줄로 나뉘거나 -, —, _ 로 읽힘 → (분자)/(분모)
    [기호] ±→+, 土 / ×→x / ÷→+ / ≤→<, ≦, s / ≥→>, ≧ / ≠→= / =→-, 二, == / π→T, n, 元, 兀 / ∠→<, L / △→A, Δ / °→o, 0 / |x|→lxl, 1x1, Ix / ∞→oo, 00 / ∑→E, Σ, 2 / ∫→J, f, S / lim→Iim, 1im / sin→sln, s1n / cos→c0s / log→l0g, 1og / ≡→三
    [숫자·글자] 1↔l, I, | / 0↔O, o / 5↔S / 8↔B / 9↔g, q / 7↔T / 4↔A / ,↔. / -↔~
    [보기·선택지] ①→®, (1), O1, 0 / ②→©, (2) / ③→(3) / ④→(4) / ⑤→(5), @ / 보기 ㄱ. ㄴ. ㄷ.→7. L. C. 또는 ᄀ. ᄂ. ᄃ.  선택지는 한 줄에 하나씩
    [한글] 이차함수→1차함수, 0|차함수 / 값→갔, 갑 / 의→으| / 이→0|, 01 / 는→늗 / 좌표→좌포 / 꼭짓점→꼭지점 / 최댓값→최대값 (식에 x²가 있으면 이차함수)
    [괄호] (→C, ( / )→), J / [ ]→I I / { }→( )
    표기는 x², √(…), (분자)/(분모), aₙ, ×, ÷, ≤, ≥, π, ①~⑤ 로 통일하고 범위는 괄호로 분명히 써.
    """

    /// 여러 번 읽은 결과를 기기 AI가 비교해 원래 문제로 복원. 길면 읽기 수를 줄여 다시 시도
    static func reconstruct(readings: [String], current: String) async throws -> String {
        if let message = unavailableMessage { throw AITutorError.unavailable(message) }
        let cleaned = readings.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var attempts: [(count: Int, limit: Int)] = [(4, 450), (2, 600), (1, 900)]
        attempts = attempts.filter { $0.count <= max(cleaned.count, 1) || $0.count == 1 }
        var lastError: Error?
        for attempt in attempts {
            let prompt = reconstructPrompt(readings: Array(cleaned.prefix(attempt.count)), current: current, limit: attempt.limit)
            let session = LanguageModelSession(instructions: ocrInstructions)
            do {
                let result = try await session.respond(to: prompt).content
                return MathOCRFixer.fix(result.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                print("AI 복원 실패(\(attempt.count)개): \(error)")
                lastError = error
                guard String(describing: error).contains("exceededContext") else { break }
            }
        }
        throw AITutorError.describe(lastError ?? AITutorError.failed("알 수 없는 오류"))
    }

    static func reconstructPrompt(readings: [String], current: String, limit: Int) -> String {
        var text = "같은 문제 사진을 글자 인식으로 읽은 결과야. 원래 인쇄된 문제로 복원해줘."
        for (index, reading) in readings.enumerated() {
            text += "\n\n[읽기 \(index + 1)]\n\(String(reading.prefix(limit)))"
        }
        if !current.isEmpty && !readings.contains(current) {
            text += "\n\n[지금 저장된 텍스트]\n\(String(current.prefix(limit)))"
        }
        return text
    }

    static func solutionPrompt(problem: String) -> String {
        "다음 문제를 서술형 모범 답안처럼 단계별로 풀어줘. 각 단계는 생각할 점(힌트)과 풀이 식으로 나눠.\n\n문제:\n\(problem)"
    }
}
