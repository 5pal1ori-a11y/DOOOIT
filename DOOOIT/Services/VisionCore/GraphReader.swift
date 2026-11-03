import Foundation

/// 그래프 판독 (외부 AI 없이 직접 계산)
/// 좌표축과 눈금 숫자로 픽셀 ↔ 수학 좌표를 맞춘 뒤, 그려진 곡선을 일차·이차·삼차식이나 원으로 맞춤
struct GraphAnalysis {
    enum Kind: String {
        case linear, quadratic, cubic, circle, unknown

        var korean: String {
            switch self {
            case .linear: return "일차함수(직선)"
            case .quadratic: return "이차함수(포물선)"
            case .cubic: return "삼차함수"
            case .circle: return "원"
            case .unknown: return "알 수 없는 곡선"
            }
        }
    }

    struct KeyPoint: Equatable {
        var name: String
        var x: Double
        var y: Double
    }

    var kind: Kind
    /// "y = x² − 2x − 3" (눈금을 못 읽었으면 nil)
    var equation: String?
    /// 다항식: 낮은 차수 → 높은 차수 / 원: [중심 x, 중심 y, 반지름]
    var coefficients: [Double]
    var keyPoints: [KeyPoint]
    /// 눈금 숫자나 눈금 표시로 실제 좌표를 맞췄는지
    var calibrated: Bool
    /// 0~1
    var confidence: Double
    var explanation: String
    var pointCount: Int
}

/// 찾은 좌표축 (픽셀)
struct GraphAxes {
    /// 가로축 (x축)의 y 픽셀 위치와 두께, 가로 범위
    var xAxisY: Double
    var xAxisHalf: Double
    var xAxisRange: ClosedRange<Int>
    /// 세로축 (y축)의 x 픽셀 위치와 두께, 세로 범위
    var yAxisX: Double
    var yAxisHalf: Double
    var yAxisRange: ClosedRange<Int>

    var origin: VPoint { VPoint(x: yAxisX, y: xAxisY) }
}

enum GraphReader {
    // MARK: - 좌표축 찾기

    /// 가로·세로로 길게 이어진 진한 선 한 쌍 (서로 만나야 함)
    static func findAxes(_ image: PixelImage) -> GraphAxes? {
        let w = image.width, h = image.height
        guard w >= 40, h >= 40 else { return nil }
        let rows = (0..<h).map { y in longestRun(count: w, gap: 3) { image.isDark($0, y) } }
        let cols = (0..<w).map { x in longestRun(count: h, gap: 3) { image.isDark(x, $0) } }
        let hBands = bands(rows, minLength: Int(Double(w) * 0.4))
        let vBands = bands(cols, minLength: Int(Double(h) * 0.4))
        guard !hBands.isEmpty, !vBands.isEmpty else { return nil }

        var best: (GraphAxes, Double)?
        for hb in hBands {
            for vb in vBands {
                // 세로축이 가로축 범위 안을, 가로축이 세로축 범위 안을 지나야 함
                guard hb.range.contains(Int(vb.center)) || abs(Double(hb.range.lowerBound) - vb.center) < 6 || abs(Double(hb.range.upperBound) - vb.center) < 6,
                      vb.range.contains(Int(hb.center)) || abs(Double(vb.range.lowerBound) - hb.center) < 6 || abs(Double(vb.range.upperBound) - hb.center) < 6
                else { continue }
                // 십자(+)로 만나면 점수를 더 줌. 테두리 모서리(ㄴ)는 낮게
                let crossH = Double(hb.range.lowerBound) + 8 < vb.center && vb.center < Double(hb.range.upperBound) - 8
                let crossV = Double(vb.range.lowerBound) + 8 < hb.center && hb.center < Double(vb.range.upperBound) - 8
                var score = Double(hb.length + vb.length)
                if crossH { score *= 1.4 }
                if crossV { score *= 1.4 }
                let axes = GraphAxes(xAxisY: hb.center, xAxisHalf: hb.half, xAxisRange: hb.range,
                                     yAxisX: vb.center, yAxisHalf: vb.half, yAxisRange: vb.range)
                if score > (best?.1 ?? 0) { best = (axes, score) }
            }
        }
        return best?.0
    }

