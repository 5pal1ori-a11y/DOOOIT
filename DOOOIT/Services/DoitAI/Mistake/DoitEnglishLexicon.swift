import Foundation

// MARK: - 영어 어법 규칙용 낱말 자료 · 명사구 읽기
// - 규칙이 "확실할 때만" 걸리도록, 품사가 헷갈리는 낱말(play, watch, park …)은 명사 목록에서 일부러 뺐어요.
// - 명사의 수(단수·복수)는 이 목록에 있는 낱말만 따져요. 모르는 낱말이면 nil (규칙이 걸리지 않음)

extension DoitSentenceCheck {
    /// 주격 → 목적격, 목적격 → 주격
    static let objectCase: [String: String] = ["i": "me", "he": "him", "she": "her", "we": "us", "they": "them"]
    static let subjectCase: [String: String] = ["me": "I", "him": "he", "her": "she", "us": "we", "them": "they"]
    static let reflexives: [String: String] = ["i": "myself", "you": "yourself", "he": "himself", "she": "herself", "it": "itself",
                                               "we": "ourselves", "they": "themselves"]
    /// 사람을 가리키는 주격 대명사 (it 뺌)
    static let personSubjects: Set<String> = ["i", "you", "he", "she", "we", "they"]
    static let whWords: Set<String> = ["what", "where", "when", "why", "how", "which", "who", "whom", "whose"]
    static let prepositionWords: Set<String> = ["in", "on", "at", "with", "to", "for", "about", "of", "from", "by", "without", "between", "among",
                                                "behind", "near", "under", "beside", "toward", "towards", "into", "onto", "against", "around",
                                                "over", "through", "across", "along", "during", "inside", "outside", "above", "below", "beyond"]
    static let singularDeterminers: Set<String> = ["a", "an", "this", "that", "each", "every", "another", "one", "either", "neither"]
    static let pluralDeterminers: Set<String> = ["these", "those", "many", "few", "several", "both", "two", "three", "four", "five", "six",
                                                 "seven", "eight", "nine", "ten", "twenty", "hundred", "various", "numerous"]
    static let neutralDeterminers: Set<String> = ["the", "my", "your", "his", "her", "its", "our", "their", "some", "any", "no", "all"]
    static let negativeAdverbs: Set<String> = ["never", "hardly", "seldom", "rarely", "scarcely", "little", "barely"]

