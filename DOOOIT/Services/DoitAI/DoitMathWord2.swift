import Foundation

/// 두잇 AI 문장제 2 (외부 AI 없이): 연립방정식이 되는 문장제, 만남·따라잡기, 기차, 강물, 일의 양, 물탱크, 시계
/// 문장의 모양이 확실할 때만 풀고, 애매하면 nil
enum DoitMathWord2 {
    typealias Solved = MathSolver.Solved

    private static func has(_ t: String, _ w: [String]) -> Bool { w.contains { t.contains($0) } }
    private static func f(_ v: Double) -> String { DoitMath.fraction(v) }
    private static func d(_ v: Double) -> String { DoitMath.format(v, digits: 8) }
    private static func match(_ t: String, _ p: String) -> [String]? { DoitMathExact.match(t, p) }
    private static func matches(_ t: String, _ p: String) -> [[String]] { DoitMathExact.matches(t, p) }
    private static let num = #"(\d+(?:\.\d+)?)"#

    static func solve(_ t: String) -> Solved? {
        if let s = digitSwap(t) { return s }
        if let s = admission(t) { return s }
        if let s = ageSumFuture(t) { return s }
        if let s = rectanglePerimeter(t) { return s }
        if let s = moneyRelation(t) { return s }
        if let s = lapMeeting(t) { return s }
        if let s = facingMeeting(t) { return s }
        if let s = chase(t) { return s }
        if let s = train(t) { return s }
        if let s = stream(t) { return s }
        if let s = work(t) { return s }
        if let s = clock(t) { return s }
        if let s = meanChange(t) { return s }
        return nil
    }

    // MARK: - 연립방정식 (문자 a, b로 쓴 것, A = B = C 꼴)

    /// "a + b = 5, 2a − b = 4", "x + y = 2x − y = 6" → x, y, z로 바꿔서 연립방정식 풀이
    static func letterSystem(_ t: String) -> Solved? {
        let pieces = t.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
        // A = B = C
        if t.contains("x"), pieces.contains(where: { DoitAlgebra.extract($0).filter { $0 == "=" }.count == 2 }) {
            var rebuilt: [String] = []
            for piece in pieces {
                let e = DoitAlgebra.extract(piece)
                let sides = e.split(separator: "=").map(String.init)
                if sides.count == 3 { rebuilt += ["\(sides[0]) = \(sides[2])", "\(sides[1]) = \(sides[2])"] } else if !e.isEmpty { rebuilt.append(e) }
            }
            guard let s = DoitAlgebra.solveSystem(rebuilt.joined(separator: ", ")) else { return nil }
            var out = s
            out.steps.insert(SolutionStep(hint: "A = B = C 꼴은 A = C, B = C 두 식으로 나눠요", work: rebuilt.joined(separator: ", ")), at: 0)
            return out
        }
        // 문자 a, b, c로 쓴 연립방정식
        guard has(t, ["연립"]), !t.contains("x"), !t.contains("y") else { return nil }
        let letters = Array(Set(t.filter { "abcpqmn".contains($0) })).sorted()
        guard (2...3).contains(letters.count) else { return nil }
        let map: [Character: Character] = Dictionary(uniqueKeysWithValues: zip(letters, ["x", "y", "z"] as [Character]))
        let back: [Character: Character] = Dictionary(uniqueKeysWithValues: map.map { ($0.value, $0.key) })
        let swapped = String(t.map { map[$0] ?? $0 })
        guard var s = DoitAlgebra.solveSystem(swapped) else { return nil }
        func undo(_ text: String) -> String { String(text.map { back[$0] ?? $0 }) }
        s.answer = undo(s.answer)
        s.steps = s.steps.map { SolutionStep(hint: undo($0.hint), work: undo($0.work)) }
        return s
    }

    // MARK: - 두 자리 자연수 (자리 바꾸기)

