import Foundation

/// 두잇 AI 기억: 스스로 배운 내용을 계정마다 따로 쌓아 두고 다음 답에 씀
/// - 인터넷에서 찾아 자기 말로 정리한 내용 (learned)
/// - 사용자가 알려준 사실·고쳐준 내용 (userFact, correction)
/// - 👍 받은 설명은 점수가 오르고, 👎 받은 설명은 점수가 내려가 덜 쓰거나 지워짐
/// 모델 자체를 다시 훈련하지는 않아요. 대신 이 기억을 찾아서(검색) 답할 때 근거로 넣어요.
@MainActor
final class DoitMemory {
    static let shared = DoitMemory()

    struct Note: Codable, Identifiable, Equatable {
        enum Kind: String, Codable { case learned, userFact, correction }
        var id = UUID()
        var kind: Kind
        var topic: String
        var summary: String
        var sources: [String] = []
        var createdAt = Date()
        var updatedAt = Date()
        var uses = 0
        /// 👍 +1, 👎 -1 (−2 이하가 되면 지움)
        var score = 0
    }

    private(set) var notes: [Note] = []
    private var fileURL: URL?
    static let limit = 400

    /// 계정 폴더에 연결 (nil이면 로그아웃 상태 — 저장하지 않음)
    func attach(folder: URL?) {
        fileURL = folder?.appending(path: "DoitMemory.json")
        notes = []
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Note].self, from: data) {
            notes = saved
        }
    }

    // MARK: 기억하기

    /// 같은 주제가 있으면 새 내용으로 바꾸고, 없으면 새로 기억
    @discardableResult
    func remember(topic rawTopic: String, summary rawSummary: String, sources: [String] = [], kind: Note.Kind = .learned) -> Note? {
        let topic = rawTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = Self.trimmed(rawSummary, max: 900)
        guard topic.count >= 1, summary.count >= 4 else { return nil }
        let key = Self.key(topic)
        if let index = notes.firstIndex(where: { Self.key($0.topic) == key && $0.kind == kind }) {
            notes[index].summary = summary
            notes[index].sources = Array(Set(notes[index].sources + sources)).sorted()
            notes[index].updatedAt = Date()
            save()
            return notes[index]
        }
        let note = Note(kind: kind, topic: topic, summary: summary, sources: sources)
        notes.append(note)
        if notes.count > Self.limit {
            // 오래되고 덜 쓴 것부터 정리 (사용자가 알려준 것은 남김)
            let removable = notes.enumerated().filter { $0.element.kind == .learned }
                .sorted { ($0.element.score, $0.element.uses, $0.element.updatedAt) < ($1.element.score, $1.element.uses, $1.element.updatedAt) }
            if let oldest = removable.first { notes.remove(at: oldest.offset) }
        }
        save()
        return note
    }

    /// 답에 대한 평가
    func feedback(topic: String, answer: String, good: Bool) {
        let key = Self.key(topic)
        if let index = notes.firstIndex(where: { Self.key($0.topic) == key && $0.kind == .learned }) {
            notes[index].score += good ? 1 : -1
            if good { notes[index].summary = Self.trimmed(answer, max: 900) }
            notes[index].updatedAt = Date()
            if notes[index].score <= -2 { notes.remove(at: index) }
        } else if good {
            var note = Note(kind: .learned, topic: topic, summary: Self.trimmed(answer, max: 900))
            note.score = 1
            notes.append(note)
        }
        save()
    }

    /// 👎를 받은 주제인지 (다음에는 인터넷에서 다시 찾아봄)
    func isDisliked(_ topic: String) -> Bool {
        let key = Self.key(topic)
        return notes.contains { Self.key($0.topic) == key && $0.score < 0 }
    }

    func forget(_ id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    func forgetAll() {
        notes = []
        save()
    }

    // MARK: 떠올리기

    /// 질문과 관련 있는 기억 (점수가 높을수록 먼저)
    func recall(_ query: String, limit: Int = 3) -> [Note] {
        let ranked = Self.rank(notes, for: query)
        let picked = ranked.prefix(limit)
        for note in picked {
            if let index = notes.firstIndex(where: { $0.id == note.id }) { notes[index].uses += 1 }
        }
        if !picked.isEmpty { save() }
        return Array(picked)
    }

    /// 순수 함수 (테스트용): 비슷한 기억 고르기
    nonisolated static func rank(_ notes: [Note], for query: String) -> [Note] {
        let q = DoitKnowledge.normalize(query)
        guard q.count >= 2 else { return [] }
        let qb = DoitKnowledge.bigrams(q)
        let scored: [(Note, Double)] = notes.compactMap { note in
            guard note.score > -2 else { return nil }
            let topic = key(note.topic)
            var s = 0.7 * DoitKnowledge.cosine(qb, DoitKnowledge.bigrams(topic))
                + 0.3 * DoitKnowledge.cosine(qb, DoitKnowledge.bigrams(DoitKnowledge.normalize(String(note.summary.prefix(160)))))
            if topic.count >= 2 && q.contains(topic) { s = max(s, 0.65 + min(0.3, Double(topic.count) * 0.04)) }
            s += Double(max(-1, min(3, note.score))) * 0.03
            return s >= 0.4 ? (note, s) : nil
        }
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }

    nonisolated static func key(_ topic: String) -> String {
        topic.lowercased().filter { !$0.isWhitespace && !"?!.,~'\"()「」".contains($0) }
    }

    nonisolated static func trimmed(_ text: String, max: Int) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > max else { return t }
        let cut = String(t.prefix(max))
        // 문장 끝에서 자름
        if let end = cut.range(of: "요.", options: .backwards) ?? cut.range(of: ".", options: .backwards), cut.distance(from: cut.startIndex, to: end.upperBound) > max / 2 {
            return String(cut[..<end.upperBound])
        }
        return cut + "…"
    }

    private func save() {
        guard let fileURL else { return }
        guard let data = try? JSONEncoder().encode(notes) else { return }
        #if os(iOS)
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        #else
        try? data.write(to: fileURL, options: .atomic)
        #endif
    }
}
