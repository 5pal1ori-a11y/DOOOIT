import Foundation

// MARK: - 과목 풀이 더하기: 과학 계산 (역학적 에너지 보존, 일률 = 힘 × 속력, 렌즈·거울, 직렬·병렬 회로, 질량 보존, 화학 반응식 계수)
// - DoitScience가 하지 않는 계산만. 값·단위·조건이 분명할 때만 답하고, 조건이 빠지거나 겹치면 nil

extension DoitSubjectSolve {
    /// 과학 계산 더하기 (계산 문제가 아니면 nil)
    static func scienceMore(_ p: Problem) -> Found? {
        if p.isChoice, !p.choices.allSatisfy(isNumberLike) { return nil }
        return energyConservation(p) ?? powerForceSpeed(p) ?? lensMirror(p) ?? circuit(p) ?? massConservation(p) ?? equationCoefficients(p)
    }

    /// 선지가 수(·단위·쉼표)뿐인지 ("3 m/s", "3, 2", "30°")
    static func isNumberLike(_ choice: String) -> Bool {
        let t = choice.trimmingCharacters(in: .whitespaces)
        guard let first = t.first, first.isNumber || first == "-" || first == "0" else { return false }
        return t.filter { DoitSubjectNote.isHangul($0) }.count <= 3
    }

