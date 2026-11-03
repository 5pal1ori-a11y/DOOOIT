import Foundation

/// 보기 항목을 하나씩 O·X로 따져 고르는 문제: "어법상 바른 것끼리 묶인 것은?", "옳은 것만을 있는 대로 고른 것은?", "틀린 것끼리"
/// - 모델은 항목마다 O·X와 짧은 이유만 쓰고, 선지 고르기는 앱이 함 (모델이 이유와 다른 번호를 고르지 않게)
/// - 항목: a) b) … · (A) (B) … · ㄱ. ㄴ. … · (가) (나) …
enum DoitItemJudge {
    struct Item: Equatable {
        let label: String
        let text: String
    }

    struct Setup: Equatable {
        let stem: String
        let items: [Item]
        /// true: 옳은·바른 것을 고름, false: 틀린·어색한 것을 고름
        let wantTrue: Bool
        /// "있는 대로" · "모두": 고를 것을 빠짐없이
        let exact: Bool
        /// 선지마다 그 선지에 든 항목 이름
        let choiceSets: [Set<String>]
    }

    // MARK: - 문제 알아보기

    static func setup(text: String, body: String?, choices: [String], boxItems: [String]?) -> Setup? {
        let source = (body?.isEmpty == false ? body! : text)
        var items = extractItems(source)
        if items.count < 2, let box = boxItems { items = box.compactMap(item(fromLine:)) }
        guard items.count >= 2, items.count <= 8 else { return nil }
        let labels = Set(items.map(\.label))
        guard Set(items.map(\.label)).count == items.count else { return nil }
        // 선지가 항목 이름 모음이어야 ("a, b" · "ㄱ, ㄷ" · "(A), (C)")
        let sets = choices.map { choiceLabels($0) }
        guard sets.count >= 2, sets.allSatisfy({ $0 != nil && !$0!.isEmpty && $0!.isSubset(of: labels) }) else { return nil }
        let stem = source.components(separatedBy: .newlines).first { line in
            item(fromLine: line) == nil && !line.trimmingCharacters(in: .whitespaces).isEmpty
        } ?? source
        guard let polarity = wantsTrue(stem) else { return nil }
        let compact = stem.replacingOccurrences(of: " ", with: "")
        let exact = compact.contains("있는대로") || compact.contains("모두")
        return Setup(stem: stem.trimmingCharacters(in: .whitespaces), items: items, wantTrue: polarity, exact: exact, choiceSets: sets.map { $0! })
    }

    /// 묻는 쪽: 옳은 것(true) · 틀린 것(false) · 모름(nil)
    static func wantsTrue(_ stem: String) -> Bool? {
        let c = stem.replacingOccurrences(of: " ", with: "")
        let negative = ["틀린", "옳지않", "바르지않", "맞지않", "어색", "적절하지않", "어긋", "일치하지않", "잘못"]
        let positive = ["바른", "옳은", "맞는", "적절한", "어법에맞", "올바른", "일치하는", "자연스러운"]
        if negative.contains(where: c.contains) { return false }
        if positive.contains(where: c.contains) { return true }
        return nil
    }

    /// 글에서 항목 줄 찾기 (한 줄에 여러 항목이 붙어 있어도)
    static func extractItems(_ text: String) -> [Item] {
        var out: [Item] = []
        for line in text.components(separatedBy: .newlines) {
            var t = line.trimmingCharacters(in: .whitespaces)
            // 선지 부분 ("① (A), (B) ② …")은 항목이 아님
            if let mark = t.firstIndex(where: { "①②③④⑤".contains($0) }) { t = String(t[..<mark]).trimmingCharacters(in: .whitespaces) }
            guard !t.isEmpty else { continue }
            // "a) … b) …"처럼 한 줄에 여러 개
            let parts = splitInline(t)
            for part in parts { if let it = item(fromLine: part) { out.append(it) } }
        }
        return out
    }

    private static let labelPattern = #"^\s*(?:\(([a-hA-H가-바])\)|([a-hA-H])[\).]|([ㄱ-ㅂ])[\.)]|\[([a-hA-H])\])\s*(.+)$"#

