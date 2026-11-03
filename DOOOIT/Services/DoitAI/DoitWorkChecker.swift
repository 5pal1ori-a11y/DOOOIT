import Foundation

/// 풀이 과정 채점: 손으로 쓴 풀이를 한 줄씩 읽어서 어느 줄에서 틀렸는지 찾음 (외부 AI 없이 직접 계산)
/// - 방정식: 각 줄의 식이 원래 방정식과 같은 해를 가지는지 (같은 해 → 바르게 변형)
/// - 연립방정식: 각 줄이 실제 해를 만족하는지
/// - 식 계산·전개·인수분해: 각 줄의 식이 원래 식과 같은 다항식인지
/// - 그 밖의 유형: 마지막 줄의 답만 정답과 비교
enum DoitWorkChecker {
    enum Mark: String, Codable {
        case ok, wrong, skipped
        /// 앞 줄의 실수가 이어진 줄 (이 줄의 계산 자체는 맞음)
        case carried
    }

    struct Line: Codable, Identifiable {
        var id = UUID()
        var text: String
        var mark: Mark
        var note: String
    }

    struct Report: Codable {
        var lines: [Line]
        var verdict: String
        var finalCorrect: Bool?
        var firstWrongIndex: Int?
        var tips: [String]
        var correctAnswer: String

        var allGood: Bool { firstWrongIndex == nil && finalCorrect != false }
    }

    typealias MPoly = DoitAlgebra.MPoly
    typealias Poly = DoitMath.Poly
    private static func f(_ v: Double) -> String { DoitMath.fraction(v) }

    // MARK: - 진입점

    static func check(problem: String, work rawLines: [String]) -> Report {
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let solved = MathSolver.solve(problem)
        let answer = solved?.answer ?? ""
        guard !lines.isEmpty else {
            return Report(lines: [], verdict: "풀이가 비어 있어요. 내 풀이를 찍거나 적어주세요.", finalCorrect: nil, firstWrongIndex: nil, tips: [], correctAnswer: answer)
        }
        let normalized = DoitAlgebra.normalize(problem)

        // 1) 원래 문제가 방정식(미지수 하나)
        if let original = MathSolver.equationPoly(in: normalized), original.degree >= 1,
           solved.map({ [.linear, .quadraticEquation, .higherEquation].contains($0.kind) }) ?? true {
            return checkEquation(original: original, lines: lines, answer: answer)
        }
        // 2) 연립방정식
        if let solved, solved.kind == .system, let solution = systemSolution(solved.answer) {
            return checkSystem(solution: solution, lines: lines, answer: answer)
        }
        // 3) 식 계산·전개·인수분해
        if let solved, [.expression, .factor, .calc].contains(solved.kind) || solved.kind == .expression,
           let original = expressionPoly(problem) {
            return checkExpression(original: original, lines: lines, answer: answer)
        }
        if solved == nil, let original = expressionPoly(problem), !problem.contains("=") {
            return checkExpression(original: original, lines: lines, answer: answer)
        }
        // 4) 그 밖에는 최종 답만
        return checkFinalOnly(lines: lines, answer: answer, solvable: solved != nil)
    }

    // MARK: - 방정식

