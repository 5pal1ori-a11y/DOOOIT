import Foundation

// MARK: - 영어 어법 규칙 (초등 ~ 중1)
// be동사 · 일반동사 수일치 (명사 주어), 이름 주어, there + 수량, 지시사와 명사의 수, one of + 복수, 셀 수 없는 명사,
// 인칭대명사의 격 · 소유대명사, 의문문 (be · do · 의문사 어순), 진행형, 명령문 · Let's, 비교 기본, 시간 전치사, 전치사가 필요 없는 동사

extension DoitSentenceCheck {
    /// 이 파일과 다른 규칙 파일의 규칙 모두 (DoitSentenceCheck.error(in:)가 기존 규칙 다음에 씀)
    static var grammarRules: [(Words) -> Issue?] {
        basicRules + middleRules + highRules
    }

    static let basicRules: [(Words) -> Issue?] = [nounSubjectAgreement, coordinatedSubject, nameSubject, thereQuantity, demonstrativeNumber,
                                                  partitiveNoun, uncountableNoun, pronounCase, possessivePronoun, questionNounPhrase,
                                                  doQuestionInside, whQuestionOrder, progressiveForm, imperativeForm, comparisonBasics,
                                                  timePrepositions, needlessPreposition, beWithVerb]

    // MARK: 명사 주어 + 동사 수일치 ("My brother play" · "The boxes on the table is")

    static func nounSubjectAgreement(_ ws: Words) -> Issue? {
        let subjunctive = ws.w.contains(where: { ["if", "wish", "suggest", "suggested", "insist", "insisted", "demand", "demanded", "recommend", "though"].contains($0) })
        var slots = clauseStarts(ws)
        // that 뒤 (명사절 · 관계절의 주어): "Experts say that this habit make …"
        for i in ws.w.indices where i > 0 && ws.w[i - 1] == "that" && !slots.contains(i) { slots.append(i) }
        for i in ws.w.indices where i > 0 && ws.comma[i - 1] && !slots.contains(i) { slots.append(i) }
        for s in slots {
            guard let np = nounPhrase(ws, at: s, bare: true), let plural = np.plural else { continue }
            if amountUnits.contains(ws.w[np.head]) { continue }
            var v = np.end
            var throughPhrase = false
            // 수식어구 (전치사 + 명사구, of + 명사구 한 번 더)
            if prepositionWords.contains(ws.at(v)), !ws.comma[np.head] {
                guard let inner = looseNounPhrase(ws, at: v + 1) else { continue }
                v = inner
                if ws.at(v) == "of", let more = looseNounPhrase(ws, at: v + 1) { v = more }
                throughPhrase = true
            }
            while ["always", "usually", "often", "sometimes", "never", "also", "really", "still", "even", "only"].contains(ws.at(v)) { v += 1 }
            let verb = ws.at(v)
            guard !verb.isEmpty, v == 0 || !ws.comma[v - 1] else { continue }
            // 동사 자리에 원형 be · being (정형 동사가 없음)
            if ["be", "being"].contains(verb), !subjunctive, !ws.w[..<v].contains(where: { modals.contains($0) }),
               verb == "be" || !ws.comma[v..<min(ws.comma.count, v + 4)].contains(true) {   // The weather being fine, … (분사구문)
                return Issue(rule: "동사가 없는 문장", why: "주어 뒤 동사 자리에 \(verb)만 올 수 없어요 (is/are/was/were …)", at: v, fix: plural ? "are" : "is")
            }
            if subjunctive, verb == "were" { continue }
            let headRaw = ws.raw[np.head]
            if throughPhrase {
                guard ["is", "are", "was", "were", "has", "have"].contains(verb), let vn = verbNumber(verb), vn != plural else { continue }
                return Issue(rule: "주어와 동사 수일치 (수식어구)", why: "주어의 중심은 '\(headRaw)'(\(plural ? "복수" : "단수"))라서 \(verb) → \(flipNumber(verb) ?? "")",
                             at: v, fix: flipNumber(verb))
            }
            if let vn = verbNumber(verb), vn != plural {
                if isThirdForm(verb), isNoun(verb) { continue }
                return Issue(rule: "주어와 동사 수일치", why: "주어 '\(ws.raw[np.start..<np.end].joined(separator: " "))'는 \(plural ? "복수" : "3인칭 단수")라서 \(verb) → \(flipNumber(verb) ?? "")",
                             at: v, fix: flipNumber(verb))
            }
            if !plural, isPlainBase(verb), actionVerbs.contains(verb), !isFiniteVerb(ws.at(v + 1)), !subjunctive {
                return Issue(rule: "3인칭 단수", why: "주어 '\(ws.raw[np.start..<np.end].joined(separator: " "))'는 3인칭 단수라 현재형에 -s: \(verb) → \(DoitEnglish.thirdPerson(verb))",
                             at: v, fix: DoitEnglish.thirdPerson(verb))
            }
        }
        return nil
    }

    // MARK: A and B 주어는 복수 ("Tom and I is" · "My sister and my brother likes")

