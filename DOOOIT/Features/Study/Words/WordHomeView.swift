import PhotosUI
import SwiftData
import SwiftUI

/// 영어 단어 홈: 위에 단어장 고르기 · 기록, 아래 "학습 | 내 단어장" 탭
struct WordHomeView: View {
    enum Tab: Hashable { case study, book }

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Word.createdAt) private var words: [Word]

    @AppStorage(SettingsKey.dailyWordGoal) private var wordGoal = 20
    @AppStorage(SettingsKey.wordGoalDoneKey) private var wordGoalDoneKey = ""
    /// 고른 단어장 ("" = 전체)
    @AppStorage("word.selectedDeck") private var selectedDeck = ""

    @State private var tab: Tab = .study
    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var importBatch: ImageBatch?
    @State private var showManualAdd = false
    @State private var showStats = false
    @State private var session: WordSessionConfig?
    @State private var errorMessage: String?
    @Namespace private var tabUnderline

    // MARK: 단어장

    private var decks: [String] { Array(Set(words.map(\.deck))).sorted() }
    private var activeDeck: String? { decks.contains(selectedDeck) ? selectedDeck : nil }
    private var deckWords: [Word] {
        guard let activeDeck else { return words }
        return words.filter { $0.deck == activeDeck }
    }
    private var title: String {
        if let activeDeck { return activeDeck.loc }
        return decks.count == 1 ? decks[0].loc : L("전체 단어")
    }
    /// 새로 추가할 때 기본 단어장
    private var addDeck: String { activeDeck ?? (decks.count == 1 ? decks[0] : "기본 단어장") }

    // MARK: 오늘 할 일

    private var unlearned: [Word] { deckWords.filter { !$0.isLearned } }
    private var doneToday: Bool { wordGoalDoneKey == Date().dayKey }
    private var todayWords: [Word] { Array(unlearned.prefix(wordGoal)) }
    private var newCount: Int { doneToday ? 0 : todayWords.count }
    /// 오늘 복습할 단어 (오래 기다린 것부터, 한 번에 최대 50개)
    private var dueWords: [Word] {
        Array(deckWords.filter(\.isDueForReview)
            .sorted { ($0.nextReviewAt ?? .distantPast) < ($1.nextReviewAt ?? .distantPast) }
            .prefix(50))
    }
    private var wrongWords: [Word] { deckWords.filter { $0.wrongCount > 0 }.sorted { $0.wrongCount > $1.wrongCount } }
    private var starredWords: [Word] { deckWords.filter(\.isStarred) }
    private var listenPool: [Word] { deckWords.filter { !$0.term.trimmingCharacters(in: .whitespaces).isEmpty } }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            switch tab {
            case .study: studyTab
            case .book: WordListView(words: deckWords, defaultDeck: addDeck)
            }
        }
        .background(Palette.card.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { deckMenu }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                Button { showStats = true } label: {
                    Image(systemName: "chart.bar.fill")
                }
                .accessibilityLabel("기록")
            }
        }
        .imageInput(showScanner: $showScanner, showPhotoPicker: $showPhotoPicker, photoItems: $photoItems, straighten: true) { images in
            importBatch = ImageBatch(images: images)
        }
        .sheet(item: $importBatch) { batch in
            WordImportView(images: batch.images, deck: addDeck)
        }
        .sheet(isPresented: $showManualAdd) {
            WordEditSheet(word: nil, defaultDeck: addDeck)
        }
        .sheet(isPresented: $showStats) {
            WordStatsSheet(words: deckWords, title: title)
        }
        .fullScreenCover(item: $session) { config in
            WordSessionView(words: config.words, kind: config.kind, pool: words)
        }
        .errorAlert($errorMessage)
        .onAppear(perform: scheduleLegacyWords)
    }

    /// 복습 일정이 생기기 전에 외운 단어: 외운 날 기준으로 일정을 잡아 둠
    private func scheduleLegacyWords() {
        var changed = false
        for word in words where word.reviewStage == 0 {
            guard let learnedAt = word.learnedAt else { continue }
            let schedule = WordReview.legacy(learnedAt: learnedAt)
            word.reviewStage = schedule.stage
            word.nextReviewAt = schedule.next
            changed = true
        }
        if changed { try? context.save() }
    }

    // MARK: 위: 단어장 메뉴 · 탭

    private var deckMenu: some View {
        Menu {
            Picker("단어장", selection: $selectedDeck) {
                Text("전체").tag("")
                ForEach(decks, id: \.self) { Text($0.loc).tag($0) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 220)
        }
        .accessibilityLabel("단어장 바꾸기, 지금 \(title)")
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(L("학습"), .study)
            tabButton(L("내 단어장"), .book)
        }
        .padding(.horizontal, 20)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1)
        }
    }

    private func tabButton(_ label: String, _ value: Tab) -> some View {
        let selected = tab == value
        return Button {
            guard tab != value else { return }
            Haptics.tap()
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { tab = value }
        } label: {
            VStack(spacing: 8) {
                Text(label)
                    .font(.body.weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? Palette.ink : .secondary)
                ZStack {
                    Capsule().fill(Color.clear).frame(height: 3)
                    if selected {
                        Capsule()
                            .fill(Theme.accent)
                            .frame(height: 3)
                            .matchedGeometryEffect(id: "underline", in: tabUnderline)
                    }
                }
            }
            .fixedSize()
            .padding(.top, 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: 학습 탭

    private var studyTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                if deckWords.isEmpty {
                    emptyHero
                } else {
                    todayStats
                        .padding(.top, 36)
                    startButton
                        .padding(.top, 32)
                }
                menuRows
                    .padding(.top, 36)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyHero: some View {
        VStack(spacing: 14) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("단어가 없어요")
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.ink)
            addMenu {
                Label("단어 추가", systemImage: "plus")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.accent, in: .rect(cornerRadius: 20, style: .continuous))
            }
            .padding(.top, 14)
        }
        .padding(.top, 56)
    }

    /// 오늘 복습 · 새 단어 (누르면 바로 그 학습)
    private var todayStats: some View {
        let due = dueWords.count
        return HStack(spacing: 0) {
            statButton(value: due, label: L("오늘 복습"), highlighted: due > 0) {
                if due > 0 { session = WordSessionConfig(words: dueWords, kind: .spaced) }
            }
            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 44)
            statButton(value: newCount, label: doneToday ? L("새 단어 완료") : L("새 단어"), highlighted: due == 0 && newCount > 0) {
                if newCount > 0 { session = WordSessionConfig(words: todayWords, kind: .daily) }
            }
        }
    }

    private func statButton(value: Int, label: String, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(highlighted ? Theme.accent : Palette.ink)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(value == 0)
    }

    /// 복습이 있으면 복습부터, 다음은 새 단어, 다 외웠으면 섞어서 다시
    private var startButton: some View {
        Button {
            if !dueWords.isEmpty {
                session = WordSessionConfig(words: dueWords, kind: .spaced)
            } else if !unlearned.isEmpty {
                session = WordSessionConfig(words: todayWords, kind: doneToday ? .extra : .daily)
            } else {
                session = WordSessionConfig(words: Array(deckWords.shuffled().prefix(wordGoal)), kind: .extra)
            }
        } label: {
            Text("학습 시작")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Theme.accent, in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.pressable)
    }

    private var menuRows: some View {
        VStack(spacing: 0) {
            if !deckWords.isEmpty {
                NavigationLink { ListenQuizView(pool: listenPool) } label: {
                    RowLabel(symbol: "ear", title: L("듣기 퀴즈"))
                }
                RowDivider()
                NavigationLink { SpeakPracticeView(pool: listenPool) } label: {
                    RowLabel(symbol: "mic", title: L("발음 연습"))
                }
                RowDivider()
            }
            addMenu {
                RowLabel(symbol: "plus", title: L("단어 추가"))
            }
            if !wrongWords.isEmpty {
                RowDivider()
                Button {
                    session = WordSessionConfig(words: wrongWords, kind: .review)
                } label: {
                    RowLabel(symbol: "arrow.counterclockwise", color: Palette.danger, title: L("틀린 단어"), value: "\(wrongWords.count)")
                }
            }
            if !starredWords.isEmpty {
                RowDivider()
                Button {
                    session = WordSessionConfig(words: starredWords, kind: .extra)
                } label: {
                    RowLabel(symbol: "bookmark", title: L("저장한 단어"), value: "\(starredWords.count)")
                }
            }
        }
        .buttonStyle(.pressable)
        .background(Palette.cardInset.opacity(0.6), in: .rect(cornerRadius: 24, style: .continuous))
    }

    private func addMenu<Content: View>(@ViewBuilder label: () -> Content) -> some View {
        let content = label()
        return Menu {
            Button { openScanner() } label: { Label("촬영", systemImage: "camera.fill") }
            Button { showPhotoPicker = true } label: { Label("앨범", systemImage: "photo.on.rectangle") }
            Button { showManualAdd = true } label: { Label("직접 입력", systemImage: "keyboard") }
        } label: {
            content
        }
        .tint(Palette.ink)
    }

    private func openScanner() {
        if DocumentScanner.isSupported {
            showScanner = true
        } else {
            errorMessage = L("이 기기는 스캔을 지원하지 않아요. 앨범에서 골라 주세요.")
        }
    }
}

