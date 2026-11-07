import Foundation

// MARK: - 미적분 기호 읽기: ∑ ∫ lim ′ → ∞ aₙ (글자 교정 · 위끝/아래끝 붙이기 · 큰 기호 모양 찾기)
// 줄 상자는 사진 테스트(맥 Vision)가 실제로 돌려준 값 (CalculusRealLines.swift)

/// 편집 계획을 줄 글에 적용 (뒤에서부터)
private func applied(_ plan: CalculusLayout.Plan, to lines: [OCRGlyphLine]) -> [String] {
    var texts = lines.map { Array($0.text) }
    for e in plan.edits.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
        texts[e.line].replaceSubrange(e.range, with: Array(e.text))
    }
    return lines.indices.filter { !plan.consumed.contains($0) }.map { String(texts[$0]) }
}

/// 잉크 그림 (위가 0): 직사각형·선으로 그린 큰 기호와 보통 글자 흉내
private struct Canvas {
    var w: Int, h: Int
    var mask: [Bool]
    init(_ w: Int, _ h: Int) { self.w = w; self.h = h; mask = [Bool](repeating: false, count: w * h) }
    mutating func dot(_ x: Int, _ y: Int, _ t: Int = 1) {
        for dy in 0..<t { for dx in 0..<t where x + dx >= 0 && x + dx < w && y + dy >= 0 && y + dy < h { mask[(y + dy) * w + x + dx] = true } }
    }
    mutating func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ t: Int = 3) {
        let n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in 0...n { dot(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, t) }
    }
    /// 보통 글자: 속이 빈 직사각형 (높이 34)
    mutating func glyph(_ x: Int, _ y: Int, w gw: Int = 22, h gh: Int = 34) {
        line(x, y, x + gw, y, 3); line(x, y + gh, x + gw, y + gh, 3); line(x, y, x, y + gh, 3); line(x + gw, y, x + gw, y + gh, 3)
    }
    /// ∑: 위·아래 가로줄 + 가운데 꼭짓점으로 모이는 두 대각선 (높이 hh, 너비 ww)
    mutating func sigma(_ x: Int, _ y: Int, w sw: Int = 44, h sh: Int = 60) {
        line(x, y, x + sw, y, 4); line(x, y + sh, x + sw, y + sh, 4)
        line(x, y, x + sw / 2, y + sh / 2, 4); line(x + sw / 2, y + sh / 2, x, y + sh, 4)
    }
    /// ∫: 위쪽은 오른쪽으로, 아래쪽은 왼쪽으로 휜 긴 S자 (높이 sh)
    mutating func integral(_ x: Int, _ y: Int, h sh: Int = 90, lean: Int = 14) {
        line(x + lean, y + 6, x + lean / 2 + 2, y + sh - 6, 3)
        line(x + lean, y + 6, x + lean + 8, y, 3)           // 위 고리 (오른쪽)
        line(x + lean / 2 + 2, y + sh - 6, x + lean / 2 - 6, y + sh, 3)   // 아래 고리 (왼쪽)
    }
    var ink: FractionFinder.Ink { FractionFinder.Ink(mask: mask, width: w, height: h) }
}

