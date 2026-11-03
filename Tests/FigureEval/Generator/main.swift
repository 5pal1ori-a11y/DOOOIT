import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 그림 읽기 확인용 문제 사진 만들기 (맥): 도형·좌표 그래프·차트·표 20장 + 정답 cases.json
//   figure-generate <출력 폴더>
// 정답은 "그림에 보이는 사실" (길이·각·직각·평행, 지나는 점, 자료 값)

struct Value: Codable { var label: String; var value: Double; var tolerance: Double }
struct Case: Codable {
    var id: String
    var group: String          // geometry, graph, chart, table
    var problem: String        // 문제 글 (사진 위쪽에 씀)
    var facts: [String]        // 결과 줄(띄어쓰기·윗줄 뺀 소문자)에 있어야 하는 것
    var values: [Value]        // 자료 값
    var equation: String?      // 그래프 식 (띄어쓰기 뺀 것)
}

let W = 900, H = 720
let ink = CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)

func makeContext() -> CGContext {
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    // 위가 0인 좌표로
    ctx.translateBy(x: 0, y: CGFloat(H))
    ctx.scaleBy(x: 1, y: -1)
    ctx.setStrokeColor(ink)
    ctx.setFillColor(ink)
    ctx.setLineWidth(3)
    return ctx
}

func text(_ ctx: CGContext, _ s: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat = 26, italic: Bool = false, center: Bool = true) {
    let name = italic ? "Times New Roman Italic" : "AppleSDGothicNeo-Regular"
    let font = CTFontCreateWithName(name as CFString, size, nil)
    let attr = NSAttributedString(string: s, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font,
                                                         NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink])
    let line = CTLineCreateWithAttributedString(attr)
    let bounds = CTLineGetBoundsWithOptions(line, [])
    ctx.saveGState()
    ctx.textMatrix = .identity
    ctx.translateBy(x: center ? x - bounds.width / 2 : x, y: y + (center ? bounds.height / 3 : 0))
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func line(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint, width: CGFloat = 3) {
    ctx.setLineWidth(width)
    ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
}

func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }

/// 변 바깥쪽에 길이 숫자
func sideLabel(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint, _ s: String, away c: CGPoint) {
    let m = mid(a, b)
    var dx = m.x - c.x, dy = m.y - c.y
    let len = max(1, (dx * dx + dy * dy).squareRoot())
    dx /= len; dy /= len
    text(ctx, s, m.x + dx * 30, m.y + dy * 30)
}

func vertexLabel(_ ctx: CGContext, _ p: CGPoint, _ s: String, from c: CGPoint) {
    var dx = p.x - c.x, dy = p.y - c.y
    let len = max(1, (dx * dx + dy * dy).squareRoot())
    dx /= len; dy /= len
    text(ctx, s, p.x + dx * 28, p.y + dy * 28, size: 28)
}

func rightMark(_ ctx: CGContext, _ p: CGPoint, toward a: CGPoint, _ b: CGPoint, size: CGFloat = 22) {
    func unit(_ q: CGPoint) -> CGPoint { let dx = q.x - p.x, dy = q.y - p.y; let l = (dx * dx + dy * dy).squareRoot(); return CGPoint(x: dx / l, y: dy / l) }
    let u = unit(a), v = unit(b)
    let p1 = CGPoint(x: p.x + u.x * size, y: p.y + u.y * size)
    let p2 = CGPoint(x: p1.x + v.x * size, y: p1.y + v.y * size)
    let p3 = CGPoint(x: p.x + v.x * size, y: p.y + v.y * size)
    ctx.setLineWidth(2)
    ctx.move(to: p1); ctx.addLine(to: p2); ctx.addLine(to: p3); ctx.strokePath()
}

func problemText(_ ctx: CGContext, _ s: String) { text(ctx, s, 40, 50, size: 26, center: false) }

func centroid(_ pts: [CGPoint]) -> CGPoint { CGPoint(x: pts.map(\.x).reduce(0, +) / CGFloat(pts.count), y: pts.map(\.y).reduce(0, +) / CGFloat(pts.count)) }

