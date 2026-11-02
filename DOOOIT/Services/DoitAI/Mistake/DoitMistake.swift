import Foundation

/// 오답 원인 분석 결과
struct MistakeAnalysis: Codable, Equatable {
    enum Cause: String, Codable, CaseIterable {
        case concept = "개념 이해 부족"
        case formula = "공식 암기 부족"
        case calculation = "계산 실수"
        case interpretation = "문제 해석 오류"
        case condition = "조건 누락"
        case process = "풀이 과정 오류"
        case careless = "단순 실수"
        // 수학이 아닌 과목 (직접 고르는 원인)
        case vocabulary = "단어 몰랐음"
        case grammar = "문법 몰랐음"
        case reading = "해석 실수"
        case choiceMix = "선지 착각"
        case memorization = "암기 부족"
        case time = "시간 부족"
        case other = "기타"
        case unknown = "판단 불가"

        /// 고르는 칩에 쓰는 짧은 이름
        var label: String { self == .concept ? "개념 몰랐음" : rawValue }
    }
    enum Certainty: String, Codable {
        /// 풀이 과정 등 직접 근거가 있음
        case confirmed = "확인됨"
        /// 답의 모양으로 짐작함
        case estimated = "추정"
        case unknown = "판단 불가"
    }
    var cause: Cause
    var certainty: Certainty
    /// 원인 설명
    var explanation: String
    /// 근거 (어떤 점을 보고 판단했는지)
    var evidence: [String]
    /// 놓친 핵심 개념
    var missedConcepts: [String]
    /// 올바른 풀이 방향
    var direction: String
    /// 추천 복습 내용
    var review: [String]
    /// 다음 학습 추천
    var next: [String]
    /// 유사 문제를 시작할 단계 (1~5)
    var startLevel: Int
}

/// 수학 문제 유형 → 개념 이름과 복습할 AI 학습 단원
enum DoitMathConceptMap {
    struct Info {
        let concept: String
        let subject: String
        let unit: String
    }

    static func info(for kind: MathSolver.Kind) -> Info? {
        switch kind {
        case .linear: return Info(concept: "일차방정식", subject: "중학교 수학", unit: "문자와 식")
        case .system: return Info(concept: "연립방정식", subject: "중학교 수학", unit: "연립일차방정식")
        case .quadraticEquation: return Info(concept: "이차방정식의 풀이", subject: "중학교 수학", unit: "이차방정식")
        case .vertex: return Info(concept: "이차함수의 최대·최소", subject: "공통수학1", unit: "이차방정식과 이차함수")
        case .rootRelation: return Info(concept: "근과 계수의 관계", subject: "공통수학1", unit: "복소수와 이차방정식")
        case .complex: return Info(concept: "복소수", subject: "공통수학1", unit: "복소수와 이차방정식")
        case .remainder: return Info(concept: "나머지정리", subject: "공통수학1", unit: "항등식과 나머지정리")
        case .expression: return Info(concept: "다항식의 연산", subject: "공통수학1", unit: "다항식의 연산")
        case .factor: return Info(concept: "인수분해", subject: "공통수학1", unit: "인수분해")
        case .higherEquation: return Info(concept: "삼차·사차방정식", subject: "공통수학1", unit: "여러 가지 방정식과 부등식")
        case .inequality, .absolute: return Info(concept: "부등식", subject: "공통수학1", unit: "여러 가지 방정식과 부등식")
        case .counting: return Info(concept: "경우의 수", subject: "공통수학1", unit: "순열과 조합")
        case .function: return Info(concept: "합성함수와 역함수", subject: "공통수학2", unit: "합성함수와 역함수")
        case .coordinate: return Info(concept: "좌표와 직선", subject: "공통수학2", unit: "두 직선의 평행과 수직")
        case .circle: return Info(concept: "원의 방정식", subject: "공통수학2", unit: "원의 방정식")
        case .sets: return Info(concept: "집합", subject: "공통수학2", unit: "집합의 연산")
        case .derivative: return Info(concept: "미분", subject: "고등학교 수학", unit: "미분")
        case .integral: return Info(concept: "적분", subject: "고등학교 수학", unit: "적분")
        case .sequence: return Info(concept: "수열", subject: "고등학교 수학", unit: "수열")
        case .statistics: return Info(concept: "통계", subject: "고등학교 수학", unit: "통계")
        case .numberTheory, .percent, .geometry, .calc: return nil
        }
    }
}