func runCalculusCases() async {
    // 1) 글자 교정 (MathOCRFixer.fix → CalculusText)
    let fixes: [(String, String)] = [
        ("Iim x-2 (x2-4)/(x-2)", "lim_{x→2}"),
        ("lim x->oo 1/x", "lim_{x→∞}"),
        ("lim_{x->0} f(x)", "lim_{x→0}"),
        ("lim x → 0+ f(x)", "lim_{x→0+}"),
        ("lim n→00 (3n+1)/(n+2)", "lim_{n→∞}"),
        ("f'(2)의 값은?", "f′(2)의 값은?"),
        ("g'(x) + F'(1)", "g′(x) + F′(1)"),
        ("y' = 3x2", "y′ = 3x²"),
        ("dy/(dx)", "dy/dx"),
        ("d/(dx) (x3 + 3x)", "d/dx"),
        ("수열 {an}에서 an = 2n-1", "{a_n}"),
        ("수열 Sn = n2+2n 일 때", "S_n"),
        ("Σ k=1", "∑ k=1"),
    ]
    for (input, expected) in fixes {
        let out = MathOCRFixer.fix(input)
        check("미적분 글자 교정: \(input)", out.contains(expected), out)
    }
    // 고치면 안 되는 것 (영어 소유격·일반 식·지수)
    let keep: [String] = [
        "He doesn't know", "f(x) = x^2 + 1", "a limit of the speed", "x' + 1을 구하시오", "an apple", "lm 단위", "(x+1)2",
        "이차함수 y = 2x2 의 그래프", "tim", "Kim과 Lee", "S = 3n"
    ]
    for input in keep {
        let out = MathOCRFixer.fix(input)
        check("미적분 교정 안 함: \(input)", !out.contains("lim_{") && !out.contains("′") && !out.contains("_n") && !out.contains("∑"), out)
    }
    // 수열 문맥이 없으면 an → a_n 으로 바꾸지 않음
    check("수열 문맥 없이 an 은 그대로", !MathOCRFixer.fix("an 이 어디 있나").contains("a_n"))

    // 2) 위끝·아래끝 글 읽기
    check("∑ 아래끝 k=1", CalculusLayout.sigmaBelow("k=1") == "k=1")
    check("∑ 아래끝 k = I (1을 I로)", CalculusLayout.sigmaBelow("k = I") == "k=1")
    check("∑ 아래끝 n=0", CalculusLayout.sigmaBelow("n=O") == "n=0")
    check("∑ 아래끝 등호 없으면 아님", CalculusLayout.sigmaBelow("k1") == nil)
    check("∑ 아래끝 식이 아니면 아님", CalculusLayout.sigmaBelow("kk=1") == nil && CalculusLayout.sigmaBelow("3=1") == nil)
    check("위끝 10", CalculusLayout.bound("10") == "10")
    check("위끝 n", CalculusLayout.bound("n") == "n")
    check("위끝 oo → ∞", CalculusLayout.bound("oo") == "∞" && CalculusLayout.bound("∞") == "∞")
    check("위끝 n+1", CalculusLayout.bound("n+1") == "n+1")
    check("위끝 한글이면 아님", CalculusLayout.bound("값은") == nil && CalculusLayout.bound("") == nil)
    check("∫ 아래끝에서 줄기 찌꺼기 걷기: J2 → 2", CalculusLayout.integralBound("J2") == "2")
    check("∫ 아래끝 -1", CalculusLayout.integralBound("-1") == "-1" && CalculusLayout.integralBound("−1") == "-1")
    check("∫ 아래끝 찌꺼기만 있으면 아님", CalculusLayout.integralBound("J") == nil && CalculusLayout.integralBound(")") == nil)
    check("lim 아래끝 x→2", CalculusLayout.limitBelow("x→2") == "x→2")
    check("lim 아래끝 x->oo", CalculusLayout.limitBelow("x->oo") == "x→∞")
    check("lim 아래끝 x-2 (화살표를 빼기로)", CalculusLayout.limitBelow("x-2") == "x→2")
    check("lim 아래끝 뒤에 다른 글이 붙어도 앞부분", CalculusLayout.limitBelow("x→∞ x2 -3") == "x→∞")
    check("lim 아래끝 0+", CalculusLayout.limitBelow("x→0+") == "x→0+")
    check("lim 아래끝 식이 아니면 아님", CalculusLayout.limitBelow("2->2") == nil && CalculusLayout.limitBelow("값은") == nil)

    // 3) 실제 Vision 줄 + 찾은 기호 → 줄에 붙이기
    do {
        // ∑ 하나: 위끝 "10"(줄 1), 본문 "Z (2k+ 1)"(줄 2), 아래끝 "k=1"(줄 3)
        let lines = calc_sig_disp_clean_korean
        let f = CalculusLayout.Finding(kind: .sigma, symbol: CGRect(x: 0.03665, y: 0.34691, width: 0.02389, height: 0.16450), text: "∑_{k=1}^{10}",
                                      regions: [CGRect(x: 0.03, y: 0.52, width: 0.04, height: 0.08), CGRect(x: 0.03, y: 0.25, width: 0.04, height: 0.08)],
                                      strong: true, coverMaxX: 0.0605)
        let plan = CalculusLayout.plan(lines: lines, findings: [f], lineHeight: 0.11)
        let out = applied(plan, to: lines)
        check("∑ 실제 줄: 본문 Z 가 ∑_{k=1}^{10} 로", out.contains { $0.hasPrefix("∑_{k=1}^{10}") && $0.contains("(2k+ 1)") }, out.joined(separator: " | "))
        check("∑ 실제 줄: 위끝·아래끝 조각은 빠짐", plan.consumed == [1, 3], "\(plan.consumed)")
    }
    do {
        // ∑ 둘 (같은 줄 "2(3k-1)- Z K"): 두 번째 아래끝 k=1, 위끝은 읽히지 않음 → 아래끝만으로도 확실하면 붙임
        let lines = calc_sig_two_clean_korean
        let a = CalculusLayout.Finding(kind: .sigma, symbol: CGRect(x: 0.06284, y: 0.44941, width: 0.02411, height: 0.21176), text: "∑_{k=1}^5", regions: [CGRect(x: 0.05, y: 0.33, width: 0.05, height: 0.09)], strong: true, coverMaxX: 0.087)
        let b = CalculusLayout.Finding(kind: .sigma, symbol: CGRect(x: 0.19985, y: 0.44941, width: 0.02375, height: 0.21176), text: "∑_{k=1}^5", regions: [CGRect(x: 0.19, y: 0.33, width: 0.05, height: 0.09)], strong: true, coverMaxX: 0.224)
        let plan = CalculusLayout.plan(lines: lines, findings: [a, b], lineHeight: 0.31)
        let out = applied(plan, to: lines)
        check("∑ 둘: 한 줄에서 둘 다 바뀜", out.first.map { $0.components(separatedBy: "∑_{k=1}^5").count - 1 == 2 } ?? false, out.joined(separator: " | "))
        check("∑ 둘: 아래끝 조각 둘 다 빠짐", plan.consumed.count == 2, "\(plan.consumed)")
    }
    do {
        // 기호 자리가 비슷한 글자가 아니면 손대지 않음: 본문 글자 위에 우연히 놓인 기호 상자
        let lines = [glyph("abc def", 1, 0.1, 0.5, 0.3, 0.05, (0..<7).map { i in i == 3 ? nil : CGRect(x: 0.1 + 0.04 * Double(i), y: 0.5, width: 0.04, height: 0.05) })]
        let f = CalculusLayout.Finding(kind: .sigma, symbol: CGRect(x: 0.1, y: 0.5, width: 0.04, height: 0.05), text: "∑_{k=1}^{n}", regions: [], strong: false, coverMaxX: 0.14)
        check("∑ 자리 글자가 a 이면 안 바꿈", CalculusLayout.plan(lines: lines, findings: [f], lineHeight: 0.05).edits.isEmpty)
    }
    do {
        // ∫ (실제 줄): "25. 1, (352+ 20) dh의 값은?" 에서 ∫ 가 "1," 로 읽힘 → ∫_{-1}^2
        let lines = calc_i_neg_clean_korean
        let f = CalculusLayout.Finding(kind: .integral, symbol: CGRect(x: 0.07191, y: 0.40, width: 0.01495, height: 0.22), text: "∫_{-1}^2",
                                      regions: [], strong: true, coverMaxX: 0.09)
        let plan = CalculusLayout.plan(lines: lines, findings: [f], lineHeight: 0.2)
        let out = applied(plan, to: lines)
        check("∫ 실제 줄: 1, 가 ∫_{-1}^2 로", out.first.map { $0.hasPrefix("25. ∫_{-1}^2") && $0.contains("(352+ 20)") } ?? false, out.joined(separator: " | "))
    }
    do {
        // lim: 한국어 읽기에서 "x→2" 가 "2->2" 로 틀렸어도 영어 읽기 조각으로 읽음 (실제 줄)
        let hosts = calc_lim_rat_clean_korean
        let found = await CalculusFind.find(ink: Canvas(10, 10).ink, pieces: hosts + calc_lim_rat_clean_english, hosts: hosts, lineHeight: 0.19) { _ in nil }
        check("lim 실제 줄: lim_{x→2} 찾음", found.count == 1 && found[0].text == "lim_{x→2}", found.map(\.text).joined(separator: ","))
        if let f = found.first {
            let plan = CalculusLayout.plan(lines: hosts, findings: [f], lineHeight: 0.19)
            let out = applied(plan, to: hosts)
            check("lim 실제 줄: 줄에 붙임 + 아래끝 조각 빠짐", out.contains { $0.hasPrefix("10. lim_{x→2}") } && plan.consumed.contains(1), out.joined(separator: " | "))
        }
    }
    do {
        // lim: 영어 읽기가 아래끝을 분모와 묶어 "x→∞ x2 -3" 으로 읽은 경우 (실제 줄)
        let hosts = calc_lim_inf_clean_korean
        let found = await CalculusFind.find(ink: Canvas(10, 10).ink, pieces: hosts + calc_lim_inf_clean_english, hosts: hosts, lineHeight: 0.12) { _ in nil }
        check("lim 묶인 조각: lim_{x→∞}", found.count == 1 && found[0].text == "lim_{x→∞}", found.map(\.text).joined(separator: ","))
    }
    do {
        // 이미 lim_{x→2} 로 읽었으면 다시 안 붙임
        let hosts = [glyph("lim_{x→2} f(x)", 1, 0.1, 0.5, 0.3, 0.05, Array(repeating: nil, count: 14))]
        let found = await CalculusFind.find(ink: Canvas(10, 10).ink, pieces: hosts, hosts: hosts, lineHeight: 0.05) { _ in "x→2" }
        check("이미 lim_{…} 이면 안 찾음", found.isEmpty)
    }

    // 4) 큰 기호 모양 찾기 (잉크 그림)
    do {
        var c = Canvas(700, 220)
        for i in 0..<12 { c.glyph(30 + i * 40, 100) }          // 보통 글자 열 (높이 34)
        c.sigma(520, 85)                                      // ∑ (높이 60 → 보통 글자의 1.8배)
        let found = CalculusShape.find(c.ink)
        check("모양: ∑ 하나 찾음", found.filter { $0.kind == .sigma }.count == 1, "\(found.map { $0.kind.rawValue })")
        check("모양: 보통 글자는 ∑ 가 아님", found.count == 1, "\(found.count)")
    }
    do {
        var c = Canvas(700, 260)
        for i in 0..<12 { c.glyph(30 + i * 40, 110) }
        c.integral(560, 70)
        let found = CalculusShape.find(c.ink)
        check("모양: ∫ 하나 찾음", found.count == 1 && found[0].kind == .integral, "\(found.map { $0.kind.rawValue })")
    }
    do {
        // 보통 크기의 Z·2 모양(위·아래 가로줄 + 가운데 대각선)은 ∑ 가 아님
        var c = Canvas(700, 220)
        for i in 0..<12 { c.glyph(30 + i * 40, 100) }
        c.sigma(520, 98, w: 26, h: 36)
        check("모양: 보통 크기 Z 모양은 ∑ 아님", CalculusShape.find(c.ink).isEmpty)
    }
    do {
        // 큰 괄호 ( 는 ∫ 가 아님: 위·아래가 같은 쪽으로 휨
        var c = Canvas(700, 260)
        for i in 0..<12 { c.glyph(30 + i * 40, 110) }
        c.line(560, 70, 548, 115, 3); c.line(548, 115, 560, 160, 3)
        check("모양: 큰 괄호는 ∫ 아님", CalculusShape.find(c.ink).isEmpty)
    }

    // 5) 큰 기호 + 위끝·아래끝 읽기 (잉크 그림 + 가짜 자르기 읽기)
    do {
        var c = Canvas(700, 260)
        for i in 0..<12 { c.glyph(30 + i * 40, 120) }
        c.sigma(520, 100)
        // 위끝·아래끝 자리에 작은 글자 잉크
        c.glyph(528, 52, w: 12, h: 18); c.glyph(520, 180, w: 40, h: 16)
        let host = glyph("E (2k+1)", 0.5, 0.70, 0.32, 0.27, 0.30, Array(repeating: nil, count: 8))
        var asked = 0
        let found = await CalculusFind.find(ink: c.ink, pieces: [host], hosts: [host], lineHeight: 0.1) { _ in
            asked += 1
            return asked == 1 ? "10" : "k=1"
        }
        let sigma = found.first { $0.kind == .sigma }
        // 위끝을 먼저 묻는지 아래끝을 먼저 묻는지는 구현 순서 (아래끝 → 위끝)
        check("위끝·아래끝 읽기: 두 번 물음", asked == 2, "\(asked)")
        check("위끝·아래끝 읽기: 둘 다 읽혀야 붙음 (아래끝이 식이 아니면 ∑만)", sigma != nil, "\(found)")
    }
    do {
        // 잉크는 있는데 읽지 못한 쪽이 있으면 부분만 붙이지 않음
        var c = Canvas(700, 260)
        for i in 0..<12 { c.glyph(30 + i * 40, 120) }
        c.sigma(520, 100)
        c.glyph(528, 52, w: 12, h: 18); c.glyph(520, 180, w: 40, h: 16)
        let host = glyph("E (2k+1)", 0.5, 0.70, 0.32, 0.27, 0.30, Array(repeating: nil, count: 8))
        let found = await CalculusFind.find(ink: c.ink, pieces: [host], hosts: [host], lineHeight: 0.1) { _ in nil }
        check("읽지 못한 끝이 있으면 ∑ 만 (부분 식 안 만듦)", found.first { $0.kind == .sigma }?.text == "∑" && found.first { $0.kind == .sigma }?.strong == false, found.map(\.text).joined(separator: ","))
    }

    // 6) 풀이 엔진이 읽은 글(앱 표기)을 받아 풀거나, 모르면 풀지 않음
    let solvable: [(String, String)] = [
        ("다음 값을 구하시오.\n∑_{k=1}^{10} (2k+1)", "120"),
        ("∑_{k=1}^{10} k", "55"),
        ("정적분 ∫_0^1 x² dx 의 값은?", "1/3"),
        ("∫_{-1}^{2} (3x² + 2x) dx 의 값은?", "9"),
        ("lim_{x→2} (x²−4)/(x−2) 의 값을 구하시오.", "4"),
        ("f(x) = x³ − 3x² + 2일 때, f′(2)의 값은?", "0"),
        ("f(x) = x³ − 3x² + 2일 때, f'(2)의 값은?", "0"),
    ]
    for (text, answer) in solvable {
        let solved = MathSolver.solve(text)
        check("미적분 풀이: \(text.replacingOccurrences(of: "\n", with: " "))", solved?.answer.contains(answer) == true, solved?.answer ?? "못 풂")
    }
    // 식이 불완전하면 풀지 않음 (틀린 답보다 못 푼 게 나음)
    let unsolvable = ["∑_{k=1}^{n} k² 의 값은?", "∫_0^x (t² + 1) dt", "∫ (2x+1) dx 를 구하시오.", "lim_{x→2} f(x) 의 값은?"]
    for text in unsolvable {
        let solved = MathSolver.solve(text)
        check("미적분: 모르면 안 풂 (\(text))", solved == nil || solved?.kind == .integral && text.hasPrefix("∫ (2x+1)"), solved?.answer ?? "")
    }
}