    /// 명사 (단수). 동사로 더 흔히 쓰거나 형용사와 겹치는 낱말은 넣지 않음
    static let nounWords: [String] = [
        "boy", "girl", "man", "woman", "child", "baby", "person", "friend", "student", "teacher", "doctor", "nurse", "parent", "brother",
        "sister", "mother", "father", "son", "daughter", "uncle", "aunt", "cousin", "grandmother", "grandfather", "grandparent", "neighbor",
        "classmate", "singer", "player", "artist", "writer", "actor", "scientist", "farmer", "driver", "pilot", "engineer", "lawyer",
        "soldier", "king", "queen", "prince", "princess", "kid", "lady", "gentleman", "tourist", "visitor", "customer", "worker", "member",
        "author", "poet", "painter", "musician", "chef", "dancer", "athlete", "volunteer", "patient", "officer", "president", "leader",
        "book", "pen", "pencil", "bag", "desk", "chair", "table", "door", "window", "house", "room", "car", "bike", "bicycle", "bus",
        "phone", "computer", "camera", "clock", "box", "cup", "bottle", "glass", "key", "hat", "shirt", "dress", "shoe", "sock", "coat",
        "jacket", "umbrella", "picture", "photo", "letter", "card", "gift", "toy", "ball", "doll", "robot", "machine", "bridge", "building",
        "tower", "city", "town", "village", "country", "river", "mountain", "lake", "sea", "island", "forest", "tree", "flower", "leaf",
        "garden", "street", "road", "school", "library", "museum", "hospital", "restaurant", "hotel", "station", "airport", "church",
        "apple", "banana", "orange", "egg", "cookie", "cake", "sandwich", "potato", "tomato", "carrot", "dog", "cat", "bird", "horse",
        "cow", "pig", "rabbit", "lion", "tiger", "elephant", "monkey", "bear", "wolf", "fox", "mouse", "animal", "insect", "bee", "ant",
        "movie", "song", "story", "novel", "poem", "game", "question", "problem", "idea", "plan", "dream", "word", "sentence", "language",
        "subject", "class", "lesson", "exam", "test", "holiday", "vacation", "trip", "party", "festival", "concert", "event", "day", "week",
        "month", "year", "hour", "minute", "second", "morning", "afternoon", "evening", "night", "season", "century", "moment", "place",
        "page", "chapter", "magazine", "newspaper", "ticket", "seat", "bed", "sofa", "bench", "wall", "floor", "roof", "kitchen",
        "bathroom", "office", "shop", "store", "market", "company", "factory", "farm", "zoo", "beach", "planet", "star", "earthquake",
        "accident", "result", "reason", "rule", "law", "fact", "country", "culture", "tradition", "custom", "habit", "skill", "job",
        "experience", "example", "difference", "decision", "choice", "chance", "opportunity", "solution", "method", "way", "program",
        "website", "smartphone", "tablet", "app", "notebook", "dictionary", "eraser", "ruler", "map", "cap", "wallet", "watch",
        "ring", "necklace", "jewel", "coin", "dollar", "price", "population", "climate", "temperature", "size", "quality", "speed",
        "plant", "seed", "fruit", "vegetable", "meal", "dish", "pizza", "hamburger", "student", "team", "eye", "ear", "nose", "mouth",
        "hand", "arm", "leg", "foot", "tooth", "head", "face", "finger", "heart", "brain", "body", "voice", "symptom", "disease", "virus",
        "cell", "organ", "species", "habitat", "dinosaur", "fish", "sheep", "deer", "kilometer", "meter", "mile", "kilogram", "gram",
        "liter", "painting", "drawing", "photograph", "sculpture", "invention", "discovery", "inventor", "explorer", "researcher",
        "mind", "life", "wife", "knife", "shelf", "thief", "hero", "piano", "radio", "video", "child", "goose", "ox", "crisis",
        "phenomenon", "criterion", "medium", "datum", "analysis", "hypothesis", "thesis", "basis", "oasis", "cactus", "fungus",
        "stimulus", "nucleus", "bacterium", "teenager", "adult", "citizen", "expert", "professor", "employee", "manager", "owner",
        "passenger", "mom", "dad", "mistake", "error", "elephant", "trunk", "grade", "castle", "statue", "temple", "palace", "vase", "mailman", "fence", "gate", "pool", "beach", "desert", "jungle", "pyramid", "clothes", "jacket", "hill", "corner", "sun", "moon", "tail", "wing", "nest", "cave", "valley", "field", "pond", "hobby", "name", "address", "color", "friendship", "uniform", "dream", "audience", "crowd", "police", "people", "family", "group", "staff", "committee", "government", "jury", "band", "club"
    ]
    /// 집합명사 · 수가 정해지지 않는 명사 (규칙에서 빼요)
    static let unsureNouns: Set<String> = ["team", "class", "family", "group", "staff", "audience", "crowd", "committee", "government", "jury",
                                           "band", "club", "species", "fish", "sheep", "deer", "series", "means", "data", "media", "couple",
                                           "pair", "number", "majority", "percent", "half", "rest", "part", "kind", "sort", "type", "lot",
                                           "plenty", "total", "dozen", "variety", "range", "crew", "public", "army", "company", "aircraft"]
    /// 늘 복수인 명사
    static let pluralOnlyNouns: Set<String> = ["people", "police", "cattle", "clothes", "glasses", "scissors", "pants", "jeans", "shorts",
                                               "trousers", "goods", "belongings", "children", "men", "women", "feet", "teeth", "mice", "geese"]
    /// 셀 수 없는 명사 (단수로 받음)
    static let massNouns: Set<String> = DoitEnglish.uncountableNouns.union(["news", "mathematics", "physics", "economics", "information", "advice",
                                                                          "furniture", "homework", "luggage", "baggage", "equipment", "knowledge",
                                                                          "money", "water", "milk", "coffee", "tea", "juice", "food", "bread",
                                                                          "rice", "sugar", "salt", "paper", "time", "work", "music", "art",
                                                                          "weather", "traffic", "pollution", "electricity", "energy", "gold",
                                                                          "silver", "wood", "glass", "air", "soil", "sand", "snow", "rain",
                                                                          "love", "peace", "health", "happiness", "success", "education",
                                                                          "technology", "science", "history", "nature", "space", "evidence", "hair"])
        .subtracting(["glass", "paper", "time", "work", "fun", "rain", "snow"])

