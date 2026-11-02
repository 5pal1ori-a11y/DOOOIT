import CoreGraphics
import CoreText
import Foundation

// 문제지·단어장 그리기: CoreText로 글자를 찍고, 분수·지수·근호·빈칸·동그라미 번호는 직접 배치

/// 줄 안의 조각
enum Seg {
    /// 한글 문장 (글꼴: 본문)
    case t(String)
    /// 수식 (영문 글자는 기울임, 숫자·기호는 바른 글꼴)
    case m(String)
    /// 영어 낱말·문장 (바른 글꼴)
    case e(String)
    /// 위 첨자 (지수)
    case sup(String)
    /// 쌓은 분수 (분자, 분모) — 둘 다 수식
    case frac(String, String)
    /// 근호 √ + 윗줄 (안은 수식)
    case sqrt(String)
    /// 빈칸 네모 □ (그린 상자)
    case blank
    /// 보기 번호 ①~⑤
    case circ(Int)
    /// 굵은 문제 번호 ("3.", "05")
    case num(String)
    /// 띄우기 (글자 크기 배수)
    case gap(CGFloat)
    /// 밑줄 빈칸 (글자 크기 배수 길이)
    case underline(CGFloat)
    /// 아래 첨자 (화학식 H₂O의 2)
    case sub(String)
    /// 밑줄 친 영어 (어법 문제의 밑줄 부분)
    case u(String)
    /// 위 첨자 (바른 글꼴: 이온 전하 ⁺, 단위 ²)
    case supText(String)
}

/// 그래프 (축 이름, 눈금, 점들 0~1)
struct GraphSpec {
    var xLabel: String
    var yLabel: String
    var xTicks: [String]
    var yTicks: [String]
    var points: [CGPoint]
    /// 그래프 높이 (글자 크기 배수)
    var height: CGFloat = 7
}

enum Line {
    /// 한 줄에 이어서
    case flow([Seg])
    /// 보기 칸: 한 줄에 cols개씩 같은 간격으로 (넘치면 다음 줄)
    case grid([[Seg]], cols: Int)
    /// 두 칸 표 (왼쪽 x, 오른쪽 x 비율 0~1)
    case columns([([Seg], CGFloat)])
    /// 빈 줄 (글자 크기 배수)
    case space(CGFloat)
    /// 가로줄
    case rule
    /// 테두리 상자 (<보기>, 주어진 문장) — title이 있으면 위 테두리 가운데에
    case boxed(String?, [[Seg]])
    /// 칸마다 테두리가 있는 표 (칸 왼쪽 위치 비율, 마지막은 오른쪽 끝)
    case table([[[Seg]]], [CGFloat])
    /// 그래프 그림
    case graph(GraphSpec)
}

struct Style {
    var korean = "AppleSDGothicNeo-Regular"
    var koreanBold = "AppleSDGothicNeo-Bold"
    var latin = "TimesNewRomanPSMT"
    var italic = "TimesNewRomanPS-ItalicMT"
    var size: CGFloat = 40
    /// 동그라미 번호: 글꼴의 ① 글자 (false면 원을 직접 그림)
    var circledGlyph = true
    /// 줄 간격 배수
    var leading: CGFloat = 1.75
    var ink = CGColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)
    var paper = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    /// 영어 단어장 표제어 글꼴 (nil이면 latin)
    var termFont: String?
}

private func font(_ name: String, _ size: CGFloat) -> CTFont {
    CTFontCreateWithName(name as CFString, size, nil)
}

/// 글꼴을 글자마다 고른 문자열 (CoreText가 없는 글자는 다른 글꼴로 대신 그림)
func attributed(_ text: String, math: Bool, size: CGFloat, style: Style, bold: Bool = false, fontName: String? = nil) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for ch in text {
        let name: String
        if let fontName {
            name = fontName
        } else if math {
            if ch.isASCII && ch.isLetter { name = style.italic }
            else if ch.isASCII || "−×÷±≤≥≠·".contains(ch) { name = style.latin }
            else { name = style.korean }
        } else {
            name = bold ? style.koreanBold : style.korean
        }
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font(name, size),
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
        ]
        result.append(NSAttributedString(string: String(ch), attributes: attrs))
    }
    return result
}

