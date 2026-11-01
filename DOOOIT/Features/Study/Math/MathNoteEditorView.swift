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
    @State private var isRecognizing = false
    @State private var tab: EditorTab = .note
    @State private var cropItem: CropItem?
    @State private var previousText: String?
    @State private var textMessage: String?
    @State private var textSelection: TextSelection?
    @State private var isEditingText = false

    enum EditorTab: String, CaseIterable, Identifiable {
        case note = "필기", grade = "채점 · 풀이", text = "문제"
        var id: String { rawValue }
    }

    private let inkColors: [Color] = [.black, Color(hex: "#2563EB"), Color(hex: "#DC2626"), Color(hex: "#16A34A"), Color(hex: "#F59E0B")]
    private let writingAreaHeight: CGFloat = 760

    var body: some View {
        GeometryReader { geo in
            let pageWidth = max(geo.size.width - 32, 100)
            ScrollView {
                VStack(spacing: 16) {
                    infoCard
                    Picker("보기", selection: $tab.animation(.snappy)) {
                        ForEach(EditorTab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch tab {
                    case .note:
                        page(width: pageWidth)
                    case .grade:
                        gradingCard
                        WrittenSolutionCard(note: note)
                        SimilarProblemsCard(note: note)
                    case .text:
                        recognizedCard
                    }
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
                if tab == .note {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isDrawing.toggle() }
                    } label: {
                        Label(isDrawing ? "완료" : "필기", systemImage: isDrawing ? "checkmark" : "pencil.tip.crop.circle")
                    }
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
        .onChange(of: tab) { _, newTab in
            if newTab != .note { isDrawing = false }
        }
        .sheet(item: $cropItem) { item in
            ProblemCropView(image: item.image) { problem in
                cropItem = nil
                Task { await recognize(problem) }
            } onCancel: {
                cropItem = nil
            }
        }
        .onAppear(perform: load)
        .onDisappear(perform: save)
    }

    // MARK: Info

    private var infoCard: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("제목", text: $note.title)
                    .font(.headline)
                TextField("단원 (예: 이차함수, 계산 실수)", text: $note.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TagLabel(text: note.status.title, symbol: note.status.symbol, color: note.status.color)
        }
        .padding(.horizontal, 4)
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
                        .fill(Theme.accent.opacity(0.35))
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
            .background(isDrawing && tool == .text ? Theme.accent.opacity(0.12) : Color.clear, in: .rect(cornerRadius: 6))
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
                            .background(tool == item ? Theme.accent : Color.clear, in: .rect(cornerRadius: 14))
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
                answerField(title: "정답", text: $note.correctAnswer, placeholder: "정답 (사진에 있으면 자동으로 채워져요)")
            }

            HStack(spacing: 10) {
                gradeButton(title: "맞았어요", symbol: "circle", color: Palette.success, status: .correct)
                gradeButton(title: "틀렸어요", symbol: "xmark", color: Palette.danger, status: .wrong)
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

    private func gradeButton(title: String, symbol: String, color: Color, status: NoteStatus) -> some View {
        let isOn = note.status == status
        return Button { setStatus(status) } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isOn ? Color.white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isOn ? color : color.opacity(0.12), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func setStatus(_ status: NoteStatus) {
        withAnimation(.snappy) { note.status = status }
        note.updatedAt = Date()
        try? context.save()
        if status == .correct { Haptics.success() } else { Haptics.error() }
    }

    // MARK: Recognized text

    private var recognizedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            problemSheet

            if let textMessage {
                Label(textMessage, systemImage: isRecognizing ? "hourglass" : "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
        }
    }

    /// 문제를 종이처럼 보여주고, "고치기"를 누르면 편집 + 수식 기호 바
    private var problemSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill").foregroundStyle(Theme.accent)
                Text("문제").font(.headline).foregroundStyle(Palette.ink)
                if isRecognizing { ProgressView().controlSize(.small) }
                Spacer()
                Menu {
                    if let problemImage {
                        Button {
                            Task { await recognize(problemImage) }
                        } label: {
                            Label(DoitAppleAI.isAvailable ? "다시 읽기 (Apple Intelligence로 다듬기)" : "다시 읽기", systemImage: "text.viewfinder")
                        }
                    }
                    if let image {
                        Button { cropItem = CropItem(image: image) } label: {
                            Label("문제 영역 다시 고르기", systemImage: "crop")
                        }
                    }
                    if let previousText {
                        Button {
                            let current = note.recognizedText
                            note.recognizedText = previousText
                            self.previousText = current
                            withAnimation { textMessage = "이전 글로 되돌렸어요." }
                        } label: {
                            Label("되돌리기", systemImage: "arrow.uturn.backward")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.06), in: .circle)
                        .foregroundStyle(Palette.ink)
                }
                .disabled(isRecognizing)
                Button {
                    withAnimation(.snappy) { isEditingText.toggle() }
                } label: {
                    Label(isEditingText ? "완료" : "고치기", systemImage: isEditingText ? "checkmark" : "pencil")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.12), in: .capsule)
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            if isEditingText {
                TextEditor(text: $note.recognizedText, selection: $textSelection)
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.ink)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.black.opacity(0.04), in: .rect(cornerRadius: 14))
                MathSymbolBar { symbol in insertSymbol(symbol) }
                Text("x² 는 ^2, 루트는 √( ) 로 써도 보기 좋게 바뀌어요.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if note.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("아직 읽은 문제가 없어요. \"고치기\"를 눌러 직접 입력해주세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(MathSymbolBar.pretty(note.recognizedText))
                    .font(.system(size: 18, design: .serif))
                    .lineSpacing(8)
                    .foregroundStyle(Palette.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .background(Color.white, in: .rect(cornerRadius: 22))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22)
                .fill(Theme.accent)
                .frame(width: 5)
        }
        .clipShape(.rect(cornerRadius: 22))
        .shadow(color: .black.opacity(0.07), radius: 14, y: 6)
    }

    private func insertSymbol(_ symbol: MathSymbolBar.Symbol) {
        var text = note.recognizedText
        var insertAt = text.endIndex
        var replaceRange = text.endIndex..<text.endIndex
        if let selection = textSelection, case .selection(let range) = selection.indices {
            replaceRange = range
            insertAt = range.lowerBound
        }
        let offset = text.distance(from: text.startIndex, to: insertAt)
        text.replaceSubrange(replaceRange, with: symbol.insert)
        note.recognizedText = text
        let caret = text.index(text.startIndex, offsetBy: min(offset + symbol.caretOffset, text.count))
        textSelection = TextSelection(insertionPoint: caret)
    }

    private var problemImage: UIImage? {
        note.problemImageData.flatMap(UIImage.init(data:)) ?? image
    }

    private func apply(_ text: String, message: String) {
        previousText = note.recognizedText
        note.recognizedText = text
        if note.correctAnswer.isEmpty, let answer = MathGrader.extractAnswer(from: text) {
            note.correctAnswer = answer
        }
        withAnimation { textMessage = message }
    }

    private func recognize(_ problem: UIImage) async {
        isRecognizing = true
        defer { isRecognizing = false }
        note.thumbnailData = problem.jpegForStorage(maxDimension: 400, quality: 0.6)
        note.problemImageData = problem.jpegForStorage(maxDimension: 2000, quality: 0.85)
        let result = await OCRService.readMathProblem(problem)
        apply(result.text, message: result.text.isEmpty ? "글자를 찾지 못했어요. 영역을 넓혀서 다시 골라보세요."
              : result.usedAI ? "인쇄된 글자를 읽고 Apple Intelligence가 수식을 다듬었어요. 틀린 곳은 \"고치기\"로 바꿔주세요."
              : "선택한 영역의 인쇄된 글자만 다시 읽었어요.")
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