    private static func checkEquation(original: Poly, lines: [String], answer: String) -> Report {
        let targetRoots = DoitAlgebra.realRoots(original).map(\.value)
        let hasRealRoots = !targetRoots.isEmpty
        var result: [Line] = []
        var firstWrong: Int?
        var tips: [String] = []
        var lastRoots: [Double]?
        var previous: Poly?

        for (index, raw) in lines.enumerated() {
            let text = clean(raw)
            // "x = 2 또는 x = 3", "x = 2, 3" 처럼 답을 적은 줄
            if let roots = answerRoots(text) {
                lastRoots = roots
                if sameSet(roots, targetRoots) {
                    result.append(Line(text: raw, mark: .ok, note: "해가 맞아요"))
                } else if firstWrong != nil, let previous, sameSet(roots, DoitAlgebra.realRoots(previous).map(\.value)) {
                    result.append(Line(text: raw, mark: .carried, note: "앞 줄에서는 맞게 이어졌지만, 앞의 실수 때문에 답이 달라졌어요"))
                } else {
                    let missing = targetRoots.filter { t in !roots.contains { abs($0 - t) < 1e-6 } }
                    let extra = roots.filter { r in !targetRoots.contains { abs($0 - r) < 1e-6 } }
                    var note = "해가 달라요."
                    if !extra.isEmpty { note += " x = \(extra.map(f).joined(separator: ", "))는 원래 방정식을 만족하지 않아요." }
                    if !missing.isEmpty && extra.isEmpty { note += " 빠진 해: x = \(missing.map(f).joined(separator: ", "))" }
                    result.append(Line(text: raw, mark: .wrong, note: note))
                    if firstWrong == nil { firstWrong = index }
                }
                continue
            }
            guard let poly = equationOf(text) else {
                result.append(Line(text: raw, mark: .skipped, note: "식으로 읽지 못해서 건너뛰었어요"))
                continue
            }
            if poly.degree <= 0 {
                result.append(Line(text: raw, mark: abs(poly[0]) < 1e-9 ? .ok : .wrong,
                                   note: abs(poly[0]) < 1e-9 ? "참인 식이에요" : "성립하지 않는 식이에요 (계산을 다시 확인해요)"))
                if abs(poly[0]) >= 1e-9, firstWrong == nil { firstWrong = index }
                continue
            }
            if equivalent(poly, original, roots: targetRoots) {
                result.append(Line(text: raw, mark: .ok, note: "앞의 식과 같은 해를 가져요"))
            } else if firstWrong != nil, let previous, equivalent(poly, previous, roots: DoitAlgebra.realRoots(previous).map(\.value)) {
                result.append(Line(text: raw, mark: .carried, note: "앞 줄에서는 맞게 이어졌지만, 앞의 실수가 남아 있어요"))
            } else {
                var note = "여기서 식이 달라졌어요."
                let lineRoots = DoitAlgebra.realRoots(poly).map(\.value)
                if !lineRoots.isEmpty && hasRealRoots {
                    note += " 이 식의 해는 x = \(lineRoots.map(f).joined(separator: ", "))인데, 원래 해는 x = \(targetRoots.map(f).joined(separator: ", "))예요."
                }
                note += " " + diagnose(poly, against: original)
                result.append(Line(text: raw, mark: .wrong, note: note))
                if firstWrong == nil { firstWrong = index }
            }
            if poly.degree == 1 { lastRoots = [-poly[0] / poly[1]] }
            previous = poly
        }

        let finalCorrect = lastRoots.map { sameSet($0, targetRoots) }
        if firstWrong != nil { tips.append("틀린 줄 바로 앞까지는 맞았어요. 그 줄의 이항·부호·계산을 다시 확인해 보세요.") }
        if finalCorrect == nil { tips.append("마지막에 'x = …' 처럼 답을 적어주면 최종 답도 확인할 수 있어요.") }
        return Report(lines: result, verdict: verdict(firstWrong: firstWrong, finalCorrect: finalCorrect),
                      finalCorrect: finalCorrect, firstWrongIndex: firstWrong, tips: tips, correctAnswer: answer)
    }

    /// 두 방정식이 같은 해를 가지는지: 비례하면 같고, 아니면 실근 집합을 비교 (인수분해 꼴 등)
    private static func equivalent(_ p: Poly, _ q: Poly, roots: [Double]) -> Bool {
        if proportional(p, q) { return true }
        let pRoots = DoitAlgebra.realRoots(p).map(\.value)
        // 근이 같고, 차수가 같은 경우만 (허근이 다른 경우까지는 비례 비교로)
        return !roots.isEmpty && sameSet(pRoots, roots) && p.degree <= q.degree
    }

