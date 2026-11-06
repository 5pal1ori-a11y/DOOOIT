import Foundation

// MARK: - 필기 판정의 자리 단서 (HandwritingLayout): 색이 인쇄와 같은 검정 펜 풀이·메모를 줄이 놓인 자리로 가름
// 줄 상자는 사진 테스트(맥 Vision)가 실제로 돌려준 값을 줄여 옮긴 것

/// 줄 상자(x, y, 폭, 높이)만 주면 글자 칸마다 인쇄와 같은 검정 잉크를 붙인 줄
private func page(_ text: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double, conf: Float = 1, angle: Double = 0) -> HandwritingFilter.Line {
    let chars = Array(text)
    let step = w / Double(max(1, chars.count))
    let ink = HandwritingFilter.Ink(count: 60, contrast: 0.85, chroma: 6, hue: .neutral, peak: 0.95, bottom: nil, thickness: 3)
    let glyphs = chars.enumerated().map { k, c in
        HandwritingFilter.Glyph(char: c, box: c.isWhitespace ? nil : CGRect(x: x + Double(k) * step, y: y, width: step, height: h), ink: c.isWhitespace ? nil : ink)
    }
    return HandwritingFilter.Line(text: text, confidence: conf, box: CGRect(x: x, y: y, width: w, height: h), angle: angle, glyphs: glyphs)
}

private let blackRef = HandwritingFilter.Reference(contrast: 0.85, peak: 0.95, chroma: 6, hue: .neutral, lineHeight: 40, angle: 0, thickness: 3)

private func verdict(_ tokens: [HandwritingFilter.Token], line: Int) -> String {
    tokens.filter { $0.line == line }.map { "\($0.text)\($0.hand ? "✗" : "·") \(String(format: "%.1f", $0.score)) \($0.reasons.joined(separator: ","))" }.joined(separator: " / ")
}

