import Foundation

// MARK: - 과목 풀이 더하기: 규칙 3
// - 국어: 문장 성분(조사로 정해지는 것만) · 피동/사동(표에 있는 낱말만) · 시제(서술어 끝) · 낱말의 품사 · 겹받침 발음 · 음운 변동 이름 · 높임법 잘못 쓰기
// - 역사: 사건 순서 나열 ((가)-(나)-(다)) · 연도로 사건 고르기
// - 사회: 환율과 화폐 가치 · 대체재/보완재 수요 · 경기 안정화 정책
// - 과학: 산화·환원(산소를 주고받는 반응식) · 주기 · 같은 족 · 혈액형(태어날 수 없는)
// - 판단이 하나라도 서지 않으면 nil

extension DoitSubjectSolve {
    static func rules3(_ p: Problem) -> Found? {
        let solvers: [(Problem) -> Found?] = [sentenceComponent, voiceQuestion, tenseQuestion, wordClassQuoted, doubleFinalSound, soundChangeNamed,
                                              honorificMisuse, eventOrder, yearToEvent, exchangeValue, relatedGoods, stabilizationPolicy,
                                              redoxQuestion, periodGroupQuestion, bloodTypeCalc]
        for solver in solvers { if let found = solver(p) { return found } }
        return nil
    }

