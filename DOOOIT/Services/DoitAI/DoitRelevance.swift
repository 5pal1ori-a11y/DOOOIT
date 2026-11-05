import Foundation

/// 모티 AI 답이 질문에서 벗어나지 않게 (외부 AI 없이)
/// - 한국어 조사 떼기: 받침에 맞는 조사만 뗌 ("수행평가" → 그대로, "수학을" → "수학")
/// - 알 수 없는 것 (실시간 정보·개인 정보·시험에 나올 문제)은 짐작하지 않고 짧게 모른다고
/// - 과목 이름만 ("수학"), 부탁말만 ("알려줘", "설명해줘"), 기호만 ("?") 보낸 말은 짧게 되묻기
/// - 모르는 질문은 질문 낱말을 넣어 짧게 모른다고 하고 되묻기
/// - 답이 질문의 핵심 낱말을 얼마나 담았는지 (더 알맞은 개념이 있으면 그걸로)
enum DoitRelevance {
    struct Guard {
        var text: String
        var suggestions: [String] = []
        /// 모델이 있으면 모델(인터넷 검색)이 대신 답해도 되는지 (실시간 정보 등)
        var modelMayAnswer = false
    }

    // MARK: - 한국어 조사

    /// 글자에 받침이 있는지 (한글 음절이 아니면 nil)
    static func batchim(_ ch: Character) -> Int? {
        guard let v = ch.unicodeScalars.first?.value, ch.unicodeScalars.count == 1, (0xAC00...0xD7A3).contains(v) else { return nil }
        return Int((v - 0xAC00) % 28)
    }

    /// 앞 글자 받침에 맞는 조사인지 ("수행평가"의 '가'는 '평' 뒤라 조사가 아님)
    static func particleFits(_ particle: String, after ch: Character) -> Bool {
        guard let final = batchim(ch) else { return true }
        switch particle {
        case "이", "은", "을", "과", "으로", "이랑", "이야", "이란", "이라는", "이라고", "이고", "이나", "이면", "이에요", "이며", "이든", "이다":
            return final != 0
        case "가", "는", "를", "와", "랑", "야", "란", "라는", "라고", "고", "나", "면", "예요", "며", "든", "다":
            return final == 0
        case "로":
            return final == 0 || final == 8
        default:
            return true
        }
    }

    /// 낱말 끝소리에 받침이 있는지 (has), 그 받침이 ㄹ인지 (rieul). 한글이 아니면 읽는 소리로 짐작
    /// (숫자: 1 일·3 삼·6 육·7 칠·8 팔·0 영은 받침 / 영어 약자: L 엘·M 엠·N 엔·R 알은 받침 / 영어 낱말: m·n·ng·l·k·p·b로 끝나면 받침)
    static func finalSound(_ word: String) -> (has: Bool, rieul: Bool) {
        let core = word.trimmingCharacters(in: CharacterSet(charactersIn: "'\"“”‘’*()[] .,!?~"))
        guard let last = core.last else { return (false, false) }
        if let final = batchim(last) { return (final != 0, final == 8) }
        if last.isNumber {
            switch last {
            case "1", "7", "8": return (true, true)
            case "0", "3", "6": return (true, false)
            default: return (false, false)
            }
        }
        guard last.isASCII, last.isLetter else { return (false, false) }
        let letters = core.reversed().prefix { $0.isASCII && $0.isLetter }.reversed()
        let tail = String(letters)
        // 대문자 약자 (AI, DNA, GPS): 마지막 글자 이름으로
        if tail.count <= 5, tail == tail.uppercased() {
            switch last {
            case "L", "R": return (true, true)
            case "M", "N": return (true, false)
            default: return (false, false)
            }
        }
        let lower = tail.lowercased()
        if lower.hasSuffix("le") || lower.hasSuffix("l") { return (true, true) }
        if lower.hasSuffix("m") || lower.hasSuffix("n") || lower.hasSuffix("ng") || lower.hasSuffix("k") || lower.hasSuffix("ck")
            || lower.hasSuffix("b") || (lower.hasSuffix("p") && !lower.hasSuffix("ph")) {
            return (true, false)
        }
        return (false, false)
    }