/// 오답 원인 분석: 제출 답 · 풀이 과정 · 정답 · 관련 개념을 비교. 근거가 부족하면 확정하지 않음
enum DoitMistake {
    struct Input {
        var problem: String
        var kind: ProblemKind
        var student: String
        var grade: GradeResult
        var choices: [String] = []
        var conditions: [String] = []
        /// 풀이 과정 채점 결과 (적었으면)
        var work: DoitWorkChecker.Report?
        /// 과목 (수학이 아니면 풀이 엔진을 쓰지 않음)
        var subject: NoteSubject = .math
    }

    static func analyze(_ input: Input) -> MistakeAnalysis? {
        let verdict = input.grade.verdict
        guard verdict == .wrong || verdict == .partial else { return nil }
        let math = input.subject.isMath
        let solved = math ? MathSolver.solve(input.problem) : nil
        let info = solved.flatMap { DoitMathConceptMap.info(for: $0.kind) }
        let concept = info?.concept ?? solved?.topic
        var analysis = MistakeAnalysis(cause: .unknown, certainty: .unknown, explanation: "", evidence: [],
                                       missedConcepts: concept.map { [$0] } ?? [], direction: direction(solved), review: [], next: [], startLevel: 2)

        // 1) 풀이 과정이 있으면 가장 확실한 근거
        if let work = input.work, !work.lines.isEmpty {
            if let index = work.firstWrongIndex, work.lines.indices.contains(index) {
                let line = work.lines[index]
                let earlierOK = work.lines.prefix(index).allSatisfy { $0.mark == .ok || $0.mark == .skipped }
                analysis.evidence.append("풀이 \(index + 1)번째 줄 '\(line.text)': \(line.note)")
                if line.note.contains("부호") || line.note.contains("계산") || line.note.contains("성립하지") {
                    set(&analysis, .calculation, .confirmed, "\(index + 1)번째 줄의 계산에서 틀렸어요. 그 앞까지는 바르게 풀었어요.")
                } else {
                    set(&analysis, .process, .confirmed, "\(index + 1)번째 줄에서 식을 바꾸는 과정이 틀렸어요." + (earlierOK ? " 그 앞 줄까지는 맞아요." : ""))
                }
            } else if work.finalCorrect == false {
                analysis.evidence.append("풀이 과정은 모두 맞지만 마지막 답이 달라요")
                set(&analysis, .careless, .confirmed, "풀이는 맞게 했는데 마지막에 답을 잘못 적었어요. 답을 옮겨 적을 때 한 번 더 확인해요.")
            }
        }

        // 2) 답의 모양으로 짐작 (수학)
        if analysis.cause == .unknown, math, input.kind == .math || input.kind == .multipleChoice {
            let studentValue = input.kind == .multipleChoice ? choiceValue(input.student, choices: input.choices) : input.student
            let answerText = solved?.answer ?? input.grade.answerUsed
            if let mine = studentValue.flatMap(DoitGrader.valueSet), let answer = DoitGrader.valueSet(answerText) ?? DoitGrader.valueSet(input.grade.answerUsed) {
                guessFromValues(mine: mine, answer: answer, solved: solved, conditions: input.conditions, into: &analysis)
            }
        }

        // 3) 단답형 (수학이 아닌 과목은 객관식도 고른 보기 글로): 다른 개념 이름과 헷갈림 / 철자
        let pickedText = !math && input.kind == .multipleChoice ? choiceValue(input.student, choices: input.choices) : nil
        let keyChoiceText = !math && input.kind == .multipleChoice ? choiceText(input.grade.answerUsed, choices: input.choices) : nil
        if analysis.cause == .unknown, input.kind == .shortAnswer || (pickedText != nil && keyChoiceText != nil) {
            let student = pickedText ?? input.student
            let key = keyChoiceText ?? (DoitGrader.alternatives(input.grade.answerUsed.replacingOccurrences(of: " / ", with: "|")).first ?? input.grade.answerUsed)
            if let other = DoitKnowledge.entry(named: student), DoitGrader.normalizeText(other.title) != DoitGrader.normalizeText(key) {
                analysis.evidence.append("적은 답 '\(student)'은(는) 다른 개념의 이름이에요")
                set(&analysis, .concept, .estimated, "'\(other.title)'과(와) '\(key)'을(를) 헷갈린 것 같아요. 두 개념의 차이를 다시 정리해요.")
                analysis.missedConcepts = [key, other.title]
                if let keyEntry = DoitKnowledge.entry(named: key) {
                    analysis.review.append("\(keyEntry.title): \(firstSentence(keyEntry.body))")
                }
                analysis.review.append("\(other.title): \(firstSentence(other.body))")
                analysis.direction = "문제에서 묻는 것이 '\(key)'의 특징인지 '\(other.title)'의 특징인지 구별해요."
            } else if let shared = sharedEntry(student, key) {
                // 같은 개념 설명에 함께 나오는 말 (예: 세포 소기관 속 '미토콘드리아'와 '엽록체')
                analysis.evidence.append("'\(student)'와(과) '\(key)'는 '\(shared.names.first ?? "")'에서 함께 배우는 말이에요")
                set(&analysis, .concept, .estimated, "'\(student)'와(과) '\(key)'를 헷갈린 것 같아요. 각각 무슨 일을 하는지 구별해서 정리해요.")
                analysis.missedConcepts = [key, student]
                analysis.review += DoitStudy.sentences(of: shared.body).filter { $0.contains(key) || $0.contains(student) }.prefix(3)
                analysis.direction = "'\(shared.names.first ?? key)'의 설명에서 '\(key)'의 역할을 다시 확인해요."
            } else if pickedText == nil, DoitGrader.editDistance(DoitGrader.normalizeText(student), DoitGrader.normalizeText(key)) <= 2, key.count >= 3 {
                analysis.evidence.append("정답과 한두 글자만 달라요")
                set(&analysis, .careless, .estimated, "거의 맞았어요. 철자나 글자를 한 번 더 확인해요.")
            } else if let keyEntry = DoitKnowledge.entry(named: key) {
                analysis.missedConcepts = [keyEntry.title]
                analysis.review.append("\(keyEntry.title): \(firstSentence(keyEntry.body))")
                analysis.direction = "'\(keyEntry.title)'의 뜻을 다시 확인해요: \(firstSentence(keyEntry.body))"
            }
        }

        // 4) 서술형: 빠진 핵심 내용
        if analysis.cause == .unknown, input.kind == .essay {
            let missed = input.grade.reasons.filter { $0.hasPrefix("✗ 빠짐: ") }.map { String($0.dropFirst("✗ 빠짐: ".count)) }
            if !missed.isEmpty {
                analysis.evidence.append("모범 답안의 핵심 내용 \(missed.count)개가 빠졌어요")
                set(&analysis, .concept, .estimated, "답에 꼭 들어가야 할 핵심 내용이 빠졌어요.")
                analysis.missedConcepts = missed
                analysis.review = missed.map { "빠진 내용: \($0)" }
            }
        }

        // 5) 그래도 모르면: 확정하지 않음
        if analysis.cause == .unknown {
            analysis.explanation = math ? "답만으로는 왜 틀렸는지 알 수 없어요. 아래 '풀이 과정 채점'에 풀이를 적으면 어디서 틀렸는지 찾아 드릴게요."
                : "왜 틀렸는지 골라 주세요."
            analysis.certainty = .unknown
        }

        // 복습·다음 학습
        if let info {
            analysis.review.append("AI 학습 › \(info.subject) · \(info.unit)에서 개념 다시 보기")
        }
        if let solved {
            analysis.review.insert("핵심 개념: \(solved.concept)", at: 0)
        }
        analysis.startLevel = [.concept, .formula].contains(analysis.cause) ? 1 : 2
        analysis.next = math ? nextSteps(for: analysis) : ["개념 카드 다시 보기", "내일 다시 풀기"]
        return analysis
    }

