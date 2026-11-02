import SwiftData
import SwiftUI

// 수학이 아닌 과목의 오답노트: 채점 → 틀린 이유(직접 고르기) → 해설(개념 카드·단어·AI 해설) → 다시 풀기(간격 복습)

extension NoteSubject {
    var color: Color { Color(hex: colorHex) }
}

extension MathNote {
    /// 틀린 적 있는 과목 노트의 다시 풀기 일정 (수학은 유사 문제 단계 학습을 씀)
    var reviewSchedule: WordReview.Schedule? {
        guard !subjectKind.isMath else { return nil }
        let retries = ladder?.retries ?? []
        let gradedWrong = grade.map { $0.verdict == .wrong || $0.verdict == .partial } ?? false
        let everWrong = gradedWrong || retries.contains(where: { !$0.correct })
        guard everWrong else { return nil }
        return DoitSubjectNote.reviewSchedule(start: createdAt, retries: retries)
    }

    var isReviewDue: Bool {
        guard let schedule = reviewSchedule else { return false }
        return WordReview.isDue(stage: schedule.stage, next: schedule.next)
    }
}

/// 작은 과목 표시
struct SubjectTag: View {
    let subject: NoteSubject
    var body: some View {
        Text(subject.rawValue)
            .font(.caption2.weight(.bold))
            .foregroundStyle(subject.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(subject.color.opacity(0.14), in: .capsule)
    }
}

// MARK: - ③ 왜 틀렸을까? (과목별 원인 고르기)

struct SubjectCauseCard: View {
    @Bindable var note: MathNote
    @Environment(\.modelContext) private var context

    private var subject: NoteSubject { note.subjectKind }
    private var isWrong: Bool { note.grade.map { $0.verdict == .wrong || $0.verdict == .partial } ?? (note.status == .wrong) }

