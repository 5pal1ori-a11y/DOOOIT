import SwiftData
import SwiftUI

/// 공부 탭의 "AI 학습" 영역: 목록 하나로 (단원별 학습 · 취약 유형 · 질문 · 주간 리포트)
struct LearnHubSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("AI 활용하기")
            VStack(spacing: 0) {
                NavigationLink { CurriculumView() } label: {
                    RowLabel(symbol: "sparkles", title: "AI 학습", subtitle: "개념과 문제를 한 번에!")
                }
                RowDivider()
                NavigationLink { WeaknessView() } label: {
                    RowLabel(symbol: "scope", color: Palette.danger, title: "취약 유형 학습", subtitle: "오답으로 찾은 약점을 분석해요")
                }
                RowDivider()
                NavigationLink { WeeklyReportView() } label: {
                    RowLabel(symbol: "doc.text.magnifyingglass", color: Palette.warning, title: "주간 리포트", subtitle: "AI가 한 주를 정리해 드려요")
                }
            }
            .buttonStyle(.pressable)
            .softCardBackground(cornerRadius: 20)
        }
    }
}
