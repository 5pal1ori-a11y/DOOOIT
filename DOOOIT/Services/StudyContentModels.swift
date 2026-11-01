import Foundation

// MARK: - 두잇 AI가 만드는 학습 자료 형식 (기기에 JSON으로 저장)

struct ConceptNote: Codable {
    var title: String
    var keyPoints: [String]
    var example: String
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
    var hint: String
    var work: String
}

struct WrittenSolution: Codable {
    var concept: String
    var steps: [SolutionStep]
    var finalAnswer: String
}

struct SimilarProblem: Codable, Hashable {
    var question: String
    var answer: String
    var explanation: String
}

struct SimilarProblemSet: Codable {
    var problems: [SimilarProblem]
}
