import SwiftData
import SwiftUI

// AI와 함께 풀기: 답은 숨기고, 묻는 것 → 힌트 1·2·3 → 내 답 확인 → 풀이 순서로 같이 풀어요 (모든 과목)

// MARK: - 들어가는 카드 (풀이 탭)

struct GuidedSolveEntryCard: View {
    @Bindable var note: MathNote
    /// 문제를 아직 확인하지 않았을 때 '문제' 탭으로
    var onNeedConfirm: () -> Void = {}

    @State private var open = false

    private var ready: Bool {
        note.isRecognitionConfirmed && !note.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // 한 줄 버튼: 누르면 같이 풀기 화면 (문제를 아직 확인하지 않았으면 문제 탭으로)
    var body: some View {
        Button {
            Haptics.tap()
            if ready { open = true } else { onNeedConfirm() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.accent.pastel, in: .rect(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("AI와 함께 풀기").font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
                    Text(ready ? (note.guidedSolve?.summary ?? "힌트를 보며 직접 풀어요") : "문제를 먼저 확인해 주세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .softCard()
        .sheet(isPresented: $open) {
            GuidedSolveView(note: note)
        }
    }
}

// MARK: - 같이 풀기 화면

struct GuidedSolveView: View {
    @Bindable var note: MathNote
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var plan: DoitGuidedSolve.Plan?
    @State private var session = GuidedSolveSession()
    @State private var input = ""
    @State private var showProblem = true
    @State private var aiWorking = false
    /// 이번 풀이를 진행 기록에 넣었는지
    @State private var saved = false
    @State private var lastAnswer = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            problemCard
                            ForEach(session.messages) { message in
                                bubble(message)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                            if aiWorking { thinking }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: session.messages.count) {
                        withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: aiWorking) {
                        withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
                composer
            }
            .background { AppBackground() }
            .navigationTitle("AI와 함께 풀기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) { statusPill }
            }
        }
        .onAppear(perform: start)
        .onDisappear(perform: saveProgress)
    }

    // MARK: 문제 (접기)

    private var problemText: String { plan?.problem.text ?? note.recognizedText }

    private var problemCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { showProblem.toggle() }
                Haptics.tap()
            } label: {
                HStack(spacing: 6) {
                    SubjectTag(label: note.subjectLabel)
                    Text(showProblem ? "문제" : problemText.replacingOccurrences(of: "\n", with: " "))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(showProblem ? Palette.ink : .secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: showProblem ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showProblem ? "문제 접기" : "문제 펼치기")

            if showProblem {
                Text(MathSymbolBar.pretty(problemText))
                    .font(.system(size: 16, design: .serif))
                    .lineSpacing(4)
                    .foregroundStyle(Palette.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let choices = plan?.choices, !choices.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(DoitGuidedSolve.circled(index + 1)).font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent)
                                Text(MathSymbolBar.pretty(choice)).font(.subheadline).foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .softCard(cornerRadius: 18, padding: 14)
    }

    // MARK: 말풍선

    @ViewBuilder
    private func bubble(_ message: GuidedSolveSession.Message) -> some View {
        if message.role == .student {
            HStack {
                Spacer(minLength: 48)
                Text(MathSymbolBar.pretty(message.text))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Theme.accent, in: .rect(cornerRadius: 18))
            }
        } else if message.tone == .explain {
            explainCard(message)
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let label = message.label ?? toneLabel(message.tone) {
                        Label(label, systemImage: toneSymbol(message.tone))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(toneColor(message.tone))
                    }
                    Text(MathSymbolBar.pretty(message.text))
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(toneBackground(message.tone), in: .rect(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
                Spacer(minLength: 36)
            }
        }
    }

    private func explainCard(_ message: GuidedSolveSession.Message) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message.label ?? "풀이", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
            if !message.text.isEmpty {
                Text(MathSymbolBar.pretty(message.text))
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(message.lines.enumerated()), id: \.offset) { _, line in
                Text(MathSymbolBar.pretty(line))
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .softCard(cornerRadius: 18, padding: 14)
        .textSelection(.enabled)
    }

    private var thinking: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("AI 힌트 생각 중").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func toneLabel(_ tone: GuidedSolveSession.Message.Tone) -> String? {
        switch tone {
        case .good: return "맞았어요"
        case .retry: return "다시 생각해 봐요"
        default: return nil
        }
    }

    private func toneSymbol(_ tone: GuidedSolveSession.Message.Tone) -> String {
        switch tone {
        case .hint: return "lightbulb.fill"
        case .ai: return "sparkles"
        case .good: return "checkmark.circle.fill"
        case .retry: return "arrow.uturn.backward.circle.fill"
        case .concept: return "book.fill"
        case .plain, .explain: return "bubble.left.fill"
        }
    }

    private func toneColor(_ tone: GuidedSolveSession.Message.Tone) -> Color {
        switch tone {
        case .good: return Palette.success
        case .retry: return Palette.warning
        case .ai, .hint, .concept, .plain, .explain: return Theme.accent
        }
    }

    private func toneBackground(_ tone: GuidedSolveSession.Message.Tone) -> Color {
        switch tone {
        case .good: return Palette.success.opacity(0.12)
        case .retry: return Palette.warning.opacity(0.14)
        case .hint, .ai: return Theme.accent.opacity(0.09)
        case .concept: return Palette.cardInset
        case .plain, .explain: return Palette.card
        }
    }

    // MARK: 상태 표시

    private var statusPill: some View {
        let text: String
        switch session.phase {
        case .solved: text = "풀었어요"
        case .revealed: text = "답 봄"
        case .solving: text = "힌트 \(session.hintsUsed)"
        }
        let color = session.phase == .solved ? Palette.success : (session.phase == .revealed ? Palette.warning : Theme.accent)
        return Text(text)
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: .capsule)
    }

    // MARK: 입력

    @ViewBuilder
    private var composer: some View {
        VStack(spacing: 10) {
            if session.isFinished {
                HStack(spacing: 10) {
                    Button {
                        restart()
                    } label: {
                        Label("다시 풀기", systemImage: "arrow.counterclockwise")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.glass)
                    Button("닫기") { dismiss() }
                        .buttonStyle(.primaryFill)
                }
            } else if let plan {
                if plan.isChoice {
                    choiceRow(plan)
                } else if plan.isOX {
                    oxRow
                }
                chips
                inputRow(plan)
                if focused && plan.isMath {
                    MathSymbolBar { symbol in input = MathSymbolBar.tidy(input + symbol.insert, after: symbol) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func choiceRow(_ plan: DoitGuidedSolve.Plan) -> some View {
        HStack(spacing: 8) {
            ForEach(1...min(plan.choices.count, 9), id: \.self) { n in
                Button { send(.submit("\(n)")) } label: {
                    Text(DoitGuidedSolve.circled(n))
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .foregroundStyle(Palette.ink)
                        .background(Palette.card, in: .rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(n)번 고르기")
            }
        }
        .disabled(aiWorking)
    }

    private var oxRow: some View {
        HStack(spacing: 8) {
            ForEach(["O", "X"], id: \.self) { mark in
                Button { send(.submit(mark)) } label: {
                    Text(mark)
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .foregroundStyle(Palette.ink)
                        .background(Palette.card, in: .rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .disabled(aiWorking)
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip("힌트 더", "lightbulb") { send(.hint) }
                chip("이 단계 맞아?", "checkmark.circle") {
                    let text = input
                    input = ""
                    send(.check(text))
                }
                chip("개념 설명", "book") { send(.concept) }
                chip("답 보기", "eye") { send(.reveal) }
            }
        }
        .scrollIndicators(.hidden)
        .disabled(aiWorking)
    }

    private func chip(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Palette.card, in: .capsule)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func inputRow(_ plan: DoitGuidedSolve.Plan) -> some View {
        HStack(spacing: 8) {
            TextField(plan.isMath ? "식이나 답, 질문을 적어요" : "답이나 질문을 적어요", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.send)
                .onSubmit(submitInput)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
            Button(action: submitInput) {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(canSend ? Theme.accent : Color.secondary.opacity(0.4), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("보내기")
        }
    }

    private var canSend: Bool { !aiWorking && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: 동작

    private func start() {
        guard plan == nil else { return }
        let problem = DoitGuidedSolve.problem(recognizedText: note.recognizedText, scan: note.scan, kind: note.kind,
                                              subjectStored: note.subject, correctAnswer: note.correctAnswer, unit: note.unit)
        let made = DoitGuidedSolve.plan(problem)
        plan = made
        session = GuidedSolveSession(plan: made)
        saved = false
    }

    private func restart() {
        saveProgress()
        guard let plan else { return }
        Haptics.tap()
        withAnimation(.snappy) {
            session = GuidedSolveSession(plan: plan)
            input = ""
            saved = false
        }
    }

    private func submitInput() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !aiWorking else { return }
        input = ""
        send(.say(text))
    }

    private func send(_ action: GuidedSolveSession.Action) {
        guard let plan, !aiWorking else { return }
        switch action {
        case .submit(let t), .check(let t), .say(let t): if !t.isEmpty { lastAnswer = t }
        default: break
        }
        let before = session.messages.count
        let ai = DoitMind.isAvailable
        let request = withAnimation(.snappy) { session.apply(action, plan: plan, aiAvailable: ai) }
        haptic(newSince: before)
        if session.isFinished { finish() }
        if let request { Task { await runAI(request, plan: plan) } }
    }

    private func runAI(_ request: GuidedSolveSession.AIRequest, plan: DoitGuidedSolve.Plan) async {
        withAnimation(.snappy) { aiWorking = true }
        let raw = try? await DoitBrain.shared.complete(system: DoitGuidedSolve.coachSystem, prompt: request.prompt, maxTokens: 160, temperature: 0.4)
        withAnimation(.snappy) {
            aiWorking = false
            session.receiveAI(raw, request: request, plan: plan)
        }
        Haptics.tap()
    }

    private func haptic(newSince index: Int) {
        let new = session.messages.dropFirst(index)
        if new.contains(where: { $0.tone == .good }) { Haptics.success() }
        else if new.contains(where: { $0.tone == .retry }) { Haptics.error() }
        else { Haptics.tap() }
    }

    /// 풀었거나 답을 봤을 때: 취약 개념 · (수학이 아닌 과목은) 간격 복습 기록 · 진행 기록
    private func finish() {
        guard !session.recorded, let outcome = DoitGuidedSolve.outcome(session) else { return }
        session.recorded = true
        WeakConceptStore.recordGrade(note: note, correct: outcome.correct, level: outcome.level, source: "AI와 함께 풀기", context: context)
        if let retry = outcome.retry {
            if !note.subjectKind.isMath {
                var ladder = note.ladder ?? PracticeLadder(level: 3)
                ladder.retries.append(PracticeAttempt(level: 3, question: "AI와 함께 풀기", given: lastAnswer, correct: retry))
                note.ladder = ladder
            }
            if retry { note.status = .correct }
        }
        saveProgress()
    }

    private func saveProgress() {
        guard !saved, session.hasActivity else { return }
        saved = true
        note.guidedSolve = (note.guidedSolve ?? GuidedSolveProgress()).adding(session)
        note.updatedAt = Date()
        try? context.save()
    }
}