    /// 단수 → 복수 (불규칙 포함)
    static let pluralOf: [String: String] = {
        let irregular: [String: String] = [
            "man": "men", "woman": "women", "child": "children", "person": "people", "foot": "feet", "tooth": "teeth", "mouse": "mice",
            "goose": "geese", "ox": "oxen", "leaf": "leaves", "knife": "knives", "wife": "wives", "life": "lives", "wolf": "wolves",
            "shelf": "shelves", "thief": "thieves", "potato": "potatoes", "tomato": "tomatoes", "hero": "heroes", "piano": "pianos",
            "photo": "photos", "radio": "radios", "video": "videos", "zoo": "zoos", "roof": "roofs", "crisis": "crises",
            "phenomenon": "phenomena", "criterion": "criteria", "medium": "media", "datum": "data", "analysis": "analyses",
            "hypothesis": "hypotheses", "thesis": "theses", "basis": "bases", "oasis": "oases", "cactus": "cacti", "fungus": "fungi",
            "stimulus": "stimuli", "nucleus": "nuclei", "bacterium": "bacteria", "fish": "fish", "sheep": "sheep", "deer": "deer",
            "species": "species", "gentleman": "gentlemen", "policeman": "policemen"
        ]
        var map: [String: String] = [:]
        for n in nounWords {
            if let p = irregular[n] { map[n] = p; continue }
            if ["s", "x", "z", "ch", "sh"].contains(where: n.hasSuffix) { map[n] = n + "es"; continue }
            if n.hasSuffix("y"), let c = n.dropLast().last, !"aeiou".contains(c) { map[n] = String(n.dropLast()) + "ies"; continue }
            map[n] = n + "s"
        }
        return map
    }()
    static let singularOf: [String: String] = {
        var map: [String: String] = [:]
        for (s, p) in pluralOf where s != p { map[p] = s }
        return map
    }()

    /// 명사의 수: true 복수, false 단수(셀 수 없는 명사 포함), nil 모름
    static func nounPlural(_ word: String) -> Bool? {
        let w = word.lowercased()
        if unsureNouns.contains(w) { return nil }
        if pluralOnlyNouns.contains(w) { return true }
        if massNouns.contains(w) { return false }
        if let s = singularOf[w] { return unsureNouns.contains(s) ? nil : true }
        if pluralOf[w] != nil { return pluralOf[w] == w ? nil : false }
        return nil
    }

    /// 셀 수 있는 명사의 단수 (a book, one boy …)
    static func isCountableSingular(_ word: String) -> Bool {
        let w = word.lowercased()
        guard let p = pluralOf[w], p != w, !unsureNouns.contains(w), !massNouns.contains(w) else { return false }
        return true
    }

    static func isNoun(_ word: String) -> Bool { nounPlural(word) != nil || pluralOf[word] != nil || massNouns.contains(word) }

    /// 형용사 (명사 앞에 오는 꾸밈말)
    static let adjectiveWords: Set<String> = Set(DoitEnglish.commonAdjectives).union([
        "beautiful", "interesting", "important", "famous", "different", "difficult", "expensive", "delicious", "wonderful", "careful",
        "useful", "dangerous", "popular", "special", "favorite", "best", "worst", "better", "worse", "own", "other", "same", "whole",
        "first", "last", "next", "only", "main", "local", "foreign", "public", "real", "true", "honest", "polite", "excellent", "perfect",
        "terrible", "amazing", "exciting", "boring", "surprising", "tired", "hungry", "huge", "little", "red", "blue", "green", "yellow",
        "white", "black", "brown", "pink", "gray", "purple", "golden", "wooden", "modern", "ancient", "traditional", "natural", "national",
        "international", "social", "human", "elderly", "fresh", "free", "open", "full", "empty", "lovely", "creative", "smart", "nervous",
        "comfortable", "convenient", "necessary", "possible", "impossible", "healthy", "serious", "simple", "certain", "various", "huge"
    ])
    static func isAdjectiveLike(_ word: String) -> Bool {
        if adjectiveWords.contains(word) || degreeForms[word] != nil { return true }
        return false
    }

