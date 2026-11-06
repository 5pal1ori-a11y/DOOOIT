import Foundation

/// 문제 사진에서 학생이 쓴 것(연필·볼펜 풀이, 보기에 친 동그라미, 써 넣은 답, 그은 줄, 체크 표시)을 찾아 지움.
/// 인쇄된 문제만 읽게 하려고 글자 인식 전에 씀 (OCRCore.printedOnly가 Vision 결과와 픽셀을 넘겨 줌).
///
/// 한 가지 신호만으로 지우지 않음 (문제집은 파란·빨간 인쇄 글씨, 회색 상자도 씀):
/// - 잉크 색: 페이지 인쇄 글자(한글 본문)와 다른 색(파랑·빨강 펜), 훨씬 연한 회색(연필)
/// - 모양: 인쇄 줄보다 기운 줄, 훨씬 큰 글씨, 낮은 인식 신뢰도
/// - 내용: 한글이 없는 짧은 계산(x = 4, 2x = 8), "답:" 으로 시작
/// - 위치: 인쇄 글자로 읽힌 자리는 지우지 않음 (색 글씨 머리말·보기 번호 보호)
/// 글자로 읽히지 않는 표시(동그라미·밑줄·X·체크)는 인쇄와 다른 색의 잉크 덩어리로 찾아 지움.
/// Vision 없이 픽셀 배열과 글자 위치만 다룸 → 리눅스 테스트에서 그대로 검사
enum HandwritingFilter {
    /// text: 글자 읽기용 (다른 색 선은 그림 선이어도 지움) · figure: 그림 읽기용 (필기로 판정한 글자 자리만 지움)
    enum Mode { case text, figure }

    /// RGBA 픽셀 (첫 줄이 사진 맨 위)
    struct Pixels {
        let width: Int
        let height: Int
        var rgba: [UInt8]
    }

    enum Hue: String { case neutral, blue, red, green, other }

    /// 상자 안 잉크: 진한 쪽 40%의 대비(0~1, 바탕보다 얼마나 어두운지)와 색
    struct Ink: Equatable {
        var count = 0
        var contrast: Double = 0
        var chroma: Double = 0
        var hue: Hue = .neutral
        /// 가장 진한 8%의 대비 (가는 획·흐린 사진에서도 인쇄는 여기가 진함, 연필은 여기도 연함)
        var peak: Double = 0
        /// 진한 잉크가 끝나는 아래 줄 (픽셀, 글씨 밑선이 들쭉날쭉한지 볼 때)
        var bottom: Double? = nil
    }

    /// 읽은 글자 하나 (box: 픽셀, 위가 0)
    struct Glyph {
        var char: Character
        var box: CGRect?
        var ink: Ink?
    }

    /// Vision이 읽은 한 줄 (angle: 줄 기울기, 도)
    struct Line {
        var text: String
        var confidence: Float
        var box: CGRect
        var angle: Double
        var glyphs: [Glyph]
    }

    /// 페이지 인쇄 글자의 기준 (한글 본문에서 잼)
    struct Reference: Equatable {
        var contrast: Double
        var peak: Double = 0
        var chroma: Double
        var hue: Hue
        var lineHeight: Double
        var angle: Double
    }

    /// 판정한 글자 조각 (한 줄 안에서 띄어쓰기·잉크 색이 바뀌는 곳마다 나눔)
    struct Token {
        var text: String
        var box: CGRect
        var line: Int
        var score: Double
        var reasons: [String]
        var hand: Bool
    }

    enum Tint { case native, colored, light, unknown }

    // MARK: - 픽셀 기본

    @inline(__always) static func luminance(_ r: Int, _ g: Int, _ b: Int) -> Int { (r * 299 + g * 587 + b * 114) / 1000 }

    static func hue(r: Double, g: Double, b: Double) -> (hue: Hue, chroma: Double) {
        let mx = max(r, g, b), mn = min(r, g, b)
        let chroma = mx - mn
        guard chroma >= 45 else { return (.neutral, chroma) }
        if b == mx, b - r >= 30 { return (.blue, chroma) }
        if r == mx, r - g >= 40, r - b >= 25 { return (.red, chroma) }
        if g == mx, g - r >= 20, g - b >= 10 { return (.green, chroma) }
        return (.other, chroma)
    }