    /// 두 낱말이 함께 나오는 교육과정 개념 (같은 내용을 배울 때 헷갈리기 쉬운 짝)
    static func sharedEntry(_ a: String, _ b: String) -> CurriculumEntry? {
        let x = a.trimmingCharacters(in: .whitespaces), y = b.trimmingCharacters(in: .whitespaces)
        guard x.count >= 2, y.count >= 2, DoitGrader.normalizeText(x) != DoitGrader.normalizeText(y) else { return nil }
        for (_, entries) in DoitCurriculum.bySubject {
            if let hit = entries.first(where: { $0.body.contains(x) && $0.body.contains(y) }) { return hit }
        }
        return nil
    }

    private static func set(_ a: inout MistakeAnalysis, _ cause: MistakeAnalysis.Cause, _ certainty: MistakeAnalysis.Certainty, _ text: String) {
        a.cause = cause
        a.certainty = certainty
        a.explanation = text
    }

    /// 답의 값으로 짐작: 부호 반대, 해 일부만, 조건 밖의 해, 풀이 중간값, 자리 바뀜
    static func guessFromValues(mine: [Double], answer: [Double], solved: MathSolver.Solved?, conditions: [String], into a: inout MistakeAnalysis) {
        func same(_ x: Double, _ y: Double) -> Bool { abs(x - y) < 1e-6 }
        // 부호만 반대
        if mine.count == answer.count, zip(mine.sorted(), answer.map { -$0 }.sorted()).allSatisfy(same), answer.contains(where: { abs($0) > 1e-9 }) {
            a.evidence.append("답의 크기는 같고 부호만 반대예요")
            set(&a, .calculation, .estimated, "부호를 반대로 계산한 것 같아요. 이항하거나 괄호를 풀 때 부호를 확인해요.")
            return
        }
        // 해를 일부만 구함
        if mine.count < answer.count, mine.allSatisfy({ m in answer.contains { same($0, m) } }) {
            a.evidence.append("해 \(answer.count)개 중 \(mine.count)개만 적었어요")
            set(&a, .process, .estimated, "해를 일부만 구했어요. 인수분해한 뒤 모든 인수를 0으로 놓아 해를 빠짐없이 구해요.")
            return
        }
        // 조건 밖의 해까지 적음
        if mine.count > answer.count, answer.allSatisfy({ x in mine.contains { same($0, x) } }) {
            let extra = mine.filter { m in !answer.contains { same($0, m) } }.map(DoitMath.fraction)
            if let condition = conditions.first {
                a.evidence.append("조건 '\(condition)'에 맞지 않는 값(\(extra.joined(separator: ", ")))까지 답에 넣었어요")
                set(&a, .condition, .estimated, "문제의 조건을 확인하지 않은 것 같아요. 구한 값이 조건에 맞는지 마지막에 꼭 확인해요.")
            } else {
                a.evidence.append("정답 외의 값(\(extra.joined(separator: ", ")))이 더 있어요")
                set(&a, .process, .estimated, "답이 아닌 값이 섞였어요. 구한 해를 원래 식에 넣어 확인해요.")
            }
            return
        }
        // 풀이 중간에 나오는 값 → 묻는 것을 잘못 이해했을 가능성
        if let solved, mine.count == 1, let value = mine.first {
            let middle = solved.steps.flatMap { DoitMathTopics.numbers(in: $0.work) }
            if middle.contains(where: { same($0, value) }) && !answer.contains(where: { same($0, value) }) {
                a.evidence.append("적은 값 \(DoitMath.fraction(value))은(는) 풀이 중간에 나오는 값이에요")
                set(&a, .interpretation, .estimated, "문제가 묻는 값이 아니라 풀이 중간의 값을 답으로 적은 것 같아요. 무엇을 구하라는지 다시 읽어요.")
                return
            }
        }
        // 숫자 자리가 바뀜 (12 ↔ 21), 10배 차이
        if mine.count == 1, answer.count == 1, let m = mine.first, let x = answer.first, m != x {
            let ms = String(Int(abs(m))), xs = String(Int(abs(x)))
            if m == m.rounded(), x == x.rounded(), ms.count >= 2, ms.sorted() == xs.sorted() {
                a.evidence.append("숫자는 같고 자리만 바뀌었어요 (\(ms) ↔ \(xs))")
                set(&a, .careless, .estimated, "숫자를 옮겨 적다 자리가 바뀐 것 같아요.")
                return
            }
            if x != 0, [10.0, 0.1, 100, 0.01].contains(where: { abs(m / x - $0) < 1e-9 }) {
                a.evidence.append("정답과 10배 차이가 나요")
                set(&a, .calculation, .estimated, "소수점이나 단위 계산에서 실수한 것 같아요.")
                return
            }
        }
    }

