import Foundation

/// 영어 문장 하나의 어법을 규칙으로 따지기 (시험의 "어법상 어색한 문장" · 보기 a)~e) 항목용)
/// - 확실히 틀린 곳만 찾아요: 찾으면 Issue, 못 찾으면 nil (nil은 "바르다"는 뜻이 아니에요)
/// - 규칙은 단서가 분명한 것만: 대명사 주어와 be동사·3인칭 단수, 조동사·do 뒤 원형, 과거 단서와 현재완료, since와 현재완료,
///   told that · said me, 가정법 과거 were + will, 조건절 will, 동명사·to부정사 목적어, 비교급·최상급 겹쳐 쓰기,
///   관계대명사와 선행사, 수동태의 과거분사, many·much, 셀 수 있는 명사의 수, there is/are, a/an, 의문문 어순, every/each 수일치
enum DoitSentenceCheck {
    struct Issue: Equatable {
        /// 규칙 이름 ("3인칭 단수")
        let rule: String
        /// 무엇이 틀렸는지 ("He play → He plays")
        let why: String
        /// 틀린 낱말 자리 (words(_:)의 번호, 모르면 nil) — 밑줄 문제에서 어느 밑줄인지 가릴 때 씀
        var at: Int? = nil
        /// 그 자리부터 몇 낱말을 고치는지
        var length: Int = 1
        /// 바르게 고친 말 (모르면 nil)
        var fix: String? = nil
    }

    // MARK: - 낱말 묶음

    static let subjectPronouns: Set<String> = ["i", "you", "he", "she", "it", "we", "they"]
    static let thirdSingular: Set<String> = ["he", "she", "it"]
    static let modals: Set<String> = ["can", "could", "will", "would", "shall", "should", "may", "might", "must"]
    static let beForms: Set<String> = ["am", "is", "are", "was", "were"]
    static let frequency: Set<String> = ["always", "usually", "often", "sometimes", "never", "also", "really", "rarely", "seldom", "still", "even", "only"]
    static let objectPronouns: Set<String> = ["me", "him", "her", "us", "them", "you", "it"]
    static let determiners: Set<String> = ["a", "an", "the", "this", "that", "my", "your", "his", "her", "our", "their", "its", "of", "free", "good"]
    /// 원형과 과거형이 같은 동사 (He put …은 과거일 수 있어요)
    static let sameBasePast: Set<String> = ["put", "cut", "hit", "read", "let", "set", "hurt", "cost", "quit", "shut", "spread", "bet", "burst",
                                                    "cast", "fit", "rid", "split", "upset", "beat", "bid", "broadcast", "forecast", "thrust", "wed",
                                                    // 다른 동사의 과거형이기도 한 원형 (lay = lie의 과거, found = find의 과거 …)
                                                    "lay", "found", "saw", "wound", "fell", "ground", "bore"]
    /// 조동사처럼도 쓰는 말 (He need not go)
    static let semiModals: Set<String> = ["need", "dare"]