struct Measured {
    var width: CGFloat
    var ascent: CGFloat
    var descent: CGFloat
    /// (그리기: 기준선 시작점)
    var draw: (CGContext, CGPoint) -> Void
}

func measureText(_ s: NSAttributedString) -> Measured {
    let line = CTLineCreateWithAttributedString(s)
    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
    return Measured(width: width, ascent: ascent, descent: descent) { ctx, p in
        ctx.textPosition = p
        CTLineDraw(line, ctx)
    }
}

func measure(_ seg: Seg, style: Style) -> Measured {
    let size = style.size
    switch seg {
    case .t(let s):
        return measureText(attributed(s, math: false, size: size, style: style))
    case .m(let s):
        return measureText(attributed(s, math: true, size: size, style: style))
    case .e(let s):
        return measureText(attributed(s, math: false, size: size, style: style, fontName: style.termFont ?? style.latin))
    case .num(let s):
        return measureText(attributed(s, math: false, size: size, style: style, bold: true))
    case .sup(let s):
        let inner = measureText(attributed(s, math: true, size: size * 0.6, style: style))
        let raise = size * 0.42
        return Measured(width: inner.width + size * 0.05, ascent: raise + inner.ascent, descent: 0) { ctx, p in
            inner.draw(ctx, CGPoint(x: p.x + size * 0.02, y: p.y + raise))
        }
    case .frac(let n, let d):
        let num = measureText(attributed(n, math: true, size: size * 0.82, style: style))
        let den = measureText(attributed(d, math: true, size: size * 0.82, style: style))
        let width = max(num.width, den.width) + size * 0.3
        let axis = size * 0.3
        let numBase = axis + size * 0.14 + num.descent
        let denBase = axis - size * 0.14 - den.ascent * 0.92
        let thick = max(1.5, size / 22)
        return Measured(width: width + size * 0.15, ascent: numBase + num.ascent, descent: -(denBase - den.descent)) { ctx, p in
            num.draw(ctx, CGPoint(x: p.x + size * 0.075 + (width - num.width) / 2, y: p.y + numBase))
            den.draw(ctx, CGPoint(x: p.x + size * 0.075 + (width - den.width) / 2, y: p.y + denBase))
            ctx.fill(CGRect(x: p.x + size * 0.075, y: p.y + axis - thick / 2, width: width, height: thick))
        }
    case .sqrt(let s):
        let radical = measureText(attributed("√", math: true, size: size * 1.05, style: style, fontName: style.latin))
        let inner = measureText(attributed(s, math: true, size: size, style: style))
        let top = max(radical.ascent * 0.92, inner.ascent + size * 0.08)
        let thick = max(1.5, size / 24)
        return Measured(width: radical.width + inner.width + size * 0.08, ascent: top + thick, descent: max(radical.descent, inner.descent)) { ctx, p in
            radical.draw(ctx, p)
            inner.draw(ctx, CGPoint(x: p.x + radical.width + size * 0.04, y: p.y))
            ctx.fill(CGRect(x: p.x + radical.width - size * 0.04, y: p.y + top, width: inner.width + size * 0.12, height: thick))
        }
    case .blank:
        let side = size * 1.08
        let lineWidth = max(2, size / 18)
        return Measured(width: side + size * 0.3, ascent: side - size * 0.2, descent: size * 0.2) { ctx, p in
            ctx.setLineWidth(lineWidth)
            ctx.stroke(CGRect(x: p.x + size * 0.15, y: p.y - size * 0.2, width: side, height: side))
        }
    case .underline(let k):
        let lineWidth = max(2, size / 20)
        return Measured(width: size * k + size * 0.3, ascent: size * 0.7, descent: size * 0.15) { ctx, p in
            ctx.fill(CGRect(x: p.x + size * 0.15, y: p.y - size * 0.12, width: size * k, height: lineWidth))
        }
    case .circ(let n):
        if style.circledGlyph {
            let glyph = String("①②③④⑤".map { $0 }[max(0, min(4, n - 1))])
            let inner = measureText(attributed(glyph, math: false, size: size, style: style))
            return Measured(width: inner.width + size * 0.25, ascent: inner.ascent, descent: inner.descent) { ctx, p in
                inner.draw(ctx, p)
            }
        }
        let digit = measureText(attributed(String(n), math: true, size: size * 0.66, style: style, fontName: style.latin))
        let radius = size * 0.43
        let lineWidth = max(1.5, size / 26)
        return Measured(width: radius * 2 + size * 0.35, ascent: size * 0.36 + radius, descent: max(0, radius - size * 0.36)) { ctx, p in
            let center = CGPoint(x: p.x + radius + size * 0.05, y: p.y + size * 0.34)
            ctx.setLineWidth(lineWidth)
            ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            digit.draw(ctx, CGPoint(x: center.x - digit.width / 2, y: center.y - size * 0.23))
        }
    case .gap(let k):
        return Measured(width: size * k, ascent: 0, descent: 0) { _, _ in }
    case .sub(let s):
        let inner = measureText(attributed(s, math: false, size: size * 0.62, style: style, fontName: style.latin))
        let drop = size * 0.16
        return Measured(width: inner.width + size * 0.04, ascent: inner.ascent - drop, descent: drop + inner.descent) { ctx, p in
            inner.draw(ctx, CGPoint(x: p.x + size * 0.01, y: p.y - drop))
        }
    case .supText(let s):
        let inner = measureText(attributed(s, math: false, size: size * 0.6, style: style, fontName: style.latin))
        let raise = size * 0.42
        return Measured(width: inner.width + size * 0.05, ascent: raise + inner.ascent, descent: 0) { ctx, p in
            inner.draw(ctx, CGPoint(x: p.x + size * 0.02, y: p.y + raise))
        }
    case .u(let s):
        let inner = measureText(attributed(s, math: false, size: size, style: style, fontName: style.termFont ?? style.latin))
        let lineWidth = max(1.5, size / 24)
        return Measured(width: inner.width, ascent: inner.ascent, descent: max(inner.descent, size * 0.2)) { ctx, p in
            inner.draw(ctx, p)
            ctx.fill(CGRect(x: p.x, y: p.y - size * 0.14, width: inner.width, height: lineWidth))
        }
    }
}

