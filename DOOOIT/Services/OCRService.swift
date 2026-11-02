import CoreImage
import UIKit
import Vision

/// 앱에서 쓰는 UIImage 입구. 실제 인식은 OCRCore.swift (CGImage만 다루므로 맥에서 사진 테스트 가능)
extension OCRService {
    /// 사진을 바로 세운 CGImage로 (긴 변 최대 3000 — 인식 단계마다 필요한 크기로 다시 줄임)
    private static func upright(_ image: UIImage, maxDimension: CGFloat = 3000) -> CGImage? {
        image.resized(maxDimension: maxDimension).cgImage
    }

    static func recognize(_ image: UIImage, languageCorrection: Bool = true,
                          languages: [String] = ["ko-KR", "en-US"], preferMath: Bool = false) async throws -> [OCRLine] {
        guard let cgImage = image.preparedForOCR().cgImage else { return [] }
        return try await recognize(cgImage, languageCorrection: languageCorrection, languages: languages, preferMath: preferMath)
    }

    /// 수학 문제용: 검은 인쇄 글자만 남긴 사진(빨간 펜·파란 펜·연필 풀이 제거, 작은 지수가 보이게 확대)으로 읽음
    static func recognizeMath(_ image: UIImage) async throws -> [OCRLine] {
        guard let cgImage = upright(image) else { return [] }
        return try await recognizeMath(cgImage)
    }

    static func mathRead(_ image: UIImage) async -> [OCRLine] {
        guard let cgImage = image.preparedForOCR(maxDimension: 3000).cgImage else { return [] }
        return await mathRead(cgImage)
    }

    /// 수학 문제 사진 → 문제 글 (improved: 기본 결과보다 나은 걸 골랐는지)
    static func readMathProblem(_ image: UIImage, thorough: Bool = true, lines precomputed: [OCRLine]? = nil) async -> (text: String, improved: Bool) {
        guard let cgImage = upright(image) else { return ("", false) }
        return await readMathProblem(cgImage, thorough: thorough, lines: precomputed)
    }

    /// 문제 읽기 + 자신 없이 읽은 줄 (인식 결과 확인 화면에서 표시)
    static func readMathProblemDetailed(_ image: UIImage) async -> (text: String, improved: Bool, unsure: [String]) {
        guard let cgImage = upright(image) else { return ("", false, []) }
        return await readMathProblemDetailed(cgImage)
    }

    /// 손으로 쓴 풀이 읽기: 영어(수식) 위주, 교정 없이, 위에서 아래로 한 줄씩
    static func readHandwriting(_ image: UIImage) async -> [String] {
        let lines = (try? await recognize(image, languageCorrection: false, languages: ["en-US", "ko-KR"], preferMath: true)) ?? []
        return handwritingRows(lines)
    }

    /// 검은색(채도가 낮고 어두운) 픽셀만 남기고 나머지는 흰색으로 지움
    static func inkOnly(_ image: UIImage) -> UIImage? {
        guard let cgImage = upright(image) else { return nil }
        return inkOnly(cgImage).map { UIImage(cgImage: $0) }
    }

    /// 같은 사진을 여러 방법으로 읽은 결과 (AI가 비교해서 문장을 복원할 때 사용)
    static func multiPassRead(_ image: UIImage) async -> [String] {
        guard let cgImage = upright(image) else { return [] }
        return await multiPassRead(cgImage)
    }

    /// 흑백 + 대비를 높이고, 작은 사진은 2배로 키움
    static func enhancedForText(_ image: UIImage) -> UIImage? {
        guard let cgImage = upright(image) else { return nil }
        return enhancedForText(cgImage).map { UIImage(cgImage: $0) }
    }

    // MARK: 사진 반듯하게 펴기

    /// 앨범 사진 속 종이(단어장·문제지)를 찾아 그 부분만 잘라 정면에서 본 것처럼 폄.
    /// 종이를 확실히 찾지 못했거나 이미 사진 전체가 종이면 그대로 둠
    static func straightened(_ image: UIImage) async -> UIImage {
        let base = image.resized(maxDimension: 3000)
        guard let cgImage = base.cgImage, let flat = await straightened(cgImage) else { return base }
        return UIImage(cgImage: flat)
    }

