import SwiftData
import SwiftUI

/// 공부 탭의 "AI 학습" 영역
struct LearnHubSection: View {
    @Query(sort: \ExamPlan.examDate) private var exams: [ExamPlan]

    var body: some View {
        let next = exams.first { $0.dDay >= 0 }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("AI 학습").font(.title3.weight(.heavy))
                Spacer()
                Text("기기 안 AI로 만들어요").font(.caption).foregroundStyle(.secondary)
            }

            NavigationLink { CramListView() } label: {
                HStack(spacing: 14) {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundStyle(Palette.warning)
                        .frame(width: 52, height: 52)
                        .background(Palette.warning.opacity(0.15), in: .rect(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("시험 직전 벼락치기").font(.headline)
                        Text(next.map { "\($0.name) · D-\($0.dDay)" } ?? "시험 범위를 정하면 단원별로 정리해요")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(
                    LinearGradient(colors: [Palette.warning.opacity(0.16), .clear], startPoint: .leading, endPoint: .trailing),
                    in: .rect(cornerRadius: 22)
                )
                .overlay { RoundedRectangle(cornerRadius: 22).stroke(Palette.warning.opacity(0.3), lineWidth: 1) }
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                NavigationLink { CurriculumView() } label: {
                    row(symbol: "square.stack.3d.up.fill", color: Theme.accent, title: "단원별 AI 학습", subtitle: "개념 → 빈칸 → O/X → 문제")
                }
                Divider().padding(.leading, 62)
                NavigationLink { WeaknessView() } label: {
                    row(symbol: "scope", color: Palette.danger, title: "취약 유형 맞춤", subtitle: "내 오답으로 찾은 약점")
                }
                Divider().padding(.leading, 62)
                NavigationLink { AskAIListView() } label: {
                    row(symbol: "questionmark.bubble.fill", color: Palette.success, title: "AI에게 질문", subtitle: "사진으로 묻고 필기로 정리")
                }
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
        }
    }

    private func row(symbol: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14), in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.bold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}
