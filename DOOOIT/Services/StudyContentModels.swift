import Foundation

// MARK: - 두잇 AI가 만드는 학습 자료 형식 (기기에 JSON으로 저장)

struct ConceptNote: Codable {
    var title: String
    /// 핵심 학습 포인트
    var keyPoints: [String]
    /// 예제 (풀이·답 포함)
    var example: String
    /// 핵심 개념 설명 (한두 문장)
    var summary: String = ""
    /// 이해하기 쉬운 상세 설명 (개념마다 한 문단)
    var details: [String] = []
    /// 학습 범위 (예: "중3 수학 · 이차방정식")
    var scope: String = ""
    /// 근거 자료
    var sources: [String] = []
    /// 통과한 검증 (예: "단원 일치", "자료 근거")
    var checks: [String] = []

    init(title: String, keyPoints: [String], example: String, summary: String = "", details: [String] = [],
         scope: String = "", sources: [String] = [], checks: [String] = []) {
        self.title = title
        self.keyPoints = keyPoints
        self.example = example
        self.summary = summary
        self.details = details
        self.scope = scope
        self.sources = sources
        self.checks = checks
    }

    // 예전에 저장한 자료(title·keyPoints·example만 있음)도 읽을 수 있게
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        keyPoints = try c.decode([String].self, forKey: .keyPoints)
        example = try c.decodeIfPresent(String.self, forKey: .example) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        details = try c.decodeIfPresent([String].self, forKey: .details) ?? []
        scope = try c.decodeIfPresent(String.self, forKey: .scope) ?? ""
        sources = try c.decodeIfPresent([String].self, forKey: .sources) ?? []
        checks = try c.decodeIfPresent([String].self, forKey: .checks) ?? []
    }
}

struct ClozeItem: Codable {
    var sentence: String
    var answer: String
}

struct ClozeSet: Codable {
    var items: [ClozeItem]
}

struct OXItem: Codable {
    var statement: String
    var isTrue: Bool
    var explanation: String
}

struct OXSet: Codable {
    var items: [OXItem]
}

struct Problem: Codable {
    var question: String
    var choices: [String]
    var answerNumber: Int
    var steps: [String]
    var finalAnswer: String
}

struct ProblemSet: Codable {
    var items: [Problem]
}

struct SolutionStep: Codable {
    /// 이 단계에서 할 일
    var hint: String
    /// 계산·풀이 과정
    var work: String
    /// 쓰는 개념이나 공식 (확실할 때만)
    var concept: String = ""
    /// 왜 이렇게 하는지 (확실할 때만)
    var reason: String = ""
    /// 다음 단계로 이어지는 말
    var next: String = ""
}

// 예전에 저장한 풀이(hint·work만 있음)도 읽을 수 있게 (extension에 두어야 SolutionStep(hint:work:)도 그대로 쓸 수 있음)
extension SolutionStep {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hint = try c.decodeIfPresent(String.self, forKey: .hint) ?? ""
        work = try c.decodeIfPresent(String.self, forKey: .work) ?? ""
        concept = try c.decodeIfPresent(String.self, forKey: .concept) ?? ""
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
        next = try c.decodeIfPresent(String.self, forKey: .next) ?? ""
    }
}

struct WrittenSolution: Codable {
    var concept: String
    var steps: [SolutionStep]
    var finalAnswer: String
    /// 누가 풀었는지 ("engine" 풀이 엔진 · "model" 두잇 1·2) — 예전 풀이는 nil
    var source: String? = nil
    /// 풀 때의 문제 글 (문제 글을 고치면 다시 풂)
    var problem: String? = nil
}

struct SimilarProblem: Codable, Hashable {
    var question: String
    var answer: String
    var explanation: String
}

struct SimilarProblemSet: Codable {
    var problems: [SimilarProblem]
}