    var body: some View {
        if isWrong {
            let analysis = note.analysis
            VStack(alignment: .leading, spacing: 12) {
                FlowHeader(number: 3, title: "왜 틀렸을까?", symbol: "magnifyingglass", trailing: certaintyText(analysis),
                           trailingColor: analysis?.certainty == .confirmed ? Palette.success : Palette.warning)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(subject.causes, id: \.self) { cause in
                        let isOn = analysis?.cause == cause
                        Button { choose(cause) } label: {
                            Text(cause.label)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .foregroundStyle(isOn ? Palette.card : Palette.ink)
                                .background(isOn ? AnyShapeStyle(Palette.ink) : AnyShapeStyle(Color.primary.opacity(0.06)), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let analysis, analysis.cause != .unknown {
                    Label(DoitSubjectNote.tip(for: analysis.cause, subject: subject), systemImage: "lightbulb")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                }
                if let evidence = analysis?.evidence.first {
                    Text(evidence).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .softCard()
        }
    }

    private func certaintyText(_ analysis: MistakeAnalysis?) -> String? {
        switch analysis?.certainty {
        case .estimated?: return "추정"
        case .confirmed?: return "직접 고름"
        default: return nil
        }
    }

    private func choose(_ cause: MistakeAnalysis.Cause) {
        let old = note.analysis?.cause.rawValue
        withAnimation(.snappy) { note.analysis = DoitSubjectNote.choose(cause, subject: subject, base: note.analysis) }
        Haptics.tap()
        WeakConceptStore.changeCause(note: note, from: old, to: cause.rawValue, context: context)
        note.updatedAt = Date()
        try? context.save()
    }
}

// MARK: - ④ 해설 (개념 카드 · 단어 · AI 해설)

struct SubjectExplainCard: View {
    @Bindable var note: MathNote
    @Environment(\.modelContext) private var context
    @Query private var words: [Word]

    @State private var expanded: Set<String> = []
    @State private var aiText: String?
    @State private var aiWorking = false
    @State private var aiFailed = false
    @State private var added: Set<String> = []

    private var subject: NoteSubject { note.subjectKind }
    private var problemBody: String { note.scan?.body ?? note.recognizedText }
    private var choices: [String] { note.scan?.choices ?? [] }
    private var correctText: String {
        guard !note.correctAnswer.isEmpty else { return "" }
        return DoitSubjectNote.describe(note.correctAnswer, choices: choices)
    }
    private var answerText: String {
        if let n = DoitGrader.choiceNumber(note.correctAnswer, choices: choices), choices.indices.contains(n - 1) { return choices[n - 1] }
        return note.correctAnswer
    }

    private var concepts: [DoitKnowledge.Entry] {
        var list: [DoitKnowledge.Entry] = []
        let unit = note.unit.trimmingCharacters(in: .whitespaces)
        if !unit.isEmpty, let entry = DoitKnowledge.entry(named: unit) { list.append(entry) }
        for entry in DoitSubjectNote.concepts(problem: problemBody, choices: choices, answer: answerText, subject: subject)
            where !list.contains(where: { $0.title == entry.title }) { list.append(entry) }
        return Array(list.prefix(3))
    }

    private var wordHints: [DoitSubjectNote.WordHint] {
        let text = problemBody + "\n" + choices.joined(separator: "\n")
        let book = DoitSubjectNote.wordBookHits(text: text, book: words.map { ($0.term, $0.meaning) })
        guard subject == .english else { return book }
        let skip = Set(book.map { $0.term.lowercased() })
        return book + DoitSubjectNote.answerWordHints(answer: answerText, choices: choices, skip: skip)
    }

    private var solution: WrittenSolution? {
        note.solutionData.flatMap { try? JSONDecoder().decode(WrittenSolution.self, from: $0) }
    }

    var body: some View {
        let concepts = self.concepts
        let hints = self.wordHints
        VStack(alignment: .leading, spacing: 14) {
            FlowHeader(number: 4, title: "해설", symbol: "book")
            if !correctText.isEmpty {
                HStack(spacing: 8) {
                    Text("정답").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Text(correctText).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                }
            }
            if let solution, !solution.steps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    sectionTitle("풀이")
                    ForEach(Array(solution.steps.enumerated()), id: \.offset) { _, step in
                        Text(step.work).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !concepts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("개념")
                    ForEach(concepts, id: \.title) { conceptRow($0) }
                }
            }
            if !hints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    sectionTitle("단어")
                    ForEach(hints, id: \.self) { wordRow($0) }
                }
            }
            if concepts.isEmpty && hints.isEmpty && solution == nil {
                Text("찾은 개념이 없어요").font(.subheadline).foregroundStyle(.secondary)
            }
            aiSection
        }
        .softCard()
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.caption.weight(.bold)).foregroundStyle(.secondary)
    }

    private func conceptRow(_ entry: DoitKnowledge.Entry) -> some View {
        let open = expanded.contains(entry.title)
        return Button {
            withAnimation(.snappy) { if open { expanded.remove(entry.title) } else { expanded.insert(entry.title) } }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.title).font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
                    Text(entry.label).font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: open ? "chevron.up" : "chevron.down").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
                }
                Text(entry.body)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink.opacity(0.85))
                    .lineLimit(open ? nil : 3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.cardInset, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func wordRow(_ hint: DoitSubjectNote.WordHint) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(hint.term).font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
            Text(hint.meaning).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if hint.inBook {
                Image(systemName: "book.closed.fill").font(.caption).foregroundStyle(subject.color)
                    .accessibilityLabel("단어장에 있음")
            } else if let meaning = DoitEnglish.koreanMeaning(of: hint.term) {
                let done = added.contains(hint.term)
                Button {
                    guard !done else { return }
                    context.insert(Word(term: hint.term, meaning: meaning, deck: "오답노트"))
                    try? context.save()
                    added.insert(hint.term)
                    Haptics.success()
                } label: {
                    Image(systemName: done ? "checkmark" : "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 26, height: 26)
                        .foregroundStyle(Theme.accent)
                        .background(Theme.accent.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(done ? "추가됨" : "단어장에 추가")
            }
        }
    }

    // MARK: AI 해설 (기기 안 모델이 있을 때만)

    @ViewBuilder
    private var aiSection: some View {
        if DoitBrain.shared.isAvailable, !note.correctAnswer.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if let aiText {
                    HStack(spacing: 6) {
                        Label("AI 해설", systemImage: "sparkles").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                        Text("틀릴 수 있어요").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(aiText).font(.subheadline).foregroundStyle(Palette.ink).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                } else if aiWorking {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("AI 해설 쓰는 중").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Button { Task { await explain() } } label: {
                        Label("AI 해설", systemImage: "sparkles").frame(maxWidth: .infinity).frame(height: 36)
                    }
                    .buttonStyle(.glass)
                    if aiFailed { Text("지금은 만들 수 없어요").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
    }

    private func explain() async {
        aiWorking = true
        aiFailed = false
        defer { aiWorking = false }
        let prompt = DoitSubjectNote.explainPrompt(problem: problemBody, choices: choices, correct: note.correctAnswer, mine: note.myAnswer,
                                                   subject: subject, concepts: concepts)
        guard let raw = try? await DoitBrain.shared.complete(system: DoitMind.persona, prompt: prompt, maxTokens: 500, temperature: 0.3) else {
            aiFailed = true
            return
        }
        let text = DoitMind.answer(raw)
        if DoitMind.isUsable(text) { withAnimation(.snappy) { aiText = text } } else { aiFailed = true }
    }
}

// MARK: - ⑤ 다시 풀기 (선택지 섞어서) · 간격 복습

struct SubjectRetryCard: View {
    @Bindable var note: MathNote
    @Environment(\.modelContext) private var context

    @State private var solving = false
    @State private var order: [Int] = []
    @State private var answer = ""
    @State private var result: GradeResult?
    @State private var given = ""

    private var subject: NoteSubject { note.subjectKind }
    private var choices: [String] { note.scan?.choices ?? [] }
    private var kind: ProblemKind {
        let k = note.kind ?? note.scan?.kind ?? .shortAnswer
        return k == .math ? .shortAnswer : k
    }
    private var isChoice: Bool { kind == .multipleChoice && choices.count >= 2 }
    private var isOX: Bool { DoitSubjectNote.isOXQuestion(note.recognizedText, answerKey: note.correctAnswer) }
    private var retries: [PracticeAttempt] { note.ladder?.retries ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowHeader(number: 5, title: "다시 풀기", symbol: "arrow.counterclockwise", trailing: scheduleText,
                       trailingColor: note.isReviewDue ? Palette.warning : Theme.accent)
            if note.correctAnswer.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("정답을 적으면 다시 풀 수 있어요").font(.subheadline).foregroundStyle(.secondary)
            } else if solving {
                solveView
            } else {
                if let result { feedback(result) }
                Button(action: start) {
                    Label(retries.isEmpty && result == nil ? "다시 풀기" : "한 번 더", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity).frame(height: 38)
                }
                .buttonStyle(.glassProminent)
            }
            if !retries.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(retries.suffix(6).enumerated()), id: \.offset) { _, attempt in
                        Image(systemName: attempt.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(attempt.correct ? Palette.success : Palette.danger)
                    }
                    Text(retries.last.map { $0.date.kr("M월 d일") } ?? "").font(.caption).foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .softCard()
    }

    private var scheduleText: String? {
        guard let schedule = note.reviewSchedule else { return nil }
        guard let next = schedule.next else { return "익힘" }
        return "복습 · " + WordReview.describe(next)
    }

    @ViewBuilder
    private var solveView: some View {
        let problem = note.scan?.body ?? note.recognizedText
        Text(MathSymbolBar.pretty(problem))
            .font(.system(size: 16, design: .serif))
            .lineSpacing(5)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
        if isChoice {
            ForEach(Array(order.enumerated()).filter { choices.indices.contains($0.element) }, id: \.offset) { display, original in
                Button { submit("\(original + 1)") } label: {
                    HStack(spacing: 10) {
                        Text("\(display + 1)").font(.subheadline.weight(.bold)).frame(width: 26, height: 26)
                            .background(Theme.accent.opacity(0.12), in: .circle)
                        Text(MathSymbolBar.pretty(choices[original])).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        } else if isOX {
            HStack(spacing: 10) {
                ForEach(["O", "X"], id: \.self) { mark in
                    Button { submit(mark) } label: {
                        Text(mark).font(.title2.weight(.bold)).frame(maxWidth: .infinity).frame(height: 52)
                            .foregroundStyle(Palette.ink)
                            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            HStack(spacing: 8) {
                TextField("내 답", text: $answer, axis: kind == .essay ? .vertical : .horizontal)
                    .lineLimit(kind == .essay ? 2...6 : 1...1)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
                Button("채점") { submit(answer) }
                    .buttonStyle(.glassProminent)
                    .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        Button("그만하기") { withAnimation(.snappy) { solving = false } }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func feedback(_ result: GradeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch result.verdict {
            case .correct:
                Label("정답이에요", systemImage: "checkmark.circle.fill").font(.subheadline.weight(.bold)).foregroundStyle(Palette.success)
            case .wrong:
                Label("오답 · 정답 \(correctShown)", systemImage: "xmark.circle.fill").font(.subheadline.weight(.bold)).foregroundStyle(Palette.danger)
            case .partial, .needsReview:
                Text(result.reasons.first ?? "확인이 필요해요").font(.subheadline)
                HStack(spacing: 10) {
                    confirm("맞았어요", correct: true)
                    confirm("틀렸어요", correct: false)
                }
            }
        }
        .transition(.opacity)
    }

    /// 섞은 번호 대신 보기 글로
    private var correctShown: String {
        if let n = DoitGrader.choiceNumber(note.correctAnswer, choices: choices), choices.indices.contains(n - 1) { return choices[n - 1] }
        return note.correctAnswer
    }

    private func confirm(_ title: String, correct: Bool) -> some View {
        Button {
            record(correct: correct)
            withAnimation(.snappy) { result = nil }
        } label: {
            Text(title).font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                .foregroundStyle(.white)
                .background(correct ? Palette.success : Palette.danger, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func start() {
        order = DoitSubjectNote.shuffledOrder(count: choices.count, seed: UInt64.random(in: 0...UInt64.max))
        answer = ""
        result = nil
        withAnimation(.snappy) { solving = true }
    }

    private func submit(_ value: String) {
        given = value
        let graded = DoitGrader.grade(.init(kind: kind, student: value, answerKey: note.correctAnswer, choices: choices,
                                            problem: note.scan?.body ?? note.recognizedText, subject: subject))
        withAnimation(.snappy) {
            result = graded
            solving = false
        }
        if graded.verdict == .correct || graded.verdict == .wrong { record(correct: graded.verdict == .correct) }
    }

    private func record(correct: Bool) {
        var ladder = note.ladder ?? PracticeLadder(level: 3)
        ladder.retries.append(PracticeAttempt(level: 3, question: "원래 문제", given: given, correct: correct))
        note.ladder = ladder
        WeakConceptStore.recordGrade(note: note, correct: correct, level: 3, source: "재도전", context: context)
        if correct { note.status = .correct; Haptics.success() } else { Haptics.error() }
        note.updatedAt = Date()
        try? context.save()
    }
}