    private struct Band {
        var center: Double
        var half: Double
        var length: Int
        var range: ClosedRange<Int>
    }

    /// 줄마다의 가장 긴 연속 구간 (작은 끊김은 이어서 봄)
    private static func longestRun(count: Int, gap: Int, _ ink: (Int) -> Bool) -> (length: Int, start: Int, end: Int) {
        var best = (0, 0, 0)
        var start = -1, last = -1
        for i in 0..<count where ink(i) {
            if start < 0 || i - last > gap + 1 { start = i }
            last = i
            if last - start + 1 > best.0 { best = (last - start + 1, start, last) }
        }
        return best
    }

    /// 긴 선이 있는 줄들을 이웃끼리 묶음 (두꺼운 선)
    private static func bands(_ runs: [(length: Int, start: Int, end: Int)], minLength: Int) -> [Band] {
        var result: [Band] = []
        var group: [Int] = []
        func flush() {
            guard !group.isEmpty else { return }
            let center = Double(group.reduce(0, +)) / Double(group.count)
            let longest = group.map { runs[$0] }.max { $0.length < $1.length }!
            let lo = group.map { runs[$0].start }.min()!, hi = group.map { runs[$0].end }.max()!
            result.append(Band(center: center, half: Double(group.count) / 2 + 0.5, length: longest.length, range: lo...max(lo, hi)))
            _ = longest
            group = []
        }
        for (i, run) in runs.enumerated() {
            if run.length >= minLength {
                if let last = group.last, i - last > 1 { flush() }
                group.append(i)
            } else {
                flush()
            }
        }
        flush()
        // 너무 두꺼운 띠(칠해진 영역)는 축이 아님
        return result.filter { $0.half < 8 }
    }

    // MARK: - 눈금 맞추기

    struct Calibration {
        /// 수학 x = ax · 픽셀 x + bx
        var ax: Double, bx: Double
        /// 수학 y = ay · 픽셀 y + by (ay는 보통 음수)
        var ay: Double, by: Double
        var fromLabels: Bool
        var note: String

        func math(_ p: VPoint) -> VPoint { VPoint(x: ax * p.x + bx, y: ay * p.y + by) }
        func pixel(_ m: VPoint) -> VPoint { VPoint(x: (m.x - bx) / ax, y: (m.y - by) / ay) }
    }

