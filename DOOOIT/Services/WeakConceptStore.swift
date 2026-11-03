import Foundation
import SwiftData

/// 오답노트 → 취약 개념 기록 (같은 개념의 오답이 쌓이면 취약 개념으로)
@MainActor
enum WeakConceptStore {
    /// 노트의 개념 (수학은 풀이 엔진이 알아낸 유형, 그 밖에는 노트의 단원)
    static func concept(for note: MathNote) -> (key: String, subject: String, unit: String, concept: String) {
        let kind = note.subjectKind
        if kind.isMath, let solved = MathSolver.solve(note.recognizedText), let info = DoitMathConceptMap.info(for: solved.kind) {
            return ("\(info.subject)|\(info.unit)|\(info.concept)", info.subject, info.unit, info.concept)
        }
        let unit = note.unit.trimmingCharacters(in: .whitespaces)
        let subject = note.subject.isEmpty ? "기타" : note.subject
        // 수학이 아닌 과목: 단원이 없으면 문제에 나온 개념 (교육과정 사전), 그것도 없으면 제목
        let found = kind.isMath || !unit.isEmpty ? nil
            : DoitSubjectNote.concepts(problem: note.scan?.body ?? note.recognizedText, choices: note.scan?.choices ?? [], subject: kind, limit: 1).first?.title
        let concept = unit.isEmpty ? (found ?? (note.title.isEmpty ? "기타" : note.title)) : unit
        return ("\(subject)|\(unit)|\(concept)", subject, unit, concept)
    }

    /// 오답 원인을 직접 고쳤을 때: 앞서 기록한 원인 대신 새 원인으로 (풀이 횟수는 그대로)
    static func changeCause(note: MathNote, from old: String?, to new: String, context: ModelContext) {
        guard !note.conceptKey.isEmpty, let item = find(note.conceptKey, context: context), old != new else { return }
        var causes = item.causes
        if let old, let count = causes[old] { causes[old] = count > 1 ? count - 1 : nil }
        causes[new, default: 0] += 1
        item.causes = causes
        try? context.save()
    }

    static func find(_ key: String, context: ModelContext) -> WeakConcept? {
        let descriptor = FetchDescriptor<WeakConcept>(predicate: #Predicate { $0.key == key })
        return try? context.fetch(descriptor).first
    }

    /// 채점 결과를 기록 (오답이면 원인도)
    @discardableResult
    static func recordGrade(note: MathNote, correct: Bool, level: Int = 3, source: String, cause: String? = nil, context: ModelContext) -> WeakConcept {
        let info = concept(for: note)
        let item = find(info.key, context: context) ?? {
            let made = WeakConcept(key: info.key, subject: info.subject, unit: info.unit, concept: info.concept,
                                   problemType: (note.kind ?? note.scan?.kind ?? .shortAnswer).title)
            made.mastery = 0.3
            context.insert(made)
            return made
        }()
        item.record(correct: correct, level: level, source: source, answer: note.myAnswer, correctAnswer: note.correctAnswer, cause: cause)
        note.conceptKey = info.key
        try? context.save()
        // 채점한 뒤 새 배지 확인 (다시 맞힘 등)
        BadgeCenter.shared.check(context: context)
        return item
    }

    /// AI 모의고사 채점 결과를 개념별로 기록 (개념 키가 있는 문제만)
    static func recordMock(key: String, correct: Bool, answer: String, correctAnswer: String, context: ModelContext) {
        guard !key.isEmpty, let item = find(key, context: context) else { return }
        item.record(correct: correct, level: 3, source: "모의고사", answer: answer, correctAnswer: correctAnswer)
    }
}
