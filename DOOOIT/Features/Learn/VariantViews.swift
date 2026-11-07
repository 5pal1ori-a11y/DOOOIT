import SwiftData
import SwiftUI

// 기출 유형 · 변형 문제
// 진짜 기출 시험지는 쓰지 않아요: 모티 엔진이 만든 변형 문제이고, 정답은 엔진이 다시 확인한 것만 내요.
// (수학은 풀이 엔진이 다시 풀어서 맞춘 것, 영어 문법·과학·사회는 교육과정 자료로 검증한 것)

// MARK: - 1. 학교급 + 과목 타일

struct VariantHubView: View {
    @State private var level: SchoolLevel = .middle
    @State private var counts: [String: Int] = [:]

    private let levels: [SchoolLevel] = [.elementary, .middle, .high]
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PillSegmentedControl(items: levels, selection: $level) { Self.levelTitle($0) }
                    .staggerIn(index: 0)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(VariantTopic.Subject.allCases.enumerated()), id: \.element) { index, subject in
                        NavigationLink { VariantTopicListView(subject: subject, level: level) } label: {
                            tile(subject)
                        }
                        .buttonStyle(.pressable)
                        .staggerIn(index: index + 1)
                    }
                }
                Text("모티가 만든 연습 문제예요")
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("기출·변형 문제")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: level) { await warm() }
    }

    static func levelTitle(_ level: SchoolLevel) -> String {
        switch level {
        case .elementary: return L("초등")
        case .middle: return L("중학교")
        default: return L("고등학교")
        }
    }

    static func symbol(_ subject: VariantTopic.Subject) -> String {
        switch subject {
        case .math: return "function"
        case .english: return "textformat"
        case .science: return "atom"
        case .social: return "globe.asia.australia"
        }
    }

    static func title(_ subject: VariantTopic.Subject) -> String {
        switch subject {
        case .math: return L("수학")
        case .english: return L("영어 문법")
        case .science: return L("과학")
        case .social: return L("사회")
        }
    }

    private func tile(_ subject: VariantTopic.Subject) -> some View {
        let count = counts["\(subject.rawValue)|\(level.rawValue)"]
        return VStack(alignment: .leading, spacing: 10) {
            Image(systemName: Self.symbol(subject))
                .font(.pt(size: 22, weight: .regular))
                .foregroundStyle(Theme.secondary)
            Spacer(minLength: 0)
            Text(Self.title(subject))
                .font(.pt(.body).weight(.semibold))
                .foregroundStyle(Palette.ink)
            Group {
                if let count {
                    Text(count == 0 ? L("준비 중") : L("주제 \(count)개"))
                } else {
                    Text(verbatim: "…")
                }
            }
            .font(.pt(.footnote))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(16)
        .softCardBackground()
    }

    /// 주제 수 세기 (수학 · 영어는 바로, 과학 · 사회는 자료를 읽어야 해서 뒤에서 한 번만)
    private func warm() async {
        let level = level
        for subject in VariantTopic.Subject.allCases {
            let key = "\(subject.rawValue)|\(level.rawValue)"
            if counts[key] != nil { continue }
            let n = await Task.detached(priority: .utility) { DoitVariants.topics(subject: subject, level: level).count }.value
            counts[key] = n
        }
    }
}

// MARK: - 2. 주제 고르기

struct VariantTopicListView: View {
    let subject: VariantTopic.Subject
    let level: SchoolLevel
    @State private var topics: [VariantTopic]?

    private var screenTitle: String { VariantHubView.title(subject) + " · " + VariantHubView.levelTitle(level) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let topics {
                    if topics.isEmpty {
                        EmptyStateView(symbol: "tray", title: L("준비된 주제가 없어요"))
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                                NavigationLink { VariantSessionView(topic: topic) } label: {
                                    RowLabel(symbol: VariantHubView.symbol(subject), title: topic.title, subtitle: topic.detail)
                                }
                                if index < topics.count - 1 { RowDivider() }
                            }
                        }
                        .buttonStyle(.pressableRow)
                        .softCardBackground()
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let subject = subject, level = level
            topics = await Task.detached(priority: .userInitiated) { DoitVariants.topics(subject: subject, level: level) }.value
        }
    }
}

