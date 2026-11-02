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

    runCircleCases()
}

// MARK: - 사진 속 동그라미 번호 · 같은 줄 보기 조각

func runCircleCases() {
    let h: CGFloat = 0.03   // 글자 줄 높이
    func shape(_ height: CGFloat, aspect: Double = 1, fill: Double = 0.78, inner: [CGRect]) -> MathOCRFixer.Shape {
        MathOCRFixer.Shape(box: CGRect(x: 0.1, y: 0.5, width: height * CGFloat(aspect), height: height), aspect: aspect, fill: fill, inner: inner)
    }
    let hole = CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84)
    let one = CGRect(x: 0.44, y: 0.25, width: 0.14, height: 0.5)
    let three = CGRect(x: 0.36, y: 0.24, width: 0.3, height: 0.52)
    check("① 테두리 동그라미", MathOCRFixer.isChoiceCircle(shape(h, inner: [hole, one]), lineHeight: h))
    check("③ 테두리 동그라미", MathOCRFixer.isChoiceCircle(shape(h * 0.9, inner: [hole, three]), lineHeight: h))
    check("❶ 속이 찬 동그라미", MathOCRFixer.isChoiceCircle(shape(h, inner: [three]), lineHeight: h))
    check("ㅇ (빈 동그라미)은 아님", !MathOCRFixer.isChoiceCircle(shape(h * 0.6, inner: [hole]), lineHeight: h))
    check("O (긴 구멍 하나)는 아님", !MathOCRFixer.isChoiceCircle(shape(h * 0.8, aspect: 0.84, inner: [CGRect(x: 0.2, y: 0.12, width: 0.6, height: 0.76)]), lineHeight: h))
    check("네모 상자는 아님", !MathOCRFixer.isChoiceCircle(shape(h, fill: 0.98, inner: [hole, one]), lineHeight: h))
    check("너무 큰 원(그림)은 아님", !MathOCRFixer.isChoiceCircle(shape(h * 4, inner: [hole, one]), lineHeight: h))
    check("너무 작은 점은 아님", !MathOCRFixer.isChoiceCircle(shape(h * 0.3, inner: [hole, one]), lineHeight: h))

    func box(_ x: CGFloat, _ y: CGFloat) -> CGRect { CGRect(x: x, y: y, width: h, height: h) }
    // 한 줄에 다섯 개 (순서가 섞여 들어와도)
    let row5 = [box(0.5, 0.2), box(0.1, 0.2), box(0.9, 0.2), box(0.3, 0.2), box(0.7, 0.2)]
    let n5 = MathOCRFixer.numberCircles(row5, lineHeight: h)
    check("한 줄 다섯 개 번호", n5 == [3, 1, 5, 2, 4], "\(n5)")
    // 3개 + 2개 두 줄
    let rows32 = [box(0.1, 0.3), box(0.4, 0.3), box(0.7, 0.3), box(0.1, 0.25), box(0.4, 0.25)]
    let n32 = MathOCRFixer.numberCircles(rows32, lineHeight: h)
    check("3+2 두 줄 번호", n32 == [1, 2, 3, 4, 5], "\(n32)")
    // 한 줄에 하나씩 다섯 줄
    let stacked = (0..<5).map { box(0.1, 0.4 - CGFloat($0) * 0.04) }
    check("한 줄씩 다섯 개", MathOCRFixer.numberCircles(stacked, lineHeight: h) == [1, 2, 3, 4, 5])
    // 사진에 문제 두 개: 멀리 떨어진 두 묶음은 각각 1부터
    let two = (0..<5).map { box(0.1 + CGFloat($0) * 0.15, 0.7) } + (0..<5).map { box(0.1 + CGFloat($0) * 0.15, 0.2) }
    check("문제 두 개의 보기", MathOCRFixer.numberCircles(two, lineHeight: h) == [1, 2, 3, 4, 5, 1, 2, 3, 4, 5])
    // 붙어 있어도 다섯 개 넘으면 다음 묶음
    let ten = (0..<5).map { box(0.1 + CGFloat($0) * 0.15, 0.3) } + (0..<5).map { box(0.1 + CGFloat($0) * 0.15, 0.26) }
    check("열 개 이어지면 다섯 개씩", MathOCRFixer.numberCircles(ten, lineHeight: h) == [1, 2, 3, 4, 5, 1, 2, 3, 4, 5])
    // 동그라미 하나·둘은 번호가 아님 (원점 O 같은 것)
    check("동그라미 두 개뿐이면 번호 아님", MathOCRFixer.numberCircles([box(0.1, 0.3), box(0.5, 0.3)], lineHeight: h) == [0, 0])
    // 글자 인식이 ③을 읽었으면 거기에 맞춤 (①② 동그라미를 놓친 경우)
    let partial = [box(0.5, 0.2), box(0.7, 0.2), box(0.9, 0.2)]
    check("읽은 번호에 맞춤", MathOCRFixer.numberCircles(partial, lineHeight: h, anchors: [0: 3]) == [3, 4, 5])
    check("맞지 않는 읽은 번호는 무시", MathOCRFixer.numberCircles(partial, lineHeight: h, anchors: [0: 3, 1: 2]) == [1, 2, 3])

    // 같은 줄 보기 조각 합치기 (Vision이 조각마다 높이를 조금씩 다르게 줘도 왼쪽부터)
    let items: [(text: String, box: CGRect)] = [
        ("다음 중 x² − 5x + 6 = 0의 한 근은?", CGRect(x: 0.05, y: 0.6, width: 0.8, height: 0.04)),
        ("③ 3", CGRect(x: 0.45, y: 0.502, width: 0.08, height: 0.04)),
        ("① 1", CGRect(x: 0.05, y: 0.497, width: 0.08, height: 0.04)),
        ("② 2", CGRect(x: 0.25, y: 0.503, width: 0.08, height: 0.04)),
        ("⑤ 5", CGRect(x: 0.25, y: 0.44, width: 0.08, height: 0.04)),
        ("④ 4", CGRect(x: 0.05, y: 0.441, width: 0.08, height: 0.04)),
    ]
    let joined = MathOCRFixer.joinRows(items)
    check("같은 줄 보기 왼쪽부터", joined == ["다음 중 x² − 5x + 6 = 0의 한 근은?", "① 1   ② 2   ③ 3", "④ 4   ⑤ 5"], "\(joined)")
    // 번호가 하나도 안 읽힌 보기 조각 → 질문 아래 4~5개면 번호 붙임
    let bareItems: [(text: String, box: CGRect)] = [
        ("두 수 12와 18의 최대공약수는?", CGRect(x: 0.05, y: 0.6, width: 0.8, height: 0.04)),
        ("2", CGRect(x: 0.1, y: 0.5, width: 0.03, height: 0.04)),
        ("3", CGRect(x: 0.3, y: 0.5, width: 0.03, height: 0.04)),
        ("4", CGRect(x: 0.5, y: 0.5, width: 0.03, height: 0.04)),
        ("6", CGRect(x: 0.7, y: 0.5, width: 0.03, height: 0.04)),
        ("9", CGRect(x: 0.9, y: 0.5, width: 0.03, height: 0.04)),
    ]
    let labeled = MathOCRFixer.joinRows(bareItems)
    check("번호 없는 보기에 번호", labeled.last == "① 2   ② 3   ③ 4   ④ 6   ⑤ 9", "\(labeled)")
    // 숫자로만 읽힌 번호 조각 "1 12", "2 14" …
    let digitItems: [(text: String, box: CGRect)] = [("다음 중 가장 큰 수는?", CGRect(x: 0.05, y: 0.6, width: 0.8, height: 0.04))]
        + ["1 12", "2 14", "3 16", "4 18", "5 20"].enumerated().map { ($1, CGRect(x: 0.05 + CGFloat($0) * 0.18, y: 0.5, width: 0.08, height: 0.04)) }
    let digitJoined = MathOCRFixer.joinRows(digitItems)
    check("숫자로 읽힌 번호 조각", digitJoined.last == "① 12   ② 14   ③ 16   ④ 18   ⑤ 20", "\(digitJoined)")
    // 두 단 편집의 긴 문장 두 개는 합치지 않음
    let columns: [(text: String, box: CGRect)] = [
        ("이차방정식 x² + 2x − 3 = 0의 두 근을 구하는 과정을 쓰시오", CGRect(x: 0.02, y: 0.5, width: 0.45, height: 0.03)),
        ("다음 그림에서 삼각형 ABC의 넓이를 구하고 그 이유를 설명하시오", CGRect(x: 0.52, y: 0.501, width: 0.45, height: 0.03)),
    ]
    check("두 단 긴 문장은 따로", MathOCRFixer.joinRows(columns).count == 2)
    // 질문 아래 긴 풀이 문장은 보기로 보지 않음
    let notChoices = MathOCRFixer.labelUnmarkedChoices([["다음 값은?"], ["가"], ["나"], ["그러므로 구하는 값은 두 근의 합과 곱을 이용하여 계산한다"], ["라"]])
    check("긴 문장 섞이면 보기 아님", notChoices.flatMap { $0 }.joined().contains("①") == false)
    check("소문항 (1)(2)는 번호 그대로", MathOCRFixer.labelUnmarkedChoices([["다음을 구하시오?"], ["(1) 3", "(2) 4", "(3) 5", "(4) 6"]])[1] == ["(1) 3", "(2) 4", "(3) 5", "(4) 6"])

    // 글자만 있을 때: "1 12 2 14 3 16 4 18 5 20"
    let bareCases: [(String, String)] = [
        ("가장 큰 수는?\n1 12 2 14 3 16 4 18 5 20", "가장 큰 수는?\n① 12 ② 14 ③ 16 ④ 18 ⑤ 20"),
        ("값은?\n1 -2 2 -1 3 0\n4 1 5 2", "값은?\n① -2 ② -1 ③ 0\n④ 1 ⑤ 2"),
        ("값은?\nx = 2\n1 √2 2 √3 3 2 4 √5", "값은?\nx = 2\n① √2 ② √3 ③ 2 ④ √5"),
    ]
    for (input, expected) in bareCases {
        let fixed = MathOCRFixer.normalizeChoices(input)
        check("숫자만 읽힌 번호: \(input.suffix(12))", fixed == expected, fixed)
    }
    for keep in ["1 2 3 4 5 6 7 8", "f(x) = 1 2 2 3", "1 + 2 + 3 + 4 = 10"] {
        check("번호 아님: \(keep)", MathOCRFixer.normalizeChoices(keep) == keep, MathOCRFixer.normalizeChoices(keep))
    }
    check("(D 로 읽힌 ①", MathOCRFixer.normalizeChoices("(D 3 (2 5 (3 7 (4 9 (5 11") == "① 3 ② 5 ③ 7 ④ 9 ⑤ 11", MathOCRFixer.normalizeChoices("(D 3 (2 5 (3 7 (4 9 (5 11"))
    let flow = MathOCRFixer.fix("두 수의 합은?\n1 12 2 14 3 16 4 18 5 20")
    check("fix 전체: 숫자 번호", flow.contains("① 12 ② 14 ③ 16 ④ 18 ⑤ 20"), flow)
}
