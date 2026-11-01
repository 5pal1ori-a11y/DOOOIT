import SwiftData
import SwiftUI

/// 내 풀이 기록으로 찾은 취약 유형과 맞춤 학습
struct WeaknessView: View {
    @Query private var records: [QuizRecord]
    @Query private var notes: [MathNote]

    struct Weakness: Identifiable {
        let subject: String
        let unit: String
        let correct: Int
        let total: Int
        let wrongNotes: Int
        var id: String { subject + "|" + unit }
        var accuracy: Double { total == 0 ? 0.3 : Double(correct) / Double(total) }

        /// 0: 개념이해 전, 1: 실전활용 가능, 2: 고난도 정복
        var level: Int { accuracy < 0.5 ? 0 : (accuracy < 0.8 ? 1 : 2) }

        var headline: String {
            switch level {
            case 0: return "기본 문제에 오답이 많아요"
            case 1: return "응용 문제에서 실수가 있어요"
            default: return "고난도 문제에 도전할 차례예요"
            }
        }

        var plan: String {
            switch level {
            case 0: return "개념 중심 학습으로 교과서 문제를 쉽게 풀 수 있어요"
            case 1: return "O/X와 유형 문제로 실전 감각을 길러요"
            default: return "실전 문제로 실수 없이 마무리해요"
            }
        }

        var startStep: LearnStep {
            switch level {
            case 0: return .concept
            case 1: return .ox
            default: return .problem
            }
        }

        var minutes: Int { level == 0 ? 90 : (level == 1 ? 60 : 40) }
    }

    private var weaknesses: [Weakness] {
        var map: [String: (subject: String, unit: String, correct: Int, total: Int, notes: Int)] = [:]
        for record in records {
            let key = record.subject + "|" + record.unit
            var entry = map[key] ?? (record.subject, record.unit, 0, 0, 0)
            entry.correct += record.correct
            entry.total += record.total
            map[key] = entry
        }
        for note in notes where note.status == .wrong && !note.unit.isEmpty {
            let unitName = note.unit.components(separatedBy: CharacterSet(charactersIn: "·,/")).first?
                .trimmingCharacters(in: .whitespaces) ?? note.unit
            let key = "수학|" + unitName
            var entry = map[key] ?? ("수학", unitName, 0, 0, 0)
            entry.notes += 1
            map[key] = entry
        }
        return map.values
            .map { Weakness(subject: $0.subject, unit: $0.unit, correct: $0.correct, total: $0.total, wrongNotes: $0.notes) }
            .filter { $0.accuracy < 0.8 || $0.wrongNotes > 0 }
            .sorted { ($0.accuracy - Double($0.wrongNotes) * 0.1) < ($1.accuracy - Double($1.wrongNotes) * 0.1) }
    }

    var body: some View {
        let list = weaknesses
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("빈칸·O/X·문제 풀이 기록과 오답노트를 모아 약한 유형을 찾아요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                NavigationLink { WeakConceptListView() } label: {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "scope", color: Palette.danger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("오답노트 취약 개념").font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
                            Text("개념별 오답 횟수·원인·숙련도").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }
                    .softCard(cornerRadius: 20, padding: 14)
                }
                .buttonStyle(.pressable)
                if list.isEmpty {
                    EmptyStateView(symbol: "scope", title: "아직 찾은 취약 유형이 없어요",
                                   message: "단원별 학습에서 문제를 풀거나\n오답노트에 단원을 적고 오답으로 채점해보세요.")
                        .softCard()
                        .appearAnimation()
                }
                ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                    weaknessCard(item)
                        .appearAnimation(delay: Double(index) * 0.07)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("취약 유형 맞춤 학습")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func weaknessCard(_ item: Weakness) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                TagLabel(text: item.subject, color: .secondary)
                if item.total > 0 { TagLabel(text: "정답률 \(Int(item.accuracy * 100))%", color: Theme.accent) }
                if item.wrongNotes > 0 { TagLabel(text: "오답노트 \(item.wrongNotes)", color: Palette.danger) }
            }
            Label(item.unit, systemImage: "sparkles").font(.headline).foregroundStyle(Theme.accent)
            Text("\(item.headline)\n\(item.plan)")
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("맞춤 학습 예상 시간 \(TimeText.duration(minutes: item.minutes))")
                .font(.caption)
                .foregroundStyle(.secondary)

            levelBar(item.level)

            NavigationLink {
                UnitStudyView(subject: item.subject, unit: item.unit, initialStep: item.startStep)
            } label: {
                Text("이 맞춤 학습 시작하기")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .softCard(cornerRadius: 24, padding: 20)
    }

    private func levelBar(_ level: Int) -> some View {
        let labels = ["개념이해 전", "실전활용 가능", "고난도 정복"]
        let current = (Double(level) + 0.5) / 3
        let target = min(1, (Double(level) + 1.5) / 3)
        return VStack(spacing: 6) {
            HStack {
                Text("현재 내 실력은?").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Label("예상 도달: \(labels[min(level + 1, 2)])", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            LevelFillBar(current: current, target: target)
                .frame(height: 10)
            HStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.caption2.weight(index == level ? .bold : .regular))
                        .foregroundStyle(index == level ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(Theme.accent.opacity(0.05), in: .rect(cornerRadius: 16))
    }
}

/// 실력 막대: 처음 보일 때 왼쪽부터 차오름
private struct LevelFillBar: View {
    let current: Double
    let target: Double
    @State private var filled = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule().fill(Theme.accent.opacity(0.25)).frame(width: geo.size.width * (filled ? target : 0))
                Capsule().fill(AccentGradient.linear).frame(width: geo.size.width * (filled ? current : 0))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.2)) { filled = true }
        }
    }
}

