import SwiftData
import SwiftUI

/// 오답노트의 서술형 단계별 풀이 (문제 / 개념 / 답안)
struct WrittenSolutionCard: View {
    @Bindable var note: MathNote
    @Environment(\.modelContext) private var context

    enum Tab: String, CaseIterable, Identifiable {
        case problem = "문제", concept = "개념", answer = "답안"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .problem
    @State private var working = false
    @State private var error: String?
    @State private var myAnswers: [String] = []

    private var solution: WrittenSolution? {
        note.solutionData.flatMap { try? JSONDecoder().decode(WrittenSolution.self, from: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "서술형 단계별 풀이", symbol: "list.number") {
                if solution != nil {
                    Button { Task { await generate() } } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("다시 만들기")
                        .disabled(working)
                }
            }

            if let solution {
                Picker("보기", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .problem:
                    Text(note.recognizedText.isEmpty ? "문제 텍스트가 없어요." : note.recognizedText)
                        .font(.subheadline)
                    ForEach(Array(solution.steps.enumerated()), id: \.offset) { index, _ in
                        VStack(alignment: .leading, spacing: 6) {
                            Label("\(index + 1)단계 풀이", systemImage: "info.circle")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            TextField("직접 풀어보세요", text: answerBinding(index), axis: .vertical)
                                .lineLimit(2...5)
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 14))
                    }
                    Button("다 풀었어요 · 모범 답안과 비교") { withAnimation { tab = .answer } }
                        .font(.subheadline.weight(.semibold))
                case .concept:
                    Text(solution.concept).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                case .answer:
                    ForEach(Array(solution.steps.enumerated()), id: \.offset) { index, step in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text("\(index + 1)단계 풀이")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Theme.accent, in: .rect(cornerRadius: 6))
                                Label(step.hint, systemImage: "lightbulb.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .labelStyle(.titleAndIcon)
                            }
                            Text(step.work).font(.body).fixedSize(horizontal: false, vertical: true)
                            if index < myAnswers.count, !myAnswers[index].isEmpty {
                                Text("내 풀이: \(myAnswers[index])").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 16))
                    }
                    HStack {
                        Text("최종 답:").font(.headline)
                        Spacer()
                        Text(solution.finalAnswer).font(.headline)
                    }
                    .padding(14)
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.15)) }
                    if note.correctAnswer.isEmpty {
                        Button("이 답을 정답 칸에 넣기") { note.correctAnswer = solution.finalAnswer }
                            .font(.subheadline.weight(.semibold))
                    }
                }
                Text("AI 풀이는 틀릴 수 있어요. 정답과 꼭 비교해보세요.").font(.caption2).foregroundStyle(.secondary)
            } else if working {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("AI 선생님이 단계별 풀이를 쓰고 있어요").font(.subheadline)
                }
            } else {
                Text(note.recognizedText.isEmpty
                     ? "문제 사진을 찍어 텍스트가 인식되면 단계별 풀이를 만들 수 있어요."
                     : "1단계, 2단계로 나눠 생각할 점과 식을 정리해드려요. 먼저 직접 풀어보고 비교해보세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button { Task { await generate() } } label: {
                    Label("AI 단계별 풀이 만들기", systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(note.recognizedText.isEmpty)
            }
        }
        .glassCard()
        .errorAlert($error)
        .onAppear { myAnswers = note.stepAnswers }
        .onChange(of: myAnswers) { _, value in note.stepAnswers = value }
    }

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
            let result = try await AITutor.generate(WrittenSolution.self, prompt: AITutor.solutionPrompt(problem: note.recognizedText))
            note.solutionData = try? JSONEncoder().encode(result)
            try? context.save()
            tab = .problem
        } catch {
            self.error = error.localizedDescription
        }
    }
}
