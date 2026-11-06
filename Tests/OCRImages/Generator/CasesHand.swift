import CoreGraphics
import CoreText
import Foundation

// 학생 필기가 있는 문제 사진: 인쇄된 문제 위에 연필·볼펜(파랑·빨강·검정)으로
// 풀이 계산, 보기 동그라미·X·빗금, 써 넣은 답, 밑줄, 줄 사이 메모, 체크 표시를 얹음.
// 정답: 인쇄된 문제 그대로 (보기·수식·문장) + 필기 글(leaks)이 읽은 글에 섞이면 안 됨

enum Pen {
    case pencil, darkPencil, blue, red, black

    var name: String {
        switch self {
        case .pencil: return "연필"
        case .darkPencil: return "진한연필"
        case .blue: return "파랑"
        case .red: return "빨강"
        case .black: return "검정"
        }
    }
    var color: CGColor {
        switch self {
        case .pencil: return CGColor(red: 0.47, green: 0.47, blue: 0.49, alpha: 0.85)
        case .darkPencil: return CGColor(red: 0.33, green: 0.33, blue: 0.35, alpha: 0.9)
        case .blue: return CGColor(red: 0.1, green: 0.22, blue: 0.72, alpha: 1)
        case .red: return CGColor(red: 0.84, green: 0.12, blue: 0.14, alpha: 1)
        case .black: return CGColor(red: 0.1, green: 0.1, blue: 0.14, alpha: 1)
        }
    }
    /// 선 두께 (글자 크기 배수)
    var width: CGFloat { self == .pencil || self == .darkPencil ? 0.06 : 0.07 }
}

enum Mark {
    /// 문제 아래 빈 곳에 풀이 줄들
    case work([String], Pen)
    /// 문제 글 끝 옆에 (써 넣은 답)
    case side(String, Pen)
    /// 첫 줄과 다음 줄 사이에 작은 메모
    case between(String, Pen)
    /// 보기 번호에 동그라미 (0부터)
    case circle(Int, Pen)
    /// 보기에 X
    case cross(Int, Pen)
    /// 보기 번호에 빗금
    case slash(Int, Pen)
    /// 첫 줄 밑줄 (물결)
    case underline(Pen)
    /// 문제 번호 옆 체크
    case check(Pen)
}

struct HandVariant {
    var tag: String
    var marks: [Mark]
    /// 읽은 글에 있으면 안 되는 필기 (띄어쓰기 무시, "|"는 또는)
    var leaks: [String]
    /// 학생이 써 넣은 답 (읽은 글에서 정답으로 잡히면 안 됨)
    var answer: String?
}

// MARK: - 글꼴

private func available(_ names: [String], size: CGFloat) -> CTFont? {
    for name in names {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        if (CTFontCopyPostScriptName(font) as String) == name { return font }
    }
    return nil
}

let handLatinFonts = ["Noteworthy-Light", "BradleyHandITCTT-Bold", "MarkerFelt-Thin", "ChalkboardSE-Light", "ChalkboardSE-Regular"]
let handKoreanFonts = ["NanumPen", "NanumPenScript-Regular", "NanumBrush", "NanumBrushScript-Regular", "AppleSDGothicNeo-Light"]

// 글꼴 찾기는 없는 이름이면 오래 걸려서 한 번만
let handLatinBase = available(handLatinFonts, size: 40) ?? CTFontCreateWithName("Helvetica" as CFString, 40, nil)
let handKoreanBase = available(handKoreanFonts, size: 40) ?? CTFontCreateWithName("AppleSDGothicNeo-Regular" as CFString, 40, nil)

