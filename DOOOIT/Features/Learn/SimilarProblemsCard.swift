import SwiftData
import SwiftUI

/// 오답과 같은 유형의 새 문제 3개를 두잇 AI가 만들어주고, 직접 풀어서 채점
struct SimilarProblemsCard: View {
    @Bindable var note: MathNote
    @Environment(\.modelContext) private var context

    @State private var problemSet: SimilarProblemSet?
    @State private var answers: [String] = ["", "", ""]
    @State private var results: [Bool?] = [nil, nil, nil]
    @State private var openExplanation: Set<Int> = []
    @State private var working = false
    @State private var error: String?

    private var cacheKey: String { ContentCache.key("오답노트", note.id.uuidString, "similar") }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let problemSet, !problemSet.problems.isEmpty {
                ForEach(Array(problemSet.problems.prefix(3).enumerated()), id: \.offset) { index, problem in
                    problemView(index: index, problem: problem)
                }
                Label("AI가 만든 문제라 틀릴 수 있어요. 해설과 함께 확인하세요.", systemImage: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if working {
                HStack(spacing: 12) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("비슷한 문제를 만들고 있어요").font(.subheadline.weight(.semibold))
                        Text("보통 10~20초 걸려요").font(.caption).foregroundStyle(.secondary)
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
        .onAppear {
            if problemSet == nil { problemSet = ContentCache.load(SimilarProblemSet.self, key: cacheKey, context: context) }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.on.square")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Palette.warning, in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text("비슷한 문제 풀기").font(.headline)
                if problemSet != nil {
                    let solved = results.compactMap { $0 }.filter { $0 }.count
                    Text("3문제 중 \(solved)문제 맞힘")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if problemSet != nil {
                Button { Task { await generate() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(Color.primary.opacity(0.06), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("새로 만들기")
                .disabled(working)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(note.recognizedText.isEmpty
                 ? "문제 탭에 문제가 있어야 비슷한 문제를 만들 수 있어요."
                 : "같은 개념으로 숫자와 조건만 바꾼 문제 3개를 만들어드려요. 풀면서 진짜 이해했는지 확인해보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button { Task { await generate() } } label: {
                Label("비슷한 문제 3개 만들기", systemImage: "sparkles")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.glassProminent)
            .disabled(note.recognizedText.isEmpty)
        }
    }

    private func problemView(index: Int, problem: SimilarProblem) -> some View {
        let result = results[index]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(index + 1)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Palette.warning, in: .circle)
                Text(MathSymbolBar.pretty(problem.question))
                    .font(.system(size: 16, design: .serif))
                    .lineSpacing(5)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                TextField("내 답", text: $answers[index])
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
                Button {
                    check(index, problem: problem)
                } label: {
                    Text("채점").font(.subheadline.weight(.bold)).padding(.horizontal, 6)
                }
                .buttonStyle(.glassProminent)
                .disabled(answers[index].trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let result {
                Label(result ? "정답이에요!" : "아쉬워요. 정답은 \(problem.answer)",
                      systemImage: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(result ? Palette.success : Palette.danger)
                    .symbolEffect(.bounce, value: result)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Button {
                withAnimation(.snappy) {
                    if openExplanation.contains(index) { openExplanation.remove(index) } else { openExplanation.insert(index) }
                }
            } label: {
                Label(openExplanation.contains(index) ? "해설 닫기" : "해설 보기",
                      systemImage: openExplanation.contains(index) ? "chevron.up" : "lightbulb")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)

            if openExplanation.contains(index) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("정답 \(problem.answer)").font(.subheadline.weight(.bold))
                    Text(MathSymbolBar.pretty(problem.explanation)).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 12))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(14)
        .background(Color.white, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        .feedbackGlow(result, cornerRadius: 18)
        .shake(trigger: result == false)
        .appearAnimation(delay: Double(index) * 0.06)
    }

    // MARK: Actions

    private func check(_ index: Int, problem: SimilarProblem) {
        let ok = MathGrader.grade(myAnswer: answers[index], correctAnswer: problem.answer) ?? false
        withAnimation(Motion.spring) { results[index] = ok }
        if ok { Haptics.success() } else { Haptics.error() }
    }

    private func generate() async {
        working = true
        defer { working = false }
        do {
            let made = try await DoitTutor.similar(to: note.recognizedText)
            guard !made.problems.isEmpty else {
                error = "문제를 만들지 못했어요. 다시 시도해주세요."
                return
            }
            ContentCache.save(made, key: cacheKey, context: context)
            withAnimation(.snappy) {
                problemSet = made
                answers = ["", "", ""]
                results = [nil, nil, nil]
                openExplanation = []
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
