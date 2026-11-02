import Foundation

/// 사진 속 쌓은 분수(가로 막대 위아래에 분자·분모) 찾기.
/// 글자 인식은 작은 분수를 "늘", "÷", "⅔" 같은 한 글자로 읽어 버려서 (사진 테스트에서 확인)
/// 막대 모양을 픽셀에서 직접 찾고, 분자·분모 자리는 따로 잘라 다시 읽음 (OCRCore).
/// 이 파일은 픽셀 배열만 다루는 순수 계산 (리눅스 테스트 가능)
enum FractionFinder {
    /// 찾은 분수 막대 (픽셀 좌표, 위가 0)
    struct Bar: Equatable {
        var x0: Int, x1: Int          // 막대 왼쪽·오른쪽 끝 (포함)
        var top: Int, bottom: Int     // 막대 두께 (포함)
        var numeratorTop: Int         // 분자 맨 위
        var denominatorBottom: Int    // 분모 맨 아래
        /// 분자·분모 영역 (픽셀, 위가 0): (x, y, 너비, 높이)
        var numerator: (x: Int, y: Int, width: Int, height: Int) {
            (x0, numeratorTop, x1 - x0 + 1, max(1, top - numeratorTop))
        }
        var denominator: (x: Int, y: Int, width: Int, height: Int) {
            (x0, bottom + 1, x1 - x0 + 1, max(1, denominatorBottom - bottom))
        }
        static func == (a: Bar, b: Bar) -> Bool {
            a.x0 == b.x0 && a.x1 == b.x1 && a.top == b.top && a.bottom == b.bottom
        }
    }

