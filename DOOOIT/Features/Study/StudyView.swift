import SwiftData
import SwiftUI

/// 공부 탭: 영어 단어 / 수학 오답노트 / 메모장
struct StudyView: View {
    @Query(sort: \Word.createdAt) private var words: [Word]
    @Query(sort: \MathNote.updatedAt, order: .reverse) private var notes: [MathNote]
    @Query(sort: \Memo.updatedAt, order: .reverse) private var memos: [Memo]

    @AppStorage(SettingsKey.dailyWordGoal) private var wordGoal = 20
    @AppStorage(SettingsKey.wordGoalDoneKey) private var wordGoalDoneKey = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    wordsCard

                    HStack(spacing: 14) {
                        mathCard
                        memoCard
                    }

                    if let recent = memos.first {
                        recentMemo(recent)
                    }
                    if let note = notes.first(where: { $0.status != .correct }) {
                        recentNote(note)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { AppBackground() }
            .navigationTitle("공부")
        }
    }

    // MARK: Cards

    private var wordsCard: some View {
        let unlearned = words.filter { !$0.isLearned }.count
        let done = wordGoalDoneKey == Date().dayKey
        let remaining = done ? 0 : min(wordGoal, unlearned)
        let wrong = words.filter { $0.wrongCount > 0 }.count

        return NavigationLink { WordHomeView() } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    IconBadge(symbol: "character.book.closed.fill", size: 46)
                    Spacer()
                    if done {
                        TagLabel(text: "오늘 목표 성공", symbol: "checkmark", color: Palette.success)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("영어 단어")
                        .font(.title2.weight(.bold))
                    Text("단어장을 찍으면 자동으로 암기 노트를 만들어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 0) {
                    stat(value: "\(remaining)", label: "오늘 외울 단어")
                    Divider().frame(height: 34)
                    stat(value: "\(words.count - unlearned)", label: "외운 단어")
                    Divider().frame(height: 34)
                    stat(value: "\(wrong)", label: "틀린 단어")
                }
            }
            .glassCard(padding: 20, interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var mathCard: some View {
        let unsolved = notes.filter { $0.status != .correct }.count
        return NavigationLink { MathNoteListView() } label: {
            VStack(alignment: .leading, spacing: 14) {
                IconBadge(symbol: "function", color: Palette.success, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("수학 오답노트").font(.headline)
                    Text("\(notes.count)문제 · 복습 \(unsolved)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .glassCard(padding: 16, interactive: true)
        }
        .buttonStyle(.plain)
    }

    private var memoCard: some View {
        NavigationLink { MemoListView() } label: {
            VStack(alignment: .leading, spacing: 14) {
                IconBadge(symbol: "note.text", color: Palette.warning, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("메모장").font(.headline)
                    Text("\(memos.count)개의 메모")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .glassCard(padding: 16, interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func recentMemo(_ memo: Memo) -> some View {
        NavigationLink { MemoEditorView(memo: memo) } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("최근 메모").font(.caption).foregroundStyle(.secondary)
                    Text(memo.displayTitle).font(.subheadline.weight(.semibold)).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .glassCard(padding: 16, interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func recentNote(_ note: MathNote) -> some View {
        NavigationLink { MathNoteEditorView(note: note) } label: {
            HStack(spacing: 12) {
                Image(systemName: note.status.symbol)
                    .foregroundStyle(note.status.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("다시 풀어볼 문제").font(.caption).foregroundStyle(.secondary)
                    Text(note.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .glassCard(padding: 16, interactive: true)
        }
        .buttonStyle(.plain)
    }
}
