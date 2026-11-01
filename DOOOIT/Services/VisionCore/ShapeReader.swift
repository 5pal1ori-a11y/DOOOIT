import Foundation

/// 도형 판독 (외부 AI 없이 직접 계산)
/// 닫힌 선으로 둘러싸인 영역을 찾아 꼭짓점 수·각도·둥근 정도로 삼각형·사각형·원 등을 구분
struct ShapeAnalysis {
    enum Kind: String {
        case triangle, rightTriangle, square, rectangle, parallelogram, quadrilateral, pentagon, hexagon, polygon, circle, ellipse
    }

    var kind: Kind
    /// "직각삼각형"
    var name: String
    /// 꼭짓점 (픽셀, 시계 방향)
    var vertices: [VPoint]
    /// 각 꼭짓점의 각도 (도)
    var angles: [Double]
    /// 변 길이 (픽셀)
    var sides: [Double]
    /// 변(또는 원)에 붙은 길이 숫자: 변 번호 → 값
    var sideLabels: [Int: Double]
    /// 꼭짓점 이름 (A, B, C …)
    var vertexNames: [Int: String]
    /// 둘러싼 영역 (픽셀)
    var bounds: VRect
    var description: String
    /// 길이가 적혀 있으면 계산한 넓이·둘레 등
    var computed: [String]
}

enum ShapeReader {
    static func analyze(_ image: PixelImage, labels: [TextLabel]) -> [ShapeAnalysis] {
        let w = image.width, h = image.height
        // 글자 자리는 잉크에서 빼기
        let boxes = labels.map { $0.box.insetBy(-2) }
        var ink = [Bool](repeating: false, count: w * h)
        for y in 0..<h {
            for x in 0..<w where image.isDark(x, y, threshold: 150) || (image.chroma[y * w + x] > 70 && image.gray[y * w + x] < 225) {
                if boxes.contains(where: { $0.contains(Double(x), Double(y)) }) { continue }
                ink[y * w + x] = true
            }
        }
        // 바깥에서 닿는 빈 곳 = 바탕, 닿지 않는 빈 곳 = 도형 안쪽
        var outside = [Bool](repeating: false, count: w * h)
        var stack: [Int] = []
        func push(_ x: Int, _ y: Int) {
            let i = y * w + x
            if !ink[i] && !outside[i] { outside[i] = true; stack.append(i) }
        }
        for x in 0..<w { push(x, 0); push(x, h - 1) }
        for y in 0..<h { push(0, y); push(w - 1, y) }
        while let i = stack.popLast() {
            let x = i % w, y = i / w
            if x > 0 { push(x - 1, y) }
            if x < w - 1 { push(x + 1, y) }
            if y > 0 { push(x, y - 1) }
            if y < h - 1 { push(x, y + 1) }
        }
        var interior = [Bool](repeating: false, count: w * h)
        for i in 0..<(w * h) where !ink[i] && !outside[i] { interior[i] = true }
        let minArea = max(150, w * h / 600)
        let regions = VisionMath.components(interior, width: w, height: h, minSize: minArea)

        var shapes: [ShapeAnalysis] = []
        for region in regions {
            // 다른 도형 안의 작은 구멍(글자 속 등)은 크기로 거름
            guard let shape = classify(region, width: w, labels: labels) else { continue }
            shapes.append(shape)
        }
        // 큰 도형부터
        return shapes.sorted { $0.bounds.w * $0.bounds.h > $1.bounds.w * $1.bounds.h }
    }

    // MARK: - 분류

