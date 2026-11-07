import Foundation

/// 모티 AI 수학 풀이: 고등 수학Ⅰ·Ⅱ·미적분 (외부 AI 없이 직접 계산)
/// - 극한 (근호·삼각·지수·로그, x → ∞, n → ∞), 급수
/// - 미분계수 · 접선 (초월함수), 닫힌구간의 최대·최소, 극값의 합, 증가 조건, 평균변화율, 속도·가속도·움직인 거리
/// - 정적분 (절댓값·초월함수), 직선 하나로 둘러싸인 넓이, f'(x)와 f(a)로 f(b)
/// - 수열: 점화식, Sₙ으로 aₙ, 처음으로 넘는 항, ∑ (분수 식), 세 근의 합(근과 계수), 모든 해의 합
/// - 삼각함수: 주기·최대·최소, sin θ + cos θ = k, 호도법 부채꼴
/// 모양이 분명하고 계산으로 확인되는 것만 풀어요. 애매하면 nil (틀린 답보다 못 푼 게 나아요)
enum DoitMathHigh {
    typealias Solved = MathSolver.Solved
    typealias Node = DoitMathCalc.Node
    typealias Rat = DoitMathExact.Rat

    static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }
    static func match(_ t: String, _ p: String) -> [String]? { DoitMathExact.match(t, p) }
    static func matches(_ t: String, _ p: String) -> [[String]] { DoitMathExact.matches(t, p) }
    static func step(_ hint: String, _ work: String) -> SolutionStep { SolutionStep(hint: hint, work: work) }

    /// 수 하나 ("3", "-1/2", "π/3", "√2", "e", "2π")
    static func number(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, let n = DoitMathCalc.parse(t, variable: "#"), !n.hasVariable else { return nil }
        return n.eval(0)
    }

    /// 문제 글에 맞는 깔끔한 값 (못 찾으면 nil)
    static func show(_ v: Double, _ text: String, tol: Double = 1e-9, maxDen: Int = 60) -> String? {
        DoitMathCalc.nice(v, allow: DoitMathCalc.allow(for: text), tol: tol, maxDen: maxDen)
    }

    /// 아래첨자 · 중괄호를 보통 글자로 ("aₙ₊₁" → "an+1", "a_{n+1}" → "an+1")
    static func plainIndices(_ s: String) -> String {
        let subs: [Character: String] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9",
                                         "ₙ": "n", "ₖ": "k", "₊": "+", "₋": "-", "ᵢ": "i"]
        var out = ""
        for ch in s { out += subs[ch] ?? String(ch) }
        return out
    }

    /// 식 덩어리: 한글 · 물음표 · 맨 바깥 쉼표 전까지 ("x³ + 2x² − x + 4 에 대하여" → "x³ + 2x² − x + 4")
    static func run(_ s: Substring, stopAtEquals: Bool = false) -> String {
        var out = ""
        var depth = 0
        for ch in s {
            if DoitSubjectNote.isHangul(ch) || ch == "?" || ch == "\n" { break }
            if ch == "(" || ch == "[" || ch == "{" { depth += 1 }
            if ch == ")" || ch == "]" || ch == "}" { depth -= 1; if depth < 0 { break } }
            if depth == 0, ch == "," { break }
            if stopAtEquals, depth == 0, "=<>≤≥".contains(ch) { break }
            out.append(ch)
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// "f(x) = …"의 식 (이름 f, g, h, 문자 x, t)
    static func definition(_ t: String, name: String = "f", variable: String = "x") -> String? {
        guard let r = t.range(of: "\(name)\\s*\\(\\s*\(variable)\\s*\\)\\s*=", options: .regularExpression) else { return nil }
        let body = run(t[r.upperBound...], stopAtEquals: true)
        return body.isEmpty ? nil : body
    }

    /// "y = …"의 식
    static func curve(_ t: String) -> String? {
        guard let r = t.range(of: #"(?<![a-z'])y\s*=\s*"#, options: .regularExpression) else { return nil }
        let body = run(t[r.upperBound...], stopAtEquals: true)
        return body.isEmpty ? nil : body
    }

    static func lineText(_ m: Double, _ b: Double, _ text: String) -> String? {
        guard let ms = show(m, text), let bs = show(abs(b), text) else { return nil }
        var slope: String
        if abs(m) < 1e-12 { slope = "" }
        else if abs(m - 1) < 1e-12 { slope = "x" }
        else if abs(m + 1) < 1e-12 { slope = "−x" }
        else { slope = (ms.contains("/") && !ms.hasPrefix("−") ? "(\(ms))" : ms.hasPrefix("−") && ms.contains("/") ? "−(\(ms.dropFirst()))" : ms) + "x" }
        if slope.isEmpty { return "y = " + (show(b, text) ?? bs) }
        if abs(b) < 1e-12 { return "y = " + slope }
        return "y = " + slope + (b < 0 ? " − " : " + ") + bs
    }

    // MARK: - 앞에서 확인 (다른 풀이가 틀리게 읽던 모양)

    static func first(_ t: String) -> Solved? {
        if let s = DoitMathProb.solve(t) { return s }
        if let s = DoitMathSpace.solve(t) { return s }
        if let s = limitSolve(t) { return s }
        if let s = series(t) { return s }
        if let s = sigmaFraction(t) { return s }
        if let s = sigmaClosedForm(t) { return s }
        if let s = recurrence(t) { return s }
        if let s = partialSum(t) { return s }
        if let s = firstExceeding(t) { return s }
        if let s = definiteIntegral(t) { return s }
        if let s = antiderivativeValue(t) { return s }
        if let s = motion(t) { return s }
        if let s = averageRate(t) { return s }
        if let s = closedIntervalExtreme(t) { return s }
        if let s = extremeCombination(t) { return s }
        if let s = monotoneCondition(t) { return s }
        if let s = tangentWithSlope(t) { return s }
        if let s = transcendentalDerivative(t) { return s }
        if let s = areaOneLine(t) { return s }
        if let s = rootSum(t) { return s }
        if let s = trigShape(t) { return s }
        if let s = sinPlusCos(t) { return s }
        if let s = radianSector(t) { return s }
        return nil
    }

    // MARK: - 극한

    static func limitSolve(_ raw: String) -> Solved? {
        guard raw.contains("lim") else { return nil }
        let t = raw.replacingOccurrences(of: "⁺", with: "+").replacingOccurrences(of: "⁻", with: "-")
        guard let r = t.range(of: #"lim\s*_?\s*\{?\s*\(?\s*([a-z])\s*(?:→|->)\s*([+-]?\s*∞|[+-]?\d*π(?:/\d+)?|[+-]?\d+(?:\.\d+)?(?:/\d+)?)\s*(?:([+-])(?=\s*\}|\s|\)))?\s*\)?\s*\}?"#, options: .regularExpression),
              let m = match(String(t[r]), #"lim\s*_?\s*\{?\s*\(?\s*([a-z])\s*(?:→|->)\s*([+-]?\s*∞|[+-]?\d*π(?:/\d+)?|[+-]?\d+(?:\.\d+)?(?:/\d+)?)\s*(?:([+-])(?=\s*\}|\s|\)))?"#),
              let variable = m[1].first else { return nil }
        let rest = t[r.upperBound...]
        let body = run(rest, stopAtEquals: true)
        // "lim … = 5 일 때 a의 값" 처럼 조건이 있는 극한은 여기서 풀지 않음
        let after = rest.dropFirst(body.count).trimmingCharacters(in: .whitespaces)
        if after.hasPrefix("=") { return nil }
        guard !body.isEmpty, let f = DoitMathCalc.parse(body, variable: variable), f.hasVariable else { return nil }
        let target = m[2].replacingOccurrences(of: " ", with: "")
        var approach: DoitMathCalc.Approach
        var atInfinity = false
        if target.hasSuffix("∞") {
            approach = target.hasPrefix("-") ? .minusInfinity : .plusInfinity
            atInfinity = true
        } else {
            guard let a = number(target) else { return nil }
            approach = m[3] == "+" ? .right(a) : m[3] == "-" ? .left(a) : .point(a)
        }
        guard let value = DoitMathCalc.limit(f, approach) else { return nil }
        var allow = DoitMathCalc.allow(for: body)
        if atInfinity, !body.contains("√") { allow.remove(.surd) }
        guard let answer = DoitMathCalc.nice(value, allow: allow, tol: atInfinity ? 1e-7 : 1e-9, maxDen: atInfinity ? 40 : 60) else { return nil }
        let arrow = "\(variable) → \(target)\(m[3])"
        var steps = [step("극한", "lim(\(arrow)) \(body)")]
        if atInfinity {
            steps.append(step(variable == "n" ? "n이 한없이 커질 때: 최고차항(또는 가장 큰 밑)으로 분모·분자를 나누면" : "x가 한없이 커질 때: 최고차항(근호는 분자의 유리화)으로 정리하면", "→ \(answer)"))
        } else if case .binary("/", let num, let den) = f, let a = number(target), let nv = num.eval(a), let dv = den.eval(a), abs(nv) < 1e-9, abs(dv) < 1e-9 {
            steps.append(step("\(variable) = \(target)을 넣으면 0/0 꼴", "인수분해·유리화로 약분하거나(로피탈의 정리처럼) 분자·분모를 미분해서 비교하면"))
            steps.append(step("극한값", answer))
        } else {
            steps.append(step("식이 이어져 있어서 \(variable) = \(target)을 넣으면", answer))
        }
        return Solved(kind: .calc, topic: "함수의 극한", concept: "0/0 꼴은 인수분해·분자의 유리화로 약분하고, ∞/∞ 꼴은 최고차항으로 나눠요. lim(x→0) sin x / x = 1, lim(x→0) (eˣ − 1)/x = 1, lim(x→0) ln(1 + x)/x = 1",
                      steps: steps, answer: answer)
    }

    // MARK: - 급수

    static func series(_ raw: String) -> Solved? {
        let t = plainIndices(raw)
        // ∑_{n=1}^{∞} aₙ
        if let m = match(t, #"[∑Σ]\s*_?\s*\(?\s*\{?\s*([nk])\s*=\s*(\d+)\s*\}?\s*\)?\s*\^?\s*\{?\s*∞\s*\}?\s*"#),
           let r = t.range(of: m[0]), let variable = m[1].first, let start = Int(m[2]) {
            let body = run(t[r.upperBound...], stopAtEquals: true)
            guard !body.isEmpty, let term = DoitMathCalc.parse(body, variable: variable) else { return nil }
            return seriesSum(term: { term.eval(Double($0)) }, start: start, shown: "∑(\(variable)=\(start)→∞) \(body)", text: raw)
        }
        // 1 + 1/2 + 1/4 + 1/8 + …
        guard has(t, ["급수", "합"]), t.contains("…") || t.contains("⋯") || t.contains("...") else { return nil }
        guard let m = match(t, #"((?:[-+]?\s*[0-9./√()]+\s*[+-]\s*){3,}[0-9./√()]+)\s*[+-]?\s*(?:…|⋯|\.\.\.)\s*(?![+\-0-9])"#) else { return nil }
        var terms: [Double] = []
        var sign = 1.0, current = ""
        for ch in m[1] + "+" {
            if ch == "+" || ch == "-" {
                if !current.trimmingCharacters(in: .whitespaces).isEmpty {
                    guard let v = number(current) else { return nil }
                    terms.append(sign * v)
                    current = ""
                }
                sign = ch == "-" ? -1 : 1
            } else { current.append(ch) }
        }
        guard terms.count >= 4, terms[0] != 0 else { return nil }
        let ratio = terms[1] / terms[0]
        for k in 1..<terms.count where abs(terms[k] - terms[k - 1] * ratio) > 1e-12 * max(1, abs(terms[k])) { return nil }
        guard abs(ratio) < 1 else { return nil }
        let sum = terms[0] / (1 - ratio)
        guard let answer = show(sum, raw), let rs = show(ratio, raw), let a = show(terms[0], raw) else { return nil }
        return Solved(kind: .sequence, topic: "등비급수", concept: "공비 r가 −1 < r < 1 이면 등비급수 a + ar + ar² + … 는 수렴하고 그 합은 a/(1 − r)이에요.",
                      steps: [step("첫째항과 공비", "a = \(a), r = \(rs) (−1 < r < 1 이라 수렴)"), step("합 a/(1 − r)", answer)], answer: answer)
    }

    private static func seriesSum(term: (Int) -> Double?, start: Int, shown: String, text: String) -> Solved? {
        let values = (start..<(start + 8)).map(term)
        guard values.allSatisfy({ $0 != nil }) else { return nil }
        let v = values.compactMap { $0 }
        // 등비급수
        if v[0] != 0 {
            let r = v[1] / v[0]
            if (1..<v.count).allSatisfy({ abs(v[$0] - v[$0 - 1] * r) <= 1e-12 * max(1, abs(v[$0])) }) {
                guard abs(r) < 1 else { return nil }
                let sum = v[0] / (1 - r)
                guard let answer = show(sum, text), let rs = show(r, text), let a = show(v[0], text) else { return nil }
                return Solved(kind: .sequence, topic: "등비급수", concept: "공비 r가 −1 < r < 1 이면 등비급수는 수렴하고 합은 (첫째항)/(1 − r)이에요.",
                              steps: [step("급수", shown), step("첫째항과 공비", "a = \(a), r = \(rs) (−1 < r < 1 이라 수렴)"), step("합 a/(1 − r)", answer)], answer: answer)
            }
        }
        // 그 밖: 부분합이 1/N 꼴로 다가갈 때만 (리처드슨 외삽으로 확인)
        func partial(_ n: Int) -> Double? {
            var s = 0.0
            for k in start...n { guard let x = term(k) else { return nil }; s += x }
            return s
        }
        guard let s1 = partial(20000), let s2 = partial(40000), let s3 = partial(100000), let s4 = partial(200000) else { return nil }
        let r1 = 2 * s2 - s1, r2 = 2 * s4 - s3
        guard abs(r1 - r2) <= 1e-8 * max(1, abs(r2)), abs(s4 - r2) <= 1e-3 * max(1, abs(r2)),
              let answer = DoitMathCalc.nice(r2, allow: [], tol: 1e-8, maxDen: 24) else { return nil }
        return Solved(kind: .sequence, topic: "급수", concept: "급수의 합은 부분합 Sₙ의 극한이에요. 부분분수로 나누면 가운데 항이 지워져요.",
                      steps: [step("급수", shown), step("부분합 Sₙ을 구해 n → ∞ 로 보내면", answer)], answer: answer)
    }

    // MARK: - ∑ (분수 식도 정확히)

    static func sigmaFraction(_ raw: String) -> Solved? {
        guard raw.contains("∑") || raw.contains("Σ") else { return nil }
        let t = DoitMathCalc.superscripts(plainIndices(raw))
        guard let m = match(t, #"[∑Σ]\s*_?\s*\(?\s*\{?\s*([kin])\s*=\s*(-?\d+)\s*\}?\s*\)?\s*\^?\s*\{?\s*\(?\s*(\d+)\s*\)?\s*\}?\s*"#),
              let r = t.range(of: m[0]), let variable = m[1].first, let lo = Int(m[2]), let hi = Int(m[3]), hi >= lo, hi - lo <= 5000 else { return nil }
        let body = run(t[r.upperBound...], stopAtEquals: true)
        // 다항식은 원래 풀이로 (∑(2k+1) 처럼)
        guard !body.isEmpty, body.contains("/") || body.contains("√") || body.contains("^(") || body.contains("^" + String(variable)),
              let term = DoitMathCalc.parse(body, variable: variable) else { return nil }
        var exact: Rat? = .zero
        var total = 0.0
        for k in lo...hi {
            guard let v = term.eval(Double(k)) else { return nil }
            total += v
            if let e = exact, let x = DoitMathCalc.evalRat(term, Rat(k)), let s = e + x { exact = s } else { exact = nil }
        }
        let answer: String
        if let e = exact { answer = e.text } else {
            guard let a = show(total, raw, tol: 1e-11, maxDen: 2000) else { return nil }
            answer = a
        }
        var steps = [step("식", "∑(\(variable)=\(lo)→\(hi)) \(body)")]
        if body.contains("/"), term.isTranscendental {
            steps.append(step("부분분수로 나누면 (예: 1/(k(k+1)) = 1/k − 1/(k+1)) 가운데 항이 지워져요", "남는 항만 계산하면 \(answer)"))
        } else {
            steps.append(step("각 항을 더하면", answer))
        }
        return Solved(kind: .sequence, topic: "합의 기호 ∑", concept: "분수 꼴은 부분분수 1/(k(k+1)) = 1/k − 1/(k+1) 로 나눠 앞뒤가 지워지게(망원합) 계산해요.",
                      steps: steps, answer: answer)
    }

    // MARK: - ∑_{k=1}^{n} (n 이 문자인 합: 다항식 꼴만, 정확한 분수로 보간하고 여러 n 으로 다시 확인한 것만)

    /// ∑_{k=1}^{n} (k의 3차 이하 다항식) → n 의 다항식. 합을 n = 시작…시작+4 에서 정확한 분수로 구해 보간하고, 그 뒤 n 여섯 개에서 다시 맞는지 확인
    static func sigmaClosedForm(_ raw: String) -> Solved? {
        guard raw.contains("∑") || raw.contains("Σ") else { return nil }
        let t = DoitMathCalc.superscripts(plainIndices(raw)).replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        guard let m = match(t, #"[∑Σ]\s*_?\s*\(?\s*([k])\s*=\s*([01])\s*\)?\s*\^\s*\(?\s*n\s*\)?\s*"#),
              let r = t.range(of: m[0]), let index = m[1].first, let lo = Int(m[2]) else { return nil }
        let body = run(t[r.upperBound...], stopAtEquals: true)
        guard !body.isEmpty, body.count <= 40, !body.contains("n"), let term = DoitMathCalc.parse(body, variable: index), term.hasVariable else { return nil }
        // 합 S(m) = ∑_{k=lo}^{m} term(k) 를 정확한 분수로
        func partial(_ upTo: Int) -> Rat? {
            var total: Rat = .zero
            if upTo < lo { return total }
            for k in lo...upTo {
                guard let v = DoitMathCalc.evalRat(term, Rat(k)), let next = total + v else { return nil }
                total = next
            }
            return total
        }
        // 다항식 확인: term 이 k 의 3차 이하 다항식이어야 함 (S 가 4차 이하). 앞 5개로 보간한 것이 뒤 6개와 모두 같아야 함
        let xs = Array((lo - 1)...(lo + 3))
        var ys: [Rat] = []
        for x in xs { guard let y = partial(x) else { return nil }; ys.append(y) }
        // 라그랑주 보간으로 n 의 다항식 계수 (n⁴ … n⁰)
        var coef = [Rat](repeating: .zero, count: 5)
        for i in 0..<5 {
            var poly: [Rat] = [.one]   // 낮은 차수부터
            var denom: Rat = .one
            for j in 0..<5 where j != i {
                guard let xj = Rat(xs[j]), let xi = Rat(xs[i]), let d = xi - xj, let nd = denom * d else { return nil }
                denom = nd
                var next = [Rat](repeating: .zero, count: poly.count + 1)
                for (power, c) in poly.enumerated() {
                    guard let a = c * (-xj), let sum = next[power] + a, let b = next[power + 1] + c else { return nil }
                    next[power] = sum; next[power + 1] = b
                }
                poly = next
            }
            for (power, c) in poly.enumerated() {
                guard let scaled = c * ys[i], let q = scaled / denom, let sum = coef[power] + q else { return nil }
                coef[power] = sum
            }
        }
        func evaluate(_ n: Int) -> Rat? {
            var total: Rat = .zero
            for (power, c) in coef.enumerated() {
                guard let pw = Rat(n).flatMap({ $0.power(power) }), let term = c * pw, let sum = total + term else { return nil }
                total = sum
            }
            return total
        }
        for n in (lo + 4)...(lo + 9) {
            guard let direct = partial(n), let formula = evaluate(n), direct == formula else { return nil }
        }
        // 식으로 쓰기
        var parts: [String] = []
        for power in stride(from: 4, through: 0, by: -1) where !coef[power].isZero {
            let c = coef[power]
            let mag = Rat(abs(c.n), c.d)!
            let variable = power == 0 ? "" : power == 1 ? "n" : "n" + ["", "", "²", "³", "⁴"][power]
            let number: String
            if power == 0 { number = mag.text }
            else if mag == Rat.one { number = "" }
            else if mag.isInteger { number = mag.text }
            else { number = "(\(mag.text))" }
            parts.append((c.n < 0 ? "− " : (parts.isEmpty ? "" : "+ ")) + number + variable)
        }
        guard !parts.isEmpty else { return nil }
        var answer = parts.joined(separator: " ")
        if answer.hasPrefix("− ") { answer = "−" + answer.dropFirst(2) }
        // 잘 알려진 모양은 인수분해한 꼴도 함께
        let known: [String: String] = ["(1/2)n² + (1/2)n": "n(n+1)/2", "(1/3)n³ + (1/2)n² + (1/6)n": "n(n+1)(2n+1)/6", "(1/4)n⁴ + (1/2)n³ + (1/4)n²": "{n(n+1)/2}²"]
        let tidy = known[answer]
        let shown = tidy.map { "\($0) = \(answer)" } ?? answer
        var steps = [step("식", "∑(\(index)=\(lo)→n) \(body)")]
        steps.append(step("n = \(lo)…\(lo + 4) 에서 합을 구해 n 의 다항식으로 정리하고, n = \(lo + 4)…\(lo + 9) 에서 다시 확인하면", shown))
        return Solved(kind: .sequence, topic: "합의 기호 ∑", concept: "∑ₖ₌₁ⁿ k = n(n+1)/2, ∑ k² = n(n+1)(2n+1)/6, ∑ k³ = {n(n+1)/2}², ∑ c = cn",
                      steps: steps, answer: shown)
    }

    // MARK: - 점화식

    static func recurrence(_ raw: String) -> Solved? {
        let t = plainIndices(raw).replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        guard t.contains("a"), let rule = match(t, #"a\s*\(?\s*n\s*\+\s*([12])\s*\)?\s*=\s*"#), let rr = t.range(of: rule[0]) else { return nil }
        let order = Int(rule[1]) ?? 1
        var rhs = run(t[rr.upperBound...])
        // "(n = 1, 2, 3, …)", "(n ≥ 1)" 처럼 붙은 범위
        if let cut = rhs.range(of: #"\(\s*n\s*(=|≥|>|은)"#, options: .regularExpression) { rhs = String(rhs[..<cut.lowerBound]).trimmingCharacters(in: .whitespaces) }
        guard !rhs.isEmpty else { return nil }
        // 처음 값들 a1 = 2, a2 = 3
        var known: [Int: Rat] = [:]
        for m in matches(t, #"(?<![a-z])a\s*(\d+)\s*=\s*(-?\d+(?:\.\d+)?(?:/\d+)?)(?![\d/.])"#) {
            guard let k = Int(m[1]), let v = number(m[2]).flatMap(DoitMathCalc.rat) else { continue }
            if let old = known[k], old != v { return nil }
            known[k] = v
        }
        guard (1...order).allSatisfy({ known[$0] != nil }) else { return nil }
        // 묻는 항
        guard let ask = match(t, #"a\s*(\d+)\s*(?:의\s*값|값|은|는|을|를|\?|$)"#), let target = Int(ask[1]), target > order, target <= 200 else { return nil }
        if known[target] != nil { return nil }
        // 식 속 an+1 → Y, an → X, n → (k)
        // "2aₙ + 1"(띄어 씀)은 aₙ₊₁이 아님: 괄호가 있거나 붙어 쓴 것만 aₙ₊₁
        var template = rhs.replacingOccurrences(of: #"a\s*\(\s*n\s*\+\s*1\s*\)|an\+1(?![0-9])"#, with: "Y", options: .regularExpression)
        template = template.replacingOccurrences(of: #"a\s*\(?\s*n\s*\)?"#, with: "X", options: .regularExpression)
        guard !template.contains("a"), order == 2 || !template.contains("Y") else { return nil }
        var values = known
        var shown: [String] = (1...order).map { "a\($0) = \(known[$0]!.text)" }
        for n in 1...(target - order) {
            var e = template
            guard let x = values[n] else { return nil }
            e = e.replacingOccurrences(of: "X", with: "(\(x.n)/\(x.d))")
            if order == 2 {
                guard let y = values[n + 1] else { return nil }
                e = e.replacingOccurrences(of: "Y", with: "(\(y.n)/\(y.d))")
            }
            e = e.replacingOccurrences(of: "n", with: "(\(n))")
            guard let node = DoitMathCalc.parse(e, variable: "#"), !node.hasVariable, let v = DoitMathCalc.evalRat(node, nil) else { return nil }
            values[n + order] = v
            if shown.count < 12 { shown.append("a\(n + order) = \(v.text)") }
        }
        guard let answer = values[target] else { return nil }
        if shown.count >= 12 { shown.append("…") }
        let lhs = order == 1 ? "aₙ₊₁" : "aₙ₊₂"
        return Solved(kind: .sequence, topic: "수열의 귀납적 정의", concept: "처음 항과 이웃한 항 사이의 관계(점화식)가 주어지면 n = 1, 2, 3, … 을 차례로 넣어 다음 항을 구해요.",
                      steps: [step("점화식", "\(lhs) = \(rhs)"), step("n = 1부터 차례로 넣으면", shown.joined(separator: ", ")), step("a\(target)", answer.text)],
                      answer: answer.text)
    }

    // MARK: - Sₙ으로 aₙ

    static func partialSum(_ raw: String) -> Solved? {
        let t = plainIndices(raw).replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        var body: String?
        if let r = t.range(of: #"S\s*n\s*(?:이|가|은|는)?\s*=\s*"#, options: .regularExpression) { body = run(t[r.upperBound...], stopAtEquals: true) }
        else if let r = t.range(of: #"[∑Σ]\s*\(?\s*k\s*=\s*1\s*\)?\s*\^?\s*n\s*a\s*k\s*=\s*"#, options: .regularExpression) { body = run(t[r.upperBound...], stopAtEquals: true) }
        else if let r = t.range(of: #"첫째항부터\s*제\s*n\s*항까지의\s*합(?:이|은|을)?\s*"#, options: .regularExpression) {
            let b = run(t[r.upperBound...], stopAtEquals: true)
            if !b.isEmpty { body = b }
        }
        guard let s = body, !s.isEmpty, let S = DoitMathCalc.parse(s, variable: "n"), S.hasVariable,
              let ask = match(t, #"a\s*(\d+)\s*(?:의\s*값|값|은|는|\?|$)"#), let k = Int(ask[1]), k >= 1, k <= 1000 else { return nil }
        guard let sk = DoitMathCalc.evalRat(S, Rat(k)), let sk1 = k == 1 ? Rat.zero : DoitMathCalc.evalRat(S, Rat(k - 1)), let a = sk - sk1 else { return nil }
        let steps = k == 1 ? [step("a₁ = S₁", a.text)] : [step("aₙ = Sₙ − Sₙ₋₁ (n ≥ 2)", "a\(k) = S\(k) − S\(k - 1) = \(sk.text) − \(sk1.text) = \(a.text)")]
        return Solved(kind: .sequence, topic: "수열의 합과 일반항", concept: "a₁ = S₁, n ≥ 2 일 때 aₙ = Sₙ − Sₙ₋₁ 이에요.",
                      steps: [step("Sₙ", s)] + steps, answer: a.text)
    }

    // MARK: - 처음으로 넘는 항

    static func firstExceeding(_ t: String) -> Solved? {
        guard let cond = match(t, #"처음으로\s*(-?\d+(?:\.\d+)?)\s*(?:보다|을|를)\s*(커|크|넘|작아|작)"#), let bound = Double(cond[1]),
              has(t, ["제몇 항", "몇째 항", "제 몇 항", "몇 번째 항"]) else { return nil }
        guard let list = match(t, #"(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,?\s*(?:…|⋯|\.\.\.)"#),
              let a = Double(list[1]), let b = Double(list[2]), let c = Double(list[3]) else { return nil }
        let bigger = cond[2].hasPrefix("커") || cond[2].hasPrefix("크") || cond[2].hasPrefix("넘")
        var term: (Int) -> Double
        var kind: String
        if abs((b - a) - (c - b)) < 1e-12, b != a {
            term = { a + Double($0 - 1) * (b - a) }; kind = "등차수열 (공차 \(DoitMath.fraction(b - a)))"
        } else if a != 0, b != 0, abs(b / a - c / b) < 1e-12 {
            let r = b / a
            term = { a * pow(r, Double($0 - 1)) }; kind = "등비수열 (공비 \(DoitMath.fraction(r)))"
        } else { return nil }
        for n in 1...10000 {
            let v = term(n)
            if bigger ? v > bound : v < bound {
                guard n > 1 else { return nil }
                return Solved(kind: .sequence, topic: "수열의 항", concept: "일반항을 구한 뒤 부등식을 만족하는 가장 작은 n을 찾아요.",
                              steps: [step("수열", kind), step("제\(n - 1)항과 제\(n)항", "\(DoitMath.format(term(n - 1))) , \(DoitMath.format(v))"),
                                      step("처음으로 \(DoitMath.format(bound))\(bigger ? "보다 커지는" : "보다 작아지는") 항", "제\(n)항")],
                              answer: "제\(n)항")
            }
        }
        return nil
    }

    // MARK: - 정적분

    /// ∫ 뒤의 아래끝 · 위끝 · 식 · 적분 변수
    static func integralParts(_ t: String) -> (lo: Double, hi: Double, loText: String, hiText: String, body: String, variable: Character)? {
        guard let start = t.firstIndex(of: "∫") else { return nil }
        let subs: [Character: Character] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9", "₋": "-"]
        let sups: [Character: Character] = ["⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4", "⁵": "5", "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9", "⁻": "-"]
        let c = Array(t[t.index(after: start)...])
        var i = 0
        func skipSpaces() { while i < c.count, c[i] == " " { i += 1 } }
        func token(scripts: [Character: Character]) -> String? {
            skipSpaces()
            guard i < c.count else { return nil }
            if c[i] == "{" {
                var s = ""
                i += 1
                while i < c.count, c[i] != "}" { s.append(c[i]); i += 1 }
                guard i < c.count else { return nil }
                i += 1
                return s
            }
            if scripts[c[i]] != nil {
                var s = ""
                while i < c.count, let d = scripts[c[i]] { s.append(d); i += 1 }
                return s
            }
            var s = ""
            if c[i] == "-" { s.append("-"); i += 1 }
            // e는 혼자일 때만 (∫₀¹e^x 의 "1e"를 끝으로 읽지 않게)
            if i < c.count, c[i] == "e", i + 1 >= c.count || c[i + 1] == " " || c[i + 1] == "(" {
                i += 1
                return s + "e"
            }
            while i < c.count, c[i].isNumber || c[i] == "." || c[i] == "π" || c[i] == "/" { s.append(c[i]); i += 1 }
            return s.isEmpty || s == "-" ? nil : s
        }
        skipSpaces()
        if i < c.count, c[i] == "_" { i += 1 }
        guard let loText = token(scripts: subs) else { return nil }
        skipSpaces()
        if i < c.count, c[i] == "^" { i += 1 }
        guard let hiText = token(scripts: sups) else { return nil }
        let rest = String(c[i...])
        guard let d = rest.range(of: #"d\s*([xt])(?![a-z])"#, options: .regularExpression) else { return nil }
        let body = String(rest[..<d.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard let variable = rest[d].last, !body.isEmpty, let lo = number(loText), let hi = number(hiText) else { return nil }
        return (lo, hi, loText, hiText, body, variable)
    }

    static func definiteIntegral(_ t: String) -> Solved? {
        guard t.contains("∫"), t.filter({ $0 == "∫" }).count == 1, let p = integralParts(t) else { return nil }
        // "f(x) = ∫…" 처럼 함수를 정하는 적분, 상수가 남은 적분은 다른 풀이로
        if t.range(of: #"[fgh]\s*\(\s*x\s*\)\s*=\s*∫"#, options: .regularExpression) != nil { return nil }
        guard let f = DoitMathCalc.parse(p.body, variable: p.variable), let value = DoitMathCalc.integrate(f, p.lo, p.hi) else { return nil }
        let polynomial = !f.isTranscendental && f.absoluteArguments.isEmpty
        guard let answer = show(value, t, tol: polynomial ? 1e-10 : 1e-9, maxDen: polynomial ? 3000 : 60) else { return nil }
        var steps = [step("정적분", "∫(\(p.loText)→\(p.hiText)) \(p.body) d\(p.variable)")]
        if !f.absoluteArguments.isEmpty { steps.append(step("절댓값 안이 0이 되는 곳에서 구간을 나누고 부호를 정해 적분하면", answer)) }
        else { steps.append(step("부정적분 F를 구해 F(\(p.hiText)) − F(\(p.loText))", answer)) }
        return Solved(kind: .integral, topic: "정적분", concept: "∫ₐᵇ f(x) dx = F(b) − F(a) (F' = f). 절댓값이 있으면 안이 0이 되는 곳에서 구간을 나눠요.",
                      steps: steps, answer: answer)
    }

    /// f'(x) = … 이고 f(a) = b 일 때 f(c)
    static func antiderivativeValue(_ t: String) -> Solved? {
        let s = t.replacingOccurrences(of: "′", with: "'")
        guard let r = s.range(of: #"f\s*'\s*\(\s*x\s*\)\s*=\s*"#, options: .regularExpression) else { return nil }
        let body = run(s[r.upperBound...], stopAtEquals: true)
        guard !body.isEmpty, let g = DoitMathCalc.parse(body, variable: "x") else { return nil }
        let given = matches(s, #"(?<!')f\s*\(\s*(-?[0-9./π]+)\s*\)\s*=\s*(-?[0-9./]+)"#)
        guard given.count == 1, let a = number(given[0][1]), let b = number(given[0][2]),
              let ask = match(s, #"(?<!')f\s*\(\s*(-?[0-9./π]+)\s*\)\s*의\s*값"#), let c = number(ask[1]), ask[1] != given[0][1],
              let integral = DoitMathCalc.integrate(g, a, c), let answer = show(b + integral, t, maxDen: 1000) else { return nil }
        return Solved(kind: .integral, topic: "도함수로 함수 구하기", concept: "f(x) = ∫f'(x)dx + C 이고, 주어진 함숫값으로 C를 정해요. f(c) = f(a) + ∫ₐᶜ f'(x) dx",
                      steps: [step("f'(x)", body), step("f(\(ask[1])) = f(\(given[0][1])) + ∫(\(given[0][1])→\(ask[1])) f'(x) dx", "\(given[0][2]) + \(show(integral, t, maxDen: 1000) ?? DoitMath.format(integral)) = \(answer)")],
                      answer: answer)
    }

    // MARK: - 속도 · 가속도 · 움직인 거리

    static func motion(_ t: String) -> Solved? {
        guard has(t, ["속도", "가속도", "움직인 거리", "위치"]), t.contains("t") else { return nil }
        // 시각 t = a, t = a 에서 t = b 까지
        let times = matches(t, #"t\s*=\s*(\d+(?:\.\d+)?(?:/\d+)?)"#).compactMap { number($0[1]) }
        // 위치 x(t) = …, x = …
        var position: Node?, velocity: Node?, shown = ""
        if let r = t.range(of: #"위치(?:\s*x)?\s*(?:가|는|를|이)?\s*x\s*(?:\(\s*t\s*\))?\s*=\s*"#, options: .regularExpression) {
            shown = run(t[r.upperBound...], stopAtEquals: true)
            position = DoitMathCalc.parse(shown, variable: "t")
        } else if let r = t.range(of: #"속도(?:\s*v)?\s*(?:가|는|를|이)?\s*v\s*(?:\(\s*t\s*\))?\s*=\s*"#, options: .regularExpression) {
            shown = run(t[r.upperBound...], stopAtEquals: true)
            velocity = DoitMathCalc.parse(shown, variable: "t")
        }
        guard position != nil || velocity != nil, !shown.isEmpty else { return nil }
        let concept = "위치 x(t)를 미분하면 속도 v(t) = x'(t), 한 번 더 미분하면 가속도 a(t) = v'(t). 움직인 거리는 ∫|v(t)|dt, 위치의 변화량은 ∫v(t)dt 예요."
        if let x = position {
            let v = x.derivative
            if has(t, ["가속도"]), times.count == 1, let a = v.derivative.eval(times[0]), let ans = show(a, t) {
                return Solved(kind: .derivative, topic: "속도와 가속도", concept: concept,
                              steps: [step("위치", "x(t) = \(shown)"), step("가속도 a(t) = x''(t) 에 t = \(DoitMath.format(times[0]))", ans)], answer: ans)
            }
            if has(t, ["속도"]), !has(t, ["가속도", "움직인 거리", "속도가 0"]), times.count == 1, let s = v.eval(times[0]), let ans = show(s, t) {
                return Solved(kind: .derivative, topic: "속도와 가속도", concept: concept,
                              steps: [step("위치", "x(t) = \(shown)"), step("속도 v(t) = x'(t) 에 t = \(DoitMath.format(times[0]))", ans)], answer: ans)
            }
            return nil
        }
        guard let v = velocity else { return nil }
        if has(t, ["움직인 거리", "이동 거리"]), times.count == 2, let d = DoitMathCalc.integrate(.function("abs", v), times[0], times[1]), let ans = show(d, t, maxDen: 1000) {
            return Solved(kind: .integral, topic: "움직인 거리", concept: concept,
                          steps: [step("속도", "v(t) = \(shown)"), step("움직인 거리 ∫|v(t)|dt (t = \(DoitMath.format(times[0])) → \(DoitMath.format(times[1])))", ans)], answer: ans)
        }
        if has(t, ["위치의 변화량", "변위"]), times.count == 2, let d = DoitMathCalc.integrate(v, times[0], times[1]), let ans = show(d, t, maxDen: 1000) {
            return Solved(kind: .integral, topic: "위치의 변화량", concept: concept,
                          steps: [step("속도", "v(t) = \(shown)"), step("위치의 변화량 ∫v(t)dt", ans)], answer: ans)
        }
        if has(t, ["가속도"]), times.count == 1, let a = v.derivative.eval(times[0]), let ans = show(a, t) {
            return Solved(kind: .derivative, topic: "속도와 가속도", concept: concept,
                          steps: [step("속도", "v(t) = \(shown)"), step("가속도 a(t) = v'(t) 에 t = \(DoitMath.format(times[0]))", ans)], answer: ans)
        }
        return nil
    }

    // MARK: - 평균변화율

    static func averageRate(_ t: String) -> Solved? {
        guard t.contains("평균변화율"), let body = definition(t) ?? curve(t), let f = DoitMathCalc.parse(body),
              let m = match(t, #"(-?\d+(?:\.\d+)?)\s*에서\s*(-?\d+(?:\.\d+)?)\s*까지"#), let a = Double(m[1]), let b = Double(m[2]), a != b,
              let fa = f.eval(a), let fb = f.eval(b), let ans = show((fb - fa) / (b - a), t) else { return nil }
        return Solved(kind: .derivative, topic: "평균변화율", concept: "x의 값이 a에서 b까지 변할 때의 평균변화율은 {f(b) − f(a)}/(b − a) 예요.",
                      steps: [step("f(\(m[1])), f(\(m[2]))", "\(DoitMath.fraction(fa)), \(DoitMath.fraction(fb))"),
                              step("{f(\(m[2])) − f(\(m[1]))}/(\(m[2]) − (\(m[1])))", ans)], answer: ans)
    }

    // MARK: - 닫힌구간에서 최댓값 · 최솟값

    static func criticalPoints(_ f: Node, _ a: Double, _ b: Double, body: String) -> [Double]? {
        // 다항식은 정확한 근으로
        if !f.isTranscendental, f.absoluteArguments.isEmpty, let p = DoitMath.polynomial(DoitMathCalc.prepare(body)) {
            let roots = DoitAlgebra.realRoots(DoitAlgebra.derive(p))
            return roots.map(\.value).filter { $0 > a + 1e-12 && $0 < b - 1e-12 }
        }
        let d = f.derivative
        var points = DoitMathCalc.signChanges({ d.eval($0) }, a, b, samples: 6000)
        // 닿기만 하는 점 (중근)은 최대·최소에 상관없어요
        points = points.filter { $0 > a + 1e-12 && $0 < b - 1e-12 }
        return points.count <= 20 ? points : nil
    }

    static func closedIntervalExtreme(_ t: String) -> Solved? {
        guard has(t, ["최댓값", "최솟값"]), !has(t, ["극댓값", "극솟값"]) else { return nil }
        var range: (Double, Double)?
        if let m = match(t, #"(?:닫힌\s*)?구간\s*\[\s*(-?[0-9./π]+)\s*,\s*(-?[0-9./π]+)\s*\]"#), let a = number(m[1]), let b = number(m[2]) { range = (a, b) }
        else if let m = match(t, #"(-?[0-9./π]+)\s*≤\s*x\s*≤\s*(-?[0-9./π]+)"#), let a = number(m[1]), let b = number(m[2]) { range = (a, b) }
        guard let (a, b) = range, b > a, let body = definition(t) ?? curve(t), let f = DoitMathCalc.parse(body) else { return nil }
        // 이차함수는 원래 풀이(꼭짓점)로
        if !f.isTranscendental, let p = DoitMath.polynomial(DoitMathCalc.prepare(body)), p.degree <= 2 { return nil }
        guard let crit = criticalPoints(f, a, b, body: body) else { return nil }
        var candidates: [(Double, Double)] = []
        for x in [a, b] + crit { guard let y = f.eval(x) else { return nil }; candidates.append((x, y)) }
        let wantMax = has(t, ["최댓값"]) && !has(t, ["최솟값"])
        let wantMin = has(t, ["최솟값"]) && !has(t, ["최댓값"])
        guard let hi = candidates.max(by: { $0.1 < $1.1 }), let lo = candidates.min(by: { $0.1 < $1.1 }) else { return nil }
        guard let hiText = show(hi.1, t), let loText = show(lo.1, t) else { return nil }
        var steps = [step("함수", "f(x) = \(body), \(show(a, t) ?? "") ≤ x ≤ \(show(b, t) ?? "")")]
        let critText = crit.compactMap { x in show(x, t).map { "x = \($0)" } }
        steps.append(step("f'(x) = 0 인 점 (구간 안)", critText.isEmpty ? "없어요" : critText.joined(separator: ", ")))
        steps.append(step("양 끝과 그 점에서의 함숫값을 비교하면", candidates.compactMap { c in show(c.0, t).flatMap { xs in show(c.1, t).map { "f(\(xs)) = \($0)" } } }.joined(separator: ", ")))
        let concept = "닫힌구간에서 연속인 함수의 최댓값·최솟값은 극값과 구간 양 끝의 함숫값 중에서 가장 큰 값·작은 값이에요."
        if wantMax { return Solved(kind: .derivative, topic: "함수의 최대·최소", concept: concept, steps: steps, answer: hiText) }
        if wantMin { return Solved(kind: .derivative, topic: "함수의 최대·최소", concept: concept, steps: steps, answer: loText) }
        if has(t, ["합"]), let s = show(hi.1 + lo.1, t) { return Solved(kind: .derivative, topic: "함수의 최대·최소", concept: concept, steps: steps + [step("최댓값 + 최솟값", "\(hiText) + (\(loText)) = \(s)")], answer: s) }
        return Solved(kind: .derivative, topic: "함수의 최대·최소", concept: concept, steps: steps, answer: "최댓값 \(hiText), 최솟값 \(loText)")
    }

    // MARK: - 극댓값과 극솟값의 합 · 곱 · 차

    static func extremeCombination(_ t: String) -> Solved? {
        guard let op = match(t, #"극댓값과\s*극솟값의\s*(합|곱|차)"#) ?? match(t, #"극솟값과\s*극댓값의\s*(합|곱|차)"#),
              let body = definition(t) ?? curve(t), let p = DoitMath.polynomial(DoitMathCalc.prepare(body)), p.degree == 3 || p.degree == 4 else { return nil }
        let d = DoitAlgebra.derive(p)
        let roots = DoitAlgebra.realRoots(d)
        guard !roots.contains(where: { $0.label.contains("≈") }) else { return nil }
        var maxima: [Double] = [], minima: [Double] = []
        let dd = DoitAlgebra.derive(d)
        for r in roots {
            let s = DoitMath.value(dd, at: r.value)
            if s < -1e-9 { maxima.append(DoitMath.value(p, at: r.value)) } else if s > 1e-9 { minima.append(DoitMath.value(p, at: r.value)) } else { return nil }
        }
        guard maxima.count == 1, minima.count == 1 else { return nil }
        let M = maxima[0], m = minima[0]
        let value = op[1] == "합" ? M + m : op[1] == "곱" ? M * m : M - m
        guard let ans = show(value, t), let Ms = show(M, t), let ms = show(m, t) else { return nil }
        let sign = op[1] == "합" ? "+" : op[1] == "곱" ? "×" : "−"
        return Solved(kind: .derivative, topic: "극대·극소", concept: "f'(x) = 0 인 x의 좌우에서 f'(x)의 부호가 +→− 이면 극대, −→+ 이면 극소예요.",
                      steps: [step("f'(x)", DoitMath.describe(d)), step("f'(x) = 0", roots.map { "x = \($0.label)" }.joined(separator: ", ")),
                              step("극댓값, 극솟값", "\(Ms), \(ms)"), step("극댓값 \(sign) 극솟값", ans)], answer: ans)
    }

    // MARK: - 실수 전체에서 증가 · 감소하도록 하는 상수

    static func monotoneCondition(_ t: String) -> Solved? {
        guard has(t, ["실수 전체", "모든 실수"]), let dir = match(t, #"(증가|감소)\s*하도록"#) ?? match(t, #"(증가|감소)\s*하기\s*위한"#),
              let body = definition(t), let letter = DoitMathExact.parameterLetter(t), letter != "x" else { return nil }
        let increasing = dir[1] == "증가"
        func derivativeAt(_ k: Double) -> DoitMath.Poly? {
            let filled = body.replacingOccurrences(of: String(letter), with: "(\(DoitMath.format(k)))")
            guard let p = DoitMath.polynomial(DoitMathCalc.prepare(filled)), p.degree == 3 else { return nil }
            return DoitAlgebra.derive(p)
        }
        // 판별식 D(k) = B² − 4AC 를 k의 이차식으로 (세 점으로 맞추고 네 번째로 확인)
        var ds: [Double] = []
        for k in [0.0, 1, 2, 3] {
            guard let d = derivativeAt(k) else { return nil }
            if increasing ? d[2] <= 0 : d[2] >= 0 { return nil }
            ds.append(d[1] * d[1] - 4 * d[2] * d[0])
        }
        let c0 = ds[0], c2 = (ds[2] - 2 * ds[1] + ds[0]) / 2, c1 = ds[1] - ds[0] - c2
        guard abs(c0 + 3 * c1 + 9 * c2 - ds[3]) < 1e-6 else { return nil }
        // D(k) ≤ 0 인 k의 범위
        let name = String(letter)
        var interval: (lo: Double?, hi: Double?)
        if abs(c2) < 1e-12 {
            guard abs(c1) > 1e-12 else { return nil }
            let root = -c0 / c1
            interval = c1 > 0 ? (nil, root) : (root, nil)
        } else {
            let disc = c1 * c1 - 4 * c2 * c0
            guard c2 > 0, disc >= 0 else { return nil }
            let r1 = (-c1 - disc.squareRoot()) / (2 * c2), r2 = (-c1 + disc.squareRoot()) / (2 * c2)
            interval = (r1, r2)
        }
        var answer: String
        if has(t, ["최솟값"]) { guard let lo = interval.lo, let s = show(lo, t) else { return nil }; answer = s }
        else if has(t, ["최댓값"]) { guard let hi = interval.hi, let s = show(hi, t) else { return nil }; answer = s }
        else if has(t, ["범위"]) {
            switch (interval.lo.flatMap { show($0, t) }, interval.hi.flatMap { show($0, t) }) {
            case (let a?, let b?): answer = "\(a) ≤ \(name) ≤ \(b)"
            case (let a?, nil): answer = "\(name) ≥ \(a)"
            case (nil, let b?): answer = "\(name) ≤ \(b)"
            default: return nil
            }
        } else { return nil }
        return Solved(kind: .derivative, topic: "함수의 증가·감소", concept: "삼차함수가 실수 전체에서 \(dir[1])하려면 f'(x) \(increasing ? "≥" : "≤") 0 이 항상 성립해야 해서, 이차식 f'(x)의 판별식 D ≤ 0 이에요.",
                      steps: [step("f(x)", body), step("f'(x)의 판별식 D ≤ 0", "\(name)에 대한 부등식을 풀면"), step("답", answer)], answer: answer)
    }

    // MARK: - 기울기가 주어진 접선

    static func tangentWithSlope(_ t: String) -> Solved? {
        guard has(t, ["접하고", "접선"]), let m = match(t, #"기울기가\s*(-?\d+(?:\.\d+)?(?:/\d+)?)\s*인\s*(?:직선|접선)"#), let slope = number(m[1]),
              let body = curve(t) ?? definition(t), let f = DoitMathCalc.parse(body), has(t, ["방정식", "y절편"]),
              let p = DoitMath.polynomial(DoitMathCalc.prepare(body)), p.degree >= 2 else { return nil }
        // f'(x) = 기울기 인 x (다항식이라 정확한 근으로, 닿기만 하는 근도 빠짐없이)
        let roots = DoitAlgebra.realRoots(DoitAlgebra.derive(p) - .constant(slope))
        guard roots.count == 1, !roots[0].label.contains("≈") else { return nil }
        let xs = [roots[0].value]
        guard let y = f.eval(xs[0]) else { return nil }
        let b = y - slope * xs[0]
        if has(t, ["y절편"]), let ans = show(b, t) {
            return Solved(kind: .derivative, topic: "접선의 방정식", concept: "기울기가 m인 접선은 f'(a) = m 인 점 (a, f(a))에서 그어요.",
                          steps: [step("f'(x) = \(m[1])", "x = \(show(xs[0], t) ?? "")"), step("접점", "(\(show(xs[0], t) ?? ""), \(show(y, t) ?? ""))"), step("y절편", ans)], answer: ans)
        }
        guard let line = lineText(slope, b, t) else { return nil }
        return Solved(kind: .derivative, topic: "접선의 방정식", concept: "기울기가 m인 접선은 f'(a) = m 인 점 (a, f(a))에서 그어요: y − f(a) = m(x − a)",
                      steps: [step("f'(x) = \(m[1]) 인 x", "x = \(show(xs[0], t) ?? "")"), step("접점", "(\(show(xs[0], t) ?? ""), \(show(y, t) ?? ""))"), step("y − f(a) = m(x − a)", line)], answer: line)
    }

    // MARK: - 초월함수의 미분계수 · 접선

    static func transcendentalDerivative(_ raw: String) -> Solved? {
        let t = raw.replacingOccurrences(of: "′", with: "'")
        guard let body = definition(t) ?? curve(t), let f = DoitMathCalc.parse(body), f.isTranscendental else { return nil }
        let concept = "(eˣ)' = eˣ, (ln x)' = 1/x, (sin x)' = cos x, (cos x)' = −sin x, (aˣ)' = aˣ ln a. 곱·몫·합성함수의 미분법을 써요."
        if let m = match(t, #"f\s*''\s*\(\s*(-?[0-9./π]+)\s*\)"#), let a = number(m[1]) {
            guard let v = f.derivative.derivative.eval(a), let ans = show(v, t) else { return nil }
            return Solved(kind: .derivative, topic: "이계도함수", concept: concept, steps: [step("f(x)", body), step("f''(\(m[1]))", ans)], answer: ans)
        }
        if let m = match(t, #"f\s*'\s*\(\s*(-?[0-9./π]+)\s*\)"#), let a = number(m[1]) {
            guard let v = f.derivative.eval(a), let ans = show(v, t) else { return nil }
            return Solved(kind: .derivative, topic: "미분계수", concept: concept, steps: [step("f(x)", body), step("도함수에 x = \(m[1])을 넣으면", "f'(\(m[1])) = \(ans)")], answer: ans)
        }
        if has(t, ["접선"]), let m = match(t, #"x\s*=\s*(-?[0-9./π]+)\s*인\s*점"#) ?? match(t, #"점\s*\(\s*(-?[0-9./π]+)\s*,"#), let a = number(m[1]),
           let slope = f.derivative.eval(a), let y = f.eval(a) {
            if has(t, ["기울기"]), !has(t, ["방정식"]), let ans = show(slope, t) {
                return Solved(kind: .derivative, topic: "접선의 기울기", concept: concept, steps: [step("f'(x)를 구해 x = \(m[1])을 넣으면", ans)], answer: ans)
            }
            if has(t, ["방정식"]), let line = lineText(slope, y - slope * a, t) {
                return Solved(kind: .derivative, topic: "접선의 방정식", concept: concept, steps: [step("접점", "(\(m[1]), \(show(y, t) ?? ""))"), step("기울기 f'(\(m[1]))", show(slope, t) ?? ""), step("y − f(a) = f'(a)(x − a)", line)], answer: line)
            }
        }
        return nil
    }

    // MARK: - 곡선과 x축, 직선 하나로 둘러싸인 넓이

    static func areaOneLine(_ t: String) -> Solved? {
        guard has(t, ["넓이"]), has(t, ["둘러싸인"]), t.contains("x축"), let body = curve(t), let f = DoitMathCalc.parse(body) else { return nil }
        let lines = matches(t, #"직선\s*x\s*=\s*(-?[0-9./π]+)"#) + matches(t, #"두\s*직선\s*x\s*=\s*(-?[0-9./π]+)\s*,\s*x\s*=\s*(-?[0-9./π]+)"#).map { [$0[0], $0[2]] }
        let values = Array(Set(lines.compactMap { number($0[1]) })).sorted()
        var a: Double, b: Double
        if values.count == 2, has(t, ["두 직선"]) {
            // 다항식은 원래 풀이로 (그대로 맞아요); 초월함수만
            guard f.isTranscendental else { return nil }
            a = values[0]; b = values[1]
        } else if values.count == 1, !has(t, ["두 직선"]) {
            let c = values[0]
            let roots = DoitMathCalc.signChanges({ f.eval($0) }, -60, 60, samples: 24000).compactMap { r -> Double? in
                guard let s = DoitMathCalc.nice(r, allow: [.surd], tol: 1e-7), let v = number(s), let y = f.eval(v), abs(y) < 1e-9 else { return nil }
                return v
            }
            // 닿기만 하는 근(x³의 0처럼 부호가 바뀌는 근은 위에서 찾음)도 확인
            var all = roots
            for k in -40...40 { let x = Double(k) / 2; if let y = f.eval(x), abs(y) < 1e-12, !all.contains(where: { abs($0 - x) < 1e-9 }) { all.append(x) } }
            all = all.filter { abs($0 - c) > 1e-9 }
            guard !all.isEmpty else { return nil }
            // 근이 모두 직선의 한쪽에 있어야 둘러싸인 부분이 하나로 정해져요
            if all.allSatisfy({ $0 < c }) { a = all.max()!; b = c }
            else if all.allSatisfy({ $0 > c }) { a = c; b = all.min()! }
            else { return nil }
        } else { return nil }
        guard let area = DoitMathCalc.integrate(.function("abs", f), a, b), area > 0,
              let ans = show(area, t, maxDen: f.isTranscendental ? 60 : 1000), let at = show(a, t), let bt = show(b, t) else { return nil }
        return Solved(kind: .integral, topic: "곡선과 x축 사이의 넓이", concept: "곡선 y = f(x)와 x축, 두 직선 x = a, x = b로 둘러싸인 넓이는 ∫ₐᵇ |f(x)| dx 예요.",
                      steps: [step("곡선", "y = \(body)"), step("넓이를 구할 구간", "\(at) ≤ x ≤ \(bt)"), step("∫|f(x)|dx", ans)], answer: ans)
    }

    // MARK: - 근과 계수의 관계 (삼차 이상) · 모든 실근의 합

    static func rootSum(_ t: String) -> Solved? {
        guard let ask = match(t, #"(세|네|모든|두)\s*(실근|근|해)의\s*(합|곱)"#) else { return nil }
        let realOnly = ask[2] == "실근"
        // 삼각·지수·로그방정식: 찾은 해를 모두 더함
        if t.range(of: #"sin|cos|tan|log|ln|\^\s*\(?\s*-?\d*\s*x"#, options: .regularExpression) != nil {
            guard ask[1] == "모든", let s = DoitMathMore.transcendental(t) else { return nil }
            let parts = s.answer.replacingOccurrences(of: "x = ", with: "").components(separatedBy: CharacterSet(charactersIn: ",또는")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let values = parts.compactMap(number)
            guard values.count == parts.count, !values.isEmpty else { return nil }
            let total = ask[3] == "합" ? values.reduce(0, +) : values.reduce(1, *)
            guard let ans = show(total, t) else { return nil }
            var out = s
            out.steps.append(step("모든 해의 \(ask[3])", parts.joined(separator: ask[3] == "합" ? " + " : " × ") + " = " + ans))
            out.answer = ans
            return out
        }
        // 다항방정식
        let expression = DoitAlgebra.extract(t)
        let sides = expression.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard sides.count == 2, let l = DoitMath.polynomial(sides[0]), let r = DoitMath.polynomial(sides[1]) else { return nil }
        let p = l - r
        let n = p.degree
        guard n >= 3 || (n == 2 && realOnly) else { return nil }
        if ask[1] == "세", n != 3 { return nil }
        if ask[1] == "네", n != 4 { return nil }
        if ask[1] == "두", n != 2 { return nil }
        var value: Double, how: String
        if realOnly {
            let roots = DoitAlgebra.realRoots(p)
            guard !roots.contains(where: { $0.label.contains("≈") }), !roots.isEmpty else { return nil }
            value = ask[3] == "합" ? roots.map(\.value).reduce(0, +) : roots.map(\.value).reduce(1, *)
            how = "실근 " + roots.map(\.label).joined(separator: ", ")
        } else {
            let lead = p[n]
            value = ask[3] == "합" ? -p[n - 1] / lead : (n % 2 == 0 ? 1 : -1) * p[0] / lead
            how = ask[3] == "합" ? "근과 계수의 관계: (모든 근의 합) = −(xⁿ⁻¹의 계수)/(최고차항의 계수)" : "근과 계수의 관계: (모든 근의 곱) = (−1)ⁿ × (상수항)/(최고차항의 계수)"
        }
        guard let ans = show(value, t) else { return nil }
        return Solved(kind: .higherEquation, topic: "근과 계수의 관계", concept: "삼차방정식 ax³ + bx² + cx + d = 0 의 세 근을 α, β, γ라 하면 α + β + γ = −b/a, αβ + βγ + γα = c/a, αβγ = −d/a",
                      steps: [step("방정식", "\(DoitMath.describe(p)) = 0"), step(how, ans)], answer: ans)
    }

    // MARK: - 삼각함수의 주기 · 최댓값 · 최솟값

    /// y = A·f(Bx + C) + D 꼴 (f = sin, cos, tan)
    static func trigParts(_ n: Node) -> (a: Double, d: Double, name: String, b: Double)? {
        switch n {
        case .function(let name, let arg) where ["sin", "cos", "tan"].contains(name):
            guard let v0 = arg.eval(0), let v1 = arg.eval(1), let v2 = arg.eval(2.5), abs((v2 - v0) - 2.5 * (v1 - v0)) < 1e-9, abs(v1 - v0) > 1e-12 else { return nil }
            return (1, 0, name, v1 - v0)
        case .negate(let a): return trigParts(a).map { (-$0.a, -$0.d, $0.name, $0.b) }
        case .binary(let op, let l, let r):
            if !l.hasVariable, let c = l.eval(0), let p = trigParts(r) {
                switch op {
                case "*": return (c * p.a, c * p.d, p.name, p.b)
                case "+": return (p.a, c + p.d, p.name, p.b)
                case "-": return (-p.a, c - p.d, p.name, p.b)
                default: return nil
                }
            }
            if !r.hasVariable, let c = r.eval(0), let p = trigParts(l) {
                switch op {
                case "*": return (c * p.a, c * p.d, p.name, p.b)
                case "/": return c == 0 ? nil : (p.a / c, p.d / c, p.name, p.b)
                case "+": return (p.a, p.d + c, p.name, p.b)
                case "-": return (p.a, p.d - c, p.name, p.b)
                default: return nil
                }
            }
            return nil
        default: return nil
        }
    }

    static func trigShape(_ t: String) -> Solved? {
        guard has(t, ["주기", "최댓값", "최솟값"]), t.range(of: "sin|cos|tan", options: .regularExpression) != nil,
              let body = curve(t) ?? definition(t), let f = DoitMathCalc.parse(body), let p = trigParts(f) else { return nil }
        // 범위가 붙은 최대·최소는 여기서 풀지 않음
        if t.range(of: #"≤\s*x|x\s*≤|<\s*x|x\s*<|구간"#, options: .regularExpression) != nil { return nil }
        let period = (p.name == "tan" ? Double.pi : 2 * .pi) / abs(p.b)
        let concept = "y = a sin(bx + c) + d 의 주기는 2π/|b|, 최댓값 |a| + d, 최솟값 −|a| + d. y = a tan(bx + c) + d 의 주기는 π/|b| (최댓값·최솟값 없음)"
        var asks: [(String, Double?)] = []
        if t.contains("주기") { asks.append(("주기", period)) }
        if t.contains("최댓값") { asks.append(("최댓값", p.name == "tan" ? nil : abs(p.a) + p.d)) }
        if t.contains("최솟값") { asks.append(("최솟값", p.name == "tan" ? nil : -abs(p.a) + p.d)) }
        guard !asks.isEmpty, asks.allSatisfy({ $0.1 != nil }) else { return nil }
        let texts = asks.compactMap { a in a.1.flatMap { show($0, t + "π") }.map { (a.0, $0) } }
        guard texts.count == asks.count else { return nil }
        var answer: String
        if texts.count == 1 { answer = texts[0].1 }
        else if has(t, ["합"]), texts.count == 2, let s = show(asks[0].1! + asks[1].1!, t + "π") { answer = s }
        else if has(t, ["곱"]), texts.count == 2, let s = show(asks[0].1! * asks[1].1!, t + "π") { answer = s }
        else { answer = texts.map { "\($0.0) \($0.1)" }.joined(separator: ", ") }
        return Solved(kind: .function, topic: "삼각함수의 그래프", concept: concept,
                      steps: [step("식의 모양", "y = \(body)"), step("a, b, d를 읽으면", texts.map { "\($0.0) \($0.1)" }.joined(separator: ", "))], answer: answer)
    }

    // MARK: - sin θ + cos θ = k

    static func sinPlusCos(_ t: String) -> Solved? {
        let s = t.replacingOccurrences(of: " ", with: "")
        guard let m = match(s, #"sinθ([+-])cosθ=(-?[0-9./√]+)"#), let k = number(m[2]) else { return nil }
        // p = sin θ cos θ
        let p = m[1] == "+" ? (k * k - 1) / 2 : (1 - k * k) / 2
        let rest = s.replacingOccurrences(of: m[0], with: "")
        var value: Double, what: String
        if rest.contains("sin^3θ+cos^3θ") || rest.contains("sin³θ+cos³θ") {
            guard m[1] == "+" else { return nil }
            value = k * k * k - 3 * p * k; what = "sin³θ + cos³θ = (sin θ + cos θ)³ − 3 sin θ cos θ (sin θ + cos θ)"
        } else if rest.contains("tanθ+1/tanθ") || rest.contains("1/tanθ+tanθ") {
            guard p != 0 else { return nil }
            value = 1 / p; what = "tan θ + 1/tan θ = 1/(sin θ cos θ)"
        } else if rest.contains("sinθcosθ") || rest.contains("sinθ×cosθ") || rest.contains("sinθ*cosθ") {
            value = p; what = "양변을 제곱하면 1 \(m[1] == "+" ? "+" : "−") 2 sin θ cos θ = \(m[2])²"
        } else { return nil }
        guard let ans = show(value, t) else { return nil }
        return Solved(kind: .function, topic: "삼각함수 사이의 관계", concept: "sin²θ + cos²θ = 1 을 써요. (sin θ ± cos θ)² = 1 ± 2 sin θ cos θ",
                      steps: [step("sin θ cos θ", "\(what) → sin θ cos θ = \(show(p, t) ?? "")"), step("값", ans)], answer: ans)
    }

    // MARK: - 호도법으로 나타낸 부채꼴

    static func radianSector(_ t: String) -> Solved? {
        guard t.contains("부채꼴"), let r = match(t, #"반지름의\s*길이가\s*(\d+(?:\.\d+)?)"#).flatMap({ number($0[1]) }),
              let m = match(t, #"중심각의\s*크기가\s*(\d*π(?:/\d+)?|\d+(?:\.\d+)?(?:/\d+)?\s*(?:라디안|rad))"#) else { return nil }
        let thetaText = m[1].replacingOccurrences(of: "라디안", with: "").replacingOccurrences(of: "rad", with: "").trimmingCharacters(in: .whitespaces)
        guard let theta = number(thetaText) else { return nil }
        if has(t, ["호의 길이"]), let ans = show(r * theta, t + "π") {
            return Solved(kind: .geometry, topic: "부채꼴의 호의 길이 (호도법)", concept: "반지름 r, 중심각 θ(라디안)인 부채꼴의 호의 길이 l = rθ, 넓이 S = (1/2)r²θ = (1/2)rl",
                          steps: [step("l = rθ", "\(DoitMath.format(r)) × \(thetaText) = \(ans)")], answer: ans)
        }
        if has(t, ["넓이"]), let ans = show(r * r * theta / 2, t + "π") {
            return Solved(kind: .geometry, topic: "부채꼴의 넓이 (호도법)", concept: "반지름 r, 중심각 θ(라디안)인 부채꼴의 넓이 S = (1/2)r²θ",
                          steps: [step("S = (1/2)r²θ", "(1/2) × \(DoitMath.format(r))² × \(thetaText) = \(ans)")], answer: ans)
        }
        return nil
    }
}