    static func calibrate(_ image: PixelImage, axes: GraphAxes, labels: [TextLabel]) -> Calibration? {
        let ox = axes.yAxisX, oy = axes.xAxisY
        var xs: [(Double, Double)] = []   // (픽셀, 값)
        var ys: [(Double, Double)] = []
        for label in labels {
            guard let value = label.number else { continue }
            let nearXAxis = abs(label.box.midY - oy) < max(label.box.h * 2.2, 14) + axes.xAxisHalf
            let nearYAxis = abs(label.box.midX - ox) < max(label.box.w * 1.6, 14) + axes.yAxisHalf + label.box.w / 2
            if nearXAxis && !(nearYAxis && abs(label.box.midX - ox) < label.box.w) && value != 0 {
                xs.append((label.box.midX, value))
            } else if nearYAxis && value != 0 {
                ys.append((label.box.midY, value))
            }
        }
        // 숫자에 맞는 직선 (원점은 축이 만나는 곳: 값 0)
        func fit(_ items: [(Double, Double)], origin: Double) -> (a: Double, b: Double)? {
            guard !items.isEmpty else { return nil }
            // 원점을 지나는 비례식 value = a (p − origin) 를 먼저, 어긋난 값은 빼고 다시
            var pool = items
            for _ in 0..<2 {
                let num = pool.reduce(0) { $0 + ($1.0 - origin) * $1.1 }
                let den = pool.reduce(0) { $0 + ($1.0 - origin) * ($1.0 - origin) }
                guard den > 1e-9 else { return nil }
                let a = num / den
                let errors = pool.map { abs(a * ($0.0 - origin) - $0.1) }
                let typical = max(abs(a) * 6, 1e-9)
                let kept = zip(pool, errors).filter { $0.1 < max(typical, 0.25) }.map(\.0)
                if kept.count == pool.count || kept.isEmpty { return (a, -a * origin) }
                pool = kept
            }
            let num = pool.reduce(0) { $0 + ($1.0 - origin) * $1.1 }
            let den = pool.reduce(0) { $0 + ($1.0 - origin) * ($1.0 - origin) }
            guard den > 1e-9 else { return nil }
            return (num / den, -(num / den) * origin)
        }
        var fx = fit(xs, origin: ox)
        var fy = fit(ys, origin: oy)
        if let f = fx, f.a <= 0 { fx = nil }
        if let f = fy, f.a >= 0 { fy = nil }
        var note = ""
        var fromLabels = true
        // 한쪽만 숫자가 있으면 같은 비율로 가정
        if fx == nil, let f = fy { fx = (-f.a, f.a * ox); note = "x축 눈금은 y축과 같은 간격으로 가정했어요." }
        if fy == nil, let f = fx { fy = (-f.a, f.a * oy); note = "y축 눈금은 x축과 같은 간격으로 가정했어요." }
        // 숫자가 없으면 눈금 표시 간격을 1로
        if fx == nil {
            fromLabels = false
            let tx = tickSpacing(image, axes: axes, horizontal: true)
            let ty = tickSpacing(image, axes: axes, horizontal: false)
            guard let unit = tx ?? ty else { return nil }
            let ux = tx ?? unit, uy = ty ?? unit
            fx = (1 / ux, -ox / ux)
            fy = (-1 / uy, oy / uy)
            note = "눈금 숫자를 읽지 못해서 눈금 한 칸을 1로 보고 계산했어요."
        }
        guard let x = fx, let y = fy else { return nil }
        return Calibration(ax: x.a, bx: x.b, ay: y.a, by: y.b, fromLabels: fromLabels, note: note)
    }

    /// 축 위의 짧은 눈금 표시 간격 (픽셀)
    private static func tickSpacing(_ image: PixelImage, axes: GraphAxes, horizontal: Bool) -> Double? {
        var positions: [Int] = []
        if horizontal {
            let y0 = Int(axes.xAxisY.rounded()), reach = Int(axes.xAxisHalf.rounded(.up)) + 1
            for x in axes.xAxisRange {
                guard abs(Double(x) - axes.yAxisX) > axes.yAxisHalf + 3 else { continue }
                var up = 0, down = 0
                for d in reach...(reach + 8) {
                    if y0 - d >= 0, image.isDark(x, y0 - d) { up += 1 }
                    if y0 + d < image.height, image.isDark(x, y0 + d) { down += 1 }
                }
                if up + down >= 2 && up + down <= 12 { positions.append(x) }
            }
        } else {
            let x0 = Int(axes.yAxisX.rounded()), reach = Int(axes.yAxisHalf.rounded(.up)) + 1
            for y in axes.yAxisRange {
                guard abs(Double(y) - axes.xAxisY) > axes.xAxisHalf + 3 else { continue }
                var left = 0, right = 0
                for d in reach...(reach + 8) {
                    if x0 - d >= 0, image.isDark(x0 - d, y) { left += 1 }
                    if x0 + d < image.width, image.isDark(x0 + d, y) { right += 1 }
                }
                if left + right >= 2 && left + right <= 12 { positions.append(y) }
            }
        }
        // 이웃한 위치는 하나로
        var centers: [Double] = []
        var group: [Int] = []
        for p in positions {
            if let last = group.last, p - last > 1 {
                centers.append(Double(group.reduce(0, +)) / Double(group.count)); group = []
            }
            group.append(p)
        }
        if !group.isEmpty { centers.append(Double(group.reduce(0, +)) / Double(group.count)) }
        guard centers.count >= 3 else { return nil }
        let gaps = zip(centers.dropFirst(), centers).map { $0 - $1 }.filter { $0 > 4 }.sorted()
        guard !gaps.isEmpty else { return nil }
        let median = gaps[gaps.count / 2]
        // 간격이 고르면 눈금으로 인정
        let regular = gaps.filter { abs($0 - median) < median * 0.2 }.count
        return regular * 2 >= gaps.count ? median : nil
    }

