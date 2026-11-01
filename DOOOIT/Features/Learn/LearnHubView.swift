import SwiftData
import SwiftUI

/// 공부 탭의 "AI 학습" 영역
struct LearnHubSection: View {
    @State private var sparkle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("AI 학습")

            // 단원별 AI 학습 (가장 많이 쓰는 기능은 위에 큰 줄로)
            NavigationLink { CurriculumView() } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AccentGradient.linear, in: .rect(cornerRadius: 13))
                            .symbolEffect(.bounce, value: sparkle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("단원별 AI 학습").font(.title3.weight(.bold)).foregroundStyle(Palette.ink)
                            Text("단원만 고르면 개념 → 빈칸 → O/X → 문제").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 6) {
                        ForEach(["초등", "중학교", "고등학교", "대학교"], id: \.self) { level in
                            Text(level)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.accent.opacity(0.1), in: .capsule)
                        }
                    }
                }
                .softCard(cornerRadius: 24, padding: 20)
            }
            .buttonStyle(.pressable)
            .appearAnimation()

            HStack(spacing: 12) {
                NavigationLink { WeaknessView() } label: {
                    tile(symbol: "scope", color: Palette.danger, title: "취약 유형 학습", subtitle: "오답으로 찾은 약점")
                }
                .buttonStyle(.pressable)
                .appearAnimation(delay: 0.06)

                NavigationLink { AskAIListView() } label: {
                    tile(symbol: "questionmark.bubble.fill", color: Palette.success, title: "AI에게 질문", subtitle: "사진으로 묻고 필기로 정리")
                }
                .buttonStyle(.pressable)
                .appearAnimation(delay: 0.12)
            }

            WeeklyReportLink()
                .appearAnimation(delay: 0.18)
        }
        .onAppear { sparkle.toggle() }
    }

    private func tile(symbol: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            IconBadge(symbol: symbol, color: color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .softCard(cornerRadius: 22, padding: 16)
    }
}
