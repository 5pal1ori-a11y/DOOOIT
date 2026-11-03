import UIKit

// 그림 읽기 iOS 형 검사용 가짜 (MLX 패키지·앱 전체 없이 FigureReader · VisionAnalyzer · FigureVision만 검사)
extension UIImage {
    func preparedForOCR(maxDimension: CGFloat = 2400) -> UIImage { self }
}

@MainActor final class PaddleOCRService {
    static let shared = PaddleOCRService()
    func tableText(cgImage: CGImage, chart: Bool) async -> String? { nil }
    func unload() {}
}

@MainActor final class DoitVision {
    static let shared = DoitVision()
    enum Phase: Equatable { case idle, loading, reading, failed(String) }
    var phase: Phase = .idle
    var isAvailable: Bool { false }
    func unload() {}
}