/// 그래프 그리기 (축·눈금·이름·꺾은선)
func measureGraph(_ g: GraphSpec, style: Style, width: CGFloat) -> Measured {
    let size = style.size
    let labelSize = size * 0.8
    func text(_ t: String) -> Measured {
        let math = !t.contains(where: { ("가"..."힣").contains($0) })
        return measureText(attributed(t, math: false, size: labelSize, style: style, fontName: math ? style.latin : nil))
    }
    let plotHeight = size * g.height
    let left = size * 2.6, plotWidth = min(width * 0.62, size * 14)
    let total = plotHeight + size * 2.6
    let lineWidth = max(1.5, size / 22)
    return Measured(width: left + plotWidth + size * 5, ascent: total, descent: 0) { ctx, p in
        let origin = CGPoint(x: p.x + left, y: p.y + size * 1.6)
        ctx.fill(CGRect(x: origin.x, y: origin.y, width: plotWidth, height: lineWidth))
        ctx.fill(CGRect(x: origin.x, y: origin.y, width: lineWidth, height: plotHeight))
        // 눈금
        for (k, t) in g.xTicks.enumerated() {
            let x = origin.x + plotWidth * CGFloat(k) / CGFloat(max(1, g.xTicks.count - 1)) * 0.9
            let m = text(t)
            m.draw(ctx, CGPoint(x: x - m.width / 2, y: origin.y - size * 1.0))
        }
        for (k, t) in g.yTicks.enumerated() where k > 0 {
            let y = origin.y + plotHeight * CGFloat(k) / CGFloat(max(1, g.yTicks.count - 1)) * 0.85
            let m = text(t)
            m.draw(ctx, CGPoint(x: origin.x - m.width - size * 0.3, y: y - size * 0.25))
            ctx.fill(CGRect(x: origin.x - size * 0.15, y: y, width: size * 0.3, height: lineWidth))
        }
        // 축 이름: y는 축 위, x는 축 오른쪽 끝
        let yl = text(g.yLabel)
        yl.draw(ctx, CGPoint(x: origin.x - size * 0.4, y: origin.y + plotHeight + size * 0.4))
        let xl = text(g.xLabel)
        xl.draw(ctx, CGPoint(x: origin.x + plotWidth + size * 0.3, y: origin.y - size * 0.25))
        // 꺾은선
        ctx.setLineWidth(lineWidth * 1.4)
        for (k, pt) in g.points.enumerated() {
            let q = CGPoint(x: origin.x + plotWidth * 0.9 * pt.x, y: origin.y + plotHeight * 0.85 * pt.y)
            if k == 0 { ctx.move(to: q) } else { ctx.addLine(to: q) }
        }
        ctx.strokePath()
    }
}

