import SwiftData
import SwiftUI

// MARK: - 단원 학습 진행 (계정 저장소에 저장 → 이어서 하기)

/// 단원마다 끝낸 단계 (개념·빈칸·O/X·문제·취약)
struct UnitProgress: Codable, Hashable {
    var subject: String
    var unit: String
    var done: [String] = []

    var doneCount: Int { LearnStep.allCases.filter { done.contains($0.rawValue) }.count }
    var isComplete: Bool { doneCount == LearnStep.allCases.count }
    var ratio: Double { Double(doneCount) / Double(LearnStep.allCases.count) }
    /// 다음에 할 단계 (다 끝냈으면 nil)
    var nextStep: LearnStep? { LearnStep.allCases.first { !done.contains($0.rawValue) } }
}

/// 진행 기록은 저장소의 기록 하나(목록)에 모아 둠
/// (SwiftData 조회 조건에 글자 앞부분 비교를 쓰면 기기에서 앱이 멈출 수 있어서, 정확한 키 하나로만 찾음)
@MainActor
enum LearnProgress {
    static let indexKey = "learn-progress-index"

    /// 모든 단원 진행 (최근에 한 것부터)
    static func all(context: ModelContext) -> [UnitProgress] {
        ContentCache.load([UnitProgress].self, key: indexKey, context: context) ?? []
    }

    static func load(subject: String, unit: String, context: ModelContext) -> UnitProgress? {
        all(context: context).first { $0.subject == subject && $0.unit == unit }
    }

    static func mark(_ step: LearnStep, subject: String, unit: String, context: ModelContext) {
        var list = all(context: context)
        var progress = list.first { $0.subject == subject && $0.unit == unit } ?? UnitProgress(subject: subject, unit: unit)
        if !progress.done.contains(step.rawValue) { progress.done.append(step.rawValue) }
        list.removeAll { $0.subject == subject && $0.unit == unit }
        list.insert(progress, at: 0)
        ContentCache.save(list, key: indexKey, context: context)
    }

    /// 같은 과목에서 바로 다음 단원
    static func nextUnit(after unit: String, subject: String) -> String? {
        guard let units = Curriculum.subjects.first(where: { $0.name == subject })?.units,
              let index = units.firstIndex(where: { $0.title == unit }), index + 1 < units.count else { return nil }
        return units[index + 1].title
    }
}

// MARK: - 단원별 AI 학습 첫 화면

/// 검색(직접 입력) → 이어서 하기 → 학교급 · 과목 → 다시 볼 단원
struct CurriculumView: View {
    @Query private var records: [QuizRecord]
    @Environment(\.modelContext) private var context
    @State private var progresses: [UnitProgress] = []

    @State private var query = ""
    @AppStorage("learn.level") private var levelRaw = LevelFilter.middle.rawValue
    @FocusState private var searching: Bool
    @State private var target: StudyTarget?
    @State private var choices: [StudyScope] = []
    @State private var choicesMessage = ""
    /// 직접 적은 말로 단원을 못 찾았을 때 (화면 안에 안내 + 비슷한 단원)
    @State private var missed: (query: String, options: [StudyScope])?

    /// 학습할 단원 (교육과정 이름 그대로)
    struct StudyTarget: Hashable, Identifiable {
        let subject: String
        let unit: String
        var id: String { subject + "|" + unit }
    }

