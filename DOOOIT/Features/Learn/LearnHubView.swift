import SwiftData
import SwiftUI

/// 공부 탭의 "AI 학습" 영역: 목록 하나로 (단원별 학습 · 취약 유형 · 질문 · 주간 리포트)
struct LearnHubSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("AI")
            VStack(spacing: 0) {
                NavigationLink { CurriculumView() } label: {
                    RowLabel(symbol: "sparkles", title: "AI 학습")
                }
                RowDivider()
                NavigationLink { WeaknessView() } label: {
                    RowLabel(symbol: "scope", color: Palette.danger, title: "취약 유형")
                }
                RowDivider()
                NavigationLink { WeeklyReportView() } label: {
                    RowLabel(symbol: "doc.text.magnifyingglass", color: Palette.warning, title: "주간 리포트")
                }
            }
            .buttonStyle(.pressable)
            .softCardBackground(cornerRadius: 20)
        }
    }
}
