import Foundation

// MARK: - 영어 어법 규칙 (고1 ~ 수능 어법)
// 분사구문(능동·수동) · with + 명사 + 분사, 도치(부정어 · Only · So/Neither · 장소), 강조 It ~ that, 병렬구조, 동사 vs 준동사,
// 형용사 vs 부사(감각동사 보어), 재귀대명사, 대명사 that/those, 조동사 + have p.p. · used to · had better, 자동사·타동사(lie/lay, rise/raise),
// 명사절 that/what, 가목적어 it

extension DoitSentenceCheck {
    static let highRules: [(Words) -> Issue?] = [participleClause, inversionRules, soNeitherAgreement, placeInversion, cleftSentence,
                                                 parallelStructure, verbCount, adjectiveAdverb, reflexiveRules, thatThose, modalPerfect,
                                                 lieLayRiseRaise, nounClauseThatWhat, formalObjectIt]

    // MARK: 분사구문 (능동 · 수동) · with + 명사 + 분사

    static func participleClause(_ ws: Words) -> Issue? {
        let transitive: Set<String> = ["write", "build", "make", "paint", "design", "invent", "publish", "cook", "bake", "use", "sell", "give",
                                       "send", "take", "produce", "create", "grow", "wash", "see", "surround", "cover", "fill", "locate",
                                       "situate", "base", "found", "plant", "raise", "translate", "print", "store", "decorate", "carve"]
        let w0 = ws.at(0)
        if w0.hasSuffix("ing"), let b = base(w0), DoitEnglish.ingForm(b) == w0, transitive.contains(b),
           let cut = ws.comma.firstIndex(of: true), cut >= 1 {
            // 목적어 없이 바로 전치사·부사가 오면 (Written in English / Seen from the sky)
            let n = ws.at(1)
            let noObject = prepositionWords.contains(n) || ["by", "many", "long", "years", "carefully", "well", "beautifully", "only", "mainly", "first"].contains(n)
            if noObject, let np = nounPhrase(ws, at: cut + 1), thingNouns.contains(ws.w[np.head]) || ["island", "bridge", "castle", "letter", "report",
                                                                                                         "painting", "statue", "village", "tower", "temple",
                                                                                                         "novel", "poem", "house", "building", "city", "book", "food", "cake", "bread"].contains(ws.w[np.head]) {
                let pp = DoitEnglish.ppForms(b).first ?? b
                return Issue(rule: "분사구문 (수동)", why: "주어(\(ws.w[np.head]))가 '~되는' 것이라 과거분사로 시작해요: \(w0) → \(pp)", at: 0, fix: pp.capitalized)
            }
        }
        // 사물 명사 + 타동사 -ing + by 사람 ✗ ("The fish catching by my dad")
        for i in ws.w.indices.dropFirst() where ws.w[i].hasSuffix("ing") && ws.at(i + 1) == "by" {
            guard let b = base(ws.w[i]), DoitEnglish.ingForm(b) == ws.w[i], transitive.contains(b) || ["catch", "draw", "steal", "break", "find", "choose", "write"].contains(b) else { continue }
            let noun = ws.w[i - 1]
            guard isNoun(noun) || pluralOf[noun] != nil, !personNouns.contains(noun), !["people", "children", "students"].contains(noun) else { continue }
            let agent = ws.at(i + 2)
            guard ["him", "her", "them", "me", "us", "my", "his", "her", "their", "our", "the", "a"].contains(agent) || looksLikeName(ws, i + 2) else { continue }
            let pp = DoitEnglish.ppForms(b).first ?? b
            return Issue(rule: "현재분사 / 과거분사", why: "\(noun)이(가) '~된' 것이라 과거분사: \(ws.w[i]) → \(pp)", at: i, fix: pp)
        }
        // with + 신체 + -ing ✗ ("with his eyes closing")
        let body: Set<String> = ["eyes", "arms", "legs", "mouth", "hands", "fingers", "lips", "fists", "head", "eye", "arm", "leg", "hand"]
        let bodyVerbs: [String: String] = ["closing": "closed", "folding": "folded", "crossing": "crossed", "shutting": "shut", "raising": "raised",
                                           "close": "closed", "fold": "folded", "cross": "crossed", "tying": "tied", "covering": "covered", "opening": "opened"]
        for i in ws.w.indices where ws.w[i] == "with" {
            guard ["his", "her", "my", "their", "your", "our", "the"].contains(ws.at(i + 1)), body.contains(ws.at(i + 2)), let right = bodyVerbs[ws.at(i + 3)] else { continue }
            return Issue(rule: "with + 명사 + 분사", why: "\(ws.at(i + 2))이(가) '~된' 상태라 과거분사: \(ws.at(i + 3)) → \(right)", at: i + 3, fix: right)
        }
        return nil
    }

    // MARK: 부정어 · Only · Not until 도치

