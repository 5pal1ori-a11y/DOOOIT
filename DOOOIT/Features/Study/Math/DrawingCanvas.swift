import PencilKit
import SwiftUI

enum DrawTool: String, CaseIterable, Identifiable {
    case pen, highlighter, eraser, lasso, text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pen: return L("펜")
        case .highlighter: return L("형광펜")
        case .eraser: return L("지우개")
        case .lasso: return L("올가미")
        case .text: return L("텍스트")
        }
    }

    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        case .text: return "textformat"
        }
    }
}

/// PKCanvasView에 접근하기 위한 참조 (실행 취소 / 다시 실행)
final class CanvasController {
    weak var canvas: PKCanvasView?

    func undo() { canvas?.undoManager?.undo() }
    func redo() { canvas?.undoManager?.redo() }
    func clear() { canvas?.drawing = PKDrawing() }
}

/// PencilKit 캔버스 (손가락으로도 필기 가능)
struct DrawingCanvas: UIViewRepresentable {
    let initialData: Data?
    let tool: DrawTool
    let color: Color
    let width: CGFloat
    let isEnabled: Bool
    let controller: CanvasController
    var onChange: (PKDrawing) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.overrideUserInterfaceStyle = .light // 흰 종이 위이므로 색 반전 방지
        if let initialData, let drawing = try? PKDrawing(data: initialData) {
            canvas.drawing = drawing
        }
        canvas.delegate = context.coordinator
        canvas.tool = pkTool
        canvas.isUserInteractionEnabled = isEnabled
        controller.canvas = canvas
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.onChange = onChange
        canvas.tool = pkTool
        canvas.isUserInteractionEnabled = isEnabled
    }

    private var pkTool: PKTool {
        let uiColor = UIColor(color)
        switch tool {
        case .pen:
            return PKInkingTool(.pen, color: uiColor, width: width)
        case .highlighter:
            return PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.45), width: width * 6)
        case .eraser:
            return PKEraserTool(.vector)
        case .lasso:
            return PKLassoTool()
        case .text:
            return PKInkingTool(.pen, color: uiColor, width: width)
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onChange: (PKDrawing) -> Void

        init(onChange: @escaping (PKDrawing) -> Void) {
            self.onChange = onChange
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onChange(canvasView.drawing)
        }
    }
}
