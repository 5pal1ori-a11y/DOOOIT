import Foundation

// MARK: - 문제 사진 글자: 빈칸(□)과 보기 번호(①~⑤) 바로잡기

func runOCRCases() {
    // 빈칸
    let blanks: [(String, String)] = [
        ("3 + 口 = 7", "3 + □ = 7"),
        ("3 + ㅁ = 7", "3 + □ = 7"),
        ("3 + [ ] = 7", "3 + □ = 7"),
        ("3 + = 7", "3 + □ = 7"),
        ("45 ÷ = 9", "45 ÷ □ = 9"),
        ("3 : 4 = : 20", "3 : 4 = □ : 20"),
        ("7 - = 3", "7 - □ = 3"),
        ("× 4 = 28", "□ × 4 = 28"),
        ("다음 (    ) 안에 알맞은 수를 쓰시오.", "다음 □ 안에 알맞은 수를 쓰시오."),
        ("x² + 6x + ___ = (x + 3)²", "x² + 6x + □ = (x + 3)²"),
    ]
    for (input, expected) in blanks {
        let fixed = MathOCRFixer.normalizeBlanks(input)
        check("빈칸 인식: \(input)", fixed == expected, fixed)
    }
    // 빈칸으로 바꾸면 안 되는 것
    for keep in ["3 + 4 = 7", "x - 1 = 0", "f(x) = 2x + 1", "a : b = 2 : 3", "3 + (-2) = 1", "ㅁ자 모양 도형", "넓이는 ( 단위: cm² )", "+ 3x + 2 = 0의 두 근"] {
        let fixed = MathOCRFixer.normalizeBlanks(keep)
        check("빈칸 아님: \(keep)", fixed == keep, fixed)
    }
    let longLine = "2x³ − 5x² + 3x\n+ 7x − 4 = 0"
    check("줄바꿈된 긴 식은 빈칸 아님", !MathOCRFixer.normalizeBlanks(longLine).contains("□"), MathOCRFixer.normalizeBlanks(longLine))

    // 보기 번호
    let choiceCases: [(String, String)] = [
        ("(1) 12 (2) 14 (3) 16 (4) 18 (5) 20", "① 12 ② 14 ③ 16 ④ 18 ⑤ 20"),
        ("1) 3 2) 5 3) 7 4) 9 5) 11", "① 3 ② 5 ③ 7 ④ 9 ⑤ 11"),
        ("(1) -2\n(2) -1\n(3) 0\n(4) 1\n(5) 2", "① -2\n② -1\n③ 0\n④ 1\n⑤ 2"),
        ("(1 √2 (2 √3 (3 2 (4 √5 (5 √6", "① √2 ② √3 ③ 2 ④ √5 ⑤ √6"),
        ("(l) 1 (Z) 2 (3) 3 (4) 4 (S) 5", "① 1 ② 2 ③ 3 ④ 4 ⑤ 5"),
        ("① 1 ② 2 ® 3 ④ 4 ⑤ 5", "① 1 ② 2 ③ 3 ④ 4 ⑤ 5"),
        ("① 1 @ 2 ③ 3 ④ 4 ⑤ 5", "① 1 ② 2 ③ 3 ④ 4 ⑤ 5"),
        ("(1) 2/3 (2) 3/4 (3) 4/5 (4) 5/6", "① 2/3 ② 3/4 ③ 4/5 ④ 5/6"),
    ]
    for (input, expected) in choiceCases {
        let fixed = MathOCRFixer.normalizeChoices(input)
        check("보기 번호: \(input.prefix(20))", fixed == expected, fixed)
    }
    // 소문항·함수값은 그대로
    let subQuestions = "(1) 이차방정식의 두 근을 구하시오.\n(2) 두 근의 합을 구하시오.\n(3) 두 근의 곱을 구하시오.\n(4) 판별식의 값을 구하시오."
    check("소문항 (1)(2)는 보기 아님", MathOCRFixer.normalizeChoices(subQuestions) == subQuestions)
    check("함수값 f(1)은 그대로", MathOCRFixer.normalizeChoices("f(1) + f(2) + f(3) + f(4)의 값은?") == "f(1) + f(2) + f(3) + f(4)의 값은?")
    check("번호 2개뿐이면 그대로", MathOCRFixer.normalizeChoices("(1) 3 (2) 5") == "(1) 3 (2) 5")
    // fix 전체 흐름: 빈칸 + 보기 함께
    let full = MathOCRFixer.fix("다음 식의 口에 알맞은 수는?\n3 × 口 = 24\n(1) 6 (2) 7 (3) 8 (4) 9 (5) 10")
    check("빈칸 + 보기 함께", full.contains("3 × □ = 24") && full.contains("① 6 ② 7 ③ 8 ④ 9 ⑤ 10"), full)
    // 보기 조각은 분수로 합치지 않음
    let line = CGRect(x: 0.1, y: 0.50, width: 0.6, height: 0.04)
    let markers = MathOCRFixer.stackedFractions(pieces: [("(1)", CGRect(x: 0.3, y: 0.535, width: 0.03, height: 0.03)),
                                                         ("(2)", CGRect(x: 0.3, y: 0.475, width: 0.03, height: 0.03))], hosts: [line])
    check("보기 번호 조각은 분수 아님", markers.isEmpty)
    // 사진 속 빈 네모 상자 → □ 자리
    let lines = [CGRect(x: 0.1, y: 0.5, width: 0.6, height: 0.04)]
    let letters = [CGRect(x: 0.1, y: 0.5, width: 0.03, height: 0.04), CGRect(x: 0.2, y: 0.5, width: 0.03, height: 0.04)]
    let found = MathOCRFixer.blankBoxes(rects: [CGRect(x: 0.3, y: 0.495, width: 0.05, height: 0.05),   // 빈 상자
                                                CGRect(x: 0.09, y: 0.49, width: 0.05, height: 0.06),   // 글자를 감싼 테두리
                                                CGRect(x: 0.1, y: 0.1, width: 0.6, height: 0.3)],      // 그림
                                         lines: lines, letters: letters)
    check("빈 네모 상자만 빈칸으로", found.count == 1 && found.first?.host == 0, "\(found)")
}