func triangle(_ ctx: CGContext, _ p: [CGPoint], names: [String]) {
    ctx.setLineWidth(3)
    ctx.move(to: p[0]); ctx.addLine(to: p[1]); ctx.addLine(to: p[2]); ctx.closePath(); ctx.strokePath()
    let c = centroid(p)
    for i in 0..<3 { vertexLabel(ctx, p[i], names[i], from: c) }
}

// MARK: - 좌표평면

struct Plane {
    var origin: CGPoint
    var unit: CGFloat
    var xr: ClosedRange<Int>
    var yr: ClosedRange<Int>
    func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: origin.x + CGFloat(x) * unit, y: origin.y - CGFloat(y) * unit) }
}

func axes(_ ctx: CGContext, _ p: Plane, ticks: Bool) {
    let left = p.pt(Double(p.xr.lowerBound) - 0.5, 0), right = p.pt(Double(p.xr.upperBound) + 0.5, 0)
    let bottom = p.pt(0, Double(p.yr.lowerBound) - 0.5), top = p.pt(0, Double(p.yr.upperBound) + 0.5)
    line(ctx, left, right, width: 2); line(ctx, bottom, top, width: 2)
    text(ctx, "x", right.x + 14, right.y + 4, italic: true)
    text(ctx, "y", top.x + 16, top.y - 4, italic: true)
    text(ctx, "O", p.origin.x - 16, p.origin.y + 20, italic: true)
    guard ticks else { return }
    for x in p.xr where x != 0 {
        let q = p.pt(Double(x), 0); line(ctx, CGPoint(x: q.x, y: q.y - 5), CGPoint(x: q.x, y: q.y + 5), width: 2)
        text(ctx, String(x), q.x, q.y + 24, size: 20)
    }
    for y in p.yr where y != 0 {
        let q = p.pt(0, Double(y)); line(ctx, CGPoint(x: q.x - 5, y: q.y), CGPoint(x: q.x + 5, y: q.y), width: 2)
        text(ctx, String(y), q.x - 22, q.y, size: 20)
    }
}

func curve(_ ctx: CGContext, _ p: Plane, from x0: Double, to x1: Double, _ f: (Double) -> Double) {
    ctx.setLineWidth(3)
    var first = true
    var x = x0
    while x <= x1 {
        let q = p.pt(x, f(x))
        if first { ctx.move(to: q); first = false } else { ctx.addLine(to: q) }
        x += 0.02
    }
    ctx.strokePath()
}

func dot(_ ctx: CGContext, _ q: CGPoint, label: String?, dx: CGFloat = 40, dy: CGFloat = -18) {
    ctx.fillEllipse(in: CGRect(x: q.x - 6, y: q.y - 6, width: 12, height: 12))
    if let label { text(ctx, label, q.x + dx, q.y + dy, size: 22) }
}

// MARK: - 차트

func barChart(_ ctx: CGContext, labels: [String], values: [Double], maxValue: Double, step: Double, showValues: Bool, unit: String) {
    let left: CGFloat = 130, bottom: CGFloat = 620, top: CGFloat = 150, right: CGFloat = 840
    line(ctx, CGPoint(x: left, y: bottom), CGPoint(x: right, y: bottom), width: 2)
    line(ctx, CGPoint(x: left, y: bottom), CGPoint(x: left, y: top - 20), width: 2)
    text(ctx, unit, left - 10, top - 40, size: 20)
    var v = 0.0
    while v <= maxValue + 1e-9 {
        let y = bottom - CGFloat(v / maxValue) * (bottom - top)
        ctx.setStrokeColor(CGColor(gray: 0.8, alpha: 1)); line(ctx, CGPoint(x: left, y: y), CGPoint(x: right, y: y), width: 1); ctx.setStrokeColor(ink)
        text(ctx, String(Int(v)), left - 40, y, size: 20)
        v += step
    }
    let slot = (right - left) / CGFloat(labels.count)
    for (i, label) in labels.enumerated() {
        let h = CGFloat(values[i] / maxValue) * (bottom - top)
        let x = left + slot * CGFloat(i) + slot * 0.25
        ctx.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.85, alpha: 1))
        ctx.fill(CGRect(x: x, y: bottom - h, width: slot * 0.5, height: h))
        ctx.setFillColor(ink)
        text(ctx, label, x + slot * 0.25, bottom + 28, size: 22)
        if showValues { text(ctx, fmt(values[i]), x + slot * 0.25, bottom - h - 18, size: 20) }
    }
}

