import CoreImage
import UIKit
import Vision

/// Vision 프레임워크로 사진 속 글자를 읽어옴 (기기 내에서 처리, 인터넷 불필요)
struct OCRLine {
    let text: String
    /// 인식 신뢰도 0~1 (손글씨는 보통 낮게 나옴)
    var confidence: Float = 1
    /// Vision 정규화 좌표 (0~1, 원점 왼쪽 아래)
    let box: CGRect
}

enum OCRService {
    static func recognize(_ image: UIImage, languageCorrection: Bool = true,
                          languages: [String] = ["ko-KR", "en-US"], preferMath: Bool = false) async throws -> [OCRLine] {
        let prepared = image.preparedForOCR()
        guard let cgImage = prepared.cgImage else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = languageCorrection
                request.recognitionLanguages = languages

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
    static func recognizeMath(_ image: UIImage) async throws -> [OCRLine] {
        let original = await mathRead(image)
        guard let ink = inkOnly(image) else { return original }
        let inkLines = await mathRead(ink)
        guard !inkLines.isEmpty else { return original }
        // 검은 글자만 읽은 결과가 원래보다 확실히 적으면 (얇은 글씨가 지워진 경우) 원래 결과 사용
        let inkCount = printedText(from: inkLines).count
        let originalCount = printedText(from: original).count
        return inkCount >= originalCount * 7 / 10 ? inkLines : original
    }

    // MARK: 수식 두 번 읽기 (한국어+영어 / 영어 전용)

    /// 한국어 인식은 한글 문장을 잘 읽지만 기울어진 수식 글자(a, b, x, 지수)를 숫자로 착각하기 쉬움.
    /// 영어 전용 인식은 수식을 더 잘 읽음 → 줄마다 글자 위치를 맞춰서 수식 부분만 영어 전용 결과로 바꿈
    static func mathRead(_ image: UIImage) async -> [OCRLine] {
        guard let cgImage = image.preparedForOCR(maxDimension: 3000).cgImage else { return [] }
        guard let korean = try? await observe(cgImage, languages: ["ko-KR", "en-US"], correction: true) else { return [] }
        let english = (try? await observe(cgImage, languages: ["en-US"], correction: false)) ?? []
        return merge(korean: korean, english: english)
    }

    private static func observe(_ cgImage: CGImage, languages: [String], correction: Bool) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = correction
                request.recognitionLanguages = languages
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

    private static func isHangul(_ c: Character) -> Bool {
        c.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) || (0x3131...0x318E).contains($0.value) }
    }

    /// 한국어 줄의 수식 부분(한글이 없는 구간)을 같은 자리의 영어 전용 인식 결과와 비교해서 더 수식다운 쪽을 고름
    private static func merge(korean: [VNRecognizedTextObservation], english: [VNRecognizedTextObservation]) -> [OCRLine] {
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

        // 줄과 떨어져서 따로 읽힌 작은 지수(x² 의 2 등) 찾기
        let heights = korean.map(\.boundingBox.height).sorted()
        let medianHeight = heights.isEmpty ? 0 : heights[heights.count / 2]
        func superscriptText(_ observation: VNRecognizedTextObservation) -> String? {
            guard let raw = observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces),
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

        let lines = korean.map { observation -> OCRLine? in
            if superscriptText(observation) != nil { return nil }   // 지수 조각은 줄에 끼워 넣음
            let candidates = observation.topCandidates(3)
            guard let best = candidates.first else { return nil }
            let candidate = candidates.filter { $0.confidence >= best.confidence - 0.15 }
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
            for edit in edits.sorted(by: { $0.start > $1.start }) {
                result.replaceSubrange(edit.start..<edit.end, with: Array(edit.text))
            }
            return OCRLine(text: String(result), confidence: best.confidence, box: observation.boundingBox)
        }
        return lines.compactMap { $0 }
    }

    /// 수식다운 정도: 변수 글자·연산 기호는 +, 숫자 자리의 이상한 글자·낯선 기호는 −
    static func mathScore(_ text: String) -> Int {
        var score = 0
        for c in text {
            if "xyabcknmt".contains(c) { score += 2 }
            else if "+-=×÷^()√<>≤≥/²³".contains(c) { score += 1 }
            else if c.isUppercase && c.isASCII { score -= 1 }
            else if !c.isASCII && !"−·αβγθπ".contains(c) { score -= 2 }
        }
        return score - 3 * mathPenalty(text)
    }

    /// 수식처럼 보이는 줄에서 숫자 자리에 비슷한 글자가 끼어든 정도 (작을수록 좋음)
    static func mathPenalty(_ text: String) -> Int {
        let patterns = [#"[0-9][ZOlISB]"#, #"[ZOlISB][0-9]"#, #"[+\-=×÷(^][ZOlS](?![a-z])"#, #"[|]"#]
        return patterns.reduce(0) { total, pattern in
            total + ((try? NSRegularExpression(pattern: pattern))?.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) ?? 0)
        }
    }

    /// 수학 문제 사진 → 문제 글: 기기 글자 인식 + 자주 틀리는 글자 교정
    /// 여러 방법으로 읽은 결과 중 수식이 가장 자연스러운 쪽을 고름 (improved: 기본 결과보다 나은 걸 골랐는지)
    static func readMathProblem(_ image: UIImage, thorough: Bool = true) async -> (text: String, improved: Bool) {
        let lines = (try? await recognizeMath(image)) ?? []
        let base = MathOCRFixer.fix(printedText(from: lines))
        guard thorough, !base.isEmpty else { return (base, false) }
        let readings = await multiPassRead(image).map { reading -> String in
            MathOCRFixer.fix(reading.replacingOccurrences(of: "[영어 전용 읽기 · 수식 참고용]\n", with: ""))
        }
        var best = (text: base, score: readingScore(base))
        for reading in readings where reading.count >= base.count * 3 / 4 && reading.count <= base.count * 3 / 2 + 10 {
            let score = readingScore(reading)
            if score > best.score + 3 { best = (reading, score) }
        }
        return (best.text, best.text != base)
    }

    /// 문제 읽기 + 자신 없이 읽은 줄 (인식 결과 확인 화면에서 표시)
    static func readMathProblemDetailed(_ image: UIImage) async -> (text: String, improved: Bool, unsure: [String]) {
        let lines = (try? await recognizeMath(image)) ?? []
        let unsure = lines.filter { $0.confidence < 0.5 && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { MathOCRFixer.fix($0.text) }
        let result = await readMathProblem(image)
        return (result.text, result.improved, unsure)
    }

    /// 읽은 글이 얼마나 그럴듯한지: 한글 문장은 그대로 두고, 수식 부분은 수식다운 정도로
    static func readingScore(_ text: String) -> Int {
        var score = 0
        for line in text.components(separatedBy: "\n") {
            let hangul = line.filter(isHangul).count
            let formula = String(line.filter { !isHangul($0) })
            score += hangul / 2 + mathScore(formula)
        }
        return score
    }

    /// 손으로 쓴 풀이 읽기: 영어(수식) 위주, 교정 없이, 위에서 아래로 한 줄씩
    static func readHandwriting(_ image: UIImage) async -> [String] {
        let lines = (try? await recognize(image, languageCorrection: false, languages: ["en-US", "ko-KR"], preferMath: true)) ?? []
        let rows = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.box.midY > $1.box.midY }
        // 같은 높이에 나뉘어 읽힌 조각은 한 줄로 합침
        var merged: [(text: String, box: CGRect)] = []
        for line in rows {
            if let last = merged.last, abs(last.box.midY - line.box.midY) < min(last.box.height, line.box.height) * 0.5 {
                let left = last.box.minX <= line.box.minX
                merged[merged.count - 1] = (left ? last.text + " " + line.text : line.text + " " + last.text, last.box.union(line.box))
            } else {
                merged.append((line.text, line.box))
            }
        }
        return merged.map { MathOCRFixer.fix($0.text) }
    }

    /// 검은색(채도가 낮고 어두운) 픽셀만 남기고 나머지는 흰색으로 지움
    /// - 빨강·파랑 펜: 채도가 높아서 지워짐
    /// - 연필 풀이: 인쇄 글자보다 밝아서 지워짐
    /// - 작은 사진은 키워서 x², x³ 같은 작은 지수도 읽히게 함
    static func inkOnly(_ image: UIImage) -> UIImage? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let targetLongest = min(max(longest, 2200), 3000)
        let scale = targetLongest / longest
        let width = Int((image.size.width * scale).rounded())
        let height = Int((image.size.height * scale).rounded())
        guard width > 0, height > 0 else { return nil }

        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 255, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow, space: colorSpace,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            context.interpolationQuality = .high
            UIGraphicsPushContext(context)
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            UIGraphicsPopContext()
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

        let output: CGImage? = pixels.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow, space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)?.makeImage()
        }
        return output.map { UIImage(cgImage: $0) }
    }

    /// 같은 사진을 세 가지 방법으로 읽은 결과 (AI가 비교해서 문장을 복원할 때 사용)
    /// 0) 검은 인쇄 글자만  1) 기본  2) 철자 자동교정 끔(수식·기호 보존)  3) 흑백·고대비·확대  4) 영어 전용(수식의 x, a, b, y)
    static func multiPassRead(_ image: UIImage) async -> [String] {
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
    static func enhancedForText(_ image: UIImage) -> UIImage? {
        let base = image.resized(maxDimension: 3000)
        guard let input = CIImage(image: base) else { return nil }
        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(input, forKey: kCIInputImageKey)
        controls?.setValue(0.0, forKey: kCIInputSaturationKey)
        controls?.setValue(1.4, forKey: kCIInputContrastKey)
        guard var output = controls?.outputImage else { return nil }
        if max(base.size.width, base.size.height) < 1600 {
            output = output.transformed(by: CGAffineTransform(scaleX: 2, y: 2))
        }
        let ciContext = CIContext()
        guard let cg = ciContext.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// 인쇄된 문제 위주로 남기기: 신뢰도가 낮은 줄(손글씨)과
    /// 한글·보기 번호 없이 숫자/기호만 있는 짧은 줄(풀이 계산 흔적)을 뺌
    static func printedText(from lines: [OCRLine]) -> String {
        let kept = lines.filter { line in
            let text = line.text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, line.confidence >= 0.35 else { return false }
            let hasHangul = text.range(of: "[가-힣]", options: .regularExpression) != nil
            let hasChoice = text.range(of: "[①②③④⑤]", options: .regularExpression) != nil
            if hasHangul || hasChoice { return true }
            if text.count <= 6 { return false }
            return line.confidence >= 0.5
        }
        return plainText(from: kept)
    }

    /// 위에서 아래 순서로 정렬된 전체 텍스트
    static func plainText(from lines: [OCRLine]) -> String {
        lines
            .sorted { $0.box.midY > $1.box.midY }
            .map(\.text)
            .joined(separator: "\n")
    }
}

extension UIImage {
    /// 방향을 .up으로 맞추고 너무 큰 이미지는 축소
    func preparedForOCR(maxDimension: CGFloat = 2400) -> UIImage {
        resized(maxDimension: maxDimension)
    }

    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    func jpegForStorage(maxDimension: CGFloat, quality: CGFloat = 0.8) -> Data? {
        resized(maxDimension: maxDimension).jpegData(compressionQuality: quality)
    }
}
