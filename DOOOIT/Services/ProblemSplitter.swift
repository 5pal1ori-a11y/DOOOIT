import Foundation

/// 문제집 한 쪽(페이지) 사진에서 문제 번호("1.", "03", "[2]", "문제 4", "Q5")를 찾아
/// 문제마다 영역을 나눔. Vision 글자 상자만으로 계산하는 순수 로직 (Linux 테스트 가능).
///
/// - 번호는 줄 맨 앞 + 그 단의 왼쪽 끝에 있어야 함 (식 속 숫자·들여 쓴 줄은 무시)
/// - 선택지 ①~⑤, 소문항 (1)(2), 쪽 번호(맨 아래 "23")는 문제 번호로 보지 않음
/// - 두 단 페이지: 번호의 x 위치로 단을 찾아 왼쪽 단 위→아래, 다음 오른쪽 단 순서
/// - 번호는 읽는 순서대로 커져야 함 (가장 길게 이어지는 번호들만 사용)
/// - 문제가 2개 미만이면 빈 배열 → 기존 "직접 자르기" 화면 사용
enum ProblemSplitter {
    struct Region: Identifiable, Equatable {
        /// 문제 번호 (읽는 순서대로 커짐 → 한 페이지 안에서 겹치지 않음)
        let number: Int
        /// Vision 정규화 좌표 (0~1, 원점 왼쪽 아래) — OCRLine.box와 같은 좌표
        let box: CGRect
        var id: Int { number }
        /// 화면·자르기용 좌표 (0~1, 원점 왼쪽 위)
        var topLeftRect: CGRect { CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height) }
    }

    enum Style: CaseIterable { case numbered, bracket, labeled }

    /// 계산용 글자 상자 (원점 왼쪽 위 좌표로 바꿔 둠: top < bottom)
    struct Box {
        let id: Int
        let text: String
        let left, right, top, bottom: Double
        var midX: Double { (left + right) / 2 }
        var midY: Double { (top + bottom) / 2 }
        var height: Double { bottom - top }
    }

    struct Anchor {
        let number: Int
        let style: Style
        let box: Box
        var column = 0
    }

    // MARK: - 기준값 (페이지 너비·높이 비율)

    /// 번호 x 위치가 이만큼 벌어지면 다른 단
    private static let columnGap = 0.15
    /// 같은 단의 번호끼리 허용하는 x 흔들림
    private static let marginTolerance = 0.045
    /// 이어지는 번호 사이에 빠져도 되는 개수 + 1 (1, 2, 4는 됨 / 1, 2, 9는 안 됨)
    private static let maxNumberStep = 3
    private static let pad = 0.012

    // MARK: - 진입점

    static func regions(lines: [OCRLine]) -> [Region] {
        let boxes: [Box] = lines.enumerated().compactMap { i, line in
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let r = line.box.standardized
            guard !text.isEmpty, r.width > 0, r.height > 0 else { return nil }
            return Box(id: i, text: text, left: Double(r.minX), right: Double(r.maxX),
                       top: 1 - Double(r.maxY), bottom: 1 - Double(r.minY))
        }
        guard boxes.count >= 2 else { return [] }

        // 1) 줄 맨 앞에 번호가 있는 줄 (같은 높이에서 바로 왼쪽에 이어지는 글자가 있으면 줄 중간이므로 제외)
        let candidates: [Anchor] = boxes.compactMap { box in
            guard let found = anchor(in: box.text) else { return nil }
            let midLine = boxes.contains { other in
                other.id != box.id && overlapsVertically(other, box)
                    && other.left < box.left - 0.005 && other.right > box.left - 0.015
            }
            return midLine ? nil : Anchor(number: found.number, style: found.style, box: box)
        }

        // 2) 번호 모양마다 따로 이어 보고 가장 길게 이어지는 것 사용 ("01"과 "[1]"이 섞이지 않게)
        let chains = Style.allCases.map { style in chain(candidates.filter { $0.style == style }, boxes: boxes) }
        guard let best = chains.max(by: { $0.count < $1.count }), best.count >= 2 else { return [] }
        return layout(best, boxes: boxes)
    }

    // MARK: - 번호 읽기

    /// 줄 맨 앞의 문제 번호. ①②③, (1)(2), 1), 그냥 "23"은 문제 번호로 보지 않음
    static func anchor(in raw: String) -> (number: Int, style: Style)? {
        let text = raw.replacingOccurrences(of: "．", with: ".")
        // [1] 【1】 〔1〕
        if let n = capture(#"^[\[【〔]\s*(\d{1,3})\s*[\]】〕]"#, in: text) { return valid(n, .bracket) }
        // 문제 3 · 문항 3 · 예제 3 · Q3 · Q.3 (유형 N은 여러 문제를 묶는 제목이라 제외)
        if let n = capture(#"^(?:문제|문항|예제|Q|q)\s*\.?\s*(\d{1,3})(?![\d,]|\.\d)"#, in: text) { return valid(n, .labeled) }
        // 1. · 12. (소수 1.5, 말줄임 1.. 은 제외)
        if let n = capture(#"^(\d{1,3})\s?\.(?![\d.])"#, in: text) { return valid(n, .numbered) }
        // 01 · 003 (앞에 0을 붙인 번호만 — 그냥 "23"은 쪽 번호나 식일 수 있음)
        if let n = capture(#"^(0\d{1,2})(?![\d.,:/])"#, in: text) { return valid(n, .numbered) }
        return nil
    }

    private static func valid(_ digits: String, _ style: Style) -> (number: Int, style: Style)? {
        guard let n = Int(digits), n >= 1, n <= 999 else { return nil }
        return (n, style)
    }

    private static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    // MARK: - 단 나누기 + 번호 잇기

    /// 한 가지 모양의 번호들 → 단 찾기 → 읽는 순서로 커지는 가장 긴 번호 줄
    private static func chain(_ anchors: [Anchor], boxes: [Box]) -> [Anchor] {
        guard anchors.count >= 2 else { return [] }
        let contentBottom = boxes.filter { !isFooter($0) }.map(\.bottom).max() ?? 1

        // x 위치로 묶기 (왼쪽부터)
        let sorted = anchors.sorted { $0.box.left < $1.box.left }
        var groups: [[Anchor]] = [[sorted[0]]]
        for a in sorted.dropFirst() {
            if let last = groups[groups.count - 1].last, a.box.left - last.box.left > columnGap {
                groups.append([a])
            } else {
                groups[groups.count - 1].append(a)
            }
        }

        var columns: [(left: Double, anchors: [Anchor])] = []
        for group in groups {
            // 단의 왼쪽 끝 = 번호가 가장 많이 모인 x (튀는 번호 하나에 끌려가지 않게)
            let lefts = group.map(\.box.left)
            let modeLeft = lefts.max { a, b in
                let ca = lefts.filter { abs($0 - a) <= 0.03 }.count, cb = lefts.filter { abs($0 - b) <= 0.03 }.count
                return ca != cb ? ca < cb : a > b
            } ?? lefts[0]
            let near = lefts.filter { abs($0 - modeLeft) <= 0.03 }
            let left = near.reduce(0, +) / Double(near.count)
            // 단의 왼쪽 끝에 붙은 번호만 (들여 쓴 줄 맨 앞 숫자는 제외)
            let kept = group.filter { abs($0.box.left - left) <= marginTolerance }
            guard let top = kept.map(\.box.top).min() else { continue }
            // 진짜 단이면 번호 x 위치를 가로지르는 줄이 거의 없음 (한 단 페이지 가운데 숫자는 제외)
            let below = boxes.filter { $0.midY >= top && $0.midY <= contentBottom && !isFooter($0) }
            let crossing = below.filter { $0.left < left - 0.03 && $0.right > left + 0.01 }.count
            guard crossing <= max(1, below.count / 8) else { continue }
            columns.append((left, kept))
        }
        columns.sort { $0.left < $1.left }

        // 읽는 순서: 왼쪽 단 위→아래, 다음 단 위→아래
        var ordered: [Anchor] = []
        for (c, column) in columns.enumerated() {
            for var a in column.anchors.sorted(by: { $0.box.top < $1.box.top }) {
                a.column = c
                ordered.append(a)
            }
        }
        return increasingChain(ordered)
    }

    /// 번호가 1~3씩 커지는 가장 긴 줄 (같으면 덜 건너뛴 쪽). 쪽 번호·식 속 숫자 같은 잡음이 빠짐
    private static func increasingChain(_ anchors: [Anchor]) -> [Anchor] {
        guard !anchors.isEmpty else { return [] }
        var length = Array(repeating: 1, count: anchors.count)
        var skipped = Array(repeating: 0, count: anchors.count)
        var previous: [Int?] = Array(repeating: nil, count: anchors.count)
        for i in anchors.indices {
            for j in 0..<i {
                let step = anchors[i].number - anchors[j].number
                guard step >= 1, step <= maxNumberStep else { continue }
                let l = length[j] + 1, s = skipped[j] + step - 1
                if l > length[i] || (l == length[i] && s < skipped[i]) {
                    length[i] = l; skipped[i] = s; previous[i] = j
                }
            }
        }
        guard var end = anchors.indices.max(by: { length[$0] != length[$1] ? length[$0] < length[$1] : skipped[$0] > skipped[$1] }) else { return [] }
        var result = [anchors[end]]
        while let p = previous[end] { result.append(anchors[p]); end = p }
        return result.reversed()
    }

    // MARK: - 영역 만들기

    /// 번호부터 같은 단의 다음 번호 바로 위까지 (단의 마지막 문제는 페이지 글자 끝까지), 단 너비 전체
    private static func layout(_ anchors: [Anchor], boxes: [Box]) -> [Region] {
        let columnIndexes = Array(Set(anchors.map(\.column))).sorted()
        let columnLeft: [Int: Double] = Dictionary(uniqueKeysWithValues: columnIndexes.map { c in
            (c, anchors.filter { $0.column == c }.map(\.box.left).min() ?? 0)
        })
        let content = boxes.filter { !isFooter($0) }
        let pageBottom = content.map(\.bottom).max() ?? 1

        var regions: [Region] = []
        for (k, c) in columnIndexes.enumerated() {
            let left = columnLeft[c] ?? 0
            // 단 경계: 다음 단 번호 조금 왼쪽
            let lowerBound = k == 0 ? 0 : left - 0.03
            let upperBound = k + 1 < columnIndexes.count ? (columnLeft[columnIndexes[k + 1]] ?? 1) - 0.03 : 1.01
            let columnAnchors = anchors.filter { $0.column == c }.sorted { $0.box.top < $1.box.top }
            guard let firstTop = columnAnchors.first?.box.top else { continue }
            let columnBoxes = content.filter { $0.midX >= lowerBound && $0.midX < upperBound && $0.bottom >= firstTop }

            let textLeft = min(left, columnBoxes.map(\.left).min() ?? left)
            let x0 = max(k == 0 ? 0 : lowerBound - 0.01, textLeft - pad)
            let x1: Double
            if k + 1 < columnIndexes.count {
                x1 = upperBound
            } else {
                let textRight = columnBoxes.map(\.right).filter { $0 <= 1.01 }.max() ?? 1
                x1 = min(1, textRight + 0.03)
            }
            guard x1 - x0 > 0.05 else { continue }

            for (i, a) in columnAnchors.enumerated() {
                let y0 = max(0, a.box.top - pad)
                var y1: Double
                if i + 1 < columnAnchors.count {
                    y1 = columnAnchors[i + 1].box.top - 0.004
                } else {
                    // 단의 마지막 문제: 이 단과 페이지의 마지막 글자까지 (아래 그림·선택지가 잘리지 않게)
                    let columnBottom = columnBoxes.map(\.bottom).max() ?? a.box.bottom
                    y1 = min(1, max(columnBottom, pageBottom) + 0.03)
                }
                y1 = min(1, max(y1, a.box.bottom + 0.01))
                guard y1 > y0 else { continue }
                regions.append(Region(number: a.number,
                                      box: CGRect(x: x0, y: 1 - y1, width: x1 - x0, height: y1 - y0)))
            }
        }
        return regions.count >= 2 ? regions : []
    }

    // MARK: - 도움 함수

    private static func overlapsVertically(_ a: Box, _ b: Box) -> Bool {
        let overlap = min(a.bottom, b.bottom) - max(a.top, b.top)
        return overlap > min(a.height, b.height) * 0.5
    }

    /// 맨 아래 쪽 번호 ("23", "- 23 -", "p.23")
    private static func isFooter(_ box: Box) -> Bool {
        box.top > 0.88 && box.text.range(of: #"^[\s\-–—·|pP.]*\d{1,4}[\s\-–—·|]*$"#, options: .regularExpression) != nil
    }
}
