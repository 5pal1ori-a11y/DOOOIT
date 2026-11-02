import UIKit

/// 수학이 아닌 과목의 문제 사진 읽기: 한글·영어 문장을 그대로 (수식 교정을 하지 않아 영어 문장이 바뀌지 않음)
/// 실제 읽기는 OCRCore의 readSubjectProblem (맥 사진 테스트에서도 같은 코드)
enum SubjectOCR {
    /// 읽은 글 + 흐리게 읽은 줄
    static func read(_ image: UIImage) async -> (text: String, unsure: [String]) {
        guard let cgImage = image.resized(maxDimension: 3000).cgImage else { return ("", []) }
        let read = await OCRService.readSubjectProblem(cgImage)
        return (read.text, read.unsure)
    }
}
