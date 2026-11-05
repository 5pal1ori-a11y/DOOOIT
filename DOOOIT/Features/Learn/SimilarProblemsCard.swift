import SwiftData
import SwiftUI

/// ⑤ 유사 문제 단계 학습 + ⑥ 재도전
/// 1단계 개념 확인 → 2단계 쉬운 유형 → 3단계 비슷한 난이도 → 4단계 응용 → 5단계 최종 복습
/// 맞히면 올라가고, 틀리면 개념을 다시 보여주고 쉬운 문제로. 모든 풀이는 취약 개념 숙련도에 기록돼요.
struct SimilarProblemsCard: View {
    @Bindable var note: MathNote
    /// 유사 문제 단계 학습 없이 원래 문제 재도전만 (오답노트 풀이 탭)
    var retryOnly = false
    @Environment(\.modelContext) private var context

    @State private var ladder: PracticeLadder?
    @State private var answer = ""
    @State private var lastResult: (item: PracticeItem, result: GradeResult)?
    @State private var working = false
    @State private var message: String?
    @State private var retryAnswer = ""
    @State private var retryResult: GradeResult?

    private var basis: DoitPractice.Basis { DoitPractice.basis(problem: note.scan?.body ?? note.recognizedText, noteUnit: note.unit) }

    var body: some View {
        if retryOnly {
            retrySection
                .softCard()
                .onAppear { if ladder == nil { ladder = note.ladder } }
        } else {
            ladderBody
        }
    }

    private var ladderBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            FlowHeader(number: 5, title: L("유사 문제 단계 학습"), symbol: "stairs",
                       trailing: ladder.map { $0.finished ? L("완료") : L("\($0.level)단계") })
            if let ladder {
                levelDots(ladder)
                if let lastResult { feedback(lastResult.item, lastResult.result, reminder: ladder.reminder) }
                if ladder.finished {
                    Label("5단계까지 통과했어요! 2~3일 뒤 원래 문제를 다시 풀어서 확실히 익혔는지 확인해요.", systemImage: "trophy.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.success)
                } else if let item = ladder.current {
                    itemView(item)
                } else if working {
                    ProgressView("다음 문제를 만드는 중…").font(.caption)
                } else {
                    Button { Task { await nextItem() } } label: {
                        Label(lastResult == nil ? L("\(PracticeLadder.levelTitle(ladder.level).loc) 시작") : L("다음 문제"), systemImage: "arrow.right")
                            .frame(maxWidth: .infinity).frame(height: 38)
                    }
                    .buttonStyle(.glassProminent)
                }
            } else {
                Text("같은 핵심 개념을 단계별로 연습해요. 숫자만 바꾼 문제가 아니라 개념 확인 → 쉬운 유형 → 비슷한 문제 → 응용 → 최종 복습 순서로, 맞히면 어려워지고 틀리면 개념을 다시 보여줘요.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button { Task { await start() } } label: {
                    Label("단계 학습 시작", systemImage: "sparkles").frame(maxWidth: .infinity).frame(height: 38)
                }
                .buttonStyle(.glassProminent)
                .disabled(note.recognizedText.isEmpty || working)
            }
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }

