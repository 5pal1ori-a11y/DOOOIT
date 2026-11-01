import SwiftData
import SwiftUI

enum LearnStep: String, CaseIterable, Identifiable, Codable {
    case concept, cloze, ox, problem, weak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .concept: return "개념"
        case .cloze: return "빈칸"
        case .ox: return "O/X"
        case .problem: return "문제"
        case .weak: return "취약"
        }
    }

    var longTitle: String {
        switch self {
        case .concept: return "개념 보기"
        case .cloze: return "빈칸 암기"
        case .ox: return "O/X 문제"
        case .problem: return "문제 풀기"
        case .weak: return "취약 복습"
        }
    }

    var symbol: String {
        switch self {
        case .concept: return "book.pages"
        case .cloze: return "rectangle.and.pencil.and.ellipsis"
        case .ox: return "circle.slash"
        case .problem: return "list.number"
        case .weak: return "arrow.counterclockwise.circle"
        }
    }
}

/// 틀린 문제 (취약 복습용)
struct WeakItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var prompt: String
    var answer: String
    var explanation: String
}

/// AI가 만든 자료를 SwiftData에 저장해 두고 재사용
@MainActor
enum ContentCache {
    static func key(_ subject: String, _ unit: String, _ kind: String, booster: Bool = false) -> String {
        "\(subject)|\(unit)|\(kind)|\(booster ? "b" : "s")"
    }

    static func load<T: Codable>(_ type: T.Type, key: String, context: ModelContext) -> T? {
        let descriptor = FetchDescriptor<StudyContent>(predicate: #Predicate { $0.key == key })
        guard let item = try? context.fetch(descriptor).first else { return nil }
        return try? JSONDecoder().decode(type, from: item.data)
    }

    static func save<T: Codable>(_ value: T, key: String, context: ModelContext) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let descriptor = FetchDescriptor<StudyContent>(predicate: #Predicate { $0.key == key })
        if let existing = try? context.fetch(descriptor).first {
            existing.data = data
            existing.createdAt = Date()
        } else {
            context.insert(StudyContent(key: key, data: data))
        }
        try? context.save()
    }
}

/// 단원 하나를 단계별로 학습: 개념 보기 → 빈칸 암기 → O/X → 문제 → 취약 복습
struct UnitStudyView: View {
    let subject: String
    let unit: String
    var booster: Bool = false
    var initialStep: LearnStep = .concept
    var completed: [String] = []
    var onStepDone: ((LearnStep) -> Void)? = nil

    @State private var step: LearnStep = .concept
    @State private var doneSteps: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            stepBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Group {
                        switch step {
                        case .concept: ConceptStepView(subject: subject, unit: unit, booster: booster, onDone: finish)
                        case .cloze: ClozeStepView(subject: subject, unit: unit, booster: booster, onDone: finish)
                        case .ox: OXStepView(subject: subject, unit: unit, booster: booster, onDone: finish)
                        case .problem: ProblemStepView(subject: subject, unit: unit, booster: booster, onDone: finish)
                        case .weak: WeakStepView(subject: subject, unit: unit, onDone: finish)
                        }
                    }
                    .id(step)
                    Text("AI가 만든 자료는 틀릴 수 있어요. 교과서와 함께 확인하세요.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background { AppBackground() }
        .navigationTitle(unit)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            step = initialStep
            doneSteps = Set(completed)
        }
    }