    // MARK: 단어장 읽기

    /// 단어장 사진 → 단어·뜻: 원래 사진과 고대비 사진을 함께 읽어 더 많이 찾은 쪽을 쓰고,
    /// 빠진 뜻은 다른 쪽에서 채운 뒤 영어 철자를 사전으로 확인 (이상하면 "확인 필요")
    @MainActor
    static func readWords(_ image: UIImage) async -> [ParsedWord] {
        guard let cgImage = upright(image) else { return [] }
        return await readWordsUnchecked(cgImage).map(spellChecked)
    }

    /// 영어 철자 확인: 사전에 없는 낱말은 "확인 필요", 한 글자만 다른 단어가 있으면 그걸로 고침 (rn↔m, l↔i 같은 착각)
    @MainActor
    static func spellChecked(_ word: ParsedWord) -> ParsedWord {
        let languages = UITextChecker.availableLanguages
        guard let language = languages.first(where: { $0 == "en_US" }) ?? languages.first(where: { $0.hasPrefix("en") }) else { return word }
        let checker = UITextChecker()
        var result = word
        var term = word.term
        for token in word.term.split(separator: " ").map(String.init) {
            guard token.count >= 3, token.allSatisfy({ $0.isASCII && $0.isLetter }) else { continue }
            let length = (token as NSString).length
            let range = checker.rangeOfMisspelledWord(in: token, range: NSRange(location: 0, length: length), startingAt: 0, wrap: false, language: language)
            guard range.location != NSNotFound else { continue }
            result.unsure = true
            let guesses = checker.guesses(forWordRange: range, in: token, language: language) ?? []
            if let guess = guesses.first(where: { editDistance($0.lowercased(), token.lowercased()) == 1 && !$0.contains(" ") }) {
                let fixed = token.first?.isUppercase == true ? guess : guess.lowercased()
                term = term.replacingOccurrences(of: token, with: fixed)
            }
        }
        result.term = term
        return result
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

// MARK: - 한 사진에 문제 여러 개 자동 나누기

extension OCRService {
    /// 문제집 한 쪽 사진에서 문제 번호를 찾아 문제마다 잘라 줌.
    /// 문제가 2개 미만이면 빈 배열 → 기존 "직접 자르기" 화면으로
    static func splitProblems(_ image: UIImage) async -> (regions: [ProblemSplitter.Region], crops: [UIImage]) {
        // 번호("01", "3.")가 사전 단어로 바뀌지 않게 언어 교정은 끔
        guard let lines = try? await recognize(image, languageCorrection: false) else { return ([], []) }
        let regions = ProblemSplitter.regions(lines: lines)
        guard regions.count >= 2 else { return ([], []) }
        return (regions, image.cropped(toVisionRects: regions.map(\.box)))
    }
}

extension UIImage {
    /// Vision 정규화 좌표(0~1, 원점 왼쪽 아래) 영역마다 잘라냄.
    /// 글자 인식과 같은 기준이 되도록 방향을 바로 세운 이미지(resized)에서 자름
    func cropped(toVisionRects rects: [CGRect], maxDimension: CGFloat = 3000) -> [UIImage] {
        let base = resized(maxDimension: maxDimension)
        guard let cg = base.cgImage else { return rects.map { _ in base } }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let bounds = CGRect(x: 0, y: 0, width: w, height: h)
        return rects.map { rect in
            // 아래 원점 → 위 원점 (CGImage 픽셀 좌표는 위가 0)
            let area = CGRect(x: rect.minX * w, y: (1 - rect.maxY) * h,
                              width: rect.width * w, height: rect.height * h).integral.intersection(bounds)
            guard !area.isNull, area.width >= 1, area.height >= 1, let cropped = cg.cropping(to: area) else { return base }
            return UIImage(cgImage: cropped)
        }
    }
}
