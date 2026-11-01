import SwiftData
import SwiftUI

/// 단어 게임: 짝 맞추기 · 스피드 퀴즈 · 스펠링 퍼즐 · 발음 연습
struct WordGamesView: View {
    @Query(sort: \Word.createdAt) private var allWords: [Word]

    private var words: [Word] {
        allWords.filter {
            !$0.term.trimmingCharacters(in: .whitespaces).isEmpty && !$0.meaning.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    enum Game: String, CaseIterable, Identifiable {
        case match, speed, spelling, speak

        var id: String { rawValue }

        var title: String {
            switch self {
            case .match: return "짝 맞추기"
            case .speed: return "스피드 퀴즈"
            case .spelling: return "스펠링 퍼즐"
            case .speak: return "발음 연습"
            }
        }

        var subtitle: String {
            switch self {
            case .match: return "단어와 뜻 카드를 빠르게 짝지어요"
            case .speed: return "60초 동안 뜻을 최대한 많이 맞혀요"
            case .spelling: return "섞인 알파벳으로 단어를 완성해요"
            case .speak: return "듣고 따라 말하면 발음을 확인해요"
            }
        }

        var symbol: String {
            switch self {
            case .match: return "square.grid.2x2.fill"
            case .speed: return "bolt.fill"
            case .spelling: return "textformat.abc"
            case .speak: return "mic.fill"
            }
        }

        var color: Color {
            switch self {
            case .match: return Color(hex: "#7B68EE")
            case .speed: return Palette.warning
            case .spelling: return Color(hex: "#3D9BE0")
            case .speak: return Palette.success
            }
        }

        var minimumWords: Int { self == .match || self == .speed ? 4 : 1 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if words.count < 4 {
                    Label("단어가 4개 이상 있어야 모든 게임을 할 수 있어요. 지금 \(words.count)개", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Game.allCases) { game in
                    let ready = words.count >= game.minimumWords
                    NavigationLink {
                        switch game {
                        case .match: MatchGameView(pool: words)
                        case .speed: SpeedQuizView(pool: words)
                        case .spelling: SpellingGameView(pool: words)
                        case .speak: SpeakPracticeView(pool: words)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: game.symbol)
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 54, height: 54)
                                .background(game.color.gradient, in: .rect(cornerRadius: 16))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(game.title).font(.headline)
                                Text(game.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                        }
                        .glassCard(interactive: true)
                        .opacity(ready ? 1 : 0.45)
                    }
                    .buttonStyle(.plain)
                    .disabled(!ready)
                }
            }
            .padding(20)
        }
        .background { AppBackground() }
        .navigationTitle("단어 게임")
    }
}

// MARK: - 결과 화면 (공통)

private struct GameResultView: View {
    let title: String
    let detail: String
    let symbol: String
    let again: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.bounce, value: title)
            Text(title).font(.title.weight(.heavy))
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(action: again) {
                Label("다시 하기", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(20)
    }
}

// MARK: - 1. 짝 맞추기

private struct MatchGameView: View {
    let pool: [Word]

    struct Card: Identifiable, Equatable {
        let id = UUID()
        let wordID: UUID
        let text: String
        let isTerm: Bool
    }

    @State private var cards: [Card] = []
    @State private var selected: Card?
    @State private var matched: Set<UUID> = []
    @State private var wrongPair: [UUID] = []
    @State private var mistakes = 0
    @State private var startedAt = Date()
    @State private var finishedIn: Int?

