import Foundation

/// 이미지 분석용 픽셀 버퍼 (UIKit 없이 계산할 수 있게 밝기·색 정도만 담음)
/// 좌표: 왼쪽 위가 (0, 0), 아래로 갈수록 y가 커짐
struct PixelImage {
    let width: Int
    let height: Int
    /// 밝기 0(검정)~255(흰색)
    var gray: [UInt8]
    /// 색 진하기 (RGB 최댓값 − 최솟값). 흑백 이미지는 0
    var chroma: [UInt8]

    init(width: Int, height: Int, gray: [UInt8]) {
        self.width = width
        self.height = height
        self.gray = gray
        self.chroma = Array(repeating: 0, count: gray.count)
    }

    /// RGBA 8비트 버퍼에서 만들기
    init(width: Int, height: Int, rgba: [UInt8]) {
        self.width = width
        self.height = height
        var g = [UInt8](repeating: 255, count: width * height)
        var c = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let r = Int(rgba[i * 4]), gg = Int(rgba[i * 4 + 1]), b = Int(rgba[i * 4 + 2])
            let a = Int(rgba[i * 4 + 3])
            // 투명한 곳은 흰 바탕으로
            let blend = { (v: Int) in (v * a + 255 * (255 - a)) / 255 }
            let rr = blend(r), gb = blend(gg), bb = blend(b)
            g[i] = UInt8((rr * 299 + gb * 587 + bb * 114) / 1000)
            c[i] = UInt8(max(rr, gb, bb) - min(rr, gb, bb))
        }
        self.gray = g
        self.chroma = c
    }

    @inline(__always) func index(_ x: Int, _ y: Int) -> Int { y * width + x }

    /// 검은(진한) 잉크
    @inline(__always) func isDark(_ x: Int, _ y: Int, threshold: UInt8 = 120) -> Bool {
        gray[y * width + x] < threshold
    }

    /// 그래프 선: 진한 회색·검정 또는 색이 있는 선 (파랑·빨강 등)
    @inline(__always) func isInk(_ x: Int, _ y: Int) -> Bool {
        let i = y * width + x
        return gray[i] < 140 || (chroma[i] > 70 && gray[i] < 225)
    }
}

/// 픽셀 좌표 사각형
struct VRect: Equatable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    var minX: Double { x }
    var minY: Double { y }
    var maxX: Double { x + w }
    var maxY: Double { y + h }
    var midX: Double { x + w / 2 }
    var midY: Double { y + h / 2 }

    func insetBy(_ d: Double) -> VRect { VRect(x: x + d, y: y + d, w: max(0, w - 2 * d), h: max(0, h - 2 * d)) }
    func contains(_ px: Double, _ py: Double) -> Bool { px >= minX && px <= maxX && py >= minY && py <= maxY }
}

/// 글자 인식 결과 한 조각 (픽셀 좌표)
struct TextLabel: Equatable {
    var text: String
    var box: VRect

    /// "−3", "-1.5", "2" → 숫자
    var number: Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        return Double(cleaned)
    }
}

/// 2차원 점 (수학 좌표나 픽셀 좌표 모두에 씀)
struct VPoint: Equatable {
    var x: Double
    var y: Double
}

// MARK: - 공통 도구

enum VisionMath {
    /// 다항식 최소제곱 (낮은 차수 → 높은 차수 계수)
    static func polyfit(_ points: [VPoint], degree: Int) -> [Double]? {
        let n = degree + 1
        guard points.count >= n + 1 else { return nil }
        // 수치 안정을 위해 x를 평균 0, 크기 1 근처로
        let mean = points.map(\.x).reduce(0, +) / Double(points.count)
        let spread = max(points.map { abs($0.x - mean) }.max() ?? 1, 1e-9)
        var ata = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        var atb = [Double](repeating: 0, count: n)
        for p in points {
            let t = (p.x - mean) / spread
            var powers = [Double](repeating: 1, count: 2 * n)
            for k in 1..<(2 * n) { powers[k] = powers[k - 1] * t }
            for i in 0..<n {
                for j in 0..<n { ata[i][j] += powers[i + j] }
                atb[i] += powers[i] * p.y
            }
        }
        guard let scaled = solve(ata, atb) else { return nil }
        // t = (x − mean)/spread 로 쓴 계수를 x의 계수로 되돌림
        var result = [Double](repeating: 0, count: n)
        for k in 0..<n {
            // c_k * ((x − m)/s)^k = c_k / s^k * Σ C(k, j) x^j (−m)^(k−j)
            let ck = scaled[k] / pow(spread, Double(k))
            for j in 0...k {
                result[j] += ck * binomial(k, j) * pow(-mean, Double(k - j))
            }
        }
        return result
    }

    static func binomial(_ n: Int, _ k: Int) -> Double {
        guard k >= 0, k <= n else { return 0 }
        var r = 1.0
        for i in 0..<k { r = r * Double(n - i) / Double(i + 1) }
        return r
    }

