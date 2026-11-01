import Foundation

// 그래프·도형 판독 테스트: 그림을 코드로 그려서 GraphReader / ShapeReader가 맞게 읽는지 확인

// MARK: - 그림판

struct Canvas {
    let w: Int, h: Int
    var gray: [UInt8]
    var chroma: [UInt8]
    var labels: [TextLabel] = []

    init(_ w: Int, _ h: Int) {
        self.w = w; self.h = h
        gray = [UInt8](repeating: 255, count: w * h)
        chroma = [UInt8](repeating: 0, count: w * h)
    }

    mutating func dot(_ x: Int, _ y: Int, _ g: UInt8, _ c: UInt8 = 0) {
        guard x >= 0, y >= 0, x < w, y < h else { return }
        let i = y * w + x
        if g < gray[i] { gray[i] = g; chroma[i] = c }
    }

    mutating func stamp(_ x: Double, _ y: Double, _ t: Double, _ g: UInt8, _ c: UInt8 = 0) {
        let r = t / 2
        for dy in Int((y - r).rounded(.down))...Int((y + r).rounded(.up)) {
            for dx in Int((x - r).rounded(.down))...Int((x + r).rounded(.up)) where hypot(Double(dx) - x, Double(dy) - y) <= r + 0.01 {
                dot(dx, dy, g, c)
            }
        }
    }

    mutating func line(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, t: Double = 2, g: UInt8 = 0, c: UInt8 = 0) {
        let n = max(Int(hypot(x1 - x0, y1 - y0) * 2), 1)
        for k in 0...n {
            let s = Double(k) / Double(n)
            stamp(x0 + (x1 - x0) * s, y0 + (y1 - y0) * s, t, g, c)
        }
    }

    mutating func polyline(_ pts: [(Double, Double)], t: Double = 2, g: UInt8 = 0, c: UInt8 = 0) {
        for i in 1..<pts.count { line(pts[i - 1].0, pts[i - 1].1, pts[i].0, pts[i].1, t: t, g: g, c: c) }
    }

    /// 글자 대신: 작은 진한 덩어리 + 글자 상자
    mutating func text(_ s: String, cx: Double, cy: Double) {
        let bw = Double(max(8, 7 * s.count)), bh = 12.0
        let box = VRect(x: cx - bw / 2, y: cy - bh / 2, w: bw, h: bh)
        for y in Int(box.minY + 2)..<Int(box.maxY - 2) {
            for x in Int(box.minX + 1)..<Int(box.maxX - 1) where (x + y) % 3 != 0 { dot(x, y, 30) }
        }
        labels.append(TextLabel(text: s, box: box))
    }

    mutating func noise(_ count: Int, seed: UInt64) {
        var rng = seed
        for _ in 0..<count {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let x = Int((rng >> 33) % UInt64(w))
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let y = Int((rng >> 33) % UInt64(h))
            dot(x, y, 60)
        }
    }

    var image: PixelImage {
        var p = PixelImage(width: w, height: h, gray: gray)
        p.chroma = chroma
        return p
    }
}

// MARK: - 그래프 그리기

struct GraphSpec {
    var xMin = -5.0, xMax = 5.0, yMin = -5.0, yMax = 5.0
    var unitX = 40.0, unitY = 40.0
    var labelStep = 1.0
    var labelX = true, labelY = true
    var ticks = true
    var grid = false
    var thickness = 2.5
    var colored = false
    var noise = 0
    var axisThickness = 2.0
}

