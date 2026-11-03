import Foundation

// MARK: - 영어 어법 문제 풀기 (밑줄 지문 · 네모 고르기 · 틀린 곳 고치기 · 빈칸 대입 · 개수 · 문장 전환)
// - 모두 DoitSentenceCheck의 "확실히 틀린 곳"만 근거로 써요. 시험은 정답이 하나라서,
//   나머지가 모두 확실히 틀렸을 때만 남은 것을 고르고, 틀린 것이 하나만 확실할 때만 그것을 골라요.
// - 지문에서 밑줄이 아닌 곳이 틀렸다고 나오면 규칙이 잘못 걸린 것이라 보고 풀지 않아요.

extension DoitSubjectSolve {
    // MARK: 공통: 영어 지문과 표시(①~⑤ · (A)~(C))

    /// 한글 지시문 줄을 뺀 영어 지문
    static func englishPassage(_ text: String) -> String {
        var lines: [String] = []
        for raw in text.components(separatedBy: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            // 줄 앞의 한글 지시문 ("다음 글의 밑줄 친 … 것은? Many people …")
            if let q = line.lastIndex(where: { $0 == "?" || $0 == "？" }), line[..<q].contains(where: { DoitSubjectNote.isHangul($0) }) {
                line = String(line[line.index(after: q)...]).trimmingCharacters(in: .whitespaces)
            }
            if line.contains(where: { DoitSubjectNote.isHangul($0) }) { continue }
            if line.range(of: #"^\s*([0-9]+\s*[번.)]\s*)?$"#, options: .regularExpression) != nil { continue }
            lines.append(line)
        }
        return lines.joined(separator: " ").replacingOccurrences(of: "  ", with: " ")
    }

    /// 문장 나누기 (. ! ? 뒤 띄어쓰기)
    static func splitEnglishSentences(in passage: String) -> [String] {
        var out: [String] = []
        var current = ""
        let chars = Array(passage)
        for (k, ch) in chars.enumerated() {
            current.append(ch)
            if ".!?".contains(ch), k + 1 >= chars.count || chars[k + 1] == " " {
                // Mr. · Dr. · a.m. 같은 줄임말은 끊지 않음
                let tail = current.split(separator: " ").last.map(String.init) ?? ""
                if ["Mr.", "Mrs.", "Ms.", "Dr.", "St.", "a.m.", "p.m.", "e.g.", "i.e.", "etc."].contains(tail) { continue }
                out.append(current.trimmingCharacters(in: .whitespaces)); current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { out.append(rest) }
        return out
    }

    /// 표시 자리: 문장 번호, 그 문장 속 낱말 번호
    struct Mark {
        let label: Int
        let sentence: Int
        let word: Int
        /// 표시 바로 뒤 낱말
        let text: String
    }

    /// 지문에서 ①~⑤ 표시를 떼고, 표시마다 자리를 기억
    static func underlineMarks(_ passage: String) -> (sentences: [String], marks: [Mark])? {
        let circledMarks: [Character: Int] = ["①": 1, "②": 2, "③": 3, "④": 4, "⑤": 5]
        guard passage.filter({ circledMarks[$0] != nil }).count >= 4 else { return nil }
        // 표시 앞뒤 띄어쓰기를 맞춤 ("①to go" → "① to go")
        var text = ""
        for ch in passage {
            if circledMarks[ch] != nil { text += " \(ch) " } else { text.append(ch) }
        }
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        // 표시를 뺀 문장과 표시 자리
        let rawSentences = splitEnglishSentences(in: text)
        var sentences: [String] = []
        var marks: [Mark] = []
        for raw in rawSentences {
            var clean: [String] = []
            var pending: [Int] = []
            for piece in raw.split(separator: " ").map(String.init) {
                if piece.count == 1, let n = circledMarks[piece.first!] { pending.append(n); continue }
                let core = piece.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"“”()"))
                if !core.isEmpty {
                    let index = DoitSentenceCheck.words(clean.joined(separator: " ")).w.count
                    for n in pending { marks.append(Mark(label: n, sentence: sentences.count, word: index, text: core)) }
                    pending = []
                }
                clean.append(piece)
            }
            sentences.append(clean.joined(separator: " "))
        }
        let labels = marks.map(\.label)
        guard labels == Array(1...labels.count), labels.count >= 4 else { return nil }
        return (sentences, marks)
    }

    // MARK: 밑줄 친 부분 중 어법상 틀린 것 (지문 속 ①~⑤)

    static func englishUnderlinedPassage(_ p: Problem) -> Found? {
        let c = p.full.filter { !$0.isWhitespace }
        guard c.contains("어법") || c.contains("grammatically"), c.contains("밑줄") || c.contains("underlined") else { return nil }
        if matches(c, #"(개수|몇개)"#) { return nil }
        let wantWrong = matches(c, #"(틀린|어색한|적절하지않은|옳지않은|바르지않은|맞지않는|incorrect|wrong)"#)
        guard let parsed = underlineMarks(englishPassage(p.full)) else { return nil }
        var flagged: [Int: DoitSentenceCheck.Issue] = [:]
        for (s, sentence) in parsed.sentences.enumerated() {
            let issues = DoitSentenceCheck.errors(in: sentence)
            let marks = parsed.marks.filter { $0.sentence == s }.sorted { $0.word < $1.word }
            for issue in issues {
                guard let at = issue.at else { return nil }   // 자리를 모르는 오류는 어느 밑줄인지 몰라요
                // 밑줄은 표시 바로 뒤부터 몇 낱말 (다음 표시 전까지, 길어야 4낱말)
                let owner = marks.last { m in m.word <= at && at <= m.word + 3 && !(marks.contains { $0.word > m.word && $0.word <= at }) }
                guard let owner else { return nil }   // 밑줄이 아닌 곳이 틀렸다고 나오면 믿지 않음
                flagged[owner.label] = issue
            }
        }
        let steps = parsed.marks.map { m -> SolutionStep in
            if let issue = flagged[m.label] { return SolutionStep(hint: issue.rule, work: "\(circled(m.label)) \(m.text) … → \(issue.why)") }
            return SolutionStep(hint: "", work: "\(circled(m.label)) \(m.text) … → 규칙으로 틀린 곳을 찾지 못했어요")
        }
        if wantWrong {
            guard flagged.count == 1, let (label, issue) = flagged.first else { return nil }
            var all = steps
            if let fix = issue.fix, !fix.isEmpty { all.append(SolutionStep(hint: "고치기", work: "→ \(fix)")) }
            all.append(SolutionStep(hint: "정답", work: circled(label)))
            return Found(answer: "\(label)", concept: "어법: " + issue.rule, steps: all)
        }
        // 옳은 것 하나: 나머지가 모두 확실히 틀렸을 때
        let labels = Set(parsed.marks.map(\.label))
        let rest = labels.subtracting(flagged.keys)
        guard rest.count == 1, let good = rest.first else { return nil }
        return Found(answer: "\(good)", concept: "어법 (나머지는 모두 틀린 곳이 있어요)", steps: steps + [SolutionStep(hint: "정답", work: circled(good))])
    }

    // MARK: (A), (B), (C) 네모 안에서 어법에 맞는 표현

    struct Box {
        let label: String
        let options: [String]
        /// 네모 자리에 ___를 넣은 문장
        let sentence: String
    }

    static func boxes(in passage: String) -> [Box] {
        // "(A) [is / are]" · "[(A) is / are]" · "(A)[is/are]"
        let pattern = #"(?:\(([A-C])\)\s*[\[［]\s*([^\]］]+?)\s*[\]］])|(?:[\[［]\s*\(([A-C])\)\s*([^\]］]+?)\s*[\]］])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = passage as NSString
        let found = regex.matches(in: passage, range: NSRange(location: 0, length: ns.length))
        guard !found.isEmpty else { return [] }
        // 네모를 ___로 바꾼 지문 (네모마다 따로)
        var result: [Box] = []
        for (k, m) in found.enumerated() {
            let labelRange = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 3)
            let optRange = m.range(at: 2).location != NSNotFound ? m.range(at: 2) : m.range(at: 4)
            let label = ns.substring(with: labelRange)
            let options = ns.substring(with: optRange).components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard options.count >= 2 else { continue }
            // 다른 네모는 첫 번째 선택지로 채움 (그 네모가 든 문장만 봄)
            var text = ""
            var last = 0
            for (j, other) in found.enumerated() {
                text += ns.substring(with: NSRange(location: last, length: other.range.location - last))
                if j == k { text += " ___ " } else {
                    let r = other.range(at: 2).location != NSNotFound ? other.range(at: 2) : other.range(at: 4)
                    text += ns.substring(with: r).components(separatedBy: "/").first?.trimmingCharacters(in: .whitespaces) ?? ""
                }
                last = other.range.location + other.range.length
            }
            text += ns.substring(from: last)
            text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            guard let sentence = splitEnglishSentences(in: text).first(where: { $0.contains("___") }) else { continue }
            result.append(Box(label: label, options: options, sentence: sentence))
        }
        return result
    }

    /// ___ 자리에 넣었을 때 확실히 틀리는지 (그 자리 근처의 오류만)
    static func wrongInBlank(_ sentence: String, option: String) -> DoitSentenceCheck.Issue? {
        let parts = sentence.components(separatedBy: "___")
        guard parts.count == 2 else { return nil }
        let filled = (parts[0] + option + parts[1]).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        let start = DoitSentenceCheck.words(parts[0]).w.count
        let length = max(1, DoitSentenceCheck.words(option).w.count)
        let issues = DoitSentenceCheck.errors(in: filled)
        return issues.first { issue in
            guard let at = issue.at else { return false }
            return at >= start - 2 && at <= start + length + 1 || (at <= start && at + issue.length > start)
        }
    }

    /// 문장 전체에 확실한 오류가 하나라도 있는지 (자리 상관없이)
    static func anyError(_ sentence: String, option: String) -> Bool {
        let parts = sentence.components(separatedBy: "___")
        guard parts.count == 2 else { return false }
        let filled = (parts[0] + option + parts[1]).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        return DoitSentenceCheck.error(in: filled) != nil
    }

    /// 한 자리의 선택지들 중 나머지가 모두 확실히 틀려서 남는 하나 (근거 함께)
    static func solveSlot(_ sentence: String, options: [String]) -> (index: Int, why: String)? {
        var verdicts: [DoitSentenceCheck.Issue?] = []
        for o in options { verdicts.append(wrongInBlank(sentence, option: o)) }
        let ok = options.indices.filter { verdicts[$0] == nil }
        guard ok.count == 1, let good = ok.first else { return nil }
        // 남은 선택지를 넣은 문장에 다른 오류가 있으면 규칙이 지문과 안 맞는 것이라 믿지 않음
        if anyError(sentence, option: options[good]) { return nil }
        let why = options.indices.filter { $0 != good }.map { "\(options[$0]) ✗ (\(verdicts[$0]?.rule ?? ""))" }.joined(separator: ", ")
        return (good, why)
    }

    static func englishBoxes(_ p: Problem) -> Found? {
        guard p.isChoice else { return nil }
        let passage = englishPassage(p.full)
        let list = boxes(in: passage)
        guard list.count >= 2 else { return nil }
        // 선지: "is - which - to go" · "is … which … to go"
        let split = p.choices.map { $0.components(separatedBy: CharacterSet(charactersIn: "-–…·,")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        guard split.allSatisfy({ $0.count == list.count }) else { return nil }
        var solved: [Int: String] = [:]
        var steps: [SolutionStep] = []
        for (slot, box) in list.enumerated() {
            guard let r = solveSlot(box.sentence, options: box.options) else { continue }
            solved[slot] = box.options[r.index]
            steps.append(SolutionStep(hint: "(\(box.label))", work: box.sentence.replacingOccurrences(of: "___", with: "[\(box.options[r.index])]") + " · " + r.why))
        }
        guard !solved.isEmpty else { return nil }
        let hits = split.indices.filter { i in solved.allSatisfy { split[i][$0.key].lowercased() == $0.value.lowercased() } }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: "네모 안 어법 (틀린 쪽을 지워요)", steps: steps)
    }

    // MARK: 어법상 틀린(옳은) 것의 개수

    static func englishCount(_ p: Problem) -> Found? {
        let c = p.compact
        guard p.isChoice, c.contains("어법"), matches(c, #"(개수|몇개)"#) else { return nil }
        var items = p.box.map { $0.replacingOccurrences(of: #"^\s*([a-eㄱ-ㅁA-E]|\([a-eA-E]\))[.)]?\s*"#, with: "", options: .regularExpression) }
        if items.isEmpty {
            items = p.stem.components(separatedBy: "\n").compactMap { line -> String? in
                guard let r = line.range(of: #"^\s*(\(?[a-eA-E]\)|[a-e]\.|[ㄱ-ㅁ][.)])\s*"#, options: .regularExpression) else { return nil }
                return String(line[r.upperBound...])
            }
        }
        guard items.count >= 3, items.allSatisfy(DoitSentenceCheck.isEnglishSentence) else { return nil }
        let wrong = items.filter { DoitSentenceCheck.error(in: $0) != nil }.count
        let wantWrong = matches(c, #"(틀린|어색한|옳지않은|바르지않은)"#)
        // 맞는지 확인할 방법이 없어서, 모두 틀렸을 때만 개수가 정해져요
        guard wrong == items.count else { return nil }
        let answer = wantWrong ? items.count : 0
        let steps = items.map { SolutionStep(hint: "", work: "\($0) → \(DoitSentenceCheck.error(in: $0)?.why ?? "")") }
        guard let index = p.choices.firstIndex(where: { key($0) == "\(answer)개" || key($0) == "\(answer)" || ($0.contains("없") && answer == 0) }) else { return nil }
        return pick(p, index: index, concept: "어법 (모든 문장에 틀린 곳이 있어요)", steps: steps)
    }

    // MARK: 틀린 부분을 찾아 바르게 고치기 (서술형)

    static func englishFixError(_ p: Problem) -> Found? {
        let c = p.compact
        guard !p.isChoice, matches(c, #"(고치|고쳐|바르게쓰|correct)"#), c.contains("틀린") || c.contains("어색") || c.contains("어법") || c.contains("잘못") else { return nil }
        let passage = englishPassage(p.full)
        let sentences = splitEnglishSentences(in: passage).filter(DoitSentenceCheck.isEnglishSentence)
        guard !sentences.isEmpty, sentences.count <= 6 else { return nil }
        var found: [(String, DoitSentenceCheck.Issue)] = []
        for s in sentences { for issue in DoitSentenceCheck.errors(in: s) { found.append((s, issue)) } }
        guard found.count == 1, let (sentence, issue) = found.first, let at = issue.at, let fix = issue.fix else { return nil }
        let ws = DoitSentenceCheck.words(sentence)
        let wrong = ws.raw[at..<min(ws.raw.count, at + issue.length)].joined(separator: " ")
        let answer = fix.isEmpty ? "\(wrong) → 삭제" : "\(wrong) → \(fix)"
        var steps = [SolutionStep(hint: issue.rule, work: issue.why)]
        if let fixed = DoitEnglishGrammar.apply(fix, at: at, length: issue.length, to: sentence) { steps.append(SolutionStep(hint: "고친 문장", work: fixed)) }
        return Found(answer: answer, concept: "어법: " + issue.rule, steps: steps)
    }

    // MARK: 빈칸에 넣어 보기 (선지를 하나씩 대입)

    static func englishBlankSubstitute(_ p: Problem) -> Found? {
        guard p.isChoice, p.choices.allSatisfy({ $0.allSatisfy(\.isASCII) && !$0.isEmpty }), p.choices.count >= 3 else { return nil }
        let c = p.compact
        guard !matches(c, #"(뜻|의미|해석|흐름|문맥|내용|요지|주제|제목)"#) else { return nil }
        let pattern = #"_{2,}|＿+|\(\s{2,}\)|\[\s+\]"#
        let lines = p.stem.components(separatedBy: "\n").filter { $0.range(of: pattern, options: .regularExpression) != nil }
        guard lines.count == 1, var line = lines.first else { return nil }
        if let q = line.lastIndex(where: { $0 == "?" || $0 == "？" }), line[..<q].contains(where: { DoitSubjectNote.isHangul($0) }) {
            line = String(line[line.index(after: q)...])
        }
        guard !line.contains(where: { DoitSubjectNote.isHangul($0) }) else { return nil }
        let sentence = line.replacingOccurrences(of: pattern, with: "___", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        guard sentence.components(separatedBy: "___").count == 2 else { return nil }
        let options = p.choices.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " .")) }
        guard let r = solveSlot(sentence, options: options) else { return nil }
        return pick(p, index: r.index, concept: "빈칸에 하나씩 넣어 보기", steps: [SolutionStep(hint: "", work: r.why),
                                                                         SolutionStep(hint: "", work: sentence.replacingOccurrences(of: "___", with: "[\(options[r.index])]"))])
    }

    // MARK: 문장 전환 (능동태 → 수동태, so ~ that ↔ too ~ to / enough to, It seems that ↔ seem to, 가정법 ↔ 직설법)

    static func englishTransform(_ p: Problem) -> Found? {
        let c = p.compact
        guard matches(c, #"(수동태|바꿔|바꾸어|바꿀|같은뜻|같도록|전환|의미가같|뜻이같)"#) else { return nil }
        let englishLines = p.full.components(separatedBy: "\n").map { line -> String in
            var l = line.trimmingCharacters(in: .whitespaces)
            if let q = l.lastIndex(where: { $0 == "?" || $0 == "？" || $0 == "." }), l[..<q].contains(where: { DoitSubjectNote.isHangul($0) }) { l = String(l[l.index(after: q)...]) }
            return l.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty && !$0.contains(where: { DoitSubjectNote.isHangul($0) }) && $0.range(of: #"^[①②③④⑤]"#, options: .regularExpression) == nil }
        // "A. = B ___" 또는 "A. → B ___" 한 줄, 또는 두 줄
        var source: String?
        var template: String?
        let joined = englishLines.joined(separator: " ")
        if let r = joined.range(of: #"\s*(=|→|->|⇒)\s*"#, options: .regularExpression) {
            source = String(joined[..<r.lowerBound]); template = String(joined[r.upperBound...])
        } else if englishLines.count == 2 {
            source = englishLines[0]; template = englishLines[1]
        } else if englishLines.count == 1 {
            source = englishLines[0]
        }
        guard let src = source?.trimmingCharacters(in: .whitespaces), !src.isEmpty else { return nil }
        let wantPassive = c.contains("수동태")
        var targets: [(String, String)] = []   // (바꾼 문장, 개념)
        if wantPassive || template?.contains(" by ") == true { if let t = DoitEnglishTransform.passive(src) { targets += t.map { ($0, "능동태 → 수동태") } } }
        if let t = DoitEnglishTransform.soThatToToo(src) { targets.append((t, "so ~ that ↔ too ~ to / enough to")) }
        if let t = DoitEnglishTransform.seemTo(src) { targets.append((t, "It seems that ↔ seem to")) }
        if let t = DoitEnglishTransform.subjunctive(src) { targets += t.map { ($0, "직설법 → 가정법") } }
        guard !targets.isEmpty else { return nil }
        func norm(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " }.split(separator: " ").joined(separator: " ") }
        // 선지에서 고르기
        if p.isChoice {
            let hits = p.choices.indices.filter { i in targets.contains { norm($0.0) == norm(p.choices[i]) } }
            guard hits.count == 1, let t = targets.first(where: { norm($0.0) == norm(p.choices[hits[0]]) }) else { return nil }
            return pick(p, index: hits[0], concept: t.1, steps: [SolutionStep(hint: t.1, work: "\(src) → \(t.0)")])
        }
        // 빈칸 채우기: 틀의 앞뒤를 맞춰 빈칸 자리의 말만
        if let tmpl = template, tmpl.range(of: #"_{2,}|＿+"#, options: .regularExpression) != nil {
            let pieces = tmpl.replacingOccurrences(of: #"(\s*(_{2,}|＿+)\s*)+"#, with: " ___ ", options: .regularExpression).components(separatedBy: "___")
            var answers: Set<String> = []
            var concept = ""
            for t in targets {
                if let fill = fillTemplate(pieces, target: t.0) { answers.insert(fill); concept = t.1 }
            }
            guard answers.count == 1, let a = answers.first else { return nil }
            return Found(answer: a, concept: concept, steps: [SolutionStep(hint: concept, work: "\(src) → \(targets.first { fillTemplate(pieces, target: $0.0) == a }?.0 ?? a)")])
        }
        // 그대로 바꿔 쓰기
        guard template == nil, targets.count == 1 || Set(targets.map { norm($0.0) }).count == 1, let t = targets.first else { return nil }
        return Found(answer: t.0, concept: t.1, steps: [SolutionStep(hint: t.1, work: "\(src) → \(t.0)")])
    }

    /// 틀 ["The window ", " by Tom."]에 맞춰 target에서 빈칸 자리 말을 뽑기
    static func fillTemplate(_ pieces: [String], target: String) -> String? {
        func toks(_ s: String) -> [String] { DoitSentenceCheck.words(s).w }
        let t = toks(target)
        var pos = 0
        var fills: [String] = []
        for (k, piece) in pieces.enumerated() {
            let pt = toks(piece)
            if k == 0 {
                guard Array(t.prefix(pt.count)) == pt else { return nil }
                pos = pt.count
                continue
            }
            // 다음 조각이 시작하는 곳을 찾기 (마지막 조각이면 끝에 맞춤)
            var found: Int?
            if k == pieces.count - 1 {
                let start = t.count - pt.count
                if start >= pos, Array(t[start...]) == pt { found = start }
            } else if pt.isEmpty { found = nil } else {
                for s in pos...max(pos, t.count - pt.count) where s + pt.count <= t.count && Array(t[s..<(s + pt.count)]) == pt { found = s; break }
            }
            guard let f = found, f > pos else { return nil }
            fills.append(t[pos..<f].joined(separator: " "))
            pos = f + pt.count
        }
        guard pos == t.count, !fills.isEmpty else { return nil }
        return fills.joined(separator: " / ")
    }
}

// MARK: - 문장 전환 규칙 (정해진 틀일 때만)

enum DoitEnglishTransform {
    typealias SC = DoitSentenceCheck

    static func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    /// 주어 · 목적어 대명사 바꾸기
    static func asObject(_ w: String) -> String { ["i": "me", "he": "him", "she": "her", "we": "us", "they": "them"][w.lowercased()] ?? w }
    static func asSubject(_ w: String) -> String { ["me": "I", "him": "he", "her": "she", "us": "we", "them": "they"][w.lowercased()] ?? w }

    /// 능동태 → 수동태 ("Tom broke the window yesterday." → "The window was broken by Tom yesterday.")
    /// - 주어(대명사·이름·명사구) + 동사(현재·과거·will·조동사·현재완료) + 목적어(대명사·명사구) + (뒤 부사구)
    static func passive(_ sentence: String) -> [String]? {
        let ws = SC.words(sentence)
        guard ws.w.count >= 3, !ws.question else { return nil }
        // 주어
        var i = 0
        let subjRaw: String
        if SC.subjectPronouns.contains(ws.w[0]) { subjRaw = ws.w[0] == "i" ? "I" : ws.w[0]; i = 1 }
        else if SC.looksLikeName(ws, 0) { subjRaw = ws.raw[0]; i = 1 }
        else if let np = SC.nounPhrase(ws, at: 0) { subjRaw = ws.raw[0..<np.end].joined(separator: " ").lowercased(); i = np.end }
        else { return nil }
        // 동사
        var tense = ""
        var modal = ""
        var verb = ""
        let w = ws.at(i)
        if SC.modals.contains(w) { modal = w; verb = ws.at(i + 1); tense = "modal"; i += 2 }
        else if ["have", "has"].contains(w), SC.isPresentPerfect(ws, at: i) { verb = ws.at(i + 1); tense = "perfect"; i += 2 }
        else if let b = DoitEnglish.verbBase(w), b != "be", b != "have" {
            if SC.isThirdForm(w) { tense = "present" } else if w == b { tense = SC.sameBasePast.contains(w) ? "" : "present" }
            else if DoitEnglish.pastForms(b).contains(w) { tense = "past" }
            verb = w; i += 1
        }
        guard !tense.isEmpty, let base = DoitEnglish.verbBase(verb), let pp = DoitEnglish.ppForms(base).first, base != "be" else { return nil }
        let transitive: Set<String> = ["build", "write", "make", "break", "speak", "teach", "sing", "steal", "eat", "give", "take", "catch", "draw",
                                       "grow", "see", "choose", "drive", "throw", "sell", "buy", "send", "bring", "find", "invent", "discover",
                                       "paint", "design", "invite", "visit", "wash", "fix", "plant", "use", "clean", "love", "respect", "create",
                                       "cook", "bake", "read", "play", "watch", "open", "close", "solve", "answer", "help", "call", "kick", "hit",
                                       "carry", "deliver", "repair", "destroy", "plan", "write", "hold", "keep", "like", "visit", "translate"]
        guard transitive.contains(base) else { return nil }
        // 목적어
        let objRaw: String
        let objPlural: Bool
        var j = i
        if let s = SC.subjectCase[ws.at(j)] { objRaw = s; objPlural = ["we", "they"].contains(s); j += 1 }
        else if ws.at(j) == "it" { objRaw = "it"; objPlural = false; j += 1 }
        else if ws.at(j) == "you" { objRaw = "you"; objPlural = true; j += 1 }
        else if SC.looksLikeName(ws, j) { objRaw = ws.raw[j]; objPlural = false; j += 1 }
        else if let np = SC.nounPhrase(ws, at: j), let pl = np.plural { objRaw = ws.raw[j..<np.end].joined(separator: " "); objPlural = pl; j = np.end }
        else { return nil }
        // 4형식(목적어 둘)은 다루지 않음
        if j < ws.w.count, SC.nounPhrase(ws, at: j) != nil { return nil }
        let rest = ws.raw[j...].joined(separator: " ")
        let firstPerson = objRaw.lowercased() == "i"
        let be: String
        switch tense {
        case "present": be = firstPerson ? "am" : objPlural ? "are" : "is"
        case "past": be = firstPerson || !objPlural ? "was" : "were"
        case "perfect": be = !objPlural && !firstPerson && objRaw.lowercased() != "you" ? "has been" : "have been"
        default: be = modal + " be"
        }
        let agent = SC.subjectPronouns.contains(subjRaw.lowercased()) ? asObject(subjRaw) : subjRaw
        let head = cap(objRaw)
        let end = sentence.trimmingCharacters(in: .whitespaces).last.map { ".!".contains($0) ? String($0) : "." } ?? "."
        let a = "\(head) \(be) \(pp) by \(agent)" + (rest.isEmpty ? "" : " " + rest) + end
        var out = [a]
        if !rest.isEmpty { out.append("\(head) \(be) \(pp) \(rest) by \(agent)" + end) }
        return out
    }

    /// so ~ that 주어 can't ↔ too ~ to · so ~ that 주어 can ↔ enough to
    static func soThatToToo(_ sentence: String) -> String? {
        let ws = SC.words(sentence)
        guard let so = ws.w.firstIndex(of: "so"), so >= 2, ws.at(so + 2) == "that" else { return nil }
        let adj = ws.raw[so + 1]
        let start = so + 3
        guard SC.subjectPronouns.contains(ws.at(start)) else { return nil }
        let m = ws.at(start + 1)
        let head = ws.raw[0..<so].joined(separator: " ")
        var restStart = start + 2
        var negative = false
        if ["can't", "couldn't", "cannot"].contains(m) { negative = true }
        else if ["can", "could"].contains(m), ws.at(start + 2) == "not" { negative = true; restStart += 1 }
        else if !["can", "could"].contains(m) { return nil }
        var rest = Array(ws.raw[restStart...])
        // 주절 주어와 같은 목적어는 to부정사에서 빠짐 (The box is so heavy that I can't lift it → too heavy for me to lift)
        let subj = ws.at(0)
        let thatSubj = ws.at(start)
        if let last = rest.last?.lowercased(), ["it", "them"].contains(last), !SC.subjectPronouns.contains(subj) || subj == "it" { rest.removeLast() }
        let forPart = thatSubj == subj || (SC.subjectPronouns.contains(subj) && thatSubj == subj) ? "" : "for \(asObject(thatSubj)) "
        guard !rest.isEmpty else { return nil }
        if negative { return "\(head) too \(adj) \(forPart)to \(rest.joined(separator: " "))." }
        return "\(head) \(adj) enough \(forPart)to \(rest.joined(separator: " "))."
    }

    /// It seems that 주어 + 동사 → 주어 seems to + 원형
    static func seemTo(_ sentence: String) -> String? {
        let ws = SC.words(sentence)
        guard ws.at(0) == "it", ["seems", "seemed", "appears", "appeared"].contains(ws.at(1)), ws.at(2) == "that" else { return nil }
        let s = ws.raw[3], v = ws.at(4)
        guard SC.subjectPronouns.contains(ws.at(3)) || SC.looksLikeName(ws, 3) else { return nil }
        let seem = ws.at(1)
        let pastMain = seem.hasSuffix("ed")
        let thirdS = ["he", "she", "it"].contains(ws.at(3)) || SC.looksLikeName(ws, 3)
        let seemForm = pastMain ? seem : (thirdS ? seem : String(seem.dropLast()))
        guard let base = DoitEnglish.verbBase(v) else { return nil }
        let rest = ws.raw[5...].joined(separator: " ")
        let pastClause = DoitEnglish.pastForms(base).contains(v) && v != base || ["was", "were"].contains(v)
        let inf: String
        if pastClause, !pastMain { inf = "to have \(DoitEnglish.ppForms(base).first ?? v)" }
        else { inf = "to \(base)" }
        return "\(cap(s)) \(seemForm) \(inf)" + (rest.isEmpty ? "" : " " + rest) + "."
    }

    /// 직설법 → 가정법 ("As I am not rich, I can't buy it." → "If I were rich, I could buy it." / "I'm sorry I can't swim." → "I wish I could swim.")
    static func subjunctive(_ sentence: String) -> [String]? {
        let ws = SC.words(sentence)
        // I'm sorry (that) I + 부정
        if ws.at(0) == "i'm" || ws.at(0) == "i" && ws.at(1) == "am", ws.w.contains("sorry") {
            var k = ws.w.firstIndex(of: "sorry")! + 1
            if ws.at(k) == "that" { k += 1 }
            guard ws.at(k) == "i" else { return nil }
            let v = ws.at(k + 1)
            let rest = ws.raw[(k + 2)...]
            if ["can't", "cannot"].contains(v) { return ["I wish I could \(rest.joined(separator: " "))."] }
            if v == "am", ws.at(k + 2) == "not" { return ["I wish I were \(ws.raw[(k + 3)...].joined(separator: " "))."] }
            if v == "don't", ws.at(k + 2) == "have" { return ["I wish I had \(ws.raw[(k + 3)...].joined(separator: " "))."] }
            return nil
        }
        // As/Because/Since + 주어 + 부정 …, 주어 + can't/won't …
        guard ["as", "because", "since"].contains(ws.at(0)), let cut = ws.comma.firstIndex(of: true), cut >= 3 else { return nil }
        let s1 = ws.at(1)
        guard SC.subjectPronouns.contains(s1) else { return nil }
        var clause: String
        let v1 = ws.at(2)
        if ["am", "is", "are"].contains(v1), ws.at(3) == "not" { clause = "were " + ws.raw[4...cut].joined(separator: " ") }
        else if ["isn't", "aren't"].contains(v1) { clause = "were " + ws.raw[3...cut].joined(separator: " ") }
        else if ["don't", "doesn't"].contains(v1), ws.at(3) == "have" { clause = "had " + ws.raw[4...cut].joined(separator: " ") }
        else if ["don't", "doesn't"].contains(v1), let b = DoitEnglish.verbBase(ws.at(3)), b == ws.at(3) { clause = (DoitEnglish.pastForms(b).first ?? b) + " " + ws.raw[4...cut].joined(separator: " ") }
        else { return nil }
        let s2 = ws.at(cut + 1)
        guard SC.subjectPronouns.contains(s2) else { return nil }
        let m = ws.at(cut + 2)
        let mainModal: String
        var restStart = cut + 3
        switch m {
        case "can't", "cannot": mainModal = "could"
        case "won't": mainModal = "would"
        case "can": if ws.at(cut + 3) == "not" { mainModal = "could"; restStart += 1 } else { return nil }
        default: return nil
        }
        let rest = ws.raw[restStart...].joined(separator: " ")
        let subj1 = s1 == "i" ? "I" : s1
        let subj2 = s2 == "i" ? "I" : s2
        return ["If \(subj1) \(clause), \(subj2) \(mainModal) \(rest)."]
    }
}