    private static func proportional(_ p: Poly, _ q: Poly) -> Bool {
        guard p.degree == q.degree, p.degree >= 0 else { return false }
        let k = p[p.degree] / q[q.degree]
        guard abs(k) > 1e-12 else { return false }
        return (0..<Poly.size).allSatisfy { abs(p[$0] - k * q[$0]) < 1e-7 * max(1, abs(p[$0])) }
    }

    /// 무엇이 틀렸는지 짐작 (부호, 상수항, 계수)
    private static func diagnose(_ p: Poly, against q: Poly) -> String {
        guard p.degree == q.degree, p.degree >= 1 else {
            return p.degree != q.degree ? "식의 차수가 바뀌었어요 (전개나 약분을 확인해요)." : ""
        }
        let k = p[p.degree] / q[q.degree]
        var diffs: [Int] = []
        for i in 0..<Poly.size where abs(p[i] - k * q[i]) > 1e-7 { diffs.append(i) }
        guard diffs.count == 1, let i = diffs.first else { return "여러 곳이 달라요. 한 줄씩 천천히 다시 계산해 보세요." }
        let name = i == 0 ? "상수항" : i == 1 ? "x의 계수" : "x\(DoitMath.superscript(i))의 계수"
        if abs(p[i] + k * q[i]) < 1e-7 { return "\(name)의 부호가 바뀌었어요 (이항할 때 부호를 바꿨는지 확인해요)." }
        return "\(name)이 달라요 (\(f(p[i])) → 맞는 값은 \(f(k * q[i])))."
    }

    // MARK: - 연립방정식

    private static func checkSystem(solution: [Character: Double], lines: [String], answer: String) -> Report {
        var result: [Line] = []
        var firstWrong: Int?
        var finalValues: [Character: Double] = [:]
        for (index, raw) in lines.enumerated() {
            let text = clean(raw)
            let parts = text.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2, let l = DoitAlgebra.parse(parts[0]), let r = DoitAlgebra.parse(parts[1]) else {
                result.append(Line(text: raw, mark: .skipped, note: "식으로 읽지 못해서 건너뛰었어요"))
                continue
            }
            let e = l - r
            let value = e.value(x: solution["x"] ?? 0, y: solution["y"] ?? 0, z: solution["z"] ?? 0)
            // "x = 3" 같은 답 줄 기억
            if e.degree == 1, e.variables.count == 1, let v = e.variables.first {
                let coefficient = v == "x" ? e.coef(x: 1) : v == "y" ? e.coef(y: 1) : e.coef(z: 1)
                if abs(coefficient) > 1e-12 { finalValues[v] = -e.constantValue / coefficient }
            }
            if abs(value) < 1e-7 {
                result.append(Line(text: raw, mark: .ok, note: "실제 해를 넣으면 성립해요"))
            } else {
                result.append(Line(text: raw, mark: .wrong, note: "실제 해 (\(solution.sorted { $0.key < $1.key }.map { "\($0.key) = \(f($0.value))" }.joined(separator: ", ")))를 넣으면 성립하지 않아요. 이 줄의 계산을 확인해요."))
                if firstWrong == nil { firstWrong = index }
            }
        }
        let finalCorrect: Bool? = finalValues.isEmpty ? nil : finalValues.allSatisfy { abs($0.value - (solution[$0.key] ?? .nan)) < 1e-7 }
        return Report(lines: result, verdict: verdict(firstWrong: firstWrong, finalCorrect: finalCorrect), finalCorrect: finalCorrect,
                      firstWrongIndex: firstWrong, tips: firstWrong == nil ? [] : ["가감법에서 양변에 같은 수를 곱했는지, 빼는 순서를 바꾸지 않았는지 확인해요."],
                      correctAnswer: answer)
    }

