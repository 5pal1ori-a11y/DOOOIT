import UIKit

/// 수학이 아닌 과목의 문제 사진 읽기: 한글·영어 문장을 그대로 (수식 교정을 하지 않아 영어 문장이 바뀌지 않음)
/// 실제 읽기는 OCRCore의 readSubjectProblem (맥 사진 테스트에서도 같은 코드)
enum SubjectOCR {
    /// 읽은 글 + 흐리게 읽은 줄
    /// 정밀 인식(PaddleOCR-VL)을 받아 두었으면 그걸로 먼저, 안 되면 Vision
    static func read(_ image: UIImage) async -> (text: String, unsure: [String]) {
        guard let cgImage = image.resized(maxDimension: 3000).cgImage else { return ("", []) }
        if let text = await PaddleOCRService.shared.problemText(image, cgImage: cgImage, purpose: .subjectProblem) {
            return (DoitProblemScan.numbered(text), [])
        }
        let read = await OCRService.readSubjectProblem(cgImage)
        return (DoitProblemScan.numbered(read.text), read.unsure)
    }
}
