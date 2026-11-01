import Foundation
import SwiftData

/// 오답노트 → 취약 개념 기록 (같은 개념의 오답이 쌓이면 취약 개념으로)
@MainActor
enum WeakConceptStore {
    /// 노트의 개념 (수학은 풀이 엔진이 알아낸 유형, 그 밖에는 노트의 단원)
    static func concept(for note: MathNote) -> (key: String, subject: String, unit: String, concept: String) {
        if let solved = MathSolver.solve(note.recognizedText), let info = DoitMathConceptMap.info(for: solved.kind) {
            return ("\(info.subject)|\(info.unit)|\(info.concept)", info.subject, info.unit, info.concept)
        }
        let unit = note.unit.trimmingCharacters(in: .whitespaces)
        let subject = note.subject.isEmpty ? "기타" : note.subject
        let concept = unit.isEmpty ? (note.title.isEmpty ? "기타" : note.title) : unit
        return ("\(subject)|\(unit)|\(concept)", subject, unit, concept)
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
        return item
    }
}
