import SwiftData
import SwiftUI

/// 공부 탭의 "AI 학습" 영역
struct LearnHubSection: View {
    @State private var sparkle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 학습").font(.title3.weight(.heavy)).foregroundStyle(Palette.ink)

            // 큰 카드: 단원별 AI 학습
            NavigationLink { CurriculumView() } label: {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("AI 학습", systemImage: "sparkles")
                            .font(.caption.weight(.heavy))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.22), in: .capsule)
                        Text("단원만 고르면\n학습 자료가 뚝딱")
                            .font(.title3.weight(.heavy))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("개념 → 빈칸 → O/X → 문제 순서로 공부해요")
                            .font(.caption)
                            .opacity(0.85)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .symbolEffect(.bounce, value: sparkle)
                        .opacity(0.9)
                }
                .foregroundStyle(.white)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AccentGradient.linear, in: .rect(cornerRadius: 24))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .offset(x: 40, y: -50)
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 24))
                .shadow(color: Theme.accent.opacity(0.3), radius: 14, y: 8)
            }
            .buttonStyle(.pressable)
            .appearAnimation()

            HStack(spacing: 12) {
                NavigationLink { WeaknessView() } label: {
                    tile(symbol: "scope", color: Palette.danger, title: "취약 유형 학습", subtitle: "내 오답으로 찾은 약점")
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
