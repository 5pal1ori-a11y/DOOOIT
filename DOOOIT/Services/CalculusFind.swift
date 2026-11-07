import Foundation

/// 미적분 기호 찾기: 사진 속 큰 기호(∑ ∫)와 글자 lim 을 찾고, 위끝·아래끝은 따로 읽힌 조각이나 잘라 읽기로 채움.
/// 잘라 읽기(read)는 호출하는 쪽(OCRCore)이 넣어 줌 → 이 파일은 Foundation만 써서 리눅스에서 시험 가능
enum CalculusFind {
    /// read: Vision 좌표(0~1, 왼쪽 아래 원점) 사각형을 잘라 키워서 읽은 글 (variant 0~2: 키우는 정도·여백을 달리해 세 번 읽어 맞춰 봄)
    typealias Reader = (CGRect, Int) async -> String?

    /// 픽셀(위가 0) 사각형 → Vision 좌표
    private static func vision(_ ink: FractionFinder.Ink, x0: Int, x1: Int, y0: Int, y1: Int) -> CGRect {
        let w = CGFloat(ink.width), h = CGFloat(ink.height)
        let ax = CGFloat(max(0, x0)), bx = CGFloat(min(ink.width, x1 + 1))
        let ay = CGFloat(max(0, y0)), by = CGFloat(min(ink.height, y1 + 1))
        return CGRect(x: ax / w, y: 1 - by / h, width: max(0, bx - ax) / w, height: max(0, by - ay) / h)
    }

    /// Vision 좌표 → 픽셀 가로 구간
    private static func pixelX(_ ink: FractionFinder.Ink, _ x: CGFloat) -> Int { Int((x * CGFloat(ink.width)).rounded()) }
    private static func pixelY(_ ink: FractionFinder.Ink, _ y: CGFloat) -> Int { Int(((1 - y) * CGFloat(ink.height)).rounded()) }

    /// 지정한 자리 안에 따로 읽힌 작은 조각들의 글 (글자 인식이 이미 읽은 것)
    private static func pieces(in region: CGRect, from lines: [OCRGlyphLine], lineHeight: CGFloat) -> [String] {
        lines.filter { l in
            let b = l.box
            return b.height <= lineHeight * 1.1 && l.text.count <= 10
                && region.insetBy(dx: -region.width * 0.05, dy: -region.height * 0.05).contains(CGPoint(x: b.midX, y: b.midY))
        }.sorted { $0.box.minX < $1.box.minX }.map(\.text)
    }

    /// 같은 자리를 세 번(variant 0~2) 읽어 두 번 이상 같게 나온 값만 믿음
    private static func vote<T: Hashable>(_ box: CGRect, read: Reader, parse: (String) -> T?) async -> T? {
        var counts: [T: Int] = [:]
        for variant in 0..<3 {
            if let text = await read(box, variant), let value = parse(text) {
                counts[value, default: 0] += 1
                if counts[value]! >= 2 { return value }
            }
        }
        return nil
    }

    /// 서로 다른 세 자리(조금씩 어긋나게 자른 것)를 한 번씩 읽어 두 번 이상 같게 나온 값만 믿음
    private static func voteBoxes<T: Hashable>(_ boxes: [CGRect], read: Reader, parse: (String) -> T?) async -> T? {
        var counts: [T: Int] = [:]
        for (k, box) in boxes.enumerated() {
            if let text = await read(box, k % 3), let value = parse(text) {
                counts[value, default: 0] += 1
                if counts[value]! >= 2 { return value }
            }
        }
        return nil
    }