    static func digitSwap(_ t: String) -> Solved? {
        guard has(t, ["두 자리"]), has(t, ["바꾼"]),
              let sumM = match(t, #"(?:각\s*)?자리(?:의)?\s*숫자의\s*합(?:은|이)\s*(\d+)"#), let sum = Int(sumM[1]),
              let diffM = match(t, #"처음\s*수(?:보다|의)\s*(\d+)\s*(?:만큼\s*)?(크|작)"#), let diff = Int(diffM[1]) else { return nil }
        // 바꾼 수 − 처음 수 = 9(u − t) = ±diff
        let signed = diffM[2] == "크" ? diff : -diff
        guard signed % 9 == 0 else { return nil }
        let k = signed / 9
        guard (sum + k) % 2 == 0 else { return nil }
        let u = (sum + k) / 2, tens = (sum - k) / 2
        guard (1...9).contains(tens), (0...9).contains(u) else { return nil }
        let n = 10 * tens + u
        return Solved(kind: .system, topic: "연립방정식의 활용 (자리의 숫자)",
                      concept: "십의 자리 숫자를 x, 일의 자리 숫자를 y라 하면 처음 수는 10x + y, 바꾼 수는 10y + x예요.",
                      steps: [SolutionStep(hint: "자리의 숫자의 합", work: "x + y = \(sum)"),
                              SolutionStep(hint: "바꾼 수와 처음 수의 관계", work: "(10y + x) − (10x + y) = \(signed) → y − x = \(k)"),
                              SolutionStep(hint: "연립하여 풀면", work: "x = \(tens), y = \(u)")],
                      answer: "\(n)")
    }

    // MARK: - 입장료 · 물건값 (두 가지를 합하여 몇 개, 모두 얼마)

    static func admission(_ raw: String) -> Solved? {
        let t = raw.replacingOccurrences(of: #"(\d),(\d{3})(?!\d)"#, with: "$1$2", options: .regularExpression)
        guard has(t, ["합하여", "모두", "합해서"]), has(t, ["원"]) else { return nil }
        // "어른이 1500원, 어린이가 800원" / "한 개에 600원인 연필과 한 개에 1000원인 볼펜"
        var items: [(String, Double)] = []
        for m in matches(t, #"([가-힣]+)(?:이|가|은|는)\s*(?:한\s*명에\s*|1인당\s*)?(\d+)\s*원"#) {
            if let v = Double(m[2]), !items.contains(where: { $0.0 == m[1] }) { items.append((m[1], v)) }
        }
        if items.count != 2 {
            items = []
            for m in matches(t, #"(?:한\s*(?:개|자루|권|장)에\s*)?(\d+)\s*원(?:인|짜리)\s*([가-힣]+?)(?:과|와|을|를|\s|,)"#) {
                if let v = Double(m[1]) { items.append((m[2], v)) }
            }
        }
        guard items.count == 2, items[0].1 != items[1].1,
              let countM = match(t, #"합하여\s*(\d+)\s*(명|개|자루|권|장|마리)"#) ?? match(t, #"모두\s*(\d+)\s*(명|개|자루|권|장|마리)"#),
              let total = Double(countM[1]) else { return nil }
        // 낸 돈: 금액 중에서 단가가 아닌 것
        let amounts = matches(t, #"(\d+)\s*원(?!인|짜리)"#).compactMap { Double($0[1]) }.filter { $0 != items[0].1 && $0 != items[1].1 }
        guard amounts.count == 1, let paid = amounts.first else { return nil }
        let (n1, p1) = items[0], (n2, p2) = items[1]
        // p1·x + p2·(total − x) = paid
        let x = (paid - p2 * total) / (p1 - p2)
        let y = total - x
        guard x >= 0, y >= 0, abs(x - x.rounded()) < 1e-9 else { return nil }
        let unit = countM[2]
        let askFirst = t.range(of: "\(n1)\\S{0,3}\\s*(?:은|는)?\\s*몇", options: .regularExpression) != nil
        let askSecond = t.range(of: "\(n2)\\S{0,3}\\s*(?:은|는)?\\s*몇", options: .regularExpression) != nil
        guard askFirst != askSecond else { return nil }
        let answer = askFirst ? "\(n1) \(d(x))\(unit)" : "\(n2) \(d(y))\(unit)"
        return Solved(kind: .system, topic: "연립방정식의 활용 (개수와 금액)",
                      concept: "개수의 합으로 식 하나, 금액의 합으로 식 하나를 세워 연립해요.",
                      steps: [SolutionStep(hint: "\(n1)을 x\(unit), \(n2)를 y\(unit)라 하면", work: "x + y = \(d(total)), \(d(p1))x + \(d(p2))y = \(d(paid))"),
                              SolutionStep(hint: "연립하여 풀면", work: "x = \(d(x)), y = \(d(y))")],
                      answer: answer)
    }

    // MARK: - 나이의 합 + 몇 년 후 몇 배

    static func ageSumFuture(_ t: String) -> Solved? {
        guard let sumM = match(t, #"나이의\s*합(?:은|이)\s*(\d+)\s*(?:세|살)"#), let sum = Double(sumM[1]),
              let laterM = match(t, #"(\d+)\s*년\s*(후|전)(?:에는|에)?\s*,?\s*([가-힣]+?)의\s*나이(?:가|는)\s*([가-힣]+?)의\s*나이의\s*(\d+)\s*배"#),
              let years = Double(laterM[1]), let k = Double(laterM[5]), k > 1 else { return nil }
        let shift = laterM[2] == "후" ? years : -years
        // 큰 사람 = k × 작은 사람 (그때) : (S − s + shift) = k(s + shift) → s = (S + shift − k·shift)/(k + 1)
        let small = (sum + shift - k * shift) / (k + 1)
        let big = sum - small
        guard small > 0, big > 0 else { return nil }
        let bigName = laterM[3], smallName = laterM[4]
        let asksSmall = t.range(of: "\(smallName)의\\s*나이(?:는|를)\\s*(?:몇|구|\\?)", options: .regularExpression) != nil || t.hasSuffix("\(smallName)의 나이는?")
        let asksBig = t.range(of: "\(bigName)의\\s*나이(?:는|를)\\s*(?:몇|구|\\?)", options: .regularExpression) != nil
        guard asksSmall || asksBig, !(asksSmall && asksBig) else { return nil }
        return Solved(kind: .system, topic: "연립방정식의 활용 (나이)",
                      concept: "현재 나이를 x, y로 놓고 '합'과 '몇 년 후의 관계'로 식 두 개를 세워요. 몇 년 후에는 두 사람 모두 그만큼 나이를 먹어요.",
                      steps: [SolutionStep(hint: "현재 \(bigName)의 나이를 x, \(smallName)의 나이를 y라 하면", work: "x + y = \(d(sum))"),
                              SolutionStep(hint: "\(d(years))년 \(laterM[2])의 관계", work: "x \(shift >= 0 ? "+" : "−") \(d(abs(shift))) = \(d(k))(y \(shift >= 0 ? "+" : "−") \(d(abs(shift))))"),
                              SolutionStep(hint: "연립하여 풀면", work: "x = \(d(big)), y = \(d(small))")],
                      answer: asksSmall ? "\(d(small))세" : "\(d(big))세")
    }

    // MARK: - 직사각형의 둘레

    static func rectanglePerimeter(_ t: String) -> Solved? {
        guard has(t, ["직사각형"]), let pm = match(t, #"둘레(?:의\s*길이)?(?:가|는|이)\s*"# + num + #"\s*(cm|m|mm|km)?"#), let perimeter = Double(pm[1]) else { return nil }
        let unit = pm[2].isEmpty ? "" : " " + pm[2]
        let half = perimeter / 2
        var width: Double?, height: Double?
        var relation = ""
        if let m = match(t, #"가로(?:의\s*길이)?(?:가|는)\s*세로(?:의\s*길이)?보다\s*"# + num + #"\s*(?:cm|m|mm|km)?\s*(?:만큼\s*)?(길|짧)"#), let k = Double(m[1]) {
            let s = m[2] == "길" ? k : -k
            height = (half - s) / 2; width = half - height!
            relation = "가로 = 세로 \(s >= 0 ? "+" : "−") \(d(abs(s)))"
        } else if let m = match(t, #"세로(?:의\s*길이)?(?:가|는)\s*가로(?:의\s*길이)?보다\s*"# + num + #"\s*(?:cm|m|mm|km)?\s*(?:만큼\s*)?(길|짧)"#), let k = Double(m[1]) {
            let s = m[2] == "길" ? k : -k
            width = (half - s) / 2; height = half - width!
            relation = "세로 = 가로 \(s >= 0 ? "+" : "−") \(d(abs(s)))"
        } else if let m = match(t, #"가로(?:의\s*길이)?(?:가|는)\s*세로(?:의\s*길이)?의\s*"# + num + #"\s*배"#), let k = Double(m[1]) {
            height = half / (k + 1); width = half - height!
            relation = "가로 = \(d(k)) × 세로"
        } else if let m = match(t, #"세로(?:의\s*길이)?(?:가|는)\s*가로(?:의\s*길이)?의\s*"# + num + #"\s*배"#), let k = Double(m[1]) {
            width = half / (k + 1); height = half - width!
            relation = "세로 = \(d(k)) × 가로"
        }
        guard let w = width, let h = height, w > 0, h > 0 else { return nil }
        var steps = [SolutionStep(hint: "둘레 = 2 × (가로 + 세로)", work: "가로 + 세로 = \(d(half))"),
                     SolutionStep(hint: "조건", work: relation),
                     SolutionStep(hint: "연립하여 풀면", work: "가로 \(d(w))\(unit), 세로 \(d(h))\(unit)")]
        let answer: String
        if has(t, ["넓이"]) {
            steps.append(SolutionStep(hint: "넓이 = 가로 × 세로", work: "\(d(w)) × \(d(h)) = \(d(w * h))"))
            answer = "\(d(w * h))" + (pm[2].isEmpty ? "" : " \(pm[2])²")
        } else if t.range(of: #"세로(?:의\s*길이)?(?:는|를|을)\s*(?:몇|구|\?)|세로의\s*길이는\?"#, options: .regularExpression) != nil {
            answer = "세로 \(d(h))\(unit)"
        } else if t.range(of: #"가로(?:의\s*길이)?(?:는|를|을)\s*(?:몇|구|\?)|가로의\s*길이는\?"#, options: .regularExpression) != nil {
            answer = "가로 \(d(w))\(unit)"
        } else { return nil }
        return Solved(kind: .system, topic: "연립방정식의 활용 (도형)", concept: "가로를 x, 세로를 y로 놓고 둘레와 조건으로 식 두 개를 세워요.", steps: steps, answer: answer)
    }

    // MARK: - 합이 S이고 A는 B의 k배보다 c 많다

    static func moneyRelation(_ raw: String) -> Solved? {
        let t = raw.replacingOccurrences(of: #"(\d),(\d{3})(?!\d)"#, with: "$1$2", options: .regularExpression)
        guard let sumM = match(t, #"합(?:은|이)\s*(\d+)\s*(원|개|명|권|장|점|살|세|cm|m|kg|g)?"#), let sum = Double(sumM[1]),
              let m = match(t, #"([A-Z가-힣]+)(?:가|이)\s*가진\s*[가-힣]+(?:은|는)\s*([A-Z가-힣]+)(?:가|이)\s*가진\s*[가-힣]+의\s*(\d+)\s*배보다\s*(\d+)\s*(?:원|개|명|권|장)?\s*(많|적)"#)
                ?? match(t, #"([A-Z가-힣]+)(?:는|은)\s*([A-Z가-힣]+)의\s*(\d+)\s*배보다\s*(\d+)\s*(?:원|개|명|권|장)?\s*(많|적)"#),
              let k = Double(m[3]), let c0 = Double(m[4]) else { return nil }
        let c = m[5] == "많" ? c0 : -c0
        // A = kB + c, A + B = S
        let b = (sum - c) / (k + 1), a = sum - b
        guard b >= 0, a >= 0 else { return nil }
        let unit = sumM[2]
        let asksB = t.range(of: "\(m[2])(?:가|이)\\s*가진\\s*[가-힣]+(?:은|는)\\s*(?:얼마|몇)", options: .regularExpression) != nil
        return Solved(kind: .system, topic: "연립방정식의 활용", concept: "모르는 두 양을 x, y로 놓고 '합'과 '관계'로 식 두 개를 세워 연립해요.",
                      steps: [SolutionStep(hint: "\(m[1])를 x, \(m[2])를 y라 하면", work: "x + y = \(d(sum)), x = \(d(k))y \(c >= 0 ? "+" : "−") \(d(abs(c)))"),
                              SolutionStep(hint: "대입법으로 풀면", work: "\(d(k + 1))y = \(d(sum - c)) → y = \(d(b)), x = \(d(a))")],
                      answer: asksB ? "\(d(b))\(unit)" : "\(d(a))\(unit)")
    }

    // MARK: - 속력 읽기 (분속 · 시속 · 초속 → m/분 등 단위를 맞춰서)

    struct Speed { var value: Double; var perSecond: Double }

    /// "분속 70 m", "시속 4 km", "초속 30 m" → 초당 m
    static func speeds(_ t: String) -> [(String, Speed)] {
        var out: [(String, Speed)] = []
        for m in matches(t, #"(분속|시속|초속)\s*(\d+(?:\.\d+)?)\s*(km|m)"#) {
            guard let v = Double(m[2]) else { continue }
            let meters = m[3] == "km" ? v * 1000 : v
            let seconds: Double = m[1] == "시속" ? 3600 : m[1] == "분속" ? 60 : 1
            out.append((m[1], Speed(value: v, perSecond: meters / seconds)))
        }
        return out
    }

    /// 거리 → m
    static func distance(_ s: String, _ unit: String) -> Double? {
        guard let v = Double(s) else { return nil }
        return unit == "km" ? v * 1000 : unit == "cm" ? v / 100 : v
    }

    /// 걸린 시간(초)을 묻는 단위로
    private static func timeAnswer(_ seconds: Double, _ t: String) -> String? {
        if has(t, ["몇 분", "몇분"]) {
            let minutes = seconds / 60
            return abs(minutes - minutes.rounded()) < 1e-9 ? "\(d(minutes))분 후" : "\(f(minutes))분 후"
        }
        if has(t, ["몇 시간", "몇시간"]) {
            let hours = seconds / 3600
            let whole = Int(hours + 1e-9)
            let minutes = (hours - Double(whole)) * 60
            if abs(minutes) < 1e-6 { return "\(whole)시간 후" }
            if abs(minutes - minutes.rounded()) < 1e-6 { return "\(d(hours))시간 후 (\(whole)시간 \(Int(minutes.rounded()))분)" }
            return "\(f(hours))시간 후"
        }
        if has(t, ["몇 초", "몇초"]) { return "\(d(seconds))초 후" }
        return nil
    }

    // MARK: - 호수 둘레를 돌다 만남 (반대 방향 / 같은 방향)

    static func lapMeeting(_ t: String) -> Solved? {
        guard has(t, ["둘레"]), has(t, ["만나"]), let lm = match(t, #"둘레(?:의\s*길이)?(?:가|는|이)\s*(\d+(?:\.\d+)?)\s*(km|m)"#),
              let lap = distance(lm[1], lm[2]) else { return nil }
        let sp = speeds(t)
        guard sp.count == 2 else { return nil }
        let opposite = has(t, ["반대 방향", "반대방향", "서로 반대"])
        let same = has(t, ["같은 방향", "같은방향"])
        guard opposite != same else { return nil }
        let rate = opposite ? sp[0].1.perSecond + sp[1].1.perSecond : abs(sp[0].1.perSecond - sp[1].1.perSecond)
        guard rate > 0, let answer = timeAnswer(lap / rate, t) else { return nil }
        let unitName = sp[0].0 == sp[1].0 ? sp[0].0 : "초속"
        let shown = unitName == sp[0].0 ? (opposite ? sp[0].1.value + sp[1].1.value : abs(sp[0].1.value - sp[1].1.value)) : rate
        return Solved(kind: .linear, topic: opposite ? "트랙에서 반대 방향으로 돌다 만나기" : "트랙에서 같은 방향으로 돌다 만나기",
                      concept: opposite ? "반대 방향이면 두 사람이 간 거리의 합이 한 바퀴일 때 만나요." : "같은 방향이면 두 사람이 간 거리의 차가 한 바퀴일 때 다시 만나요.",
                      steps: [SolutionStep(hint: opposite ? "1분(1시간)에 가까워지는 거리 = 속력의 합" : "1분(1시간)에 벌어지는 거리 = 속력의 차", work: "\(unitName) \(d(shown))"),
                              SolutionStep(hint: "한 바퀴 = \(d(lap)) m를 그 속력으로 나누면", work: answer)],
                      answer: answer)
    }

    // MARK: - 마주 보고 출발해서 만남

    static func facingMeeting(_ t: String) -> Solved? {
        guard has(t, ["마주"]), has(t, ["만나", "만날"]), !has(t, ["둘레"]) else { return nil }
        guard let dm = match(t, #"(\d+(?:\.\d+)?)\s*(km|m)\s*(?:떨어진|거리)"#) ?? match(t, #"거리(?:는|가)\s*(\d+(?:\.\d+)?)\s*(km|m)"#),
              let gap = distance(dm[1], dm[2]) else { return nil }
        let sp = speeds(t)
        guard sp.count == 2 else { return nil }
        let rate = sp[0].1.perSecond + sp[1].1.perSecond
        let seconds = gap / rate
        var steps = [SolutionStep(hint: "마주 보고 가면 두 사람이 간 거리의 합 = 처음 떨어진 거리", work: "\(dm[1]) \(dm[2])"),
                     SolutionStep(hint: "만나는 시간 = 거리 ÷ (속력의 합)", work: "\(d(gap)) m ÷ \(d(rate)) m/초 = \(d(seconds))초")]
        // 한 사람이 간 거리
        if let wm = match(t, #"([가-힣A-Z]+)(?:이|가)\s*(?:걸은|간|달린|이동한)\s*거리"#) {
            // 이름 뒤에 나오는 속력 찾기
            let name = wm[1]
            guard let range = t.range(of: name) else { return nil }
            let after = String(t[range.upperBound...])
            guard let mine = speeds(after).first else { return nil }
            let meters = mine.1.perSecond * seconds
            let km = has(t, ["몇 km"])
            steps.append(SolutionStep(hint: "\(name)이(가) 간 거리 = 속력 × 시간", work: "\(d(meters)) m"))
            return Solved(kind: .linear, topic: "마주 보고 출발해서 만나기", concept: "두 사람이 간 거리의 합 = 처음 떨어진 거리", steps: steps, answer: km ? "\(d(meters / 1000)) km" : "\(d(meters)) m")
        }
        guard let answer = timeAnswer(seconds, t) else { return nil }
        steps.append(SolutionStep(hint: "단위를 맞추면", work: answer))
        return Solved(kind: .linear, topic: "마주 보고 출발해서 만나기", concept: "두 사람이 간 거리의 합 = 처음 떨어진 거리, 시간 = 거리 ÷ (두 속력의 합)", steps: steps, answer: answer)
    }

    // MARK: - 먼저 출발한 사람을 따라잡기

    static func chase(_ t: String) -> Solved? {
        guard has(t, ["따라"]), has(t, ["만나", "따라잡"]),
              let lagM = match(t, #"(\d+(?:\.\d+)?)\s*(분|시간)\s*(?:후|뒤)에"#), let lag = Double(lagM[1]) else { return nil }
        let sp = speeds(t)
        guard sp.count == 2 else { return nil }
        // 먼저 출발한 사람: 문장에서 "출발한 지 … 후에" 앞에 나온 사람 → 첫 번째로 나온 속력이 느린 쪽이어야 따라잡음
        let lagSeconds = lag * (lagM[2] == "시간" ? 3600 : 60)
        let first: Speed, second: Speed
        // 사람마다 속력: "동생은 분속 60 m", "형이 분속 80 m로"
        let name = "([A-Z]|형|동생|누나|언니|오빠|아버지|어머니|아빠|엄마)"
        var mine: [String: Speed] = [:]
        for m in matches(t, name + #"(?:은|는|이|가)\s*(?:[가-힣]+(?:에서|으로|로)\s*)?(분속|시속|초속)\s*(\d+(?:\.\d+)?)\s*(km|m)"#) {
            if mine[m[1]] == nil, let v = speeds(String(m[0])).first?.1 { mine[m[1]] = v }
        }
        if mine.count == 2, let follower = match(t, #"(?:후에|뒤에)\s*"# + name + #"(?:이|가|은|는)"#)?[1], let f2 = mine[follower],
           let leader = mine.first(where: { $0.key != follower })?.value {
            first = leader
            second = f2
        } else if mine.isEmpty || !has(t, ["형", "동생", "누나", "언니", "오빠"]) {
            // 문장에 먼저 나온 속력이 먼저 출발한 사람
            first = sp[0].1
            second = sp[1].1
        } else { return nil }
        guard second.perSecond > first.perSecond else { return nil }
        let head = first.perSecond * lagSeconds
        let seconds = head / (second.perSecond - first.perSecond)
        guard let answer = timeAnswer(seconds, t) else { return nil }
        return Solved(kind: .linear, topic: "따라잡기 (같은 방향)", concept: "나중에 출발한 사람이 x분 후에 만난다면, 두 사람이 간 거리가 같아요. 먼저 간 거리 ÷ 속력의 차 = 따라잡는 시간",
                      steps: [SolutionStep(hint: "먼저 출발한 사람이 \(d(lag))\(lagM[2]) 동안 간 거리", work: "\(d(head)) m"),
                              SolutionStep(hint: "1초마다 줄어드는 거리 = 속력의 차", work: "\(d(second.perSecond - first.perSecond)) m/초"),
                              SolutionStep(hint: "따라잡는 시간", work: answer)],
                      answer: answer)
    }

    // MARK: - 기차가 터널 · 다리를 지나기

    static func train(_ t: String) -> Solved? {
        guard has(t, ["기차", "열차"]), has(t, ["터널", "다리", "철교"]), has(t, ["통과", "지나", "건너"]) else { return nil }
        // 길이들
        let trainLength = match(t, #"길이(?:가|는)?\s*(\d+(?:\.\d+)?)\s*m\s*인\s*(?:기차|열차)"#).flatMap { Double($0[1]) }
        var structures: [(Double, Double?)] = [] // (길이, 걸린 초)
        for m in matches(t, #"길이(?:가|는)?\s*(\d+(?:\.\d+)?)\s*m\s*인\s*(?:터널|다리|철교)([^0-9]{0,30}?(\d+(?:\.\d+)?)\s*(초|분))?"#) {
            guard let len = Double(m[1]) else { continue }
            var sec: Double? = Double(m[3])
            if m[4] == "분", let s = sec { sec = s * 60 }
            structures.append((len, sec))
        }
        let sp = speeds(t)
        let concept = "기차가 터널(다리)을 완전히 통과하려면 (터널의 길이 + 기차의 길이)만큼 달려야 해요."
        if structures.count == 2, let s1 = structures[0].1, let s2 = structures[1].1, sp.isEmpty, trainLength == nil {
            // (L1 + x)/s1 = (L2 + x)/s2
            let (l1, l2) = (structures[0].0, structures[1].0)
            guard abs(s1 - s2) > 1e-12 else { return nil }
            let x = (l2 * s1 - l1 * s2) / (s2 - s1)
            let v = (l1 + x) / s1
            guard x > 0, v > 0 else { return nil }
            let asksSpeed = has(t, ["속력", "초속 몇", "몇 m/s"]) && !has(t, ["기차의 길이", "열차의 길이"])
            return Solved(kind: .linear, topic: "기차의 길이와 속력", concept: concept,
                          steps: [SolutionStep(hint: "기차의 길이를 x m라 하면 속력이 같으므로", work: "(\(d(l1)) + x)/\(d(s1)) = (\(d(l2)) + x)/\(d(s2))"),
                                  SolutionStep(hint: "풀면", work: "x = \(d(x)), 속력 = 초속 \(d(v)) m")],
                          answer: asksSpeed ? "초속 \(d(v)) m" : "\(d(x)) m")
        }
        guard structures.count == 1 else { return nil }
        let (len, secs) = structures[0]
        if let L = trainLength, let v = sp.first?.1.perSecond, secs == nil {
            let seconds = (L + len) / v
            return Solved(kind: .linear, topic: "기차가 터널을 통과하는 시간", concept: concept,
                          steps: [SolutionStep(hint: "달려야 하는 거리 = 터널 + 기차", work: "\(d(len)) + \(d(L)) = \(d(len + L)) m"),
                                  SolutionStep(hint: "시간 = 거리 ÷ 속력", work: "\(d(len + L)) ÷ \(d(v)) = \(d(seconds))초")],
                          answer: has(t, ["몇 분"]) ? "\(d(seconds / 60))분" : "\(d(seconds))초")
        }
        guard let s = secs else { return nil }
        if let L = trainLength, sp.isEmpty {
            let v = (L + len) / s
            return Solved(kind: .linear, topic: "기차의 속력", concept: concept,
                          steps: [SolutionStep(hint: "달린 거리 = 터널(다리) + 기차", work: "\(d(len)) + \(d(L)) = \(d(len + L)) m"),
                                  SolutionStep(hint: "속력 = 거리 ÷ 시간", work: "\(d(len + L)) ÷ \(d(s)) = \(d(v))")],
                          answer: "초속 \(d(v)) m")
        }
        if trainLength == nil, let v = sp.first?.1.perSecond {
            let L = v * s - len
            guard L > 0 else { return nil }
            return Solved(kind: .linear, topic: "기차의 길이", concept: concept,
                          steps: [SolutionStep(hint: "\(d(s))초 동안 달린 거리", work: "\(d(v)) × \(d(s)) = \(d(v * s)) m"),
                                  SolutionStep(hint: "기차의 길이 = 달린 거리 − 터널(다리)의 길이", work: "\(d(v * s)) − \(d(len)) = \(d(L)) m")],
                          answer: "\(d(L)) m")
        }
        return nil
    }

    // MARK: - 강물 (거슬러 올라감 · 내려옴)

    static func stream(_ t: String) -> Solved? {
        guard has(t, ["강", "물"]), has(t, ["거슬러", "올라", "상류"]), has(t, ["배"]) else { return nil }
        let concept = "올라갈 때 속력 = 배의 속력 − 강물의 속력, 내려갈 때 속력 = 배의 속력 + 강물의 속력"
        // 정지한 물에서 배의 속력과 강물의 속력이 주어지고 시간을 물음
        if let bm = match(t, #"(?:흐르지\s*않는\s*물|정지한\s*물|잔잔한\s*물)에서의?\s*속력(?:이|은)\s*시속\s*(\d+(?:\.\d+)?)\s*km"#), let boat = Double(bm[1]),
           let cm = match(t, #"시속\s*(\d+(?:\.\d+)?)\s*km\s*로\s*흐르는"#) ?? match(t, #"강물의\s*속력(?:이|은)\s*시속\s*(\d+(?:\.\d+)?)\s*km"#), let current = Double(cm[1]),
           let dm = match(t, #"(\d+(?:\.\d+)?)\s*km\s*(?:를|을)?\s*(거슬러|내려)"#), let dist = Double(dm[1]) {
            let up = dm[2] == "거슬러"
            let v = up ? boat - current : boat + current
            guard v > 0 else { return nil }
            let hours = dist / v
            let whole = Int(hours + 1e-9), minutes = (hours - Double(whole)) * 60
            let text = abs(minutes) < 1e-6 ? "\(whole)시간" : abs(minutes - minutes.rounded()) < 1e-6 ? "\(whole)시간 \(Int(minutes.rounded()))분" : "\(f(hours))시간"
            return Solved(kind: .linear, topic: "강물의 흐름과 배의 속력", concept: concept,
                          steps: [SolutionStep(hint: up ? "거슬러 올라갈 때의 속력" : "내려갈 때의 속력", work: "\(d(boat)) \(up ? "−" : "+") \(d(current)) = 시속 \(d(v)) km"),
                                  SolutionStep(hint: "시간 = 거리 ÷ 속력", work: "\(d(dist)) ÷ \(d(v)) = \(f(hours))시간 = \(text)")],
                          answer: text)
        }
        // 강물의 속력이 주어지고, 올라가는 데 a시간, 내려오는 데 b시간 (같은 거리) → 배의 속력
        if let cm = match(t, #"강물의\s*속력(?:이|은)\s*시속\s*(\d+(?:\.\d+)?)\s*km"#), let current = Double(cm[1]),
           let um = match(t, #"(?:거슬러\s*)?올라가는\s*데\s*(\d+(?:\.\d+)?)\s*시간"#), let up = Double(um[1]),
           let dn = match(t, #"내려오는\s*데\s*(\d+(?:\.\d+)?)\s*시간"#) ?? match(t, #"내려가는\s*데\s*(\d+(?:\.\d+)?)\s*시간"#), let down = Double(dn[1]),
           has(t, ["배의 속력"]), abs(up - down) > 1e-12 {
            // up(v − c) = down(v + c)
            let v = current * (up + down) / (up - down)
            guard v > current else { return nil }
            return Solved(kind: .linear, topic: "강물의 흐름과 배의 속력", concept: concept,
                          steps: [SolutionStep(hint: "정지한 물에서의 배의 속력을 시속 x km라 하면 거리가 같으므로", work: "\(d(up))(x − \(d(current))) = \(d(down))(x + \(d(current)))"),
                                  SolutionStep(hint: "풀면", work: "x = \(d(v))")],
                          answer: "시속 \(d(v)) km")
        }
        // 거리와 왕복 시간 → 강물(배)의 속력
        if let dm = match(t, #"(\d+(?:\.\d+)?)\s*km\s*떨어진"#), let dist = Double(dm[1]),
           let dn = match(t, #"내려(?:갈|올)\s*때(?:는|에는)?\s*(\d+(?:\.\d+)?)\s*시간"#), let down = Double(dn[1]),
           let um = match(t, #"올라(?:올|갈)\s*때(?:는|에는)?\s*(\d+(?:\.\d+)?)\s*시간"#), let up = Double(um[1]) {
            let vd = dist / down, vu = dist / up
            let boat = (vd + vu) / 2, current = (vd - vu) / 2
            guard current > 0 else { return nil }
            let asksCurrent = has(t, ["강물의 속력"])
            return Solved(kind: .system, topic: "강물의 흐름과 배의 속력", concept: concept,
                          steps: [SolutionStep(hint: "내려갈 때 속력 = 배 + 강물", work: "\(d(dist)) ÷ \(d(down)) = 시속 \(d(vd)) km"),
                                  SolutionStep(hint: "올라갈 때 속력 = 배 − 강물", work: "\(d(dist)) ÷ \(d(up)) = 시속 \(d(vu)) km"),
                                  SolutionStep(hint: "두 식을 더하고 빼서 나누면", work: "배 = 시속 \(d(boat)) km, 강물 = 시속 \(d(current)) km")],
                          answer: asksCurrent ? "시속 \(d(current)) km" : "시속 \(d(boat)) km")
        }
        return nil
    }

    // MARK: - 일의 양 · 물탱크

    static func work(_ t: String) -> Solved? {
        let isTank = has(t, ["물탱크", "물통", "수조", "호스", "관으로", "수도"])
        guard has(t, ["일을", "일이", "걸린", "걸리", "끝낸", "완성"]) || isTank else { return nil }
        let unitPattern = #"(\d+(?:\.\d+)?)\s*(일|시간|분)"#
        // A는 6일, B는 3일 / A가 혼자 하면 10일 / A 호스로는 4시간 / A관으로 3시간
        // "함께 하면 4일 걸리는 일을 A가 혼자 하면 12일" → 나머지 한 사람
        let combined = match(t, #"(?:함께|같이|둘이)\s*(?:하면|할 때|해서|일하면)?\s*"# + unitPattern)
        var people: [(String, Double, String)] = []
        for m in matches(t, #"([A-Z]|형|동생|언니|누나|오빠|아버지|어머니)\s*(?:가|이|는|은)?\s*[^0-9A-Z.,]{0,14}?"# + unitPattern + #"(?:이|가|만에|동안|씩)?"#) {
            if m[0].contains("함께") || m[0].contains("같이") { continue }
            guard let v = Double(m[2]), !people.contains(where: { $0.0 == m[1] }) else { continue }
            people.append((m[1], v, m[3]))
            if people.count == 2 { break }
        }
        if let c = combined, let together = Double(c[1]), people.count == 1, people[0].2 == c[2] {
            let (a, ta) = (people[0].0, people[0].1)
            let rest = 1 / together - 1 / ta
            guard rest > 0, let other = match(t, "(?<![가-힣])([A-Z]|형|동생|언니|누나|오빠)(?:가|이|는|은)\\s*혼자\\s*(?:하면|할 때|일하면)?\\s*(?:며칠|몇)").map({ $0[1] }), other != a else { return nil }
            let unit = c[2]
            return Solved(kind: .linear, topic: "일의 양", concept: "전체 일의 양을 1로 놓으면 혼자 x\(unit) 걸리는 사람은 1\(unit)에 1/x만큼 해요. 함께 하면 일의 양을 더해요.",
                          steps: [SolutionStep(hint: "함께 하면 1\(unit)에", work: "1/\(d(together))"),
                                  SolutionStep(hint: "\(other)가 1\(unit)에 하는 일 = 함께 − \(a)", work: "1/\(d(together)) − 1/\(d(ta)) = \(f(rest))"),
                                  SolutionStep(hint: "\(other)가 혼자 하면", work: "1 ÷ \(f(rest)) = \(f(1 / rest))\(unit)")],
                          answer: "\(f(1 / rest))\(unit)")
        }
        guard combined == nil, people.count == 2, people[0].2 == people[1].2 else { return nil }
        let unit = people[0].2
        let (a, ta) = (people[0].0, people[0].1), (b, tb) = (people[1].0, people[1].1)
        let ra = 1 / ta, rb = 1 / tb
        let concept = "전체 일의 양을 1로 놓으면 혼자 x\(unit) 걸리는 사람은 1\(unit)에 1/x만큼 해요. 함께 하면 일의 양을 더해요."
        // 비우는 관
        let draining = has(t, ["비우", "빼", "빠지"]) && isTank
        // A가 k일 동안 한 후 나머지를 B가
        if let m = match(t, "\(a)(?:가|이)\\s*\(unitPattern)\\s*동안\\s*(?:일을\\s*)?(?:한|하고)\\s*(?:후|뒤)?[^0-9]*나머지를\\s*\(b)(?:가|이)"), let k = Double(m[1]) {
            let rest = 1 - k * ra
            guard rest > 0 else { return nil }
            let days = rest / rb
            return Solved(kind: .linear, topic: "일의 양", concept: concept,
                          steps: [SolutionStep(hint: "\(a)가 \(d(k))\(unit) 동안 한 일", work: "\(d(k)) × 1/\(d(ta)) = \(f(k * ra))"),
                                  SolutionStep(hint: "남은 일", work: "1 − \(f(k * ra)) = \(f(rest))"),
                                  SolutionStep(hint: "\(b)가 1\(unit)에 1/\(d(tb))씩 하므로", work: "\(f(rest)) ÷ 1/\(d(tb)) = \(f(days))\(unit)")],
                          answer: "\(f(days))\(unit)")
        }
        guard has(t, ["함께", "같이", "동시에", "둘이", "두 사람이"]) else { return nil }
        let rate = draining ? ra - rb : ra + rb
        guard rate > 0 else { return nil }
        let time = 1 / rate
        let shown = time == time.rounded() ? d(time) : f(time)
        return Solved(kind: .linear, topic: isTank ? "물탱크 채우기 (일의 양)" : "일의 양 (함께 하기)", concept: concept,
                      steps: [SolutionStep(hint: "1\(unit)에 하는 일의 양", work: "\(a): 1/\(d(ta)), \(b): 1/\(d(tb))"),
                              SolutionStep(hint: draining ? "넣는 양 − 빼는 양" : "함께 하면 1\(unit)에", work: "1/\(d(ta)) \(draining ? "−" : "+") 1/\(d(tb)) = \(f(rate))"),
                              SolutionStep(hint: "전체 1을 끝내는 데 걸리는 시간", work: "1 ÷ \(f(rate)) = \(shown)\(unit)")],
                      answer: "\(shown)\(unit)")
    }

    // MARK: - 시계 (시침과 분침)

    static func clock(_ t: String) -> Solved? {
        guard has(t, ["시침"]), has(t, ["분침"]) else { return nil }
        // 겹치는 시각: h시와 h+1시 사이
        if has(t, ["겹치", "일치"]), let m = match(t, #"(\d+)\s*시와\s*(\d+)\s*시\s*사이"#), let h = Double(m[1]) {
            // 30h + 0.5m = 6m → m = 60h/11
            let minute = 60 * h / 11
            return Solved(kind: .linear, topic: "시계의 시침과 분침", concept: "분침은 1분에 6°, 시침은 1분에 0.5°씩 움직여요. h시 m분의 시침 각도 = 30h + 0.5m, 분침 각도 = 6m",
                          steps: [SolutionStep(hint: "\(d(h))시 x분에 겹친다면", work: "30 × \(d(h)) + 0.5x = 6x"),
                                  SolutionStep(hint: "풀면", work: "5.5x = \(d(30 * h)) → x = \(f(minute))")],
                          answer: "\(d(h))시 \(f(minute))분")
        }
        guard let m = match(t, #"(\d{1,2})\s*시\s*(?:(\d{1,2})\s*분|정각)?"#), let h0 = Double(m[1]), h0 >= 0, h0 <= 24 else { return nil }
        let minute = Double(m[2]) ?? 0
        guard minute < 60, has(t, ["각"]) else { return nil }
        let h = h0.truncatingRemainder(dividingBy: 12)
        let hourAngle = 30 * h + 0.5 * minute, minuteAngle = 6 * minute
        var angle = abs(hourAngle - minuteAngle)
        if angle > 180 { angle = 360 - angle }
        let big = has(t, ["큰 쪽", "큰 각"])
        let answer = big ? 360 - angle : angle
        return Solved(kind: .geometry, topic: "시계의 시침과 분침이 이루는 각", concept: "분침은 1분에 6°, 시침은 1시간에 30°(1분에 0.5°)씩 움직여요. 12시 방향에서 잰 두 각의 차를 구해요.",
                      steps: [SolutionStep(hint: "12시 방향에서 시침까지의 각", work: "30 × \(d(h)) + 0.5 × \(d(minute)) = \(d(hourAngle))°"),
                              SolutionStep(hint: "12시 방향에서 분침까지의 각", work: "6 × \(d(minute)) = \(d(minuteAngle))°"),
                              SolutionStep(hint: "두 각의 차 (180°보다 크면 360°에서 빼요)", work: "\(d(answer))°")],
                      answer: "\(d(answer))°")
    }

    // MARK: - 평균의 변화 (한 명이 빠지거나 들어올 때)

    static func meanChange(_ t: String) -> Solved? {
        guard let m = match(t, #"평균이\s*(\d+(?:\.\d+)?)\s*점인\s*(\d+)\s*명"#), let mean1 = Double(m[1]), let n = Double(m[2]),
              let m2 = match(t, #"평균이\s*(\d+(?:\.\d+)?)\s*점(?:이|으로)\s*(?:되었|됐|올랐|내려갔|높아|낮아)"#), let mean2 = Double(m2[1]) else { return nil }
        if has(t, ["전학을 갔", "빠지", "빠졌", "나갔", "한 명을 빼"]) {
            let x = mean1 * n - mean2 * (n - 1)
            return Solved(kind: .statistics, topic: "평균의 변화", concept: "(자료의 합) = 평균 × 개수. 한 명이 빠지기 전과 후의 합의 차가 그 학생의 점수예요.",
                          steps: [SolutionStep(hint: "처음 \(d(n))명의 점수의 합", work: "\(d(mean1)) × \(d(n)) = \(d(mean1 * n))"),
                                  SolutionStep(hint: "남은 \(d(n - 1))명의 점수의 합", work: "\(d(mean2)) × \(d(n - 1)) = \(d(mean2 * (n - 1)))"),
                                  SolutionStep(hint: "빠진 학생의 점수", work: "\(d(mean1 * n)) − \(d(mean2 * (n - 1))) = \(d(x))")],
                          answer: "\(d(x))점")
        }
        if has(t, ["전학을 왔", "들어오", "들어왔", "새로"]) {
            let x = mean2 * (n + 1) - mean1 * n
            return Solved(kind: .statistics, topic: "평균의 변화", concept: "(자료의 합) = 평균 × 개수",
                          steps: [SolutionStep(hint: "처음 합", work: "\(d(mean1)) × \(d(n)) = \(d(mean1 * n))"),
                                  SolutionStep(hint: "들어온 뒤 합", work: "\(d(mean2)) × \(d(n + 1)) = \(d(mean2 * (n + 1)))"),
                                  SolutionStep(hint: "들어온 학생의 점수", work: "\(d(x))")],
                          answer: "\(d(x))점")
        }
        return nil
    }
}
