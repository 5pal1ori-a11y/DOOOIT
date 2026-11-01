import Foundation

/// 두잇 AI 수학 엔진 (외부 AI 없이 직접 계산)
/// - 계산: 3×(4+5)÷2, 2^10, √16
/// - 방정식: 2x+3=11, x²-5x+6=0, 3(x-1)=2x+4 (일차·이차, 풀이 과정 포함)
/// - 전개: (x+1)², (2x-3)(x+4)
enum DoitMath {
    struct Result {
        var title: String
        var steps: [String]
        var answer: String
    }

    /// 수식처럼 보이는지 (숫자와 연산 기호가 같이 있을 때)
    static func looksLikeMath(_ text: String) -> Bool {
        let expression = extractExpression(text)
        guard expression.count >= 3 else { return false }
        let hasDigit = expression.contains { $0.isNumber }
        let hasOperator = expression.contains { "+-*/^=×÷²³√()".contains($0) } || expression.contains("x")
        return hasDigit && hasOperator
    }

    /// 문장에서 식 부분만 꺼냄 ("2x+3=11 풀어줘" → "2x+3=11")
    static func extractExpression(_ text: String) -> String {
        let allowed = Set("0123456789.+-*/^=()xX×÷−²³√ ")
        var best = ""
        var current = ""
        for character in text {
            if allowed.contains(character) {
                current.append(character)
            } else {
                if current.trimmingCharacters(in: .whitespaces).count > best.trimmingCharacters(in: .whitespaces).count { best = current }
                current = ""
            }
        }
        if current.trimmingCharacters(in: .whitespaces).count > best.trimmingCharacters(in: .whitespaces).count { best = current }
        return best.trimmingCharacters(in: .whitespaces)
    }

    static func solve(_ text: String) -> Result? {
        let expression = extractExpression(text)
        guard !expression.isEmpty else { return nil }
        let sides = expression.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        if sides.count == 2 {
            guard let left = Parser.parse(sides[0]), let right = Parser.parse(sides[1]) else { return nil }
            return equation(left - right, original: expression)
        }
        guard sides.count == 1, let poly = Parser.parse(expression) else { return nil }
        if poly.degree <= 0 {
            return Result(title: "계산", steps: ["\(pretty(expression)) 를 계산하면"], answer: format(poly[0]))
        }
        return Result(title: "식 전개·정리", steps: ["\(pretty(expression)) 를 전개해서 정리하면"], answer: describe(poly))
    }

    // MARK: 방정식

    private static func equation(_ poly: Poly, original: String) -> Result {
        let a = poly[2], b = poly[1], c = poly[0]
        var steps = ["모든 항을 왼쪽으로 옮기면  \(describe(poly)) = 0"]
        switch poly.degree {
        case ..<1:
            let answer = abs(c) < 1e-9 ? "항상 성립 (모든 x가 해)" : "해가 없어요"
            return Result(title: "방정식", steps: steps, answer: answer)
        case 1:
            steps.append("\(format(b))x = \(format(-c))")
            steps.append("양변을 \(format(b))(으)로 나누면")
            return Result(title: "일차방정식", steps: steps, answer: "x = \(fraction(-c / b))")
        case 2:
            let d = b * b - 4 * a * c
            steps.append("근의 공식: x = (−b ± √(b²−4ac)) / 2a  (a=\(format(a)), b=\(format(b)), c=\(format(c)))")
            steps.append("판별식 D = b²−4ac = \(format(b * b)) − \(format(4 * a * c)) = \(format(d))")
            if abs(d) < 1e-9 {
                steps.append("D = 0 이므로 중근")
                return Result(title: "이차방정식", steps: steps, answer: "x = \(fraction(-b / (2 * a))) (중근)")
            }
            if d > 0 {
                let root = d.squareRoot()
                let x1 = (-b + root) / (2 * a), x2 = (-b - root) / (2 * a)
                steps.append("D > 0 이므로 서로 다른 두 실근")
                if abs(root - root.rounded()) < 1e-9 {
                    return Result(title: "이차방정식", steps: steps, answer: "x = \(fraction(min(x1, x2))) 또는 x = \(fraction(max(x1, x2)))")
                }
                let exact = "x = (\(format(-b)) ± √\(format(d))) / \(format(2 * a))"
                return Result(title: "이차방정식", steps: steps,
                              answer: "\(exact)\n≈ \(format(min(x1, x2), digits: 4)), \(format(max(x1, x2), digits: 4))")
            }
            let real = -b / (2 * a)
            let imaginary = (-d).squareRoot() / abs(2 * a)
            steps.append("D < 0 이므로 서로 다른 두 허근 (i² = −1)")
            let imaginaryText = abs(imaginary - imaginary.rounded()) < 1e-9
                ? fraction(imaginary)
                : "√\(format(-d))/\(format(abs(2 * a)))"
            return Result(title: "이차방정식", steps: steps,
                          answer: "x = \(fraction(real)) ± \(imaginaryText)i")
        default:
            return Result(title: "방정식", steps: steps, answer: "삼차 이상 방정식은 아직 풀 수 없어요. 인수분해할 수 있는지 먼저 살펴보세요.")
        }
    }