    /// pieces: 한국어·영어 읽기 줄 모두 (위끝·아래끝 조각 찾기용), hosts: 한국어 읽기 줄 (lim 낱말 찾기용)
    static func find(ink: FractionFinder.Ink, pieces all: [OCRGlyphLine], hosts: [OCRGlyphLine], lineHeight: CGFloat, read: Reader) async -> [CalculusLayout.Finding] {
        var findings: [CalculusLayout.Finding] = []

        // 1) 큰 기호 ∑ ∫ (사진 모양)
        for shape in CalculusShape.find(ink) {
            let b = shape.blob
            let w = b.width, h = b.height
            switch shape.kind {
            case .sigma:
                let cx = (b.x0 + b.x1) / 2
                let gap = max(4, Int(Double(h) * 0.22))
                let x0 = b.x0 - Int(Double(w) * 0.8), x1 = b.x1 + Int(Double(w) * 0.8)
                let belowRun = CalculusShape.inkRun(ink, x0: x0, x1: x1, y0: b.y1 + 2, y1: b.y1 + Int(Double(h) * 1.0), gap: gap, near: cx)
                let aboveRun = CalculusShape.inkRun(ink, x0: x0, x1: x1, y0: b.y0 - Int(Double(h) * 1.0), y1: b.y0 - 2, gap: gap, near: cx)
                var regions: [CGRect] = []
                var below: String?, above: String?
                var unread = false
                if let r = belowRun {
                    let box = vision(ink, x0: r.x0 - 2, x1: r.x1 + 2, y0: r.y0 - 2, y1: r.y1 + 2)
                    regions.append(box)
                    for text in pieces(in: box, from: all, lineHeight: lineHeight) where below == nil { below = CalculusLayout.sigmaBelow(text) }
                    if below == nil { below = await vote(box, read: read, parse: CalculusLayout.sigmaBelow) }
                    if below == nil { unread = true }
                }
                if let r = aboveRun {
                    let box = vision(ink, x0: r.x0 - 2, x1: r.x1 + 2, y0: r.y0 - 2, y1: r.y1 + 2)
                    regions.append(box)
                    for text in pieces(in: box, from: all, lineHeight: lineHeight) where above == nil { above = CalculusLayout.bound(text) }
                    if above == nil { above = await vote(box, read: read, parse: CalculusLayout.bound) }
                    // ∞ 는 8·00·oo 로 읽히기 쉬움: 잉크 상자가 가로로 납작하면(너비 ≥ 높이의 1.35배) ∞
                    let aspect = Double(r.x1 - r.x0 + 1) / Double(r.y1 - r.y0 + 1)
                    if aspect >= 1.35, let a = above, ["8", "0", "00", "6", "9"].contains(a) { above = "∞" }
                    if above == nil { unread = true }
                }
                var text = "∑"
                if let below { text += CalculusLayout.script("_", below) }
                if let above { text += CalculusLayout.script("^", above) }
                // 위·아래끝 자리에 잉크가 있는데 읽지 못한 쪽이 있으면 부분만 붙이면 틀린 식이 됨 → 기호만 바꾸고 조각은 그대로 둠
                if unread { text = "∑"; regions = [] }
                let symbol = vision(ink, x0: b.x0, x1: b.x1, y0: b.y0, y1: b.y1)
                findings.append(CalculusLayout.Finding(kind: .sigma, symbol: symbol, text: text, regions: regions,
                                                      strong: below != nil && !unread, coverMaxX: symbol.maxX))
            case .integral:
                let c = Int(shape.centerX.rounded())
                let hd = Double(h)
                // 위끝: 기호 오른쪽 위 (고리 아래), 아래끝: 오른쪽 아래 (꼬리 위). 세 번 조금씩 어긋나게 잘라 읽음
                let shifts = [0.05, 0.10, 0.15]
                let uppers = shifts.map { s in vision(ink, x0: c + Int(hd * s), x1: c + Int(hd * (s + 0.52)), y0: b.y0 + Int(hd * 0.02), y1: b.y0 + Int(hd * 0.40)) }
                let lowers = shifts.map { s in vision(ink, x0: c + Int(hd * s), x1: c + Int(hd * (s + 0.52)), y0: b.y1 - Int(hd * 0.40), y1: b.y1 - Int(hd * 0.02)) }
                let upper = await voteBoxes(uppers, read: read, parse: CalculusLayout.integralBound)
                let lower = await voteBoxes(lowers, read: read, parse: CalculusLayout.integralBound)
                let symbol = vision(ink, x0: b.x0, x1: b.x1, y0: b.y0, y1: b.y1)
                let right = vision(ink, x0: b.x1, x1: b.x1 + Int(hd * 0.1), y0: b.y0, y1: b.y1).maxX
                // 위·아래끝이 둘 다 읽혔을 때만 붙임 (하나만 읽으면 ∫ 만)
                if let upper, let lower {
                    findings.append(CalculusLayout.Finding(kind: .integral, symbol: symbol, text: "∫" + CalculusLayout.script("_", lower) + CalculusLayout.script("^", upper),
                                                          regions: [uppers[1], lowers[1]], strong: true, coverMaxX: right))
                } else {
                    findings.append(CalculusLayout.Finding(kind: .integral, symbol: symbol, text: "∫", regions: [], strong: false, coverMaxX: right))
                }
            }
        }

        // 2) lim: 글자 "lim" 아래에 쌓인 x→a
        for line in hosts {
            let chars = Array(line.text)
            let string = line.text
            guard let regex = try? NSRegularExpression(pattern: #"(?<![A-Za-z])(?:lim|Iim|1im|llm|Ilm|iim|lm|lirn|Iirn|tim|Lim)(?![A-Za-z])"#) else { continue }
            for m in regex.matches(in: string, range: NSRange(string.startIndex..., in: string)) {
                guard let sr = Range(m.range, in: string) else { continue }
                let start = string.distance(from: string.startIndex, to: sr.lowerBound)
                let end = string.distance(from: string.startIndex, to: sr.upperBound)
                // 이미 lim_{…} 로 읽었으면 그대로
                if string[sr.upperBound...].hasPrefix("_") { continue }
                guard end <= line.charBoxes.count, start < chars.count, let first = line.charBoxes[start], let last = line.charBoxes[end - 1] else { continue }
                let word = CGRect(x: first.minX, y: line.box.minY, width: last.maxX - first.minX, height: line.box.height)
                var value: String?
                var regions: [CGRect] = []
                // 글자 인식이 이미 읽은 조각: 낱말 아래 가까이
                let near = CGRect(x: word.minX - word.width * 0.4, y: line.box.minY - lineHeight * 1.0, width: word.width * 1.8, height: lineHeight * 1.0 + line.box.height * 0.12)
                for p in all.filter({ $0.box.height <= lineHeight * 1.1 && $0.box.minX >= word.minX - word.width * 0.4 && $0.box.minX <= word.maxX
                    && $0.box.midY < word.midY && $0.box.midY >= near.minY && $0.box.maxY <= word.minY + word.height * 0.3 + lineHeight * 0.3 }).sorted(by: { $0.box.minX < $1.box.minX }) {
                    if value == nil { value = CalculusLayout.limitBelow(p.text); if value != nil { regions = [near] } }
                }
                // 못 읽었으면 낱말 아래 잉크 글자 묶음만 잘라 세 번 읽음
                if value == nil {
                    let lhPx = max(8, Int(lineHeight * CGFloat(ink.height)))
                    let wx0 = pixelX(ink, word.minX), wx1 = pixelX(ink, word.maxX)
                    let ww = max(1, wx1 - wx0)
                    let bottom = pixelY(ink, line.box.minY)
                    if let r = CalculusShape.inkRun(ink, x0: wx0 - Int(Double(ww) * 0.6), x1: wx1 + Int(Double(ww) * 0.6), y0: bottom - Int(Double(lhPx) * 0.15),
                                                    y1: bottom + Int(Double(lhPx) * 1.1), gap: max(3, Int(Double(lhPx) * 0.15)), near: (wx0 + wx1) / 2) {
                        let box = vision(ink, x0: r.x0 - 2, x1: r.x1 + 2, y0: r.y0 - 2, y1: r.y1 + 2)
                        value = await vote(box, read: read, parse: CalculusLayout.limitBelow)
                        if value != nil { regions = [box] }
                    }
                }
                guard let value else { continue }
                findings.append(CalculusLayout.Finding(kind: .limit, symbol: word, text: "lim_{\(value)}", regions: regions, strong: true, coverMaxX: word.maxX))
            }
        }
        return findings
    }
}