    /// 글자(잉크) 픽셀: 주변 종이 밝기보다 확실히 어두운 픽셀.
    /// 한쪽이 어두운 조명·책상 배경에서도 맞도록 16픽셀 칸마다 가장 밝은 값(종이)을 재고 그와 비교함
    static func inkMask(gray: [UInt8], width: Int, height: Int) -> [Bool] {
        let block = 16
        let bw = (width + block - 1) / block, bh = (height + block - 1) / block
        var paper = [Int](repeating: 0, count: bw * bh)
        for y in 0..<height {
            let by = y / block
            for x in 0..<width {
                let i = by * bw + x / block
                let v = Int(gray[y * width + x])
                if v > paper[i] { paper[i] = v }
            }
        }
        // 글자로 꽉 찬 칸도 있으니 이웃 칸까지 넓혀서 종이 밝기로
        var smooth = paper
        for by in 0..<bh {
            for bx in 0..<bw {
                var m = 0
                for dy in -1...1 {
                    for dx in -1...1 {
                        let yy = by + dy, xx = bx + dx
                        if yy >= 0, yy < bh, xx >= 0, xx < bw { m = max(m, paper[yy * bw + xx]) }
                    }
                }
                smooth[by * bw + bx] = m
            }
        }
        var mask = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            let by = y / block
            for x in 0..<width {
                let bg = smooth[by * bw + x / block]
                // 종이보다 30% 이상 어둡고, 종이 자체가 너무 어둡지 않을 때 (어두운 배경 속 무늬는 글자가 아님)
                mask[y * width + x] = bg >= 90 && Int(gray[y * width + x]) * 10 < bg * 7
            }
        }
        // 절반 가까이 어두운 칸은 글자가 아니라 종이 밖 배경·그림 (종이 가장자리가 긴 선으로 잡히지 않게)
        var counts = [Int](repeating: 0, count: bw * bh)
        for y in 0..<height {
            let by = y / block
            for x in 0..<width where mask[y * width + x] { counts[by * bw + x / block] += 1 }
        }
        for y in 0..<height {
            let by = y / block
            for x in 0..<width where mask[y * width + x] && counts[by * bw + x / block] * 100 > block * block * 45 {
                mask[y * width + x] = false
            }
        }
        return mask
    }

    /// 어두운 글자 픽셀 기준 (오츠 방법, 너무 밝거나 어둡지 않게)
    static func darkThreshold(_ gray: [UInt8]) -> UInt8 {
        var histogram = [Int](repeating: 0, count: 256)
        for v in gray { histogram[Int(v)] += 1 }
        let total = gray.count
        guard total > 0 else { return 128 }
        var sumAll = 0.0
        for level in 0..<256 { sumAll += Double(level * histogram[level]) }
        var sumBack = 0.0, weightBack = 0.0, bestVariance = 0.0, otsu = 128
        for level in 0..<256 {
            weightBack += Double(histogram[level])
            if weightBack == 0 { continue }
            let weightFore = Double(total) - weightBack
            if weightFore == 0 { break }
            sumBack += Double(level * histogram[level])
            let meanBack = sumBack / weightBack
            let meanFore = (sumAll - sumBack) / weightFore
            let variance = weightBack * weightFore * (meanBack - meanFore) * (meanBack - meanFore)
            if variance > bestVariance { bestVariance = variance; otsu = level }
        }
        return UInt8(min(max(otsu, 60), 200))
    }

    /// gray: 밝기 (0 검정 ~ 255 흰색), 가로 width, 세로 height, 위가 0
    /// size: 글자 크기 짐작 (픽셀, 한글 한 글자 높이쯤 — 글자 인식 줄 상자 높이의 아래쪽 4분위 값)
    /// lines: 글자 인식 줄 상자 (픽셀, 위가 0). 분수가 없는 줄들의 높이로 글자 크기를 다시 재서
    ///        분수 묶음이 보통 글자보다 확실히 높은지 봄 ("갈", "를", "필"의 가로획 묶음은 글자 하나 높이)
    static func bars(gray: [UInt8], width: Int, height: Int, size: Double,
                     lines: [(x: Double, y: Double, width: Double, height: Double)] = []) -> [Bar] {
        guard width > 4, height > 4, gray.count >= width * height, size >= 6 else { return [] }
        let dark = inkMask(gray: gray, width: width, height: height)
        func isDark(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height && dark[y * width + x] }
        /// 가로 [x0, x1], 세로 y 줄에서 어두운 비율
        func coverage(_ x0: Int, _ x1: Int, _ y: Int) -> Double {
            guard y >= 0, y < height, x1 >= x0 else { return 0 }
            var n = 0
            for x in max(0, x0)...min(width - 1, x1) where dark[y * width + x] { n += 1 }
            return Double(n) / Double(x1 - x0 + 1)
        }
        /// 영역 안 잉크의 위·아래 끝과 가로 범위 (없으면 nil)
        func inkBounds(_ x0: Int, _ x1: Int, _ y0: Int, _ y1: Int) -> (top: Int, bottom: Int, left: Int, right: Int, count: Int)? {
            var top = Int.max, bottom = -1, left = Int.max, right = -1, count = 0
            let ys = max(0, y0), ye = min(height - 1, y1), xs = max(0, x0), xe = min(width - 1, x1)
            guard ys <= ye, xs <= xe else { return nil }
            for y in ys...ye {
                for x in xs...xe where dark[y * width + x] {
                    count += 1
                    top = min(top, y); bottom = max(bottom, y); left = min(left, x); right = max(right, x)
                }
            }
            return count > 0 ? (top, bottom, left, right, count) : nil
        }

        // 줄 상자로 짐작한 글자 크기는 분수가 든 줄에서 1.5배쯤 커짐 → 아래 한계는 작은 쪽(lo)으로
        let lo = size / 1.5
        let minLength = max(5, Int(lo * 0.35)), maxLength = Int(size * 4)
        let maxThick = max(2, Int((size * 0.13).rounded(.up)))
        var found: [Bar] = []
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                guard dark[y * width + x] else { x += 1; continue }
                var end = x
                while end + 1 < width, dark[y * width + end + 1] { end += 1 }
                defer { x = end + 1 }
                let length = end - x + 1
                guard length >= minLength, length <= maxLength else { continue }
                // 이미 찾은 막대의 아랫줄이면 건너뜀
                if found.contains(where: { y >= $0.top && y <= $0.bottom && x <= $0.x1 && end >= $0.x0 }) { continue }
                // 두께: 아래로 같은 길이로 이어지는 줄 수
                var bottom = y
                while bottom + 1 < height, coverage(x, end, bottom + 1) >= 0.85 { bottom += 1 }
                let thick = bottom - y + 1
                guard thick <= maxThick else { continue }
                // 막대 양 끝 바로 바깥은 비어 있어야 함 (글자 획의 일부가 아님)
                var attached = false
                for row in y...bottom where isDark(x - 1, row) || isDark(end + 1, row) { attached = true }
                if attached { continue }
                // 바로 위·아래 한 줄은 거의 비어 있어야 함 (분자·분모와 떨어져 있음)
                guard coverage(x, end, y - 1) < 0.35, coverage(x, end, bottom + 1) < 0.35 else { continue }
                // 위·아래에 글자가 있어야 함 (막대 폭 안쪽, 글자 크기만큼)
                let reach = Int(size * 1.1)
                let pad = max(1, length / 12)
                guard let above = inkBounds(x + pad, end - pad, y - reach, y - 1),
                      let below = inkBounds(x + pad, end - pad, bottom + 1, bottom + reach) else { continue }
                // 위 글자는 막대 바로 위에서 끝나고 아래 글자는 바로 아래에서 시작 (등호 "="의 다른 줄이 아님)
                let gapAbove = y - 1 - above.bottom, gapBelow = below.top - (bottom + 1)
                guard gapAbove <= Int(size * 0.45), gapBelow <= Int(size * 0.45) else { continue }
                let heightAbove = above.bottom - above.top + 1, heightBelow = below.bottom - below.top + 1
                guard Double(heightAbove) >= lo * 0.3, Double(heightBelow) >= lo * 0.3,
                      Double(max(heightAbove, heightBelow)) <= min(size * 1.2, Double(length) * 1.6) else { continue }
                // 분자·분모는 막대 가운데쯤
                let mid = Double(x + end) / 2
                let aboveMid = Double(above.left + above.right) / 2, belowMid = Double(below.left + below.right) / 2
                guard abs(aboveMid - mid) <= Double(length) * 0.3, abs(belowMid - mid) <= Double(length) * 0.3 else { continue }
                // 분자·분모를 위·아래 끝까지 (막대 폭 안에서 이어지는 잉크)
                let stackTop = above.top, stackBottom = below.bottom
                let stack = stackBottom - stackTop + 1
                // 양옆 바로 붙은 글자가 분수만큼 크면 보통 글자("를", "늘"의 ㅡ)
                func neighborHeight(direction: Int) -> Int? {
                    var col = direction < 0 ? x - 1 : end + 1
                    let limit = Int(size * 0.9)
                    var steps = 0
                    while steps < limit, col >= 0, col < width {
                        if (stackTop...stackBottom).contains(where: { isDark(col, $0) }) { break }
                        col += direction; steps += 1
                    }
                    guard steps < limit, col >= 0, col < width else { return nil }
                    // 그 글자의 세로 범위 (빈 세로줄이 나올 때까지)
                    var top = Int.max, bottom = -1
                    var c = col
                    var width2 = 0
                    let band0 = stackTop - Int(size * 0.3), band1 = stackBottom + Int(size * 0.3)
                    while c >= 0, c < width, width2 < Int(size * 1.2) {
                        var any = false
                        for row in max(0, band0)...min(height - 1, band1) where dark[row * width + c] {
                            any = true; top = min(top, row); bottom = max(bottom, row)
                        }
                        if !any { break }
                        c += direction; width2 += 1
                    }
                    return bottom >= top ? bottom - top + 1 : nil
                }
                let neighbors = [neighborHeight(direction: -1), neighborHeight(direction: 1)].compactMap { $0 }
                if neighbors.contains(where: { Double($0) >= Double(stack) * 0.72 }) { continue }
                // 분수는 보통 글자보다 훨씬 높음 (분자 + 막대 + 분모). "를", "필"의 ㅡ 묶음은 글자 하나 높이
                // (분수가 많은 사진은 글자 크기 짐작이 커지므로, 막대보다 두 배 가까이 높은 묶음도 후보: 한 글자 분자·분모)
                if Double(stack) < size * 1.3 && Double(stack) < Double(length) * 1.9 { continue }
                found.append(Bar(x0: x, x1: end, top: y, bottom: bottom, numeratorTop: stackTop, denominatorBottom: stackBottom))
            }
            y += 1
        }
        // 분자 글자 "2"의 밑획처럼 다른 막대의 분자·분모 안에 든 짧은 막대는 버림
        let kept = found.filter { bar in
            !found.contains { other in
                other != bar && other.x1 - other.x0 > bar.x1 - bar.x0
                    && bar.top >= other.numeratorTop && bar.bottom <= other.denominatorBottom
                    && bar.x0 <= other.x1 && bar.x1 >= other.x0
            }
        }
        // 분수 후보가 없는 줄들로 글자 크기를 다시 잼 → 분수 묶음은 그 1.3배 이상
        func contains(_ line: (x: Double, y: Double, width: Double, height: Double), _ bar: Bar) -> Bool {
            let cx = Double(bar.x0 + bar.x1) / 2, cy = Double(bar.top + bar.bottom) / 2
            return cx >= line.x && cx <= line.x + line.width && cy >= line.y && cy <= line.y + line.height
        }
        let plainHeights = lines.filter { line in !kept.contains { contains(line, $0) } }.map(\.height).sorted()
        guard !plainHeights.isEmpty else { return kept }
        let plainSize = plainHeights[plainHeights.count / 2]
        return kept.filter { Double($0.denominatorBottom - $0.numeratorTop + 1) >= plainSize * 1.3 }
    }
}