    static func item(fromLine line: String) -> Item? {
        guard let regex = try? NSRegularExpression(pattern: labelPattern),
              let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { return nil }
        var label: String?
        for g in 1...4 { if let r = Range(m.range(at: g), in: line) { label = String(line[r]) } }
        guard let raw = label, let r5 = Range(m.range(at: 5), in: line) else { return nil }
        let text = String(line[r5]).trimmingCharacters(in: .whitespaces)
        guard text.count >= 3 else { return nil }
        return Item(label: normalize(raw), text: text)
    }

    /// "a) I am. b) You are." → ["a) I am.", "b) You are."]
    private static func splitInline(_ line: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<=\s)(?=(?:\([a-hA-H]\)|[a-h]\)|[ㄱ-ㅂ]\.)\s)"#) else { return [line] }
        let ns = line as NSString
        var cuts = regex.matches(in: line, range: NSRange(location: 0, length: ns.length)).map(\.range.location)
        guard !cuts.isEmpty else { return [line] }
        cuts.insert(0, at: 0)
        cuts.append(ns.length)
        return zip(cuts, cuts.dropFirst()).map { ns.substring(with: NSRange(location: $0, length: $1 - $0)).trimmingCharacters(in: .whitespaces) }
    }

    /// 항목 이름 맞추기: 영어 대문자는 소문자로
    static func normalize(_ label: String) -> String { label.lowercased() }

    /// 선지 글 → 항목 이름 모음 ("a, b" → {a, b}). 이름 말고 다른 글이 있으면 nil
    static func choiceLabels(_ choice: String) -> Set<String>? {
        let t = choice.replacingOccurrences(of: #"[\s,·、/()\[\]]|및|와|과"#, with: " ", options: .regularExpression)
        let tokens = t.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }
        var set = Set<String>()
        for token in tokens {
            // "ab"처럼 붙어 있으면 한 글자씩
            if token.count > 1, token.allSatisfy({ $0.isLetter && $0.isASCII }), token.count <= 5 {
                for c in token { set.insert(String(c).lowercased()) }
                continue
            }
            guard token.count == 1, let c = token.first, (c.isASCII && c.isLetter) || "ㄱㄴㄷㄹㅁㅂ가나다라마바".contains(c) else { return nil }
            set.insert(String(c).lowercased())
        }
        return set
    }

    // MARK: - 모델에게 묻기

    /// 규칙·자료로 확실히 판단한 항목 (영어 어법 규칙, 맞춤법 표, 개념 사실표). 모델에게 고정 판단으로 알려 주고, 모델 답보다 앞서요
    static func ruleVerdicts(_ s: Setup) -> [String: (verdict: Bool, why: String)] {
        var out: [String: (verdict: Bool, why: String)] = [:]
        for item in s.items {
            if let r = DoitSubjectSolve.ruleVerdict(item, stem: s.stem) { out[item.label] = r }
        }
        return out
    }

    static func prompt(_ s: Setup, subjectName: String, fixed: [String: (verdict: Bool, why: String)] = [:]) -> String {
        var parts = ["[과목] \(subjectName)", "[문제] \(s.stem)"]
        parts.append("[항목]\n" + s.items.map { "\($0.label)) \($0.text)" }.joined(separator: "\n"))
        if !fixed.isEmpty {
            let lines = s.items.compactMap { it in fixed[it.label].map { "\(it.label)) \($0.verdict ? "O" : "X") - \($0.why)" } }
            parts.append("[규칙으로 확인한 판단] (이 항목은 이 판단을 그대로 쓰세요)\n" + lines.joined(separator: "\n"))
        }
        parts.append("각 항목을 하나씩 따져서, 문제의 기준에 맞으면 O, 맞지 않으면 X로 판단하세요. "
                     + "한 줄에 하나씩 'a) O - 짧은 이유' 모양으로만 쓰고, 선택지 번호나 정답은 쓰지 마세요. 확실하지 않으면 ?를 쓰세요.")
        return parts.joined(separator: "\n\n")
    }

    /// 모델 답 → 항목마다 O(true)·X(false). 하나라도 빠지거나 ?면 nil
    static func parseVerdicts(_ raw: String, labels: [String]) -> (verdicts: [String: Bool], reasons: [String: String])? {
        var verdicts: [String: Bool] = [:]
        var reasons: [String: String] = [:]
        let pattern = #"^\s*[\*\-•]*\s*(?:\(([a-hA-H가-바ㄱ-ㅂ])\)|([a-hA-H가-바ㄱ-ㅂ])\s*[\).:\]])\s*[:\-–]?\s*(O|X|o|x|○|×|✕|✓|✔|맞음|맞아요|맞습니다|바름|옳음|틀림|틀려요|틀립니다|어색|\?)(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for line in raw.replacingOccurrences(of: "**", with: "").components(separatedBy: .newlines) {
            guard let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { continue }
            var label = ""
            for g in 1...2 { if let r = Range(m.range(at: g), in: line) { label = normalize(String(line[r])) } }
            guard let rv = Range(m.range(at: 3), in: line) else { continue }
            let mark = String(line[rv])
            if mark == "?" { return nil }
            let isTrue = ["O", "o", "○", "✓", "✔", "맞음", "맞아요", "맞습니다", "바름", "옳음"].contains(mark)
            verdicts[label] = isTrue
            if let rr = Range(m.range(at: 4), in: line) {
                reasons[label] = String(line[rr]).trimmingCharacters(in: CharacterSet(charactersIn: " -–:·."))
            }
        }
        guard labels.allSatisfy({ verdicts[$0] != nil }) else { return nil }
        return (verdicts, reasons)
    }

    /// O·X로 선지 고르기: 고를 것만 든 선지가 하나면 그것 ("있는 대로"면 빠짐없이 같은 것). 하나로 안 정해지면 nil
    static func pickChoice(_ s: Setup, verdicts: [String: Bool]) -> Int? {
        let wanted = Set(s.items.map(\.label).filter { verdicts[$0] == s.wantTrue })
        let exact = s.choiceSets.indices.filter { s.choiceSets[$0] == wanted }
        if s.exact { return exact.count == 1 ? exact[0] : nil }
        let onlyWanted = s.choiceSets.indices.filter { s.choiceSets[$0].isSubset(of: wanted) }
        if onlyWanted.count == 1 { return onlyWanted[0] }
        return exact.count == 1 ? exact[0] : nil
    }

    /// 화면에 보여 줄 풀이 (AI 추측)
    static func solution(_ s: Setup, verdicts: [String: Bool], reasons: [String: String], choice: Int, problem: String) -> WrittenSolution {
        let steps = s.items.map { it in
            SolutionStep(hint: "", work: "\(it.label)) \(verdicts[it.label] == true ? "O" : "X")" + ((reasons[it.label] ?? "").isEmpty ? "" : " · \(reasons[it.label]!)"))
        }
        var solution = WrittenSolution(concept: s.wantTrue ? "항목을 하나씩 따져 맞는 것만 골라요" : "항목을 하나씩 따져 틀린 것만 골라요",
                                       steps: steps, finalAnswer: "\(choice + 1)")
        solution.source = DoitAutoSolve.modelSource
        solution.problem = problem.trimmingCharacters(in: .whitespacesAndNewlines)
        return solution
    }

    /// 두 번 물어 같은 판단일 때만 씀 (작은 모델은 같은 문제에도 답이 흔들려서)
    static func agree(_ a: [String: Bool], _ b: [String: Bool]) -> Bool { a == b }

    /// 모델로 항목 판단: 두 번 물어 판단이 같고 선지가 하나로 정해질 때만 풀이 (아니면 nil — 틀린 답을 보여 주지 않게)
    @MainActor
    static func run(_ s: Setup, subjectName: String, problem: String) async -> WrittenSolution? {
        let labels = s.items.map(\.label)
        let fixed = ruleVerdicts(s)
        let text = prompt(s, subjectName: subjectName, fixed: fixed)
        var first: (verdicts: [String: Bool], reasons: [String: String])?
        for temperature: Float in [0.1, 0.6] {
            guard let raw = try? await DoitBrain.shared.complete(system: DoitMind.persona, prompt: text, maxTokens: 500, temperature: temperature),
                  var parsed = parseVerdicts(DoitMind.answer(raw), labels: labels) else { return nil }
            // 규칙으로 확실한 항목은 규칙 판단으로 (모델이 다르게 써도)
            for (label, rule) in fixed { parsed.verdicts[label] = rule.verdict; parsed.reasons[label] = rule.why }
            if let first {
                guard agree(first.verdicts, parsed.verdicts) else { return nil }
            } else {
                first = parsed
            }
        }
        guard let result = first, let choice = pickChoice(s, verdicts: result.verdicts) else { return nil }
        return solution(s, verdicts: result.verdicts, reasons: result.reasons, choice: choice, problem: problem)
    }
}