    // MARK: - 곡선 점 모으기

    /// 축·눈금·글자·격자를 빼고 남은 선의 픽셀을 열마다 가운데 점으로
    static func curvePixels(_ image: PixelImage, axes: GraphAxes?, labels: [TextLabel]) -> (points: [VPoint], multiRunRatio: Double) {
        let w = image.width, h = image.height
        func px(_ v: Int) -> Double { Double(v) }
        var mask = [Bool](repeating: false, count: w * h)
        let boxes = labels.map { $0.box.insetBy(-3) }
        // 아주 긴 직선(격자·테두리)은 빼기
        var longRows = Set<Int>(), longCols = Set<Int>()
        for y in 0..<h where longestRun(count: w, gap: 2, { image.isInk($0, y) }).length > Int(Double(w) * 0.7) { longRows.insert(y) }
        for x in 0..<w where longestRun(count: h, gap: 2, { image.isInk(x, $0) }).length > Int(Double(h) * 0.7) { longCols.insert(x) }
        for y in 0..<h {
            if longRows.contains(y) { continue }
            for x in 0..<w where image.isInk(x, y) {
                if longCols.contains(x) { continue }
                if let axes {
                    if abs(Double(y) - axes.xAxisY) <= axes.xAxisHalf + 5 { continue }
                    if abs(Double(x) - axes.yAxisX) <= axes.yAxisHalf + 5 { continue }
                    // 좌표평면 밖(위쪽 문제 글, 옆의 선택지 등)은 그래프가 아님: 축이 그려진 범위 + 조금
                    let marginX = Double(axes.xAxisRange.count) * 0.08, marginY = Double(axes.yAxisRange.count) * 0.08
                    if px(x) < Double(axes.xAxisRange.lowerBound) - marginX || px(x) > Double(axes.xAxisRange.upperBound) + marginX { continue }
                    if px(y) < Double(axes.yAxisRange.lowerBound) - marginY || px(y) > Double(axes.yAxisRange.upperBound) + marginY { continue }
                }
                let px = Double(x), py = Double(y)
                if boxes.contains(where: { $0.contains(px, py) }) { continue }
                mask[y * w + x] = true
            }
        }
        // 작은 점(잡티)·짧은 조각 빼기
        let comps = VisionMath.components(mask, width: w, height: h, minSize: 1)
        let largest = comps.map(\.count).max() ?? 0
        var keep = [Bool](repeating: false, count: w * h)
        for comp in comps where comp.count >= max(25, largest / 12) {
            for i in comp { keep[i] = true }
        }
        var points: [VPoint] = []
        var columnsWithInk = 0, multi = 0
        for x in 0..<w {
            var runs: [(Int, Int)] = []
            var start = -1
            for y in 0..<h {
                if keep[y * w + x] {
                    if start < 0 { start = y }
                } else if start >= 0 {
                    runs.append((start, y - 1)); start = -1
                }
            }
            if start >= 0 { runs.append((start, h - 1)) }
            guard !runs.isEmpty else { continue }
            columnsWithInk += 1
            if runs.count >= 2 { multi += 1 }
            for r in runs {
                points.append(VPoint(x: Double(x), y: Double(r.0 + r.1) / 2))
            }
        }
        return (points, columnsWithInk == 0 ? 0 : Double(multi) / Double(columnsWithInk))
    }

