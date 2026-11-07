import Foundation

/// 미적분 기호 찾기: 사진 속 큰 기호(∑ ∫)와 글자 lim 을 찾고, 위끝·아래끝은 따로 읽힌 조각이나 자른 사진 읽기로 채움.
/// 사진 자르기 읽기(read)는 호출하는 쪽(OCRCore)이 넣어 줌 → 이 파일은 Foundation만 써서 리눅스에서 시험 가능
enum CalculusFind {
    /// read: Vision 좌표(0~1, 왼쪽 아래 원점) 사각형을 잘라 키워서 읽은 글 (못 읽으면 nil)
    typealias Reader = (CGRect) async -> String?

    /// 픽셀(위가 0) 사각형 → Vision 좌표
    private static func vision(_ ink: FractionFinder.Ink, x0: Int, x1: Int, y0: Int, y1: Int) -> CGRect {
        let w = CGFloat(ink.width), h = CGFloat(ink.height)
        let ax = CGFloat(max(0, x0)), bx = CGFloat(min(ink.width, x1 + 1))
        let ay = CGFloat(max(0, y0)), by = CGFloat(min(ink.height, y1 + 1))
        return CGRect(x: ax / w, y: 1 - by / h, width: max(0, bx - ax) / w, height: max(0, by - ay) / h)
    }