/// AI 학습: 교과 단원을 고르거나 과목과 단원을 직접 입력
struct CurriculumView: View {
    @State private var subject = ""
    @State private var unit = ""
    @State private var pickedSubject: String?
    @FocusState private var focus: Field?
    @Query private var records: [QuizRecord]
    /// 직접 입력을 분석한 결과
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

    private enum Field { case subject, unit }

    private var trimmedSubject: String { subject.trimmingCharacters(in: .whitespaces) }
    private var trimmedUnit: String { unit.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("무엇을 공부할까요?").font(.title2.weight(.bold)).foregroundStyle(Palette.ink)
                    Text("단원을 고르거나 직접 적으면 AI가 개념 → 빈칸 → O/X → 문제 순서로 자료를 만들어요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .appearAnimation()

                subjectCards
                    .appearAnimation(delay: 0.05)

                if let picked = pickedSubject, let curriculum = Curriculum.subjects.first(where: { $0.name == picked }) {
                    unitList(curriculum)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("직접 입력").font(.headline).foregroundStyle(Palette.ink)
                    VStack(spacing: 0) {
                        field(title: "과목", placeholder: "예: 중3 수학 (비워도 돼요)", text: $subject, field: .subject)
                        Divider().padding(.leading, 16)
                        field(title: "단원", placeholder: "예: 이차방정식의 풀이", text: $unit, field: .unit)
                    }
                    .softCardBackground(cornerRadius: 20)
                    Text("\"중학교 2학년 역사 삼국의 성립과 발전\"처럼 한 칸에 모두 적어도 돼요. 두잇 AI가 과목·학년·단원을 알아내고, 여러 단원으로 해석되면 골라 달라고 물어봐요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(action: startTyped) {
                        Label("학습 시작", systemImage: "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(trimmedSubject.isEmpty && trimmedUnit.isEmpty)
                }
                .appearAnimation(delay: 0.1)
            }
            .padding(20)
            .animation(Motion.spring, value: pickedSubject)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .navigationTitle("AI 학습")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $target) { item in
            UnitStudyView(subject: item.subject, unit: item.unit)
        }
        .confirmationDialog("어느 단원을 공부할까요?", isPresented: Binding(get: { !choices.isEmpty }, set: { if !$0 { choices = [] } }),
                            titleVisibility: .visible) {
            ForEach(choices, id: \.key) { option in
                Button(option.label) { open(option) }
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

    /// 직접 적은 말 → 과목·학년·단원 분석 → 바로 시작 / 골라 달라고 묻기 / 없다고 알려주기
    private func startTyped() {
        focus = nil
        switch DoitStudy.resolve(subject: trimmedSubject, unit: trimmedUnit) {
        case .resolved(let scope):
            open(scope)
        case .ambiguous(let options):
            choicesMessage = "'\(trimmedUnit.isEmpty ? trimmedSubject : trimmedUnit)'은(는) 여러 단원으로 해석돼요. 임의로 고르지 않을게요."
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

    private func open(_ scope: StudyScope) {
        Haptics.tap()
        target = StudyTarget(subject: scope.subjectName, unit: scope.unit)
    }

    /// 교과 과목 카드 (가로로 넘김)
    private var subjectCards: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(Curriculum.subjects) { item in
                    let selected = pickedSubject == item.name
                    Button {
                        pickedSubject = selected ? nil : item.name
                        Haptics.tap()
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: item.symbol)
                                .font(.headline)
                                .foregroundStyle(selected ? Theme.accent : .white)
                                .frame(width: 38, height: 38)
                                .background(selected ? AnyShapeStyle(Color.white) : AnyShapeStyle(AccentGradient.linear), in: .rect(cornerRadius: 12))
                                .symbolEffect(.bounce, value: selected)
                            Text(item.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(selected ? .white : Palette.ink)
                            Text("\(item.units.count)개 단원")
                                .font(.caption)
                                .foregroundStyle(selected ? Color.white.opacity(0.85) : Color.secondary)
                        }
                        .frame(width: 118, alignment: .leading)
                        .padding(14)
                        .background(selected ? AnyShapeStyle(AccentGradient.linear) : AnyShapeStyle(Color.white), in: .rect(cornerRadius: 20))
                        .shadow(color: selected ? Theme.accent.opacity(0.3) : .black.opacity(0.06), radius: 10, y: 4)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    /// 고른 과목의 단원 목록 (기록이 있으면 정답률 표시)
    private func unitList(_ curriculum: CurriculumSubject) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(curriculum.units.enumerated()), id: \.element.id) { index, item in
                NavigationLink {
                    UnitStudyView(subject: curriculum.name, unit: item.title)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.chapter).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                            Text(item.title).font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
                        }
                        Spacer(minLength: 0)
                        if let accuracy = accuracy(subject: curriculum.name, unit: item.title) {
                            TagLabel(text: "정답률 \(accuracy)%", symbol: "checkmark.circle.fill",
                                     color: accuracy >= 80 ? Palette.success : (accuracy >= 50 ? Theme.accent : Palette.danger))
                        }
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                if index < curriculum.units.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .softCardBackground(cornerRadius: 20)
    }

    private func accuracy(subject: String, unit: String) -> Int? {
        let matching = records.filter { $0.subject == subject && $0.unit == unit }
        let total = matching.reduce(0) { $0 + $1.total }
        guard total > 0 else { return nil }
        return Int((Double(matching.reduce(0) { $0 + $1.correct }) / Double(total) * 100).rounded())
    }

    private func field(title: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            TextField(placeholder, text: text)
                .focused($focus, equals: field)
                .submitLabel(field == .subject ? .next : .done)
                .onSubmit { if field == .subject { focus = .unit } }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
    }
}
