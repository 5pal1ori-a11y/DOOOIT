import Foundation

/// 모티 AI 수학 엔진: 초월함수까지 다루는 식 나무 (외부 AI 없이 직접 계산)
/// - 읽기: sin 3x, sin²x, e^(2x), xeˣ, ln(x² + 1), log₂ x, √(x + 4), ∛27, |x − 1|, π
/// - 계산 · 미분(식으로) · 극한(로피탈 + 수치 확인) · 정적분(두 가지 방법으로 계산해 맞춰 봄)
/// - 깔끔한 값 찾기: 정수 · 분수 · a√m · kπ · a + be · k ln 2 (아주 가까울 때만, 아니면 못 푼 것으로)
enum DoitMathCalc {
    indirect enum Node {
        case number(Double)
        case variable
        case negate(Node)
        case binary(Character, Node, Node)
        case function(String, Node)
        case log(Double, Node)   // 밑, 진수

        func eval(_ x: Double) -> Double? {
            switch self {
            case .number(let v): return v
            case .variable: return x
            case .negate(let a): return a.eval(x).map { -$0 }
            case .binary(let op, let a, let b):
                guard let p = a.eval(x), let q = b.eval(x) else { return nil }
                let v: Double
                switch op {
                case "+": v = p + q
                case "-": v = p - q
                case "*": v = p * q
                case "/":
                    guard abs(q) > 1e-300 else { return nil }
                    v = p / q
                default:
                    // 음수의 거듭제곱은 정수 지수일 때만
                    if p < 0, q != q.rounded() { return nil }
                    if p == 0, q <= 0 { return nil }
                    v = pow(p, q)
                }
                return v.isFinite ? v : nil
            case .function(let name, let a):
                guard let u = a.eval(x) else { return nil }
                let v: Double
                switch name {
                case "sin": v = Foundation.sin(u)
                case "cos": v = Foundation.cos(u)
                case "tan":
                    let c = Foundation.cos(u)
                    guard abs(c) > 1e-12 else { return nil }
                    v = Foundation.sin(u) / c
                case "ln":
                    guard u > 0 else { return nil }
                    v = Foundation.log(u)
                case "exp": v = Foundation.exp(u)
                case "sqrt":
                    guard u >= 0 else { return nil }
                    v = u.squareRoot()
                case "cbrt": v = Foundation.cbrt(u)
                case "root4":
                    guard u >= 0 else { return nil }
                    v = pow(u, 0.25)
                case "abs": v = Swift.abs(u)
                case "sign":
                    guard u != 0 else { return nil }
                    v = u > 0 ? 1 : -1
                default: return nil
                }
                return v.isFinite ? v : nil
            case .log(let base, let a):
                guard let u = a.eval(x), u > 0, base > 0, base != 1 else { return nil }
                return Foundation.log(u) / Foundation.log(base)
            }
        }

        var hasVariable: Bool {
            switch self {
            case .number: return false
            case .variable: return true
            case .negate(let a): return a.hasVariable
            case .binary(_, let a, let b): return a.hasVariable || b.hasVariable
            case .function(_, let a): return a.hasVariable
            case .log(_, let a): return a.hasVariable
            }
        }

        /// 절댓값 안의 식들 (꺾이는 점에서 적분을 나누려고)
        var absoluteArguments: [Node] {
            switch self {
            case .number, .variable: return []
            case .negate(let a): return a.absoluteArguments
            case .binary(_, let a, let b): return a.absoluteArguments + b.absoluteArguments
            case .function(let name, let a): return (name == "abs" ? [a] : []) + a.absoluteArguments
            case .log(_, let a): return a.absoluteArguments
            }
        }

        /// 초월함수(sin, e, ln, √ …)가 들어 있는지
        var isTranscendental: Bool {
            switch self {
            case .number, .variable: return false
            case .negate(let a): return a.isTranscendental
            case .binary(let op, let a, let b):
                if op == "^", b.hasVariable { return true }
                if op == "^", case .number(let k) = b, k != k.rounded() || k < 0 { return true }
                if op == "/", b.hasVariable { return true }
                return a.isTranscendental || b.isTranscendental
            case .function, .log: return true
            }
        }

        /// 도함수 (식으로)
        var derivative: Node {
            switch self {
            case .number: return .number(0)
            case .variable: return .number(1)
            case .negate(let a): return .negate(a.derivative)
            case .binary(let op, let u, let v):
                let du = u.derivative, dv = v.derivative
                switch op {
                case "+": return .binary("+", du, dv)
                case "-": return .binary("-", du, dv)
                case "*": return .binary("+", .binary("*", du, v), .binary("*", u, dv))
                case "/": return .binary("/", .binary("-", .binary("*", du, v), .binary("*", u, dv)), .binary("^", v, .number(2)))
                default:
                    if !v.hasVariable {
                        // (u^k)' = k u^(k−1) u'
                        return .binary("*", .binary("*", v, .binary("^", u, .binary("-", v, .number(1)))), du)
                    }
                    if !u.hasVariable {
                        // (c^v)' = c^v ln c · v'
                        return .binary("*", .binary("*", self, .function("ln", u)), dv)
                    }
                    // u^v = e^(v ln u)
                    return .binary("*", self, .binary("+", .binary("*", dv, .function("ln", u)), .binary("/", .binary("*", v, du), u)))
                }
            case .function(let name, let u):
                let du = u.derivative
                let outer: Node
                switch name {
                case "sin": outer = .function("cos", u)
                case "cos": outer = .negate(.function("sin", u))
                case "tan": outer = .binary("/", .number(1), .binary("^", .function("cos", u), .number(2)))
                case "ln": outer = .binary("/", .number(1), u)
                case "exp": outer = .function("exp", u)
                case "sqrt": outer = .binary("/", .number(1), .binary("*", .number(2), .function("sqrt", u)))
                case "cbrt": outer = .binary("/", .number(1), .binary("*", .number(3), .binary("^", .function("cbrt", u), .number(2))))
                case "root4": outer = .binary("/", .number(1), .binary("*", .number(4), .binary("^", .function("root4", u), .number(3))))
                case "abs": outer = .function("sign", u)
                default: outer = .number(0)
                }
                return .binary("*", outer, du)
            case .log(let base, let u):
                return .binary("/", u.derivative, .binary("*", u, .number(Foundation.log(base))))
            }
        }
    }

