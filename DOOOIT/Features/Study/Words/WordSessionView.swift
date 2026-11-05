import SwiftData
import SwiftUI

/// 단어 학습 세션: 큰 영어 단어 + 뜻 카드 두 장 중 고르기.
/// 맞히면 잠깐 뒤 다음 단어로, 틀리면 정답을 보여 주고 그 단어는 끝에 다시 물어봄 (모두 맞힐 때까지).
/// 다른 뜻이 없어 보기를 못 만들면 카드 뒤집기(알아요/몰라요)로 대신함.
struct WordSessionView: View {
    /// spaced: 복습 일정이 된 단어 (처음에 맞혔는지로 다음 복습 날을 정함)
    enum Kind { case daily, extra, review, spaced }

    let words: [Word]
    let kind: Kind
    /// 보기(오답 뜻)를 고를 단어들. 같은 단어장 단어를 먼저 씀
    var pool: [Word] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SettingsKey.wordGoalDoneKey) private var wordGoalDoneKey = ""

    @State private var queue: [Word] = []
    @State private var index = 0
    @State private var choices: [String] = []
    @State private var picked: Int?
    /// 카드 뒤집기 모드: 뜻을 보여 줬는지
    @State private var revealed = false
    @State private var finished = false
    /// 처음 물었을 때 틀린 단어 (복습 일정 · 다시 볼 단어)
    @State private var firstTryWrong: Set<UUID> = []
    @State private var seen: Set<UUID> = []
    /// 결과 화면에서 "다시 하기"를 누른 뒤에는 연습만 (일정·목표는 다시 바꾸지 않음)
    @State private var practice = false
    @State private var roundWords: [Word] = []
    @State private var advanceTask: Task<Void, Never>?
    @State private var showExitConfirm = false

    private var current: Word? { queue.indices.contains(index) ? queue[index] : nil }
    private var answered: Bool { picked != nil }
    private var isFlashcard: Bool { choices.count < 2 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if finished {
                resultView
            } else if let word = current {
                question(word)
                    .id("\(index)-\(word.id)")
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.card.ignoresSafeArea())
        .onAppear {
            guard queue.isEmpty, !finished else { return }
            start(with: words)
        }
        .onDisappear { advanceTask?.cancel() }
        .confirmationDialog("그만할까요?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("그만하기", role: .destructive) { dismiss() }
            Button("계속하기", role: .cancel) {}
        }
    }

    // MARK: 위

    private var topBar: some View {
        ZStack {
            if !finished && !queue.isEmpty {
                Text("\(min(index + 1, queue.count))/\(queue.count)")
                    .font(.pt(.subheadline).weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            HStack {
                Button {
                    if finished || seen.isEmpty { dismiss() } else { showExitConfirm = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.pt(.body).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("닫기")
                Spacer()
            }
        }
        .padding(.top, 8)
    }

    // MARK: 문제

    private func question(_ word: Word) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Text(word.term)
                .font(.pt(size: 52, weight: .bold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)

            if isFlashcard, revealed {
                Text(word.meaning)
                    .font(.pt(.title3).weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .transition(.opacity)
            }

            Spacer(minLength: 32)

            if isFlashcard {
                flashcardControls(word)
            } else {
                choiceCards(word)
            }

            pills(word)
                .padding(.top, 28)

            nextButton
                .frame(height: 76)
        }
    }

    private func choiceCards(_ word: Word) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(Array(choices.enumerated()), id: \.offset) { offset, choice in
                VStack(spacing: 10) {
                    choiceCard(number: offset + 1, text: choice, state: state(of: offset, word: word)) {
                        pick(offset, word: word)
                    }
                    Text(caption(for: offset, word: word))
                        .font(.pt(.footnote).weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(height: 18)
                        .opacity(caption(for: offset, word: word).isEmpty ? 0 : 1)
                }
            }
        }
        .padding(.top, 14)
    }

    fileprivate enum CardState { case idle, correct, wrong, dimmed }

    private func state(of offset: Int, word: Word) -> CardState {
        guard let picked else { return .idle }
        if choices[offset] == word.meaning { return .correct }
        return offset == picked ? .wrong : .dimmed
    }

    private func caption(for offset: Int, word: Word) -> String {
        guard let picked, choices[offset] == word.meaning else { return "" }
        return choices[picked] == word.meaning ? "정답입니다!" : "정답"
    }

    private func choiceCard(number: Int, text: String, state: CardState, action: @escaping () -> Void) -> some View {
        let tint: Color? = switch state {
        case .correct: Theme.accent
        case .wrong: Palette.danger
        case .idle, .dimmed: nil
        }
        return Button(action: action) {
            Text(text)
                .font(.pt(.headline))
                .foregroundStyle(tint ?? Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 132)
                .background((tint ?? .clear).opacity(0.08), in: .rect(cornerRadius: 22))
                .background(Palette.cardInset, in: .rect(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(tint ?? .clear, lineWidth: 2)
                }
                .overlay(alignment: .top) {
                    Text("\(number)")
                        .font(.pt(.footnote).weight(.bold).monospacedDigit())
                        .foregroundStyle(tint == nil ? Palette.ink : .white)
                        .frame(width: 28, height: 28)
                        .background(tint ?? Palette.card, in: .circle)
                        .overlay { Circle().strokeBorder(tint ?? Color.primary.opacity(0.12), lineWidth: 1) }
                        .offset(y: -14)
                }
                .opacity(state == .dimmed ? 0.5 : 1)
                .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.pressable)
        .disabled(answered)
        .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: [])
        .accessibilityLabel("\(number)번, \(text)")
    }

    @ViewBuilder
    private func flashcardControls(_ word: Word) -> some View {
        if !revealed {
            Button {
                withAnimation(reduceMotion ? nil : .snappy) { revealed = true }
                Haptics.tap()
            } label: {
                Label("뜻 보기", systemImage: "eye")
            }
            .buttonStyle(.primaryFill)
        } else if !answered {
            HStack(spacing: 12) {
                Button { grade(false, word: word, choice: 1) } label: {
                    Text("몰라요")
                        .font(.pt(.body).weight(.bold))
                        .foregroundStyle(Palette.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Palette.danger.opacity(0.1), in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.pressable)
                Button { grade(true, word: word, choice: 0) } label: {
                    Text("알아요")
                }
                .buttonStyle(.primaryFill)
            }
        } else {
            Color.clear.frame(height: 52)
        }
    }

    private func pills(_ word: Word) -> some View {
        HStack(spacing: 10) {
            pill(title: "듣기", symbol: "speaker.wave.2.fill", active: false) {
                WordSpeaker.shared.speak(word.term)
            }
            pill(title: "저장", symbol: word.isStarred ? "bookmark.fill" : "bookmark", active: word.isStarred) {
                word.isStarred.toggle()
                try? context.save()
                Haptics.tap()
            }
        }
    }

    private func pill(title: String, symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(active ? Theme.accent : Palette.ink.opacity(0.75))
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(active ? Theme.accent.opacity(0.1) : Palette.cardInset, in: .capsule)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.pressable)
    }

    /// 틀렸을 때만: 눌러야 다음으로
    @ViewBuilder
    private var nextButton: some View {
        if answered, let word = current, lastWasWrong(word) {
            Button { advance() } label: {
                Label("다음", systemImage: "arrow.right")
            }
            .buttonStyle(.primaryFill)
            .keyboardShortcut(.return, modifiers: [])
            .padding(.top, 16)
            .transition(.opacity)
        } else {
            Color.clear
        }
    }

    private func lastWasWrong(_ word: Word) -> Bool {
        guard let picked else { return false }
        if isFlashcard { return picked != 0 }
        return choices.indices.contains(picked) && choices[picked] != word.meaning
    }

    // MARK: 진행

    private func start(with list: [Word]) {
        advanceTask?.cancel()
        roundWords = list
        firstTryWrong = []
        seen = []
        queue = list.shuffled()
        index = 0
        finished = false
        prepare()
    }

    private func prepare() {
        picked = nil
        revealed = false
        guard let word = current else { choices = []; return }
        choices = WordChoices.make(for: word, pool: pool.isEmpty ? words : pool)
    }

    private func pick(_ offset: Int, word: Word) {
        guard !answered, choices.indices.contains(offset) else { return }
        grade(choices[offset] == word.meaning, word: word, choice: offset)
    }

    private func grade(_ ok: Bool, word: Word, choice: Int) {
        guard !answered else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { picked = choice }
        let firstTime = seen.insert(word.id).inserted
        if ok {
            word.correctCount += 1
            Haptics.success()
            advanceTask?.cancel()
            advanceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                advance()
            }
        } else {
            word.wrongCount += 1
            if firstTime { firstTryWrong.insert(word.id) }
            // 이 단어는 끝에 다시 물어봄
            queue.append(word)
            Haptics.error()
        }
    }

    private func advance() {
        advanceTask?.cancel()
        advanceTask = nil
        guard answered else { return }
        if index + 1 < queue.count {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                index += 1
                prepare()
            }
        } else {
            complete()
        }
    }

    private func complete() {
        if !practice {
            let now = Date()
            for word in words {
                if kind == .spaced {
                    // 처음에 맞혔으면 다음 간격, 틀렸으면 내일부터 다시
                    let schedule = WordReview.afterReview(stage: word.reviewStage, correct: !firstTryWrong.contains(word.id), now: now)
                    word.reviewStage = schedule.stage
                    word.nextReviewAt = schedule.next
                    continue
                }
                if word.learnedAt == nil { word.learnedAt = now }
                // 처음 외운 단어는 내일 첫 복습
                if word.reviewStage == 0 {
                    let schedule = WordReview.afterLearning(now: now)
                    word.reviewStage = schedule.stage
                    word.nextReviewAt = schedule.next
                }
                if kind == .review { word.wrongCount = 0 }
            }
            if kind == .daily { wordGoalDoneKey = now.dayKey }
        }
        try? context.save()
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { finished = true }
    }

    // MARK: 결과

    private var missed: [Word] { roundWords.filter { firstTryWrong.contains($0.id) } }

    private var resultView: some View {
        let total = roundWords.count
        let right = total - missed.count
        return VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("\(right)/\(total)")
                    .font(.pt(size: 56, weight: .bold).monospacedDigit())
                    .foregroundStyle(right == total ? Theme.accent : Palette.ink)
                Text("맞힌 개수")
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(.secondary)
                if kind == .daily && !practice {
                    TagLabel(text: "오늘 목표 완료", symbol: "checkmark")
                        .padding(.top, 6)
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 28)

            if missed.isEmpty {
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.pt(size: 52))
                    .foregroundStyle(Theme.accent)
                    .symbolEffect(.bounce, options: .nonRepeating, value: finished)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("다시 볼 단어 \(missed.count)")
                        .font(.pt(.subheadline).weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(missed) { word in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(word.term).font(.pt(.body).weight(.semibold)).foregroundStyle(Palette.ink)
                                        Text(word.meaning).font(.pt(.subheadline)).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer(minLength: 8)
                                    SpeakButton(text: word.term, size: 34)
                                }
                                .padding(.vertical, 10)
                                if word.id != missed.last?.id { Divider() }
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(Palette.cardInset, in: .rect(cornerRadius: 18))
                    }
                    .scrollIndicators(.hidden)
                }
            }

            VStack(spacing: 10) {
                Button {
                    practice = true
                    withAnimation(reduceMotion ? nil : .smooth) { start(with: missed.isEmpty ? roundWords : missed) }
                } label: {
                    Label("다시 하기", systemImage: "arrow.counterclockwise")
                        .font(.pt(.body).weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.accent.opacity(0.1), in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.pressable)
                Button("완료") { dismiss() }
                    .buttonStyle(.primaryFill)
            }
            .padding(.vertical, 20)
        }
    }
}

