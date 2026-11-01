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
    static func recognize(_ image: UIImage, languageCorrection: Bool = true) async throws -> [OCRLine] {
        let prepared = image.preparedForOCR()
        guard let cgImage = prepared.cgImage else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = languageCorrection
                request.recognitionLanguages = ["ko-KR", "en-US"]

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let lines: [OCRLine] = observations.compactMap { observation in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return OCRLine(text: candidate.string, confidence: candidate.confidence, box: observation.boundingBox)
                    }
                    continuation.resume(returning: lines)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 같은 사진을 세 가지 방법으로 읽은 결과 (AI가 비교해서 문장을 복원할 때 사용)
    /// 1) 기본  2) 철자 자동교정 끔(수식·기호 보존)  3) 흑백·고대비·확대
    static func multiPassRead(_ image: UIImage) async -> [String] {
        var results: [String] = []
        if let lines = try? await recognize(image) {
            results.append(printedText(from: lines))
        }
        if let lines = try? await recognize(image, languageCorrection: false) {
            results.append(printedText(from: lines))
        }
        if let enhanced = enhancedForText(image), let lines = try? await recognize(enhanced, languageCorrection: false) {
            results.append(printedText(from: lines))
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
