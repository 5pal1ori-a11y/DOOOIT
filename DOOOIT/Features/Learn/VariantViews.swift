import SwiftData
import SwiftUI

// 변형 문제 연습 (AI 학습 안에서)
// 진짜 기출 시험지는 쓰지 않아요: 모티 엔진이 만든 변형 문제이고, 정답은 엔진이 다시 확인한 것만 내요.
// (수학은 풀이 엔진이 다시 풀어서 맞춘 것, 영어 문법·과학·사회는 교육과정 자료로 검증한 것)
// 문제 하나씩: 문제 → 채점 → 짧은 풀이 → 다음. 다섯 문제가 한 판이에요.

// MARK: - 단원 → 변형 문제 주제 찾기 (엔진이 확인한 것만, 한 번 찾으면 기억)

@MainActor
enum VariantLookup {
    private static var cache: [String: VariantTopic?] = [:]

    /// 이미 찾아 둔 결과 (처음이면 nil → 아직 모름)
    static func cached(subject: String, unit: String) -> VariantTopic?? {
        cache[subject + "|" + unit]
    }

    /// 화면을 막지 않게 뒤에서 찾음
    static func find(subject: String, unit: String) async -> VariantTopic? {
        if let hit = cached(subject: subject, unit: unit) { return hit }
        let found = await Task.detached(priority: .utility) { DoitVariants.topic(subjectName: subject, unit: unit) }.value
        cache[subject + "|" + unit] = .some(found)
        return found
    }
}

// MARK: - 단원 목록의 작은 "변형 연습" 버튼 (낼 수 있는 단원에만 나타남)

struct VariantChip: View {
    let subject: String
    let unit: String
    var onPick: (VariantTopic) -> Void

    @State private var topic: VariantTopic?

    var body: some View {
        Group {
            if let topic {
                Button {
                    Haptics.tap()
                    onPick(topic)
                } label: {
                    Text("변형 연습")
                        .font(.pt(.footnote).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Theme.secondaryFill, in: .rect(cornerRadius: Radius.chip, style: .continuous))
                }
                .buttonStyle(.pressable)
                .transition(.opacity)
            }
        }
        .animation(Motion.quick, value: topic?.id)
        .task(id: subject + "|" + unit) {
            let found = await VariantLookup.find(subject: subject, unit: unit)
            topic = found
        }
    }
}

// MARK: - 풀기 (한 화면에 문제 하나)

struct VariantSessionView: View {
    let topic: VariantTopic
    /// 채팅에서 시트로 열었을 때 (닫기 버튼)
    var inSheet = false
    /// 단원 학습 안에서 열었을 때: 제목 · 배경은 바깥 화면이 맡고, 끝에 "다음 단계로"
    var embedded = false
    /// 단원 학습 안에서 열었을 때 그 단원 (오답노트 과목 · 정답률 기록에 씀)
    var link: (subject: String, unit: String)? = nil
    var onFinish: (() -> Void)? = nil

    @Environment(\.modelContext) private var context

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
    @State private var recorded = false
    /// 다음 문제를 만드는 중 (버튼을 두 번 눌러도 한 번만)
    @State private var advancing = false
    @State private var showAllSteps = false
    @FocusState private var typing: Bool

