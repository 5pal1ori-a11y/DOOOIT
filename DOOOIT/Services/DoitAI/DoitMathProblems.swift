import Foundation

/// 수학 문제 유형 알아보기 + 풀이 (오답노트 단계별 풀이, AI에게 질문)
enum MathSolver {
    enum Kind { case linear, quadraticEquation, vertex, rootRelation, remainder, expression }

    struct Solved {
        var topic: String
        var concept: String
        var steps: [SolutionStep]
        var answer: String
    }

    private typealias P = DoitMath.Poly

    static func kind(of text: String) -> Kind? {
        if function(in: text) != nil, has(text, ["꼭짓점", "최댓값", "최솟값", "최대", "최소", "축의 방정식"]) { return .vertex }
        if has(text, ["나머지"]), divisorRoot(in: text) != nil, function(in: text) ?? equationPoly(in: text) != nil { return .remainder }
        if let poly = equationPoly(in: text) {
            if poly.degree == 2, has(text, ["두 근의 합", "두 근의 곱", "근의 합", "근의 곱", "α+β", "αβ", "a+b"]) { return .rootRelation }
            if poly.degree == 2 { return .quadraticEquation }
            if poly.degree == 1 { return .linear }
        }
        let expression = DoitMath.extractExpression(text)
        if !expression.contains("="), DoitMath.looksLikeMath(expression), DoitMath.polynomial(expression) != nil { return .expression }
        return nil
    }

    static func solve(_ text: String) -> Solved? {
        guard let kind = kind(of: text) else { return nil }
        switch kind {
        case .vertex:
            guard let f = function(in: text), f.degree == 2 else { return nil }
            return vertex(f, asks: text)
        case .rootRelation:
            guard let poly = equationPoly(in: text) else { return nil }
            return roots(poly, asks: text)
        case .remainder:
            guard let f = function(in: text) ?? equationPoly(in: text), let r = divisorRoot(in: text) else { return nil }
            let value = DoitMath.value(f, at: r)
            return Solved(topic: "나머지정리", concept: "다항식 f(x)를 x − a로 나눈 나머지는 f(a)예요.",
                          steps: [SolutionStep(hint: "나누는 식이 0이 되는 x는?", work: "x = \(DoitMath.fraction(r))"),
                                  SolutionStep(hint: "f(\(DoitMath.fraction(r)))를 계산하면?", work: "f(x) = \(DoitMath.describe(f)) 에 대입 → \(DoitMath.fraction(value))")],
                          answer: DoitMath.fraction(value))
        case .linear, .quadraticEquation:
            let expression = DoitMath.extractExpression(text)
            guard let result = DoitMath.solveEquation(expression) else { return nil }
            let hints = kind == .linear
                ? ["모든 항을 한쪽으로 모으면?", "x의 계수로 양변을 나누면?"]
                : ["모든 항을 한쪽으로 모으면?", "근의 공식에 넣을 a, b, c는?", "판별식으로 근의 종류를 확인하면?", "근을 구하면?"]
            let steps = result.steps.enumerated().map { index, work in
                SolutionStep(hint: index < hints.count ? hints[index] : "다음으로", work: work)
            }
            return Solved(topic: result.title,
                          concept: kind == .linear ? "x가 포함된 항은 한쪽, 수는 다른 쪽으로 옮긴 뒤 x의 계수로 나눠요."
                                                    : "ax² + bx + c = 0 의 근은 x = (−b ± √(b²−4ac)) / 2a 예요. 인수분해가 되면 더 빨라요.",
                          steps: steps, answer: result.answer)
        case .expression:
            guard let result = DoitMath.solve(DoitMath.extractExpression(text)) else { return nil }
            return Solved(topic: result.title, concept: "괄호를 먼저 풀고 같은 차수끼리 모아요.",
                          steps: result.steps.map { SolutionStep(hint: "계산 순서대로", work: $0) }, answer: result.answer)
        }
    }