    var body: some View {
        Group {
            if let finishedIn {
                GameResultView(title: "모두 맞췄어요!", detail: "\(finishedIn)초 · 실수 \(mistakes)번", symbol: "checkmark.seal.fill") { setUp() }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        HStack {
                            Label("\(matched.count / 2)/\(cards.count / 2)", systemImage: "square.grid.2x2")
                            Spacer()
                            Label("실수 \(mistakes)", systemImage: "xmark.circle")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(cards) { card in cardView(card) }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background { AppBackground() }
        .navigationTitle("짝 맞추기")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if cards.isEmpty { setUp() } }
    }

    private func cardView(_ card: Card) -> some View {
        let isMatched = matched.contains(card.id)
        let isSelected = selected?.id == card.id
        let isWrong = wrongPair.contains(card.id)
        return Button { tap(card) } label: {
            Text(card.text)
                .font(card.isTerm ? .headline : .subheadline)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 74)
                .padding(8)
                .background(
                    isWrong ? Palette.danger.opacity(0.25) : (isSelected ? Theme.accent : Color.primary.opacity(0.05)),
                    in: .rect(cornerRadius: 16)
                )
        }
        .buttonStyle(.plain)
        .opacity(isMatched ? 0 : 1)
        .scaleEffect(isMatched ? 0.8 : 1)
        .disabled(isMatched)
        .animation(.snappy, value: isMatched)
        .animation(.snappy, value: isSelected)
    }

    private func setUp() {
        let picked = Array(pool.shuffled().prefix(6))
        cards = picked.flatMap { word in
            [Card(wordID: word.id, text: word.term, isTerm: true), Card(wordID: word.id, text: word.meaning, isTerm: false)]
        }.shuffled()
        selected = nil
        matched = []
        mistakes = 0
        finishedIn = nil
        startedAt = Date()
    }

    private func tap(_ card: Card) {
        guard let first = selected else {
            selected = card
            Haptics.tap()
            return
        }
        if first.id == card.id { selected = nil; return }
        if first.wordID == card.wordID && first.isTerm != card.isTerm {
            matched.insert(first.id)
            matched.insert(card.id)
            selected = nil
            Haptics.success()
            if matched.count == cards.count {
                finishedIn = Int(Date().timeIntervalSince(startedAt))
            }
        } else {
            mistakes += 1
            wrongPair = [first.id, card.id]
            selected = nil
            Haptics.error()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { wrongPair = [] }
        }
    }
}

// MARK: - 2. 스피드 퀴즈

private struct SpeedQuizView: View {
    let pool: [Word]
    private let duration = 60

    @State private var current: Word?
    @State private var choices: [String] = []
    @State private var score = 0
    @State private var answered = 0
    @State private var endsAt: Date?
    @State private var feedback: String?
    @State private var finished = false

