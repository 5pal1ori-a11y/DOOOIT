import SwiftUI
import WatchKit

/// 단어 카드: 오늘 복습할 단어. 눌러서 뜻 보기 → 알아요 / 몰라요 (아이폰 복습 일정에 반영)
struct WordsScreen: View {
    @Environment(WatchStore.self) private var store
    @State private var flipped = false
    @State private var doneCount = 0

    private var words: [WatchWordItem] { store.snapshot.words }
    private var accent: Color { store.snapshot.accent }

    var body: some View {
        Group {
            if let word = words.first {
                card(word)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.largeTitle)
                        .foregroundStyle(accent)
                    Text(doneCount > 0 ? "복습 끝!" : "복습할 단어가 없어요")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(doneCount > 0 ? .primary : .secondary)
                }
            }
        }
        .navigationTitle("단어 카드")
    }

    private func card(_ word: WatchWordItem) -> some View {
        VStack(spacing: 6) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { flipped.toggle() }
                WKInterfaceDevice.current().play(.click)
            } label: {
                VStack(spacing: 4) {
                    if flipped {
                        Text(word.term)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(word.meaning)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .lineLimit(3)
                    } else {
                        Text(word.term)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)
                        Text("눌러서 뜻 보기")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .background(accent.opacity(flipped ? 0.32 : 0.2), in: .rect(cornerRadius: 18))
                .overlay(alignment: .bottomTrailing) {
                    Text("\(words.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
            .buttonStyle(.plain)
            .id(word.id)
            .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))

            HStack(spacing: 6) {
                Button("몰라요") { grade(word, known: false) }
                    .tint(.gray)
                Button("알아요") { grade(word, known: true) }
                    .tint(accent)
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.borderedProminent)
        }
    }

    private func grade(_ word: WatchWordItem, known: Bool) {
        WKInterfaceDevice.current().play(known ? .success : .retry)
        withAnimation(.snappy(duration: 0.25)) {
            flipped = false
            doneCount += 1
            store.send(.gradeWord(wordID: word.id, known: known))
        }
    }
}
