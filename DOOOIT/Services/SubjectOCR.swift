import UIKit

/// 수학이 아닌 과목의 문제 사진 읽기: 한글·영어 문장을 그대로 (수식 교정을 하지 않아 영어 문장이 바뀌지 않음)
enum SubjectOCR {
    /// 읽은 글 + 흐리게 읽은 줄
    static func read(_ image: UIImage) async -> (text: String, unsure: [String]) {
        var best: [OCRLine] = []
        var bestScore = -1.0
        // 펜 자국을 지운 사진과 원본 중 더 잘 읽힌 쪽
        for candidate in [OCRService.inkOnly(image), image].compactMap({ $0 }) {
            let lines = ((try? await OCRService.recognize(candidate)) ?? [])
                .filter { $0.confidence >= 0.3 && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            let score = lines.reduce(0.0) { $0 + Double($1.text.count) * Double($1.confidence) }
            if score > bestScore { best = lines; bestScore = score }
        }
        let text = OCRService.plainText(from: best)
        let unsure = best.filter { $0.confidence < 0.5 }.map { $0.text.trimmingCharacters(in: .whitespaces) }
        return (text, unsure)
    }
}
