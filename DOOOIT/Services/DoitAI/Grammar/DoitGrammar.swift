import Foundation

/// 영어 문법 단원 (초등 ~ 고등, 교과서 순서): 개념 정리 + 검증된 연습 문제
/// - 문제는 손으로 쓴 것과, 표로 확인하는 틀(3인칭 단수 · 과거형 · 비교급 · 복수형)로 만든 것만 써요
/// - 모델·인터넷을 쓰지 않아서 늘 같은 내용이에요 (AI 학습 화면 · 모의고사에서 씀)
/// - 문제 하나에 정답은 하나: 오답 보기를 넣은 문장은 어법상 틀린 문장이어야 해요 (뜻으로 고르는 문제는 ko에 해석)
struct GrammarItem: Hashable {
    enum Kind: String, CaseIterable {
        /// 빈칸 고르기 (객관식 · 빈칸 쓰기)
        case blank
        /// 문장 전환 (능동 ↔ 수동 등): 바꾼 문장의 빈칸
        case transform
        /// 영어 문장이 어법상 맞는지
        case ox
        /// 규칙 설명(한국어)이 맞는지
        case rule
        /// 틀린 곳 찾아 고치기
        case fix
        /// 낱말 배열 (정답은 문장 하나)
        case order
        /// 해석 고르기
        case meaning
    }

    let kind: Kind
    /// 문장 (빈칸은 "___"). transform은 바꾼 문장, fix는 틀린 문장, rule은 한국어 설명
    let text: String
    /// 정답 (ox·rule은 "O" 또는 "X", fix는 고친 표현, order는 문장)
    let answer: String
    /// 오답 보기 (fix는 [틀린 부분])
    let wrong: [String]
    /// 한 줄 해설
    let note: String
    /// 빈칸 쓰기에서 보여 줄 힌트 (동사원형 등)
    var hint: String? = nil
    /// transform: 원래 문장과 할 일
    var from: String? = nil
    var instruction: String? = nil
    /// 해석 (뜻으로 고르는 빈칸: 오답을 넣은 문장도 어법상은 맞을 수 있어서 O/X로 쓰지 않음)
    var ko: String? = nil
    /// 같이 인정하는 답 (축약형 등)
    var alternatives: [String] = []
    /// fix: 틀린 곳 찾기 보기에 넣지 않을 낱말 (다르게 고쳐도 맞는 말이 될 수 있는 곳)
    var avoid: [String] = []
    /// 표로 만든 문제
    var templated = false
}

struct GrammarUnit {
    let level: SchoolLevel
    /// 단원 이름 (검색·목록에 그대로)
    let name: String
    /// 학년·학기 (학년 × 10 + 학기)
    let grades: [Int]
    /// 다른 이름 (검색용)
    let aliases: [String]
    let summary: String
    let points: [String]
    /// "영어 문장 → 해석"
    let examples: [String]
    /// 자주 틀리는 곳
    let traps: [String]
    var items: [GrammarItem]
    /// 이 단원 문제를 함께 쓰는 다른 단원 ("고등학교 영어|도치와 강조", "공통영어|가정법")
    var covers: [String] = []

    /// 교육과정 과목 이름 ("초등 영어", "중학교 영어", "고등학교 영어")
    var subjectName: String { "\(level.rawValue) 영어" }
    var key: String { subjectName + "|" + name }
}

enum DoitGrammar {
    // MARK: - 단원 목록

    /// 모든 문법 단원 (표로 만든 문제까지 붙여서)
    static let units: [GrammarUnit] = {
        var list = elementaryUnits + middleUnits + middleUnits2 + highUnits
        let extra = templatedItems()
        for index in list.indices {
            list[index].items += extra[list[index].key] ?? []
        }
        return list
    }()

    /// 단원 하나 (과목 이름 + 단원 이름)
    static func unit(subjectName: String, name: String) -> GrammarUnit? {
        units.first { $0.subjectName == subjectName && $0.name == name }
    }

    /// 학습 범위에 맞는 문법 단원 (그 단원 자체 또는 그 단원을 함께 쓰는 단원들)
    static func units(for scope: StudyScope) -> [GrammarUnit] {
        guard scope.subject == "영어" else { return [] }
        return units(subjectName: scope.subjectName, unit: scope.unit)
    }

