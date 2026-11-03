import Foundation

/// 두잇 AI 대수 엔진 (외부 AI 없이 직접 계산)
/// - 인수분해 (공통인수, 인수정리 + 조립제법, 사차식 → 이차식 두 개)
/// - 삼차·사차 이상 방정식, 일차·이차·고차 부등식, 연립부등식, 절댓값
/// - 연립일차방정식 (미지수 2~3개), 미분·적분, 합성함수·역함수
enum DoitAlgebra {
    typealias Poly = DoitMath.Poly

    // MARK: - 글자 정리

    /// 여러 가지 수식 기호를 계산하기 쉬운 모양으로
    static func normalize(_ raw: String) -> String {
        var t = raw
        let table: [(String, String)] = [
            ("−", "-"), ("–", "-"), ("—", "-"), ("×", "*"), ("·", "*"), ("÷", "/"), ("＝", "="), ("＋", "+"),
            ("²", "^2"), ("³", "^3"), ("⁴", "^4"), ("⁵", "^5"), ("⁶", "^6"), ("≦", "≤"), ("≧", "≥"),
            ("<=", "≤"), (">=", "≥"), ("=<", "≤"), ("=>", "≥"), ("（", "("), ("）", ")"), ("，", ","), ("X", "x"), ("Y", "y")
        ]
        for (from, to) in table { t = t.replacingOccurrences(of: from, with: to) }
        return t
    }

    /// 문장에서 수식 부분만 (허용 글자 연속 구간 중 가장 긴 것)
    static func extract(_ text: String, extra: String = "") -> String {
        let allowed = Set("0123456789.+-*/^=()[]xyz√ |" + extra)
        var best = "", current = ""
        func commit() {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if trimmed.count > best.count, trimmed.contains(where: { $0.isNumber || $0 == "x" || $0 == "y" }) { best = trimmed }
            current = ""
        }
        for ch in normalize(text) {
            if allowed.contains(ch) { current.append(ch) } else { commit() }
        }
        commit()
        return best
    }

    static func has(_ text: String, _ words: [String]) -> Bool { words.contains { text.contains($0) } }

    // MARK: - 여러 문자 다항식 (x, y, z)

    struct Mono: Hashable {
        var x = 0, y = 0, z = 0
        var degree: Int { x + y + z }
    }

    struct MPoly {
        var t: [Mono: Double] = [:]

        static func constant(_ v: Double) -> MPoly { MPoly(t: [Mono(): v]) }
        static func variable(_ name: Character) -> MPoly {
            switch name {
            case "y": return MPoly(t: [Mono(y: 1): 1])
            case "z": return MPoly(t: [Mono(z: 1): 1])
            default: return MPoly(t: [Mono(x: 1): 1])
            }
        }

        var cleaned: MPoly { MPoly(t: t.filter { abs($0.value) > 1e-10 }) }
        var degree: Int { cleaned.t.keys.map(\.degree).max() ?? -1 }
        var isConstant: Bool { degree <= 0 }
        var constantValue: Double { t[Mono()] ?? 0 }
        func coef(x: Int = 0, y: Int = 0, z: Int = 0) -> Double { t[Mono(x: x, y: y, z: z)] ?? 0 }
        var variables: [Character] {
            let keys = cleaned.t.keys
            var result: [Character] = []
            if keys.contains(where: { $0.x > 0 }) { result.append("x") }
            if keys.contains(where: { $0.y > 0 }) { result.append("y") }
            if keys.contains(where: { $0.z > 0 }) { result.append("z") }
            return result
        }

        /// x만 있는 다항식이면 Poly로
        var univariate: Poly? {
            var p = Poly()
            for (mono, value) in cleaned.t {
                guard mono.y == 0, mono.z == 0, mono.x < Poly.size else { return nil }
                p.c[mono.x] += value
            }
            return p
        }

        static func + (l: MPoly, r: MPoly) -> MPoly {
            var out = l
            for (k, v) in r.t { out.t[k, default: 0] += v }
            return out.cleaned
        }
        static prefix func - (p: MPoly) -> MPoly { MPoly(t: p.t.mapValues { -$0 }) }
        static func - (l: MPoly, r: MPoly) -> MPoly { l + (-r) }
        static func * (l: MPoly, r: MPoly) -> MPoly? {
            var out = MPoly()
            for (a, va) in l.t {
                for (b, vb) in r.t {
                    let m = Mono(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z)
                    guard m.degree <= 8 else { return nil }
                    out.t[m, default: 0] += va * vb
                }
            }
            return out.cleaned
        }

        func value(x: Double, y: Double = 0, z: Double = 0) -> Double {
            t.reduce(0) { $0 + $1.value * pow(x, Double($1.key.x)) * pow(y, Double($1.key.y)) * pow(z, Double($1.key.z)) }
        }
    }

    /// 수식 → 다항식 (실패하면 nil)
    static func parse(_ raw: String) -> MPoly? {
        var text = normalize(raw).replacingOccurrences(of: " ", with: "")
        text = text.replacingOccurrences(of: "[", with: "(").replacingOccurrences(of: "]", with: ")")
        // 휴대폰으로 쓴 x2 → x^2
        text = text.replacingOccurrences(of: "([xyz])([2-8])(?![0-9.])", with: "$1^$2", options: .regularExpression)
        guard !text.isEmpty else { return nil }
        var parser = MParser(chars: Array(text))
        guard let result = parser.expression(), parser.i == parser.chars.count else { return nil }
        return result
    }

    private struct MParser {
        let chars: [Character]
        var i = 0
        private var peek: Character? { i < chars.count ? chars[i] : nil }

        mutating func expression() -> MPoly? {
            guard var value = term() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                i += 1
                guard let rhs = term() else { return nil }
                value = op == "+" ? value + rhs : value - rhs
            }
            return value
        }

        mutating func term() -> MPoly? {
            guard var value = unary() else { return nil }
            while let next = peek {
                if next == "*" || next == "/" {
                    i += 1
                    guard let rhs = unary() else { return nil }
                    if next == "*" {
                        guard let product = value * rhs else { return nil }
                        value = product
                    } else {
                        guard rhs.isConstant, abs(rhs.constantValue) > 1e-12,
                              let q = value * .constant(1 / rhs.constantValue) else { return nil }
                        value = q
                    }
                } else if next == "(" || "xyz√".contains(next) || next.isNumber {
                    guard let rhs = power(), let product = value * rhs else { return nil }
                    value = product
                } else {
                    break
                }
            }
            return value
        }

        mutating func unary() -> MPoly? {
            if peek == "-" { i += 1; return unary().map { -$0 } }
            if peek == "+" { i += 1; return unary() }
            return power()
        }

        mutating func power() -> MPoly? {
            guard let base = primary() else { return nil }
            guard peek == "^" else { return base }
            i += 1
            guard let exponent = unary(), exponent.isConstant else { return nil }
            let n = exponent.constantValue
            if base.isConstant { return .constant(pow(base.constantValue, n)) }
            guard n >= 0, n == n.rounded(), n <= 8 else { return nil }
            var result = MPoly.constant(1)
            for _ in 0..<Int(n) {
                guard let product = result * base else { return nil }
                result = product
            }
            return result
        }

