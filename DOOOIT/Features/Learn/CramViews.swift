import SwiftData
import SwiftUI

/// 시험 직전 벼락치기 목록
struct CramListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ExamPlan.examDate) private var exams: [ExamPlan]
    @State private var showNew = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if exams.isEmpty {
                    VStack(spacing: 16) {
                        EmptyStateView(symbol: "bolt.fill", title: "다가오는 시험이 없어요")
                        Button { showNew = true } label: {
                            Label("시험 추가하기", systemImage: "plus")
                                .font(.pt(.body).weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                    }
                    .glassCard(padding: 20)
                }
                ForEach(exams) { exam in
                    NavigationLink { CramDetailView(exam: exam) } label: { examRow(exam) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                context.delete(exam)
                                try? context.save()
                            } label: { Label("삭제", systemImage: "trash") }
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("시험 벼락치기")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("시험 추가")
            }
        }
        .sheet(isPresented: $showNew) { CramEditorView() }
    }

    private func examRow(_ exam: ExamPlan) -> some View {
        let units = exam.units
        let totalSteps = units.count * LearnStep.allCases.count
        let doneSteps = units.reduce(0) { $0 + $1.done.count }
        return HStack(spacing: 16) {
            VStack(spacing: 0) {
                Text(exam.dDay > 0 ? "D-\(exam.dDay)" : (exam.dDay == 0 ? "D-DAY" : "끝"))
                    .font(.pt(.title3).weight(.bold))
                    .foregroundStyle(exam.dDay <= 3 ? Palette.danger : Theme.accent)
                Text(exam.examDate.kr("M.d")).font(.pt(.caption2)).foregroundStyle(.secondary)
            }
            .frame(width: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text(exam.name).font(.pt(.headline))
                Text("\(Set(units.map(\.subject)).sorted().joined(separator: " · ")) · \(units.count)단원")
                    .font(.pt(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ProgressView(value: Double(doneSteps), total: Double(max(totalSteps, 1)))
                    .tint(Theme.accent)
            }
            Image(systemName: "chevron.right").font(.pt(.footnote)).foregroundStyle(.tertiary)
        }
        .glassCard(interactive: true)
    }
}

/// 시험 상세: 정석/부스터 모드, 과목 탭, 단원별 학습 단계
struct CramDetailView: View {
    @Bindable var exam: ExamPlan
    @Environment(\.modelContext) private var context
    @State private var subject = ""
    @State private var openUnit: OpenUnit?

    struct OpenUnit: Identifiable, Hashable {
        let unitID: UUID
        let step: LearnStep
        var id: String { unitID.uuidString + step.rawValue }
    }

    private var subjects: [String] {
        var seen: [String] = []
        for unit in exam.units where !seen.contains(unit.subject) { seen.append(unit.subject) }
        return seen
    }

    var body: some View {
        let current = subject.isEmpty ? (subjects.first ?? "") : subject
        let units = exam.units.filter { $0.subject == current }
        let chapters = units.reduce(into: [String]()) { if !$0.contains($1.chapter) { $0.append($1.chapter) } }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                modePicker
                if subjects.count > 1 {
                    ScrollView(.horizontal) {
                        HStack(spacing: 18) {
                            ForEach(subjects, id: \.self) { name in
                                Button { subject = name } label: {
                                    Text(name)
                                        .font(.pt(.headline))
                                        .foregroundStyle(name == current ? Color.primary : Color.secondary)
                                        .padding(.bottom, 6)
                                        .overlay(alignment: .bottom) {
                                            if name == current { Capsule().fill(Color.primary).frame(height: 2.5) }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                Text("학습 범위").font(.pt(.title3).weight(.bold))
                ForEach(chapters, id: \.self) { chapter in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(chapter).font(.pt(.subheadline).weight(.bold)).foregroundStyle(.secondary)
                        ForEach(units.filter { $0.chapter == chapter }) { unit in
                            unitCard(unit)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 140)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle(exam.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationDestination(item: $openUnit) { target in
            if let unit = exam.units.first(where: { $0.id == target.unitID }) {
                UnitStudyView(subject: unit.subject, unit: unit.title, booster: exam.isBooster,
                              initialStep: target.step, completed: unit.done) { step in
                    markDone(unitID: unit.id, step: step)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(exam.name).font(.pt(.title2).weight(.bold))
                Text("\(exam.examDate.kr("M월 d일 (E)")) 시험").font(.pt(.subheadline)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "bolt.fill")
                .font(.pt(size: 34))
                .foregroundStyle(Palette.warning)
                .frame(width: 64, height: 64)
                .glassEffect(.regular, in: .circle)
        }
        .padding(.top, 6)
    }

    private var modePicker: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if exam.dDay <= 2 && !exam.isBooster {
                Label("시험 \(max(exam.dDay, 0))일 전, 핵심만 빠르게", systemImage: "sparkles")
                    .font(.pt(.caption).weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.08), in: .capsule)
            }
            Picker("모드", selection: Binding(get: { exam.isBooster }, set: { exam.isBooster = $0; try? context.save() })) {
                Text("정석 모드").tag(false)
                Text("부스터 모드").tag(true)
            }
            .pickerStyle(.segmented)
            Text(exam.isBooster ? "부스터: 핵심 개념 3개, 문제 수를 줄여 빠르게 훑어요." : "정석: 개념부터 응용 문제까지 차근차근 풀어요.")
                .font(.pt(.caption))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func unitCard(_ unit: CramUnit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(unit.title).font(.pt(.headline))
                Spacer()
                Text("\(unit.done.count)/\(LearnStep.allCases.count)").font(.pt(.caption).weight(.bold)).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(LearnStep.allCases) { step in
                        let done = unit.done.contains(step.rawValue)
                        Button { openUnit = OpenUnit(unitID: unit.id, step: step) } label: {
                            HStack(spacing: 4) {
                                if done { Image(systemName: "checkmark").font(.pt(.caption2).weight(.bold)) }
                                Text(step.title)
                            }
                            .font(.pt(.subheadline).weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .foregroundStyle(done ? Theme.accent : Color.primary)
                            .background(done ? Theme.accent.opacity(0.14) : Color.primary.opacity(0.05), in: .capsule)
                        }
                        .buttonStyle(.plain)
                        if step != LearnStep.allCases.last {
                            Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 8, height: 2)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 20))
    }

    private var bottomBar: some View {
        let next = exam.units.first { $0.done.count < LearnStep.allCases.count }
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(next.map { "\($0.subject) · \($0.title)" } ?? "모든 단원을 끝냈어요")
                    .font(.pt(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(exam.dDay >= 0 ? "시험 D-\(exam.dDay)" : "시험이 끝났어요").font(.pt(.headline))
            }
            Spacer()
            if let next {
                Button("학습 시작") {
                    let step = LearnStep.allCases.first { !next.done.contains($0.rawValue) } ?? .concept
                    openUnit = OpenUnit(unitID: next.id, step: step)
                }
                .buttonStyle(.glassProminent)
                .fontWeight(.bold)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func markDone(unitID: UUID, step: LearnStep) {
        var units = exam.units
        guard let i = units.firstIndex(where: { $0.id == unitID }) else { return }
        if !units[i].done.contains(step.rawValue) { units[i].done.append(step.rawValue) }
        exam.units = units
        try? context.save()
    }
}

/// 새 시험 만들기: 이름, 날짜, 과목/단원 범위
struct CramEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = "1학기 중간고사"
    @State private var date = Date().adding(days: 7)
    @State private var selected: Set<String> = []
    @State private var customSubject = ""
    @State private var customUnit = ""
    @State private var customUnits: [CramUnit] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("시험 이름", text: $name).font(.pt(.headline))
                    DatePicker("시험 날짜", selection: $date, in: Date()..., displayedComponents: .date)
                }

                ForEach(Curriculum.subjects) { subject in
                    Section {
                        ForEach(subject.units) { unit in
                            let key = subject.name + "/" + unit.id
                            Button {
                                if selected.contains(key) { selected.remove(key) } else { selected.insert(key) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(unit.title).foregroundStyle(Color.primary)
                                        Text(unit.chapter).font(.pt(.caption)).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: selected.contains(key) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(key) ? Theme.accent : Color.secondary)
                                }
                            }
                        }
                    } header: {
                        Label(subject.name, systemImage: subject.symbol)
                    }
                }

                Section {
                    TextField("과목 (예: 한국사)", text: $customSubject)
                    HStack {
                        TextField("단원 (예: 조선의 건국)", text: $customUnit)
                        Button("추가") {
                            let s = customSubject.trimmingCharacters(in: .whitespaces)
                            let u = customUnit.trimmingCharacters(in: .whitespaces)
                            guard !s.isEmpty, !u.isEmpty else { return }
                            customUnits.append(CramUnit(subject: s, chapter: "직접 추가", title: u))
                            customUnit = ""
                        }
                    }
                    ForEach(customUnits) { unit in
                        Text("\(unit.subject) · \(unit.title)")
                    }
                    .onDelete { customUnits.remove(atOffsets: $0) }
                } header: {
                    Text("다른 과목 · 단원 직접 추가")
                }
            }
            .navigationTitle("시험 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Image(systemName: "checkmark") }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (selected.isEmpty && customUnits.isEmpty))
                }
            }
        }
    }

    private func save() {
        var units: [CramUnit] = []
        for subject in Curriculum.subjects {
            for unit in subject.units where selected.contains(subject.name + "/" + unit.id) {
                units.append(CramUnit(subject: subject.name, chapter: unit.chapter, title: unit.title))
            }
        }
        units += customUnits
        context.insert(ExamPlan(name: name.trimmingCharacters(in: .whitespaces), examDate: date, units: units))
        try? context.save()
        dismiss()
    }
}
