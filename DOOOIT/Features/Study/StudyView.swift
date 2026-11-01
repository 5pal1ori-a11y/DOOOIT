import SwiftData
import SwiftUI

/// 공부 탭: 영어 단어 요약 카드 → 공부 도구 목록 → AI 학습
struct StudyView: View {
    @Query(sort: \Word.createdAt) private var words: [Word]
    @Query(sort: \Memo.updatedAt, order: .reverse) private var memos: [Memo]

    @AppStorage(SettingsKey.dailyWordGoal) private var wordGoal = 20
    @AppStorage(SettingsKey.wordGoalDoneKey) private var wordGoalDoneKey = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    wordsHero
                        .appearAnimation()
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("공부 도구")
                        toolList
                    }
                    .appearAnimation(delay: 0.08)
                    LearnHubSection()
                        .appearAnimation(delay: 0.14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { AppBackground() }
            .navigationTitle("공부")
        }
    }

    /// 영어 단어 요약 카드: 제목 → 오늘 진행 막대 → 세 칸 숫자
    private var wordsHero: some View {
        let unlearned = words.filter { !$0.isLearned }.count
        let done = wordGoalDoneKey == Date().dayKey
        let remaining = done ? 0 : min(wordGoal, unlearned)
        let wrong = words.filter { $0.wrongCount > 0 }.count

        return NavigationLink { WordHomeView() } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("영어 단어").font(.title3.weight(.bold)).foregroundStyle(Palette.ink)
                        Text("단어장을 찍으면 암기 노트가 돼요").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if done {
                        TagLabel(text: "오늘 목표 성공", symbol: "checkmark", color: Palette.success)
                    } else {
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                LinearProgressBar(value: Double(max(0, wordGoal - remaining)) / Double(max(wordGoal, 1)), color: done ? Palette.success : Theme.accent)
                HStack(spacing: 0) {
                    StatColumn(value: "\(remaining)", label: "오늘 외울 단어")
                    StatColumn(value: "\(words.count - unlearned)", label: "외운 단어")
                    StatColumn(value: "\(wrong)", label: "틀린 단어", color: wrong > 0 ? Palette.danger : Palette.ink)
                }
            }
            .softCard(cornerRadius: 24, padding: 20)
        }
        .buttonStyle(.pressable)
    }

    private var toolList: some View {
        VStack(spacing: 0) {
            NavigationLink { MathNoteListView() } label: {
                RowLabel(symbol: "function", color: Palette.success, title: "오답노트", subtitle: "찍으면 채점·원인 분석·유사 문제까지")
            }
            RowDivider()
            NavigationLink { MemoListView() } label: {
                RowLabel(symbol: "note.text", color: Palette.warning, title: "메모장", value: "\(memos.count)")
            }
            RowDivider()
            NavigationLink { StatsView() } label: {
                RowLabel(symbol: "chart.bar.fill", color: Theme.accent, title: "공부 통계", subtitle: "과목별 시간과 변화")
            }
        }
        .buttonStyle(.pressable)
        .softCardBackground(cornerRadius: 20)
    }
}
