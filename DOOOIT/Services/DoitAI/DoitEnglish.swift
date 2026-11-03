import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 두잇 AI 영어 선생님 (외부 AI 없이 직접 만든 규칙 + 내장 자료)
/// - 문법 개념 설명, 동사·명사·형용사 변화, 숙어, 간단한 문장 교정, 영어 인사말, 내장 단어장
/// - 사전: 무료 Free Dictionary API (키 없음)
enum DoitEnglish {

    // MARK: - 진입점

    /// 영어 관련 질문이면 답, 아니면 nil (오프라인, 즉시)
    static func answer(_ question: String) -> String? {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")
        guard !text.isEmpty, text.count <= 400 else { return nil }
        let lower = text.lowercased()
        let compact = EngText.compact(lower)
        if EngText.isAppCommand(lower) { return nil }
        let hasHangul = EngText.hasHangul(text)

        // 1. 영어로만 한 짧은 인사·대화
        if !hasHangul, let reply = EngSmallTalk.reply(to: lower) { return reply }

        // 2. 문장 교정 ("He go to school 문법 맞아?")
        if EngText.asksCheck(lower, compact: compact), let sentence = EngText.englishSentence(in: text),
           sentence.split(separator: " ").count >= 2 {
            return EngChecker.report(sentence, intro: nil)
        }

        // 3. 형태 변화 ("go 과거형", "child 복수형", "big 비교급", "past tense of go")
        if let reply = EngForms.answer(text, lower: lower, compact: compact, hasHangul: hasHangul) { return reply }

        // 3-2. 한국어 낱말을 영어로 ("사과를 영어로", "행복하다 영어로 뭐야")
        if hasHangul, let reply = toEnglish(text) { return reply }

        // 4. 숙어 ("look forward to 뜻")
        if let reply = EngIdioms.answer(lower, hasHangul: hasHangul) { return reply }

        // 5. 문법 개념 ("현재완료 설명해줘")
        if hasHangul || lower.contains("grammar"), let reply = EngGrammar.answer(compact) { return reply }

        // 6. 단어 뜻 (내장 단어장)
        if let word = lookupWord(in: text) {
            let wordCount = text.split(separator: " ").count
            let asksMeaning = hasHangul ? EngText.asksMeaning(compact) : wordCount == 1
            if asksMeaning, let reply = EngWords.meaningReply(word) { return reply }
        }

        // 7. 영어 문장만 보냈을 때: 흔한 실수가 있으면 고쳐 줌
        if !hasHangul, let sentence = EngText.englishSentence(in: text), sentence.split(separator: " ").count >= 3 {
            let result = EngChecker.check(sentence)
            if result.fixes.contains(where: { !$0.minor }) {
                return EngChecker.report(sentence, intro: "혹시 이 문장을 확인하려던 거라면, 이렇게 고칠 수 있어요.")
            }
        }
        return nil
    }

    /// 영어 단어 사전 (무료 키 없는 Free Dictionary API)
    /// 발음기호, 품사별 영어 뜻 2~3개, 예문, 유의어. 실패하면 nil
    static func define(_ word: String) async -> String? {
        let w = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty, w.count <= 40,
              w.allSatisfy({ ($0.isLetter && $0.isASCII) || $0 == "-" || $0 == "'" || $0 == " " }),
              let encoded = w.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/" + encoded) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("DOOOIT/1.0 (iOS study planner)", forHTTPHeaderField: "User-Agent")
        guard let data = await EngNetwork.fetch(request) else { return nil }
        return EngDictionary.format(data: data, word: w)
    }

    /// 문장에서 찾아볼 영어 단어 하나 ("abundant 뜻 알려줘" → "abundant"), 없으면 nil
    static func lookupWord(in question: String) -> String? {
        EngText.englishWords(in: question).first { !EngText.lookupStopWords.contains($0) }
    }

    /// 내장 사전의 한국어 뜻 (없으면 nil)
    static func koreanMeaning(of word: String) -> String? {
        let w = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let meaning = EngWords.dictionary[w] { return meaning }
        if let meaning = EngVerbs.meaning(of: w) { return meaning }
        if let (base, _) = EngVerbs.analyze(w), let meaning = EngWords.dictionary[base] ?? EngVerbs.meaning(of: base) {
            return meaning
        }
        return nil
    }
}

// MARK: - 문장 분석 도구

private enum EngText {
    static func compact(_ lower: String) -> String {
        lower.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "")
    }

    static func hasHangul(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) || (0x3131...0x318E).contains($0.value) }
    }

    static func has(_ text: String, _ words: [String]) -> Bool { words.contains { text.contains($0) } }

    /// 앱 명령(타이머, 일정, 단어 추가…)은 영어 엔진이 가로채지 않음
    static func isAppCommand(_ lower: String) -> Bool {
        if has(lower, ["타이머", "스톱워치", "단어 추가", "단어추가", "추가해", "추가:", "넣어줘", "넣어 줘", "저장해", "등록해",
                       "일정", "플랜", "삭제", "지워", "완료했", "통계", "디데이", "d-day", "메모", "목표", "알림", "오답노트"]) {
            return true
        }
        if lower.contains("단어"), lower.contains(":") { return true }
        if lower.range(of: #"\d+\s*(분|시간)"#, options: .regularExpression) != nil { return true }
        return false
    }

    static func asksCheck(_ lower: String, compact: String) -> Bool {
        has(compact, ["문법", "맞아", "맞나", "맞는", "맞게", "틀린", "틀렸", "고쳐", "교정", "첨삭", "어색", "자연스러", "확인해", "올바른"])
            || has(lower, ["check", "correct this", "is this right", "is it right", "is this correct", "proofread"])
    }

    static func asksMeaning(_ compact: String) -> Bool {
        has(compact, ["뜻", "의미", "무슨말", "해석", "뭐야", "뭔데", "뭐지", "meaning", "mean", "무슨단어", "한국어로", "우리말로", "번역"])
    }

    /// 영어 단어들 (소문자), 한글 조사가 붙어 있어도 영어 부분만
    static func englishWords(in text: String) -> [String] {
        var words: [String] = []
        var current = ""
        func flush() {
            let trimmed = current.trimmingCharacters(in: CharacterSet(charactersIn: "-'"))
            if trimmed.count >= 2 { words.append(trimmed.lowercased()) }
            current = ""
        }
        for ch in text {
            if (ch.isLetter && ch.isASCII) || ((ch == "-" || ch == "'") && !current.isEmpty) {
                current.append(ch)
            } else {
                flush()
            }
        }
        flush()
        return words
    }

    static let lookupStopWords: Set<String> = [
        "ai", "doooit", "ing", "pp", "es", "ed", "er", "est", "vs", "ok", "okay", "d-day", "dday", "ocr", "pdf", "ox", "p.p",
        "tv", "app", "sns"
    ]

    /// 글 속의 가장 긴 영어 문장 부분
    static func englishSentence(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"[A-Za-z][A-Za-z0-9 ,'"\.\?!\-]*"#) else { return nil }
        let ns = text as NSString
        var best: String?
        var bestCount = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            var part = ns.substring(with: match.range).trimmingCharacters(in: .whitespaces)
            part = part.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            for prefix in ["check ", "Check ", "correct ", "Correct ", "grammar ", "Grammar "] where part.hasPrefix(prefix) {
                part = String(part.dropFirst(prefix.count))
            }
            let count = part.split(separator: " ").count
            if count > bestCount { best = part; bestCount = count }
        }
        return best
    }

    /// 단어가 모음 소리로 시작하는지 (a / an 고르기)
    static func startsWithVowelSound(_ word: String) -> Bool {
        let lower = word.lowercased()
        guard let first = lower.first else { return false }
        if word.count >= 2, word == word.uppercased(), word.allSatisfy({ $0.isLetter }) {
            return "aefhilmnorsx".contains(first)   // 약어: an MP3, an FBI, a UFO
        }
        if lower.hasPrefix("uni"), let next = lower.dropFirst(3).first, "nmd".contains(next) { return true } // unimportant
        for prefix in ["uni", "use", "usu", "uti", "ura", "ure", "eu", "ewe", "one", "once", "ubiq", "ukulele", "ufo"]
        where lower.hasPrefix(prefix) { return false }
        for prefix in ["hour", "honest", "honor", "honour", "heir"] where lower.hasPrefix(prefix) { return true }
        return "aeiou".contains(first)
    }

    /// 음절 수 (대략)
    static func syllables(_ word: String) -> Int {
        let chars = Array(word.lowercased())
        var count = 0
        var previousVowel = false
        for (index, ch) in chars.enumerated() {
            let vowel = "aeiou".contains(ch) || (ch == "y" && index > 0)
            if vowel && !previousVowel { count += 1 }
            previousVowel = vowel
        }
        if word.hasSuffix("e") && !word.hasSuffix("le") && !word.hasSuffix("ee") && count > 1 { count -= 1 }
        return max(count, 1)
    }

    static func isVowel(_ ch: Character) -> Bool { "aeiou".contains(ch) }

    /// 단모음 + 단자음으로 끝나는 1음절 단어 (big, stop, run)
    static func endsCVC(_ word: String) -> Bool {
        let chars = Array(word)
        guard chars.count >= 3 else {
            return chars.count == 2 && isVowel(chars[0]) == false && false
        }
        let last = chars[chars.count - 1], middle = chars[chars.count - 2], before = chars[chars.count - 3]
        return !isVowel(last) && !"wxy".contains(last) && isVowel(middle) && !isVowel(before)
            && !(before == "u" && chars.count >= 4 && chars[chars.count - 4] == "q")
    }
}

// MARK: - 영어 인사·짧은 대화

private enum EngSmallTalk {
    private struct Rule {
        let phrases: [String]
        let maxWords: Int
        let reply: String
    }

    private static let rules: [Rule] = [
        Rule(phrases: ["how are you", "how are you doing", "how's it going", "how is it going", "what's up", "whats up", "how have you been", "how was your day"],
             maxWords: 8,
             reply: "I'm doing great, thanks for asking! How about you?\n(저는 잘 지내요, 물어봐 줘서 고마워요! 당신은요?)\n\n팁: \"I'm good.\", \"Not bad.\", \"Pretty good, thanks.\"로 대답할 수 있어요."),
        Rule(phrases: ["what's your name", "what is your name", "whats your name", "who are you", "your name"],
             maxWords: 7,
             reply: "I'm DOOOIT AI, your study buddy. Nice to meet you!\n(저는 공부 친구 두잇 AI예요. 만나서 반가워요!)\n\n팁: 이름을 물을 때 \"May I ask your name?\"이라고 하면 더 공손해요."),
        Rule(phrases: ["nice to meet you", "nice meeting you", "pleased to meet you", "glad to meet you"],
             maxWords: 7,
             reply: "Nice to meet you, too!\n(저도 만나서 반가워요!)\n\n팁: 대답할 때는 끝에 too를 붙여요."),
        Rule(phrases: ["good morning"], maxWords: 5,
             reply: "Good morning! Let's have a productive day.\n(좋은 아침이에요! 오늘도 알찬 하루 보내요.)"),
        Rule(phrases: ["good afternoon"], maxWords: 5,
             reply: "Good afternoon! How's your study going?\n(안녕하세요! 공부는 잘 되고 있어요?)"),
        Rule(phrases: ["good evening"], maxWords: 5,
             reply: "Good evening! Did you have a good day?\n(안녕하세요! 오늘 하루 잘 보냈어요?)"),
        Rule(phrases: ["good night", "nighty night", "sweet dreams"], maxWords: 6,
             reply: "Good night! Sleep well and see you tomorrow.\n(잘 자요! 푹 자고 내일 봐요.)\n\n팁: 잠을 잘 자는 것도 기억력에 큰 도움이 돼요."),
        Rule(phrases: ["thank you", "thanks", "thx", "thank u", "thanks a lot"], maxWords: 6,
             reply: "You're welcome! Happy to help.\n(천만에요! 도움이 돼서 기뻐요.)\n\n팁: \"No problem.\", \"My pleasure.\", \"Anytime.\"도 자주 써요."),
        Rule(phrases: ["i'm sorry", "i am sorry", "sorry"], maxWords: 6,
             reply: "No worries! It's totally fine.\n(괜찮아요! 전혀 문제없어요.)"),
        Rule(phrases: ["i'm tired", "i am tired", "i'm sleepy", "i am sleepy", "so tired", "i'm exhausted", "i am exhausted"], maxWords: 8,
             reply: "You've worked hard! How about a short break?\n(열심히 했네요! 잠깐 쉬는 건 어때요?)\n\n팁: 25분 공부하고 5분 쉬는 방법(뽀모도로)을 써 보세요."),
        Rule(phrases: ["i'm bored", "i am bored", "so bored", "boring"], maxWords: 6,
             reply: "Let's make it fun! Want to try a quick quiz?\n(재미있게 해 봐요! 짧은 퀴즈 한번 풀어 볼래요?)\n\n팁: bored는 '내가 지루함을 느낄 때', boring은 '무언가가 지루할 때' 써요."),
        Rule(phrases: ["i'm sad", "i am sad", "i'm stressed", "i am stressed", "i'm upset", "i am upset", "i feel bad", "i'm depressed", "i feel sad", "i'm worried", "i am worried"],
             maxWords: 9,
             reply: "I'm sorry to hear that. You're doing your best, and that's enough.\n(그랬군요. 지금도 최선을 다하고 있어요. 그걸로 충분해요.)\n\n팁: 힘들 땐 잠깐 산책하거나 물 한 잔 마시고 오는 것도 좋아요."),
        Rule(phrases: ["i'm happy", "i am happy", "i feel good", "i'm great", "i'm good", "i'm fine", "so happy", "i feel great", "i'm excited"],
             maxWords: 7,
             reply: "That's great to hear! Keep up the good work.\n(좋다니 저도 기뻐요! 이대로 계속 힘내요.)"),
        Rule(phrases: ["i'm hungry", "i am hungry"], maxWords: 6,
             reply: "Go grab something to eat! Your brain needs energy, too.\n(뭐 좀 먹고 와요! 뇌도 에너지가 필요해요.)"),
        Rule(phrases: ["bye", "goodbye", "good bye", "see you", "see ya", "talk to you later", "see you later"], maxWords: 6,
             reply: "Bye! See you next time.\n(안녕! 다음에 또 봐요.)\n\n팁: \"Take care!\"(잘 지내!)도 자주 써요."),
        Rule(phrases: ["i love you", "love you"], maxWords: 6,
             reply: "Aw, thank you! I'm always here to help you study.\n(고마워요! 언제나 공부를 도와줄게요.)"),
        Rule(phrases: ["how old are you"], maxWords: 6,
             reply: "I'm an app, so I don't have an age. But I'm always learning!\n(저는 앱이라 나이가 없어요. 그래도 늘 배우는 중이에요!)"),
        Rule(phrases: ["where are you from"], maxWords: 6,
             reply: "I live in your phone! Where are you from?\n(저는 휴대폰 안에 살아요! 당신은 어디 출신이에요?)\n\n팁: \"I'm from Korea.\" 또는 \"I'm from Seoul.\"로 대답해요."),
        Rule(phrases: ["do you speak english", "can you speak english", "let's speak english", "speak english", "let's talk in english"], maxWords: 8,
             reply: "Yes! Let's practice English together. Try saying \"How are you?\" or ask me about grammar.\n(네! 같이 영어 연습해요. \"How are you?\"라고 말해 보거나 문법을 물어보세요.)"),
        Rule(phrases: ["what can you do", "help me", "can you help me", "can you help"], maxWords: 8,
             reply: "I can explain grammar, show verb forms, check your sentences, and tell you word meanings.\n(문법 설명, 동사 변화, 문장 교정, 단어 뜻을 도와줄 수 있어요.)\n\n예: \"현재완료 설명해줘\", \"go 과거분사\", \"He go to school 맞아?\""),
        Rule(phrases: ["hello", "hi", "hey", "hiya", "hi there", "hello there", "yo"], maxWords: 4,
             reply: "Hello! Nice to see you. How's your study going today?\n(안녕하세요! 반가워요. 오늘 공부는 어때요?)")
    ]

    static func reply(to lower: String) -> String? {
        let normalized = lower.map { ch -> Character in
            (ch.isLetter && ch.isASCII) || ch == "'" || ch == " " ? ch : " "
        }
        let words = String(normalized).split(separator: " ").map(String.init)
        guard !words.isEmpty, words.allSatisfy({ $0.allSatisfy { $0.isASCII } }) else { return nil }
        let padded = " " + words.joined(separator: " ") + " "
        for rule in rules where words.count <= rule.maxWords {
            if rule.phrases.contains(where: { padded.contains(" \($0) ") }) { return rule.reply }
        }
        return nil
    }
}

// MARK: - 사전 (Free Dictionary API)

private enum EngNetwork {
    static func fetch(_ request: URLRequest) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil { continuation.resume(returning: nil); return }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    continuation.resume(returning: nil); return
                }
                continuation.resume(returning: data)
            }
            task.resume()
        }
    }
}

private enum EngDictionary {
    static let partsOfSpeech: [String: String] = [
        "noun": "명사", "verb": "동사", "adjective": "형용사", "adverb": "부사", "preposition": "전치사",
        "conjunction": "접속사", "pronoun": "대명사", "interjection": "감탄사", "determiner": "한정사",
        "exclamation": "감탄사", "article": "관사", "numeral": "수사"
    ]

    static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func format(data: Data, word: String) -> String? {
        guard let entries = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]], !entries.isEmpty else { return nil }
        let title = (entries.first?["word"] as? String) ?? word

        var phonetic = ""
        for entry in entries {
            if let p = entry["phonetic"] as? String, !p.isEmpty { phonetic = p; break }
            if let list = entry["phonetics"] as? [[String: Any]],
               let p = list.compactMap({ $0["text"] as? String }).first(where: { !$0.isEmpty }) { phonetic = p; break }
        }

        var order: [String] = []
        var definitions: [String: [String]] = [:]
        var example: String?
        var synonyms: [String] = []
        for entry in entries {
            for meaning in (entry["meanings"] as? [[String: Any]]) ?? [] {
                let pos = (meaning["partOfSpeech"] as? String) ?? ""
                if definitions[pos] == nil {
                    guard order.count < 3 else { continue }
                    order.append(pos)
                    definitions[pos] = []
                }
                for synonym in (meaning["synonyms"] as? [String]) ?? [] where !synonyms.contains(synonym) { synonyms.append(synonym) }
                for definition in (meaning["definitions"] as? [[String: Any]]) ?? [] {
                    if let text = definition["definition"] as? String, !text.isEmpty, (definitions[pos]?.count ?? 0) < 2 {
                        definitions[pos]?.append(clean(text))
                    }
                    if example == nil, let e = definition["example"] as? String, !e.isEmpty { example = clean(e) }
                    for synonym in (definition["synonyms"] as? [String]) ?? [] where !synonyms.contains(synonym) { synonyms.append(synonym) }
                }
            }
        }
        guard order.contains(where: { !(definitions[$0] ?? []).isEmpty }) else { return nil }

        var lines = ["**\(title)**" + (phonetic.isEmpty ? "" : " \(phonetic)")]
        if let korean = DoitEnglish.koreanMeaning(of: title) { lines.append("한국어 뜻: \(korean)") }
        for pos in order {
            let list = definitions[pos] ?? []
            guard !list.isEmpty else { continue }
            let label = partsOfSpeech[pos].map { "\($0)(\(pos))" } ?? pos
            lines.append(label + ":")
            for (index, definition) in list.enumerated() { lines.append("\(index + 1)) \(definition)") }
        }
        if let example { lines.append("예문: \(example)") }
        if !synonyms.isEmpty { lines.append("유의어: " + synonyms.prefix(5).joined(separator: ", ")) }
        lines.append("출처: Free Dictionary API (Wiktionary)")
        return lines.joined(separator: "\n")
    }
}

// MARK: - 동사 변화

private enum EngVerbs {
    struct Irregular {
        let base: String
        let past: [String]
        let pp: [String]
        let meaning: String
    }

    enum FormKind { case past, pp, pastAndPP, third, ing }