    static func inversionRules(_ ws: Words) -> Issue? {
        let w0 = ws.at(0)
        var k: Int?
        if negativeAdverbs.contains(w0), !ws.comma[0] { k = 1 }
        if w0 == "only", ["then", "recently", "later", "now", "once", "yesterday", "after", "when", "by", "in", "through"].contains(ws.at(1)) {
            // Only + 부사(구): 쉼표 없이 주어가 오는 자리까지
            if ["then", "recently", "later", "now", "once", "yesterday"].contains(ws.at(1)) { k = 2 }
            else if let np = nounPhrase(ws, at: 2) { k = np.end }
        }
        if w0 == "not", ws.at(1) == "until" {
            if ["yesterday", "then", "recently", "now"].contains(ws.at(2)) { k = 3 }
            else if ws.at(2) == "last", isNoun(ws.at(3)) || ["week", "year", "month", "night"].contains(ws.at(3)) { k = 4 }
            else if let np = nounPhrase(ws, at: 2) { k = np.end }
        }
        if let k, personSubjects.contains(ws.at(k)) || ["he", "she", "it"].contains(ws.at(k)) {
            if ws.comma[0..<k].contains(true) { return nil }
            let v = ws.at(k + 1)
            if isFiniteVerb(v) || isPlainBase(v) || modals.contains(v) {
                if w0 == "little", !["knew", "know", "did", "dreamed", "thought", "realized", "expected"].contains(v) { return nil }
                return Issue(rule: "부정어 도치", why: "\(ws.raw[0..<k].joined(separator: " "))가 문장 앞에 오면 '조동사(do/have/be) + 주어 + 동사' 어순 (\(ws.raw[k]) \(ws.raw[k + 1]) ✗)", at: k)
            }
        }
        // So + 형용사 + 주어 + be + that ✗ → So + 형용사 + be + 주어 + that
        if w0 == "so", isAdjectiveLike(ws.at(1)), personSubjects.contains(ws.at(2)) || ["he", "she", "it"].contains(ws.at(2)), beForms.contains(ws.at(3)), ws.at(4) == "that" {
            return Issue(rule: "So + 형용사 도치", why: "So + 형용사가 문장 앞이면 be동사 + 주어 어순: So \(ws.at(1)) \(ws.at(3)) \(ws.at(2)) that …", at: 2)
        }
        return nil
    }

    // MARK: so/neither + 조동사 + 주어 (앞 절의 동사에 맞춤)

    static func soNeitherAgreement(_ ws: Words) -> Issue? {
        guard ws.at(0) != "so", ws.at(0) != "neither", subjectPronouns.contains(ws.at(0)) || nounPhrase(ws, at: 0) != nil || looksLikeName(ws, 0) else { return nil }
        guard let t = ws.w.indices.first(where: { $0 >= 2 && ["so", "neither", "nor"].contains(ws.w[$0]) && (ws.comma[$0 - 1] || ws.w[$0 - 1] == "and") }) else { return nil }
        let aux = ws.at(t + 1), subj = ws.at(t + 2)
        guard subjectPronouns.contains(subj), endsPhrase(ws, t + 3) else { return nil }
        let start = subjectPronouns.contains(ws.at(0)) || looksLikeName(ws, 0) ? 1 : (nounPhrase(ws, at: 0)?.end ?? 1)
        let mainWords = ws.w[start..<t]
        let negative = mainWords.contains(where: { ["not", "never", "no"].contains($0) || $0.hasSuffix("n't") })
        var j = start
        while frequency.contains(ws.at(j)) { j += 1 }
        let v = ws.at(j)
        // 앞 절 동사의 종류
        var kind: String?
        if beForms.contains(v) || ["isn't", "aren't", "wasn't", "weren't"].contains(v) { kind = ["was", "were", "wasn't", "weren't"].contains(v) ? "be-past" : "be" }
        else if modals.contains(v) || ["can't", "won't", "couldn't", "shouldn't", "wouldn't"].contains(v) {
            kind = ["can't": "can", "won't": "will", "couldn't": "could", "shouldn't": "should", "wouldn't": "would"][v] ?? v
        }
        else if ["have", "has", "haven't", "hasn't"].contains(v), isPresentPerfect(ws, at: j) || v.hasSuffix("n't") { kind = "have" }
        else if ["did", "didn't"].contains(v) || isPastOnly(v) || (base(v).map { $0 != v && DoitEnglish.pastForms($0).contains(v) } ?? false) { kind = "did" }
        else if isThirdForm(v) || isPlainBase(v) || ["do", "does", "don't", "doesn't"].contains(v) { kind = "do" }
        guard let kind else { return nil }
        let soWord = ws.w[t]
        if soWord == "so", negative { return Issue(rule: "so / neither", why: "앞 절이 부정이면 neither(nor) + 조동사 + 주어 (so ✗)", at: t, fix: "neither") }
        if soWord != "so", !negative { return Issue(rule: "so / neither", why: "앞 절이 긍정이면 so + 조동사 + 주어 (\(soWord) ✗)", at: t, fix: "so") }
        let okAux: Set<String>
        switch kind {
        case "be": okAux = subj == "i" ? ["am"] : ["he", "she", "it"].contains(subj) ? ["is"] : ["are"]
        case "be-past": okAux = ["i", "he", "she", "it"].contains(subj) ? ["was"] : ["were"]
        case "have": okAux = ["he", "she", "it"].contains(subj) ? ["has"] : ["have"]
        case "did": okAux = ["did"]
        case "do": okAux = ["he", "she", "it"].contains(subj) ? ["does"] : ["do"]
        default: okAux = [kind]
        }
        if !okAux.contains(aux) {
            return Issue(rule: "so / neither + 조동사", why: "앞 절의 동사(\(v))와 주어(\(subj))에 맞춰: \(soWord) \(aux) \(subj) → \(soWord) \(okAux.first ?? "") \(subj)", at: t + 1, fix: okAux.first)
        }
        return nil
    }

    // MARK: 장소 · Here 도치의 수일치 ("Here is your books" · "On the hill stand a castle")

