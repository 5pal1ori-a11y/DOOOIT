import Foundation

/// 두잇 AI: 객관식 "옳은 것 / 옳지 않은 것 / 아닌 것 / 모두 고르면" (외부 AI 없이)
/// 보기 하나하나를 참·거짓으로 확인해요 (계산식, 등식·항등식, 대소 비교, 인수분해, 해인지, 소수·약수·배수·유리수…)
/// 확인할 수 없는 보기가 하나라도 있으면 nil (틀린 답보다 '못 풀어요'가 나아요)
/// 빈칸(□) 여러 개: 같은 수, 자리의 숫자, 부등식의 □, 식마다 하나씩
enum DoitMathChoice {
    typealias Solved = MathSolver.Solved

    private static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }
    private static func f(_ v: Double) -> String { DoitMath.fraction(v) }
    private static func match(_ t: String, _ p: String) -> [String]? { DoitMathExact.match(t, p) }

    // MARK: - 보기 고르기

    private enum Mode {
        case statement
        case predicate((String) -> Bool?)
        case solutions([Double])
    }

    static func solve(body raw: String, choices: [(Character, String)]) -> Solved? {
        let body = DoitAlgebra.normalize(DoitMathExact.tidy(raw))
        let negative = has(body, ["아닌", "않은", "틀린", "않는", "잘못", "거짓인"])
        let multi = has(body, ["모두 고르", "모두 찾", "모두 구하", "모두 몇", "모두 골"])
        if let s = extreme(body, choices) { return s }
        guard let mode = mode(body) else { return nil }
        var truths: [Bool] = []
        var reasons: [String] = []
        for (_, text) in choices {
            let c = DoitAlgebra.normalize(DoitMathExact.tidy(text)).trimmingCharacters(in: CharacterSet(charactersIn: " .。"))
            var value: Bool?
            switch mode {
            case .statement: value = statement(c)
            case .predicate(let p): value = p(c)
            case .solutions(let roots):
                if let v = number(c) { value = roots.contains { abs($0 - v) < 1e-9 } }
            }
            guard let v = value else { return nil }
            truths.append(v)
            reasons.append(v ? "참" : "거짓")
        }
        let wanted = !negative
        let hits = truths.enumerated().filter { $0.element == wanted }.map(\.offset)
        guard !hits.isEmpty, multi || hits.count == 1 else { return nil }
        let steps = choices.enumerated().map { i, c in SolutionStep(hint: "\(c.0) \(c.1)", work: truths[i] ? "옳아요" : "옳지 않아요") }
        let answer = hits.count == 1 && !multi ? "\(choices[hits[0]].0) \(choices[hits[0]].1)" : hits.map { String(choices[$0].0) }.joined(separator: ", ")
        return Solved(kind: .calc, topic: "보기 하나씩 확인하기", concept: negative ? "보기를 하나씩 계산해서 옳지 않은(조건에 맞지 않는) 것을 찾아요." : "보기를 하나씩 계산해서 옳은(조건에 맞는) 것을 찾아요.",
                      steps: steps, answer: answer)
    }

    /// "계산 결과가 가장 큰 것은?", "가장 작은 수는?"
    private static func extreme(_ body: String, _ choices: [(Character, String)]) -> Solved? {
        let wantsMax = has(body, ["가장 큰"]), wantsMin = has(body, ["가장 작은"])
        guard wantsMax != wantsMin, !has(body, ["=", "x"]) else { return nil }
        var values: [Double] = []
        for (_, text) in choices {
            guard let v = numeric(DoitAlgebra.normalize(DoitMathExact.tidy(text))) else { return nil }
            values.append(v)
        }
        guard let best = wantsMax ? values.max() : values.min(), values.filter({ abs($0 - best) < 1e-9 }).count == 1,
              let index = values.firstIndex(where: { abs($0 - best) < 1e-9 }) else { return nil }
        let steps = choices.enumerated().map { i, c in SolutionStep(hint: "\(c.0) \(c.1)", work: DoitMathFigures.nice(values[i]) ?? DoitMath.format(values[i], digits: 6)) }
        return Solved(kind: .calc, topic: "보기의 값 비교", concept: "보기를 하나씩 계산해서 크기를 비교해요.", steps: steps,
                      answer: "\(choices[index].0) \(choices[index].1)")
    }

    private static func mode(_ body: String) -> Mode? {
        // x = 2가 해, x = −1을 해로 갖는
        if let m = match(body, #"x\s*=\s*(-?\d+(?:\.\d+)?(?:/\d+)?)\s*(?:가|이|을|를|은|는)?\s*(?:해|근)"#), let v = DoitMathConstants.value(m[1]) {
            return .predicate { c in isSolution(c, v) }
        }
        if body.contains("="), has(body, ["해를 모두", "근을 모두", "해가 되는 것을 모두"]) {
            guard let solved = MathSolver.solve(body) else { return nil }
            let values = DoitMathExact.matches(solved.answer, #"(-?\d+(?:\.\d+)?(?:/\d+)?)"#).compactMap { DoitMathConstants.value($0[1]) }
            return values.isEmpty ? nil : .solutions(values)
        }
        let picksThings = has(body, ["인 것", "아닌 것", "를 모두", "을 모두", "인 수", "아닌 수"])
        // "다항식 x² − x − 6의 인수인 것은?" → 보기 (일차식)가 0이 되는 x를 넣으면 0
        if picksThings, body.contains("인수"), !body.contains("인수분해"), let m = match(body, #"([^가-힣]*x[^가-힣]*?)\s*의\s*인수"#),
           let p = DoitAlgebra.parse(m[1].trimmingCharacters(in: .whitespaces))?.univariate, p.degree >= 1 {
            return .predicate { c in
                guard let l = DoitAlgebra.parse(c)?.univariate, l.degree == 1 else { return nil }
                return abs(DoitMath.value(p, at: -l[0] / l[1])) < 1e-9
            }
        }
        if picksThings, let m = match(body, #"(\d+)\s*의\s*약수"#), let n = Int(m[1]), n > 0 {
            return .predicate { c in integer(c).map { $0 > 0 && n % $0 == 0 } }
        }
        if picksThings, let m = match(body, #"(\d+)\s*의\s*배수"#), let n = Int(m[1]), n > 0 {
            return .predicate { c in integer(c).map { $0 % n == 0 } }
        }
        let statementWords = ["옳은", "옳지", "바르게", "바른", "틀린", "맞는", "참인", "거짓인", "잘못"]
        if !has(body, statementWords) {
            if !body.contains("=") {
                if has(body, ["항등식"]) { return .predicate { c in identity(c) } }
                if has(body, ["일차방정식"]) { return .predicate { c in equationDegree(c).map { $0 == 1 } } }
                if has(body, ["이차방정식"]) { return .predicate { c in equationDegree(c).map { $0 == 2 } } }
            }
            for (word, test) in numberPredicates where picksThings && body.contains(word) && !has(body, ["순환소수", "유한소수", "무한소수"]) {
                return .predicate { c in classify(c, test) }
            }
            return nil
        }
        return .statement
    }

    private static let numberPredicates: [(String, String)] = [
        ("합성수", "합성수"), ("무리수", "무리수"), ("유리수", "유리수"), ("소수", "소수"), ("짝수", "짝수"), ("홀수", "홀수"),
        ("자연수", "자연수"), ("음의 정수", "음의 정수"), ("정수", "정수")
    ]

    // MARK: - 값 읽기

    /// |−3| 처럼 절댓값을 먼저 계산
    private static func absFree(_ s: String) -> String? {
        var t = s
        for _ in 0..<6 {
            guard let m = match(t, #"\|([^|]*)\|"#) else { break }
            guard let v = numeric(m[1]) else { return nil }
            t = t.replacingOccurrences(of: m[0], with: "(\(DoitMath.format(abs(v), digits: 15)))")
        }
        return t.contains("|") ? nil : t
    }

    /// 수 하나의 값 (√, 분수, 거듭제곱, π)
    static func numeric(_ raw: String) -> Double? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, s.range(of: "[가-힣a-zA-Z]", options: .regularExpression) == nil else { return nil }
        guard let clean = s.contains("|") ? absFree(s) : s else { return nil }
        if let e = DoitMathExact.exactValue(clean) { return e.value }
        return DoitMathExact.node(clean)?.eval([:])
    }

    private static func number(_ c: String) -> Double? { numeric(c) }

    private static func integer(_ c: String) -> Int? {
        guard let v = numeric(c), abs(v - v.rounded()) < 1e-9, abs(v) < 1e12 else { return nil }
        return Int(v.rounded())
    }

    private static func isPrime(_ n: Int) -> Bool {
        guard n >= 2 else { return false }
        var k = 2
        while k * k <= n { if n % k == 0 { return false }; k += 1 }
        return true
    }

    /// 유리수인지 (정확히 알 수 없으면 nil)
    private static func rational(_ c: String) -> Bool? {
        // π가 들어간 수 (π, 2π, π/2)는 무리수
        if c.contains("π") { return numeric(c) != nil ? false : nil }
        guard let clean = c.contains("|") ? absFree(c) : c, let e = DoitMathExact.exactValue(clean) else { return nil }
        return e.rational != nil
    }

    private static func classify(_ c: String, _ test: String) -> Bool? {
        switch test {
        case "유리수": return rational(c)
        case "무리수": return rational(c).map { !$0 }
        default: break
        }
        // 정수가 아닌 수도 판단할 수 있는 것: 정수, 자연수
        if test == "정수" || test == "자연수" || test == "음의 정수" {
            guard let v = numeric(c) else { return nil }
            let isInt = abs(v - v.rounded()) < 1e-9
            if test == "정수" { return isInt }
            if test == "음의 정수" { return isInt && v < 0 }
            return isInt && v >= 1
        }
        guard let n = integer(c) else { return nil }
        switch test {
        case "소수": return isPrime(n)
        case "합성수": return n >= 4 && !isPrime(n)
        case "짝수": return n % 2 == 0
        case "홀수": return abs(n % 2) == 1
        default: return nil
        }
    }

    // MARK: - 식 확인

    /// 식에 쓰인 문자들
    private static func letters(_ s: String) -> Set<Character> { Set(s.filter { $0.isASCII && $0.isLetter }) }

    /// 좌변 − 우변을 여러 값에서 계산
    private static func differences(_ l: String, _ r: String) -> [Double]? {
        let vars = letters(l + r)
        guard vars.count <= 3, let ln = DoitMathExact.node(l, variables: vars), let rn = DoitMathExact.node(r, variables: vars) else { return nil }
        let samples: [[Double]] = [[1.37, -0.83, 2.21], [-2.11, 1.73, 0.61], [0.47, 2.93, -1.29], [3.17, -1.41, 1.87]]
        var out: [Double] = []
        for row in samples {
            var env: [Character: Double] = [:]
            for (i, v) in vars.sorted().enumerated() { env[v] = row[i] }
            guard let a = ln.eval(env), let b = rn.eval(env) else { return nil }
            out.append(a - b)
        }
        return out
    }

    /// 항등식인지 (좌변 − 우변이 늘 0)
    private static func identity(_ c: String) -> Bool? {
        let sides = c.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard sides.count == 2, let diffs = differences(sides[0], sides[1]) else { return nil }
        return diffs.allSatisfy { abs($0) < 1e-9 }
    }

    /// 방정식이면 차수 (항을 옮겨 정리한 뒤), 방정식이 아니면 −1
    private static func equationDegree(_ c: String) -> Int? {
        let sides = c.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard sides.count <= 2 else { return nil }
        guard sides.count == 2 else { return DoitAlgebra.parse(c) != nil ? -1 : nil }
        guard let l = DoitAlgebra.parse(sides[0]), let r = DoitAlgebra.parse(sides[1]) else { return nil }
        let e = l - r
        guard e.variables.allSatisfy({ $0 == "x" }) else { return nil }
        return e.degree <= 0 ? 0 : e.degree
    }

    private static func isSolution(_ c: String, _ v: Double) -> Bool? {
        let sides = c.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard sides.count == 2, let l = DoitMathExact.node(sides[0]), let r = DoitMathExact.node(sides[1]),
              let a = l.eval(["x": v]), let b = r.eval(["x": v]) else { return nil }
        return abs(a - b) < 1e-9
    }

    /// 참인 문장인지: 계산식·등식·부등식·항등식, "2는 소수이다", "6은 3의 배수이다"
    static func statement(_ raw: String) -> Bool? {
        let c = raw.replacingOccurrences(of: "입니다", with: "이다")
        if let fact = facts[c.replacingOccurrences(of: " ", with: "")] { return fact }
        // "1은 소수도 합성수도 아니다"
        if let m = match(c, #"^(-?\d+)\s*(?:은|는)\s*소수도\s*합성수도\s*아니다$"#), let n = Int(m[1]) { return n == 1 || n == 0 || n < 0 ? true : false }
        // "x = 2는 방정식 x + 1 = 3의 해이다"
        if let m = match(c, #"^x\s*=\s*(-?\d+(?:\.\d+)?(?:/\d+)?)\s*(?:은|는)\s*(?:방정식\s*|부등식\s*)?(.+?)\s*의\s*(?:해|근)(이다|가\s*아니다|이\s*아니다)$"#),
           let v = DoitMathConstants.value(m[1]), let truth = isSolution(m[2], v) {
            return m[3] == "이다" ? truth : !truth
        }
        if let r = setStatement(c) { return r }
        // 제곱근: "4의 제곱근은 ±2이다", "9의 양의 제곱근은 3이다", "제곱근 16은 4이다"
        if let m = match(c, #"^(\d+(?:\.\d+)?)\s*의\s*(양의\s*|음의\s*)?제곱근은\s*(±)?\s*(-?\d+(?:\.\d+)?)\s*(?:이다|뿐이다)$"#), let n = Double(m[1]), let k = Double(m[4]) {
            let root = n.squareRoot()
            if m[2].hasPrefix("양") { return m[3].isEmpty && abs(k - root) < 1e-9 }
            if m[2].hasPrefix("음") { return m[3].isEmpty && abs(k + root) < 1e-9 }
            return n == 0 ? k == 0 : (!m[3].isEmpty && abs(abs(k) - root) < 1e-9)
        }
        if let m = match(c, #"^(-?\d+(?:\.\d+)?)\s*의\s*제곱근은\s*없다$"#), let n = Double(m[1]) { return n < 0 }
        if let m = match(c, #"^제곱근\s*(\d+(?:\.\d+)?)\s*(?:은|는)\s*(±)?\s*(-?\d+(?:\.\d+)?)\s*이다$"#), let n = Double(m[1]), let k = Double(m[3]) {
            return m[2].isEmpty && abs(k - n.squareRoot()) < 1e-9
        }
        // "4의 약수는 3개이다", "12의 약수의 개수는 6개이다"
        if let m = match(c, #"^(\d+)\s*의\s*약수(?:는|의\s*개수는)\s*(\d+)\s*개(?:이다|가\s*아니다)$"#), let n = Int(m[1]), let k = Int(m[2]), n > 0, n < 1_000_000 {
            let count = (1...n).filter { n % $0 == 0 }.count
            return c.hasSuffix("아니다") ? count != k : count == k
        }
        // "N은 M의 약수(배수)이다 / 아니다"
        if let m = match(c, #"^(-?\d+)\s*(?:은|는)\s*(\d+)\s*의\s*(약수|배수)(?:이다|가\s*아니다|이\s*아니다)$"#), let n = Int(m[1]), let k = Int(m[2]), n != 0, k != 0 {
            let truth = m[3] == "약수" ? k % n == 0 : n % k == 0
            return c.hasSuffix("아니다") ? !truth : truth
        }
        // "N은 (짝수인) 소수이다 / 소수가 아니다"
        if let m = match(c, #"^(.+?)\s*(?:은|는)\s*((?:[가-힣]+인\s*)?[가-힣 ]+?)(?:이다|가\s*아니다|이\s*아니다)$"#) {
            let subject = m[1]
            let words = m[2].replacingOccurrences(of: "인", with: " ").split(separator: " ").map(String.init).filter { !$0.isEmpty }
            guard !words.isEmpty else { return nil }
            var truth = true
            for w in words {
                guard numberPredicates.contains(where: { $0.0 == w }), let v = classify(subject, w) else { return nil }
                truth = truth && v
            }
            return c.hasSuffix("아니다") ? !truth : truth
        }
        guard c.range(of: "[가-힣]", options: .regularExpression) == nil else { return nil }
        // 관계식: =, <, >, ≤, ≥, ≠ (이어진 것도)
        let ops: Set<Character> = ["=", "<", ">", "≤", "≥", "≠"]
        var parts: [String] = [], relations: [Character] = []
        var current = ""
        for ch in c {
            if ops.contains(ch) { parts.append(current); relations.append(ch); current = "" } else { current.append(ch) }
        }
        parts.append(current)
        guard !relations.isEmpty, parts.allSatisfy({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return nil }
        for (i, op) in relations.enumerated() {
            let l = parts[i].trimmingCharacters(in: .whitespaces), r = parts[i + 1].trimmingCharacters(in: .whitespaces)
            guard let truth = relation(l, op, r) else { return nil }
            if !truth { return false }
        }
        return true
    }

    private static func relation(_ l: String, _ op: Character, _ r: String) -> Bool? {
        // "√9 = ±3": 한 값이 두 값과 같을 수는 없어요
        if r.hasPrefix("±") || l.hasPrefix("±") {
            guard op == "=", let v = numeric(r.replacingOccurrences(of: "±", with: "")) ?? numeric(l.replacingOccurrences(of: "±", with: "")) else { return nil }
            return abs(v) < 1e-12
        }
        let vars = letters(l + r)
        if vars.isEmpty {
            guard let a = numeric(l), let b = numeric(r) else { return nil }
            let tol = 1e-9 * max(1, abs(a), abs(b))
            switch op {
            case "=": return abs(a - b) < tol
            case "≠": return abs(a - b) >= tol
            case "<": return a < b - tol
            case ">": return a > b + tol
            case "≤": return a <= b + tol
            default: return a >= b - tol
            }
        }
        // 문자가 있으면 늘 성립하는지 (지수법칙, 인수분해, 전개)
        guard op == "=" || op == "≠", let diffs = differences(l, r) else { return nil }
        let same = diffs.allSatisfy { abs($0) < 1e-7 * 10 }
        return op == "=" ? same : !same
    }

    /// 집합 사이의 관계: "2 ∈ {1, 2, 3}", "{1, 2} ⊂ {1, 2, 3}", "∅ ⊂ {1}", "{1, 2} = {2, 1}"
    private static func setStatement(_ c: String) -> Bool? {
        guard let m = match(c, #"^(.+?)\s*(∈|∉|⊂|⊄|⊆|⊊|=|≠)\s*(.+)$"#), c.contains("{") || c.contains("∅") else { return nil }
        func members(_ s: String) -> [String]? {
            let t = s.trimmingCharacters(in: .whitespaces)
            if t == "∅" || t == "{}" || t == "{ }" { return [] }
            guard t.hasPrefix("{"), t.hasSuffix("}") else { return nil }
            let inner = t.dropFirst().dropLast()
            guard !inner.contains("{"), !inner.contains("|") else { return nil }
            let items = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            var out: [String] = []
            for i in items where !out.contains(i) { out.append(i) }
            return out
        }
        let op = m[2]
        guard let right = members(m[3]) else { return nil }
        if op == "∈" || op == "∉" {
            let e = m[1].trimmingCharacters(in: .whitespaces)
            guard !e.contains("{"), !e.isEmpty else { return nil }
            let inside = right.contains(e)
            return op == "∈" ? inside : !inside
        }
        guard let left = members(m[1]) else { return nil }
        let subset = left.allSatisfy { right.contains($0) }
        switch op {
        case "⊂", "⊆": return subset
        case "⊊": return subset && left.count < right.count
        case "⊄": return !subset
        case "=": return subset && right.allSatisfy { left.contains($0) }
        default: return !(subset && right.allSatisfy { left.contains($0) })
        }
    }

    /// 자주 나오는 말로 된 사실 (공백 없이)
    private static let facts: [String: Bool] = [
        "모든소수는홀수이다": false, "가장작은소수는2이다": true, "가장작은합성수는4이다": true,
        "소수의약수는2개이다": true, "소수는약수가2개이다": true, "합성수는약수가3개이상이다": true,
        "짝수인소수는2뿐이다": true, "짝수인소수는2하나뿐이다": true, "모든홀수는소수이다": false,
        "자연수는1,소수,합성수로이루어져있다": true, "두소수의곱은합성수이다": true, "모든자연수는정수이다": true,
        "모든정수는유리수이다": true, "모든유리수는정수이다": false, "0은양수도음수도아니다": true,
        "모든무리수는무한소수이다": true, "순환소수는유리수이다": true, "모든무한소수는무리수이다": false,
        "유한소수는유리수이다": true, "1은모든자연수의약수이다": true, "0은자연수이다": false
    ]

    // MARK: - 빈칸(□) 여러 개

    enum BlankOutcome {
        case solved(Solved)
        case refuse
        case pass
    }

    static func blanks(_ t: String) -> BlankOutcome {
        let allowed = Set("0123456789.+-*/^()=:□x√<>≤≥ ")
        var runs: [String] = [], current = ""
        for ch in t {
            if allowed.contains(ch) { current.append(ch) } else { runs.append(current); current = "" }
        }
        runs.append(current)
        let pieces = runs.map(tidyRun).filter { $0.contains("□") }
        guard !pieces.isEmpty else { return .pass }
        // □가 들어간 부등식 ("□ < 5 인 자연수 □의 개수")
        let inequalities = pieces.filter { $0.range(of: "[<>≤≥]", options: .regularExpression) != nil }
        if inequalities.count == 1, pieces.allSatisfy({ $0 == inequalities[0] || $0 == "□" }) {
            return inequalityBlank(inequalities[0], t)
        }
        let equations = pieces.filter { $0.contains("=") }
        // 식마다 □ 하나씩: 차례대로
        if equations.count >= 2, equations.allSatisfy({ $0.filter { $0 == "□" }.count == 1 }), !equations.contains(where: { digitAdjacent($0) }) {
            var values: [String] = []
            var steps: [SolutionStep] = []
            for e in equations {
                guard let s = DoitMathExact.blank(e), let v = s.answer.components(separatedBy: "= ").last else { return .refuse }
                values.append(v)
                steps.append(SolutionStep(hint: e.replacingOccurrences(of: "*", with: " × "), work: "□ = \(v)"))
            }
            return .solved(Solved(kind: .linear, topic: "□ 안에 알맞은 수", concept: "식마다 □를 모르는 수로 놓고 차례대로 구해요.", steps: steps, answer: "차례대로 \(values.joined(separator: ", "))"))
        }
        guard equations.count == 1, let run = equations.first else { return pieces.contains(where: { $0.filter { $0 == "□" }.count > 1 }) ? .refuse : .pass }
        let count = run.filter { $0 == "□" }.count
        if digitAdjacent(run) && (count >= 2 || has(t, ["숫자"])) { return digitPuzzle(run) }
        if count == 1 { return digitAdjacent(run) ? digitPuzzle(run) : .pass }
        // 같은 수가 들어가는 □
        guard has(t, ["같은 수", "같은 자연수", "같은 모양"]) else { return .refuse }
        let sides = run.replacingOccurrences(of: "□", with: "x").split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard sides.count == 2, let l = DoitMath.polynomial(sides[0]), let r = DoitMath.polynomial(sides[1]) else { return .refuse }
        var roots = DoitAlgebra.realRoots(l - r).map(\.value)
        if has(t, ["자연수"]) { roots = roots.filter { $0 > 0 && abs($0 - $0.rounded()) < 1e-9 } }
        guard roots.count == 1, let v = roots.first else { return .refuse }
        let filled = run.replacingOccurrences(of: "□", with: f(v)).replacingOccurrences(of: "*", with: " × ")
        return .solved(Solved(kind: .linear, topic: "□ 안에 알맞은 수 (같은 수)", concept: "같은 □에는 같은 수가 들어가요. □를 x로 놓고 방정식을 풀어요.",
                              steps: [SolutionStep(hint: "□를 x로 놓으면", work: run.replacingOccurrences(of: "□", with: "x").replacingOccurrences(of: "*", with: " × ")),
                                      SolutionStep(hint: "x를 구해 넣어 보면", work: filled)],
                              answer: "□ = \(f(v))"))
    }

    /// 앞뒤 공백, 짝이 없는 괄호 ("10 (단, …" 의 '(') 떼기
    private static func tidyRun(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        while s.hasSuffix("("), s.filter({ $0 == "(" }).count > s.filter({ $0 == ")" }).count { s = String(s.dropLast()).trimmingCharacters(in: .whitespaces) }
        while s.hasPrefix(")"), s.filter({ $0 == ")" }).count > s.filter({ $0 == "(" }).count { s = String(s.dropFirst()).trimmingCharacters(in: .whitespaces) }
        return s
    }

    /// □ 바로 옆에 숫자가 붙어 있으면 (3□, □5) 자리의 숫자
    private static func digitAdjacent(_ run: String) -> Bool {
        let c = Array(run)
        for (i, ch) in c.enumerated() where ch == "□" {
            let before = i > 0 ? c[i - 1] : " ", after = i + 1 < c.count ? c[i + 1] : " "
            if before.isNumber || after.isNumber || (before == "□") || (after == "□") { return true }
        }
        return false
    }

    /// 자리의 숫자 맞히기: 각 □에 0~9 (맨 앞자리는 1~9). 답이 하나일 때만
    private static func digitPuzzle(_ run: String) -> BlankOutcome {
        let c = Array(run)
        let positions = c.indices.filter { c[$0] == "□" }
        guard positions.count <= 4 else { return .refuse }
        // 맨 앞자리인 □
        let leading: [Bool] = positions.map { i in
            let before = i > 0 ? c[i - 1] : " "
            let after = i + 1 < c.count ? c[i + 1] : " "
            return !(before.isNumber || before == "□" || before == ".") && (after.isNumber || after == "□")
        }
        var solutions: [[Int]] = []
        let total = Int(pow(10.0, Double(positions.count)))
        for code in 0..<total {
            var digits: [Int] = []
            var k = code
            for _ in positions { digits.append(k % 10); k /= 10 }
            if zip(digits, leading).contains(where: { $0 == 0 && $1 }) { continue }
            var filled = c
            for (j, p) in positions.enumerated() { filled[p] = Character(String(digits[j])) }
            let sides = String(filled).split(separator: "=", omittingEmptySubsequences: false).map(String.init)
            guard sides.count == 2, let a = numeric(sides[0]), let b = numeric(sides[1]) else { continue }
            if abs(a - b) < 1e-9 { solutions.append(digits) }
            if solutions.count > 1 { return .refuse }
        }
        guard solutions.count == 1, let digits = solutions.first else { return .refuse }
        var filled = c
        for (j, p) in positions.enumerated() { filled[p] = Character(String(digits[j])) }
        let shown = String(filled).replacingOccurrences(of: "*", with: " × ").replacingOccurrences(of: "/", with: " ÷ ")
        let list = digits.map(String.init).joined(separator: ", ")
        return .solved(Solved(kind: .calc, topic: "□ 안에 알맞은 숫자", concept: "□는 한 자리 숫자(0~9)예요. 일의 자리부터 받아올림·받아내림을 생각하며 맞는 숫자를 찾아요.",
                              steps: [SolutionStep(hint: "□에 0부터 9까지 넣어 보며 식이 맞는 것을 찾으면", work: shown),
                                      SolutionStep(hint: "□ 안의 숫자를 차례대로", work: list)],
                              answer: positions.count == 1 ? "□ = \(list)" : "차례대로 \(list)"))
    }

    /// "□ < 5 인 자연수 □의 개수", "3 × □ < 20을 만족하는 자연수 □ 중 가장 큰 수"
    private static func inequalityBlank(_ piece: String, _ t: String) -> BlankOutcome {
        guard has(t, ["자연수", "한 자리 수"]) else { return .refuse }
        // 부등호마다 나눠서 확인 (25 < □ × 4 < 40)
        var parts: [String] = [], ops: [Character] = []
        var current = ""
        for ch in piece {
            if "<>≤≥".contains(ch) { parts.append(current); ops.append(ch); current = "" } else { current.append(ch) }
        }
        parts.append(current)
        let nodes = parts.map { DoitMathExact.node($0.replacingOccurrences(of: "□", with: "x")) }
        guard nodes.allSatisfy({ $0 != nil }), !ops.isEmpty else { return .refuse }
        let oneDigit = has(t, ["한 자리"])
        let limit = oneDigit ? 9 : 10000
        var found: [Int] = []
        for n in 1...limit {
            var ok = true
            for (i, op) in ops.enumerated() {
                guard let a = nodes[i]?.eval(["x": Double(n)]), let b = nodes[i + 1]?.eval(["x": Double(n)]) else { ok = false; break }
                let holds: Bool
                switch op { case "<": holds = a < b; case ">": holds = a > b; case "≤": holds = a <= b; default: holds = a >= b }
                if !holds { ok = false; break }
            }
            if ok { found.append(n) }
        }
        // 끝없이 많으면 (□ > 5인 자연수) 셀 수 없음
        // 끝없이 많아도 가장 작은 수는 정할 수 있어요
        guard !found.isEmpty, oneDigit || found.last! < limit || has(t, ["가장 작은"]) else { return .refuse }
        let shown = piece.replacingOccurrences(of: "*", with: " × ")
        var steps = [SolutionStep(hint: "□에 1, 2, 3, …을 차례로 넣어 보면", work: "\(shown)을 만족하는 수: \(found.map(String.init).joined(separator: ", "))")]
        let answer: String
        if has(t, ["가장 큰"]) { answer = "\(found.last!)" }
        else if has(t, ["가장 작은"]) { answer = "\(found.first!)" }
        else if has(t, ["개수", "몇 개"]) { answer = "\(found.count)개" }
        else if has(t, ["모두", "구하"]) { answer = found.map(String.init).joined(separator: ", ") }
        else { return .refuse }
        steps.append(SolutionStep(hint: "묻는 것", work: answer))
        return .solved(Solved(kind: .inequality, topic: "□가 있는 부등식", concept: "□에 수를 하나씩 넣어 보며 부등식이 맞는지 확인해요. (곱셈·나눗셈의 관계를 이용하면 빨라요)", steps: steps, answer: answer))
    }
}