    // MARK: - 분석

    static func analyze(_ image: PixelImage, labels: [TextLabel]) -> GraphAnalysis? {
        guard let axes = findAxes(image) else { return nil }
        let calibration = calibrate(image, axes: axes, labels: labels)
        let (pixels, multiRatio) = curvePixels(image, axes: axes, labels: labels)
        guard pixels.count >= 12 else {
            return GraphAnalysis(kind: .unknown, equation: nil, coefficients: [], keyPoints: [], calibrated: calibration != nil,
                                 confidence: 0.2, explanation: "좌표축은 찾았지만 그려진 그래프 선을 찾지 못했어요.", pointCount: pixels.count)
        }
        // 수학 좌표 (눈금이 없으면 원점 기준 픽셀 좌표, y는 위쪽이 +)
        let cal = calibration ?? Calibration(ax: 1, bx: -axes.yAxisX, ay: -1, by: axes.xAxisY, fromLabels: false, note: "")
        let points = pixels.map { cal.math($0) }
        let xs = points.map(\.x), ys = points.map(\.y)
        let yRange = max((ys.max() ?? 0) - (ys.min() ?? 0), 1e-9)
        let xRange = max((xs.max() ?? 0) - (xs.min() ?? 0), 1e-9)

        // 원 (한 열에 선이 두 번 지나는 곳이 많을 때)
        if multiRatio > 0.35, let circle = fitCircle(points) {
            let r = circle.r
            let residual = (points.reduce(0) { $0 + pow(hypot($1.x - circle.cx, $1.y - circle.cy) - r, 2) } / Double(points.count)).squareRoot()
            if residual < r * 0.06 {
                return circleAnalysis(circle, residual: residual, calibrated: calibration != nil, cal: calibration, count: points.count)
            }
        }

        // 다항식 1~3차
        var fits: [(degree: Int, c: [Double], e: Double)] = []
        for d in 1...3 {
            if let c = VisionMath.polyfit(points, degree: d) { fits.append((d, c, VisionMath.rmse(c, points) / yRange)) }
        }
        guard let bestError = fits.map(\.e).min() else { return nil }
        let chosen = fits.first { $0.e <= max(bestError * 1.6, 0.012) } ?? fits.last!
        let kind: GraphAnalysis.Kind = chosen.e > 0.08 ? .unknown : [1: .linear, 2: .quadratic, 3: .cubic][chosen.degree] ?? .unknown

        // 계수 다듬기: 정수·0.5 단위로 맞춰도 비슷하게 맞으면 그 값
        var coefficients = chosen.c
        if calibration != nil {
            let snapped = chosen.c.map(VisionMath.nice)
            let snappedError = VisionMath.rmse(snapped, points) / yRange
            if snappedError <= max(chosen.e * 1.5, 0.02) { coefficients = snapped }
        }
        // 3차 계수가 거의 0이면 2차로
        while coefficients.count > 2, abs(coefficients.last!) < 1e-9 { coefficients.removeLast() }

        var confidence = 0.92
        if calibration == nil { confidence -= 0.35 }
        else if !(calibration!.fromLabels) { confidence -= 0.15 }
        if !(calibration?.note.isEmpty ?? true) { confidence -= 0.05 }
        if points.count < 60 { confidence -= 0.1 }
        confidence -= min(0.3, chosen.e * 3)
        if kind == .unknown { confidence = min(confidence, 0.3) }
        confidence = max(0.05, min(0.98, confidence))

        let calibrated = calibration != nil
        var keyPoints: [GraphAnalysis.KeyPoint] = []
        var lines: [String] = []
        let equation = calibrated && kind != .unknown ? polynomialText(coefficients) : nil
        let viewMinX = xs.min() ?? 0, viewMaxX = xs.max() ?? 0

        switch kind {
        case .linear:
            let a = coefficients.count > 1 ? coefficients[1] : 0, b = coefficients[0]
            if calibrated {
                lines.append("**\(equation!)** 그래프(직선)로 보여요.")
                lines.append("기울기는 \(VisionMath.format(a)), y절편은 \(VisionMath.format(b))이에요.")
                keyPoints.append(.init(name: "y절편", x: 0, y: b))
                if abs(a) > 1e-9 {
                    let xi = -b / a
                    lines.append("x절편은 \(VisionMath.format(xi))이에요.")
                    keyPoints.append(.init(name: "x절편", x: xi, y: 0))
                }
            } else {
                lines.append("직선 그래프로 보여요. 눈금을 읽지 못해서 정확한 식은 알 수 없어요.")
            }
            lines.append(a > 0 ? "오른쪽으로 갈수록 올라가요 (증가)." : a < 0 ? "오른쪽으로 갈수록 내려가요 (감소)." : "x축에 평행한 직선이에요.")
        case .quadratic:
            let a = coefficients[2], b = coefficients[1], c = coefficients[0]
            let vx = -b / (2 * a), vy = VisionMath.evaluate(coefficients, vx)
            let shape = a > 0 ? "아래로 볼록" : "위로 볼록"
            if calibrated {
                lines.append("**\(equation!)** 그래프(포물선)로 보여요.")
                lines.append("\(shape)하고, 꼭짓점은 약 (\(VisionMath.format(VisionMath.nice(vx))), \(VisionMath.format(VisionMath.nice(vy))))이에요.")
                keyPoints.append(.init(name: "꼭짓점", x: vx, y: vy))
                let roots = VisionMath.realRoots(coefficients)
                if roots.isEmpty {
                    lines.append("x축과 만나지 않아요.")
                } else {
                    lines.append("x절편은 \(roots.map { VisionMath.format(VisionMath.nice($0)) }.joined(separator: "과 "))이에요.")
                    for r in roots { keyPoints.append(.init(name: "x절편", x: r, y: 0)) }
                }
                lines.append("y절편은 \(VisionMath.format(VisionMath.nice(c)))이고, \(a > 0 ? "최솟값" : "최댓값")은 \(VisionMath.format(VisionMath.nice(vy)))이에요.")
            } else {
                lines.append("\(shape)한 포물선(이차함수) 모양이에요. 눈금을 읽지 못해서 정확한 식은 알 수 없어요.")
            }
        case .cubic:
            if calibrated {
                lines.append("**\(equation!)** 그래프(삼차함수)로 보여요.")
                let derivative = [coefficients[1], 2 * coefficients[2], 3 * coefficients[3]]
                let critical = VisionMath.realRoots(derivative).filter { $0 >= viewMinX - xRange * 0.1 && $0 <= viewMaxX + xRange * 0.1 }
                for x in critical {
                    let y = VisionMath.evaluate(coefficients, x)
                    let second = 2 * coefficients[2] + 6 * coefficients[3] * x
                    let name = second < 0 ? "극대" : "극소"
                    keyPoints.append(.init(name: name, x: x, y: y))
                    lines.append("\(name)점은 약 (\(VisionMath.format(VisionMath.nice(x))), \(VisionMath.format(VisionMath.nice(y))))이에요.")
                }
                let roots = VisionMath.realRoots(coefficients)
                if !roots.isEmpty { lines.append("x절편은 \(roots.map { VisionMath.format(VisionMath.nice($0)) }.joined(separator: ", "))이에요.") }
            } else {
                lines.append("삼차함수 모양의 곡선이에요. 눈금을 읽지 못해서 정확한 식은 알 수 없어요.")
            }
        default:
            lines.append("곡선을 찾았지만 일차·이차·삼차식이나 원으로 딱 맞지는 않아요. 지수·로그·분수함수일 수도 있어요.")
        }
        if let note = calibration?.note, !note.isEmpty { lines.append("(\(note))") }
        if kind != .unknown { lines.append("믿을 만한 정도: \(Int((confidence * 100).rounded()))%") }

        return GraphAnalysis(kind: kind, equation: equation, coefficients: coefficients, keyPoints: keyPoints, calibrated: calibrated,
                             confidence: confidence, explanation: lines.joined(separator: "\n"), pointCount: points.count)
    }

