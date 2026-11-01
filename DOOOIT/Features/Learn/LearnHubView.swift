import SwiftData
import SwiftUI

/// 공부 탭의 "AI 학습" 영역
struct LearnHubSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 학습").font(.title3.weight(.heavy)).foregroundStyle(Palette.ink)

            VStack(spacing: 0) {
                NavigationLink { CurriculumView() } label: {
                    row(symbol: "square.stack.3d.up.fill", color: Theme.accent, title: "AI 학습", subtitle: "과목과 단원만 적으면 AI가 자료를 만들어요")
                }
                Divider().padding(.leading, 68)
                NavigationLink { WeaknessView() } label: {
                    row(symbol: "scope", color: Palette.danger, title: "취약 유형 학습", subtitle: "내 오답으로 찾은 약점")
                }
                Divider().padding(.leading, 68)
                NavigationLink { AskAIListView() } label: {
                    row(symbol: "questionmark.bubble.fill", color: Palette.success, title: "AI에게 질문하기", subtitle: "사진으로 묻고 필기로 정리해요.")
                }
            }
            .buttonStyle(.plain)
            .softCardBackground(cornerRadius: 22)
        }
    }

    private func row(symbol: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            IconBadge(symbol: symbol, color: color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