    static func coordinatedSubject(_ ws: Words) -> Issue? {
        func conjunct(_ i: Int, first: Bool) -> Int? {
            let w = ws.at(i)
            if personSubjects.contains(w) || (!first && w == "i") { return i + 1 }
            if looksLikeName(ws, i) { return i + 1 }
            if let np = nounPhrase(ws, at: i), np.plural != nil { return np.end }
            return nil
        }
        var start = 0
        if ws.at(0) == "both" { start = 1 }
        guard let a = conjunct(start, first: true), ws.at(a) == "and", let b = conjunct(a + 1, first: false) else { return nil }
        let verb = ws.at(b)
        guard ["is", "was", "has", "does", "doesn't", "isn't", "wasn't"].contains(verb) || isThirdForm(verb) && !isNoun(verb) else { return nil }
        // 이름 + 이름 + is + 단수 명사 (책 · 만화 제목)일 수 있으면 빼요
        let names = looksLikeName(ws, a + 1) || ws.raw[a + 1].first?.isUppercase == true
        if names, ["a", "an", "my", "our", "the"].contains(ws.at(b + 1)) { return nil }
        // 두 번째도 한정사가 있는 명사구여야 (The singer and actor is는 한 사람)
        if !personSubjects.contains(ws.at(a + 1)), ws.at(a + 1) != "i", !names, nounPhrase(ws, at: a + 1)?.hasDeterminer != true { return nil }
        return Issue(rule: "A and B 주어는 복수", why: "'\(ws.raw[start..<b].joined(separator: " "))'는 둘이라 복수: \(verb) → \(flipNumber(verb) ?? "")", at: b, fix: flipNumber(verb))
    }

    static func looksLikeNameAtStart(_ w: String) -> Bool {
        let common: Set<String> = ["please", "let", "here", "there", "today", "then", "now", "both", "all", "some", "many", "most", "each", "every"]
        return !common.contains(w) && !whWords.contains(w) && !subjectPronouns.contains(w) && !adjectiveWords.contains(w)
            && !singularDeterminers.contains(w) && !pluralDeterminers.contains(w) && !neutralDeterminers.contains(w)
    }

    // MARK: 이름 주어 ("Tom like apples" · "Mina are")

    static func nameSubject(_ ws: Words) -> Issue? {
        var i = 0
        if ["mr", "mrs", "ms", "dr"].contains(ws.at(0)) { i = 1 }
        guard looksLikeName(ws, i), !ws.comma[i] else { return nil }
        if ws.w.contains(where: { ["if", "wish"].contains($0) }) { return nil }
        var k = i + 1
        while frequency.contains(ws.at(k)) { k += 1 }
        let v = ws.at(k)
        if ["are", "were", "have", "do", "don't", "aren't", "weren't"].contains(v) {
            return Issue(rule: "주어와 동사 수일치", why: "주어 \(ws.raw[0...i].joined(separator: " "))는 3인칭 단수라서 \(v) → \(flipNumber(v) ?? "")", at: k, fix: flipNumber(v))
        }
        if isPlainBase(v), actionVerbs.contains(v), !isFiniteVerb(ws.at(k + 1)) {
            return Issue(rule: "3인칭 단수", why: "주어 \(ws.raw[0...i].joined(separator: " "))는 3인칭 단수라 현재형에 -s: \(v) → \(DoitEnglish.thirdPerson(v))",
                         at: k, fix: DoitEnglish.thirdPerson(v))
        }
        return nil
    }

    // MARK: there is/are + some · a lot of · no + 명사

    static func thereQuantity(_ ws: Words) -> Issue? {
        for i in ws.w.indices where ws.w[i] == "there" && (i == 0 || ws.comma[i - 1]) {
            let be = ws.at(i + 1)
            if ["be", "been", "being"].contains(be) {
                return Issue(rule: "there is/are", why: "there 뒤 동사 자리에 \(be)만 올 수 없어요 (is/are/was/were)", at: i + 1)
            }
            guard let bn = verbNumber(be), beForms.contains(be) else { continue }
            var j = i + 2
            if ["a lot of", "lots of", "plenty of"].contains(ws.w[j..<min(j + 3, ws.w.count)].joined(separator: " ")) { j += 3 }
            else if ws.at(j) == "lots" || ws.at(j) == "plenty", ws.at(j + 1) == "of" { j += 2 }
            else if ["some", "no", "any"].contains(ws.at(j)) { j += 1 }
            else { continue }
            var k = j
            while isAdjectiveLike(ws.at(k)), !isNoun(ws.at(k)) { k += 1 }
            guard let np = nounPlural(ws.at(k)), !amountUnits.contains(ws.at(k)) else { continue }
            if np != bn {
                return Issue(rule: "there is/are", why: "there 뒤 be동사는 뒤 명사(\(ws.raw[k]): \(np ? "복수" : "단수·셀 수 없음"))에 맞춰요: \(be) → \(flipNumber(be) ?? "")",
                             at: i + 1, fix: flipNumber(be))
            }
        }
        return nil
    }

    // MARK: this · these · those와 명사의 수

