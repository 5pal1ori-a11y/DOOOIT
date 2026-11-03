import SwiftData
import SwiftUI

/// 공부 탭: 큰 타일 2×2(영어 단어 · 오답노트 · 메모장 · 공부 랭킹) → AI 학습 목록 → 공부 통계
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
                            tile(symbol: "character.book.closed.fill", color: Theme.accent, title: "영어 단어", detail: wordDetail)
                        }
                        NavigationLink { MathNoteListView() } label: {
                            tile(symbol: "pencil.and.list.clipboard", color: Palette.success, title: "오답노트", detail: noteDetail)
                        }
                        NavigationLink { MemoListView() } label: {
                            tile(symbol: "note.text", color: Palette.warning, title: "메모장", detail: memos.isEmpty ? "메모 쓰기" : "\(memos.count)개")
                        }
                        NavigationLink { RankingView() } label: {
                            tile(symbol: "trophy.fill", color: Color(hex: "#FF7A45"), title: "공부 랭킹", detail: "오늘 순위 보기")
                        }
                    }
                    .buttonStyle(.pressable)
                    .appearAnimation()

                    LearnHubSection()
                        .appearAnimation(delay: 0.08)

                    NavigationLink { StatsView() } label: {
                        RowLabel(symbol: "chart.bar.fill", color: Theme.accent, title: "공부 통계", subtitle: "과목별 시간과 변화")
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
            #endif
        }
    }

    private var wordDetail: String {
        if words.isEmpty { return "단어장 찍어서 시작" }
        if wordGoalDoneKey == Date().dayKey { return "오늘 목표 완료 ✓" }
        let left = min(wordGoal, words.filter { !$0.isLearned }.count)
        return "오늘 \(left)개 외울 차례"
    }

    private var noteDetail: String {
        let unsolved = mathNotes.filter { $0.status != .correct }.count
        if mathNotes.isEmpty { return "틀린 문제 찍기" }
        return unsolved > 0 ? "복습할 문제 \(unsolved)개" : "모두 복습 완료 ✓"
    }

    /// 큰 정사각 타일: 위 아이콘 · 아래 제목과 한 줄 설명
    private func tile(symbol: String, color: Color, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 46, height: 46)
                .background(color.opacity(0.12), in: .rect(cornerRadius: 14))
            Spacer(minLength: 16)
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .softCard(cornerRadius: 22, padding: 16)
    }
}
