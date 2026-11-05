import SwiftData
import SwiftUI

/// 듣기 퀴즈: 발음을 듣고 ① 뜻 고르기 ② 받아쓰기
struct ListenQuizView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case meaning = "뜻 고르기", spelling = "받아쓰기"
        var id: String { rawValue }
        var symbol: String { self == .meaning ? "list.bullet" : "keyboard" }
    }

    let pool: [Word]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: Mode
    @State private var queue: [Word] = []
    @State private var index = 0
    @State private var choices: [String] = []
    @State private var picked: String?
    @State private var typed = ""
    @State private var result: Bool?
    @State private var correct = 0
    @FocusState private var focused: Bool

    init(pool: [Word], mode: Mode = .meaning) {
        self.pool = pool
        _mode = State(initialValue: mode)
    }

    private var current: Word? { queue.indices.contains(index) ? queue[index] : nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Picker("방식", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue.loc).tag($0) }
                }
                .pickerStyle(.segmented)

                if let word = current {
                    question(word)
                } else if !queue.isEmpty {
                    finished
                } else {
                    Text("단어가 없어요").foregroundStyle(.secondary).padding(.top, 60)
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.card.ignoresSafeArea())
        .navigationTitle("듣기 퀴즈")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if queue.isEmpty { setUp() } }
        .onChange(of: mode) { setUp() }
        .sensoryFeedback(trigger: result) { _, value in
            switch value {
            case .some(true): return .success
            case .some(false): return .error
            case .none: return nil
            }
        }
    }

    // MARK: 문제

    @ViewBuilder
    private func question(_ word: Word) -> some View {
        Text("\(index + 1)/\(queue.count)")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)

        VStack(spacing: 14) {
            SpeakButton(text: word.term, size: 84)
            if result != nil {
                Text(word.term)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(result == true ? Theme.accent : Palette.danger)
                Text(word.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .id(index)

        if mode == .meaning {
            VStack(spacing: 10) {
                ForEach(choices, id: \.self) { choice in
                    Button { pick(choice, word: word) } label: {
                        Text(choice)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(choiceColor(choice, word: word))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(choiceBackground(choice, word: word), in: .rect(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(choiceStroke(choice, word: word), lineWidth: 2)
                            }
                    }
                    .buttonStyle(.pressable)
                    .disabled(result != nil)
                }
            }
        } else {
            HStack(spacing: 10) {
                TextField("들린 단어", text: $typed)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { check(word) }
                    .disabled(result != nil)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Palette.cardInset, in: .rect(cornerRadius: 16))
                if result == nil {
                    Button("확인") { check(word) }
                        .font(.headline)
                        .tint(Theme.accent)
                        .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }

        if result != nil {
            Button {
                next()
            } label: {
                Label(index + 1 < queue.count ? L("다음") : L("결과"), systemImage: "arrow.right")
            }
            .buttonStyle(.primaryFill)
        }
    }

    private var finished: some View {
        VStack(spacing: 16) {
            Text("\(correct)/\(queue.count)")
                .font(.system(size: 52, weight: .bold).monospacedDigit())
                .foregroundStyle(correct == queue.count ? Theme.accent : Palette.ink)
            Text("맞힌 개수").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Button { setUp() } label: { Label("다시 하기", systemImage: "arrow.counterclockwise") }
                .buttonStyle(.primaryFill)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: 진행

    private func setUp() {
        queue = Array(pool.filter { !$0.term.isEmpty && !$0.meaning.isEmpty }.shuffled().prefix(10))
        index = 0
        correct = 0
        prepare()
    }

    private func prepare() {
        picked = nil
        typed = ""
        result = nil
        guard let word = current else { return }
        if mode == .meaning {
            let others = pool.filter { $0.id != word.id && $0.meaning != word.meaning }.map(\.meaning)
            choices = (Array(Set(others)).shuffled().prefix(3) + [word.meaning]).shuffled()
        } else {
            focused = true
        }
        // 화면이 바뀐 뒤 바로 들려줌
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { WordSpeaker.shared.speak(word.term) }
    }

    private func pick(_ choice: String, word: Word) {
        guard result == nil else { return }
        picked = choice
        finish(choice == word.meaning, word: word)
    }

    private func check(_ word: Word) {
        guard result == nil, !typed.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        finish(AnswerChecker.checkTerm(typed, answer: word.term), word: word)
    }

    private func finish(_ ok: Bool, word: Word) {
        withAnimation(reduceMotion ? nil : .snappy) { result = ok }
        if ok { correct += 1; word.correctCount += 1 } else { word.wrongCount += 1 }
        focused = false
    }

    private func next() {
        withAnimation(reduceMotion ? nil : .smooth) { index += 1 }
        prepare()
    }

    private func choiceColor(_ choice: String, word: Word) -> Color {
        guard result != nil else { return Palette.ink }
        if choice == word.meaning { return Theme.accent }
        return choice == picked ? Palette.danger : Color.secondary
    }

    private func choiceStroke(_ choice: String, word: Word) -> Color {
        guard result != nil else { return .clear }
        if choice == word.meaning { return Theme.accent }
        return choice == picked ? Palette.danger : .clear
    }

    private func choiceBackground(_ choice: String, word: Word) -> Color {
        guard result != nil else { return Palette.cardInset }
        if choice == word.meaning { return Theme.accent.opacity(0.08) }
        return choice == picked ? Palette.danger.opacity(0.08) : Palette.cardInset
    }
}
