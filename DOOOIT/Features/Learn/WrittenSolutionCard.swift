import SwiftData
import SwiftUI

/// 오답노트의 서술형 단계별 풀이 (직접 풀기 / 개념 / 모범 답안)
struct WrittenSolutionCard: View {
    @Bindable var note: MathNote
    @Environment(\.modelContext) private var context
    @Environment(CreditStore.self) private var credits

    enum Tab: String, CaseIterable, Identifiable {
        case problem = "직접 풀기", concept = "개념", answer = "모범 답안"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .problem
    @State private var working = false
    @State private var error: String?
    @State private var myAnswers: [String] = []
    @State private var confirmCredits = false

    private var solution: WrittenSolution? {
        note.solutionData.flatMap { try? JSONDecoder().decode(WrittenSolution.self, from: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let solution {
                Picker("보기", selection: $tab.animation(.snappy)) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .problem: practice(solution)
                case .concept: concept(solution)
                case .answer: modelAnswer(solution)
                }

                Label("AI 풀이는 틀릴 수 있어요. 정답과 꼭 비교해보세요.", systemImage: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if working {
                HStack(spacing: 12) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("단계별 풀이를 쓰고 있어요").font(.subheadline.weight(.semibold))
                        Text("기기 안 AI라 10~30초 걸릴 수 있어요").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } else {
                emptyState
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .errorAlert($error)
        .alert("크레딧이 사용돼요", isPresented: $confirmCredits) {
            Button("진행 (\(CreditStore.costPerUse) 크레딧)") { Task { await generate() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text(credits.confirmText("AI 단계별 풀이를 만들면"))
        }
        .onAppear { myAnswers = note.stepAnswers }
        .onChange(of: myAnswers) { _, value in note.stepAnswers = value }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.number")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Theme.accent, in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text("서술형 단계별 풀이").font(.headline)
                if let solution {
                    Text("\(solution.steps.count)단계 · 최종 답 \(solution.finalAnswer)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if solution != nil {
                Button { confirmCredits = true } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(Color.primary.opacity(0.06), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("다시 만들기 (\(CreditStore.costPerUse) 크레딧)")
                .disabled(working || !credits.canAfford())
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(note.recognizedText.isEmpty
                 ? "문제 탭에서 문제가 읽히면 단계별 풀이를 만들 수 있어요."
                 : "생각할 점과 식을 단계별로 나눠서 정리해드려요. 먼저 직접 풀어보고 모범 답안과 비교해보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button { confirmCredits = true } label: {
                Label("AI 단계별 풀이 만들기", systemImage: "sparkles")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.glassProminent)
            .disabled(note.recognizedText.isEmpty || !credits.canAfford())

            if credits.canAfford() {
                Label("\(CreditStore.costPerUse) 크레딧 사용 · 지금 \(credits.balance) 크레딧", systemImage: "bolt.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                NotEnoughCreditsView()
            }
        }
    }

    /// 단계 번호 + 세로 연결선
    private func stepMarker(_ index: Int, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Text("\(index + 1)")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Theme.accent, in: .circle)
            if !isLast {
                Rectangle()
                    .fill(Theme.accent.opacity(0.25))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 28)
    }

    private func practice(_ solution: WrittenSolution) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(solution.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    stepMarker(index, isLast: index == solution.steps.count - 1)
                    VStack(alignment: .leading, spacing: 8) {
                        Label(step.hint, systemImage: "lightbulb.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.warning)
                            .labelStyle(.titleAndIcon)
                        TextField("이 단계를 직접 풀어보세요", text: answerBinding(index), axis: .vertical)
                            .font(.system(.body, design: .rounded))
                            .lineLimit(2...6)
                            .padding(12)
                            .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 14))
                    }
                    .padding(.bottom, 18)
                }
            }
            Button {
                withAnimation(.snappy) { tab = .answer }
            } label: {
                Label("다 풀었어요 · 모범 답안과 비교", systemImage: "arrow.right.circle.fill")
                    .font(.subheadline.weight(.bold))
            }
            .padding(.leading, 40)
        }
    }

    private func concept(_ solution: WrittenSolution) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.title3)
                .foregroundStyle(Theme.accent)
            Text(solution.concept)
                .font(.body)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 18))
    }

    private func modelAnswer(_ solution: WrittenSolution) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(solution.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    stepMarker(index, isLast: index == solution.steps.count - 1)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(step.hint)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(MathSymbolBar.pretty(step.work))
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 14))
                        if index < myAnswers.count, !myAnswers[index].isEmpty {
                            Label("내 풀이: \(myAnswers[index])", systemImage: "person.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 18)
                }
            }

            HStack {
                Label("최종 답", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(MathSymbolBar.pretty(solution.finalAnswer))
                    .font(.title3.weight(.heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Theme.accent, in: .capsule)

            if note.correctAnswer.isEmpty {
                Button {
                    note.correctAnswer = solution.finalAnswer
                } label: {
                    Label("이 답을 정답 칸에 넣기", systemImage: "arrow.down.doc")
                        .font(.caption.weight(.semibold))
                }
                .padding(.top, 10)
            }
        }
    }

    // MARK: Logic

    private func answerBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { index < myAnswers.count ? myAnswers[index] : "" },
            set: { value in
                while myAnswers.count <= index { myAnswers.append("") }
                myAnswers[index] = value
            }
        )
    }

    private func generate() async {
        guard credits.canAfford() else {
            error = "크레딧이 부족해요. 공부 탭의 크레딧에서 광고를 보고 받을 수 있어요."
            return
        }
        working = true
        defer { working = false }
        do {
            let result = try await AITutor.generate(WrittenSolution.self, prompt: AITutor.solutionPrompt(problem: note.recognizedText))
            note.solutionData = try? JSONEncoder().encode(result)
            try? context.save()
            credits.charge(.solution)
            tab = .problem
        } catch {
            self.error = error.localizedDescription
        }
    }
}