/// 손글씨처럼: 글자마다 크기·기울기·높낮이를 조금씩 흔들고, 줄 전체를 기울여서
func handText(_ ctx: CGContext, _ text: String, x: CGFloat, top: CGFloat, size: CGFloat, pen: Pen, tilt: CGFloat, rng: inout SeededRandom, pageHeight: CGFloat) -> CGFloat {
    let latin = handLatinBase, korean = handKoreanBase
    ctx.saveGState()
    let baseY = pageHeight - top - size * 0.8
    ctx.translateBy(x: x, y: baseY)
    ctx.rotate(by: tilt * .pi / 180)
    var cx: CGFloat = 0
    for ch in text {
        if ch == " " { cx += size * 0.35; continue }
        let isKorean = ch.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
        let scale = rng.range(0.88, 1.14)
        let font = CTFontCreateCopyWithAttributes(isKorean ? korean : latin, size * scale, nil, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): pen.color
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(ch), attributes: attrs))
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        ctx.saveGState()
        ctx.translateBy(x: cx, y: rng.range(-0.07, 0.07) * size)
        ctx.rotate(by: rng.range(-7, 7) * .pi / 180)
        ctx.textMatrix = CGAffineTransform(a: 1, b: 0, c: rng.range(0.05, 0.22), d: 1, tx: 0, ty: 0)
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
        cx += width * rng.range(0.95, 1.1)
    }
    ctx.restoreGState()
    return cx
}

/// 손으로 그린 선 (조금씩 흔들림)
private func handStroke(_ ctx: CGContext, _ points: [CGPoint], pen: Pen, size: CGFloat, pageHeight: CGFloat) {
    guard let first = points.first else { return }
    ctx.saveGState()
    ctx.setStrokeColor(pen.color)
    ctx.setLineWidth(max(2, size * pen.width))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: first.x, y: pageHeight - first.y))
    for p in points.dropFirst() { ctx.addLine(to: CGPoint(x: p.x, y: pageHeight - p.y)) }
    ctx.strokePath()
    ctx.restoreGState()
}

private func wobblyLine(from a: CGPoint, to b: CGPoint, wave: CGFloat, rng: inout SeededRandom) -> [CGPoint] {
    let n = 24
    let phase = rng.range(0, 6.28)
    let dx = b.x - a.x, dy = b.y - a.y
    let len = max(1, hypot(dx, dy))
    return (0...n).map { k in
        let t = CGFloat(k) / CGFloat(n)
        let off = sin(t * 9 + phase) * wave
        return CGPoint(x: a.x + dx * t - dy / len * off, y: a.y + dy * t + dx / len * off)
    }
}

/// 손으로 그린 동그라미: 조금 찌그러지고 끝이 겹침
private func handEllipse(center c: CGPoint, rx: CGFloat, ry: CGFloat, rng: inout SeededRandom) -> [CGPoint] {
    let start = rng.range(0, 6.28), sweep = 2 * CGFloat.pi + rng.range(0.25, 0.6)
    let wob = rng.range(0.03, 0.08), phase = rng.range(0, 6.28)
    return (0...60).map { k in
        let t = start + sweep * CGFloat(k) / 60
        let r = 1 + wob * sin(3 * t + phase) + 0.04 * CGFloat(k) / 60
        return CGPoint(x: c.x + rx * r * cos(t), y: c.y + ry * r * sin(t))
    }
}

// MARK: - 필기 얹기