    /// 학교급: 초등학교 · 중학교 · 고등학교(고1 공통과목 포함) · 대학교
    enum LevelFilter: String, CaseIterable, Identifiable {
        case elementary = "초등학교", middle = "중학교", high = "고등학교", university = "대학교"
        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .elementary: return "pencil"
            case .middle: return "book.fill"
            case .high: return "graduationcap.fill"
            case .university: return "building.columns.fill"
            }
        }

        /// 과목 이름 앞에 붙은 학교급 (예: "초등 수학", "중학교 과학")
        var namePrefix: String { self == .elementary ? "초등" : rawValue }

        static func isCommon(_ subject: CurriculumSubject) -> Bool {
            Curriculum.highSchoolCommon.contains { $0.name == subject.name }
        }

        func matches(_ subject: CurriculumSubject) -> Bool {
            if Self.isCommon(subject) { return self == .high }
            return subject.name.hasPrefix(namePrefix)
        }

        /// 타일에 보일 이름: 학교급은 빼고 과목만 ("중학교 수학" → "수학")
        func shortName(_ subject: CurriculumSubject) -> String {
            guard !Self.isCommon(subject), subject.name.hasPrefix(namePrefix) else { return subject.name }
            let rest = subject.name.dropFirst(namePrefix.count).trimmingCharacters(in: .whitespaces)
            return rest.isEmpty ? subject.name : rest
        }
    }

    private var level: LevelFilter { LevelFilter(rawValue: levelRaw) ?? .middle }

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                searchField

                // 과목·단원 목록은 보여 주지 않고 검색으로만 찾음 (자료는 그대로, 검색하면 나옴)
                if !trimmed.isEmpty {
                    searchResults
                } else {
                    exampleChips
                        .appearAnimation()
                    if let resume = progresses.first(where: { !$0.isComplete }) {
                        resumeCard(resume)
                            .appearAnimation(delay: 0.05)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .animation(.smooth(duration: 0.25), value: trimmed.isEmpty)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .navigationTitle("단원별 AI 학습")
        .onAppear { progresses = LearnProgress.all(context: context) }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $target) { item in
            UnitStudyView(subject: item.subject, unit: item.unit)
        }
        .confirmationDialog("어느 단원을 공부할까요?", isPresented: Binding(get: { !choices.isEmpty }, set: { if !$0 { choices = [] } }),
                            titleVisibility: .visible) {
            ForEach(choices, id: \.key) { option in
                Button(option.label) { open(subject: option.subjectName, unit: option.unit) }
            }
        } message: {
            Text(choicesMessage)
        }
    }

    // MARK: 검색

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("배우고 싶은 단원이나 주제 검색", text: $query)
                .focused($searching)
                .submitLabel(.go)
                .onSubmit(startTyped)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("지우기")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .softCardBackground(cornerRadius: 16)
    }

    /// 교육과정 단원 중 검색어가 들어간 것 + 직접 입력으로 시작
    private var searchResults: some View {
        let words = trimmed.lowercased().split(separator: " ").map(String.init)
        var matches: [(subject: CurriculumSubject, unit: CurriculumUnit)] = []
        for subject in Curriculum.subjects {
            for unit in subject.units {
                // 영어 문법 단원은 "영어 문법"·"영문법"·"어법"으로도 찾게
                let grammar = DoitGrammar.isGrammarUnit(subjectName: subject.name, unit: unit.title) ? " 영어 문법 영문법 어법" : ""
                let haystack = (subject.name + " " + unit.chapter + " " + unit.title + grammar).lowercased()
                if words.allSatisfy({ haystack.contains($0) }) { matches.append((subject, unit)) }
                if matches.count >= 20 { break }
            }
            if matches.count >= 20 { break }
        }
        return VStack(alignment: .leading, spacing: 12) {
            Button(action: startTyped) {
                RowLabel(symbol: "lightbulb", color: Theme.accent, title: L("'\(trimmed)'(으)로 학습 시작"),
                         subtitle: L("과목·학년·단원을 알아서 찾아요"))
                    .softCardBackground(cornerRadius: 18)
            }
            .buttonStyle(.pressable)

            if let missed, missed.query == trimmed {
                missedCard(missed.options)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !matches.isEmpty {
                SectionTitle(L("찾은 단원"))
                VStack(spacing: 0) {
                    ForEach(Array(matches.enumerated()), id: \.offset) { index, match in
                        Button {
                            open(subject: match.subject.name, unit: match.unit.title)
                        } label: {
                            unitRow(subject: match.subject.name, unit: match.unit.title, caption: match.subject.name)
                        }
                        .buttonStyle(.pressable)
                        if index < matches.count - 1 { RowDivider() }
                    }
                }
                .softCardBackground(cornerRadius: 20)
            }
        }
    }

    /// 검색 예시 (누르면 바로 검색)
    private var exampleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(["일차함수", "다항식", "현재완료", "전기", "광합성", "임진왜란"], id: \.self) { example in
                    Button {
                        query = example
                        Haptics.tap()
                    } label: {
                        Text(example)
                            .font(.pt(.subheadline).weight(.medium))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.accent.opacity(0.1), in: .capsule)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .scrollClipDisabled()
    }

    /// 단원을 못 찾았을 때: 이유 대신 할 수 있는 것 (비슷한 단원 · 이렇게 적어 보기)
    private func missedCard(_ options: [StudyScope]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.pt(.title3).weight(.semibold))
                    .foregroundStyle(Palette.warning)
                    .frame(width: 42, height: 42)
                    .background(Palette.warning.opacity(0.14), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("딱 맞는 단원이 없어요")
                        .font(.pt(.headline))
                        .foregroundStyle(Palette.ink)
                    Text("교과서 자료에 없는 주제예요")
                        .font(.pt(.caption))
                        .foregroundStyle(.secondary)
                }
            }

            // 교과서 자료가 없으면 모델(DOOOIT 1·2)로 만들어 보기
            FreeStudyOption {
                open(subject: DoitStudy.freeSubject, unit: DoitStudy.normalizedTopic(trimmed))
            }

            if !options.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("혹시 이 단원인가요?")
                        .font(.pt(.subheadline).weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(options, id: \.key) { option in
                        Button {
                            open(subject: option.subjectName, unit: option.unit)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.unit)
                                        .font(.pt(.body).weight(.semibold))
                                        .foregroundStyle(Palette.ink)
                                    Text(option.subjectName)
                                        .font(.pt(.caption))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.pt(.footnote).weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Palette.cardInset, in: .rect(cornerRadius: 14))
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("이렇게 적어 보세요")
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["중2 일차함수", "중3 삼각비", "고1 다항식", "초5 약수와 배수", "중2 과학 전기"], id: \.self) { example in
                            Button {
                                query = example
                                startTyped()
                            } label: {
                                Text(example)
                                    .font(.pt(.subheadline).weight(.medium))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Theme.accent.opacity(0.1), in: .capsule)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
        .softCard(cornerRadius: 22, padding: 18)
    }

    // MARK: 이어서 하기

    private func resumeCard(_ progress: UnitProgress) -> some View {
        Button {
            open(subject: progress.subject, unit: progress.unit)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: progress.ratio, lineWidth: 7, color: Theme.accent)
                    Text("\(progress.doneCount)/\(LearnStep.allCases.count)")
                        .font(.pt(.caption).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("이어서 학습")
                        .font(.pt(.caption).weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(progress.unit)
                        .font(.pt(.headline))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text("\(progress.subject) · 다음: \(progress.nextStep?.longTitle ?? L("복습"))")
                        .font(.pt(.footnote))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.pt(.subheadline))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent, in: .circle)
            }
            .softCard(cornerRadius: 22, padding: 16)
        }
        .buttonStyle(.pressable)
    }

    // MARK: 과목

    private var subjectSection: some View {
        let subjects = Curriculum.subjects.filter(level.matches)
        return VStack(alignment: .leading, spacing: 14) {
            levelTabs

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(subjects) { subject in
                    NavigationLink {
                        SubjectUnitsView(subject: subject)
                    } label: {
                        subjectTile(subject)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .id(level)
            .transition(.opacity)
        }
    }

    /// 학교급 네 칸 (아이콘 + 이름)
    private var levelTabs: some View {
        HStack(spacing: 4) {
            ForEach(LevelFilter.allCases) { item in
                let isOn = level == item
                Button {
                    withAnimation(.snappy) { levelRaw = item.rawValue }
                    Haptics.tap()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol).font(.pt(.subheadline).weight(.semibold))
                        Text(item.rawValue.loc).font(.pt(.caption).weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(isOn ? Theme.onAccent : Color.secondary)
                    .background(isOn ? Theme.accent : Color.clear, in: .rect(cornerRadius: 14))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .softCardBackground(cornerRadius: 18)
    }

    /// 과목마다 색 (국어·영어·수학·과학·사회)
    private func color(for subject: CurriculumSubject) -> Color {
        let name = subject.name
        if name.contains("국어") { return Color(hex: "#FF6B6B") }
        if name.contains("영어") { return Color(hex: "#4D8DFF") }
        if name.contains("수학") { return Theme.accent }
        if name.contains("과학") { return Palette.success }
        if name.contains("사회") || name.contains("역사") { return Palette.warning }
        return Theme.accent
    }

    private func subjectTile(_ subject: CurriculumSubject) -> some View {
        let done = progresses.filter { $0.subject == subject.name && $0.isComplete }.count
        let ratio = subject.units.isEmpty ? 0 : Double(done) / Double(subject.units.count)
        let tint = color(for: subject)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: subject.symbol)
                    .font(.pt(.headline))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.12), in: .rect(cornerRadius: 12))
                Spacer(minLength: 0)
                if LevelFilter.isCommon(subject) {
                    Text("고1 공통")
                        .font(.pt(.caption2).weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06), in: .capsule)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(level.shortName(subject))
                    .font(.pt(.subheadline).weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(done > 0 ? L("\(subject.units.count)개 단원 · \(done)개 완료") : L("\(subject.units.count)개 단원"))
                    .font(.pt(.caption))
                    .foregroundStyle(.secondary)
            }
            LinearProgressBar(value: ratio, color: tint, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(cornerRadius: 20, padding: 14)
    }

    // MARK: 다시 볼 단원 (정답률 60% 미만)

    @ViewBuilder
    private var weakSection: some View {
        let weak = weakUnits
        if !weak.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(L("다시 볼 단원"))
                VStack(spacing: 0) {
                    ForEach(Array(weak.enumerated()), id: \.offset) { index, item in
                        Button {
                            open(subject: item.subject, unit: item.unit)
                        } label: {
                            unitRow(subject: item.subject, unit: item.unit, caption: item.subject)
                        }
                        .buttonStyle(.pressable)
                        if index < weak.count - 1 { RowDivider() }
                    }
                }
                .softCardBackground(cornerRadius: 20)
            }
        }
    }

    private var weakUnits: [(subject: String, unit: String)] {
        var totals: [String: (subject: String, unit: String, correct: Int, total: Int)] = [:]
        for record in records where !record.unit.isEmpty {
            let key = record.subject + "|" + record.unit
            var value = totals[key] ?? (record.subject, record.unit, 0, 0)
            value.correct += record.correct
            value.total += record.total
            totals[key] = value
        }
        return totals.values
            .filter { $0.total >= 3 && Double($0.correct) / Double($0.total) < 0.6 }
            .sorted { Double($0.correct) / Double($0.total) < Double($1.correct) / Double($1.total) }
            .prefix(5)
            .map { ($0.subject, $0.unit) }
    }

    // MARK: 공통

    /// 단원 한 줄: 진행 링 · 단원 이름 · 정답률
    private func unitRow(subject: String, unit: String, caption: String) -> some View {
        UnitRow(progress: progresses.first { $0.subject == subject && $0.unit == unit },
                title: unit, caption: caption, accuracy: unitAccuracy(records, subject: subject, unit: unit))
    }

    /// 직접 적은 말 → 과목·학년·단원 분석 → 바로 시작 / 골라 달라고 묻기 / 없다고 알려주기
    private func startTyped() {
        searching = false
        guard !trimmed.isEmpty else { return }
        switch DoitStudy.resolve(subject: "", unit: trimmed) {
        case .resolved(let scope):
            open(subject: scope.subjectName, unit: scope.unit)
        case .ambiguous(let options):
            choicesMessage = L("'\(trimmed)'은(는) 여러 단원으로 해석돼요.")
            choices = options
        case .notFound(_, let suggestions):
            Haptics.error()
            withAnimation(.snappy) { missed = (trimmed, suggestions) }
        }
    }

    private func open(subject: String, unit: String) {
        Haptics.tap()
        target = StudyTarget(subject: subject, unit: unit)
    }
}

