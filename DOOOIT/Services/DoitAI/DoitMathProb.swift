import Foundation

/// 모티 AI 수학 풀이: 확률과 통계 (외부 AI 없이 직접 계산)
/// - 확률의 덧셈정리 · 조건부확률 · 독립 (P(A), P(B), P(A ∩ B), P(A ∪ B), P(A|B) 중 아는 것으로 모르는 것)
/// - 확률변수: E(X), V(X), σ(X), E(aX + b), V(aX + b), 확률분포표, 이항분포 B(n, p), 정규분포 N(m, σ²), 표본평균
/// - 중복순열 ₙΠᵣ, 중복조합 ₙHᵣ, 공을 상자에 넣기, 같은 글자가 있는 영어 단어 배열
/// - 주사위·동전을 여러 번 (독립시행), 주머니에서 꺼내기, 1부터 N까지 두 수 고르기, 일렬로 세울 때의 확률
/// 모두 하나씩 세거나 정확한 분수로 계산해요. 조건을 못 읽으면 nil
enum DoitMathProb {
    typealias Solved = MathSolver.Solved
    typealias Rat = DoitMathExact.Rat

    private static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }
    private static func match(_ t: String, _ p: String) -> [String]? { DoitMathExact.match(t, p) }
    private static func matches(_ t: String, _ p: String) -> [[String]] { DoitMathExact.matches(t, p) }
    private static func step(_ h: String, _ w: String) -> SolutionStep { SolutionStep(hint: h, work: w) }

    /// "0.3" → 3/10, "1/4" → 1/4, "-2" → −2
    static func ratio(_ s: String) -> Rat? {
        let t = s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "−", with: "-")
        let negative = t.hasPrefix("-")
        let body = negative ? String(t.dropFirst()) : t
        let parts = body.split(separator: "/").map(String.init)
        var r: Rat?
        if parts.count == 1 { r = Rat.parse(parts[0]) }
        else if parts.count == 2, let a = Rat.parse(parts[0]), let b = Rat.parse(parts[1]) { r = a / b }
        guard let v = r else { return nil }
        return negative ? -v : v
    }

    /// 확률을 보여 주는 모양: 문제가 소수로 주면 소수, 아니면 분수
    private static func text(_ r: Rat, decimal: Bool) -> String {
        if decimal, let d = r.decimalText { return d.replacingOccurrences(of: "−", with: "-") }
        return r.text
    }

    static func solve(_ t: String) -> Solved? {
        if let s = eventAlgebra(t) { return s }
        if let s = randomVariable(t) { return s }
        if let s = binomialDistribution(t) { return s }
        if let s = normalDistribution(t) { return s }
        if let s = sampleMean(t) { return s }
        if let s = repetition(t) { return s }
        if let s = wordArrangement(t) { return s }
        if let s = ballsBoxes(t) { return s }
        if let s = independentTrials(t) { return s }
        if let s = diceEnumeration(t) { return s }
        if let s = drawFromBag(t) { return s }
        if let s = pairFromRange(t) { return s }
        if let s = lineupProbability(t) { return s }
        return nil
    }

    // MARK: - 확률의 덧셈정리 · 조건부확률

    static func eventAlgebra(_ raw: String) -> Solved? {
        guard raw.contains("P(") || raw.contains("P (") else { return nil }
        let t = raw.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "ᶜ", with: "^c").replacingOccurrences(of: "∁", with: "")
            .replacingOccurrences(of: "｜", with: "|").replacingOccurrences(of: "∣", with: "|")
        // 확률변수 P(X = 1) 은 다른 풀이로
        if t.range(of: #"P\(\s*[XYZ]"#, options: .regularExpression) != nil { return nil }
        let names = ["A", "B", "A∩B", "A∪B", "A|B", "B|A", "A^c", "B^c", "A^c∩B^c", "A∩B^c", "B∩A^c", "A^c∪B^c"]
        var known: [String: Rat] = [:]
        var decimal = false
        for m in matches(t, #"P\(([A-Bᶜ^c∩∪|]+)\)=(-?[0-9]+(?:\.[0-9]+)?(?:/[0-9]+)?)"#) {
            var key = m[1]
            if key == "B∩A" { key = "A∩B" }
            if key == "B∪A" { key = "A∪B" }
            guard names.contains(key), let v = ratio(m[2]), v.n >= 0, v.n <= v.d else { return nil }
            if m[2].contains(".") { decimal = true }
            if let old = known[key], old != v { return nil }
            known[key] = v
        }
        guard !known.isEmpty else { return nil }
        // 물은 것: 맨 뒤의 "P(…)의 값"
        guard let ask = matches(t, #"P\(([A-Bᶜ^c∩∪|]+)\)(?:의값|값|은|는|을|를|\?)"#).last else { return nil }
        var target = ask[1]
        if target == "B∩A" { target = "A∩B" }
        if target == "B∪A" { target = "A∪B" }
        guard names.contains(target), known[target] == nil else { return nil }
        let independent = has(raw, ["서로 독립", "독립이고", "독립일 때", "독립이다"]) && !has(raw, ["독립이 아", "종속"])
        let exclusive = has(raw, ["서로 배반", "배반사건"])
        var steps: [SolutionStep] = []
        func set(_ k: String, _ v: Rat?, _ why: String) -> Bool {
            guard known[k] == nil, let v = v, v.n >= 0, v.n <= v.d else { return false }
            known[k] = v
            steps.append(step(why, "P(\(k.replacingOccurrences(of: "^c", with: "ᶜ"))) = \(text(v, decimal: decimal))"))
            return true
        }
        let one = Rat.one
        for _ in 0..<6 {
            var changed = false
            if exclusive, known["A∩B"] == nil { changed = set("A∩B", .zero, "서로 배반이면 A ∩ B = ∅") || changed }
            if let a = known["A"], known["A^c"] == nil { changed = set("A^c", one - a, "여사건: P(Aᶜ) = 1 − P(A)") || changed }
            if let a = known["A^c"], known["A"] == nil { changed = set("A", one - a, "P(A) = 1 − P(Aᶜ)") || changed }
            if let b = known["B"], known["B^c"] == nil { changed = set("B^c", one - b, "여사건: P(Bᶜ) = 1 − P(B)") || changed }
            if let b = known["B^c"], known["B"] == nil { changed = set("B", one - b, "P(B) = 1 − P(Bᶜ)") || changed }
            if independent, let a = known["A"], let b = known["B"], known["A∩B"] == nil { changed = set("A∩B", a * b, "서로 독립이면 P(A ∩ B) = P(A)P(B)") || changed }
            if let a = known["A"], let b = known["B"], let i = known["A∩B"], known["A∪B"] == nil { changed = set("A∪B", (a + b).flatMap { $0 - i }, "덧셈정리: P(A ∪ B) = P(A) + P(B) − P(A ∩ B)") || changed }
            if let a = known["A"], let b = known["B"], let u = known["A∪B"], known["A∩B"] == nil { changed = set("A∩B", (a + b).flatMap { $0 - u }, "덧셈정리에서 P(A ∩ B) = P(A) + P(B) − P(A ∪ B)") || changed }
            if let a = known["A"], let u = known["A∪B"], let i = known["A∩B"], known["B"] == nil { changed = set("B", (u + i).flatMap { $0 - a }, "덧셈정리에서 P(B) = P(A ∪ B) + P(A ∩ B) − P(A)") || changed }
            if let b = known["B"], let u = known["A∪B"], let i = known["A∩B"], known["A"] == nil { changed = set("A", (u + i).flatMap { $0 - b }, "덧셈정리에서 P(A) = P(A ∪ B) + P(A ∩ B) − P(B)") || changed }
            if let i = known["A∩B"], let b = known["B"], b.n > 0, known["A|B"] == nil { changed = set("A|B", i / b, "조건부확률: P(A|B) = P(A ∩ B)/P(B)") || changed }
            if let i = known["A∩B"], let a = known["A"], a.n > 0, known["B|A"] == nil { changed = set("B|A", i / a, "조건부확률: P(B|A) = P(A ∩ B)/P(A)") || changed }
            if let c = known["A|B"], let b = known["B"], known["A∩B"] == nil { changed = set("A∩B", c * b, "곱셈정리: P(A ∩ B) = P(B)P(A|B)") || changed }
            if let c = known["B|A"], let a = known["A"], known["A∩B"] == nil { changed = set("A∩B", c * a, "곱셈정리: P(A ∩ B) = P(A)P(B|A)") || changed }
            if let c = known["A|B"], let i = known["A∩B"], c.n > 0, known["B"] == nil { changed = set("B", i / c, "P(B) = P(A ∩ B)/P(A|B)") || changed }
            if let c = known["B|A"], let i = known["A∩B"], c.n > 0, known["A"] == nil { changed = set("A", i / c, "P(A) = P(A ∩ B)/P(B|A)") || changed }
            if let u = known["A∪B"], known["A^c∩B^c"] == nil { changed = set("A^c∩B^c", one - u, "드모르간: P(Aᶜ ∩ Bᶜ) = 1 − P(A ∪ B)") || changed }
            if let n = known["A^c∩B^c"], known["A∪B"] == nil { changed = set("A∪B", one - n, "P(A ∪ B) = 1 − P(Aᶜ ∩ Bᶜ)") || changed }
            if let i = known["A∩B"], known["A^c∪B^c"] == nil { changed = set("A^c∪B^c", one - i, "드모르간: P(Aᶜ ∪ Bᶜ) = 1 − P(A ∩ B)") || changed }
            if let a = known["A"], let i = known["A∩B"], known["A∩B^c"] == nil { changed = set("A∩B^c", a - i, "P(A ∩ Bᶜ) = P(A) − P(A ∩ B)") || changed }
            if let b = known["B"], let i = known["A∩B"], known["B∩A^c"] == nil { changed = set("B∩A^c", b - i, "P(Aᶜ ∩ B) = P(B) − P(A ∩ B)") || changed }
            if known[target] != nil || !changed { break }
        }
        guard let answer = known[target] else { return nil }
        // 독립·배반 조건과 맞지 않는 값이면 (문제를 잘못 읽었을 수 있어요) 풀지 않음
        if independent, let a = known["A"], let b = known["B"], let i = known["A∩B"], (a * b) != i { return nil }
        return Solved(kind: .counting, topic: "확률의 계산", concept: "P(A ∪ B) = P(A) + P(B) − P(A ∩ B), P(A|B) = P(A ∩ B)/P(B), 서로 독립이면 P(A ∩ B) = P(A)P(B), P(Aᶜ) = 1 − P(A)",
                      steps: steps, answer: text(answer, decimal: decimal))
    }

    // MARK: - 확률변수의 평균 · 분산

    /// E(X) = 3, V(X) = 4, σ(X) = 2, E(X²) = 13, "평균이 5, 분산이 4"
    private static func moments(_ t: String) -> (e: Rat?, v: Rat?, s: Rat?, e2: Rat?) {
        var e: Rat?, v: Rat?, s: Rat?, e2: Rat?
        if let m = match(t, #"E\(\s*X\s*\)\s*=\s*(-?[0-9./]+)"#) { e = ratio(m[1]) }
        if let m = match(t, #"V\(\s*X\s*\)\s*=\s*([0-9./]+)"#) { v = ratio(m[1]) }
        if let m = match(t, #"σ\(\s*X\s*\)\s*=\s*([0-9./]+)"#) { s = ratio(m[1]) }
        if let m = match(t, #"E\(\s*X\s*(?:\^\s*2|²)\s*\)\s*=\s*(-?[0-9./]+)"#) { e2 = ratio(m[1]) }
        if e == nil, let m = match(t, #"(?:X|확률변수\s*X)\s*의\s*평균(?:이|은)\s*(-?[0-9./]+)"#) { e = ratio(m[1]) }
        if v == nil, let m = match(t, #"(?:평균이\s*-?[0-9./]+\s*,?\s*(?:이고)?\s*)?분산(?:이|은)\s*([0-9./]+)"#), t.contains("X") { v = ratio(m[1]) }
        if s == nil, let m = match(t, #"표준편차(?:가|는)\s*([0-9./]+)"#), t.contains("X"), !t.contains("모표준편차") { s = ratio(m[1]) }
        return (e, v, s, e2)
    }

    static func randomVariable(_ raw: String) -> Solved? {
        guard raw.contains("X"), has(raw, ["확률변수", "E(", "V(", "σ("]) else { return nil }
        if has(raw, ["이항분포", "정규분포", "B(", "N("]) { return nil }
        let t = raw.replacingOccurrences(of: "−", with: "-")
        // 확률분포표: P(X = 1) = 1/4, …
        let table = matches(t, #"P\(\s*X\s*=\s*(-?\d+)\s*\)\s*=\s*([0-9./]+|[a-z])"#)
        if table.count >= 2 { return distributionTable(t, table) }
        var (e, v, s, e2) = moments(t)
        var steps: [SolutionStep] = []
        if v == nil, let e = e, let e2 = e2, let sq = e * e, let vv = e2 - sq { v = vv; steps.append(step("V(X) = E(X²) − {E(X)}²", "\(e2.text) − (\(e.text))² = \(vv.text)")) }
        if v == nil, let s = s, let vv = s * s { v = vv }
        // Y = aX + b 의 평균·분산
        var a: Rat = .one, b: Rat = .zero
        var linear = false
        if let m = matches(t, #"(?:Y\s*=\s*|[EVσ]\(\s*)(-?\d*(?:\.\d+)?(?:/\d+)?)\s*X\s*([+-]\s*\d+(?:\.\d+)?(?:/\d+)?)?\s*\)?"#).first(where: { !($0[1].isEmpty && $0[2].isEmpty) }) {
            if !m[1].isEmpty { guard let r = m[1] == "-" ? Rat(-1) : ratio(m[1]) else { return nil }; a = r }
            if !m[2].isEmpty { guard let r = ratio(m[2].replacingOccurrences(of: "+", with: "")) else { return nil }; b = r }
            linear = true
        }
        // 물은 것: "V(2X + 3)의 값", "Y의 평균은", "… − 2 의 분산은"
        let asksMean = t.range(of: #"E\(\s*-?\d*(?:\.\d+)?(?:/\d+)?\s*X\s*[+-]?[^)]*\)\s*(?:의|값|은|는|\?)|의\s*평균(?:은|을|\?|의\s*값)|기댓값(?:은|을|\?)"#, options: .regularExpression) != nil
        let asksVar = t.range(of: #"V\(\s*-?\d*(?:\.\d+)?(?:/\d+)?\s*X\s*[+-]?[^)]*\)\s*(?:의|값|은|는|\?)|의\s*분산(?:은|을|\?|의\s*값)"#, options: .regularExpression) != nil
        let asksSD = t.range(of: #"σ\(\s*-?\d*(?:\.\d+)?(?:/\d+)?\s*X\s*[+-]?[^)]*\)\s*(?:의|값|은|는|\?)|의\s*표준편차(?:는|를|\?|의\s*값)"#, options: .regularExpression) != nil
        let concept = "E(aX + b) = aE(X) + b, V(aX + b) = a²V(X), σ(aX + b) = |a|σ(X), V(X) = E(X²) − {E(X)}²"
        let label = linear ? "\(a.text == "1" ? "" : a.text)X\(b.isZero ? "" : (b.n < 0 ? " − " + (-b).text : " + " + b.text))" : "X"
        if asksMean && !asksVar && !asksSD {
            guard let e = e, let ae = a * e, let r = ae + b else { return nil }
            if linear { steps.append(step("E(\(label)) = \(a.text)E(X) + \(b.text)", r.text)) }
            guard linear || !steps.isEmpty else { return nil }
            return Solved(kind: .statistics, topic: "확률변수의 평균", concept: concept, steps: steps.isEmpty ? [step("평균", r.text)] : steps, answer: r.text)
        }
        if asksVar && !asksMean && !asksSD {
            guard let v = v, let a2 = a * a, let r = a2 * v else { return nil }
            guard linear || !steps.isEmpty else { return nil }
            if linear { steps.append(step("V(\(label)) = (\(a.text))² V(X)", r.text)) }
            return Solved(kind: .statistics, topic: "확률변수의 분산", concept: concept, steps: steps, answer: r.text)
        }
        if asksSD && !asksMean && !asksVar {
            guard let v = v, let a2 = a * a, let r = a2 * v, let root = DoitMathExact.Surd.sqrt(r) else { return nil }
            steps.append(step("σ = √V", "√(\(r.text)) = \(root.text)"))
            return Solved(kind: .statistics, topic: "확률변수의 표준편차", concept: concept, steps: steps, answer: root.text)
        }
        return nil
    }

    private static func distributionTable(_ t: String, _ rows: [[String]]) -> Solved? {
        var xs: [Rat] = [], ps: [Rat?] = []
        var unknown: Character?
        for r in rows {
            guard let x = ratio(r[1]) else { return nil }
            if xs.contains(x) { return nil }
            xs.append(x)
            if let p = ratio(r[2]) { ps.append(p) } else {
                guard let c = r[2].first, unknown == nil || unknown == c else { return nil }
                unknown = c; ps.append(nil)
            }
        }
        var steps: [SolutionStep] = []
        // 확률의 합은 1 (모르는 확률이 하나면 구함)
        let knownSum = ps.compactMap { $0 }.reduce(Rat.zero) { ($0 + $1) ?? $0 }
        if ps.contains(where: { $0 == nil }) {
            let count = ps.filter { $0 == nil }.count
            guard let rest = Rat.one - knownSum, let each = rest / Rat(count)! else { return nil }
            ps = ps.map { $0 ?? each }
            steps.append(step("확률의 합은 1", "\(unknown.map(String.init) ?? "?") = \(each.text)"))
            if let u = unknown, t.range(of: "(?<![a-zA-Z])\(u)\\s*의\\s*값", options: .regularExpression) != nil, !has(t, ["E(", "V(", "σ(", "평균", "분산", "표준편차"]) {
                return Solved(kind: .statistics, topic: "확률분포", concept: "확률분포에서 모든 확률의 합은 1이에요.", steps: steps, answer: each.text)
            }
        } else {
            guard knownSum == .one else { return nil }
        }
        let probs = ps.compactMap { $0 }
        guard probs.count == xs.count, probs.allSatisfy({ $0.n >= 0 }) else { return nil }
        var e = Rat.zero, e2 = Rat.zero
        for (x, p) in zip(xs, probs) {
            guard let xp = x * p, let s = e + xp, let x2 = x * x, let x2p = x2 * p, let s2 = e2 + x2p else { return nil }
            e = s; e2 = s2
        }
        guard let sq = e * e, let v = e2 - sq else { return nil }
        steps.append(step("E(X) = ∑ x·P(X = x)", e.text))
        let concept = "E(X) = ∑xᵢpᵢ, V(X) = E(X²) − {E(X)}², σ(X) = √V(X)"
        if t.range(of: #"V\(\s*X\s*\)|분산"#, options: .regularExpression) != nil {
            steps.append(step("V(X) = E(X²) − {E(X)}²", "\(e2.text) − (\(e.text))² = \(v.text)"))
            return Solved(kind: .statistics, topic: "확률분포의 분산", concept: concept, steps: steps, answer: v.text)
        }
        if t.range(of: #"σ\(\s*X\s*\)|표준편차"#, options: .regularExpression) != nil, let root = DoitMathExact.Surd.sqrt(v) {
            steps.append(step("σ(X) = √V(X)", "√(\(v.text)) = \(root.text)"))
            return Solved(kind: .statistics, topic: "확률분포의 표준편차", concept: concept, steps: steps, answer: root.text)
        }
        if t.range(of: #"E\(\s*X\s*\)|평균|기댓값"#, options: .regularExpression) != nil {
            return Solved(kind: .statistics, topic: "확률분포의 평균", concept: concept, steps: steps, answer: e.text)
        }
        return nil
    }

    // MARK: - 이항분포 B(n, p)

    static func binomialDistribution(_ raw: String) -> Solved? {
        guard raw.contains("B("), has(raw, ["이항분포", "확률변수"]) else { return nil }
        let t = raw.replacingOccurrences(of: " ", with: "")
        guard let m = match(t, #"B\((\d+|n),([0-9./]+|p)\)"#) else { return nil }
        let concept = "이항분포 B(n, p)를 따르면 P(X = r) = ₙCᵣ pʳ(1 − p)ⁿ⁻ʳ, E(X) = np, V(X) = np(1 − p), σ(X) = √(np(1 − p))"
        // n을 모를 때: E(X) = 8 이면 n = 8/p
        if m[1] == "n" {
            guard let p = ratio(m[2]), p.n > 0 else { return nil }
            let mom = moments(t)
            let e = mom.e, v = mom.v, s = mom.s
            var n: Rat?
            if let e = e { n = e / p }
            else if let v = v, let q = Rat.one - p, let pq = p * q { n = v / pq }
            else if let s = s, let s2 = s * s, let q = Rat.one - p, let pq = p * q { n = s2 / pq }
            guard let nn = n, nn.isInteger, nn.n > 0, t.range(of: #"(?<![a-z])n의값"#, options: .regularExpression) != nil else { return nil }
            return Solved(kind: .statistics, topic: "이항분포", concept: concept, steps: [step("E(X) = np 또는 V(X) = np(1 − p) 에서", "n = \(nn.text)")], answer: nn.text)
        }
        guard let n = Int(m[1]), n > 0, n <= 10000, let p = ratio(m[2]), p.n >= 0, p.n <= p.d, let q = Rat.one - p,
              let mean = Rat(n)! * p, let variance = mean * q else { return nil }
        let decimal = m[2].contains(".")
        // P(X = r)
        if let pm = match(t, #"P\(X=(\d+)\)"#), let r = Int(pm[1]), r <= n, n <= 60 {
            guard let pr = p.power(r), let qr = q.power(n - r), let c = Rat(Int(DoitMathTopics.combination(n, r))), let a = c * pr, let prob = a * qr else { return nil }
            return Solved(kind: .statistics, topic: "이항분포의 확률", concept: concept,
                          steps: [step("P(X = \(r)) = ₙCᵣ pʳ(1 − p)ⁿ⁻ʳ", "\(n)C\(r) × (\(p.text))^\(r) × (\(q.text))^\(n - r) = \(prob.text)")], answer: text(prob, decimal: decimal))
        }
        // E(aX + b), V(aX + b) 는 아래 일반 규칙으로
        var a: Rat = .one, b: Rat = .zero
        if let lm = match(t, #"[EVσ]\((-?\d*(?:\.\d+)?)X([+-]\d+(?:\.\d+)?)?\)"#) {
            if !lm[1].isEmpty { guard let r = lm[1] == "-" ? Rat(-1) : ratio(lm[1]) else { return nil }; a = r }
            if !lm[2].isEmpty { guard let r = ratio(lm[2].replacingOccurrences(of: "+", with: "")) else { return nil }; b = r }
        }
        if t.range(of: #"V\([^)]*X[^)]*\)|분산"#, options: .regularExpression) != nil, !t.contains("표준편차"), !t.contains("σ(") {
            guard let a2 = a * a, let r = a2 * variance else { return nil }
            return Solved(kind: .statistics, topic: "이항분포의 분산", concept: concept, steps: [step("V(X) = np(1 − p)", "\(n) × \(p.text) × \(q.text) = \(variance.text)")] + (a == .one ? [] : [step("V(aX + b) = a²V(X)", r.text)]), answer: text(r, decimal: decimal))
        }
        if t.range(of: #"σ\([^)]*X[^)]*\)|표준편차"#, options: .regularExpression) != nil {
            guard let a2 = a * a, let r = a2 * variance, let root = DoitMathExact.Surd.sqrt(r) else { return nil }
            return Solved(kind: .statistics, topic: "이항분포의 표준편차", concept: concept, steps: [step("V(X) = np(1 − p)", variance.text), step("σ = √V", root.text)], answer: root.text)
        }
        if t.range(of: #"E\([^)]*X[^)]*\)|평균|기댓값"#, options: .regularExpression) != nil {
            guard let am = a * mean, let r = am + b else { return nil }
            return Solved(kind: .statistics, topic: "이항분포의 평균", concept: concept, steps: [step("E(X) = np", "\(n) × \(p.text) = \(mean.text)")] + (a == .one && b.isZero ? [] : [step("E(aX + b) = aE(X) + b", r.text)]), answer: text(r, decimal: decimal))
        }
        return nil
    }

    // MARK: - 정규분포 N(m, σ²)

    static func normalDistribution(_ raw: String) -> Solved? {
        guard raw.contains("N("), has(raw, ["정규분포"]) else { return nil }
        let t = DoitAlgebra.normalize(raw).replacingOccurrences(of: " ", with: "")
        guard let m = match(t, #"N\((-?\d+(?:\.\d+)?),(\d+(?:\.\d+)?)(\^2)?\)"#), let mean = Double(m[1]), let s0 = Double(m[2]) else { return nil }
        let sigma = m[3].isEmpty ? s0.squareRoot() : s0
        guard sigma > 0 else { return nil }
        let concept = "X가 정규분포 N(m, σ²)을 따르면 Z = (X − m)/σ 는 표준정규분포 N(0, 1)을 따라요. 그래프는 x = m에 대하여 대칭이에요."
        // 표준화한 값
        if has(t, ["표준화"]), let x = match(t, #"[Xx]=(-?\d+(?:\.\d+)?)"#).flatMap({ Double($0[1]) }) {
            let z = (x - mean) / sigma
            guard let zs = DoitMathCalc.nice(z, allow: [], tol: 1e-12) else { return nil }
            return Solved(kind: .statistics, topic: "정규분포의 표준화", concept: concept, steps: [step("Z = (X − m)/σ", "(\(DoitMath.format(x)) − \(DoitMath.format(mean)))/\(DoitMath.format(sigma)) = \(zs)")], answer: zs)
        }
        // 표준정규분포표 값: P(0≤Z≤1)=0.3413
        var tableValues: [Double: Double] = [:]
        for r in matches(t, #"P\(0≤Z≤(\d+(?:\.\d+)?)\)=(0\.\d+)"#) { if let z = Double(r[1]), let p = Double(r[2]) { tableValues[z] = p } }
        func phi0(_ z: Double) -> Double? {   // P(0 ≤ Z ≤ |z|)
            if abs(z) < 1e-12 { return 0 }
            return tableValues.first(where: { abs($0.key - abs(z)) < 1e-9 })?.value
        }
        // P(X ≤ a), P(X ≥ a), P(a ≤ X ≤ b)
        func cdf(_ x: Double) -> Double? {   // P(X ≤ x)
            let z = (x - mean) / sigma
            guard let h = phi0(z) else { return nil }
            return z >= 0 ? 0.5 + h : 0.5 - h
        }
        var prob: Double?
        var shown = ""
        if let r = match(t, #"P\((-?\d+(?:\.\d+)?)[≤<][Xx][≤<](-?\d+(?:\.\d+)?)\)"#), let a = Double(r[1]), let b = Double(r[2]), let fa = cdf(a), let fb = cdf(b) { prob = fb - fa; shown = r[0] }
        else if let r = match(t, #"P\([Xx][≤<](-?\d+(?:\.\d+)?)\)"#), let a = Double(r[1]), let fa = cdf(a) { prob = fa; shown = r[0] }
        else if let r = match(t, #"P\([Xx][≥>](-?\d+(?:\.\d+)?)\)"#), let a = Double(r[1]), let fa = cdf(a) { prob = 1 - fa; shown = r[0] }
        guard let p = prob, p >= 0, p <= 1 else { return nil }
        let rounded = (p * 10000).rounded() / 10000
        guard abs(rounded - p) < 1e-9 else { return nil }
        let ans = DoitMath.format(rounded)
        return Solved(kind: .statistics, topic: "정규분포의 확률", concept: concept,
                      steps: [step("표준화 Z = (X − \(DoitMath.format(mean)))/\(DoitMath.format(sigma))", shown), step("표준정규분포의 대칭성과 표의 값으로", ans)], answer: ans)
    }

    // MARK: - 표본평균

    static func sampleMean(_ t: String) -> Solved? {
        guard has(t, ["표본평균"]), let n = match(t, #"크기가\s*(\d+)\s*인\s*표본"#).flatMap({ Int($0[1]) }), n > 0 else { return nil }
        let concept = "모평균 m, 모표준편차 σ인 모집단에서 크기 n인 표본을 뽑으면 E(X̄) = m, V(X̄) = σ²/n, σ(X̄) = σ/√n"
        if let s = match(t, #"모표준편차(?:가|는|이)?\s*(\d+(?:\.\d+)?)"#).flatMap({ ratio($0[1]) }), let v = s * s, let vn = v / Rat(n)! {
            if has(t, ["표본평균의 표준편차", "표본평균 X̄의 표준편차"]) || t.range(of: #"σ\(\s*X̄\s*\)"#, options: .regularExpression) != nil, let root = DoitMathExact.Surd.sqrt(vn) {
                return Solved(kind: .statistics, topic: "표본평균의 분포", concept: concept, steps: [step("σ(X̄) = σ/√n", "\(s.text)/√\(n) = \(root.text)")], answer: root.text)
            }
            if has(t, ["표본평균의 분산"]) || t.range(of: #"V\(\s*X̄\s*\)"#, options: .regularExpression) != nil {
                return Solved(kind: .statistics, topic: "표본평균의 분포", concept: concept, steps: [step("V(X̄) = σ²/n", "\(v.text)/\(n) = \(vn.text)")], answer: vn.text)
            }
        }
        if let m = match(t, #"모평균(?:이|은)?\s*(-?\d+(?:\.\d+)?)"#), has(t, ["표본평균의 평균"]) || t.range(of: #"E\(\s*X̄\s*\)"#, options: .regularExpression) != nil {
            return Solved(kind: .statistics, topic: "표본평균의 분포", concept: concept, steps: [step("E(X̄) = m", m[1])], answer: m[1])
        }
        return nil
    }

    // MARK: - 중복순열 · 중복조합

    static func repetition(_ raw: String) -> Solved? {
        let subs: [Character: Character] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9"]
        let t = String(raw.map { subs[$0] ?? $0 })
        let found = matches(t, #"(?<![0-9])(\d{1,2})\s*([ΠH∏])\s*(\d{1,2})(?![0-9])"#)
        guard !found.isEmpty else { return nil }
        // 식 전체가 이것들의 곱·합이면 계산 ("₅H₂ + ₃Π₂")
        var expression = DoitAlgebra.extract(t, extra: "ΠH∏")
        guard expression.contains("Π") || expression.contains("H") || expression.contains("∏") else { return nil }
        var steps: [SolutionStep] = []
        for m in found {
            guard let n = Int(m[1]), let r = Int(m[3]) else { return nil }
            let value: Double
            if m[2] == "H" {
                guard n >= 1 else { return nil }
                value = DoitMathTopics.combination(n + r - 1, r)
                steps.append(step("중복조합 ₙHᵣ = ₙ₊ᵣ₋₁Cᵣ", "\(n)H\(r) = \(n + r - 1)C\(r) = \(DoitMath.format(value))"))
            } else {
                value = pow(Double(n), Double(r))
                steps.append(step("중복순열 ₙΠᵣ = nʳ", "\(n)Π\(r) = \(n)^\(r) = \(DoitMath.format(value))"))
            }
            guard value < 1e15 else { return nil }
            expression = expression.replacingOccurrences(of: m[0].trimmingCharacters(in: .whitespaces), with: "(\(DoitMath.format(value)))")
        }
        guard !expression.contains("Π"), !expression.contains("H"), let v = Expression.evaluate(expression), v == v.rounded(), abs(v) < 1e15 else { return nil }
        let ans = DoitMath.format(v)
        if found.count > 1 { steps.append(step("계산하면", ans)) }
        return Solved(kind: .counting, topic: "중복순열 · 중복조합", concept: "서로 다른 n개에서 중복을 허락해 r개를 택해 일렬로: ₙΠᵣ = nʳ, 중복을 허락해 r개를 택하는 조합: ₙHᵣ = ₙ₊ᵣ₋₁Cᵣ",
                      steps: steps, answer: ans)
    }

    // MARK: - 같은 글자가 있는 영어 단어 배열

    static func wordArrangement(_ t: String) -> Solved? {
        guard has(t, ["나열", "배열"]), has(t, ["경우의 수", "방법의 수"]), !has(t, ["이웃", "양 끝", "맨 앞", "맨 뒤", "적어도", "끼리", "사이", "순서"]),
              let m = match(t, #"(?<![A-Za-z])([A-Za-z]{3,12})(?![A-Za-z])\s*(?:의|에서|라는|이라는)?\s*(?:\d+\s*개의?\s*)?(?:문자|글자|알파벳)"#) else { return nil }
        let word = m[1]
        // 문자 개수를 말했으면 맞아야 함
        if let c = match(t, #"(\d+)\s*개의?\s*(?:문자|글자)"#), Int(c[1]) != word.count { return nil }
        guard has(t, ["모두", "전부", "일렬"]) else { return nil }
        var counts: [Character: Int] = [:]
        for ch in word { counts[ch, default: 0] += 1 }
        var v = DoitMathTopics.factorial(word.count)
        for (_, k) in counts { v /= DoitMathTopics.factorial(k) }
        guard v == v.rounded(), v < 1e15 else { return nil }
        let repeated = counts.filter { $0.value > 1 }.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)개" }
        let den = counts.values.filter { $0 > 1 }.sorted(by: >).map { "\($0)!" }.joined(separator: " × ")
        return Solved(kind: .counting, topic: "같은 것이 있는 순열", concept: "n개 중 같은 것이 p개, q개, … 있을 때 일렬로 나열하는 경우의 수는 n!/(p! q! …)",
                      steps: [step("글자 \(word.count)개 중 같은 것", repeated.isEmpty ? "없어요" : repeated.joined(separator: ", ")),
                              step("\(word.count)!" + (den.isEmpty ? "" : " / (\(den))"), DoitMath.format(v))], answer: DoitMath.format(v))
    }

    // MARK: - 공을 상자에 넣기

    static func ballsBoxes(_ t: String) -> Solved? {
        guard let m = match(t, #"서로\s*다른\s*(\d+)\s*개의\s*(공|물건|구슬|사탕|편지)[^.?]*?서로\s*다른\s*(\d+)\s*개의\s*(상자|주머니|우체통|바구니)"#),
              let balls = Int(m[1]), let boxes = Int(m[3]), balls <= 12, boxes <= 12, has(t, ["넣는", "넣을"]) else { return nil }
        // 빈 상자가 있어도 될 때만 (없어야 하면 다른 계산이 필요해요)
        guard has(t, ["빈 상자가 있을 수", "빈 상자가 있어도", "빈 상자를 허용", "빈 상자가 생겨도"]) || !has(t, ["빈 상자", "적어도 한 개", "1개 이상", "한 개 이상"]) else { return nil }
        let v = pow(Double(boxes), Double(balls))
        return Solved(kind: .counting, topic: "중복순열", concept: "공마다 들어갈 상자를 고르는 것이라 ₙΠᵣ = nʳ (n = 상자 수, r = 공 수)",
                      steps: [step("공 \(balls)개가 각각 상자 \(boxes)개 중 하나를 골라요", "\(boxes)Π\(balls) = \(boxes)^\(balls) = \(DoitMath.format(v))")], answer: DoitMath.format(v))
    }

    // MARK: - 독립시행 (주사위·동전을 여러 번)

    static func independentTrials(_ t: String) -> Solved? {
        guard has(t, ["확률"]), let times = match(t, #"(\d+)\s*(?:번|회)\s*(?:던질|던져|던지)"#).flatMap({ Int($0[1]) }), times >= 2, times <= 20 else { return nil }
        var p: Rat?, what = ""
        let dice = has(t, ["주사위"]) && !has(t, ["두 개의 주사위", "주사위 2개", "주사위 두 개", "2개의 주사위"])
        let coin = has(t, ["동전"]) && !has(t, ["동전 2개", "동전 두 개", "두 개의 동전", "동전 3개", "동전 세 개"])
        if dice, let m = match(t, #"(\d)\s*의\s*눈"#), let k = Int(m[1]), (1...6).contains(k), !has(t, ["배수", "약수", "이상", "이하", "보다"]) { p = Rat(1, 6); what = "\(k)의 눈" }
        else if dice, has(t, ["짝수의 눈"]) { p = Rat(1, 2); what = "짝수의 눈" }
        else if dice, has(t, ["홀수의 눈"]) { p = Rat(1, 2); what = "홀수의 눈" }
        else if dice, let m = match(t, #"(\d)\s*의\s*배수의\s*눈"#), let k = Int(m[1]), k >= 2 { p = Rat(6 / k, 6); what = "\(k)의 배수의 눈" }
        else if coin, has(t, ["앞면"]) { p = Rat(1, 2); what = "앞면" }
        else if coin, has(t, ["뒷면"]) { p = Rat(1, 2); what = "뒷면" }
        guard let prob = p, dice != coin else { return nil }
        guard let q = Rat.one - prob else { return nil }
        let n = times
        func exactly(_ r: Int) -> Rat? {
            guard let pr = prob.power(r), let qr = q.power(n - r), let c = Rat(Int(DoitMathTopics.combination(n, r))), let a = c * pr else { return nil }
            return a * qr
        }
        var answer: Rat?, how = ""
        if let m = match(t, #"(?:정확히\s*)?(\d+)\s*(?:번|회)\s*(?:만\s*)?나올\s*확률"#) ?? match(t, #"(\d+)\s*(?:번|회)\s*나오는\s*확률"#), let r = Int(m[1]), r <= n, r != n || !has(t, ["모두"]) {
            if has(t, ["이상"]) || has(t, ["이하"]) { return nil }
            answer = exactly(r); how = "\(n)C\(r) (\(prob.text))^\(r) (\(q.text))^\(n - r)"
        } else if has(t, ["적어도 한 번", "적어도 1번", "적어도 1회", "적어도 한 번은"]) {
            answer = exactly(0).flatMap { Rat.one - $0 }; how = "1 − (한 번도 안 나올 확률) = 1 − (\(q.text))^\(n)"
        } else if has(t, ["모두 " + what, what + "이 모두", what + "가 모두", "매번 " + what]) || (has(t, ["모두"]) && has(t, [what])) {
            answer = prob.power(n); how = "(\(prob.text))^\(n)"
        } else { return nil }
        guard let a = answer else { return nil }
        return Solved(kind: .counting, topic: "독립시행의 확률", concept: "한 번 할 때 확률이 p인 시행을 n번 독립으로 할 때 r번 일어날 확률은 ₙCᵣ pʳ(1 − p)ⁿ⁻ʳ",
                      steps: [step("한 번에 \(what)이(가) 나올 확률", prob.text), step(how, a.text)], answer: a.text)
    }

    // MARK: - 주사위를 던져 하나씩 세기

    /// 두 눈(또는 한 눈)에 대한 조건 하나 (못 읽으면 nil)
    private static func diceCondition(_ t: String) -> ((Int, Int) -> Bool, String)? {
        func num(_ s: String) -> Int? { Int(s) }
        // 조건이 여러 개이거나 반대(아닐)이면 읽지 않음
        if has(t, ["이고", "그리고", "아닐", "아닌", "않을", "않는", "적어도", "동시에 만족"]) || (t.contains("이상") && t.contains("이하")) { return nil }
        if t.components(separatedBy: "합이").count + t.components(separatedBy: "곱이").count + t.components(separatedBy: "차가").count > 4 { return nil }
        if let m = match(t, #"합이\s*(\d+)\s*이하"#), let k = num(m[1]) { return ({ $0 + $1 <= k }, "합이 \(k) 이하") }
        if let m = match(t, #"합이\s*(\d+)\s*이상"#), let k = num(m[1]) { return ({ $0 + $1 >= k }, "합이 \(k) 이상") }
        if let m = match(t, #"합이\s*(\d+)\s*보다\s*작"#), let k = num(m[1]) { return ({ $0 + $1 < k }, "합이 \(k)보다 작음") }
        if let m = match(t, #"합이\s*(\d+)\s*보다\s*크"#), let k = num(m[1]) { return ({ $0 + $1 > k }, "합이 \(k)보다 큼") }
        if let m = match(t, #"합이\s*(\d+)\s*의\s*배수"#), let k = num(m[1]), k > 0 { return ({ ($0 + $1) % k == 0 }, "합이 \(k)의 배수") }
        if let m = match(t, #"합이\s*(\d+)\s*(?:또는|이나)\s*(\d+)\s*(?:이|일|인)"#), let a = num(m[1]), let b = num(m[2]) { return ({ $0 + $1 == a || $0 + $1 == b }, "합이 \(a) 또는 \(b)") }
        if let m = match(t, #"합이\s*(\d+)\s*(?:이|일|인|가)"#), let k = num(m[1]) { return ({ $0 + $1 == k }, "합이 \(k)") }
        if has(t, ["합이 짝수"]) { return ({ ($0 + $1) % 2 == 0 }, "합이 짝수") }
        if has(t, ["합이 홀수"]) { return ({ ($0 + $1) % 2 == 1 }, "합이 홀수") }
        if has(t, ["곱이 짝수"]) { return ({ ($0 * $1) % 2 == 0 }, "곱이 짝수") }
        if has(t, ["곱이 홀수"]) { return ({ ($0 * $1) % 2 == 1 }, "곱이 홀수") }
        if let m = match(t, #"곱이\s*(\d+)\s*의\s*배수"#), let k = num(m[1]), k > 0 { return ({ ($0 * $1) % k == 0 }, "곱이 \(k)의 배수") }
        if let m = match(t, #"곱이\s*(\d+)\s*(?:이|일|인|가)"#), let k = num(m[1]) { return ({ $0 * $1 == k }, "곱이 \(k)") }
        if let m = match(t, #"차가\s*(\d+)\s*(?:이|일|인|가)"#), let k = num(m[1]) { return ({ abs($0 - $1) == k }, "차가 \(k)") }
        if has(t, ["눈의 수가 같", "같은 눈", "두 눈이 같"]) { return ({ $0 == $1 }, "두 눈이 같음") }
        if has(t, ["모두 홀수", "두 번 모두 홀수", "둘 다 홀수"]) { return ({ $0 % 2 == 1 && $1 % 2 == 1 }, "모두 홀수") }
        if has(t, ["모두 짝수", "두 번 모두 짝수", "둘 다 짝수"]) { return ({ $0 % 2 == 0 && $1 % 2 == 0 }, "모두 짝수") }
        return nil
    }

    static func diceEnumeration(_ t: String) -> Solved? {
        guard has(t, ["주사위"]), has(t, ["확률", "경우의 수"]) else { return nil }
        let two = has(t, ["두 개의 주사위", "주사위 2개", "주사위 두 개", "2개의 주사위", "두 번 던", "2번 던", "두 번을 던", "주사위 A, B", "두 주사위"])
        guard two, !has(t, ["세 개", "3개", "세 번", "3번"]) else { return nil }
        // "두 눈의 수"가 아니라 "a, b로 만든 식" 같은 것은 다른 풀이로
        if t.range(of: #"[a-z]\s*,\s*[a-z]"#, options: .regularExpression) != nil || has(t, ["방정식", "직선", "점 ("]) { return nil }
        guard let (cond, label) = diceCondition(t) else { return nil }
        var count = 0
        for a in 1...6 { for b in 1...6 where cond(a, b) { count += 1 } }
        let asksProb = has(t, ["확률"])
        if asksProb {
            guard let p = Rat(count, 36) else { return nil }
            return Solved(kind: .counting, topic: "주사위의 확률", concept: "주사위 두 개(또는 두 번)의 모든 경우는 6 × 6 = 36가지예요. 조건에 맞는 순서쌍을 세어요.",
                          steps: [step("모든 경우", "36가지"), step("\(label)인 경우", "\(count)가지"), step("확률", "\(count)/36 = \(p.text)")], answer: p.text)
        }
        return Solved(kind: .counting, topic: "주사위의 경우의 수", concept: "주사위 두 개(또는 두 번)를 던지는 모든 경우는 36가지예요. 조건에 맞는 순서쌍을 세어요.",
                      steps: [step("\(label)인 경우를 세면", "\(count)가지")], answer: "\(count)")
    }

    // MARK: - 주머니에서 꺼내기

    static func drawFromBag(_ t: String) -> Solved? {
        guard has(t, ["확률"]), has(t, ["주머니", "상자"]), has(t, ["꺼낼", "꺼내"]) else { return nil }
        // 색깔별 개수 ("흰 공 4개, 검은 공 3개")
        let colorPattern = #"(흰|검은|빨간|파란|노란|초록|하얀|붉은)\s*공\s*(\d+)\s*개"#
        let before = t.range(of: "꺼내").map { String(t[..<$0.lowerBound]) } ?? t
        let found = matches(before.components(separatedBy: "꺼낼").first ?? before, colorPattern)
        guard found.count >= 2, found.count <= 4 else { return nil }
        var colors: [(String, Int)] = []
        for m in found {
            guard let k = Int(m[2]), !colors.contains(where: { $0.0 == m[1] }) else { return nil }
            colors.append((m[1], k))
        }
        let total = colors.reduce(0) { $0 + $1.1 }
        // 한 번에 몇 개 (동시에 / 차례로 되돌려 놓지 않고)
        guard let drawn = match(t, #"(\d+)\s*개(?:의\s*공)?를?\s*(?:을\s*)?(?:동시에|한꺼번에)?\s*꺼낼"#).flatMap({ Int($0[1]) }) ?? match(t, #"(?:동시에|한꺼번에)\s*(\d+)\s*개"#).flatMap({ Int($0[1]) }),
              drawn >= 1, drawn <= total, drawn <= 6 else { return nil }
        guard has(t, ["동시에", "한꺼번에"]) || drawn == 1 else { return nil }
        // 물은 것: "흰 공 1개와 검은 공 1개", "모두 검은 공", "적어도 한 개는 흰 공"
        let afterDraw = t.range(of: "꺼낼").map { String(t[$0.upperBound...]) } ?? t
        var want: [String: Int] = [:]
        for m in matches(afterDraw, #"(흰|검은|빨간|파란|노란|초록|하얀|붉은)\s*공\s*(\d+)\s*개"#) { if let k = Int(m[2]) { want[m[1]] = k } }
        let ways = DoitMathTopics.combination(total, drawn)
        var favorable: Double
        var how: String
        if !want.isEmpty {
            guard want.values.reduce(0, +) == drawn, want.keys.allSatisfy({ k in colors.contains { $0.0 == k } }) else { return nil }
            favorable = 1
            var parts: [String] = []
            for (c, k) in want.sorted(by: { $0.key < $1.key }) {
                let n = colors.first { $0.0 == c }!.1
                favorable *= DoitMathTopics.combination(n, k)
                parts.append("\(n)C\(k)")
            }
            how = parts.joined(separator: " × ")
        } else if let m = match(afterDraw, #"모두\s*(흰|검은|빨간|파란|노란|초록|하얀|붉은)\s*공"#) ?? match(afterDraw, #"(흰|검은|빨간|파란|노란|초록|하얀|붉은)\s*공\s*(?:이|만)?\s*모두"#),
                  let n = colors.first(where: { $0.0 == m[1] })?.1 {
            favorable = DoitMathTopics.combination(n, drawn); how = "\(n)C\(drawn)"
        } else if let m = match(afterDraw, #"적어도\s*(?:한|1)\s*개(?:는|가)?\s*(흰|검은|빨간|파란|노란|초록|하얀|붉은)\s*공"#), let n = colors.first(where: { $0.0 == m[1] })?.1 {
            favorable = ways - DoitMathTopics.combination(total - n, drawn); how = "\(total)C\(drawn) − \(total - n)C\(drawn)"
        } else if drawn == 1, let m = match(afterDraw, #"(흰|검은|빨간|파란|노란|초록|하얀|붉은)\s*공\s*(?:이|일)"#), let n = colors.first(where: { $0.0 == m[1] })?.1 {
            favorable = Double(n); how = "\(n)"
        } else { return nil }
        guard let p = Rat(Int(favorable), Int(ways)) else { return nil }
        return Solved(kind: .counting, topic: "주머니에서 꺼낼 확률", concept: "모든 경우 ₙCᵣ 중에서 원하는 색을 고르는 경우를 조합으로 세어 나눠요.",
                      steps: [step("모든 경우", "\(total)C\(drawn) = \(DoitMath.format(ways))"), step("원하는 경우", "\(how) = \(DoitMath.format(favorable))"),
                              step("확률", "\(DoitMath.format(favorable))/\(DoitMath.format(ways)) = \(p.text)")], answer: p.text)
    }

    // MARK: - 1부터 N까지에서 서로 다른 두 수

    static func pairFromRange(_ t: String) -> Solved? {
        guard has(t, ["확률", "경우의 수"]), let r = match(t, #"1\s*부터\s*(\d+)\s*까지의?\s*(?:자연수|수|정수)"#), let n = Int(r[1]), n >= 2, n <= 100,
              has(t, ["서로 다른 두 수", "서로 다른 2개의 수", "두 수를", "2개를"]), !has(t, ["카드를 한 장씩", "차례로", "두 자리"]) else { return nil }
        guard let (cond, label) = diceCondition(t) else { return nil }
        var count = 0, total = 0
        for a in 1...n { for b in (a + 1)...max(a + 1, n) where b <= n { total += 1; if cond(a, b) { count += 1 } } }
        guard total > 0 else { return nil }
        if has(t, ["확률"]) {
            guard let p = Rat(count, total) else { return nil }
            return Solved(kind: .counting, topic: "확률", concept: "서로 다른 두 수를 택하는 모든 경우는 ₙC₂ 가지예요. 조건에 맞는 경우를 세어 나눠요.",
                          steps: [step("모든 경우", "\(n)C2 = \(total)"), step("\(label)인 경우", "\(count)가지"), step("확률", "\(count)/\(total) = \(p.text)")], answer: p.text)
        }
        return Solved(kind: .counting, topic: "경우의 수", concept: "서로 다른 두 수를 택하는 경우를 하나씩 세어요.", steps: [step("\(label)인 경우", "\(count)가지")], answer: "\(count)")
    }

    // MARK: - 일렬로 세울 때의 확률

    static func lineupProbability(_ t: String) -> Solved? {
        guard has(t, ["확률"]), has(t, ["일렬로", "한 줄로"]), has(t, ["세울", "앉힐", "나열", "배열"]) else { return nil }
        let people = matches(t, #"(남학생|여학생|남자|여자|어른|어린이|학생|선생님)\s*(\d+)\s*명"#)
        guard !people.isEmpty else { return nil }
        let total = people.compactMap { Int($0[2]) }.reduce(0, +)
        guard total >= 2, total <= 10 else { return nil }
        // 경우의 수 풀이로 원하는 경우를 세고 전체 n!로 나눔
        let asCount = t.replacingOccurrences(of: "확률", with: "경우의 수")
        guard let counted = DoitMathMore.arrangements(asCount), let fav = Double(counted.answer.replacingOccurrences(of: ",", with: "")), fav == fav.rounded(), fav > 0 else { return nil }
        let all = DoitMathTopics.factorial(total)
        guard fav <= all, let p = Rat(Int(fav), Int(all)) else { return nil }
        return Solved(kind: .counting, topic: "순열과 확률", concept: "n명을 일렬로 세우는 모든 경우는 n!가지예요. 조건에 맞게 세우는 경우를 세어 나눠요.",
                      steps: counted.steps + [step("모든 경우", "\(total)! = \(DoitMath.format(all))"), step("확률", "\(DoitMath.format(fav))/\(DoitMath.format(all)) = \(p.text)")], answer: p.text)
    }
}
