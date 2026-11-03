import Foundation

// MARK: - 과목 풀이 더하기: 국어 문법 (음운 변동 · 표준 발음 · 높임법)
// - 음운 변동은 받침과 다음 첫소리로 정해지는 규칙만 써요. 말에 따라 달라지는 것(사잇소리·ㄴ 첨가·용언 어간 뒤 된소리·한자어 ㄹ 뒤 된소리 ·
//   ㄹ의 비음화와 유음화가 갈리는 말)은 "그럴 수도 있음"으로 두고, 답이 그것에 달려 있으면 풀지 않아요

extension DoitSubjectSolve {
    // MARK: 한글 나누기

    private static let initials: [Character] = ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
    private static let finals: [Character?] = [nil, "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]

    struct Syllable: Equatable {
        var initial: Character
        var vowel: Int
        var final: Character?
    }

    static func syllables(_ word: String) -> [Syllable]? {
        var out: [Syllable] = []
        for ch in word {
            guard let v = ch.unicodeScalars.first?.value, ch.unicodeScalars.count == 1, (0xAC00...0xD7A3).contains(v) else { return nil }
            let index = Int(v - 0xAC00)
            out.append(Syllable(initial: initials[index / 588], vowel: (index % 588) / 28, final: finals[index % 28]))
        }
        return out
    }

    static func compose(_ s: [Syllable]) -> String {
        String(s.compactMap { syl -> Character? in
            guard let l = initials.firstIndex(of: syl.initial) else { return nil }
            let t = finals.firstIndex(where: { $0 == syl.final }) ?? 0
            return Character(Unicode.Scalar(UInt32(0xAC00 + l * 588 + syl.vowel * 28 + t))!)
        })
    }

    /// 음운 변동 분석 결과
    struct SoundChange {
        /// 반드시 일어나는 변동
        var certain: Set<String> = []
        /// 말에 따라 일어날 수도 있는 변동 (사잇소리·ㄴ 첨가 …)
        var possible: Set<String> = []
        /// 표준 발음 (그럴 수도 있는 변동이 없을 때만)
        var pronunciation: String?
    }

    /// 낱말 하나의 음운 변동 (두세 글자 낱말, 겹받침이 있으면 nil)
    static func soundChanges(_ word: String) -> SoundChange? {
        guard var s = syllables(word), s.count >= 1, s.count <= 4 else { return nil }
        var result = SoundChange()
        let double: Set<Character> = ["ㄳ", "ㄵ", "ㄶ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅄ"]
        guard !s.contains(where: { $0.final.map(double.contains) ?? false }) else { return nil }
        let iVowels: Set<Int> = [20, 2, 6, 12, 17]   // ㅣ ㅑ ㅕ ㅛ ㅠ
        func neutral(_ c: Character) -> Character {
            switch c {
            case "ㄲ", "ㅋ": return "ㄱ"
            case "ㅅ", "ㅆ", "ㅈ", "ㅊ", "ㅌ": return "ㄷ"
            case "ㅍ": return "ㅂ"
            default: return c
            }
        }
        func tense(_ c: Character) -> Character? { ["ㄱ": "ㄲ", "ㄷ": "ㄸ", "ㅂ": "ㅃ", "ㅅ": "ㅆ", "ㅈ": "ㅉ"][c] }
        for i in 0..<(s.count - 1) {
            guard let f = s[i].final else { continue }
            let next = s[i + 1].initial
            if next == "ㅇ" {
                if f == "ㅎ" { s[i].final = nil; result.certain.insert("ㅎ 탈락"); continue }
                if f == "ㅇ" { continue }
                if (f == "ㄷ" || f == "ㅌ"), s[i + 1].vowel == 20 {
                    s[i].final = nil; s[i + 1].initial = f == "ㄷ" ? "ㅈ" : "ㅊ"; result.certain.insert("구개음화"); continue
                }
                if iVowels.contains(s[i + 1].vowel) { result.possible.formUnion(["ㄴ 첨가", "비음화", "유음화"]) }
                s[i].final = nil; s[i + 1].initial = f; result.certain.insert("연음"); continue
            }
            if next == "ㅎ" {
                let n = neutral(f)
                let aspirated: [Character: Character] = ["ㄱ": "ㅋ", "ㄷ": "ㅌ", "ㅂ": "ㅍ"]
                if f == "ㅈ" { s[i].final = nil; s[i + 1].initial = "ㅊ"; result.certain.insert("거센소리되기"); continue }
                if let a = aspirated[n] {
                    s[i].final = nil
                    // ㄷ + 히 → 치 (구개음화)
                    if n == "ㄷ", s[i + 1].vowel == 20 { s[i + 1].initial = "ㅊ"; result.certain.formUnion(["거센소리되기", "구개음화"]) }
                    else { s[i + 1].initial = a; result.certain.insert("거센소리되기") }
                    continue
                }
                if ["ㄴ", "ㄹ", "ㅁ", "ㅇ"].contains(f) { result.possible.insert("ㅎ 탈락"); continue }
                continue
            }
            if f == "ㅎ" {
                let asp: [Character: Character] = ["ㄱ": "ㅋ", "ㄷ": "ㅌ", "ㅈ": "ㅊ"]
                if let a = asp[next] { s[i].final = nil; s[i + 1].initial = a; result.certain.insert("거센소리되기"); continue }
                if next == "ㅅ" { s[i].final = nil; s[i + 1].initial = "ㅆ"; result.certain.insert("된소리되기"); continue }
                if next == "ㄴ" { s[i].final = "ㄴ"; result.certain.insert("비음화"); continue }
                return nil
            }
            let n = neutral(f)
            if n != f { result.certain.insert("음절의 끝소리 규칙"); s[i].final = n }
            switch next {
            case "ㄴ", "ㅁ":
                if let nasal = ["ㄱ": "ㅇ", "ㄷ": "ㄴ", "ㅂ": "ㅁ"][n] as Character? { s[i].final = nasal; result.certain.insert("비음화") }
                else if n == "ㄹ", next == "ㄴ" { s[i + 1].initial = "ㄹ"; result.certain.insert("유음화") }
            case "ㄹ":
                if n == "ㄴ" {
                    if s.count == 2 { s[i].final = "ㄹ"; result.certain.insert("유음화") }
                    else { result.possible.formUnion(["유음화", "비음화"]) }
                } else if n == "ㅁ" || n == "ㅇ" { s[i + 1].initial = "ㄴ"; result.certain.insert("비음화") }
                else if let nasal = ["ㄱ": "ㅇ", "ㅂ": "ㅁ"][n] as Character? { s[i].final = nasal; s[i + 1].initial = "ㄴ"; result.certain.insert("비음화") }
                else if n == "ㄹ" { }
                else { return nil }
            case "ㄱ", "ㄷ", "ㅂ", "ㅅ", "ㅈ":
                if ["ㄱ", "ㄷ", "ㅂ"].contains(n), let t = tense(next) { s[i + 1].initial = t; result.certain.insert("된소리되기") }
                else if ["ㄴ", "ㄹ", "ㅁ", "ㅇ"].contains(n) { result.possible.insert("된소리되기") }
            default: break
            }
        }
        // 낱말 끝 받침
        if let last = s.last?.final, neutral(last) != last { s[s.count - 1].final = neutral(last); result.certain.insert("음절의 끝소리 규칙") }
        if result.possible.isEmpty { result.pronunciation = compose(s) }
        return result
    }

    /// 묻는 음운 변동 이름
    private static let soundNames: [(names: [String], kind: String)] = [
        (["비음화"], "비음화"), (["유음화"], "유음화"), (["구개음화"], "구개음화"), (["된소리되기", "된소리 되기", "경음화"], "된소리되기"),
        (["거센소리되기", "거센소리 되기", "자음 축약", "격음화"], "거센소리되기"), (["ㅎ 탈락"], "ㅎ 탈락")
    ]

    /// 음운 변동 · 표준 발음 문제
    static func koreanSound(_ p: Problem) -> Found? {
        let c = p.compact
        // 표준 발음: "국물[궁물]" 선지, 낱말 + "[밤물]" 선지, "'신라'의 표준 발음"
        if matches(c, #"(발음|소리나)"#) {
            if p.isChoice, p.choices.allSatisfy({ $0.contains("[") }) {
                var verdicts: [Bool] = []
                var steps: [SolutionStep] = []
                let stemWord = c.firstMatch(of: #/(?:^|[?\n.])([가-힣]{2,4})$/#).map { String($0.1) }
                    ?? p.stem.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.last(where: { $0.range(of: #"^[가-힣]{2,4}$"#, options: .regularExpression) != nil })
                for (i, choice) in p.choices.enumerated() {
                    guard let m = choice.firstMatch(of: #/^\s*([가-힣]*)\s*\[([가-힣]+)\]\s*$/#) else { return nil }
                    let word = m.1.isEmpty ? (stemWord ?? "") : String(m.1)
                    guard !word.isEmpty, let sound = soundChanges(word)?.pronunciation else { return nil }
                    verdicts.append(sound == String(m.2))
                    steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(word) → [\(sound)]"))
                }
                let hits = verdicts.indices.filter { verdicts[$0] != p.negated }
                guard hits.count == 1 else { return nil }
                return pick(p, index: hits[0], concept: "표준 발음", steps: steps)
            }
            if !p.isChoice, let m = p.stem.firstMatch(of: #/[‘'"“]([가-힣]{2,4})[’'"”]/#), matches(c, #"표준발음"#) {
                let word = String(m.1)
                guard let change = soundChanges(word), let sound = change.pronunciation, sound != word || change.certain.subtracting(["연음"]).isEmpty else { return nil }
                let kinds = change.certain.subtracting(["연음"]).sorted().joined(separator: ", ")
                return Found(answer: "[\(sound)]", concept: "표준 발음", steps: [SolutionStep(hint: "음운 변동", work: kinds.isEmpty ? "변동 없음" : kinds),
                                                                              SolutionStep(hint: "발음", work: "\(word) → [\(sound)]")])
            }
        }
        guard p.isChoice, p.box.isEmpty, p.choices.allSatisfy({ $0.range(of: #"^[가-힣]{2,4}$"#, options: .regularExpression) != nil }) else { return nil }
        let analyses = p.choices.map(soundChanges)
        guard analyses.allSatisfy({ $0 != nil }) else { return nil }
        let list = analyses.compactMap { $0 }
        func describe(_ i: Int) -> SolutionStep {
            let a = list[i]
            let kinds = a.certain.subtracting(["연음", "음절의 끝소리 규칙"]).sorted().joined(separator: ", ")
            return SolutionStep(hint: "", work: "\(circled(i + 1)) \(p.choices[i])" + (a.pronunciation.map { "[\($0)]" } ?? "") + ": " + (kinds.isEmpty ? "변동 없음" : kinds))
        }
        // 종류가 다른 하나
        if matches(c, #"음운변동.{0,10}(종류|유형).{0,10}다른"#) {
            let mains = list.map { $0.certain.subtracting(["연음", "음절의 끝소리 규칙"]) }
            guard list.allSatisfy({ $0.possible.isEmpty }), mains.allSatisfy({ $0.count == 1 }) else { return nil }
            let kinds = mains.map { $0.first! }
            let counts = Dictionary(grouping: kinds, by: { $0 }).mapValues(\.count)
            guard counts.count == 2, let odd = counts.first(where: { $0.value == 1 })?.key, counts.values.contains(kinds.count - 1),
                  let index = kinds.firstIndex(of: odd) else { return nil }
            return pick(p, index: index, concept: "음운 변동", steps: p.choices.indices.map(describe))
        }
        // "비음화가 일어나는(일어나지 않는) 단어는?"
        let asked = soundNames.filter { entry in entry.names.contains { c.contains($0.replacingOccurrences(of: " ", with: "")) } }
        guard asked.count == 1, let kind = asked.first?.kind, matches(c, #"(일어나|나타나|적용되|일어난|해당)"#) else { return nil }
        var verdicts: [Bool] = []
        for a in list {
            if a.certain.contains(kind) { verdicts.append(true) }
            else if a.possible.contains(kind) { return nil }
            else { verdicts.append(false) }
        }
        let hits = verdicts.indices.filter { verdicts[$0] != p.negated }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: kind, steps: p.choices.indices.map(describe))
    }

    // MARK: 높임법

    /// 문장 하나의 높임 (주체 · 객체): true 있음, false 없음, nil 모름
    static func honorifics(_ sentence: String) -> (subject: Bool?, object: Bool?, objectWord: Bool?) {
        let s = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = s.filter { !$0.isWhitespace }
        // 객체 높임: 특수 어휘(드리다·여쭙다·모시다·뵙다)와 조사 '께'
        let objectWord = matches(compact, #"(드리|드렸|드려|드립|여쭈|여쭙|여쭤|모시|모셔|모셨|뵙|뵈|봬)"#)
        let objectParticle = matches(compact, #"(?<!함)께(?!서)"#)
        // 주체 높임: 께서, 특수 어휘, 선어말 어미 -시-
        var subject: Bool? = matches(compact, #"(께서|계시|계셨|계세|계십|주무|잡수|드시|드셨|드세|편찮|돌아가셨|돌아가시)"#)
        if subject == false {
            // 어간 뒤 선어말 어미 -시-: 둘째 글자부터 시·셨·셔·세·십·신·실 (첫 글자인 시장·신문은 아님, 마시다·모시다도 아님)
            // 높임 어미 모양이 분명하지 않으면 (다시, 도시 …) 모름
            let honorSyllables: Set<Character> = ["시", "셨", "셔", "세", "십", "신", "실"]
            let tokens = s.split(whereSeparator: { $0 == " " }).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?")) }
            search: for token in tokens {
                let chars = Array(token)
                guard chars.count >= 2 else { continue }
                for j in 1..<chars.count where honorSyllables.contains(chars[j]) {
                    let stem = String(chars[0..<j]), rest = String(chars[j...])
                    if stem.hasSuffix("마") || stem.hasSuffix("모") { continue }
                    let known = rest.range(of: #"^(셨|셔서|셔요|세요|십니다|십시오|신다|시는|시고|시며|시면|시어|시었|시다|신|실)"#, options: .regularExpression) != nil
                    subject = known ? true : nil
                    break search
                }
            }
        }
        return (subject, objectWord || objectParticle, objectWord)
    }

    static func koreanHonorific(_ p: Problem) -> Found? {
        let c = p.compact
        guard p.isChoice, p.box.isEmpty, c.contains("높임") else { return nil }
        let objectAsked = c.contains("객체높임"), subjectAsked = c.contains("주체높임")
        guard objectAsked != subjectAsked, !c.contains("상대높임") else { return nil }
        let wordsOnly = c.contains("특수어휘")
        var verdicts: [Bool] = []
        var steps: [SolutionStep] = []
        for (i, choice) in p.choices.enumerated() {
            let h = honorifics(choice)
            guard let v = objectAsked ? (wordsOnly ? h.objectWord : h.object) : h.subject else { return nil }
            verdicts.append(v)
            steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(choice) → \(objectAsked ? "객체" : "주체") 높임 \(v ? "있음" : "없음")"))
        }
        let hits = verdicts.indices.filter { verdicts[$0] != p.negated }
        guard hits.count == 1 else { return nil }
        let concept = objectAsked ? "객체 높임법 (드리다·여쭙다·모시다·뵙다, 조사 '께')" : "주체 높임법 (-시-, 께서, 계시다·주무시다·잡수시다)"
        return pick(p, index: hits[0], concept: concept, steps: steps)
    }
}
