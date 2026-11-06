import UIKit

/// 문제 사진의 그림·그래프·차트·표를 읽어 "[그림에서 읽음]" 줄로 (기계가 읽은 값: 문제 탭에서 학생이 확인한 뒤에만 풀이에 씀)
/// - 표·차트: 정밀 인식(PaddleOCR-VL)의 표/차트 읽기 → 안 되면 모티 2 사진 읽기(차트) → Vision 문서 읽기의 표
/// - 도형·좌표 그래프: 모티 2 사진 읽기(8GB 기기 + 모티 2) → 안 되면 기본 판독(그래프 식, 도형 이름·길이)
/// 큰 모델은 한 번에 하나만 메모리에 둠 (정밀 인식을 쓰기 전에 모티 2 사진 모델을, 그 반대도 내림)
@MainActor
enum FigureReader {
    /// 지금 무엇을 하는지 (진행 표시에 씀)
    static var status: String {
        switch DoitVision.shared.phase {
        case .loading: return "모티 2가 그림을 볼 준비를 하고 있어요"
        case .reading: return "모티 2가 그림을 읽고 있어요"
        default: return "문제를 분석하고 있어요"
        }
    }

    /// - problemText: 사진에서 읽은 문제 글 (어떤 그림인지 고르는 데 씀)
    /// - analysis: VisionAnalyzer 결과 (있으면 기본 판독에 씀)
    /// - figures: false면 표·차트만 (수학이 아닌 과목의 과학 그림 등은 줄 모양이 맞지 않아서)
    static func read(_ image: UIImage, problemText: String, analysis: ImageAnalysis? = nil, figures: Bool = true) async -> DoitFigureFacts.Reading? {
        var route = DoitFigureFacts.route(problemText)
        // 글에 도형 말이 있으면 좌표축처럼 보여도 도형 (직각삼각형의 두 변을 좌표축으로 보지 않게)
        if route == .none, analysis?.kind == .graph { route = .graph }
        if route == .none, analysis?.kind == .figure { route = .geometry }
        guard route != .none else { return nil }
        if !figures, route == .graph || route == .geometry { return nil }
        guard let cgImage = image.preparedForOCR(maxDimension: 1600).cgImage else { return nil }

        switch route {
        case .table, .chart:
            let kind: DoitFigureFacts.ChartKind = route == .table ? .table : chartKind(problemText)
            DoitVision.shared.unload()
            if let raw = await PaddleOCRService.shared.tableText(cgImage: cgImage, chart: route == .chart) {
                let lines = DoitFigureFacts.tableLines(DoitFigureFacts.parseTable(raw), kind: kind)
                if !lines.isEmpty { return .init(kind: route == .table ? .table : .chart, lines: lines, source: "정밀 인식") }
            }
            if route == .chart, figures, let seen = await vision(cgImage), seen.kind == .chart || seen.kind == .table { return seen }
            if let table = await FigureVision.tables(cgImage).first {
                let lines = DoitFigureFacts.tableLines(table, kind: kind)
                if !lines.isEmpty { return .init(kind: .table, lines: lines, source: "기본 판독") }
            }
            if route == .chart {
                let seen: ImageAnalysis
                if let analysis { seen = analysis } else { seen = await VisionAnalyzer.analyze(image) }
                let lines = FigureVision.chartLines(seen.textLabels, image: seen.pixels, kind: kind)
                if !lines.isEmpty { return .init(kind: .chart, lines: lines, source: "기본 판독") }
            }
            return nil
        case .graph, .geometry:
            if let seen = await vision(cgImage) { return seen }
            if route == .graph {
                // 그림에 적힌 절편·꼭짓점·좌표로 식이 정해지면 그 값만, 아니면 그래프 판독 식 + 적힌 좌표
                var lines: [String]
                if let analysis {
                    lines = FigureVision.graphFacts(analysis.textLabels, pixels: analysis.pixels, graph: analysis.graph, problem: problemText)
                    if lines.isEmpty { lines = FigureVision.pointLines(analysis.text) }
                } else {
                    lines = FigureVision.pointLines(problemText)
                }
                if !lines.isEmpty { return .init(kind: .graph, lines: lines, source: "기본 판독") }
            }
            var shapes = analysis?.shapes ?? []
            // 그래프로 판독한 그림(직각을 낀 두 변이 축처럼 보임)은 도형을 따로 찾음
            if shapes.isEmpty, let analysis, analysis.kind == .graph, let pixels = analysis.pixels {
                let minArea = Double(pixels.width * pixels.height) * 0.03
                shapes = ShapeReader.analyze(pixels, labels: analysis.textLabels).filter { $0.bounds.w * $0.bounds.h >= minArea }
                if shapes.count > 6 { shapes = [] }
            }
            let lines = FigureVision.shapeLines(shapes, problem: problemText)
            return lines.isEmpty ? nil : .init(kind: .geometry, lines: lines, source: "기본 판독")
        case .none:
            return nil
        }
    }

    /// 모티 2 사진 읽기 (쓸 수 없으면 nil)
    private static func vision(_ cgImage: CGImage) async -> DoitFigureFacts.Reading? {
        #if canImport(MLXVLM)
        guard DoitVision.shared.isAvailable else { return nil }
        PaddleOCRService.shared.unload()
        return await DoitVision.shared.read(cgImage)
        #else
        return nil
        #endif
    }

    private static func chartKind(_ text: String) -> DoitFigureFacts.ChartKind {
        let t = text.replacingOccurrences(of: " ", with: "")
        if t.contains("꺾은선") { return .line }
        if t.contains("원그래프") || t.contains("띠그래프") || t.contains("비율") { return .pie }
        return .bar
    }
}