    static func placeInversion(_ ws: Words) -> Issue? {
        var v: Int?
        if ws.at(0) == "here" || ws.at(0) == "there" && ["comes", "come", "goes", "go"].contains(ws.at(1)) { v = 1 }
        else if prepositionWords.contains(ws.at(0)), ws.at(0) != "of", let np = nounPhrase(ws, at: 1) {
            var e = np.end
            if ws.at(e) == "of", let more = nounPhrase(ws, at: e + 1) { e = more.end }
            if !ws.comma[e - 1] { v = e }
        }
        guard let vi = v else { return nil }
        let verb = ws.at(vi)
        let movers: Set<String> = ["is", "are", "was", "were", "stands", "stand", "lies", "lie", "sits", "sit", "lives", "live", "comes", "come",
                                   "goes", "go", "hangs", "hang", "remains", "remain", "rises", "rise", "grows", "grow", "exists", "exist", "stood", "lay"]
        guard movers.contains(verb), let np = nounPhrase(ws, at: vi + 1), let plural = np.plural, endsPhrase(ws, np.end) || ["who", "that", "which", "with", "in", "on"].contains(ws.at(np.end)) else { return nil }
        if ws.at(0) == "here", subjectPronouns.contains(ws.at(vi + 1)) { return nil }
        guard let vn = verbNumber(verb) ?? (isPlainBase(verb) ? true : nil), vn != plural else { return nil }
        return Issue(rule: "도치된 문장의 수일치", why: "동사 뒤로 간 주어(\(ws.raw[np.start..<np.end].joined(separator: " ")))에 맞춰요: \(verb) → \(flipNumber(verb) ?? "")", at: vi, fix: flipNumber(verb))
    }

    // MARK: 강조 It is ~ that

    static func cleftSentence(_ ws: Words) -> Issue? {
        guard ws.at(0) == "it", ["is", "was"].contains(ws.at(1)) else { return nil }
        guard let w = ws.w.indices.first(where: { $0 >= 3 && ["which", "what"].contains(ws.w[$0]) }) else { return nil }
        let focus = Array(ws.w[2..<w])
        let timeFocus = focus.count <= 3 && (focus.first.map { ["yesterday", "then", "last", "today"].contains($0) } ?? false || focus.last == "ago")
        if timeFocus {
            return Issue(rule: "강조 구문 It ~ that", why: "It is/was + 강조할 말 + that … (때를 강조할 때 \(ws.w[w]) ✗)", at: w, fix: "that")
        }
        // It was in the park which I met him (전치사구 강조 + 완전한 절)
        if let p = focus.first, prepositionWords.contains(p), focus.count <= 4, personSubjects.contains(ws.at(w + 1)), isFiniteVerb(ws.at(w + 2)),
           ["him", "her", "them", "me", "us", "it"].contains(ws.at(w + 3)) {
            return Issue(rule: "강조 구문 It ~ that", why: "전치사구를 강조하는 It ~ that 구문이에요 (\(ws.w[w]) ✗ → that).", at: w, fix: "that")
        }
        return nil
    }

    // MARK: 병렬구조

    static func parallelStructure(_ ws: Words) -> Issue? {
        // 동사 + -ing … and/or + to 원형 (같은 동사의 목적어끼리 모양을 맞춰요)
        for i in ws.w.indices where ["and", "or"].contains(ws.w[i]) && i >= 2 {
            let after = ws.at(i + 1)
            // 앞쪽: 목적어 모양을 정하는 동사 (enjoy · like · want …) 바로 뒤
            let governing: Set<String> = ["enjoy", "enjoys", "enjoyed", "like", "likes", "liked", "love", "loves", "loved", "hate", "hates", "finish", "finished",
                                          "practice", "practiced", "avoid", "avoided", "keep", "kept", "mind", "want", "wants", "wanted", "hope", "hoped",
                                          "plan", "planned", "decide", "decided", "need", "needs", "needed", "would"]
            guard let first = ws.w[..<i].indices.last(where: { governing.contains(ws.w[$0]) }) else { continue }
            let objStart = first + 1
            let o = ws.at(objStart)
            if ws.w[(objStart)..<i].contains(where: { ["and", "or", "but", "that", "who", "which", "because", "when"].contains($0) }) || ws.comma[objStart..<i].contains(true) && i - objStart > 6 { continue }
            if o.hasSuffix("ing"), let b = base(o), DoitEnglish.ingForm(b) == o, after == "to", isBaseForm(ws.at(i + 2)) || base(ws.at(i + 2)) == ws.at(i + 2),
               ["enjoy", "enjoys", "enjoyed", "like", "likes", "liked", "love", "loves", "loved", "hate", "hates", "finish", "finished", "practice", "practiced", "avoid", "avoided", "keep", "kept", "mind"].contains(ws.w[first]) {
                return Issue(rule: "병렬구조", why: "and/or로 이어진 말은 모양을 맞춰요: \(o) … and to \(ws.at(i + 2)) → \(DoitEnglish.ingForm(ws.at(i + 2)))", at: i + 1, length: 2, fix: DoitEnglish.ingForm(ws.at(i + 2)))
            }
            if o == "to", isBaseForm(ws.at(objStart + 1)), after.hasSuffix("ing"), let b = base(after), DoitEnglish.ingForm(b) == after, !ingNouns.contains(after),
               ["want", "wants", "wanted", "hope", "hoped", "plan", "planned", "decide", "decided", "like", "love", "need", "needs", "needed", "would"].contains(ws.w[first]) {
                // 뒤에 다시 동사가 오면 (… and watching TV is fun) 새 절이에요
                if ws.w[(i + 2)...].contains(where: { isFiniteVerb($0) }) { continue }
                return Issue(rule: "병렬구조", why: "and/or로 이어진 말은 모양을 맞춰요: to \(ws.at(objStart + 1)) … and \(after) → (to) \(b)", at: i + 1, fix: b)
            }
        }
        // 주어 + 과거형/3인칭 … and + 원형 (주어 없이 이어지는 두 번째 동사)
        let starts = subjectSlots(ws).filter { personSubjects.contains(ws.w[$0]) }
        guard let s = starts.first, s == 0 else { return nil }
        var j = s + 1
        while frequency.contains(ws.at(j)) { j += 1 }
        let v1 = ws.at(j)
        let past = isPastOnly(v1) || (base(v1).map { $0 != v1 && DoitEnglish.pastForms($0).contains(v1) && v1.hasSuffix("ed") } ?? false)
        let third = isThirdForm(v1) && ["he", "she"].contains(ws.w[s])
        guard past || third, let a = ws.w.indices.first(where: { $0 > j && ws.w[$0] == "and" }) else { return nil }
        let between = ws.w[(j + 1)..<a]
        let blockers: Set<String> = ["to", "let", "make", "made", "help", "helped", "have", "had", "see", "saw", "watch", "watched", "hear", "heard",
                                     "please", "will", "can", "would", "could", "should", "must", "and", "or", "but", "that", "who", "which", "when", "if", "because"]
        if between.contains(where: { blockers.contains($0) || isFiniteVerb($0) || modals.contains($0) }) || ws.comma[j..<a].contains(true) || between.count > 6 { return nil }
        let v2 = ws.at(a + 1)
        guard isPlainBase(v2), actionVerbs.contains(v2), !nounishVerbs.contains(v2) || ["the", "a", "an", "my", "his", "her", "their", "our", "some", "to", "home", "him", "her", "them", "it", "me", "us", "in", "out", "away", "up", "down", "back", "inside", "outside", "around", "into"].contains(ws.at(a + 2)) else { return nil }
        if subjectPronouns.contains(ws.at(a + 2)) { return nil }
        let right = past ? (DoitEnglish.pastForms(v2).first ?? v2) : DoitEnglish.thirdPerson(v2)
        return Issue(rule: "병렬구조 (동사 시제)", why: "and로 이어진 두 동사는 같은 모양: \(v1) … and \(v2) → \(right)", at: a + 1, fix: right)
    }

