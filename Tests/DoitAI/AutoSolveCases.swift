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
    let m2 = DoitAutoSolve.parseModel("생각해 보면\n정답: 세종대왕\n- 훈민정음을 만들었어요.", problem: "p", choices: [])
    check("AI 풀이 모델: 문단 중간 정답", m2?.finalAnswer == "세종대왕" && m2?.steps.contains { $0.work == "훈민정음을 만들었어요." } == true)
    let m3 = DoitAutoSolve.parseModel("1. 어제(yesterday)라서 과거형을 써요.\n2. go의 과거형은 went예요.\n**정답:** ①", problem: "p", choices: opts)
    check("AI 풀이 모델: 풀이 뒤 마지막 줄 정답", m3?.finalAnswer == "1" && m3?.steps.count == 2, m3?.finalAnswer ?? "nil")
    check("AI 풀이 모델: 정답 줄 없이 '3번'", DoitAutoSolve.parseModel("보기를 따져 보면\n그래서 3번이 맞아요.", problem: "p", choices: opts)?.finalAnswer == "3")
    check("AI 풀이 모델: 빈 답", DoitAutoSolve.parseModel("", problem: "p", choices: []) == nil)

    // 사진 글 고치기: 문제 번호 · 식만 · 넣어서 계산
    check("AI 풀이: '3. 56÷□=8'이 붙어 읽혀도 □ = 7", DoitAutoSolve.engine(text: "3.56÷ □ =8\n위 식에서 에 들어갈 수를 구하시오.", choices: [], isChoice: false)?.finalAnswer.contains("7") == true)
    check("AI 풀이: 번호 10을 곱하지 않음", DoitAutoSolve.engine(text: "10. (2x+ 1)(x- 3)을 전개하시오", choices: [], isChoice: false)?.finalAnswer == "2x² − 5x − 3")
    check("AI 풀이: 뒤 한글 속 숫자를 식에 붙이지 않음", DoitAutoSolve.engine(text: "9. 2^5 × 2^3을 2의 거듭제곱으로 나타내시오.", choices: [], isChoice: false)?.finalAnswer.contains("256") == true)
    check("AI 풀이: 0.3 × 0.4는 소수 그대로", DoitAutoSolve.engine(text: "3. 0.3 × 0.4의 값은?\n① 0.012 ② 0.12 ③ 1.2 ④ 12 ⑤ 0.7", choices: ["0.012", "0.12", "1.2", "12", "0.7"], isChoice: true, body: "0.3 × 0.4의 값은?")?.finalAnswer == "2")
    // ①과 ⑤가 둘 다 5면 고를 수 없어서 ①을 2+2로 (값 5를 ⑤번으로 읽던 버릇 없이도 ⑤를 골라야 함)
    let grid = ["2+2", "4×2", "10-4", "3× 3", "15÷ 3"]
    check("AI 풀이: x = 2일 때 식의 값 → 선지", DoitAutoSolve.engine(text: "1^1. x= 2일 때, 식 3x- 1의 값과 같은 것은?\n① 2+2 ② 4×2 ③ 10-4 ④ 3× 3 ⑤ 15÷ 3", choices: grid, isChoice: true, body: "1^1. x= 2일 때, 식 3x- 1의 값과 같은 것은?")?.finalAnswer == "5")
    let odd = DoitAutoSolve.engine(text: "2x + 3 = 11의 해는?\n① 1 ② 2 ③ 3", choices: ["1", "2", "3"], isChoice: true, body: "2x + 3 = 11의 해는?")
    check("AI 풀이: 선지에 없는 값은 번호로 안 씀", odd.map { DoitGrader.choiceNumber($0.finalAnswer, choices: ["1", "2", "3"]) == nil && $0.finalAnswer.contains("4") } ?? false, odd?.finalAnswer ?? "nil")
    check("AI 풀이: 넣어서 계산할 식", DoitAutoSolve.substitute("x = 2일 때, 식 3x − 1의 값과 같은 것은?") == "3×(2) − 1의 값은?")
    check("AI 풀이: 이상하게 큰 수에도 멈추지 않음", DoitMath.fraction(1e30) != "" && DoitMath.format(.infinity) == "?" && DoitMath.safeInt(1e300) == Int.max)
    check("AI 풀이: 큰 수 근호 간단히 (오래 안 걸림)", DoitAlgebra.simplifyRoot(Int.max).outside == 1)

    // 프롬프트에 문제·선지·형식
    let prompt = DoitAutoSolve.modelPrompt(problem: "빈칸에 알맞은 말은?", choices: opts, subjectName: "영어", problemType: nil)
    check("AI 풀이 프롬프트", prompt.contains("[과목] 영어") && prompt.contains("1) went") && prompt.contains("정답: "))

    // 대화: 사진 속 문제 풀기
    check("대화 사진 풀기: 풀어줘", DoitAutoSolve.asksToSolve("이거 풀어줘") && DoitAutoSolve.asksToSolve("답 알려줘") && DoitAutoSolve.asksToSolve("몇 번이야?"))
    check("대화 사진 풀기: 저장·유형은 아님", !DoitAutoSolve.asksToSolve("오답노트에 저장해줘") && !DoitAutoSolve.asksToSolve("이 문제 무슨 유형이야?") && !DoitAutoSolve.asksToSolve("단어 추가해줘"))
    let choiceScan = DoitProblemScan.scan("다음 빈칸에 알맞은 것은?\n① went ② go ③ goes", math: false)
    check("대화 사진 풀기: 선지 있는 글은 문제", DoitAutoSolve.looksLikeProblem("다음 빈칸에 알맞은 것은?\n① went ② go ③ goes", scan: choiceScan))
    check("대화 사진 풀기: 그냥 글은 문제 아님", !DoitAutoSolve.looksLikeProblem("오늘 점심은 김밥", scan: DoitProblemScan.scan("오늘 점심은 김밥", math: false)))
    if let solved = DoitAutoSolve.engine(text: "x^2 - 5x + 6 = 0", choices: [], isChoice: false) {
        let text = DoitAutoSolve.chatText(solved, choices: [])
        check("대화 사진 풀기: 정답 먼저", text.hasPrefix("**정답: ") && text.contains("1. "), text)
    } else { check("대화 사진 풀기: 엔진", false) }
    let guess = WrittenSolution(concept: "", steps: [SolutionStep(hint: "", work: "어제라서 과거형")], finalAnswer: "1", source: DoitAutoSolve.modelSource)
    let guessText = DoitAutoSolve.chatText(guess, choices: opts)
    check("대화 사진 풀기: 모델 답은 추측 표시", guessText.contains("AI 추측") && guessText.contains("1번 (went)") && guessText.contains("확인해"), guessText)

    // 실수 x가 들어간 복소수 (z, z²이 실수·순허수·양/음의 실수)
    let complexCases: [(String, String)] = [
        ("복소수 z = (2+4i)(x−8i)에 대하여 z²이 양의 실수가 되도록 하는 실수 x의 값을 a, z²이 음의 실수가 되도록 하는 실수 x의 값을 b라 할 때, a+b의 값은?", "-12"),
        ("z = (1+i)x + 2 - 3i가 실수가 되도록 하는 실수 x의 값은?", "x = 3"),
        ("z = x^2 - 4 + (x+2)i가 순허수일 때 실수 x의 값은?", "x = 2"),
        ("복소수 z = (1+2i)(x-i)가 실수일 때 실수 x의 값을 구하시오.", "x = 1/2"),
    ]
    for (text, expected) in complexCases {
        let got = MathSolver.solve(text)?.answer
        check("복소수 조건: \(text.prefix(30))", got == expected, got ?? "nil")
    }
    let variants: [String] = [
        "복소수 z = (2+4i)(x-8i)에 대하여 z²이 양의 실수가 되도록 하는 실수 x의 값을 a, z2이 음의 실수가 되도록 하는 실수 x의 값을 b라 할 때, a+b의 값은?",
        "복소수 z=(2+4i)(x-8i)에 대하여 z^{2}이 양의 실수가 되도록 하는 실수 x의 값을 a, z^{2}이 음의 실수가 되도록 하는 실수 x의 값을 b라 할 때, a+b의 값은?",
        "복소수 z = (2+4i)(x-8i) 에 대하여 z²이 양수가 되도록 하는 실수 x의 값을 a, z²이 음수가 되도록 하는 실수 x의 값을 b라 할 때, a+b의 값은?",
    ]
    for text in variants { check("복소수 조건 (사진 글 모양): \(text.suffix(40))", MathSolver.solve(text)?.answer == "-12", MathSolver.solve(text)?.answer ?? "nil") }
    let half = MathSolver.solve("복소수 z=(2+4i)(x-8i)에 대하여 z²이 양의 실수가 되도록 하는 실수 x의 값을 a, z 이 음의 실수가 되도록 하는 실수 x의 값을 b라 할 때, a+b의 값은?")?.answer
    check("복소수 조건: 조건 하나를 못 읽으면 반쪽 답(a = 4)을 내지 않음", half == nil || half == "-12", half ?? "nil")
    check("복소수 계산은 그대로", MathSolver.solve("(2+4i)(3-8i)")?.answer == "38 − 4i")
    check("문자가 붙은 복소수는 계산으로 풀지 않음", MathSolver.solve("z = (1+i)x + 2 - 3i가 실수가 되도록 하는 실수 x의 값은?")?.answer != "2 − 3i")
}
