import Foundation

/// 채점 결과
struct GradeResult: Codable, Equatable {
    enum Verdict: String, Codable {
        case correct, wrong, partial
        /// 확실하게 채점할 수 없음 → 사용자에게 확인 요청
        case needsReview
        var title: String {
            switch self {
            case .correct: return "정답"
            case .wrong: return "오답"
            case .partial: return "부분 정답"
            case .needsReview: return "확인 필요"
            }
        }
    }
    var verdict: Verdict
    /// 0~1 (부분 점수)
    var score: Double
    /// 어떻게 채점했는지 ("수식을 계산해서 비교", "선택지 번호 비교" …)
    var method: String
    /// 채점 근거
    var reasons: [String]
    /// 비교에 쓴 정답
    var answerUsed: String
    /// 정답을 어디서 가져왔는지 ("입력한 정답", "사진의 정답 표기", "두잇 풀이 엔진")
    var answerSource: String
}

/// 문제 유형별 자동 채점. 확실하지 않으면 정답/오답을 정하지 않고 확인을 요청해요.
enum DoitGrader {
    struct Input {
        var kind: ProblemKind
        var student: String
        /// 정답 (여러 개면 줄바꿈·"|"·" 또는 "로 나눔). 비어 있으면 수학은 직접 풀어 봄
        var answerKey: String
        var choices: [String] = []
        var problem: String = ""
        /// 서술형 채점 기준 (핵심 내용들). 비어 있으면 정답 문장에서 뽑음
        var rubric: [String] = []
    }

    static func grade(_ input: Input) -> GradeResult {
        let student = input.student.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !student.isEmpty else {
            return GradeResult(verdict: .needsReview, score: 0, method: "답 없음", reasons: ["내 답을 먼저 적어 주세요."], answerUsed: "", answerSource: "")
        }
        var key = input.answerKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var source = "입력한 정답"
        if key.isEmpty, input.kind == .math || input.kind == .multipleChoice, let solved = MathSolver.solve(input.problem) {
            // 정답을 모르면 두잇 풀이 엔진이 직접 풀어서 (객관식이면 그 값의 보기를 찾아서)
            key = solved.answer
            source = "두잇 풀이 엔진 (직접 풀어서 구함)"
            if input.kind == .multipleChoice, let index = input.choices.firstIndex(where: { equivalentMath($0, key) == true }) { key = "\(index + 1)" }
        }
        guard !key.isEmpty else {
            return GradeResult(verdict: .needsReview, score: 0, method: "정답 없음",
                               reasons: ["정답을 알 수 없어 채점하지 않았어요. 정답을 적거나, 맞았는지 직접 골라 주세요."], answerUsed: "", answerSource: "")
        }
        var result: GradeResult
        switch input.kind {
        case .multipleChoice: result = gradeChoice(student, key: key, choices: input.choices)
        case .shortAnswer: result = gradeShort(student, keys: alternatives(key))
        // 수학 답의 "또는"은 해를 이어 쓴 것이라 나누지 않음 ("x = 2 또는 x = 3")
        case .math: result = gradeMath(student, keys: alternatives(key, splitOr: false))
        case .essay: result = gradeEssay(student, key: key, rubric: input.rubric)
        }
        result.answerSource = source
        return result
    }