    // MARK: - 읽기

    /// 위첨자 덩어리 → ^(…) ("3ⁿ⁺¹" → "3^(n+1)", "e²ˣ" → "e^(2x)", "x²" → "x^(2)")
    static func superscripts(_ s: String) -> String {
        let map: [Character: Character] = ["⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4", "⁵": "5", "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9",
                                           "⁺": "+", "⁻": "-", "ⁿ": "n", "ˣ": "x", "ᵗ": "t", "ᵏ": "k", "⁽": "(", "⁾": ")"]
        var out = "", run = ""
        func flush() {
            guard !run.isEmpty else { return }
            out += run.count == 1 ? "^" + run : "^(" + run + ")"
            run = ""
        }
        for ch in s {
            if let m = map[ch] { run.append(m) } else { flush(); out.append(ch) }
        }
        flush()
        return out
    }

    /// 계산하기 좋은 모양으로 (아래첨자는 "_2", 공백 없음)
    static func prepare(_ raw: String) -> String {
        let subs: [Character: String] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9"]
        var s = ""
        var inSub = false
        for ch in superscripts(raw) {
            if let v = subs[ch] { if !inSub { s += "_" }; s += v; inSub = true } else { inSub = false; s.append(ch) }
        }
        s = DoitAlgebra.normalize(s)
        for (from, to) in [(" ", ""), ("{", "("), ("}", ")"), ("[", "("), ("]", ")"), ("·", "*"), ("⋅", "*"), ("∙", "*")] {
            s = s.replacingOccurrences(of: from, with: to)
        }
        return s
    }

