import Foundation

// 사진 테스트 한 건의 정답 (생성기가 쓰고, 실행기가 읽음)

struct WordPair: Codable {
    var term: String
    /// 뜻의 핵심 (읽은 뜻에 이 글이 들어 있으면 맞음, 띄어쓰기 무시)
    var meaning: String
}

struct Expectation: Codable {
    /// 보기 (순서대로). nil이면 검사 안 함, []이면 보기가 없어야 함
    var choices: [String]?
    /// 빈칸 □이 있어야 하는지
    var blank: Bool?
    /// 읽은 글에 들어 있어야 할 수식 조각 (띄어쓰기 무시, ²→^2)
    var tokens: [String] = []
    /// 읽은 글에 들어 있어야 할 문장 조각 (띄어쓰기 무시)
    var phrases: [String] = []
    /// 단어장: 찾아야 할 단어·뜻
    var words: [WordPair] = []
    /// 단어장: 단어로 잡히면 안 되는 낱말 (유의어·제목)
    var notTerms: [String] = []
}

struct CaseSpec: Codable {
    var id: String
    /// 분류 (math-choice, math-short, math-blank, math-fraction, korean, english, science, social, words …)
    var category: String
    /// "problem" (문제 읽기 + 나누기) 또는 "words" (단어장)
    var kind: String
    /// 사진 손상 정도 (clean, mild, photo, lowres, desk)
    var degrade: String
    var image: String
    var expect: Expectation
}
