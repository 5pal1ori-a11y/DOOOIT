import Foundation

// MARK: - 사진 속 학생 필기 지우기 (HandwritingFilter): 색·연함·기울기·내용으로 판정, 인쇄 글자는 그대로

/// 흰 종이 사진 (첫 줄이 위)
private struct Paper {
    var p: HandwritingFilter.Pixels
    init(p: HandwritingFilter.Pixels) { self.p = p }
    init(_ w: Int, _ h: Int) { p = HandwritingFilter.Pixels(width: w, height: h, rgba: [UInt8](repeating: 250, count: w * h * 4)) }
    mutating func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: (UInt8, UInt8, UInt8)) {
        for yy in max(0, y)..<min(p.height, y + h) { for xx in max(0, x)..<min(p.width, x + w) { set(xx, yy, c) } }
    }
    mutating func set(_ x: Int, _ y: Int, _ c: (UInt8, UInt8, UInt8)) {
        guard x >= 0, y >= 0, x < p.width, y < p.height else { return }
        let i = (y * p.width + x) * 4
        p.rgba[i] = c.0; p.rgba[i + 1] = c.1; p.rgba[i + 2] = c.2
    }
    /// 글자 모양 대신: 글자 칸마다 세로 획 두 개 (두께 3)
    mutating func glyphs(_ x: Int, _ y: Int, count: Int, size: Int, _ c: (UInt8, UInt8, UInt8)) {
        for k in 0..<count {
            let gx = x + k * size
            fill(gx + size / 5, y + size / 6, 3, size * 2 / 3, c)
            fill(gx + size * 3 / 5, y + size / 6, 3, size * 2 / 3, c)
            fill(gx + size / 5, y + size / 2, size * 2 / 5 + 3, 3, c)
        }
    }
    mutating func ring(cx: Int, cy: Int, r: Int, _ c: (UInt8, UInt8, UInt8)) {
        for a in 0..<720 {
            let t = Double(a) * .pi / 360
            for d in 0..<3 {
                set(cx + Int((Double(r + d) * cos(t)).rounded()), cy + Int((Double(r + d) * sin(t)).rounded()), c)
            }
        }
    }
    func color(_ x: Int, _ y: Int) -> (Int, Int, Int) {
        let i = (y * p.width + x) * 4
        return (Int(p.rgba[i]), Int(p.rgba[i + 1]), Int(p.rgba[i + 2]))
    }
}

/// 글자 칸마다 상자를 붙인 줄
private func line(_ text: String, x: Int, y: Int, size: Int, confidence: Float = 1, angle: Double = 0) -> HandwritingFilter.Line {
    var glyphs: [HandwritingFilter.Glyph] = []
    var cx = x
    for ch in text {
        glyphs.append(HandwritingFilter.Glyph(char: ch, box: ch.isWhitespace ? nil : CGRect(x: cx, y: y, width: size, height: size), ink: nil))
        cx += size
    }
    return HandwritingFilter.Line(text: text, confidence: confidence, box: CGRect(x: x, y: y, width: cx - x, height: size), angle: angle, glyphs: glyphs)
}