    /// 거의 늘 동사로 쓰는 원형 (명사·형용사와 잘 안 겹침)
    static let actionVerbs: Set<String> = ["go", "come", "eat", "see", "meet", "make", "take", "give", "say", "tell", "buy", "find", "get",
                                           "keep", "bring", "write", "sing", "become", "begin", "forget", "choose", "speak", "teach",
                                           "think", "send", "spend", "wear", "win", "lose", "wake", "know", "understand", "finish",
                                           "enjoy", "solve", "explain", "protect", "improve", "learn", "listen", "prepare", "borrow",
                                           "lend", "arrive", "invite", "apply", "wash", "catch", "sit", "swim", "play", "study", "dance",
                                           "watch", "walk", "talk", "sleep", "cook", "wait", "draw", "ride", "fly", "cry", "laugh", "jump",
                                           "climb", "sell", "drive", "visit", "travel", "stay", "move", "carry", "throw", "build",
                                           "paint", "plant", "help", "run", "drink", "leave", "open", "close", "try", "ask", "answer",
                                           "call", "like", "love", "want", "need", "live", "work", "smile", "feel", "worry", "wonder",
                                           "fall", "fix", "repair", "check", "enter", "steal", "break", "hide", "grow", "save", "turn",
                                           "push", "pull", "kick", "hit", "join", "exercise", "practice", "shout", "agree", "follow",
                                           "remember", "believe", "hope", "decide", "change", "use"]
    /// 명사로도 아주 흔한 동사 원형 (전치사 뒤 "for help"처럼 명사일 수 있음)
    static let nounishVerbs: Set<String> = ["play", "study", "dance", "watch", "walk", "talk", "sleep", "cook", "wait", "draw", "ride", "fly",
                                            "cry", "laugh", "jump", "climb", "drive", "visit", "travel", "stay", "move", "help", "run",
                                            "drink", "leave", "open", "close", "try", "answer", "call", "like", "love", "want", "need",
                                            "live", "work", "smile", "feel", "worry", "wonder", "fall", "fix", "repair", "check", "break",
                                            "turn", "push", "pull", "kick", "hit", "exercise", "practice", "shout", "hope", "change", "use",
                                            "swim", "plant", "paint", "wash", "catch", "sit", "act", "set", "cut", "put", "read", "show"]

    /// 동사 모양인지 (정형 동사: be·조동사·3인칭·과거·현재 원형) — 절이 시작되는지 볼 때
    static func isFiniteVerb(_ w: String) -> Bool {
        if beForms.contains(w) || modals.contains(w) { return true }
        if ["has", "have", "had", "do", "does", "did", "don't", "doesn't", "didn't", "can't", "won't", "cannot", "isn't", "aren't", "wasn't", "weren't"].contains(w) { return true }
        if isThirdForm(w) || isPastOnly(w) { return true }
        if let b = base(w), b != w, DoitEnglish.pastForms(b).contains(w) { return true }
        return false
    }

    // MARK: 명사구

    struct NounPhrase {
        let start: Int
        let head: Int
        /// 명사구 다음 낱말 번호
        let end: Int
        /// 복수인지 (nil: 모름)
        let plural: Bool?
        let hasDeterminer: Bool
    }

