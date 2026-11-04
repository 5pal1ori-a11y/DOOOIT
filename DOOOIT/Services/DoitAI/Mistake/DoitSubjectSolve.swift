import Foundation

/// 수학이 아닌 과목(과학·영어·사회·국어) 문제를 규칙과 내장 자료로 풀기
/// - 확인한 답만 냄: 공식으로 계산해 선지 하나와 값이 맞을 때, 문법 규칙의 단서가 분명할 때,
///   자료로 선지 하나만 맞고 나머지는 틀린 것을 알 때. 조금이라도 모르면 nil (틀린 답보다 안 푸는 게 나아요)
/// - 외부 AI·인터넷 없이 앱에 들어 있는 자료(과학 계산, 주기율표, 영어 변화형·단어장, 나라·연표)와 이 파일의 사실표만 씀
enum DoitSubjectSolve {
    /// 문제 하나 풀기 (객관식이면 정답은 선지 번호 "3")
    /// - subjectBroad: 큰 과목 이름 ("과학", "영어" …). 순서만 정하고, 과목이 틀려도 규칙이 맞으면 풂
    static func solve(text: String, choices: [String], subjectBroad: String?, body: String? = nil, boxItems: [String]? = nil) -> WrittenSolution? {
        let full = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !full.isEmpty else { return nil }
        let p = Problem(full: full, body: body, choices: choices, box: boxItems)
        let calc: [(Problem) -> Found?] = [scienceMore, scienceCalc2, scienceCalc]
        // 영어 어법: 지문 밑줄 · 네모 · 개수 · 고치기 · 문장 전환은 문장 선지 풀이보다 먼저, 빈칸 대입은 빈칸 규칙 다음에
        let englishFirst: [(Problem) -> Found?] = [englishUnderlinedPassage, englishBoxes, englishCount, englishFixError, englishTransform]
        var solvers: [(Problem) -> Found?] = [chartData, socialCalc] + englishFirst + [itemRules, englishSentences, englishTwoBlanks, koreanSound, koreanHonorific, koreanSpelling,
                                              englishGrammar, englishBlankSubstitute, englishVocabulary, oddWordClass, category, statements, phenomena, eraQuestion, personEvent,
                                              socialLookup, timeZone, element, facts, entityPairs, entityStatements, entityFromDescription, scaleQuestion, colorMix]
        // 과학이면 계산을 먼저 (계산 문제에 낱말 사실표가 먼저 걸리지 않게)
        solvers = subjectBroad == "과학" ? calc + solvers : solvers + calc
        for solver in solvers {
            guard let found = solver(p) else { continue }
            var solution = WrittenSolution(concept: found.concept, steps: found.steps, finalAnswer: found.answer)
            solution.source = DoitAutoSolve.engineSource
            solution.problem = full
            return solution
        }
        return nil
    }

    // MARK: - 문제 글

    struct Problem {
        let full: String
        /// 선지·<보기>를 뺀 본문 (없으면 글 전체)
        let stem: String
        let choices: [String]
        /// <보기> 항목 ("ㄱ. 편마암")
        let box: [String]
        var isChoice: Bool { choices.count >= 2 }
        /// 띄어쓰기를 뺀 본문
        var compact: String { stem.filter { !$0.isWhitespace } }
        /// 틀린 것·아닌 것을 고르는 문제
        var negated: Bool {
            let c = compact
            return ["아닌", "않은", "않는", "틀린", "잘못", "옳지않", "알맞지않", "바르지않", "적절하지않", "해당하지않"].contains { c.contains($0) }
        }

        init(full: String, body: String?, choices: [String], box: [String]?) {
            self.full = full
            self.choices = choices.map { $0.trimmingCharacters(in: .whitespaces) }
            let scanned = DoitProblemScan.scan(full, math: false)
            self.box = box ?? scanned.boxItems ?? []
            var main = (body?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? scanned.body
            if main.isEmpty { main = full }
            // 본문에 남은 선지 줄 떼기 ("① 2 ② 4 …")
            if let r = main.range(of: #"\s*[①②③④⑤].*$"#, options: .regularExpression), r.lowerBound != main.startIndex {
                main = String(main[..<r.lowerBound])
            }
            stem = main
        }
    }

    struct Found {
        var answer: String
        var concept: String
        var steps: [SolutionStep]
    }

    // MARK: - 공통 도구

    static func circled(_ n: Int) -> String { DoitGuidedSolve.circled(n) }

    /// 비교용: 소문자, 띄어쓰기·가운뎃점·괄호 속 설명 빼기 ("이산화 탄소(CO₂)" → "이산화탄소")
    static func key(_ s: String) -> String {
        var t = s.lowercased()
        t = t.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"^\s*(\d+[.)]|[①②③④⑤])\s*"#, with: "", options: .regularExpression)
        return t.filter { !" ·・-_.,'\"‘’“”?!~\t\n".contains($0) }
    }

    /// 정답 하나를 고른 풀이 (객관식이면 선지 번호)
    static func pick(_ p: Problem, index: Int, concept: String, steps: [SolutionStep]) -> Found {
        var all = steps
        all.append(SolutionStep(hint: "정답", work: "\(circled(index + 1)) \(p.choices[index])"))
        return Found(answer: "\(index + 1)", concept: concept, steps: all)
    }

    /// 답 이름들과 같은 선지가 하나뿐이면 그 번호
    static func uniqueChoice(_ p: Problem, matching names: [String]) -> Int? {
        let keys = Set(names.map(key))
        let hits = p.choices.indices.filter { keys.contains(key(p.choices[$0])) }
        return hits.count == 1 ? hits[0] : nil
    }

    static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - 그림에서 읽은 자료 (차트·표)

    /// 학생이 확인한 차트·표 자료로 답하는 질문 (가장 많은 것, 합, 평균, 차, 증가율). 선지가 있으면 값·이름이 같은 선지 하나일 때만
    static func chartData(_ p: Problem) -> Found? {
        let figure = DoitFigureFacts.split(p.full)
        guard !figure.facts.isEmpty else { return nil }
        let question = DoitFigureFacts.split(p.stem).problem
        guard let found = DoitFigureFacts.solveChart(question: question, facts: figure.facts) else { return nil }
        let concept = "그림(자료)에서 읽은 값으로 비교·계산해요. 읽은 값이 그림과 같은지 먼저 확인해요."
        let steps = found.steps.map { SolutionStep(hint: $0.0, work: $0.1) }
        guard p.isChoice else { return Found(answer: found.answer, concept: concept, steps: steps) }
        if let label = found.label, let index = uniqueChoice(p, matching: [label]) { return pick(p, index: index, concept: concept, steps: steps) }
        if let value = found.value {
            let hits = p.choices.indices.filter { DoitFigureFacts.number(in: p.choices[$0]).map { abs($0 - value) < 1e-6 } ?? false }
            if hits.count == 1 { return pick(p, index: hits[0], concept: concept, steps: steps) }
        }
        return nil
    }

    // MARK: - 과학 계산 (공식 · 단위)