    private static func classify(_ region: [Int], width w: Int, labels: [TextLabel]) -> ShapeAnalysis? {
        let pts = region.map { VPoint(x: Double($0 % w), y: Double($0 / w)) }
        let xs = pts.map(\.x), ys = pts.map(\.y)
        let bounds = VRect(x: xs.min()!, y: ys.min()!, w: xs.max()! - xs.min()! + 1, h: ys.max()! - ys.min()! + 1)
        guard bounds.w >= 12, bounds.h >= 12 else { return nil }
        let area = Double(region.count)
        let hull = convexHull(pts)
        guard hull.count >= 3 else { return nil }
        let hullArea = polygonArea(hull)
        // 오목하거나 글자 사이 빈 곳이면 건너뜀
        guard hullArea > 0, area / hullArea > 0.82 else { return nil }
        let perimeter = polygonPerimeter(hull)
        let circularity = 4 * Double.pi * hullArea / (perimeter * perimeter)
        let polygon = simplify(hull, perimeter: perimeter)
        let n = polygon.count

        // 원·타원: 꼭짓점을 이어도 둘레를 잘 못 따라가고(곧은 변이 아님) 둥근 정도가 높음
        let polygonFits = n <= 8 && polygonArea(polygon) / hullArea > 0.965
        if !polygonFits && (n > 6 || circularity > 0.8) {
            let ellipseArea = Double.pi * bounds.w * bounds.h / 4
            if abs(area - ellipseArea) / ellipseArea < 0.12 {
                let isCircle = abs(bounds.w - bounds.h) / max(bounds.w, bounds.h) < 0.08
                var shape = ShapeAnalysis(kind: isCircle ? .circle : .ellipse, name: isCircle ? "원" : "타원", vertices: [], angles: [],
                                          sides: [], sideLabels: [:], vertexNames: [:], bounds: bounds, description: "", computed: [])
                attachCircleLabel(&shape, labels: labels)
                describe(&shape)
                return shape
            }
        }
        guard (3...8).contains(n) else { return nil }
        let angles = (0..<n).map { interiorAngle(polygon[(($0 - 1) + n) % n], polygon[$0], polygon[($0 + 1) % n]) }
        let sides = (0..<n).map { distance(polygon[$0], polygon[($0 + 1) % n]) }
        var kind: ShapeAnalysis.Kind
        var name: String
        switch n {
        case 3:
            if angles.contains(where: { abs($0 - 90) < 7 }) { kind = .rightTriangle; name = "직각삼각형" }
            else { kind = .triangle; name = triangleName(sides: sides, angles: angles) }
        case 4:
            let rightAngles = angles.filter { abs($0 - 90) < 8 }.count
            let parallel = abs(sides[0] - sides[2]) / max(sides[0], sides[2]) < 0.1 && abs(sides[1] - sides[3]) / max(sides[1], sides[3]) < 0.1
            if rightAngles == 4 {
                let square = abs(sides[0] - sides[1]) / max(sides[0], sides[1]) < 0.08
                kind = square ? .square : .rectangle
                name = square ? "정사각형" : "직사각형"
            } else if parallel {
                let rhombus = abs(sides[0] - sides[1]) / max(sides[0], sides[1]) < 0.08
                kind = .parallelogram
                name = rhombus ? "마름모" : "평행사변형"
            } else {
                kind = .quadrilateral
                name = isTrapezoid(polygon) ? "사다리꼴" : "사각형"
            }
        case 5: kind = .pentagon; name = isRegular(sides, angles) ? "정오각형" : "오각형"
        case 6: kind = .hexagon; name = isRegular(sides, angles) ? "정육각형" : "육각형"
        default: kind = .polygon; name = "\(n)각형"
        }
        var shape = ShapeAnalysis(kind: kind, name: name, vertices: polygon, angles: angles, sides: sides, sideLabels: [:],
                                  vertexNames: [:], bounds: bounds, description: "", computed: [])
        attachLabels(&shape, labels: labels)
        describe(&shape)
        return shape
    }

    private static func triangleName(sides: [Double], angles: [Double]) -> String {
        let sorted = sides.sorted()
        if (sorted[2] - sorted[0]) / sorted[2] < 0.06 { return "정삼각형" }
        if (sorted[1] - sorted[0]) / sorted[1] < 0.06 || (sorted[2] - sorted[1]) / sorted[2] < 0.06 { return "이등변삼각형" }
        if angles.contains(where: { $0 > 97 }) { return "둔각삼각형" }
        return "삼각형"
    }

