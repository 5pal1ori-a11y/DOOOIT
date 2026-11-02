import PhotosUI
import SwiftData
import SwiftUI

/// 영어 단어 메인: 오늘 외울 단어 수, 학습 시작, 단어장 촬영
struct WordHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.createdAt) private var words: [Word]

    @AppStorage(SettingsKey.dailyWordGoal) private var wordGoal = 20
    @AppStorage(SettingsKey.wordGoalDoneKey) private var wordGoalDoneKey = ""
    @AppStorage(WordSpeaker.accentKey) private var accentRaw = WordSpeaker.Accent.us.rawValue

    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var importBatch: ImageBatch?
    @State private var showManualAdd = false
    @State private var session: WordSessionConfig?
    @State private var errorMessage: String?

    private var unlearned: [Word] { words.filter { !$0.isLearned } }
    private var wrongWords: [Word] { words.filter { $0.wrongCount > 0 } }
    private var doneToday: Bool { wordGoalDoneKey == Date().dayKey }
    private var todayWords: [Word] { Array(unlearned.prefix(wordGoal)) }
    /// 오늘 복습할 단어 (오래 기다린 것부터, 한 번에 최대 50개)
    private var dueWords: [Word] {
        Array(words.filter(\.isDueForReview).sorted { ($0.nextReviewAt ?? .distantPast) < ($1.nextReviewAt ?? .distantPast) }.prefix(50))
    }
    /// 가장 가까운 다음 복습 날
    private var nextReview: (date: Date, count: Int)? {
        let upcoming = words.compactMap { word -> Date? in
            guard (1...WordReview.intervals.count).contains(word.reviewStage), let next = word.nextReviewAt, next > Date() else { return nil }
            return Calendar.current.startOfDay(for: next)
        }
        guard let first = upcoming.min() else { return nil }
        return (first, upcoming.filter { $0 == first }.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                if words.contains(where: \.isLearned) { spacedCard }
                if !words.isEmpty { gamesCard }
                addCard
                if !wrongWords.isEmpty { reviewCard }
                goalCard
                listLink
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("영어 단어")
        .imageInput(showScanner: $showScanner, showPhotoPicker: $showPhotoPicker, photoItems: $photoItems, straighten: true) { images in
            importBatch = ImageBatch(images: images)
        }
        .sheet(item: $importBatch) { batch in
            WordImportView(images: batch.images)
        }
        .sheet(isPresented: $showManualAdd) {
            WordEditSheet(word: nil)
        }
        .fullScreenCover(item: $session) { config in
            WordSessionView(words: config.words, kind: config.kind)
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

    // MARK: 간격 복습

    private var spacedCard: some View {
        let due = dueWords
        let mastered = words.filter(\.isMastered).count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                IconBadge(symbol: "calendar.badge.clock", color: Palette.warning, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(due.isEmpty ? "오늘 복습 끝" : "오늘 복습 \(due.count)개")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    Text(due.isEmpty ? nextReviewText : "외운 단어를 1·3·7·14·30일 간격으로 다시 물어봐요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if mastered > 0 {
                    VStack(spacing: 0) {
                        Text("\(mastered)").font(.headline.monospacedDigit()).foregroundStyle(Palette.success)
                        Text("완전히 외움").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            if !due.isEmpty {
                Button {
                    session = WordSessionConfig(words: due, kind: .spaced)
                } label: {
                    Label("복습 시작", systemImage: "play.fill")
                }
                .buttonStyle(.primaryFill)
            }
        }
        .softCard()
    }

    private var nextReviewText: String {
        guard let next = nextReview else { return "다음 복습 일정이 없어요" }
        return "다음 복습: \(WordReview.describe(next.date)) \(next.count)개"
    }

    // MARK: Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(doneToday ? "오늘의 단어목표 성공!" : "지금 외워야 할 단어")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(doneToday ? 0 : todayWords.count)")
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.numericText())
                        Text("개").font(.title3.weight(.semibold))
                    }
                }
                Spacer()
                ZStack {
                    ProgressRing(progress: doneToday ? 1 : 0, lineWidth: 8,
                                 color: doneToday ? Palette.success : Theme.accent)
                    Image(systemName: doneToday ? "trophy.fill" : "target")
                        .font(.title2)
                        .foregroundStyle(doneToday ? Palette.success : Theme.accent)
                        .symbolEffect(.bounce, value: doneToday)
                }
                .frame(width: 70, height: 70)
            }

            if words.isEmpty {
                Text("아직 등록된 단어가 없어요. 단어장 사진을 찍으면 글자를 자동으로 읽어서 암기 노트를 만들어드려요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if unlearned.isEmpty {
                Text("등록된 단어를 모두 외웠어요! 새 단어장을 촬영해보세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                if words.isEmpty {
                    openScanner()
                } else if !unlearned.isEmpty {
                    session = WordSessionConfig(words: todayWords, kind: doneToday ? .extra : .daily)
                } else {
                    session = WordSessionConfig(words: Array(words.shuffled().prefix(wordGoal)), kind: .extra)
                }
            } label: {
                Label(primaryTitle, systemImage: words.isEmpty ? "camera.fill" : "play.fill")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .softCard(cornerRadius: 24, padding: 20)
    }

    private var primaryTitle: String {
        if words.isEmpty { return "단어장 촬영하기" }
        if unlearned.isEmpty { return "전체 단어 복습하기" }
        return doneToday ? "다음 단어 더 외우기" : "오늘의 단어 외우기"
    }

    // MARK: Pronunciation

    /// 발음 · 듣기: 따라 말하기 / 듣고 뜻 고르기 / 받아쓰기 + 미국식·영국식
    private var gamesCard: some View {
        let pool = words.filter { !$0.term.trimmingCharacters(in: .whitespaces).isEmpty }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "발음 · 듣기", symbol: "ear.fill")
                Spacer()
                Picker("발음", selection: $accentRaw) {
                    ForEach(WordSpeaker.Accent.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
            }
            VStack(spacing: 0) {
                NavigationLink { SpeakPracticeView(pool: pool) } label: {
                    RowLabel(symbol: "mic.fill", color: Palette.success, title: "따라 말하기", subtitle: "말하면 발음을 확인해요")
                }
                RowDivider()
                NavigationLink { ListenQuizView(pool: pool, mode: .meaning) } label: {
                    RowLabel(symbol: "ear.fill", color: Theme.accent, title: "듣고 뜻 고르기", subtitle: "발음을 듣고 4개 중에서")
                }
                RowDivider()
                NavigationLink { ListenQuizView(pool: pool, mode: .spelling) } label: {
                    RowLabel(symbol: "keyboard", color: Palette.warning, title: "받아쓰기", subtitle: "들린 단어의 철자 쓰기")
                }
            }
            .buttonStyle(.pressable)
            .background(Palette.card, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.06)))
        }
        .softCard()
    }

    // MARK: Add

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "단어 추가", symbol: "plus.circle.fill")
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    addButton(symbol: "doc.viewfinder", title: "촬영") { openScanner() }
                    addButton(symbol: "photo.on.rectangle", title: "앨범") { showPhotoPicker = true }
                    addButton(symbol: "keyboard", title: "직접 입력") { showManualAdd = true }
                }
            }
        }
        .softCard()
    }

    private func addButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title3.weight(.semibold))
                Text(title).font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accent.opacity(0.09), in: .rect(cornerRadius: 18))
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    private func openScanner() {
        if DocumentScanner.isSupported {
            showScanner = true
        } else {
            errorMessage = "이 기기에서는 카메라 스캔을 지원하지 않아요. 앨범에서 사진을 선택해주세요."
        }
    }

    // MARK: Review

    private var reviewCard: some View {
        Button {
            session = WordSessionConfig(words: wrongWords.sorted { $0.wrongCount > $1.wrongCount }, kind: .review)
        } label: {
            HStack(spacing: 14) {
                IconBadge(symbol: "arrow.counterclockwise", color: Palette.danger, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("틀린 단어 복습").font(.headline).foregroundStyle(Palette.ink)
                    Text("\(wrongWords.count)개의 단어를 다시 외워요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .softCard()
        }
        .buttonStyle(.pressable)
    }

    // MARK: Goal

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "하루 목표", symbol: "target")
            Stepper(value: $wordGoal, in: 5...200, step: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(wordGoal)").font(.title2.weight(.bold).monospacedDigit())
                    Text("개 / 하루").foregroundStyle(.secondary)
                }
            }
            Text("매일 정해진 개수만큼 새 단어를 외워요. 외우기 → 뜻 쓰기 → 단어 쓰기를 모두 통과하면 목표 성공!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .softCard()
    }

    private var listLink: some View {
        NavigationLink { WordListView() } label: {
            HStack {
                Label("전체 단어 목록", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(words.count)개").foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .softCard()
        }
        .buttonStyle(.pressable)
    }
}

struct WordSessionConfig: Identifiable {
    let id = UUID()
    let words: [Word]
    let kind: WordSessionView.Kind
}
