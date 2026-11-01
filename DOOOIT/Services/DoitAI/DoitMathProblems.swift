import Foundation

/// 수학 문제 유형 알아보기 + 풀이 (두잇 AI 대화, 오답노트 단계별 풀이, AI에게 질문)
enum MathSolver {
    enum Kind: String, Codable, CaseIterable {
        case linear, quadraticEquation, vertex, rootRelation, remainder, expression
        case factor, higherEquation, inequality, system, absolute
        case derivative, integral, function
        case counting, statistics, numberTheory, percent, coordinate, circle, geometry, sequence, sets, complex, calc
    }

    struct Solved {
        var kind: Kind
        var topic: String
        var concept: String
        var steps: [SolutionStep]
        var answer: String
    }

    private typealias P = DoitMath.Poly

    static func kind(of text: String) -> Kind? { solve(text)?.kind }

    /// 문장을 보고 알맞은 풀이를 찾아 풂 (못 풀면 nil)
    static func solve(_ raw: String) -> Solved? {
        let text = DoitAlgebra.normalize(raw)
        let t = text

        // 0) 문자 a, b, c로 쓴 식의 전개: (a+b)² → 여러 문자 다항식으로 계산
        if has(t, ["전개", "정리", "곱셈 공식", "곱셈공식"]), !t.contains(where: { "xyz".contains($0) }),
           t.range(of: #"[abc]"#, options: .regularExpression) != nil, let s = expandLetters(t) { return s }

        // 1) 키워드가 분명한 유형부터
        if let s = DoitMathTopics.sets(t) { return s }
        if let s = DoitMathTopics.functionGraph(t) { return s }
        if let s = DoitAlgebra.solveCalculus(t) { return s }
        if let f = function(in: t), f.degree == 2, has(t, ["꼭짓점", "최댓값", "최솟값", "최대", "최소", "축의 방정식"]) { return vertex(f, asks: t) }
        if has(t, ["나머지"]), let r = divisorRoot(in: t), let f = function(in: t) ?? polynomialBefore(t, marker: "을") ?? equationPoly(in: t) {
            return remainder(f, at: r)
        }
        if let s = DoitAlgebra.solveFunction(t) { return s }
        if let s = DoitMathTopics.counting(t) { return s }
        if let s = DoitMathTopics.statistics(t) { return s }
        if let s = DoitMathTopics.numberTheory(t) { return s }
        if let s = DoitMathTopics.percent(t) { return s }
        if let s = DoitMathTopics.sequence(t) { return s }
        if let s = DoitMathTopics.coordinate(t) { return s }
        if let s = DoitMathTopics.geometry(t) { return s }
        if t.range(of: #"\d\s*i|i\s*\^|\(\s*\d[^)]*i\s*\)|\bi\b"#, options: .regularExpression) != nil, let s = DoitMathTopics.complex(t) { return s }

        // 2) 식의 모양으로
        if t.contains("|"), let s = DoitAlgebra.solveAbsoluteEquation(t) { return s }
        if t.contains(where: { "<>≤≥".contains($0) }), let s = DoitAlgebra.solveInequality(t) { return s }
        if t.contains("y") || t.contains("z"), let s = DoitAlgebra.solveSystem(t) { return s }
        if has(t, ["인수분해"]) {
            let expression = DoitAlgebra.extract(t)
            if let p = DoitAlgebra.parse(expression.split(separator: "=").first.map(String.init) ?? expression)?.univariate,
               p.degree >= 2, let factored = DoitAlgebra.factor(p) {
                return Solved(kind: .factor, topic: "인수분해",
                              concept: "공통인수 묶기 → 공식(a² − b², 완전제곱식, x² + (a+b)x + ab) → 인수정리와 조립제법 순서로 시도해요.",
                              steps: factored.steps.isEmpty ? [SolutionStep(hint: "곱해서 상수항, 더해서 x의 계수가 되는 두 수를 찾으면", work: factored.text)] : factored.steps,
                              answer: factored.isTrivial ? "유리수 범위에서 더 인수분해되지 않아요" : factored.text)
            }
        }
        if let poly = equationPoly(in: t) {
            if poly.degree == 2, has(t, ["두 근의 합", "두 근의 곱", "근의 합", "근의 곱", "α+β", "αβ", "α + β", "α²", "α^2", "1/α", "(α", "두 근을 α"]) { return roots(poly, asks: t) }
            if poly.degree >= 3 { return DoitAlgebra.solveHigherEquation(poly, original: t) }
            if poly.degree == 2, has(t, ["판별식", "근의 종류", "실근", "허근", "중근"]) && !has(t, ["구해", "풀어"]) { return discriminant(poly) }
            if poly.degree >= 1, let result = DoitMath.solveEquation(DoitMath.extractExpression(t)) {
                return equation(poly, result: result)
            }
        }
        if let s = DoitMathTopics.calculate(t) { return s }
        let expression = DoitMath.extractExpression(t)
        if !expression.contains("="), DoitMath.looksLikeMath(expression), let result = DoitMath.solve(expression) {
            if let p = DoitMath.polynomial(expression), p.degree >= 2, has(t, ["인수분해"]) == false {
                return Solved(kind: .expression, topic: result.title, concept: "괄호를 먼저 풀고 같은 차수끼리 모아요. 곱셈 공식: (a ± b)² = a² ± 2ab + b², (a + b)(a − b) = a² − b²",
                              steps: result.steps.map { SolutionStep(hint: "전개해서 정리하면", work: $0) }, answer: result.answer)
            }
            return Solved(kind: .expression, topic: result.title, concept: "괄호 → 거듭제곱 → 곱셈·나눗셈 → 덧셈·뺄셈 순서로 계산해요.",
                          steps: result.steps.map { SolutionStep(hint: "계산 순서대로", work: $0) }, answer: result.answer)
        }
        return nil
    }

    // MARK: 유형별

    /// a, b, c 를 x, y, z 로 바꿔 계산하고 다시 a, b, c 로 보여줌
    private static func expandLetters(_ text: String) -> Solved? {
        let swapped = String(text.map { c -> Character in
            switch c { case "a": return "x"; case "b": return "y"; case "c": return "z"; default: return c }
        })
        let expression = DoitAlgebra.extract(swapped)
        guard expression.count >= 3, !expression.contains("="), let poly = DoitAlgebra.parse(expression), poly.degree >= 2 else { return nil }
        func back(_ s: String) -> String {
            String(s.map { c -> Character in
                switch c { case "x": return "a"; case "y": return "b"; case "z": return "c"; default: return c }
            })
        }
        return Solved(kind: .expression, topic: "식의 전개", concept: "곱셈 공식: (a ± b)² = a² ± 2ab + b², (a + b)(a − b) = a² − b², (a + b)³ = a³ + 3a²b + 3ab² + b³",
                      steps: [SolutionStep(hint: "분배법칙으로 전개해서 같은 항끼리 모으면", work: back(expression).replacingOccurrences(of: "*", with: "×"))],
                      answer: back(DoitAlgebra.describe(poly)))
    }

    private static func equation(_ poly: P, result: DoitMath.Result) -> Solved {
        let isLinear = poly.degree == 1
        var steps: [SolutionStep] = []
        let hints = isLinear
            ? ["모든 항을 한쪽으로 모으면?", "x항과 수를 양쪽으로 나누면?", "x의 계수로 양변을 나누면?"]
            : ["모든 항을 한쪽으로 모으면?", "근의 공식에 넣을 a, b, c는?", "판별식으로 근의 종류를 확인하면?", "근을 구하면?"]
        for (index, work) in result.steps.enumerated() {
            steps.append(SolutionStep(hint: index < hints.count ? hints[index] : "다음으로", work: work))
        }
        if !isLinear, let factored = DoitAlgebra.factor(poly), !factored.linear.isEmpty || factored.xPower > 0 {
            steps.insert(SolutionStep(hint: "인수분해가 되나요?", work: "\(factored.text) = 0"), at: 1)
        }
        return Solved(kind: isLinear ? .linear : .quadraticEquation, topic: result.title,
                      concept: isLinear ? "x가 포함된 항은 한쪽, 수는 다른 쪽으로 옮긴 뒤 x의 계수로 나눠요."
                                        : "ax² + bx + c = 0 의 근은 x = (−b ± √(b²−4ac)) / 2a 예요. 인수분해가 되면 더 빨라요. D < 0 이면 허근 (i² = −1).",
                      steps: steps, answer: result.answer)
    }

    private static func discriminant(_ poly: P) -> Solved {
        let a = poly[2], b = poly[1], c = poly[0]
        let d = b * b - 4 * a * c
        let kind = abs(d) < 1e-9 ? "중근 (서로 같은 두 실근)" : d > 0 ? "서로 다른 두 실근" : "서로 다른 두 허근"
        return Solved(kind: .quadraticEquation, topic: "판별식", concept: "D = b² − 4ac: D > 0 서로 다른 두 실근, D = 0 중근, D < 0 서로 다른 두 허근",
                      steps: [SolutionStep(hint: "a, b, c는?", work: "a = \(DoitMath.fraction(a)), b = \(DoitMath.fraction(b)), c = \(DoitMath.fraction(c))"),
                              SolutionStep(hint: "D = b² − 4ac", work: "\(DoitMath.fraction(b * b)) − \(DoitMath.fraction(4 * a * c)) = \(DoitMath.fraction(d))")],
                      answer: "D = \(DoitMath.fraction(d)) → \(kind)")
    }

    private static func remainder(_ f: P, at r: Double) -> Solved {
        let value = DoitMath.value(f, at: r)
        return Solved(kind: .remainder, topic: "나머지정리", concept: "다항식 f(x)를 x − a로 나눈 나머지는 f(a)예요. (f(a) = 0 이면 x − a는 인수 — 인수정리)",
                      steps: [SolutionStep(hint: "나누는 식이 0이 되는 x는?", work: "x = \(DoitMath.fraction(r))"),
                              SolutionStep(hint: "f(\(DoitMath.fraction(r)))를 계산하면?", work: "f(x) = \(DoitMath.describe(f)) 에 대입 → \(DoitMath.fraction(value))")],
                      answer: DoitMath.fraction(value))
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
        var answer: String
        if has(text, ["최댓값", "최대"]) {
            answer = opensUp ? "최댓값은 없어요 (최솟값 \(qText))" : qText
        } else if has(text, ["최솟값", "최소"]) {
            answer = opensUp ? qText : "최솟값은 없어요 (최댓값 \(qText))"
        } else if has(text, ["축의 방정식"]) {
            answer = "x = \(pText)"
        } else {
            answer = "(\(pText), \(qText))"
        }
        // 제한된 범위: "−1 ≤ x ≤ 3"
        if let m = text.firstMatch(of: #/(-?\d+(?:\.\d+)?)\s*≤\s*x\s*≤\s*(-?\d+(?:\.\d+)?)/#), let lo = Double(String(m.1)), let hi = Double(String(m.2)), lo < hi {
            var candidates = [lo, hi]
            if p > lo && p < hi { candidates.append(p) }
            let values = candidates.map { ($0, DoitMath.value(f, at: $0)) }
            let maxPair = values.max { $0.1 < $1.1 }!, minPair = values.min { $0.1 < $1.1 }!
            steps.append(SolutionStep(hint: "범위 \(DoitMath.fraction(lo)) ≤ x ≤ \(DoitMath.fraction(hi))의 양 끝과 꼭짓점의 값", work: values.map { "f(\(DoitMath.fraction($0.0))) = \(DoitMath.fraction($0.1))" }.joined(separator: ", ")))
            answer = "최댓값 \(DoitMath.fraction(maxPair.1)) (x = \(DoitMath.fraction(maxPair.0))), 최솟값 \(DoitMath.fraction(minPair.1)) (x = \(DoitMath.fraction(minPair.0)))"
        }
        return Solved(kind: .vertex, topic: "이차함수의 꼭짓점과 최대·최소", concept: "y = ax² + bx + c 를 y = a(x − p)² + q 꼴로 바꾸면 꼭짓점은 (p, q)예요. 범위가 있으면 양 끝값과 꼭짓점을 비교해요.",
                      steps: steps, answer: answer)
    }

    private static func roots(_ poly: P, asks text: String) -> Solved {
        let a = poly[2], b = poly[1], c = poly[0]
        let sumValue = -b / a, productValue = c / a
        let sum = DoitMath.fraction(sumValue), product = DoitMath.fraction(productValue)
        var steps = [
            SolutionStep(hint: "ax² + bx + c = 0 의 a, b, c는?", work: "a = \(DoitMath.fraction(a)), b = \(DoitMath.fraction(b)), c = \(DoitMath.fraction(c))"),
            SolutionStep(hint: "두 근의 합 = −b/a", work: "α + β = \(sum)"),
            SolutionStep(hint: "두 근의 곱 = c/a", work: "αβ = \(product)")
        ]
        var answer: String
        let compact = text.replacingOccurrences(of: " ", with: "")
        if has(compact, ["α²+β²", "α^2+β^2"]) {
            let v = sumValue * sumValue - 2 * productValue
            steps.append(SolutionStep(hint: "α² + β² = (α + β)² − 2αβ", work: "(\(sum))² − 2×(\(product)) = \(DoitMath.fraction(v))"))
            answer = DoitMath.fraction(v)
        } else if has(compact, ["1/α+1/β"]) && productValue != 0 {
            let v = sumValue / productValue
            steps.append(SolutionStep(hint: "1/α + 1/β = (α + β)/αβ", work: DoitMath.fraction(v)))
            answer = DoitMath.fraction(v)
        } else if has(compact, ["(α-β)²", "(α-β)^2"]) {
            let v = sumValue * sumValue - 4 * productValue
            steps.append(SolutionStep(hint: "(α − β)² = (α + β)² − 4αβ", work: DoitMath.fraction(v)))
            answer = DoitMath.fraction(v)
        } else if has(text, ["곱", "αβ"]) && !has(text, ["합", "α+β", "α + β"]) { answer = product }
        else if has(text, ["합", "α+β", "α + β"]) && !has(text, ["곱", "αβ"]) { answer = sum }
        else { answer = "합 \(sum), 곱 \(product)" }
        return Solved(kind: .rootRelation, topic: "근과 계수의 관계", concept: "이차방정식 ax² + bx + c = 0 의 두 근을 α, β라 하면 α + β = −b/a, αβ = c/a 예요.",
                      steps: steps, answer: answer)
    }

    // MARK: 문장에서 식 찾기

    private static func has(_ text: String, _ words: [String]) -> Bool { words.contains { text.contains($0) } }

    /// "y = x² − 4x + 1", "f(x) = …" 의 오른쪽 식
    static func function(in text: String) -> DoitMath.Poly? {
        let t = DoitAlgebra.normalize(text)
        for marker in ["f(x)=", "f(x) =", "y=", "y =", "g(x)=", "g(x) =", "P(x)=", "P(x) ="] {
            guard let range = t.range(of: marker) else { continue }
            let rest = String(t[range.upperBound...])
            var piece = String(rest.prefix(60))
            if let cut = piece.firstIndex(where: { $0 == "," || $0 == "\n" }) { piece = String(piece[..<cut]) }
            // 식은 한글이 나오기 전까지 ("x³ 를 x − 3로 나눈"에서 나누는 식을 f(x)로 잘못 잡지 않게)
            if let cut = piece.firstIndex(where: { ("가"..."힣").contains($0) }), piece.distance(from: piece.startIndex, to: cut) > 0 {
                let head = String(piece[..<cut])
                if head.contains("x") { piece = head }
            }
            let expression = DoitMath.extractExpression(piece)
            let lhs = expression.split(separator: "=").first.map(String.init) ?? expression
            if let poly = DoitMath.polynomial(lhs), poly.degree >= 1 { return poly }
        }
        return nil
    }

    /// "x³−2x+1을 x−2로 나눈" 처럼 f(x) 없이 쓴 다항식
    private static func polynomialBefore(_ text: String, marker: String) -> DoitMath.Poly? {
        guard let range = text.range(of: #"x\s*[-+]\s*\d+\s*(으로|로)\s*나눈"#, options: .regularExpression) else { return nil }
        let before = String(text[..<range.lowerBound])
        let expression = DoitMath.extractExpression(before)
        guard let p = DoitMath.polynomial(expression), p.degree >= 1 else { return nil }
        return p
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
        let t = DoitAlgebra.normalize(text)
        guard let range = t.range(of: #"x\s*[-+]\s*\d+\s*(으로|로)\s*나눈"#, options: .regularExpression) else { return nil }
        let part = String(t[range])
        let number = Double(part.filter(\.isNumber)) ?? 0
        return part.contains("+") ? -number : number
    }
}

/// 수학 계산 문제 만들기 (AI 학습 문제, 개념 예제, 비슷한 문제, 두잇 AI 퀴즈)
enum MathProblems {
    enum Topic: CaseIterable {
        case quadraticEquation, quadraticFunction, linear, remainder, rootRelation, expand
        case factor, complexCalc, discriminant, cubic, system, inequality, quadInequality
        case sumProduct, permutation, combination, matrix
        case distance, internalDivision, lines, circle, translation
        case sets, proposition, amgm, composite, inverse, rational, irrational
        case derivative, integral, sequence, statistics, numberTheory, percent, geometry
    }

    private typealias P = DoitMath.Poly

    static func topic(for unit: String) -> [Topic]? {
        let u = unit.replacingOccurrences(of: " ", with: "")
        if u.contains("절대부등식") { return [.amgm] }
        if u.contains("도형의이동") { return [.translation] }
        var topics: [Topic] = []
        func add(_ words: [String], _ list: [Topic]) { if words.contains(where: { u.contains($0) }) { topics += list } }
        add(["다항식의연산", "다항식", "전개", "곱셈공식"], [.expand])
        add(["항등식", "나머지정리", "나눗셈"], [.remainder])
        add(["인수분해", "인수정리"], [.factor])
        add(["복소수"], [.complexCalc, .discriminant])
        add(["이차방정식", "근의공식", "판별식"], [.quadraticEquation, .discriminant, .rootRelation])
        add(["이차함수", "꼭짓점", "최대", "최소"], [.quadraticFunction])
        add(["근과계수"], [.rootRelation])
        add(["여러가지방정식", "삼차방정식", "사차방정식", "고차방정식"], [.cubic, .system])
        add(["연립"], [.system])
        add(["부등식"], [.inequality, .quadInequality])
        add(["합의법칙", "곱의법칙", "경우의수"], [.sumProduct])
        add(["순열"], [.permutation])
        add(["조합"], [.combination])
        add(["행렬"], [.matrix])
        add(["내분", "두점사이", "거리", "평면좌표"], [.distance, .internalDivision])
        add(["직선", "평행", "수직"], [.lines])
        add(["원의방정식"], [.circle])
        add(["도형의이동", "평행이동", "대칭이동"], [.translation])
        add(["집합"], [.sets])
        add(["명제", "조건"], [.proposition])
        add(["절대부등식", "산술평균", "기하평균"], [.amgm])
        add(["합성함수"], [.composite])
        add(["역함수"], [.inverse])
        add(["유리함수"], [.rational])
        add(["무리함수"], [.irrational])
        add(["미분", "도함수", "접선"], [.derivative])
        add(["적분"], [.integral])
        add(["수열", "등차", "등비"], [.sequence])
        add(["통계", "평균", "분산", "표준편차", "대푯값"], [.statistics])
        add(["약수", "배수", "소인수"], [.numberTheory])
        add(["비율", "백분율", "퍼센트"], [.percent])
        add(["도형", "넓이", "부피", "피타고라스"], [.geometry])
        if topics.isEmpty && (u.contains("일차방정식") || u.contains("방정식")) { topics.append(.linear) }
        var seen = Set<String>()
        topics = topics.filter { seen.insert("\($0)").inserted }
        return topics.isEmpty ? nil : topics
    }

    static func make(unit: String, hard: Bool) -> Problem? {
        let topic = (topic(for: unit) ?? [.linear, .quadraticEquation, .quadraticFunction, .factor, .expand]).randomElement() ?? .linear
        return make(topic: topic, hard: hard)
    }

    static func make(topic: Topic, hard: Bool) -> Problem {
        let made = generate(topic, hard: hard)
        return Problem(question: made.question, choices: made.choices, answerNumber: made.answerNumber,
                       steps: made.steps, finalAnswer: made.answer)
    }

    /// 오답과 같은 유형으로 새 문제 (level 0 쉬움 → 2 어려움)
    static func similar(kind: MathSolver.Kind, level: Int) -> SimilarProblem? {
        guard let topic = topic(for: kind) else { return nil }
        let made = generate(topic, hard: level >= 2)
        return SimilarProblem(question: made.question, answer: made.answer, explanation: made.steps.joined(separator: " → "))
    }

    static func topic(for kind: MathSolver.Kind) -> Topic? {
        switch kind {
        case .linear: return .linear
        case .quadraticEquation: return .quadraticEquation
        case .vertex: return .quadraticFunction
        case .rootRelation: return .rootRelation
        case .remainder: return .remainder
        case .expression: return .expand
        case .factor: return .factor
        case .higherEquation: return .cubic
        case .inequality, .absolute: return [.inequality, .quadInequality].randomElement()
        case .system: return .system
        case .derivative: return .derivative
        case .integral: return .integral
        case .function: return [.composite, .inverse].randomElement()
        case .counting: return [.permutation, .combination, .sumProduct].randomElement()
        case .statistics: return .statistics
        case .numberTheory: return .numberTheory
        case .percent: return .percent
        case .coordinate: return [.distance, .internalDivision, .lines].randomElement()
        case .circle: return .circle
        case .geometry: return .geometry
        case .sequence: return .sequence
        case .sets: return .sets
        case .complex: return .complexCalc
        case .calc: return nil
        }
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
        for (i, c) in coefficients.enumerated() where i < P.size { p.c[i] = c }
        return p
    }

    private static func nonZero(_ range: ClosedRange<Int>) -> Int {
        var n = 0
        while n == 0 { n = Int.random(in: range) }
        return n
    }

    private static func signed(_ n: Int) -> String { n >= 0 ? "+ \(n)" : "− \(-n)" }
    private static func f(_ v: Double) -> String { DoitMath.fraction(v) }
    private static func linearFactor(_ r: Int) -> String { r == 0 ? "x" : r > 0 ? "x − \(r)" : "x + \(-r)" }

    private static func generate(_ topic: Topic, hard: Bool) -> Made {
        switch topic {
        case .quadraticEquation:
            let a = hard ? [2, 3].randomElement()! : 1
            var r1 = Int.random(in: -6...6), r2 = Int.random(in: -6...6)
            while r1 == r2 { r2 = Int.random(in: -6...6) }
            let p = poly([Double(a * r1 * r2), Double(-a * (r1 + r2)), Double(a)])
            let big = max(r1, r2)
            return numeric("이차방정식 \(DoitMath.describe(p)) = 0 의 두 근 중 큰 근은?", answer: big,
                           steps: ["인수분해: \(a == 1 ? "" : "\(a)")(\(linearFactor(r1)))(\(linearFactor(r2))) = 0", "x = \(r1) 또는 x = \(r2)", "큰 근은 \(big)"])
        case .rootRelation:
            let a = hard ? [2, 3].randomElement()! : 1
            let b = Int.random(in: -9...9), c = nonZero(-9...9)
            let p = poly([Double(c), Double(b), Double(a)])
            let asks = Int.random(in: 0...(hard ? 2 : 1))
            let sum = -Double(b) / Double(a), product = Double(c) / Double(a)
            let value = asks == 0 ? sum : asks == 1 ? product : sum * sum - 2 * product
            guard value == value.rounded() else { return generate(.quadraticEquation, hard: hard) }
            let label = asks == 0 ? "α + β" : asks == 1 ? "αβ" : "α² + β²"
            var steps = ["α + β = −b/a = \(f(sum))", "αβ = c/a = \(f(product))"]
            if asks == 2 { steps.append("α² + β² = (α + β)² − 2αβ = \(f(value))") }
            return numeric("이차방정식 \(DoitMath.describe(p)) = 0 의 두 근을 α, β라 할 때 \(label)의 값은?", answer: Int(value), steps: steps)
        case .quadraticFunction:
            let a = [1, -1, 2, -2].randomElement()!
            let p0 = Int.random(in: -5...5), q0 = Int.random(in: -6...6)
            let fx = poly([Double(a * p0 * p0 + q0), Double(-2 * a * p0), Double(a)])
            if hard {
                return numeric("이차함수 y = \(DoitMath.describe(fx)) 의 \(a > 0 ? "최솟값" : "최댓값")은?", answer: q0,
                               steps: ["y = \(a == 1 ? "" : a == -1 ? "−" : "\(a)")(x \(signed(-p0)))² \(signed(q0))", "x = \(p0)일 때 \(a > 0 ? "최솟값" : "최댓값") \(q0)"])
            }
            let right = "(\(p0), \(q0))"
            let options = ["(\(-p0), \(q0))", "(\(p0), \(-q0))", "(\(q0), \(p0))", "(\(-p0), \(-q0))", "(\(p0 + 1), \(q0))", "(\(p0), \(q0 - 1))"]
            return choice("이차함수 y = \(DoitMath.describe(fx)) 의 꼭짓점의 좌표는?", right: right, wrong: options,
                          steps: ["x = −b/2a = \(p0)", "y = f(\(p0)) = \(q0)", "꼭짓점 \(right), \(a > 0 ? "최솟값" : "최댓값") \(q0)"])
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
            let fx = poly([Double(c), Double(b), Double(a), 1])
            let value = Int(DoitMath.value(fx, at: Double(r)))
            return numeric("다항식 f(x) = \(DoitMath.describe(fx)) 를 \(linearFactor(r))로 나눈 나머지는?", answer: value,
                           steps: ["나머지정리: 나머지 = f(\(r))", "f(\(r)) = \(value)"])
        case .expand:
            let p = nonZero(-7...7), q = nonZero(-7...7)
            let m = hard ? nonZero(2...3) : 1
            let coefficient = m * q + p
            let first = m == 1 ? "x" : "\(m)x"
            return numeric("(\(first) \(signed(p)))(x \(signed(q))) 를 전개했을 때 x의 계수는?", answer: coefficient,
                           steps: ["x 계수 = \(m)×\(q) + \(p)", "= \(coefficient)"])
        case .factor:
            var r1 = nonZero(-7...7), r2 = nonZero(-7...7)
            while r1 == -r2 && !hard { r2 = nonZero(-7...7) }
            if hard {
                // 삼차식: (x − r1)(x − r2)(x − r3)
                let r3 = nonZero(-3...3)
                let fx = (poly([Double(-r1), 1]) * poly([Double(-r2), 1])).flatMap { $0 * poly([Double(-r3), 1]) } ?? poly([0, 1])
                let sum = r1 + r2 + r3
                return numeric("\(DoitMath.describe(fx)) 를 인수분해하면 (x − a)(x − b)(x − c)일 때 a + b + c의 값은?", answer: sum,
                               steps: ["인수정리로 f(\(r3)) = 0 확인", "조립제법으로 나누면 (\(linearFactor(r3)))(\(DoitMath.describe(poly([Double(r1 * r2), Double(-(r1 + r2)), 1]))))", "(\(linearFactor(r1)))(\(linearFactor(r2)))(\(linearFactor(r3)))", "a + b + c = \(sum)"])
            }
            let fx = poly([Double(r1 * r2), Double(-(r1 + r2)), 1])
            let right = "(\(linearFactor(r1)))(\(linearFactor(r2)))"
            let wrong = ["(\(linearFactor(-r1)))(\(linearFactor(-r2)))", "(\(linearFactor(r1)))(\(linearFactor(-r2)))", "(\(linearFactor(-r1)))(\(linearFactor(r2)))",
                         "(\(linearFactor(r1 + 1)))(\(linearFactor(r2 - 1)))", "(\(linearFactor(r1 * r2)))(x − 1)"]
            return choice("\(DoitMath.describe(fx)) 를 인수분해한 것은?", right: right, wrong: wrong,
                          steps: ["곱해서 \(r1 * r2), 더해서 \(-(r1 + r2)) 이 되는 두 수: \(-r1), \(-r2)", right])
        case .complexCalc:
            let a = nonZero(-5...5), b = nonZero(-5...5), c = nonZero(-5...5), d = nonZero(-5...5)
            let re = a * c - b * d, im = a * d + b * c
            func z(_ x: Int, _ y: Int) -> String { "\(x) \(y < 0 ? "−" : "+") \(abs(y) == 1 ? "" : String(abs(y)))i" }
            if hard {
                return numeric("(\(z(a, b)))(\(z(c, d))) = p + qi 일 때 p + q 의 값은? (p, q는 실수)", answer: re + im,
                               steps: ["전개: \(a * c) + \(a * d)i + \(b * c)i + \(b * d)i²", "i² = −1 이므로 \(re) + \(im)i", "p + q = \(re + im)"])
            }
            let n = Int.random(in: 5...60)
            let cycle = ["1", "i", "−1", "−i"]
            return choice("i^\(n) 의 값은?", right: cycle[n % 4], wrong: cycle.filter { $0 != cycle[n % 4] } + ["0"],
                          steps: ["i의 거듭제곱은 i, −1, −i, 1 이 반복", "\(n) = 4×\(n / 4) + \(n % 4)", "i^\(n) = \(cycle[n % 4])"])
        case .discriminant:
            let k = Int.random(in: 1...9)
            let b = 2 * k
            // x² + bx + c = 0 이 중근을 가질 c
            return numeric("이차방정식 x² + \(b)x + c = 0 이 중근을 가질 때, 실수 c의 값은?", answer: k * k,
                           steps: ["중근 ⇔ D = 0", "D = \(b)² − 4c = 0", "c = \(k * k)"])
        case .cubic:
            let r = nonZero(-3...3), s = nonZero(-4...4), t = nonZero(-4...4)
            let fx = (poly([Double(-r), 1]) * poly([Double(-s), 1])).flatMap { $0 * poly([Double(-t), 1]) } ?? poly([0, 1])
            let roots = Set([r, s, t])
            return numeric("삼차방정식 \(DoitMath.describe(fx)) = 0 의 모든 실근의 합은? (중근은 한 번만)", answer: roots.reduce(0, +),
                           steps: ["인수정리: f(\(r)) = 0", "조립제법으로 인수분해: (\(linearFactor(r)))(\(linearFactor(s)))(\(linearFactor(t))) = 0", "서로 다른 근: \(roots.sorted().map(String.init).joined(separator: ", "))"])
        case .system:
            let x = Int.random(in: -6...6), y = Int.random(in: -6...6)
            var a1 = nonZero(-4...4), b1 = nonZero(-4...4), a2 = nonZero(-4...4), b2 = nonZero(-4...4)
            while a1 * b2 - a2 * b1 == 0 { a1 = nonZero(-4...4); b1 = nonZero(-4...4); a2 = nonZero(-4...4); b2 = nonZero(-4...4) }
            func eq(_ a: Int, _ b: Int) -> String {
                let ax = a == 1 ? "x" : a == -1 ? "−x" : "\(a)x"
                let by = abs(b) == 1 ? "y" : "\(abs(b))y"
                return "\(ax.replacingOccurrences(of: "-", with: "−")) \(b < 0 ? "−" : "+") \(by) = \(a * x + b * y)"
            }
            return numeric("연립방정식 \(eq(a1, b1)), \(eq(a2, b2)) 의 해를 x = p, y = q 라 할 때 p + q 의 값은?", answer: x + y,
                           steps: ["가감법으로 한 문자를 없애요", "x = \(x), y = \(y)", "p + q = \(x + y)"])
        case .inequality:
            let a = nonZero(-5...5), x0 = Int.random(in: -6...6), b = Int.random(in: -9...9)
            let c = a * x0 + b
            let op = ["<", ">", "≤", "≥"].randomElement()!
            let flipped = a < 0 ? ["<": ">", ">": "<", "≤": "≥", "≥": "≤"][op]! : op
            let left = DoitMath.describe(poly([Double(b), Double(a)]))
            let right = "x \(flipped) \(x0)"
            let others = ["<", ">", "≤", "≥"].filter { $0 != flipped }.map { "x \($0) \(x0)" } + ["x \(flipped) \(-x0)", "x \(flipped) \(x0 + 1)"]
            return choice("부등식 \(left) \(op) \(c) 의 해는?", right: right, wrong: others,
                          steps: ["\(a)x \(op) \(c - b)", a < 0 ? "음수 \(a)로 나누면 부등호 방향이 바뀌어요" : "\(a)로 나누면", right])
        case .quadInequality:
            var r1 = Int.random(in: -6...6), r2 = Int.random(in: -6...6)
            while r1 == r2 { r2 = Int.random(in: -6...6) }
            let lo = min(r1, r2), hi = max(r1, r2)
            let fx = poly([Double(lo * hi), Double(-(lo + hi)), 1])
            if Bool.random() {
                let count = hi - lo - 1
                return numeric("이차부등식 \(DoitMath.describe(fx)) < 0 을 만족하는 정수 x의 개수는?", answer: count,
                               steps: ["(\(linearFactor(lo)))(\(linearFactor(hi))) < 0", "\(lo) < x < \(hi)", "정수는 \(count)개"])
            }
            let right = "x ≤ \(lo) 또는 x ≥ \(hi)"
            return choice("이차부등식 \(DoitMath.describe(fx)) ≥ 0 의 해는?", right: right,
                          wrong: ["\(lo) ≤ x ≤ \(hi)", "x < \(lo) 또는 x > \(hi)", "\(lo) < x < \(hi)", "x ≤ \(-hi) 또는 x ≥ \(-lo)"],
                          steps: ["(\(linearFactor(lo)))(\(linearFactor(hi))) ≥ 0", "두 근 바깥쪽 (근 포함)", right])
        case .sumProduct:
            let a = Int.random(in: 2...6), b = Int.random(in: 2...6)
            if Bool.random() {
                return numeric("A 지역에서 B 지역으로 가는 길이 \(a)가지, B에서 C로 가는 길이 \(b)가지일 때, A에서 B를 거쳐 C로 가는 방법의 수는?", answer: a * b,
                               steps: ["잇달아 일어나면 곱의 법칙", "\(a) × \(b) = \(a * b)"])
            }
            return numeric("서로 다른 소설책 \(a)권과 만화책 \(b)권 중에서 한 권을 고르는 방법의 수는?", answer: a + b,
                           steps: ["동시에 일어나지 않으면 합의 법칙", "\(a) + \(b) = \(a + b)"])
        case .permutation:
            let n = Int.random(in: 4...8), r = Int.random(in: 2...3)
            let value = Int(DoitMathTopics.permutation(n, r))
            return numeric("\(n)명 중에서 회장 1명, 부회장 1명\(r == 3 ? ", 총무 1명" : "")을 뽑는 방법의 수는?", answer: value,
                           steps: ["순서(역할)가 있으므로 순열", "₍\(n)₎P₍\(r)₎ = \((0..<r).map { String(n - $0) }.joined(separator: "×"))", "= \(value)"])
        case .combination:
            let n = Int.random(in: 5...10), r = Int.random(in: 2...3)
            let value = Int(DoitMathTopics.combination(n, r))
            return numeric("\(n)명 중에서 대표 \(r)명을 뽑는 방법의 수는?", answer: value,
                           steps: ["순서가 없으므로 조합", "₍\(n)₎C₍\(r)₎ = ₍\(n)₎P₍\(r)₎ ÷ \(r)!", "= \(value)"])
        case .matrix:
            let a = (0..<4).map { _ in Int.random(in: -3...4) }, b = (0..<4).map { _ in Int.random(in: -3...4) }
            func m(_ v: [Int]) -> String { "(\(v[0])  \(v[1]) / \(v[2])  \(v[3]))" }
            if hard {
                let product = [a[0] * b[0] + a[1] * b[2], a[0] * b[1] + a[1] * b[3], a[2] * b[0] + a[3] * b[2], a[2] * b[1] + a[3] * b[3]]
                let sum = product.reduce(0, +)
                return numeric("두 행렬 A = \(m(a)), B = \(m(b)) 에 대해 AB의 모든 성분의 합은? (/ 앞은 1행, 뒤는 2행)", answer: sum,
                               steps: ["(i, j) 성분 = A의 i행과 B의 j열을 차례로 곱해 더한 값", "AB = \(m(product))", "성분의 합 = \(sum)"])
            }
            let k = Int.random(in: 2...3)
            let result = zip(a, b).map { k * $0 - $1 }
            return numeric("두 행렬 A = \(m(a)), B = \(m(b)) 에 대해 \(k)A − B 의 모든 성분의 합은? (/ 앞은 1행, 뒤는 2행)", answer: result.reduce(0, +),
                           steps: ["같은 위치의 성분끼리 계산", "\(k)A − B = \(m(result))", "합 = \(result.reduce(0, +))"])
        case .distance:
            let triples = [(3, 4, 5), (6, 8, 10), (5, 12, 13), (8, 6, 10), (9, 12, 15)]
            let (dx, dy, d) = triples.randomElement()!
            let x1 = Int.random(in: -5...5), y1 = Int.random(in: -5...5)
            let sx = Bool.random() ? 1 : -1, sy = Bool.random() ? 1 : -1
            return numeric("두 점 A(\(x1), \(y1)), B(\(x1 + sx * dx), \(y1 + sy * dy)) 사이의 거리는?", answer: d,
                           steps: ["AB = √((x₂−x₁)² + (y₂−y₁)²)", "√(\(dx)² + \(dy)²) = √\(d * d)", "= \(d)"])
        case .internalDivision:
            let m = Int.random(in: 1...3), n = Int.random(in: 1...3)
            let x1 = Int.random(in: -6...6), x2 = x1 + (m + n) * Int.random(in: -2...2)
            let y1 = Int.random(in: -6...6), y2 = y1 + (m + n) * nonZero(-2...2)
            let px = (m * x2 + n * x1) / (m + n), py = (m * y2 + n * y1) / (m + n)
            return numeric("두 점 A(\(x1), \(y1)), B(\(x2), \(y2))에 대하여 선분 AB를 \(m):\(n)으로 내분하는 점의 좌표를 (a, b)라 할 때 a + b의 값은?", answer: px + py,
                           steps: ["내분점 = ((mx₂ + nx₁)/(m+n), (my₂ + ny₁)/(m+n))", "(\(px), \(py))", "a + b = \(px + py)"])
        case .lines:
            let m = nonZero(-4...4), b = Int.random(in: -5...5), x0 = Int.random(in: -3...3), y0 = Int.random(in: -5...5)
            if Bool.random() {
                let k = y0 - m * x0
                return numeric("직선 y = \(m)x \(signed(b)) 에 평행하고 점 (\(x0), \(y0))을 지나는 직선의 y절편은?", answer: k,
                               steps: ["평행하면 기울기가 같아요: \(m)", "y − \(y0) = \(m)(x − \(x0))", "y절편 = \(k)"])
            }
            // 수직: 기울기 곱 −1 → 정수 기울기 ±1
            let s = [1, -1].randomElement()!
            let k = y0 + s * x0
            return numeric("직선 y = \(s == 1 ? "" : "−")x \(signed(b)) 에 수직이고 점 (\(x0), \(y0))을 지나는 직선의 y절편은?", answer: k,
                           steps: ["수직이면 기울기의 곱이 −1: \(-s)", "y − \(y0) = \(-s)(x − \(x0))", "y절편 = \(k)"])
        case .circle:
            let a = Int.random(in: -5...5), b = Int.random(in: -5...5), r = Int.random(in: 1...6)
            let D = -2 * a, E = -2 * b, F = a * a + b * b - r * r
            func term(_ v: Int, _ name: String) -> String { v == 0 ? "" : " \(v < 0 ? "−" : "+") \(abs(v) == 1 ? "" : String(abs(v)))\(name)" }
            let eq = "x² + y²\(term(D, "x"))\(term(E, "y"))\(F == 0 ? "" : " \(F < 0 ? "−" : "+") \(abs(F))") = 0"
            return numeric("원 \(eq) 의 반지름의 길이는?", answer: r,
                           steps: ["완전제곱식으로: (x \(signed(-a)))² + (y \(signed(-b)))² = \(r * r)", "중심 (\(a), \(b)), 반지름 \(r)"])
        case .translation:
            let x = Int.random(in: -5...5), y = Int.random(in: -5...5), dx = nonZero(-4...4), dy = nonZero(-4...4)
            switch Int.random(in: 0...2) {
            case 0:
                return numeric("점 (\(x), \(y))를 x축 방향으로 \(dx)만큼, y축 방향으로 \(dy)만큼 평행이동한 점을 (a, b)라 할 때 a + b의 값은?", answer: x + dx + y + dy,
                               steps: ["(x + m, y + n)", "(\(x + dx), \(y + dy))", "a + b = \(x + dx + y + dy)"])
            case 1:
                return numeric("점 (\(x), \(y))를 직선 y = x 에 대하여 대칭이동한 점을 (a, b)라 할 때 a − b의 값은?", answer: y - x,
                               steps: ["y = x 대칭: x, y를 바꿔요", "(\(y), \(x))", "a − b = \(y - x)"])
            default:
                return numeric("점 (\(x), \(y))를 원점에 대하여 대칭이동한 점을 (a, b)라 할 때 a + 2b의 값은?", answer: -x - 2 * y,
                               steps: ["원점 대칭: 부호를 모두 바꿔요", "(\(-x), \(-y))", "a + 2b = \(-x - 2 * y)"])
            }
        case .sets:
            let a = Int.random(in: 8...20), b = Int.random(in: 6...18), inter = Int.random(in: 1...min(a, b) - 1)
            return numeric("두 집합 A, B에 대하여 n(A) = \(a), n(B) = \(b), n(A∩B) = \(inter)일 때 n(A∪B)는?", answer: a + b - inter,
                           steps: ["n(A∪B) = n(A) + n(B) − n(A∩B)", "\(a) + \(b) − \(inter) = \(a + b - inter)"])
        case .proposition:
            // (명제, 역, 이, 대우)
            let sets: [(String, String, String, String)] = [
                ("x = 2이면 x² = 4이다", "x² = 4이면 x = 2이다", "x ≠ 2이면 x² ≠ 4이다", "x² ≠ 4이면 x ≠ 2이다"),
                ("x > 3이면 x > 1이다", "x > 1이면 x > 3이다", "x ≤ 3이면 x ≤ 1이다", "x ≤ 1이면 x ≤ 3이다"),
                ("x가 4의 배수이면 x는 2의 배수이다", "x가 2의 배수이면 x는 4의 배수이다", "x가 4의 배수가 아니면 x는 2의 배수가 아니다", "x가 2의 배수가 아니면 x는 4의 배수가 아니다"),
                ("두 삼각형이 합동이면 넓이가 같다", "두 삼각형의 넓이가 같으면 합동이다", "두 삼각형이 합동이 아니면 넓이가 같지 않다", "두 삼각형의 넓이가 같지 않으면 합동이 아니다"),
                ("x = 1이면 x² − 1 = 0이다", "x² − 1 = 0이면 x = 1이다", "x ≠ 1이면 x² − 1 ≠ 0이다", "x² − 1 ≠ 0이면 x ≠ 1이다")
            ]
            let (original, converse, inverse, contrapositive) = sets.randomElement()!
            let kind = Int.random(in: 0...2)
            let names = ["대우", "역", "이"], answers = [contrapositive, converse, inverse]
            let right = "'\(answers[kind])'"
            return choice("명제 '\(original)'의 \(names[kind])는?", right: right,
                          wrong: ["'\(contrapositive)'", "'\(converse)'", "'\(inverse)'", "'\(original)'"],
                          steps: ["역: 가정과 결론을 바꿈 / 이: 둘 다 부정 / 대우: 바꾸고 둘 다 부정", right, "명제가 참이면 대우도 참 (역과 이는 참인지 따로 확인)"])
        case .amgm:
            let a = Int.random(in: 1...4), k = Int.random(in: 1...4)
            let b = a * k * k
            return numeric("x > 0 일 때, \(a == 1 ? "" : String(a))x + \(b)/x 의 최솟값은?", answer: 2 * a * k,
                           steps: ["산술·기하평균: \(a == 1 ? "" : String(a))x + \(b)/x ≥ 2√(\(a)x × \(b)/x)", "= 2√\(a * b) = \(2 * a * k)", "등호는 x = \(k)일 때"])
        case .composite:
            let a = nonZero(-3...3), b = Int.random(in: -5...5), c = nonZero(-3...3), d = Int.random(in: -5...5), x = Int.random(in: -3...3)
            let g = c * x + d, value = a * g + b
            return numeric("f(x) = \(DoitMath.describe(poly([Double(b), Double(a)]))), g(x) = \(DoitMath.describe(poly([Double(d), Double(c)]))) 일 때 (f∘g)(\(x))의 값은?", answer: value,
                           steps: ["(f∘g)(\(x)) = f(g(\(x)))", "g(\(x)) = \(g)", "f(\(g)) = \(value)"])
        case .inverse:
            let a = nonZero(-4...4), b = Int.random(in: -6...6), k = Int.random(in: -4...4)
            let y = a * k + b
            return numeric("f(x) = \(DoitMath.describe(poly([Double(b), Double(a)]))) 일 때 f⁻¹(\(y))의 값은?", answer: k,
                           steps: ["f⁻¹(\(y)) = t 이면 f(t) = \(y)", "\(a)t \(signed(b)) = \(y)", "t = \(k)"])
        case .rational:
            let k = nonZero(-5...5), p = Int.random(in: -5...5), q = Int.random(in: -5...5)
            return numeric("유리함수 y = \(k)/(\(p == 0 ? "x" : "x " + signed(-p)))\(q == 0 ? "" : " " + signed(q)) 의 그래프의 두 점근선의 교점을 (a, b)라 할 때 a + b의 값은?", answer: p + q,
                           steps: ["y = k/(x − p) + q 의 점근선: x = p, y = q", "x = \(p), y = \(q)", "a + b = \(p + q)"])
        case .irrational:
            let a = [1, 2, 3].randomElement()!, b = Int.random(in: -6...6) * a, c = Int.random(in: -5...5)
            let start = -b / a
            return numeric("무리함수 y = √(\(a == 1 ? "" : String(a))x\(b == 0 ? "" : " " + signed(b)))\(c == 0 ? "" : " " + signed(c)) 의 정의역이 {x | x ≥ a}, 치역이 {y | y ≥ b}일 때 a + b의 값은?", answer: start + c,
                           steps: ["근호 안 ≥ 0 → x ≥ \(start)", "치역 y ≥ \(c)", "a + b = \(start + c)"])
        case .derivative:
            let a = nonZero(-3...3), b = Int.random(in: -5...5), c = Int.random(in: -5...5), x0 = Int.random(in: -3...3)
            let fx = poly([Double(Int.random(in: -5...5)), Double(c), Double(b), Double(a)])
            let value = 3 * a * x0 * x0 + 2 * b * x0 + c
            return numeric("f(x) = \(DoitMath.describe(fx)) 일 때 f'(\(x0))의 값은?", answer: value,
                           steps: ["f'(x) = \(DoitMath.describe(DoitAlgebra.derive(fx)))", "f'(\(x0)) = \(value)"])
        case .integral:
            let a = Int.random(in: 1...3) * 3, b = Int.random(in: -4...4) * 2, hi = Int.random(in: 1...3)
            // ∫0^hi (a x² + b x) dx = a/3 hi³ + b/2 hi²
            let value = a / 3 * hi * hi * hi + b / 2 * hi * hi
            return numeric("정적분 ∫₀^\(hi) (\(DoitMath.describe(poly([0, Double(b), Double(a)]))))dx 의 값은?", answer: value,
                           steps: ["부정적분 F(x) = \(DoitMath.describe(poly([0, 0, Double(b / 2), Double(a / 3)])))", "F(\(hi)) − F(0) = \(value)"])
        case .sequence:
            let a = Int.random(in: -5...9), d = nonZero(-4...5), n = Int.random(in: 5...20)
            if Bool.random() {
                return numeric("첫째항이 \(a), 공차가 \(d)인 등차수열의 제\(n)항은?", answer: a + (n - 1) * d,
                               steps: ["aₙ = a + (n − 1)d", "\(a) + \(n - 1)×\(d) = \(a + (n - 1) * d)"])
            }
            let r = [2, 3, -2].randomElement()!, m = Int.random(in: 3...6), first = Int.random(in: 1...3)
            let value = first * Int(pow(Double(r), Double(m - 1)))
            return numeric("첫째항이 \(first), 공비가 \(r)인 등비수열의 제\(m)항은?", answer: value, steps: ["aₙ = arⁿ⁻¹", "\(first)×(\(r))^\(m - 1) = \(value)"])
        case .statistics:
            let count = 5
            var values = (0..<count).map { _ in Int.random(in: 1...10) }
            let total = values.reduce(0, +)
            let fix = (5 - total % 5) % 5
            values[0] += fix
            let mean = values.reduce(0, +) / count
            return numeric("자료 \(values.map(String.init).joined(separator: ", "))의 평균은?", answer: mean,
                           steps: ["합 = \(values.reduce(0, +))", "평균 = 합 ÷ \(count) = \(mean)"])
        case .numberTheory:
            let g = Int.random(in: 2...9), a = g * Int.random(in: 2...7), b = g * Int.random(in: 2...7)
            let gcd = DoitAlgebra.gcd(a, b)
            return numeric("\(a)와 \(b)의 최대공약수는?", answer: gcd,
                           steps: ["\(a) = \(DoitMathTopics.factorText(DoitMathTopics.primeFactors(a)))", "\(b) = \(DoitMathTopics.factorText(DoitMathTopics.primeFactors(b)))", "공통 소인수의 곱 = \(gcd)"])
        case .percent:
            let price = Int.random(in: 2...20) * 1000, rate = [10, 20, 25, 30, 40].randomElement()!
            return numeric("\(price)원짜리 물건을 \(rate)% 할인하면 얼마인가요?", answer: price * (100 - rate) / 100,
                           steps: ["할인 금액 = \(price) × \(rate)/100 = \(price * rate / 100)", "\(price) − \(price * rate / 100) = \(price * (100 - rate) / 100)"])
        case .geometry:
            let triples = [(3, 4, 5), (5, 12, 13), (6, 8, 10), (8, 15, 17), (7, 24, 25)]
            let (a, b, c) = triples.randomElement()!
            return numeric("직각을 낀 두 변의 길이가 \(a), \(b)인 직각삼각형의 빗변의 길이는?", answer: c,
                           steps: ["피타고라스 정리: c² = a² + b²", "\(a)² + \(b)² = \(c * c)", "c = \(c)"])
        }
    }

    /// 답이 정수인 문제: 헷갈리기 쉬운 오답 4개를 섞어서 보기 5개
    private static func numeric(_ question: String, answer: Int, steps: [String]) -> Made {
        var wrong: [Int] = []
        // 답이 양수면 음수 보기는 넣지 않음 (경우의 수, 길이, 가격 등)
        let candidates = answer > 0
            ? [answer + 1, answer - 1, answer + 2, answer * 2, answer - 2, answer + 3, answer + 5, answer + 10].filter { $0 >= 0 }
            : [-answer, answer + 1, answer - 1, answer + 2, answer - 2, answer * 2, answer + 3, answer - 3, answer + 4]
        for candidate in candidates
        where candidate != answer && !wrong.contains(candidate) {
            wrong.append(candidate)
            if wrong.count == 4 { break }
        }
        let choices = ([answer] + wrong).shuffled().map(String.init)
        let index = choices.firstIndex(of: String(answer)) ?? 0
        return Made(question: question, answer: String(answer), steps: steps, choices: choices, answerNumber: index + 1)
    }

    /// 답이 글자인 문제
    private static func choice(_ question: String, right: String, wrong: [String], steps: [String]) -> Made {
        var unique: [String] = []
        for w in wrong where w != right && !unique.contains(w) { unique.append(w) }
        let choices = ([right] + unique.shuffled().prefix(4)).shuffled()
        return Made(question: question, answer: right, steps: steps, choices: choices, answerNumber: (choices.firstIndex(of: right) ?? 0) + 1)
    }
}