    /// 원형|과거|과거분사|뜻 (여러 형태는 / 로)
    private static let irregularRaw = """
    arise|arose|arisen|생기다, 일어나다
    awake|awoke|awoken|깨다, 깨우다
    be|was/were|been|~이다, 있다
    bear|bore|born/borne|낳다, 견디다
    beat|beat|beaten|이기다, 때리다
    become|became|become|~이 되다
    begin|began|begun|시작하다
    behold|beheld|beheld|보다
    bend|bent|bent|구부리다
    bet|bet|bet|내기하다
    bid|bid|bid|입찰하다
    bind|bound|bound|묶다
    bite|bit|bitten|물다
    bleed|bled|bled|피를 흘리다
    blow|blew|blown|불다
    break|broke|broken|깨다, 부수다
    breed|bred|bred|기르다, 번식하다
    bring|brought|brought|가져오다
    broadcast|broadcast|broadcast|방송하다
    build|built|built|짓다
    burn|burned/burnt|burned/burnt|타다, 태우다
    burst|burst|burst|터지다
    buy|bought|bought|사다
    cast|cast|cast|던지다
    catch|caught|caught|잡다
    choose|chose|chosen|고르다
    cling|clung|clung|매달리다
    come|came|come|오다
    cost|cost|cost|비용이 들다
    creep|crept|crept|기다
    cut|cut|cut|자르다
    deal|dealt|dealt|다루다
    dig|dug|dug|파다
    dive|dived/dove|dived|잠수하다
    do|did|done|하다
    draw|drew|drawn|그리다, 끌다
    dream|dreamed/dreamt|dreamed/dreamt|꿈꾸다
    drink|drank|drunk|마시다
    drive|drove|driven|운전하다
    dwell|dwelt/dwelled|dwelt/dwelled|살다, 거주하다
    eat|ate|eaten|먹다
    fall|fell|fallen|떨어지다, 넘어지다
    feed|fed|fed|먹이를 주다
    feel|felt|felt|느끼다
    fight|fought|fought|싸우다
    find|found|found|찾다, 발견하다
    fit|fit/fitted|fit/fitted|맞다
    flee|fled|fled|달아나다
    fling|flung|flung|내던지다
    fly|flew|flown|날다
    forbid|forbade|forbidden|금지하다
    forecast|forecast|forecast|예보하다
    foresee|foresaw|foreseen|예견하다
    forget|forgot|forgotten|잊다
    forgive|forgave|forgiven|용서하다
    forsake|forsook|forsaken|저버리다
    freeze|froze|frozen|얼다
    get|got|got/gotten|얻다, 되다
    give|gave|given|주다
    go|went|gone|가다
    grind|ground|ground|갈다
    grow|grew|grown|자라다, 기르다
    hang|hung|hung|걸다, 매달다
    have|had|had|가지다, 먹다
    hear|heard|heard|듣다
    hide|hid|hidden|숨기다, 숨다
    hit|hit|hit|치다
    hold|held|held|잡다, 개최하다
    hurt|hurt|hurt|다치게 하다, 아프다
    keep|kept|kept|유지하다, 계속하다
    kneel|knelt/kneeled|knelt/kneeled|무릎을 꿇다
    knit|knit/knitted|knit/knitted|뜨개질하다
    know|knew|known|알다
    lay|laid|laid|놓다, (알을) 낳다
    lead|led|led|이끌다
    lean|leaned/leant|leaned/leant|기대다
    leap|leaped/leapt|leaped/leapt|뛰다
    learn|learned/learnt|learned/learnt|배우다
    leave|left|left|떠나다, 남기다
    lend|lent|lent|빌려주다
    let|let|let|~하게 하다
    lie|lay|lain|눕다, 놓여 있다
    light|lit/lighted|lit/lighted|불을 켜다
    lose|lost|lost|잃다, 지다
    make|made|made|만들다
    mean|meant|meant|의미하다
    meet|met|met|만나다
    mislead|misled|misled|잘못 이끌다
    mistake|mistook|mistaken|오해하다, 착각하다
    misunderstand|misunderstood|misunderstood|오해하다
    mow|mowed|mown/mowed|(풀을) 베다
    outgrow|outgrew|outgrown|너무 커져 못 쓰게 되다
    overcome|overcame|overcome|극복하다
    overhear|overheard|overheard|우연히 듣다
    oversleep|overslept|overslept|늦잠 자다
    overtake|overtook|overtaken|추월하다
    overthrow|overthrew|overthrown|전복시키다
    pay|paid|paid|지불하다
    prove|proved|proved/proven|증명하다
    put|put|put|놓다, 두다
    quit|quit|quit|그만두다
    read|read|read|읽다
    rebuild|rebuilt|rebuilt|다시 짓다
    rid|rid|rid|없애다
    ride|rode|ridden|타다
    ring|rang|rung|울리다
    rise|rose|risen|오르다, 뜨다
    run|ran|run|달리다, 운영하다
    say|said|said|말하다
    see|saw|seen|보다
    seek|sought|sought|찾다, 구하다
    sell|sold|sold|팔다
    send|sent|sent|보내다
    set|set|set|놓다, 정하다
    sew|sewed|sewn/sewed|바느질하다
    shake|shook|shaken|흔들다
    shed|shed|shed|흘리다
    shine|shone|shone|빛나다
    shoot|shot|shot|쏘다
    show|showed|shown/showed|보여 주다
    shrink|shrank|shrunk|줄어들다
    shut|shut|shut|닫다
    sing|sang|sung|노래하다
    sink|sank|sunk|가라앉다
    sit|sat|sat|앉다
    sleep|slept|slept|자다
    slide|slid|slid|미끄러지다
    slit|slit|slit|가르다
    smell|smelled/smelt|smelled/smelt|냄새 맡다, 냄새가 나다
    sow|sowed|sown/sowed|씨를 뿌리다
    speak|spoke|spoken|말하다
    speed|sped/speeded|sped/speeded|속도를 내다
    spell|spelled/spelt|spelled/spelt|철자를 말하다
    spend|spent|spent|쓰다 (돈·시간)
    spill|spilled/spilt|spilled/spilt|엎지르다
    spin|spun|spun|돌다, 돌리다
    spit|spat/spit|spat/spit|침을 뱉다
    split|split|split|나누다, 쪼개다
    spoil|spoiled/spoilt|spoiled/spoilt|망치다
    spread|spread|spread|펼치다, 퍼지다
    spring|sprang|sprung|튀어 오르다
    stand|stood|stood|서다, 참다
    steal|stole|stolen|훔치다
    stick|stuck|stuck|붙이다, 찌르다
    sting|stung|stung|쏘다 (벌 등)
    stink|stank|stunk|악취가 나다
    stride|strode|stridden|성큼성큼 걷다
    strike|struck|struck|치다, 파업하다
    string|strung|strung|줄에 꿰다
    strive|strove|striven|노력하다
    swear|swore|sworn|맹세하다
    sweep|swept|swept|쓸다
    swim|swam|swum|수영하다
    swing|swung|swung|흔들다
    take|took|taken|가져가다, 잡다
    teach|taught|taught|가르치다
    tear|tore|torn|찢다
    tell|told|told|말하다
    think|thought|thought|생각하다
    throw|threw|thrown|던지다
    thrust|thrust|thrust|밀다, 찌르다
    tread|trod|trodden|밟다
    understand|understood|understood|이해하다
    undergo|underwent|undergone|겪다
    undertake|undertook|undertaken|맡다, 착수하다
    upset|upset|upset|속상하게 하다
    wake|woke|woken|깨다, 깨우다
    wear|wore|worn|입다, 닳다
    weave|wove|woven|짜다, 엮다
    weep|wept|wept|울다
    wet|wet/wetted|wet/wetted|적시다
    win|won|won|이기다, 얻다
    wind|wound|wound|감다
    withdraw|withdrew|withdrawn|물러나다, 인출하다
    withstand|withstood|withstood|견디다
    wring|wrung|wrung|짜다, 비틀다
    write|wrote|written|쓰다
    """

    /// 자주 쓰는 규칙 동사 (원형|뜻)
    private static let regularRaw = """
    accept|받아들이다
    achieve|성취하다
    add|더하다
    admit|인정하다
    agree|동의하다
    allow|허락하다
    answer|대답하다
    appear|나타나다
    apply|지원하다, 적용하다
    arrive|도착하다
    ask|묻다, 부탁하다
    avoid|피하다
    believe|믿다
    borrow|빌리다
    call|부르다, 전화하다
    carry|나르다
    change|바꾸다
    check|확인하다
    clean|청소하다
    climb|오르다
    close|닫다
    collect|모으다
    commit|저지르다
    compare|비교하다
    complain|불평하다
    consider|고려하다
    continue|계속하다
    control|통제하다
    cook|요리하다
    copy|베끼다
    count|세다
    cover|덮다
    create|만들다
    cry|울다
    dance|춤추다
    decide|결정하다
    delay|미루다
    deliver|배달하다
    deny|부인하다
    depend|의존하다
    describe|묘사하다
    destroy|파괴하다
    develop|발전시키다
    die|죽다
    disagree|동의하지 않다
    discover|발견하다
    discuss|토론하다
    drop|떨어뜨리다
    employ|고용하다
    end|끝나다
    enjoy|즐기다
    enter|들어가다
    exercise|운동하다
    explain|설명하다
    fail|실패하다
    fill|채우다
    finish|끝내다
    fix|고치다
    follow|따라가다
    guess|추측하다
    happen|일어나다
    hate|싫어하다
    help|돕다
    hope|바라다
    hug|껴안다
    hurry|서두르다
    imagine|상상하다
    improve|향상시키다
    invite|초대하다
    join|가입하다, 함께하다
    jump|뛰다
    kick|차다
    kill|죽이다
    kiss|입 맞추다
    knock|두드리다
    laugh|웃다
    like|좋아하다
    listen|듣다
    live|살다
    look|보다
    love|사랑하다
    marry|결혼하다
    miss|그리워하다, 놓치다
    mix|섞다
    move|움직이다, 이사하다
    need|필요하다
    obey|따르다
    occur|일어나다
    offer|제공하다
    omit|생략하다
    open|열다
    order|주문하다, 명령하다
    paint|칠하다, 그리다
    pass|지나가다, 합격하다
    permit|허락하다
    pick|고르다, 줍다
    plan|계획하다
    play|놀다, 경기하다, 연주하다
    practice|연습하다
    pray|기도하다
    prefer|선호하다
    prepare|준비하다
    prevent|막다
    produce|생산하다
    protect|보호하다
    provide|제공하다
    pull|당기다
    push|밀다
    rain|비가 오다
    reach|도달하다
    realize|깨닫다
    receive|받다
    recommend|추천하다
    reduce|줄이다
    refer|언급하다
    regret|후회하다
    relax|쉬다
    remember|기억하다
    remove|제거하다
    repair|수리하다
    replace|대체하다
    reply|답장하다
    rest|쉬다
    return|돌아오다
    save|구하다, 저장하다
    seem|~처럼 보이다
    share|나누다
    shop|쇼핑하다
    shout|외치다
    smile|미소 짓다
    snow|눈이 오다
    solve|풀다, 해결하다
    start|시작하다
    stay|머무르다
    stop|멈추다
    study|공부하다
    submit|제출하다
    suggest|제안하다
    talk|이야기하다
    taste|맛보다
    test|시험하다
    thank|감사하다
    touch|만지다
    travel|여행하다
    try|노력하다, 시도하다
    turn|돌다, 돌리다
    use|사용하다
    visit|방문하다
    wait|기다리다
    walk|걷다
    want|원하다
    wash|씻다
    watch|보다, 지켜보다
    wish|바라다
    wonder|궁금해하다
    work|일하다, 작동하다
    worry|걱정하다
    """

    static let irregular: [String: Irregular] = {
        var map: [String: Irregular] = [:]
        for line in irregularRaw.split(separator: "\n") {
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 4 else { continue }
            map[parts[0]] = Irregular(base: parts[0], past: parts[1].components(separatedBy: "/"),
                                      pp: parts[2].components(separatedBy: "/"), meaning: parts[3])
        }
        return map
    }()

    static let regular: [String: String] = {
        var map: [String: String] = [:]
        for line in regularRaw.split(separator: "\n") {
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { map[parts[0]] = parts[1] }
        }
        return map
    }()

    static let modals: Set<String> = ["can", "could", "will", "would", "shall", "should", "may", "might", "must", "ought"]

    /// 두 음절 이상이지만 끝 음절에 강세가 있어 자음을 겹치는 동사
    private static let doublingVerbs: Set<String> = [
        "admit", "begin", "commit", "control", "forget", "occur", "omit", "permit", "prefer", "refer", "regret",
        "submit", "transfer", "upset", "equip", "patrol", "compel", "expel", "propel", "rebel", "excel", "forbid"
    ]

    static let pastToBase: [String: String] = {
        var map: [String: String] = [:]
        for verb in irregular.values {
            for form in verb.past where form != verb.base && map[form] == nil { map[form] = verb.base }
        }
        return map
    }()

    static let ppToBase: [String: String] = {
        var map: [String: String] = [:]
        for verb in irregular.values {
            for form in verb.pp where form != verb.base && map[form] == nil { map[form] = verb.base }
        }
        return map
    }()

    /// 불규칙 동사를 규칙처럼 바꾼 흔한 실수 (goed, buyed, runned …) → 원형
    static let wrongForms: [String: String] = {
        let realWords: Set<String> = ["seed", "singed", "lied", "hanged", "winded", "leaded", "spitted", "betted", "quitted",
                                      "waked", "shined", "speeded", "fitted", "lighted", "wetted", "knitted", "bidded", "bored",
                                      "laid", "felled", "founded", "wounded", "grounded", "beed", "doed", "weaved", "strived",
                                      "broadcasted", "forecasted", "bended"]
        var map: [String: String] = ["brang": "bring", "brung": "bring", "thunk": "think"]
        for verb in irregular.values where verb.base != "be" && verb.base != "do" {
            let base = verb.base
            var candidates = [base + "ed"]
            if base.hasSuffix("e") { candidates.append(base + "d") }
            if base.hasSuffix("y"), let last = base.dropLast().last, !EngText.isVowel(last) {
                candidates.append(String(base.dropLast()) + "ied")
            }
            if shouldDouble(base), let last = base.last { candidates.append(base + String(last) + "ed") }
            for candidate in candidates
            where !verb.past.contains(candidate) && !verb.pp.contains(candidate) && !realWords.contains(candidate)
                && pastToBase[candidate] == nil && ppToBase[candidate] == nil && irregular[candidate] == nil {
                map[candidate] = base
            }
        }
        return map
    }()

    static func isBaseVerb(_ word: String) -> Bool { irregular[word] != nil || regular[word] != nil }

    static func meaning(of word: String) -> String? { irregular[word]?.meaning ?? regular[word] }

    static func shouldDouble(_ word: String) -> Bool {
        if doublingVerbs.contains(word) { return true }
        return EngText.syllables(word) == 1 && EngText.endsCVC(word)
    }

    static func pastForms(_ base: String) -> [String] { irregular[base]?.past ?? [regularPast(base)] }
    static func ppForms(_ base: String) -> [String] { irregular[base]?.pp ?? [regularPast(base)] }
    static func past(_ base: String) -> String { pastForms(base)[0] }
    static func pp(_ base: String) -> String { ppForms(base)[0] }

    static func regularPast(_ base: String) -> String {
        if base.hasSuffix("e") { return base + "d" }
        if base.hasSuffix("c") { return base + "ked" }
        if base.hasSuffix("y"), let last = base.dropLast().last, !EngText.isVowel(last) { return String(base.dropLast()) + "ied" }
        if shouldDouble(base), let last = base.last { return base + String(last) + "ed" }
        return base + "ed"
    }

    static func ing(_ base: String) -> String {
        switch base {
        case "be": return "being"
        case "see", "flee", "agree", "free", "disagree", "guarantee": return base + "ing"
        default: break
        }
        if base.hasSuffix("ie") { return String(base.dropLast(2)) + "ying" }
        if base.hasSuffix("ee") || base.hasSuffix("ye") || base.hasSuffix("oe") { return base + "ing" }
        if base.hasSuffix("e") { return String(base.dropLast()) + "ing" }
        if base.hasSuffix("c") { return base + "king" }
        if shouldDouble(base), let last = base.last { return base + String(last) + "ing" }
        return base + "ing"
    }

    static func third(_ base: String) -> String {
        switch base {
        case "be": return "is"
        case "have": return "has"
        case "do": return "does"
        case "go": return "goes"
        default: break
        }
        if base.hasSuffix("y"), let last = base.dropLast().last, !EngText.isVowel(last) { return String(base.dropLast()) + "ies" }
        for suffix in ["s", "x", "z", "ch", "sh", "o"] where base.hasSuffix(suffix) { return base + "es" }
        return base + "s"
    }

    static func baseFromThird(_ word: String) -> String? {
        switch word {
        case "has": return "have"
        case "does": return "do"
        case "is": return nil
        default: break
        }
        var candidates: [String] = []
        if word.hasSuffix("ies") { candidates.append(String(word.dropLast(3)) + "y") }
        if word.hasSuffix("es") { candidates.append(String(word.dropLast(2))) }
        if word.hasSuffix("s") { candidates.append(String(word.dropLast())) }
        return candidates.first { isBaseVerb($0) && third($0) == word }
    }

    static func baseFromIng(_ word: String) -> String? {
        guard word.hasSuffix("ing"), word.count > 4 else { return nil }
        let stem = String(word.dropLast(3))
        var candidates = [stem, stem + "e"]
        if stem.hasSuffix("y") { candidates.append(String(stem.dropLast()) + "ie") }
        if let last = stem.last, stem.dropLast().last == last { candidates.append(String(stem.dropLast())) }
        if stem.hasSuffix("k") { candidates.append(String(stem.dropLast())) }
        return candidates.first { isBaseVerb($0) && ing($0) == word }
    }

    static func regularBase(fromPast word: String) -> String? {
        guard word.hasSuffix("ed"), word.count > 3 else { return nil }
        var candidates: [String] = []
        if word.hasSuffix("ied") { candidates.append(String(word.dropLast(3)) + "y") }
        candidates.append(String(word.dropLast(1)))
        candidates.append(String(word.dropLast(2)))
        let stem = String(word.dropLast(2))
        if let last = stem.last, stem.dropLast().last == last { candidates.append(String(stem.dropLast())) }
        return candidates.first { regular[$0] != nil && regularPast($0) == word }
    }

    /// 동사의 변화형이면 (원형, 어떤 형태). 원형 자체이면 nil
    static func analyze(_ word: String) -> (String, FormKind)? {
        if isBaseVerb(word) { return nil }
        if let base = pastToBase[word] { return (base, ppForms(base).contains(word) ? .pastAndPP : .past) }
        if let base = ppToBase[word] { return (base, .pp) }
        if let base = regularBase(fromPast: word) { return (base, .pastAndPP) }
        if let base = baseFromThird(word) { return (base, .third) }
        if let base = baseFromIng(word) { return (base, .ing) }
        return nil
    }

    /// 과거형으로만 쓰는 형태 (went, ate…) → 원형
    static func pastOnlyBase(_ word: String) -> String? {
        guard let base = pastToBase[word], !ppForms(base).contains(word) else { return nil }
        return base
    }

    /// 과거분사로만 쓰는 형태 (gone, seen, eaten…) → 원형
    static func ppOnlyBase(_ word: String) -> String? {
        guard let base = ppToBase[word], !pastForms(base).contains(word), !["been", "gotten", "born", "borne"].contains(word) else { return nil }
        return base
    }

    /// 규칙 변화 설명
    static func pastRule(_ base: String) -> String {
        if base.hasSuffix("e") { return "e로 끝나서 -d만 붙여요." }
        if base.hasSuffix("y"), let last = base.dropLast().last, !EngText.isVowel(last) { return "자음 + y로 끝나서 y를 i로 바꾸고 -ed를 붙여요." }
        if shouldDouble(base) { return "단모음 + 단자음으로 끝나서 마지막 자음을 한 번 더 쓰고 -ed를 붙여요." }
        return "규칙 동사라 -ed를 붙여요."
    }

    static func ingRule(_ base: String) -> String {
        if base.hasSuffix("ie") { return "ie로 끝나서 ie를 y로 바꾸고 -ing를 붙여요." }
        if base.hasSuffix("e") && ing(base) == String(base.dropLast()) + "ing" { return "e로 끝나서 e를 빼고 -ing를 붙여요." }
        if shouldDouble(base) { return "단모음 + 단자음으로 끝나서 마지막 자음을 한 번 더 쓰고 -ing를 붙여요." }
        return "-ing를 붙여요."
    }

    static func thirdRule(_ base: String) -> String {
        if ["be", "have"].contains(base) { return "불규칙하게 바뀌어요." }
        if base.hasSuffix("y"), let last = base.dropLast().last, !EngText.isVowel(last) { return "자음 + y로 끝나서 y를 i로 바꾸고 -es를 붙여요." }
        if third(base).hasSuffix("es") { return "s, x, z, ch, sh, o로 끝나서 -es를 붙여요." }
        return "-s를 붙여요."
    }
}

// MARK: - 명사 복수형 · 형용사 비교급

private enum EngNouns {
    static let irregularPlural: [String: String] = [
        "child": "children", "man": "men", "woman": "women", "person": "people", "mouse": "mice", "goose": "geese",
        "tooth": "teeth", "foot": "feet", "ox": "oxen", "louse": "lice", "sheep": "sheep", "deer": "deer", "fish": "fish",
        "species": "species", "series": "series", "aircraft": "aircraft", "cactus": "cacti", "fungus": "fungi",
        "nucleus": "nuclei", "stimulus": "stimuli", "radius": "radii", "alumnus": "alumni", "syllabus": "syllabi",
        "analysis": "analyses", "basis": "bases", "crisis": "crises", "thesis": "theses", "hypothesis": "hypotheses",
        "diagnosis": "diagnoses", "oasis": "oases", "phenomenon": "phenomena", "criterion": "criteria", "datum": "data",
        "medium": "media", "bacterium": "bacteria", "curriculum": "curricula", "appendix": "appendices", "matrix": "matrices",
        "vertex": "vertices", "index": "indices", "leaf": "leaves", "knife": "knives", "wife": "wives", "life": "lives",
        "wolf": "wolves", "half": "halves", "shelf": "shelves", "thief": "thieves", "loaf": "loaves", "calf": "calves",
        "self": "selves", "elf": "elves", "scarf": "scarves", "potato": "potatoes", "tomato": "tomatoes", "hero": "heroes",
        "echo": "echoes", "mosquito": "mosquitoes", "quiz": "quizzes", "roof": "roofs", "belief": "beliefs", "chief": "chiefs",
        "cliff": "cliffs", "safe": "safes", "piano": "pianos", "photo": "photos", "radio": "radios", "zoo": "zoos",
        "video": "videos", "kilo": "kilos", "memo": "memos"
    ]