    /// 채점 결과의 정답 표시("3번 (went)")에서 보기 글
    private static func choiceText(_ answerUsed: String, choices: [String]) -> String? {
        guard let m = answerUsed.firstMatch(of: #/^(\d+)번/#), let n = Int(m.1), choices.indices.contains(n - 1) else { return nil }
        return choices[n - 1]
    }

    private static func choiceValue(_ student: String, choices: [String]) -> String? {
        guard let n = DoitGrader.choiceNumber(student, choices: choices), choices.indices.contains(n - 1) else { return nil }
        return choices[n - 1]
    }

    private static func direction(_ solved: MathSolver.Solved?) -> String {
        guard let solved else { return "" }
        let first = solved.steps.first.map { " 먼저 \($0.hint)" } ?? ""
        return "\(solved.concept)\(first)"
    }

    private static func nextSteps(for a: MistakeAnalysis) -> [String] {
        var list: [String] = []
        switch a.cause {
        case .concept, .formula:
            list.append("개념 다시 보기 → 유사 문제 1단계(개념 확인)부터 풀기")
        case .calculation, .careless:
            list.append("유사 문제 2단계부터 풀면서 계산을 한 줄씩 적어 보기")
        case .condition, .interpretation:
            list.append("문제에서 조건과 묻는 것에 밑줄 긋고 유사 문제 3단계 풀기")
        case .process:
            list.append("틀린 줄부터 다시 풀어 보고 유사 문제 2단계부터 풀기")
        case .vocabulary, .grammar, .reading, .choiceMix, .memorization, .time:
            list.append("개념 다시 보기 → 원래 문제 다시 풀기")
        case .other, .unknown:
            list.append("풀이 과정을 적어서 어디서 틀렸는지 확인하기")
            list.append("유사 문제 2단계부터 풀기")
        }
        list.append("같은 개념을 2~3일 뒤에 한 번 더 풀어 보기 (한 번 맞혔다고 끝이 아니에요)")
        return list
    }

    private static func firstSentence(_ text: String) -> String {
        DoitStudy.sentences(of: text.components(separatedBy: "예:")[0]).first ?? String(text.prefix(80))
    }
}

/// 단계별 풀이 다듬기: 풀이 엔진의 단계에 "쓰는 개념·이유·다음 단계"를 붙임 (확실한 경우에만, 없는 조건을 만들지 않음)
enum DoitSolutionWriter {
    static func write(_ solved: MathSolver.Solved) -> WrittenSolution {
        var steps = solved.steps
        for i in steps.indices {
            let text = steps[i].hint + " " + steps[i].work
            if steps[i].concept.isEmpty { steps[i].concept = concept(in: text) ?? (i == 0 ? solved.concept : "") }
            if steps[i].reason.isEmpty { steps[i].reason = reason(for: text) ?? "" }
            steps[i].next = i + 1 < steps.count ? "다음: \(steps[i + 1].hint)" : "→ 답: \(solved.answer)"
        }
        return WrittenSolution(concept: solved.concept, steps: steps, finalAnswer: solved.answer)
    }

