import Foundation

/// 모티 AI 수학 주제별 풀이 (외부 AI 없이 직접 계산)
/// 공학용 계산(삼각함수·로그·팩토리얼), 복소수, 경우의 수, 통계, 약수·배수, 백분율,
/// 좌표·직선·원, 도형 공식, 수열, 집합, 유리·무리함수, 산술·기하 평균
enum DoitMathTopics {
    typealias Solved = MathSolver.Solved
    private static func f(_ v: Double) -> String { DoitMath.fraction(v) }
    private static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }

    /// 문장 속 숫자들 (음수·소수 포함)
    static func numbers(in text: String) -> [Double] {
        let t = DoitAlgebra.normalize(text)
        var result: [Double] = []
        var current = ""
        let chars = Array(t)
        for (i, ch) in chars.enumerated() {
            if ch.isNumber || (ch == "." && !current.isEmpty) {
                current.append(ch)
            } else if ch == "-" && current.isEmpty && i + 1 < chars.count && chars[i + 1].isNumber
                        && (i == 0 || !(chars[i - 1].isNumber || chars[i - 1].isLetter || chars[i - 1] == ")")) {
                current = "-"
            } else {
                if let v = Double(current) { result.append(v) }
                current = ""
            }
        }
        if let v = Double(current) { result.append(v) }
        return result
    }

    // MARK: - 1. 공학용 계산 (sin, cos, tan, log, ln, √, !, π, e)

    static func calculate(_ text: String) -> Solved? {
        var t = DoitAlgebra.normalize(text).lowercased()
        // "2의 10제곱" → 2^10, "5 제곱" → 5^2, "제곱근 50" → √50, "세제곱" → ^3
        t = t.replacingOccurrences(of: #"(\d+(?:\.\d+)?)\s*의\s*(\d+)\s*제곱"#, with: "$1^$2", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(\d+(?:\.\d+)?)\s*(?:의\s*)?세제곱(?!근)"#, with: "$1^3", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(\d+(?:\.\d+)?)\s*(?:의\s*)?제곱(?!근)"#, with: "$1^2", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?:제곱근|루트)\s*(\d+(?:\.\d+)?)"#, with: "√$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(\d+(?:\.\d+)?)\s*의\s*제곱근"#, with: "√$1", options: .regularExpression)
        let functionWords = ["sin", "cos", "tan", "log", "ln", "π", "pi", "!", "√", "sqrt", "^", "%"]
        guard has(t, functionWords) || t.range(of: #"\d\s*[+\-*/]\s*\d"#, options: .regularExpression) != nil else { return nil }
        guard !t.contains("x"), !t.contains("="), !has(t, ["i)", "i ", "복소수"]) || has(t, ["sin", "pi"]) else { return nil }
        // 특수각 정확한 값
        if let exact = specialAngle(t) { return exact }
        var expression = t
        for word in ["계산해줘", "계산해", "계산", "얼마야", "얼마", "구해줘", "의 값", "값은", "값", "?", "은", "는", "을", "를"] {
            expression = expression.replacingOccurrences(of: word, with: " ")
        }
        expression = expression.replacingOccurrences(of: "°", with: "").replacingOccurrences(of: "도", with: "")
        // log₂8, log2 8 → 밑 표시(_)
        let subscripts: [Character: Character] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9"]
        expression = String(expression.map { subscripts[$0] ?? $0 })
        expression = expression.replacingOccurrences(of: #"log_?(\d+)\s+(\d+(?:\.\d+)?)"#, with: "log_$1($2)", options: .regularExpression)
        expression = expression.replacingOccurrences(of: #"log_?(\d+)\s*\("#, with: "log_$1(", options: .regularExpression)
        expression = expression.trimmingCharacters(in: .whitespaces)
        guard expression.range(of: "[가-힣]", options: .regularExpression) == nil else {
            // 한글이 섞여 있으면 수식 부분만
            let allowed = Set("0123456789.+-*/^()!%√ sincotalgpe_")
            let pieces: [String] = expression.split(whereSeparator: { (ch: Character) -> Bool in !allowed.contains(ch) }).map { String($0) }
            let run = pieces.max(by: { $0.count < $1.count }) ?? ""
            return evaluateText(run, original: text)
        }
        return evaluateText(expression, original: text)
    }

    private static func evaluateText(_ expression: String, original: String) -> Solved? {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, trimmed.contains(where: \.isNumber) || trimmed.contains("π") || trimmed.contains("pi") else { return nil }
        // 분수·제곱근·특수각은 소수로 바꾸지 않고 정확한 값으로 (2/3 + 1/4 = 11/12, √12 + √27 = 5√3)
        if let exact = DoitMathExact.exactCalc(trimmed, original: original) { return exact }
        var parser = CalcParser(chars: Array(trimmed.replacingOccurrences(of: " ", with: "")))
        guard let value = parser.expression(), parser.i == parser.chars.count, value.isFinite else { return nil }
        var answer: String
        if let m = trimmed.firstMatch(of: #/^√\s*(\d+)$/#), let n = Int(String(m.1)), n > 0, value != value.rounded() {
            // √50 → 5√2 (≈ 7.0711)
            answer = "\(DoitAlgebra.sqrtText(Double(n))) (≈ \(DoitMath.format(value, digits: 6)))"
        } else if abs(value - value.rounded()) < 1e-9 && abs(value) < 1e15 {
            answer = String(DoitMath.safeInt(value))
        } else {
            let frac = f(value)
            answer = frac.contains("/") ? "\(frac) (≈ \(DoitMath.format(value, digits: 8)))" : DoitMath.format(value, digits: 10)
        }
        return Solved(kind: .calc, topic: "계산", concept: "괄호 → 거듭제곱 → 곱셈·나눗셈 → 덧셈·뺄셈 순서로 계산해요. 삼각함수의 각은 도(°) 단위예요 (π가 있으면 라디안).",
                      steps: [SolutionStep(hint: "식", work: trimmed.replacingOccurrences(of: "*", with: "×").replacingOccurrences(of: "/", with: "÷"))],
                      answer: answer)
    }

    /// sin 30°, cos 45°, tan 60° 같은 특수각
    private static func specialAngle(_ t: String) -> Solved? {
        guard let m = t.firstMatch(of: #/(sin|cos|tan)\s*\(?\s*(-?\d+)\s*(?:°|도)?\s*\)?/#), let degree = Int(String(m.2)) else { return nil }
        let rest = t.replacingOccurrences(of: String(m.0), with: "")
        guard rest.range(of: #"[\d+\-*/^]"#, options: .regularExpression) == nil else { return nil }
        let name = String(m.1)
        let angle = ((degree % 360) + 360) % 360
        let table: [Int: (String, String, String)] = [
            0: ("0", "1", "0"), 30: ("1/2", "√3/2", "√3/3"), 45: ("√2/2", "√2/2", "1"), 60: ("√3/2", "1/2", "√3"),
            90: ("1", "0", "없음"), 120: ("√3/2", "−1/2", "−√3"), 135: ("√2/2", "−√2/2", "−1"), 150: ("1/2", "−√3/2", "−√3/3"),
            180: ("0", "−1", "0"), 210: ("−1/2", "−√3/2", "√3/3"), 225: ("−√2/2", "−√2/2", "1"), 240: ("−√3/2", "−1/2", "√3"),
            270: ("−1", "0", "없음"), 300: ("−√3/2", "1/2", "−√3"), 315: ("−√2/2", "√2/2", "−1"), 330: ("−1/2", "√3/2", "−√3/3")
        ]
        guard let row = table[angle] else { return nil }
        let value = name == "sin" ? row.0 : name == "cos" ? row.1 : row.2
        var steps = [SolutionStep(hint: "각을 0°~360° 사이로", work: "\(degree)° → \(angle)°")]
        if angle > 90 {
            let quadrant = angle < 180 ? 2 : angle < 270 ? 3 : 4
            let sign = name == "sin" ? (quadrant <= 2 ? "+" : "−") : name == "cos" ? (quadrant == 4 ? "+" : "−") : (quadrant == 3 ? "+" : "−")
            steps.append(SolutionStep(hint: "제\(quadrant)사분면의 \(name) 부호는?", work: sign))
        }
        steps.append(SolutionStep(hint: "특수각 표에서", work: "\(name) \(degree)° = \(value)"))
        return Solved(kind: .calc, topic: "삼각함수의 값", concept: "특수각 30°, 45°, 60°의 값을 기억하고, 사분면에 따라 부호를 정해요 (얼싸안코: 1사분면 모두 +, 2사분면 sin +, 3사분면 tan +, 4사분면 cos +).",
                      steps: steps, answer: value)
    }

    private struct CalcParser {
        let chars: [Character]
        var i = 0
        private var peek: Character? { i < chars.count ? chars[i] : nil }
        private func starts(_ word: String) -> Bool {
            let w = Array(word)
            guard i + w.count <= chars.count else { return false }
            return Array(chars[i..<(i + w.count)]) == w
        }

        mutating func expression() -> Double? {
            guard var v = term() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                i += 1
                guard let r = term() else { return nil }
                v = op == "+" ? v + r : v - r
            }
            return v
        }

        mutating func term() -> Double? {
            guard var v = unary() else { return nil }
            while let op = peek {
                if op == "*" || op == "/" {
                    i += 1
                    guard let r = unary() else { return nil }
                    if op == "/" { guard r != 0 else { return nil }; v /= r } else { v *= r }
                } else if op == "(" || op == "√" || op == "π" || starts("pi") || starts("sin") || starts("cos") || starts("tan") || starts("log") || starts("ln") || starts("sqrt") {
                    guard let r = power() else { return nil }
                    v *= r
                } else {
                    break
                }
            }
            return v
        }

        mutating func unary() -> Double? {
            if peek == "-" { i += 1; return unary().map { -$0 } }
            if peek == "+" { i += 1; return unary() }
            return power()
        }

        mutating func power() -> Double? {
            guard var base = postfix() else { return nil }
            if peek == "^" {
                i += 1
                guard let e = unary() else { return nil }
                base = pow(base, e)
            }
            return base
        }

        mutating func postfix() -> Double? {
            guard var v = primary() else { return nil }
            while let p = peek {
                if p == "!" {
                    i += 1
                    guard v >= 0, v == v.rounded(), v <= 170 else { return nil }
                    v = (1...max(1, Int(v))).reduce(1.0) { $0 * Double($1) }
                } else if p == "%" {
                    i += 1
                    v /= 100
                } else { break }
            }
            return v
        }

        mutating func function(_ name: String) -> Double? {
            i += name.count
            // log2 8, log_2 8
            var base: Double? = nil
            if name == "log" {
                if peek == "_" {
                    i += 1
                    var digits = ""
                    while let d = peek, d.isNumber { digits.append(d); i += 1 }
                    base = Double(digits)
                }
            }
            let argument: Double?
            if peek == "(" {
                i += 1
                argument = expression()
                guard peek == ")" else { return nil }
                i += 1
            } else {
                argument = power()
            }
            guard let x = argument else { return nil }
            let usesRadian = chars.contains("π") || chars.contains(where: { $0 == "p" })
            let angle = usesRadian ? x : x * .pi / 180
            func clean(_ v: Double) -> Double { abs(v) < 1e-12 ? 0 : v }
            switch name {
            case "sin": return clean(sin(angle))
            case "cos": return clean(cos(angle))
            case "tan": return clean(tan(angle))
            case "ln": return x > 0 ? log(x) : nil
            case "sqrt": return x >= 0 ? x.squareRoot() : nil
            default:
                guard x > 0 else { return nil }
                let b = base ?? 10
                return log(x) / log(b)
            }
        }

        mutating func primary() -> Double? {
            guard let c = peek else { return nil }
            if c == "(" {
                i += 1
                guard let v = expression(), peek == ")" else { return nil }
                i += 1
                return v
            }
            if c == "√" { i += 1; guard let v = power(), v >= 0 else { return nil }; return v.squareRoot() }
            if c == "π" { i += 1; return .pi }
            if starts("pi") { i += 2; return .pi }
            for name in ["sqrt", "sin", "cos", "tan", "log", "ln"] where starts(name) { return function(name) }
            if c == "e" { i += 1; return M_E }
            var number = ""
            while let d = peek, d.isNumber || d == "." || d == "," {
                if d != "," { number.append(d) }
                i += 1
            }
            return Double(number)
        }
    }

    // MARK: - 2. 복소수

    struct Complex {
        var re: Double, im: Double
        static func + (a: Complex, b: Complex) -> Complex { Complex(re: a.re + b.re, im: a.im + b.im) }
        static func - (a: Complex, b: Complex) -> Complex { Complex(re: a.re - b.re, im: a.im - b.im) }
        static func * (a: Complex, b: Complex) -> Complex { Complex(re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re) }
        static func / (a: Complex, b: Complex) -> Complex? {
            let d = b.re * b.re + b.im * b.im
            guard d > 1e-15 else { return nil }
            return Complex(re: (a.re * b.re + a.im * b.im) / d, im: (a.im * b.re - a.re * b.im) / d)
        }
        var text: String {
            let r = abs(re) < 1e-12 ? 0 : re, m = abs(im) < 1e-12 ? 0 : im
            if m == 0 { return DoitMath.fraction(r) }
            let imagPart = abs(abs(m) - 1) < 1e-12 ? "i" : DoitMath.fraction(abs(m)) + "i"
            if r == 0 { return (m < 0 ? "−" : "") + imagPart }
            return "\(DoitMath.fraction(r)) \(m < 0 ? "−" : "+") \(imagPart)"
        }
    }

    static func complex(_ text: String) -> Solved? {
        let t = DoitAlgebra.normalize(text)
        let allowed = Set("0123456789.+-*/^()i ")
        let runs: [String] = t.split(whereSeparator: { !allowed.contains($0) }).map { String($0).trimmingCharacters(in: .whitespaces) }
        let candidates: [String] = runs.filter { $0.contains("i") && $0.count >= 2 }
        let run: String = candidates.max(by: { $0.count < $1.count }) ?? ""
        guard !run.isEmpty else { return nil }
        // 식에 실수 x 같은 문자가 붙어 있으면 ("(1 + i)x + 2 − 3i") 계산 문제가 아님 (조건 문제: 다른 풀이로)
        let withLetters = Set("0123456789.+-*/^() abcdefghijklmnopqrstuvwxyz")
        let wide = t.split(whereSeparator: { !withLetters.contains($0) }).map(String.init)
        if wide.contains(where: { $0.contains(run) && $0.contains(where: { $0.isLetter && $0 != "i" }) }) { return nil }
        let wantsConjugate = has(t, ["켤레"])
        var parser = ComplexParser(chars: Array(run.replacingOccurrences(of: " ", with: "")))
        guard let value = parser.expression(), parser.i == parser.chars.count else { return nil }
        var steps = [SolutionStep(hint: "i² = −1 을 이용해 계산하면", work: "\(run.replacingOccurrences(of: "*", with: "×")) = \(value.text)")]
        if run.contains("/") {
            steps.insert(SolutionStep(hint: "분모가 복소수면?", work: "분모의 켤레복소수를 분자·분모에 곱해서 분모를 실수로 만들어요"), at: 0)
        }
        if let m = run.firstMatch(of: #/i\^(\d+)/#), let n = Int(String(m.1)) {
            steps.insert(SolutionStep(hint: "i의 거듭제곱은 4개씩 반복 (i, −1, −i, 1)", work: "\(n) = 4×\(n / 4) + \(n % 4) 이므로 i^\(n) = i^\(n % 4)"), at: 0)
        }
        if wantsConjugate {
            let conj = Complex(re: value.re, im: -value.im)
            steps.append(SolutionStep(hint: "켤레복소수는 허수부의 부호만 바꿔요", work: conj.text))
            return Solved(kind: .complex, topic: "켤레복소수", concept: "a + bi 의 켤레복소수는 a − bi 예요.", steps: steps, answer: conj.text)
        }
        return Solved(kind: .complex, topic: "복소수의 계산", concept: "i² = −1. 실수부끼리, 허수부끼리 계산하고, 나눗셈은 분모의 켤레복소수를 곱해요.",
                      steps: steps, answer: value.text)
    }

    private struct ComplexParser {
        let chars: [Character]
        var i = 0
        private var peek: Character? { i < chars.count ? chars[i] : nil }

        mutating func expression() -> Complex? {
            guard var v = term() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                i += 1
                guard let r = term() else { return nil }
                v = op == "+" ? v + r : v - r
            }
            return v
        }
        mutating func term() -> Complex? {
            guard var v = unary() else { return nil }
            while let op = peek {
                if op == "*" || op == "/" {
                    i += 1
                    guard let r = unary() else { return nil }
                    if op == "*" { v = v * r } else { guard let q = v / r else { return nil }; v = q }
                } else if op == "(" || op == "i" || op.isNumber {
                    guard let r = power() else { return nil }
                    v = v * r
                } else { break }
            }
            return v
        }
        mutating func unary() -> Complex? {
            if peek == "-" { i += 1; return unary().map { Complex(re: -$0.re, im: -$0.im) } }
            if peek == "+" { i += 1; return unary() }
            return power()
        }
        mutating func power() -> Complex? {
            guard let base = primary() else { return nil }
            guard peek == "^" else { return base }
            i += 1
            var digits = ""
            while let d = peek, d.isNumber { digits.append(d); i += 1 }
            guard let n = Int(digits), n <= 10000 else { return nil }
            var result = Complex(re: 1, im: 0)
            // i의 거듭제곱은 주기 4
            let count = (abs(base.re) < 1e-12 && abs(abs(base.im) - 1) < 1e-12) ? n % 4 : n
            guard count <= 64 else { return nil }
            for _ in 0..<count { result = result * base }
            return result
        }
        mutating func primary() -> Complex? {
            guard let c = peek else { return nil }
            if c == "(" {
                i += 1
                guard let v = expression(), peek == ")" else { return nil }
                i += 1
                return v
            }
            if c == "i" { i += 1; return Complex(re: 0, im: 1) }
            var number = ""
            while let d = peek, d.isNumber || d == "." { number.append(d); i += 1 }
            guard let v = Double(number) else { return nil }
            return Complex(re: v, im: 0)
        }
    }

    // MARK: - 3. 경우의 수 (순열, 조합, 팩토리얼)

    static func factorial(_ n: Int) -> Double { n <= 1 ? 1 : (2...n).reduce(1.0) { $0 * Double($1) } }
    static func permutation(_ n: Int, _ r: Int) -> Double { r > n || r < 0 ? 0 : (0..<r).reduce(1.0) { $0 * Double(n - $1) } }
    static func combination(_ n: Int, _ r: Int) -> Double {
        guard r >= 0, r <= n else { return 0 }
        let k = min(r, n - r)
        return (0..<k).reduce(1.0) { $0 * Double(n - $1) / Double($1 + 1) }.rounded()
    }
    private static func int(_ v: Double) -> String { abs(v) < 1e15 ? String(DoitMath.safeInt(v)) : DoitMath.format(v) }

    static func counting(_ text: String) -> Solved? {
        let t = DoitAlgebra.normalize(text)
        let subscripts: [Character: Character] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9"]
        let plain = String(t.map { subscripts[$0] ?? $0 })
        // 5P2, 5C2, 5H2, 5Π2, P(5,2), C(5,2)
        var symbol: (String, Int, Int)?
        if let m = plain.firstMatch(of: #/(\d+)\s*([PCHΠ])\s*(\d+)/#), let n = Int(String(m.1)), let r = Int(String(m.3)) { symbol = (String(m.2), n, r) }
        else if let m = plain.firstMatch(of: #/([PCH])\(\s*(\d+)\s*,\s*(\d+)\s*\)/#), let n = Int(String(m.2)), let r = Int(String(m.3)) { symbol = (String(m.1), n, r) }
        // 기호가 여러 개거나 다른 계산이 섞이면 (₅P₂ + ₅C₂) 값으로 바꿔 넣고 계산
        let symbolPattern = #"(\d+)\s*([PCH])\s*(\d+)"#
        let allSymbols = DoitMathExact.matches(plain, symbolPattern)
        if symbol != nil, !allSymbols.isEmpty {
            var rest = plain
            for m in allSymbols { rest = rest.replacingOccurrences(of: m[0], with: " ") }
            if allSymbols.count > 1 || rest.range(of: #"[0-9]\s*[+\-*/]|[+\-*/]\s*[0-9]|[+\-*/^]"#, options: .regularExpression) != nil {
                var expression = plain
                var shown: [String] = []
                for m in allSymbols {
                    guard let n = Int(m[1]), let r = Int(m[3]), n <= 30, r <= n else { return nil }
                    let value = m[2] == "P" ? permutation(n, r) : m[2] == "C" ? combination(n, r) : combination(n + r - 1, r)
                    expression = expression.replacingOccurrences(of: m[0], with: "(\(int(value)))")
                    shown.append("\(m[1])\(m[2])\(m[3]) = \(int(value))")
                }
                let allowed = Set("0123456789.+-*/^()! ")
                let runs = expression.split(whereSeparator: { !allowed.contains($0) }).map { String($0).trimmingCharacters(in: .whitespaces) }
                guard let run = runs.max(by: { $0.count < $1.count }), let value = DoitMathExact.exactValue(run), let r = value.rational else { return nil }
                return Solved(kind: .counting, topic: "순열과 조합의 계산", concept: "ₙPᵣ = n!/(n−r)!, ₙCᵣ = ₙPᵣ/r! 를 각각 구한 뒤 계산해요.",
                              steps: [SolutionStep(hint: "각각의 값", work: shown.joined(separator: ", ")), SolutionStep(hint: "계산하면", work: r.text)], answer: r.text)
            }
        }
        if let (kind, n, r) = symbol, n <= 170, r <= 170 {
            switch kind {
            case "P":
                return Solved(kind: .counting, topic: "순열 ₙPᵣ", concept: "서로 다른 n개에서 r개를 골라 순서대로 나열하는 경우의 수: ₙPᵣ = n!/(n−r)!",
                              steps: [SolutionStep(hint: "\(n)부터 1씩 줄여가며 \(r)개를 곱하면", work: (0..<min(r, 8)).map { String(n - $0) }.joined(separator: "×") + (r > 8 ? "×…" : ""))],
                              answer: int(permutation(n, r)))
            case "C":
                return Solved(kind: .counting, topic: "조합 ₙCᵣ", concept: "서로 다른 n개에서 순서 없이 r개를 고르는 경우의 수: ₙCᵣ = ₙPᵣ / r!  (ₙCᵣ = ₙCₙ₋ᵣ)",
                              steps: [SolutionStep(hint: "ₙPᵣ를 r!로 나누면", work: "\(int(permutation(n, r))) ÷ \(int(factorial(r)))")],
                              answer: int(combination(n, r)))
            case "H":
                return Solved(kind: .counting, topic: "중복조합 ₙHᵣ", concept: "ₙHᵣ = ₙ₊ᵣ₋₁Cᵣ",
                              steps: [SolutionStep(hint: "조합으로 바꾸면", work: "\(n + r - 1)C\(r)")], answer: int(combination(n + r - 1, r)))
            default:
                return Solved(kind: .counting, topic: "중복순열 ₙΠᵣ", concept: "ₙΠᵣ = nʳ",
                              steps: [SolutionStep(hint: "n을 r번 곱하면", work: "\(n)^\(r)")], answer: int(pow(Double(n), Double(r))))
            }
        }
        if let m = plain.firstMatch(of: #/(\d+)\s*!/#), let n = Int(String(m.1)), n <= 170,
           plain.replacingOccurrences(of: String(m.0), with: "").range(of: #"[\d+\-*/]"#, options: .regularExpression) == nil {
            return Solved(kind: .counting, topic: "팩토리얼", concept: "n! = n×(n−1)×…×2×1, 0! = 1",
                          steps: [SolutionStep(hint: "1부터 \(n)까지 곱하면", work: n <= 8 ? (1...max(1, n)).map(String.init).joined(separator: "×") : "1×2×…×\(n)")],
                          answer: int(factorial(n)))
        }

        // 문장형: "5명 중 2명을 뽑는", "6명을 일렬로", "원형으로 앉는", "회장과 부회장"
        var counted = t.matches(of: #/(\d+)\s*(명|개|권|장|가지|자리|팀|곳)/#).compactMap { Int(String($0.1)) }
        // "네 사람", "다섯 명" 처럼 한글로 쓴 수
        if counted.isEmpty, let m = DoitMathExact.match(t, #"(?<![가-힣])(두|세|네|다섯|여섯|일곱|여덟|아홉|열)\s*(?:명|사람|개|권|장|자리|팀)"#) {
            let words = ["두": 2, "세": 3, "네": 4, "다섯": 5, "여섯": 6, "일곱": 7, "여덟": 8, "아홉": 9, "열": 10]
            if let n = words[m[1]] { counted = [n] }
        }
        guard !counted.isEmpty, has(t, ["경우의 수", "방법의 수", "가지 수", "몇 가지", "방법은", "경우는", "뽑", "고르", "세우", "앉", "나열", "배열", "만들 수 있는"]) else { return nil }
        // 수가 셋 이상이거나 (남학생 4명, 여학생 3명 중 2명), 숫자 카드·확률은 여기서 풀지 않음 (틀린 답 방지)
        guard counted.count <= 2, !has(t, ["카드", "확률", "적어도", "이웃", "포함", "주사위", "동전"]) else { return nil }
        if counted.count == 2, t.range(of: #"\d+\s*(?:명|개|권|장|가지|자리|팀|곳)\s*(?:,|과|와|및)\s*[가-힣]*\s*\d+\s*(?:명|개|권|장)"#, options: .regularExpression) != nil { return nil }
        let n = counted[0]
        let roles = ["부회장", "총무", "서기", "반장", "부반장", "1등", "2등", "3등", "금메달", "은메달", "동메달"].filter { t.contains($0) }.count
            + (t.replacingOccurrences(of: "부회장", with: "").contains("회장") ? 1 : 0)
        let r = counted.count > 1 ? counted[1] : (roles >= 2 ? roles : n)
        guard n <= 30, r <= n else { return nil }
        if has(t, ["원형", "둥글게", "원탁", "원 모양"]) {
            return Solved(kind: .counting, topic: "원순열", concept: "서로 다른 n개를 원형으로 배열하는 경우의 수는 (n−1)! — 회전해서 같은 것은 하나로 봐요.",
                          steps: [SolutionStep(hint: "한 명을 고정하고 나머지를 나열", work: "(\(n)−1)! = \(n - 1)!")], answer: int(factorial(n - 1)))
        }
        let ordered = has(t, ["일렬", "줄", "순서", "나열", "배열", "회장", "부회장", "1등", "2등", "자리", "세우", "비밀번호", "자연수를 만", "자리 수"])
        let choose = has(t, ["뽑", "고르", "선택", "대표", "선발"]) && !ordered
        if has(t, ["중복", "여러 번", "반복해서"]) {
            return ordered || !choose
                ? Solved(kind: .counting, topic: "중복순열", concept: "같은 것을 여러 번 써서 r개를 나열: nʳ", steps: [SolutionStep(hint: "자리마다 \(n)가지", work: "\(n)^\(r)")], answer: int(pow(Double(n), Double(r))))
                : Solved(kind: .counting, topic: "중복조합", concept: "ₙHᵣ = ₙ₊ᵣ₋₁Cᵣ", steps: [SolutionStep(hint: "조합으로 바꾸면", work: "\(n + r - 1)C\(r)")], answer: int(combination(n + r - 1, r)))
        }
        if choose && counted.count > 1 {
            return Solved(kind: .counting, topic: "조합", concept: "순서와 상관없이 고르면 조합 ₙCᵣ = ₙPᵣ / r!",
                          steps: [SolutionStep(hint: "\(n)개 중 \(r)개를 순서 없이 고르면", work: "₍\(n)₎C₍\(r)₎ = \(int(permutation(n, r))) ÷ \(r)! = \(int(combination(n, r)))")],
                          answer: int(combination(n, r)))
        }
        if ordered || counted.count == 1 {
            if r == n {
                return Solved(kind: .counting, topic: "순열 (모두 나열)", concept: "서로 다른 n개를 일렬로 나열하는 경우의 수는 n!",
                              steps: [SolutionStep(hint: "첫 자리 \(n)가지, 다음 \(n - 1)가지, …", work: "\(n)! = \(int(factorial(n)))")], answer: int(factorial(n)))
            }
            return Solved(kind: .counting, topic: "순열", concept: "순서를 생각해서 r개를 고르면 순열 ₙPᵣ",
                          steps: [SolutionStep(hint: "\(n)개 중 \(r)개를 순서대로", work: "₍\(n)₎P₍\(r)₎ = \(int(permutation(n, r)))")], answer: int(permutation(n, r)))
        }
        return nil
    }

    // MARK: - 4. 통계 (평균, 중앙값, 최빈값, 분산, 표준편차)

    static func statistics(_ text: String) -> Solved? {
        guard has(text, ["평균", "중앙값", "최빈값", "분산", "표준편차", "범위", "중간값"]) else { return nil }
        // "평균이 85점일 때"처럼 평균이 조건이면 자료로 계산하면 안 됨 (문장제 풀이에서 따로)
        guard text.range(of: #"(?:평균|분산|중앙값|표준편차)(?:이|은|는)\s*-?\d"#, options: .regularExpression) == nil else { return nil }
        // "5개의 변량 2, 4, 6"의 5처럼 개수를 자료로 세지 않게: 쉼표로 나열된 자료가 있으면 그것만
        let listed = DoitMathWord.dataList(DoitAlgebra.normalize(text)).flatMap { items in items.compactMap { Double($0) } }
        let values = (listed?.count ?? 0) >= 2 ? listed! : numbers(in: text)
        // "시험 범위는 1단원부터 3단원까지"처럼 '범위'만 있고 자료가 없으면 통계가 아님
        if !has(text, ["평균", "중앙값", "최빈값", "분산", "표준편차", "중간값"]), listed == nil, values.count < 3 { return nil }
        // "3x − 1 ≤ 2x + 4 를 만족하는 x의 값의 범위"는 부등식의 해 (자료의 범위가 아님)
        if !has(text, ["평균", "중앙값", "최빈값", "분산", "표준편차", "중간값", "자료", "변량"]), text.contains(where: { "<>≤≥".contains($0) }) { return nil }
        guard values.count >= 2 else { return nil }
        let n = Double(values.count)
        let mean = values.reduce(0, +) / n
        let sorted = values.sorted()
        let median = values.count % 2 == 1 ? sorted[values.count / 2] : (sorted[values.count / 2 - 1] + sorted[values.count / 2]) / 2
        var counts: [Double: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }
        let top = counts.values.max() ?? 1
        let modes = counts.filter { $0.value == top }.keys.sorted()
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / n
        let sd = variance.squareRoot()
        func d(_ v: Double) -> String { DoitMath.format(v, digits: 6) }
        let steps = [
            SolutionStep(hint: "자료 \(values.count)개를 크기순으로", work: sorted.map(d).joined(separator: ", ")),
            SolutionStep(hint: "평균 = 합 ÷ 개수", work: "\(d(values.reduce(0, +))) ÷ \(values.count) = \(f(mean))"),
            SolutionStep(hint: "중앙값 = 가운데 값", work: d(median)),
            SolutionStep(hint: "최빈값 = 가장 많이 나온 값", work: top == 1 ? "모두 한 번씩이라 최빈값이 없어요" : modes.map(d).joined(separator: ", ")),
            SolutionStep(hint: "분산 = (편차²)의 평균", work: f(variance)),
            SolutionStep(hint: "표준편차 = √분산", work: DoitAlgebra.sqrtText(variance))
        ]
        let answer: String
        if has(text, ["표준편차"]) {
            let exact = DoitAlgebra.sqrtText(variance)
            answer = "표준편차 " + exact + (exact.contains("√") && !exact.contains("≈") ? " (≈ \(d(sd)))" : "")
        }
        else if has(text, ["분산"]) { answer = "분산 " + f(variance) }
        else if has(text, ["중앙값", "중간값"]) { answer = "중앙값 " + d(median) }
        else if has(text, ["최빈값"]) { answer = top == 1 ? "최빈값 없음" : "최빈값 " + modes.map(d).joined(separator: ", ") }
        else if has(text, ["범위"]) { answer = "범위 \(d(sorted.last! - sorted.first!))" }
        else { answer = "평균 " + f(mean) + (f(mean).contains("/") ? " (≈ \(d(mean)))" : "") }
        return Solved(kind: .statistics, topic: "자료의 정리 (대푯값과 산포도)", concept: "대푯값: 평균·중앙값·최빈값 / 산포도: 분산(편차 제곱의 평균), 표준편차(분산의 제곱근)",
                      steps: steps, answer: answer)
    }

    // MARK: - 5. 약수와 배수, 소수

    static func primeFactors(_ n: Int) -> [(Int, Int)] {
        var n = n, result: [(Int, Int)] = [], p = 2
        while p * p <= n {
            var k = 0
            while n % p == 0 { n /= p; k += 1 }
            if k > 0 { result.append((p, k)) }
            p += 1
        }
        if n > 1 { result.append((n, 1)) }
        return result
    }

    static func factorText(_ factors: [(Int, Int)]) -> String {
        factors.map { $0.1 == 1 ? String($0.0) : "\($0.0)\(DoitMath.superscript($0.1))" }.joined(separator: " × ")
    }

    static func numberTheory(_ text: String) -> Solved? {
        let values = numbers(in: text).filter { $0 > 0 && $0 == $0.rounded() && $0 < 1e12 }.map { Int($0) }
        guard !values.isEmpty else { return nil }
        if text.range(of: #"(?:최대공약수|최소공배수)(?:가|는|이)\s*\d"#, options: .regularExpression) != nil { return nil }
        if has(text, ["최대공약수", "최소공배수", "GCD", "LCM", "gcd", "lcm"]), values.count >= 2 {
            let g = values.reduce(0) { DoitAlgebra.gcd($0, $1) }
            let l = values.reduce(1) { $0 / DoitAlgebra.gcd($0, $1) * $1 }
            let steps = values.map { SolutionStep(hint: "\($0)을 소인수분해", work: factorText(primeFactors($0))) } + [
                SolutionStep(hint: "공통인 소인수를 가장 작은 지수로 곱하면 최대공약수", work: String(g)),
                SolutionStep(hint: "모든 소인수를 가장 큰 지수로 곱하면 최소공배수", work: String(l))
            ]
            let asksLCM = has(text, ["최소공배수", "LCM", "lcm"]) && !has(text, ["최대공약수", "GCD", "gcd"])
            let asksGCD = has(text, ["최대공약수", "GCD", "gcd"]) && !has(text, ["최소공배수", "LCM", "lcm"])
            return Solved(kind: .numberTheory, topic: "최대공약수와 최소공배수", concept: "두 수 A, B에 대해 A × B = 최대공약수 × 최소공배수 예요.",
                          steps: steps, answer: asksLCM ? "최소공배수 \(l)" : asksGCD ? "최대공약수 \(g)" : "최대공약수 \(g), 최소공배수 \(l)")
        }
        // 공약수·공배수: 최대공약수의 약수, 최소공배수의 배수 ("100 이하" 같은 범위 수는 빼고)
        if has(text, ["공약수", "공배수"]) && !has(text, ["최대공약수", "최소공배수"]) {
            var list = values
            var limit: Int?
            if let m = text.firstMatch(of: #/(\d+)\s*(이하|미만|보다\s*작은)/#), let v = Int(String(m.1)) {
                limit = String(m.2) == "이하" ? v : v - 1
                if let index = list.firstIndex(of: v) { list.remove(at: index) }
            }
            guard list.count >= 2 else { return nil }
            let g = list.reduce(0) { DoitAlgebra.gcd($0, $1) }
            let l = list.reduce(1) { $0 / DoitAlgebra.gcd($0, $1) * $1 }
            let names = list.map(String.init).joined(separator: ", ")
            if has(text, ["공약수"]) {
                let ds = DoitAlgebra.divisors(g)
                let steps = [SolutionStep(hint: "\(names)의 최대공약수", work: String(g)), SolutionStep(hint: "공약수는 최대공약수의 약수", work: ds.map(String.init).joined(separator: ", "))]
                let answer = has(text, ["개수", "몇 개"]) ? "\(ds.count)개" : has(text, ["합"]) ? "공약수의 합 \(ds.reduce(0, +))" : ds.map(String.init).joined(separator: ", ")
                return Solved(kind: .numberTheory, topic: "공약수", concept: "두 수의 공약수는 최대공약수의 약수와 같아요.", steps: steps, answer: answer)
            }
            var steps = [SolutionStep(hint: "\(names)의 최소공배수", work: String(l))]
            if let n = limit, has(text, ["개수", "몇 개"]) {
                steps.append(SolutionStep(hint: "공배수는 최소공배수의 배수: \(n) ÷ \(l)의 몫", work: "\(n / l)"))
                return Solved(kind: .numberTheory, topic: "공배수", concept: "두 수의 공배수는 최소공배수의 배수와 같아요.", steps: steps, answer: "\(n / l)개")
            }
            if has(text, ["가장 작은"]) {
                return Solved(kind: .numberTheory, topic: "공배수", concept: "두 수의 공배수 중 가장 작은 수가 최소공배수예요.", steps: steps, answer: String(l))
            }
            return nil
        }
        let n = values[0]
        if has(text, ["소인수분해"]) {
            let factors = primeFactors(n)
            return Solved(kind: .numberTheory, topic: "소인수분해", concept: "가장 작은 소수부터 계속 나눠서 소수들의 곱으로 나타내요.",
                          steps: [SolutionStep(hint: "작은 소수부터 나누면", work: factors.map { "\($0.0)로 \($0.1)번" }.joined(separator: ", "))],
                          answer: "\(n) = \(factorText(factors))")
        }
        if has(text, ["약수"]) && n <= 10_000_000 {
            let list = DoitAlgebra.divisors(n)
            let factors = primeFactors(n)
            let count = factors.reduce(1) { $0 * ($1.1 + 1) }
            var steps = [SolutionStep(hint: "소인수분해", work: "\(n) = \(factorText(factors))"),
                         SolutionStep(hint: "약수의 개수 = (지수+1)의 곱", work: factors.map { "(\($0.1)+1)" }.joined(separator: "×") + " = \(count)")]
            if has(text, ["합"]) { steps.append(SolutionStep(hint: "약수를 모두 더하면", work: String(list.reduce(0, +)))) }
            let answer = has(text, ["개수", "몇 개"]) ? "\(count)개" : has(text, ["합"]) ? "약수의 합 \(list.reduce(0, +))" : (list.count <= 40 ? list.map(String.init).joined(separator: ", ") + " (\(count)개)" : "\(count)개")
            return Solved(kind: .numberTheory, topic: "약수", concept: "n = pᵃ × qᵇ 이면 약수의 개수는 (a+1)(b+1)개예요.", steps: steps, answer: answer)
        }
        if has(text, ["소수야", "소수인지", "소수니", "소수 맞", "소수 판별", "소수예요", "소수입니까", "소수인가"]) {
            let factors = primeFactors(n)
            let isPrime = n >= 2 && factors.count == 1 && factors[0].1 == 1
            return Solved(kind: .numberTheory, topic: "소수 판별", concept: "1과 자기 자신만을 약수로 가지는 1보다 큰 자연수가 소수예요. √n 이하의 소수로 나눠보면 돼요.",
                          steps: [SolutionStep(hint: "√\(n) ≈ \(DoitMath.format(Double(n).squareRoot(), digits: 4)) 이하의 소수로 나눠보면", work: isPrime ? "나누어떨어지는 수가 없어요" : "\(n) = \(factorText(factors))")],
                          answer: isPrime ? "\(n)은 소수예요" : "\(n)은 소수가 아니에요")
        }
        return nil
    }

    // MARK: - 6. 백분율 · 비율

    static func percent(_ text: String) -> Solved? {
        let t = text.replacingOccurrences(of: ",", with: "")
        guard t.contains("%") || has(t, ["퍼센트", "프로", "할인", "할푼리", "비율", "증가율", "감소율"]) else { return nil }
        let values = numbers(in: t)
        if let m = t.firstMatch(of: #/(\d+(?:\.\d+)?)\s*(?:원|개|명|점|kg|g|L|m)?\s*(?:의|에서|을|를)\s*(\d+(?:\.\d+)?)\s*(?:%|퍼센트|프로)/#), let a = Double(String(m.1)), let p = Double(String(m.2)) {
            let part = a * p / 100
            if has(t, ["할인"]) {
                return Solved(kind: .percent, topic: "할인 가격", concept: "할인 가격 = 원래 가격 × (1 − 할인율)",
                              steps: [SolutionStep(hint: "할인 금액", work: "\(DoitMath.format(a)) × \(DoitMath.format(p))/100 = \(DoitMath.format(part))"),
                                      SolutionStep(hint: "원래 가격에서 빼면", work: "\(DoitMath.format(a)) − \(DoitMath.format(part))")],
                              answer: DoitMath.format(a - part))
            }
            if has(t, ["증가", "인상", "올리"]) {
                return Solved(kind: .percent, topic: "증가한 값", concept: "증가한 값 = 원래 값 × (1 + 증가율)",
                              steps: [SolutionStep(hint: "늘어난 양", work: DoitMath.format(part))], answer: DoitMath.format(a + part))
            }
            return Solved(kind: .percent, topic: "백분율", concept: "A의 p% = A × p/100",
                          steps: [SolutionStep(hint: "A × p ÷ 100", work: "\(DoitMath.format(a)) × \(DoitMath.format(p)) ÷ 100")], answer: DoitMath.format(part))
        }
        if let m = t.firstMatch(of: #/(\d+(?:\.\d+)?)\s*(?:은|는|이|가)?\s*(\d+(?:\.\d+)?)\s*의\s*몇\s*(?:%|퍼센트|프로)/#), let a = Double(String(m.1)), let b = Double(String(m.2)), b != 0 {
            return Solved(kind: .percent, topic: "비율을 백분율로", concept: "백분율 = (비교하는 양 ÷ 기준량) × 100",
                          steps: [SolutionStep(hint: "\(DoitMath.format(a)) ÷ \(DoitMath.format(b)) × 100", work: DoitMath.format(a / b * 100, digits: 6))],
                          answer: DoitMath.format(a / b * 100, digits: 6) + "%")
        }
        if has(t, ["증가율", "감소율", "변화율", "몇 % 증가", "몇 % 감소", "몇 퍼센트 증가", "몇 퍼센트 감소"]), values.count >= 2, values[0] != 0 {
            let rate = (values[1] - values[0]) / values[0] * 100
            return Solved(kind: .percent, topic: "증가율·감소율", concept: "변화율 = (나중 값 − 처음 값) ÷ 처음 값 × 100",
                          steps: [SolutionStep(hint: "(\(DoitMath.format(values[1])) − \(DoitMath.format(values[0]))) ÷ \(DoitMath.format(values[0])) × 100", work: DoitMath.format(rate, digits: 6) + "%")],
                          answer: rate >= 0 ? "\(DoitMath.format(rate, digits: 6))% 증가" : "\(DoitMath.format(-rate, digits: 6))% 감소")
        }
        return nil
    }

    // MARK: - 7. 좌표 · 직선 · 원

    struct Point { var x: Double; var y: Double; var label: String { "(\(f(x)), \(f(y)))" } }

    static func points(in text: String) -> [Point] {
        let t = DoitAlgebra.normalize(text)
        return t.matches(of: #/\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)/#).compactMap { m in
            guard let x = Double(String(m.1)), let y = Double(String(m.2)) else { return nil }
            return Point(x: x, y: y)
        }
    }

    static func coordinate(_ text: String) -> Solved? {
        let pts = points(in: text)
        let t = DoitAlgebra.normalize(text)
        // 점과 직선 사이의 거리
        if pts.count == 1, has(t, ["거리"]), let line = lineEquation(in: t) {
            let (a, b, c) = line
            let p = pts[0]
            let numerator = abs(a * p.x + b * p.y + c)
            let denominator2 = a * a + b * b
            let value = numerator / denominator2.squareRoot()
            let exact = denominator2 == denominator2.rounded() && Int(denominator2).isPerfectSquare
                ? f(value) : "\(f(numerator))/\(DoitAlgebra.sqrtText(denominator2))"
            return Solved(kind: .coordinate, topic: "점과 직선 사이의 거리", concept: "점 (x₁, y₁)과 직선 ax + by + c = 0 사이의 거리 = |ax₁ + by₁ + c| / √(a² + b²)",
                          steps: [SolutionStep(hint: "분자 |ax₁ + by₁ + c|", work: "|\(f(a))×(\(f(p.x))) + \(f(b))×(\(f(p.y))) + (\(f(c)))| = \(f(numerator))"),
                                  SolutionStep(hint: "분모 √(a² + b²)", work: DoitAlgebra.sqrtText(denominator2))],
                          answer: exact + (exact.contains("√") ? " (≈ \(DoitMath.format(value, digits: 5)))" : ""))
        }
        // 기울기와 한 점
        if pts.count == 1, has(t, ["직선", "기울기"]), let m = t.firstMatch(of: #/기울기(?:가|는)?\s*(-?\d+(?:\.\d+)?(?:/\d+)?)/#) {
            let parts = String(m.1).split(separator: "/").compactMap { Double(String($0)) }
            guard let first = parts.first else { return nil }
            let slope = parts.count == 2 && parts[1] != 0 ? first / parts[1] : first
            let p = pts[0]
            var line = DoitMath.Poly(); line.c[1] = slope; line.c[0] = p.y - slope * p.x
            let solved = Solved(kind: .coordinate, topic: "직선의 방정식", concept: "기울기 m, 점 (x₁, y₁)을 지나는 직선: y − y₁ = m(x − x₁)",
                                steps: [SolutionStep(hint: "y − y₁ = m(x − x₁)", work: "y − (\(f(p.y))) = \(f(slope))(x − (\(f(p.x))))")],
                                answer: "y = \(DoitMath.describe(line))")
            return intercept(solved, line: line, asks: t)
        }
        guard pts.count >= 2 else { return circle(t) ?? lineInfo(t) }
        let a = pts[0], b = pts[1]
        if pts.count >= 3, has(t, ["무게중심"]) {
            let c = pts[2]
            let g = Point(x: (a.x + b.x + c.x) / 3, y: (a.y + b.y + c.y) / 3)
            return Solved(kind: .coordinate, topic: "삼각형의 무게중심", concept: "무게중심 = (세 x좌표의 평균, 세 y좌표의 평균)",
                          steps: [SolutionStep(hint: "x좌표", work: "(\(f(a.x)) + \(f(b.x)) + \(f(c.x))) / 3 = \(f(g.x))"),
                                  SolutionStep(hint: "y좌표", work: "(\(f(a.y)) + \(f(b.y)) + \(f(c.y))) / 3 = \(f(g.y))")],
                          answer: g.label)
        }
        if pts.count >= 3, has(t, ["넓이", "면적"]) {
            let c = pts[2]
            let area = abs(a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y)) / 2
            return Solved(kind: .coordinate, topic: "세 점으로 이루어진 삼각형의 넓이", concept: "신발끈 공식: ½|x₁(y₂−y₃) + x₂(y₃−y₁) + x₃(y₁−y₂)|",
                          steps: [SolutionStep(hint: "신발끈 공식에 넣으면", work: "½ × |\(f(2 * area))|")], answer: f(area))
        }
        if let m = t.firstMatch(of: #/(\d+)\s*:\s*(\d+)\s*(?:으로|로)?\s*(내분|외분)/#), let mm = Double(String(m.1)), let nn = Double(String(m.2)) {
            let external = String(m.3) == "외분"
            guard !(external && mm == nn) else { return nil }
            let den = external ? mm - nn : mm + nn
            let px = external ? (mm * b.x - nn * a.x) / den : (mm * b.x + nn * a.x) / den
            let py = external ? (mm * b.y - nn * a.y) / den : (mm * b.y + nn * a.y) / den
            let formula = external ? "(mx₂ − nx₁)/(m − n)" : "(mx₂ + nx₁)/(m + n)"
            return Solved(kind: .coordinate, topic: external ? "선분의 외분점" : "선분의 내분점", concept: "\(f(mm)):\(f(nn))로 \(external ? "외분" : "내분")하는 점의 x좌표 = \(formula), y도 같은 방법",
                          steps: [SolutionStep(hint: "x좌표", work: "\(external ? "(\(f(mm))×\(f(b.x)) − \(f(nn))×\(f(a.x)))" : "(\(f(mm))×\(f(b.x)) + \(f(nn))×\(f(a.x)))") / \(f(den)) = \(f(px))"),
                                  SolutionStep(hint: "y좌표", work: "\(external ? "(\(f(mm))×\(f(b.y)) − \(f(nn))×\(f(a.y)))" : "(\(f(mm))×\(f(b.y)) + \(f(nn))×\(f(a.y)))") / \(f(den)) = \(f(py))")],
                          answer: Point(x: px, y: py).label)
        }
        if has(t, ["중점"]) {
            let mid = Point(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            return Solved(kind: .coordinate, topic: "선분의 중점", concept: "중점 = ((x₁+x₂)/2, (y₁+y₂)/2)",
                          steps: [SolutionStep(hint: "x, y좌표를 각각 평균", work: mid.label)], answer: mid.label)
        }
        if has(t, ["기울기"]) && !has(t, ["직선의 방정식"]) {
            guard b.x != a.x else { return Solved(kind: .coordinate, topic: "기울기", concept: "x좌표가 같으면 y축에 평행한 직선이에요.", steps: [], answer: "기울기가 정의되지 않아요 (x = \(f(a.x)))") }
            let s = (b.y - a.y) / (b.x - a.x)
            return Solved(kind: .coordinate, topic: "두 점을 지나는 직선의 기울기", concept: "기울기 = (y의 증가량) / (x의 증가량)",
                          steps: [SolutionStep(hint: "(y₂ − y₁)/(x₂ − x₁)", work: "(\(f(b.y)) − (\(f(a.y))))/(\(f(b.x)) − (\(f(a.x))))")], answer: f(s))
        }
        if has(t, ["직선", "방정식", "일차함수", "함수의 식", "그래프의 식"]) {
            guard b.x != a.x else {
                return Solved(kind: .coordinate, topic: "직선의 방정식", concept: "x좌표가 같은 두 점을 지나는 직선은 y축에 평행해요.", steps: [], answer: "x = \(f(a.x))")
            }
            let s = (b.y - a.y) / (b.x - a.x)
            var line = DoitMath.Poly(); line.c[1] = s; line.c[0] = a.y - s * a.x
            let solved = Solved(kind: .coordinate, topic: "두 점을 지나는 직선", concept: "기울기를 먼저 구하고, y − y₁ = m(x − x₁)에 넣어요.",
                                steps: [SolutionStep(hint: "기울기", work: "m = \(f(s))"), SolutionStep(hint: "점 \(a.label)을 지나므로", work: "y − (\(f(a.y))) = \(f(s))(x − (\(f(a.x))))")],
                                answer: "y = \(DoitMath.describe(line))")
            return intercept(solved, line: line, asks: t)
        }
        if has(t, ["거리", "길이", "AB", "선분"]) {
            let d2 = (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)
            let text = DoitAlgebra.sqrtText(d2)
            return Solved(kind: .coordinate, topic: "두 점 사이의 거리", concept: "두 점 사이의 거리 = √((x₂−x₁)² + (y₂−y₁)²)",
                          steps: [SolutionStep(hint: "x, y좌표 차이의 제곱을 더하면", work: "(\(f(b.x - a.x)))² + (\(f(b.y - a.y)))² = \(f(d2))"),
                                  SolutionStep(hint: "제곱근을 씌우면", work: "√\(f(d2)) = \(text)")],
                          answer: text + (text.contains("√") && !text.contains("≈") ? " (≈ \(DoitMath.format(d2.squareRoot(), digits: 5)))" : ""))
        }
        return nil
    }

    /// 직선을 구한 뒤 "y절편은?", "x절편은?"을 물으면 그 값으로
    private static func intercept(_ solved: Solved, line: DoitMath.Poly, asks t: String) -> Solved {
        var out = solved
        let asksY = t.range(of: #"y\s*절편(?:은|을|의\s*값|을\s*구)"#, options: .regularExpression) != nil
        let asksX = t.range(of: #"x\s*절편(?:은|을|의\s*값|을\s*구)"#, options: .regularExpression) != nil
        if asksY && !asksX {
            out.steps.append(SolutionStep(hint: "y절편은 x = 0일 때의 y값", work: f(line[0])))
            out.answer = "y절편 \(f(line[0]))"
        } else if asksX && !asksY, abs(line[1]) > 1e-12 {
            out.steps.append(SolutionStep(hint: "x절편은 y = 0일 때의 x값", work: f(-line[0] / line[1])))
            out.answer = "x절편 \(f(-line[0] / line[1]))"
        }
        return out
    }

    /// "3x + 4y − 5 = 0", "y = 2x + 1" → (a, b, c)  ax + by + c = 0
    private static func lineEquation(in text: String) -> (Double, Double, Double)? {
        for chunk in text.components(separatedBy: CharacterSet(charactersIn: ",\n")) {
            let expression = DoitAlgebra.extract(chunk)
            let sides = expression.split(separator: "=").map(String.init)
            guard sides.count == 2, let l = DoitAlgebra.parse(sides[0]), let r = DoitAlgebra.parse(sides[1]) else { continue }
            let e = l - r
            guard e.degree == 1, e.coef(y: 1) != 0 || e.coef(x: 1) != 0 else { continue }
            return (e.coef(x: 1), e.coef(y: 1), e.constantValue)
        }
        return nil
    }

    /// 원의 방정식: x² + y² + Dx + Ey + F = 0 또는 (x−a)² + (y−b)² = r² → 중심, 반지름
    private static func circle(_ t: String) -> Solved? {
        guard has(t, ["원", "중심", "반지름"]) else { return nil }
        let expression = DoitAlgebra.extract(t)
        let sides = expression.split(separator: "=").map(String.init)
        guard sides.count == 2, let l = DoitAlgebra.parse(sides[0]), let r = DoitAlgebra.parse(sides[1]) else { return nil }
        let e = l - r
        let a2 = e.coef(x: 2), b2 = e.coef(y: 2)
        guard abs(a2) > 1e-12, abs(a2 - b2) < 1e-12, abs(e.coef(x: 1, y: 1)) < 1e-12 else { return nil }
        let D = e.coef(x: 1) / a2, E = e.coef(y: 1) / a2, F = e.constantValue / a2
        let cx = -D / 2, cy = -E / 2
        let r2 = cx * cx + cy * cy - F
        guard r2 > 0 else {
            return Solved(kind: .circle, topic: "원의 방정식", concept: "(x − a)² + (y − b)² = r² 꼴로 바꿨을 때 r² > 0 이어야 원이에요.", steps: [], answer: "원이 아니에요 (r² = \(f(r2)))")
        }
        return Solved(kind: .circle, topic: "원의 방정식", concept: "x² + y² + Dx + Ey + F = 0 을 완전제곱식으로 바꾸면 (x − a)² + (y − b)² = r², 중심 (a, b), 반지름 r",
                      steps: [SolutionStep(hint: "x, y끼리 묶어 완전제곱식으로", work: "(x \(cx > 0 ? "−" : "+") \(f(abs(cx))))² + (y \(cy > 0 ? "−" : "+") \(f(abs(cy))))² = \(f(r2))")],
                      answer: "중심 \(Point(x: cx, y: cy).label), 반지름 \(DoitAlgebra.sqrtText(r2))")
    }

    /// 직선 하나: 기울기, 절편
    private static func lineInfo(_ t: String) -> Solved? {
        guard has(t, ["기울기", "절편"]), let (a, b, c) = lineEquation(in: t), b != 0 else { return nil }
        let slope = -a / b, yIntercept = -c / b
        let xIntercept = a != 0 ? f(-c / a) : "없음"
        return Solved(kind: .coordinate, topic: "직선의 기울기와 절편", concept: "y = mx + n 꼴로 바꾸면 m이 기울기, n이 y절편이에요.",
                      steps: [SolutionStep(hint: "y에 대해 정리하면", work: "y = \(f(slope))x + (\(f(yIntercept)))")],
                      answer: "기울기 \(f(slope)), y절편 \(f(yIntercept)), x절편 \(xIntercept)")
    }

    // MARK: - 8. 도형 공식

    static func geometry(_ text: String) -> Solved? {
        // 넓이·부피 단위의 ²·³ (cm², cm^3)는 수로 세지 않음
        var t = text.replacingOccurrences(of: #"(cm|mm|km|m)\s*\^\s*[23]|㎠|㎤|cm²|cm³|m²|m³"#, with: "$1", options: .regularExpression)
        // 원주율이 주어지면 그 값으로 계산 ("원주율은 3.14")
        var piValue: Double?
        if let m = t.firstMatch(of: #/원주율(?:은|는|을|를)?\s*(3(?:\.\d+)?)/#), let v = Double(String(m.1)) {
            piValue = v
            t = t.replacingOccurrences(of: String(m.0), with: " ")
        }
        t = t.replacingOccurrences(of: "원주율", with: " ")
        // 한글 수 + 각형: 육각형 → 6각형 (다각형 판별에만 씀. 정사각형·직사각형 판별은 원래 글자로)
        var polygonText = t
        let koreanNumbers = [("십이", 12), ("십", 10), ("구", 9), ("팔", 8), ("칠", 7), ("육", 6), ("오", 5), ("사", 4), ("삼", 3)]
        for (word, n) in koreanNumbers { polygonText = polygonText.replacingOccurrences(of: word + "각형", with: "\(n)각형") }
        let v = numbers(in: t).filter { $0 > 0 }
        guard !v.isEmpty else { return polygon(polygonText, t) }
        func piText(_ k: Double) -> String {
            if let p = piValue { return DoitMath.format(k * p, digits: 8) }
            let coefficient = abs(k - 1) < 1e-12 ? "" : f(k)
            return "\(coefficient.contains("/") ? "(\(coefficient))" : coefficient)π (≈ \(DoitMath.format(k * .pi, digits: 6)))"
        }
        let piName = piValue.map { DoitMath.format($0) } ?? "π"
        func step(_ hint: String, _ work: String) -> [SolutionStep] { [SolutionStep(hint: hint, work: work)] }
        let r = v[0]
        // 반지름/지름
        let radius = has(t, ["지름"]) && !has(t, ["반지름"]) ? r / 2 : r
        // 원주각·중심각(각의 크기) 문제의 "원주"는 원의 둘레가 아님
        if has(t, ["원"]) && !has(t, ["원기둥", "원뿔", "원의 방정식", "원순열", "원형", "원짜리", "원가", "원에", "원을 냈", "원주각", "중심각", "∠"]) && has(t, ["넓이", "둘레", "원주", "면적"]) {
            if has(t, ["둘레", "원주"]) {
                return Solved(kind: .geometry, topic: "원의 둘레", concept: "원의 둘레 = 2πr = 지름 × π", steps: step("반지름 r = \(f(radius))", "2 × \(piName) × \(f(radius))"), answer: piText(2 * radius))
            }
            return Solved(kind: .geometry, topic: "원의 넓이", concept: "원의 넓이 = πr²", steps: step("반지름 r = \(f(radius))", "\(piName) × \(f(radius))²"), answer: piText(radius * radius))
        }
        if has(t, ["부채꼴"]), v.count >= 2 {
            let angle = v[1]
            if has(t, ["호", "길이"]) && !has(t, ["넓이"]) {
                return Solved(kind: .geometry, topic: "부채꼴의 호의 길이", concept: "호의 길이 = 2πr × (중심각/360°)", steps: step("2π × \(f(r)) × \(f(angle))/360", f(2 * r * angle / 360) + "π"), answer: piText(2 * r * angle / 360))
            }
            return Solved(kind: .geometry, topic: "부채꼴의 넓이", concept: "부채꼴의 넓이 = πr² × (중심각/360°)", steps: step("π × \(f(r))² × \(f(angle))/360", f(r * r * angle / 360) + "π"), answer: piText(r * r * angle / 360))
        }
        if has(t, ["구"]) && !has(t, ["구해", "구하", "구간", "구성", "각형"]) || has(t, ["구의"]) {
            if has(t, ["겉넓이", "표면적"]) { return Solved(kind: .geometry, topic: "구의 겉넓이", concept: "구의 겉넓이 = 4πr²", steps: step("4π × \(f(radius))²", f(4 * radius * radius) + "π"), answer: piText(4 * radius * radius)) }
            if has(t, ["부피"]) { return Solved(kind: .geometry, topic: "구의 부피", concept: "구의 부피 = (4/3)πr³", steps: step("(4/3)π × \(f(radius))³", f(4 * pow(radius, 3) / 3) + "π"), answer: piText(4 * pow(radius, 3) / 3)) }
        }
        if has(t, ["원기둥"]), v.count >= 2 {
            let h = v[1]
            if has(t, ["겉넓이"]) { return Solved(kind: .geometry, topic: "원기둥의 겉넓이", concept: "겉넓이 = 2πr² + 2πrh", steps: step("밑넓이×2 + 옆넓이", "2π×\(f(radius))² + 2π×\(f(radius))×\(f(h))"), answer: piText(2 * radius * radius + 2 * radius * h)) }
            return Solved(kind: .geometry, topic: "원기둥의 부피", concept: "부피 = 밑넓이 × 높이 = πr²h", steps: step("밑넓이 × 높이", "π×\(f(radius))²×\(f(h))"), answer: piText(radius * radius * h))
        }
        if has(t, ["원뿔"]), v.count >= 2 {
            let h = v[1]
            return Solved(kind: .geometry, topic: "원뿔의 부피", concept: "부피 = (1/3)πr²h", steps: step("(1/3) × 밑넓이 × 높이", "(1/3)π×\(f(radius))²×\(f(h))"), answer: piText(radius * radius * h / 3))
        }
        if has(t, ["빗변", "피타고라스"]), v.count >= 2 {
            let a = v[0], b = v[1]
            if has(t, ["빗변이", "빗변의 길이가", "빗변 길이가"]) || (has(t, ["빗변"]) && has(t, ["나머지", "다른 한 변"])) {
                let hyp = max(a, b), leg = min(a, b)
                let other = hyp * hyp - leg * leg
                return Solved(kind: .geometry, topic: "피타고라스 정리", concept: "직각삼각형에서 a² + b² = c² (c는 빗변)",
                              steps: [SolutionStep(hint: "c² − a²", work: "\(f(hyp))² − \(f(leg))² = \(f(other))"), SolutionStep(hint: "제곱근", work: "√\(f(other)) = \(DoitAlgebra.sqrtText(other))")], answer: DoitAlgebra.sqrtText(other))
            }
            let c2 = a * a + b * b
            return Solved(kind: .geometry, topic: "피타고라스 정리", concept: "직각삼각형에서 a² + b² = c² (c는 빗변)",
                          steps: [SolutionStep(hint: "a² + b²", work: "\(f(a))² + \(f(b))² = \(f(c2))"), SolutionStep(hint: "제곱근", work: "√\(f(c2)) = \(DoitAlgebra.sqrtText(c2))")], answer: "빗변 " + DoitAlgebra.sqrtText(c2))
        }
        if has(t, ["정삼각형"]) && has(t, ["넓이", "높이"]) {
            let a = v[0]
            if has(t, ["높이"]) && !has(t, ["넓이"]) { return Solved(kind: .geometry, topic: "정삼각형의 높이", concept: "높이 = (√3/2)a", steps: step("(√3/2) × \(f(a))", "\(f(a / 2))√3"), answer: "\(f(a / 2))√3") }
            return Solved(kind: .geometry, topic: "정삼각형의 넓이", concept: "넓이 = (√3/4)a²", steps: step("(√3/4) × \(f(a))²", "\(f(a * a / 4))√3"), answer: "\(f(a * a / 4))√3 (≈ \(DoitMath.format(a * a * 3.squareRoot() / 4, digits: 6)))")
        }
        if has(t, ["삼각형"]) && !has(t, ["정삼각형", "직각삼각형"]) && has(t, ["넓이"]) && v.count == 2 && !has(t, ["("]) {
            return Solved(kind: .geometry, topic: "삼각형의 넓이", concept: "삼각형의 넓이 = 밑변 × 높이 ÷ 2", steps: step("\(f(v[0])) × \(f(v[1])) ÷ 2", f(v[0] * v[1] / 2)), answer: f(v[0] * v[1] / 2))
        }
        if has(t, ["사다리꼴"]) && v.count == 3 {
            return Solved(kind: .geometry, topic: "사다리꼴의 넓이", concept: "(윗변 + 아랫변) × 높이 ÷ 2", steps: step("(\(f(v[0])) + \(f(v[1]))) × \(f(v[2])) ÷ 2", f((v[0] + v[1]) * v[2] / 2)), answer: f((v[0] + v[1]) * v[2] / 2))
        }
        if has(t, ["마름모"]) && v.count == 2 {
            return Solved(kind: .geometry, topic: "마름모의 넓이", concept: "두 대각선의 곱 ÷ 2", steps: step("\(f(v[0])) × \(f(v[1])) ÷ 2", f(v[0] * v[1] / 2)), answer: f(v[0] * v[1] / 2))
        }
        if has(t, ["평행사변형"]) && has(t, ["넓이"]) && v.count == 2 {
            return Solved(kind: .geometry, topic: "평행사변형의 넓이", concept: "밑변 × 높이", steps: step("\(f(v[0])) × \(f(v[1]))", f(v[0] * v[1])), answer: f(v[0] * v[1]))
        }
        if has(t, ["직육면체"]) && v.count == 3 {
            if has(t, ["대각선"]) {
                let d2 = v[0] * v[0] + v[1] * v[1] + v[2] * v[2]
                return Solved(kind: .geometry, topic: "직육면체의 대각선", concept: "가로 a, 세로 b, 높이 c인 직육면체의 대각선 = √(a² + b² + c²)",
                              steps: step("√(\(f(v[0]))² + \(f(v[1]))² + \(f(v[2]))²)", "√\(f(d2)) = \(DoitAlgebra.sqrtText(d2))"), answer: DoitAlgebra.sqrtText(d2))
            }
            if has(t, ["겉넓이"]) {
                let area = 2 * (v[0] * v[1] + v[1] * v[2] + v[2] * v[0])
                return Solved(kind: .geometry, topic: "직육면체의 겉넓이", concept: "2(ab + bc + ca) (서로 다른 세 면의 넓이의 합 × 2)", steps: step("2 × (\(f(v[0]))×\(f(v[1])) + \(f(v[1]))×\(f(v[2])) + \(f(v[2]))×\(f(v[0])))", f(area)), answer: f(area))
            }
            return Solved(kind: .geometry, topic: "직육면체의 부피", concept: "가로 × 세로 × 높이", steps: step("\(f(v[0])) × \(f(v[1])) × \(f(v[2]))", f(v[0] * v[1] * v[2])), answer: f(v[0] * v[1] * v[2]))
        }
        if has(t, ["정육면체"]) && v.count == 1 {
            if has(t, ["대각선"]) { return Solved(kind: .geometry, topic: "정육면체의 대각선", concept: "한 모서리가 a인 정육면체의 대각선 = √3 a", steps: step("√(\(f(r))² × 3)", "√\(f(3 * r * r))"), answer: DoitAlgebra.sqrtText(3 * r * r)) }
            if has(t, ["겉넓이"]) { return Solved(kind: .geometry, topic: "정육면체의 겉넓이", concept: "한 면의 넓이 × 6 = 6a²", steps: step("\(f(r)) × \(f(r)) × 6", f(6 * r * r)), answer: f(6 * r * r)) }
            return Solved(kind: .geometry, topic: "정육면체의 부피", concept: "a³", steps: step("\(f(r)) × \(f(r)) × \(f(r))", f(r * r * r)), answer: f(r * r * r))
        }
        // "가로가 세로보다 3cm 긴 직사각형의 둘레가 26cm일 때"처럼 길이 사이의 관계가 주어진 것은 방정식 (여기서 곱하면 틀려요)
        if has(t, ["직사각형"]) && v.count == 2 && !has(t, ["보다", "배인", "배이고", "배가"]) {
            if has(t, ["대각선"]) { let d2 = v[0] * v[0] + v[1] * v[1]; return Solved(kind: .geometry, topic: "직사각형의 대각선", concept: "대각선 = √(가로² + 세로²)", steps: step("√(\(f(v[0]))² + \(f(v[1]))²)", "√\(f(d2))"), answer: DoitAlgebra.sqrtText(d2)) }
            if has(t, ["둘레"]) { return Solved(kind: .geometry, topic: "직사각형의 둘레", concept: "2 × (가로 + 세로)", steps: step("2 × (\(f(v[0])) + \(f(v[1])))", f(2 * (v[0] + v[1]))), answer: f(2 * (v[0] + v[1]))) }
            return Solved(kind: .geometry, topic: "직사각형의 넓이", concept: "가로 × 세로", steps: step("\(f(v[0])) × \(f(v[1]))", f(v[0] * v[1])), answer: f(v[0] * v[1]))
        }
        if has(t, ["정사각형"]) && v.count == 1 && !has(t, ["넓이가", "둘레가", "둘레의 길이가"]) {
            if has(t, ["대각선"]) { return Solved(kind: .geometry, topic: "정사각형의 대각선", concept: "한 변이 a일 때 대각선 = √2 a", steps: step("√(\(f(r))² + \(f(r))²)", "√\(f(2 * r * r))"), answer: "\(f(r))√2") }
            if has(t, ["둘레"]) { return Solved(kind: .geometry, topic: "정사각형의 둘레", concept: "4a", steps: step("4 × \(f(r))", f(4 * r)), answer: f(4 * r)) }
            return Solved(kind: .geometry, topic: "정사각형의 넓이", concept: "a²", steps: step("\(f(r)) × \(f(r))", f(r * r)), answer: f(r * r))
        }
        return polygon(polygonText, t)
    }

    /// n각형의 대각선 개수, 내각의 합, 정다각형의 한 내각·외각
    private static func polygon(_ polygonText: String, _ t: String) -> Solved? {
        func step(_ hint: String, _ work: String) -> [SolutionStep] { [SolutionStep(hint: hint, work: work)] }
        if let m = polygonText.firstMatch(of: #/(정)?(\d+)\s*각형/#), let n = Int(String(m.2)), n >= 3 {
            let regular = m.1 != nil
            if has(t, ["대각선"]) && !has(t, ["대각선의 길이", "대각선 길이"]) {
                return Solved(kind: .geometry, topic: "다각형의 대각선 개수", concept: "n각형의 대각선 개수 = n(n − 3)/2", steps: step("\(n)(\(n) − 3)/2", "\(n * (n - 3) / 2)"), answer: "\(n * (n - 3) / 2)개")
            }
            if has(t, ["내각"]) && has(t, ["합"]) {
                return Solved(kind: .geometry, topic: "다각형의 내각의 합", concept: "n각형의 내각의 합 = 180° × (n − 2)", steps: step("180° × (\(n) − 2)", "\(180 * (n - 2))°"), answer: "\(180 * (n - 2))°")
            }
            if has(t, ["외각"]) && has(t, ["합"]) {
                return Solved(kind: .geometry, topic: "다각형의 외각의 합", concept: "다각형의 외각의 합은 항상 360°", steps: step("외각의 합", "360°"), answer: "360°")
            }
            if regular && has(t, ["한 내각", "내각의 크기"]) {
                let one = Double(180 * (n - 2)) / Double(n)
                return Solved(kind: .geometry, topic: "정다각형의 한 내각", concept: "정n각형의 한 내각 = 180° × (n − 2) / n",
                              steps: [SolutionStep(hint: "내각의 합 = 180° × (\(n) − 2)", work: "\(180 * (n - 2))°"), SolutionStep(hint: "\(n)으로 나누면", work: "\(f(one))°")], answer: "\(f(one))°")
            }
            if regular && has(t, ["외각"]) {
                return Solved(kind: .geometry, topic: "정다각형의 한 외각", concept: "외각의 합은 항상 360°, 정n각형의 한 외각 = 360°/n", steps: step("360° ÷ \(n)", "\(f(360 / Double(n)))°"), answer: "\(f(360 / Double(n)))°")
            }
        }
        return nil
    }

    // MARK: - 9. 수열

    static func sequence(_ text: String) -> Solved? {
        let t = text.replacingOccurrences(of: ",", with: " , ")
        // 1부터 100까지 합
        if let m = t.firstMatch(of: #/(-?\d+)\s*부터\s*(-?\d+)\s*까지\s*(?:의\s*)?(?:자연수의\s*|정수의\s*|수의\s*)?(?:합|더하)/#),
           let a = Int(String(m.1)), let b = Int(String(m.2)), b >= a {
            let count = b - a + 1
            let sum = (a + b) * count / 2
            return Solved(kind: .sequence, topic: "연속한 수의 합", concept: "등차수열의 합 = (첫째항 + 끝항) × 항의 개수 ÷ 2",
                          steps: [SolutionStep(hint: "(\(a) + \(b)) × \(count) ÷ 2", work: String(sum))], answer: String(sum))
        }
        guard has(t, ["수열", "첫째항", "공차", "공비", "번째 항", "번째항", "일반항"]) || t.range(of: #"제\s*\d+\s*항"#, options: .regularExpression) != nil else { return nil }
        func value(after word: String) -> Double? {
            guard let range = t.range(of: "\(word)\\s*(?:이|가|은|는|:|=)?\\s*(-?\\d+(?:\\.\\d+)?(?:/\\d+)?)", options: .regularExpression) else { return nil }
            let part = String(t[range]).replacingOccurrences(of: word, with: "")
            let nums = part.split(whereSeparator: { !($0.isNumber || $0 == "." || $0 == "-" || $0 == "/") }).first.map(String.init) ?? ""
            let pieces = nums.split(separator: "/").compactMap { Double(String($0)) }
            if pieces.count == 2, pieces[1] != 0 { return pieces[0] / pieces[1] }
            return pieces.first
        }
        var nth: Int?
        if let m = t.firstMatch(of: #/(?:제\s*)?(\d+)\s*(?:번째\s*)?항/#) { nth = Int(String(m.1)) }
        let wantsSum = has(t, ["합", "까지 더"])
        // 첫째항/공차/공비가 없으면 나열된 수에서 찾기: "2, 5, 8, 11, …"
        var a1 = value(after: "첫째항")
        var d = value(after: "공차")
        var r = value(after: "공비")
        if a1 == nil, let listed = t.firstMatch(of: #/(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/#),
           let x1 = Double(String(listed.1)), let x2 = Double(String(listed.2)), let x3 = Double(String(listed.3)) {
            a1 = x1
            if abs((x2 - x1) - (x3 - x2)) < 1e-12 { d = x2 - x1 }
            else if x1 != 0, x2 != 0, abs(x2 / x1 - x3 / x2) < 1e-12 { r = x2 / x1 }
        }
        // 일반항: aₙ = dn + (a − d), aₙ = a·rⁿ⁻¹
        if let a = a1, nth == nil, has(t, ["일반항"]) {
            if let d {
                var general = DoitMath.Poly(); general.c[1] = d; general.c[0] = a - d
                let formula = "aₙ = " + DoitMath.describe(general).replacingOccurrences(of: "x", with: "n")
                return Solved(kind: .sequence, topic: "등차수열의 일반항", concept: "첫째항 a, 공차 d인 등차수열: aₙ = a + (n − 1)d",
                              steps: [SolutionStep(hint: "aₙ = a + (n − 1)d 에 넣으면", work: "\(f(a)) + (n − 1) × \(f(d))"), SolutionStep(hint: "정리하면", work: formula)], answer: formula)
            }
            if let r {
                let formula = "aₙ = \(f(a) == "1" ? "" : f(a) + " × ")\(r < 0 ? "(\(f(r)))" : f(r))ⁿ⁻¹"
                return Solved(kind: .sequence, topic: "등비수열의 일반항", concept: "첫째항 a, 공비 r인 등비수열: aₙ = arⁿ⁻¹",
                              steps: [SolutionStep(hint: "aₙ = arⁿ⁻¹ 에 넣으면", work: formula)], answer: formula)
            }
        }
        // "50은 제몇 항인가?"
        if let a = a1, let m = t.firstMatch(of: #/(-?\d+(?:\.\d+)?)\s*(?:은|는|이|가)\s*제\s*몇\s*(?:번째\s*)?항/#), let target = Double(String(m.1)) {
            if let d, d != 0 {
                let k = (target - a) / d + 1
                guard k >= 1, abs(k - k.rounded()) < 1e-9 else { return nil }
                return Solved(kind: .sequence, topic: "등차수열", concept: "aₙ = a + (n − 1)d 에 값을 넣어 n을 구해요.",
                              steps: [SolutionStep(hint: "aₙ = \(f(a)) + (n − 1) × \(f(d)) = \(f(target))", work: "n − 1 = \(f(k - 1))"), SolutionStep(hint: "n을 구하면", work: "n = \(DoitMath.safeInt(k))")],
                              answer: "제\(DoitMath.safeInt(k))항")
            }
            if let r, abs(r) > 1, a != 0 {
                var value = a, k = 1
                while abs(value) < abs(target) - 1e-9 && k < 200 { value *= r; k += 1 }
                guard abs(value - target) < 1e-9 else { return nil }
                return Solved(kind: .sequence, topic: "등비수열", concept: "aₙ = arⁿ⁻¹ 에 값을 넣어 n을 구해요.",
                              steps: [SolutionStep(hint: "\(f(a)) × \(f(r))ⁿ⁻¹ = \(f(target))", work: "\(f(r))ⁿ⁻¹ = \(f(target / a)) → n = \(k)")], answer: "제\(k)항")
            }
        }
        guard let a = a1, let n = nth, n >= 1, n <= 10000 else { return nil }
        if let d {
            let an = a + Double(n - 1) * d
            let sum = Double(n) * (2 * a + Double(n - 1) * d) / 2
            var steps = [SolutionStep(hint: "등차수열의 일반항 aₙ = a + (n − 1)d", work: "a\(n) = \(f(a)) + (\(n) − 1) × \(f(d)) = \(f(an))")]
            if wantsSum { steps.append(SolutionStep(hint: "합 Sₙ = n(2a + (n − 1)d)/2", work: "S\(n) = \(n)(2×\(f(a)) + \(n - 1)×\(f(d)))/2 = \(f(sum))")) }
            return Solved(kind: .sequence, topic: "등차수열", concept: "첫째항 a, 공차 d인 등차수열: aₙ = a + (n − 1)d, Sₙ = n{2a + (n − 1)d}/2",
                          steps: steps, answer: wantsSum ? "첫째항부터 제\(n)항까지의 합 \(f(sum))" : "제\(n)항 \(f(an))")
        }
        if let r {
            let an = a * pow(r, Double(n - 1))
            let sum = abs(r - 1) < 1e-12 ? a * Double(n) : a * (pow(r, Double(n)) - 1) / (r - 1)
            var steps = [SolutionStep(hint: "등비수열의 일반항 aₙ = a × rⁿ⁻¹", work: "a\(n) = \(f(a)) × \(f(r))^\(n - 1) = \(DoitMath.format(an, digits: 12))")]
            if wantsSum { steps.append(SolutionStep(hint: "합 Sₙ = a(rⁿ − 1)/(r − 1)", work: "S\(n) = \(DoitMath.format(sum, digits: 12))")) }
            return Solved(kind: .sequence, topic: "등비수열", concept: "첫째항 a, 공비 r인 등비수열: aₙ = arⁿ⁻¹, Sₙ = a(rⁿ − 1)/(r − 1) (r ≠ 1)",
                          steps: steps, answer: wantsSum ? "합 \(DoitMath.format(sum, digits: 12))" : "제\(n)항 \(DoitMath.format(an, digits: 12))")
        }
        return nil
    }

    // MARK: - 10. 집합의 원소 개수

    static func sets(_ text: String) -> Solved? {
        let t = DoitAlgebra.normalize(text).replacingOccurrences(of: " ", with: "")
        guard t.contains("n(") else { return nil }
        var known: [String: Double] = [:]
        for m in t.matches(of: #/n\(([^)]+)\)=(\d+)/#) { known[String(m.1)] = Double(String(m.2)) }
        let unionKeys = ["A∪B", "AUB", "A∪B"], interKeys = ["A∩B", "AnB"]
        func get(_ keys: [String]) -> Double? { keys.compactMap { known[$0] }.first }
        let a = known["A"], b = known["B"], union = get(unionKeys), inter = get(interKeys)
        let concept = "n(A∪B) = n(A) + n(B) − n(A∩B)"
        if let a, let b, let inter, union == nil {
            return Solved(kind: .sets, topic: "합집합의 원소 개수", concept: concept, steps: [SolutionStep(hint: "\(f(a)) + \(f(b)) − \(f(inter))", work: "")], answer: "n(A∪B) = \(f(a + b - inter))")
        }
        if let a, let b, let union, inter == nil {
            return Solved(kind: .sets, topic: "교집합의 원소 개수", concept: concept, steps: [SolutionStep(hint: "\(f(a)) + \(f(b)) − \(f(union))", work: "")], answer: "n(A∩B) = \(f(a + b - union))")
        }
        if let union, let inter {
            if let a, b == nil { return Solved(kind: .sets, topic: "집합의 원소 개수", concept: concept, steps: [], answer: "n(B) = \(f(union - a + inter))") }
            if let b, a == nil { return Solved(kind: .sets, topic: "집합의 원소 개수", concept: concept, steps: [], answer: "n(A) = \(f(union - b + inter))") }
        }
        if let u = known["U"], let a, has(t, ["여집합", "A^c", "Aᶜ", "A^C"]) {
            return Solved(kind: .sets, topic: "여집합의 원소 개수", concept: "n(Aᶜ) = n(U) − n(A)", steps: [], answer: "n(Aᶜ) = \(f(u - a))")
        }
        if let a, let b, let inter, let union {
            _ = union
            return Solved(kind: .sets, topic: "차집합의 원소 개수", concept: "n(A − B) = n(A) − n(A∩B)", steps: [], answer: "n(A−B) = \(f(a - inter)), n(B−A) = \(f(b - inter))")
        }
        return nil
    }

    // MARK: - 11. 유리함수 · 무리함수 · 산술기하평균

    static func functionGraph(_ text: String) -> Solved? {
        let t = DoitAlgebra.normalize(text).replacingOccurrences(of: " ", with: "")
        // y = k/(x − p) + q
        if let m = t.firstMatch(of: #/y=(-?\d*)/\(x([+-]\d+(?:\.\d+)?)?\)([+-]\d+(?:\.\d+)?)?/#) {
            let k = String(m.1).isEmpty ? 1 : (String(m.1) == "-" ? -1 : Double(String(m.1)) ?? 1)
            let p = -(Double(String(m.2 ?? "0")) ?? 0)
            let q = Double(String(m.3 ?? "0")) ?? 0
            return Solved(kind: .function, topic: "유리함수의 그래프", concept: "y = k/(x − p) + q 는 y = k/x 를 x축으로 p, y축으로 q만큼 평행이동한 그래프예요. 점근선은 x = p, y = q.",
                          steps: [SolutionStep(hint: "k, p, q는?", work: "k = \(f(k)), p = \(f(p)), q = \(f(q))"),
                                  SolutionStep(hint: "정의역과 치역", work: "정의역: x ≠ \(f(p))인 실수, 치역: y ≠ \(f(q))인 실수")],
                          answer: "점근선 x = \(f(p)), y = \(f(q))")
        }
        // y = (ax + b)/(cx + d)
        if let m = t.firstMatch(of: #/y=\((-?\d*)x([+-]\d+)?\)/\((-?\d*)x([+-]\d+)?\)/#) {
            func coef(_ s: Substring) -> Double { s.isEmpty ? 1 : (s == "-" ? -1 : Double(String(s)) ?? 1) }
            let a = coef(m.1), b = Double(String(m.2 ?? "0")) ?? 0, c = coef(m.3), d = Double(String(m.4 ?? "0")) ?? 0
            guard c != 0 else { return nil }
            return Solved(kind: .function, topic: "유리함수의 점근선", concept: "y = (ax + b)/(cx + d)의 점근선은 x = −d/c, y = a/c 예요.",
                          steps: [SolutionStep(hint: "분모가 0이 되는 x", work: "x = \(f(-d / c))"), SolutionStep(hint: "x의 계수의 비", work: "y = \(f(a / c))")],
                          answer: "점근선 x = \(f(-d / c)), y = \(f(a / c))")
        }
        // y = √(ax + b) + c
        if let m = t.firstMatch(of: #/y=(-?\d*)√\(?(-?\d*)x([+-]\d+)?\)?([+-]\d+)?/#) {
            let outer = String(m.1).isEmpty ? 1 : (String(m.1) == "-" ? -1 : Double(String(m.1)) ?? 1)
            let a = String(m.2).isEmpty ? 1 : (String(m.2) == "-" ? -1 : Double(String(m.2)) ?? 1)
            let b = Double(String(m.3 ?? "0")) ?? 0, c = Double(String(m.4 ?? "0")) ?? 0
            let start = -b / a
            let domain = a > 0 ? "x ≥ \(f(start))" : "x ≤ \(f(start))"
            let range = outer > 0 ? "y ≥ \(f(c))" : "y ≤ \(f(c))"
            return Solved(kind: .function, topic: "무리함수의 그래프", concept: "y = √(ax + b) + c 는 근호 안이 0 이상인 x에서 정의되고, 시작점은 (−b/a, c)예요.",
                          steps: [SolutionStep(hint: "근호 안 ≥ 0", work: "\(f(a))x + (\(f(b))) ≥ 0 → \(domain)"), SolutionStep(hint: "시작점", work: Point(x: start, y: c).label)],
                          answer: "정의역 \(domain), 치역 \(range)")
        }
        // 산술·기하평균: x > 0 일 때 ax + b/x 의 최솟값
        if t.contains("최솟값") || t.contains("최소"), let m = t.firstMatch(of: #/(\d*)x\+(\d+)/x/#) ?? t.firstMatch(of: #/(\d*)x\+(\d+)/\(x\)/#) {
            let a = String(m.1).isEmpty ? 1 : Double(String(m.1)) ?? 1
            let b = Double(String(m.2)) ?? 1
            let minValue = 2 * (a * b).squareRoot()
            let at = (b / a).squareRoot()
            return Solved(kind: .function, topic: "산술평균과 기하평균의 관계", concept: "a > 0, b > 0 일 때 a + b ≥ 2√(ab) (등호는 a = b일 때)",
                          steps: [SolutionStep(hint: "\(f(a))x > 0, \(f(b))/x > 0 이므로", work: "\(f(a))x + \(f(b))/x ≥ 2√(\(f(a))x × \(f(b))/x) = 2√\(f(a * b))"),
                                  SolutionStep(hint: "등호 조건", work: "\(f(a))x = \(f(b))/x → x = \(DoitAlgebra.sqrtText(b / a))")],
                          answer: "최솟값 \(DoitAlgebra.sqrtText(minValue * minValue / 4) == DoitAlgebra.sqrtText(a * b) ? (minValue == minValue.rounded() ? f(minValue) : "2" + DoitAlgebra.sqrtText(a * b)) : f(minValue)) (x = \(at == at.rounded() ? f(at) : DoitAlgebra.sqrtText(b / a))일 때)")
        }
        return nil
    }
}

private extension Int {
    var isPerfectSquare: Bool {
        guard self >= 0 else { return false }
        let r = Int(Double(self).squareRoot().rounded())
        return r * r == self
    }
}
