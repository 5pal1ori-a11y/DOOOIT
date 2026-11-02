import Foundation

// 두잇 AI 문제 유형 사전: 학교 시험·수능에 나오는 문제 "유형"을 알아보고, 무엇을 묻는지·어떻게 풀면 되는지 짧게 알려 줘요.
// 데이터는 과목별 파일(ProblemTypes*.swift)에 글로 적어 두고 처음 쓸 때 한 번만 읽어요 (컴파일이 빠르도록).
//
// 글 형식 (한 줄에 하나, " | "로 칸 나눔, "//"로 시작하면 주석)
//   직접 적은 유형: id | 세부 과목 | 이름 | 지시문 패턴 ; 패턴 | 묻는 것 | 푸는 법 / 푸는 법 | 함정 / 함정 [| 주제 낱말, 낱말]
//   묻는 형식(form): id | 이름 | 지시문 패턴 ; 패턴 | 묻는 것({T}=주제) | 푸는 법 / … | 함정 / …
//   주제(topic):     key | 세부 과목 | 이름 | 주제 낱말, 낱말 | 주제 요령 | 주제 함정 | 쓸 형식 id, id (* = 모두)
// 지시문 패턴은 띄어쓰기를 모두 없앤 소문자 글에 맞추는 정규식이에요 (사진 글자 인식의 띄어쓰기 실수에 강하도록).

/// 문제 유형 하나
struct ProblemType: Identifiable, Hashable {
    enum Lang: String { case any, ko, en }

    let id: String
    /// 큰 과목: 국어 · 영어 · 수학 · 과학 · 사회 · 윤리 · 역사 · 기타
    let subject: String
    /// 세부 과목 (문학, 독서, 수학Ⅰ, 생명과학, 한국사 …)
    let detail: String
    /// 짧은 이름 (예: "빈칸 추론")
    let name: String
    /// 지시문 패턴 (띄어쓰기 없앤 글에 맞추는 정규식)
    let patterns: [String]
    /// 주제 낱말: 하나라도 나와야 이 유형으로 봄 (비어 있으면 지시문만으로)
    let topics: [String]
    /// 무엇을 묻는지 (한 줄)
    let asks: String
    /// 푸는 법 (2~4단계)
    let steps: [String]
    /// 자주 하는 실수
    let traps: [String]
    /// 지문 언어 (영어 독해 유형은 영어 지문, 국어 독해 유형은 한글 지문)
    var lang: Lang = .any

    static func == (a: ProblemType, b: ProblemType) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 분류 결과 하나 (점수가 높을수록 확실)
struct ProblemTypeMatch: Hashable {
    let type: ProblemType
    let score: Double
}

enum DoitProblemTypes {
    // MARK: - 사전

    /// 모든 유형 (처음 쓸 때 한 번 만듦)
    static var all: [ProblemType] { store.types }

    /// id로 찾기
    static func type(id: String) -> ProblemType? { store.byID[id] }

    /// 과목의 유형들 ("윤리" → 큰 과목 전체, "생활과 윤리" → 그 세부 과목)
    static func types(subject: String) -> [ProblemType] {
        let s = subject.trimmingCharacters(in: .whitespaces)
        if DoitSubjectDetector.broadSubjects.contains(s) { return all.filter { $0.subject == s } }
        let key = s.filter { !$0.isWhitespace }
        let exact = all.filter { $0.detail.filter { !$0.isWhitespace } == key }
        if !exact.isEmpty { return exact }
        let broad = DoitSubjectDetector.broad(ofStored: s)
        return all.filter { $0.subject == broad }
    }

    // MARK: - 분류

