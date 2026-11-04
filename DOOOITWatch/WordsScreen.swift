import SwiftUI
import WatchKit

/// 단어: 카드(눌러서 뜻 → 알아요/몰라요) · 4지선다 퀴즈. 복습 차례 단어는 아이폰 복습 일정에 반영,
/// 복습할 단어가 없으면 퀴즈로 연습만
struct WordsScreen: View {
    @Environment(WatchStore.self) private var store
    @AppStorage("watch.wordQuiz") private var quizMode = false
    @State private var flipped = WatchDemo.screen == "wordsBack"
    @State private var doneCount = 0
    /// 퀴즈: 고른 보기 (잠깐 정답을 보여 주고 넘어감)
    @State private var picked: String?
    @State private var practiced: Set<String> = []
    @State private var score = 0
    @State private var asked = 0

    private var words: [WatchWordItem] { store.snapshot.words }
    private var accent: Color { store.snapshot.accent }

    /// 퀴즈 차례: 복습 단어(보기가 있는 것) 먼저, 없으면 연습 단어
    private var quizDeck: [WatchWordItem] {
        let due = words.filter { $0.choices?.count == 4 }
        if !due.isEmpty { return due }
        return store.snapshot.practice.filter { $0.choices?.count == 4 && !practiced.contains($0.id) }
    }

    var body: some View {
        Group {
            if quizMode {
                if let word = quizDeck.first, let choices = word.choices {
                    quiz(word, choices: choices)
                } else {
                    finished(quiz: true)
                }
            } else if let word = words.first {
                card(word)
            } else {
                finished(quiz: false)
            }
        }
        .navigationTitle(quizMode ? "퀴즈" : "단어 카드")
        .onAppear { if WatchDemo.screen == "quiz" { quizMode = true } else if WatchDemo.screen?.hasPrefix("words") == true { quizMode = false } }
    }

    /// 카드 ↔ 퀴즈 (툴바 단추는 세로 페이지 안에서 워치가 멈춰서 화면 안에 둠)
    private var modeButton: some View {
        Button {
            withAnimation(.snappy) {
                quizMode.toggle()
                picked = nil
                flipped = false
            }
            WatchHaptics.play(.click)
        } label: {
            Image(systemName: quizMode ? "rectangle.on.rectangle" : "square.grid.2x2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.18), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(quizMode ? "카드로" : "퀴즈로")
    }

    // MARK: 끝 · 빈 화면

    private func finished(quiz: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(accent)
            if quiz && asked > 0 {
                Text("\(score)/\(asked) 맞힘")
                    .font(.headline)
            } else {
                Text(doneCount > 0 ? "복습 끝!" : "복습할 단어가 없어요")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(doneCount > 0 ? .primary : .secondary)
            }
            Text("오늘 \(store.snapshot.wordsToday)개")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if !quiz, !store.snapshot.practice.isEmpty {
                Button("퀴즈로 연습") {
                    withAnimation(.snappy) { quizMode = true }
                }
                .font(.footnote.weight(.semibold))
                .tint(accent)
                .buttonStyle(.bordered)
            } else if quiz, asked > 0, !store.snapshot.practice.isEmpty, words.isEmpty {
                Button("다시") {
                    practiced = []
                    score = 0
                    asked = 0
                }
                .font(.footnote.weight(.semibold))
                .tint(accent)
                .buttonStyle(.bordered)
            } else if quiz, !words.isEmpty {
                modeButton
            }
        }
    }

    // MARK: 카드

    private func card(_ word: WatchWordItem) -> some View {
        VStack(spacing: 6) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { flipped.toggle() }
                WatchHaptics.play(.click)
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
            .overlay(alignment: .topTrailing) {
                if !store.snapshot.practice.isEmpty || words.contains(where: { $0.choices?.count == 4 }) {
                    modeButton.padding(4)
                }
            }
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
        WatchHaptics.play(known ? .success : .retry)
        withAnimation(.snappy(duration: 0.25)) {
            flipped = false
            doneCount += 1
            store.send(.gradeWord(wordID: word.id, known: known))
        }
    }

    // MARK: 4지선다

    private func quiz(_ word: WatchWordItem, choices: [String]) -> some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(word.term)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(quizDeck.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                modeButton
            }
            .padding(.horizontal, 4)
            .id(word.id)

            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    choice(choices[0], word: word)
                    choice(choices[1], word: word)
                }
                GridRow {
                    choice(choices[2], word: word)
                    choice(choices[3], word: word)
                }
            }
        }
    }

    private func choice(_ text: String, word: WatchWordItem) -> some View {
        let answered = picked != nil
        let isAnswer = text == word.meaning
        let color: Color = !answered ? accent.opacity(0.22)
            : (isAnswer ? .green.opacity(0.6) : (picked == text ? .red.opacity(0.6) : .gray.opacity(0.15)))
        return Button {
            pick(text, word: word)
        } label: {
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(4)
                .background(color, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(answered)
        .accessibilityLabel(text)
    }

    private func pick(_ text: String, word: WatchWordItem) {
        guard picked == nil else { return }
        let correct = text == word.meaning
        picked = text
        asked += 1
        if correct { score += 1 }
        WatchHaptics.play(correct ? .success : .failure)
        let isDue = words.contains { $0.id == word.id }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(correct ? 600 : 1_200))
            withAnimation(.snappy(duration: 0.25)) {
                picked = nil
                if isDue {
                    // 복습 차례 단어: 처음 고른 답으로 복습 일정 반영
                    doneCount += 1
                    store.send(.gradeWord(wordID: word.id, known: correct))
                } else {
                    practiced.insert(word.id)
                }
            }
        }
    }
}
