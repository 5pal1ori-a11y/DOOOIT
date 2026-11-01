import SwiftData
import SwiftUI

/// 단어 암기 세션
/// 1. 외우기: 단어 + 뜻을 메모지에 보여줌 → 다음
/// 2. 뜻 쓰기: 뜻을 가리고 입력 → 정답/오답 → 틀린 단어는 다시 외우고 재시험 (모두 맞을 때까지)
/// 3. 단어 쓰기: 단어를 가리고 입력 → 같은 방식
/// 4. 완료: 오늘의 단어목표 성공!
struct WordSessionView: View {
    enum Kind { case daily, extra, review }
    enum QuizType: Equatable { case meaning, term }
    enum Step: Equatable {
        case learn(review: QuizType?)
        case quiz(QuizType)
        case finished
    }

    let words: [Word]
    let kind: Kind

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.wordGoalDoneKey) private var wordGoalDoneKey = ""

    @State private var step: Step = .learn(review: nil)
    @State private var queue: [Word] = []
    @State private var index = 0
    @State private var wrongs: [Word] = []
    @State private var answer = ""
    @State private var result: Bool?
    @State private var totalWrong = 0
    @State private var showExitConfirm = false
    @FocusState private var inputFocused: Bool

    private var current: Word? { queue.indices.contains(index) ? queue[index] : nil }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 18) {
                topBar
                if step == .finished {
                    finishedView
                } else if let word = current {
                    ScrollView {
                        VStack(spacing: 22) {
                            card(for: word)
                                .id("\(stepID)-\(index)")
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            controls(for: word)
                        }
                        .padding(.top, 14)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.never)
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            if queue.isEmpty { queue = words }
        }
        .sensoryFeedback(trigger: result) { _, newValue in
            switch newValue {
            case .some(true): return .success
            case .some(false): return .error
            case .none: return nil
            }
        }
        .confirmationDialog("학습을 그만할까요?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("그만하기", role: .destructive) { dismiss() }
            Button("계속하기", role: .cancel) {}
        } message: {
            Text("지금까지의 정답/오답 기록은 저장되지만, 오늘의 목표는 완료되지 않아요.")
        }
    }

    // MARK: Top bar

    private var stepID: String {
        switch step {
        case .learn(let review): return review == nil ? "learn" : "review"
        case .quiz(let type): return type == .meaning ? "quiz-meaning" : "quiz-term"
        case .finished: return "done"
        }
    }

    private var stepTitle: String {
        switch step {
        case .learn(.none): return "단어 외우기"
        case .learn(.some): return "틀린 단어 복습"
        case .quiz(.meaning): return "뜻 쓰기"
        case .quiz(.term): return "단어 쓰기"
        case .finished: return "완료"
        }
    }

    private var stepIndex: Int {
        switch step {
        case .learn(.none): return 1
        case .quiz(.meaning), .learn(.some(.meaning)): return 2
        case .quiz(.term), .learn(.some(.term)): return 3
        case .finished: return 3
        }
    }

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    if step == .finished { dismiss() } else { showExitConfirm = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)

                Spacer()

                VStack(spacing: 2) {
                    Text(stepTitle).font(.headline)
                    if step != .finished {
                        Text("\(stepIndex)/3 단계").font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(step == .finished ? "" : "\(min(index + 1, queue.count))/\(queue.count)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular, in: .circle)
                    .opacity(step == .finished ? 0 : 1)
            }

            if step != .finished {
                ProgressView(value: Double(index + (result != nil ? 1 : 0)), total: Double(max(queue.count, 1)))
                    .tint(Theme.accent)
                    .animation(.smooth, value: index)
            }
        }
        .padding(.top, 8)
    }

    // MARK: Card

    @ViewBuilder
    private func card(for word: Word) -> some View {
        NotePaperCard {
            VStack(alignment: .leading, spacing: 26) {
                switch step {
                case .learn:
                    termText(word.term)
                    meaningText(word.meaning)

                case .quiz(.meaning):
                    termText(word.term)
                    if let result {
                        meaningText(word.meaning, color: result ? Palette.success : Palette.danger)
                    } else {
                        hiddenBlock("뜻을 적어보세요")
                    }

                case .quiz(.term):
                    if let result {
                        termText(word.term, color: result ? Palette.success : Palette.danger)
                    } else {
                        hiddenBlock("단어를 적어보세요")
                    }
                    meaningText(word.meaning)

                case .finished:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            if let result {
                Image(systemName: result ? "circle" : "xmark")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle((result ? Palette.success : Palette.danger).opacity(0.8))
                    .rotationEffect(.degrees(-12))
                    .padding(18)
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
            }
        }
    }

    private func termText(_ text: String, color: Color = Palette.ink) -> some View {
        Text(text)
            .font(.custom("Noteworthy-Bold", size: 40, relativeTo: .largeTitle))
            .foregroundStyle(color)
            .minimumScaleFactor(0.5)
            .lineLimit(2)
    }

    private func meaningText(_ text: String, color: Color = Palette.ink) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(color.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func hiddenBlock(_ placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash.fill")
            Text(placeholder)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Palette.ink.opacity(0.45))
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Palette.ink.opacity(0.07), in: .rect(cornerRadius: 12))
    }

    // MARK: Controls

    @ViewBuilder
    private func controls(for word: Word) -> some View {
        switch step {
        case .learn:
            primaryButton(index + 1 < queue.count ? "다음 단어" : learnFinishTitle, symbol: "arrow.right") {
                advance()
            }

        case .quiz(let type):
            VStack(spacing: 14) {
                if let result {
                    feedback(isCorrect: result, word: word, type: type)
                    primaryButton(index + 1 < queue.count ? "다음" : "결과 보기", symbol: "arrow.right") {
                        advance()
                    }
                } else {
                    HStack(spacing: 10) {
                        TextField(type == .meaning ? "뜻 입력" : "영어 단어 입력", text: $answer)
                            .font(.title3)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($inputFocused)
                            .submitLabel(.done)
                            .onSubmit(check)
                            .glassField()
                        Button(action: check) {
                            Image(systemName: "checkmark")
                                .font(.title3.weight(.bold))
                                .frame(width: 30, height: 36)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Button("모르겠어요") {
                        answer = ""
                        markResult(false, word: word)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .onAppear { inputFocused = true }

        case .finished:
            EmptyView()
        }
    }

    private var learnFinishTitle: String {
        if case .learn(let review) = step, let review {
            return review == .meaning ? "뜻 다시 쓰기" : "단어 다시 쓰기"
        }
        return "뜻 쓰기 시작"
    }

    private func feedback(isCorrect: Bool, word: Word, type: QuizType) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(isCorrect ? Palette.success : Palette.danger)
            VStack(alignment: .leading, spacing: 4) {
                Text(isCorrect ? "맞았어요!" : "틀렸어요")
                    .font(.headline)
                if !isCorrect {
                    Text("정답: \(type == .meaning ? word.meaning : word.term)")
                        .font(.subheadline)
                    if !answer.isEmpty {
                        Text("내 답: \(answer)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("이 단어는 이번 단계가 끝나면 다시 복습해요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .glassCard(cornerRadius: 20, padding: 16, tint: (isCorrect ? Palette.success : Palette.danger).opacity(0.25))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func primaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Image(systemName: symbol)
            }
            .font(.body.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 40)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }

    // MARK: Flow

    private func check() {
        guard result == nil, let word = current, case .quiz(let type) = step else { return }
        guard !answer.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let ok = type == .meaning
            ? AnswerChecker.checkMeaning(answer, answer: word.meaning)
            : AnswerChecker.checkTerm(answer, answer: word.term)
        markResult(ok, word: word)
    }

    private func markResult(_ ok: Bool, word: Word) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { result = ok }
        if ok {
            word.correctCount += 1
        } else {
            word.wrongCount += 1
            totalWrong += 1
            if !wrongs.contains(where: { $0.id == word.id }) { wrongs.append(word) }
        }
        inputFocused = false
    }

    private func advance() {
        if index + 1 < queue.count {
            withAnimation(.smooth(duration: 0.35)) {
                index += 1
                answer = ""
                result = nil
            }
            if case .quiz = step { inputFocused = true }
            return
        }
        finishStep()
    }

    private func finishStep() {
        switch step {
        case .learn(.none):
            begin(.quiz(.meaning), queue: words.shuffled())

        case .learn(.some(let type)):
            // 복습한 단어만 다시 시험
            begin(.quiz(type), queue: queue.shuffled())

        case .quiz(let type):
            if !wrongs.isEmpty {
                let review = wrongs
                wrongs = []
                begin(.learn(review: type), queue: review)
            } else if type == .meaning {
                begin(.quiz(.term), queue: words.shuffled())
            } else {
                complete()
            }

        case .finished:
            dismiss()
        }
    }

    private func begin(_ newStep: Step, queue newQueue: [Word]) {
        withAnimation(.smooth(duration: 0.4)) {
            step = newStep
            queue = newQueue
            index = 0
            answer = ""
            result = nil
        }
        if case .quiz = newStep { inputFocused = true }
    }

    private func complete() {
        let now = Date()
        for word in words {
            if word.learnedAt == nil { word.learnedAt = now }
            if kind == .review { word.wrongCount = 0 }
        }
        if kind == .daily { wordGoalDoneKey = now.dayKey }
        try? context.save()
        Haptics.success()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { step = .finished }
    }

    // MARK: Finished

    @State private var celebrate = false

    private var finishedView: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Palette.success.opacity(0.18))
                    .frame(width: 170, height: 170)
                    .scaleEffect(celebrate ? 1 : 0.6)
                Image(systemName: kind == .daily ? "trophy.fill" : "checkmark.seal.fill")
                    .font(.system(size: 76, weight: .bold))
                    .foregroundStyle(Palette.success)
                    .symbolEffect(.bounce, value: celebrate)
            }
            .glassEffect(.regular, in: .circle)

            VStack(spacing: 8) {
                Text(kind == .daily ? "오늘의 단어목표 성공!" : (kind == .review ? "복습 완료!" : "학습 완료!"))
                    .font(.title.weight(.bold))
                Text("\(words.count)개 단어를 모두 통과했어요 · 오답 \(totalWrong)회")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            primaryButton("완료", symbol: "checkmark") { dismiss() }
                .padding(.bottom, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.1)) { celebrate = true }
        }
    }
}
