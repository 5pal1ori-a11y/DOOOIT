import PhotosUI
import SwiftData
import SwiftUI

struct MathNoteListView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "전체", unsolved = "미채점", wrong = "오답", correct = "정답"
        var id: String { rawValue }
        /// 화면 이름 ("정답"은 상태 뜻으로: Correct)
        var title: String { self == .correct ? L("정답(상태)") : rawValue.loc }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \MathNote.createdAt, order: .reverse) private var notes: [MathNote]
    @Query private var weakConcepts: [WeakConcept]

    @State private var filter: Filter = .all
    /// 새 문제의 과목은 언제나 자동 (문제 글을 읽고 AI가 정함)
    private var addSubjectRaw: String { DoitSubjectNote.autoLabel }
    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var cropQueue: [UIImage] = []
    @State private var cropItem: CropItem?
    /// 문제 번호로 자동으로 나눈 페이지 (확인 화면)
    @State private var splitItem: SplitItem?
    /// 자동 나누기 화면에서 "직접 자르기"를 고른 페이지 (다음에 바로 직접 자르기)
    @State private var manualQueue: [UIImage] = []
    @State private var isDetecting = false
    @State private var croppedPairs: [(original: UIImage, problem: UIImage)] = []
    @State private var openedNote: MathNote?
    @State private var errorMessage: String?

    private var isAutoSubject: Bool { true }

    /// 오답노트 전체 (과목은 자동으로 정해서 목록에 표시만)
    private var scoped: [MathNote] { notes }

    private var filtered: [MathNote] {
        switch filter {
        case .all: return scoped
        case .unsolved: return scoped.filter { $0.status == .unsolved }
        case .wrong: return scoped.filter { $0.status == .wrong }
        case .correct: return scoped.filter { $0.status == .correct }
        }
    }

    private func count(_ status: NoteStatus) -> Int { scoped.filter { $0.status == status }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if notes.isEmpty {
                    emptyState
                        .appearAnimation()
                } else {
                    summaryCard
                        .appearAnimation()
                    if !weakConcepts.isEmpty {
                        NavigationLink { WeakConceptListView() } label: {
                            RowLabel(symbol: "target", title: L("취약 개념"),
                                     value: "\(weakConcepts.count)")
                                .softCardBackground()
                        }
                        .buttonStyle(.pressable)
                        .appearAnimation(delay: 0.04)
                    }
                    filterChips
                    if filtered.isEmpty {
                        Text("해당하는 문제가 없어요")
                            .font(.pt(.subheadline))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        noteList
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .animation(Motion.spring, value: filter)
            .animation(Motion.spring, value: notes.count)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("오답노트")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PhotoRecognitionMenu()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { openScanner() } label: { Label("문제 촬영", systemImage: "camera.fill") }
                    Button { showPhotoPicker = true } label: { Label("앨범에서 선택", systemImage: "photo.on.rectangle") }
                    Button { createBlank() } label: { Label("문제 직접 입력", systemImage: "square.and.pencil") }
                    NavigationLink { WeakConceptListView() } label: { Label("취약 개념 보기", systemImage: "target") }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .imageInput(showScanner: $showScanner, showPhotoPicker: $showPhotoPicker, photoItems: $photoItems, maxPhotos: 10, straighten: true) { images in
            cropQueue = images
            manualQueue = []
            croppedPairs = []
            nextCrop()
        }
        .sheet(item: $splitItem, onDismiss: nextCrop) { item in
            ProblemSplitView(item: item) { crops in
                // 원본은 페이지 전체, 문제 사진은 잘라 낸 부분
                for crop in crops { croppedPairs.append((original: item.image, problem: crop)) }
                splitItem = nil
            } onManual: {
                manualQueue.append(item.image)
                splitItem = nil
            } onCancel: {
                splitItem = nil
            }
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
            if isProcessing {
                ProcessingOverlay(message: FigureReader.status)
            } else if isDetecting {
                ProcessingOverlay(message: L("문제 번호를 찾고 있어요"))
            }
        }
        .navigationDestination(item: $openedNote) { note in
            MathNoteEditorView(note: note)
        }
        #if DEBUG
        .task {
            if UIShot.matches(.mathNote, .mathNoteText), openedNote == nil {
                try? await Task.sleep(for: .milliseconds(400))
                openedNote = notes.first { $0.subjectKind == .math && $0.status == .wrong }
            } else if UIShot.screen == .subjectNote, openedNote == nil {
                try? await Task.sleep(for: .milliseconds(400))
                openedNote = notes.first { $0.subjectKind == .english }
            }
        }
        #endif
        .errorAlert($errorMessage)
    }

    /// 맨 위: 복습할 문제 수(큰 숫자) · 상태별 개수 · 정답률 · 문제 찍기
    private var summaryCard: some View {
        // 맞힌 문제라도 다시 풀 날이 된 과목 문제는 복습에 넣음
        let toReview = count(.wrong) + count(.unsolved) + scoped.filter { $0.status == .correct && $0.isReviewDue }.count
        let graded = count(.wrong) + count(.correct)
        let ratio = graded == 0 ? 0 : Double(count(.correct)) / Double(graded)
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(toReview > 0 ? L("복습할 문제") : L("모두 복습했어요"))
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                BigNumberText(text: L("\(toReview)개"), size: 36)
                    .contentTransition(.numericText())
            }
            Hairline()
            HStack(spacing: 12) {
                StatColumn(value: "\(count(.wrong))", label: Filter.wrong.title)
                StatColumn(value: "\(count(.unsolved))", label: Filter.unsolved.title)
                StatColumn(value: graded == 0 ? "–" : "\(Int(ratio * 100))%", label: L("정답률"))
            }
            captureButtons
        }
        .softCard()
    }

    /// 촬영하기 (과목은 자동) + 앨범에서 고르기
    private var captureButtons: some View {
        HStack(spacing: 8) {
            Button { openScanner() } label: {
                Text("촬영하기")
            }
            .buttonStyle(.primaryFill)
            Button { showPhotoPicker = true } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.pt(size: 18, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 52, height: 52)
                    .background(Theme.secondaryFill, in: .rect(cornerRadius: Radius.button, style: .continuous))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("앨범에서 선택")
        }
    }

    /// 상태 고르기 (개수 함께)
    private var filterChips: some View {
        PillSegmentedControl(items: Filter.allCases, selection: $filter) { item in
            let number: Int = {
                switch item {
                case .all: return scoped.count
                case .unsolved: return count(.unsolved)
                case .wrong: return count(.wrong)
                case .correct: return count(.correct)
                }
            }()
            return "\(item.title) \(number)"
        }
    }

    /// 문제 목록 (한 줄씩: 사진 · 제목 · 과목·유형·날짜 · 상태), 줄 사이는 헤어라인
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
                if index < filtered.count - 1 { Hairline().padding(.leading, 76) }
            }
        }
        .softCardBackground()
    }

    /// 빈 상태: 회색 아이콘 + 한 줄 + 버튼
    private var emptyState: some View {
        VStack(spacing: 16) {
            EmptyStateView(symbol: "camera.viewfinder", title: L("틀린 문제를 찍어 보세요"))
            captureButtons
            Button { createBlank() } label: {
                Text("문제 직접 입력")
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.pressable)
        }
        .frame(maxWidth: .infinity)
        .softCard()
    }

    private func openScanner() {
        if DocumentScanner.isSupported {
            showScanner = true
        } else {
            errorMessage = L("이 기기에서는 카메라 스캔을 지원하지 않아요. 앨범에서 사진을 선택해주세요.")
        }
    }

    private func createBlank() {
        let note = MathNote(title: L("오답 \(notes.count + 1)"), imageData: nil, thumbnailData: nil, recognizedText: "")
        if isAutoSubject {
            // 다 적은 뒤 글을 보고 과목을 정함 (그때까지는 수학)
            var scan = DoitProblemScan.scan("")
            scan.autoSubject = ""
            note.scan = scan
        } else {
            note.subject = DoitSubjectNote.storedValue(addSubjectRaw)
        }
        // 직접 적는 문제도 다 적은 뒤 "이대로 확정"을 눌러야 채점·풀이를 시작
        note.recognitionRaw = "pending"
        context.insert(note)
        try? context.save()
        openedNote = note
    }

    /// 사진마다 먼저 문제 번호로 자동으로 나눠 보고 (2문제 이상이면 확인 화면),
    /// 아니면 직접 문제 영역을 고름. 다 고르면 한꺼번에 노트로 만듦
    private func nextCrop() {
        guard cropItem == nil, splitItem == nil, !isDetecting else { return }
        if !manualQueue.isEmpty {
            let next = manualQueue.removeFirst()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { cropItem = CropItem(image: next) }
        } else if !cropQueue.isEmpty {
            let next = cropQueue.removeFirst()
            withAnimation { isDetecting = true }
            let started = Date()
            Task {
                let split = await OCRService.splitProblems(next)
                // 앞 화면이 완전히 내려간 뒤 다음 화면을 띄움 (그때까지 진행 표시 유지)
                let wait = max(0, 0.35 - Date().timeIntervalSince(started))
                DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                    withAnimation { isDetecting = false }
                    if split.regions.count >= 2 {
                        splitItem = SplitItem(image: next, regions: split.regions, crops: split.crops)
                    } else {
                        cropItem = CropItem(image: next)
                    }
                }
            }
        } else if !croppedPairs.isEmpty {
            let pairs = croppedPairs
            croppedPairs = []
            Task { await create(from: pairs) }
        }
    }

    private func create(from pairs: [(original: UIImage, problem: UIImage)]) async {
        withAnimation { isProcessing = true }
        var created: [MathNote] = []
        let chosen = addSubjectRaw
        let auto = isAutoSubject
        for (i, pair) in pairs.enumerated() {
            // 자동: 먼저 글자 그대로 읽어 과목을 정함 (수학이면 수식 교정 읽기로 다시)
            var label = DoitSubjectNote.storedValue(chosen)
            var plainRead: (text: String, unsure: [String])?
            if auto {
                let read = await SubjectOCR.read(pair.problem)
                plainRead = read
                label = DoitSubjectNote.storedValue(DoitSubjectNote.detectedSubject(read.text) ?? DoitSubjectNote.fallbackSubject(read.text))
            }
            guard NoteSubject.from(label).isMath else {
                created.append(await createSubjectNote(pair, subject: label, index: i, read: plainRead, auto: auto))
                continue
            }
            // 기기 안 글자 인식 (검은 인쇄 글자 위주) + 자주 틀리는 수식 글자 교정
            let read = await OCRService.readMathProblemDetailed(pair.problem)
            // 그림·그래프·표에서 읽은 것은 "[그림에서 읽음]" 블록으로 붙임 (문제 탭에서 확인 · 고치기)
            // 그림 읽기도 학생 필기(그림 위에 쓴 값·그은 선)를 지운 사진으로 (오답노트에 그린 필기는 처음부터 넣지 않음)
            let figureImage = await OCRService.printedOnly(pair.problem, mode: .figure)
            let graph = await VisionAnalyzer.analyze(figureImage)
            let figure = await FigureReader.read(figureImage, problemText: read.text, analysis: graph)
            let text = DoitFigureFacts.attach(figure, to: read.text)
            let title = DoitProblemScan.titled(read.text, base: MathOCRFixer.title(from:)) ?? L("오답 \(notes.count + i + 1)")
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
            var scan = DoitProblemScan.scan(text, lowConfidence: read.unsure, graphNote: graph.graph != nil && figure == nil ? graphNote(graph) : nil)
            note.subject = label
            scan.autoSubject = auto ? label : nil
            scan.typeID = DoitProblemTypes.bestID(for: text, subject: DoitSubjectNote.displayName(label))
            note.scan = scan
            note.kind = scan.kind
            context.insert(note)
            created.append(note)
        }
        try? context.save()
        withAnimation { isProcessing = false }
        if created.count == 1 { openedNote = created.first }
    }

    /// 수학이 아닌 과목: 한글·영어 문장 그대로 읽고 (수식 교정 없이), 선택지·정답 표기만 나눔
    private func createSubjectNote(_ pair: (original: UIImage, problem: UIImage), subject: String, index: Int,
                                   read already: (text: String, unsure: [String])?, auto: Bool) async -> MathNote {
        var read: (text: String, unsure: [String])
        if let already { read = already } else { read = await SubjectOCR.read(pair.problem) }
        // 사회·과학의 표·차트 (자료 값): 도형·좌표 그림은 수학만
        if let figure = await FigureReader.read(await OCRService.printedOnly(pair.problem, mode: .figure), problemText: read.text, figures: false) {
            read.text = DoitFigureFacts.attach(figure, to: read.text)
        }
        let note = MathNote(
            title: DoitProblemScan.titled(read.text, base: DoitSubjectNote.title(from:)) ?? L("오답 \(notes.count + index + 1)"),
            imageData: pair.original.jpegForStorage(maxDimension: 2000),
            thumbnailData: pair.problem.jpegForStorage(maxDimension: 400, quality: 0.6),
            recognizedText: read.text,
            correctAnswer: DoitSubjectNote.printedAnswer(in: read.text) ?? ""
        )
        note.subject = subject
        note.problemImageData = pair.problem.jpegForStorage(maxDimension: 2000, quality: 0.85)
        note.recognitionRaw = "pending"
        var scan = DoitProblemScan.scan(read.text, lowConfidence: read.unsure, math: false)
        scan.autoSubject = auto ? subject : nil
        scan.typeID = DoitProblemTypes.bestID(for: read.text, subject: DoitSubjectNote.displayName(subject))
        note.scan = scan
        note.kind = scan.kind
        context.insert(note)
        return note
    }
}