    /// 식 읽기 (변수 하나: x, n, t …). 모르는 글자나 애매한 모양이 있으면 nil
    static func parse(_ raw: String, variable: Character = "x") -> Node? {
        let s = prepare(raw)
        guard !s.isEmpty else { return nil }
        var p = Parser(c: Array(s), v: variable)
        guard let n = p.expression(), p.i == p.c.count, !p.ambiguous else { return nil }
        return n
    }

    private struct Parser {
        let c: [Character]
        let v: Character
        var i = 0
        var ambiguous = false
        var peek: Character? { i < c.count ? c[i] : nil }

        func starts(_ word: String) -> Bool {
            let w = Array(word)
            guard i + w.count <= c.count else { return false }
            return Array(c[i..<(i + w.count)]) == w
        }
        var startsFunction: Bool { ["sin", "cos", "tan", "ln", "log", "exp"].contains { starts($0) } }

        mutating func expression() -> Node? {
            guard var value = term() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                i += 1
                guard let r = term() else { return nil }
                value = .binary(op, value, r)
            }
            return value
        }

        mutating func term() -> Node? {
            guard var value = unary() else { return nil }
            while let op = peek {
                if op == "*" || op == "/" {
                    i += 1
                    guard let r = unary() else { return nil }
                    value = .binary(op, value, r)
                } else if op == "(" || op == v || op == "π" || op == "e" || op == "√" || op == "∛" || op == "∜" || op.isNumber || startsFunction {
                    // 곱하기 기호 생략 (2x, 3(x+1), xeˣ, 2sin x)
                    if op.isNumber, let last = i > 0 ? c[i - 1] : nil, last == ")" || last == v {
                        // "x2"처럼 문자 뒤의 수는 곱으로 읽지 않음 (지수인지 알 수 없어요)
                        ambiguous = true
                    }
                    guard let r = power() else { return nil }
                    value = .binary("*", value, r)
                } else { break }
            }
            return value
        }

        mutating func unary() -> Node? {
            if peek == "-" { i += 1; return unary().map { .negate($0) } }
            if peek == "+" { i += 1; return unary() }
            return power()
        }

        mutating func power() -> Node? {
            guard let base = primary() else { return nil }
            guard peek == "^" else { return base }
            i += 1
            // 지수: 부호 + 괄호·수·문자 하나 (2^-x, e^(2x), 3^n)
            var negative = false
            if peek == "-" { negative = true; i += 1 } else if peek == "+" { i += 1 }
            guard let e = exponentAtom() else { return nil }
            let exponent: Node = negative ? .negate(e) : e
            // 지수 다음에 또 ^가 오면 오른쪽부터 (2^3^2 = 2^9)
            if peek == "^" {
                i += 1
                guard let more = exponentAtom() else { return nil }
                return .binary("^", base, .binary("^", exponent, more))
            }
            return .binary("^", base, exponent)
        }

        mutating func exponentAtom() -> Node? {
            guard let ch = peek else { return nil }
            if ch == "(" { return primary() }
            if ch == v { i += 1; return .variable }
            if ch.isNumber {
                let n = number()
                // "e^2x": 지수가 2x인지 e²·x인지 알 수 없어요
                if peek == v { ambiguous = true }
                return n
            }
            return nil
        }

        mutating func number() -> Node? {
            var digits = ""
            while let d = peek, d.isNumber || d == "." { digits.append(d); i += 1 }
            return Double(digits).map { .number($0) }
        }

