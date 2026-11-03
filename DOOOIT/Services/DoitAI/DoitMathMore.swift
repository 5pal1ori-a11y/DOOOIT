import Foundation

/// 모티 AI 수학 풀이 더 (외부 AI 없이): 지금까지 풀지 못하던 유형을 한곳에서 먼저 확인해요
/// - 조건제시법 집합, 도수분포표, 상수가 여러 개인 조건, 정적분으로 정의된 함수
/// - 지수·로그·삼각방정식, 시그마, "1 + 3 + … + 19" 꼴의 합, 공비가 ±인 등비수열, 세 수의 등차·등비중항
/// - 이웃하는/이웃하지 않는 배열, 교대로 서기, 원탁의 이웃, 방정식의 음이 아닌 정수해, 같은 것이 있는 순열, 이항정리
/// - 연립방정식 문장제, 만남·기차·강물·일·시계, 꼭짓점 이름이 붙은 도형
enum DoitMathMore {
    typealias Solved = MathSolver.Solved

    private static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }
    private static func f(_ v: Double) -> String { DoitMath.fraction(v) }
    private static func d(_ v: Double) -> String { DoitMath.format(v, digits: 8) }
    private static func match(_ t: String, _ p: String) -> [String]? { DoitMathExact.match(t, p) }
    private static func matches(_ t: String, _ p: String) -> [[String]] { DoitMathExact.matches(t, p) }
    private static let num = #"(-?\d+(?:\.\d+)?(?:/\d+)?)"#

    /// 앞쪽에서 먼저 확인 (모양이 분명한 것만)
    static func solve(_ t: String) -> Solved? {
        if let s = DoitMathFigures.sets(t) { return s }
        if let s = table(t) { return s }
        if let s = relativeFrequency(t) { return s }
        if let s = integralDefined(t) { return s }
        if let s = DoitMathConstants.solve(t) { return s }
        if let s = transcendental(t) { return s }
        if let s = sigma(t) { return s }
        if let s = series(t) { return s }
        if let s = geometricBoth(t) { return s }
        if let s = arithmeticAsked(t) { return s }
        if let s = middleTerm(t) { return s }
        if let s = arrangements(t) { return s }
        if let s = binomialTerm(t) { return s }
        if let s = DoitMathWord2.letterSystem(t) { return s }
        if let s = DoitMathWord2.solve(t) { return s }
        if let s = DoitMathFigures.triangle(t) { return s }
        if let s = extras(t) { return s }
        return nil
    }

    // MARK: - 그 밖의 자주 나오는 유형

    static func extras(_ t: String) -> Solved? {
        if let s = substitutionValue(t) { return s }
        if let s = pointOnGraph(t) { return s }
        if let s = definiteConstant(t) { return s }
        if let s = parallelLine(t) { return s }
        if let s = circleTangent(t) { return s }
        if let s = arithmeticSum(t) { return s }
        if let s = cardProbability(t) { return s }
        if let s = ballsIntoBoxes(t) { return s }
        if let s = twoLetterBinomial(t) { return s }
        return nil
    }

    /// "x가 3일 때 2x + 1의 값", "x = 2, y = −1일 때 3x − 2y의 값", "a = 2, b = −3일 때 a² − ab의 값"
    private static func substitutionValue(_ t: String) -> Solved? {
        var values: [Character: Double] = [:]
        for m in matches(t, #"(?<![a-zA-Z+\-*/^=)])(?<![+\-*/^=)]\s)([a-z])\s*(?:가|이|는|=|의 값이)\s*"# + num + #"(?![0-9])\s*(?:,|이고|일|이면|이라|라)"#) {
            guard let c = m[1].first, let v = DoitMathConstants.value(m[2]) else { continue }
            values[c] = v
        }
        guard !values.isEmpty else { return nil }
        var found: String?
        if let m = match(t, #"(?:일\s*때|이면|라\s*할\s*때|일때)\s*,?\s*([0-9a-z+\-*/^().√ ]+?)\s*의\s*값"#) { found = m[1] }
        else if let range = t.range(of: #"(?:일\s*때|이면)\s*,?\s*다음\s*식의\s*값"#, options: .regularExpression) {
            // "x = −1일 때, 다음 식의 값을 구하시오. 2x² − x + 3"
            let rest = String(t[range.upperBound...])
            found = DoitMathConstants.runs(rest).map(\.text).filter { $0.contains(where: { values[$0] != nil }) && !$0.contains("=") }.max(by: { $0.count < $1.count })
        }
        guard let expression = found?.trimmingCharacters(in: .whitespaces), !expression.isEmpty else { return nil }
        let letters = Set(expression.filter { $0.isLetter })
        guard !letters.isEmpty, letters.isSubset(of: Set(values.keys)), let node = DoitMathExact.node(expression, variables: letters), let v = node.eval(values) else { return nil }
        var filled = ""
        var previous: Character = " "
        for ch in expression {
            if let x = values[ch] {
                if previous.isNumber || previous == ")" || values[previous] != nil { filled += "×" }
                filled += x < 0 ? "(\(f(x)))" : f(x)
            } else { filled.append(ch) }
            if ch != " " { previous = ch }
        }
        let shown = filled.replacingOccurrences(of: "*", with: " × ")
        guard let text = DoitMathFigures.nice(v) ?? Optional(DoitMath.format(v, digits: 8)) else { return nil }
        return Solved(kind: .expression, topic: "식의 값", concept: "문자에 수를 넣을 때는 생략된 곱셈 기호를 되살리고, 음수는 괄호를 씌워서 넣어요.",
                      steps: [SolutionStep(hint: "문자 대신 수를 넣으면", work: shown), SolutionStep(hint: "계산하면", work: text)], answer: text)
    }

    /// 점 (a, 2)가 직선 y = 3x − 4 위에 있을 때 a
    private static func pointOnGraph(_ t: String) -> Solved? {
        guard has(t, ["위에 있", "위의 점", "지날", "지나"]), let m = match(t, #"\(\s*([a-z]|-?\d+(?:\.\d+)?)\s*,\s*([a-z]|-?\d+(?:\.\d+)?)\s*\)"#) else { return nil }
        let xLetter = m[1].first.map { $0.isLetter } ?? false, yLetter = m[2].first.map { $0.isLetter } ?? false
        guard xLetter != yLetter else { return nil }
        let letter = xLetter ? m[1] : m[2]
        guard letter != "x", letter != "y", let known = Double(xLetter ? m[2] : m[1]) else { return nil }
        // 함수 y = F(x)
        var F: DoitMath.Poly?
        for run in DoitMathConstants.runs(t) {
            guard let mm = match(run.text, #"^(?:y|f\(x\))\s*=\s*(.+)$"#), !mm[1].contains(letter), let p = DoitMath.polynomial(mm[1]), p.degree >= 1 else { continue }
            F = p
            break
        }
        guard let f0 = F else { return nil }
        var roots: [String]
        var work: String
        if xLetter {
            // F(a) = known
            var g = f0
            g.c[0] -= known
            let r = DoitAlgebra.realRoots(g)
            guard !r.isEmpty, r.count <= 2 else { return nil }
            roots = r.map(\.label)
            work = "\(DoitMath.describe(f0).replacingOccurrences(of: "x", with: letter)) = \(f(known))"
        } else {
            roots = [f(DoitMath.value(f0, at: known))]
            work = "\(letter) = f(\(f(known)))"
        }
        if has(t, ["양수 \(letter)", "\(letter) > 0"]) { roots = roots.filter { ($0.hasPrefix("−") || $0.hasPrefix("-")) == false && $0 != "0" } }
        guard !roots.isEmpty else { return nil }
        return Solved(kind: .coordinate, topic: "그래프 위의 점", concept: "점 (p, q)가 그래프 위에 있으면 x = p, y = q를 식에 넣었을 때 등식이 성립해요.",
                      steps: [SolutionStep(hint: "점의 좌표를 식에 넣으면", work: work), SolutionStep(hint: "풀면", work: roots.map { "\(letter) = \($0)" }.joined(separator: " 또는 "))],
                      answer: roots.map { "\(letter) = \($0)" }.joined(separator: " 또는 "))
    }

    /// ∫₀¹ (ax + 1) dx = 3 → a
    private static func definiteConstant(_ raw: String) -> Solved? {
        guard raw.contains("∫"), raw.contains("=") else { return nil }
        let subs: [Character: String] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9"]
        var t = ""
        var inSub = false
        for ch in raw {
            if let v = subs[ch] { if !inSub { t += "_" }; t += v; inSub = true } else { inSub = false; t.append(ch) }
        }
        t = DoitMathExact.superscriptsToPowers(t).replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        guard let m = match(t, #"∫\s*_\s*\(?(-?\d+)\)?\s*\^\s*\(?(-?\d+)\)?\s*(.+?)\s*d\s*x\s*=\s*"# + num + "(?![0-9])"),
              let lo = Double(m[1]), let hi = Double(m[2]), let target = DoitMathConstants.value(m[4]) else { return nil }
        let letters = Set(m[3].filter { "abckmnpq".contains($0) })
        guard letters.count == 1, let u = letters.first else { return nil }
        guard let g = DoitMathConstants.parse(m[3], variables: [u, "x"]) else { return nil }
        // 항마다 적분: x^k → x^(k+1)/(k+1)
        var antiderivative = DoitMathConstants.GPoly()
        let top = max(0, g.degree(in: "x"))
        for k in 0...top {
            let c = g.coefficient("x", k)
            antiderivative = antiderivative + c * DoitMathConstants.GPoly.variable("x").power(k + 1).scaled(1 / Double(k + 1))
        }
        let value = antiderivative.substitute("x", hi) - antiderivative.substitute("x", lo) - DoitMathConstants.GPoly.constant(target)
        guard let sols = DoitMathConstants.solveEquations([value], unknowns: [u]), sols.count == 1, let v = sols[0][u] else { return nil }
        return Solved(kind: .integral, topic: "정적분의 값으로 상수 구하기", concept: "적분 안의 상수는 그대로 두고 정적분을 계산한 뒤, 주어진 값과 같다고 놓고 풀어요.",
                      steps: [SolutionStep(hint: "부정적분", work: DoitMathConstants.describe(antiderivative)),
                              SolutionStep(hint: "[F(x)]\(f(lo))→\(f(hi)) = \(f(target))", work: DoitMathConstants.equationText(value)),
                              SolutionStep(hint: "풀면", work: "\(u) = \(f(v))")],
                      answer: "\(u) = \(f(v))")
    }

    /// 직선 …에 평행(수직)하고 점 (p, q)를 지나는 직선
    private static func parallelLine(_ t: String) -> Solved? {
        guard has(t, ["평행", "수직"]), has(t, ["지나"]), has(t, ["직선"]) else { return nil }
        let pts = DoitMathTopics.points(in: t)
        guard pts.count == 1, let p = pts.first else { return nil }
        var slope: Double?
        var shown = ""
        for run in DoitMathConstants.runs(t) where run.text.contains("=") && run.text.contains("x") {
            let sides = run.text.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
            guard sides.count == 2, let l = DoitAlgebra.parse(sides[0]), let r = DoitAlgebra.parse(sides[1]) else { continue }
            let e = l - r
            guard e.degree == 1, abs(e.coef(y: 1)) > 1e-12 else { continue }
            slope = -e.coef(x: 1) / e.coef(y: 1)
            shown = run.text
            break
        }
        guard var m = slope else { return nil }
        let perpendicular = has(t, ["수직"]) && !has(t, ["평행"])
        if perpendicular {
            guard abs(m) > 1e-12 else { return nil }
            m = -1 / m
        }
        var line = DoitMath.Poly()
        line.c[1] = m
        line.c[0] = p.y - m * p.x
        return Solved(kind: .coordinate, topic: perpendicular ? "수직인 직선의 방정식" : "평행한 직선의 방정식",
                      concept: "평행한 두 직선은 기울기가 같고, 수직인 두 직선은 기울기의 곱이 −1이에요. 기울기 m, 점 (x₁, y₁)을 지나는 직선: y − y₁ = m(x − x₁)",
                      steps: [SolutionStep(hint: "\(shown)의 기울기", work: f(perpendicular ? -1 / m : m)),
                              SolutionStep(hint: perpendicular ? "수직이면 기울기는 −1/m" : "평행하면 기울기가 같아요", work: "m = \(f(m))"),
                              SolutionStep(hint: "점 \(p.label)을 지나므로", work: "y − (\(f(p.y))) = \(f(m))(x − (\(f(p.x))))")],
                      answer: "y = \(DoitMath.describe(line))")
    }

    /// 원 위의 점에서의 접선
    private static func circleTangent(_ t: String) -> Solved? {
        guard has(t, ["접선"]), has(t, ["원"]), has(t, ["위의 점"]) else { return nil }
        let pts = DoitMathTopics.points(in: t)
        guard pts.count == 1, let p = pts.first else { return nil }
        var circle: (Double, Double, Double)?
        for run in DoitMathConstants.runs(t) where run.text.contains("y") && run.text.contains("=") {
            let sides = run.text.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
            guard sides.count == 2, let l = DoitAlgebra.parse(sides[0]), let r = DoitAlgebra.parse(sides[1]) else { continue }
            let e = l - r
            let a2 = e.coef(x: 2)
            guard abs(a2) > 1e-12, abs(a2 - e.coef(y: 2)) < 1e-12, abs(e.coef(x: 1, y: 1)) < 1e-12 else { continue }
            let cx = -e.coef(x: 1) / a2 / 2, cy = -e.coef(y: 1) / a2 / 2
            let r2 = cx * cx + cy * cy - e.constantValue / a2
            guard r2 > 0 else { return nil }
            circle = (cx, cy, r2)
        }
        guard let (a, b, r2) = circle, abs((p.x - a) * (p.x - a) + (p.y - b) * (p.y - b) - r2) < 1e-9 else { return nil }
        let nx = p.x - a, ny = p.y - b
        let k = nx * p.x + ny * p.y
        let answer: String
        if abs(ny) < 1e-12 { answer = "x = \(f(p.x))" } else {
            var line = DoitMath.Poly()
            line.c[1] = -nx / ny
            line.c[0] = k / ny
            answer = "\(general(nx, ny, k)) (y = \(DoitMath.describe(line)))"
        }
        return Solved(kind: .circle, topic: "원 위의 점에서의 접선", concept: "원 (x − a)² + (y − b)² = r² 위의 점 (x₁, y₁)에서의 접선: (x₁ − a)(x − a) + (y₁ − b)(y − b) = r² (접선은 반지름과 수직)",
                      steps: [SolutionStep(hint: "중심 (\(f(a)), \(f(b))), 반지름² = \(f(r2))", work: "(\(f(nx)))(x − \(f(a))) + (\(f(ny)))(y − \(f(b))) = \(f(r2))"),
                              SolutionStep(hint: "정리하면", work: answer)],
                      answer: answer)
    }

    /// ax + by = k 꼴 글자 (정수로 맞춰서)
    private static func general(_ a: Double, _ b: Double, _ k: Double) -> String {
        func term(_ c: Double, _ v: String, first: Bool) -> String {
            guard abs(c) > 1e-12 else { return "" }
            let mag = abs(c)
            let body = (abs(mag - 1) < 1e-12 ? "" : f(mag)) + v
            if first { return c < 0 ? "−" + body : body }
            return c < 0 ? " − " + body : " + " + body
        }
        let x = term(a, "x", first: true)
        let y = term(b, "y", first: x.isEmpty)
        return "\(x)\(y) = \(f(k))"
    }

    /// 첫째항, 끝항, 항의 수 → 등차수열의 합
    private static func arithmeticSum(_ t: String) -> Solved? {
        guard has(t, ["등차"]), has(t, ["합"]), let a = match(t, "첫째항(?:이|은|:)?\\s*\(num)").flatMap({ DoitMathConstants.value($0[1]) }),
              let l = match(t, "끝항(?:이|은|:)?\\s*\(num)").flatMap({ DoitMathConstants.value($0[1]) }),
              let n = match(t, #"(?:항수|항의\s*수|항의\s*개수)(?:가|는|:)?\s*(\d+)"#).flatMap({ Double($0[1]) }) else { return nil }
        let s = n * (a + l) / 2
        return Solved(kind: .sequence, topic: "등차수열의 합", concept: "첫째항 a, 끝항 l, 항의 개수 n인 등차수열의 합 = n(a + l)/2",
                      steps: [SolutionStep(hint: "n(a + l)/2", work: "\(d(n)) × (\(f(a)) + \(f(l))) ÷ 2 = \(f(s))")], answer: f(s))
    }

    /// 1부터 N까지 적힌 카드 한 장 → 소수(짝수, k의 배수 …)일 확률
    private static func cardProbability(_ t: String) -> Solved? {
        guard has(t, ["확률"]), has(t, ["카드", "공", "번호표"]), has(t, ["한 장", "한 개", "1장", "1개"]),
              let m = match(t, #"1\s*부터\s*(\d+)\s*까지의?\s*(?:자연수|수)"#), let n = Int(m[1]), n >= 2, n <= 1000 else { return nil }
        guard !has(t, ["두 장", "2장", "두 개", "연속", "동시에"]) else { return nil }
        let after = t.components(separatedBy: "뽑").dropFirst().joined()
        var test: ((Int) -> Bool)?
        var label = ""
        if let mm = match(after, #"(\d+)\s*의\s*배수"#), let k = Int(mm[1]), k > 0 { test = { $0 % k == 0 }; label = "\(k)의 배수" }
        else if let mm = match(after, #"(\d+)\s*의\s*약수"#), let k = Int(mm[1]), k > 0 { test = { k % $0 == 0 }; label = "\(k)의 약수" }
        else if after.contains("소수") {
            test = { v in v >= 2 && !(2..<v).contains { v % $0 == 0 } }
            label = "소수"
        }
        else if after.contains("짝수") { test = { $0 % 2 == 0 }; label = "짝수" }
        else if after.contains("홀수") { test = { $0 % 2 == 1 }; label = "홀수" }
        guard let p = test else { return nil }
        let hits = (1...n).filter(p)
        guard let r = DoitMathExact.Rat(hits.count, n) else { return nil }
        return Solved(kind: .counting, topic: "확률", concept: "(확률) = (조건에 맞는 경우의 수) ÷ (모든 경우의 수)",
                      steps: [SolutionStep(hint: "모든 경우의 수", work: "\(n)"),
                              SolutionStep(hint: "\(label)인 경우", work: hits.count <= 30 ? hits.map(String.init).joined(separator: ", ") + " → \(hits.count)가지" : "\(hits.count)가지"),
                              SolutionStep(hint: "확률", work: "\(hits.count)/\(n) = \(r.text)")],
                      answer: r.text)
    }

    /// 서로 다른 n개의 공을 서로 다른 r개의 상자에 넣는 경우의 수 = rⁿ
    private static func ballsIntoBoxes(_ t: String) -> Solved? {
        guard has(t, ["상자", "주머니", "바구니"]), has(t, ["넣는"]), has(t, ["경우의 수", "방법의 수"]), !has(t, ["빈 상자", "적어도", "같은 공", "똑같은"]),
              let m = match(t, #"서로\s*다른\s*(\d+)\s*(?:개|권|장)의\s*[가-힣]+(?:을|를)\s*서로\s*다른\s*(\d+)\s*개의\s*(?:상자|주머니|바구니)"#),
              let n = Int(m[1]), let r = Int(m[2]), n <= 12, r <= 12 else { return nil }
        let v = pow(Double(r), Double(n))
        return Solved(kind: .counting, topic: "중복순열", concept: "서로 다른 n개를 서로 다른 r개의 상자에 넣는 경우의 수 = rⁿ (하나마다 r가지)",
                      steps: [SolutionStep(hint: "하나하나가 \(r)개의 상자 중 하나를 고르므로", work: "\(r)^\(n) = \(d(v))")], answer: d(v))
    }

    /// (a + b)⁴의 전개식에서 a²b²의 계수
    private static func twoLetterBinomial(_ raw: String) -> Solved? {
        guard has(raw, ["계수"]), has(raw, ["전개"]) else { return nil }
        let t = DoitMathExact.superscriptsToPowers(DoitAlgebra.normalize(raw)).replacingOccurrences(of: " ", with: "")
        guard let m = match(t, #"\((\d*)([a-wyz])([+-])(\d*)([a-wyz])\)\^(\d+)"#), m[2] != m[5], let n = Int(m[6]), n <= 20,
              let target = match(t, "\(m[2])(?:\\^(\\d+))?\(m[5])(?:\\^(\\d+))?의계수") else { return nil }
        let p = target[1].isEmpty ? 1 : Int(target[1]) ?? -1, q = target[2].isEmpty ? 1 : Int(target[2]) ?? -1
        guard p + q == n, p >= 0, q >= 0 else { return nil }
        let c1 = Double(m[1]) ?? 1, c2 = (Double(m[4]) ?? 1) * (m[3] == "-" ? -1 : 1)
        let v = comb(n, q) * pow(c1, Double(p)) * pow(c2, Double(q))
        return Solved(kind: .counting, topic: "이항정리", concept: "(a + b)ⁿ의 전개식의 일반항은 ₙCᵣ aⁿ⁻ʳ bʳ 이에요.",
                      steps: [SolutionStep(hint: "\(m[5])의 지수가 \(q)인 항", work: "\(n)C\(q) × \(f(c1))^\(p) × (\(f(c2)))^\(q) = \(f(v))")],
                      answer: "\(m[2])\(DoitMath.superscript(p))\(m[5])\(DoitMath.superscript(q))의 계수 \(f(v))")
    }

    // MARK: - 도수분포표 (글로 옮긴 표)

    struct Row {
        var lo: Double?
        var hi: Double?
        var value: Double     // 변량 또는 계급값
        var count: Double?    // 도수 (모르면 nil)
    }

    /// "계급 | 도수" 줄, "점수 | 6 | 7 | 8" / "학생 수 | 2 | 3 | 5" 가로 표, "변량: 3, 5, 7 / 도수: 2, 3, 5"
    static func rows(_ t: String) -> (rows: [Row], total: Double?, grouped: Bool)? {
        var out: [Row] = []
        var total: Double?
        // 가로: "변량: 3, 5, 7 / 도수: 2, 3, 5"
        if let m = match(t, #"(?:변량|계급값|점수|값)(?:\([^)]*\))?\s*[:：]\s*([-\d., ]+?)\s*[/\n]\s*(?:도수|학생\s*수|사람\s*수)(?:\([^)]*\))?\s*[:：]\s*([-\d., ]+)"#) {
            let xs = m[1].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            let fs = m[2].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard xs.count == fs.count, xs.count >= 2 else { return nil }
            return (zip(xs, fs).map { Row(lo: nil, hi: nil, value: $0, count: $1) }, nil, false)
        }
        let lines = t.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.contains("|") }
        guard lines.count >= 2 else { return nil }
        let cells = lines.map { $0.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) } }
        // 가로 표: 두 줄, 칸이 3개 이상
        if cells.count == 2, cells[0].count >= 3, cells[0].count == cells[1].count,
           cells[1][0].range(of: "도수|학생|사람|명", options: .regularExpression) != nil {
            let xs = cells[0].dropFirst().map { Double($0) }
            let fs = cells[1].dropFirst().map { Double($0) }
            guard xs.allSatisfy({ $0 != nil }), fs.allSatisfy({ $0 != nil }) else { return nil }
            return (zip(xs, fs).map { Row(lo: nil, hi: nil, value: $0!, count: $1!) }, nil, false)
        }
        // 세로 표: 머리줄 + 줄마다 "계급 | 도수"
        guard cells[0].count == 2, cells[0][1].contains("도수") || cells[0][1].contains("명") || cells[0][1].contains("학생") else { return nil }
        var grouped = false
        for row in cells.dropFirst() {
            guard row.count == 2 else { return nil }
            let label = row[0], cell = row[1]
            if label.contains("합계") || label.contains("계") && label.count <= 2 {
                guard let v = Double(cell) else { return nil }
                total = v
                continue
            }
            let count: Double? = Double(cell)
            if count == nil, cell.range(of: #"^[A-Za-z]$"#, options: .regularExpression) == nil { return nil }
            let nums = DoitMathTopics.numbers(in: label.replacingOccurrences(of: "~", with: " ~ "))
            if nums.count == 2, label.contains("~") || label.contains("이상") {
                out.append(Row(lo: nums[0], hi: nums[1], value: (nums[0] + nums[1]) / 2, count: count))
                grouped = true
            } else if nums.count == 1 {
                out.append(Row(lo: nil, hi: nil, value: nums[0], count: count))
            } else { return nil }
        }
        guard out.count >= 2 else { return nil }
        return (out, total, grouped)
    }

    static func table(_ t: String) -> Solved? {
        guard has(t, ["도수", "변량", "계급", "학생 수", "표"]), var parsed = rows(t) else { return nil }
        let concept = "도수분포표: 평균 = (계급값 × 도수)의 합 ÷ 도수의 총합, 상대도수 = 그 계급의 도수 ÷ 도수의 총합, 누적도수는 앞 계급까지의 도수를 더한 값"
        var steps: [SolutionStep] = []
        // 모르는 도수 (A)
        let unknown = parsed.rows.filter { $0.count == nil }
        if unknown.count == 1 {
            let total = parsed.total ?? match(t, #"(?:총합|합계|전체)(?:이|은|는)?\s*(\d+)"#).flatMap { Double($0[1]) }
            guard let n = total else { return nil }
            let known = parsed.rows.compactMap(\.count).reduce(0, +)
            let a = n - known
            guard a >= 0 else { return nil }
            steps.append(SolutionStep(hint: "도수의 총합에서 나머지 도수를 빼면", work: "\(d(n)) − \(d(known)) = \(d(a))"))
            if t.range(of: #"(?<![A-Za-z])[A-Z]\s*의\s*값"#, options: .regularExpression) != nil {
                return Solved(kind: .statistics, topic: "도수분포표의 빈칸", concept: concept, steps: steps, answer: d(a))
            }
            for i in parsed.rows.indices where parsed.rows[i].count == nil { parsed.rows[i].count = a }
        } else if !unknown.isEmpty { return nil }
        let rows = parsed.rows
        let counts = rows.map { $0.count ?? 0 }
        let n = counts.reduce(0, +)
        guard n > 0 else { return nil }
        let sum = zip(rows, counts).reduce(0.0) { $0 + $1.0.value * $1.1 }
        let mean = sum / n
        steps.append(SolutionStep(hint: "도수의 총합", work: d(n)))
        if has(t, ["상대도수"]) {
            guard let target = rowAsked(rows, t) else { return nil }
            let r = (rows[target].count ?? 0) / n
            steps.append(SolutionStep(hint: "상대도수 = 그 계급의 도수 ÷ 도수의 총합", work: "\(d(rows[target].count ?? 0)) ÷ \(d(n)) = \(d(r))"))
            return Solved(kind: .statistics, topic: "상대도수", concept: concept, steps: steps, answer: d(r))
        }
        // "80점 미만인 학생 수", "70점 이상인 학생 수", 누적도수
        if let m = match(t, #"(\d+(?:\.\d+)?)\s*[가-힣]*\s*(미만|이상|이하|초과)인\s*(?:학생|사람|자료|변량)?\s*(?:수|의\s*수|은|는)"#), let v = Double(m[1]), !has(t, ["상대도수", "평균"]) {
            let selected = rows.filter { r in
                switch m[2] {
                case "미만": return (r.hi ?? r.value + (parsed.grouped ? .infinity : 0)) <= v && (parsed.grouped || r.value < v)
                case "이상": return (r.lo ?? r.value) >= v
                case "이하": return parsed.grouped ? false : r.value <= v
                default: return parsed.grouped ? false : r.value > v
                }
            }
            guard !selected.isEmpty else { return nil }
            let c = selected.compactMap(\.count).reduce(0, +)
            steps.append(SolutionStep(hint: "해당하는 계급의 도수를 더하면", work: selected.map { d($0.count ?? 0) }.joined(separator: " + ") + " = \(d(c))"))
            return Solved(kind: .statistics, topic: "도수의 합 (누적도수)", concept: concept, steps: steps, answer: "\(d(c))" + (has(t, ["학생"]) ? "명" : ""))
        }
        if has(t, ["누적도수"]), let target = rowAsked(rows, t) {
            let c = counts.prefix(target + 1).reduce(0, +)
            steps.append(SolutionStep(hint: "첫 계급부터 그 계급까지 도수를 더하면", work: d(c)))
            return Solved(kind: .statistics, topic: "누적도수", concept: concept, steps: steps, answer: d(c))
        }
        if has(t, ["분산", "표준편차"]) {
            let variance = zip(rows, counts).reduce(0.0) { $0 + ($1.0.value - mean) * ($1.0.value - mean) * $1.1 } / n
            steps.append(SolutionStep(hint: "평균", work: f(mean)))
            steps.append(SolutionStep(hint: "분산 = (편차)² × 도수의 합 ÷ 도수의 총합", work: f(variance)))
            if has(t, ["표준편차"]) { return Solved(kind: .statistics, topic: "표준편차", concept: concept, steps: steps, answer: "표준편차 " + DoitAlgebra.sqrtText(variance)) }
            return Solved(kind: .statistics, topic: "분산", concept: concept, steps: steps, answer: "분산 " + f(variance))
        }
        if has(t, ["중앙값", "중간값"]) {
            guard !parsed.grouped, n == n.rounded() else { return nil }
            var expanded: [Double] = []
            for (r, c) in zip(rows, counts) { expanded += Array(repeating: r.value, count: Int(c)) }
            expanded.sort()
            let k = expanded.count
            let median = k % 2 == 1 ? expanded[k / 2] : (expanded[k / 2 - 1] + expanded[k / 2]) / 2
            steps.append(SolutionStep(hint: k % 2 == 1 ? "가운데(\(k / 2 + 1)번째) 값" : "\(k / 2)번째와 \(k / 2 + 1)번째 값의 평균", work: d(median)))
            return Solved(kind: .statistics, topic: "중앙값", concept: concept, steps: steps, answer: "중앙값 \(d(median))")
        }
        if has(t, ["최빈값"]) {
            let top = counts.max() ?? 0
            let modes = zip(rows, counts).filter { $0.1 == top }.map { $0.0.value }
            steps.append(SolutionStep(hint: parsed.grouped ? "도수가 가장 큰 계급의 계급값" : "도수가 가장 큰 변량", work: modes.map(d).joined(separator: ", ")))
            return Solved(kind: .statistics, topic: "최빈값", concept: concept, steps: steps, answer: "최빈값 \(modes.map(d).joined(separator: ", "))")
        }
        if has(t, ["평균"]) {
            steps.append(SolutionStep(hint: "(계급값 × 도수)의 합", work: zip(rows, counts).map { "\(d($0.0.value))×\(d($0.1))" }.joined(separator: " + ") + " = \(d(sum))"))
            steps.append(SolutionStep(hint: "÷ 도수의 총합", work: "\(d(sum)) ÷ \(d(n)) = \(d(mean))"))
            return Solved(kind: .statistics, topic: "도수분포표의 평균", concept: concept, steps: steps, answer: "평균 \(d(mean))")
        }
        return nil
    }

    /// "70점 이상 80점 미만인 계급", "변량 7"
    private static func rowAsked(_ rows: [Row], _ t: String) -> Int? {
        if let m = match(t, #"(\d+(?:\.\d+)?)\s*[가-힣]*\s*이상\s*(\d+(?:\.\d+)?)\s*[가-힣]*\s*미만"#), let lo = Double(m[1]), let hi = Double(m[2]) {
            return rows.firstIndex { $0.lo == lo && $0.hi == hi }
        }
        return nil
    }

    /// "도수가 6이고 상대도수가 0.15 → 총합", "총합이 50이고 상대도수가 0.3 → 도수"
    static func relativeFrequency(_ t: String) -> Solved? {
        guard has(t, ["상대도수"]), !t.contains("|"), let rm = match(t, #"상대도수(?:가|는)\s*(\d*\.?\d+)"#), let r = Double(rm[1]), r > 0, r <= 1 else { return nil }
        let concept = "상대도수 = (그 계급의 도수) ÷ (도수의 총합)"
        if let m = match(t, #"(?<!총합)(?<!총합이)\s도수가\s*(\d+)"#) ?? match(t, #"계급의\s*도수가\s*(\d+)"#), let c = Double(m[1]), has(t, ["총합을", "총합은", "총합이 몇", "전체"]) && !has(t, ["총합이 \(m[1])"]) {
            return Solved(kind: .statistics, topic: "상대도수", concept: concept,
                          steps: [SolutionStep(hint: "도수의 총합 = 도수 ÷ 상대도수", work: "\(d(c)) ÷ \(d(r)) = \(d(c / r))")], answer: d(c / r))
        }
        if let m = match(t, #"총합(?:이|은)\s*(\d+)"#), let total = Double(m[1]) {
            return Solved(kind: .statistics, topic: "상대도수", concept: concept,
                          steps: [SolutionStep(hint: "도수 = 도수의 총합 × 상대도수", work: "\(d(total)) × \(d(r)) = \(d(total * r))")], answer: d(total * r))
        }
        return nil
    }

    // MARK: - 정적분으로 정의된 함수

    static func integralDefined(_ raw: String) -> Solved? {
        guard raw.contains("∫") else { return nil }
        let subs: [Character: String] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9", "ˣ": "x"]
        var t = ""
        var inSub = false
        for ch in raw {
            if let s = subs[ch] {
                if ch == "ˣ" { t += "^x"; inSub = false } else { if !inSub { t += "_" }; t += s; inSub = true }
            } else { inSub = false; t.append(ch) }
        }
        t = t.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        guard let m = match(t, #"∫\s*_\s*\(?(-?\d+)\)?\s*\^\s*\(?x\)?\s*(.+?)\s*d\s*t"#), let c = Double(m[1]) else { return nil }
        let integrand = m[2].trimmingCharacters(in: .whitespaces)
        let concept = "d/dx ∫ₐˣ f(t) dt = f(x), ∫ₐᵃ f(t) dt = 0"
        if integrand == "f(t)" || integrand == "f (t)" {
            // ∫ₐˣ f(t) dt = G(x)
            guard let after = t.range(of: m[0]).map({ String(t[$0.upperBound...]) }), let eq = match(after, #"^\s*=\s*([^가-힣,]+)"#) else { return nil }
            let letters = Set(eq[1].filter { "abckmnpq".contains($0) })
            guard letters.count <= 1 else { return nil }
            var vars = letters
            vars.insert("x")
            guard let G = DoitMathConstants.parse(eq[1].trimmingCharacters(in: .whitespaces), variables: vars) else { return nil }
            var steps: [SolutionStep] = []
            var g = G
            if let u = letters.first {
                // x = a를 넣으면 0
                let at = G.substitute("x", c)
                guard let sols = DoitMathConstants.solveEquations([at], unknowns: [u]), sols.count == 1, let v = sols[0][u] else { return nil }
                steps.append(SolutionStep(hint: "양변에 x = \(f(c))을 넣으면 왼쪽은 0", work: "\(DoitMathConstants.equationText(at)) → \(u) = \(f(v))"))
                g = G.substitute(u, v)
            }
            let fx = g.derivative("x")
            steps.append(SolutionStep(hint: "양변을 x에 대해 미분하면 f(x)", work: "f(x) = \(DoitMathConstants.describe(fx))"))
            if let k = match(t, "f\\s*\\(\\s*\(num)\\s*\\)\\s*의\\s*값").flatMap({ DoitMathConstants.value($0[1]) }), let v = fx.substitute("x", k).evaluate([:]) {
                steps.append(SolutionStep(hint: "x = \(f(k))을 넣으면", work: "f(\(f(k))) = \(f(v))"))
                return Solved(kind: .integral, topic: "정적분으로 정의된 함수", concept: concept, steps: steps, answer: "f(\(f(k))) = \(f(v))")
            }
            return Solved(kind: .integral, topic: "정적분으로 정의된 함수", concept: concept, steps: steps, answer: "f(x) = \(DoitMathConstants.describe(fx))")
        }
        // f(x) = ∫ₐˣ g(t) dt → f'(k) = g(k), f(k) = ∫ₐᵏ g
        guard let g = DoitMathConstants.parse(integrand.replacingOccurrences(of: "t", with: "x"), variables: ["x"]) else { return nil }
        if let k = match(t, "f'\\s*\\(\\s*\(num)\\s*\\)").flatMap({ DoitMathConstants.value($0[1]) }), let v = g.substitute("x", k).evaluate([:]) {
            return Solved(kind: .integral, topic: "정적분으로 정의된 함수", concept: concept,
                          steps: [SolutionStep(hint: "f'(x)는 적분 안의 함수에 x를 넣은 것", work: "f'(x) = \(DoitMathConstants.describe(g))"),
                                  SolutionStep(hint: "x = \(f(k))을 넣으면", work: "f'(\(f(k))) = \(f(v))")],
                          answer: "f'(\(f(k))) = \(f(v))")
        }
        if let k = match(t, "f\\s*\\(\\s*\(num)\\s*\\)\\s*의\\s*값").flatMap({ DoitMathConstants.value($0[1]) }), let p = g.univariate("x"), let F = DoitAlgebra.integrate(p) {
            let v = DoitMath.value(F, at: k) - DoitMath.value(F, at: c)
            return Solved(kind: .integral, topic: "정적분으로 정의된 함수", concept: concept,
                          steps: [SolutionStep(hint: "부정적분 F(x)", work: DoitMath.describe(F)), SolutionStep(hint: "F(\(f(k))) − F(\(f(c)))", work: f(v))],
                          answer: "f(\(f(k))) = \(f(v))")
        }
        return nil
    }

    // MARK: - 지수 · 로그 · 삼각방정식 (수치로 근을 찾고 깔끔한 값으로 확인)

    indirect enum FNode {
        case number(Double)
        case x
        case negate(FNode)
        case binary(Character, FNode, FNode)
        case function(String, FNode)
        case log(FNode, FNode)   // 밑, 진수

        func eval(_ x: Double, degrees: Bool) -> Double? {
            switch self {
            case .number(let v): return v
            case .x: return x
            case .negate(let a): return a.eval(x, degrees: degrees).map { -$0 }
            case .binary(let op, let a, let b):
                guard let p = a.eval(x, degrees: degrees), let q = b.eval(x, degrees: degrees) else { return nil }
                switch op {
                case "+": return p + q
                case "-": return p - q
                case "*": return p * q
                case "/": return abs(q) < 1e-300 ? nil : p / q
                default:
                    let v = pow(p, q)
                    return v.isFinite ? v : nil
                }
            case .function(let name, let a):
                guard let v = a.eval(x, degrees: degrees) else { return nil }
                let r = degrees ? v * .pi / 180 : v
                switch name {
                case "sin": return Foundation.sin(r)
                case "cos": return Foundation.cos(r)
                case "tan":
                    let c = Foundation.cos(r)
                    return abs(c) < 1e-12 ? nil : Foundation.sin(r) / c
                case "ln": return v > 0 ? Foundation.log(v) : nil
                default: return v >= 0 ? v.squareRoot() : nil
                }
            case .log(let base, let a):
                guard let b = base.eval(x, degrees: degrees), let v = a.eval(x, degrees: degrees), b > 0, b != 1, v > 0 else { return nil }
                return Foundation.log(v) / Foundation.log(b)
            }
        }

        var hasX: Bool {
            switch self {
            case .number: return false
            case .x: return true
            case .negate(let a): return a.hasX
            case .binary(_, let a, let b): return a.hasX || b.hasX
            case .function(_, let a): return a.hasX
            case .log(let a, let b): return a.hasX || b.hasX
            }
        }
    }

    private struct FParser {
        let c: [Character]
        var i = 0
        var peek: Character? { i < c.count ? c[i] : nil }
        func starts(_ word: String) -> Bool {
            let w = Array(word)
            guard i + w.count <= c.count else { return false }
            return Array(c[i..<(i + w.count)]) == w
        }

        mutating func expression() -> FNode? {
            guard var v = term() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                i += 1
                guard let r = term() else { return nil }
                v = .binary(op, v, r)
            }
            return v
        }
        mutating func term() -> FNode? {
            guard var v = unary() else { return nil }
            while let op = peek {
                if op == "*" || op == "/" {
                    i += 1
                    guard let r = unary() else { return nil }
                    v = .binary(op, v, r)
                } else if op == "(" || op == "x" || op == "π" || op == "√" || op.isNumber || starts("sin") || starts("cos") || starts("tan") || starts("log") || starts("ln") {
                    guard let r = power() else { return nil }
                    v = .binary("*", v, r)
                } else { break }
            }
            return v
        }
        mutating func unary() -> FNode? {
            if peek == "-" { i += 1; return unary().map { .negate($0) } }
            if peek == "+" { i += 1; return unary() }
            return power()
        }
        mutating func power() -> FNode? {
            guard let b = primary() else { return nil }
            guard peek == "^" else { return b }
            i += 1
            guard let e = unary() else { return nil }
            return .binary("^", b, e)
        }
        /// 함수의 인수: 괄호가 있으면 괄호, 없으면 곱으로 이어진 짧은 덩어리 (sin 2x, log₂ x)
        mutating func argument() -> FNode? {
            if peek == "(" { return primary() }
            guard var v = primaryNoFunction() else { return nil }
            while let ch = peek, ch == "x" || ch == "π" || ch.isNumber {
                guard let r = primaryNoFunction() else { return nil }
                v = .binary("*", v, r)
            }
            return v
        }
        mutating func primaryNoFunction() -> FNode? {
            guard let ch = peek else { return nil }
            if ch == "x" { i += 1; return .x }
            if ch == "π" { i += 1; return .number(.pi) }
            if ch == "(" { return primary() }
            var digits = ""
            while let dd = peek, dd.isNumber || dd == "." { digits.append(dd); i += 1 }
            return Double(digits).map { .number($0) }
        }
        mutating func primary() -> FNode? {
            guard let ch = peek else { return nil }
            if ch == "(" {
                i += 1
                guard let v = expression(), peek == ")" else { return nil }
                i += 1
                return v
            }
            for name in ["sin", "cos", "tan"] where starts(name) {
                i += name.count
                // sin^2 x
                var exponent: FNode?
                if peek == "^" {
                    i += 1
                    guard let e = primaryNoFunction() else { return nil }
                    exponent = e
                }
                guard let arg = argument() else { return nil }
                let value = FNode.function(name, arg)
                return exponent.map { .binary("^", value, $0) } ?? value
            }
            if starts("ln") {
                i += 2
                return argument().map { .function("ln", $0) }
            }
            if starts("log") {
                i += 3
                var base = FNode.number(10)
                if peek == "_" {
                    i += 1
                    guard let b = primaryNoFunction() else { return nil }
                    base = b
                }
                return argument().map { .log(base, $0) }
            }
            if ch == "√" {
                i += 1
                return power().map { .function("sqrt", $0) }
            }
            return primaryNoFunction()
        }
    }

    static func fnode(_ raw: String) -> FNode? {
        let subs: [Character: String] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9"]
        var s = ""
        var inSub = false
        for ch in DoitMathExact.superscriptsToPowers(DoitAlgebra.normalize(raw)) {
            if let v = subs[ch] { if !inSub { s += "_" }; s += v; inSub = true } else { inSub = false; s.append(ch) }
        }
        s = s.replacingOccurrences(of: "ˣ", with: "^x").replacingOccurrences(of: " ", with: "")
        guard !s.isEmpty else { return nil }
        var p = FParser(c: Array(s))
        guard let n = p.expression(), p.i == p.c.count else { return nil }
        return n
    }

    static func transcendental(_ t: String) -> Solved? {
        let trig = t.range(of: #"(sin|cos|tan)\s*(\^\s*\d\s*)?\(?\s*\d*\s*x"#, options: .regularExpression) != nil
        let expo = t.range(of: #"\^\s*\(?[^=]*x|ˣ"#, options: .regularExpression) != nil && t.range(of: #"\d\s*\^\s*\(?\s*-?\d*\s*x|\)\s*\^\s*\(?\s*-?\d*\s*x|\dˣ"#, options: .regularExpression) != nil
        let logarithm = t.range(of: #"(log|ln)\s*[₀-₉_\d]*\s*\(?\s*x"#, options: .regularExpression) != nil
        guard trig || expo || logarithm, t.contains("=") else { return nil }
        // 방정식 부분: '=' 하나가 있는 가장 긴 조각
        let allowed = Set("0123456789.+-*/^=()xπ√ sincotalg_₀₁₂₃₄₅₆₇₈₉ˣ")
        var best = "", current = ""
        func commit() {
            let s = current.trimmingCharacters(in: .whitespaces)
            if s.filter({ $0 == "=" }).count == 1, s.contains("x"), s.count > best.count { best = s }
            current = ""
        }
        for ch in t { if allowed.contains(ch) { current.append(ch) } else { commit() } }
        commit()
        let sides = best.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard sides.count == 2, let l = fnode(sides[0]), let r = fnode(sides[1]), l.hasX || r.hasX else { return nil }
        let shown = best.replacingOccurrences(of: "*", with: "×")
        if trig {
            // 범위: 0 ≤ x < 2π, 0° ≤ x < 360°
            guard let m = match(t, #"(-?\d*π?(?:/\d+)?)\s*(°)?\s*(≤|<)\s*x\s*(≤|<)\s*(\d*π(?:/\d+)?|\d+)\s*(°)?"#),
                  let lo = angleValue(m[1]), let hi = angleValue(m[5]), hi > lo else { return nil }
            let degrees = !m[2].isEmpty || !m[6].isEmpty
            let includeLo = m[3] == "≤", includeHi = m[4] == "≤"
            func g(_ x: Double) -> Double? {
                guard let a = l.eval(x, degrees: degrees), let b = r.eval(x, degrees: degrees) else { return nil }
                return a - b
            }
            // 깔끔한 후보: π/12 (15°)의 배수
            let stepValue = degrees ? 15.0 : .pi / 12
            var found: [Double] = []
            var k = (lo / stepValue).rounded(.down)
            while k * stepValue <= hi + 1e-9 {
                let x = k * stepValue
                k += 1
                guard x >= lo - 1e-9, x <= hi + 1e-9 else { continue }
                if abs(x - lo) < 1e-9 && !includeLo { continue }
                if abs(x - hi) < 1e-9 && !includeHi { continue }
                if let v = g(x), abs(v) < 1e-9 { found.append(x) }
            }
            // 부호가 바뀌는 곳이 후보 밖에 있으면 (깔끔하지 않은 근) 풀지 않음
            let n = 4000
            var previous: (Double, Double)?
            for j in 0...n {
                let x = lo + (hi - lo) * Double(j) / Double(n)
                guard let y = g(x) else { previous = nil; continue }
                if let (px, py) = previous, py * y < 0 {
                    var a = px, b = x, fa = py
                    for _ in 0..<60 {
                        let mid = (a + b) / 2
                        guard let fm = g(mid) else { break }
                        if (fm < 0) == (fa < 0) { a = mid; fa = fm } else { b = mid }
                    }
                    let root = (a + b) / 2
                    if let v = g(root), abs(v) < 1e-6, !found.contains(where: { abs($0 - root) < 1e-6 }) { return nil }
                }
                previous = (x, y)
            }
            guard !found.isEmpty else { return nil }
            let labels = found.map { degrees ? "\(d($0))°" : piLabel($0) }
            return Solved(kind: .function, topic: "삼각방정식", concept: "단위원(또는 그래프)에서 sin, cos, tan 값이 같아지는 각을 주어진 범위 안에서 모두 찾아요. 같은 값을 갖는 각은 보통 두 개씩 있어요.",
                          steps: [SolutionStep(hint: "방정식", work: shown),
                                  SolutionStep(hint: "\(m[0]) 범위에서 식을 만족하는 각", work: labels.joined(separator: ", "))],
                          answer: "x = " + labels.joined(separator: ", "))
        }
        // 지수 · 로그: −30 ~ 30에서 근 찾기
        func g(_ x: Double) -> Double? {
            guard let a = l.eval(x, degrees: false), let b = r.eval(x, degrees: false) else { return nil }
            let v = a - b
            return v.isFinite ? v : nil
        }
        var roots: [Double] = []
        var previous: (Double, Double)?
        var x = -30.0
        while x <= 30 {
            if let y = g(x) {
                if let (px, py) = previous, py * y < 0 {
                    var a = px, b = x, fa = py
                    for _ in 0..<70 {
                        let mid = (a + b) / 2
                        guard let fm = g(mid) else { break }
                        if (fm < 0) == (fa < 0) { a = mid; fa = fm } else { b = mid }
                    }
                    let root = (a + b) / 2
                    if let v = g(root), abs(v) < 1e-6 {
                        guard let snapped = snap(root, g) else { return nil }
                        if !roots.contains(where: { abs($0 - snapped) < 1e-9 }) { roots.append(snapped) }
                    }
                }
                if abs(y) < 1e-12, let snapped = snap(x, g), !roots.contains(where: { abs($0 - snapped) < 1e-9 }) { roots.append(snapped) }
                previous = (x, y)
            } else { previous = nil }
            x += 0.01
        }
        // 부호가 바뀌지 않고 닿기만 하는 근 (중근)
        for den in 1...4 {
            for k in -120...120 {
                let c = Double(k) / Double(den)
                if let v = g(c), abs(v) < 1e-10, !roots.contains(where: { abs($0 - c) < 1e-9 }) { roots.append(c) }
            }
        }
        guard !roots.isEmpty, roots.count <= 4 else { return nil }
        roots.sort()
        let labels = roots.map { "x = \(f($0))" }
        let concept = logarithm ? "로그방정식: 진수 조건(진수 > 0)을 먼저 확인하고, logₐ M = logₐ N 이면 M = N, logₐ M = k 이면 M = aᵏ" : "지수방정식: 밑을 같게 만들어 지수끼리 비교해요 (aᶠ⁽ˣ⁾ = aᵍ⁽ˣ⁾ 이면 f(x) = g(x)). aˣ = t로 치환하면 이차방정식이 되기도 해요 (t > 0)."
        return Solved(kind: .function, topic: logarithm ? "로그방정식" : "지수방정식", concept: concept,
                      steps: [SolutionStep(hint: "방정식", work: shown),
                              SolutionStep(hint: logarithm ? "진수 조건을 만족하는 해만 남기면" : "밑을 같게 하거나 치환해서 풀면", work: labels.joined(separator: " 또는 ")),
                              SolutionStep(hint: "대입해서 확인", work: roots.map { "x = \(f($0)) 일 때 성립" }.joined(separator: ", "))],
                      answer: labels.joined(separator: " 또는 "))
    }

    private static func snap(_ r: Double, _ g: (Double) -> Double?) -> Double? {
        for den in 1...12 {
            let c = (r * Double(den)).rounded() / Double(den)
            if abs(c - r) < 1e-5, let v = g(c), abs(v) < 1e-9 { return c }
        }
        return nil
    }

    private static func angleValue(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        if !t.contains("π") { return Double(t) }
        let parts = t.split(separator: "/").map(String.init)
        let head = parts[0].replacingOccurrences(of: "π", with: "")
        let k = head.isEmpty ? 1 : head == "-" ? -1 : Double(head)
        guard let coefficient = k else { return nil }
        let den = parts.count == 2 ? Double(parts[1]) ?? 0 : 1
        guard den != 0 else { return nil }
        return coefficient * .pi / den
    }

    private static func piLabel(_ x: Double) -> String {
        let k = Int((x / (.pi / 12)).rounded())
        if k == 0 { return "0" }
        let g = DoitAlgebra.gcd(abs(k), 12)
        let n = k / g, den = 12 / g
        let top = n == 1 ? "π" : n == -1 ? "−π" : "\(n)π"
        return den == 1 ? top : "\(top)/\(den)"
    }

    // MARK: - 시그마

    static func sigma(_ raw: String) -> Solved? {
        guard raw.contains("∑") || raw.contains("Σ") else { return nil }
        let subs: [Character: String] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9", "ₖ": "k", "ₙ": "n", "₌": "="]
        var t = ""
        for ch in raw { t += subs[ch] ?? String(ch) }
        t = DoitMathExact.superscriptsToPowers(DoitAlgebra.normalize(t)).replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        guard let m = match(t, #"[∑Σ]\s*_?\s*\(?\s*([kin])\s*=\s*(\d+)\s*\)?\s*\^?\s*(?:to\s*)?(\d+)\s*([^가-힣]+?)\s*(?:의\s*값|를|을|$|\?)"#),
              let index = m[1].first, let lo = Int(m[2]), let hi = Int(m[3]), hi >= lo, hi - lo <= 10000 else { return nil }
        var body = m[4].trimmingCharacters(in: .whitespaces)
        // "^10 (2k+1)" 처럼 위끝이 ^로 붙은 경우
        if body.hasPrefix("^") { return nil }
        if body.hasPrefix("(") && body.hasSuffix(")") && DoitMathConstants.splitFraction(body) == nil { body = String(body.dropFirst().dropLast()) }
        guard let p = DoitMathConstants.parse(body, variables: [index]) else { return nil }
        var total = 0.0
        for k in lo...hi { total += p.substitute(index, Double(k)).evaluate([:]) ?? .nan }
        guard total.isFinite else { return nil }
        let formula = "∑(\(index)=\(lo)→\(hi)) (\(DoitMathConstants.describe(p)))"
        return Solved(kind: .sequence, topic: "합의 기호 ∑", concept: "∑ₖ₌₁ⁿ k = n(n+1)/2, ∑ k² = n(n+1)(2n+1)/6, ∑ c = cn, ∑(aₖ + bₖ) = ∑aₖ + ∑bₖ",
                      steps: [SolutionStep(hint: "식", work: formula),
                              SolutionStep(hint: "공식으로 나눠 계산하면", work: f(total))],
                      answer: f(total))
    }

    // MARK: - "1 + 3 + 5 + … + 19" 꼴의 합

    static func series(_ t: String) -> Solved? {
        guard let m = match(t, #"((?:-?\d+(?:\.\d+)?\s*\+\s*){2,})(?:…|⋯|\.\s*\.\s*\.|·\s*·\s*·)\s*\+\s*(-?\d+(?:\.\d+)?)"#) else { return nil }
        let first = m[1].split(separator: "+").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard first.count >= 2, let last = Double(m[2]) else { return nil }
        let a = first[0]
        let diffs = zip(first.dropFirst(), first).map { $0 - $1 }
        if diffs.allSatisfy({ abs($0 - diffs[0]) < 1e-12 }), abs(diffs[0]) > 1e-12 {
            let dd = diffs[0]
            let n = (last - a) / dd + 1
            guard n >= Double(first.count), abs(n - n.rounded()) < 1e-9 else { return nil }
            let s = n * (a + last) / 2
            return Solved(kind: .sequence, topic: "등차수열의 합", concept: "등차수열의 합 = (첫째항 + 끝항) × 항의 개수 ÷ 2",
                          steps: [SolutionStep(hint: "첫째항 \(d(a)), 공차 \(d(dd)), 끝항 \(d(last))", work: "항의 개수 = (\(d(last)) − \(d(a))) ÷ \(d(dd)) + 1 = \(d(n))"),
                                  SolutionStep(hint: "(첫째항 + 끝항) × 개수 ÷ 2", work: "(\(d(a)) + \(d(last))) × \(d(n)) ÷ 2 = \(d(s))")],
                          answer: d(s))
        }
        guard a != 0 else { return nil }
        let ratios = zip(first.dropFirst(), first).map { $0 / $1 }
        guard ratios.allSatisfy({ abs($0 - ratios[0]) < 1e-12 }), abs(ratios[0]) > 1 else { return nil }
        let r = ratios[0]
        var term = a, n = 1
        while abs(term) < abs(last) - 1e-9 && n < 200 { term *= r; n += 1 }
        guard abs(term - last) < 1e-9 else { return nil }
        let s = a * (pow(r, Double(n)) - 1) / (r - 1)
        return Solved(kind: .sequence, topic: "등비수열의 합", concept: "첫째항 a, 공비 r인 등비수열의 첫째항부터 제n항까지의 합 = a(rⁿ − 1)/(r − 1)",
                      steps: [SolutionStep(hint: "첫째항 \(d(a)), 공비 \(d(r)), 끝항 \(d(last))", work: "\(d(a)) × \(d(r))ⁿ⁻¹ = \(d(last)) → n = \(n)"),
                              SolutionStep(hint: "a(rⁿ − 1)/(r − 1)", work: "\(d(a))(\(d(r))^\(n) − 1)/(\(d(r)) − 1) = \(d(s))")],
                      answer: d(s))
    }

    // MARK: - 등비수열: 짝수 번 떨어진 두 항 (공비 ±)

    static func geometricBoth(_ t: String) -> Solved? {
        guard has(t, ["등비"]), !has(t, ["등차"]) else { return nil }
        let subs: [Character: Character] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9"]
        let plain = String(t.map { subs[$0] ?? $0 })
        var given: [(Int, Double)] = []
        for m in matches(plain, #"제\s*(\d+)\s*항(?:이|은|는|의 값이)?\s*(-?\d+(?:\.\d+)?)"#) {
            if let k = Int(m[1]), let v = Double(m[2]), !given.contains(where: { $0.0 == k }) { given.append((k, v)) }
        }
        for m in matches(plain, #"a_?(\d+)\s*=\s*(-?\d+(?:\.\d+)?)"#) {
            if let k = Int(m[1]), let v = Double(m[2]), !given.contains(where: { $0.0 == k }) { given.append((k, v)) }
        }
        guard given.count == 2, !has(t, ["공비가 2", "공비가 3", "첫째항이"]) else { return nil }
        let (k1, v1) = given[0], (k2, v2) = given[1]
        let e = k2 - k1
        guard v1 != 0, e != 0, e % 2 == 0 else { return nil }
        let q = v2 / v1
        guard q > 0 else { return nil }
        var r = pow(q, 1 / Double(abs(e)))
        if e < 0 { r = 1 / r }
        if abs(r - r.rounded()) < 1e-9 { r = r.rounded() }
        guard abs(pow(r, Double(e)) - q) < 1e-9 * max(1, q) else { return nil }
        let positive = has(t, ["공비가 양수", "공비는 양수", "모든 항이 양수", "양수인 등비", "양의 실수", "공비가 양의"])
        let negativeRatio = has(t, ["공비가 음수", "공비는 음수"])
        var ratios = [r, -r]
        if positive { ratios = [r] }
        if negativeRatio { ratios = [-r] }
        // 묻는 것
        let asked = matches(plain, #"(?:제\s*(\d+)\s*항|a_?(\d+)\s*의\s*값)"#).compactMap { Int($0[1].isEmpty ? $0[2] : $0[1]) }.filter { $0 != k1 && $0 != k2 }.first
        let concept = "등비수열 aₙ = a × rⁿ⁻¹. 두 항을 나누면 r의 거듭제곱이 나와요. 짝수 제곱이면 r = ±값 두 가지를 모두 생각해요."
        var steps = [SolutionStep(hint: "두 항을 나누면", work: "r^\(e) = \(f(q)) → r = \(ratios.map { f($0) }.joined(separator: " 또는 "))")]
        func value(_ rr: Double, _ n: Int) -> Double { v1 * pow(rr, Double(n - k1)) }
        let sub: [Character: Character] = ["0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉"]
        func term(_ n: Int) -> String { "a" + String(String(n).compactMap { sub[$0] }) }
        if let n = asked {
            let values = ratios.map { value($0, n) }
            if values.allSatisfy({ abs($0 - values[0]) < 1e-9 * max(1, abs(values[0])) }) {
                steps.append(SolutionStep(hint: "\(term(n)) = \(term(k1)) × r^\(n - k1)", work: "\(d(values[0])) (공비의 부호와 상관없이 같아요)"))
                return Solved(kind: .sequence, topic: "등비수열", concept: concept, steps: steps, answer: "\(term(n)) = \(d(values[0]))")
            }
            let parts = zip(ratios, values).map { "\(d($0.1)) (공비 \(f($0.0)))" }
            steps.append(SolutionStep(hint: "공비마다 계산하면", work: parts.joined(separator: ", ")))
            return Solved(kind: .sequence, topic: "등비수열", concept: concept, steps: steps, answer: "\(term(n)) = " + parts.joined(separator: " 또는 "))
        }
        if has(t, ["첫째항"]) {
            let values = ratios.map { value($0, 1) }
            let unique = values.allSatisfy { abs($0 - values[0]) < 1e-9 }
            steps.append(SolutionStep(hint: "a₁ = a\(k1) ÷ r^\(k1 - 1)", work: values.map(d).joined(separator: " 또는 ")))
            return Solved(kind: .sequence, topic: "등비수열", concept: concept, steps: steps, answer: "첫째항 " + (unique ? d(values[0]) : zip(ratios, values).map { "\(d($0.1)) (공비 \(f($0.0)))" }.joined(separator: " 또는 ")))
        }
        if has(t, ["공비"]) {
            return Solved(kind: .sequence, topic: "등비수열", concept: concept, steps: steps, answer: "공비 " + ratios.map { f($0) }.joined(separator: " 또는 "))
        }
        return nil
    }

    /// 등차수열 두 항 → "a₁₀의 값"
    static func arithmeticAsked(_ t: String) -> Solved? {
        guard has(t, ["등차"]), !has(t, ["등비"]) else { return nil }
        let subs: [Character: Character] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9"]
        let plain = String(t.map { subs[$0] ?? $0 })
        var given: [(Int, Double)] = []
        for m in matches(plain, #"a_?(\d+)\s*=\s*(-?\d+(?:\.\d+)?)"#) {
            if let k = Int(m[1]), let v = Double(m[2]), !given.contains(where: { $0.0 == k }) { given.append((k, v)) }
        }
        guard given.count == 2, given[0].0 != given[1].0, let asked = match(plain, #"a_?(\d+)\s*의\s*값"#).flatMap({ Int($0[1]) }),
              !given.contains(where: { $0.0 == asked }) else { return nil }
        let (k1, v1) = given[0], (k2, v2) = given[1]
        let dd = (v2 - v1) / Double(k2 - k1)
        let value = v1 + Double(asked - k1) * dd
        let sub: [Character: Character] = ["0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉"]
        func term(_ n: Int) -> String { "a" + String(String(n).compactMap { sub[$0] }) }
        return Solved(kind: .sequence, topic: "등차수열", concept: "등차수열 aₙ = a + (n − 1)d. 두 항의 차를 항 번호의 차로 나누면 공차예요.",
                      steps: [SolutionStep(hint: "공차 d = (\(term(k2)) − \(term(k1))) ÷ (\(k2) − \(k1))", work: "(\(d(v2)) − \(d(v1))) ÷ \(k2 - k1) = \(f(dd))"),
                              SolutionStep(hint: "\(term(asked)) = \(term(k1)) + (\(asked) − \(k1))d", work: "\(d(v1)) + \(asked - k1) × \(f(dd)) = \(f(value))")],
                      answer: "\(term(asked)) = \(f(value))")
    }

    /// 세 수 a, x, b가 이 순서대로 등비(등차)수열 → x² = ab (2x = a + b)
    static func middleTerm(_ t: String) -> Solved? {
        guard let m = match(t, #"세\s*수\s*(-?\d+(?:\.\d+)?)\s*,\s*([a-z])\s*,\s*(-?\d+(?:\.\d+)?)\s*(?:이|가)\s*이\s*순서대로\s*(등비|등차)"#),
              let a = Double(m[1]), let b = Double(m[3]) else { return nil }
        let x = m[2]
        if m[4] == "등차" {
            return Solved(kind: .sequence, topic: "등차중항", concept: "세 수 a, x, b가 이 순서대로 등차수열을 이루면 2x = a + b",
                          steps: [SolutionStep(hint: "2\(x) = \(d(a)) + \(d(b))", work: "\(x) = \(f((a + b) / 2))")], answer: "\(x) = \(f((a + b) / 2))")
        }
        let p = a * b
        guard p > 0 else { return nil }
        let root = p.squareRoot()
        guard let shown = DoitMathFigures.nice(root) else { return nil }
        var answers = ["\(x) = \(shown)", "\(x) = −\(shown)"]
        if has(t, ["양수 \(x)", "\(x) > 0", "양의 실수 \(x)"]) { answers = ["\(x) = \(shown)"] }
        if has(t, ["음수 \(x)", "\(x) < 0"]) { answers = ["\(x) = −\(shown)"] }
        return Solved(kind: .sequence, topic: "등비중항", concept: "세 수 a, x, b가 이 순서대로 등비수열을 이루면 x² = ab",
                      steps: [SolutionStep(hint: "\(x)² = \(d(a)) × \(d(b))", work: "\(x)² = \(d(p))")], answer: answers.joined(separator: " 또는 "))
    }

    // MARK: - 경우의 수: 이웃하는 · 이웃하지 않는 · 교대로 · 원탁 · 정수해 · 같은 것이 있는 순열

    private static func fact(_ n: Int) -> Double { DoitMathTopics.factorial(n) }
    private static func comb(_ n: Int, _ r: Int) -> Double { DoitMathTopics.combination(n, r) }

    static func arrangements(_ t: String) -> Solved? {
        // x + y + z = n 의 음이 아닌 정수해 / 자연수해
        if let m = match(t, #"([a-z](?:\s*\+\s*[a-z]){1,5})\s*=\s*(\d+)"#), has(t, ["순서쌍", "해의 개수"]), let n = Int(m[2]) {
            let k = m[1].split(separator: "+").count
            if has(t, ["음이 아닌 정수", "음이아닌 정수"]) {
                let v = comb(n + k - 1, k - 1)
                return Solved(kind: .counting, topic: "중복조합 (방정식의 음이 아닌 정수해)", concept: "x₁ + … + xₖ = n 의 음이 아닌 정수해의 개수 = ₖHₙ = ₙ₊ₖ₋₁Cₙ",
                              steps: [SolutionStep(hint: "\(k)개의 문자에서 중복을 허락해 \(n)개를 고르는 것과 같아요", work: "\(k)H\(n) = \(n + k - 1)C\(n) = \(d(v))")], answer: d(v))
            }
            if has(t, ["자연수"]), n >= k {
                let v = comb(n - 1, k - 1)
                return Solved(kind: .counting, topic: "중복조합 (방정식의 자연수해)", concept: "각 문자에 1씩 먼저 주고 남은 \(n - k)을 나누는 음이 아닌 정수해의 개수 ₖHₙ₋ₖ",
                              steps: [SolutionStep(hint: "x = x' + 1 꼴로 바꾸면 x' + … = \(n - k)", work: "\(k)H\(n - k) = \(n - 1)C\(n - k) = \(d(v))")], answer: d(v))
            }
        }
        // 같은 것이 있는 순열: "a, a, b, b, c를 일렬로", "1, 1, 2, 2, 2를 일렬로 나열"
        if has(t, ["일렬로", "한 줄로", "나열"]), let m = match(t, #"((?:[a-zA-Z0-9]\s*,\s*){2,}[a-zA-Z0-9])\s*(?:을|를|의)"#) {
            let items = m[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            var counts: [String: Int] = [:]
            for i in items { counts[i, default: 0] += 1 }
            if counts.values.contains(where: { $0 >= 2 }), items.count <= 12, !items.contains("0") {
                let v = counts.values.reduce(fact(items.count)) { $0 / fact($1) }
                let denominators = counts.values.filter { $0 >= 2 }.map { "\($0)!" }.joined(separator: " × ")
                return Solved(kind: .counting, topic: "같은 것이 있는 순열", concept: "n개 중 같은 것이 p개, q개씩 있으면 일렬로 나열하는 경우의 수는 n!/(p! q! …)",
                              steps: [SolutionStep(hint: "\(items.count)개를 나열하고 같은 것끼리의 순서를 나누면", work: "\(items.count)! ÷ (\(denominators)) = \(d(v))")], answer: d(v))
            }
        }
        guard has(t, ["이웃", "교대로", "번갈아"]) else { return nil }
        let circular = has(t, ["원탁", "원형", "둥글게"])
        // 사람 수: "5명", 또는 이름 나열 "A, B, C, D, E"
        var total: Int?
        if let m = match(t, #"남학생\s*(\d+)\s*명\s*(?:과|와|,)?\s*여학생\s*(\d+)\s*명"#), let b = Int(m[1]), let g = Int(m[2]) {
            if has(t, ["교대로", "번갈아"]) {
                guard !circular else {
                    guard b == g else { return nil }
                    let v = fact(b - 1) * fact(g)
                    return Solved(kind: .counting, topic: "원순열 (교대로 앉기)", concept: "남학생을 먼저 원형으로 앉히고((n−1)!), 사이사이에 여학생을 앉혀요(n!).",
                                  steps: [SolutionStep(hint: "(\(b) − 1)! × \(g)!", work: d(v))], answer: d(v))
                }
                let v: Double
                if b == g { v = 2 * fact(b) * fact(g) } else if abs(b - g) == 1 { v = fact(b) * fact(g) } else { return nil }
                return Solved(kind: .counting, topic: "교대로 서는 경우의 수", concept: "남녀가 교대로 서려면 자리를 남·여로 번갈아 정해 놓고 각각 나열해요. 인원이 같으면 누가 먼저 서는지 2가지.",
                              steps: [SolutionStep(hint: b == g ? "2 × \(b)! × \(g)!" : "\(b)! × \(g)!", work: d(v))], answer: d(v))
            }
            // "여학생끼리 이웃하는", "남학생끼리"
            let block: Int? = has(t, ["여학생끼리", "여학생 2명이 이웃", "여학생이 이웃", "여학생들이 이웃"]) ? g : has(t, ["남학생끼리", "남학생이 이웃", "남학생들이 이웃"]) ? b : nil
            guard let k = block, !circular else { return nil }
            let n = b + g
            let together = fact(n - k + 1) * fact(k)
            if has(t, ["이웃하지 않", "이웃하지않"]) {
                guard k == 2 || has(t, ["어느 두"]) else { return nil }
                // k명 중 어느 두 명도 이웃하지 않음: (n−k)! × (n−k+1)P(k)
                let others = n - k
                let v = fact(others) * DoitMathTopics.permutation(others + 1, k)
                return Solved(kind: .counting, topic: "이웃하지 않는 경우의 수", concept: "먼저 나머지를 세우고, 그 사이사이와 양 끝 자리에 이웃하면 안 되는 사람을 세워요.",
                              steps: [SolutionStep(hint: "나머지 \(others)명을 세우고 \(others + 1)개의 틈에 \(k)명을 세우면", work: "\(others)! × \(others + 1)P\(k) = \(d(v))")], answer: d(v))
            }
            return Solved(kind: .counting, topic: "이웃하는 경우의 수", concept: "이웃하는 사람들을 한 묶음으로 보고 나열한 뒤, 묶음 안에서 자리를 바꾸는 경우를 곱해요.",
                          steps: [SolutionStep(hint: "\(k)명을 한 묶음으로 → \(n - k + 1)개를 나열", work: "\(n - k + 1)! = \(d(fact(n - k + 1)))"),
                                  SolutionStep(hint: "묶음 안에서 \(k)명이 자리를 바꾸는 경우", work: "\(k)! = \(d(fact(k)))"),
                                  SolutionStep(hint: "곱하면", work: d(together))],
                          answer: d(together))
        }
        if let m = match(t, #"(\d+)\s*명"#), let n = Int(m[1]) { total = n }
        else if let m = match(t, #"([A-Z](?:\s*,\s*[A-Z]){2,})"#) { total = m[1].split(separator: ",").count }
        guard let n = total, n >= 3, n <= 12 else { return nil }
        let apart = has(t, ["이웃하지 않", "이웃하지않"])
        // "A, B, C 3명이 이웃하여" (세 명 이상 묶음)
        if let m = match(t, #"([A-Z](?:\s*(?:,|와|과)\s*[A-Z]){2,})\s*(?:\d+\s*명)?\s*(?:이|가|는)?\s*(?:서로\s*)?이웃"#), !circular, !apart {
            let k = m[1].filter { $0.isUppercase }.count
            guard k < n else { return nil }
            let v = fact(n - k + 1) * fact(k)
            return Solved(kind: .counting, topic: "이웃하는 경우의 수", concept: "이웃하는 사람들을 한 묶음으로 보고 나열한 뒤, 묶음 안에서 자리를 바꾸는 경우를 곱해요.",
                          steps: [SolutionStep(hint: "\(k)명을 한 묶음으로 → \(n - k + 1)개를 나열", work: "\(n - k + 1)! = \(d(fact(n - k + 1)))"),
                                  SolutionStep(hint: "묶음 안에서 \(k)명이 자리를 바꾸는 경우", work: "\(k)! = \(d(fact(k)))"),
                                  SolutionStep(hint: "곱하면", work: d(v))],
                          answer: d(v))
        }
        // "A와 B가 이웃", "A, B가 이웃"
        guard t.range(of: #"[A-Z]\s*(?:와|과|,)\s*[A-Z]\s*(?:가|는|이)?\s*(?:서로\s*)?이웃"#, options: .regularExpression) != nil else { return nil }
        if circular {
            let together = fact(n - 2) * 2
            let v = apart ? fact(n - 1) - together : together
            return Solved(kind: .counting, topic: "원순열 (이웃하는 경우)", concept: "원탁에 n명이 앉는 경우의 수는 (n−1)!. 이웃하는 두 명은 한 묶음으로 보고 (n−2)! × 2",
                          steps: [SolutionStep(hint: "두 명을 묶어 \(n - 1)개를 원형으로", work: "(\(n - 1) − 1)! × 2 = \(d(together))")] + (apart ? [SolutionStep(hint: "전체 (\(n)−1)!에서 빼면", work: "\(d(fact(n - 1))) − \(d(together)) = \(d(v))")] : []),
                          answer: d(v))
        }
        let together = fact(n - 1) * 2
        if apart {
            let v = fact(n) - together
            return Solved(kind: .counting, topic: "이웃하지 않는 경우의 수", concept: "(전체 경우의 수) − (이웃하는 경우의 수)",
                          steps: [SolutionStep(hint: "전체 \(n)명을 일렬로", work: "\(n)! = \(d(fact(n)))"),
                                  SolutionStep(hint: "두 명이 이웃하는 경우", work: "\(n - 1)! × 2 = \(d(together))"),
                                  SolutionStep(hint: "빼면", work: d(v))],
                          answer: d(v))
        }
        return Solved(kind: .counting, topic: "이웃하는 경우의 수", concept: "이웃하는 두 사람을 한 묶음으로 보고 나열한 뒤, 묶음 안에서 자리를 바꾸는 2가지를 곱해요.",
                      steps: [SolutionStep(hint: "두 명을 한 묶음으로 → \(n - 1)개를 나열", work: "\(n - 1)! = \(d(fact(n - 1)))"),
                              SolutionStep(hint: "묶음 안에서 자리 바꾸기", work: "× 2 = \(d(together))")],
                      answer: d(together))
    }

    // MARK: - 이항정리: (ax^p + bx^q)ⁿ 에서 x^k의 계수, 상수항

    static func binomialTerm(_ raw: String) -> Solved? {
        guard has(raw, ["계수", "상수항"]), has(raw, ["전개"]) else { return nil }
        let t = DoitMathExact.superscriptsToPowers(DoitAlgebra.normalize(raw)).replacingOccurrences(of: " ", with: "")
        guard let m = match(t, #"\(([^()]+?)([+-])([^()]+?)\)\^(\d+)"#), let n = Int(m[4]), n >= 1, n <= 30,
              let (c1, p1) = monomial(m[1]), let (c2raw, p2) = monomial(m[3]), p1 != p2 else { return nil }
        let c2 = m[2] == "-" ? -c2raw : c2raw
        var target: Int
        if has(raw, ["상수항"]) { target = 0 }
        else if let k = match(t, #"x\^(\d+)의계수"#).flatMap({ Int($0[1]) }) { target = k }
        else if t.contains("x의계수") { target = 1 }
        else { return nil }
        // 일반항: nCr (c1 x^p1)^(n−r) (c2 x^p2)^r, 차수 p1(n−r) + p2 r
        var found: [(Int, Double)] = []
        for r in 0...n where p1 * (n - r) + p2 * r == target {
            let v = comb(n, r) * pow(c1, Double(n - r)) * pow(c2, Double(r))
            found.append((r, v))
        }
        let value = found.reduce(0) { $0 + $1.1 }
        let what = target == 0 ? "상수항" : "x\(DoitMath.superscript(target))의 계수"
        let steps = [SolutionStep(hint: "일반항 ₙCᵣ (첫째 항)ⁿ⁻ʳ (둘째 항)ʳ 에서 x의 지수가 \(target)이 되는 r", work: found.isEmpty ? "그런 r이 없어요" : found.map { "r = \($0.0)" }.joined(separator: ", ")),
                     SolutionStep(hint: "계수를 계산하면", work: found.map { "\(n)C\($0.0) × \(f(c1))^\(n - $0.0) × (\(f(c2)))^\($0.0) = \(f($0.1))" }.joined(separator: ", "))]
        return Solved(kind: .counting, topic: "이항정리", concept: "(a + b)ⁿ의 전개식의 일반항은 ₙCᵣ aⁿ⁻ʳ bʳ 이에요.", steps: steps, answer: "\(what) \(f(value))")
    }

    /// "2x" → (2, 1), "x^2" → (1, 2), "1/x" → (1, −1), "3" → (3, 0), "1/x^2" → (1, −2)
    private static func monomial(_ s: String) -> (Double, Int)? {
        if let m = match(s, #"^(\d*(?:\.\d+)?)/x(?:\^(\d+))?$"#) {
            let c = m[1].isEmpty ? 1 : Double(m[1]) ?? 1
            return (c, -(Int(m[2]) ?? 1))
        }
        if let m = match(s, #"^(\d*(?:\.\d+)?)\*?x(?:\^(\d+))?$"#) {
            let c = m[1].isEmpty ? 1 : Double(m[1]) ?? 1
            return (c, Int(m[2]) ?? 1)
        }
        if let m = match(s, #"^(\d+(?:\.\d+)?)$"#), let c = Double(m[1]) { return (c, 0) }
        return nil
    }
}