    static func units(subjectName: String, unit: String) -> [GrammarUnit] {
        if let own = self.unit(subjectName: subjectName, name: unit) { return [own] }
        let key = subjectName + "|" + unit
        return units.filter { $0.covers.contains(key) }
    }

    /// 단원 이름·다른 이름으로 찾기 (오답노트·모의고사의 "영어 · 현재완료" 같은 글)
    static func find(_ text: String) -> [GrammarUnit] {
        let q = squash(text)
        guard q.count >= 2 else { return [] }
        let exact = units.filter { ([$0.name] + $0.aliases).contains { squash($0) == q } }
        if !exact.isEmpty { return exact }
        return units.filter { ([$0.name] + $0.aliases).contains { squash($0).count >= 3 && q.contains(squash($0)) } }
    }

    static func squash(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace && !"·,./()'\"?!~-+「」".contains($0) }
    }

    // MARK: - 문장 만들기 (검증용)

    static let blankMark = "___"

    /// 정답을 넣은 (어법상 바른) 영어 문장들
    static func correctSentences(_ item: GrammarItem) -> [String] {
        switch item.kind {
        case .blank, .transform: return [filled(item.text, item.answer)]
        case .fix: return [corrected(item)].compactMap { $0 }
        case .ox: return item.answer == "O" ? [item.text] : []
        case .order, .meaning: return [item.text]
        case .rule: return []
        }
    }

    /// 어법상 틀린 영어 문장들 (빈칸에 오답을 넣은 것 · 고치기 전 문장 · X 문장)
    static func wrongSentences(_ item: GrammarItem) -> [String] {
        switch item.kind {
        case .blank, .transform: return item.ko == nil ? item.wrong.map { filled(item.text, $0) } : []
        case .fix: return [item.text]
        case .ox: return item.answer == "X" ? [item.text] : []
        default: return []
        }
    }

    static func filled(_ text: String, _ word: String) -> String {
        var t = text.replacingOccurrences(of: blankMark, with: word)
        // 빈칸에 아무것도 넣지 않는 보기("×")는 빈칸 앞뒤 띄어쓰기 정리
        t = t.replacingOccurrences(of: "  ", with: " ")
        return t
    }

    /// 틀린 부분을 고친 문장 (틀린 부분이 문장에 한 번만 나와야 함)
    static func corrected(_ item: GrammarItem) -> String? {
        guard item.kind == .fix, let part = item.wrong.first, let range = wordRange(of: part, in: item.text) else { return nil }
        var t = item.text
        t.replaceSubrange(range, with: item.answer)
        return t.replacingOccurrences(of: "  ", with: " ")
    }

    /// 낱말 경계에 맞는 위치 (부분 글자에 잘못 맞지 않게)
    static func wordRange(of part: String, in text: String) -> Range<String.Index>? {
        var search = text.startIndex..<text.endIndex
        var found: [Range<String.Index>] = []
        while let r = text.range(of: part, range: search) {
            let before = r.lowerBound == text.startIndex ? " " : text[text.index(before: r.lowerBound)]
            let after = r.upperBound == text.endIndex ? " " : text[r.upperBound]
            if !before.isLetter && !after.isLetter && before != "'" { found.append(r) }
            search = r.upperBound..<text.endIndex
        }
        return found.count == 1 ? found[0] : nil
    }

    /// 문장 낱말 (문장부호 뺌)
    static func tokens(_ sentence: String) -> [String] {
        sentence.split(separator: " ").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"“”")) }.filter { !$0.isEmpty }
    }

    // MARK: - 늘 같은 순서로 섞기

    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        init(_ text: String) {
            var h: UInt64 = 0xcbf29ce484222325
            for b in text.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
            state = h
        }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    static func seededShuffle<T>(_ list: [T], seed: String) -> [T] {
        var rng = Seeded(seed)
        return list.shuffled(using: &rng)
    }

    /// 배열 문제의 섞은 낱말 (원래 순서와 다르게)
    static func scrambled(_ item: GrammarItem) -> [String] {
        var words = tokens(item.text)
        let original = words
        var seed = item.text
        for _ in 0..<6 where words == original {
            words = seededShuffle(original, seed: seed)
            seed += "+"
        }
        if words == original { words = Array(original.reversed()) }
        return words
    }
}
