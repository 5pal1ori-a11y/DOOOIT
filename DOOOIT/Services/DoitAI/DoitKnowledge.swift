import Foundation

/// 모티 AI 지식 검색: 수학·과학·사회·영어 엔진에 들어 있는 모든 개념을 모아서
/// 이름이 정확히 안 맞아도 비슷한 말로 찾아줌 (글자 두 개씩 묶어 비교하는 방식, 외부 AI 없음)
enum DoitKnowledge {
    struct Entry {
        let subject: String
        let names: [String]
        let body: String
        /// 교육과정 사전에서 온 개념이면 학교급·단원
        var level: SchoolLevel? = nil
        var unit: String? = nil
        var title: String { names.first ?? "" }
        /// 화면에 보여줄 과목 표시 (예: "중학교 수학")
        var label: String { level.map { "\($0.rawValue) \(subject)" } ?? subject }
    }

    struct Match {
        let entry: Entry
        let score: Double
    }

    static let entries: [Entry] = {
        var list: [Entry] = []
        list += DoitMathConcepts.knowledgeEntries.map { Entry(subject: "수학", names: $0.names, body: $0.body) }
        list += DoitScience.knowledgeEntries.map { Entry(subject: "과학", names: $0.names, body: $0.body) }
        list += DoitSocial.knowledgeEntries.map { Entry(subject: "사회", names: $0.names, body: $0.body) }
        list += DoitEnglish.knowledgeEntries.map { Entry(subject: "영어", names: $0.names, body: $0.body) }
        // 자주 묻는 인물·현상·맞춤법 (모델 없이도 답할 수 있게 직접 정리한 것)
        list += DoitZeroFacts.entries.map { Entry(subject: $0.subject, names: $0.names, body: $0.body) }
        // 초등 ~ 대학교 교육과정 사전 (같은 이름이 이미 있으면 앞의 설명을 남기고 건너뜀)
        // (같은 이름이면 다른 이름들은 앞 개념의 다른 이름으로 더함: "공리주의"의 "벤담과 밀")
        func squash(_ s: String) -> String { s.lowercased().filter { !$0.isWhitespace } }
        var seen: [String: Int] = [:]
        for (i, entry) in list.enumerated() where seen[squash(entry.title)] == nil { seen[squash(entry.title)] = i }
        for (subject, items) in DoitCurriculum.bySubject {
            for item in items {
                let key = squash(item.names.first ?? "")
                guard !key.isEmpty else { continue }
                if let index = seen[key] {
                    let old = list[index]
                    let known = Set(old.names.map(squash))
                    let extra = item.names.filter { !known.contains(squash($0)) }
                    if !extra.isEmpty {
                        list[index] = Entry(subject: old.subject, names: old.names + extra, body: old.body, level: old.level, unit: old.unit)
                    }
                    continue
                }
                seen[key] = list.count
                list.append(Entry(subject: subject, names: item.names, body: item.body, level: item.level, unit: item.unit))
            }
        }
        return list.filter { !$0.names.isEmpty && !$0.body.isEmpty }
    }()

    /// 묻는 말에 붙는 낱말 (검색할 때 빼고 비교)
    private static let fillers = ["뭐야", "뭔가요", "뭐예요", "뭐지", "뭔데", "무엇", "무슨", "설명해줘", "설명해", "설명", "알려줘", "알려", "가르쳐줘",
                                  "궁금해", "궁금", "란", "이란", "정의", "개념", "의미", "뜻", "좀", "해줘", "줘", "요", "어떻게", "대해", "대해서", "에", "이", "가",
                                  "은", "는", "을", "를", "의", "?", "!", ".", "말해줘", "쉽게", "뭐라고해", "뭐라고하지", "뭐라고", "라고해", "라고", "하는거", "것을"]

    /// 낱말로만 빼는 말 (낱말 전체가 이 말일 때만: "구하는 법"의 '법'은 빼지만 "문법"은 그대로)
    private static let wholeFillers: Set<String> = ["차이", "차이점", "구하는", "하는", "법", "방법", "구하는법", "하는법", "공식은", "언제야", "누구야", "어디야", "머야", "머임", "뭐임"]
    private static let suffixFillers = (fillers + ["구하는법", "구하는방법", "하는법", "하는방법", "머야", "머임", "뭐임", "언제야", "누구야"]).filter { $0.count >= 2 }.sorted { $0.count > $1.count }