func lineChart(_ ctx: CGContext, labels: [String], values: [Double], maxValue: Double, step: Double, unit: String) {
    let left: CGFloat = 130, bottom: CGFloat = 620, top: CGFloat = 150, right: CGFloat = 840
    line(ctx, CGPoint(x: left, y: bottom), CGPoint(x: right, y: bottom), width: 2)
    line(ctx, CGPoint(x: left, y: bottom), CGPoint(x: left, y: top - 20), width: 2)
    text(ctx, unit, left - 10, top - 40, size: 20)
    var v = 0.0
    while v <= maxValue + 1e-9 {
        let y = bottom - CGFloat(v / maxValue) * (bottom - top)
        text(ctx, String(Int(v)), left - 40, y, size: 20)
        v += step
    }
    let slot = (right - left) / CGFloat(labels.count)
    var pts: [CGPoint] = []
    for (i, label) in labels.enumerated() {
        let x = left + slot * (CGFloat(i) + 0.5)
        let y = bottom - CGFloat(values[i] / maxValue) * (bottom - top)
        pts.append(CGPoint(x: x, y: y))
        text(ctx, label, x, bottom + 28, size: 20)
    }
    ctx.setLineWidth(3)
    ctx.move(to: pts[0]); for p in pts.dropFirst() { ctx.addLine(to: p) }; ctx.strokePath()
    for (i, p) in pts.enumerated() { dot(ctx, p, label: fmt(values[i]), dx: 0, dy: -26) }
}

func pieChart(_ ctx: CGContext, labels: [String], percents: [Double]) {
    let c = CGPoint(x: 450, y: 400), r: CGFloat = 220
    var start = -CGFloat.pi / 2
    let colors: [CGColor] = [CGColor(red: 0.95, green: 0.6, blue: 0.5, alpha: 1), CGColor(red: 0.6, green: 0.8, blue: 0.95, alpha: 1),
                             CGColor(red: 0.7, green: 0.9, blue: 0.6, alpha: 1), CGColor(red: 0.95, green: 0.9, blue: 0.5, alpha: 1), CGColor(gray: 0.85, alpha: 1)]
    for (i, p) in percents.enumerated() {
        let end = start + CGFloat(p / 100) * 2 * .pi
        ctx.setFillColor(colors[i % colors.count])
        ctx.move(to: c); ctx.addArc(center: c, radius: r, startAngle: start, endAngle: end, clockwise: false); ctx.closePath(); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(2)
        ctx.move(to: c); ctx.addArc(center: c, radius: r, startAngle: start, endAngle: end, clockwise: false); ctx.closePath(); ctx.strokePath()
        let midAngle = (start + end) / 2
        ctx.setFillColor(ink)
        text(ctx, "\(labels[i]) \(fmt(p))%", c.x + cos(midAngle) * r * 0.6, c.y + sin(midAngle) * r * 0.6, size: 24)
        start = end
    }
}

func table(_ ctx: CGContext, _ rows: [[String]], top: CGFloat = 160) {
    let cols = rows[0].count
    let cellW: CGFloat = min(180, 800 / CGFloat(cols)), cellH: CGFloat = 60
    let left = (CGFloat(W) - cellW * CGFloat(cols)) / 2
    for (r, row) in rows.enumerated() {
        for (c, cell) in row.enumerated() {
            let rect = CGRect(x: left + CGFloat(c) * cellW, y: top + CGFloat(r) * cellH, width: cellW, height: cellH)
            if r == 0 { ctx.setFillColor(CGColor(gray: 0.9, alpha: 1)); ctx.fill(rect); ctx.setFillColor(ink) }
            ctx.setLineWidth(2); ctx.stroke(rect)
            text(ctx, cell, rect.midX, rect.midY, size: 24)
        }
    }
}

func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(v) }

// MARK: - 사진 20장

var cases: [Case] = []
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "figure-cases")
try? FileManager.default.createDirectory(at: out.appendingPathComponent("images"), withIntermediateDirectories: true)