    static func demonstrativeNumber(_ ws: Words) -> Issue? {
        for i in ws.w.indices where ["this", "these", "those"].contains(ws.w[i]) {
            var j = i + 1
            while isAdjectiveLike(ws.at(j)), !isNoun(ws.at(j)) { j += 1 }
            let n = ws.at(j)
            guard let plural = nounPlural(n), !massNouns.contains(n) || ws.w[i] != "this" else { continue }
            if ["kind", "sort", "type"].contains(n) { continue }
            if ws.w[i] == "this", plural, !pluralOnlyNouns.contains(n) || n == "people" {
                return Issue(rule: "지시사와 명사의 수", why: "\(n)는 복수라 this가 아니라 these를 써요.", at: i, fix: ws.raw[i] == "This" ? "These" : "these")
            }
            if ws.w[i] != "this", !plural, isCountableSingular(n) {
                return Issue(rule: "지시사와 명사의 수", why: "\(ws.w[i]) 뒤에는 복수 명사: \(n) → \(pluralOf[n] ?? n)", at: j, fix: pluralOf[n])
            }
        }
        return nil
    }

    // MARK: one of · each of · some of + the + 복수 명사

    static func partitiveNoun(_ ws: Words) -> Issue? {
        let quantifiers: Set<String> = ["one", "each", "either", "neither", "many", "several", "both", "few", "none"]
        for i in ws.w.indices where quantifiers.contains(ws.w[i]) && ws.at(i + 1) == "of" {
            guard ["the", "my", "your", "his", "her", "our", "their", "these", "those"].contains(ws.at(i + 2)) else { continue }
            var j = i + 3
            var guardCount = 0
            while guardCount < 3, ["most", "more"].contains(ws.at(j)) || isAdjectiveLike(ws.at(j)) && !isNoun(ws.at(j)) { j += 1; guardCount += 1 }
            let n = ws.at(j)
            guard isCountableSingular(n), !isNoun(ws.at(j + 1)) || isFiniteVerb(ws.at(j + 1)), ws.at(j + 1) != "'s" else { continue }
            return Issue(rule: "one of + 복수 명사", why: "\(ws.w[i]) of the … 뒤에는 복수 명사: \(n) → \(pluralOf[n] ?? n)", at: j, fix: pluralOf[n])
        }
        return nil
    }

    // MARK: 셀 수 없는 명사 ("an information" · "advices")

    static func uncountableNoun(_ ws: Words) -> Issue? {
        let never: [String: String] = ["informations": "information", "advices": "advice", "furnitures": "furniture", "homeworks": "homework",
                                       "luggages": "luggage", "baggages": "baggage", "equipments": "equipment", "knowledges": "knowledge"]
        let strict: Set<String> = ["information", "advice", "furniture", "homework", "luggage", "baggage", "equipment", "news"]
        let after: Set<String> = ["", "of", "for", "about", "on", "from", "to", "is", "was", "and", "in", "at", "with", "that", "which", "today", "yesterday"]
        // a/an: 철자와 소리가 다른 말 (an useful ✗, a hour ✗)
        let consonantSound: Set<String> = ["useful", "university", "uniform", "unique", "unicorn", "union", "unit", "united", "universe", "usual",
                                           "european", "one", "once", "user", "utensil", "unicycle", "uniformed", "usage"]
        let vowelSoundWords: Set<String> = ["hour", "hours", "honest", "honor", "honour", "heir", "honorable", "hourly"]
        for i in ws.w.indices.dropLast() {
            if ws.w[i] == "an", consonantSound.contains(ws.w[i + 1]) { return Issue(rule: "a/an", why: "\(ws.w[i + 1])는 자음 소리(j/w)로 시작해서 a를 써요.", at: i, fix: ws.raw[i] == "An" ? "A" : "a") }
            if ws.w[i] == "a", vowelSoundWords.contains(ws.w[i + 1]) { return Issue(rule: "a/an", why: "\(ws.w[i + 1])의 h는 소리가 나지 않아 an을 써요.", at: i, fix: ws.raw[i] == "A" ? "An" : "an") }
        }
        for i in ws.w.indices {
            if let right = never[ws.w[i]] { return Issue(rule: "셀 수 없는 명사", why: "\(right)는 셀 수 없어서 -s를 붙이지 않아요.", at: i, fix: right) }
            if ["a", "an"].contains(ws.w[i]), strict.contains(ws.at(i + 1)), after.contains(ws.at(i + 2)) {
                return Issue(rule: "셀 수 없는 명사", why: "\(ws.at(i + 1))는 셀 수 없어서 a/an을 쓰지 않아요 (a piece of …).", at: i, fix: "")
            }
            if ["many", "few", "several"].contains(ws.w[i]) || ws.w[i] == "a" && ws.at(i + 1) == "few" {
                let n = ws.w[i] == "a" ? ws.at(i + 2) : ws.at(i + 1)
                if strict.contains(n) || ["money", "water", "milk", "time", "bread", "rice", "sugar", "music"].contains(n) && ws.w[i] != "many" {
                    return Issue(rule: "셀 수 없는 명사", why: "\(n)는 셀 수 없어서 much / a little을 써요.", at: i)
                }
            }
        }
        return nil
    }