    static let gerundVerbs: Set<String> = ["enjoy", "finish", "mind", "avoid", "quit", "practice", "deny", "consider", "imagine", "admit",
                                                   "postpone", "delay", "keep", "suggest", "recommend", "dislike", "give up", "put off"]
    static let infinitiveVerbs: Set<String> = ["want", "hope", "decide", "plan", "expect", "wish", "promise", "agree", "refuse", "choose",
                                                       "pretend", "afford", "manage", "fail", "offer", "would like"]
    /// -ing로 끝나지만 명사로 흔히 쓰는 말 (want clothing, plan a meeting)
    static let ingNouns: Set<String> = ["clothing", "building", "meeting", "painting", "morning", "evening", "feeling", "wedding", "ceiling",
                                                "ring", "king", "thing", "something", "nothing", "anything", "everything", "spring", "string", "swing",
                                                "wing", "sting", "boring", "interesting", "exciting", "amazing", "shopping", "camping", "fishing",
                                                "training", "reading", "writing", "drawing", "learning", "understanding", "beginning", "ending", "saving", "savings"]
    /// 사람 명사 (관계대명사 which를 쓰면 틀림)
    static let personNouns: Set<String> = ["friend", "friends", "boy", "boys", "girl", "girls", "man", "men", "woman", "women", "people", "person",
                                           "teacher", "teachers", "student", "students", "doctor", "doctors", "child", "children", "kid", "kids",
                                           "lady", "singer", "player", "players", "brother", "sister", "uncle", "aunt", "cousin", "neighbor",
                                           "nurse", "scientist", "artist", "writer", "actor", "actress", "baby", "classmate", "classmates",
                                           "pilot", "farmer", "driver", "mother", "father", "son", "daughter", "grandmother", "grandfather"]
    /// 사물 명사 (관계대명사 who를 쓰면 틀림, 동물은 who로도 쓸 때가 있어서 넣지 않음)
    static let thingNouns: Set<String> = ["book", "books", "house", "houses", "car", "cars", "movie", "movies", "song", "songs", "bag", "bags",
                                          "phone", "computer", "pen", "pencil", "picture", "pictures", "city", "town", "building", "story",
                                          "stories", "letter", "letters", "food", "restaurant", "shop", "store", "box", "watch", "camera",
                                          "bike", "bicycle", "game", "games", "toy", "toys", "flower", "flowers", "tree", "trees", "room",
                                          "school", "cake", "hat", "shirt", "shoes", "dress", "present", "gift", "river", "mountain", "country",
                                          "museum", "park", "window", "chair", "table", "desk", "bread", "smartphone", "robot", "machine", "bridge"]
    /// 셀 수 있는 명사 (단수 → 복수)
    static let countable: [String: String] = {
        var map: [String: String] = [
            "child": "children", "man": "men", "woman": "women", "foot": "feet", "tooth": "teeth", "mouse": "mice", "person": "people",
            "box": "boxes", "dish": "dishes", "watch": "watches", "city": "cities", "story": "stories", "baby": "babies", "leaf": "leaves", "knife": "knives"
        ]
        for noun in ["book", "friend", "brother", "sister", "boy", "girl", "student", "teacher", "pen", "pencil", "car", "dog", "cat", "apple",
                     "egg", "bird", "chair", "desk", "flower", "tree", "house", "room", "bag", "song", "movie", "picture", "cookie", "orange",
                     "banana", "cup", "hat", "key", "toy", "game", "door", "window", "student", "son", "daughter", "uncle", "cousin", "doctor"] {
            map[noun] = noun + "s"
        }
        return map
    }()
    static let numberWords: Set<String> = ["two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "twenty", "several", "many", "both", "these", "those"]
    static let wrongPlurals: Set<String> = ["childs", "mans", "womans", "foots", "tooths", "mouses", "gooses", "sheeps", "deers", "childrens", "mens", "teeths", "feets"]

    // MARK: - 낱말 나누기

    struct Words {
        /// 원래 모양 (구두점 뺌)
        let raw: [String]
        /// 소문자
        let w: [String]
        /// 이 낱말 뒤에 쉼표가 있었는지
        let comma: [Bool]
        let question: Bool
        func at(_ i: Int) -> String { i >= 0 && i < w.count ? w[i] : "" }
    }

    static func words(_ sentence: String) -> Words {
        let text = sentence.replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "‘", with: "'")
        var raw: [String] = [], comma: [Bool] = []
        for piece in text.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }) {
            var t = String(piece)
            let hadComma = t.hasSuffix(",") || t.hasSuffix(";")
            t = t.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"“”()"))
            guard !t.isEmpty else { if hadComma, !comma.isEmpty { comma[comma.count - 1] = true }; continue }
            raw.append(t); comma.append(hadComma)
        }
        return Words(raw: raw, w: raw.map { $0.lowercased() }, comma: comma, question: text.trimmingCharacters(in: .whitespaces).hasSuffix("?"))
    }

    /// 영어 문장으로 볼 만한지 (낱말 3개 이상, 한글 없음)
    static func isEnglishSentence(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.contains(where: { DoitSubjectNote.isHangul($0) }) else { return false }
        let ws = words(t)
        return ws.w.count >= 3 && ws.w.filter { $0.allSatisfy { $0.isLetter || $0 == "'" || $0 == "-" } }.count >= ws.w.count - 1
    }

    // MARK: - 동사 모양

    static func base(_ word: String) -> String? { DoitEnglish.verbBase(word) }

    /// 3인칭 단수 모양 (plays, goes, has, does)
    static func isThirdForm(_ word: String) -> Bool {
        guard word.hasSuffix("s"), let b = base(word), b != word, b != "be" else { return false }
        return DoitEnglish.thirdPerson(b) == word
    }

    /// 과거형으로만 쓰는 모양 (went, wrote — 원형·과거분사와 다른 것)
    static func isPastOnly(_ word: String) -> Bool {
        guard let b = base(word), b != word, b != "be" else { return false }
        return DoitEnglish.pastForms(b).contains(word) && !DoitEnglish.ppForms(b).contains(word)
    }

    /// 원형이 아닌 동사 모양 (3인칭·과거·-ing)
    static func isNonBaseVerb(_ word: String) -> Bool {
        guard let b = base(word), b != word else { return false }
        if b == "be" { return true }
        if word.hasSuffix("ing"), !ingNouns.contains(word) { return DoitEnglish.ingForm(b) == word }
        return isThirdForm(word) || DoitEnglish.pastForms(b).contains(word) || DoitEnglish.ppForms(b).contains(word)
    }

    /// 원형 동사 (주어 뒤에 바로 오면 현재형으로 읽는 것)
    static func isPlainBase(_ word: String) -> Bool {
        guard DoitEnglish.isKnownBaseVerb(word), base(word) == word, word != "be" else { return false }
        return !modals.contains(word) && !semiModals.contains(word) && !sameBasePast.contains(word)
    }

    /// 동사원형 (to 뒤 등: 원형·과거형이 같은 동사도 원형으로)
    static func isBaseForm(_ word: String) -> Bool {
        ["be", "have", "do", "go"].contains(word) || DoitEnglish.isKnownBaseVerb(word) && base(word) == word
    }

    static func isPresentPerfect(_ ws: Words, at i: Int) -> Bool {
        guard ["have", "has", "'ve"].contains(ws.at(i)) else { return false }
        var j = i + 1
        while frequency.contains(ws.at(j)) || ["just", "already", "ever", "not", "recently"].contains(ws.at(j)) { j += 1 }
        let next = ws.at(j)
        guard let b = base(next), b != next || next == "been" else { return false }
        return DoitEnglish.ppForms(b).contains(next)
    }

    // MARK: - 검사

    /// 확실한 어법 오류 하나 (없으면 nil)
    static func error(in sentence: String) -> Issue? {
        let ws = words(sentence)
        guard ws.w.count >= 2 else { return nil }
        let checks: [(Words) -> Issue?] = [wrongWordForms, pronounSubject, doSupport, afterModal, questionOrder, everyEach, thereBe,
                                           tenseCues, sinceCue, tellSay, conditional, verbObjects, causative, comparison, relative,
                                           passive, quantity, article, theAdjective, amountAsOne, numberOf, historicalFact, generalTruth] + grammarRules
        for check in checks { if let issue = check(ws) { return issue } }
        return nil
    }

    /// 확실한 어법 오류 모두 (규칙마다 하나씩, 같은 자리는 한 번만)
    static func errors(in sentence: String) -> [Issue] {
        let ws = words(sentence)
        guard ws.w.count >= 2 else { return [] }
        let checks: [(Words) -> Issue?] = [wrongWordForms, pronounSubject, doSupport, afterModal, questionOrder, everyEach, thereBe,
                                           tenseCues, sinceCue, tellSay, conditional, verbObjects, causative, comparison, relative,
                                           passive, quantity, article, theAdjective, amountAsOne, numberOf, historicalFact, generalTruth] + grammarRules
        var found: [Issue] = []
        for check in checks {
            guard let issue = check(ws) else { continue }
            if let a = issue.at, found.contains(where: { $0.at == a }) { continue }
            found.append(issue)
        }
        return found
    }

    /// 절이 하나인 짧은 문장인지 (때 단서 규칙은 이런 문장에만)
    static func singleClause(_ ws: Words) -> Bool {
        let joiners: Set<String> = ["that", "because", "when", "while", "if", "after", "before", "and", "but", "so", "who", "which", "said", "says",
                                    "think", "thinks", "thought", "know", "knows", "knew", "believe", "until", "though", "although", "since", "what", "where", "whom", "whose", "or", "than", "as"]
        return !ws.comma.contains(true) && !ws.w.contains(where: joiners.contains)
    }

    /// 대명사 주어가 오는 자리 (문장 처음, 쉼표 뒤, 접속사 if/when/because … 뒤)
    static func subjectSlots(_ ws: Words) -> [Int] {
        let openers: Set<String> = ["if", "when", "because", "before", "after", "so", "but", "while", "though", "although", "until"]
        return ws.w.indices.filter { i in
            guard subjectPronouns.contains(ws.w[i]) else { return false }
            if i == 0 || ws.comma[i - 1] || openers.contains(ws.w[i - 1]) && (i == 1 || ws.comma[i - 2]) { return true }
            // "He plays soccer and they …": and 앞에 동사가 있고 바로 앞이 대명사가 아니면 새 절
            if ws.w[i - 1] == "and", i >= 3, !subjectPronouns.contains(ws.w[i - 2]), !objectPronouns.contains(ws.w[i - 2]),
               ws.w[0..<(i - 1)].contains(where: { isPlainBase($0) || isThirdForm($0) || isPastOnly($0) || beForms.contains($0) }) { return true }
            return false
        }
    }

    /// goed · childs 같은 없는 낱말
    static func wrongWordForms(_ ws: Words) -> Issue? {
        for (i, word) in ws.w.enumerated() {
            if wrongPlurals.contains(word) { return Issue(rule: "불규칙 복수", why: "'\(ws.raw[i])'는 없는 복수형이에요.", at: i) }
            if DoitEnglish.isWrongVerbForm(word) { return Issue(rule: "불규칙 동사", why: "'\(ws.raw[i])'는 없는 동사 모양이에요.", at: i) }
        }
        return nil
    }

    /// 대명사 주어와 be동사 · 일반동사의 수일치 ("They was", "He play", "They plays")
    static func pronounSubject(_ ws: Words) -> Issue? {
        let subjunctive = ws.w.contains("if") || ws.w.contains("wish") || ws.w.contains("as")
        for i in subjectSlots(ws) {
            let s = ws.w[i]
            var j = i + 1
            while frequency.contains(ws.at(j)) { j += 1 }
            let v = ws.at(j)
            guard !v.isEmpty else { continue }
            // be동사
            if beForms.contains(v), j == i + 1 {
                let ok: Set<String>
                switch s {
                case "i": ok = subjunctive ? ["am", "was", "were"] : ["am", "was"]
                case "he", "she", "it": ok = subjunctive ? ["is", "was", "were"] : ["is", "was"]
                default: ok = ["are", "were"]
                }
                if !ok.contains(v) { return Issue(rule: "be동사 수일치", why: "주어 \(ws.raw[i]) 뒤에는 '\(v)'를 쓸 수 없어요.", at: j) }
                continue
            }
            // 일반동사 현재형
            // (that he go처럼 가정법 현재가 오는 자리는 빼려고 주어 자리를 문장 처음·쉼표 뒤·접속사 뒤로만 봐요)
            if thirdSingular.contains(s), isPlainBase(v) {
                return Issue(rule: "3인칭 단수", why: "주어 \(ws.raw[i])(3인칭 단수) 뒤 현재형은 \(DoitEnglish.thirdPerson(v))처럼 -s를 붙여요.", at: j, fix: DoitEnglish.thirdPerson(v))
            }
            if !thirdSingular.contains(s), isThirdForm(v) {
                return Issue(rule: "주어와 동사 수일치", why: "주어 \(ws.raw[i]) 뒤에는 \(base(v) ?? v)를 써요 (\(v)는 3인칭 단수 모양).", at: j, fix: v == "has" ? "have" : v == "does" ? "do" : base(v))
            }
        }
        return nil
    }

    /// do · does · did + 동사원형, 부정문 don't · doesn't
    static func doSupport(_ ws: Words) -> Issue? {
        // 의문문: Does she likes …?, Do she …?
        if ["do", "does", "did"].contains(ws.at(0)), subjectPronouns.contains(ws.at(1)) {
            let aux = ws.at(0), s = ws.at(1)
            if aux == "do", thirdSingular.contains(s) { return Issue(rule: "do/does", why: "주어 \(ws.raw[1])는 3인칭 단수라 Does를 써요.", at: 0, fix: "Does") }
            if aux == "does", !thirdSingular.contains(s) { return Issue(rule: "do/does", why: "주어 \(ws.raw[1])에는 Do를 써요.", at: 0, fix: "Do") }
            if isNonBaseVerb(ws.at(2)) {
                return Issue(rule: "의문문의 동사원형", why: "\(ws.raw[0]) + 주어 뒤에는 동사원형을 써요 ('\(ws.raw[2])' ✗).", at: 2, fix: base(ws.at(2)))
            }
        }
        for i in ws.w.indices {
            let t = ws.w[i]
            var verbAt: Int?
            if ["don't", "doesn't", "didn't"].contains(t) { verbAt = i + 1 }
            else if ["do", "does", "did"].contains(t), ws.at(i + 1) == "not", i > 0 { verbAt = i + 2 }
            guard let v = verbAt else { continue }
            let word = ws.at(v)
            if isNonBaseVerb(word), word != "being" {
                return Issue(rule: "부정문의 동사원형", why: "\(t) 뒤에는 동사원형을 써요 ('\(ws.raw[v])' ✗).", at: v, fix: base(word))
            }
            // 주어와 수일치 (문장 처음 대명사)
            if i == 1, subjectPronouns.contains(ws.at(0)) {
                let s = ws.at(0)
                let thirdAux = t.hasPrefix("does")
                if t.hasPrefix("do"), !t.hasPrefix("does"), thirdSingular.contains(s) { return Issue(rule: "don't/doesn't", why: "주어 \(ws.raw[0])는 3인칭 단수라 doesn't를 써요.", at: i, fix: t == "don't" ? "doesn't" : "does") }
                if thirdAux, !thirdSingular.contains(s) { return Issue(rule: "don't/doesn't", why: "주어 \(ws.raw[0])에는 don't를 써요.", at: i, fix: t == "doesn't" ? "don't" : "do") }
            }
        }
        return nil
    }

    /// 조동사 뒤 동사원형 ("can speaks", "will went", "must to go")
    static func afterModal(_ ws: Words) -> Issue? {
        let negatives: Set<String> = ["can't", "cannot", "won't", "couldn't", "shouldn't", "wouldn't", "mustn't", "mightn't"]
        for i in ws.w.indices where i > 0 && (modals.contains(ws.w[i]) || negatives.contains(ws.w[i])) {
            if determiners.contains(ws.w[i - 1]) { continue }
            let next = ws.at(i + 1)
            if next == "to" { return Issue(rule: "조동사 + 동사원형", why: "\(ws.w[i]) 뒤에는 to 없이 동사원형을 써요.", at: i + 1, fix: "") }
            if next == "not" || next.isEmpty { continue }
            if isNonBaseVerb(next), !["been", "had"].contains(next) {
                return Issue(rule: "조동사 + 동사원형", why: "\(ws.w[i]) 뒤에는 동사원형을 써요 ('\(ws.raw[i + 1])' ✗).", at: i + 1, fix: base(next))
            }
        }
        return nil
    }

    /// 의문문 어순의 be동사 ("Is they …?", "Are he …?")
    static func questionOrder(_ ws: Words) -> Issue? {
        guard ws.question, beForms.contains(ws.at(0)), subjectPronouns.contains(ws.at(1)) else { return nil }
        let be = ws.at(0), s = ws.at(1)
        let wrong: Bool
        switch be {
        case "am": wrong = s != "i"
        case "is": wrong = !thirdSingular.contains(s)
        case "are": wrong = s == "i" || thirdSingular.contains(s)
        case "was": wrong = !["i", "he", "she", "it"].contains(s)
        default: wrong = false   // Were I … (가정법 도치)는 따지지 않음
        }
        return wrong ? Issue(rule: "be동사 수일치", why: "주어 \(ws.raw[1])에는 \(ws.raw[0])를 쓸 수 없어요.", at: 0) : nil
    }

    /// every · each · everyone · one of … 는 단수 ("Every student are" ✗)
    static func everyEach(_ ws: Words) -> Issue? {
        var end: Int?
        let w0 = ws.at(0)
        if ["every", "each"].contains(w0), ws.at(1) != "of", !ws.at(1).isEmpty, countable[ws.at(1)] != nil || personNouns.contains(ws.at(1)) || thingNouns.contains(ws.at(1)) {
            end = 2
        } else if ["everyone", "everybody", "someone", "somebody", "nobody", "everything", "something", "nothing"].contains(w0) {
            end = 1
        } else if ["each", "one"].contains(w0), ws.at(1) == "of" {
            var j = 2
            if ["the", "my", "your", "his", "her", "our", "their", "these", "those"].contains(ws.at(j)) { j += 1 }
            let noun = ws.at(j)
            guard noun.hasSuffix("s") || ["children", "people", "men", "women"].contains(noun) || noun == "us" || noun == "them" else { return nil }
            end = j + 1
        }
        guard var v = end else { return nil }
        while frequency.contains(ws.at(v)) { v += 1 }
        let verb = ws.at(v)
        if ["are", "were"].contains(verb) || verb == "have" || isPlainBase(verb) {
            return Issue(rule: "단수 주어", why: "'\(ws.raw[0..<min(v, ws.raw.count)].joined(separator: " "))'는 단수로 받아요 ('\(ws.raw[v])' ✗).", at: v, fix: ["are": "is", "were": "was", "have": "has"][verb] ?? DoitEnglish.thirdPerson(verb))
        }
        return nil
    }

    /// there is + 단수, there are + 복수
    static func thereBe(_ ws: Words) -> Issue? {
        for i in ws.w.indices where ws.w[i] == "there" && (i == 0 || ws.comma[i - 1]) {
            let be = ws.at(i + 1), next = ws.at(i + 2), after = ws.at(i + 3)
            if ["is", "was"].contains(be) {
                if numberWords.contains(next) || countable.values.contains(next) {
                    return Issue(rule: "there is/are", why: "뒤에 복수 명사가 오면 there \(be == "is" ? "are" : "were")를 써요.", at: i + 1, fix: be == "is" ? "are" : "were")
                }
            } else if ["are", "were"].contains(be) {
                if ["a", "an", "one", "much", "each", "every"].contains(next), !["lot", "few", "number", "couple", "great"].contains(after) {
                    return Issue(rule: "there is/are", why: "뒤에 단수 명사가 오면 there \(be == "are" ? "is" : "was")를 써요.", at: i + 1, fix: be == "are" ? "is" : "was")
                }
            }
        }
        return nil
    }

    static let pastCue = #"\b(yesterday|ago|last (night|week|month|year|summer|winter|spring|fall|weekend|sunday|monday|tuesday|wednesday|thursday|friday|saturday))\b"#

    /// 과거 단서 + 현재완료 · 현재형 ("I have seen it yesterday", "He goes there yesterday")
    static func tenseCues(_ ws: Words) -> Issue? {
        let line = ws.w.joined(separator: " ")
        guard line.range(of: pastCue, options: .regularExpression) != nil, singleClause(ws) else { return nil }
        // 동사 뒤에 또 주어·동사가 오면 (관계사를 뺀 "He is the man I met yesterday") 과거 단서가 어느 동사 것인지 몰라요
        func anotherClause(after j: Int) -> Bool {
            ws.w.indices.contains { k in k > j && (subjectPronouns.contains(ws.w[k]) && !(["it", "you"].contains(ws.w[k]) && k == j + 1) || isPastOnly(ws.w[k]) || isThirdForm(ws.w[k])
                || (base(ws.w[k]).map { DoitEnglish.pastForms($0).contains(ws.w[k]) && $0 != ws.w[k] } ?? false)) }
        }
        for i in ws.w.indices where isPresentPerfect(ws, at: i) {
            guard !anotherClause(after: i + 1) else { return nil }
            return Issue(rule: "현재완료와 과거 단서", why: "yesterday · ago · last … 같은 과거 시점은 현재완료와 함께 쓰지 않아요 (과거형).", at: i)
        }
        guard subjectPronouns.contains(ws.at(0)) else { return nil }
        var j = 1
        while frequency.contains(ws.at(j)) { j += 1 }
        let v = ws.at(j)
        guard !anotherClause(after: j) else { return nil }
        if ["am", "is", "are"].contains(v) || isThirdForm(v) || isPlainBase(v) {
            return Issue(rule: "과거 시제", why: "과거를 나타내는 말이 있어서 과거형을 써요 ('\(ws.raw[j])' ✗).", at: j, fix: v == "am" || v == "is" ? "was" : v == "are" ? "were" : base(v).map { DoitEnglish.pastForms($0)[0] })
        }
        return nil
    }

    /// since + 시점이면 현재완료 ("I live here since 2010" ✗)
    static func sinceCue(_ ws: Words) -> Issue? {
        guard let s = ws.w.firstIndex(of: "since"), s >= 2 else { return nil }
        let point = ws.at(s + 1)
        guard point.range(of: #"^(1[89]|20)[0-9]{2}$"#, options: .regularExpression) != nil || point == "last" || point == "yesterday" else { return nil }
        // 앞부분은 대명사 주어 + 동사 하나뿐인 절
        guard subjectPronouns.contains(ws.at(0)), !ws.comma[0..<s].contains(true) else { return nil }
        let before = Array(ws.w[1..<s])
        guard !before.contains(where: { ["that", "because", "when", "and", "but", "who", "which"].contains($0) }) else { return nil }
        var j = 1
        while frequency.contains(ws.at(j)) { j += 1 }
        let v = ws.at(j)
        if ["have", "has", "'ve"].contains(v) || v == "had" { return nil }
        if beForms.contains(v) || isThirdForm(v) || isPlainBase(v) || isPastOnly(v) || (base(v).map { DoitEnglish.pastForms($0).contains(v) && $0 != v } ?? false) {
            return Issue(rule: "since와 현재완료", why: "since + 시점(…부터 지금까지)에는 현재완료(have/has + 과거분사)를 써요 ('\(ws.raw[j])' ✗).", at: j)
        }
        return nil
    }

    /// tell 뒤에는 사람, say 뒤에는 사람 없이 ("She told that …" ✗, "He said me that …" ✗)
    static func tellSay(_ ws: Words) -> Issue? {
        for i in ws.w.indices {
            let t = ws.w[i]
            if ["tell", "tells", "told"].contains(t), ws.at(i + 1) == "that" {
                let n1 = ws.at(i + 2), n2 = ws.at(i + 3), n3 = ws.at(i + 4)
                if subjectPronouns.contains(n1) || n1 == "there" || (n1 == "the" && (beForms.contains(n3) || isPastOnly(n3) || isThirdForm(n3)) && !n2.isEmpty) {
                    return Issue(rule: "tell + 사람 + that", why: "tell은 'tell + 사람 + that …'으로 써요 (told that ✗ → told me that / said that).", at: i)
                }
            }
            if ["say", "says", "said"].contains(t), objectPronouns.contains(ws.at(i + 1)), ws.at(i + 1) != "it", ws.at(i + 1) != "you" || ws.at(i + 2) == "that" {
                if ws.at(i + 2) == "that" || subjectPronouns.contains(ws.at(i + 2)) {
                    return Issue(rule: "say + (to 사람) + that", why: "say는 사람을 바로 쓰지 않아요 (said me ✗ → said to me / told me).", at: i)
                }
            }
        }
        return nil
    }

    /// 가정법 과거 + will, 조건 부사절의 will
    static func conditional(_ ws: Words) -> Issue? {
        guard ws.at(0) == "if" || ws.at(0) == "when", let cut = ws.comma.firstIndex(of: true), cut >= 2 else { return nil }
        let clause = Array(ws.w[1...cut]), main = Array(ws.w[(cut + 1)...])
        guard main.count >= 2 else { return nil }
        let mainWill = subjectPronouns.contains(main[0]) && ["will", "can", "shall"].contains(main[1]) || main[0].hasSuffix("'ll")
        if ws.at(0) == "if", clause.contains("were"), mainWill {
            return Issue(rule: "가정법 과거", why: "If + 주어 + were …(가정법 과거)이면 주절은 would/could + 동사원형이에요 (will ✗).", at: main[0].hasSuffix("'ll") ? cut + 1 : cut + 2, fix: main[0].hasSuffix("'ll") ? nil : (["will": "would", "can": "could", "shall": "should"][main[1]]))
        }
        if clause.count >= 2, subjectPronouns.contains(clause[0]) || clause[0] == "it", clause[1] == "will", mainWill || main[0].hasSuffix("'ll") {
            return Issue(rule: "조건·때의 부사절", why: "조건·때를 나타내는 부사절(if/when …)에서는 미래도 현재형으로 써요 (will ✗).", at: 2)
        }
        return nil
    }

    static func verbForms(_ v: String) -> Set<String> {
        guard !v.contains(" ") else { return [v] }
        var set: Set<String> = [v, DoitEnglish.thirdPerson(v), DoitEnglish.ingForm(v)]
        set.formUnion(DoitEnglish.pastForms(v))
        return set
    }

    /// 목적어로 동명사만 · to부정사만 쓰는 동사
    static func verbObjects(_ ws: Words) -> Issue? {
        let line = " " + ws.w.joined(separator: " ") + " "
        for v in gerundVerbs {
            let forms: [String] = v.contains(" ") ? {
                let parts = v.split(separator: " ").map(String.init)
                return verbForms(parts[0]).map { $0 + " " + parts.dropFirst().joined(separator: " ") }
            }() : Array(verbForms(v))
            for form in forms {
                guard let r = line.range(of: " \(form) to ") else { continue }
                let after = line[r.upperBound...].split(separator: " ").first.map(String.init) ?? ""
                if isBaseForm(after) {
                    return Issue(rule: "동명사를 목적어로 쓰는 동사", why: "\(v)는 목적어로 동명사(-ing)를 써요 (\(form) to \(after) ✗).", at: ws.w.firstIndex(of: after).map { $0 - 1 }, length: 2, fix: DoitEnglish.ingForm(after))
                }
            }
        }
        for v in infinitiveVerbs {
            let forms: [String] = v == "would like" ? ["would like", "'d like"] : Array(verbForms(v))
            for form in forms {
                guard let r = line.range(of: " \(form) ") else { continue }
                let after = line[r.upperBound...].split(separator: " ").first.map(String.init) ?? ""
                guard after.hasSuffix("ing"), !ingNouns.contains(after), let b = base(after), DoitEnglish.ingForm(b) == after else { continue }
                return Issue(rule: "to부정사를 목적어로 쓰는 동사", why: "\(v)는 목적어로 to부정사(to + 동사원형)를 써요 (\(form) \(after) ✗).", at: ws.w.firstIndex(of: after), fix: "to " + b)
            }
        }
        // look forward to + -ing
        if let r = line.range(of: #" look(s|ed|ing)? forward to "#, options: .regularExpression) {
            let after = line[r.upperBound...].split(separator: " ").first.map(String.init) ?? ""
            if isPlainBase(after) || after == "see" || after == "meet" {
                return Issue(rule: "look forward to + -ing", why: "look forward to의 to는 전치사라 뒤에 동명사(-ing)를 써요 (to \(after) ✗).", at: ws.w.firstIndex(of: after), fix: DoitEnglish.ingForm(after))
            }
        }
        return nil
    }

    /// 사역동사 make · let + 목적어 + 동사원형 ("made me to wait" ✗)
    static func causative(_ ws: Words) -> Issue? {
        let causatives: Set<String> = ["make", "makes", "made", "making", "let", "lets", "letting"]
        for i in ws.w.indices where causatives.contains(ws.w[i]) {
            guard objectPronouns.contains(ws.at(i + 1)) || ["tom", "mom", "dad"].contains(ws.at(i + 1)), ws.at(i + 2) == "to" else { continue }
            let v = ws.at(i + 3)
            if isBaseForm(v) {
                return Issue(rule: "사역동사 + 동사원형", why: "\(ws.w[i]) + 목적어 뒤에는 to 없이 동사원형을 써요.", at: i + 2, fix: "")
            }
        }
        return nil
    }

    /// 비교급 · 최상급 모양 → 원급 (흔한 형용사만)
    static let degreeForms: [String: (base: String, superlative: Bool)] = {
        var map: [String: (String, Bool)] = [:]
        for a in DoitEnglish.commonAdjectives {
            let f = DoitEnglish.comparison(a)
            for c in f.comparative where !c.contains(" ") && c != a { map[c] = (a, false) }
            for s in f.superlative where !s.contains(" ") && s != a { map[s] = (a, true) }
        }
        return map
    }()

    static func comparison(_ ws: Words) -> Issue? {
        for i in ws.w.indices {
            let t = ws.w[i], next = ws.at(i + 1)
            if ["more", "most", "less", "least"].contains(t), degreeForms[next] != nil {
                return Issue(rule: "비교급·최상급", why: "\(t)와 \(next)를 겹쳐 쓰지 않아요.", at: i, length: 2, fix: ws.raw[i + 1])
            }
            if let f = degreeForms[t], f.superlative, next == "than" {
                return Issue(rule: "비교급", why: "than 앞에는 비교급을 써요 (\(t) ✗).", at: i, fix: DoitEnglish.comparison(f.base).comparative.first)
            }
            if t == "as", let f = degreeForms[next], !f.superlative, ws.at(i + 2) == "as" {
                return Issue(rule: "원급 비교", why: "as … as 사이에는 원급을 써요 (\(next) ✗ → \(f.base)).", at: i + 1, fix: f.base)
            }
            if next == "than", DoitEnglish.commonAdjectives.contains(t), !["more", "less", "much", "far", "no", "any"].contains(ws.at(i - 1)),
               !["many", "much", "little", "far", "late", "well", "close", "near", "fine", "pure", "rude", "wet", "dry"].contains(t),
               beForms.contains(ws.at(i - 1)) {
                return Issue(rule: "비교급", why: "than 앞에는 비교급을 써요 (\(t) ✗).", at: i, fix: DoitEnglish.comparison(t).comparative.first)
            }
        }
        return nil
    }

    /// 관계대명사와 선행사 ("the girl which" ✗, "the book who" ✗, "the thing what" ✗)
    static func relative(_ ws: Words) -> Issue? {
        for i in ws.w.indices where i >= 1 && !ws.comma[i - 1] {
            let antecedent = ws.w[i - 1], r = ws.w[i]
            guard ["who", "whom", "which", "what"].contains(r), ws.at(i - 2) == "the" || ws.at(i - 2) == "a" || ws.at(i - 2) == "an"
                    || ["everything", "something", "anything", "all"].contains(antecedent) else { continue }
            // 관계절이어야: 바로 뒤에 동사나 주어
            let next = ws.at(i + 1)
            let clause = subjectPronouns.contains(next) || isThirdForm(next) || beForms.contains(next) || isPastOnly(next) || ["the", "my", "his", "her"].contains(next)
                || isPlainBase(next) && (antecedent.hasSuffix("s") || ["people", "children", "men", "women"].contains(antecedent))
            guard clause else { continue }
            if r == "which", personNouns.contains(antecedent) { return Issue(rule: "관계대명사", why: "선행사 \(antecedent)는 사람이라 who(m)/that을 써요 (which ✗).", at: i, fix: "who") }
            if r == "who" || r == "whom", thingNouns.contains(antecedent) { return Issue(rule: "관계대명사", why: "선행사 \(antecedent)는 사물이라 which/that을 써요 (\(r) ✗).", at: i, fix: "which") }
            if r == "what", ["thing", "things", "everything", "something", "anything", "all"].contains(antecedent) {
                return Issue(rule: "관계대명사 what", why: "what은 선행사를 품고 있어서 선행사(\(antecedent)) 뒤에 쓰지 않아요 (→ that/which).", at: i, fix: "that")
            }
        }
        return nil
    }

    /// 수동태는 be + 과거분사 ("was wrote" ✗, "was build" ✗)
    static func passive(_ ws: Words) -> Issue? {
        let transitive: Set<String> = ["build", "write", "make", "break", "speak", "teach", "sing", "steal", "eat", "give", "take", "catch", "draw",
                                       "grow", "see", "know", "choose", "drive", "ride", "bite", "hide", "throw", "forget", "sell", "buy", "send",
                                       "bring", "find", "tell", "invent", "discover", "paint", "design", "invite", "visit", "wash", "fix", "plant"]
        for i in ws.w.indices where ["was", "were", "been", "being", "is", "are", "am", "be"].contains(ws.w[i]) {
            let v = ws.at(i + 1)
            // broke는 "돈이 없는"이라는 형용사도 있어서 by가 바로 뒤에 올 때만
            if isPastOnly(v), v != "broke" || ws.at(i + 2) == "by", let b = base(v), b != "be" {
                return Issue(rule: "수동태의 과거분사", why: "be동사 + 과거분사: \(v) ✗ → \(DoitEnglish.ppForms(b).joined(separator: "/"))", at: i + 1, fix: DoitEnglish.ppForms(b).first)
            }
            if transitive.contains(v), DoitEnglish.ppForms(v).first != v,
               ["was", "were", "been", "being"].contains(ws.w[i]) || ws.w.dropFirst(i + 2).prefix(4).contains("by") {
                return Issue(rule: "수동태의 과거분사", why: "be동사 + 과거분사: \(v) ✗ → \(DoitEnglish.ppForms(v).joined(separator: "/"))", at: i + 1, fix: DoitEnglish.ppForms(v).first)
            }
        }
        return nil
    }

    /// many + 셀 수 없는 명사, much + 복수, 수 + 단수 명사
    static func quantity(_ ws: Words) -> Issue? {
        let plurals = Set(countable.values)
        for i in ws.w.indices {
            let t = ws.w[i], next = ws.at(i + 1)
            if t == "many", DoitEnglish.uncountableNouns.contains(next), next != "fun" {
                return Issue(rule: "many와 much", why: "\(next)는 셀 수 없는 명사라 many가 아니라 much를 써요.", at: i, fix: "much")
            }
            if t == "much", plurals.contains(next) {
                return Issue(rule: "many와 much", why: "\(next)는 셀 수 있는 명사의 복수라 much가 아니라 many를 써요.", at: i, fix: "many")
            }
            if ["two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "several", "many", "both"].contains(t), let plural = countable[next],
               plural != next {
                let after = ws.at(i + 2)
                if countable[after] == nil, !plurals.contains(after), !["of", "times", "hundred", "thousand"].contains(next) {
                    return Issue(rule: "명사의 복수형", why: "\(t) 뒤에는 복수형 \(plural)를 써요 (\(next) ✗).", at: i + 1, fix: plural)
                }
            }
            if ["a", "an", "every", "each", "another", "one"].contains(t), plurals.contains(next), !["people"].contains(next) || t != "a" {
                if t == "one", ws.at(i + 2) == "of" { continue }
                return Issue(rule: "명사의 수", why: "\(t) 뒤에는 단수 명사를 써요 (\(next) ✗).", at: i + 1, fix: countable.first(where: { $0.value == next })?.key)
            }
        }
        return nil
    }

    /// a / an
    static func article(_ ws: Words) -> Issue? {
        for i in ws.w.indices where ["a", "an"].contains(ws.w[i]) && i + 1 < ws.w.count {
            let raw = ws.raw[i + 1]
            guard raw.count >= 2, raw.allSatisfy({ $0.isLetter && $0.isLowercase }) else { continue }
            if ws.raw[i] == "A" && i > 0 { continue }   // Plan A 같은 이름
            let known = DoitEnglish.vocabulary[raw] != nil || DoitEnglish.commonAdjectives.contains(raw) || countable[raw] != nil
            guard known else { continue }
            let vowel = DoitEnglish.vowelSound(raw)
            if ws.w[i] == "a", vowel { return Issue(rule: "a/an", why: "\(raw)는 모음 소리로 시작해서 an을 써요.", at: i, fix: ws.raw[i] == "A" ? "An" : "an") }
            if ws.w[i] == "an", !vowel { return Issue(rule: "a/an", why: "\(raw)는 자음 소리로 시작해서 a를 써요.", at: i, fix: ws.raw[i] == "An" ? "A" : "a") }
        }
        return nil
    }

    // MARK: - 시험에 자주 나오는 수일치 · 시제 일치 예외

    /// the + 형용사 = ~한 사람들 (복수): "The young is" → are
    static let peopleAdjectives: Set<String> = ["young", "old", "rich", "poor", "elderly", "wounded", "injured", "homeless", "unemployed",
                                                        "sick", "disabled", "blind", "deaf", "dead", "living", "wealthy", "weak", "strong", "brave", "jobless"]
    static func theAdjective(_ ws: Words) -> Issue? {
        for i in ws.w.indices where ws.w[i] == "the" && (i == 0 || ws.at(i - 1) == "that" || ws.comma[i - 1]) {
            guard peopleAdjectives.contains(ws.at(i + 1)) else { continue }
            let verb = ws.at(i + 2)
            let fix = ["is": "are", "was": "were", "has": "have", "does": "do"]
            if let right = fix[verb] {
                return Issue(rule: "the + 형용사 (복수)", why: "the \(ws.at(i + 1)) = \(ws.at(i + 1)) people이라 복수: \(verb) → \(right)", at: i + 2, fix: right)
            }
        }
        return nil
    }

    /// 거리·시간·금액·무게를 한 덩어리로 볼 때는 단수: "Six kilometers are too long" → is
    static let amountUnits: Set<String> = ["kilometers", "kilometres", "miles", "meters", "metres", "years", "hours", "minutes", "seconds", "days",
                                                   "weeks", "months", "dollars", "won", "pounds", "kilograms", "grams", "liters", "litres", "feet", "yen", "euros"]
    static let amountNumbers: Set<String> = ["two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "fifteen",
                                                   "twenty", "thirty", "forty", "fifty", "sixty", "hundred", "thousand", "million", "several"]
    static func amountAsOne(_ ws: Words) -> Issue? {
        guard ws.w.count >= 4 else { return nil }
        // 문장 처음의 "수 + 단위 + are/were + (too/enough/a/not …)"
        var i = 0
        if ws.at(0) == "a" || ws.at(0) == "the" { i = 1 }
        let n = ws.at(i)
        guard amountNumbers.contains(n) || n.allSatisfy(\.isNumber), amountUnits.contains(ws.at(i + 1)) else { return nil }
        let verb = ws.at(i + 2)
        guard verb == "are" || verb == "were" else { return nil }
        let complements: Set<String> = ["too", "enough", "a", "an", "not", "very", "quite", "so", "long", "far", "short", "much", "expensive", "cheap",
                                        "heavy", "plenty", "more", "less", "the", "really", "pretty", "fairly"]
        guard complements.contains(ws.at(i + 3)) else { return nil }
        return Issue(rule: "거리·시간·금액은 단수", why: "\(ws.raw[i]) \(ws.raw[i + 1])는 한 덩어리로 봐서 단수: \(verb) → \(verb == "are" ? "is" : "was")", at: i + 2, fix: verb == "are" ? "is" : "was")
    }

    /// a number of + 복수 동사 / the number of + 단수 동사
    static func numberOf(_ ws: Words) -> Issue? {
        for i in ws.w.indices where ws.at(i + 1) == "number" && ws.at(i + 2) == "of" && (ws.w[i] == "a" || ws.w[i] == "the") {
            // of 뒤 명사 다음의 첫 동사 (4낱말 안)
            for j in (i + 3)..<min(ws.w.count, i + 8) {
                let v = ws.w[j]
                guard ["is", "are", "was", "were", "has", "have"].contains(v) else { continue }
                let singular = ["is", "was", "has"].contains(v)
                if ws.w[i] == "a", singular {
                    return Issue(rule: "a number of + 복수", why: "a number of(많은) 뒤는 복수 동사: \(v) → \(["is": "are", "was": "were", "has": "have"][v]!)", at: j, fix: ["is": "are", "was": "were", "has": "have"][v])
                }
                if ws.w[i] == "the", !singular {
                    return Issue(rule: "the number of + 단수", why: "the number of(~의 수)는 단수 동사: \(v) → \(["are": "is", "were": "was", "have": "has"][v]!)", at: j, fix: ["are": "is", "were": "was", "have": "has"][v])
                }
                break
            }
        }
        return nil
    }

    /// 역사적 사실은 늘 과거: "I heard that Pompeii had been discovered in 1748" → was discovered
    static func historicalFact(_ ws: Words) -> Issue? {
        guard let that = ws.w.firstIndex(of: "that"), that > 0 else { return nil }
        let reporting: Set<String> = ["heard", "learned", "learnt", "knew", "read", "said", "told", "taught", "studied", "found", "remembered"]
        guard ws.w[..<that].contains(where: reporting.contains) else { return nil }
        let clause = Array(ws.w[(that + 1)...])
        guard let had = clause.firstIndex(where: { $0 == "had" || $0 == "has" || $0 == "have" }) else { return nil }
        guard clause.indices.contains(where: { $0 > had && clause[$0] == "in" && $0 + 1 < clause.count
                                                && clause[$0 + 1].count >= 3 && clause[$0 + 1].count <= 4 && clause[$0 + 1].allSatisfy(\.isNumber) }) else { return nil }
        // "by 1748"·"before"·"since"처럼 그때까지의 완료를 말하면 맞을 수 있어서 제외
        if clause.contains(where: { ["by", "before", "since", "until", "already"].contains($0) }) { return nil }
        return Issue(rule: "역사적 사실은 과거", why: "역사적 사실은 주절 시제와 상관없이 과거: \(clause[had]) … → 과거 시제(was/were …)", at: that + 1 + had)
    }

    /// 변하지 않는 사실·과학적 진리는 늘 현재: "We were taught that Venus was the hottest planet" → is
    static let truthSubjects: Set<String> = ["earth", "sun", "moon", "venus", "mars", "jupiter", "saturn", "mercury", "neptune", "uranus",
                                                     "water", "light", "sound", "ice", "planet", "planets", "stars"]
    static func generalTruth(_ ws: Words) -> Issue? {
        guard let that = ws.w.firstIndex(of: "that"), that > 0 else { return nil }
        let reporting: Set<String> = ["taught", "learned", "learnt", "knew", "told", "said", "heard", "read", "studied", "explained", "believed"]
        guard ws.w[..<that].contains(where: reporting.contains) else { return nil }
        var k = that + 1
        if ws.at(k) == "the" { k += 1 }
        guard truthSubjects.contains(ws.at(k)) else { return nil }
        let verb = ws.at(k + 1)
        let pastToPresent = ["was": "is", "were": "are", "moved": "moves", "revolved": "revolves", "went": "goes", "boiled": "boils", "froze": "freezes",
                             "rose": "rises", "set": "sets", "travelled": "travels", "traveled": "travels", "had": "has", "consisted": "consists"]
        guard let right = pastToPresent[verb] else { return nil }
        return Issue(rule: "변하지 않는 사실은 현재", why: "과학적 사실·진리는 주절 시제와 상관없이 현재: \(verb) → \(right)", at: k + 1, fix: right)
    }
}