    /// 문제 글 → 맞는 유형 (가장 그럴듯한 것 먼저). subjectHint: 노트 과목 ("윤리", "중학교 과학", "" = 모름)
    static func classify(_ text: String, subjectHint: String? = nil, limit: Int = 5) -> [ProblemTypeMatch] {
        let prepared = Prepared(text)
        guard !prepared.compact.isEmpty else { return [] }
        let raw = rawScores(prepared)
        guard !raw.isEmpty else { return [] }
        // 과목 기준: 알려 준 과목이 먼저, 없으면 글에서 짐작한 과목 (확실할 때만)
        var broad: String?
        var detail: String?
        var strength = 1.0
        if let hint = subjectHint?.trimmingCharacters(in: .whitespaces), !hint.isEmpty {
            broad = DoitSubjectDetector.broad(ofStored: hint)
            detail = hint
        } else if let guess = DoitSubjectDetector.detect(prepared: prepared, raw: raw) {
            broad = guess.broad
            detail = guess.detail
            strength = min(1, guess.confidence + 0.2)
        }
        // 짐작한 과목의 유형이 하나도 안 맞으면 (예: 국어 독서 지문이 경제 내용) 과목으로 거르지 않음
        if subjectHint == nil, let b = broad, !raw.contains(where: { store.types[$0.0].subject == b }) { broad = nil }
        var scored: [ProblemTypeMatch] = []
        for (index, base) in raw {
            let type = store.types[index]
            var score = base
            if let broad {
                if type.subject == broad {
                    score += 1.5 * strength
                    if let detail, !type.detail.isEmpty, detailMatches(type.detail, detail) { score += 0.8 * strength }
                } else if broad != "기타" {
                    score *= 1 - 0.6 * strength
                }
            }
            switch type.lang {
            case .en:
                if prepared.englishWords < 6 && broad != "영어" { score *= 0.75 }
            case .ko:
                if prepared.englishWords >= 20 { score *= 0.3 }
            case .any: break
            }
            if score >= 2 { scored.append(ProblemTypeMatch(type: type, score: (score * 100).rounded() / 100)) }
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.type.id < $1.type.id }
        return Array(scored.prefix(max(limit, 1)))
    }

    /// 가장 그럴듯한 유형 id (노트에 저장할 때)
    static func bestID(for text: String, subject: String?) -> String? {
        classify(text, subjectHint: subject, limit: 1).first?.type.id
    }

    private static func detailMatches(_ typeDetail: String, _ hint: String) -> Bool {
        let a = typeDetail.filter { !$0.isWhitespace }, b = hint.filter { !$0.isWhitespace }
        return a.contains(b) || b.contains(a)
    }

    /// 짧은 설명 (여러 줄): 유형 · 묻는 것 · 푸는 법 · 함정
    static func explain(_ match: ProblemTypeMatch) -> String { explain(match.type) }

    static func explain(_ type: ProblemType) -> String {
        var lines = ["유형 · \(type.name) (\(type.detail.isEmpty ? type.subject : type.detail))", "묻는 것 · \(type.asks)"]
        let marks = ["①", "②", "③", "④"]
        let steps = type.steps.prefix(4).enumerated().map { "\(marks[$0.offset]) \($0.element)" }
        if !steps.isEmpty { lines.append("푸는 법 · " + steps.joined(separator: " ")) }
        if let trap = type.traps.first { lines.append("함정 · \(trap)") }
        return lines.joined(separator: "\n")
    }

    // MARK: - 점수 (과목 보정 전)

    /// 유형 번호 → 점수 (지시문이 맞고, 주제 낱말이 있으면 그것도 맞아야 함)
    static func rawScores(_ p: Prepared) -> [(Int, Double)] {
        var patternCache: [Int: Double] = [:]
        var topicCache: [Int: Int] = [:]
        var result: [(Int, Double)] = []
        let s = store
        for (index, compiled) in s.compiled.enumerated() {
            var best = 0.0
            var extra = 0.0
            for pid in compiled.patterns {
                let w: Double
                if let cached = patternCache[pid] { w = cached } else {
                    w = s.patterns[pid].weight(in: p)
                    patternCache[pid] = w
                }
                if w > 0 {
                    if w > best { extra += best * 0.15; best = w } else { extra += w * 0.15 }
                }
            }
            guard best > 0 else { continue }
            var score = best + min(extra, 1)
            if !compiled.topics.isEmpty {
                var hits = 0
                var longest = 0
                for tid in compiled.topics {
                    let len: Int
                    if let cached = topicCache[tid] { len = cached } else {
                        len = s.topics[tid].found(in: p) ? s.topics[tid].text.count : 0
                        topicCache[tid] = len
                    }
                    if len > 0 { hits += 1; longest = max(longest, len) }
                }
                guard hits > 0 else { continue }
                score += 1.2 + 0.45 * Double(min(hits - 1, 4)) + Double(min(longest, 8)) / 10
            }
            result.append((index, score))
        }
        return result
    }

    // MARK: - 미리 손질한 글

    struct Prepared {
        /// 소문자 + 띄어쓰기 없앤 글 (괄호·물음표 모양 통일)
        let compact: String
        /// 두 글자 묶음 (빠르게 거르기용)
        let bigrams: Set<String>
        /// 영어 낱말 수 (세 글자 이상, 수식 함수 이름 빼고)
        let englishWords: Int
        /// 한글 글자 수
        let hangul: Int
        /// 수식 신호 (등호·연산 기호·x² 같은 것)
        let mathSignal: Int
        /// 원래 글 (소문자)
        let lower: String