    /// 받침에 맞는 조사만 ("은" → 은/는, "이" → 이/가, "을" → 을/를, "과" → 과/와, "으로" → 으로/로, "이에요" → 이에요/예요, "이야", "이라고", "이랑", "이나")
    static func josa(_ word: String, _ particle: String) -> String {
        let sound = finalSound(word)
        let pairs: [String: String] = ["은": "는", "이": "가", "을": "를", "과": "와", "이에요": "예요", "이야": "야", "이라고": "라고",
                                       "이랑": "랑", "이나": "나", "이라는": "라는", "이란": "란"]
        if particle == "으로" { return sound.has && !sound.rieul ? "으로" : "로" }
        if let without = pairs[particle] { return sound.has ? particle : without }
        if let with = pairs.first(where: { $0.value == particle })?.key { return sound.has ? with : particle }
        return particle
    }

    /// 낱말 + 알맞은 조사 ("광합성" + "은" → "광합성은", "AI" + "은" → "AI는")
    static func with(_ word: String, _ particle: String) -> String { word + josa(word, particle) }

    /// 모델(모티 1·2)이 없을 때 "모티 1·2를 받으면 더 자세히 답해요"를 붙일지 (DoitAssistant가 말을 받을 때마다 알려 줌)
    static var noModel = true
    /// 모델 안내를 붙인 뒤 지난 답 수 (같은 안내를 연달아 붙이지 않게)
    static var sinceHint = 99

    /// 모르는 답 끝에 붙이는 짧은 모델 안내 (모델이 없을 때만, 여러 번 연달아 붙이지 않음)
    static func modelHint() -> String {
        sinceHint += 1
        guard noModel, sinceHint >= 4 else { return "" }
        sinceHint = 0
        return " 모티 1·2를 받으면 더 자세히 답해요."
    }

    static let particles = ["으로부터", "에서부터", "이라는", "이라고", "에서는", "으로는", "에게서", "이랑", "에서", "에게", "한테", "까지", "부터", "처럼", "보다",
                            "으로", "이란", "이야", "라는", "라고", "에는", "와", "과", "을", "를", "은", "는", "이", "가", "의", "에", "로", "도", "만", "랑", "란", "야"]

    /// 낱말 끝의 조사 하나 떼기 (받침에 맞을 때만, 두 글자 이상 남을 때만)
    static func stripParticle(_ word: String) -> String {
        for p in particles where word.count >= p.count + 2 && word.hasSuffix(p) {
            let stem = String(word.dropLast(p.count))
            guard let last = stem.last, particleFits(p, after: last) else { continue }
            return stem
        }
        return word
    }

    // MARK: - 알 수 없는 것 · 되묻기

    private static func has(_ t: String, _ words: [String]) -> Bool { words.contains { t.contains($0) } }

    /// 실시간으로 바뀌는 정보 (날씨·뉴스·주가·경기 결과…)
    private static let liveWords = ["날씨", "기온", "미세먼지", "뉴스", "속보", "주가", "주식", "코스피", "코스닥", "환율", "비트코인", "코인", "금값", "유가",
                                    "로또", "경기결과", "스코어", "골넣었", "신곡", "컴백", "출시", "개봉", "노벨상", "시청률",
                                    "유행하는", "요즘인기", "요즘핫한", "요즘뜨는", "실시간", "박스오피스", "몇대몇"]
    private static let timeWords = ["오늘", "내일", "지금", "요즘", "최근", "어제", "이번주", "다음주", "올해", "현재", "실시간", "방금", "이번"]
    /// 개념을 묻는 말 ("환율이 뭐야?"는 실시간 정보가 아니라 개념)
    private static let conceptWords = ["뜻", "이란", "개념", "설명", "원리", "이유", "왜", "정의", "역할", "종류", "특징", "어떻게생", "의미", "방법", "하는법", "쓰는법", "보는법", "읽는법"]

    /// 알 수 없거나 짧게 되물어야 하는 말이면 답 (아니면 nil)
    /// - topic: 바로 전 대화 주제 (있으면 되묻기에 씀)
    static func check(_ raw: String, topic: String? = nil) -> Guard? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = text.lowercased().replacingOccurrences(of: " ", with: "")
        let core = t.trimmingCharacters(in: CharacterSet(charactersIn: "?？!.~…ㅠㅜ"))