    // MARK: 동사 vs 준동사 (한 절에 동사는 하나)

    static func verbCount(_ ws: Words) -> Issue? {
        // 명사 + 3인칭 동사 … + be동사 (관계대명사 없이 동사가 둘): "The man lives next door is kind."
        let clauseJoiners: Set<String> = ["that", "who", "which", "whom", "whose", "and", "but", "or", "because", "when", "if", "while", "although",
                                          "though", "so", "as", "since", "after", "before", "until", "where", "what", "how", "why", "than"]
        if !ws.w.contains(where: clauseJoiners.contains), !ws.comma.contains(true), let np = nounPhrase(ws, at: 0), np.plural == false {
            let v = ws.at(np.end)
            let verbsOnly: Set<String> = ["lives", "stands", "sits", "wants", "likes", "loves", "goes", "comes", "teaches", "speaks", "knows", "sings",
                                          "wears", "owns", "drives", "runs", "plays", "works", "sells", "makes", "writes", "lived", "stood", "wanted"]
            if verbsOnly.contains(v), let be = ws.w.indices.first(where: { $0 > np.end + 1 && ["is", "was", "are", "were"].contains(ws.w[$0]) }) {
                // 그 사이에 주어 대명사가 없어야 (The man lives where he is happy 같은 건 위에서 걸러짐)
                if !ws.w[(np.end + 1)..<be].contains(where: { subjectPronouns.contains($0) || isFiniteVerb($0) }) {
                    let fix = v.hasSuffix("s") ? DoitEnglish.ingForm(base(v) ?? v) : nil
                    return Issue(rule: "동사 vs 준동사", why: "한 문장에 동사가 둘(\(v), \(ws.w[be]))이면 앞의 것은 준동사(-ing)나 관계대명사절로: \(v) → \(fix ?? "who \(v)")", at: np.end, fix: fix)
                }
            }
        }
        // 주어 + -ing (be동사 없음): "He going to school every day."
        for i in subjectSlots(ws) where personSubjects.contains(ws.w[i]) {
            var j = i + 1
            while frequency.contains(ws.at(j)) { j += 1 }
            let v = ws.at(j)
            guard v.hasSuffix("ing"), let b = base(v), DoitEnglish.ingForm(b) == v, actionVerbs.contains(b), !ingNouns.contains(v), !ws.question else { continue }
            if i > 0, ["with", "of", "about", "for", "without", "by"].contains(ws.at(i - 1)) { continue }
            let be = ws.w[i] == "i" ? "am" : ["he", "she"].contains(ws.w[i]) ? "is" : "are"
            return Issue(rule: "동사가 없는 문장", why: "주어 뒤에 동사가 있어야 해요: \(v) → \(be) \(v)", at: j, fix: "\(be) \(v)")
        }
        return nil
    }

    // MARK: 형용사 vs 부사