        init(_ text: String) {
            lower = text.lowercased()
            compact = DoitProblemTypes.compact(text)
            var grams = Set<String>()
            let chars = Array(compact)
            if chars.count >= 2 { for i in 0..<(chars.count - 1) { grams.insert(String(chars[i]) + String(chars[i + 1])) } }
            bigrams = grams
            var words = 0, letters = 0
            var token = ""
            var upper = true
            let mathWords: Set<String> = ["sin", "cos", "tan", "log", "lim", "max", "min", "exp", "sec", "csc", "cot"]
            // 영어 낱말: 세 글자 이상 (모두 대문자인 약어 DNA·ATP, 수식 함수 이름은 빼고)
            for ch in text + " " {
                if ch.isASCII && ch.isLetter {
                    token.append(ch)
                    if ch.isLowercase { upper = false }
                } else {
                    if token.count >= 3 && !upper && !mathWords.contains(token.lowercased()) { words += 1 }
                    token = ""; upper = true
                }
                if ch.unicodeScalars.allSatisfy({ (0xAC00...0xD7A3).contains($0.value) }) { letters += 1 }
            }
            englishWords = words
            hangul = letters
            var signal = 0
            for ch in text where "=+×÷^√∫∑π≤≥²³∞".contains(ch) { signal += 1 }
            for token in ["f(x)", "g(x)", "x^", "y=", "a_n", "aₙ", "x²", "x³"] where lower.contains(token) { signal += 2 }
            // 영어 낱말 속 sin(using)·log(blog)는 빼고 수식 함수만
            let ns = lower as NSString
            signal += 2 * min(DoitProblemTypes.mathFunctionRegex?.numberOfMatches(in: lower, range: NSRange(location: 0, length: ns.length)) ?? 0, 4)
            mathSignal = signal
        }

        func has(_ needle: String) -> Bool {
            let chars = Array(needle)
            if chars.count >= 2 { guard bigrams.contains(String(chars[0]) + String(chars[1])) else { return false } }
            return compact.contains(needle)
        }
    }