        // 기호만
        if core.isEmpty, !t.isEmpty, !has(t, ["ㅠ", "ㅜ"]) {
            return Guard(text: "무엇이 궁금한지 알려줄래요? 예: \"광합성이 뭐야?\", \"2x+3=11 풀어줘\"", suggestions: ["뭐 할 수 있어?"])
        }
        // 부탁말만 ("알려줘", "설명해줘", "뭐야")
        let bare = ["알려줘", "알려주세요", "알려줄래", "설명해줘", "설명해", "설명", "뭐야", "뭐지", "뭔데", "뭐임", "어떻게", "어떻게해", "어떻게해?", "가르쳐줘",
                    "말해줘", "궁금해", "질문", "질문있어", "질문할게", "물어볼게있어", "해줘", "도와줘", "도와줄래", "부탁해"]
        if bare.contains(core) {
            if let topic, !topic.isEmpty, core != "도와줘" {
                return Guard(text: "'\(topic)'에서 무엇이 궁금한지 알려줄래요?", suggestions: ["\(topic) 더 자세히 알려줘", "이걸로 퀴즈 내줘"])
            }
            return Guard(text: "무엇을 도와줄까요? 궁금한 개념이나 문제를 같이 적어 주세요. 예: \"광합성이 뭐야?\", \"2x+3=11 풀어줘\"",
                         suggestions: ["뭐 할 수 있어?", "오늘 할 일 알려줘"])
        }
        // 과목 이름만
        let subjects = ["수학", "영어", "과학", "사회", "국어", "역사", "한국사", "물리", "화학", "생물", "생명과학", "지구과학", "윤리", "도덕", "경제", "지리", "문법", "한문"]
        if subjects.contains(core) {
            return Guard(text: "\(core)에서 무엇을 도와줄까요? 개념 설명, 문제 풀이, 퀴즈 중에 골라 주세요.",
                         suggestions: ["\(core) 퀴즈 내줘", "\(core) 공부법 알려줘"])
        }
        if ["시험", "시험공부", "시험기간"].contains(core) {
            return Guard(text: "시험 이야기군요. 무엇을 도와줄까요? 시험 날짜(D-Day)를 정하거나 남은 기간에 맞는 공부 계획을 알려줄 수 있어요.",
                         suggestions: ["시험 기간 계획 어떻게 세워?", "기말고사 D-Day 12월 10일로 설정해줘"])
        }
        if ["공부", "공부해", "공부할래"].contains(core) {
            return Guard(text: "좋아요! 어떤 공부를 할까요? 타이머를 켜거나, 개념을 묻거나, 퀴즈를 풀 수 있어요.",
                         suggestions: ["25분 타이머 시작해줘", "퀴즈 내줘", "공부법 알려줘"])
        }

        let isCalc = has(t, ["계산", "구해", "이면", "일때", "할인", "몇m", "몇원"]) && t.contains(where: \.isNumber)
        let asksConcept = has(t, conceptWords) || (!has(t, timeWords) && (t.hasSuffix("뭐야") || t.hasSuffix("뭐야?") || t.hasSuffix("뭐임") || t.hasSuffix("이뭐야?")))

        // 시험에 무엇이 나올지
        if has(t, ["뭐나와", "뭐가나와", "뭐나올", "뭐가나올", "시험에나와", "시험에나올", "시험에나오", "시험문제뭐", "어떤문제나와", "무슨문제나와", "출제될"]), !has(t, ["추가", "일정"]) {
            var line = "시험에 어떤 문제가 나올지는 저도 몰라요."
            var chips = ["시험 기간 계획 어떻게 세워?"]
            if let topic, !topic.isEmpty {
                line += " 대신 '\(topic)'\(josa(topic, "은")) 핵심 개념이라 퀴즈로 한 번 확인해 두면 좋아요."
                chips = ["이걸로 퀴즈 내줘"]
            } else {
                line += " 교과서 핵심 개념과 학교 기출, 선생님이 강조한 부분을 먼저 보는 게 가장 확실해요."
            }
            return Guard(text: line, suggestions: chips)
        }

