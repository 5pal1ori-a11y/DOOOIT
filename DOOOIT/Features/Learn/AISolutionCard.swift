import SwiftData
import SwiftUI

/// 오답노트 풀이 탭 맨 위: AI가 문제를 읽고 직접 풀어 정답과 풀이를 보여 줌
/// 수학은 풀이 엔진이 계산해서 풀고, 다른 과목은 규칙·자료로 확인해서 풀어요.
/// 그래도 못 풀면 다른 과목은 두잇 1·2 모델이 참고 자료를 보고 풀어요 (추측이라 확인 표시)
struct AISolutionCard: View {
    @Bindable var note: MathNote
    /// 못 풀었을 때 '문제 글 고치기' (문제 탭으로)
    var onEditProblem: () -> Void = {}
    @Environment(\.modelContext) private var context

    @State private var working = false
    @State private var failed = false

    private var problemText: String { note.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var choices: [String] { note.scan?.choices ?? [] }
    private var isChoice: Bool {
        let kind = note.kind ?? note.scan?.kind
        return (kind == .multipleChoice || kind == nil) && choices.count >= 2
    }
    private var solution: WrittenSolution? {
        note.solutionData.flatMap { try? JSONDecoder().decode(WrittenSolution.self, from: $0) }
    }
    private var current: WrittenSolution? {
        guard DoitAutoSolve.isCurrent(solution, problem: problemText) else { return nil }
        // 예전에 모델이 추측한 수학 답은 버리고 계산으로 다시 풂
        if note.subjectKind.isMath, solution?.source == DoitAutoSolve.modelSource { return nil }
        return solution
    }
    private var noteKey: String { note.correctAnswer.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let current {
                result(current)
            } else if working {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("AI가 문제를 풀고 있어요").font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 6)
            } else if failed {
                failedState
            } else if problemText.isEmpty {
                Text("문제 탭에서 문제 글이 읽히면 AI가 풀어 줘요").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .task(id: problemText) { await solveIfNeeded() }
    }

    // MARK: 화면

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Theme.accent, in: .rect(cornerRadius: 10))
            Text("AI 풀이").font(.headline)
            Spacer()
            if current != nil, !working {
                Button { Task { await solve(force: true) } } label: {
                    Image(systemName: "arrow.clockwise").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("다시 풀기")
            }
        }
    }

    @ViewBuilder
    private func result(_ solution: WrittenSolution) -> some View {
        let fromModel = solution.source == DoitAutoSolve.modelSource
        let agrees = noteKey.isEmpty || DoitGuidedSolve.agrees(solution.finalAnswer, noteKey, choices: choices, choice: isChoice)

        VStack(alignment: .leading, spacing: 6) {
            Text("정답").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text(MathSymbolBar.pretty(DoitSubjectNote.describe(solution.finalAnswer, choices: choices)))
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.accent.opacity(0.1), in: .rect(cornerRadius: 16))

        if isChoice, !matchesChoice(solution.finalAnswer) {
            Label("선지에서 같은 답을 못 찾았어요. 문제 글이 맞게 읽혔는지 확인해 보세요.", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.warning)
                .fixedSize(horizontal: false, vertical: true)
        } else if !agrees {
            Label("적어 둔 정답과 달라요. 문제 글이 맞게 읽혔는지 확인해 보세요.", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.warning)
                .fixedSize(horizontal: false, vertical: true)
        }

        if !solution.concept.isEmpty {
            Label(MathSymbolBar.pretty(solution.concept), systemImage: "lightbulb")
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)
        }

        if !solution.steps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(solution.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Theme.accent, in: .circle)
                        VStack(alignment: .leading, spacing: 4) {
                            if !step.hint.isEmpty {
                                Text(step.hint).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                            if !step.work.isEmpty {
                                Text(MathSymbolBar.pretty(step.work))
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .lineSpacing(4)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }

        if fromModel {
            HStack {
                Label("AI가 추측한 답이에요. 꼭 확인해 보세요.", systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if noteKey.isEmpty {
                    Button("정답으로 쓰기") {
                        note.correctAnswer = solution.finalAnswer
                        save()
                        Haptics.tap()
                    }
                    .font(.caption.weight(.bold))
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private var failedState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.subjectKind.isMath ? "AI가 이 문제를 확실하게 풀지 못했어요. 틀린 답을 보여 주지 않으려고 계산으로 확인한 답만 보여 줘요. 문제 글이 맞게 읽혔는지 확인하거나 'AI와 함께 풀기'로 풀어 봐요."
                 : DoitMind.isAvailable ? "AI가 이 문제를 풀지 못했어요" : "AI가 이 문제를 풀지 못했어요. 두잇 AI 탭에서 모델을 받으면 더 많은 문제를 풀어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button { onEditProblem() } label: {
                    Label("문제 글 고치기", systemImage: "pencil").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)
                Button { Task { await solve(force: true) } } label: {
                    Label("다시 풀기", systemImage: "arrow.clockwise").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)
            }
        }
    }

    // MARK: 풀기

    private func solveIfNeeded() async {
        guard !problemText.isEmpty else { return }
        // 예전에 모델이 추측한 답은 규칙·자료로 확인한 답이 생기면 바꿈
        if let current, current.source == DoitAutoSolve.modelSource {
            if let verified = subjectSolved(problemText) { store(verified) }
            return
        }
        guard current == nil else { return }
        await solve(force: false)
    }

    /// 규칙·자료로 확인한 답 (과학 계산, 영어 문법, 분류·사실·연표, 맞춤법)
    private func subjectSolved(_ text: String) -> WrittenSolution? {
        DoitSubjectSolve.solve(text: text, choices: isChoice ? choices : [], subjectBroad: note.subjectKind.rawValue,
                               body: note.scan?.body, boxItems: note.scan?.boxItems)
    }

    private func solve(force: Bool) async {
        let text = problemText
        guard !text.isEmpty, !working else { return }
        working = true
        failed = false
        defer { working = false }

        // 1) 수학: 풀이 엔진 (계산으로 확인한 답)
        if note.subjectKind.isMath, let solved = DoitAutoSolve.engine(text: text, choices: choices, isChoice: isChoice, body: note.scan?.body) {
            store(solved)
            // 정답을 아직 안 적었으면 엔진 답을 정답으로 (채점·다시 풀기에 씀, 객관식은 선지와 맞을 때만)
            if noteKey.isEmpty, !isChoice || matchesChoice(solved.finalAnswer) { note.correctAnswer = solved.finalAnswer; save() }
            return
        }
        // 2) 규칙·자료로 확인한 답 (다른 과목, 수학 노트에 들어온 과학 계산도)
        if let solved = subjectSolved(text) {
            store(solved)
            if noteKey.isEmpty, !isChoice || matchesChoice(solved.finalAnswer) { note.correctAnswer = solved.finalAnswer; save() }
            return
        }
        // 3) 두잇 1·2 모델 (수학이 아닌 과목만: 작은 모델의 수학 답은 자주 틀려서 계산으로 확인한 답만 보여 줌)
        if !note.subjectKind.isMath, DoitMind.isAvailable {
            let body = note.scan.map { $0.body.isEmpty ? text : $0.body } ?? text
            let material = DoitAutoSolve.modelMaterial(text: text, body: note.scan?.body, choices: isChoice ? choices : [],
                                                       boxItems: note.scan?.boxItems, subject: note.subjectKind)
            let prompt = DoitAutoSolve.modelPrompt(problem: body, choices: isChoice ? choices : [],
                                                   subjectName: note.subjectLabel, problemType: note.scan?.problemType,
                                                   reference: material.reference, hints: material.hints)
            // 생각 모드는 쓰지 않음 (생각만 길게 하다 답을 못 쓰는 일이 있어서) → 풀이를 쓰고 마지막 줄에 정답
            for attempt in 0..<2 {
                if attempt > 0 { try? await Task.sleep(for: .seconds(2)) }   // 대화 답을 쓰는 중이면 잠깐 기다렸다 다시
                guard let raw = try? await DoitBrain.shared.complete(system: DoitMind.persona, prompt: prompt, maxTokens: 600, temperature: 0.2) else { continue }
                if let solved = DoitAutoSolve.parseModel(DoitMind.answer(raw), problem: text, choices: isChoice ? choices : []) {
                    guard problemText == text else { return }
                    store(solved)
                    return
                }
            }
        }
        guard problemText == text else { return }
        withAnimation(.snappy) { failed = true }
    }

    private func matchesChoice(_ answer: String) -> Bool {
        guard let n = DoitGrader.choiceNumber(answer, choices: choices) else { return false }
        return (1...choices.count).contains(n)
    }

    private func store(_ solution: WrittenSolution) {
        withAnimation(.snappy) { note.solutionData = try? JSONEncoder().encode(solution) }
        save()
    }

    private func save() {
        note.updatedAt = Date()
        try? context.save()
    }
}