func drawGraph(_ spec: GraphSpec, curve: (Double) -> Double?) -> Canvas {
    let margin = 30.0
    let w = Int((spec.xMax - spec.xMin) * spec.unitX + 2 * margin)
    let h = Int((spec.yMax - spec.yMin) * spec.unitY + 2 * margin)
    var c = Canvas(w, h)
    func px(_ x: Double) -> Double { margin + (x - spec.xMin) * spec.unitX }
    func py(_ y: Double) -> Double { margin + (spec.yMax - y) * spec.unitY }
    let ax = min(max(0, spec.xMin), spec.xMax), ay = min(max(0, spec.yMin), spec.yMax)
    if spec.grid {
        var x = ceil(spec.xMin); while x <= spec.xMax { c.line(px(x), py(spec.yMin), px(x), py(spec.yMax), t: 1, g: 205); x += 1 }
        var y = ceil(spec.yMin); while y <= spec.yMax { c.line(px(spec.xMin), py(y), px(spec.xMax), py(y), t: 1, g: 205); y += 1 }
    }
    // 축 + 화살표
    c.line(px(spec.xMin) - 10, py(ay), px(spec.xMax) + 15, py(ay), t: spec.axisThickness)
    c.line(px(spec.xMax) + 15, py(ay), px(spec.xMax) + 7, py(ay) - 5, t: 2)
    c.line(px(spec.xMax) + 15, py(ay), px(spec.xMax) + 7, py(ay) + 5, t: 2)
    c.line(px(ax), py(spec.yMin) + 10, px(ax), py(spec.yMax) - 15, t: spec.axisThickness)
    c.line(px(ax), py(spec.yMax) - 15, px(ax) - 5, py(spec.yMax) - 7, t: 2)
    c.line(px(ax), py(spec.yMax) - 15, px(ax) + 5, py(spec.yMax) - 7, t: 2)
    // 눈금 · 숫자
    var x = ceil(spec.xMin)
    while x <= spec.xMax {
        if x != 0 {
            if spec.ticks { c.line(px(x), py(ay) - 4, px(x), py(ay) + 4, t: 1.5) }
            if spec.labelX, (x / spec.labelStep).rounded() == x / spec.labelStep { c.text(fmt(x), cx: px(x), cy: py(ay) + 16) }
        }
        x += 1
    }
    var y = ceil(spec.yMin)
    while y <= spec.yMax {
        if y != 0 {
            if spec.ticks { c.line(px(ax) - 4, py(y), px(ax) + 4, py(y), t: 1.5) }
            if spec.labelY, (y / spec.labelStep).rounded() == y / spec.labelStep { c.text(fmt(y), cx: px(ax) - 16 - Double(fmt(y).count) * 2, cy: py(y)) }
        }
        y += 1
    }
    c.text("O", cx: px(ax) - 10, cy: py(ay) + 12)
    c.text("x", cx: px(spec.xMax) + 12, cy: py(ay) + 14)
    c.text("y", cx: px(ax) + 14, cy: py(spec.yMax) - 14)
    // 곡선
    var pts: [(Double, Double)] = []
    var t = spec.xMin
    while t <= spec.xMax {
        if let v = curve(t), v >= spec.yMin - 0.5, v <= spec.yMax + 0.5 {
            pts.append((px(t), py(v)))
        } else if pts.count > 1 {
            c.polyline(pts, t: spec.thickness, g: spec.colored ? 110 : 0, c: spec.colored ? 160 : 0); pts = []
        } else { pts = [] }
        t += 0.01
    }
    if pts.count > 1 { c.polyline(pts, t: spec.thickness, g: spec.colored ? 110 : 0, c: spec.colored ? 160 : 0) }
    if spec.noise > 0 { c.noise(spec.noise, seed: 42) }
    return c
}

func drawCircleGraph(_ spec: GraphSpec, cx: Double, cy: Double, r: Double) -> Canvas {
    var c = drawGraph(spec) { _ in nil }
    let margin = 30.0
    func px(_ x: Double) -> Double { margin + (x - spec.xMin) * spec.unitX }
    func py(_ y: Double) -> Double { margin + (spec.yMax - y) * spec.unitY }
    var pts: [(Double, Double)] = []
    for k in 0...720 {
        let a = Double(k) / 720 * 2 * .pi
        pts.append((px(cx + r * cos(a)), py(cy + r * sin(a))))
    }
    c.polyline(pts, t: spec.thickness)
    return c
}

func fmt(_ v: Double) -> String {
    v == v.rounded() ? String(Int(v)).replacingOccurrences(of: "-", with: "−") : String(v)
}

// MARK: - 도형 그리기

func shapeCanvas(_ pts: [(Double, Double)], labels: [(String, Double, Double)] = [], thickness: Double = 2.5, noise: Int = 0) -> Canvas {
    var c = Canvas(500, 420)
    c.polyline(pts + [pts[0]], t: thickness)
    for l in labels { c.text(l.0, cx: l.1, cy: l.2) }
    if noise > 0 { c.noise(noise, seed: 7) }
    return c
}

func regularPolygon(_ n: Int, cx: Double = 250, cy: Double = 210, r: Double = 140) -> [(Double, Double)] {
    (0..<n).map { k in
        let a = -Double.pi / 2 + Double(k) * 2 * .pi / Double(n)
        return (cx + r * cos(a), cy + r * sin(a))
    }
}