    static func adjectiveAdverb(_ ws: Words) -> Issue? {
        let linking: Set<String> = ["look", "looks", "looked", "sound", "sounds", "sounded", "smell", "smells", "smelled", "taste", "tastes",
                                    "tasted", "feel", "feels", "felt", "seem", "seems", "seemed", "become", "becomes", "became"]
        let mannerOK: Set<String> = ["at", "for", "around", "into", "through", "up", "down", "out", "after", "over", "back", "away", "in", "like", "as"]
        for i in ws.w.indices where linking.contains(ws.w[i]) {
            var k = i + 1
            if ["very", "so", "really", "too", "quite", "pretty", "extremely"].contains(ws.at(k)) { k += 1 }
            let adv = ws.at(k)
            guard let adj = adjectiveOfAdverb(adv), adv != "badly", adv != "early", adv != "friendly", adv != "lovely", adv != "only" else { continue }
            let next = ws.at(k + 1)
            if mannerOK.contains(next) { continue }
            guard endsPhrase(ws, k + 1) || ["to", "today", "now", "after", "when", "because"].contains(next) else { continue }
            return Issue(rule: "감각동사 + 형용사", why: "\(ws.w[i])의 보어 자리에는 형용사: \(adv) → \(adj)", at: k, fix: adj)
        }
        // 동작 동사 + 형용사 (문장 끝) → 부사 ("She sings beautiful.")
        let actions: Set<String> = ["sing", "sings", "sang", "speak", "speaks", "spoke", "dance", "dances", "danced", "drive", "drives", "drove",
                                    "walk", "walks", "walked", "talk", "talks", "talked", "play", "plays", "played", "write", "writes", "wrote",
                                    "work", "works", "worked", "run", "runs", "ran", "cook", "cooks", "cooked", "answer", "answered", "behave", "behaved", "smile", "smiled", "smiles"]
        let manner: [String: String] = ["beautiful": "beautifully", "careful": "carefully", "careless": "carelessly", "quiet": "quietly",
                                        "happy": "happily", "nervous": "nervously", "polite": "politely", "perfect": "perfectly", "terrible": "terribly",
                                        "wonderful": "wonderfully", "serious": "seriously", "honest": "honestly", "brave": "bravely", "kind": "kindly",
                                        "angry": "angrily", "sad": "sadly", "easy": "easily", "safe": "safely", "patient": "patiently", "excellent": "excellently"]
        for i in ws.w.indices where actions.contains(ws.w[i]) && i > 0 {
            let a = ws.at(i + 1)
            guard let right = manner[a], endsPhrase(ws, i + 2) || ["every", "today", "yesterday", "at", "in", "on", "last"].contains(ws.at(i + 2)) else { continue }
            if ["the", "a", "an", "to"].contains(ws.w[i - 1]) { continue }
            return Issue(rule: "동사를 꾸미는 부사", why: "동사(\(ws.w[i]))를 꾸미는 말은 부사: \(a) → \(right)", at: i + 1, fix: right)
        }
        for i in ws.w.indices.dropLast() {
            let t = ws.w[i], n = ws.w[i + 1]
            // be + terrible/extreme + 형용사 → 부사
            if ["terrible", "extreme", "incredible", "awful", "surprising", "amazing", "real", "unbelievable", "perfect"].contains(t), i > 0,
               beForms.contains(ws.w[i - 1]) || ["looks", "looked", "seems", "seemed", "feel", "felt"].contains(ws.w[i - 1]),
               DoitEnglish.commonAdjectives.contains(n) || ["beautiful", "important", "difficult", "expensive", "delicious", "dangerous", "popular", "tired", "boring", "interesting"].contains(n),
               !isNoun(n), endsPhrase(ws, i + 2) || ["to", "for", "that"].contains(ws.at(i + 2)) {
                let ly = t == "terrible" ? "terribly" : t == "incredible" ? "incredibly" : t == "unbelievable" ? "unbelievably" : t == "real" ? "really" : t + "ly"
                return Issue(rule: "형용사를 꾸미는 부사", why: "형용사(\(n))를 꾸미는 말은 부사: \(t) → \(ly)", at: i, fix: ly)
            }
            // work hardly → hard, arrive lately → late
            if ["work", "works", "worked", "study", "studies", "studied", "try", "tries", "tried", "train", "trained", "practice", "practiced"].contains(t), n == "hardly",
               endsPhrase(ws, i + 2) || ["to", "for", "every", "all", "at", "in"].contains(ws.at(i + 2)) {
                return Issue(rule: "hard / hardly", why: "'열심히'는 hard (hardly는 '거의 ~않다')", at: i + 1, fix: "hard")
            }
            if ["arrive", "arrived", "arrives", "came", "come", "comes"].contains(t), n == "lately" {
                return Issue(rule: "late / lately", why: "'늦게'는 late (lately는 '최근에')", at: i + 1, fix: "late")
            }
            // make + 사람 + 감정 부사 ✗
            if ["make", "makes", "made", "keep", "keeps", "kept"].contains(t), ["me", "him", "her", "us", "them"].contains(n),
               let adj = adjectiveOfAdverb(ws.at(i + 2)), ["happily", "sadly", "angrily", "nervously", "calmly", "comfortably", "safely", "warmly"].contains(ws.at(i + 2)), endsPhrase(ws, i + 3) {
                if t.hasPrefix("k"), ["safely", "warmly", "calmly"].contains(ws.at(i + 2)) { continue }
                return Issue(rule: "목적격 보어는 형용사", why: "목적어(\(n))의 상태를 말하는 보어는 형용사: \(ws.at(i + 2)) → \(adj)", at: i + 2, fix: adj)
            }
        }
        return nil
    }

    // MARK: 재귀대명사