    static let uncountable: Set<String> = [
        "information", "advice", "furniture", "homework", "news", "luggage", "baggage", "equipment", "knowledge", "money",
        "water", "bread", "music", "research", "evidence", "traffic", "weather", "progress", "rice", "sugar", "milk", "air",
        "scenery", "machinery", "jewelry", "poetry", "mail", "garbage", "trash", "fun", "happiness", "health"
    ]

    static var pluralToSingular: [String: String] {
        Dictionary(irregularPlural.map { ($0.value, $0.key) }, uniquingKeysWith: { first, _ in first })
    }

    static func plural(_ noun: String) -> (form: String, rule: String) {
        if let irregular = irregularPlural[noun] {
            if irregular == noun + "s" { return (irregular, "f나 o로 끝나지만 예외적으로 -s만 붙여요.") }
            if irregular == noun + "es" { return (irregular, "자음 + o로 끝나서 -es를 붙여요.") }
            if irregular == noun + "zes" { return (irregular, "z를 한 번 더 쓰고 -es를 붙여요.") }
            return (irregular, irregular == noun ? "단수와 복수 모양이 같아요." : "불규칙하게 바뀌어요.")
        }
        for suffix in ["s", "x", "z", "ch", "sh"] where noun.hasSuffix(suffix) {
            return (noun + "es", "s, x, z, ch, sh로 끝나서 -es를 붙여요.")
        }
        if noun.hasSuffix("y"), let last = noun.dropLast().last, !EngText.isVowel(last) {
            return (String(noun.dropLast()) + "ies", "자음 + y로 끝나서 y를 i로 바꾸고 -es를 붙여요.")
        }
        if noun.hasSuffix("fe") { return (String(noun.dropLast(2)) + "ves", "fe로 끝나서 ves로 바꿔요. (예외: safe → safes)") }
        if noun.hasSuffix("f") { return (String(noun.dropLast()) + "ves", "f로 끝나서 ves로 바꿔요. (예외: roof, belief, chief → -s)") }
        return (noun + "s", "-s를 붙여요.")
    }
}

private enum EngAdjectives {
    static let irregular: [String: (String, String)] = [
        "good": ("better", "best"), "well": ("better", "best"), "bad": ("worse", "worst"), "ill": ("worse", "worst"),
        "many": ("more", "most"), "much": ("more", "most"), "little": ("less", "least"),
        "far": ("farther / further", "farthest / furthest"), "old": ("older / elder", "oldest / eldest"),
        "late": ("later / latter", "latest / last")
    ]

    static let common: [String] = [
        "big", "small", "tall", "short", "long", "fast", "slow", "old", "young", "new", "hot", "cold", "warm", "cool", "high", "low",
        "strong", "weak", "hard", "easy", "happy", "busy", "early", "late", "heavy", "light", "dark", "bright", "cheap", "rich",
        "poor", "smart", "nice", "large", "great", "thin", "fat", "wide", "deep", "safe", "close", "near", "clean", "quick", "sad",
        "funny", "pretty", "ugly", "lucky", "angry", "healthy", "friendly", "simple", "quiet", "kind", "loud", "wise", "brave",
        "calm", "fresh", "sweet", "sharp", "soft", "rough", "tough", "tiny", "lazy", "dirty", "noisy", "crazy", "scary", "thick",
        "strict", "fine", "pure", "rude", "wet", "dry", "hungry", "thirsty", "cute", "bad", "good", "far", "many", "much", "little"
    ]

    private static let twoSyllableEr: Set<String> = ["simple", "quiet", "narrow", "clever", "gentle", "shallow", "humble", "noble"]
    private static let alwaysMore: Set<String> = ["real", "right", "wrong", "fun", "tired", "bored", "pleased", "worn", "just"]

    static func compare(_ adjective: String) -> (comparative: String, superlative: String, rule: String) {
        let a = adjective
        if let pair = irregular[a] { return (pair.0, pair.1, "불규칙하게 바뀌어요.") }
        let syllables = EngText.syllables(a)
        let moreRule = (comparative: "more " + a, superlative: "most " + a, rule: "2음절 이상(또는 -ful, -ous, -ive, -ing, -ed 등)이라 앞에 more / most를 써요.")
        if alwaysMore.contains(a) || a.hasSuffix("ed") || a.hasSuffix("ing") || a.hasSuffix("ful") || a.hasSuffix("ous")
            || a.hasSuffix("ive") || a.hasSuffix("less") || (a.hasSuffix("ly") && a != "early" && a != "friendly" && a != "lovely") {
            return moreRule
        }
        let endsConsonantY = a.hasSuffix("y") && a.dropLast().last.map { !EngText.isVowel($0) } == true
        if syllables == 1 || endsConsonantY && syllables == 2 || twoSyllableEr.contains(a) || a == "friendly" || a == "lovely" {
            if endsConsonantY {
                let stem = String(a.dropLast())
                return (stem + "ier", stem + "iest", "자음 + y로 끝나서 y를 i로 바꾸고 -er / -est를 붙여요.")
            }
            if a.hasSuffix("e") { return (a + "r", a + "st", "e로 끝나서 -r / -st만 붙여요.") }
            if syllables == 1, EngText.endsCVC(a), let last = a.last {
                return (a + String(last) + "er", a + String(last) + "est", "단모음 + 단자음으로 끝나서 마지막 자음을 겹치고 -er / -est를 붙여요.")
            }
            return (a + "er", a + "est", "짧은 단어라 -er / -est를 붙여요.")
        }
        return moreRule
    }

    /// bigger → big, best → good (비교급·최상급 모양의 흔한 형용사)
    static let fromComparative: [String: String] = {
        var map: [String: String] = ["better": "good", "worse": "bad", "best": "good", "worst": "bad"]
        for adjective in common where irregular[adjective] == nil {
            let forms = compare(adjective)
            if !forms.comparative.hasPrefix("more") { map[forms.comparative] = adjective; map[forms.superlative] = adjective }
        }
        return map
    }()
}

// MARK: - 형태 변화 질문

private enum EngForms {
    enum Kind { case all, past, pp, ing, third, plural, comparative, base }

    private static let formKeywords = ["3단변화", "삼단변화", "3단계변화", "과거분사", "과거형", "과거", "현재분사", "3인칭단수", "3인칭",
                                       "삼인칭", "단수형", "단수", "복수형", "복수", "비교급", "최상급", "ing형", "진행형", "변화형",
                                       "변화", "활용", "변형", "원형", "형태", "pp형", "p.p", "pp", "ing"]

    private static let functionWords: Set<String> = [
        "as", "than", "the", "a", "an", "to", "of", "if", "wish", "it", "what", "that", "which", "who", "whom", "whose", "when",
        "where", "why", "how", "so", "too", "enough", "there", "here", "more", "most", "much", "very", "and", "or", "but", "not",
        "no", "with", "for", "by", "in", "on", "at", "from", "ever", "every", "some", "any", "this", "these", "those", "will",
        "would", "can", "could", "may", "might", "must", "should", "shall", "i", "you", "he", "she", "we", "they"
    ]

    static func kind(compact: String, lower: String) -> Kind? {
        if EngText.has(compact, ["3단변화", "삼단변화", "3단계변화"]) { return .all }
        if EngText.has(compact, ["3인칭", "삼인칭", "3단현", "단수현재"]) { return .third }
        if EngText.has(compact, ["과거분사", "p.p", "pp형"]) || EngText.englishWords(in: lower).contains("pp") { return .pp }
        if compact.contains("과거") { return .past }
        if EngText.has(compact, ["현재분사", "진행형", "ing형"]) || EngText.englishWords(in: lower).contains("ing") { return .ing }
        if compact.contains("복수") { return .plural }
        if EngText.has(compact, ["비교급", "최상급"]) { return .comparative }
        if compact.contains("원형") { return .base }
        if EngText.has(compact, ["변화", "활용", "변형", "형태"]) { return .all }
        return nil
    }

    static func answer(_ text: String, lower: String, compact: String, hasHangul: Bool) -> String? {
        if !hasHangul { return englishQuestion(lower) }
        guard let kind = kind(compact: compact, lower: lower) else { return nil }
        if EngText.has(compact, ["havep.p", "havepp", "hadp.p", "hadpp", "bep.p", "bepp", "조동사"]) { return nil }
        guard let word = EngText.englishWords(in: text).first(where: {
            !EngText.lookupStopWords.contains($0) && !functionWords.contains($0) && $0 != "pp" && $0 != "ing"
        }) else { return nil }

        // 남은 말이 문법 주제를 가리키면 문법 설명에 맡김 ("I wish 가정법 과거")
        var rest = compact.replacingOccurrences(of: word, with: "")
        for keyword in formKeywords { rest = rest.replacingOccurrences(of: keyword, with: "") }
        if EngGrammar.topic(for: rest) != nil { return nil }

        return card(word, kind: kind)
    }