    var body: some View {
        Group {
            if finished {
                GameResultView(title: "\(score)개 맞혔어요!", detail: "\(answered)문제 중 \(score)문제 정답 · 틀린 단어는 복습 목록에 들어가요",
                               symbol: "bolt.fill") { start() }
            } else if let current, let endsAt {
                VStack(spacing: 22) {
                    TimelineView(.periodic(from: .now, by: 0.2)) { context in
                        let left = max(0, endsAt.timeIntervalSince(context.date))
                        VStack(spacing: 6) {
                            ProgressView(value: left, total: Double(duration))
                                .tint(left < 10 ? Palette.danger : Theme.accent)
                            HStack {
                                Text("\(Int(left.rounded(.up)))초").monospacedDigit()
                                Spacer()
                                Text("점수 \(score)").monospacedDigit()
                            }
                            .font(.subheadline.weight(.bold))
                        }
                        .onChange(of: left <= 0) { _, over in if over { finished = true } }
                    }

                    VStack(spacing: 6) {
                        Text(current.term).font(.system(size: 34, weight: .heavy))
                        Button { WordSpeaker.shared.speak(current.term) } label: {
                            Image(systemName: "speaker.wave.2.fill").font(.headline)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))

                    VStack(spacing: 10) {
                        ForEach(choices, id: \.self) { choice in
                            Button { answer(choice, for: current) } label: {
                                Text(choice)
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let feedback {
                        Text(feedback).font(.subheadline.weight(.bold)).transition(.opacity)
                    }
                    Spacer()
                }
                .padding(20)
            } else {
                ProgressView()
            }
        }
        .background { AppBackground() }
        .navigationTitle("스피드 퀴즈")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if endsAt == nil { start() } }
    }

    private func start() {
        score = 0
        answered = 0
        finished = false
        feedback = nil
        endsAt = Date().addingTimeInterval(TimeInterval(duration))
        next()
    }

    private func next() {
        guard let word = pool.randomElement() else { return }
        current = word
        let others = pool.filter { $0.id != word.id }.map(\.meaning).filter { $0 != word.meaning }
        choices = (Array(Set(others)).shuffled().prefix(3) + [word.meaning]).shuffled()
    }

    private func answer(_ choice: String, for word: Word) {
        guard !finished else { return }
        answered += 1
        if choice == word.meaning {
            score += 1
            word.correctCount += 1
            Haptics.success()
            withAnimation { feedback = "정답!" }
        } else {
            word.wrongCount += 1
            Haptics.error()
            withAnimation { feedback = "\(word.term) = \(word.meaning)" }
        }
        next()
    }
}

// MARK: - 3. 스펠링 퍼즐

private struct SpellingGameView: View {
    let pool: [Word]

    struct Tile: Identifiable, Equatable {
        let id = UUID()
        let letter: Character
    }

    @State private var queue: [Word] = []
    @State private var index = 0
    @State private var tiles: [Tile] = []
    @State private var picked: [Tile] = []
    @State private var correct = 0
    @State private var shake = 0
    @State private var revealed = false

    private var current: Word? { index < queue.count ? queue[index] : nil }
    private var target: String { (current?.term ?? "").lowercased().filter { $0.isLetter } }

    var body: some View {
        Group {
            if let current {
                VStack(spacing: 20) {
                    Text("\(index + 1) / \(queue.count)").font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
                    VStack(spacing: 6) {
                        Text("뜻").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        Text(current.meaning).font(.title2.weight(.heavy)).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))

                    // 고른 글자
                    HStack(spacing: 6) {
                        ForEach(Array(target.enumerated()), id: \.offset) { offset, letter in
                            let shown: Character? = revealed ? letter : (offset < picked.count ? picked[offset].letter : nil)
                            Text(shown.map { String($0) } ?? " ")
                                .font(.title2.weight(.bold).monospaced())
                                .frame(width: 30, height: 40)
                                .overlay(alignment: .bottom) { Rectangle().fill(Theme.accent).frame(height: 2) }
                        }
                    }
                    .modifier(ShakeEffect(shakes: CGFloat(shake)))
                    .animation(.default, value: shake)

                    // 섞인 글자
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 8), count: 6), spacing: 8) {
                        ForEach(tiles) { tile in
                            let used = picked.contains(tile)
                            Button { pick(tile) } label: {
                                Text(String(tile.letter))
                                    .font(.title3.weight(.bold).monospaced())
                                    .frame(width: 48, height: 48)
                                    .background(used ? Color.clear : Theme.accent.opacity(0.14), in: .rect(cornerRadius: 12))
                                    .foregroundStyle(used ? Color.clear : Theme.accent)
                            }
                            .buttonStyle(.plain)
                            .disabled(used || revealed)
                        }
                    }

                    HStack(spacing: 10) {
                        Button { if !picked.isEmpty { picked.removeLast() } } label: {
                            Label("지우기", systemImage: "delete.left").frame(maxWidth: .infinity).frame(height: 36)
                        }
                        .buttonStyle(.glass)
                        Button { reveal() } label: {
                            Label("정답 보기", systemImage: "eye").frame(maxWidth: .infinity).frame(height: 36)
                        }
                        .buttonStyle(.glass)
                    }
                    Spacer()
                }
                .padding(20)
            } else if !queue.isEmpty {
                GameResultView(title: "\(correct) / \(queue.count) 완성!", detail: "정답 보기 없이 완성한 단어 수예요",
                               symbol: "textformat.abc") { setUp() }
            } else {
                ProgressView()
            }
        }
        .background { AppBackground() }
        .navigationTitle("스펠링 퍼즐")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if queue.isEmpty { setUp() } }
    }

    private func setUp() {
        queue = Array(pool.filter { (2...12).contains($0.term.filter(\.isLetter).count) }.shuffled().prefix(10))
        if queue.isEmpty { queue = Array(pool.shuffled().prefix(10)) }
        index = 0
        correct = 0
        load()
    }

    private func load() {
        picked = []
        revealed = false
        tiles = target.map { Tile(letter: $0) }.shuffled()
    }

    private func pick(_ tile: Tile) {
        picked.append(tile)
        Haptics.tap()
        guard picked.count == target.count else { return }
        if String(picked.map(\.letter)) == target {
            correct += 1
            Haptics.success()
            if let current { WordSpeaker.shared.speak(current.term) }
            advance(after: 0.7)
        } else {
            Haptics.error()
            shake += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { picked = [] }
        }
    }

    private func reveal() {
        revealed = true
        current?.wrongCount += 1
        advance(after: 1.4)
    }

    private func advance(after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            index += 1
            if current != nil { load() }
        }
    }
}

