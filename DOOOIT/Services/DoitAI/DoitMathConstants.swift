import Foundation

/// 두잇 AI: 모르는 상수가 여러 개인 문제 (외부 AI 없이 직접 계산)
/// - 그래프가 지나는 두 점, 두 근, 나머지정리 조건 두 개, 항등식의 계수 비교, 극값·접선·꼭짓점 조건
/// - 연립방정식의 해가 주어진 상수, 복소수가 서로 같을 조건, 부등식의 해, 극한·연속 조건
/// 조건을 상수에 대한 방정식으로 바꿔 연립해서 풀고, 해가 하나로 정해지지 않으면 nil
enum DoitMathConstants {
    typealias Solved = MathSolver.Solved

    private static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }
    private static func f(_ v: Double) -> String { DoitMath.fraction(v) }
    private static func match(_ t: String, _ p: String) -> [String]? { DoitMathExact.match(t, p) }
    private static func matches(_ t: String, _ p: String) -> [[String]] { DoitMathExact.matches(t, p) }

    /// 정수 · 소수 · 분수 하나
    static let num = #"(-?\d+(?:\.\d+)?(?:/\d+)?)"#

    static func value(_ s: String) -> Double? {
        let parts = s.replacingOccurrences(of: " ", with: "").split(separator: "/").map(String.init)
        if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]), b != 0 { return a / b }
        return parts.count == 1 ? Double(parts[0]) : nil
    }

    // MARK: - 여러 문자 다항식 (문자 이름 자유, i² = −1)

    struct GPoly {
        typealias Key = [Character: Int]
        var t: [Key: Double] = [:]

        static func constant(_ v: Double) -> GPoly { GPoly(t: [[:]: v]).cleaned }
        static func variable(_ c: Character) -> GPoly { GPoly(t: [[c: 1]: 1]) }

        var cleaned: GPoly { GPoly(t: t.filter { abs($0.value) > 1e-10 }) }
        var isZero: Bool { cleaned.t.isEmpty }
        var constantValue: Double { t[[:]] ?? 0 }
        var letters: Set<Character> {
            var out = Set<Character>()
            for key in cleaned.t.keys { for (c, e) in key where e > 0 { out.insert(c) } }
            return out
        }

        func degree(in c: Character) -> Int {
            let d = cleaned.t.keys.map { $0[c] ?? 0 }
            return d.max() ?? -1
        }

        func totalDegree(in set: Set<Character>) -> Int {
            var best = -1
            for key in cleaned.t.keys {
                var d = 0
                for (c, e) in key where set.contains(c) { d += e }
                best = max(best, d)
            }
            return best
        }

        static func + (l: GPoly, r: GPoly) -> GPoly {
            var o = l
            for (k, v) in r.t { o.t[k, default: 0] += v }
            return o.cleaned
        }
        static prefix func - (p: GPoly) -> GPoly { GPoly(t: p.t.mapValues { -$0 }) }
        static func - (l: GPoly, r: GPoly) -> GPoly { l + (-r) }
        static func * (l: GPoly, r: GPoly) -> GPoly {
            var o: [Key: Double] = [:]
            for (a, va) in l.t {
                for (b, vb) in r.t {
                    var k = a
                    for (c, e) in b { k[c, default: 0] += e }
                    var sign = 1.0
                    if let e = k["i"], e >= 2 {
                        if (e / 2) % 2 == 1 { sign = -1 }
                        k["i"] = e % 2 == 0 ? nil : 1
                    }
                    o[k, default: 0] += sign * va * vb
                }
            }
            return GPoly(t: o).cleaned
        }

        func scaled(_ v: Double) -> GPoly { GPoly(t: t.mapValues { $0 * v }).cleaned }

        func power(_ n: Int) -> GPoly {
            var out = GPoly.constant(1)
            for _ in 0..<max(0, n) { out = out * self }
            return out
        }

        /// c^k 항만 모아서 c를 뗀 것
        func coefficient(_ c: Character, _ k: Int) -> GPoly {
            var o: [Key: Double] = [:]
            for (key, v) in cleaned.t where (key[c] ?? 0) == k {
                var nk = key
                nk[c] = nil
                o[nk, default: 0] += v
            }
            return GPoly(t: o).cleaned
        }

        func substitute(_ c: Character, _ value: Double) -> GPoly {
            substitute(c, GPoly.constant(value))
        }

        func substitute(_ c: Character, _ p: GPoly) -> GPoly {
            let d = degree(in: c)
            guard d >= 1 else { return self }
            var out = GPoly()
            for k in 0...d { out = out + coefficient(c, k) * p.power(k) }
            return out
        }

        func derivative(_ c: Character) -> GPoly {
            var o: [Key: Double] = [:]
            for (key, v) in cleaned.t {
                guard let e = key[c], e >= 1 else { continue }
                var nk = key
                nk[c] = e == 1 ? nil : e - 1
                o[nk, default: 0] += v * Double(e)
            }
            return GPoly(t: o).cleaned
        }

        func evaluate(_ values: [Character: Double]) -> Double? {
            var total = 0.0
            for (key, v) in cleaned.t {
                var term = v
                for (c, e) in key {
                    guard let x = values[c] else { return nil }
                    term *= pow(x, Double(e))
                }
                total += term
            }
            return total
        }

        /// x만 남은 다항식 → Poly (다른 문자가 있으면 nil)
        func univariate(_ c: Character) -> DoitMath.Poly? {
            var p = DoitMath.Poly()
            for (key, v) in cleaned.t {
                guard key.keys.allSatisfy({ $0 == c }) else { return nil }
                let e = key[c] ?? 0
                guard e < DoitMath.Poly.size else { return nil }
                p.c[e] += v
            }
            return p
        }
    }

    /// 수식 → GPoly (variables에 든 문자만 문자로)
    static func parse(_ raw: String, variables: Set<Character>) -> GPoly? {
        var s = DoitMathExact.superscriptsToPowers(DoitAlgebra.normalize(raw)).replacingOccurrences(of: " ", with: "")
        s = s.replacingOccurrences(of: "[", with: "(").replacingOccurrences(of: "]", with: ")")
        s = s.replacingOccurrences(of: "{", with: "(").replacingOccurrences(of: "}", with: ")")
        guard !s.isEmpty else { return nil }
        var p = GParser(c: Array(s), vars: variables)
        guard let r = p.expression(), p.i == p.c.count else { return nil }
        return r
    }

    private struct GParser {
        let c: [Character]
        let vars: Set<Character>
        var i = 0
        var peek: Character? { i < c.count ? c[i] : nil }

        mutating func expression() -> GPoly? {
            guard var v = term() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                i += 1
                guard let r = term() else { return nil }
                v = op == "+" ? v + r : v - r
            }
            return v
        }

        mutating func term() -> GPoly? {
            guard var v = unary() else { return nil }
            while let op = peek {
                if op == "*" {
                    i += 1
                    guard let r = unary() else { return nil }
                    v = v * r
                } else if op == "/" {
                    i += 1
                    guard let r = unary(), r.letters.isEmpty, abs(r.constantValue) > 1e-12 else { return nil }
                    v = v.scaled(1 / r.constantValue)
                } else if op == "(" || op == "√" || op == "π" || op.isNumber || vars.contains(op) {
                    guard let r = power() else { return nil }
                    v = v * r
                } else { break }
            }
            return v
        }

        mutating func unary() -> GPoly? {
            if peek == "-" { i += 1; return unary().map { -$0 } }
            if peek == "+" { i += 1; return unary() }
            return power()
        }

        mutating func power() -> GPoly? {
            guard let b = primary() else { return nil }
            guard peek == "^" else { return b }
            i += 1
            guard let e = unary(), e.letters.isEmpty else { return nil }
            let k = e.constantValue
            guard k >= 0, k <= 12, k == k.rounded() else { return nil }
            return b.power(Int(k))
        }

        mutating func primary() -> GPoly? {
            guard let ch = peek else { return nil }
            if ch == "(" {
                i += 1
                guard let v = expression(), peek == ")" else { return nil }
                i += 1
                return v
            }
            if ch == "√" {
                i += 1
                guard let v = primary(), v.letters.isEmpty, v.constantValue >= 0 else { return nil }
                return GPoly.constant(v.constantValue.squareRoot())
            }
            if ch == "π" { i += 1; return GPoly.constant(.pi) }
            if vars.contains(ch) { i += 1; return GPoly.variable(ch) }
            var digits = ""
            while let d = peek, d.isNumber || d == "." { digits.append(d); i += 1 }
            guard let v = Double(digits) else { return nil }
            return GPoly.constant(v)
        }
    }

    // MARK: - 보기 좋게

    static func describe(_ p: GPoly) -> String {
        let terms = p.cleaned.t.sorted { a, b in
            let da = a.key.values.reduce(0, +), db = b.key.values.reduce(0, +)
            if da != db { return da > db }
            return name(a.key) < name(b.key)
        }
        guard !terms.isEmpty else { return "0" }
        var out = ""
        for (index, (key, v)) in terms.enumerated() {
            let letters = name(key)
            let magnitude = abs(v)
            var body = letters.isEmpty || abs(magnitude - 1) > 1e-12 ? f(magnitude) : ""
            if body.contains("/") && !letters.isEmpty { body = "(\(body))" }
            body += letters
            if index == 0 { out = v < 0 ? "−" + body : body }
            else { out += v < 0 ? " − " + body : " + " + body }
        }
        return out
    }

    private static func name(_ key: GPoly.Key) -> String {
        key.sorted { ($0.key == "i" ? "~" : String($0.key)) < ($1.key == "i" ? "~" : String($1.key)) }
            .map { $0.value == 1 ? String($0.key) : "\($0.key)\(DoitMath.superscript($0.value))" }.joined()
    }

    /// "a + b + 1 = 4" 꼴 (상수항을 오른쪽으로)
    static func equationText(_ e: GPoly) -> String {
        let c = e.constantValue
        let rest = e - GPoly.constant(c)
        return "\(describe(rest)) = \(f(-c))"
    }

    // MARK: - 연립해서 풀기

    /// 상수들의 연립방정식 (일차면 소거법, 미지수 2개까지는 한 식이 일차면 대입) → 해들. 하나로 정해지지 않으면 nil
    static func solveEquations(_ eqs: [GPoly], unknowns: [Character]) -> [[Character: Double]]? {
        let set = Set(unknowns)
        let useful = eqs.filter { !$0.isZero }
        guard useful.allSatisfy({ $0.letters.isSubset(of: set) }) else { return nil }
        // 상수항만 남은 식(0이 아닌 수 = 0)이 있으면 모순
        if useful.contains(where: { $0.letters.isEmpty }) { return [] }
        let n = unknowns.count
        if useful.allSatisfy({ $0.totalDegree(in: set) <= 1 }) {
            var rows: [[Double]] = useful.map { e in unknowns.map { e.coefficient($0, 1).constantValue } + [-e.constantValue] }
            var rank = 0
            var pivots: [Int] = []
            for col in 0..<n {
                guard rank < rows.count else { break }
                var best = rank
                for r in rank..<rows.count where abs(rows[r][col]) > abs(rows[best][col]) { best = r }
                guard abs(rows[best][col]) > 1e-10 else { continue }
                rows.swapAt(rank, best)
                let p = rows[rank][col]
                rows[rank] = rows[rank].map { $0 / p }
                for r in 0..<rows.count where r != rank {
                    let factor = rows[r][col]
                    if abs(factor) > 0 { rows[r] = zip(rows[r], rows[rank]).map { $0 - factor * $1 } }
                }
                pivots.append(col)
                rank += 1
            }
            // 남은 식이 0 = (0 아닌 수)면 모순
            for r in rank..<rows.count where abs(rows[r][n]) > 1e-8 { return [] }
            guard rank == n else { return nil }
            var solution: [Character: Double] = [:]
            for (r, col) in pivots.enumerated() { solution[unknowns[col]] = clean(rows[r][n]) }
            return [solution]
        }
        // 비선형: 미지수 1개 또는 2개
        if n == 1 {
            let u = unknowns[0]
            guard let main = useful.max(by: { $0.degree(in: u) < $1.degree(in: u) }), let p = main.univariate(u), p.degree >= 1 else { return nil }
            let roots = DoitAlgebra.realRoots(p).map { clean($0.value) }
            let good = roots.filter { r in useful.allSatisfy { abs($0.evaluate([u: r]) ?? 1) < 1e-7 } }
            return good.map { [u: $0] }
        }
        guard n == 2 else { return nil }
        for e in useful where e.totalDegree(in: set) == 1 {
            for (index, u) in unknowns.enumerated() {
                let other = unknowns[1 - index]
                let coef = e.coefficient(u, 1)
                guard coef.letters.isEmpty, abs(coef.constantValue) > 1e-10 else { continue }
                // u = −(e − coef·u)/coef
                let rest = e - coef * GPoly.variable(u)
                let expression = rest.scaled(-1 / coef.constantValue)
                let reduced = useful.map { $0.substitute(u, expression) }.filter { !$0.isZero }
                guard let main = reduced.max(by: { $0.degree(in: other) < $1.degree(in: other) }), let p = main.univariate(other), p.degree >= 1 else { return nil }
                var out: [[Character: Double]] = []
                for r in DoitAlgebra.realRoots(p) {
                    let v = clean(r.value)
                    guard let uv = expression.evaluate([other: v]) else { continue }
                    let candidate: [Character: Double] = [other: v, u: clean(uv)]
                    if useful.allSatisfy({ abs($0.evaluate(candidate) ?? 1) < 1e-7 }) { out.append(candidate) }
                }
                return out
            }
        }
        return nil
    }

    private static func clean(_ v: Double) -> Double {
        if abs(v - v.rounded()) < 1e-9 { return v.rounded() == 0 ? 0 : v.rounded() }
        return v
    }

    // MARK: - 구할 상수 찾기

    private static let letterClass = "abcdkmnpq"

    /// "상수 a, b", "a, b의 값", "a + b의 값", "(단, a, b는 상수)" → [a, b]
    static func unknownLetters(_ t: String) -> [Character]? {
        let l = "[\(letterClass)]"
        var found = Set<Character>()
        for m in matches(t, "(?<![a-z])(\(l))\\s*,\\s*(\(l))(?:\\s*,\\s*(\(l)))?(?![a-z(])") {
            for g in m.dropFirst() where !g.isEmpty { if let c = g.first { found.insert(c) } }
        }
        if let asked = askedExpression(t) {
            for c in asked where letterClass.contains(c) { found.insert(c) }
        }
        if found.count >= 2 { return found.sorted() }
        return nil
    }

    /// 수식 속에 쓰인 상수 문자가 하나뿐이면 그 문자 (x² + kx + 3 = 0)
    private static func singleLetter(_ t: String) -> Character? {
        var found = Set<Character>()
        for run in runs(t) where run.text.contains("x") && run.text.contains("=") {
            for c in run.text where letterClass.contains(c) { found.insert(c) }
        }
        return found.count == 1 ? found.first : nil
    }

    /// 묻는 식 ("a + b의 값", "ab의 값") — 상수 문자만으로 된 것
    static func askedExpression(_ t: String) -> String? {
        let all = matches(t, #"([0-9a-z+\-*/^() ]*[a-z][0-9a-z+\-*/^() ]*)\s*의\s*값"#)
        guard let last = all.last else { return nil }
        let e = last[1].trimmingCharacters(in: .whitespaces)
        guard !e.isEmpty, e.allSatisfy({ letterClass.contains($0) || "0123456789+-*/^() ".contains($0) }) else { return nil }
        let letters = Set(e.filter { $0.isLetter })
        // 문자 하나만이면 (a의 값) 묻는 식이 아님
        guard letters.count >= 2 || e.count > 1 && e.contains(where: { "+-*/^".contains($0) }) else { return nil }
        return e
    }

    // MARK: - 문장 속 수식 조각

    struct Run {
        var text: String
        var range: Range<String.Index>
    }

    /// 수식으로 쓸 수 있는 글자가 이어진 조각들 (쉼표, 한글에서 끊음)
    static func runs(_ t: String) -> [Run] {
        let allowed = Set("0123456789.+-*/^=()√ <>≤≥'abcdefghijklmnopqrstuvwxyzπ")
        var out: [Run] = []
        var start: String.Index?
        var i = t.startIndex
        func commit(_ end: String.Index) {
            if let s = start {
                let piece = String(t[s..<end]).trimmingCharacters(in: .whitespaces)
                if !piece.isEmpty { out.append(Run(text: piece, range: s..<end)) }
            }
            start = nil
        }
        while i < t.endIndex {
            if allowed.contains(t[i]) { if start == nil { start = i } } else { commit(i) }
            i = t.index(after: i)
        }
        commit(t.endIndex)
        return out
    }

    // MARK: - 풀이

    struct Condition {
        var hint: String
        var eq: GPoly
    }

    static func solve(_ t: String) -> Solved? {
        if let s = limitConstants(t) { return s }
        if let s = continuity(t) { return s }
        // 복소수가 서로 같을 조건: "x + yi = (2 + i)(1 − i)를 만족시키는 실수 x, y"
        if let s = complexEquality(t) { return s }
        // 실수 x가 들어간 복소수: "z = (2 + 4i)(x − 8i)에 대하여 z²이 양의 실수가 되는 x를 a, 음의 실수가 되는 x를 b라 할 때 a + b"
        if let s = complexParameter(t) { return s }
        if let s = plainEquations(t) { return s }
        var found = unknownLetters(t)
        // 상수 하나라도, 한 근이 1 + √2, 2 + i 꼴이면 여기서 (켤레근)
        if found == nil, t.range(of: #"한\s*근(?:이|은|을)?\s*-?\d*(?:\.\d+)?\s*[+-]\s*\d*(?:\.\d+)?\s*(?:√|i(?![a-z]))"#, options: .regularExpression) != nil,
           let letter = DoitMathExact.parameterLetter(t) { found = [letter] }
        // "한 근이 1일 때, 다른 한 근은?"
        let asksOtherRoot = has(t, ["다른 한 근", "나머지 한 근", "다른 근"])
        if found == nil, asksOtherRoot, let letter = DoitMathExact.parameterLetter(t) ?? singleLetter(t) { found = [letter] }
        guard let unknowns = found else { return nil }
        let set = Set(unknowns)
        var vars = set
        vars.insert("x")
        let complexUnit = t.range(of: #"(?<![a-z])i(?![a-z])"#, options: .regularExpression) != nil
        if complexUnit { vars.insert("i") }
        let pieces = runs(t)

        // 함수 F(x) (y = …, f(x) = …) 또는 다항식
        var function: GPoly?
        var functionRun: Run?
        var equation: GPoly?
        var inequality: (GPoly, String)?
        var systemEquations: [GPoly] = []
        for run in pieces {
            var s = run.text
            var isFunction = false
            if let m = match(s, #"^(?:[fgPh]\s*\(\s*x\s*\)|y)\s*=\s*"#) {
                s = String(s.dropFirst(m[0].count))
                isFunction = true
            }
            guard s.contains(where: { set.contains($0) }) else { continue }
            let ops = ["<", ">", "≤", "≥"]
            if !isFunction, let op = ops.first(where: { s.contains($0) }) {
                let sides = s.components(separatedBy: op)
                guard sides.count == 2, let l = parse(sides[0], variables: vars), let r = parse(sides[1], variables: vars) else { continue }
                if inequality == nil { inequality = (l - r, op) }
                continue
            }
            if isFunction {
                guard function == nil, !s.contains("="), let p = parse(s, variables: vars) else { continue }
                function = p
                functionRun = run
                continue
            }
            let sides = s.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
            if sides.count == 2 {
                var withY = vars
                withY.insert("y")
                if let l = parse(sides[0], variables: withY), let r = parse(sides[1], variables: withY) {
                    let e = l - r
                    if e.letters.contains("y") { systemEquations.append(e) } else if equation == nil { equation = e }
                }
            } else if sides.count == 1, function == nil, s.contains("x"), let p = parse(s, variables: vars), p.degree(in: "x") >= 1 {
                function = p
                functionRun = run
            }
        }

        var conditions: [Condition] = []
        // 연립방정식의 해 (x = 2, y = 1) 또는 교점 (2, 3)
        if !systemEquations.isEmpty {
            var sol: (Double, Double)?
            if let m = match(t, "x\\s*=\\s*\(num)\\s*,\\s*y\\s*=\\s*\(num)"), let x = value(m[1]), let y = value(m[2]) { sol = (x, y) }
            else if has(t, ["교점"]), let p = DoitMathTopics.points(in: t).first { sol = (p.x, p.y) }
            guard let (x0, y0) = sol else { return nil }
            for e in systemEquations {
                let reduced = e.substitute("x", x0).substitute("y", y0)
                conditions.append(Condition(hint: "x = \(f(x0)), y = \(f(y0))를 대입하면", eq: reduced))
            }
        }
        if let F = function { conditions += functionConditions(F, t, functionRun: functionRun) }
        if let E = equation {
            if has(t, ["항등식", "모든 실수 x", "모든 x", "x의 값에 관계없이", "x에 대한 항등식"]) {
                let d = max(0, E.degree(in: "x"))
                for k in stride(from: d, through: 0, by: -1) {
                    let c = E.coefficient("x", k)
                    if !c.isZero { conditions.append(Condition(hint: k == 0 ? "상수항끼리 비교하면" : "x\(k == 1 ? "" : DoitMath.superscript(k))의 계수끼리 비교하면", eq: c)) }
                }
            } else {
                conditions += rootConditions(E, t)
            }
        }
        if let (E, op) = inequality, let s = inequalityConditions(E, op, t) { conditions += s }
        guard conditions.count >= unknowns.count else { return nil }
        guard let solutions = solveEquations(conditions.map(\.eq), unknowns: unknowns) else { return nil }
        let kept = filter(solutions, unknowns: unknowns, t)
        // 극값의 종류, 부등식의 방향을 확인
        let verified = kept.filter { verify($0, function: function, inequality: inequality, t) }
        guard !verified.isEmpty, verified.count <= 2 else { return nil }

        var steps = conditions.map { SolutionStep(hint: $0.hint, work: equationText($0.eq)) }
        let answers = verified.map { sol in unknowns.map { "\($0) = \(f(sol[$0] ?? 0))" }.joined(separator: ", ") }
        steps.append(SolutionStep(hint: "연립하여 풀면", work: answers.joined(separator: " 또는 ")))
        var answer = answers.joined(separator: " 또는 ")
        let kind: MathSolver.Kind = has(t, ["나머지", "나누어떨어"]) ? .remainder : has(t, ["극값", "극댓값", "극솟값", "접선"]) ? .derivative
            : equation != nil && has(t, ["항등식", "모든 실수"]) ? .expression : equation != nil ? .rootRelation : .system
        // 묻는 식 (a + b, ab, f(3))
        if verified.count == 1, let sol = verified.first, asksOtherRoot, let E = equation {
            // 구한 상수를 넣고 방정식을 풀어 주어진 근을 뺀 나머지
            var filled = E
            for (c, v) in sol { filled = filled.substitute(c, v) }
            guard let p = filled.univariate("x"), p.degree == 2, let m = match(t, "한\\s*근(?:이|은)\\s*\(num)"), let given = value(m[1]) else { return nil }
            let roots = DoitAlgebra.realRoots(p)
            let others = roots.filter { abs($0.value - given) > 1e-9 }
            let other: String
            if others.count == 1 { other = others[0].label }
            else if roots.count == 1 { other = roots[0].label }  // 중근
            else { return nil }
            steps.append(SolutionStep(hint: "\(DoitMath.describe(p)) = 0 을 풀면", work: roots.map(\.label).joined(separator: ", ")))
            let constants = unknowns.map { "\($0) = \(f(sol[$0] ?? 0))" }.joined(separator: ", ")
            return Solved(kind: .quadraticEquation, topic: "한 근이 주어진 이차방정식", concept: "주어진 근을 대입해 상수를 구한 뒤, 방정식을 풀어 다른 근을 찾아요. (근과 계수의 관계를 써도 돼요)",
                          steps: steps, answer: has(t, ["값과", "와 다른", "과 다른"]) ? "\(constants), 다른 한 근 \(other)" : "다른 한 근 \(other)")
        }
        if verified.count == 1, let sol = verified.first {
            if let asked = askedExpression(t), let p = parse(asked, variables: set), let v = p.evaluate(sol) {
                let shown = pretty(asked)
                steps.append(SolutionStep(hint: "\(shown)의 값은", work: "\(shown) = \(f(clean(v)))"))
                answer = "\(shown) = \(f(clean(v)))"
            } else if let F = function, let m = match(t, "f\\s*\\(\\s*\(num)\\s*\\)\\s*의\\s*값"), let x0 = value(m[1]) {
                let filled = F.substitute("x", x0)
                if let v = filled.evaluate(sol) {
                    steps.append(SolutionStep(hint: "f(\(f(x0)))에 대입하면", work: "f(\(f(x0))) = \(f(clean(v)))"))
                    answer = "f(\(f(x0))) = \(f(clean(v)))"
                }
            }
        }
        return Solved(kind: kind, topic: "상수 구하기 (연립)",
                      concept: "주어진 조건마다 상수에 대한 식을 하나씩 세워요. 모르는 상수가 n개면 식도 n개가 필요하고, 연립해서 풀어요.",
                      steps: steps, answer: answer)
    }

    private static func pretty(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "*", with: "×").replacingOccurrences(of: "-", with: " − ").replacingOccurrences(of: "+", with: " + ")
        out = out.replacingOccurrences(of: "^2", with: "²").replacingOccurrences(of: "^3", with: "³")
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// "양수 a", "a > 0", "a, b는 자연수"
    private static func filter(_ sols: [[Character: Double]], unknowns: [Character], _ t: String) -> [[Character: Double]] {
        var out = sols
        for u in unknowns {
            let n = String(u)
            if has(t, ["양수 \(n)", "\(n) > 0", "\(n)>0", "양의 상수 \(n)"]) { out = out.filter { ($0[u] ?? 0) > 1e-12 } }
            if has(t, ["음수 \(n)", "\(n) < 0", "\(n)<0"]) { out = out.filter { ($0[u] ?? 0) < -1e-12 } }
        }
        if t.range(of: "[\(letterClass)]\\s*,\\s*[\(letterClass)]\\s*(?:는|은)\\s*양수", options: .regularExpression) != nil {
            out = out.filter { s in unknowns.allSatisfy { (s[$0] ?? 0) > 1e-12 } }
        }
        if t.range(of: "(?:자연수|정수)\\s*[\(letterClass)]\\s*,", options: .regularExpression) != nil
            || t.range(of: "[\(letterClass)]\\s*,\\s*[\(letterClass)]\\s*(?:는|은)\\s*(?:자연수|정수)", options: .regularExpression) != nil {
            out = out.filter { s in unknowns.allSatisfy { abs((s[$0] ?? 0) - (s[$0] ?? 0).rounded()) < 1e-9 } }
        }
        return out
    }

    private static func verify(_ sol: [Character: Double], function: GPoly?, inequality: (GPoly, String)?, _ t: String) -> Bool {
        if let F = function {
            let second = F.derivative("x").derivative("x")
            for m in matches(t, "x\\s*=\\s*\(num)\\s*에서\\s*(극댓값|극솟값|극대|극소)") {
                guard let x0 = value(m[1]) else { continue }
                var s = sol
                s["x"] = x0
                guard let v = second.evaluate(s) else { return false }
                if m[2].hasPrefix("극대") && v >= -1e-12 { return false }
                if m[2].hasPrefix("극소") && v <= 1e-12 { return false }
            }
        }
        if let (E, op) = inequality {
            guard let lead = E.coefficient("x", 2).evaluate(sol) else { return false }
            let inside = match(t, "해가\\s*\(num)\\s*[<≤]\\s*x\\s*[<≤]\\s*\(num)") != nil
            let negativeSide = op == "<" || op == "≤"
            // 두 근 사이가 해: (아래로 볼록, < 0) 또는 (위로 볼록, > 0)
            let needPositive = inside == negativeSide
            if needPositive && lead <= 1e-12 { return false }
            if !needPositive && lead >= -1e-12 { return false }
        }
        return true
    }

    // MARK: - 함수 조건 (지나는 점, 함숫값, 절편, 기울기, 접선, 극값, 꼭짓점, 나머지)

    private static func functionConditions(_ F: GPoly, _ t: String, functionRun: Run?) -> [Condition] {
        var out: [Condition] = []
        let derivative = F.derivative("x")
        func at(_ x0: Double) -> GPoly { F.substitute("x", x0) }
        func slopeAt(_ x0: Double) -> GPoly { derivative.substitute("x", x0) }
        let pts = DoitMathTopics.points(in: t)
        var vertex: DoitMathTopics.Point?
        if has(t, ["꼭짓점"]), let m = match(t, "꼭짓점(?:의\\s*좌표)?(?:가|이|은|는)?\\s*\\(\\s*\(num)\\s*,\\s*\(num)\\s*\\)"), let x0 = value(m[1]), let y0 = value(m[2]) {
            vertex = DoitMathTopics.Point(x: x0, y: y0)
            out.append(Condition(hint: "꼭짓점의 x좌표 \(f(x0))에서 기울기가 0 (f'(\(f(x0))) = 0)", eq: slopeAt(x0)))
            out.append(Condition(hint: "꼭짓점 (\(f(x0)), \(f(y0)))을 지나므로", eq: at(x0) - GPoly.constant(y0)))
        }
        if has(t, ["지나", "지날", "위의 점", "위에 있", "에서의 접선", "에서 만나", "에서 만날", "에서 만난"]) {
            for p in pts where !(vertex.map { abs($0.x - p.x) < 1e-12 && abs($0.y - p.y) < 1e-12 } ?? false) {
                out.append(Condition(hint: "점 \(p.label)을 지나므로 x = \(f(p.x))을 넣으면 \(f(p.y))", eq: at(p.x) - GPoly.constant(p.y)))
            }
        }
        for m in matches(t, "f\\s*\\(\\s*\(num)\\s*\\)\\s*=\\s*\(num)") {
            guard let x0 = value(m[1]), let y0 = value(m[2]) else { continue }
            out.append(Condition(hint: "f(\(f(x0))) = \(f(y0))", eq: at(x0) - GPoly.constant(y0)))
        }
        for m in matches(t, "f'\\s*\\(\\s*\(num)\\s*\\)\\s*=\\s*\(num)") {
            guard let x0 = value(m[1]), let y0 = value(m[2]) else { continue }
            out.append(Condition(hint: "f'(\(f(x0))) = \(f(y0))", eq: slopeAt(x0) - GPoly.constant(y0)))
        }
        if let m = match(t, "y\\s*절편(?:이|은|는|가)\\s*\(num)"), let v = value(m[1]) {
            out.append(Condition(hint: "y절편이 \(f(v))이므로 x = 0일 때 y = \(f(v))", eq: at(0) - GPoly.constant(v)))
        }
        if let m = match(t, "x\\s*절편(?:이|은|는|가)\\s*\(num)"), let v = value(m[1]) {
            out.append(Condition(hint: "x절편이 \(f(v))이므로 x = \(f(v))일 때 y = 0", eq: at(v)))
        }
        // 접선의 기울기
        if let m = match(t, "접선의\\s*기울기(?:가|는|이)\\s*\(num)"), let slope = value(m[1]) {
            var x0: Double?
            if let mm = match(t, "x\\s*=\\s*\(num)\\s*(?:인\\s*점)?에서의?\\s*접선"), let v = value(mm[1]) { x0 = v }
            else if let mm = match(t, "\\(\\s*\(num)\\s*,\\s*\(num)\\s*\\)\\s*에서의?\\s*접선"), let v = value(mm[1]) { x0 = v }
            if let x0 { out.append(Condition(hint: "x = \(f(x0))에서의 접선의 기울기 f'(\(f(x0))) = \(f(slope))", eq: slopeAt(x0) - GPoly.constant(slope))) }
        } else if F.degree(in: "x") == 1, let m = match(t, "기울기(?:가|는|이)\\s*\(num)"), let slope = value(m[1]) {
            out.append(Condition(hint: "x의 계수가 기울기", eq: F.coefficient("x", 1) - GPoly.constant(slope)))
        }
        // 극값: "x = 1에서 극솟값 −2", "x = −1에서 극댓값을 갖고"
        for m in matches(t, "x\\s*=\\s*\(num)\\s*에서\\s*(?:극댓값|극솟값|극값|극대|극소)(?:\\s*(?:이|은|으로|을|를|가)?\\s*\(num)(?![0-9]))?") {
            guard let x0 = value(m[1]) else { continue }
            out.append(Condition(hint: "x = \(f(x0))에서 극값을 가지므로 f'(\(f(x0))) = 0", eq: slopeAt(x0)))
            if !m[2].isEmpty, let v = value(m[2]) {
                out.append(Condition(hint: "극값이 \(f(v))이므로 f(\(f(x0))) = \(f(v))", eq: at(x0) - GPoly.constant(v)))
            }
        }
        out += remainderConditions(F, t, functionRun: functionRun)
        return out
    }

    /// x − 1로 나눈 나머지가 2, x + 2로 나누어떨어짐, x² − 3x + 2로 나누어떨어짐
    private static func remainderConditions(_ F: GPoly, _ t: String, functionRun: Run?) -> [Condition] {
        var out: [Condition] = []
        func at(_ x0: Double) -> GPoly { F.substitute("x", x0) }
        let linear = #"(\d*)\s*x\s*([+-])\s*(\d+(?:\.\d+)?)"#
        func root(_ m: [String], from i: Int) -> Double? {
            guard let b = Double(m[i + 2]) else { return nil }
            let a = Double(m[i]) ?? 1
            guard a != 0 else { return nil }
            return (m[i + 1] == "-" ? b : -b) / a
        }
        for m in matches(t, linear + #"\s*(?:으로|로)\s*나[누눈][^0-9\-]{0,15}?나머지(?:가|는|를)\s*"# + num) {
            guard let r = root(m, from: 1), let v = value(m[4]) else { continue }
            out.append(Condition(hint: "나머지정리: x = \(f(r))을 넣은 값이 나머지 \(f(v))", eq: at(r) - GPoly.constant(v)))
        }
        guard let cut = t.range(of: "나누어떨어") ?? t.range(of: "인수로") ?? t.range(of: "인수를") else { return out }
        var segment = String(t[..<cut.lowerBound])
        if let run = functionRun, run.range.upperBound <= cut.lowerBound { segment = String(t[run.range.upperBound..<cut.lowerBound]) }
        // "x − 1로 나눈 나머지가 2이고 x + 2로 나누어떨어질 때": 나머지 조건 뒤만
        if let last = matches(segment, #"나머지(?:가|는|를)\s*-?\d+(?:\.\d+)?"#).last?[0], let r = segment.range(of: last, options: .backwards) {
            segment = String(segment[r.upperBound...])
        }
        // 이차식으로 나누어떨어짐
        if segment.contains("x^2") || segment.contains(")(") {
            let candidates = runs(segment).filter { $0.text.contains("x") }
            if let last = candidates.last, let p = parse(last.text, variables: ["x"])?.univariate("x"), p.degree == 2 {
                let roots = DoitAlgebra.realRoots(p)
                guard roots.count == 2 else { return out }
                for r in roots { out.append(Condition(hint: "\(DoitMath.describe(p))로 나누어떨어지므로 f(\(r.label)) = 0", eq: at(r.value))) }
                return out
            }
        }
        for m in matches(segment, linear + #"\s*(?=,|와|과|및|으로|로)"#) {
            guard let r = root(m, from: 1) else { continue }
            out.append(Condition(hint: "x − (\(f(r)))로 나누어떨어지므로 f(\(f(r))) = 0", eq: at(r)))
        }
        return out
    }

    // MARK: - 방정식의 근 조건

    private static func rootConditions(_ E: GPoly, _ t: String) -> [Condition] {
        var out: [Condition] = []
        func at(_ x0: Double) -> GPoly { E.substitute("x", x0) }
        if let m = match(t, "두\\s*근(?:이|은|을)?\\s*(?:각각\\s*)?\(num)\\s*(?:,|와|과|및)\\s*\(num)(?![0-9])"), let r1 = value(m[1]), let r2 = value(m[2]) {
            out.append(Condition(hint: "x = \(f(r1))이 근이므로 대입하면", eq: at(r1)))
            out.append(Condition(hint: "x = \(f(r2))이 근이므로 대입하면", eq: at(r2)))
            return out
        }
        if let m = match(t, #"한\s*근(?:이|은|을)?\s*(-?\d*(?:\.\d+)?)\s*([+-])\s*(\d*(?:\.\d+)?)\s*(√\s*\d+|i)"#) {
            let p = Double(m[1]) ?? (m[1] == "-" ? -0.0 : 0)
            let q = (Double(m[3]) ?? 1) * (m[2] == "-" ? -1 : 1)
            if m[4] == "i" {
                // 계수가 실수면 켤레복소수도 근: x = p + qi 를 넣고 실수부, 허수부 = 0
                let z = GPoly.constant(p) + GPoly.constant(q) * GPoly.variable("i")
                let filled = E.substitute("x", z)
                out.append(Condition(hint: "x = \(f(p)) + \(f(q))i를 대입한 식의 실수부분 = 0", eq: filled.coefficient("i", 0)))
                out.append(Condition(hint: "허수부분 = 0", eq: filled.coefficient("i", 1)))
            } else if let r = Double(m[4].replacingOccurrences(of: "√", with: "").trimmingCharacters(in: .whitespaces)) {
                // 계수가 유리수면 p − q√r도 근
                let s = q * r.squareRoot()
                out.append(Condition(hint: "x = \(f(p)) + \(f(q))√\(f(r))가 근이고, 계수가 유리수이므로 \(f(p)) − \(f(q))√\(f(r))도 근 → 두 근의 합", eq: at(p + s) + at(p - s)))
                out.append(Condition(hint: "두 근을 넣은 값의 차도 0", eq: (at(p + s) - at(p - s)).scaled(1 / (2 * s))))
            }
            return out
        }
        if let m = match(t, "한\\s*근(?:이|은)\\s*(?:x\\s*=\\s*)?\(num)(?![0-9.])(?!\\s*[+-]\\s*\\d*\\s*(?:√|i))"), let r = value(m[1]) {
            out.append(Condition(hint: "x = \(f(r))이 근이므로 대입하면", eq: at(r)))
        }
        if E.degree(in: "x") == 2 {
            let a = E.coefficient("x", 2), b = E.coefficient("x", 1), c = E.coefficient("x", 0)
            if let m = match(t, "합(?:이|은|는)\\s*\(num)"), let s = value(m[1]) {
                out.append(Condition(hint: "두 근의 합 −b/a = \(f(s))", eq: b + a.scaled(s)))
            }
            if let m = match(t, "곱(?:이|은|는)\\s*\(num)"), let p = value(m[1]) {
                out.append(Condition(hint: "두 근의 곱 c/a = \(f(p))", eq: c - a.scaled(p)))
            }
        }
        return out
    }

    private static func inequalityConditions(_ E: GPoly, _ op: String, _ t: String) -> [Condition]? {
        guard E.degree(in: "x") == 2 else { return nil }
        var roots: (Double, Double)?
        if let m = match(t, "해가\\s*\(num)\\s*[<≤]\\s*x\\s*[<≤]\\s*\(num)"), let p = value(m[1]), let q = value(m[2]) { roots = (p, q) }
        else if let m = match(t, "해가\\s*x\\s*[<≤]\\s*\(num)\\s*또는\\s*x\\s*[>≥]\\s*\(num)"), let p = value(m[1]), let q = value(m[2]) { roots = (p, q) }
        guard let (p, q) = roots, p < q else { return nil }
        return [Condition(hint: "해의 경계 x = \(f(p))은 이차방정식의 근", eq: E.substitute("x", p)),
                Condition(hint: "해의 경계 x = \(f(q))도 근", eq: E.substitute("x", q))]
    }

    // MARK: - 문자만으로 된 식들: "a + b = 5, ab = 6일 때 a² + b²", "x + y = 5, xy = 6일 때 x² + y²"

    private static func plainEquations(_ t: String) -> Solved? {
        guard let asked = askedExpression(t) ?? askedXY(t) else { return nil }
        let letters = Set(asked.filter { $0.isLetter })
        guard (1...3).contains(letters.count) else { return nil }
        var eqs: [GPoly] = []
        var shown: [String] = []
        for run in runs(t) where run.text.contains("=") {
            let sides = run.text.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
            guard sides.count == 2 else { continue }
            let used = Set(run.text.filter { $0.isLetter })
            guard !used.isEmpty, used.isSubset(of: letters), let l = parse(sides[0], variables: letters), let r = parse(sides[1], variables: letters) else { continue }
            eqs.append(l - r)
            shown.append(run.text)
        }
        let unknowns = letters.sorted()
        guard eqs.count >= unknowns.count, eqs.contains(where: { $0.totalDegree(in: letters) >= 2 }),
              let sols = solveEquations(eqs, unknowns: unknowns), !sols.isEmpty, sols.count <= 4,
              let target = parse(asked, variables: letters) else { return nil }
        let values = sols.compactMap { target.evaluate($0) }
        guard values.count == sols.count, let v = values.first, values.allSatisfy({ abs($0 - v) < 1e-7 * max(1, abs(v)) }) else { return nil }
        let shownAsked = pretty(asked)
        let pairs = sols.map { s in unknowns.map { "\($0) = \(f(s[$0] ?? 0))" }.joined(separator: ", ") }
        return Solved(kind: .expression, topic: "곱셈 공식의 변형 (식의 값)",
                      concept: "a² + b² = (a + b)² − 2ab, (a − b)² = (a + b)² − 4ab 처럼 주어진 합·곱으로 바꿔 계산해요.",
                      steps: [SolutionStep(hint: "주어진 식", work: shown.map(pretty).joined(separator: ", ")),
                              SolutionStep(hint: "두 식을 만족하는 값 (어느 쪽이든 결과는 같아요)", work: pairs.joined(separator: " 또는 ")),
                              SolutionStep(hint: "\(shownAsked)에 넣으면", work: "\(shownAsked) = \(f(clean(v)))")],
                      answer: "\(shownAsked) = \(f(clean(v)))")
    }

    /// x, y로 된 묻는 식 ("x² + y²의 값", "xy의 값")
    private static func askedXY(_ t: String) -> String? {
        let all = matches(t, #"([0-9xy+\-*/^() ]*[xy][0-9xy+\-*/^() ]*)\s*의\s*값"#)
        guard let last = all.last else { return nil }
        let e = last[1].trimmingCharacters(in: .whitespaces)
        guard Set(e.filter { $0.isLetter }).count == 2, e.contains(where: { "+-*/^".contains($0) }) || e == "xy" else { return nil }
        return e
    }

    // MARK: - 실수 x가 들어간 복소수의 조건 (실수 · 순허수 · 양/음의 실수, z와 z²)

    /// "양의 실수" · "양수" → "양의실수"
    private static func kindName(_ raw: String) -> String {
        let k = raw.replacingOccurrences(of: " ", with: "")
        return k == "양수" ? "양의실수" : k == "음수" ? "음의실수" : k
    }

    private static func complexParameter(_ t: String) -> Solved? {
        guard t.range(of: #"(?<![a-z])i(?![a-z])"#, options: .regularExpression) != nil,
              let def = match(t, #"(?<![a-z])([a-hj-z])\s*=\s*([0-9a-z+\-*/^()\s.]+?)\s*(?=[가-힣,]|$)"#),
              let name = def[1].first else { return nil }
        let exprText = def[2].trimmingCharacters(in: .whitespaces)
        let letters = Set(exprText.filter { $0.isLetter && $0 != "i" })
        guard exprText.contains("i"), letters.count == 1, let u = letters.first, u != name else { return nil }
        guard let Z = parse(exprText, variables: [u, "i"]), Z.degree(in: "i") <= 1 else { return nil }
        let R = Z.coefficient("i", 0), I = Z.coefficient("i", 1)
        guard R.letters.isSubset(of: [u]), I.letters.isSubset(of: [u]), !(R.letters.isEmpty && I.letters.isEmpty) else { return nil }
        let n = String(name)
        // z² · z^2 · z^{2} · (위 첨자를 놓쳐) z2
        let target = "(\(n)\\s*\\^\\s*\\{?\\s*2\\s*\\}?|\(n)²|\(n)2(?![0-9])|\(n))"
        let kind = #"(양의\s*실수|음의\s*실수|순허수|실수|양수|음수)"#
        // 조건 하나: (z 또는 z², 무엇이 되는지, 값을 담을 문자)
        var clauses: [(squared: Bool, kind: String, letter: Character?)] = []
        for m in matches(t, target + #"\s*(?:의\s*값)?\s*(?:이|가)\s*"# + kind + #"[^,.]*?값을\s*([a-z])(?![a-z])"#) {
            clauses.append((m[1] != n, kindName(m[2]), m[3].first))
        }
        if clauses.isEmpty, let m = match(t, target + #"\s*(?:의\s*값)?\s*(?:이|가)\s*"# + kind) {
            clauses.append((m[1] != n, kindName(m[2]), nil))
        }
        // 식 바로 뒤에 조건: "z = (1 + i)x + 2 − 3i가 실수가 되도록"
        if clauses.isEmpty, let m = match(t, #"[0-9i)]\s*(?:이|가|은|는)\s*"# + kind) {
            clauses.append((false, kindName(m[1]), nil))
        }
        guard !clauses.isEmpty else { return nil }

        func solveFor(_ eq: GPoly) -> [Double] {
            guard let sols = solveEquations([eq], unknowns: [u]) else { return [] }
            return sols.compactMap { $0[u] }
        }
        func at(_ p: GPoly, _ v: Double) -> Double { p.evaluate([u: v]) ?? .nan }
        var steps = [SolutionStep(hint: "i² = −1을 써서 \(n)를 a + bi 꼴로 정리하면", work: "\(n) = (\(describe(R))) + (\(describe(I)))i",
                                  concept: "실수부분과 허수부분으로 나누어 조건을 따져요.")]
        var values: [Character: Double] = [:]
        var single: Double?
        for clause in clauses {
            let what = clause.squared ? "\(n)²" : n
            var found: [Double]
            var why: String
            switch (clause.squared, clause.kind) {
            case (false, "실수"):
                found = solveFor(I); why = "\(n)가 실수 → 허수부분 = 0"
            case (false, "순허수"):
                found = solveFor(R).filter { abs(at(I, $0)) > 1e-9 }; why = "\(n)가 순허수 → 실수부분 = 0, 허수부분 ≠ 0"
            case (false, "양의실수"):
                found = solveFor(I).filter { at(R, $0) > 1e-9 }; why = "\(n)가 양의 실수 → 허수부분 = 0, 실수부분 > 0"
            case (false, "음의실수"):
                found = solveFor(I).filter { at(R, $0) < -1e-9 }; why = "\(n)가 음의 실수 → 허수부분 = 0, 실수부분 < 0"
            case (true, "양의실수"):
                found = solveFor(I).filter { abs(at(R, $0)) > 1e-9 }; why = "\(n)²이 양의 실수 → \(n)가 0이 아닌 실수 → 허수부분 = 0, 실수부분 ≠ 0"
            case (true, "음의실수"):
                found = solveFor(R).filter { abs(at(I, $0)) > 1e-9 }; why = "\(n)²이 음의 실수 → \(n)가 순허수 → 실수부분 = 0, 허수부분 ≠ 0"
            case (true, "실수"):
                found = solveFor(R) + solveFor(I); why = "\(n)²이 실수 → 실수부분 = 0 또는 허수부분 = 0"
            default:
                return nil
            }
            var uniq: [Double] = []
            for v in found where !uniq.contains(where: { abs($0 - v) < 1e-9 }) { uniq.append(v) }
            guard !uniq.isEmpty else { return nil }
            let shown = uniq.map { "\(u) = \(f(clean($0)))" }.joined(separator: " 또는 ")
            steps.append(SolutionStep(hint: why, work: shown + (clause.letter.map { " → \($0) = \(uniq.count == 1 ? f(clean(uniq[0])) : "?")" } ?? "")))
            if let letter = clause.letter {
                guard uniq.count == 1 else { return nil }
                values[letter] = uniq[0]
            } else if clauses.count == 1, uniq.count == 1 {
                single = uniq[0]
            } else if clauses.count == 1 {
                return Solved(kind: .complex, topic: "복소수가 실수·순허수가 될 조건", concept: "a + bi에서 실수는 b = 0, 순허수는 a = 0이고 b ≠ 0이에요.",
                              steps: steps, answer: shown)
            }
            _ = what
        }
        var answer: String
        // 묻는 식의 문자를 다 구하지 못했으면 (조건 하나를 못 읽음) 반쪽 답을 내지 않음
        if let asked = askedExpression(t), !values.isEmpty {
            let needed = Set(asked.filter { $0.isLetter })
            guard needed.isSubset(of: Set(values.keys)) else { return nil }
        }
        if let asked = askedExpression(t), !values.isEmpty, let p = parse(asked, variables: Set(values.keys)), let v = p.evaluate(values) {
            steps.append(SolutionStep(hint: "\(pretty(asked))의 값은", work: "\(pretty(asked)) = \(f(clean(v)))"))
            answer = f(clean(v))
        } else if let single {
            answer = "\(u) = \(f(clean(single)))"
        } else if !values.isEmpty {
            answer = values.keys.sorted().map { "\($0) = \(f(clean(values[$0]!)))" }.joined(separator: ", ")
        } else {
            return nil
        }
        return Solved(kind: .complex, topic: "복소수가 실수·순허수가 될 조건",
                      concept: "z = a + bi일 때 z²이 양의 실수 ⇔ z가 0이 아닌 실수(b = 0), z²이 음의 실수 ⇔ z가 순허수(a = 0, b ≠ 0)예요.",
                      steps: steps, answer: answer)
    }

    // MARK: - 복소수가 서로 같을 조건

    private static func complexEquality(_ t: String) -> Solved? {
        guard t.range(of: #"(?<![a-z])i(?![a-z])"#, options: .regularExpression) != nil,
              let m = match(t, #"실수\s*([a-z])\s*,\s*([a-z])"#), let u1 = m[1].first, let u2 = m[2].first, u1 != "i", u2 != "i" else { return nil }
        let unknowns = [u1, u2].sorted()
        let vars: Set<Character> = [u1, u2, "i"]
        var target: GPoly?
        for run in runs(t) where run.text.contains("=") && run.text.contains("i") {
            let sides = run.text.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
            guard sides.count == 2, let l = parse(sides[0], variables: vars), let r = parse(sides[1], variables: vars) else { continue }
            let e = l - r
            guard !e.letters.intersection([u1, u2]).isEmpty else { continue }
            target = e
            break
        }
        guard let e = target else { return nil }
        let real = e.coefficient("i", 0), imag = e.coefficient("i", 1)
        guard e.degree(in: "i") <= 1, let sols = solveEquations([real, imag], unknowns: unknowns), sols.count == 1, let sol = sols.first else { return nil }
        let answer = unknowns.map { "\($0) = \(f(sol[$0] ?? 0))" }.joined(separator: ", ")
        var steps = [SolutionStep(hint: "실수부분끼리 같아야 하므로", work: equationText(real)),
                     SolutionStep(hint: "허수부분끼리 같아야 하므로", work: equationText(imag)),
                     SolutionStep(hint: "연립하여 풀면", work: answer)]
        var out = answer
        if let asked = askedExpression(t), let p = parse(asked, variables: [u1, u2]), let v = p.evaluate(sol) {
            steps.append(SolutionStep(hint: "\(pretty(asked))의 값은", work: f(clean(v))))
            out = "\(pretty(asked)) = \(f(clean(v)))"
        }
        return Solved(kind: .complex, topic: "복소수가 서로 같을 조건", concept: "a, b, c, d가 실수일 때 a + bi = c + di 이면 a = c, b = d (실수부분끼리, 허수부분끼리 같아요).",
                      steps: steps, answer: out)
    }

    // MARK: - 극한이 주어진 상수: lim x→p N(x)/D(x) = L

    /// lim x→∞ N(x)/D(x) = L (L ≠ 0): D의 차수보다 높은 N의 항은 0, 같은 차수 계수의 비 = L
    private static func limitAtInfinity(_ t: String) -> Solved? {
        guard let m = match(t, "lim\\s*_?[({]?\\s*x\\s*(?:→|->)\\s*∞\\s*[)}]?\\s*(.+?)\\s*=\\s*\(num)(?![0-9])"), let L = value(m[2]), abs(L) > 1e-12 else { return nil }
        let letters = Set(m[1].filter { letterClass.contains($0) })
        guard !letters.isEmpty, letters.count <= 2 else { return nil }
        var vars = letters
        vars.insert("x")
        guard let (nText, dText) = splitFraction(m[1]), let N = parse(nText, variables: vars), let D = parse(dText, variables: vars), D.letters.isSubset(of: ["x"]) else { return nil }
        let dm = D.degree(in: "x")
        let lead = D.coefficient("x", dm).constantValue
        guard dm >= 0, abs(lead) > 1e-12 else { return nil }
        var conditions: [Condition] = []
        let top = N.degree(in: "x")
        if top > dm {
            for k in stride(from: top, to: dm, by: -1) { conditions.append(Condition(hint: "극한값이 있으려면 x\(DoitMath.superscript(k))의 계수는 0", eq: N.coefficient("x", k))) }
        }
        conditions.append(Condition(hint: "분모와 같은 차수의 계수의 비가 극한값", eq: N.coefficient("x", dm) - GPoly.constant(L * lead)))
        let unknowns = letters.sorted()
        guard conditions.count >= unknowns.count, let sols = solveEquations(conditions.map(\.eq), unknowns: unknowns), sols.count == 1, let sol = sols.first else { return nil }
        let answer = unknowns.map { "\($0) = \(f(sol[$0] ?? 0))" }.joined(separator: ", ")
        var steps = conditions.map { SolutionStep(hint: $0.hint, work: equationText($0.eq)) }
        steps.append(SolutionStep(hint: "풀면", work: answer))
        var out = answer
        if let asked = askedExpression(t), let e = parse(asked, variables: letters), let v = e.evaluate(sol) {
            steps.append(SolutionStep(hint: "\(pretty(asked))의 값은", work: f(clean(v))))
            out = "\(pretty(asked)) = \(f(clean(v)))"
        }
        return Solved(kind: .function, topic: "x → ∞ 일 때의 극한과 상수", concept: "(다항식)/(다항식)의 x → ∞ 극한은 최고차항끼리 비교해요. 분자의 차수가 더 높으면 발산, 같으면 최고차항 계수의 비, 낮으면 0",
                      steps: steps, answer: out)
    }

    private static func limitConstants(_ t: String) -> Solved? {
        if t.contains("∞") { return limitAtInfinity(t) }
        guard t.contains("lim"), let m = match(t, "lim\\s*_?\\(?\\s*x\\s*(?:→|->)\\s*\(num)\\s*\\)?\\s*(.+?)\\s*=\\s*\(num)(?![0-9])"),
              let p = value(m[1]), let L = value(m[3]) else { return nil }
        let letters = Set(m[2].filter { letterClass.contains($0) })
        guard !letters.isEmpty, letters.count <= 2 else { return nil }
        let unknowns = letters.sorted()
        var vars = letters
        vars.insert("x")
        guard let (nText, dText) = splitFraction(m[2]), let N = parse(nText, variables: vars), let D = parse(dText, variables: vars),
              D.letters.isSubset(of: ["x"]) else { return nil }
        guard let dp = D.substitute("x", p).evaluate([:]) else { return nil }
        var conditions: [Condition] = []
        if abs(dp) < 1e-12 {
            guard let d1 = D.derivative("x").substitute("x", p).evaluate([:]), abs(d1) > 1e-12 else { return nil }
            conditions.append(Condition(hint: "x → \(f(p))일 때 (분모) → 0 이고 극한값이 있으므로 (분자) → 0", eq: N.substitute("x", p)))
            conditions.append(Condition(hint: "분자를 (x − \(f(p)))로 묶어 약분하면 극한값 = (분자의 미분계수)/(분모의 미분계수) = \(f(L))",
                                        eq: N.derivative("x").substitute("x", p) - GPoly.constant(L * d1)))
        } else {
            conditions.append(Condition(hint: "분모가 0이 아니므로 x = \(f(p))을 그대로 대입", eq: N.substitute("x", p) - GPoly.constant(L * dp)))
        }
        guard conditions.count >= unknowns.count, let sols = solveEquations(conditions.map(\.eq), unknowns: unknowns), sols.count == 1, let sol = sols.first else { return nil }
        let answer = unknowns.map { "\($0) = \(f(sol[$0] ?? 0))" }.joined(separator: ", ")
        var steps = conditions.map { SolutionStep(hint: $0.hint, work: equationText($0.eq)) }
        steps.append(SolutionStep(hint: "연립하여 풀면", work: answer))
        var out = answer
        if let asked = askedExpression(t), let e = parse(asked, variables: letters), let v = e.evaluate(sol) {
            steps.append(SolutionStep(hint: "\(pretty(asked))의 값은", work: f(clean(v))))
            out = "\(pretty(asked)) = \(f(clean(v)))"
        }
        return Solved(kind: .function, topic: "극한값이 주어질 때 상수 구하기", concept: "lim (분자/분모)가 수렴하고 (분모) → 0 이면 (분자) → 0 이어야 해요. 그다음 약분해서 극한값을 구해요.",
                      steps: steps, answer: out)
    }

    /// "(x^2 + ax + b)/(x - 1)" → ("x^2 + ax + b", "x - 1") (맨 바깥의 / 하나)
    static func splitFraction(_ s: String) -> (String, String)? {
        var depth = 0
        var index: String.Index?
        for i in s.indices {
            switch s[i] {
            case "(": depth += 1
            case ")": depth -= 1
            case "/" where depth == 0: if index == nil { index = i } else { return nil }
            default: break
            }
        }
        guard let cut = index else { return nil }
        func strip(_ x: Substring) -> String {
            var v = x.trimmingCharacters(in: .whitespaces)
            if v.hasPrefix("("), v.hasSuffix(")") { v = String(v.dropFirst().dropLast()) }
            return v
        }
        return (strip(s[..<cut]), strip(s[s.index(after: cut)...]))
    }

    // MARK: - 연속 · 미분가능 조건 (구간별로 정의된 함수)

    private static func continuity(_ t: String) -> Solved? {
        guard has(t, ["연속", "미분가능"]) else { return nil }
        let pieces = matches(t, "([^,{}\\n]+?)\\s*\\(\\s*x\\s*([<>≤≥])\\s*\(num)\\s*\\)")
        guard pieces.count == 2, let p1 = value(pieces[0][3]), let p2 = value(pieces[1][3]), abs(p1 - p2) < 1e-12 else { return nil }
        let letters = Set(pieces.flatMap { $0[1].filter { letterClass.contains($0) } })
        guard !letters.isEmpty, letters.count <= 2 else { return nil }
        var vars = letters
        vars.insert("x")
        func expression(_ raw: String) -> GPoly? {
            var s = raw
            if let r = s.range(of: "=") { s = String(s[r.upperBound...]) }
            return parse(s.trimmingCharacters(in: .whitespaces), variables: vars)
        }
        guard let left = expression(pieces[0][1]), let right = expression(pieces[1][1]) else { return nil }
        var conditions = [Condition(hint: "x = \(f(p1))에서 연속이려면 두 식의 값이 같아야 해요", eq: left.substitute("x", p1) - right.substitute("x", p1))]
        if has(t, ["미분가능"]) {
            conditions.append(Condition(hint: "미분가능하려면 두 식의 미분계수도 같아야 해요", eq: left.derivative("x").substitute("x", p1) - right.derivative("x").substitute("x", p1)))
        }
        let unknowns = letters.sorted()
        guard conditions.count >= unknowns.count, let sols = solveEquations(conditions.map(\.eq), unknowns: unknowns), sols.count == 1, let sol = sols.first else { return nil }
        let answer = unknowns.map { "\($0) = \(f(sol[$0] ?? 0))" }.joined(separator: ", ")
        var steps = conditions.map { SolutionStep(hint: $0.hint, work: equationText($0.eq)) }
        steps.append(SolutionStep(hint: "풀면", work: answer))
        return Solved(kind: .function, topic: "함수의 연속", concept: "구간별로 정의된 함수가 x = a에서 연속이려면 lim(x→a−) f(x) = lim(x→a+) f(x) = f(a). 미분가능하면 양쪽 미분계수도 같아요.",
                      steps: steps, answer: answer)
    }
}