    // MARK: 인칭대명사의 격 ("with I" · "I love she" · "Me and my friend went")

    static func pronounCase(_ ws: Words) -> Issue? {
        let preps: Set<String> = ["with", "to", "about", "of", "from", "at", "by", "without", "among", "behind", "near", "under", "beside",
                                  "toward", "towards", "into", "onto", "against", "around", "for"]
        let objectVerbs: Set<String> = ["love", "loves", "loved", "like", "likes", "liked", "help", "helps", "helped", "meet", "meets", "met",
                                        "visit", "visits", "visited", "invite", "invites", "invited", "thank", "thanked", "call", "calls",
                                        "called", "follow", "follows", "followed", "marry", "married", "join", "joined", "hate", "hates",
                                        "hated", "miss", "missed", "hug", "hugged", "trust", "trusted", "teach", "taught", "tell", "told"]
        for i in ws.w.indices.dropLast() {
            let t = ws.w[i], p = ws.at(i + 1)
            guard let obj = objectCase[p], p != "i" || ws.raw[i + 1] == "I" else { continue }
            let next = ws.at(i + 2)
            let clauseFollows = isFiniteVerb(next) || isBaseForm(next) || modals.contains(next) || ["not", "always", "never", "often", "also", "usually"].contains(next)
            if preps.contains(t), !clauseFollows, !(t == "for" && isFiniteVerb(ws.at(i + 3))) {
                return Issue(rule: "인칭대명사의 격", why: "전치사 \(t) 뒤에는 목적격: \(ws.raw[i + 1]) → \(obj)", at: i + 1, fix: obj)
            }
            if objectVerbs.contains(t) || t.hasSuffix("ing") && base(t).map({ objectVerbs.contains($0) }) == true, !clauseFollows {
                return Issue(rule: "인칭대명사의 격", why: "동사 \(t)의 목적어 자리에는 목적격: \(ws.raw[i + 1]) → \(obj)", at: i + 1, fix: obj)
            }
        }
        // between you and I
        if let b = ws.w.firstIndex(of: "between"), ws.at(b + 2) == "and", let obj = objectCase[ws.at(b + 3)], !isFiniteVerb(ws.at(b + 4)) {
            return Issue(rule: "인칭대명사의 격", why: "between A and B의 B도 목적격: \(ws.raw[b + 3]) → \(obj)", at: b + 3, fix: obj)
        }
        // 문장 처음의 목적격 주어
        let w0 = ws.at(0)
        if let subj = subjectCase[w0], w0 != "her", w0 != "us" || isFiniteVerb(ws.at(1)) {
            let v = ws.at(1)
            if isFiniteVerb(v), !ws.comma[0] {
                return Issue(rule: "인칭대명사의 격", why: "주어 자리에는 주격: \(ws.raw[0]) → \(subj == "I" ? "I" : subj.capitalized)", at: 0, fix: subj == "I" ? "I" : subj.capitalized)
            }
            if v == "and", (2..<min(6, ws.w.count)).contains(where: { isFiniteVerb(ws.w[$0]) }) {
                return Issue(rule: "인칭대명사의 격", why: "주어 자리에는 주격: \(ws.raw[0]) and … → … and \(subj) (주격)", at: 0, fix: subj == "I" ? "I" : subj.capitalized)
            }
        }
        return nil
    }

    // MARK: 소유격 · 소유대명사 ("The book is my." · "mine book" · "it's own")

    static func possessivePronoun(_ ws: Words) -> Issue? {
        let toPronoun = ["my": "mine", "your": "yours", "our": "ours", "their": "theirs"]
        let toPossessive = ["mine": "my", "yours": "your", "hers": "her", "ours": "our", "theirs": "their"]
        for i in ws.w.indices {
            let t = ws.w[i]
            if let right = toPronoun[t], i == ws.w.count - 1, i > 0, beForms.contains(ws.w[i - 1]) {
                return Issue(rule: "소유대명사", why: "'~의 것'은 소유대명사: \(t) → \(right)", at: i, fix: right)
            }
            if let right = toPossessive[t], isNoun(ws.at(i + 1)), !["and", "or"].contains(ws.at(i + 1)), !ws.comma[i] {
                return Issue(rule: "소유격", why: "명사 앞에는 소유격: \(t) \(ws.at(i + 1)) → \(right) \(ws.at(i + 1))", at: i, fix: right)
            }
            if t == "it's", ws.at(i + 1) == "own" { return Issue(rule: "소유격 its", why: "'그것의'는 its (it's = it is): it's own → its own", at: i, fix: "its") }
            if t == "it's", i > 0, prepositionWords.contains(ws.w[i - 1]) && isNoun(ws.at(i + 1))
                || (isFiniteVerb(ws.w[i - 1]) || ws.w[i - 1].hasSuffix("ed")) && !["said", "says", "thought", "knew", "believed", "hoped", "guessed", "felt", "found", "is", "was"].contains(ws.w[i - 1])
                    && isCountableSingular(ws.at(i + 1)) && !personNouns.contains(ws.at(i + 1)) {
                return Issue(rule: "소유격 its", why: "'그것의'는 its (it's = it is)", at: i, fix: "its")
            }
            if t == "its", i == 0 || ws.comma[i - 1], ["a", "an", "the", "very", "so", "not", "too", "raining", "snowing"].contains(ws.at(i + 1)) {
                return Issue(rule: "it's와 its", why: "'그것은 ~이다'는 It's (= It is): Its → It's", at: i, fix: ws.raw[i] == "Its" ? "It's" : "it's")
            }
        }
        return nil
    }