    static func reflexiveRules(_ ws: Words) -> Issue? {
        let reflexiveOwner = Dictionary(uniqueKeysWithValues: reflexives.map { ($0.value, $0.key) })
        // 재귀대명사 주어 ✗
        if let owner = reflexiveOwner[ws.at(0)], isFiniteVerb(ws.at(1)) {
            return Issue(rule: "재귀대명사", why: "재귀대명사는 주어 자리에 쓰지 않아요: \(ws.at(0)) → \(owner == "i" ? "I" : owner)", at: 0, fix: owner == "i" ? "I" : owner.capitalized)
        }
        for i in subjectSlots(ws) {
            let s = ws.w[i]
            guard reflexives[s] != nil else { continue }
            var j = i + 1
            while frequency.contains(ws.at(j)) { j += 1 }
            let v = ws.at(j)
            guard isFiniteVerb(v) || isPlainBase(v) || sameBasePast.contains(v), !beForms.contains(v), !modals.contains(v), !["let", "lets", "made", "make", "had", "have", "has", "do", "does", "did", "don't", "doesn't", "didn't"].contains(v) else { continue }
            var o = ws.at(j + 1)
            var oAt = j + 1
            if ["at", "to"].contains(o), ["look", "looked", "looks", "talk", "talked", "laugh", "laughed", "smile", "smiled"].contains(v) { o = ws.at(j + 2); oAt = j + 2 }
            // I + 동사 + me ✗ (같은 사람이면 재귀대명사)
            if (s == "i" && o == "me") || (s == "we" && o == "us"), endsPhrase(ws, oAt + 1) || prepositionWords.contains(ws.at(oAt + 1)) || ["very", "a", "in", "at"].contains(ws.at(oAt + 1)) {
                if ["told", "asked", "let", "help", "helped"].contains(v) { continue }
                return Issue(rule: "재귀대명사", why: "목적어가 주어와 같은 사람이면 재귀대명사: \(o) → \(reflexives[s]!)", at: oAt, fix: reflexives[s])
            }
            // 주어와 맞지 않는 재귀대명사 ("He hurt myself")
            if let owner = reflexiveOwner[o], owner != s, ["myself", "yourself", "himself", "herself", "ourselves", "themselves"].contains(o), s != "you" || !["yourselves"].contains(o) {
                if s == "it" { continue }
                return Issue(rule: "재귀대명사", why: "주어(\(ws.raw[i]))와 같은 사람을 가리키는 재귀대명사는 \(reflexives[s]!) (\(o) ✗)", at: j + 1, fix: reflexives[s])
            }
        }
        return nil
    }

    // MARK: 비교 대상의 대명사 that / those

    static func thatThose(_ ws: Words) -> Issue? {
        guard let np = nounPhrase(ws, at: 0), let plural = np.plural, ws.at(np.end) == "of" || isFiniteVerb(ws.at(np.end)) else { return nil }
        for i in ws.w.indices where ["than", "as", "with", "to"].contains(ws.w[i]) && i > np.end {
            let p = ws.at(i + 1)
            if ["it", "this", "these", "they", "them"].contains(p), ws.at(i + 2) == "of", ws.w[i] == "than" {
                return Issue(rule: "대명사 that / those", why: "앞에 나온 명사를 다시 가리키는 말은 \(plural ? "those" : "that") (\(p) ✗)", at: i + 1, fix: plural ? "those" : "that")
            }
            guard ["that", "those"].contains(p), ws.at(i + 2) == "of" || ws.at(i + 2) == "in" else { continue }
            if ws.w[i] == "to" || ws.w[i] == "with", !ws.w[..<i].contains(where: { ["compared", "similar", "different", "comparable"].contains($0) }) { continue }
            if p == "that", plural { return Issue(rule: "대명사 that / those", why: "비교하는 말(\(ws.w[np.head]))이 복수라 those (that ✗)", at: i + 1, fix: "those") }
            if p == "those", !plural { return Issue(rule: "대명사 that / those", why: "비교하는 말(\(ws.w[np.head]))이 단수라 that (those ✗)", at: i + 1, fix: "that") }
        }
        return nil
    }

    // MARK: 조동사 + have p.p. · used to · had better · would rather · cannot but