    /// "past tense of go", "plural of child"
    private static func englishQuestion(_ lower: String) -> String? {
        let patterns: [(String, Kind)] = [
            (#"past participle of ([a-z]+)"#, .pp), (#"([a-z]+) past participle"#, .pp),
            (#"past (?:tense |form )?of ([a-z]+)"#, .past), (#"([a-z]+) past tense"#, .past),
            (#"plural (?:form )?of ([a-z]+)"#, .plural), (#"comparative (?:form )?of ([a-z]+)"#, .comparative),
            (#"superlative (?:form )?of ([a-z]+)"#, .comparative), (#"-?ing form of ([a-z]+)"#, .ing)
        ]
        for (pattern, kind) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
                  let range = Range(match.range(at: 1), in: lower) else { continue }
            return card(String(lower[range]), kind: kind)
        }
        return nil
    }

    static func card(_ word: String, kind: Kind) -> String? {
        switch kind {
        case .plural: return pluralCard(word)
        case .comparative: return comparativeCard(word)
        case .base:
            if let (base, form) = EngVerbs.analyze(word) {
                let name: String
                switch form {
                case .past: name = "과거형"
                case .pp: name = "과거분사"
                case .pastAndPP: name = "과거형·과거분사"
                case .third: name = "3인칭 단수 현재형"
                case .ing: name = "-ing형"
                }
                return "\(word)의 원형: **\(base)**\n(\(word): \(base)의 \(name))\n\n" + verbCard(base, asked: nil)
            }
            if let singular = EngNouns.pluralToSingular[word] { return "\(word)의 단수형: **\(singular)**" }
            if let adjective = EngAdjectives.fromComparative[word] { return "\(word)의 원급: **\(adjective)**" }
            return EngVerbs.isBaseVerb(word) ? "\(word): 이미 원형이에요.\n\n" + verbCard(word, asked: nil) : nil
        case .all:
            if let (base, _) = EngVerbs.analyze(word) { return verbCard(base, asked: nil) }
            if EngVerbs.isBaseVerb(word) { return verbCard(word, asked: nil) }
            if EngAdjectives.common.contains(word) { return comparativeCard(word) }
            if EngNouns.irregularPlural[word] != nil { return pluralCard(word) }
            return verbCard(word, asked: nil)
        default:
            let base = EngVerbs.isBaseVerb(word) ? word : (EngVerbs.analyze(word)?.0 ?? word)
            return verbCard(base, asked: kind)
        }
    }

    static func verbCard(_ base: String, asked: Kind?) -> String {
        let known = EngVerbs.isBaseVerb(base)
        let irregular = EngVerbs.irregular[base]
        let past = EngVerbs.pastForms(base).joined(separator: " / ")
        let pp = EngVerbs.ppForms(base).joined(separator: " / ")
        let ing = EngVerbs.ing(base)
        let third = EngVerbs.third(base)
        var lines: [String] = []

        switch asked {
        case .past?:
            lines.append("\(base)의 과거형: **\(past)**")
            if irregular == nil { lines.append(EngVerbs.pastRule(base)) }
        case .pp?:
            lines.append("\(base)의 과거분사: **\(pp)**")
            if irregular == nil { lines.append("규칙 동사는 과거분사도 과거형과 같아요. " + EngVerbs.pastRule(base)) }
        case .ing?:
            lines.append("\(base)의 -ing형(현재분사·동명사): **\(ing)**")
            lines.append(EngVerbs.ingRule(base))
        case .third?:
            lines.append("\(base)의 3인칭 단수 현재형: **\(third)**")
            lines.append(EngVerbs.thirdRule(base))
        default:
            break
        }
        if !lines.isEmpty { lines.append("") }

        let meaning = EngVerbs.meaning(of: base) ?? EngWords.dictionary[base]
        lines.append("**\(base)**" + (meaning.map { ": \($0)" } ?? ""))
        lines.append("\(base) - \(past) - \(pp) (\(irregular != nil ? "불규칙 동사" : "규칙 동사"))")
        lines.append("• 과거형: \(past)")
        lines.append("• 과거분사: \(pp)")
        lines.append("• 현재분사(-ing): \(ing)")
        lines.append("• 3인칭 단수 현재: \(third)")
        if base == "be" { lines.append("• 현재형: am / are / is") }
        if let note = notes[base] { lines.append("참고: \(note)") }
        if !known { lines.append("※ 내장 목록에 없는 단어라 규칙대로 만들었어요. 불규칙 동사라면 다를 수 있어요.") }
        return lines.joined(separator: "\n")
    }

    private static let notes: [String: String] = [
        "read": "과거·과거분사 read는 [red]로 발음해요.",
        "lie": "'거짓말하다'의 lie는 lie - lied - lied (규칙), '놓다'의 lay는 lay - laid - laid예요.",
        "lay": "'눕다'의 lie(lie - lay - lain)와 헷갈리지 않게 주의해요.",
        "hang": "'교수형에 처하다'라는 뜻일 때는 hang - hanged - hanged예요.",
        "find": "'설립하다'의 found는 found - founded - founded로 다른 동사예요.",
        "fall": "'(나무를) 베다'의 fell은 fell - felled - felled로 다른 동사예요.",
        "see": "'톱질하다'의 saw는 saw - sawed - sawn으로 다른 동사예요.",
        "rise": "rise(오르다, 자동사)와 raise(올리다, 타동사, 규칙)를 구분해요.",
        "get": "과거분사는 영국은 got, 미국은 gotten을 주로 써요.",
        "bear": "'태어나다'는 수동태 be born을 써요.",
        "wind": "'감다'의 wind[와인드]와 명사 wind[윈드](바람)는 다른 단어예요."
    ]

    static func pluralCard(_ noun: String) -> String {
        if EngNouns.uncountable.contains(noun) {
            return "**\(noun)**: 셀 수 없는 명사라서 복수형이 없어요.\na / an이나 -s를 붙이지 않고, 셀 때는 a piece of \(noun)처럼 단위를 써요."
        }
        let result = EngNouns.plural(noun)
        return "\(noun)의 복수형: **\(result.form)**\n\(result.rule)"
    }

    static func comparativeCard(_ adjective: String) -> String {
        let forms = EngAdjectives.compare(adjective)
        var text = "**\(adjective)**\n• 비교급: \(forms.comparative)\n• 최상급: \(forms.superlative)\n\(forms.rule)"
        if adjective == "far" { text += "\n참고: farther는 거리, further는 정도(더 나아가)에 주로 써요." }
        if adjective == "old" { text += "\n참고: elder / eldest는 형제·자매 관계에서 명사 앞에만 써요. (my elder brother)" }
        if adjective == "late" { text += "\n참고: later / latest는 시간, latter / last는 순서예요." }
        return text
    }
}

// MARK: - 내장 단어장 (고등 필수 어휘)

private enum EngWords {
    private static let raw = """
    abandon|버리다, 포기하다
    ability|능력
    abroad|해외로, 해외에
    absence|결석, 부재
    absolute|절대적인
    absorb|흡수하다
    abstract|추상적인
    abundant|풍부한
    academic|학업의, 학문의
    access|접근, 이용
    accident|사고, 우연
    accompany|동행하다
    accomplish|성취하다
    accurate|정확한
    acquire|얻다, 습득하다
    adapt|적응하다, 각색하다
    adequate|충분한, 적절한
    admire|존경하다, 감탄하다
    adopt|채택하다, 입양하다
    advantage|이점, 장점
    advertise|광고하다
    affect|영향을 미치다
    afford|~할 여유가 있다
    aggressive|공격적인
    agriculture|농업
    aim|목표; 겨누다
    alter|바꾸다
    alternative|대안; 대안의
    amazing|놀라운
    ambition|야망
    amount|양, 총액
    analyze|분석하다
    ancestor|조상
    ancient|고대의
    anniversary|기념일
    announce|발표하다
    annual|매년의, 연간의
    anxious|불안한, 열망하는
    apparent|명백한, 겉보기의
    appeal|호소하다; 매력
    appetite|식욕
    appliance|가전제품
    appointment|약속, 임명
    appreciate|감사하다, 감상하다, 진가를 알다
    approach|접근하다; 접근법
    appropriate|적절한
    approve|승인하다
    argue|논쟁하다, 주장하다
    arrange|정리하다, 준비하다
    artificial|인공의
    aspect|측면
    assignment|과제
    assist|돕다
    assume|가정하다, 추정하다
    atmosphere|대기, 분위기
    attach|붙이다
    attempt|시도하다; 시도
    attend|참석하다
    attitude|태도
    attract|끌다, 매혹하다
    audience|청중, 관객
    authority|권위, 당국
    available|이용 가능한
    average|평균; 평균의
    aware|알고 있는
    awkward|어색한
    balance|균형
    barrier|장벽
    behavior|행동
    belief|믿음
    benefit|이익, 혜택
    bias|편견
    biology|생물학
    blame|비난하다, 탓하다
    boundary|경계
    brilliant|뛰어난, 빛나는
    budget|예산
    burden|부담, 짐
    capable|~할 수 있는, 유능한
    capacity|용량, 능력
    career|직업, 경력
    careless|부주의한
    cause|원인; 일으키다
    celebrate|기념하다, 축하하다
    challenge|도전; 도전하다
    character|성격, 등장인물
    charge|요금, 책임; 청구하다
    chemical|화학의; 화학 물질
    circumstance|상황, 환경
    citizen|시민
    claim|주장하다; 주장
    classify|분류하다
    climate|기후
    colleague|동료
    combine|결합하다
    comfortable|편안한
    command|명령하다; 명령
    comment|논평, 의견
    commercial|상업의; 광고
    communicate|의사소통하다
    community|공동체, 지역 사회
    compete|경쟁하다
    complete|완전한; 완성하다
    complex|복잡한
    concentrate|집중하다
    concept|개념
    concern|걱정; 관련되다
    conclusion|결론
    condition|상태, 조건
    conduct|수행하다; 행동
    conference|회의
    confident|자신 있는
    conflict|갈등
    confuse|혼란시키다
    connect|연결하다
    conscious|의식하는
    consequence|결과
    conserve|보존하다, 아끼다
    consist|구성되다 (consist of)
    constant|끊임없는, 일정한
    construct|건설하다
    consume|소비하다
    contain|포함하다
    contemporary|현대의, 동시대의
    content|내용; 만족하는
    context|맥락, 문맥
    contrast|대조; 대조하다
    contribute|기여하다, 기부하다
    convenient|편리한
    convince|설득하다, 확신시키다
    cooperate|협력하다
    correct|옳은; 바로잡다
    creative|창의적인
    crisis|위기
    critical|비판적인, 중요한
    crucial|결정적인, 매우 중요한
    culture|문화
    curious|호기심 많은
    current|현재의; 흐름
    custom|관습
    damage|손상; 손상시키다
    decade|10년
    decline|감소하다, 거절하다
    decrease|감소하다
    dedicate|바치다, 헌신하다
    define|정의하다
    demand|요구; 요구하다
    demonstrate|증명하다, 시위하다
    depressed|우울한
    deserve|~을 받을 만하다
    desire|욕구; 바라다
    despite|~에도 불구하고
    detail|세부 사항
    determine|결정하다, 알아내다
    device|장치
    devote|바치다, 헌신하다
    diet|식단, 식습관
    differ|다르다
    difficulty|어려움
    digest|소화하다
    diligent|부지런한
    disappoint|실망시키다
    disaster|재난
    disease|질병
    display|전시하다; 전시
    distance|거리
    distinguish|구별하다
    distribute|분배하다
    diverse|다양한
    divide|나누다
    domestic|국내의, 가정의
    dominate|지배하다
    donate|기부하다
    doubt|의심; 의심하다
    dramatic|극적인
    duty|의무
    eager|열망하는
    economy|경제
    edge|가장자리
    educate|교육하다
    effect|효과, 결과
    efficient|효율적인
    effort|노력
    element|요소
    eliminate|제거하다
    embarrass|당황하게 하다
    emergency|비상 (사태)
    emotion|감정
    emphasize|강조하다
    encourage|격려하다
    enemy|적
    energy|에너지, 활력
    enormous|거대한
    ensure|보장하다
    environment|환경
    equal|같은, 평등한
    equipment|장비
    escape|탈출하다
    essential|필수적인
    establish|설립하다, 확립하다
    estimate|추정하다; 추정
    evaluate|평가하다
    eventually|결국
    evidence|증거
    evolve|진화하다
    exact|정확한
    examine|조사하다, 검사하다
    exceed|넘다, 초과하다
    excellent|훌륭한
    exchange|교환하다; 교환
    exhausted|지친
    exhibit|전시하다
    exist|존재하다
    expand|확장하다
    expect|기대하다, 예상하다
    expense|비용
    experience|경험; 경험하다
    experiment|실험
    explore|탐험하다
    express|표현하다
    extend|연장하다, 확장하다
    extinct|멸종된
    extreme|극단적인
    facility|시설
    factor|요인
    failure|실패
    familiar|익숙한, 친숙한
    famous|유명한
    fascinate|매혹하다
    feature|특징
    fee|요금, 수수료
    flexible|유연한
    focus|집중하다; 초점
    force|힘; 강요하다
    foreign|외국의
    fortune|운, 재산
    foundation|기초, 재단
    frequent|잦은
    frustrate|좌절시키다
    fuel|연료
    function|기능
    fundamental|근본적인
    generate|생성하다, 발생시키다
    generation|세대
    generous|관대한, 너그러운
    genuine|진짜의, 진실한
    global|세계적인
    goal|목표
    gradually|점차
    grateful|감사하는
    guarantee|보장하다
    habit|습관
    harm|해; 해치다
    harmony|조화
    heritage|유산
    hesitate|망설이다
    honest|정직한
    humble|겸손한
    identify|확인하다, 동일시하다
    ignore|무시하다
    illustrate|설명하다, 삽화를 넣다
    immediate|즉각적인
    impact|영향, 충격
    include|포함하다
    income|소득
    increase|증가하다; 증가
    independent|독립적인
    indicate|나타내다, 가리키다
    individual|개인; 개인의
    industry|산업
    influence|영향; 영향을 주다
    inform|알리다
    ingredient|재료
    initial|처음의
    injury|부상
    innocent|무죄의, 순진한
    insight|통찰력
    insist|주장하다
    inspire|영감을 주다
    instance|사례
    instead|대신에
    instinct|본능
    instruction|지시, 설명
    intelligent|똑똑한
    intend|의도하다
    interact|상호작용하다
    interpret|해석하다, 통역하다
    interrupt|방해하다
    invest|투자하다
    investigate|조사하다
    involve|포함하다, 관련시키다
    isolate|고립시키다
    issue|문제, 쟁점; 발행하다
    judge|판단하다; 판사
    justify|정당화하다
    labor|노동
    lack|부족; 부족하다
    language|언어
    leisure|여가
    limit|한계; 제한하다
    literature|문학
    logical|논리적인
    maintain|유지하다
    major|주요한; 전공
    manage|관리하다, 해내다
    material|재료, 물질
    measure|측정하다; 조치
    medical|의학의
    mental|정신의
    method|방법
    minor|사소한, 작은
    mission|임무
    modern|현대의
    modify|수정하다
    moral|도덕적인
    motivate|동기를 부여하다
    mutual|상호의
    native|원주민의, 모국의
    negative|부정적인
    neglect|무시하다, 소홀히 하다
    negotiate|협상하다
    nervous|긴장한
    neutral|중립의
    notice|알아차리다; 공지
    nutrition|영양
    object|물체; 반대하다
    observe|관찰하다, 준수하다
    obtain|얻다
    obvious|명백한
    occasion|경우, 행사
    occupy|차지하다
    operate|작동하다, 수술하다
    opinion|의견
    opportunity|기회
    oppose|반대하다
    option|선택(권)
    ordinary|평범한
    organize|조직하다, 정리하다
    origin|기원
    outcome|결과
    participate|참여하다
    particular|특정한
    passion|열정
    patient|참을성 있는; 환자
    perceive|인식하다
    perform|공연하다, 수행하다
    permanent|영구적인
    persuade|설득하다
    phenomenon|현상
    philosophy|철학
    physical|신체의, 물리적인
    polite|공손한
    pollution|오염
    popular|인기 있는
    positive|긍정적인
    possess|소유하다
    potential|잠재적인; 잠재력
    predict|예측하다
    prejudice|편견
    preserve|보존하다
    pressure|압력
    previous|이전의
    primary|주요한, 최초의
    principle|원리, 원칙
    priority|우선 사항
    private|사적인
    procedure|절차
    process|과정
    profession|직업
    profit|이익
    progress|진보, 진행
    prohibit|금지하다
    promote|촉진하다, 승진시키다
    proper|적절한
    property|재산, 특성
    proportion|비율
    propose|제안하다
    protest|항의하다
    psychology|심리학
    publish|출판하다
    punish|처벌하다
    purchase|구매하다
    pursue|추구하다
    quality|질, 품질
    quantity|양
    random|무작위의
    range|범위
    rapid|빠른
    rare|드문
    rational|이성적인
    react|반응하다
    reasonable|합리적인
    recall|기억해 내다
    recognize|알아보다, 인정하다
    recover|회복하다
    reflect|반영하다, 반사하다
    refuse|거절하다
    region|지역
    regular|규칙적인
    reject|거절하다
    relationship|관계
    release|풀어 주다, 발표하다
    relevant|관련 있는
    reliable|믿을 만한
    relieve|덜어 주다, 안심시키다
    religion|종교
    rely|의지하다 (rely on)
    remain|남다, 여전히 ~이다
    remarkable|놀라운, 주목할 만한
    represent|대표하다, 나타내다
    require|요구하다, 필요로 하다
    research|연구; 연구하다
    resemble|닮다
    reserve|예약하다
    resident|주민
    resilient|회복력 있는
    resist|저항하다
    resolve|해결하다, 결심하다
    resource|자원
    respect|존경하다; 존경
    respond|응답하다, 반응하다
    responsible|책임 있는
    restore|복구하다
    restrict|제한하다
    result|결과
    retire|은퇴하다
    reveal|드러내다
    reward|보상
    role|역할
    routine|일상, 규칙적인 일
    rural|시골의
    sacrifice|희생; 희생하다
    satisfy|만족시키다
    scared|무서워하는
    schedule|일정
    scholar|학자
    security|안전, 보안
    select|선택하다
    sensitive|민감한
    separate|분리하다; 분리된
    serious|심각한, 진지한
    severe|심한
    significant|중요한, 상당한
    similar|비슷한
    sincere|진실한
    situation|상황
    skill|기술
    society|사회
    solution|해결책
    source|원천, 출처
    species|종(種)
    specific|구체적인, 특정한
    stable|안정된
    status|지위, 상태
    strategy|전략
    structure|구조
    struggle|애쓰다, 투쟁하다
    subject|주제, 과목
    substance|물질
    succeed|성공하다, 뒤를 잇다
    sufficient|충분한
    suitable|적합한
    supply|공급; 공급하다
    support|지지하다; 지지
    suppose|가정하다, 생각하다
    surface|표면
    surround|둘러싸다
    survey|설문 조사
    survive|살아남다
    sustain|유지하다, 지탱하다
    symbol|상징
    sympathy|동정, 공감
    technology|기술
    temperature|온도
    temporary|일시적인
    tend|경향이 있다 (tend to)
    tension|긴장
    theory|이론
    threat|위협
    tolerate|참다, 용인하다
    tradition|전통
    transfer|옮기다, 전학하다
    transform|변형시키다
    transport|수송하다; 수송
    treat|대하다, 치료하다
    trend|경향, 추세
    typical|전형적인
    unique|독특한
    universe|우주
    urban|도시의
    urgent|긴급한
    valuable|귀중한
    variety|다양성
    various|다양한
    vehicle|차량
    victim|희생자
    violent|폭력적인
    virtue|미덕
    visible|보이는
    vital|필수적인, 생명의
    volunteer|자원봉사자; 자원하다
    vote|투표하다
    weird|이상한
    welfare|복지
    wisdom|지혜
    witness|목격자; 목격하다
    worth|~의 가치가 있는
    apple|사과
    friend|친구
    school|학교
    teacher|선생님
    student|학생
    family|가족
    happy|행복한
    sad|슬픈
    beautiful|아름다운
    important|중요한
    difficult|어려운
    interesting|흥미로운
    delicious|맛있는
    weather|날씨
    library|도서관
    hospital|병원
    question|질문
    problem|문제
    future|미래
    dream|꿈; 꿈꾸다
    book|책
    pen|펜
    pencil|연필
    desk|책상
    chair|의자
    bag|가방
    classroom|교실
    homework|숙제
    test|시험
    exam|시험
    class|수업, 반
    subject|과목, 주제
    mother|어머니, 엄마
    father|아버지, 아빠
    brother|형제, 남동생
    sister|자매, 여동생
    baby|아기
    child|아이
    people|사람들
    person|사람
    man|남자
    woman|여자
    boy|소년
    girl|소녀
    name|이름
    water|물
    food|음식
    rice|쌀, 밥
    bread|빵
    milk|우유
    egg|달걀
    fruit|과일
    banana|바나나
    orange|오렌지
    grape|포도
    strawberry|딸기
    house|집
    home|집, 가정
    room|방
    door|문
    window|창문
    car|자동차
    bus|버스
    train|기차
    bike|자전거
    road|길, 도로
    city|도시
    country|나라, 시골
    world|세계
    dog|개
    cat|고양이
    bird|새
    fish|물고기
    horse|말
    tree|나무
    flower|꽃
    sun|해, 태양
    moon|달
    star|별
    sky|하늘
    sea|바다
    river|강
    mountain|산
    rain|비
    snow|눈
    wind|바람
    spring|봄
    summer|여름
    autumn|가을
    winter|겨울
    morning|아침
    night|밤
    day|날, 하루
    week|주
    month|달, 월
    year|해, 년
    time|시간
    money|돈
    music|음악
    movie|영화
    game|게임, 경기
    song|노래
    picture|그림, 사진
    color|색깔
    red|빨간
    blue|파란
    green|초록색의
    yellow|노란
    white|하얀
    black|검은
    big|큰
    small|작은
    tall|키가 큰
    long|긴
    short|짧은
    new|새로운
    old|늙은, 오래된
    young|어린, 젊은
    good|좋은
    bad|나쁜
    hot|뜨거운, 더운
    cold|차가운, 추운
    fast|빠른
    slow|느린
    easy|쉬운
    busy|바쁜
    tired|피곤한
    hungry|배고픈
    angry|화난
    kind|친절한
    smart|똑똑한
    love|사랑; 사랑하다
    hope|희망; 바라다
    help|도움; 돕다
    work|일; 일하다
    study|공부하다
    read|읽다
    write|쓰다
    speak|말하다
    listen|듣다
    walk|걷다
    run|달리다
    swim|수영하다
    sleep|자다
    eat|먹다
    drink|마시다
    play|놀다, 경기하다
    sing|노래하다
    dance|춤; 춤추다
    open|열다
    close|닫다
    start|시작하다
    finish|끝내다
    buy|사다
    sell|팔다
    give|주다
    take|가져가다, 잡다
    make|만들다
    know|알다
    think|생각하다
    like|좋아하다
    want|원하다
    need|필요하다
    come|오다
    go|가다
    see|보다
    look|보다
    watch|보다, 시계
    hear|듣다
    learn|배우다
    teach|가르치다
    remember|기억하다
    forget|잊다
    """

    static let dictionary: [String: String] = {
        var map: [String: String] = [:]
        for line in raw.split(separator: "\n") {
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, map[parts[0]] == nil { map[parts[0]] = parts[1] }
        }
        return map
    }()

    static func meaningReply(_ word: String) -> String? {
        if let (base, form) = EngVerbs.analyze(word), form != .ing || EngVerbs.irregular[base] != nil {
            let meaning = EngVerbs.meaning(of: base) ?? dictionary[base] ?? ""
            let name: String
            switch form {
            case .past: name = "과거형"
            case .pp: name = "과거분사"
            case .pastAndPP: name = "과거형·과거분사"
            case .third: name = "3인칭 단수 현재형"
            case .ing: name = "-ing형"
            }
            return "**\(word)**: \(base)\(meaning.isEmpty ? "" : "(\(meaning))")의 \(name)\n"
                + "\(base) - \(EngVerbs.pastForms(base).joined(separator: "/")) - \(EngVerbs.ppForms(base).joined(separator: "/"))"
        }
        if let singular = EngNouns.pluralToSingular[word], word != singular {
            let meaning = dictionary[singular].map { " (\($0))" } ?? ""
            return "**\(word)**: \(singular)\(meaning)의 복수형 (불규칙)"
        }
        guard let meaning = dictionary[word] ?? EngVerbs.meaning(of: word) else { return nil }
        var lines = ["**\(word)**: \(meaning)"]
        if let verb = EngVerbs.irregular[word] {
            lines.append("불규칙 동사: \(word) - \(verb.past.joined(separator: "/")) - \(verb.pp.joined(separator: "/"))")
        }
        return lines.joined(separator: "\n")
    }

    /// 퀴즈용 (영어, 대표 뜻 목록)
    static var quizPairs: [(String, [String])] {
        dictionary.map { word, meaning in
            let meanings = meaning.replacingOccurrences(of: ";", with: ",").components(separatedBy: ",")
                .map { $0.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return (word, meanings)
        }
    }
}

// MARK: - 숙어

private enum EngIdioms {
    struct Idiom {
        let key: String
        let display: String
        let meaning: String
        let example: String
        let exampleKo: String
        let note: String
    }

    /// 찾는말|보여줄 말|뜻|예문|해석|주의
    private static let raw = """
    look forward to|look forward to (-ing)|~을 기대하다, 고대하다|I'm looking forward to seeing you.|너를 만나기를 기대하고 있어요.|to는 전치사라 뒤에 명사나 동명사(-ing)가 와요.
    be used to|be used to (-ing)|~에 익숙하다|I'm used to getting up early.|나는 일찍 일어나는 데 익숙해요.|used to + 동사원형(~하곤 했다), be used to + 동사원형(~하는 데 사용되다)과 구분해요.
    get used to|get used to (-ing)|~에 익숙해지다|You will get used to living here.|여기 사는 데 곧 익숙해질 거예요.|to 뒤에 동명사(-ing)를 써요.
    used to|used to + 동사원형|(예전에) ~하곤 했다, ~이었다|I used to play soccer after school.|나는 방과 후에 축구를 하곤 했어요.|be used to -ing(~에 익숙하다)와 헷갈리지 마세요.
    take part in|take part in|~에 참가하다 (= participate in)|She took part in the contest.|그녀는 대회에 참가했어요.|
    give up|give up (-ing)|포기하다, 그만두다|Don't give up your dream.|꿈을 포기하지 마세요.|목적어로 동명사를 써요. (give up smoking)
    look after|look after|~을 돌보다 (= take care of)|I look after my little brother.|나는 남동생을 돌봐요.|
    look for|look for|~을 찾다|I'm looking for my phone.|휴대폰을 찾고 있어요.|
    look up to|look up to|~을 존경하다 (= respect)|I look up to my father.|나는 아버지를 존경해요.|반대말: look down on(~을 무시하다)
    look down on|look down on|~을 얕보다, 무시하다|Don't look down on others.|다른 사람을 무시하지 마세요.|
    look up|look up|(사전 등에서) 찾아보다|Look up the word in the dictionary.|그 단어를 사전에서 찾아봐요.|
    put off|put off (-ing)|미루다, 연기하다 (= postpone)|Don't put off your homework.|숙제를 미루지 마세요.|
    put up with|put up with|~을 참다 (= tolerate, stand)|I can't put up with the noise.|그 소음을 참을 수가 없어요.|
    take care of|take care of|~을 돌보다, 처리하다|Take care of yourself.|몸 잘 챙겨요.|
    take after|take after|~을 닮다 (= resemble)|She takes after her mother.|그녀는 엄마를 닮았어요.|
    take off|take off|(옷을) 벗다, 이륙하다|The plane took off on time.|비행기는 제시간에 이륙했어요.|반대: put on(입다)
    turn down|turn down|거절하다, (소리를) 줄이다|He turned down the offer.|그는 제안을 거절했어요.|
    bring up|bring up|기르다, (화제를) 꺼내다|She was brought up in Busan.|그녀는 부산에서 자랐어요.|
    come up with|come up with|(생각을) 떠올리다, 생각해 내다|He came up with a great idea.|그는 좋은 생각을 떠올렸어요.|
    carry out|carry out|수행하다, 실행하다|They carried out the experiment.|그들은 실험을 수행했어요.|
    figure out|figure out|이해하다, 알아내다|I can't figure out this problem.|이 문제를 이해할 수가 없어요.|
    find out|find out|알아내다, 발견하다|I found out the truth.|나는 진실을 알아냈어요.|
    get along with|get along with|~와 잘 지내다|I get along with my classmates.|나는 반 친구들과 잘 지내요.|
    get over|get over|극복하다, (병에서) 회복하다|She got over her cold.|그녀는 감기가 나았어요.|
    run out of|run out of|~을 다 써 버리다, 바닥나다|We ran out of time.|우리는 시간이 다 떨어졌어요.|
    keep up with|keep up with|(뒤처지지 않고) 따라가다|It's hard to keep up with the class.|수업을 따라가기 힘들어요.|
    catch up with|catch up with|따라잡다|I'll catch up with you soon.|곧 따라잡을게요.|
    make up for|make up for|보상하다, 만회하다|I studied hard to make up for lost time.|잃어버린 시간을 만회하려고 열심히 공부했어요.|
    make up one's mind|make up one's mind|결심하다 (= decide)|I made up my mind to study abroad.|나는 유학 가기로 결심했어요.|
    pay attention to|pay attention to|~에 주의를 기울이다|Pay attention to the teacher.|선생님 말씀에 집중하세요.|
    be interested in|be interested in|~에 관심이 있다|I'm interested in science.|나는 과학에 관심이 있어요.|
    be good at|be good at (-ing)|~을 잘하다|He is good at swimming.|그는 수영을 잘해요.|반대: be poor at
    be afraid of|be afraid of|~을 무서워하다|She is afraid of dogs.|그녀는 개를 무서워해요.|
    be proud of|be proud of|~을 자랑스러워하다 (= take pride in)|I'm proud of you.|네가 자랑스러워요.|
    be full of|be full of|~으로 가득 차다 (= be filled with)|The room was full of people.|방은 사람들로 가득했어요.|
    be famous for|be famous for|~으로 유명하다|Jeonju is famous for bibimbap.|전주는 비빔밥으로 유명해요.|be famous as(~로서 유명하다)와 구분해요.
    be responsible for|be responsible for|~에 책임이 있다|You are responsible for your actions.|네 행동은 네가 책임져야 해요.|
    depend on|depend on|~에 의존하다, ~에 달려 있다 (= rely on)|It depends on the weather.|그건 날씨에 달려 있어요.|
    deal with|deal with|~을 다루다, 처리하다|How do you deal with stress?|스트레스를 어떻게 다뤄요?|
    consist of|consist of|~으로 구성되다 (= be made up of)|Water consists of hydrogen and oxygen.|물은 수소와 산소로 이루어져 있어요.|수동태로 쓰지 않아요. (is consisted of ✗)
    result in|result in|~을 초래하다 (원인 result in 결과)|The accident resulted in two deaths.|그 사고로 두 명이 사망했어요.|result from은 반대 방향: 결과 result from 원인
    result from|result from|~에서 비롯되다 (결과 result from 원인)|His success resulted from hard work.|그의 성공은 노력에서 나왔어요.|
    because of|because of + 명사|~ 때문에 (= due to, owing to)|The game was canceled because of the rain.|비 때문에 경기가 취소됐어요.|because 뒤에는 주어 + 동사, because of 뒤에는 명사를 써요.
    in spite of|in spite of + 명사|~에도 불구하고 (= despite)|In spite of the rain, we went out.|비에도 불구하고 우리는 나갔어요.|although 뒤에는 주어 + 동사가 와요.
    instead of|instead of|~ 대신에|I drank tea instead of coffee.|커피 대신 차를 마셨어요.|
    according to|according to|~에 따르면|According to the news, it will snow.|뉴스에 따르면 눈이 올 거래요.|
    as soon as|as soon as + 주어 + 동사|~하자마자|Call me as soon as you arrive.|도착하자마자 전화해요.|미래 일이라도 현재시제를 써요. (as soon as you will arrive ✗)
    not only|not only A but also B|A뿐만 아니라 B도 (= B as well as A)|She is not only smart but also kind.|그녀는 똑똑할 뿐 아니라 친절해요.|주어로 쓰면 동사는 B에 맞춰요.
    either or|either A or B|A 또는 B 둘 중 하나|You can either stay or leave.|머물거나 떠날 수 있어요.|동사는 B에 맞춰요.
    neither nor|neither A nor B|A도 B도 아닌|Neither he nor I am ready.|그도 나도 준비가 안 됐어요.|동사는 B에 맞춰요.
    had better|had better + 동사원형|~하는 게 낫다 (충고)|You had better go to bed early.|일찍 자는 게 좋겠어요.|부정은 had better not + 동사원형
    would rather|would rather A (than B)|(B하느니) 차라리 A하겠다|I would rather stay home.|차라리 집에 있을래요.|뒤에 동사원형을 써요.
    be about to|be about to + 동사원형|막 ~하려고 하다|The movie is about to start.|영화가 막 시작하려고 해요.|
    be supposed to|be supposed to + 동사원형|~하기로 되어 있다, ~해야 한다|You are supposed to wear a uniform.|교복을 입어야 해요.|
    can't help|cannot help -ing|~하지 않을 수 없다 (= cannot but + 동사원형)|I couldn't help laughing.|웃지 않을 수 없었어요.|
    feel like|feel like -ing|~하고 싶다|I feel like eating pizza.|피자 먹고 싶어요.|feel like + 명사/절은 '~인 것 같다'
    be likely to|be likely to + 동사원형|~할 것 같다|It is likely to rain.|비가 올 것 같아요.|
    make sense|make sense|이치에 맞다, 이해가 되다|That makes sense.|그거 말 되네요.|
    take place|take place|일어나다, 개최되다 (= happen, be held)|The festival takes place in May.|축제는 5월에 열려요.|자동사라 수동태로 쓰지 않아요.
    in order to|in order to + 동사원형|~하기 위해서 (= so as to)|I study hard in order to pass the exam.|시험에 붙으려고 열심히 공부해요.|부정: in order not to
    as well as|A as well as B|B뿐만 아니라 A도|He speaks Chinese as well as English.|그는 영어뿐 아니라 중국어도 해요.|주어로 쓰면 동사는 A에 맞춰요.
    at least|at least|적어도, 최소한|Sleep at least seven hours.|적어도 7시간은 자요.|반대: at most(많아야)
    at last|at last|마침내 (= finally)|At last, summer vacation began.|마침내 여름방학이 시작됐어요.|
    by the way|by the way|그런데, 그건 그렇고|By the way, did you finish it?|그런데, 그거 끝냈어요?|
    for example|for example|예를 들어 (= for instance)|I like fruits, for example, apples.|나는 과일, 예를 들어 사과를 좋아해요.|
    in fact|in fact|사실은|In fact, I didn't know that.|사실 그건 몰랐어요.|
    on time|on time|제시간에, 정각에|The bus arrived on time.|버스가 제시간에 왔어요.|in time은 '늦지 않게, 시간 안에'
    in time|in time|늦지 않게, 시간 맞춰|We got there in time for the show.|공연 시간에 늦지 않게 도착했어요.|on time은 '정각에'
    on purpose|on purpose|일부러, 고의로|He broke it on purpose.|그는 그걸 일부러 깼어요.|반대: by accident(우연히)
    break down|break down|고장 나다|My car broke down.|차가 고장 났어요.|
    call off|call off|취소하다 (= cancel)|They called off the meeting.|그들은 회의를 취소했어요.|
    show up|show up|나타나다 (= appear, turn up)|He didn't show up.|그는 나타나지 않았어요.|
    set up|set up|설치하다, 세우다|We set up a tent.|우리는 텐트를 쳤어요.|
    be busy|be busy -ing|~하느라 바쁘다|I'm busy studying for the exam.|시험 공부하느라 바빠요.|be busy 뒤에는 동명사를 써요.
    so that|so that + 주어 + can|~하기 위해서, ~하도록|Speak louder so that everyone can hear.|모두 들을 수 있게 크게 말해요.|so + 형용사 + that(너무 ~해서 …하다)과 구분해요.
    too to|too + 형용사 + to부정사|너무 ~해서 …할 수 없다|He is too tired to walk.|그는 너무 피곤해서 걸을 수 없어요.|= so tired that he can't walk
    thanks to|thanks to|~ 덕분에|Thanks to you, I passed the test.|덕분에 시험에 붙었어요.|
    """

    static let idioms: [Idiom] = {
        raw.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 6 else { return nil }
            return Idiom(key: parts[0], display: parts[1], meaning: parts[2], example: parts[3], exampleKo: parts[4], note: parts[5])
        }
        .sorted { $0.key.count > $1.key.count }
    }()

    static func answer(_ lower: String, hasHangul: Bool) -> String? {
        let normalized = String(lower.map { ($0.isLetter && $0.isASCII) || $0 == "'" ? $0 : " " })
        let words = normalized.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }
        let padded = " " + words.joined(separator: " ") + " "
        for idiom in idioms {
            let keyWords = idiom.key.split(separator: " ").map(String.init)
            let matched: Bool
            if keyWords.count == 2, ["either or", "neither nor", "too to"].contains(idiom.key) {
                matched = padded.contains(" \(keyWords[0]) ") && padded.contains(" \(keyWords[1]) ") && hasHangul
            } else {
                matched = padded.contains(" \(idiom.key) ")
            }
            guard matched else { continue }
            // 영어로만 쓴 긴 문장 속에 우연히 들어 있는 경우는 제외
            if !hasHangul && words.count > keyWords.count + 2 { continue }
            var lines = ["**\(idiom.display)**", "뜻: \(idiom.meaning)", "예문: \(idiom.example) — \(idiom.exampleKo)"]
            if !idiom.note.isEmpty { lines.append("주의: \(idiom.note)") }
            return lines.joined(separator: "\n")
        }
        return nil
    }
}

// MARK: - 영어 문법 노트

private struct EngTopic {
    let title: String
    let keywords: [String]
    let body: String
}

private enum EngGrammar {
    static func topic(for compact: String) -> EngTopic? {
        var best: (EngTopic, Int)?
        for topic in topics {
            for keyword in topic.keywords {
                let key = keyword.lowercased().replacingOccurrences(of: " ", with: "")
                guard compact.contains(key) else { continue }
                if key.count > (best?.1 ?? 0) { best = (topic, key.count) }
            }
        }
        return best?.0
    }

    static func answer(_ compact: String) -> String? {
        guard let topic = topic(for: compact) else { return nil }
        return "**\(topic.title)**\n\(topic.body)"
    }

    static let topics: [EngTopic] = partOne + partTwo

    private static let partOne: [EngTopic] = [
        EngTopic(title: "문장의 5형식", keywords: ["5형식", "문장의형식", "문장형식", "1형식", "2형식", "3형식", "4형식", "수여동사", "목적격보어", "주격보어"], body: """
        • 1형식: 주어 + 동사 (Birds fly.)
        • 2형식: 주어 + 동사 + 주격보어 — become, seem, look, sound 뒤에는 형용사가 와요.
        • 3형식: 주어 + 동사 + 목적어
        • 4형식: 주어 + 동사 + 간접목적어(~에게) + 직접목적어(~을) — give, send, show, teach, buy … 3형식으로 바꿀 때 to / for / of를 써요.
        • 5형식: 주어 + 동사 + 목적어 + 목적격보어 (make, keep, find, call, want …)
        예문
        1) She looks happy. — 그녀는 행복해 보여요. (2형식)
        2) He gave me a book. = He gave a book to me. — 그는 나에게 책을 줬어요. (4형식 → 3형식)
        시험 포인트: 감각동사(look, sound, smell, taste, feel) 뒤에는 부사가 아니라 형용사를 써요. (looks happily ✗)
        """),
        EngTopic(title: "영어의 12시제", keywords: ["시제", "12시제", "진행형", "현재진행", "과거진행", "미래진행", "진행시제"], body: """
        • 기본: 현재(do) · 과거(did) · 미래(will do)
        • 진행: be + -ing (am doing, was doing, will be doing)
        • 완료: have + p.p. (have done, had done, will have done)
        • 완료진행: have been + -ing (have been doing, had been doing, will have been doing)
        → 때 3가지(현재·과거·미래) × 모양 4가지(기본·진행·완료·완료진행) = 12시제
        예문
        1) I am studying English now. — 나는 지금 영어를 공부하고 있어요.
        2) By next year, I will have lived here for ten years. — 내년이면 여기 산 지 10년이 돼요.
        시험 포인트: 상태동사(know, like, have(가지다), belong, want)는 진행형으로 잘 쓰지 않아요.
        """),
        EngTopic(title: "현재완료 (have / has + p.p.)", keywords: ["현재완료", "havep.p", "havepp", "현재완료진행", "완료시제", "havebeento", "havegoneto"], body: """
        • 과거의 일이 지금과 이어질 때 써요.
        • 4가지 용법: 완료(just, already, yet) · 경험(ever, never, before) · 계속(for, since) · 결과(have gone: 가 버리고 없음)
        • yesterday, ago, last ~, when, in 2020 같은 과거 시점 표현과는 함께 못 써요 → 과거시제를 써요.
        • have been to(가 본 적 있다) vs have gone to(가 버려서 지금 없다)
        예문
        1) I have lived here for five years. — 나는 여기서 5년째 살고 있어요.
        2) She has just finished her homework. — 그녀는 막 숙제를 끝냈어요.
        시험 포인트: I have seen him yesterday. ✗ → I saw him yesterday.
        """),
        EngTopic(title: "과거완료 (had + p.p.)", keywords: ["과거완료", "hadp.p", "hadpp", "대과거", "과거완료진행"], body: """
        • 과거의 어느 때보다 더 먼저 일어난 일(대과거)이나, 그때까지 이어진 일을 나타내요.
        • 두 과거 일 중 먼저 일어난 쪽에 had p.p.를 써요.
        • before, after처럼 순서가 분명한 접속사가 있으면 과거시제로 써도 돼요.
        예문
        1) When I arrived, the movie had already started. — 내가 도착했을 때 영화는 이미 시작했어요.
        2) She lost the watch that her father had bought her. — 그녀는 아버지가 사 준 시계를 잃어버렸어요.
        시험 포인트: 시간 순서를 보고 더 먼저 일어난 일을 had p.p.로 써요.
        """),
        EngTopic(title: "미래 표현", keywords: ["미래시제", "미래표현", "begoingto", "will과begoingto", "willbegoingto"], body: """
        • will + 동사원형: 말하는 순간 정한 일, 예측, 의지
        • be going to + 동사원형: 미리 계획한 일, 지금 보이는 근거로 하는 예측
        • 현재진행(be -ing): 확정된 가까운 일정 / 현재시제: 시간표·정해진 일정 (The train leaves at 7.)
        • be about to(막 ~하려 하다), be supposed to(~하기로 되어 있다)
        예문
        1) Look at the clouds. It is going to rain. — 구름 좀 봐요. 비가 오겠어요.
        2) I'm meeting Jane tomorrow. — 나는 내일 제인을 만나요.
        시험 포인트: 시간·조건 부사절(when, if, before, after, until)에서는 미래 대신 현재시제를 써요.
        """),
        EngTopic(title: "수동태 (be + p.p.)", keywords: ["수동태", "능동태", "bep.p", "bepp", "수동형", "시제와태"], body: """
        • 주어가 동작을 '당할' 때: be + p.p. (+ by 행위자)
        • 시제는 be동사로 나타내요: is made / was made / will be made / has been made / is being made
        • 4형식 수동태: 두 목적어 모두 주어가 될 수 있어요. 5형식은 목적격보어가 그대로 남아요.
        • 사역·지각동사의 목적격보어(동사원형)는 수동태에서 to부정사로 바뀌어요: He was made to wait.
        • by 이외의 전치사: be interested in, be covered with, be known to, be filled with, be made of(재료가 그대로) / from(재료가 변함)
        예문
        1) This book was written by Kim. — 이 책은 김 작가가 썼어요.
        2) The bridge is being repaired. — 다리가 수리되고 있어요.
        시험 포인트: 자동사(happen, appear, disappear, occur, arrive)는 수동태가 안 돼요. (was happened ✗)
        """),
        EngTopic(title: "조동사", keywords: ["조동사", "musthave", "shouldhave", "cannothave", "can'thave", "mayhave", "mighthave", "couldhave", "haveto", "mustnot", "don'thaveto"], body: """
        • can(능력·허가·가능성), may(허가·추측), must(의무·강한 추측), should(충고·의무), have to(의무, 과거는 had to)
        • 조동사 뒤에는 항상 동사원형: He can swims ✗ → He can swim
        • 조동사 + have p.p. (과거에 대한 추측·후회)
          must have p.p. ~했음이 틀림없다 / may(might) have p.p. ~했을지도 모른다 / cannot have p.p. ~했을 리가 없다 / should have p.p. ~했어야 했는데 / could have p.p. ~할 수도 있었는데
        • must not(~하면 안 된다, 금지) vs don't have to(~할 필요 없다)
        예문
        1) You should have studied harder. — 더 열심히 공부했어야 했어요.
        2) He must have been tired. — 그는 피곤했던 게 틀림없어요.
        시험 포인트: must not과 don't have to의 뜻 차이를 자주 물어요.
        """),
        EngTopic(title: "to부정사", keywords: ["to부정사", "부정사", "toinfinitive", "명사적용법", "형용사적용법", "부사적용법", "의미상주어", "부정사용법"], body: """
        • 모양: to + 동사원형 / 부정은 not to + 동사원형
        • 명사적 용법(~하는 것): 주어·목적어·보어 — To learn English is fun. / I want to learn.
        • 형용사적 용법(~할): 명사를 뒤에서 꾸며요 — something to drink
        • 부사적 용법: 목적(~하기 위해), 감정의 원인(~해서), 결과, 판단의 근거, 형용사 수식(easy to read)
        • 의미상 주어: for + 목적격 (It is hard for me to swim.) / 사람의 성격 형용사(kind, nice, foolish)는 of + 목적격
        예문
        1) I went to the library to borrow a book. — 책을 빌리려고 도서관에 갔어요. (목적)
        2) It was kind of you to help me. — 도와주다니 친절하시네요. (of + 목적격)
        시험 포인트: want, hope, plan, decide, expect, promise, refuse, agree는 to부정사를 목적어로 써요.
        """),
        EngTopic(title: "동명사 (-ing)", keywords: ["동명사", "gerund", "동명사와to부정사", "동명사목적어", "to부정사와동명사"], body: """
        • 동사원형 + -ing로 명사처럼 써요 (주어·목적어·보어·전치사의 목적어).
        • 동명사만 목적어로: enjoy, finish, mind, avoid, give up, keep, practice, suggest, consider, quit, deny, put off
        • to부정사만 목적어로: want, hope, plan, decide, expect, promise, refuse, agree, learn, wish
        • 둘 다 쓰지만 뜻이 다름: remember / forget -ing(한 것) vs to(할 것) · stop -ing(그만두다) vs stop to(~하려고 멈추다) · try -ing(시험 삼아 해 보다) vs try to(애쓰다) · regret -ing(한 것을 후회) vs regret to(~하게 되어 유감)
        • 전치사 뒤에는 동명사: look forward to -ing, be used to -ing, be good at -ing
        예문
        1) I enjoy reading novels. — 나는 소설 읽는 걸 즐겨요.
        2) Remember to lock the door. — 문 잠그는 거 잊지 마요. (할 일)
        시험 포인트: look forward to 다음에는 동사원형이 아니라 -ing! (to meet ✗ → to meeting)
        """),
        EngTopic(title: "분사 (현재분사 · 과거분사)", keywords: ["분사", "감정분사", "감정동사", "분사의형용사적용법"], body: """
        • 현재분사(-ing): 능동·진행 "~하는" — a sleeping baby
        • 과거분사(p.p.): 수동·완료 "~된, ~당한" — a broken window
        • 명사를 꾸밀 때: 분사 혼자면 명사 앞, 다른 말과 함께면 명사 뒤 (the boy playing the piano)
        • 감정동사: 감정을 일으키면 -ing (boring, exciting), 감정을 느끼면 p.p. (bored, excited)
        예문
        1) The movie was boring, so I was bored. — 영화가 지루해서 나는 지루했어요.
        2) Look at the leaves fallen on the ground. — 땅에 떨어진 나뭇잎들을 봐요.
        시험 포인트: 사람이 감정을 느낄 때는 p.p.(interested, surprised), 사물이 감정을 줄 때는 -ing.
        """),
        EngTopic(title: "분사구문", keywords: ["분사구문", "독립분사구문", "with분사구문", "분사구문만들기", "분사와분사구문"], body: """
        • 만드는 법: ① 접속사 지우기 ② 주어가 같으면 주어 지우기 ③ 동사를 -ing로 (Being / Having been은 생략 가능)
        • 뜻: 시간(~할 때), 이유(~해서), 조건(~하면), 양보(~해도), 동시동작(~하면서)
        • 수동이면 p.p.로 시작 (Written in English, …), 주절보다 앞선 일이면 Having p.p.
        • 주어가 다르면 주어를 남겨요(독립분사구문): It being rainy, we stayed home.
        • with + 명사 + 분사: ~한 채로 (with his eyes closed)
        예문
        1) Feeling tired, I went to bed early. — 피곤해서 일찍 잤어요.
        2) Seen from the sky, the island looks like a heart. — 하늘에서 보면 그 섬은 하트처럼 보여요.
        시험 포인트: 의미상 주어가 직접 하면 -ing, 당하면 p.p.
        """),
        EngTopic(title: "관계대명사", keywords: ["관계대명사", "관계사", "선행사", "계속적용법", "목적격관계대명사", "주격관계대명사", "소유격관계대명사", "관계대명사that", "관계대명사생략"], body: """
        • 두 문장을 이어 주면서 앞의 명사(선행사)를 꾸며요.
        • 사람: who(주격) / whom·who(목적격) / whose(소유격) · 사물·동물: which / which / whose · that은 사람·사물 모두 (주격·목적격)
        • 목적격 관계대명사는 생략할 수 있어요. '주격 관계대명사 + be동사'도 함께 생략 가능해요.
        • 계속적 용법(, which / , who): 앞 내용을 덧붙여 설명해요. that은 콤마 뒤와 전치사 뒤에 못 써요.
        • 전치사 + 관계대명사: the house in which I live (= where I live)
        예문
        1) I have a friend who lives in Busan. — 나는 부산에 사는 친구가 있어요.
        2) He passed the exam, which surprised everyone. — 그는 시험에 붙었는데, 그게 모두를 놀라게 했어요.
        시험 포인트: 콤마(,) 뒤와 전치사 뒤에는 that을 쓸 수 없어요.
        """),
        EngTopic(title: "관계대명사 what", keywords: ["관계대명사what", "what관계대명사", "what용법", "선행사를포함", "what과that"], body: """
        • what = the thing(s) which (~하는 것) — 선행사를 포함해서 앞에 명사가 없어요.
        • 명사절을 이끌어 주어·목적어·보어 역할을 해요.
        • what vs that: 앞에 선행사가 없고 뒤 문장이 불완전하면 what, 뒤 문장이 완전하면 접속사 that
        • 관용 표현: what is called(이른바), what I am(지금의 나), A is to B what C is to D(A와 B의 관계는 C와 D의 관계와 같다)
        예문
        1) What I want is a long vacation. — 내가 원하는 것은 긴 휴가예요.
        2) This is what he said. — 이게 그가 말한 거예요.
        시험 포인트: 선행사가 있으면 what을 못 써요. (the thing what ✗ → the thing that / which)
        """),
        EngTopic(title: "관계부사", keywords: ["관계부사", "관계부사how", "관계부사where", "관계부사when", "관계부사why"], body: """
        • 관계부사 = 전치사 + 관계대명사: when(시간), where(장소), why(이유: the reason), how(방법: the way)
        • 관계부사 뒤에는 완전한 문장이 와요. (관계대명사 뒤는 불완전한 문장)
        • the way와 how는 같이 쓰지 않아요: the way how ✗ → the way 또는 how
        • 계속적 용법: , when(그리고 그때) / , where(그리고 거기서)
        예문
        1) This is the house where I was born. — 여기가 내가 태어난 집이에요.
        2) Tell me the reason why you were late. — 늦은 이유를 말해 줘요.
        시험 포인트: 장소 명사라도 뒤 문장이 불완전하면 which / that (the city which I visited)
        """),
        EngTopic(title: "복합관계사 (-ever)", keywords: ["복합관계사", "복합관계대명사", "복합관계부사", "whoever", "whatever", "whichever", "whenever", "wherever", "nomatter"], body: """
        • 관계사 + ever: 선행사를 포함해요.
        • 복합관계대명사: whoever(~하는 누구든 / 누가 ~하더라도), whatever, whichever
        • 복합관계부사: whenever(~할 때마다 / 언제 ~하더라도), wherever, however(아무리 ~해도)
        • 양보의 뜻이면 no matter who / what / when / where / how로 바꿀 수 있어요.
        예문
        1) You can invite whoever you like. — 좋아하는 누구든 초대해도 돼요.
        2) However hard it is, I won't give up. — 아무리 어려워도 포기하지 않을 거예요.
        시험 포인트: however 뒤 어순은 however + 형용사/부사 + 주어 + 동사 (However it is hard ✗)
        """),
        EngTopic(title: "가정법 한눈에 보기", keywords: ["가정법", "가정법정리", "가정법종류"], body: """
        • 가정법 과거: If + 주어 + 과거동사(be는 were), 주어 + would / could + 동사원형 — 현재 사실의 반대
        • 가정법 과거완료: If + 주어 + had p.p., 주어 + would / could + have p.p. — 과거 사실의 반대
        • 혼합 가정법: If + had p.p., 주어 + would + 동사원형 (now) — 그때 ~했다면 지금 …할 텐데
        • I wish + 과거 / had p.p. (~라면 좋을 텐데) · as if + 과거 / had p.p. (마치 ~인 것처럼)
        • if 생략 도치: Were I you, … / Had I known, …
        예문
        1) If I were you, I would apologize. — 내가 너라면 사과할 거예요.
        2) If I had studied, I would have passed. — 공부했더라면 합격했을 거예요.
        시험 포인트: 가정법 과거는 '현재', 가정법 과거완료는 '과거' 사실의 반대예요. 동사 시제가 한 칸씩 뒤로 가요.
        """),
        EngTopic(title: "가정법 과거", keywords: ["가정법과거", "ifiwere"], body: """
        • 모양: If + 주어 + 과거동사(be동사는 주로 were), 주어 + would / could / might + 동사원형
        • 뜻: 현재 사실과 반대이거나 일어날 가능성이 낮은 일 (~라면 …할 텐데)
        • 직설법으로 바꾸면 현재시제: If I had money, I could buy it. = As I don't have money, I can't buy it.
        • Without / But for ~ = If it were not for ~ (~이 없다면)
        예문
        1) If I had wings, I could fly to you. — 날개가 있다면 너에게 날아갈 수 있을 텐데.
        2) If it were not for water, we could not live. — 물이 없다면 우리는 살 수 없을 거예요.
        시험 포인트: 주절에 will이 아니라 would / could를 써요.
        """),
        EngTopic(title: "가정법 과거완료", keywords: ["가정법과거완료", "ifihad"], body: """
        • 모양: If + 주어 + had p.p., 주어 + would / could / might + have p.p.
        • 뜻: 과거 사실과 반대 (~했더라면 …했을 텐데)
        • 직설법: If I had left earlier, I would have caught the bus. = As I didn't leave earlier, I didn't catch the bus.
        • If 생략 도치: Had I left earlier, …
        예문
        1) If you had told me, I would have helped you. — 네가 말해 줬더라면 도와줬을 거예요.
        2) Had it not been for your help, I would have failed. — 네 도움이 없었더라면 실패했을 거예요.
        시험 포인트: if절 had p.p.와 주절 would have p.p.의 짝을 확인해요.
        """),
        EngTopic(title: "혼합 가정법", keywords: ["혼합가정법", "혼합가정"], body: """
        • 모양: If + 주어 + had p.p. (과거), 주어 + would + 동사원형 (now / today)
        • 뜻: 그때 ~했더라면 (지금) …할 텐데
        • 주절의 now, today 같은 현재 표시가 단서예요.
        예문
        1) If I had eaten breakfast, I wouldn't be hungry now. — 아침을 먹었더라면 지금 배고프지 않을 텐데.
        2) If she had taken the medicine, she would be fine today. — 그녀가 약을 먹었더라면 오늘 괜찮을 텐데.
        시험 포인트: 문장 끝에 now가 보이면 주절은 would + 동사원형!
        """),
        EngTopic(title: "I wish · as if 가정법", keywords: ["iwish", "asif", "asthough", "wish가정법", "asif가정법", "it'stime"], body: """
        • I wish + 주어 + 과거동사: (지금) ~라면 좋을 텐데 / I wish + had p.p.: (그때) ~했더라면 좋았을 텐데
        • as if(as though) + 과거동사: 마치 ~인 것처럼 (주절과 같은 때) / as if + had p.p.: 마치 ~였던 것처럼 (주절보다 앞선 때)
        • It's time + 주어 + 과거동사: 이제 ~해야 할 때다
        예문
        1) I wish I were taller. — 키가 더 크면 좋을 텐데.
        2) He talks as if he had seen a ghost. — 그는 마치 유령을 본 것처럼 말해요.
        시험 포인트: I wish 뒤의 시제를 보고 현재의 반대인지 과거의 반대인지 구분해요.
        """)
    ]
}

extension EngGrammar {
    fileprivate static let partTwo: [EngTopic] = [
        EngTopic(title: "비교급 · 최상급", keywords: ["비교급", "최상급", "비교구문", "비교급강조", "the비교급", "비교급만드는법"], body: """
        • 비교급: -er 또는 more ~ + than / 최상급: the + -est 또는 the most ~ (in / of ~)
        • 불규칙: good / well - better - best, bad - worse - worst, many / much - more - most, little - less - least
        • 비교급 강조: much, even, still, far, a lot (very는 ✗)
        • The + 비교급, the + 비교급: ~할수록 더 …하다 / 비교급 and 비교급: 점점 더 ~
        • 최상급 뜻의 다른 표현: 비교급 than any other + 단수명사 / No (other) ~ is 비교급 than
        예문
        1) The more you practice, the better you get. — 연습할수록 더 잘하게 돼요.
        2) Seoul is bigger than any other city in Korea. — 서울은 한국의 다른 어떤 도시보다 커요.
        시험 포인트: than any other 뒤에는 단수명사, 비교급 강조에 very는 못 써요.
        """),
        EngTopic(title: "원급 비교 (as ~ as)", keywords: ["원급", "원급비교", "asas", "as~as", "배수비교", "배수표현"], body: """
        • as + 원급 + as: ~만큼 …한 / not as(so) + 원급 + as: ~만큼 …하지 않은
        • 배수 표현: 배수 + as 원급 as (three times as big as) = 배수 + 비교급 than
        • as + 원급 + as possible = as + 원급 + as 주어 + can: 가능한 한 ~하게
        예문
        1) She is as tall as her mother. — 그녀는 엄마만큼 키가 커요.
        2) Please come as soon as possible. — 가능한 한 빨리 와 주세요.
        시험 포인트: as ~ as 사이에는 비교급이 아니라 원급을 써요. (as taller as ✗)
        """),
        EngTopic(title: "접속사", keywords: ["접속사", "등위접속사", "종속접속사", "상관접속사", "양보접속사", "despite", "although"], body: """
        • 등위: and, but, or, so — 같은 형태끼리 이어요 (병렬 구조).
        • 상관: both A and B(복수), either A or B / neither A nor B / not only A but also B (동사는 B에 맞춤), not A but B
        • 시간: when, while, before, after, until, since, as soon as / 이유: because, since, as / 양보: though, although, even if / 조건: if, unless(= if not)
        • because + 주어 + 동사 vs because of + 명사 / although + 주어 + 동사 vs despite(in spite of) + 명사
        예문
        1) Not only you but also he is wrong. — 너뿐 아니라 그도 틀렸어요.
        2) Although it rained, we went out. — 비가 왔지만 우리는 나갔어요.
        시험 포인트: although와 despite, because와 because of 뒤의 형태 차이를 자주 물어요.
        """),
        EngTopic(title: "명사절 (that · whether · if)", keywords: ["명사절", "that절", "whether절", "명사절접속사", "접속사that", "whether와if"], body: """
        • 문장 안에서 주어·목적어·보어 역할을 하는 절이에요.
        • that(~라는 것): 뒤에 완전한 문장이 와요 / 목적어 자리의 that은 생략할 수 있어요.
        • whether / if(~인지 아닌지): if는 목적어 자리에만, whether는 주어·보어·전치사 뒤 모두 가능, whether or not
        • 의문사절(간접의문문): what, who, when, where, why, how + 주어 + 동사
        예문
        1) I think (that) he is honest. — 나는 그가 정직하다고 생각해요.
        2) Whether he will come is not clear. — 그가 올지는 확실하지 않아요.
        시험 포인트: 주어 자리에는 if가 아니라 whether를 써요.
        """),
        EngTopic(title: "간접의문문", keywords: ["간접의문문", "의문사+주어+동사", "간접의문"], body: """
        • 의문문이 다른 문장 속에 들어가면 어순: 의문사 + 주어 + 동사
        • 의문사가 없으면 if / whether + 주어 + 동사
        • think, believe, guess, suppose, imagine이 있으면 의문사를 맨 앞으로: What do you think he wants?
        예문
        1) Do you know where she lives? — 그녀가 어디 사는지 알아요? (where does she live ✗)
        2) I wonder if he likes me. — 그가 나를 좋아하는지 궁금해요.
        시험 포인트: 간접의문문 안에서는 do / does / did를 쓰지 않고 평서문 어순으로 써요.
        """),
        EngTopic(title: "도치", keywords: ["도치", "도치구문", "부정어도치", "부정어구도치", "only도치", "so도치", "neither도치", "장소도치"], body: """
        • 부정어(Never, Hardly, Little, Rarely, Not until, No sooner)가 문장 앞에 오면: 부정어 + 조동사 / be + 주어 + 동사
        • Only + 부사(구·절)가 앞에 와도 도치해요.
        • 장소·방향 부사구가 앞에 오면: 부사구 + 동사 + 주어 (Here comes the bus.)
        • So / Neither + 동사 + 주어: ~도 그래 / ~도 안 그래 (So do I. / Neither do I.)
        • 가정법 if 생략: Were I …, Had I …, Should you …
        예문
        1) Never have I seen such a beautiful view. — 이렇게 아름다운 풍경은 본 적이 없어요.
        2) Only then did I realize the truth. — 그제서야 나는 진실을 깨달았어요.
        시험 포인트: 일반동사는 do / does / did를 앞으로 보내고 동사는 원형으로 써요.
        """),
        EngTopic(title: "강조 구문", keywords: ["강조구문", "강조용법", "itisthat", "it~that", "do강조", "강조의do", "itis~that"], body: """
        • It is(was) + 강조할 말 + that ~: …한 것은 바로 ~이다 (주어·목적어·부사구를 강조)
        • 강조하는 말이 사람이면 who, 사물이면 which로 바꿔 쓸 수 있어요.
        • 동사 강조: do / does / did + 동사원형 (정말 ~하다)
        • 명사 강조: the very + 명사 / 부정 강조: not ~ at all, not ~ in the least
        예문
        1) It was Tom that broke the window. — 창문을 깬 사람은 바로 톰이었어요.
        2) I do love you. — 정말 사랑해요.
        시험 포인트: It is와 that을 빼도 문장이 완전하면 강조 구문, 아니면 가주어-진주어 구문이에요.
        """),
        EngTopic(title: "사역동사 (make · have · let)", keywords: ["사역동사", "사역", "get사역"], body: """
        • make / have / let + 목적어 + 동사원형 (~하게 하다, 시키다)
        • 목적어가 동작을 당하면 p.p.: I had my hair cut. (머리를 잘랐어요)
        • get + 목적어 + to부정사(능동) / p.p.(수동)
        • help + 목적어 + 동사원형 또는 to부정사 (둘 다 가능)
        예문
        1) My mom made me clean my room. — 엄마는 나에게 방 청소를 시켰어요.
        2) I had my car repaired. — 나는 차를 수리 맡겼어요.
        시험 포인트: make의 수동태는 be made to + 동사원형 (to가 생겨요).
        """),
        EngTopic(title: "지각동사", keywords: ["지각동사"], body: """
        • see, watch, hear, listen to, feel, notice, smell + 목적어 + 동사원형 / -ing
        • 동사원형: 동작 전체를 봄 / -ing: 진행 중인 순간을 강조 / p.p.: 목적어가 당함 (I heard my name called.)
        • 수동태에서는 to부정사나 -ing: He was seen to enter / entering the room.
        예문
        1) I saw him cross the street. — 나는 그가 길을 건너는 것을 봤어요.
        2) She heard someone calling her name. — 그녀는 누군가 자기 이름을 부르는 소리를 들었어요.
        시험 포인트: 지각동사의 목적격보어 자리에 to부정사는 못 와요. (saw him to cross ✗)
        """),
        EngTopic(title: "수 일치", keywords: ["수일치", "주어동사수일치", "수의일치", "주어와동사일치", "주어동사일치"], body: """
        • 주어가 단수면 단수 동사, 복수면 복수 동사 (꾸미는 말은 빼고 진짜 주어를 찾아요)
        • 동명사·to부정사·명사절 주어는 단수: Reading books is fun.
        • each, every, -one, -body, -thing → 단수 / both, few, many, several → 복수
        • the number of + 복수명사 → 단수 동사 / a number of + 복수명사 → 복수 동사
        • either A or B, neither A nor B, not only A but also B → B에 맞춤 / A as well as B → A에 맞춤 / both A and B → 복수
        • 부분 표현(some of, most of, half of, 분수 of): of 뒤 명사에 맞춰요.
        예문
        1) The number of students is increasing. — 학생 수가 늘고 있어요.
        2) The books on the desk are mine. — 책상 위의 책들은 내 거예요.
        시험 포인트: 주어 뒤에 꾸미는 말이 길면 진짜 주어를 찾아 동사를 맞춰요.
        """),
        EngTopic(title: "시제 일치 · 시간·조건 부사절", keywords: ["시제일치", "시간부사절", "조건부사절", "시간조건부사절", "부사절현재시제"], body: """
        • 주절이 과거면 종속절도 과거·과거완료로 맞춰요: He said that he was tired.
        • 예외: 변하지 않는 진리·습관은 현재시제 그대로, 역사적 사실은 항상 과거시제
        • 시간(when, before, after, until, as soon as)·조건(if, unless) 부사절에서는 미래 대신 현재시제
        • 하지만 명사절(know if / when ~)에서는 미래면 will을 써요.
        예문
        1) I will call you when I arrive. — 도착하면 전화할게요.
        2) I don't know if he will come. — 그가 올지 모르겠어요. (명사절)
        시험 포인트: 부사절 when / if와 명사절 when / if를 구분해요.
        """),
        EngTopic(title: "화법 전환", keywords: ["화법", "직접화법", "간접화법", "화법전환"], body: """
        • 평서문: say to → tell, 따옴표 → that절, 인칭·시제·부사를 바꿔요 (now → then, today → that day, tomorrow → the next day, here → there, ago → before)
        • 의문문: say to → ask, 의문사 + 주어 + 동사 / 의문사가 없으면 if(whether)
        • 명령문: tell / ask / order + 목적어 + to부정사 (부정은 not to)
        예문
        1) He said to me, "I am busy." → He told me that he was busy. — 그는 나에게 바쁘다고 말했어요.
        2) She said to me, "Where do you live?" → She asked me where I lived. — 그녀는 내게 어디 사는지 물었어요.
        시험 포인트: 시제를 한 단계 과거로, 시간·장소 부사도 바꾸는 것을 놓치지 마세요.
        """),
        EngTopic(title: "관사 (a · an · the)", keywords: ["관사", "부정관사", "정관사", "a와the", "a와an", "무관사"], body: """
        • a / an: 처음 말하는 셀 수 있는 단수 명사, '하나', '~마다(per)' — 첫 발음이 모음이면 an (an hour, an MP3, a university)
        • the: 이미 말한 것, 서로 아는 것, 하나뿐인 것(the sun), 최상급·서수 앞, 악기(play the piano), 꾸미는 말로 한정될 때
        • 관사를 안 쓰는 경우: 운동·식사·과목(play soccer, have lunch), by + 교통수단(by bus), 건물을 본래 목적으로 쓸 때(go to school / bed)
        예문
        1) I saw a cat. The cat was black. — 고양이를 봤어요. 그 고양이는 까만색이었어요.
        2) He is an honest boy. — 그는 정직한 소년이에요.
        시험 포인트: a / an은 철자가 아니라 첫 '발음'으로 정해요.
        """),
        EngTopic(title: "가주어 · 가목적어 it", keywords: ["가주어", "가목적어", "진주어", "진목적어", "it가주어", "it가목적어"], body: """
        • 주어가 길면(to부정사·that절) 뒤로 보내고 그 자리에 it을 써요: It is important to exercise.
        • 5형식에서 목적어가 to부정사·that절이면 가목적어 it: I found it difficult to solve the problem. (make, find, think, consider + it + 형용사 + to부정사)
        • 의미상 주어: It is hard for me to … / It is kind of you to …
        예문
        1) It is true that he won the prize. — 그가 상을 탄 것은 사실이에요.
        2) I think it necessary to study every day. — 매일 공부하는 게 필요하다고 생각해요.
        시험 포인트: 가목적어 it은 생략할 수 없어요. (I found difficult to … ✗)
        """),
        EngTopic(title: "전치사 in · on · at", keywords: ["전치사", "시간전치사", "장소전치사", "inonat", "in·on·at", "in,on,at"], body: """
        • 시간: at(시각·정확한 때: at 7, at night) / on(날짜·요일·특정한 날: on Monday, on May 5) / in(월·계절·연도·긴 기간: in July, in 2025, in the morning)
        • 장소: at(한 지점: at the bus stop) / on(표면 위: on the wall) / in(공간 안: in the room, in Seoul)
        • for(얼마 동안: for 3 years) vs during(특정 기간 동안: during the vacation) / by(~까지 완료) vs until(~까지 계속)
        • 전치사 뒤에는 명사·동명사를 써요.
        예문
        1) I was born on March 3, 2009. — 나는 2009년 3월 3일에 태어났어요.
        2) Finish it by Friday. — 금요일까지 끝내요.
        시험 포인트: next, last, this, every 앞에는 전치사를 쓰지 않아요. (on next Monday ✗)
        """),
        EngTopic(title: "부가의문문", keywords: ["부가의문문", "부가의문"], body: """
        • 앞이 긍정이면 부정으로, 부정이면 긍정으로 / 동사·조동사와 인칭대명사로 만들어요.
        • 일반동사는 do / does / did: You like it, don't you?
        • 명령문 → will you? / Let's ~ → shall we? / I am ~ → aren't I?
        • 대답은 사실이 긍정이면 Yes, 부정이면 No (우리말 대답과 반대일 수 있어요)
        예문
        1) She can swim, can't she? — 그녀는 수영할 수 있죠, 그렇죠?
        2) Let's go, shall we? — 가요, 그럴까요?
        시험 포인트: There is ~ 문장은 isn't there?처럼 there를 써요.
        """),
        EngTopic(title: "감탄문", keywords: ["감탄문", "what감탄문", "how감탄문"], body: """
        • What + a(n) + 형용사 + 명사 + 주어 + 동사! (복수·셀 수 없는 명사면 a 없이)
        • How + 형용사 / 부사 + 주어 + 동사!
        • 뒤의 주어 + 동사는 자주 생략돼요.
        예문
        1) What a beautiful day it is! — 정말 아름다운 날이에요!
        2) How fast he runs! — 그는 정말 빨리 달려요!
        시험 포인트: 명사가 있으면 What, 형용사·부사만 있으면 How.
        """),
        EngTopic(title: "대명사 (재귀대명사 · 부정대명사)", keywords: ["재귀대명사", "부정대명사", "대명사", "another", "theother", "others", "one과it"], body: """
        • 재귀대명사(myself, yourself …): 주어와 목적어가 같을 때(생략 ✗), 강조할 때(생략 가능) / by oneself(혼자), for oneself(스스로)
        • one(같은 종류의 아무거나) vs it(바로 그것)
        • 둘 중: one ~ the other / 셋 이상: one ~ another ~ the other / 여럿: some ~ others(다른 일부) ~ the others(나머지 전부)
        예문
        1) I lost my pen, so I bought a new one. — 펜을 잃어버려서 새 걸 샀어요.
        2) I have two sisters. One is a teacher, and the other is a nurse. — 언니가 둘인데, 한 명은 선생님이고 다른 한 명은 간호사예요.
        시험 포인트: 정해진 나머지면 the other(s), 정해지지 않은 다른 것이면 another / others.
        """),
        EngTopic(title: "셀 수 있는 명사 · 셀 수 없는 명사", keywords: ["셀수있는명사", "셀수없는명사", "가산명사", "불가산명사", "수량형용사", "many와much", "few와little", "afew"], body: """
        • 셀 수 없는 명사: information, advice, furniture, homework, news, money, water, bread, knowledge, equipment → a / an, -s를 붙이지 않아요.
        • 세는 법: a piece of advice, a glass of water, a loaf of bread, two cups of coffee
        • 수(셀 수 있는): many, (a) few, a number of / 양(셀 수 없는): much, (a) little, an amount of / 둘 다: a lot of, lots of, some, any
        • a few / a little: 조금 있는(긍정) / few / little: 거의 없는(부정)
        예문
        1) She gave me some useful advice. — 그녀는 유용한 조언을 해 줬어요.
        2) I have a few friends here. — 나는 여기 친구가 몇 명 있어요.
        시험 포인트: informations, advices처럼 -s를 붙이면 틀려요.
        """),
        EngTopic(title: "형용사 · 부사", keywords: ["형용사와부사", "빈도부사", "부사위치", "형용사부사", "형용사의위치", "hardly", "lately"], body: """
        • 형용사: 명사를 꾸미거나 보어 / 부사: 동사·형용사·다른 부사·문장 전체를 꾸밈
        • 빈도부사(always, usually, often, sometimes, never): be동사·조동사 뒤, 일반동사 앞
        • -thing, -one, -body는 형용사가 뒤에서 꾸며요: something cold
        • 모양이 비슷해도 뜻이 다른 부사: hard(열심히) / hardly(거의 ~않다), late(늦게) / lately(최근에), near(가까이) / nearly(거의), high(높이) / highly(매우)
        예문
        1) I always get up early. — 나는 항상 일찍 일어나요.
        2) I want something cold to drink. — 차가운 마실 것을 원해요.
        시험 포인트: hardly, lately, nearly는 뜻이 완전히 달라요.
        """),
        EngTopic(title: "too ~ to · so ~ that · enough to", keywords: ["tooto", "too~to", "so~that", "sothat", "enoughto", "such~that", "결과구문"], body: """
        • too + 형용사 + to부정사: 너무 ~해서 …할 수 없다 = so + 형용사 + that + 주어 + can't
        • 형용사 + enough + to부정사: …할 만큼 충분히 ~하다 = so + 형용사 + that + 주어 + can
        • so + 형용사 / 부사 + that: 너무 ~해서 …하다 / such + (a) + 형용사 + 명사 + that
        • so that + 주어 + can: ~하기 위해서 (목적) = in order to
        예문
        1) He is too young to drive. = He is so young that he can't drive. — 그는 너무 어려서 운전할 수 없어요.
        2) She is old enough to travel alone. — 그녀는 혼자 여행할 만큼 나이가 들었어요.
        시험 포인트: enough는 형용사 '뒤'에 써요. (enough old ✗)
        """),
        EngTopic(title: "어법 문제 푸는 법", keywords: ["어법", "어법문제", "문법문제", "어법푸는법"], body: """
        • ① 동사 자리인지 준동사(to부정사·동명사·분사) 자리인지 먼저 봐요. 한 문장에 동사는 접속사 수 + 1개예요.
        • ② 주어와 동사의 수 일치를 확인해요. (꾸미는 말을 지우고 진짜 주어 찾기)
        • ③ 능동 / 수동: 주어가 하는 건지 당하는 건지 확인해요.
        • ④ 관계사: 뒤 문장이 완전하면 관계부사·접속사 that, 불완전하면 관계대명사·what
        • ⑤ 형용사 / 부사: 보어 자리는 형용사, 동사를 꾸미면 부사
        예문
        1) The girls who live next door is ✗ → are — 옆집에 사는 소녀들은 … (주어 The girls)
        2) The book written by him is popular. — 그가 쓴 책은 인기가 많아요. (책은 '쓰여진' 것 → p.p.)
        시험 포인트: 수 일치, 능동·수동, 관계사, 동사·준동사가 가장 자주 나와요.
        """)
    ]
}

// MARK: - 문장 교정 (자주 하는 실수를 규칙으로 찾기)

private enum EngChecker {
    struct Fix {
        let text: String
        let minor: Bool
    }

    struct Token {
        var lead: String
        var core: String
        var trail: String
        var removed = false
        var lower: String { removed ? "" : core.lowercased() }
    }

    enum Person { case first, third, plural }

    final class Work {
        var tokens: [Token]
        var fixes: [Fix] = []
        init(_ tokens: [Token]) { self.tokens = tokens }

        var count: Int { tokens.count }
        func lower(_ i: Int) -> String { i >= 0 && i < tokens.count ? tokens[i].lower : "" }

        func next(after i: Int, skipping: Set<String> = []) -> Int? {
            var j = i + 1
            while j < tokens.count {
                if !tokens[j].removed && !tokens[j].core.isEmpty {
                    if skipping.contains(tokens[j].lower) { j += 1; continue }
                    return j
                }
                j += 1
            }
            return nil
        }

        func previous(before i: Int, skipping: Set<String> = []) -> Int? {
            var j = i - 1
            while j >= 0 {
                if !tokens[j].removed && !tokens[j].core.isEmpty {
                    if skipping.contains(tokens[j].lower) { j -= 1; continue }
                    return j
                }
                j -= 1
            }
            return nil
        }

        func replace(_ i: Int, with new: String, reason: String, minor: Bool = false) {
            let old = tokens[i].core
            guard old != new, !new.isEmpty else { return }
            var value = new
            if let first = old.first, first.isUppercase, let firstNew = value.first, old != "I" {
                value = firstNew.uppercased() + value.dropFirst()
            }
            tokens[i].core = value
            fixes.append(Fix(text: "\(old) → \(value): \(reason)", minor: minor))
        }

        func remove(_ i: Int, reason: String) {
            let old = tokens[i].core
            tokens[i].removed = true
            if !tokens[i].trail.isEmpty, let p = previous(before: i) { tokens[p].trail += tokens[i].trail }
            fixes.append(Fix(text: "\(old) 삭제: \(reason)", minor: false))
        }

        var sentence: String {
            tokens.filter { !$0.removed }.map { $0.lead + $0.core + $0.trail }.joined(separator: " ")
        }
    }

    // MARK: 단어 묶음

    static let modalsAndDo: Set<String> = ["do", "does", "did", "don't", "doesn't", "didn't", "can", "can't", "cannot", "could",
                                           "couldn't", "will", "won't", "would", "wouldn't", "shall", "should", "shouldn't", "may",
                                           "might", "must", "mustn't", "let's"]
    static let haveForms: Set<String> = ["have", "has", "had", "having", "i've", "you've", "we've", "they've", "haven't", "hasn't", "hadn't"]
    static let beForms: Set<String> = ["am", "is", "are", "was", "were", "be", "been", "being", "i'm", "you're", "we're", "they're",
                                       "isn't", "aren't", "wasn't", "weren't"]
    static let skipAdverbs: Set<String> = ["not", "never", "always", "really", "just", "also", "even", "still", "ever", "usually",
                                           "often", "sometimes", "already", "actually", "probably", "recently", "finally"]
    static let frequencyAdverbs: Set<String> = ["always", "usually", "often", "sometimes", "never", "really", "also", "still", "just",
                                                "rarely", "seldom", "actually", "even", "only", "already", "probably"]
    static let clauseStarters: Set<String> = ["and", "but", "because", "when", "if", "so", "then", "after", "before", "think", "know",
                                              "believe", "hope", "said", "says", "while", "although", "though", "since", "until", "or",
                                              "that", "guess", "feel", "sure", "where", "why", "how", "what", "once", "unless"]
    /// 다른 동사의 과거형과 모양이 같아서 'to' 뒤에서 판단하기 어려운 말
    static let ambiguousPast: Set<String> = ["left", "found", "felt", "rose", "lay", "fell", "bound", "ground", "wound", "saw", "bore", "lit"]
    /// be동사 뒤에 와도 자연스러운 말 (형용사·명사로도 쓰는 동사)
    static let beFriendly: Set<String> = ["clean", "open", "close", "dry", "empty", "free", "last", "like", "mean", "love", "hope",
                                          "help", "work", "rain", "snow", "rest", "change", "fine", "light", "right", "wrong",
                                          "present", "fit", "wet", "cool", "warm", "slow", "fast", "clear", "live", "welcome",
                                          "awake", "complete", "correct", "separate", "content", "agree", "disagree", "need",
                                          "use", "order", "answer", "test", "plan", "visit", "talk", "walk", "call", "cook", "kiss",
                                          "touch", "fix", "mix", "dance", "shop", "travel", "wish", "end", "control", "check",
                                          "film", "lie", "dream", "smell", "taste", "sound", "upset"]
    static let singularNouns: Set<String> = ["mother", "father", "mom", "dad", "brother", "sister", "friend", "teacher", "son", "daughter",
                                             "uncle", "aunt", "grandmother", "grandfather", "grandma", "grandpa", "family", "dog", "cat",
                                             "baby", "boy", "girl", "man", "woman", "student", "class", "team", "sun", "earth", "bus",
                                             "train", "store", "shop", "movie", "book", "school", "company", "government", "phone",
                                             "computer", "child", "person", "city", "country", "world", "doctor", "car", "house"]
    static let pluralNouns: Set<String> = ["friends", "parents", "students", "children", "people", "brothers", "sisters", "kids",
                                           "teachers", "dogs", "cats", "boys", "girls", "men", "women", "classmates", "players"]
    static let functionWords: Set<String> = ["please", "yesterday", "today", "tomorrow", "maybe", "here", "there", "now", "then",
                                             "also", "so", "and", "but", "or", "because", "when", "if", "every", "last", "next",
                                             "this", "that", "these", "those", "what", "where", "why", "how", "who", "which", "let",
                                             "let's", "thank", "thanks", "hello", "hi", "yes", "no", "ok", "okay", "sorry", "oh",
                                             "wow", "well", "really", "actually", "sometimes", "usually", "always", "never", "often",
                                             "in", "on", "at", "after", "before", "for", "from", "with", "of", "to", "the", "a", "an",
                                             "my", "your", "his", "her", "our", "their", "its", "some", "many", "much", "all", "both",
                                             "each", "dear", "good", "great", "nice", "once", "first", "finally", "suddenly", "today's"]
    static let pastTimeNouns: Set<String> = ["week", "month", "year", "night", "weekend", "summer", "winter", "spring", "fall",
                                             "autumn", "time", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
                                             "semester", "vacation"]
    static let uncountablePlurals: [String: String] = [
        "informations": "information", "advices": "advice", "furnitures": "furniture", "homeworks": "homework",
        "luggages": "luggage", "baggages": "baggage", "equipments": "equipment", "knowledges": "knowledge",
        "evidences": "evidence", "sceneries": "scenery", "machineries": "machinery", "jewelries": "jewelry"
    ]

    // MARK: 확인

    static func tokenize(_ text: String) -> [Token] {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).map { piece in
            let chars = Array(piece)
            guard let first = chars.firstIndex(where: { $0.isLetter || $0.isNumber }),
                  let last = chars.lastIndex(where: { $0.isLetter || $0.isNumber }) else {
                return Token(lead: String(chars), core: "", trail: "")
            }
            return Token(lead: String(chars[..<first]), core: String(chars[first...last]), trail: String(chars[(last + 1)...]))
        }
    }

    static func check(_ raw: String) -> (corrected: String, fixes: [Fix]) {
        let w = Work(tokenize(raw.replacingOccurrences(of: "’", with: "'")))
        guard w.count > 0 else { return (raw, []) }
        let all = w.tokens.map(\.lower)
        let pastContext = all.contains("yesterday") || all.contains("ago")
            || zip(all, all.dropFirst()).contains { $0 == "last" && pastTimeNouns.contains($1) }
        let subjunctive = all.contains("if") || all.contains("wish") || all.contains("though")

        fixPronounI(w)
        fixArticles(w)
        fixWrongForms(w)
        fixWordChoices(w)
        fixAfterModals(w)
        fixPerfect(w)
        fixSubjects(w, pastContext: pastContext, subjunctive: subjunctive)
        fixBeBase(w)
        fixPrepositions(w)
        fixCapitalAndPeriod(w)
        return (w.sentence, w.fixes)
    }

    static func report(_ sentence: String, intro: String?) -> String {
        let result = check(sentence)
        var lines: [String] = []
        if let intro { lines.append(intro) }
        lines.append("**문장 확인**")
        lines.append("원래 문장: \(sentence)")
        if result.fixes.isEmpty {
            lines.append("흔히 틀리는 부분은 찾지 못했어요.")
            lines.append("※ 규칙으로 확인해서 문맥, 단어 선택, 시제 흐름 같은 오류는 놓칠 수 있어요.")
            return lines.joined(separator: "\n")
        }
        lines.append("고친 문장: **\(result.corrected)**")
        for (index, fix) in result.fixes.enumerated() { lines.append("\(index + 1)) \(fix.text)") }
        lines.append("※ 두잇 AI는 자주 하는 실수를 규칙으로 찾아요. 모든 오류를 찾지는 못해요.")
        return lines.joined(separator: "\n")
    }

    // MARK: 규칙들

    private static func fixPronounI(_ w: Work) {
        var reported = false
        for i in 0..<w.count where w.tokens[i].core == "i" || w.tokens[i].core.hasPrefix("i'") {
            let old = w.tokens[i].core
            w.tokens[i].core = "I" + old.dropFirst()
            if !reported {
                w.fixes.append(Fix(text: "\(old) → I\(old.dropFirst()): '나'를 뜻하는 I는 항상 대문자로 써요.", minor: true))
                reported = true
            }
        }
    }

    private static func fixArticles(_ w: Work) {
        for i in 0..<w.count where w.lower(i) == "a" || w.lower(i) == "an" {
            guard let j = w.next(after: i) else { continue }
            let word = w.tokens[j].core
            guard let first = word.first, first.isLetter else { continue }
            let vowel = EngText.startsWithVowelSound(word)
            if w.lower(i) == "a" && vowel {
                w.replace(i, with: "an", reason: "뒤 단어(\(word))가 모음 소리로 시작해서 an을 써요.")
            } else if w.lower(i) == "an" && !vowel {
                w.replace(i, with: "a", reason: "뒤 단어(\(word))가 자음 소리로 시작해서 a를 써요.")
            }
        }
    }

    private static func fixWrongForms(_ w: Work) {
        for i in 0..<w.count {
            guard let base = EngVerbs.wrongForms[w.lower(i)] else { continue }
            let p = w.previous(before: i, skipping: skipAdverbs).map { w.lower($0) } ?? ""
            let forms = "\(base) - \(EngVerbs.past(base)) - \(EngVerbs.pp(base))"
            if haveForms.contains(p) || beForms.contains(p) {
                w.replace(i, with: EngVerbs.pp(base), reason: "불규칙 동사라서 과거분사 모양이 따로 있어요. (\(forms))")
            } else if modalsAndDo.contains(p) || p == "to" {
                w.replace(i, with: base, reason: "\(p) 뒤에는 동사원형을 써요.")
            } else {
                w.replace(i, with: EngVerbs.past(base), reason: "불규칙 동사라서 -ed를 붙이지 않아요. (\(forms))")
            }
        }
    }

    private static func fixWordChoices(_ w: Work) {
        for i in 0..<w.count {
            let word = w.lower(i)
            if let fixed = uncountablePlurals[word] {
                w.replace(i, with: fixed, reason: "셀 수 없는 명사(\(fixed))라서 -s를 붙이지 않아요.")
                if let j = w.next(after: i), ["are", "were"].contains(w.lower(j)) {
                    w.replace(j, with: w.lower(j) == "are" ? "is" : "was", reason: "셀 수 없는 명사는 단수 취급해요.")
                }
                continue
            }
            guard let j = w.next(after: i) else { continue }
            let next = w.lower(j)
            switch word {
            case "much" where pluralNouns.contains(next) || ["books", "things", "questions", "times", "cars"].contains(next):
                w.replace(i, with: "many", reason: "셀 수 있는 명사의 복수형 앞에는 much가 아니라 many를 써요.")
            case _ where ["am", "is", "are", "was", "were", "i'm", "you're", "we're", "they're"].contains(word) && (next == "agree" || next == "disagree"):
                let fixedVerb: String
                switch word {
                case "is": fixedVerb = next + "s"
                case "was", "were": fixedVerb = next + "d"
                default: fixedVerb = next
                }
                if word.hasPrefix("i'") || word.hasSuffix("'re") {
                    let pronoun = String(w.tokens[i].core.split(separator: "'").first ?? "")
                    w.tokens[i].core = pronoun
                    w.fixes.append(Fix(text: "\(word) \(next) → \(pronoun) \(fixedVerb): agree는 '동의하다'라는 동사라 be동사와 같이 쓰지 않아요.", minor: false))
                    w.tokens[j].core = fixedVerb
                } else {
                    w.remove(i, reason: "agree는 '동의하다'라는 동사라 be동사와 같이 쓰지 않아요.")
                    w.tokens[j].core = fixedVerb
                }
            case "very" where ["like", "love", "enjoy", "want", "hate", "prefer", "liked", "loved", "enjoyed", "wanted", "likes", "loves", "enjoys", "wants"].contains(next):
                w.replace(i, with: "really", reason: "very는 동사를 직접 꾸미지 못해요. really를 쓰거나 '~ very much'로 써요.")
            case _ where (word == "more" || word == "very") && EngAdjectives.fromComparative[next] != nil && !next.hasSuffix("est") && next != "best" && next != "worst":
                if word == "more" {
                    w.remove(i, reason: "이미 비교급(\(next))이라서 more를 함께 쓰지 않아요.")
                } else {
                    w.replace(i, with: "much", reason: "비교급을 강조할 때는 very가 아니라 much, even, far, a lot을 써요.")
                }
            case "most" where (next.hasSuffix("est") || next == "best" || next == "worst") && EngAdjectives.fromComparative[next] != nil:
                w.remove(i, reason: "이미 최상급(\(next))이라서 most를 함께 쓰지 않아요.")
            case "more" where EngAdjectives.common.contains(next) && !EngAdjectives.compare(next).comparative.hasPrefix("more"):
                let comparative = EngAdjectives.compare(next).comparative
                guard !comparative.contains("/") else { break }
                w.remove(i, reason: "짧은 형용사는 more 대신 -er로 비교급을 만들어요.")
                w.tokens[j].core = comparative
                w.fixes.append(Fix(text: "\(next) → \(comparative): 짧은 형용사의 비교급이에요.", minor: false))
            default:
                break
            }
        }
    }

    private static func fixAfterModals(_ w: Work) {
        for i in 0..<w.count {
            let trigger = w.lower(i)
            guard modalsAndDo.contains(trigger) || trigger == "to" else { continue }
            guard var j = w.next(after: i, skipping: skipAdverbs) else { continue }
            // 의문문: Did you went …? → 주어 하나 건너뛰기
            if trigger != "to", ["i", "you", "he", "she", "it", "we", "they"].contains(w.lower(j)),
               let k = w.next(after: j, skipping: skipAdverbs) { j = k }
            let word = w.lower(j)
            guard let (base, kind) = EngVerbs.analyze(word), kind != .ing else { continue }
            if trigger == "to" {
                // to 뒤에서는 확실한 과거형만 (전치사 to와 헷갈리지 않게)
                guard kind == .past || kind == .pastAndPP, !ambiguousPast.contains(word), EngVerbs.irregular[base] != nil || word.hasSuffix("ed") else { continue }
                if let p = w.previous(before: i), ["according", "close", "next", "due", "thanks"].contains(w.lower(p)) && kind == .pastAndPP && word.hasSuffix("ed") { continue }
            }
            if kind == .pp, ambiguousPast.contains(word) { continue }
            w.replace(j, with: base, reason: "\(w.tokens[i].core) 뒤에는 동사원형을 써요.")
        }
    }

    private static func fixPerfect(_ w: Work) {
        for i in 0..<w.count where haveForms.contains(w.lower(i)) {
            guard let j = w.next(after: i, skipping: skipAdverbs) else { continue }
            let word = w.lower(j)
            guard let base = EngVerbs.pastOnlyBase(word) else { continue }
            let pp = EngVerbs.pp(base)
            w.replace(j, with: pp, reason: "have / has / had 뒤에는 과거분사를 써요. (\(base) - \(EngVerbs.past(base)) - \(pp))")
        }
    }

    private static func subject(at i: Int, in w: Work) -> (person: Person, end: Int)? {
        let word = w.lower(i)
        switch word {
        case "i": return (.first, i)
        case "he", "she", "it", "everyone", "everybody", "someone", "somebody", "nobody", "everything", "something", "nothing":
            return (.third, i)
        case "you", "we", "they", "people", "children", "students", "parents", "kids":
            return (.plural, i)
        case "my", "your", "his", "her", "our", "their", "the", "this", "that", "these", "those", "a", "an":
            guard let j = w.next(after: i) else { return nil }
            let noun = w.lower(j)
            if singularNouns.contains(noun) && !["these", "those"].contains(word) { return (.third, j) }
            if pluralNouns.contains(noun) && !["this", "that", "a", "an"].contains(word) { return (.plural, j) }
            return nil
        default:
            // 문장 첫머리의 이름 (Tom, Minji …)
            let core = w.tokens[i].core
            guard i == 0, core.count >= 3, let first = core.first, first.isUppercase,
                  core.dropFirst().allSatisfy({ $0.isLowercase }), !functionWords.contains(word),
                  !EngVerbs.isBaseVerb(word), EngWords.dictionary[word] == nil, EngVerbs.analyze(word) == nil else { return nil }
            return (.third, i)
        }
    }

    private static func fixSubjects(_ w: Work, pastContext: Bool, subjunctive: Bool) {
        var i = 0
        while i < w.count {
            guard !w.tokens[i].removed, let found = subject(at: i, in: w) else { i += 1; continue }
            if let p = w.previous(before: i) {
                let previous = w.lower(p)
                let pause = w.tokens[p].trail.contains(",") || w.tokens[p].trail.contains(";")
                guard clauseStarters.contains(previous) || pause || pastTimeNouns.contains(previous) || previous == "yesterday" || previous == "ago" || previous == "today" else {
                    i = found.end + 1; continue
                }
            }
            guard let v = w.next(after: found.end, skipping: frequencyAdverbs) else { break }
            fixVerb(v, person: found.person, in: w, pastContext: pastContext, subjunctive: subjunctive)
            i = v + 1
        }
    }

    private static func fixVerb(_ v: Int, person: Person, in w: Work, pastContext: Bool, subjunctive: Bool) {
        let word = w.lower(v)
        let pastReason = "yesterday · ago · last ~ 같은 과거 표현이 있어서 과거형으로 써요."

        // 과거분사만 혼자 쓴 경우: I seen → I saw
        if let base = EngVerbs.ppOnlyBase(word) {
            let past = base == "be" ? (person == .plural ? "were" : "was") : EngVerbs.past(base)
            w.replace(v, with: past, reason: "과거분사(\(word))는 혼자서 동사로 못 써요. 과거형(\(past))을 쓰거나 have + 과거분사로 써요.")
            return
        }

        if pastContext {
            switch word {
            case "am", "is": w.replace(v, with: "was", reason: pastReason)
            case "are": w.replace(v, with: person == .plural ? "were" : "was", reason: pastReason)
            case "do", "does": w.replace(v, with: "did", reason: pastReason)
            case "don't", "doesn't": w.replace(v, with: "didn't", reason: pastReason)
            case "can": w.replace(v, with: "could", reason: pastReason)
            case "have", "has":
                if let n = w.next(after: v, skipping: skipAdverbs), let (base, kind) = EngVerbs.analyze(w.lower(n)), kind == .pp || kind == .pastAndPP {
                    w.remove(v, reason: "과거 시점 표현(yesterday, ago …)은 현재완료와 함께 쓰지 않아요.")
                    w.replace(n, with: EngVerbs.past(base), reason: "과거시제로 써요.")
                } else {
                    w.replace(v, with: "had", reason: pastReason)
                }
            default:
                let base: String?
                if EngVerbs.isBaseVerb(word) { base = word } else if let (b, kind) = EngVerbs.analyze(word), kind == .third { base = b } else { base = nil }
                guard let base, !EngVerbs.modals.contains(base), base != "be", EngVerbs.pastToBase[word] == nil else { return }
                let past = EngVerbs.past(base)
                if past != word { w.replace(v, with: past, reason: pastReason) }
            }
            return
        }

        switch person {
        case .third:
            switch word {
            case "don't": w.replace(v, with: "doesn't", reason: "주어가 3인칭 단수라서 doesn't를 써요.")
            case "have": w.replace(v, with: "has", reason: "주어가 3인칭 단수라서 has를 써요.")
            case "do": w.replace(v, with: "does", reason: "주어가 3인칭 단수라서 does를 써요.")
            case "are", "am": w.replace(v, with: "is", reason: "주어가 3인칭 단수라서 is를 써요.")
            case "were" where !subjunctive: w.replace(v, with: "was", reason: "주어가 3인칭 단수라서 was를 써요.")
            default:
                guard EngVerbs.isBaseVerb(word), !EngVerbs.modals.contains(word), word != "be",
                      EngVerbs.past(word) != word, EngVerbs.pastToBase[word] == nil else { return }
                w.replace(v, with: EngVerbs.third(word), reason: "주어가 3인칭 단수라서 현재형 동사에 -s / -es를 붙여요.")
            }
        case .first, .plural:
            let subjectName = person == .first ? "I" : "복수 주어"
            switch word {
            case _ where (word == "is" || word == "am") && person == .plural: w.replace(v, with: "are", reason: "주어가 복수라서 are를 써요.")
            case _ where (word == "is" || word == "are") && person == .first: w.replace(v, with: "am", reason: "주어가 I라서 am을 써요.")
            case "was" where person == .plural: w.replace(v, with: "were", reason: "주어가 복수라서 were를 써요.")
            case "doesn't": w.replace(v, with: "don't", reason: "\(subjectName) 뒤에는 don't를 써요.")
            case "has": w.replace(v, with: "have", reason: "\(subjectName) 뒤에는 have를 써요.")
            case "does": w.replace(v, with: "do", reason: "\(subjectName) 뒤에는 do를 써요.")
            default:
                guard let (base, kind) = EngVerbs.analyze(word), kind == .third, base != "be" else { return }
                w.replace(v, with: base, reason: "주어가 3인칭 단수가 아니라서 -s를 붙이지 않아요.")
            }
        }
    }

    private static func fixBeBase(_ w: Work) {
        let triggers: Set<String> = ["am", "is", "are", "was", "were", "i'm", "you're", "we're", "they're", "he's", "she's", "it's"]
        for i in 0..<w.count where triggers.contains(w.lower(i)) {
            guard let j = w.next(after: i, skipping: ["not", "always", "really", "just", "still", "also", "never"]) else { continue }
            let word = w.lower(j)
            guard EngVerbs.isBaseVerb(word), !beFriendly.contains(word), !EngVerbs.modals.contains(word),
                  !EngVerbs.ppForms(word).contains(word), EngVerbs.pastToBase[word] == nil, word != "be" else { continue }
            w.replace(j, with: EngVerbs.ing(word), reason: "be동사와 동사원형은 같이 못 써요. 진행형이면 be + -ing로 써요. (또는 be를 빼고 동사만)")
        }
    }

    private static func fixPrepositions(_ w: Work) {
        for i in 0..<w.count {
            let word = w.lower(i)
            guard let j = w.next(after: i) else { continue }
            let next = w.lower(j)
            switch (word, next) {
            case ("discuss", "about"), ("discussed", "about"), ("discussing", "about"), ("discusses", "about"):
                w.remove(j, reason: "discuss는 타동사라 about 없이 바로 목적어를 써요.")
            case ("marry", "with"), ("married", "with"), ("marries", "with"):
                if let p = w.previous(before: i), beForms.contains(w.lower(p)) || ["get", "got", "gets", "getting"].contains(w.lower(p)) {
                    w.replace(j, with: "to", reason: "'~와 결혼한 상태이다'는 be married to로 써요.")
                } else {
                    w.remove(j, reason: "marry는 타동사라 with 없이 바로 사람을 써요.")
                }
            case _ where ["explain", "explained", "explains"].contains(word) && ["me", "him", "her", "us", "them"].contains(next):
                w.replace(j, with: "to " + w.tokens[j].core, reason: "explain은 4형식으로 못 써서 'explain (내용) to + 사람'으로 써요.")
            case _ where ["listen", "listened", "listening", "listens"].contains(word)
                && ["music", "me", "him", "her", "us", "them", "it", "the", "this", "my", "your", "his", "songs", "radio"].contains(next):
                w.replace(j, with: "to " + w.tokens[j].core, reason: "listen은 자동사라 'listen to + 대상'으로 써요.")
            case ("reach", "to"), ("reached", "to"), ("enter", "into"), ("entered", "into"), ("attend", "to"), ("resemble", "with"):
                w.remove(j, reason: "타동사(\(word))라서 전치사 없이 바로 목적어를 써요.")
            case ("arrive", "to"), ("arrived", "to"), ("arrives", "to"):
                w.replace(j, with: "at", reason: "arrive는 at(좁은 장소) / in(넓은 장소)과 함께 써요.")
            case (_, "to") where ["go", "goes", "went", "going", "come", "comes", "came", "coming", "get", "got", "return", "returned"].contains(word):
                if let k = w.next(after: j), ["home", "there", "here", "abroad", "downtown", "upstairs", "downstairs"].contains(w.lower(k)) {
                    w.remove(j, reason: "home, there, here 같은 말은 부사라서 앞에 to를 쓰지 않아요.")
                }
            case ("since", _) where Int(next) != nil:
                if let k = w.next(after: j), ["years", "months", "weeks", "days", "hours", "minutes", "year", "month", "week", "day", "hour"].contains(w.lower(k)) {
                    w.replace(i, with: "for", reason: "'~ 동안'은 for + 기간, since는 시작 시점(since 2020) 앞에 써요.")
                }
            default:
                break
            }
        }
    }

    private static func fixCapitalAndPeriod(_ w: Work) {
        guard let first = w.next(after: -1) else { return }
        let core = w.tokens[first].core
        if let letter = core.first, letter.isLowercase {
            w.tokens[first].core = letter.uppercased() + core.dropFirst()
            w.fixes.append(Fix(text: "\(core) → \(w.tokens[first].core): 문장 첫 글자는 대문자로 써요.", minor: true))
        }
        guard let last = w.previous(before: w.count) else { return }
        let trail = w.tokens[last].trail
        if !trail.contains(where: { ".?!".contains($0) }) {
            let questionStarters: Set<String> = ["what", "where", "when", "why", "who", "how", "which", "do", "does", "did", "are", "is",
                                                 "can", "could", "will", "would", "should", "have", "has", "may", "am", "were", "was"]
            let mark = questionStarters.contains(w.lower(first)) ? "?" : "."
            w.tokens[last].trail += mark
            w.fixes.append(Fix(text: "문장 끝에 \(mark == "?" ? "물음표(?)" : "마침표(.)")를 찍어요.", minor: true))
        }
    }
}

// MARK: - 영어 퀴즈

extension DoitEnglish {
    /// 내장 자료로 만든 짧은 주관식 문제 (topic: "동사", "불규칙", "단어", "어휘", "문법", "비교급", "복수" …)
    static func quiz(topic: String?) -> DoitQuizItem? {
        let t = (topic ?? "").replacingOccurrences(of: " ", with: "").lowercased()
        var kinds: [EngQuiz.Kind]
        if EngText.has(t, ["동사", "불규칙", "과거", "변화"]) { kinds = [.verb] }
        else if EngText.has(t, ["단어", "어휘", "뜻", "voca", "word"]) { kinds = [.vocab, .vocabReverse] }
        else if EngText.has(t, ["문법", "어법", "grammar"]) { kinds = [.grammar] }
        else if EngText.has(t, ["비교"]) { kinds = [.comparative] }
        else if EngText.has(t, ["복수", "명사"]) { kinds = [.plural] }
        else { kinds = [.verb, .verb, .vocab, .vocab, .vocabReverse, .grammar, .grammar, .comparative, .plural] }
        for _ in 0..<5 {
            if let kind = kinds.randomElement(), let item = EngQuiz.make(kind) { return item }
        }
        return nil
    }
}

private enum EngQuiz {
    enum Kind { case verb, vocab, vocabReverse, grammar, comparative, plural }