    // MARK: be · do · have 의문문과 명사 주어 ("Is your parents …?" · "Do your brother …?")

    static func questionNounPhrase(_ ws: Words) -> Issue? {
        guard ws.question else { return nil }
        var i = 0
        if whWords.contains(ws.at(0)) { i = 1 }
        let aux = ws.at(i)
        guard ["is", "are", "was", "does", "do", "has"].contains(aux), let an = verbNumber(aux),
              let np = nounPhrase(ws, at: i + 1), let plural = np.plural, np.hasDeterminer, ws.at(np.end) != "and", ws.at(np.end) != "or" else { return nil }
        if amountUnits.contains(ws.w[np.head]) { return nil }
        // what is + 명사구: "What are your plans?" · "What is the boys' names?"처럼 뒤에 또 명사가 오면 모름
        if isNoun(ws.at(np.end)) { return nil }
        guard an != plural else {
            // Does your father works …? (do/does/did + 주어 + 동사원형)
            if ["does", "do", "did"].contains(aux), isNonBaseVerb(ws.at(np.end)), !isNoun(ws.at(np.end)), let b = base(ws.at(np.end)), ws.at(np.end) != "being" {
                return Issue(rule: "의문문의 동사원형", why: "\(ws.raw[i]) + 주어 뒤에는 동사원형: \(ws.raw[np.end]) → \(b)", at: np.end, fix: b)
            }
            return nil
        }
        let fixed = flipNumber(aux).map { i == 0 ? $0.capitalized : $0 }
        return Issue(rule: "의문문의 수일치", why: "주어 '\(ws.raw[np.start..<np.end].joined(separator: " "))'는 \(plural ? "복수" : "단수"): \(ws.raw[i]) → \(fixed ?? "")", at: i, fix: fixed)
    }

    // MARK: 의문사 · 부정어 뒤 do/does/did + 주어 + 동사원형 ("What does he likes?" · "Where did you went?")

    static func doQuestionInside(_ ws: Words) -> Issue? {
        for i in ws.w.indices where i >= 1 && ["do", "does", "did"].contains(ws.w[i]) {
            let s = ws.at(i + 1)
            guard subjectPronouns.contains(s) else { continue }
            let w0 = ws.at(0)
            let frontWh = whWords.contains(w0) && !(1..<i).contains(where: { isFiniteVerb(ws.w[$0]) })
            let frontNeg = (negativeAdverbs.contains(w0) || w0 == "only" || (w0 == "not" && ws.at(1) == "until")) && !(1..<i).contains(where: { isFiniteVerb(ws.w[$0]) || subjectPronouns.contains(ws.w[$0]) })
            guard frontWh || frontNeg, !ws.comma[0..<i].contains(true) || frontNeg else { continue }
            var v = i + 2
            if ws.at(v) == "not" || frequency.contains(ws.at(v)) || ws.at(v) == "ever" { v += 1 }
            let verb = ws.at(v)
            if ws.w[i] == "does", ["i", "you", "we", "they"].contains(s), isBaseForm(verb) {
                return Issue(rule: "do/does", why: "주어 \(ws.raw[i + 1])에는 do를 써요 (does ✗).", at: i, fix: "do")
            }
            if ws.w[i] == "do", ["he", "she"].contains(s), isBaseForm(verb) {
                return Issue(rule: "do/does", why: "주어 \(ws.raw[i + 1])는 3인칭 단수라 does를 써요 (do ✗).", at: i, fix: "does")
            }
            if isNonBaseVerb(verb), verb != "being", !isNoun(verb), let b = base(verb) {
                return Issue(rule: "의문문의 동사원형", why: "\(ws.w[i]) + 주어 뒤에는 동사원형: \(ws.raw[v]) → \(b)", at: v, fix: b)
            }
        }
        return nil
    }

    // MARK: 의문사 의문문 어순 ("Where you live?" · "What you are doing?")

    static func whQuestionOrder(_ ws: Words) -> Issue? {
        guard ws.question, ["what", "where", "when", "why", "how", "which", "who", "whom"].contains(ws.at(0)) else { return nil }
        var s = 1
        if ws.at(0) == "how", ["many", "much", "old", "long", "often", "far", "tall", "big"].contains(ws.at(1)) {
            s = 2
            if let np = nounPhrase(ws, at: 2, bare: true) { s = np.end } else if isNoun(ws.at(2)) { s = 3 }
        }
        guard personSubjects.contains(ws.at(s)), !ws.comma.contains(true) else { return nil }
        if ws.at(0) == "how", ws.at(1) == "come" { return nil }
        let v = ws.at(s + 1)
        let verbLike = beForms.contains(v) || modals.contains(v) || ["has", "have", "do", "does", "did"].contains(v) || isPlainBase(v) || isPastOnly(v) || isThirdForm(v)
        guard verbLike else { return nil }
        return Issue(rule: "의문사 의문문 어순", why: "의문사 의문문은 '의문사 + 동사(조동사) + 주어 …?' 어순이에요 (\(ws.raw[0..<(s + 2)].joined(separator: " ")) ✗).", at: s)
    }

