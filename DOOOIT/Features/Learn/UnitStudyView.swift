import SwiftData
import SwiftUI

enum LearnStep: String, CaseIterable, Identifiable, Codable {
    case concept, cloze, ox, problem, weak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .concept: return L("개념")
        case .cloze: return L("빈칸")
        case .ox: return "O/X"
        case .problem: return L("문제")
        case .weak: return L("취약")
        }
    }

    var longTitle: String {
        switch self {
        case .concept: return L("개념 보기")
        case .cloze: return L("빈칸 암기")
        case .ox: return L("O/X 문제")
        case .problem: return L("문제 풀기")
        case .weak: return L("취약 복습")
        }
    }

    var symbol: String {
        switch self {
        case .concept: return "book.pages"
        case .cloze: return "pencil"
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
    /// 학습 자료 형식 버전: 검증 단계를 추가하면서 v2로 (예전 자료는 지우지 않고 새로 만듦, 취약 복습 목록은 그대로)
    static let version = "v2"

    static func key(_ subject: String, _ unit: String, _ kind: String, booster: Bool = false) -> String {
        let base = "\(subject)|\(unit)|\(kind)|\(booster ? "b" : "s")"
        // 개념 정리는 원리·실수·확인 문제를 더하면서 새로 만듦 (예전 자료는 지우지 않음)
        if kind == "concept" { return base + "|" + version + "|x1" }
        return kind == "weak" ? base : base + "|" + version
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
/// 끝낸 단계는 저장돼서 다음에 열면 이어서 해요
struct UnitStudyView: View {
    let subject: String
    let unit: String
    var booster: Bool = false
    var initialStep: LearnStep = .concept
    var completed: [String] = []
    var onStepDone: ((LearnStep) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @State private var step: LearnStep = .concept
    @State private var doneSteps: Set<String> = []
    @State private var showComplete = false
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            stepBar
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if showComplete {
                        completeCard
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if DoitStudy.isFree(subject) {
                        // 교과서 자료 없이 모델이 만든 내용
                        Label("AI가 만든 내용 · 틀릴 수 있어요", systemImage: "info.circle")
                            .font(.pt(.caption).weight(.semibold))
                            .foregroundStyle(Palette.warning)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Palette.warning.opacity(0.12), in: .capsule)
                        FreeStudyOption(start: nil)
                    }
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
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                }
                .padding(20)
                .padding(.bottom, 40)
                .animation(Motion.spring, value: step)
                .animation(Motion.spring, value: showComplete)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background { AppBackground() }
        .navigationTitle(unit)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let saved = LearnProgress.load(subject: subject, unit: unit, context: context)
            doneSteps = Set(completed).union(saved?.done ?? [])
            // 따로 정한 단계가 없으면 아직 안 한 첫 단계부터
            if initialStep != .concept {
                step = initialStep
            } else {
                step = LearnStep.allCases.first { !doneSteps.contains($0.rawValue) } ?? .concept
            }
        }
    }

    /// 번호 동그라미 5개를 선으로 이은 단계 표시 (끝낸 단계는 ✓)
    private var stepBar: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(LearnStep.allCases.enumerated()), id: \.element) { index, item in
                let isDone = doneSteps.contains(item.rawValue)
                let isCurrent = step == item
                Button {
                    withAnimation(Motion.spring) { step = item }
                    Haptics.tap()
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(isCurrent ? Theme.accent : (isDone ? Theme.accent.opacity(0.14) : Palette.card))
                            Circle()
                                .strokeBorder(isCurrent || isDone ? Color.clear : Color.primary.opacity(0.12), lineWidth: 1.5)
                            if isDone && !isCurrent {
                                Image(systemName: "checkmark").font(.pt(.caption).weight(.heavy)).foregroundStyle(Theme.accent)
                            } else {
                                Text("\(index + 1)")
                                    .font(.pt(.subheadline).weight(.bold))
                                    .foregroundStyle(isCurrent ? Color.white : Color.secondary)
                            }
                        }
                        .frame(width: 32, height: 32)
                        Text(item.title)
                            .font(.pt(.caption2).weight(isCurrent ? .bold : .medium))
                            .foregroundStyle(isCurrent ? Palette.ink : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(index + 1)단계 \(item.longTitle)\(isDone ? L(", 완료") : "")")
                .background(alignment: .top) {
                    // 옆 단계와 잇는 선
                    if index < LearnStep.allCases.count - 1 {
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(isDone ? Theme.accent.opacity(0.4) : Color.primary.opacity(0.1))
                                .frame(width: proxy.size.width - 40, height: 2)
                                .offset(x: proxy.size.width / 2 + 20, y: 15)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Palette.card.opacity(0.7))
        .overlay(alignment: .bottom) { Divider() }
    }

    /// 다섯 단계를 다 끝냈을 때: 다음 단원으로 / 처음부터 다시
    private var completeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.pt(.title2))
                    .foregroundStyle(Palette.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text("단원 학습 완료").font(.pt(.headline)).foregroundStyle(Palette.ink)
                    Text(unit).font(.pt(.subheadline)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            HStack(spacing: 10) {
                if let next = LearnProgress.nextUnit(after: unit, subject: subject) {
                    NavigationLink {
                        UnitStudyView(subject: subject, unit: next)
                    } label: {
                        Label("다음 단원: \(next)", systemImage: "arrow.right")
                            .lineLimit(1)
                    }
                    .buttonStyle(.primaryFill)
                }
                Button {
                    withAnimation(Motion.spring) {
                        showComplete = false
                        step = .concept
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.pt(.headline))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 52, height: 52)
                        .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("처음부터 다시")
            }
        }
        .softCard(cornerRadius: 22, padding: 18)
    }

    private func finish(_ finished: LearnStep) {
        doneSteps.insert(finished.rawValue)
        LearnProgress.mark(finished, subject: subject, unit: unit, context: context)
        onStepDone?(finished)
        let all = LearnStep.allCases
        if all.allSatisfy({ doneSteps.contains($0.rawValue) }) {
            Haptics.celebrate()
            withAnimation(Motion.spring) { showComplete = true }
            if finished != .weak, let index = all.firstIndex(of: finished), index + 1 < all.count {
                withAnimation(Motion.spring) { step = all[index + 1] }
            }
            return
        }
        // 이 단계 뒤에서 아직 안 한 단계, 없으면 앞에서 빠뜨린 단계로
        let index = all.firstIndex(of: finished) ?? 0
        let next = all[(index + 1)...].first { !doneSteps.contains($0.rawValue) } ?? all.first { !doneSteps.contains($0.rawValue) }
        if let next { withAnimation(Motion.spring) { step = next } }
    }
}

// MARK: - 공통: AI 자료 불러오기

struct AIContentLoader<T: Codable, Content: View>: View {
    let cacheKey: String
    let make: () async throws -> T
    @ViewBuilder var content: (T, _ regenerate: @escaping () -> Void) -> Content

    @Environment(\.modelContext) private var context
    @State private var value: T?
    @State private var loading = false
    @State private var error: String?
    @State private var startedAt = Date()
    @State private var generation: Task<Void, Never>?

    var body: some View {
        Group {
            if let value {
                content(value) { Task { await load(force: true) } }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if let error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.pt(size: 30, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 64, height: 64)
                        .background(Theme.accent.opacity(0.12), in: .circle)
                    Text(error).font(.pt(.subheadline)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("다시 시도") { Task { await load(force: true) } }
                        .buttonStyle(.glass)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // 처음부터 이 화면을 보여줘야 .task가 실행됨 (빈 화면이면 시작되지 않음)
                VStack(spacing: 12) {
                    Image(systemName: "lightbulb")
                        .font(.pt(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Theme.accent, in: .circle)
                    Text("모티 AI가 학습 자료를 만들고 있어요").font(.pt(.subheadline).weight(.semibold)).foregroundStyle(Palette.ink)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(loading ? L("\(Int(context.date.timeIntervalSince(startedAt)))초째 만드는 중 · 보통 몇 초면 돼요") : L("준비 중"))
                            .font(.pt(.caption))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            }
        }
        .animation(Motion.spring, value: value == nil)
        .task { await load(force: false) }
        .onDisappear { generation?.cancel() }
    }

    private func load(force: Bool) async {
        if !force, let cached = ContentCache.load(T.self, key: cacheKey, context: context) {
            value = cached
            return
        }
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
            try? await Task.sleep(for: .seconds(150))
            if loading && value == nil && error == nil {
                work.cancel()
                loading = false
                error = L("시간이 너무 오래 걸려서 멈췄어요. 다시 시도해주세요.\n(기기가 뜨겁거나 저전력 모드면 느려질 수 있어요)")
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
            .font(.pt(.body).weight(.bold))
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
        AIContentLoader(cacheKey: ContentCache.key(subject, unit, "concept", booster: booster)) {
            try await DoitTutor.concept(subject: subject, unit: unit, booster: booster)
        } content: { note, regenerate in
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(note.scope.isEmpty ? "\(subject) · \(note.title)" : note.scope, systemImage: "book.pages")
                        .font(.pt(.headline))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Button(action: regenerate) { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("다시 만들기")
                }
                if !note.checks.isEmpty {
                    // 통과한 검증
                    HStack(spacing: 6) {
                        ForEach(note.checks, id: \.self) { check in
                            Label(check, systemImage: "checkmark.seal.fill")
                                .font(.pt(.caption2).weight(.semibold))
                                .foregroundStyle(Palette.success)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Palette.success.opacity(0.1), in: .capsule)
                        }
                    }
                }
                if !note.summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("핵심 개념", systemImage: "star.fill").font(.pt(.subheadline).weight(.bold)).foregroundStyle(Theme.accent)
                        Text(note.summary).font(.pt(.body)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 14))
                }
                if !note.details.isEmpty {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(note.details.enumerated()), id: \.offset) { _, detail in
                                Text(detail).font(.pt(.subheadline)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Label("자세히 알아보기", systemImage: "book.closed").font(.pt(.subheadline).weight(.bold))
                    }
                    .padding(14)
                    .background(Palette.card, in: .rect(cornerRadius: 14))
                }
                Text("핵심 학습 포인트").font(.pt(.subheadline).weight(.bold)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(note.keyPoints.enumerated()), id: \.offset) { index, point in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.pt(.caption).weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Theme.accent, in: .circle)
                            Text(point)
                                .font(.pt(.body))
                                .foregroundStyle(Palette.ink)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .appearAnimation(delay: Double(index) * 0.06)
                    }
                }
                .softCard()
                if !note.example.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("예제", systemImage: "lightbulb.fill").font(.pt(.subheadline).weight(.bold)).foregroundStyle(Palette.warning)
                        Text(note.example).font(.pt(.subheadline)).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.warning.opacity(0.12), in: .rect(cornerRadius: 14))
                    .appearAnimation(delay: 0.3)
                }
                if !note.principles.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("왜 그럴까요?", systemImage: "questionmark.bubble.fill").font(.pt(.subheadline).weight(.bold)).foregroundStyle(Theme.accent)
                        ForEach(Array(note.principles.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.pt(.subheadline)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 14))
                }
                if !note.mistakes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("자주 하는 실수", systemImage: "exclamationmark.triangle.fill").font(.pt(.subheadline).weight(.bold)).foregroundStyle(Palette.warning)
                        ForEach(Array(note.mistakes.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.pt(.subheadline)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.warning.opacity(0.12), in: .rect(cornerRadius: 14))
                }
                if !note.checkQuestion.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("확인 문제", systemImage: "checkmark.circle.fill").font(.pt(.subheadline).weight(.bold)).foregroundStyle(Palette.success)
                        Text(note.checkQuestion).font(.pt(.subheadline)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                        if !note.checkAnswer.isEmpty {
                            DisclosureGroup("정답 보기") {
                                Text(note.checkAnswer).font(.pt(.subheadline)).foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 4)
                            }
                            .font(.pt(.subheadline).weight(.semibold))
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.success.opacity(0.1), in: .rect(cornerRadius: 14))
                }
                if !note.sources.isEmpty {
                    Label("근거: " + note.sources.joined(separator: " · "), systemImage: "books.vertical")
                        .font(.pt(.caption2))
                        .foregroundStyle(.secondary)
                }

                primaryButton(L("다 읽었어요 · 빈칸 암기로")) { onDone(.concept) }
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
        AIContentLoader(cacheKey: ContentCache.key(subject, unit, "cloze", booster: booster)) {
            try await DoitTutor.cloze(subject: subject, unit: unit, count: booster ? 4 : 6)
        } content: { set, regenerate in
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("빈칸에 들어갈 말을 적어보세요").font(.pt(.headline))
                    Spacer()
                    Button { answers = [:]; checked = false; regenerate() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("새 문제")
                }
                ForEach(Array(set.items.enumerated()), id: \.offset) { index, item in
                    let ok = DoitStudy.clozeMatches(answers[index] ?? "", answer: item.answer)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(index + 1). \(item.sentence)").fixedSize(horizontal: false, vertical: true)
                        HStack {
                            TextField("정답", text: Binding(get: { answers[index] ?? "" }, set: { answers[index] = $0 }))
                                .textInputAutocapitalization(.never)
                                .disabled(checked)
                            if checked {
                                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(ok ? Palette.success : Palette.danger)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
                        .feedbackGlow(checked ? ok : nil, cornerRadius: 12)
                        .shake(trigger: checked && !ok)
                        if checked && !ok {
                            Text("정답: \(item.answer)").font(.pt(.caption).weight(.semibold)).foregroundStyle(Palette.danger)
                        }
                    }
                }
                if checked {
                    let score = set.items.indices.filter { DoitStudy.clozeMatches(answers[$0] ?? "", answer: set.items[$0].answer) }.count
                    ResultSummaryCard(correct: score, total: set.items.count)
                    primaryButton(L("O/X 문제로")) { onDone(.cloze) }
                } else {
                    primaryButton(L("채점하기"), symbol: "checkmark") {
                        withAnimation(Motion.spring) { checked = true }
                        let wrong = set.items.indices.filter { !DoitStudy.clozeMatches(answers[$0] ?? "", answer: set.items[$0].answer) }
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
        AIContentLoader(cacheKey: ContentCache.key(subject, unit, "ox", booster: booster)) {
            try await DoitTutor.ox(subject: subject, unit: unit, count: booster ? 4 : 6)
        } content: { set, regenerate in
            if finished || set.items.isEmpty {
                resultView(total: set.items.count) { index = 0; correct = 0; wrongs = []; picked = nil; finished = false; regenerate() }
            } else {
                let item = set.items[min(index, set.items.count - 1)]
                VStack(alignment: .leading, spacing: 18) {
                    Text("\(index + 1) / \(set.items.count)").font(.pt(.caption).weight(.bold)).foregroundStyle(.secondary)
                    Text(item.statement)
                        .font(.pt(.title3).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(Palette.ink)
                        .softCard(cornerRadius: 22, padding: 20)
                        .feedbackGlow(picked.map { $0 == item.isTrue }, cornerRadius: 22)
                        .shake(trigger: picked != nil && picked != item.isTrue)
                        .id(index)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    HStack(spacing: 14) {
                        oxButton(true, item: item)
                        oxButton(false, item: item)
                    }
                    if let picked {
                        let ok = picked == item.isTrue
                        VStack(alignment: .leading, spacing: 6) {
                            Label(ok ? L("맞았어요!") : L("틀렸어요 · 정답은 \(item.isTrue ? "O" : "X")"), systemImage: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.pt(.headline))
                                .foregroundStyle(ok ? Palette.success : Palette.danger)
                            Text(item.explanation).font(.pt(.subheadline)).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((ok ? Palette.success : Palette.danger).opacity(0.12), in: .rect(cornerRadius: 14))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        primaryButton(index + 1 < set.items.count ? L("다음") : L("결과 보기")) {
                            if index + 1 < set.items.count {
                                withAnimation(Motion.spring) {
                                    index += 1
                                    self.picked = nil
                                }
                            } else {
                                withAnimation(Motion.spring) { finished = true }
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
            withAnimation(Motion.bouncy) { picked = value }
            if value == item.isTrue {
                correct += 1
                Haptics.success()
            } else {
                wrongs.append(WeakItem(prompt: item.statement, answer: item.isTrue ? "O" : "X", explanation: item.explanation))
                Haptics.error()
            }
        } label: {
            Image(systemName: value ? "circle" : "xmark")
                .font(.pt(size: 34, weight: .heavy))
                .foregroundStyle(value ? Palette.success : Palette.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 76)
        }
        .buttonStyle(.plain)
        .background((value ? Palette.success : Palette.danger).opacity(0.08), in: .rect(cornerRadius: 14))
        .background(Palette.card, in: .rect(cornerRadius: 14))
        .opacity(picked == nil || picked == value ? 1 : 0.4)
        .scaleEffect(picked == value ? 1.04 : 1)
        .animation(Motion.bouncy, value: picked)
    }

    private func resultView(total: Int, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            ResultSummaryCard(correct: correct, total: total)
            if !wrongs.isEmpty {
                Text("틀린 \(wrongs.count)문제는 취약 복습에 모아뒀어요").font(.pt(.subheadline)).foregroundStyle(.secondary)
            }
            primaryButton(L("문제 풀기로")) { onDone(.ox) }
            Button("새 O/X 문제 받기", action: retry).font(.pt(.subheadline))
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
    @State private var savedToNotes: Set<String> = []

    var body: some View {
        AIContentLoader(cacheKey: ContentCache.key(subject, unit, "problem", booster: booster)) {
            try await DoitTutor.problems(subject: subject, unit: unit, count: booster ? 3 : 4, hard: !booster)
        } content: { set, regenerate in
            if finished || set.items.isEmpty {
                VStack(spacing: 14) {
                    ResultSummaryCard(correct: correct, total: set.items.count)
                    primaryButton(L("취약 복습으로")) { onDone(.problem) }
                    Button("새 문제 받기") { index = 0; correct = 0; wrongs = []; picked = nil; finished = false; regenerate() }
                        .font(.pt(.subheadline))
                }
                .frame(maxWidth: .infinity)
            } else {
                let item = set.items[min(index, set.items.count - 1)]
                VStack(alignment: .leading, spacing: 14) {
                    Text("문제 \(index + 1) / \(set.items.count)").font(.pt(.caption).weight(.bold)).foregroundStyle(.secondary)
                    Text(item.question)
                        .font(.pt(.body).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .softCard(cornerRadius: 20, padding: 16)
                        .shake(trigger: picked != nil && picked != item.answerNumber)
                        .id(index)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    ForEach(Array(item.choices.prefix(5).enumerated()), id: \.offset) { choiceIndex, choice in
                        let number = choiceIndex + 1
                        Button {
                            guard picked == nil else { return }
                            withAnimation(Motion.bouncy) { picked = number }
                            if number == item.answerNumber { correct += 1; Haptics.success() } else {
                                Haptics.error()
                                wrongs.append(WeakItem(prompt: item.question, answer: "\(item.answerNumber)번 · \(item.finalAnswer)", explanation: item.steps.joined(separator: "\n")))
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(number)")
                                    .font(.pt(.subheadline).weight(.bold))
                                    .frame(width: 28, height: 28)
                                    .background(choiceColor(number, answer: item.answerNumber).opacity(0.18), in: .circle)
                                Text(choice).multilineTextAlignment(.leading).foregroundStyle(Palette.ink)
                                Spacer(minLength: 0)
                                if picked != nil && number == item.answerNumber {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Palette.success)
                                        .transition(.scale.combined(with: .opacity))
                                } else if picked == number {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Palette.danger)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(12)
                            .background(Palette.card, in: .rect(cornerRadius: 14))
                            .scaleEffect(picked == number ? 1.02 : 1)
                            .overlay {
                                RoundedRectangle(cornerRadius: 14).stroke(choiceColor(number, answer: item.answerNumber), lineWidth: picked == nil ? 0 : 1.5)
                            }
                        }
                        .buttonStyle(.pressable)
                        .appearAnimation(delay: Double(choiceIndex) * 0.04)
                    }
                    if picked != nil {
                        DisclosureGroup(isExpanded: $showSteps.animation(Motion.spring)) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(item.steps.enumerated()), id: \.offset) { stepIndex, line in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(stepIndex + 1)단계 풀이")
                                            .font(.pt(.caption).weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Theme.accent, in: .rect(cornerRadius: 6))
                                        Text(line).font(.pt(.subheadline)).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Text("최종 답: \(item.finalAnswer)").font(.pt(.headline))
                            }
                            .padding(.top, 8)
                        } label: {
                            Label("단계별 풀이 보기", systemImage: "lightbulb.fill").font(.pt(.subheadline).weight(.bold))
                        }
                        .padding(14)
                        .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 14))

                        if let picked, picked != item.answerNumber {
                            Button { saveToNotes(item, picked: picked) } label: {
                                Label(savedToNotes.contains(item.question) ? L("오답노트에 담았어요") : L("오답노트에 담기"),
                                      systemImage: savedToNotes.contains(item.question) ? "checkmark" : "arrow.down.circle")
                                    .font(.pt(.subheadline).weight(.semibold))
                            }
                            .disabled(savedToNotes.contains(item.question))
                        }

                        primaryButton(index + 1 < set.items.count ? L("다음 문제") : L("결과 보기")) {
                            showSteps = false
                            if index + 1 < set.items.count {
                                withAnimation(Motion.spring) {
                                    index += 1
                                    picked = nil
                                }
                            } else {
                                withAnimation(Motion.spring) { finished = true }
                                record(context, subject: subject, unit: unit, step: .problem, correct: correct, total: set.items.count)
                                saveWeak(wrongs, subject: subject, unit: unit, context: context)
                            }
                        }
                    }
                }
            }
        }
    }

    /// 틀린 AI 학습 문제를 오답노트로 (글이 정확하니 인식 확인 없이 바로 확정, 채점·원인 분석까지)
    private func saveToNotes(_ item: Problem, picked: Int) {
        let marks = ["①", "②", "③", "④", "⑤"]
        let text = item.question + "\n" + item.choices.prefix(5).enumerated().map { "\(marks[$0.offset]) \($0.element)" }.joined(separator: " ")
        let note = MathNote(title: unit, imageData: nil, thumbnailData: nil, recognizedText: text, correctAnswer: "\(item.answerNumber)")
        note.subject = subject
        note.unit = unit
        note.recognitionRaw = "confirmed"
        note.scan = DoitProblemScan.scan(text, math: note.subjectKind.isMath)
        note.kind = .multipleChoice
        note.myAnswer = "\(picked)"
        let result = DoitGrader.grade(.init(kind: .multipleChoice, student: note.myAnswer, answerKey: note.correctAnswer, choices: Array(item.choices.prefix(5)), problem: item.question))
        note.grade = result
        note.status = .wrong
        note.analysis = DoitMistake.analyze(.init(problem: item.question, kind: .multipleChoice, student: note.myAnswer, grade: result, choices: Array(item.choices.prefix(5)),
                                                  subject: note.subjectKind))
        note.solutionData = try? JSONEncoder().encode(WrittenSolution(concept: unit, steps: item.steps.map { SolutionStep(hint: "풀이", work: $0) }, finalAnswer: item.finalAnswer))
        context.insert(note)
        WeakConceptStore.recordGrade(note: note, correct: false, source: "AI 학습", cause: note.analysis?.cause.rawValue, context: context)
        savedToNotes.insert(item.question)
        Haptics.success()
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
            Text("틀렸던 문제를 다시 확인해요").font(.pt(.headline))
            if items.isEmpty {
                Label("아직 틀린 문제가 없어요", systemImage: "checkmark.seal")
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.prompt).font(.pt(.subheadline).weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    if revealed.contains(item.id) {
                        Text("정답: \(item.answer)").font(.pt(.subheadline).weight(.bold)).foregroundStyle(Theme.accent)
                        if !item.explanation.isEmpty {
                            Text(item.explanation).font(.pt(.caption)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Button("이제 알아요 · 목록에서 빼기") { remove(item) }.font(.pt(.caption).weight(.semibold))
                    } else {
                        Button("정답 확인") { _ = withAnimation(Motion.spring) { revealed.insert(item.id) } }.font(.pt(.caption).weight(.semibold))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.card, in: .rect(cornerRadius: 14))
                .overlay(alignment: .leading) {
                    UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16)
                        .fill(Palette.danger.opacity(0.7))
                        .frame(width: 4)
                }
                .clipShape(.rect(cornerRadius: 14))
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity)))
            }
            primaryButton(L("이 단원 학습 완료"), symbol: "checkmark") { onDone(.weak) }
        }
        .onAppear { items = ContentCache.load([WeakItem].self, key: ContentCache.key(subject, unit, "weak"), context: context) ?? [] }
    }

    private func remove(_ item: WeakItem) {
        items.removeAll { $0.id == item.id }
        ContentCache.save(items, key: ContentCache.key(subject, unit, "weak"), context: context)
    }
}


// MARK: - 결과 요약 카드 (링이 채워지고 숫자가 올라감)

struct ResultSummaryCard: View {
    let correct: Int
    let total: Int
    @State private var shown = 0.0

    init(correct: Int, total: Int) {
        self.correct = correct
        self.total = total
    }

    private var ratio: Double { total > 0 ? Double(correct) / Double(total) : 0 }

    private var message: String {
        switch ratio {
        case 1: return L("완벽해요! 🎉")
        case 0.7...: return L("잘했어요! 조금만 더 다듬어요")
        case 0.4...: return L("절반 넘게 맞혔어요. 틀린 건 복습해요")
        default: return L("괜찮아요, 틀린 문제가 실력이 돼요")
        }
    }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                ProgressRing(progress: shown, lineWidth: 9, color: ratio >= 0.7 ? Palette.success : Theme.accent)
                VStack(spacing: 0) {
                    AnimatedNumberText(value: Int((shown * 100).rounded()), suffix: "%", font: .headline.weight(.bold))
                }
            }
            .frame(width: 76, height: 76)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(total)문제 중 \(correct)개 정답")
                    .font(.pt(.headline))
                    .foregroundStyle(Palette.ink)
                Text(message)
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .softCard(cornerRadius: 22, padding: 18)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) { shown = ratio }
        }
        .sensoryFeedback(.success, trigger: shown > 0 && ratio >= 0.7)
    }
}
