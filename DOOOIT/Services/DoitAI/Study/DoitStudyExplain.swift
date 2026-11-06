import Foundation

/// AI 학습 설명을 한 겹 더 깊게: 핵심 개념 · 왜 그런지(원리) · 비유/실생활 예시 · 자주 하는 실수 · 확인 문제
/// 규칙으로 만들 때는 학습 자료에 있는 문장만 골라 쓰고(지어내지 않음), 확인 문제는 검증을 통과한 O/X만 써요.
/// 모델로 만들 때는 같은 틀을 프롬프트로 주고, 나온 문장은 자료에 근거하는지 따로 검사해요.
extension DoitStudy {
    /// 이유·원리를 말하는 문장의 단서
    static let whyCues = ["때문", "므로", "따라서", "그래서", "이유", "원리", "덕분", "로 인해", "으로 인해", "기 위해", "위해서"]
    /// 헷갈리기 쉬운 점을 말하는 문장의 단서
    static let mistakeCues = ["혼동", "헷갈", "주의", "착각", "구분", "아니라", "오해", "달리"]

    /// 모델에게 줄 생각 틀 (짧게): 관점을 한두 개 골라 속으로 생각한 뒤 쓰기
    static let thinkingHint = "쓰기 전에 속으로 원인→결과, 큰 그림→세부, 일상 예시, 반대로 생각하기 중 알맞은 한두 가지 관점으로 확인해요. 생각 과정은 쓰지 않아요."

    /// 자료에서 이유·원리 문장 (정의 문장 다음부터, 자료 그대로)
    static func rulePrinciples(materials: [DoitStudyMaterial], basis: DoitStudyCheck.Basis, limit: Int = 3) -> [String] {
        var result: [String] = []
        for m in materials {
            for sentence in sentences(of: m.paragraph).dropFirst() where result.count < limit {
                guard whyCues.contains(where: { sentence.contains($0) }), sentence.count <= 160 else { continue }
                let line = m.kind == .engine ? sentence : "\(m.title) — \(sentence)"
                if DoitStudyCheck.checkSentence(line, basis: basis, label: "원리").isEmpty, !result.contains(line) { result.append(line) }
            }
        }
        return result
    }

    /// 자료에서 헷갈리기 쉬운 점 + 서로 다른 두 개념을 나란히 (구분해서 기억하기)
    static func ruleMistakes(materials: [DoitStudyMaterial], basis: DoitStudyCheck.Basis, avoiding used: [String], limit: Int = 3) -> [String] {
        var result: [String] = []
        for m in materials {
            for sentence in sentences(of: m.paragraph) where result.count < limit {
                guard mistakeCues.contains(where: { sentence.contains($0) }), sentence.count <= 160 else { continue }
                let line = m.kind == .engine ? sentence : "\(m.title) — \(sentence)"
                guard !used.contains(line), !result.contains(line) else { continue }
                if DoitStudyCheck.checkSentence(line, basis: basis, label: "실수").isEmpty { result.append(line) }
            }
        }
        let concepts = materials.filter { $0.kind != .engine && $0.definition.count >= 10 }
        if result.count < limit, let a = concepts.first, let b = concepts.dropFirst().first(where: { independent(a, $0) }) {
            let pair = "\(josa("'\(a.title)'", "과", "와")) '\(b.title)'을(를) 섞어 쓰지 않게 구분해서 기억해요. \(a.title): \(shortDefinition(a)) / \(b.title): \(shortDefinition(b))"
            if DoitStudyCheck.checkSentence(pair, basis: basis, label: "실수").isEmpty { result.append(pair) }
        }
        return result
    }

    /// 확인 문제: 검증을 통과한 O/X 하나 (틀린 문장이 있으면 그것을 먼저 — 스스로 가려내 보게)
    static func ruleCheck(scope: StudyScope, materials: [DoitStudyMaterial], basis: DoitStudyCheck.Basis, concept: ConceptNote) -> (question: String, answer: String)? {
        let pack = StudyPack(scope: scope, materials: materials, basis: basis, concept: concept, madeByModel: false)
        let items = ruleOX(pack: pack, count: 4)
        guard let item = items.first(where: { !$0.isTrue }) ?? items.first else { return nil }
        let answer = (item.isTrue ? "O · " : "X · ") + item.explanation
        return (item.statement, answer)
    }

    /// 모델이나 규칙으로 만든 개념 정리에 원리 · 실수 · 확인 문제를 채움 (이미 있는 것은 그대로)
    static func enrich(_ note: ConceptNote, scope: StudyScope, materials: [DoitStudyMaterial], basis: DoitStudyCheck.Basis) -> ConceptNote {
        var result = note
        if result.principles.isEmpty { result.principles = rulePrinciples(materials: materials, basis: basis) }
        if result.mistakes.isEmpty { result.mistakes = ruleMistakes(materials: materials, basis: basis, avoiding: result.principles) }
        if result.checkQuestion.isEmpty, let check = ruleCheck(scope: scope, materials: materials, basis: basis, concept: result) {
            result.checkQuestion = check.question
            result.checkAnswer = check.answer
        }
        return result
    }
}
