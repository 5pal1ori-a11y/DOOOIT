import Foundation

/// 사진 속 글줄 기울기 재기 (투영 방법: 여러 각도로 어두운 픽셀을 가로줄에 모아 보고, 줄과 줄 사이가 가장 깨끗하게 갈리는 각도).
/// 픽셀 배열만 다루는 순수 계산 (리눅스 테스트 가능)
enum TextSkew {
    /// gray: 밝기 (0 검정 ~ 255 흰색), 위가 0. 반환: 글줄이 오른쪽으로 올라가면 + (도, 반시계).
    /// 고칠 만큼(0.4° 이상) 기울지 않았거나 글이 너무 적으면 nil
    static func angle(gray: [UInt8], width: Int, height: Int, maxDegrees: Double = 8, step: Double = 0.2) -> Double? {
        guard width > 10, height > 10, gray.count >= width * height else { return nil }
        let ink = FractionFinder.inkMask(gray: gray, width: width, height: height)
        var xs: [Double] = [], ys: [Double] = []
        for y in 0..<height {
            let row = y * width
            for x in 0..<width where ink[row + x] {
                xs.append(Double(x)); ys.append(Double(y))
            }
        }
        // 글자가 거의 없거나 거의 다 어두우면 (사진·그림) 재지 않음
        let total = width * height
        guard xs.count >= 200, xs.count < total / 3 else { return nil }
        // 너무 많으면 고르게 덜어냄
        let stride = max(1, xs.count / 60_000)
        let span = Double(width) * tan(maxDegrees * .pi / 180)
        let offset = span + 1
        let binCount = Int(Double(height) + span * 2) + 3
        func score(_ degrees: Double) -> Double {
            let t = tan(degrees * .pi / 180)
            var bins = [Double](repeating: 0, count: binCount)
            var i = 0
            while i < xs.count {
                let b = Int(ys[i] + xs[i] * t + offset)
                if b >= 0, b < binCount { bins[b] += 1 }
                i += stride
            }
            return bins.reduce(0) { $0 + $1 * $1 }
        }
        var best = (angle: 0.0, score: score(0))
        let flat = best.score
        var a = -maxDegrees
        while a <= maxDegrees + 1e-9 {
            if abs(a) > 1e-9 {
                let s = score(a)
                if s > best.score { best = (a, s) }
            }
            a += step
        }
        // 가까운 두 각도 사이를 더 잘게
        for fine in [best.angle - step / 2, best.angle + step / 2] {
            let s = score(fine)
            if s > best.score { best = (fine, s) }
        }
        guard abs(best.angle) >= 0.4, best.score > flat * 1.03 else { return nil }
        return best.angle
    }
}