/// 페이지(CGImage) 위에 필기를 그린 새 사진
func overlayHandwriting(_ page: CGImage, marks: [Mark], items: [RenderedItem], size: CGFloat, seed: UInt64) -> CGImage? {
    let w = page.width, h = page.height
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    ctx.draw(page, in: CGRect(x: 0, y: 0, width: w, height: h))
    ctx.setShouldAntialias(true)
    var rng = SeededRandom(seed)
    let H = CGFloat(h)
    let flows = items.filter { $0.choice == nil }
    let rows = Dictionary(grouping: flows, by: \.row).sorted { $0.key < $1.key }.map { $0.value }
    let choices = items.filter { $0.choice != nil }.sorted { $0.choice! < $1.choice! }
    let contentBottom = items.map(\.rect.maxY).max() ?? H * 0.6
    let firstRow = rows.first?.map(\.rect).reduce(CGRect.null) { $0.union($1) } ?? CGRect(x: size, y: size, width: size * 10, height: size)
    let lastFlow = rows.last?.map(\.rect).reduce(CGRect.null) { $0.union($1) } ?? firstRow
    var workColumn: CGFloat = 0
    for mark in marks {
        switch mark {
        case .work(let lines, let pen):
            let x0 = size * 1.6 + workColumn + rng.range(0, size)
            var top = contentBottom + size * rng.range(0.5, 0.9)
            let tilt = rng.range(-6, 6)
            var widest: CGFloat = 0
            for line in lines {
                let s = size * rng.range(0.95, 1.3)
                widest = max(widest, handText(ctx, line, x: x0 + rng.range(-size * 0.3, size * 0.3), top: top, size: s, pen: pen, tilt: tilt, rng: &rng, pageHeight: H))
                top += s * rng.range(1.25, 1.5)
            }
            workColumn += widest + size * 2.5
        case .side(let text, let pen):
            let s = size * rng.range(1.0, 1.25)
            var x = lastFlow.maxX + size * 0.8
            var top = lastFlow.minY - size * 0.1
            if x + s * CGFloat(text.count) * 0.7 > CGFloat(w) - size * 0.4 {
                // 글 끝 옆에 자리가 없으면 줄 위 오른쪽 여백
                x = CGFloat(w) - size * (0.8 + CGFloat(text.count) * 0.7)
                top = max(size * 0.1, firstRow.minY - size * 1.15)
            }
            _ = handText(ctx, text, x: x, top: top, size: s, pen: pen, tilt: rng.range(-8, 4), rng: &rng, pageHeight: H)
        case .between(let text, let pen):
            let s = size * 0.72
            let x = firstRow.minX + firstRow.width * rng.range(0.25, 0.55)
            _ = handText(ctx, text, x: x, top: firstRow.maxY - size * 0.05, size: s, pen: pen, tilt: rng.range(-4, 4), rng: &rng, pageHeight: H)
        case .circle(let n, let pen):
            guard n < choices.count else { continue }
            let r = choices[n].rect
            let center = CGPoint(x: r.minX + size * 0.45 + rng.range(-3, 3), y: r.minY + r.height * 0.45 + rng.range(-3, 3))
            handStroke(ctx, handEllipse(center: center, rx: size * rng.range(0.62, 0.8), ry: size * rng.range(0.55, 0.72), rng: &rng), pen: pen, size: size, pageHeight: H)
        case .cross(let n, let pen):
            guard n < choices.count else { continue }
            let r = choices[n].rect.insetBy(dx: -size * 0.1, dy: size * 0.1)
            handStroke(ctx, wobblyLine(from: CGPoint(x: r.minX, y: r.minY), to: CGPoint(x: r.maxX, y: r.maxY), wave: size * 0.04, rng: &rng), pen: pen, size: size, pageHeight: H)
            handStroke(ctx, wobblyLine(from: CGPoint(x: r.maxX, y: r.minY), to: CGPoint(x: r.minX, y: r.maxY), wave: size * 0.04, rng: &rng), pen: pen, size: size, pageHeight: H)
        case .slash(let n, let pen):
            guard n < choices.count else { continue }
            let r = choices[n].rect
            handStroke(ctx, wobblyLine(from: CGPoint(x: r.minX + size * 0.95, y: r.minY - size * 0.1), to: CGPoint(x: r.minX - size * 0.05, y: r.maxY + size * 0.1),
                                       wave: size * 0.03, rng: &rng), pen: pen, size: size, pageHeight: H)
        case .underline(let pen):
            let x0 = firstRow.minX + firstRow.width * rng.range(0.2, 0.35), x1 = firstRow.minX + firstRow.width * rng.range(0.6, 0.95)
            let y = firstRow.maxY - size * 0.05
            handStroke(ctx, wobblyLine(from: CGPoint(x: x0, y: y), to: CGPoint(x: x1, y: y + rng.range(-4, 4)), wave: size * 0.06, rng: &rng), pen: pen, size: size, pageHeight: H)
        case .check(let pen):
            let x = max(4, firstRow.minX - size * 1.15), y = firstRow.midY
            handStroke(ctx, [CGPoint(x: x, y: y - size * 0.05), CGPoint(x: x + size * 0.3, y: y + size * 0.35), CGPoint(x: x + size * 0.85, y: y - size * 0.55)],
                       pen: pen, size: size, pageHeight: H)
        }
    }
    return ctx.makeImage()
}

// MARK: - 사례

/// 비교용: 띄어쓰기 없애고 기호 모양 통일 (Checks.swift의 norm과 같게)
func handNorm(_ s: String) -> String {
    var t = s.replacingOccurrences(of: "²", with: "^2").replacingOccurrences(of: "³", with: "^3")
    t = t.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "–", with: "-")
    t = t.replacingOccurrences(of: "＝", with: "=").replacingOccurrences(of: "，", with: ",")
    return t.filter { !$0.isWhitespace }.lowercased()
}

