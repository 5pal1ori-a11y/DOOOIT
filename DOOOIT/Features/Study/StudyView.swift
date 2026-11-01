import SwiftData
import SwiftUI

/// 공부 탭: 큰 그라데이션 영역(영어 단어) → 목록형(오답노트·메모·통계) → 최근 항목
struct StudyView: View {
    @Query(sort: \Word.createdAt) private var words: [Word]
    @Query(sort: \Memo.updatedAt, order: .reverse) private var memos: [Memo]

    @AppStorage(SettingsKey.dailyWordGoal) private var wordGoal = 20
    @AppStorage(SettingsKey.wordGoalDoneKey) private var wordGoalDoneKey = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    wordsHero
                    toolList
                    LearnHubSection()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { AppBackground() }
            .navigationTitle("공부")
        }
    }

    private var wordsHero: some View {
        let unlearned = words.filter { !$0.isLearned }.count
        let done = wordGoalDoneKey == Date().dayKey
        let remaining = done ? 0 : min(wordGoal, unlearned)
        let wrong = words.filter { $0.wrongCount > 0 }.count

        return NavigationLink { WordHomeView() } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: "character.book.closed.fill")
                        .font(.title3)
                        .frame(width: 46, height: 46)
                        .background(.white.opacity(0.18), in: .circle)
                    Spacer()
                    if done {
                        Label("오늘 목표 성공", systemImage: "checkmark")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.2), in: .capsule)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("영어 단어").font(.title.weight(.heavy))
                    Text("단어장을 촬영하면 자동으로 암기노트를 만들어요.")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                HStack(spacing: 0) {
                    heroStat("\(remaining)", "오늘 외울 단어")
                    heroStat("\(words.count - unlearned)", "외운 단어")
                    heroStat("\(wrong)", "틀린 단어")
                }
                .padding(.top, 14)
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.22)).frame(height: 1) }
            }
            .foregroundStyle(.white)
            .padding(22)
            .background {
                ZStack {
                    LinearGradient(colors: [Color(hex: "#5148E8"), Color(hex: "#2F2A9C")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    RadialGradient(colors: [Color(hex: "#9B6CF5"), .clear], center: .topTrailing, startRadius: 0, endRadius: 240)
                }
            }
            .clipShape(.rect(cornerRadius: 30))
            .shadow(color: Color(hex: "#4F46E5").opacity(0.35), radius: 20, y: 12)
        }
        .buttonStyle(.plain)
    }

    private func heroStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title2.weight(.black)).monospacedDigit()
            Text(label).font(.caption2).opacity(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var toolList: some View {
        return VStack(spacing: 0) {
            NavigationLink { MathNoteListView() } label: {
                listRow(symbol: "function", color: Palette.success, title: "오답노트", subtitle: "AI의 피드백을 받아 오답을 정리하세요.")
            }
            Divider().padding(.leading, 68)
            NavigationLink { MemoListView() } label: {
                listRow(symbol: "note.text", color: Palette.warning, title: "메모장", subtitle: "\(memos.count)개의 메모")
            }
            Divider().padding(.leading, 68)
            NavigationLink { StatsView() } label: {
                listRow(symbol: "chart.pie.fill", color: Theme.accent, title: "공부 통계", subtitle: "과목별 시간과 변화")
            }
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func listRow(symbol: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            IconBadge(symbol: symbol, color: color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
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