// MARK: - 실행

var passed = 0, failed = 0
func check(_ name: String, _ ok: Bool, _ detail: String) {
    if ok { passed += 1; print("✅ \(name)") } else { failed += 1; print("❌ \(name)\n   \(detail)") }
}

func close(_ a: [Double], _ b: [Double], tol: Double) -> Bool {
    let n = max(a.count, b.count)
    return (0..<n).allSatisfy { abs((($0 < a.count) ? a[$0] : 0) - (($0 < b.count) ? b[$0] : 0)) <= tol }
}

func graphCase(_ name: String, _ spec: GraphSpec, kind: GraphAnalysis.Kind, coefficients: [Double], tol: Double = 0.15, _ f: @escaping (Double) -> Double?) {
    let canvas = drawGraph(spec, curve: f)
    let start = Date()
    guard let result = GraphReader.analyze(canvas.image, labels: canvas.labels) else {
        check(name, false, "축을 찾지 못함"); return
    }
    let ms = Int(Date().timeIntervalSince(start) * 1000)
    let ok = result.kind == kind && close(result.coefficients, coefficients, tol: tol)
    check("\(name) [\(ms)ms]", ok, "kind=\(result.kind) coef=\(result.coefficients.map { VisionMath.format($0) }) eq=\(result.equation ?? "-")\n   \(result.explanation.replacingOccurrences(of: "\n", with: " / "))")
}

// 1~20 그래프
graphCase("y = x²", GraphSpec(yMin: -2, yMax: 10), kind: .quadratic, coefficients: [0, 0, 1]) { $0 * $0 }
graphCase("y = 2x + 1", GraphSpec(), kind: .linear, coefficients: [1, 2]) { 2 * $0 + 1 }
graphCase("y = −x² + 4x", GraphSpec(xMin: -2, xMax: 6, yMin: -4, yMax: 6), kind: .quadratic, coefficients: [0, 4, -1]) { -$0 * $0 + 4 * $0 }
graphCase("y = x³ − 3x", GraphSpec(xMin: -3, xMax: 3, yMin: -5, yMax: 5), kind: .cubic, coefficients: [0, -3, 0, 1]) { $0 * $0 * $0 - 3 * $0 }
graphCase("y = x² − 2x − 3", GraphSpec(xMin: -3, xMax: 5, yMin: -5, yMax: 6), kind: .quadratic, coefficients: [-3, -2, 1]) { $0 * $0 - 2 * $0 - 3 }
graphCase("y = −0.5x + 2", GraphSpec(), kind: .linear, coefficients: [2, -0.5]) { -0.5 * $0 + 2 }
graphCase("y = 0.5x²", GraphSpec(yMin: -2, yMax: 9), kind: .quadratic, coefficients: [0, 0, 0.5]) { 0.5 * $0 * $0 }
graphCase("격자 있는 y = x² − 4", { var s = GraphSpec(yMin: -5, yMax: 6); s.grid = true; return s }(), kind: .quadratic, coefficients: [-4, 0, 1]) { $0 * $0 - 4 }
graphCase("파란 선 y = 2x + 1", { var s = GraphSpec(); s.colored = true; return s }(), kind: .linear, coefficients: [1, 2]) { 2 * $0 + 1 }
graphCase("굵은 선 y = −x² + 3", { var s = GraphSpec(yMin: -6, yMax: 5); s.thickness = 5; return s }(), kind: .quadratic, coefficients: [3, 0, -1]) { -$0 * $0 + 3 }
graphCase("잡티 많은 y = x − 1", { var s = GraphSpec(); s.noise = 400; return s }(), kind: .linear, coefficients: [-1, 1]) { $0 - 1 }
graphCase("1사분면 y = x", GraphSpec(xMin: 0, xMax: 8, yMin: 0, yMax: 8), kind: .linear, coefficients: [0, 1]) { $0 }
graphCase("x축 숫자만 y = x² − 1", { var s = GraphSpec(yMin: -3, yMax: 8); s.labelY = false; return s }(), kind: .quadratic, coefficients: [-1, 0, 1]) { $0 * $0 - 1 }
graphCase("숫자 없이 눈금만 y = 2x − 2", { var s = GraphSpec(); s.labelX = false; s.labelY = false; return s }(), kind: .linear, coefficients: [-2, 2]) { 2 * $0 - 2 }
graphCase("y = −2x² + 8x − 6", GraphSpec(xMin: -1, xMax: 5, yMin: -7, yMax: 4), kind: .quadratic, coefficients: [-6, 8, -2]) { -2 * $0 * $0 + 8 * $0 - 6 }
graphCase("y = x³", GraphSpec(xMin: -2.5, xMax: 2.5, yMin: -8, yMax: 8, unitY: 25), kind: .cubic, coefficients: [0, 0, 0, 1]) { $0 * $0 * $0 }
graphCase("가로세로 눈금 다른 y = x²", GraphSpec(xMin: -4, xMax: 4, yMin: -2, yMax: 16, unitX: 50, unitY: 20, labelStep: 2), kind: .quadratic, coefficients: [0, 0, 1]) { $0 * $0 }
graphCase("2칸마다 숫자 y = 3x − 2", GraphSpec(xMin: -4, xMax: 4, yMin: -10, yMax: 10, unitX: 40, unitY: 20, labelStep: 2), kind: .linear, coefficients: [-2, 3]) { 3 * $0 - 2 }
graphCase("두꺼운 축 y = x² + 2x", { var s = GraphSpec(yMin: -2, yMax: 8); s.axisThickness = 4; return s }(), kind: .quadratic, coefficients: [0, 2, 1]) { $0 * $0 + 2 * $0 }
graphCase("y = −x + 3 격자+잡티", { var s = GraphSpec(); s.grid = true; s.noise = 200; return s }(), kind: .linear, coefficients: [3, -1]) { -$0 + 3 }