    /// 바탕(종이) 밝기 지도: 칸마다 밝은 쪽 90% 밝기 → 이웃 칸 최댓값 (그림자·조명이 고르지 않아도 잉크만 어둡게 보이게)
    struct PaperMap {
        let cell: Int
        let cols: Int
        let rows: Int
        let values: [Double]

        init(_ p: Pixels) {
            let cell = max(16, min(p.width, p.height) / 40)
            let cols = (p.width + cell - 1) / cell, rows = (p.height + cell - 1) / cell
            var raw = [Double](repeating: 255, count: cols * rows)
            p.rgba.withUnsafeBufferPointer { px in
                var histogram = [Int](repeating: 0, count: 256)
                for cy in 0..<rows {
                    for cx in 0..<cols {
                        for k in 0..<256 { histogram[k] = 0 }
                        var n = 0
                        let y0 = cy * cell, y1 = min(p.height, y0 + cell), x0 = cx * cell, x1 = min(p.width, x0 + cell)
                        var y = y0
                        while y < y1 {
                            var x = x0
                            while x < x1 {
                                let i = (y * p.width + x) * 4
                                histogram[HandwritingFilter.luminance(Int(px[i]), Int(px[i + 1]), Int(px[i + 2]))] += 1
                                n += 1
                                x += 2
                            }
                            y += 2
                        }
                        var need = n / 10, level = 255
                        while level > 0 { need -= histogram[level]; if need <= 0 { break }; level -= 1 }
                        raw[cy * cols + cx] = Double(level)
                    }
                }
            }
            // 글자·그림이 빽빽한 칸은 바탕이 어둡게 잡히므로 이웃 칸의 최댓값
            var values = raw
            for cy in 0..<rows {
                for cx in 0..<cols {
                    var best = raw[cy * cols + cx]
                    for dy in -1...1 { for dx in -1...1 {
                        let x = cx + dx, y = cy + dy
                        if x >= 0, y >= 0, x < cols, y < rows { best = max(best, raw[y * cols + x]) }
                    } }
                    values[cy * cols + cx] = max(40, best)
                }
            }
            self.cell = cell; self.cols = cols; self.rows = rows; self.values = values
        }

        @inline(__always) func at(_ x: Int, _ y: Int) -> Double {
            values[min(rows - 1, y / cell) * cols + min(cols - 1, x / cell)]
        }
    }

    /// 상자 안 잉크 재기
    static func ink(in rect: CGRect, pixels p: Pixels, paper: PaperMap) -> Ink? {
        let x0 = max(0, Int(rect.minX)), x1 = min(p.width, Int(rect.maxX.rounded(.up)))
        let y0 = max(0, Int(rect.minY)), y1 = min(p.height, Int(rect.maxY.rounded(.up)))
        guard x1 > x0, y1 > y0 else { return nil }
        let area = (x1 - x0) * (y1 - y0)
        let step = area > 40_000 ? 2 : 1
        var samples: [(c: Double, r: Int, g: Int, b: Int, y: Int)] = []
        p.rgba.withUnsafeBufferPointer { px in
            var y = y0
            while y < y1 {
                var x = x0
                while x < x1 {
                    let i = (y * p.width + x) * 4
                    let r = Int(px[i]), g = Int(px[i + 1]), b = Int(px[i + 2])
                    let bg = paper.at(x, y)
                    let c = (bg - Double(luminance(r, g, b))) / bg
                    let chroma = max(r, g, b) - min(r, g, b)
                    if c > 0.2 || (chroma > 50 && c > 0.08) { samples.append((c, r, g, b, y)) }
                    x += step
                }
                y += step
            }
        }
        guard !samples.isEmpty else { return Ink() }
        samples.sort { $0.c > $1.c }
        let core = samples.prefix(max(1, samples.count * 2 / 5))
        let n = Double(core.count)
        let contrast = core.reduce(0) { $0 + $1.c } / n
        // 색은 가장 진한 픽셀로 (인쇄 글자 위에 펜 선이 지나가도 가장 진한 곳은 인쇄 잉크)
        let top = samples.prefix(max(3, samples.count * 2 / 25))
        let m = Double(top.count)
        let r = top.reduce(0.0) { $0 + Double($1.r) } / m, g = top.reduce(0.0) { $0 + Double($1.g) } / m, b = top.reduce(0.0) { $0 + Double($1.b) } / m
        let h = hue(r: r, g: g, b: b)
        let peak = top.reduce(0) { $0 + $1.c } / m
        let strong = samples.filter { $0.c >= peak * 0.5 }
        let bottom = strong.map(\.y).max().map(Double.init)
        return Ink(count: samples.count * step * step, contrast: contrast, chroma: h.chroma, hue: h.hue, peak: peak, bottom: bottom)
    }