    // MARK: 진행형 be + -ing ("I am play soccer now") · 상태동사 진행형 ("I am knowing")

    static func progressiveForm(_ ws: Words) -> Issue? {
        let progressive: Set<String> = ["play", "study", "go", "eat", "run", "swim", "sing", "dance", "watch", "listen", "walk", "talk", "sleep",
                                        "cook", "write", "wait", "learn", "teach", "draw", "ride", "fly", "cry", "laugh", "jump", "climb", "wash",
                                        "make", "take", "do", "buy", "sell", "drive", "speak", "visit", "travel", "sit", "stand", "wear",
                                        "come", "think", "move", "carry", "build", "bring", "send", "meet", "tell", "say", "finish", "rain"]
        let stative: Set<String> = ["knowing", "belonging", "resembling", "possessing"]
        for i in subjectSlots(ws) where personSubjects.contains(ws.w[i]) {
            var j = i + 1
            guard beForms.contains(ws.at(j)) else { continue }
            j += 1
            if ws.at(j) == "not" || frequency.contains(ws.at(j)) { j += 1 }
            let v = ws.at(j)
            if progressive.contains(v), isPlainBase(v) || v == "do" || v == "go" {
                return Issue(rule: "진행형 be + -ing", why: "be동사 뒤에 동사원형은 올 수 없어요: 진행형은 be + -ing (\(v) → \(DoitEnglish.ingForm(v)))",
                             at: j, fix: DoitEnglish.ingForm(v))
            }
            if stative.contains(v) {
                return Issue(rule: "상태동사의 진행형", why: "know · belong · resemble 같은 상태동사는 진행형으로 쓰지 않아요 (\(v) ✗).", at: j)
            }
        }
        return nil
    }

    // MARK: 명령문 · Let's ("Don't late" · "Let's going" · "Please opens")

    static func imperativeForm(_ ws: Words) -> Issue? {
        let adjectives: Set<String> = ["late", "noisy", "shy", "afraid", "angry", "sad", "rude", "lazy", "nervous", "careless", "sorry", "scared",
                                       "silly", "foolish", "quiet", "upset", "worried", "selfish", "mean", "loud"]
        var i = 0
        if ws.at(0) == "please" { i = 1 }
        if ws.at(i) == "don't" || ws.at(i) == "do" && ws.at(i + 1) == "not" {
            let k = ws.at(i) == "don't" ? i + 1 : i + 2
            if adjectives.contains(ws.at(k)), ws.at(k) != "mean" || ws.at(k + 1).isEmpty {
                return Issue(rule: "부정 명령문", why: "형용사 앞 부정 명령은 Don't be + 형용사 (Don't \(ws.at(k)) ✗)", at: k, fix: "be " + ws.raw[k])
            }
        }
        for j in ws.w.indices where ws.w[j] == "let's" {
            var k = j + 1
            if ws.at(k) == "not" { k += 1 }
            let v = ws.at(k)
            if v == "to" { return Issue(rule: "Let's + 동사원형", why: "Let's 뒤에는 to 없이 동사원형을 써요.", at: k, fix: "") }
            if isNonBaseVerb(v), !isNoun(v), let b = base(v), v != "being" {
                return Issue(rule: "Let's + 동사원형", why: "Let's 뒤에는 동사원형: \(v) → \(b)", at: k, fix: b)
            }
        }
        if ws.at(0) == "please", !ws.comma[0], (isThirdForm(ws.at(1)) || isPastOnly(ws.at(1))), !isNoun(ws.at(1)), let b = base(ws.at(1)) {
            return Issue(rule: "명령문은 동사원형", why: "명령문은 동사원형으로 시작해요: \(ws.at(1)) → \(b)", at: 1, fix: b)
        }
        return nil
    }

    // MARK: 비교 기본 ("very taller" · "is tallest boy" · "as tall than" · "taller as me" · "than any other boys")

