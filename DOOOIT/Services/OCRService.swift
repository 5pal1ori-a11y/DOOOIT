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
        let original = try await recognize(image, preferMath: true)
        guard let ink = inkOnly(image), let inkLines = try? await recognize(ink, preferMath: true), !inkLines.isEmpty else { return original }
        // 검은 글자만 읽은 결과가 원래보다 확실히 적으면 (얇은 글씨가 지워진 경우) 원래 결과 사용
        let inkCount = printedText(from: inkLines).count
        let originalCount = printedText(from: original).count
        return inkCount >= originalCount * 7 / 10 ? inkLines : original
    }

    /// 수식처럼 보이는 줄에서 숫자 자리에 비슷한 글자가 끼어든 정도 (작을수록 좋음)
    static func mathPenalty(_ text: String) -> Int {
        let patterns = [#"[0-9][ZOlISB]"#, #"[ZOlISB][0-9]"#, #"[+\-=×÷(^][ZOlS](?![a-z])"#, #"[|]"#]
        return patterns.reduce(0) { total, pattern in
            total + ((try? NSRegularExpression(pattern: pattern))?.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) ?? 0)
        }
    }

    /// 수학 문제 사진 → 문제 글: 기기 글자 인식 + 자주 틀리는 글자 교정
    /// Apple Intelligence를 쓸 수 있으면 여러 번 읽은 결과를 비교해서 원래 인쇄된 문제로 한 번 더 복원
    static func readMathProblem(_ image: UIImage, useAI: Bool = true) async -> (text: String, usedAI: Bool) {
        let lines = (try? await recognizeMath(image)) ?? []
        let base = MathOCRFixer.fix(printedText(from: lines))
        guard useAI, DoitAppleAI.isAvailable, !base.isEmpty else { return (base, false) }
        let readings = await multiPassRead(image)
        guard let repaired = try? await DoitAppleAI.reconstruct(readings: readings, current: base) else { return (base, false) }
        let fixed = MathOCRFixer.fix(repaired)
        // 너무 짧아졌거나 엉뚱하게 길어지면 기본 결과 사용
        guard fixed.count >= base.count / 2, fixed.count <= base.count * 2 + 40 else { return (base, false) }
        return (fixed, true)
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