func measureRun(_ segs: [Seg], style: Style) -> Measured {
    let parts = segs.map { measure($0, style: style) }
    let width = parts.reduce(0) { $0 + $1.width }
    let ascent = parts.map(\.ascent).max() ?? 0
    let descent = parts.map(\.descent).max() ?? 0
    return Measured(width: width, ascent: ascent, descent: descent) { ctx, p in
        var x = p.x
        for part in parts {
            part.draw(ctx, CGPoint(x: x, y: p.y))
            x += part.width
        }
    }
}

/// 페이지 그리기 (위 원점 기준 배치, CoreGraphics는 아래 원점이라 뒤집어서 계산)
func renderPage(_ lines: [Line], style: Style, width: Int, margin: CGFloat) -> CGImage? {
    let size = style.size
    // 1) 줄마다 높이 계산
    struct Placed {
        var ascent: CGFloat; var descent: CGFloat; var draws: [(CGFloat, Measured)]; var rule = false; var extra: CGFloat = 0
        /// 테두리 상자 시작(머리글) / 끝
        var frameStart: String?? = nil
        var frameEnd = false
        /// 표 한 줄: 칸 경계 x (여백 기준)
        var cells: [CGFloat]? = nil
    }
    var placed: [Placed] = []
    let usable = CGFloat(width) - margin * 2
    for line in lines {
        switch line {
        case .flow(let segs):
            let m = measureRun(segs, style: style)
            placed.append(Placed(ascent: max(m.ascent, size * 0.8), descent: max(m.descent, size * 0.22), draws: [(0, m)]))
        case .grid(let items, let cols):
            var row: [(CGFloat, Measured)] = []
            for (k, item) in items.enumerated() {
                let m = measureRun(item, style: style)
                row.append((usable / CGFloat(cols) * CGFloat(k % cols), m))
                if row.count == cols || k == items.count - 1 {
                    placed.append(Placed(ascent: max(row.map(\.1.ascent).max() ?? 0, size * 0.8),
                                         descent: max(row.map(\.1.descent).max() ?? 0, size * 0.22), draws: row))
                    row = []
                }
            }
        case .columns(let cells):
            let ms = cells.map { (usable * $0.1, measureRun($0.0, style: style)) }
            placed.append(Placed(ascent: max(ms.map(\.1.ascent).max() ?? 0, size * 0.8), descent: max(ms.map(\.1.descent).max() ?? 0, size * 0.22), draws: ms))
        case .space(let k):
            placed.append(Placed(ascent: 0, descent: 0, draws: [], extra: size * k))
        case .rule:
            placed.append(Placed(ascent: size * 0.3, descent: size * 0.3, draws: [], rule: true))
        case .boxed(let title, let rows):
            placed.append(Placed(ascent: 0, descent: 0, draws: [], extra: size * 0.9, frameStart: .some(title)))
            for segs in rows {
                let m = measureRun(segs, style: style)
                placed.append(Placed(ascent: max(m.ascent, size * 0.8), descent: max(m.descent, size * 0.22), draws: [(size * 0.6, m)]))
            }
            placed.append(Placed(ascent: 0, descent: 0, draws: [], extra: size * 0.3, frameEnd: true))
        case .table(let rows, let xs):
            for row in rows {
                let ms = row.enumerated().map { (usable * xs[$0.offset] + size * 0.3, measureRun($0.element, style: style)) }
                placed.append(Placed(ascent: max(ms.map(\.1.ascent).max() ?? 0, size * 0.8), descent: max(ms.map(\.1.descent).max() ?? 0, size * 0.22),
                                     draws: ms, cells: xs.map { usable * $0 }))
            }
        case .graph(let g):
            let m = measureGraph(g, style: style, width: usable)
            placed.append(Placed(ascent: m.ascent, descent: 0, draws: [(0, m)]))
        }
    }
    let gapBetween = size * (style.leading - 1)
    var height = margin * 2
    for p in placed { height += p.ascent + p.descent + p.extra + (p.draws.isEmpty && !p.rule ? 0 : gapBetween) }
    let h = Int(height.rounded(.up))
    guard let ctx = CGContext(data: nil, width: width, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    ctx.setFillColor(style.paper)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: h))
    ctx.setFillColor(style.ink)
    ctx.setStrokeColor(style.ink)
    ctx.setShouldAntialias(true)
    ctx.setShouldSmoothFonts(false)
    var top = margin
    var frame: (top: CGFloat, title: String?)?
    let stroke = max(1.5, size / 22)
    for p in placed {
        let baseline = CGFloat(h) - (top + p.ascent)
        if p.rule {
            ctx.fill(CGRect(x: margin, y: baseline, width: usable, height: max(1.5, size / 20)))
        }
        if let start = p.frameStart { frame = (top + size * 0.3, start) }
        if p.frameEnd, let f = frame {
            let rect = CGRect(x: margin, y: CGFloat(h) - (top + p.extra), width: usable, height: top + p.extra - f.top)
            ctx.setLineWidth(stroke)
            ctx.stroke(rect)
            if let title = f.title {
                let m = measureText(attributed(title, math: false, size: size, style: style))
                let x = margin + (usable - m.width) / 2
                ctx.setFillColor(style.paper)
                ctx.fill(CGRect(x: x - size * 0.3, y: rect.maxY - size * 0.6, width: m.width + size * 0.6, height: size * 1.2))
                ctx.setFillColor(style.ink)
                m.draw(ctx, CGPoint(x: x, y: rect.maxY - size * 0.33))
            }
            frame = nil
        }
        if let cells = p.cells {
            let rowTop = CGFloat(h) - (top - gapBetween * 0.45), rowBottom = CGFloat(h) - (top + p.ascent + p.descent + gapBetween * 0.55)
            ctx.setLineWidth(stroke)
            for k in 0..<(cells.count - 1) {
                ctx.stroke(CGRect(x: margin + cells[k], y: rowBottom, width: cells[k + 1] - cells[k], height: rowTop - rowBottom))
            }
        }
        for (x, m) in p.draws { m.draw(ctx, CGPoint(x: margin + x, y: baseline)) }
        top += p.ascent + p.descent + p.extra + (p.draws.isEmpty && !p.rule ? 0 : gapBetween)
    }
    return ctx.makeImage()
}
