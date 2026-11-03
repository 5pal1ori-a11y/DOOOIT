import Foundation

/// 모티 AI 문장제 풀이 (교과서·문제집 문장 그대로, 외부 AI 없이)
/// 확률·경우의 수, 속력, 농도, 할인·이익, 나이·연속하는 수·개수·다리 수, 비례배분,
/// 배수의 개수, 다각형의 각, 평균의 미지수, 두 항으로 정하는 수열, 집합의 연산, 넓이에서 길이
/// 문장의 모양이 확실할 때만 풀고, 애매하면 nil (틀린 답보다 '못 풀어요'가 나아요)
enum DoitMathWord {
    typealias Solved = MathSolver.Solved
    typealias Rat = DoitMathExact.Rat

    private static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }
    private static func f(_ v: Double) -> String { DoitMath.fraction(v) }
    private static func d(_ v: Double) -> String { DoitMath.format(v, digits: 8) }
    private static func match(_ t: String, _ p: String) -> [String]? { DoitMathExact.match(t, p) }
    private static func matches(_ t: String, _ p: String) -> [[String]] { DoitMathExact.matches(t, p) }

    static let koreanCount: [String: Int] = ["한": 1, "두": 2, "세": 3, "네": 4, "다섯": 5, "여섯": 6, "일곱": 7, "여덟": 8, "아홉": 9, "열": 10]
    static let countWord = #"(\d+|한|두|세|네|다섯|여섯|일곱|여덟|아홉|열)"#
    static func count(_ s: String) -> Int? { Int(s.trimmingCharacters(in: .whitespaces)) ?? koreanCount[s.trimmingCharacters(in: .whitespaces)] }

    /// 1,000 같은 천 단위 쉼표 없애기 (돈·거리 문제에서만)
    private static func noThousands(_ t: String) -> String {
        t.replacingOccurrences(of: #"(\d),(\d{3})(?!\d)"#, with: "$1$2", options: .regularExpression)
    }

    /// 기약분수 글자
    private static func ratio(_ n: Int, _ total: Int) -> String {
        guard let r = Rat(n, total) else { return "\(n)/\(total)" }
        return r.text
    }

    static func solve(_ t: String) -> Solved? {
        if let s = explicitSets(t) { return s }
        if let s = probability(t) { return s }
        if let s = diceEvent(t, probability: false) { return s }
        if let s = coinDiceTotal(t) { return s }
        if let s = groupSelection(t) { return s }
        if let s = digitCards(t) { return s }
        if let s = speed(t) { return s }
        if let s = concentration(t) { return s }
        if let s = money(t) { return s }
        if let s = partPercent(t) { return s }
        if let s = age(t) { return s }
        if let s = consecutive(t) { return s }
        if let s = priceCount(t) { return s }
        if let s = legs(t) { return s }
        if let s = sumDifference(t) { return s }
        if let s = simplestRatio(t) { return s }
        if let s = ratioDivision(t) { return s }
        if let s = multiplesCount(t) { return s }
        if let s = gcdLcmProduct(t) { return s }
        if let s = squareMultiplier(t) { return s }
        if let s = roundRobin(t) { return s }
        if let s = angleRatio(t) { return s }
        if let s = deviationUnknown(t) { return s }
        if let s = someNumber(t) { return s }
        if let s = polygonFromAngle(t) { return s }
        if let s = missingAngle(t) { return s }
        if let s = meanUnknown(t) { return s }
        if let s = twoTermSequence(t) { return s }
        if let s = lineFromSlopeIntercept(t) { return s }
        if let s = inverseGeometry(t) { return s }
        return nil
    }

    // MARK: - 집합 (원소를 나열한 집합)

    private static func elements(_ s: String) -> [String] {
        var out: [String] = []
        for part in s.split(separator: ",") {
            let e = part.trimmingCharacters(in: .whitespaces)
            if !e.isEmpty && !out.contains(e) { out.append(e) }
        }
        return out
    }

    private static func setText(_ items: [String]) -> String {
        guard !items.isEmpty else { return "∅ (공집합)" }
        let numeric = items.compactMap { Double($0) }
        let sorted = numeric.count == items.count ? items.sorted { (Double($0) ?? 0) < (Double($1) ?? 0) } : items
        return "{" + sorted.joined(separator: ", ") + "}"
    }

    static func explicitSets(_ t: String) -> Solved? {
        var named: [String: [String]] = [:]
        for m in matches(t, #"([A-Z])\s*=\s*\{([^{}]*)\}"#) {
            guard !m[2].contains("|") else { return nil }
            named[m[1]] = elements(m[2])
        }
        if named.isEmpty, has(t, ["부분집합", "원소"]), let m = match(t, #"\{([^{}|]*)\}"#) { named["S"] = elements(m[1]) }
        guard !named.isEmpty else { return nil }
        let concept = "A ∪ B: A 또는 B에 속하는 원소, A ∩ B: A와 B 모두에 속하는 원소, A − B: A에만 속하는 원소, Aᶜ = U − A. 원소가 n개인 집합의 부분집합은 2ⁿ개예요."
        var steps = named.keys.sorted().filter { $0 != "S" }.compactMap { k in named[k].map { SolutionStep(hint: "집합 \(k)", work: setText($0)) } }
        func apply(_ a: [String], _ op: String, _ b: [String]) -> [String] {
            switch op {
            case "∪": return a + b.filter { !a.contains($0) }
            case "∩": return a.filter { b.contains($0) }
            default: return a.filter { !b.contains($0) }
            }
        }
        // n(A ∩ B), A ∪ B, A − B
        if let m = match(t, #"(n\s*\(\s*)?([A-Z])\s*(∪|∩|-|\\)\s*([A-Z])"#), let a = named[m[2]], let b = named[m[4]] {
            let op = m[3] == "\\" ? "-" : m[3]
            let result = apply(a, op, b)
            let label = "\(m[2]) \(op == "-" ? "−" : op) \(m[4])"
            steps.append(SolutionStep(hint: op == "∪" ? "두 집합의 원소를 모두 모으면 (겹치는 것은 한 번만)" : op == "∩" ? "두 집합에 공통으로 있는 원소는" : "\(m[2])에만 있는 원소는",
                                      work: "\(label) = \(setText(result))"))
            if !m[1].isEmpty {
                return Solved(kind: .sets, topic: "집합의 연산과 원소의 개수", concept: concept, steps: steps, answer: "n(\(label)) = \(result.count)")
            }
            return Solved(kind: .sets, topic: "집합의 연산", concept: concept, steps: steps, answer: "\(label) = \(setText(result))")
        }
        // 여집합
        if let m = match(t, #"([A-Z])\s*(?:\^\s*[cC]|ᶜ|의\s*여집합)"#), let u = named["U"], let a = named[m[1]] {
            let result = u.filter { !a.contains($0) }
            steps.append(SolutionStep(hint: "전체집합 U에서 \(m[1])의 원소를 빼면", work: setText(result)))
            return Solved(kind: .sets, topic: "여집합", concept: concept, steps: steps, answer: "\(m[1])ᶜ = \(setText(result))")
        }
        // 부분집합의 개수
        if has(t, ["부분집합"]) && has(t, ["개수", "몇 개"]) {
            let key = match(t, #"집합\s*([A-Z])\s*의\s*(?:진)?부분집합"#)?[1] ?? (named.count == 1 ? named.keys.first! : "")
            guard let set = named[key], set.count <= 20 else { return nil }
            let n = set.count
            let total = 1 << n
            let proper = has(t, ["진부분집합"])
            steps.append(SolutionStep(hint: "원소가 \(n)개이면 각 원소를 넣거나 빼는 2가지씩", work: "2^\(n) = \(total)"))
            if proper { steps.append(SolutionStep(hint: "진부분집합은 자기 자신을 빼요", work: "\(total) − 1 = \(total - 1)")) }
            return Solved(kind: .sets, topic: proper ? "진부분집합의 개수" : "부분집합의 개수", concept: concept, steps: steps, answer: "\(proper ? total - 1 : total)개")
        }
        // n(A)
        if let m = match(t, #"n\s*\(\s*([A-Z])\s*\)"#), let a = named[m[1]], !t.contains("n(\(m[1]))=") && !t.contains("n(\(m[1])) =") {
            steps.append(SolutionStep(hint: "원소를 세면", work: setText(a)))
            return Solved(kind: .sets, topic: "원소의 개수", concept: concept, steps: steps, answer: "n(\(m[1])) = \(a.count)")
        }
        return nil
    }

    // MARK: - 확률

    static func probability(_ t: String) -> Solved? {
        guard has(t, ["확률"]) else { return nil }
        if let s = coinProbability(t) { return s }
        if let s = diceEvent(t, probability: true) { return s }
        if let s = balls(t) { return s }
        return nil
    }

    private static func coinProbability(_ t: String) -> Solved? {
        guard has(t, ["동전"]), !has(t, ["주사위"]) else { return nil }
        var n: Int?
        if let m = match(t, countWord + #"\s*(?:번|회)\s*던"#) { n = count(m[1]) }
        else if let m = match(t, #"동전\s*"# + countWord + #"\s*개"#) ?? match(t, countWord + #"\s*개의\s*동전"#) { n = count(m[1]) }
        guard let tosses = n, (1...10).contains(tosses) else { return nil }
        let total = 1 << tosses
        let concept = "동전 n번 → 모든 경우 2ⁿ가지. 앞면이 k번 나오는 경우는 ₙCₖ가지. 확률 = (그 사건의 경우의 수) ÷ (모든 경우의 수)"
        var steps = [SolutionStep(hint: "모든 경우의 수", work: "2^\(tosses) = \(total)")]
        if has(t, ["적어도"]) {
            guard has(t, ["앞면", "뒷면"]), has(t, ["한 번", "한 개", "1번", "1개"]) else { return nil }
            steps.append(SolutionStep(hint: "적어도 한 번 = 1 − (한 번도 안 나올 확률)", work: "1 − 1/\(total)"))
            return Solved(kind: .counting, topic: "확률 (적어도)", concept: concept, steps: steps, answer: ratio(total - 1, total))
        }
        var k: Int?
        if let m = match(t, #"(?:앞면|뒷면)(?:이|만)\s*"# + countWord + #"\s*(?:번|개|회)"#) { k = count(m[1]) }
        else if has(t, ["모두 앞면", "모두 뒷면"]) { k = tosses }
        guard let heads = k, heads <= tosses else { return nil }
        let ways = Int(DoitMathTopics.combination(tosses, heads))
        steps.append(SolutionStep(hint: "\(tosses)번 중 \(heads)번을 고르는 경우", work: "₍\(tosses)₎C₍\(heads)₎ = \(ways)"))
        steps.append(SolutionStep(hint: "확률 = \(ways) ÷ \(total)", work: ratio(ways, total)))
        return Solved(kind: .counting, topic: "동전 던지기의 확률", concept: concept, steps: steps, answer: ratio(ways, total))
    }

    /// 주사위 눈 조건: (눈 목록) → 참/거짓
    private static func faceCondition(_ t: String) -> ((Int) -> Bool, String)? {
        var found: [((Int) -> Bool, String)] = []
        if let m = match(t, #"(\d+)\s*의\s*배수"#), let k = Int(m[1]), k > 0 { found.append(({ $0 % k == 0 }, "\(k)의 배수")) }
        if let m = match(t, #"(\d+)\s*의\s*약수"#), let k = Int(m[1]), k > 0 { found.append(({ k % $0 == 0 }, "\(k)의 약수")) }
        if has(t, ["짝수"]) { found.append(({ $0 % 2 == 0 }, "짝수")) }
        if has(t, ["홀수"]) { found.append(({ $0 % 2 == 1 }, "홀수")) }
        if has(t, ["소수"]) { found.append(({ [2, 3, 5].contains($0) }, "소수")) }
        if let m = match(t, #"(\d+)\s*이상"#), let k = Int(m[1]) { found.append(({ $0 >= k }, "\(k) 이상")) }
        if let m = match(t, #"(\d+)\s*이하"#), let k = Int(m[1]) { found.append(({ $0 <= k }, "\(k) 이하")) }
        if let m = match(t, #"(\d+)\s*(?:보다\s*큰|초과)"#), let k = Int(m[1]) { found.append(({ $0 > k }, "\(k)보다 큰 수")) }
        if let m = match(t, #"(\d+)\s*(?:보다\s*작은|미만)"#), let k = Int(m[1]) { found.append(({ $0 < k }, "\(k)보다 작은 수")) }
        if found.isEmpty, let m = match(t, #"(\d+)\s*의\s*눈|눈의\s*수가\s*(\d+)\s*(?:인|일|이)"#), let k = Int(m[1].isEmpty ? m[2] : m[1]) {
            found.append(({ $0 == k }, "\(k)"))
        }
        return found.count == 1 ? found[0] : nil
    }

    /// 두 수(또는 세 수)의 합·차·곱 조건
    private static func aggregateCondition(_ t: String) -> (([Int]) -> Bool, String)? {
        if has(t, ["같은 눈", "같은 수", "눈의 수가 같", "눈이 같"]) { return ({ Set($0).count == 1 }, "같은 눈") }
        if has(t, ["서로 다른 눈", "눈의 수가 서로 다른", "다른 눈이"]) { return ({ Set($0).count == $0.count }, "서로 다른 눈") }
        guard let m = match(t, #"(합|차|곱)(?:이|가|은|는)\s*(\d+)\s*(인|일|이 되는|이 될|이상|이하|보다\s*큰|보다\s*작은|초과|미만|의\s*배수|의\s*약수)?"#),
              let k = Int(m[2]) else { return nil }
        let kind = m[1], relation = m[3].replacingOccurrences(of: " ", with: "")
        let value: ([Int]) -> Int
        switch kind {
        case "합": value = { $0.reduce(0, +) }
        case "곱": value = { $0.reduce(1, *) }
        default: value = { ($0.max() ?? 0) - ($0.min() ?? 0) }
        }
        let label = "두 눈의 수의 \(kind)\(kind == "차" ? "가" : "이") \(k)\(relation.isEmpty || relation == "인" || relation == "일" ? "" : " " + m[3])"
        switch relation {
        case "이상": return ({ value($0) >= k }, label)
        case "이하": return ({ value($0) <= k }, label)
        case "보다큰", "초과": return ({ value($0) > k }, label)
        case "보다작은", "미만": return ({ value($0) < k }, label)
        case "의배수": return ({ k > 0 && value($0) % k == 0 }, label)
        case "의약수": return ({ value($0) != 0 && k % value($0) == 0 }, label)
        default:
            return ({ value($0) == k }, label)
        }
    }

    private static func diceCount(_ t: String) -> Int? {
        if let m = match(t, #"주사위\s*"# + countWord + #"\s*개"#) ?? match(t, countWord + #"\s*개의\s*주사위"#) { return count(m[1]) }
        if has(t, ["주사위"]) && !has(t, ["주사위 두", "두 주사위", "주사위 2", "주사위 세"]) && has(t, ["주사위를 한 번", "주사위 하나", "주사위를 던질", "주사위를 1번", "주사위를 한번"]) { return 1 }
        if has(t, ["두 주사위", "주사위 두"]) { return 2 }
        return nil
    }

    /// 주사위의 눈: 경우의 수 또는 확률
    static func diceEvent(_ t: String, probability: Bool) -> Solved? {
        guard has(t, ["주사위"]), !has(t, ["동전", "윷", "카드"]) else { return nil }
        guard probability || has(t, ["경우의 수", "가지 수", "몇 가지", "방법의 수"]) else { return nil }
        guard let n = diceCount(t), (1...3).contains(n) else { return nil }
        // 눈 조건 부분 ("던질 때," 뒤)
        let tail = t.components(separatedBy: "던질 때").last ?? t
        var outcomes: [[Int]] = [[]]
        for _ in 0..<n { outcomes = outcomes.flatMap { o in (1...6).map { o + [$0] } } }
        let total = outcomes.count
        var hits: [[Int]] = []
        var label = ""
        if n == 1 {
            guard let (test, name) = faceCondition(tail) else { return nil }
            hits = outcomes.filter { test($0[0]) }
            label = "눈이 \(name)"
        } else {
            guard let (test, name) = aggregateCondition(tail) else { return nil }
            hits = outcomes.filter(test)
            label = name
        }
        let listed = hits.count <= 12 ? hits.map { $0.count == 1 ? String($0[0]) : "(" + $0.map(String.init).joined(separator: ", ") + ")" }.joined(separator: ", ") : "\(hits.count)가지"
        var steps = [SolutionStep(hint: "모든 경우의 수", work: n == 1 ? "6" : "6^\(n) = \(total)"),
                     SolutionStep(hint: "\(label)인 경우를 모두 찾으면", work: listed.isEmpty ? "없어요" : listed)]
        if probability {
            steps.append(SolutionStep(hint: "확률 = (사건의 경우의 수) ÷ (모든 경우의 수)", work: "\(hits.count) ÷ \(total) = \(ratio(hits.count, total))"))
            return Solved(kind: .counting, topic: "주사위의 확률", concept: "확률 = (어떤 사건이 일어나는 경우의 수) ÷ (모든 경우의 수). 주사위 n개를 던지면 모든 경우는 6ⁿ가지예요.",
                          steps: steps, answer: ratio(hits.count, total))
        }
        return Solved(kind: .counting, topic: "주사위의 경우의 수", concept: "서로 다른 주사위는 (첫째 눈, 둘째 눈) 순서쌍으로 세요. 두 개를 던지면 모든 경우는 36가지예요.",
                      steps: steps, answer: "\(hits.count)")
    }

    /// 동전 a개, 주사위 b개를 던질 때 모든 경우의 수
    static func coinDiceTotal(_ t: String) -> Solved? {
        guard has(t, ["동전", "주사위"]), has(t, ["경우의 수", "가지"]), has(t, ["모든", "일어나는"]) else { return nil }
        guard !has(t, ["합", "차가", "곱", "배수", "약수", "앞면", "뒷면", "짝수", "홀수", "소수", "이상", "이하", "같은", "다른 눈"]) else { return nil }
        var coins = 0, dice = 0
        if let m = match(t, #"동전\s*"# + countWord + #"\s*개"#) ?? match(t, countWord + #"\s*개의\s*동전"#) { coins = count(m[1]) ?? 0 }
        else if has(t, ["동전"]) { coins = 1 }
        if let m = match(t, #"주사위\s*"# + countWord + #"\s*개"#) ?? match(t, countWord + #"\s*개의\s*주사위"#) { dice = count(m[1]) ?? 0 }
        else if has(t, ["주사위"]) { dice = 1 }
        guard coins + dice >= 1, coins <= 10, dice <= 5 else { return nil }
        var total = 1
        for _ in 0..<coins { total *= 2 }
        for _ in 0..<dice { total *= 6 }
        var factors: [String] = []
        if coins > 0 { factors.append(coins == 1 ? "2" : "2^\(coins)") }
        if dice > 0 { factors.append(dice == 1 ? "6" : "6^\(dice)") }
        return Solved(kind: .counting, topic: "곱의 법칙", concept: "동시에(잇달아) 일어나면 곱의 법칙: 동전 하나는 2가지, 주사위 하나는 6가지씩 곱해요.",
                      steps: [SolutionStep(hint: "동전 \(coins)개, 주사위 \(dice)개의 경우를 곱하면", work: factors.joined(separator: " × ") + " = \(total)")],
                      answer: "\(total)")
    }

    private static func balls(_ t: String) -> Solved? {
        guard has(t, ["공", "구슬"]), !has(t, ["다시 넣", "되돌려", "넣은 후", "넣고"]) else { return nil }
        var colors: [(String, Int)] = []
        // "공 1개를 꺼낼 때"의 공은 색깔이 아님
        for m in matches(t, #"([가-힣]+)\s*(?:공|구슬)\s*(\d+)\s*개(?!\s*(?:를|을))"#) {
            guard let c = Int(m[2]), !colors.contains(where: { $0.0 == m[1] }) else { continue }
            colors.append((m[1], c))
        }
        guard colors.count >= 2 else { return nil }
        let total = colors.reduce(0) { $0 + $1.1 }
        guard let dm = match(t, countWord + #"\s*개를\s*(?:동시에\s*|차례로\s*|연달아\s*|한꺼번에\s*)?(?:꺼낼|꺼내|뽑을|뽑)"#), let r = count(dm[1]), r >= 1, r <= total else { return nil }
        let tail = String(t[t.range(of: dm[0])!.upperBound...])
        let allWays = DoitMathTopics.combination(total, r)
        let concept = "확률 = (사건의 경우의 수) ÷ (모든 경우의 수). 동시에 r개를 꺼내면 모든 경우는 ₙCᵣ가지예요."
        var steps = [SolutionStep(hint: "공은 모두 \(total)개, \(r)개를 꺼내는 모든 경우", work: r == 1 ? "\(total)가지" : "₍\(total)₎C₍\(r)₎ = \(Int(allWays))")]
        let mentioned = colors.filter { tail.contains($0.0 + " 공") || tail.contains($0.0 + "공") || tail.contains($0.0 + " 구슬") }
        var ways: Double
        if has(tail, ["같은 색"]) {
            ways = colors.reduce(0) { $0 + DoitMathTopics.combination($1.1, r) }
            steps.append(SolutionStep(hint: "모두 같은 색인 경우를 색깔별로 더하면", work: colors.map { "₍\($0.1)₎C₍\(r)₎" }.joined(separator: " + ") + " = \(Int(ways))"))
        } else if has(tail, ["서로 다른 색", "다른 색"]), r == 2 {
            let same = colors.reduce(0) { $0 + DoitMathTopics.combination($1.1, 2) }
            ways = allWays - same
            steps.append(SolutionStep(hint: "전체에서 같은 색인 경우를 빼면", work: "\(Int(allWays)) − \(Int(same)) = \(Int(ways))"))
        } else if mentioned.count == 1 {
            let (name, c) = mentioned[0]
            if has(tail, ["적어도"]) {
                let none = DoitMathTopics.combination(total - c, r)
                ways = allWays - none
                steps.append(SolutionStep(hint: "적어도 한 개 = 전체 − (\(name) 공이 하나도 없는 경우)", work: "\(Int(allWays)) − \(Int(none)) = \(Int(ways))"))
            } else if r == 1 || has(tail, ["모두", "둘 다", "전부"]) {
                ways = DoitMathTopics.combination(c, r)
                steps.append(SolutionStep(hint: "\(name) 공 \(c)개 중에서 \(r)개", work: r == 1 ? "\(c)가지" : "₍\(c)₎C₍\(r)₎ = \(Int(ways))"))
            } else { return nil }
        } else if mentioned.count == 2, r == 2, !has(tail, ["모두", "적어도"]) {
            ways = Double(mentioned[0].1 * mentioned[1].1)
            steps.append(SolutionStep(hint: "\(mentioned[0].0) 공 1개, \(mentioned[1].0) 공 1개", work: "\(mentioned[0].1) × \(mentioned[1].1) = \(Int(ways))"))
        } else { return nil }
        let answer = ratio(Int(ways), Int(allWays))
        steps.append(SolutionStep(hint: "확률", work: "\(Int(ways)) ÷ \(Int(allWays)) = \(answer)"))
        return Solved(kind: .counting, topic: "공 꺼내기의 확률", concept: concept, steps: steps, answer: answer)
    }

    // MARK: - 경우의 수 (뽑기 · 숫자 카드)

    /// "남학생 4명, 여학생 3명 중에서 대표 2명"
    static func groupSelection(_ t: String) -> Solved? {
        guard let m = match(t, #"([가-힣]+)\s*(\d+)\s*명\s*(?:,|과|와|및)?\s*([가-힣]+)\s*(\d+)\s*명\s*(?:중|가운데)(?:에서)?"#),
              let a = Int(m[2]), let b = Int(m[4]), a + b <= 30 else { return nil }
        guard !has(t, ["적어도", "반드시", "포함", "만 뽑", "이웃", "일렬", "한 줄", "확률"]) else { return nil }
        let g1 = m[1], g2 = m[3]
        let tail = String(t[t.range(of: m[0])!.upperBound...])
        let concept = "순서 없이 뽑으면 조합 ₙCᵣ, 역할(순서)이 있으면 순열 ₙPᵣ. 두 무리에서 따로 뽑으면 곱의 법칙이에요."
        if let p = match(tail, g1 + #"\s*"# + countWord + #"\s*명\s*(?:,|과|와)?\s*"# + g2 + #"\s*"# + countWord + #"\s*명"#),
           let r1 = count(p[1]), let r2 = count(p[2]), r1 <= a, r2 <= b {
            let c1 = Int(DoitMathTopics.combination(a, r1)), c2 = Int(DoitMathTopics.combination(b, r2))
            return Solved(kind: .counting, topic: "조합과 곱의 법칙", concept: concept,
                          steps: [SolutionStep(hint: "\(g1) \(a)명 중 \(r1)명", work: "₍\(a)₎C₍\(r1)₎ = \(c1)"),
                                  SolutionStep(hint: "\(g2) \(b)명 중 \(r2)명", work: "₍\(b)₎C₍\(r2)₎ = \(c2)"),
                                  SolutionStep(hint: "동시에 일어나므로 곱하면", work: "\(c1) × \(c2) = \(c1 * c2)")],
                          answer: "\(c1 * c2)")
        }
        let roles = ["회장", "부회장", "총무", "서기", "반장", "부반장"].filter { tail.contains($0) }.count
        let n = a + b
        if roles >= 2, !tail.contains(g1), !tail.contains(g2) {
            let value = Int(DoitMathTopics.permutation(n, roles))
            return Solved(kind: .counting, topic: "순열", concept: concept,
                          steps: [SolutionStep(hint: "전체 \(a) + \(b) = \(n)명", work: "\(n)명"),
                                  SolutionStep(hint: "역할이 다르니 순서가 있어요", work: "₍\(n)₎P₍\(roles)₎ = \(value)")],
                          answer: "\(value)")
        }
        guard let p = match(tail, #"^\s*(?:대표\s*|위원\s*|당번\s*|선수\s*)?"# + countWord + #"\s*명"#), let r = count(p[1]), r <= n,
              !tail.contains(g1), !tail.contains(g2) else { return nil }
        let value = Int(DoitMathTopics.combination(n, r))
        return Solved(kind: .counting, topic: "조합", concept: concept,
                      steps: [SolutionStep(hint: "전체 \(a) + \(b) = \(n)명", work: "\(n)명"),
                              SolutionStep(hint: "순서 없이 \(r)명을 뽑으므로", work: "₍\(n)₎C₍\(r)₎ = \(Int(DoitMathTopics.permutation(n, r))) ÷ \(r)! = \(value)")],
                      answer: "\(value)")
    }

    /// "0, 1, 2, 3의 숫자 카드로 두 자리 자연수"
    static func digitCards(_ t: String) -> Solved? {
        guard has(t, ["자리"]), has(t, ["카드", "숫자"]), has(t, ["자연수", "정수", "수"]) else { return nil }
        var digits: [Int] = []
        if let m = match(t, #"((?:\d\s*,\s*)+\d)(?!\d)"#) {
            digits = m[1].split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        } else if let m = match(t, #"(\d)\s*부터\s*(\d)\s*까지"#), let lo = Int(m[1]), let hi = Int(m[2]), lo <= hi {
            digits = Array(lo...hi)
        }
        guard digits.count >= 2, digits.allSatisfy({ (0...9).contains($0) }),
              let rm = match(t, #"(두|세|네|2|3|4)\s*자리"#), let r = count(rm[1]) ?? Int(rm[1]), r <= digits.count || has(t, ["중복", "여러 번", "반복"]) else { return nil }
        let repeatable = has(t, ["중복", "여러 번", "반복"])
        var numbers = Set<Int>()
        func build(_ used: [Int], _ value: Int) {
            if used.count == r { numbers.insert(value); return }
            for (i, digit) in digits.enumerated() where repeatable || !used.contains(i) {
                if used.isEmpty && digit == 0 { continue }
                build(used + [i], value * 10 + digit)
            }
        }
        build([], 0)
        var conditions: [String] = []
        var filtered = numbers
        if has(t, ["짝수"]) { filtered = filtered.filter { $0 % 2 == 0 }; conditions.append("짝수") }
        if has(t, ["홀수"]) { filtered = filtered.filter { $0 % 2 == 1 }; conditions.append("홀수") }
        if let m = match(t, #"(\d+)\s*의\s*배수"#), let k = Int(m[1]), k > 0 { filtered = filtered.filter { $0 % k == 0 }; conditions.append("\(k)의 배수") }
        if let m = match(t, #"(\d+)\s*이상"#), let k = Int(m[1]) { filtered = filtered.filter { $0 >= k }; conditions.append("\(k) 이상") }
        if let m = match(t, #"(\d+)\s*이하"#), let k = Int(m[1]) { filtered = filtered.filter { $0 <= k }; conditions.append("\(k) 이하") }
        if let m = match(t, #"(\d+)\s*보다\s*큰"#), let k = Int(m[1]) { filtered = filtered.filter { $0 > k }; conditions.append("\(k)보다 큰") }
        if let m = match(t, #"(\d+)\s*보다\s*작은"#), let k = Int(m[1]) { filtered = filtered.filter { $0 < k }; conditions.append("\(k)보다 작은") }
        let sorted = filtered.sorted()
        let concept = "맨 앞자리에는 0이 올 수 없어요. 0이 있으면 첫 자리는 (0을 뺀 개수)가지, 그다음 자리부터 0을 쓸 수 있어요."
        var steps = [SolutionStep(hint: "숫자 \(digits.map(String.init).joined(separator: ", "))로 \(r)자리 수 (\(repeatable ? "중복 허용" : "중복 없이"), 맨 앞 0 제외)",
                                  work: numbers.count <= 30 ? numbers.sorted().map(String.init).joined(separator: ", ") : "\(numbers.count)개")]
        if !conditions.isEmpty { steps.append(SolutionStep(hint: "그중 \(conditions.joined(separator: ", "))인 수", work: sorted.count <= 30 ? sorted.map(String.init).joined(separator: ", ") : "\(sorted.count)개")) }
        if has(t, ["가장 큰"]), let top = sorted.last {
            return Solved(kind: .counting, topic: "수 카드로 수 만들기", concept: concept, steps: steps, answer: "\(top)")
        }
        if has(t, ["가장 작은"]), let low = sorted.first {
            return Solved(kind: .counting, topic: "수 카드로 수 만들기", concept: concept, steps: steps, answer: "\(low)")
        }
        guard has(t, ["개수", "몇 개", "가지"]) else { return nil }
        if !repeatable, conditions.isEmpty, digits.contains(0) {
            let k = digits.count - 1
            steps.append(SolutionStep(hint: "첫 자리는 0을 뺀 \(k)가지, 나머지 자리는 남은 숫자로", work: "\(k) × ₍\(k)₎P₍\(r - 1)₎ = \(sorted.count)"))
        }
        return Solved(kind: .counting, topic: "수 카드로 수 만들기", concept: concept, steps: steps, answer: "\(sorted.count)개")
    }

    // MARK: - 속력 · 거리 · 시간

    static func speed(_ raw: String) -> Solved? {
        let t = noThousands(raw)
        guard has(t, ["시속", "분속", "초속", "속력", "km/h", "m/s"]) else { return nil }
        if has(t, ["올라갈", "내려올"]) { return hiking(t) }
        guard !has(t, ["만나", "따라잡", "마주", "반대 방향", "같은 방향", "터널", "다리를", "철교", "강물", "흐르는"]) else { return nil }
        var rest = t
        var speedValue: Double?   // m/s
        var speedUnit = "km/h"
        for m in matches(t, #"(시속|분속|초속)\s*(\d+(?:\.\d+)?)\s*(km|m)"#) {
            guard speedValue == nil, let v = Double(m[2]) else { return nil }
            let meters = m[3] == "km" ? v * 1000 : v
            switch m[1] {
            case "시속": speedValue = meters / 3600; speedUnit = m[3] == "km" ? "km/h" : "m/h"
            case "분속": speedValue = meters / 60; speedUnit = "m/min"
            default: speedValue = meters; speedUnit = "m/s"
            }
            rest = rest.replacingOccurrences(of: m[0], with: " ")
        }
        var seconds: Double?
        if let m = match(rest, #"(\d+(?:\.\d+)?)\s*시간\s*(?:(\d+)\s*분)?"#), let h = Double(m[1]) {
            seconds = h * 3600 + (Double(m[2]) ?? 0) * 60
            rest = rest.replacingOccurrences(of: m[0], with: " ")
        } else if let m = match(rest, #"(\d+(?:\.\d+)?)\s*분(?!속)\s*(?:(\d+)\s*초)?"#), let mins = Double(m[1]) {
            seconds = mins * 60 + (Double(m[2]) ?? 0)
            rest = rest.replacingOccurrences(of: m[0], with: " ")
        } else if let m = match(rest, #"(\d+(?:\.\d+)?)\s*초(?!속)"#), let s = Double(m[1]) {
            seconds = s
            rest = rest.replacingOccurrences(of: m[0], with: " ")
        }
        let distances = matches(rest, #"(\d+(?:\.\d+)?)\s*(km|m)(?![a-z/])"#)
        guard distances.count <= 1 else { return nil }
        var meters: Double?
        var distanceUnit = speedUnit == "km/h" ? "km" : "m"
        if let m = distances.first, let v = Double(m[1]) { meters = m[2] == "km" ? v * 1000 : v; distanceUnit = m[2] }
        let known = [speedValue != nil, seconds != nil, meters != nil].filter { $0 }.count
        guard known == 2 else { return nil }
        let concept = "거리 = 속력 × 시간, 속력 = 거리 ÷ 시간, 시간 = 거리 ÷ 속력. 단위(km와 m, 시간과 분)를 먼저 맞춰요."
        if let v = speedValue, let s = seconds {
            let unit = has(t, ["몇 km"]) ? "km" : has(t, ["몇 m"]) ? "m" : (speedUnit == "km/h" ? "km" : "m")
            let value = v * s / (unit == "km" ? 1000 : 1)
            return Solved(kind: .percent, topic: "거리 구하기", concept: concept,
                          steps: [SolutionStep(hint: "단위를 맞추면", work: speedText(v, speedUnit) + ", " + timeText(s)),
                                  SolutionStep(hint: "거리 = 속력 × 시간", work: "\(d(value)) \(unit)")],
                          answer: "\(d(value)) \(unit)")
        }
        if let v = speedValue, let m = meters {
            let s = m / v
            let unit = has(t, ["몇 시간"]) ? "시간" : has(t, ["몇 분"]) ? "분" : has(t, ["몇 초"]) ? "초" : (speedUnit == "km/h" ? "시간" : speedUnit == "m/min" ? "분" : "초")
            let value = unit == "시간" ? s / 3600 : unit == "분" ? s / 60 : s
            var answer = "\(d(value))\(unit)"
            if unit == "시간", value != value.rounded() { answer += " (\(timeText(s)))" }
            return Solved(kind: .percent, topic: "걸린 시간 구하기", concept: concept,
                          steps: [SolutionStep(hint: "단위를 맞추면", work: "거리 \(d(m / (distanceUnit == "km" ? 1000 : 1))) \(distanceUnit), \(speedText(v, speedUnit))"),
                                  SolutionStep(hint: "시간 = 거리 ÷ 속력", work: answer)],
                          answer: answer)
        }
        guard let m = meters, let s = seconds, s > 0 else { return nil }
        let asked = has(t, ["분속"]) ? "m/min" : has(t, ["초속"]) ? "m/s" : (has(t, ["시속"]) || distanceUnit == "km") ? "km/h" : "m/min"
        let v = m / s
        return Solved(kind: .percent, topic: "속력 구하기", concept: concept,
                      steps: [SolutionStep(hint: "거리와 시간", work: "\(d(m / (distanceUnit == "km" ? 1000 : 1))) \(distanceUnit), \(timeText(s))"),
                              SolutionStep(hint: "속력 = 거리 ÷ 시간", work: speedText(v, asked))],
                      answer: speedText(v, asked))
    }

    private static func speedText(_ v: Double, _ unit: String) -> String {
        switch unit {
        case "km/h": return "시속 \(d(v * 3.6)) km"
        case "m/h": return "시속 \(d(v * 3600)) m"
        case "m/min": return "분속 \(d(v * 60)) m"
        default: return "초속 \(d(v)) m"
        }
    }

    private static func timeText(_ s: Double) -> String {
        if s >= 3600 {
            let h = Int(s / 3600), rest = s - Double(h) * 3600
            return rest < 1e-9 ? "\(h)시간" : "\(h)시간 \(d(rest / 60))분"
        }
        if s >= 60 { return "\(d(s / 60))분" }
        return "\(d(s))초"
    }

    /// 올라갈 때 시속 a km, 내려올 때 시속 b km, 모두 T시간
    private static func hiking(_ t: String) -> Solved? {
        let speeds = matches(t, #"시속\s*(\d+(?:\.\d+)?)\s*km"#).compactMap { Double($0[1]) }
        guard speeds.count == 2, speeds.allSatisfy({ $0 > 0 }),
              let tm = match(t, #"(?:모두|총|합하여|전체)\s*(\d+(?:\.\d+)?)\s*시간(?:\s*(\d+)\s*분)?"#), let hours = Double(tm[1]) else { return nil }
        let total = hours + (Double(tm[2]) ?? 0) / 60
        var offset = 0.0
        if let m = match(t, #"(\d+(?:\.\d+)?)\s*km\s*(?:더\s*)?(긴|먼|짧은)"#), let v = Double(m[1]) { offset = m[2] == "짧은" ? -v : v }
        else if !has(t, ["같은 길"]) { return nil }
        let up = speeds[0], down = speeds[1]
        // x/up + (x + offset)/down = total
        let x = (total - offset / down) / (1 / up + 1 / down)
        guard x > 0 else { return nil }
        let asksDown = has(t, ["내려온 거리", "내려온 길"])
        let asksAll = has(t, ["걸은 거리", "전체 거리", "모두 걸은"])
        let value = asksAll ? 2 * x + offset : asksDown ? x + offset : x
        let label = asksAll ? "걸은 거리" : asksDown ? "내려온 거리" : "올라간 거리"
        return Solved(kind: .linear, topic: "속력 문장제 (일차방정식)", concept: "시간 = 거리 ÷ 속력. 올라간 시간 + 내려온 시간 = 전체 시간으로 방정식을 세워요.",
                      steps: [SolutionStep(hint: "올라간 거리를 x km라 하면", work: "x/\(d(up)) + \(offset == 0 ? "x" : "(x \(offset > 0 ? "+" : "−") \(d(abs(offset))))")/\(d(down)) = \(d(total))"),
                              SolutionStep(hint: "양변에 분모의 최소공배수를 곱해 풀면", work: "x = \(d(x))"),
                              SolutionStep(hint: label, work: "\(d(value)) km")],
                      answer: "\(d(value)) km")
    }

    // MARK: - 농도

    static func concentration(_ raw: String) -> Solved? {
        let t = noThousands(raw)
        guard has(t, ["농도", "소금물", "설탕물"]) else { return nil }
        let concept = "농도(%) = (녹아 있는 양 ÷ 전체 용액의 양) × 100, 녹아 있는 양 = 용액의 양 × 농도/100"
        let solutions = matches(t, #"(\d+(?:\.\d+)?)\s*%\s*(?:의|인)?\s*(?:소금물|설탕물)\s*(\d+(?:\.\d+)?)\s*g"#).compactMap { m -> (Double, Double)? in
            guard let p = Double(m[1]), let w = Double(m[2]) else { return nil }
            return (p, w)
        }
        // 두 용액 섞기
        if solutions.count == 2, has(t, ["섞"]) {
            let salt = solutions.reduce(0) { $0 + $1.0 * $1.1 / 100 }, total = solutions.reduce(0) { $0 + $1.1 }
            let p = salt / total * 100
            return Solved(kind: .percent, topic: "소금물 섞기", concept: concept,
                          steps: [SolutionStep(hint: "각 소금물 속 소금의 양", work: solutions.map { "\(d($0.1)) × \(d($0.0))/100 = \(d($0.0 * $0.1 / 100)) g" }.joined(separator: ", ")),
                                  SolutionStep(hint: "섞은 뒤 소금 ÷ 전체 × 100", work: "\(d(salt)) ÷ \(d(total)) × 100 = \(d(p))%")],
                          answer: "\(d(p))%")
        }
        if solutions.count == 1 {
            let (p, w) = solutions[0]
            let salt = p * w / 100
            if let m = match(t, #"물\s*(\d+(?:\.\d+)?)\s*g\s*(?:을|를)?\s*(?:더\s*)?(넣|부|섞|증발|버리|덜어)"#), let water = Double(m[1]) {
                let evaporate = m[2] == "증발"
                guard !has(t, ["버리", "덜어"]) || evaporate else { return nil }
                let total = evaporate ? w - water : w + water
                guard total > 0 else { return nil }
                let q = salt / total * 100
                return Solved(kind: .percent, topic: evaporate ? "물 증발시키기" : "물 더 넣기", concept: concept,
                              steps: [SolutionStep(hint: "소금의 양은 그대로", work: "\(d(w)) × \(d(p))/100 = \(d(salt)) g"),
                                      SolutionStep(hint: "소금물의 양", work: "\(d(w)) \(evaporate ? "−" : "+") \(d(water)) = \(d(total)) g"),
                                      SolutionStep(hint: "농도", work: "\(d(salt)) ÷ \(d(total)) × 100 = \(d(q))%")],
                              answer: "\(d(q))%")
            }
            if has(t, ["소금의 양", "설탕의 양", "소금은 몇", "설탕은 몇", "몇 g"]) {
                return Solved(kind: .percent, topic: "녹아 있는 양 구하기", concept: concept,
                              steps: [SolutionStep(hint: "소금물의 양 × 농도/100", work: "\(d(w)) × \(d(p))/100 = \(d(salt)) g")],
                              answer: "\(d(salt)) g")
            }
            return nil
        }
        guard has(t, ["농도", "몇 %"]) else { return nil }
        let soluteMatch = match(t, #"(?:소금|설탕)(?!물)\s*(\d+(?:\.\d+)?)\s*g"#)
        if let s = soluteMatch, let solute = Double(s[1]) {
            if let w = match(t, #"(?<!소금|설탕)물\s*(\d+(?:\.\d+)?)\s*g"#), let water = Double(w[1]) {
                let p = solute / (solute + water) * 100
                return Solved(kind: .percent, topic: "농도 구하기", concept: concept,
                              steps: [SolutionStep(hint: "소금물의 양 = 소금 + 물", work: "\(d(solute)) + \(d(water)) = \(d(solute + water)) g"),
                                      SolutionStep(hint: "농도 = 소금 ÷ 소금물 × 100", work: "\(d(solute)) ÷ \(d(solute + water)) × 100 = \(d(p))%")],
                              answer: "\(d(p))%")
            }
            if let w = match(t, #"(?:소금물|설탕물)\s*(\d+(?:\.\d+)?)\s*g"#), let total = Double(w[1]), total > 0 {
                let p = solute / total * 100
                return Solved(kind: .percent, topic: "농도 구하기", concept: concept,
                              steps: [SolutionStep(hint: "농도 = 소금 ÷ 소금물 × 100", work: "\(d(solute)) ÷ \(d(total)) × 100 = \(d(p))%")],
                              answer: "\(d(p))%")
            }
        }
        return nil
    }

    // MARK: - 할인 · 이익

    static func money(_ raw: String) -> Solved? {
        let t = noThousands(raw)
        guard has(t, ["할인", "이익"]), let rm = match(t, #"(\d+(?:\.\d+)?)\s*%"#), let rate = Double(rm[1]), rate < 100,
              let pm = match(t, #"(\d+(?:\.\d+)?)\s*원"#), let price = Double(pm[1]) else { return nil }
        guard matches(t, #"(\d+(?:\.\d+)?)\s*%"#).count == 1, !(has(t, ["할인"]) && has(t, ["이익"])) else { return nil }
        let r = rate / 100
        if has(t, ["할인"]) {
            // 할인한 가격을 알고 정가를 묻기: "20% 할인하여 8000원에 샀다. 정가는?"
            if has(t, ["정가는", "정가를", "원래 가격", "처음 가격"]), t.range(of: #"\d\s*원에\s*(?:샀|팔|판|구입|구매)"#, options: .regularExpression) != nil {
                let original = price / (1 - r)
                return Solved(kind: .percent, topic: "할인 전 가격", concept: "할인 가격 = 정가 × (1 − 할인율) 이므로 정가 = 할인 가격 ÷ (1 − 할인율)",
                              steps: [SolutionStep(hint: "정가를 x원이라 하면", work: "x × (1 − \(d(rate))/100) = \(d(price))"),
                                      SolutionStep(hint: "x를 구하면", work: "x = \(d(original))")],
                              answer: "\(d(original))원")
            }
            let off = price * r
            if has(t, ["할인 금액", "할인받은 금액", "할인받은 돈", "얼마를 할인", "얼마나 할인"]) {
                return Solved(kind: .percent, topic: "할인 금액", concept: "할인 금액 = 원래 가격 × 할인율",
                              steps: [SolutionStep(hint: "\(d(price)) × \(d(rate))/100", work: "\(d(off))원")], answer: "\(d(off))원")
            }
            return Solved(kind: .percent, topic: "할인한 가격", concept: "할인 가격 = 원래 가격 × (1 − 할인율) = 원래 가격 − 할인 금액",
                          steps: [SolutionStep(hint: "할인 금액 = \(d(price)) × \(d(rate))/100", work: "\(d(off))원"),
                                  SolutionStep(hint: "원래 가격에서 빼면", work: "\(d(price)) − \(d(off)) = \(d(price - off))원")],
                          answer: "\(d(price - off))원")
        }
        // 이익: 원가에 a%의 이익을 붙여 정가
        guard has(t, ["원가"]) else { return nil }
        let profit = price * r
        if has(t, ["이익은 얼마", "이익금", "이익을 구", "이익은 몇"]) {
            return Solved(kind: .percent, topic: "이익", concept: "이익 = 원가 × 이익률", steps: [SolutionStep(hint: "\(d(price)) × \(d(rate))/100", work: "\(d(profit))원")], answer: "\(d(profit))원")
        }
        guard has(t, ["정가"]) else { return nil }
        return Solved(kind: .percent, topic: "정가 정하기", concept: "정가 = 원가 × (1 + 이익률) = 원가 + 이익",
                      steps: [SolutionStep(hint: "이익 = \(d(price)) × \(d(rate))/100", work: "\(d(profit))원"),
                              SolutionStep(hint: "정가 = 원가 + 이익", work: "\(d(price)) + \(d(profit)) = \(d(price + profit))원")],
                      answer: "\(d(price + profit))원")
    }

    /// "학생 25명 중 여학생이 15명 … 전체의 몇 %"
    static func partPercent(_ t: String) -> Solved? {
        guard has(t, ["몇 %", "몇%", "몇 퍼센트", "몇 프로", "백분율"]) else { return nil }
        guard let m = match(t, #"(\d+)\s*(명|개|마리|권|장|대|그루|송이|자루)\s*(?:중|가운데)(?:에서)?\s*[^\d]{0,20}?(\d+)\s*(명|개|마리|권|장|대|그루|송이|자루)"#),
              m[2] == m[4], let total = Double(m[1]), let part = Double(m[3]), total > 0, part <= total else { return nil }
        let p = part / total * 100
        return Solved(kind: .percent, topic: "비율을 백분율로", concept: "백분율(%) = (비교하는 양 ÷ 기준량) × 100",
                      steps: [SolutionStep(hint: "기준량 \(d(total)), 비교하는 양 \(d(part))", work: "\(d(part)) ÷ \(d(total)) = \(d(part / total))"),
                              SolutionStep(hint: "× 100", work: "\(d(p))%")],
                      answer: "\(d(p))%")
    }

    // MARK: - 일차방정식 문장제

    /// 나이: "A의 나이가 B의 나이의 k배가 되는 것은 몇 년 후"
    static func age(_ t: String) -> Solved? {
        guard has(t, ["나이"]), has(t, ["년 후", "년 전"]) else { return nil }
        var ages: [String: Double] = [:]
        for m in matches(t, #"([가-힣]+)의\s*나이(?:는|가|은)\s*(\d+)\s*(?:세|살)"#) { ages[m[1]] = Double(m[2]) }
        guard let c = match(t, #"([가-힣]+)의\s*나이가\s*([가-힣]+)의\s*나이의\s*(\d+)\s*배"#),
              let a = ages[c[1]], let b = ages[c[2]], let k = Double(c[3]), k > 1 else { return nil }
        // a + x = k(b + x)
        let x = (a - k * b) / (k - 1)
        guard abs(x - x.rounded()) < 1e-9, x != 0 else { return nil }
        let answer = x > 0 ? "\(d(x))년 후" : "\(d(-x))년 전"
        return Solved(kind: .linear, topic: "나이 문장제 (일차방정식)", concept: "x년 후에는 두 사람 모두 x살씩 많아져요. 조건대로 방정식을 세워요.",
                      steps: [SolutionStep(hint: "x년 후 \(c[1])의 나이는 \(d(a)) + x, \(c[2])의 나이는 \(d(b)) + x", work: "\(d(a)) + x = \(d(k))(\(d(b)) + x)"),
                              SolutionStep(hint: "괄호를 풀고 정리하면", work: "\(d(a)) + x = \(d(k * b)) + \(d(k))x → \(k == 2 ? "" : d(k - 1))x = \(d(a - k * b))"),
                              SolutionStep(hint: "x를 구하면", work: "x = \(d(x))")],
                      answer: answer)
    }

    /// 연속하는 세 자연수의 합이 48
    static func consecutive(_ t: String) -> Solved? {
        guard let m = match(t, #"연속(?:하는|된|한)\s*(두|세|네|다섯|2|3|4|5)\s*(?:개의\s*)?(자연수|정수|짝수|홀수|수)(?:의)?\s*합(?:이|은)\s*(-?\d+)"#),
              let n = count(m[1]), let s = Int(m[3]) else { return nil }
        let step = (m[2] == "짝수" || m[2] == "홀수") ? 2 : 1
        let offset = step * n * (n - 1) / 2
        guard (s - offset) % n == 0 else { return nil }
        let first = (s - offset) / n
        if m[2] == "짝수" && first % 2 != 0 { return nil }
        if m[2] == "홀수" && abs(first % 2) != 1 { return nil }
        if m[2] == "자연수" && first < 1 { return nil }
        let list = (0..<n).map { first + $0 * step }
        let answer: String
        if has(t, ["가장 큰"]) { answer = "\(list.last!)" }
        else if has(t, ["가장 작은"]) { answer = "\(list[0])" }
        else if has(t, ["가운데"]), n % 2 == 1 { answer = "\(list[n / 2])" }
        else { answer = list.map(String.init).joined(separator: ", ") }
        let terms = (0..<n).map { $0 == 0 ? "x" : "(x + \($0 * step))" }.joined(separator: " + ")
        return Solved(kind: .linear, topic: "연속하는 수 (일차방정식)", concept: "연속하는 수는 x, x + 1, x + 2 … (짝수·홀수는 2씩) 로 놓고 방정식을 세워요.",
                      steps: [SolutionStep(hint: "가장 작은 수를 x라 하면", work: "\(terms) = \(s)"),
                              SolutionStep(hint: "정리하면", work: "\(n)x + \(offset) = \(s) → x = \(first)"),
                              SolutionStep(hint: "\(n)개의 수", work: list.map(String.init).joined(separator: ", "))],
                      answer: answer)
    }

    /// 한 개에 500원인 A와 800원인 B를 합하여 10개, 6800원
    static func priceCount(_ raw: String) -> Solved? {
        let t = noThousands(raw)
        let items = matches(t, #"한\s*(?:개|자루|권|장|병|송이|켤레|봉지)에\s*(\d+)\s*원(?:인|하는|짜리)\s*([가-힣]+?)(?:와|과|을|를|\s)"#)
        guard items.count == 2, let p1 = Double(items[0][1]), let p2 = Double(items[1][1]), p1 != p2,
              let nm = match(t, #"(?:합하여|모두|합해서|전부|합쳐서)\s*(\d+)\s*(?:개|자루|권|장|병|송이|켤레|봉지)"#), let n = Double(nm[1]) else { return nil }
        let money = matches(t, #"(\d+)\s*원"#).compactMap { Double($0[1]) }.filter { $0 != p1 && $0 != p2 }
        guard money.count == 1, let total = money.first else { return nil }
        let name1 = items[0][2], name2 = items[1][2]
        let tail = t.components(separatedBy: "원").last ?? t
        let b = (total - p1 * n) / (p2 - p1), a = n - b
        guard b >= 0, a >= 0, abs(b - b.rounded()) < 1e-9 else { return nil }
        let asks2 = tail.contains(name2), asks1 = tail.contains(name1)
        guard asks1 != asks2 else { return nil }
        let answer = asks2 ? "\(d(b))개" : "\(d(a))개"
        return Solved(kind: .linear, topic: "개수와 금액 (일차방정식)", concept: "한 가지의 개수를 x로 놓으면 다른 것은 (전체 개수 − x)개. 금액의 합으로 방정식을 세워요.",
                      steps: [SolutionStep(hint: "\(name2)을(를) x개라 하면 \(name1)은(는) (\(d(n)) − x)개", work: "\(d(p1))(\(d(n)) − x) + \(d(p2))x = \(d(total))"),
                              SolutionStep(hint: "정리하면", work: "\(d(p2 - p1))x = \(d(total - p1 * n)) → x = \(d(b))"),
                              SolutionStep(hint: "개수", work: "\(name1) \(d(a))개, \(name2) \(d(b))개")],
                      answer: answer)
    }

    static let legCount: [String: Int] = ["닭": 2, "오리": 2, "참새": 2, "비둘기": 2, "타조": 2, "거위": 2,
                                          "토끼": 4, "돼지": 4, "소": 4, "강아지": 4, "고양이": 4, "양": 4, "염소": 4, "말": 4, "사슴": 4,
                                          "거미": 8, "개미": 6, "잠자리": 6, "메뚜기": 6, "나비": 6]

    /// 닭과 토끼가 모두 10마리, 다리 수의 합이 32
    static func legs(_ t: String) -> Solved? {
        guard has(t, ["다리"]), has(t, ["마리"]) else { return nil }
        let names = legCount.keys.sorted { $0.count > $1.count }.joined(separator: "|")
        var animals: [String] = []
        for m in matches(t, "(?<![가-힣])(\(names))(?=\\s*(?:와|과|는|은|가|이|를|을|의|,|\\s))") where !animals.contains(m[1]) { animals.append(m[1]) }
        guard animals.count == 2, let l1 = legCount[animals[0]], let l2 = legCount[animals[1]], l1 != l2,
              let nm = match(t, #"(?:모두|합하여|합해서|전부|합쳐서|모두 합해)\s*(\d+)\s*마리"#), let n = Double(nm[1]),
              let lm = match(t, #"다리(?:의)?\s*(?:수|개수)?(?:의\s*합|를\s*모두\s*세면|는\s*모두|가\s*모두)?(?:이|가|은|는)?\s*(?:모두\s*)?(\d+)\s*(?:개|쌍)?"#), let legs = Double(lm[1]) else { return nil }
        let x = (legs - Double(l1) * n) / Double(l2 - l1)   // 두 번째 동물의 수
        guard x >= 0, x <= n, abs(x - x.rounded()) < 1e-9 else { return nil }
        guard let askRange = t.range(of: "몇 마리") else { return nil }
        let before = String(t[..<askRange.lowerBound])
        let lastFirst = before.range(of: animals[0], options: .backwards)?.lowerBound
        let lastSecond = before.range(of: animals[1], options: .backwards)?.lowerBound
        let asksSecond: Bool
        switch (lastFirst, lastSecond) {
        case let (a?, b?): asksSecond = b > a
        case (nil, _?): asksSecond = true
        default: asksSecond = false
        }
        let value = asksSecond ? x : n - x
        let asked = asksSecond ? animals[1] : animals[0]
        return Solved(kind: .linear, topic: "다리 수 문장제 (일차방정식)", concept: "한쪽 동물의 수를 x로 놓으면 다른 쪽은 (전체 − x)마리. 다리 수의 합으로 방정식을 세워요.",
                      steps: [SolutionStep(hint: "\(animals[1])를 x마리라 하면 \(animals[0])는 (\(d(n)) − x)마리", work: "\(l1)(\(d(n)) − x) + \(l2)x = \(d(legs))"),
                              SolutionStep(hint: "정리하면", work: "\(l2 - l1)x = \(d(legs - Double(l1) * n)) → x = \(d(x))"),
                              SolutionStep(hint: "\(asked)의 수", work: "\(d(value))마리")],
                      answer: "\(d(value))마리")
    }

    /// 두 수의 합이 25, 차가 7
    static func sumDifference(_ t: String) -> Solved? {
        guard let m = match(t, #"두\s*(?:자연)?수의\s*합(?:이|은)\s*(-?\d+(?:\.\d+)?)"#), let s = Double(m[1]) else { return nil }
        let concept = "두 수를 x, y로 놓고 연립방정식을 세워요. 합과 차를 알면 큰 수 = (합 + 차)/2, 작은 수 = (합 − 차)/2"
        var big: Double, small: Double
        var steps: [SolutionStep]
        if let dm = match(t, #"차(?:가|는)\s*(-?\d+(?:\.\d+)?)"#), let diff = Double(dm[1]) {
            big = (s + diff) / 2; small = (s - diff) / 2
            steps = [SolutionStep(hint: "큰 수를 x, 작은 수를 y라 하면", work: "x + y = \(d(s)), x − y = \(d(diff))"),
                     SolutionStep(hint: "두 식을 더하면", work: "2x = \(d(s + diff)) → x = \(d(big)), y = \(d(small))")]
        } else if let km = match(t, #"큰\s*수(?:가|는)\s*작은\s*수의\s*(\d+)\s*배"#), let k = Double(km[1]), k > 0 {
            small = s / (k + 1); big = s - small
            steps = [SolutionStep(hint: "작은 수를 x라 하면 큰 수는 \(d(k))x", work: "x + \(d(k))x = \(d(s))"),
                     SolutionStep(hint: "x를 구하면", work: "x = \(d(small)), 큰 수 \(d(big))")]
        } else { return nil }
        let answer: String
        // 묻는 부분: 마지막 "때" 뒤
        let question = t.components(separatedBy: "때").last ?? t
        if has(question, ["큰 수"]) && !has(question, ["작은 수"]) { answer = d(big) }
        else if has(question, ["작은 수"]) && !has(question, ["큰 수"]) { answer = d(small) }
        else { answer = "큰 수 \(d(big)), 작은 수 \(d(small))" }
        return Solved(kind: .system, topic: "두 수의 합과 차 (연립방정식)", concept: concept, steps: steps, answer: answer)
    }

    // MARK: - 비와 비율

    private static func ratParse(_ s: String) -> Rat? {
        let parts = s.split(separator: "/").map(String.init)
        if parts.count == 2, let a = Rat.parse(parts[0]), let b = Rat.parse(parts[1]) { return a / b }
        return Rat.parse(s)
    }

    /// 가장 간단한 자연수의 비
    static func simplestRatio(_ t: String) -> Solved? {
        guard has(t, ["간단한"]), has(t, ["비"]),
              let m = match(t, #"(\d+(?:\.\d+)?(?:/\d+)?)\s*:\s*(\d+(?:\.\d+)?(?:/\d+)?)(?:\s*:\s*(\d+(?:\.\d+)?(?:/\d+)?))?"#) else { return nil }
        let parts = [m[1], m[2], m[3]].filter { !$0.isEmpty }.compactMap(ratParse)
        guard parts.count >= 2, parts.allSatisfy({ $0.n > 0 }) else { return nil }
        var lcm = 1
        for p in parts { lcm = lcm / DoitAlgebra.gcd(lcm, p.d) * p.d }
        let scaled = parts.map { $0.n * (lcm / $0.d) }
        let g = scaled.reduce(0) { DoitAlgebra.gcd($0, $1) }
        let result = scaled.map { $0 / max(g, 1) }
        var steps: [SolutionStep] = []
        if lcm > 1 { steps.append(SolutionStep(hint: "각 항에 \(lcm)을(를) 곱해 자연수로", work: scaled.map(String.init).joined(separator: " : "))) }
        steps.append(SolutionStep(hint: "각 항을 최대공약수 \(g)(으)로 나누면", work: result.map(String.init).joined(separator: " : ")))
        return Solved(kind: .percent, topic: "간단한 자연수의 비", concept: "비의 전항과 후항에 0이 아닌 같은 수를 곱하거나 나누어도 비율은 같아요.",
                      steps: steps, answer: result.map(String.init).joined(separator: " : "))
    }

    /// 비례배분: "35개를 형과 동생이 3 : 4로 나누어"
    static func ratioDivision(_ raw: String) -> Solved? {
        let t = noThousands(raw)
        guard has(t, ["나누", "나눠", "배분"]),
              let rm = match(t, #"(\d+)\s*:\s*(\d+)(?!\s*:)"#), let a = Double(rm[1]), let b = Double(rm[2]), a > 0, b > 0,
              let tm = match(t, #"(\d+(?:\.\d+)?)\s*(개|원|명|cm|m|g|kg|L|장|권|자루|마리|송이)\s*(?:을|를)"#), let total = Double(tm[1]) else { return nil }
        let unit = tm[2]
        let first = total * a / (a + b), second = total * b / (a + b)
        guard let range = t.range(of: rm[0]) else { return nil }
        let before = String(t[..<range.lowerBound]), tail = String(t[range.upperBound...])
        var answer = "\(d(first))\(unit), \(d(second))\(unit)"
        var names: (String, String)?
        if let nm = match(before, #"([가-힣]+)(?:와|과)\s*([가-힣]+?)(?:이|가|에게)?\s*$"#) ?? match(before, #"([가-힣]+)(?:와|과)\s*([가-힣]+?)(?:이|가)\s"#) { names = (nm[1], nm[2]) }
        if let (n1, n2) = names {
            func asks(_ name: String) -> Bool { tail.range(of: name + "(?:이|가|은|는|의|에게)", options: .regularExpression) != nil }
            let ask1 = asks(n1) && !(n2.contains(n1) && asks(n2)), ask2 = asks(n2) && !(n1.contains(n2) && asks(n1))
            if ask2 && !ask1 { answer = "\(n2) \(d(second))\(unit)" }
            else if ask1 && !ask2 { answer = "\(n1) \(d(first))\(unit)" }
            else { answer = "\(n1) \(d(first))\(unit), \(n2) \(d(second))\(unit)" }
        }
        return Solved(kind: .percent, topic: "비례배분", concept: "전체를 a : b로 나누면 앞의 몫은 전체 × a/(a+b), 뒤의 몫은 전체 × b/(a+b)예요.",
                      steps: [SolutionStep(hint: "\(d(a)) : \(d(b))로 나누면 전체를 \(d(a + b))묶음으로", work: "\(d(total)) ÷ \(d(a + b)) = \(d(total / (a + b)))"),
                              SolutionStep(hint: "각각의 양", work: "\(d(total)) × \(d(a))/\(d(a + b)) = \(d(first)), \(d(total)) × \(d(b))/\(d(a + b)) = \(d(second))")],
                      answer: answer)
    }

    // MARK: - 약수와 배수 문장제

    /// 1부터 50까지의 자연수 중 6의 배수의 개수
    static func multiplesCount(_ t: String) -> Solved? {
        guard has(t, ["배수"]), has(t, ["개수", "몇 개"]), !has(t, ["공배수", "이면서", "또는", "아닌", "그리고"]) else { return nil }
        var lo = 0, hi = 0
        if let m = match(t, #"(\d+)\s*부터\s*(\d+)\s*까지"#), let a = Int(m[1]), let b = Int(m[2]) { lo = a; hi = b }
        else if let m = match(t, #"(\d+)\s*이하의\s*자연수"#), let b = Int(m[1]) { lo = 1; hi = b }
        else if let m = match(t, #"(\d+)\s*(?:보다\s*작은|미만의)\s*자연수"#), let b = Int(m[1]) { lo = 1; hi = b - 1 }
        else if has(t, ["두 자리 자연수", "두 자리의 자연수"]) { lo = 10; hi = 99 }
        else if has(t, ["세 자리 자연수", "세 자리의 자연수"]) { lo = 100; hi = 999 }
        else { return nil }
        guard let km = match(t, #"(\d+)\s*의\s*배수"#), let k = Int(km[1]), k > 0, lo <= hi, hi < 100_000_000 else { return nil }
        guard lo >= 1 else { return nil }
        let value = hi / k - (lo - 1) / k
        return Solved(kind: .numberTheory, topic: "배수의 개수", concept: "1부터 n까지 k의 배수는 (n ÷ k의 몫)개예요.",
                      steps: [SolutionStep(hint: "1부터 \(hi)까지 \(k)의 배수", work: "\(hi) ÷ \(k)의 몫 = \(hi / k)"),
                              SolutionStep(hint: lo > 1 ? "1부터 \(lo - 1)까지의 \(k)의 배수를 빼면" : "\(lo)부터 \(hi)까지", work: lo > 1 ? "\(hi / k) − \((lo - 1) / k) = \(value)" : "\(value)개")],
                      answer: "\(value)개")
    }

    /// 최대공약수가 G, 최소공배수가 L 일 때 두 수의 곱 (또는 다른 한 수)
    static func gcdLcmProduct(_ t: String) -> Solved? {
        guard let gm = match(t, #"최대공약수(?:가|는)\s*(\d+)"#), let lm = match(t, #"최소공배수(?:가|는)\s*(\d+)"#),
              let g = Int(gm[1]), let l = Int(lm[1]), g > 0, l % g == 0 else { return nil }
        let concept = "두 자연수 A, B의 최대공약수를 G, 최소공배수를 L이라 하면 A × B = G × L 이에요."
        if has(t, ["곱"]) {
            return Solved(kind: .numberTheory, topic: "최대공약수와 최소공배수의 관계", concept: concept,
                          steps: [SolutionStep(hint: "A × B = G × L", work: "\(g) × \(l) = \(g * l)")], answer: "\(g * l)")
        }
        if let am = match(t, #"한\s*수(?:가|는)\s*(\d+)"#), let a = Int(am[1]), a > 0, (g * l) % a == 0, has(t, ["다른 한 수", "다른 수", "나머지 한 수"]) {
            let b = g * l / a
            return Solved(kind: .numberTheory, topic: "최대공약수와 최소공배수의 관계", concept: concept,
                          steps: [SolutionStep(hint: "A × B = G × L", work: "\(a) × B = \(g) × \(l)"), SolutionStep(hint: "B를 구하면", work: "B = \(b)")],
                          answer: "\(b)")
        }
        return nil
    }

    /// n팀이 서로 한 번씩 경기 (n명이 서로 한 번씩 악수) → ₙC₂
    static func roundRobin(_ t: String) -> Solved? {
        guard let m = match(t, #"(\d+)\s*(?:개의\s*)?(?:팀|명|사람)(?:이|가)?\s*(?:모두\s*)?서로\s*한\s*번씩\s*(경기|악수)"#), let n = Int(m[1]), n >= 2, n <= 100 else { return nil }
        let value = n * (n - 1) / 2
        return Solved(kind: .counting, topic: "조합 (리그전·악수)", concept: "두 팀(두 사람)을 순서 없이 고르는 것과 같아서 ₙC₂ = n(n − 1)/2 예요.",
                      steps: [SolutionStep(hint: "\(n)개 중 순서 없이 2개를 고르면", work: "₍\(n)₎C₍2₎ = \(n) × \(n - 1) ÷ 2 = \(value)")], answer: "\(value)")
    }

    /// 삼각형의 세 내각의 크기의 비가 2 : 3 : 4
    static func angleRatio(_ t: String) -> Solved? {
        guard has(t, ["내각", "세 각"]), has(t, ["비"]),
              let m = match(t, #"(\d+)\s*:\s*(\d+)\s*:\s*(\d+)(?:\s*:\s*(\d+))?"#) else { return nil }
        let parts = [m[1], m[2], m[3], m[4]].compactMap { Int($0) }
        let sides = parts.count
        guard (sides == 3 && has(t, ["삼각형"])) || (sides == 4 && has(t, ["사각형"])) else { return nil }
        let total = 180.0 * Double(sides - 2), sum = Double(parts.reduce(0, +))
        let angles = parts.map { total * Double($0) / sum }
        let answer: String
        if has(t, ["가장 큰"]) { answer = "\(d(angles.max()!))°" }
        else if has(t, ["가장 작은"]) { answer = "\(d(angles.min()!))°" }
        else { answer = angles.map { "\(d($0))°" }.joined(separator: ", ") }
        return Solved(kind: .geometry, topic: "내각의 크기의 비", concept: "내각의 합을 비율대로 나눠요 (삼각형 180°, 사각형 360°).",
                      steps: [SolutionStep(hint: "내각의 합 \(Int(total))°를 \(parts.map(String.init).joined(separator: " : "))로 나누면", work: angles.map { "\(d($0))°" }.joined(separator: ", "))],
                      answer: answer)
    }

    /// 편차의 합은 0
    static func deviationUnknown(_ t: String) -> Solved? {
        guard has(t, ["편차"]), !has(t, ["표준편차"]), let items = dataList(t, allowX: true), items.filter({ $0 == "x" }).count == 1 else { return nil }
        let known = items.compactMap { Double($0) }.reduce(0, +)
        return Solved(kind: .statistics, topic: "편차의 합", concept: "편차 = 변량 − 평균이고, 편차의 합은 항상 0이에요.",
                      steps: [SolutionStep(hint: "편차의 합 = 0", work: items.joined(separator: " + ") + " = 0"), SolutionStep(hint: "x를 구하면", work: "x = \(d(-known))")],
                      answer: "x = \(d(-known))")
    }

    /// 60에 곱해서(나눠서) 어떤 자연수의 제곱이 되게 하는 가장 작은 자연수
    static func squareMultiplier(_ t: String) -> Solved? {
        guard has(t, ["제곱"]), has(t, ["가장 작은"]),
              let m = match(t, #"(\d+)\s*(?:에|을|를)\s*(?:가장\s*작은\s*)?(?:자연수|어떤\s*수|수)\s*(?:[a-z]\s*)?(?:를|을|로|으로)\s*(곱|나누)"#),
              let n = Int(m[1]), n >= 2, n < 100_000_000 else { return nil }
        let factors = DoitMathTopics.primeFactors(n)
        let odd = factors.filter { $0.1 % 2 == 1 }.map(\.0)
        let k = odd.reduce(1, *)
        let multiply = m[2] == "곱"
        let result = multiply ? n * k : n / k
        let root = Int(Double(result).squareRoot().rounded())
        guard root * root == result else { return nil }
        return Solved(kind: .numberTheory, topic: "제곱인 수 만들기", concept: "어떤 자연수의 제곱이 되려면 소인수분해했을 때 모든 지수가 짝수여야 해요.",
                      steps: [SolutionStep(hint: "소인수분해", work: "\(n) = \(DoitMathTopics.factorText(factors))"),
                              SolutionStep(hint: "지수가 홀수인 소인수를 \(multiply ? "곱하면" : "나누면")", work: odd.isEmpty ? "이미 제곱수예요" : odd.map(String.init).joined(separator: " × ") + " = \(k)"),
                              SolutionStep(hint: "확인", work: "\(n) \(multiply ? "×" : "÷") \(k) = \(result) = \(root)²")],
                      answer: "\(k)")
    }

    /// "어떤 수에 5를 더하면 12가 된다", "x의 3배에서 4를 뺀 수는 11이다"
    static func someNumber(_ t: String) -> Solved? {
        guard !has(t, ["잘못", "처음 수", "보다", "만큼", "차이"]) else { return nil }
        guard let start = t.range(of: #"어떤\s*수|(?<![a-z])x(?=\s*(?:에|의|를|을|에서))"#, options: .regularExpression) else { return nil }
        let tail = String(t[start.upperBound...])
        let end = #"(?:하면|하고|한\s*후|한\s*다음|한|하여|해서|하니|했더니|하였더니)?"#
        let ops: [(String, String)] = [
            (#"^\s*에\s*(\d+(?:\.\d+)?)\s*(?:을|를)\s*더"# + end, "+"),
            (#"^\s*에서\s*(\d+(?:\.\d+)?)\s*(?:을|를)\s*(?:빼면|빼고|뺀\s*후|뺀|빼서|빼니|뺐더니)"#, "-"),
            (#"^\s*에\s*(\d+(?:\.\d+)?)\s*(?:을|를)\s*곱"# + end, "*"),
            (#"^\s*(?:을|를)\s*(\d+(?:\.\d+)?)\s*(?:으로|로)\s*(?:나누면|나누고|나눈\s*후|나눈|나누어|나눠서|나누니|나눴더니)"#, "/"),
            (#"^\s*의\s*(\d+(?:\.\d+)?)\s*배(?:를\s*하면|하면|한\s*후|한|하여|해서)?"#, "*"),
            (#"^\s*(?:을|를)?\s*(\d+(?:\.\d+)?)\s*배\s*(?:하면|한\s*후|한|하여|해서)"#, "*"),
            // 앞 계산에 이어서: "…나눈 후 5를 더하면"
            (#"^\s*(\d+(?:\.\d+)?)\s*(?:을|를)\s*더"# + end, "+"),
            (#"^\s*(\d+(?:\.\d+)?)\s*(?:을|를)\s*(?:빼면|빼고|뺀\s*후|뺀|빼서|빼니|뺐더니)"#, "-"),
            (#"^\s*(\d+(?:\.\d+)?)\s*(?:을|를)\s*곱"# + end, "*"),
            (#"^\s*(\d+(?:\.\d+)?)\s*(?:으로|로)\s*(?:나누면|나누고|나눈\s*후|나눈|나누어|나눠서|나누니|나눴더니)"#, "/")
        ]
        var expression = "x"
        var shown = "□"
        var rest = tail
        var used = 0
        while used < 4 {
            var matched = false
            // 이어지는 말: "고", "후", "여", "다음" 뒤에 "다시"
            rest = rest.replacingOccurrences(of: #"^[\s,]*(?:다음에|다음|후에|후|뒤에|뒤)?[\s,]*(?:다시\s*)?(?:그\s*수)?"#, with: "", options: .regularExpression)
            for (pattern, op) in ops {
                guard let m = match(rest, pattern), let r = rest.range(of: m[0]) else { continue }
                // 앞의 결과에 이어서 계산 ("에서"/"의"/"를" 다음은 앞 결과가 주어)
                expression = "(\(expression))\(op)\(m[1])"
                shown = op == "*" && m[0].contains("배") ? "(\(shown)) × \(m[1])" : "(\(shown)) \(op == "*" ? "×" : op == "/" ? "÷" : op == "-" ? "−" : "+") \(m[1])"
                rest = String(rest[r.upperBound...])
                // 다음 연산의 주어는 앞의 결과 ("…을 더한 수에서 4를 빼면")
                rest = rest.replacingOccurrences(of: #"^\s*(?:수|값)?\s*"#, with: "", options: .regularExpression)
                matched = true
                used += 1
                break
            }
            if !matched { break }
        }
        guard used >= 1,
              let result = match(rest, #"^\s*(?:면|니|은|는|이|가|의 값은|의 값이)?\s*(-?\d+(?:\.\d+)?)\s*(?:이|가)?\s*(?:된다|됩니다|돼요|입니다|이다|예요|이에요|와 같|과 같)"#),
              let target = Double(result[1]) else { return nil }
        // 문장 속 수는 모두 쓰여야 함 (안 쓴 조건이 있으면 풀지 않음)
        let allNumbers = matches(t, #"\d+(?:\.\d+)?"#).count
        guard allNumbers == used + 1 else { return nil }
        guard let left = DoitMath.polynomial(expression), left.degree == 1 else { return nil }
        let x = (target - left[0]) / left[1]
        let shownExpression = shown.replacingOccurrences(of: "(□)", with: "□")
        return Solved(kind: .linear, topic: "어떤 수 구하기", concept: "어떤 수를 □(또는 x)로 놓고 식을 세운 뒤, 거꾸로 계산하거나 방정식으로 풀어요.",
                      steps: [SolutionStep(hint: "어떤 수를 □라 하고 식으로 나타내면", work: "\(shownExpression) = \(d(target))"),
                              SolutionStep(hint: "거꾸로 계산(또는 방정식 풀이)하면", work: "□ = \(d(x))"),
                              SolutionStep(hint: "확인", work: shownExpression.replacingOccurrences(of: "□", with: d(x)) + " = \(d(target))")],
                      answer: d(x))
    }

    // MARK: - 다각형의 각

    private static func polygonName(_ n: Int, regular: Bool) -> String {
        let names = [3: "삼", 4: "사", 5: "오", 6: "육", 7: "칠", 8: "팔", 9: "구", 10: "십", 11: "십일", 12: "십이"]
        let prefix = regular ? "정" : ""
        if let k = names[n] { return "\(prefix)\(n)각형 (\(prefix)\(k)각형)" }
        return "\(prefix)\(n)각형"
    }

    static func polygonFromAngle(_ t: String) -> Solved? {
        if let m = match(t, #"한\s*내각의\s*크기가\s*(\d+(?:\.\d+)?)\s*°?\s*인\s*정다각형"#), let a = Double(m[1]), a < 180 {
            let n = 360 / (180 - a)
            guard abs(n - n.rounded()) < 1e-9, n >= 3 else { return nil }
            return Solved(kind: .geometry, topic: "정다각형의 한 내각", concept: "한 내각 + 한 외각 = 180°, 외각의 합은 항상 360°예요.",
                          steps: [SolutionStep(hint: "한 외각 = 180° − 한 내각", work: "180° − \(d(a))° = \(d(180 - a))°"),
                                  SolutionStep(hint: "외각의 합 360° ÷ 한 외각", work: "360 ÷ \(d(180 - a)) = \(Int(n))")],
                          answer: polygonName(Int(n), regular: true))
        }
        if let m = match(t, #"한\s*외각의\s*크기가\s*(\d+(?:\.\d+)?)\s*°?\s*인\s*정다각형"#), let a = Double(m[1]), a > 0 {
            let n = 360 / a
            guard abs(n - n.rounded()) < 1e-9, n >= 3 else { return nil }
            return Solved(kind: .geometry, topic: "정다각형의 한 외각", concept: "다각형의 외각의 합은 항상 360°예요.",
                          steps: [SolutionStep(hint: "360° ÷ 한 외각", work: "360 ÷ \(d(a)) = \(Int(n))")], answer: polygonName(Int(n), regular: true))
        }
        if let m = match(t, #"내각의\s*(?:크기의\s*)?합이\s*(\d+)\s*°?\s*인\s*(정)?다각형"#), let s = Int(m[1]), s % 180 == 0, s >= 180 {
            let n = s / 180 + 2
            var steps = [SolutionStep(hint: "n각형의 내각의 합 = 180° × (n − 2)", work: "180 × (n − 2) = \(s) → n = \(n)")]
            if has(t, ["대각선"]) {
                steps.append(SolutionStep(hint: "대각선의 개수 = n(n − 3)/2", work: "\(n) × \(n - 3) ÷ 2 = \(n * (n - 3) / 2)"))
                return Solved(kind: .geometry, topic: "다각형의 대각선", concept: "n각형의 내각의 합은 180°(n − 2), 대각선은 n(n − 3)/2개예요.", steps: steps, answer: "\(n * (n - 3) / 2)개")
            }
            if has(t, ["한 내각"]), !m[2].isEmpty {
                let one = Double(s) / Double(n)
                steps.append(SolutionStep(hint: "정다각형의 한 내각 = 내각의 합 ÷ n", work: "\(s) ÷ \(n) = \(d(one))°"))
                return Solved(kind: .geometry, topic: "정다각형의 한 내각", concept: "n각형의 내각의 합은 180°(n − 2)예요.", steps: steps, answer: "\(d(one))°")
            }
            return Solved(kind: .geometry, topic: "다각형의 내각의 합", concept: "n각형의 내각의 합은 180° × (n − 2)예요.", steps: steps, answer: polygonName(n, regular: !m[2].isEmpty))
        }
        return nil
    }

    /// "삼각형의 세 내각의 크기가 50°, 70°, x°" → x
    static func missingAngle(_ t: String) -> Solved? {
        guard has(t, ["내각", "각의 크기"]), t.contains("x"), t.contains("°") else { return nil }
        let shapes: [(String, Int)] = [("삼각형", 3), ("사각형", 4), ("오각형", 5), ("육각형", 6), ("칠각형", 7), ("팔각형", 8)]
        var sides: Int?
        for (word, n) in shapes where t.contains(word) && !t.contains("정" + word) { sides = sides == nil ? n : -1 }
        if let m = match(t, #"(\d+)\s*각형"#), let n = Int(m[1]) { sides = sides == nil ? n : -1 }
        guard let n = sides, n >= 3 else { return nil }
        let angles = matches(t, #"([0-9x+\-*/(). ]*[0-9x][0-9x+\-*/(). ]*)\s*°"#).map { $0[1].trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard angles.count == n else { return nil }
        let polys = angles.compactMap { DoitMath.polynomial($0) }
        guard polys.count == n else { return nil }
        var sum = DoitMath.Poly()
        for p in polys { sum = sum + p }
        let total = Double(180 * (n - 2))
        sum.c[0] -= total
        guard sum.degree == 1 else { return nil }
        let x = -sum[0] / sum[1]
        guard x > 0, polys.allSatisfy({ DoitMath.value($0, at: x) > 0 }) else { return nil }
        return Solved(kind: .geometry, topic: "다각형의 내각의 합", concept: "삼각형의 세 내각의 합은 180°, n각형은 180° × (n − 2)예요.",
                      steps: [SolutionStep(hint: "\(n)각형의 내각의 합은 \(Int(total))°", work: angles.map { $0 + "°" }.joined(separator: " + ") + " = \(Int(total))°"),
                              SolutionStep(hint: "x에 대해 풀면", work: "x = \(d(x))")],
                      answer: "x = \(d(x))")
    }

    // MARK: - 통계

    /// 쉼표로 이어진 자료 (가장 긴 것). x가 있으면 "x"로
    static func dataList(_ t: String, allowX: Bool = false) -> [String]? {
        let unit = #"(?:\s*(?:점|개|회|kg|cm|시간|분|명|권|살|세|m|g|°C|℃|번|mm|L))?"#
        let item = allowX ? #"(?:-?\d+(?:\.\d+)?|x)"# : #"-?\d+(?:\.\d+)?"#
        let pattern = item + unit + #"(?:\s*,\s*"# + item + unit + ")+"
        let runs = matches(t, pattern).map { $0[0] }
        guard let best = runs.max(by: { $0.count < $1.count }) else { return nil }
        let items = matches(best, allowX ? #"-?\d+(?:\.\d+)?|x"# : #"-?\d+(?:\.\d+)?"#).map { $0[0] }
        return items.count >= 2 ? items : nil
    }

    /// 평균이 주어지고 자료 하나가 x
    static func meanUnknown(_ t: String) -> Solved? {
        guard has(t, ["평균"]), let mm = match(t, #"평균(?:이|은|는)\s*(-?\d+(?:\.\d+)?)"#), let mean = Double(mm[1]),
              let items = dataList(t, allowX: true), items.filter({ $0 == "x" }).count == 1 else { return nil }
        let known = items.compactMap { Double($0) }
        let n = Double(items.count)
        let x = mean * n - known.reduce(0, +)
        return Solved(kind: .statistics, topic: "평균을 이용해 모르는 값 구하기", concept: "평균 = (자료의 합) ÷ (자료의 개수) → 자료의 합 = 평균 × 개수",
                      steps: [SolutionStep(hint: "자료 \(items.count)개의 합 = 평균 × 개수", work: "\(items.joined(separator: " + ")) = \(d(mean)) × \(items.count) = \(d(mean * n))"),
                              SolutionStep(hint: "x를 구하면", work: "x = \(d(mean * n)) − \(d(known.reduce(0, +))) = \(d(x))")],
                      answer: "x = \(d(x))")
    }

    // MARK: - 수열 (두 항이 주어진 등차·등비수열)

    static func twoTermSequence(_ t: String) -> Solved? {
        guard has(t, ["등차", "등비"]) else { return nil }
        let subscripts: [Character: Character] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9"]
        let plain = String(t.map { subscripts[$0] ?? $0 })
        var given: [(Int, Double)] = []
        for m in matches(plain, #"제\s*(\d+)\s*항(?:이|은|는|의 값이)?\s*(-?\d+(?:\.\d+)?)"#) {
            if let k = Int(m[1]), let v = Double(m[2]), !given.contains(where: { $0.0 == k }) { given.append((k, v)) }
        }
        for m in matches(plain, #"a_?(\d+)\s*=\s*(-?\d+(?:\.\d+)?)"#) {
            if let k = Int(m[1]), let v = Double(m[2]), !given.contains(where: { $0.0 == k }) { given.append((k, v)) }
        }
        guard given.count == 2, given[0].0 != given[1].0, !has(t, ["첫째항이", "첫째항은", "공차가", "공비가"]) else { return nil }
        let (k1, v1) = given[0], (k2, v2) = given[1]
        let asked = matches(plain, #"제\s*(\d+)\s*항"#).compactMap { Int($0[1]) }.filter { $0 != k1 && $0 != k2 }.first
        if has(t, ["등차"]) {
            let dd = (v2 - v1) / Double(k2 - k1), a1 = v1 - Double(k1 - 1) * dd
            var general = DoitMath.Poly(); general.c[1] = dd; general.c[0] = a1 - dd
            let formula = "aₙ = " + DoitMath.describe(general).replacingOccurrences(of: "x", with: "n")
            var steps = [SolutionStep(hint: "aₙ = a + (n − 1)d 에서", work: "a + \(k1 - 1)d = \(d(v1)), a + \(k2 - 1)d = \(d(v2))"),
                         SolutionStep(hint: "두 식을 빼면", work: "\(k2 - k1)d = \(d(v2 - v1)) → d = \(f(dd)), a = \(f(a1))"),
                         SolutionStep(hint: "일반항", work: formula)]
            let concept = "등차수열: aₙ = a + (n − 1)d. 두 항을 알면 차를 항 번호의 차로 나눠 공차를 구해요."
            if let n = asked {
                let value = a1 + Double(n - 1) * dd
                if has(t, ["합"]) {
                    let s = Double(n) * (2 * a1 + Double(n - 1) * dd) / 2
                    steps.append(SolutionStep(hint: "Sₙ = n{2a + (n − 1)d}/2", work: "S\(n) = \(f(s))"))
                    return Solved(kind: .sequence, topic: "등차수열", concept: concept, steps: steps, answer: "첫째항부터 제\(n)항까지의 합 \(f(s))")
                }
                steps.append(SolutionStep(hint: "n = \(n)을 넣으면", work: "a\(n) = \(f(value))"))
                return Solved(kind: .sequence, topic: "등차수열", concept: concept, steps: steps, answer: "제\(n)항 \(f(value))")
            }
            if has(t, ["공차"]) && !has(t, ["일반항"]) { return Solved(kind: .sequence, topic: "등차수열", concept: concept, steps: steps, answer: "공차 \(f(dd))") }
            if has(t, ["첫째항"]) && !has(t, ["일반항"]) { return Solved(kind: .sequence, topic: "등차수열", concept: concept, steps: steps, answer: "첫째항 \(f(a1))") }
            return Solved(kind: .sequence, topic: "등차수열의 일반항", concept: concept, steps: steps, answer: formula)
        }
        // 등비: r^(k2−k1) = v2/v1
        guard v1 != 0 else { return nil }
        let q = v2 / v1, e = k2 - k1
        guard e != 0 else { return nil }
        var r: Double
        if e % 2 != 0 {
            r = q < 0 ? -pow(-q, 1 / Double(e)) : pow(q, 1 / Double(e))
        } else {
            // 짝수 제곱이면 ±r 두 가지라, 공비가 양수라고 했을 때만
            guard q > 0, has(t, ["공비는 양수", "공비가 양수", "모든 항이 양수", "양의 실수"]) else { return nil }
            r = pow(q, 1 / Double(e))
        }
        if abs(r - r.rounded()) < 1e-9 { r = r.rounded() }
        guard abs(pow(r, Double(e)) - q) < 1e-9 * max(1, abs(q)) else { return nil }
        let a1 = v1 / pow(r, Double(k1 - 1))
        let concept = "등비수열: aₙ = a × rⁿ⁻¹. 두 항을 알면 나눠서 rᵏ를 구해요."
        var steps = [SolutionStep(hint: "aₙ = arⁿ⁻¹ 에서 두 항을 나누면", work: "r^\(e) = \(f(q)) → r = \(f(r))"),
                     SolutionStep(hint: "첫째항", work: "a = \(f(a1))")]
        let formula = "aₙ = \(f(a1) == "1" ? "" : f(a1) + " × ")\(r < 0 ? "(\(f(r)))" : f(r))ⁿ⁻¹"
        if let n = asked {
            let value = a1 * pow(r, Double(n - 1))
            steps.append(SolutionStep(hint: "n = \(n)을 넣으면", work: "a\(n) = \(d(value))"))
            return Solved(kind: .sequence, topic: "등비수열", concept: concept, steps: steps, answer: "제\(n)항 \(d(value))")
        }
        if has(t, ["공비"]) && !has(t, ["일반항"]) { return Solved(kind: .sequence, topic: "등비수열", concept: concept, steps: steps, answer: "공비 \(f(r))") }
        steps.append(SolutionStep(hint: "일반항", work: formula))
        return Solved(kind: .sequence, topic: "등비수열의 일반항", concept: concept, steps: steps, answer: formula)
    }

    // MARK: - 직선 (기울기와 절편)

    static func lineFromSlopeIntercept(_ t: String) -> Solved? {
        guard DoitMathTopics.points(in: t).isEmpty, has(t, ["직선", "일차함수", "그래프"]),
              let sm = match(t, #"기울기(?:가|는)\s*(-?\d+(?:\.\d+)?(?:/\d+)?)"#), let m = ratParse(sm[1].replacingOccurrences(of: "-", with: "")).map({ sm[1].hasPrefix("-") ? -$0.value : $0.value }) else { return nil }
        var line = DoitMath.Poly()
        line.c[1] = m
        var steps: [SolutionStep]
        if let bm = match(t, #"y\s*절편(?:이|은|는)\s*(-?\d+(?:\.\d+)?(?:/\d+)?)"#), let b = ratParse(bm[1].replacingOccurrences(of: "-", with: "")).map({ bm[1].hasPrefix("-") ? -$0.value : $0.value }) {
            line.c[0] = b
            steps = [SolutionStep(hint: "기울기 a, y절편 b인 직선은 y = ax + b", work: "a = \(f(m)), b = \(f(b))")]
        } else if let xm = match(t, #"x\s*절편(?:이|은|는)\s*(-?\d+(?:\.\d+)?)"#), let p = Double(xm[1]) {
            line.c[0] = -m * p
            steps = [SolutionStep(hint: "x절편이 \(f(p))이면 점 (\(f(p)), 0)을 지나요", work: "y = \(f(m))(x − (\(f(p))))")]
        } else { return nil }
        let answer = "y = \(DoitMath.describe(line))"
        steps.append(SolutionStep(hint: "직선의 방정식", work: answer))
        return Solved(kind: .coordinate, topic: "직선의 방정식", concept: "기울기가 a이고 y절편이 b인 직선은 y = ax + b 예요.", steps: steps, answer: answer)
    }

    // MARK: - 넓이·부피에서 길이

    static func inverseGeometry(_ raw: String) -> Solved? {
        let t = raw.replacingOccurrences(of: #"(cm|m|mm|km)\s*\^\s*[23]|㎠|㎤|cm²|cm³"#, with: "", options: .regularExpression)
        let num = #"(\d+(?:\.\d+)?)"#
        if let m = match(t, #"넓이가\s*"# + num + #"\s*인\s*정사각형"#), let a = Double(m[1]), has(t, ["한 변"]) {
            let side = DoitAlgebra.sqrtText(a)
            return Solved(kind: .geometry, topic: "정사각형의 한 변", concept: "정사각형의 넓이 = (한 변)²",
                          steps: [SolutionStep(hint: "한 변을 a라 하면 a² = \(d(a))", work: "a = √\(d(a)) = \(side)")], answer: side)
        }
        if let m = match(t, #"둘레(?:의\s*길이)?가\s*"# + num + #"\s*인\s*정사각형"#), let p = Double(m[1]), has(t, ["한 변"]) {
            return Solved(kind: .geometry, topic: "정사각형의 한 변", concept: "정사각형의 둘레 = 4 × (한 변)",
                          steps: [SolutionStep(hint: "둘레 ÷ 4", work: "\(d(p)) ÷ 4 = \(d(p / 4))")], answer: d(p / 4))
        }
        if let m = match(t, #"부피가\s*"# + num + #"\s*인\s*정육면체"#), let v = Double(m[1]), has(t, ["모서리", "한 변"]) {
            let edge = pow(v, 1.0 / 3).rounded()
            guard abs(edge * edge * edge - v) < 1e-9 else { return nil }
            return Solved(kind: .geometry, topic: "정육면체의 한 모서리", concept: "정육면체의 부피 = (한 모서리)³",
                          steps: [SolutionStep(hint: "a³ = \(d(v))", work: "a = \(d(edge))")], answer: d(edge))
        }
        if let m = match(t, #"넓이가\s*"# + num + #"\s*π\s*인\s*원"#), let a = Double(m[1]), has(t, ["반지름"]) {
            let r = DoitAlgebra.sqrtText(a)
            return Solved(kind: .geometry, topic: "원의 반지름", concept: "원의 넓이 = πr²",
                          steps: [SolutionStep(hint: "πr² = \(d(a))π", work: "r² = \(d(a)) → r = \(r)")], answer: r)
        }
        if let m = match(t, #"(?:둘레|원주)(?:의\s*길이)?가\s*"# + num + #"\s*π\s*인\s*원"#), let c = Double(m[1]), has(t, ["반지름"]) {
            return Solved(kind: .geometry, topic: "원의 반지름", concept: "원의 둘레 = 2πr",
                          steps: [SolutionStep(hint: "2πr = \(d(c))π", work: "r = \(d(c / 2))")], answer: d(c / 2))
        }
        if let m = match(t, #"넓이가\s*"# + num + #"\s*인\s*직사각형"#), let area = Double(m[1]),
           let w = match(t, #"(가로|세로)(?:의\s*길이)?가\s*"# + num), let side = Double(w[2]), side > 0, has(t, [w[1] == "가로" ? "세로" : "가로"]) {
            let other = w[1] == "가로" ? "세로" : "가로"
            return Solved(kind: .geometry, topic: "직사각형의 변의 길이", concept: "직사각형의 넓이 = 가로 × 세로",
                          steps: [SolutionStep(hint: "\(other) = 넓이 ÷ \(w[1])", work: "\(d(area)) ÷ \(d(side)) = \(d(area / side))")], answer: d(area / side))
        }
        return nil
    }
}