    private static func vertex(_ f: P, asks text: String) -> Solved {
        let a = f[2], b = f[1]
        let p = -b / (2 * a)
        let q = DoitMath.value(f, at: p)
        let pText = DoitMath.fraction(p), qText = DoitMath.fraction(q)
        var steps = [
            SolutionStep(hint: "x² 계수 a와 x 계수 b는?", work: "a = \(DoitMath.fraction(a)), b = \(DoitMath.fraction(b))"),
            SolutionStep(hint: "꼭짓점의 x좌표는 −b/2a", work: "x = \(pText)"),
            SolutionStep(hint: "그때의 y값은?", work: "y = \(qText) → 꼭짓점 (\(pText), \(qText))")
        ]
        let opensUp = a > 0
        steps.append(SolutionStep(hint: "그래프 모양은?", work: opensUp ? "a > 0 이라 아래로 볼록 → x = \(pText)에서 최솟값 \(qText)"
                                                                  : "a < 0 이라 위로 볼록 → x = \(pText)에서 최댓값 \(qText)"))
        let answer: String
        if has(text, ["최댓값", "최대"]) {
            answer = opensUp ? "최댓값은 없어요 (최솟값 \(qText))" : qText
        } else if has(text, ["최솟값", "최소"]) {
            answer = opensUp ? qText : "최솟값은 없어요 (최댓값 \(qText))"
        } else if has(text, ["축의 방정식"]) {
            answer = "x = \(pText)"
        } else {
            answer = "(\(pText), \(qText))"
        }
        return Solved(topic: "이차함수의 꼭짓점", concept: "y = ax² + bx + c 를 y = a(x − p)² + q 꼴로 바꾸면 꼭짓점은 (p, q)예요.",
                      steps: steps, answer: answer)
    }

    private static func roots(_ poly: P, asks text: String) -> Solved {
        let a = poly[2], b = poly[1], c = poly[0]
        let sum = DoitMath.fraction(-b / a), product = DoitMath.fraction(c / a)
        let steps = [
            SolutionStep(hint: "ax² + bx + c = 0 의 a, b, c는?", work: "a = \(DoitMath.fraction(a)), b = \(DoitMath.fraction(b)), c = \(DoitMath.fraction(c))"),
            SolutionStep(hint: "두 근의 합 = −b/a", work: "α + β = \(sum)"),
            SolutionStep(hint: "두 근의 곱 = c/a", work: "αβ = \(product)")
        ]
        let answer: String
        if has(text, ["곱", "αβ"]) && !has(text, ["합", "α+β"]) { answer = product }
        else if has(text, ["합", "α+β"]) && !has(text, ["곱", "αβ"]) { answer = sum }
        else { answer = "합 \(sum), 곱 \(product)" }
        return Solved(topic: "근과 계수의 관계", concept: "이차방정식 ax² + bx + c = 0 의 두 근을 α, β라 하면 α + β = −b/a, αβ = c/a 예요.",
                      steps: steps, answer: answer)
    }

    // MARK: 문장에서 식 찾기

    private static func has(_ text: String, _ words: [String]) -> Bool { words.contains { text.contains($0) } }

    /// "y = x² − 4x + 1", "f(x) = …" 의 오른쪽 식
    static func function(in text: String) -> DoitMath.Poly? {
        for marker in ["f(x)=", "f(x) =", "y=", "y =", "g(x)=", "P(x)="] {
            guard let range = text.range(of: marker) else { continue }
            let rest = String(text[range.upperBound...])
            let expression = DoitMath.extractExpression(String(rest.prefix(60)))
            let lhs = expression.split(separator: "=").first.map(String.init) ?? expression
            if let poly = DoitMath.polynomial(lhs), poly.degree >= 1 { return poly }
        }
        return nil
    }

    /// 방정식 "… = …" 을 (좌변 − 우변) 다항식으로
    static func equationPoly(in text: String) -> DoitMath.Poly? {
        let expression = DoitMath.extractExpression(text)
        let sides = expression.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard sides.count == 2, let left = DoitMath.polynomial(sides[0]), let right = DoitMath.polynomial(sides[1]) else { return nil }
        let poly = left - right
        return poly.degree >= 1 ? poly : nil
    }

