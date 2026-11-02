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
                        return OCRLine(text: chosen.string, confidence: max(chosen.confidence, best.confidence * 0.9), box: observation.boundingBox)
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
        let original = await mathRead(image)
        guard let ink = inkOnly(image) else { return original }
        let inkLines = await mathRead(ink)
        return chooseInkReading(original: original, ink: inkLines)
    }

    // MARK: 수식 두 번 읽기 (한국어+영어 / 영어 전용)

    /// 한국어 인식은 한글 문장을 잘 읽지만 기울어진 수식 글자(a, b, x, 지수)를 숫자로 착각하기 쉬움.
    /// 영어 전용 인식은 수식을 더 잘 읽음 → 줄마다 글자 위치를 맞춰서 수식 부분만 영어 전용 결과로 바꿈
    static func mathRead(_ image: CGImage) async -> [OCRLine] {
        let cgImage = scaled(image, maxDimension: 3000)
        // 두 번 읽기를 동시에 (기다리는 시간 절반)
        async let koreanRead = try? observe(cgImage, languages: ["ko-KR", "en-US"], correction: true)
        async let englishRead = try? observe(cgImage, languages: ["en-US"], correction: false)
        // 빈칸 네모 상자 (글자 인식은 빈 네모를 아예 안 읽는 경우가 많아서 따로 찾음)
        async let boxRead = detectRectangles(cgImage)
        // 보기 번호 동그라미 ①~⑤ (글자 인식이 못 읽거나 "1", "@", "(D"로 읽는 경우가 많아서 모양으로 찾음)
        async let circleRead = detectCircles(cgImage)
        guard let korean = await koreanRead else { return [] }
        let english = await englishRead ?? []
        let rects = await boxRead
        let circles = await circleRead
        return merge(korean: korean, english: english, rects: rects, circles: circles)
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
                              circles: [MathOCRFixer.Shape] = []) -> [OCRLine] {
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
        )
        let fractionPieces = Set(fractions.flatMap { $0.used.map { shortIndexes[$0] } })
        var fractionsByLine: [Int: [MathOCRFixer.Fraction]] = [:]
        for fraction in fractions { fractionsByLine[hostIndexes[fraction.host], default: []].append(fraction) }
        func isFractionBox(_ box: CGRect) -> Bool {
            fractions.contains { $0.box.insetBy(dx: -0.005, dy: -0.005).contains(CGPoint(x: box.midX, y: box.midY)) }
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
        var letterBoxes = words.map(\.box)
        for observation in korean {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            var index = text.startIndex
            while index < text.endIndex {
                guard let start = text[index...].firstIndex(where: { !$0.isWhitespace }) else { break }
                let end = text[start...].firstIndex(where: { $0.isWhitespace }) ?? text.endIndex
                if let box = try? candidate.boundingBox(for: start..<end)?.boundingBox { letterBoxes.append(box) }
                index = end
            }
        }
        var blanksByLine: [Int: [CGRect]] = [:]
        for blank in MathOCRFixer.blankBoxes(rects: rects, lines: korean.map(\.boundingBox), letters: letterBoxes) {
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

            // 1-3) 빈칸 □ 끼워 넣기 (이미 □·口로 읽었으면 그대로)
            if !original.contains(where: { "□口ㅁ".contains($0) }) {
                for blank in blanksByLine[lineIndex] ?? [] {
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
                    // 보기 번호를 고친 구간도 그대로 둠
                    if circleHere.contains(where: { $0.remove.overlaps(range) || ($0.remove.lowerBound >= range.lowerBound && $0.remove.lowerBound <= range.upperBound) }) { continue }
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
            let circled: [Character] = ["①", "②", "③", "④", "⑤"]
            edits += circleHere.map { (start: $0.remove.lowerBound, end: $0.remove.upperBound, text: " \(circled[$0.number - 1]) ") }
            // 뒤에서부터, 같은 자리면 긴 범위를 먼저 (끼워 넣기가 범위 바꾸기에 지워지지 않게)
            for edit in edits.sorted(by: { $0.start != $1.start ? $0.start > $1.start : $0.end > $1.end }) {
                result.replaceSubrange(edit.start..<edit.end, with: Array(edit.text))
            }
            let text = String(result).replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            return OCRLine(text: text, confidence: best.confidence, box: observation.boundingBox)
        }
        return lines.compactMap { $0 }
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

    // MARK: 기울어진 사진 바로 세우기

    /// 글줄이 기울어진 사진(문제 부분만 비스듬히 찍거나 자른 사진)을 바로 세움.
    /// 기울면 같은 줄의 보기 ①~⑤가 다른 줄로 나뉘고 줄 순서가 뒤섞여서, 읽기 전에 사진을 돌려 놓음
    static func deskewed(_ image: CGImage) async -> CGImage {
        await deskew(image).image
    }

    static func deskew(_ image: CGImage) async -> (image: CGImage, angle: Double) {
        let small = scaled(image, maxDimension: 1600)
        let quads: [(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint)] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .fast
                request.usesLanguageCorrection = false
                let handler = VNImageRequestHandler(cgImage: small, options: [:])
                try? handler.perform([request])
                continuation.resume(returning: (request.results ?? []).map { (topLeft: $0.topLeft, topRight: $0.topRight, bottomLeft: $0.bottomLeft, bottomRight: $0.bottomRight) })
            }
        }
        guard let angle = MathOCRFixer.skewAngle(quads: quads, width: Double(small.width), height: Double(small.height)),
              let rotated = rotated(image, degrees: -angle) else { return (image, 0) }
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