/// 인쇄된 글 (필기 글이 원래 문제에 있으면 검사에서 뺌)
func printedPlain(_ content: Content) -> String {
    var parts: [String] = []
    for line in content.lines {
        switch line {
        case .flow(let segs): parts.append(plain(segs))
        case .grid(let items, _): parts += items.map(plain)
        case .columns(let cells): parts += cells.map { plain($0.0) }
        case .boxed(let title, let rows): parts.append(title ?? ""); parts += rows.map(plain)
        case .table(let rows, _): parts += rows.flatMap { $0.map(plain) }
        case .graph(let g): parts += [g.xLabel, g.yLabel] + g.xTicks + g.yTicks
        case .space, .rule: break
        }
    }
    return parts.joined(separator: "\n")
}

/// 수학 문제 필기 4가지 (펜을 돌려 가며)
func mathVariants(answer: Int) -> [HandVariant] {
    let circled = ["①", "②", "③", "④", "⑤"][answer]
    let other = (answer + 2) % 5
    return [
        HandVariant(tag: "pencil", marks: [.work(["2x = 8", "x = 4"], .pencil), .circle(answer, .pencil), .side("답: \(answer + 1)", .pencil)],
                    leaks: ["2x=8", "x=4", "답:\(answer + 1)|답\(answer + 1)"], answer: "\(answer + 1)"),
        HandVariant(tag: "red", marks: [.check(.red), .circle(answer, .red), .slash(other, .red), .work(["3×4=12", "12-5=7"], .red)],
                    leaks: ["3×4=12|3x4=12", "12-5=7"]),
        HandVariant(tag: "blue", marks: [.underline(.blue), .cross(other, .blue), .between("조건 확인!", .blue), .work(["a+b=9", "ab=14"], .blue)],
                    leaks: ["a+b=9", "ab=14", "조건확인"]),
        HandVariant(tag: "black", marks: [.work(["y = 3x - 1", "→ 기울기 3"], .black), .circle(answer, .black), .side(circled, .black)],
                    leaks: ["y=3x-1", "기울기3"], answer: circled),
        HandVariant(tag: "dark", marks: [.work(["16 ÷ 4 = 4", "4 + 7 = 11"], .darkPencil), .slash(other, .darkPencil), .side("정답 \(circled)", .darkPencil)],
                    leaks: ["16÷4=4", "4+7=11", "정답\(circled)"], answer: circled),
    ]
}

/// 국어·영어·과학·사회 필기 4가지
func subjectVariants(answer: Int) -> [HandVariant] {
    let circled = ["①", "②", "③", "④", "⑤"][answer]
    let other = (answer + 3) % 5
    return [
        HandVariant(tag: "pencil", marks: [.underline(.pencil), .circle(answer, .pencil), .work(["주제 = 핵심 문장", "답 \(circled)"], .pencil)],
                    leaks: ["주제=핵심문장", "답\(circled)"], answer: circled),
        HandVariant(tag: "red", marks: [.check(.red), .slash(other, .red), .circle(answer, .red), .side("정답 \(circled)", .red)],
                    leaks: ["정답\(circled)"], answer: circled),
        HandVariant(tag: "blue", marks: [.between("여기 중요", .blue), .cross(other, .blue), .work(["헷갈림 → 다시 보기"], .blue)],
                    leaks: ["여기중요", "헷갈림", "다시보기"]),
        HandVariant(tag: "black", marks: [.circle(answer, .black), .work(["오답 이유: 개념 부족"], .black), .side("답: \(circled)", .black)],
                    leaks: ["오답이유", "개념부족", "답:\(circled)|답\(circled)"], answer: circled),
        HandVariant(tag: "dark", marks: [.underline(.darkPencil), .work(["S V O", "핵심어 체크"], .darkPencil), .slash(other, .darkPencil)],
                    leaks: ["SVO", "핵심어체크"]),
    ]
}