        mutating func primary() -> MPoly? {
            guard let c = peek else { return nil }
            if c == "(" {
                i += 1
                guard let inner = expression(), peek == ")" else { return nil }
                i += 1
                return inner
            }
            if "xyz".contains(c) { i += 1; return .variable(c) }
            if c == "√" {
                i += 1
                guard let inner = power(), inner.isConstant, inner.constantValue >= 0 else { return nil }
                return .constant(inner.constantValue.squareRoot())
            }
            var number = ""
            while let d = peek, d.isNumber || d == "." { number.append(d); i += 1 }
            guard let value = Double(number) else { return nil }
            return .constant(value)
        }
    }

    // MARK: - 보기 좋게

    static func f(_ v: Double) -> String { DoitMath.fraction(v) }

    /// 여러 문자 다항식 보기 좋게 (2x + 3y − 6)
    static func describe(_ p: MPoly) -> String {
        let monos = p.cleaned.t.sorted { a, b in
            if a.key.degree != b.key.degree { return a.key.degree > b.key.degree }
            if a.key.x != b.key.x { return a.key.x > b.key.x }
            if a.key.y != b.key.y { return a.key.y > b.key.y }
            return a.key.z > b.key.z
        }
        guard !monos.isEmpty else { return "0" }
        var text = ""
        for (index, (mono, value)) in monos.enumerated() {
            let sign = value < 0 ? "−" : "+"
            let magnitude = abs(value)
            var vars = ""
            if mono.x > 0 { vars += "x" + DoitMath.superscript(mono.x) }
            if mono.y > 0 { vars += "y" + DoitMath.superscript(mono.y) }
            if mono.z > 0 { vars += "z" + DoitMath.superscript(mono.z) }
            var number = (!vars.isEmpty && abs(magnitude - 1) < 1e-9) ? "" : f(magnitude)
            if !vars.isEmpty && number.contains("/") { number = "(\(number))" }
            if index == 0 {
                text = (value < 0 ? "−" : "") + number + vars
            } else {
                text += " \(sign) \(number)\(vars)"
            }
        }
        return text
    }

    /// √n 간단히: 12 → (2, 3) 즉 2√3
    static func simplifyRoot(_ n: Int) -> (outside: Int, inside: Int) {
        guard n > 0 else { return (0, 0) }
        // 너무 큰 수는 나누어 보지 않음 (오래 걸리거나 곱셈이 넘침)
        guard n < 1_000_000_000_000 else { return (1, n) }
        var outside = 1, inside = n, k = 2
        while k * k <= inside {
            while inside % (k * k) == 0 { inside /= k * k; outside *= k }
            k += 1
        }
        return (outside, inside)
    }

    /// k√m 글자로
    static func rootText(_ outside: Int, _ inside: Int) -> String {
        if inside == 1 { return String(outside) }
        return (outside == 1 ? "" : String(outside)) + "√\(inside)"
    }

    /// √n 을 간단한 모양으로 (정수면 정수)
    static func sqrtText(_ value: Double) -> String {
        guard value >= 0 else { return "√(\(f(value)))" }
        if abs(value - value.rounded()) < 1e-9 {
            let s = simplifyRoot(DoitMath.safeInt(value))
            return rootText(s.outside, s.inside)
        }
        // 분수: √(n/d) = √(n·d)/d
        for d in 2...100 {
            let n = value * Double(d)
            guard abs(n - n.rounded()) < 1e-7 else { continue }
            let s = simplifyRoot(DoitMath.safeInt(n) * d)
            let g = gcd(s.outside, d)
            let top = rootText(s.outside / g, s.inside), bottom = d / g
            return bottom == 1 ? top : "\(top)/\(bottom)"
        }
        let r = value.squareRoot()
        if abs(r - r.rounded()) < 1e-9 { return String(DoitMath.safeInt(r)) }
        return "√\(f(value)) ≈ \(DoitMath.format(r, digits: 5))"
    }

    // MARK: - 정수 계수

    static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = abs(a), b = abs(b)
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }

    /// 계수를 정수로 (분수면 분모를 곱함). [낮은 차수 → 높은 차수]
    static func integerCoefficients(_ p: Poly) -> (coefficients: [Int], scale: Int)? {
        let degree = p.degree
        guard degree >= 0 else { return nil }
        for scale in [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 24, 30, 60, 100, 120] {
            var out: [Int] = []
            var ok = true
            for i in 0...degree {
                let v = p[i] * Double(scale)
                guard abs(v - v.rounded()) < 1e-7, abs(v) < 1e9 else { ok = false; break }
                out.append(DoitMath.safeInt(v))
            }
            if ok { return (out, scale) }
        }
        return nil
    }

    static func divisors(_ n: Int) -> [Int] {
        let n = abs(n)
        guard n > 0 else { return [] }
        var result: [Int] = []
        var k = 1
        while k * k <= n {
            if n % k == 0 { result.append(k); if k != n / k { result.append(n / k) } }
            k += 1
        }
        return result.sorted()
    }

    /// 정수 계수 [낮은 → 높은]를 (qx − p)로 나눈 몫 (나누어떨어질 때만)
    static func divide(_ a: [Int], byRoot p: Int, _ q: Int) -> [Int]? {
        // 높은 차수부터 조립제법: a(x) = (qx − p) b(x)
        let n = a.count - 1
        guard n >= 1 else { return nil }
        var b = Array(repeating: 0, count: n)
        var carry = 0
        for k in stride(from: n, through: 1, by: -1) {
            let value = a[k] + carry
            guard value % q == 0 else { return nil }
            b[k - 1] = value / q
            carry = b[k - 1] * p
        }
        guard a[0] + carry == 0 else { return nil }
        return b
    }

    static func polyFromInts(_ a: [Int]) -> Poly {
        var p = Poly()
        for (i, v) in a.enumerated() where i < Poly.size { p.c[i] = Double(v) }
        return p
    }

    // MARK: - 인수분해

    struct Factorization {
        var content: Int = 1
        var xPower = 0
        /// (q, p, 거듭제곱): (qx − p)^k
        var linear: [(q: Int, p: Int, power: Int)] = []
        /// 더 나눠지지 않는 식 (정수 계수, 낮은 → 높은)
        var rest: [[Int]] = []
        var steps: [SolutionStep] = []
        /// 원래 식의 분모 (계수가 분수였을 때)
        var scale = 1

        var text: String {
            var parts: [String] = []
            if xPower > 0 { parts.append("x" + DoitMath.superscript(xPower)) }
            for factor in linear {
                let body = linearText(q: factor.q, p: factor.p)
                if linear.count == 1 && parts.isEmpty && rest.isEmpty && factor.power == 1 && content == 1 {
                    parts.append(body)
                } else {
                    parts.append("(\(body))" + DoitMath.superscript(factor.power))
                }
            }
            for r in rest {
                let body = DoitMath.describe(polyFromInts(r))
                parts.append(parts.isEmpty && rest.count == 1 && linear.isEmpty ? body : "(\(body))")
            }
            var head = ""
            if content == -1 { head = "−" } else if content != 1 { head = String(content) }
            if scale != 1 { head = "(1/\(scale))" + (head.isEmpty ? "" : "×" + head) }
            // 괄호 없이 시작하는 경우 곱셈이 헷갈리지 않게
            if !head.isEmpty, let first = parts.first, !first.hasPrefix("("), !first.hasPrefix("x") {
                parts[0] = "(\(first))"
            }
            return head + parts.joined()
        }

        var isTrivial: Bool { linear.isEmpty && xPower == 0 && content == 1 && rest.count <= 1 }
    }

    static func linearText(q: Int, p: Int) -> String {
        let lead = q == 1 ? "x" : "\(q)x"
        if p == 0 { return lead }
        return p > 0 ? "\(lead) − \(p)" : "\(lead) + \(-p)"
    }

    static func factor(_ poly: Poly) -> Factorization? {
        guard poly.degree >= 1, let (ints, scale) = integerCoefficients(poly) else { return nil }
        var a = ints
        var result = Factorization()
        result.scale = scale
        // 1) 공통인수
        var g = a.reduce(0) { gcd($0, $1) }
        if (a.last ?? 0) < 0 { g = -g }
        if abs(g) > 1 || g == -1 {
            a = a.map { $0 / g }
            result.content = g
            if abs(g) > 1 { result.steps.append(SolutionStep(hint: "공통인수를 먼저 묶어요", work: "\(g)로 묶으면 \(g)(\(DoitMath.describe(polyFromInts(a))))")) }
        }
        // 2) x로 묶기
        while a.count > 1 && a[0] == 0 { a.removeFirst(); result.xPower += 1 }
        if result.xPower > 0 {
            result.steps.append(SolutionStep(hint: "모든 항에 x가 있어요", work: "x\(DoitMath.superscript(result.xPower))로 묶으면 남는 식: \(DoitMath.describe(polyFromInts(a)))"))
        }
        // 3) 인수정리 + 조립제법
        while a.count >= 2 {
            if a.count == 2 {
                // 남은 일차식 ax + b (계수의 최대공약수는 1, a > 0)
                append(&result, q: a[1], p: -a[0])
                a = [1]
                break
            }
            let leading = a.last!, constant = a[0]
            var candidates: [(Int, Int)] = []
            for p in divisors(constant) {
                for q in divisors(leading) where gcd(p, q) == 1 {
                    candidates.append((p, q))
                    candidates.append((-p, q))
                }
            }
            candidates.sort { abs(Double($0.0) / Double($0.1)) < abs(Double($1.0) / Double($1.1)) }
            var found = false
            for (p, q) in candidates {
                guard let quotient = divide(a, byRoot: p, q) else { continue }
                let rootText = q == 1 ? String(p) : "\(p)/\(q)"
                let before = DoitMath.describe(polyFromInts(a))
                result.steps.append(SolutionStep(
                    hint: "x = \(rootText)을 넣으면 0이 되나요? (인수정리)",
                    work: "f(\(rootText)) = 0 이므로 \(linearText(q: q, p: p))가 인수예요. \(before)을 조립제법으로 나누면 몫은 \(DoitMath.describe(polyFromInts(quotient)))"
                ))
                append(&result, q: q, p: p)
                a = quotient
                found = true
                break
            }
            if !found { break }
        }
        // 4) 남은 식: 사차식은 이차식 두 개로 나눠보기
        if a.count == 5, let pair = quarticSplit(a) {
            result.steps.append(SolutionStep(hint: "이차식 두 개의 곱으로 나눠지나요?",
                                             work: "(\(DoitMath.describe(polyFromInts(pair.0))))(\(DoitMath.describe(polyFromInts(pair.1))))"))
            result.rest += [pair.0, pair.1]
            a = [1]
        }
        if a.count >= 3 {
            result.rest.append(a)
            if a.count == 3 {
                let d = a[1] * a[1] - 4 * a[2] * a[0]
                result.steps.append(SolutionStep(hint: "남은 이차식 \(DoitMath.describe(polyFromInts(a)))은?",
                                                 work: "판별식 D = \(d) — 유리수 범위에서는 더 인수분해되지 않아요"))
            }
        } else if a.count == 1 && a[0] != 1 {
            result.content *= a[0]
        }
        return result
    }

    private static func append(_ result: inout Factorization, q: Int, p: Int) {
        if let index = result.linear.firstIndex(where: { $0.q == q && $0.p == p }) {
            result.linear[index].power += 1
        } else {
            result.linear.append((q, p, 1))
        }
    }

    /// (p1x² + r1x + q1)(p2x² + r2x + q2) 꼴 찾기
    private static func quarticSplit(_ a: [Int]) -> ([Int], [Int])? {
        let A = a[4], B = a[3], C = a[2], D = a[1], E = a[0]
        guard A != 0, E != 0 else { return nil }
        for p1 in divisors(A) {
            let p2 = A / p1
            for q1abs in divisors(E) {
                for q1 in [q1abs, -q1abs] {
                    let q2 = E / q1
                    for r1 in -30...30 {
                        let numerator = B - r1 * p2
                        guard numerator % p1 == 0 else { continue }
                        let r2 = numerator / p1
                        if p1 * q2 + r1 * r2 + q1 * p2 == C && r1 * q2 + q1 * r2 == D {
                            return ([q1, r1, p1], [q2, r2, p2])
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - 실근 (정확한 값 + 근삿값)

    struct Root {
        var value: Double
        var label: String
    }

    /// 이차식 ax² + bx + c 의 실근 (정확한 모양)
    static func quadraticRoots(_ a: Double, _ b: Double, _ c: Double) -> [Root] {
        let d = b * b - 4 * a * c
        if d < -1e-9 { return [] }
        if abs(d) < 1e-9 { let r = -b / (2 * a); return [Root(value: r, label: f(r))] }
        let r1 = (-b - d.squareRoot()) / (2 * a), r2 = (-b + d.squareRoot()) / (2 * a)
        let low = min(r1, r2), high = max(r1, r2)
        let isInt = [a, b, c].allSatisfy { abs($0 - $0.rounded()) < 1e-9 }
        if isInt, abs(d - d.rounded()) < 1e-9 {
            let s = simplifyRoot(DoitMath.safeInt(d))
            if s.inside == 1 { return [Root(value: low, label: f(low)), Root(value: high, label: f(high))] }
            var p = Int((-b).rounded()), k = s.outside, den = Int((2 * a).rounded())
            if den < 0 { den = -den; p = -p }
            let g = gcd(gcd(p, k), den)
            p /= g; k /= g; den /= g
            func label(_ sign: String) -> String {
                let rootPart = rootText(k, s.inside)
                if p == 0 { return den == 1 ? "\(sign == "−" ? "−" : "")\(rootPart)" : "\(sign == "−" ? "−" : "")\(rootPart)/\(den)" }
                let body = "\(p) \(sign) \(rootPart)"
                return den == 1 ? body : "(\(body))/\(den)"
            }
            return [Root(value: low, label: label("−")), Root(value: high, label: label("+"))]
        }
        return [Root(value: low, label: "≈ " + DoitMath.format(low, digits: 5)), Root(value: high, label: "≈ " + DoitMath.format(high, digits: 5))]
    }

    /// 다항식의 서로 다른 실근 (작은 순)
    static func realRoots(_ poly: Poly) -> [Root] {
        let degree = poly.degree
        guard degree >= 1 else { return [] }
        if degree == 1 { let r = -poly[0] / poly[1]; return [Root(value: r, label: f(r))] }
        if degree == 2 { return quadraticRoots(poly[2], poly[1], poly[0]) }
        var roots: [Root] = []
        if let factored = factor(poly) {
            if factored.xPower > 0 { roots.append(Root(value: 0, label: "0")) }
            for l in factored.linear {
                let v = Double(l.p) / Double(l.q)
                roots.append(Root(value: v, label: f(v)))
            }
            for r in factored.rest {
                let p = polyFromInts(r)
                if p.degree == 2 { roots += quadraticRoots(p[2], p[1], p[0]) }
                else if p.degree == 1 { let v = -p[0] / p[1]; roots.append(Root(value: v, label: f(v))) }
                else { roots += numericRoots(p).map { Root(value: $0, label: "≈ " + DoitMath.format($0, digits: 5)) } }
            }
        } else {
            roots = numericRoots(poly).map { Root(value: $0, label: "≈ " + DoitMath.format($0, digits: 5)) }
        }
        roots.sort { $0.value < $1.value }
        var unique: [Root] = []
        for r in roots where !unique.contains(where: { abs($0.value - r.value) < 1e-7 }) { unique.append(r) }
        return unique
    }

    /// 수치로 실근 찾기 (부호가 바뀌는 곳을 반으로 나눠 좁힘)
    static func numericRoots(_ poly: Poly) -> [Double] {
        let n = poly.degree
        guard n >= 1 else { return [] }
        let lead = abs(poly[n])
        let bound = 1 + (0..<n).map { abs(poly[$0]) / lead }.max()!
        let steps = 4000
        var roots: [Double] = []
        var previousX = -bound
        var previousY = DoitMath.value(poly, at: previousX)
        for k in 1...steps {
            let x = -bound + 2 * bound * Double(k) / Double(steps)
            let y = DoitMath.value(poly, at: x)
            if abs(y) < 1e-12 { roots.append(x) }
            else if previousY * y < 0 {
                var lo = previousX, hi = x
                for _ in 0..<80 {
                    let mid = (lo + hi) / 2
                    if DoitMath.value(poly, at: lo) * DoitMath.value(poly, at: mid) <= 0 { hi = mid } else { lo = mid }
                }
                roots.append((lo + hi) / 2)
            }
            previousX = x
            previousY = y
        }
        // 중근(접하는 근): 도함수의 근 중 값이 0인 것
        let derivative = derive(poly)
        if derivative.degree >= 1 && derivative.degree < n {
            for r in numericRootsShallow(derivative, bound: bound) where abs(DoitMath.value(poly, at: r)) < 1e-7 {
                roots.append(r)
            }
        }
        var unique: [Double] = []
        for r in roots.sorted() where !unique.contains(where: { abs($0 - r) < 1e-6 }) { unique.append(r) }
        return unique.map { abs($0 - $0.rounded()) < 1e-7 ? $0.rounded() : $0 }
    }

    private static func numericRootsShallow(_ poly: Poly, bound: Double) -> [Double] {
        var roots: [Double] = []
        var px = -bound, py = DoitMath.value(poly, at: px)
        for k in 1...4000 {
            let x = -bound + 2 * bound * Double(k) / 4000
            let y = DoitMath.value(poly, at: x)
            if py * y <= 0 {
                var lo = px, hi = x
                for _ in 0..<80 {
                    let mid = (lo + hi) / 2
                    if DoitMath.value(poly, at: lo) * DoitMath.value(poly, at: mid) <= 0 { hi = mid } else { lo = mid }
                }
                roots.append((lo + hi) / 2)
            }
            px = x; py = y
        }
        return roots
    }

    // MARK: - 방정식 (삼차 이상 포함)

    static func solveHigherEquation(_ poly: Poly, original: String) -> MathSolver.Solved? {
        guard poly.degree >= 3 else { return nil }
        var steps = [SolutionStep(hint: "모든 항을 한쪽으로 모으면?", work: "\(DoitMath.describe(poly)) = 0")]
        var answers: [String] = []
        if let factored = factor(poly), !factored.isTrivial {
            steps += factored.steps
            steps.append(SolutionStep(hint: "인수분해한 모양은?", work: "\(factored.text) = 0"))
            if factored.xPower > 0 { answers.append("0" + (factored.xPower > 1 ? " (\(factored.xPower)중근)" : "")) }
            for l in factored.linear {
                answers.append(f(Double(l.p) / Double(l.q)) + (l.power > 1 ? " (\(l.power == 2 ? "중근" : "\(l.power)중근"))" : ""))
            }
            for r in factored.rest {
                let p = polyFromInts(r)
                if p.degree == 2 {
                    let d = p[1] * p[1] - 4 * p[2] * p[0]
                    if d >= 0 {
                        answers += quadraticRoots(p[2], p[1], p[0]).map(\.label)
                        steps.append(SolutionStep(hint: "남은 이차방정식 \(DoitMath.describe(p)) = 0", work: "근의 공식으로 풀면 \(quadraticRoots(p[2], p[1], p[0]).map(\.label).joined(separator: ", "))"))
                    } else {
                        let re = -p[1] / (2 * p[2])
                        let im = sqrtText(-d) + "/" + f(abs(2 * p[2]))
                        let imText = abs(2 * p[2] - 1) < 1e-9 ? sqrtText(-d) : (abs((-d).squareRoot() / abs(2 * p[2]) - ((-d).squareRoot() / abs(2 * p[2])).rounded()) < 1e-9 ? f((-d).squareRoot() / abs(2 * p[2])) : im)
                        answers.append("\(abs(re) < 1e-12 ? "" : f(re) + " ")±\(abs(re) < 1e-12 ? "" : " ")\(imText)i (허근)")
                        steps.append(SolutionStep(hint: "남은 이차방정식 \(DoitMath.describe(p)) = 0", work: "판별식 D = \(f(d)) < 0 이라 두 허근"))
                    }
                } else {
                    let numeric = numericRoots(p)
                    answers += numeric.map { "≈ " + DoitMath.format($0, digits: 5) }
                    steps.append(SolutionStep(hint: "남은 식 \(DoitMath.describe(p)) = 0", work: numeric.isEmpty ? "실근이 없어요" : "수치로 구한 실근: \(numeric.map { DoitMath.format($0, digits: 5) }.joined(separator: ", "))"))
                }
            }
        } else {
            let numeric = numericRoots(poly)
            steps.append(SolutionStep(hint: "유리수 근이 있나요?", work: "인수정리로 찾을 수 있는 유리수 근이 없어서 수치로 근을 구했어요"))
            answers = numeric.map { "≈ " + DoitMath.format($0, digits: 6) }
            if answers.isEmpty { answers = ["실근이 없어요"] }
        }
        return MathSolver.Solved(kind: .higherEquation, topic: "\(poly.degree)차방정식",
                                 concept: "삼차 이상 방정식은 인수정리로 f(a) = 0 이 되는 a를 찾고, 조립제법으로 차수를 낮춰서 풀어요.",
                                 steps: steps, answer: "x = " + answers.joined(separator: ", "))
    }

    // MARK: - 부등식

    struct Interval {
        var low: Double, lowIn: Bool
        var high: Double, highIn: Bool
        var lowLabel: String, highLabel: String
    }

    static func intervalText(_ set: [Interval]) -> String {
        guard !set.isEmpty else { return "해가 없어요" }
        if set.count == 1, set[0].low == -.infinity, set[0].high == .infinity { return "모든 실수" }
        if set.count == 2, set[0].low == -.infinity, set[1].high == .infinity,
           abs(set[0].high - set[1].low) < 1e-12, !set[0].highIn, !set[1].lowIn {
            return "x ≠ \(set[0].highLabel)인 모든 실수"
        }
        return set.map { i -> String in
            if i.low == i.high { return "x = \(i.lowLabel)" }
            if i.low == -.infinity { return "x \(i.highIn ? "≤" : "<") \(i.highLabel)" }
            if i.high == .infinity { return "x \(i.lowIn ? "≥" : ">") \(i.lowLabel)" }
            return "\(i.lowLabel) \(i.lowIn ? "≤" : "<") x \(i.highIn ? "≤" : "<") \(i.highLabel)"
        }.joined(separator: " 또는 ")
    }

    /// p(x) [op] 0 의 해
    static func solveSign(_ poly: Poly, op: String) -> (set: [Interval], roots: [Root]) {
        let roots = realRoots(poly)
        func holds(_ v: Double) -> Bool {
            switch op {
            case "<": return v < -1e-9
            case ">": return v > 1e-9
            case "≤": return v <= 1e-9
            default: return v >= -1e-9
            }
        }
        var set: [Interval] = []
        let points = [-Double.infinity] + roots.map(\.value) + [Double.infinity]
        let labels = [""] + roots.map(\.label) + [""]
        for k in 0..<(points.count - 1) {
            let lo = points[k], hi = points[k + 1]
            let mid: Double
            if lo == -.infinity && hi == .infinity { mid = 0 }
            else if lo == -.infinity { mid = hi - 1 }
            else if hi == .infinity { mid = lo + 1 }
            else { mid = (lo + hi) / 2 }
            if holds(DoitMath.value(poly, at: mid)) {
                set.append(Interval(low: lo, lowIn: false, high: hi, highIn: false, lowLabel: labels[k], highLabel: labels[k + 1]))
            }
        }
        // 근에서 성립하면 (≤, ≥) 경계 포함 / 이어 붙이기
        for (index, root) in roots.enumerated() where holds(0) {
            _ = index
            if let left = set.firstIndex(where: { abs($0.high - root.value) < 1e-12 }) { set[left].highIn = true }
            if let right = set.firstIndex(where: { abs($0.low - root.value) < 1e-12 }) { set[right].lowIn = true }
            if !set.contains(where: { abs($0.high - root.value) < 1e-12 || abs($0.low - root.value) < 1e-12 }) {
                set.append(Interval(low: root.value, lowIn: true, high: root.value, highIn: true, lowLabel: root.label, highLabel: root.label))
            }
        }
        return (merge(set), roots)
    }

    static func merge(_ set: [Interval]) -> [Interval] {
        let sorted = set.sorted { $0.low < $1.low || ($0.low == $1.low && $0.high < $1.high) }
        var out: [Interval] = []
        for i in sorted {
            if var last = out.last, (i.low < last.high) || (abs(i.low - last.high) < 1e-12 && (i.lowIn || last.highIn)) {
                if i.high > last.high || (i.high == last.high && i.highIn) {
                    last.high = i.high; last.highIn = i.highIn || (i.high == last.high && last.highIn); last.highLabel = i.highLabel
                }
                out[out.count - 1] = last
            } else {
                out.append(i)
            }
        }
        return out
    }

    static func intersect(_ a: [Interval], _ b: [Interval]) -> [Interval] {
        var out: [Interval] = []
        for x in a {
            for y in b {
                var lo = x.low, loIn = x.lowIn, loLabel = x.lowLabel
                if y.low > lo || (y.low == lo && !y.lowIn) { lo = y.low; loIn = y.lowIn && (y.low != x.low || x.lowIn); loLabel = y.lowLabel }
                var hi = x.high, hiIn = x.highIn, hiLabel = x.highLabel
                if y.high < hi || (y.high == hi && !y.highIn) { hi = y.high; hiIn = y.highIn && (y.high != x.high || x.highIn); hiLabel = y.highLabel }
                if lo < hi || (lo == hi && loIn && hiIn) {
                    out.append(Interval(low: lo, lowIn: loIn, high: hi, highIn: hiIn, lowLabel: loLabel, highLabel: hiLabel))
                }
            }
        }
        return merge(out)
    }

    private static func flip(_ op: String) -> String {
        switch op { case "<": return ">"; case ">": return "<"; case "≤": return "≥"; default: return "≤" }
    }

    /// "2x+3>7", "x²−5x+6≤0", "1<2x+3≤7", 쉼표로 여러 개(연립부등식), |x−2|<3
    static func solveInequality(_ text: String) -> MathSolver.Solved? {
        let normalized = normalize(text)
        guard normalized.contains(where: { "<>≤≥".contains($0) }) else { return nil }
        let chunks = normalized.components(separatedBy: CharacterSet(charactersIn: ",\n;")).flatMap { $0.components(separatedBy: "그리고") }
        var total: [Interval]? = nil
        var steps: [SolutionStep] = []
        var count = 0
        for chunk in chunks {
            let expression = extract(chunk, extra: "<>≤≥")
            guard expression.contains(where: { "<>≤≥".contains($0) }) else { continue }
            // 식과 부호로 나누기
            var pieces: [String] = [], ops: [String] = [], current = ""
            for ch in expression {
                if "<>≤≥".contains(ch) { pieces.append(current); ops.append(String(ch)); current = "" } else { current.append(ch) }
            }
            pieces.append(current)
            guard pieces.allSatisfy({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return nil }
            for k in 0..<ops.count {
                guard let part = solveSingleInequality(pieces[k], ops[k], pieces[k + 1], steps: &steps) else { return nil }
                total = total.map { intersect($0, part) } ?? part
                count += 1
            }
        }
        guard let solution = total, count > 0 else { return nil }
        if count > 1 { steps.append(SolutionStep(hint: "각 부등식의 해의 공통 범위는?", work: intervalText(solution))) }
        // 정수(자연수) x의 개수·합·가장 큰 값
        if has(normalized, ["정수", "자연수"]), has(normalized, ["개수", "몇 개", "합", "가장 큰", "가장 작은", "최댓값", "최솟값", "모두 구", "모두 쓰"]) {
            let natural = has(normalized, ["자연수"])
            var integers: [Int] = []
            for i in solution {
                guard i.low.isFinite || natural, i.high.isFinite, i.high - (i.low.isFinite ? i.low : 0) <= 5000 else { integers = []; break }
                var k = Int(max(i.low.isFinite ? i.low : 1, natural ? 1 : -1e9).rounded(.up))
                while Double(k) <= i.high && integers.count < 10000 {
                    let inside = (Double(k) > i.low || (i.lowIn && abs(Double(k) - i.low) < 1e-12)) && (Double(k) < i.high || (i.highIn && abs(Double(k) - i.high) < 1e-12))
                    if inside && (!natural || k >= 1) && !integers.contains(k) { integers.append(k) }
                    k += 1
                }
            }
            let bounded = solution.allSatisfy { $0.high.isFinite && ($0.low.isFinite || natural) && $0.high - ($0.low.isFinite ? $0.low : 0) <= 5000 }
            if bounded {
                integers.sort()
                let label = natural ? "자연수" : "정수"
                steps.append(SolutionStep(hint: "범위 안의 \(label) x", work: integers.isEmpty ? "없어요" : integers.map(String.init).joined(separator: ", ")))
                var answer: String?
                if has(normalized, ["개수", "몇 개"]) { answer = "\(integers.count)개" }
                else if has(normalized, ["모두 구", "모두 쓰"]) { answer = integers.isEmpty ? "없어요" : integers.map(String.init).joined(separator: ", ") }
                else if has(normalized, ["합"]) { answer = "\(integers.reduce(0, +))" }
                else if has(normalized, ["가장 큰", "최댓값"]), let top = integers.last { answer = "\(top)" }
                else if has(normalized, ["가장 작은", "최솟값"]), let low = integers.first { answer = "\(low)" }
                if let answer {
                    return MathSolver.Solved(kind: .inequality, topic: "부등식을 만족하는 \(label)", concept: "부등식의 해를 구한 뒤, 그 범위에 들어가는 \(label)를 세어요. 경계값이 포함되는지(≤, <) 꼭 확인해요.",
                                             steps: steps, answer: answer)
                }
            }
        }
        return MathSolver.Solved(kind: .inequality, topic: count > 1 ? "연립부등식" : "부등식",
                                 concept: "이차 이상 부등식은 f(x) = 0 의 근을 기준으로 구간을 나누고, 각 구간에서 f(x)의 부호를 확인해요. 음수를 곱하거나 나누면 부등호 방향이 바뀌어요.",
                                 steps: steps, answer: intervalText(solution))
    }

    private static func solveSingleInequality(_ left: String, _ op: String, _ right: String, steps: inout [SolutionStep]) -> [Interval]? {
        // 절댓값 |A| op c
        if left.contains("|") || right.contains("|") {
            return absoluteInequality(left, op, right, steps: &steps)
        }
        guard let l = parse(left), let r = parse(right), let poly = (l - r).univariate else { return nil }
        let display = "\(DoitMath.describe(poly)) \(op) 0"
        if poly.degree <= 0 {
            let holds: Bool
            switch op { case "<": holds = poly[0] < 0; case ">": holds = poly[0] > 0; case "≤": holds = poly[0] <= 0; default: holds = poly[0] >= 0 }
            steps.append(SolutionStep(hint: "x를 정리하면?", work: "\(f(poly[0])) \(op) 0 → \(holds ? "항상 성립" : "성립하지 않음")"))
            return holds ? [Interval(low: -.infinity, lowIn: false, high: .infinity, highIn: false, lowLabel: "", highLabel: "")] : []
        }
        if poly.degree == 1 {
            let a = poly[1], b = poly[0]
            let newOp = a < 0 ? flip(op) : op
            steps.append(SolutionStep(hint: "x항은 왼쪽, 수는 오른쪽으로", work: "\(DoitMath.describe(Poly.x * .constant(a) ?? Poly.x)) \(op) \(f(-b))"))
            steps.append(SolutionStep(hint: "x의 계수로 나누면\(a < 0 ? " (음수라 부등호 방향이 바뀌어요)" : "")", work: "x \(newOp) \(f(-b / a))"))
        } else {
            let roots = realRoots(poly)
            steps.append(SolutionStep(hint: "한쪽으로 모으면?", work: display))
            if let factored = factor(poly), !factored.isTrivial {
                steps.append(SolutionStep(hint: "인수분해하면?", work: "\(factored.text) \(op) 0"))
            }
            steps.append(SolutionStep(hint: "f(x) = 0 의 실근은?", work: roots.isEmpty ? "실근이 없어요 (그래프가 x축과 만나지 않아요)" : roots.map(\.label).joined(separator: ", ")))
        }
        let solved = solveSign(poly, op: op)
        if poly.degree >= 2 { steps.append(SolutionStep(hint: "구간마다 부호를 확인하면", work: intervalText(solved.set))) }
        return solved.set
    }

    private static func absoluteInequality(_ left: String, _ op: String, _ right: String, steps: inout [SolutionStep]) -> [Interval]? {
        var op = op, inner = left, other = right
        if !left.contains("|") { op = flip(op); inner = right; other = left }
        let trimmed = inner.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|"), trimmed.hasSuffix("|"), trimmed.count > 2 else { return nil }
        let body = String(trimmed.dropFirst().dropLast())
        guard let a = parse(body)?.univariate, a.degree == 1, let c = parse(other), c.isConstant else { return nil }
        let k = c.constantValue
        let aText = DoitMath.describe(a)
        if op == "<" || op == "≤" {
            guard k > 0 || (k == 0 && op == "≤") else {
                steps.append(SolutionStep(hint: "절댓값은 0 이상", work: "|\(aText)| \(op) \(f(k)) 은 성립할 수 없어요"))
                return []
            }
            steps.append(SolutionStep(hint: "|A| \(op) k 이면 −k \(op) A \(op) k", work: "−\(f(k)) \(op) \(aText) \(op) \(f(k))"))
            let lower = solveSign(a + Poly.constant(k), op: op == "<" ? ">" : "≥").set
            let upper = solveSign(a - Poly.constant(k), op: op).set
            return intersect(lower, upper)
        } else {
            guard k >= 0 else { return [Interval(low: -.infinity, lowIn: false, high: .infinity, highIn: false, lowLabel: "", highLabel: "")] }
            steps.append(SolutionStep(hint: "|A| \(op) k 이면 A \(flip(op)) −k 또는 A \(op) k", work: "\(aText) \(flip(op)) −\(f(k)) 또는 \(aText) \(op) \(f(k))"))
            let lower = solveSign(a + Poly.constant(k), op: flip(op)).set
            let upper = solveSign(a - Poly.constant(k), op: op).set
            return merge(lower + upper)
        }
    }

    // MARK: - 절댓값 방정식

    static func solveAbsoluteEquation(_ text: String) -> MathSolver.Solved? {
        let expression = extract(text)
        guard expression.filter({ $0 == "|" }).count == 2, expression.contains("=") else { return nil }
        let sides = expression.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard sides.count == 2 else { return nil }
        var absSide = sides[0], other = sides[1]
        if !absSide.contains("|") { swap(&absSide, &other) }
        let trimmed = absSide.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|"), trimmed.hasSuffix("|"),
              let a = parse(String(trimmed.dropFirst().dropLast()))?.univariate, a.degree == 1,
              let b = parse(other)?.univariate, b.degree <= 1 else { return nil }
        var answers: [Double] = []
        var steps = [SolutionStep(hint: "|A| = B 이면 A = B 또는 A = −B (단, B ≥ 0)", work: "\(DoitMath.describe(a)) = \(DoitMath.describe(b)) 또는 \(DoitMath.describe(a)) = −(\(DoitMath.describe(b)))")]
        for candidate in [a - b, a + b] where candidate.degree == 1 {
            let x = -candidate[0] / candidate[1]
            let ok = DoitMath.value(b, at: x) >= -1e-9
            steps.append(SolutionStep(hint: "\(DoitMath.describe(candidate)) = 0", work: "x = \(f(x))" + (ok ? "" : " → 오른쪽이 음수가 되어 해가 아니에요")))
            if ok && !answers.contains(where: { abs($0 - x) < 1e-9 }) { answers.append(x) }
        }
        return MathSolver.Solved(kind: .absolute, topic: "절댓값이 있는 방정식",
                                 concept: "|A| = B 는 A = B 또는 A = −B 로 나눠 풀고, B ≥ 0 인지 꼭 확인해요.",
                                 steps: steps, answer: answers.isEmpty ? "해가 없어요" : "x = " + answers.sorted().map(f).joined(separator: " 또는 x = "))
    }

    // MARK: - 연립일차방정식

    static func solveSystem(_ text: String) -> MathSolver.Solved? {
        let normalized = normalize(text)
        let chunks = normalized.components(separatedBy: CharacterSet(charactersIn: ",\n;")).flatMap { $0.components(separatedBy: "그리고") }
        var equations: [MPoly] = []
        var shown: [String] = []
        for chunk in chunks {
            let expression = extract(chunk)
            let sides = expression.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
            guard sides.count == 2, let l = parse(sides[0]), let r = parse(sides[1]) else { continue }
            let e = l - r
            guard e.degree == 1 else { if e.degree > 1 { return nil } else { continue } }
            equations.append(e)
            shown.append(expression)
        }
        let variables = Array(Set(equations.flatMap(\.variables))).sorted()
        guard equations.count >= 2, (2...3).contains(variables.count), equations.count >= variables.count else { return nil }
        let n = variables.count
        // 행렬 [계수 | 상수]
        func coefficient(_ e: MPoly, _ v: Character) -> Double {
            v == "x" ? e.coef(x: 1) : v == "y" ? e.coef(y: 1) : e.coef(z: 1)
        }
        var rows = equations.prefix(max(n, equations.count)).map { e in variables.map { coefficient(e, $0) } + [-e.constantValue] }
        var steps: [SolutionStep] = []
        let labels = ["①", "②", "③", "④"]
        for (k, e) in equations.prefix(4).enumerated() {
            steps.append(SolutionStep(hint: "\(labels[k]) 식 정리", work: "\(describe(e - .constant(e.constantValue))) = \(f(-e.constantValue))"))
        }
        if n == 2 {
            let (a1, b1, c1) = (rows[0][0], rows[0][1], rows[0][2])
            let (a2, b2, c2) = (rows[1][0], rows[1][1], rows[1][2])
            let det = a1 * b2 - a2 * b1
            let v0 = String(variables[0]), v1 = String(variables[1])
            if abs(det) < 1e-12 {
                let consistent = abs(a1 * c2 - a2 * c1) < 1e-9 && abs(b1 * c2 - b2 * c1) < 1e-9
                return MathSolver.Solved(kind: .system, topic: "연립방정식", concept: "두 직선이 평행하면 해가 없고, 일치하면 해가 무수히 많아요.",
                                         steps: steps, answer: consistent ? "해가 무수히 많아요 (부정)" : "해가 없어요 (불능)")
            }
            let x = (c1 * b2 - c2 * b1) / det
            let y = (a1 * c2 - a2 * c1) / det
            func times(_ v: Double) -> String { v < 0 ? "(\(f(v)))" : f(v) }
            steps.append(SolutionStep(hint: "\(v1)의 계수를 맞춰 없애려면 (가감법)", work: "①×\(times(b2)) − ②×\(times(b1)) → \(f(det))\(v0) = \(f(c1 * b2 - c2 * b1))"))
            steps.append(SolutionStep(hint: "\(v0)를 구하면", work: "\(v0) = \(f(x))"))
            steps.append(SolutionStep(hint: "\(v0) = \(f(x))을 \(abs(b1) > 1e-12 ? "①" : "②")에 대입하면", work: "\(v1) = \(f(y))"))
            return MathSolver.Solved(kind: .system, topic: "연립일차방정식",
                                     concept: "한 미지수의 계수를 같게 만들어 빼거나 더하는 가감법, 한 식을 다른 식에 넣는 대입법으로 풀어요.",
                                     steps: steps, answer: "\(v0) = \(f(x)), \(v1) = \(f(y))")
        }
        // 미지수 3개: 가우스 소거
        for col in 0..<n {
            guard let pivot = (col..<rows.count).max(by: { abs(rows[$0][col]) < abs(rows[$1][col]) }), abs(rows[pivot][col]) > 1e-12 else {
                return MathSolver.Solved(kind: .system, topic: "연립방정식", concept: "식이 서로 독립이 아니면 해가 하나로 정해지지 않아요.",
                                         steps: steps, answer: "해가 하나로 정해지지 않아요")
            }
            rows.swapAt(col, pivot)
            let p = rows[col][col]
            rows[col] = rows[col].map { $0 / p }
            for r in 0..<rows.count where r != col {
                let factor = rows[r][col]
                rows[r] = zip(rows[r], rows[col]).map { $0 - factor * $1 }
            }
        }
        steps.append(SolutionStep(hint: "한 문자씩 없애면서 (소거법) 정리하면", work: variables.enumerated().map { "\($0.element) = \(f(rows[$0.offset][n]))" }.joined(separator: ", ")))
        return MathSolver.Solved(kind: .system, topic: "연립일차방정식 (미지수 3개)",
                                 concept: "두 식씩 짝지어 같은 문자를 없애서 미지수 2개짜리로 만든 뒤 풀어요.",
                                 steps: steps, answer: variables.enumerated().map { "\($0.element) = \(f(rows[$0.offset][n]))" }.joined(separator: ", "))
    }

    // MARK: - 미분 · 적분

    static func derive(_ p: Poly) -> Poly {
        var d = Poly()
        for i in 1..<Poly.size { d.c[i - 1] = p[i] * Double(i) }
        return d
    }

    static func integrate(_ p: Poly) -> Poly? {
        guard p.degree < Poly.size - 1 else { return nil }
        var q = Poly()
        for i in 0..<(Poly.size - 1) { q.c[i + 1] = p[i] / Double(i + 1) }
        return q
    }

    /// 미분·적분 대상 식 ("f(x) = …" 또는 문장 속 식)
    private static func calculusTarget(_ text: String) -> Poly? {
        var t = normalize(text)
        // 구간·대입 표현은 지우고 식만
        for pattern in [#"x\s*=\s*-?\d+(\.\d+)?\s*(에서|일 때|일때)"#, #"-?\d+(\.\d+)?\s*(부터|에서)\s*-?\d+(\.\d+)?\s*까지"#,
                        #"구간\s*\[[^\]]*\]"#, #"f'\(-?\d+(\.\d+)?\)"#, #"\[\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\]"#] {
            t = t.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        if let f = MathSolver.function(in: t) { return f }
        t = t.replacingOccurrences(of: "dx", with: " ").replacingOccurrences(of: "∫", with: " ")
        let expression = extract(t)
        guard !expression.contains("=") else { return nil }
        return parse(expression)?.univariate
    }

    private static func number(_ s: Substring) -> Double? { Double(String(s).replacingOccurrences(of: " ", with: "")) }

    static func solveCalculus(_ text: String) -> MathSolver.Solved? {
        var t = normalize(text)
        // ∫₀², ∫_1^3, ∫_{1}^{3} → 구간 [a, b]로 (식을 읽을 때 위끝·아래끝이 섞이지 않게)
        let subscripts: [Character: Character] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9", "₋": "-"]
        if t.contains("∫") {
            var plain = ""
            var inSub = false
            for ch in t {
                if let d = subscripts[ch] { if !inSub { plain.append("_"); inSub = true }; plain.append(d) } else { inSub = false; plain.append(ch) }
            }
            t = plain
            if let m = t.firstMatch(of: #/∫\s*_\s*\{?\s*(-?\d+(?:\.\d+)?)\s*\}?\s*\^\s*\{?\s*(-?\d+(?:\.\d+)?)\s*\}?/#) {
                t = t.replacingOccurrences(of: String(m.0), with: " 구간 [\(m.1), \(m.2)] ∫ ")
            } else if t.range(of: #"∫\s*[_^]"#, options: .regularExpression) != nil {
                return nil
            }
        }
        // 곡선과 x축으로 둘러싸인 넓이
        if has(t, ["둘러싸인"]), has(t, ["x축"]), has(t, ["넓이"]) { return enclosedArea(t) }
        let wantsIntegral = has(t, ["적분", "∫", "넓이를 구", "부정적분", "정적분"])
        let wantsDerivative = has(t, ["미분", "도함수", "접선", "f'(", "증가", "감소", "극대", "극소", "극값", "극댓값", "극솟값"])
        guard wantsIntegral || wantsDerivative, let poly = calculusTarget(t), poly.degree >= 1 || wantsIntegral else { return nil }
        let fText = DoitMath.describe(poly)

        if wantsIntegral {
            guard let F = integrate(poly) else { return nil }
            var bounds: (Double, Double)?
            if let m = t.firstMatch(of: #/구간\s*\[\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\]/#), let a = number(m.1), let b = number(m.2) { bounds = (a, b) }
            else if let m = t.firstMatch(of: #/(-?\d+(?:\.\d+)?)\s*(?:부터|에서)\s*(-?\d+(?:\.\d+)?)\s*까지/#), let a = number(m.1), let b = number(m.2) { bounds = (a, b) }
            else if let m = t.firstMatch(of: #/\[\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\]/#), let a = number(m.1), let b = number(m.2) { bounds = (a, b) }
            var steps = [SolutionStep(hint: "xⁿ 을 적분하면 xⁿ⁺¹/(n+1)", work: "∫(\(fText))dx = \(DoitMath.describe(F)) + C")]
            if let (a, b) = bounds {
                let value = DoitMath.value(F, at: b) - DoitMath.value(F, at: a)
                steps.append(SolutionStep(hint: "위끝 \(f(b))과 아래끝 \(f(a))을 넣어 빼면", work: "F(\(f(b))) − F(\(f(a))) = \(f(DoitMath.value(F, at: b))) − (\(f(DoitMath.value(F, at: a)))) = \(f(value))"))
                return MathSolver.Solved(kind: .integral, topic: "정적분", concept: "∫ₐᵇ f(x)dx = F(b) − F(a) (F는 f의 부정적분)", steps: steps, answer: f(value))
            }
            return MathSolver.Solved(kind: .integral, topic: "부정적분", concept: "∫xⁿdx = xⁿ⁺¹/(n+1) + C (C는 적분상수)", steps: steps, answer: "\(DoitMath.describe(F)) + C")
        }

        let d = derive(poly)
        var steps = [SolutionStep(hint: "xⁿ 을 미분하면 nxⁿ⁻¹, 상수는 0", work: "f'(x) = \(DoitMath.describe(d))")]
        var point: Double?
        if let m = t.firstMatch(of: #/x\s*=\s*(-?\d+(?:\.\d+)?)\s*(?:에서|일 때|일때|인)/#) { point = number(m.1) }
        else if let m = t.firstMatch(of: #/f'\((-?\d+(?:\.\d+)?)\)/#) { point = number(m.1) }
        else if has(t, ["접선"]) {
            // "곡선 위의 점 (3, 3)에서의 접선": 점이 곡선 위에 있을 때만 (밖의 점에서 그은 접선은 여기서 풀지 않음)
            let pts = DoitMathTopics.points(in: t)
            guard pts.count == 1 else { return nil }
            guard abs(DoitMath.value(poly, at: pts[0].x) - pts[0].y) < 1e-9 else { return nil }
            point = pts[0].x
        }

        if has(t, ["접선"]), let a = point {
            let slope = DoitMath.value(d, at: a), y0 = DoitMath.value(poly, at: a)
            steps.append(SolutionStep(hint: "접점의 y좌표는?", work: "f(\(f(a))) = \(f(y0))"))
            steps.append(SolutionStep(hint: "접선의 기울기는 f'(\(f(a)))", work: "f'(\(f(a))) = \(f(slope))"))
            let intercept = y0 - slope * a
            var line = Poly(); line.c[1] = slope; line.c[0] = intercept
            if has(t, ["접선의 기울기"]) {
                return MathSolver.Solved(kind: .derivative, topic: "접선의 기울기", concept: "x = a 에서의 접선의 기울기는 미분계수 f'(a)예요.", steps: steps, answer: f(slope))
            }
            steps.append(SolutionStep(hint: "y − f(a) = f'(a)(x − a)", work: "y − (\(f(y0))) = \(f(slope))(x − (\(f(a))))"))
            return MathSolver.Solved(kind: .derivative, topic: "접선의 방정식", concept: "x = a 에서의 접선: y = f'(a)(x − a) + f(a)", steps: steps, answer: "y = \(DoitMath.describe(line))")
        }
        if has(t, ["극대", "극소", "극값", "극댓값", "극솟값", "증가", "감소"]) {
            let critical = realRoots(d)
            steps.append(SolutionStep(hint: "f'(x) = 0 이 되는 x는?", work: critical.isEmpty ? "없어요" : critical.map(\.label).joined(separator: ", ")))
            var extrema: [String] = []
            for c in critical {
                let left = DoitMath.value(d, at: c.value - 1e-4), right = DoitMath.value(d, at: c.value + 1e-4)
                if left > 0 && right < 0 { extrema.append("x = \(c.label)에서 극댓값 \(f(DoitMath.value(poly, at: c.value)))") }
                if left < 0 && right > 0 { extrema.append("x = \(c.label)에서 극솟값 \(f(DoitMath.value(poly, at: c.value)))") }
            }
            let increasing = solveSign(d, op: ">").set, decreasing = solveSign(d, op: "<").set
            steps.append(SolutionStep(hint: "f'(x)의 부호로 증가·감소를 보면", work: "증가: \(intervalText(increasing)), 감소: \(intervalText(decreasing))"))
            // 극댓값만(극솟값만) 물으면 그것만
            var asked = extrema
            if has(t, ["극댓값", "극대값"]) && !has(t, ["극솟값", "극소값"]) { asked = extrema.filter { $0.contains("극댓값") } }
            if has(t, ["극솟값", "극소값"]) && !has(t, ["극댓값", "극대값"]) { asked = extrema.filter { $0.contains("극솟값") } }
            return MathSolver.Solved(kind: .derivative, topic: "함수의 증가·감소와 극값",
                                     concept: "f'(x) > 0 이면 증가, f'(x) < 0 이면 감소. f'(x)의 부호가 +에서 −로 바뀌면 극대, −에서 +로 바뀌면 극소예요.",
                                     steps: steps, answer: asked.isEmpty ? (extrema.isEmpty ? "극값이 없어요" : "\(has(t, ["극댓값"]) ? "극댓값" : "극솟값")이 없어요") : asked.joined(separator: ", "))
        }
        if let a = point {
            let value = DoitMath.value(d, at: a)
            steps.append(SolutionStep(hint: "x = \(f(a))을 넣으면", work: "f'(\(f(a))) = \(f(value))"))
            return MathSolver.Solved(kind: .derivative, topic: "미분계수", concept: "x = a 에서의 미분계수 f'(a)는 그 점에서 접선의 기울기예요.", steps: steps, answer: f(value))
        }
        return MathSolver.Solved(kind: .derivative, topic: "도함수", concept: "(xⁿ)' = nxⁿ⁻¹, (상수)' = 0, 합의 미분은 각각 미분해서 더해요.", steps: steps, answer: "f'(x) = \(DoitMath.describe(d))")
    }

    /// 곡선 y = f(x)와 x축 (및 두 직선 x = a, x = b)으로 둘러싸인 부분의 넓이
    private static func enclosedArea(_ t: String) -> MathSolver.Solved? {
        var cleaned = t
        var lo: Double?, hi: Double?
        if let m = t.firstMatch(of: #/x\s*=\s*(-?\d+(?:\.\d+)?)\s*,\s*x\s*=\s*(-?\d+(?:\.\d+)?)/#), let a = number(m.1), let b = number(m.2) {
            lo = min(a, b); hi = max(a, b)
            cleaned = cleaned.replacingOccurrences(of: String(m.0), with: " ")
        }
        guard let poly = MathSolver.function(in: cleaned), poly.degree >= 1, let F = integrate(poly) else { return nil }
        let roots = realRoots(poly).map(\.value)
        if lo == nil {
            guard roots.count >= 2 else { return nil }
            lo = roots.first; hi = roots.last
        }
        guard let a = lo, let b = hi, a < b else { return nil }
        let cuts = [a] + roots.filter { $0 > a + 1e-12 && $0 < b - 1e-12 } + [b]
        var area = 0.0
        var pieces: [String] = []
        for k in 0..<(cuts.count - 1) {
            let part = DoitMath.value(F, at: cuts[k + 1]) - DoitMath.value(F, at: cuts[k])
            area += abs(part)
            pieces.append("|∫ \(f(cuts[k]))~\(f(cuts[k + 1]))| = \(f(abs(part)))")
        }
        return MathSolver.Solved(kind: .integral, topic: "곡선과 x축 사이의 넓이",
                                 concept: "넓이 = ∫ₐᵇ |f(x)| dx. f(x)의 부호가 바뀌는 곳(x축과 만나는 점)에서 나눠서 각각 절댓값을 더해요.",
                                 steps: [SolutionStep(hint: "부정적분 F(x)", work: "\(DoitMath.describe(F)) + C"),
                                         SolutionStep(hint: "구간 [\(f(a)), \(f(b))]에서 x축과 만나는 점으로 나누면", work: pieces.joined(separator: ", ")),
                                         SolutionStep(hint: "모두 더하면", work: f(area))],
                                 answer: f(area))
    }

    // MARK: - 함수 (함숫값, 합성함수, 역함수)

    /// 문장 속 "f(x) = …", "g(x) = …" 정의
    static func functionDefinitions(_ text: String) -> [Character: Poly] {
        let t = normalize(text)
        var result: [Character: Poly] = [:]
        let names: [Character] = ["f", "g", "h"]
        for name in names {
            guard let range = t.range(of: "\(name)(x)=") ?? t.range(of: "\(name)(x) =") ?? t.range(of: "\(name)(x)  =") else { continue }
            var rest = String(t[range.upperBound...])
            // 다음 정의나 쉼표 전까지
            if let cut = rest.firstIndex(where: { $0 == "," || $0 == "\n" }) { rest = String(rest[..<cut]) }
            if let r = rest.range(of: #"\(?[fgh](∘|o\(|\()"#, options: .regularExpression) { rest = String(rest[..<r.lowerBound]) }
            let expression = extract(String(rest.prefix(60)))
            if let p = parse(expression)?.univariate { result[name] = p }
        }
        return result
    }

    /// 함수를 다른 다항식에 합성: f(g(x))
    static func compose(_ outer: Poly, _ inner: Poly) -> Poly? {
        var result = Poly()
        var power = Poly.constant(1)
        for i in 0...max(outer.degree, 0) {
            if i > 0 { guard let next = power * inner else { return nil }; power = next }
            guard let term = power * Poly.constant(outer[i]) else { return nil }
            result = result + term
        }
        return result
    }

    static func solveFunction(_ text: String) -> MathSolver.Solved? {
        let t = normalize(text).replacingOccurrences(of: " ", with: "")
        let defs = functionDefinitions(text)
        guard !defs.isEmpty else { return nil }
        var steps: [SolutionStep] = defs.sorted { $0.key < $1.key }.map {
            SolutionStep(hint: "\($0.key)(x)", work: "\($0.key)(x) = \(DoitMath.describe($0.value))")
        }

        // 역함수
        if has(t, ["역함수", "⁻¹", "^-1"]) {
            let name: Character = t.contains("g의역함수") || t.contains("g^-1") || t.contains("g⁻¹") ? "g" : (defs["f"] != nil ? "f" : defs.keys.first!)
            guard let p = defs[name], p.degree == 1 else { return nil }
            let a = p[1], b = p[0]
            var inverse = Poly(); inverse.c[1] = 1 / a; inverse.c[0] = -b / a
            steps.append(SolutionStep(hint: "y = \(DoitMath.describe(p))를 x에 대해 풀면", work: "x = (y − (\(f(b)))) / \(f(a))"))
            steps.append(SolutionStep(hint: "x와 y를 바꾸면", work: "y = \(DoitMath.describe(inverse))"))
            if let m = t.firstMatch(of: #/(?:⁻¹|\^-1)\((-?\d+(?:\.\d+)?)\)/#), let v = Double(String(m.1)) {
                let value = DoitMath.value(inverse, at: v)
                steps.append(SolutionStep(hint: "\(name)⁻¹(\(f(v)))", work: "= \(f(value))"))
                return MathSolver.Solved(kind: .function, topic: "역함수", concept: "f⁻¹(k) = a 는 f(a) = k 와 같아요.", steps: steps, answer: f(value))
            }
            return MathSolver.Solved(kind: .function, topic: "역함수", concept: "y = f(x)를 x에 대해 푼 뒤 x와 y를 바꾸면 역함수예요.", steps: steps, answer: "\(name)⁻¹(x) = \(DoitMath.describe(inverse))")
        }

        // "f(x) = x² 에 x = 2를 넣으면", "x = 3일 때 f(x)의 값"
        if !t.contains("(f∘") && !t.contains("(g∘"), t.range(of: #"[fgh]\([fgh]\("#, options: .regularExpression) == nil,
           has(t, ["넣", "대입", "일때", "의값", "값은", "값을", "구해"]),
           let m = t.firstMatch(of: #/(?:^|[^a-z(])x=(-?\d+(?:\.\d+)?)(?:을|를|일|에서|$|,)/#), let x = Double(String(m.1)) {
            let name: Character = defs["f"] != nil ? "f" : defs.keys.sorted().first!
            let value = DoitMath.value(defs[name]!, at: x)
            steps.append(SolutionStep(hint: "x 자리에 \(f(x))을 넣으면", work: "\(name)(\(f(x))) = \(f(value))"))
            return MathSolver.Solved(kind: .function, topic: "함숫값", concept: "x 자리에 수를 넣어 계산해요.", steps: steps, answer: "\(name)(\(f(x))) = \(f(value))")
        }

        // 합성: (f∘g)(2), f(g(2)), (f∘g)(x)
        var chain: [Character] = []
        var argument: String?
        if let m = t.firstMatch(of: #/\(([fgh])[∘o]([fgh])\)\(([^)]+)\)/#) {
            chain = [Character(String(m.1)), Character(String(m.2))]
            argument = String(m.3)
        } else if let m = t.firstMatch(of: #/([fgh])\(([fgh])\(([^()]+)\)\)/#) {
            chain = [Character(String(m.1)), Character(String(m.2))]
            argument = String(m.3)
        } else if let m = t.firstMatch(of: #/([fgh])\((-?\d+(?:\.\d+)?)\)/#) {
            chain = [Character(String(m.1))]
            argument = String(m.2)
        }
        guard !chain.isEmpty, let arg = argument, chain.allSatisfy({ defs[$0] != nil }) else { return nil }
        if arg == "x" {
            guard chain.count == 2, let composed = compose(defs[chain[0]]!, defs[chain[1]]!) else { return nil }
            steps.append(SolutionStep(hint: "\(chain[1])(x)를 \(chain[0])의 x 자리에 넣으면", work: "\(chain[0])(\(chain[1])(x)) = \(DoitMath.describe(composed))"))
            return MathSolver.Solved(kind: .function, topic: "합성함수", concept: "(f∘g)(x) = f(g(x)): 안쪽 g를 먼저, 그 결과를 f에 넣어요.", steps: steps, answer: "\(chain[0])∘\(chain[1])(x) = \(DoitMath.describe(composed))")
        }
        guard let x = Double(arg) else { return nil }
        var value = x
        for name in chain.reversed() {
            let next = DoitMath.value(defs[name]!, at: value)
            steps.append(SolutionStep(hint: "\(name)(\(f(value)))을 계산하면", work: "\(name)(\(f(value))) = \(f(next))"))
            value = next
        }
        return MathSolver.Solved(kind: .function, topic: chain.count > 1 ? "합성함수의 함숫값" : "함숫값",
                                 concept: chain.count > 1 ? "(f∘g)(a) = f(g(a)): 안쪽부터 차례로 계산해요." : "x 자리에 수를 넣어 계산해요.",
                                 steps: steps, answer: f(value))
    }
}