    static func comparisonBasics(_ ws: Words) -> Issue? {
        for i in ws.w.indices {
            let t = ws.w[i], next = ws.at(i + 1)
            let nextComparative = degreeForms[next].map { !$0.superlative } ?? false || ["better", "worse", "more", "less"].contains(next)
            if t == "very", nextComparative, ws.w.dropFirst(i + 2).prefix(3).contains("than") || next == "more" {
                return Issue(rule: "비교급 강조", why: "비교급은 very가 아니라 much · far · even · a lot으로 꾸며요.", at: i, fix: "much")
            }
            if beForms.contains(t), let f = degreeForms[next], f.superlative, isNoun(ws.at(i + 2)), !ws.comma[i + 1], !["best", "most", "least", "last"].contains(next) {
                return Issue(rule: "최상급 앞 the", why: "최상급 앞에는 the: \(next) → the \(next)", at: i + 1, fix: "the " + ws.raw[i + 1])
            }
            if t == "as", DoitEnglish.commonAdjectives.contains(next) || adjectiveWords.contains(next), ws.at(i + 2) == "than", degreeForms[next] == nil {
                return Issue(rule: "원급 비교 as ~ as", why: "as + 원급 + as (as \(next) than ✗)", at: i + 2, fix: "as")
            }
            if let f = degreeForms[t], !f.superlative, next == "as" {
                let after = ws.at(i + 2)
                if ["me", "him", "her", "us", "them", "mine", "yours", "hers", "ours", "theirs"].contains(after) && endsPhrase(ws, i + 3) {
                    return Issue(rule: "비교급 + than", why: "비교급 뒤에는 than: \(t) as ✗ → \(t) than", at: i + 1, fix: "than")
                }
            }
            if t == "than", next == "any", ws.at(i + 2) == "other", nounPlural(ws.at(i + 3)) == true, let s = singularOf[ws.at(i + 3)] {
                return Issue(rule: "비교급 + than any other + 단수", why: "than any other 뒤에는 단수 명사: \(ws.at(i + 3)) → \(s)", at: i + 3, fix: s)
            }
            if ["superior", "inferior", "senior", "junior"].contains(t), next == "than" {
                return Issue(rule: "라틴어 비교급", why: "\(t)는 than이 아니라 to와 써요.", at: i + 1, fix: "to")
            }
            if t == "no", next == "other", nounPlural(ws.at(i + 2)) == true, let s = singularOf[ws.at(i + 2)], beForms.contains(ws.at(i + 3)),
               degreeForms[ws.at(i + 4)] != nil || ["as", "more"].contains(ws.at(i + 4)) {
                return Issue(rule: "No other + 단수", why: "No other 뒤에는 단수 명사: \(ws.at(i + 2)) → \(s)", at: i + 2, fix: s)
            }
        }
        // prefer A to B
        if let p = ws.w.firstIndex(where: { ["prefer", "prefers", "preferred"].contains($0) }),
           let th = ws.w.indices.first(where: { $0 > p && $0 <= p + 5 && ws.w[$0] == "than" }), !ws.w.contains("rather"), !ws.w[(p + 1)..<th].contains("more") {
            return Issue(rule: "prefer A to B", why: "prefer A to B: than이 아니라 to를 써요.", at: th, fix: "to")
        }
        // the 비교급, the 비교급
        if ws.at(0) == "the", degreeForms[ws.at(1)].map({ !$0.superlative }) == true || ["more", "less", "better", "worse"].contains(ws.at(1)),
           let cut = ws.comma.firstIndex(of: true), ws.at(cut + 1) == "the" {
            let w = ws.at(cut + 2)
            if let f = degreeForms[w], f.superlative {
                return Issue(rule: "the 비교급, the 비교급", why: "뒤쪽도 비교급: \(w) → \(DoitEnglish.comparison(f.base).comparative.first ?? "")", at: cut + 2, fix: DoitEnglish.comparison(f.base).comparative.first)
            }
            if ["most", "least"].contains(w) { return Issue(rule: "the 비교급, the 비교급", why: "뒤쪽도 비교급: \(w) → \(w == "most" ? "more" : "less")", at: cut + 2, fix: w == "most" ? "more" : "less") }
            if DoitEnglish.commonAdjectives.contains(w), degreeForms[w] == nil, let c = DoitEnglish.comparison(w).comparative.first, c != w, !c.contains(" ") {
                return Issue(rule: "the 비교급, the 비교급", why: "뒤쪽도 비교급: \(w) → \(c)", at: cut + 2, fix: c)
            }
        }
        return nil
    }

    // MARK: 시간 전치사 in · on · at

