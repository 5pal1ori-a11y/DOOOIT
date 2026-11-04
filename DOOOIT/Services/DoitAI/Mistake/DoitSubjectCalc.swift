import Foundation

// MARK: - 과목 풀이 더하기: 계산 문제 더 (과학 · 사회)
// - 과학: 등가속도 · 자유 낙하(시간) · 운동량 · 충격량 · 충돌 · 지레 · 변압기 · 열효율 · 원자 구성 · 이온의 전자 수 · 원자가 전자 ·
//   몰 농도 · pH 비 · 보일/샤를 법칙 · 질량비 · 용해도 · 유전(교배 · 혈액형) · DNA 염기 비율 · 반감기 · 연주 시차 · 등급 · 상대 습도 · 에너지 효율 · 염색체 수
// - 사회: 실업률 · 고용률 · 물가 상승률 · 경제 성장률 · 가격 탄력성 · 단리/복리 · 축척 · 부양비
// - 값·조건이 문제에 다 있고 묻는 것이 분명할 때만 계산해요. 하나라도 빠지거나 겹치면 nil

extension DoitSubjectSolve {
    // MARK: 공통

    /// 첫 일치의 묶음들 (없으면 nil)
    static func groups(_ text: String, _ pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<m.numberOfRanges).map { i in Range(m.range(at: i), in: text).map { String(text[$0]) } ?? "" }
    }

    static func count(_ text: String, _ pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    /// 띄어쓰기·쉼표(천 단위)를 뺀 글
    static func dense(_ text: String) -> String {
        var t = text.filter { !$0.isWhitespace }
        t = t.replacingOccurrences(of: #"(?<=[0-9]),(?=[0-9]{3})"#, with: "", options: .regularExpression)
        return t
    }

    /// 분수 답: 객관식이면 값이 같은 선지 하나 ("1/4", "25 %", "0.25", "0", "1")
    static func answerFraction(_ p: Problem, numerator: Int, denominator: Int, concept: String, steps: [SolutionStep]) -> Found? {
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        let g = max(1, gcd(numerator, denominator))
        let n = numerator / g, d = denominator / g
        let shown = n == 0 ? "0" : d == 1 ? "\(n)" : "\(n)/\(d)"
        let value = Double(n) / Double(d)
        var all = steps
        all.append(SolutionStep(hint: "답", work: shown))
        guard p.isChoice else { return Found(answer: shown, concept: concept, steps: all) }
        let hits = p.choices.indices.filter { i in fractionValue(p.choices[i]).map { abs($0 - value) < 1e-9 } ?? false }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: concept, steps: all)
    }

    static func fractionValue(_ choice: String) -> Double? {
        let t = choice.filter { !$0.isWhitespace }
        if let g = groups(t, #"^([0-9]+)/([0-9]+)$"#), let a = Double(g[1]), let b = Double(g[2]), b > 0 { return a / b }
        if let g = groups(t, #"^([0-9]+(?:\.[0-9]+)?)%$"#), let a = Double(g[1]) { return a / 100 }
        if let g = groups(t, #"^([0-9]+(?:\.[0-9]+)?)$"#), let a = Double(g[1]), a <= 1 { return a }
        return nil
    }

    /// 비 답 ("1 : 1", "9 : 3 : 3 : 1"): 줄인 비가 같은 선지 하나 (ordered: 순서까지 같아야 하는지)
    static func answerRatio(_ p: Problem, _ ratio: [Int], ordered: Bool, concept: String, steps: [SolutionStep]) -> Found? {
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        func reduce(_ r: [Int]) -> [Int] { let g = r.reduce(0, gcd); return g > 0 ? r.map { $0 / g } : r }
        let want = reduce(ratio)
        let shown = want.map(String.init).joined(separator: " : ")
        var all = steps
        all.append(SolutionStep(hint: "답", work: shown))
        guard p.isChoice else { return Found(answer: shown, concept: concept, steps: all) }
        let hits = p.choices.indices.filter { i in
            let parts = p.choices[i].components(separatedBy: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2, let nums = Optional(parts.compactMap { Int($0) }), nums.count == parts.count else { return false }
            let r = reduce(nums)
            return ordered ? r == want : r.sorted() == want.sorted()
        }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: concept, steps: all)
    }

    // MARK: 과학 계산 더

    static func scienceCalc2(_ p: Problem) -> Found? {
        if p.isChoice, !p.choices.allSatisfy({ isNumberLike($0) || fractionValue($0) != nil || $0.contains(":") }) { return nil }
        let solvers: [(Problem) -> Found?] = [kinematics, freeFallTime, momentumCalc, impulseCalc, collisionCalc, leverCalc, transformerCalc, efficiencyCalc,
                                              nucleusCalc, ionElectrons, valenceElectrons, molarityCalc, phRatio, gasLaw, massRatio, solubilityCalc,
                                              geneticsCalc, bloodTypeCalc, dnaBase, halfLife, parallaxCalc, magnitudeCalc, humidityCalc, ecoEfficiency, chromosomeHalf]
        for solver in solvers { if let found = solver(p) { return found } }
        return nil
    }

    private static func qs(_ p: Problem, _ dimension: String) -> [DoitScience.Quantity] { DoitScience.quantities(in: p.stem).filter { $0.dimension == dimension } }

    /// 정지 상태에서 출발한 등가속도 운동: 나중 속력 v = at, 이동 거리 s = ½at²
    static func kinematics(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"정지(해있던|한|상태에서|상태로)"#), !matches(c, #"(던|떨어뜨|낙하|정지하였|정지했|멈추|브레이크|감속)"#) else { return nil }
        let a = qs(p, "accel"), t = qs(p, "time")
        guard a.count == 1, t.count == 1, qs(p, "speed").isEmpty, qs(p, "length").isEmpty, qs(p, "force").isEmpty, qs(p, "mass").isEmpty else { return nil }
        let av = a[0].si, tv = t[0].si
        let rule = SolutionStep(hint: "등가속도 운동", work: "정지 상태에서 출발: 나중 속력 v = at, 이동 거리 s = ½at²")
        if matches(c, #"(나중속력|나중속도|속력은|속도는|속력이?몇|속도가?몇|속력을|속력의크기)"#), !matches(c, #"거리"#) {
            let v = av * tv
            return answerValue(p, value: v, unit: "m/s", dimension: "speed", concept: "등가속도 운동", steps: [rule, SolutionStep(hint: "값 넣기", work: "v = \(DoitScience.fmt(av)) × \(DoitScience.fmt(tv)) = \(DoitScience.fmt(v)) m/s")])
        }
        if matches(c, #"(이동한거리|이동거리|간거리|움직인거리)"#) {
            let s = 0.5 * av * tv * tv
            return answerValue(p, value: s, unit: "m", dimension: "length", concept: "등가속도 운동", steps: [rule, SolutionStep(hint: "값 넣기", work: "s = ½ × \(DoitScience.fmt(av)) × \(DoitScience.fmt(tv))² = \(DoitScience.fmt(s)) m")])
        }
        return nil
    }

    /// 가만히 떨어뜨린 물체의 시간에 따른 속력 v = gt, 떨어진 거리 s = ½gt² (공기 저항 무시)
    static func freeFallTime(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"(가만히(떨어뜨|놓)|자유낙하)"#), !matches(c, #"(던|마찰이있|공기저항이있|빗면)"#), matches(c, #"(공기저항(은|을)?무시|공기저항이없|자유낙하)"#) else { return nil }
        let t = qs(p, "time")
        guard t.count == 1, qs(p, "length").isEmpty, qs(p, "speed").isEmpty else { return nil }
        let g = DoitScience.gravity(in: p.full), tv = t[0].si
        let rule = SolutionStep(hint: "자유 낙하", work: "가속도가 중력 가속도 g로 일정한 등가속도 운동: v = gt, s = ½gt²")
        if matches(c, #"(속력|속도)(은|는|이|을|가)?(몇|\?|얼마)"#), !matches(c, #"거리"#) {
            let v = g * tv
            return answerValue(p, value: v, unit: "m/s", dimension: "speed", concept: "자유 낙하 운동", steps: [rule, SolutionStep(hint: "값 넣기", work: "v = \(DoitScience.fmt(g)) × \(DoitScience.fmt(tv)) = \(DoitScience.fmt(v)) m/s")])
        }
        if matches(c, #"(떨어진거리|낙하한거리|낙하거리|이동한거리)"#) {
            let s = 0.5 * g * tv * tv
            return answerValue(p, value: s, unit: "m", dimension: "length", concept: "자유 낙하 운동", steps: [rule, SolutionStep(hint: "값 넣기", work: "s = ½ × \(DoitScience.fmt(g)) × \(DoitScience.fmt(tv))² = \(DoitScience.fmt(s)) m")])
        }
        return nil
    }

    /// 운동량 p = mv
    static func momentumCalc(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"운동량(의크기)?(은|는|을|이)?.{0,6}(몇|\?|얼마)"#), !matches(c, #"(충돌|충격량|변화량|나중|처음)"#) else { return nil }
        let m = qs(p, "mass"), v = qs(p, "speed")
        guard m.count == 1, v.count == 1 else { return nil }
        let value = m[0].si * v[0].si
        return answerValue(p, value: value, unit: "kg·m/s", dimension: nil, concept: "운동량", steps: [SolutionStep(hint: "운동량", work: "p = mv = \(DoitScience.fmt(m[0].si)) kg × \(DoitScience.fmt(v[0].si)) m/s = \(DoitScience.fmt(value)) kg·m/s")])
    }

    /// 충격량 I = Ft
    static func impulseCalc(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"충격량(의크기)?(은|는|을|이)?.{0,6}(몇|\?|얼마)"#) else { return nil }
        let f = qs(p, "force"), t = qs(p, "time")
        guard f.count == 1, t.count == 1, qs(p, "mass").isEmpty, qs(p, "speed").isEmpty else { return nil }
        let value = f[0].si * t[0].si
        return answerValue(p, value: value, unit: "N·s", dimension: nil, concept: "충격량", steps: [SolutionStep(hint: "충격량", work: "I = Ft = \(DoitScience.fmt(f[0].si)) N × \(DoitScience.fmt(t[0].si)) s = \(DoitScience.fmt(value)) N·s")])
    }

    /// 정지한 물체와 충돌해 한 덩어리가 됨: 운동량 보존 m₁v = (m₁ + m₂)V
    static func collisionCalc(_ p: Problem) -> Found? {
        let c = p.compact
        guard c.contains("충돌"), matches(c, #"(한덩어리|붙어서|붙은채|함께운동)"#), matches(c, #"정지(해있던|한)"#) else { return nil }
        guard matches(c, #"(속력|속도)(은|는|을|이)?.{0,6}(몇|\?|얼마)"#) else { return nil }
        let m = qs(p, "mass"), v = qs(p, "speed")
        guard m.count == 2, v.count == 1 else { return nil }
        // 속력은 처음 물체(첫째 질량)의 것
        let total = m[0].si + m[1].si
        guard total > 0 else { return nil }
        let value = m[0].si * v[0].si / total
        let steps = [SolutionStep(hint: "운동량 보존", work: "충돌 전 운동량의 합 = 충돌 후 운동량의 합"),
                     SolutionStep(hint: "값 넣기", work: "\(DoitScience.fmt(m[0].si)) × \(DoitScience.fmt(v[0].si)) = (\(DoitScience.fmt(m[0].si)) + \(DoitScience.fmt(m[1].si))) × V → V = \(DoitScience.fmt(value)) m/s")]
        return answerValue(p, value: value, unit: "m/s", dimension: "speed", concept: "운동량 보존", steps: steps)
    }

    /// 지레: 물체 무게 × 받침점~물체 거리 = 힘 × 받침점~힘 거리 (거리 → 무게 → 거리 차례로 쓴 글만)
    static func leverCalc(_ p: Problem) -> Found? {
        let c = p.compact
        guard c.contains("지레"), c.contains("받침점"), matches(c, #"(몇N|힘은|힘의크기)"#) else { return nil }
        let all = DoitScience.quantities(in: p.stem)
        let kinds = all.map(\.dimension).filter { $0 == "length" || $0 == "force" }
        guard kinds == ["length", "force", "length"] else { return nil }
        let l = all.filter { $0.dimension == "length" }, w = all.filter { $0.dimension == "force" }
        guard l.count == 2, w.count == 1, l[1].si > 0, c.contains("반대") else { return nil }
        let value = w[0].si * l[0].si / l[1].si
        let steps = [SolutionStep(hint: "지레의 원리", work: "물체의 무게 × 받침점에서 물체까지 거리 = 힘 × 받침점에서 힘까지 거리"),
                     SolutionStep(hint: "값 넣기", work: "\(DoitScience.fmt(w[0].si)) × \(DoitScience.fmt(l[0].si)) = F × \(DoitScience.fmt(l[1].si)) → F = \(DoitScience.fmt(value)) N")]
        return answerValue(p, value: value, unit: "N", dimension: "force", concept: "지레의 원리", steps: steps)
    }

    /// 변압기: V₁ : V₂ = N₁ : N₂
    static func transformerCalc(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard c.contains("변압기"), let n1 = groups(c, #"1차코일의?감은수가?([0-9]+)회"#).flatMap({ Double($0[1]) }),
              let n2 = groups(c, #"2차코일의?감은수가?([0-9]+)회"#).flatMap({ Double($0[1]) }), n1 > 0, n2 > 0 else { return nil }
        let v = qs(p, "voltage")
        guard v.count == 1, qs(p, "current").isEmpty else { return nil }
        let rule = SolutionStep(hint: "변압기", work: "에너지 손실이 없으면 전압은 코일의 감은 수에 비례해요: V₁ : V₂ = N₁ : N₂")
        if matches(c, #"2차코일에?걸리는전압"#), matches(c, #"1차코일에.{0,10}전압을?걸"#) {
            let value = v[0].si * n2 / n1
            return answerValue(p, value: value, unit: "V", dimension: "voltage", concept: "변압기", steps: [rule, SolutionStep(hint: "값 넣기", work: "V₂ = \(DoitScience.fmt(v[0].si)) × \(DoitScience.fmt(n2)) ÷ \(DoitScience.fmt(n1)) = \(DoitScience.fmt(value)) V")])
        }
        return nil
    }

    /// 열기관의 열효율 = 한 일 ÷ 흡수한 열 × 100
    static func efficiencyCalc(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard c.contains("열효율"), count(c, #"[0-9]"#) > 0 else { return nil }
        func joules(_ g: [String]) -> Double? { Double(g[1]).map { g[2] == "kJ" ? $0 * 1000 : $0 } }
        guard let q1 = groups(c, #"([0-9.]+)(k?J)의?열(에너지)?을?(흡수|공급받|받)"#).flatMap(joules) else { return nil }
        var work: Double?
        if let w = groups(c, #"([0-9.]+)(k?J)의?일을"#).flatMap(joules) { work = w }
        if let q2 = groups(c, #"([0-9.]+)(k?J)의?열(에너지)?을?(방출|버리|내보내)"#).flatMap(joules) {
            guard work == nil else { return nil }
            work = q1 - q2
        }
        guard let w = work, q1 > 0, w > 0, w <= q1 else { return nil }
        let value = w / q1 * 100
        return answerValue(p, value: value, unit: "%", dimension: nil, concept: "열효율",
                           steps: [SolutionStep(hint: "열효율", work: "열효율 = 한 일 ÷ 흡수한 열 × 100 = \(DoitScience.fmt(w)) ÷ \(DoitScience.fmt(q1)) × 100 = \(DoitScience.fmt(value)) %")])
    }

    // MARK: 원자 · 이온

    /// 질량수 = 양성자 수 + 중성자 수
    static func nucleusCalc(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        let mass = groups(c, #"질량수가?는?([0-9]+)"#).flatMap { Int($0[1]) }
        let z = (groups(c, #"원자번호가?는?([0-9]+)"#) ?? groups(c, #"양성자수?가?는?([0-9]+)"#)).flatMap { Int($0[1]) }
        guard let mass, let z, mass >= z else { return nil }
        guard matches(c, #"중성자(의)?수(는|가|를)?.{0,8}(몇|\?|얼마|$)"#) || matches(c, #"중성자수는"#) else { return nil }
        guard count(c, #"질량수"#) == 1, !matches(c, #"(이온|[⁺⁻]|\+|전자수)"#) else { return nil }
        let n = mass - z
        let steps = [SolutionStep(hint: "원자의 구성", work: "질량수 = 양성자 수(= 원자 번호) + 중성자 수"),
                     SolutionStep(hint: "값 넣기", work: "중성자 수 = \(mass) − \(z) = \(n)")]
        return answerValue(p, value: Double(n), unit: "개", dimension: nil, concept: "원자의 구성 입자", steps: steps)
    }

    /// 이온의 전자 수 = 원자 번호 − 이온의 전하
    static func ionElectrons(_ p: Problem) -> Found? {
        let full = p.stem
        let c = dense(full)
        guard matches(c, #"전자(의)?수"#), !c.contains("중성자"), !c.contains("원자가전자") else { return nil }
        let sup: [Character: Character] = ["⁺": "+", "⁻": "-", "¹": "1", "²": "2", "³": "3", "⁴": "4"]
        let t = String(c.map { sup[$0] ?? $0 })
        // "Mg2+" · "O2-" · "Cl-" · "Na+"
        let pattern = #"(?<![A-Za-z])([A-Z][a-z]?)([1-4]?)([+\-])(?![0-9A-Za-z])"#
        guard count(t, pattern) == 1, let g = groups(t, pattern) else { return nil }
        guard let e = DoitScience.elementList.first(where: { $0.symbol == g[1] }) else { return nil }
        let charge = (Int(g[2]) ?? 1) * (g[3] == "+" ? 1 : -1)
        var z = e.number
        if let given = groups(c, #"원자번호는?가?([0-9]+)"#).flatMap({ Int($0[1]) }) {
            guard given == z else { return nil }
            z = given
        }
        let n = z - charge
        guard n >= 0 else { return nil }
        let steps = [SolutionStep(hint: "이온", work: "양이온은 전자를 잃고, 음이온은 전자를 얻어요. 전자 수 = 원자 번호 − 전하"),
                     SolutionStep(hint: "값 넣기", work: "\(e.name)(\(e.symbol)) 원자 번호 \(z), 전하 \(charge > 0 ? "+" : "−")\(abs(charge)) → 전자 \(n)개")]
        return answerValue(p, value: Double(n), unit: "개", dimension: nil, concept: "이온의 전자 수", steps: steps)
    }

    /// 묻는 원소 하나 (이름 · 원소 기호 · 원자 번호)
    static func namedElement(_ text: String) -> DoitScience.ElementInfo? {
        let c = dense(text)
        let list = DoitScience.elementList
        if let z = groups(c, #"원자번호가?는?([0-9]{1,3})"#).flatMap({ Int($0[1]) }) {
            let e = list.first { $0.number == z }
            // 이름도 쓰여 있으면 같은 원소여야
            if let e, list.contains(where: { o in o.number != e.number && ([o.name] + o.aliases).contains { c.contains($0 + "(") || c.contains($0 + "의") } }) { return nil }
            return e
        }
        let named = list.filter { e in ([e.name] + e.aliases).contains { name in name.count >= 2 && c.contains(name) } }
        if named.count == 1 { return named[0] }
        return nil
    }

    /// 원자가 전자 수 (1·2족 → 족 번호, 13~17족 → 족 번호 − 10, 18족 → 0)
    static func valenceElectrons(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard matches(c, #"원자가전자(의)?수"#), !c.contains("이온") else { return nil }
        guard let e = namedElement(p.stem), e.period <= 4 else { return nil }
        let v: Int
        switch e.group {
        case 1, 2: v = e.group
        case 13...17: v = e.group - 10
        case 18: v = 0
        default: return nil
        }
        let steps = [SolutionStep(hint: "원자가 전자", work: "가장 바깥 전자 껍질의 전자 중 화학 결합에 참여하는 전자예요. 1, 2족은 족 번호, 13~17족은 족 번호 − 10, 18족은 0개"),
                     SolutionStep(hint: e.name, work: "\(e.period)주기 \(e.group)족 → \(v)개")]
        return answerValue(p, value: Double(v), unit: "개", dimension: nil, concept: "원자가 전자", steps: steps)
    }

    // MARK: 용액 · 기체

    /// 몰 농도 = 용질의 몰수 ÷ 용액의 부피(L)
    static func molarityCalc(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard matches(c, #"몰농도(는|가|를)?.{0,6}(몇|\?|얼마)"#) || matches(c, #"몰농도는"#) else { return nil }
        let vol = qs(p, "volume"), moles = qs(p, "mole"), mass = qs(p, "mass")
        guard vol.count == 1, vol[0].si > 0 else { return nil }
        let liters = vol[0].si * 1000
        var n: Double
        var work: String
        if moles.count == 1, mass.isEmpty {
            n = moles[0].si; work = "몰수 \(DoitScience.fmt(n)) mol"
        } else if moles.isEmpty, mass.count == 1, let m = groups(c, #"(화학식량|분자량|몰질량)은?는?이?([0-9.]+)"#).flatMap({ Double($0[2]) }), m > 0 {
            n = mass[0].si * 1000 / m; work = "몰수 = \(DoitScience.fmt(mass[0].si * 1000)) g ÷ \(DoitScience.fmt(m)) g/mol = \(DoitScience.fmt(n)) mol"
        } else { return nil }
        let value = n / liters
        let steps = [SolutionStep(hint: "몰 농도", work: "몰 농도(M) = 용질의 양(mol) ÷ 용액의 부피(L)"), SolutionStep(hint: "몰수", work: work),
                     SolutionStep(hint: "값 넣기", work: "\(DoitScience.fmt(n)) mol ÷ \(DoitScience.fmt(liters)) L = \(DoitScience.fmt(value)) M")]
        return answerValue(p, value: value, unit: "M", dimension: "molarity", concept: "몰 농도", steps: steps)
    }

    /// pH가 1 작을수록 수소 이온 농도는 10배
    static func phRatio(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard c.contains("수소이온"), c.contains("농도"), matches(c, #"몇배"#), !matches(c, #"(섞|혼합)"#) else { return nil }
        let regex = try? NSRegularExpression(pattern: #"pH가?([0-9]+(?:\.[0-9]+)?)인"#)
        let ms = regex?.matches(in: c, range: NSRange(c.startIndex..., in: c)) ?? []
        guard ms.count == 2, let r1 = Range(ms[0].range(at: 1), in: c), let r2 = Range(ms[1].range(at: 1), in: c),
              let a = Double(c[r1]), let b = Double(c[r2]), (b - a).rounded() == b - a else { return nil }
        let value = pow(10, b - a)
        let steps = [SolutionStep(hint: "pH", work: "pH가 1 작아질 때마다 수소 이온 농도는 10배가 돼요."),
                     SolutionStep(hint: "계산", work: "pH \(DoitScience.fmt(a))와 pH \(DoitScience.fmt(b)): 10^(\(DoitScience.fmt(b)) − \(DoitScience.fmt(a))) = \(DoitScience.fmt(value))배")]
        return answerValue(p, value: value, unit: "배", dimension: nil, concept: "pH와 수소 이온 농도", steps: steps)
    }

    /// 보일 법칙 (온도 일정: PV 일정) · 샤를 법칙 (압력 일정: V ∝ 절대 온도)
    static func gasLaw(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"부피는?.{0,8}(몇|\?|얼마|되)"#) else { return nil }
        let vol = qs(p, "volume")
        guard vol.count == 1 else { return nil }
        if matches(c, #"온도가?일정"#), !matches(c, #"압력이?일정"#) {
            let pr = qs(p, "pressure")
            guard pr.count == 2, pr[1].si > 0, qs(p, "temperature").isEmpty else { return nil }
            let value = pr[0].si * vol[0].si / pr[1].si
            let shown = value / (vol[0].si / vol[0].raw)
            let steps = [SolutionStep(hint: "보일 법칙", work: "온도가 일정하면 압력 × 부피가 일정해요: P₁V₁ = P₂V₂"),
                         SolutionStep(hint: "값 넣기", work: "\(DoitScience.fmt(pr[0].raw)) × \(DoitScience.fmt(vol[0].raw)) = \(DoitScience.fmt(pr[1].raw)) × V₂ → V₂ = \(DoitScience.fmt(shown)) \(vol[0].unit)")]
            return answerValue(p, value: shown, unit: vol[0].unit, dimension: "volume", concept: "보일 법칙", steps: steps)
        }
        if matches(c, #"압력이?일정"#), !matches(c, #"온도가?일정"#) {
            let temps = qs(p, "temperature")
            guard temps.count == 2, qs(p, "pressure").count <= 1 else { return nil }
            let t1 = temps[0].si + 273, t2 = temps[1].si + 273
            guard t1 > 0, t2 > 0 else { return nil }
            let shown = vol[0].raw * t2 / t1
            let steps = [SolutionStep(hint: "샤를 법칙", work: "압력이 일정하면 기체의 부피는 절대 온도(℃ + 273)에 비례해요: V₁/T₁ = V₂/T₂"),
                         SolutionStep(hint: "값 넣기", work: "\(DoitScience.fmt(vol[0].raw)) × \(DoitScience.fmt(t2)) ÷ \(DoitScience.fmt(t1)) = \(DoitScience.fmt(shown)) \(vol[0].unit)")]
            return answerValue(p, value: shown, unit: vol[0].unit, dimension: "volume", concept: "샤를 법칙", steps: steps)
        }
        return nil
    }

    /// 일정 성분비: "A와 B의 질량비는 4 : 1" + A의 질량 → B의 질량
    static func massRatio(_ p: Problem) -> Found? {
        let s = p.stem
        guard let g = groups(s, #"([가-힣]+)(?:과|와)\s*([가-힣]+)의\s*질량\s*비는?\s*([0-9]+)\s*:\s*([0-9]+)"#),
              let ra = Double(g[3]), let rb = Double(g[4]), ra > 0, rb > 0 else { return nil }
        let a = g[1], b = g[2]
        let masses = qs(p, "mass")
        guard masses.count == 1 else { return nil }
        let c = dense(s)
        let givenA = matches(c, NSRegularExpression.escapedPattern(for: a) + #"[0-9.]+(g|kg)"#)
        let givenB = matches(c, NSRegularExpression.escapedPattern(for: b) + #"[0-9.]+(g|kg)"#)
        guard givenA != givenB else { return nil }
        let asked = givenA ? b : a
        guard matches(c, NSRegularExpression.escapedPattern(for: asked) + #"의질량"#) else { return nil }
        let m = masses[0].si * 1000
        let value = givenA ? m * rb / ra : m * ra / rb
        let steps = [SolutionStep(hint: "일정 성분비 법칙", work: "\(a) : \(b) = \(DoitScience.fmt(ra)) : \(DoitScience.fmt(rb))로 반응해요."),
                     SolutionStep(hint: "비례식", work: givenA ? "\(DoitScience.fmt(ra)) : \(DoitScience.fmt(rb)) = \(DoitScience.fmt(m)) : x → x = \(DoitScience.fmt(value)) g"
                                                            : "\(DoitScience.fmt(ra)) : \(DoitScience.fmt(rb)) = x : \(DoitScience.fmt(m)) → x = \(DoitScience.fmt(value)) g")]
        return answerValue(p, value: value, unit: "g", dimension: "mass", concept: "일정 성분비 법칙", steps: steps)
    }

    /// 용해도 S(물 100 g에 녹는 최대 g) → 물 W g에 녹는 최대 양 = S × W ÷ 100
    static func solubilityCalc(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard let s = groups(c, #"용해도가?는?([0-9.]+)(인|이고|일때)"#).flatMap({ Double($0[1]) }),
              let w = groups(c, #"물([0-9.]+)g에"#).flatMap({ Double($0[1]) }), matches(c, #"(최대|몇g까지)"#) else { return nil }
        guard count(c, #"물[0-9.]+g"#) == 1, !matches(c, #"(냉각|식히|석출|가열)"#) else { return nil }
        let value = s * w / 100
        return answerValue(p, value: value, unit: "g", dimension: "mass", concept: "용해도",
                           steps: [SolutionStep(hint: "용해도", work: "용해도는 물 100 g에 최대로 녹는 용질의 g 수예요."),
                                   SolutionStep(hint: "비례식", work: "100 : \(DoitScience.fmt(s)) = \(DoitScience.fmt(w)) : x → x = \(DoitScience.fmt(value)) g")])
    }

    // MARK: 유전

    /// 유전자형 글자 ("Rr", "RrYy") → 유전자 쌍들
    static func genePairs(_ token: String) -> [(Character, Character)]? {
        let chars = Array(token)
        guard chars.count == 2 || chars.count == 4, chars.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        var out: [(Character, Character)] = []
        var i = 0
        while i < chars.count {
            let a = chars[i], b = chars[i + 1]
            guard a.lowercased() == b.lowercased(), !(a.isLowercase && b.isUppercase) else { return nil }
            out.append((a, b)); i += 2
        }
        if out.count == 2, out[0].0.lowercased() == out[1].0.lowercased() { return nil }
        return out
    }

    /// 자손의 유전자형 분포 (유전자 쌍마다 독립)
    static func cross(_ a: [(Character, Character)], _ b: [(Character, Character)]) -> [String: Int]? {
        guard a.count == b.count else { return nil }
        var dist: [String: Int] = ["": 1]
        for (x, y) in zip(a, b) {
            guard x.0.lowercased() == y.0.lowercased() else { return nil }
            var next: [String: Int] = [:]
            for (prefix, n) in dist {
                for g1 in [x.0, x.1] { for g2 in [y.0, y.1] {
                    let pair = [g1, g2].sorted { ($0.isUppercase ? 0 : 1) < ($1.isUppercase ? 0 : 1) }
                    next[prefix + String(pair), default: 0] += n
                } }
            }
            dist = next
        }
        return dist
    }

    static func geneticsCalc(_ p: Problem) -> Found? {
        let s = p.stem
        let c = dense(s)
        guard matches(c, #"(교배|자가수분|자가교배)"#), !c.contains("혈액형"), !matches(c, #"(X염색체|반성|색맹|연관|중간유전|불완전우성|복대립)"#) else { return nil }
        // 교배 낱말 앞: 어버이, 뒤: 묻는 것
        guard let cut = s.range(of: #"(끼리|자가\s*수분|자가\s*교배|교배)"#, options: .regularExpression) else { return nil }
        let before = String(s[..<cut.lowerBound]), after = String(s[cut.lowerBound...])
        func tokens(_ t: String) -> [String] {
            t.matches(of: #/(?<![A-Za-z])[A-Za-z]{2,4}(?![A-Za-z])/#).map { String($0.output) }.filter { genePairs($0) != nil }
        }
        let parents = tokens(before)
        let selfCross = matches(c, #"(끼리|자가수분|자가교배)"#)
        let pa: [(Character, Character)], pb: [(Character, Character)]
        if selfCross {
            guard Set(parents).count == 1, let g = genePairs(parents[0]) else { return nil }
            pa = g; pb = g
        } else {
            guard parents.count == 2, let g1 = genePairs(parents[0]), let g2 = genePairs(parents[1]) else { return nil }
            pa = g1; pb = g2
        }
        guard let dist = cross(pa, pb) else { return nil }
        let total = dist.values.reduce(0, +)
        let parentText = selfCross ? "\(parents[0]) × \(parents[0])" : "\(parents[0]) × \(parents[1])"
        let rule = SolutionStep(hint: "교배", work: "\(parentText): 유전자 쌍마다 생식세포가 반씩 만들어져 무작위로 수정돼요.")
        let distText = dist.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        let table = SolutionStep(hint: "자손의 유전자형", work: distText + " (모두 \(total))")
        func phenotype(_ g: String) -> String {
            let chars = Array(g)
            return stride(from: 0, to: chars.count, by: 2).map { i in chars[i].isUppercase || chars[i + 1].isUppercase ? "우성" : "열성" }.joined(separator: "·")
        }
        let afterTokens = tokens(after)
        let ac = dense(after)
        // 표현형 분리비
        if matches(ac, #"표현형.{0,4}(분리)?비"#) {
            var ph: [String: Int] = [:]
            for (g, n) in dist { ph[phenotype(g), default: 0] += n }
            let ordered: [Int]
            if pa.count == 1, matches(ac, #"우성:열성"#) { ordered = [ph["우성"] ?? 0, ph["열성"] ?? 0] }
            else { ordered = ph.values.sorted(by: >) }
            return answerRatio(p, ordered, ordered: pa.count == 1 && matches(ac, #"우성:열성"#), concept: "멘델의 유전", steps: [rule, table])
        }
        // 유전자형 분리비
        if matches(ac, #"유전자형.{0,4}(분리)?비"#), pa.count == 1 {
            return answerRatio(p, dist.sorted { $0.key < $1.key }.map(\.value), ordered: false, concept: "멘델의 유전", steps: [rule, table])
        }
        // 특정 유전자형 · 우성/열성 형질의 비율이나 개수
        var hit: Int?
        var label = ""
        if afterTokens.count == 1, let target = genePairs(afterTokens[0]), target.count == pa.count, matches(ac, #"유전자형이?"# + afterTokens[0]) {
            let key = target.map { String([$0.0, $0.1]) }.joined()
            hit = dist[key] ?? 0; label = "유전자형 \(afterTokens[0])"
        } else if afterTokens.isEmpty, pa.count == 1, matches(ac, #"(우성|열성)형질을?(나타내|가진|보이)"#) {
            let dominant = ac.contains("우성형질")
            hit = dist.filter { (phenotype($0.key) == "우성") == dominant }.values.reduce(0, +); label = dominant ? "우성 형질" : "열성 형질"
        }
        // 잡종 1대처럼 자손 유전자형이 하나뿐일 때 "유전자형은?"
        if hit == nil, afterTokens.isEmpty, dist.count == 1, matches(ac, #"유전자형은"#), let only = dist.keys.first {
            var all = [rule, table]
            all.append(SolutionStep(hint: "답", work: only))
            if p.isChoice {
                guard let index = p.choices.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == only }),
                      p.choices.filter({ $0.trimmingCharacters(in: .whitespaces) == only }).count == 1 else { return nil }
                return pick(p, index: index, concept: "멘델의 유전", steps: all)
            }
            return Found(answer: only, concept: "멘델의 유전", steps: all)
        }
        guard let hit else { return nil }
        if matches(ac, #"(비율|확률)(은|는|이|을)?"#), !matches(ac, #"몇개"#) {
            return answerFraction(p, numerator: hit, denominator: total, concept: "멘델의 유전", steps: [rule, table, SolutionStep(hint: label, work: "\(hit)/\(total)")])
        }
        if matches(ac, #"몇개|몇포기|몇마리"#), let n = groups(ac, #"([0-9]+)(개|포기|마리)중"#).flatMap({ Int($0[1]) }) {
            guard (n * hit) % total == 0 else { return nil }
            let value = n * hit / total
            return answerValue(p, value: Double(value), unit: "개", dimension: nil, concept: "멘델의 유전",
                               steps: [rule, table, SolutionStep(hint: label, work: "\(n) × \(hit)/\(total) = \(value)")])
        }
        return nil
    }

    /// ABO식 혈액형: 부모 유전자형 → 자녀 혈액형의 확률
    static func bloodTypeCalc(_ p: Problem) -> Found? {
        let s = p.stem
        let c = dense(s)
        guard c.contains("혈액형"), c.contains("유전자형") else { return nil }
        let parents = c.matches(of: #/(?<![A-Z])([ABO]{2})인/#).map { String($0.output.1) }
        guard parents.count == 2 else { return nil }
        func alleles(_ g: String) -> [Character] { Array(g) }
        var dist: [String: Int] = [:]
        for x in alleles(parents[0]) { for y in alleles(parents[1]) {
            let set = Set([x, y])
            let type = set == ["A", "B"] ? "AB" : set.contains("A") ? "A" : set.contains("B") ? "B" : "O"
            dist[type, default: 0] += 1
        } }
        let steps = [SolutionStep(hint: "ABO식 혈액형", work: "A, B는 O에 대해 우성이고 A와 B는 공동 우성이에요."),
                     SolutionStep(hint: "자녀", work: "\(parents[0]) × \(parents[1]) → " + dist.sorted { $0.key < $1.key }.map { "\($0.key)형 \($0.value)/4" }.joined(separator: ", "))]
        // "태어날 수 없는 혈액형"
        if matches(c, #"(태어날수없|나올수없|나타날수없)"#), p.isChoice {
            let types = p.choices.map { choice -> String? in
                guard let m = dense(choice).firstMatch(of: #/^(AB|A|B|O)형?$/#) else { return nil }
                return String(m.output.1)
            }
            guard types.allSatisfy({ $0 != nil }) else { return nil }
            let hits = types.indices.filter { dist[types[$0]!] == nil }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "ABO식 혈액형의 유전", steps: steps)
        }
        guard let target = c.firstMatch(of: #/(AB|A|B|O)형인?자녀가?(태어날)?(확률|비율)/#).map({ String($0.output.1) }) else { return nil }
        return answerFraction(p, numerator: dist[target] ?? 0, denominator: 4, concept: "ABO식 혈액형의 유전", steps: steps)
    }

    /// DNA 이중 가닥: A = T, G = C, A + G = 50 %
    static func dnaBase(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard c.contains("DNA"), !matches(c, #"(RNA|단일가닥|한가닥|유라실)"#), c.contains("%") else { return nil }
        let names: [(String, Character)] = [("아데닌", "A"), ("티민", "T"), ("구아닌", "G"), ("사이토신", "C")]
        func base(_ s: String) -> Character? {
            if let n = names.first(where: { s.hasPrefix($0.0) }) { return n.1 }
            return s.first.flatMap { "ATGC".contains($0) ? $0 : nil }
        }
        guard let g = groups(c, #"(아데닌|티민|구아닌|사이토신|[ATGC])(\([ATGC]\))?의?비율이?([0-9.]+)%"#), let given = base(g[1]), let v = Double(g[3]),
              count(c, #"[0-9.]+%"#) == 1 else { return nil }
        let rest = c.components(separatedBy: g[0]).last ?? ""
        guard let a = groups(rest, #"(아데닌|티민|구아닌|사이토신|[ATGC])(\([ATGC]\))?의?비율은"#), let asked = base(a[1]), asked != given else { return nil }
        let partner: [Character: Character] = ["A": "T", "T": "A", "G": "C", "C": "G"]
        let value = partner[given] == asked ? v : 50 - v
        guard value >= 0 else { return nil }
        let steps = [SolutionStep(hint: "상보적 결합", work: "DNA 이중 나선에서 A는 T와, G는 C와 결합해요: A = T, G = C, A + G = 50 %"),
                     SolutionStep(hint: "계산", work: "\(given) = \(DoitScience.fmt(v)) % → \(asked) = \(DoitScience.fmt(value)) %")]
        return answerValue(p, value: value, unit: "%", dimension: nil, concept: "DNA 염기 조성", steps: steps)
    }

    // MARK: 지구과학 계산

    /// 반감기: 남은 양이 (1/2)ⁿ이면 걸린 시간 = n × 반감기 (n이 정수일 때만)
    static func halfLife(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard let g = groups(c, #"반감기가?는?([0-9.]+)(억|만|천)?년"#), let t = Double(g[1]) else { return nil }
        let unit = g[2] + "년"
        var fraction: Double?
        if let f = groups(c, #"처음.{0,6}([0-9]+)/([0-9]+)"#), let a = Double(f[1]), let b = Double(f[2]), b > 0 { fraction = a / b }
        else if let f = groups(c, #"처음.{0,8}([0-9.]+)%"#), let a = Double(f[1]) { fraction = a / 100 }
        else if let f = groups(c, #"([0-9.]+)%가?(남|로줄|만남)"#), let a = Double(f[1]), c.contains("처음") { fraction = a / 100 }
        guard let fr = fraction, fr > 0, fr < 1, matches(c, #"(걸리는시간|시간은|몇년|지나야)"#) else { return nil }
        let n = log2(1 / fr)
        guard abs(n - n.rounded()) < 1e-9, n >= 1, n <= 10 else { return nil }
        let value = n.rounded() * t
        let shown = "\(DoitScience.fmt(value))\(g[2].isEmpty ? "" : g[2]) 년".replacingOccurrences(of: "  ", with: " ")
        let steps = [SolutionStep(hint: "반감기", work: "반감기마다 방사성 원소의 양이 절반이 돼요."),
                     SolutionStep(hint: "계산", work: "처음의 \(DoitScience.fmt(fr * 100)) % = (1/2)^\(Int(n.rounded())) → \(Int(n.rounded())) × \(DoitScience.fmt(t))\(unit) = \(DoitScience.fmt(value))\(unit)")]
        if p.isChoice {
            let hits = p.choices.indices.filter { i in
                let d = dense(p.choices[i])
                guard let m = groups(d, #"^([0-9.]+)(억|만|천)?년$"#), let v = Double(m[1]) else { return false }
                return m[2] == g[2] && abs(v - value) < 1e-9
            }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "반감기", steps: steps)
        }
        _ = shown
        let answer = "\(DoitScience.fmt(value))\(unit)"
        return Found(answer: answer, concept: "반감기", steps: steps + [SolutionStep(hint: "답", work: answer)])
    }

    /// 연주 시차 p″ → 거리 d = 1/p (pc)
    static func parallaxCalc(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard let g = groups(c, #"연주시차가?는?([0-9.]+)(″|"|''|초)"#), let v = Double(g[1]), v > 0, matches(c, #"거리"#), !c.contains("광년") else { return nil }
        let d = 1 / v
        let steps = [SolutionStep(hint: "연주 시차", work: "별까지의 거리(pc) = 1 ÷ 연주 시차(″)"), SolutionStep(hint: "계산", work: "1 ÷ \(DoitScience.fmt(v)) = \(DoitScience.fmt(d)) pc")]
        return answerValue(p, value: d, unit: "pc", dimension: nil, concept: "연주 시차와 거리", steps: steps)
    }

    /// 등급 차 5 → 밝기 100배
    static func magnitudeCalc(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard let g = groups(c, #"(-?[0-9]+)등급인?별은?(-?[0-9]+)등급인?별보다.{0,4}몇배.{0,4}밝"#), let a = Int(g[1]), let b = Int(g[2]), b > a, (b - a) % 5 == 0 else { return nil }
        let value = pow(100, Double(b - a) / 5)
        let steps = [SolutionStep(hint: "별의 등급", work: "등급이 1 작을수록 약 2.5배 밝고, 5등급 차이는 정확히 100배예요."),
                     SolutionStep(hint: "계산", work: "\(b - a)등급 차 → 100^(\(b - a)/5) = \(DoitScience.fmt(value))배")]
        return answerValue(p, value: value, unit: "배", dimension: nil, concept: "별의 밝기와 등급", steps: steps)
    }

    /// 상대 습도 = 현재 수증기량 ÷ 포화 수증기량 × 100
    static func humidityCalc(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard c.contains("상대습도"), let now = groups(c, #"(현재|실제)(공기의)?수증기량[은는이가]?([0-9.]+)"#).flatMap({ Double($0[3]) }),
              let sat = groups(c, #"포화수증기량[은는이가]?([0-9.]+)"#).flatMap({ Double($0[1]) }), sat > 0, now <= sat else { return nil }
        guard count(c, #"포화수증기량[은는이가]?[0-9]"#) == 1 else { return nil }
        let value = now / sat * 100
        let steps = [SolutionStep(hint: "상대 습도", work: "상대 습도(%) = 현재 수증기량 ÷ 그 기온의 포화 수증기량 × 100"),
                     SolutionStep(hint: "계산", work: "\(DoitScience.fmt(now)) ÷ \(DoitScience.fmt(sat)) × 100 = \(DoitScience.fmt(value)) %")]
        return answerValue(p, value: value, unit: "%", dimension: nil, concept: "상대 습도", steps: steps)
    }

    /// 생태 피라미드의 에너지 효율 = 이 단계 에너지 ÷ 바로 아래 단계 에너지 × 100
    static func ecoEfficiency(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard c.contains("에너지효율") else { return nil }
        let levels = ["생산자", "1차소비자", "2차소비자", "3차소비자"]
        var energy: [Int: Double] = [:]
        for (i, name) in levels.enumerated() {
            if let g = groups(c, NSRegularExpression.escapedPattern(for: name) + #"의?(에너지|에너지양)[은는이가]?([0-9.]+)"#), let v = Double(g[2]) { energy[i] = v }
        }
        guard let asked = groups(c, #"(1차소비자|2차소비자|3차소비자)의?에너지효율"#).flatMap({ levels.firstIndex(of: $0[1]) }),
              let upper = energy[asked], let lower = energy[asked - 1], lower > 0 else { return nil }
        let value = upper / lower * 100
        let steps = [SolutionStep(hint: "에너지 효율", work: "에너지 효율(%) = 그 단계의 에너지양 ÷ 전 단계의 에너지양 × 100"),
                     SolutionStep(hint: "계산", work: "\(DoitScience.fmt(upper)) ÷ \(DoitScience.fmt(lower)) × 100 = \(DoitScience.fmt(value)) %")]
        return answerValue(p, value: value, unit: "%", dimension: nil, concept: "생태계의 에너지 효율", steps: steps)
    }

    /// 체세포 2n → 생식세포 n
    static func chromosomeHalf(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard let g = groups(c, #"2n=([0-9]+)"#), let v = Int(g[1]), v % 2 == 0, matches(c, #"생식세포(의)?염색체수"#), !matches(c, #"(체세포분열후|딸세포의염색체수는모세포)"#) else { return nil }
        let value = v / 2
        let steps = [SolutionStep(hint: "감수 분열", work: "생식세포는 감수 분열로 만들어져 염색체 수가 체세포의 절반(n)이에요."),
                     SolutionStep(hint: "계산", work: "2n = \(v) → n = \(value)")]
        return answerValue(p, value: Double(value), unit: "개", dimension: nil, concept: "염색체 수", steps: steps)
    }

    // MARK: 사회 계산

    static func socialCalc(_ p: Problem) -> Found? {
        if p.isChoice, !p.choices.allSatisfy({ isNumberLike($0) || $0.contains(":") }) { return nil }
        let solvers: [(Problem) -> Found?] = [laborRates, priceIndexRate, growthRate, elasticityCalc, interestCalc, mapScale, dependencyRatio]
        for solver in solvers { if let found = solver(p) { return found } }
        return nil
    }

    /// "200만 명" → 2,000,000
    private static func people(_ c: String, _ name: String) -> Double? {
        guard let g = groups(c, NSRegularExpression.escapedPattern(for: name) + #"(수)?[은는이가]?([0-9.]+)(억|만|천)?명"#), let v = Double(g[2]) else { return nil }
        guard count(c, NSRegularExpression.escapedPattern(for: name) + #"(수)?[은는이가]?[0-9]"#) == 1 else { return nil }
        let unit = ["억": 1e8, "만": 1e4, "천": 1e3][g[3]] ?? 1
        return v * unit
    }

    /// 실업률 · 고용률 · 경제 활동 참가율
    static func laborRates(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        let active = people(c, "경제활동인구"), unemployed = people(c, "실업자"), employed = people(c, "취업자"), adult = people(c, "15세이상인구")
        let rule: (String) -> SolutionStep = { SolutionStep(hint: "공식", work: $0) }
        if matches(c, #"실업률(은|는|을)?"#), !matches(c, #"(고용률|참가율)(은|는)"#) {
            var labor = active
            if labor == nil, let e = employed, let u = unemployed { labor = e + u }
            guard let l = labor, let u = unemployed, l > 0, u <= l else { return nil }
            let value = u / l * 100
            return answerValue(p, value: value, unit: "%", dimension: nil, concept: "실업률",
                               steps: [rule("실업률(%) = 실업자 ÷ 경제 활동 인구 × 100"), SolutionStep(hint: "계산", work: "\(DoitScience.fmt(u)) ÷ \(DoitScience.fmt(l)) × 100 = \(DoitScience.fmt(value)) %")])
        }
        if matches(c, #"고용률(은|는|을)?"#), !matches(c, #"실업률(은|는)"#) {
            guard let e = employed, let a = adult, a > 0, e <= a else { return nil }
            let value = e / a * 100
            return answerValue(p, value: value, unit: "%", dimension: nil, concept: "고용률",
                               steps: [rule("고용률(%) = 취업자 ÷ 15세 이상 인구 × 100"), SolutionStep(hint: "계산", work: "\(DoitScience.fmt(e)) ÷ \(DoitScience.fmt(a)) × 100 = \(DoitScience.fmt(value)) %")])
        }
        if matches(c, #"경제활동참가율(은|는|을)?"#) {
            guard let l = active, let a = adult, a > 0, l <= a else { return nil }
            let value = l / a * 100
            return answerValue(p, value: value, unit: "%", dimension: nil, concept: "경제 활동 참가율",
                               steps: [rule("경제 활동 참가율(%) = 경제 활동 인구 ÷ 15세 이상 인구 × 100"), SolutionStep(hint: "계산", work: "\(DoitScience.fmt(l)) ÷ \(DoitScience.fmt(a)) × 100 = \(DoitScience.fmt(value)) %")])
        }
        return nil
    }

    /// 물가 상승률 = (올해 물가 지수 − 작년) ÷ 작년 × 100
    static func priceIndexRate(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard matches(c, #"물가상승률(은|는|을)?"#), let g = groups(c, #"물가지수가?.{0,10}?([0-9.]+)에서.{0,10}?([0-9.]+)(로|으로)"#),
              let a = Double(g[1]), let b = Double(g[2]), a > 0 else { return nil }
        let value = (b - a) / a * 100
        return answerValue(p, value: value, unit: "%", dimension: nil, concept: "물가 상승률",
                           steps: [SolutionStep(hint: "공식", work: "물가 상승률(%) = (올해 물가 지수 − 작년 물가 지수) ÷ 작년 물가 지수 × 100"),
                                   SolutionStep(hint: "계산", work: "(\(DoitScience.fmt(b)) − \(DoitScience.fmt(a))) ÷ \(DoitScience.fmt(a)) × 100 = \(DoitScience.fmt(value)) %")])
    }

    /// 경제 성장률 = (올해 실질 GDP − 작년 실질 GDP) ÷ 작년 실질 GDP × 100
    static func growthRate(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard matches(c, #"경제성장률(은|는|을)?"#), !c.contains("명목") || c.contains("실질") else { return nil }
        guard let a = groups(c, #"(작년|전년|지난해)(의)?(실질)?GDP가?는?([0-9.]+)(조|억|만)?원"#),
              let b = groups(c, #"(올해|금년)(의)?(실질)?GDP가?는?([0-9.]+)(조|억|만)?원"#), a[5] == b[5],
              let x = Double(a[4]), let y = Double(b[4]), x > 0 else { return nil }
        guard !c.contains("명목") else { return nil }
        let value = (y - x) / x * 100
        return answerValue(p, value: value, unit: "%", dimension: nil, concept: "경제 성장률",
                           steps: [SolutionStep(hint: "공식", work: "경제 성장률(%) = (올해 실질 GDP − 작년 실질 GDP) ÷ 작년 실질 GDP × 100"),
                                   SolutionStep(hint: "계산", work: "(\(DoitScience.fmt(y)) − \(DoitScience.fmt(x))) ÷ \(DoitScience.fmt(x)) × 100 = \(DoitScience.fmt(value)) %")])
    }

    /// 수요의 가격 탄력성 = 수요량 변화율 ÷ 가격 변화율
    static func elasticityCalc(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard matches(c, #"(수요|공급)의?가격탄력성(은|는|을)?"#), let price = groups(c, #"가격이?([0-9.]+)%(상승|하락|오르|내리|인상|인하)"#),
              let q = groups(c, #"(수요량|공급량)이?([0-9.]+)%(감소|증가|줄|늘)"#), let pv = Double(price[1]), let qv = Double(q[2]), pv > 0 else { return nil }
        guard count(c, #"[0-9.]+%"#) == 2 else { return nil }
        let value = qv / pv
        return answerValue(p, value: value, unit: "", dimension: nil, concept: "가격 탄력성",
                           steps: [SolutionStep(hint: "공식", work: "가격 탄력성 = 수요량(공급량) 변화율 ÷ 가격 변화율"),
                                   SolutionStep(hint: "계산", work: "\(DoitScience.fmt(qv)) % ÷ \(DoitScience.fmt(pv)) % = \(DoitScience.fmt(value))")])
    }

    /// 단리 · 복리: 원금 P, 연 이자율 r, n년
    static func interestCalc(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        let simple = c.contains("단리"), compound = c.contains("복리")
        guard simple != compound, let g = groups(c, #"원금([0-9.]+)(만|억|천)?원"#), let principal = Double(g[1]),
              let r = groups(c, #"(연)?이자율[은이]?([0-9.]+)%"#).flatMap({ Double($0[2]) }), let n = groups(c, #"([0-9]+)년"#).flatMap({ Int($0[1]) }), n >= 1, n <= 10 else { return nil }
        let unit = g[2] + "원"
        let total = compound ? principal * pow(1 + r / 100, Double(n)) : principal * (1 + r / 100 * Double(n))
        let askInterest = matches(c, #"이자는"#) && !matches(c, #"원리금"#)
        guard askInterest || matches(c, #"(원리금|받는돈|찾는돈|모두얼마)"#) else { return nil }
        let value = askInterest ? total - principal : total
        let rounded = (value * 1000).rounded() / 1000
        let steps = [SolutionStep(hint: compound ? "복리" : "단리", work: compound ? "원리금 = 원금 × (1 + 이자율)^기간" : "원리금 = 원금 × (1 + 이자율 × 기간)"),
                     SolutionStep(hint: "계산", work: "\(DoitScience.fmt(principal))\(unit) → 원리금 \(DoitScience.fmt((total * 1000).rounded() / 1000))\(unit)" + (askInterest ? ", 이자 \(DoitScience.fmt(rounded))\(unit)" : ""))]
        if p.isChoice {
            let hits = p.choices.indices.filter { i in
                guard let m = groups(dense(p.choices[i]), #"^([0-9.]+)(만|억|천)?원$"#), let v = Double(m[1]) else { return false }
                return m[2] == g[2] && abs(v - rounded) < 1e-6
            }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: compound ? "복리" : "단리", steps: steps)
        }
        let answer = "\(DoitScience.fmt(rounded))\(g[2]) 원".replacingOccurrences(of: " 원", with: g[2].isEmpty ? " 원" : " 원")
        return Found(answer: answer, concept: compound ? "복리" : "단리", steps: steps + [SolutionStep(hint: "답", work: answer)])
    }

    /// 축척 1 : N 지도 → 실제 거리, 또는 실제 거리와 지도 거리 → 축척
    static func mapScale(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard matches(c, #"(축척|지도|지형도)"#) else { return nil }
        let lengths = DoitScience.quantities(in: p.stem.replacingOccurrences(of: ",", with: "")).filter { $0.dimension == "length" }
        if let g = groups(c, #"1:([0-9]+)"#), let n = Double(g[1]), n > 0 {
            guard matches(c, #"실제거리"#), lengths.count == 1, count(c, #"1:[0-9]"#) == 1 else { return nil }
            let real = lengths[0].si * n
            let steps = [SolutionStep(hint: "축척", work: "실제 거리 = 지도상 거리 × 축척의 분모"),
                         SolutionStep(hint: "계산", work: "\(DoitScience.fmt(lengths[0].raw)) \(lengths[0].unit) × \(DoitScience.fmt(n)) = \(DoitScience.fmt(real)) m")]
            // 묻는 단위로
            let unit = matches(c, #"몇km"#) ? "km" : matches(c, #"몇m"#) ? "m" : p.isChoice ? "m" : nil
            guard let unit else { return nil }
            let value = unit == "km" ? real / 1000 : real
            return answerValue(p, value: value, unit: unit, dimension: "length", concept: "축척과 실제 거리", steps: steps)
        }
        // 축척 구하기
        guard matches(c, #"축척(은|는)"#), lengths.count == 2, p.isChoice else { return nil }
        let realQ = lengths.max { $0.si < $1.si }!, mapQ = lengths.min { $0.si < $1.si }!
        guard mapQ.si > 0 else { return nil }
        let n = realQ.si / mapQ.si
        let hits = p.choices.indices.filter { i in
            guard let m = groups(dense(p.choices[i]), #"^1:([0-9]+)$"#), let v = Double(m[1]) else { return false }
            return abs(v - n) < 1e-6
        }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: "축척", steps: [SolutionStep(hint: "축척", work: "축척의 분모 = 실제 거리 ÷ 지도상 거리 = \(DoitScience.fmt(n))")])
    }

    /// 부양비 · 노령화 지수
    static func dependencyRatio(_ p: Problem) -> Found? {
        let c = dense(p.stem)
        guard let young = people(c, "유소년인구"), let old = people(c, "노년인구") else { return nil }
        let work = people(c, "생산가능인구") ?? people(c, "청장년인구")
        var value: Double, name: String, formula: String
        if matches(c, #"총부양비"#), let w = work, w > 0 { value = (young + old) / w * 100; name = "총부양비"; formula = "(유소년 인구 + 노년 인구) ÷ 생산 가능 인구 × 100" }
        else if matches(c, #"유소년부양비"#), let w = work, w > 0 { value = young / w * 100; name = "유소년 부양비"; formula = "유소년 인구 ÷ 생산 가능 인구 × 100" }
        else if matches(c, #"노년부양비"#), let w = work, w > 0 { value = old / w * 100; name = "노년 부양비"; formula = "노년 인구 ÷ 생산 가능 인구 × 100" }
        else if matches(c, #"노령화지수"#), young > 0 { value = old / young * 100; name = "노령화 지수"; formula = "노년 인구 ÷ 유소년 인구 × 100" }
        else { return nil }
        let rounded = (value * 10).rounded() / 10
        return answerValue(p, value: rounded, unit: "", dimension: nil, concept: name,
                           steps: [SolutionStep(hint: name, work: formula), SolutionStep(hint: "계산", work: "\(DoitScience.fmt(rounded))")])
    }
}
