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
        VStack(alignment: .leading, spacing: 16) {
            problemSheet

            if let textMessage {
                Label(textMessage, systemImage: isRecognizing ? "hourglass" : "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("다시 읽기")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                if ClaudeReader.isConfigured {
                    Button { Task { await readWithClaude() } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(0.22), in: .circle)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Claude로 정확하게 읽기").font(.headline)
                                Text("사진을 직접 보고 루트·분수·변수까지 읽어요").font(.caption).opacity(0.85)
                            }
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Theme.accent, in: .rect(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    if image != nil {
                        readOption(symbol: "crop", title: "영역 다시 고르기") {
                            if let image { cropItem = CropItem(image: image) }
                        }
                    }
                    readOption(symbol: "wand.and.stars", title: "기기 AI로 다듬기") {
                        Task { await tidyWithAI() }
                    }
                }

                if previousText != nil {
                    Button {
                        if let previousText { note.recognizedText = previousText }
                        previousText = nil
                        textMessage = "이전 텍스트로 되돌렸어요."
                    } label: {
                        Label("이전 텍스트로 되돌리기", systemImage: "arrow.uturn.backward")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 4)
                }
            }
            .disabled(isRecognizing)
            .opacity(isRecognizing ? 0.5 : 1)
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
                Text("아직 읽은 문제가 없어요. 아래 \"다시 읽기\"로 사진에서 문제를 읽어주세요.")
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

    private func readOption(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
    }

    /// 커서 위치에 수식 기호 넣기 (괄호 안에 커서를 둠)
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
        if ClaudeReader.isConfigured, let result = try? await ClaudeReader.read(problem) {
            if note.correctAnswer.isEmpty, !result.answer.isEmpty { note.correctAnswer = result.answer }
            apply(result.text, message: "Claude가 선택한 영역을 읽었어요.")
            return
        }
        let lines = (try? await OCRService.recognize(problem)) ?? []
        let text = MathOCRFixer.fix(OCRService.printedText(from: lines))
        apply(text, message: text.isEmpty ? "글자를 찾지 못했어요. 영역을 넓혀서 다시 골라보세요." : "선택한 영역의 인쇄된 글자만 다시 읽었어요.")
    }

    /// 서버의 Claude가 사진을 직접 보고 읽음
    private func readWithClaude() async {
        guard let source = problemImage else {
            textMessage = "읽을 사진이 없어요."
            return
        }
        isRecognizing = true
        defer { isRecognizing = false }
        withAnimation { textMessage = "Claude가 사진을 읽는 중이에요… (10~20초)" }
        do {
            let result = try await ClaudeReader.read(source)
            if note.correctAnswer.isEmpty, !result.answer.isEmpty { note.correctAnswer = result.answer }
            if note.title.hasPrefix("오답") || note.title.isEmpty, !result.title.isEmpty { note.title = result.title }
            apply(result.text, message: "Claude가 사진을 직접 보고 읽었어요.")
        } catch {
            withAnimation { textMessage = error.localizedDescription }
        }
    }

    /// 기기 안: 사진을 여러 방법으로 다시 읽고, AI가 결과들을 비교해 문제 문장을 복원 (풀지 않음)
    private func tidyWithAI() async {
        isRecognizing = true
        defer { isRecognizing = false }
        let original = note.recognizedText

        var readings: [String] = []
        if let source = problemImage {
            withAnimation { textMessage = "사진을 네 가지 방법으로 다시 읽는 중이에요…" }
            readings = await OCRService.multiPassRead(source).map(MathOCRFixer.fix)
        }
        if readings.isEmpty && original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            withAnimation { textMessage = "사진에서 글자를 찾지 못했어요. 문제 영역을 다시 골라보세요." }
            return
        }
        withAnimation { textMessage = "기기 AI가 \(max(readings.count, 1))개의 읽기 결과를 비교하는 중이에요…" }

        do {
            let prompt = readings.isEmpty
                ? AITutor.reconstructPrompt(readings: [original], current: "")
                : AITutor.reconstructPrompt(readings: readings, current: original)
            let tidy = MathOCRFixer.fix(try await AITutor.answer(prompt).trimmingCharacters(in: .whitespacesAndNewlines))
            guard !tidy.isEmpty else { return }
            apply(tidy, message: "기기 AI가 정리했어요. [?] 표시와 숫자가 사진과 같은지 확인하세요.")
        } catch {
            withAnimation { textMessage = error.localizedDescription }
        }
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
