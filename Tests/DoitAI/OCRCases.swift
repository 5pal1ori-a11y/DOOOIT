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
    runPhotoFixCases()
    runFractionFinderCases()
}

// MARK: - 쌓은 분수 막대 찾기 (픽셀)

func runFractionFinderCases() {
    let w = 200, h = 120
    func canvas() -> [UInt8] { [UInt8](repeating: 250, count: w * h) }
    // 글자는 두께 2픽셀 테두리 (꽉 찬 네모는 그림으로 봄), 얇은 것(높이·너비 3 이하)은 그대로 채움
    func fill(_ g: inout [UInt8], _ x: Int, _ y: Int, _ bw: Int, _ bh: Int) {
        for yy in y..<(y + bh) {
            for xx in x..<(x + bw) where bw <= 3 || bh <= 3 || xx - x < 2 || x + bw - 1 - xx < 2 || yy - y < 2 || y + bh - 1 - yy < 2 {
                g[yy * w + xx] = 20
            }
        }
    }
    // 글자 크기 30px: 분수 = 분자(10×17) / 막대(22×2) / 분모(10×17)
    var frac = canvas()
    fill(&frac, 30, 50, 22, 2)          // 막대
    fill(&frac, 36, 30, 10, 17)         // 분자
    fill(&frac, 36, 56, 10, 17)         // 분모
    fill(&frac, 70, 45, 14, 3)          // 오른쪽 "=" 위
    fill(&frac, 70, 53, 14, 3)          // 오른쪽 "=" 아래
    fill(&frac, 95, 38, 26, 28)         // 오른쪽 한글 한 글자 (분수보다 작음)
    let found = FractionFinder.bars(gray: frac, width: w, height: h, size: 30)
    check("분수 막대 하나", found.count == 1 && found.first?.x0 == 30 && found.first?.top == 50, "\(found)")
    check("분자·분모 영역", found.first.map { $0.numerator.y == 30 && $0.denominator.y == 52 } == true, "\(found)")
    // "=" 만 있으면 분수 아님
    var eq = canvas()
    fill(&eq, 30, 45, 22, 2); fill(&eq, 30, 53, 22, 2)
    check("등호는 분수 아님", FractionFinder.bars(gray: eq, width: w, height: h, size: 30).isEmpty)
    // "를"처럼 ㅡ 위아래 작은 획 + 옆 글자가 같은 높이 → 분수 아님
    var reul = canvas()
    fill(&reul, 30, 50, 24, 2); fill(&reul, 33, 38, 18, 9); fill(&reul, 33, 55, 18, 9)
    fill(&reul, 60, 37, 22, 28)          // 옆 글자 (같은 높이)
    check("를의 ㅡ는 분수 아님", FractionFinder.bars(gray: reul, width: w, height: h, size: 30).isEmpty)
    // 빼기 기호(위아래 글자 없음)는 분수 아님
    var minus = canvas()
    fill(&minus, 30, 50, 16, 2)
    check("빼기는 분수 아님", FractionFinder.bars(gray: minus, width: w, height: h, size: 30).isEmpty)

    // 지수 위치 (픽셀, 위가 0)
    check("2³: 작고 위에 붙은 숫자", FractionFinder.isSuperscript(base: (100, 128), digit: (92, 109)))
    check("x²: 낮은 x 위로 솟은 숫자", FractionFinder.isSuperscript(base: (112, 128), digit: (95, 111)))
    check("12: 같은 높이 숫자는 지수 아님", !FractionFinder.isSuperscript(base: (100, 128), digit: (100, 128)))
    check("x2: 바닥이 같은 숫자는 지수 아님", !FractionFinder.isSuperscript(base: (112, 128), digit: (100, 128)))

    // 빈칸 네모: 테두리 있고 안이 빔 / 안에 글자가 있으면 아님
    var box = [Bool](repeating: false, count: 60 * 60)
    for i in 10...40 { box[10 * 60 + i] = true; box[40 * 60 + i] = true; box[i * 60 + 10] = true; box[i * 60 + 40] = true }
    let ink = FractionFinder.Ink(mask: box, width: 60, height: 60)
    check("빈 네모", FractionFinder.isEmptyBox(ink, x0: 10, x1: 40, y0: 10, y1: 40))
    var filled = box
    for y in 18...32 { for x in 22...28 { filled[y * 60 + x] = true } }
    check("글자 든 네모는 빈칸 아님", !FractionFinder.isEmptyBox(FractionFinder.Ink(mask: filled, width: 60, height: 60), x0: 10, x1: 40, y0: 10, y1: 40))
    check("선 없는 빈 곳은 빈칸 아님", !FractionFinder.isEmptyBox(FractionFinder.Ink(mask: [Bool](repeating: false, count: 3600), width: 60, height: 60), x0: 10, x1: 40, y0: 10, y1: 40))
    // 철자 추천: rn↔m 같은 착각
    check("Joumey → journey", OCRService.isLikelyMisread(token: "Joumey", guess: "journey"))
    check("eager는 cager의 한 글자 차이", OCRService.isLikelyMisread(token: "cager", guess: "eager"))
    check("전혀 다른 낱말은 아님", !OCRService.isLikelyMisread(token: "apple", guess: "orange"))

    // 따로 읽은 분자·분모 정리
    check("분자 1", MathOCRFixer.fractionPart(" 1 ") == "1")
    check("분자 l → 1", MathOCRFixer.fractionPart("l") == "1")
    check("막대 조각 떼기", MathOCRFixer.fractionPart("3-") == "3")
    check("음수 분자는 그대로", MathOCRFixer.fractionPart("-3") == "-3")
    check("한글은 분자 아님", MathOCRFixer.fractionPart("늘") == nil)
    check("빈 글은 분자 아님", MathOCRFixer.fractionPart("") == nil)
    check("빗금 분수 읽기", MathOCRFixer.fractionParts("3/4").map { $0.numerator == "3" && $0.denominator == "4" } == true)
    check("빗금을 l로", MathOCRFixer.fractionParts("1l2").map { $0.numerator == "1" && $0.denominator == "2" } == true)
    check("빗금 없으면 아님", MathOCRFixer.fractionParts("12") == nil && MathOCRFixer.fractionParts("x/") == nil)
    check("분수 글", MathOCRFixer.fractionText("x+1", "2") == "(x+1)/2" && MathOCRFixer.fractionText("12", "35") == "12/35"
          && MathOCRFixer.fractionText("x", "3") == "x/3", MathOCRFixer.fractionText("x+1", "2"))
}