    // MARK: - 기준 · 색 판정

    static func isHangul(_ c: Character) -> Bool {
        c.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        return s[s.count / 2]
    }

    /// 인쇄 기준: 믿을 만한 줄의 한글 글자 (적으면 믿을 만한 줄의 모든 글자)
    static func reference(_ lines: [Line]) -> Reference? {
        let sure = lines.filter { $0.confidence >= 0.5 }
        var glyphs = sure.flatMap { line in line.glyphs.filter { isHangul($0.char) && ($0.ink?.count ?? 0) >= 6 } }
        var refLines = sure.filter { $0.text.filter(isHangul).count >= 2 }
        if glyphs.count < 6 {
            glyphs = sure.flatMap { line in line.glyphs.filter { !$0.char.isWhitespace && ($0.ink?.count ?? 0) >= 6 } }
            refLines = sure
        }
        guard glyphs.count >= 3 else { return nil }
        var hues: [Hue: Int] = [:]
        for g in glyphs { if let h = g.ink?.hue { hues[h, default: 0] += 1 } }
        // 인쇄는 대부분 검정: 다른 색 글자가 검정의 2배(그리고 6자) 이상일 때만 색 인쇄 페이지로 봄
        // (파란 펜 메모의 한글이 몇 자 많다고 파랑을 인쇄로 보지 않게)
        let neutralCount = hues[.neutral] ?? 0
        let top = hues.filter { $0.key != .neutral }.max { $0.value < $1.value }
        let hue: Hue = (top.map { $0.value >= max(6, neutralCount * 2) } ?? false) ? top!.key : .neutral
        // 대비·채도는 그 색 글자에서만 잼
        let sameHue = glyphs.filter { $0.ink?.hue == hue }
        guard let contrast = median((sameHue.isEmpty ? glyphs : sameHue).compactMap { $0.ink?.contrast }) else { return nil }
        let chroma = median((sameHue.isEmpty ? glyphs : sameHue).compactMap { $0.ink?.chroma }) ?? 0
        // 줄 높이: 글자 상자 높이 (두 줄이 한 줄로 읽혀도 흔들리지 않게), 기울기: 글자 수만큼 무게
        let height = median(glyphs.compactMap { $0.box.map { Double($0.height) } }) ?? median(refLines.map { Double($0.box.height) }) ?? 20
        let angleLines = refLines.filter { $0.text.filter { !$0.isWhitespace }.count >= 4 }
        let weighted = angleLines.flatMap { line in Array(repeating: line.angle, count: line.text.filter { !$0.isWhitespace }.count) }
        let angle = median(weighted) ?? median(lines.map(\.angle)) ?? 0
        let peak = median((sameHue.isEmpty ? glyphs : sameHue).compactMap { $0.ink?.peak }) ?? contrast
        return Reference(contrast: contrast, peak: peak, chroma: chroma, hue: hue, lineHeight: height, angle: angle)
    }

    /// 인쇄 기준과 비교한 잉크 색: 다른 색 펜 / 훨씬 연한 연필 / 인쇄와 같음
    static func tint(_ ink: Ink?, _ ref: Reference) -> Tint {
        guard let ink, ink.count >= 6 else { return .unknown }
        if ink.hue != ref.hue {
            // 검은 인쇄 위 파랑·빨강 펜
            if ink.hue != .neutral, ink.chroma >= 50 { return .colored }
            // 색으로 인쇄한 쪽 위 검은 펜
            if ink.hue == .neutral, ref.chroma - ink.chroma >= 45 { return .colored }
        }
        // 연필: 획의 가장 진한 곳도 인쇄보다 훨씬 연함 (가는 인쇄 획·흐린 사진은 평균은 연해도 가장 진한 곳은 진함)
        if ink.hue == .neutral, ref.hue == .neutral, ref.contrast >= 0.4, ink.contrast < ref.contrast * 0.66,
           ink.peak < max(ref.peak, ref.contrast) * 0.62 { return .light }
        return .native
    }