// 원
do {
    for (name, cx, cy, r) in [("원 x² + y² = 9", 0.0, 0.0, 3.0), ("원 (x − 1)² + (y + 1)² = 4", 1.0, -1.0, 2.0)] {
        let canvas = drawCircleGraph(GraphSpec(), cx: cx, cy: cy, r: r)
        let result = GraphReader.analyze(canvas.image, labels: canvas.labels)
        let ok = result?.kind == .circle && close(result?.coefficients ?? [], [cx, cy, r], tol: 0.15)
        check(name, ok, "kind=\(String(describing: result?.kind)) coef=\(result?.coefficients ?? []) \(result?.explanation ?? "")")
    }
}

// 축 없는 그림은 그래프가 아님
do {
    let canvas = shapeCanvas(regularPolygon(3))
    check("삼각형 그림은 그래프 아님", GraphReader.analyze(canvas.image, labels: []) == nil, "그래프로 잘못 봄")
    let blank = Canvas(300, 200)
    check("빈 그림", GraphReader.analyze(blank.image, labels: []) == nil && ShapeReader.analyze(blank.image, labels: []).isEmpty, "빈 그림에서 무언가 찾음")
}

// MARK: 도형

func shapeCase(_ name: String, _ canvas: Canvas, kind: ShapeAnalysis.Kind, contains: [String] = []) {
    let start = Date()
    let shapes = ShapeReader.analyze(canvas.image, labels: canvas.labels)
    let ms = Int(Date().timeIntervalSince(start) * 1000)
    guard let first = shapes.first else { check(name, false, "도형을 못 찾음"); return }
    let text = first.description + " " + first.computed.joined(separator: " ")
    let ok = first.kind == kind && contains.allSatisfy { text.contains($0) }
    check("\(name) [\(ms)ms]", ok, "kind=\(first.kind) name=\(first.name) angles=\(first.angles.map { Int($0) }) labels=\(first.sideLabels)\n   \(text)")
}

shapeCase("직각삼각형 3·4 → 빗변 5", shapeCanvas([(100, 330), (100, 90), (420, 330)], labels: [("3", 80, 210), ("4", 260, 352)]),
          kind: .rightTriangle, contains: ["빗변", "= 5", "÷ 2 = 6"])
shapeCase("정삼각형", shapeCanvas(regularPolygon(3)), kind: .triangle, contains: ["정삼각형"])
shapeCase("직사각형 5·3", shapeCanvas([(80, 100), (420, 100), (420, 300), (80, 300)], labels: [("5", 250, 85), ("3", 440, 200)]),
          kind: .rectangle, contains: ["넓이 = 5 × 3 = 15", "둘레"])
shapeCase("정사각형 4", shapeCanvas([(130, 70), (370, 70), (370, 310), (130, 310)], labels: [("4cm", 250, 55)]),
          kind: .square, contains: ["넓이 = 4² = 16"])
