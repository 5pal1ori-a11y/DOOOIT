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
    @Query private var weakConcepts: [WeakConcept]

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

    private var filtered: [MathNote] {
        switch filter {
        case .all: return notes
        case .unsolved: return notes.filter { $0.status == .unsolved }
        case .wrong: return notes.filter { $0.status == .wrong }
        case .correct: return notes.filter { $0.status == .correct }
        }
    }

    private func count(_ status: NoteStatus) -> Int { notes.filter { $0.status == status }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if notes.isEmpty {
                    emptyState
                        .appearAnimation()
                } else {
                    summaryCard
                        .appearAnimation()
                    if !weakConcepts.isEmpty {
                        NavigationLink { WeakConceptListView() } label: {
                            RowLabel(symbol: "scope", color: Palette.danger, title: "취약 개념",
                                     subtitle: "\(weakConcepts.count)개 · 약한 개념부터 다시 풀기")
                                .softCardBackground(cornerRadius: 20)
                        }
                        .buttonStyle(.pressable)
                        .appearAnimation(delay: 0.04)
                    }
                    filterChips
                    if filtered.isEmpty {
                        Text("해당하는 문제가 없어요")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        noteList
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
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
        .imageInput(showScanner: $showScanner, showPhotoPicker: $showPhotoPicker, photoItems: $photoItems, maxPhotos: 10, straighten: true) { images in
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

    /// 맨 위: 복습할 문제 수 · 상태별 개수 · 정답률 링 · 문제 찍기
    private var summaryCard: some View {
        let toReview = count(.wrong) + count(.unsolved)
        let graded = count(.wrong) + count(.correct)
        let ratio = graded == 0 ? 0 : Double(count(.correct)) / Double(graded)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(toReview > 0 ? "복습할 문제" : "모두 복습했어요")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(toReview)개")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    Text("오답 \(count(.wrong)) · 미채점 \(count(.unsolved)) · 정답 \(count(.correct))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                ZStack {
                    ProgressRing(progress: ratio, lineWidth: 9, color: Palette.success)
                    VStack(spacing: 0) {
                        Text("\(Int(ratio * 100))%").font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(Palette.ink)
                        Text("정답률").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 76, height: 76)
            }
            captureButtons
        }
        .softCard(cornerRadius: 26, padding: 20)
    }

    private var captureButtons: some View {
        HStack(spacing: 10) {
            Button { openScanner() } label: {
                Label("틀린 문제 찍기", systemImage: "camera.fill")
            }
            .buttonStyle(.primaryFill)
            Button { showPhotoPicker = true } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 52, height: 52)
                    .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("앨범에서 선택")
        }
    }

    /// 상태 고르기 (개수 함께)
    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { item in
                let isOn = filter == item
                let number: Int = {
                    switch item {
                    case .all: return notes.count
                    case .unsolved: return count(.unsolved)
                    case .wrong: return count(.wrong)
                    case .correct: return count(.correct)
                    }
                }()
                Button {
                    withAnimation(.snappy) { filter = item }
                    Haptics.tap()
                } label: {
                    HStack(spacing: 4) {
                        Text(item.rawValue)
                        Text("\(number)").monospacedDigit().opacity(0.7)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .foregroundStyle(isOn ? Color.white : Palette.ink)
                    .background(isOn ? AnyShapeStyle(Palette.ink) : AnyShapeStyle(Color.white), in: .capsule)
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(isOn ? 0 : 0.08)))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    /// 문제 목록 (한 줄씩: 사진 · 제목 · 유형·날짜 · 상태)
    private var noteList: some View {
        VStack(spacing: 0) {
            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, note in
                Button { openedNote = note } label: {
                    MathNoteRow(note: note)
                }
                .buttonStyle(.pressable)
                .contextMenu {
                    Button(role: .destructive) {
                        context.delete(note)
                        try? context.save()
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
                if index < filtered.count - 1 { Divider().padding(.leading, 88) }
            }
        }
        .softCardBackground(cornerRadius: 22)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "function")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 72, height: 72)
                .background(Theme.accent.opacity(0.12), in: .circle)
            VStack(spacing: 6) {
                Text("틀린 문제를 찍어 보세요")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text("채점 → 틀린 이유 → 풀이 → 비슷한 문제까지 이어서 도와줘요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            captureButtons
            Button { createBlank() } label: {
                Text("문제 직접 입력")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .softCard(cornerRadius: 26, padding: 24)
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

/// 오답노트 한 줄: 문제 사진 · 제목 · 유형·날짜 · 상태
private struct MathNoteRow: View {
    let note: MathNote

    var body: some View {
        HStack(spacing: 14) {
            Color.clear
                .frame(width: 58, height: 58)
                .background { GridPaperBackground() }
                .overlay {
                    if let data = note.thumbnailData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Image(systemName: "function").font(.title3).foregroundStyle(Palette.ink.opacity(0.3))
                    }
                }
                .clipShape(.rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06)))

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(note.status.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(note.status.color)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(note.status.color.opacity(0.12), in: .capsule)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        if let kind = note.kind { parts.append(kind.title) }
        if !note.unit.isEmpty { parts.append(note.unit) }
        parts.append(note.createdAt.kr("M월 d일"))
        return parts.joined(separator: " · ")
    }
}