    /// 문제|정답(여러 개는 /)|해설
    private static let grammarRaw = """
    I look forward to (   ) you soon. (see)|seeing|look forward to의 to는 전치사라 뒤에 동명사(-ing)를 써요.
    She enjoys (   ) novels. (read)|reading|enjoy는 동명사를 목적어로 써요.
    I decided (   ) abroad. (study)|to study|decide는 to부정사를 목적어로 써요.
    He has already (   ) his homework. (finish)|finished|현재완료 have / has + 과거분사.
    If I (   ) you, I would apologize. (be)|were|가정법 과거에서 be동사는 were를 써요.
    If I had studied harder, I would have (   ) the exam. (pass)|passed|가정법 과거완료: would have + 과거분사.
    This book was (   ) by a famous writer. (write)|written|수동태 be + 과거분사 (write - wrote - written).
    The movie was so (   ) that I fell asleep. (bore)|boring|영화가 지루함을 '주는' 쪽이라 -ing를 써요.
    I was (   ) at the news. (surprise)|surprised|사람이 감정을 '느끼는' 쪽이라 과거분사를 써요.
    My mom made me (   ) my room. (clean)|clean|사역동사 make + 목적어 + 동사원형.
    I saw him (   ) the street. (cross)|cross/crossing|지각동사 see + 목적어 + 동사원형 / -ing.
    He (   ) to school every day. (go)|goes|주어가 3인칭 단수, 현재형이라 -es를 붙여요.
    The number of students (   ) increasing. (be)|is|the number of + 복수명사는 단수 동사를 써요.
    This is the house (   ) I was born. (관계부사)|where|뒤 문장이 완전하고 장소(the house)를 꾸며서 where를 써요.
    (   ) I want is a long vacation. (관계대명사)|what|선행사가 없고 '~하는 것'이라는 뜻이라 what을 써요.
    I have a friend (   ) lives in Busan. (관계대명사)|who/that|선행사가 사람이고 주격이라 who(that)를 써요.
    She is as (   ) as her mother. (tall)|tall|as ~ as 사이에는 원급을 써요.
    This box is much (   ) than that one. (heavy)|heavier|자음 + y로 끝나서 y를 i로 바꾸고 -er.
    He is the (   ) student in our class. (smart)|smartest|최상급 the + -est.
    I wish I (   ) fly. (can)|could|I wish + 과거형: 현재 이루기 어려운 소망이에요.
    I stopped (   ) because it was bad for my health. (smoke)|smoking|stop -ing: ~하던 것을 그만두다.
    Remember (   ) the door when you leave. (lock)|to lock|remember to: (앞으로) ~할 것을 기억하다.
    Do you know where she (   )? (live)|lives|간접의문문은 의문사 + 주어 + 동사 어순이고, 주어가 3인칭 단수예요.
    I will call you when I (   ) home. (get)|get|시간 부사절에서는 미래 대신 현재시제를 써요.
    He is too young (   ) a car. (drive)|to drive|too + 형용사 + to부정사: 너무 ~해서 …할 수 없다.
    It is important (   ) every day. (exercise)|to exercise|가주어 it, 진주어 to부정사.
    Never (   ) I seen such a view. (have)|have|부정어 Never가 앞에 와서 도치: Never + have + 주어 + p.p.
    """