    // MARK: - 원

    private static func fitCircle(_ p: [VPoint]) -> (cx: Double, cy: Double, r: Double)? {
        // x² + y² + Dx + Ey + F = 0 최소제곱
        var a = [[Double]](repeating: [0, 0, 0], count: 3)
        var b = [0.0, 0.0, 0.0]
        for q in p {
            let row = [q.x, q.y, 1.0]
            let rhs = -(q.x * q.x + q.y * q.y)
            for i in 0..<3 {
                for j in 0..<3 { a[i][j] += row[i] * row[j] }
                b[i] += row[i] * rhs
            }
        }
        guard let s = VisionMath.solve(a, b) else { return nil }
        let cx = -s[0] / 2, cy = -s[1] / 2
        let r2 = cx * cx + cy * cy - s[2]
        guard r2 > 0 else { return nil }
        return (cx, cy, r2.squareRoot())
    }

    private static func circleAnalysis(_ c: (cx: Double, cy: Double, r: Double), residual: Double, calibrated: Bool,
                                       cal: Calibration?, count: Int) -> GraphAnalysis {
        let cx = VisionMath.nice(c.cx), cy = VisionMath.nice(c.cy), r = VisionMath.nice(c.r)
        var lines: [String] = []
        var equation: String?
        if calibrated {
            func part(_ name: String, _ v: Double) -> String {
                if abs(v) < 1e-9 { return "\(name)²" }
                return "(\(name) \(v > 0 ? "−" : "+") \(VisionMath.format(abs(v))))²"
            }
            let r2 = r * r
            equation = "\(part("x", cx)) + \(part("y", cy)) = \(VisionMath.format(r2))"
            lines.append("**\(equation!)** (원)으로 보여요.")
            lines.append("중심은 (\(VisionMath.format(cx)), \(VisionMath.format(cy))), 반지름은 \(VisionMath.format(r))이에요.")
            if let cal, abs(abs(cal.ax) - abs(cal.ay)) > 0.12 * abs(cal.ax) { lines.append("가로·세로 눈금 간격이 달라서 타원처럼 보일 수 있어요.") }
        } else {
            lines.append("원 모양 그래프로 보여요. 눈금을 읽지 못해서 정확한 식은 알 수 없어요.")
        }
        let confidence = max(0.1, min(0.95, (calibrated ? 0.9 : 0.5) - residual / max(c.r, 1e-9)))
        lines.append("믿을 만한 정도: \(Int((confidence * 100).rounded()))%")
        return GraphAnalysis(kind: .circle, equation: equation, coefficients: [cx, cy, r],
                             keyPoints: [.init(name: "중심", x: cx, y: cy)], calibrated: calibrated,
                             confidence: confidence, explanation: lines.joined(separator: "\n"), pointCount: count)
    }

    // MARK: - 식 글자

    static func polynomialText(_ c: [Double]) -> String {
        var terms: [String] = []
        for power in stride(from: c.count - 1, through: 0, by: -1) {
            let v = c[power]
            guard abs(v) > 1e-9 else { continue }
            let magnitude = abs(v)
            let coefficient = (power > 0 && abs(magnitude - 1) < 1e-9) ? "" : VisionMath.format(magnitude)
            let variable = power == 0 ? "" : power == 1 ? "x" : power == 2 ? "x²" : "x³"
            let body = coefficient + variable
            if terms.isEmpty {
                terms.append((v < 0 ? "−" : "") + body)
            } else {
                terms.append((v < 0 ? "− " : "+ ") + body)
            }
        }
        return "y = " + (terms.isEmpty ? "0" : terms.joined(separator: " "))
    }
}