// MARK: - 사진 테스트(Tests/OCRImages)에서 찾은 잘못 읽기

func runPhotoFixCases() {
    let fixes: [(String, String)] = [
        ("① 2v2 ② 2v3 ③ 3v2 ④ 4v3 ⑤ 6", "① 2√2 ② 2√3 ③ 3√2 ④ 4√3 ⑤ 6"),     // 근호를 v로
        ("① ~2 ② 4~3", "① √2 ② 4√3"),                                      // 근호를 ~로
        ("3. 0.3 x 0.4의 값은?", "3. 0.3 × 0.4의 값은?"),                     // 띄어 쓴 x 는 곱셈
        ("일차함수 y= 2r- 3의 그래프", "일차함수 y= 2x- 3의 그래프"),            // x 를 r 로
        ("식 3*- 1의 값", "식 3x- 1의 값"),
        ("④ l am go to school.", "④ I am go to school."),                    // 영어 I 를 l 로
        ("늘 + ⅓의 값은?", "늘 + 1/3의 값은?"),                                  // 한 글자 분수
        ("① O 0.012 ② @ 0.12 ③ 3 1.2 ④ * 12 ⑤ S 0.7", "① 0.012 ② 0.12 ③ 1.2 ④ 12 ⑤ 0.7"),  // 번호 찌꺼기
        ("① 금새 ② 웬일 ③ 몇일 ④ ④ 어떻해 ⑤ 설레임", "① 금새 ② 웬일 ③ 몇일 ④ 어떻해 ⑤ 설레임"),
        ("2. D+ 17=42", "2. □ + 17=42"),                                     // 맨 앞 빈칸을 D 로
        ("2. + 17=42", "2. □ + 17=42"),
        ("2._+ 17=42", "2.□ + 17=42"),
        ("(x+ 3) 2= x² + 6x+ [", "(x+ 3)²= x² + 6x+ □"),                    // 맨 끝 빈칸을 [ 로
        ("16. 다음 식의 안에 알맞은 수는?", "16. 다음 식의 □ 안에 알맞은 수는?"),   // 빠진 □
        ("_ 안에 알맞은 분수를 구하시오.", "□ 안에 알맞은 분수를 구하시오."),
        ("l 빠르다 ② 예쁘다 ③ 달리다\n④ 높다 ⑤ 푸르다", "① 빠르다 ② 예쁘다 ③ 달리다\n④ 높다 ⑤ 푸르다"),   // ①을 l로
        ("① 왕건 ② 이성계 ③ 세종 ④ 정도전 S 이방원", "① 왕건 ② 이성계 ③ 세종 ④ 정도전 ⑤ 이방원"),     // ⑤를 S로
        ("① ×≤2 ② x<3", "① x≤2 ② x<3"),                                                       // 부등호 앞 x 를 × 로
        ("① 물 ② 이산화 탄소 ③ 빛 ④ 엽록체 s 산소", "① 물 ② 이산화 탄소 ③ 빛 ④ 엽록체 ⑤ 산소"),          // ⑤를 s로
        ("③ They was very happy.\n* I am go to school.\n⑤ We is good friends.", "③ They was very happy.\n④ I am go to school.\n⑤ We is good friends."),
        ("① 금새 ② 웬일 ③ 몇일 ④ 어떻해 ⑤ § 설레임", "① 금새 ② 웬일 ③ 몇일 ④ 어떻해 ⑤ 설레임"),
        ("① m/$ ② kg ③ N ④ J ⑤ W", "① m/s ② kg ③ N ④ J ⑤ W"),
        ("④ I am go to school.\n5 We is good friends.", "④ I am go to school.\n⑤ We is good friends."),
        ("이 부족한 2 풍부한 ③ 위험한 ④ 정직한 ⑤ 조용한", "① 부족한 ② 풍부한 ③ 위험한 ④ 정직한 ⑤ 조용한"),
        ("1 2 2 3 ③ 4 ④ 5 ⑤ 6", "① 2 ② 3 ③ 4 ④ 5 ⑤ 6"),
    ]
    for (input, expected) in fixes {
        let fixed = MathOCRFixer.fix(input).trimmingCharacters(in: .whitespaces)
        check("사진 교정: \(input.prefix(24))", fixed == expected, fixed)
    }
    // 바꾸면 안 되는 것
    for keep in ["① 0 ② 1 ③ 2 ④ 3 ⑤ 4", "반지름이 2r인 원", "x = 3", "I have a pen.", "상자 안에 공이 있다.", "① 3 ② 6 ③ 9 ④ 12 ⑤ 18",
                 "① x = 1 ② x = 2 ③ x = 3 ④ x + 5 = 0", "① 2 ② 3 ④ 5 ⑤ 6"] {
        let fixed = MathOCRFixer.fix(keep)
        check("사진 교정 아님: \(keep)", fixed == keep, fixed)
    }

    // 글줄 기울기: 3° 기운 글줄(작은 네모 글자들) → 3, 반듯하면 nil
    func page(_ degrees: Double) -> [UInt8] {
        let w = 400, h = 300
        var g = [UInt8](repeating: 245, count: w * h)
        let t = tan(degrees * .pi / 180)
        for line in 0..<6 {
            for k in 0..<20 {
                let x0 = 30 + k * 17, baseY = 50 + line * 40
                for dx in 0..<12 {
                    let x = x0 + dx
                    let yTop = Int(Double(baseY) - Double(x) * t)
                    for y in yTop..<(yTop + 14) where y >= 0 && y < h && (dx < 2 || dx > 9 || y - yTop < 2 || y - yTop > 11) { g[y * w + x] = 30 }
                }
            }
        }
        return g
    }
    let tilted = TextSkew.angle(gray: page(3), width: 400, height: 300)
    check("글줄 기울기 3°", tilted.map { abs($0 - 3) < 0.3 } == true, "\(String(describing: tilted))")
    check("반듯한 글줄은 그대로", TextSkew.angle(gray: page(0), width: 400, height: 300) == nil)

    // 비스듬한 보기 줄: 합친 조각이 다시 들어가지 않음
    let slanted = [OCRLine(text: "다음 단어의 뜻으로 알맞은 것은?", confidence: 0.9, box: CGRect(x: 0.05, y: 0.8, width: 0.7, height: 0.04)),
                   OCRLine(text: "① 부족한", confidence: 0.9, box: CGRect(x: 0.05, y: 0.50, width: 0.12, height: 0.04)),
                   OCRLine(text: "② 풍부한", confidence: 0.9, box: CGRect(x: 0.25, y: 0.515, width: 0.12, height: 0.04)),
                   OCRLine(text: "③ 위험한", confidence: 0.9, box: CGRect(x: 0.45, y: 0.53, width: 0.12, height: 0.04)),
                   OCRLine(text: "④ 정직한", confidence: 0.9, box: CGRect(x: 0.65, y: 0.545, width: 0.12, height: 0.04))]
    let printed = OCRService.printedText(from: slanted)
    // Vision은 ①이 든 줄 신뢰도를 0.3으로 줌 → 보기 줄이 버려지면 안 됨
    let lowChoice = [OCRLine(text: "다음 중 일차방정식 2x+3=11의 해는?", confidence: 1, box: CGRect(x: 0.03, y: 0.64, width: 0.42, height: 0.15)),
                     OCRLine(text: "① 2", confidence: OCRService.adjustedConfidence("① 2", 0.3), box: CGRect(x: 0.035, y: 0.336, width: 0.045, height: 0.13)),
                     OCRLine(text: "② 3", confidence: OCRService.adjustedConfidence("② 3", 0.3), box: CGRect(x: 0.22, y: 0.336, width: 0.045, height: 0.13))]
    check("신뢰도 낮은 보기 줄도 남김", OCRService.printedText(from: lowChoice).contains("① 2   ② 3"), OCRService.printedText(from: lowChoice))
    // 검은 글자만 읽은 쪽이 x를 놓치면 같은 자리 원래 줄
    let ink = [OCRLine(text: "5. 이차방정식 22- 5x+ 6= 0의 두 근의 합을", confidence: 0.5, box: CGRect(x: 0.03, y: 0.62, width: 0.44, height: 0.15))]
    let orig = [OCRLine(text: "5. 이차방정식 x2 - 5x+ 6= 0의 두 근의 합을", confidence: 0.5, box: CGRect(x: 0.035, y: 0.624, width: 0.442, height: 0.145))]
    check("검은 글자 읽기가 x를 놓치면 원래 줄", OCRService.chooseInkReading(original: orig, ink: ink).first?.text.hasPrefix("5. 이차방정식 x2") == true)
    check("비스듬한 보기 줄 한 번씩", printed.components(separatedBy: "풍부한").count == 2, printed)
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
