import Foundation

/// 모티 AI 수학 풀이: 다른 풀이가 모두 못 푼 문제만 (DoitMathBasic.late) + 답 다시 보기 (DoitMathBasic.review)
/// 모양이 분명한 것만 정확한 분수로 계산해요. 조건이 모자라거나 애매하면 nil
extension DoitMathBasic {

    static func late(_ raw: String) -> Solved? {
        let t = DoitAlgebra.normalize(DoitMathExact.tidy(raw))
        // 그림·표를 봐야 하는 문제는 풀지 않음
        if has(t, ["그림", "표에서", "그래프에서", "다음 표", "아래 표", "색칠"]) { return nil }
        let solvers: [(String) -> Solved?] = [
            ratioValue, mapScale, ratioRectangle, remainingAngle, absCount, numberLineDistance, candyShare, rectangleSides,
            travel, quadrant, diagonalCount, relativeFrequency, simplifyPolynomial, coins, powerEquation, budget,
            interceptsLine, axisTriangle, parallelPerpendicular, complementProbability, consecutiveProduct, yIntercept,
            symmetricSum, iPowerSum, circleEquation, tangentToCircle, reflectPoint, radiusThroughPoint, sqrtFunctionRange,
            sufficientCondition, radicals, pythagoreanIdentity, limitConstants, numberSentence,
        ]
        for solve in solvers { if let s = solve(t) { return s } }
        return nil
    }

    // MARK: 비율 · 축척

