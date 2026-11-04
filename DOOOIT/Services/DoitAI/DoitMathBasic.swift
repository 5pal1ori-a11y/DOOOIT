import Foundation

/// 모티 AI 수학 풀이: 초등 · 중학교 · 공통수학에서 자주 나오는 모양 (외부 AI 없이 직접 계산)
/// - early: 다른 풀이가 틀리게 읽던 모양 (어떤 수, 해가 주어진 방정식의 상수, 정비례·반비례, 함숫값, 소금물, 뽑기·줄 세우기,
///   √(ax)가 자연수, 꼭짓점·세 점으로 이차함수, 직각삼각형·세 변의 넓이, 조건이 있는 부분집합, 여집합의 원소 개수,
///   로그·지수 부등식, 거듭제곱으로 쓴 수의 최대공약수·최소공배수)
/// - late: 다른 풀이가 모두 못 푼 것만 (비율, 축척, 각의 크기, 문장제, 일차함수, 판별식, 원, 대칭이동 …)
/// 모두 정확한 분수로 계산하고, 조건이 모자라거나 애매하면 nil
enum DoitMathBasic {
    typealias Solved = MathSolver.Solved
    typealias Rat = DoitMathExact.Rat

    static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }
    static func match(_ t: String, _ p: String) -> [String]? { DoitMathExact.match(t, p) }
    static func matches(_ t: String, _ p: String) -> [[String]] { DoitMathExact.matches(t, p) }
    static func step(_ h: String, _ w: String) -> SolutionStep { SolutionStep(hint: h, work: w) }
    /// 수 (정수 · 소수 · 분수)
    static let num = #"-?\d+(?:\.\d+)?(?:/\d+)?"#

    // MARK: - 도우미

    /// "3/4", "-2", "0.5", "(-3)" → 유리수
    static func rat(_ s: String) -> Rat? {
        var t = s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "−", with: "-")
        while t.hasPrefix("("), t.hasSuffix(")") { t = String(t.dropFirst().dropLast()) }
        let negative = t.hasPrefix("-")
        let body = negative ? String(t.dropFirst()) : t
        guard !body.isEmpty, body.allSatisfy({ $0.isNumber || $0 == "." || $0 == "/" }) else { return nil }
        let parts = body.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        var r: Rat?
        if parts.count == 1 { r = Rat.parse(parts[0]) }
        else if parts.count == 2, let a = Rat.parse(parts[0]), let b = Rat.parse(parts[1]) { r = a / b }
        guard let v = r else { return nil }
        return negative ? -v : v
    }

    /// 식의 값 (변수 v에 value를 넣어서, 정확한 분수로)
    static func eval(_ s: String, _ v: Character = "x", _ value: Rat? = nil) -> Rat? {
        guard let node = DoitMathCalc.parse(s, variable: v) else { return nil }
        if value == nil, node.hasVariable { return nil }
        return DoitMathCalc.evalRat(node, value)
    }

    /// 식의 문자 v 자리에 값을 넣은 글 (곱하기 기호를 붙여서)
    static func put(_ expr: String, _ v: Character, _ value: Rat) -> String {
        var out = ""
        let chars = Array(expr)
        let shown = "(" + value.text.replacingOccurrences(of: "−", with: "-") + ")"
        for (i, c) in chars.enumerated() {
            if c == v {
                if let p = out.last, p.isNumber || p.isLetter || p == ")" { out += "*" }
                out += shown
                if i + 1 < chars.count, chars[i + 1].isLetter || chars[i + 1].isNumber || chars[i + 1] == "(" { out += "*" }
            } else {
                out.append(c)
            }
        }
        return out
    }

    /// f(c) = 0 인 c (f가 일차식일 때만, 정확히 확인)
    static func linearRoot(_ f: (Rat) -> Rat?) -> Rat? {
        guard let f0 = f(.zero), let f1 = f(.one), let two = Rat(2), let f2 = f(two),
              let d1 = f1 - f0, let d2 = f2 - f1, d1 == d2, !d1.isZero, let r = (-f0) / d1, let check = f(r), check.isZero else { return nil }
        return r
    }

    /// 수 보여 주기 (분수, 음수는 −)
    static func show(_ r: Rat) -> String { r.text }

    static let koreanCounts: [String: Int] = ["한": 1, "두": 2, "세": 3, "네": 4, "다섯": 5, "여섯": 6, "일곱": 7, "여덟": 8, "아홉": 9, "열": 10]
    static func count(_ s: String) -> Int? { Int(s) ?? koreanCounts[s.trimmingCharacters(in: .whitespaces)] }

    /// 글에 든 수의 개수 (분수는 하나로)
    static func numberCount(_ t: String) -> Int { matches(t, #"(?<![\d.])\d+(?:\.\d+)?(?:/\d+)?"#).count }

    static func factorial(_ n: Int) -> Int? {
        guard n >= 0, n <= 20 else { return nil }
        return n <= 1 ? 1 : (2...n).reduce(1, *)
    }

    static func choose(_ n: Int, _ r: Int) -> Int? {
        guard n >= 0, r >= 0, r <= n, n <= 60 else { return nil }
        var out = 1
        for i in 0..<r {
            guard let m = DoitMathExact.mul(out, n - i) else { return nil }
            out = m / (i + 1)
        }
        return out
    }

    // MARK: - 다른 풀이보다 먼저 (다른 풀이가 틀리게 읽던 모양)

    static func early(_ t: String) -> Solved? {
        if let s = someNumber(t) { return s }
        if let s = constantFromSolution(t) { return s }
        if let s = proportional(t) { return s }
        if let s = evaluateAt(t) { return s }
        if let s = functionValues(t) { return s }
        if let s = saltWater(t) { return s }
        if let s = chooseOrLine(t) { return s }
        if let s = sqrtNatural(t) { return s }
        if let s = rootOfRoot(t) { return s }
        if let s = quadraticThrough(t) { return s }
        if let s = triangleArea(t) { return s }
        if let s = constrainedSubsets(t) { return s }
        if let s = complementCount(t) { return s }
        if let s = logInequality(t) { return s }
        if let s = expInequality(t) { return s }
        if let s = factoredGcd(t) { return s }
        if let s = discriminantCondition(t) { return s }
        if let s = axisTriangle(t) { return s }
        if let s = ages(t) { return s }
        if let s = lawOfCosines(t) { return s }
        if let s = linearity(t) { return s }
        if let s = inverseValue(t) { return s }
        return nil
    }

    // MARK: 어떤 수에 a를 곱했더니 b

    static func someNumber(_ t: String) -> Solved? {
        // "어떤 수에 3을 곱했더니 처음 수보다 10만큼 커졌다": (a − 1)x = b
        if t.contains("어떤 수"), !has(t, ["잘못", "바르게", "나머지"]), numberCount(t) == 2,
           let m = match(t, #"어떤\s*수에\s*("# + num + #")\s*(?:을|를)\s*곱(?:했더니|하였더니|하면)\s*(?:처음\s*수|어떤\s*수|처음의\s*수)보다\s*("# + num + #")\s*만큼\s*(커|작아)"#),
           let a = rat(m[1]), let b0 = rat(m[2]), let a1 = a - .one, !a1.isZero {
            let b = m[3] == "커" ? b0 : -b0
            guard let x = b / a1 else { return nil }
            return Solved(kind: .linear, topic: "어떤 수 구하기", concept: "어떤 수를 x로 놓고 문장을 식으로 옮겨요.",
                          steps: [step("어떤 수를 x라 하면", "\(show(a))x = x \(b.n >= 0 ? "+" : "−") \(show(b0))"), step("풀면", "x = \(show(x))")], answer: show(x))
        }
        guard t.contains("어떤 수"), !has(t, ["잘못", "바르게", "나머지", "배", "보다", "몫"]), numberCount(t) == 2 else { return nil }
        guard t.range(of: #"어떤\s*수(?:는|를\s*구|의\s*값|를\s*쓰|은|를\s*찾)"#, options: .regularExpression) != nil else { return nil }
        let n = "(" + num + ")"
        let after = #"\s*(?:이|가)?\s*(?:되었|됩니다|되었습니다|된다|됐|나왔|입니다|이다|였)"#
        let rules: [(String, String, (Rat, Rat) -> Rat?)] = [
            (#"어떤\s*수에\s*"# + n + #"\s*(?:을|를)\s*곱(?:했더니|하였더니|하면|한\s*값은|한\s*수는)\s*"# + n + after, "× ", { a, b in b / a }),
            (#"어떤\s*수에\s*"# + n + #"\s*(?:을|를)\s*더(?:했더니|하였더니|하면|한\s*값은|한\s*수는)\s*"# + n + after, "+ ", { a, b in b - a }),
            (#"어떤\s*수에서\s*"# + n + #"\s*(?:을|를)\s*(?:뺐더니|빼었더니|빼면|뺀\s*값은|뺀\s*수는)\s*"# + n + after, "− ", { a, b in b + a }),
            (#"어떤\s*수를\s*"# + n + #"\s*(?:으로|로)\s*(?:나누었더니|나눴더니|나누면|나눈\s*값은|나눈\s*수는)\s*"# + n + after, "÷ ", { a, b in b * a }),
        ]
        for (pattern, op, inverse) in rules {
            guard let m = match(t, pattern), let a = rat(m[1]), let b = rat(m[2]) else { continue }
            if op.hasPrefix("×") || op.hasPrefix("÷"), a.isZero { return nil }
            guard let x = inverse(a, b) else { return nil }
            return Solved(kind: .linear, topic: "어떤 수 구하기", concept: "어떤 수를 □로 놓고 식을 세운 뒤, 거꾸로 계산해요.",
                          steps: [step("어떤 수를 □라 하면", "□ \(op)\(show(a)) = \(show(b))"), step("거꾸로 계산하면", "□ = \(show(x))")], answer: show(x))
        }
        return nil
    }

    // MARK: x = 2가 방정식 ax − 3 = 5의 해일 때 a

    static func constantFromSolution(_ t: String) -> Solved? {
        guard has(t, ["해", "근"]), !has(t, ["다른 한 근", "다른 근", "나머지 근", "나머지 한 근", "와 b", "과 b", "a, b", "a와", "a + b"]),
              let asked = match(t, #"(?<![a-z])([a-wz])\s*의\s*값"#)?[1].first else { return nil }
        let given = #"([xy])\s*=\s*("# + num + #")\s*(?:,\s*([xy])\s*=\s*("# + num + #"))?"#
        var eq: String?
        var values: [(Character, Rat)] = []
        if let m = match(t, given + #"\s*(?:이|가|을|를)\s*(?:연립)?(?:일차|이차)?\s*방정식\s*([^가-힣]+?)\s*의\s*(?:한\s*)?(?:해|근)"#) {
            eq = m[5]
            if let v = m[1].first, let r = rat(m[2]) { values.append((v, r)) }
            if let v = m[3].first, let r = rat(m[4]) { values.append((v, r)) }
        } else if let m = match(t, #"(?:일차|이차)?\s*방정식\s*([^가-힣]+?)\s*의\s*(?:한\s*)?(?:해|근)(?:이|가|은|는)\s*"# + given + #"\s*(?:일\s*때|이면|이다|이고)"#) {
            eq = m[1]
            if let v = m[2].first, let r = rat(m[3]) { values.append((v, r)) }
            if let v = m[4].first, let r = rat(m[5]) { values.append((v, r)) }
        }
        guard var e = eq?.trimmingCharacters(in: .whitespaces), !values.isEmpty else { return nil }
        let sides = e.split(separator: "=", omittingEmptySubsequences: false)
        guard sides.count == 2, Set(values.map(\.0)).count == values.count else { return nil }
        for (v, r) in values { e = put(e, v, r) }
        // 남은 문자는 묻는 상수 하나뿐이어야 함
        let letters = Set(e.filter { $0.isLetter && $0.isASCII })
        guard letters == [asked] else { return nil }
        let parts = e.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard let root = linearRoot({ c in
            guard let l = eval(parts[0], asked, c), let r = eval(parts[1], asked, c) else { return nil }
            return l - r
        }) else { return nil }
        let given1 = values.map { "\($0.0) = \(show($0.1))" }.joined(separator: ", ")
        return Solved(kind: .linear, topic: "해가 주어진 방정식의 상수", concept: "해를 방정식에 넣으면 등식이 참이 돼요. 넣은 식을 상수에 대한 방정식으로 풀어요.",
                      steps: [step("\(given1)을 넣으면", e.replacingOccurrences(of: "*", with: "×")), step("\(asked)에 대한 방정식을 풀면", "\(asked) = \(show(root))")], answer: show(root))
    }

    // MARK: 코사인법칙 (세 변 → cos)

    static func lawOfCosines(_ t: String) -> Solved? {
        guard let m = match(t, #"(?:삼각형|△)\s*ABC\s*에서\s*a\s*=\s*("# + num + #")\s*,\s*b\s*=\s*("# + num + #")\s*,\s*c\s*=\s*("# + num + #")\s*일\s*때\s*,?\s*cos\s*([ABC])\s*의\s*값"#),
              let a = rat(m[1]), let b = rat(m[2]), let c = rat(m[3]), a.n > 0, b.n > 0, c.n > 0 else { return nil }
        let sides = [a, b, c].sorted { $0.value < $1.value }
        guard let s2 = sides[0] + sides[1], s2.value > sides[2].value else { return nil }
        let (x, y, z): (Rat, Rat, Rat) = m[4] == "A" ? (a, b, c) : m[4] == "B" ? (b, c, a) : (c, a, b)
        guard let y2 = y * y, let z2 = z * z, let x2 = x * x, let s = y2 + z2, let n = s - x2, let yz = y * z, let d = yz * Rat(2)!, let r = n / d else { return nil }
        let name = m[4].lowercased()
        return Solved(kind: .geometry, topic: "코사인법칙", concept: "a² = b² + c² − 2bc cos A 이므로 cos A = (b² + c² − a²)/(2bc)",
                      steps: [step("cos \(m[4]) = (두 변의 제곱의 합 − \(name)²)/(2 × 두 변의 곱)", "(\(show(y2)) + \(show(z2)) − \(show(x2)))/(2 × \(show(y)) × \(show(z))) = \(show(r))")], answer: show(r))
    }

    // MARK: 정적분 · 극한의 성질 (∫ f = 3 일 때 ∫ 2f, lim f = 3 일 때 lim (2f + 1))

    static func linearity(_ t: String) -> Solved? {
        let s = DoitMathCalc.prepare(t)
        // 정적분: "∫₀¹ f(x) dx = 3 일 때, ∫₀¹ 2f(x) dx"
        let pieces = t.components(separatedBy: "일 때")
        if pieces.count == 2, let first = DoitMathHigh.integralParts(pieces[0]), let second = DoitMathHigh.integralParts(pieces[1]),
           first.lo == second.lo, first.hi == second.hi, first.body.replacingOccurrences(of: " ", with: "") == "f(x)",
           let given = match(pieces[0], #"d\s*x\s*=\s*("# + num + #")\s*$"#).flatMap({ rat($0[1]) }) ?? match(pieces[0].trimmingCharacters(in: .whitespaces), #"=\s*("# + num + #")$"#).flatMap({ rat($0[1]) }),
           pieces[1].range(of: #"d\s*x\s*의\s*값"#, options: .regularExpression) != nil,
           let m = match(second.body.replacingOccurrences(of: " ", with: ""), #"^\(?(-?\d*(?:/\d+)?)\*?f\(x\)([+-]\d+(?:/\d+)?)?\)?$"#),
           let lo = DoitMathCalc.rat(first.lo), let hi = DoitMathCalc.rat(first.hi) {
            let k: Rat = m[1].isEmpty ? .one : m[1] == "-" ? -Rat.one : (rat(m[1]) ?? .one)
            let add = m[2].isEmpty ? Rat.zero : rat(m[2].replacingOccurrences(of: "+", with: "")) ?? .zero
            guard let kc = k * given, let w = hi - lo, let aw = add * w, let r = kc + aw else { return nil }
            return Solved(kind: .integral, topic: "정적분의 성질", concept: "∫(kf(x) + m)dx = k∫f(x)dx + m(b − a)",
                          steps: [step("성질로 나누면", "\(show(k)) × \(show(given))\(add.isZero ? "" : " + \(show(add)) × \(show(w))") = \(show(r))")], answer: show(r))
        }
        // 극한
        if let m = match(s, #"lim_?\(?x→(-?\d+|∞)\)?f\(x\)=(-?\d+(?:/\d+)?)일때,?lim_?\(?x→(-?\d+|∞)\)?\(?(-?\d*(?:/\d+)?)\*?f\(x\)([+-]\d+(?:/\d+)?)?\)?의값"#),
           m[1] == m[3], let c = rat(m[2]) {
            let k: Rat = m[4].isEmpty ? .one : m[4] == "-" ? -Rat.one : (rat(m[4]) ?? .one)
            let add = m[5].isEmpty ? Rat.zero : rat(m[5].replacingOccurrences(of: "+", with: "")) ?? .zero
            guard let kc = k * c, let r = kc + add else { return nil }
            return Solved(kind: .derivative, topic: "극한의 성질", concept: "lim (kf(x) + m) = k lim f(x) + m (극한값이 있을 때)",
                          steps: [step("성질로 나누면", "\(show(k)) × \(show(c)) + \(show(add)) = \(show(r))")], answer: show(r))
        }
        return nil
    }

    // MARK: 역함수의 값 (f(x) = 3x + 6 의 역함수 g에 대하여 g(3))

    static func inverseValue(_ t: String) -> Solved? {
        guard let m = match(t, #"f\(x\)\s*=\s*([0-9x+\-*/().\s]+?)\s*의\s*역함수를\s*g\(x\)\s*(?:라|이라)\s*할\s*때\s*,?\s*g\(\s*("# + num + #")\s*\)\s*의\s*값"#)
                ?? match(t, #"f\(x\)\s*=\s*([0-9x+\-*/().\s]+?)\s*(?:에\s*대하여|일\s*때)\s*,?\s*f\^\(?-1\)?\(\s*("# + num + #")\s*\)\s*의\s*값"#),
              let k = rat(m[2]), let (p, q) = linearParts(m[1]), let d = k - q, let x = d / p else { return nil }
        return Solved(kind: .function, topic: "역함수", concept: "g(k) = a 이면 f(a) = k: f(x) = k 를 풀어요.",
                      steps: [step("f(x) = \(show(k))", "\(m[1].trimmingCharacters(in: .whitespaces)) = \(show(k)) → x = \(show(x))")], answer: show(x))
    }

    // MARK: 나이 (현재 A의 나이는 B의 나이의 3배, 10년 후에는 2배)

    static func ages(_ t: String) -> Solved? {
        guard let m = match(t, #"([가-힣]+?)의\s*나이(?:는|가)\s*([가-힣]+?)의\s*나이의\s*(\d+)\s*배(?:이고|이며|이다|인데)\s*,?\s*(\d+)\s*년\s*(후|뒤|전)에는\s*(?:[가-힣]+?의\s*나이(?:가|는)\s*[가-힣]+?의\s*나이의\s*)?(\d+)\s*배"#),
              let k = Int(m[3]), let n = Int(m[4]), let r = Int(m[6]), k != r,
              let ask = matches(t, #"([가-힣]+?)의\s*나이(?:는|를)\s*(?:몇|구|\?|얼마)"#).last?[1] else { return nil }
        let a = m[1].replacingOccurrences(of: "현재", with: "").trimmingCharacters(in: .whitespaces), b = m[2]
        let askName = ask.replacingOccurrences(of: "현재", with: "").trimmingCharacters(in: .whitespaces)
        // A = kB, (kB ± n) = r(B ± n)
        let sign = m[5] == "전" ? -1 : 1
        let numer = sign * n * (r - 1), denom = k - r
        guard denom != 0, numer % denom == 0 else { return nil }
        let young = numer / denom
        guard young > 0, young + sign * n > 0 else { return nil }
        let old = k * young
        let value: Int
        if askName.hasSuffix(b) || b.hasSuffix(askName) { value = young } else if askName.hasSuffix(a) || a.hasSuffix(askName) { value = old } else { return nil }
        return Solved(kind: .linear, topic: "나이 문제", concept: "현재 나이를 x로 놓고, n년 후에는 두 사람 모두 n살씩 많아져요.",
                      steps: [step("\(b)의 나이를 x라 하면", "\(a): \(k)x"), step("\(n)년 \(m[5])", "\(k)x \(sign > 0 ? "+" : "−") \(n) = \(r)(x \(sign > 0 ? "+" : "−") \(n))"), step("풀면", "x = \(young), \(a) \(old)")], answer: "\(value)")
    }

    // MARK: 정비례 · 반비례

    static func proportional(_ t: String) -> Solved? {
        let direct = t.contains("정비례"), inverse = t.contains("반비례")
        guard direct != inverse else { return nil }
        var a: Rat?
        var steps: [SolutionStep] = []
        if let m = match(t, #"x\s*=\s*("# + num + #")\s*일\s*때\s*,?\s*y\s*=\s*("# + num + #")\s*(?:이다|이고|이며|일\s*때|이면|입니다)"#), let p = rat(m[1]), let q = rat(m[2]) {
            a = direct ? (p.isZero ? nil : q / p) : p * q
            steps.append(step(direct ? "y = ax 에 넣으면" : "y = a/x 에 넣으면", direct ? "\(show(q)) = a × \(show(p))" : "\(show(q)) = a/\(show(p))"))
        } else if let m = match(t, #"y\s*=\s*a\s*(x|/\s*x)\s*의?\s*그래프가\s*점\s*\(\s*("# + num + #")\s*,\s*("# + num + #")\s*\)\s*(?:을|를)\s*지날"#),
                  let p = rat(m[2]), let q = rat(m[3]) {
            guard (m[1] == "x") == direct else { return nil }
            a = direct ? (p.isZero ? nil : q / p) : p * q
            steps.append(step("점의 좌표를 넣으면", direct ? "\(show(q)) = a × \(show(p))" : "\(show(q)) = a/\(show(p))"))
        }
        guard let k = a, !k.isZero else { return nil }
        steps.append(step("상수", "a = \(show(k))"))
        let formula = direct ? "y = \(k == .one ? "" : k == -Rat.one ? "−" : (k.isInteger ? show(k) : "(\(show(k)))"))x" : "y = \(show(k))/x"
        let concept = direct ? "y가 x에 정비례하면 y = ax (a ≠ 0)" : "y가 x에 반비례하면 y = a/x (a ≠ 0), xy = a 로 일정"
        let rest = t
        if let m = match(rest, #"x\s*=\s*("# + num + #")\s*일\s*때\s*,?\s*y\s*의\s*값"#), let x = rat(m[1]) {
            guard let y = direct ? k * x : (x.isZero ? nil : k / x) else { return nil }
            steps.append(step("x = \(show(x))를 넣으면", "y = \(show(y))"))
            return Solved(kind: .function, topic: direct ? "정비례" : "반비례", concept: concept, steps: steps, answer: show(y))
        }
        if let m = match(rest, #"y\s*=\s*("# + num + #")\s*일\s*때\s*,?\s*x\s*의\s*값"#), let y = rat(m[1]) {
            guard let x = direct ? y / k : (y.isZero ? nil : k / y) else { return nil }
            steps.append(step("y = \(show(y))를 넣으면", "x = \(show(x))"))
            return Solved(kind: .function, topic: direct ? "정비례" : "반비례", concept: concept, steps: steps, answer: show(x))
        }
        if t.range(of: #"(?<![a-z])a\s*의\s*값"#, options: .regularExpression) != nil {
            return Solved(kind: .function, topic: direct ? "정비례" : "반비례", concept: concept, steps: steps, answer: show(k))
        }
        if has(t, ["식으로 나타내", "관계식", "식을 구", "식은"]) {
            return Solved(kind: .function, topic: direct ? "정비례" : "반비례", concept: concept, steps: steps, answer: formula)
        }
        return nil
    }

    // MARK: y = (식)에서 x = 3일 때 y의 값 · 증가량

    static func evaluateAt(_ t: String) -> Solved? {
        let fn = #"y\s*=\s*([0-9x+\-*/^().\s]+?)\s*(?:에서|에\s*대하여|의\s*그래프에서)\s*,?\s*"#
        if let m = match(t, fn + #"x\s*=\s*("# + num + #")\s*일\s*때\s*,?\s*y\s*의\s*값"#), let x = rat(m[2]), m[1].contains("x"), let y = eval(m[1], "x", x) {
            return Solved(kind: .function, topic: "함숫값", concept: "x의 값을 식에 넣어 y의 값을 구해요.",
                          steps: [step("x = \(show(x))를 넣으면", "y = \(show(y))")], answer: show(y))
        }
        if let m = match(t, fn + #"y\s*=\s*("# + num + #")\s*일\s*때\s*,?\s*x\s*의\s*값"#), let y = rat(m[2]), m[1].contains("x"),
           let x = linearRoot({ v in eval(m[1], "x", v).flatMap { $0 - y } }) {
            return Solved(kind: .function, topic: "함숫값", concept: "y의 값을 넣고 x에 대한 방정식을 풀어요.",
                          steps: [step("y = \(show(y))를 넣으면", "\(m[1].trimmingCharacters(in: .whitespaces)) = \(show(y))"), step("풀면", "x = \(show(x))")], answer: show(x))
        }
        if let m = match(t, fn + #"x\s*의\s*값이\s*("# + num + #")\s*만큼\s*증가할\s*때\s*,?\s*y\s*의\s*값의\s*증가량"#), let k = rat(m[2]),
           let f0 = eval(m[1], "x", .zero), let f1 = eval(m[1], "x", .one), let two = Rat(2), let f2 = eval(m[1], "x", two),
           let s = f1 - f0, let s2 = f2 - f1, s == s2, let d = s * k {
            return Solved(kind: .function, topic: "일차함수의 증가량", concept: "일차함수 y = ax + b에서 (y의 값의 증가량) = a × (x의 값의 증가량)",
                          steps: [step("기울기", "a = \(show(s))"), step("증가량", "\(show(s)) × \(show(k)) = \(show(d))")], answer: show(d))
        }
        return nil
    }

    // MARK: f(x) = (식)에 대하여 f(2) − f(−1), f(2) = 4일 때 f(−1)

    static func functionValues(_ t: String) -> Solved? {
        guard !has(t, ["…", "⋯", "...", "∑", "f'", "f′", "∫", "lim", "역함수", "f^-1", "f⁻¹", "∘", "g(", "h(", "{", "≤", "≥", "<", ">", "|", "정의역", "치역", "모든 실수", "f(x+", "f(x-", "f(2x", "그래프"]) else { return nil }
        guard let d = match(t, #"f\(x\)\s*=\s*([0-9a-z+\-*/^().√\s]+?)\s*(?:에\s*대하여|일\s*때|이고|,|이라|라\s*할)"#) else { return nil }
        let definition = d[1].trimmingCharacters(in: .whitespaces)
        guard definition.contains("x") else { return nil }
        let constants = Set(definition.filter { $0.isLetter && $0.isASCII && $0 != "x" })
        guard constants.count <= 1 else { return nil }
        // 조건 f(2) = 4
        var conditions: [(Rat, Rat)] = []
        var rest = t
        if let r = t.range(of: d[0]) { rest = String(t[r.upperBound...]) }
        for c in matches(rest, #"f\(\s*("# + num + #")\s*\)\s*=\s*("# + num + #")\s*(?:일\s*때|이고|이면|,|을|를)"#) {
            guard let p = rat(c[1]), let q = rat(c[2]) else { return nil }
            conditions.append((p, q))
            rest = rest.replacingOccurrences(of: c[0], with: " ")
        }
        var body = definition
        var steps: [SolutionStep] = []
        if let c = constants.first {
            guard conditions.count == 1, let (p, q) = conditions.first else { return nil }
            let withX = put(definition, "x", p)
            guard let value = linearRoot({ v in eval(withX, c, v).flatMap { $0 - q } }) else { return nil }
            steps.append(step("f(\(show(p))) = \(show(q))", "\(withX.replacingOccurrences(of: "*", with: "×")) = \(show(q)) → \(c) = \(show(value))"))
            body = put(definition, c, value)
            if t.range(of: "(?<![a-z])\(c)\\s*의\\s*값", options: .regularExpression) != nil {
                return Solved(kind: .function, topic: "함숫값", concept: "주어진 함숫값을 식에 넣어 상수를 구해요.", steps: steps, answer: show(value))
            }
        } else {
            guard conditions.isEmpty else { return nil }
        }
        // 물은 식: f(2) − f(−1), 2f(1) + f(0), f(f(1))
        guard let a = match(rest, #"((?:[\s\d+\-*/().]|f\()+)\s*의\s*값"#), a[1].contains("f(") else { return nil }
        var asked = a[1].trimmingCharacters(in: .whitespaces)
        while asked.hasPrefix(",") { asked.removeFirst() }
        asked = asked.trimmingCharacters(in: .whitespaces)
        guard let lead = asked.first, "f0123456789(-".contains(lead) else { return nil }
        let original = asked
        var guardCount = 0
        while asked.contains("f("), guardCount < 8 {
            guardCount += 1
            guard let m = match(asked, #"f\(\s*("# + num + #")\s*\)"#), let x = rat(m[1]), let y = eval(body, "x", x) else { return nil }
            asked = asked.replacingOccurrences(of: m[0], with: "(" + y.text.replacingOccurrences(of: "−", with: "-") + ")")
            steps.append(step("f(\(show(x)))", show(y)))
        }
        guard !asked.contains("f"), let value = eval(asked) else { return nil }
        if original.trimmingCharacters(in: .whitespaces).range(of: #"^f\(\s*-?[\d./]+\s*\)$"#, options: .regularExpression) == nil {
            steps.append(step(original, show(value)))
        }
        return Solved(kind: .function, topic: "함숫값", concept: "f(a)는 식의 x 자리에 a를 넣은 값이에요.", steps: steps, answer: show(value))
    }

    // MARK: 소금물

    static func saltWater(_ t: String) -> Solved? {
        guard t.contains("소금물"), t.contains("%") else { return nil }
        let concept = "(소금의 양) = (소금물의 양) × (농도)/100, (농도) = (소금의 양)/(소금물의 양) × 100"
        let hundred = Rat(100)!
        if let m = match(t, "(" + num + #")\s*%\s*의\s*소금물\s*("# + num + #")\s*g\s*에\s*(소금|물)을?\s*몇\s*g\s*(?:더\s*)?넣(?:으면|어야)"#),
           let target = match(t, #"("# + num + #")\s*%\s*의\s*소금물이\s*(?:되|된)"#),
           let a = rat(m[1]), let w = rat(m[2]), let c = rat(target[1]), let salt = w * a, let s0 = salt / hundred {
            if m[3] == "소금" {
                guard c.n * a.d > a.n * c.d, let x1 = c - a, let num1 = w * x1, let den = hundred - c, !den.isZero, let x = num1 / den, x.n > 0 else { return nil }
                return Solved(kind: .linear, topic: "소금물의 농도", concept: concept,
                              steps: [step("처음 소금의 양", "\(show(w)) × \(show(a))/100 = \(show(s0)) g"), step("넣는 소금을 x g이라 하면", "(\(show(s0)) + x)/(\(show(w)) + x) × 100 = \(show(c))"), step("풀면", "x = \(show(x))")],
                              answer: show(x))
            }
            guard c.n * a.d < a.n * c.d, !c.isZero, let total = s0 * hundred, let all = total / c, let x = all - w, x.n > 0 else { return nil }
            return Solved(kind: .linear, topic: "소금물의 농도", concept: concept,
                          steps: [step("소금의 양은 그대로", "\(show(s0)) g"), step("넣는 물을 x g이라 하면", "\(show(s0))/(\(show(w)) + x) × 100 = \(show(c))"), step("풀면", "x = \(show(x))")], answer: show(x))
        }
        if let m = match(t, "(" + num + #")\s*%\s*의\s*소금물\s*("# + num + #")\s*g\s*에서\s*물을?\s*몇\s*g\s*(?:증발시키면|증발시켜야)"#),
           let target = match(t, #"("# + num + #")\s*%\s*의\s*소금물이\s*(?:되|된)"#),
           let a = rat(m[1]), let w = rat(m[2]), let c = rat(target[1]), c.n * a.d > a.n * c.d, let salt = w * a, let s0 = salt / hundred,
           let total = s0 * hundred, let after = total / c, let x = w - after, x.n > 0 {
            return Solved(kind: .linear, topic: "소금물의 농도", concept: concept,
                          steps: [step("소금의 양은 그대로", "\(show(s0)) g"), step("증발시키는 물을 x g이라 하면", "\(show(s0))/(\(show(w)) − x) × 100 = \(show(c))"), step("풀면", "x = \(show(x))")], answer: show(x))
        }
        if let m = match(t, "(" + num + #")\s*%\s*의\s*소금물\s*("# + num + #")\s*g\s*(?:과|와)\s*("# + num + #")\s*%\s*의\s*소금물\s*("# + num + #")\s*g\s*을\s*섞"#),
           has(t, ["몇 %", "농도"]), numberCount(t) == 4,
           let a = rat(m[1]), let w1 = rat(m[2]), let b = rat(m[3]), let w2 = rat(m[4]),
           let s1 = w1 * a, let s2 = w2 * b, let s = s1 + s2, let w = w1 + w2, !w.isZero, let c = s / w {
            return Solved(kind: .linear, topic: "소금물의 농도", concept: concept,
                          steps: [step("소금의 양", "\(show(w1)) × \(show(a))/100 + \(show(w2)) × \(show(b))/100"), step("농도", "(소금의 양)/\(show(w)) × 100 = \(show(c))%")], answer: show(c))
        }
        return nil
    }

    // MARK: 뽑기 · 한 줄로 세우기

    /// 늘어선 사람·문자의 수: "A, B, C, D" 또는 "5명", "다섯 개의 문자"
    static func items(_ t: String) -> Int? {
        var n: Int?
        // "남자 4명, 여자 3명": 무리가 여럿이면 다른 풀이로
        if t.range(of: #"(?:명|개|사람)\s*(?:,|과|와|및)\s*[가-힣A-Za-z\s]*?(?:\d+|한|두|세|네|다섯|여섯|일곱|여덟|아홉|열)\s*(?:명|개|사람)"#, options: .regularExpression) != nil { return nil }
        if let m = match(t, #"((?:[A-Za-z가-힣]\s*,\s*){2,}[A-Za-z가-힣])(?=\s|$|의|를|을|가|이|\s*중)"#) {
            let names = m[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard Set(names).count == names.count else { return nil }
            n = names.count
        }
        if let m = match(t, #"(?<![\d가-힣a-z])(\d+|한|두|세|네|다섯|여섯|일곱|여덟|아홉|열)\s*(?:명|개|사람)\s*(?:의\s*(?:학생|사람|문자|선수|후보))?\s*(?:중|(?:을|를)\s*(?:한\s*줄|일렬)|의\s*(?:학생|사람|문자|선수|후보)(?:을|를)\s*(?:한\s*줄|일렬))"#), let k = count(m[1]) {
            if let n0 = n, n0 != k { return nil }
            n = k
        }
        return n
    }

    static func chooseOrLine(_ t: String) -> Solved? {
        guard has(t, ["경우의 수", "방법의 수", "가지"]), !has(t, ["확률", "주사위", "동전", "카드", "숫자", "자리", "원탁", "원형", "중복", "같은 것"]) else { return nil }
        guard let n = items(t), n >= 2, n <= 12 else { return nil }
        // 대표 k명 뽑기 (순서 없음)
        if let m = match(t, #"중에서?\s*(?:대표|위원|당번|청소\s*당번)?\s*(\d+|한|두|세|네|다섯)\s*명을\s*(?:뽑|선출|고르|선택)"#), let k = count(m[1]),
           !has(t, ["회장", "반장", "부회장", "순서", "일렬", "한 줄", "차례", "각각", "1등", "2등", "포함", "않", "적어도", "남학생", "여학생"]), k <= n, let c = choose(n, k) {
            return Solved(kind: .counting, topic: "조합 (뽑기)", concept: "순서 없이 r개를 뽑는 경우의 수는 ₙCᵣ = n!/(r!(n − r)!)",
                          steps: [step("\(n)명 중 \(k)명을 순서 없이 뽑으면", "\(n)C\(k) = \(c)")], answer: "\(c)")
        }
        // 회장 1명, 부회장 1명
        if t.range(of: #"(?:회장|반장)\s*(?:1|한)\s*명\s*(?:,|과|와|및)\s*부(?:회장|반장)\s*(?:1|한)\s*명을?\s*(?:뽑|선출)"#, options: .regularExpression) != nil,
           !has(t, ["포함", "않", "적어도", "남학생", "여학생"]) {
            return Solved(kind: .counting, topic: "순열 (뽑아 세우기)", concept: "자리가 다르면 순서가 있는 뽑기: ₙPᵣ",
                          steps: [step("\(n)명 중 회장 1명, 부회장 1명", "\(n) × \(n - 1) = \(n * (n - 1))")], answer: "\(n * (n - 1))")
        }
        guard t.range(of: #"(?:한\s*줄로|일렬로)\s*(?:세울|배열할|나열할|늘어세울|앉힐|세우는|배열하는)"#, options: .regularExpression) != nil, let all = factorial(n), let less = factorial(n - 1) else { return nil }
        // 조건이 둘 이상이면 (맨 앞에 서고 이웃하지 않고 …) 다른 계산이 필요
        let conditionCount = matches(t, #"맨\s*(?:앞|뒤|처음|끝|왼쪽|오른쪽)|이웃|양\s*끝|사이에|번째|끼리|않도록|않는"#).count
        guard conditionCount <= 1 || (conditionCount == 2 && t.range(of: #"이웃하지\s*않|이웃하지\s*않도록"#, options: .regularExpression) != nil && matches(t, #"이웃"#).count == 1) else { return nil }
        let concept = "n명을 한 줄로 세우는 경우의 수는 n! (이웃하는 것은 한 묶음으로 보고, 묶음 안에서 자리를 바꾸는 경우를 곱해요)"
        if match(t, #"([A-Za-z가-힣])\s*(?:가|이|는)\s*맨\s*(?:앞|뒤|처음|끝|왼쪽|오른쪽)(?:에|에서)?\s*(?:서는|오는|놓이는|앉는|서도록|오도록)"#) != nil {
            return Solved(kind: .counting, topic: "한 줄로 세우기", concept: concept,
                          steps: [step("맨 앞(끝) 자리를 정해 두고 나머지 \(n - 1)명을 세우면", "\(n - 1)! = \(less)")], answer: "\(less)")
        }
        if let m = match(t, #"([A-Za-z가-힣])\s*(?:와|과)\s*([A-Za-z가-힣])\s*(?:가|이)\s*(?:서로\s*)?이웃하(지\s*않는|지\s*않도록|는|도록|여)"#), m[1] != m[2] {
            let adjacent = 2 * less
            if m[3].contains("않") {
                return Solved(kind: .counting, topic: "한 줄로 세우기", concept: concept,
                              steps: [step("모든 경우", "\(n)! = \(all)"), step("이웃하는 경우", "\(n - 1)! × 2 = \(adjacent)"), step("빼면", "\(all) − \(adjacent) = \(all - adjacent)")], answer: "\(all - adjacent)")
            }
            return Solved(kind: .counting, topic: "한 줄로 세우기", concept: concept,
                          steps: [step("\(m[1]), \(m[2])를 한 묶음으로 보면", "\(n - 1)! = \(less)"), step("묶음 안에서 자리를 바꾸면", "\(less) × 2 = \(adjacent)")], answer: "\(adjacent)")
        }
        if let m = match(t, #"특정한\s*두\s*(?:사람|명|학생|문자)(?:이|가)\s*(?:서로\s*)?이웃하(지\s*않는|지\s*않도록|는|도록|여)"#) {
            let adjacent = 2 * less
            let answer = m[1].contains("않") ? all - adjacent : adjacent
            return Solved(kind: .counting, topic: "한 줄로 세우기", concept: concept,
                          steps: [step("두 사람을 한 묶음으로 보면", "\(n - 1)! × 2 = \(adjacent)")] + (m[1].contains("않") ? [step("전체에서 빼면", "\(all) − \(adjacent) = \(answer)")] : []), answer: "\(answer)")
        }
        if let m = match(t, #"([A-Za-z가-힣])\s*(?:와|과)\s*([A-Za-z가-힣])\s*(?:가|이)\s*양\s*끝에"#), m[1] != m[2], n >= 3, let middle = factorial(n - 2) {
            return Solved(kind: .counting, topic: "한 줄로 세우기", concept: concept,
                          steps: [step("양 끝에 두 사람을 세우는 경우", "2"), step("가운데 \(n - 2)명", "\(n - 2)! = \(middle)"), step("곱하면", "\(2 * middle)")], answer: "\(2 * middle)")
        }
        return nil
    }

    // MARK: √(ax)가 자연수가 되도록 하는 x

    static func sqrtNatural(_ t: String) -> Solved? {
        guard let m = match(t, #"√\s*\(?\s*([0-9x+\-*/\s]+?)\s*\)?\s*(?:가|이)\s*(자연수|정수)가?\s*되도록\s*하는\s*(가장\s*작은|가장\s*큰)?\s*(두\s*자리의?|세\s*자리의?)?\s*자연수\s*x\s*(?:의\s*(값|개수)|는|를|의\s*값의\s*합)"#) else { return nil }
        let inner = m[1].trimmingCharacters(in: .whitespaces)
        guard inner.contains("x"), let node = DoitMathCalc.parse(inner) else { return nil }
        let natural = m[2] == "자연수"
        var lo = 1, hi = 20000
        if m[4].hasPrefix("두") { lo = 10; hi = 99 } else if m[4].hasPrefix("세") { lo = 100; hi = 999 }
        let wantsCount = m[5] == "개수" || m[0].contains("합")
        let wantsMax = m[3].contains("큰")
        guard wantsCount || wantsMax || m[3].contains("작은") else { return nil }
        func ok(_ x: Int) -> Bool {
            guard let x0 = Rat(x), let v = DoitMathCalc.evalRat(node, x0), v.isInteger, v.n >= (natural ? 1 : 0), let r = DoitMathExact.integerRoot(v.n, 2) else { return false }
            return r * r == v.n
        }
        if (wantsCount || wantsMax), m[4].isEmpty {
            // 끝없이 늘어나는 식이면 개수·가장 큰 수가 없음: 큰 x에서 값이 1보다 작아야 함 (줄어드는 식)
            guard let far = node.eval(Double(hi)), far < (natural ? 1 : 0), let a = node.eval(1), let b = node.eval(2), b < a else { return nil }
            for x in stride(from: hi, through: hi - 500, by: -1) where ok(x) { return nil }
        }
        let hits = (lo...hi).filter(ok)
        guard !hits.isEmpty else { return nil }
        let concept = "√A가 자연수가 되려면 A가 (자연수)²이어야 해요. 소인수분해해서 지수가 모두 짝수가 되게 해요."
        if m[0].contains("합") {
            let s = hits.reduce(0, +)
            return Solved(kind: .numberTheory, topic: "제곱근이 자연수가 되는 조건", concept: concept, steps: [step("x", hits.map(String.init).joined(separator: ", ")), step("합", "\(s)")], answer: "\(s)")
        }
        if wantsCount {
            return Solved(kind: .numberTheory, topic: "제곱근이 자연수가 되는 조건", concept: concept, steps: [step("되는 x", hits.map(String.init).joined(separator: ", "))], answer: "\(hits.count)")
        }
        let x = wantsMax ? hits.last! : hits.first!
        let v = DoitMathCalc.evalRat(node, Rat(x)!)!
        return Solved(kind: .numberTheory, topic: "제곱근이 자연수가 되는 조건", concept: concept,
                      steps: [step("x = \(x)이면", "√\(v.text) = \(DoitMathExact.integerRoot(v.n, 2) ?? 0)")], answer: "\(x)")
    }

    // MARK: √16의 제곱근

    static func rootOfRoot(_ t: String) -> Solved? {
        guard let m = match(t, #"(?<![\d)])√\s*(\d+)\s*의\s*(양의\s*|음의\s*)?제곱근(?:은|을|는|\?|$|의\s*값|을\s*구)"#), let n = Int(m[1]),
              let r = DoitMathExact.integerRoot(n, 2), r > 0 else { return nil }
        let inner: String
        if let s = DoitMathExact.integerRoot(r, 2) { inner = "\(s)" } else {
            let sr = DoitAlgebra.simplifyRoot(r)
            inner = (sr.outside == 1 ? "" : "\(sr.outside)") + "√\(sr.inside)"
        }
        let answer = m[2].contains("양") ? inner : m[2].contains("음") ? "−" + inner : "±" + inner
        return Solved(kind: .calc, topic: "제곱근", concept: "a(a > 0)의 제곱근은 ±√a 두 개예요. 먼저 √\(n) = \(r)를 구해요.",
                      steps: [step("√\(n)", "\(r)"), step("\(r)의 제곱근", "±√\(r) = ±\(inner)")], answer: answer)
    }

    // MARK: 꼭짓점·지나는 점 · 세 점으로 이차함수의 식

    static func polyText(_ c: [Rat]) -> String {
        var p = DoitMath.Poly()
        for (i, r) in c.enumerated() where i < DoitMath.Poly.size { p.c[i] = r.value }
        return DoitMath.describe(p)
    }

    static func quadraticThrough(_ t: String) -> Solved? {
        guard has(t, ["이차함수", "포물선"]), !has(t, ["최댓값", "최솟값", "평행이동", "대칭이동", "넓이", "x축과 만나는 두 점 사이"]) else { return nil }
        let point = #"\(\s*("# + num + #")\s*,\s*("# + num + #")\s*\)"#
        let pts = matches(t, point).compactMap { m -> (Rat, Rat)? in
            guard let x = rat(m[1]), let y = rat(m[2]) else { return nil }
            return (x, y)
        }
        var coefficients: [Rat]?
        var steps: [SolutionStep] = []
        if let v = match(t, #"꼭짓점(?:의\s*좌표)?(?:가|이|는|은)?\s*"# + point), let p = rat(v[1]), let q = rat(v[2]) {
            guard pts.count == 2, let other = pts.first(where: { $0 != (p, q) }), other.0 != p,
                  let dx = other.0 - p, let dx2 = dx * dx, let dy = other.1 - q, let a = dy / dx2, !a.isZero else { return nil }
            // y = a(x − p)² + q = ax² − 2apx + ap² + q
            guard let ap = a * p, let b = ap * Rat(-2)!, let app = ap * p, let c = app + q else { return nil }
            coefficients = [c, b, a]
            steps = [step("꼭짓점이 (\(show(p)), \(show(q)))이면", "y = a(x − \(show(p)))² + \(show(q))"), step("점 (\(show(other.0)), \(show(other.1)))을 넣으면", "a = \(show(a))")]
        } else if pts.count == 3, has(t, ["세 점", "지나는", "지날"]) {
            let xs = pts.map(\.0)
            guard Set(xs.map { "\($0.n)/\($0.d)" }).count == 3 else { return nil }
            // 라그랑주 보간: 정확한 분수로
            var c: [Rat] = [.zero, .zero, .zero]
            for i in 0..<3 {
                let others = (0..<3).filter { $0 != i }
                let (xj, xk) = (xs[others[0]], xs[others[1]])
                guard let d1 = xs[i] - xj, let d2 = xs[i] - xk, let den = d1 * d2, let w = pts[i].1 / den,
                      let sum = xj + xk, let prod = xj * xk,
                      let a2 = c[2] + w, let ws = w * sum, let a1 = c[1] - ws, let wp = w * prod, let a0 = c[0] + wp else { return nil }
                c = [a0, a1, a2]
            }
            guard !c[2].isZero else { return nil }
            coefficients = c
            steps = [step("y = ax² + bx + c에 세 점을 넣고 연립하면", "a = \(show(c[2])), b = \(show(c[1])), c = \(show(c[0]))")]
        }
        guard let c = coefficients else { return nil }
        let formula = "y = " + polyText(c)
        steps.append(step("식", formula))
        let concept = "꼭짓점 (p, q)를 알면 y = a(x − p)² + q, 세 점을 알면 y = ax² + bx + c에 넣어 연립해요."
        // "y = ax² + bx + c 라 할 때 a + b + c의 값"
        let general = t.range(of: #"y\s*=\s*ax\^2\s*\+\s*bx\s*\+\s*c"#, options: .regularExpression) != nil
        if general, t.range(of: #"a\s*,\s*b\s*,\s*c\s*의\s*값"#, options: .regularExpression) != nil {
            return Solved(kind: .function, topic: "이차함수의 식", concept: concept, steps: steps, answer: "a = \(show(c[2])), b = \(show(c[1])), c = \(show(c[0]))")
        }
        if general, let e = match(t, #"상수\s*a\s*,\s*b\s*,\s*c\s*에\s*대하여\s*([abc+\-*\s\d()]+?)\s*의\s*값"#) ?? match(t, #"([abc]\s*[+\-*]\s*[abc+\-*\s\d()]*?)\s*의\s*값"#) {
            var expr = e[1]
            for (letter, value) in [("a", c[2]), ("b", c[1]), ("c", c[0])] { expr = put(expr, Character(letter), value) }
            guard let v = eval(expr) else { return nil }
            steps.append(step(e[1].trimmingCharacters(in: .whitespaces), show(v)))
            return Solved(kind: .function, topic: "이차함수의 식", concept: concept, steps: steps, answer: show(v))
        }
        guard has(t, ["식을 구", "식은", "식을 쓰", "나타내", "함수의 식"]) else { return nil }
        return Solved(kind: .function, topic: "이차함수의 식", concept: concept, steps: steps, answer: formula)
    }

    // MARK: 직각삼각형 · 세 변으로 넓이

    static func triangleArea(_ t: String) -> Solved? {
        guard t.contains("넓이"), !has(t, ["그림", "색칠", "넓이가"]) else { return nil }
        let unit = #"\s*(?:cm|m|mm)?\s*"#
        if t.contains("직각삼각형"), let m = match(t, #"빗변의\s*길이가\s*("# + num + ")" + unit + #"(?:이고|,|인)\s*(?:다른\s*)?한\s*변의\s*길이가\s*("# + num + ")"),
           let c = rat(m[1]), let a = rat(m[2]), c.n * a.d > a.n * c.d, let c2 = c * c, let a2 = a * a, let b2 = c2 - a2, let b = DoitMathExact.Surd.sqrt(b2),
           let half = Rat(1, 2), let area = b * DoitMathExact.Surd(a), let result = area * DoitMathExact.Surd(half) {
            return Solved(kind: .geometry, topic: "직각삼각형의 넓이", concept: "피타고라스 정리로 나머지 한 변을 구한 뒤, (밑변) × (높이) ÷ 2",
                          steps: [step("나머지 한 변", "√(\(show(c))² − \(show(a))²) = \(b.text)"), step("넓이", "\(show(a)) × \(b.text) ÷ 2 = \(result.text)")], answer: result.text)
        }
        if t.contains("삼각형"), !t.contains("직각"), let m = match(t, #"세\s*변의\s*길이가\s*("# + num + ")" + unit + #",\s*("# + num + ")" + unit + #",?\s*("# + num + ")" + unit + #"인\s*삼각형의\s*넓이"#),
           let a = rat(m[1]), let b = rat(m[2]), let c = rat(m[3]) {
            let s3 = [a, b, c].sorted { $0.value < $1.value }
            guard let sum2 = s3[0] + s3[1], sum2.value > s3[2].value else { return nil }
            guard let ab = a + b, let abc = ab + c, let s = abc / Rat(2)!, let sa = s - a, let sb = s - b, let sc = s - c,
                  let p1 = s * sa, let p2 = p1 * sb, let p3 = p2 * sc, let area = DoitMathExact.Surd.sqrt(p3) else { return nil }
            // 직각삼각형이면 두 변의 곱 ÷ 2 로 보여 주기
            if let x = s3[0] * s3[0], let y = s3[1] * s3[1], let z = s3[2] * s3[2], let xy = x + y, xy == z {
                return Solved(kind: .geometry, topic: "삼각형의 넓이", concept: "a² + b² = c²이면 직각삼각형 (빗변 c)이에요.",
                              steps: [step("\(show(s3[0]))² + \(show(s3[1]))² = \(show(s3[2]))²", "직각삼각형"), step("넓이", "\(show(s3[0])) × \(show(s3[1])) ÷ 2 = \(area.text)")], answer: area.text)
            }
            return Solved(kind: .geometry, topic: "삼각형의 넓이", concept: "헤론의 공식: s = (a + b + c)/2 일 때 넓이 = √(s(s − a)(s − b)(s − c))",
                          steps: [step("s", show(s)), step("넓이", "√(\(show(p3))) = \(area.text)")], answer: area.text)
        }
        return nil
    }

    // MARK: 조건이 있는 부분집합의 개수

    static func setElements(_ t: String, name: String) -> [String]? {
        guard let m = match(t, name + #"\s*=\s*\{([^{}]*)\}"#) else { return nil }
        let items = m[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !items.isEmpty, Set(items).count == items.count, !items.contains(where: { $0.contains("|") || $0.contains(":") || $0.contains("…") || $0.contains("...") }) else { return nil }
        return items
    }

    static func constrainedSubsets(_ t: String) -> Solved? {
        guard t.contains("부분집합"), has(t, ["개수", "몇 개"]), !has(t, ["또는", "적어도", "중 하나", "하나 이상", "만을", "만 원소", "홀수", "짝수", "소수", "배수", "진부분집합", "∪", "∩", "원소의 개수가", "개인 부분집합", "B ⊂", "⊂ X", "X ⊂"]),
              let name = match(t, #"집합\s*([A-Z])\s*="#)?[1], let elements = setElements(t, name: name) else { return nil }
        var must = Set<String>(), never = Set<String>()
        for m in matches(t, #"((?:[0-9a-z]+\s*,\s*)*[0-9a-z]+)\s*(?:은|는|을|를|이|가|와|과)\s*(?:모두\s*)?(?:반드시\s*)?(?:원소로\s*)?(갖|가지|포함하)(지\s*않|고|는|며)"#) {
            let list = m[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard list.allSatisfy({ elements.contains($0) }) else { return nil }
            if m[3].contains("않") { never.formUnion(list) } else { must.formUnion(list) }
        }
        guard !must.isEmpty || !never.isEmpty, must.isDisjoint(with: never) else { return nil }
        let free = elements.count - must.count - never.count
        guard free >= 0, free <= 30 else { return nil }
        let value = 1 << free
        var parts: [String] = []
        if !must.isEmpty { parts.append("반드시 들어가는 원소 \(must.count)개") }
        if !never.isEmpty { parts.append("들어가지 않는 원소 \(never.count)개") }
        return Solved(kind: .sets, topic: "조건이 있는 부분집합의 개수", concept: "원소가 n개인 집합에서 k개는 반드시 넣고 m개는 빼는 부분집합의 개수는 2ⁿ⁻ᵏ⁻ᵐ",
                      steps: [step("원소 \(elements.count)개 중 " + parts.joined(separator: ", "), "남은 \(free)개만 넣을지 말지 정함"), step("개수", "2^\(free) = \(value)")], answer: "\(value)")
    }

    // MARK: 여집합 · 차집합의 원소 개수

    static func complementCount(_ t: String) -> Solved? {
        guard t.contains("n("), let target = match(t, #"n\(\s*([^)]*?)\s*\)\s*의\s*값"#)?[1] ?? match(t, #"n\(\s*([^)]*?)\s*\)\s*(?:은|는|을\s*구|\?)"#)?[1] else { return nil }
        let squash = { (s: String) in s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "ᶜ", with: "^c").replacingOccurrences(of: "∁", with: "") }
        var given: [String: Rat] = [:]
        for m in matches(t, #"n\(\s*([^)]*?)\s*\)\s*=\s*(\d+)"#) { if let v = rat(m[2]) { given[squash(m[1])] = v } }
        guard let u = given["U"], let a = given["A"], let b = given["B"] else { return nil }
        var both = given["A∩B"] ?? given["B∩A"]
        var either = given["A∪B"] ?? given["B∪A"]
        if both == nil, let e = either { both = (a + b).flatMap { $0 - e } }
        if either == nil, let i = both { either = (a + b).flatMap { $0 - i } }
        guard let i = both, let e = either, i.n >= 0, e.value <= u.value else { return nil }
        let goal = squash(target)
        var value: Rat?
        var how = ""
        switch goal {
        case "A^c∩B^c", "(A∪B)^c": value = u - e; how = "n(U) − n(A ∪ B) = \(show(u)) − \(show(e))"
        case "A^c∪B^c", "(A∩B)^c": value = u - i; how = "n(U) − n(A ∩ B) = \(show(u)) − \(show(i))"
        case "A-B", "A∩B^c", "A−B": value = a - i; how = "n(A) − n(A ∩ B) = \(show(a)) − \(show(i))"
        case "B-A", "B∩A^c", "A^c∩B", "B−A": value = b - i; how = "n(B) − n(A ∩ B) = \(show(b)) − \(show(i))"
        case "A^c": value = u - a; how = "n(U) − n(A)"
        case "B^c": value = u - b; how = "n(U) − n(B)"
        default: return nil
        }
        guard let v = value, v.n >= 0 else { return nil }
        return Solved(kind: .sets, topic: "집합의 원소의 개수", concept: "n(A ∪ B) = n(A) + n(B) − n(A ∩ B), n(Aᶜ ∩ Bᶜ) = n((A ∪ B)ᶜ) = n(U) − n(A ∪ B)",
                      steps: [step("n(A ∪ B)", "\(show(a)) + \(show(b)) − \(show(i)) = \(show(e))"), step(target, "\(how) = \(show(v))")], answer: show(v))
    }

    // MARK: 로그 · 지수 부등식

    /// 일차부등식 (px + q) op r 의 해 → (아래 끝, 포함, 위 끝, 포함)
    struct Interval {
        var lo: Rat?, loIn = false, hi: Rat?, hiIn = false
        mutating func meet(_ o: Interval) {
            if let l = o.lo { if lo == nil || l.value > lo!.value || (l == lo! && !o.loIn) { lo = l; loIn = o.loIn } }
            if let h = o.hi { if hi == nil || h.value < hi!.value || (h == hi! && !o.hiIn) { hi = h; hiIn = o.hiIn } }
        }
        var isEmpty: Bool {
            guard let l = lo, let h = hi else { return false }
            return l.value > h.value || (l == h && !(loIn && hiIn))
        }
        func text(_ v: String = "x") -> String {
            switch (lo, hi) {
            case let (l?, h?): return "\(show(l)) \(loIn ? "≤" : "<") \(v) \(hiIn ? "≤" : "<") \(show(h))"
            case let (l?, nil): return "\(v) \(loIn ? "≥" : ">") \(show(l))"
            case let (nil, h?): return "\(v) \(hiIn ? "≤" : "<") \(show(h))"
            default: return "모든 실수"
            }
        }
    }

    /// p·x + q (op) r 를 x의 범위로
    static func linearInterval(p: Rat, q: Rat, op: String, r: Rat) -> Interval? {
        guard !p.isZero, let d = r - q, let bound = d / p else { return nil }
        var flip = p.n < 0
        var o = op
        if flip { o = ["<": ">", ">": "<", "≤": "≥", "≥": "≤"][op] ?? op }
        flip = false
        switch o {
        case "<": return Interval(lo: nil, hi: bound, hiIn: false)
        case "≤": return Interval(lo: nil, hi: bound, hiIn: true)
        case ">": return Interval(lo: bound, loIn: false)
        case "≥": return Interval(lo: bound, loIn: true)
        default: return nil
        }
    }

    static func linearParts(_ s: String) -> (Rat, Rat)? {
        guard let q = eval(s, "x", .zero), let one = eval(s, "x", .one), let two = Rat(2), let f2 = eval(s, "x", two),
              let p = one - q, let p2 = f2 - one, p == p2, !p.isZero else { return nil }
        return (p, q)
    }

    static func subscriptNumber(_ s: String) -> Int? {
        let map: [Character: Character] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9"]
        return Int(String(s.compactMap { map[$0] ?? ($0.isNumber ? $0 : nil) }))
    }

    static func logInequality(_ t: String) -> Solved? {
        guard t.contains("log"), t.contains("부등식"), has(t, ["해", "범위", "정수", "x의 값"]) else { return nil }
        guard let m = match(t, #"부등식\s*log\s*_?([₀-₉0-9]+)\s*(?:\(([^()]+)\)|(x))\s*(<|>|≤|≥)\s*("# + num + #")\s*(?:의|을|를|이|에서|에)"#),
              let base = subscriptNumber(m[1]), base >= 2, let c = rat(m[5]), c.isInteger, abs(c.n) <= 12 else { return nil }
        let inner = m[2].isEmpty ? m[3] : m[2]
        guard let (p, q) = linearParts(inner), let b = Rat(base), let bound = c.n >= 0 ? b.power(c.n) : b.power(-c.n).flatMap({ Rat.one / $0 }),
              var range = linearInterval(p: p, q: q, op: ">", r: .zero), let cond = linearInterval(p: p, q: q, op: m[4], r: bound) else { return nil }
        range.meet(cond)
        guard !range.isEmpty else { return nil }
        let answer = range.text()
        let concept = "밑이 1보다 크면 logₐ f(x) < c ⇔ 0 < f(x) < aᶜ (진수 조건 f(x) > 0을 꼭 함께)"
        let steps = [step("진수 조건", "\(inner.trimmingCharacters(in: .whitespaces)) > 0"), step("밑 \(base) > 1 이므로", "\(inner.trimmingCharacters(in: .whitespaces)) \(m[4]) \(base)^\(c.n) = \(show(bound))"), step("함께 만족하는 범위", answer)]
        if has(t, ["정수의 개수", "정수 x의 개수", "자연수의 개수", "자연수 x의 개수"]) {
            guard let lo = range.lo, let hi = range.hi else { return nil }
            var k = 0
            var x = Int(lo.value.rounded(.down)) - 1
            let natural = t.contains("자연수")
            while Double(x) <= hi.value + 1 {
                let v = Double(x)
                let inLo = range.loIn ? v >= lo.value - 1e-12 : v > lo.value + 1e-12
                let inHi = range.hiIn ? v <= hi.value + 1e-12 : v < hi.value - 1e-12
                if inLo, inHi, !natural || x >= 1 { k += 1 }
                x += 1
                if k > 100000 { return nil }
            }
            return Solved(kind: .inequality, topic: "로그부등식", concept: concept, steps: steps + [step("개수", "\(k)")], answer: "\(k)")
        }
        guard has(t, ["해는", "해를 구", "풀", "범위", "해?"]) else { return nil }
        return Solved(kind: .inequality, topic: "로그부등식", concept: concept, steps: steps, answer: answer)
    }

    /// b = g^m 꼴 (g는 작은 밑)
    static func powerOf(_ r: Rat) -> (g: Int, k: Rat)? {
        for g in [2, 3, 5, 6, 7, 10, 11, 13] {
            for e in -20...20 where e != 0 {
                guard let gp = Rat(g) else { continue }
                let v = e > 0 ? gp.power(e) : gp.power(-e).flatMap { Rat.one / $0 }
                if v == r { return (g, Rat(e)!) }
            }
        }
        if r == .one { return (2, .zero) }
        return nil
    }

    static func expInequality(_ t: String) -> Solved? {
        guard t.contains("부등식"), t.contains("^"), !t.contains("log"), has(t, ["해", "범위"]) else { return nil }
        guard let m = match(t, #"부등식\s*(\d+|\(\s*\d+\s*/\s*\d+\s*\))\s*\^\s*(?:\(([^()]+)\)|(-?\d*x))\s*(<|>|≤|≥)\s*("# + num + #"|\(\s*\d+\s*/\s*\d+\s*\))\s*(?:의|을|를|이|에서|에)"#),
              let b = rat(m[1]), let r = rat(m[5]), r.n > 0, b.n > 0, b != .one else { return nil }
        let exponent = m[2].isEmpty ? m[3] : m[2]
        guard let (p, q) = linearParts(exponent), let gb = powerOf(b), let gr = powerOf(r), gb.g == gr.g || gr.k.isZero, !gb.k.isZero,
              let k = gr.k / gb.k else { return nil }
        // b > 1 이면 부등호 그대로, 0 < b < 1 이면 반대로
        var op = m[4]
        if b.value < 1 { op = ["<": ">", ">": "<", "≤": "≥", "≥": "≤"][op] ?? op }
        guard let range = linearInterval(p: p, q: q, op: op, r: k) else { return nil }
        let answer = range.text()
        return Solved(kind: .inequality, topic: "지수부등식", concept: "밑이 1보다 크면 aᶠ⁽ˣ⁾ < aᵍ⁽ˣ⁾ ⇔ f(x) < g(x), 밑이 0과 1 사이면 부등호 방향이 바뀌어요.",
                      steps: [step("밑을 같게 하면", "\(show(r)) = \(show(b))^\(show(k))"), step(b.value < 1 ? "밑이 1보다 작으므로 부등호 방향을 바꾸면" : "지수끼리 비교하면", "\(exponent.trimmingCharacters(in: .whitespaces)) \(op) \(show(k))"), step("해", answer)],
                      answer: answer)
    }

    // MARK: 거듭제곱으로 쓴 수의 최대공약수 · 최소공배수

    static func factorText(_ n: Int) -> String {
        var parts: [String] = []
        var m = n, p = 2
        while m > 1, p <= m {
            var e = 0
            while m % p == 0 { m /= p; e += 1 }
            if e > 0 { parts.append("\(p)" + DoitMath.superscript(e)) }
            p += 1
        }
        return parts.isEmpty ? "1" : parts.joined(separator: " × ")
    }

    static func factoredGcd(_ t: String) -> Solved? {
        guard has(t, ["최대공약수", "최소공배수"]), let m = match(t, #"(?:두|세)\s*수\s*([0-9^*,\s]+?)\s*(?:의|에\s*대하여)\s*(최대공약수|최소공배수)"#), m[1].contains("^") else { return nil }
        let items = m[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard items.count >= 2 else { return nil }
        var values: [Int] = []
        for s in items {
            guard let v = eval(s), v.isInteger, v.n > 0, v.n < 1_000_000_000 else { return nil }
            values.append(v.n)
        }
        let asked = m[2]
        var r = values[0]
        for v in values.dropFirst() {
            if asked == "최대공약수" { r = DoitAlgebra.gcd(r, v) } else {
                guard let p = DoitMathExact.mul(r / DoitAlgebra.gcd(r, v), v) else { return nil }
                r = p
            }
        }
        let text = factorText(r)
        return Solved(kind: .numberTheory, topic: asked, concept: asked == "최대공약수" ? "공통인 소인수를 지수가 작은 쪽으로 곱해요." : "모든 소인수를 지수가 큰 쪽으로 곱해요.",
                      steps: [step("소인수의 지수를 비교하면", text), step("값", "\(r)")], answer: text.contains("×") || text.contains("²") || text.contains("³") ? "\(text) (= \(r))" : "\(r)")
    }

    // MARK: 판별식으로 상수의 범위 (x축과 만남 · 접함 · 항상 성립)

    /// 이차식의 계수 (문자 k에 값을 넣은 다음)
    static func quadCoefficients(_ s: String, _ letter: Character, _ value: Rat) -> (a: Rat, b: Rat, c: Rat)? {
        let filled = put(s, letter, value)
        guard let f0 = eval(filled, "x", .zero), let f1 = eval(filled, "x", .one), let fm = eval(filled, "x", -Rat.one),
              let two = Rat(2), let f2 = eval(filled, "x", two),
              let s1 = f1 + fm, let h = s1 / two, let a = h - f0, let d = f1 - fm, let b = d / two else { return nil }
        // 이차식인지 확인 (x = 2에서도 맞아야 함)
        guard let a4 = a * Rat(4)!, let b2 = b * two, let sum = a4 + b2, let check = sum + f0, check == f2 else { return nil }
        return (a, b, f0)
    }

    static func discriminantCondition(_ t: String) -> Solved? {
        guard let kLetter = match(t, #"(?:실수|상수)\s*([km])\s*의\s*(?:값의\s*범위|값)"#)?[1].first else { return nil }
        var poly: String?
        var relation = ""   // ">": 서로 다른 두 실근 / "=": 중근 / "<": 허근 / "≥": 실근
        var leadingPositive = false
        let e = #"([0-9a-z+\-*/^().\s]+?)"#
        if let m = match(t, #"이차함수\s*y\s*=\s*"# + e + #"\s*의\s*그래프(?:가|와)\s*x축(?:과|이)?\s*(서로\s*다른\s*두\s*점에서\s*만나|한\s*점에서\s*만나|접하|만나지\s*않|만나)"#) {
            poly = m[1]
            relation = m[2].contains("다른") ? ">" : (m[2].contains("한 점") || m[2].contains("접")) ? "=" : m[2].contains("않") ? "<" : "≥"
        } else if let m = match(t, #"이차함수\s*y\s*=\s*"# + e + #"\s*의\s*그래프와\s*직선\s*y\s*=\s*"# + e + #"\s*(?:가|이)\s*(서로\s*다른\s*두\s*점에서\s*만나|한\s*점에서\s*만나|접하|접할|만나지\s*않|만나)"#) {
            poly = "(" + m[1] + ")-(" + m[2] + ")"
            relation = m[3].contains("다른") ? ">" : (m[3].contains("한 점") || m[3].contains("접")) ? "=" : m[3].contains("않") ? "<" : "≥"
        } else if let m = match(t, #"이차방정식\s*"# + e + #"\s*=\s*0\s*(?:이|가)\s*(서로\s*다른\s*두\s*실근|중근|서로\s*다른\s*두\s*허근|허근|실근)을?\s*(?:갖|가지)(지\s*않)?"#) {
            poly = m[1]
            relation = m[2].contains("허근") ? "<" : m[2].contains("중근") ? "=" : m[2].contains("다른") ? ">" : "≥"
            // "실근을 갖지 않도록" → 허근 (반대 조건)
            if !m[3].isEmpty {
                guard relation != "=" else { return nil }
                relation = ["<": "≥", ">": "≤", "≥": "<"][relation] ?? relation
            }
        } else if let m = match(t, #"모든\s*실수\s*x\s*에\s*대하여\s*(?:이차부등식\s*)?"# + e + #"\s*(>|≥)\s*0\s*(?:이|가)\s*(?:항상\s*)?성립"#) {
            poly = m[1]
            relation = m[2] == ">" ? "<" : "≤"
            leadingPositive = true
        }
        if poly == nil, let m = match(t, #"(?:이차부등식\s*)?"# + e + #"\s*(>|≥)\s*0\s*(?:이|가)\s*모든\s*실수\s*x\s*에\s*대하여\s*(?:항상\s*)?성립"#) {
            poly = m[1]
            relation = m[2] == ">" ? "<" : "≤"
            leadingPositive = true
        }
        guard let p = poly, p.contains(kLetter), p.contains("x") else { return nil }
        let letters = Set(p.filter { $0.isLetter && $0.isASCII })
        guard letters == ["x", kLetter] else { return nil }
        // D(k) = b² − 4ac 를 k = 0, 1, 2, 3, 4 에서 계산해 이차 이하 다항식으로
        var ds: [Rat] = []
        for v in 0...4 {
            guard let co = quadCoefficients(p, kLetter, Rat(v)!), !co.a.isZero else { return nil }
            if leadingPositive, co.a.n < 0 { return nil }
            guard let bb = co.b * co.b, let ac = co.a * co.c, let ac4 = ac * Rat(4)!, let d = bb - ac4 else { return nil }
            ds.append(d)
        }
        // 이차항 계수에 k가 들어 있으면 (a ≠ 0 조건이 따로 생김) 풀지 않음
        let a0 = quadCoefficients(p, kLetter, .zero)!.a, a1 = quadCoefficients(p, kLetter, .one)!.a
        guard a0 == a1 else { return nil }
        // 차분으로 계수: D(k) = A k² + B k + C
        guard let d1 = ds[1] - ds[0], let d2 = ds[2] - ds[1], let dd = d2 - d1, let A = dd / Rat(2)!,
              let Ak = A * Rat(1)!, let B = d1 - Ak, let C = Optional(ds[0]) else { return nil }
        for v in 3...4 {
            guard let kv = Rat(v), let k2 = kv * kv, let t1 = A * k2, let t2 = B * kv, let s = t1 + t2, let s2 = s + C, s2 == ds[v] else { return nil }
        }
        let name = String(kLetter)
        var answer: String?
        if A.isZero {
            guard !B.isZero, let root = (-C) / B else { return nil }
            if relation == "=" { answer = "\(name) = \(show(root))" } else {
                guard let range = linearInterval(p: B, q: C, op: relation, r: .zero) else { return nil }
                answer = range.text(name)
            }
        } else {
            // A k² + B k + C 의 근 (유리수일 때만)
            guard let bb = B * B, let ac = A * C, let ac4 = ac * Rat(4)!, let disc = bb - ac4, disc.n >= 0, let sq = DoitMathExact.Surd.sqrt(disc), let r = sq.rational,
                  let twoA = A * Rat(2)!, let r1n = -B - r, let r2n = -B + r, let x1 = r1n / twoA, let x2 = r2n / twoA else { return nil }
            let (lo, hi) = x1.value <= x2.value ? (x1, x2) : (x2, x1)
            let positiveOpen = A.n > 0
            switch relation {
            case "=":
                if lo == hi { answer = "\(name) = \(show(lo))" }
                else if t.contains("양수"), lo.n <= 0, hi.n > 0 { answer = "\(name) = \(show(hi))" }
                else if t.contains("음수"), hi.n >= 0, lo.n < 0 { answer = "\(name) = \(show(lo))" }
                else { answer = "\(name) = \(show(lo)) 또는 \(name) = \(show(hi))" }
            case "<", "≤":
                guard positiveOpen, lo != hi || relation == "≤" else { return nil }
                let op = relation == "<" ? "<" : "≤"
                answer = lo == hi ? "\(name) = \(show(lo))" : "\(show(lo)) \(op) \(name) \(op) \(show(hi))"
            default:
                guard positiveOpen, lo != hi else { return nil }
                let op = relation == ">" ? "<" : "≤"
                answer = "\(name) \(op) \(show(lo)) 또는 \(name) \(op == "<" ? ">" : "≥") \(show(hi))"
            }
        }
        guard let ans = answer else { return nil }
        // "k의 값"은 = 일 때만, "범위"는 부등식일 때만
        if relation == "=", t.contains("범위") { return nil }
        if relation != "=", !t.contains("범위") { return nil }
        return Solved(kind: .inequality, topic: "판별식의 활용", concept: "이차방정식 ax² + bx + c = 0의 판별식 D = b² − 4ac: D > 0 서로 다른 두 실근(두 점), D = 0 중근(접함), D < 0 허근(만나지 않음). 모든 x에서 ax² + bx + c > 0 ⇔ a > 0, D < 0",
                      steps: [step("판별식", "D = \(A.isZero ? "" : "\(show(A))\(name)² + ")\(show(B))\(name) + \(show(C))".replacingOccurrences(of: "+ −", with: "− ")), step("조건 D \(relation) 0 을 풀면", ans)], answer: ans)
    }
}
