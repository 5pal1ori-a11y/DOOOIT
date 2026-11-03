import CoreGraphics
import CoreImage
import Foundation
import Vision

/// Vision 프레임워크로 사진 속 글자를 읽어옴 (기기 내에서 처리, 인터넷 불필요)
/// 글자 인식의 몸통: UIKit 없이 CGImage와 Vision 결과만 다룸. 글자만 다루는 정리 단계는 OCRText.swift.
/// 앱은 OCRService.swift의 UIImage 함수로 부르고, 맥 사진 테스트(Tests/OCRImages)는 이 파일을 그대로 컴파일해서 씀
enum OCRService {
    /// 글자 인식 요청 (최신 인식 모델 · 작은 글씨까지)
    static func makeRequest(languages: [String], correction: Bool, minimumTextHeight: Float = 0.006) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = correction
        request.recognitionLanguages = languages
        request.automaticallyDetectsLanguage = false
        // 사진 높이의 0.6%보다 큰 글씨는 모두 읽음 (작은 단어장 글씨·지수까지)
        request.minimumTextHeight = minimumTextHeight
        return request
    }

    // MARK: 사진 크기 맞추기

    /// 긴 변이 maxDimension보다 크면 줄임 (작으면 그대로)
    static func scaled(_ image: CGImage, maxDimension: CGFloat) -> CGImage {
        let longest = CGFloat(max(image.width, image.height))
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        return resampled(image, width: Int((CGFloat(image.width) * scale).rounded()), height: Int((CGFloat(image.height) * scale).rounded())) ?? image
    }

    /// 정해진 크기로 다시 그림 (sRGB, 불투명)
    static func resampled(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    // MARK: 기본 읽기

    static func recognize(_ image: CGImage, languageCorrection: Bool = true,
                          languages: [String] = ["ko-KR", "en-US"], preferMath: Bool = false) async throws -> [OCRLine] {
        let cgImage = scaled(image, maxDimension: 2400)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = makeRequest(languages: languages, correction: languageCorrection)
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let lines: [OCRLine] = observations.compactMap { observation in
                        let candidates = observation.topCandidates(preferMath ? 3 : 1)
                        guard let best = candidates.first else { return nil }
                        // 수학 문제: 신뢰도가 비슷하면 숫자 자리에 글자(Z, O, l, S)가 덜 섞인 후보를 고름
                        var chosen = best
                        if preferMath {
                            chosen = candidates.filter { $0.confidence >= best.confidence - 0.15 }
                                .min { mathPenalty($0.string) < mathPenalty($1.string) } ?? best
                        }
                        return OCRLine(text: chosen.string, confidence: adjustedConfidence(chosen.string, max(chosen.confidence, best.confidence * 0.9)), box: observation.boundingBox)
                    }
                    continuation.resume(returning: lines)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 수학 문제용: 검은 인쇄 글자만 남긴 사진(빨간 펜·파란 펜·연필 풀이 제거, 작은 지수가 보이게 확대)으로 읽음
    static func recognizeMath(_ image: CGImage) async throws -> [OCRLine] {
        let original = await mathReadDetailed(image)
        guard let ink = inkOnly(image) else { return original.lines }
        // 분수 막대는 원래 사진에서 찾은 것을 그대로 씀 (검은 글자만 남기면 가는 막대가 끊어지기도 해서)
        let inkLines = await mathReadDetailed(ink, fractions: original.fractions).lines
        return chooseInkReading(original: original.lines, ink: inkLines)
    }

    // MARK: 수식 두 번 읽기 (한국어+영어 / 영어 전용)

    /// 한국어 인식은 한글 문장을 잘 읽지만 기울어진 수식 글자(a, b, x, 지수)를 숫자로 착각하기 쉬움.
    /// 영어 전용 인식은 수식을 더 잘 읽음 → 줄마다 글자 위치를 맞춰서 수식 부분만 영어 전용 결과로 바꿈
    static func mathRead(_ image: CGImage) async -> [OCRLine] {
        await mathReadDetailed(image).lines
    }

    /// fractions: 같은 사진(크기만 다를 수 있음)에서 이미 찾은 분수 (없으면 이 사진에서 찾음)
    static func mathReadDetailed(_ image: CGImage, fractions known: [BarFraction]? = nil) async -> (lines: [OCRLine], fractions: [BarFraction]) {
        let cgImage = scaled(image, maxDimension: 3000)
        // 두 번 읽기를 동시에 (기다리는 시간 절반)
        async let koreanRead = try? observe(cgImage, languages: ["ko-KR", "en-US"], correction: true)
        async let englishRead = try? observe(cgImage, languages: ["en-US"], correction: false)
        // 빈칸 네모 상자 (글자 인식은 빈 네모를 아예 안 읽는 경우가 많아서 따로 찾음)
        async let boxRead = detectRectangles(cgImage)
        // 보기 번호 동그라미 ①~⑤ (글자 인식이 못 읽거나 "1", "@", "(D"로 읽는 경우가 많아서 모양으로 찾음)
        async let circleRead = detectCircles(cgImage)
        guard let korean = await koreanRead else { return ([], known ?? []) }
        // 쌓은 분수: 막대를 픽셀에서 찾고 분자·분모를 따로 읽음 (글자 인식은 작은 분수를 "늘", "⅔"처럼 한 글자로 읽음)
        let page = grayPage(cgImage, lines: korean.map(\.boundingBox))
        var barFractions = known ?? []
        if known == nil { barFractions = await stackedFractions(cgImage, page: page, lines: korean.map(\.boundingBox)) }
        let english = await englishRead ?? []
        let rects = await boxRead
        let circles = await circleRead
        let lines = merge(korean: korean, english: english, rects: rects, circles: circles, barFractions: barFractions,
                          ink: page.map { FractionFinder.Ink(mask: FractionFinder.inkMask(gray: $0.gray, width: $0.width, height: $0.height), width: $0.width, height: $0.height) })
        return (lines, barFractions)
    }

    /// 글자 크기가 40픽셀쯤 되게 줄인 흑백 사진 (분수 막대·지수 위치를 픽셀로 볼 때)
    struct GrayPage {
        var gray: [UInt8]
        var width: Int
        var height: Int
        /// 원래 사진 → 줄인 사진 배율
        var scale: Double
        /// 줄인 사진에서 글자 크기 짐작 (픽셀)
        var size: Double
    }

    static func grayPage(_ cgImage: CGImage, lines: [CGRect]) -> GrayPage? {
        let heights = lines.map { Double($0.height) * Double(cgImage.height) }.sorted()
        guard !heights.isEmpty else { return nil }
        let size = heights[heights.count / 4]
        guard size >= 8 else { return nil }
        let scale = min(1.0, 40.0 / size)
        let w = max(1, Int(Double(cgImage.width) * scale)), h = max(1, Int(Double(cgImage.height) * scale))
        var gray = [UInt8](repeating: 255, count: w * h)
        let drawn: Bool = gray.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .high
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: w, height: h))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return drawn ? GrayPage(gray: gray, width: w, height: h, scale: scale, size: size * scale) : nil
    }

    // MARK: 쌓은 분수 (막대 찾기 + 분자·분모 따로 읽기)

    /// 사진에서 찾아 읽은 분수 하나 (box: Vision 좌표, 분자·분모를 합친 영역)
    struct BarFraction {
        var box: CGRect
        var text: String
    }

    /// note: 원인 찾기용 기록 (사진 테스트에서만 씀)
    static func stackedFractions(_ cgImage: CGImage, page: GrayPage?, lines: [CGRect], note: ((String) -> Void)? = nil) async -> [BarFraction] {
        guard let page else { return [] }
        let fullWidth = cgImage.width, fullHeight = cgImage.height
        let w = page.width, h = page.height, scale = page.scale
        let pixelLines = lines.map { (x: Double($0.minX) * Double(w), y: (1 - Double($0.maxY)) * Double(h),
                                      width: Double($0.width) * Double(w), height: Double($0.height) * Double(h)) }
        let bars = FractionFinder.bars(gray: page.gray, width: w, height: h, size: page.size, lines: pixelLines)
        note?("막대 \(bars.count)개 (글자 크기 \(Int(page.size))px, 배율 \(String(format: "%.2f", scale)))")
        guard !bars.isEmpty, bars.count <= 24 else { return [] }

        // 분자·분모를 원래 사진에서 잘라 "분자 / 분모"로 한 줄에 놓은 "읽기 종이"를 만들어 한 번에 읽음
        // (숫자 하나만 따로 두면 글자 인식이 못 읽는 일이 많아서, 사이에 빗금을 그려 "3/4" 같은 한 덩어리로)
        let pieceHeight = 64.0, gap = 72.0, margin = 96.0, slash = pieceHeight * 0.55, space = pieceHeight * 0.18
        func crop(_ part: (x: Int, y: Int, width: Int, height: Int), numerator: Bool) -> CGImage? {
            // 막대 쪽으로는 넓히지 않음 (막대가 "-"로 읽히지 않게)
            let pad = 2.0
            let top = Double(part.y) - (numerator ? pad : 0), bottom = Double(part.y + part.height) + (numerator ? 0 : pad)
            let rect = CGRect(x: (Double(part.x) - pad) / scale, y: top / scale,
                              width: (Double(part.width) + pad * 2) / scale, height: (bottom - top) / scale)
                .integral.intersection(CGRect(x: 0, y: 0, width: fullWidth, height: fullHeight))
            return rect.isNull || rect.width < 2 || rect.height < 2 ? nil : cgImage.cropping(to: rect)
        }
        func scaledWidth(_ piece: CGImage?) -> Double {
            guard let piece else { return 0 }
            return Double(piece.width) * pieceHeight / Double(max(1, piece.height))
        }
        let rows = bars.map { (numerator: crop($0.numerator, numerator: true), denominator: crop($0.denominator, numerator: false)) }
        let rowWidths = rows.map { scaledWidth($0.numerator) + scaledWidth($0.denominator) + slash + space * 2 }
        let sheetWidth = Int((rowWidths.max() ?? 0) + margin * 2)
        let sheetHeight = Int(Double(rows.count) * (pieceHeight + gap) + gap)
        guard sheetWidth > 0, sheetHeight > 0,
              let sheet = CGContext(data: nil, width: sheetWidth, height: sheetHeight, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return [] }
        sheet.interpolationQuality = .high
        sheet.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        sheet.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))
        sheet.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1)
        sheet.setLineWidth(pieceHeight / 11)
        var rowCenters: [Double] = []   // Vision 좌표 (아래가 0)
        for (k, row) in rows.enumerated() {
            let top = gap + Double(k) * (pieceHeight + gap)
            let y = Double(sheetHeight) - top - pieceHeight
            rowCenters.append(1 - (top + pieceHeight / 2) / Double(sheetHeight))
            var x = margin
            if let n = row.numerator { sheet.draw(n, in: CGRect(x: x, y: y, width: scaledWidth(n), height: pieceHeight)) }
            x += scaledWidth(row.numerator) + space
            sheet.move(to: CGPoint(x: x, y: y))
            sheet.addLine(to: CGPoint(x: x + slash, y: y + pieceHeight))
            sheet.strokePath()
            x += slash + space
            if let d = row.denominator { sheet.draw(d, in: CGRect(x: x, y: y, width: scaledWidth(d), height: pieceHeight)) }
        }
        guard let sheetImage = sheet.makeImage() else { return [] }
        let observations: [VNRecognizedTextObservation] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = makeRequest(languages: ["en-US"], correction: false, minimumTextHeight: 0)
                let handler = VNImageRequestHandler(cgImage: sheetImage, options: [:])
                try? handler.perform([request])
                continuation.resume(returning: request.results ?? [])
            }
        }
        var texts = Array(repeating: "", count: rows.count)
        for observation in observations {
            guard let text = observation.topCandidates(1).first?.string else { continue }
            let mid = Double(observation.boundingBox.midY)
            guard let row = rowCenters.indices.min(by: { abs(rowCenters[$0] - mid) < abs(rowCenters[$1] - mid) }),
                  abs(rowCenters[row] - mid) * Double(sheetHeight) < pieceHeight else { continue }
            texts[row] += (texts[row].isEmpty ? "" : " ") + text
        }
        note?("읽기 종이 \(sheetWidth)x\(sheetHeight): " + texts.map { "[\($0)]" }.joined(separator: " "))
        var result: [BarFraction] = []
        for (k, bar) in bars.enumerated() {
            guard let parts = MathOCRFixer.fractionParts(texts[k]) else { continue }
            // Vision 좌표: 분자 맨 위 ~ 분모 맨 아래
            let box = CGRect(x: Double(bar.x0) / Double(w), y: 1 - Double(bar.denominatorBottom + 1) / Double(h),
                             width: Double(bar.x1 - bar.x0 + 1) / Double(w), height: Double(bar.denominatorBottom - bar.numeratorTop + 1) / Double(h))
            result.append(BarFraction(box: box, text: MathOCRFixer.fractionText(parts.numerator, parts.denominator)))
        }
        return result
    }

    /// 사진 속 윤곽선 중 동그라미 번호 후보 (모양 정보만, 판정은 MathOCRFixer.isChoiceCircle)
    static func detectCircles(_ cgImage: CGImage) async -> [MathOCRFixer.Shape] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectContoursRequest()
                request.detectsDarkOnLight = true
                request.contrastAdjustment = 1.5
                request.maximumImageDimension = min(2400, max(cgImage.width, cgImage.height))
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                guard (try? handler.perform([request])) != nil, let observation = request.results?.first else {
                    continuation.resume(returning: [])
                    return
                }
                let width = Double(cgImage.width), height = Double(cgImage.height)
                var shapes: [MathOCRFixer.Shape] = []
                func bounds(_ contour: VNContour) -> CGRect { contour.normalizedPath.boundingBox }
                func descendants(_ contour: VNContour, depth: Int) -> [VNContour] {
                    guard depth < 3 else { return [] }
                    return contour.childContours.flatMap { [$0] + descendants($0, depth: depth + 1) }
                }
                func visit(_ contour: VNContour, depth: Int) {
                    guard depth < 6, shapes.count < 400 else { return }
                    let box = bounds(contour)
                    let pixelWidth = Double(box.width) * width, pixelHeight = Double(box.height) * height
                    // 글자 하나 크기의 동그란 윤곽만 자세히 봄
                    if pixelHeight >= 9, pixelHeight <= 220, pixelWidth >= pixelHeight * 0.7, pixelWidth <= pixelHeight * 1.4,
                       !contour.childContours.isEmpty {
                        let points = contour.normalizedPoints
                        var area = 0.0
                        for k in points.indices {
                            let a = points[k], b = points[(k + 1) % points.count]
                            let ax = Double(a.x) * width, ay = Double(a.y) * height
                            let bx = Double(b.x) * width, by = Double(b.y) * height
                            area += ax * by - bx * ay
                        }
                        let fill = abs(area) / 2 / max(1, pixelWidth * pixelHeight)
                        let inner = descendants(contour, depth: 0).map { child -> CGRect in
                            let c = bounds(child)
                            return CGRect(x: (c.minX - box.minX) / box.width, y: (c.minY - box.minY) / box.height,
                                          width: c.width / box.width, height: c.height / box.height)
                        }
                        // 가로/세로 비율은 픽셀 기준으로 맞춘 안쪽 상자
                        let ratio: Double = pixelWidth / max(1, pixelHeight)
                        let corrected = inner.map { CGRect(x: $0.minX, y: $0.minY, width: $0.width * CGFloat(ratio), height: $0.height) }
                        shapes.append(MathOCRFixer.Shape(box: box, aspect: ratio, fill: fill, inner: corrected))
                    }
                    for child in contour.childContours { visit(child, depth: depth + 1) }
                }
                for contour in observation.topLevelContours { visit(contour, depth: 0) }
                continuation.resume(returning: shapes)
            }
        }
    }

    /// 사진 속 네모 상자들 (빈칸 □ 후보)
    static func detectRectangles(_ cgImage: CGImage) async -> [CGRect] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectRectanglesRequest()
                request.minimumAspectRatio = 0.25
                request.maximumAspectRatio = 1.0
                request.minimumSize = 0.012
                request.maximumObservations = 40
                request.minimumConfidence = 0.5
                request.quadratureTolerance = 25
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
                continuation.resume(returning: (request.results ?? []).map(\.boundingBox))
            }
        }
    }

    static func observe(_ cgImage: CGImage, languages: [String], correction: Bool) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = makeRequest(languages: languages, correction: correction)
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    continuation.resume(returning: request.results ?? [])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    private struct Word {
        let text: String
        let box: CGRect
    }

    /// 한국어 줄의 수식 부분(한글이 없는 구간)을 같은 자리의 영어 전용 인식 결과와 비교해서 더 수식다운 쪽을 고름
    static func merge(korean: [VNRecognizedTextObservation], english: [VNRecognizedTextObservation], rects: [CGRect] = [],
                      circles: [MathOCRFixer.Shape] = [], barFractions: [BarFraction] = [], ink: FractionFinder.Ink? = nil) -> [OCRLine] {
        // 영어 전용 결과를 낱말 단위 위치로
        var words: [Word] = []
        for observation in english {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            var index = text.startIndex
            while index < text.endIndex {
                guard let start = text[index...].firstIndex(where: { !$0.isWhitespace }) else { break }
                let end = text[start...].firstIndex(where: { $0.isWhitespace }) ?? text.endIndex
                if let box = try? candidate.boundingBox(for: start..<end)?.boundingBox {
                    words.append(Word(text: String(text[start..<end]), box: box))
                }
                index = end
            }
        }

        let heights = korean.map(\.boundingBox.height).sorted()
        let medianHeight = heights.isEmpty ? 0 : heights[heights.count / 2]

        // 분수: 분자·분모가 문장 줄 위아래에 따로 읽힌 짧은 조각 → "a/b"로 합쳐서 그 줄에 끼워 넣음
        let shortIndexes = korean.indices.filter { index in
            guard let text = korean[index].topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces) else { return false }
            return !text.isEmpty && text.count <= 7 && !text.contains(where: isHangul)
        }
        let hostIndexes = korean.indices.filter { !shortIndexes.contains($0) }
        let fractions = MathOCRFixer.stackedFractions(
            pieces: shortIndexes.map { (text: korean[$0].topCandidates(1).first?.string ?? "", box: korean[$0].boundingBox) },
            hosts: hostIndexes.map { korean[$0].boundingBox }
        ).filter { f in !barFractions.contains { $0.box.intersects(f.box) } }
        var fractionPieces = Set(fractions.flatMap { $0.used.map { shortIndexes[$0] } })
        // 사진에서 찾은 분수 자리에 따로 읽힌 조각("1", "35", "늘")은 분수로 바뀌므로 뺌
        for (i, observation) in korean.enumerated() {
            let b = observation.boundingBox
            if barFractions.contains(where: { f in
                f.box.insetBy(dx: -f.box.width * 0.2, dy: -f.box.height * 0.1).contains(CGPoint(x: b.midX, y: b.midY)) && b.width <= f.box.width * 1.8
            }) { fractionPieces.insert(i) }
        }
        // 분수마다 끼워 넣을 줄: 분수 가운데 높이를 지나는 줄 (없으면 같은 높이 왼쪽 줄 끝, 그것도 없으면 따로)
        var barsByLine: [Int: [BarFraction]] = [:]
        var looseBars: [BarFraction] = []
        for f in barFractions {
            let candidates = korean.indices.filter { i in
                let b = korean[i].boundingBox
                return !fractionPieces.contains(i) && b.minY <= f.box.midY && b.maxY >= f.box.midY
            }
            let inside = candidates.first { i in
                let b = korean[i].boundingBox
                return f.box.midX >= b.minX - 0.01 && f.box.midX <= b.maxX + 0.01
            }
            let left = candidates.filter { korean[$0].boundingBox.maxX <= f.box.midX && f.box.minX - korean[$0].boundingBox.maxX <= medianHeight * 3 }
                .max { korean[$0].boundingBox.maxX < korean[$1].boundingBox.maxX }
            if let host = inside ?? left { barsByLine[host, default: []].append(f) } else { looseBars.append(f) }
        }
        var fractionsByLine: [Int: [MathOCRFixer.Fraction]] = [:]
        for fraction in fractions { fractionsByLine[hostIndexes[fraction.host], default: []].append(fraction) }
        func isFractionBox(_ box: CGRect) -> Bool {
            fractions.contains { $0.box.insetBy(dx: -0.005, dy: -0.005).contains(CGPoint(x: box.midX, y: box.midY)) }
                || barFractions.contains { $0.box.insetBy(dx: -0.005, dy: -0.005).contains(CGPoint(x: box.midX, y: box.midY)) }
        }

        // 줄과 떨어져서 따로 읽힌 작은 지수(x² 의 2 등) 찾기
        func superscriptText(_ observation: VNRecognizedTextObservation) -> String? {
            guard !isFractionBox(observation.boundingBox),
                  let raw = observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces),
                  raw.range(of: #"^[0-9n]{1,2}$"#, options: .regularExpression) != nil,
                  observation.boundingBox.height < medianHeight * 0.75 else { return nil }
            return raw
        }
        var tiny: [(text: String, box: CGRect)] = []
        for observation in korean + english {
            guard let text = superscriptText(observation) else { continue }
            let box = observation.boundingBox
            if !tiny.contains(where: { abs($0.box.midX - box.midX) < 0.01 && abs($0.box.midY - box.midY) < 0.01 }) {
                tiny.append((text, box))
            }
        }
        var usedTiny = Set<Int>()

        // 빈 네모 상자 → 그 줄에 □ (글자 상자와 겹치지 않는 것만)
        // 글자 하나하나의 상자로 봄. 네모를 잘못 읽은 글자("_", "[", "L", "D", "口")는 글자로 치지 않음 (그 자리에 □)
        var letterBoxes: [CGRect] = []
        for observation in korean + english {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            var index = text.startIndex
            while index < text.endIndex {
                let next = text.index(after: index)
                if !text[index].isWhitespace, !MathOCRFixer.blankLookalikes.contains(text[index]),
                   let box = try? candidate.boundingBox(for: index..<next)?.boundingBox {
                    letterBoxes.append(box)
                }
                index = next
            }
        }
        var blanksByLine: [Int: [CGRect]] = [:]
        for blank in MathOCRFixer.blankBoxes(rects: rects, lines: korean.map(\.boundingBox), letters: letterBoxes) {
            // 사진 픽셀로 한 번 더: 테두리가 있고 안이 빈 네모만 (글자 사이 빈 곳을 네모로 잡은 것 거름)
            if let ink {
                let b = blank.box
                let x0 = Int(b.minX * CGFloat(ink.width)), x1 = Int(b.maxX * CGFloat(ink.width))
                let y0 = Int((1 - b.maxY) * CGFloat(ink.height)), y1 = Int((1 - b.minY) * CGFloat(ink.height))
                if !FractionFinder.isEmptyBox(ink, x0: x0, x1: x1, y0: y0, y1: y1) { continue }
            }
            blanksByLine[blank.host, default: []].append(blank.box)
        }

        // 보기 번호 동그라미 → 줄마다 (지울 글자 범위, 넣을 자리, 번호)
        var circleEdits: [Int: [(remove: Range<Int>, number: Int)]] = [:]
        do {
            func chosen(_ observation: VNRecognizedTextObservation) -> VNRecognizedText? { observation.topCandidates(1).first }
            func charBox(_ candidate: VNRecognizedText, _ offset: Int) -> CGRect? {
                let text = candidate.string
                let start = text.index(text.startIndex, offsetBy: offset)
                return try? candidate.boundingBox(for: start..<text.index(after: start))?.boundingBox
            }
            let found = circles.filter { MathOCRFixer.isChoiceCircle($0, lineHeight: medianHeight) }.map(\.box)
            // 겹친 것(테두리 안팎 윤곽)은 하나로
            var boxes: [CGRect] = []
            for box in found.sorted(by: { $0.height > $1.height }) where !boxes.contains(where: { $0.intersects(box.insetBy(dx: box.width * 0.2, dy: box.height * 0.2)) }) {
                boxes.append(box)
            }
            // 동그라미마다 줄과 글자 위치 찾기
            var places: [(line: Int, remove: Range<Int>, anchor: Int?)?] = []
            for box in boxes {
                let sameRow = korean.indices.filter { i in
                    let line = korean[i].boundingBox
                    let overlap = min(line.maxY, box.maxY) - max(line.minY, box.minY)
                    return overlap >= min(line.height, box.height) * 0.5 && !fractionPieces.contains(i)
                }
                let inside = sameRow.first { korean[$0].boundingBox.insetBy(dx: -0.004, dy: 0).contains(CGPoint(x: box.midX, y: korean[$0].boundingBox.midY)) }
                let right = sameRow.filter { korean[$0].boundingBox.minX >= box.midX && korean[$0].boundingBox.minX - box.maxX <= medianHeight * 2.5 }
                    .min { korean[$0].boundingBox.minX < korean[$1].boundingBox.minX }
                guard let line = inside ?? right, let candidate = chosen(korean[line]) else { places.append(nil); continue }
                let chars = Array(candidate.string)
                // 동그라미 자리에 잘못 읽힌 글자("1", "@", "(D", "①")는 지우고 그 자리에 번호
                let zone = box.insetBy(dx: -box.width * 0.15, dy: -box.height * 0.15)
                var covered: [Int] = []
                var insertAt = 0
                var anchor: Int?
                for i in chars.indices where !chars[i].isWhitespace {
                    guard let cb = charBox(candidate, i) else { continue }
                    if zone.contains(CGPoint(x: cb.midX, y: cb.midY)), cb.width < box.width * 1.3 {
                        covered.append(i)
                        if let n = "①②③④⑤".firstIndex(of: chars[i]) { anchor = "①②③④⑤".distance(from: "①②③④⑤".startIndex, to: n) + 1 }
                    } else if cb.maxX <= box.midX {
                        insertAt = i + 1
                    }
                }
                // 왼쪽 글자가 너무 붙어 있으면 낱말 속 글자(점 O 등)라서 번호가 아님
                if covered.isEmpty, insertAt > 0, let left = charBox(candidate, insertAt - 1), box.minX - left.maxX < medianHeight * 0.45 {
                    places.append(nil)
                    continue
                }
                // 낱말 한가운데 글자("don't", "homework"의 o)는 번호가 아님
                if let first = covered.min(), let last = covered.max(), first > 0, last + 1 < chars.count,
                   chars[first - 1].isLetter, chars[last + 1].isLetter {
                    places.append(nil)
                    continue
                }
                let range = covered.isEmpty ? insertAt..<insertAt : (covered.min()!)..<(covered.max()! + 1)
                places.append((line, range, anchor))
            }
            var anchors: [Int: Int] = [:]
            for (k, place) in places.enumerated() { if let a = place?.anchor { anchors[k] = a } }
            let valid = boxes.indices.filter { places[$0] != nil }
            let numbers = MathOCRFixer.numberCircles(valid.map { boxes[$0] }, lineHeight: medianHeight,
                                                     anchors: Dictionary(uniqueKeysWithValues: valid.enumerated().compactMap { k, i in anchors[i].map { (k, $0) } }))
            for (k, i) in valid.enumerated() where numbers[k] > 0 {
                guard let place = places[i] else { continue }
                // 동그라미 자리를 다른 숫자 하나("9", "6")로 또렷이 읽었으면 그건 보기 값의 숫자 (모양만 둥근 것)
                if let text = chosen(korean[place.line])?.string, place.remove.count == 1 {
                    let c = Array(text)[place.remove.lowerBound]
                    if c.isASCII, c.isNumber, !"10".contains(c), String(c) != String(numbers[k]) { continue }
                }
                circleEdits[place.line, default: []].append((place.remove, numbers[k]))
            }
        }

        let lines = korean.indices.map { lineIndex -> OCRLine? in
            let observation = korean[lineIndex]
            if fractionPieces.contains(lineIndex) { return nil }      // 분수 조각은 줄에 끼워 넣음
            if superscriptText(observation) != nil { return nil }   // 지수 조각은 줄에 끼워 넣음
            let candidates = observation.topCandidates(3)
            guard let best = candidates.first else { return nil }
            let candidate = circleEdits[lineIndex] != nil ? best : candidates.filter { $0.confidence >= best.confidence - 0.15 }
                .min { mathPenalty($0.string) < mathPenalty($1.string) } ?? best
            let original = candidate.string
            let chars = Array(original)
            func index(_ offset: Int) -> String.Index { original.index(original.startIndex, offsetBy: offset) }
            func charBox(_ offset: Int) -> CGRect? {
                try? candidate.boundingBox(for: index(offset)..<index(offset + 1))?.boundingBox
            }

            // 1) 떨어진 지수 끼워 넣기: 줄 위쪽에 붙은 작은 숫자 → 바로 왼쪽 글자 뒤에 ^숫자
            var insertions: [(offset: Int, text: String)] = []
            let line = observation.boundingBox
            for (k, piece) in tiny.enumerated() where !usedTiny.contains(k) {
                let b = piece.box
                guard b.midX >= line.minX, b.midX <= line.maxX + 0.02,
                      b.minY >= line.minY + line.height * 0.25, b.minY <= line.maxY,
                      b.maxY <= line.maxY + line.height * 0.8 else { continue }
                var bestOffset: Int?
                var bestMaxX = -1.0
                for offset in chars.indices where !chars[offset].isWhitespace {
                    guard let cb = charBox(offset), cb.maxX <= b.minX + 0.006, cb.maxX > bestMaxX else { continue }
                    bestMaxX = cb.maxX
                    bestOffset = offset
                }
                guard let offset = bestOffset else { continue }
                let base = chars[offset]
                guard base.isLetter || base.isNumber || base == ")" else { continue }
                // 이미 지수가 붙어 있으면 건너뜀
                if offset + 1 < chars.count, chars[offset + 1] == piece.text.first || "²³^".contains(chars[offset + 1]) { usedTiny.insert(k); continue }
                insertions.append((offset + 1, "^" + piece.text))
                usedTiny.insert(k)
            }

            // 1-2) 분수 끼워 넣기: 분수 왼쪽에 있는 마지막 글자 뒤에
            for fraction in fractionsByLine[lineIndex] ?? [] {
                var offset = 0
                var bestMaxX = -1.0
                for i in chars.indices where !chars[i].isWhitespace {
                    guard let cb = charBox(i), cb.maxX <= fraction.box.minX + 0.006, cb.maxX > bestMaxX else { continue }
                    bestMaxX = cb.maxX
                    offset = i + 1
                }
                insertions.append((offset, " " + fraction.text + " "))
            }

            // 1-1b) 줄 안에 붙어 읽힌 지수: "x2", "23" 중 숫자가 앞 글자보다 작고 위에 떠 있으면 ^ (x², 2³)
            if let ink {
                func extent(_ box: CGRect) -> (top: Int, bottom: Int)? {
                    // 글자 상자 경계는 대략이라 옆 글자 획이 섞이지 않게 양쪽을 넉넉히 뺌
                    let shrink = box.width * 0.25
                    let x0 = Int((box.minX + shrink) * CGFloat(ink.width)), x1 = Int((box.maxX - shrink) * CGFloat(ink.width))
                    let y0 = Int((1 - line.maxY - line.height * 0.15) * CGFloat(ink.height)), y1 = Int((1 - line.minY + line.height * 0.15) * CGFloat(ink.height))
                    return ink.extent(x0: x0, x1: x1, y0: y0, y1: y1)
                }
                // 이 줄 숫자들의 보통 높이 (지수는 그보다 확실히 작음)
                let digitHeights = chars.indices.filter { chars[$0].isASCII && chars[$0].isNumber }
                    .compactMap { i in charBox(i).flatMap(extent).map { $0.bottom - $0.top + 1 } }.sorted()
                let typical = digitHeights.count >= 3 ? digitHeights[digitHeights.count / 2] : nil
                for i in chars.indices.dropFirst() where chars[i].isASCII && chars[i].isNumber {
                    let base = chars[i - 1]
                    guard base.isASCII && (base.isLetter || base.isNumber) || base == ")",
                          !(i >= 2 && chars[i - 2] == "^"), chars[i - 1] != "^",
                          let digitBox = charBox(i), let baseBox = charBox(i - 1),
                          let d = extent(digitBox), let b = extent(baseBox),
                          FractionFinder.isSuperscript(base: b, digit: d) else { continue }
                    if let typical, Double(d.bottom - d.top + 1) > Double(typical) * 0.85 { continue }
                    insertions.append((i, "^"))
                }
            }

            // 1-1c) 선분 윗줄: 따로 선 대문자 두 글자(AB) 위의 짧은 가로줄 → 글자마다 윗줄 (A̅B̅, 앱 표기는 GeometryText)
            //       글자 인식은 윗줄을 버리고 "AB"만 읽어서, 사진 픽셀에서 직접 확인
            if let ink {
                let pairs = chars.indices.dropLast().filter { i in
                    chars[i].isASCII && chars[i].isUppercase && chars[i + 1].isASCII && chars[i + 1].isUppercase && chars[i] != chars[i + 1]
                        && (i == 0 || !(chars[i - 1].isLetter || chars[i - 1].isNumber)) && (i + 2 >= chars.count || !(chars[i + 2].isLetter || chars[i + 2].isNumber))
                }
                if !pairs.isEmpty {
                    let paired = Set(pairs.flatMap { [$0, $0 + 1] })
                    func extent(_ box: CGRect) -> (top: Int, bottom: Int)? {
                        let shrink = box.width * 0.2
                        let x0 = Int((box.minX + shrink) * CGFloat(ink.width)), x1 = Int((box.maxX - shrink) * CGFloat(ink.width))
                        let y0 = Int((1 - line.maxY - line.height * 0.1) * CGFloat(ink.height)), y1 = Int((1 - line.minY + line.height * 0.1) * CGFloat(ink.height))
                        return ink.extent(x0: x0, x1: x1, y0: y0, y1: y1)
                    }
                    // 같은 줄 대문자·숫자(없으면 한글)의 보통 윗끝과 높이
                    func typical(_ keep: (Character) -> Bool) -> (top: Int, height: Int)? {
                        let found = chars.indices.filter { !paired.contains($0) && keep(chars[$0]) }.compactMap { charBox($0).flatMap(extent) }
                        guard found.count >= 2 else { return nil }
                        let tops = found.map(\.top).sorted(), heights = found.map { $0.bottom - $0.top + 1 }.sorted()
                        return (tops[tops.count / 2], heights[heights.count / 2])
                    }
                    if let cap = typical({ $0.isASCII && ($0.isUppercase || $0.isNumber) }) ?? typical({ isHangul($0) }) {
                        for i in pairs {
                            guard let a = charBox(i), let b = charBox(i + 1), !isFractionBox(a.union(b)) else { continue }
                            let box = a.union(b)
                            let x0 = Int(box.minX * CGFloat(ink.width)), x1 = Int(box.maxX * CGFloat(ink.width))
                            if FractionFinder.hasOverline(ink, x0: x0, x1: x1, capTop: cap.top, letterHeight: cap.height) {
                                insertions.append((i + 1, GeometryText.overlineMark))
                                insertions.append((i + 2, GeometryText.overlineMark))
                            }
                        }
                    }
                }
            }

            // 1-2b) 사진에서 찾은 분수: 그 자리에 잘못 읽힌 글자("늘", "÷", "⅔")를 지우고 분수로
            var barEdits: [(range: Range<Int>, text: String)] = []
            let circleRanges = (circleEdits[lineIndex] ?? []).map(\.remove)
            for f in barsByLine[lineIndex] ?? [] {
                let zone = f.box.insetBy(dx: -f.box.width * 0.12, dy: -f.box.height * 0.05)
                var covered: [Int] = []
                var after = 0
                var bestMaxX = -1.0
                for i in chars.indices where !chars[i].isWhitespace && !circleRanges.contains(where: { $0.contains(i) }) {
                    guard let cb = charBox(i) else { continue }
                    if zone.contains(CGPoint(x: cb.midX, y: cb.midY)), cb.width < f.box.width * 2 {
                        covered.append(i)
                    } else if cb.maxX <= f.box.minX + 0.006, cb.maxX > bestMaxX {
                        bestMaxX = cb.maxX
                        after = i + 1
                    }
                }
                if let first = covered.min(), let last = covered.max(),
                   !barEdits.contains(where: { $0.range.overlaps(first..<(last + 1)) }) {
                    barEdits.append((first..<(last + 1), " " + f.text + " "))
                } else {
                    insertions.append((after, " " + f.text + " "))
                }
            }

            // 1-3) 빈칸 □ 끼워 넣기 (이미 □·口로 읽었으면 그대로). 네모 자리에 "_", "[", "L" 처럼 읽힌 글자는 □로 바꿈
            var blankEdits: [(range: Range<Int>, text: String)] = []
            if !original.contains(where: { "□口ㅁ".contains($0) }) {
                for blank in blanksByLine[lineIndex] ?? [] {
                    let zone = blank.insetBy(dx: -blank.width * 0.1, dy: -blank.height * 0.1)
                    if let hit = chars.indices.first(where: { i in
                        MathOCRFixer.blankLookalikes.contains(chars[i]) && charBox(i).map { zone.contains(CGPoint(x: $0.midX, y: $0.midY)) } == true
                    }) {
                        blankEdits.append((hit..<(hit + 1), " □ "))
                        continue
                    }
                    var offset = 0
                    var bestMaxX = -1.0
                    for i in chars.indices where !chars[i].isWhitespace {
                        guard let cb = charBox(i), cb.maxX <= blank.minX + 0.006, cb.maxX > bestMaxX else { continue }
                        bestMaxX = cb.maxX
                        offset = i + 1
                    }
                    insertions.append((offset, " □ "))
                }
            }

            // 1-4) 보기 번호 ①~⑤
            let circleHere = circleEdits[lineIndex] ?? []

            // 2) 한글이 없는 구간(수식)을 영어 전용 결과와 비교
            var replacements: [(range: Range<Int>, text: String)] = []
            if !words.isEmpty {
                var runs: [Range<Int>] = []
                var runStart: Int?
                for i in chars.indices {
                    if isHangul(chars[i]) {
                        if let s = runStart { runs.append(s..<i); runStart = nil }
                    } else if runStart == nil {
                        runStart = i
                    }
                }
                if let s = runStart { runs.append(s..<chars.count) }
                for run in runs {
                    guard let first = run.first(where: { !chars[$0].isWhitespace && !",.".contains(chars[$0]) }),
                          let last = run.last(where: { !chars[$0].isWhitespace && !",.".contains(chars[$0]) }) else { continue }
                    let range = first..<(last + 1)
                    // 지수를 끼워 넣은 구간은 그대로 둠
                    if insertions.contains(where: { $0.offset > range.lowerBound && $0.offset <= range.upperBound }) { continue }
                    // 보기 번호를 고친 구간, 분수로 바꾼 구간도 그대로 둠
                    if circleHere.contains(where: { $0.remove.overlaps(range) || ($0.remove.lowerBound >= range.lowerBound && $0.remove.lowerBound <= range.upperBound) }) { continue }
                    if barEdits.contains(where: { $0.range.overlaps(range) }) || blankEdits.contains(where: { $0.range.overlaps(range) }) { continue }
                    let originalPart = String(chars[range])
                    guard originalPart.contains(where: { $0.isNumber || ($0.isASCII && $0.isLetter) || "=+-×÷^()√<>".contains($0) }),
                          let box = try? candidate.boundingBox(for: index(range.lowerBound)..<index(range.upperBound))?.boundingBox else { continue }
                    let inside = words.filter { word in
                        let overlap = min(word.box.maxY, box.maxY) - max(word.box.minY, box.minY)
                        let height = min(word.box.height, box.height)
                        guard height > 0, overlap / height > 0.5 else { return false }
                        let midX = word.box.midX
                        return midX >= box.minX - 0.01 && midX <= box.maxX + 0.01
                    }.sorted { $0.box.minX < $1.box.minX }
                    let replacement = inside.map(\.text).joined(separator: " ")
                    guard !replacement.isEmpty, !replacement.contains(where: isHangul),
                          replacement.count * 2 >= originalPart.count, replacement.count <= originalPart.count * 2 + 2,
                          mathScore(replacement) > mathScore(originalPart) else { continue }
                    replacements.append((range, replacement))
                }
            }

            // 3) 뒤에서부터 적용 (앞쪽 위치가 안 바뀌게)
            var result = chars
            var edits: [(start: Int, end: Int, text: String)] = replacements.map { (start: $0.range.lowerBound, end: $0.range.upperBound, text: $0.text) }
            edits += insertions.map { (start: $0.offset, end: $0.offset, text: $0.text) }
            edits += barEdits.map { (start: $0.range.lowerBound, end: $0.range.upperBound, text: $0.text) }
            edits += blankEdits.filter { b in !barEdits.contains { $0.range.overlaps(b.range) } }
                .map { (start: $0.range.lowerBound, end: $0.range.upperBound, text: $0.text) }
            let circled: [Character] = ["①", "②", "③", "④", "⑤"]
            edits += circleHere.map { (start: $0.remove.lowerBound, end: $0.remove.upperBound, text: " \(circled[$0.number - 1]) ") }
            // 뒤에서부터, 같은 자리면 긴 범위를 먼저 (끼워 넣기가 범위 바꾸기에 지워지지 않게)
            for edit in edits.sorted(by: { $0.start != $1.start ? $0.start > $1.start : $0.end > $1.end }) {
                result.replaceSubrange(edit.start..<edit.end, with: Array(edit.text))
            }
            let text = String(result).replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            return OCRLine(text: text, confidence: adjustedConfidence(text, best.confidence), box: observation.boundingBox)
        }
        // 어느 줄에도 붙지 않은 분수는 따로 한 줄
        return lines.compactMap { $0 } + looseBars.map { OCRLine(text: $0.text, confidence: 0.9, box: $0.box) }
    }

    /// 수학 문제 사진 → 문제 글: 기기 글자 인식 + 자주 틀리는 글자 교정
    /// 여러 방법으로 읽은 결과 중 수식이 가장 자연스러운 쪽을 고름 (improved: 기본 결과보다 나은 걸 골랐는지)
    static func readMathProblem(_ image: CGImage, thorough: Bool = true, lines precomputed: [OCRLine]? = nil) async -> (text: String, improved: Bool) {
        // 미리 읽은 줄이 있으면 그 사진은 이미 바로 세운 것 (readMathProblemDetailed)
        let image = precomputed == nil ? await deskewed(image) : image
        var lines = precomputed ?? []
        if precomputed == nil { lines = (try? await recognizeMath(image)) ?? [] }
        let base = MathOCRFixer.fix(printedText(from: lines))
        guard thorough, !base.isEmpty else { return (base, false) }
        let readings = await multiPassRead(image)
        return bestReading(base: base, others: readings)
    }

    /// 문제 읽기 + 자신 없이 읽은 줄 (인식 결과 확인 화면에서 표시)
    static func readMathProblemDetailed(_ image: CGImage) async -> (text: String, improved: Bool, unsure: [String]) {
        let trace = await readMathProblemTrace(image)
        return (trace.text, trace.improved, trace.unsure)
    }

    /// 문제 읽기 단계별 결과 (사진 테스트에서 원인 찾기에도 씀)
    struct MathTrace {
        var text = ""
        var improved = false
        var unsure: [String] = []
        /// 글줄 기울기를 바로잡은 각도 (도, 0이면 그대로)
        var skew: Double = 0
        var lines: [OCRLine] = []
        var base = ""
        var readings: [String] = []
    }

    static func readMathProblemTrace(_ image: CGImage) async -> MathTrace {
        var trace = MathTrace()
        let straight = await deskew(image)
        trace.skew = straight.angle
        trace.lines = (try? await recognizeMath(straight.image)) ?? []
        trace.unsure = unsureLines(trace.lines)
        trace.base = MathOCRFixer.fix(printedText(from: trace.lines))
        trace.text = trace.base
        guard !trace.base.isEmpty else { return trace }
        trace.readings = await multiPassRead(straight.image)
        (trace.text, trace.improved) = bestReading(base: trace.base, others: trace.readings)
        return trace
    }

    // MARK: 수학이 아닌 과목 (SubjectOCR)

    /// 국어·영어·과학·사회 문제 사진: 한글·영어 문장을 그대로 (수식 교정 없이), 보기 번호·영어 낱말·과학 기호만 정리.
    /// 바로 세운 뒤 펜 자국을 지운 사진과 원본 중 더 잘 읽힌 쪽
    static func readSubjectProblem(_ image: CGImage) async -> (text: String, unsure: [String], lines: [OCRLine]) {
        let trace = await readSubjectTrace(image)
        return (trace.text, trace.unsure, trace.lines)
    }

    /// 수학이 아닌 과목 읽기 단계별 결과 (사진 테스트에서 다시 채점·원인 찾기에도 씀)
    struct SubjectTrace {
        struct Reading {
            var korean: [OCRGlyphLine] = []
            var english: [OCRGlyphLine] = []
            /// 동그라미 번호로 판정한 모양 상자
            var circles: [CGRect] = []
            /// 합친 줄 (흐린 줄 빼기 전)
            var lines: [OCRLine] = []
        }
        /// [펜 자국 지운 사진, 원래 사진]
        var readings: [Reading] = []
        var chosen = 0
        var skew: Double = 0
        var lines: [OCRLine] = []
        var text = ""
        var unsure: [String] = []
    }

    static func readSubjectTrace(_ image: CGImage) async -> SubjectTrace {
        var trace = SubjectTrace()
        let straight = await deskew(image)
        trace.skew = straight.angle
        // 두 사진을 동시에 읽음
        async let plainRead = subjectReading(straight.image)
        if let ink = inkOnly(straight.image) { trace.readings.append(await subjectReading(ink)) }
        trace.readings.append(await plainRead)
        let chosen = chooseSubjectReading(trace.readings.map(\.lines))
        trace.chosen = chosen.index
        trace.lines = chosen.lines
        trace.text = subjectText(chosen.lines)
        trace.unsure = chosen.lines.filter { $0.confidence < 0.5 }.map { $0.text.trimmingCharacters(in: .whitespaces) }
        return trace
    }

    /// 사진 한 장을 한국어+영어 / 영어 전용으로 읽고 동그라미 번호를 찾아 합침
    static func subjectReading(_ image: CGImage) async -> SubjectTrace.Reading {
        let cgImage = scaled(image, maxDimension: 3000)
        async let koreanRead = try? observe(cgImage, languages: ["ko-KR", "en-US"], correction: true)
        // 영어 문장은 철자 교정을 켠 영어 전용 인식이 가장 잘 읽음
        async let englishRead = try? observe(cgImage, languages: ["en-US"], correction: true)
        async let circleRead = detectCircles(cgImage)
        var reading = SubjectTrace.Reading()
        reading.korean = glyphLines(await koreanRead ?? [])
        reading.english = glyphLines(await englishRead ?? [])
        let heights = reading.korean.map(\.box.height).sorted()
        let median = heights.isEmpty ? 0 : heights[heights.count / 2]
        reading.circles = await circleRead.filter { MathOCRFixer.isChoiceCircle($0, lineHeight: median) }.map(\.box)
        reading.lines = subjectMerge(korean: reading.korean, english: reading.english, circles: reading.circles)
        return reading
    }

    /// Vision 결과 → 글자마다 상자가 있는 줄
    static func glyphLines(_ observations: [VNRecognizedTextObservation]) -> [OCRGlyphLine] {
        observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string
            var boxes: [CGRect?] = []
            var index = text.startIndex
            while index < text.endIndex {
                let next = text.index(after: index)
                if text[index].isWhitespace {
                    boxes.append(nil)
                } else {
                    boxes.append((try? candidate.boundingBox(for: index..<next))?.boundingBox)
                }
                index = next
            }
            return OCRGlyphLine(text: text, confidence: candidate.confidence, box: observation.boundingBox, charBoxes: boxes)
        }
    }

    // MARK: 기울어진 사진 바로 세우기

    /// 글줄이 기울어진 사진(문제 부분만 비스듬히 찍거나 자른 사진)을 바로 세움.
    /// 기울면 같은 줄의 보기 ①~⑤가 다른 줄로 나뉘고 줄 순서가 뒤섞여서, 읽기 전에 사진을 돌려 놓음
    static func deskewed(_ image: CGImage) async -> CGImage {
        await deskew(image).image
    }

    static func deskew(_ image: CGImage) async -> (image: CGImage, angle: Double) {
        let small = scaled(image, maxDimension: 1200)
        // 글줄 자리만 보고 잼 (종이 가장자리·책상·그림의 긴 선에 끌려가지 않게): 빠른 글자 찾기의 줄 상자
        let boxes: [CGRect] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .fast
                request.usesLanguageCorrection = false
                let handler = VNImageRequestHandler(cgImage: small, options: [:])
                try? handler.perform([request])
                continuation.resume(returning: (request.results ?? []).map(\.boundingBox))
            }
        }
        let w = small.width, h = small.height
        var gray = [UInt8](repeating: 255, count: w * h)
        let drawn: Bool = gray.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.draw(small, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return (image, 0) }
        // 글줄 상자(조금 넓혀서) 밖은 흰색으로
        var keep = [Bool](repeating: false, count: w * h)
        for box in boxes {
            let x0 = max(0, Int((box.minX - box.height * 0.3) * CGFloat(w))), x1 = min(w - 1, Int((box.maxX + box.height * 0.3) * CGFloat(w)))
            let y0 = max(0, Int((1 - box.maxY - box.height * 0.3) * CGFloat(h))), y1 = min(h - 1, Int((1 - box.minY + box.height * 0.3) * CGFloat(h)))
            guard x0 <= x1, y0 <= y1 else { continue }
            for y in y0...y1 { for x in x0...x1 { keep[y * w + x] = true } }
        }
        var masked = gray
        for i in 0..<(w * h) where !keep[i] { masked[i] = 255 }
        // 글줄 자리만 본 각도와 사진 전체로 잰 각도: 비슷하면 그대로, 다르면 덜 기운 쪽
        // (보기가 칸으로 늘어선 문제는 대각선으로 글자가 줄 서는 큰 각도가 잘못 잡히기도 하고,
        //  책상 위 종이는 종이 가장자리 선에 끌려가기도 해서)
        let a1 = TextSkew.angle(gray: masked, width: w, height: h, maxDegrees: 5)
        let a2 = TextSkew.angle(gray: gray, width: w, height: h, maxDegrees: 5)
        let angle: Double?
        switch (a1, a2) {
        case let (x?, y?): angle = abs(x - y) <= 1 ? (x + y) / 2 : (abs(x) < abs(y) ? x : y)
        case let (x?, nil): angle = x
        case let (nil, y?): angle = y
        default: angle = nil
        }
        guard let angle, let rotated = rotated(image, degrees: -angle) else { return (image, 0) }
        return (rotated, angle)
    }

    /// 가운데를 중심으로 돌린 사진 (잘리지 않게 넓힌 바깥은 흰색)
    static func rotated(_ image: CGImage, degrees: Double) -> CGImage? {
        let radians = CGFloat(degrees * .pi / 180)
        let input = CIImage(cgImage: image)
        let turned = input.transformed(by: CGAffineTransform(rotationAngle: radians))
        let extent = turned.extent.integral
        let background = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: extent)
        let output = turned.composited(over: background).cropped(to: extent)
        return CIContext().createCGImage(output, from: extent)
    }

    /// 손으로 쓴 풀이 읽기: 영어(수식) 위주, 교정 없이, 위에서 아래로 한 줄씩
    static func readHandwriting(_ image: CGImage) async -> [String] {
        let lines = (try? await recognize(image, languageCorrection: false, languages: ["en-US", "ko-KR"], preferMath: true)) ?? []
        return handwritingRows(lines)
    }

    // MARK: 검은 인쇄 글자만 남기기

    /// 검은 글자만 남긴 사진 그릴 크기: 작은 사진은 키워서 x², x³ 같은 작은 지수도 읽히게 함
    static func inkTargetSize(width: CGFloat, height: CGFloat) -> (width: Int, height: Int)? {
        let longest = max(width, height)
        guard longest > 0 else { return nil }
        let targetLongest = min(max(longest, 2200), 3000)
        let scale = targetLongest / longest
        let w = Int((width * scale).rounded()), h = Int((height * scale).rounded())
        guard w > 0, h > 0 else { return nil }
        return (w, h)
    }

    /// 검은색(채도가 낮고 어두운) 픽셀만 남기고 나머지는 흰색으로 지움
    /// - 빨강·파랑 펜: 채도가 높아서 지워짐
    /// - 연필 풀이: 인쇄 글자보다 밝아서 지워짐
    static func inkOnly(_ image: CGImage) -> CGImage? {
        guard let size = inkTargetSize(width: CGFloat(image.width), height: CGFloat(image.height)) else { return nil }
        return inkFiltered(width: size.width, height: size.height) { context in
            context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
    }

    /// draw로 그린 RGBX 픽셀(흰 바탕)을 검은 글자만 남긴 흑백으로
    static func inkFiltered(width: Int, height: Int, draw: (CGContext) -> Void) -> CGImage? {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 255, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow, space: colorSpace,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            context.interpolationQuality = .high
            draw(context)
            return true
        }
        guard drawn else { return nil }

        // 채도가 낮은 픽셀들의 밝기 분포로 "인쇄 글자"와 "종이"를 나누는 기준을 찾음 (오츠 방법)
        var histogram = [Int](repeating: 0, count: 256)
        var index = 0
        while index < pixels.count {
            let r = Int(pixels[index]), g = Int(pixels[index + 1]), b = Int(pixels[index + 2])
            if max(r, g, b) - min(r, g, b) < 60 {
                histogram[(r * 299 + g * 587 + b * 114) / 1000] += 1
            }
            index += 4
        }
        let total = histogram.reduce(0, +)
        guard total > 0 else { return nil }
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
        // 연필(회색)은 빼고 진한 인쇄만: 기준을 조금 더 어둡게
        let threshold = min(max(Int(Double(otsu) * 0.85), 80), 170)
        let ramp = 45

        index = 0
        while index < pixels.count {
            let r = Int(pixels[index]), g = Int(pixels[index + 1]), b = Int(pixels[index + 2])
            let saturation = max(r, g, b) - min(r, g, b)
            let luminance = (r * 299 + g * 587 + b * 114) / 1000
            let value: Int
            if saturation > 70 && luminance > 40 {
                value = 255
            } else if luminance <= threshold {
                value = 0
            } else if luminance >= threshold + ramp {
                value = 255
            } else {
                value = (luminance - threshold) * 255 / ramp
            }
            let byte = UInt8(value)
            pixels[index] = byte
            pixels[index + 1] = byte
            pixels[index + 2] = byte
            index += 4
        }

        return pixels.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow, space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)?.makeImage()
        }
    }

    /// 같은 사진을 여러 방법으로 읽은 결과 (AI가 비교해서 문장을 복원할 때 사용)
    /// 0) 검은 인쇄 글자만  1) 기본  2) 철자 자동교정 끔(수식·기호 보존)  3) 흑백·고대비·확대  4) 영어 전용(수식의 x, a, b, y)
    static func multiPassRead(_ image: CGImage) async -> [String] {
        var results: [String] = []
        if let ink = inkOnly(image), let lines = try? await recognize(ink) {
            results.append(printedText(from: lines))
        }
        if let lines = try? await recognize(image) {
            results.append(printedText(from: lines))
        }
        if let lines = try? await recognize(image, languageCorrection: false) {
            results.append(printedText(from: lines))
        }
        if let enhanced = enhancedForText(image), let lines = try? await recognize(enhanced, languageCorrection: false) {
            results.append(printedText(from: lines))
        }
        if let lines = try? await recognize(image, languageCorrection: false, languages: ["en-US"]) {
            let text = plainText(from: lines.filter { $0.confidence >= 0.3 })
            if !text.isEmpty { results.append("[영어 전용 읽기 · 수식 참고용]\n" + text) }
        }
        return results.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// 흑백 + 대비를 높이고, 작은 사진은 2배로 키움
    static func enhancedForText(_ image: CGImage) -> CGImage? {
        let base = scaled(image, maxDimension: 3000)
        let input = CIImage(cgImage: base)
        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(input, forKey: kCIInputImageKey)
        controls?.setValue(0.0, forKey: kCIInputSaturationKey)
        controls?.setValue(1.4, forKey: kCIInputContrastKey)
        guard var output = controls?.outputImage else { return nil }
        if max(base.width, base.height) < 1600 {
            output = output.transformed(by: CGAffineTransform(scaleX: 2, y: 2))
        }
        return CIContext().createCGImage(output, from: output.extent)
    }

    // MARK: 사진 반듯하게 펴기

    /// 앨범 사진 속 종이(단어장·문제지)를 찾아 그 부분만 잘라 정면에서 본 것처럼 폄.
    /// 종이를 확실히 찾지 못했거나 이미 사진 전체가 종이면 nil (그대로 씀)
    static func straightened(_ image: CGImage) async -> CGImage? {
        let cgImage = scaled(image, maxDimension: 3000)
        let corners: [CGPoint]? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectDocumentSegmentationRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                guard (try? handler.perform([request])) != nil,
                      let page = request.results?.first, page.confidence >= 0.8 else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: [page.topLeft, page.topRight, page.bottomRight, page.bottomLeft])
            }
        }
        guard let corners else { return nil }
        // 사진의 35% ~ 95%를 차지하는 종이만 (너무 작으면 그림·표 상자, 너무 크면 이미 반듯한 사진)
        var area: CGFloat = 0
        for i in corners.indices {
            let a = corners[i], b = corners[(i + 1) % corners.count]
            area += a.x * b.y - b.x * a.y
        }
        area = abs(area) / 2
        guard area >= 0.35, area <= 0.95 else { return nil }

        let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
        func point(_ p: CGPoint) -> CIVector { CIVector(x: p.x * width, y: p.y * height) }
        let input = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(point(corners[0]), forKey: "inputTopLeft")
        filter.setValue(point(corners[1]), forKey: "inputTopRight")
        filter.setValue(point(corners[2]), forKey: "inputBottomRight")
        filter.setValue(point(corners[3]), forKey: "inputBottomLeft")
        guard let output = filter.outputImage, output.extent.width > 200, output.extent.height > 200 else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }

    // MARK: 단어장 읽기

    /// 단어장 사진 → 단어·뜻 (철자 확인 전): 원래 사진과 고대비 사진을 함께 읽어 더 많이 찾은 쪽을 쓰고,
    /// 빠진 뜻은 다른 쪽에서 채움
    static func readWordsUnchecked(_ image: CGImage) async -> [ParsedWord] {
        await readWordsTrace(image).words
    }

    /// 단어장 읽기 단계별 결과: 바로 세운 사진을 원래대로 / 고대비로 읽은 줄
    static func readWordsTrace(_ image: CGImage) async -> (words: [ParsedWord], plain: [OCRLine], contrast: [OCRLine], skew: Double) {
        let straight = await deskew(image)
        async let plainRead = try? recognize(straight.image)
        async let contrastRead = contrastLines(straight.image)
        let first = await plainRead
        let second = await contrastRead
        return (bestWords([first, second].compactMap { $0 }), first ?? [], second ?? [], straight.angle)
    }

    private static func contrastLines(_ image: CGImage) async -> [OCRLine]? {
        guard let enhanced = enhancedForText(image) else { return nil }
        return try? await recognize(enhanced)
    }
}
