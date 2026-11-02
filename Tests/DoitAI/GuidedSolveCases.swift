import Foundation

// MARK: - AI와 함께 풀기 (힌트 순서 · 정답 새는 문장 지우기 · 단계 확인 · 상태 바뀜)

private func korChoiceProblem(answer: String) -> DoitGuidedSolve.Problem {
    var p = DoitGuidedSolve.Problem(text: "윗글의 내용과 일치하지 않는 것은?\n조선은 한양을 수도로 정하고 경복궁을 지었다. 세종은 훈민정음을 만들었다.")
    p.choices = ["조선의 수도는 한양이다", "세종은 훈민정음을 만들었다", "경복궁은 조선의 궁궐이다", "세종은 고려의 왕이었다", "한양에 궁궐을 지었다"]
    p.kind = .multipleChoice
    p.subject = .korean
    p.subjectLabel = "국어"
    p.answerKey = answer
    p.answerSource = answer.isEmpty ? .none : .note
    p.type = DoitProblemTypes.classify(p.text, subjectHint: "국어", limit: 1).first?.type
    return p
}

func runGuidedSolveCases() {
    // 1. 정답 새는 문장 지우기
    let choices5 = ["가", "나", "다", "라", "마"]
    check("새는 말: 정답 번호(③) 문장은 지움",
          DoitGuidedSolve.stripLeak("정답은 ③이에요. 둘째 문단을 봐요.", answer: "3", choices: choices5, problem: "다음 중 옳은 것은?", isChoice: true) == "둘째 문단을 봐요.")
    check("새는 말: '3번' 문장도 지움",
          DoitGuidedSolve.stripLeak("3번 선지를 보세요. 다른 선지와 비교해요.", answer: "③", choices: choices5, problem: "옳은 것은?", isChoice: true) == "다른 선지와 비교해요.")
    check("새는 말: 정답이 아닌 선지는 그대로",
          DoitGuidedSolve.stripLeak("선지 ②를 지문과 맞춰 봐요.", answer: "3", choices: choices5, problem: "옳은 것은?", isChoice: true) == "선지 ②를 지문과 맞춰 봐요.")
    let longChoices = ["광합성은 엽록체에서 일어난다", "호흡은 미토콘드리아에서", "증산은 잎에서", "흡수는 뿌리에서", "저장은 줄기에서"]
    check("새는 말: 정답 선지 글을 그대로 말하면 지움",
          DoitGuidedSolve.stripLeak("광합성은 엽록체에서 일어난다는 문장이 맞아요. 다시 봐요.", answer: "1", choices: longChoices, problem: "옳은 것은?", isChoice: true) == "다시 봐요.")
    let quad = "x^2 - 5x + 6 = 0 을 푸시오"
    check("새는 말: 수학 답 'x = 2'는 지움 (문제에 2가 있어도)",
          DoitGuidedSolve.stripLeak("x = 2를 넣어 봐요. 먼저 인수분해해요.", answer: "x = 2 또는 x = 3", choices: [], problem: quad, isChoice: false) == "먼저 인수분해해요.")
    check("새는 말: 문제에 없던 답 값은 지움",
          DoitGuidedSolve.stripLeak("두 근 3과 2 중 큰 것을 골라요. 곱해서 6이 되는 두 수를 찾아요.", answer: "3", choices: [], problem: "x^2 - 5x + 6 = 0의 큰 근은?", isChoice: false)
              == "곱해서 6이 되는 두 수를 찾아요.")
    check("새는 말: 문제에 있는 수는 답과 같아도 남김 (단정하지 않으면)",
          DoitGuidedSolve.stripLeak("양변에서 3을 빼 봐요.", answer: "3", choices: [], problem: "x + 3 = 6", isChoice: false) == "양변에서 3을 빼 봐요.")
    check("새는 말: 문제에 없는 답 낱말은 지움",
          DoitGuidedSolve.stripLeak("엽록체를 떠올려 봐요. 초록색 알갱이를 생각해요.", answer: "엽록체", choices: [], problem: "광합성이 일어나는 세포 소기관은?", isChoice: false)
              == "초록색 알갱이를 생각해요.")
    check("새는 말: 문제에 있는 낱말은 '정답은'과 함께일 때만 지움",
          DoitGuidedSolve.stripLeak("광합성 과정을 떠올려요. 정답은 광합성이에요.", answer: "광합성", choices: [], problem: "다음 설명의 광합성 과정에서 빛을 쓰는 반응은? 광합성", isChoice: false)
              == "광합성 과정을 떠올려요.")
    check("새는 말: 영어 답",
          DoitGuidedSolve.stripLeak("Use went here. 시제를 먼저 봐요.", answer: "went", choices: [], problem: "Yesterday I ___ to school.", isChoice: false) == "시제를 먼저 봐요.")
    check("새는 말: O/X 답 ('맞는 문장')",
          DoitGuidedSolve.stripLeak("이건 맞는 문장이에요. 핵심 낱말을 봐요.", answer: "O", choices: [], problem: "물은 100도에서 끓는다. (O, X)", isChoice: false) == "핵심 낱말을 봐요.")
    check("새는 말: 정답을 몰라도 '정답은 ②'는 지움",
          DoitGuidedSolve.stripLeak("정답은 ②예요. 지문을 봐요.", answer: "", choices: choices5, problem: "옳은 것은?", isChoice: true) == "지문을 봐요.")
    check("문장 나누기: 소수점은 나누지 않음", DoitGuidedSolve.splitSentences("0.5를 곱해요. 다음.").count == 2)

    // 2. 단계 확인 (수학)
    check("방정식 비교: 2x + 3 = 7 ≡ 2x = 4", DoitGuidedSolve.equivalentEquation("2x + 3 = 7", "2x = 4") == true)
    check("방정식 비교: 2x = 4 ≡ x = 2", DoitGuidedSolve.equivalentEquation("2x = 4", "x = 2") == true)
    check("방정식 비교: 2x = 4 ≠ x = 3", DoitGuidedSolve.equivalentEquation("2x = 4", "x = 3") == false)
    check("단계 조각: '25 − 24 = 1' → 끝 값 1", DoitGuidedSolve.stepPieces("25 − 24 = 1").contains("1"))
    let steps = [SolutionStep(hint: "3을 오른쪽으로 옮기면", work: "2x = 7 − 3 = 4"), SolutionStep(hint: "양변을 2로 나누면", work: "x = 2")]
    check("단계 맞추기: 2x = 4 → 1단계", DoitGuidedSolve.matchStep("2x = 4", steps: steps) == 0, "\(String(describing: DoitGuidedSolve.matchStep("2x = 4", steps: steps)))")
    check("단계 맞추기: x = 2 → 2단계", DoitGuidedSolve.matchStep("x=2", steps: steps) == 1)
    check("단계 맞추기: 틀린 식은 없음", DoitGuidedSolve.matchStep("2x = 10", steps: steps) == nil)
    check("단계 맞추기: 모양이 다른 같은 방정식은 단계로 정하지 않음", DoitGuidedSolve.matchStep("4x = 8", steps: steps) == nil && DoitGuidedSolve.isEquivalentStep("4x = 8", steps: steps))
    check("단계 맞추기: 틀린 방정식은 같은 식도 아님", !DoitGuidedSolve.isEquivalentStep("2x = 10", steps: steps))

    // 3. 수학: 엔진 단계로 같이 풀기
    let mathProblem = DoitGuidedSolve.problem(recognizedText: "2x + 3 = 7", scan: nil, kind: nil, subjectStored: "", correctAnswer: "")
    check("수학: 엔진이 풀어서 단계 · 정답(엔진)", !mathProblem.steps.isEmpty && mathProblem.answerSource == .engine && !mathProblem.answerKey.isEmpty,
          "\(mathProblem.steps.count) \(mathProblem.answerKey)")
    let mathPlan = DoitGuidedSolve.plan(mathProblem)
    check("수학: 힌트가 있고 정답이 새지 않음", !mathPlan.hints.isEmpty && mathPlan.hints.allSatisfy { !$0.text.contains("x = 2") && !$0.text.contains("x=2") },
          mathPlan.hints.map(\.text).joined(separator: " / "))
    check("수학: 마지막 단계 결과는 힌트로 보여 주지 않음", !mathPlan.hints.contains { $0.advances && $0.step == mathPlan.steps.count - 1 })
    var m = GuidedSolveSession(plan: mathPlan)
    check("수학: 처음엔 묻는 것 + 안내 (힌트 0)", m.messages.count == 2 && m.hintsUsed == 0 && m.phase == .solving)
    m.apply(.hint, plan: mathPlan)
    check("수학: 힌트 더 → 힌트 1", m.hintsUsed == 1 && m.messages.last?.label == "힌트 1" && m.messages.last?.tone == .hint)
    m.apply(.check("x = 5"), plan: mathPlan)
    check("수학: 틀린 답 → 다시 생각해 봐요", m.messages.contains { $0.tone == .retry } && m.phase == .solving && m.attempts == 1)
    m.apply(.check(""), plan: mathPlan)
    check("수학: 빈 칸 확인 → 적어 달라고", m.messages.last?.text.contains("적어 주세요") == true && m.attempts == 1)
    if let firstWork = mathPlan.steps.first?.work, mathPlan.steps.count >= 2 {
        let before = m.step
        m.apply(.check(DoitGuidedSolve.stepPieces(firstWork).last ?? firstWork), plan: mathPlan)
        check("수학: 1단계 결과를 적으면 맞았어요 · 다음 단계", m.messages.last?.tone == .good && m.step >= max(before, 1), "\(m.messages.last?.text ?? "") \(firstWork)")
    }
    m.apply(.check("x = 2"), plan: mathPlan)
    check("수학: 답을 맞히면 풀림 + 풀이", m.phase == .solved && m.messages.last?.tone == .explain && m.messages.last?.text.contains("정답") == true)
    let afterSolved = m.messages.count
    m.apply(.hint, plan: mathPlan)
    check("수학: 끝난 뒤엔 힌트를 더 주지 않음", m.messages.count == afterSolved)

    // 힌트를 다 쓰면: 모델이 없으면 안내, 있으면 부탁(정답을 알려 주되 말하지 말라고)
    var drain = GuidedSolveSession(plan: mathPlan)
    for _ in 0..<(mathPlan.hints.count) { drain.apply(.hint, plan: mathPlan) }
    check("힌트 순서: 준비한 힌트 수만큼 셈", drain.hintsUsed == mathPlan.hints.count, "\(drain.hintsUsed) / \(mathPlan.hints.count)")
    drain.apply(.hint, plan: mathPlan, aiAvailable: false)
    check("힌트 순서: 다 쓰면 안내 (모델 없음)", drain.messages.last?.text == DoitGuidedSolve.outOfHints && drain.hintsUsed == mathPlan.hints.count)
    let request = drain.apply(.hint, plan: mathPlan, aiAvailable: true)
    check("힌트 순서: 다 쓰면 모델에게 부탁 (정답 포함 · 말하지 말라고)",
          request?.purpose == .hint && request?.prompt.contains("[확인된 정답") == true && request?.prompt.contains("절대 말하지") == true)
    if let request {
        drain.receiveAI("좋은 질문이에요! x = 2예요. 양변을 같은 수로 나눠 봐요. 그리고 검산해요. 또 하나 더.", request: request, plan: mathPlan)
        let last = drain.messages.last
        check("AI 힌트: 새는 문장 지우고 2문장까지 · 'AI 힌트' 표시",
              last?.tone == .ai && last?.label == "AI 힌트" && last?.text.contains("x = 2") == false && DoitGuidedSolve.splitSentences(last?.text ?? "").count <= 2,
              last?.text ?? "")
        let count = drain.hintsUsed
        drain.receiveAI("x = 2예요.", request: request, plan: mathPlan)
        check("AI 힌트: 다 새면 버리고 안내", drain.messages.last?.text == DoitGuidedSolve.outOfHints && drain.hintsUsed == count)
        drain.receiveAI(nil, request: request, plan: mathPlan)
        check("AI 힌트: 실패하면 안내", drain.messages.last?.text == DoitGuidedSolve.outOfHints)
    }

    // 적힌 정답과 엔진 답이 다르면 엔진 단계는 쓰지 않음
    let disagree = DoitGuidedSolve.problem(recognizedText: "2x + 3 = 7", scan: nil, kind: nil, subjectStored: "", correctAnswer: "5")
    check("수학: 적힌 정답과 엔진 답이 다르면 단계 안 씀", disagree.steps.isEmpty && disagree.answerKey == "5" && disagree.answerSource == .note)
    let disagreePlan = DoitGuidedSolve.plan(disagree)
    check("수학: 엔진 단계 없을 때도 힌트 (유형·일반)", !disagreePlan.hints.isEmpty)

    // 4. 국어 객관식 (정답 앎)
    let korPlan = DoitGuidedSolve.plan(korChoiceProblem(answer: "4"))
    check("국어: 힌트에 정답 선지(④)가 없음", korPlan.hints.allSatisfy { !$0.text.contains("④") && !$0.text.contains("4번") },
          korPlan.hints.map(\.text).joined(separator: " / "))
    check("국어: 틀린 선지 확인 힌트 (정답 선지는 없음)", korPlan.choiceHints[4] == nil && korPlan.choiceHints[2] != nil)
    check("국어: 선지 지우기 힌트는 2개까지", korPlan.hints.filter { $0.choice != nil }.count <= 2 && korPlan.hints.allSatisfy { $0.choice != 4 })
    var k = GuidedSolveSession(plan: korPlan)
    k.apply(.submit("2"), plan: korPlan)
    check("국어: 틀린 선지 → 다시 생각 + 그 선지 힌트", k.messages.contains { $0.tone == .retry } && k.messages.last?.label == "선지 ②" && k.phase == .solving,
          k.messages.last?.text ?? "")
    check("국어: 다시 생각 메시지에 정답이 없음", !k.messages.contains { $0.role == .coach && ($0.text.contains("④") || $0.text.contains("고려의 왕")) })
    k.apply(.say("④"), plan: korPlan)
    check("국어: 정답 선지 → 풀림 (시도 2)", k.phase == .solved && k.attempts == 2)
    check("국어: 풀이에 정답", k.messages.last?.text.contains("4번") == true)

    // 5. 정답을 모르면 맞다고 하지 않음
    let unknownPlan = DoitGuidedSolve.plan(korChoiceProblem(answer: ""))
    var u = GuidedSolveSession(plan: unknownPlan)
    u.apply(.submit("3"), plan: unknownPlan)
    check("정답 모름: 채점하지 않고 그렇다고 말함", u.phase == .solving && u.messages.last?.text.contains("확인할 수 없어요") == true)
    u.apply(.reveal, plan: unknownPlan)
    check("정답 모름: 답 보기 → 모른다고", u.phase == .revealed && u.messages.last?.text.contains("정답을 아직 몰라요") == true)

    // 6. 답 보기
    var r = GuidedSolveSession(plan: korPlan)
    r.apply(.hint, plan: korPlan)
    r.apply(.reveal, plan: korPlan)
    check("답 보기: 정답과 풀이", r.phase == .revealed && r.messages.last?.tone == .explain && r.messages.last?.text.contains("정답") == true)
    check("답 보기 뒤 답을 내도 채점하지 않음", { var c = r; c.apply(.submit("4"), plan: korPlan); return c.phase == .revealed && c.messages.count == r.messages.count }())

    // 7. 개념 설명 (돌아가며)
    var c = GuidedSolveSession(plan: mathPlan)
    c.apply(.concept, plan: mathPlan)
    check("개념 설명: 개념 또는 없다는 안내", c.messages.last?.tone == .concept || c.messages.last?.text.contains("개념 카드가 없어요") == true)

    // 8. 말 알아보기
    check("말: '힌트 줘' → 힌트", DoitGuidedSolve.intent(of: "힌트 줘", plan: korPlan) == .hint)
    check("말: '모르겠어요' → 힌트", DoitGuidedSolve.intent(of: "모르겠어요", plan: korPlan) == .hint)
    check("말: '답 알려줘' → 답 보기", DoitGuidedSolve.intent(of: "답 알려줘", plan: korPlan) == .reveal)
    check("말: 객관식 '3번' → 답", DoitGuidedSolve.intent(of: "3번", plan: korPlan) == .answer)
    check("말: '왜 그래요?' → 질문", DoitGuidedSolve.intent(of: "왜 그래요?", plan: korPlan) == .question)
    check("말: 수학 식 → 답·단계", DoitGuidedSolve.intent(of: "2x = 4", plan: mathPlan) == .answer)
    var q = GuidedSolveSession(plan: korPlan)
    let ask = q.apply(.say("둘째 문장은 무슨 뜻이에요?"), plan: korPlan, aiAvailable: true)
    check("말: 질문 + 모델 → 답 부탁 (학생 말 포함)", ask?.purpose == .reply && ask?.prompt.contains("[학생 말]") == true)
    var q2 = GuidedSolveSession(plan: korPlan)
    q2.apply(.say("둘째 문장은 무슨 뜻이에요?"), plan: korPlan, aiAvailable: false)
    check("말: 질문 + 모델 없음 → 힌트로 대신", q2.hintsUsed == 1 && q2.messages.last?.tone == .hint)

    // 9. 기록
    var solo = GuidedSolveSession(plan: korPlan)
    solo.apply(.submit("4"), plan: korPlan)
    check("결과: 힌트 없이 풀면 단계 4 · 재도전 정답", DoitGuidedSolve.outcome(solo) == .init(correct: true, level: 4, retry: true))
    var helped = GuidedSolveSession(plan: korPlan)
    helped.apply(.hint, plan: korPlan)
    helped.apply(.hint, plan: korPlan)
    helped.apply(.submit("4"), plan: korPlan)
    check("결과: 힌트 2개로 풀면 단계 2 · 재도전엔 안 넣음", DoitGuidedSolve.outcome(helped) == .init(correct: true, level: 2, retry: nil))
    check("결과: 답을 보면 오답으로", DoitGuidedSolve.outcome(r) == .init(correct: false, level: 1, retry: false))
    check("결과: 아직 푸는 중이면 없음", DoitGuidedSolve.outcome(GuidedSolveSession(plan: korPlan)) == nil)
    let progress = GuidedSolveProgress().adding(helped).adding(solo).adding(GuidedSolveSession(plan: korPlan))
    check("진행 기록: 한 것만 세고 최소 힌트", progress.sessions == 2 && progress.solvedCount == 2 && progress.bestHints == 0 && progress.lastHints == 0)
    check("진행 기록: 요약", progress.summary == "지난번엔 힌트 없이 풀었어요")
    let saved = try? JSONDecoder().decode(GuidedSolveProgress.self, from: JSONEncoder().encode(progress))
    check("진행 기록: 저장·읽기", saved == progress)

    // 11. 선지가 문제 글에 같이 있어도 정답 선지 낱말은 샘 (개념 카드 "…(빛, 엽록체)…")
    let sci = "다음 중 광합성이 일어나는 세포 소기관은?\n① 핵 ② 엽록체 ③ 미토콘드리아 ④ 리보솜 ⑤ 골지체"
    let sciChoices = ["핵", "엽록체", "미토콘드리아", "리보솜", "골지체"]
    check("새는 말: 문제 속 선지 줄은 '문제에 있다'로 보지 않음",
          DoitGuidedSolve.stripLeak("광합성은 엽록체에서 일어나요. 빛이 필요해요.", answer: "2", choices: sciChoices, problem: sci, isChoice: true) == "빛이 필요해요.")
    var sciProblem = DoitGuidedSolve.Problem(text: sci, choices: sciChoices, kind: .multipleChoice, subject: .science, answerKey: "2")
    sciProblem.concepts = [.init(title: "광합성", body: "식: 6CO₂ + 6H₂O → (빛, 엽록체) → C₆H₁₂O₆ + 6O₂\n빛에너지를 화학 에너지로 바꿔요.")]
    let sciPlan = DoitGuidedSolve.plan(sciProblem)
    check("과학: 힌트·개념에 정답 선지 낱말 없음", (sciPlan.hints.map(\.text) + sciPlan.concepts).allSatisfy { !$0.contains("엽록체") },
          (sciPlan.hints.map(\.text) + sciPlan.concepts).joined(separator: " / "))
    check("과학: 개념 카드의 안전한 문장은 힌트로", sciPlan.hints.contains { $0.text.contains("빛에너지") })

    // 12. 단답형: 마지막 힌트는 글자 수 → 첫 글자
    var hist = DoitGuidedSolve.Problem(text: "조선을 건국한 왕은 누구인가?", kind: .shortAnswer, subject: .social, answerKey: "이성계")
    hist.concepts = [.init(title: "조선", body: "조선은 1392년 이성계가 세운 나라예요. 한양을 도읍으로 삼았어요.")]
    let histPlan = DoitGuidedSolve.plan(hist)
    check("단답형: 글자 수 · 첫 글자 힌트가 마지막", histPlan.hints.suffix(2).map(\.text) == ["답은 3글자예요.", "첫 글자는 '이'예요."], histPlan.hints.map(\.text).joined(separator: " / "))
    check("단답형: 정답 든 개념 문장은 빼고 다음 문장", histPlan.hints.contains { $0.text.contains("한양") } && !histPlan.hints.contains { $0.text.contains("이성계") })
    var h = GuidedSolveSession(plan: histPlan)
    h.apply(.say("이성계"), plan: histPlan)
    check("단답형: 적은 답 채점 → 풀림", h.phase == .solved)

    // 13. 빈칸 문제의 선지 힌트는 "빈칸에 넣어 읽어 봐요"
    check("빈칸: 선지 넣어 읽기", DoitGuidedSolve.choiceCheck(1, choice: "go", problem: "빈칸에 들어갈 말은? Yesterday I ___ to school.").contains("빈칸에 넣어"))

    // 10. 모델 부탁 글
    let prompt = DoitGuidedSolve.hintPrompt(plan: korPlan, step: nil, shown: ["첫 힌트"], student: nil)
    check("부탁 글: 문제·선택지·정답·이미 준 힌트", prompt.contains("[문제]") && prompt.contains("[선택지]") && prompt.contains("4번") && prompt.contains("첫 힌트"))
    check("부탁 글: 정답 모르면 추측하지 말라고", DoitGuidedSolve.hintPrompt(plan: unknownPlan, step: nil, shown: [], student: nil).contains("모름"))
}