    static func ratioValue(_ t: String) -> Solved? {
        guard let m = match(t, #"비\s*("# + num + #")\s*:\s*("# + num + #")\s*의\s*비율을\s*(분수|소수|백분율)"#), let a = rat(m[1]), let b = rat(m[2]), !b.isZero, let r = a / b else { return nil }
        let concept = "비 a : b의 비율은 a/b (기준량 b에 대한 비교하는 양 a의 크기), 백분율은 비율 × 100"
        switch m[3] {
        case "분수": return Solved(kind: .percent, topic: "비율", concept: concept, steps: [step("비율 = 비교하는 양 ÷ 기준량", "\(show(a)) ÷ \(show(b)) = \(show(r))")], answer: show(r))
        case "소수":
            guard let d = r.decimalText else { return nil }
            return Solved(kind: .percent, topic: "비율", concept: concept, steps: [step("비율", "\(show(a)) ÷ \(show(b)) = \(d)")], answer: d)
        default:
            guard let p = r * Rat(100)!, let d = p.decimalText else { return nil }
            return Solved(kind: .percent, topic: "백분율", concept: concept, steps: [step("비율 × 100", "\(show(r)) × 100 = \(d)%")], answer: d + "%")
        }
    }

    static func mapScale(_ t: String) -> Solved? {
        guard let s = match(t, #"축척이?\s*(?:이\s*)?1\s*:\s*(\d+)"#), let n = Rat.parse(s[1]),
              let len = match(t, #"(?:지도에서|지도\s*위에서|지도에서의)\s*(?:길이가\s*)?("# + num + #")\s*(cm|mm|m)"#) ?? match(t, #"길이가\s*("# + num + #")\s*(cm|mm|m)\s*인"#),
              let l = rat(len[1]), let ask = match(t, #"실제\s*(?:거리|길이)는\s*몇\s*(km|m|cm)"#) else { return nil }
        let toCM: [String: Rat] = ["mm": Rat(1, 10)!, "cm": .one, "m": Rat(100)!, "km": Rat(100000)!]
        guard let u = toCM[len[2]], let v = toCM[ask[1]], let real = l * n, let cm = real * u, let out = cm / v else { return nil }
        return Solved(kind: .percent, topic: "축척", concept: "축척 1 : n 이면 (실제 거리) = (지도에서의 거리) × n",
                      steps: [step("실제 거리", "\(show(l)) \(len[2]) × \(s[1]) = \(show(real)) \(len[2])"), step("단위를 바꾸면", "\(show(out)) \(ask[1])")], answer: show(out))
    }

    static func ratioRectangle(_ t: String) -> Solved? {
        guard t.contains("직사각형"), let r = match(t, #"가로와\s*세로의\s*(?:길이의\s*)?비가?\s*("# + num + #")\s*:\s*("# + num + #")"#),
              let p = match(t, #"둘레(?:의\s*길이)?가\s*("# + num + #")\s*(?:cm|m)?"#),
              let a = rat(r[1]), let b = rat(r[2]), let per = rat(p[1]), let ab = a + b, let two = ab * Rat(2)!, let unit = per / two else { return nil }
        guard let w = a * unit, let h = b * unit else { return nil }
        let steps = [step("가로 \(show(a))k, 세로 \(show(b))k로 놓으면", "2 × (\(show(a))k + \(show(b))k) = \(show(per)) → k = \(show(unit))"), step("가로, 세로", "\(show(w)), \(show(h))")]
        let concept = "비가 a : b이면 가로 ak, 세로 bk로 놓고 둘레 2(ak + bk)로 k를 구해요."
        if t.range(of: #"가로의\s*길이는|가로는"#, options: .regularExpression) != nil { return Solved(kind: .geometry, topic: "비와 직사각형", concept: concept, steps: steps, answer: show(w)) }
        if t.range(of: #"세로의\s*길이는|세로는"#, options: .regularExpression) != nil { return Solved(kind: .geometry, topic: "비와 직사각형", concept: concept, steps: steps, answer: show(h)) }
        if t.contains("넓이는"), let area = w * h { return Solved(kind: .geometry, topic: "비와 직사각형", concept: concept, steps: steps + [step("넓이", show(area))], answer: show(area)) }
        return nil
    }

    // MARK: 각의 크기

    static func remainingAngle(_ t: String) -> Solved? {
        guard !has(t, ["외각", "이등변", "정"]) else { return nil }
        if let m = match(t, #"삼각형의\s*두\s*(?:내)?각의\s*크기가\s*(?:각각\s*)?(\d+(?:\.\d+)?)\s*°?\s*,\s*(\d+(?:\.\d+)?)\s*°?\s*일\s*때\s*,?\s*나머지\s*한\s*(?:내)?각의\s*크기"#),
           let a = rat(m[1]), let b = rat(m[2]), let ab = a + b, let r = Rat(180)! - ab, r.n > 0 {
            return Solved(kind: .geometry, topic: "삼각형의 내각", concept: "삼각형의 세 내각의 크기의 합은 180°",
                          steps: [step("180° − (두 각)", "180° − \(show(a))° − \(show(b))° = \(show(r))°")], answer: show(r) + "°")
        }
        if let m = match(t, #"사각형의\s*세\s*(?:내)?각의\s*크기가\s*(?:각각\s*)?(\d+)\s*°?\s*,\s*(\d+)\s*°?\s*,\s*(\d+)\s*°?\s*일\s*때\s*,?\s*나머지\s*한\s*(?:내)?각의\s*크기"#),
           let a = Int(m[1]), let b = Int(m[2]), let c = Int(m[3]), 360 - a - b - c > 0 {
            return Solved(kind: .geometry, topic: "사각형의 내각", concept: "사각형의 네 내각의 크기의 합은 360°",
                          steps: [step("360° − (세 각)", "360° − \(a)° − \(b)° − \(c)° = \(360 - a - b - c)°")], answer: "\(360 - a - b - c)°")
        }
        return nil
    }

    // MARK: 정수와 수직선

    static func absCount(_ t: String) -> Solved? {
        guard let m = match(t, #"절댓값이\s*(\d+(?:\.\d+)?|\d+/\d+)\s*(이하|미만|보다\s*작은)인?\s*정수의\s*개수"#), let a = rat(m[1]) else { return nil }
        let whole = Int(a.value.rounded(.down))
        let strictEdge = m[2] != "이하" && a.isInteger
        let k = strictEdge ? whole - 1 : whole
        guard k >= 0 else { return nil }
        let count = 2 * k + 1
        return Solved(kind: .numberTheory, topic: "절댓값", concept: "절댓값이 a 이하인 정수는 −a부터 a까지의 정수예요.",
                      steps: [step("정수", "−\(k), …, 0, …, \(k)"), step("개수", "\(count)")], answer: "\(count)")
    }

    static func numberLineDistance(_ t: String) -> Solved? {
        guard let m = match(t, "(" + num + #")\s*(?:을|를)\s*나타내는\s*점과\s*("# + num + #")\s*(?:을|를)\s*나타내는\s*점\s*사이의\s*거리"#),
              let a = rat(m[1]), let b = rat(m[2]), let d = a - b else { return nil }
        let r = d.n < 0 ? -d : d
        return Solved(kind: .coordinate, topic: "수직선 위의 두 점 사이의 거리", concept: "수직선 위의 두 점 a, b 사이의 거리는 |a − b|",
                      steps: [step("|a − b|", "|\(show(a)) − (\(show(b)))| = \(show(r))")], answer: show(r))
    }

    // MARK: 문장제 (일차방정식)

    static func candyShare(_ t: String) -> Solved? {
        let ms = matches(t, #"(\d+)\s*(?:개|자루|권|장)씩\s*(?:나누어\s*)?(?:주면|나누어\s*주면|넣으면)\s*(\d+)\s*(?:개|자루|권|장)?(?:가|이)?\s*(남|부족|모자라)"#)
        guard ms.count == 2, let a = Int(ms[0][1]), let r1 = Int(ms[0][2]), let c = Int(ms[1][1]), let r2 = Int(ms[1][2]), a != c else { return nil }
        let s1 = ms[0][3] == "남" ? r1 : -r1, s2 = ms[1][3] == "남" ? r2 : -r2
        guard (s1 - s2) % (c - a) == 0 else { return nil }
        let n = (s1 - s2) / (c - a)
        guard n > 0 else { return nil }
        let total = a * n + s1
        guard total > 0 else { return nil }
        let steps = [step("사람 수를 x라 하면", "\(a)x \(s1 >= 0 ? "+" : "−") \(abs(s1)) = \(c)x \(s2 >= 0 ? "+" : "−") \(abs(s2))"), step("풀면", "x = \(n), 물건은 \(total)개")]
        let concept = "나누어 주는 물건의 수는 어떻게 나누어도 같아요: (한 사람 몫) × (사람 수) ± (남거나 모자란 수)"
        if has(t, ["학생 수", "학생은 몇", "사람 수", "몇 명", "학생의 수", "사람은 몇"]) {
            return Solved(kind: .linear, topic: "과부족 문제", concept: concept, steps: steps, answer: "\(n)")
        }
        if t.range(of: #"(?:사탕|연필|공책|귤|사과|구슬|과자|초콜릿|물건|색종이|볼펜)(?:의\s*개수|은\s*(?:모두\s*)?몇|는\s*(?:모두\s*)?몇|의\s*수)|모두\s*몇\s*(?:개|자루|권|장)"#, options: .regularExpression) != nil {
            return Solved(kind: .linear, topic: "과부족 문제", concept: concept, steps: steps, answer: "\(total)")
        }
        return nil
    }

    static func rectangleSides(_ t: String) -> Solved? {
        guard t.contains("직사각형"), let p = match(t, #"둘레의\s*길이가\s*("# + num + #")\s*(?:cm|m)?"#), let per = rat(p[1]), let half = per / Rat(2)! else { return nil }
        var w: Rat?, h: Rat?
        if let m = match(t, #"가로의\s*길이가\s*세로의\s*길이보다\s*("# + num + #")\s*(?:cm|m)?\s*(긴|짧은|길|짧)"#), let d = rat(m[1]) {
            let diff = m[2].hasPrefix("긴") || m[2].hasPrefix("길") ? d : -d
            guard let s = half - diff, let hh = s / Rat(2)!, let ww = hh + diff else { return nil }
            w = ww; h = hh
        } else if let m = match(t, #"세로의\s*길이가\s*가로의\s*길이보다\s*("# + num + #")\s*(?:cm|m)?\s*(긴|짧은|길|짧)"#), let d = rat(m[1]) {
            let diff = m[2].hasPrefix("긴") || m[2].hasPrefix("길") ? d : -d
            guard let s = half - diff, let ww = s / Rat(2)!, let hh = ww + diff else { return nil }
            w = ww; h = hh
        } else if let m = match(t, #"가로의\s*길이가\s*세로의\s*길이의\s*(\d+)\s*배"#), let k = rat(m[1]), let k1 = k + .one, let hh = half / k1, let ww = hh * k {
            w = ww; h = hh
        }
        guard let ww = w, let hh = h, ww.n > 0, hh.n > 0 else { return nil }
        let steps = [step("가로 + 세로 = 둘레 ÷ 2", show(half)), step("가로, 세로", "\(show(ww)), \(show(hh))")]
        let concept = "직사각형의 둘레 = 2 × (가로 + 세로). 한 변을 x로 놓고 일차방정식을 세워요."
        if t.range(of: #"세로의\s*길이는|세로의\s*길이를\s*구|세로의\s*길이\s*\?|세로의\s*길이$"#, options: .regularExpression) != nil, !t.hasSuffix("가로의 길이는?") {
            return Solved(kind: .linear, topic: "직사각형의 둘레", concept: concept, steps: steps, answer: show(hh))
        }
        if t.range(of: #"가로의\s*길이는|가로의\s*길이를\s*구"#, options: .regularExpression) != nil, let last = t.range(of: "가로의 길이는", options: .backwards), last.lowerBound > (t.range(of: "둘레")?.lowerBound ?? t.startIndex) {
            return Solved(kind: .linear, topic: "직사각형의 둘레", concept: concept, steps: steps, answer: show(ww))
        }
        if t.range(of: #"넓이는|넓이를\s*구"#, options: .regularExpression) != nil, let area = ww * hh {
            return Solved(kind: .linear, topic: "직사각형의 둘레", concept: concept, steps: steps + [step("넓이", show(area))], answer: show(area))
        }
        return nil
    }

    static func travel(_ t: String) -> Solved? {
        let ms = matches(t, #"(분속|시속|초속)\s*("# + num + #")\s*(m|km)"#)
        guard ms.count == 2, ms[0][1] == ms[1][1], ms[0][3] == ms[1][3], let v1 = rat(ms[0][2]), let v2 = rat(ms[1][2]),
              let d = match(t, #"(?:거리가|사이가)\s*("# + num + #")\s*(m|km)\s*가?\s*(?:되는|될)"#), d[2] == ms[0][3], let dist = rat(d[1]),
              let ask = match(t, #"몇\s*(분|시간|초)\s*(?:후|뒤)"#), ["분속": "분", "시속": "시간", "초속": "초"][ms[0][1]] == ask[1] else { return nil }
        let opposite = has(t, ["반대 방향", "반대방향", "마주 보고", "마주보고"])
        let same = has(t, ["같은 방향", "같은방향"])
        guard opposite != same, has(t, ["동시에", "같은 지점", "같은 곳"]) else { return nil }
        guard let rel = opposite ? v1 + v2 : (v1 - v2).map({ $0.n < 0 ? -$0 : $0 }), !rel.isZero, let time = dist / rel else { return nil }
        return Solved(kind: .linear, topic: "거리 · 속력 · 시간", concept: opposite ? "반대 방향으로 가면 두 사람 사이의 거리는 1\(ask[1])에 (두 속력의 합)만큼 늘어나요." : "같은 방향으로 가면 1\(ask[1])에 (두 속력의 차)만큼 벌어져요.",
                      steps: [step(opposite ? "속력의 합" : "속력의 차", "\(show(rel)) \(ms[0][3])"), step("시간 = 거리 ÷ 속력", "\(show(dist)) ÷ \(show(rel)) = \(show(time))")], answer: show(time))
    }

    // MARK: 좌표 · 다각형 · 통계

    static func quadrant(_ t: String) -> Solved? {
        guard let m = match(t, #"점\s*\(\s*("# + num + #")\s*,\s*("# + num + #")\s*\)\s*(?:은|는)\s*(?:제\s*몇\s*사분면|어느\s*사분면|몇\s*사분면)"#), let x = rat(m[1]), let y = rat(m[2]) else { return nil }
        guard !x.isZero, !y.isZero else {
            return Solved(kind: .coordinate, topic: "사분면", concept: "좌표축 위의 점은 어느 사분면에도 속하지 않아요.", steps: [step("x좌표 또는 y좌표가 0", "축 위의 점")], answer: "어느 사분면에도 속하지 않아요")
        }
        let q = x.n > 0 ? (y.n > 0 ? 1 : 4) : (y.n > 0 ? 2 : 3)
        return Solved(kind: .coordinate, topic: "사분면", concept: "(+, +) 제1사분면, (−, +) 제2사분면, (−, −) 제3사분면, (+, −) 제4사분면",
                      steps: [step("부호", "(\(x.n > 0 ? "+" : "−"), \(y.n > 0 ? "+" : "−"))")], answer: "제\(q)사분면")
    }

    static let polygonNames = [3: "삼각형", 4: "사각형", 5: "오각형", 6: "육각형", 7: "칠각형", 8: "팔각형", 9: "구각형", 10: "십각형", 11: "십일각형", 12: "십이각형"]

    static func diagonalCount(_ t: String) -> Solved? {
        guard let m = match(t, #"대각선의\s*(?:총\s*)?개수가\s*(\d+)\s*(?:개)?인\s*(정)?다각형"#), let d = Int(m[1]), t.range(of: #"몇\s*각형|이름|어떤\s*다각형|다각형은"#, options: .regularExpression) != nil else { return nil }
        guard let n = (4...200).first(where: { $0 * ($0 - 3) / 2 == d }) else { return nil }
        let name = (m[2].isEmpty ? "" : "정") + (polygonNames[n] ?? "\(n)각형")
        return Solved(kind: .geometry, topic: "다각형의 대각선의 개수", concept: "n각형의 대각선의 개수는 n(n − 3)/2",
                      steps: [step("n(n − 3)/2 = \(d)", "n(n − 3) = \(2 * d) → n = \(n)")], answer: name)
    }

    static func relativeFrequency(_ t: String) -> Solved? {
        guard t.contains("상대도수"), let total = match(t, #"도수의\s*총합이\s*(\d+)"#).flatMap({ Rat.parse($0[1]) }), !total.isZero else { return nil }
        if let f = match(t, #"(?:계급의\s*)?도수가\s*(\d+)\s*일\s*때"#).flatMap({ Rat.parse($0[1]) }), t.range(of: #"상대도수는|상대도수를\s*구"#, options: .regularExpression) != nil, let r = f / total {
            return Solved(kind: .statistics, topic: "상대도수", concept: "(상대도수) = (그 계급의 도수) ÷ (도수의 총합)", steps: [step("도수 ÷ 총합", "\(show(f)) ÷ \(show(total)) = \(r.decimalText ?? show(r))")], answer: r.decimalText ?? show(r))
        }
        if let r = match(t, #"상대도수가\s*(0\.\d+|\d+/\d+)"#).flatMap({ rat($0[1]) }), t.range(of: #"도수는|도수를\s*구"#, options: .regularExpression) != nil, let f = r * total {
            return Solved(kind: .statistics, topic: "상대도수", concept: "(그 계급의 도수) = (도수의 총합) × (상대도수)", steps: [step("총합 × 상대도수", "\(show(total)) × \(show(r)) = \(show(f))")], answer: show(f))
        }
        return nil
    }

    // MARK: 다항식 간단히 (x, y)

    /// "(6x^2y - 4xy^2) / 2xy": 다항식 ÷ 단항식
    static func simplifyPolynomial(_ t: String) -> Solved? {
        guard let m = match(t, #"^\s*(?:\d+\s*[.)번]\s*)?([0-9xy+\-*/^()\s]+?)\s*(?:을|를)\s*(?:간단히|계산|정리)"#) else { return nil }
        let e = m[1].trimmingCharacters(in: .whitespaces)
        guard e.contains("x") || e.contains("y"), e.contains("("), !e.contains("=") else { return nil }
        var result: DoitAlgebra.MPoly?
        if let slash = e.range(of: "/", options: .backwards), e[..<slash.lowerBound].hasSuffix(")") || e[..<slash.lowerBound].trimmingCharacters(in: .whitespaces).hasSuffix(")") {
            let left = String(e[..<slash.lowerBound]), right = String(e[slash.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard right.range(of: #"^\(?\s*-?\d*\s*x?\s*(?:\^\s*\d+)?\s*y?\s*(?:\^\s*\d+)?\s*\)?$"#, options: .regularExpression) != nil,
                  let l = DoitAlgebra.parse(left), let r = DoitAlgebra.parse(right) else { return nil }
            let rt = r.cleaned.t
            guard rt.count == 1, let (mono, c) = rt.first, abs(c) > 1e-12 else { return nil }
            var out = DoitAlgebra.MPoly()
            for (k, v) in l.cleaned.t {
                guard k.x >= mono.x, k.y >= mono.y, k.z >= mono.z else { return nil }
                out.t[DoitAlgebra.Mono(x: k.x - mono.x, y: k.y - mono.y, z: k.z - mono.z), default: 0] += v / c
            }
            result = out
        } else {
            guard !e.contains("/"), let p = DoitAlgebra.parse(e) else { return nil }
            result = p
        }
        guard let r = result, r.cleaned.t.values.allSatisfy({ abs($0 * 60 - ($0 * 60).rounded()) < 1e-9 }) else { return nil }
        let text = DoitAlgebra.describe(r)
        return Solved(kind: .expression, topic: "다항식의 계산", concept: "괄호를 풀고 동류항끼리 모아요. 단항식으로 나눌 때는 각 항을 나눠요.",
                      steps: [step("계산하면", text)], answer: text)
    }

    // MARK: 연립방정식 문장제 (동전)

    static func coins(_ t: String) -> Solved? {
        guard let m = match(t, #"(\d+)\s*원짜리\s*([가-힣]+?)\s*(?:과|와)\s*(\d+)\s*원짜리\s*([가-힣]+?)(?:가|이|을|를)"#), m[2] == m[4],
              let a = Int(m[1]), let b = Int(m[3]), a != b,
              let n = match(t, #"(?:모두|합하여|합쳐서|모두\s*합하여)\s*(\d+)\s*(?:개|장|자루|권)"#).flatMap({ Int($0[1]) }),
              let total = match(t, #"(?:금액의\s*합|금액|합계|값의\s*합|모두\s*합한\s*금액|총\s*금액)(?:이|은|는)?\s*(\d+)\s*원"#).flatMap({ Int($0[1]) }),
              let ask = match(t, #"(\d+)\s*원짜리\s*[가-힣]*?\s*(?:은|는)?\s*몇\s*(?:개|장|자루|권)"#).flatMap({ Int($0[1]) }), ask == a || ask == b else { return nil }
        // a원짜리 x개, b원짜리 n − x개: a x + b(n − x) = total
        guard (total - b * n) % (a - b) == 0 else { return nil }
        let x = (total - b * n) / (a - b), y = n - x
        guard x >= 0, y >= 0 else { return nil }
        let answer = ask == a ? x : y
        return Solved(kind: .system, topic: "연립방정식의 활용", concept: "개수의 합과 금액의 합으로 연립방정식을 세워요.",
                      steps: [step("\(a)원짜리 x개, \(b)원짜리 y개", "x + y = \(n), \(a)x + \(b)y = \(total)"), step("풀면", "x = \(x), y = \(y)")], answer: "\(answer)")
    }

    // MARK: 지수법칙 2³ × 4² = 2ᵏ

    static func powerEquation(_ t: String) -> Solved? {
        guard let m = match(t, #"([0-9^*/()\s]+?)\s*=\s*(\d+)\s*\^\s*([a-z])\s*일\s*때"#), let b = Int(m[2]), b >= 2,
              t.range(of: "(?<![a-z])\(m[3])\\s*의\\s*값", options: .regularExpression) != nil, let v = eval(m[1]), v.n > 0 else { return nil }
        guard let found = (-30...60).first(where: { k in
            guard let br = Rat(b) else { return false }
            let p = k >= 0 ? br.power(k) : br.power(-k).flatMap { Rat.one / $0 }
            return p == v
        }) else { return nil }
        return Solved(kind: .expression, topic: "지수법칙", concept: "밑을 같게 바꾼 뒤 aᵐ × aⁿ = aᵐ⁺ⁿ, (aᵐ)ⁿ = aᵐⁿ",
                      steps: [step("좌변", "\(m[1].trimmingCharacters(in: .whitespaces)) = \(show(v)) = \(b)^\(found)")], answer: "\(found)")
    }

    // MARK: 일차부등식 문장제 (최대 몇 개)

    static func budget(_ t: String) -> Solved? {
        guard t.range(of: #"최대\s*몇\s*(?:개|자루|권|송이)"#, options: .regularExpression) != nil,
              let price = match(t, #"한\s*(?:개|자루|권|송이)에\s*(\d+)\s*원인"#).flatMap({ Int($0[1]) }) ?? match(t, #"(\d+)\s*원짜리\s*[가-힣]+\s*(?:을|를)\s*몇"#).flatMap({ Int($0[1]) }),
              let limit = match(t, #"(\d+)\s*원\s*(이하|미만|이내)"#), let cap = Int(limit[1]), price > 0 else { return nil }
        // 따로 내는 돈: "2000원짜리 상자 하나", "배송비 3000원"
        var fixed = 0
        for f in matches(t, #"(\d+)\s*원짜리\s*[가-힣]+\s*(?:하나|한\s*개|1\s*개)"#) { fixed += Int(f[1]) ?? 0 }
        if let f = match(t, #"(?:배송비|포장비|입장료|기본요금)(?:가|는|로)?\s*(\d+)\s*원"#) { fixed += Int(f[1]) ?? 0 }
        let numbers = matches(t, #"(\d+)\s*원"#).count
        guard numbers == 2 + (fixed > 0 ? 1 : 0) else { return nil }
        let room = cap - fixed
        guard room > 0 else { return nil }
        var n = room / price
        if limit[2] == "미만", room % price == 0 { n -= 1 }
        guard n >= 0 else { return nil }
        let op = limit[2] == "미만" ? "<" : "≤"
        return Solved(kind: .inequality, topic: "일차부등식의 활용", concept: "모르는 개수를 x로 놓고 (전체 금액) \(op) (가진 돈)으로 부등식을 세워요. x는 자연수예요.",
                      steps: [step("x개를 사면", "\(price)x\(fixed > 0 ? " + \(fixed)" : "") \(op) \(cap)"), step("풀면", "x \(op) \(DoitMath.fraction(Double(room) / Double(price))) → 가장 큰 자연수 \(n)")], answer: "\(n)")
    }

    // MARK: 일차함수

    static func interceptsLine(_ t: String) -> Solved? {
        guard let m = match(t, #"x절편이\s*("# + num + #")\s*(?:이고|,)\s*y절편이\s*("# + num + #")\s*인\s*(?:직선|일차함수)"#), let a = rat(m[1]), let b = rat(m[2]), !a.isZero, !b.isZero,
              let s = (-b) / a, has(t, ["방정식", "식"]) else { return nil }
        let line = "y = " + polyText([b, s])
        return Solved(kind: .function, topic: "일차함수의 식", concept: "x절편 a, y절편 b인 직선의 기울기는 −b/a",
                      steps: [step("기울기", "−(\(show(b)))/\(show(a)) = \(show(s))"), step("식", line)], answer: line)
    }

    static func axisTriangle(_ t: String) -> Solved? {
        guard let m = match(t, #"y\s*=\s*([0-9x+\-*/().\s]+?)\s*의\s*그래프와\s*(?:x축\s*(?:,|및|과)?\s*y축|두\s*좌표축|x축,\s*y축)으로\s*둘러싸인\s*(?:도형|삼각형|부분)의\s*넓이"#),
              let (p, q) = linearParts(m[1]), !q.isZero, let xi = (-q) / p, let prod = xi * q, let area0 = prod / Rat(2)! else { return nil }
        let area = area0.n < 0 ? -area0 : area0
        return Solved(kind: .function, topic: "일차함수의 그래프와 넓이", concept: "x절편과 y절편을 구하면 삼각형의 밑변과 높이가 돼요.",
                      steps: [step("x절편, y절편", "\(show(xi)), \(show(q))"), step("넓이", "|\(show(xi))| × |\(show(q))| ÷ 2 = \(show(area))")], answer: show(area))
    }

    static func parallelPerpendicular(_ t: String) -> Solved? {
        guard let m = match(t, #"y\s*=\s*([0-9a-z+\-*/().\s]+?)\s*,\s*y\s*=\s*([0-9a-z+\-*/().\s]+?)\s*(?:의\s*그래프가|이|가)\s*(?:서로\s*)?(평행|수직)"#),
              let c = match(t, #"상수\s*([a-wz])\s*의\s*값"#)?[1].first else { return nil }
        let sides = [m[1], m[2]].map { $0.trimmingCharacters(in: .whitespaces) }
        guard let unknown = sides.firstIndex(where: { $0.contains(c) }), sides.filter({ $0.contains(c) }).count == 1 else { return nil }
        let known = sides[1 - unknown]
        guard let (s, q) = linearParts(known), let um = match(sides[unknown], "^(-?\\d*)\\s*\(c)\\s*x\\s*([+-]\\s*\(num))?$") else { return nil }
        let k: Rat = um[1].isEmpty ? .one : um[1] == "-" ? -Rat.one : (rat(um[1]) ?? .one)
        let b = um[2].isEmpty ? Rat.zero : rat(um[2].replacingOccurrences(of: "+", with: "")) ?? .zero
        var value: Rat?
        if m[3] == "평행" {
            guard b != q else { return nil }   // 같으면 일치
            value = s / k
        } else {
            guard !s.isZero, let inv = (-Rat.one) / s else { return nil }
            value = inv / k
        }
        guard let v = value else { return nil }
        return Solved(kind: .function, topic: m[3] == "평행" ? "평행한 두 직선" : "수직인 두 직선", concept: m[3] == "평행" ? "두 직선이 평행하면 기울기가 같고 y절편이 달라요." : "두 직선이 수직이면 기울기의 곱이 −1이에요.",
                      steps: [step("기울기 조건", m[3] == "평행" ? "\(show(k))\(c) = \(show(s))" : "\(show(k))\(c) × \(show(s)) = −1"), step(String(c), show(v))], answer: show(v))
    }

    // MARK: 확률 · 수

    static func complementProbability(_ t: String) -> Solved? {
        guard numberCount(t) == 1, let m = match(t, #"확률이\s*(0\.\d+|\d+/\d+)\s*일\s*때\s*,?\s*(.+?)(?:않을|못할|아닐|지\s*않을)\s*확률"#), let p = rat(m[1]), p.value <= 1,
              let q = Rat.one - p else { return nil }
        let decimal = m[1].contains(".")
        let ans = decimal ? (q.decimalText ?? show(q)) : show(q)
        return Solved(kind: .counting, topic: "여사건의 확률", concept: "(어떤 사건이 일어나지 않을 확률) = 1 − (그 사건이 일어날 확률)",
                      steps: [step("1 − p", "1 − \(m[1]) = \(ans)")], answer: ans)
    }

    static func consecutiveProduct(_ t: String) -> Solved? {
        guard let m = match(t, #"연속하는\s*(두|세)\s*(자연수|짝수|홀수|양의\s*정수)의\s*곱이\s*(\d+)"#), let k = count(m[1]), let target = Int(m[3]) else { return nil }
        let stepSize = m[2] == "자연수" || m[2].contains("정수") ? 1 : 2
        var found: [Int]?
        var start = m[2] == "짝수" ? 2 : 1
        while start <= target {
            let list = (0..<k).map { start + $0 * stepSize }
            let p = list.reduce(1, *)
            if p == target { found = list; break }
            if p > target { break }
            start += m[2] == "자연수" || m[2].contains("정수") ? 1 : 2
        }
        guard let l = found else { return nil }
        let steps = [step("연속하는 수를 놓고 곱이 \(target)인 것을 찾으면", l.map(String.init).joined(separator: ", "))]
        let concept = "연속하는 두 자연수는 x, x + 1 (짝수·홀수는 x, x + 2)로 놓고 이차방정식을 풀어요."
        if t.range(of: #"(?:두|세)\s*수의\s*합"#, options: .regularExpression) != nil { return Solved(kind: .quadraticEquation, topic: "이차방정식의 활용", concept: concept, steps: steps, answer: "\(l.reduce(0, +))") }
        if has(t, ["작은 수는", "작은 수를"]) { return Solved(kind: .quadraticEquation, topic: "이차방정식의 활용", concept: concept, steps: steps, answer: "\(l.first!)") }
        if has(t, ["큰 수는", "큰 수를"]) { return Solved(kind: .quadraticEquation, topic: "이차방정식의 활용", concept: concept, steps: steps, answer: "\(l.last!)") }
        return nil
    }

    static func yIntercept(_ t: String) -> Solved? {
        guard let m = match(t, #"y\s*=\s*([0-9x+\-*/^().\s]+?)\s*의\s*그래프의\s*y절편"#), m[1].contains("x"), let v = eval(m[1], "x", .zero) else { return nil }
        return Solved(kind: .function, topic: "y절편", concept: "y절편은 x = 0일 때의 y의 값이에요.", steps: [step("x = 0을 넣으면", "y = \(show(v))")], answer: show(v))
    }

    // MARK: 공통수학

    static func symmetricSum(_ t: String) -> Solved? {
        guard let s = match(t, #"a\s*\+\s*b\s*\+\s*c\s*=\s*("# + num + ")").flatMap({ rat($0[1]) }),
              let p = match(t, #"ab\s*\+\s*bc\s*\+\s*ca\s*=\s*("# + num + ")").flatMap({ rat($0[1]) }),
              t.range(of: #"a\^2\s*\+\s*b\^2\s*\+\s*c\^2\s*의\s*값"#, options: .regularExpression) != nil,
              let s2 = s * s, let p2 = p * Rat(2)!, let r = s2 - p2 else { return nil }
        return Solved(kind: .expression, topic: "곱셈 공식의 변형", concept: "a² + b² + c² = (a + b + c)² − 2(ab + bc + ca)",
                      steps: [step("(a + b + c)² − 2(ab + bc + ca)", "\(show(s))² − 2 × \(show(p)) = \(show(r))")], answer: show(r))
    }

    static func iPowerSum(_ t: String) -> Solved? {
        guard let m = match(DoitMathCalc.superscripts(t), #"(?<![a-z])(1\s*\+\s*)?i\s*\+\s*i\^2\s*\+\s*i\^3\s*\+\s*(?:…|\.\.\.|⋯|···)\s*\+\s*i\^\(?(\d+)\)?\s*의\s*값"#), let n = Int(m[2]), n >= 3, n <= 10000 else { return nil }
        var re = m[1].isEmpty ? 0 : 1, im = 0
        for k in 1...n {
            switch k % 4 { case 1: im += 1; case 2: re -= 1; case 3: im -= 1; default: re += 1 }
        }
        var text = ""
        if re != 0 { text = re < 0 ? "−\(-re)" : "\(re)" }
        if im != 0 {
            let mag = abs(im) == 1 ? "i" : "\(abs(im))i"
            text += text.isEmpty ? (im < 0 ? "−" + mag : mag) : (im < 0 ? " − " + mag : " + " + mag)
        }
        if text.isEmpty { text = "0" }
        return Solved(kind: .complex, topic: "i의 거듭제곱", concept: "i, i² = −1, i³ = −i, i⁴ = 1 이 4개씩 반복되고, 연속한 네 항의 합은 0이에요.",
                      steps: [step("네 항씩 묶으면 0", "남는 항만 더하면 \(text)")], answer: text)
    }

    static func circleEquation(_ t: String) -> Solved? {
        guard t.contains("원의 방정식") else { return nil }
        var center: (Rat, Rat)?
        if let m = match(t, #"중심이\s*\(\s*("# + num + #")\s*,\s*("# + num + #")\s*\)\s*(?:이고|인)"#), let a = rat(m[1]), let b = rat(m[2]) { center = (a, b) }
        else if t.contains("중심이 원점") { center = (.zero, .zero) }
        guard let (a, b) = center else { return nil }
        var r2: Rat?
        if let m = match(t, #"반지름의\s*길이가\s*("# + num + #")\s*인\s*원"#), let r = rat(m[1]), r.n > 0 { r2 = r * r }
        else if let m = match(t, #"점\s*\(\s*("# + num + #")\s*,\s*("# + num + #")\s*\)\s*(?:을|를)\s*지나는\s*원"#), let x = rat(m[1]), let y = rat(m[2]),
                let dx = x - a, let dy = y - b, let dx2 = dx * dx, let dy2 = dy * dy { r2 = dx2 + dy2 }
        guard let rr = r2, rr.n > 0 else { return nil }
        func part(_ v: String, _ c: Rat) -> String { c.isZero ? "\(v)²" : "(\(v) \(c.n > 0 ? "−" : "+") \(show(c.n > 0 ? c : -c)))²" }
        let eq = "\(part("x", a)) + \(part("y", b)) = \(show(rr))"
        return Solved(kind: .circle, topic: "원의 방정식", concept: "중심 (a, b), 반지름 r인 원: (x − a)² + (y − b)² = r²", steps: [step("식", eq)], answer: eq)
    }

    static func tangentToCircle(_ t: String) -> Solved? {
        guard let m = match(t, #"직선\s*y\s*=\s*(-?\d*)\s*x\s*\+\s*k\s*(?:가|이)\s*원\s*x\^2\s*\+\s*y\^2\s*=\s*(\d+)\s*에\s*접할\s*때"#), let r2 = Rat.parse(m[2]), r2.n > 0,
              t.range(of: #"(양수|음수)\s*k\s*의\s*값"#, options: .regularExpression) != nil else { return nil }
        let slope: Double = m[1].isEmpty ? 1 : m[1] == "-" ? -1 : Double(m[1]) ?? .nan
        guard slope.isFinite else { return nil }
        // |k| / √(m² + 1) = r → k = ±r√(m² + 1)
        let k = (r2.value * (slope * slope + 1)).squareRoot()
        let positive = t.contains("양수")
        guard let shown = DoitMathCalc.nice(positive ? k : -k, allow: [.surd]) else { return nil }
        return Solved(kind: .circle, topic: "원과 직선의 위치 관계", concept: "원의 중심에서 직선까지의 거리가 반지름과 같으면 접해요.",
                      steps: [step("중심 (0, 0)에서 직선까지의 거리", "|k|/√(\(DoitMath.format(slope * slope)) + 1) = √\(m[2])"), step("k", shown)], answer: shown)
    }

    static func reflectPoint(_ t: String) -> Solved? {
        guard let m = match(t, #"점\s*\(\s*("# + num + #")\s*,\s*("# + num + #")\s*\)\s*(?:을|를)\s*(직선\s*y\s*=\s*x|직선\s*y\s*=\s*-x)\s*에\s*대하여\s*대칭이동한\s*점의\s*좌표"#),
              let x = rat(m[1]), let y = rat(m[2]) else { return nil }
        let minus = m[3].contains("-x")
        let p = minus ? "(\(show(-y)), \(show(-x)))" : "(\(show(y)), \(show(x)))"
        return Solved(kind: .coordinate, topic: "대칭이동", concept: minus ? "직선 y = −x에 대하여 대칭이동하면 (a, b) → (−b, −a)" : "직선 y = x에 대하여 대칭이동하면 (a, b) → (b, a)",
                      steps: [step("좌표를 바꾸면", p)], answer: p)
    }

    static func radiusThroughPoint(_ t: String) -> Solved? {
        guard t.range(of: #"반지름의\s*길이(?:는|를)"#, options: .regularExpression) != nil, !t.contains("원의 방정식"),
              let m = match(t, #"점\s*\(\s*("# + num + #")\s*,\s*("# + num + #")\s*\)\s*(?:을|를)\s*지나는\s*원"#), let x = rat(m[1]), let y = rat(m[2]) else { return nil }
        var center: (Rat, Rat)?
        if t.contains("중심이 원점") { center = (.zero, .zero) }
        else if let c = match(t, #"중심이\s*\(\s*("# + num + #")\s*,\s*("# + num + #")\s*\)"#), let a = rat(c[1]), let b = rat(c[2]) { center = (a, b) }
        guard let (a, b) = center, let dx = x - a, let dy = y - b, let dx2 = dx * dx, let dy2 = dy * dy, let s = dx2 + dy2, let r = DoitMathExact.Surd.sqrt(s) else { return nil }
        return Solved(kind: .circle, topic: "원의 반지름", concept: "반지름은 중심과 원 위의 점 사이의 거리예요.", steps: [step("두 점 사이의 거리", "√(\(show(s))) = \(r.text)")], answer: r.text)
    }

    static func sqrtFunctionRange(_ t: String) -> Solved? {
        guard let m = match(t, #"y\s*=\s*(-?\d*)\s*√\s*\(([^()]+)\)\s*([+-]\s*\d+(?:\.\d+)?(?:/\d+)?)?\s*의\s*(치역|정의역)"#) else { return nil }
        let a: Rat = m[1].isEmpty ? .one : m[1] == "-" ? -Rat.one : rat(m[1]) ?? .zero
        guard !a.isZero, let (p, q) = linearParts(m[2]) else { return nil }
        let c = m[3].isEmpty ? Rat.zero : rat(m[3].replacingOccurrences(of: "+", with: "")) ?? .zero
        if m[4] == "치역" {
            let ans = "y \(a.n > 0 ? "≥" : "≤") \(show(c))"
            return Solved(kind: .function, topic: "무리함수의 치역", concept: "√(식) ≥ 0 이므로 y = a√(…) + q 의 치역은 a > 0이면 y ≥ q, a < 0이면 y ≤ q",
                          steps: [step("√ 부분은 0 이상", ans)], answer: ans)
        }
        guard let range = linearInterval(p: p, q: q, op: "≥", r: .zero) else { return nil }
        let ans = range.text()
        return Solved(kind: .function, topic: "무리함수의 정의역", concept: "근호 안의 식이 0 이상인 x의 값의 범위가 정의역이에요.", steps: [step("근호 안 ≥ 0", ans)], answer: ans)
    }

    static func sufficientCondition(_ t: String) -> Solved? {
        guard let m = match(t, #"p\s*:\s*("# + num + #")\s*(≤|<)\s*x\s*(≤|<)\s*("# + num + #")\s*,\s*q\s*:\s*x\s*(≤|<|≥|>)\s*a\s*에\s*대하여\s*,?\s*p\s*(?:가|는)\s*q\s*이기\s*위한\s*충분조건"#),
              let lo = rat(m[1]), let hi = rat(m[4]), lo.value < hi.value, t.range(of: #"(?:실수|상수)\s*a\s*의\s*(최솟값|최댓값)"#, options: .regularExpression) != nil else { return nil }
        let asksMin = t.contains("최솟값")
        // p ⊂ q
        switch m[5] {
        case "≤", "<":
            guard asksMin else { return nil }
            if m[5] == "<", m[3] == "≤" { return nil }   // a > hi: 최솟값 없음
            return Solved(kind: .sets, topic: "충분조건", concept: "p가 q이기 위한 충분조건 ⇔ P ⊂ Q (진리집합)", steps: [step("P ⊂ Q 이려면", "a ≥ \(show(hi))")], answer: show(hi))
        default:
            guard !asksMin else { return nil }
            if m[5] == ">", m[2] == "≤" { return nil }
            return Solved(kind: .sets, topic: "충분조건", concept: "p가 q이기 위한 충분조건 ⇔ P ⊂ Q (진리집합)", steps: [step("P ⊂ Q 이려면", "a ≤ \(show(lo))")], answer: show(lo))
        }
    }

    // MARK: 수학Ⅰ · Ⅱ

    static func radicals(_ t: String) -> Solved? {
        guard has(t, ["∛", "∜"]), let m = match(t, #"^\s*(?:\d+\s*[.)번]\s*)?([0-9∛∜√*/+\-()\s]+?)\s*(?:의\s*값|을\s*계산|를\s*계산|을\s*간단히|를\s*간단히)"#) else { return nil }
        var e = m[1]
        var steps: [SolutionStep] = []
        for (symbol, k) in [("∛", 3), ("∜", 4), ("√", 2)] {
            for r in matches(e, symbol + #"\s*(\d+)"#) {
                guard let n = Int(r[1]), let root = DoitMathExact.integerRoot(n, k) else { return nil }
                steps.append(step(r[0], "\(root)"))
                e = e.replacingOccurrences(of: r[0], with: "(\(root))")
            }
        }
        guard !e.contains("∛"), !e.contains("∜"), !e.contains("√"), let v = eval(e) else { return nil }
        steps.append(step("계산하면", show(v)))
        return Solved(kind: .calc, topic: "거듭제곱근", concept: "ⁿ√(aⁿ) = a (a > 0)", steps: steps, answer: show(v))
    }

    static func pythagoreanIdentity(_ t: String) -> Solved? {
        guard let m = match(t, #"(sin|cos)\^2\s*\(?\s*([^()+\s]+)\s*\)?\s*\+\s*(sin|cos)\^2\s*\(?\s*([^()+\s]+)\s*\)?\s*의\s*값"#), m[1] != m[3], m[2] == m[4] else { return nil }
        return Solved(kind: .calc, topic: "삼각함수 사이의 관계", concept: "모든 θ에 대하여 sin²θ + cos²θ = 1", steps: [step("sin²θ + cos²θ", "1")], answer: "1")
    }

    /// lim_{x→p} (x² + ax + b)/(x − p) = L 일 때 a, b
    static func limitConstants(_ t: String) -> Solved? {
        let s = DoitMathCalc.prepare(t)
        guard let m = match(s, #"lim_?\(?x→(-?\d+)\)?\(([^()]+)\)/\(([^()]+)\)=(-?\d+(?:/\d+)?)"#), let p = rat(m[1]), let L = rat(m[4]),
              let ask = match(t, #"상수\s*a\s*,\s*b\s*에\s*대하여\s*([ab+\-*\s\d()]+?)\s*의\s*값"#) else { return nil }
        let numer = m[2], denom = m[3]
        guard Set(numer.filter { $0.isLetter }) == ["x", "a", "b"], !denom.contains("a"), !denom.contains("b"),
              let dn = DoitMathCalc.parse(denom), let d0 = DoitMathCalc.evalRat(dn, p), d0.isZero,
              let dd = DoitMathCalc.evalRat(dn.derivative, p), !dd.isZero else { return nil }
        // N(p; a, b) = 0, N'(p; a, b) = L·D'(p): a, b에 대한 일차식 두 개
        func values(_ a: Rat, _ b: Rat) -> (Rat, Rat)? {
            let filled = put(put(numer, "a", a), "b", b)
            guard let node = DoitMathCalc.parse(filled), let v = DoitMathCalc.evalRat(node, p), let dv = DoitMathCalc.evalRat(node.derivative, p),
                  let ld = L * dd, let e2 = dv - ld else { return nil }
            return (v, e2)
        }
        guard let o = values(.zero, .zero), let ea = values(.one, .zero), let eb = values(.zero, .one),
              let a1 = ea.0 - o.0, let b1 = eb.0 - o.0, let a2 = ea.1 - o.1, let b2 = eb.1 - o.1,
              let det1 = a1 * b2, let det2 = a2 * b1, let det = det1 - det2, !det.isZero,
              let x1 = b1 * o.1, let x2 = b2 * o.0, let an = x1 - x2, let a = an / det,
              let y1 = a2 * o.0, let y2 = a1 * o.1, let bn = y1 - y2, let b = bn / det,
              let check = values(a, b), check.0.isZero, check.1.isZero else { return nil }
        var expr = ask[1]
        expr = put(put(expr, "a", a), "b", b)
        guard let v = eval(expr) else { return nil }
        return Solved(kind: .derivative, topic: "극한값으로 상수 구하기", concept: "(분모) → 0 이고 극한값이 있으면 (분자) → 0 이어야 해요. 분자를 인수분해(또는 미분계수)로 극한값을 구해요.",
                      steps: [step("x → \(show(p))일 때 (분자) → 0", "a = \(show(a)), b = \(show(b))"), step(ask[1].trimmingCharacters(in: .whitespaces), show(v))], answer: show(v))
    }

    // MARK: 어떤 수의 2배에서 3을 뺀 수는 그 수에 5를 더한 수와 같다

    /// "어떤 수의 k배", "에서 n을 뺀 수", "에 n을 더한 수" 를 식으로 (모르는 말이 있으면 nil)
    static func phrase(_ s: String) -> (Rat, Rat)? {
        var t = s.trimmingCharacters(in: .whitespaces)
        var a = Rat.one, b = Rat.zero
        guard let head = t.range(of: #"^(어떤\s*수|그\s*수|이\s*수)"#, options: .regularExpression) else { return nil }
        t = String(t[head.upperBound...]).trimmingCharacters(in: .whitespaces)
        while !t.isEmpty {
            if let m = match(t, #"^의\s*(\d+)\s*배"#), let k = rat(m[1]), let na = a * k, let nb = b * k { a = na; b = nb; t = String(t.dropFirst(m[0].count)) }
            else if let m = match(t, #"^(?:에서|보다)\s*("# + num + #")\s*(?:을|를)\s*뺀"#), let k = rat(m[1]), let nb = b - k { b = nb; t = String(t.dropFirst(m[0].count)) }
            else if let m = match(t, #"^에\s*("# + num + #")\s*(?:을|를)\s*더한"#), let k = rat(m[1]), let nb = b + k { b = nb; t = String(t.dropFirst(m[0].count)) }
            else if let m = match(t, #"^보다\s*("# + num + #")\s*큰"#), let k = rat(m[1]), let nb = b + k { b = nb; t = String(t.dropFirst(m[0].count)) }
            else if let m = match(t, #"^보다\s*("# + num + #")\s*작은"#), let k = rat(m[1]), let nb = b - k { b = nb; t = String(t.dropFirst(m[0].count)) }
            else if let m = match(t, #"^\s*수"#) { t = String(t.dropFirst(m[0].count)) }
            else { return nil }
            t = t.trimmingCharacters(in: .whitespaces)
        }
        return (a, b)
    }

    static func numberSentence(_ t: String) -> Solved? {
        guard let m = match(t, #"^\s*(?:\d+\s*[.)번]\s*)?(어떤\s*수.+?)\s*(?:은|는)\s*(그\s*수.+?)\s*(?:와|과)\s*같다\s*,?\s*(?:이때\s*)?어떤\s*수(?:는|를\s*구)"#),
              let l = phrase(m[1]), let r = phrase(m[2]), let da = l.0 - r.0, !da.isZero, let db = r.1 - l.1, let x = db / da else { return nil }
        return Solved(kind: .linear, topic: "일차방정식의 활용", concept: "어떤 수를 x로 놓고 문장을 그대로 식으로 옮겨요.",
                      steps: [step("어떤 수를 x라 하면", "\(show(l.0))x + (\(show(l.1))) = \(show(r.0))x + (\(show(r.1)))"), step("풀면", "x = \(show(x))")], answer: show(x))
    }

    // MARK: - 답 다시 보기 (물은 값과 맞는지)

    static func review(_ solved: Solved, _ raw: String) -> Solved? {
        let t = DoitAlgebra.normalize(DoitMathExact.tidy(GeometryText.forSolver(raw)))
        let answer = solved.answer
        if let first = answer.first, "①②③④⑤".contains(first) { return solved }
        let plain = t.replacingOccurrences(of: " ", with: "")
        // 수가 하나도 없는 글 ("f'(x)를 구하시오", "x의 값을 구하시오")은 풀 수 없음
        let noChoices = DoitMathExact.splitChoices(raw)?.body ?? raw
        if DoitAlgebra.normalize(noChoices).rangeOfCharacter(from: .decimalDigits) == nil,
           !noChoices.contains(where: { "π√∞₀₁₂₃₄₅₆₇₈₉⁰¹²³⁴⁵⁶⁷⁸⁹".contains($0) }),
           noChoices.range(of: #"(?:한|두|세|네|다섯|여섯|일곱|여덟|아홉|열)\s*(?:개|번|명|장|자루|권|사람|가지|쌍|자리|면|쪽)|[삼사오육칠팔구십이]+각형|주사위|동전|(?:[A-Za-z가-힣]\s*,\s*){2,}[A-Za-z가-힣]"#, options: .regularExpression) == nil,
           !(noChoices.contains("∠") && !noChoices.contains("그림")) { return nil }
        // "√16의 제곱근"은 ±: 식만 떼어 √16 = 4로 계산한 답은 아님
        if t.range(of: #"(?<!양의\s)(?<!음의\s)제곱근(?:은|을|는|\?)"#, options: .regularExpression) != nil, !t.contains("양의 제곱근"), !t.contains("음의 제곱근"),
           !answer.contains("±"), !answer.contains(","), t.range(of: #"제곱근\s*\d"#, options: .regularExpression) == nil { return nil }
        // 그림을 봐야 하는 색칠한 부분
        if has(t, ["색칠", "어두운 부분", "빗금"]), has(t, ["그림"]), DoitFigureFacts.split(raw).facts.isEmpty { return nil }
        // 답이 문제에 주어진 등식 그대로 ("x = 3일 때 …"의 x = 3)
        if let m = match(answer.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "−", with: "-"), #"^([a-zA-Z])=(-?\d+(?:\.\d+)?(?:/\d+)?)$"#) {
            let pattern = "(?<![a-zA-Z0-9_])" + NSRegularExpression.escapedPattern(for: m[1]) + "=" + NSRegularExpression.escapedPattern(for: m[2]) + #"(?![0-9a-zA-Z.^/(])"#
            if plain.range(of: pattern, options: .regularExpression) != nil { return nil }
            // 다른 문자의 값을 물었는데 이 문자의 값을 답함 ("y의 값은?" → "x = …")
            if let asked = match(t, #"(?<![a-zA-Z'])([a-zA-Z])\s*의\s*값\s*(?:은|을|는|\?|$)"#)?[1], asked != m[1], t.range(of: "(?<![a-zA-Z])\(m[1])\\s*의\\s*값", options: .regularExpression) == nil { return nil }
        }
        // 함수의 식 없이 함숫값만 ("f(2)의 값은?")
        if t.range(of: #"(?<![a-z])[fgh]\s*\("#, options: .regularExpression) != nil, !t.contains("="),
           t.replacingOccurrences(of: #"(?<![a-z])[fgh]'?\s*\([^)]*\)"#, with: " ", options: .regularExpression).rangeOfCharacter(from: .decimalDigits) == nil { return nil }
        // 식 속 상수(a, b, k)를 정할 조건이 없는데 값이 나옴 ("f(x) = ax + 3 에 대하여 f(5)")
        if let d = match(t, #"f\(x\)\s*=\s*([0-9a-z+\-*/^().\s]+?)\s*(?:에\s*대하여|일\s*때|이고|,|이라)"#),
           !Set(d[1].replacingOccurrences(of: #"sin|cos|tan|ln|log|sqrt|exp|e"#, with: " ", options: .regularExpression).filter { $0.isLetter && $0.isASCII && $0 != "x" }).isEmpty,
           t.components(separatedBy: "=").count == 2,
           !answer.contains(where: { $0.isLetter && $0.isASCII }) { return nil }
        // 수 하나만 '계산'한 답 (문장 속 "10%", "f(2)"의 2만 떼어 읽음)
        if solved.topic == "계산", let work = solved.steps.first?.work {
            let core = work.replacingOccurrences(of: "를 계산하면", with: "").replacingOccurrences(of: " ", with: "")
            if core.range(of: #"^[(]?[-−]?\d+(?:\.\d+)?%?[)]?$"#, options: .regularExpression) != nil { return nil }
        }
        // 이차함수의 식을 물었는데 일차식
        if has(t, ["이차함수의 식", "포물선을 그래프로 하는", "이차함수를 구"]), answer.hasPrefix("y ="), !answer.contains("²"), !answer.contains("^2") { return nil }
        // 넓이를 물었는데 변의 길이만 (피타고라스 정리)
        if solved.topic.contains("피타고라스"), t.range(of: #"넓이(?:는|를|\?)"#, options: .regularExpression) != nil { return nil }
        if solved.topic.contains("피타고라스"), t.range(of: #"둘레(?:의\s*길이)?(?:는|를|\?)"#, options: .regularExpression) != nil { return nil }
        // 조건이 붙은 줄 세우기를 조건 없이 셈
        if solved.topic == "순열 (모두 나열)", has(t, ["맨 앞", "맨 뒤", "이웃", "양 끝", "사이에", "번째", "끼리", "않도록", "않는", "적어도", "포함"]) { return nil }
        // 대표 몇 명 뽑기를 순열로 셈
        if solved.topic.contains("순열 (모두 나열)"), t.range(of: #"\d+\s*명을\s*(?:뽑|선출)"#, options: .regularExpression) != nil { return nil }
        // 부분집합의 개수인데 조건(반드시 포함 · 포함하지 않음)을 안 봄
        if solved.topic == "부분집합의 개수", t.range(of: #"(?:반드시|포함하지|갖지|가지지)"#, options: .regularExpression) != nil { return nil }
        // n(A ∪ B)를 답했는데 다른 것을 물음
        if answer.hasPrefix("n(A∪B)"), let target = match(t, #"n\(\s*([^)]*)\)\s*의\s*값"#)?[1], target.replacingOccurrences(of: " ", with: "") != "A∪B" { return nil }
        // 두 수 중 작은 수 · 큰 수
        let listed = answer.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if listed.count >= 2, listed.allSatisfy({ rat($0) != nil }) {
            let values = listed.compactMap { rat($0) }
            if t.range(of: #"(?:가장\s*)?작은\s*수(?:는|를|\?)"#, options: .regularExpression) != nil, let v = values.min(by: { $0.value < $1.value }) {
                var out = solved; out.steps.append(step("작은 수", show(v))); out.answer = show(v); return out
            }
            if t.range(of: #"(?:가장\s*)?큰\s*수(?:는|를|\?)"#, options: .regularExpression) != nil, let v = values.max(by: { $0.value < $1.value }) {
                var out = solved; out.steps.append(step("큰 수", show(v))); out.answer = show(v); return out
            }
            if t.range(of: #"(?:두|세)\s*수의\s*합(?:은|을|\?)"#, options: .regularExpression) != nil {
                let s = values.reduce(Rat.zero) { ($0 + $1) ?? $0 }
                var out = solved; out.steps.append(step("합", show(s))); out.answer = show(s); return out
            }
        }
        // 집합을 구했는데 원소의 합 · 개수를 물음
        if let m = match(answer, #"^[A-Z∪∩\s−\-ᶜ()]*=\s*\{([^{}]*)\}$"#) {
            let items = m[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if t.range(of: #"원소의\s*합|원소들의\s*합"#, options: .regularExpression) != nil {
                let values = items.compactMap(rat)
                guard values.count == items.count else { return nil }
                let s = values.reduce(Rat.zero) { ($0 + $1) ?? $0 }
                var out = solved; out.steps.append(step("원소의 합", show(s))); out.answer = show(s); return out
            }
            if t.range(of: #"원소의\s*개수"#, options: .regularExpression) != nil {
                var out = solved; out.steps.append(step("원소의 개수", "\(items.count)")); out.answer = "\(items.count)"; return out
            }
        }
        return solved
    }
}