// MARK: - 3. 풀기 (문제 → 채점 → 풀이 → 비슷한 문제 한 번 더 / 한 단계 쉽게 · 어렵게)

struct VariantSessionView: View {
    let topic: VariantTopic
    /// 채팅에서 시트로 열었을 때 (닫기 버튼)
    var inSheet = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var level = 1
    @State private var item: PracticeItem?
    @State private var loading = true
    @State private var exhausted = false
    @State private var typed = ""
    @State private var picked: Int?
    @State private var result: GradeResult?
    @State private var given = ""
    @State private var note: String?
    @State private var seen: Set<String> = []
    /// 이번 판(5문제)에서 맞고 틀린 것
    @State private var round: [Bool] = []
    @State private var wrongs: [(item: PracticeItem, given: String)] = []
    @State private var saved: Set<UUID> = []
    @State private var summary = false
    @FocusState private var typing: Bool

    private var size: Int { DoitVariants.setSize }
    private var maxLevel: Int { DoitVariants.levelCount(topic) }
    private var answered: Bool { result != nil }
    private var correct: Bool { result?.verdict == .correct }
    private var subjectName: String {
        switch topic.source {
        case .math: return topic.level == .middle ? "중학교 수학" : "고등학교 수학"
        case .grammar(let s, _), .knowledge(let s, _): return s
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if summary {
                        summaryView
                    } else {
                        levelBar
                        progressBar.id("top")
                        if loading {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                        } else if exhausted {
                            exhaustedView
                        } else if let item {
                            questionCard(item)
                            if let result { feedback(item, result) }
                            actions(item)
                        }
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            // 채점하면 풀이와 다음 버튼이 보이게 아래로
            .onChange(of: answered) { _, now in
                guard now else { return }
                // 풀이 카드가 그려진 다음에 내려감
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(180))
                    withAnimation(Motion.quick) { proxy.scrollTo("end", anchor: .bottom) }
                }
            }
            .onChange(of: item?.id) { _, _ in
                proxy.scrollTo("top", anchor: .top)
            }
        }
        .background { AppBackground() }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if inSheet {
                ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } }
            }
        }
        .task {
            await load()
            #if DEBUG
            await uiShotSteps()
            #endif
        }
    }

    // MARK: 위쪽

    private var levelBar: some View {
        Group {
            if maxLevel > 1 {
                PillSegmentedControl(items: Array(1...maxLevel), selection: Binding(get: { level }, set: { changeLevel($0) })) {
                    DoitVariants.levelName($0, of: topic).loc
                }
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 12) {
            LinearProgressBar(value: Double(round.count) / Double(size), height: 4)
            Text(verbatim: "\(min(round.count + (answered ? 0 : 1), size)) / \(size)")
                .font(.pt(.footnote).weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: 문제

    private func questionCard(_ item: PracticeItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(MathSymbolBar.pretty(item.question))
                .font(topic.subject == .math ? Font.system(size: 17, design: .serif) : Font.pt(.body))
                .foregroundStyle(Palette.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            if !item.choices.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(item.choices.enumerated()), id: \.offset) { index, choice in
                        choiceRow(item, index: index, text: choice)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    TextField("내 답", text: $typed)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($typing)
                        .submitLabel(.done)
                        .onSubmit { submit(item) }
                        .disabled(answered)
                        .flatField()
                    if !answered {
                        Button("제출") { submit(item) }
                            .buttonStyle(.flatProminent)
                            .fixedSize()
                            .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if item.kind == .math, !answered {
                    MathSymbolBar { symbol in
                        typed = MathSymbolBar.tidy(typed + symbol.insert, after: symbol)
                    }
                }
            }
            if let note {
                Text(note).font(.pt(.footnote)).foregroundStyle(Palette.warning)
            }
        }
        .softCard()
    }

    private func choiceRow(_ item: PracticeItem, index: Int, text: String) -> some View {
        let marks = ["①", "②", "③", "④", "⑤", "⑥"]
        let number = index + 1
        let right = Int(item.answer) == number
        let mine = picked == number
        return Button {
            guard !answered else { return }
            picked = number
            Haptics.tap()
            submit(item)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(item.choices.count > 2 && number <= marks.count ? marks[number - 1] : "")
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
                Text(MathSymbolBar.pretty(text))
                    .font(.pt(.subheadline))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if answered, right {
                    Image(systemName: "checkmark").font(.pt(.footnote).weight(.bold)).foregroundStyle(Palette.success)
                } else if answered, mine {
                    Image(systemName: "xmark").font(.pt(.footnote).weight(.bold)).foregroundStyle(Palette.danger)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Palette.cardInset, in: .rect(cornerRadius: Radius.field, style: .continuous))
            .overlay {
                if answered, right || mine {
                    RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                        .strokeBorder(right ? Palette.success : Palette.danger, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 채점 · 풀이

    private func feedback(_ item: PracticeItem, _ result: GradeResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            StatusText(text: correct ? L("맞았어요") : L("틀렸어요"), color: correct ? Palette.success : Palette.danger)
            if !correct {
                Text("정답: \(MathSymbolBar.pretty(DoitVariants.answerText(item)))")
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(Palette.ink)
            }
            if !item.explanation.isEmpty { Hairline() }
            ForEach(Array(item.explanation.prefix(6).enumerated()), id: \.offset) { _, line in
                Text(MathSymbolBar.pretty(line))
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !correct {
                Button { saveToNotes(item, given: given) } label: {
                    Label(saved.contains(item.id) ? L("오답노트에 담았어요") : L("오답노트에 담기"),
                          systemImage: saved.contains(item.id) ? "checkmark" : "arrow.down.circle")
                        .font(.pt(.footnote).weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(saved.contains(item.id) ? Color.secondary : Theme.accent)
                .disabled(saved.contains(item.id))
            }
        }
        .softCard()
        .transition(.opacity)
    }

    @ViewBuilder
    private func actions(_ item: PracticeItem) -> some View {
        if answered {
            let last = round.count >= size
            VStack(spacing: 10) {
                Button {
                    if last { withAnimation(Motion.quick) { summary = true } } else { Task { await next(level: level) } }
                } label: {
                    Text(last ? L("결과 보기") : L("비슷한 문제 한 번 더"))
                }
                .buttonStyle(.primaryFill)
                if !last, maxLevel > 1 {
                    HStack(spacing: 10) {
                        Button("한 단계 쉽게") { Task { await next(level: level - 1) } }
                            .buttonStyle(.flat)
                            .disabled(level <= 1)
                        Button("한 단계 어렵게") { Task { await next(level: level + 1) } }
                            .buttonStyle(.flat)
                            .disabled(level >= maxLevel)
                    }
                }
            }
        }
    }

    private var exhaustedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이 단계는 더 낼 문제가 없어요")
                .font(.pt(.body).weight(.semibold))
                .foregroundStyle(Palette.ink)
            if maxLevel > 1 {
                HStack(spacing: 10) {
                    Button("한 단계 쉽게") { Task { await next(level: level - 1) } }.buttonStyle(.flat).disabled(level <= 1)
                    Button("한 단계 어렵게") { Task { await next(level: level + 1) } }.buttonStyle(.flat).disabled(level >= maxLevel)
                }
            }
            if round.count > 0 {
                Button("결과 보기") { withAnimation(Motion.quick) { summary = true } }.buttonStyle(.primaryFill)
            }
        }
        .softCard()
    }

    // MARK: 한 판 결과

    private var summaryView: some View {
        let score = round.filter { $0 }.count
        let unsaved = wrongs.filter { !saved.contains($0.item.id) }
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: "\(score)")
                        .font(.pt(size: 40, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                        .numberRoll(Double(score))
                    Text(verbatim: "/ \(round.count)")
                        .font(.pt(size: 15))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(DoitMockExam.cheer(correct: score, total: round.count).loc)
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
            }
            .softCard()
            .staggerIn(index: 0)
            VStack(spacing: 10) {
                Button("비슷한 문제 한 번 더") { Task { await newRound(level: level) } }
                    .buttonStyle(.primaryFill)
                if maxLevel > 1 {
                    HStack(spacing: 10) {
                        Button("한 단계 쉽게") { Task { await newRound(level: level - 1) } }.buttonStyle(.flat).disabled(level <= 1)
                        Button("한 단계 어렵게") { Task { await newRound(level: level + 1) } }.buttonStyle(.flat).disabled(level >= maxLevel)
                    }
                }
                if !unsaved.isEmpty {
                    Button("틀린 문제 모두 담기") {
                        for entry in unsaved { saveToNotes(entry.item, given: entry.given) }
                    }
                    .buttonStyle(.flat)
                }
            }
            .staggerIn(index: 1)
        }
    }

    // MARK: 진행

    private func load() async {
        loading = true
        exhausted = false
        resetAnswer()
        let topic = topic, level = level, avoid = seen
        let made = await Task.detached(priority: .userInitiated) { DoitVariants.makeItem(topic: topic, level: level, avoid: avoid) }.value
        item = made
        exhausted = made == nil
        if let made { seen.insert(DoitPractice.questionKey(made.question)) }
        loading = false
    }

    private func resetAnswer() {
        typed = ""
        picked = nil
        result = nil
        given = ""
        note = nil
    }

    /// 다음 문제 (단계를 바꿀 수도 있음)
    private func next(level newLevel: Int) async {
        level = max(1, min(newLevel, maxLevel))
        await load()
    }

    private func newRound(level newLevel: Int) async {
        round = []
        wrongs = []
        withAnimation(Motion.quick) { summary = false }
        await next(level: newLevel)
    }

    /// 단계 막대로 바꿈: 아직 안 푼 문제면 바로 새 문제로
    private func changeLevel(_ new: Int) {
        guard new != level else { return }
        level = new
        if !answered { Task { await load() } }
    }

    private func submit(_ item: PracticeItem) {
        guard !answered else { return }
        let text = item.choices.isEmpty ? typed : (picked.map(String.init) ?? "")
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let graded = DoitVariants.grade(item, answer: text)
        // 확인할 수 없는 답은 맞고 틀림에 넣지 않고 다시 써 보게
        guard graded.verdict != .needsReview else {
            note = graded.reasons.first ?? L("답을 확인할 수 없어요. 다시 써 주세요.")
            return
        }
        typing = false
        given = text
        withAnimation(Motion.quick) { result = graded }
        let ok = graded.verdict == .correct
        round.append(ok)
        if !ok { wrongs.append((item, text)) }
        if ok { Haptics.success() } else { Haptics.error() }
    }

    /// 틀린 문제를 오답노트로 (글이 정확하니 인식 확인 없이 바로 확정, 채점 · 원인 분석까지)
    private func saveToNotes(_ item: PracticeItem, given: String) {
        guard !saved.contains(item.id) else { return }
        let text = DoitVariants.noteText(item)
        let note = MathNote(title: topic.title, imageData: nil, thumbnailData: nil, recognizedText: text, correctAnswer: item.answer)
        note.subject = subjectName
        note.unit = topic.title
        note.recognitionRaw = "confirmed"
        note.scan = DoitProblemScan.scan(text, math: note.subjectKind.isMath)
        note.kind = item.kind
        note.myAnswer = given
        let graded = DoitVariants.grade(item, answer: given)
        note.grade = graded
        note.status = .wrong
        note.analysis = DoitMistake.analyze(.init(problem: item.question, kind: item.kind, student: given, grade: graded, choices: item.choices, subject: note.subjectKind))
        note.solutionData = try? JSONEncoder().encode(WrittenSolution(concept: item.concept, steps: item.explanation.map { SolutionStep(hint: "풀이", work: $0) },
                                                                      finalAnswer: DoitVariants.answerText(item)))
        context.insert(note)
        WeakConceptStore.recordGrade(note: note, correct: false, source: "변형 문제", cause: note.analysis?.cause.rawValue, context: context)
        saved.insert(item.id)
        Haptics.success()
    }

    #if DEBUG
    /// 화면 사진용: 푼 뒤 / 한 판이 끝난 뒤 모습
    private func uiShotSteps() async {
        guard UIShot.matches(.variantFeedback, .variantResult), let first = item else { return }
        if UIShot.matches(.variantFeedback) {
            // 일부러 틀린 답
            if first.choices.isEmpty { typed = "0" } else { picked = (Int(first.answer) == 1 ? 2 : 1) }
            submit(first)
            return
        }
        for i in 0..<size {
            guard let current = item else { break }
            if current.choices.isEmpty { typed = i == 2 ? "0" : current.answer } else { picked = i == 2 ? (Int(current.answer) == 1 ? 2 : 1) : Int(current.answer) }
            submit(current)
            if i < size - 1 { await next(level: level) }
        }
        summary = true
    }
    #endif
}