        // 실시간 정보 (날씨·뉴스·주가·경기 결과…)
        let rain = t.range(of: #"(비|눈|소나기)(가|이)?(와|오|올|내리|내려|온대)"#, options: .regularExpression) != nil && !has(t, ["이유", "원리", "왜", "과정"])
        let president = t.contains("대통령") && has(t, ["누구", "지금", "현재", "이번", "요즘"])
        let match = has(t, ["축구", "야구", "농구", "배구", "경기", "월드컵", "올림픽", "리그", "시합"]) && has(t, ["이겼", "졌", "결과", "스코어", "몇대몇", "누가", "우승"])
        let asksLive = text.contains("?") || has(t, ["알려", "어때", "뭐야", "얼마", "몇", "누구", "언제", "결과", "올까", "오나", "오니", "나와", "어떻게돼", "됐어", "줘", "궁금", "알아"])
            || liveWords.contains { t.hasSuffix($0) }
        if !isCalc, asksLive, !asksConcept || rain, rain || president || match || has(t, liveWords) {
            let word = liveWords.first { t.contains($0) } ?? (rain ? "날씨" : match ? "경기결과" : "그 소식")
            let shown = ["요즘핫한": "요즘 유행", "요즘뜨는": "요즘 유행", "유행하는": "요즘 유행", "요즘인기": "요즘 유행", "골넣었": "경기 결과", "경기결과": "경기 결과",
                         "몇대몇": "경기 결과", "실시간": "실시간 소식", "출시": "출시 소식", "개봉": "개봉 소식", "컴백": "컴백 소식", "신곡": "신곡 소식"][word] ?? word
            var line = president && liveWords.first(where: { t.contains($0) }) == nil
                ? "현재 대통령 같은 최신 정보는 제가 몰라요. 뉴스나 검색 앱에서 확인해 주세요."
                : "\(shown)처럼 실시간으로 바뀌는 정보는 제가 몰라요. 뉴스나 검색 앱에서 확인해 주세요."
            let concepts = ["환율": "환율", "주식": "주식", "주가": "주식", "인플레이션": "인플레이션", "노벨상": "노벨상"]
            if let (key, name) = concepts.first(where: { t.contains($0.key) }), !key.isEmpty {
                line += " '\(name)'의 뜻이 궁금하면 \"\(with(name, "이")) 뭐야?\"라고 물어봐 주세요."
            }
            return Guard(text: line, modelMayAnswer: true)
        }

        // 제가 도와줄 수 없는 일 (코딩·게임 공략·맛집 추천·알람): 짧게 솔직하게, 대신 할 수 있는 일을 알려 줌
        if let scope = outOfScope(t) { return scope }

        // 개인 정보 (내 생일·친구 전화번호·우리 학교 급식…)
        let owners = ["내", "나의", "제", "우리", "엄마", "아빠", "친구", "선생님", "쌤", "동생", "형", "누나", "언니", "오빠", "할머니", "할아버지"]
        let personal = ["생일", "전화번호", "번호", "주소", "성적", "점수", "등수", "1등", "키", "몸무게", "급식", "시간표", "이름", "어디있", "어딨", "어디야", "비밀번호", "혈액형", "mbti", "몇살", "나이"]
        let asks = text.contains("?") || has(t, ["뭐야", "뭐지", "언제야", "언제지", "어디", "알아", "몇이야", "몇점", "누구", "알려줘", "알려", "몇", "뭐였"])
        if asks, !isCalc, !has(t, ["내이름은", "기억해", "추가", "일정", "메모", "통계", "단어", "오답", "목표", "d-day", "디데이"]),
           !(t.contains("내이름") || t.contains("제이름")),
           // (남을 가리키는 말이 있으면 그쪽: "내 친구 생일" → 친구)
           let owner = (owners.dropFirst(3).map { $0 } + owners.prefix(3)).first(where: { o in text.range(of: #"(^|\s)"# + o + #"(\s|$|의|가|이|는|은|님)"#, options: .regularExpression) != nil || t.hasPrefix(o) }),
           let thing = personal.first(where: { t.contains($0) }) {
            let mine = ["내", "나의", "제"].contains(owner)
            let shown = text.range(of: thing, options: .caseInsensitive).map { String(text[$0]) } ?? thing
            if mine {
                let label = thing.hasPrefix("어디") || thing == "어딨" ? "그건" : with(shown, "은")
                let thingWord = thing.hasPrefix("어디") ? "정보" : shown
                return Guard(text: "\(label) 제가 몰라요. \"기억해줘: 내 \(with(thingWord, "은")) …\"처럼 알려 주면 기억해 둘게요.",
                             suggestions: ["배운 거 보여줘"])
            }
            if owner == "우리" {
                return Guard(text: "그런 주변 정보는 제가 몰라요. 학교 알림장이나 아는 사람에게 직접 확인해 주세요.")
            }
            return Guard(text: "\(owner)의 개인 정보나 있는 곳은 제가 몰라요. 직접 물어보거나 확인해 주세요.")
        }
        return nil
    }

    /// 앱이 도와줄 수 없는 부탁 (모델이 있으면 모델이 대신 답해도 됨)
    private static func outOfScope(_ t: String) -> Guard? {
        let coding = ["코딩", "파이썬", "python", "자바스크립트", "javascript", "c언어", "c++", "html", "css", "프로그래밍", "코드짜", "코드좀짜", "코드만들",
                      "for문", "while문", "if문", "앱만드는법", "앱개발"]
        if has(t, coding) {
            return Guard(text: "코딩은 아직 제가 도와줄 수 없어요. 대신 수학·영어·과학·사회 공부랑 일정·타이머는 바로 도와줄게요.",
                         suggestions: ["뭐 할 수 있어?"], modelMayAnswer: true)
        }
        let games = ["티어", "배그", "롤토체스", "마인크래프트", "발로란트", "오버워치", "게임공략", "현질", "랭크올리", "랭겜"]
        if has(t, games) {
            return Guard(text: "게임 공략은 잘 몰라요 😅 쉬는 시간에 할 거면 타이머로 시간을 정해 두는 건 어때요?",
                         suggestions: ["10분 타이머 시작해줘"], modelMayAnswer: true)
        }
        let picks = ["맛집", "유튜브추천", "유튜버추천", "웹툰추천", "옷추천", "선물추천"]
        if has(t, picks) {
            return Guard(text: "그런 추천은 제가 잘 몰라요. 대신 점심 메뉴는 골라 줄 수 있어요!", suggestions: ["점심 메뉴 추천해줘"], modelMayAnswer: true)
        }
        if has(t, ["알람", "깨워줘", "깨워줄", "깨워주", "모닝콜"]), !has(t, ["알림"]) {
            return Guard(text: "알람은 제가 직접 맞출 수 없어요. 대신 \"내일 오전 7시 기상 추가해줘\"처럼 플랜을 넣으면 시작하기 전에 알림을 보내요.",
                         suggestions: ["내일 오전 7시 기상 추가해줘"])
        }
        return nil
    }

    /// 모르는 질문: 질문 낱말을 넣어 짧게 모른다고 하고 되묻기
    /// (앞 내용 없이 "그거", "아까 말한 거"만 있으면 무엇인지 되물음, topic: 바로 전 대화 주제)
    static func dontKnow(_ question: String, topic: String? = nil) -> Guard {
        let compact = question.replacingOccurrences(of: " ", with: "")
        if DoitDialogue.containsPronoun(question) || has(compact, ["아까", "저번에", "방금말한", "말한거", "그거말고", "이거말고"]) {
            if let topic, !topic.isEmpty {
                return Guard(text: "'\(topic)' 이야기 맞죠? 어떤 점이 궁금한지 조금 더 자세히 알려줄래요?", suggestions: ["\(topic) 더 자세히 알려줘"])
            }
            return Guard(text: "어떤 걸 말하는지 조금 더 알려줄래요? 궁금한 낱말이나 문제를 같이 적어 주세요.", suggestions: ["뭐 할 수 있어?"])
        }
        let words = DoitDialogue.keywords(question).prefix(2)
        // 바로 전 주제가 있는데 질문에 새 주제가 없으면 ("임진왜란 언제야" → "누가 이겼어?") 그 주제에서 모른다고 짧게
        if let topic, !topic.isEmpty, question.count <= 14, DoitKnowledge.search(question, limit: 1).first.map({ $0.score < 0.45 }) ?? true {
            if let first = words.first, !topic.contains(first), isNounish(first) {
                let word = question.range(of: first, options: .caseInsensitive).map { String(question[$0]) } ?? first
                return Guard(text: "'\(word)'\(josa(word, "은")) 아직 잘 몰라요." + modelHint(),
                             suggestions: ["\(topic) 설명해줘"], modelMayAnswer: true)
            }
            return Guard(text: DoitTone.pick(["'\(topic)'에서 그 부분은 아직 잘 몰라요.", "그 부분은 제 자료에 없어서 잘 몰라요."]) + modelHint(),
                         suggestions: ["\(topic) 설명해줘"], modelMayAnswer: true)
        }
        guard !words.isEmpty else {
            return Guard(text: "무엇이 궁금한지 조금 더 자세히 알려줄래요?", suggestions: ["뭐 할 수 있어?"])
        }
        // 이름 하나만 물었으면 그 이름으로 ("아인슈타인 누구야" → '아인슈타인'은), 아니면 "그건" (뜻 없는 낱말 조각을 따옴표로 보여 주지 않게)
        // (영어 낱말은 원래 대소문자로: "CPU")
        let label = words.map { w in question.range(of: w, options: .caseInsensitive).map { String(question[$0]) } ?? w }.joined(separator: " ")
        let text: String
        if words.count == 1, isNounish(label) {
            text = DoitTone.pick(["'\(label)'\(josa(label, "은")) 아직 잘 몰라요.", "'\(label)'\(josa(label, "은")) 제가 가진 자료에 없어서 잘 몰라요."])
        } else {
            text = DoitTone.pick(["그건 아직 잘 몰라요.", "그건 제가 가진 자료에 없어서 잘 몰라요."])
        }
        return Guard(text: text + modelHint(), suggestions: ["뭐 할 수 있어?"], modelMayAnswer: true)
    }

    /// 이름씨(명사)처럼 보이는 낱말인지 ("아인슈타인", "Qwen"은 되고 "중요해", "생겨", "이겼어"는 아님)
    static func isNounish(_ word: String) -> Bool {
        let chars = Array(word)
        guard let last = chars.last else { return false }
        if last.isASCII { return last.isLetter || last.isNumber }
        // 풀어 쓴 끝맺음 ("중요해", "생겨", "파래", "이겼어", "됐어")
        let endings: Set<Character> = ["해", "겨", "져", "줘", "돼", "봐", "워", "래", "냐", "까", "죠", "했", "었", "았", "네", "임", "함", "됨", "냥", "듯"]
        if endings.contains(last) { return false }
        if ["어", "아", "요", "다"].contains(last), chars.count >= 2, let final = batchim(chars[chars.count - 2]), final == 20 { return false }
        return true
    }

    // MARK: - 짧게

    /// 긴 설명은 앞부분만 (제목 + 처음 몇 줄). 나머지는 "더 자세히"로 볼 수 있음
    static func brief(_ text: String, maxLines: Int = 7, maxChars: Int = 430) -> String {
        let lines = text.components(separatedBy: "\n")
        guard text.count > maxChars + 50 || lines.count > maxLines + 1 else { return text }
        var kept: [String] = []
        var total = 0
        for line in lines {
            if kept.count >= maxLines || (kept.count >= 3 && total + line.count > maxChars) { break }
            kept.append(line)
            total += line.count + 1
        }
        // 끝에 빈 줄·소제목만 남지 않게
        while let last = kept.last, kept.count > 2, last.trimmingCharacters(in: .whitespaces).isEmpty || last.hasSuffix(":") || last.hasSuffix("**") {
            kept.removeLast()
        }
        return kept.joined(separator: "\n")
    }

    // MARK: - 묻는 말 / 하는 말

    /// 끝이 이름씨(명사)로 끝나는 말 ("벤담이랑 밀 차이", "세종대왕 업적", "롤스 정의론") — 묻는 말로 봄
    /// (반말 끝맺음 "아파", "배불러", "외워져"는 대부분 받침 없는 글자로 끝남)
    static func endsWithNoun(_ text: String) -> Bool {
        let words = text.trimmingCharacters(in: CharacterSet(charactersIn: " .!~")).split(separator: " ")
        guard words.count >= 2, let last = words.last.map(String.init), last.count >= 2, let ch = last.last else { return false }
        let nounEndings = ["차이", "이유", "원리", "방법", "공식", "정의", "종류", "특징", "과정", "순서", "역할", "의미", "뜻", "업적", "결과", "원인", "비교", "장단점", "구조", "기능", "예시", "정리"]
        if nounEndings.contains(where: { last.hasSuffix($0) }) { return true }
        guard let final = batchim(ch), final != 0 else { return false }
        // 받침이 있어도 끝맺음인 글자 ("했", "없", "싶", "좋"…, "~음/~함" 명사형 끝맺음)
        let verbish: Set<Character> = ["했", "었", "았", "겠", "있", "없", "싶", "좋", "않", "같", "많", "봤", "갔", "왔", "줬", "됐", "음", "임", "함", "됨", "옴", "감", "듯", "걸", "군", "죠", "늘", "는"]
        return !verbish.contains(ch)
    }

    /// 묻는 말이 아니라 하는 말 ("영어 단어가 안 외워져", "머리 아파") — 지식 사전 설명을 붙이지 않음
    static func isStatement(_ text: String) -> Bool {
        let t = text.replacingOccurrences(of: " ", with: "")
        if text.contains("?") || text.contains("？") { return false }
        let askWords = ["뭐", "무엇", "무슨", "누구", "누가", "언제", "어디", "왜", "어떻게", "어떤", "얼마", "몇", "인가", "일까", "알려", "설명", "가르쳐", "뜻", "의미", "이란", "란", "궁금",
                        "차이", "원리", "이유", "방법", "정의", "개념", "머야", "머임", "뭐임", "해줘", "줘", "인지", "는지", "은지", "나요", "니", "냐", "까"]
        if askWords.contains(where: { t.contains($0) }) { return false }
        let words = text.split(separator: " ")
        guard words.count >= 2, let last = words.last.map(String.init) else { return false }
        if endsWithNoun(text) { return false }
        // 끝이 반말·존댓말 끝맺음 ("아파", "외워져", "했어", "없어") — "달의 위상 변화", "가정법 과거" 같은 이름씨는 아님
        let endings = ["어", "아", "여", "워", "러", "파", "해", "돼", "야", "지", "네", "요", "다", "자", "게", "래", "져", "봐", "데", "ㅠ", "ㅜ", "ㅋ", "ㅎ"]
        let verbish: Set<Character> = ["했", "었", "았", "겠", "있", "없", "싶", "좋", "않", "같", "많", "봤", "갔", "왔", "줬", "됐", "음", "임", "함", "됨", "듯"]
        return endings.contains { last.hasSuffix($0) } || last.last.map { verbish.contains($0) } == true
    }

    /// 답이 질문 낱말의 대부분(2/3 이상)을 담았는지 (하는 말에 개념 설명을 붙여도 되는지: "플라톤 이데아"는 되고 "영어 단어가 안 외워져"는 안 됨)
    static func coversMost(_ question: String, _ reply: String) -> Bool {
        let words = DoitDialogue.keywords(question)
        guard !words.isEmpty else { return false }
        return Double(covered(words, in: reply)) >= Double(words.count) * 2 / 3
    }

    // MARK: - 답이 질문을 얼마나 담았는지

    /// 질문 핵심 낱말 중 답(과 답 제목의 다른 이름들)에 들어 있는 수
    static func covered(_ words: [String], in reply: String) -> Int {
        let body = expanded(reply)
        return words.filter { body.contains($0) }.count
    }

    /// 답 본문 + 답 제목 개념의 다른 이름들 (띄어쓰기·굵은 글씨 없이, 소문자)
    static func expanded(_ reply: String) -> String {
        var body = reply
        if let title = DoitDialogue.topic(fromReply: reply) {
            let cut = title.components(separatedBy: CharacterSet(charactersIn: ":(")).first?.trimmingCharacters(in: .whitespaces) ?? title
            for name in [title, cut] {
                // 다른 이름들과 단원 이름 ("되와 돼" → 단원 '맞춤법과 띄어쓰기')
                if let entry = DoitKnowledge.entry(named: name) { body += " " + entry.names.joined(separator: " ") + " " + (entry.unit ?? "") }
            }
        }
        return body.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "*", with: "")
    }

    /// 더 알맞은 개념: 짧은 개념 질문에서 답이 질문 낱말을 다 담지 못했는데, 사전에 다 담은 개념이 있으면 그 개념
    /// ("세포 분열이 뭐야" → '세포'가 아니라 '체세포 분열', "반어법" → '어법 문제'가 아니라 '반어법')
    static func betterEntry(for question: String, than reply: String) -> DoitKnowledge.Entry? {
        guard question.count <= 30, !question.contains(where: \.isNumber) else { return nil }
        let words = DoitDialogue.keywords(question)
        guard !words.isEmpty, words.count <= 3 else { return nil }
        let have = covered(words, in: reply)
        guard have < words.count else { return nil }
        // 질문 낱말을 더 많이 담은 개념 (가장 많이 담은 것, 같으면 점수 순)
        var best: (entry: DoitKnowledge.Entry, hit: Int)?
        for match in DoitKnowledge.search(question, limit: 4) where match.score >= 0.55 {
            let entry = match.entry
            let hit = covered(words, in: "**\(entry.title)**\n" + entry.body)
            if hit > (best?.hit ?? have) { best = (entry, hit) }
        }
        guard let best, best.hit >= min(words.count, 2) else { return nil }
        return best.entry
    }
}
