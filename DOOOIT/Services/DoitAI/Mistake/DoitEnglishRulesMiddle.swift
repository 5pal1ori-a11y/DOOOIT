import Foundation

// MARK: - 영어 어법 규칙 (중2 ~ 중3)
// 현재완료 · 수동태 · to부정사 · 동명사 · 분사(감정) · 관계대명사 · 관계부사 · 접속사 · 간접의문문 · 부가의문문 · 가정법 ·
// 사역/지각동사 · 수일치(학문명 · 부분 표현 · 동명사 주어)

extension DoitSentenceCheck {
    static let middleRules: [(Words) -> Issue?] = [presentPerfectRules, passiveRules, infinitiveRules, gerundRules, emotionParticiple,
                                                   relativeRules, relativeAdverbRules, relativeAgreement, conjunctionRules, correlativeRules,
                                                   adverbClauseWill, indirectQuestion, tagQuestion, subjunctiveRules, objectComplement,
                                                   agreementMisc]

    // MARK: 현재완료

    static func presentPerfectRules(_ ws: Words) -> Issue? {
        // When + 현재완료 의문문 ("When have you finished it?")
        if ws.question, ws.at(0) == "when", ["have", "has"].contains(ws.at(1)), subjectPronouns.contains(ws.at(2)) || nounPhrase(ws, at: 2) != nil {
            return Issue(rule: "when과 현재완료", why: "when(언제)은 정확한 때를 묻는 말이라 현재완료와 쓰지 않아요 (→ When did …?)", at: 1)
        }
        for i in ws.w.indices where ["have", "has", "had", "'ve", "'s"].contains(ws.w[i]) || ws.w[i].hasSuffix("'ve") {
            var j = i + 1
            if ws.question || negativeAdverbs.contains(ws.at(0)), subjectPronouns.contains(ws.at(j)) { j += 1 }
            while ["just", "already", "ever", "never", "not", "recently", "often", "always", "once", "also", "finally"].contains(ws.at(j)) { j += 1 }
            let v = ws.at(j)
            // have + 과거형 ("have went" · "has ate")
            if isPastOnly(v), let b = base(v), !isNoun(v), ws.w[i] != "'s", !["lay", "saw", "found", "left", "fell", "wound", "ground", "bore", "rose"].contains(v) {
                if ws.w[i] == "had", j == i + 1, ["better", "to"].contains(ws.at(j)) { continue }
                return Issue(rule: "완료형 have + 과거분사", why: "have/has/had 뒤에는 과거분사: \(v) → \(DoitEnglish.ppForms(b).first ?? b)", at: j, fix: DoitEnglish.ppForms(b).first)
            }
        }
        let line = " " + ws.w.joined(separator: " ") + " "
        // 현재완료 + just now
        if line.contains(" just now "), ws.w.indices.contains(where: { isPresentPerfect(ws, at: $0) }) {
            return Issue(rule: "현재완료와 just now", why: "just now(방금 전)는 과거 시점이라 과거형과 써요 (현재완료 ✗).", at: ws.w.firstIndex(where: { ["have", "has"].contains($0) }))
        }
        // I have gone to … (1인칭 경험은 have been to)
        if let r = line.range(of: #" (i|we) (have|'ve) (never |ever |already |once )?gone to "#, options: .regularExpression),
           line[r.upperBound...].range(of: #"(twice|once|before|three times|many times|several times|\d+ times)"#, options: .regularExpression) != nil
            || line.contains(" never gone to ") || line.hasPrefix(" have you ever gone to ") {
            let g = ws.w.firstIndex(of: "gone")
            return Issue(rule: "have been to (경험)", why: "'가 본 적이 있다'(경험)는 have been to예요 (have gone to는 '가 버리고 없다').", at: g, fix: "been")
        }
        if ws.at(0) == "have", ws.at(1) == "you", ws.at(2) == "ever", ws.at(3) == "gone", ws.at(4) == "to" {
            return Issue(rule: "have been to (경험)", why: "'가 본 적이 있니?'는 Have you ever been to …?", at: 3, fix: "been")
        }
        // since + 기간 ("since three years") · 현재완료 + for + 연도
        if let s = ws.w.firstIndex(of: "since"), amountNumbers.contains(ws.at(s + 1)) || Int(ws.at(s + 1)).map({ $0 < 100 }) == true,
           ["years", "months", "weeks", "days", "hours", "minutes"].contains(ws.at(s + 2)), ws.at(s + 3) != "ago" {
            return Issue(rule: "for와 since", why: "기간(\(ws.at(s + 1)) \(ws.at(s + 2))) 앞에는 for, 시점 앞에는 since를 써요.", at: s, fix: "for")
        }
        if let f = ws.w.firstIndex(of: "for"), ws.at(f + 1).range(of: #"^(19|20)[0-9]{2}$"#, options: .regularExpression) != nil, endsPhrase(ws, f + 2),
           ws.w.indices.contains(where: { $0 < f && isPresentPerfect(ws, at: $0) }) {
            return Issue(rule: "for와 since", why: "시점(\(ws.at(f + 1))) 앞에는 since: for → since", at: f, fix: "since")
        }
        // know · live + for + 기간 → 현재완료
        if subjectPronouns.contains(ws.at(0)), ["know", "knows", "live", "lives"].contains(ws.at(1)),
           let f = ws.w.firstIndex(of: "for"), amountNumbers.contains(ws.at(f + 1)) || ws.at(f + 1) == "many",
           ["years", "months", "weeks"].contains(ws.at(f + 2)), endsPhrase(ws, f + 3),
           !ws.w.contains(where: { ["every", "usually", "will", "when", "if", "and", "but", "that", "who", "which"].contains($0) }),
           ws.at(1).hasPrefix("know") || ["here", "there", "in"].contains(ws.at(2)) {
            let v = ws.at(1)
            let pp = v.hasPrefix("know") ? "known" : "lived"
            let have = thirdSingular.contains(ws.at(0)) ? "has" : "have"
            return Issue(rule: "현재완료 (계속)", why: "for + 기간(…동안 지금까지)은 현재완료: \(v) → \(have) \(pp)", at: 1, fix: "\(have) \(pp)")
        }
        return nil
    }

    // MARK: 수동태

    static func passiveRules(_ ws: Words) -> Issue? {
        let intransitive: Set<String> = ["happened", "occurred", "appeared", "disappeared", "arrived", "died", "existed", "emerged", "consisted",
                                         "belonged", "resembled", "seemed", "lasted", "vanished", "remained", "lacked"]
        let transitive: Set<String> = ["build", "write", "make", "break", "speak", "teach", "sing", "steal", "eat", "give", "take", "catch", "draw",
                                       "grow", "see", "know", "choose", "drive", "throw", "forget", "sell", "buy", "send", "bring", "find",
                                       "tell", "invent", "discover", "paint", "design", "invite", "visit", "wash", "fix", "plant", "use",
                                       "hold", "keep", "show", "love", "respect", "create", "produce", "develop", "deliver"]
        let wrongPrep: [String: (Set<String>, String)] = [
            "interested": (["at", "about", "on", "of", "with"], "in"), "satisfied": (["at", "of"], "with"), "filled": (["of"], "with"),
            "covered": (["of"], "with"), "famous": (["of"], "for"), "proud": (["at", "with", "in"], "of"), "afraid": (["from", "at", "with"], "of"),
            "fond": (["with", "at", "about", "for", "in"], "of"), "similar": (["with"], "to"), "full": (["with"], "of"),
            "pleased": (["of"], "with"), "worried": (["of"], "about"), "tired": (["at"], "of"), "different": (["of"], "from"),
            "crowded": (["of"], "with"), "absent": (["of"], "from"), "excited": (["of"], "about"), "surprised": (["of", "in"], "at")
        ]
        for i in ws.w.indices {
            let t = ws.w[i], n = ws.at(i + 1)
            // 자동사는 수동태로 쓰지 않음 ("was happened")
            if ["is", "are", "was", "were", "be", "been", "being", "am"].contains(t), intransitive.contains(n) {
                return Issue(rule: "자동사는 수동태 ✗", why: "\(n.dropLast(n.hasSuffix("ed") ? 1 : 0))은(는) 목적어가 없는 자동사라 수동태(be + p.p.)로 쓰지 않아요.", at: i, length: 2, fix: n)
            }
            // 조동사 + be + 동사원형 ("will be build")
            if t == "be", i > 0, modals.contains(ws.w[i - 1]) || ws.w[i - 1] == "to", transitive.contains(n), DoitEnglish.ppForms(n).first != n {
                return Issue(rule: "수동태의 과거분사", why: "be 뒤 수동태는 과거분사: \(n) → \(DoitEnglish.ppForms(n).first ?? n)", at: i + 1, fix: DoitEnglish.ppForms(n).first)
            }
            // 5형식 수동태: be made + to부정사 ("was made go" · "was seen cross")
            if ["is", "are", "was", "were", "be", "been"].contains(t), ["made", "seen", "heard", "watched", "noticed", "forced", "asked", "told", "allowed"].contains(n) {
                let v = ws.at(i + 2)
                if isPlainBase(v), actionVerbs.contains(v), !nounishVerbs.contains(v) || ["made", "seen", "heard", "forced", "told", "asked", "allowed"].contains(n),
                   !isNoun(v), !["to", "up", "out", "of", "from", "in", "by"].contains(v) {
                    return Issue(rule: "5형식의 수동태", why: "사역·지각동사의 수동태에서는 원형이 to부정사로 바뀌어요: \(n) \(v) → \(n) to \(v)", at: i + 2, fix: "to " + ws.raw[i + 2])
                }
            }
            // 주어 + born ("I born in 2005")
            if personSubjects.contains(t), n == "born", i == 0 || ws.comma[i - 1] {
                return Issue(rule: "be born", why: "'태어나다'는 수동태 be born: \(t) born → \(t) \(t == "i" ? "was" : ["he", "she"].contains(t) ? "was" : "were") born", at: i + 1, fix: (["i", "he", "she"].contains(t) ? "was" : "were") + " born")
            }
            if ["am", "is", "are"].contains(t), n == "born", ws.at(i + 2) == "in", ws.at(i + 3).range(of: #"^(19|20)[0-9]{2}$"#, options: .regularExpression) != nil {
                return Issue(rule: "be born", why: "과거에 태어났으니 was/were born", at: i, fix: t == "are" ? "were" : "was")
            }
            // 수동태와 쓰는 전치사 · 형용사 + 전치사
            if let (bad, right) = wrongPrep[n], bad.contains(ws.at(i + 2)), beForms.contains(t) || ["become", "became", "feel", "felt", "seem", "seems", "seemed", "get", "got"].contains(t) {
                return Issue(rule: "전치사 짝", why: "be \(n) \(right) (\(n) \(ws.at(i + 2)) ✗)", at: i + 2, fix: right.contains("/") ? nil : right)
            }
        }
        // 사물 주어 + 과거형 + by 사람 ("The window broke by Tom")
        if let np = nounPhrase(ws, at: 0), ws.w[np.head] != "", thingNouns.contains(ws.w[np.head]) || massNouns.contains(ws.w[np.head]) {
            let v = ws.at(np.end)
            if isPastOnly(v), ws.at(np.end + 1) == "by", let b = base(v), transitive.contains(b) {
                let agent = ws.at(np.end + 2)
                if ["him", "her", "them", "me", "us"].contains(agent) || looksLikeName(ws, np.end + 2) || nounPhrase(ws, at: np.end + 2).map({ personNouns.contains(ws.w[$0.head]) }) == true {
                    let be = np.plural == true ? "were" : "was"
                    return Issue(rule: "수동태 be + p.p.", why: "주어가 행동을 당하니 수동태: \(v) → \(be) \(DoitEnglish.ppForms(b).first ?? v)", at: np.end, fix: "\(be) \(DoitEnglish.ppForms(b).first ?? v)")
                }
            }
        }
        return nil
    }

    // MARK: to부정사

    static func infinitiveRules(_ ws: Words) -> Issue? {
        let character: Set<String> = ["kind", "wise", "foolish", "stupid", "careless", "polite", "rude", "generous", "honest", "silly",
                                      "brave", "clever", "considerate", "thoughtful", "cruel", "selfish"]
        let impersonal: Set<String> = ["important", "necessary", "easy", "difficult", "hard", "possible", "impossible", "dangerous", "natural",
                                       "essential", "interesting", "safe", "useful", "common", "convenient", "helpful", "boring",
                                       "exciting", "fun", "healthy", "unnecessary"]
        for i in ws.w.indices where ws.w[i] == "it" || ws.w[i] == "it's" {
            var j = i + 1
            if ws.w[i] == "it" { guard beForms.contains(ws.at(j)) || ws.at(j) == "be" else { continue }; j += 1 }
            if ["very", "so", "really", "quite", "not", "too"].contains(ws.at(j)) { j += 1 }
            let adj = ws.at(j), p = ws.at(j + 1)
            guard ["for", "of"].contains(p) else { continue }
            var k = j + 2
            if ["me", "you", "him", "her", "us", "them", "it"].contains(ws.at(k)) || looksLikeName(ws, k) { k += 1 }
            else if let np = nounPhrase(ws, at: k) { k = np.end } else { continue }
            guard ws.at(k) == "to", isBaseForm(ws.at(k + 1)) else { continue }
            if character.contains(adj), p == "for" {
                return Issue(rule: "to부정사의 의미상 주어", why: "사람의 성격·태도(\(adj))를 말하는 형용사 뒤 의미상 주어는 of + 목적격 (for ✗)", at: j + 1, fix: "of")
            }
            if impersonal.contains(adj), p == "of" {
                return Issue(rule: "to부정사의 의미상 주어", why: "\(adj) 같은 형용사 뒤 의미상 주어는 for + 목적격 (of ✗)", at: j + 1, fix: "for")
            }
        }
        let enoughAdjectives: Set<String> = ["old", "tall", "big", "strong", "rich", "smart", "brave", "young", "wise", "clever", "careful",
                                             "lucky", "brave", "fast", "kind", "large", "warm", "long", "good", "healthy", "mature", "experienced"]
        for i in ws.w.indices {
            let t = ws.w[i], n = ws.at(i + 1)
            // enough의 자리: 형용사 + enough ("enough old to" ✗)
            if t == "enough", enoughAdjectives.contains(n), ["to", "for"].contains(ws.at(i + 2)), i > 0, beForms.contains(ws.w[i - 1]) || ["not", "be", "become", "became", "feel", "felt", "get", "got", "grow", "grew"].contains(ws.w[i - 1]) {
                return Issue(rule: "형용사 + enough to", why: "enough는 형용사 뒤에: enough \(n) → \(n) enough", at: i, length: 2, fix: "\(ws.raw[i + 1]) enough")
            }
            // too ~ that + 주어 + can't ("too tired that he can't" ✗ → so ~ that)
            if t == "too", isAdjectiveLike(n) || adjectiveOfAdverb(n) != nil, ws.at(i + 2) == "that", subjectPronouns.contains(ws.at(i + 3)),
               ["can't", "cannot", "couldn't", "could", "can"].contains(ws.at(i + 4)) {
                return Issue(rule: "so ~ that / too ~ to", why: "'너무 ~해서 …할 수 없다'는 so ~ that … can't 또는 too ~ to … (too ~ that ✗)", at: i, fix: "so")
            }
            // too ~ to + 동사 + it (주어와 같은 목적어를 또 씀)
            if t == "too", isAdjectiveLike(n), ws.at(i + 2) == "to" || ws.at(i + 2) == "for" {
                var k = i + 2
                if ws.at(k) == "for" { k += 2 }
                guard ws.at(k) == "to", isBaseForm(ws.at(k + 1)), ["it", "them"].contains(ws.at(k + 2)), endsPhrase(ws, k + 3),
                      let np = nounPhrase(ws, at: 0), thingNouns.contains(ws.w[np.head]) || massNouns.contains(ws.w[np.head]) || ["soup", "box", "problem", "question", "water", "coffee", "tea", "food", "bag", "book", "story", "door"].contains(ws.w[np.head]),
                      np.plural == (ws.at(k + 2) == "them"), beForms.contains(ws.at(np.end)) else { continue }
                return Issue(rule: "too ~ to의 목적어", why: "문장의 주어가 to부정사의 목적어라서 \(ws.at(k + 2))를 또 쓰지 않아요.", at: k + 2, fix: "")
            }
        }
        // 의문사 + to부정사 ("know how swim" ✗)
        let askVerbs: Set<String> = ["know", "knows", "knew", "learn", "learned", "learnt", "tell", "told", "show", "showed", "teach", "taught",
                                     "decide", "decided", "ask", "asked", "wonder", "wondered", "explain", "explained", "forget", "forgot",
                                     "remember", "remembered", "me", "him", "her", "us", "them"]
        for i in ws.w.indices.dropFirst() where ["how", "what", "where", "when", "which"].contains(ws.w[i]) && askVerbs.contains(ws.w[i - 1]) {
            let v = ws.at(i + 1)
            guard isPlainBase(v), actionVerbs.contains(v), !(ws.w[i] == "how" && v == "come"), !isFiniteVerb(ws.at(i + 2)) else { continue }
            if ["how", "where", "when"].contains(ws.w[i]) || ws.w[i] == "what" && !personSubjects.contains(ws.at(i + 2)) {
                return Issue(rule: "의문사 + to부정사", why: "'어떻게/무엇을 ~할지'는 의문사 + to + 동사원형: \(ws.w[i]) \(v) → \(ws.w[i]) to \(v)", at: i + 1, fix: "to " + ws.raw[i + 1])
            }
        }
        // 명사 + to부정사 + 전치사 ("a chair to sit" → sit on)
        let pairs: [(Set<String>, String, String)] = [(["chair", "chairs", "bench", "sofa", "seat"], "sit", "on"),
                                                      (["house", "apartment", "town", "city"], "live", "in"),
                                                      (["friend", "friends", "someone", "somebody", "anyone", "nobody"], "talk", "to"),
                                                      (["friend", "friends", "someone", "somebody", "anyone"], "play", "with"),
                                                      (["pen", "pencil"], "write", "with"), (["paper"], "write", "on")]
        if let last = ws.w.indices.last, last >= 2, ws.w[last - 1] == "to" {
            for (nouns, verb, prep) in pairs where ws.w[last] == verb && nouns.contains(ws.w[last - 2]) {
                return Issue(rule: "to부정사의 형용사적 용법 + 전치사", why: "'\(ws.w[last - 2])에/와 ~할'은 to \(verb) \(prep)처럼 전치사가 필요해요.", at: last, fix: ws.raw[last] + " " + prep)
            }
        }
        // 목적어를 to부정사로만 받는 동사 + to + 원형이 아닌 것 ("want to goes")
        let toVerbs: Set<String> = ["want", "wants", "wanted", "hope", "hopes", "hoped", "decide", "decided", "plan", "plans", "planned", "need",
                                    "needs", "needed", "able", "have", "has", "had", "ought", "like", "promise", "promised", "refuse", "refused", "try", "tried"]
        for i in ws.w.indices.dropFirst() where ws.w[i] == "to" && toVerbs.contains(ws.w[i - 1]) {
            if ws.w[i - 1] == "like", !["would", "'d"].contains(ws.at(i - 2)) && !ws.at(i - 2).hasSuffix("'d") { continue }
            let v = ws.at(i + 1)
            guard !v.isEmpty, !isNoun(v), !ingNouns.contains(v) else { continue }
            if isPastOnly(v) || isThirdForm(v) && actionVerbs.contains(base(v) ?? "") && !nounishVerbs.contains(base(v) ?? "")
                || v.hasSuffix("ing") && base(v).map({ DoitEnglish.ingForm($0) == v && actionVerbs.contains($0) }) == true && !["have", "has", "had"].contains(ws.w[i - 1]) {
                guard let b = base(v) else { continue }
                return Issue(rule: "to부정사 (to + 동사원형)", why: "to부정사는 to + 동사원형: to \(v) → to \(b)", at: i + 1, fix: b)
            }
        }
        return nil
    }

    // MARK: 동명사

    static func gerundRules(_ ws: Words) -> Issue? {
        let strongVerbs: Set<String> = ["go", "come", "eat", "see", "meet", "make", "take", "give", "say", "tell", "buy", "find", "get", "keep",
                                        "bring", "write", "sing", "become", "begin", "forget", "choose", "speak", "teach", "think", "send",
                                        "spend", "wear", "win", "lose", "wake", "know", "understand", "finish", "enjoy", "solve", "explain",
                                        "protect", "improve", "learn", "listen", "prepare", "borrow", "lend", "arrive", "ask", "invite", "apply",
                                        "catch"]
        let preps: Set<String> = ["in", "of", "for", "about", "without", "by", "after", "before", "on", "at", "from", "besides"]
        for i in ws.w.indices.dropLast() where preps.contains(ws.w[i]) {
            let v = ws.at(i + 1), after = ws.at(i + 2)
            if ws.w[i] == "of", i > 0, ["kind", "sort"].contains(ws.w[i - 1]) { continue }
            if ["before", "after"].contains(ws.w[i]), subjectPronouns.contains(after) || nounPhrase(ws, at: i + 1) != nil { continue }
            let objectFollows = ["me", "him", "her", "us", "them", "it", "you"].contains(after)
            guard isPlainBase(v) || v == "go" || v == "do", strongVerbs.contains(v) || objectFollows && actionVerbs.contains(v) else { continue }
            if ws.w[i] == "for", v == "help", !objectFollows { continue }
            return Issue(rule: "전치사 + 동명사", why: "전치사(\(ws.w[i])) 뒤에 동사가 오면 동명사(-ing): \(v) → \(DoitEnglish.ingForm(v))", at: i + 1, fix: DoitEnglish.ingForm(v))
        }
        let line = " " + ws.w.joined(separator: " ") + " "
        // be used to + -ing (사람 주어, 현재) · when it comes to · object to · be opposed to · contribute to · devoted to
        let toPhrases = [#"(\s|')(am|is|are|m|re|get|gets|got) used to "#, #" when it comes to "#, #" (i|you|he|she|we|they) object(s|ed)? to "#, #" (be|is|are|am|was|were) opposed to "#,
                         #" devoted to "#, #" committed to "#, #" contribute(s|d)? to "#, #" key to "#]
        for pattern in toPhrases {
            guard let r = line.range(of: pattern, options: .regularExpression) else { continue }
            let after = line[r.upperBound...].split(separator: " ").first.map(String.init) ?? ""
            if pattern.contains("used"), !personSubjects.contains(ws.at(0)) && !["i'm", "you're", "we're", "they're", "he's", "she's"].contains(ws.at(0)) { continue }
            if pattern.contains("key") || pattern.contains("contribute") { guard strongVerbs.contains(after) else { continue } }
            guard isPlainBase(after) || after == "go" || after == "do", actionVerbs.contains(after) || after == "do" else { continue }
            let at = ws.w.firstIndex(of: after)
            return Issue(rule: "to(전치사) + 동명사", why: "이 표현의 to는 전치사라 뒤에 동명사(-ing): to \(after) → to \(DoitEnglish.ingForm(after))", at: at, fix: DoitEnglish.ingForm(after))
        }
        for i in ws.w.indices {
            let t = ws.w[i], n = ws.at(i + 1)
            // cannot help + -ing
            if ["can't", "cannot", "couldn't"].contains(t) || t == "not" && ["can", "could"].contains(ws.at(i - 1)), n == "help" {
                let v = ws.at(i + 2)
                if ["laugh", "cry", "smile", "think", "feel", "worry", "wonder", "fall", "admire", "notice", "eat", "sing", "dance"].contains(v) {
                    return Issue(rule: "cannot help + -ing", why: "'~하지 않을 수 없다'는 cannot help -ing: \(v) → \(DoitEnglish.ingForm(v))", at: i + 2, fix: DoitEnglish.ingForm(v))
                }
            }
            // be busy + -ing
            if t == "busy", i > 0, beForms.contains(ws.w[i - 1]) || ["very", "so", "too"].contains(ws.w[i - 1]), n == "to", isBaseForm(ws.at(i + 2)) {
                return Issue(rule: "be busy + -ing", why: "'~하느라 바쁘다'는 be busy -ing (busy to ✗)", at: i + 1, length: 2, fix: DoitEnglish.ingForm(ws.at(i + 2)))
            }
            // have difficulty/trouble + -ing
            if ["difficulty", "trouble"].contains(t), n == "to", isBaseForm(ws.at(i + 2)), ws.w[..<i].contains(where: { ["have", "has", "had", "having"].contains($0) }) {
                return Issue(rule: "have trouble + -ing", why: "'~하는 데 어려움을 겪다'는 have trouble/difficulty (in) -ing", at: i + 1, length: 2, fix: DoitEnglish.ingForm(ws.at(i + 2)))
            }
            // feel like + -ing
            if ["feel", "feels", "felt"].contains(t), n == "like" {
                let v = ws.at(i + 2)
                if v == "to", isBaseForm(ws.at(i + 3)) { return Issue(rule: "feel like + -ing", why: "'~하고 싶다'는 feel like -ing", at: i + 2, length: 2, fix: DoitEnglish.ingForm(ws.at(i + 3))) }
                if isPlainBase(v), strongVerbs.contains(v) || v == "go" { return Issue(rule: "feel like + -ing", why: "'~하고 싶다'는 feel like -ing: \(v) → \(DoitEnglish.ingForm(v))", at: i + 2, fix: DoitEnglish.ingForm(v)) }
            }
            // How about / What about + -ing
            if ["how", "what"].contains(t), n == "about", i == 0 {
                let v = ws.at(i + 2)
                if v == "to", isBaseForm(ws.at(i + 3)) { return Issue(rule: "How about + -ing", why: "How about 뒤에는 동명사(-ing)", at: i + 2, length: 2, fix: DoitEnglish.ingForm(ws.at(i + 3))) }
                if isPlainBase(v) || v == "go", actionVerbs.contains(v), !nounishVerbs.contains(v) || ["me", "him", "her", "us", "them", "to"].contains(ws.at(i + 3)) {
                    return Issue(rule: "How about + -ing", why: "How about 뒤에는 동명사: \(v) → \(DoitEnglish.ingForm(v))", at: i + 2, fix: DoitEnglish.ingForm(v))
                }
            }
            // be worth + -ing ("worth to visit" ✗)
            if t == "worth", n == "to", isBaseForm(ws.at(i + 2)) {
                return Issue(rule: "be worth + -ing", why: "'~할 가치가 있다'는 be worth -ing (worth to ✗)", at: i + 1, length: 2, fix: DoitEnglish.ingForm(ws.at(i + 2)))
            }
            // spend + 시간 + -ing 형태 중 "spend ... to"는 뜻에 따라 맞을 수도 있어 따지지 않음
        }
        return nil
    }

    // MARK: 감정을 나타내는 분사 (interesting / interested)

    static let emotionVerbs: [String: (ing: String, ed: String)] = [
        "bore": ("boring", "bored"), "interest": ("interesting", "interested"), "excite": ("exciting", "excited"),
        "surprise": ("surprising", "surprised"), "amaze": ("amazing", "amazed"), "shock": ("shocking", "shocked"),
        "disappoint": ("disappointing", "disappointed"), "satisfy": ("satisfying", "satisfied"), "frighten": ("frightening", "frightened"),
        "confuse": ("confusing", "confused"), "please": ("pleasing", "pleased"), "annoy": ("annoying", "annoyed"),
        "embarrass": ("embarrassing", "embarrassed"), "tire": ("tiring", "tired"), "scare": ("scaring", "scared"),
        "depress": ("depressing", "depressed"), "thrill": ("thrilling", "thrilled"), "fascinate": ("fascinating", "fascinated")
    ]

    static func emotionParticiple(_ ws: Words) -> Issue? {
        let edToIng = Dictionary(uniqueKeysWithValues: emotionVerbs.values.map { ($0.ed, $0.ing) })
        let ingToEd = Dictionary(uniqueKeysWithValues: emotionVerbs.values.map { ($0.ing, $0.ed) })
        let thingSubjects: Set<String> = ["movie", "film", "book", "story", "game", "news", "result", "lecture", "trip", "show", "match", "test",
                                          "question", "novel", "concert", "speech", "class", "lesson", "party", "festival", "song", "music",
                                          "play", "drama", "program", "experience", "event", "idea", "plan", "magazine", "website", "museum",
                                          "picture", "painting", "joke", "situation", "problem", "exam", "subject", "tour", "view", "journey"]
        let linking: Set<String> = ["is", "are", "was", "were", "be", "been", "seems", "seemed", "looks", "looked", "sounds", "sounded", "became", "becomes"]
        // 사물 주어 + be + -ed ("The movie was bored")
        for s in clauseStarts(ws) {
            guard let np = nounPhrase(ws, at: s), thingSubjects.contains(ws.w[np.head]) || ws.w[np.head] == "news", ws.w[np.head] != "class" else { continue }
            var v = np.end
            guard linking.contains(ws.at(v)) else { continue }
            v += 1
            if ["very", "so", "really", "quite", "too", "not", "a", "little", "bit", "rather", "extremely"].contains(ws.at(v)) { v += 1 }
            if ws.at(v) == "bit" || ws.at(v) == "little" { v += 1 }
            let p = ws.at(v)
            if let ing = edToIng[p], endsPhrase(ws, v + 1) || ["to", "for"].contains(ws.at(v + 1)) && p != "tired" {
                if p == "tired" || p == "pleased" || p == "confused" && ws.at(v + 1) == "with" { continue }
                return Issue(rule: "감정 분사 (사물 주어)", why: "\(ws.w[np.head])이(가) 감정을 일으키니 현재분사: \(p) → \(ing)", at: v, fix: ing)
            }
        }
        for i in ws.w.indices {
            let t = ws.w[i], n = ws.at(i + 1)
            // 사람 주어 + be + -ing + 감정 전치사 ("I am interesting in music")
            let pairs: [String: Set<String>] = ["interesting": ["in"], "exciting": ["about"], "disappointing": ["with"], "satisfying": ["with"],
                                                "tiring": ["of"], "frightening": ["of"], "shocking": ["at"], "pleasing": ["with"], "surprising": ["at"],
                                                "boring": ["of"], "amazing": ["by"]]
            if let preps = pairs[n], preps.contains(ws.at(i + 2)), beForms.contains(t) || ["feel", "feels", "felt", "got", "get", "became"].contains(t),
               i > 0, personSubjects.contains(ws.w[i - 1]) || nounPhrase(ws, at: max(0, i - 2)).map({ personNouns.contains(ws.w[$0.head]) && $0.end == i }) == true {
                let ed = ingToEd[n] ?? n
                if n == "interesting", !["music", "art", "science", "history", "math", "sports", "soccer", "books", "english", "reading", "cooking",
                                         "movies", "painting", "dancing", "games", "it", "them", "this", "that", "learning", "playing", "drawing",
                                         "becoming", "studying", "baseball", "basketball", "korean", "computers", "animals", "nature", "politics",
                                         "his", "her", "my", "the", "your", "their", "our", "foreign", "classical", "making", "writing", "singing"].contains(ws.at(i + 3)) { continue }
                return Issue(rule: "감정 분사 (사람 주어)", why: "사람이 감정을 느끼니 과거분사: \(n) → \(ed)", at: i + 1, fix: ed)
            }
            // 사람 주어 + feel + -ing ("I felt boring")
            if ["feel", "feels", "felt"].contains(t), i > 0, personSubjects.contains(ws.w[i - 1]) {
                var k = i + 1
                if ["very", "so", "really", "a", "bit", "little", "quite"].contains(ws.at(k)) { k += 1 }
                if ws.at(k) == "bit" || ws.at(k) == "little" { k += 1 }
                let p = ws.at(k)
                if let ed = ingToEd[p], p != "amazing", p != "pleasing", endsPhrase(ws, k + 1) || ["about", "with", "at", "because", "when"].contains(ws.at(k + 1)) {
                    return Issue(rule: "감정 분사 (사람 주어)", why: "사람이 느끼는 감정은 과거분사: feel \(p) → feel \(ed)", at: k, fix: ed)
                }
            }
            // make + 사람 + 감정 ("made me surprising")
            if ["make", "makes", "made"].contains(t), ["me", "him", "her", "us", "them"].contains(n) {
                var k = i + 2
                if ["very", "so", "really"].contains(ws.at(k)) { k += 1 }
                let p = ws.at(k)
                if let ed = ingToEd[p], p != "amazing", endsPhrase(ws, k + 1) {
                    return Issue(rule: "감정 분사 (목적격 보어)", why: "목적어(사람)가 감정을 느끼니 과거분사: \(p) → \(ed)", at: k, fix: ed)
                }
            }
        }
        return nil
    }

    // MARK: 관계대명사

    static let placeNouns: Set<String> = ["house", "city", "town", "village", "country", "room", "hospital", "restaurant", "park", "place", "school",
                                          "hotel", "store", "shop", "street", "museum", "library", "office", "building", "island", "beach", "cafe",
                                          "apartment", "farm", "station", "area", "classroom", "theater", "stadium", "garden", "kitchen", "factory"]
    static let timeNouns: Set<String> = ["day", "year", "time", "moment", "night", "morning", "week", "month", "season", "summer", "winter",
                                         "spring", "fall", "evening", "afternoon", "date", "century", "period", "age", "era"]

    /// 관계사절 뒤가 비어 있거나 때를 나타내는 말뿐인지
    static func clauseEndsPlainly(_ ws: Words, from k: Int) -> Bool {
        if endsPhrase(ws, k) { return true }
        let t = ws.at(k)
        if ["yesterday", "ago", "last", "before", "once", "twice", "often", "now", "then", "when", "as", "since", "until", "for", "together", "every", "many"].contains(t) { return true }
        if t == "in", ws.at(k + 1).range(of: #"^(1[5-9]|20)[0-9]{2}$"#, options: .regularExpression) != nil { return true }
        if t == "is", ws.at(k + 1) == "very" || isAdjectiveLike(ws.at(k + 1)) { return true }
        if beForms.contains(t) || isThirdForm(t) { return true }
        return false
    }

    static func relativeRules(_ ws: Words) -> Issue? {
        let possessed: Set<String> = ["father", "mother", "name", "brother", "sister", "parents", "hair", "eyes", "house", "car", "dog", "son",
                                      "daughter", "cat", "job", "wife", "husband", "uncle", "aunt", "dream", "hobby", "bag", "phone", "roof",
                                      "cover", "tail", "legs", "color", "books", "paintings", "novels", "songs", "family", "friend", "friends"]
        for i in ws.w.indices.dropFirst() {
            let t = ws.w[i], prev = ws.w[i - 1]
            // 전치사 + that ✗ ("the house in that he lives")
            if t == "that", prepositionWords.contains(prev), prev != "in" || i >= 2, i >= 2, isNoun(ws.w[i - 2]), !ws.comma[i - 1], !ws.comma[i],
               personSubjects.contains(ws.at(i + 1)) || ws.at(i + 1) == "the", !["except", "but", "save", "so", "such"].contains(prev) {
                if prev == "in", ws.w[i - 2] != "house" && !placeNouns.contains(ws.w[i - 2]) && !thingNouns.contains(ws.w[i - 2]) { continue }
                return Issue(rule: "전치사 + 관계대명사", why: "전치사 뒤에는 관계대명사 that을 쓰지 않아요 (\(prev) that ✗ → \(prev) which/whom).", at: i, fix: personNouns.contains(ws.w[i - 2]) ? "whom" : "which")
            }
            // 계속적 용법의 that ✗ ("my brother, that lives …")
            if t == "that", ws.comma[i - 1], personNouns.contains(prev) || thingNouns.contains(prev) || looksLikeName(ws, i - 1) {
                let n = ws.at(i + 1)
                if (isThirdForm(n) || isPastOnly(n) || ["has", "have", "lives", "works"].contains(n)) && !isNoun(n) || personSubjects.contains(n) && isFiniteVerb(ws.at(i + 2)) {
                    return Issue(rule: "계속적 용법", why: "쉼표 뒤(계속적 용법)에는 that을 쓰지 않아요 (→ who/which).", at: i, fix: personNouns.contains(prev) || looksLikeName(ws, i - 1) ? "who" : "which")
                }
            }
            // 선행사 + what ✗ ("the book what I bought")
            if t == "what", thingNouns.contains(prev) || placeNouns.contains(prev), i >= 2, ["the", "a", "an", "this", "that", "my", "his", "her"].contains(ws.w[i - 2]),
               personSubjects.contains(ws.at(i + 1)), isFiniteVerb(ws.at(i + 2)) {
                if i >= 3, ["give", "gave", "show", "showed", "tell", "told", "ask", "asked", "teach", "taught", "bring", "brought", "send", "sent", "offer", "offered"].contains(ws.w[i - 3]) { continue }
                return Issue(rule: "관계대명사 what", why: "what은 선행사를 품은 관계대명사라 선행사(\(prev)) 뒤에 쓰지 않아요 (→ which/that).", at: i, fix: "which")
            }
            // the way how ✗
            if t == "how", prev == "way", i >= 2, ws.w[i - 2] == "the" {
                return Issue(rule: "the way how ✗", why: "the way와 how는 함께 쓰지 않아요 (the way 또는 how 하나만).", at: i, fix: "")
            }
            // whose 자리 ("the girl who father is a doctor")
            if t == "who", personNouns.contains(prev), possessed.contains(ws.at(i + 1)), isFiniteVerb(ws.at(i + 2)) || ws.at(i + 2) == "is" {
                return Issue(rule: "소유격 관계대명사 whose", why: "'\(prev)의 \(ws.at(i + 1))'처럼 소유를 나타내면 whose (who ✗)", at: i, fix: "whose")
            }
            // 전치사 + who ✗ → whom
            if t == "who", prepositionWords.contains(prev), i >= 2, personNouns.contains(ws.w[i - 2]), personSubjects.contains(ws.at(i + 1)) {
                return Issue(rule: "전치사 + whom", why: "전치사 뒤 사람 관계대명사는 whom (\(prev) who ✗)", at: i, fix: "whom")
            }
            // 관계대명사 뒤 목적어를 또 씀 ("the book which I bought it")
            if ["which", "that", "whom"].contains(t), thingNouns.contains(prev) || personNouns.contains(prev) && t == "whom", personSubjects.contains(ws.at(i + 1)),
               !ws.w[..<i].contains(where: { ["so", "such", "too"].contains($0) }) {
                let v = ws.at(i + 2)
                let o = ws.at(i + 3)
                let transitiveVerb = (base(v).map { ["buy", "make", "read", "write", "see", "love", "like", "want", "give", "find", "lose", "build",
                                                    "draw", "paint", "take", "bring", "wear", "eat", "cook", "visit", "meet", "watch", "borrow", "sell", "choose"].contains($0) } ?? false)
                if transitiveVerb, (o == "it" && nounPlural(prev) == false || o == "them" && nounPlural(prev) == true || o == "him" || o == "her") && personNouns.contains(prev) == (o == "him" || o == "her"),
                   clauseEndsPlainly(ws, from: i + 4) {
                    return Issue(rule: "관계대명사절의 목적어", why: "관계대명사(\(t))가 목적어 역할을 하니 \(o)를 또 쓰지 않아요.", at: i + 3, fix: "")
                }
            }
        }
        return nil
    }

    // MARK: 관계부사 where/when vs 관계대명사 which

    static func relativeAdverbRules(_ ws: Words) -> Issue? {
        let placeIntransitive: Set<String> = ["live", "lives", "lived", "stay", "stays", "stayed", "grew", "grow", "work", "works", "worked", "go",
                                              "went", "study", "studied", "studies", "sleep", "slept", "met", "meet", "played", "play"]
        let placeTransitive: Set<String> = ["visited", "visit", "liked", "like", "loved", "love", "built", "bought", "saw", "chose", "recommended",
                                            "designed", "painted", "enjoyed", "want", "wanted", "explored", "mentioned", "described", "showed", "found"]
        let timeIntransitive: Set<String> = ["met", "arrived", "came", "moved", "graduated", "started", "began", "left", "happened", "died"]
        for i in ws.w.indices.dropFirst() {
            let t = ws.w[i], prev = ws.w[i - 1]
            guard i >= 2, ["the", "a", "this", "that", "my", "his", "her", "our", "their"].contains(ws.w[i - 2]) || isAdjectiveLike(ws.w[i - 2]) else { continue }
            let s = ws.at(i + 1)
            guard personSubjects.contains(s) || nounPhrase(ws, at: i + 1) != nil else { continue }
            let vAt = personSubjects.contains(s) ? i + 2 : (nounPhrase(ws, at: i + 1)?.end ?? i + 2)
            var v = ws.at(vAt)
            var after = vAt + 1
            if ["was", "were"].contains(v), ws.at(vAt + 1) == "born" { v = "born"; after = vAt + 2 }
            if v == "grew" || v == "grow", ws.at(after) == "up" { after += 1 }
            if t == "which", placeNouns.contains(prev), placeIntransitive.contains(v) || v == "born", clauseEndsPlainly(ws, from: after) {
                if ["met", "meet", "played", "play", "study", "studied"].contains(v), !endsPhrase(ws, after) && !clauseEndsPlainly(ws, from: after) { continue }
                if ["met", "meet", "play", "played", "study", "studied", "studies"].contains(v) { continue }
                return Issue(rule: "관계부사 where", why: "장소(\(prev)) 뒤 절이 완전하면(목적어가 빠지지 않음) where 또는 in which (which ✗)", at: i, fix: "where")
            }
            if t == "which", timeNouns.contains(prev), timeIntransitive.contains(v) || v == "born", clauseEndsPlainly(ws, from: after) {
                return Issue(rule: "관계부사 when", why: "때(\(prev)) 뒤 절이 완전하면 when 또는 on/in which (which ✗)", at: i, fix: "when")
            }
            if t == "where", placeNouns.contains(prev), placeTransitive.contains(v), endsPhrase(ws, after) || ["yesterday", "last", "ago", "before", "twice", "once", "often"].contains(ws.at(after)) {
                return Issue(rule: "관계대명사 which", why: "\(v)의 목적어가 빠진 절이라 관계대명사 which/that (where ✗)", at: i, fix: "which")
            }
            if t == "which", prev == "reason", ["left", "came", "cried", "was", "were", "is", "are", "went", "failed", "quit", "laughed", "lied", "got"].contains(v) {
                if beForms.contains(v), !(isAdjectiveLike(ws.at(after)) || ["so", "very", "late", "absent", "angry", "upset", "sad"].contains(ws.at(after))) { continue }
                return Issue(rule: "관계부사 why", why: "이유(reason) 뒤 완전한 절은 why 또는 for which (which ✗)", at: i, fix: "why")
            }
        }
        return nil
    }

    // MARK: 주격 관계대명사 뒤 동사의 수 ("the boys who plays")

    static func relativeAgreement(_ ws: Words) -> Issue? {
        for i in ws.w.indices where ["who", "which", "that"].contains(ws.w[i]) && i >= 2 && !ws.comma[i - 1] {
            // 명사구 찾기: 바로 앞 명사
            let headIdx = i - 1
            let head = ws.w[headIdx]
            guard let plural = nounPlural(head), personNouns.contains(head) || thingNouns.contains(head) || isNoun(head),
                  !["fact", "idea", "news", "belief", "rumor", "hope", "thought", "feeling", "truth", "chance", "reason", "time", "way"].contains(head) else { continue }
            // 앞에 one of / some of … 가 있으면 수가 헷갈림
            let window = ws.w[max(0, headIdx - 4)..<headIdx]
            if window.contains(where: { $0 == "of" || $0 == "and" || $0 == "or" || prepositionWords.contains($0) }) { continue }
            if ws.w[i] == "that", !(personNouns.contains(head) || thingNouns.contains(head)) { continue }
            if ws.w[i] == "which", personNouns.contains(head) { continue }
            // 바로 앞 낱말이 한정사 또는 형용사여야 (명사구의 끝)
            let before = ws.at(headIdx - 1)
            guard neutralDeterminers.contains(before) || singularDeterminers.contains(before) || pluralDeterminers.contains(before) || isAdjectiveLike(before) else { continue }
            var v = i + 1
            while ["always", "often", "usually", "never", "also", "really", "sometimes"].contains(ws.at(v)) { v += 1 }
            let verb = ws.at(v)
            if let vn = verbNumber(verb), vn != plural {
                if isThirdForm(verb), isNoun(verb) { continue }
                return Issue(rule: "주격 관계대명사 뒤 수일치", why: "\(ws.w[i])의 선행사 '\(head)'가 \(plural ? "복수" : "단수")라서 \(verb) → \(flipNumber(verb) ?? "")", at: v, fix: flipNumber(verb))
            }
            if !plural, isPlainBase(verb), actionVerbs.contains(verb), !isFiniteVerb(ws.at(v + 1)) {
                return Issue(rule: "주격 관계대명사 뒤 수일치", why: "선행사 '\(head)'가 3인칭 단수라 \(verb) → \(DoitEnglish.thirdPerson(verb))", at: v, fix: DoitEnglish.thirdPerson(verb))
            }
        }
        return nil
    }

    // MARK: 접속사 · 전치사 (because / because of, although / despite, during / while, if / whether)

    /// i부터 쉼표·문장 끝까지 동사로 볼 만한 낱말이 없는지
    static func noVerbUntilBreak(_ ws: Words, from i: Int) -> Bool {
        var k = i
        while k < ws.w.count {
            let t = ws.w[k]
            if isFiniteVerb(t) || base(t) != nil && !isNoun(t) || modals.contains(t) || t.hasSuffix("ing") { return false }
            if ws.comma[k] { return true }
            k += 1
        }
        return true
    }

    static func conjunctionRules(_ ws: Words) -> Issue? {
        for i in ws.w.indices {
            let t = ws.w[i], n = ws.at(i + 1)
            // because of + 절
            if t == "because", n == "of", subjectPronouns.contains(ws.at(i + 2)), isFiniteVerb(ws.at(i + 3)) {
                return Issue(rule: "because / because of", why: "뒤에 주어 + 동사(절)가 오면 because (because of ✗)", at: i, length: 2, fix: "because")
            }
            // because + 명사구 (동사 없음)
            if t == "because", n != "of", let np = nounPhrase(ws, at: i + 1), np.hasDeterminer, endsPhrase(ws, np.end), noVerbUntilBreak(ws, from: i + 1) {
                return Issue(rule: "because / because of", why: "뒤에 명사(구)만 오면 because of (because ✗)", at: i, fix: "because of")
            }
            // although + 명사구
            if ["although", "though"].contains(t), let np = nounPhrase(ws, at: i + 1), np.hasDeterminer, endsPhrase(ws, np.end), noVerbUntilBreak(ws, from: i + 1) {
                return Issue(rule: "although / despite", why: "뒤에 명사(구)만 오면 despite / in spite of (\(t) ✗)", at: i, fix: "despite")
            }
            // despite + 절 · despite of
            if t == "despite", n == "of" { return Issue(rule: "although / despite", why: "despite는 of 없이 써요 (despite of ✗ → despite / in spite of).", at: i + 1, fix: "") }
            if t == "despite" || t == "spite" && ws.at(i - 1) == "in" && n == "of", subjectPronouns.contains(t == "despite" ? n : ws.at(i + 2)) {
                let k = t == "despite" ? i + 1 : i + 2
                if isFiniteVerb(ws.at(k + 1)) { return Issue(rule: "although / despite", why: "뒤에 주어 + 동사(절)가 오면 although (despite ✗)", at: t == "despite" ? i : i - 1, fix: "although") }
            }
            // during + 절 / while + 명사구
            if t == "during", subjectPronouns.contains(n), isFiniteVerb(ws.at(i + 2)) {
                return Issue(rule: "during / while", why: "뒤에 주어 + 동사(절)가 오면 while (during ✗)", at: i, fix: "while")
            }
            if t == "while", ["the", "my", "his", "her", "our", "their", "summer", "winter"].contains(n), let np = nounPhrase(ws, at: i + 1), endsPhrase(ws, np.end), noVerbUntilBreak(ws, from: i + 1) {
                return Issue(rule: "during / while", why: "뒤에 명사(구)만 오면 during (while ✗)", at: i, fix: "during")
            }
            // if or not ✗
            if t == "if", n == "or", ws.at(i + 2) == "not" {
                return Issue(rule: "if / whether", why: "'~인지 아닌지'에서 바로 뒤에 or not이 오면 whether (if or not ✗)", at: i, fix: "whether")
            }
            // 전치사 + if ✗
            if t == "if", i > 0, ["on", "about", "of", "upon"].contains(ws.w[i - 1]) {
                return Issue(rule: "if / whether", why: "전치사 뒤 '~인지'는 whether (\(ws.w[i - 1]) if ✗)", at: i, fix: "whether")
            }
            // be so a + 형용사 + 명사 → such a
            if t == "so", ["a", "an"].contains(n), i > 0, beForms.contains(ws.w[i - 1]) || ["was", "is"].contains(ws.w[i - 1]), isAdjectiveLike(ws.at(i + 2)) {
                return Issue(rule: "such a + 형용사 + 명사", why: "'정말 ~한 (명사)'는 such a + 형용사 + 명사 (so a ✗)", at: i, fix: "such")
            }
            // unless + 부정 ✗
            if t == "unless" {
                var end = i + 1
                while end < ws.w.count, end < i + 6 { if ws.comma[end] { end += 1; break }; end += 1 }
                let window = ws.w[(i + 1)..<min(ws.w.count, end)]
                if window.contains(where: { ["don't", "doesn't", "didn't", "won't", "not", "can't"].contains($0) }) {
                    return Issue(rule: "unless", why: "unless(= if … not)는 이미 부정의 뜻이라 not을 또 쓰지 않아요.", at: i)
                }
            }
        }
        // Although …, but … ✗ / Because …, so … ✗
        if ["although", "though", "because"].contains(ws.at(0)) || ws.at(0) == "even" && ws.at(1) == "though",
           let cut = ws.comma.firstIndex(of: true), ws.at(cut + 1) == (ws.at(0) == "because" ? "so" : "but") {
            return Issue(rule: "접속사 겹쳐 쓰기", why: "\(ws.at(0)) 절과 \(ws.at(cut + 1))를 함께 쓰지 않아요 (접속사 하나만).", at: cut + 1, fix: "")
        }
        // If … or not + 동사 (문장 처음 주어 자리) → Whether
        if ws.at(0) == "if", let o = ws.w.firstIndex(of: "or"), ws.at(o + 1) == "not", ["is", "was", "doesn't", "does", "depends", "matters"].contains(ws.at(o + 2)) {
            return Issue(rule: "if / whether", why: "주어 자리의 '~인지'는 whether (If ✗)", at: 0, fix: "Whether")
        }
        return nil
    }

    // MARK: 상관접속사 (both A and B, either A or B, neither A nor B, not only A but also B, A as well as B)

    /// 주어 하나 (대명사 · 이름 · 명사구): (끝 번호, 복수인지, 1인칭 I인지)
    static func simpleSubject(_ ws: Words, _ i: Int) -> (end: Int, plural: Bool?, first: Bool)? {
        let w = ws.at(i)
        if w == "i" { return (i + 1, nil, true) }
        if ["you", "we", "they"].contains(w) { return (i + 1, true, false) }
        if ["he", "she", "it"].contains(w) { return (i + 1, false, false) }
        if looksLikeName(ws, i) { return (i + 1, false, false) }
        if let np = nounPhrase(ws, at: i, bare: true), np.plural != nil { return (np.end, np.plural, false) }
        return nil
    }

    static func correlativeRules(_ ws: Words) -> Issue? {
        let w0 = ws.at(0)
        // Both A and B + 단수 동사
        if w0 == "both", let a = simpleSubject(ws, 1), ws.at(a.end) == "and", let b = simpleSubject(ws, a.end + 1) {
            let v = ws.at(b.end)
            if verbNumber(v) == false { return Issue(rule: "both A and B", why: "both A and B는 복수: \(v) → \(flipNumber(v) ?? "")", at: b.end, fix: flipNumber(v)) }
        }
        // both … or / either … and / neither … or ✗
        if ["both", "either", "neither"].contains(w0), let a = simpleSubject(ws, 1) {
            let c = ws.at(a.end)
            let right = w0 == "both" ? "and" : w0 == "either" ? "or" : "nor"
            if ["and", "or", "nor"].contains(c), c != right, simpleSubject(ws, a.end + 1) != nil {
                return Issue(rule: "상관접속사 짝", why: "\(w0) A \(right) B로 써요 (\(c) ✗)", at: a.end, fix: right)
            }
        }
        // Either/Neither A or/nor B, Not only A but (also) B + 동사: B에 맞춤
        var bStart: Int?
        if ["either", "neither"].contains(w0), let a = simpleSubject(ws, 1), ["or", "nor"].contains(ws.at(a.end)) { bStart = a.end + 1 }
        if w0 == "not", ws.at(1) == "only", let a = simpleSubject(ws, 2), ws.at(a.end) == "but" { bStart = ws.at(a.end + 1) == "also" ? a.end + 2 : a.end + 1 }
        if let s = bStart, let b = simpleSubject(ws, s) {
            let v = ws.at(b.end)
            if b.first {
                if ["is", "are", "was"].contains(v) && v != "am" && v != "was" || isThirdForm(v) && !isNoun(v) {
                    let right = v == "is" || v == "are" ? "am" : (base(v) ?? v)
                    return Issue(rule: "상관접속사 수일치 (B에 맞춤)", why: "동사는 B(I)에 맞춰요: \(v) → \(right)", at: b.end, fix: right)
                }
            } else if let p = b.plural, let vn = verbNumber(v), vn != p {
                return Issue(rule: "상관접속사 수일치 (B에 맞춤)", why: "동사는 B(\(ws.raw[s..<b.end].joined(separator: " ")))에 맞춰요: \(v) → \(flipNumber(v) ?? "")", at: b.end, fix: flipNumber(v))
            } else if b.plural == false, isPlainBase(v), actionVerbs.contains(v) {
                return Issue(rule: "상관접속사 수일치 (B에 맞춤)", why: "동사는 B에 맞춰요: \(v) → \(DoitEnglish.thirdPerson(v))", at: b.end, fix: DoitEnglish.thirdPerson(v))
            }
        }
        // A as well as B + 동사: A에 맞춤
        if let a = simpleSubject(ws, 0), ws.at(a.end) == "as", ws.at(a.end + 1) == "well", ws.at(a.end + 2) == "as", let b = simpleSubject(ws, a.end + 3), !a.first {
            let v = ws.at(b.end)
            if let p = a.plural, let vn = verbNumber(v), vn != p {
                return Issue(rule: "A as well as B (A에 맞춤)", why: "A as well as B의 동사는 A(\(ws.raw[0..<a.end].joined(separator: " ")))에 맞춰요: \(v) → \(flipNumber(v) ?? "")", at: b.end, fix: flipNumber(v))
            }
        }
        // Not only + 절 (도치 안 함): "Not only he is smart, but …"
        if w0 == "not", ws.at(1) == "only", personSubjects.contains(ws.at(2)) || ["he", "she", "it"].contains(ws.at(2)), isFiniteVerb(ws.at(3)) || isPlainBase(ws.at(3)) {
            return Issue(rule: "부정어 도치 (Not only)", why: "Not only가 문장 앞에 오면 조동사(be)를 주어 앞으로: Not only \(ws.at(2)) \(ws.at(3)) ✗", at: 2)
        }
        return nil
    }

    // MARK: 때·조건의 부사절에는 will ✗

    static func adverbClauseWill(_ ws: Words) -> Issue? {
        let line = " " + ws.w.joined(separator: " ") + " "
        let starters = [" as soon as ", " unless ", " until ", " till ", " by the time ", " before ", " after "]
        let mainFuture = ws.w.contains("will") || ws.w.contains(where: { $0.hasSuffix("'ll") }) || ws.w.contains("shall")
        guard mainFuture else { return nil }
        for st in starters {
            guard let r = line.range(of: st) else { continue }
            let rest = line[r.upperBound...].split(separator: " ").map(String.init)
            guard rest.count >= 2 else { continue }
            var k = 0
            if subjectPronouns.contains(rest[0]) { k = 1 }
            else if let np = nounPhrase(words(rest.joined(separator: " ")), at: 0) { k = np.end }
            else { continue }
            if k < rest.count, rest[k] == "will" || rest[k - 1].hasSuffix("'ll") {
                let offset = line[..<r.upperBound].split(separator: " ").count
                return Issue(rule: "때·조건의 부사절", why: "때·조건의 부사절(\(st.trimmingCharacters(in: .whitespaces)) …)에서는 미래도 현재형 (will ✗)", at: offset + k)
            }
        }
        // 주절 뒤의 if/when + will (명사절을 받는 동사 뒤는 빼요)
        for i in ws.w.indices where ["if", "when"].contains(ws.w[i]) && i >= 2 && ws.w[..<i].contains("will") {
            let before = Set(ws.w[..<i])
            if !before.isDisjoint(with: ["know", "wonder", "ask", "asked", "tell", "sure", "see", "doubt", "decide", "remember", "forget", "say", "check", "guess", "idea", "find", "out", "whether", "question", "knows", "wonders", "me", "us", "him", "her", "them"]) { continue }
            if subjectPronouns.contains(ws.at(i + 1)) || ws.at(i + 1) == "it", ws.at(i + 2) == "will" {
                return Issue(rule: "때·조건의 부사절", why: "때·조건의 부사절(\(ws.w[i]) …)에서는 미래도 현재형 (will ✗)", at: i + 2)
            }
        }
        return nil
    }

    // MARK: 간접의문문 어순

    static func indirectQuestion(_ ws: Words) -> Issue? {
        let askers: Set<String> = ["know", "knows", "knew", "tell", "wonder", "wondered", "ask", "asked", "remember", "guess", "sure", "idea",
                                   "explain", "understand", "show", "me", "him", "her", "us", "them", "forget", "forgot", "learn", "decide", "find", "out", "see", "check"]
        for i in ws.w.indices.dropFirst() where askers.contains(ws.w[i - 1]) && whWords.contains(ws.w[i]) {
            var k = i + 1
            if ws.w[i] == "how", ["many", "much", "old", "long", "often", "far", "tall"].contains(ws.at(k)) { k += 1; if isNoun(ws.at(k)) || nounPlural(ws.at(k)) != nil { k += 1 } }
            let aux = ws.at(k), s = ws.at(k + 1)
            if ["do", "does", "did"].contains(aux), ["i", "you", "he", "she", "we", "they"].contains(s), isBaseForm(ws.at(k + 2)) {
                if ["who", "what"].contains(ws.w[i]), k == i + 1, false { continue }
                return Issue(rule: "간접의문문 어순", why: "문장 속 의문문은 '의문사 + 주어 + 동사' (\(ws.w[i]) \(aux) \(s) … ✗)", at: k)
            }
            if ["where", "when", "why", "how"].contains(ws.w[i]) || k > i + 1, beForms.contains(aux), personSubjects.contains(s) || nounPhrase(ws, at: k + 1) != nil,
               !["going", "coming"].contains(s) {
                let subjectEnd = personSubjects.contains(s) ? k + 2 : (nounPhrase(ws, at: k + 1)?.end ?? k + 2)
                if endsPhrase(ws, subjectEnd) || isAdjectiveLike(ws.at(subjectEnd)) || ws.at(subjectEnd).hasSuffix("ing") || ["from", "now", "so", "today", "here", "there", "late", "absent", "angry", "upset", "sad"].contains(ws.at(subjectEnd)) {
                    return Issue(rule: "간접의문문 어순", why: "문장 속 의문문은 '의문사 + 주어 + 동사' (\(ws.w[i]) \(aux) \(ws.at(k + 1)) ✗)", at: k)
                }
            }
        }
        // Do you think where …? ✗
        if ws.question, ws.at(0) == "do", ws.at(1) == "you", ["think", "believe", "guess", "suppose", "imagine"].contains(ws.at(2)), whWords.contains(ws.at(3)) {
            return Issue(rule: "간접의문문 어순 (think류)", why: "think · believe · guess · suppose · imagine이면 의문사를 문장 맨 앞으로: \(ws.at(3).capitalized) do you think …?", at: 3)
        }
        return nil
    }

    // MARK: 부가의문문

    static func tagQuestion(_ ws: Words) -> Issue? {
        guard ws.question, ws.w.count >= 4, let cut = ws.comma.lastIndex(of: true), cut == ws.w.count - 3 else { return nil }
        let tagAux = ws.w[cut + 1], tagSubj = ws.w[cut + 2]
        guard subjectPronouns.contains(tagSubj) || tagSubj == "there" else { return nil }
        let negTag = tagAux.hasSuffix("n't")
        let tagBase: String = {
            if tagAux == "won't" { return "will" }
            if tagAux == "can't" { return "can" }
            if tagAux == "shan't" { return "shall" }
            return negTag ? String(tagAux.dropLast(3)) : tagAux
        }()
        // Let's …, shall we?
        if ws.at(0) == "let's" {
            return tagAux == "shall" && tagSubj == "we" ? nil : Issue(rule: "부가의문문", why: "Let's …의 부가의문문은 shall we?", at: cut + 1, length: 2, fix: "shall we")
        }
        let s = ws.at(0)
        var expectedSubj: String
        var mainStart = 1
        if s == "there" { expectedSubj = "there" }
        else if subjectPronouns.contains(s) { expectedSubj = s }
        else if let np = nounPhrase(ws, at: 0), let p = np.plural, np.end <= cut {
            expectedSubj = p ? "they" : (personNouns.contains(ws.w[np.head]) ? "" : "it"); mainStart = np.end
        } else if looksLikeName(ws, 0) { expectedSubj = "" }
        else { return nil }
        // 주절에 절이 더 있으면 (I think he is …) 어느 절의 부가의문문인지 몰라요
        if ws.w[mainStart..<cut].contains(where: { subjectPronouns.contains($0) || ["that", "and", "but", "because", "when", "if", "who", "which", "think", "believe", "guess", "suppose"].contains($0) }) { return nil }
        // 주절의 첫 동사
        var j = mainStart
        while frequency.contains(ws.at(j)) && !["never"].contains(ws.at(j)) { j += 1 }
        let v = ws.at(j)
        let negativeMain = ws.w[mainStart...cut].contains(where: { ["not", "never", "no", "nothing", "nobody", "hardly", "seldom", "rarely", "little"].contains($0) || $0.hasSuffix("n't") })
        var expectedAux: String?
        if beForms.contains(v) || ["isn't", "aren't", "wasn't", "weren't"].contains(v) {
            let b = v.hasSuffix("n't") ? String(v.dropLast(3)) : v
            expectedAux = b == "am" ? (negativeMain ? "am" : "are") : b
        } else if modals.contains(v) || ["can't", "won't", "couldn't", "shouldn't", "wouldn't", "mustn't", "cannot"].contains(v) {
            expectedAux = ["can't": "can", "cannot": "can", "won't": "will", "couldn't": "could", "shouldn't": "should", "wouldn't": "would", "mustn't": "must"][v] ?? v
        } else if ["have", "has", "had"].contains(v) || ["haven't", "hasn't", "hadn't"].contains(v), isPresentPerfect(ws, at: j) || ws.at(j + 1).hasSuffix("ed") || v.hasSuffix("n't") {
            expectedAux = v.hasSuffix("n't") ? String(v.dropLast(3)) : v
        } else if ["don't", "doesn't", "didn't", "do", "does", "did"].contains(v) {
            expectedAux = v.hasSuffix("n't") ? String(v.dropLast(3)) : v
        } else if isThirdForm(v) { expectedAux = "does" }
        else if isPastOnly(v) || (base(v).map { $0 != v && DoitEnglish.pastForms($0).contains(v) } ?? false) { expectedAux = "did" }
        else if isPlainBase(v), !thirdSingular.contains(s) { expectedAux = "do" }
        guard var aux = expectedAux else { return nil }
        if aux == "am", !negativeMain { aux = "are" }
        let shouldBeNegative = !negativeMain
        let tagFix: String = {
            if shouldBeNegative {
                if aux == "will" { return "won't" }
                if aux == "can" { return "can't" }
                if aux == "am" { return "aren't" }
                return aux + "n't"
            }
            return aux
        }()
        let subjFix = expectedSubj == "i" ? "I" : expectedSubj
        let auxOK = (tagBase == aux || aux == "are" && s == "i" && tagAux == "aren't") && negTag == shouldBeNegative
        let subjOK = expectedSubj.isEmpty || tagSubj == expectedSubj
        if !auxOK || !subjOK {
            return Issue(rule: "부가의문문", why: "앞 문장이 \(negativeMain ? "부정" : "긍정")이고 동사가 \(v)라서 부가의문문은 '\(tagFix) \(expectedSubj.isEmpty ? tagSubj : subjFix)?'",
                         at: cut + 1, length: 2, fix: "\(tagFix) \(expectedSubj.isEmpty ? tagSubj : subjFix)")
        }
        return nil
    }

    // MARK: 가정법 (I wish · If + 과거완료)

    static func subjunctiveRules(_ ws: Words) -> Issue? {
        // I wish + 현재형 ✗
        for i in ws.w.indices where ["wish", "wishes", "wished"].contains(ws.w[i]) && i > 0 && subjectPronouns.contains(ws.w[i - 1]) {
            var k = i + 1
            if ws.at(k) == "that" { k += 1 }
            guard subjectPronouns.contains(ws.at(k)) else { continue }
            let v = ws.at(k + 1)
            let fixes = ["am": "were", "is": "were", "are": "were", "can": "could", "will": "would", "has": "had", "have": "had", "do": "did",
                         "does": "did", "don't": "didn't", "doesn't": "didn't", "can't": "couldn't", "won't": "wouldn't", "isn't": "weren't", "aren't": "weren't"]
            if let f = fixes[v] {
                if v == "have" || v == "has", ws.at(k + 2).hasSuffix("ed") || isPresentPerfect(ws, at: k + 1) { return Issue(rule: "I wish 가정법", why: "I wish + 가정법: 과거 사실의 반대는 had + p.p.", at: k + 1, fix: "had") }
                return Issue(rule: "I wish 가정법", why: "I wish 뒤에는 가정법(과거형): \(v) → \(f)", at: k + 1, fix: f)
            }
            if isThirdForm(v) && !isNoun(v) || isPlainBase(v) && actionVerbs.contains(v) && ws.at(k) != "you" {
                if let b = base(v) { return Issue(rule: "I wish 가정법", why: "I wish 뒤에는 가정법(과거형): \(v) → \(DoitEnglish.pastForms(b).first ?? v)", at: k + 1, fix: DoitEnglish.pastForms(b).first) }
            }
        }
        // If + had p.p. …, 주어 + will/would + 원형 (지금을 말하는 말이 없을 때)
        if ws.at(0) == "if", let cut = ws.comma.firstIndex(of: true), cut >= 3 {
            let clause = Array(ws.w[1...cut]), main = Array(ws.w[(cut + 1)...])
            let hadPP = clause.indices.contains { j in clause[j] == "had" && j + 1 < clause.count && (base(clause[j + 1]).map { DoitEnglish.ppForms($0).contains(clause[j + 1]) && $0 != clause[j + 1] } ?? false || clause[j + 1] == "been") }
            if hadPP, main.count >= 3 {
                if let m = main.firstIndex(where: { ["will", "can", "shall"].contains($0) }), m <= 2 {
                    return Issue(rule: "가정법 과거완료", why: "If + had p.p. …이면 주절은 would/could + have p.p. (\(main[m]) ✗)", at: cut + 1 + m, fix: ["will": "would", "can": "could", "shall": "should"][main[m]].map { $0 + " have" })
                }
                if let m = main.firstIndex(where: { ["would", "could", "might"].contains($0) }), m <= 2, m + 1 < main.count,
                   case let nxt = main[m + 1] == "not" && m + 2 < main.count ? main[m + 2] : main[m + 1],
                   nxt != "have", actionVerbs.contains(nxt), !["have", "know", "live", "like", "love", "want", "need", "feel"].contains(nxt),
                   !main.contains(where: { ["now", "today", "still", "anymore", "these", "tonight"].contains($0) }) {
                    return Issue(rule: "가정법 과거완료", why: "If + had p.p. …(과거 사실의 반대)이면 주절은 \(main[m]) + have p.p. (지금을 말하는 now 같은 말이 없으면)", at: cut + 2 + m)
                }
            }
            // If + would have p.p. ✗
            if clause.count >= 4, let w = clause.firstIndex(of: "would"), w + 1 < clause.count, clause[w + 1] == "have" {
                return Issue(rule: "가정법 과거완료", why: "if절에는 would를 쓰지 않아요: If + had p.p.", at: 1 + w, length: 2, fix: "had")
            }
            // If + 주어 + were / had + 명사 …, 주어 + will ✗ (가정법 과거)
            if clause.count >= 3, subjectPronouns.contains(clause[0]), clause[1] == "had", !hadPP, ["a", "an", "more", "enough", "money", "time", "wings", "a lot"].contains(clause[2]),
               main.count >= 2, subjectPronouns.contains(main[0]), ["will", "can"].contains(main[1]) {
                return Issue(rule: "가정법 과거", why: "If + 주어 + 과거형 …(지금 사실의 반대)이면 주절은 would/could + 동사원형 (\(main[1]) ✗)", at: cut + 2, fix: main[1] == "will" ? "would" : "could")
            }
        }
        return nil
    }

    // MARK: 목적격 보어 (사역 · 지각 · want/ask/tell + 목적어 + to부정사)

    static func objectComplement(_ ws: Words) -> Issue? {
        let objects: Set<String> = ["me", "you", "him", "her", "us", "them"]
        let toVerbs: Set<String> = ["want", "wants", "wanted", "ask", "asks", "asked", "tell", "tells", "told", "advise", "advised", "allow",
                                    "allows", "allowed", "expect", "expects", "expected", "order", "ordered", "encourage", "encouraged",
                                    "force", "forced", "persuade", "persuaded", "get", "gets", "got", "enable", "enabled", "cause", "caused", "would like", "'d like"]
        let perception: Set<String> = ["see", "saw", "seen", "watch", "watched", "hear", "heard", "feel", "felt", "notice", "noticed"]
        let perceivedActs: Set<String> = ["cross", "dance", "sing", "run", "play", "come", "go", "enter", "leave", "cry", "fall", "walk", "swim",
                                          "jump", "fly", "ride", "open", "steal", "break", "shout", "laugh", "talk", "call", "knock", "ring", "shake", "move"]
        let thingNouns2: Set<String> = ["car", "hair", "computer", "bike", "watch", "house", "room", "teeth", "photo", "picture", "window",
                                        "shoes", "clothes", "phone", "roof", "bag", "door", "glasses", "eyes", "camera", "laptop", "bicycle", "nails", "dress"]
        for i in ws.w.indices.dropLast(2) {
            let t = ws.w[i], o = ws.w[i + 1], v = ws.w[i + 2]
            // want/ask/tell + 목적어 + 동사원형 ✗
            let pairVerb = toVerbs.contains(t) || (t == "like" && i > 0 && (ws.w[i - 1] == "would" || ws.w[i - 1].hasSuffix("'d")))
            if pairVerb, objects.contains(o) || nounPhrase(ws, at: i + 1).map({ personNouns.contains(ws.w[$0.head]) }) == true {
                let k = objects.contains(o) ? i + 2 : (nounPhrase(ws, at: i + 1)?.end ?? i + 2)
                let w = ws.at(k)
                if isPlainBase(w) || w == "go" || w == "do", actionVerbs.contains(w) || w == "do", !isNoun(w), !nounishVerbs.contains(w) || objects.contains(o) {
                    if ["get", "gets", "got"].contains(t), ["home", "back", "up", "out", "ready", "lost", "married"].contains(w) { continue }
                    if ["tell", "tells", "told", "ask", "asks", "asked"].contains(t), ["what", "how", "where", "when", "why", "if", "whether"].contains(w) { continue }
                    return Issue(rule: "목적격 보어 to부정사", why: "\(t) + 목적어 + to부정사: \(w) → to \(w)", at: k, fix: "to " + ws.raw[k])
                }
                if w.hasSuffix("ing"), let b = base(w), DoitEnglish.ingForm(b) == w, actionVerbs.contains(b), !ingNouns.contains(w), !["want", "wants", "wanted", "get", "gets", "got"].contains(t),
                   !(emotionVerbs[b] != nil) {
                    return Issue(rule: "목적격 보어 to부정사", why: "\(t) + 목적어 + to부정사: \(w) → to \(b)", at: k, fix: "to " + b)
                }
            }
            // 사역동사 make/let + 목적어 + -ing ✗, help + 목적어 + -ing ✗
            if ["make", "makes", "made", "let", "lets", "help", "helps", "helped"].contains(t), objects.contains(o), v.hasSuffix("ing"), let b = base(v),
               DoitEnglish.ingForm(b) == v, actionVerbs.contains(b), emotionVerbs[b] == nil, !ingNouns.contains(v) {
                return Issue(rule: "사역동사 + 동사원형", why: "\(t) + 목적어 + 동사원형: \(v) → \(b)", at: i + 2, fix: b)
            }
            // have + 목적어(사람) + to ✗
            if ["have", "has", "had"].contains(t), objects.contains(o), v == "to", isBaseForm(ws.at(i + 3)), ws.at(i + 3) != "thank", i > 0, personSubjects.contains(ws.w[i - 1]) || ws.w[i - 1] == "will" {
                return Issue(rule: "사역동사 + 동사원형", why: "사역동사 have + 목적어 + 동사원형 (to ✗)", at: i + 2, fix: "")
            }
            // 지각동사 + 목적어 + to부정사 ✗
            if perception.contains(t), objects.contains(o) || looksLikeName(ws, i + 1), v == "to", perceivedActs.contains(ws.at(i + 3)) {
                return Issue(rule: "지각동사 + 동사원형/-ing", why: "지각동사 \(t) + 목적어 + 동사원형/-ing (to ✗)", at: i + 2, fix: "")
            }
            // have/get + 사물 + 원형 ✗ → 과거분사 ("had my car wash")
            if ["have", "has", "had", "get", "got", "gets"].contains(t), ["my", "his", "her", "the", "their", "our", "your"].contains(o), thingNouns2.contains(v) {
                let w = ws.at(i + 3)
                let fixable: Set<String> = ["fix", "repair", "wash", "paint", "check", "dye", "deliver", "print", "test", "examine", "replace", "take", "steal"]
                if fixable.contains(w), let pp = DoitEnglish.ppForms(w).first, pp != w {
                    return Issue(rule: "사역동사 + 목적어 + p.p.", why: "목적어(\(v))가 '되는' 것이라 과거분사: \(w) → \(pp)", at: i + 3, fix: pp)
                }
            }
        }
        return nil
    }

    // MARK: 수일치 더 (학문·나라 이름, most of + 명사, 동명사 · to부정사 주어)

    static func agreementMisc(_ ws: Words) -> Issue? {
        // 문장 처음 most/some/all/half/a lot of + 명사 + 동사
        let w0 = ws.at(0)
        var k: Int?
        if ["most", "some", "all", "half", "lots", "none", "plenty"].contains(w0), ws.at(1) == "of" { k = 2 }
        if w0 == "a", ws.at(1) == "lot", ws.at(2) == "of" { k = 3 }
        if let k {
            var j = k
            if ["the", "my", "his", "her", "our", "their", "your", "these", "those", "this", "that"].contains(ws.at(j)) { j += 1 }
            while isAdjectiveLike(ws.at(j)), !isNoun(ws.at(j)) { j += 1 }
            if let p = nounPlural(ws.at(j)), !(w0 == "none") {
                let v = ws.at(j + 1)
                if let vn = verbNumber(v), vn != p {
                    return Issue(rule: "부분 표현의 수일치", why: "\(w0) of + 명사의 동사는 of 뒤 명사(\(ws.at(j)))에 맞춰요: \(v) → \(flipNumber(v) ?? "")", at: j + 1, fix: flipNumber(v))
                }
            }
        }
        // 동명사 주어 (뒤에 목적어·전치사구) + 복수 동사 ✗
        if w0.hasSuffix("ing"), let b = base(w0), DoitEnglish.ingForm(b) == w0, actionVerbs.contains(b) || ["read", "use"].contains(b) {
            let n = ws.at(1)
            let objects: Set<String> = ["games", "movies", "books", "friends", "pictures", "photos", "vegetables", "sports", "soccer", "baseball",
                                        "basketball", "tennis", "languages", "bikes", "instruments", "novels", "comics", "cartoons", "songs", "letters",
                                        "computer", "video", "tv", "fruits", "comic", "online", "mobile"]
            let gerundVerbs2: Set<String> = ["play", "watch", "make", "take", "learn", "visit", "read", "eat", "ride", "use", "write", "sing", "draw"]
            if neutralDeterminers.contains(n) || singularDeterminers.contains(n) || pluralDeterminers.contains(n) || prepositionWords.contains(n) || ["too", "a"].contains(n)
                || gerundVerbs2.contains(b) && objects.contains(n) {
                for j in 2..<min(ws.w.count, 9) {
                    let v = ws.w[j]
                    if ws.comma[j - 1] || ["and", "or", "who", "which", "that"].contains(v) { break }
                    if ["are", "were", "have"].contains(v) {
                        return Issue(rule: "동명사 주어는 단수", why: "동명사(\(w0) …) 주어는 단수: \(v) → \(flipNumber(v) ?? "")", at: j, fix: flipNumber(v))
                    }
                    if isFiniteVerb(v) { break }
                }
            }
        }
        // to부정사 주어 + 복수 동사 ✗
        if w0 == "to", isBaseForm(ws.at(1)), !ws.comma[0], !ws.comma[1] {
            for j in 2..<min(ws.w.count, 9) {
                let v = ws.w[j]
                if ws.comma[j - 1] || ["and", "or", "who", "which", "that"].contains(v) { break }
                if ["are", "were"].contains(v) { return Issue(rule: "to부정사 주어는 단수", why: "to부정사 주어는 단수: \(v) → \(flipNumber(v) ?? "")", at: j, fix: flipNumber(v)) }
                if isFiniteVerb(v) { break }
            }
        }
        return nil
    }
}