    static func modalPerfect(_ ws: Words) -> Issue? {
        for i in ws.w.indices.dropLast(2) where ["must", "should", "could", "might", "may", "would", "cannot", "can't", "couldn't", "shouldn't", "needn't"].contains(ws.w[i]) {
            var j = i + 1
            if ws.at(j) == "not" { j += 1 }
            guard ws.at(j) == "have" else { continue }
            let v = ws.at(j + 1)
            if isPastOnly(v), let b = base(v), !isNoun(v) {
                return Issue(rule: "조동사 + have p.p.", why: "\(ws.w[i]) have 뒤에는 과거분사: \(v) → \(DoitEnglish.ppForms(b).first ?? v)", at: j + 1, fix: DoitEnglish.ppForms(b).first)
            }
            if isPlainBase(v), let pp = DoitEnglish.ppForms(v).first, pp != v, actionVerbs.contains(v), v != "to" {
                if ws.at(j + 1) == "to" { continue }
                return Issue(rule: "조동사 + have p.p.", why: "\(ws.w[i]) have 뒤에는 과거분사: \(v) → \(pp)", at: j + 1, fix: pp)
            }
        }
        let line = " " + ws.w.joined(separator: " ") + " "
        // had better + 원형
        if let r = line.range(of: #" (had|'d) better (not )?to "#, options: .regularExpression) {
            let idx = line[..<r.upperBound].split(separator: " ").count - 1
            return Issue(rule: "had better + 동사원형", why: "had better 뒤에는 to 없이 동사원형 (had better (not) to ✗)", at: idx, fix: "")
        }
        if let r = line.range(of: #"\b(had|you'd|i'd|we'd|he'd|she'd|they'd) better (not )?"#, options: .regularExpression) {
            let after = line[r.upperBound...].split(separator: " ").first.map(String.init) ?? ""
            if after.hasSuffix("ing"), let b = base(after), DoitEnglish.ingForm(b) == after, actionVerbs.contains(b) {
                return Issue(rule: "had better + 동사원형", why: "had better 뒤에는 동사원형: \(after) → \(b)", at: ws.w.firstIndex(of: after), fix: b)
            }
        }
        if line.range(of: #" would rather (not )?to "#, options: .regularExpression) != nil {
            return Issue(rule: "would rather + 동사원형", why: "would rather 뒤에는 to 없이 동사원형", at: ws.w.firstIndex(of: "to"), fix: "")
        }
        // used to + 원형 (be/get used to 아님): "I used to playing" ✗
        for i in ws.w.indices where ws.w[i] == "used" && ws.at(i + 1) == "to" && i > 0 {
            let prev = ws.w[i - 1]
            if beForms.contains(prev) || ["get", "gets", "got", "getting", "become", "became", "be", "been"].contains(prev) { continue }
            guard personSubjects.contains(prev) || ["never", "always", "often"].contains(prev) || nounPhrase(ws, at: max(0, i - 2))?.end == i else { continue }
            let v = ws.at(i + 2)
            if v.hasSuffix("ing"), let b = base(v), DoitEnglish.ingForm(b) == v, actionVerbs.contains(b), !ingNouns.contains(v) {
                return Issue(rule: "used to + 동사원형", why: "'~하곤 했다'는 used to + 동사원형: \(v) → \(b)", at: i + 2, fix: b)
            }
        }
        // 주어 + use to ✗ (did/didn't 뒤 빼고)
        for i in ws.w.indices.dropFirst() where ws.w[i] == "use" && ws.at(i + 1) == "to" && personSubjects.contains(ws.w[i - 1]) && isBaseForm(ws.at(i + 2)) {
            return Issue(rule: "used to", why: "'~하곤 했다'는 used to (use to ✗)", at: i, fix: "used")
        }
        // cannot but + 원형
        if let r = line.range(of: #" (cannot|can't|couldn't) but "#, options: .regularExpression) {
            let after = line[r.upperBound...].split(separator: " ").first.map(String.init) ?? ""
            if after.hasSuffix("ing"), let b = base(after), DoitEnglish.ingForm(b) == after {
                return Issue(rule: "cannot but + 동사원형", why: "cannot but 뒤에는 동사원형: \(after) → \(b)", at: ws.w.firstIndex(of: after), fix: b)
            }
        }
        return nil
    }

    // MARK: 자동사 · 타동사 (lie / lay, rise / raise)

    static func lieLayRiseRaise(_ ws: Words) -> Issue? {
        let places: Set<String> = ["on", "in", "under", "beside", "down", "around", "there", "here", "still", "awake", "asleep", "at", "near"]
        for i in ws.w.indices {
            let t = ws.w[i], n = ws.at(i + 1)
            // be laying on ✗ → lying
            if t == "laying", i > 0, beForms.contains(ws.w[i - 1]) || ws.w[i - 1] == "been", places.contains(n) {
                return Issue(rule: "lie / lay", why: "'눕다·놓여 있다'는 자동사 lie (lying): laying은 '놓는'(목적어 필요)", at: i, fix: "lying")
            }
            if t == "lays", i > 0, subjectPronouns.contains(ws.w[i - 1]) || nounPhrase(ws, at: max(0, i - 2))?.end == i, places.contains(n) {
                return Issue(rule: "lie / lay", why: "'눕다'는 lie (lies): lays는 '~을 놓다'", at: i, fix: "lies")
            }
            if t == "laid", i > 0, personSubjects.contains(ws.w[i - 1]), ["on", "down", "in"].contains(n), !["it", "them", "the", "a", "his", "her", "my"].contains(ws.at(i + 2)) || n == "on" && ["the", "a", "his", "her", "my"].contains(ws.at(i + 2)) && ["bed", "sofa", "floor", "grass", "ground", "beach", "couch"].contains(ws.at(i + 3)) {
                if n == "down", ["the", "his", "her", "my", "a"].contains(ws.at(i + 2)) { continue }   // laid down the book (놓았다)
                return Issue(rule: "lie / lay", why: "'누웠다'는 lie의 과거 lay (laid는 '~을 놓았다')", at: i, fix: "lay")
            }
            if t == "lied", ["on", "in"].contains(n), ["the", "a", "his", "her", "my"].contains(ws.at(i + 2)), ["bed", "sofa", "floor", "grass", "ground", "beach", "couch"].contains(ws.at(i + 3)) {
                return Issue(rule: "lie / lay", why: "'누웠다'는 lie의 과거 lay (lied는 '거짓말했다')", at: i, fix: "lay")
            }
            if t == "laying", i > 0, isNoun(ws.w[i - 1]), ["on", "in", "under", "beside", "around", "near"].contains(n) {
                return Issue(rule: "lie / lay", why: "'놓여 있는'은 자동사 lie의 -ing (lying): laying은 '~을 놓는'", at: i, fix: "lying")
            }
            // raise + 목적어 없음 ✗ ("The sun raises in the east")
            if ["raise", "raises", "raised"].contains(t), i > 0, !beForms.contains(ws.w[i - 1]), ws.w[i - 1] != "been", ["in", "up", "from", "every", "by", "to", "above", "into"].contains(n),
               i == 1 || nounPhrase(ws, at: max(0, i - 2))?.end == i || subjectPronouns.contains(ws.w[i - 1]) {
                if n == "up" || n == "by" && t == "raised" || n == "to" { continue }
                let right = t == "raise" ? "rise" : t == "raises" ? "rises" : "rose"
                return Issue(rule: "rise / raise", why: "목적어 없이 '오르다'는 자동사 rise: \(t) → \(right)", at: i, fix: right)
            }
            // rise + 목적어 ✗ ("He rose his hand")
            if ["rise", "rises", "rose", "risen"].contains(t), ["his", "her", "my", "your", "their", "our", "its"].contains(n), isNoun(ws.at(i + 2)) || ["hand", "hands", "voice", "prices", "glass", "trunk", "head", "arm", "arms"].contains(ws.at(i + 2)) {
                let right = ["rise": "raise", "rises": "raises", "rose": "raised", "risen": "raised"][t]!
                return Issue(rule: "rise / raise", why: "'~을 올리다'는 타동사 raise: \(t) → \(right)", at: i, fix: right)
            }
        }
        return nil
    }