    /// 따옴표 속 글들 (‘…’, '…', “…”, "…")
    static func quotedParts(_ text: String) -> [String] {
        allGroups(text, #"[‘'"“]([^‘’'"“”]{1,60})[’'"”]"#).map { $0[1].trimmingCharacters(in: .whitespaces) }
    }

    // MARK: 국어 — 문장 성분

    private static let componentNames = ["주어", "서술어", "목적어", "보어", "관형어", "부사어", "독립어"]

    static func sentenceComponent(_ p: Problem) -> Found? {
        let c = p.compact
        guard c.contains("문장성분"), !p.negated else { return nil }
        let quoted = quotedParts(p.stem)
        guard quoted.count == 2 else { return nil }
        let sentence = quoted[0], target = quoted[1]
        let tokens = sentence.split(separator: " ").map(String.init)
        let clean = tokens.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".!?")) }
        let idx = clean.indices.filter { clean[$0].trimmingCharacters(in: CharacterSet(charactersIn: ",")) == target }
        guard idx.count == 1, clean.count >= 2 else { return nil }
        let i = idx[0]
        let word = target
        var answer: String?
        var why = ""
        let interjections = wordClassOf.filter { $0.value == "감탄사" }.map(\.key)
        if clean[i].hasSuffix(","), i == 0, interjections.contains(key(word)) || word.hasSuffix("야") || word.hasSuffix("아") {
            answer = "독립어"; why = "감탄사나 부르는 말은 다른 성분과 직접 관계없는 독립어예요."
        } else if i == clean.count - 1 {
            answer = "서술어"; why = "문장 끝에서 주어를 풀이하는 말은 서술어예요."
        } else if wordClassOf[key(word)] == "관형사" {
            answer = "관형어"; why = "'\(word)'는 관형사로, 뒤의 체언을 꾸미는 관형어예요."
        } else if wordClassOf[key(word)] == "부사" {
            answer = "부사어"; why = "'\(word)'는 부사로, 용언을 꾸미는 부사어예요."
        } else if let syl = syllables(word), syl.count >= 2 {
            let last = word.last!
            let stemSyl = syl[syl.count - 2]
            let next = clean[i + 1]
            let complementVerb = i + 1 == clean.count - 1 && (next.hasPrefix("되") || next.hasPrefix("된") || next.hasPrefix("됐") || next.hasPrefix("아니"))
            if last == "을" && stemSyl.final != nil || last == "를" && stemSyl.final == nil {
                answer = "목적어"; why = "목적격 조사 '을/를'이 붙은 말은 목적어예요."
            } else if (last == "이" && stemSyl.final != nil && !["고양이", "원숭이", "호랑이"].contains(word)) || (last == "가" && stemSyl.final == nil) || word.hasSuffix("께서") {
                if complementVerb { answer = "보어"; why = "'되다·아니다' 앞에서 '이/가'가 붙어 꼭 필요한 말은 보어예요." }
                else if i + 1 < clean.count - 1 && (clean[i + 1].hasSuffix("이") || clean[i + 1].hasSuffix("가")) && clean.last.map({ $0.hasPrefix("되") || $0.hasPrefix("아니") || $0.hasPrefix("됐") }) == true {
                    return nil
                } else { answer = "주어"; why = "주격 조사 '이/가(께서)'가 붙은 말은 주어예요." }
            } else if ["에서", "에게", "한테", "으로", "에"].contains(where: { word.hasSuffix($0) }) || (word.hasSuffix("로") && stemSyl.final == nil) {
                answer = "부사어"; why = "부사격 조사(에, 에서, 에게, 으로)가 붙은 말은 부사어예요."
            } else if word.hasSuffix("의") {
                answer = "관형어"; why = "관형격 조사 '의'가 붙은 말은 관형어예요."
            }
        }
        guard let answer else { return nil }
        let steps = [SolutionStep(hint: "문장 성분", work: why)]
        if p.isChoice {
            guard p.choices.allSatisfy({ componentNames.contains(key($0)) }), let index = uniqueChoice(p, matching: [answer]) else { return nil }
            return pick(p, index: index, concept: "문장 성분", steps: steps)
        }
        return Found(answer: answer, concept: "문장 성분", steps: steps + [SolutionStep(hint: "답", work: answer)])
    }

    // MARK: 국어 — 피동 · 사동

    /// 피동사 꼴 (이·히·리·기): 피동으로만 쓰이는 것
    private static let passiveForms = ["잡혔", "잡힌", "잡히", "닫혔", "닫히", "찢겼", "찢기", "쫓겼", "쫓기", "열렸", "열리", "풀렸", "풀리", "팔렸", "팔리",
                                       "밟혔", "밟히", "막혔", "막히", "먹혔", "먹히", "쓰였", "쓰이", "놓였", "놓이", "끊겼", "끊기", "박혔", "박히", "꺾였", "꺾이",
                                       "섞였", "섞이", "묶였", "묶이", "깎였", "깎이", "빼앗겼", "빼앗기", "뽑혔", "뽑히", "쌓였", "쌓이", "담겼", "담기", "갇혔", "갇히", "덮였", "덮이"]
    /// 사동사 꼴: 사동으로만 쓰이는 것
    private static let causativeForms = ["먹였", "먹이", "앉혔", "앉히", "입혔", "입히", "웃겼", "웃기", "재웠", "재우", "깨웠", "깨우", "태웠", "태우", "숨겼", "숨기",
                                         "맡겼", "맡기", "신겼", "신기", "씻겼", "씻기", "높였", "높이", "넓혔", "넓히", "줄였", "줄이", "녹였", "녹이", "얼렸", "얼리",
                                         "죽였", "죽이", "살렸", "살리", "남겼", "남기", "늘렸", "늘리", "익혔", "익히", "굽혔", "굽히", "울렸"]
    /// 피동도 사동도 아닌 서술어 (능동·주동)
    private static let plainForms = ["읽었", "읽는", "읽는다", "먹었", "먹는", "먹는다", "갔", "간다", "왔", "온다", "만났", "부른다", "불렀", "샀", "달렸", "피었",
                                     "잤", "놀았", "웃었", "썼", "봤", "보았", "했", "공부했", "열었", "닫았", "잡았", "앉았", "입었", "울었", "죽었", "살았", "찢었", "끊었", "쌓았"]

    private enum Voice { case passive, causative, plain }

    private static func voice(_ sentence: String) -> Voice? {
        let tokens = sentence.split(separator: " ").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?")) }
        guard let pred = tokens.last, tokens.count >= 2 else { return nil }
        let hasObject = tokens.dropLast().contains { t in
            guard let syl = syllables(t), syl.count >= 2, let last = t.last else { return false }
            let prev = syl[syl.count - 2]
            return last == "을" && prev.final != nil || last == "를" && prev.final == nil
        }
        func starts(_ list: [String]) -> Bool { list.contains { pred.hasPrefix($0) } }
        if pred.contains("어지") || pred.contains("아지") || pred.contains("어졌") || pred.contains("아졌") { return hasObject ? nil : .passive }
        if pred.contains("게했") || pred.contains("게한") || pred.contains("게하") { return .causative }
        // 피동·사동 둘 다 되는 꼴 (물리다 · 보이다 · 안기다 …): 목적어가 있으면 사동, 없으면 피동
        if starts(["물렸", "물리", "보였", "보이", "들렸", "들리", "안겼", "안기", "업혔", "업히", "감겼", "감기", "날렸", "날리", "읽혔", "읽히"]) {
            return hasObject ? .causative : .passive
        }
        let isPassive = starts(passiveForms), isCausative = starts(causativeForms), isPlain = plainForms.contains { pred.hasPrefix($0) }
        guard [isPassive, isCausative, isPlain].filter({ $0 }).count == 1 else { return nil }
        if isPassive { return hasObject ? nil : .passive }
        if isCausative { return hasObject ? .causative : nil }
        return .plain
    }

    static func voiceQuestion(_ p: Problem) -> Found? {
        let c = p.compact
        guard p.isChoice, p.box.isEmpty else { return nil }
        let askPassive = matches(c, #"피동(표현|문)"#), askCausative = matches(c, #"사동(표현|문)"#)
        guard askPassive != askCausative else { return nil }
        let want: Voice = askPassive ? .passive : .causative
        var verdicts: [Bool] = []
        var steps: [SolutionStep] = []
        for (i, choice) in p.choices.enumerated() {
            guard let v = voice(choice) else { return nil }
            verdicts.append(v == want)
            let name = v == .passive ? "피동" : v == .causative ? "사동" : "능동·주동"
            steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(choice) → \(name)"))
        }
        let hits = verdicts.indices.filter { verdicts[$0] != p.negated }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: askPassive ? "피동 표현 (주어가 남의 행동을 당함: -이/히/리/기-, -어지다)" : "사동 표현 (남에게 하게 함: -이/히/리/기/우/구/추-, -게 하다)", steps: steps)
    }

    // MARK: 국어 — 시제

    private enum Tense: String { case past = "과거", present = "현재", future = "미래" }

    private static func tense(_ sentence: String) -> Tense? {
        let tokens = sentence.split(separator: " ").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?")) }
        guard let pred = tokens.last, let syl = syllables(pred) else { return nil }
        if pred.contains("겠") { return pred.contains("었") || pred.contains("았") ? nil : .future }
        if pred.hasPrefix("것이") || pred.hasPrefix("거야") || pred == "거다", tokens.count >= 2, let prev = syllables(tokens[tokens.count - 2])?.last, prev.final == "ㄹ" { return .future }
        let pastMark = syl.dropLast().contains { $0.final == "ㅆ" } && !pred.hasPrefix("있") && !pred.hasPrefix("없")
        if pastMark { return .past }
        let lastTwo = String(pred.suffix(2))
        if pred.hasSuffix("는다") || (lastTwo.count == 2 && pred.last == "다" && syl[syl.count - 2].final == "ㄴ") { return .present }
        return nil
    }

    static func tenseQuestion(_ p: Problem) -> Found? {
        let c = p.compact
        guard p.isChoice, p.box.isEmpty, let m = groups(c, #"(과거|현재|미래)시제(가|를)?"#) else { return nil }
        guard count(c, #"(과거|현재|미래)시제"#) == 1, p.choices.allSatisfy({ $0.filter { DoitSubjectNote.isHangul($0) }.count >= 4 }) else { return nil }
        let want = Tense(rawValue: m[1])!
        var verdicts: [Bool] = []
        var steps: [SolutionStep] = []
        for (i, choice) in p.choices.enumerated() {
            guard let t = tense(choice) else { return nil }
            verdicts.append(t == want)
            steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(choice) → \(t.rawValue) 시제"))
        }
        let hits = verdicts.indices.filter { verdicts[$0] != p.negated }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: "시제 (과거 -았/었-, 현재 -ㄴ/는-, 미래 -겠-·-ㄹ 것이다)", steps: steps)
    }

    // MARK: 국어 — 낱말의 품사

    static func wordClassQuoted(_ p: Problem) -> Found? {
        let c = p.compact
        guard !p.negated, matches(c, #"의품사(는|가|로)"#), !matches(c, #"(에서|문장)"#) else { return nil }
        let quoted = quotedParts(p.stem)
        guard quoted.count == 1, let cls = wordClassOf[key(quoted[0])] else { return nil }
        let steps = [SolutionStep(hint: "품사", work: "'\(quoted[0])'는 \(cls)예요.")]
        if p.isChoice {
            guard let index = uniqueChoice(p, matching: [cls]) else { return nil }
            return pick(p, index: index, concept: "품사", steps: steps)
        }
        return Found(answer: cls, concept: "품사", steps: steps + [SolutionStep(hint: "답", work: cls)])
    }

    // MARK: 국어 — 겹받침 발음

    /// 겹받침 낱말의 표준 발음 (규칙에 예외가 많아 낱말마다)
    static let doubleFinalSounds: [String: String] = [
        "닭": "닥", "값": "갑", "삶": "삼", "흙": "흑", "몫": "목", "넋": "넉", "삯": "삭", "여덟": "여덜", "외곬": "외골", "앉다": "안따", "얹다": "언따",
        "읽다": "익따", "맑다": "막따", "늙다": "늑따", "밟다": "밥따", "넓다": "널따", "짧다": "짤따", "얇다": "얄따", "엷다": "열따", "없다": "업따",
        "젊다": "점따", "굶다": "굼따", "닮다": "담따", "삶다": "삼따", "핥다": "할따", "훑다": "훌따", "읊다": "읍따", "많다": "만타", "않다": "안타",
        "싫다": "실타", "앓다": "알타", "끓다": "끌타", "옳다": "올타", "읽고": "일꼬", "맑고": "말꼬", "밟고": "밥꼬", "넓고": "널꼬", "값도": "갑또", "닭도": "닥또"
    ]

    static func doubleFinalSound(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"(발음|소리)"#) else { return nil }
        if p.isChoice, p.choices.allSatisfy({ $0.contains("[") }) {
            let quoted = quotedParts(p.stem)
            var verdicts: [Bool] = []
            var steps: [SolutionStep] = []
            for (i, choice) in p.choices.enumerated() {
                guard let m = groups(choice, #"^\s*([가-힣]*)\s*\[([가-힣]+)\]\s*$"#) else { return nil }
                let word = m[1].isEmpty ? (quoted.count == 1 ? quoted[0] : "") : m[1]
                guard let sound = doubleFinalSounds[word] ?? (word.isEmpty ? nil : soundChanges(word)?.pronunciation) else { return nil }
                verdicts.append(sound == m[2])
                steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(word) → [\(sound)]"))
            }
            let hits = verdicts.indices.filter { verdicts[$0] != p.negated }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "표준 발음 (겹받침·음운 변동)", steps: steps)
        }
        guard !p.isChoice, matches(c, #"표준발음"#) else { return nil }
        let quoted = quotedParts(p.stem)
        guard quoted.count == 1, let sound = doubleFinalSounds[quoted[0]] else { return nil }
        return Found(answer: "[\(sound)]", concept: "겹받침의 발음", steps: [SolutionStep(hint: "발음", work: "\(quoted[0]) → [\(sound)]")])
    }

    // MARK: 국어 — 일어나는 음운 변동 (이름)

    private static let changeNames: [(names: [String], kind: String)] = [
        (["비음화"], "비음화"), (["유음화"], "유음화"), (["구개음화"], "구개음화"), (["된소리되기", "된소리 되기", "경음화"], "된소리되기"),
        (["거센소리되기", "거센소리 되기", "자음 축약", "격음화"], "거센소리되기"), (["ㅎ 탈락"], "ㅎ 탈락")
    ]

    static func soundChangeNamed(_ p: Problem) -> Found? {
        let c = p.compact
        // "다음 중 음운의 축약(탈락)이 일어나는 단어는?": 다른 선지마다 다른 변동이 분명할 때만
        if p.isChoice, matches(c, #"음운의?(축약|탈락)"#), p.choices.allSatisfy({ $0.range(of: #"^[가-힣]{2,4}$"#, options: .regularExpression) != nil }) {
            let kind = c.contains("축약") ? "거센소리되기" : "ㅎ 탈락"
            let analyses = p.choices.map(soundChanges)
            guard analyses.allSatisfy({ $0 != nil && $0!.possible.isEmpty }) else { return nil }
            let mains = analyses.map { $0!.certain.subtracting(["연음", "음절의 끝소리 규칙"]) }
            var verdicts: [Bool] = []
            for m in mains {
                if m.contains(kind) { verdicts.append(true) }
                else if m.isEmpty { return nil }   // 변동을 설명할 수 없는 말이 있으면 모름 (모음 축약·ㄹ 탈락 같은 것일 수 있어요)
                else { verdicts.append(false) }
            }
            let hits = verdicts.indices.filter { verdicts[$0] != p.negated }
            guard hits.count == 1 else { return nil }
            let steps = p.choices.indices.map { SolutionStep(hint: "", work: "\(circled($0 + 1)) \(p.choices[$0]): \(mains[$0].sorted().joined(separator: ", "))") }
            return pick(p, index: hits[0], concept: kind == "거센소리되기" ? "음운의 축약 (ㅎ + ㄱ·ㄷ·ㅂ·ㅈ → ㅋ·ㅌ·ㅍ·ㅊ)" : "음운의 탈락", steps: steps)
        }
        // "'굳이'를 발음할 때 일어나는 음운 변동은?"
        guard matches(c, #"(발음할때|발음하면).{0,6}(일어나는|나타나는).{0,4}음운(의)?변동"#), !p.negated else { return nil }
        let quoted = quotedParts(p.stem)
        guard quoted.count == 1, let change = soundChanges(quoted[0]), change.possible.isEmpty else { return nil }
        let main = change.certain.subtracting(["연음", "음절의 끝소리 규칙"])
        guard main.count == 1, let kind = main.first else { return nil }
        let steps = [SolutionStep(hint: "음운 변동", work: "\(quoted[0])" + (change.pronunciation.map { " → [\($0)]" } ?? "") + ": \(kind)")]
        if p.isChoice {
            let named = p.choices.map { choice in changeNames.first { $0.names.contains { key($0) == key(choice) } }?.kind }
            guard named.allSatisfy({ $0 != nil }) else { return nil }
            let hits = named.indices.filter { named[$0] == kind }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "음운 변동", steps: steps)
        }
        return Found(answer: kind, concept: "음운 변동", steps: steps + [SolutionStep(hint: "답", work: kind)])
    }

    // MARK: 국어 — 높임법이 잘못 쓰인 문장

    static func honorificMisuse(_ p: Problem) -> Found? {
        let c = p.compact
        guard p.isChoice, p.box.isEmpty, matches(c, #"높임(법|표현)이?.{0,4}(잘못|바르지않|어색|틀린|알맞지않)"#) || matches(c, #"높임(법|표현)이?.{0,4}(바르게|알맞게|올바르게)"#) else { return nil }
        let askWrong = matches(c, #"(잘못|바르지않|어색|틀린|알맞지않)"#)
        var wrong: [Bool] = []
        var steps: [SolutionStep] = []
        for (i, choice) in p.choices.enumerated() {
            let s = choice.filter { !$0.isWhitespace }
            // 사물을 높임 ("커피 나오셨습니다", "사이즈가 없으세요")
            let thingHonored = matches(s, #"(커피|음료|주문하신.{0,8}|물건|상품|제품|가격|사이즈|거스름돈|잔돈|품절)(이|가|은|는)?(나오셨|나오십|나오세|있으십|있으세|없으십|없으세|되십|되세|되셨|이십|이세)"#)
            // 께서 + 높이지 않은 서술어 · 께 + '주다/묻다'
            let subjectMissing = s.contains("께서") && honorifics(choice).subject == true && !matches(s, #"(시|셨|셔|세|십|신|실|계|주무|잡수|드시|드셨|편찮)[가-힣]*[.!?]?$"#)
            let objectMissing = matches(s, #"(?<!함)께(?!서).{0,10}(줬|주었|준다|물어|물었)"#)
            let isWrong = thingHonored || subjectMissing || objectMissing
            if !isWrong {
                // 바르게 높인 것이 분명해야 해요
                let h = honorifics(choice)
                guard h.subject == true || h.object == true else { return nil }
            }
            wrong.append(isWrong)
            steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(choice) → \(isWrong ? (thingHonored ? "사물을 높였어요" : "높임이 맞지 않아요") : "바르게 높였어요")"))
        }
        let hits = wrong.indices.filter { wrong[$0] == askWrong }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: "높임법 (높일 대상은 사람: 사물에는 '-시-'를 쓰지 않아요)", steps: steps)
    }

    // MARK: 역사 — 순서대로 나열

    /// 글 속 (가) 사건 (나) 사건 … → 이름표마다 사건 해
    static func labeledEvents(_ text: String) -> [(label: String, year: Int, name: String)]? {
        let parts = allGroups(text, #"\(([가-마])\)\s*([^()\n①②③④⑤]+?)(?=\s*\([가-마]\)|\s*[①②③④⑤]|\n|$)"#)
        guard parts.count >= 3 else { return nil }
        var out: [(String, Int, String)] = []
        for part in parts {
            let name = part[2].trimmingCharacters(in: .whitespaces)
            guard let e = exactEvent(name) else { return nil }
            out.append((part[1], e.year, name))
        }
        guard Set(out.map(\.0)).count == out.count, Set(out.map(\.1)).count == out.count else { return nil }
        return out
    }

    static func eventOrder(_ p: Problem) -> Found? {
        let c = p.compact
        guard p.isChoice, matches(c, #"(순서|시대순|차례)"#), !matches(c, #"(역순|최근부터|늦은것부터|나중것부터)"#) else { return nil }
        guard let events = labeledEvents(p.stem) else { return nil }
        let order = events.sorted { $0.year < $1.year }.map(\.label)
        let hits = p.choices.indices.filter { i in
            let labels = allGroups(p.choices[i], #"\(([가-마])\)"#).map { $0[1] }
            return labels == order
        }
        guard hits.count == 1 else { return nil }
        let steps = events.sorted { $0.year < $1.year }.map { SolutionStep(hint: "(\($0.label))", work: "\($0.name): \(yearText($0.year))") }
        return pick(p, index: hits[0], concept: "사건의 순서", steps: steps)
    }

    /// "1636년에 일어난 전쟁은?" — 선지가 모두 연표의 사건이고 그 해가 하나뿐일 때
    static func yearToEvent(_ p: Problem) -> Found? {
        let c = p.compact
        guard p.isChoice, !p.negated, let m = groups(c, #"^(기원전)?([0-9]{1,4})년(에|의|)"#), let y = Int(m[2]) else { return nil }
        guard matches(c, #"(일어난|체결된|맺은|발생한|시작된|있었던|세워진|건국된|일어났던)"#), count(c, #"[0-9]{3,4}년"#) == 1 else { return nil }
        let year = m[1].isEmpty ? y : -y
        let events = p.choices.map(exactEvent)
        guard events.allSatisfy({ $0 != nil }) else { return nil }
        let hits = events.indices.filter { events[$0]!.year == year }
        guard hits.count == 1 else { return nil }
        let steps = p.choices.indices.map { SolutionStep(hint: "", work: "\(circled($0 + 1)) \(p.choices[$0]): \(yearText(events[$0]!.year))") }
        return pick(p, index: hits[0], concept: "연표", steps: steps)
    }

    // MARK: 사회 — 환율과 화폐 가치

    static func exchangeValue(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard c.contains("환율"), let g = groups(c, #"1(달러|엔|유로|위안)당([0-9.]+)원에서([0-9.]+)원으로"#), let a = Double(g[2]), let b = Double(g[3]), a != b else { return nil }
        let rateUp = b > a
        let askWon = matches(c, #"원화(의)?가치"#) && !matches(c, #"(달러|엔|유로|위안)화?(의)?가치(는|가)"#)
        let askForeign = matches(c, #"(달러|엔|유로|위안)화?(의)?가치(는|가)"#) && !askWon
        guard askWon || askForeign else { return nil }
        let up = askWon ? !rateUp : rateUp
        let steps = [SolutionStep(hint: "환율", work: "환율(1\(g[1])당 원)이 \(rateUp ? "오르면" : "내리면") 같은 \(g[1])를 사는 데 원화가 \(rateUp ? "더" : "덜") 들어요 → 원화 가치 \(rateUp ? "하락" : "상승"), \(g[1])화 가치 \(rateUp ? "상승" : "하락")")]
        if p.isChoice {
            let hits = p.choices.indices.filter { i in
                let k = key(p.choices[i])
                return up ? (k.hasPrefix("상승") || k.hasPrefix("오른") || k.hasPrefix("높아")) : (k.hasPrefix("하락") || k.hasPrefix("내린") || k.hasPrefix("낮아") || k.hasPrefix("떨어"))
            }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "환율과 화폐 가치", steps: steps)
        }
        let answer = up ? "상승한다" : "하락한다"
        return Found(answer: answer, concept: "환율과 화폐 가치", steps: steps + [SolutionStep(hint: "답", work: answer)])
    }

    // MARK: 사회 — 대체재 · 보완재

    static func relatedGoods(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"(대체재|보완재|대체관계|보완관계)"#), matches(c, #"수요(는|의변화|가|변화)"#), !matches(c, #"수요량"#) else { return nil }
        let up = matches(c, #"가격이?(상승|오르|인상)"#), down = matches(c, #"가격이?(하락|내리|인하)"#)
        let substitute = matches(c, #"(대체재|대체관계)"#), complement = matches(c, #"(보완재|보완관계)"#)
        guard up != down, substitute != complement else { return nil }
        let increase = substitute ? up : down
        let steps = [SolutionStep(hint: substitute ? "대체재" : "보완재",
                                  work: substitute ? "한 재화 가격이 오르면 그 대신 쓰는 대체재의 수요는 늘어요(내리면 줄어요)." : "한 재화 가격이 오르면 함께 쓰는 보완재의 수요는 줄어요(내리면 늘어요).")]
        if p.isChoice {
            let hits = p.choices.indices.filter { i in
                let k = key(p.choices[i])
                return increase ? (k.hasPrefix("증가") || k.hasPrefix("늘")) : (k.hasPrefix("감소") || k.hasPrefix("줄"))
            }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "연관재의 수요 변화", steps: steps)
        }
        let answer = increase ? "증가한다" : "감소한다"
        return Found(answer: answer, concept: "연관재의 수요 변화", steps: steps + [SolutionStep(hint: "답", work: answer)])
    }

    // MARK: 사회 — 경기 안정화 정책

    /// 정책 → (확대 정책인지, 통화 정책인지)
    private static func policyKind(_ choice: String) -> (expand: Bool, monetary: Bool)? {
        let k = key(choice)
        let table: [(String, Bool, Bool)] = [
            (#"^(기준)?금리(를)?인하"#, true, true), (#"^(기준)?금리(를)?인상"#, false, true), (#"^국공채(를)?매입"#, true, true), (#"^국공채(를)?매각"#, false, true),
            (#"^지급준비율(을)?인하"#, true, true), (#"^지급준비율(을)?인상"#, false, true), (#"^통화량(을)?(늘|증가|확대)"#, true, true), (#"^통화량(을)?(줄|감소|축소)"#, false, true),
            (#"^정부지출(을)?(확대|증가|늘)"#, true, false), (#"^정부지출(을)?(축소|감소|줄)"#, false, false), (#"^(세율|세금)(을)?(인하|내림|낮)"#, true, false),
            (#"^(세율|세금)(을)?(인상|올림|높)"#, false, false), (#"^재정지출(을)?(확대|증가|늘)"#, true, false), (#"^재정지출(을)?(축소|감소|줄)"#, false, false)
        ]
        let hits = table.filter { matches(k, $0.0) }
        guard hits.count == 1 else { return nil }
        return (hits[0].1, hits[0].2)
    }

    static func stabilizationPolicy(_ p: Problem) -> Found? {
        let c = p.compact
        guard p.isChoice, p.box.isEmpty else { return nil }
        let slump = matches(c, #"(경기(가)?침체|불황|경기(가)?(나쁠|위축)|실업(이|률이)?(증가|높))"#), boom = matches(c, #"(경기(가)?과열|인플레이션|물가(가)?(급등|크게오르|상승))"#)
        guard slump != boom else { return nil }
        let wantMonetary: Bool? = matches(c, #"(통화정책|중앙은행|한국은행)"#) ? true : matches(c, #"(재정정책|정부의?정책)"#) && !c.contains("중앙은행") ? false : nil
        let kinds = p.choices.map(policyKind)
        guard kinds.allSatisfy({ $0 != nil }) else { return nil }
        let expand = slump
        let fits = kinds.indices.filter { i in
            let k = kinds[i]!
            return k.expand == expand && (wantMonetary.map { $0 == k.monetary } ?? true)
        }
        let hits = p.negated ? kinds.indices.filter { !fits.contains($0) } : fits
        guard hits.count == 1 else { return nil }
        let steps = [SolutionStep(hint: "경기 안정화", work: expand ? "경기 침체: 금리 인하·국공채 매입·지급 준비율 인하(통화), 정부 지출 확대·세율 인하(재정)"
                                                                : "경기 과열: 금리 인상·국공채 매각·지급 준비율 인상(통화), 정부 지출 축소·세율 인상(재정)")]
        return pick(p, index: hits[0], concept: "경기 안정화 정책", steps: steps)
    }

    // MARK: 과학 — 산화 · 환원 (산소를 주고받는 반응)

    /// 화학식 → 원소별 원자 수 ("CuO" → [Cu: 1, O: 1]), 계수는 뗌
    static func formulaAtoms(_ formula: String) -> [String: Int]? {
        var t = formula.trimmingCharacters(in: .whitespaces)
        let sub: [Character: Character] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6"]
        t = String(t.map { sub[$0] ?? $0 })
        t = t.replacingOccurrences(of: #"^[0-9]+"#, with: "", options: .regularExpression)
        guard !t.isEmpty, t.range(of: #"^([A-Z][a-z]?[0-9]*)+$"#, options: .regularExpression) != nil else { return nil }
        var out: [String: Int] = [:]
        for g in allGroups(t, #"([A-Z][a-z]?)([0-9]*)"#) { out[g[1], default: 0] += Int(g[2]) ?? 1 }
        return out
    }

    static func redoxQuestion(_ p: Problem) -> Found? {
        let c = p.compact
        let askOx = matches(c, #"산화되는(물질|것)"#), askRed = matches(c, #"환원되는(물질|것)"#)
        guard p.isChoice, askOx != askRed, !p.negated else { return nil }
        guard let eq = groups(p.full, #"([A-Za-z0-9₀-₉ +]+)→([A-Za-z0-9₀-₉ +]+)"#) else { return nil }
        let left = eq[1].components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        let right = eq[2].components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        let la = left.map(formulaAtoms), ra = right.map(formulaAtoms)
        guard left.count == 2, right.count == 2, la.allSatisfy({ $0 != nil }), ra.allSatisfy({ $0 != nil }) else { return nil }
        // 산소를 잃는 반응물(산화물 → 홑원소) = 환원, 산소를 얻는 반응물(홑원소 → 산화물) = 산화
        var oxidized: String?, reduced: String?
        for (i, r) in la.enumerated() {
            let a = r!
            let elems = Set(a.keys)
            if a["O"] != nil, elems.count == 2, let other = elems.subtracting(["O"]).first,
               ra.contains(where: { Set($0!.keys) == [other] }) { reduced = left[i] }
            if a["O"] == nil, elems.count == 1, let only = elems.first,
               ra.contains(where: { Set($0!.keys) == [only, "O"] }) { oxidized = left[i] }
        }
        guard let ox = oxidized, let red = reduced, ox != red else { return nil }
        let target = askOx ? ox : red
        let clean = target.replacingOccurrences(of: #"^[0-9]+"#, with: "", options: .regularExpression)
        guard let want = formulaAtoms(clean) else { return nil }
        let hits = p.choices.indices.filter { formulaAtoms(p.choices[$0]) == want && p.choices[$0].trimmingCharacters(in: .whitespaces).first?.isNumber == false }
        guard hits.count == 1 else { return nil }
        let steps = [SolutionStep(hint: "산화·환원", work: "산소를 얻은 물질은 산화되고, 산소를 잃은 물질은 환원돼요."),
                     SolutionStep(hint: "이 반응", work: "\(ox.replacingOccurrences(of: #"^[0-9]+"#, with: "", options: .regularExpression)): 산소를 얻음(산화) · \(red.replacingOccurrences(of: #"^[0-9]+"#, with: "", options: .regularExpression)): 산소를 잃음(환원)")]
        return pick(p, index: hits[0], concept: "산화 환원 반응", steps: steps)
    }

    // MARK: 과학 — 주기 · 같은 족

    private static func elementOf(_ choice: String) -> DoitScience.ElementInfo? {
        let t = choice.trimmingCharacters(in: .whitespaces)
        let list = DoitScience.elementList
        return list.first { $0.symbol == t } ?? list.first { ([$0.name] + $0.aliases).contains(t) }
    }

    static func periodGroupQuestion(_ p: Problem) -> Found? {
        let c = p.compact
        guard p.isChoice, !p.negated else { return nil }
        // "3주기에 속하는 원소는?"
        if let m = groups(c, #"([1-7])주기(에|의)?(속하는|해당하는|원소)"#), let period = Int(m[1]), !c.contains("족") {
            let els = p.choices.map(elementOf)
            guard els.allSatisfy({ $0 != nil && $0!.number <= 36 }) else { return nil }
            let hits = els.indices.filter { els[$0]!.period == period }
            guard hits.count == 1 else { return nil }
            let steps = p.choices.indices.map { SolutionStep(hint: "", work: "\(circled($0 + 1)) \(p.choices[$0]): \(els[$0]!.period)주기") }
            return pick(p, index: hits[0], concept: "주기율표의 주기", steps: steps)
        }
        // "같은 족에 속하는 원소끼리 짝지은 것은?"
        if matches(c, #"같은족"#), !c.contains("주기") {
            var verdicts: [Bool] = []
            var steps: [SolutionStep] = []
            for (i, choice) in p.choices.enumerated() {
                let parts = choice.components(separatedBy: CharacterSet(charactersIn: ",·와과")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                guard parts.count == 2, let a = elementOf(parts[0]), let b = elementOf(parts[1]), a.number <= 36, b.number <= 36, a.group > 0, b.group > 0 else { return nil }
                // 수소는 1족이지만 알칼리 금속과 성질이 달라, 수소와 1족 원소의 짝은 모름
                if (a.number == 1 && b.group == 1) || (b.number == 1 && a.group == 1) { return nil }
                verdicts.append(a.group == b.group)
                steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(a.symbol) \(a.group)족, \(b.symbol) \(b.group)족"))
            }
            let hits = verdicts.indices.filter { verdicts[$0] }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "주기율표의 족", steps: steps)
        }
        return nil
    }
}
