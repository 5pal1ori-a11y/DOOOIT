import PhotosUI
import SwiftData
import SwiftUI

struct MathNoteListView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "전체", unsolved = "미채점", wrong = "오답", correct = "정답"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(CreditStore.self) private var credits
    @Query(sort: \MathNote.createdAt, order: .reverse) private var notes: [MathNote]

    @State private var filter: Filter = .all
    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var cropQueue: [UIImage] = []
    @State private var cropItem: CropItem?
    @State private var croppedPairs: [(original: UIImage, problem: UIImage)] = []
    @State private var openedNote: MathNote?
    @State private var errorMessage: String?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var filtered: [MathNote] {
        switch filter {
        case .all: return notes
        case .unsolved: return notes.filter { $0.status == .unsolved }
        case .wrong: return notes.filter { $0.status == .wrong }
        case .correct: return notes.filter { $0.status == .correct }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("필터", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if notes.isEmpty {
                    emptyState
                } else if filtered.isEmpty {
                    EmptyStateView(symbol: "tray", title: "해당하는 문제가 없어요", message: "다른 필터를 선택해보세요.")
                        .glassCard()
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filtered) { note in
                            Button { openedNote = note } label: {
                                MathNoteCard(note: note)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    context.delete(note)
                                    try? context.save()
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("오답노트")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { openScanner() } label: { Label("문제 촬영", systemImage: "doc.viewfinder") }
                    Button { showPhotoPicker = true } label: { Label("앨범에서 선택", systemImage: "photo.on.rectangle") }
                    Button { createBlank() } label: { Label("빈 노트", systemImage: "square.and.pencil") }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .imageInput(showScanner: $showScanner, showPhotoPicker: $showPhotoPicker, photoItems: $photoItems, maxPhotos: 10) { images in
            cropQueue = images
            croppedPairs = []
            nextCrop()
        }
        .sheet(item: $cropItem, onDismiss: nextCrop) { item in
            ProblemCropView(image: item.image) { problem in
                croppedPairs.append((original: item.image, problem: problem))
                cropItem = nil
            } onCancel: {
                cropItem = nil
            }
        }
        .overlay {
            if isProcessing { ProcessingOverlay(message: "문제를 분석하고 있어요") }
        }
        .navigationDestination(item: $openedNote) { note in
            MathNoteEditorView(note: note)
        }
        .errorAlert($errorMessage)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            EmptyStateView(symbol: "function", title: "오답노트가 비어 있어요",
                           message: "틀린 문제를 촬영하면 글과 그림을 분석해서\n필기할 수 있는 노트로 만들어드려요.")
            Button { openScanner() } label: {
                Label("틀린 문제 촬영하기", systemImage: "camera.fill")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            Button { showPhotoPicker = true } label: {
                Label("앨범에서 선택", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
            }
            .buttonStyle(.glass)
        }
        .glassCard(padding: 20)
    }

    private func openScanner() {
        if DocumentScanner.isSupported {
            showScanner = true
        } else {
            errorMessage = "이 기기에서는 카메라 스캔을 지원하지 않아요. 앨범에서 사진을 선택해주세요."
        }
    }

    private func createBlank() {
        let note = MathNote(title: "오답 \(notes.count + 1)", imageData: nil, thumbnailData: nil, recognizedText: "")
        context.insert(note)
        try? context.save()
        openedNote = note
    }

    /// 사진마다 문제 영역을 고른 뒤, 다 고르면 한꺼번에 노트로 만듦
    private func nextCrop() {
        guard cropItem == nil else { return }
        if !cropQueue.isEmpty {
            let next = cropQueue.removeFirst()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { cropItem = CropItem(image: next) }
        } else if !croppedPairs.isEmpty {
            let pairs = croppedPairs
            croppedPairs = []
            Task { await create(from: pairs) }
        }
    }

    private func create(from pairs: [(original: UIImage, problem: UIImage)]) async {
        withAnimation { isProcessing = true }
        var created: [MathNote] = []
        for (i, pair) in pairs.enumerated() {
            // 서버가 연결되어 있으면 Claude가 직접 읽고, 실패하거나 없으면 기기 안 글자 인식
            var text = ""
            var claudeTitle = ""
            var claudeAnswer = ""
            // Claude 읽기는 문제 1개에 크레딧 차감, 모자라면 기기 안 인식(무료)
            if ClaudeReader.isConfigured, credits.canAfford(), let result = try? await ClaudeReader.read(pair.problem) {
                text = result.text
                claudeTitle = result.title
                claudeAnswer = result.answer
                credits.charge(.readProblem)
            } else {
                let lines = (try? await OCRService.recognizeMath(pair.problem)) ?? []
                text = MathOCRFixer.fix(OCRService.printedText(from: lines))
            }
            let title = !claudeTitle.isEmpty ? claudeTitle : (MathOCRFixer.title(from: text) ?? "오답 \(notes.count + i + 1)")
            let note = MathNote(
                title: title,
                imageData: pair.original.jpegForStorage(maxDimension: 2000),
                thumbnailData: pair.problem.jpegForStorage(maxDimension: 400, quality: 0.6),
                recognizedText: text,
                correctAnswer: claudeAnswer.isEmpty ? (MathGrader.extractAnswer(from: text) ?? "") : claudeAnswer
            )
            note.problemImageData = pair.problem.jpegForStorage(maxDimension: 2000, quality: 0.85)
            context.insert(note)
            created.append(note)
        }
        try? context.save()
        withAnimation { isProcessing = false }
        if created.count == 1 { openedNote = created.first }
    }
}

private struct MathNoteCard: View {
    let note: MathNote

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 사진이 카드 크기를 밀어내지 않도록: 고정 크기 틀 위에 사진을 덮고 잘라냄
            Color.clear
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .background { GridPaperBackground() }
                .overlay {
                    if let data = note.thumbnailData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "function")
                            .font(.largeTitle)
                            .foregroundStyle(Palette.ink.opacity(0.3))
                    }
                }
                .clipped()
            .clipShape(.rect(cornerRadius: 14))
            .overlay(alignment: .topTrailing) {
                Image(systemName: note.status.symbol)
                    .font(.title3)
                    .foregroundStyle(.white, note.status.color)
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(note.status.title).foregroundStyle(note.status.color)
                    Text("·")
                    Text(note.createdAt.kr("M.d"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
    }
}