    /// i에서 시작하는 명사구: (한정사) (형용사 …) 명사 (명사)
    /// - 한정사가 없으면 bare: true일 때만 (복수·셀 수 없는 명사)
    static func nounPhrase(_ ws: Words, at i: Int, bare: Bool = false) -> NounPhrase? {
        var j = i
        var detPlural: Bool? = nil
        var hasDet = false
        let d = ws.at(j)
        if singularDeterminers.contains(d) { detPlural = false; hasDet = true; j += 1 }
        else if pluralDeterminers.contains(d) || (Int(d) ?? 0) >= 2 { detPlural = true; hasDet = true; j += 1 }
        else if neutralDeterminers.contains(d) { hasDet = true; j += 1 }
        guard hasDet || bare else { return nil }
        // 꾸밈말: 부사 very · 형용사 · 최상급 most + 형용사
        var count = 0
        while count < 4, j < ws.w.count, !(j > i && ws.comma[j - 1]) {
            let t = ws.at(j)
            guard ["very", "really", "most", "more", "quite"].contains(t) || isAdjectiveLike(t) && !isNoun(t) else { break }
            j += 1; count += 1
        }
        let headWord = ws.at(j)
        guard isNoun(headWord) else { return nil }
        // 이름 같은 대문자 낱말이 끼면 (The United States) 모름
        if j < ws.raw.count, j > 0, ws.raw[j].first?.isUppercase == true { return nil }
        var head = j
        // 명사 + 명사 (school bus): 뒤 낱말이 동사로도 쓰이면 붙이지 않음
        while isNoun(ws.at(head + 1)), base(ws.at(head + 1)) == nil, !ws.comma[head] { head += 1 }
        var plural = nounPlural(ws.w[head])
        if let dp = detPlural, let p = plural, dp != p {
            // 한정사와 명사의 수가 다르면 (this books) 명사구로 보지 않음 — 다른 규칙이 따짐
            return nil
        }
        if plural == nil, let dp = detPlural, !unsureNouns.contains(ws.w[head]) { plural = dp }
        if !hasDet, plural == false, !massNouns.contains(ws.w[head]) { return nil }
        return NounPhrase(start: i, head: head, end: head + 1, plural: plural, hasDeterminer: hasDet)
    }

    /// 느슨한 명사구 (한정사 + 꾸밈말 + 아무 명사): 수식어구처럼 수를 따지지 않는 곳에서만
    static func looseNounPhrase(_ ws: Words, at i: Int) -> Int? {
        if let np = nounPhrase(ws, at: i, bare: true) { return np.end }
        let d = ws.at(i)
        guard singularDeterminers.contains(d) || pluralDeterminers.contains(d) || neutralDeterminers.contains(d) else { return nil }
        var j = i + 1
        while isAdjectiveLike(ws.at(j)) && !isNoun(ws.at(j)) { j += 1 }
        let h = ws.at(j)
        guard h.count >= 2, h.allSatisfy(\.isLetter), !isFiniteVerb(h), !prepositionWords.contains(h), base(h) == nil || isNoun(h),
              !["and", "or", "but", "who", "which", "that", "to", "not"].contains(h), j > i, !ws.comma[j - 1] else { return nil }
        return j + 1
    }

    /// 사람 이름처럼 보이는 대문자 낱말 (단어장에 없고 -s로 끝나지 않음)
    static func looksLikeName(_ ws: Words, _ i: Int) -> Bool {
        guard i < ws.raw.count else { return false }
        let raw = ws.raw[i], w = ws.w[i]
        guard raw.count >= 2, raw.first?.isUppercase == true, raw.allSatisfy({ $0.isLetter }), !w.hasSuffix("s") else { return false }
        if ["mr", "mrs", "ms", "dr"].contains(w) { return false }
        let common: Set<String> = ["here", "there", "then", "now", "today", "tomorrow", "yesterday", "please", "let", "all", "both", "many",
                                   "some", "few", "most", "several", "each", "every", "never", "always", "often", "usually", "sometimes",
                                   "just", "only", "also", "even", "still", "soon", "again", "first", "finally", "so", "but", "and", "or",
                                   "if", "because", "though", "although", "while", "as", "once", "after", "before", "when", "since",
                                   "until", "cattle", "data", "media", "staff", "everyone", "everybody", "nobody", "someone", "anyone",
                                   "nothing", "something", "everything", "none", "no", "yes", "not", "maybe", "perhaps", "however",
                                   "japanese", "chinese", "english", "french", "korean", "spanish", "german", "british", "dutch", "swiss",
                                   "vietnamese", "portuguese", "american", "italian", "russian", "indian", "thai", "people", "children"]
        if common.contains(w) || prepositionWords.contains(w) || ["to", "a", "an", "the", "not", "very", "too", "than", "like", "please", "thank", "hello", "hi", "dear", "oh", "wow", "well"].contains(w) || whWords.contains(w) || subjectPronouns.contains(w) || objectPronouns.contains(w) { return false }
        if w.hasSuffix("ese") || w.hasSuffix("ish") || w.hasSuffix("ch") || w.hasSuffix("ly") { return false }
        if DoitEnglish.vocabulary[w] != nil || isNoun(w) || base(w) != nil || adjectiveWords.contains(w) { return false }
        if singularDeterminers.contains(w) || pluralDeterminers.contains(w) || neutralDeterminers.contains(w) { return false }
        return true
    }