    /// 묻는 말을 뺀 낱말들: 낱말 전체가 묻는 말이거나 낱말 끝에 붙은 묻는 말만 뗌
    /// (예전처럼 글자 가운데서 빼면 "정의론" → "론", "설명문" → "문"처럼 개념 이름이 망가짐)
    static func words(_ text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "?!.,~'\"()？！"))
        var result: [String] = []
        for piece in text.lowercased().components(separatedBy: separators) where !piece.isEmpty {
            var word = piece
            if fillers.contains(word) || wholeFillers.contains(word) { continue }
            var changed = true
            while changed {
                changed = false
                for filler in suffixFillers where word.count > filler.count && word.hasSuffix(filler) {
                    word.removeLast(filler.count)
                    changed = true
                    break
                }
            }
            for prefix in ["무슨", "좀"] where word.hasPrefix(prefix) && word.count > prefix.count + 1 { word.removeFirst(prefix.count) }
            if !word.isEmpty { result.append(word) }
        }
        return result
    }

    static func normalize(_ text: String) -> String {
        words(text).joined()
    }

    /// 낱말 비교용 모양들 (조사를 뗀 것도: "세종의" → 세종의, 세종)
    private static func forms(_ word: String) -> [String] {
        var list = [word]
        let stripped = DoitRelevance.stripParticle(word)
        if stripped != word { list.append(stripped) }
        if word.count >= 3, word.hasSuffix("의") { list.append(String(word.dropLast())) }
        // 한 글자 낱말 + 조사 ("되와" → 되, "원의" → 원)
        if word.count == 2, let last = word.last, ["와", "과", "의", "랑", "는", "은", "를", "을", "가", "이", "도"].contains(String(last)),
           let first = word.first, DoitRelevance.particleFits(String(last), after: first) {
            list.append(String(first))
        }
        return list
    }

    /// 질문 낱말 하나와 이름 낱말 하나가 같은 말인지 ("세종대왕" ↔ "세종", "세포" ↔ "체세포", "벤담이랑" ↔ "벤담과")
    private static func sameWord(_ q: String, _ n: String) -> Bool {
        let qs = forms(q), ns = forms(n)
        for a in qs {
            for b in ns {
                if a == b { return true }
                if b.count >= 2, a.hasPrefix(b), a.count - b.count <= 2 { return true }
                if a.count >= 2, b.hasSuffix(a), b.count - a.count <= 1 { return true }
            }
        }
        return false
    }

    /// 이름의 낱말이 모두 질문에 있으면 (질문 낱말을 얼마나 덮었는지에 따라) 점수
    private static func tokenScore(query: [String], name: String) -> Double {
        let plain = name.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        // (이름 속 "비교", "차이"는 묻는 말과 같아서 빼고 비교: "광합성과 호흡의 비교" ↔ "호흡과 광합성의 차이")
        let parts = plain.lowercased().components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "·,/")))
            .filter { !$0.isEmpty && !["비교", "차이", "차이점"].contains($0) }
        guard !parts.isEmpty, !query.isEmpty, parts.joined().count >= 2 else { return 0 }
        guard parts.allSatisfy({ n in query.contains { sameWord($0, n) } }) else {
            // 띄어 쓰지 않은 질문 ("세종대왕업적"): 이름의 낱말(두 글자 이상)이 모두 질문 속에 있으면 덮은 글자 수만큼
            let joined = query.joined()
            guard query.count <= 2, parts.count >= 2, parts.allSatisfy({ $0.count >= 2 }) else { return 0 }
            var used = 0
            for part in parts {
                guard let form = forms(part).first(where: { $0.count >= 2 && joined.contains($0) }) else { return 0 }
                used += form.count
            }
            return 0.45 + 0.4 * min(1, Double(used) / Double(max(1, joined.count)))
        }
        let covered = query.filter { q in parts.contains { sameWord(q, $0) } }.count
        return 0.5 + 0.4 * Double(covered) / Double(query.count) + (parts.count >= 2 ? 0.05 : 0)
    }

    /// 이름이 질문 속 낱말의 시작에 있는지 ("반어법" 속 "어법"은 아님)
    private static func startsAtWord(_ name: String, in tokens: [String]) -> Bool {
        let joined = tokens.joined()
        var offset = 0
        for token in tokens {
            if joined.dropFirst(offset).hasPrefix(name) { return true }
            offset += token.count
        }
        return false
    }

    static func bigrams(_ text: String) -> [String: Double] {
        let chars = Array(text)
        guard chars.count >= 2 else { return chars.isEmpty ? [:] : [String(chars): 1] }
        var result: [String: Double] = [:]
        for i in 0..<(chars.count - 1) { result[String(chars[i...i + 1]), default: 0] += 1 }
        return result
    }

    static func cosine(_ a: [String: Double], _ b: [String: Double]) -> Double {
        var dot = 0.0
        for (k, v) in a { if let w = b[k] { dot += v * w } }
        let na = sqrt(a.values.reduce(0) { $0 + $1 * $1 }), nb = sqrt(b.values.reduce(0) { $0 + $1 * $1 })
        return na == 0 || nb == 0 ? 0 : dot / (na * nb)
    }

    /// 미리 계산해 둔 이름·설명(문장마다) 글자 묶음
    private static let index: [(name: [String: Double], sentences: [[String: Double]], names: [String])] = entries.map { entry in
        let nameText = entry.names.map { $0.lowercased().filter { !$0.isWhitespace } }.joined(separator: " ")
        let sentences = entry.body.components(separatedBy: CharacterSet(charactersIn: "\n.")).map {
            normalize($0)
        }.filter { $0.count >= 4 }
        return (bigrams(nameText), sentences.prefix(8).map { bigrams($0) }, entry.names.map { $0.lowercased().filter { !$0.isWhitespace } })
    }

    /// 가장 비슷한 개념들 (점수 0~1, 높을수록 비슷)
    static func search(_ query: String, limit: Int = 3) -> [Match] {
        let queryWords = words(query)
        let q = queryWords.joined()
        guard q.count >= 2 else { return [] }
        let qb = bigrams(q)
        var results: [Match] = []
        // 짧은 질문은 이름 위주, 긴 질문(설명으로 묻기)은 설명 문장 위주로 비교
        let nameWeight = q.count <= 6 ? 0.8 : 0.35
        for (i, item) in index.enumerated() {
            let sentenceScore = item.sentences.map { cosine(qb, $0) }.max() ?? 0
            var score = nameWeight * cosine(qb, item.name) + (1 - nameWeight) * sentenceScore
            // 설명 문장과 아주 비슷하면 그 자체로 충분
            if q.count >= 8 { score = max(score, sentenceScore * 0.95) }
            // 이름이 질문에 그대로 들어 있으면 크게 올림 (긴 이름일수록)
            // 낱말 가운데에 든 짧은 이름은 다른 말의 일부 ("반어법" 속 "어법", "시간" 속 "시")
            if let hit = item.names.filter({ $0.count >= 2 && q.contains($0) && ($0.count >= 4 || startsAtWord($0, in: queryWords)) }).max(by: { $0.count < $1.count }) {
                score = max(score, 0.6 + min(0.35, Double(hit.count) * 0.05))
            }
            // 이름의 낱말이 모두 질문에 있으면 ("세종대왕 업적" ↔ "세종의 업적", "삼각형 넓이 구하는 법" ↔ "삼각형의 넓이")
            if queryWords.count <= 6 {
                let best = entries[i].names.map { tokenScore(query: queryWords, name: $0) }.max() ?? 0
                score = max(score, best)
            }
            // 이름이 질문 낱말과 똑같으면 조금 더 ("소수" → '복소수'가 아니라 '소수')
            if queryWords.count == 1, item.names.contains(q) || item.names.contains(DoitRelevance.stripParticle(q)) { score = min(1, score + 0.06) }
            if score > 0.18 { results.append(Match(entry: entries[i], score: score)) }
        }
        return Array(results.sorted { $0.score > $1.score }.prefix(limit))
    }

    /// 확실한 답이 있으면 보기 좋게 (없으면 nil)
    static func answer(_ query: String) -> String? {
        guard let best = search(query, limit: 3).first, best.score >= 0.45 else { return nil }
        // 다른 이름으로 물었으면 그 이름도 같이 ("논설문" → **주장하는 글** (논설문 · 초등 국어))
        let asked = words(query).joined()
        let alias = best.entry.names.dropFirst().first { name in
            let key = name.lowercased().filter { !$0.isWhitespace }
            return key.count >= 2 && asked.contains(key) && !best.entry.title.lowercased().filter({ !$0.isWhitespace }).contains(key)
        }
        var text = "**\(best.entry.title)** (\(alias.map { "\($0) · " } ?? "")\(best.entry.label))\n\(best.entry.body)"
        // 함께 보면 좋은 개념: 같은 과목이고 이름이 질문 낱말로 시작하거나 ("소수" → '소수와 합성수') 같은 갈래인 것 ("은유법" → '직유법')만
        // ("빛의 분산"에 통계 '분산', "안 않 구분"에 '분류'처럼 낱말만 겹치는 개념은 붙이지 않음)
        let asks = words(query).map { DoitRelevance.stripParticle($0) }.filter { $0.count >= 2 }
        let bestTitle = best.entry.title.lowercased().filter { !$0.isWhitespace }
        let others = search(query, limit: 4).dropFirst().filter { match in
            guard match.score >= 0.35, match.entry.subject == best.entry.subject else { return false }
            let title = match.entry.title.lowercased().filter { !$0.isWhitespace }
            let sameKind = title.count >= 3 && bestTitle.count >= 3 && title.suffix(2) == bestTitle.suffix(2)
            return asks.contains { title.hasPrefix($0) } || sameKind
        }.map(\.entry.title)
        if !others.isEmpty { text += "\n\n함께 보면 좋아요: " + others.joined(separator: ", ") }
        return text
    }

    /// 교육과정 단원에 들어 있는 개념들 (AI 학습에서 단원을 골랐을 때)
    /// (검색 사전에서는 이름이 겹쳐 빠진 개념도, 단원 목록에는 모두 들어 있음)
    /// subject에는 "국어" 같은 과목 이름이나 "초등 국어" 같은 AI 학습 과목 이름을 넣어도 돼요 (학교급이 있으면 그 학교급만)
    static func entries(inUnit unit: String, subject: String? = nil) -> [Entry] {
        let key = unit.filter { !$0.isWhitespace }
        let level = subject.flatMap { name in SchoolLevel.allCases.first { name.hasPrefix($0.rawValue) } }
        let subjectKey = subject.flatMap { name in DoitCurriculum.bySubject.map(\.subject).first { name.contains($0) } }
        return (unitIndex[key] ?? []).filter { entry in
            (subjectKey.map { entry.subject == $0 } ?? true) && (level.map { entry.level == $0 } ?? true)
        }
    }

    /// 단원 → 그 단원의 교육과정 개념 전체
    private static let unitIndex: [String: [Entry]] = {
        var index: [String: [Entry]] = [:]
        for (subject, items) in DoitCurriculum.bySubject {
            for item in items where !item.names.isEmpty && !item.body.isEmpty {
                index[item.unit.filter { !$0.isWhitespace }, default: []]
                    .append(Entry(subject: subject, names: item.names, body: item.body, level: item.level, unit: item.unit))
            }
        }
        return index
    }()

    /// 이름이 정확히 같은 개념
    static func entry(named topic: String) -> Entry? {
        let key = topic.lowercased().filter { !$0.isWhitespace }
        return entries.first { $0.names.contains { $0.lowercased().filter { !$0.isWhitespace } == key } }
    }

    /// 함께 보면 좋은 개념: 같은 과목에서 설명이 비슷한 것 (추천·"더 자세히"용)
    static func related(to topic: String, limit: Int = 3) -> [Entry] {
        let base = entry(named: topic)
        let probe = base.map { $0.title + " " + String($0.body.prefix(120)) } ?? topic
        let qb = bigrams(normalize(probe))
        var scored: [(Entry, Double)] = []
        for (i, item) in index.enumerated() {
            let candidate = entries[i]
            if let base, candidate.title == base.title { continue }
            if candidate.title == topic { continue }
            if let base, candidate.subject != base.subject { continue }
            let score = (item.sentences.map { cosine(qb, $0) }.max() ?? 0) + 0.5 * cosine(qb, item.name)
            if score > 0.22 { scored.append((candidate, score)) }
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }
}