    static func make(_ kind: Kind) -> DoitQuizItem? {
        switch kind {
        case .verb:
            let verbs = EngVerbs.irregular.values.filter { $0.base != "be" && !($0.past == [$0.base] && $0.pp == [$0.base]) }
            guard let verb = verbs.randomElement() else { return nil }
            let askPP = Bool.random()
            let forms = "\(verb.base) - \(verb.past.joined(separator: "/")) - \(verb.pp.joined(separator: "/")) (\(verb.meaning))"
            return DoitQuizItem(question: "\(verb.base)(\(verb.meaning))의 \(askPP ? "과거분사는" : "과거형은")?",
                                answers: askPP ? verb.pp : verb.past, explanation: forms)
        case .vocab:
            guard let (word, meanings) = EngWords.quizPairs.randomElement(), !meanings.isEmpty else { return nil }
            return DoitQuizItem(question: "\(word)의 뜻은?", answers: meanings, explanation: "\(word): \(EngWords.dictionary[word] ?? meanings.joined(separator: ", "))")
        case .vocabReverse:
            guard let (word, meanings) = EngWords.quizPairs.randomElement(), let first = meanings.first else { return nil }
            return DoitQuizItem(question: "'\(first)'을(를) 영어 단어로 쓰면? (첫 글자: \(word.prefix(1)))",
                                answers: [word], explanation: "\(word): \(EngWords.dictionary[word] ?? first)")
        case .grammar:
            let rows = grammarRaw.split(separator: "\n").map { $0.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) } }
            guard let row = rows.filter({ $0.count == 3 }).randomElement() else { return nil }
            return DoitQuizItem(question: "빈칸에 알맞은 말은?\n\(row[0])", answers: row[1].components(separatedBy: "/"), explanation: row[2])
        case .comparative:
            let candidates = EngAdjectives.common.filter {
                EngAdjectives.irregular[$0] == nil && !EngAdjectives.compare($0).comparative.hasPrefix("more")
            }
            guard let adjective = candidates.randomElement() else { return nil }
            let forms = EngAdjectives.compare(adjective)
            let askSuperlative = Bool.random()
            return DoitQuizItem(question: "\(adjective)의 \(askSuperlative ? "최상급" : "비교급")은?",
                                answers: [askSuperlative ? forms.superlative : forms.comparative],
                                explanation: "\(adjective) - \(forms.comparative) - \(forms.superlative): \(forms.rule)")
        case .plural:
            guard let (singular, plural) = EngNouns.irregularPlural.filter({ $0.key != $0.value && $0.key.count <= 8 && $0.value != $0.key + "s" }).randomElement() else { return nil }
            return DoitQuizItem(question: "\(singular)의 복수형은?", answers: [plural], explanation: "\(singular) → \(plural): \(EngNouns.plural(singular).rule)")
        }
    }
}