        /// 함수의 인수: 괄호가 있으면 괄호, 없으면 곱으로 이어진 짧은 덩어리 (sin 3x, ln x, sin πx)
        mutating func argument() -> Node? {
            if peek == "(" { return primary() }
            var parts: [Node] = []
            while let ch = peek {
                if ch.isNumber { guard let n = number() else { return nil }; parts.append(n) }
                else if ch == v { i += 1; parts.append(.variable) }
                else if ch == "π" { i += 1; parts.append(.number(.pi)) }
                else { break }
                // 덩어리 끝의 거듭제곱 (sin x², ln x²)
                if peek == "^" {
                    i += 1
                    guard let e = exponentAtom() else { return nil }
                    parts[parts.count - 1] = .binary("^", parts[parts.count - 1], e)
                }
            }
            guard var value = parts.first else { return nil }
            // "sin π/6", "sin x/2"는 sin(π)/6 인지 sin(π/6) 인지 알 수 없어요 ("sin 3x / x"는 (sin 3x)/x)
            if peek == "/", i + 1 < c.count, c[i + 1].isNumber || c[i + 1] == "π" { ambiguous = true }
            for p in parts.dropFirst() { value = .binary("*", value, p) }
            return value
        }

        mutating func primary() -> Node? {
            guard let ch = peek else { return nil }
            if ch == "(" {
                i += 1
                guard let inner = expression(), peek == ")" else { return nil }
                i += 1
                return inner
            }
            if ch == "|" {
                i += 1
                guard let inner = expression(), peek == "|" else { return nil }
                i += 1
                return .function("abs", inner)
            }
            for name in ["sin", "cos", "tan"] where starts(name) {
                i += name.count
                // sin²x, sin^2 x
                var exponent: Node?
                if peek == "^" {
                    i += 1
                    guard let e = exponentAtom() else { return nil }
                    exponent = e
                }
                guard let arg = argument() else { return nil }
                let value = Node.function(name, arg)
                return exponent.map { .binary("^", value, $0) } ?? value
            }
            if starts("exp") {
                i += 3
                return argument().map { .function("exp", $0) }
            }
            if starts("ln") {
                i += 2
                return argument().map { .function("ln", $0) }
            }
            if starts("log") {
                i += 3
                var base = 10.0
                if peek == "_" {
                    i += 1
                    guard let b = number(), case .number(let value) = b else { return nil }
                    base = value
                }
                return argument().map { .log(base, $0) }
            }
            if ch == "√" || ch == "∛" || ch == "∜" {
                i += 1
                let name = ch == "√" ? "sqrt" : ch == "∛" ? "cbrt" : "root4"
                if peek == "(" { return primary().map { .function(name, $0) } }
                // √2x: √(2x)인지 √2·x인지 알 수 없어요
                if let d = peek, d.isNumber {
                    guard let n = number() else { return nil }
                    if peek == v || peek == "(" { ambiguous = true }
                    return .function(name, n)
                }
                if peek == v { i += 1; return .function(name, .variable) }
                return nil
            }
            if ch == v { i += 1; return .variable }
            if ch == "π" { i += 1; return .number(.pi) }
            if ch == "e" { i += 1; return .number(M_E) }
            if ch.isNumber { return number() }
            return nil
        }
    }

    // MARK: - 정확한 유리수 계산 (사칙연산과 정수 지수만)

    typealias Rat = DoitMathExact.Rat

    /// 소수로 읽은 수를 유리수로 (0.3 → 3/10)
    static func rat(_ v: Double) -> Rat? {
        guard v.isFinite, abs(v) < 1e12 else { return nil }
        for q in [1, 2, 4, 5, 8, 10, 20, 25, 40, 50, 100, 1000, 10000] {
            let p = (v * Double(q)).rounded()
            if abs(p / Double(q) - v) < 1e-12 * max(1, abs(v)) { return Rat(Int(p), q) }
        }
        return nil
    }

    static func evalRat(_ node: Node, _ x: Rat?) -> Rat? {
        switch node {
        case .number(let v): return rat(v)
        case .variable: return x
        case .negate(let a): return evalRat(a, x).map { -$0 }
        case .binary(let op, let a, let b):
            guard let p = evalRat(a, x), let q = evalRat(b, x) else { return nil }
            switch op {
            case "+": return p + q
            case "-": return p - q
            case "*": return p * q
            case "/": return p / q
            default:
                guard q.isInteger, abs(q.n) <= 40 else { return nil }
                if p.isZero && q.n <= 0 { return nil }
                return p.power(q.n)
            }
        case .function, .log: return nil
        }
    }

    // MARK: - 깔끔한 값

    struct Allow: OptionSet {
        let rawValue: Int
        static let surd = Allow(rawValue: 1)
        static let pi = Allow(rawValue: 2)
        static let e = Allow(rawValue: 4)
        static let ln = Allow(rawValue: 8)
        static let all: Allow = [.surd, .pi, .e, .ln]
    }

    private static func rational(_ v: Double, maxDen: Int, tol: Double) -> (Int, Int)? {
        guard v.isFinite, abs(v) < 1e12 else { return nil }
        for q in 1...maxDen {
            let p = (v * Double(q)).rounded()
            if abs(v - p / Double(q)) <= tol * max(1, abs(v)) {
                let n = Int(p)
                let g = max(1, DoitAlgebra.gcd(abs(n), q))
                return (n / g, q / g)
            }
        }
        return nil
    }

    private static func fracText(_ n: Int, _ d: Int) -> String {
        if d == 1 { return String(n) }
        return n < 0 ? "−\(-n)/\(d)" : "\(n)/\(d)"
    }

    /// 계수 · 기호 ("2π", "−π/2", "3√2/2", "√3")
    private static func scaled(_ n: Int, _ d: Int, _ symbol: String) -> String {
        let sign = n < 0 ? "−" : ""
        let k = abs(n)
        let head = (k == 1 ? "" : "\(k)") + symbol
        return sign + head + (d == 1 ? "" : "/\(d)")
    }

    /// 값을 깔끔한 모양으로 (정확히 맞는 모양을 못 찾으면 nil)
    static func nice(_ v: Double, allow: Allow = [.surd], tol: Double = 1e-9, maxDen: Int = 60) -> String? {
        guard v.isFinite else { return nil }
        if abs(v) < tol { return "0" }
        if let (n, d) = rational(v, maxDen: maxDen, tol: tol) { return fracText(n, d) }
        if allow.contains(.surd) {
            for m in [2, 3, 5, 6, 7, 10, 11, 13, 14, 15, 17, 19, 21, 22, 23, 26, 29, 30] {
                if let (n, d) = rational(v / Double(m).squareRoot(), maxDen: 12, tol: tol), abs(n) <= 200 { return scaled(n, d, "√\(m)") }
            }
            // a + b√m
            for m in [2, 3, 5, 6, 7] {
                for bd in 1...4 {
                    for bn in -12...12 where bn != 0 {
                        guard DoitAlgebra.gcd(abs(bn), bd) == 1 else { continue }
                        let rest = v - Double(bn) / Double(bd) * Double(m).squareRoot()
                        if let (n, d) = rational(rest, maxDen: 12, tol: tol), n != 0, abs(n) <= 100 {
                            let surd = scaled(bn, bd, "√\(m)")
                            return fracText(n, d) + (bn < 0 ? " − " + String(surd.dropFirst()) : " + " + surd)
                        }
                    }
                }
            }
        }
        if allow.contains(.pi) {
            if let (n, d) = rational(v / .pi, maxDen: 24, tol: tol), abs(n) <= 100 { return scaled(n, d, "π") }
        }
        if allow.contains(.e) {
            for (symbol, c) in [("e", M_E), ("e²", M_E * M_E)] {
                if let (n, d) = rational(v / c, maxDen: 12, tol: tol), abs(n) <= 50 { return scaled(n, d, symbol) }
                for bd in 1...2 {
                    for bn in -4...4 where bn != 0 {
                        let rest = v - Double(bn) / Double(bd) * c
                        if let (n, d) = rational(rest, maxDen: 12, tol: tol), n != 0, abs(n) <= 50 {
                            let term = scaled(bn, bd, symbol)
                            // "e − 1", "2 − e"
                            if bn > 0 { return term + (n < 0 ? " − " + fracText(-n, d) : " + " + fracText(n, d)) }
                            return fracText(n, d) + " − " + String(term.dropFirst())
                        }
                    }
                }
            }
        }
        if allow.contains(.ln) {
            for b in [2, 3, 5, 10] {
                if let (n, d) = rational(v / Foundation.log(Double(b)), maxDen: 6, tol: tol), abs(n) <= 20 { return scaled(n, d, "ln \(b)") }
            }
        }
        return nil
    }

    /// 문제 글에 든 기호로 어떤 모양까지 허용할지
    static func allow(for text: String) -> Allow {
        var a: Allow = [.surd]
        if text.contains("π") || text.range(of: "sin|cos|tan", options: .regularExpression) != nil { a.insert(.pi) }
        if text.contains("e") || text.contains("ln") { a.insert(.e); a.insert(.ln) }
        return a
    }

    // MARK: - 정적분

    private static let gaussNodes: [(Double, Double)] = [
        (0, 0.5688888888888889), (-0.5384693101056831, 0.4786286704993665), (0.5384693101056831, 0.4786286704993665),
        (-0.9061798459386640, 0.2369268850561891), (0.9061798459386640, 0.2369268850561891)
    ]

    private static func gauss(_ f: Node, _ a: Double, _ b: Double, panels: Int) -> Double? {
        let h = (b - a) / Double(panels)
        var total = 0.0
        for k in 0..<panels {
            let mid = a + h * (Double(k) + 0.5)
            for (t, w) in gaussNodes {
                guard let y = f.eval(mid + t * h / 2) else { return nil }
                total += w * y * h / 2
            }
        }
        return total
    }

    /// 함수 g의 [a, b] 안 부호가 바뀌는 점 (꺾이는 점 찾기)
    static func signChanges(_ g: (Double) -> Double?, _ a: Double, _ b: Double, samples: Int = 4000) -> [Double] {
        var out: [Double] = []
        var previous: (Double, Double)?
        for j in 0...samples {
            let x = a + (b - a) * Double(j) / Double(samples)
            guard let y = g(x) else { previous = nil; continue }
            if y == 0 { if x > a, x < b { out.append(x) }; previous = (x, y); continue }
            if let (px, py) = previous, py != 0, (py < 0) != (y < 0) {
                var lo = px, hi = x, flo = py
                for _ in 0..<100 {
                    let mid = (lo + hi) / 2
                    guard let fm = g(mid) else { break }
                    if (fm < 0) == (flo < 0) { lo = mid; flo = fm } else { hi = mid }
                }
                out.append((lo + hi) / 2)
            }
            previous = (x, y)
        }
        return out
    }

    /// ∫ₐᵇ f(x) dx (절댓값이 꺾이는 점에서 나누고, 칸 수를 두 번 달리해 같은 값이 나와야 함)
    static func integrate(_ f: Node, _ a: Double, _ b: Double) -> Double? {
        guard a.isFinite, b.isFinite else { return nil }
        if a == b { return 0 }
        let lo = min(a, b), hi = max(a, b)
        var cuts = [lo]
        for arg in f.absoluteArguments { cuts += signChanges({ arg.eval($0) }, lo, hi) }
        cuts.append(hi)
        cuts.sort()
        var total1 = 0.0, total2 = 0.0
        for k in 0..<(cuts.count - 1) where cuts[k + 1] - cuts[k] > 1e-14 {
            guard let p = gauss(f, cuts[k], cuts[k + 1], panels: 300), let q = gauss(f, cuts[k], cuts[k + 1], panels: 700) else { return nil }
            total1 += p; total2 += q
        }
        guard abs(total1 - total2) <= 1e-11 * max(1, abs(total2)) else { return nil }
        return a <= b ? total2 : -total2
    }

    // MARK: - 극한

    enum Approach { case point(Double), left(Double), right(Double), plusInfinity, minusInfinity }

    /// 극한값 (못 정하거나 발산하면 nil)
    static func limit(_ f: Node, _ approach: Approach) -> Double? {
        switch approach {
        case .point(let a):
            guard let l = sideLimit(f, a, side: 1), let r = sideLimit(f, a, side: -1), abs(l - r) <= 1e-7 * max(1, abs(l)) else { return nil }
            return (l + r) / 2
        case .right(let a): return sideLimit(f, a, side: 1)
        case .left(let a): return sideLimit(f, a, side: -1)
        case .plusInfinity: return infinityLimit(f, sign: 1)
        case .minusInfinity: return infinityLimit(f, sign: -1)
        }
    }

    /// 한쪽 극한: 바로 넣기(이어져 있으면) → 로피탈(0/0) → 아주 가까운 곳의 값으로 확인
    private static func sideLimit(_ f: Node, _ a: Double, side: Double) -> Double? {
        let near = [1e-4, 1e-5, 1e-6].map { f.eval(a + side * $0) }
        guard near.allSatisfy({ $0 != nil }) else { return nil }
        let values = near.compactMap { $0 }
        var candidate: Double?
        if let direct = f.eval(a), abs(direct - values[2]) <= 1e-4 * max(1, abs(direct)) {
            candidate = direct
        } else if case .binary("/", let num, let den) = f {
            var n = num, d = den
            for _ in 0..<4 {
                guard let nv = n.eval(a), let dv = d.eval(a) else { break }
                if abs(dv) > 1e-9 {
                    candidate = nv / dv
                    break
                }
                // 분모만 0이면 발산
                guard abs(nv) <= 1e-9 else { return nil }
                n = n.derivative; d = d.derivative
            }
        }
        // 한쪽에서 값이 그대로인 것 (|x − 1|/(x − 1) 의 오른쪽 = 1)
        if candidate == nil, abs(values[0] - values[2]) <= 1e-12 * max(1, abs(values[2])) { candidate = values[2] }
        guard let value = candidate else { return nil }
        // 가까운 곳의 값이 그 값으로 다가가는지 확인 (가까울수록 더 가까워야 함)
        let errors = values.map { abs($0 - value) }
        guard errors[2] <= 1e-3 * max(1, abs(value)), errors[2] <= errors[0] + 1e-9 else { return nil }
        return value
    }

    /// x → ±∞: 큰 값 여러 개에서 계산해 값이 모이는지 확인 (1/x 꼴로 다가가면 리처드슨 외삽)
    private static func infinityLimit(_ f: Node, sign: Double) -> Double? {
        // 지수함수처럼 빨리 다가가는 것
        let steps = [10.0, 20, 40, 80, 160, 320, 640, 1280]
        let fast = steps.compactMap { x in f.eval(sign * x).map { (x, $0) } }
        if fast.count >= 4 {
            let last = fast.suffix(3).map(\.1)
            if abs(last[0] - last[2]) <= 1e-11 * max(1, abs(last[2])), abs(last[1] - last[2]) <= 1e-11 * max(1, abs(last[2])) { return last[2] }
        }
        // 1/x 꼴로 다가가는 것: R(X) = 2f(2X) − f(X)
        let big = [1e4, 2e4, 1e5, 2e5, 1e6, 2e6]
        let values = big.map { f.eval(sign * $0) }
        guard values.allSatisfy({ $0 != nil }) else { return nil }
        let v = values.compactMap { $0 }
        let r1 = 2 * v[1] - v[0], r2 = 2 * v[3] - v[2], r3 = 2 * v[5] - v[4]
        guard abs(r2 - r3) <= 1e-7 * max(1, abs(r3)), abs(r1 - r3) <= 1e-5 * max(1, abs(r3)),
              abs(v[5] - r3) <= 1e-4 * max(1, abs(r3)) else { return nil }
        return r3
    }
}