func save(_ ctx: CGContext, _ c: Case) {
    let url = out.appendingPathComponent("images/\(c.id).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    cases.append(c)
}

func add(_ id: String, _ group: String, _ problem: String, facts: [String] = [], values: [Value] = [], equation: String? = nil, draw: (CGContext) -> Void) {
    let ctx = makeContext()
    problemText(ctx, problem)
    draw(ctx)
    save(ctx, Case(id: id, group: group, problem: problem, facts: facts, values: values, equation: equation))
}

func vals(_ labels: [String], _ values: [Double], tol: Double) -> [Value] { zip(labels, values).map { Value(label: $0, value: $1, tolerance: tol) } }

// 도형
add("geo-tri-sides", "geometry", "그림의 삼각형 ABC의 둘레의 길이를 구하시오.", facts: ["ab=7", "bc=8", "ac=5"]) { ctx in
    let p = [CGPoint(x: 420, y: 190), CGPoint(x: 200, y: 600), CGPoint(x: 720, y: 600)]
    triangle(ctx, p, names: ["A", "B", "C"])
    sideLabel(ctx, p[0], p[1], "7", away: centroid(p)); sideLabel(ctx, p[1], p[2], "8", away: centroid(p)); sideLabel(ctx, p[0], p[2], "5", away: centroid(p))
}
add("geo-right-c", "geometry", "그림의 직각삼각형 ABC에서 BC의 길이를 구하시오.", facts: ["∠c=90°", "ab=10", "ac=6"]) { ctx in
    let p = [CGPoint(x: 220, y: 180), CGPoint(x: 700, y: 600), CGPoint(x: 220, y: 600)]
    triangle(ctx, p, names: ["A", "B", "C"])
    rightMark(ctx, p[2], toward: p[0], p[1])
    sideLabel(ctx, p[0], p[1], "10", away: centroid(p)); sideLabel(ctx, p[0], p[2], "6", away: centroid(p))
}
add("geo-right-b", "geometry", "그림에서 AC의 길이를 구하시오.", facts: ["∠b=90°", "ab=5", "bc=12"]) { ctx in
    let p = [CGPoint(x: 200, y: 260), CGPoint(x: 200, y: 600), CGPoint(x: 760, y: 600)]
    triangle(ctx, p, names: ["A", "B", "C"])
    rightMark(ctx, p[1], toward: p[0], p[2])
    sideLabel(ctx, p[0], p[1], "5", away: centroid(p)); sideLabel(ctx, p[1], p[2], "12", away: centroid(p))
}
add("geo-angles", "geometry", "그림의 삼각형 ABC에서 ∠C의 크기를 구하시오.", facts: ["∠a=50°", "∠b=70°"]) { ctx in
    let p = [CGPoint(x: 380, y: 190), CGPoint(x: 180, y: 600), CGPoint(x: 740, y: 600)]
    triangle(ctx, p, names: ["A", "B", "C"])
    text(ctx, "50°", p[0].x + 6, p[0].y + 70, size: 24)
    text(ctx, "70°", p[1].x + 70, p[1].y - 26, size: 24)
}
add("geo-parallel", "geometry", "그림에서 l ∥ m일 때, ∠x의 크기를 구하시오.", facts: ["l∥m", "65°"]) { ctx in
    line(ctx, CGPoint(x: 100, y: 300), CGPoint(x: 800, y: 300)); line(ctx, CGPoint(x: 100, y: 540), CGPoint(x: 800, y: 540))
    text(ctx, "l", 830, 300, italic: true); text(ctx, "m", 830, 540, italic: true)
    for (x, y) in [(250.0, 300.0), (250.0, 540.0)] { // 평행 표시 화살
        ctx.setLineWidth(2); ctx.move(to: CGPoint(x: x - 10, y: y - 10)); ctx.addLine(to: CGPoint(x: x, y: y)); ctx.addLine(to: CGPoint(x: x - 10, y: y + 10)); ctx.strokePath()
    }
    line(ctx, CGPoint(x: 330, y: 180), CGPoint(x: 640, y: 660))
    text(ctx, "65°", 470, 330, size: 24)
    text(ctx, "x", 640, 520, size: 28, italic: true)
}
add("geo-circle", "geometry", "그림의 원 O에서 원주각 ∠APB의 크기를 구하시오.", facts: ["∠aob=80°"]) { ctx in
    let c = CGPoint(x: 450, y: 400), r: CGFloat = 220
    ctx.setLineWidth(3); ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    let a = CGPoint(x: c.x + r * cos(2.4), y: c.y + r * sin(2.4)), b = CGPoint(x: c.x + r * cos(0.74), y: c.y + r * sin(0.74))
    let p = CGPoint(x: c.x + r * cos(-1.57), y: c.y + r * sin(-1.57))
    line(ctx, c, a); line(ctx, c, b); line(ctx, p, a); line(ctx, p, b)
    dot(ctx, c, label: nil)
    text(ctx, "O", c.x, c.y - 26, size: 26); text(ctx, "A", a.x - 26, a.y + 18); text(ctx, "B", b.x + 26, b.y + 18); text(ctx, "P", p.x, p.y - 26)
    text(ctx, "80°", c.x, c.y + 50, size: 24)
}
add("geo-iso", "geometry", "그림의 이등변삼각형 ABC에서 ∠B의 크기를 구하시오.", facts: ["∠a=40°"]) { ctx in
    let p = [CGPoint(x: 450, y: 170), CGPoint(x: 260, y: 620), CGPoint(x: 640, y: 620)]
    triangle(ctx, p, names: ["A", "B", "C"])
    for (a, b) in [(p[0], p[1]), (p[0], p[2])] { let m = mid(a, b); line(ctx, CGPoint(x: m.x - 12, y: m.y - 4), CGPoint(x: m.x + 12, y: m.y + 4), width: 2) }
    text(ctx, "40°", p[0].x, p[0].y + 70, size: 24)
}

// 좌표 그래프
add("graph-line-points", "graph", "그림은 일차함수의 그래프이다. 이 그래프의 식을 구하시오.", equation: "y=2x+1") { ctx in
    let pl = Plane(origin: CGPoint(x: 380, y: 520), unit: 50, xr: -4...6, yr: -3...6)
    axes(ctx, pl, ticks: false)
    curve(ctx, pl, from: -2.2, to: 2.6) { 2 * $0 + 1 }
    dot(ctx, pl.pt(0, 1), label: "(0, 1)", dx: 50, dy: 10); dot(ctx, pl.pt(2, 5), label: "(2, 5)", dx: 50)
}
add("graph-line-intercepts", "graph", "그림과 같은 직선의 방정식을 구하시오.", equation: "y=-2x+6") { ctx in
    let pl = Plane(origin: CGPoint(x: 300, y: 560), unit: 60, xr: -2...6, yr: -2...7)
    axes(ctx, pl, ticks: false)
    curve(ctx, pl, from: -0.4, to: 3.6) { -2 * $0 + 6 }
    text(ctx, "6", pl.pt(0, 6).x - 22, pl.pt(0, 6).y, size: 22); text(ctx, "3", pl.pt(3, 0).x, pl.pt(3, 0).y + 26, size: 22)
}
add("graph-parabola-vertex", "graph", "그림은 이차함수의 그래프이다. 이 이차함수의 식을 구하시오.", equation: "y=3x²-6x+1") { ctx in
    let pl = Plane(origin: CGPoint(x: 360, y: 400), unit: 60, xr: -3...5, yr: -3...5)
    axes(ctx, pl, ticks: false)
    curve(ctx, pl, from: -0.45, to: 2.45) { 3 * $0 * $0 - 6 * $0 + 1 }
    dot(ctx, pl.pt(1, -2), label: "(1, -2)", dx: 60, dy: 16); dot(ctx, pl.pt(0, 1), label: "1", dx: -22, dy: 0)
}
add("graph-parabola-roots", "graph", "그림과 같은 포물선을 그래프로 하는 이차함수의 식을 구하시오.", equation: "y=x²-2x-3") { ctx in
    let pl = Plane(origin: CGPoint(x: 400, y: 380), unit: 55, xr: -3...5, yr: -5...5)
    axes(ctx, pl, ticks: false)
    curve(ctx, pl, from: -1.9, to: 3.9) { $0 * $0 - 2 * $0 - 3 }
    text(ctx, "-1", pl.pt(-1, 0).x - 14, pl.pt(-1, 0).y - 20, size: 22); text(ctx, "3", pl.pt(3, 0).x + 14, pl.pt(3, 0).y - 20, size: 22)
    text(ctx, "-3", pl.pt(0, -3).x - 26, pl.pt(0, -3).y, size: 22)
}
add("graph-line-ticks", "graph", "그림과 같은 일차함수의 그래프의 기울기를 구하시오.", equation: "y=2x+4") { ctx in
    let pl = Plane(origin: CGPoint(x: 480, y: 470), unit: 50, xr: -5...4, yr: -3...6)
    axes(ctx, pl, ticks: true)
    curve(ctx, pl, from: -3.5, to: 1.0) { 2 * $0 + 4 }
}

// 차트
let months = ["1월", "2월", "3월", "4월"], sales = [30.0, 45, 25, 50]
add("chart-bar-labels", "chart", "다음 막대그래프는 월별 판매량이다. 판매량이 가장 많은 달은?", values: vals(months, sales, tol: 0.01)) { ctx in
    barChart(ctx, labels: months, values: sales, maxValue: 60, step: 10, showValues: true, unit: "(개)")
}
let teams = ["A", "B", "C", "D"], points = [20.0, 35, 15, 40]
add("chart-bar-ticks", "chart", "다음 막대그래프에서 B와 D의 차는?", values: vals(teams, points, tol: 2.5)) { ctx in
    barChart(ctx, labels: teams, values: points, maxValue: 50, step: 5, showValues: false, unit: "(점)")
}
let years = ["2018", "2019", "2020", "2021", "2022"], amounts = [12.0, 15, 11, 18, 20]
add("chart-line", "chart", "다음 꺾은선그래프에서 2020년에 대한 2022년의 증가율을 구하시오.", values: vals(years, amounts, tol: 0.01)) { ctx in
    lineChart(ctx, labels: years, values: amounts, maxValue: 25, step: 5, unit: "(만 명)")
}
let fruits = ["사과", "배", "포도", "감"], shares = [40.0, 30, 20, 10]
add("chart-pie", "chart", "다음 원그래프에서 사과를 좋아하는 학생의 비율은?", values: vals(fruits, shares, tol: 0.01)) { ctx in
    pieChart(ctx, labels: fruits, percents: shares)
}
let regions = ["가", "나", "다", "라", "마"], rain = [1200.0, 950, 1430, 800, 1100]
add("chart-bar-regions", "chart", "다음은 지역별 연 강수량을 나타낸 그래프이다. 강수량이 가장 적은 지역은?", values: vals(regions, rain, tol: 0.01)) { ctx in
    barChart(ctx, labels: regions, values: rain, maxValue: 1600, step: 400, showValues: true, unit: "(mm)")
}

// 표
add("table-two", "table", "다음 표는 월별 판매량이다. 판매량의 평균을 구하시오.", values: vals(months, sales, tol: 0.01)) { ctx in
    table(ctx, [["월", "판매량"]] + zip(months, sales).map { [$0, fmt($1)] })
}
add("table-wide", "table", "다음 표는 어느 도시의 인구이다. 2010년에 대한 2020년의 증가율을 구하시오.",
    values: vals(["2010", "2015", "2020"], [120, 135, 150], tol: 0.01)) { ctx in
    table(ctx, [["연도", "2010", "2015", "2020"], ["인구(만 명)", "120", "135", "150"]], top: 220)
}
add("table-grid", "table", "다음 표는 두 반의 과목별 평균 점수이다. 2반의 수학 점수를 구하시오.",
    values: [Value(label: "국어", value: 72, tolerance: 0.01), Value(label: "수학", value: 81, tolerance: 0.01), Value(label: "영어", value: 77, tolerance: 0.01)]) { ctx in
    table(ctx, [["과목", "1반", "2반"], ["국어", "78", "72"], ["수학", "65", "81"], ["영어", "88", "77"]])
}

let data = try JSONEncoder().encode(cases)
try data.write(to: out.appendingPathComponent("cases.json"))
print("그림 \(cases.count)장 → \(out.path)")