    // MARK: 다항식 (최고 4차까지)

    struct Poly {
        var c: [Double] = [0, 0, 0, 0, 0]

        subscript(_ i: Int) -> Double { i < c.count ? c[i] : 0 }

        var degree: Int {
            for i in stride(from: c.count - 1, through: 0, by: -1) where abs(c[i]) > 1e-9 { return i }
            return -1
        }

        static func constant(_ v: Double) -> Poly { var p = Poly(); p.c[0] = v; return p }
        static var x: Poly { var p = Poly(); p.c[1] = 1; return p }

        static func + (l: Poly, r: Poly) -> Poly { var p = Poly(); for i in 0..<5 { p.c[i] = l[i] + r[i] }; return p }
        static func - (l: Poly, r: Poly) -> Poly { var p = Poly(); for i in 0..<5 { p.c[i] = l[i] - r[i] }; return p }
        static prefix func - (p: Poly) -> Poly { Poly() - p }

        static func * (l: Poly, r: Poly) -> Poly? {
            var p = Poly()
            for i in 0..<5 where abs(l[i]) > 1e-12 {
                for j in 0..<5 where abs(r[j]) > 1e-12 {
                    guard i + j < 5 else { return nil }
                    p.c[i + j] += l[i] * r[j]
                }
            }
            return p
        }
    }

    /// 재귀 하향 파서: 덧셈·뺄셈 < 곱셈·나눗셈(생략된 곱 포함) < 부호 < 거듭제곱 < 괄호·√
    private struct Parser {
        let chars: [Character]
        var i = 0

        static func parse(_ raw: String) -> Poly? {
            var text = raw.replacingOccurrences(of: " ", with: "")
            for (from, to) in [("×", "*"), ("÷", "/"), ("−", "-"), ("²", "^2"), ("³", "^3"), ("X", "x")] {
                text = text.replacingOccurrences(of: from, with: to)
            }
            // 휴대폰으로 쓴 x2, x3 은 x², x³ 으로
            text = text.replacingOccurrences(of: "x([234])(?![0-9.])", with: "x^$1", options: .regularExpression)
            guard !text.isEmpty else { return nil }
            var parser = Parser(chars: Array(text))
            guard let result = parser.expression(), parser.i == parser.chars.count else { return nil }
            return result
        }

        private var peek: Character? { i < chars.count ? chars[i] : nil }

        mutating func expression() -> Poly? {
            guard var value = term() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                i += 1
                guard let rhs = term() else { return nil }
                value = op == "+" ? value + rhs : value - rhs
            }
            return value
        }

