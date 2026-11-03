import Foundation

/// 문제 유형 (채점 방법이 달라요)
enum ProblemKind: String, Codable, CaseIterable, Identifiable {
    case multipleChoice, shortAnswer, math, essay
    var id: String { rawValue }
    var title: String {
        switch self {
        case .multipleChoice: return "객관식"
        case .shortAnswer: return "단답형"
        case .math: return "수학 계산"
        case .essay: return "서술형"
        }
    }
}

/// 사진·글에서 읽은 문제를 나눠 정리한 것 (사용자가 확인하기 전까지는 "임시")
struct ProblemScan: Codable, Equatable {
    /// 불확실한 부분
    struct Doubt: Codable, Equatable, Hashable {
        var text: String
        var reason: String
    }

    var body: String = ""
    var formulas: [String] = []
    var choices: [String] = []
    var conditions: [String] = []
    var table: [[String]] = []
    var graphNote: String?
    /// 질문의 핵심 ("~을 구하시오", "~은?")
    var question: String = ""
    var kind: ProblemKind = .shortAnswer
    /// 사진 속에 적힌 정답 표기 (있을 때만)
    var printedAnswer: String?
    var doubts: [Doubt] = []
    /// 글로 자동으로 정한 과목 (노트 과목이 이 값과 같으면 사용자가 아직 직접 고르지 않은 것). 예전 노트는 nil
    var autoSubject: String?
    /// 문제 유형 사전(DoitProblemTypes)에서 찾은 유형 id
    var typeID: String?
    /// <보기> 상자의 항목 ("ㄱ. …", "ㄴ. …"). 예전 노트는 nil
    var boxItems: [String]?
    /// 그림·그래프·차트·표에서 읽은 줄 (문제 글 끝 "[그림에서 읽음]" 블록, 기계가 읽은 값이라 확인 필요). 없으면 nil
    var figureLines: [String]?
    /// 문제 번호 ("12." · "12번)" · "[12]" → 12). 없거나 예전 노트는 nil
    var number: Int?

    var hasDoubts: Bool { !doubts.isEmpty }

    /// 찾은 문제 유형
    var problemType: ProblemType? { typeID.flatMap(DoitProblemTypes.type(id:)) }
}

