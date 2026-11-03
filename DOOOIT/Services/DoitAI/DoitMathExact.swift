import Foundation

/// 두잇 AI 정확한 계산 (분수·제곱근을 소수로 바꾸지 않고 그대로, 외부 AI 없이)
/// - 유리수 · 제곱근 식: 2/3 + 1/4 = 11/12, √12 + √27 = 5√3, 6/√3 = 2√3, tan 45° × cos 30° = √3/2
/// - 단항식 지수법칙: (2x³)² ÷ 4x² = x⁴, (2a²b)³ = 8a⁶b³
/// - 빈칸(□) · 비례식 · 객관식 보기 맞추기
/// - 미지의 상수 구하기 (중근, 지나는 점, 나머지, 최솟값 조건)
/// - 다항식의 나눗셈 (몫과 나머지), 함수의 극한, 두 근 α, β로 된 식의 값
enum DoitMathExact {
    typealias Solved = MathSolver.Solved
    typealias Poly = DoitMath.Poly

    private static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }
    private static func f(_ v: Double) -> String { DoitMath.fraction(v) }

    // MARK: - 정규식 도우미

    /// 처음 맞는 곳의 묶음들 (0번은 전체)
    static func match(_ text: String, _ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        var out: [String] = []
        for i in 0..<m.numberOfRanges {
            if let r = Range(m.range(at: i), in: text) { out.append(String(text[r])) } else { out.append("") }
        }
        return out
    }

    static func matches(_ text: String, _ pattern: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        return re.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { m in
            (0..<m.numberOfRanges).map { i in Range(m.range(at: i), in: text).map { String(text[$0]) } ?? "" }
        }
    }

    // MARK: - 글자 다듬기 (문장 → 계산하기 좋은 모양)

    /// 문장 끝 마침표, 대분수(1과 1/2), ÷ 옆의 분수(5/6 ÷ 10/9)를 계산할 수 있게
    static func tidy(_ raw: String) -> String {
        var t = raw
        // 숫자 사이가 아닌 점은 문장 부호 ("계산하시오. 3 + 4"의 점이 소수점으로 붙지 않게)
        t = t.replacingOccurrences(of: #"(?<![0-9])\.|\.(?![0-9])"#, with: " ", options: .regularExpression)
        // 대분수: 앞이나 뒤에 연산 기호가 있을 때만 (1과 1/2 + 2와 1/3)
        let mixed = #"(\d+)\s*[과와]\s*(\d+)\s*/\s*(\d+)"#
        t = t.replacingOccurrences(of: mixed + #"(?=\s*[+\-−×÷*/=])"#, with: "($1+$2/$3)", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?<=[+\-−×÷*/=]\s{0,3})"# + mixed, with: "($1+$2/$3)", options: .regularExpression)
        // sin²30° → (sin(30))^2
        t = t.replacingOccurrences(of: #"(sin|cos|tan)\s*([²³])\s*\(?\s*(\d+)\s*°?\s*\)?"#, with: "($1($3))$2", options: .regularExpression)
        // ÷가 있으면 a/b는 분수 한 덩어리 (5/6 ÷ 10/9 를 5/6/10/9 로 계산하지 않게)
        if t.contains("÷") {
            t = t.replacingOccurrences(of: #"(?<![\d.)^])(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)(?![\d.(^²³])"#, with: "($1/$2)", options: .regularExpression)
        }
        return t
    }

    // MARK: - 유리수

    /// 2⁵² 보다 커지면 nil (Double로 바꿔도 정확하도록)
    static func mul(_ a: Int, _ b: Int) -> Int? {
        let r = a.multipliedReportingOverflow(by: b)
        guard !r.overflow, abs(r.partialValue) < (1 << 52) else { return nil }
        return r.partialValue
    }

    static func add(_ a: Int, _ b: Int) -> Int? {
        let r = a.addingReportingOverflow(b)
        guard !r.overflow, abs(r.partialValue) < (1 << 52) else { return nil }
        return r.partialValue
    }

    struct Rat: Equatable {
        var n: Int
        var d: Int

        init?(_ n: Int, _ d: Int = 1) {
            guard d != 0 else { return nil }
            let g = max(1, DoitAlgebra.gcd(n, d))
            let sign = d < 0 ? -1 : 1
            self.n = sign * (n / g)
            self.d = abs(d) / g
        }

        static let zero = Rat(0)!
        static let one = Rat(1)!

        var value: Double { Double(n) / Double(d) }
        var isInteger: Bool { d == 1 }
        var isZero: Bool { n == 0 }

        /// "1.25" → 5/4
        static func parse(_ s: String) -> Rat? {
            let parts = s.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard parts.count <= 2, let whole = Int(parts[0].isEmpty ? "0" : parts[0]) else { return nil }
            guard parts.count == 2 else { return Rat(whole) }
            let frac = parts[1]
            guard !frac.isEmpty, frac.count <= 9, let fracValue = Int(frac) else { return nil }
            var scale = 1
            for _ in 0..<frac.count { scale *= 10 }
            guard let big = DoitMathExact.mul(whole, scale), let total = DoitMathExact.add(big, fracValue) else { return nil }
            return Rat(total, scale)
        }

        static func + (a: Rat, b: Rat) -> Rat? {
            guard let x = DoitMathExact.mul(a.n, b.d), let y = DoitMathExact.mul(b.n, a.d),
                  let s = DoitMathExact.add(x, y), let dd = DoitMathExact.mul(a.d, b.d) else { return nil }
            return Rat(s, dd)
        }
        static prefix func - (a: Rat) -> Rat { Rat(-a.n, a.d) ?? a }
        static func - (a: Rat, b: Rat) -> Rat? { a + (-b) }
        static func * (a: Rat, b: Rat) -> Rat? {
            guard let x = DoitMathExact.mul(a.n, b.n), let y = DoitMathExact.mul(a.d, b.d) else { return nil }
            return Rat(x, y)
        }
        static func / (a: Rat, b: Rat) -> Rat? {
            guard b.n != 0, let x = DoitMathExact.mul(a.n, b.d), let y = DoitMathExact.mul(a.d, b.n) else { return nil }
            return Rat(x, y)
        }

        func power(_ k: Int) -> Rat? {
            guard abs(k) <= 64 else { return nil }
            if k < 0 {
                guard let p = power(-k) else { return nil }
                return Rat.one / p
            }
            var out = Rat.one
            for _ in 0..<k { guard let next = out * self else { return nil }; out = next }
            return out
        }

        /// 정수 "3", 분수 "−3/4"
        var text: String {
            if d == 1 { return String(n) }
            return n < 0 ? "−\(-n)/\(d)" : "\(n)/\(d)"
        }

        /// 분모가 2, 5로만 되어 있으면 유한소수 ("0.3", "5.95")
        var decimalText: String? {
            guard d != 1 else { return String(n) }
            var p = 1, k = 0
            while p % d != 0 {
                guard k < 12 else { return nil }
                p *= 10; k += 1
            }
            guard let scaled = DoitMathExact.mul(abs(n), p / d) else { return nil }
            var digits = String(scaled)
            while digits.count <= k { digits = "0" + digits }
            digits.insert(".", at: digits.index(digits.endIndex, offsetBy: -k))
            return (n < 0 ? "−" : "") + digits
        }
    }

    /// 정수의 k제곱근이 정수면 그 값
    static func integerRoot(_ n: Int, _ k: Int) -> Int? {
        guard n >= 0, k >= 1 else { return nil }
        let guess = Int(pow(Double(n), 1 / Double(k)).rounded())
        for c in max(0, guess - 1)...(guess + 1) {
            var p = 1
            var ok = true
            for _ in 0..<k { guard let next = mul(p, c) else { ok = false; break }; p = next }
            if ok && p == n { return c }
        }
        return nil
    }

    // MARK: - 제곱근이 있는 수 (a + b√m + …)

    struct Surd {
        /// 근호 안의 수(제곱인수 없음) → 계수. 1은 유리수 부분
        var terms: [Int: Rat] = [:]

        init(_ r: Rat) { if !r.isZero { terms[1] = r } }
        init(terms: [Int: Rat]) { self.terms = terms.filter { !$0.value.isZero } }

        var rational: Rat? {
            if terms.isEmpty { return .zero }
            if terms.count == 1, let r = terms[1] { return r }
            return nil
        }

        var value: Double {
            var total = 0.0
            for (m, c) in terms { total += c.value * Double(m).squareRoot() }
            return total
        }

        static func + (a: Surd, b: Surd) -> Surd? {
            var out = a.terms
            for (m, c) in b.terms {
                guard let s = (out[m] ?? .zero) + c else { return nil }
                out[m] = s
            }
            return Surd(terms: out)
        }
        static prefix func - (a: Surd) -> Surd { Surd(terms: a.terms.mapValues { -$0 }) }
        static func - (a: Surd, b: Surd) -> Surd? { a + (-b) }

        static func * (a: Surd, b: Surd) -> Surd? {
            var out: [Int: Rat] = [:]
            for (m1, c1) in a.terms {
                for (m2, c2) in b.terms {
                    guard let mm = DoitMathExact.mul(m1, m2), mm < 1_000_000_000_000 else { return nil }
                    let s = DoitAlgebra.simplifyRoot(mm)
                    guard let c = c1 * c2, let outside = Rat(s.outside), let ck = c * outside,
                          let sum = (out[s.inside] ?? .zero) + ck else { return nil }
                    out[s.inside] = sum
                }
            }
            return Surd(terms: out)
        }

        /// √(n/d) = √(nd)/d
        static func sqrt(_ r: Rat) -> Surd? {
            guard r.n >= 0 else { return nil }
            if r.n == 0 { return Surd(.zero) }
            guard let nd = DoitMathExact.mul(r.n, r.d), nd < 1_000_000_000_000 else { return nil }
            let s = DoitAlgebra.simplifyRoot(nd)
            guard let c = Rat(s.outside, r.d) else { return nil }
            return Surd(terms: [s.inside: c])
        }

        /// 1/이 수 (분모의 유리화: 항이 하나면 같은 근호를, 둘이면 켤레를 곱함)
        func inverse() -> Surd? {
            if terms.count == 1, let (m, c) = terms.first {
                guard let radicand = Rat(m), let cm = c * radicand, let inv = Rat.one / cm else { return nil }
                return Surd(terms: [m: inv])
            }
            guard terms.count == 2 else { return nil }
            let keys = terms.keys.sorted()
            guard let c0 = terms[keys[0]], let c1 = terms[keys[1]] else { return nil }
            let conjugate = Surd(terms: [keys[0]: c0, keys[1]: -c1])
            guard let den = self * conjugate, let r = den.rational, !r.isZero, let inv = Rat.one / r else { return nil }
            return conjugate * Surd(inv)
        }

        static func / (a: Surd, b: Surd) -> Surd? {
            guard let inv = b.inverse() else { return nil }
            return a * inv
        }

        /// "5√3", "√3/2", "−2 + √3", "2√3/3"
        var text: String {
            if let r = rational { return r.text }
            var out = ""
            // 양수인 항부터 (−1 + √2 대신 √2 − 1)
            var order = terms.keys.sorted()
            if let firstPositive = order.firstIndex(where: { (terms[$0]?.n ?? 0) > 0 }), firstPositive > 0 {
                let key = order.remove(at: firstPositive)
                order.insert(key, at: 0)
            }
            for (index, m) in order.enumerated() {
                guard let c = terms[m] else { continue }
                let magnitude = abs(c.n)
                var body: String
                if m == 1 {
                    body = c.d == 1 ? "\(magnitude)" : "\(magnitude)/\(c.d)"
                } else {
                    body = (magnitude == 1 ? "" : "\(magnitude)") + "√\(m)" + (c.d == 1 ? "" : "/\(c.d)")
                }
                if index == 0 {
                    out = (c.n < 0 ? "−" : "") + body
                } else {
                    out += c.n < 0 ? " − " : " + "
                    out += body
                }
            }
            return out
        }
    }

    /// 거듭제곱: 정수 지수, 또는 유리수의 분수 지수 (8^(2/3) = 4, 4^(1/2) = 2)
    static func raise(_ base: Surd, _ k: Rat) -> Surd? {
        if k.isInteger {
            let e = k.n
            guard abs(e) <= 64 else { return nil }
            if e == 0 { return base.terms.isEmpty ? nil : Surd(.one) }
            var out = Surd(.one)
            for _ in 0..<abs(e) { guard let next = out * base else { return nil }; out = next }
            return e < 0 ? out.inverse() : out
        }
        guard let r = base.rational, r.n > 0, k.d <= 12 else { return nil }
        if let top = integerRoot(r.n, k.d), let bottom = integerRoot(r.d, k.d), let root = Rat(top, bottom) {
            return raise(Surd(root), Rat(k.n)!)
        }
        if k.d == 2, let root = Surd.sqrt(r) { return raise(root, Rat(k.n)!) }
        return nil
    }

    /// 특수각 (도)의 sin 값
    static func sinSurd(_ degree: Int) -> Surd? {
        let a = ((degree % 360) + 360) % 360
        var reference = a, negative = false
        if a > 90 && a <= 180 { reference = 180 - a }
        else if a > 180 && a <= 270 { reference = a - 180; negative = true }
        else if a > 270 { reference = 360 - a; negative = true }
        let value: Surd?
        switch reference {
        case 0: value = Surd(.zero)
        case 30: value = Surd(Rat(1, 2)!)
        case 45: value = Surd(terms: [2: Rat(1, 2)!])
        case 60: value = Surd(terms: [3: Rat(1, 2)!])
        case 90: value = Surd(.one)
        default: value = nil
        }
        guard let v = value else { return nil }
        return negative ? -v : v
    }

    static func trigSurd(_ name: String, _ degree: Int) -> Surd? {
        switch name {
        case "sin": return sinSurd(degree)
        case "cos": return sinSurd(degree + 90)
        default:
            guard let s = sinSurd(degree), let c = sinSurd(degree + 90), !c.terms.isEmpty else { return nil }
            return s / c
        }
    }

    private struct SurdParser {
        let c: [Character]
        var i = 0
        var peek: Character? { i < c.count ? c[i] : nil }

        func starts(_ word: String) -> Bool {
            let w = Array(word)
            guard i + w.count <= c.count else { return false }
            return Array(c[i..<(i + w.count)]) == w
        }
        var startsTrig: Bool { starts("sin") || starts("cos") || starts("tan") }

        mutating func expression() -> Surd? {
            guard var v = term() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                i += 1
                guard let r = term() else { return nil }
                guard let next = op == "+" ? v + r : v - r else { return nil }
                v = next
            }
            return v
        }

        mutating func term() -> Surd? {
            guard var v = unary() else { return nil }
            while let op = peek {
                if op == "*" || op == "/" {
                    i += 1
                    guard let r = unary() else { return nil }
                    guard let next = op == "*" ? v * r : v / r else { return nil }
                    v = next
                } else if op == "(" || op == "√" || op.isNumber || startsTrig {
                    guard let r = power(), let next = v * r else { return nil }
                    v = next
                } else {
                    break
                }
            }
            return v
        }

        mutating func unary() -> Surd? {
            if peek == "-" { i += 1; return unary().map { -$0 } }
            if peek == "+" { i += 1; return unary() }
            return power()
        }

        mutating func power() -> Surd? {
            guard let base = primary() else { return nil }
            guard peek == "^" else { return base }
            i += 1
            guard let e = unary(), let k = e.rational else { return nil }
            return DoitMathExact.raise(base, k)
        }

        mutating func number() -> Rat? {
            var digits = ""
            while let d = peek, d.isNumber || d == "." { digits.append(d); i += 1 }
            return Rat.parse(digits)
        }

        mutating func primary() -> Surd? {
            guard let ch = peek else { return nil }
            if ch == "(" {
                i += 1
                guard let v = expression(), peek == ")" else { return nil }
                i += 1
                return v
            }
            if ch == "√" {
                i += 1
                guard let inner = power(), let r = inner.rational else { return nil }
                return Surd.sqrt(r)
            }
            if ch == "|" {
                // 절댓값 (유리수만)
                i += 1
                guard let inner = expression(), peek == "|", let r = inner.rational else { return nil }
                i += 1
                return Surd(r.n < 0 ? -r : r)
            }
            if startsTrig {
                let name = String(c[i..<(i + 3)])
                i += 3
                var angle: Rat?
                if peek == "(" {
                    i += 1
                    angle = expression()?.rational
                    guard peek == ")" else { return nil }
                    i += 1
                } else {
                    var negative = false
                    if peek == "-" { negative = true; i += 1 }
                    angle = number().map { negative ? -$0 : $0 }
                }
                guard let a = angle, a.isInteger else { return nil }
                return DoitMathExact.trigSurd(name, a.n)
            }
            guard ch.isNumber, let r = number() else { return nil }
            return Surd(r)
        }
    }

    /// 식을 정확한 값으로 (π, log, !, % 처럼 정확히 못 다루는 것이 있으면 nil)
    static func exactValue(_ expression: String) -> Surd? {
        var s = DoitAlgebra.normalize(expression).lowercased()
        for (from, to) in [(" ", ""), ("°", ""), ("[", "("), ("]", ")"), ("{", "("), ("}", ")")] { s = s.replacingOccurrences(of: from, with: to) }
        s = superscriptsToPowers(s)
        guard !s.isEmpty, s.allSatisfy({ "0123456789.+-*/^()√sincota|".contains($0) }) else { return nil }
        var parser = SurdParser(c: Array(s))
        guard let v = parser.expression(), parser.i == parser.c.count else { return nil }
        return v
    }

    /// ⁷ ⁸ ⁹ ⁰ ¹ 같이 normalize가 바꾸지 않는 위첨자도 ^n으로
    static func superscriptsToPowers(_ s: String) -> String {
        let map: [Character: Character] = ["⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4", "⁵": "5", "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9"]
        var out = ""
        var inSuper = false
        for ch in s {
            if let d = map[ch] {
                if !inSuper { out.append("^"); inSuper = true }
                out.append(d)
            } else {
                inSuper = false
                out.append(ch)
            }
        }
        return out
    }

    /// 사칙연산·분수·제곱근·특수각 계산 (정확한 값으로)
    static func exactCalc(_ expression: String, original: String) -> Solved? {
        guard let value = exactValue(expression) else { return nil }
        let shown = expression.replacingOccurrences(of: "*", with: "×").replacingOccurrences(of: "-", with: "−")
        var steps = [SolutionStep(hint: "식", work: shown)]
        let compact = DoitAlgebra.normalize(expression).replacingOccurrences(of: " ", with: "")
        // 근호 안을 간단히: √12 = 2√3
        let roots = matches(compact, #"√(\d+)"#).compactMap { Int($0[1]) }
        let simplified = roots.compactMap { n -> String? in
            let s = DoitAlgebra.simplifyRoot(n)
            return s.outside > 1 ? "√\(n) = \(DoitAlgebra.rootText(s.outside, s.inside))" : nil
        }
        if !simplified.isEmpty { steps.append(SolutionStep(hint: "근호 안의 제곱인수를 밖으로 꺼내면", work: simplified.joined(separator: ", "))) }
        if compact.range(of: #"/\(?[\d.]*√"#, options: .regularExpression) != nil {
            steps.append(SolutionStep(hint: "분모에 근호가 있으면?", work: "분자와 분모에 같은 근호(또는 켤레식)를 곱해서 분모를 유리화해요"))
        }
        if has(compact, ["sin", "cos", "tan"]) {
            steps.append(SolutionStep(hint: "특수각의 삼각비", work: "sin 30° = 1/2, sin 45° = √2/2, sin 60° = √3/2, cos 60° = 1/2, tan 45° = 1, tan 60° = √3"))
        }
        var answer: String
        if let r = value.rational {
            let decimalInput = compact.range(of: #"\d\.\d"#, options: .regularExpression) != nil && !compact.contains("√")
            if r.isInteger {
                answer = r.text
            } else if decimalInput, let decimal = r.decimalText {
                answer = decimal
            } else {
                answer = r.text
                if abs(r.n) > r.d && original.range(of: #"\d\s*[과와]\s*\d+\s*/"#, options: .regularExpression) != nil {
                    let whole = abs(r.n) / r.d, rest = abs(r.n) % r.d
                    answer += " (= \(r.n < 0 ? "−" : "")\(whole)과 \(rest)/\(r.d))"
                } else {
                    answer += " (≈ \(DoitMath.format(r.value, digits: 6)))"
                }
            }
            if compact.contains("/") && !r.isInteger && !compact.contains("√") {
                steps.append(SolutionStep(hint: "분수는 통분하고, 나눗셈은 역수를 곱해서 계산하면", work: answer))
            } else {
                steps.append(SolutionStep(hint: "계산 순서대로 (괄호 → 거듭제곱 → ×÷ → +−)", work: answer))
            }
        } else {
            answer = "\(value.text) (≈ \(DoitMath.format(value.value, digits: 6)))"
            steps.append(SolutionStep(hint: "같은 근호끼리 모아서 계산하면", work: value.text))
        }
        let topic = compact.contains("√") ? "제곱근의 계산" : has(compact, ["sin", "cos", "tan"]) ? "삼각비의 값" : "계산"
        let concept = compact.contains("√")
            ? "√a × √b = √(ab), m√a + n√a = (m + n)√a. 근호 안의 제곱인수는 밖으로 꺼내고, 분모의 근호는 유리화해요."
            : "괄호 → 거듭제곱 → 곱셈·나눗셈 → 덧셈·뺄셈 순서로 계산해요. 분수의 덧셈은 통분, 나눗셈은 역수의 곱셈이에요."
        return Solved(kind: .calc, topic: topic, concept: concept, steps: steps, answer: answer)
    }

    /// 수식 옆에 x, y, z가 아닌 영어 소문자가 있는지 (sin, log, f(x), n(A) 같은 말은 빼고)
    static func hasStrayLetters(_ t: String) -> Bool {
        var s = t
        for w in ["sin", "cos", "tan", "log", "ln", "lim", "dx", "sqrt", "pi"] { s = s.replacingOccurrences(of: w, with: " ") }
        s = s.replacingOccurrences(of: #"[fghnP]\s*'?\s*\("#, with: "(", options: .regularExpression)
        // 단위 (3 km, 5 cm, 2 kg)는 문자가 아님
        s = s.replacingOccurrences(of: #"(\d)\s*(?:km|cm|mm|kg|mg|ml|mL|m|g|s|L)(?![a-z])"#, with: "$1 ", options: .regularExpression)
        return s.range(of: #"[0-9)^*/+\-=(]\s*[abcdgjkmnpqrstuvw](?![가-힣])|(?<![a-z])[abcdgjkmnpqrstuvw]\s*[0-9(^*/+\-=]"#, options: .regularExpression) != nil
    }

    /// |−5| + |3| 처럼 수의 절댓값 계산
    static func absoluteCalc(_ text: String) -> Solved? {
        let allowed = Set("0123456789.+-*/^()| ")
        var best = "", current = ""
        func commit() {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("|"), trimmed.count > best.count { best = trimmed }
            current = ""
        }
        for ch in DoitAlgebra.normalize(text) { if allowed.contains(ch) { current.append(ch) } else { commit() } }
        commit()
        guard best.filter({ $0 == "|" }).count % 2 == 0, let value = exactValue(best), let r = value.rational else { return nil }
        let shown = best.replacingOccurrences(of: "*", with: "×").replacingOccurrences(of: "-", with: "−")
        return Solved(kind: .calc, topic: "절댓값의 계산", concept: "절댓값은 수직선에서 0까지의 거리라 항상 0 이상이에요. |−5| = 5, |3| = 3",
                      steps: [SolutionStep(hint: "식", work: shown), SolutionStep(hint: "절댓값을 먼저 구해서 계산하면", work: r.text)], answer: r.text)
    }

    // MARK: - 단항식 (지수법칙)

    struct Mono {
        var c: Rat
        var e: [Character: Int]

        static func * (a: Mono, b: Mono) -> Mono? {
            guard let c = a.c * b.c else { return nil }
            var e = a.e
            for (k, v) in b.e { e[k, default: 0] += v }
            return Mono(c: c, e: e.filter { $0.value != 0 })
        }
        static func / (a: Mono, b: Mono) -> Mono? {
            guard let c = a.c / b.c else { return nil }
            var e = a.e
            for (k, v) in b.e { e[k, default: 0] -= v }
            return Mono(c: c, e: e.filter { $0.value != 0 })
        }
        func power(_ k: Int) -> Mono? {
            guard let c = self.c.power(k) else { return nil }
            return Mono(c: c, e: e.mapValues { $0 * k }.filter { $0.value != 0 })
        }

        var text: String {
            var top = "", bottom = ""
            for letter in e.keys.sorted() {
                guard let k = e[letter] else { continue }
                if k > 0 { top += "\(letter)" + DoitMath.superscript(k) } else { bottom += "\(letter)" + DoitMath.superscript(-k) }
            }
            let sign = c.n < 0 ? "−" : ""
            let numerator = (abs(c.n) == 1 && !top.isEmpty) ? top : "\(abs(c.n))" + top
            let denominator = (c.d == 1 ? "" : "\(c.d)") + bottom
            if denominator.isEmpty { return sign + numerator }
            let factors = (c.d == 1 ? 0 : 1) + e.values.filter { $0 < 0 }.count
            return sign + numerator + "/" + (factors > 1 ? "(\(denominator))" : denominator)
        }
    }

    private struct MonoParser {
        let c: [Character]
        var i = 0
        var parts: [Mono] = []
        var peek: Character? { i < c.count ? c[i] : nil }

        mutating func product(top: Bool = false) -> Mono? {
            guard var v = term() else { return nil }
            if top { parts.append(v) }
            while let op = peek, op == "*" || op == "/" {
                i += 1
                // 한국 교과서: "÷ 4x²"는 4x² 전체로 나눔
                guard let r = term() else { return nil }
                if top { parts.append(r) }
                guard let next = op == "*" ? v * r : v / r else { return nil }
                v = next
            }
            return v
        }

        mutating func term() -> Mono? {
            var negative = false
            while peek == "-" { negative.toggle(); i += 1 }
            guard var v = factor() else { return nil }
            while let p = peek, p == "(" || p.isNumber || (p.isLetter && p.isASCII) {
                guard let r = factor(), let next = v * r else { return nil }
                v = next
            }
            return negative ? Mono(c: -v.c, e: v.e) : v
        }

        mutating func factor() -> Mono? {
            guard var b = base() else { return nil }
            while peek == "^" {
                i += 1
                var negative = false
                if peek == "-" { negative = true; i += 1 }
                var digits = ""
                while let d = peek, d.isNumber { digits.append(d); i += 1 }
                guard let k = Int(digits), k <= 64, let next = b.power(negative ? -k : k) else { return nil }
                b = next
            }
            return b
        }

        mutating func base() -> Mono? {
            guard let ch = peek else { return nil }
            if ch == "(" {
                i += 1
                guard let v = product(), peek == ")" else { return nil }
                i += 1
                return v
            }
            if ch.isLetter && ch.isASCII {
                i += 1
                return Mono(c: .one, e: [ch: 1])
            }
            var digits = ""
            while let d = peek, d.isNumber || d == "." { digits.append(d); i += 1 }
            guard !digits.isEmpty, let r = Rat.parse(digits) else { return nil }
            return Mono(c: r, e: [:])
        }
    }

    /// (x²)³ × x⁴, (2x³)² ÷ 4x², (2a²b)³ 처럼 곱셈·나눗셈·거듭제곱만 있는 단항식
    static func monomial(_ text: String) -> Solved? {
        let t = DoitAlgebra.normalize(text)
        guard !has(t, ["=", "<", ">", "≤", "≥", "sin", "cos", "tan", "log", "lim", "ln", "∫", "적분", "미분", "|", "!"]) else { return nil }
        let allowed = Set("0123456789.()^*/- abcdfghjklmnopqrstuvwxyz⁰¹²³⁴⁵⁶⁷⁸⁹")
        var best = "", current = ""
        func commit() {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if trimmed.count > best.count, trimmed.contains(where: { $0.isLetter && $0.isASCII }) { best = trimmed }
            current = ""
        }
        for ch in t { if allowed.contains(ch) { current.append(ch) } else { commit() } }
        commit()
        let expression = superscriptsToPowers(best.replacingOccurrences(of: " ", with: ""))
        guard expression.count >= 3, has(expression, ["^", "*", "/", "("]) else { return nil }
        // f(x), n(A) 같은 함수 표기는 단항식이 아님
        guard expression.range(of: #"[a-z]\("#, options: .regularExpression) == nil else { return nil }
        // 수식 밖에 다른 식이 더 있으면 (예: 문장 속 다른 수식) 건드리지 않음
        let others = t.replacingOccurrences(of: best, with: " ")
        guard others.range(of: #"[0-9][\s]*[+\-*/^]|[+\-*/^]\s*[0-9a-z]"#, options: .regularExpression) == nil else { return nil }
        var parser = MonoParser(c: Array(expression))
        guard let value = parser.product(top: true), parser.i == parser.c.count, !value.e.isEmpty else { return nil }
        var steps = [SolutionStep(hint: "식", work: best.replacingOccurrences(of: "*", with: "×").replacingOccurrences(of: "/", with: "÷"))]
        if parser.parts.count > 1 {
            steps.append(SolutionStep(hint: "괄호의 거듭제곱부터: (aᵐ)ⁿ = aᵐⁿ, (ab)ⁿ = aⁿbⁿ", work: parser.parts.map(\.text).joined(separator: ", ")))
        }
        steps.append(SolutionStep(hint: "계수끼리, 같은 문자끼리 지수를 더하거나(곱셈) 빼면(나눗셈)", work: value.text))
        return Solved(kind: .expression, topic: "지수법칙 (단항식의 계산)",
                      concept: "aᵐ × aⁿ = aᵐ⁺ⁿ, aᵐ ÷ aⁿ = aᵐ⁻ⁿ, (aᵐ)ⁿ = aᵐⁿ, (ab)ⁿ = aⁿbⁿ. 나눗셈은 역수의 곱셈으로 바꿔도 돼요.",
                      steps: steps, answer: value.text)
    }

    // MARK: - 실수 계산기 (변수 하나, 근 찾기용)

    indirect enum Node {
        case number(Double)
        case variable(Character)
        case negate(Node)
        case binary(Character, Node, Node)
        case root(Node)

        func eval(_ vars: [Character: Double]) -> Double? {
            switch self {
            case .number(let v): return v
            case .variable(let name): return vars[name]
            case .negate(let a): return a.eval(vars).map { -$0 }
            case .root(let a):
                guard let v = a.eval(vars), v >= 0 else { return nil }
                return v.squareRoot()
            case .binary(let op, let a, let b):
                guard let x = a.eval(vars), let y = b.eval(vars) else { return nil }
                switch op {
                case "+": return x + y
                case "-": return x - y
                case "*": return x * y
                case "/": return abs(y) < 1e-15 ? nil : x / y
                default:
                    let v = pow(x, y)
                    return v.isFinite ? v : nil
                }
            }
        }

        func evalComplex(_ vars: [Character: DoitMathTopics.Complex]) -> DoitMathTopics.Complex? {
            typealias C = DoitMathTopics.Complex
            switch self {
            case .number(let v): return C(re: v, im: 0)
            case .variable(let name): return vars[name]
            case .negate(let a): return a.evalComplex(vars).map { C(re: -$0.re, im: -$0.im) }
            case .root: return nil
            case .binary(let op, let a, let b):
                guard let x = a.evalComplex(vars), let y = b.evalComplex(vars) else { return nil }
                switch op {
                case "+": return x + y
                case "-": return x - y
                case "*": return x * y
                case "/": return x / y
                default:
                    guard abs(y.im) < 1e-12, y.re == y.re.rounded(), abs(y.re) <= 20 else { return nil }
                    var out = C(re: 1, im: 0)
                    for _ in 0..<Int(abs(y.re)) { out = out * x }
                    return y.re < 0 ? C(re: 1, im: 0) / out : out
                }
            }
        }
    }

    private struct NodeParser {
        let c: [Character]
        let variables: Set<Character>
        var i = 0
        var peek: Character? { i < c.count ? c[i] : nil }

        mutating func expression() -> Node? {
            guard var v = term() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                i += 1
                guard let r = term() else { return nil }
                v = .binary(op, v, r)
            }
            return v
        }
        mutating func term() -> Node? {
            guard var v = unary() else { return nil }
            while let op = peek {
                if op == "*" || op == "/" {
                    i += 1
                    guard let r = unary() else { return nil }
                    v = .binary(op, v, r)
                } else if op == "(" || op == "√" || op == "π" || op.isNumber || variables.contains(op) {
                    guard let r = power() else { return nil }
                    v = .binary("*", v, r)
                } else { break }
            }
            return v
        }
        mutating func unary() -> Node? {
            if peek == "-" { i += 1; return unary().map { .negate($0) } }
            if peek == "+" { i += 1; return unary() }
            return power()
        }
        mutating func power() -> Node? {
            guard let b = primary() else { return nil }
            guard peek == "^" else { return b }
            i += 1
            guard let e = unary() else { return nil }
            return .binary("^", b, e)
        }
        mutating func primary() -> Node? {
            guard let ch = peek else { return nil }
            if ch == "(" {
                i += 1
                guard let v = expression(), peek == ")" else { return nil }
                i += 1
                return v
            }
            if ch == "√" { i += 1; return power().map { .root($0) } }
            if ch == "π" { i += 1; return .number(.pi) }
            if variables.contains(ch) { i += 1; return .variable(ch) }
            var digits = ""
            while let d = peek, d.isNumber || d == "." { digits.append(d); i += 1 }
            guard let v = Double(digits) else { return nil }
            return .number(v)
        }
    }

    static func node(_ raw: String, variables: Set<Character> = ["x"]) -> Node? {
        var s = superscriptsToPowers(DoitAlgebra.normalize(raw)).replacingOccurrences(of: " ", with: "")
        s = s.replacingOccurrences(of: "[", with: "(").replacingOccurrences(of: "]", with: ")")
        guard !s.isEmpty else { return nil }
        var parser = NodeParser(c: Array(s), variables: variables)
        guard let n = parser.expression(), parser.i == parser.c.count else { return nil }
        return n
    }

    /// 함수 g의 실근 (−2000 ~ 2000에서 부호가 바뀌는 곳 + 이분법). 깔끔한 값으로 맞춘 뒤 다시 확인
    static func numericRoots(_ g: (Double) -> Double?) -> [Double] {
        var roots: [Double] = []
        func add(_ r: Double) {
            var value = r
            if abs(r - r.rounded()) < 1e-6 { value = r.rounded() }
            else {
                for d in 2...100 {
                    let n = r * Double(d)
                    if abs(n - n.rounded()) < 1e-6 * Double(d) { value = n.rounded() / Double(d); break }
                }
            }
            guard let check = g(value), abs(check) < 1e-9 else { return }
            if !roots.contains(where: { abs($0 - value) < 1e-9 }) { roots.append(value) }
        }
        var points: [Double] = []
        var v = -2000.0
        while v <= 2000 { points.append(v); v += abs(v) < 100 ? 0.25 : 5 }
        var previous: (Double, Double)?
        for x in points {
            guard let y = g(x), y.isFinite else { previous = nil; continue }
            if abs(y) < 1e-12 { add(x) }
            if let (px, py) = previous, py * y < 0 {
                var lo = px, hi = x, flo = py
                for _ in 0..<80 {
                    let mid = (lo + hi) / 2
                    guard let fm = g(mid) else { break }
                    if (fm < 0) == (flo < 0) { lo = mid; flo = fm } else { hi = mid }
                }
                add((lo + hi) / 2)
            }
            previous = (x, y)
        }
        return roots.sorted()
    }

    // MARK: - 빈칸 (□)

    /// "3 + □ = 7", "45 ÷ □ = 9", "x² + 6x + □ = (x + 3)²" → □의 값
    static func blank(_ text: String) -> Solved? {
        let t = DoitAlgebra.normalize(text)
        let allowed = Set("0123456789.+-*/^()=:□x√ ")
        var runs: [String] = [], current = ""
        for ch in t {
            if allowed.contains(ch) { current.append(ch) } else { runs.append(current); current = "" }
        }
        runs.append(current)
        let candidates = runs.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.contains("□") && $0.contains("=") }
        guard candidates.count == 1, let run = candidates.first, run.filter({ $0 == "□" }).count == 1 else { return nil }
        if run.contains(":") { return proportion(run, unknown: "□") }
        let sides = run.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard sides.count == 2, sides.allSatisfy({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return nil }
        let shown = pretty(run)
        var steps = [SolutionStep(hint: "□를 모르는 수로 놓고 식을 보면", work: shown)]
        var value: Double?
        if run.contains("x") {
            // 항등식: x에 대해 늘 성립하도록
            guard let v = identityBlank(sides[0], sides[1]) else { return nil }
            steps.append(SolutionStep(hint: "양변을 전개해서 x에 대한 항등식이 되게 (같은 차수의 계수끼리 같게) 하면", work: "□ = \(f(v))"))
            value = v
        } else {
            let left = sides[0].replacingOccurrences(of: "□", with: "x"), right = sides[1].replacingOccurrences(of: "□", with: "x")
            if let l = DoitMath.polynomial(left), let r = DoitMath.polynomial(right) {
                let diff = l - r
                guard diff.degree == 1 else { return nil }
                value = -diff[0] / diff[1]
                steps.append(SolutionStep(hint: "덧셈과 뺄셈, 곱셈과 나눗셈의 관계를 이용해 □만 남기면", work: "□ = \(f(value!))"))
            } else if let ln = node(left), let rn = node(right) {
                let roots = numericRoots { x in
                    guard let a = ln.eval(["x": x]), let b = rn.eval(["x": x]) else { return nil }
                    return a - b
                }
                guard roots.count == 1 else { return nil }
                value = roots[0]
                steps.append(SolutionStep(hint: "나눗셈과 곱셈의 관계 (A ÷ □ = B 이면 □ = A ÷ B)를 이용하면", work: "□ = \(f(roots[0]))"))
            }
        }
        guard let v = value, v.isFinite else { return nil }
        let filled = shown.replacingOccurrences(of: "□", with: v < 0 ? "(\(f(v)))" : f(v))
        steps.append(SolutionStep(hint: "□에 넣어 확인하면", work: filled))
        return Solved(kind: run.contains("x") ? .expression : .linear, topic: "□ 안에 알맞은 수",
                      concept: run.contains("x") ? "양변이 x에 대한 항등식이 되려면 같은 차수 항의 계수가 서로 같아야 해요."
                                                 : "□를 모르는 수 x로 놓고 방정식처럼 풀어요. 덧셈↔뺄셈, 곱셈↔나눗셈은 서로 거꾸로 하는 계산이에요.",
                      steps: steps, answer: "□ = \(f(v))")
    }

    /// A(x, □) = B(x, □)가 x에 대한 항등식이 되는 □
    private static func identityBlank(_ left: String, _ right: String) -> Double? {
        guard let l = DoitAlgebra.parse(left.replacingOccurrences(of: "□", with: "z")),
              let r = DoitAlgebra.parse(right.replacingOccurrences(of: "□", with: "z")) else { return nil }
        let e = l - r
        guard e.variables.allSatisfy({ $0 == "x" || $0 == "z" }), e.variables.contains("z") else { return nil }
        guard let groups = zCoefficients(e) else { return nil }
        let nonConstant = groups.filter { $0.degree >= 1 }.sorted { $0.degree < $1.degree }
        guard let first = nonConstant.first else { return nil }
        let candidates = DoitAlgebra.realRoots(first).map(\.value)
        let good = candidates.filter { z in groups.allSatisfy { abs(DoitMath.value($0, at: z)) < 1e-9 } }
        return good.count == 1 ? good[0] : nil
    }

    /// x에 대한 다항식의 계수(각각 z에 대한 다항식)들. y가 있으면 nil
    static func zCoefficients(_ e: DoitAlgebra.MPoly) -> [Poly]? {
        var groups = Array(repeating: Poly(), count: Poly.size)
        for (mono, value) in e.cleaned.t {
            guard mono.y == 0, mono.x < Poly.size, mono.z < Poly.size else { return nil }
            groups[mono.x].c[mono.z] += value
        }
        return groups
    }

    private static func pretty(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "*", with: " × ").replacingOccurrences(of: "-", with: " − ")
        out = out.replacingOccurrences(of: "^2", with: "²").replacingOccurrences(of: "^3", with: "³")
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - 비례식

    /// "3 : 4 = □ : 20", "2 : 5 = 6 : x" → 외항의 곱 = 내항의 곱
    static func proportion(_ text: String, unknown: String? = nil) -> Solved? {
        let t = DoitAlgebra.normalize(text)
        guard t.contains(":"), t.contains("=") else { return nil }
        let allowed = Set("0123456789.+-*/^()=:□x ")
        var best = "", current = ""
        func commit() {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(":") && trimmed.contains("=") && trimmed.count > best.count { best = trimmed }
            current = ""
        }
        for ch in t { if allowed.contains(ch) { current.append(ch) } else { commit() } }
        commit()
        let sides = best.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard sides.count == 2 else { return nil }
        let left = sides[0].split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        let right = sides[1].split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard left.count == 2, right.count == 2 else { return nil }
        let symbol = unknown ?? (best.contains("□") ? "□" : "x")
        let parts = (left + right).map { $0.replacingOccurrences(of: "□", with: "x") }
        let polys = parts.compactMap { DoitMath.polynomial($0) }
        guard polys.count == 4, let outer = polys[0] * polys[3], let inner = polys[1] * polys[2] else { return nil }
        let e = outer - inner
        guard e.degree == 1 else { return nil }
        let v = -e[0] / e[1]
        // 0으로 된 항이 생기면 비례식이 아님
        guard polys.allSatisfy({ abs(DoitMath.value($0, at: v)) > 1e-12 }) else { return nil }
        let names = (left + right).map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "-", with: "−") }
        let filled = names.map { $0.replacingOccurrences(of: symbol, with: f(v)) }
        let steps = [
            SolutionStep(hint: "비례식에서 외항의 곱과 내항의 곱은 같아요", work: "\(names[0]) × \(names[3]) = \(names[1]) × \(names[2])"),
            SolutionStep(hint: "\(symbol)에 대해 풀면", work: "\(symbol) = \(f(v))"),
            SolutionStep(hint: "확인: 외항의 곱과 내항의 곱", work: "\(filled[0]) : \(filled[1]) = \(filled[2]) : \(filled[3])")
        ]
        return Solved(kind: .linear, topic: "비례식", concept: "a : b = c : d 이면 ad = bc (외항의 곱 = 내항의 곱)", steps: steps, answer: "\(symbol) = \(f(v))")
    }

    // MARK: - 객관식 보기

    static let circled: [Character] = ["①", "②", "③", "④", "⑤"]

    /// 문제와 보기 나누기: "… 의 값은? ① 1 ② 2 ③ 3" → ("… 의 값은?", [(①, "1"), …])
    static func splitChoices(_ raw: String) -> (body: String, choices: [(Character, String)])? {
        guard let first = raw.firstIndex(where: { circled.contains($0) }), raw.contains("②") else { return nil }
        let body = String(raw[..<first])
        var choices: [(Character, String)] = []
        var mark: Character?
        var current = ""
        for ch in raw[first...] {
            if circled.contains(ch) {
                if let m = mark { choices.append((m, current.trimmingCharacters(in: .whitespacesAndNewlines))) }
                mark = ch
                current = ""
            } else {
                current.append(ch)
            }
        }
        if let m = mark { choices.append((m, current.trimmingCharacters(in: .whitespacesAndNewlines))) }
        guard choices.count >= 2, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              choices.allSatisfy({ !$0.1.isEmpty }) else { return nil }
        return (body, choices)
    }

    /// 답과 값이 같은 보기를 찾아 "④ 12"처럼. 딱 하나의 보기와 맞지 않으면 (문제를 잘못 읽었을 수 있어서) nil
    static func pickChoice(_ solved: Solved, from choices: [(Character, String)]) -> Solved? {
        let answers = answerForms(solved.answer)
        var hits: [Int] = []
        for (index, choice) in choices.enumerated() where answers.contains(where: { sameValue(choice.1, $0) == true }) {
            hits.append(index)
        }
        if hits.count == 1 {
            let (mark, text) = choices[hits[0]]
            var out = solved
            out.steps.append(SolutionStep(hint: "보기에서 같은 값을 찾으면", work: "\(solved.answer) → \(mark) \(text)"))
            out.answer = "\(mark) \(text)"
            return out
        }
        return nil
    }

    /// 답 글자에서 비교할 값들: 전체, "x = 3"의 3, "최대공약수 12"의 12
    static func answerForms(_ answer: String) -> [String] {
        var a = answer.components(separatedBy: "\n").first ?? answer
        a = a.replacingOccurrences(of: #"\s*\((?:≈|=)[^)]*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        var forms = [a]
        if let m = match(a, #"^[^=]{1,10}=\s*([^=]+)$"#), !m[1].contains("또는") { forms.append(m[1].trimmingCharacters(in: .whitespaces)) }
        if let m = match(a, #"^(?=[^\s]*[가-힣])[가-힣0-9()a-zA-Z]+\s+([^가-힣]+)$"#) { forms.append(m[1].trimmingCharacters(in: .whitespaces)) }
        // "x = 1에서 극댓값 5", "첫째항부터 제10항까지의 합 100" → 5, 100 (이름표에 쉼표가 없을 때만: 여러 값을 붙인 답은 아님)
        if let m = match(a, #"^[^,]*[가-힣]\s+([^가-힣,]+)$"#), !m[0].contains("→") {
            let value = m[1].trimmingCharacters(in: .whitespaces)
            if !forms.contains(value) { forms.append(value) }
        }
        return forms
    }

    /// 두 답이 같은 값인지 (true / false / 비교할 수 없으면 nil)
    static func sameValue(_ a: String, _ b: String) -> Bool? {
        func clean(_ s: String) -> String {
            var t = DoitAlgebra.normalize(s).replacingOccurrences(of: " ", with: "")
            t = t.replacingOccurrences(of: #"(cm\^?[23]?|km|mm|m\^?[23]?|kg|g|개|명|원|°|도|마리|가지|권|장|번|살|세|시간|분|초|%|L|mL|배|년후|년전|cm²|cm³|항)$"#, with: "", options: .regularExpression)
            return t
        }
        let x = clean(a).replacingOccurrences(of: #"^제(?=\d)"#, with: "", options: .regularExpression)
        let y = clean(b).replacingOccurrences(of: #"^제(?=\d)"#, with: "", options: .regularExpression)
        guard !x.isEmpty, !y.isEmpty else { return nil }
        if x == y { return true }
        // 말로 된 보기 ("서로 다른 두 허근"): 답 속에 그 말이 있는지
        if x.range(of: "[가-힣]", options: .regularExpression) != nil, x.count >= 2 { return y.contains(x) }
        // 순서쌍
        if x.hasPrefix("("), y.hasPrefix("("), x.contains(","), y.contains(",") {
            let px = x.dropFirst().dropLast().split(separator: ",").map { node(String($0))?.eval([:]) }
            let py = y.dropFirst().dropLast().split(separator: ",").map { node(String($0))?.eval([:]) }
            guard px.count == py.count, !px.contains(where: { $0 == nil }), !py.contains(where: { $0 == nil }) else { return nil }
            return zip(px, py).allSatisfy { abs(($0 ?? 0) - ($1 ?? 0)) < 1e-9 }
        }
        // 해 모음 ("x = 2 또는 x = 3" = "2, 3")
        if x.contains("또는") || y.contains("또는") || (x.contains(",") && y.contains(",")) {
            func values(_ s: String) -> [Double]? {
                let parts = s.replacingOccurrences(of: "또는", with: ",").split(separator: ",").map { String($0).replacingOccurrences(of: #"^[a-z]="#, with: "", options: .regularExpression) }
                let v = parts.map { node($0)?.eval([:]) }
                return v.contains(where: { $0 == nil }) ? nil : v.compactMap { $0 }.sorted()
            }
            guard let vx = values(x), let vy = values(y) else { return nil }
            return vx.count == vy.count && zip(vx, vy).allSatisfy { abs($0 - $1) < 1e-9 }
        }
        if let vx = node(x)?.eval([:]), let vy = node(y)?.eval([:]) { return abs(vx - vy) < 1e-9 * max(1, abs(vx)) }
        // x가 들어 있는 식: 여러 값을 넣어 비교
        if x.contains("x") || y.contains("x"), let nx = node(x.replacingOccurrences(of: "y=", with: "")), let ny = node(y.replacingOccurrences(of: "y=", with: "")) {
            var compared = 0
            for v in [-2.3, -0.7, 0.4, 1.9, 3.1] {
                guard let p = nx.eval(["x": v]), let q = ny.eval(["x": v]) else { continue }
                compared += 1
                if abs(p - q) > 1e-9 * max(1, abs(p)) { return false }
            }
            return compared >= 3 ? true : nil
        }
        return nil
    }

    // MARK: - 미지의 상수 (a, b, k, m …) 구하기

    /// "상수 k", "양수 a의 값", "실수 k의 값의 범위" 에서 상수 이름
    static func parameterLetter(_ t: String) -> Character? {
        var letters = Set<Character>()
        for m in matches(t, #"(?:상수|실수|정수|자연수|양수|음수|유리수)\s*([abckmpq])(?![a-z])"#) { if let c = m[1].first { letters.insert(c) } }
        for m in matches(t, #"(?<![a-z])([abckmpq])\s*의\s*(?:값|최댓값|최솟값)"#) { if let c = m[1].first { letters.insert(c) } }
        guard letters.count == 1, let letter = letters.first else { return nil }
        // 수식 속에서 쓰여야 함 (2a, ax, + k, k = …)
        let pattern = "(?:[0-9x)^*/+\\-=]\\s*\(letter)|\(letter)\\s*[x(+\\-*/^=])"
        guard t.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return letter
    }

    /// 문제에 구해야 할 상수(상수 a, k의 값)가 있는지 — 못 풀면 다른 풀이로 넘기지 않으려고 (a를 지운 식은 엉뚱한 답)
    static func mentionsConstant(_ t: String) -> Bool {
        t.range(of: #"(?:상수|실수|정수|자연수|양수|음수|유리수)\s*[abckmpq](?![a-z])"#, options: .regularExpression) != nil
            && t.range(of: #"[0-9x)^*/+\-=]\s*[abckmpq](?![a-z])|(?<![a-z])[abckmpq]\s*[x(+\-*/^=]"#, options: .regularExpression) != nil
    }

    /// 수식 속 상수 이름을 z로 (sin, tan 같은 말에 그 글자가 섞여 있으면 nil)
    static func replaceParameter(_ t: String, _ letter: Character) -> String? {
        var out = ""
        var word = ""
        func flush() -> Bool {
            if word.contains(letter) {
                let others = word.filter { $0 != letter && $0 != "x" && $0 != "y" }
                guard others.isEmpty || (others == "f" && word.count <= 1) else { return false }
                out += String(word.map { $0 == letter ? "z" : $0 })
            } else {
                out += word
            }
            word = ""
            return true
        }
        for ch in t {
            if ch.isASCII && ch.isLetter { word.append(ch) } else { guard flush() else { return nil }; out.append(ch) }
        }
        guard flush() else { return nil }
        return out
    }

    /// 다항식에서 z를 상수 이름으로 보여주기
    private static func describe(_ p: Poly, as letter: Character) -> String {
        DoitMath.describe(p).replacingOccurrences(of: "x", with: String(letter))
    }

    static func unknownConstant(_ text: String) -> Solved? {
        let t = DoitAlgebra.normalize(text)
        guard let letter = parameterLetter(t), let s = replaceParameter(t, letter) else { return nil }
        let name = String(letter)
        // z가 들어 있는 수식 중 가장 긴 것
        let allowed = Set("0123456789.+-*/^=()xyz ")
        var best = "", current = ""
        func commit() {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("z"), trimmed.count > best.count { best = trimmed }
            current = ""
        }
        for ch in s { if allowed.contains(ch) { current.append(ch) } else { commit() } }
        commit()
        guard !best.isEmpty else { return nil }
        // "(x) = …" (f(x) = …의 f가 빠진 것) → y = …
        var formula = best
        if formula.hasPrefix("(x)") { formula = "y" + formula.dropFirst(3) }
        let sides = formula.split(separator: "=", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard sides.count <= 2, sides.allSatisfy({ !$0.isEmpty }) else { return nil }
        var condition: Poly?
        var steps: [SolutionStep] = []
        var kind: MathSolver.Kind = .linear
        var inequality: String?
        var leading: Poly?

        // 식 E(x, y, z) = 0 꼴로
        var expression: DoitAlgebra.MPoly?
        if sides.count == 2, let l = DoitAlgebra.parse(sides[0]), let r = DoitAlgebra.parse(sides[1]) { expression = l - r }
        else if sides.count == 1 { expression = DoitAlgebra.parse(sides[0]) }
        guard let e = expression else { return nil }
        let isFunction = sides.count == 2 && sides[0] == "y"
        // 함수 부분 F(x, z) (y = F)
        let function: DoitAlgebra.MPoly? = isFunction ? DoitAlgebra.parse(sides[1]) : (sides.count == 1 ? e : nil)

        let pts = DoitMathTopics.points(in: t)
        if has(t, ["지나", "지날", "지난", "위에 있", "위의 점"]), pts.count == 1, isFunction {
            // 점을 넣으면
            let p = pts[0]
            guard let groups = zCoefficients(substitute(e, y: p.y)) else { return nil }
            condition = evaluate(groups, at: p.x)
            steps.append(SolutionStep(hint: "그래프가 점 \(p.label)을 지나므로 x = \(f(p.x)), y = \(f(p.y))를 대입하면", work: "\(describe(condition!, as: letter)) = 0"))
            kind = .coordinate
        } else if let fx = function, let groups = zCoefficients(fx), has(t, ["나머지", "나누어떨어", "인수"]) {
            guard let root = divisorValue(t) else { return nil }
            var remainder = 0.0
            if let m = match(t, #"나머지(?:가|는)\s*(-?\d+(?:\.\d+)?)"#), let v = Double(m[1]) { remainder = v }
            else if !has(t, ["나누어떨어", "인수"]) { return nil }
            var value = evaluate(groups, at: root)
            value.c[0] -= remainder
            condition = value
            steps.append(SolutionStep(hint: "나머지정리: x − (\(f(root)))로 나눈 나머지는 f(\(f(root)))", work: "f(\(f(root))) = \(f(remainder))"))
            steps.append(SolutionStep(hint: "x = \(f(root))을 대입해서 정리하면", work: "\(describe(value, as: letter)) = 0"))
            kind = .remainder
        } else if let fx = function, let groups = zCoefficients(fx), let (x0, v0) = derivativeCondition(t) {
            // 미분계수 조건: f'(a) = v
            var derived = Array(repeating: Poly(), count: Poly.size)
            for k in 1..<Poly.size { derived[k - 1] = groups[k] * Poly.constant(Double(k)) ?? Poly() }
            var value = evaluate(derived, at: x0)
            value.c[0] -= v0
            condition = value
            steps.append(SolutionStep(hint: "f'(x)를 구해서 x = \(f(x0))을 넣으면 \(f(v0))", work: "\(describe(value, as: letter)) = 0"))
            kind = .derivative
        } else if let m = match(t, #"f\((-?\d+(?:\.\d+)?)\)\s*=\s*(-?\d+(?:\.\d+)?)"#), let fx = function ?? DoitMathExact.functionAfterF(s),
                  let x0 = Double(m[1]), let v0 = Double(m[2]), let groups = zCoefficients(fx) {
            var value = evaluate(groups, at: x0)
            value.c[0] -= v0
            condition = value
            steps.append(SolutionStep(hint: "f(\(f(x0))) = \(f(v0))이므로 x = \(f(x0))을 대입하면", work: "\(describe(value, as: letter)) = 0"))
            kind = .function
        } else if let groups = zCoefficients(isFunction ? (function ?? e) : e), groups.dropFirst(3).allSatisfy({ $0.degree < 0 }), groups[2].degree >= 0 {
            // 이차식 Ax² + Bx + C (A, B, C는 상수 z의 식)
            let a = groups[2], b = groups[1], c = groups[0]
            leading = a
            guard let bb = b * b, let ac = a * c, let fourAC = ac * Poly.constant(4) else { return nil }
            let discriminant = bb - fourAC
            if isFunction, let m = match(t, #"(최솟값|최댓값)(?:이|은)\s*(-?\d+(?:\.\d+)?)"#), let target = Double(m[2]) {
                // 꼭짓점의 y좌표: (4AC − B²)/4A = m  →  4AC − B² − 4A·m = 0
                guard let fourA = a * Poly.constant(4), let shifted = fourA * Poly.constant(target) else { return nil }
                condition = fourAC - bb - shifted
                steps.append(SolutionStep(hint: "y = ax² + bx + c 의 \(m[1])은 꼭짓점의 y좌표 (4ac − b²)/4a", work: "(4ac − b²)/4a = \(f(target))"))
                steps.append(SolutionStep(hint: "정리하면", work: "\(describe(condition!, as: letter)) = 0"))
                kind = .vertex
                inequality = m[1] == "최솟값" ? "min" : "max"
            } else if has(t, ["중근", "완전제곱식"]) {
                condition = discriminant
                steps.append(SolutionStep(hint: has(t, ["완전제곱식"]) ? "완전제곱식이 되려면 판별식 D = b² − 4ac = 0" : "중근을 가지려면 판별식 D = b² − 4ac = 0",
                                          work: "D = \(describe(discriminant, as: letter)) = 0"))
                kind = .quadraticEquation
            } else if has(t, ["서로 다른 두 실근"]) {
                inequality = ">"; condition = discriminant
            } else if has(t, ["허근", "실근을 갖지 않", "실근을 가지지 않", "실근이 없"]) {
                inequality = "<"; condition = discriminant
            } else if has(t, ["실근을 가질", "실근을 갖도록", "실근을 가지도록", "실근을 갖는"]) {
                inequality = "≥"; condition = discriminant
            } else if let m = match(t, #"(?:한\s*근이|한\s*근은|근이|해가|해는)\s*(?:x\s*=\s*)?(-?\d+(?:\.\d+)?)"#) ?? match(t, #"x\s*=\s*(-?\d+(?:\.\d+)?)\s*(?:을|를|이|가)?\s*(?:근|해)"#),
                      let r = Double(m[1]) {
                condition = evaluate(groups, at: r)
                steps.append(SolutionStep(hint: "x = \(f(r))이 근이므로 대입하면", work: "\(describe(condition!, as: letter)) = 0"))
                kind = .quadraticEquation
            } else if let m = match(t, #"두\s*근의\s*(합|곱)(?:이|은)\s*(-?\d+(?:\.\d+)?)"#), let v = Double(m[2]) {
                // 합 −B/A = v → B + vA = 0, 곱 C/A = v → C − vA = 0
                guard let va = a * Poly.constant(v) else { return nil }
                condition = m[1] == "합" ? b + va : c - va
                steps.append(SolutionStep(hint: m[1] == "합" ? "근과 계수의 관계: 두 근의 합 = −b/a" : "근과 계수의 관계: 두 근의 곱 = c/a", work: "\(describe(condition!, as: letter)) = 0"))
                kind = .rootRelation
            }
            if let op = inequality, op != "min" && op != "max" {
                // 판별식 부등식: x²의 계수에 상수가 없을 때만
                guard a.degree == 0, let d = condition, d.degree >= 1 else { return nil }
                let solved = DoitAlgebra.solveSign(d, op: op)
                let range = DoitAlgebra.intervalText(solved.set).replacingOccurrences(of: "x", with: name)
                steps.append(SolutionStep(hint: "판별식 D = b² − 4ac 가 \(op == ">" ? "0보다 커야" : op == "<" ? "0보다 작아야" : "0 이상이어야") 해요", work: "D = \(describe(d, as: letter)) \(op) 0"))
                steps.append(SolutionStep(hint: "\(name)에 대해 풀면", work: range))
                return Solved(kind: .quadraticEquation, topic: "판별식과 근의 조건",
                              concept: "ax² + bx + c = 0 에서 D = b² − 4ac > 0 이면 서로 다른 두 실근, D = 0 이면 중근, D < 0 이면 서로 다른 두 허근이에요.",
                              steps: steps, answer: range)
            }
        }
        guard let z = condition, z.degree >= 1, z.degree <= 4 else { return nil }
        var roots = DoitAlgebra.realRoots(z)
        // 이차방정식이 되려면 x²의 계수 ≠ 0, 최솟값이면 아래로 볼록(a > 0)
        if let a = leading {
            roots = roots.filter { abs(DoitMath.value(a, at: $0.value)) > 1e-12 }
            if inequality == "min" { roots = roots.filter { DoitMath.value(a, at: $0.value) > 0 } }
            if inequality == "max" { roots = roots.filter { DoitMath.value(a, at: $0.value) < 0 } }
        }
        if has(t, ["양수 \(name)", "양의 상수 \(name)", "양의 실수 \(name)", "자연수 \(name)", "\(name) > 0", "\(name)>0"]) { roots = roots.filter { $0.value > 1e-12 } }
        if has(t, ["음수 \(name)", "음의 상수 \(name)", "음의 실수 \(name)", "\(name) < 0", "\(name)<0"]) { roots = roots.filter { $0.value < -1e-12 } }
        if has(t, ["정수 \(name)", "자연수 \(name)"]) { roots = roots.filter { abs($0.value - $0.value.rounded()) < 1e-9 } }
        guard !roots.isEmpty, roots.count <= 2 else { return nil }
        let answer = roots.map { "\(name) = \($0.label)" }.joined(separator: " 또는 ")
        steps.append(SolutionStep(hint: "\(name)에 대해 풀면", work: answer))
        return Solved(kind: kind, topic: "조건을 만족하는 상수 구하기",
                      concept: "주어진 조건(지나는 점, 나머지정리, 판별식, 꼭짓점)을 상수에 대한 방정식으로 바꿔서 풀어요.",
                      steps: steps, answer: answer)
    }

    /// "f'(1) = 5", "x = 1에서의 미분계수가 5", "x = 1인 점에서의 접선의 기울기가 5" → (1, 5)
    private static func derivativeCondition(_ t: String) -> (Double, Double)? {
        if let m = match(t, #"f'\s*\((-?\d+(?:\.\d+)?)\)\s*=\s*(-?\d+(?:\.\d+)?)"#), let a = Double(m[1]), let v = Double(m[2]) { return (a, v) }
        if let m = match(t, #"x\s*=\s*(-?\d+(?:\.\d+)?)\s*(?:에서의|인\s*점에서의|에서)\s*(?:미분계수|접선의\s*기울기)(?:가|는|이)\s*(-?\d+(?:\.\d+)?)"#),
           let a = Double(m[1]), let v = Double(m[2]) { return (a, v) }
        return nil
    }

    /// "f(x) = …" 부분만 (z 포함)
    static func functionAfterF(_ s: String) -> DoitAlgebra.MPoly? {
        guard let range = s.range(of: #"f\(x\)\s*="#, options: .regularExpression) else { return nil }
        var rest = String(s[range.upperBound...])
        if let cut = rest.firstIndex(where: { $0 == "," || $0 == "\n" || ("가"..."힣").contains($0) }) { rest = String(rest[..<cut]) }
        return DoitAlgebra.parse(rest)
    }

    /// E(x, y, z)에 y 값 넣기
    private static func substitute(_ e: DoitAlgebra.MPoly, y: Double) -> DoitAlgebra.MPoly {
        var out = DoitAlgebra.MPoly()
        for (mono, value) in e.cleaned.t {
            let key = DoitAlgebra.Mono(x: mono.x, y: 0, z: mono.z)
            out.t[key, default: 0] += value * pow(y, Double(mono.y))
        }
        return out.cleaned
    }

    /// 계수 묶음(z의 식)에 x 값을 넣으면 z에 대한 다항식
    private static func evaluate(_ groups: [Poly], at x: Double) -> Poly {
        var out = Poly()
        for (power, g) in groups.enumerated() where g.degree >= 0 {
            out = out + (g * Poly.constant(pow(x, Double(power))) ?? Poly())
        }
        return out
    }

    /// "x − 1로 나눈", "2x + 1로 나누어", "x + 2를 인수로" → 그 식이 0이 되는 x
    static func divisorValue(_ t: String) -> Double? {
        guard let m = match(t, #"(\d*)\s*x\s*([-+])\s*(\d+(?:\.\d+)?)\s*(?:으로|로|을|를|이|가)\s*(?:나[누눈눌]|인수)"#),
              let b = Double(m[3]) else { return nil }
        let a = Double(m[1]) ?? 1
        guard a != 0 else { return nil }
        return (m[2] == "-" ? b : -b) / a
    }

    // MARK: - 다항식의 나눗셈

    static func polyDivide(_ a: Poly, by b: Poly) -> (quotient: Poly, remainder: Poly)? {
        let db = b.degree
        guard db >= 0 else { return nil }
        var r = a, q = Poly()
        var guardCount = 0
        while r.degree >= db && guardCount < 20 {
            guardCount += 1
            let k = r.degree - db
            let coefficient = r[r.degree] / b[db]
            q.c[k] += coefficient
            for i in 0...db { r.c[i + k] -= coefficient * b[i] }
            r.c[db + k] = 0
            for i in 0..<Poly.size where abs(r.c[i]) < 1e-10 { r.c[i] = 0 }
        }
        return (q, r)
    }

    /// "x³ + 2x² − x + 3을 x + 2로 나눈 몫과 나머지", "(x³ − 3x + 5) ÷ (x − 2)"
    static func division(_ text: String) -> Solved? {
        let t = DoitAlgebra.normalize(text)
        var dividend: Poly?, divisor: Poly?
        if let m = match(t, #"\(([^()]+)\)\s*/\s*\(([^()]+)\)"#) {
            dividend = DoitMath.polynomial(m[1]); divisor = DoitMath.polynomial(m[2])
        } else if let m = match(t, #"([^을를]*)(?:을|를)\s*([^을를]+?)\s*(?:으로|로)\s*나[누눈눌]"#) {
            dividend = MathSolver.function(in: m[1]) ?? DoitMath.polynomial(DoitMath.extractExpression(m[1]))
            divisor = DoitMath.polynomial(DoitMath.extractExpression(m[2]))
        }
        guard let a = dividend, let b = divisor, b.degree >= 1, a.degree >= b.degree,
              let (q, r) = polyDivide(a, by: b), let check = b * q else { return nil }
        // 검산: A = BQ + R
        let back = check + r
        guard (0..<Poly.size).allSatisfy({ abs(back[$0] - a[$0]) < 1e-9 }) else { return nil }
        let qText = DoitMath.describe(q), rText = DoitMath.describe(r)
        let steps = [
            SolutionStep(hint: "나누는 식", work: "\(DoitMath.describe(a)) ÷ (\(DoitMath.describe(b)))"),
            SolutionStep(hint: b.degree == 1 ? "조립제법(또는 직접 나누기)으로 최고차항부터 나누면" : "최고차항부터 차례로 나누면", work: "몫 \(qText), 나머지 \(rText)"),
            SolutionStep(hint: "검산: A = B × Q + R", work: "\(DoitMath.describe(a)) = (\(DoitMath.describe(b)))(\(qText)) + \(rText.hasPrefix("−") ? "(\(rText))" : rText)")
        ]
        let asksQuotient = has(t, ["몫"])
        return Solved(kind: .remainder, topic: "다항식의 나눗셈",
                      concept: "A를 B로 나눈 몫을 Q, 나머지를 R이라 하면 A = BQ + R (R의 차수 < B의 차수). 일차식으로 나눌 때는 조립제법이 편해요.",
                      steps: steps, answer: asksQuotient ? "몫 \(qText), 나머지 \(rText)" : "나머지 \(rText)")
    }

    // MARK: - 함수의 극한

    /// lim x→2 (x² − 4)/(x − 2), lim x→∞ (2x² + 1)/(x² − 3)
    static func limit(_ text: String) -> Solved? {
        let t = DoitAlgebra.normalize(text)
        guard has(t, ["lim", "극한"]),
              let m = match(t, #"x\s*(?:→|->|➝|⟶)\s*(-?\s*∞|-?\d+(?:\.\d+)?|무한대)"#) else { return nil }
        let target = m[1].replacingOccurrences(of: " ", with: "")
        var rest = t.replacingOccurrences(of: m[0], with: " ")
        for word in ["lim", "_", "{", "}"] { rest = rest.replacingOccurrences(of: word, with: " ") }
        let expression = DoitAlgebra.extract(rest).replacingOccurrences(of: " ", with: "")
        guard !expression.isEmpty, !expression.contains("=") else { return nil }
        // 맨 바깥의 / 로 분자·분모 나누기
        var depth = 0, split: String.Index?
        for index in expression.indices {
            let ch = expression[index]
            if ch == "(" { depth += 1 } else if ch == ")" { depth -= 1 } else if ch == "/" && depth == 0 { split = index }
        }
        var numerator: Poly?, denominator: Poly?
        if let s = split {
            numerator = DoitMath.polynomial(String(expression[..<s]))
            denominator = DoitMath.polynomial(String(expression[expression.index(after: s)...]))
        } else {
            numerator = DoitMath.polynomial(expression); denominator = .constant(1)
        }
        guard var num = numerator, var den = denominator, den.degree >= 0 else { return nil }
        let concept = "x → a 에서 0/0 꼴이면 분자·분모를 인수분해해서 (x − a)를 약분하고, x → ∞ 이면 최고차항으로 나눠요."
        var steps = [SolutionStep(hint: "극한을 구할 식", work: "(\(DoitMath.describe(num))) / (\(DoitMath.describe(den)))")]
        if target.contains("∞") || target == "무한대" {
            let negative = target.hasPrefix("-")
            let dn = num.degree, dd = den.degree
            steps.append(SolutionStep(hint: "분자·분모의 최고차항을 비교하면", work: "분자 \(dn)차, 분모 \(dd)차"))
            if dn < dd { return Solved(kind: .function, topic: "함수의 극한 (x → ∞)", concept: concept, steps: steps, answer: "0") }
            if dn == dd {
                let v = num[dn] / den[dd]
                steps.append(SolutionStep(hint: "최고차항의 계수의 비", work: "\(f(num[dn])) / \(f(den[dd])) = \(f(v))"))
                return Solved(kind: .function, topic: "함수의 극한 (x → ∞)", concept: concept, steps: steps, answer: f(v))
            }
            let sign = (num[dn] / den[dd]) * ((negative && (dn - dd) % 2 == 1) ? -1 : 1)
            return Solved(kind: .function, topic: "함수의 극한 (x → ∞)", concept: concept, steps: steps, answer: sign > 0 ? "∞ (양의 무한대로 발산)" : "−∞ (음의 무한대로 발산)")
        }
        guard let a = Double(target) else { return nil }
        let factor = Poly.x - Poly.constant(a)
        for _ in 0..<6 {
            let dv = DoitMath.value(den, at: a), nv = DoitMath.value(num, at: a)
            if abs(dv) > 1e-12 {
                steps.append(SolutionStep(hint: "x = \(f(a))을 넣으면", work: "\(f(nv)) / \(f(dv)) = \(f(nv / dv))"))
                return Solved(kind: .function, topic: "함수의 극한", concept: concept, steps: steps, answer: f(nv / dv))
            }
            guard abs(nv) < 1e-12 else {
                steps.append(SolutionStep(hint: "x = \(f(a))에서 분모만 0", work: "(0이 아닌 수)/0 꼴"))
                return Solved(kind: .function, topic: "함수의 극한", concept: concept, steps: steps, answer: "극한값이 없어요 (발산)")
            }
            guard let (qn, rn) = polyDivide(num, by: factor), let (qd, rd) = polyDivide(den, by: factor),
                  rn.degree < 0 || abs(rn[0]) < 1e-9, rd.degree < 0 || abs(rd[0]) < 1e-9 else { return nil }
            steps.append(SolutionStep(hint: "0/0 꼴이라 분자·분모를 (x − \(f(a)))로 약분하면", work: "(\(DoitMath.describe(qn))) / (\(DoitMath.describe(qd)))"))
            num = qn; den = qd
        }
        return nil
    }

    // MARK: - 두 근 α, β로 된 식의 값

    /// ax² + bx + c = 0 의 두 근 α, β 에 대한 대칭식의 값 (α + β + αβ, α³ + β³, β/α + α/β …)
    static func rootExpression(_ poly: Poly, asks text: String) -> (value: Double, expression: String)? {
        let t = DoitAlgebra.normalize(text)
        let allowed = Set("0123456789.+-*/^()αβ ")
        var runs: [String] = [], current = ""
        for ch in t {
            if allowed.contains(ch) { current.append(ch) } else { runs.append(current); current = "" }
        }
        runs.append(current)
        // "두 근을 α, β라" 의 α, β 하나씩은 빼고, 식으로 된 것 중 마지막
        let candidates = runs.map { $0.replacingOccurrences(of: " ", with: "") }
            .filter { ($0.contains("α") || $0.contains("β")) && $0.count >= 2 }
        guard let expression = candidates.last else { return nil }
        guard let n = node(expression, variables: ["α", "β"]) else { return nil }
        let a = poly[2], b = poly[1], c = poly[0]
        guard abs(a) > 1e-12 else { return nil }
        typealias C = DoitMathTopics.Complex
        let d = b * b - 4 * a * c
        let r1: C, r2: C
        if d >= 0 {
            r1 = C(re: (-b + d.squareRoot()) / (2 * a), im: 0); r2 = C(re: (-b - d.squareRoot()) / (2 * a), im: 0)
        } else {
            r1 = C(re: -b / (2 * a), im: (-d).squareRoot() / (2 * a)); r2 = C(re: -b / (2 * a), im: -(-d).squareRoot() / (2 * a))
        }
        guard let v1 = n.evalComplex(["α": r1, "β": r2]), let v2 = n.evalComplex(["α": r2, "β": r1]),
              abs(v1.im) < 1e-7, abs(v1.re - v2.re) < 1e-7 * max(1, abs(v1.re)), abs(v2.im) < 1e-7 else { return nil }
        return (v1.re, expression)
    }

    // MARK: - 두 문자 인수분해 (동차식: a² − 4b², x² − 5xy + 6y²)

    static func factorTwoLetters(_ text: String) -> Solved? {
        let t = DoitAlgebra.normalize(text)
        guard has(t, ["인수분해"]) else { return nil }
        let allowed = Set("0123456789+-*/^() abcdmnpqrstuvwxyz")
        var best = "", current = ""
        func commit() {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if trimmed.count > best.count, trimmed.contains(where: { $0.isLetter }) { best = trimmed }
            current = ""
        }
        for ch in t { if allowed.contains(ch) { current.append(ch) } else { commit() } }
        commit()
        var letters: [Character] = []
        for ch in best where ch.isLetter && ch.isASCII && !letters.contains(ch) { letters.append(ch) }
        guard letters.count == 2 else { return nil }
        letters.sort()
        let (u, v) = (letters[0], letters[1])
        let swapped = String(best.map { $0 == u ? "x" : $0 == v ? "y" : ($0 == "x" || $0 == "y" ? "#" : $0) })
        guard !swapped.contains("#"), let e = DoitAlgebra.parse(swapped) else { return nil }
        let degrees = Set(e.cleaned.t.keys.map(\.degree))
        guard degrees.count == 1, let n = degrees.first, n >= 2, n < Poly.size, e.variables.count == 2 else { return nil }
        // y = 1 로 놓은 x의 다항식을 인수분해한 뒤 다시 y를 붙임
        var p = Poly()
        for (mono, value) in e.cleaned.t { p.c[mono.x] += value }
        guard let fac = DoitAlgebra.factor(p), fac.scale == 1, !fac.linear.isEmpty || fac.xPower > 0 || fac.content != 1 || fac.rest.count > 1 else { return nil }
        let yPower = n - p.degree
        func name(_ c: Character) -> String { String(c == "x" ? u : v) }
        var parts: [String] = []
        if fac.xPower > 0 { parts.append(name("x") + DoitMath.superscript(fac.xPower)) }
        if yPower > 0 { parts.append(name("y") + DoitMath.superscript(yPower)) }
        for l in fac.linear {
            let lead = l.q == 1 ? name("x") : "\(l.q)\(name("x"))"
            let tail = l.p == 0 ? "" : (l.p > 0 ? " − " : " + ") + (abs(l.p) == 1 ? "" : "\(abs(l.p))") + name("y")
            parts.append("(\(lead)\(tail))" + DoitMath.superscript(l.power))
        }
        for r in fac.rest {
            var m = DoitAlgebra.MPoly()
            let k = r.count - 1
            for (i, c) in r.enumerated() where c != 0 { m.t[DoitAlgebra.Mono(x: i, y: k - i)] = Double(c) }
            let body = String(DoitAlgebra.describe(m).map { $0 == "x" ? u : $0 == "y" ? v : $0 })
            parts.append("(\(body))")
        }
        let head = fac.content == 1 ? "" : fac.content == -1 ? "−" : String(fac.content)
        let answer = head + parts.joined()
        let original = String(DoitAlgebra.describe(e).map { $0 == "x" ? u : $0 == "y" ? v : $0 })
        return Solved(kind: .factor, topic: "인수분해 (두 문자)",
                      concept: "a² − b² = (a + b)(a − b), a² ± 2ab + b² = (a ± b)², x² + (a + b)xy + aby² = (x + ay)(x + by)",
                      steps: [SolutionStep(hint: "식을 정리하면", work: original),
                              SolutionStep(hint: "\(v)를 상수처럼 보고, 곱해서 마지막 항·더해서 가운데 항의 계수가 되는 두 수를 찾으면", work: answer)],
                      answer: answer)
    }

    // MARK: - 평행이동 · 대칭이동

    /// "y = 2x + 1의 그래프를 y축의 방향으로 3만큼 평행이동한 그래프의 식"
    static func moveGraph(_ text: String) -> (poly: Poly, steps: [SolutionStep])? {
        let t = DoitAlgebra.normalize(text)
        guard has(t, ["평행이동", "대칭이동"]), has(t, ["그래프", "함수"]), let f = MathSolver.function(in: t) else { return nil }
        var g = f
        var steps = [SolutionStep(hint: "처음 함수", work: "y = \(DoitMath.describe(f))")]
        if has(t, ["평행이동"]) {
            var p = 0.0, q = 0.0
            if let m = match(t, #"x\s*축의?\s*방향으로\s*(-?\d+(?:\.\d+)?)\s*만큼"#), let v = Double(m[1]) { p = v }
            if let m = match(t, #"y\s*축의?\s*방향으로\s*(-?\d+(?:\.\d+)?)\s*만큼"#), let v = Double(m[1]) { q = v }
            guard p != 0 || q != 0, let shifted = DoitAlgebra.compose(f, Poly.x - Poly.constant(p)) else { return nil }
            g = shifted + Poly.constant(q)
            steps.append(SolutionStep(hint: "x 대신 x − (\(DoitMath.fraction(p))), y 대신 y − (\(DoitMath.fraction(q)))를 넣으면", work: "y − (\(DoitMath.fraction(q))) = f(x − (\(DoitMath.fraction(p))))"))
        } else if has(t, ["원점에 대하여", "원점에 대해"]) {
            guard let m = DoitAlgebra.compose(f, -Poly.x) else { return nil }
            g = -m
            steps.append(SolutionStep(hint: "원점 대칭: x 대신 −x, y 대신 −y", work: "−y = f(−x)"))
        } else if has(t, ["x축에 대하여", "x축에 대해"]) {
            g = -f
            steps.append(SolutionStep(hint: "x축 대칭: y 대신 −y", work: "−y = f(x)"))
        } else if has(t, ["y축에 대하여", "y축에 대해"]) {
            guard let m = DoitAlgebra.compose(f, -Poly.x) else { return nil }
            g = m
            steps.append(SolutionStep(hint: "y축 대칭: x 대신 −x", work: "y = f(−x)"))
        } else { return nil }
        steps.append(SolutionStep(hint: "정리하면", work: "y = \(DoitMath.describe(g))"))
        return (g, steps)
    }

    /// 점의 평행이동·대칭이동: "점 (2, −3)을 x축의 방향으로 1만큼, y축의 방향으로 4만큼 평행이동한 점"
    static func movePoint(_ text: String) -> Solved? {
        let t = DoitAlgebra.normalize(text)
        let pts = DoitMathTopics.points(in: t)
        guard pts.count == 1, has(t, ["평행이동", "대칭이동"]), !has(t, ["그래프", "y=", "y =", "f(x)", "직선", "원 "]) else { return nil }
        var x = pts[0].x, y = pts[0].y
        var rule = ""
        if has(t, ["평행이동"]) {
            var p = 0.0, q = 0.0
            if let m = match(t, #"x\s*축의?\s*방향으로\s*(-?\d+(?:\.\d+)?)\s*만큼"#), let v = Double(m[1]) { p = v }
            if let m = match(t, #"y\s*축의?\s*방향으로\s*(-?\d+(?:\.\d+)?)\s*만큼"#), let v = Double(m[1]) { q = v }
            guard p != 0 || q != 0 else { return nil }
            x += p; y += q
            rule = "(x, y) → (x + \(f(p)), y + \(f(q)))"
        } else if has(t, ["원점에 대하여", "원점에 대해"]) { x = -x; y = -y; rule = "원점 대칭: (x, y) → (−x, −y)" }
        else if has(t, ["y = x에 대하여", "y=x에 대하여", "y = x에 대해", "y=x에 대해"]) { swap(&x, &y); rule = "y = x 대칭: (x, y) → (y, x)" }
        else if has(t, ["x축에 대하여", "x축에 대해"]) { y = -y; rule = "x축 대칭: (x, y) → (x, −y)" }
        else if has(t, ["y축에 대하여", "y축에 대해"]) { x = -x; rule = "y축 대칭: (x, y) → (−x, y)" }
        else { return nil }
        let moved = DoitMathTopics.Point(x: x, y: y).label
        return Solved(kind: .coordinate, topic: "점의 이동", concept: "평행이동: (x, y) → (x + m, y + n). 대칭이동: x축 (x, −y), y축 (−x, y), 원점 (−x, −y), y = x (y, x)",
                      steps: [SolutionStep(hint: "규칙", work: rule), SolutionStep(hint: "점 \(pts[0].label)을 옮기면", work: moved)],
                      answer: moved)
    }

    // MARK: - 연립방정식의 해로 식의 값

    /// "x + y = 10, x − y = 4 일 때 xy의 값" → 해를 넣어 계산
    static func systemValue(_ solved: Solved, text: String) -> Solved? {
        let t = DoitAlgebra.normalize(text)
        guard let m = match(t, #"(?:일\s*때|일때|할\s*때|할때)\s*,?\s*([0-9a-z+\-*/^() ]+?)\s*의\s*값"#) else { return nil }
        var target = m[1].trimmingCharacters(in: .whitespaces)
        // "해를 x = p, y = q 라 할 때 p + q" → x + y
        if let alias = match(t, #"x\s*=\s*([a-wA-W])\s*,\s*y\s*=\s*([a-wA-W])\s*(?:이라|라|일\s*때|일때)"#) {
            target = String(target.map { String($0) == alias[1] ? "x" : String($0) == alias[2] ? "y" : $0 })
        }
        guard target.contains(where: { "xyz".contains($0) }), let p = DoitAlgebra.parse(target) else { return nil }
        var values: [Character: Double] = [:]
        for part in matches(solved.answer, #"([xyz])\s*=\s*(-?[0-9./]+)"#) {
            guard let name = part[1].first else { continue }
            let pieces = part[2].split(separator: "/").compactMap { Double(String($0)) }
            values[name] = pieces.count == 2 && pieces[1] != 0 ? pieces[0] / pieces[1] : pieces.first
        }
        guard !values.isEmpty, p.variables.allSatisfy({ values[$0] != nil }) else { return nil }
        let v = p.value(x: values["x"] ?? 0, y: values["y"] ?? 0, z: values["z"] ?? 0)
        var out = solved
        out.steps.append(SolutionStep(hint: "구한 해를 \(DoitAlgebra.describe(p))에 대입하면", work: "\(DoitAlgebra.describe(p)) = \(f(v))"))
        out.answer = f(v)
        return out
    }
}
