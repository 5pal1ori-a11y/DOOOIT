import Foundation

/// 두잇 AI 지식 검색: 수학·과학·사회·영어 엔진에 들어 있는 모든 개념을 모아서
/// 이름이 정확히 안 맞아도 비슷한 말로 찾아줌 (글자 두 개씩 묶어 비교하는 방식, 외부 AI 없음)
enum DoitKnowledge {
    struct Entry {
        let subject: String
        let names: [String]
        let body: String
        var title: String { names.first ?? "" }
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
        return list.filter { !$0.names.isEmpty && !$0.body.isEmpty }
    }()

    /// 묻는 말에 붙는 낱말 (검색할 때 빼고 비교)
    private static let fillers = ["뭐야", "뭔가요", "뭐예요", "뭐지", "뭔데", "무엇", "무슨", "설명해줘", "설명해", "설명", "알려줘", "알려", "가르쳐줘",
                                  "궁금해", "궁금", "란", "이란", "정의", "개념", "의미", "뜻", "좀", "해줘", "줘", "요", "어떻게", "대해", "대해서", "에", "이", "가",
                                  "은", "는", "을", "를", "의", "?", "!", ".", "말해줘", "쉽게", "뭐라고해", "뭐라고하지", "뭐라고", "라고해", "라고", "하는거", "것을"]

    static func normalize(_ text: String) -> String {
        var t = text.lowercased()
        for word in fillers.sorted(by: { $0.count > $1.count }) where word.count >= 2 { t = t.replacingOccurrences(of: word, with: " ") }
        return t.filter { !$0.isWhitespace && !"?!.,~'\"()".contains($0) }
    }

    private static func bigrams(_ text: String) -> [String: Double] {
        let chars = Array(text)
        guard chars.count >= 2 else { return chars.isEmpty ? [:] : [String(chars): 1] }
        var result: [String: Double] = [:]
        for i in 0..<(chars.count - 1) { result[String(chars[i...i + 1]), default: 0] += 1 }
        return result
    }

    private static func cosine(_ a: [String: Double], _ b: [String: Double]) -> Double {
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
        let q = normalize(query)
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
            if let hit = item.names.filter({ $0.count >= 2 && q.contains($0) }).max(by: { $0.count < $1.count }) {
                score = max(score, 0.6 + min(0.35, Double(hit.count) * 0.05))
            }
            if score > 0.18 { results.append(Match(entry: entries[i], score: score)) }
        }
        return Array(results.sorted { $0.score > $1.score }.prefix(limit))
    }

    /// 확실한 답이 있으면 보기 좋게 (없으면 nil)
    static func answer(_ query: String) -> String? {
        guard let best = search(query, limit: 3).first, best.score >= 0.45 else { return nil }
        var text = "**\(best.entry.title)** (\(best.entry.subject))\n\(best.entry.body)"
        let others = search(query, limit: 4).dropFirst().filter { $0.score >= 0.35 }.map(\.entry.title)
        if !others.isEmpty { text += "\n\n함께 보면 좋아요: " + others.joined(separator: ", ") }
        return text
    }

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