    static func timePrepositions(_ ws: Words) -> Issue? {
        let days: Set<String> = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "mondays", "tuesdays",
                                 "wednesdays", "thursdays", "fridays", "saturdays", "sundays"]
        let months: Set<String> = ["january", "february", "march", "april", "june", "july", "august", "september", "october", "november", "december"]
        for i in ws.w.indices.dropLast() {
            let p = ws.w[i], n = ws.w[i + 1], after = ws.at(i + 2)
            guard ["in", "on", "at"].contains(p) else { continue }
            func bad(_ right: String, _ why: String) -> Issue { Issue(rule: "시간 전치사", why: why + " (\(p) ✗ → \(right))", at: i, fix: right) }
            if days.contains(n), p != "on" { return bad("on", "요일 앞에는 on") }
            if months.contains(n) {
                let date = after.range(of: #"^[0-9]{1,2}(st|nd|rd|th)?$"#, options: .regularExpression) != nil
                if date, p != "on" { return bad("on", "날짜(월 + 일) 앞에는 on") }
                if !date, p != "in", endsPhrase(ws, i + 2) || after == "of" && false { return bad("in", "달(月) 앞에는 in") }
            }
            if n.range(of: #"^(1[5-9]|20)[0-9]{2}$"#, options: .regularExpression) != nil, p != "in", endsPhrase(ws, i + 2) {
                return bad("in", "연도 앞에는 in")
            }
            if n.range(of: #"^[0-9]{1,2}(:[0-9]{2})?$"#, options: .regularExpression) != nil, ["o'clock", "a.m", "p.m", "am", "pm"].contains(after) || n.contains(":"), p != "at" {
                return bad("at", "시각 앞에는 at")
            }
            if ["noon", "midnight"].contains(n), p != "at" { return bad("at", "noon · midnight 앞에는 at") }
            if n == "night", p == "in", endsPhrase(ws, i + 2) { return bad("at", "'밤에'는 at night") }
            if ["morning", "afternoon", "evening"].contains(n), p == "at" || p == "on", endsPhrase(ws, i + 2) {
                return bad("in the", "아침·오후·저녁에는 in the …")
            }
            if n == "the", ["morning", "afternoon", "evening"].contains(after), p == "at", endsPhrase(ws, i + 3) {
                return bad("in", "in the morning / afternoon / evening")
            }
            if ["my", "his", "her", "your", "our", "their"].contains(n), after == "birthday", p != "on", endsPhrase(ws, i + 3) {
                return bad("on", "특정한 날(생일) 앞에는 on")
            }
            if n == "christmas", after == "day", p == "in" { return bad("on", "특정한 날 앞에는 on") }
        }
        return nil
    }

    // MARK: 전치사 없이 쓰는 동사 ("discuss about" · "resemble with" · "explain me")

    static func needlessPreposition(_ ws: Words) -> Issue? {
        for i in ws.w.indices.dropLast() {
            let t = ws.w[i], n = ws.w[i + 1]
            if ["discuss", "discusses", "discussed", "discussing"].contains(t), n == "about" {
                return Issue(rule: "타동사 + 목적어", why: "discuss는 전치사 없이 목적어를 바로 써요 (discuss about ✗).", at: i + 1, fix: "")
            }
            if ["mention", "mentions", "mentioned"].contains(t), n == "about" {
                return Issue(rule: "타동사 + 목적어", why: "mention은 전치사 없이 목적어를 바로 써요 (mention about ✗).", at: i + 1, fix: "")
            }
            if ["resemble", "resembles", "resembled"].contains(t), n == "with" || n == "to" {
                return Issue(rule: "타동사 + 목적어", why: "resemble은 전치사 없이 목적어를 바로 써요 (resemble \(n) ✗).", at: i + 1, fix: "")
            }
            if ["marry", "marries"].contains(t), n == "with" {
                return Issue(rule: "타동사 + 목적어", why: "marry는 전치사 없이 목적어를 바로 써요 (marry with ✗).", at: i + 1, fix: "")
            }
            if ["explain", "explains", "explained"].contains(t), ["me", "us"].contains(n), !endsPhrase(ws, i + 2) {
                return Issue(rule: "explain + 사물 + to 사람", why: "explain은 사람을 바로 목적어로 쓰지 않아요 (explain \(n) ✗ → explain … to \(n)).", at: i + 1)
            }
            if ["arrive", "arrives", "arrived"].contains(t), n == "to", !isBaseForm(ws.at(i + 2)) {
                return Issue(rule: "arrive at/in", why: "arrive는 to가 아니라 at(좁은 곳) · in(넓은 곳)과 써요.", at: i + 1, fix: "at")
            }
            if ["enter", "enters", "entered"].contains(t), n == "into", ws.at(i + 2) == "the", ["room", "house", "classroom", "building", "kitchen", "museum", "library"].contains(ws.at(i + 3)) {
                return Issue(rule: "타동사 + 목적어", why: "'~에 들어가다'의 enter는 전치사 없이 써요 (enter into ✗).", at: i + 1, fix: "")
            }
            if ["reach", "reached", "reaches"].contains(t), n == "to", ws.at(i + 2) == "the", ["station", "airport", "village", "city", "summit"].contains(ws.at(i + 3)) {
                return Issue(rule: "타동사 + 목적어", why: "'~에 도착하다'의 reach는 전치사 없이 써요 (reach to ✗).", at: i + 1, fix: "")
            }
        }
        return nil
    }

    // MARK: be동사와 일반동사를 함께 ("I am agree" · "He is live")

    static func beWithVerb(_ ws: Words) -> Issue? {
        for i in subjectSlots(ws) where personSubjects.contains(ws.w[i]) {
            guard beForms.contains(ws.at(i + 1)) else { continue }
            var j = i + 2
            if ws.at(j) == "not" { j += 1 }
            let v = ws.at(j)
            if ["agree", "disagree", "like", "want", "need", "know", "have"].contains(v), v != "like" || ws.at(j + 1) == "to" {
                return Issue(rule: "be동사와 일반동사", why: "be동사와 일반동사(\(v))를 함께 쓰지 않아요 (\(ws.raw[i + 1]) \(v) ✗).", at: i + 1, length: j - i, fix: nil)
            }
        }
        return nil
    }
}
