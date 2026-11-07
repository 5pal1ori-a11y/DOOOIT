import SwiftData
import SwiftUI

/// 공부 탭의 "AI 학습" 영역: 목록 하나로 (단원별 학습 · 취약 유형 · 모의고사 · 주간 리포트)
/// 변형 문제는 단원별 학습 안에 들어 있어요 (단원 학습의 한 단계 · 단원 목록의 "변형 연습")
struct LearnHubSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("AI")
            VStack(spacing: 0) {
                NavigationLink { CurriculumView() } label: {
                    RowLabel(symbol: "lightbulb", title: L("AI 학습"))
                }
                RowDivider()
                NavigationLink { WeaknessView() } label: {
                    RowLabel(symbol: "target", color: Palette.pink, title: L("취약 유형"))
                }
                RowDivider()
                NavigationLink { MockExamView() } label: {
                    RowLabel(symbol: "doc.text", color: Palette.sky, title: L("AI 모의고사"))
                }
                RowDivider()
                NavigationLink { WeeklyReportView() } label: {
                    RowLabel(symbol: "newspaper.fill", color: Palette.butter, title: L("주간 리포트"))
                }
            }
            .buttonStyle(.pressableRow)
            .softCardBackground(cornerRadius: 20)
        }
    }
}