/// 교육과정에 없는 주제: 모델이 있으면 "AI로 학습해 보기", 받아 두기만 했으면 켜고 시작, 없으면 받기 안내
struct FreeStudyOption: View {
    /// nil이면 시작 버튼 없이 (모델이 없을 때 안내만)
    var start: (() -> Void)?
    @State private var brain = DoitBrain.shared

    var body: some View {
        if brain.isAvailable {
            if let start {
                Button(action: start) {
                    RowLabel(symbol: "lightbulb", title: L("AI로 학습해 보기"), subtitle: L("AI가 만든 내용 · 틀릴 수 있어요"))
                        .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.pressable)
            }
        } else if DoitBrain.isSupported, let model = DoitBrain.Model.allCases.first(where: brain.isInstalled), brain.downloading == nil {
            Button {
                Haptics.tap()
                brain.select(model)
                Task { await brain.prepare() }
                start?()
            } label: {
                RowLabel(symbol: "lightbulb", title: L("\(model.title) 켜고 AI로 학습"), subtitle: L("AI가 만든 내용 · 틀릴 수 있어요"))
                    .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.pressable)
        } else if DoitBrain.isSupported {
            VStack(alignment: .leading, spacing: 8) {
                Text("AI로 학습하려면 모델이 필요해요")
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(.secondary)
                ModelDownloadCard()
            }
        }
    }
}

