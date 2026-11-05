import CoreGraphics
import Foundation
import Vision

/// 기본 판독 (모델 없이 Apple Vision + 픽셀 계산): 모티 1·모델 없는 기기에서도 그림을 조금은 읽음
/// - 표: 문서 읽기(RecognizeDocumentsRequest)가 찾은 표 칸
/// - 좌표 그래프: GraphReader가 맞춘 식과 절편·꼭짓점
/// - 도형: ShapeReader가 붙인 꼭짓점 이름·변 길이 (직각은 그림에서 90°에 아주 가까울 때만)
/// 앱(FigureReader)과 맥 확인 도구(Tests/FigureEval)가 같은 코드를 씀 (UIKit 없이)
enum FigureVision {
    /// 사진 속 표들 → 칸 (머리줄 포함, 두 줄·두 칸 이상만)
    static func tables(_ image: CGImage) async -> [[[String]]] {
        guard #available(iOS 26.0, macOS 26.0, *) else { return [] }
        let request = RecognizeDocumentsRequest()
        guard let observations = try? await request.perform(on: image) else { return [] }
        var out: [[[String]]] = []
        for observation in observations {
            for table in observation.document.tables {
                let rows = table.rows.map { row in
                    row.map { $0.content.text.transcript.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces) }
                }
                let width = rows.map(\.count).max() ?? 0
                if rows.count >= 2, width >= 2 { out.append(rows.map { $0 + Array(repeating: "", count: width - $0.count) }) }
            }
        }
        return out
    }

    // MARK: 그림 속 글자 (꼭짓점 이름·길이·각·좌표)

    /// Vision 글자 읽기 → 낱말마다 픽셀 상자 (위가 0)
    static func textLabels(_ image: CGImage, correction: Bool = false) async -> [TextLabel] {
        let observations: [VNRecognizedTextObservation] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = correction
                request.recognitionLanguages = ["ko-KR", "en-US"]
                try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
                continuation.resume(returning: request.results ?? [])
            }
        }
        return words(observations, width: Double(image.width), height: Double(image.height))
    }

    static func words(_ observations: [VNRecognizedTextObservation], width W: Double, height H: Double) -> [TextLabel] {
        func pixel(_ r: CGRect) -> VRect { VRect(x: Double(r.minX) * W, y: (1 - Double(r.maxY)) * H, w: Double(r.width) * W, h: Double(r.height) * H) }
        var labels: [TextLabel] = []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let s = candidate.string
            var index = s.startIndex
            var found: [TextLabel] = []
            while index < s.endIndex {
                guard let start = s[index...].firstIndex(where: { !$0.isWhitespace }) else { break }
                let end = s[start...].firstIndex(where: { $0.isWhitespace }) ?? s.endIndex
                if let box = try? candidate.boundingBox(for: start..<end)?.boundingBox {
                    found.append(TextLabel(text: String(s[start..<end]), box: pixel(box)))
                }
                index = end
            }
            if found.count > 1 { labels += found } else { labels.append(TextLabel(text: s, box: pixel(observation.boundingBox))) }
        }
        return labels
    }

    /// 글자 읽기가 놓친 그림 속 작은 글자 (따로 선 "A", "7", "50°", "(2, 5)")를 찾아 다시 읽음.
    /// Vision은 그림 옆에 홀로 놓인 한두 글자를 자주 건너뜀 → 글자만 한 덩어리 크기의 잉크 묶음을 잘라
    /// 넓게 띄워 한 장(읽기 종이)에 늘어놓고 한 번에 읽은 뒤, 글자마다 원래 자리로 되돌림
    static func missingLabels(_ image: CGImage, pixels: PixelImage, known: [TextLabel]) async -> [TextLabel] {
        let w = pixels.width, h = pixels.height
        guard w >= 40, h >= 40, w == image.width, h == image.height else { return [] }
        var mask = [Bool](repeating: false, count: w * h)
        for i in 0..<(w * h) where pixels.gray[i] < 150 { mask[i] = true }
        let known = known.map { $0.box.insetBy(-2) }
        let maxH = Double(h) * 0.09, minH = max(7, Double(min(w, h)) * 0.012)
        // 글자 크기 잉크 덩어리
        var pieces: [VRect] = []
        for comp in VisionMath.components(mask, width: w, height: h, minSize: 6) {
            var x0 = w, y0 = h, x1 = 0, y1 = 0
            for i in comp { let x = i % w, y = i / w; x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y) }
            let box = VRect(x: Double(x0), y: Double(y0), w: Double(x1 - x0 + 1), h: Double(y1 - y0 + 1))
            guard box.h <= maxH, box.w <= maxH * 1.6 else { continue }
            if known.contains(where: { $0.contains(box.midX, box.midY) }) { continue }
            // 꽉 찬 동그라미(점 표시)는 글자가 아님
            let fill = Double(comp.count) / (box.w * box.h)
            if fill > 0.68, box.w > 6, abs(box.w - box.h) < max(box.w, box.h) * 0.25 { continue }
            pieces.append(box)
        }
        guard !pieces.isEmpty else { return [] }
        // 가까운 조각끼리 한 묶음 ("50°", "(2, 5)", "10")
        let glyph = median(pieces.filter { $0.h >= minH }.map(\.h)) ?? minH
        var clusters: [VRect] = []
        for piece in pieces.sorted(by: { $0.minX < $1.minX }) {
            if let k = clusters.lastIndex(where: { c in
                let gap = piece.minX - c.maxX
                let overlap = min(c.maxY, piece.maxY) - max(c.minY, piece.minY)
                return gap < glyph * 0.7 && gap > -glyph && (overlap > -glyph * 0.15 || piece.h < glyph * 0.5 && abs(piece.midY - c.midY) < glyph)
            }) {
                let c = clusters[k]
                clusters[k] = VRect(x: min(c.minX, piece.minX), y: min(c.minY, piece.minY), w: max(c.maxX, piece.maxX) - min(c.minX, piece.minX),
                                    h: max(c.maxY, piece.maxY) - min(c.minY, piece.minY))
            } else {
                clusters.append(piece)
            }
        }
        clusters = clusters.filter { $0.h >= minH && $0.h <= maxH && $0.w <= glyph * 8 }
        guard !clusters.isEmpty else { return [] }
        clusters = Array(clusters.prefix(36))

        // 읽기 종이: 글자 높이 56픽셀, 한 줄에 6묶음, 사이를 넓게
        let slotH = 56.0, gap = 70.0, margin = 60.0, perRow = 6
        let scale = slotH / max(glyph, 1)
        var slots: [(rect: VRect, cluster: Int)] = []
        var x = margin, row = 0, maxX = 0.0
        for (k, c) in clusters.enumerated() {
            if k > 0, k % perRow == 0 { row += 1; x = margin }
            let sw = (c.w + 6) * scale, sh = (c.h + 6) * scale
            let top = margin + Double(row) * (slotH * 2.2) + (slotH * 1.2 - sh) / 2
            slots.append((VRect(x: x, y: top, w: sw, h: sh), k))
            x += sw + gap
            maxX = max(maxX, x)
        }
        let sheetW = Int(maxX + margin), sheetH = Int(margin * 2 + Double(row + 1) * slotH * 2.2)
        guard sheetW > 0, sheetH > 0,
              let sheet = CGContext(data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return [] }
        sheet.interpolationQuality = .high
        sheet.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        sheet.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
        for slot in slots {
            let c = clusters[slot.cluster]
            let crop = CGRect(x: c.minX - 3, y: c.minY - 3, width: c.w + 6, height: c.h + 6).integral
                .intersection(CGRect(x: 0, y: 0, width: w, height: h))
            guard !crop.isNull, let piece = image.cropping(to: crop) else { continue }
            // CGContext는 아래가 0
            sheet.draw(piece, in: CGRect(x: slot.rect.minX, y: Double(sheetH) - slot.rect.maxY, width: slot.rect.w, height: slot.rect.h))
        }
        guard let sheetImage = sheet.makeImage() else { return [] }
        let observations: [VNRecognizedTextObservation] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["en-US"]
                request.minimumTextHeight = 0
                try? VNImageRequestHandler(cgImage: sheetImage, options: [:]).perform([request])
                continuation.resume(returning: request.results ?? [])
            }
        }
        var texts = [String](repeating: "", count: clusters.count)
        let SW = Double(sheetW), SH = Double(sheetH)
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let s = candidate.string
            var index = s.startIndex
            while index < s.endIndex {
                let next = s.index(after: index)
                defer { index = next }
                guard !s[index].isWhitespace, let box = (try? candidate.boundingBox(for: index..<next))?.boundingBox else { continue }
                let cx = Double(box.midX) * SW, cy = (1 - Double(box.midY)) * SH
                guard let slot = slots.first(where: { $0.rect.insetBy(-gap * 0.35).contains(cx, cy) }) else { continue }
                texts[slot.cluster].append(s[index])
            }
        }
        return clusters.indices.compactMap { k in
            let t = DoitFigureFacts.cleanedLabel(texts[k])
            return t.isEmpty ? nil : TextLabel(text: t, box: clusters[k])
        }
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        return s[s.count / 2]
    }

    // MARK: 좌표 그래프: 그림에 적힌 값

    /// 좌표 그래프 사실: 그림에 적힌 절편·꼭짓점·좌표(정확한 값)로 식이 정해지면 그것만,
    /// 아니면 픽셀로 맞춘 식 + 적힌 값 (problem: 문제 글, 포물선인지 보는 데 씀)
    static func graphFacts(_ labels: [TextLabel], pixels: PixelImage?, graph: GraphAnalysis?, problem: String) -> [String] {
        let points = pointLines(labels.map(\.text).joined(separator: " "))
        let marked = pixels.map { axisLines(labels, pixels: $0, problem: problem) } ?? []
        var exact = marked
        for line in points where !exact.contains(line) { exact.append(line) }
        if !exact.isEmpty, DoitFigureFacts.graphEquation(exact, hint: problem) != nil { return exact }
        let pixelLines = graph.map(graphLines) ?? []
        // 적힌 값이 모자라면 그래프 판독의 절편·꼭짓점(정수·0.5 단위로 맞춘 것)을 더해 보고,
        // 그 식이 판독한 곡선과 거의 같을 때만 씀 (적힌 값과 그림이 서로 맞는지 확인)
        if let graph, !exact.isEmpty {
            var merged = exact
            for line in pixelLines.dropFirst() where !merged.contains(where: { same($0, line) }) { merged.append(line) }
            if let eq = DoitFigureFacts.graphEquation(merged, hint: problem), agrees(eq, graph) { return merged }
        }
        return pixelLines + exact
    }

    /// 같은 사실 줄인지 ("y절편 −3" = "y절편 -3")
    private static func same(_ a: String, _ b: String) -> Bool {
        let na = a.replacingOccurrences(of: "−", with: "-"), nb = b.replacingOccurrences(of: "−", with: "-")
        if na == nb { return true }
        // 꼭짓점은 하나뿐
        return na.hasPrefix("꼭짓점") && nb.hasPrefix("꼭짓점")
    }

    /// 식 글(y = x² - 2x - 3)의 계수가 판독한 곡선 계수와 가까운지
    private static func agrees(_ equation: String, _ graph: GraphAnalysis) -> Bool {
        guard graph.calibrated, graph.coefficients.count >= 2 else { return false }
        let t = equation.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "y=", with: "")
        var coef = [0.0, 0.0, 0.0]
        for m in t.matches(of: #/([+-]?)(\(?\d*(?:\.\d+)?(?:/\d+)?\)?)(x²|x)?/#) where !m.0.isEmpty {
            var body = String(m.2).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            if body.isEmpty { body = "1" }
            let parts = body.split(separator: "/")
            guard let first = Double(parts[0]) else { continue }
            var v = parts.count == 2 ? first / (Double(parts[1]) ?? 1) : first
            if m.1 == "-" { v = -v }
            let k = m.3 == "x²" ? 2 : (m.3 == "x" ? 1 : 0)
            coef[k] += v
        }
        let fitted = graph.coefficients + [0, 0, 0]
        let scale = max(1, coef.map(abs).max() ?? 1)
        return (0..<3).allSatisfy { abs(coef[$0] - fitted[$0]) <= max(0.35, scale * 0.15) }
    }

    /// 축 옆에 적힌 숫자 중 그래프가 그 자리에서 축과 만나는 것 → "x절편 3", "y절편 6"
    /// 포물선이면 적힌 좌표 중 꼭짓점 자리에 있는 것 → "꼭짓점 (1, -2)"
    static func axisLines(_ labels: [TextLabel], pixels: PixelImage, problem: String) -> [String] {
        guard let axes = GraphReader.findAxes(pixels) else { return [] }
        let curve = GraphReader.curvePixels(pixels, axes: axes, labels: labels).points
        guard curve.count >= 12 else { return [] }
        let ox = axes.yAxisX, oy = axes.xAxisY
        var lines: [String] = []
        func add(_ line: String) { if !lines.contains(line) { lines.append(line) } }
        for label in labels {
            // 홀로 선 "1"을 l·I·|로 읽는 일이 많음 (축 옆 숫자만)
            let digits = ["l": "1", "I": "1", "|": "1", "O": "0", "o": "0"][label.text] ?? label.text
            guard let value = TextLabel(text: digits, box: label.box).number, value != 0 else { continue }
            let nearX = abs(label.box.midY - oy) < max(label.box.h * 2.2, 14) + axes.xAxisHalf
            let nearY = abs(label.box.midX - ox) < max(label.box.w * 1.6, 14) + axes.yAxisHalf + label.box.w / 2
            if nearX && !(nearY && abs(label.box.midX - ox) < label.box.w) {
                // 그래프가 숫자 바로 옆에서 x축을 지나는지 (축 위아래에 모두 점이 있음)
                let reach = label.box.w + 22, band = max(label.box.h * 3, 30)
                let near = curve.filter { abs($0.x - label.box.midX) < reach && abs($0.y - oy) < band }
                if near.contains(where: { $0.y < oy - 2 }) && near.contains(where: { $0.y > oy + 2 }) { add("x절편 \(VisionMath.format(value))") }
            } else if nearY {
                let reach = max(label.box.h, 12) + 16, band = max(label.box.w * 3, 34)
                let near = curve.filter { abs($0.y - label.box.midY) < reach && abs($0.x - ox) < band }
                if near.contains(where: { $0.x < ox - 2 }) && near.contains(where: { $0.x > ox + 2 }) { add("y절편 \(VisionMath.format(value))") }
            }
        }
        // 포물선 꼭짓점: 곡선을 이차식으로 맞춘 꼭짓점 가까이에 적힌 좌표
        let t = problem.replacingOccurrences(of: " ", with: "")
        if t.contains("이차함수") || t.contains("포물선"), let c = VisionMath.polyfit(curve, degree: 2), abs(c[2]) > 1e-9 {
            let vx = -c[1] / (2 * c[2]), vy = VisionMath.evaluate(c, vx)
            let text = DoitFigureFacts.normalizedPoints(labels.map(\.text).joined(separator: " "))
            var best: (String, Double)?
            for m in text.matches(of: #/\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)/#) {
                // 그 좌표 글자가 있는 자리 (여는 괄호 낱말)
                let head = "(" + String(m.1)
                guard let label = labels.first(where: { DoitFigureFacts.normalizedPoints($0.text).replacingOccurrences(of: " ", with: "").hasPrefix(head) }) else { continue }
                let d = hypot(label.box.midX - vx, label.box.midY - vy)
                if d < Double(max(pixels.width, pixels.height)) * 0.16, d < (best?.1 ?? .infinity) { best = ("꼭짓점 (\(m.1), \(m.2))", d) }
            }
            if let best { add(best.0) }
        }
        return lines
    }

    /// 차트 판독 (글자 위치 + 막대 높이) → "[막대그래프] 1월 30, 2월 45" 한 줄
    static func chartLines(_ labels: [TextLabel], image: PixelImage?, kind: DoitFigureFacts.ChartKind) -> [String] {
        let items = ChartReader.read(labels, image: image)
        guard items.count >= 2 else { return [] }
        let isPie = labels.filter { $0.text.hasSuffix("%") }.count >= 2
        let shown = isPie ? DoitFigureFacts.ChartKind.pie : (kind == .table ? .bar : kind)
        return ["[\(shown.rawValue)] " + items.map { "\($0.label) \(VisionMath.format($0.value))\(isPie ? "%" : "")" }.joined(separator: ", ")]
    }

    /// 그래프 판독 → 줄 (눈금이나 적힌 숫자로 좌표를 맞춘 직선·포물선만)
    static func graphLines(_ graph: GraphAnalysis) -> [String] {
        guard graph.calibrated, graph.kind == .linear || graph.kind == .quadratic, let equation = graph.equation else { return [] }
        var lines = ["그래프의 식은 " + equation.replacingOccurrences(of: "−", with: "-")]
        // 픽셀에서 잰 값이라 정수·0.5 단위로 맞춰 보여 줌 (식과 같은 다듬기)
        func shown(_ v: Double) -> String { VisionMath.format(VisionMath.nice(v)).replacingOccurrences(of: "−", with: "-") }
        for point in graph.keyPoints {
            switch point.name {
            case "y절편": lines.append("y절편 \(shown(point.y))")
            case "x절편": lines.append("x절편 \(shown(point.x))")
            case "꼭짓점": lines.append("꼭짓점 (\(shown(point.x)), \(shown(point.y)))")
            default: continue
            }
        }
        return lines
    }

    /// 그림에 적힌 좌표 "(0, 1)", "(2, 5)" → "지나는 점 …" 한 줄 (식은 확인한 뒤 풀이가 이 점들로 구함)
    static func pointLines(_ text: String) -> [String] {
        let normalized = DoitFigureFacts.normalizedPoints(text)
        var points: [String] = []
        for m in normalized.matches(of: #/\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)/#) {
            let p = "(\(m.1), \(m.2))"
            if !points.contains(p) { points.append(p) }
        }
        return points.count >= 1 ? ["지나는 점 " + points.joined(separator: ", ")] : []
    }

    /// 문제 글에 적힌 꼭짓점 이름(△ABC, 삼각형 ABC, 사각형 ABCD) 중 그림에서 하나만 못 읽었으면 남은 이름으로
    /// (나머지 이름이 모두 그 이름들 안에 있을 때만, 순서는 그림의 둘레 방향과 무관하게 남은 하나만 채움)
    static func fillVertexName(_ shape: inout ShapeAnalysis, problem: String) {
        let n = shape.vertices.count
        guard n == 3 || n == 4, shape.vertexNames.count == n - 1 else { return }
        let pattern = n == 3 ? #"(?:△|삼각형\s*)([A-Z]{3})(?![A-Za-z])"# : #"(?:□|사각형\s*|사다리꼴\s*|평행사변형\s*|직사각형\s*|정사각형\s*|마름모\s*)([A-Z]{4})(?![A-Za-z])"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: problem, range: NSRange(problem.startIndex..., in: problem)),
              let r = Range(m.range(at: 1), in: problem) else { return }
        let names = problem[r].map(String.init)
        let known = Set(shape.vertexNames.values)
        guard known.isSubset(of: Set(names)), Set(names).count == n else { return }
        let missing = names.filter { !known.contains($0) }
        guard missing.count == 1, let slot = (0..<n).first(where: { shape.vertexNames[$0] == nil }) else { return }
        shape.vertexNames[slot] = missing[0]
    }

    /// 도형 판독 → 줄 (꼭짓점 이름이 붙은 삼각형의 변 길이, 원의 반지름)
    /// problem: 문제 글 ("삼각형 ABC"에서 못 읽은 꼭짓점 이름 하나를 채우고, 각을 묻는지 봄)
    static func shapeLines(_ shapes: [ShapeAnalysis], problem: String = "") -> [String] {
        var lines: [String] = []
        let asksAngle = problem.contains("∠") || problem.contains("각") || problem.contains("°")
        for var shape in shapes.prefix(2) {
            fillVertexName(&shape, problem: problem)
            if asksAngle { for (i, v) in shape.innerNumbers where shape.angleLabels[i] == nil && v < 180 { shape.angleLabels[i] = v } }
            let n = shape.vertices.count
            if shape.kind == .circle {
                if let r = shape.sideLabels[0] { lines.append("원의 반지름 = \(VisionMath.format(r))") }
                continue
            }
            guard n >= 3, n <= 4 else { continue }
            let names = (0..<n).compactMap { shape.vertexNames[$0] }
            if names.count == n, n == 3 { lines.append("△" + names.sorted().joined()) }
            if names.count == n, n == 4 { lines.append("사각형 " + names.joined()) }
            for i in 0..<n {
                guard let value = shape.sideLabels[i], let a = shape.vertexNames[i], let b = shape.vertexNames[(i + 1) % n] else { continue }
                lines.append(GeometryText.segment(String([a, b].sorted().joined())) + " = " + VisionMath.format(value))
            }
            if n == 3 {
                // 직각: 그림의 직각 표시, 또는 90°에 아주 가까울 때
                for i in 0..<3 where abs(shape.angles[i] - 90) < 2 || shape.rightAngles.contains(i) {
                    if let name = shape.vertexNames[i] { lines.append("∠\(name) = 90°") }
                }
            } else {
                for i in shape.rightAngles.sorted() { if let name = shape.vertexNames[i] { lines.append("∠\(name) = 90°") } }
            }
            // 꼭짓점 안쪽에 적힌 각
            for (i, value) in shape.angleLabels.sorted(by: { $0.key < $1.key }) {
                guard let name = shape.vertexNames[i] else { continue }
                lines.append("∠\(name) = \(VisionMath.format(value))°")
            }
        }
        var seen = Set<String>()
        return lines.filter { seen.insert($0).inserted }
    }
}