    private static func isRegular(_ sides: [Double], _ angles: [Double]) -> Bool {
        let ms = sides.reduce(0, +) / Double(sides.count)
        let ma = angles.reduce(0, +) / Double(angles.count)
        return sides.allSatisfy { abs($0 - ms) / ms < 0.1 } && angles.allSatisfy { abs($0 - ma) < 8 }
    }

    private static func isTrapezoid(_ p: [VPoint]) -> Bool {
        func dir(_ a: VPoint, _ b: VPoint) -> Double { atan2(b.y - a.y, b.x - a.x) }
        func parallel(_ a: Double, _ b: Double) -> Bool {
            var d = abs(a - b).truncatingRemainder(dividingBy: .pi)
            if d > .pi / 2 { d = .pi - d }
            return d < 0.08
        }
        return parallel(dir(p[0], p[1]), dir(p[3], p[2])) || parallel(dir(p[1], p[2]), dir(p[0], p[3]))
    }

    // MARK: - 글자 붙이기

    /// 숫자는 가장 가까운 변에, 알파벳 한 글자는 가장 가까운 꼭짓점에
    private static func attachLabels(_ shape: inout ShapeAnalysis, labels: [TextLabel]) {
        let n = shape.vertices.count
        let size = max(shape.bounds.w, shape.bounds.h)
        for label in labels {
            let c = VPoint(x: label.box.midX, y: label.box.midY)
            let text = label.text.trimmingCharacters(in: .whitespaces)
            if text.count == 1, text.first!.isUppercase, text.first!.isLetter {
                if let (i, d) = shape.vertices.enumerated().map({ ($0.offset, distance($0.element, c)) }).min(by: { $0.1 < $1.1 }), d < size * 0.25 {
                    shape.vertexNames[i] = text
                }
                continue
            }
            guard let value = lengthValue(text) else { continue }
            var best: (Int, Double)?
            for i in 0..<n {
                let d = segmentDistance(c, shape.vertices[i], shape.vertices[(i + 1) % n])
                if d < (best?.1 ?? .infinity) { best = (i, d) }
            }
            if let (i, d) = best, d < max(size * 0.18, 30) { shape.sideLabels[i] = value }
        }
    }

    private static func attachCircleLabel(_ shape: inout ShapeAnalysis, labels: [TextLabel]) {
        for label in labels {
            let text = label.text.replacingOccurrences(of: " ", with: "")
            guard let value = lengthValue(text.replacingOccurrences(of: "r=", with: "")) else { continue }
            if shape.bounds.insetBy(-20).contains(label.box.midX, label.box.midY) {
                shape.sideLabels[0] = value
                break
            }
        }
    }

