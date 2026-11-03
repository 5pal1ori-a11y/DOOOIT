import CoreGraphics
import Foundation
import Vision

/// 기본 판독 (모델 없이 Apple Vision + 픽셀 계산): 모티 1·모델 없는 기기에서도 그림을 조금은 읽음
/// - 표: 문서 읽기(RecognizeDocumentsRequest)가 찾은 표 칸
/// - 좌표 그래프: GraphReader가 맞춘 식과 절편·꼭짓점
/// - 도형: ShapeReader가 붙인 꼭짓점 이름·변 길이 (직각은 그림에서 90°에 아주 가까울 때만)
/// 앱(FigureReader)과 맥 확인 도구(Tests/FigureEval)가 같은 코드를 씀 (UIKit 없이)
enum FigureVision {
    /// 사진 속 표들 → 칸 (머리줄 포함, 두 줄·두 칸 이상만)
    static func tables(_ image: CGImage) async -> [[[String]]] {
        guard #available(iOS 26.0, macOS 26.0, *) else { return [] }
        let request = RecognizeDocumentsRequest()
        guard let observations = try? await request.perform(on: image) else { return [] }
        var out: [[[String]]] = []
        for observation in observations {
            for table in observation.document.tables {
                let rows = table.rows.map { row in
                    row.map { $0.content.text.transcript.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces) }
                }
                let width = rows.map(\.count).max() ?? 0
                if rows.count >= 2, width >= 2 { out.append(rows.map { $0 + Array(repeating: "", count: width - $0.count) }) }
            }
        }
        return out
    }

    /// 차트 판독 (글자 위치 + 막대 높이) → "[막대그래프] 1월 30, 2월 45" 한 줄
    static func chartLines(_ labels: [TextLabel], image: PixelImage?, kind: DoitFigureFacts.ChartKind) -> [String] {
        let items = ChartReader.read(labels, image: image)
        guard items.count >= 2 else { return [] }
        let isPie = labels.filter { $0.text.hasSuffix("%") }.count >= 2
        let shown = isPie ? DoitFigureFacts.ChartKind.pie : (kind == .table ? .bar : kind)
        return ["[\(shown.rawValue)] " + items.map { "\($0.label) \(VisionMath.format($0.value))\(isPie ? "%" : "")" }.joined(separator: ", ")]
    }

    /// 그래프 판독 → 줄 (눈금이나 적힌 숫자로 좌표를 맞춘 직선·포물선만)
    static func graphLines(_ graph: GraphAnalysis) -> [String] {
        guard graph.calibrated, graph.kind == .linear || graph.kind == .quadratic, let equation = graph.equation else { return [] }
        var lines = ["그래프의 식은 " + equation.replacingOccurrences(of: "−", with: "-")]
        // 픽셀에서 잰 값이라 정수·0.5 단위로 맞춰 보여 줌 (식과 같은 다듬기)
        func shown(_ v: Double) -> String { VisionMath.format(VisionMath.nice(v)).replacingOccurrences(of: "−", with: "-") }
        for point in graph.keyPoints {
            switch point.name {
            case "y절편": lines.append("y절편 \(shown(point.y))")
            case "x절편": lines.append("x절편 \(shown(point.x))")
            case "꼭짓점": lines.append("꼭짓점 (\(shown(point.x)), \(shown(point.y)))")
            default: continue
            }
        }
        return lines
    }

    /// 그림에 적힌 좌표 "(0, 1)", "(2, 5)" → "지나는 점 …" 한 줄 (식은 확인한 뒤 풀이가 이 점들로 구함)
    static func pointLines(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "，", with: ",")
        var points: [String] = []
        for m in normalized.matches(of: #/\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)/#) {
            let p = "(\(m.1), \(m.2))"
            if !points.contains(p) { points.append(p) }
        }
        return points.count >= 1 ? ["지나는 점 " + points.joined(separator: ", ")] : []
    }

    /// 도형 판독 → 줄 (꼭짓점 이름이 붙은 삼각형의 변 길이, 원의 반지름)
    static func shapeLines(_ shapes: [ShapeAnalysis]) -> [String] {
        var lines: [String] = []
        for shape in shapes.prefix(2) {
            let n = shape.vertices.count
            if shape.kind == .circle {
                if let r = shape.sideLabels[0] { lines.append("원의 반지름 = \(VisionMath.format(r))") }
                continue
            }
            guard n >= 3, n <= 4 else { continue }
            let names = (0..<n).compactMap { shape.vertexNames[$0] }
            if names.count == n, n == 3 { lines.append("△" + names.sorted().joined()) }
            if names.count == n, n == 4 { lines.append("사각형 " + names.joined()) }
            for i in 0..<n {
                guard let value = shape.sideLabels[i], let a = shape.vertexNames[i], let b = shape.vertexNames[(i + 1) % n] else { continue }
                lines.append(GeometryText.segment(String([a, b].sorted().joined())) + " = " + VisionMath.format(value))
            }
            if n == 3 {
                for i in 0..<3 where abs(shape.angles[i] - 90) < 2 {
                    if let name = shape.vertexNames[i] { lines.append("∠\(name) = 90°") }
                }
            }
        }
        var seen = Set<String>()
        return lines.filter { seen.insert($0).inserted }
    }
}
