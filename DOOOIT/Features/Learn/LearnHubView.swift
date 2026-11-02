import SwiftData
import SwiftUI

/// 공부 탭의 "AI 학습" 영역: 목록 하나로 (단원별 학습 · 취약 유형 · 질문 · 주간 리포트)
struct LearnHubSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("AI 학습")
            VStack(spacing: 0) {
                NavigationLink { CurriculumView() } label: {
                    RowLabel(symbol: "sparkles", title: "단원별 AI 학습", subtitle: "초등~대학교 · 개념 → 빈칸 → O/X → 문제")
                }
                RowDivider()
                NavigationLink { WeaknessView() } label: {
                    RowLabel(symbol: "scope", color: Palette.danger, title: "취약 유형 학습", subtitle: "오답으로 찾은 약점")
                }
                RowDivider()
                NavigationLink { AskAIListView() } label: {
                    RowLabel(symbol: "questionmark.bubble.fill", color: Palette.success, title: "AI에게 질문", subtitle: "사진으로 묻고 필기로 정리")
                }
                RowDivider()
                NavigationLink { WeeklyReportView() } label: {
                    RowLabel(symbol: "doc.text.magnifyingglass", color: Palette.warning, title: "주간 AI 리포트", subtitle: "한 주 정리와 다음 주 추천")
                }
            }
            .buttonStyle(.pressable)
            .softCardBackground(cornerRadius: 20)
        }
    }
}
