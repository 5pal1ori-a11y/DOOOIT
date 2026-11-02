import Foundation

// MARK: - 모든 과목 오답노트: 과목 판단 · 채점(영어·국어·O/X) · 과목별 원인 · 개념 찾기 · 다시 풀기

func runMistakeSubjectCases() {
    // 1) 과목 (예전 노트는 비어 있어서 수학)
    let subjects: [(String, NoteSubject)] = [("", .math), ("수학", .math), ("공통수학1", .math), ("중학교 수학", .math), ("영어", .english),
                                             ("중학교 과학", .science), ("고등학교 사회", .social), ("한국사", .social), ("국어", .korean),
                                             ("문학", .korean), ("미술", .other), ("기타", .other)]
    for (stored, expected) in subjects {
        check("과목: '\(stored)' → \(expected.rawValue)", NoteSubject.from(stored) == expected, NoteSubject.from(stored).rawValue)
    }

    // 2) 채점
    func g(_ kind: ProblemKind, _ student: String, _ key: String, _ subject: NoteSubject, choices: [String] = [], problem: String = "") -> GradeResult.Verdict {
        DoitGrader.grade(.init(kind: kind, student: student, answerKey: key, choices: choices, problem: problem, subject: subject)).verdict
    }
    check("영어 채점: 대소문자·마침표 무시", g(.shortAnswer, "Went.", "went", .english) == .correct)
    check("영어 채점: 축약형 = 풀어 쓴 말", g(.shortAnswer, "don't", "do not", .english) == .correct)
    check("영어 채점: can't = cannot", g(.shortAnswer, "Can't", "cannot", .english) == .correct)
    check("영어 채점: 띄어쓰기·쉼표 무시", g(.shortAnswer, "Yes, I  do", "yes I do.", .english) == .correct)
    check("영어 채점: 곱슬 따옴표", g(.shortAnswer, "I’m", "I am", .english) == .correct)
    check("영어 채점: 복수 정답", g(.shortAnswer, "which", "that | which", .english) == .correct)
    check("영어 채점: 틀린 형태는 오답", g(.shortAnswer, "goed", "went", .english) == .wrong)
    check("영어 채점: 철자 한 글자 차이는 확인 요청", g(.shortAnswer, "recieve", "receive", .english) == .needsReview)
    check("영어 채점: 다른 단어는 오답", g(.shortAnswer, "who", "which", .english) == .wrong)
    let verbs = ["go", "goes", "went", "going", "gone"]
    check("영어 객관식: 보기 글로 답해도", g(.multipleChoice, "Went", "③", .english, choices: verbs) == .correct)
    check("영어 객관식: 번호 오답", g(.multipleChoice, "5", "③", .english, choices: verbs) == .wrong)
    check("국어 채점: 끝말 정리", g(.shortAnswer, "은유법이다", "은유법", .korean) == .correct)
    check("국어 채점: 띄어쓰기 무시", g(.shortAnswer, "세종 대왕", "세종대왕", .social) == .correct)
    check("과학 채점: 복수 정답(또는)", g(.shortAnswer, "엽록체", "엽록체 또는 클로로플라스트", .science) == .correct)
    check("O/X 채점: 소문자 o", g(.shortAnswer, "o", "O", .science) == .correct)
    check("O/X 채점: 맞다 = O", g(.shortAnswer, "맞다", "O", .social) == .correct)
    check("O/X 채점: X ≠ O", g(.shortAnswer, "X", "O", .social) == .wrong)
    check("O/X 채점: ○ × 기호", g(.shortAnswer, "×", "X", .korean) == .correct)
    check("과목 채점: 정답이 없으면 풀이 엔진으로 지어내지 않음",
          g(.multipleChoice, "2", "", .science, choices: ["3", "4", "5", "6", "7"], problem: "2 + 3 = ?") == .needsReview)
    check("수학 채점은 그대로: 정답 없으면 직접 풀기", g(.math, "x = 4", "", .math, problem: "2x + 3 = 11") == .correct)

    // 3) 문제 나누기 (수학이 아닌 과목: 수식 찾기 없음, 영어 문장 그대로)
    let english = DoitProblemScan.scan("""
    다음 빈칸에 들어갈 말로 알맞은 것은?
    This is the book ___ I bought yesterday.
    ① who ② which ③ what ④ whose ⑤ whom
    정답: ②
    """, math: false)
    check("과목 인식: 선택지 5개", english.choices == ["who", "which", "what", "whose", "whom"], "\(english.choices)")
    check("과목 인식: 객관식", english.kind == .multipleChoice)
    check("과목 인식: 정답 표기", english.printedAnswer == "②", english.printedAnswer ?? "-")
    check("과목 인식: 수식 없음 (영어 문장을 수식으로 보지 않음)", english.formulas.isEmpty && !english.doubts.contains { $0.reason.contains("숫자 1") }, "\(english.formulas) \(english.doubts)")
    check("과목 인식: 영어 문장 그대로", english.body.contains("This is the book ___ I bought yesterday."), english.body)
    check("과목 인식: 단답형은 수학 계산으로 보지 않음", DoitProblemScan.scan("2 + 3 = ?", math: false).kind == .shortAnswer)
    check("정답 표기: '답을 고르시오'는 정답 아님", DoitSubjectNote.printedAnswer(in: "알맞은 답을 고르시오.") == nil)
    check("정답 표기: 정답 ③", DoitSubjectNote.printedAnswer(in: "문제\n정답 ③") == "③")
    check("정답 표기: 답: 광합성", DoitSubjectNote.printedAnswer(in: "답: 광합성") == "광합성")
    check("정답 표기: Answer: went", DoitSubjectNote.printedAnswer(in: "Answer: went") == "went")
    check("제목: 번호 떼고 첫 줄", DoitSubjectNote.title(from: "3. 다음 중 광합성에 대한 설명으로 옳은 것은?") == "다음 중 광합성에 대한 설명으로 옳은 것은?",
          DoitSubjectNote.title(from: "3. 다음 중 광합성에 대한 설명으로 옳은 것은?") ?? "-")
    let longTitle = DoitSubjectNote.title(from: "Read the passage below and choose the best title for it") ?? ""
    check("제목: 긴 영어 첫 줄은 낱말 단위로 자름", longTitle.count <= 24 && !longTitle.hasSuffix(" ") && "Read the passage below and".hasPrefix(longTitle), longTitle)
    check("O/X 문제 판단", DoitSubjectNote.isOXQuestion("맞으면 O, 틀리면 X를 쓰시오.", answerKey: "") && DoitSubjectNote.isOXQuestion("", answerKey: "X"))

    // 4) 과목별 오답 원인
    check("원인: 영어에는 단어·문법·해석", [.vocabulary, .grammar, .reading].allSatisfy { NoteSubject.english.causes.contains($0) })
    check("원인: 영어에는 공식 암기 없음", !NoteSubject.english.causes.contains(.formula) && !NoteSubject.english.causes.contains(.calculation))
    check("원인: 국어에는 해석 실수·선지 착각", NoteSubject.korean.causes.contains(.reading) && NoteSubject.korean.causes.contains(.choiceMix))
    check("원인: 과학에는 암기 부족·계산 실수", NoteSubject.science.causes.contains(.memorization) && NoteSubject.science.causes.contains(.calculation))
    check("원인: 사회에는 개념·시간 부족", NoteSubject.social.causes.contains(.concept) && NoteSubject.social.causes.contains(.time))
    check("원인: 수학은 예전 그대로", NoteSubject.math.causes.contains(.calculation) && NoteSubject.math.causes.contains(.formula) && !NoteSubject.math.causes.contains(.vocabulary))
    check("원인: 모든 과목에 시간 부족(수학 빼고)", NoteSubject.allCases.filter { !$0.isMath }.allSatisfy { $0.causes.contains(.time) })
    check("원인 이름: 개념 몰랐음", MistakeAnalysis.Cause.concept.label == "개념 몰랐음" && MistakeAnalysis.Cause.vocabulary.label == "단어 몰랐음")
    let picked = DoitSubjectNote.choose(.vocabulary, subject: .english, base: nil)
    check("원인 고르기: 직접 고른 원인은 확인됨", picked.cause == .vocabulary && picked.certainty == .confirmed && picked.explanation.contains("단어장"), picked.explanation)
    let oldJSON = #"{"cause":"계산 실수","certainty":"추정","explanation":"","evidence":[],"missedConcepts":[],"direction":"","review":[],"next":[],"startLevel":2}"#
    check("원인: 예전 분석 기록도 그대로 읽힘", (try? JSONDecoder().decode(MistakeAnalysis.self, from: Data(oldJSON.utf8)))?.cause == .calculation)

    // 5) 오답 원인 분석 (수학이 아닌 과목: 풀이 엔진 없이, 고른 보기 글로 헷갈린 개념 찾기)
    let cellChoices = ["핵", "엽록체", "미토콘드리아", "리보솜", "액포"]
    let cellGrade = DoitGrader.grade(.init(kind: .multipleChoice, student: "3", answerKey: "2", choices: cellChoices, subject: .science))
    let cell = DoitMistake.analyze(.init(problem: "광합성이 일어나는 세포 소기관은?", kind: .multipleChoice, student: "3", grade: cellGrade,
                                         choices: cellChoices, subject: .science))
    check("과학 원인: 헷갈린 개념(추정)", cell?.cause == .concept && cell?.certainty == .estimated, "\(String(describing: cell))")
    let unknownGrade = DoitGrader.grade(.init(kind: .shortAnswer, student: "turned", answerKey: "turn off", subject: .english))
    let unknown = DoitMistake.analyze(.init(problem: "Please ___ the light.", kind: .shortAnswer, student: "turned", grade: unknownGrade, subject: .english))
    check("영어 원인: 모르면 골라 달라고", unknown?.cause == .unknown && unknown?.explanation == "왜 틀렸는지 골라 주세요.", "\(String(describing: unknown))")

    // 6) 개념 찾기 (교육과정 사전에서, 문제에 나온 개념만)
    let science = DoitSubjectNote.concepts(problem: "다음 중 광합성이 일어나는 세포 소기관은?", choices: cellChoices, answer: "엽록체", subject: .science)
    check("개념(과학): 광합성·엽록체", science.contains { ["광합성", "엽록체"].contains($0.title) } && science.allSatisfy { $0.subject == "과학" }, science.map(\.title).description)
    let social = DoitSubjectNote.concepts(problem: "삼권 분립에 대한 설명으로 옳은 것은?\n① 국회는 법을 집행한다 ② 법원은 재판을 한다", subject: .social)
    check("개념(사회): 삼권 분립", social.first?.title == "삼권 분립", social.map(\.title).description)
    let demand = DoitSubjectNote.concepts(problem: "가격이 오르면 수요량은 어떻게 변하는가?", subject: .social)
    check("개념(사회): 수요", demand.contains { $0.names.contains("수요") || $0.title.contains("수요") }, demand.map(\.title).description)
    let grammar = DoitSubjectNote.concepts(problem: "다음 빈칸에 들어갈 관계대명사로 알맞은 것은?\nThis is the book ___ I bought yesterday.", choices: english.choices, subject: .english)
    check("개념(영어): 관계대명사", grammar.contains { $0.title.contains("관계대명사") } && grammar.allSatisfy { $0.subject == "영어" }, grammar.map(\.title).description)
    let korean = DoitSubjectNote.concepts(problem: "'내 마음은 호수요'에 쓰인 표현 방법은?", choices: ["직유법", "은유법", "의인법"], answer: "은유법", subject: .korean)
    check("개념(국어): 정답 개념 먼저", korean.first?.title == "은유법", korean.map(\.title).description)
    let longPassage = Array(repeating: "Some people like dogs and others like cats because another animal is", count: 4).joined(separator: " ")
    let noisy = DoitSubjectNote.concepts(problem: longPassage + "\n글의 주제로 알맞은 것은?", choices: ["pets", "food"], subject: .english)
    check("개념(영어): 긴 지문 속 낱말(others·another)은 개념 아님", !noisy.contains { $0.title.contains("대명사") }, noisy.map(\.title).description)
    check("개념: 다른 과목 개념은 안 섞임", DoitSubjectNote.concepts(problem: "광합성", subject: .social).allSatisfy { $0.subject == "사회" })

    // 7) 단어 (내 단어장 · 정답 단어 뜻)
    let book: [(term: String, meaning: String)] = [("abundant", "풍부한"), ("bought", "샀다"), ("apple", "사과"), ("look forward to", "~을 고대하다")]
    let hits = DoitSubjectNote.wordBookHits(text: "Water is Abundant here. I look forward to it. I bought it.", book: book)
    check("단어장: 문제에 나온 단어", Set(hits.map(\.term)) == ["abundant", "bought", "look forward to"], hits.map(\.term).description)
    check("단어장: 없는 단어는 안 나옴", !hits.contains { $0.term == "apple" })
    check("단어장: 단어 안의 글자는 아님", DoitSubjectNote.wordBookHits(text: "pineapples", book: book).isEmpty)
    let went = DoitSubjectNote.answerWordHints(answer: "went", choices: [], skip: [])
    check("정답 단어: went = go의 과거형", went.first?.term == "went" && (went.first?.meaning.contains("go") ?? false) && !(went.first?.inBook ?? true), went.description)

    // 8) 다시 풀기: 선택지 섞기 · 간격 복습
    for seed in [UInt64(0), 1, 42, 999] {
        let order = DoitSubjectNote.shuffledOrder(count: 5, seed: seed)
        check("섞기: 모든 보기 한 번씩 (seed \(seed))", order.sorted() == [0, 1, 2, 3, 4], order.description)
        check("섞기: 원래 순서와 다름 (seed \(seed))", order != [0, 1, 2, 3, 4], order.description)
    }
    check("섞기: 보기 하나면 그대로", DoitSubjectNote.shuffledOrder(count: 1, seed: 3) == [0])
    let calendar = Calendar(identifier: .gregorian)
    let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 9))!
    let first = DoitSubjectNote.reviewSchedule(start: start, retries: [], calendar: calendar)
    check("복습: 틀린 다음 날 다시", first.stage == 1 && first.next == calendar.date(from: DateComponents(year: 2026, month: 11, day: 2)), "\(first)")
    let day = { (d: Int) in calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: 10))! }
    let good = DoitSubjectNote.reviewSchedule(start: start, retries: [PracticeAttempt(level: 3, question: "원래 문제", given: "2", correct: true, date: day(2))], calendar: calendar)
    check("복습: 맞히면 3일 뒤", good.stage == 2 && good.next == calendar.date(from: DateComponents(year: 2026, month: 11, day: 5)), "\(good)")
    let again = DoitSubjectNote.reviewSchedule(start: start, retries: [PracticeAttempt(level: 3, question: "원래 문제", given: "2", correct: true, date: day(2)),
                                                                     PracticeAttempt(level: 3, question: "원래 문제", given: "3", correct: false, date: day(5))], calendar: calendar)
    check("복습: 다시 틀리면 다음 날부터", again.stage == 1 && again.next == calendar.date(from: DateComponents(year: 2026, month: 11, day: 6)), "\(again)")

    // 9) AI 해설 글: 확인된 정답을 넘겨 줌 (추측하지 않게)
    let prompt = DoitSubjectNote.explainPrompt(problem: "This is the book ___ I bought.", choices: english.choices, correct: "②", mine: "1",
                                               subject: .english, concepts: grammar)
    check("AI 해설: 확인된 정답 포함", prompt.contains("[확인된 정답] 2번 (which)") && prompt.contains("[학생 답] 1번 (who)"), prompt)
    check("AI 해설: 정답을 바꾸지 말라고", prompt.contains("바꾸거나 의심하지"))
}
