import PencilKit
import PhotosUI
import SwiftData
import SwiftUI

/// AI에게 질문하기 목록
struct AskAIListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \AIQuestion.createdAt, order: .reverse) private var questions: [AIQuestion]
    @State private var showComposer = false

    var body: some View {
        List {
            if questions.isEmpty {
                EmptyStateView(symbol: "questionmark.circle", title: L("궁금한 걸 물어보세요"))
                    .listRowBackground(Color.clear)
            }
            ForEach(questions) { item in
                NavigationLink { AIQuestionDetailView(item: item) } label: {
                    HStack(spacing: 12) {
                        IconBadge(symbol: item.imageData != nil ? "photo.fill" : "questionmark.circle.fill",
                                  color: item.helpful > 0 ? Palette.success : Theme.accent, size: 38)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                TagLabel(text: item.subject.isEmpty ? L("질문") : item.subject)
                                Text(item.createdAt.ui("M.d")).font(.pt(.caption)).foregroundStyle(.secondary)
                            }
                            Text(item.question).font(.pt(.subheadline).weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete { offsets in
                for i in offsets { context.delete(questions[i]) }
                try? context.save()
            }
        }
        .scrollContentBackground(.hidden)
        .animation(Motion.spring, value: questions.count)
        .background { AppBackground() }
        .navigationTitle("AI에게 질문하기")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showComposer = true } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel("새 질문")
            }
        }
        .sheet(isPresented: $showComposer) { AskAIComposer() }
    }
}

/// 질문 작성 → AI 답변 생성 → 저장
struct AskAIComposer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var subject = "수학"
    @State private var text = ""
    @State private var image: UIImage?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showPicker = false
    @State private var showScanner = false
    @State private var working = false
    @State private var error: String?

    private let subjects = ["국어", "영어", "수학", "과학", "사회", "기타"]

    var body: some View {
        NavigationStack {
            Form {
                Section("과목") {
                    Picker("과목", selection: $subject) {
                        ForEach(subjects, id: \.self) { Text($0.loc).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    TextField("무엇이 궁금한가요? (예: 전체 지문 해설이 필요해요)", text: $text, axis: .vertical)
                        .lineLimit(4...10)
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    HStack {
                        Button { if DocumentScanner.isSupported { showScanner = true } else { showPicker = true } } label: {
                            Label("문제 촬영", systemImage: "camera.fill")
                        }
                        Spacer()
                        Button { showPicker = true } label: { Label("앨범", systemImage: "photo.on.rectangle") }
                    }
                    .buttonStyle(.borderless)
                } footer: {
                    Text("AI 답은 틀릴 수 있어요")
                }
            }
            .navigationTitle("새 질문")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("질문하기") { Task { await ask() } }
                        .fontWeight(.bold)
                        .disabled(working || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && image == nil))
                }
            }
            .imageInput(showScanner: $showScanner, showPhotoPicker: $showPicker, photoItems: $photoItems, maxPhotos: 1) { images in
                image = images.first
            }
            .overlay { if working { ProcessingOverlay(message: L("AI 선생님이 답을 쓰고 있어요")) } }
            .errorAlert($error)
        }
    }

    private func ask() async {
        working = true
        defer { working = false }
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let answer = try await DoitTutor.answer(question, subject: subject, image: image)
            let item = AIQuestion(question: question.isEmpty ? L("사진 질문") : question,
                                  imageData: image?.jpegForStorage(maxDimension: 1600), subject: subject)
            item.answer = answer
            context.insert(item)
            try? context.save()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// 질문 상세: 질문, 사진, AI 답변, 내 필기, 도움 여부
struct AIQuestionDetailView: View {
    @Bindable var item: AIQuestion
    @Environment(\.modelContext) private var context
    @State private var showNotes = false
    @State private var tool: DrawTool = .pen
    @State private var controller = CanvasController()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TagLabel(text: L("질문"))
                        Text("\(item.subject) · \(item.createdAt.ui("yyyy.MM.dd"))").font(.pt(.caption)).foregroundStyle(.secondary)
                    }
                    Text(item.question).font(.pt(.body).weight(.semibold))
                    if let data = item.imageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 14))

                HStack {
                    Label("AI 선생님 답변", systemImage: "lightbulb").font(.pt(.headline)).foregroundStyle(Theme.accent)
                    Spacer()
                    Text("도움 되었나요?").font(.pt(.caption)).foregroundStyle(.secondary)
                    Button { item.helpful = item.helpful == 1 ? 0 : 1 } label: {
                        Image(systemName: item.helpful == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                    }
                    Button { item.helpful = item.helpful == -1 ? 0 : -1 } label: {
                        Image(systemName: item.helpful == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    }
                }

                ZStack(alignment: .topLeading) {
                    Text(item.answer)
                        .font(.pt(.body))
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
                        .padding(16)
                    if showNotes {
                        DrawingCanvas(initialData: item.drawingData, tool: tool, color: Color(hex: "#2563EB"), width: 3,
                                      isEnabled: true, controller: controller) { drawing in
                            item.drawingData = drawing.dataRepresentation()
                        }
                    } else if item.drawingData != nil {
                        DrawingCanvas(initialData: item.drawingData, tool: .pen, color: .black, width: 3,
                                      isEnabled: false, controller: CanvasController()) { _ in }
                    }
                }
                .background(Palette.card, in: .rect(cornerRadius: 14))

                Toggle(isOn: $showNotes.animation()) {
                    Label("답변 위에 내 필기", systemImage: "pencil.tip")
                }
                if showNotes {
                    HStack {
                        Picker("도구", selection: $tool) {
                            Text("펜").tag(DrawTool.pen)
                            Text("형광펜").tag(DrawTool.highlighter)
                            Text("지우개").tag(DrawTool.eraser)
                        }
                        .pickerStyle(.segmented)
                        Button { controller.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    }
                }

                Text("AI 답은 틀릴 수 있어요")
                    .font(.pt(.caption2))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .scrollDisabled(showNotes)
        .background { AppBackground() }
        .navigationTitle("질문 · 답변")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
    }
}