            Divider().padding(.vertical, 4)
            retrySection
        }
        .softCard()
        .onAppear { if ladder == nil { ladder = note.ladder } }
    }

    // MARK: 단계 표시

    private func levelDots(_ ladder: PracticeLadder) -> some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { level in
                let passed = ladder.history.contains { $0.level == level && $0.correct }
                Capsule()
                    .fill(passed ? AnyShapeStyle(AccentGradient.linear) : AnyShapeStyle(level == ladder.level ? Theme.accent.opacity(0.35) : Color.primary.opacity(0.08)))
                    .frame(height: 8)
            }
        }
        .accessibilityLabel("\(ladder.level)단계, 정답 \(ladder.correctCount)개")
    }

    private func itemView(_ item: PracticeItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(PracticeLadder.levelTitle(item.level).loc).font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
            Text(MathSymbolBar.pretty(item.question))
                .font(.system(size: 16, design: .serif))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            if !item.choices.isEmpty {
                ForEach(Array(item.choices.enumerated()), id: \.offset) { index, choice in
                    Button { submit(item, answer: "\(index + 1)") } label: {
                        HStack {
                            Text("\(index + 1)").font(.subheadline.weight(.bold)).frame(width: 26, height: 26).background(Theme.accent.opacity(0.12), in: .circle)
                            Text(MathSymbolBar.pretty(choice)).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 8) {
                    TextField("내 답", text: $answer)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(10)
                        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
                    Button("제출") { submit(item, answer: answer) }
                        .buttonStyle(.glassProminent)
                        .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func feedback(_ item: PracticeItem, _ result: GradeResult, reminder: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(result.verdict == .correct ? L("정답이에요! 한 단계 올라가요") : (result.verdict == .needsReview ? L("확인이 필요해요") : L("아쉬워요. 개념을 다시 보고 쉬운 문제로 가요")),
                  systemImage: result.verdict == .correct ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(result.verdict == .correct ? Palette.success : Palette.warning)
            if result.verdict != .correct { Text("정답: \(MathSymbolBar.pretty(item.choices.isEmpty ? item.answer : "\(item.answer)번"))").font(.subheadline.weight(.semibold)) }
            ForEach(item.explanation, id: \.self) { line in
                Text(MathSymbolBar.pretty(line)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let reminder, result.verdict != .correct {
                Text(MathSymbolBar.pretty(reminder))
                    .font(.subheadline)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.warning.opacity(0.1), in: .rect(cornerRadius: 12))
            }
        }
    }

    // MARK: 진행

    private func start() async {
        ladder = PracticeLadder(level: note.analysis?.startLevel ?? 2)
        lastResult = nil
        await nextItem()
    }

    private func nextItem() async {
        guard var current = ladder else { return }
        working = true
        defer { working = false }
        let asked = current.history.map(\.question)
        if let item = await DoitPractice.makeItem(level: current.level, basis: basis, avoid: asked) {
            current.current = item
            message = nil
        } else if let item = await DoitPractice.makeItem(level: max(2, current.level - 1), basis: basis, avoid: asked) {
            current.current = item
            message = L("이 단계 문제를 만들 수 없어 한 단계 쉬운 문제로 냈어요.")
        } else {
            message = L("이 문제의 유형으로는 검증된 유사 문제를 만들 수 없어요. 문제 글이 정확한지 확인하거나, 단원(개념 이름)을 적어 주세요.")
        }
        answer = ""
        ladder = current
        save()
    }

    private func submit(_ item: PracticeItem, answer given: String) {
        guard var current = ladder else { return }
        let result = DoitPractice.grade(item, answer: given)
        guard result.verdict != .needsReview else {
            message = result.reasons.first
            return
        }
        DoitPractice.advance(&current, item: item, answer: given, result: result, reminder: basis.reminder)
        withAnimation(.snappy) {
            lastResult = (item, result)
            ladder = current
        }
        if result.verdict == .correct { Haptics.success() } else { Haptics.error() }
        WeakConceptStore.recordGrade(note: note, correct: result.verdict == .correct, level: item.level, source: "유사 문제", context: context)
        save()
    }

    // MARK: 재도전 (원래 문제)

    private var retrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowHeader(number: retryOnly ? 4 : 6, title: L("원래 문제 재도전"), symbol: "arrow.counterclockwise")
            Text(retryOnly ? L("정답을 보지 않고 다시 풀어 봐요.") : L("유사 문제를 푼 뒤 원래 문제를 정답을 보지 않고 다시 풀어 봐요.")).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("다시 푼 답", text: $retryAnswer)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
                Button("채점", action: retry)
                    .buttonStyle(.glassProminent)
                    .disabled(retryAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let retryResult {
                Text(retryResult.verdict == .correct ? L("재도전 성공! 🎉") : (retryResult.verdict == .needsReview ? (retryResult.reasons.first ?? L("확인이 필요해요")) : L("아직 틀렸어요. 풀이와 원인 분석을 다시 확인해요.")))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(retryResult.verdict == .correct ? Palette.success : Palette.danger)
            }
            if let retries = ladder?.retries, !retries.isEmpty {
                ForEach(Array(retries.suffix(5).enumerated()), id: \.offset) { _, attempt in
                    Text("\(attempt.date.ui("M월 d일")) · \(attempt.given) · \(attempt.correct ? L("정답") : L("오답"))").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func retry() {
        let kind = note.kind ?? note.scan?.kind ?? .shortAnswer
        let result = DoitGrader.grade(.init(kind: kind, student: retryAnswer, answerKey: note.correctAnswer, choices: note.scan?.choices ?? [],
                                            problem: note.scan?.body ?? note.recognizedText))
        withAnimation(.snappy) { retryResult = result }
        guard result.verdict == .correct || result.verdict == .wrong else { return }
        var current = ladder ?? PracticeLadder(level: 3)
        current.retries.append(PracticeAttempt(level: 3, question: "원래 문제", given: retryAnswer, correct: result.verdict == .correct))
        ladder = current
        WeakConceptStore.recordGrade(note: note, correct: result.verdict == .correct, level: 3, source: "재도전", context: context)
        if result.verdict == .correct { note.status = .correct }
        retryAnswer = ""
        save()
    }

    private func save() {
        note.ladder = ladder
        note.updatedAt = Date()
        try? context.save()
    }
}