    static let mathFunctionRegex = try? NSRegularExpression(pattern: #"(?<![a-z])(lim|log|ln|sin|cos|tan)(?![a-wyz])"#)

    /// 띄어쓰기를 없애고 괄호·물음표 모양을 통일 ("〈보 기〉" → "<보기>")
    static func compact(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text.lowercased() {
            if ch.isWhitespace { continue }
            switch ch {
            case "〈", "＜", "《": out.append("<")
            case "〉", "＞", "》": out.append(">")
            case "［", "【": out.append("[")
            case "］", "】": out.append("]")
            case "（": out.append("(")
            case "）": out.append(")")
            case "？": out.append("?")
            case "～", "∼", "〜": out.append("~")
            case "ㆍ", "・", "•": out.append("·")
            case "‘", "’", "`": out.append("'")
            case "“", "”": out.append("\"")
            case "，": out.append(",")
            default: out.append(ch)
            }
        }
        for (from, to) in [("[보기]", "<보기>"), ("(보기)", "<보기>"), ("<보기)", "<보기>"), ("(보기>", "<보기>")] where out.contains(from) {
            out = out.replacingOccurrences(of: from, with: to)
        }
        return out
    }

    // MARK: - 사전 만들기 (글 → 유형)

    struct Pattern {
        let source: String
        let regex: NSRegularExpression?
        /// 정규식 기호가 없는 그냥 글이면 바로 비교
        let literal: String?
        /// 정규식 앞부분의 그냥 글 (없으면 빈 글): 이게 없으면 정규식을 돌리지 않음
        let anchor: String
        let weight: Double

        init(_ source: String) {
            self.source = source
            let meta = Set("\\.^$|?*+()[]{}")
            if !source.contains(where: { meta.contains($0) }) {
                literal = source
                regex = nil
                anchor = source
            } else {
                literal = nil
                regex = try? NSRegularExpression(pattern: source, options: [.dotMatchesLineSeparators])
                anchor = Pattern.anchor(of: source, meta: meta)
            }
            // 글자가 길고 구체적인 패턴일수록 무게가 큼 (고르기 "(a|b)"는 짧은 쪽, "?"·".{0,9}"는 0글자로 셈)
            let letters = Pattern.minLetters(Array(source))
            weight = 1.8 + min(Double(letters), 18) / 6
        }

        /// 정규식이 맞을 때 꼭 있어야 하는 글자 수 (대략)
        static func minLetters(_ chars: [Character]) -> Int {
            var i = 0
            return sequence(chars, &i, stopAtClose: false)
        }

        /// 이어진 조각들의 글자 수 (맨 바깥 "|"가 있으면 가장 짧은 쪽)
        private static func sequence(_ c: [Character], _ i: inout Int, stopAtClose: Bool) -> Int {
            var options: [Int] = []
            var total = 0
            var last = 0
            while i < c.count {
                let ch = c[i]
                if ch == ")" && stopAtClose { i += 1; break }
                if ch == "|" { options.append(total); total = 0; last = 0; i += 1; continue }
                var unit = 0
                if ch == "(" {
                    i += 1
                    if i + 1 < c.count, c[i] == "?", c[i + 1] == ":" { i += 2 }
                    unit = sequence(c, &i, stopAtClose: true)
                } else if ch == "[" {
                    while i < c.count && c[i] != "]" { if c[i] == "\\" { i += 1 }; i += 1 }
                    i += 1
                    unit = 1
                } else if ch == "\\" {
                    i += 2
                    unit = 1
                } else if ch == "." || ch == "^" || ch == "$" {
                    i += 1
                } else if ch == "?" || ch == "*" {
                    total -= last; last = 0; i += 1; continue
                } else if ch == "+" {
                    i += 1; continue
                } else if ch == "{" {
                    let start = i
                    while i < c.count && c[i] != "}" { i += 1 }
                    i += 1
                    if String(c[start..<min(i, c.count)]).hasPrefix("{0") { total -= last; last = 0 }
                    continue
                } else {
                    i += 1
                    unit = ch.isLetter || ch.isNumber ? 1 : 0
                }
                total += unit
                last = unit
            }
            options.append(total)
            return options.min() ?? 0
        }

        /// 앞부분의 그냥 글 (맨 바깥에 "|"가 있거나 바로 뒤가 "?*{"면 쓰지 않음)
        static func anchor(of source: String, meta: Set<Character>) -> String {
            var depth = 0
            var escaped = false
            for ch in source {
                if escaped { escaped = false; continue }
                if ch == "\\" { escaped = true; continue }
                if ch == "(" || ch == "[" { depth += 1 } else if ch == ")" || ch == "]" { depth -= 1 } else if ch == "|" && depth == 0 { return "" }
            }
            let head = String(source.prefix { !meta.contains($0) })
            guard head.count >= 2 else { return "" }
            let next = source.dropFirst(head.count).first
            if let next, "?*{".contains(next) { return String(head.dropLast()).count >= 2 ? String(head.dropLast()) : "" }
            return head
        }

        func weight(in p: Prepared) -> Double {
            if let literal { return p.has(literal) ? weight : 0 }
            if !anchor.isEmpty && !p.has(anchor) { return 0 }
            guard let regex else { return 0 }
            let ns = p.compact as NSString
            return regex.firstMatch(in: p.compact, range: NSRange(location: 0, length: ns.length)) != nil ? weight : 0
        }
    }

    struct Topic {
        let text: String
        func found(in p: Prepared) -> Bool { p.has(text) }
    }

    struct Compiled {
        let patterns: [Int]
        let topics: [Int]
    }

    final class Store {
        let types: [ProblemType]
        let byID: [String: ProblemType]
        let patterns: [Pattern]
        let topics: [Topic]
        let compiled: [Compiled]

        init(types: [ProblemType]) {
            self.types = types
            var map: [String: ProblemType] = [:]
            for t in types where map[t.id] == nil { map[t.id] = t }
            byID = map
            var patternIndex: [String: Int] = [:]
            var topicIndex: [String: Int] = [:]
            var patterns: [Pattern] = []
            var topics: [Topic] = []
            var compiled: [Compiled] = []
            for t in types {
                var pids: [Int] = []
                for source in t.patterns {
                    if let i = patternIndex[source] { pids.append(i); continue }
                    patternIndex[source] = patterns.count
                    pids.append(patterns.count)
                    patterns.append(Pattern(source))
                }
                var tids: [Int] = []
                for word in t.topics {
                    if let i = topicIndex[word] { tids.append(i); continue }
                    topicIndex[word] = topics.count
                    tids.append(topics.count)
                    topics.append(Topic(text: word))
                }
                compiled.append(Compiled(patterns: pids, topics: tids))
            }
            self.patterns = patterns
            self.topics = topics
            self.compiled = compiled
        }

        /// 정규식이 잘못된 패턴 (테스트용)
        var brokenPatterns: [String] { patterns.filter { $0.literal == nil && $0.regex == nil }.map(\.source) }
    }

    static let store: Store = Store(types: buildAll())

    /// 과목별 데이터 모음
    static func buildAll() -> [ProblemType] {
        var list: [ProblemType] = []
        list += parseTypes(koreanTypes, subject: "국어", prefix: "ko", lang: .ko)
        list += parseTypes(koreanGrammarTypes, subject: "국어", prefix: "kog", lang: .any)
        list += parseTypes(englishTypes, subject: "영어", prefix: "en", lang: .en)
        list += generate(forms: englishGrammarForms, topics: englishGrammarTopics, subject: "영어", prefix: "eng")
        list += parseTypes(mathTypes, subject: "수학", prefix: "ma", lang: .any)
        list += generate(forms: mathForms, topics: mathTopics, subject: "수학", prefix: "ma")
        list += parseTypes(scienceTypes, subject: "과학", prefix: "sc", lang: .any)
        list += generate(forms: scienceForms, topics: scienceTopics, subject: "과학", prefix: "sc")
        list += parseTypes(socialTypes, subject: "사회", prefix: "so", lang: .any)
        list += generate(forms: socialForms, topics: socialTopics, subject: "사회", prefix: "so")
        list += parseTypes(ethicsTypes, subject: "윤리", prefix: "et", lang: .any)
        list += generate(forms: ethicsForms, topics: ethicsTopics, subject: "윤리", prefix: "et")
        list += parseTypes(historyTypes, subject: "역사", prefix: "hi", lang: .any)
        list += generate(forms: historyForms, topics: historyTopics, subject: "역사", prefix: "hi")
        list += parseTypes(etcTypes, subject: "기타", prefix: "etc", lang: .any)
        return list
    }

    // MARK: 글 읽기

    static func lines(_ text: String) -> [[String]] {
        text.components(separatedBy: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("//") else { return nil }
            return line.components(separatedBy: " | ").map { $0.trimmingCharacters(in: .whitespaces) }
        }
    }

    static func list(_ field: String, _ separator: String) -> [String] {
        field.components(separatedBy: separator).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// 지시문 패턴: 띄어쓰기를 없애고 소문자로
    static func patternList(_ field: String) -> [String] {
        list(field, " ; ").map { compact($0) }
    }

    static func topicList(_ field: String) -> [String] {
        list(field, ",").map { compact($0) }.filter { !$0.isEmpty }
    }

    static func parseTypes(_ text: String, subject: String, prefix: String, lang: ProblemType.Lang) -> [ProblemType] {
        lines(text).compactMap { f in
            guard f.count >= 7 else { return nil }
            return ProblemType(id: "\(prefix).\(f[0])", subject: subject, detail: f[1], name: f[2], patterns: patternList(f[3]),
                               topics: f.count >= 8 ? topicList(f[7]) : [], asks: f[4], steps: list(f[5], " / "), traps: list(f[6], " / "),
                               lang: lang)
        }
    }

    static func generate(forms formText: String, topics topicText: String, subject: String, prefix: String) -> [ProblemType] {
        let forms = lines(formText).filter { $0.count >= 6 }
        var result: [ProblemType] = []
        for t in lines(topicText) where t.count >= 7 {
            let wanted = Set(list(t[6], ","))
            let words = topicList(t[3])
            for f in forms where wanted.contains("*") || wanted.contains(f[0]) {
                let formSteps = list(f[4], " / ").map { $0.replacingOccurrences(of: "{T}", with: t[2]) }
                var steps = Array(formSteps.prefix(1))
                steps.append(t[4])
                steps += formSteps.dropFirst()
                var traps = [t[5]]
                traps += list(f[5], " / ").prefix(1).map { $0.replacingOccurrences(of: "{T}", with: t[2]) }
                result.append(ProblemType(id: "\(prefix).\(t[0]).\(f[0])", subject: subject, detail: t[1], name: "\(t[2]) · \(f[1])",
                                          patterns: patternList(f[2]), topics: words,
                                          asks: f[3].replacingOccurrences(of: "{T}", with: t[2]),
                                          steps: Array(steps.prefix(4)), traps: traps.filter { !$0.isEmpty }))
            }
        }
        return result
    }
}