    /// 계산한 값으로 답하기: 객관식이면 같은 값의 선지 하나, 아니면 값 글
    static func answerValue(_ p: Problem, value: Double, unit: String, dimension: String?, concept: String, steps: [SolutionStep]) -> Found? {
        let shown = unit.isEmpty ? DoitScience.fmt(value) : "\(DoitScience.fmt(value)) \(unit)"
        var all = steps
        all.append(SolutionStep(hint: "답", work: shown))
        guard p.isChoice else { return Found(answer: shown, concept: concept, steps: all) }
        func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) <= max(1e-9, abs(b) * 2e-3) }
        let hits = p.choices.indices.filter { i in
            let choice = p.choices[i]
            if let dimension, let q = DoitScience.quantities(in: choice).first {
                guard q.dimension == dimension else { return false }
                let unitQ = DoitScience.quantities(in: "1 " + unit).first
                return close(q.si, value * (unitQ?.si ?? 1))
            }
            var cleaned = choice.replacingOccurrences(of: "°", with: "")
            if !unit.isEmpty { cleaned = cleaned.replacingOccurrences(of: unit, with: "") }
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)
            return plainNumber(cleaned).map { close($0.raw, value) } ?? false
        }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: concept, steps: all)
    }

    private static func lengths(_ text: String) -> [DoitScience.Quantity] { DoitScience.quantities(in: text).filter { $0.dimension == "length" } }

    // MARK: 역학적 에너지 보존

    /// 떨어뜨린 물체의 속력·운동 에너지, 위로 던진 물체의 최고 높이 (공기 저항·마찰이 없을 때)
    static func energyConservation(_ p: Problem) -> Found? {
        let c = p.compact
        guard !matches(c, #"(마찰이있|공기저항이있|공기저항을무시하지|저항을받)"#) else { return nil }
        let qs = DoitScience.quantities(in: p.stem)
        let g = DoitScience.gravity(in: p.full)
        let rule = SolutionStep(hint: "역학적 에너지 보존", work: "공기 저항이 없으면 줄어든 위치 에너지 = 늘어난 운동 에너지 (mgh = ½mv²)")
        let dropped = matches(c, #"(가만히(떨어뜨|놓)|자유낙하|정지상태에서(떨어|출발)|정지상태로출발|떨어뜨렸|떨어뜨릴|떨어뜨린|떨어뜨리)"#) && !matches(c, #"던"#)
        let thrownUp = matches(c, #"(연직|수직|똑바로)?위(쪽)?로던"#)
        let heights = lengths(p.stem)
        // 위로 던진 물체: 최고 높이 = v² ÷ 2g
        if thrownUp, matches(c, #"(최고높이|최고점|올라가는높이|올라갈수있는.{0,6}높이|올라간높이)"#) {
            let speeds = qs.filter { $0.dimension == "speed" }
            guard speeds.count == 1, heights.isEmpty else { return nil }
            let v = speeds[0].si
            let h = v * v / (2 * g)
            let steps = [rule, SolutionStep(hint: "식", work: "½mv² = mgh → h = v² ÷ 2g"),
                         SolutionStep(hint: "값 넣기", work: "h = (\(DoitScience.fmt(v)))² ÷ (2 × \(DoitScience.fmt(g))) = \(DoitScience.fmt(h)) m")]
            return answerValue(p, value: h, unit: "m", dimension: "length", concept: "역학적 에너지 보존", steps: steps)
        }
        guard dropped else { return nil }
        // 떨어진 높이: 높이 하나면 그것, 둘이면 (처음 높이 − 지나는 지점 높이)
        var fall: Double
        var fallText: String
        if heights.count == 1 {
            fall = heights[0].si; fallText = "\(DoitScience.fmt(fall)) m"
        } else if heights.count == 2, matches(c, #"(지점|높이).{0,12}(지나|통과|도달)"#) {
            fall = heights[0].si - heights[1].si
            guard fall > 0 else { return nil }
            fallText = "\(DoitScience.fmt(heights[0].si)) m − \(DoitScience.fmt(heights[1].si)) m = \(DoitScience.fmt(fall)) m"
        } else { return nil }
        let masses = qs.filter { $0.dimension == "mass" }
        if matches(c, #"(속력|속도)(은|는|이|을|가|으로)?(몇|\?|얼마)"#) || matches(c, #"(순간|직전|지점|때)의?(속력|속도)"#) {
            guard heights.count == 1 || matches(c, #"지나"#) else { return nil }
            let v = (2 * g * fall).squareRoot()
            // 루트가 깔끔하지 않으면 (선지와 맞추기 어려움) 그래도 값으로 비교
            let steps = [rule, SolutionStep(hint: "떨어진 높이", work: fallText), SolutionStep(hint: "식", work: "mgh = ½mv² → v = √(2gh)"),
                         SolutionStep(hint: "값 넣기", work: "v = √(2 × \(DoitScience.fmt(g)) × \(DoitScience.fmt(fall))) = \(DoitScience.fmt(v)) m/s")]
            return answerValue(p, value: v, unit: "m/s", dimension: "speed", concept: "역학적 에너지 보존", steps: steps)
        }
        if matches(c, #"운동에너지"#), !matches(c, #"위치에너지(는|은|를|가)?(몇|얼마)"#) {
            guard masses.count == 1 else { return nil }
            let m = masses[0].si
            let e = m * g * fall
            let steps = [rule, SolutionStep(hint: "떨어진 높이", work: fallText),
                         SolutionStep(hint: "운동 에너지", work: "늘어난 운동 에너지 = 줄어든 위치 에너지 = mgh = \(DoitScience.fmt(m)) × \(DoitScience.fmt(g)) × \(DoitScience.fmt(fall)) = \(DoitScience.fmt(e)) J")]
            return answerValue(p, value: e, unit: "J", dimension: "energy", concept: "역학적 에너지 보존", steps: steps)
        }
        return nil
    }

    // MARK: 일률 = 힘 × 속력

    static func powerForceSpeed(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"(일정한속력|등속|일정한속도)"#) else { return nil }
        let qs = DoitScience.quantities(in: p.stem)
        let forces = qs.filter { $0.dimension == "force" }, speeds = qs.filter { $0.dimension == "speed" }, powers = qs.filter { $0.dimension == "power" }
        guard speeds.count == 1, !qs.contains(where: { $0.dimension == "time" || $0.dimension == "length" }) else { return nil }
        let v = speeds[0].si
        if matches(c, #"일률(은|는|을|이)?"#), powers.isEmpty, forces.count == 1 {
            let power = forces[0].si * v
            let steps = [SolutionStep(hint: "식", work: "일률 = 일 ÷ 시간 = 힘 × (거리 ÷ 시간) = 힘 × 속력"),
                         SolutionStep(hint: "값 넣기", work: "P = \(DoitScience.fmt(forces[0].si)) N × \(DoitScience.fmt(v)) m/s = \(DoitScience.fmt(power)) W")]
            return answerValue(p, value: power, unit: "W", dimension: "power", concept: "일률 = 힘 × 속력", steps: steps)
        }
        if matches(c, #"힘(은|는|의크기|을|이)?.{0,6}(몇|얼마)"#) || matches(c, #"작용하는힘은"#), powers.count == 1, forces.isEmpty, v > 0 {
            let force = powers[0].si / v
            let steps = [SolutionStep(hint: "식", work: "일률 = 힘 × 속력 → 힘 = 일률 ÷ 속력"),
                         SolutionStep(hint: "값 넣기", work: "F = \(DoitScience.fmt(powers[0].si)) W ÷ \(DoitScience.fmt(v)) m/s = \(DoitScience.fmt(force)) N")]
            return answerValue(p, value: force, unit: "N", dimension: "force", concept: "일률 = 힘 × 속력", steps: steps)
        }
        return nil
    }

    // MARK: 렌즈 · 거울

    static func lensMirror(_ p: Problem) -> Found? {
        let c = p.compact
        func number(_ pattern: String) -> Double? {
            guard let regex = try? NSRegularExpression(pattern: pattern), let m = regex.firstMatch(in: c, range: NSRange(c.startIndex..., in: c)),
                  let r = Range(m.range(at: 1), in: c) else { return nil }
            return Double(c[r])
        }
        if c.contains("배율") {
            var ratio: Double?
            var work = ""
            if let object = number(#"물체의?크기(?:가|는|이)?([0-9.]+)"#),
               let image = number(#"상의?크기(?:가|는|이)?([0-9.]+)"#), object > 0, !c.contains("거리") {
                ratio = image / object; work = "배율 = 상의 크기 ÷ 물체의 크기 = \(DoitScience.fmt(image)) ÷ \(DoitScience.fmt(object))"
            } else if let a = number(#"물체까지의?거리(?:가|는|이)?([0-9.]+)"#), let b = number(#"상까지의?거리(?:가|는|이)?([0-9.]+)"#), a > 0, !c.contains("크기") {
                ratio = b / a; work = "배율 = 렌즈에서 상까지 거리 ÷ 렌즈에서 물체까지 거리 = \(DoitScience.fmt(b)) ÷ \(DoitScience.fmt(a))"
            }
            guard let ratio else { return nil }
            let steps = [SolutionStep(hint: "배율", work: work)]
            if p.isChoice { return answerValue(p, value: ratio, unit: "배", dimension: nil, concept: "렌즈의 배율", steps: steps) }
            var all = steps
            all.append(SolutionStep(hint: "답", work: "\(DoitScience.fmt(ratio))배"))
            return Found(answer: "\(DoitScience.fmt(ratio))배", concept: "렌즈의 배율", steps: all)
        }
        if c.contains("반사각"), !c.contains("굴절") {
            var angle: Double?
            var work = ""
            if let i = number(#"입사각(?:이|은|는)?([0-9.]+)(?:°|도)"#), !c.contains("거울면과") {
                angle = i; work = "반사 법칙: 입사각 = 반사각 = \(DoitScience.fmt(i))°"
            } else if let s = number(#"거울면과([0-9.]+)(?:°|도)"#), s < 90 {
                angle = 90 - s; work = "입사각은 법선과 이루는 각: 90° − \(DoitScience.fmt(s))° = \(DoitScience.fmt(90 - s))°, 반사각 = 입사각"
            }
            guard let angle else { return nil }
            let steps = [SolutionStep(hint: "반사 법칙", work: work)]
            if p.isChoice { return answerValue(p, value: angle, unit: "°", dimension: nil, concept: "빛의 반사", steps: steps) }
            return Found(answer: "\(DoitScience.fmt(angle))°", concept: "빛의 반사", steps: steps + [SolutionStep(hint: "답", work: "\(DoitScience.fmt(angle))°")])
        }
        // 평면거울: 상은 거울 뒤 같은 거리
        if c.contains("평면거울"), matches(c, #"상(사이|까지)의?거리"#), let d = lengths(p.stem).first, lengths(p.stem).count == 1 {
            let both = matches(c, #"(사람|물체|나|학생)과.{0,10}상사이"#)
            guard both || matches(c, #"거울과.{0,6}상사이"#) else { return nil }
            let value = both ? 2 * d.si : d.si
            let steps = [SolutionStep(hint: "평면거울", work: "상은 거울 뒤쪽, 거울에서 물체까지와 같은 거리에 생겨요."),
                         SolutionStep(hint: "거리", work: both ? "\(DoitScience.fmt(d.si)) m + \(DoitScience.fmt(d.si)) m = \(DoitScience.fmt(value)) m" : "\(DoitScience.fmt(value)) m")]
            return answerValue(p, value: value, unit: "m", dimension: "length", concept: "평면거울의 상", steps: steps)
        }
        return nil
    }

    // MARK: 직렬 · 병렬 회로

    static func circuit(_ p: Problem) -> Found? {
        let c = p.compact
        let series = c.contains("직렬"), parallel = c.contains("병렬")
        guard series != parallel else { return nil }
        // 저항 값 (같은 저항 N개 포함)
        var values: [Double] = []
        let text = p.stem.replacingOccurrences(of: "옴", with: "Ω")
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*Ω(?:인|의|짜리)?\s*(?:저항)?\s*(두|세|네|2|3|4)\s*개"#
        var counted = Set<Int>()
        if let regex = try? NSRegularExpression(pattern: pattern) {
            for m in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let r1 = Range(m.range(at: 1), in: text), let r2 = Range(m.range(at: 2), in: text), let v = Double(text[r1]) else { continue }
                let n = ["두": 2, "세": 3, "네": 4][String(text[r2])] ?? Int(text[r2]) ?? 1
                values += Array(repeating: v, count: n)
                counted.insert(m.range(at: 1).location)
            }
        }
        if values.isEmpty {
            values = DoitScience.quantities(in: text).filter { $0.dimension == "resistance" }.map(\.si)
        }
        guard values.count >= 2, values.allSatisfy({ $0 > 0 }) else { return nil }
        let total = parallel ? 1 / values.reduce(0) { $0 + 1 / $1 } : values.reduce(0, +)
        let formula = parallel ? "1/R = " + values.map { "1/\(DoitScience.fmt($0))" }.joined(separator: " + ") + " → R = \(DoitScience.fmt(total)) Ω"
                               : "R = " + values.map { DoitScience.fmt($0) }.joined(separator: " + ") + " = \(DoitScience.fmt(total)) Ω"
        let steps = [SolutionStep(hint: parallel ? "병렬 연결" : "직렬 연결", work: formula)]
        let qs = DoitScience.quantities(in: text)
        let volts = qs.filter { $0.dimension == "voltage" }, amps = qs.filter { $0.dimension == "current" }
        if matches(c, #"전류(의세기)?(는|은|를|가)?(몇|\?|얼마)"#) || matches(c, #"흐르는전류"#) {
            guard volts.count == 1, amps.isEmpty, !matches(c, #"(각저항|한저항|저항하나|에흐르는전류.{0,3}각각)"#) else { return nil }
            if parallel, !c.contains("전체") { return nil }
            let i = volts[0].si / total
            let all = steps + [SolutionStep(hint: "옴의 법칙", work: "I = V ÷ R = \(DoitScience.fmt(volts[0].si)) V ÷ \(DoitScience.fmt(total)) Ω = \(DoitScience.fmt(i)) A")]
            return answerValue(p, value: i, unit: "A", dimension: "current", concept: parallel ? "병렬 회로" : "직렬 회로", steps: all)
        }
        if matches(c, #"(합성저항|전체저항|합성된저항)"#), volts.isEmpty, amps.isEmpty {
            return answerValue(p, value: total, unit: "Ω", dimension: "resistance", concept: parallel ? "병렬 연결 합성 저항" : "직렬 연결 합성 저항", steps: steps)
        }
        return nil
    }

    // MARK: 질량 보존

    static func massConservation(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"완전히.{0,4}(반응|연소|타)"#), c.contains("질량") else { return nil }
        let masses = DoitScience.quantities(in: p.stem).filter { $0.dimension == "mass" }
        guard masses.count == 2 else { return nil }
        let a = masses[0].si * 1000, b = masses[1].si * 1000
        let productGiven = matches(c, #"[0-9.]+(g|kg)(이|가)?(생성|만들어|생겼|얻었)"#)
        let rule = SolutionStep(hint: "질량 보존 법칙", work: "화학 반응 전 물질의 질량 합 = 반응 후 물질의 질량 합")
        var value: Double
        var work: String
        if productGiven, matches(c, #"반응한.{0,10}질량"#) {
            guard b > a else { return nil }
            value = b - a; work = "반응한 물질 = 생성물 − 처음 물질 = \(DoitScience.fmt(b)) g − \(DoitScience.fmt(a)) g = \(DoitScience.fmt(value)) g"
        } else if !productGiven, matches(c, #"(생성된|생긴|만들어진|얻어진).{0,15}질량"#) {
            value = a + b; work = "생성물 = \(DoitScience.fmt(a)) g + \(DoitScience.fmt(b)) g = \(DoitScience.fmt(value)) g"
        } else { return nil }
        return answerValue(p, value: value, unit: "g", dimension: "mass", concept: "질량 보존 법칙", steps: [rule, SolutionStep(hint: "계산", work: work)])
    }

    // MARK: 화학 반응식 계수 맞추기

    /// 화학식 → 원소별 원자 수 ("H2O" → H 2, O 1). 모르는 글자가 있으면 nil
    static func atoms(_ formula: String) -> [String: Int]? {
        let chars = Array(formula)
        var i = 0
        func group() -> [String: Int]? {
            var out: [String: Int] = [:]
            while i < chars.count {
                let ch = chars[i]
                if ch == "(" {
                    i += 1
                    guard let inner = group(), i < chars.count, chars[i] == ")" else { return nil }
                    i += 1
                    let n = count()
                    for (k, v) in inner { out[k, default: 0] += v * n }
                } else if ch == ")" {
                    return out
                } else if ch.isUppercase, ch.isASCII {
                    var symbol = String(ch)
                    i += 1
                    if i < chars.count, chars[i].isLowercase, chars[i].isASCII { symbol.append(chars[i]); i += 1 }
                    out[symbol, default: 0] += count()
                } else { return nil }
            }
            return out
        }
        func count() -> Int {
            var digits = ""
            while i < chars.count, chars[i].isASCII, chars[i].isNumber { digits.append(chars[i]); i += 1 }
            return Int(digits) ?? 1
        }
        guard let result = group(), i == chars.count, !result.isEmpty else { return nil }
        return result
    }

    static func equationCoefficients(_ p: Problem) -> Found? {
        // 아래 첨자 숫자 → 보통 숫자
        let subscripts: [Character: Character] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9"]
        let text = String(p.full.map { subscripts[$0] ?? $0 }).replacingOccurrences(of: "->", with: "→").replacingOccurrences(of: "⟶", with: "→")
        guard let line = text.components(separatedBy: "\n").first(where: { $0.contains("→") }) else { return nil }
        // 반응식 부분만 ("화학 반응식 N2 + aH2 → bNH3에서" → "N2 + aH2 → bNH3")
        guard let eq = line.firstMatch(of: #/((?:[a-f0-9]*\s*[A-Z][A-Za-z0-9()]*\s*\+\s*)*[a-f0-9]*\s*[A-Z][A-Za-z0-9()]*)\s*→\s*((?:[a-f0-9]*\s*[A-Z][A-Za-z0-9()]*\s*\+\s*)*[a-f0-9]*\s*[A-Z][A-Za-z0-9()]*)/#) else { return nil }
        struct Term { let coef: Int?; let letter: Character?; let atoms: [String: Int] }
        func terms(_ side: Substring) -> [Term]? {
            var out: [Term] = []
            for raw in side.split(separator: "+") {
                let t = raw.trimmingCharacters(in: .whitespaces)
                guard let m = t.firstMatch(of: #/^([a-f]|[0-9]+)?\s*([A-Z][A-Za-z0-9()]*)$/#) else { return nil }
                guard let a = atoms(String(m.2)) else { return nil }
                var coef: Int?, letter: Character?
                if let c = m.1 { if let n = Int(c) { coef = n } else { letter = c.first } } else { coef = 1 }
                out.append(Term(coef: coef, letter: letter, atoms: a))
            }
            return out
        }
        guard let left = terms(eq.1), let right = terms(eq.2) else { return nil }
        let letters = (left + right).compactMap(\.letter)
        guard !letters.isEmpty, letters.count <= 4, Set(letters).count == letters.count else { return nil }
        let elements = Set((left + right).flatMap { $0.atoms.keys })
        var solutions: [[Character: Int]] = []
        let maxC = 12
        var assignment: [Character: Int] = [:]
        func balanced() -> Bool {
            for e in elements {
                let l = left.reduce(0) { $0 + ($1.coef ?? assignment[$1.letter!]!) * ($1.atoms[e] ?? 0) }
                let r = right.reduce(0) { $0 + ($1.coef ?? assignment[$1.letter!]!) * ($1.atoms[e] ?? 0) }
                if l != r { return false }
            }
            return true
        }
        func search(_ k: Int) {
            if k == letters.count { if balanced() { solutions.append(assignment) }; return }
            for v in 1...maxC { assignment[letters[k]] = v; search(k + 1) }
        }
        search(0)
        // 정해진 계수가 없으면 가장 작은 정수 비 (최대공약수 1)
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        // 계수가 정해진 물질이 있으면 배수가 정해지고, 모두 문자면 가장 작은 정수 비
        let allLetters = (left + right).allSatisfy { $0.letter != nil }
        let candidates = allLetters ? solutions.filter { s in (left + right).map { s[$0.letter!]! }.reduce(0, gcd) == 1 } : solutions
        guard candidates.count == 1, let solution = candidates.first else { return nil }
        let steps = [SolutionStep(hint: "원자 수 맞추기", work: "반응 전후 원소마다 원자 수가 같아야 해요 (원자는 없어지거나 새로 생기지 않아요)."),
                     SolutionStep(hint: "계수", work: letters.map { "\($0) = \(solution[$0]!)" }.joined(separator: ", "))]
        let stem = p.compact
        // 묻는 것: a + b + c, a와 b (차례대로), a 하나
        if let m = stem.firstMatch(of: #/([a-f](?:\+[a-f])+)의?값/#) {
            let asked = m.1.split(separator: "+").compactMap(\.first)
            guard asked.allSatisfy({ solution[$0] != nil }) else { return nil }
            let sum = asked.reduce(0) { $0 + solution[$1]! }
            return answerValue(p, value: Double(sum), unit: "", dimension: nil, concept: "화학 반응식의 계수", steps: steps + [SolutionStep(hint: "합", work: asked.map { String(solution[$0]!) }.joined(separator: " + ") + " = \(sum)")])
        }
        // "계수 a, b, c를 옳게 짝지은 것은?" — 선지의 수가 문자 차례와 같을 때
        if p.isChoice, letters.count >= 2, stem.contains(letters.map(String.init).joined(separator: ",")) {
            let hits = p.choices.indices.filter { i in
                let nums = p.choices[i].matches(of: #/[0-9]+/#).compactMap { Int($0.output) }
                return nums == letters.map { solution[$0]! }
            }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "화학 반응식의 계수", steps: steps)
        }
        if let m = stem.firstMatch(of: #/([a-f])(와|과)([a-f])에?/#), stem.contains("차례"), p.isChoice {
            guard let x = m.1.first, let y = m.3.first, let vx = solution[x], let vy = solution[y] else { return nil }
            let hits = p.choices.indices.filter { i in
                let nums = p.choices[i].matches(of: #/[0-9]+/#).compactMap { Int($0.output) }
                return nums == [vx, vy]
            }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "화학 반응식의 계수", steps: steps)
        }
        if let m = stem.firstMatch(of: #/(?:^|[^a-zA-Z])([a-f])(의값|에알맞은|는|은|값은|의계수)/#), let x = m.1.first, let v = solution[x] {
            return answerValue(p, value: Double(v), unit: "", dimension: nil, concept: "화학 반응식의 계수", steps: steps)
        }
        return nil
    }
}
