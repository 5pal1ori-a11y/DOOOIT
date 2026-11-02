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

@MainActor
enum LearnProgress {
    static let prefix = "progress|"

    static func key(_ subject: String, _ unit: String) -> String { prefix + subject + "|" + unit }

    static func load(subject: String, unit: String, context: ModelContext) -> UnitProgress? {
        ContentCache.load(UnitProgress.self, key: key(subject, unit), context: context)
    }

    static func mark(_ step: LearnStep, subject: String, unit: String, context: ModelContext) {
        var progress = load(subject: subject, unit: unit, context: context) ?? UnitProgress(subject: subject, unit: unit)
        if !progress.done.contains(step.rawValue) { progress.done.append(step.rawValue) }
        ContentCache.save(progress, key: key(subject, unit), context: context)
    }

    static func decode(_ item: StudyContent) -> UnitProgress? {
        try? JSONDecoder().decode(UnitProgress.self, from: item.data)
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
    @Query(filter: #Predicate<StudyContent> { $0.key.starts(with: "progress|") }, sort: \StudyContent.createdAt, order: .reverse)
    private var progressItems: [StudyContent]

    @State private var query = ""
    @State private var level: LevelFilter = .all
    @FocusState private var searching: Bool
    @State private var target: StudyTarget?
    @State private var choices: [StudyScope] = []
    @State private var choicesMessage = ""
    @State private var notFound: String?

    /// 학습할 단원 (교육과정 이름 그대로)
    struct StudyTarget: Hashable, Identifiable {
        let subject: String
        let unit: String
        var id: String { subject + "|" + unit }
    }

    enum LevelFilter: String, CaseIterable, Identifiable {
        case all = "전체", common = "고1 공통", elementary = "초등", middle = "중학교", high = "고등학교", university = "대학교"
        var id: String { rawValue }

        func matches(_ subject: CurriculumSubject) -> Bool {
            let isCommon = Curriculum.highSchoolCommon.contains { $0.name == subject.name }
            switch self {
            case .all: return true
            case .common: return isCommon
            default: return !isCommon && subject.name.hasPrefix(rawValue)
            }
        }
    }

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    private var progresses: [UnitProgress] { progressItems.compactMap(LearnProgress.decode) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                searchField

                if !trimmed.isEmpty {
                    searchResults
                } else {
                    if let resume = progresses.first(where: { !$0.isComplete }) {
                        resumeCard(resume)
                            .appearAnimation()
                    }
                    subjectSection
                        .appearAnimation(delay: 0.05)
                    weakSection
                        .appearAnimation(delay: 0.1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .animation(.smooth(duration: 0.25), value: trimmed.isEmpty)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .navigationTitle("단원별 AI 학습")
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
        .alert("단원을 찾지 못했어요", isPresented: Binding(get: { notFound != nil }, set: { if !$0 { notFound = nil } })) {
            Button("확인", role: .cancel) { notFound = nil }
        } message: {
            Text(notFound ?? "")
        }
    }

    // MARK: 검색

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("단원 검색 또는 직접 입력 (예: 중2 일차함수)", text: $query)
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
                let haystack = (subject.name + " " + unit.chapter + " " + unit.title).lowercased()
                if words.allSatisfy({ haystack.contains($0) }) { matches.append((subject, unit)) }
                if matches.count >= 12 { break }
            }
            if matches.count >= 12 { break }
        }
        return VStack(alignment: .leading, spacing: 12) {
            Button(action: startTyped) {
                RowLabel(symbol: "sparkles", color: Theme.accent, title: "'\(trimmed)'(으)로 학습 시작",
                         subtitle: "과목·학년·단원을 알아서 찾아요")
                    .softCardBackground(cornerRadius: 18)
            }
            .buttonStyle(.pressable)

            if !matches.isEmpty {
                SectionTitle("찾은 단원")
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

    // MARK: 이어서 하기

    private func resumeCard(_ progress: UnitProgress) -> some View {
        Button {
            open(subject: progress.subject, unit: progress.unit)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: progress.ratio, lineWidth: 7, color: Theme.accent)
                    Text("\(progress.doneCount)/\(LearnStep.allCases.count)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("이어서 학습")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(progress.unit)
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text("\(progress.subject) · 다음: \(progress.nextStep?.longTitle ?? "복습")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
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
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle("과목")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(LevelFilter.allCases) { item in
                        let isOn = level == item
                        Button {
                            withAnimation(.snappy) { level = item }
                            Haptics.tap()
                        } label: {
                            Text(item.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .frame(height: 34)
                                .foregroundStyle(isOn ? Color.white : Palette.ink)
                                .background(isOn ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white), in: .capsule)
                                .overlay(Capsule().strokeBorder(Color.primary.opacity(isOn ? 0 : 0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)

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
        }
    }

    private func subjectTile(_ subject: CurriculumSubject) -> some View {
        let done = progresses.filter { $0.subject == subject.name && $0.isComplete }.count
        let ratio = subject.units.isEmpty ? 0 : Double(done) / Double(subject.units.count)
        return VStack(alignment: .leading, spacing: 10) {
            Image(systemName: subject.symbol)
                .font(.headline)
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(subject.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(done > 0 ? "\(subject.units.count)개 단원 · \(done)개 완료" : "\(subject.units.count)개 단원")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LinearProgressBar(value: ratio, height: 4)
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
                SectionTitle("다시 볼 단원")
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
            choicesMessage = "'\(trimmed)'은(는) 여러 단원으로 해석돼요."
            choices = options
        case .notFound(let message, let suggestions):
            if suggestions.isEmpty {
                notFound = message
            } else {
                choicesMessage = message
                choices = suggestions
            }
        }
    }

    private func open(subject: String, unit: String) {
        Haptics.tap()
        target = StudyTarget(subject: subject, unit: unit)
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
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Palette.success, in: .circle)
                } else {
                    ProgressRing(progress: progress?.ratio ?? 0, lineWidth: 4, color: Theme.accent)
                        .frame(width: 30, height: 30)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                if let caption {
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let accuracy {
                Text("\(accuracy)%")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(accuracy >= 80 ? Palette.success : (accuracy >= 60 ? Theme.accent : Palette.danger))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((accuracy >= 80 ? Palette.success : (accuracy >= 60 ? Theme.accent : Palette.danger)).opacity(0.12), in: .capsule)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
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
    @Query(filter: #Predicate<StudyContent> { $0.key.starts(with: "progress|") }) private var progressItems: [StudyContent]

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
        let progresses = progressItems.compactMap(LearnProgress.decode).filter { $0.subject == subject.name }
        let done = progresses.filter(\.isComplete).count
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 16) {
                    ZStack {
                        ProgressRing(progress: subject.units.isEmpty ? 0 : Double(done) / Double(subject.units.count), lineWidth: 8, color: Theme.accent)
                        Image(systemName: subject.symbol).font(.title3).foregroundStyle(Theme.accent)
                    }
                    .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subject.name).font(.title3.weight(.bold)).foregroundStyle(Palette.ink)
                        Text("\(subject.units.count)개 단원 중 \(done)개 완료")
                            .font(.subheadline)
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
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background { AppBackground() }
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
