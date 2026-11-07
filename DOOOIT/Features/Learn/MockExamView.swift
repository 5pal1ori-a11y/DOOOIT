import SwiftData
import SwiftUI

/// AI 모의고사: 범위 고르기 → 10문제 (시간 재기) → 제출 → 점수 · 문제마다 정답/해설
/// 문제는 검증된 생성기로만 만들고(DoitMockExam), 채점 뒤 취약 개념 숙련도와 풀이 기록을 남겨요.
struct MockExamView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeakConcept.mastery) private var concepts: [WeakConcept]
    @Query(sort: \QuizRecord.date, order: .reverse) private var records: [QuizRecord]
    @Query private var notes: [MathNote]

    enum Stage: Equatable { case setup, loading, taking, result }

    @State private var stage: Stage = .setup
    @State private var scope: NoteSubject?
    @State private var exam: MockExam?
    @State private var answers: [UUID: String] = [:]
    @State private var index = 0
    @State private var startedAt = Date()
    @State private var finishedAt = Date()
    @State private var results: [Bool] = []
    @State private var confirmSubmit = false
    @State private var expanded: Set<UUID> = []
    @FocusState private var typing: Bool

    var body: some View {
        Group {
            switch stage {
            case .setup, .loading: setup
            case .taking: taking
            case .result: result
            }
        }
        .background { AppBackground() }
        .navigationTitle("AI 모의고사")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.smooth(duration: 0.3), value: stage)
        .navigationBarBackButtonHidden(stage == .taking)
        .toolbar {
            if stage == .taking {
                ToolbarItem(placement: .topBarLeading) {
                    Button("그만") { stage = .setup; exam = nil }
                }
                ToolbarItem(placement: .principal) { clock }
            }
        }
        .confirmationDialog("제출할까요?", isPresented: $confirmSubmit, titleVisibility: .visible) {
            Button("제출") { submit() }
            Button("계속 풀기", role: .cancel) {}
        } message: {
            Text("안 푼 문제 \(unanswered)개")
        }
        #if DEBUG
        .task {
            if UIShot.matches(.mockExam) { await begin() }
            if UIShot.matches(.mockResult) {
                await begin()
                if let exam { for (i, q) in exam.questions.enumerated() { answers[q.id] = i % 4 == 2 ? "1" : q.item.answer } }
                submit()
            }
        }
        #endif
    }

    // MARK: 데이터

    /// 아직 익히지 않은 개념 (약한 순서)
    private var weakSources: [MockExamSource] {
        concepts.filter { $0.state != .mastered }.map { concept in
            let note = notes.first { $0.conceptKey == concept.key && $0.status == .wrong } ?? notes.first { $0.conceptKey == concept.key }
            return MockExamSource(key: concept.key, subject: concept.subject, unit: concept.unit, concept: concept.concept,
                                  problem: note.map { $0.scan?.body ?? $0.recognizedText } ?? "",
                                  mastery: concept.mastery, wrongCount: concept.wrongCount)
        }
    }

    /// 최근에 공부한 단원 (모의고사 기록 빼고)
    private var recentSources: [MockExamSource] {
        var seen = Set<String>()
        var list: [MockExamSource] = []
        for record in records where record.step != DoitMockExam.step && !record.unit.isEmpty {
            guard seen.insert(record.subject + "|" + record.unit).inserted else { continue }
            list.append(MockExamSource(subject: record.subject, unit: record.unit, concept: record.unit))
            if list.count >= 6 { break }
        }
        return list
    }

    private var questions: [MockExamQuestion] { exam?.questions ?? [] }
    private var unanswered: Int { questions.filter { (answers[$0.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }.count }

    // MARK: 1. 범위

    private var setup: some View {
        let weak = weakSources
        let subjects = DoitMockExam.subjects(in: weak)
        let inScope = weak.filter { scope == nil || $0.category == scope }.count
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    IconBadge(symbol: "doc.text", color: Palette.sky, size: 48)
                    Text("내 취약 개념으로 10문제")
                        .font(.pt(.title3).weight(.bold))
                        .foregroundStyle(Palette.ink)
                    HStack(spacing: 6) {
                        TagLabel(text: L("\(DoitMockExam.size)문제"), symbol: "list.number", color: Palette.sky)
                        TagLabel(text: L("\(DoitMockExam.minutes)분"), symbol: "timer", color: Palette.butter)
                        TagLabel(text: L("객관식 · 단답"), color: .secondary)
                    }
                }
                .softCard(cornerRadius: 24, padding: 20)
                .staggerIn(index: 0)

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(L("범위"))
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            scopeChip(nil, title: L("전체"), symbol: "square.grid.2x2")
                            ForEach(subjects) { subject in
                                scopeChip(subject, title: subject.rawValue.loc, symbol: subject.symbol)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .scrollIndicators(.hidden)
                    if inScope < DoitMockExam.minWeak {
                        Label(inScope == 0 ? L("취약 개념이 없어서 최근 단원으로 내요") : L("취약 개념이 적어서 최근 단원도 섞어요"), systemImage: "info.circle")
                            .font(.pt(.footnote))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    } else {
                        Label("취약 개념 \(inScope)개", systemImage: "target")
                            .font(.pt(.footnote))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .staggerIn(index: 1)

                Button {
                    Task { await begin() }
                } label: {
                    if stage == .loading {
                        ProgressView().tint(.white)
                    } else {
                        Label("시작", systemImage: "play.fill")
                    }
                }
                .buttonStyle(.primaryFill)
                .disabled(stage == .loading)
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func scopeChip(_ subject: NoteSubject?, title: String, symbol: String) -> some View {
        let on = scope == subject
        return Button {
            scope = subject
            Haptics.tap()
        } label: {
            Label(title, systemImage: symbol)
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(on ? Theme.onAccent : Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(on ? Theme.accent : Palette.card, in: .capsule)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(on ? 0 : 0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func begin() async {
        stage = .loading
        let weak = weakSources, recent = recentSources, scope = scope
        let made = await Task.detached(priority: .userInitiated) {
            DoitMockExam.assemble(weak: weak, recent: recent, scope: scope)
        }.value
        guard !made.questions.isEmpty else {
            stage = .setup
            return
        }
        exam = made
        answers = [:]
        expanded = []
        index = 0
        startedAt = Date()
        stage = .taking
    }

    // MARK: 2. 풀기

    private var clock: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { timeline in
            let left = DoitMockExam.minutes * 60 - Int(timeline.date.timeIntervalSince(startedAt))
            // 툴바의 Label은 아이콘만 보여서 직접 나란히
            HStack(spacing: 5) {
                Image(systemName: left >= 0 ? "timer" : "exclamationmark.circle")
                Text((left >= 0 ? "" : "+") + Self.mmss(abs(left)))
                    .contentTransition(.numericText())
            }
            .font(.pt(.subheadline).weight(.semibold).monospacedDigit())
            .foregroundStyle(left >= 0 ? Palette.ink : Palette.warning)
            .accessibilityLabel(left >= 0 ? L("남은 시간 \(Self.mmss(left))") : L("시간 지남"))
        }
    }

    private var taking: some View {
        let list = questions
        let current = list.indices.contains(index) ? list[index] : nil
        return VStack(spacing: 0) {
            numberStrip(list)
                .padding(.top, 6)
            ScrollView {
                if let current {
                    questionCard(current, number: index + 1)
                        .id(current.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            HStack(spacing: 10) {
                Button {
                    withAnimation(.snappy) { index = max(0, index - 1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.pt(.headline))
                        .frame(width: 54, height: 54)
                        .background(Palette.card, in: .rect(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .accessibilityLabel("이전 문제")
                if index < list.count - 1 {
                    Button("다음") { withAnimation(.snappy) { index += 1 } }
                        .buttonStyle(.primaryFill)
                } else {
                    Button("제출") {
                        typing = false
                        if unanswered > 0 { confirmSubmit = true } else { submit() }
                    }
                    .buttonStyle(.primaryFill)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    /// 문제 번호 (푼 문제는 색이 참)
    private func numberStrip(_ list: [MockExamQuestion]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(list.enumerated()), id: \.element.id) { i, q in
                let done = !(answers[q.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
                Button { withAnimation(.snappy) { index = i } } label: {
                    Text("\(i + 1)")
                        .font(.pt(.caption).weight(.bold).monospacedDigit())
                        .foregroundStyle(i == index ? Theme.onAccent : (done ? Theme.accent : .secondary))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(i == index ? Theme.accent : (done ? Theme.accent.pastel : Color.primary.opacity(0.05)),
                                    in: .rect(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func questionCard(_ q: MockExamQuestion, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Text("\(number)번").font(.pt(.headline)).foregroundStyle(Theme.accent)
                TagLabel(text: q.isChoice ? L("객관식") : L("단답"), color: .secondary)
                Spacer()
                Text(q.concept).font(.pt(.caption)).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(MathSymbolBar.pretty(q.item.question))
                .font(.pt(.body).weight(.medium))
                .foregroundStyle(Palette.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            if q.isChoice {
                VStack(spacing: 8) {
                    ForEach(Array(q.item.choices.enumerated()), id: \.offset) { i, choice in
                        choiceRow(q, number: i + 1, text: choice)
                    }
                }
            } else {
                TextField("답", text: Binding(get: { answers[q.id] ?? "" }, set: { answers[q.id] = $0 }))
                    .font(.pt(.title3).weight(.semibold))
                    .focused($typing)
                    .submitLabel(.next)
                    .onSubmit { if index < questions.count - 1 { withAnimation(.snappy) { index += 1 } } }
                    .padding(14)
                    .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 14, style: .continuous))
                if q.item.kind == .math {
                    MathSymbolBar { symbol in
                        let text = (answers[q.id] ?? "") + symbol.insert
                        answers[q.id] = MathSymbolBar.tidy(text, after: symbol)
                    }
                }
            }
        }
        .softCard(cornerRadius: 24, padding: 20)
    }

    private func choiceRow(_ q: MockExamQuestion, number: Int, text: String) -> some View {
        let on = answers[q.id] == "\(number)"
        let marks = ["①", "②", "③", "④", "⑤", "⑥"]
        return Button {
            answers[q.id] = "\(number)"
            Haptics.tap()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(number <= marks.count ? marks[number - 1] : "\(number)")
                    .font(.pt(.headline))
                    .foregroundStyle(on ? Theme.onAccent : Theme.accent)
                Text(MathSymbolBar.pretty(text))
                    .font(.pt(.subheadline))
                    .foregroundStyle(on ? Theme.onAccent : Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(on ? Theme.accent : Color.primary.opacity(0.05), in: .rect(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    // MARK: 3. 결과

    private func submit() {
        let list = questions
        guard !list.isEmpty else { return }
        finishedAt = Date()
        results = list.map { DoitMockExam.isCorrect($0, answer: answers[$0.id] ?? "") }
        // 개념마다 숙련도 · 풀이 기록
        for (q, ok) in zip(list, results) {
            WeakConceptStore.recordMock(key: q.sourceKey, correct: ok, answer: answers[q.id] ?? "",
                                        correctAnswer: DoitMockExam.answerText(q.item), context: context)
        }
        // 단원별 풀이 기록 (같은 시각 = 한 번의 시험)
        let date = Date()
        for group in DoitMockExam.groups(list, results: results) {
            let record = QuizRecord(subject: group.subject, unit: group.unit, step: DoitMockExam.step, correct: group.correct, total: group.total)
            record.date = date
            context.insert(record)
        }
        try? context.save()
        let score = results.filter { $0 }.count
        if score == list.count { Haptics.celebrate() } else { Haptics.tap() }
        stage = .result
        BadgeCenter.shared.check(context: context)
    }

    private var result: some View {
        let list = questions
        let score = results.filter { $0 }.count
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 20) {
                    ZStack {
                        ProgressRing(progress: Double(score) / Double(max(list.count, 1)), lineWidth: 12,
                                     color: score == list.count ? Palette.success : Theme.accent)
                        VStack(spacing: 0) {
                            Text("\(score)").font(.pt(size: 30, weight: .bold)).foregroundStyle(Palette.ink)
                            Text("/ \(list.count)").font(.pt(.caption)).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(DoitMockExam.cheer(correct: score, total: list.count))
                            .font(.pt(.title3).weight(.bold))
                            .foregroundStyle(Palette.ink)
                        Label(Self.mmss(Int(finishedAt.timeIntervalSince(startedAt))), systemImage: "timer")
                            .font(.pt(.subheadline))
                            .foregroundStyle(.secondary)
                        if exam?.usedFallback == true {
                            Text("최근 단원도 섞었어요").font(.pt(.caption)).foregroundStyle(.tertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .softCard(cornerRadius: 24, padding: 20)
                .staggerIn(index: 0)

                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, q in
                        reviewRow(q, number: i + 1, correct: results.indices.contains(i) && results[i])
                        if i < list.count - 1 { RowDivider() }
                    }
                }
                .softCardBackground(cornerRadius: 20)
                .staggerIn(index: 1)

                HStack(spacing: 10) {
                    Button("새 시험") { Task { await begin() } }
                        .buttonStyle(.primaryFill)
                    Button {
                        dismiss()
                    } label: {
                        Text("닫기")
                            .font(.pt(.body).weight(.bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 96, height: 54)
                            .background(Palette.card, in: .rect(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    /// 문제 한 줄: ✓/✗ + 문제 → 누르면 내 답 · 정답 · 해설
    private func reviewRow(_ q: MockExamQuestion, number: Int, correct: Bool) -> some View {
        let open = expanded.contains(q.id)
        let mine = answers[q.id] ?? ""
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) {
                    if open { expanded.remove(q.id) } else { expanded.insert(q.id) }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: correct ? "checkmark" : "xmark")
                        .font(.pt(size: 14, weight: .bold))
                        .foregroundStyle(correct ? Palette.success : Palette.danger)
                        .frame(width: 32, height: 32)
                        .background((correct ? Palette.success : Palette.danger).pastel, in: .rect(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(number)번 · \(q.concept)").font(.pt(.caption)).foregroundStyle(.secondary).lineLimit(1)
                        Text(MathSymbolBar.pretty(q.item.question.components(separatedBy: "\n").last ?? q.item.question))
                            .font(.pt(.subheadline).weight(.semibold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(open ? nil : 1)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.pt(.footnote).weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    if q.item.question.contains("\n") {
                        Text(MathSymbolBar.pretty(q.item.question)).font(.pt(.footnote)).foregroundStyle(.secondary)
                    }
                    answerLine(L("내 답"), mine.isEmpty ? "—" : (q.isChoice ? choiceText(q, mine) : mine), color: correct ? Palette.success : Palette.danger)
                    answerLine(L("정답"), DoitMockExam.answerText(q.item), color: Palette.success)
                    ForEach(Array(q.item.explanation.prefix(4).enumerated()), id: \.offset) { _, line in
                        Text(MathSymbolBar.pretty(line)).font(.pt(.footnote)).foregroundStyle(Palette.ink.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 14, style: .continuous))
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func answerLine(_ title: String, _ value: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).font(.pt(.caption).weight(.bold)).foregroundStyle(color).frame(width: 34, alignment: .leading)
            Text(MathSymbolBar.pretty(value)).font(.pt(.subheadline).weight(.semibold)).foregroundStyle(Palette.ink)
        }
    }

    private func choiceText(_ q: MockExamQuestion, _ answer: String) -> String {
        var item = q.item
        item.answer = answer
        return DoitMockExam.answerText(item)
    }

    static func mmss(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
