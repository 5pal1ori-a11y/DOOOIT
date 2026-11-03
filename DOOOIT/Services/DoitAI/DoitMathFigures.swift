import Foundation

/// 모티 AI: 조건제시법 집합, 꼭짓점 이름이 붙은 도형 (외부 AI 없이)
/// - {x | x는 10 이하의 소수}, {x | 1 ≤ x < 5, x는 정수}, {2x | x는 4 이하의 자연수} → 원소나열, 연산, n(A), 부분집합
/// - 직각삼각형 ABC (피타고라스, 삼각비, 특수각), 두 변과 끼인각의 넓이, 코사인·사인법칙, 외접원
/// - 평행선과 선분의 비, 닮음(∽), 닮음비와 넓이·부피의 비, 접선의 길이, 원주각과 중심각
enum DoitMathFigures {
    typealias Solved = MathSolver.Solved

    private static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }
    private static func f(_ v: Double) -> String { DoitMath.fraction(v) }
    private static func d(_ v: Double) -> String { DoitMath.format(v, digits: 8) }
    private static func match(_ t: String, _ p: String) -> [String]? { DoitMathExact.match(t, p) }
    private static func matches(_ t: String, _ p: String) -> [[String]] { DoitMathExact.matches(t, p) }
    private static let num = #"(-?\d+(?:\.\d+)?(?:/\d+)?)"#

    /// 정확한 값 글자: 12, 5/13, 4√3, √3/2, 2√6 (모르면 nil)
    static func nice(_ v: Double) -> String? {
        guard v.isFinite else { return nil }
        if abs(v - v.rounded()) < 1e-9 { return f(v.rounded()) }
        for den in 2...100 {
            let n = v * Double(den)
            if abs(n - n.rounded()) < 1e-7 { return f(v) }
        }
        let s = v * v
        for den in 1...100 {
            let n = s * Double(den)
            guard abs(n - n.rounded()) < 1e-6 * max(1, n) else { continue }
            let text = DoitAlgebra.sqrtText(n.rounded() / Double(den))
            guard !text.contains("≈") else { return nil }
            return (v < 0 ? "−" : "") + text
        }
        return nil
    }

    // MARK: - 조건제시법 집합

    enum Members {
        case finite([Double])
        case rule((Double) -> Bool)
    }

    static func sets(_ t: String) -> Solved? {
        guard t.range(of: #"\{[^{}]*\|[^{}]*\}"#, options: .regularExpression) != nil else { return nil }
        var named: [String: Members] = [:]
        var order: [String] = []
        var steps: [SolutionStep] = []
        let definitions = matches(t, #"(?:([A-Z])\s*=\s*)?\{([^{}]*)\}"#)
        guard !definitions.isEmpty else { return nil }
        // 전체집합을 먼저 (A = {x | x는 홀수}를 U 안에서 읽으려고)
        let sortedDefinitions = definitions.sorted { ($0[1] == "U" ? 0 : 1) < ($1[1] == "U" ? 0 : 1) }
        for m in sortedDefinitions {
            let name = m[1].isEmpty ? "S" : m[1]
            let body = m[2]
            var members: Members
            if body.contains("|") {
                let universe: [Double]? = { if case .finite(let u)? = named["U"], name != "U" { return u }; return nil }()
                guard let built = builder(body, universe: universe) else { return nil }
                members = built
            } else {
                let items = body.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                let values = items.compactMap { DoitMathConstants.value($0) }
                guard values.count == items.count else { return nil }
                members = .finite(unique(values))
            }
            if case .finite(let v) = members { steps.append(SolutionStep(hint: "집합 \(name)의 원소를 나열하면", work: "\(name) = \(text(v))")) }
            named[name] = members
            order.append(name)
        }
        let concept = "조건제시법 {x | 조건}은 조건을 만족하는 x를 모두 모은 집합이에요. 원소를 하나씩 찾아 나열한 뒤 계산해요."
        func finite(_ name: String) -> [Double]? { if case .finite(let v)? = named[name] { return v }; return nil }
        // 연산
        if let m = match(t, #"(n\s*\(\s*)?([A-Z])\s*(∪|∩|-|\\)\s*([A-Z])"#), named[m[2]] != nil, named[m[4]] != nil {
            let op = m[3] == "\\" ? "-" : m[3]
            var result: [Double]?
            switch (named[m[2]]!, named[m[4]]!, op) {
            case (.finite(let a), .finite(let b), "∪"): result = unique(a + b)
            case (.finite(let a), .finite(let b), "∩"): result = a.filter { b.contains($0) }
            case (.finite(let a), .rule(let p), "∩"), (.rule(let p), .finite(let a), "∩"): result = a.filter(p)
            case (.finite(let a), .finite(let b), "-"): result = a.filter { !b.contains($0) }
            case (.finite(let a), .rule(let p), "-"): result = a.filter { !p($0) }
            default: result = nil
            }
            guard let r = result else { return nil }
            let label = "\(m[2]) \(op == "-" ? "−" : op) \(m[4])"
            steps.append(SolutionStep(hint: op == "∪" ? "두 집합의 원소를 모두 모으면" : op == "∩" ? "공통인 원소만" : "\(m[2])에만 있는 원소만", work: "\(label) = \(text(r))"))
            if !m[1].isEmpty { return Solved(kind: .sets, topic: "집합의 연산과 원소의 개수", concept: concept, steps: steps, answer: "n(\(label)) = \(r.count)") }
            return Solved(kind: .sets, topic: "집합의 연산", concept: concept, steps: steps, answer: "\(label) = \(text(r))")
        }
        if let m = match(t, #"([A-Z])\s*(?:\^\s*[cC]|ᶜ|의\s*여집합)"#), let u = finite("U") {
            let r: [Double]
            switch named[m[1]] {
            case .finite(let a)?: r = u.filter { !a.contains($0) }
            case .rule(let p)?: r = u.filter { !p($0) }
            default: return nil
            }
            steps.append(SolutionStep(hint: "U에서 \(m[1])의 원소를 빼면", work: text(r)))
            return Solved(kind: .sets, topic: "여집합", concept: concept, steps: steps, answer: "\(m[1])ᶜ = \(text(r))")
        }
        // 대상 집합: "집합 A의", "A를", 하나뿐이면 그것
        let target: String? = match(t, #"(?:집합\s*)?([A-Z])\s*(?:의|를|을|는|가|이)"#).map { $0[1] }.flatMap { named[$0] != nil ? $0 : nil }
            ?? match(t, #"n\s*\(\s*([A-Z])\s*\)"#).map { $0[1] } ?? (order.count == 1 ? order[0] : nil)
        // 원소가 끝없이 많은 집합: 원소나열법은 "{3, 6, 9, 12, …}"
        if let key = target, case .rule(let p)? = named[key], has(t, ["원소나열법", "나열"]) {
            let members = (-300...1000).map(Double.init).filter(p)
            guard let first = members.first, first > -300, members.count >= 5 else { return nil }
            let shown = "{" + members.prefix(4).map { f($0) }.joined(separator: ", ") + ", …}"
            steps.append(SolutionStep(hint: "조건을 만족하는 수를 작은 것부터 나열하면 (끝없이 이어져요)", work: shown))
            return Solved(kind: .sets, topic: "원소나열법 (무한집합)", concept: concept, steps: steps, answer: "\(key == "S" ? "" : key + " = ")\(shown)")
        }
        guard let key = target, let set = finite(key) else { return nil }
        if has(t, ["부분집합"]) && has(t, ["개수", "몇 개"]) {
            guard set.count <= 20 else { return nil }
            let total = 1 << set.count
            let proper = has(t, ["진부분집합"])
            steps.append(SolutionStep(hint: "원소가 \(set.count)개이면 부분집합은 2^\(set.count)개", work: "\(total)"))
            if proper { steps.append(SolutionStep(hint: "자기 자신을 빼면", work: "\(total - 1)")) }
            return Solved(kind: .sets, topic: proper ? "진부분집합의 개수" : "부분집합의 개수", concept: concept, steps: steps, answer: "\(proper ? total - 1 : total)개")
        }
        if has(t, ["n(", "원소의 개수", "원소의 수", "몇 개"]) {
            return Solved(kind: .sets, topic: "원소의 개수", concept: concept, steps: steps, answer: "n(\(key == "S" ? "A" : key)) = \(set.count)")
        }
        if has(t, ["원소나열법", "나열", "나타내", "구하"]) {
            return Solved(kind: .sets, topic: "원소나열법", concept: concept, steps: steps, answer: "\(key == "S" ? "" : key + " = ")\(text(set))")
        }
        return nil
    }

    private static func unique(_ v: [Double]) -> [Double] {
        var out: [Double] = []
        for x in v where !out.contains(where: { abs($0 - x) < 1e-12 }) { out.append(x) }
        return out.sorted()
    }

    private static func text(_ v: [Double]) -> String {
        v.isEmpty ? "∅" : "{" + unique(v).map { f($0) }.joined(separator: ", ") + "}"
    }

    private static func isPrime(_ n: Int) -> Bool {
        guard n >= 2 else { return false }
        var k = 2
        while k * k <= n { if n % k == 0 { return false }; k += 1 }
        return true
    }

    /// "x | x는 10 이하의 소수" → 원소들 (끝없이 많으면 규칙으로)
    static func builder(_ body: String, universe: [Double]?) -> Members? {
        let parts = body.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }
        let element = parts[0]
        var tests: [(Double) -> Bool] = []
        var candidates: [Double]?
        var bounded = false
        for raw in parts[1].components(separatedBy: CharacterSet(charactersIn: ",")) {
            let c = raw.trimmingCharacters(in: .whitespaces)
            guard !c.isEmpty else { continue }
            if c.contains("=") && !c.contains("<") && !c.contains(">") {
                // x² − 5x + 6 = 0
                let sides = c.split(separator: "=").map(String.init)
                guard sides.count == 2, let l = DoitAlgebra.parse(sides[0])?.univariate, let r = DoitAlgebra.parse(sides[1])?.univariate else { return nil }
                let roots = DoitAlgebra.realRoots(l - r).map(\.value)
                candidates = roots
                bounded = true
                continue
            }
            if c.range(of: "[<>≤≥]", options: .regularExpression) != nil, c.range(of: "[가-힣]", options: .regularExpression) == nil {
                guard let test = inequalityTest(c) else { return nil }
                tests.append(test.0)
                bounded = bounded || test.1
                continue
            }
            guard let words = wordTest(c) else { return nil }
            tests.append(words.0)
            bounded = bounded || words.1
        }
        var pool: [Double]
        if let c = candidates { pool = c }
        else if let u = universe, !bounded { pool = u }
        else { pool = (-300...1000).map(Double.init) }
        let chosen = pool.filter { x in tests.allSatisfy { $0(x) } }
        // 아주 큰 범위까지 남으면 끝이 없는 집합
        if candidates == nil, universe == nil || bounded, chosen.contains(where: { abs($0) >= 300 }) {
            guard element == "x" else { return nil }
            return .rule { x in tests.allSatisfy { $0(x) } }
        }
        if element == "x" { return .finite(unique(chosen)) }
        guard let e = DoitMathExact.node(element) else { return nil }
        let mapped = chosen.compactMap { e.eval(["x": $0]) }
        guard mapped.count == chosen.count else { return nil }
        return .finite(unique(mapped))
    }

    /// "1 ≤ x < 5", "x ≤ 4", "−2 < x ≤ 3"
    private static func inequalityTest(_ c: String) -> ((Double) -> Bool, Bool)? {
        let s = c.replacingOccurrences(of: " ", with: "")
        func cmp(_ a: Double, _ op: String, _ b: Double) -> Bool {
            switch op { case "<": return a < b; case "≤": return a <= b; case ">": return a > b; default: return a >= b }
        }
        if let m = match(s, #"^(-?\d+(?:\.\d+)?)([<≤])x([<≤])(-?\d+(?:\.\d+)?)$"#), let lo = Double(m[1]), let hi = Double(m[4]) {
            let o1 = m[2], o2 = m[3]
            return ({ x in cmp(lo, o1, x) && cmp(x, o2, hi) }, true)
        }
        if let m = match(s, #"^x([<>≤≥])(-?\d+(?:\.\d+)?)$"#), let v = Double(m[2]) {
            let o = m[1]
            return ({ x in cmp(x, o, v) }, false)
        }
        return nil
    }

    /// 말로 된 조건: "x는 10 이하의 소수", "x는 짝수인 한 자리 자연수", "x는 12의 약수", "x는 정수"
    private static func wordTest(_ raw: String) -> ((Double) -> Bool, Bool)? {
        var c = raw
        var tests: [(Double) -> Bool] = []
        var bounded = false
        var naturalOnly = true
        func take(_ pattern: String, _ test: @escaping ([String], Double) -> Bool) -> Bool {
            guard let m = match(c, pattern) else { return false }
            tests.append { x in test(m, x) }
            c = c.replacingOccurrences(of: m[0], with: " ")
            return true
        }
        func isInt(_ x: Double) -> Bool { abs(x - x.rounded()) < 1e-12 }
        func n(_ m: [String]) -> Double { Double(m[1]) ?? 0 }
        if take(#"(\d+)\s*이하의?"#, { m, x in x <= n(m) }) { bounded = true }
        if take(#"(\d+)\s*미만의?"#, { m, x in x < n(m) }) { bounded = true }
        if take(#"(\d+)\s*보다\s*작은"#, { m, x in x < n(m) }) { bounded = true }
        if take(#"(\d+)\s*보다\s*작고"#, { m, x in x < n(m) }) { bounded = true }
        _ = take(#"(\d+)\s*보다\s*크고"#, { m, x in x > n(m) })
        _ = take(#"(\d+)\s*이상의?"#, { m, x in x >= n(m) })
        _ = take(#"(\d+)\s*보다\s*큰"#, { m, x in x > n(m) })
        _ = take(#"(\d+)\s*초과의?"#, { m, x in x > n(m) })
        if take(#"(\d+)\s*의\s*약수"#, { m, x in isInt(x) && x >= 1 && Int(n(m)) % Int(x) == 0 }) { bounded = true }
        _ = take(#"([1-9]\d*)\s*의\s*배수"#, { m, x in isInt(x) && Int(x) % Int(n(m)) == 0 })
        if take(#"한\s*자리(?:의)?"#, { _, x in abs(x) <= 9 }) { bounded = true }
        if take(#"두\s*자리(?:의)?"#, { _, x in abs(x) >= 10 && abs(x) <= 99 }) { bounded = true }
        _ = take("합성수", { _, x in isInt(x) && x >= 4 && !isPrime(Int(x)) })
        _ = take("소수", { _, x in isInt(x) && isPrime(Int(x)) })
        _ = take("짝수", { _, x in isInt(x) && Int(x) % 2 == 0 })
        _ = take("홀수", { _, x in isInt(x) && abs(Int(x) % 2) == 1 })
        if take("음의\\s*정수", { _, x in isInt(x) && x < 0 }) { naturalOnly = false }
        if take("정수", { _, x in isInt(x) }) { naturalOnly = false }
        _ = take("자연수", { _, x in isInt(x) && x >= 1 })
        // 남은 글자가 이어주는 말뿐이어야 (모르는 조건이 있으면 nil)
        var rest = c
        for w in ["x는", "x가", "x", "이고", "인", "의", "수", "중", "에서", "모든", "숫자"] { rest = rest.replacingOccurrences(of: w, with: " ") }
        guard rest.trimmingCharacters(in: .whitespaces).isEmpty, !tests.isEmpty else { return nil }
        if naturalOnly { tests.append { x in isInt(x) && x >= 1 } }
        return ({ x in tests.allSatisfy { $0(x) } }, bounded)
    }

    // MARK: - 꼭짓점 이름이 붙은 삼각형

    struct Triangle {
        var side: [Character: Double] = [:]    // a = BC, b = CA, c = AB
        var angle: [Character: Double] = [:]   // 도
    }

    private static func sideKey(_ name: String) -> Character? {
        let s = Set(name)
        guard s.count == 2, s.isSubset(of: ["A", "B", "C"]) else { return nil }
        return ["A", "B", "C"].first { !s.contains($0) }.map { Character($0.lowercased()) }
    }

    private static func sin(_ deg: Double) -> Double { Foundation.sin(deg * .pi / 180) }
    private static func cos(_ deg: Double) -> Double { Foundation.cos(deg * .pi / 180) }

    static func triangle(_ t: String) -> Solved? {
        if let s = parallelLines(t) { return s }
        if let s = similar(t) { return s }
        if let s = congruent(t) { return s }
        if let s = parallelogram(t) { return s }
        if let s = parallelAngles(t) { return s }
        if let s = similarityRatio(t) { return s }
        if let s = circleAngles(t) { return s }
        if let s = tangentLength(t) { return s }
        if let s = twoSidesArea(t) { return s }
        if let s = threePointArea(t) { return s }
        let labelled = has(t, ["삼각형 ABC", "△ABC", "ABC에서", "ABC의"]) || t.range(of: #"∠\s*[ABC]\s*="#, options: .regularExpression) != nil
        let ratioOnly = t.range(of: #"(sin|cos|tan)\s*[A-Z]\s*=\s*"# + num, options: .regularExpression) != nil && t.contains("°")
        guard labelled || ratioOnly else { return nil }
        var tri = Triangle()
        var given: [String] = []
        for m in matches(t, #"(?<![A-Za-z])([A-C]{2})\s*=\s*(\d+(?:\.\d+)?)(?!\s*°)"#) {
            guard let key = sideKey(m[1]), let v = Double(m[2]) else { continue }
            tri.side[key] = v
            given.append("\(m[1]) = \(m[2])")
        }
        if has(t, ["삼각형 ABC", "△ABC"]) {
            for m in matches(t, #"(?<![A-Za-z])([abc])\s*=\s*(\d+(?:\.\d+)?)(?!\s*°)"#) {
                guard let key = m[1].first, let v = Double(m[2]) else { continue }
                tri.side[key] = v
                given.append("\(m[1]) = \(m[2])")
            }
        }
        for m in matches(t, #"(?:∠\s*|(?<![A-Za-z]))([A-C])\s*=\s*(\d+(?:\.\d+)?)\s*°"#) {
            guard let key = m[1].first, let v = Double(m[2]) else { continue }
            tri.angle[key] = v
            given.append("∠\(m[1]) = \(m[2])°")
        }
        for m in matches(t, #"(sin|cos|tan)\s*([A-C])\s*=\s*"# + num) {
            guard let key = m[2].first, let v = DoitMathConstants.value(m[3]), tri.angle[key] == nil else { continue }
            // 예각일 때만 (직각삼각형의 예각, 0° < A < 90°)
            let acute = tri.angle.values.contains(90) || has(t, ["예각", "< 90°", "<90°", "직각삼각형"])
            guard acute else { return nil }
            let deg: Double
            switch m[1] {
            case "sin": guard v > 0, v < 1 else { return nil }; deg = asin(v) * 180 / .pi
            case "cos": guard v > 0, v < 1 else { return nil }; deg = acos(v) * 180 / .pi
            default: guard v > 0 else { return nil }; deg = atan(v) * 180 / .pi
            }
            tri.angle[key] = deg
            given.append("\(m[1]) \(m[2]) = \(m[3])")
        }
        // 이등변삼각형: AB = AC → ∠B = ∠C ("AB = AC인 이등변삼각형", "AB = AC이고")
        var equalPair: (Character, Character)?
        if let m = match(t, #"(?<![A-Za-z])([A-C]{2})\s*=\s*([A-C]{2})(?![A-Za-z])"#), let k1 = sideKey(m[1]), let k2 = sideKey(m[2]), k1 != k2 {
            equalPair = (Character(k1.uppercased()), Character(k2.uppercased()))
        }
        // 수직: AB ⊥ BC → 두 변이 만나는 꼭짓점의 각이 90°
        for m in matches(t, #"(?<![A-Za-z])([A-C]{2})\s*⊥\s*([A-C]{2})(?![A-Za-z])"#) {
            let common = Set(m[1]).intersection(Set(m[2]))
            guard common.count == 1, let vertex = common.first, tri.angle[vertex] == nil else { continue }
            tri.angle[vertex] = 90
            given.append("\(m[1]) ⊥ \(m[2]) → ∠\(vertex) = 90°")
        }
        // ∠A : ∠B : ∠C = 1 : 2 : 3
        if let m = match(t, #"∠?\s*A\s*:\s*∠?\s*B\s*:\s*∠?\s*C\s*=\s*(\d+)\s*:\s*(\d+)\s*:\s*(\d+)"#),
           let p = Double(m[1]), let q = Double(m[2]), let r = Double(m[3]), p + q + r > 0 {
            let unit = 180 / (p + q + r)
            tri.angle["A"] = p * unit; tri.angle["B"] = q * unit; tri.angle["C"] = r * unit
            given.append("∠A : ∠B : ∠C = \(m[1]) : \(m[2]) : \(m[3]) → 180° × 각각의 비율")
        }
        guard !given.isEmpty else { return nil }
        // 조건을 퍼뜨리기
        for _ in 0..<6 {
            if let (p, q) = equalPair {
                if let v = tri.angle[p], tri.angle[q] == nil { tri.angle[q] = v }
                if let v = tri.angle[q], tri.angle[p] == nil { tri.angle[p] = v }
                let apex = ["A", "B", "C"].map { Character($0) }.first { $0 != p && $0 != q }!
                if let v = tri.angle[apex], tri.angle[p] == nil { tri.angle[p] = (180 - v) / 2; tri.angle[q] = (180 - v) / 2 }
            }
            let known = tri.angle.filter { _ in true }
            if known.count == 2 {
                let missing = ["A", "B", "C"].map { Character($0) }.first { known[$0] == nil }!
                tri.angle[missing] = 180 - known.values.reduce(0, +)
            }
            // 직각: 빗변
            if let right = tri.angle.first(where: { abs($0.value - 90) < 1e-9 })?.key {
                let hyp = Character(right.lowercased())
                let legs = ["a", "b", "c"].map { Character($0) }.filter { $0 != hyp }
                if let h = tri.side[hyp], let l = tri.side[legs[0]], tri.side[legs[1]] == nil, h > l { tri.side[legs[1]] = (h * h - l * l).squareRoot() }
                if let h = tri.side[hyp], let l = tri.side[legs[1]], tri.side[legs[0]] == nil, h > l { tri.side[legs[0]] = (h * h - l * l).squareRoot() }
                if tri.side[hyp] == nil, let x = tri.side[legs[0]], let y = tri.side[legs[1]] { tri.side[hyp] = (x * x + y * y).squareRoot() }
            }
            // 세 변 → 각 (코사인법칙)
            if let a = tri.side["a"], let b = tri.side["b"], let c = tri.side["c"] {
                guard a + b > c, b + c > a, a + c > b else { return nil }
                if tri.angle["A"] == nil { tri.angle["A"] = acos((b * b + c * c - a * a) / (2 * b * c)) * 180 / .pi }
                if tri.angle["B"] == nil { tri.angle["B"] = acos((a * a + c * c - b * b) / (2 * a * c)) * 180 / .pi }
                if tri.angle["C"] == nil { tri.angle["C"] = acos((a * a + b * b - c * c) / (2 * a * b)) * 180 / .pi }
            }
            // 두 변과 끼인각 → 나머지 변
            for (opp, s1, s2) in [("a", "b", "c"), ("b", "a", "c"), ("c", "a", "b")] {
                let o = Character(opp), x = Character(s1), y = Character(s2)
                if tri.side[o] == nil, let p = tri.side[x], let q = tri.side[y], let g = tri.angle[Character(opp.uppercased())] {
                    tri.side[o] = (p * p + q * q - 2 * p * q * cos(g)).squareRoot()
                }
            }
            // 사인법칙: 변과 그 대각을 알면
            if let pair = ["a", "b", "c"].map({ Character($0) }).first(where: { tri.side[$0] != nil && tri.angle[Character($0.uppercased())] != nil }) {
                let k = tri.side[pair]! / sin(tri.angle[Character(pair.uppercased())]!)
                for s in ["a", "b", "c"].map({ Character($0) }) {
                    let big = Character(s.uppercased())
                    if tri.side[s] == nil, let g = tri.angle[big] { tri.side[s] = k * sin(g) }
                    // 각 구하기는 더 짧은 변일 때만 (예각으로 하나)
                    if tri.angle[big] == nil, let v = tri.side[s], v < tri.side[pair]!, abs(v / k) <= 1 { tri.angle[big] = asin(v / k) * 180 / .pi }
                }
            }
        }
        let concept = "직각삼각형은 피타고라스 정리 a² + b² = c²와 삼각비, 일반 삼각형은 코사인법칙 a² = b² + c² − 2bc cos A, 사인법칙 a/sin A = b/sin B = 2R로 풀어요."
        let givenStep = SolutionStep(hint: "주어진 것", work: given.joined(separator: ", "))
        // 묻는 것
        if has(t, ["외접원"]), has(t, ["반지름"]) {
            guard let pair = ["a", "b", "c"].map({ Character($0) }).first(where: { tri.side[$0] != nil && tri.angle[Character($0.uppercased())] != nil }),
                  let r = nice(tri.side[pair]! / (2 * sin(tri.angle[Character(pair.uppercased())]!))) else { return nil }
            let A = Character(pair.uppercased())
            return Solved(kind: .geometry, topic: "사인법칙과 외접원", concept: concept,
                          steps: [givenStep, SolutionStep(hint: "a/sin A = 2R", work: "\(nice(tri.side[pair]!) ?? d(tri.side[pair]!)) ÷ sin \(d(tri.angle[A]!))° = 2R → R = \(r)")], answer: r)
        }
        if has(t, ["넓이"]) {
            for (s1, s2, g) in [("b", "c", "A"), ("a", "c", "B"), ("a", "b", "C")] {
                guard let p = tri.side[Character(s1)], let q = tri.side[Character(s2)], let angle = tri.angle[Character(g)], let area = nice(p * q * sin(angle) / 2) else { continue }
                return Solved(kind: .geometry, topic: "두 변과 끼인각으로 구하는 삼각형의 넓이", concept: "삼각형의 넓이 = ½ × (두 변의 곱) × sin(끼인각)",
                              steps: [givenStep, SolutionStep(hint: "½ × \(nice(p) ?? d(p)) × \(nice(q) ?? d(q)) × sin \(d(angle))°", work: area)], answer: area)
            }
            return nil
        }
        if let m = match(t, #"(sin|cos|tan)\s*([A-C])\s*(?:의\s*값|×|\+|-|는|은|=\s*\?)"#), let key = m[2].first {
            guard let g = tri.angle[key] else { return nil }
            let v = m[1] == "sin" ? sin(g) : m[1] == "cos" ? cos(g) : Foundation.tan(g * .pi / 180)
            guard let shown = nice(v) else { return nil }
            var steps = [givenStep]
            if let right = tri.angle.first(where: { abs($0.value - 90) < 1e-9 })?.key, right != key {
                let hyp = Character(right.lowercased()), opp = Character(key.lowercased())
                let adj = ["a", "b", "c"].map { Character($0) }.first { $0 != hyp && $0 != opp }!
                func label(_ s: Character) -> String { String(["A", "B", "C"].filter { Character($0.lowercased()) != s }.joined()) }
                if let h = tri.side[hyp], let o = tri.side[opp], let a = tri.side[adj] {
                    steps.append(SolutionStep(hint: "피타고라스 정리로 세 변을 모두 구하면", work: "\(label(hyp)) = \(nice(h) ?? d(h)), \(label(opp)) = \(nice(o) ?? d(o)), \(label(adj)) = \(nice(a) ?? d(a))"))
                }
                let formula = m[1] == "sin" ? "(대변)/(빗변)" : m[1] == "cos" ? "(밑변)/(빗변)" : "(대변)/(밑변)"
                steps.append(SolutionStep(hint: "\(m[1]) \(key) = \(formula)", work: shown))
            } else {
                steps.append(SolutionStep(hint: "sin²A + cos²A = 1, tan A = sin A / cos A", work: "\(m[1]) \(key) = \(shown)"))
            }
            return Solved(kind: .geometry, topic: "삼각비", concept: "직각삼각형에서 sin = 높이/빗변, cos = 밑변/빗변, tan = 높이/밑변", steps: steps, answer: shown)
        }
        if let m = match(t, #"∠\s*([A-C])\s*의\s*외각"#), let key = m[1].first, let g = tri.angle[key] {
            return Solved(kind: .geometry, topic: "삼각형의 외각", concept: "삼각형의 한 외각의 크기는 그와 이웃하지 않는 두 내각의 크기의 합과 같아요 (= 180° − 그 내각).",
                          steps: [givenStep, SolutionStep(hint: "180° − ∠\(key)", work: "180° − \(d(g))° = \(d(180 - g))°")], answer: "\(d(abs(g - g.rounded()) < 1e-6 ? 180 - g.rounded() : 180 - g))°")
        }
        if let m = match(t, #"(?:∠\s*)?(?<![A-Za-z])([A-C])\s*의\s*크기"#), let key = m[1].first {
            guard let g = tri.angle[key], abs(g - g.rounded()) < 1e-6 else { return nil }
            return Solved(kind: .geometry, topic: "삼각형의 각", concept: concept,
                          steps: [givenStep, SolutionStep(hint: "삼각형의 세 각의 합은 180°, 세 변을 알면 cos A = (b² + c² − a²)/2bc", work: "∠\(key) = \(d(g.rounded()))°")], answer: "\(d(g.rounded()))°")
        }
        var asked: Character?
        if let m = match(t, #"(?<![A-Za-z])([A-C]{2})\s*의\s*(?:길이|값)"#) ?? match(t, #"(?<![A-Za-z])([A-C]{2})\s*(?:는|은|를|을)\s*(?:\?|구하|$)"#) { asked = sideKey(m[1]) }
        else if has(t, ["삼각형 ABC", "△ABC"]), let m = match(t, #"(?<![A-Za-z])([abc])\s*의\s*(?:값|길이)"#) { asked = m[1].first }
        guard let key = asked, let v = tri.side[key], let shown = nice(v) else { return nil }
        var steps = [givenStep]
        if tri.angle.values.contains(where: { abs($0 - 90) < 1e-9 }) && tri.angle.count <= 1 {
            steps.append(SolutionStep(hint: "피타고라스 정리 (빗변)² = (나머지 두 변의 제곱의 합)", work: shown))
            return Solved(kind: .geometry, topic: "피타고라스 정리", concept: "직각삼각형에서 빗변의 길이를 c라 하면 a² + b² = c²", steps: steps, answer: shown)
        }
        steps.append(SolutionStep(hint: "삼각비(사인법칙·코사인법칙)로 구하면", work: shown))
        return Solved(kind: .geometry, topic: "삼각형의 변의 길이", concept: concept, steps: steps, answer: shown)
    }

    // MARK: - 두 변과 끼인각 (꼭짓점 이름 없이)

    private static func twoSidesArea(_ t: String) -> Solved? {
        guard has(t, ["넓이"]), let m = match(t, #"두\s*변의\s*길이가\s*(?:각각\s*)?(\d+(?:\.\d+)?)\s*(?:cm|m)?\s*,\s*(\d+(?:\.\d+)?)\s*(?:cm|m)?\s*이고\s*(?:그\s*)?끼인각의\s*크기가\s*(\d+(?:\.\d+)?)\s*°"#),
              let p = Double(m[1]), let q = Double(m[2]), let g = Double(m[3]), let area = nice(p * q * sin(g) / 2) else { return nil }
        return Solved(kind: .geometry, topic: "두 변과 끼인각으로 구하는 삼각형의 넓이", concept: "삼각형의 넓이 = ½ × (두 변의 곱) × sin(끼인각)",
                      steps: [SolutionStep(hint: "½ × \(d(p)) × \(d(q)) × sin \(d(g))°", work: area)], answer: area)
    }

    // MARK: - 세 점이 꼭짓점인 삼각형의 넓이

    private static func threePointArea(_ t: String) -> Solved? {
        guard has(t, ["넓이"]), has(t, ["삼각형"]) else { return nil }
        let pts = DoitMathTopics.points(in: t)
        guard pts.count == 3 else { return nil }
        let (a, b, c) = (pts[0], pts[1], pts[2])
        let twice = a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y)
        return Solved(kind: .coordinate, topic: "세 점으로 이루어진 삼각형의 넓이", concept: "신발끈 공식: ½|x₁(y₂−y₃) + x₂(y₃−y₁) + x₃(y₁−y₂)|",
                      steps: [SolutionStep(hint: "신발끈 공식에 넣으면", work: "½ × |\(f(twice))| = \(f(abs(twice) / 2))")], answer: f(abs(twice) / 2))
    }

    // MARK: - 평행선과 선분의 비 (DE // BC)

    private static func parallelLines(_ t: String) -> Solved? {
        guard let m = match(t, #"([A-Z]{2})\s*(?://|∥|ǁ|\|\|)\s*([A-Z]{2})"#) else { return nil }
        let de = m[1], bc = m[2]
        guard de == "DE" || de == "ED", bc == "BC" || bc == "CB" else { return nil }
        var seg: [String: Double] = [:]
        func norm(_ s: String) -> String { String(s.sorted()) }
        for mm in matches(t, #"(?<![A-Z])([A-Z]{2})\s*=\s*(\d+(?:\.\d+)?)"#) { if let v = Double(mm[2]) { seg[norm(mm[1])] = v } }
        guard let askM = match(t, #"(?<![A-Z])([A-Z]{2})\s*의\s*길이"#) else { return nil }
        let ask = norm(askM[1])
        for _ in 0..<4 {
            if seg["AB"] == nil, let x = seg["AD"], let y = seg["BD"] { seg["AB"] = x + y }
            if seg["AC"] == nil, let x = seg["AE"], let y = seg["CE"] { seg["AC"] = x + y }
            if seg["BD"] == nil, let x = seg["AB"], let y = seg["AD"] { seg["BD"] = x - y }
            if seg["CE"] == nil, let x = seg["AC"], let y = seg["AE"] { seg["CE"] = x - y }
            var k: Double?
            if let x = seg["AD"], let y = seg["AB"], y > 0 { k = x / y }
            else if let x = seg["AE"], let y = seg["AC"], y > 0 { k = x / y }
            else if let x = seg["DE"], let y = seg["BC"], y > 0 { k = x / y }
            else if let x = seg["AD"], let y = seg["BD"] { k = x / (x + y) }
            else if let x = seg["AE"], let y = seg["CE"] { k = x / (x + y) }
            guard let r = k, r > 0, r < 1 else { continue }
            for (part, whole) in [("AD", "AB"), ("AE", "AC"), ("DE", "BC")] {
                if seg[part] == nil, let w = seg[whole] { seg[part] = r * w }
                if seg[whole] == nil, let p = seg[part] { seg[whole] = p / r }
            }
            // AD : DB = AE : EC
            if seg["CE"] == nil, let ae = seg["AE"] { seg["CE"] = ae * (1 - r) / r }
            if seg["BD"] == nil, let ad = seg["AD"] { seg["BD"] = ad * (1 - r) / r }
        }
        guard let v = seg[ask], let shown = nice(v) else { return nil }
        return Solved(kind: .geometry, topic: "삼각형에서 평행선과 선분의 길이의 비", concept: "DE ∥ BC 이면 AD : AB = AE : AC = DE : BC, AD : DB = AE : EC",
                      steps: [SolutionStep(hint: "평행선이 만드는 닮은 삼각형 △ADE ∽ △ABC", work: "AD : AB = AE : AC = DE : BC"),
                              SolutionStep(hint: "비례식을 풀면", work: "\(askM[1]) = \(shown)")],
                      answer: shown)
    }

    // MARK: - 닮음 (△ABC ∽ △DEF)

    private static func similar(_ t: String) -> Solved? {
        guard let m = match(t, #"△\s*([A-Z]{3})\s*∽\s*△\s*([A-Z]{3})"#) else { return nil }
        let p = Array(m[1]), q = Array(m[2])
        var map: [Character: Character] = [:]
        for i in 0..<3 { map[p[i]] = q[i]; map[q[i]] = p[i] }
        var seg: [String: Double] = [:]
        func norm(_ s: String) -> String { String(s.sorted()) }
        for mm in matches(t, #"(?<![A-Z])([A-Z]{2})\s*=\s*(\d+(?:\.\d+)?)"#) { if let v = Double(mm[2]) { seg[norm(mm[1])] = v } }
        guard let askM = match(t, #"(?<![A-Z])([A-Z]{2})\s*의\s*길이"#) else { return nil }
        func partner(_ s: String) -> String? {
            let mapped = s.compactMap { map[$0] }
            return mapped.count == 2 ? norm(String(mapped)) : nil
        }
        let first = Set(p)
        // 닮음비 (첫 삼각형 : 둘째 삼각형)
        var ratio: Double?
        for (k, v) in seg where Set(k).isSubset(of: first) {
            if let other = partner(k), let w = seg[other], w > 0 { ratio = v / w; break }
        }
        let ask = norm(askM[1])
        guard let r = ratio, let other = partner(ask), let known = seg[other] else { return nil }
        let v = Set(ask).isSubset(of: first) ? known * r : known / r
        guard let shown = nice(v) else { return nil }
        return Solved(kind: .geometry, topic: "닮은 도형의 대응변", concept: "닮은 두 도형에서 대응변의 길이의 비(닮음비)는 일정해요. 꼭짓점을 쓴 순서대로 대응해요.",
                      steps: [SolutionStep(hint: "대응하는 변끼리 비를 구하면 닮음비", work: "\(f(r)) (= \(m[1]) : \(m[2]))"),
                              SolutionStep(hint: "\(askM[1])에 대응하는 변은 \(other)", work: "\(askM[1]) = \(shown)")],
                      answer: shown)
    }

    // MARK: - 합동 (△ABC ≡ △DEF): 대응변의 길이, 대응각의 크기는 같음

    private static func congruent(_ t: String) -> Solved? {
        guard let m = match(t, #"△\s*([A-Z]{3})\s*≡\s*△\s*([A-Z]{3})"#) else { return nil }
        let p = Array(m[1]), q = Array(m[2])
        guard Set(p).count == 3, Set(q).count == 3 else { return nil }
        var map: [Character: Character] = [:]
        for i in 0..<3 { map[p[i]] = q[i]; map[q[i]] = p[i] }
        func norm(_ s: String) -> String { String(s.sorted()) }
        var seg: [String: Double] = [:]
        for mm in matches(t, #"(?<![A-Z])([A-Z]{2})\s*=\s*(\d+(?:\.\d+)?)(?!\s*°)"#) { if let v = Double(mm[2]) { seg[norm(mm[1])] = v } }
        var angle: [Character: Double] = [:]
        for mm in matches(t, #"∠\s*([A-Z])\s*=\s*(\d+(?:\.\d+)?)\s*°"#) { if let c = mm[1].first, let v = Double(mm[2]) { angle[c] = v } }
        // 한 삼각형의 두 각을 알면 나머지 각 (세 각의 합 180°)
        for tri in [p, q] {
            let known = tri.filter { angle[$0] != nil }
            if known.count == 2, let missing = tri.first(where: { angle[$0] == nil }) {
                let rest = 180 - known.reduce(0) { $0 + angle[$1]! }
                guard rest > 0 else { return nil }
                angle[missing] = rest
            }
        }
        let concept = "합동인 두 도형은 대응변의 길이와 대응각의 크기가 각각 같아요. 꼭짓점을 쓴 순서대로 대응해요."
        if let ask = match(t, #"(?<![A-Z])([A-Z]{2})\s*의\s*길이"#) {
            let key = norm(ask[1])
            let mapped = ask[1].compactMap { map[$0] }
            guard mapped.count == 2 else { return nil }
            let other = norm(String(mapped))
            guard let v = seg[key] ?? seg[other], let shown = nice(v) else { return nil }
            return Solved(kind: .geometry, topic: "합동인 도형의 대응변", concept: concept,
                          steps: [SolutionStep(hint: "\(ask[1])에 대응하는 변은 \(String(mapped))", work: "\(ask[1]) = \(String(mapped)) = \(shown)")], answer: shown)
        }
        if let ask = match(t, #"∠\s*([A-Z])\s*의\s*크기"#), let c = ask[1].first, let partner = map[c] {
            guard let v = angle[c] ?? angle[partner], v > 0, v < 180 else { return nil }
            return Solved(kind: .geometry, topic: "합동인 도형의 대응각", concept: concept,
                          steps: [SolutionStep(hint: "∠\(c)에 대응하는 각은 ∠\(partner)", work: "∠\(c) = ∠\(partner) = \(d(v))°")], answer: "\(d(v))°")
        }
        return nil
    }

    // MARK: - 평행사변형 ABCD: 마주 보는 각은 같고, 이웃한 두 각의 합은 180°

    private static func parallelogram(_ t: String) -> Solved? {
        guard let m = match(t, #"(?:사각형|□)\s*([A-Z]{4})\s*(?:는|은|이|가)?\s*(평행사변형|마름모)"#) ?? match(t, #"(평행사변형|마름모)\s*([A-Z]{4})"#).map({ [$0[0], $0[2], $0[1]] }) else { return nil }
        let v = Array(m[1])
        guard Set(v).count == 4 else { return nil }
        let given = matches(t, #"∠\s*([A-Z])\s*=\s*(\d+(?:\.\d+)?)\s*°"#)
        guard given.count == 1, let g = given[0][1].first, let gv = Double(given[0][2]), gv > 0, gv < 180, let gi = v.firstIndex(of: g),
              let ask = match(t, #"∠\s*([A-Z])\s*의\s*크기"#), let a = ask[1].first, let ai = v.firstIndex(of: a), ai != gi else { return nil }
        let opposite = (gi + 2) % 4 == ai
        let value = opposite ? gv : 180 - gv
        return Solved(kind: .geometry, topic: "평행사변형의 성질", concept: "평행사변형은 두 쌍의 대각의 크기가 각각 같고, 이웃한 두 내각의 크기의 합은 180°예요.",
                      steps: [SolutionStep(hint: opposite ? "∠\(a)는 ∠\(g)의 대각" : "∠\(a)는 ∠\(g)와 이웃한 각", work: opposite ? "∠\(a) = ∠\(g) = \(d(gv))°" : "180° − \(d(gv))° = \(d(value))°")],
                      answer: "\(d(value))°")
    }

    // MARK: - 평행선의 동위각·엇각, 맞꼭지각 (글로 관계를 밝힌 문제만: 그림이 필요한 문제는 안 풂)

    private static func parallelAngles(_ t: String) -> Solved? {
        guard let rel = match(t, #"(동위각|엇각|맞꼭지각)"#)?[1] else { return nil }
        // 동위각·엇각은 평행할 때만 크기가 같음
        if rel != "맞꼭지각" { guard has(t, ["∥", "//", "평행"]) else { return nil } }
        guard !has(t, ["동측내각", "같은 쪽", "그림"]) else { return nil }
        let given = matches(t, #"∠\s*([a-z])\s*=\s*(\d+(?:\.\d+)?)\s*°"#)
        guard given.count == 1, let g = given[0][1].first, let gv = Double(given[0][2]), gv > 0, gv < 180 else { return nil }
        // "∠a와 ∠b는 동위각", "∠b는 ∠a의 엇각", "∠a의 동위각 ∠b"처럼 두 각의 관계를 글로 말해야 함
        let names = Set(matches(t, #"∠\s*([a-z])(?![A-Za-z])"#).compactMap { $0[1].first })
        guard names.count == 2, names.contains(g), let asked = names.first(where: { $0 != g }) else { return nil }
        let a = String(asked), pair = "[" + String(g) + String(asked) + "]"
        guard t.range(of: "∠\\s*" + a + "\\s*(?:의\\s*크기|의\\s*값|(?:는|은)\\s*\\?)", options: .regularExpression) != nil,
              t.range(of: "∠\\s*" + pair + "\\s*(?:와|과|의|는|은)?\\s*(?:∠\\s*" + pair + "\\s*(?:의|는|은|가|이)?\\s*)?" + rel, options: .regularExpression) != nil else { return nil }
        let reason = rel == "맞꼭지각" ? "맞꼭지각의 크기는 서로 같아요." : "평행한 두 직선이 다른 한 직선과 만날 때 생기는 \(rel)의 크기는 서로 같아요."
        return Solved(kind: .geometry, topic: rel == "맞꼭지각" ? "맞꼭지각" : "평행선과 \(rel)", concept: reason,
                      steps: [SolutionStep(hint: "∠\(asked)와 ∠\(g)는 \(rel)", work: "∠\(asked) = ∠\(g) = \(d(gv))°")], answer: "\(d(gv))°")
    }

    /// "닮음비가 2 : 3인 두 삼각형의 넓이의 비"
    private static func similarityRatio(_ t: String) -> Solved? {
        guard let m = match(t, #"닮음비(?:가|는)\s*(\d+)\s*:\s*(\d+)"#), let a = Int(m[1]), let b = Int(m[2]) else { return nil }
        if has(t, ["넓이의 비", "겉넓이의 비", "넓이 비"]) {
            return Solved(kind: .geometry, topic: "닮음비와 넓이의 비", concept: "닮음비가 m : n이면 넓이의 비는 m² : n², 부피의 비는 m³ : n³",
                          steps: [SolutionStep(hint: "넓이의 비는 닮음비의 제곱", work: "\(a)² : \(b)²")], answer: "\(a * a) : \(b * b)")
        }
        if has(t, ["부피의 비", "부피 비"]) {
            return Solved(kind: .geometry, topic: "닮음비와 부피의 비", concept: "닮음비가 m : n이면 넓이의 비는 m² : n², 부피의 비는 m³ : n³",
                          steps: [SolutionStep(hint: "부피의 비는 닮음비의 세제곱", work: "\(a)³ : \(b)³")], answer: "\(a * a * a) : \(b * b * b)")
        }
        if has(t, ["둘레의 비", "둘레의 길이의 비"]) {
            return Solved(kind: .geometry, topic: "닮음비와 둘레의 비", concept: "닮은 도형의 둘레의 비는 닮음비와 같아요.", steps: [SolutionStep(hint: "둘레의 비 = 닮음비", work: "\(a) : \(b)")], answer: "\(a) : \(b)")
        }
        return nil
    }

    // MARK: - 원: 원주각과 중심각, 지름에 대한 원주각, 접선의 길이

    private static func circleAngles(_ t: String) -> Solved? {
        guard has(t, ["원주각", "∠APB", "원 위의 점", "원 O"]) else { return nil }
        if has(t, ["지름"]), has(t, ["원주각", "∠APB", "원 위의 점"]), !has(t, ["중심각의 크기가", "원주각의 크기가"]) {
            return Solved(kind: .geometry, topic: "반원에 대한 원주각", concept: "지름에 대한 원주각(반원에 대한 원주각)은 항상 90°예요.",
                          steps: [SolutionStep(hint: "지름 AB에 대한 중심각은 180°, 원주각은 그 절반", work: "180° ÷ 2 = 90°")], answer: "90°")
        }
        guard let m = match(t, #"(중심각|원주각)(?:\s*∠\s*[A-Z]{3})?(?:의\s*크기)?\s*(?:가|이|은|는|=)\s*(\d+(?:\.\d+)?)\s*°"#), let v = Double(m[2]) else { return nil }
        if m[1] == "중심각", has(t, ["원주각"]) {
            return Solved(kind: .geometry, topic: "원주각과 중심각", concept: "한 호에 대한 원주각의 크기는 그 호에 대한 중심각의 크기의 ½이에요.",
                          steps: [SolutionStep(hint: "원주각 = 중심각 ÷ 2", work: "\(d(v))° ÷ 2 = \(d(v / 2))°")], answer: "\(d(v / 2))°")
        }
        if m[1] == "원주각", has(t, ["중심각"]) {
            return Solved(kind: .geometry, topic: "원주각과 중심각", concept: "한 호에 대한 중심각의 크기는 원주각의 크기의 2배예요.",
                          steps: [SolutionStep(hint: "중심각 = 원주각 × 2", work: "\(d(v))° × 2 = \(d(v * 2))°")], answer: "\(d(v * 2))°")
        }
        return nil
    }

    private static func tangentLength(_ t: String) -> Solved? {
        guard has(t, ["접선"]), has(t, ["접점"]), let om = match(t, #"O([A-Z])\s*=\s*(\d+(?:\.\d+)?)"#), let op = Double(om[2]),
              let rm = match(t, #"반지름(?:의\s*길이)?(?:가|는|이)\s*(\d+(?:\.\d+)?)"#), let r = Double(rm[1]), op > r,
              let ask = match(t, #"(?<![A-Z])([A-Z]{2})\s*의\s*길이"#), ask[1].contains(om[1]), !ask[1].contains("O") else { return nil }
        guard let shown = nice((op * op - r * r).squareRoot()) else { return nil }
        return Solved(kind: .geometry, topic: "원의 접선의 길이", concept: "원의 접선은 접점을 지나는 반지름과 수직이에요 → 직각삼각형에서 피타고라스 정리",
                      steps: [SolutionStep(hint: "∠OT\(om[1]) = 90°이므로", work: "\(ask[1])² = \(d(op))² − \(d(r))² = \(d(op * op - r * r))"),
                              SolutionStep(hint: "제곱근", work: shown)],
                      answer: shown)
    }
}
