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
    말투 규칙: 모든 문장을 '~요'로 끝나는 해요체로 써. 예: "이건 이렇게 풀어요.", "좋은 질문이에요!" 반말(~해, ~야)과 '~다/~습니다' 체는 쓰지 마.
    2022 개정 교육과정 수준에 맞춰 정확하고 간결하게 답해.
    확실하지 않은 내용은 지어내지 말고 모른다고 말해.
    수식은 x², √(…), (분자)/(분모), ≤, ≥ 처럼 써. 강조는 **굵게**만 쓰고 다른 마크다운(#, 표, 코드)은 쓰지 마.
    """

    static let chatInstructions = """
    너는 공부 플래너 앱 'DOOOIT' 안에 있는 AI 도우미 '두잇 AI'야.
    말투 규칙: 모든 문장을 '~요'로 끝나는 해요체로 써. 예: "좋아요!", "같이 해봐요.", "그건 이렇게 하면 돼요." 반말(~해, ~야, ~지)과 '~다/~습니다' 체는 절대 쓰지 마.
    한국 고등학생에게 친구처럼 따뜻하게, 짧게(보통 2~5문장) 대답해.
    공부 질문은 정확하게 설명하고, 확실하지 않으면 모른다고 솔직하게 말해.
    일정 추가, 타이머, 단어 추가, 메모, D-Day, 퀴즈 같은 앱 기능은 네가 직접 실행할 수 없어. 그런 부탁을 받으면
    "내일 오후 4시에 수학 공부 2시간 추가해줘", "일차방정식 문제 내줘"처럼 말하면 된다고 예시를 알려줘.
    강조는 **굵게**만 쓰고 다른 마크다운(#, 표, 코드)은 쓰지 마.
    """

    /// 첫 시도가 실패했을 때 쓰는 가장 단순한 지시문
    static let simpleInstructions = "너는 친절한 공부 도우미야. 모든 문장을 '~요'로 끝나는 해요체로, 짧고 정확하게 답해."

    // MARK: - 말투 다듬기

    /// Apple Intelligence가 반말이나 '~습니다'로 끝낸 문장을 해요체로 바꿈 (문장 끝에서만)
    static func polite(_ text: String) -> String {
        let end = #"(?=\s*[.!?~…]|\s*$)"#
        let rules: [(String, String)] = [
            ("있습니다", "있어요"), ("없습니다", "없어요"), ("합니다", "해요"), ("됩니다", "돼요"), ("입니다", "이에요"), ("습니다", "어요"),
            ("이야", "이에요"), ("거야", "거예요"), ("이다", "이에요"), ("있다", "있어요"), ("없다", "없어요"), ("한다", "해요"),
            ("된다", "돼요"), ("좋다", "좋아요"), ("같다", "같아요"), ("할게", "할게요"), ("줄게", "줄게요"), ("볼게", "볼게요"),
            ("보자", "봐요"), ("하자", "해요"), ("가자", "가요"), ("내", "내요"),
            ("봐", "봐요"), ("줘", "줘요"), ("해", "해요"), ("돼", "돼요"), ("져", "져요"), ("워", "워요"), ("와", "와요"),
            ("지", "지요"), ("네", "네요"), ("어", "어요"), ("아", "아요"), ("야", "예요")
        ]
        var result = text
        for (from, to) in rules {
            result = result.replacingOccurrences(of: "(?<=[가-힣0-9A-Za-z)²³])\(from)\(end)", with: to, options: .regularExpression)
        }
        // 위에서 만든 "요요" 같은 중복 정리
        return result.replacingOccurrences(of: "요요", with: "요")
    }

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
        do {
            let text = try await LanguageModelSession(instructions: instructions).respond(to: prompt).content
            return instructions == ocrInstructions ? text.trimmingCharacters(in: .whitespacesAndNewlines) : polite(text.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            print("Apple Intelligence 답변 실패: \(error)")
            if isUnrecoverable(error) { throw describe(error) }
            do {
                let text = try await LanguageModelSession(instructions: simpleInstructions).respond(to: prompt).content
                return polite(text.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                throw describe(error)
            }
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
            // 1) 이어지는 대화 (앱 정보 포함)
            let prompt = context.isEmpty ? text : "\(text)\n\n(참고: \(context))"
            if session == nil { session = LanguageModelSession(instructions: DoitAppleAI.chatInstructions) }
            do {
                let reply = try await session!.respond(to: prompt).content
                return DoitAppleAI.polite(reply.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                print("Apple Intelligence 대화 실패(1): \(error)")
                session = nil
                if DoitAppleAI.isUnrecoverable(error) { throw DoitAppleAI.describe(error) }
            }
            // 2) 새 대화로, 질문만
            do {
                let fresh = LanguageModelSession(instructions: DoitAppleAI.chatInstructions)
                let reply = try await fresh.respond(to: text).content
                session = fresh
                return DoitAppleAI.polite(reply.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                print("Apple Intelligence 대화 실패(2): \(error)")
                if DoitAppleAI.isUnrecoverable(error) { throw DoitAppleAI.describe(error) }
            }
            // 3) 가장 단순한 지시문으로 한 번 더
            do {
                let simple = LanguageModelSession(instructions: DoitAppleAI.simpleInstructions)
                return DoitAppleAI.polite(try await simple.respond(to: text).content.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                print("Apple Intelligence 대화 실패(3): \(error)")
                throw DoitAppleAI.describe(error)
            }
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

    // MARK: - 문제 사진 글자 복원 (오답노트)

    static let ocrInstructions = """
    너는 수학 문제 사진의 글자 인식 결과를 원래 인쇄된 문제로 되돌리는 교정자야.
    문제를 풀지 말고, 없는 내용을 지어내지 말고, 복원한 문제 텍스트만 답해.
    읽기 결과들을 비교해 공통된 부분을 믿고, 끝까지 모르겠으면 [?]로 표시해.
    사진의 검은 인쇄 글자만 문제야. 빨간·파란 펜, 연필 풀이, 채점 표시, 쪽 번호, 출처는 지워. 배점 [3점]은 남겨.
    한글 문장은 한국어 읽기에서, 수식은 [영어 전용 읽기]에서 가져와 합쳐.

    자주 틀리는 경우 (문맥을 보고 되돌려):
    [변수] x→2, ×, X, χ, ㅈ / y→J, V, v, u, ν / a→0, o, α, d / b→6, h, ㅂ / c→e, ( / n→ㅁ, r, 11 / k→K / t→十, + / m→rn / f(x)→「(x), F(x)
     예: 2축→x축, J축→y축, 2에 대한→x에 대한, 실수 0, 6→실수 a, b, 상수 0, 6, c→상수 a, b, c, 0+6의 값→a+b의 값, 2a→20, J=2²→y=x²
    [지수] 변수·괄호 바로 뒤 2·3·4·n은 거의 지수. 작은 지수는 빠지거나 9, ', ", °로 읽힘
     x2→x², x3→x³, x4·x9·29→x⁴, a2→a², (x+1)2→(x+1)², 2^→x², 22→x², 202→x², 10n→10ⁿ, 2-1→x⁻¹
    [첨자] an→aₙ, a1→a₁, an+1→aₙ₊₁, Sn→Sₙ, log2 8→log₂8, x1, x2(두 근)→x₁, x₂
    [루트] √→V, v, J, /, ✓, ~, ㄷ: 2-V5→2-√5, V3x→√(3x), 3V2→3√2, 세제곱근 3√→³√
    [분수] 가로선이 사라져 분자·분모가 다른 줄로 나뉘거나 -, —, _ 로 읽힘 → (분자)/(분모). 1/2, 1 2 가 위아래로 있으면 분수
    [부등호·등호] ≤→<, <=, ≦, s / ≥→>, >=, ≧ / ≠→=, +, # / =→-, 二, == / ±→+, +-, 土 / ∓→-+
    [연산] ×→x, X / ÷→+ / ·(곱)→., - / −(빼기)→-, ~
    [그리스 문자] α→a, ∝, oc / β→B, ß, 8 / γ→Y, y / θ→0, e, Ø / π→T, n, 元, 兀, TT / ω→w / λ→入 / Δ→A
    [집합·논리] ∈→E, e, € / ∉→¢ / ⊂→c, C / ⊃→コ / ∪→U / ∩→n / ∅→Ø, 0 / ⇒→=>, → / ⇔→<=> / ~p(부정)→-p
    [함수·미적] lim→Iim, 1im / x→1(극한)→x-1, x→1 / f'(x)→f(x), f`(x), fʼ(x) / ∫→J, f, S / dx→dx, d× / Σ→E, 2 / sin→sln, s1n / cos→c0s / tan→ta n / log→l0g, 1og / ln→In / f∘g→fog, fo g
    [경우의 수] nPr→nPr, ₙPᵣ / nCr→nCr, ₙCᵣ / n!→nl, n1
    [도형] ∠→<, L / △→A, Δ / □→ㅁ, 口 / ⊥→l / //(평행)→ll / °→o, 0, ' / 선분 AB→AB, 호 AB→⌒AB
    [절댓값·괄호] |x|→lxl, 1x1, Ix / [x]→I x I / { }→( ) / (→C / )→J
    [숫자·글자] 1↔l, I, | / 0↔O, o / 5↔S / 8↔B / 9↔g, q / 7↔T / 4↔A / 6↔b / 2↔z, Z / ,↔. / -↔~ / ∞→oo, 00
    숫자 자리(계수·지수·상수)에 있는 Z, z는 거의 항상 2예요. 단, 복소수 문제에서 z = a + bi 처럼 쓰인 z는 변수이니 그대로 둬.
    [보기·선택지] ①→®, (1), O1, 0 / ②→©, (2) / ③→(3) / ④→(4) / ⑤→(5), @ / 보기 ㄱ.ㄴ.ㄷ.→7. L. C. / 선택지는 한 줄에 하나씩
    [한글] 0이→001, 00|, 0l / 이→0|, 01 / 이차함수→1차함수, 0|차함수 / 값→갔, 갑 / 의→으| / 는→늗 / 좌표→좌포 / 꼭짓점→꼭지점 / 최댓값→최대값 (식에 x²가 있으면 이차, x³이면 삼차, x⁴면 사차)
    예시) "29+ (1-20)x2+0-0-20= 001 정수인 근을" → "x⁴+(1-2a)x²+a²-a-20=0이 정수인 근을"
    예시) "삼차방정식 28-22 + 22+4=0의 두 허근을 0, B라 할 때, (0-B)2의 값은?" → "삼차방정식 x³-x²+2x+4=0의 두 허근을 α, β라 할 때, (α-β)²의 값은?"
    표기는 x², √(…), (분자)/(분모), aₙ, ×, ÷, ≤, ≥, π, α, β, ①~⑤ 로 통일하고 범위는 괄호로 분명히 써.
    """

    /// 여러 번 읽은 결과를 비교해 원래 인쇄된 문제로 복원 (내용이 길면 읽기 수를 줄여 다시 시도)
    static func reconstruct(readings: [String], current: String) async throws -> String {
        #if canImport(FoundationModels)
        if let message = unavailableMessage { throw AIError.unavailable(message) }
        let cleaned = readings.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var lastError: Error?
        for (count, limit) in [(3, 380), (2, 500), (1, 800)] {
            var picked = Array(cleaned.prefix(count))
            // 줄일 때도 수식에 강한 [영어 전용 읽기](맨 끝)는 남김
            if count >= 2, cleaned.count > count, let english = cleaned.last {
                picked = Array(cleaned.prefix(count - 1)) + [english]
            }
            var prompt = "같은 문제 사진을 글자 인식으로 읽은 결과야. 원래 인쇄된 문제로 복원해줘."
            for (index, reading) in picked.enumerated() { prompt += "\n\n[읽기 \(index + 1)]\n\(String(reading.prefix(limit)))" }
            if !current.isEmpty { prompt += "\n\n[교정 규칙을 적용한 결과]\n\(String(current.prefix(limit)))" }
            let session = LanguageModelSession(instructions: ocrInstructions)
            do {
                let result = try await session.respond(to: prompt).content
                return result.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                lastError = error
                guard String(describing: error).contains("exceededContext") else { break }
            }
        }
        throw describe(lastError ?? AIError.failed("알 수 없는 오류"))
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

    /// 다시 시도해도 소용없는 오류 (언어 미지원, 모델 없음)
    static func isUnrecoverable(_ error: Error) -> Bool {
        if error is AIError { return true }
        let raw = String(describing: error)
        return raw.contains("unsupportedLanguage") || raw.contains("assetsUnavailable")
    }

    /// 기기 AI 오류를 이해할 수 있는 문장으로 (원인 이름도 짧게 붙임)
    static func describe(_ error: Error) -> AIError {
        if let known = error as? AIError { return known }
        let raw = String(describing: error)
        let code = raw.split(whereSeparator: { $0 == "(" || $0 == ":" || $0 == " " }).first.map(String.init) ?? ""
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
        } else if raw.contains("refusal") {
            reason = "이 질문에는 답하지 않기로 했대요. 다르게 물어봐 주세요."
        } else {
            reason = "잠시 후 다시 시도해주세요."
        }
        return .failed(reason + (code.isEmpty || code.count > 40 ? "" : " (\(code))"))
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