do {
    var c = Canvas(500, 420)
    var pts: [(Double, Double)] = []
    for k in 0...720 { let a = Double(k) / 720 * 2 * .pi; pts.append((250 + 150 * cos(a), 210 + 150 * sin(a))) }
    c.polyline(pts, t: 2.5)
    c.line(250, 210, 400, 210, t: 1.5)
    c.text("r=3", cx: 320, cy: 195)
    shapeCase("원 반지름 3", c, kind: .circle, contains: ["9π"])
}
shapeCase("정오각형", shapeCanvas(regularPolygon(5)), kind: .pentagon, contains: ["정오각형", "540°"])
shapeCase("정육각형", shapeCanvas(regularPolygon(6)), kind: .hexagon, contains: ["정육각형", "720°"])
shapeCase("둔각삼각형", shapeCanvas([(60, 300), (440, 300), (130, 200)]), kind: .triangle, contains: ["둔각삼각형"])
shapeCase("평행사변형", shapeCanvas([(80, 300), (330, 300), (430, 120), (180, 120)]), kind: .parallelogram, contains: ["평행사변형"])
shapeCase("이등변삼각형", shapeCanvas([(250, 60), (140, 340), (360, 340)]), kind: .triangle, contains: ["이등변삼각형"])
shapeCase("사다리꼴", shapeCanvas([(60, 320), (440, 320), (340, 120), (160, 120)]), kind: .quadrilateral, contains: ["사다리꼴"])
shapeCase("굵은 선+잡티 직사각형", shapeCanvas([(80, 100), (420, 100), (420, 300), (80, 300)], thickness: 5, noise: 300), kind: .rectangle)
shapeCase("꼭짓점 이름 ABC 직각삼각형", shapeCanvas([(100, 330), (100, 90), (420, 330)], labels: [("A", 85, 345), ("B", 85, 75), ("C", 435, 345), ("6", 80, 210), ("8", 260, 352)]),
          kind: .rightTriangle, contains: ["빗변", "= 10", "÷ 2 = 24", "ABC"])
shapeCase("타원", { () -> Canvas in
    var c = Canvas(500, 420)
    var pts: [(Double, Double)] = []
    for k in 0...720 { let a = Double(k) / 720 * 2 * .pi; pts.append((250 + 190 * cos(a), 210 + 110 * sin(a))) }
    c.polyline(pts, t: 2.5)
    return c
}(), kind: .ellipse)
shapeCase("직각삼각형 빗변 13·밑변 5", shapeCanvas([(100, 330), (100, 90), (420, 330)], labels: [("5", 80, 210), ("13", 275, 195)]),
          kind: .rightTriangle, contains: ["나머지 한 변", "= 12"])

// MARK: 그래프·도형이 아닌 그림
do {
    // 글자만 있는 문서
    var doc = Canvas(600, 400)
    for row in 0..<12 { for col in 0..<8 { doc.text("가나", cx: 40 + Double(col) * 70, cy: 30 + Double(row) * 28) } }
    check("문서는 그래프 아님", GraphReader.analyze(doc.image, labels: doc.labels) == nil, "문서를 그래프로 봄")
    check("문서는 도형 없음", ShapeReader.analyze(doc.image, labels: doc.labels).isEmpty, "문서에서 도형을 찾음")
    // 아주 지저분한 사진 같은 그림 (오류 없이 끝나야 함)
    var photo = Canvas(400, 300)
    photo.noise(20000, seed: 99)
    let g = GraphReader.analyze(photo.image, labels: [])
    let sh = ShapeReader.analyze(photo.image, labels: [])
    check("잡음 사진에서 그래프 없음", g == nil || g!.kind == .unknown, "잡음을 그래프로 봄: \(String(describing: g?.kind))")
    check("잡음 사진에서 도형 거의 없음", sh.count <= 1, "도형 \(sh.count)개")
    // 축이 있고 두 점만 찍힌 그래프 (선 없음)
    var empty = drawGraph(GraphSpec()) { _ in nil }
    empty.stamp(250, 150, 8, 0)
    let r = GraphReader.analyze(empty.image, labels: empty.labels)
    check("선 없는 좌표평면", r != nil && r!.kind == .unknown, "kind=\(String(describing: r?.kind))")
}

print("\n결과: \(passed)개 통과, \(failed)개 실패")
exit(failed == 0 ? 0 : 1)
