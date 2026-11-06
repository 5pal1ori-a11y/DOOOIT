import SwiftData
import SwiftUI

/// 오답노트의 서술형 단계별 풀이 (직접 풀기 / 개념 / 모범 답안)
struct WrittenSolutionCard: View {
    @Bindable var note: MathNote
    /// 못 푸는 문제일 때 '문제 글 고치기' (문제 탭으로)
    var onEditProblem: () -> Void = {}
    @Environment(\.modelContext) private var context

    enum Tab: String, CaseIterable, Identifiable {
        case problem = "직접 풀기", concept = "개념", answer = "모범 답안"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .problem
    @State private var working = false
    @State private var error: String?
    /// 풀이 엔진이 풀지 못한 문제 (알림창 대신 카드 안에서 안내)
    @State private var unsolved = false
    @State private var myAnswers: [String] = []

    private var solution: WrittenSolution? {
        note.solutionData.flatMap { try? JSONDecoder().decode(WrittenSolution.self, from: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let solution {
                PillSegmentedControl(items: Tab.allCases, selection: $tab) { $0.rawValue.loc }

                Group {
                    switch tab {
                    case .problem: practice(solution)
                    case .concept: concept(solution)
                    case .answer: modelAnswer(solution)
                    }
                }
                .id(tab)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                Label("모티 풀이 엔진이 직접 푼 단계예요. 문제 글이 정확해야 풀이도 정확해요.", systemImage: "exclamationmark.circle")
                    .font(.pt(.caption2))
                    .foregroundStyle(.secondary)
            } else if working {
                HStack(spacing: 12) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("단계별 풀이를 쓰고 있어요").font(.pt(.subheadline).weight(.semibold))
                        Text("보통 10~20초 걸려요").font(.pt(.caption)).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } else if unsolved {
                unsolvedState
            } else {
                emptyState
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .errorAlert($error)
        .onAppear { myAnswers = note.stepAnswers }
        .onChange(of: myAnswers) { _, value in note.stepAnswers = value }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.number")
                .font(.pt(.headline))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accent.pastel, in: .rect(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("단계별 풀이").font(.pt(.headline))
                if let solution {
                    Text("\(solution.steps.count)단계 · 최종 답 \(solution.finalAnswer)")
                        .font(.pt(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if solution != nil {
                Button { Task { await generate() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.pt(.subheadline).weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(Color.primary.opacity(0.06), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("다시 만들기")
                .disabled(working)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(note.recognizedText.isEmpty
                 ? L("문제 탭에서 문제가 읽히면 단계별 풀이를 만들 수 있어요.")
                 : L("생각할 점과 식을 단계별로 나눠서 정리해드려요. 먼저 직접 풀어보고 모범 답안과 비교해보세요."))
                .font(.pt(.subheadline))
                .foregroundStyle(.secondary)
            Button { Task { await generate() } } label: {
                Label("AI 단계별 풀이 만들기", systemImage: "lightbulb")
                    .font(.pt(.body).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.glassProminent)
            .disabled(note.recognizedText.isEmpty)
        }
    }

    /// 못 푸는 문제: 왜 그런지 짧게 + 바로 할 수 있는 것
    private var unsolvedState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .font(.pt(.title3).weight(.semibold))
                    .foregroundStyle(Palette.warning)
                    .frame(width: 42, height: 42)
                    .background(Palette.warning.opacity(0.14), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("아직 풀 수 없는 문제예요")
                        .font(.pt(.headline))
                        .foregroundStyle(Palette.ink)
                    Text("틀린 풀이를 지어내지 않으려고 멈췄어요")
                        .font(.pt(.caption))
                        .foregroundStyle(.secondary)
                }
            }

            // 읽은 문제 글 (대부분 글자가 잘못 읽혀서 못 풀어요)
            VStack(alignment: .leading, spacing: 6) {
                Text("읽은 문제")
                    .font(.pt(.caption).weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(note.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.pt(.subheadline))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Palette.cardInset, in: .rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 8) {
                tip("textformat", L("숫자·기호가 다르게 읽혔다면 고친 뒤 다시 시도해 주세요"))
                tip("chart.bar.fill", L("그림·표가 필요한 문제는 필요한 값을 문제 글에 적어 주세요"))
            }

            HStack(spacing: 10) {
                Button {
                    onEditProblem()
                } label: {
                    Label("문제 글 고치기", systemImage: "pencil")
                        .font(.pt(.subheadline).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.glass)
                Button {
                    Task { await generate() }
                } label: {
                    Label("다시 시도", systemImage: "arrow.clockwise")
                        .font(.pt(.subheadline).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.pt(.footnote)).foregroundStyle(.secondary)
        } icon: {
            Image(systemName: symbol).font(.pt(.footnote)).foregroundStyle(Theme.accent)
        }
    }

    /// 단계 번호 + 세로 연결선
    private func stepMarker(_ index: Int, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Text("\(index + 1)")
                .font(.pt(.subheadline).weight(.bold))
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
                            .font(.pt(.subheadline).weight(.semibold))
                            .foregroundStyle(Palette.warning)
                            .labelStyle(.titleAndIcon)
                        TextField("이 단계를 직접 풀어보세요", text: answerBinding(index), axis: .vertical)
                            .font(.pt(.body))
                            .lineLimit(2...6)
                            .padding(12)
                            .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 14))
                    }
                    .padding(.bottom, 18)
                }
                .appearAnimation(delay: Double(index) * 0.06)
            }
            Button {
                withAnimation(Motion.spring) { tab = .answer }
            } label: {
                Label("다 풀었어요 · 모범 답안과 비교", systemImage: "arrow.right.circle.fill")
                    .font(.pt(.subheadline).weight(.bold))
            }
            .padding(.leading, 40)
        }
    }

    private func concept(_ solution: WrittenSolution) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.pt(.title3))
                .foregroundStyle(Theme.accent)
            Text(solution.concept)
                .font(.pt(.body))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 14))
    }

    private func modelAnswer(_ solution: WrittenSolution) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(solution.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    stepMarker(index, isLast: index == solution.steps.count - 1)
                    VStack(alignment: .leading, spacing: 8) {
                        // 이 단계에서 할 일
                        Text(step.hint)
                            .font(.pt(.caption).weight(.semibold))
                            .foregroundStyle(.secondary)
                        // 쓰는 개념·공식
                        if !step.concept.isEmpty {
                            Label(MathSymbolBar.pretty(step.concept), systemImage: "function")
                                .font(.pt(.caption))
                                .foregroundStyle(Theme.accent)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        // 계산·풀이 과정
                        Text(MathSymbolBar.pretty(step.work))
                            .font(.pt(.body).weight(.medium))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 14))
                        // 왜 이렇게 하는지 · 다음 단계
                        if !step.reason.isEmpty {
                            Label(step.reason, systemImage: "questionmark.circle")
                                .font(.pt(.caption))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !step.next.isEmpty {
                            Text(MathSymbolBar.pretty(step.next))
                                .font(.pt(.caption2).weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        if index < myAnswers.count, !myAnswers[index].isEmpty {
                            Label("내 풀이: \(myAnswers[index])", systemImage: "person.fill")
                                .font(.pt(.caption))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 18)
                }
                .appearAnimation(delay: Double(index) * 0.08)
            }

            HStack {
                Label("최종 답", systemImage: "checkmark.seal.fill")
                    .font(.pt(.subheadline).weight(.bold))
                Spacer()
                Text(MathSymbolBar.pretty(solution.finalAnswer))
                    .font(.pt(.title3).weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(AccentGradient.linear, in: .capsule)
            .appearAnimation(delay: 0.25)

            if note.correctAnswer.isEmpty {
                Button {
                    note.correctAnswer = solution.finalAnswer
                } label: {
                    Label("이 답을 정답 칸에 넣기", systemImage: "arrow.down.circle")
                        .font(.pt(.caption).weight(.semibold))
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
        working = true
        defer { working = false }
        do {
            let result = try await DoitTutor.solution(for: note.recognizedText)
            note.solutionData = try? JSONEncoder().encode(result)
            try? context.save()
            unsolved = false
            tab = .problem
        } catch DoitTutor.TutorError.cannotSolve(_) {
            Haptics.error()
            withAnimation(.snappy) { unsolved = true }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
