import SwiftData
import SwiftUI

/// 공부 탭: 타일 2×2(영어 단어 · 오답노트 · 메모장 · 공부 랭킹) → AI 목록 → 공부 통계
struct StudyView: View {
    @Query(sort: \Word.createdAt) private var words: [Word]
    @Query(sort: \Memo.updatedAt, order: .reverse) private var memos: [Memo]
    @Query private var mathNotes: [MathNote]

    @AppStorage(SettingsKey.dailyWordGoal) private var wordGoal = 20
    @AppStorage(SettingsKey.wordGoalDoneKey) private var wordGoalDoneKey = ""

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        NavigationLink { WordHomeView() } label: {
                            tile(symbol: "book.closed.fill", color: Theme.accent, title: "영어 단어", detail: wordDetail)
                        }
                        NavigationLink { MathNoteListView() } label: {
                            tile(symbol: "pencil", color: Palette.mint, title: "오답노트", detail: noteDetail)
                        }
                        NavigationLink { MemoListView() } label: {
                            tile(symbol: "doc.text.fill", color: Palette.butter, title: "메모장", detail: memos.isEmpty ? "새 메모" : "\(memos.count)개")
                        }
                        NavigationLink { RankingView() } label: {
                            tile(symbol: "trophy.fill", color: Palette.peach, title: "공부 랭킹", detail: "오늘 순위")
                        }
                    }
                    .buttonStyle(.pressable)
                    .appearAnimation()

                    LearnHubSection()
                        .appearAnimation(delay: 0.08)

                    NavigationLink { StatsView() } label: {
                        RowLabel(symbol: "chart.bar.fill", color: Theme.accent, title: "공부 통계")
                            .softCardBackground(cornerRadius: 20)
                    }
                    .buttonStyle(.pressable)
                    .appearAnimation(delay: 0.14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { AppBackground() }
            .navigationTitle("학습")
            #if DEBUG
            .uiShotPush(.words) { WordHomeView() }
            .uiShotPush(.mathList, .mathNote) { MathNoteListView() }
            .uiShotPush(.mockExam, .mockResult) { MockExamView() }
            .uiShotPush(.grammar) { UnitStudyView(subject: "중학교 영어", unit: "현재완료") }
            .uiShotPush(.grammarOX) { UnitStudyView(subject: "중학교 영어", unit: "현재완료", initialStep: .ox) }
            .uiShotPush(.grammarProblem) { UnitStudyView(subject: "중학교 영어", unit: "현재완료", initialStep: .problem) }
            #endif
        }
    }

    private var wordDetail: String {
        if words.isEmpty { return "단어 추가" }
        if wordGoalDoneKey == Date().dayKey { return "오늘 완료" }
        let left = min(wordGoal, words.filter { !$0.isLearned }.count)
        return left == 0 ? "모두 외움" : "오늘 \(left)개"
    }

    private var noteDetail: String {
        let unsolved = mathNotes.filter { $0.status != .correct }.count
        if mathNotes.isEmpty { return "문제 찍기" }
        return unsolved > 0 ? "복습 \(unsolved)개" : "복습 완료"
    }

    /// 큰 정사각 타일: 위 아이콘 · 아래 제목과 한 줄 설명
    private func tile(symbol: String, color: Color, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: symbol.outlineSymbol)
                .environment(\.symbolVariants, .none)
                .font(.title3.weight(.regular))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.pastel, in: .rect(cornerRadius: 15, style: .continuous))
            Spacer(minLength: 14)
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .softCard(cornerRadius: 24, padding: 18)
    }
}
