import Foundation

/// 사진 속 큰 기호(∑, ∫)를 잉크 모양으로 알아보기 (픽셀 배열만 다루는 순수 계산 → 리눅스 테스트 가능)
/// 글자 인식은 ∑를 E·Z·2·s로, ∫를 J·f·S·[ 로 읽는 일이 많아서, 보통 글자보다 훨씬 큰 덩어리의 모양을 직접 봄.
/// 잉크 표시(FractionFinder.Ink)는 위가 0
enum CalculusShape {
    enum Kind: String { case sigma, integral }

    /// 이어진 잉크 덩어리 (픽셀, 위가 0, 끝 포함)
    struct Blob: Equatable {
        var x0: Int, x1: Int, y0: Int, y1: Int
        var area: Int
        var width: Int { x1 - x0 + 1 }
        var height: Int { y1 - y0 + 1 }
    }

    struct Found: Equatable {
        var kind: Kind
        var blob: Blob
        /// ∫ 의 세로 줄기 가운데 x (픽셀). ∑ 는 덩어리 가운데
        var centerX: Double
        /// 보통 글자 높이(픽셀) 대비 이 덩어리 높이
        var ratio: Double
    }

    /// 이어진 잉크 덩어리 전부 (8방향 연결). 점·획 조각(높이 minHeight 미만)은 뺌
    static func components(_ ink: FractionFinder.Ink, minHeight: Int = 6) -> [(blob: Blob, pixels: [Int])] {
        let w = ink.width, h = ink.height
        guard w > 0, h > 0, ink.mask.count >= w * h else { return [] }
        var seen = [Bool](repeating: false, count: w * h)
        var result: [(Blob, [Int])] = []
        var stack: [Int] = []
        for start in 0..<(w * h) where ink.mask[start] && !seen[start] {
            seen[start] = true
            stack.append(start)
            var pixels: [Int] = []
            var x0 = Int.max, x1 = -1, y0 = Int.max, y1 = -1
            while let p = stack.popLast() {
                pixels.append(p)
                let x = p % w, y = p / w
                x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
                for dy in -1...1 {
                    let ny = y + dy
                    if ny < 0 || ny >= h { continue }
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = x + dx
                        if nx < 0 || nx >= w { continue }
                        let q = ny * w + nx
                        if ink.mask[q] && !seen[q] { seen[q] = true; stack.append(q) }
                    }
                }
            }
            if y1 - y0 + 1 >= minHeight { result.append((Blob(x0: x0, x1: x1, y0: y0, y1: y1, area: pixels.count), pixels)) }
        }
        return result
    }

    /// 사진의 보통 글자 높이: 덩어리 높이들 중 가장 큰 5%를 뺀 나머지의 75번째 백분위
    /// (한글 글자·숫자·괄호가 대부분이고 ∑·∫ 는 훨씬 커서 위쪽 꼬리로 빠짐)
    static func referenceHeight(_ blobs: [Blob]) -> Int? {
        let heights = blobs.map(\.height).filter { $0 >= 8 }.sorted()
        guard heights.count >= 4 else { return nil }
        let kept = Array(heights.prefix(max(1, Int(Double(heights.count) * 0.95))))
        return kept[min(kept.count - 1, Int(Double(kept.count) * 0.75))]
    }

    /// 사진 속 ∑ · ∫ 모양 덩어리 (왼쪽부터). 보수적: 크기·가로세로 비율·모양이 모두 맞을 때만
    static func find(_ ink: FractionFinder.Ink) -> [Found] {
        let parts = components(ink)
        guard let ref = referenceHeight(parts.map(\.blob)) else { return [] }
        var found: [Found] = []
        for (blob, pixels) in parts {
            if let f = classify(ink, blob: blob, pixels: pixels, reference: ref) { found.append(f) }
        }
        return found.sorted { $0.blob.x0 < $1.blob.x0 }
    }

    /// 덩어리 하나가 ∑ 인지 ∫ 인지 (아니면 nil)
    static func classify(_ ink: FractionFinder.Ink, blob: Blob, pixels: [Int], reference ref: Int) -> Found? {
        let h = blob.height, w = blob.width
        guard h >= Int(Double(ref) * 1.25), w >= 3 else { return nil }
        let aspect = Double(w) / Double(h)
        // 덩어리 안 행마다 잉크 가로 범위·개수
        var minX = [Int](repeating: Int.max, count: h), maxX = [Int](repeating: -1, count: h), count = [Int](repeating: 0, count: h)
        var sumX = [Double](repeating: 0, count: h)
        for p in pixels {
            let x = p % ink.width - blob.x0, r = p / ink.width - blob.y0
            minX[r] = min(minX[r], x); maxX[r] = max(maxX[r], x); count[r] += 1; sumX[r] += Double(x)
        }
        func span(_ r: Int) -> Int { maxX[r] >= 0 ? maxX[r] - minX[r] + 1 : 0 }
        func band(_ from: Double, _ to: Double) -> Range<Int> {
            let a = max(0, min(h - 1, Int(Double(h) * from))), b = max(a + 1, min(h, Int((Double(h) * to).rounded(.up))))
            return a..<b
        }
        func centroidX(_ rows: Range<Int>) -> Double? {
            let n = rows.reduce(0) { $0 + count[$1] }
            guard n > 0 else { return nil }
            return rows.reduce(0.0) { $0 + sumX[$1] } / Double(n)
        }
        func inkCount(_ rows: Range<Int>) -> Int { rows.reduce(0) { $0 + count[$1] } }

        let ratio = Double(h) / Double(ref)
        // ∑: 위·아래 가로줄이 넓고 가운데가 좁은 모양 (너비 ≈ 높이의 0.55~1.5배)
        if aspect >= 0.55, aspect <= 1.5 {
            let top = band(0, 0.2), bottom = band(0.8, 1), middle = band(0.4, 0.6)
            let topSpan = top.map(span).max() ?? 0, bottomSpan = bottom.map(span).max() ?? 0
            let midSpan = middle.map(span).max() ?? 0
            let mass = Double(inkCount(top) + inkCount(bottom)) / Double(max(1, blob.area))
            if Double(topSpan) >= Double(w) * 0.7, Double(bottomSpan) >= Double(w) * 0.7,
               Double(midSpan) <= Double(w) * 0.62, mass >= 0.3 {
                return Found(kind: .sigma, blob: blob, centerX: Double(blob.x0) + Double(w) / 2, ratio: ratio)
            }
        }
        // ∫: 아주 크고(보통 글자의 1.6배 이상) 길쭉하며, 위쪽은 한쪽·아래쪽은 반대쪽으로 휘어 기울어 있음
        if ratio >= 1.6, aspect <= 0.85, Double(blob.area) <= Double(w * h) * 0.55,
           let top = centroidX(band(0, 0.25)), let bottom = centroidX(band(0.75, 1)),
           abs(top - bottom) >= Double(w) * 0.15 {
            // 세로 줄기: 긴 세로 줄이 이어진 열들의 가운데
            var stem: [Int] = []
            for x in 0..<w {
                var run = 0, best = 0
                for r in 0..<h {
                    let y = blob.y0 + r
                    if ink.mask[y * ink.width + blob.x0 + x] { run += 1; best = max(best, run) } else { run = 0 }
                }
                if Double(best) >= Double(h) * 0.25 { stem.append(x) }
            }
            let center = stem.isEmpty ? Double(blob.x0) + Double(w) / 2 : Double(blob.x0) + Double(stem.reduce(0, +)) / Double(stem.count)
            return Found(kind: .integral, blob: blob, centerX: center, ratio: ratio)
        }
        return nil
    }

    /// 사각형(픽셀) 안 잉크 픽셀 수
    static func inkCount(_ ink: FractionFinder.Ink, x0: Int, x1: Int, y0: Int, y1: Int) -> Int {
        let xs = max(0, x0), xe = min(ink.width - 1, x1), ys = max(0, y0), ye = min(ink.height - 1, y1)
        guard xs <= xe, ys <= ye else { return 0 }
        var n = 0
        for y in ys...ye { for x in xs...xe where ink.mask[y * ink.width + x] { n += 1 } }
        return n
    }
}