    /// 단계에 나온 공식 이름
    static func concept(in text: String) -> String? {
        let table: [(String, String)] = [
            ("근의 공식", "근의 공식: ax² + bx + c = 0 의 해는 x = (−b ± √(b² − 4ac)) / 2a"),
            ("판별식", "판별식 D = b² − 4ac (D > 0 서로 다른 두 실근, D = 0 중근, D < 0 허근)"),
            ("근과 계수", "근과 계수의 관계: α + β = −b/a, αβ = c/a"),
            ("나머지정리", "나머지정리: f(x)를 x − a로 나눈 나머지는 f(a)"),
            ("인수정리", "인수정리: f(a) = 0 이면 x − a는 f(x)의 인수"),
            ("완전제곱", "완전제곱식: a(x − p)² + q 꼴로 바꾸면 꼭짓점 (p, q)"),
            ("인수분해", "인수분해: AB = 0 이면 A = 0 또는 B = 0"),
            ("이항", "등식의 성질: 양변에 같은 수를 더하거나 빼도 등식은 성립"),
            ("미분", "미분: (xⁿ)′ = n·xⁿ⁻¹"),
            ("적분", "적분: ∫xⁿ dx = xⁿ⁺¹/(n + 1) + C"),
            ("조립제법", "조립제법: 일차식으로 나누는 나눗셈을 계수만으로 계산")
        ]
        return table.first { text.contains($0.0) }?.1
    }

