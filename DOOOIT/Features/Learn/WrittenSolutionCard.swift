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
        VStack(alignment: .leading, spacing: 12) {
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

                Text("모티 풀이 엔진이 직접 푼 단계예요. 문제 글이 정확해야 풀이도 정확해요.")
                    .font(.pt(.caption2))
                    .foregroundStyle(.secondary)
            } else if working {
                HStack(spacing: 12) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("단계별 풀이를 쓰고 있어요").font(.pt(.subheadline)).foregroundStyle(Palette.ink)
                        Text("보통 10~20초 걸려요").font(.pt(.footnote)).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } else if unsolved {
                unsolvedState
            } else {
                emptyState
            }
        }
        .softCard()
        .errorAlert($error)
        .onAppear { myAnswers = note.stepAnswers }
        .onChange(of: myAnswers) { _, value in note.stepAnswers = value }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("단계별 풀이").font(.pt(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                if let solution {
                    Text("\(solution.steps.count)단계 · 최종 답 \(solution.finalAnswer)")
                        .font(.pt(.footnote))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if solution != nil {
                Button { Task { await generate() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.pt(.subheadline).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 32, height: 32)
                        .background(Theme.secondaryFill, in: .rect(cornerRadius: Radius.field, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("다시 만들기")
                .disabled(working)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(note.recognizedText.isEmpty
                 ? L("문제 탭에서 문제가 읽히면 단계별 풀이를 만들 수 있어요.")
                 : L("생각할 점과 식을 단계별로 나눠서 정리해드려요. 먼저 직접 풀어보고 모범 답안과 비교해보세요."))
                .font(.pt(.footnote))
                .foregroundStyle(.secondary)
            Button { Task { await generate() } } label: {
                Text("AI 단계별 풀이 만들기")
            }
            .buttonStyle(.flatProminent)
            .disabled(note.recognizedText.isEmpty)
        }
    }

    /// 못 푸는 문제: 왜 그런지 짧게 + 바로 할 수 있는 것
    private var unsolvedState: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("아직 풀 수 없는 문제예요")
                    .font(.pt(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("틀린 풀이를 지어내지 않으려고 멈췄어요")
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
            }

            // 읽은 문제 글 (대부분 글자가 잘못 읽혀서 못 풀어요)
            VStack(alignment: .leading, spacing: 4) {
                FlowLabel(L("읽은 문제"))
                Text(note.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.pt(.subheadline))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .flatField()

            VStack(alignment: .leading, spacing: 8) {
                tip(L("숫자·기호가 다르게 읽혔다면 고친 뒤 다시 시도해 주세요"))
                tip(L("그림·표가 필요한 문제는 필요한 값을 문제 글에 적어 주세요"))
            }

            HStack(spacing: 8) {
                Button {
                    onEditProblem()
                } label: {
                    Text("문제 글 고치기")
                }
                .buttonStyle(.flat)
                Button {
                    Task { await generate() }
                } label: {
                    Text("다시 시도")
                }
                .buttonStyle(.flatProminent)
            }
        }
    }

    private func tip(_ text: String) -> some View {
        Text(text).font(.pt(.footnote)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    /// 단계 번호 + 세로 연결선
    private func stepMarker(_ index: Int, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Text("\(index + 1)")
                .font(.pt(.footnote).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .frame(width: 24, height: 24)
                .background(Theme.secondaryFill, in: .circle)
            if !isLast {
                Rectangle()
                    .fill(Palette.line)
                    .frame(width: 0.5)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 24)
    }

    private func practice(_ solution: WrittenSolution) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(solution.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    stepMarker(index, isLast: index == solution.steps.count - 1)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(step.hint)
                            .font(.pt(.subheadline).weight(.semibold))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField("이 단계를 직접 풀어보세요", text: answerBinding(index), axis: .vertical)
                            .font(.pt(.body))
                            .lineLimit(2...6)
                            .flatField()
                    }
                    .padding(.bottom, 16)
                }
                .appearAnimation(delay: Double(index) * 0.06)
            }
            Button {
                withAnimation(Motion.spring) { tab = .answer }
            } label: {
                HStack(spacing: 4) {
                    Text("다 풀었어요 · 모범 답안과 비교")
                    Image(systemName: "chevron.right").font(.pt(.caption2).weight(.semibold))
                }
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(Palette.ink)
            }
            .buttonStyle(.pressable)
            .padding(.leading, 36)
        }
    }

    private func concept(_ solution: WrittenSolution) -> some View {
        Text(solution.concept)
            .font(.pt(.body))
            .foregroundStyle(Palette.ink)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func modelAnswer(_ solution: WrittenSolution) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(solution.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    stepMarker(index, isLast: index == solution.steps.count - 1)
                    VStack(alignment: .leading, spacing: 8) {
                        // 이 단계에서 할 일
                        Text(step.hint)
                            .font(.pt(.footnote))
                            .foregroundStyle(.secondary)
                        // 쓰는 개념·공식
                        if !step.concept.isEmpty {
                            Text(MathSymbolBar.pretty(step.concept))
                                .font(.pt(.footnote).weight(.semibold))
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        // 계산·풀이 과정
                        Text(MathSymbolBar.pretty(step.work))
                            .font(.pt(.body).weight(.medium))
                            .foregroundStyle(Palette.ink)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .flatField()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // 왜 이렇게 하는지 · 다음 단계
                        if !step.reason.isEmpty {
                            Text(step.reason)
                                .font(.pt(.footnote))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !step.next.isEmpty {
                            Text(MathSymbolBar.pretty(step.next))
                                .font(.pt(.caption2).weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        if index < myAnswers.count, !myAnswers[index].isEmpty {
                            Text("내 풀이: \(myAnswers[index])")
                                .font(.pt(.footnote))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .appearAnimation(delay: Double(index) * 0.08)
            }

            HStack(alignment: .firstTextBaseline) {
                FlowLabel(L("최종 답"))
                Spacer()
                Text(MathSymbolBar.pretty(solution.finalAnswer))
                    .font(.pt(.title3).weight(.bold))
                    .foregroundStyle(Palette.ink)
            }
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Hairline() }
            .appearAnimation(delay: 0.25)

            if note.correctAnswer.isEmpty {
                Button {
                    note.correctAnswer = solution.finalAnswer
                } label: {
                    Text("이 답을 정답 칸에 넣기")
                        .font(.pt(.footnote).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                }
                .buttonStyle(.pressable)
                .padding(.top, 4)
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