private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(shakes * .pi * 4), y: 0))
    }
}

// MARK: - 4. 발음 연습

struct SpeakPracticeView: View {
    let pool: [Word]

    @State private var queue: [Word] = []
    @State private var index = 0
    @State private var checker = SpeechChecker()
    @State private var result: Bool?
    @State private var passed = 0

    private var current: Word? { index < queue.count ? queue[index] : nil }

    var body: some View {
        Group {
            if let current {
                VStack(spacing: 22) {
                    Text("\(index + 1) / \(queue.count)").font(.subheadline.weight(.bold)).foregroundStyle(.secondary)

                    VStack(spacing: 10) {
                        Text(current.term).font(.system(size: 38, weight: .heavy))
                        Text(current.meaning).font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button { WordSpeaker.shared.speak(current.term) } label: {
                                Label("듣기", systemImage: "speaker.wave.2.fill")
                            }
                            Button { WordSpeaker.shared.speak(current.term, slow: true) } label: {
                                Label("천천히", systemImage: "tortoise.fill")
                            }
                        }
                        .buttonStyle(.glass)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .glassEffect(.regular, in: .rect(cornerRadius: 26))

                    Button {
                        if checker.isListening {
                            checker.stop()
                        } else {
                            result = nil
                            Task {
                                await checker.start(expected: current.term) { spoken in
                                    let ok = SpeechChecker.matches(spoken, expected: current.term)
                                    withAnimation(.snappy) { result = ok }
                                    if ok { passed += 1; Haptics.success() } else { Haptics.error() }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: checker.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 96)
                            .background(checker.isListening ? Palette.danger : Theme.accent, in: .circle)
                            .symbolEffect(.pulse, isActive: checker.isListening)
                    }
                    .buttonStyle(.plain)

                    Group {
                        if checker.isListening {
                            Text(checker.transcript.isEmpty ? "듣고 있어요… 단어를 말해보세요" : "“\(checker.transcript)”")
                                .foregroundStyle(.secondary)
                        } else if let result {
                            VStack(spacing: 4) {
                                Label(result ? "정확해요!" : "다시 해볼까요?",
                                      systemImage: result ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(result ? Palette.success : Palette.warning)
                                if !checker.transcript.isEmpty {
                                    Text("들린 말: \(checker.transcript)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        } else if let error = checker.errorMessage {
                            Text(error).font(.caption).foregroundStyle(Palette.danger).multilineTextAlignment(.center)
                        } else {
                            Text("마이크를 누르고 단어를 말해보세요").foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .frame(minHeight: 44)

                    Button {
                        index += 1
                        result = nil
                    } label: {
                        Text(result == true ? "다음 단어" : "건너뛰기")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.glass)
                    Spacer()
                }
                .padding(20)
                .onAppear { WordSpeaker.shared.speak(current.term) }
                .onChange(of: index) { if let next = self.current { WordSpeaker.shared.speak(next.term) } }
            } else if !queue.isEmpty {
                GameResultView(title: "\(passed) / \(queue.count) 통과!", detail: "기기 안 음성 인식으로 확인했어요",
                               symbol: "mic.fill") { setUp() }
            } else {
                ProgressView()
            }
        }
        .background { AppBackground() }
        .navigationTitle("발음 연습")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if queue.isEmpty { setUp() } }
        .onDisappear { checker.stop() }
    }

    private func setUp() {
        queue = Array(pool.shuffled().prefix(10))
        index = 0
        passed = 0
        result = nil
    }
}
