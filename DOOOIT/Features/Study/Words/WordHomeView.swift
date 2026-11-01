import PhotosUI
import SwiftData
import SwiftUI

/// 영어 단어 메인: 오늘 외울 단어 수, 학습 시작, 단어장 촬영
struct WordHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.createdAt) private var words: [Word]

    @AppStorage(SettingsKey.dailyWordGoal) private var wordGoal = 20
    @AppStorage(SettingsKey.wordGoalDoneKey) private var wordGoalDoneKey = ""

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard
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
        .imageInput(showScanner: $showScanner, showPhotoPicker: $showPhotoPicker, photoItems: $photoItems) { images in
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
        .glassCard(padding: 20)
    }

    private var primaryTitle: String {
        if words.isEmpty { return "단어장 촬영하기" }
        if unlearned.isEmpty { return "전체 단어 복습하기" }
        return doneToday ? "다음 단어 더 외우기" : "오늘의 단어 외우기"
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
        .glassCard()
    }

    private func addButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title3.weight(.semibold))
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
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
                    Text("틀린 단어 복습").font(.headline)
                    Text("\(wrongWords.count)개의 단어를 다시 외워요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .glassCard(interactive: true)
        }
        .buttonStyle(.plain)
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
        .glassCard()
    }

    private var listLink: some View {
        NavigationLink { WordListView() } label: {
            HStack {
                Label("전체 단어 목록", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                Text("\(words.count)개").foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .glassCard(interactive: true)
        }
        .buttonStyle(.plain)
    }
}

struct WordSessionConfig: Identifiable {
    let id = UUID()
    let words: [Word]
    let kind: WordSessionView.Kind
}
