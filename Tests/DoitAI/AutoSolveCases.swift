import Foundation

// MARK: - 오답노트 풀이 탭: AI가 문제를 읽고 직접 풀기 (풀이 엔진 · 모델 답 읽기)

func runAutoSolveCases() {
    // 풀이 엔진: 답과 단계, 문제 글 저장
    let eq = DoitAutoSolve.engine(text: "x^2 - 5x + 6 = 0", choices: [], isChoice: false)
    check("AI 풀이: 이차방정식 풂", eq != nil && !(eq?.steps.isEmpty ?? true), eq?.finalAnswer ?? "nil")
    check("AI 풀이: 엔진 답 표시", eq?.source == DoitAutoSolve.engineSource && eq?.problem == "x^2 - 5x + 6 = 0")
    check("AI 풀이: 지금 문제 풀이로 인정", DoitAutoSolve.isCurrent(eq, problem: "x^2 - 5x + 6 = 0\n"))
    check("AI 풀이: 문제 글이 바뀌면 다시 풂", !DoitAutoSolve.isCurrent(eq, problem: "x^2 - 5x + 4 = 0"))
    check("AI 풀이: 예전 풀이는 다시 풂", !DoitAutoSolve.isCurrent(WrittenSolution(concept: "", steps: [], finalAnswer: "3"), problem: "x^2 - 5x + 6 = 0"))
    check("AI 풀이: 빈 문제는 안 풂", DoitAutoSolve.engine(text: "  ", choices: [], isChoice: false) == nil)

    // 객관식: 엔진 답과 같은 선지 번호로
    let choiceText = "방정식 2x + 3 = 7의 해는?\n① x = 1 ② x = 2 ③ x = 3 ④ x = 4 ⑤ x = 5"
    let choices = ["x = 1", "x = 2", "x = 3", "x = 4", "x = 5"]
    let mc = DoitAutoSolve.engine(text: choiceText, choices: choices, isChoice: true)
    check("AI 풀이: 객관식은 선지 번호", mc.map { DoitGrader.choiceNumber($0.finalAnswer, choices: choices) == 2 } ?? false, mc?.finalAnswer ?? "nil")

    // 모델 답 읽기
    let m1 = DoitAutoSolve.parseModel("정답: 광합성\n1. 빛을 써서 양분을 만드는 과정이에요.\n2. 엽록체에서 일어나요.", problem: "식물이 빛으로 양분을 만드는 과정은?", choices: [])
    check("AI 풀이 모델: 단답", m1?.finalAnswer == "광합성" && m1?.steps.count == 2 && m1?.steps.first?.work == "빛을 써서 양분을 만드는 과정이에요.", m1?.finalAnswer ?? "nil")
    check("AI 풀이 모델: 추측 표시", m1?.source == DoitAutoSolve.modelSource)
    let opts = ["went", "go", "goes", "going", "gone"]
    check("AI 풀이 모델: 번호", DoitAutoSolve.parseModel("정답: 1\n어제 일이라 과거형이에요.", problem: "p", choices: opts)?.finalAnswer == "1")
    check("AI 풀이 모델: 동그라미 번호", DoitAutoSolve.parseModel("**정답: ③**", problem: "p", choices: opts)?.finalAnswer == "3")
    check("AI 풀이 모델: '3번이에요'", DoitAutoSolve.parseModel("정답은 3번입니다.", problem: "p", choices: opts)?.finalAnswer == "3")
    check("AI 풀이 모델: 선지 글로 답해도 번호", DoitAutoSolve.parseModel("답: went", problem: "p", choices: opts)?.finalAnswer == "1")
    check("AI 풀이 모델: 없는 번호는 버림", DoitAutoSolve.parseModel("정답: 7", problem: "p", choices: opts) == nil)
    check("AI 풀이 모델: 정답 줄 없으면 버림", DoitAutoSolve.parseModel("잘 모르겠어요.", problem: "p", choices: []) == nil)
    check("AI 풀이 모델: 문단 앞 설명 뒤 정답", DoitAutoSolve.parseModel("생각해 보면\n정답: 세종대왕\n- 훈민정음을 만들었어요.", problem: "p", choices: [])?.steps.first?.work == "훈민정음을 만들었어요.")

    // 프롬프트에 문제·선지·형식
    let prompt = DoitAutoSolve.modelPrompt(problem: "빈칸에 알맞은 말은?", choices: opts, subjectName: "영어", problemType: nil)
    check("AI 풀이 프롬프트", prompt.contains("[과목] 영어") && prompt.contains("1) went") && prompt.contains("정답: "))
}
