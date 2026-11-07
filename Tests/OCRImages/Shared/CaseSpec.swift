import Foundation

// 사진 테스트 한 건의 정답 (생성기가 쓰고, 실행기가 읽음)

/// 사진 이름 필터: 부분 일치. 앞에 !를 붙이면 그 글이 든 사진을 뺌.
/// 쉼표로 이으면 모두 만족 (!hw-,m- = 필기 사진 빼고 m-), 세로줄(|)로 이으면 하나라도 만족 (m-|g-)
func idMatches(_ id: String, filter: String) -> Bool {
    if filter.isEmpty { return true }
    return filter.split(separator: "|").contains { group in
        group.split(separator: ",").allSatisfy { term in
            term.hasPrefix("!") ? !id.contains(term.dropFirst()) : id.contains(term)
        }
    }
}

struct WordPair: Codable {
    var term: String
    /// 뜻의 핵심 (읽은 뜻에 이 글이 들어 있으면 맞음, 띄어쓰기 무시)
    var meaning: String
}

/// 미적분 기호 검사 한 건: 기호 종류(∑, ∫, lim, ′ …)와 읽어야 할 조각 (";"로 같은 뜻의 다른 표기, 띄어쓰기·중괄호 무시)
struct CalcToken: Codable {
    var cls: String
    var text: String
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
    /// <보기> ㄱ. ㄴ. ㄷ. 항목 (DoitProblemScan.boxItems, 띄어쓰기 무시)
    var boxItems: [String]? = nil
    /// 학생 필기 사진: 읽은 글에 섞이면 안 되는 필기 글 (띄어쓰기 무시, "|"는 또는). nil이면 필기 사진 아님
    var leaks: [String]? = nil
    /// 학생이 써 넣은 답 (읽은 글에서 정답 표기로 잡히면 안 됨)
    var handAnswer: String? = nil
    /// 미적분 기호 검사 (기호 종류별 정확도를 따로 셈)
    var calc: [CalcToken]? = nil
}

struct CaseSpec: Codable {
    var id: String
    /// 분류 (math-choice, math-short, math-blank, math-fraction, korean, english, science, social, words …)
    var category: String
    /// "problem" (수학 문제 읽기 + 나누기), "subject" (국어·영어·과학·사회: SubjectOCR), "words" (단어장)
    var kind: String
    /// 사진 손상 정도 (clean, mild, photo, lowres, desk)
    var degrade: String
    var image: String
    var expect: Expectation
}