    /// 공식으로 계산하고, 묻는 단위(몇 N)·선지와 값이 맞을 때만
    static func scienceCalc(_ p: Problem) -> Found? {
        let stem = p.stem
        // 선지가 문장이면 계산 문제가 아님
        if p.isChoice, !p.choices.allSatisfy(isNumericChoice) { return nil }
        // 지도 축척 문제는 단위 바꾸기가 아님 (socialCalc에서)
        if matches(p.compact, #"(축척|지도|지형도)"#) { return nil }
        if let special = scienceSpecial(p) { return special }
        guard let reply = DoitScience.calculation(stem) else { return nil }
        guard let parsed = parseCalc(reply), !ambiguousValues(stem, title: parsed.title) else { return nil }
        // 직렬·병렬 회로나 "저항 2개"인데 저항 하나로 계산했으면 믿지 않음 (회로 계산은 scienceMore에서)
        if matches(p.compact, #"Ω(인|의|짜리)?(저항)?(두|세|네|[2-9])개"#) || matches(p.compact, #"(직렬|병렬)"#) && !parsed.title.contains("합성 저항") { return nil }
        let asked = askedUnit(stem)
        // 계산한 값: 기본 단위 값과 보여 준 단위
        guard let value = DoitScience.quantities(in: parsed.answerHead).first ?? plainNumber(parsed.answerHead) else { return nil }
        var shown = parsed.answerHead
        var displayValue = value.raw
        if let asked {
            guard asked.dimension == value.dimension else { return nil }   // 다른 양을 계산했으면 버림
            if asked.unit != value.unit, value.dimension != "temperature" {
                displayValue = value.si / asked.factor
                shown = "\(DoitScience.fmt(displayValue)) \(asked.unit)"
            }
        }
        var steps = parsed.steps
        if p.isChoice {
            let hits = p.choices.indices.filter { sameValue(p.choices[$0], value: value, displayValue: displayValue, asked: asked) }
            guard hits.count == 1 else { return nil }
            steps.append(SolutionStep(hint: "답", work: shown))
            return pick(p, index: hits[0], concept: parsed.title, steps: steps)
        }
        steps.append(SolutionStep(hint: "답", work: shown))
        return Found(answer: shown, concept: parsed.title, steps: steps)
    }

    /// 같은 종류 값이 둘 이상인데 공식이 하나만 골라 썼으면 (저항 두 개 중 첫째, "1시간 30분"의 1시간) 믿지 않음
    private static func ambiguousValues(_ stem: String, title: String) -> Bool {
        let counts = Dictionary(grouping: DoitScience.quantities(in: stem), by: \.dimension).mapValues(\.count)
        let allowed: [String: [String]] = [
            "resistance": ["합성 저항"], "temperature": ["열량", "비열"], "speed": ["가속도"],
            "mass": ["농도", "녹아 있는"]
        ]
        for (dimension, count) in counts where count >= 2 {
            guard let titles = allowed[dimension], titles.contains(where: title.contains) else { return true }
        }
        return false
    }

    private struct Calc {
        var title: String
        var steps: [SolutionStep]
        /// 답 글 앞부분 ("5 m/s")
        var answerHead: String
    }

    /// DoitScience 풀이 글 → 제목·단계·답
    private static func parseCalc(_ reply: String) -> Calc? {
        let lines = reply.components(separatedBy: "\n").map { $0.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard let title = lines.first else { return nil }
        var steps: [SolutionStep] = []
        var answer: String?
        for line in lines.dropFirst() {
            if line.hasPrefix("공식: ") { steps.append(SolutionStep(hint: "공식", work: String(line.dropFirst(4)))) }
            else if line.hasPrefix("단위 맞추기: ") { steps.append(SolutionStep(hint: "단위 맞추기", work: String(line.dropFirst(7)))) }
            else if line.hasPrefix("대입: ") { steps.append(SolutionStep(hint: "값 넣기", work: String(line.dropFirst(4)))) }
            else if line.hasPrefix("답: ") { answer = String(line.dropFirst(3)) }
            else if title.contains("단위 바꾸기"), answer == nil, let eq = line.range(of: " = ") {
                steps.append(SolutionStep(hint: "단위 바꾸기", work: line))
                answer = String(line[eq.upperBound...])
            } else if title.contains("화학식량"), let r = line.range(of: "계산하면: ") {
                answer = String(line[r.upperBound...]) + " g/mol"
            }
        }
        guard var head = answer?.trimmingCharacters(in: .whitespaces), !head.hasPrefix("약") else { return nil }
        // "5 m/s (약 18 km/h)" → "5 m/s", "300 Wh = 1080000 J" → "300 Wh"
        for separator in [" (", " = "] { if let r = head.range(of: separator) { head = String(head[..<r.lowerBound]) } }
        guard !steps.isEmpty else { return nil }
        return Calc(title: title, steps: steps, answerHead: head)
    }

    static func plainNumber(_ text: String) -> DoitScience.Quantity? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard let m = t.firstMatch(of: #/^(-?[0-9]+(?:\.[0-9]+)?)\s*(배|개)?$/#), let v = Double(String(m.1)) else { return nil }
        return DoitScience.Quantity(dimension: "number", si: v, raw: v, unit: m.2.map(String.init) ?? "")
    }

    /// 묻는 단위: "몇 m/s인가", "몇 N의 힘", "(단위: J)"
    private static func askedUnit(_ stem: String) -> (dimension: String, factor: Double, unit: String)? {
        let patterns = [#"몇\s*([A-Za-zΩ℃%μ㎞㎏㎝㎖/²³0-9()·⋅]+)"#, #"단위\s*[:：]\s*([A-Za-zΩ℃%μ/²³0-9()·⋅]+)"#]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let m = regex.firstMatch(in: stem, range: NSRange(stem.startIndex..., in: stem)),
                  let r = Range(m.range(at: 1), in: stem) else { continue }
            var unit = String(stem[r])
            // 짝 없는 닫는 괄호 떼기 ("(단위: J)"의 ")")
            while unit.hasSuffix(")"), unit.filter({ $0 == "(" }).count < unit.filter({ $0 == ")" }).count { unit.removeLast() }
            guard let q = DoitScience.quantities(in: "1 " + unit).first, q.raw == 1 else { return nil }
            return (q.dimension, q.si, q.unit)
        }
        return nil
    }

    /// 선지가 수(와 단위)뿐인지
    private static func isNumericChoice(_ choice: String) -> Bool {
        let t = choice.trimmingCharacters(in: .whitespaces)
        guard t.first(where: { !$0.isWhitespace }).map({ $0.isNumber || $0 == "-" }) == true else { return false }
        let hangul = t.filter { DoitSubjectNote.isHangul($0) }
        return hangul.count <= 3
    }

    /// 선지 값이 계산한 값과 같은지 (단위가 있으면 기본 단위로 바꿔 비교, 없으면 묻는 단위·보여 준 단위의 수로)
    private static func sameValue(_ choice: String, value: DoitScience.Quantity, displayValue: Double, asked: (dimension: String, factor: Double, unit: String)?) -> Bool {
        func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) <= max(1e-9, abs(b) * 2e-3) }
        if let q = DoitScience.quantities(in: choice).first {
            guard q.dimension == value.dimension else { return false }
            return close(q.si, value.si)
        }
        guard let n = plainNumber(choice) else { return false }
        return close(n.raw, displayValue)
    }

    /// DoitScience가 하지 않는 계산: 움직이지 않은 일(0 J), 속력·질량·높이가 몇 배일 때 에너지, 물을 섞은 온도
    private static func scienceSpecial(_ p: Problem) -> Found? {
        let c = p.compact
        // 한 일이 0인 경우
        if matches(c, #"(한일|일의양|일은|일을)"#),
           matches(c, #"(움직이지않|이동하지않|꿈쩍도하지않)"#) || (matches(c, #"(들고|든채)"#) && matches(c, #"수평"#)) {
            let reason = matches(c, #"수평"#) ? "물체를 든 힘(위쪽)과 이동 방향(수평)이 수직이라 힘의 방향으로 이동한 거리가 0이에요."
                                              : "물체가 힘의 방향으로 이동하지 않아서 이동 거리가 0이에요."
            let steps = [SolutionStep(hint: "공식", work: "일 = 힘 × 힘의 방향으로 이동한 거리"), SolutionStep(hint: "이동 거리", work: reason),
                         SolutionStep(hint: "답", work: "0 J")]
            if p.isChoice {
                let hits = p.choices.indices.filter { plainNumber(p.choices[$0].replacingOccurrences(of: "J", with: "").trimmingCharacters(in: .whitespaces))?.raw == 0 }
                guard hits.count == 1 else { return nil }
                return pick(p, index: hits[0], concept: "과학에서 한 일", steps: steps)
            }
            return Found(answer: "0 J", concept: "과학에서 한 일", steps: steps)
        }
        // 몇 배: "속력이 2배가 되면 운동 에너지는 몇 배"
        if let m = c.firstMatch(of: #/(속력|속도|질량|높이)이?([0-9]+)배가?(되면|로하면|로늘리면|일때)/#), let n = Double(String(m.2)),
           c.contains("몇배"), m.1 != "높이" || c.contains("위치에너지") {
            let what = String(m.1)
            var ratio: Double?
            var rule = ""
            if c.contains("운동에너지"), !c.contains("위치에너지") {
                if what == "속력" || what == "속도" { ratio = n * n; rule = "운동 에너지 = ½mv² → 속력의 제곱에 비례" }
                else if what == "질량" { ratio = n; rule = "운동 에너지 = ½mv² → 질량에 비례" }
            } else if c.contains("위치에너지"), !c.contains("운동에너지"), what == "질량" || what == "높이" {
                ratio = n; rule = "위치 에너지 = 9.8mh → 질량과 높이에 각각 비례"
            }
            guard let ratio else { return nil }
            let answer = "\(DoitScience.fmt(ratio))배"
            let steps = [SolutionStep(hint: "비례 관계", work: rule), SolutionStep(hint: "계산", work: "\(what)이 \(DoitScience.fmt(n))배 → \(answer)")]
            if p.isChoice {
                let hits = p.choices.indices.filter { plainNumber(p.choices[$0])?.raw == ratio }
                guard hits.count == 1 else { return nil }
                return pick(p, index: hits[0], concept: "에너지와 비례 관계", steps: steps)
            }
            return Found(answer: answer, concept: "에너지와 비례 관계", steps: steps)
        }
        // 물끼리 섞은 온도 (열평형): (m₁t₁ + m₂t₂) ÷ (m₁ + m₂)
        if c.contains("섞"), c.contains("물"), matches(c, #"(온도|열평형)"#), !matches(c, #"(비열|J/|cal/)"#) {
            let qs = DoitScience.quantities(in: p.stem)
            let masses = qs.filter { $0.dimension == "mass" }, temps = qs.filter { $0.dimension == "temperature" }
            guard masses.count == 2, temps.count == 2 else { return nil }
            // 글 속 순서대로 짝 (20 ℃의 물 100 g과 80 ℃의 물 100 g)
            let m1 = masses[0].si * 1000, m2 = masses[1].si * 1000, t1 = temps[0].si, t2 = temps[1].si
            guard m1 + m2 > 0 else { return nil }
            let t = (m1 * t1 + m2 * t2) / (m1 + m2)
            let answer = "\(DoitScience.fmt(t)) ℃"
            let steps = [SolutionStep(hint: "열평형", work: "뜨거운 물이 잃은 열량 = 차가운 물이 얻은 열량 (같은 물이라 비열이 같아요)"),
                         SolutionStep(hint: "식", work: "나중 온도 = (m₁t₁ + m₂t₂) ÷ (m₁ + m₂)"),
                         SolutionStep(hint: "값 넣기", work: "(\(DoitScience.fmt(m1)) × \(DoitScience.fmt(t1)) + \(DoitScience.fmt(m2)) × \(DoitScience.fmt(t2))) ÷ \(DoitScience.fmt(m1 + m2)) = \(answer)")]
            if p.isChoice {
                let hits = p.choices.indices.filter { i in DoitScience.quantities(in: p.choices[i]).first.map { abs($0.si - t) < 1e-6 && $0.dimension == "temperature" } ?? (plainNumber(p.choices[i])?.raw == t) }
                guard hits.count == 1 else { return nil }
                return pick(p, index: hits[0], concept: "열평형", steps: steps)
            }
            return Found(answer: answer, concept: "열평형", steps: steps)
        }
        return nil
    }

    // MARK: - 분류 (다음 중 ~인 것 / 아닌 것, <보기>에서 ~만을 고른 것)

    /// 분류 하나: 질문에 나오는 이름, 속하는 것, 속하는지 아는 것 전체
    struct Category {
        let names: [String]
        let members: Set<String>
        let universe: Set<String>
        let subject: String
        /// 이름 바로 뒤에 와야 하는 말 ("아시아에", "유럽의"): "유럽 연합" 속 "유럽"을 대륙으로 읽지 않게
        var followers: [String]? = nil
    }

    /// 사실표: 무리 하나(universe) 안에서 각 분류에 속하는 것 (빠짐없이 아는 것만 넣어요)
    private static func group(_ subject: String, _ items: [([String], [String])], extra: [String] = []) -> [Category] {
        let universe = Set((items.flatMap(\.1) + extra).map(key))
        return items.map { Category(names: $0.0, members: Set($0.1.map(key)), universe: universe, subject: subject) }
    }

    static let categories: [Category] = {
        var list: [Category] = []
        // 암석
        let sedimentary = ["사암", "셰일", "이암", "역암", "석회암", "응회암", "암염", "처트"]
        let volcanic = ["현무암", "안산암", "유문암"], plutonic = ["화강암", "반려암", "섬록암"]
        let metamorphic = ["편마암", "대리암", "규암", "편암", "점판암", "혼펠스"]
        list += group("과학", [(["퇴적암"], sedimentary), (["화성암"], volcanic + plutonic), (["화산암"], volcanic), (["심성암"], plutonic),
                              (["변성암"], metamorphic)])
        // 동물
        let mammals = ["고래", "박쥐", "개", "고양이", "사람", "소", "말", "돌고래", "원숭이", "호랑이", "사자", "토끼", "쥐", "코끼리", "캥거루", "곰", "돼지", "다람쥐", "물개", "기린"]
        let birds = ["닭", "참새", "독수리", "펭귄", "타조", "비둘기", "오리", "까치", "앵무새", "부엉이", "제비"]
        let reptiles = ["뱀", "거북", "도마뱀", "악어", "카멜레온", "이구아나"]
        let amphibians = ["개구리", "도롱뇽", "두꺼비", "맹꽁이"]
        let fish = ["붕어", "고등어", "상어", "잉어", "연어", "가오리", "금붕어", "참치", "멸치", "갈치"]
        let insects = ["나비", "개미", "메뚜기", "잠자리", "벌", "꿀벌", "파리", "모기", "매미", "무당벌레", "사마귀", "바퀴벌레", "딱정벌레", "나방"]
        let otherArthropods = ["거미", "게", "새우", "가재", "지네", "전갈", "노래기"]
        let otherInvertebrates = ["지렁이", "오징어", "문어", "달팽이", "조개", "불가사리", "해파리", "말미잘", "성게", "해삼"]
        let vertebrates = mammals + birds + reptiles + amphibians + fish
        list += group("과학", [(["포유류"], mammals), (["조류"], birds), (["파충류"], reptiles), (["양서류"], amphibians), (["어류"], fish),
                              (["척추동물"], vertebrates), (["무척추동물"], insects + otherArthropods + otherInvertebrates),
                              (["곤충", "곤충류"], insects), (["절지동물"], insects + otherArthropods)])
        // 세포 소기관 (액포는 식물 세포에서 크게 발달해서 '공통'에서는 아닌 것으로, '식물 세포에만'에서는 넣지 않음)
        let shared = ["핵", "세포막", "세포질", "미토콘드리아"], plantOnly = ["세포벽", "엽록체"]
        list.append(Category(names: ["모두 있는", "공통으로 있는", "공통적으로 있는", "모두 가지고 있는", "공통으로 가지고"], members: Set(shared.map(key)),
                             universe: Set((shared + plantOnly + ["액포"]).map(key)), subject: "과학"))
        list.append(Category(names: ["식물 세포에만", "식물 세포에서만"], members: Set(plantOnly.map(key)),
                             universe: Set((shared + plantOnly).map(key)), subject: "과학"))
        // 행성
        list += group("과학", [(["지구형 행성"], ["수성", "금성", "지구", "화성"]), (["목성형 행성"], ["목성", "토성", "천왕성", "해왕성"]),
                              (["내행성"], ["수성", "금성"]), (["외행성"], ["화성", "목성", "토성", "천왕성", "해왕성"])], extra: ["지구"])
        // 물질 (소금은 천일염처럼 섞인 것도 있어서 넣지 않음)
        let elementsList = ["산소", "수소", "질소", "철", "금", "은", "구리", "알루미늄", "탄소", "헬륨", "네온", "나트륨", "마그네슘", "황", "다이아몬드", "아연", "납"]
        let compounds = ["물", "증류수", "염화 나트륨", "설탕", "이산화 탄소", "에탄올", "암모니아", "포도당", "메테인", "물(H2O)", "녹말", "드라이아이스"]
        let mixtures = ["공기", "바닷물", "소금물", "설탕물", "우유", "흙탕물", "탄산음료", "콜라", "식초", "간장", "청동", "합금", "석유", "혈액", "탄산수", "과일 주스", "김밥", "화강암", "흙"]
        list += group("과학", [(["순물질"], elementsList + compounds), (["혼합물"], mixtures), (["원소"], elementsList), (["화합물"], compounds)])
        // 액성
        let acids = ["식초", "레몬즙", "탄산음료", "염산", "위액", "사이다", "콜라", "묽은 염산", "탄산수"]
        let bases = ["비눗물", "암모니아수", "석회수", "수산화 나트륨 수용액", "하수구 세정제", "제산제", "베이킹 소다 용액", "유리 세정제"]
        let neutral = ["설탕물", "소금물", "증류수", "순수한 물"]
        list += group("과학", [(["산성"], acids), (["염기성"], bases), (["중성"], neutral)])
        // 상태 변화 (승화는 두 방향이 있어 넣지 않음)
        list += group("과학", [(["열을 흡수", "열에너지를 흡수", "주변에서 열을 흡수"], ["융해", "기화", "증발", "끓음"]),
                              (["열을 방출", "열에너지를 방출", "주변으로 열을 방출"], ["응고", "액화"])])
        // 에너지 자원
        let renewable = ["태양광", "태양열", "풍력", "수력", "지열", "조력", "파력", "바이오 에너지", "해양 에너지"]
        let fossil = ["석탄", "석유", "천연가스"]
        list += group("사회", [(["재생 에너지", "신재생 에너지", "재생 가능 에너지"], renewable), (["화석 연료", "화석 에너지"], fossil)], extra: ["원자력"])
        // 기본권
        let freedom = ["신체의 자유", "거주·이전의 자유", "거주 이전의 자유", "종교의 자유", "언론·출판의 자유", "언론의 자유", "집회·결사의 자유",
                       "직업 선택의 자유", "양심의 자유", "사생활의 자유", "학문의 자유", "예술의 자유", "재산권"]
        let participation = ["선거권", "피선거권", "공무 담임권", "국민 투표권"]
        let social = ["교육을 받을 권리", "교육받을 권리", "근로의 권리", "환경권", "인간다운 생활을 할 권리", "근로 3권", "노동 3권"]
        let claim = ["재판 청구권", "재판을 받을 권리", "청원권", "국가 배상 청구권", "형사 보상 청구권"]
        list += group("사회", [(["자유권"], freedom), (["참정권"], participation), (["사회권"], social), (["청구권"], claim), (["평등권"], ["평등권"])])
        // 사회 보장
        list += group("사회", [(["사회 보험"], ["국민연금", "건강 보험", "국민 건강 보험", "고용 보험", "산업 재해 보상 보험", "산재 보험", "노인 장기 요양 보험"]),
                              (["공공 부조"], ["국민 기초 생활 보장", "의료 급여"])])
        // 조세
        list += group("사회", [(["직접세"], ["소득세", "법인세", "상속세", "증여세", "재산세", "종합 부동산세"]),
                              (["간접세"], ["부가 가치세", "개별 소비세", "주세", "관세", "인지세", "증권 거래세"])])
        // 산업 (우리나라 분류: 광업은 2차 산업)
        list += group("사회", [(["1차 산업"], ["농업", "어업", "임업", "목축업", "축산업"]),
                              (["2차 산업"], ["제조업", "건설업", "광업", "전기·가스업"]),
                              (["3차 산업"], ["서비스업", "금융업", "관광업", "운수업", "상업", "도소매업", "숙박업", "음식점업", "통신업", "교육 서비스업"])])
        // 대륙 (두 대륙에 걸친 나라는 넣지 않음)
        let continents = ["아시아", "유럽", "아프리카", "북아메리카", "남아메리카", "오세아니아"]
        let countries = DoitSocial.countryList.filter { continents.contains($0.continent) }
        let countryUniverse = Set(countries.flatMap { $0.names.map(key) })
        for continent in continents {
            let members = Set(countries.filter { $0.continent == continent }.flatMap { $0.names.map(key) })
            var names = [continent]
            if continent == "남아메리카" { names.append("남미") }
            if continent == "북아메리카" { names.append("북미") }
            list.append(Category(names: names, members: members, universe: countryUniverse, subject: "사회",
                                 followers: ["에", "의", "대륙", "지역", "주에"]))
        }
        // 금속·비금속 원소 (준금속은 넣지 않음)
        let known = DoitScience.elementList.filter { $0.number <= 56 || ["Au", "Hg", "Pb", "Pt", "U"].contains($0.symbol) }
        let metals = known.filter { $0.kind.hasPrefix("금속") }, nonmetals = known.filter { $0.kind.hasPrefix("비금속") || $0.kind.hasPrefix("비활성") }
        let names: (DoitScience.ElementInfo) -> [String] = { [$0.name] + $0.aliases }
        let elementUniverse = Set((metals + nonmetals).flatMap(names).map(key))
        list.append(Category(names: ["금속 원소", "금속"], members: Set(metals.flatMap(names).map(key)), universe: elementUniverse, subject: "과학"))
        list.append(Category(names: ["비금속 원소", "비금속"], members: Set(nonmetals.flatMap(names).map(key)), universe: elementUniverse, subject: "과학"))
        return list + moreCategories
    }()

    /// 질문에 나온 분류 (더 긴 이름에 들어 있는 짧은 이름은 빼고, 둘 이상이면 nil)
    private static func askedCategory(_ p: Problem) -> Category? {
        let c = key(p.stem)
        var found: [(Category, Range<String.Index>)] = []
        for category in categories {
            for name in category.names {
                let k = key(name)
                var from = c.startIndex
                while let r = c.range(of: k, range: from..<c.endIndex) {
                    from = r.upperBound
                    if let followers = category.followers, !followers.contains(where: { c[r.upperBound...].hasPrefix($0) }) { continue }
                    found.append((category, r))
                }
            }
        }
        // 다른 이름 안에 들어 있는 것 ("비금속" 속 "금속")은 빼요
        let kept = found.filter { item in
            !found.contains { other in other.1 != item.1 && other.1.contains(item.1.lowerBound) && other.1.upperBound >= item.1.upperBound
                && c.distance(from: other.1.lowerBound, to: other.1.upperBound) > c.distance(from: item.1.lowerBound, to: item.1.upperBound) }
        }
        let distinct = Dictionary(grouping: kept, by: { $0.0.names[0] })
        guard distinct.count == 1, let category = kept.first?.0 else { return nil }
        return category
    }

    static func category(_ p: Problem) -> Found? {
        guard let cat = askedCategory(p) else { return nil }
        let c = p.compact
        guard matches(c, #"(것|나라|고른|고르면|물질은|원소는|암석은|동물은|행성은|산업은|세금은|권리는|에너지는|해당|속하|있는|위치한|인것|변화는|(은|는)\??$)"#) else { return nil }
        // <보기>에서 있는 대로 고르기
        if !p.box.isEmpty, p.isChoice, matches(c, #"(있는대로|모두|만을|만고른|고른것)"#) {
            var chosen = Set<Character>()
            var lines: [String] = []
            for item in p.box {
                guard let letter = item.first, "ㄱㄴㄷㄹㅁ".contains(letter) else { return nil }
                let name = item.dropFirst().trimmingCharacters(in: CharacterSet(charactersIn: ". )").union(.whitespaces))
                let k = key(name)
                guard cat.universe.contains(k) else { return nil }
                let isMember = cat.members.contains(k)
                if isMember != p.negated { chosen.insert(letter) }
                lines.append("\(letter). \(name): \(cat.names[0])\(isMember ? "이에요" : "이 아니에요")")
            }
            let hits = p.choices.indices.filter { letters(p.choices[$0]) == chosen }
            guard hits.count == 1 else { return nil }
            let steps = lines.map { SolutionStep(hint: "", work: $0) } + [SolutionStep(hint: "고를 것", work: chosen.sorted().map(String.init).joined(separator: ", "))]
            return pick(p, index: hits[0], concept: "\(cat.names[0]) 구분하기", steps: steps)
        }
        guard p.isChoice, p.box.isEmpty else { return nil }
        var steps: [SolutionStep] = []
        var hits: [Int] = []
        for (i, choice) in p.choices.enumerated() {
            let k = key(choice)
            guard cat.universe.contains(k) else { return nil }
            let isMember = cat.members.contains(k)
            steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(choice): \(cat.names[0])\(isMember ? "이에요" : "이 아니에요")"))
            if isMember != p.negated { hits.append(i) }
        }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: "\(cat.names[0]) 구분하기", steps: steps)
    }

    /// 선지의 ㄱ·ㄴ·ㄷ 모음 ("ㄱ, ㄷ" → {ㄱ, ㄷ})
    static func letters(_ choice: String) -> Set<Character>? {
        let t = choice.filter { !" ,·.、".contains($0) }
        guard !t.isEmpty, t.allSatisfy({ "ㄱㄴㄷㄹㅁ".contains($0) }) else { return nil }
        return Set(t)
    }

    // MARK: - 사실표 (설명 → 이름)

    /// 문제 글(띄어쓰기 뺌)에 맞는 꼴이 있으면 그 답. 묻는 말까지 꼴에 넣어 엉뚱한 물음에 걸리지 않게
    struct Fact {
        let answers: [String]
        let patterns: [String]
        let why: String
    }

    private static func f(_ answers: [String], _ patterns: [String], _ why: String) -> Fact { Fact(answers: answers, patterns: patterns, why: why) }

    static let factTable: [Fact] = [
        // 세포
        f(["엽록체"], [#"광합성이?일어나는.{0,6}(장소|곳|세포소기관|구조)"#, #"광합성을?하는.{0,6}(장소|곳|세포소기관|구조)"#], "엽록체는 빛 에너지로 광합성을 하는 곳이에요."),
        f(["미토콘드리아"], [#"세포호흡이?일어나.{0,30}(세포소기관|곳|장소|구조)"#, #"에너지를(만드|생성하|얻)는.{0,6}(세포소기관|곳|구조)"#], "미토콘드리아에서 세포 호흡으로 생명 활동에 필요한 에너지를 만들어요."),
        f(["핵"], [#"유전물질.{0,30}(곳|것|세포소기관|구조)는?\?"#, #"생명활동을조절하는(곳|것|구조|세포소기관)"#], "핵에는 유전 물질(DNA)이 있어 세포의 생명 활동을 조절해요."),
        f(["세포막"], [#"물질이?.{0,8}(출입|드나드).{0,10}조절하는(것|곳|구조)"#], "세포막은 세포를 둘러싸고 물질이 드나드는 것을 조절해요."),
        f(["세포벽"], [#"식물세포의?모양을.{0,8}유지.{0,20}(것|곳|구조)"#], "세포벽은 식물 세포의 모양을 일정하게 유지하고 보호해요."),
        // 광합성 · 호흡
        f(["산소", "O2", "O₂"], [#"광합성.{0,10}(결과|생성|만들어지|발생|나오|내보내).{0,8}기체"#, #"호흡.{0,10}(필요한|사용하는|쓰이는|이용하는)기체"#], "광합성: 이산화 탄소 + 물 → (빛) 포도당 + 산소. 호흡에는 산소가 쓰여요."),
        f(["이산화 탄소", "이산화탄소", "CO2", "CO₂"], [#"광합성.{0,10}(필요한|쓰이는|사용되는|사용하는|재료가?되는|흡수하는)기체"#, #"호흡.{0,10}(결과|생성|발생|나오|내보내).{0,8}기체"#], "광합성의 재료는 이산화 탄소와 물이고, 호흡 결과 이산화 탄소가 나와요."),
        f(["아이오딘 용액", "아이오딘-아이오딘화 칼륨 용액", "요오드 용액"], [#"녹말.{0,10}(검출|확인).{0,10}(용액|시약)"#], "녹말은 아이오딘 용액과 만나면 청람색이 돼요."),
        f(["베네딕트 용액"], [#"(포도당|엿당).{0,10}(검출|확인).{0,10}(용액|시약)"#], "포도당·엿당은 베네딕트 용액을 넣고 가열하면 황적색이 돼요."),
        f(["뷰렛 용액", "뷰렛 반응"], [#"단백질.{0,10}(검출|확인).{0,10}(용액|시약)"#], "단백질은 뷰렛 용액과 만나면 보라색이 돼요."),
        f(["수단 Ⅲ 용액", "수단3 용액", "수단III 용액"], [#"지방.{0,10}(검출|확인).{0,10}(용액|시약)"#], "지방은 수단 Ⅲ 용액과 만나면 선홍색이 돼요."),
        // 혈액 · 소화
        f(["적혈구"], [#"산소를?운반하는"#], "적혈구의 헤모글로빈이 산소를 운반해요."),
        f(["혈소판"], [#"(혈액을?응고|피를?굳게|혈액응고에관여|출혈을멈추)"#], "혈소판은 상처가 났을 때 혈액을 응고시켜요."),
        f(["백혈구"], [#"(식균작용|세균을.{0,4}(잡아먹|제거))"#], "백혈구는 몸속에 들어온 세균을 잡아먹어요(식균 작용)."),
        f(["아밀레이스", "아밀라아제"], [#"녹말을?엿당으로분해"#], "침 속 아밀레이스가 녹말을 엿당으로 분해해요."),
        f(["펩신"], [#"위액.{0,15}단백질을?분해.{0,8}(효소)"#], "위액 속 펩신이 단백질을 분해해요."),
        f(["라이페이스", "리파아제"], [#"지방을?(지방산과모노글리세리드로)?분해하는.{0,6}효소"#], "라이페이스는 지방을 지방산과 모노글리세리드로 분해해요."),
        // 상태 변화
        f(["융해"], [#"고체(가|에서|이)?액체로(변|바뀌|되)"#], "고체 → 액체: 융해 (열을 흡수해요)"),
        f(["응고"], [#"액체(가|에서|이)?고체로(변|바뀌|되)"#], "액체 → 고체: 응고 (열을 방출해요)"),
        f(["기화"], [#"액체(가|에서|이)?기체로(변|바뀌|되)"#], "액체 → 기체: 기화 (열을 흡수해요)"),
        f(["액화"], [#"기체(가|에서|이)?액체로(변|바뀌|되)"#], "기체 → 액체: 액화 (열을 방출해요)"),
        f(["승화"], [#"고체(가|에서|이)?액체(상태)?를?거치지않고.{0,4}기체로"#, #"기체(가|에서|이)?액체(상태)?를?거치지않고.{0,4}고체로"#,
                    #"(드라이아이스|나프탈렌|좀약).{0,12}(작아지|사라지|없어지).{0,20}(상태변화|현상)"#], "고체 ↔ 기체로 바로 변하는 것: 승화"),
        // 생활 속 상태 변화
        f(["융해"], [#"(얼음|아이스크림|버터|초콜릿|눈)이?.{0,4}녹.{0,20}(상태변화|현상)"#], "고체가 녹아 액체가 되는 것: 융해"),
        f(["응고"], [#"(물|촛농|용암|쇳물)이?.{0,6}(얼어|얼면|얼|굳).{0,20}(상태변화|현상)"#], "액체가 얼거나 굳어 고체가 되는 것: 응고"),
        f(["기화"], [#"(젖은빨래|빨래|물웅덩이|머리카락)가?이?.{0,6}(마르|말라|마른).{0,20}(상태변화|현상)"#], "액체가 기체(수증기)로 되는 것: 기화(증발)"),
        f(["액화"], [#"(이슬이?맺|김이?서리|물방울이?맺|안경에김).{0,20}(상태변화|현상)"#], "수증기(기체)가 차가운 곳에서 물(액체)이 되는 것: 액화"),
        // 물리
        f(["관성"], [#"(원래|처음|현재)의?(운동)?상태를.{0,8}유지하려는성질"#], "물체가 원래의 운동 상태를 유지하려는 성질이 관성이에요(뉴턴 운동 제1법칙)."),
        f(["N", "뉴턴"], [#"(?<![가-힣])힘의(크기의)?단위"#], "힘의 단위는 N(뉴턴)이에요."),
        f(["W", "와트"], [#"(일률|전력)의단위"#], "일률·전력의 단위는 W(와트)예요."),
        f(["J", "줄"], [#"(?<![가-힣])(일|에너지)의단위"#], "일·에너지의 단위는 J(줄)이에요."),
        f(["Pa", "파스칼", "N/m²"], [#"압력의단위"#], "압력의 단위는 Pa(파스칼) = N/m²이에요."),
        f(["Ω", "옴", "ohm"], [#"(전기)?저항의단위"#], "저항의 단위는 Ω(옴)이에요."),
        f(["A", "암페어"], [#"전류의(세기의)?단위"#], "전류의 단위는 A(암페어)예요."),
        f(["V", "볼트"], [#"전압의단위"#], "전압의 단위는 V(볼트)예요."),
        f(["Hz", "헤르츠"], [#"진동수의단위"#], "진동수의 단위는 Hz(헤르츠)예요."),
        f(["복사"], [#"(물질|매질|입자)을?(거치지|통하지|이용하지)않고.{0,15}(이동|전달)"#], "물질을 거치지 않고 열이 직접 전달되는 방식은 복사예요(태양열)."),
        f(["대류"], [#"(액체|기체).{0,15}(물질|입자|분자)이?직접이동.{0,10}(열|전달)"#], "액체·기체에서 물질이 직접 이동하며 열을 전달하는 방식은 대류예요."),
        f(["전도"], [#"고체.{0,15}(이웃한|옆)(입자|분자).{0,10}전달"#], "고체에서 이웃한 입자로 열이 전달되는 방식은 전도예요."),
        // 지구과학
        f(["지구의 자전", "자전"], [#"낮과밤이?.{0,6}(반복|생기|나타나|바뀌)"#], "지구가 하루에 한 바퀴 자전해서 낮과 밤이 반복돼요."),
        f(["대류권"], [#"기상현상이?.{0,8}(나타나|일어나).{0,10}(층|권)"#], "대류권에서는 공기가 대류하고 수증기가 있어 기상 현상이 나타나요."),
        f(["성층권"], [#"오존층이?.{0,6}(있는|존재하는).{0,10}(층|권)"#], "성층권에 오존층이 있어 자외선을 흡수해요."),
        f(["열권"], [#"오로라.{0,10}(나타나|관측되|생기).{0,10}(층|권)"#], "오로라는 열권에서 나타나요."),
        f(["외핵"], [#"지구내부.{0,20}액체.{0,12}(층|부분)"#], "외핵은 액체 상태로 추정돼요(S파가 통과하지 못함)."),
        f(["맨틀"], [#"지구내부.{0,20}(가장큰부피|부피가가장큰|부피가가장크)"#], "맨틀은 지구 전체 부피의 약 80%를 차지해요."),
        // 사회 · 경제
        f(["기회비용", "기회 비용"], [#"포기한.{0,20}가장.{0,6}(큰|높은)"#, #"포기하게되는.{0,20}가장.{0,6}(큰|높은)"#], "선택으로 포기한 것 중 가장 가치가 큰 것이 기회비용이에요."),
        f(["희소성"], [#"욕구에비해.{0,10}(자원|재화|수단).{0,10}부족"#], "욕구에 비해 자원이 상대적으로 부족한 것이 희소성이에요(양이 적은 희귀성과 달라요)."),
        f(["인플레이션"], [#"물가가?.{0,6}(지속적으로|계속).{0,6}(오르|상승)"#], "물가가 지속적으로 오르는 현상이 인플레이션이에요."),
        f(["디플레이션"], [#"물가가?.{0,6}(지속적으로|계속).{0,6}(내려|하락|떨어)"#], "물가가 지속적으로 내려가는 현상이 디플레이션이에요."),
        f(["권력 분립", "삼권 분립", "권력분립", "삼권분립"], [#"입법권.{0,3}행정권.{0,3}사법권.{0,20}(나누|분리).{0,20}(원리|제도)"#], "국가 권력을 입법·행정·사법으로 나눠 견제하게 하는 원리는 권력 분립(삼권 분립)이에요."),
        f(["국회"], [#"(법을만드는|법률을만드는|입법권을가진).{0,10}(국가기관|기관)"#], "입법권(법을 만드는 권한)은 국회가 가져요."),
        f(["법원"], [#"(재판을통해|사법권을가진).{0,20}(국가기관|기관)"#], "사법권(재판으로 법을 적용하는 권한)은 법원이 가져요."),
        f(["정부", "행정부"], [#"(행정권을가진|법을집행하는).{0,10}(국가기관|기관)"#], "행정권(법을 집행하는 권한)은 정부가 가져요."),
        f(["평등 선거"], [#"(한사람이?한표|1인1표)"#], "누구나 똑같이 한 표씩 가지는 것은 평등 선거예요."),
        f(["보통 선거"], [#"일정한?(나이|연령)가?이?되면.{0,10}(누구나|모든)"#, #"(누구나|모든국민이?).{0,4}일정한?(나이|연령)가?이?되면"#], "일정한 나이가 되면 누구나 투표할 수 있는 것은 보통 선거예요."),
        f(["비밀 선거"], [#"(누구를|어떤후보를).{0,8}(뽑았는지|찍었는지|투표했는지).{0,10}(모르|비밀|알수없)"#], "누구를 뽑았는지 알 수 없게 하는 것은 비밀 선거예요."),
        f(["수요 법칙", "수요의 법칙"], [#"가격이?(오르면|상승하면).{0,6}수요량이?.{0,4}(감소|줄)"#, #"가격이?(내리면|하락하면).{0,6}수요량이?.{0,4}(증가|늘)"#], "가격이 오르면 수요량이 줄고 내리면 늘어나는 것이 수요 법칙이에요."),
        f(["공급 법칙", "공급의 법칙"], [#"가격이?(오르면|상승하면).{0,6}공급량이?.{0,4}(증가|늘)"#, #"가격이?(내리면|하락하면).{0,6}공급량이?.{0,4}(감소|줄)"#], "가격이 오르면 공급량이 늘고 내리면 줄어드는 것이 공급 법칙이에요."),
        f(["자문화 중심주의"], [#"자기(나라)?문화만.{0,6}우월"#], "자기 문화만 우월하다고 보고 다른 문화를 낮게 보는 태도는 자문화 중심주의예요."),
        f(["문화 사대주의"], [#"다른(나라|사회)의?문화.{0,6}(우월|우수).{0,20}자기문화.{0,6}(낮|열등|업신)"#], "다른 문화를 우월하게 보고 자기 문화를 낮게 보는 태도는 문화 사대주의예요."),
        f(["문화 상대주의"], [#"(그사회|그문화|각사회).{0,20}(맥락|환경|배경|상황).{0,10}이해"#], "각 문화를 그 사회의 환경과 맥락에서 이해하려는 태도는 문화 상대주의예요."),
        f(["몽테스키외"], [#"(삼권분립|권력분립).{0,10}(주장|제시|사상가|인물)"#], "몽테스키외가 『법의 정신』에서 삼권 분립을 주장했어요."),
        f(["1시간", "1"], [#"경도15°?(도)?마다.{0,10}(몇시간|시차)"#], "지구는 24시간에 360° 자전하므로 경도 15°마다 1시간의 시차가 생겨요."),
        f(["동경 135°", "동경135°", "동경 135도", "135°E"], [#"우리나라.{0,6}표준(시|경선).{0,15}(기준|경선)"#], "우리나라는 동경 135°를 표준 경선으로 써요.")
    ]

    static func facts(_ p: Problem) -> Found? {
        let c = p.compact
        var hits = (factTable + moreFacts).filter { fact in fact.patterns.contains { matches(c, $0) } }
        // 꼴이 둘 이상 걸리면 (물가 상승 → 인플레이션 / 화폐 가치) 선지에 답이 있는 사실 하나만
        if Set(hits.map { key($0.answers[0]) }).count > 1, p.isChoice {
            hits = hits.filter { fact in p.choices.contains { choice in fact.answers.contains { key($0) == key(choice) } } }
        }
        // 사실 꼴 안의 '않는·아닌'("분해되지 않는", "사람이 아닌")은 틀린 것을 묻는 말이 아님
        //   (꼴에 그 말이 글자 그대로 들어 있을 때만 빼요: ".{0,30}" 같은 틈에 들어간 '않는'은 묻는 말일 수 있어서)
        let outside = hits.reduce(c) { text, fact in
            fact.patterns.filter { $0.contains("않") || $0.contains("아닌") }.reduce(text) { $0.replacingOccurrences(of: $1, with: "", options: .regularExpression) }
        }
        let negated = ["아닌", "않은", "않는", "틀린", "잘못", "옳지않", "알맞지않", "바르지않", "적절하지않", "해당하지않"].contains { outside.contains($0) }
        guard let first = hits.first, Set(hits.map { key($0.answers[0]) }).count == 1, !negated else { return nil }
        let steps = [SolutionStep(hint: "개념", work: first.why)]
        if p.isChoice {
            guard let index = uniqueChoice(p, matching: first.answers) else { return nil }
            return pick(p, index: index, concept: first.answers[0], steps: steps)
        }
        return Found(answer: first.answers[0], concept: first.answers[0], steps: steps)
    }

    // MARK: - 빛의 합성

    static func colorMix(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"(합성|겹치|섞|함께비추)"#), c.contains("빛") else { return nil }
        var colors = Set<String>()
        if matches(c, #"빨간?(색)?빛|빨강"#) { colors.insert("빨강") }
        if matches(c, #"초록(색)?빛|초록|녹색빛"#) { colors.insert("초록") }
        if matches(c, #"파란?(색)?빛|파랑"#) { colors.insert("파랑") }
        guard colors.count >= 2, !matches(c, #"(노란|노랑|자홍|청록)(색)?빛(과|와|을|를)"#) else { return nil }
        let result: [String]
        switch colors {
        case ["빨강", "초록"]: result = ["노란색", "노랑", "노란"]
        case ["빨강", "파랑"]: result = ["자홍색", "자홍", "마젠타"]
        case ["초록", "파랑"]: result = ["청록색", "청록", "시안"]
        default: result = ["흰색", "하얀색", "백색"]
        }
        let steps = [SolutionStep(hint: "빛의 합성", work: "빨강 + 초록 = 노랑, 빨강 + 파랑 = 자홍, 초록 + 파랑 = 청록, 세 빛 모두 = 흰색"),
                     SolutionStep(hint: "이 문제", work: colors.sorted().joined(separator: " + ") + " = " + result[0])]
        if p.isChoice {
            guard let index = uniqueChoice(p, matching: result) else { return nil }
            return pick(p, index: index, concept: "빛의 삼원색과 합성", steps: steps)
        }
        return Found(answer: result[0], concept: "빛의 삼원색과 합성", steps: steps)
    }

    // MARK: - 원소 (주기율표)

    static func element(_ p: Problem) -> Found? {
        let stem = p.stem
        let c = p.compact
        guard matches(c, #"(원소기호|원자번호)"#) else { return nil }
        let list = DoitScience.elementList
        // 원소와 원소 기호 짝 고르기 ("구리 - Cu")
        if p.isChoice, p.choices.allSatisfy({ $0.contains("-") || $0.contains("–") || $0.contains(":") }) {
            var hits: [Int] = []
            var steps: [SolutionStep] = []
            for (i, choice) in p.choices.enumerated() {
                let parts = choice.components(separatedBy: CharacterSet(charactersIn: "-–:")).map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2 else { return nil }
                let (name, symbol) = parts[0].first?.isASCII == true ? (parts[1], parts[0]) : (parts[0], parts[1])
                guard let e = list.first(where: { ([$0.name] + $0.aliases).contains(name) }) else { return nil }
                let ok = e.symbol == symbol
                steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(name)의 원소 기호는 \(e.symbol)" + (ok ? " ✓" : "")))
                if ok != p.negated { hits.append(i) }
            }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "원소 기호", steps: steps)
        }
        // 주어진 것: 원소 기호 · 원자 번호 · 이름
        var given: DoitScience.ElementInfo?
        var how = ""
        if let m = stem.firstMatch(of: #/원소\s*기호(?:가|는|이)?\s*([A-Z][a-z]?)(?![A-Za-z])/#) ?? stem.firstMatch(of: #/(?:^|[^A-Za-z])([A-Z][a-z]?)(?![A-Za-z])\s*(?:가|이|는|은|로)?\s*(?:나타내는|가리키는|인)\s*원소/#) {
            let symbol = String(m.1)
            given = list.first { $0.symbol == symbol }
            how = "원소 기호 \(symbol)"
        } else if let m = c.firstMatch(of: #/원자번호가?([0-9]{1,3})(번|인|의)/#), let z = Int(String(m.1)) {
            given = list.first { $0.number == z }
            how = "원자 번호 \(z)"
        } else {
            // "칼슘의 원소 기호는?"
            let named = list.filter { e in ([e.name] + e.aliases).contains { name in c.hasPrefix(name + "의원소기호") || c.contains(name + "의원소기호") && !c.contains("원소기호가") } }
            if named.count == 1 { given = named[0]; how = named[0].name }
        }
        guard let e = given else { return nil }
        // 묻는 것
        let tail = c.components(separatedBy: how.filter { !$0.isWhitespace }).last ?? c
        let asksSymbol = matches(tail, #"원소기호(는|로|를|가무엇)"#) && !how.hasPrefix("원소 기호")
        let asksNumber = matches(tail, #"원자번호(는|를)"#) && !how.hasPrefix("원자 번호")
        // 몇 족 · 몇 주기를 물으면 그 수 (족을 모르는 원소는 답하지 않아요)
        let asksGroup = matches(tail, #"몇족"#), asksPeriod = matches(tail, #"몇주기"#)
        if asksGroup || asksPeriod {
            guard asksGroup != asksPeriod, !asksSymbol, !asksNumber, !asksGroup || e.group > 0 else { return nil }
            let n = asksGroup ? e.group : e.period, unit = asksGroup ? "족" : "주기"
            let steps = [SolutionStep(hint: "주기율표", work: "\(e.name)(\(e.symbol)): 원자 번호 \(e.number), \(e.period)주기" + (e.group > 0 ? " \(e.group)족" : ""))]
            if p.isChoice {
                let hits = p.choices.indices.filter { key(p.choices[$0]) == key("\(n)\(unit)") || key(p.choices[$0]) == "\(n)" }
                guard hits.count == 1 else { return nil }
                return pick(p, index: hits[0], concept: "주기율표", steps: steps)
            }
            return Found(answer: "\(n)\(unit)", concept: "주기율표", steps: steps + [SolutionStep(hint: "답", work: "\(n)\(unit)")])
        }
        let answers: [String] = asksSymbol ? [e.symbol] : asksNumber ? ["\(e.number)", "\(e.number)번"] : [e.name] + e.aliases
        let steps = [SolutionStep(hint: "주기율표", work: "\(e.name)(\(e.symbol)): 원자 번호 \(e.number), \(e.period)주기" + (e.group > 0 ? " \(e.group)족" : "") + ", \(e.kind)")]
        if p.isChoice {
            let hits = p.choices.indices.filter { i in answers.contains { a in asksSymbol ? p.choices[i].trimmingCharacters(in: .whitespaces) == a : key(p.choices[i]) == key(a) } }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "주기율표와 원소 기호", steps: steps)
        }
        return Found(answer: answers[0], concept: "주기율표와 원소 기호", steps: steps)
    }

    // MARK: - 사회: 수도 · 연도 · 인물 · 사건 순서

    static func socialLookup(_ p: Problem) -> Found? { capital(p) ?? eventQuestion(p) }

    private static func capital(_ p: Problem) -> Found? {
        let c = key(p.stem)
        guard c.contains("수도") else { return nil }
        let countries = DoitSocial.countryList
        func countryNamed(_ name: String) -> (names: [String], capital: String, capitalAliases: [String], continent: String)? {
            let k = key(name)
            return countries.first { $0.names.contains { key($0) == k } }
        }
        // 나라 - 수도 짝
        if p.isChoice, p.choices.allSatisfy({ $0.contains("-") || $0.contains("–") || $0.contains(":") }) {
            var hits: [Int] = []
            var steps: [SolutionStep] = []
            for (i, choice) in p.choices.enumerated() {
                let parts = choice.components(separatedBy: CharacterSet(charactersIn: "-–:")).map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2, let country = countryNamed(parts[0]) else { return nil }
                let ok = ([country.capital] + country.capitalAliases).contains { key($0) == key(parts[1]) }
                steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(country.names[0])의 수도는 \(country.capital)" + (ok ? " ✓" : "")))
                if ok != p.negated { hits.append(i) }
            }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "나라와 수도", steps: steps)
        }
        guard !p.negated else { return nil }
        // "수도가 하노이인 나라는?"
        if c.contains("수도가") || c.contains("수도인"), c.contains("나라") {
            var best: (country: (names: [String], capital: String, capitalAliases: [String], continent: String), length: Int)?
            for country in countries {
                for name in [country.capital] + country.capitalAliases where key(name).count >= 2 && c.contains(key(name)) {
                    if key(name).count > (best?.length ?? 0) { best = (country, key(name).count) }
                }
            }
            guard let country = best?.country else { return nil }
            let steps = [SolutionStep(hint: "수도", work: "\(country.capital)은(는) \(country.names[0])의 수도예요. (\(country.continent))")]
            if p.isChoice {
                guard let index = uniqueChoice(p, matching: country.names) else { return nil }
                return pick(p, index: index, concept: "나라와 수도", steps: steps)
            }
            return Found(answer: country.names[0], concept: "나라와 수도", steps: steps)
        }
        // "프랑스의 수도는?"
        var best: (country: (names: [String], capital: String, capitalAliases: [String], continent: String), length: Int)?
        for country in countries {
            for name in country.names where c.contains(key(name) + "의수도") || c.hasPrefix(key(name) + "수도") {
                if key(name).count > (best?.length ?? 0) { best = (country, key(name).count) }
            }
        }
        guard let country = best?.country else { return nil }
        let steps = [SolutionStep(hint: "수도", work: "\(country.names[0])의 수도는 \(country.capital)이에요. (\(country.continent))")]
        if p.isChoice {
            guard let index = uniqueChoice(p, matching: [country.capital] + country.capitalAliases) else { return nil }
            return pick(p, index: index, concept: "나라와 수도", steps: steps)
        }
        return Found(answer: country.capital, concept: "나라와 수도", steps: steps)
    }

    static func yearText(_ year: Int) -> String { year < 0 ? "기원전 \(-year)년" : "\(year)년" }

    /// 글 속 사건 이름 (이름의 낱말이 차례대로 나오면: "훈민정음이 반포된" ↔ "훈민정음 반포")
    private static func events(in text: String) -> [(year: Int, names: [String], who: String?, score: Int, end: Int?)] {
        let compact = key(text)
        var found: [(year: Int, names: [String], who: String?, score: Int, end: Int?)] = []
        for e in DoitSocial.eventDetails where !e.approx {
            var best = 0
            for name in e.names {
                let words = name.components(separatedBy: " ").map(key).filter { !$0.isEmpty }
                guard !words.isEmpty else { continue }
                var from = compact.startIndex
                var ok = true
                for word in words {
                    guard let r = compact.range(of: word, range: from..<compact.endIndex) else { ok = false; break }
                    from = r.upperBound
                }
                let length = words.reduce(0) { $0 + $1.count }
                if ok, length >= 2, length > best { best = length }
            }
            if best > 0 { found.append((e.year, e.names, e.who, best, e.end)) }
        }
        return found.sorted { $0.score > $1.score }
    }

    static func exactEvent(_ choice: String) -> (year: Int, names: [String], who: String?)? {
        let k = key(choice).replacingOccurrences(of: "의", with: "")
        let hits = DoitSocial.eventList.filter { e in !e.approx && e.names.contains { key($0).replacingOccurrences(of: "의", with: "") == k } }
        guard let first = hits.first, Set(hits.map(\.year)).count == 1 else { return nil }
        return (first.year, first.names, first.who)
    }

    private static func eventQuestion(_ p: Problem) -> Found? {
        let c = p.compact
        // 가장 먼저 · 가장 나중에 일어난 사건
        if p.isChoice, matches(c, #"가장(먼저|이른|오래된|나중|늦게|최근)"#), !p.negated {
            let events = p.choices.map(exactEvent)
            guard events.allSatisfy({ $0 != nil }) else { return nil }
            let years = events.compactMap { $0?.year }
            let target = matches(c, #"가장(먼저|이른|오래된)"#) ? years.min() : years.max()
            let hits = years.indices.filter { years[$0] == target }
            guard hits.count == 1 else { return nil }
            let steps = p.choices.indices.map { SolutionStep(hint: "", work: "\(circled($0 + 1)) \(p.choices[$0]): \(yearText(years[$0]))") }
            return pick(p, index: hits[0], concept: "사건의 순서", steps: steps)
        }
        guard !p.negated else { return nil }
        let found = events(in: p.stem)
        guard let top = found.first else { return nil }
        // 다른 해의 사건이 같이 나오면 (무엇을 묻는지 모름)
        if found.dropFirst().contains(where: { $0.year != top.year && $0.score >= top.score }) { return nil }
        let name = top.names[0]
        // 인물
        if matches(c, #"(세운|세웠|건국한|일으킨|이끈|주도한|만든|창제한|반포한|인물|누구|왕은|사람은)"#), !matches(c, #"(해는|연도|년도|몇년|언제)"#) {
            guard let who = top.who, p.isChoice else { return nil }
            let people = who.components(separatedBy: CharacterSet(charactersIn: ",()")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let hits = p.choices.indices.filter { i in people.contains { key($0) == key(p.choices[i]) } }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: name, steps: [SolutionStep(hint: "역사", work: "\(name) (\(yearText(top.year))): \(who)")])
        }
        guard matches(c, #"(해는|연도|년도|몇년|언제|해를)"#) else { return nil }
        // 끝난 해를 물으면 끝난 해 (끝난 해를 모르면 답하지 않아요)
        var year = top.year
        if matches(c, #"(끝난|끝났|끝나|끝맺|종결|종전|멈춘|막을내|마무리|체결되어끝|완성된|완공된|완료된)"#) {
            guard let end = top.end else { return nil }
            year = end
        } else if top.end != nil, !matches(c, #"(일어난|일어났|시작|발발|일으킨|터진|벌어진|발생한|시작된)"#) {
            return nil
        }
        let steps = [SolutionStep(hint: "연표", work: "\(name): \(yearText(year))")]
        if p.isChoice {
            let hits = p.choices.indices.filter { i in
                guard let m = p.choices[i].firstMatch(of: #/(기원전\s*)?([0-9]{1,4})\s*년?/#), let y = Int(String(m.2)) else { return false }
                return (m.1 == nil ? y : -y) == year
            }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: name, steps: steps)
        }
        return Found(answer: yearText(year), concept: name, steps: steps)
    }

    // MARK: - 국어: 맞춤법

    /// 틀리게 쓰는 말 → 바른 말 (뜻에 따라 둘 다 맞을 수 있는 말은 넣지 않음)
    static let misspellings: [(wrong: String, right: String)] = [
        ("몇일", "며칠"), ("몇 일", "며칠"), ("금새", "금세"), ("일부로", "일부러"), ("설겆이", "설거지"), ("왠일", "웬일"),
        ("웬지", "왠지"), ("왠만", "웬만"), ("오랫만", "오랜만"), ("희안", "희한"), ("역활", "역할"), ("할께", "할게"),
        ("됬", "됐"), ("되서", "돼서"), ("되요", "돼요"), ("뵈요", "봬요"), ("어떻해", "어떡해"), ("어떡게", "어떻게"), ("어떻케", "어떻게"),
        ("곰곰히", "곰곰이"), ("깨끗히", "깨끗이"), ("일일히", "일일이"), ("틈틈히", "틈틈이"), ("꼼꼼이", "꼼꼼히"), ("솔직이", "솔직히"),
        ("구지 ", "굳이 "), ("윗층", "위층"), ("윗쪽", "위쪽"), ("웃사람", "윗사람"), ("아랫층", "아래층"), ("갯수", "개수"), ("촛점", "초점"),
        ("댓가", "대가"), ("설레임", "설렘"), ("하마트면", "하마터면"), ("귀뜸", "귀띔"), ("뒷풀이", "뒤풀이"), ("어의없", "어이없"),
        ("곱배기", "곱빼기"), ("짜집기", "짜깁기"), ("왠걸", "웬걸"), ("문안하", "무난하"), ("개였다", "개었다"), ("했읍니다", "했습니다"),
        ("않 돼", "안 돼"), ("않돼", "안 돼"), ("안되요", "안 돼요"),
        ("육계장", "육개장"), ("휴계실", "휴게실"), ("계시판", "게시판"), ("잠궜", "잠갔"), ("잠궈", "잠가"), ("담궜", "담갔"), ("담궈", "담가"),
        ("치뤘", "치렀"), ("치뤄", "치러"), ("머릿말", "머리말"), ("인삿말", "인사말"), ("햇님", "해님"), ("통채", "통째"), ("깡총", "깡충"),
        ("우뢰", "우레"), ("나뭇군", "나무꾼"), ("삭월세", "사글세"), ("끼여들", "끼어들"), ("떡볶기", "떡볶이"), ("깍뚜기", "깍두기"),
        ("오뚜기", "오뚝이"), ("눈꼽", "눈곱"), ("생각컨대", "생각건대"), ("익숙치", "익숙지"), ("넉넉치", "넉넉지"), ("섭섭치", "섭섭지"),
        ("서슴치", "서슴지"), ("짖궂", "짓궂"), ("애띤", "앳된"), ("희노애락", "희로애락"), ("구렛나루", "구레나룻"), ("내노라", "내로라"),
        ("닥달", "닦달"), ("뇌졸증", "뇌졸중"), ("괜시리", "괜스레"), ("어줍잖", "어쭙잖"), ("오랜동안", "오랫동안"), ("아뭏든", "아무튼")
    ]

    /// 낱말 하나로 쓸 때만 틀린 말 ("살이 찌게 되다"의 찌게는 맞아서, 선지가 그 낱말 하나이거나 조사가 붙었을 때만)
    static let wordMisspellings: [(wrong: String, right: String)] = [("찌게", "찌개"), ("베게", "베개")]

    /// 바르게 쓴 말 (선지에 이 말이 있고 틀린 말이 없으면 바른 선지)
    static let correctSpellings: [String] = [
        "며칠", "금세", "일부러", "설거지", "웬일", "왠지", "웬만", "오랜만", "희한", "역할", "할게", "됐", "돼서", "돼요", "봬요", "어떡해", "어떻게",
        "곰곰이", "깨끗이", "일일이", "틈틈이", "꼼꼼히", "솔직히", "굳이", "위층", "위쪽", "윗사람", "윗니", "웃어른", "아랫니", "아래층", "개수",
        "초점", "대가", "설렘", "하마터면", "귀띔", "뒤풀이", "어이없", "곱빼기", "짜깁기", "웬걸", "무난하", "거예요", "할게요", "안 돼",
        "찌개", "베개", "육개장", "휴게실", "게시판", "잠갔", "잠가", "담갔", "담가", "치렀", "치러", "머리말", "인사말", "해님", "통째", "깡충",
        "우레", "나무꾼", "사글세", "끼어들", "떡볶이", "깍두기", "오뚝이", "눈곱", "생각건대", "익숙지", "넉넉지", "섭섭지", "서슴지", "짓궂",
        "앳된", "희로애락", "구레나룻", "닦달", "오랫동안", "아무튼", "뇌졸중", "괜스레"
    ]

    private static let particles = ["", "이", "가", "을", "를", "은", "는", "도", "에", "와", "과", "로", "으로", "의", "만", "처럼"]

    static func wrongSpelling(in text: String) -> (wrong: String, right: String)? {
        if let hit = misspellings.first(where: { text.contains($0.wrong) }) { return hit }
        let tokens = text.split(separator: " ").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?'\"‘’“”")) }
        for pair in wordMisspellings {
            for token in tokens where token.hasPrefix(pair.wrong) {
                let rest = String(token.dropFirst(pair.wrong.count))
                if rest.isEmpty ? tokens.count == 1 : particles.contains(rest) { return pair }
            }
        }
        // 띄어쓰기: '-ㄹ 수 있다'의 '수'는 의존 명사라 띄어 써요
        if matches(text, #"[가-힣]수(있|없)"#) || matches(text, #"(할|갈|볼|올|먹을|읽을|쓸|될|살)수\s"#) || matches(text, #"수(있다|있어|있는|있을|없다|없어|없는|없을)"#)
            || matches(text, #"(할|갈|볼|올|먹을|읽을|쓸|될|살|알|잘)수(도|가|는|밖에)\s?(있|없)"#) { return ("붙여 쓴 '수'", "띄어 쓴 '-ㄹ 수 있다'") }
        // 의존 명사 '것'도 띄어 써요 ("먹을것" → "먹을 것")
        if matches(text, #"[가-힣](을|는|은)것(이|을|은|도|만|들|\s|$|[.,!?])"#) { return ("붙여 쓴 '것'", "띄어 쓴 '-ㄹ 것'") }
        // 조사는 앞말에 붙여 써요 ("학교 에" → "학교에")
        if matches(text, #"[가-힣] (에|을|를|에서|에게|에게서|으로|처럼|까지|부터|한테|께서|조차|마저)(\s|$|[.,!?])"#) { return ("띄어 쓴 조사", "조사는 앞말에 붙여 써요") }
        return nil
    }

    static func rightSpelling(in text: String) -> String? {
        if let hit = correctSpellings.first(where: { text.contains($0) }) { return hit }
        if matches(text, #"[가-힣] 수 (있|없)"#) { return "-ㄹ 수 있다" }
        if matches(text, #"(을|는|은|할|갈|볼|올|쓸|될|살|알|잘) (것|데|줄|바|뿐|만큼)"#) { return "띄어 쓴 의존 명사" }
        return nil
    }

    static func koreanSpelling(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"(맞춤법|표준어|띄어쓰기|바르게쓴|바르게고|옳게쓴|표기가|바르게고쳐)"#) else { return nil }
        // "‘됬다’를 바르게 고쳐 쓰시오"
        if !p.isChoice, matches(c, #"고(쳐|치)"#),
           let m = p.stem.firstMatch(of: #/[‘'"“「]([^’'"”」]{1,20})[’'"”」]/#) {
            let word = String(m.1)
            guard let hit = misspellings.first(where: { word.contains($0.wrong) }) else { return nil }
            let fixed = word.replacingOccurrences(of: hit.wrong, with: hit.right)
            return Found(answer: fixed, concept: "한글 맞춤법", steps: [SolutionStep(hint: "맞춤법", work: "'\(hit.wrong)'는 틀린 표기예요 → '\(hit.right)'"),
                                                                    SolutionStep(hint: "고쳐 쓰기", work: "\(word) → \(fixed)")])
        }
        guard p.isChoice else { return nil }
        let wrongs = p.choices.map(wrongSpelling)
        let rights = p.choices.map(rightSpelling)
        let steps = p.choices.indices.map { i -> SolutionStep in
            if let w = wrongs[i] { return SolutionStep(hint: "", work: "\(circled(i + 1)) \(p.choices[i]): '\(w.wrong)' → '\(w.right)'로 써야 해요") }
            return SolutionStep(hint: "", work: "\(circled(i + 1)) \(p.choices[i]): 바르게 썼어요" + (rights[i].map { " ('\($0)')" } ?? ""))
        }
        let askWrong = p.negated || matches(c, #"표준어가아닌"#)
        if askWrong {
            // 틀린 것: 틀린 말이 있는 선지 하나, 나머지는 모두 바른 말이 확인됨
            let bad = p.choices.indices.filter { wrongs[$0] != nil }
            guard bad.count == 1, p.choices.indices.allSatisfy({ $0 == bad[0] || rights[$0] != nil }) else { return nil }
            return pick(p, index: bad[0], concept: "한글 맞춤법", steps: steps)
        }
        // 바른 것: 틀린 말이 없는 선지 하나, 나머지는 모두 틀린 말이 확인됨
        let good = p.choices.indices.filter { wrongs[$0] == nil }
        guard good.count == 1, rights[good[0]] != nil else { return nil }
        return pick(p, index: good[0], concept: "한글 맞춤법", steps: steps)
    }

    // MARK: - 영어: 어휘

    /// 단어장 뜻을 하나씩 ("버리다, 포기하다" → ["버리다", "포기하다"])
    static func meanings(of word: String) -> [String]? {
        guard let raw = DoitEnglish.vocabulary[word.lowercased()] ?? DoitEnglish.koreanMeaning(of: word) else { return nil }
        return raw.replacingOccurrences(of: ";", with: ",").components(separatedBy: ",")
            .map { $0.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 글 속 영어 낱말 (두 글자 이상, 한글에 붙어 있어도: "accident의" → "accident")
    static func englishRuns(_ text: String) -> [String] {
        text.matches(of: #/[A-Za-z]{2,}/#).map { String($0.output) }
    }

    private static func isEnglishWord(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        return !t.isEmpty && t.allSatisfy { ($0.isASCII && $0.isLetter) || $0 == "-" }
    }

    static func englishVocabulary(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"(뜻|의미|우리말|단어)"#), !c.contains("빈칸"), !c.contains("___"),
              !matches(c, #"(반대|반의|비슷한|유의|동의|영영|철자)"#) else { return nil }
        // 단어 - 뜻 짝 고르기
        if p.isChoice, p.choices.allSatisfy({ $0.contains("-") || $0.contains(":") }) {
            var hits: [Int] = []
            var steps: [SolutionStep] = []
            for (i, choice) in p.choices.enumerated() {
                let parts = choice.components(separatedBy: CharacterSet(charactersIn: "-:")).map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2, isEnglishWord(parts[0]), let list = meanings(of: parts[0]) else { return nil }
                let ok = list.contains { key($0) == key(parts[1]) }
                steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(parts[0]): \(list.joined(separator: ", "))" + (ok ? " ✓" : "")))
                if ok != p.negated { hits.append(i) }
            }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "영어 단어 뜻", steps: steps)
        }
        let stemWords = Array(Set(englishRuns(p.stem).map { $0.lowercased() }))
        // 영어 단어 → 우리말 뜻 고르기
        if stemWords.count == 1, let list = meanings(of: stemWords[0]) {
            let word = stemWords[0]
            let steps = [SolutionStep(hint: "단어장", work: "\(word): \(list.joined(separator: ", "))")]
            guard p.isChoice else {
                return Found(answer: list[0], concept: "영어 단어 뜻", steps: steps)
            }
            guard p.choices.allSatisfy({ !isEnglishWord($0) }) else { return nil }
            let inList = p.choices.indices.filter { i in list.contains { key($0) == key(p.choices[i]) } }
            if p.negated {
                let out = p.choices.indices.filter { !inList.contains($0) }
                guard out.count == 1 else { return nil }
                return pick(p, index: out[0], concept: "영어 단어 뜻", steps: steps)
            }
            guard inList.count == 1 else { return nil }
            return pick(p, index: inList[0], concept: "영어 단어 뜻", steps: steps)
        }
        // 우리말 뜻 → 영어 단어 고르기 ("'능력'을 뜻하는 영어 단어는?")
        guard stemWords.isEmpty, p.isChoice, !p.negated, p.choices.allSatisfy(isEnglishWord),
              let m = p.stem.firstMatch(of: #/[‘'"“]([가-힣 ]{1,12})[’'"”]/#) else { return nil }
        let target = key(String(m.1))
        var hits: [Int] = []
        var steps: [SolutionStep] = []
        for (i, choice) in p.choices.enumerated() {
            guard let list = meanings(of: choice) else { return nil }
            steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(choice): \(list.joined(separator: ", "))"))
            if list.contains(where: { key($0) == target }) { hits.append(i) }
        }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: "영어 단어 뜻", steps: steps)
    }

    // MARK: - 영어: 문법 빈칸

    /// 빈칸 앞뒤 낱말 (빈칸이 하나인 영어 문장일 때만)
    private struct Blank {
        let sentence: String
        let left: [String]
        let right: [String]
        /// 문장 앞의 Look! · Listen! 같은 말까지 모두 (소문자)
        let whole: String
    }

    private static func blank(_ p: Problem) -> Blank? {
        let pattern = #"_{2,}|＿+|\(\s{1,}\)|\[\s*\]"#
        let lines = p.stem.components(separatedBy: "\n").filter { $0.range(of: pattern, options: .regularExpression) != nil }
        guard lines.count == 1, let line = lines.first,
              let r = line.range(of: pattern, options: .regularExpression),
              line.range(of: pattern, options: .regularExpression, range: r.upperBound..<line.endIndex) == nil else { return nil }
        // 한글 지시문이 같은 줄에 있으면 영어 부분만 ("빈칸에 알맞은 것은? She ___ …")
        var before = String(line[..<r.lowerBound]), after = String(line[r.upperBound...])
        if let h = before.lastIndex(where: { DoitSubjectNote.isHangul($0) || $0 == "?" || $0 == "？" }) {
            before = String(before[before.index(after: h)...])
        }
        if let h = after.firstIndex(where: { DoitSubjectNote.isHangul($0) }) { after = String(after[..<h]) }
        func words(_ s: String) -> [String] {
            s.lowercased().replacingOccurrences(of: "’", with: "'").components(separatedBy: CharacterSet(charactersIn: " ,;:\t"))
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".\"“”")) }.filter { !$0.isEmpty }
        }
        // 빈칸이 있는 문장만 (앞 문장 "Look!"은 단서로 따로)
        var leftWords = words(before)
        var lead: [String] = []
        if let cut = leftWords.lastIndex(where: { $0.hasSuffix("!") || $0.hasSuffix("?") }) {
            lead = Array(leftWords[...cut]); leftWords = Array(leftWords[(cut + 1)...])
        }
        var rightWords = words(after)
        if let cut = rightWords.firstIndex(where: { $0.hasSuffix("!") || $0.hasSuffix("?") }) {
            rightWords[cut] = String(rightWords[cut].dropLast()); rightWords = Array(rightWords[...cut])
        }
        rightWords = rightWords.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "!?.")) }.filter { !$0.isEmpty }
        guard (leftWords + rightWords).allSatisfy({ $0.allSatisfy { $0.isASCII } }), leftWords.count + rightWords.count >= 1 else { return nil }
        let whole = (lead + leftWords + ["___"] + rightWords).joined(separator: " ")
        return Blank(sentence: (before + "___" + after).trimmingCharacters(in: .whitespaces), left: leftWords, right: rightWords, whole: whole)
    }

    static func englishGrammar(_ p: Problem) -> Found? {
        guard p.isChoice, p.choices.allSatisfy({ $0.allSatisfy { $0.isASCII } }), let b = blank(p) else { return nil }
        let options = p.choices.map { $0.lowercased().split(separator: " ").joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
        if let found = relativePronoun(p, b, options) { return found }
        if let found = byPreposition(p, b, options) { return found }
        if let found = comparison(p, b, options) { return found }
        if let found = verbForm(p, b, options) { return found }
        return nil
    }

    private static func choose(_ p: Problem, _ options: [String], allowed: Set<String>, concept: String, why: [String]) -> Found? {
        let hits = options.indices.filter { allowed.contains(options[$0]) }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: concept, steps: why.map { SolutionStep(hint: "", work: $0) })
    }

    // 관계대명사

    private static let personNouns: Set<String> = [
        "friend", "friends", "boy", "boys", "girl", "girls", "man", "men", "woman", "women", "people", "person", "teacher", "teachers",
        "student", "students", "doctor", "doctors", "child", "children", "kid", "kids", "lady", "gentleman", "singer", "player", "players",
        "brother", "sister", "uncle", "aunt", "cousin", "neighbor", "nurse", "scientist", "artist", "writer", "actor", "actress", "baby",
        "someone", "anyone", "everyone", "classmate", "classmates", "pilot", "farmer", "police officer", "officer", "driver", "girlfriend", "boyfriend"
    ]
    private static let thingNouns: Set<String> = [
        "book", "books", "house", "houses", "car", "cars", "dog", "dogs", "cat", "cats", "movie", "movies", "song", "songs", "bag", "bags",
        "phone", "computer", "pen", "pencil", "picture", "pictures", "city", "town", "building", "story", "stories", "letter", "letters",
        "animal", "animals", "bird", "birds", "food", "restaurant", "shop", "store", "box", "watch", "camera", "bike", "bicycle", "game", "games",
        "toy", "toys", "flower", "flowers", "tree", "trees", "room", "school", "cake", "hat", "shirt", "shoes", "dress", "present", "gift", "river",
        "mountain", "country", "museum", "park", "window", "chair", "table", "desk", "bread", "smartphone", "robot", "machine", "pet", "horse"
    ]
    private static let subjectPronouns: Set<String> = ["i", "you", "he", "she", "we", "they", "it", "my", "his", "her", "our", "their", "your", "tom", "the", "a", "an", "this", "that", "everyone", "people", "mr", "mrs", "ms"]
    private static let possessedNouns: Set<String> = [
        "father", "mother", "name", "brother", "sister", "parents", "hair", "eyes", "house", "car", "dog", "son", "daughter", "roof",
        "cover", "tail", "legs", "color", "job", "wife", "husband", "uncle", "aunt", "dream", "window", "door",
        "songs", "books", "paintings", "novels", "hobby", "names", "sons", "daughters"
    ]

    private static func relativePronoun(_ p: Problem, _ b: Blank, _ options: [String]) -> Found? {
        let relatives: Set<String> = ["who", "whom", "whose", "which", "that", "what", "where", "when", "why", "how"]
        guard options.allSatisfy({ relatives.contains($0) }), let antecedent = b.left.last, let next = b.right.first else { return nil }
        let person = personNouns.contains(antecedent), thing = thingNouns.contains(antecedent)
        guard person != thing else { return nil }
        var allowed: Set<String>
        var role: String
        // 관사 없는 명사 + 동사는 "the book which students read"(목적격)일 수도 있어서, 흔히 '누구의 것'인 명사일 때만 소유격으로
        if possessedNouns.contains(next), b.right.count >= 2, isVerbLike(b.right[1]) {
            allowed = ["whose"]; role = "뒤에 명사(\(next))가 바로 오고 '\(antecedent)의 \(next)'라는 뜻이라 소유격"
        } else if isVerbLike(next) {
            allowed = person ? ["who", "that"] : ["which", "that"]; role = "뒤에 동사(\(next))가 바로 와서 주격"
        } else if subjectPronouns.contains(next) || next.first?.isUppercase == true {
            // 관계부사(where · when …)가 선지에 있으면 뒤 동사가 목적어를 갖는지 몰라서 풀지 않음 ("the house ___ I live")
            // (뒤 동사가 목적어를 꼭 갖는 동사면 목적격: "the book ___ I bought")
            let transitive: Set<String> = ["buy", "make", "meet", "see", "write", "read", "like", "love", "want", "give", "take", "find", "build", "draw",
                                           "eat", "cook", "know", "visit", "watch", "choose", "wear", "send", "lose", "borrow", "paint", "bake", "invite", "call"]
            let objectVerb = b.right.dropFirst().prefix(3).contains { w in DoitEnglish.verbBase(w).map { transitive.contains($0) && w != $0 || transitive.contains(w) && w == $0 } ?? false }
            guard !options.contains(where: { ["where", "when", "why", "how"].contains($0) }) || objectVerb else { return nil }
            allowed = person ? ["who", "whom", "that"] : ["which", "that"]; role = "뒤에 주어(\(next))와 동사가 와서 목적격"
        } else { return nil }
        let why = ["선행사 '\(antecedent)'는 \(person ? "사람" : "사물·동물")이에요.", "빈칸 \(role) 관계대명사가 필요해요.",
                   "쓸 수 있는 말: " + allowed.sorted().joined(separator: ", ")]
        return choose(p, options, allowed: allowed, concept: "관계대명사", why: why)
    }

    private static func isVerbLike(_ word: String) -> Bool {
        let w = word.lowercased()
        if ["is", "are", "was", "were", "am", "has", "have", "had", "can", "will", "would", "should", "must", "may", "could", "does", "did", "do"].contains(w) { return true }
        guard let base = DoitEnglish.verbBase(w) else { return false }
        // 명사로 더 흔한 말은 동사로 보지 않음 (book, name …): 3인칭·과거 모양일 때만
        if w == base { return false }
        return true
    }

    // 수동태의 by

    private static func byPreposition(_ p: Problem, _ b: Blank, _ options: [String]) -> Found? {
        let preps: Set<String> = ["by", "at", "on", "in", "for", "with", "to", "of", "from", "about"]
        guard options.allSatisfy({ preps.contains($0) }), options.contains("by"), b.left.count >= 2 else { return nil }
        let verb = b.left[b.left.count - 1], be = b.left[b.left.count - 2]
        guard ["is", "are", "was", "were", "be", "been", "am"].contains(be), let base = DoitEnglish.verbBase(verb),
              DoitEnglish.ppForms(base).contains(verb), base != "be" else { return nil }
        // 다른 전치사를 쓰는 수동태 (be interested in, be made of …)는 풀지 않음
        let simple: Set<String> = ["love", "write", "build", "break", "paint", "invent", "discover", "use", "speak", "read", "eat", "visit", "sing",
                                   "play", "teach", "watch", "design", "create", "find", "cook", "clean", "wash", "help", "take", "give", "send",
                                   "draw", "grow", "sell", "buy", "catch", "steal", "bite", "build", "invite", "respect", "like", "hit", "kick", "open", "close", "fix", "plant"]
        guard simple.contains(base) else { return nil }
        let why = ["\(be) + \(verb)(과거분사): 수동태예요.", "행동한 사람·것(행위자)은 'by + 행위자'로 나타내요."]
        return choose(p, options, allowed: ["by"], concept: "수동태", why: why)
    }

    // 비교급 · 최상급

    private static func comparison(_ p: Problem, _ b: Blank, _ options: [String]) -> Found? {
        // 원급: 다른 선지가 그 말의 비교급·최상급인 것
        let bases = options.filter { option in
            !option.contains(" ") && option.allSatisfy(\.isLetter) && {
                let forms = DoitEnglish.comparison(option)
                return options.contains { forms.comparative.contains($0) || forms.superlative.contains($0) || forms.superlative.contains($0.replacingOccurrences(of: "the ", with: "")) }
            }()
        }
        guard bases.count == 1, let base = bases.first else { return nil }
        let forms = DoitEnglish.comparison(base)
        let next = b.right.first ?? "", previous = b.left.last ?? ""
        var allowed: Set<String>
        var why: [String]
        if next == "than" {
            guard !["the", "most", "more", "less", "very", "least"].contains(previous) else { return nil }
            allowed = Set(forms.comparative); why = ["뒤에 than이 있으면 비교급을 써요.", "\(base) → \(forms.comparative.joined(separator: " / "))"]
        } else if previous == "as", next == "as" {
            allowed = [base]; why = ["as + 원급 + as: '~만큼 …한'", "그대로 \(base)"]
        } else if previous == "the", !b.right.contains("than"), !b.whole.contains("of the two") {
            allowed = Set(forms.superlative); why = ["the + 최상급 (in/of + 범위): '가장 …한'", "\(base) → \(forms.superlative.joined(separator: " / "))"]
        } else if b.right.contains(where: { ["in", "of"].contains($0) }), !b.right.contains("than"), previous != "a", previous != "as" {
            allowed = Set(forms.superlative.map { "the " + $0 }); why = ["범위(in/of …) 안에서 '가장 …한': the + 최상급", "\(base) → the \(forms.superlative.joined(separator: " / "))"]
            guard options.contains(where: allowed.contains) else { return nil }
        } else { return nil }
        return choose(p, options, allowed: allowed, concept: next == "than" ? "비교급" : previous == "as" ? "원급 비교" : "최상급", why: why)
    }

    // 동사 모양

    private static let gerundVerbs: Set<String> = ["enjoy", "finish", "mind", "avoid", "keep", "practice", "quit", "deny", "consider", "suggest", "imagine", "admit", "miss", "delay", "postpone", "recommend"]
    private static let gerundPhrases: Set<String> = ["give up", "put off", "keep on", "be busy", "look forward to", "feel like", "how about", "what about"]
    private static let infinitiveVerbs: Set<String> = ["want", "hope", "decide", "plan", "expect", "wish", "promise", "agree", "refuse", "need", "learn", "choose", "would like", "manage", "fail", "afford", "pretend", "seem", "offer", "prepare"]
    private static let bothVerbs: Set<String> = ["like", "love", "hate", "begin", "start", "continue", "prefer"]
    private static let modalsList: Set<String> = ["can", "could", "will", "would", "should", "must", "may", "might", "shall"]

    private enum Person { case first, third, plural }

    private static let collectiveNouns: Set<String> = ["team", "family", "class", "group", "staff", "audience", "crowd", "committee", "police", "government", "jury", "band", "club"]
    private static let amountNouns: Set<String> = ["dollars", "minutes", "hours", "years", "miles", "kilometers", "meters", "days", "weeks", "months", "seconds", "won", "pounds", "euros", "kilograms"]
    private static let numberWords: Set<String> = ["two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "twenty", "thirty", "fifty", "hundred", "a"]

    /// "Two dollars", "Ten minutes" (수 + 단위)
    private static func isAmount(_ words: [String]) -> Bool {
        words.count == 2 && (numberWords.contains(words[0]) || Int(words[0]) != nil) && amountNouns.contains(words[1])
    }

    /// 주어의 인칭·수 (모르면 nil)
    private static func person(_ words: [String], original: String) -> Person? {
        guard !words.isEmpty else { return nil }
        // 금액·시간·거리 덩어리(Two dollars)는 뜻에 따라 달라서 여기서는 모름, 집합 명사(team, family)도 모름
        if isAmount(words) { return nil }
        if let last = words.last, collectiveNouns.contains(last) || ["mathematics", "physics", "economics", "politics", "species", "series", "means", "lens"].contains(last) { return nil }
        // every · each + 단수 명사, each of · one of + 복수 명사 → 단수
        if ["every", "each"].contains(words[0]), words.count == 2, words[1] != "of" { return .third }
        if ["each", "one"].contains(words[0]), words.count >= 3, words.count <= 4, words[1] == "of", words.last!.hasSuffix("s") || ["children", "people", "men", "women"].contains(words.last!) { return .third }
        // 꾸미는 말이 붙은 주어 ("The boys in the park")·의문사·there는 주어를 확실히 모름
        let unsure: Set<String> = ["in", "of", "on", "at", "with", "from", "for", "near", "under", "behind", "who", "which", "that",
                                   "what", "where", "when", "why", "how", "there", "here"]
        if words.count > 1 || ["there", "here", "what", "where", "when", "why", "how", "who", "which"].contains(words[0]) {
            if words.contains(where: unsure.contains) && !(words.count == 1 && words[0] == "that") { return nil }
        }
        if words.contains("and") { return .plural }
        let last = words.last!
        if words.count == 1 {
            switch last {
            case "i": return .first
            case "you", "we", "they", "people", "children", "men", "women": return .plural
            case "he", "she", "it", "this", "that", "everyone", "someone", "somebody", "everybody", "nobody", "everything": return .third
            default:
                // 복수형일 수 있는 말(-s, 불규칙 복수)은 모름, 나머지 대문자 낱말은 사람 이름
                if last.hasSuffix("s") || DoitEnglish.singular(ofIrregular: last) != nil { return nil }
                if let word = original.split(separator: " ").first(where: { $0.lowercased() == last }), word.first?.isUppercase == true { return .third }
                return nil
            }
        }
        let determiners: Set<String> = ["the", "a", "an", "my", "your", "his", "her", "our", "their", "its", "this", "that", "these", "those", "mr", "mrs", "ms", "dr", "mr.", "mrs.", "ms."]
        guard determiners.contains(words[words.count - 2]) || words.count == 2 && original.first?.isUppercase == true else { return nil }
        if ["mr", "mrs", "ms", "dr", "mr.", "mrs.", "ms."].contains(words[words.count - 2]) { return .third }
        if ["these", "those"].contains(words[words.count - 2]) { return .plural }
        if let single = DoitEnglish.singular(ofIrregular: last) { return single == last ? nil : .plural }
        if ["people", "children", "men", "women"].contains(last) { return .plural }
        if last.hasSuffix("s"), !last.hasSuffix("ss"), !["bus", "news", "class", "glass"].contains(last) { return .plural }
        if ["someone", "one"].contains(last) { return .third }
        return .third
    }

    /// 때 단서가 없을 때: 주어와 수가 맞는 정형 동사(현재·과거·미래) 선지가 하나뿐이면 그것
    /// ("Every student ___ a uniform." → wears, -ing·to부정사는 혼자 동사가 될 수 없고 wear는 수가 안 맞음)
    private static func agreementOnly(_ p: Problem, _ options: [String], base: String, who: Person, b: Blank) -> Found? {
        func agrees(_ o: String) -> Bool {
            switch o {
            case "am": return who == .first
            case "is": return who == .third
            case "are": return who == .plural
            case "was": return who != .plural
            case "were": return who == .plural
            default: break
            }
            if base == "be" { return false }
            if DoitEnglish.pastForms(base).contains(o) { return true }   // read · put처럼 원형과 과거형이 같으면 과거로도 맞음
            if o == base { return who != .third }
            if o == DoitEnglish.thirdPerson(base) { return who == .third }
            if DoitEnglish.pastForms(base).contains(o) { return true }
            if o.hasPrefix("will ") { return true }
            if o.hasPrefix("has ") { return who == .third }
            if o.hasPrefix("have ") { return who != .third }
            return false
        }
        var candidates = options.filter(agrees)
        // already · yet: 현재완료 (과거형 선지가 없을 때만)
        let whole = " " + b.whole + " "
        if candidates.count > 1, whole.contains(" already ") || whole.hasSuffix(" yet ") || whole.contains(" yet?") {
            let perfect = candidates.filter { $0.hasPrefix("has ") || $0.hasPrefix("have ") }
            let past = candidates.filter { DoitEnglish.pastForms(base).contains($0) }
            if perfect.count == 1, past.isEmpty { candidates = perfect }
        }
        guard candidates.count == 1 else { return nil }
        let subjectWord = who == .first ? "1인칭 I" : who == .third ? "3인칭 단수" : "복수(또는 you)"
        let why = ["빈칸은 주어 뒤 동사 자리라 -ing·to부정사·원형 be는 올 수 없어요.", "주어가 \(subjectWord)라서 수가 맞는 것: \(candidates[0])"]
        return choose(p, options, allowed: [candidates[0]], concept: "주어와 동사의 수일치", why: why)
    }

    /// 때 단서 (yesterday → 과거 …). 둘 이상이면 nil
    private enum Time { case past, future, now, habit }

    private static func timeCue(_ b: Blank) -> Time? {
        let s = " " + b.whole.replacingOccurrences(of: "!", with: " ! ") + " "
        var cues = Set<String>()
        if matches(s, #" (yesterday|ago|last (night|week|month|year|summer|winter|spring|fall|weekend|sunday|monday|tuesday|wednesday|thursday|friday|saturday|time)|in (19|20)[0-1][0-9]) "#) { cues.insert("past") }
        if matches(s, #" (tomorrow|next (week|month|year|summer|winter|spring|fall|weekend|sunday|monday|tuesday|wednesday|thursday|friday|saturday|time)|in the future|someday) "#) { cues.insert("future") }
        if matches(s, #" (now|right now|at the moment|at this moment) "#) || matches(s, #"^\s*(look|listen)\s*!"#) { cues.insert("now") }
        if matches(s, #" (every (day|morning|evening|night|week|sunday|monday|tuesday|wednesday|thursday|friday|saturday|weekend|year)|usually|always|often|sometimes|on (sundays|mondays|tuesdays|wednesdays|thursdays|fridays|saturdays|weekends)|once a|twice a) "#) { cues.insert("habit") }
        guard cues.count == 1 else { return nil }
        switch cues.first! {
        case "past": return .past
        case "future": return .future
        case "now": return .now
        default: return .habit
        }
    }

    /// 선지 하나(B)를 원형으로 놓았을 때 다른 선지가 모두 B의 변화형이면 B
    private static func regularBase(_ options: [String]) -> String? {
        func forms(_ b: String) -> Set<String> {
            let ing = DoitEnglish.ingForm(b), pp = DoitEnglish.ppForms(b), past = DoitEnglish.pastForms(b)
            var set: Set<String> = [b, DoitEnglish.thirdPerson(b), ing, "to " + b, "will " + b]
            set.formUnion(past); set.formUnion(pp)
            for be in ["am", "is", "are", "was", "were"] { set.insert(be + " " + ing); set.insert(be + " going to " + b); set.formUnion(pp.map { be + " " + $0 }) }
            for have in ["have", "has", "had"] { set.formUnion(pp.map { have + " " + $0 }) }
            return set
        }
        let candidates = options.filter { !$0.contains(" ") && $0.count >= 2 && $0.allSatisfy(\.isLetter) }
            .filter { b in options.allSatisfy { forms(b).contains($0) } }
        return candidates.count == 1 ? candidates[0] : nil
    }

    /// 목적어 모양을 정하는 동사 (enjoy, want, like …): 그 동사의 어느 모양이든 ("enjoyed", "wants")
    private static func listedVerb(_ word: String) -> String? {
        for v in gerundVerbs.union(infinitiveVerbs).union(bothVerbs) where !v.contains(" ") {
            if word == v || word == DoitEnglish.thirdPerson(v) || DoitEnglish.pastForms(v).contains(word) || word == DoitEnglish.ingForm(v) { return v }
        }
        return DoitEnglish.verbBase(word)
    }

    private static func verbForm(_ p: Problem, _ b: Blank, _ options: [String]) -> Found? {
        // 선지가 모두 한 동사의 모양인지 ("go", "went", "will go", "is going", "to go")
        func verbOf(_ option: String) -> String? {
            let words = option.split(separator: " ").map(String.init)
            guard let last = words.last, words.count <= 3 else { return nil }
            if words.count == 1, last == "be" { return "be" }
            return DoitEnglish.verbBase(last)
        }
        var bases = options.map(verbOf)
        // 단어장에 없는 규칙 동사: 선지 하나를 원형으로 놓고 나머지가 모두 그 변화형이면 그 원형
        if !bases.allSatisfy({ $0 != nil }), let guessed = regularBase(options) { bases = options.map { _ in guessed } }
        guard bases.allSatisfy({ $0 != nil }) else { return nil }
        // be 동사(am/is/are …)와 그 뒤 동사가 섞이면 뒤 동사로
        let nonBe = Set(bases.compactMap { $0 }).subtracting(["be"])
        let base: String
        if nonBe.count == 1 { base = nonBe.first! }
        else if nonBe.isEmpty { base = "be" }
        else { return nil }
        guard options.filter({ verbOf($0) == base || base == "be" }).count == options.count || nonBe.count == 1 else { return nil }
        let left = b.left
        let last = left.last ?? ""
        let previous = left.count >= 2 ? left[left.count - 2] : ""
        let pastForms = Set(DoitEnglish.pastForms(base)), ppForms = Set(DoitEnglish.ppForms(base))
        let ing = DoitEnglish.ingForm(base)
        var allowed: Set<String> = []
        var why: [String] = []
        var concept = "동사의 형태"
        let leftText = left.joined(separator: " ")

        if modalsList.contains(last) || ["don't", "doesn't", "didn't", "can't", "won't", "cannot"].contains(last)
            || (last == "not" && (["do", "does", "did"].contains(previous) || modalsList.contains(previous))) {
            allowed = [base]; why = ["\(last == "not" ? previous + " not" : last) 뒤에는 동사원형을 써요."]; concept = "조동사 + 동사원형"
        } else if let first = left.first, ["do", "does", "did"].contains(first), left.count >= 2, left.count <= 4,
                  !left.dropFirst().contains(where: { DoitEnglish.verbBase($0) != nil && !personNouns.contains($0) && !thingNouns.contains($0) && !["she", "he", "you", "they", "we", "i", "it"].contains($0) }) {
            allowed = [base]; why = ["\(first.capitalized)로 시작하는 의문문에서 주어 뒤에는 동사원형을 써요."]; concept = "의문문의 동사원형"
        } else if last == "to", leftText.hasSuffix("forward to") {
            allowed = [ing]; why = ["look forward to의 to는 전치사라 뒤에 동명사(-ing)를 써요.", "\(base) → \(ing)"]; concept = "look forward to + -ing"
        } else if last == "to" {
            guard let v = listedVerb(previous), infinitiveVerbs.contains(v) || bothVerbs.contains(v) else { return nil }
            allowed = [base]; why = ["to부정사: to + 동사원형"]; concept = "to부정사"
        } else if ["have", "has", "had", "'ve"].contains(last)
                    || (["already", "just", "never", "ever", "not", "recently", "once"].contains(last) && ["have", "has", "had"].contains(previous)) {
            guard base != "have" || last != "have" else { return nil }
            // been(경험 · 다녀옴)과 gone(가 버림)은 뜻으로 갈려요: 횟수·경험 단서가 있을 때만 been
            if options.contains("been"), options.contains("gone") {
                let cue = matches(" " + b.whole + " ", #" (twice|once|before|ever|never|\d+ times|many times|several times|three times) "#)
                guard cue, b.right.first == "to" else { return nil }
                return choose(p, options, allowed: ["been"], concept: "have been to (경험)", why: ["횟수·경험(twice, ever …)을 말하면 have been to (have gone to는 '가 버리고 없다')"])
            }
            allowed = ppForms; why = ["have/has + 과거분사: 현재완료", "\(base) → \(ppForms.sorted().joined(separator: "/"))"]; concept = "현재완료"
        } else if ["am", "is", "are", "was", "were", "be", "been"].contains(last) {
            let rightWindow = b.right.prefix(6)
            let intransitive: Set<String> = ["stand", "sit", "live", "stay", "wait", "walk", "run", "go", "come", "arrive", "sleep", "lie", "swim", "travel"]
            if rightWindow.contains("by"), base != "be", !intransitive.contains(base) {
                allowed = ppForms; why = ["be동사 + 과거분사 + by …: 수동태", "\(base) → \(ppForms.sorted().joined(separator: "/"))"]; concept = "수동태"
            } else if timeCue(b) == .now, ["am", "is", "are"].contains(last), base != "be" {
                allowed = [ing]; why = ["now 같은 지금을 나타내는 말: 현재진행형 (be동사 + -ing)", "\(base) → \(ing)"]; concept = "현재진행형"
            } else { return nil }
        } else if let v = listedVerb(last), gerundVerbs.contains(v) || bothVerbs.contains(v) || infinitiveVerbs.contains(v),
                  !["i", "you", "he", "she", "we", "they", "it"].contains(last) {
            if gerundVerbs.contains(v) { allowed = [ing]; why = ["\(v)는 목적어로 동명사(-ing)를 써요.", "\(base) → \(ing)"]; concept = "동명사를 목적어로 쓰는 동사" }
            else if infinitiveVerbs.contains(v) || (v == "like" && previous == "would") { allowed = ["to " + base]; why = ["\(v)는 목적어로 to부정사를 써요.", "to + \(base)"]; concept = "to부정사를 목적어로 쓰는 동사" }
            else { allowed = [ing, "to " + base]; why = ["\(v)는 동명사와 to부정사를 모두 목적어로 써요."]; concept = "동명사·to부정사" }
        } else if gerundPhrases.contains(where: { leftText.hasSuffix($0) || leftText.hasSuffix($0.replacingOccurrences(of: "give", with: "gave")) }) {
            allowed = [ing]; why = ["'\(left.suffix(2).joined(separator: " "))' 뒤에는 동명사(-ing)를 써요.", "\(base) → \(ing)"]; concept = "동명사"
        } else if ["me", "you", "him", "her", "us", "them"].contains(last), ["make", "makes", "made", "let", "lets", "had"].contains(previous) {
            allowed = [base]; why = ["사역동사 \(previous) + 목적어 + 동사원형"]; concept = "사역동사"
        } else if ["me", "you", "him", "her", "us", "them"].contains(last),
                  ["tell", "tells", "told", "ask", "asks", "asked", "want", "wants", "wanted", "advise", "advised", "allow", "allowed",
                   "expect", "expected", "order", "ordered", "encourage", "encouraged"].contains(previous) {
            allowed = ["to " + base]; why = ["\(previous) + 목적어 + to부정사"]; concept = "목적격 보어 to부정사"
        } else if left.first == "if", left.count >= 2, left.count <= 3, b.right.contains(where: { ["would", "could", "might"].contains($0) }) {
            allowed = base == "be" ? ["were"] : pastForms
            why = ["If + 주어 + 과거형 …, 주어 + would/could + 동사원형: 가정법 과거 (be동사는 주어와 상관없이 were)"]; concept = "가정법 과거"
        } else {
            // 주어 + 빈칸: 때 단서로 시제, 주어로 인칭
            var subject = left
            let adverbs: Set<String> = ["always", "usually", "often", "sometimes", "never", "also", "really"]
            while let w = subject.last, adverbs.contains(w) { subject.removeLast() }
            guard !subject.isEmpty, subject.count <= 4, !subject.contains(where: { modalsList.contains($0) || ["is", "are", "was", "were", "am", "has", "have", "does", "did", "do"].contains($0) }),
                  !["i", "you", "he", "she", "we", "they", "it"].contains(b.right.first ?? "") else { return nil }
            let originalLeft = b.sentence.components(separatedBy: "___").first ?? ""
            let originalSubject = originalLeft.split(separator: " ").suffix(subject.count + (left.count - subject.count)).joined(separator: " ")
            // 금액·시간 덩어리 + enough · too much … → 단수 ("Two dollars is enough")
            let amountCue: Set<String> = ["enough", "too", "a", "not", "quite", "very", "much", "plenty", "worth", "expensive", "cheap", "long", "short", "far"]
            let who: Person? = isAmount(subject) ? (amountCue.contains(b.right.first ?? "") ? .third : nil) : person(subject, original: originalSubject)
            let since = matches(" " + b.whole + " ", #" since ((1[89]|20)[0-9]{2}|last|yesterday|i|you|he|she|we|they|it|my|his|her|our|their|the|then|childhood) "#)
            if since {
                // since + 시점: 현재완료
                guard let who else { return nil }
                allowed = Set(ppForms.map { (who == .third ? "has " : "have ") + $0 })
                why = ["since + 시점(…부터 지금까지): 현재완료 have/has + 과거분사", "\(allowed.sorted().joined(separator: " / "))"]; concept = "현재완료 (since)"
                return choose(p, options, allowed: allowed, concept: concept, why: why)
            }
            guard let time = timeCue(b) else {
                // 때 단서가 없으면 주어와 수가 맞는 정형 동사가 하나뿐일 때만
                guard let who else { return nil }
                return agreementOnly(p, options, base: base, who: who, b: b)
            }
            if base == "be", let next = b.right.first, next.hasSuffix("ing"), time == .future || time == .now, let who {
                // be going to · 진행형의 be동사: 주어에 맞는 현재형
                allowed = [who == .first ? "am" : who == .third ? "is" : "are"]
                why = ["뒤에 \(next)가 있어 be동사 현재형, 주어에 맞춰 \(allowed.first!)"]; concept = "be동사와 주어의 수일치"
                return choose(p, options, allowed: allowed, concept: concept, why: why)
            }
            switch time {
            case .past:
                if base == "be" {
                    guard let who else { return nil }
                    allowed = [who == .plural ? "were" : "was"]
                } else { allowed = pastForms }
                why = ["과거를 나타내는 말(yesterday, last …, ago)이 있어서 과거형", "\(base) → \(allowed.sorted().joined(separator: "/"))"]; concept = "과거 시제"
            case .future:
                allowed = ["will " + base]
                if let who { allowed.insert((who == .first ? "am" : who == .third ? "is" : "are") + " going to " + base) }
                why = ["미래를 나타내는 말(tomorrow, next …)이 있어서 will + 동사원형"]; concept = "미래 시제"
            case .now:
                guard let who else { return nil }
                let be = who == .first ? "am" : who == .third ? "is" : "are"
                if base == "be" { allowed = [be]; why = ["지금(now)의 상태: 현재형 \(be)"]; concept = "be동사 현재형" }
                else { allowed = [be + " " + ing]; why = ["지금 하고 있는 일(now, Look!, Listen!): 현재진행형 be동사 + -ing", "\(be) \(ing)"]; concept = "현재진행형" }
            case .habit:
                guard let who else { return nil }
                if base == "be" { allowed = [who == .first ? "am" : who == .third ? "is" : "are"] }
                else { allowed = [who == .third ? DoitEnglish.thirdPerson(base) : base] }
                why = ["늘 하는 일(every …, always, usually): 현재형"] + (who == .third ? ["주어가 3인칭 단수라 \(base) → \(allowed.first ?? "")"] : [])
                concept = who == .third ? "3인칭 단수 현재형" : "현재 시제"
            }
        }
        guard !allowed.isEmpty else { return nil }
        return choose(p, options, allowed: allowed, concept: concept, why: why)
    }

    // MARK: - 모델에게 줄 참고 자료 (추측 풀이용)

    /// 규칙으로 확실히 틀린 것을 아는 선지 ("자료로 보면 ①, ④는 퇴적암이 아니에요")
    static func partialHints(text: String, choices: [String], body: String? = nil, boxItems: [String]? = nil) -> [String] {
        let p = Problem(full: text, body: body, choices: choices, box: boxItems)
        guard p.isChoice else { return [] }
        var hints: [String] = []
        if let cat = askedCategory(p), p.box.isEmpty {
            let known = p.choices.indices.filter { cat.universe.contains(key(p.choices[$0])) }
            let members = known.filter { cat.members.contains(key(p.choices[$0])) }
            let others = known.filter { !members.contains($0) }
            if !members.isEmpty { hints.append("자료: " + members.map { "\(circled($0 + 1)) \(p.choices[$0])" }.joined(separator: ", ") + "은(는) \(cat.names[0])이에요.") }
            if !others.isEmpty { hints.append("자료: " + others.map { "\(circled($0 + 1)) \(p.choices[$0])" }.joined(separator: ", ") + "은(는) \(cat.names[0])이 아니에요.") }
        }
        // 영어 문장 선지: 규칙으로 확실히 틀린 곳을 찾은 선지
        if p.choices.allSatisfy(DoitSentenceCheck.isEnglishSentence) {
            for (i, choice) in p.choices.enumerated() {
                if let issue = DoitSentenceCheck.error(in: choice) { hints.append("어법 규칙: \(circled(i + 1)) \(choice) → \(issue.why)") }
            }
        }
        let englishInStem = englishRuns(p.stem)
        if Set(englishInStem.map { $0.lowercased() }).count == 1, let word = englishInStem.first, let list = meanings(of: word) {
            hints.append("단어장: \(word) = \(list.joined(separator: ", "))")
        }
        return hints
    }

    /// 문제와 관련된 개념 설명 (모델이 근거로 쓰게)
    static func reference(problem: String, choices: [String], subject: NoteSubject, limit: Int = 3) -> [String] {
        let entries = DoitSubjectNote.concepts(problem: problem, choices: choices, subject: subject, limit: limit)
        return entries.map { entry in
            let body = entry.body.components(separatedBy: "\n").prefix(2).joined(separator: " ")
            return "\(entry.title): " + String(body.prefix(220))
        }
    }
}