        mutating func term() -> Poly? {
            guard var value = unary() else { return nil }
            while let next = peek {
                if next == "*" || next == "/" {
                    i += 1
                    guard let rhs = unary() else { return nil }
                    if next == "*" {
                        guard let product = value * rhs else { return nil }
                        value = product
                    } else {
                        guard rhs.degree <= 0, abs(rhs[0]) > 1e-12 else { return nil }
                        value = value * .constant(1 / rhs[0]) ?? value
                    }
                } else if next == "(" || next == "x" || next == "√" || next.isNumber {
                    // 2x, 3(x+1), x(x-2) 처럼 곱하기 기호 생략
                    guard let rhs = power(), let product = value * rhs else { return nil }
                    value = product
                } else {
                    break
                }
            }
            return value
        }

        mutating func power() -> Poly? {
            guard let base = primary() else { return nil }
            guard peek == "^" else { return base }
            i += 1
            guard let exponent = unary(), exponent.degree <= 0 else { return nil }
            let n = exponent[0]
            if base.degree <= 0 {
                return .constant(pow(base[0], n))
            }
            guard n >= 0, n == n.rounded(), n <= 4 else { return nil }
            var result = Poly.constant(1)
            for _ in 0..<Int(n) {
                guard let product = result * base else { return nil }
                result = product
            }
            return result
        }

        /// 부호는 거듭제곱보다 나중에: -x² = -(x²)
        mutating func unary() -> Poly? {
            if peek == "-" { i += 1; return unary().map { -$0 } }
            if peek == "+" { i += 1; return unary() }
            return power()
        }

        mutating func primary() -> Poly? {
            guard let c = peek else { return nil }
            if c == "(" {
                i += 1
                guard let inner = expression(), peek == ")" else { return nil }
                i += 1
                return inner
            }
            if c == "x" { i += 1; return .x }
            if c == "√" {
                i += 1
                guard let inner = power(), inner.degree <= 0, inner[0] >= 0 else { return nil }
                return .constant(inner[0].squareRoot())
            }
            var number = ""
            while let d = peek, d.isNumber || d == "." { number.append(d); i += 1 }
            guard let value = Double(number) else { return nil }
            return .constant(value)
        }
    }

    // MARK: 보기 좋게

    static func describe(_ p: Poly) -> String {
        var parts: [String] = []
        let names = ["", "x", "x²", "x³", "x⁴"]
        for power in stride(from: 4, through: 0, by: -1) {
            let value = p[power]
            guard abs(value) > 1e-9 else { continue }
            let sign = value < 0 ? "−" : "+"
            let magnitude = abs(value)
            let number = (power > 0 && abs(magnitude - 1) < 1e-9) ? "" : fraction(magnitude)
            parts.append("\(sign) \(number)\(names[power])")
        }
        guard !parts.isEmpty else { return "0" }
        var text = parts.joined(separator: " ")
        if text.hasPrefix("+ ") { text.removeFirst(2) } else if text.hasPrefix("− ") { text = "−" + text.dropFirst(2) }
        return text
    }

    static func format(_ value: Double, digits: Int = 6) -> String {
        if abs(value - value.rounded()) < 1e-9 { return String(Int(value.rounded())) }
        return String(format: "%.\(digits)g", value)
    }

    /// 0.5 → 1/2 처럼 간단한 분수로 (분모 100 이하일 때)
    static func fraction(_ value: Double) -> String {
        if abs(value - value.rounded()) < 1e-9 { return String(Int(value.rounded())) }
        for denominator in 2...100 {
            let numerator = value * Double(denominator)
            if abs(numerator - numerator.rounded()) < 1e-7 {
                let n = Int(numerator.rounded())
                return n < 0 ? "−\(-n)/\(denominator)" : "\(n)/\(denominator)"
            }
        }
        return format(value, digits: 6)
    }

    private static func pretty(_ text: String) -> String {
        text.replacingOccurrences(of: "*", with: "×").replacingOccurrences(of: "/", with: "÷")
    }
}