    /// 복수 정답 나누기 ("3 | 셋", "광합성 또는 탄소 동화 작용"). 분수 "1/2"는 나누지 않음
    static func alternatives(_ key: String, splitOr: Bool = true) -> [String] {
        key.components(separatedBy: CharacterSet(charactersIn: "|\n;")).flatMap { splitOr ? $0.components(separatedBy: " 또는 ") : [$0] }
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    // MARK: - 객관식

    /// "③", "3번", "3", "(3)" 또는 보기 글 그대로 → 번호
    static func choiceNumber(_ text: String, choices: [String]) -> Int? {
        let t = text.trimmingCharacters(in: .whitespaces)
        let map: [Character: Int] = ["①": 1, "②": 2, "③": 3, "④": 4, "⑤": 5]
        if let first = t.first, let n = map[first], t.count <= 2 { return n }
        // "④ 12"처럼 번호 뒤에 보기 내용이 붙은 답
        if let first = t.first, let n = map[first], t.dropFirst().first?.isWhitespace == true { return n }
        let digits = t.replacingOccurrences(of: #"[()번\s.)]"#, with: "", options: .regularExpression)
        if let n = Int(digits), (1...max(5, choices.count)).contains(n), t.count <= 4 { return n }
        if let index = choices.firstIndex(where: { normalizeText($0) == normalizeText(t) }) { return index + 1 }
        if let index = choices.firstIndex(where: { equivalentMath($0, t) == true }) { return index + 1 }
        return nil
    }

    static func gradeChoice(_ student: String, key: String, choices: [String]) -> GradeResult {
        guard let mine = choiceNumber(student, choices: choices) else {
            return GradeResult(verdict: .needsReview, score: 0, method: "선택지 번호 비교", reasons: ["'\(student)'이(가) 몇 번 보기인지 알 수 없어요. 번호로 적어 주세요."], answerUsed: key, answerSource: "")
        }
        let keys = alternatives(key).compactMap { choiceNumber($0, choices: choices) }
        guard !keys.isEmpty else {
            return GradeResult(verdict: .needsReview, score: 0, method: "선택지 번호 비교", reasons: ["정답 '\(key)'이(가) 몇 번 보기인지 알 수 없어요."], answerUsed: key, answerSource: "")
        }
        let right = keys.contains(mine)
        let shown = keys.map { "\($0)번" + (choices.indices.contains($0 - 1) ? " (\(choices[$0 - 1]))" : "") }.joined(separator: ", ")
        return GradeResult(verdict: right ? .correct : .wrong, score: right ? 1 : 0, method: "선택지 번호 비교",
                           reasons: [right ? "고른 \(mine)번이 정답이에요." : "고른 답은 \(mine)번, 정답은 \(shown)이에요."], answerUsed: shown, answerSource: "")
    }

    // MARK: - 단답형

    /// 띄어쓰기·기호·끝말(이다/입니다/예요) 정리
    static func normalizeText(_ s: String) -> String {
        var t = s.lowercased()
        t = t.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
        for ending in ["입니다", "이에요", "예요", "이다", "이요", "임", "."] where t.hasSuffix(ending) && t.count > ending.count + 1 { t.removeLast(ending.count); break }
        return t.filter { !$0.isWhitespace && !"·,.'\"!?~-_:;“”‘’「」『』".contains($0) }
    }

    static func gradeShort(_ student: String, keys: [String]) -> GradeResult {
        let mine = normalizeText(student)
        for key in keys {
            if mine == normalizeText(key) {
                return GradeResult(verdict: .correct, score: 1, method: "글자 비교 (띄어쓰기·기호 무시)", reasons: ["정답 '\(key)'과(와) 같아요."], answerUsed: keys.joined(separator: " / "), answerSource: "")
            }
            // 숫자 답은 값으로
            if let same = equivalentMath(student, key), same {
                return GradeResult(verdict: .correct, score: 1, method: "값 비교", reasons: ["정답 '\(key)'과(와) 값이 같아요."], answerUsed: keys.joined(separator: " / "), answerSource: "")
            }
        }
        // 거의 같으면 (한두 글자 차이) 확정하지 않고 확인 요청
        if let close = keys.first(where: { let k = normalizeText($0); return k.count >= 3 && editDistance(mine, k) <= max(1, k.count / 6) }) {
            return GradeResult(verdict: .needsReview, score: 0.5, method: "글자 비교", reasons: ["정답 '\(close)'과(와) 한두 글자가 달라요. 같은 뜻이면 '맞았어요'를 눌러 주세요."],
                               answerUsed: keys.joined(separator: " / "), answerSource: "")
        }
        return GradeResult(verdict: .wrong, score: 0, method: "글자 비교 (띄어쓰기·기호 무시)", reasons: ["정답은 '\(keys.joined(separator: "' 또는 '"))'이에요."],
                           answerUsed: keys.joined(separator: " / "), answerSource: "")
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        guard !x.isEmpty else { return y.count }
        guard !y.isEmpty else { return x.count }
        var previous = Array(0...y.count)
        for i in 1...x.count {
            var current = [i] + Array(repeating: 0, count: y.count)
            for j in 1...y.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[y.count]
    }

    // MARK: - 수학

    static func gradeMath(_ student: String, keys: [String]) -> GradeResult {
        var unreadable = false
        for key in keys {
            switch equivalentMath(student, key) {
            case true?:
                return GradeResult(verdict: .correct, score: 1, method: "수식 비교 (값·순서·표현 차이 무시)", reasons: ["'\(student)'은(는) 정답 '\(key)'과(와) 같아요."],
                                   answerUsed: keys.joined(separator: " / "), answerSource: "")
            case nil: unreadable = true
            case false?: continue
            }
        }
        if unreadable {
            return GradeResult(verdict: .needsReview, score: 0, method: "수식 비교", reasons: ["답을 수식으로 읽지 못해 비교할 수 없어요. 정답 '\(keys.joined(separator: ", "))'과(와) 직접 비교해 주세요."],
                               answerUsed: keys.joined(separator: " / "), answerSource: "")
        }
        // 해가 여러 개인데 일부만 맞으면 부분 정답
        if let mine = valueSet(student), let answer = keys.compactMap(valueSet).first, answer.count > 1 {
            let hit = mine.filter { m in answer.contains { abs($0 - m) < 1e-6 } }.count
            if hit > 0 && hit < answer.count && mine.count <= answer.count {
                return GradeResult(verdict: .partial, score: Double(hit) / Double(answer.count), method: "해 비교 (순서 무시)",
                                   reasons: ["해 \(answer.count)개 중 \(hit)개를 맞혔어요. 빠진 해가 있어요."], answerUsed: keys.joined(separator: " / "), answerSource: "")
            }
        }
        return GradeResult(verdict: .wrong, score: 0, method: "수식 비교 (값·순서·표현 차이 무시)", reasons: ["정답은 \(keys.joined(separator: " 또는 "))이에요."],
                           answerUsed: keys.joined(separator: " / "), answerSource: "")
    }

    /// 수학 답이 같은지: true / false / nil(읽을 수 없음)
    /// - 값: 0.5 = 1/2 = 2/4, √8 = 2√2, π
    /// - 해 모음: "x = 2 또는 x = 3" = "3, 2" (순서 무시)
    /// - 순서쌍·연립: "x=1, y=2" = "y=2, x=1", (1, 2) ≠ (2, 1)
    /// - 식: x² + 2x + 1 = (x + 1)² (여러 x 값을 넣어 비교)
    /// - 부등식·구간: 글자 정리 후 비교
    static func equivalentMath(_ a: String, _ b: String) -> Bool? {
        let x = cleanMath(a), y = cleanMath(b)
        if x.isEmpty || y.isEmpty { return nil }
        if x == y { return true }
        // 부등식
        if x.contains("<") || x.contains(">") || y.contains("<") || y.contains(">") {
            return normalizedInequality(x) == normalizedInequality(y)
        }
        // 변수 이름이 붙은 연립 해 (x=1,y=2)
        let vx = namedValues(x), vy = namedValues(y)
        if vx.count >= 2 || vy.count >= 2 {
            guard vx.count == vy.count, !vx.isEmpty else { return false }
            return vx.allSatisfy { name, value in vy[name].map { abs($0 - value) < 1e-6 } ?? false }
        }
        // 순서쌍
        if x.hasPrefix("("), y.hasPrefix("("), let px = tuple(x), let py = tuple(y), px.count >= 2 {
            return px.count == py.count && zip(px, py).allSatisfy { abs($0 - $1) < 1e-6 }
        }
        // 해 모음 (순서 무시)
        if let sx = valueSet(a), let sy = valueSet(b) {
            guard sx.count == sy.count else { return false }
            return sx.sorted().elementsEqual(sy.sorted()) { abs($0 - $1) < 1e-6 }
        }
        // x가 들어 있는 식: 여러 값을 넣어 비교
        if x.contains("x") || y.contains("x") {
            let samples = [-2.3, -0.7, 0.4, 1.9, 3.1]
            var compared = 0
            for v in samples {
                guard let p = Expression.evaluate(x, x: v), let q = Expression.evaluate(y, x: v) else { continue }
                compared += 1
                if abs(p - q) > 1e-6 * max(1, abs(p)) { return false }
            }
            return compared >= 3 ? true : nil
        }
        return nil
    }

    static func cleanMath(_ s: String) -> String {
        var t = s.lowercased()
        let replacements: [(String, String)] = [("−", "-"), ("–", "-"), ("×", "*"), ("·", "*"), ("÷", "/"), ("²", "^2"), ("³", "^3"), ("≤", "<="), ("≥", ">="),
                                                ("답:", ""), ("답", ""), ("정답", ""), ("π", "pi"), (" ", "")]
        for (from, to) in replacements { t = t.replacingOccurrences(of: from, with: to) }
        // 끝에 붙은 말 ("4이다", "4개", "4cm")
        t = t.replacingOccurrences(of: #"(이다|입니다|예요|이에요|개|cm|m|kg|g|도|°)$"#, with: "", options: .regularExpression)
        // "x=4"처럼 하나뿐인 해는 값만
        if t.range(of: #"^[a-z]=[^=,]+$"#, options: .regularExpression) != nil, !t.hasPrefix("y=") || !t.contains("x") { t.removeFirst(2) }
        return t
    }

    /// "2, 3" / "x=2또는x=3" / "2 또는 3" → [2, 3]
    static func valueSet(_ s: String) -> [Double]? {
        var t = cleanMath(s).replacingOccurrences(of: "또는", with: ",").replacingOccurrences(of: "or", with: ",")
        t = t.replacingOccurrences(of: #"[a-z]="#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "±", with: "±")
        var values: [Double] = []
        for part in t.split(separator: ",") {
            let piece = String(part)
            if piece.contains("±") {
                // a±b
                let sides = piece.components(separatedBy: "±")
                guard sides.count == 2, let b = Expression.evaluate(sides[1]) else { return nil }
                let a = sides[0].isEmpty ? 0 : (Expression.evaluate(sides[0]) ?? .nan)
                guard !a.isNaN else { return nil }
                values += [a + b, a - b]
            } else {
                guard let v = Expression.evaluate(piece) else { return nil }
                values.append(v)
            }
        }
        return values.isEmpty ? nil : values
    }

    private static func namedValues(_ t: String) -> [Character: Double] {
        var result: [Character: Double] = [:]
        for part in t.replacingOccurrences(of: "또는", with: ",").split(separator: ",") {
            let sides = part.split(separator: "=")
            guard sides.count == 2, sides[0].count == 1, let name = sides[0].first, name.isLetter, let v = Expression.evaluate(String(sides[1])) else { continue }
            result[name] = v
        }
        return result
    }

    private static func tuple(_ t: String) -> [Double]? {
        guard t.hasPrefix("("), t.hasSuffix(")") else { return nil }
        let parts = t.dropFirst().dropLast().split(separator: ",").map { Expression.evaluate(String($0)) }
        guard parts.allSatisfy({ $0 != nil }) else { return nil }
        return parts.compactMap { $0 }
    }

    private static func normalizedInequality(_ t: String) -> String {
        // "x>2" == "2<x"
        let s = t.replacingOccurrences(of: "또는", with: ",")
        if let m = s.firstMatch(of: #/^(-?[0-9./]+)(<=|<)x$/#) { return "x" + (m.2 == "<" ? ">" : ">=") + m.1 }
        if let m = s.firstMatch(of: #/^(-?[0-9./]+)(>=|>)x$/#) { return "x" + (m.2 == ">" ? "<" : "<=") + m.1 }
        return s
    }

    // MARK: - 서술형

    /// 정답(모범 답안)의 핵심 내용이 들어 있는지로 부분 점수. 항상 "추정" — 최종 판단은 사용자 확인
    static func gradeEssay(_ student: String, key: String, rubric: [String]) -> GradeResult {
        let points = rubric.isEmpty ? DoitProblemScan.splitSentences(key).filter { $0.count >= 4 } : rubric
        guard !points.isEmpty else {
            return GradeResult(verdict: .needsReview, score: 0, method: "채점 기준 없음", reasons: ["모범 답안이나 채점 기준을 적어 주면 핵심 내용을 확인해 드릴게요."], answerUsed: key, answerSource: "")
        }
        let mine = normalizeText(student)
        var met: [String] = [], missed: [String] = []
        for point in points {
            let words = DoitStudyCheck.contentWords(point).map(normalizeText).filter { $0.count >= 2 }
            guard !words.isEmpty else { continue }
            let covered = words.filter { mine.contains($0) }.count
            if Double(covered) / Double(words.count) >= 0.6 { met.append(point) } else { missed.append(point) }
        }
        let total = met.count + missed.count
        guard total > 0 else {
            return GradeResult(verdict: .needsReview, score: 0, method: "핵심 내용 비교", reasons: ["채점 기준을 읽지 못했어요. 직접 확인해 주세요."], answerUsed: key, answerSource: "")
        }
        let score = Double(met.count) / Double(total)
        var reasons = met.map { "✓ 포함: \($0)" } + missed.map { "✗ 빠짐: \($0)" }
        reasons.append("서술형은 표현이 달라도 맞을 수 있어서 점수는 추정이에요. 최종 결과는 직접 확인해 주세요.")
        // 서술형은 확정하지 않음: 모두 들어 있어도 '확인 필요'로, 점수와 근거만 보여줌
        return GradeResult(verdict: score == 0 ? .needsReview : .partial, score: score, method: "핵심 내용 포함 여부 (부분 점수)",
                           reasons: reasons, answerUsed: key, answerSource: "")
    }
}

/// 작은 계산기: 수, + − × ÷ ^, 괄호, √, pi, 곱셈 생략(2x, 2√3, 3(x+1)), 변수 x
enum Expression {
    static func evaluate(_ raw: String, x: Double? = nil) -> Double? {
        var parser = Parser(Array(DoitGrader.cleanMath(raw).replacingOccurrences(of: "√", with: "r").replacingOccurrences(of: "sqrt", with: "r")
            .replacingOccurrences(of: "pi", with: "p")), x: x)
        guard let value = parser.expression(), parser.index == parser.chars.count, value.isFinite else { return nil }
        return value
    }

    private struct Parser {
        let chars: [Character]
        var index = 0
        let x: Double?
        init(_ chars: [Character], x: Double?) { self.chars = chars; self.x = x }

        var peek: Character? { index < chars.count ? chars[index] : nil }

        mutating func expression() -> Double? {
            guard var value = term() else { return nil }
            while let c = peek, c == "+" || c == "-" {
                index += 1
                guard let rhs = term() else { return nil }
                value = c == "+" ? value + rhs : value - rhs
            }
            return value
        }

        mutating func term() -> Double? {
            guard var value = power() else { return nil }
            while let c = peek {
                if c == "*" || c == "/" {
                    index += 1
                    guard let rhs = power() else { return nil }
                    if c == "/" { guard rhs != 0 else { return nil }; value /= rhs } else { value *= rhs }
                } else if c == "(" || c == "r" || c == "p" || c == "x" || c.isNumber {
                    // 곱셈 생략
                    guard let rhs = power() else { return nil }
                    value *= rhs
                } else { break }
            }
            return value
        }

        mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            if peek == "^" {
                index += 1
                guard let exponent = power() else { return nil }
                return pow(base, exponent)
            }
            return base
        }

        mutating func unary() -> Double? {
            if peek == "-" { index += 1; return power().map { -$0 } }
            if peek == "+" { index += 1; return power() }
            return primary()
        }

        mutating func primary() -> Double? {
            guard let c = peek else { return nil }
            if c == "(" {
                index += 1
                let value = expression()
                guard peek == ")" else { return nil }
                index += 1
                return value
            }
            if c == "r" {
                index += 1
                guard let inside = primary(), inside >= 0 else { return nil }
                return inside.squareRoot()
            }
            if c == "p" { index += 1; return Double.pi }
            if c == "x" { index += 1; return x }
            if c.isNumber || c == "." {
                var text = ""
                while let d = peek, d.isNumber || d == "." { text.append(d); index += 1 }
                return Double(text)
            }
            return nil
        }
    }
}