/// 그래프 분석 결과를 문제에 붙일 짧은 글 (식을 찾지 못하면 그렇다고만)
@MainActor
private func graphNote(_ analysis: ImageAnalysis) -> String {
    if let equation = analysis.graph?.equation { return L("그래프에서 찾은 식: \(equation) (눈으로 읽은 값이라 확인해 주세요)") }
    return L("그래프가 있지만 식을 읽지 못했어요. 필요한 값은 직접 적어 주세요.")
}

/// 오답노트 한 줄: 문제 사진 · 제목 · 과목 태그와 유형·날짜 · 상태(점 + 글자)
private struct MathNoteRow: View {
    let note: MathNote

    var body: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 48, height: 48)
                .background { GridPaperBackground() }
                .overlay {
                    if let data = note.thumbnailData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Image(systemName: DoitSubjectNote.symbol(broad: note.broadSubject).outlineSymbol)
                            .environment(\.symbolVariants, .none)
                            .font(.pt(.title3))
                            .foregroundStyle(Color.secondary.opacity(0.6))
                    }
                }
                .clipShape(.rect(cornerRadius: Radius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.pt(.body).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    SubjectTag(label: note.subjectLabel, auto: note.isSubjectAuto)
                    Text(subtitle)
                        .font(.pt(.footnote))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                StatusText(text: note.status.title, color: note.status == .unsolved ? .secondary : note.status.color)
                if note.isReviewDue {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.pt(.caption).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("다시 풀 차례")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        // 문제 유형 이름이 있으면 그것 (예: 빈칸 추론), 없으면 채점 방식 (객관식)
        if let type = note.scan?.problemType { parts.append(type.name) } else if let kind = note.kind { parts.append(kind.title) }
        if !note.unit.isEmpty { parts.append(note.unit) }
        parts.append(note.createdAt.ui("M월 d일"))
        return parts.joined(separator: " · ")
    }
}

/// 오답노트 사진 인식 설정: 정밀 인식(기본 · 와이파이에서 알아서 받음) / 기본 인식
struct PhotoRecognitionMenu: View {
    @State private var ocr = PaddleOCRService.shared
    @State private var confirmOff = false

    var body: some View {
        Menu {
            Section("사진 인식") {
                if !PaddleOCRService.isSupported {
                    Label("기본 인식", systemImage: "checkmark")
                    Text("이 기기는 정밀 인식을 못 써요")
                } else {
                    Button {
                        if case .downloading = ocr.phase { return }
                        if !ocr.isEnabled || !ocr.isInstalled { ocr.turnOn() }
                    } label: {
                        if case .downloading(let fraction) = ocr.phase {
                            Label("정밀 인식 받는 중 \(Int(fraction * 100))%", systemImage: "arrow.down.circle")
                        } else if ocr.isEnabled && ocr.isInstalled {
                            Label("정밀 인식", systemImage: "checkmark")
                        } else if ocr.isEnabled {
                            Label("정밀 인식 받기", systemImage: "arrow.down.circle")
                        } else {
                            Text("정밀 인식")
                        }
                    }
                    Button {
                        if ocr.isEnabled { confirmOff = true }
                    } label: {
                        if ocr.isEnabled { Text("기본 인식") } else { Label("기본 인식", systemImage: "checkmark") }
                    }
                }
            }
        } label: {
            if case .downloading(let fraction) = ocr.phase {
                Text("\(Int(fraction * 100))%").font(.pt(.caption).weight(.semibold)).monospacedDigit().foregroundStyle(Theme.accent)
            } else {
                Image(systemName: "text.viewfinder")
            }
        }
        .accessibilityLabel("사진 인식 설정")
        .alert("기본 인식으로 바꿀까요?", isPresented: $confirmOff) {
            Button("바꾸기", role: .destructive) { ocr.turnOff() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("받아 둔 정밀 인식 모델을 지워요.")
        }
    }
}