func runHandwritingCases() {
    let black: (UInt8, UInt8, UInt8) = (20, 20, 25), blue: (UInt8, UInt8, UInt8) = (30, 60, 200)
    let red: (UInt8, UInt8, UInt8) = (210, 30, 30), pencil: (UInt8, UInt8, UInt8) = (150, 150, 152)

    // 1) 인쇄만 있는 쪽: 아무것도 지우지 않음
    var plain = Paper(600, 260)
    plain.glyphs(20, 20, count: 10, size: 30, black)
    plain.glyphs(20, 80, count: 8, size: 30, black)
    let plainLines = [line("다음 중 일차방정식의 해는", x: 20, y: 20, size: 30), line("① 2 ② 3 ③ 4", x: 20, y: 80, size: 30)]
    let r1 = HandwritingFilter.clean(plain.p, lines: plainLines, mode: .text)
    check("필기: 인쇄만 있으면 그대로", r1.report.erased == 0 && r1.pixels.rgba == plain.p.rgba, r1.report.lines.joined(separator: " / "))
    check("필기: 인쇄 기준은 검정", r1.report.reference?.hue == .neutral && (r1.report.reference?.contrast ?? 0) > 0.8, "\(String(describing: r1.report.reference))")

    // 2) 파란 펜으로 쓴 풀이 줄 (한글 없음) → 지움, 인쇄는 그대로
    var bluePage = plain
    bluePage.glyphs(40, 160, count: 3, size: 34, blue)
    let blueLines = plainLines + [line("x=4", x: 40, y: 160, size: 34, confidence: 0.5, angle: 5)]
    let r2 = HandwritingFilter.clean(bluePage.p, lines: blueLines, mode: .text)
    let blueToken = r2.report.tokens.first { $0.text == "x=4" }
    check("필기: 파란 펜 풀이는 필기", blueToken?.hand == true, r2.report.lines.joined(separator: " / "))
    check("필기: 인쇄 줄은 필기 아님", r2.report.tokens.filter { $0.line < 2 }.allSatisfy { !$0.hand })
    let afterBlue = Paper(p: r2.pixels)
    check("필기: 파란 획 지움", afterBlue.color(40 + 34 / 5 + 1, 160 + 15).2 > 200 && afterBlue.color(40 + 34 / 5 + 1, 160 + 15).0 > 200, "\(afterBlue.color(47, 175))")
    check("필기: 검은 인쇄 획은 남김", afterBlue.color(20 + 30 / 5 + 1, 20 + 12).0 < 60)

    // 3) 연필(연한 회색) 계산 → 지움
    var pencilPage = plain
    pencilPage.glyphs(300, 150, count: 4, size: 36, pencil)
    let r3 = HandwritingFilter.clean(pencilPage.p, lines: plainLines + [line("2x=8", x: 300, y: 150, size: 36, confidence: 0.3, angle: -7)], mode: .text)
    check("필기: 연필 계산은 필기", r3.report.tokens.first { $0.text == "2x=8" }?.hand == true, r3.report.lines.joined(separator: " / "))
    check("필기: 연필 획 지움", Paper(p: r3.pixels).color(300 + 36 / 5 + 1, 150 + 15).0 > 230)

    // 4) 파란색으로 인쇄한 한글 머리말 (반듯·신뢰도 높음) → 남김
    var header = plain
    header.glyphs(20, 150, count: 6, size: 30, blue)
    let r4 = HandwritingFilter.clean(header.p, lines: [line("개념 확인 문제", x: 20, y: 150, size: 30), plainLines[0]], mode: .text)
    check("필기: 색으로 인쇄한 머리말은 남김", r4.report.tokens.allSatisfy { !$0.hand } && Paper(p: r4.pixels).color(20 + 30 / 5 + 1, 150 + 12).2 > 150 && Paper(p: r4.pixels).color(27, 162).0 < 80,
          r4.report.lines.joined(separator: " / "))

    // 5) 보기 번호에 친 빨간 동그라미 (글자로 안 읽힘) → 동그라미만 지우고 번호는 남김
    var circled = plain
    circled.ring(cx: 20 + 30 * 7 + 15, cy: 95, r: 26, red)
    let r5 = HandwritingFilter.clean(circled.p, lines: plainLines, mode: .text)
    let after5 = Paper(p: r5.pixels)
    check("필기: 보기 동그라미 지움", after5.color(20 + 30 * 7 + 15 + 27, 95).1 > 200, "\(after5.color(262, 95)) \(r5.report.lines.joined(separator: " / "))")
    check("필기: 동그라미 안 번호는 남김", after5.color(20 + 30 * 7 + 30 / 5 + 1, 80 + 12).0 < 60)

    // 4-2) 문제 한가운데 따로 선 짧은 파란 한글(반듯해도 신뢰도 높음) → 펜 메모로 지움
    var memo = plain
    memo.glyphs(20, 150, count: 4, size: 30, blue)
    let r4b = HandwritingFilter.clean(memo.p, lines: plainLines + [line("여기 중요", x: 20, y: 150, size: 30)], mode: .text)
    check("필기: 문제 가운데 짧은 파란 한글 메모는 필기", r4b.report.tokens.contains { $0.text.contains("여기") && $0.hand }, r4b.report.lines.joined(separator: " / "))

    // 4-3) 색이 인쇄와 같은 검정 펜 풀이·메모: 보기 블록 아래 빈 자리에 쓴 줄은 필기
    //  - 보기가 줄마다 ①로 시작해도 (한 줄에 ①②가 둘 없어도) 보기 블록으로 봄
    //  - 기운 글씨는 상자가 위로 겹쳐도 줄 가운데로 판정
    let choiceRows = [line("3. 윗글과 일치하지 않는 것은?", x: 20, y: 20, size: 30), line("① 글쓴이는 시골에서 자랐다.", x: 20, y: 70, size: 30),
                      line("② 할머니는 매일 아침 밭에 나가셨다.", x: 20, y: 120, size: 30), line("③ 마을 앞에는 큰 강이 흘렀다.", x: 20, y: 170, size: 30)]
    let noteBelow = line("오답 이유: 개념 부족", x: 40, y: 190, size: 36, confidence: 0.5, angle: 4.8)
    let r4c = HandwritingFilter.tokens(choiceRows + [noteBelow], reference: HandwritingFilter.Reference(contrast: 0.9, peak: 0.9, chroma: 5, hue: .neutral, lineHeight: 30, angle: 0), mode: .text)
    check("필기: 줄마다 ①로 시작하는 보기 아래 검정 펜 메모는 필기", r4c.filter { $0.line == 4 }.allSatisfy(\.hand), r4c.filter { $0.line == 4 }.map { "\($0.text) \($0.score) \($0.reasons)" }.joined(separator: " / "))
    check("필기: 보기 줄 자체는 필기 아님", r4c.filter { $0.line < 4 }.allSatisfy { !$0.hand })
    // 보기 아래라도 영어 문장·(A)-(C)-(B) 순서 보기는 인쇄
    let engRows = [line("5. 어법상 올바른 것은?", x: 20, y: 20, size: 30), line("① She go to school every day.", x: 20, y: 70, size: 30),
                   line("② He enjoyed to swim in the lake.", x: 20, y: 120, size: 30), line("(A)-(C)-(B)", x: 20, y: 200, size: 30, confidence: 0.3),
                   line("I enjoyed to swim in the lake.", x: 20, y: 250, size: 30, confidence: 0.5)]
    let r4d = HandwritingFilter.tokens(engRows, reference: HandwritingFilter.Reference(contrast: 0.9, peak: 0.9, chroma: 5, hue: .neutral, lineHeight: 30, angle: 0), mode: .text)
    check("필기: 보기 아래 영어 문장·순서 보기는 인쇄", r4d.allSatisfy { !$0.hand }, r4d.filter(\.hand).map(\.text).joined(separator: " / "))

    // 4-4) 인쇄 글이 두어 줄뿐인 쪽에 큰 글씨 풀이: 지울 잉크가 페이지 잉크의 40%를 넘어도 글자 판정이 믿을 만하면 지움
    var sparse = Paper(700, 360)
    sparse.glyphs(20, 20, count: 14, size: 30, black)
    sparse.glyphs(60, 150, count: 6, size: 60, black)
    let sparseLines = [line("2. 안에 알맞은 수를 쓰시오.", x: 20, y: 20, size: 30), line("16÷4=4", x: 60, y: 150, size: 60, confidence: 0.3)]
    let r4e = HandwritingFilter.clean(sparse.p, lines: sparseLines, mode: .text)
    check("필기: 인쇄가 적고 풀이가 큰 쪽도 풀이는 필기", r4e.report.tokens.filter { $0.line == 1 }.allSatisfy(\.hand), r4e.report.lines.joined(separator: " / "))
    check("필기: 인쇄가 적고 풀이가 큰 쪽도 풀이 획을 지움", r4e.report.erased > 500 && Paper(p: r4e.pixels).color(60 + 60 / 5 + 1, 150 + 20).0 > 200, r4e.report.lines.joined(separator: " / "))
    check("필기: 그때도 인쇄 줄은 남김", Paper(p: r4e.pixels).color(20 + 30 / 5 + 1, 20 + 12).0 < 60)

    // 4-5) 흐릿한 가장자리(번짐)까지 지움: 글자 윤곽이 희미하게 남으면 인식이 다시 읽음. 인쇄 글자는 그대로
    var fringe = Paper(700, 300)
    for r in 0..<3 {   // 보기 줄 (글자 칸마다 획) 3개
        fringe.glyphs(20, 60 + r * 40, count: 12, size: 30, black)
    }
    fringe.glyphs(20, 10, count: 12, size: 30, black)
    let noteX = 40, noteY = 230, noteSize = 36
    // 번짐: 획 둘레 한 칸을 연한 회색으로 먼저 칠하고 그 위에 진한 획
    for k in 0..<6 {
        let gx = noteX + k * noteSize
        fringe.fill(gx + noteSize / 5 - 1, noteY + noteSize / 6 - 1, 5, noteSize * 2 / 3 + 2, (225, 225, 227))
        fringe.fill(gx + noteSize * 3 / 5 - 1, noteY + noteSize / 6 - 1, 5, noteSize * 2 / 3 + 2, (225, 225, 227))
    }
    fringe.glyphs(noteX, noteY, count: 6, size: noteSize, black)
    var fringeLines = [line("3. 윗글과 일치하지 않는 것은?", x: 20, y: 10, size: 30)]
    fringeLines += (0..<3).map { r in line("① 글쓴이는 시골에서 자랐다.", x: 20, y: 60 + r * 40, size: 30) }
    fringeLines.append(line("오답이유개념", x: noteX, y: noteY, size: noteSize, confidence: 0.5, angle: 4.8))
    let r4f = HandwritingFilter.clean(fringe.p, lines: fringeLines, mode: .text)
    var faint = 0
    let after4f = Paper(p: r4f.pixels)
    for y in noteY..<(noteY + noteSize) { for x in noteX..<(noteX + 6 * noteSize) where after4f.color(x, y).0 < 238 { faint += 1 } }
    check("필기: 판정한 필기 자리는 흐린 번짐까지 비움", r4f.report.tokens.filter { $0.line == 4 }.allSatisfy(\.hand) && faint == 0, "남은 \(faint)px \(r4f.report.lines.joined(separator: " / "))")
    var printedSame = true
    for y in 10..<40 { for x in 20..<(20 + 12 * 30) where after4f.color(x, y).0 != fringe.color(x, y).0 { printedSame = false } }
    check("필기: 번짐을 지워도 인쇄 줄은 그대로", printedSame)

    // 4-6) 글자 판정이 지나치게 많은 쪽(글자 대부분이 필기)은 지우지 않음 (기준을 잘못 잡은 쪽)
    var mostly = Paper(800, 200)
    mostly.glyphs(20, 20, count: 3, size: 30, black)
    mostly.glyphs(20, 100, count: 12, size: 60, black)
    let r4g = HandwritingFilter.clean(mostly.p, lines: [line("문제", x: 20, y: 20, size: 30), line("x=4 x=5 x=6 x=7", x: 20, y: 100, size: 60, confidence: 0.3)], mode: .text)
    check("필기: 글자 대부분을 필기로 보면 그대로 둠", r4g.report.erased == 0, r4g.report.lines.joined(separator: " / "))

    // 4-7) 책상 그림자 같은 넓은 연한 덩어리가 지울 양을 부풀려도 필기 자리 안 덩어리는 지움
    var smear = Paper(700, 420)
    smear.glyphs(20, 10, count: 12, size: 30, black)
    for r in 0..<3 { smear.glyphs(20, 60 + r * 40, count: 12, size: 30, black) }
    smear.fill(40, 300, 620, 110, (185, 185, 188))                  // 넓은 연회색 얼룩
    smear.glyphs(40, 190, count: 6, size: 36, black)               // 보기 아래 검정 펜 메모
    var smearLines = [line("3. 윗글과 일치하지 않는 것은?", x: 20, y: 10, size: 30)]
    smearLines += (0..<3).map { r in line("① 글쓴이는 시골에서 자랐다.", x: 20, y: 60 + r * 40, size: 30) }
    smearLines.append(line("오답이유개념", x: 40, y: 190, size: 36, confidence: 0.5, angle: 4.8))
    let r4h = HandwritingFilter.clean(smear.p, lines: smearLines, mode: .text)
    check("필기: 넓은 얼룩이 섞여도 필기 자리 안 글씨는 지움", r4h.report.erased > 300 && Paper(p: r4h.pixels).color(40 + 36 / 5 + 1, 190 + 20).0 > 200, r4h.report.lines.joined(separator: " / "))
    check("필기: 얼룩 자체는 건드리지 않음", Paper(p: r4h.pixels).color(300, 350).0 < 200)

    // 6) 그림 읽기: 파란 선(인쇄 그림일 수 있음)은 남기고, 필기로 판정한 글자만 지움
    var figure = plain
    figure.fill(100, 200, 400, 3, blue)
    let r6 = HandwritingFilter.clean(figure.p, lines: plainLines, mode: .figure)
    check("필기: 그림 읽기에선 색 선 남김", r6.report.erased == 0)

    // 6-2) 인쇄 글자를 지나는 파란 밑줄: 글자는 인쇄(가장 진한 곳이 검정), 밑줄만 지움
    var underlined = plain
    underlined.fill(20, 20 + 20, 300, 3, blue)
    let r7 = HandwritingFilter.clean(underlined.p, lines: plainLines, mode: .text)
    let after7 = Paper(p: r7.pixels)
    check("필기: 밑줄 지난 인쇄 글자는 인쇄", r7.report.tokens.allSatisfy { !$0.hand }, r7.report.lines.joined(separator: " / "))
    check("필기: 글자를 지나는 펜 밑줄 지움", after7.color(20 + 30 * 3 + 2, 41).2 < 230 ? false : after7.color(20 + 30 * 3 + 2, 41).0 > 200, "\(after7.color(112, 41))")
    check("필기: 밑줄 지나도 인쇄 획은 남김", after7.color(20 + 30 / 5 + 1, 20 + 8).0 < 60)

    // 6-3) 흐린 사진의 가는 인쇄 기호(+, 괄호)는 연해 보여도 필기 아님
    var thin = Paper(600, 120)
    thin.glyphs(20, 20, count: 4, size: 30, black)
    thin.fill(20 + 4 * 30 + 12, 28, 1, 14, (140, 140, 142))
    thin.fill(20 + 4 * 30 + 6, 34, 13, 1, (140, 140, 142))
    thin.glyphs(20 + 5 * 30, 20, count: 4, size: 30, black)
    let r8 = HandwritingFilter.clean(thin.p, lines: [line("다음 중 +일차방정", x: 20, y: 20, size: 30)], mode: .text)
    check("필기: 인쇄 줄 속 가는 기호는 필기 아님", r8.report.tokens.allSatisfy { !$0.hand } && r8.report.erased == 0, r8.report.lines.joined(separator: " / "))

    // 6-3b) 앱 안 필기(PencilKit 획·글자 메모)가 문제 인식 입력에 섞이지 않는지 소스 검사
    //  - 필기 획(PKDrawing)을 그림으로 바꿔 읽는 곳은 '내 풀이 읽기'(readHandwriting) 하나뿐이고,
    //  - 필기 데이터를 다루는 화면 파일은 화면을 그림으로 찍어(렌더러·스냅샷) 읽지 않아야 함 (문제 사진 위 필기가 합쳐져 들어가는 길)
    if let files = FileManager.default.enumerator(atPath: ".")?.compactMap({ $0 as? String }).filter({ $0.hasSuffix(".swift") && $0.hasPrefix("Features/") }), !files.isEmpty {
        var strokeReaders: [String] = []
        var mixed: [String] = []
        let renderers = ["UIGraphicsImageRenderer", "ImageRenderer", "drawHierarchy", "snapshotView", "takeSnapshot"]
        for f in files {
            guard let src = try? String(contentsOfFile: f, encoding: .utf8) else { continue }
            if src.contains("PKDrawing") && src.contains("drawing.image(from") { strokeReaders.append(f) }
            if (src.contains("PKDrawing") || src.contains("drawingData") || src.contains("annotationsData")) && renderers.contains(where: { src.contains($0) }) && f != "Features/Learn/WorkCheckCard.swift" { mixed.append(f) }
        }
        check("필기: 획을 그림으로 바꾸는 곳은 풀이 읽기 하나", strokeReaders == ["Features/Learn/WorkCheckCard.swift"], strokeReaders.joined(separator: ", "))
        check("필기: 필기 화면은 화면을 그림으로 찍어 읽지 않음", mixed.isEmpty, mixed.joined(separator: ", "))
        let work = (try? String(contentsOfFile: "Features/Learn/WorkCheckCard.swift", encoding: .utf8)) ?? ""
        check("필기: 풀이 읽기는 필기만 흰 바탕에 그려 읽음(문제 사진과 합치지 않음)", work.contains("readHandwriting(image)") && !work.contains("readMathProblem") && !work.contains("readSubjectProblem"))
    }

    // 6-4) 써 넣은 답 줄
    check("필기 내용: 문제 줄 끝에 덧붙인 답 자리", HandwritingFilter.trailingAnswerNoteStart("크기는? 정답 ②") == 5 && HandwritingFilter.trailingAnswerNoteStart("크기는? 답 3") == 5
          && HandwritingFilter.trailingAnswerNoteStart("정답을 고르시오") == nil && HandwritingFilter.trailingAnswerNoteStart("크기는? ②") == nil && HandwritingFilter.trailingAnswerNoteStart("해는? 답: 3") == 4)
    check("필기 내용: 써 넣은 답 줄", HandwritingFilter.looksLikeAnswerNote("답: 3") && HandwritingFilter.looksLikeAnswerNote("정답 ④")
          && !HandwritingFilter.looksLikeAnswerNote("답을 고르시오.") && !HandwritingFilter.looksLikeAnswerNote("정답과 가장 가까운 것은?"))

    // 6-5) 파란 펜 메모의 한글이 인쇄 한글보다 많아도 기준은 검정 (인쇄를 지우지 않음)
    var scarce = Paper(620, 240)
    scarce.glyphs(20, 20, count: 7, size: 30, black)      // "0.3 × 0.4의 값은?" 처럼 한글이 적은 줄
    scarce.glyphs(60, 150, count: 5, size: 30, blue)      // 파란 펜 메모 (한글 5자)
    let scarceLines = [line("0.3 × 0.4의 값은?", x: 20, y: 20, size: 30), line("여기서 조심하기", x: 60, y: 150, size: 30, confidence: 0.6, angle: 3)]
    let r9 = HandwritingFilter.clean(scarce.p, lines: scarceLines, mode: .text)
    check("필기: 기준은 검정 유지", r9.report.reference?.hue == .neutral, "\(String(describing: r9.report.reference))")
    check("필기: 검정 인쇄 줄은 남김", Paper(p: r9.pixels).color(20 + 30 / 5 + 1, 20 + 10).0 < 60, r9.report.lines.joined(separator: " / "))

    // 7) 내용 판정
    check("필기 내용: 답 쓰기", HandwritingFilter.looksLikeWork("답: 4") && HandwritingFilter.looksLikeWork("x=4") && HandwritingFilter.looksLikeWork("3×4=12"))
    check("필기 내용: 인쇄 문장은 아님", !HandwritingFilter.looksLikeWork("다음 중 옳은 것은?") && !HandwritingFilter.looksLikeWork("2018"))
    let ref = HandwritingFilter.Reference(contrast: 0.9, chroma: 5, hue: .neutral, lineHeight: 30, angle: 0)
    check("필기 색: 파랑", HandwritingFilter.tint(HandwritingFilter.Ink(count: 50, contrast: 0.7, chroma: 150, hue: .blue), ref) == .colored)
    check("필기 색: 연필", HandwritingFilter.tint(HandwritingFilter.Ink(count: 50, contrast: 0.4, chroma: 3, hue: .neutral), ref) == .light)
    check("필기 색: 인쇄", HandwritingFilter.tint(HandwritingFilter.Ink(count: 50, contrast: 0.85, chroma: 8, hue: .neutral), ref) == .native)
}
