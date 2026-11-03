import Foundation

/// 차트 판독 (외부 AI 없이): 글자 위치로 막대·꺾은선그래프의 항목과 값, 원그래프의 "이름 N%"를 읽음
/// - 항목 이름: 맨 아래 줄에 나란히 놓인 짧은 글자들 (선택지 줄 ①②…는 뺌)
/// - 값: 항목 바로 위에 적힌 숫자. 숫자가 없으면 왼쪽 눈금 숫자로 픽셀 높이를 값으로 바꾸고, 그 항목 위 색칠된 막대 끝을 잼
enum ChartReader {
    struct Item: Equatable {
        var label: String
        var value: Double
    }

    static func read(_ labels: [TextLabel], image: PixelImage? = nil) -> [Item] {
        let clean = labels.map { TextLabel(text: $0.text.trimmingCharacters(in: .whitespaces), box: $0.box) }.filter { !$0.text.isEmpty }
        if let pie = percents(clean), pie.count >= 2 { return pie }
        return bars(clean, image: image)
    }

    // MARK: 원그래프 "사과 40%"

    private static func percentValue(_ s: String) -> Double? {
        guard s.hasSuffix("%") else { return nil }
        return Double(s.dropLast().trimmingCharacters(in: .whitespaces))
    }

    private static func percents(_ labels: [TextLabel]) -> [Item]? {
        var items: [Item] = []
        var used = Set<Int>()
        for (i, label) in labels.enumerated() {
            // 한 조각에 "사과 40%"
            if let m = label.text.firstMatch(of: #/^(.+?)\s*(\d+(?:\.\d+)?)\s*%$/#), let v = Double(m.2), !m.1.contains(where: { $0.isNumber }) {
                items.append(Item(label: String(m.1).trimmingCharacters(in: .whitespaces), value: v)); used.insert(i); continue
            }
            guard let v = percentValue(label.text) else { continue }
            // 낱말로 나뉜 "사과" "40%": 같은 줄 왼쪽의 가장 가까운 글자
            let h = max(label.box.h, 8)
            let left = labels.enumerated().filter { j, other in
                j != i && !used.contains(j) && abs(other.box.midY - label.box.midY) < h * 0.6 && other.box.maxX <= label.box.minX + 2
                    && label.box.minX - other.box.maxX < h * 3 && other.number == nil && percentValue(other.text) == nil
            }.min { label.box.minX - $0.1.box.maxX < label.box.minX - $1.1.box.maxX }
            if let (j, name) = left { items.append(Item(label: name.text, value: v)); used.insert(j); used.insert(i) }
        }
        return items.count >= 2 ? items : nil
    }

    // MARK: 막대·꺾은선

    private static func rows(_ labels: [TextLabel]) -> [[TextLabel]] {
        let sorted = labels.sorted { $0.box.midY < $1.box.midY }
        let heights = labels.map(\.box.h).sorted()
        let tolerance = (heights.isEmpty ? 12 : heights[heights.count / 2]) * 0.6
        var out: [[TextLabel]] = []
        for label in sorted {
            if let last = out.last?.last, abs(label.box.midY - last.box.midY) < tolerance { out[out.count - 1].append(label) } else { out.append([label]) }
        }
        return out.map { $0.sorted { $0.box.midX < $1.box.midX } }
    }

    private static func bars(_ labels: [TextLabel], image: PixelImage?) -> [Item] {
        let allRows = rows(labels)
        // 항목 줄: 아래에서부터, 짧은 글자 2개 이상, 선택지 표시가 없는 줄
        for row in allRows.reversed() {
            guard row.count >= 2, row.count <= 12, row.allSatisfy({ $0.text.count <= 6 }),
                  !row.contains(where: { $0.text.contains(where: { "①②③④⑤".contains($0) }) }) else { continue }
            let catY = row.map(\.box.minY).min() ?? 0
            let spacing = zip(row.dropFirst(), row).map { $0.box.midX - $1.box.midX }.min() ?? 0
            guard spacing > 0 else { continue }
            let leftmost = row.first!.box.minX - spacing * 0.5
            // 눈금 숫자: 항목보다 왼쪽, 위쪽에 세로로 놓인 숫자들
            let ticks = labels.filter { $0.number != nil && $0.box.maxX <= leftmost + spacing * 0.2 && $0.box.midY < catY }
            let values = labels.filter { l in l.number != nil && l.box.maxY <= catY + 2 && !ticks.contains(l) && !row.contains(l) }
            var items: [Item] = []
            for cat in row {
                let near = values.filter { abs($0.box.midX - cat.box.midX) < spacing * 0.4 }
                // 위쪽에 있는 것 중 x가 가장 가까운 숫자
                if let best = near.min(by: { abs($0.box.midX - cat.box.midX) < abs($1.box.midX - cat.box.midX) }), let v = best.number {
                    items.append(Item(label: cat.text, value: v))
                }
            }
            if items.count == row.count { return items }
            // 값 숫자가 없으면 눈금으로 막대 높이를 잼
            if let image, ticks.count >= 2, let measured = measureBars(row, ticks: ticks, catY: catY, spacing: spacing, image: image) { return measured }
            if items.count >= 2, items.count == row.count { return items }
            return []
        }
        return []
    }

    /// 눈금 숫자(세로 위치 → 값)로 막대 끝의 높이를 값으로
    private static func measureBars(_ row: [TextLabel], ticks: [TextLabel], catY: Double, spacing: Double, image: PixelImage) -> [Item]? {
        guard let fit = VisionMath.lineFit(ticks.map(\.box.midY), ticks.compactMap(\.number)), abs(fit.a) > 1e-9, fit.rmse < 0.05 * (ticks.compactMap(\.number).max() ?? 1) + 0.5 else { return nil }
        let top = Int(max(0, ticks.map(\.box.minY).min()! - 20))
        var items: [Item] = []
        let step = ticks.compactMap(\.number).sorted().adjacentPairs().map { $1 - $0 }.filter { $0 > 0 }.min() ?? 1
        for cat in row {
            let x = Int(cat.box.midX)
            guard x >= 0, x < image.width else { return nil }
            // 항목 글자 바로 위(축 선 포함)에서 위로: 색칠된 막대가 이어지는 끝
            var y = Int(catY) - 3
            var barTop: Int?
            var gap = 0
            var started = false
            while y > top {
                let i = image.index(x, y)
                let fill = image.chroma[i] > 40 && image.gray[i] < 235
                if fill { started = true; barTop = y; gap = 0 } else if started { gap += 1; if gap > 3 { break } }
                y -= 1
            }
            guard let barTop else { return nil }
            let raw = fit.a * Double(barTop) + fit.b
            // 눈금 간격의 1/10로 맞춤 (픽셀 오차)
            let unit = step / 10
            items.append(Item(label: cat.text, value: (raw / unit).rounded() * unit))
        }
        return items.count >= 2 ? items : nil
    }
}

private extension Array {
    func adjacentPairs() -> [(Element, Element)] { count < 2 ? [] : (1..<count).map { (self[$0 - 1], self[$0]) } }
}