/// 필기를 얹을 문제 (깨끗한 사진에서 잘 읽히는 것) + 학생이 고른 답
let handBases: [(id: String, answer: Int)] = [
    ("m-linear", 2), ("m-func", 0), ("m-decimal", 1), ("m-row4", 1), ("m-blank-add", 3), ("m-quad-neg", 1), ("m-stack-words", 2),
    ("m-short-system", 0), ("m-short-poly", 0), ("m-blank-div", 0), ("g-arc", 2), ("g-polygon", 3), ("g-inscribed", 1), ("g-quad", 2), ("g-pi", 4),
    ("k-pos", 3), ("k-reading", 1), ("e-blank", 2), ("e-order", 4), ("e-passage-blank", 0), ("e-grammar", 3),
    ("so-city", 2), ("so-joseon", 0), ("s-experiment", 1), ("s-stack", 3),
]

/// 필기 사진 만들기 (emit과 같은 손상, 이름 hw-<문제>-<필기>__<손상>)
func emitHandwriting(_ all: [Content], degrades: [Degrade]) {
    let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    let latin = CTFontCopyPostScriptName(handLatinBase) as String
    let korean = CTFontCopyPostScriptName(handKoreanBase) as String
    print("필기 글꼴: \(latin) / \(korean)")
    var handSeed: UInt64 = 9001
    for (k, base) in handBases.enumerated() {
        guard var content = byID[base.id] else { print("✗ 필기 문제 없음: \(base.id)"); continue }
        let printed = handNorm(printedPlain(content))
        let variants = content.kind == "subject" ? subjectVariants(answer: base.answer) : mathVariants(answer: base.answer)
        // 필터에 걸리는 사진이 없으면 그리지 않고 씨앗만 진행 (아래 반복과 같은 만큼)
        let picked = [variants[k % variants.count], variants[(k + 2) % variants.count]]
        var anyWanted = wanted("hw-\(base.id)-none__clean")
        for (j, variant) in picked.enumerated() {
            for d in [Degrade.clean, degrades[(k + j) % degrades.count]] where wanted("hw-\(base.id)-\(variant.tag)__\(d.name)") { anyWanted = true }
        }
        if !anyWanted { seed &+= 5; handSeed &+= 34; continue }
        // 풀이를 쓸 빈 곳
        content.lines.append(.space(4.2))
        var style = variantStyle(content.style, index: k)
        style.size = 40
        guard let page = renderPage(content.lines, style: style, width: content.width, margin: style.size * 1.4) else { continue }
        let items = renderedItems
        // 필기 없는 같은 사진 (지우기가 인쇄를 망가뜨리지 않는지, 글자 차이 기준)
        let category = "hw-" + (content.category.split(separator: "-").first.map(String.init) ?? content.category)
        var plainExpect = content.expect
        plainExpect.leaks = []
        seed &+= 1
        let plainName = "hw-\(base.id)-none__clean.jpg"
        if wanted("hw-\(base.id)-none__clean"), writeJPEG(degrade(page, .clean, seed: seed), to: imageDir.appendingPathComponent(plainName), quality: Degrade.clean.jpeg) {
            specs.append(CaseSpec(id: "hw-\(base.id)-none__clean", category: category, kind: content.kind, degrade: "clean", image: "images/\(plainName)", expect: plainExpect))
        }
        for (j, variant) in picked.enumerated() {
            handSeed &+= 17
            let id = "hw-\(base.id)-\(variant.tag)"
            let ds = [Degrade.clean, degrades[(k + j) % degrades.count]]
            if !ds.contains(where: { wanted("\(id)__\($0.name)") }) { seed &+= 2; continue }
            guard let marked = overlayHandwriting(page, marks: variant.marks, items: items, size: style.size, seed: handSeed) else { continue }
            let leaks = variant.leaks.filter { leak in
                let found = leak.split(separator: "|").contains { printed.contains(handNorm(String($0))) }
                if found { print("  (필기 검사 뺌: \(base.id) \(leak) — 인쇄 글에 있음)") }
                return !found
            }
            var expect = content.expect
            expect.leaks = leaks
            expect.handAnswer = variant.answer
            for d in ds {
                seed &+= 1
                guard wanted("\(id)__\(d.name)") else { continue }
                let image = degrade(marked, d, seed: seed)
                let name = "\(id)__\(d.name).jpg"
                guard writeJPEG(image, to: imageDir.appendingPathComponent(name), quality: d.jpeg) else { continue }
                specs.append(CaseSpec(id: "\(id)__\(d.name)", category: category, kind: content.kind, degrade: d.name, image: "images/\(name)", expect: expect))
            }
        }
    }
}