    static func evaluate(_ c: [Double], _ x: Double) -> Double {
        c.enumerated().reduce(0) { $0 + $1.element * pow(x, Double($1.offset)) }
    }

    static func rmse(_ c: [Double], _ points: [VPoint]) -> Double {
        guard !points.isEmpty else { return .infinity }
        let s = points.reduce(0) { $0 + pow(evaluate(c, $1.x) - $1.y, 2) }
        return (s / Double(points.count)).squareRoot()
    }

    /// 가우스 소거
    static func solve(_ a: [[Double]], _ b: [Double]) -> [Double]? {
        let n = b.count
        var m = a
        var v = b
        for col in 0..<n {
            guard let pivot = (col..<n).max(by: { abs(m[$0][col]) < abs(m[$1][col]) }), abs(m[pivot][col]) > 1e-12 else { return nil }
            m.swapAt(col, pivot)
            v.swapAt(col, pivot)
            for r in 0..<n where r != col {
                let f = m[r][col] / m[col][col]
                if f == 0 { continue }
                for k in col..<n { m[r][k] -= f * m[col][k] }
                v[r] -= f * v[col]
            }
        }
        return (0..<n).map { v[$0] / m[$0][$0] }
    }

    /// 직선 최소제곱 y = a·x + b
    static func lineFit(_ xs: [Double], _ ys: [Double]) -> (a: Double, b: Double, rmse: Double)? {
        guard xs.count >= 2 else { return nil }
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        var sxx = 0.0, sxy = 0.0
        for i in xs.indices { sxx += (xs[i] - mx) * (xs[i] - mx); sxy += (xs[i] - mx) * (ys[i] - my) }
        guard sxx > 1e-9 else { return nil }
        let a = sxy / sxx, b = my - a * mx
        let e = (zip(xs, ys).reduce(0) { $0 + pow(a * $1.0 + b - $1.1, 2) } / n).squareRoot()
        return (a, b, e)
    }

    /// 보기 좋은 수: 정수·0.5 단위에 가까우면 맞춰서
    static func nice(_ v: Double) -> Double {
        let r = v.rounded()
        if abs(v - r) < 0.12 { return r }
        let h = (v * 2).rounded() / 2
        if abs(v - h) < 0.08 { return h }
        return (v * 10).rounded() / 10
    }

    static func format(_ v: Double) -> String {
        let n = abs(v) < 1e-9 ? 0 : v
        if abs(n - n.rounded()) < 1e-9 { return String(Int(n.rounded())).replacingOccurrences(of: "-", with: "−") }
        var s = String(format: "%.2f", n)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s.replacingOccurrences(of: "-", with: "−")
    }

    /// 실근 (차수 1~3)
    static func realRoots(_ c: [Double]) -> [Double] {
        var c = c
        while c.count > 1 && abs(c.last!) < 1e-12 { c.removeLast() }
        switch c.count {
        case 2: return [-c[0] / c[1]]
        case 3:
            let (cc, b, a) = (c[0], c[1], c[2])
            let d = b * b - 4 * a * cc
            if d < -1e-9 { return [] }
            if abs(d) < 1e-9 { return [-b / (2 * a)] }
            let s = d.squareRoot()
            return [(-b - s) / (2 * a), (-b + s) / (2 * a)].sorted()
        case 4:
            // 부호가 바뀌는 곳을 찾아 이분법
            let bound = 1 + max(abs(c[0]), abs(c[1]), abs(c[2])) / max(abs(c[3]), 1e-12)
            var roots: [Double] = []
            let steps = 4000
            var px = -bound, py = evaluate(c, px)
            for k in 1...steps {
                let x = -bound + 2 * bound * Double(k) / Double(steps)
                let y = evaluate(c, x)
                if py == 0 { roots.append(px) }
                else if py * y < 0 {
                    var lo = px, hi = x
                    for _ in 0..<60 {
                        let mid = (lo + hi) / 2
                        if evaluate(c, lo) * evaluate(c, mid) <= 0 { hi = mid } else { lo = mid }
                    }
                    roots.append((lo + hi) / 2)
                }
                px = x; py = y
            }
            var unique: [Double] = []
            for r in roots where !unique.contains(where: { abs($0 - r) < 1e-6 }) { unique.append(r) }
            return unique
        default: return []
        }
    }

    /// 연결 요소 (8방향). mask[i] == true 인 픽셀끼리 묶음
    static func components(_ mask: [Bool], width: Int, height: Int, minSize: Int = 1) -> [[Int]] {
        var seen = [Bool](repeating: false, count: mask.count)
        var result: [[Int]] = []
        var stack: [Int] = []
        for start in mask.indices where mask[start] && !seen[start] {
            var comp: [Int] = []
            stack.append(start)
            seen[start] = true
            while let i = stack.popLast() {
                comp.append(i)
                let x = i % width, y = i / width
                for dy in -1...1 {
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                        let j = ny * width + nx
                        if mask[j] && !seen[j] { seen[j] = true; stack.append(j) }
                    }
                }
            }
            if comp.count >= minSize { result.append(comp) }
        }
        return result
    }
}