    // MARK: - 글자 조각 판정

    /// 손으로 쓴 답·풀이 같은 내용
    static func looksLikeWork(_ text: String) -> Bool {
        let t = text.replacingOccurrences(of: " ", with: "")
        if t.range(of: #"^(답|정답|풀이|ans|Ans|sol)\s*[:=)]?"#, options: .regularExpression) != nil { return true }
        // 한글 없는 짧은 계산: x=4, 2x=8, 3×4=12, 8÷2
        return !t.contains(where: isHangul) && t.count <= 12 && t.range(of: #"^[0-9a-zA-Z().,+\-−×÷*/=√^²]+$"#, options: .regularExpression) != nil
            && t.contains(where: { "=×÷+−-".contains($0) })
    }

    /// 글씨 밑선이 들쭉날쭉한 정도 (숫자·영문 글자 밑의 흩어짐 / 글자 높이). 셀 글자가 3개 미만이면 nil
    static func wobble(_ glyphs: [Glyph], height: Double) -> Double? {
        let flat = Set("0123456789abcdefhiklmnorstuvwxzABCDEFGHIJKLMNOPRSTUVWXYZ")
        let bottoms = glyphs.filter { flat.contains($0.char) }.compactMap { $0.ink?.bottom }
        guard bottoms.count >= 3, height > 0 else { return nil }
        let mean = bottoms.reduce(0, +) / Double(bottoms.count)
        let sd = (bottoms.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(bottoms.count)).squareRoot()
        return sd / height
    }

    /// 줄 전체가 "답: 3", "정답 ④" 꼴 (문제 사진에서는 거의 늘 학생이 써 넣은 답)
    static func looksLikeAnswerNote(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces)
            .range(of: #"^(답|정답)\s*[:：=)]?\s*[①②③④⑤0-9a-zA-Z.\-−/]{1,6}$"#, options: .regularExpression) != nil
    }

    /// 인쇄한 문제 줄 맨 끝에 덧붙여 쓴 답("... 크기는? 정답 ②")이 시작하는 글자 자리 (없으면 nil)
    static func trailingAnswerNoteStart(_ text: String) -> Int? {
        guard let r = text.range(of: #"\s(답|정답)\s*[:：=)]?\s*[①②③④⑤0-9.\-−]{1,4}\s*$"#, options: .regularExpression) else { return nil }
        return text.distance(from: text.startIndex, to: r.lowerBound) + 1
    }

    static func tokens(_ lines: [Line], reference ref: Reference, mode: Mode) -> [Token] {
        var out: [Token] = []
        // 보기 줄(①②가 둘 이상)이 끝나는 아래: 그 밑에 쓴 계산은 대개 학생 풀이
        let choiceBottom = lines.filter { $0.text.filter { "①②③④⑤".contains($0) }.count >= 2 }.map { Double($0.box.maxY) }.max()
        for (index, line) in lines.enumerated() {
            let tints = line.glyphs.map { $0.char.isWhitespace ? Tint.unknown : tint($0.ink, ref) }
            // 띄어쓰기와 색이 바뀌는 곳에서 나눔 (모르는 글자는 앞 조각에 붙임)
            var runs: [Range<Int>] = []
            var start: Int?
            var current: Bool?
            for k in line.glyphs.indices {
                if line.glyphs[k].char.isWhitespace {
                    if let s = start { runs.append(s..<k) }
                    start = nil; current = nil
                    continue
                }
                let foreign: Bool? = tints[k] == .unknown ? nil : tints[k] != .native
                if start == nil { start = k; current = foreign; continue }
                if let f = foreign, let c = current, f != c, let s = start {
                    runs.append(s..<k); start = k; current = f
                } else if current == nil { current = foreign }
            }
            if let s = start { runs.append(s..<line.glyphs.count) }
            let nonSpace = line.glyphs.filter { !$0.char.isWhitespace }.count
            for run in runs {
                let glyphs = Array(line.glyphs[run])
                let text = String(glyphs.map(\.char))
                let boxes = glyphs.compactMap(\.box)
                let box = boxes.dropFirst().reduce(boxes.first ?? line.box) { $0.union($1) }
                let known = run.filter { tints[$0] != .unknown }
                let colored = Double(known.filter { tints[$0] == .colored }.count)
                let light = Double(known.filter { tints[$0] == .light }.count)
                let n = Double(max(1, known.count))
                let hangul = text.filter(isHangul).count
                let core = text.filter { !$0.isPunctuation && !"+-−=×÷()".contains($0) }.count
                let circled = text.contains(where: { "①②③④⑤⑥⑦⑧⑨⑩".contains($0) })
                var score = 0.0
                var reasons: [String] = []
                let tilt = abs(line.angle - ref.angle)
                let measurable = nonSpace >= 3 && line.box.width >= line.box.height * 2
                let whole = Double(glyphs.count) >= Double(nonSpace) * 0.8
                let ratio = Double(line.box.height) / max(1, ref.lineHeight)
                let printedShape = line.confidence >= 0.9 && (!measurable || tilt <= 2) && (!whole || (0.7...1.35).contains(ratio))
                if !known.isEmpty, colored / n >= 0.6 {
                    score += 1.5; reasons.append("색")
                    // 색으로 인쇄한 머리말·라벨(첫 줄, [1~3], <보기>, (가))만 반듯하면 인쇄로 봄.
                    // 문제 한가운데 따로 선 짧은 색 글(여기 중요, 다시 보기)은 반듯해도 펜 메모
                    let lineStart = line.text.trimmingCharacters(in: .whitespaces).first
                    let headerLike = index == 0 || (lineStart.map { "[<(［〈（".contains($0) } ?? false)
                    if hangul >= 2 && printedShape {
                        if headerLike { score -= 0.9; reasons.append("인쇄 모양") }
                        else if nonSpace <= 12 { score += 0.4; reasons.append("짧은 색 메모") }
                    }
                }
                if !known.isEmpty, light / n >= 0.6 {
                    let darkest = glyphs.compactMap { $0.ink?.peak }.max() ?? 0
                    if darkest < max(ref.peak, ref.contrast) * 0.55 { score += 1.9; reasons.append("아주 연함") } else { score += 1.5; reasons.append("연함") }
                    if hangul >= 2 && printedShape { score -= 0.5; reasons.append("인쇄 모양") }
                }
                if score > 0, hangul == 0, core >= 2, !circled { score += 0.4; reasons.append("한글 없음") }
                if measurable, tilt > 3 { score += tilt > 6 ? 1.0 : 0.6; reasons.append("기울기 \(Int(tilt.rounded()))°") }
                if whole, ratio >= 1.45 { score += ratio >= 1.9 ? 0.9 : 0.6; reasons.append("큰 글씨") }
                // Vision은 ①~⑤ 든 줄의 신뢰도를 늘 낮게 줌 → 보기 번호 조각은 신뢰도로 깎지 않음
                if !circled {
                    if line.confidence < 0.4 { score += 0.6; reasons.append("신뢰도 낮음") } else if line.confidence < 0.6 { score += 0.3; reasons.append("신뢰도 보통") }
                }
                if looksLikeWork(text) { score += 0.4; reasons.append("풀이 모양") }
                // 줄 전체가 계산(2x=8)·써 넣은 답(답: 3)이면 조각마다 더함 (검정 펜 풀이는 색으로 못 가름)
                let lineWork = looksLikeWork(line.text)
                if lineWork, text != line.text { score += 0.6; reasons.append("풀이 줄") }
                let lineChars = String(line.glyphs.map(\.char))
                let tailStart = trailingAnswerNoteStart(lineChars)
                let answerNote = looksLikeAnswerNote(line.text) || (tailStart.map { run.lowerBound >= $0 } ?? false)
                if answerNote { score += (tailStart.map { run.lowerBound >= $0 } ?? false) ? 2.0 : 1.2; reasons.append("써 넣은 답") }
                if let bottom = choiceBottom, Double(line.box.minY) > bottom + ref.lineHeight * 0.3, !circled {
                    score += lineWork || hangul == 0 ? 0.8 : 0.4; reasons.append("보기 아래")
                }
                if let w = wobble(glyphs, height: ref.lineHeight), w > 0.045 { score += w > 0.08 ? 0.9 : 0.6; reasons.append(String(format: "들쭉날쭉 %.2f", w)) }
                // 인쇄 줄 안에 낀 한두 글자 조각(+, −, 괄호, ②)은 가는 획이라 연해 보일 뿐 (줄 대부분이 인쇄면 필기 아님)
                let lineKnown = line.glyphs.indices.filter { tints[$0] != .unknown }
                let lineNative = lineKnown.filter { tints[$0] == .native }.count
                let belowChoices = choiceBottom.map { Double(line.box.minY) > $0 + ref.lineHeight * 0.3 } ?? false
                if glyphs.count <= 2 || core <= 1, lineKnown.count >= 4, Double(lineNative) >= Double(lineKnown.count) * 0.6,
                   !lineWork, !answerNote, !belowChoices {
                    score = 0; reasons = ["인쇄 줄 속 조각"]
                }
                let threshold = mode == .text ? 1.8 : 2.3
                out.append(Token(text: text, box: box, line: index, score: score, reasons: reasons, hand: score >= threshold))
            }
        }
        return out
    }

    // MARK: - 지우기

    /// 지운 결과 (지운 게 없으면 erased 0)
    struct Report {
        var reference: Reference?
        var tokens: [Token] = []
        /// 지운 픽셀 수
        var erased = 0
        /// 지운 잉크 덩어리 수 (글자로 읽히지 않은 동그라미·줄 포함)
        var marks = 0

        /// 원인 찾기용 한 줄씩
        var lines: [String] {
            var out: [String] = []
            if let r = reference {
                out.append(String(format: "기준 대비 %.2f 채도 %.0f %@ 줄높이 %.0f 기울기 %.1f", r.contrast, r.chroma, r.hue.rawValue, r.lineHeight, r.angle))
            }
            for t in tokens where t.score > 0 {
                out.append("\(t.hand ? "✗" : "·") \(t.text) \(String(format: "%.1f", t.score)) \(t.reasons.joined(separator: ","))")
            }
            out.append("지움 \(erased)px 덩어리 \(marks)")
            return out
        }
    }

    /// 필기를 지운 픽셀 (lines: 같은 사진을 Vision이 읽은 줄, 글자 상자·잉크는 아직 비어 있어도 됨)
    static func clean(_ pixels: Pixels, lines rawLines: [Line], mode: Mode) -> (pixels: Pixels, report: Report) {
        let paper = PaperMap(pixels)
        var lines = rawLines
        for i in lines.indices {
            for k in lines[i].glyphs.indices where !lines[i].glyphs[k].char.isWhitespace {
                if let box = lines[i].glyphs[k].box { lines[i].glyphs[k].ink = ink(in: box, pixels: pixels, paper: paper) }
            }
        }
        var report = Report()
        guard let ref = reference(lines) else { return (pixels, report) }
        report.reference = ref
        let tokens = tokens(lines, reference: ref, mode: mode)
        report.tokens = tokens
        let pad = ref.lineHeight * 0.15
        let handBoxes = tokens.filter(\.hand).map { $0.box.insetBy(dx: -pad, dy: -pad) }
        // 인쇄로 본 자리: 필기가 없는 줄은 줄 상자 전체(지수·분수 막대까지), 섞인 줄은 인쇄 조각 상자를 위아래로 넓혀서
        var printedBoxes: [CGRect] = []
        for (index, line) in lines.enumerated() {
            let parts = tokens.filter { $0.line == index }
            if parts.allSatisfy({ !$0.hand }) {
                printedBoxes.append(line.box.insetBy(dx: -pad, dy: -pad * 2))
            } else {
                printedBoxes += parts.filter { !$0.hand }.map { $0.box.insetBy(dx: 0, dy: -pad * 2) }
            }
        }

        let w = pixels.width, h = pixels.height
        var out = pixels
        // 잉크 덩어리 (8방향 연결)
        var label = [Int32](repeating: -1, count: w * h)
        var isInk = [Bool](repeating: false, count: w * h)
        var contrastOf = [Float](repeating: 0, count: w * h)
        pixels.rgba.withUnsafeBufferPointer { px in
            for y in 0..<h {
                for x in 0..<w {
                    let i = y * w + x, j = i * 4
                    let r = Int(px[j]), g = Int(px[j + 1]), b = Int(px[j + 2])
                    let bg = paper.at(x, y)
                    let c = (bg - Double(luminance(r, g, b))) / bg
                    let chroma = max(r, g, b) - min(r, g, b)
                    contrastOf[i] = Float(c)
                    isInk[i] = c > 0.2 || (chroma > 50 && c > 0.08)
                }
            }
        }
        struct Blob {
            var minX: Int, minY: Int, maxX: Int, maxY: Int
            var count = 0
            var pixels: [Int] = []
        }
        var blobs: [Blob] = []
        var stack: [Int] = []
        for start in 0..<(w * h) where isInk[start] && label[start] < 0 {
            let id = Int32(blobs.count)
            var blob = Blob(minX: start % w, minY: start / w, maxX: start % w, maxY: start / w)
            label[start] = id
            stack.append(start)
            while let i = stack.popLast() {
                let x = i % w, y = i / w
                blob.pixels.append(i)
                blob.minX = min(blob.minX, x); blob.maxX = max(blob.maxX, x); blob.minY = min(blob.minY, y); blob.maxY = max(blob.maxY, y)
                for dy in -1...1 {
                    let ny = y + dy
                    guard ny >= 0, ny < h else { continue }
                    for dx in -1...1 {
                        let nx = x + dx
                        guard nx >= 0, nx < w else { continue }
                        let k = ny * w + nx
                        if isInk[k] && label[k] < 0 { label[k] = id; stack.append(k) }
                    }
                }
            }
            blob.count = blob.pixels.count
            blobs.append(blob)
        }

        func blobInk(_ b: Blob) -> Ink {
            var cs = b.pixels.map { contrastOf[$0] }
            cs.sort(by: >)
            let cut = cs[min(cs.count - 1, max(0, cs.count * 2 / 5 - 1))]
            let peakCut = cs[min(cs.count - 1, max(0, max(3, cs.count * 2 / 25) - 1))]
            var r = 0.0, g = 0.0, bl = 0.0, m = 0.0, n = 0.0, csum = 0.0
            for i in b.pixels {
                let c = contrastOf[i]
                if c >= cut { csum += Double(c); n += 1 }
                if c >= peakCut { r += Double(pixels.rgba[i * 4]); g += Double(pixels.rgba[i * 4 + 1]); bl += Double(pixels.rgba[i * 4 + 2]); m += 1 }
            }
            n = max(1, n); m = max(1, m)
            let hh = hue(r: r / m, g: g / m, b: bl / m)
            let top = cs.prefix(max(1, cs.count * 2 / 25))
            let peak = Double(top.reduce(0, +)) / Double(top.count)
            return Ink(count: b.count, contrast: csum / n, chroma: hh.chroma, hue: hh.hue, peak: peak)
        }
        func overlap(_ a: CGRect, _ boxes: [CGRect]) -> Double {
            let area = max(1, a.width * a.height)
            var best: CGFloat = 0
            for box in boxes {
                let i = a.intersection(box)
                if !i.isNull { best = max(best, i.width * i.height) }
            }
            return Double(best / area)
        }
        func erase(_ i: Int) {
            let v = UInt8(max(0, min(255, paper.at(i % w, i / w))))
            out.rgba[i * 4] = v; out.rgba[i * 4 + 1] = v; out.rgba[i * 4 + 2] = v
            report.erased += 1
        }
        /// 덩어리 안에서 인쇄와 다른 잉크 픽셀인지 (인쇄 글자 가장자리 빼려고 진한 인쇄 픽셀 2칸 안은 남김)
        func foreignPixel(_ i: Int) -> Bool {
            let r = Int(pixels.rgba[i * 4]), g = Int(pixels.rgba[i * 4 + 1]), b = Int(pixels.rgba[i * 4 + 2])
            let hh = hue(r: Double(r), g: Double(g), b: Double(b))
            return hh.hue != ref.hue && hh.chroma >= 55
        }
        func nearPrintCore(_ i: Int) -> Bool {
            let x = i % w, y = i / w
            for dy in -2...2 {
                let ny = y + dy
                guard ny >= 0, ny < h else { continue }
                for dx in -2...2 {
                    let nx = x + dx
                    guard nx >= 0, nx < w else { continue }
                    let k = ny * w + nx
                    if isInk[k], !foreignPixel(k), Double(contrastOf[k]) >= ref.contrast * 0.75 { return true }
                }
            }
            return false
        }

        let big = ref.lineHeight * 1.6
        let imageArea = Double(w * h)
        let sizable = Int(ref.lineHeight * ref.lineHeight * 0.15)
        var wipes: [Int] = []
        var partial: [Int] = []
        var evidence = tokens.contains(where: \.hand)
        for (index, b) in blobs.enumerated() where b.count >= 3 {
            let rect = CGRect(x: b.minX, y: b.minY, width: b.maxX - b.minX + 1, height: b.maxY - b.minY + 1)
            // 사진 가장자리에 닿은 아주 큰 덩어리 (책상·그림자)는 그대로
            let touchesEdge = b.minX == 0 || b.minY == 0 || b.maxX == w - 1 || b.maxY == h - 1
            if touchesEdge && Double(rect.width * rect.height) > imageArea * 0.1 { continue }
            let bi = blobInk(b)
            let t = tint(bi, ref)
            let foreign = t == .colored || t == .light
            // 인쇄 자리 위에서도 지우는 큰 표시: 색 펜, 또는 아주 연한 연필 (흐린 인쇄 선을 연필로 보지 않게)
            let strongForeign = t == .colored || (t == .light && bi.peak < max(ref.peak, ref.contrast) * 0.55)
            let inHand = overlap(rect, handBoxes) >= 0.5
            let inPrinted = overlap(rect, printedBoxes) >= 0.5
            let isBig = Double(max(rect.width, rect.height)) > big
            var wipe = false
            switch mode {
            case .text:
                wipe = (inHand && (foreign || !inPrinted)) || (foreign && !inPrinted) || (strongForeign && isBig)
            case .figure:
                wipe = inHand && (foreign || !inPrinted)
            }
            if wipe {
                wipes.append(index)
                if (foreign && (isBig || b.count >= sizable) && !inPrinted) || (strongForeign && isBig) { evidence = true }
            } else if mode == .text, isBig || inHand {
                // 인쇄 글자·선에 붙은 다른 색 잉크가 넉넉하면 (보기 번호에 닿은 동그라미, 글자를 지나는 줄)
                let foreignCount = b.pixels.reduce(0) { $0 + (foreignPixel($1) ? 1 : 0) }
                if Double(foreignCount) >= Double(b.count) * 0.25 {
                    partial.append(index)
                    if isBig { evidence = true }
                }
            }
        }
        // 필기라고 볼 근거가 없으면 (인쇄만 있는 쪽: 잡티·흐린 가장자리뿐) 사진을 그대로 둠
        guard evidence else { return (pixels, report) }
        // 지울 양이 페이지 잉크의 40%를 넘으면 판단이 잘못된 것 (색 인쇄 페이지 등) → 그대로 둠
        let totalInk = max(1, isInk.reduce(0) { $0 + ($1 ? 1 : 0) })
        let wipeTotal = wipes.reduce(0) { $0 + blobs[$1].count }
        guard Double(wipeTotal) <= Double(totalInk) * 0.4 else {
            report.tokens.append(Token(text: "(지울 양이 너무 많아 그대로 둠)", box: .zero, line: -1, score: 0, reasons: [], hand: false))
            return (pixels, report)
        }
        for index in wipes {
            report.marks += 1
            for i in blobs[index].pixels { erase(i) }
        }
        for index in partial {
            // 인쇄 글자·선에 붙은 다른 색 잉크 (보기 번호에 닿은 동그라미, 글자를 지나는 줄)
            let b = blobs[index]
            let foreignPixels = b.pixels.filter(foreignPixel)
            var any = false
            for i in foreignPixels where !nearPrintCore(i) { erase(i); any = true }
            if any { report.marks += 1 }
        }
        return (out, report)
    }
}
