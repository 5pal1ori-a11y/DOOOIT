import Foundation

// MARK: - 영어 문법 단원 (DoitGrammar): 단원마다 개념 + 검증된 문제 15개 이상, 정답 하나, 문장 어법 검사, 검색으로 찾기

func runEnglishCurriculumCases() async {
    let units = DoitGrammar.units
    check("영문법 단원 수 (초등·중·고)", units.count >= 40, "\(units.count)개")
    let levels = Set(units.map(\.level))
    check("영문법 단원: 초등·중학교·고등학교 모두", levels == [.elementary, .middle, .high], "\(levels)")

    var keys = Set<String>()
    var allQuestions: [String: String] = [:]
    var flagged: [String] = []
    var wrongCaught = 0, wrongTotal = 0
    for unit in units {
        let tag = "영문법 \(unit.subjectName) · \(unit.name)"
        check("\(tag): 단원 이름 겹치지 않음", keys.insert(unit.key).inserted)
        // 개념 정리
        check("\(tag): 개념 정리 (요약 · 포인트 3개 이상 · 예문 2개 이상 · 함정)",
              !unit.summary.isEmpty && unit.points.count >= 3 && unit.examples.count >= 2 && !unit.traps.isEmpty,
              "포인트 \(unit.points.count), 예문 \(unit.examples.count), 함정 \(unit.traps.count)")
        check("\(tag): 예문마다 해석", unit.examples.allSatisfy { $0.contains("→") })
        check("\(tag): 문제 15개 이상", unit.items.count >= 15, "\(unit.items.count)개")
        let kinds = Set(unit.items.map(\.kind))
        check("\(tag): 문제 종류 3가지 이상 섞임", kinds.count >= 3, "\(kinds)")
        check("\(tag): 객관식·O/X·고치기 모두 있음", kinds.contains(.fix) && (kinds.contains(.ox) || kinds.contains(.rule))
              && (kinds.contains(.blank) || kinds.contains(.transform) || kinds.contains(.meaning)), "\(kinds)")

        var seen = Set<String>()
        for item in unit.items {
            let label = "\(tag) [\(item.kind.rawValue)] \(item.text.prefix(50))"
            check("\(label): 해설 있음", !item.note.isEmpty)
            check("\(label): 중복 아님", seen.insert(item.kind.rawValue + "|" + item.text + "|" + (item.from ?? "")).inserted)
            switch item.kind {
            case .blank, .transform, .meaning:
                let choices = DoitGrammar.choiceList(item)
                check("\(label): 정답이 보기에 한 번", choices.filter { $0 == item.answer }.count == 1, "\(choices)")
                check("\(label): 오답 보기 2개 이상 · 서로 다름 · 정답과 다름",
                      item.wrong.count >= 2 && Set(item.wrong.map { $0.lowercased() }).count == item.wrong.count
                      && !item.wrong.contains { $0.lowercased() == item.answer.lowercased() }, "\(item.wrong)")
                if item.kind != .meaning {
                    check("\(label): 빈칸 하나", item.text.components(separatedBy: DoitGrammar.blankMark).count == 2)
                }
                if item.kind == .transform { check("\(label): 원래 문장 있음", !(item.from ?? "").isEmpty) }
            case .fix:
                check("\(label): 틀린 부분이 문장에 한 번", item.wrong.count == 1 && DoitGrammar.corrected(item) != nil, "\(item.wrong)")
                check("\(label): 고친 표현이 다름", item.wrong.first != item.answer)
            case .order:
                let words = DoitGrammar.tokens(item.text)
                check("\(label): 배열 낱말 4개 이상 · 쉼표 없음", words.count >= 4 && !item.text.contains(","))
                check("\(label): 섞은 순서는 원래와 다름", DoitGrammar.scrambled(item) != words)
                check("\(label): 섞어도 같은 낱말", DoitGrammar.scrambled(item).sorted() == words.sorted())
            case .ox, .rule:
                check("\(label): 답은 O 또는 X", item.answer == "O" || item.answer == "X")
            }
            // 바른 문장으로 둔 문장은 문장 검사기가 틀렸다고 하지 않아야 함
            for sentence in DoitGrammar.correctSentences(item) {
                if let issue = DoitSentenceCheck.error(in: sentence) { flagged.append("\(unit.name): \(sentence) — \(issue.rule): \(issue.why)") }
            }
            for sentence in DoitGrammar.wrongSentences(item) {
                wrongTotal += 1
                if DoitSentenceCheck.error(in: sentence) != nil { wrongCaught += 1 }
            }
        }

        // 화면 단계로 바꾼 것
        let list = [unit]
        let problems = DoitGrammar.problems(list)
        check("\(tag): 객관식 문제 6개 이상", problems.count >= 6, "\(problems.count)개")
        for p in problems {
            let label = "\(tag) 문제: \(p.question.prefix(40))"
            check("\(label): 정답 번호가 보기 안", p.answerNumber >= 1 && p.answerNumber <= p.choices.count)
            check("\(label): 보기 3~5개 · 겹치지 않음", (3...5).contains(p.choices.count) && Set(p.choices).count == p.choices.count, "\(p.choices)")
            check("\(label): 해설 있음", !p.steps.isEmpty && !p.finalAnswer.isEmpty)
            let key = p.question + "|" + p.choices.joined(separator: "/")
            if let other = allQuestions[key], other != unit.key { check("\(label): 다른 단원과 같은 문제 없음", false, other) }
            allQuestions[key] = unit.key
        }
        check("\(tag): 빈칸 쓰기 4개 이상", DoitGrammar.clozeItems(list).count >= 4, "\(DoitGrammar.clozeItems(list).count)개")
        let ox = DoitGrammar.oxItems(list)
        check("\(tag): O/X 6개 이상 (O·X 모두)", ox.count >= 6 && ox.contains { $0.isTrue } && ox.contains { !$0.isTrue }, "\(ox.count)개")
        // 빈칸 쓰기: 정답을 그대로 적으면 맞고, 오답 보기를 적으면 틀림
        for item in unit.items where item.kind == .blank || item.kind == .transform {
            let cloze = DoitGrammar.answerText(item)
            check("\(tag) 빈칸 채점: '\(item.answer)' 정답", DoitStudy.clozeMatches(item.answer, answer: cloze))
            for wrong in item.wrong {
                check("\(tag) 빈칸 채점: '\(wrong)'은 오답 (정답 \(item.answer))", !DoitStudy.clozeMatches(wrong, answer: cloze))
            }
        }
        // 모의고사 문제: 정답을 넣으면 채점기가 정답이라고 함
        let practice = DoitGrammar.practiceItems(list, concept: unit.name)
        let unverified = practice.filter { !DoitMockExam.verified($0) }
        // 단답: 오답 보기를 적으면 정답이 아님
        for item in unit.items where item.kind == .blank || item.kind == .transform {
            guard let p = practice.first(where: { $0.kind == .shortAnswer && $0.question.hasSuffix(DoitGrammar.blankPrompt(item)) }) else { continue }
            for wrong in item.wrong where DoitPractice.grade(p, answer: wrong).verdict == .correct {
                check("\(tag) 모의고사 단답: '\(wrong)'은 오답", false, p.question)
            }
        }
        check("\(tag): 모의고사 문제 모두 채점 확인", unverified.isEmpty, unverified.prefix(3).map { "\($0.question.prefix(40)) → \($0.answer)" }.joined(separator: " | "))
    }
    check("영문법: 바른 문장으로 둔 문장은 문장 검사기가 틀렸다고 하지 않음", flagged.isEmpty, "\(flagged.count)개: " + flagged.prefix(25).joined(separator: "\n    "))
    print("영문법: 틀린 문장 \(wrongTotal)개 중 문장 검사기가 찾은 것 \(wrongCaught)개")

    // 표로 만든 문제: 표와 영어 엔진이 같은 모양이라고 함
    for (base, third, _) in DoitGrammar.thirdPersonTable {
        check("표 확인: \(base) → \(third)", DoitEnglish.thirdPerson(base) == third, DoitEnglish.thirdPerson(base))
    }
    for (base, past, pp, _) in DoitGrammar.pastTable {
        check("표 확인: \(base) → \(past)", DoitEnglish.pastForms(base).contains(past), "\(DoitEnglish.pastForms(base))")
        check("표 확인: \(base) p.p. → \(pp)", DoitEnglish.ppForms(base).contains(pp), "\(DoitEnglish.ppForms(base))")
    }
    for (adj, comp, sup, _, _) in DoitGrammar.comparisonTable {
        let forms = DoitEnglish.comparison(adj)
        check("표 확인: \(adj) → \(comp)", forms.comparative.contains(comp), "\(forms.comparative)")
        check("표 확인: \(adj) → \(sup)", forms.superlative.contains(sup), "\(forms.superlative)")
    }
    // 복수형: 불규칙은 영어 엔진의 불규칙 표, 규칙은 규칙대로 (s·x·sh·ch → -es, 자음 + y → -ies, f(e) → -ves, o → -es/-s)
    func rulePlural(_ n: String) -> [String] {
        if n.hasSuffix("fe") { return [String(n.dropLast(2)) + "ves"] }
        if n.hasSuffix("f") { return [String(n.dropLast()) + "ves"] }
        if n.hasSuffix("y"), let c = n.dropLast().last, !"aeiou".contains(c) { return [String(n.dropLast()) + "ies"] }
        if ["s", "x", "sh", "ch"].contains(where: { n.hasSuffix($0) }) { return [n + "es"] }
        if n.hasSuffix("o") { return [n + "es", n + "s"] }
        return [n + "s"]
    }
    for (noun, plural, _) in DoitGrammar.pluralTable {
        let ok = DoitEnglish.singular(ofIrregular: plural) == noun || rulePlural(noun).contains(plural)
        check("표 확인: \(noun) → \(plural)", ok, "\(rulePlural(noun))")
    }
    let templated = units.flatMap(\.items).filter(\.templated)
    check("표로 만든 문제 있음", templated.count >= 40, "\(templated.count)개")

    // 화면 흐름: 개념 → 빈칸 → O/X → 문제 (모델 없이)
    for unit in units {
        let tag = "영문법 흐름 \(unit.subjectName) · \(unit.name)"
        do {
            let note = try await DoitTutor.concept(subject: unit.subjectName, unit: unit.name, booster: false)
            check("\(tag): 개념은 문법 단원 자료", note.title == unit.name && note.keyPoints == unit.points && note.sources == [DoitGrammar.source], note.title)
            let cloze = try await DoitTutor.cloze(subject: unit.subjectName, unit: unit.name, count: 6)
            check("\(tag): 빈칸 6개 이하 · 1개 이상", (1...6).contains(cloze.items.count), "\(cloze.items.count)")
            let ox = try await DoitTutor.ox(subject: unit.subjectName, unit: unit.name, count: 6)
            check("\(tag): O/X 6개", ox.items.count == 6, "\(ox.items.count)")
            let problems = try await DoitTutor.problems(subject: unit.subjectName, unit: unit.name, count: 4, hard: true)
            check("\(tag): 문제 4개", problems.items.count == 4, "\(problems.items.count)")
        } catch {
            check("\(tag): 학습 자료 만들기", false, error.localizedDescription)
        }
    }

    // 검색: 단원 이름과 흔한 다른 이름으로
    func found(_ query: String, _ unitName: String, level: SchoolLevel? = nil) -> Bool {
        switch DoitStudy.resolve(subject: "", unit: query) {
        case .resolved(let scope): return scope.unit == unitName && (level == nil || scope.level == level)
        case .ambiguous(let options): return options.contains { $0.unit == unitName && (level == nil || $0.level == level) }
        case .notFound: return false
        }
    }
    func resolvedUnit(_ query: String) -> String {
        switch DoitStudy.resolve(subject: "", unit: query) {
        case .resolved(let scope): return scope.label
        case .ambiguous(let options): return "여럿: " + options.map(\.label).joined(separator: ", ")
        case .notFound(let message, _): return "못 찾음: \(message.prefix(40))"
        }
    }
    for unit in units {
        check("영문법 검색: '\(unit.name)'", found(unit.name, unit.name, level: unit.level), resolvedUnit(unit.name))
        let prefix = unit.level == .elementary ? "초등" : unit.level == .middle ? "중학교" : "고등학교"
        check("영문법 검색: '\(prefix) 영어 \(unit.name)'", found("\(prefix) 영어 \(unit.name)", unit.name, level: unit.level), resolvedUnit("\(prefix) 영어 \(unit.name)"))
        for alias in unit.aliases.prefix(3) {
            check("영문법 검색: '\(alias)' → \(unit.name)", found(alias, unit.name), resolvedUnit(alias))
        }
        check("영문법 단원이 AI 학습 목록에 있음: \(unit.name)",
              DoitCurriculum.studySubjects.contains { $0.name == unit.subjectName && $0.units.contains(unit.name) })
    }
    let named: [(String, String)] = [("현재완료", "현재완료"), ("관계대명사", "관계대명사"), ("중2 수동태", "수동태"), ("to부정사", "to부정사"),
                                     ("가정법", "가정법"), ("중3 가정법", "가정법"), ("동명사", "동명사"), ("분사구문", "분사와 분사구문"),
                                     ("be동사", "be동사"), ("3인칭 단수", "일반동사"), ("There is", "There is/are"), ("관계부사", "관계부사"),
                                     ("간접의문문", "간접의문문"), ("수일치", "수일치 심화"), ("도치", "도치"), ("가정법 심화", "가정법")]
    for (query, unit) in named {
        check("영문법 검색: '\(query)' → \(unit)", found(query, unit), resolvedUnit(query))
    }
    for query in ["영어 문법", "영문법", "중학교 영어 문법", "고등 영어 어법"] {
        if case .ambiguous(let options) = DoitStudy.resolve(subject: "", unit: query) {
            check("영문법 검색: '\(query)' → 문법 단원 고르기", options.allSatisfy { DoitGrammar.isGrammarUnit(subjectName: $0.subjectName, unit: $0.unit) }, "\(options.map(\.label))")
        } else {
            check("영문법 검색: '\(query)' → 문법 단원 고르기", false, resolvedUnit(query))
        }
    }
    // 목록 검색(낱말이 모두 들어간 단원)으로도 "영어 문법"이 나옴
    // (화면의 Curriculum.subjects와 같은 방법: 문법 단원의 chapter = 과목 이름 + " · 영문법")
    let listed = DoitCurriculum.studySubjects.flatMap { s in s.units.filter { unit in
        let chapter = DoitGrammar.isGrammarUnit(subjectName: s.name, unit: unit) ? s.name + " · 영문법" : s.name
        let haystack = "\(s.name) \(chapter) \(unit)"
        return haystack.contains("영어") && haystack.contains("문법")
    } }
    check("영문법 목록 검색: '영어 문법'으로 단원이 나옴", listed.count >= 30, "\(listed.count)개")
    // 다른 과목 검색은 그대로
    check("영문법 추가 후에도 수학 검색 그대로", found("중2 일차함수", "일차함수와 그래프"), resolvedUnit("중2 일차함수"))

    // 공통영어 어법 단원도 문법 문제로
    for unit in ["시제와 태", "관계사", "분사와 분사구문", "가정법"] {
        check("공통영어 '\(unit)' → 문법 단원 문제", !DoitGrammar.units(subjectName: "공통영어", unit: unit).isEmpty)
    }

    // 모의고사: 영어 문법 단원에서 검증된 문제로
    let sources = units.prefix(12).map { MockExamSource(key: "영어|\($0.name)|\($0.name)", subject: "영어", unit: $0.name, concept: $0.name, mastery: 0.2, wrongCount: 2) }
    let exam = DoitMockExam.assemble(weak: Array(sources), scope: .english)
    check("모의고사 영어 문법: 10문제", exam.questions.count == DoitMockExam.size, "\(exam.questions.count)")
    check("모의고사 영어 문법: 모두 정답 확인", exam.questions.allSatisfy { DoitMockExam.isCorrect($0, answer: $0.item.answer) && DoitMockExam.isCorrect($0, answer: $0.isChoice ? $0.item.answer : DoitMockExam.answerText($0.item)) })
    check("모의고사 영어 문법: 객관식·단답 섞임", exam.questions.contains { $0.isChoice } && exam.questions.contains { !$0.isChoice })
    let fallback = DoitMockExam.assemble(weak: [], scope: .english)
    check("모의고사 영어 (취약 개념 없음): 공통영어 단원에서 문제", fallback.questions.count >= 5, "\(fallback.questions.count)")
}
