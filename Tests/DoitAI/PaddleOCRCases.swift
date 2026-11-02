import Foundation

// MARK: - 정밀 인식(PaddleOCR-VL): LaTeX → 앱 글 모양, 되풀이 멈춤, 언제 쓰는지, 크기·위치 계산

func runPaddleOCRCases() {
    // LaTeX → 앱 글 모양 (모델이 실제로 낸 글: 141장 비교 실험 로그에서)
    let latex: [(String, String)] = [
        ("2. 이차방정식 \\(x^{2}+x-2=0\\)의 두 근 중", "2. 이차방정식 x²+x-2=0의 두 근 중"),
        ("3. 0.3 \\(\\times\\) 0.4의 값은?", "3. 0.3 × 0.4의 값은?"),
        ("④x\\(\\leq\\)3 ⑤x>2", "④x≤3 ⑤x>2"),
        ("4. \\(2^{3} \\times 2^{2}\\)의 값은?", "4. 2³ × 2²의 값은?"),
        ("6. \\(\\frac{1}{2} + \\frac{1}{3}\\)의 값은?", "6. 1/2 + 1/3의 값은?"),
        ("① 2\\(\\sqrt{2}\\) ② \\(2\\sqrt{3}\\)", "① 2√2 ② 2√3"),
        ("\\(\\frac{x+1}{2}\\)", "(x+1)/2"),
        ("\\(\\sqrt{x+1}\\)", "√(x+1)"),
        ("\\(\\sqrt[3]{8}\\)", "3√8"),
        ("\\(3 + \\square = 7\\)", "3 + □ = 7"),
        ("\\(\\angle ABC = 90^{\\circ}\\)", "∠ ABC = 90°"),
        ("2<sup>5</sup>의 값", "2^5의 값"),
        ("\\(x^{10}\\)", "x^10"),
        ("\\(\\log_{2} 8\\)", "log2 8"),
        ("$$a \\ne b$$", "a ≠ b"),
        ("**12.** 다음 중", "12. 다음 중"),
    ]
    for (input, expected) in latex {
        let out = PaddleOCRText.toApp(input)
        check("정밀 인식 LaTeX: \(input)", out == expected, out)
    }
    // 표: 칸을 띄어 이음, 구분 줄은 버림
    let table = PaddleOCRText.toApp("| 물질 | 상태 |\n|---|---|\n| 물 | 액체 |")
    check("정밀 인식 표 (마크다운)", table == "물질   상태\n물   액체", table)
    let html = PaddleOCRText.toApp("<table><tr><td>apple</td><td>사과</td></tr><tr><td>run</td><td>달리다</td></tr></table>")
    check("정밀 인식 표 (HTML)", html == "apple   사과\nrun   달리다", html)
    // 한 칸 안의 \\ 줄바꿈은 여러 줄로
    let multi = PaddleOCRText.toApp("\\(\\begin{cases} x+y=3 \\\\ x-y=1 \\end{cases}\\)")
    check("정밀 인식 연립방정식 줄바꿈", multi.components(separatedBy: "\n").count == 2 && multi.contains("x+y=3") && multi.contains("x-y=1"), multi)

    // 앱에 넘길 글: 수학은 MathOCRFixer까지, 과목은 보기 번호 정리
    let math = PaddleOCRText.mathText("6. \\(\\frac{1}{2} + \\frac{1}{3}\\)의 값은?\n① \\(\\frac{5}{6}\\) ② \\(\\frac{2}{5}\\) ③ \\(\\frac{1}{6}\\) ④ \\(\\frac{3}{5}\\) ⑤ \\(\\frac{7}{6}\\)")
    check("정밀 인식 수학 글: 분수 문제", math.contains("1/2 + 1/3") && math.contains("① 5/6") && math.contains("⑤ 7/6") && !math.contains("\\"), math)
    let root = PaddleOCRText.mathText("8. \\(\\sqrt{12}\\)를 간단히 하면?\n① \\(2\\sqrt{2}\\) ② \\(2\\sqrt{3}\\) ③ \\(3\\sqrt{2}\\) ④ \\(4\\sqrt{3}\\) ⑤ 6")
    check("정밀 인식 수학 글: 제곱근", root.contains("√12") && root.contains("② 2√3") && root.contains("⑤ 6"), root)
    let subject = PaddleOCRText.subjectText("3. 다음 중 포유류가 아닌 것은?\n① 고래 ② 박쥐 ③ 펭귄 ④ 사자 ⑤ 토끼")
    check("정밀 인식 과목 글", subject.contains("③ 펭귄") && subject.hasPrefix("3. 다음 중"), subject)
    let english = PaddleOCRText.subjectText("Choose the word that means \"happy\".\n① sad ② glad ③ angry")
    check("정밀 인식 영어 문장은 그대로", english.contains("Choose the word that means \"happy\".") && english.contains("② glad"), english)
    check("정밀 인식: 빈 결과는 쓰지 않음", !PaddleOCRText.isUsable("") && !PaddleOCRText.isUsable(" . ") && PaddleOCRText.isUsable("x=3"))

    // 되풀이 고리 찾기
    let prefix = Array(1...30)
    let loop = prefix + Array(repeating: [7, 8, 9, 10, 11, 12, 13, 14], count: 8).flatMap { $0 }
    let cut = PaddleRepetition.cutIndex(loop)
    check("되풀이: 8토큰 묶음 8번 → 한 번만 남김", cut == 38, "\(String(describing: cut))")
    check("되풀이: 보통 글은 그대로", PaddleRepetition.cutIndex(Array(1...200)) == nil)
    check("되풀이: 같은 토큰 10번은 괜찮음 (빈칸 ____ 같은 것)", PaddleRepetition.cutIndex(prefix + Array(repeating: 5, count: 10)) == nil)
    check("되풀이: 같은 토큰 40번은 멈춤", PaddleRepetition.cutIndex(prefix + Array(repeating: 5, count: 40)) == 31)
    check("되풀이: 보기 ①②③ 두 번 되풀이는 괜찮음", PaddleRepetition.cutIndex(prefix + [1, 2, 3, 4, 1, 2, 3, 4]) == nil)
    let midway = prefix + Array(repeating: [21, 22, 23, 24, 25], count: 9).flatMap { $0 } + [21, 22]
    check("되풀이: 묶음 중간에서 끝나도 찾음", PaddleRepetition.cutIndex(midway) != nil)
    let lines = PaddleRepetition.collapseRepeatedLines("문제\n같은 줄\n같은 줄\n같은 줄\n같은 줄\n같은 줄\n끝")
    check("되풀이 줄 하나로", lines == "문제\n같은 줄\n끝", lines)
    let twice = PaddleRepetition.collapseRepeatedLines("가\n나\n나\n다")
    check("두 번 같은 줄은 그대로", twice == "가\n나\n나\n다", twice)

    // 토큰 → 글: 끝에 남은 바이트 조각도 (O²⁻의 ⁻ = E2 81 BB), ▁는 띄어쓰기, 특수 토큰은 뺌
    let decoded = PaddleDecode.text(pieces: ["\u{2581}⑤", "\u{2581}O", "²", "<0xE2>", "<0x81>", "<0xBB>"])
    check("토큰 글: 끝 바이트 조각", decoded == " ⑤ O²⁻", decoded)
    let jamo = PaddleDecode.text(pieces: ["ㄋ", ",", "\u{2581}", "<0xE3>", "<0x84>", "<0xB3>", ",", "\u{2581}ㄷ", "</s>", "<|LOC_3|>"])
    check("토큰 글: 가운데 바이트 조각 + 특수 토큰", jamo == "ㄋ, ㄳ, ㄷ", jamo)
    check("바이트 조각 읽기", PaddleDecode.byte("<0x0A>") == 10 && PaddleDecode.byte("<0xZZ>") == nil && PaddleDecode.byte("abc") == nil)

    // 언제 정밀 인식을 쓰는지
    let gb: UInt64 = 1_073_741_824
    let six: UInt64 = 5_900_000_000, four: UInt64 = 4 * gb - 300_000_000, eight: UInt64 = 8 * gb
    for purpose in [PaddleOCRRouting.Purpose.mathProblem, .subjectProblem, .chatPhoto] {
        check("정밀 인식 사용: \(purpose) (모델 있음, 6GB)", PaddleOCRRouting.shouldUsePaddle(purpose, supported: true, installed: true, physicalMemory: six))
        check("정밀 인식 안 씀: \(purpose) 모델 없음", !PaddleOCRRouting.shouldUsePaddle(purpose, supported: true, installed: false, physicalMemory: eight))
        check("정밀 인식 안 씀: \(purpose) 4GB 기기", !PaddleOCRRouting.shouldUsePaddle(purpose, supported: true, installed: true, physicalMemory: four))
        check("정밀 인식 안 씀: \(purpose) 시뮬레이터", !PaddleOCRRouting.shouldUsePaddle(purpose, supported: false, installed: true, physicalMemory: eight))
        check("정밀 인식 안 씀: \(purpose) 세 번 실패", !PaddleOCRRouting.shouldUsePaddle(purpose, supported: true, installed: true, physicalMemory: eight, failures: 3))
        check("정밀 인식 사용: \(purpose) 실패 두 번까지는 다시", PaddleOCRRouting.shouldUsePaddle(purpose, supported: true, installed: true, physicalMemory: eight, failures: 2))
    }
    for purpose in [PaddleOCRRouting.Purpose.wordBook, .handwriting, .problemSplit] {
        check("Vision 그대로: \(purpose)", !PaddleOCRRouting.shouldUsePaddle(purpose, supported: true, installed: true, physicalMemory: eight))
    }
    check("메모리 기준: 5.5GB 이상", PaddleOCRRouting.deviceCanRun(physicalMemory: 5_500_000_000) && !PaddleOCRRouting.deviceCanRun(physicalMemory: 5_499_999_999))

    // 사진 크기 (파이썬 smart_resize와 같은 값: 반올림 짝수까지)
    let sizes: [((Int, Int), (Int, Int))] = [
        ((1600, 1200), (1148, 840)), ((100, 300), (196, 588)), ((406, 350), (392, 336)),
        ((1000, 1000), (980, 980)), ((3000, 2250), (1148, 840)), ((70, 900), (112, 1232)), ((14, 500), (84, 2016)),
    ]
    for ((h, w), expected) in sizes {
        let got = PaddleImageSize.target(height: h, width: w)
        check("정밀 인식 사진 크기 \(h)×\(w)", got?.height == expected.0 && got?.width == expected.1, "\(String(describing: got))")
    }
    check("정밀 인식 이미지 토큰 수", PaddleImageSize.imageTokens(height: 1148, width: 840) == 1230)
    check("너무 긴 사진은 못 읽음", PaddleImageSize.target(height: 28, width: 6000) == nil)

    // 프롬프트
    check("프롬프트 글 (대화 틀과 같음)", PaddlePrompt.text() == "<|begin_of_sentence|>User: <|IMAGE_START|><|IMAGE_PLACEHOLDER|><|IMAGE_END|>OCR:\nAssistant:\n")
    check("사진 자리 늘리기", PaddlePrompt.expand([5, 9, 6], imageTokenID: 9, count: 3) == [5, 9, 9, 9, 6])
    check("사진 자리가 둘이면 안 됨", PaddlePrompt.expand([9, 5, 9], imageTokenID: 9, count: 3) == nil)

    // 3D 위치: 글 0,1 → 사진 2×3 (세로·가로) → 글은 사진의 가장 큰 자리 다음부터
    let index = PaddleRopeIndex.positions(tokens: [1, 2, 9, 9, 9, 9, 9, 9, 3, 4], imageTokenID: 9, gridH: 2, gridW: 3)
    check("위치 t", index.t == [0, 1, 2, 2, 2, 2, 2, 2, 5, 6], "\(index.t)")
    check("위치 h", index.h == [0, 1, 2, 2, 2, 3, 3, 3, 5, 6], "\(index.h)")
    check("위치 w", index.w == [0, 1, 2, 3, 4, 2, 3, 4, 5, 6], "\(index.w)")
    check("위치 delta (다음 토큰 = 캐시 길이 + delta)", index.delta == -3, "\(index.delta)")
    let textOnly = PaddleRopeIndex.positions(tokens: [1, 2, 3], imageTokenID: 9, gridH: 2, gridW: 2)
    check("글만 있으면 차례대로", textOnly.t == [0, 1, 2] && textOnly.delta == 0)
    let angles = PaddleRopeIndex.angles(t: [1], h: [2], w: [3], headDim: 128, theta: 500_000, sections: [16, 24, 24])
    let inv = { (j: Int) -> Float in Float(1.0 / pow(500_000.0, Double(2 * j) / 128.0)) }
    check("RoPE 구역: 0~15는 t", abs(angles[0] - 1) < 1e-6 && abs(angles[15] - inv(15)) < 1e-6)
    check("RoPE 구역: 16~39는 h", abs(angles[16] - 2 * inv(16)) < 1e-6 && abs(angles[39] - 2 * inv(39)) < 1e-6)
    check("RoPE 구역: 40~63은 w, 뒤 절반은 같음", abs(angles[40] - 3 * inv(40)) < 1e-6 && angles[64] == angles[0] && angles[127] == angles[63])
    let vision = PaddleRopeIndex.visionAngles(gridH: 2, gridW: 3, dim: 36)
    check("사진 RoPE: 조각(1,2)는 세로 1, 가로 2", vision.count == 6 * 36 && vision[5 * 36] == 1 && vision[5 * 36 + 18] == 2)

    // 위치 임베딩 늘리기: 같은 크기면 그대로
    let same = PaddleBilinear.axis(input: 27, output: 27)
    check("쌍선형: 같은 크기는 그대로", same.enumerated().allSatisfy { $0.element.lo == $0.offset && abs($0.element.weight) < 1e-5 })
    let up = PaddleBilinear.axis(input: 2, output: 4)
    check("쌍선형: 2 → 4 (가장자리 무게는 파이썬처럼 음수)", up[0].lo == 0 && abs(up[0].weight + 0.25) < 1e-6 && up[1].lo == 0 && abs(up[1].weight - 0.25) < 1e-6 && up[3].lo == 1 && up[3].hi == 1)
    let corners = PaddleBilinear.corners(inputSide: 27, height: 3, width: 5)
    check("쌍선형 네 모서리 무게 합은 1", (0..<15).allSatisfy { i in abs(corners.weights.map { $0[i] }.reduce(0, +) - 1) < 1e-5 })

    // 양자화 설정 알아내기
    check("4비트 64묶음", PaddleQuantization.infer(packedColumns: 128, scaleColumns: 16, inputDimensions: 1024).map { [$0.groupSize, $0.bits] } == [64, 4])
    check("8비트 32묶음", PaddleQuantization.infer(packedColumns: 256, scaleColumns: 32, inputDimensions: 1024).map { [$0.groupSize, $0.bits] } == [32, 8])
    check("안 맞으면 nil", PaddleQuantization.infer(packedColumns: 100, scaleColumns: 16, inputDimensions: 1024) == nil)
}