    private var size: Int { DoitVariants.setSize }
    private var maxLevel: Int { DoitVariants.levelCount(topic) }
    private var answered: Bool { result != nil }
    private var correct: Bool { result?.verdict == .correct }
    private var subjectName: String {
        if let link { return link.subject }
        switch topic.source {
        case .math: return topic.level == .middle ? "중학교 수학" : "고등학교 수학"
        case .grammar(let s, _), .knowledge(let s, _): return s
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if summary {
                    summaryView
                } else {
                    header
                    if loading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 48)
                    } else if exhausted {
                        exhaustedView
                    } else if let item {
                        VStack(alignment: .leading, spacing: 20) {
                            questionText(item)
                            answerArea(item)
                        }
                        .id(item.id)
                        .transition(.rise(6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .modifier(VariantChrome(embedded: embedded, inSheet: inSheet, title: topic.title))
        .task {
            await load()
            #if DEBUG
            await uiShotSteps()
            #endif
        }
    }

    // MARK: 위쪽: 진행 막대 + 번호 + 단계

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "\(min(round.count + (answered ? 0 : 1), size))")
                    .font(.pt(size: 28, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .numberRoll(Double(round.count))
                Text(verbatim: "/ \(size)")
                    .font(.pt(size: 15))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                TagLabel(text: DoitVariants.levelName(level, of: topic).loc)
            }
            LinearProgressBar(value: Double(round.count) / Double(size), height: 4)
        }
    }

    // MARK: 문제

    private func questionText(_ item: PracticeItem) -> some View {
        Text(MathSymbolBar.pretty(item.question))
            .font(topic.subject == .math ? Font.system(size: 22, weight: .regular, design: .serif) : Font.pt(size: 22, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func answerArea(_ item: PracticeItem) -> some View {
        if item.choices == ["O", "X"] {
            HStack(spacing: 12) {
                ForEach(1...2, id: \.self) { number in
                    choiceCell(item, number: number, text: item.choices[number - 1], big: true)
                }
            }
        } else if !item.choices.isEmpty {
            VStack(spacing: 8) {
                ForEach(Array(item.choices.enumerated()), id: \.offset) { index, choice in
                    choiceCell(item, number: index + 1, text: choice, big: false)
                        .staggerIn(index: index)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                TextField("내 답", text: $typed)
                    .font(.pt(size: 20, weight: .semibold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($typing)
                    .submitLabel(.done)
                    .onSubmit { submit(item) }
                    .disabled(answered)
                    .flatField(horizontal: 16, vertical: 14)
                    .overlay {
                        if answered {
                            RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                                .strokeBorder(correct ? Palette.success : Palette.danger, lineWidth: 1.5)
                        }
                    }
                    .shake(trigger: answered && !correct)
                    .popOnce(when: answered && correct)
                if item.kind == .math, !answered {
                    MathSymbolBar { symbol in
                        typed = MathSymbolBar.tidy(typed + symbol.insert, after: symbol)
                    }
                }
                if let note {
                    Text(note).font(.pt(.footnote)).foregroundStyle(Palette.warning)
                }
            }
        }
    }

    /// 보기 한 칸: 누르면 바로 채점. 채점 뒤에는 정답은 초록 테두리 · 내가 고른 오답은 빨강 테두리
    private func choiceCell(_ item: PracticeItem, number: Int, text: String, big: Bool) -> some View {
        let right = Int(item.answer) == number
        let mine = picked == number
        let state: Bool? = answered ? (right ? true : (mine ? false : nil)) : nil
        let tint: Color = state == true ? Palette.success : (state == false ? Palette.danger : Color.clear)
        return Button {
            guard !answered else { return }
            picked = number
            Haptics.tap()
            submit(item)
        } label: {
            HStack(spacing: 12) {
                if !big {
                    Text(verbatim: "\(number)")
                        .font(.pt(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                Text(MathSymbolBar.pretty(text))
                    .font(big ? Font.pt(size: 28, weight: .bold) : Font.pt(.body))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !big { Spacer(minLength: 0) }
                if state != nil {
                    Image(systemName: state == true ? "checkmark" : "xmark")
                        .font(.pt(.footnote).weight(.bold))
                        .foregroundStyle(tint)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, minHeight: big ? 72 : 48, alignment: big ? .center : .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, big ? 0 : 4)
            .background(tint.opacity(0.08), in: .rect(cornerRadius: Radius.card, style: .continuous))
            .background(Palette.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(state == nil ? Palette.line : tint, lineWidth: state == nil ? 0.5 : 1.5)
            }
            .opacity(answered && state == nil ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .shake(trigger: state == false)
        .popOnce(when: state == true && mine)
        .animation(Motion.quick, value: answered)
        .accessibilityLabel(text)
    }

    // MARK: 채점 뒤: 아래 막대 (맞았는지 · 짧은 풀이 · 다음)

    /// 짧은 풀이: 처음엔 두 줄만, "풀이 더 보기"를 누르면 전부
    private func feedback(_ item: PracticeItem) -> some View {
        let lines = item.explanation.map { MathSymbolBar.pretty($0) }
        let more = lines.count > 2 || lines.joined().count > 60
        let shown = showAllSteps ? lines : Array(lines.prefix(2))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Image(systemName: "circle.fill"))
                    .font(.pt(size: 7))
                    .foregroundStyle(correct ? Palette.success : Palette.danger)
                    .accessibilityHidden(true)
                Text(correct ? L("맞았어요") : L("틀렸어요"))
                    .font(.pt(.body).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                if !correct {
                    Text(MathSymbolBar.pretty(DoitVariants.answerText(item)))
                        .font(.pt(.body).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            if !shown.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.pt(.footnote))
                            .foregroundStyle(.secondary)
                            .lineLimit(showAllSteps ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            HStack(spacing: 16) {
                if more && !showAllSteps {
                    Button("풀이 더 보기") { withAnimation(Motion.quick) { showAllSteps = true } }
                        .font(.pt(.footnote).weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                if !correct {
                    let didSave = saved.contains(item.id)
                    Button { saveToNotes(item, given: given) } label: {
                        Label(didSave ? L("오답노트에 담았어요") : L("오답노트에 담기"), systemImage: didSave ? "checkmark" : "arrow.down.circle")
                            .font(.pt(.footnote).weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(didSave ? Color.secondary : Theme.accent)
                    .disabled(didSave)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.rise(6))
    }

    @ViewBuilder
    private var bottomBar: some View {
        if !summary, !loading, !exhausted, let item {
            if answered {
                let last = round.count >= size
                VStack(spacing: 8) {
                    feedback(item)
                    Button {
                        if last { showSummary() } else { Task { await next(level: level) } }
                    } label: {
                        Text(last ? L("결과 보기") : L("다음 문제"))
                    }
                    .buttonStyle(.primaryFill)
                    if !last, maxLevel > 1 {
                        HStack {
                            ladderButton(L("한 단계 쉽게"), enabled: level > 1) { Task { await next(level: level - 1) } }
                            Spacer()
                            ladderButton(L("한 단계 어렵게"), enabled: level < maxLevel) { Task { await next(level: level + 1) } }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Theme.base)
                .overlay(alignment: .top) { Hairline() }
            } else if item.choices.isEmpty {
                Button("제출") { submit(item) }
                    .buttonStyle(.primaryFill)
                    .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.base)
                    .overlay(alignment: .top) { Hairline() }
            }
        }
    }

    private func ladderButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.pt(.subheadline))
                .foregroundStyle(.secondary)
                .frame(height: 36)
                .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private var exhaustedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("더 낼 문제가 없어요")
                .font(.pt(.body).weight(.semibold))
                .foregroundStyle(Palette.ink)
            if maxLevel > 1 {
                HStack(spacing: 10) {
                    Button("한 단계 쉽게") { Task { await next(level: level - 1) } }.buttonStyle(.flat).disabled(level <= 1)
                    Button("한 단계 어렵게") { Task { await next(level: level + 1) } }.buttonStyle(.flat).disabled(level >= maxLevel)
                }
            }
            if round.count > 0 {
                Button("결과 보기") { showSummary() }.buttonStyle(.primaryFill)
            } else if embedded {
                Button("다음 단계로") { onFinish?() }.buttonStyle(.primaryFill)
            }
        }
        .softCard()
    }

    // MARK: 한 판 결과

    private var summaryView: some View {
        let score = round.filter { $0 }.count
        let unsaved = wrongs.filter { !saved.contains($0.item.id) }
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
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
                    Spacer(minLength: 8)
                    TagLabel(text: DoitVariants.levelName(level, of: topic).loc)
                }
                Text(DoitMockExam.cheer(correct: score, total: round.count).loc)
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
                Hairline()
                HStack(spacing: 14) {
                    ForEach(Array(round.enumerated()), id: \.offset) { index, ok in
                        VStack(spacing: 6) {
                            Text(verbatim: "\(index + 1)")
                                .font(.pt(.footnote).weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                            Circle()
                                .fill(ok ? Palette.success : Palette.danger)
                                .frame(width: 6, height: 6)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .softCard()
            .staggerIn(index: 0)

            if !wrongs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(wrongs.enumerated()), id: \.offset) { index, entry in
                        let didSave = saved.contains(entry.item.id)
                        HStack(spacing: 12) {
                            Text(MathSymbolBar.pretty(entry.item.question))
                                .font(.pt(.subheadline))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if didSave {
                                Image(systemName: "checkmark").font(.pt(.footnote).weight(.bold)).foregroundStyle(.secondary)
                            } else {
                                Button("담기") { saveToNotes(entry.item, given: entry.given) }
                                    .font(.pt(.subheadline).weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        if index < wrongs.count - 1 { Hairline().padding(.leading, 16) }
                    }
                }
                .softCardBackground()
                .staggerIn(index: 1)
            }

            VStack(spacing: 10) {
                if embedded {
                    Button("다음 단계로") { onFinish?() }.buttonStyle(.primaryFill)
                    Button("한 번 더") { Task { await newRound(level: level) } }.buttonStyle(.flat)
                } else {
                    Button("한 번 더") { Task { await newRound(level: level) } }.buttonStyle(.primaryFill)
                }
                if maxLevel > 1 {
                    HStack(spacing: 10) {
                        Button("한 단계 쉽게") { Task { await newRound(level: level - 1) } }.buttonStyle(.flat).disabled(level <= 1)
                        Button("한 단계 어렵게") { Task { await newRound(level: level + 1) } }.buttonStyle(.flat).disabled(level >= maxLevel)
                    }
                }
                if unsaved.count > 1 {
                    Button("틀린 문제 모두 담기") {
                        for entry in unsaved { saveToNotes(entry.item, given: entry.given) }
                    }
                    .buttonStyle(.flat)
                }
            }
            .staggerIn(index: 2)
        }
    }

    // MARK: 진행

    private func load() async {
        // 다음 문제를 만드는 동안에는 지난 문제를 그대로 두고 (깜빡임 없이) 다 만들면 바꿈
        let first = item == nil
        if first { loading = true }
        exhausted = false
        let topic = topic, level = level, avoid = seen
        let made = await Task.detached(priority: .userInitiated) { DoitVariants.makeItem(topic: topic, level: level, avoid: avoid) }.value
        withAnimation(Motion.quick) {
            resetAnswer()
            item = made
            exhausted = made == nil
            loading = false
        }
        if let made { seen.insert(DoitPractice.questionKey(made.question)) }
        advancing = false
    }

    private func resetAnswer() {
        typed = ""
        picked = nil
        result = nil
        given = ""
        note = nil
        showAllSteps = false
    }

    /// 다음 문제 (단계를 바꿀 수도 있음)
    private func next(level newLevel: Int) async {
        guard !advancing else { return }
        advancing = true
        level = max(1, min(newLevel, maxLevel))
        await load()
    }

    private func newRound(level newLevel: Int) async {
        guard !advancing else { return }
        round = []
        wrongs = []
        recorded = false
        withAnimation(Motion.quick) { summary = false }
        await next(level: newLevel)
    }

    private func showSummary() {
        // 단원 학습 안이면 정답률에 반영 (단원 목록의 정답률)
        if let link, !recorded, !round.isEmpty {
            recorded = true
            context.insert(QuizRecord(subject: link.subject, unit: link.unit, step: "variant", correct: round.filter { $0 }.count, total: round.count))
            try? context.save()
        }
        withAnimation(Motion.quick) { summary = true }
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
        showSummary()
    }
    #endif
}

/// 바깥 틀: 따로 열면 제목 · 배경 (시트면 닫기), 단원 학습 안이면 바깥 화면 것을 그대로
private struct VariantChrome: ViewModifier {
    let embedded: Bool
    let inSheet: Bool
    let title: String
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        if embedded {
            content
        } else {
            content
                .background { AppBackground() }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .tabBar)
                .toolbar {
                    if inSheet {
                        ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } }
                    }
                }
        }
    }
}