func runHandwritingLayoutCases() {
    // 1) 보기 번호(①)를 못 읽은 가로 보기 줄 아래의 검정 펜 풀이·메모 (실제 사진 줄 상자)
    let polygon = [
        page("10. 육각형의 내각의 크기의 합은?", 38, 51, 503, 52, conf: 0.5),
        page("360°", 86, 135, 79, 43), page("540°", 358, 135, 79, 43), page("720°", 633, 135, 79, 43),
        page("900°", 912, 135, 77, 43), page("1080°", 1191, 137, 92, 36),
        page("y = 3×-1", 77, 214, 176, 51, conf: 0.3),
        page("- 기울기 3", 62, 267, 230, 48, conf: 0.5, angle: -0.3)
    ]
    let rowBottom = HandwritingFilter.choiceRowBottom(polygon, lineHeight: 40)
    check("필기 자리: 번호 없는 가로 보기 줄을 보기 블록으로 봄", rowBottom != nil && abs(rowBottom! - 178) < 2, "\(String(describing: rowBottom))")
    let t1 = HandwritingFilter.tokens(polygon, reference: blackRef, mode: .text)
    check("필기 자리: 가로 보기 아래 검정 펜 식은 필기", t1.filter { $0.line == 6 }.allSatisfy(\.hand), verdict(t1, line: 6))
    check("필기 자리: 가로 보기 아래 '- 기울기 3' 메모는 필기 (줄머리 기호)", t1.filter { $0.line == 7 }.allSatisfy(\.hand), verdict(t1, line: 7))
    check("필기 자리: 문제 줄과 가로 보기 자체는 인쇄", t1.filter { $0.line <= 5 }.allSatisfy { !$0.hand }, t1.filter { $0.line <= 5 && $0.hand }.map(\.text).joined(separator: " / "))

    // 2) 표(가로 줄 셋 넘게 쌓임)는 보기가 아님: 표 아래 글을 필기로 보지 않음
    var table: [HandwritingFilter.Line] = [page("물질 100g에 녹는 최대 질량을 나타낸 표이다.", 40, 40, 700, 40)]
    for r in 0..<4 {
        for c in 0..<4 { table.append(page(r == 0 ? "온도" : "\(10 * (r + c))", 60 + Double(c) * 180, 110 + Double(r) * 50, 90, 38)) }
    }
    table.append(page("이 물질을 물에 넣었을 때 녹지 않고 남는 양을 구하시오", 40, 360, 700, 40))
    check("필기 자리: 표는 보기 블록이 아님", HandwritingFilter.choiceRowBottom(table, lineHeight: 40) == nil)
    let t2 = HandwritingFilter.tokens(table, reference: blackRef, mode: .text)
    check("필기 자리: 표 아래 인쇄 문장은 인쇄", t2.allSatisfy { !$0.hand }, t2.filter(\.hand).map(\.text).joined(separator: " / "))

    // 3) 문제 줄 끝 옆에 덧붙인 답 (같은 높이, 오른쪽 가까이)
    let order = [
        page("(C) As a result, they also produce oxygen for us.", 26, 240, 378, 22),
        page("답:⑤", 416, 231, 52, 24, conf: 0.5),
        page("① (A) -(C)-(B)", 28, 279, 138, 22), page("② (B) -(A)-(C)", 266, 281, 136, 20), page("③ (B)- (C)-(A)", 504, 281, 138, 20)
    ]
    let cues = HandwritingFilter.layoutCues(order, lineHeight: 22)
    check("필기 자리: 인쇄 줄 끝 옆의 짧은 줄은 줄 끝 옆 단서", cues[1].sideNote && !cues[0].sideNote && !cues[2].sideNote, "\(cues.map(\.sideNote))")
    let t3 = HandwritingFilter.tokens(order, reference: HandwritingFilter.Reference(contrast: 0.85, peak: 0.95, chroma: 6, hue: .neutral, lineHeight: 22, angle: 0, thickness: 3), mode: .text)
    check("필기 자리: 인쇄 줄 끝에 덧붙인 '답:⑤'는 필기", t3.filter { $0.line == 1 }.allSatisfy(\.hand), verdict(t3, line: 1))
    check("필기 자리: 줄 끝 옆 답이 있어도 문제 줄·보기는 인쇄", t3.filter { $0.line != 1 }.allSatisfy { !$0.hand })

    // 4) 줄머리 기호 메모는 한글·영문 글이 이어질 때만 (음수·분수는 아님)
    check("필기 자리: 줄머리 기호 메모", HandwritingFilter.bulletNote("- 기울기 3") && HandwritingFilter.bulletNote("→ 개념 부족") && HandwritingFilter.bulletNote("∴ 답") == false
          && HandwritingFilter.bulletNote("-> 헷갈림") && HandwritingFilter.bulletNote("- note"))
    check("필기 자리: 음수·번호·식은 줄머리 기호 메모가 아님", !HandwritingFilter.bulletNote("-3") && !HandwritingFilter.bulletNote("- 3") && !HandwritingFilter.bulletNote("1. 다음 중")
          && !HandwritingFilter.bulletNote("−2x + 1") && !HandwritingFilter.bulletNote("다음 - 기울기"))

    // 5) 인쇄만 있는 한 문제 (번호·본문·세로 보기): 자리 단서가 아무것도 켜지지 않음
    let printed = [
        page("3. 윗글과 일치하지 않는 것은?", 20, 20, 400, 40),
        page("① 글쓴이는 시골에서 자랐다.", 20, 70, 420, 40), page("② 할머니는 매일 아침 밭에 나가셨다.", 20, 120, 480, 40),
        page("③ 마을 앞에는 큰 강이 흘렀다.", 20, 170, 440, 40), page("④ 글쓴이는 지금도 그곳에 산다.", 20, 220, 440, 40)
    ]
    let printedCues = HandwritingFilter.layoutCues(printed, lineHeight: 40)
    check("필기 자리: 인쇄 문제엔 자리 단서가 없음", printedCues.allSatisfy { $0 == HandwritingFilter.LineCue() }, "\(printedCues)")
    check("필기 자리: 인쇄 문제는 하나도 필기가 아님", HandwritingFilter.tokens(printed, reference: blackRef, mode: .text).allSatisfy { !$0.hand })

    // 6) 위아래와 멀리 떨어져 홀로 선 한글 메모 (문제 줄과 보기 사이 빈 틈)
    let gap = [
        page("5. 다음 중 옳은 것은?", 20, 20, 360, 40),
        page("핵심어 체크", 80, 140, 200, 40, conf: 0.6),
        page("① 첫째 보기", 20, 260, 300, 40)
    ]
    check("필기 자리: 위아래와 떨어져 홀로 선 줄", HandwritingFilter.layoutCues(gap, lineHeight: 40)[1].isolated && !HandwritingFilter.layoutCues(gap, lineHeight: 40)[0].isolated)

    // 7) 보기가 2×2 격자로 놓여 아랫줄의 번호를 못 읽은 문제 (실제 사진 줄 상자): 아랫줄 보기를 필기로 보지 않음
    let gridChoices = [
        page("11. x=2일 때, 식 3x - 1의 값과 같은 것은?", 55, 93, 580, 38, conf: 0.3),
        page("① 2+3", 57, 169, 116, 34, conf: 0.5), page("4 × 2", 546, 173, 76, 27, conf: 0.3),
        page("3×3", 97, 236, 74, 28, conf: 0.3), page("15 ÷ 3", 545, 235, 92, 29, conf: 0.5),
        page("③", 954, 171, 32, 30), page("10 - 4", 994, 175, 91, 24, conf: 0.5)
    ]
    let gridRef = HandwritingFilter.Reference(contrast: 0.85, peak: 0.95, chroma: 6, hue: .neutral, lineHeight: 30, angle: 0, thickness: 3)
    check("필기 자리: 격자 보기의 아랫줄을 알아봄", HandwritingFilter.gridChoiceLines(gridChoices, lineHeight: 30) == [3, 4], "\(HandwritingFilter.gridChoiceLines(gridChoices, lineHeight: 30))")
    let tGrid = HandwritingFilter.tokens(gridChoices, reference: gridRef, mode: .text)
    check("필기 자리: 격자 보기 아랫줄(3×3, 15 ÷ 3)은 인쇄", tGrid.allSatisfy { !$0.hand }, tGrid.filter(\.hand).map { "\($0.text) \($0.reasons)" }.joined(separator: " / "))
    let withNote = gridChoices + [page("x=4", 97, 300, 60, 28, conf: 0.3)]
    let tNote = HandwritingFilter.tokens(withNote, reference: gridRef, mode: .text)
    check("필기 자리: 격자 보기 아래 한 칸짜리 풀이는 필기", tNote.filter { $0.line == 7 }.allSatisfy(\.hand) && tNote.filter { $0.line < 7 }.allSatisfy { !$0.hand },
          tNote.map { "\($0.text)\($0.hand ? "✗" : "·") \($0.reasons)" }.joined(separator: " / "))
}
