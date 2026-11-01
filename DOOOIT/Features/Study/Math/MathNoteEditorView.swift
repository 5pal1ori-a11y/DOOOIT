import PencilKit
import SwiftData
import SwiftUI

/// 오답노트 편집: 문제 사진 위에 펜/형광펜/지우개/올가미/텍스트로 필기 + 채점
struct MathNoteEditorView: View {
    @Bindable var note: MathNote

    @Environment(\.modelContext) private var context

    @State private var image: UIImage?
    @State private var isDrawing = false
    @State private var tool: DrawTool = .pen
    @State private var inkColor: Color = .black
    @State private var penWidth: CGFloat = 3
    @State private var controller = CanvasController()
    @State private var annotations: [TextAnnotation] = []

    @State private var pendingTextLocation: CGPoint?
    @State private var editingAnnotationID: UUID?
    @State private var textInput = ""
    @State private var showTextAlert = false
    @State private var gradeMessage: String?
    @State private var isRecognizing = false

    private let inkColors: [Color] = [.black, Color(hex: "#2563EB"), Color(hex: "#DC2626"), Color(hex: "#16A34A"), Color(hex: "#F59E0B")]
    private let writingAreaHeight: CGFloat = 760

    var body: some View {
        GeometryReader { geo in
            let pageWidth = max(geo.size.width - 32, 100)
            ScrollView {
                VStack(spacing: 18) {
                    infoCard
                    page(width: pageWidth)
                    gradingCard
                    WrittenSolutionCard(note: note)
                    recognizedCard
                }
                .padding(16)
                .padding(.bottom, isDrawing ? 150 : 40)
            }
            .scrollDisabled(isDrawing)
            .scrollDismissesKeyboard(.interactively)
        }
        .background { AppBackground() }
        .navigationTitle(note.title.isEmpty ? "오답노트" : note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isDrawing.toggle() }
                } label: {
                    Label(isDrawing ? "완료" : "필기", systemImage: isDrawing ? "checkmark" : "pencil.tip.crop.circle")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if isDrawing {
                toolPalette
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert(editingAnnotationID == nil ? "텍스트 추가" : "텍스트 수정", isPresented: $showTextAlert) {
            TextField("내용", text: $textInput)
            Button("취소", role: .cancel) { resetTextEditing() }
            if editingAnnotationID != nil {
                Button("삭제", role: .destructive) {
                    annotations.removeAll { $0.id == editingAnnotationID }
                    saveAnnotations()
                    resetTextEditing()
                }
            }
            Button("확인") { commitText() }
        }
        .onAppear(perform: load)
        .onDisappear(perform: save)
    }

    // MARK: Info

    private var infoCard: some View {
        VStack(spacing: 10) {
            TextField("제목", text: $note.title)
                .font(.headline)
            Divider()
            TextField("단원 / 메모 (예: 이차함수, 계산 실수)", text: $note.unit)
                .font(.subheadline)
        }
        .glassCard(cornerRadius: 20, padding: 16)
    }

    // MARK: Page

    private func page(width: CGFloat) -> some View {
        let imageHeight: CGFloat = image.map { width * $0.size.height / max($0.size.width, 1) } ?? 0
        let height = imageHeight + writingAreaHeight

        return ZStack(alignment: .topLeading) {
            GridPaperBackground()

            VStack(alignment: .leading, spacing: 0) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: width, height: imageHeight)
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.35))
                        .frame(height: 2)
                }
                Text("풀이")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.ink.opacity(0.4))
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
            }

            DrawingCanvas(
                initialData: note.drawingData,
                tool: tool,
                color: inkColor,
                width: penWidth,
                isEnabled: isDrawing && tool != .text,
                controller: controller
            ) { drawing in
                note.drawingData = drawing.dataRepresentation()
                note.updatedAt = Date()
            }

            if isDrawing && tool == .text {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in
                        pendingTextLocation = location
                        editingAnnotationID = nil
                        textInput = ""
                        showTextAlert = true
                    }
            }

            ForEach(annotations) { annotation in
                annotationView(annotation)
            }
        }
        .frame(width: width, height: height)
        .clipShape(.rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 14, y: 8)
    }

    private func annotationView(_ annotation: TextAnnotation) -> some View {
        Text(annotation.text)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color(hex: annotation.colorHex))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isDrawing && tool == .text ? Color.accentColor.opacity(0.12) : Color.clear, in: .rect(cornerRadius: 6))
            .position(x: annotation.x, y: annotation.y)
            .onTapGesture {
                guard isDrawing && tool == .text else { return }
                editingAnnotationID = annotation.id
                textInput = annotation.text
                showTextAlert = true
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard isDrawing && tool == .text,
                              let idx = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
                        annotations[idx].x = value.location.x
                        annotations[idx].y = value.location.y
                    }
                    .onEnded { _ in saveAnnotations() },
                including: isDrawing && tool == .text ? .all : .subviews
            )
    }

    // MARK: Tool palette

    private var toolPalette: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ForEach(inkColors, id: \.self) { color in
                        Button { inkColor = color } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 26, height: 26)
                                .overlay {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: inkColor == color ? 2.5 : 0)
                                        .padding(-4)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    Divider().frame(height: 24)
                    Menu {
                        Picker("굵기", selection: $penWidth) {
                            Text("얇게").tag(CGFloat(2))
                            Text("보통").tag(CGFloat(3))
                            Text("굵게").tag(CGFloat(6))
                        }
                    } label: {
                        Image(systemName: "lineweight")
                            .font(.headline)
                            .frame(width: 30, height: 30)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)

                HStack(spacing: 4) {
                    ForEach(DrawTool.allCases) { item in
                        Button {
                            tool = item
                            Haptics.tap()
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                Text(item.title)
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .frame(width: 46, height: 44)
                            .foregroundStyle(tool == item ? Color.white : Color.primary)
                            .background(tool == item ? Color.accentColor : Color.clear, in: .rect(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    Divider().frame(height: 28).padding(.horizontal, 2)
                    Button { controller.undo() } label: {
                        Image(systemName: "arrow.uturn.backward").frame(width: 36, height: 44)
                    }
                    .buttonStyle(.plain)
                    Button { controller.redo() } label: {
                        Image(systemName: "arrow.uturn.forward").frame(width: 36, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
        }
    }

    // MARK: Grading

    private var gradingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "채점", symbol: "checkmark.seal.fill") {
                TagLabel(text: note.status.title, symbol: note.status.symbol, color: note.status.color)
            }

            VStack(spacing: 10) {
                answerField(title: "내 답", text: $note.myAnswer, placeholder: "풀이 후 답을 입력")
                answerField(title: "정답", text: $note.correctAnswer, placeholder: "정답 (사진에서 자동 인식 시 채워져요)")
            }

            HStack(spacing: 10) {
                Button(action: autoGrade) {
                    Label("자동 채점", systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)

                Button { setStatus(.correct) } label: {
                    Image(systemName: "circle")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Palette.success)
                        .frame(width: 30)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("정답으로 표시")

                Button { setStatus(.wrong) } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Palette.danger)
                        .frame(width: 30)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("오답으로 표시")
            }

            if let gradeMessage {
                Text(gradeMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .glassCard()
    }

    private func answerField(title: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(width: 40, alignment: .leading)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 14))
    }

    private func autoGrade() {
        switch MathGrader.grade(myAnswer: note.myAnswer, correctAnswer: note.correctAnswer) {
        case .some(true):
            setStatus(.correct)
            withAnimation { gradeMessage = "정답이에요! 잘했어요." }
        case .some(false):
            setStatus(.wrong)
            withAnimation { gradeMessage = "아쉽지만 오답이에요. 풀이를 다시 확인해보세요." }
        case .none:
            Haptics.error()
            withAnimation {
                gradeMessage = note.myAnswer.isEmpty
                    ? "내 답을 먼저 입력해주세요."
                    : "등록된 정답이 없어 자동 채점을 할 수 없어요. 정답을 입력하거나 O / X 버튼으로 직접 채점해주세요."
            }
        }
    }

    private func setStatus(_ status: NoteStatus) {
        withAnimation(.snappy) { note.status = status }
        note.updatedAt = Date()
        try? context.save()
        if status == .correct { Haptics.success() } else { Haptics.error() }
    }

    // MARK: Recognized text

    private var recognizedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "인식된 문제 텍스트", symbol: "text.viewfinder") {
                if image != nil {
                    Button {
                        Task { await recognizeAgain() }
                    } label: {
                        if isRecognizing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRecognizing)
                }
            }
            if note.recognizedText.isEmpty {
                Text("인식된 텍스트가 없어요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(note.recognizedText)
                    .font(.subheadline)
                    .textSelection(.enabled)
            }
        }
        .glassCard()
    }

    private func recognizeAgain() async {
        guard let image else { return }
        isRecognizing = true
        let lines = (try? await OCRService.recognize(image)) ?? []
        note.recognizedText = OCRService.plainText(from: lines)
        if note.correctAnswer.isEmpty, let answer = MathGrader.extractAnswer(from: note.recognizedText) {
            note.correctAnswer = answer
        }
        isRecognizing = false
    }

    // MARK: Text annotations

    private func commitText() {
        let text = textInput.trimmingCharacters(in: .whitespaces)
        defer { resetTextEditing() }
        guard !text.isEmpty else { return }

        if let id = editingAnnotationID, let idx = annotations.firstIndex(where: { $0.id == id }) {
            annotations[idx].text = text
        } else if let location = pendingTextLocation {
            annotations.append(TextAnnotation(text: text, x: location.x, y: location.y, colorHex: hexString(inkColor)))
        }
        saveAnnotations()
    }

    private func resetTextEditing() {
        pendingTextLocation = nil
        editingAnnotationID = nil
        textInput = ""
    }

    private func hexString(_ color: Color) -> String {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    // MARK: Persistence

    private func load() {
        if image == nil, let data = note.imageData {
            image = UIImage(data: data)
        }
        annotations = note.annotations
    }

    private func saveAnnotations() {
        note.annotations = annotations
        note.updatedAt = Date()
    }

    private func save() {
        saveAnnotations()
        try? context.save()
    }
}