    // MARK: 명사절 that / what

    static func nounClauseThatWhat(_ ws: Words) -> Issue? {
        let objectVerbs: Set<String> = ["want", "wants", "wanted", "need", "needs", "needed", "like", "likes", "liked", "love", "loved", "bought",
                                        "said", "did", "made", "saw", "have", "has", "had", "ate", "wrote", "heard", "found", "say", "says", "do",
                                        "does", "make", "makes", "see", "know", "knew", "told", "learned", "chose", "did"]
        // That + 주어 + 타동사 + be ✗ → What
        if ws.at(0) == "that", personSubjects.contains(ws.at(1)) || ["he", "she"].contains(ws.at(1)), objectVerbs.contains(ws.at(2)), ["is", "was", "are", "were"].contains(ws.at(3)) {
            return Issue(rule: "명사절 what", why: "\(ws.at(2))의 목적어가 빠진 불완전한 절이라 what (That ✗)", at: 0, fix: "What")
        }
        // What + 주어 + be + 형용사 + be ✗ → That (완전한 절)
        if ws.at(0) == "what", personSubjects.contains(ws.at(1)) || ["he", "she", "it"].contains(ws.at(1)), beForms.contains(ws.at(2)),
           adjectiveWords.contains(ws.at(3)) || ["honest", "lying", "right", "wrong", "true", "alive", "sick", "innocent"].contains(ws.at(3)), ["is", "was"].contains(ws.at(4)) {
            return Issue(rule: "명사절 that", why: "뒤가 완전한 절이라 that (What ✗)", at: 0, fix: "That")
        }
        for i in ws.w.indices.dropFirst() where ws.w[i] == "what" {
            let prev = ws.w[i - 1]
            // hope + what ✗
            if ["hope", "hopes", "hoped"].contains(prev), personSubjects.contains(ws.at(i + 1)) || ["he", "she", "it"].contains(ws.at(i + 1)) {
                return Issue(rule: "명사절 that", why: "hope 뒤 완전한 절은 that (what ✗)", at: i, fix: "that")
            }
            // the fact/news/idea + what ✗ (동격)
            if ["fact", "news", "idea", "belief", "rumor", "truth", "evidence", "possibility"].contains(prev), i >= 2, ws.w[i - 2] == "the",
               personSubjects.contains(ws.at(i + 1)) || ["he", "she", "it"].contains(ws.at(i + 1)) || nounPhrase(ws, at: i + 1) != nil {
                return Issue(rule: "동격의 that", why: "the \(prev) + 완전한 절(동격)은 that (what ✗)", at: i, fix: "that")
            }
            // think/believe/know + what + 주어 + be + 형용사 (완전한 절)
            if ["think", "thinks", "thought", "believe", "believes", "believed", "say", "says", "said", "realize", "realized", "felt", "feel", "learned"].contains(prev),
               personSubjects.contains(ws.at(i + 1)) || ["he", "she", "it"].contains(ws.at(i + 1)), beForms.contains(ws.at(i + 2)),
               adjectiveWords.contains(ws.at(i + 3)) || ["honest", "right", "wrong", "true", "sick", "innocent", "kind"].contains(ws.at(i + 3)), endsPhrase(ws, i + 4) {
                return Issue(rule: "명사절 that", why: "\(prev) 뒤 완전한 절(주어 + be + 형용사)은 that (what ✗)", at: i, fix: "that")
            }
        }
        return nil
    }

    // MARK: 가목적어 it ("I found difficult to solve")

    static func formalObjectIt(_ ws: Words) -> Issue? {
        let verbs: Set<String> = ["find", "finds", "found", "think", "thinks", "thought", "make", "makes", "made", "consider", "considered", "believe",
                                  "believed", "feel", "felt"]
        let adjectives: Set<String> = ["difficult", "hard", "easy", "important", "impossible", "possible", "necessary", "interesting", "dangerous",
                                       "useful", "fun", "boring", "exciting", "safe", "natural", "strange", "helpful", "convenient", "a"]
        for i in ws.w.indices where verbs.contains(ws.w[i]) {
            let a = ws.at(i + 1)
            guard adjectives.contains(a), a != "a" else { continue }
            if ws.at(i + 2) == "to", isBaseForm(ws.at(i + 3)) || ws.at(i + 3) == "be" {
                return Issue(rule: "가목적어 it", why: "to부정사가 진짜 목적어면 가목적어 it을 써요: \(ws.w[i]) \(a) to … → \(ws.w[i]) it \(a) to …", at: i + 1, fix: "it " + ws.raw[i + 1])
            }
            if ws.at(i + 2) == "for", ["me", "him", "her", "us", "them", "you"].contains(ws.at(i + 3)), ws.at(i + 4) == "to" {
                return Issue(rule: "가목적어 it", why: "가목적어 it이 필요해요: \(ws.w[i]) it \(a) for … to …", at: i + 1, fix: "it " + ws.raw[i + 1])
            }
        }
        return nil
    }
}