    private static func systemSolution(_ answer: String) -> [Character: Double]? {
        var result: [Character: Double] = [:]
        for m in answer.matches(of: #/([xyz])\s*=\s*(−?-?\d+(?:\.\d+)?(?:/\d+)?)/#) {
            let raw = String(m.2).replacingOccurrences(of: "−", with: "-")
            let pieces = raw.split(separator: "/").compactMap { Double(String($0)) }
            guard let first = pieces.first else { continue }
            result[Character(String(m.1))] = pieces.count == 2 && pieces[1] != 0 ? first / pieces[1] : first
        }
        return result.count >= 2 ? result : nil
    }

    // MARK: - 식 계산·전개·인수분해

    private static func checkExpression(original: MPoly, lines: [String], answer: String) -> Report {
        var result: [Line] = []
        var firstWrong: Int?
        var last: MPoly?
        for (index, raw) in lines.enumerated() {
            let text = clean(raw)
            // "= …" 로 시작하거나 "A = B = C" 처럼 이어 쓴 줄
            let parts = text.split(separator: "=").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !parts.isEmpty else { continue }
            var lineOK = true
            var parsedAny = false
            var carried = true
            let before = last
            for part in parts {
                guard let p = DoitAlgebra.parse(part) else { continue }
                parsedAny = true
                last = p
                if !same(p, original) { lineOK = false }
                if before.map({ !same(p, $0) }) ?? true { carried = false }
            }
            if !parsedAny {
                result.append(Line(text: raw, mark: .skipped, note: "식으로 읽지 못해서 건너뛰었어요"))
            } else if lineOK {
                result.append(Line(text: raw, mark: .ok, note: "원래 식과 같아요"))
            } else if firstWrong != nil && carried {
                result.append(Line(text: raw, mark: .carried, note: "앞 줄에서는 맞게 이어졌지만, 앞의 실수가 남아 있어요"))
            } else {
                result.append(Line(text: raw, mark: .wrong, note: "원래 식과 달라졌어요. 전개할 때 빠진 항이나 부호를 확인해요."))
                if firstWrong == nil { firstWrong = index }
            }
        }
        let finalCorrect = last.map { same($0, original) }
        return Report(lines: result, verdict: verdict(firstWrong: firstWrong, finalCorrect: finalCorrect), finalCorrect: finalCorrect,
                      firstWrongIndex: firstWrong, tips: firstWrong == nil ? [] : ["곱셈 공식: (a ± b)² = a² ± 2ab + b², (a + b)(a − b) = a² − b²"],
                      correctAnswer: answer)
    }

    private static func same(_ a: MPoly, _ b: MPoly) -> Bool {
        let d = (a - b).cleaned
        return d.t.values.allSatisfy { abs($0) < 1e-7 }
    }

    private static func expressionPoly(_ problem: String) -> MPoly? {
        let expression = DoitAlgebra.extract(problem)
        guard !expression.isEmpty, !expression.contains("=") else { return nil }
        return DoitAlgebra.parse(expression)
    }

    // MARK: - 최종 답만

    private static func checkFinalOnly(lines: [String], answer: String, solvable: Bool) -> Report {
        guard solvable, !answer.isEmpty else {
            return Report(lines: lines.map { Line(text: $0, mark: .skipped, note: "") },
                          verdict: "이 문제는 모티 AI가 직접 풀 수 없는 유형이라 과정을 확인하지 못했어요.",
                          finalCorrect: nil, firstWrongIndex: nil, tips: ["문제 글이 정확히 읽혔는지 '문제' 탭에서 확인해 주세요."], correctAnswer: answer)
        }
        let answerNumbers = Set(numbers(in: answer).map { ($0 * 1000).rounded() })
        let lastNumbers = Set(numbers(in: lines.last ?? "").map { ($0 * 1000).rounded() })
        let correct = !answerNumbers.isEmpty && !lastNumbers.isEmpty && answerNumbers.isSubset(of: lastNumbers.union(answerNumbers)) && !answerNumbers.isDisjoint(with: lastNumbers)
        var marked = lines.map { Line(text: $0, mark: .skipped, note: "") }
        if !marked.isEmpty {
            marked[marked.count - 1].mark = correct ? .ok : .wrong
            marked[marked.count - 1].note = correct ? "최종 답이 맞아요" : "최종 답이 달라요"
        }
        return Report(lines: marked, verdict: correct ? "최종 답이 맞아요! (이 유형은 중간 과정 대신 답만 확인했어요)" : "최종 답이 정답과 달라요.",
                      finalCorrect: correct, firstWrongIndex: correct ? nil : marked.count - 1,
                      tips: ["이 유형은 줄마다 확인하지 않고 마지막 답만 비교했어요."], correctAnswer: answer)
    }

