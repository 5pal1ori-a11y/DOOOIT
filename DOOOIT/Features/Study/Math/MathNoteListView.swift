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
    /// 과목 고르기: 큰 과목 (nil = 전체) · 그 안의 세부 과목 (nil = 모두)
    @State private var subjectFilter: String?
    @State private var detailFilter: String?
    /// 새 문제를 넣을 과목 ("자동" = 문제 글을 읽고 AI가 정함. 아니면 고른 과목 이름)
    @AppStorage("mistakeNote.addSubject") private var addSubjectRaw = DoitSubjectNote.autoLabel
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

    private var isAutoSubject: Bool { addSubjectRaw == DoitSubjectNote.autoLabel }
    /// 새 문제의 과목 (자동이면 사진을 읽은 뒤 정함)
    private var addSubject: NoteSubject { isAutoSubject ? .math : NoteSubject.from(addSubjectRaw) }
    private var addSubjectSpoken: String { isAutoSubject ? L("과목 자동") : L("과목 \(addSubjectRaw.loc)") }
    private var addSubjectColor: Color {
        isAutoSubject ? Theme.accent : Color(hex: DoitSubjectNote.colorHex(broad: DoitSubjectDetector.broad(ofStored: addSubjectRaw)))
    }

    /// 노트에 실제로 있는 과목들 (큰 과목별 묶음)
    private var groups: [(broad: String, total: Int, details: [(label: String, count: Int)])] {
        DoitSubjectNote.subjectGroups(notes.map(\.subject))
    }

    /// 고른 과목의 노트 (과목 거르기는 메모리에서. #Predicate 문자열 함수는 쓰지 않음)
    private var scoped: [MathNote] {
        guard let subjectFilter else { return notes }
        return notes.filter { note in
            note.broadSubject == subjectFilter && (detailFilter == nil || note.subjectLabel == detailFilter)
        }
    }

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
            VStack(alignment: .leading, spacing: 20) {
                if notes.isEmpty {
                    emptyState
                        .appearAnimation()
                } else {
                    summaryCard
                        .appearAnimation()
                    if !weakConcepts.isEmpty {
                        NavigationLink { WeakConceptListView() } label: {
                            RowLabel(symbol: "target", color: Palette.pink, title: L("취약 개념"),
                                     value: "\(weakConcepts.count)")
                                .softCardBackground(cornerRadius: 20)
                        }
                        .buttonStyle(.pressable)
                        .appearAnimation(delay: 0.04)
                    }
                    subjectChips
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
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
            .animation(Motion.spring, value: filter)
            .animation(Motion.spring, value: subjectFilter)
            .animation(Motion.spring, value: detailFilter)
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
                    subjectPicker
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
            if UIShot.screen == .mathNote, openedNote == nil {
                try? await Task.sleep(for: .milliseconds(400))
                openedNote = notes.first { $0.subjectKind == .math && $0.status == .wrong }
            }
        }
        #endif
        .errorAlert($errorMessage)
    }

    /// 맨 위: 복습할 문제 수 · 상태별 개수 · 정답률 링 · 문제 찍기
    private var summaryCard: some View {
        // 맞힌 문제라도 다시 풀 날이 된 과목 문제는 복습에 넣음
        let toReview = count(.wrong) + count(.unsolved) + scoped.filter { $0.status == .correct && $0.isReviewDue }.count
        let graded = count(.wrong) + count(.correct)
        let ratio = graded == 0 ? 0 : Double(count(.correct)) / Double(graded)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(toReview > 0 ? L("복습할 문제") : L("모두 복습했어요"))
                        .font(.pt(.subheadline).weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(toReview)개")
                        .font(.pt(size: 34, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 8)
                ZStack {
                    ProgressRing(progress: ratio, lineWidth: 9, color: Palette.success)
                    VStack(spacing: 0) {
                        Text("\(Int(ratio * 100))%").font(.pt(.subheadline).weight(.bold)).monospacedDigit().foregroundStyle(Palette.ink)
                        Text("정답률").font(.pt(.caption2)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 76, height: 76)
            }
            captureButtons
        }
        .softCard(cornerRadius: 26, padding: 20)
    }

    /// 새 문제의 과목 고르기 (자동 = 문제를 읽고 AI가 정함)
    @ViewBuilder
    private var subjectPicker: some View {
        Menu {
            SubjectMenuItems(includeAuto: true, onAuto: { addSubjectRaw = DoitSubjectNote.autoLabel }, onPick: { addSubjectRaw = $0 })
        } label: {
            Label("과목: \(addSubjectRaw.loc)", systemImage: isAutoSubject ? "sparkles" : DoitSubjectNote.symbol(broad: DoitSubjectDetector.broad(ofStored: addSubjectRaw)))
        }
    }

    private var captureButtons: some View {
        HStack(spacing: 10) {
            Menu {
                SubjectMenuItems(includeAuto: true, onAuto: { addSubjectRaw = DoitSubjectNote.autoLabel }, onPick: { addSubjectRaw = $0 })
            } label: {
                VStack(spacing: 1) {
                    if isAutoSubject { Image(systemName: "sparkles").font(.pt(.caption2).weight(.bold)) }
                    Text(addSubjectRaw.loc)
                        .font(addSubjectRaw.count > 3 ? .caption2.weight(.bold) : .subheadline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(addSubjectColor)
                .frame(width: 52, height: 52)
                .background(addSubjectColor.pastel, in: .rect(cornerRadius: 20, style: .continuous))
            }
            .accessibilityLabel(addSubjectSpoken)
            Button { openScanner() } label: {
                Label("틀린 문제 찍기", systemImage: "camera.fill")
            }
            .buttonStyle(.primaryFill)
            Button { showPhotoPicker = true } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.pt(.headline))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 52, height: 52)
                    .background(Theme.accent.pastel, in: .rect(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("앨범에서 선택")
        }
    }

    /// 과목 고르기 (노트에 있는 과목만, 큰 과목별 · 개수 함께). 과목을 고르면 새 문제도 그 과목으로, 전체면 자동으로
    private var subjectChips: some View {
        let groups = self.groups
        let current = groups.first { $0.broad == subjectFilter }
        return VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    chip(title: L("전체"), number: notes.count, color: nil, isOn: subjectFilter == nil) {
                        subjectFilter = nil
                        detailFilter = nil
                        addSubjectRaw = DoitSubjectNote.autoLabel
                    }
                    ForEach(groups, id: \.broad) { group in
                        chip(title: group.broad.loc, number: group.total, color: Color(hex: DoitSubjectNote.colorHex(broad: group.broad)),
                             isOn: subjectFilter == group.broad) {
                            subjectFilter = group.broad
                            detailFilter = nil
                            addSubjectRaw = group.details.count == 1 ? group.details[0].label : group.broad
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            // 고른 과목 안에 세부 과목이 둘 이상이면 (예: 윤리 → 생활과 윤리 · 윤리와 사상)
            if let current, current.details.count >= 2 {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(current.details, id: \.label) { detail in
                            let isOn = detailFilter == detail.label
                            Button {
                                withAnimation(.snappy) {
                                    detailFilter = isOn ? nil : detail.label
                                    addSubjectRaw = isOn ? current.broad : detail.label
                                }
                                Haptics.tap()
                            } label: {
                                Text("\(detail.label.loc) \(detail.count)")
                                    .font(.pt(.caption).weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .frame(height: 26)
                                    .foregroundStyle(isOn ? Palette.card : Palette.ink)
                                    .background(isOn ? AnyShapeStyle(Palette.ink.opacity(0.8)) : AnyShapeStyle(Color.primary.opacity(0.06)), in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .transition(.opacity)
            }
        }
    }

    private func chip(title: String, number: Int, color: Color?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
            Haptics.tap()
        } label: {
            HStack(spacing: 5) {
                if let color { Circle().fill(color).frame(width: 7, height: 7) }
                Text(title)
                Text("\(number)").monospacedDigit().opacity(0.7)
            }
            .font(.pt(.subheadline).weight(.semibold))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .foregroundStyle(isOn ? Palette.card : Palette.ink)
            .background(isOn ? AnyShapeStyle(Palette.ink) : AnyShapeStyle(Palette.card), in: .capsule)
            .overlay(Capsule().strokeBorder(Color.primary.opacity(isOn ? 0 : 0.08)))
        }
        .buttonStyle(.plain)
    }

    /// 상태 고르기 (개수 함께)
    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { item in
                let isOn = filter == item
                let number: Int = {
                    switch item {
                    case .all: return scoped.count
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
                        Text(item.title)
                        Text("\(number)").monospacedDigit().opacity(0.7)
                    }
                    .font(.pt(.subheadline).weight(.semibold))
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .foregroundStyle(isOn ? Palette.card : Palette.ink)
                    .background(isOn ? AnyShapeStyle(Palette.ink) : AnyShapeStyle(Palette.card), in: .capsule)
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
            Image(systemName: addSubject.symbol)
                .font(.pt(size: 30, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 72, height: 72)
                .background(Theme.accent.opacity(0.12), in: .circle)
            VStack(spacing: 6) {
                Text("틀린 문제를 찍어 보세요")
                    .font(.pt(.title3).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text("채점 · 풀이 · 비슷한 문제까지")
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            captureButtons
            Button { createBlank() } label: {
                Text("문제 직접 입력")
                    .font(.pt(.subheadline).weight(.semibold))
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
            let graph = await VisionAnalyzer.analyze(pair.problem)
            let figure = await FigureReader.read(pair.problem, problemText: read.text, analysis: graph)
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
        if let figure = await FigureReader.read(pair.problem, problemText: read.text, figures: false) {
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
                        Image(systemName: DoitSubjectNote.symbol(broad: note.broadSubject)).font(.pt(.title3)).foregroundStyle(Palette.ink.opacity(0.3))
                    }
                }
                .clipShape(.rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06)))

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    SubjectTag(label: note.subjectLabel, auto: note.isSubjectAuto)
                    Text(subtitle)
                        .font(.pt(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if note.isReviewDue {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(Palette.warning)
                    .accessibilityLabel("다시 풀 차례")
            }
            Text(note.status.title)
                .font(.pt(.caption).weight(.bold))
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