    /// 주어 자리 (문장 처음 · 쉼표 뒤 · 접속사 뒤)
    static func clauseStarts(_ ws: Words) -> [Int] {
        let openers: Set<String> = ["if", "when", "because", "before", "after", "so", "but", "while", "though", "although", "until", "since", "unless"]
        return ws.w.indices.filter { i in i == 0 || openers.contains(ws.w[i - 1]) && (i == 1 || ws.comma[i - 2]) }
    }

    /// 정형 동사의 수: true 복수형(are · have · 원형), false 단수형(is · has · -s), nil 둘 다(과거 · 조동사)
    static func verbNumber(_ v: String) -> Bool? {
        switch v {
        case "is", "was", "has", "does", "doesn't", "isn't", "wasn't": return false
        case "are", "were", "have", "do", "don't", "aren't", "weren't": return true
        default: break
        }
        if isThirdForm(v) { return false }
        return nil
    }

    /// 복수 ↔ 단수 동사로 바꾸기
    static func flipNumber(_ v: String) -> String? {
        let map = ["is": "are", "are": "is", "was": "were", "were": "was", "has": "have", "have": "has", "does": "do", "do": "does",
                   "doesn't": "don't", "don't": "doesn't", "isn't": "aren't", "aren't": "isn't", "wasn't": "weren't", "weren't": "wasn't"]
        if let m = map[v] { return m }
        if isThirdForm(v) { return base(v) }
        if isPlainBase(v) { return DoitEnglish.thirdPerson(v) }
        return nil
    }

    /// 문장 끝 · 쉼표 · 접속사 자리인지 (구가 거기서 끝나는지)
    static func endsPhrase(_ ws: Words, _ i: Int) -> Bool {
        i >= ws.w.count || (i > 0 && ws.comma[i - 1]) || ["and", "but", "or", "so", "because", "when", "if", "while", "although", "though", "before", "after"].contains(ws.at(i))
    }

    /// -ly 부사 → 형용사 (happily → happy)
    static func adjectiveOfAdverb(_ w: String) -> String? {
        guard w.hasSuffix("ly"), w.count > 4 else { return nil }
        let stem = String(w.dropLast(2))
        let candidates = [stem, stem.hasSuffix("i") ? String(stem.dropLast()) + "y" : stem, stem + "e", stem.hasSuffix("al") ? stem : stem,
                          w.hasSuffix("ically") ? String(w.dropLast(4)) : stem, w.hasSuffix("bly") ? String(w.dropLast(1)) + "e" : stem]
        for c in candidates where adjectiveWords.contains(c) || ["sad", "glad", "angry", "happy", "nervous", "quiet", "strange", "sweet",
                                                                   "soft", "delicious", "wonderful", "terrible", "beautiful", "nice", "bad", "calm",
                                                                   "gentle", "comfortable", "perfect", "serious", "honest", "polite", "rude",
                                                                   "careful", "easy", "quick", "slow", "brave", "proud", "safe", "warm"].contains(c) {
            return c
        }
        return nil
    }
}