// MARK: - 두잇 AI 지식 검색용

extension DoitEnglish {
    /// 문법 노트와 숙어 전체 (이름들, 설명)
    static var knowledgeEntries: [(names: [String], body: String)] {
        EngGrammar.topics.map { ([$0.title] + $0.keywords, $0.body) }
            + EngIdioms.idioms.map { ([$0.display, $0.key], "\($0.display): \($0.meaning)\n예문: \($0.example) — \($0.exampleKo)" + ($0.note.isEmpty ? "" : "\n주의: \($0.note)")) }
    }
}

// MARK: - 오답노트 해설용 (영어 문제의 정답·선택지 단어)

extension DoitEnglish {
    private static let hintStopWords: Set<String> = [
        "the", "and", "for", "are", "was", "were", "you", "your", "this", "that", "with", "have", "has", "had", "not", "but",
        "his", "her", "she", "they", "them", "what", "which", "who", "from", "can", "will", "there", "their", "its", "our", "one"
    ]

    /// 뜻을 보여 줄 만한 영어 단어들 (세 글자 이상, 흔한 기능어 빼고)
    static func wordsForHints(in text: String) -> [String] {
        EngText.englishWords(in: text).filter { $0.count >= 3 && !hintStopWords.contains($0) && !EngText.lookupStopWords.contains($0) }
    }

