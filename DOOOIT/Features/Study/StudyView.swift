import SwiftData
import SwiftUI

/// 공부 탭: 큰 그라데이션 영역(영어 단어) → 목록형(오답노트·메모·통계) → 최근 항목
struct StudyView: View {
    @Query(sort: \Word.createdAt) private var words: [Word]
    @Query(sort: \MathNote.updatedAt, order: .reverse) private var notes: [MathNote]
    @Query(sort: \Memo.updatedAt, order: .reverse) private var memos: [Memo]

    @AppStorage(SettingsKey.dailyWordGoal) private var wordGoal = 20
    @AppStorage(SettingsKey.wordGoalDoneKey) private var wordGoalDoneKey = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    wordsHero
                    toolList
                    recentSection
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
                    Text("단어장을 찍으면 자동으로 암기 노트를 만들어요")
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
        let unsolved = notes.filter { $0.status != .correct }.count
        return VStack(spacing: 0) {
            NavigationLink { MathNoteListView() } label: {
                listRow(symbol: "function", color: Palette.success, title: "수학 오답노트", subtitle: "\(notes.count)문제 · 다시 풀 문제 \(unsolved)")
            }
            Divider().padding(.leading, 68)
            NavigationLink { MemoListView() } label: {
                listRow(symbol: "note.text", color: Palette.warning, title: "메모장", subtitle: "\(memos.count)개의 메모")
            }
            Divider().padding(.leading, 68)
            NavigationLink { StatsView() } label: {
                listRow(symbol: "chart.pie.fill", color: .accentColor, title: "공부 통계", subtitle: "과목별 시간과 변화 추이")
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

    @ViewBuilder
    private var recentSection: some View {
        let memo = memos.first
        let note = notes.first(where: { $0.status != .correct })
        if memo != nil || note != nil {
            VStack(alignment: .leading, spacing: 4) {
                Text("최근").font(.title3.weight(.heavy))
                if let memo {
                    NavigationLink { MemoEditorView(memo: memo) } label: {
                        plainRow(symbol: "clock.arrow.circlepath", color: .secondary, caption: "최근 메모", title: memo.displayTitle)
                    }
                }
                if let note {
                    NavigationLink { MathNoteEditorView(note: note) } label: {
                        plainRow(symbol: note.status.symbol, color: note.status.color, caption: "다시 풀어볼 문제", title: note.title)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func plainRow(symbol: String, color: Color, caption: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(caption).font(.caption).foregroundStyle(.secondary)
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Divider() }
        .contentShape(Rectangle())
    }
}