    /// 이 작업을 하는 이유 (알려진 풀이 방법일 때만)
    static func reason(for text: String) -> String? {
        let table: [(String, String)] = [
            ("이항", "미지수가 있는 항과 수를 양쪽으로 나눠 x만 남기려고 해요."),
            ("옮기", "미지수가 있는 항과 수를 양쪽으로 나눠 x만 남기려고 해요."),
            ("인수분해", "곱이 0이면 둘 중 하나는 0이라는 성질로 해를 쉽게 구하려고 해요."),
            ("근의 공식", "인수분해가 어려울 때도 항상 해를 구할 수 있는 방법이라서요."),
            ("판별식", "근을 직접 구하지 않고도 근의 개수와 종류를 알 수 있어서요."),
            ("완전제곱", "꼭짓점(최대·최소)을 식에서 바로 읽으려고 해요."),
            ("전개", "괄호를 풀어 같은 차수의 항끼리 모아야 계산할 수 있어서요."),
            ("정리", "같은 차수의 항끼리 모아야 다음 계산이 쉬워져요."),
            ("대입", "구한 값이나 주어진 값을 넣어 확인하거나 계산하려고 해요."),
            ("나머지정리", "직접 나누지 않고 f(a)만 계산하면 나머지를 알 수 있어서요."),
            ("미분", "기울기(순간 변화율)를 구하려면 도함수가 필요해서요."),
            ("적분", "넓이나 원래 함수를 구하려면 적분이 필요해서요.")
        ]
        return table.first { text.contains($0.0) }?.1
    }
}