    /// 단어 한 줄 설명 (내장 사전 · 동사 변화). 모르면 nil
    static func wordNote(_ word: String) -> String? {
        EngWords.meaningReply(word.lowercased())?
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "\n", with: " · ")
    }
}

// MARK: - 한국어 → 영어 낱말 ("사과를 영어로", "행복하다 영어로 뭐야")

extension DoitEnglish {
    /// 내장 단어장·동사 사전을 거꾸로 찾아서 영어 낱말로. "영어로"를 묻는 말이 아니면 nil
    static func toEnglish(_ text: String) -> String? {
        let pattern = #"^\s*['"‘“]?(.+?)['"’”]?\s*(?:이라는\s*말|라는\s*말)?\s*(?:영어로|영단어로|영어\s*단어로|영어\s*단어)\s*(?:는|은)?\s*(?:뭐야|뭐지|뭐예요|뭐라고\s*해|뭐라고\s*하지|뭐라고|알려\s*줘|해\s*줘|써\s*줘|말해\s*줘|번역해\s*줘|어떻게\s*(?:써|말해)\??)?\s*[?？.!]*\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(m.range(at: 1), in: text) else { return nil }
        let whole = String(text[range]).trimmingCharacters(in: .whitespaces)
        guard !whole.isEmpty, EngText.hasHangul(whole) else { return nil }
        // "고양이" → 그대로 먼저, 없으면 조사 뗀 말 ("사과를" → 사과)
        let stripped = DoitRelevance.stripParticle(whole)
        let word = englishWords(forKorean: whole).isEmpty && stripped != whole ? stripped : whole
        if word.split(separator: " ").count >= 3 {
            return "문장 번역은 아직 잘 못 해요. 낱말 하나씩 물어봐 주세요. 예: \"사과 영어로\""
        }
        let found = englishWords(forKorean: word)
        guard let first = found.first else {
            return "'\(word)'에 맞는 영어 낱말은 내장 단어장에 없어요. 다른 말로 물어보거나 영어 낱말의 뜻을 물어봐 주세요."
        }
        var line = "**\(word)** → **\(first)**"
        if found.count > 1 { line += "\n비슷한 말: " + found.dropFirst().prefix(2).joined(separator: ", ") }
        return line
    }

    /// 한국어 뜻으로 영어 낱말 찾기 (뜻이 똑같은 것 먼저, 그다음 '행복하다' ↔ '행복한'처럼 줄기가 같은 것)
    static func englishWords(forKorean korean: String) -> [String] {
        let key = korean.replacingOccurrences(of: " ", with: "")
        let keyStem = koreanStem(key)
        var exact: [String] = [], similar: [String] = []
        var pool: [(String, String)] = EngWords.dictionary.map { ($0.key, $0.value) }
        pool += EngVerbs.irregular.map { ($0.key, $0.value.meaning) }
        pool += EngVerbs.regular.map { ($0.key, $0.value) }
        for (english, meaning) in pool.sorted(by: { $0.0 < $1.0 }) {
            let parts = meaning.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
                .components(separatedBy: CharacterSet(charactersIn: ",;/·")).map { $0.replacingOccurrences(of: " ", with: "") }.filter { !$0.isEmpty }
            if parts.contains(key) {
                if !exact.contains(english) { exact.append(english) }
            } else if keyStem.count >= 1, parts.contains(where: { koreanStem($0) == keyStem }), !similar.contains(english) {
                similar.append(english)
            }
        }
        // 짧은 낱말 먼저 (기본 낱말)
        return (exact.sorted { $0.count < $1.count } + similar.sorted { $0.count < $1.count })
    }

    /// '행복하다', '행복한' → '행복하', '빠르다', '빠른' → '빠르', '작은' → '작'
    private static func koreanStem(_ word: String) -> String {
        var w = word
        for ending in ["스럽다", "스러운", "적인", "하게", "하는", "다", "은", "는", "의"] where w.count > ending.count && w.hasSuffix(ending) {
            w.removeLast(ending.count)
            return w
        }
        // 받침 ㄴ으로 꾸미는 말 ("빠른" → "빠르", "행복한" → "행복하")
        if w.count >= 2, let last = w.last, let v = last.unicodeScalars.first?.value, (0xAC00...0xD7A3).contains(v), (v - 0xAC00) % 28 == 4,
           let plain = Unicode.Scalar(v - 4) {
            w.removeLast()
            w.append(Character(plain))
        }
        return w
    }
}


// MARK: - 과목 풀이(DoitSubjectSolve)용: 동사·형용사 변화와 내장 단어장

extension DoitEnglish {
    /// 동사 원형 ("went" → "go", "is" → "be", "plays" → "play"). 동사가 아니면 nil
    static func verbBase(_ word: String) -> String? {
        let w = word.lowercased()
        if ["am", "is", "are", "was", "were", "been", "being", "be"].contains(w) { return "be" }
        if EngVerbs.isBaseVerb(w) { return w }
        return EngVerbs.analyze(w)?.0
    }

    static func pastForms(_ base: String) -> [String] { EngVerbs.pastForms(base) }
    static func ppForms(_ base: String) -> [String] { EngVerbs.ppForms(base) }
    static func thirdPerson(_ base: String) -> String { EngVerbs.third(base) }
    static func ingForm(_ base: String) -> String { EngVerbs.ing(base) }

    /// 비교급 · 최상급 (여러 모양이면 모두)
    static func comparison(_ adjective: String) -> (comparative: [String], superlative: [String]) {
        let forms = EngAdjectives.compare(adjective.lowercased())
        let split: (String) -> [String] = { $0.components(separatedBy: " / ").map { $0.trimmingCharacters(in: .whitespaces) } }
        return (split(forms.comparative), split(forms.superlative))
    }

    /// 내장 단어장 (단어 → 뜻 글)
    static var vocabulary: [String: String] { EngWords.dictionary }

    /// 불규칙 복수형 → 단수 ("children" → "child")
    static func singular(ofIrregular plural: String) -> String? { EngNouns.pluralToSingular[plural.lowercased()] }
}
