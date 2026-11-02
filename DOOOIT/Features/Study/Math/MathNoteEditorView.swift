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

    /// 문제 확인 → 풀이·학습 → 필기 순서
    enum EditorTab: String, CaseIterable, Identifiable {
        case text = "문제", grade = "풀이·학습", note = "필기"
        var id: String { rawValue }
    }

    private let inkColors: [Color] = [.black, Color(hex: "#2563EB"), Color(hex: "#DC2626"), Color(hex: "#16A34A"), Color(hex: "#F59E0B")]
    private let writingAreaHeight: CGFloat = 760

    var body: some View {
        GeometryReader { geo in
            let pageWidth = max(geo.size.width - 32, 100)
            ScrollView {
                VStack(spacing: 18) {
                    infoCard
                    tabBar

                    switch tab {
                    case .note:
                        page(width: pageWidth)
                    case .grade:
                        // 학습 순서: 채점 → 오답 원인 → 풀이(과정 채점·단계별 풀이) → 유사 문제 → 재도전 → 취약 개념
                        VStack(spacing: 14) {
                            MistakeGradingCard(note: note) { withAnimation(.snappy) { tab = .text } }
                            if note.isRecognitionConfirmed {
                                MistakeAnalysisCard(note: note)
                                WorkCheckCard(note: note)
                                WrittenSolutionCard(note: note)
                                SimilarProblemsCard(note: note)
                                WeakConceptBadge(note: note)
                            }
                        }
                    case .text:
                        recognizedCard
                        ProblemReviewCard(note: note) {
                            withAnimation(.snappy) { isEditingText = true }
                        }
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
        // 문제 글을 고치면 다시 나눔 (흐리게 읽은 줄 표시는 그 줄이 남아 있을 때만)
        .onChange(of: note.recognizedText) { _, text in rescan(text) }
    }

    // MARK: Info

    /// 머리말: 문제 사진 · 제목 · 단원 · 상태
    private var infoCard: some View {
        HStack(alignment: .center, spacing: 14) {
            Color.clear
                .frame(width: 64, height: 64)
                .background { GridPaperBackground() }
                .overlay {
                    if let data = note.thumbnailData, let thumb = UIImage(data: data) {
                        Image(uiImage: thumb).resizable().scaledToFill()
                    } else {
                        Image(systemName: "function").font(.title3).foregroundStyle(Palette.ink.opacity(0.3))
                    }
                }
                .clipShape(.rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.06)))
            VStack(alignment: .leading, spacing: 4) {
                TextField("제목", text: $note.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.ink)
                TextField("단원 (예: 이차함수)", text: $note.unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(note.status.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(note.status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(note.status.color.opacity(0.12), in: .capsule)
        }
        .softCard(cornerRadius: 22, padding: 14)
    }

    /// 밑줄 탭 (문제 · 풀이·학습 · 필기)
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(EditorTab.allCases) { item in
                let isOn = tab == item
                Button {
                    withAnimation(.snappy) { tab = item }
                    Haptics.tap()
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text(item.rawValue)
                            if item == .text && !note.isRecognitionConfirmed {
                                Circle().fill(Palette.warning).frame(width: 6, height: 6)
                            }
                        }
                        .font(.subheadline.weight(isOn ? .bold : .medium))
                        .foregroundStyle(isOn ? Palette.ink : Color.secondary)
                        Capsule()
                            .fill(isOn ? Palette.ink : Color.clear)
                            .frame(width: 32, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
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
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
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
                            Label("다시 읽기 (꼼꼼하게)", systemImage: "text.viewfinder")
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
        let result = await OCRService.readMathProblemDetailed(problem)
        // 새로 읽은 문제는 사용자가 확인하기 전까지 확정하지 않음
        note.isRecognitionConfirmed = false
        apply(result.text, message: result.text.isEmpty ? "글자를 찾지 못했어요. 영역을 넓혀서 다시 골라보세요."
              : result.improved ? "여러 방법으로 읽어서 수식이 가장 자연스러운 결과를 골랐어요. 틀린 곳은 \"고치기\"로 바꿔주세요."
              : "선택한 영역의 인쇄된 글자만 다시 읽었어요.")
        rescan(result.text, unsure: result.unsure)
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
        // 인식 결과를 아직 확인하지 않았으면 문제 탭부터, 확인했으면 풀이·학습부터
        tab = note.isRecognitionConfirmed ? .grade : .text
        if note.scan == nil, !note.recognizedText.isEmpty { rescan(note.recognizedText) }
    }

    private func rescan(_ text: String, unsure: [String]? = nil) {
        let previous = note.scan?.doubts.filter { $0.reason.hasPrefix("글자가") }.map(\.text) ?? []
        let low = (unsure ?? previous).filter { text.contains($0) }
        note.scan = DoitProblemScan.scan(text, lowConfidence: low, graphNote: note.scan?.graphNote)
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