/// 정답률 (기록이 없으면 nil)
func unitAccuracy(_ records: [QuizRecord], subject: String, unit: String) -> Int? {
    let matching = records.filter { $0.subject == subject && $0.unit == unit }
    let total = matching.reduce(0) { $0 + $1.total }
    guard total > 0 else { return nil }
    return Int((Double(matching.reduce(0) { $0 + $1.correct }) / Double(total) * 100).rounded())
}

/// 단원 한 줄 (진행 링 · 제목 · 정답률)
struct UnitRow: View {
    let progress: UnitProgress?
    let title: String
    var caption: String?
    var accuracy: Int?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if progress?.isComplete == true {
                    Image(systemName: "checkmark")
                        .font(.pt(.caption).weight(.heavy))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 30, height: 30)
                        .background(Palette.success, in: .circle)
                } else {
                    ProgressRing(progress: progress?.ratio ?? 0, lineWidth: 4, color: Theme.accent)
                        .frame(width: 30, height: 30)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                if let caption {
                    Text(caption).font(.pt(.caption)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let accuracy {
                Text("\(accuracy)%")
                    .font(.pt(.caption).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(accuracy >= 80 ? Palette.success : (accuracy >= 60 ? Theme.accent : Palette.danger))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((accuracy >= 80 ? Palette.success : (accuracy >= 60 ? Theme.accent : Palette.danger)).opacity(0.12), in: .capsule)
            }
            Image(systemName: "chevron.right")
                .font(.pt(.footnote).weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

// MARK: - 과목 → 단원 목록

struct SubjectUnitsView: View {
    let subject: CurriculumSubject

    @Query private var records: [QuizRecord]
    @Environment(\.modelContext) private var context
    @State private var allProgress: [UnitProgress] = []

    /// 대단원끼리 묶음 (대단원 이름이 과목 이름과 같으면 한 묶음)
    private var chapters: [(name: String, units: [CurriculumUnit])] {
        var result: [(String, [CurriculumUnit])] = []
        for unit in subject.units {
            if let last = result.last, last.0 == unit.chapter {
                result[result.count - 1].1.append(unit)
            } else {
                result.append((unit.chapter, [unit]))
            }
        }
        return result
    }

    var body: some View {
        let progresses = allProgress.filter { $0.subject == subject.name }
        let done = progresses.filter(\.isComplete).count
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 16) {
                    ZStack {
                        ProgressRing(progress: subject.units.isEmpty ? 0 : Double(done) / Double(subject.units.count), lineWidth: 8, color: Theme.accent)
                        Image(systemName: subject.symbol).font(.pt(.title3)).foregroundStyle(Theme.accent)
                    }
                    .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subject.name).font(.pt(.title3).weight(.bold)).foregroundStyle(Palette.ink)
                        Text("\(subject.units.count)개 단원 중 \(done)개 완료")
                            .font(.pt(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .softCard(cornerRadius: 22, padding: 18)

                ForEach(Array(chapters.enumerated()), id: \.offset) { _, chapter in
                    VStack(alignment: .leading, spacing: 10) {
                        if chapter.name != subject.name { SectionTitle(chapter.name) }
                        VStack(spacing: 0) {
                            ForEach(Array(chapter.units.enumerated()), id: \.element.id) { index, unit in
                                NavigationLink {
                                    UnitStudyView(subject: subject.name, unit: unit.title)
                                } label: {
                                    UnitRow(progress: progresses.first { $0.unit == unit.title }, title: unit.title,
                                            accuracy: unitAccuracy(records, subject: subject.name, unit: unit.title))
                                }
                                .buttonStyle(.pressable)
                                if index < chapter.units.count - 1 { RowDivider() }
                            }
                        }
                        .softCardBackground(cornerRadius: 20)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background { AppBackground() }
        .navigationTitle(subject.name)
        .onAppear { allProgress = LearnProgress.all(context: context) }
        .navigationBarTitleDisplayMode(.inline)
    }
}