    /// "5", "5cm", "3.5 cm", "12m" → 숫자
    static func lengthValue(_ text: String) -> Double? {
        let cleaned = text.lowercased().replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "cm", with: "").replacingOccurrences(of: "mm", with: "")
            .replacingOccurrences(of: "km", with: "").replacingOccurrences(of: "m", with: "")
        guard let v = Double(cleaned), v > 0 else { return nil }
        return v
    }

    // MARK: - 설명 · 계산

    private static func describe(_ shape: inout ShapeAnalysis) {
        var lines: [String] = []
        let f = VisionMath.format
        let names = shape.vertexNames.isEmpty ? "" : " " + shape.vertexNames.values.sorted().joined()
        switch shape.kind {
        case .circle, .ellipse:
            lines.append("**\(shape.name)\(names)** 모양이에요.")
            if shape.kind == .circle, let r = shape.sideLabels[0] {
                // 숫자가 원 안에 있으면 반지름으로 봄
                shape.computed.append("반지름을 \(f(r))로 보면 넓이 \(f(r * r))π ≈ \(f(Double.pi * r * r)), 둘레 \(f(2 * r))π ≈ \(f(2 * Double.pi * r))")
            }
        case .rightTriangle:
            lines.append("**\(shape.name)\(names)** 모양이에요. 세 각은 약 \(shape.angles.map { "\(Int($0.rounded()))°" }.joined(separator: ", "))이에요.")
            if let right = shape.angles.firstIndex(where: { abs($0 - 90) < 7 }) {
                let n = 3
                // 직각을 낀 두 변: right−1→right, right→right+1
                let legA = (right - 1 + n) % n, legB = right, hyp = (right + 1) % n
                let a = shape.sideLabels[legA], b = shape.sideLabels[legB], c = shape.sideLabels[hyp]
                if let a, let b {
                    shape.computed.append("빗변 = √(\(f(a))² + \(f(b))²) = \(sqrtText(a * a + b * b))")
                    shape.computed.append("넓이 = \(f(a)) × \(f(b)) ÷ 2 = \(f(a * b / 2))")
                } else if let c, let leg = a ?? b, c > leg {
                    let other = c * c - leg * leg
                    shape.computed.append("나머지 한 변 = √(\(f(c))² − \(f(leg))²) = \(sqrtText(other))")
                    shape.computed.append("넓이 = \(f(leg)) × \(sqrtText(other)) ÷ 2")
                }
            }
        case .triangle:
            lines.append("**\(shape.name)\(names)** 모양이에요. 세 각은 약 \(shape.angles.map { "\(Int($0.rounded()))°" }.joined(separator: ", "))이에요.")
            let known = shape.sideLabels.values.sorted()
            if known.count == 3 {
                let s = known.reduce(0, +) / 2
                let a2 = s * (s - known[0]) * (s - known[1]) * (s - known[2])
                if a2 > 0 { shape.computed.append("헤론의 공식으로 넓이 = √(\(f(a2))) ≈ \(f(a2.squareRoot()))") }
                shape.computed.append("둘레 = \(f(known.reduce(0, +)))")
            }
        case .square, .rectangle:
            lines.append("**\(shape.name)\(names)** 모양이에요. 네 각이 모두 직각이에요.")
            let horizontal = [0, 2].compactMap { shape.sideLabels[$0] }.first
            let vertical = [1, 3].compactMap { shape.sideLabels[$0] }.first
            if shape.kind == .square, let a = horizontal ?? vertical {
                shape.computed.append("넓이 = \(f(a))² = \(f(a * a)), 둘레 = 4 × \(f(a)) = \(f(4 * a))")
                shape.computed.append("대각선 = \(f(a))√2 ≈ \(f(a * 2.squareRoot()))")
            } else if let a = horizontal, let b = vertical {
                shape.computed.append("넓이 = \(f(a)) × \(f(b)) = \(f(a * b)), 둘레 = 2 × (\(f(a)) + \(f(b))) = \(f(2 * (a + b)))")
                shape.computed.append("대각선 = √(\(f(a))² + \(f(b))²) = \(sqrtText(a * a + b * b))")
            }
        default:
            lines.append("**\(shape.name)\(names)** 모양이에요.")
            if shape.vertices.count >= 3 {
                let total = 180 * (shape.vertices.count - 2)
                lines.append("내각의 합은 \(total)°예요.")
            }
        }
        if !shape.sideLabels.isEmpty && shape.computed.isEmpty && shape.kind != .circle {
            lines.append("적힌 길이: \(shape.sideLabels.sorted { $0.key < $1.key }.map { f($0.value) }.joined(separator: ", "))")
        }
        shape.description = lines.joined(separator: "\n")
    }

    private static func sqrtText(_ v: Double) -> String {
        let r = v.squareRoot()
        if abs(r - r.rounded()) < 1e-9 { return VisionMath.format(r) }
        if abs(v - v.rounded()) < 1e-9 {
            var n = Int(v.rounded()), outside = 1, k = 2
            while k * k <= n { while n % (k * k) == 0 { n /= k * k; outside *= k }; k += 1 }
            return (outside == 1 ? "" : "\(outside)") + "√\(n) ≈ \(VisionMath.format((r * 100).rounded() / 100))"
        }
        return "≈ \(VisionMath.format((r * 100).rounded() / 100))"
    }

    // MARK: - 기하 도구

    static func convexHull(_ points: [VPoint]) -> [VPoint] {
        // 같은 줄의 양 끝 점만 써도 볼록 껍질은 같음 (빠르게)
        var extremes: [Int: (Double, Double)] = [:]
        for p in points {
            let key = Int(p.y)
            if let e = extremes[key] { extremes[key] = (min(e.0, p.x), max(e.1, p.x)) } else { extremes[key] = (p.x, p.x) }
        }
        var pts: [VPoint] = []
        for (y, e) in extremes {
            // 픽셀의 바깥 모서리까지
            pts.append(VPoint(x: e.0, y: Double(y))); pts.append(VPoint(x: e.1 + 1, y: Double(y)))
            pts.append(VPoint(x: e.0, y: Double(y) + 1)); pts.append(VPoint(x: e.1 + 1, y: Double(y) + 1))
        }
        pts.sort { $0.x < $1.x || ($0.x == $1.x && $0.y < $1.y) }
        guard pts.count >= 3 else { return pts }
        func cross(_ o: VPoint, _ a: VPoint, _ b: VPoint) -> Double { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
        var lower: [VPoint] = []
        for p in pts {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        var upper: [VPoint] = []
        for p in pts.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }

    /// 거의 일직선인 꼭짓점과 아주 짧은 변을 지워서 진짜 꼭짓점만 남김
    static func simplify(_ hull: [VPoint], perimeter: Double) -> [VPoint] {
        var p = hull
        var changed = true
        while changed && p.count > 3 {
            changed = false
            // 가장 평평한 꼭짓점부터 지움
            var flattest: (Int, Double)?
            for i in 0..<p.count {
                let angle = interiorAngle(p[(i - 1 + p.count) % p.count], p[i], p[(i + 1) % p.count])
                if angle > 160, angle > (flattest?.1 ?? 0) { flattest = (i, angle) }
            }
            if let (i, _) = flattest { p.remove(at: i); changed = true; continue }
            // 아주 짧은 변: 두 꼭짓점을 가운데 하나로
            if let i = (0..<p.count).min(by: { distance(p[$0], p[($0 + 1) % p.count]) < distance(p[$1], p[($1 + 1) % p.count]) }),
               distance(p[i], p[(i + 1) % p.count]) < perimeter * 0.04 {
                let j = (i + 1) % p.count
                let mid = VPoint(x: (p[i].x + p[j].x) / 2, y: (p[i].y + p[j].y) / 2)
                p[i] = mid
                p.remove(at: j)
                changed = true
            }
        }
        // 마지막으로 평평한 각 한 번 더 정리
        var i = 0
        while p.count > 3 && i < p.count {
            if interiorAngle(p[(i - 1 + p.count) % p.count], p[i], p[(i + 1) % p.count]) > 155 { p.remove(at: i) } else { i += 1 }
        }
        return p
    }

    static func interiorAngle(_ a: VPoint, _ b: VPoint, _ c: VPoint) -> Double {
        let v1 = VPoint(x: a.x - b.x, y: a.y - b.y), v2 = VPoint(x: c.x - b.x, y: c.y - b.y)
        let dot = v1.x * v2.x + v1.y * v2.y
        let n = hypot(v1.x, v1.y) * hypot(v2.x, v2.y)
        guard n > 1e-9 else { return 180 }
        return acos(max(-1, min(1, dot / n))) * 180 / .pi
    }

    static func distance(_ a: VPoint, _ b: VPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }

    static func segmentDistance(_ p: VPoint, _ a: VPoint, _ b: VPoint) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 1e-9 else { return distance(p, a) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return distance(p, VPoint(x: a.x + t * dx, y: a.y + t * dy))
    }

    static func polygonArea(_ p: [VPoint]) -> Double {
        guard p.count >= 3 else { return 0 }
        var s = 0.0
        for i in 0..<p.count { let j = (i + 1) % p.count; s += p[i].x * p[j].y - p[j].x * p[i].y }
        return abs(s) / 2
    }

    static func polygonPerimeter(_ p: [VPoint]) -> Double {
        (0..<p.count).reduce(0) { $0 + distance(p[$1], p[($1 + 1) % p.count]) }
    }
}