struct WordSessionConfig: Identifiable {
    let id = UUID()
    let words: [Word]
    let kind: WordSessionView.Kind
}

/// 기록 + 설정 (하루 목표 · 발음)
private struct WordStatsSheet: View {
    let words: [Word]
    let title: String

    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.dailyWordGoal) private var wordGoal = 20
    @AppStorage(WordSpeaker.accentKey) private var accentRaw = WordSpeaker.Accent.us.rawValue

    private var nextReview: String {
        let upcoming = words.compactMap { word -> Date? in
            guard (1...WordReview.intervals.count).contains(word.reviewStage), let next = word.nextReviewAt, next > Date() else { return nil }
            return Calendar.current.startOfDay(for: next)
        }
        guard let first = upcoming.min() else { return L("없음") }
        return L("\(WordReview.describeL(first)) \(upcoming.filter { $0 == first }.count)개")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("전체", value: "\(words.count)")
                    LabeledContent("외움", value: "\(words.filter(\.isLearned).count)")
                    LabeledContent("완전히 외움", value: "\(words.filter(\.isMastered).count)")
                    LabeledContent("틀린 단어", value: "\(words.filter { $0.wrongCount > 0 }.count)")
                    LabeledContent("저장", value: "\(words.filter(\.isStarred).count)")
                    LabeledContent("다음 복습", value: nextReview)
                }
                Section {
                    Stepper(value: $wordGoal, in: 5...200, step: 5) {
                        LabeledContent("하루 목표", value: L("\(wordGoal)개"))
                    }
                    Picker("발음", selection: $accentRaw) {
                        ForEach(WordSpeaker.Accent.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