    // MARK: - 도구

    private static func verdict(firstWrong: Int?, finalCorrect: Bool?) -> String {
        switch (firstWrong, finalCorrect) {
        case (nil, true?): return "완벽해요! 풀이 과정과 답이 모두 맞아요. 🎉"
        case (nil, nil): return "지금까지의 풀이는 모두 맞아요. 답까지 적어보세요."
        case (nil, false?): return "과정은 맞는데 최종 답이 달라요."
        case (let i?, true?): return "답은 맞지만 \(i + 1)번째 줄에 실수가 있어요."
        case (let i?, _): return "\(i + 1)번째 줄에서 처음 틀렸어요."
        }
    }

    /// 줄 앞뒤 기호 정리: "∴ x = 3", "→ 2x = 8", "①", "(1)" 등
    static func clean(_ raw: String) -> String {
        var t = DoitAlgebra.normalize(raw)
        t = t.replacingOccurrences(of: #"^\s*(∴|→|⇒|=>|\(\d\)|[①②③④⑤]|\d\.)\s*"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "∴", with: " ")
        // 한글 설명은 빼고 식만
        let expression = DoitAlgebra.extract(t, extra: ",또는±")
        return expression.isEmpty ? t : expression
    }

    /// "x = 2 또는 x = 3", "x = 2, 3", "x = −1 ± 2" → 근 목록 (식이 아니라 답을 적은 줄)
    private static func answerRoots(_ text: String) -> [Double]? {
        let t = text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "또는", with: ",")
        guard t.hasPrefix("x=") else { return nil }
        var pieces: [String] = []
        for piece in t.replacingOccurrences(of: "x=", with: "").split(separator: ",").map(String.init) {
            if piece.contains("±") {
                pieces.append(piece.replacingOccurrences(of: "±", with: "+"))
                pieces.append(piece.replacingOccurrences(of: "±", with: "-"))
            } else {
                pieces.append(piece)
            }
        }
        var roots: [Double] = []
        for piece in pieces {
            guard let p = DoitAlgebra.parse(piece), p.isConstant else { return nil }
            roots.append(p.constantValue)
        }
        // "x = 4" 한 개는 방정식으로도 볼 수 있지만 답으로 처리해도 같음
        return roots.isEmpty ? nil : roots
    }

    private static func equationOf(_ text: String) -> Poly? {
        let parts = text.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2, let l = DoitAlgebra.parse(parts[0]), let r = DoitAlgebra.parse(parts[1]) else { return nil }
        return (l - r).univariate
    }

    private static func sameSet(_ a: [Double], _ b: [Double]) -> Bool {
        let ua = unique(a), ub = unique(b)
        guard ua.count == ub.count else { return false }
        return ua.allSatisfy { x in ub.contains { abs($0 - x) < 1e-6 } }
    }

    private static func unique(_ values: [Double]) -> [Double] {
        var out: [Double] = []
        for v in values where !out.contains(where: { abs($0 - v) < 1e-9 }) { out.append(v) }
        return out
    }

    private static func numbers(in text: String) -> [Double] {
        DoitMathTopics.numbers(in: text)
    }
}