/// 문제 글을 본문·수식·선택지·조건·표·질문으로 나눔 (사진에서 확인할 수 없는 내용은 만들지 않음)
enum DoitProblemScan {
    /// - text: 읽은 글 (사용자가 고친 글이어도 됨)
    /// - lowConfidence: 글자 인식이 자신 없어 한 줄들
    /// - graphNote: 그림 분석 결과 (그래프가 있으면)
    /// - math: false면 수학이 아닌 과목 (수식 찾기·수학 유형 판단을 하지 않고, 정답 표기는 줄 맨 앞의 것만)
    static func scan(_ raw: String, lowConfidence: [String] = [], graphNote: String? = nil, math: Bool = true) -> ProblemScan {
        var result = ProblemScan()
        // 그림에서 읽은 블록은 떼어 두고 문제 글만 나눔 (선택지·질문·수식에 섞이지 않게)
        let figure = DoitFigureFacts.split(raw.replacingOccurrences(of: "\r", with: ""))
        var text = figure.problem
        // 0) 맨 앞 문제 번호는 따로 ("12번) 다음 중…" → 번호 12, 본문 "다음 중…")
        if let found = leadingNumber(text) {
            result.number = found.number
            text = found.rest
        }
        var lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // <보기> ㄱ. ㄴ. ㄷ. 항목: 글자 인식이 ㄱ을 "7", ㄴ을 "L", ㄷ을 "C"로 읽은 것도 바로잡음
        let box = boxItems(in: lines)
        lines = box.lines
        if !box.items.isEmpty { result.boxItems = box.items }

        // 1) 사진에 적힌 정답 ("정답: ③")은 문제에서 빼서 따로
        if let answer = math ? MathGrader.extractAnswer(from: text) : DoitSubjectNote.printedAnswer(in: text) {
            result.printedAnswer = answer
            lines.removeAll { $0.range(of: #"^(정답|답)\s*[:：)]"#, options: .regularExpression) != nil || (!math && DoitSubjectNote.printedAnswer(in: $0) != nil) }
        }

        // 2) 선택지: 줄마다 ①~⑤ / (1)~(5) / 1) ~ 5), 한 줄에 여러 개도
        var bodyLines: [String] = []
        for (index, line) in lines.enumerated() {
            // "3. 다음 중…" 같은 문제 번호는 선택지가 아님: "N."은 1부터 차례대로 이어질 때만 선택지
            if let m = line.firstMatch(of: #/^([1-5])\.\s/#), let n = Int(m.1) {
                let next = index + 1 < lines.count ? lines[index + 1] : ""
                let inSequence = n == result.choices.count + 1 && (n > 1 || next.hasPrefix("2."))
                if !inSequence { bodyLines.append(String(line.dropFirst(m.0.count))); continue }
            }
            let found = choices(in: line)
            if found.count >= 1, startsWithChoiceMark(line) {
                result.choices += found
            } else if found.count >= 3, math || !isPassageLine(line, parts: found) {
                result.choices += found
            } else {
                bodyLines.append(line)
            }
        }

        // 2-1) <보기> 문제의 조합 선택지 ("ㄱ, ㄷ"): 자음을 닮은 글자("7", "L", "C")를 자음으로, 쉼표 모양 통일
        if !box.items.isEmpty || lines.contains(where: { $0.contains("보기") }) {
            let mapped = result.choices.map(jamoCombination)
            let real = result.choices.map { $0.contains(where: { jamoMarks.contains($0) }) }
            // 모두 자음 조합이면 함께 바꿈 (진짜 자음이 하나라도 있거나 <보기> 항목이 있을 때). 아니면 진짜 자음이 든 것만
            if mapped.allSatisfy(isJamoList), real.contains(true) || !box.items.isEmpty {
                result.choices = mapped
            } else if mapped.filter(isJamoList).count * 2 > mapped.count, real.contains(true) || !box.items.isEmpty {
                // 대부분이 자음 조합이면 바꿀 수 있는 것만 바꿈 (하나를 잘못 읽어도 나머지는 살림)
                result.choices = result.choices.indices.map { isJamoList(mapped[$0]) ? mapped[$0] : result.choices[$0] }
            } else {
                result.choices = result.choices.indices.map { real[$0] ? mapped[$0] : result.choices[$0] }
            }
        }

        // 3) 표: "|"로 나뉜 줄이나 숫자·낱말이 세 칸 이상 띄어 쓴 줄이 두 줄 넘게 이어지면
        var tableRows: [[String]] = []
        var keep: [String] = []
        for line in bodyLines {
            let cells = tableCells(line)
            if cells.count >= 3 { tableRows.append(cells) } else { keep.append(line) }
        }
        if tableRows.count >= 2 { result.table = tableRows; bodyLines = keep }

        result.body = bodyLines.joined(separator: "\n")
        let problemBody = result.body
        if !figure.facts.isEmpty {
            result.figureLines = figure.facts
            // 본문에는 블록을 그대로 둠 (풀이·설명이 그림에서 읽은 값을 쓰게)
            result.body += (result.body.isEmpty ? "" : "\n") + DoitFigureFacts.block(figure.facts)
        }

        // 4) 조건: "단," "(단 …)" "~일 때" "자연수·정수·실수·양수" 같은 제한
        let sentences = splitSentences(problemBody)
        result.conditions = sentences.filter(isCondition)

        // 5) 질문의 핵심: "구하시오/고르시오/쓰시오/설명하시오/~은?" 문장
        result.question = sentences.last(where: isQuestion) ?? sentences.last ?? ""

        // 6) 수식: 수식다운 덩어리
        if math { result.formulas = formulas(in: problemBody + "\n" + result.choices.joined(separator: "\n")) }

        result.graphNote = graphNote
        result.kind = guessKind(body: result.body, choices: result.choices, question: result.question, math: math)

        // 7) 불확실한 부분: 인식이 자신 없던 줄 + 수식이 이상한 곳
        var doubts: [ProblemScan.Doubt] = []
        for line in lowConfidence where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            doubts.append(.init(text: line, reason: "글자가 흐리거나 작아서 확실하지 않아요"))
        }
        for formula in result.formulas {
            if let reason = suspicious(formula) { doubts.append(.init(text: formula, reason: reason)) }
        }
        if result.kind == .multipleChoice, result.choices.count < 5, result.choices.count >= 2, numbered(result.choices) {
            doubts.append(.init(text: "선택지 \(result.choices.count)개", reason: "선택지가 5개가 아니에요. 빠진 보기가 없는지 확인해 주세요"))
        }
        if graphNote == nil, figure.facts.isEmpty, problemBody.contains("그래프") || problemBody.contains("그림") {
            doubts.append(.init(text: "그래프·그림", reason: "문제에 그래프나 그림이 있지만 내용을 읽지 못했어요. 필요한 값은 직접 적어 주세요"))
        }
        if problemBody.count < 6 && result.choices.isEmpty {
            doubts.append(.init(text: "문제 본문", reason: "읽은 글이 너무 짧아요. 영역을 다시 고르거나 직접 적어 주세요"))
        }
        var seen = Set<String>()
        result.doubts = doubts.filter { seen.insert($0.text + $0.reason).inserted }
        return result
    }

    // MARK: - 선택지

    private static let circled: [Character] = ["①", "②", "③", "④", "⑤"]

    static func startsWithChoiceMark(_ line: String) -> Bool {
        guard let first = line.first else { return false }
        if circled.contains(first) { return true }
        return line.range(of: #"^(\(?[1-5]\)|[1-5]\.)\s"#, options: .regularExpression) != nil
    }

    /// 한 줄 안의 선택지들 ("① 2 ② 3 ③ 4" → ["2", "3", "4"])
    static func choices(in line: String) -> [String] {
        // ①②③④⑤
        if line.contains(where: { circled.contains($0) }) {
            var parts: [String] = []
            var current: String?
            for ch in line {
                if circled.contains(ch) {
                    if let c = current { parts.append(c.trimmingCharacters(in: .whitespaces)) }
                    current = ""
                } else if current != nil {
                    current?.append(ch)
                }
            }
            if let c = current { parts.append(c.trimmingCharacters(in: .whitespaces)) }
            return parts.filter { !$0.isEmpty }
        }
        // (1) … (2) … / 1) … 2) …
        let pattern = #"(?:^|\s)\(?([1-5])[)\.]\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return [] }
        // 번호가 1부터 차례대로일 때만 선택지로 봄 ("3. 다음 중…" 같은 문제 번호는 아님)
        let numbers = matches.map { Int(ns.substring(with: $0.range(at: 1))) ?? 0 }
        guard numbers.first == 1 || (matches.count == 1 && startsWithChoiceMark(line)), numbers == Array(numbers.first!..<(numbers.first! + numbers.count)) else { return [] }
        var parts: [String] = []
        for (i, m) in matches.enumerated() {
            let start = m.range.location + m.range.length
            let end = i + 1 < matches.count ? matches[i + 1].range.location : ns.length
            parts.append(ns.substring(with: NSRange(location: start, length: max(0, end - start))).trimmingCharacters(in: .whitespaces))
        }
        return parts.filter { !$0.isEmpty }
    }

    private static func numbered(_ choices: [String]) -> Bool { !choices.isEmpty }

    /// 지문 속 밑줄 번호(①~⑤)가 든 줄인지: 첫 번호 앞에 글이 있고 번호 사이 글이 긴 줄 ("Many people ①believe that …")
    static func isPassageLine(_ line: String, parts: [String]) -> Bool {
        guard let first = line.firstIndex(where: { circled.contains($0) }) else { return false }
        let prefix = line[..<first].filter { !$0.isWhitespace }
        let average = parts.isEmpty ? 0 : parts.map(\.count).reduce(0, +) / parts.count
        return prefix.count >= 6 && average >= 12
    }

    // MARK: - <보기> ㄱ. ㄴ. ㄷ.

    private static let jamoMarks: [Character] = ["ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ"]
    /// 자음 대신 읽히는 글자 (첫 낱자 ᄀ·ᄂ·ᄃ, 숫자 7, 영어 L·C 등)
    private static let jamoLookalikes: [Character: Character] = [
        "ᄀ": "ㄱ", "7": "ㄱ", "ㄱ": "ㄱ",
        "ᄂ": "ㄴ", "L": "ㄴ", "ㄴ": "ㄴ", "└": "ㄴ", "1": "ㄴ", "4": "ㄴ",
        "ᄃ": "ㄷ", "C": "ㄷ", "c": "ㄷ", "⊏": "ㄷ", "匚": "ㄷ", "ㄷ": "ㄷ", "[": "ㄷ",
        "ᄅ": "ㄹ", "ㄹ": "ㄹ", "己": "ㄹ",
        "ᄆ": "ㅁ", "ㅁ": "ㅁ", "口": "ㅁ",
    ]

    /// 줄 처음의 "ㄱ.", "ㄴ)" 같은 항목 표시 (닮은 글자 포함) → (자음, 표시 뒤 글)
    private static func itemMark(_ line: Substring, expected: Character?) -> (mark: Character, rest: Substring)? {
        guard let first = line.first, let mark = jamoLookalikes[first] else { return nil }
        let after = line.dropFirst()
        guard let sep = after.first, ".)．,".contains(sep) else { return nil }
        // 진짜 자음이 아닌 닮은 글자는 차례가 맞을 때만 ("7. …"이 문제 번호일 수도 있어서)
        if !jamoMarks.contains(first), let expected, mark != expected { return nil }
        if !jamoMarks.contains(first), expected == nil { return nil }
        return (mark, after.dropFirst().drop(while: { $0 == " " }))
    }

    /// <보기> 상자의 항목을 찾아 (자음 표시를 바로잡은 줄들, 항목들). 한 줄에 여러 항목("ㄱ. … ㄴ. …")도 나눔
    static func boxItems(in lines: [String]) -> (lines: [String], items: [String]) {
        // 머리글 "<보기>" (뒤에 첫 항목을 이어 쓴 것도). "<보기>에서 고른 것은?" 같은 질문 줄은 아님
        func headerRest(_ line: String) -> Substring? {
            guard let r = line.range(of: #"^[•·\-_.\s]*[<〈《\[(［]?\s*보\s*기\s*[>〉》\])］]?\s*"#, options: .regularExpression) else { return nil }
            let rest = line[r.upperBound...]
            // 상자 테두리를 "-", "_" 로 읽은 것은 머리글 뒤 찌꺼기
            let trimmed = rest.drop { "-—–_=~|.·─ ".contains($0) }
            return trimmed.isEmpty || itemMark(trimmed, expected: "ㄱ") != nil ? trimmed : nil
        }
        let header = lines.firstIndex { headerRest($0) != nil }
        var out = lines
        var items: [String] = []
        // 보기 머리글이 없으면 진짜 자음 "ㄱ."으로 시작하는 줄부터
        let startIndex: Int
        if let header { startIndex = header } else if let first = lines.firstIndex(where: { $0.hasPrefix("ㄱ.") || $0.hasPrefix("ㄱ ") || $0.hasPrefix("ᄀ.") }) { startIndex = first } else { return (lines, []) }
        var i = startIndex
        while i < out.count {
            var line = Substring(out[i])
            if i == header {
                // 머리글 뒤에 이어 쓴 항목
                line = headerRest(out[i]) ?? line
                if line.isEmpty { i += 1; continue }
            }
            let expected: Character? = items.count < jamoMarks.count ? jamoMarks[items.count] : nil
            guard itemMark(line, expected: expected) != nil || (items.isEmpty == false && !startsWithChoiceMark(String(line)) && !line.contains(where: { circled.contains($0) }) && isContinuation(line)) else { break }
            if let mark = itemMark(line, expected: expected) {
                // 한 줄에 여러 항목: 다음 자음 표시 앞에서 자름
                var rest = mark.rest
                var parts: [(Character, Substring)] = []
                var current = mark.mark
                while true {
                    let next: Character? = parts.count + items.count + 1 < jamoMarks.count ? jamoMarks[parts.count + items.count + 1] : nil
                    guard let next, let r = rest.range(of: #"\s"# + String(next) + #"[.)]\s"#, options: .regularExpression) else { break }
                    parts.append((current, rest[..<r.lowerBound]))
                    current = next
                    rest = rest[r.upperBound...]
                }
                parts.append((current, rest))
                for (m, body) in parts { items.append("\(m). " + body.trimmingCharacters(in: .whitespaces)) }
                let fixed = parts.map { "\($0.0). " + $0.1.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
                out[i] = i == header ? out[i].replacingOccurrences(of: String(line), with: fixed) : fixed
            } else if let expected, items[items.count - 1].hasSuffix(".") || items[items.count - 1].hasSuffix("다"), line.count >= 4 {
                // 앞 항목이 문장으로 끝났으면 자음 표시("ㄷ.")를 못 읽은 다음 항목
                let body = line.trimmingCharacters(in: .whitespaces)
                items.append("\(expected). " + body)
                out[i] = "\(expected). " + body
            } else {
                // 앞 항목이 다음 줄로 이어짐
                items[items.count - 1] += " " + line.trimmingCharacters(in: .whitespaces)
            }
            i += 1
        }
        return (out, items.count >= 2 ? items : [])
    }

    /// 앞 항목에서 이어지는 줄인지 (질문·선택지 줄이 아님)
    private static func isContinuation(_ line: Substring) -> Bool {
        let s = String(line)
        return !isQuestion(s) && s.range(of: #"^\d+[.)]"#, options: .regularExpression) == nil && s.count >= 2
    }

    /// 조합 선택지 "7, C" → "ㄱ, ㄷ" (모두 자음 하나씩일 때만)
    static func jamoCombination(_ choice: String) -> String {
        let parts = choice.split(whereSeparator: { ", ，、·=.;".contains($0) }).map(String.init)
        var marks: [Character] = []
        for part in parts {
            // "ㄱㄴ"처럼 붙여 읽은 것도
            for c in part {
                guard let m = jamoLookalikes[c] else { return choice }
                marks.append(m)
            }
        }
        guard !marks.isEmpty, marks.count <= jamoMarks.count, Set(marks).count == marks.count else { return choice }
        // 자음 차례(ㄱ<ㄴ<ㄷ)가 맞을 때만
        let order = marks.compactMap { jamoMarks.firstIndex(of: $0) }
        guard order == order.sorted() else { return choice }
        return marks.map(String.init).joined(separator: ", ")
    }

    /// "ㄱ", "ㄱ, ㄷ" 같은 자음 조합인지
    static func isJamoList(_ choice: String) -> Bool {
        let parts = choice.components(separatedBy: ", ")
        return !parts.isEmpty && parts.allSatisfy { $0.count == 1 && jamoMarks.contains($0.first!) }
    }

    // MARK: - 문제 번호

    /// 맨 앞 문제 번호 찾기: "12." "12)" "07" "[3]" "문제 3" "Q3" "12번)" "1^1."(11이 지수로 읽힘) → (번호, 나머지 글)
    /// 소수("3.5 × 2"), 선택지("1) …"가 이어지는 것), 식("2x + 3")은 번호로 보지 않음
    static func leadingNumber(_ raw: String) -> (number: Int, rest: String)? {
        let text = raw.replacingOccurrences(of: "．", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        func take(_ pattern: String, join: Bool = false) -> (Int, String)? {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let whole = Range(m.range, in: text), let r1 = Range(m.range(at: 1), in: text) else { return nil }
            var digits = String(text[r1])
            if join, m.numberOfRanges > 2, let r2 = Range(m.range(at: 2), in: text) { digits += text[r2] }
            guard let n = Int(digits), (1...999).contains(n) else { return nil }
            let rest = String(text[whole.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard rest.count >= 2 else { return nil }
            return (n, rest)
        }
        // 이미 바꾼 모양 "12번)" · "12번."
        if let found = take(#"^(\d{1,3})\s*번\s*[).:]?\s*"#) { return found }
        // [12] 【12】 〔12〕
        if let found = take(#"^[\[【〔]\s*(\d{1,3})\s*[\]】〕]\s*"#) { return found }
        // 문제 12 · 문항 12 · Q12 · Q.12
        if let found = take(#"^(?:문제|문항|Q|q)\s*\.?\s*(\d{1,3})(?![\d,]|\.\d)\s*[.):]?\s*"#) { return found }
        // "1^1." "1^6." — 두 자리 번호의 뒷자리가 지수로 읽힘
        if let found = take(#"^(\d)\s*\^\s*(\d)\s*\.(?![\d.])\s*"#, join: true) { return found }
        // 12. (소수 3.5, 말줄임 1.. 은 제외)
        if let found = take(#"^(\d{1,3})\s?\.(?![\d.])\s*"#) { return found }
        // 07 · 012 (앞에 0을 붙인 번호)
        if let found = take(#"^(0\d{1,2})(?![\d.,:/^])\s+"#) { return found }
        // 12) — 1)~5)는 선택지일 수 있어서, 다음 줄들에 "2)" 같은 선택지가 없을 때만
        if let found = take(#"^(\d{1,3})\)\s+"#) {
            let choiceLike = text.components(separatedBy: "\n").dropFirst().contains { $0.trimmingCharacters(in: .whitespaces).range(of: #"^[2-5]\)"#, options: .regularExpression) != nil }
                || text.range(of: #"\s[2-5]\)\s"#, options: .regularExpression) != nil
            if found.0 > 5 || !choiceLike { return found }
        }
        return nil
    }

    /// 노트 제목: 번호가 있으면 "12번) " + 내용 제목 ("12번) 다음 중 옳은 것")
    static func titled(_ text: String, base: (String) -> String?) -> String? {
        guard let found = leadingNumber(text) else { return base(text) }
        let rest = base(found.rest) ?? ""
        return "\(found.number)번)" + (rest.isEmpty ? "" : " " + rest)
    }

    /// 문제 글 맨 앞 번호를 "12번) " 모양으로 (번호가 없으면 그대로)
    static func numbered(_ text: String) -> String {
        guard let found = leadingNumber(text) else { return text }
        return "\(found.number)번) " + found.rest
    }

    // MARK: - 표 · 문장 · 조건 · 질문

    static func tableCells(_ line: String) -> [String] {
        if line.contains("|") {
            return line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        let cells = line.components(separatedBy: "\t").flatMap { $0.components(separatedBy: "   ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return cells.count >= 3 && cells.allSatisfy { $0.count <= 12 } ? cells : []
    }

    static func splitSentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if ch == "?" || ch == "\n" || (ch == "." && !(current.dropLast().last?.isNumber ?? false)) {
                let s = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { result.append(s) }
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty { result.append(rest) }
        // "(단, x는 실수이다.)"처럼 마침표 뒤 닫는 괄호는 앞 문장에 붙임
        var merged: [String] = []
        for sentence in result {
            if sentence.hasPrefix(")"), let last = merged.popLast() {
                let tail = sentence.dropFirst().trimmingCharacters(in: .whitespaces)
                merged.append(last + ")")
                if !tail.isEmpty { merged.append(tail) }
            } else {
                merged.append(sentence)
            }
        }
        return merged
    }

    static func isCondition(_ sentence: String) -> Bool {
        let s = sentence.replacingOccurrences(of: " ", with: "")
        if s.hasPrefix("단,") || s.hasPrefix("(단") || s.contains("(단,") || s.contains("(단 ") { return true }
        let words = ["자연수", "정수", "실수", "양수", "음수", "유리수", "≠", "이상", "이하", "초과", "미만", "서로다른", "중근", "범위", "조건"]
        return words.contains { s.contains($0) } && !isQuestion(sentence)
    }

    static func isQuestion(_ sentence: String) -> Bool {
        let s = sentence.replacingOccurrences(of: " ", with: "")
        let endings = ["구하시오", "구하여라", "구하라", "고르시오", "고른것은", "쓰시오", "설명하시오", "서술하시오", "나타내시오", "값은", "것은", "몇개", "?", "구해보세요", "구하세요"]
        return endings.contains { s.hasSuffix($0) || s.hasSuffix($0 + ".") || s.contains($0 + "?") }
    }

    static func guessKind(body: String, choices: [String], question: String, math: Bool = true) -> ProblemKind {
        if choices.count >= 3 { return .multipleChoice }
        let q = question.replacingOccurrences(of: " ", with: "")
        if ["서술하시오", "설명하시오", "논하시오", "까닭을쓰", "이유를쓰", "과정을쓰"].contains(where: { q.contains($0) }) { return .essay }
        if math, DoitMath.looksLikeMath(body) || MathSolver.solve(body) != nil { return .math }
        return .shortAnswer
    }

    // MARK: - 수식

    static func formulas(in text: String) -> [String] {
        var found: [String] = []
        for line in text.components(separatedBy: "\n") {
            let expression = formulaRun(line)
            if expression.count >= 3, expression.contains(where: { "=+-−×÷*/^²³√<>≤≥".contains($0) }) || expression.contains("x") {
                if !found.contains(expression) { found.append(expression) }
            }
        }
        return found
    }

    /// 한 줄에서 가장 긴 수식 덩어리 (문자 i·z·a 같은 것도 포함: "z=(2+4i)(x-8i)"가 "=(2+4"로 잘리지 않게)
    static func formulaRun(_ line: String) -> String {
        let base = DoitMath.extractExpression(line)
        let allowed = Set("0123456789.+-*/^=()[]×÷−–·²³⁴⁵√<>≤≥ abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var best = "", current = ""
        for character in line + "\u{0}" {
            if allowed.contains(character) { current.append(character); continue }
            let t = current.trimmingCharacters(in: .whitespaces)
            if t.count > best.count { best = t }
            current = ""
        }
        // 낱말(영어 문장)이 아닌 수식일 때만: 연산 기호가 있고, 글자가 세 개 넘게 붙은 덩어리가 없어야 함
        let hasOperator = best.contains(where: { "=+-−×÷*/^²³√<>≤≥".contains($0) })
        let wordy = best.range(of: #"[A-Za-z]{4,}"#, options: .regularExpression) != nil
        let opens = best.filter { $0 == "(" }.count, closes = best.filter { $0 == ")" }.count
        guard hasOperator, !wordy, best.count > base.count, opens == closes || base.isEmpty else { return base }
        return best
    }

    /// 잘못 읽었을 가능성이 큰 수식
    static func suspicious(_ formula: String) -> String? {
        let opens = formula.filter { $0 == "(" }.count, closes = formula.filter { $0 == ")" }.count
        if opens != closes { return "괄호 짝이 맞지 않아요" }
        if formula.range(of: #"[+\-−×÷*/=]{2,}"#, options: .regularExpression) != nil, !formula.contains("->") { return "기호가 겹쳐 있어요" }
        if formula.range(of: #"(^|[^a-z])[lIO|](?=[0-9x+\-])"#, options: .regularExpression) != nil { return "l·I·O·| 가 숫자 1이나 0일 수 있어요" }
        if formula.hasSuffix("=") || formula.hasPrefix("=") { return "등식 한쪽이 비어 있어요" }
        if formula.range(of: #"x[0-9]{2,}"#, options: .regularExpression) != nil { return "지수(제곱)가 숫자로 읽혔을 수 있어요" }
        return nil
    }
}