    /// 지정한 자리 안에 따로 읽힌 작은 조각들의 글 (글자 인식이 이미 읽은 것)
    private static func pieces(in region: CGRect, from lines: [OCRGlyphLine], lineHeight: CGFloat) -> [String] {
        lines.filter { l in
            let b = l.box
            return b.height <= lineHeight * 1.1 && l.text.count <= 10
                && region.insetBy(dx: -region.width * 0.05, dy: -region.height * 0.05).contains(CGPoint(x: b.midX, y: b.midY))
        }.sorted { $0.box.minX < $1.box.minX }.map(\.text)
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
                let x0 = b.x0 - Int(Double(w) * 0.6), x1 = b.x1 + Int(Double(w) * 0.6)
                let belowPx = (x0: x0, x1: x1, y0: b.y1 + 1, y1: b.y1 + Int(Double(h) * 0.9))
                let abovePx = (x0: x0, x1: x1, y0: b.y0 - Int(Double(h) * 0.9), y1: b.y0 - 1)
                let belowBox = vision(ink, x0: belowPx.x0, x1: belowPx.x1, y0: belowPx.y0, y1: belowPx.y1)
                let aboveBox = vision(ink, x0: abovePx.x0, x1: abovePx.x1, y0: abovePx.y0, y1: abovePx.y1)
                var regions: [CGRect] = []
                var below: String?, above: String?
                if CalculusShape.inkCount(ink, x0: belowPx.x0, x1: belowPx.x1, y0: belowPx.y0, y1: belowPx.y1) >= 6 {
                    regions.append(belowBox)
                    for text in pieces(in: belowBox, from: all, lineHeight: lineHeight) { if below == nil { below = CalculusLayout.sigmaBelow(text) } }
                    if below == nil, let text = await read(belowBox) { below = CalculusLayout.sigmaBelow(text) }
                }
                if CalculusShape.inkCount(ink, x0: abovePx.x0, x1: abovePx.x1, y0: abovePx.y0, y1: abovePx.y1) >= 6 {
                    regions.append(aboveBox)
                    for text in pieces(in: aboveBox, from: all, lineHeight: lineHeight) { if above == nil { above = CalculusLayout.bound(text) } }
                    if above == nil, let text = await read(aboveBox) { above = CalculusLayout.bound(text) }
                }
                var text = "∑"
                if let below { text += CalculusLayout.script("_", below) }
                if let above { text += CalculusLayout.script("^", above) }
                // 위·아래끝 자리의 잉크가 있는데 읽지 못한 쪽이 있으면 부분만 붙이면 틀린 식이 됨 → 글자는 그대로 두고 따로 읽힌 조각만 남김
                let hasInkBelow = regions.contains(belowBox), hasInkAbove = regions.contains(aboveBox)
                if (hasInkBelow && below == nil) || (hasInkAbove && above == nil) { text = "∑" ; regions = [] }
                let symbol = vision(ink, x0: b.x0, x1: b.x1, y0: b.y0, y1: b.y1)
                findings.append(CalculusLayout.Finding(kind: .sigma, symbol: symbol, text: text, regions: regions,
                                                      strong: below != nil && !regions.isEmpty, coverMaxX: symbol.maxX))
            case .integral:
                let c = Int(shape.centerX.rounded())
                let hd = Double(h)
                // 위끝: 기호 오른쪽 위, 아래끝: 오른쪽 아래 (고리 끝이 일부 들어옴)
                let right = max(c + Int(hd * 0.7), b.x1 + Int(hd * 0.1))
                let upperPx = (x0: c - Int(hd * 0.12), x1: right, y0: b.y0 - Int(hd * 0.08), y1: b.y0 + Int(hd * 0.42))
                let lowerPx = (x0: c - Int(hd * 0.12), x1: right, y0: b.y1 - Int(hd * 0.42), y1: b.y1 + Int(hd * 0.08))
                let upperBox = vision(ink, x0: upperPx.x0, x1: upperPx.x1, y0: upperPx.y0, y1: upperPx.y1)
                let lowerBox = vision(ink, x0: lowerPx.x0, x1: lowerPx.x1, y0: lowerPx.y0, y1: lowerPx.y1)
                var upper: String?, lower: String?
                if let t = await read(upperBox) { upper = CalculusLayout.integralBound(t) }
                if let t = await read(lowerBox) { lower = CalculusLayout.integralBound(t) }
                // 위·아래끝이 둘 다 읽혔을 때만 붙임 (하나만 읽으면 ∫ 만)
                let symbol = vision(ink, x0: b.x0, x1: b.x1, y0: b.y0, y1: b.y1)
                if let upper, let lower {
                    findings.append(CalculusLayout.Finding(kind: .integral, symbol: symbol, text: "∫" + CalculusLayout.script("_", lower) + CalculusLayout.script("^", upper),
                                                          regions: [upperBox, lowerBox], strong: true, coverMaxX: vision(ink, x0: right, x1: right, y0: b.y0, y1: b.y1).maxX))
                } else {
                    findings.append(CalculusLayout.Finding(kind: .integral, symbol: symbol, text: "∫", regions: [], strong: false,
                                                          coverMaxX: vision(ink, x0: b.x1, x1: b.x1, y0: b.y0, y1: b.y1).maxX))
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
                // lim 아래 자리: 낱말 가로 범위, 줄 아래쪽에서 한 줄 높이만큼 아래
                let below = CGRect(x: word.minX - word.width * 0.2, y: line.box.minY - lineHeight * 1.0, width: word.width * 1.4, height: lineHeight * 1.0 + line.box.height * 0.12)
                var value: String?
                for p in all.filter({ $0.box.height <= lineHeight * 1.1 && $0.box.minX >= word.minX - word.width * 0.4 && $0.box.minX <= word.maxX
                    && $0.box.midY < word.midY && $0.box.midY >= below.minY && $0.box.maxY <= word.minY + word.height * 0.3 + lineHeight * 0.3 }).sorted(by: { $0.box.minX < $1.box.minX }) {
                    if value == nil { value = CalculusLayout.limitBelow(p.text) }
                }
                if value == nil, let text = await read(below) { value = CalculusLayout.limitBelow(text) }
                guard let value else { continue }
                findings.append(CalculusLayout.Finding(kind: .limit, symbol: word, text: "lim_{\(value)}", regions: [below], strong: true, coverMaxX: word.maxX))
            }
        }
        return findings
    }
}