    private var stepBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(LearnStep.allCases) { item in
                    Button {
                        withAnimation(.snappy) { step = item }
                    } label: {
                        HStack(spacing: 4) {
                            if doneSteps.contains(item.rawValue) {
                                Image(systemName: "checkmark").font(.caption2.weight(.heavy))
                            }
                            Text(item.longTitle)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(step == item ? Theme.accent : Color.secondary)
                        .background(step == item ? Theme.accent.opacity(0.14) : Color.clear, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    if item != LearnStep.allCases.last {
                        Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 10, height: 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
    }

    private func finish(_ finished: LearnStep) {
        doneSteps.insert(finished.rawValue)
        onStepDone?(finished)
        if let index = LearnStep.allCases.firstIndex(of: finished), index + 1 < LearnStep.allCases.count {
            withAnimation(.snappy) { step = LearnStep.allCases[index + 1] }
        }
    }
}

// MARK: - 공통: AI 자료 불러오기

struct AIContentLoader<T: Codable, Content: View>: View {
    let cacheKey: String
    /// 크레딧을 받는 단위 (단원). 같은 단원의 다른 단계는 추가 차감 없음
    var creditKey: String? = nil
    let make: () async throws -> T
    @ViewBuilder var content: (T, _ regenerate: @escaping () -> Void) -> Content

    @Environment(\.modelContext) private var context
    @Environment(CreditStore.self) private var credits
    @State private var value: T?
    @State private var needCredits = false
    @State private var needConfirm = false
    @State private var loading = false
    @State private var error: String?
    @State private var startedAt = Date()
    @State private var generation: Task<Void, Never>?

    var body: some View {
        Group {
            if let value {
                content(value) { Task { await load(force: true) } }
            } else if needCredits {
                NotEnoughCreditsView()
                    .padding(.vertical, 20)
            } else if needConfirm, let creditKey {
                confirmCard(creditKey)
            } else if let error {
                VStack(spacing: 12) {
                    Text(error).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("다시 시도") { Task { await load(force: true) } }
                        .buttonStyle(.glass)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // 처음부터 이 화면을 보여줘야 .task가 실행됨 (빈 화면이면 시작되지 않음)
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text("두잇 AI가 자료를 찾아서 만들고 있어요").font(.subheadline.weight(.semibold))
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(loading ? "\(Int(context.date.timeIntervalSince(startedAt)))초째 만드는 중 · 보통 몇 초면 돼요" : "준비 중")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            }
        }
        .task { await load(force: false) }
        .onDisappear { generation?.cancel() }
        .onChange(of: credits.balance) {
            if needCredits && credits.canAfford() {
                needCredits = false
                Task { await load(force: false) }
            }
        }
    }

    /// 단원 첫 학습 전에 크레딧 사용을 물어봄
    private func confirmCard(_ key: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            VStack(spacing: 6) {
                Text("크레딧이 사용돼요").font(.headline)
                Text(credits.confirmText("이 단원을 AI로 학습하면"))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Text("같은 단원의 개념·빈칸·O/X·문제는 추가로 차감되지 않아요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                credits.confirmUnit(key)
                Task { await load(force: false) }
            } label: {
                Text("진행 (\(CreditStore.costPerUse) 크레딧)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(.vertical, 20)
    }

    private func load(force: Bool) async {
        if !force, let cached = ContentCache.load(T.self, key: cacheKey, context: context) {
            value = cached
            return
        }
        if let creditKey, !credits.isUnitConfirmed(creditKey) {
            if credits.canAfford() {
                needCredits = false
                needConfirm = true
            } else {
                needCredits = true
            }
            return
        }
        needCredits = false
        needConfirm = false
        generation?.cancel()
        loading = true
        error = nil
        value = nil
        startedAt = Date()

        let work = Task { @MainActor in
            do {
                let made = try await make()
                guard !Task.isCancelled else { return }
                ContentCache.save(made, key: cacheKey, context: context)
                if let creditKey { credits.chargeUnit(creditKey) }
                value = made
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
            loading = false
        }
        generation = work

        // 90초가 지나도 안 끝나면 멈추고 다시 시도할 수 있게
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(90))
            if loading && value == nil && error == nil {
                work.cancel()
                loading = false
                error = "시간이 너무 오래 걸려서 멈췄어요. 다시 시도해주세요.\n(기기가 뜨겁거나 저전력 모드면 느려질 수 있어요)"
            }
        }
    }
}

@MainActor
private func record(_ context: ModelContext, subject: String, unit: String, step: LearnStep, correct: Int, total: Int) {
    guard total > 0 else { return }
    context.insert(QuizRecord(subject: subject, unit: unit, step: step.rawValue, correct: correct, total: total))
    try? context.save()
}

@MainActor
private func saveWeak(_ items: [WeakItem], subject: String, unit: String, context: ModelContext) {
    let key = ContentCache.key(subject, unit, "weak")
    var existing = ContentCache.load([WeakItem].self, key: key, context: context) ?? []
    for item in items where !existing.contains(where: { $0.prompt == item.prompt }) {
        existing.append(item)
    }
    ContentCache.save(existing, key: key, context: context)
}

@MainActor
private func primaryButton(_ title: String, symbol: String = "arrow.right", action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Label(title, systemImage: symbol)
            .font(.body.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 40)
    }
    .buttonStyle(.glassProminent)
    .controlSize(.large)
}

// MARK: - 1. 개념 보기

struct ConceptStepView: View {
    let subject: String
    let unit: String
    let booster: Bool
    var onDone: (LearnStep) -> Void

    var body: some View {
        AIContentLoader(cacheKey: ContentCache.key(subject, unit, "concept", booster: booster), creditKey: "\(subject)|\(unit)") {
            try await DoitTutor.concept(subject: subject, unit: unit, booster: booster)
        } content: { note, regenerate in
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("\(subject) · \(note.title)", systemImage: "book.pages").font(.headline)
                    Spacer()
                    Button(action: regenerate) { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("다시 만들기")
                }
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(note.keyPoints.enumerated()), id: \.offset) { index, point in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Theme.accent, in: .circle)
                            Text(point).font(.body).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label("예시", systemImage: "lightbulb.fill").font(.subheadline.weight(.bold)).foregroundStyle(Palette.warning)
                    Text(note.example).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.warning.opacity(0.12), in: .rect(cornerRadius: 16))

                primaryButton("다 읽었어요 · 빈칸 암기로") { onDone(.concept) }
            }
        }
    }
}

// MARK: - 2. 빈칸 암기

struct ClozeStepView: View {
    let subject: String
    let unit: String
    let booster: Bool
    var onDone: (LearnStep) -> Void

    @Environment(\.modelContext) private var context
    @State private var answers: [Int: String] = [:]
    @State private var checked = false

    var body: some View {
        AIContentLoader(cacheKey: ContentCache.key(subject, unit, "cloze", booster: booster), creditKey: "\(subject)|\(unit)") {
            try await DoitTutor.cloze(subject: subject, unit: unit, count: booster ? 4 : 6)
        } content: { set, regenerate in
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("빈칸에 들어갈 말을 적어보세요").font(.headline)
                    Spacer()
                    Button { answers = [:]; checked = false; regenerate() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("새 문제")
                }
                ForEach(Array(set.items.enumerated()), id: \.offset) { index, item in
                    let ok = AnswerChecker.checkMeaning(answers[index] ?? "", answer: item.answer)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(index + 1). \(item.sentence)").fixedSize(horizontal: false, vertical: true)
                        HStack {
                            TextField("정답", text: Binding(get: { answers[index] ?? "" }, set: { answers[index] = $0 }))
                                .textInputAutocapitalization(.never)
                                .disabled(checked)
                            if checked {
                                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(ok ? Palette.success : Palette.danger)
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
                        if checked && !ok {
                            Text("정답: \(item.answer)").font(.caption.weight(.semibold)).foregroundStyle(Palette.danger)
                        }
                    }
                }
                if checked {
                    let score = set.items.indices.filter { AnswerChecker.checkMeaning(answers[$0] ?? "", answer: set.items[$0].answer) }.count
                    Text("\(set.items.count)문제 중 \(score)개 맞았어요").font(.headline)
                    primaryButton("O/X 문제로") { onDone(.cloze) }
                } else {
                    primaryButton("채점하기", symbol: "checkmark") {
                        checked = true
                        let wrong = set.items.indices.filter { !AnswerChecker.checkMeaning(answers[$0] ?? "", answer: set.items[$0].answer) }
                        record(context, subject: subject, unit: unit, step: .cloze, correct: set.items.count - wrong.count, total: set.items.count)
                        saveWeak(wrong.map { WeakItem(prompt: set.items[$0].sentence, answer: set.items[$0].answer, explanation: "") }, subject: subject, unit: unit, context: context)
                    }
                }
            }
        }
    }
}

// MARK: - 3. O/X

struct OXStepView: View {
    let subject: String
    let unit: String
    let booster: Bool
    var onDone: (LearnStep) -> Void

    @Environment(\.modelContext) private var context
    @State private var index = 0
    @State private var picked: Bool?
    @State private var correct = 0
    @State private var wrongs: [WeakItem] = []
    @State private var finished = false

    var body: some View {
        AIContentLoader(cacheKey: ContentCache.key(subject, unit, "ox", booster: booster), creditKey: "\(subject)|\(unit)") {
            try await DoitTutor.ox(subject: subject, unit: unit, count: booster ? 4 : 6)
        } content: { set, regenerate in
            if finished || set.items.isEmpty {
                resultView(total: set.items.count) { index = 0; correct = 0; wrongs = []; picked = nil; finished = false; regenerate() }
            } else {
                let item = set.items[min(index, set.items.count - 1)]
                VStack(alignment: .leading, spacing: 18) {
                    Text("\(index + 1) / \(set.items.count)").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Text(item.statement)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .glassEffect(.regular, in: .rect(cornerRadius: 22))
                    HStack(spacing: 14) {
                        oxButton(true, item: item)
                        oxButton(false, item: item)
                    }
                    if let picked {
                        let ok = picked == item.isTrue
                        VStack(alignment: .leading, spacing: 6) {
                            Label(ok ? "맞았어요!" : "틀렸어요 · 정답은 \(item.isTrue ? "O" : "X")", systemImage: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(ok ? Palette.success : Palette.danger)
                            Text(item.explanation).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((ok ? Palette.success : Palette.danger).opacity(0.12), in: .rect(cornerRadius: 16))
                        primaryButton(index + 1 < set.items.count ? "다음" : "결과 보기") {
                            if index + 1 < set.items.count {
                                index += 1
                                self.picked = nil
                            } else {
                                finished = true
                                record(context, subject: subject, unit: unit, step: .ox, correct: correct, total: set.items.count)
                                saveWeak(wrongs, subject: subject, unit: unit, context: context)
                            }
                        }
                    }
                }
            }
        }
    }

    private func oxButton(_ value: Bool, item: OXItem) -> some View {
        Button {
            guard picked == nil else { return }
            picked = value
            if value == item.isTrue {
                correct += 1
                Haptics.success()
            } else {
                wrongs.append(WeakItem(prompt: item.statement, answer: item.isTrue ? "O" : "X", explanation: item.explanation))
                Haptics.error()
            }
        } label: {
            Image(systemName: value ? "circle" : "xmark")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(value ? Palette.success : Palette.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 76)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .opacity(picked == nil || picked == value ? 1 : 0.4)
    }

    private func resultView(total: Int, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            Text("\(total)문제 중 \(correct)개 맞았어요").font(.title3.weight(.bold))
            if !wrongs.isEmpty {
                Text("틀린 \(wrongs.count)문제는 취약 복습에 모아뒀어요").font(.subheadline).foregroundStyle(.secondary)
            }
            primaryButton("문제 풀기로") { onDone(.ox) }
            Button("새 O/X 문제 받기", action: retry).font(.subheadline)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 4. 문제 풀기 (5지선다 + 단계별 풀이)

struct ProblemStepView: View {
    let subject: String
    let unit: String
    let booster: Bool
    var onDone: (LearnStep) -> Void

    @Environment(\.modelContext) private var context
    @State private var index = 0
    @State private var picked: Int?
    @State private var correct = 0
    @State private var wrongs: [WeakItem] = []
    @State private var finished = false
    @State private var showSteps = false

    var body: some View {
        AIContentLoader(cacheKey: ContentCache.key(subject, unit, "problem", booster: booster), creditKey: "\(subject)|\(unit)") {
            try await DoitTutor.problems(subject: subject, unit: unit, count: booster ? 3 : 4, hard: !booster)
        } content: { set, regenerate in
            if finished || set.items.isEmpty {
                VStack(spacing: 14) {
                    Text("\(set.items.count)문제 중 \(correct)개 맞았어요").font(.title3.weight(.bold))
                    primaryButton("취약 복습으로") { onDone(.problem) }
                    Button("새 문제 받기") { index = 0; correct = 0; wrongs = []; picked = nil; finished = false; regenerate() }
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
            } else {
                let item = set.items[min(index, set.items.count - 1)]
                VStack(alignment: .leading, spacing: 14) {
                    Text("문제 \(index + 1) / \(set.items.count)").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Text(item.question).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    ForEach(Array(item.choices.prefix(5).enumerated()), id: \.offset) { choiceIndex, choice in
                        let number = choiceIndex + 1
                        Button {
                            guard picked == nil else { return }
                            picked = number
                            if number == item.answerNumber { correct += 1; Haptics.success() } else {
                                Haptics.error()
                                wrongs.append(WeakItem(prompt: item.question, answer: "\(item.answerNumber)번 · \(item.finalAnswer)", explanation: item.steps.joined(separator: "\n")))
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(number)")
                                    .font(.subheadline.weight(.bold))
                                    .frame(width: 28, height: 28)
                                    .background(choiceColor(number, answer: item.answerNumber).opacity(0.18), in: .circle)
                                Text(choice).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14).stroke(choiceColor(number, answer: item.answerNumber), lineWidth: picked == nil ? 0 : 1.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if picked != nil {
                        DisclosureGroup(isExpanded: $showSteps) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(item.steps.enumerated()), id: \.offset) { stepIndex, line in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(stepIndex + 1)단계 풀이")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Theme.accent, in: .rect(cornerRadius: 6))
                                        Text(line).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Text("최종 답: \(item.finalAnswer)").font(.headline)
                            }
                            .padding(.top, 8)
                        } label: {
                            Label("단계별 풀이 보기", systemImage: "lightbulb.fill").font(.subheadline.weight(.bold))
                        }
                        .padding(14)
                        .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 16))

                        primaryButton(index + 1 < set.items.count ? "다음 문제" : "결과 보기") {
                            showSteps = false
                            if index + 1 < set.items.count {
                                index += 1
                                picked = nil
                            } else {
                                finished = true
                                record(context, subject: subject, unit: unit, step: .problem, correct: correct, total: set.items.count)
                                saveWeak(wrongs, subject: subject, unit: unit, context: context)
                            }
                        }
                    }
                }
            }
        }
    }

    private func choiceColor(_ number: Int, answer: Int) -> Color {
        guard let picked else { return Theme.accent }
        if number == answer { return Palette.success }
        if number == picked { return Palette.danger }
        return .clear
    }
}

// MARK: - 5. 취약 복습

struct WeakStepView: View {
    let subject: String
    let unit: String
    var onDone: (LearnStep) -> Void

    @Environment(\.modelContext) private var context
    @State private var items: [WeakItem] = []
    @State private var revealed: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("틀렸던 문제를 다시 확인해요").font(.headline)
            if items.isEmpty {
                Label("아직 틀린 문제가 없어요. 빈칸·O/X·문제 단계를 먼저 풀어보세요.", systemImage: "checkmark.seal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.prompt).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    if revealed.contains(item.id) {
                        Text("정답: \(item.answer)").font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent)
                        if !item.explanation.isEmpty {
                            Text(item.explanation).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Button("이제 알아요 · 목록에서 빼기") { remove(item) }.font(.caption.weight(.semibold))
                    } else {
                        Button("정답 확인") { revealed.insert(item.id) }.font(.caption.weight(.semibold))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.danger.opacity(0.07), in: .rect(cornerRadius: 16))
            }
            primaryButton("이 단원 학습 완료", symbol: "checkmark") { onDone(.weak) }
        }
        .onAppear { items = ContentCache.load([WeakItem].self, key: ContentCache.key(subject, unit, "weak"), context: context) ?? [] }
    }

    private func remove(_ item: WeakItem) {
        items.removeAll { $0.id == item.id }
        ContentCache.save(items, key: ContentCache.key(subject, unit, "weak"), context: context)
    }
}