/// 뜻 보기 두 개 만들기: 정답 + 같은 단어장의 다른 뜻 하나 (같거나 거의 같은 뜻은 뺌)
enum WordChoices {
    static func make(for word: Word, pool: [Word], count: Int = 2) -> [String] {
        let answer = word.meaning
        let key = AnswerChecker.normalizeMeaning(answer)
        guard !key.isEmpty else { return [answer] }

        func candidates(_ words: [Word]) -> [String] {
            var keys: Set<String> = [key]
            var result: [String] = []
            for other in words.shuffled() where other.id != word.id {
                let meaning = other.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
                let otherKey = AnswerChecker.normalizeMeaning(meaning)
                guard !otherKey.isEmpty, !keys.contains(otherKey) else { continue }
                // "사과" ↔ "사과, 사과나무" 처럼 정답으로도 통하는 뜻은 보기에서 뺌
                guard !AnswerChecker.checkMeaning(meaning, answer: answer),
                      !AnswerChecker.checkMeaning(answer, answer: meaning) else { continue }
                keys.insert(otherKey)
                result.append(meaning)
                if result.count >= count - 1 { break }
            }
            return result
        }

        var distractors = candidates(pool.filter { $0.deck == word.deck })
        if distractors.count < count - 1 {
            // 같은 단어장에 다른 뜻이 없으면 다른 단어장에서
            distractors = candidates(pool.filter { $0.deck != word.deck })
        }
        guard distractors.count >= count - 1 else { return [answer] }
        return (distractors + [answer]).shuffled()
    }
}
