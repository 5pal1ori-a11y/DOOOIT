import Foundation

/// 물은 값으로 답하기 + 다른 풀이가 엉뚱하게 받던 유형들
/// - focus: 답에 여러 값이 있으면 문제가 물은 값 하나로 ("x절편은?" → "기울기 2, y절편 −6, x절편 3"의 3)
///   물은 값을 만들 수 없으면 nil (틀린 답보다 안 푸는 게 나아요)
/// - solve: 두 근으로 이차방정식 만들기, x + 1/x = k일 때 식의 값, 미분계수의 정의(lim), 나머지 두 개로 일차식 나머지,
///   그래프가 지나는 점, 여사건, 몇 %, 가로·세로 관계가 주어진 직사각형, 인수분해한 꼴의 상수, a√b 꼴
enum DoitMathAsked {
    typealias Solved = MathSolver.Solved

    private static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }
    private static func match(_ t: String, _ p: String) -> [String]? { DoitMathExact.match(t, p) }
    private static func matches(_ t: String, _ p: String) -> [[String]] { DoitMathExact.matches(t, p) }
    private static func f(_ v: Double) -> String { DoitMath.fraction(v).replacingOccurrences(of: "−", with: "-") }
    private static let num = #"-?\d+(?:\.\d+)?(?:/\d+)?"#

    /// "3", "-1/2", "0.8" → 값
    private static func value(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "−", with: "-")
        let parts = t.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]), b != 0 { return a / b }
        return Double(t)
    }

    /// 깔끔한 값인지 (정수 · 분모 100 이하 분수)
    private static func isNice(_ v: Double) -> Bool {
        guard v.isFinite, abs(v) < 1e12 else { return false }
        return !DoitMath.fraction(v).contains(".") && !DoitMath.fraction(v).contains("e")
    }

    /// 문제가 묻는 식 ("…일 때, x² + 1/x² 의 값은?" → "x^2 + 1/x^2")
    private static func askedExpression(_ t: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: #"([0-9a-z+\-*/^().√ ]+?)\s*의\s*값"#),
              let last = re.matches(in: t, range: NSRange(t.startIndex..., in: t)).last,
              let whole = Range(last.range, in: t), let r = Range(last.range(at: 1), in: t) else { return nil }
        // "상수 a, b의 값"은 값 여러 개를 묻는 것 (b 하나가 아님)
        if String(t[..<whole.lowerBound]).range(of: #"[a-zA-Z]\s*,\s*$"#, options: .regularExpression) != nil { return nil }
        let e = t[r].trimmingCharacters(in: .whitespaces)
        return e.isEmpty ? nil : e
    }

    // MARK: - 물은 값 하나로

    static func focus(_ solved: Solved, _ raw: String) -> Solved? {
        let t = DoitAlgebra.normalize(DoitMathExact.tidy(raw))
        let answer = solved.answer
        // 선지 번호를 고른 답은 이미 본문으로 맞춰 본 것
        if let first = answer.first, "①②③④⑤".contains(first) { return solved }
        // 수 하나를 묻는 말 ("가장 큰 정수", "개수", "경우의 수")인데 답이 식·범위면 물은 값이 아님
        if has(t, ["가장 큰 정수", "가장 작은 정수", "가장 큰 자연수", "가장 작은 자연수", "의 개수", "몇 개", "경우의 수"]), !looksLikeValue(answer) { return nil }
        func pick(_ value: String) -> Solved {
            var out = solved
            if value != answer { out.steps.append(SolutionStep(hint: "구한 값을 정리하면", work: answer)) }
            out.answer = value
            return out
        }
        if let s = aliased(solved, t) { return s }
        // 판별식의 값: "D = 13 → 서로 다른 두 실근" → 13
        if answer.hasPrefix("D = "), has(t, ["판별식의 값", "D의 값", "D 의 값", "D값"]), let m = match(answer, #"^D = ([^→]+?)\s*→"#) {
            return pick(m[1])
        }
        // "점근선 x = 1, y = 2": 두 점근선의 교점 → (1, 2)
        if let m = match(answer, #"^점근선 x = ([^,]+), y = (.+)$"#) {
            if has(t, ["교점"]) { return pick("(\(m[1]), \(m[2]))") }
            if has(t, ["점근선"]) { return solved }
        }
        // 이름표가 붙은 값 여러 개: "기울기 2, y절편 -6, x절편 3", "중심 (2, -3), 반지름 4", "몫 x² − x − 2, 나머지 0"
        let parts = labeledParts(answer)
        if parts.count >= 2 {
            let asked = parts.filter { asks(t, $0.label) }
            // 물은 값만 이름표와 함께 ("x절편 3", "반지름 4", "최솟값 0")
            if asked.count == 1 { return pick("\(asked[0].label) \(asked[0].value)") }
            // "기울기와 y절편의 합", "최댓값과 최솟값의 곱"
            if asked.count == 2, let op = match(t, asked[0].label + #"\S*\s*(?:와|과)\s*"# + asked[1].label + #"\S*\s*의\s*(합|곱)"#) ?? match(t, asked[1].label + #"\S*\s*(?:와|과)\s*"# + asked[0].label + #"\S*\s*의\s*(합|곱)"#),
               let x = value(asked[0].value), let y = value(asked[1].value) {
                let v = op[1] == "합" ? x + y : x * y
                var out = pick(f(v))
                out.steps.append(SolutionStep(hint: "\(asked[0].label)\(op[1] == "합" ? " + " : " × ")\(asked[1].label)", work: "\(asked[0].value)\(op[1] == "합" ? " + " : " × ")(\(asked[1].value)) = \(f(v))"))
                return out
            }
        }
        // "x = 3, y = 4": 교점의 좌표 → (3, 4), "x + y의 값" → 7
        let pairs = matches(answer, #"(?:^|,\s*)([a-z])\s*=\s*([^,=]+)"#)
        if pairs.count >= 2, pairs.map({ $0[0] }).joined().count == answer.count {
            var values: [Character: Double] = [:]
            var texts: [Character: String] = [:]
            for p in pairs {
                guard let name = p[1].first else { continue }
                texts[name] = p[2].trimmingCharacters(in: .whitespaces)
                if let v = value(p[2]) { values[name] = v }
            }
            if let x = texts["x"], let y = texts["y"], texts.count == 2, has(t, ["교점의 좌표", "점의 좌표", "좌표를 구", "좌표는"]), !has(t, ["x좌표", "y좌표"]) {
                return pick("(\(x), \(y))")
            }
            if let e = askedExpression(t) {
                var target = e
                // "해가 x = a, y = b일 때 a + b" / "해를 x = p, y = q라 할 때"
                if let alias = match(t, #"x\s*=\s*([a-w])\s*,\s*y\s*=\s*([a-w])\s*(?:이라|라|일\s*때|일때)"#) {
                    target = String(target.map { String($0) == alias[1] ? "x" : String($0) == alias[2] ? "y" : $0 })
                }
                let letters = Set(target.filter { $0.isLetter && $0.isASCII })
                if !letters.isEmpty, letters.isSubset(of: Set(values.keys)) {
                    if letters.count == 1, target.trimmingCharacters(in: .whitespaces).count == 1, let name = letters.first, let v = values[name] { return pick(f(v)) }
                    var filled = target
                    for (name, v) in values { filled = filled.replacingOccurrences(of: String(name), with: "(\(v))") }
                    if let v = Expression.evaluate(filled), isNice(v) {
                        var out = pick(f(v))
                        out.steps.append(SolutionStep(hint: "구한 값을 \(target)에 넣으면", work: "\(target) = \(f(v))"))
                        return out
                    }
                    return nil
                }
                // 묻는 문자(a, b)가 답에 없으면 물은 값이 아님
                if !letters.isEmpty, letters.isDisjoint(with: Set(values.keys)) { return nil }
            }
        }
        // "a의 값은?"처럼 문자 하나를 물었는데, 답이 그 문자가 아닌 다른 것들의 설명이면 물은 값이 아님
        if let m = match(t, #"(?<![a-z(])([a-z])\s*의\s*값(?!의\s*범위)"#), let letter = m[1].first,
           !answer.contains(letter), answer.contains(where: { DoitSubjectNote.isHangul($0) }) || answer.contains(",") {
            // "공비 r의 값" → "공비 3"은 물은 값 (문자 앞 이름이 답에 있으면)
            if let named = match(t, "([가-힣]+)\\s*\(m[1])\\s*의\\s*값"), answer.hasPrefix(named[1]) { return solved }
            return nil
        }
        // "a − b의 값"을 물었는데 답에 a, b가 없고 값도 아니면 (예: 인수분해한 식만) 물은 값이 아님
        if let e = askedExpression(t) {
            let letters = Set(e.filter { $0.isASCII && $0.isLetter })
            if !letters.isEmpty, letters.isDisjoint(with: Set(answer.filter { $0.isASCII && $0.isLetter })), !looksLikeValue(answer) { return nil }
        }
        // "x의 값의 범위"인데 범위가 아닌 답
        if has(t, ["값의 범위", "의 범위를", "의 범위는"]), !has(t, ["자료", "변량", "평균"]), !answer.contains(where: { "<>≤≥".contains($0) }), !has(answer, ["모든 실수", "해가 없", "없어요"]) {
            return nil
        }
        return solved
    }

    /// "y절편을 b라 할 때 b의 값", "중점의 좌표를 (a, b)라 할 때 a + b의 값", "제10항을 a라 할 때 2a의 값"
    /// 구한 값을 그 문자로 놓고 묻는 식을 계산 (값이 하나로 정해질 때만)
    private static func aliased(_ solved: Solved, _ t: String) -> Solved? {
        guard let m = match(t, #"(?:을|를)\s*(\(\s*[a-w]\s*,\s*[a-w]\s*\)|[a-w])\s*(?:이라|라)\s*(?:할|하면|하자|하고|놓)"#),
              let e = askedExpression(t) else { return nil }
        let names = m[1].filter { $0.isLetter }
        let letters = Set(e.filter { $0.isASCII && $0.isLetter })
        guard !letters.isEmpty, letters.isSubset(of: Set(names)) else { return nil }
        var a = solved.answer.replacingOccurrences(of: #"\s*\(≈[^)]*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        // 이름표가 여러 개면 물은 것 하나 ("기울기 2, y절편 3"에서 y절편)
        let parts = labeledParts(a)
        if parts.count >= 2 {
            let asked = parts.filter { asks(t, $0.label) }
            guard asked.count == 1 else { return nil }
            a = asked[0].value
        }
        a = a.replacingOccurrences(of: #"^(?:[가-힣0-9]+\s+|[^=]{1,15}=\s*)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        var values: [Character: Double] = [:]
        if names.count == 2 {
            guard let tuple = match(a, "^\\((\(num))\\s*,\\s*(\(num))\\)$"), let x = value(tuple[1]), let y = value(tuple[2]) else { return nil }
            values[names.first!] = x; values[names.last!] = y
        } else {
            guard let v = value(a.replacingOccurrences(of: "−", with: "-")) else { return nil }
            values[names.first!] = v
        }
        var filled = e
        for (name, v) in values { filled = filled.replacingOccurrences(of: String(name), with: "(\(v))") }
        guard let v = Expression.evaluate(filled), isNice(v) else { return nil }
        var out = solved
        out.steps.append(SolutionStep(hint: names.count == 2 ? "\(m[1]) = \(a)이므로" : "\(names) = \(a)이므로", work: "\(e) = \(f(v))"))
        out.answer = f(v)
        return out
    }

    /// 값 하나로 된 답인지 ("7", "−3/4", "2√2 (≈ 2.83)", "36π", "25%", "4개")
    private static func looksLikeValue(_ answer: String) -> Bool {
        var a = answer.replacingOccurrences(of: #"\s*\(≈[^)]*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        // 이름표 하나 ("빗변 10", "x = 4")
        a = a.replacingOccurrences(of: #"^(?:[가-힣]+\s+|[a-zA-Z()∪∩ᶜ ]{1,12}=\s*)"#, with: "", options: .regularExpression)
        return a.range(of: #"^[-−]?[0-9./√π ]+(%|개|명|가지|cm|m|km|kg|g|원|°)?$"#, options: .regularExpression) != nil
    }

    /// 문제가 이 이름표의 값을 묻는지 ("반지름의 길이는?" → 반지름)
    private static func asks(_ t: String, _ label: String) -> Bool {
        let compact = t.replacingOccurrences(of: " ", with: "")
        return compact.contains(label.replacingOccurrences(of: " ", with: ""))
    }

    /// "기울기 2, y절편 -6, x절편 3" → [(기울기, 2), (y절편, -6), (x절편, 3)] (괄호 속 쉼표는 나누지 않음)
    /// "최댓값 4 (x = 1)"의 "(x = 1)"은 값에서 뺌
    private static func labeledParts(_ answer: String) -> [(label: String, value: String)] {
        var pieces: [String] = [], current = "", depth = 0
        for c in answer {
            if c == "(" || c == "{" { depth += 1 }
            if c == ")" || c == "}" { depth -= 1 }
            if c == ",", depth == 0 { pieces.append(current); current = ""; continue }
            current.append(c)
        }
        pieces.append(current)
        var out: [(String, String)] = []
        for piece in pieces {
            let p = piece.trimmingCharacters(in: .whitespaces)
            guard let m = match(p, #"^([xy]?[가-힣]+)\s+(.+)$"#) else { return [] }
            var v = m[2].replacingOccurrences(of: #"\s*\((?:x|y)\s*=[^)]*\)\s*$"#, with: "", options: .regularExpression)
            v = v.trimmingCharacters(in: .whitespaces)
            guard !v.contains(where: { DoitSubjectNote.isHangul($0) }) else { return [] }
            out.append((m[1], v))
        }
        return out
    }

    // MARK: - 유형들

    static func solve(_ t: String) -> Solved? {
        if let s = equationFromRoots(t) { return s }
        if let s = reciprocalSum(t) { return s }
        if let s = differenceQuotient(t) { return s }
        if let s = twoRemainders(t) { return s }
        if let s = throughPoint(t) { return s }
        if let s = complement(t) { return s }
        if let s = percentOf(t) { return s }
        if let s = rectangleRelation(t) { return s }
        if let s = factoredConstants(t) { return s }
        if let s = surdForm(t) { return s }
        if let s = yIntercept(t) { return s }
        if let s = roles(t) { return s }
        if let s = multiplesCount(t) { return s }
        if let s = combinationEquation(t) { return s }
        if let s = repeatedTrials(t) { return s }
        if let s = movedReciprocal(t) { return s }
        if let s = trigQuadrant(t) { return s }
        if let s = constantFromCondition(t) { return s }
        if let s = areaBetween(t) { return s }
        if let s = roundTrip(t) { return s }
        if let s = repeatingDecimal(t) { return s }
        return nil
    }

    /// "두 근이 2, −3이고 x²의 계수가 1인 이차방정식" → x² + x − 6 = 0
    private static func equationFromRoots(_ t: String) -> Solved? {
        guard has(t, ["이차방정식"]), !has(t, ["상수", "값은", "값을"]),
              let m = match(t, "두\\s*근(?:이|은|을)?\\s*(\(num))\\s*(?:,|와|과)\\s*(\(num))\\s*(?:이고|인|일)"),
              let p = value(m[1]), let q = value(m[2]) else { return nil }
        // x 말고 다른 문자(상수)가 있으면 상수 구하기 문제
        let letters = Set(t.filter { $0.isASCII && $0.isLetter }).subtracting(["x"])
        guard letters.isEmpty else { return nil }
        var a = 1.0
        if let c = match(t, "x\\^2\\s*의\\s*계수(?:가|는|이)\\s*(\(num))"), let v = value(c[1]), v != 0 { a = v }
        var poly = DoitMath.Poly()
        poly.c[2] = a; poly.c[1] = -a * (p + q); poly.c[0] = a * p * q
        let answer = DoitMath.describe(poly) + " = 0"
        return Solved(kind: .quadraticEquation, topic: "두 근이 주어진 이차방정식",
                      concept: "두 근이 α, β이고 x²의 계수가 a인 이차방정식은 a(x − α)(x − β) = 0, 곧 a{x² − (α + β)x + αβ} = 0 이에요.",
                      steps: [SolutionStep(hint: "두 근의 합과 곱", work: "α + β = \(f(p + q)), αβ = \(f(p * q))"),
                              SolutionStep(hint: "a{x² − (α + β)x + αβ} = 0", work: answer)],
                      answer: answer)
    }

    /// "x + 1/x = 4일 때 x² + 1/x²의 값" (x − 1/x = k도): 두 근 어느 쪽을 넣어도 같은 값일 때만
    private static func reciprocalSum(_ t: String) -> Solved? {
        let compact = t.replacingOccurrences(of: " ", with: "")
        guard let m = match(compact, "(?<![0-9a-z^)])x([+-])1/x=(\(num))(?:이고|일때|일|,)"), let k = value(m[2]),
              let e = askedExpression(t), e.contains("x"), Set(e.filter { $0.isLetter }) == ["x"] else { return nil }
        let plus = m[1] == "+"
        // x + 1/x = k → x² − kx + 1 = 0, x − 1/x = k → x² − kx − 1 = 0
        let c = plus ? 1.0 : -1.0
        let d = k * k - 4 * c
        guard d >= 0 else { return nil }
        let roots = [(k + d.squareRoot()) / 2, (k - d.squareRoot()) / 2]
        let values = roots.compactMap { Expression.evaluate(e, x: $0) }
        guard values.count == 2, abs(values[0] - values[1]) < 1e-7 * max(1, abs(values[0])), isNice(values[0]) else { return nil }
        let v = values[0]
        let sign = plus ? "+" : "−"
        var steps = [SolutionStep(hint: "주어진 식", work: "x \(sign) 1/x = \(f(k))")]
        let e2 = e.replacingOccurrences(of: " ", with: "")
        if e2 == "x^2+1/x^2" {
            steps.append(SolutionStep(hint: "x² + 1/x² = (x \(sign) 1/x)² \(plus ? "−" : "+") 2", work: "\(f(k))² \(plus ? "−" : "+") 2 = \(f(v))"))
        } else if e2 == "x^3+1/x^3", plus {
            steps.append(SolutionStep(hint: "x³ + 1/x³ = (x + 1/x)³ − 3(x + 1/x)", work: "\(f(k))³ − 3 × \(f(k)) = \(f(v))"))
        } else {
            steps.append(SolutionStep(hint: "곱셈 공식의 변형으로 (x \(sign) 1/x)의 식으로 바꾸면", work: "\(e.replacingOccurrences(of: "^2", with: "²").replacingOccurrences(of: "^3", with: "³")) = \(f(v))"))
        }
        return Solved(kind: .expression, topic: "곱셈 공식의 변형 (x ± 1/x)",
                      concept: "x² + 1/x² = (x + 1/x)² − 2 = (x − 1/x)² + 2, x³ + 1/x³ = (x + 1/x)³ − 3(x + 1/x)",
                      steps: steps, answer: f(v))
    }

    /// lim_{h→0} {f(a + ph) − f(a − qh)}/(rh) = (p + q)/r × f'(a), lim_{x→a} {f(x) − f(a)}/(x − a) = f'(a)
    private static func differenceQuotient(_ t: String) -> Solved? {
        guard has(t, ["lim"]), let fx = MathSolver.function(in: t) else { return nil }
        let c = t.replacingOccurrences(of: " ", with: "")
        var a: Double?, scale = 1.0, shown = ""
        if let m = match(c, "[{(\\[]?f\\((\(num))\\+(\\d*)h\\)-f\\((\(num))(?:(-)(\\d*)h)?\\)[})\\]]?/\\(?(\\d*)h\\)?"),
           let a1 = value(m[1]), let a2 = value(m[3]), abs(a1 - a2) < 1e-12 {
            let p = Double(m[2]) ?? 1
            let q = m[4].isEmpty ? 0 : (Double(m[5]) ?? 1)
            let r = Double(m[6]) ?? 1
            a = a1
            scale = (p + q) / r
            shown = scale == 1 ? "f'(\(f(a1)))" : "\(f(scale)) × f'(\(f(a1)))"
        } else if let m = match(c, "[{(\\[]?f\\(x\\)-f\\((\(num))\\)[})\\]]?/\\(x-(\(num))\\)"), let a1 = value(m[1]), let a2 = value(m[2]), abs(a1 - a2) < 1e-12 {
            a = a1
            shown = "f'(\(f(a1)))"
        }
        guard let a else { return nil }
        var derivative = 0.0
        for i in 1..<DoitMath.Poly.size where abs(fx[i]) > 1e-12 { derivative += Double(i) * fx[i] * pow(a, Double(i - 1)) }
        let v = scale * derivative
        var d = DoitMath.Poly()
        for i in 1..<DoitMath.Poly.size { d.c[i - 1] = Double(i) * fx[i] }
        return Solved(kind: .derivative, topic: "미분계수의 정의",
                      concept: "lim_{h→0} {f(a + h) − f(a)}/h = f'(a), lim_{x→a} {f(x) − f(a)}/(x − a) = f'(a) 예요. h 앞의 수가 다르면 그만큼 곱하고 나눠요.",
                      steps: [SolutionStep(hint: "미분계수의 정의로 바꾸면", work: shown),
                              SolutionStep(hint: "f'(x)를 구하면", work: "f'(x) = \(DoitMath.describe(d))"),
                              SolutionStep(hint: "x = \(f(a))를 넣으면", work: "\(shown) = \(f(v))")],
                      answer: f(v))
    }

    /// "x − 1로 나눈 나머지가 3, x + 2로 나눈 나머지가 −3일 때, (x − 1)(x + 2)로 나눈 나머지" → 2x + 1
    private static func twoRemainders(_ t: String) -> Solved? {
        let c = t.replacingOccurrences(of: " ", with: "")
        guard let asked = match(c, #"\(x([+-])(\d+(?:\.\d+)?)\)\(x([+-])(\d+(?:\.\d+)?)\)(?:으로|로)나[누눈]"#), c.contains("나머지") else { return nil }
        let r1 = (asked[1] == "-" ? 1 : -1) * (Double(asked[2]) ?? 0), r2 = (asked[3] == "-" ? 1 : -1) * (Double(asked[4]) ?? 0)
        guard abs(r1 - r2) > 1e-12 else { return nil }
        var given: [Double: Double] = [:]
        for m in matches(c, "(?<![)])x([+-])(\\d+(?:\\.\\d+)?)(?:으로|로)나[누눈]나머지(?:가|는|이)(\(num))") {
            let root = (m[1] == "-" ? 1 : -1) * (Double(m[2]) ?? 0)
            if let v = value(m[3]) { given[root] = v }
        }
        guard let v1 = given[r1], let v2 = given[r2] else { return nil }
        let p = (v1 - v2) / (r1 - r2), q = v1 - p * r1
        var poly = DoitMath.Poly()
        poly.c[1] = p; poly.c[0] = q
        let answer = DoitMath.describe(poly)
        return Solved(kind: .remainder, topic: "나머지정리 (이차식으로 나눈 나머지)",
                      concept: "이차식으로 나눈 나머지는 일차 이하라 ax + b로 놓고, 나머지정리 f(α) = (나머지)에 넣어 a, b를 구해요.",
                      steps: [SolutionStep(hint: "f(x) = (x − α)(x − β)Q(x) + ax + b 로 놓으면", work: "f(\(f(r1))) = \(f(r1))a + b = \(f(v1)), f(\(f(r2))) = \(f(r2))a + b = \(f(v2))"),
                              SolutionStep(hint: "두 식을 연립하면", work: "a = \(f(p)), b = \(f(q))")],
                      answer: answer.isEmpty ? "0" : answer)
    }

    /// "y = √(2x + 4)의 그래프가 점 (a, 4)를 지날 때, a의 값" (식에 상수가 없는 함수만)
    private static func throughPoint(_ t: String) -> Solved? {
        guard let p = match(t, #"점\s*\(\s*([a-w]|-?\d+(?:\.\d+)?(?:/\d+)?)\s*,\s*([a-w]|-?\d+(?:\.\d+)?(?:/\d+)?)\s*\)\s*(?:을|를)?\s*지[나날]"#),
              let ask = match(t, #"([a-w])\s*의\s*값"#), p[1] == ask[1] || p[2] == ask[1],
              let fm = match(t, #"(?:y|f\(x\))\s*=\s*([^가-힣,]+?)\s*(?:의|이|은|는)?\s*(?:그래프|$)"#) else { return nil }
        let expression = fm[1].trimmingCharacters(in: .whitespaces)
        guard expression.contains("x"), Set(expression.filter { $0.isLetter && $0.isASCII }) == ["x"],
              Expression.evaluate(expression, x: 0.37) != nil || Expression.evaluate(expression, x: 5.37) != nil else { return nil }
        if p[2] == ask[1], let x0 = value(p[1]) {
            guard let v = Expression.evaluate(expression, x: x0), isNice(v) else { return nil }
            return Solved(kind: .function, topic: "그래프 위의 점", concept: "점 (p, q)가 그래프 위에 있으면 x = p를 넣은 값이 q예요.",
                          steps: [SolutionStep(hint: "x = \(f(x0))를 넣으면", work: "\(ask[1]) = \(f(v))")], answer: f(v))
        }
        guard p[1] == ask[1], let y0 = value(p[2]) else { return nil }
        // f(x) = y0 의 실근 찾기 (−200 ~ 200, 부호가 바뀌는 곳을 반씩 줄여서)
        func g(_ x: Double) -> Double? { Expression.evaluate(expression, x: x).map { $0 - y0 } }
        var roots: [Double] = []
        var prev: (x: Double, v: Double)?
        for i in 0...8000 {
            let x = -200 + Double(i) * 0.05
            guard let v = g(x) else { prev = nil; continue }
            if abs(v) < 1e-12 { roots.append(x) }
            else if let pr = prev, pr.v * v < 0 {
                var lo = pr.x, hi = x, flo = pr.v
                for _ in 0..<80 {
                    let mid = (lo + hi) / 2
                    guard let fm = g(mid) else { break }
                    if flo * fm <= 0 { hi = mid } else { lo = mid; flo = fm }
                }
                roots.append((lo + hi) / 2)
            }
            prev = (x, v)
            if roots.count > 3 { return nil }
        }
        var exact: [Double] = []
        for r in roots {
            guard let txt = Optional(DoitMath.fraction(r)), isNice(r), let back = value(txt.replacingOccurrences(of: "−", with: "-")),
                  let check = g(back), abs(check) < 1e-9, !exact.contains(where: { abs($0 - back) < 1e-9 }) else { continue }
            exact.append(back)
        }
        guard exact.count == 1, exact.count == Set(roots.map { ($0 * 1e6).rounded() }).count else { return nil }
        let x0 = exact[0]
        return Solved(kind: .function, topic: "그래프 위의 점", concept: "점 (p, q)가 그래프 위에 있으면 x = p를 넣은 값이 q예요.",
                      steps: [SolutionStep(hint: "점의 좌표를 식에 넣으면", work: "\(f(y0)) = \(expression.replacingOccurrences(of: "x", with: ask[1]))"),
                              SolutionStep(hint: "풀면", work: "\(ask[1]) = \(f(x0))")],
                      answer: f(x0))
    }

    /// "사건 A가 일어날 확률이 1/3일 때, 사건 A가 일어나지 않을 확률" → 1 − 1/3
    private static func complement(_ t: String) -> Solved? {
        guard has(t, ["일어나지 않을 확률", "일어나지 않는 확률"]),
              let m = match(t, "일어날\\s*확률(?:이|은|는)\\s*(\(num))"), let p = value(m[1]), (0...1).contains(p) else { return nil }
        return Solved(kind: .counting, topic: "여사건의 확률", concept: "사건 A가 일어나지 않을 확률은 1 − P(A)예요.",
                      steps: [SolutionStep(hint: "1 − P(A)", work: "1 − \(f(p)) = \(f(1 - p))")], answer: f(1 - p))
    }

    /// "500원은 2000원의 몇 %인가?" → 25%
    private static func percentOf(_ t: String) -> Solved? {
        let unit = #"(?:원|개|명|cm|mm|km|kg|g|m|L|mL|점|분|시간|마리|권)?"#
        guard let m = match(t, "(\(num))\\s*\(unit)\\s*(?:은|는|이|가)\\s*(\(num))\\s*\(unit)\\s*의\\s*몇\\s*(?:%|퍼센트|프로)"),
              let a = value(m[1]), let b = value(m[2]), b != 0 else { return nil }
        let v = a / b * 100
        return Solved(kind: .percent, topic: "비율을 백분율로", concept: "A는 B의 몇 %? → (A ÷ B) × 100",
                      steps: [SolutionStep(hint: "(비교하는 양 ÷ 기준량) × 100", work: "\(f(a)) ÷ \(f(b)) × 100 = \(DoitMath.format(v))")],
                      answer: DoitMath.format(v) + "%")
    }

    /// "가로의 길이가 세로의 길이보다 3cm 긴 직사각형의 둘레의 길이가 26cm일 때, 가로의 길이" → 8
    private static func rectangleRelation(_ t: String) -> Solved? {
        guard has(t, ["직사각형"]),
              let m = match(t, "(가로|세로)의?\\s*길이(?:가|는)\\s*(가로|세로)의?\\s*길이보다\\s*(\(num))\\s*(?:cm|m|mm)?\\s*(?:더\\s*)?(긴|길고|짧은|짧고)"),
              m[1] != m[2], let d = value(m[3]),
              let pm = match(t, "둘레의?\\s*길이(?:가|는)\\s*(\(num))"), let perimeter = value(pm[1]) else { return nil }
        // 앞 = 뒤 ± d, 2(앞 + 뒤) = 둘레
        let longer = m[4].hasPrefix("긴") || m[4].hasPrefix("길")
        let other = (perimeter / 2 - (longer ? d : -d)) / 2
        let first = other + (longer ? d : -d)
        guard other > 0, first > 0 else { return nil }
        let width = m[1] == "가로" ? first : other, height = m[1] == "가로" ? other : first
        let tail = t.components(separatedBy: "일 때").last ?? t
        let answer: String
        if has(tail, ["넓이"]) { answer = f(width * height) }
        else if has(tail, ["가로"]) && !has(tail, ["세로"]) { answer = f(width) }
        else if has(tail, ["세로"]) && !has(tail, ["가로"]) { answer = f(height) }
        else { return nil }
        return Solved(kind: .geometry, topic: "직사각형의 둘레 (방정식)", concept: "모르는 길이를 x로 놓고 둘레 = 2 × (가로 + 세로)로 식을 세워요.",
                      steps: [SolutionStep(hint: "\(m[2])의 길이를 x라 하면 \(m[1])의 길이는 x \(longer ? "+" : "−") \(f(d))", work: "2{x + (x \(longer ? "+" : "−") \(f(d)))} = \(f(perimeter))"),
                              SolutionStep(hint: "풀면", work: "x = \(f(other)) → 가로 \(f(width)), 세로 \(f(height))")],
                      answer: answer)
    }

    /// "x² − 2x − 15를 인수분해하면 (x + a)(x + b)일 때, a + b의 값" (a, b를 바꿔도 같은 값일 때만)
    private static func factoredConstants(_ t: String) -> Solved? {
        let c = t.replacingOccurrences(of: " ", with: "")
        guard has(c, ["인수분해"]), let m = match(c, #"\(x([+-])([a-w])\)\(x([+-])([a-w])\)"#), m[2] != m[4],
              let e = askedExpression(t), let range = c.range(of: "인수분해") else { return nil }
        let before = String(c[..<range.lowerBound])
        guard let p = DoitMath.polynomial(DoitMath.extractExpression(before.replacingOccurrences(of: #"(을|를)$"#, with: "", options: .regularExpression))),
              p.degree == 2, abs(p[2] - 1) < 1e-12 else { return nil }
        let roots = DoitAlgebra.realRoots(p)
        guard roots.count == 2 else { return nil }
        // x + a = 0 의 근이 r이면 a = −r, x − a 이면 a = r
        func constant(_ sign: String, _ r: Double) -> Double { sign == "+" ? -r : r }
        let first = [(roots[0].value, roots[1].value), (roots[1].value, roots[0].value)]
        var results: [Double] = []
        for (ra, rb) in first {
            var filled = e
            filled = filled.replacingOccurrences(of: m[2], with: "(\(constant(m[1], ra)))").replacingOccurrences(of: m[4], with: "(\(constant(m[3], rb)))")
            guard !filled.contains(where: { $0.isLetter }), let v = Expression.evaluate(filled) else { return nil }
            results.append(v)
        }
        var chosen = results[0]
        if abs(results[0] - results[1]) > 1e-9 {
            // "(단, a > b)"처럼 두 상수의 크기가 주어지면 그 순서로
            let order = match(c, "\\(단,?(?:\(m[2])([<>])\(m[4])|\(m[4])([<>])\(m[2]))\\)")
            guard let order else { return nil }
            let aBigger = order[1] == ">" || order[2] == "<"
            let pairs = first.map { (constant(m[1], $0.0), constant(m[3], $0.1)) }
            guard let index = pairs.firstIndex(where: { aBigger ? $0.0 > $0.1 : $0.0 < $0.1 }) else { return nil }
            chosen = results[index]
        }
        results = [chosen]
        guard isNice(chosen), let factored = DoitAlgebra.factor(p) else { return nil }
        return Solved(kind: .factor, topic: "인수분해", concept: "x² + (a + b)x + ab = (x + a)(x + b): 곱해서 상수항, 더해서 x의 계수가 되는 두 수를 찾아요.",
                      steps: [SolutionStep(hint: "인수분해하면", work: factored.text),
                              SolutionStep(hint: "\(e)의 값", work: f(results[0]))],
                      answer: f(results[0]))
    }

    /// "√72를 a√b 꼴로 나타내시오" → 6√2, "… a√b 꼴로 나타낼 때 a + b의 값" → 8
    private static func surdForm(_ t: String) -> Solved? {
        let c = t.replacingOccurrences(of: " ", with: "")
        guard c.contains("a√b"), let m = match(c, #"^(.*?)(?:을|를)a√b"#) else { return nil }
        let expression = m[1].replacingOccurrences(of: #"^[^0-9√(]*"#, with: "", options: .regularExpression)
        guard expression.contains("√"), !expression.contains(where: { $0.isLetter }), let inner = MathSolver.solve(expression + "의 값은?") else { return nil }
        let value = inner.answer.replacingOccurrences(of: #"\s*\(≈[^)]*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        guard let parts = match(value.replacingOccurrences(of: " ", with: ""), #"^(\d*)√(\d+)$"#) else { return nil }
        var answer = value
        let a = Double(parts[1].isEmpty ? "1" : parts[1]) ?? 1, b = Double(parts[2]) ?? 0
        if let e = askedExpression(t), Set(e.filter { $0.isLetter }).isSubset(of: ["a", "b"]), e.contains("a") || e.contains("b") {
            let filled = e.replacingOccurrences(of: "a", with: "(\(a))").replacingOccurrences(of: "b", with: "(\(b))")
            guard let v = Expression.evaluate(filled) else { return nil }
            answer = f(v)
        }
        var steps = inner.steps
        steps.append(SolutionStep(hint: "a√b 꼴 (b는 가장 작은 자연수)", work: "\(value) → a = \(f(a)), b = \(f(b))"))
        return Solved(kind: inner.kind, topic: "근호가 있는 식을 a√b 꼴로", concept: "√(k²b) = k√b: 근호 안의 제곱인 수를 밖으로 꺼내요.", steps: steps, answer: answer)
    }

    // MARK: - 못 풀던 유형

    /// "이차함수 y = x² − 2x + 5의 그래프가 y축과 만나는 점의 y좌표" → f(0)
    private static func yIntercept(_ t: String) -> Solved? {
        guard has(t, ["y축과 만나는", "y축과의 교점", "y축과 만나"]), !has(t, ["넓이", "둘러싸인"]), let p = MathSolver.function(in: t) else { return nil }
        let c = p[0]
        let answer = has(t, ["y좌표"]) || !has(t, ["좌표"]) ? f(c) : "(0, \(f(c)))"
        return Solved(kind: .function, topic: "그래프와 y축의 교점", concept: "y축 위의 점은 x = 0 이에요. x = 0을 넣은 값이 y절편이에요.",
                      steps: [SolutionStep(hint: "x = 0을 넣으면", work: "y = \(f(c))")], answer: answer)
    }

    /// "5명 중에서 회장 1명, 부회장 1명을 뽑는 경우의 수" → ₅P₂ (맡는 일이 다르면 순서가 있는 뽑기)
    private static func roles(_ t: String) -> Solved? {
        guard has(t, ["경우의 수", "방법의 수", "가짓수"]), let m = match(t, #"(\d+)\s*명\s*(?:중에서|중|가운데|에서)"#), let n = Int(m[1]), n <= 30 else { return nil }
        let named = matches(t, #"([가-힣]{1,4})\s*1\s*명"#).map { $0[1] }
        let roles = named.filter { !["중에서", "가운데"].contains($0) }
        guard roles.count >= 2, Set(roles).count == roles.count, roles.count <= n, !has(t, ["대표", "이웃", "일렬", "원형"]) else { return nil }
        // "남학생 3명, 여학생 2명 중에서 남학생 1명, 여학생 1명"은 무리마다 따로 뽑기 (곱의 법칙)
        let groups = matches(t, #"(\d+)\s*명"#).filter { $0[1] != "1" }
        guard groups.count == 1 else { return nil }
        let k = roles.count
        let v = MathTopicsBridge.permutation(n, k)
        return Solved(kind: .counting, topic: "순열 (맡는 일이 다른 대표 뽑기)", concept: "회장·부회장처럼 맡는 일이 다르면 뽑는 순서가 있는 경우라 ₙPᵣ = n × (n − 1) × … 예요.",
                      steps: [SolutionStep(hint: "\(roles.joined(separator: ", "))을(를) 차례로 뽑으면", work: "\(n)P\(k) = " + (0..<k).map { "\(n - $0)" }.joined(separator: " × ") + " = \(DoitMath.format(v))")],
                      answer: DoitMath.format(v))
    }

    /// "1부터 20까지의 자연수 중에서 3의 배수 또는 5의 배수의 개수" → 6 + 4 − 1
    private static func multiplesCount(_ t: String) -> Solved? {
        guard let r = match(t, #"(\d+)\s*부터\s*(\d+)\s*까지"#), let lo = Int(r[1]), let hi = Int(r[2]), lo >= 1, hi >= lo, hi <= 1_000_000,
              let m = match(t, #"(\d+)\s*의\s*배수\s*(또는|이거나|이고|이면서|그리고)\s*(\d+)\s*의\s*배수"#),
              let a = Int(m[1]), let b = Int(m[3]), a >= 1, b >= 1, has(t, ["개수", "몇 개"]), !has(t, ["아닌"]) else { return nil }
        func count(_ k: Int) -> Int { hi / k - (lo - 1) / k }
        let l = a / DoitAlgebra.gcd(a, b) * b
        let both = count(l)
        let union = m[2] == "또는" || m[2] == "이거나"
        let v = union ? count(a) + count(b) - both : both
        return Solved(kind: .counting, topic: "배수의 개수 (합집합·교집합)", concept: "n(A ∪ B) = n(A) + n(B) − n(A ∩ B): 두 수의 공배수는 최소공배수의 배수예요.",
                      steps: [SolutionStep(hint: "\(a)의 배수, \(b)의 배수, \(l)(최소공배수)의 배수", work: "\(count(a))개, \(count(b))개, \(both)개"),
                              SolutionStep(hint: union ? "\(count(a)) + \(count(b)) − \(both)" : "공배수의 개수", work: "\(v)")],
                      answer: "\(v)")
    }

    /// "nC2 = 10을 만족하는 자연수 n" → 5 (nP2도)
    private static func combinationEquation(_ t: String) -> Solved? {
        let subs: [Character: Character] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9", "ₙ": "n"]
        let plain = String(t.map { subs[$0] ?? $0 }).replacingOccurrences(of: " ", with: "")
        guard let m = match(plain, #"(?<![a-z])n([CP])(\d+)=(\d+)(?!\d)"#), let r = Int(m[2]), let v = Double(m[3]), r >= 1, r <= 10, v <= 1e12 else { return nil }
        var found: Int?
        for n in r...2000 {
            let value = m[1] == "C" ? MathTopicsBridge.combination(n, r) : MathTopicsBridge.permutation(n, r)
            if abs(value - v) < 0.5 { found = n; break }
            if value > v { break }
        }
        guard let n = found else { return nil }
        let formula = m[1] == "C" ? "n(n − 1)…/\(r)!" : "n(n − 1)…"
        return Solved(kind: .counting, topic: m[1] == "C" ? "조합의 수로 n 구하기" : "순열의 수로 n 구하기", concept: "ₙPᵣ = n(n − 1)…(n − r + 1), ₙCᵣ = ₙPᵣ / r! 로 식을 세워 n을 찾아요.",
                      steps: [SolutionStep(hint: "n\(m[1])\(r) = \(formula) = \(m[3])", work: "n = \(n)이면 \(n)\(m[1])\(r) = \(m[3])")], answer: "\(n)")
    }

    /// "명중률이 0.8인 선수가 두 번 쏠 때, 두 번 모두 명중할 확률" → 0.64 (적어도 한 번, 한 번도 못)
    private static func repeatedTrials(_ t: String) -> Solved? {
        guard let pm = match(t, "(?:명중률|성공률|확률)(?:이|은|는)\\s*(\(num))"), let p = value(pm[1]), p > 0, p < 1,
              let nm = match(t, #"(한|두|세|네|다섯|\d+)\s*(?:번|회)\s*(?:쏠|던질|시도|던져|쏘|할|반복)"#) else { return nil }
        let words = ["한": 1, "두": 2, "세": 3, "네": 4, "다섯": 5]
        guard let n = words[nm[1]] ?? Int(nm[1]), n >= 1, n <= 10 else { return nil }
        let v: Double, how: String
        if has(t, ["적어도 한 번", "적어도 1번", "적어도 한 발"]) { v = 1 - pow(1 - p, Double(n)); how = "1 − (1 − \(f(p)))^\(n)" }
        else if has(t, ["모두 실패", "한 번도 명중하지", "한 번도 성공하지", "모두 명중하지 못", "모두 빗나"]) { v = pow(1 - p, Double(n)); how = "(1 − \(f(p)))^\(n)" }
        else if has(t, ["모두 명중", "모두 성공", "모두 맞"]) { v = pow(p, Double(n)); how = "\(f(p))^\(n)" }
        else { return nil }
        let text = DoitMath.format((v * 1e9).rounded() / 1e9, digits: 9)
        return Solved(kind: .counting, topic: "독립시행의 확률", concept: "매번 결과가 서로 영향을 주지 않으면(독립) 각 확률을 곱해요. '적어도 한 번'은 1 − (한 번도 안 일어날 확률).",
                      steps: [SolutionStep(hint: "각 시행이 독립이므로", work: "\(how) = \(text)")], answer: text)
    }

    /// "y = 3/x의 그래프를 x축의 방향으로 2만큼, y축의 방향으로 −1만큼 평행이동한 그래프의 점근선" → x = 2, y = −1
    private static func movedReciprocal(_ t: String) -> Solved? {
        guard has(t, ["점근선"]), has(t, ["평행이동"]), let k = match(t, #"y\s*=\s*(-?\d*)\s*/\s*x(?![0-9a-z+\-])"#),
              let mx = match(t, "x축의?\\s*방향으로\\s*(\(num))\\s*만큼"), let dx = value(mx[1]) else { return nil }
        let dy = match(t, "y축의?\\s*방향으로\\s*(\(num))\\s*만큼").flatMap { value($0[1]) } ?? 0
        let kText = k[1].isEmpty ? "1" : k[1]
        return Solved(kind: .function, topic: "유리함수의 평행이동과 점근선", concept: "y = k/x 의 점근선은 x = 0, y = 0. x축으로 m, y축으로 n만큼 옮기면 y = k/(x − m) + n 이고 점근선은 x = m, y = n 이에요.",
                      steps: [SolutionStep(hint: "옮긴 식", work: "y = \(kText)/(x − (\(f(dx)))) + (\(f(dy)))"), SolutionStep(hint: "점근선도 같이 옮겨져요", work: "x = \(f(dx)), y = \(f(dy))")],
                      answer: "점근선 x = \(f(dx)), y = \(f(dy))")
    }

    /// "θ가 제2사분면의 각이고 sin θ = 3/5일 때, cos θ의 값" → −4/5
    private static func trigQuadrant(_ t: String) -> Solved? {
        guard let q = match(t, #"제\s*([1-4])\s*사분면"#), let quadrant = Int(q[1]),
              let given = match(t, "(sin|cos|tan)\\s*θ\\s*=\\s*(\(num))"), let g = value(given[2]),
              let ask = matches(t, #"(sin|cos|tan)\s*θ\s*(?:의\s*값|는|은|를|을)"#).last?[1], ask != given[1] else { return nil }
        let sinSign: Double = quadrant <= 2 ? 1 : -1
        let cosSign: Double = quadrant == 1 || quadrant == 4 ? 1 : -1
        var s2: Double, c2: Double
        switch given[1] {
        case "sin": guard abs(g) <= 1, g * sinSign >= 0 else { return nil }; s2 = g * g; c2 = 1 - s2
        case "cos": guard abs(g) <= 1, g * cosSign >= 0 else { return nil }; c2 = g * g; s2 = 1 - c2
        default: guard g * sinSign * cosSign >= 0 else { return nil }; c2 = 1 / (1 + g * g); s2 = 1 - c2
        }
        func signed(_ square: Double, _ sign: Double) -> String {
            let magnitude = DoitAlgebra.sqrtText(square)
            return sign < 0 && square > 1e-12 ? "-" + magnitude : magnitude
        }
        let answer: String
        switch ask {
        case "sin": answer = signed(s2, sinSign)
        case "cos": answer = signed(c2, cosSign)
        default: guard c2 > 1e-12 else { return nil }; answer = signed(s2 / c2, sinSign * cosSign)
        }
        return Solved(kind: .calc, topic: "삼각함수 사이의 관계", concept: "sin²θ + cos²θ = 1, tan θ = sin θ / cos θ. 부호는 사분면으로 정해요 (제1: 모두 +, 제2: sin +, 제3: tan +, 제4: cos +).",
                      steps: [SolutionStep(hint: "sin²θ + cos²θ = 1", work: "sin²θ = \(f(s2)), cos²θ = \(f(c2))"),
                              SolutionStep(hint: "제\(quadrant)사분면이므로 부호를 정하면", work: "\(ask) θ = \(answer)")],
                      answer: answer)
    }

    /// 상수 하나가 조건 하나로 정해지는 것 (조건이 상수에 대해 일차식일 때만)
    /// "방정식 ax + 3 = 2x − 1의 해가 x = −2일 때 a", "f(x) = x³ + ax² + 3x가 x = 1에서 극값을 가질 때 a"
    private static func constantFromCondition(_ t: String) -> Solved? {
        guard let ask = match(t, #"상수\s*([a-wA-W])\s*의\s*값"#), let letter = ask[1].first else { return nil }
        let others = Set(t.filter { $0.isASCII && $0.isLetter }).subtracting(["x", letter])
        // 다른 문자(함수 이름 f 말고)가 있으면 상수가 여럿
        guard others.isSubset(of: ["f"]) else { return nil }
        func filled(_ expression: String, x: String, k: Double) -> String {
            expression.replacingOccurrences(of: String(letter), with: "(\(k))").replacingOccurrences(of: "x", with: "(\(x))")
        }
        var condition: ((Double) -> Double?)?
        var hint = ""
        if let m = match(t, "방정식\\s*([^가-힣]+?=[^가-힣]+?)\\s*의\\s*(?:해|근)(?:가|이|는|은)\\s*(?:x\\s*=\\s*)?(\(num))\\s*일"), let r = value(m[2]) {
            let sides = m[1].split(separator: "=").map(String.init)
            guard sides.count == 2, m[1].contains(letter) else { return nil }
            condition = { k in
                guard let l = Expression.evaluate(filled(sides[0], x: "\(r)", k: k)), let rv = Expression.evaluate(filled(sides[1], x: "\(r)", k: k)) else { return nil }
                return l - rv
            }
            hint = "x = \(f(r))을 방정식에 넣으면"
        } else if let m = match(t, "x\\s*=\\s*(\(num))\\s*에서\\s*극(?:값|댓값|솟값)을\\s*(?:가질|갖|가지)"), let p = value(m[1]),
                  !has(t, ["극댓값이", "극솟값이", "극댓값은", "극솟값은"]),
                  let fm = match(t, #"(?:f\(x\)|y)\s*=\s*([^가-힣,]+?)\s*(?:이|가|의|은|는)?\s*x\s*="#) {
            let expression = fm[1]
            guard expression.contains(letter) else { return nil }
            // 다섯 점 차분: 4차 이하 다항식이면 미분계수가 정확히 나와요
            condition = { k in
                let h = 0.01
                guard let a = Expression.evaluate(filled(expression, x: "\(p + 2 * h)", k: k)), let b = Expression.evaluate(filled(expression, x: "\(p + h)", k: k)),
                      let c = Expression.evaluate(filled(expression, x: "\(p - h)", k: k)), let d = Expression.evaluate(filled(expression, x: "\(p - 2 * h)", k: k)) else { return nil }
                return (-a + 8 * b - 8 * c + d) / (12 * h)
            }
            hint = "극값을 가지는 x에서 f'(x) = 0 이므로 f'(\(f(p))) = 0"
        }
        guard let g = condition, let g0 = g(0), let g1 = g(1), let g2 = g(2), let g3 = g(-3) else { return nil }
        let slope = g1 - g0
        // 일차식인지 확인 (상수에 대해 이차 이상이면 다른 풀이로)
        guard abs(slope) > 1e-9, abs((g2 - g1) - slope) < 1e-6 * max(1, abs(slope)), abs((g0 - g3) - 3 * slope) < 1e-5 * max(1, abs(slope)) else { return nil }
        let k = -g0 / slope
        // 계산 오차를 지우려고 가까운 간단한 분수로 맞춘 뒤 다시 넣어 확인
        var rounded = k
        for d in 1...100 where abs(k * Double(d) - (k * Double(d)).rounded()) < 1e-6 { rounded = (k * Double(d)).rounded() / Double(d); break }
        guard isNice(rounded), let check = g(rounded), abs(check) < 1e-6 * max(1, abs(slope)) else { return nil }
        return Solved(kind: .expression, topic: "조건으로 상수 구하기", concept: "주어진 조건을 식에 넣으면 상수에 대한 방정식이 돼요.",
                      steps: [SolutionStep(hint: hint, work: "\(letter)에 대한 일차방정식"), SolutionStep(hint: "풀면", work: "\(letter) = \(f(rounded))")],
                      answer: f(rounded))
    }

    /// "곡선 y = x²과 직선 y = x로 둘러싸인 부분의 넓이" → ∫|f − g|
    private static func areaBetween(_ t: String) -> Solved? {
        guard has(t, ["둘러싸인"]), has(t, ["넓이"]), !has(t, ["x축", "y축"]) else { return nil }
        let defs = matches(t, #"y\s*=\s*([0-9x+\-*/^(). ]+?)\s*(?:과|와|및|으로|로|,|$)"#)
        guard defs.count == 2, let p = DoitMath.polynomial(defs[0][1].trimmingCharacters(in: .whitespaces)),
              let q = DoitMath.polynomial(defs[1][1].trimmingCharacters(in: .whitespaces)) else { return nil }
        let d = p - q
        guard d.degree >= 2 else { return nil }
        let roots = DoitAlgebra.realRoots(d).map(\.value).sorted()
        guard roots.count >= 2 else { return nil }
        var anti = DoitMath.Poly()
        for i in 0..<(DoitMath.Poly.size - 1) { anti.c[i + 1] = d[i] / Double(i + 1) }
        guard abs(d[DoitMath.Poly.size - 1]) < 1e-12 else { return nil }
        var area = 0.0
        for k in 0..<(roots.count - 1) { area += abs(DoitMath.value(anti, at: roots[k + 1]) - DoitMath.value(anti, at: roots[k])) }
        guard isNice(area) else { return nil }
        return Solved(kind: .integral, topic: "두 그래프로 둘러싸인 넓이", concept: "두 그래프의 교점을 구하고, 그 사이에서 ∫|f(x) − g(x)| dx 를 계산해요.",
                      steps: [SolutionStep(hint: "교점의 x좌표: f(x) − g(x) = 0", work: "\(DoitMath.describe(d)) = 0 → x = " + roots.map { f($0) }.joined(separator: ", ")),
                              SolutionStep(hint: "∫|f(x) − g(x)| dx", work: f(area))],
                      answer: f(area))
    }

    /// "갈 때는 시속 4km, 올 때는 시속 6km로 … 모두 5시간" → 거리 d: d/4 + d/6 = 5
    private static func roundTrip(_ t: String) -> Solved? {
        guard let m = match(t, "갈\\s*때(?:는|에는)?\\s*시속\\s*(\(num))\\s*km.*?올\\s*때(?:는|에는)?\\s*시속\\s*(\(num))\\s*km"),
              let a = value(m[1]), let b = value(m[2]), a > 0, b > 0,
              let tm = match(t, "(?:모두|총|왕복)\\s*(\(num))\\s*시간"), let total = value(tm[1]), has(t, ["거리"]) else { return nil }
        let d = total / (1 / a + 1 / b)
        guard isNice(d) else { return nil }
        return Solved(kind: .linear, topic: "거리·속력·시간 (왕복)", concept: "시간 = 거리 ÷ 속력. 갈 때 걸린 시간 + 올 때 걸린 시간 = 전체 시간으로 식을 세워요.",
                      steps: [SolutionStep(hint: "거리를 x km라 하면", work: "x/\(f(a)) + x/\(f(b)) = \(f(total))"), SolutionStep(hint: "풀면", work: "x = \(f(d))")],
                      answer: "\(f(d))km")
    }

    /// "순환소수 0.444…를 기약분수로" → 4/9, 0.1666… → 1/6, 0.3232… → 32/99
    private static func repeatingDecimal(_ t: String) -> Solved? {
        guard has(t, ["순환소수"]) || t.contains("…") || t.contains("..."),
              let m = match(t, #"(\d+)\.(\d+)\s*(?:…|\.\.\.|⋯)"#) ?? (has(t, ["순환소수"]) ? match(t, #"(\d+)\.(\d{3,})"#) : nil),
              m[1].count <= 6, m[2].count <= 12 else { return nil }
        let digits = Array(m[2])
        // 끝까지 되풀이되는 마디 찾기 (마디가 두 번 이상 보여야 함): 앞자리 수 + 마디 길이가 짧은 것
        var best: (pre: Int, period: Int)?
        search: for total in 1...digits.count {
            for period in 1...total {
                let pre = total - period
                let tail = Array(digits[pre...])
                guard tail.count >= period * 2 else { continue }
                if tail.indices.allSatisfy({ tail[$0] == tail[$0 % period] }) { best = (pre, period); break search }
            }
        }
        guard let (pre, period) = best, let whole = Int(m[1]) else { return nil }
        let preDigits = String(digits[..<pre]), block = String(digits[pre..<(pre + period)])
        guard let a = Int(preDigits + block), let b = preDigits.isEmpty ? 0 : Int(preDigits) else { return nil }
        let numerator = a - b
        var denominator = 0
        for _ in 0..<period { denominator = denominator * 10 + 9 }
        for _ in 0..<pre { denominator *= 10 }
        let top = numerator + whole * denominator
        let g = DoitAlgebra.gcd(top, denominator)
        let answer = "\(top / g)/\(denominator / g)"
        return Solved(kind: .calc, topic: "순환소수를 분수로", concept: "순환소수 = (전체 수 − 순환하지 않는 부분) / (순환마디 자리 수만큼 9, 그 뒤에 순환하지 않는 소수 자리 수만큼 0)",
                      steps: [SolutionStep(hint: "순환마디", work: block), SolutionStep(hint: "분수로 바꾸면", work: "\(top)/\(denominator) = \(answer)")],
                      answer: denominator / g == 1 ? "\(top / g)" : answer)
    }
}

/// 순열·조합 계산 (DoitMathTopics 것을 그대로)
private enum MathTopicsBridge {
    static func permutation(_ n: Int, _ r: Int) -> Double { DoitMathTopics.permutation(n, r) }
    static func combination(_ n: Int, _ r: Int) -> Double { DoitMathTopics.combination(n, r) }
}