    /// "x − 2로 나눈" → 2
    static func divisorRoot(in text: String) -> Double? {
        guard let range = text.range(of: #"x\s*[-−+]\s*\d+\s*(으로|로)\s*나눈"#, options: .regularExpression) else { return nil }
        let part = String(text[range])
        let number = Double(part.filter(\.isNumber)) ?? 0
        return part.contains("+") ? -number : number
    }
}

/// 수학 계산 문제 만들기 (AI 학습 문제, 개념 예제, 비슷한 문제)
enum MathProblems {
    enum Topic: CaseIterable { case quadraticEquation, quadraticFunction, linear, remainder, rootRelation, expand }

    private typealias P = DoitMath.Poly

    static func topic(for unit: String) -> [Topic]? {
        var topics: [Topic] = []
        if unit.contains("이차방정식") || unit.contains("근의 공식") || unit.contains("판별식") { topics.append(.quadraticEquation) }
        if unit.contains("이차함수") || unit.contains("꼭짓점") || unit.contains("최대") || unit.contains("최소") { topics.append(.quadraticFunction) }
        if unit.contains("일차방정식") || (unit.contains("방정식") && topics.isEmpty) { topics.append(.linear) }
        if unit.contains("나머지정리") || unit.contains("인수정리") || unit.contains("나눗셈") { topics.append(.remainder) }
        if unit.contains("근과 계수") { topics.append(.rootRelation) }
        if unit.contains("다항식") || unit.contains("전개") || unit.contains("곱셈 공식") || unit.contains("인수분해") { topics.append(.expand) }
        return topics.isEmpty ? nil : topics
    }

    static func make(unit: String, hard: Bool) -> Problem? {
        let topic = (topic(for: unit) ?? Topic.allCases).randomElement() ?? .linear
        let made = generate(topic, hard: hard)
        return Problem(question: made.question, choices: made.choices, answerNumber: made.answerNumber,
                       steps: made.steps, finalAnswer: made.answer)
    }

    /// 오답과 같은 유형으로 새 문제 (level 0 쉬움 → 2 어려움)
    static func similar(kind: MathSolver.Kind, level: Int) -> SimilarProblem? {
        let topic: Topic
        switch kind {
        case .linear: topic = .linear
        case .quadraticEquation: topic = .quadraticEquation
        case .vertex: topic = .quadraticFunction
        case .rootRelation: topic = .rootRelation
        case .remainder: topic = .remainder
        case .expression: topic = .expand
        }
        let made = generate(topic, hard: level >= 2)
        return SimilarProblem(question: made.question, answer: made.answer, explanation: made.steps.joined(separator: " → "))
    }

    // MARK: 만들기

    private struct Made {
        var question: String
        var answer: String
        var steps: [String]
        var choices: [String]
        var answerNumber: Int
    }

    private static func poly(_ coefficients: [Double]) -> P {
        var p = P()
        for (i, c) in coefficients.enumerated() where i < 5 { p.c[i] = c }
        return p
    }

    private static func nonZero(_ range: ClosedRange<Int>) -> Int {
        var n = 0
        while n == 0 { n = Int.random(in: range) }
        return n
    }

