import PhotosUI
import SwiftData
import SwiftUI

struct MathNoteListView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "전체", unsolved = "미채점", wrong = "오답", correct = "정답"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
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
                PillSegmentedControl(items: Filter.allCases, selection: $filter) { $0.rawValue }

                if notes.isEmpty {
                    emptyState
                } else if filtered.isEmpty {
                    EmptyStateView(symbol: "tray", title: "해당하는 문제가 없어요", message: "다른 필터를 선택해보세요.")
                        .softCard()
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, note in
                            Button { openedNote = note } label: {
                                MathNoteCard(note: note)
                            }
                            .buttonStyle(.pressable)
                            .appearAnimation(delay: Double(min(index, 8)) * 0.04)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
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
            .animation(Motion.spring, value: filter)
            .animation(Motion.spring, value: notes.count)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("오답노트")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { openScanner() } label: { Label("문제 촬영", systemImage: "doc.viewfinder") }
                    Button { showPhotoPicker = true } label: { Label("앨범에서 선택", systemImage: "photo.on.rectangle") }
                    Button { createBlank() } label: { Label("문제 직접 입력", systemImage: "square.and.pencil") }
                    NavigationLink { WeakConceptListView() } label: { Label("취약 개념 보기", systemImage: "scope") }
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
        .softCard(cornerRadius: 24, padding: 20)
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
        // 직접 적는 문제도 다 적은 뒤 "이대로 확정"을 눌러야 채점·풀이를 시작
        note.recognitionRaw = "pending"
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
            // 기기 안 글자 인식 (검은 인쇄 글자 위주) + 자주 틀리는 수식 글자 교정
            let read = await OCRService.readMathProblemDetailed(pair.problem)
            let text = read.text
            let title = MathOCRFixer.title(from: text) ?? "오답 \(notes.count + i + 1)"
            let note = MathNote(
                title: title,
                imageData: pair.original.jpegForStorage(maxDimension: 2000),
                thumbnailData: pair.problem.jpegForStorage(maxDimension: 400, quality: 0.6),
                recognizedText: text,
                correctAnswer: MathGrader.extractAnswer(from: text) ?? ""
            )
            note.problemImageData = pair.problem.jpegForStorage(maxDimension: 2000, quality: 0.85)
            // 인식 결과는 사용자가 확인하기 전까지 임시 (흐리게 읽은 줄·이상한 수식은 표시)
            note.recognitionRaw = "pending"
            let graph = await VisionAnalyzer.analyze(pair.problem)
            note.scan = DoitProblemScan.scan(text, lowConfidence: read.unsure, graphNote: graph.graph != nil ? graphNote(graph) : nil)
            note.kind = note.scan?.kind
            context.insert(note)
            created.append(note)
        }
        try? context.save()
        withAnimation { isProcessing = false }
        if created.count == 1 { openedNote = created.first }
    }
}

/// 그래프 분석 결과를 문제에 붙일 짧은 글 (식을 찾지 못하면 그렇다고만)
@MainActor
private func graphNote(_ analysis: ImageAnalysis) -> String {
    if let equation = analysis.graph?.equation { return "그래프에서 찾은 식: \(equation) (눈으로 읽은 값이라 확인해 주세요)" }
    return "그래프가 있지만 식을 읽지 못했어요. 필요한 값은 직접 적어 주세요."
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
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
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
        .background(Color.white, in: .rect(cornerRadius: 22))
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(note.status.color.opacity(0.7))
                .frame(height: 3)
                .padding(.horizontal, 22)
        }
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}
