import Foundation

/// 모티 AI 수학 풀이: 기하 (외부 AI 없이 직접 계산)
/// - 이차곡선: 포물선의 초점·준선, 타원의 초점·장축·단축, 쌍곡선의 초점·점근선·주축, 타원 위의 점에서 두 초점까지 거리의 합
/// - 평면벡터·공간벡터: 성분의 합·차·실수배, 크기, 내적, 이루는 각, 수직·평행 조건
/// - |a|, |b|, 이루는 각(또는 a·b, |a + b|)으로 다른 값 구하기
/// - 좌표공간: 두 점 사이의 거리, 중점·내분점, 무게중심, 대칭인 점, 구의 중심과 반지름
enum DoitMathSpace {
    typealias Solved = MathSolver.Solved

    private static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }
    private static func match(_ t: String, _ p: String) -> [String]? { DoitMathExact.match(t, p) }
    private static func matches(_ t: String, _ p: String) -> [[String]] { DoitMathExact.matches(t, p) }
    private static func step(_ h: String, _ w: String) -> SolutionStep { SolutionStep(hint: h, work: w) }
    private static func show(_ v: Double) -> String? { DoitMathCalc.nice(v, allow: [.surd]) }
    private static let num = #"-?\d+(?:\.\d+)?(?:/\d+)?"#

    static func solve(_ t: String) -> Solved? {
        if let s = conic(t) { return s }
        if let s = vectorGram(t) { return s }
        if let s = vectorComponents(t) { return s }
        if let s = space(t) { return s }
        if let s = sphere(t) { return s }
        return nil
    }

    // MARK: - 이차곡선

    /// 방정식 → x², y², x, y, xy, 상수의 계수 (좌변 − 우변)
    private static func quadraticCoefficients(_ equation: String) -> [String: Double]? {
        let sides = equation.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard sides.count == 2, let l = DoitAlgebra.parse(sides[0]), let r = DoitAlgebra.parse(sides[1]) else { return nil }
        let p = l - r
        guard p.degree == 2, p.t.keys.allSatisfy({ $0.z == 0 }) else { return nil }
        return ["xx": p.coef(x: 2), "yy": p.coef(y: 2), "xy": p.coef(x: 1, y: 1), "x": p.coef(x: 1), "y": p.coef(y: 1), "1": p.constantValue]
    }

    /// 곡선 이름 뒤의 방정식
    private static func conicEquation(_ t: String, _ name: String) -> String? {
        guard let r = t.range(of: name) else { return nil }
        let rest = t[r.upperBound...]
        var out = ""
        for ch in rest {
            if DoitSubjectNote.isHangul(ch) || ch == "?" || ch == "," || ch == "\n" { break }
            out.append(ch)
        }
        let e = out.trimmingCharacters(in: .whitespaces)
        return e.contains("=") ? e : nil
    }

    private static func pointText(_ x: Double, _ y: Double) -> String? {
        guard let a = show(x), let b = show(y) else { return nil }
        return "(\(a), \(b))"
    }

    static func conic(_ t: String) -> Solved? {
        if let s = parabola(t) { return s }
        for name in ["타원", "쌍곡선"] where t.contains(name) {
            guard let e = conicEquation(t, name), let c = quadraticCoefficients(e),
                  abs(c["xy"]!) < 1e-12, abs(c["x"]!) < 1e-12, abs(c["y"]!) < 1e-12 else { return nil }
            let A = c["xx"]!, B = c["yy"]!, F = c["1"]!
            guard A != 0, B != 0, F != 0 else { return nil }
            let p = -F / A, q = -F / B   // x²/p + y²/q = 1
            return name == "타원" ? ellipse(t, p, q, e) : hyperbola(t, p, q, e)
        }
        return nil
    }

    private static func parabola(_ t: String) -> Solved? {
        guard t.contains("포물선"), let e = conicEquation(t, "포물선"), let c = quadraticCoefficients(e),
              abs(c["xy"]!) < 1e-12, abs(c["1"]!) < 1e-12 else { return nil }
        var focus: (Double, Double), directrix: String, p: Double
        if abs(c["xx"]!) < 1e-12, c["yy"]! != 0, abs(c["y"]!) < 1e-12, c["x"]! != 0 {
            // y² = 4px
            p = -c["x"]! / c["yy"]! / 4
            focus = (p, 0)
            guard let d = show(-p) else { return nil }
            directrix = "x = \(d)"
        } else if abs(c["yy"]!) < 1e-12, c["xx"]! != 0, abs(c["x"]!) < 1e-12, c["y"]! != 0 {
            // x² = 4py
            p = -c["y"]! / c["xx"]! / 4
            focus = (0, p)
            guard let d = show(-p) else { return nil }
            directrix = "y = \(d)"
        } else { return nil }
        guard let f = pointText(focus.0, focus.1) else { return nil }
        let concept = "포물선 y² = 4px 의 초점은 (p, 0), 준선은 x = −p. x² = 4py 의 초점은 (0, p), 준선은 y = −p"
        let steps = [step("4p를 읽으면", "p = \(show(p) ?? "")"), step("초점, 준선", "\(f), \(directrix)")]
        if has(t, ["준선"]), !has(t, ["초점"]) { return Solved(kind: .coordinate, topic: "포물선", concept: concept, steps: steps, answer: directrix) }
        if has(t, ["초점"]), has(t, ["준선"]), has(t, ["거리"]), let d = show(2 * abs(p)) { return Solved(kind: .coordinate, topic: "포물선", concept: concept, steps: steps, answer: d) }
        if has(t, ["초점"]), !has(t, ["준선", "거리"]) { return Solved(kind: .coordinate, topic: "포물선", concept: concept, steps: steps, answer: f) }
        return nil
    }

    private static func ellipse(_ t: String, _ p: Double, _ q: Double, _ e: String) -> Solved? {
        guard p > 0, q > 0, abs(p - q) > 1e-12 else { return nil }
        let alongX = p > q
        let a = max(p, q).squareRoot(), b = min(p, q).squareRoot(), c = (max(p, q) - min(p, q)).squareRoot()
        let concept = "타원 x²/a² + y²/b² = 1 (a > b > 0)의 초점은 (±c, 0), c² = a² − b², 장축의 길이 2a, 단축의 길이 2b. 타원 위의 점에서 두 초점까지 거리의 합은 2a"
        guard let cs = show(c), let mc = show(-c) else { return nil }
        let foci = alongX ? "(\(cs), 0), (\(mc), 0)" : "(0, \(cs)), (0, \(mc))"
        var steps = [step("타원", e), step("c² = a² − b²", "c = \(cs)")]
        var answer: String?
        if has(t, ["장축의 길이"]) { answer = show(2 * a) }
        else if has(t, ["단축의 길이"]) { answer = show(2 * b) }
        else if has(t, ["두 초점 사이의 거리", "두 초점 사이 거리"]) { answer = show(2 * c) }
        else if has(t, ["PF", "거리의 합"]), t.range(of: #"PF\s*'?\s*\+\s*PF|거리의\s*합"#, options: .regularExpression) != nil { answer = show(2 * a); steps.append(step("타원의 정의", "PF + PF' = 2a")) }
        else if has(t, ["초점의 좌표", "초점은", "초점을 구"]) { answer = foci }
        guard let ans = answer else { return nil }
        return Solved(kind: .coordinate, topic: "타원", concept: concept, steps: steps, answer: ans)
    }

    private static func hyperbola(_ t: String, _ p: Double, _ q: Double, _ e: String) -> Solved? {
        guard (p > 0) != (q > 0) else { return nil }
        let alongX = p > 0
        let a2 = alongX ? p : q, b2 = alongX ? -q : -p
        let a = a2.squareRoot(), c = (a2 + b2).squareRoot()
        let concept = "쌍곡선 x²/a² − y²/b² = 1 의 초점은 (±c, 0), c² = a² + b², 점근선 y = ±(b/a)x, 주축의 길이 2a. 쌍곡선 위의 점에서 두 초점까지 거리의 차는 2a"
        guard let cs = show(c), let mc = show(-c) else { return nil }
        let foci = alongX ? "(\(cs), 0), (\(mc), 0)" : "(0, \(cs)), (0, \(mc))"
        // 점근선 기울기 √(q/p) 꼴: x²/p + y²/q = 1 에서 y = ±√(−q/p) x
        let slope = (-q / p).squareRoot()
        var steps = [step("쌍곡선", e), step("c² = a² + b²", "c = \(cs)")]
        var answer: String?
        if has(t, ["점근선"]) {
            guard let s = show(slope) else { return nil }
            let k = s.contains("/") ? "(\(s))" : s == "1" ? "" : s
            answer = "y = ±\(k)x"
        } else if has(t, ["주축의 길이"]) { answer = show(2 * a) }
        else if has(t, ["두 초점 사이의 거리"]) { answer = show(2 * c) }
        else if has(t, ["거리의 차"]) || t.range(of: #"\|\s*PF\s*-\s*PF\s*'\s*\|"#, options: .regularExpression) != nil { answer = show(2 * a); steps.append(step("쌍곡선의 정의", "|PF − PF'| = 2a")) }
        else if has(t, ["초점의 좌표", "초점은", "초점을 구"]) { answer = foci }
        guard let ans = answer else { return nil }
        return Solved(kind: .coordinate, topic: "쌍곡선", concept: concept, steps: steps, answer: ans)
    }

    // MARK: - 벡터 (크기 · 내적 · 이루는 각)

    /// 각도 이름 (cos 값이 특수각일 때만)
    private static func angleName(_ cosine: Double) -> String? {
        for (deg, rad) in [(0, "0"), (30, "π/6"), (45, "π/4"), (60, "π/3"), (90, "π/2"), (120, "2π/3"), (135, "3π/4"), (150, "5π/6"), (180, "π")] {
            if abs(cos(Double(deg) * .pi / 180) - cosine) < 1e-9 { return "\(deg)° (\(rad))" }
        }
        return nil
    }

    /// 벡터 문자 (a, b, u, v, p, q)와 그 뒤의 화살표 기호를 지운 글
    private static func vectorText(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\u{20D7}", with: "").replacingOccurrences(of: "⃗", with: "")
            .replacingOccurrences(of: "→", with: "").replacingOccurrences(of: "·", with: "∙").replacingOccurrences(of: "⋅", with: "∙").replacingOccurrences(of: "*", with: "∙")
    }

    /// "2a − 3b" → (2, −3)
    private static func combination(_ s: String) -> (Double, Double)? {
        let t = s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "−", with: "-")
        guard !t.isEmpty, t.allSatisfy({ "0123456789./+-ab".contains($0) }) else { return nil }
        var p = 0.0, q = 0.0, current = "", sign = 1.0
        var sawLetter = false
        func flush(_ letter: Character) -> Bool {
            let k: Double
            if current.isEmpty { k = 1 } else if let v = DoitMathHigh.number(current) { k = v } else { return false }
            if letter == "a" { p += sign * k } else { q += sign * k }
            current = ""
            sawLetter = true
            return true
        }
        for ch in t {
            if ch == "+" || ch == "-" {
                guard current.isEmpty else { return nil }
                sign = ch == "-" ? -1 : 1
            } else if ch == "a" || ch == "b" { guard flush(ch) else { return nil } }
            else { current.append(ch) }
        }
        guard current.isEmpty, sawLetter else { return nil }
        return (p, q)
    }

    static func vectorGram(_ raw: String) -> Solved? {
        guard has(raw, ["벡터"]) || raw.contains("|a") else { return nil }
        let t = vectorText(raw)
        // 성분이 주어진 벡터는 다른 풀이로
        if t.range(of: #"[ab]\s*=\s*\("#, options: .regularExpression) != nil { return nil }
        var aa: Double?, bb: Double?, ab: Double?, angle: Double?
        var steps: [SolutionStep] = []
        if let m = match(t, #"\|\s*a\s*\|\s*=\s*("# + num + #"|√\d+|\d*√\d+)"#), let v = DoitMathHigh.number(m[1]) { aa = v * v }
        if let m = match(t, #"\|\s*b\s*\|\s*=\s*("# + num + #"|√\d+|\d*√\d+)"#), let v = DoitMathHigh.number(m[1]) { bb = v * v }
        if let m = match(t, #"a\s*∙\s*b\s*=\s*("# + num + ")"), let v = DoitMathHigh.number(m[1]) { ab = v }
        if let m = match(t, #"이루는\s*각의\s*크기가\s*(\d+)\s*°"#), let d = Double(m[1]) { angle = d * .pi / 180 }
        else if let m = match(t, #"이루는\s*각의\s*크기가\s*(\d*π(?:/\d+)?)"#), let v = DoitMathHigh.number(m[1]) { angle = v }
        // |pa + qb| = v
        var norms: [((Double, Double), Double)] = []
        for m in matches(t, #"\|\s*([0-9./+\-ab\s]+?)\s*\|\s*=\s*("# + num + #"|√\d+|\d*√\d+)"#) {
            guard let c = combination(m[1]), let v = DoitMathHigh.number(m[2]) else { continue }
            if c == (1, 0) || c == (0, 1) { continue }
            norms.append((c, v * v))
        }
        guard aa != nil || bb != nil else { return nil }
        // 차례로 채우기
        for _ in 0..<3 {
            if ab == nil, let th = angle, let x = aa, let y = bb { ab = (x * y).squareRoot() * cos(th); steps.append(step("a∙b = |a||b|cos θ", show(ab!) ?? "")) }
            for ((p, q), v) in norms {
                // p²|a|² + 2pq a∙b + q²|b|² = v
                if ab == nil, let x = aa, let y = bb, p * q != 0 { ab = (v - p * p * x - q * q * y) / (2 * p * q); steps.append(step("|\(DoitMath.format(p))a + \(DoitMath.format(q))b|² = \(DoitMath.format(p * p))|a|² + \(DoitMath.format(2 * p * q))a∙b + \(DoitMath.format(q * q))|b|²", "a∙b = \(show(ab!) ?? "")")) }
                else if bb == nil, let x = aa, let z = ab, q != 0 { bb = (v - p * p * x - 2 * p * q * z) / (q * q) }
                else if aa == nil, let y = bb, let z = ab, p != 0 { aa = (v - q * q * y - 2 * p * q * z) / (p * p) }
            }
        }
        let concept = "|a + b|² = |a|² + 2a∙b + |b|², a∙b = |a||b|cos θ. 크기는 제곱해서 내적으로 바꿔 계산해요."
        // 물은 것
        let tail = t.components(separatedBy: "일 때").last ?? t
        if let m = match(tail, #"\|\s*([0-9./+\-ab\s]+?)\s*\|\s*(?:의\s*값|값|은|는|을|를|\?)"#), let (p, q) = combination(m[1]), let x = aa, let y = bb, let z = ab {
            let sq = p * p * x + 2 * p * q * z + q * q * y
            guard sq >= -1e-12, let r = DoitMathExact.Surd.sqrt(DoitMathCalc.rat(max(0, sq)) ?? .zero), abs(r.value - max(0, sq).squareRoot()) < 1e-9 else { return nil }
            steps.append(step("|\(m[1].trimmingCharacters(in: .whitespaces))|²", "\(show(sq) ?? "") → \(r.text)"))
            return Solved(kind: .coordinate, topic: "벡터의 크기", concept: concept, steps: steps, answer: r.text)
        }
        if tail.range(of: #"a\s*∙\s*b\s*(?:의\s*값|값|은|는|\?)"#, options: .regularExpression) != nil, let z = ab, let s = show(z) {
            return Solved(kind: .coordinate, topic: "벡터의 내적", concept: concept, steps: steps, answer: s)
        }
        if has(tail, ["이루는 각"]), angle == nil, let x = aa, let y = bb, let z = ab, x > 0, y > 0, let name = angleName(z / (x * y).squareRoot()) {
            steps.append(step("cos θ = a∙b/(|a||b|)", show(z / (x * y).squareRoot()) ?? ""))
            return Solved(kind: .coordinate, topic: "두 벡터가 이루는 각", concept: concept, steps: steps, answer: name)
        }
        return nil
    }

    // MARK: - 성분으로 주어진 벡터

    /// 성분 하나: 수 또는 문자 k 하나에 대한 일차식 (c0 + c1·k)
    private static func component(_ s: String, _ letter: inout Character?) -> (Double, Double)? {
        let t = s.replacingOccurrences(of: " ", with: "")
        if let v = DoitMathHigh.number(t) { return (v, 0) }
        let letters = t.filter { $0.isLetter }
        guard letters.count == 1, let c = letters.first, c != "e", letter == nil || letter == c else { return nil }
        letter = c
        guard let n = DoitMathCalc.parse(t, variable: c), let v0 = n.eval(0), let v1 = n.eval(1), let v2 = n.eval(2), abs(v2 - 2 * v1 + v0) < 1e-12 else { return nil }
        return (v0, v1 - v0)
    }

    static func vectorComponents(_ raw: String) -> Solved? {
        guard has(raw, ["벡터"]) else { return nil }
        let t = vectorText(raw)
        var vectors: [Character: [(Double, Double)]] = [:]
        var letter: Character?
        for m in matches(t, #"(?<![A-Za-z])([a-z])\s*=\s*\(\s*([^()]+?)\s*\)"#) {
            guard let name = m[1].first, name != "x", name != "y" else { continue }
            let parts = m[2].split(separator: ",").map(String.init)
            guard parts.count == 2 || parts.count == 3 else { return nil }
            var comps: [(Double, Double)] = []
            for p in parts { guard let c = component(p, &letter) else { return nil }; comps.append(c) }
            vectors[name] = comps
        }
        guard vectors.count >= 1, let dim = vectors.values.first?.count, vectors.values.allSatisfy({ $0.count == dim }) else { return nil }
        let names = vectors.keys.sorted()
        let concept = "a = (a₁, a₂), b = (b₁, b₂) 이면 a ± b = (a₁ ± b₁, a₂ ± b₂), a∙b = a₁b₁ + a₂b₂, |a| = √(a₁² + a₂²). 수직이면 a∙b = 0, 평행이면 성분의 비가 같아요."
        func value(_ c: (Double, Double), _ k: Double) -> Double { c.0 + c.1 * k }
        // 상수 k: 수직 · 평행 조건
        if let k = letter {
            guard names.count == 2, let u = vectors[names[0]], let v = vectors[names[1]] else { return nil }
            var poly = [0.0, 0.0, 0.0]   // 상수, k, k²
            if has(t, ["수직"]) {
                for i in 0..<dim {
                    poly[0] += u[i].0 * v[i].0; poly[1] += u[i].0 * v[i].1 + u[i].1 * v[i].0; poly[2] += u[i].1 * v[i].1
                }
            } else if has(t, ["평행"]), dim == 2 {
                poly[0] = u[0].0 * v[1].0 - u[1].0 * v[0].0
                poly[1] = u[0].0 * v[1].1 + u[0].1 * v[1].0 - u[1].0 * v[0].1 - u[1].1 * v[0].0
                poly[2] = u[0].1 * v[1].1 - u[1].1 * v[0].1
            } else { return nil }
            guard abs(poly[2]) < 1e-12, abs(poly[1]) > 1e-12, t.range(of: "(?<![a-z])\(k)\\s*의\\s*값", options: .regularExpression) != nil else { return nil }
            let root = -poly[0] / poly[1]
            guard let s = show(root) else { return nil }
            return Solved(kind: .coordinate, topic: has(t, ["수직"]) ? "벡터의 수직 조건" : "벡터의 평행 조건", concept: concept,
                          steps: [step(has(t, ["수직"]) ? "수직이면 내적이 0" : "평행이면 성분의 비가 같아요", "\(k) = \(s)")], answer: s)
        }
        let vals: [Character: [Double]] = vectors.mapValues { $0.map { $0.0 } }
        func linear(_ s: String) -> [Double]? {
            // "2a − b" 꼴: a, b 대신 실제 이름(names[0], names[1])
            guard names.count <= 2 else { return nil }
            var mapped = s
            if names.count == 2 { mapped = String(s.map { $0 == names[0] ? "a" : $0 == names[1] ? "b" : $0 }) } else { mapped = String(s.map { $0 == names[0] ? "a" : $0 }) }
            guard let (p, q) = combination(mapped), let u = vals[names[0]] else { return nil }
            let w = names.count == 2 ? vals[names[1]]! : Array(repeating: 0.0, count: dim)
            if names.count == 1, q != 0 { return nil }
            return (0..<dim).map { p * u[$0] + q * w[$0] }
        }
        func vectorString(_ v: [Double]) -> String? {
            let parts = v.compactMap(show)
            return parts.count == v.count ? "(" + parts.joined(separator: ", ") + ")" : nil
        }
        let tail = t.components(separatedBy: "대하여").last ?? t
        // 내적
        if names.count == 2, tail.range(of: "\(names[0])\\s*∙\\s*\(names[1])", options: .regularExpression) != nil || has(tail, ["내적"]),
           let u = vals[names[0]], let v = vals[names[1]] {
            let d = zip(u, v).map { $0 * $1 }.reduce(0, +)
            guard let s = show(d) else { return nil }
            return Solved(kind: .coordinate, topic: "벡터의 내적", concept: concept, steps: [step("성분끼리 곱해 더하면", s)], answer: s)
        }
        // 이루는 각
        if names.count == 2, has(tail, ["이루는 각"]), let u = vals[names[0]], let v = vals[names[1]] {
            let d = zip(u, v).map { $0 * $1 }.reduce(0, +)
            let nu = u.map { $0 * $0 }.reduce(0, +).squareRoot(), nv = v.map { $0 * $0 }.reduce(0, +).squareRoot()
            guard nu > 0, nv > 0, let name = angleName(d / (nu * nv)) else { return nil }
            return Solved(kind: .coordinate, topic: "두 벡터가 이루는 각", concept: concept, steps: [step("cos θ = a∙b/(|a||b|)", show(d / (nu * nv)) ?? ""), step("θ", name)], answer: name)
        }
        // 크기 |…|
        if let m = match(tail, #"\|\s*([0-9a-z./+\-\s]+?)\s*\|"#), let v = linear(m[1]) {
            let sq = v.map { $0 * $0 }.reduce(0, +)
            guard let r = DoitMathCalc.rat(sq).flatMap(DoitMathExact.Surd.sqrt) else { return nil }
            return Solved(kind: .coordinate, topic: "벡터의 크기", concept: concept, steps: [step("성분", vectorString(v) ?? ""), step("크기 √(제곱의 합)", r.text)], answer: r.text)
        }
        if has(tail, ["크기"]), names.count == 1, let u = vals[names[0]] {
            let sq = u.map { $0 * $0 }.reduce(0, +)
            guard let r = DoitMathCalc.rat(sq).flatMap(DoitMathExact.Surd.sqrt) else { return nil }
            return Solved(kind: .coordinate, topic: "벡터의 크기", concept: concept, steps: [step("크기 √(제곱의 합)", r.text)], answer: r.text)
        }
        // 성분 "2a − b의 성분", "벡터 a + b"
        if has(tail, ["성분", "벡터"]), let m = match(tail, #"([0-9./]*\s*[a-z](?:\s*[+\-]\s*[0-9./]*\s*[a-z])+)\s*(?:의\s*성분|를|을|은|는|\?)"#), let v = linear(m[1]), let s = vectorString(v) {
            return Solved(kind: .coordinate, topic: "벡터의 성분", concept: concept, steps: [step("성분끼리 계산하면", s)], answer: s)
        }
        return nil
    }

    // MARK: - 좌표공간

    private static func points3(_ t: String) -> [Character: [Double]] {
        var out: [Character: [Double]] = [:]
        for m in matches(t, #"(?<![A-Za-z])([A-Z])\s*\(\s*("# + num + #")\s*,\s*("# + num + #")\s*,\s*("# + num + #")\s*\)"#) {
            guard let name = m[1].first, let x = DoitMathHigh.number(m[2]), let y = DoitMathHigh.number(m[3]), let z = DoitMathHigh.number(m[4]) else { continue }
            out[name] = [x, y, z]
        }
        return out
    }

    static func space(_ t: String) -> Solved? {
        let pts = points3(t)
        guard !pts.isEmpty else { return nil }
        func text(_ p: [Double]) -> String? {
            let parts = p.compactMap(show)
            return parts.count == 3 ? "(" + parts.joined(separator: ", ") + ")" : nil
        }
        let concept = "좌표공간에서 두 점 A(x₁, y₁, z₁), B(x₂, y₂, z₂) 사이의 거리는 √((x₂ − x₁)² + (y₂ − y₁)² + (z₂ − z₁)²), m : n으로 내분하는 점은 ((mx₂ + nx₁)/(m + n), …)"
        let names = pts.keys.sorted()
        // 대칭인 점
        if names.count == 1, let p = pts[names[0]], has(t, ["대칭"]) {
            var q = p
            if has(t, ["xy평면"]) { q[2] = -p[2] } else if has(t, ["yz평면"]) { q[0] = -p[0] } else if has(t, ["zx평면", "xz평면"]) { q[1] = -p[1] }
            else if has(t, ["원점"]) { q = p.map { -$0 } } else if has(t, ["x축"]) { q[1] = -p[1]; q[2] = -p[2] }
            else if has(t, ["y축"]) { q[0] = -p[0]; q[2] = -p[2] } else if has(t, ["z축"]) { q[0] = -p[0]; q[1] = -p[1] } else { return nil }
            guard let s = text(q) else { return nil }
            return Solved(kind: .coordinate, topic: "좌표공간의 대칭이동", concept: "xy평면에 대칭이면 z의 부호, x축에 대칭이면 y, z의 부호, 원점에 대칭이면 모든 부호가 바뀌어요.", steps: [step("부호를 바꾸면", s)], answer: s)
        }
        if names.count == 1, let p = pts[names[0]], has(t, ["원점"]), has(t, ["거리"]) {
            let d2 = p.map { $0 * $0 }.reduce(0, +)
            guard let r = DoitMathCalc.rat(d2).flatMap(DoitMathExact.Surd.sqrt) else { return nil }
            return Solved(kind: .coordinate, topic: "좌표공간의 거리", concept: concept, steps: [step("√(x² + y² + z²)", r.text)], answer: r.text)
        }
        if names.count == 3, has(t, ["무게중심"]) {
            let g = (0..<3).map { i in names.map { pts[$0]![i] }.reduce(0, +) / 3 }
            guard let s = text(g) else { return nil }
            return Solved(kind: .coordinate, topic: "삼각형의 무게중심", concept: "세 꼭짓점 좌표의 평균이 무게중심이에요.", steps: [step("각 좌표의 평균", s)], answer: s)
        }
        guard names.count == 2, let a = pts[names[0]], let b = pts[names[1]] else { return nil }
        if has(t, ["중점"]) {
            guard let s = text((0..<3).map { (a[$0] + b[$0]) / 2 }) else { return nil }
            return Solved(kind: .coordinate, topic: "선분의 중점", concept: concept, steps: [step("좌표끼리 더해 2로 나누면", s)], answer: s)
        }
        if let m = match(t, #"(\d+)\s*:\s*(\d+)\s*(?:로|으로)\s*내분"#), let p = Double(m[1]), let q = Double(m[2]), p + q > 0 {
            // 선분 AB를 m : n으로 내분 (앞 글자가 처음 점)
            let first = t.range(of: "\(names[0])\\s*\\(", options: .regularExpression).map(\.lowerBound)
            let second = t.range(of: "\(names[1])\\s*\\(", options: .regularExpression).map(\.lowerBound)
            guard let f = first, let s2 = second, f < s2, t.contains("선분 \(names[0])\(names[1])") || !t.contains("선분") else { return nil }
            guard let s = text((0..<3).map { (p * b[$0] + q * a[$0]) / (p + q) }) else { return nil }
            return Solved(kind: .coordinate, topic: "선분의 내분점", concept: concept, steps: [step("(mx₂ + nx₁)/(m + n) 꼴로", s)], answer: s)
        }
        if has(t, ["거리", "길이"]) {
            let d2 = (0..<3).map { (a[$0] - b[$0]) * (a[$0] - b[$0]) }.reduce(0, +)
            guard let r = DoitMathCalc.rat(d2).flatMap(DoitMathExact.Surd.sqrt) else { return nil }
            return Solved(kind: .coordinate, topic: "좌표공간의 두 점 사이의 거리", concept: concept, steps: [step("좌표의 차를 제곱해 더하면", "\(DoitMath.format(d2)) → √\(DoitMath.format(d2)) = \(r.text)")], answer: r.text)
        }
        return nil
    }

    // MARK: - 구

    static func sphere(_ t: String) -> Solved? {
        guard t.contains("구"), t.contains("z"), let r = t.range(of: #"(?<![가-힣])구\s*(?=[x(])"#, options: .regularExpression) else { return nil }
        var e = ""
        for ch in t[r.upperBound...] {
            if DoitSubjectNote.isHangul(ch) || ch == "?" || ch == "," || ch == "\n" { break }
            e.append(ch)
        }
        let sides = e.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard sides.count == 2, let l = DoitAlgebra.parse(sides[0]), let rr = DoitAlgebra.parse(sides[1]) else { return nil }
        let p = l - rr
        let a = p.coef(x: 2)
        guard a != 0, p.coef(y: 2) == a, p.coef(z: 2) == a, p.degree == 2,
              p.coef(x: 1, y: 1) == 0, p.coef(y: 1, z: 1) == 0, p.coef(x: 1, z: 1) == 0 else { return nil }
        let cx = -p.coef(x: 1) / (2 * a), cy = -p.coef(y: 1) / (2 * a), cz = -p.coef(z: 1) / (2 * a)
        let r2 = cx * cx + cy * cy + cz * cz - p.constantValue / a
        let center = [cx, cy, cz].compactMap(show)
        guard r2 > 0, center.count == 3, let radius = DoitMathCalc.rat(r2).flatMap(DoitMathExact.Surd.sqrt) else { return nil }
        let c = "(" + center.joined(separator: ", ") + ")"
        let concept = "x² + y² + z² + Ax + By + Cz + D = 0 을 (x − a)² + (y − b)² + (z − c)² = r² 꼴로 고치면 중심 (a, b, c), 반지름 r"
        let steps = [step("완전제곱식으로 고치면", "중심 \(c), r² = \(DoitMath.format(r2))")]
        if has(t, ["반지름"]), !has(t, ["중심"]) { return Solved(kind: .circle, topic: "구의 방정식", concept: concept, steps: steps, answer: radius.text) }
        if has(t, ["중심"]), !has(t, ["반지름"]) { return Solved(kind: .circle, topic: "구의 방정식", concept: concept, steps: steps, answer: c) }
        return Solved(kind: .circle, topic: "구의 방정식", concept: concept, steps: steps, answer: "중심 \(c), 반지름 \(radius.text)")
    }
}