    private static func generate(_ topic: Topic, hard: Bool) -> Made {
        switch topic {
        case .quadraticEquation:
            let a = hard ? [2, 3].randomElement()! : 1
            var r1 = Int.random(in: -6...6), r2 = Int.random(in: -6...6)
            while r1 == r2 { r2 = Int.random(in: -6...6) }
            let p = poly([Double(a * r1 * r2), Double(-a * (r1 + r2)), Double(a)])
            let big = max(r1, r2)
            return numeric("이차방정식 \(DoitMath.describe(p)) = 0 의 두 근 중 큰 근은?", answer: big,
                           steps: ["인수분해: \(a == 1 ? "" : "\(a)")(x − (\(r1)))(x − (\(r2))) = 0", "x = \(r1) 또는 x = \(r2)", "큰 근은 \(big)"])
        case .rootRelation:
            let a = hard ? [2, 3].randomElement()! : 1
            let b = Int.random(in: -9...9), c = nonZero(-9...9)
            let p = poly([Double(c), Double(b), Double(a)])
            let asksSum = Bool.random()
            let value = asksSum ? -Double(b) / Double(a) : Double(c) / Double(a)
            if value == value.rounded() {
                return numeric("이차방정식 \(DoitMath.describe(p)) = 0 의 두 근을 α, β라 할 때 \(asksSum ? "α + β" : "αβ")의 값은?",
                               answer: Int(value), steps: [asksSum ? "α + β = −b/a = \(DoitMath.fraction(value))" : "αβ = c/a = \(DoitMath.fraction(value))"])
            }
            return generate(.quadraticEquation, hard: hard)
        case .quadraticFunction:
            let a = [1, -1, 2, -2].randomElement()!
            let p0 = Int.random(in: -5...5), q0 = Int.random(in: -6...6)
            let f = poly([Double(a * p0 * p0 + q0), Double(-2 * a * p0), Double(a)])
            let right = "(\(p0), \(q0))"
            var options = [right, "(\(-p0), \(q0))", "(\(p0), \(-q0))", "(\(q0), \(p0))", "(\(-p0), \(-q0))", "(\(p0 + 1), \(q0))", "(\(p0), \(q0 - 1))"]
            options = Array(NSOrderedSet(array: options).array as? [String] ?? options)
            let choices = Array(([right] + options.filter { $0 != right }.shuffled().prefix(4)).shuffled())
            return Made(question: "이차함수 y = \(DoitMath.describe(f)) 의 꼭짓점의 좌표는?",
                        answer: right,
                        steps: ["x = −b/2a = \(p0)", "y = f(\(p0)) = \(q0)", "꼭짓점 \(right), \(a > 0 ? "최솟값" : "최댓값") \(q0)"],
                        choices: choices, answerNumber: (choices.firstIndex(of: right) ?? 0) + 1)
        case .linear:
            let x0 = Int.random(in: -9...9)
            let a = nonZero(-6...6)
            var c = Int.random(in: -6...6)
            while c == a { c = Int.random(in: -6...6) }
            let b = Int.random(in: -12...12)
            let d = (a - c) * x0 + b
            let left = DoitMath.describe(poly([Double(b), Double(a)]))
            let right = DoitMath.describe(poly([Double(d), Double(c)]))
            return numeric("방정식 \(left) = \(right) 의 해는?", answer: x0,
                           steps: ["x항은 왼쪽, 수는 오른쪽으로: \(a - c)x = \(d - b)", "x = \(x0)"])
        case .remainder:
            let a = Int.random(in: -3...3), b = Int.random(in: -5...5), c = Int.random(in: -6...6)
            let r = nonZero(-3...3)
            let f = poly([Double(c), Double(b), Double(a), 1])
            let value = Int(DoitMath.value(f, at: Double(r)))
            let divisor = r > 0 ? "x − \(r)" : "x + \(-r)"
            return numeric("다항식 f(x) = \(DoitMath.describe(f)) 를 \(divisor)로 나눈 나머지는?", answer: value,
                           steps: ["나머지정리: 나머지 = f(\(r))", "f(\(r)) = \(value)"])
        case .expand:
            let p = nonZero(-7...7), q = nonZero(-7...7)
            let m = hard ? nonZero(2...3) : 1
            let coefficient = m * q + p
            let first = m == 1 ? "x" : "\(m)x"
            func signed(_ n: Int) -> String { n >= 0 ? "+ \(n)" : "− \(-n)" }
            return numeric("(\(first) \(signed(p)))(x \(signed(q))) 를 전개했을 때 x의 계수는?", answer: coefficient,
                           steps: ["x 계수 = \(m)×\(q) + \(p)", "= \(coefficient)"])
        }
    }

    /// 답이 정수인 문제: 헷갈리기 쉬운 오답 4개를 섞어서 보기 5개
    private static func numeric(_ question: String, answer: Int, steps: [String]) -> Made {
        var wrong = Set<Int>()
        for candidate in [-answer, answer + 1, answer - 1, answer + 2, answer - 2, answer * 2, answer + 3] where candidate != answer {
            wrong.insert(candidate)
            if wrong.count == 4 { break }
        }
        let choices = ([answer] + Array(wrong)).shuffled().map(String.init)
        let index = choices.firstIndex(of: String(answer)) ?? 0
        return Made(question: question, answer: String(answer), steps: steps, choices: choices, answerNumber: index + 1)
    }
}
