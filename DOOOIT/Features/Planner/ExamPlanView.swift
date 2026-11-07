import SwiftData
import SwiftUI

/// 시험 D-day 자동 계획: 시험 · 과목 · 하루 시간을 넣으면 시험 전날까지 하루씩 공부 플랜을 짜서 플래너에 넣어요.
struct ExamPlanView: View {
    private struct Draft {
        var selected = false
        var size = ""
        var important = false
    }

    private struct DayGroup: Identifiable {
        let date: Date
        let items: [ExamPlanner.Item]
        var id: Date { date }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanCategory.sortIndex) private var categories: [PlanCategory]
    @Query private var plans: [Plan]
    @Query private var weakConcepts: [WeakConcept]

    @State private var name = ""
    @State private var examDate = Date().startOfDay.adding(days: 14)
    @State private var drafts: [String: Draft] = [:]
    @State private var extraNames: [String] = []
    @State private var newName = ""
    @State private var dailyMinutes = 180
    @State private var startTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var offDays: Set<Int> = []
    @State private var reviewTail = true
    @State private var setDDay = true
    @State private var excluded: Set<String> = []
    @State private var showPreview = false
    @State private var deleteTarget: ExamPlanStore.Group?
    @State private var didSetup = false
    @FocusState private var focus: Field?

    private enum Field { case name, newSubject }

    var body: some View {
        NavigationStack {
            inputPage
                .navigationDestination(isPresented: $showPreview) { previewPage }
        }
        .contentFadeIn()
        .onAppear(perform: setup)
    }

    // MARK: 데이터

    private var allNames: [String] {
        let base = categories.filter(\.isStudy).map(\.name)
        return base + extraNames.filter { !base.contains($0) }
    }

    private var weakNames: Set<String> {
        var counts: [String: Int] = [:]
        for concept in weakConcepts where concept.wrongCount > 0 && concept.mastery < 0.5 && !concept.subject.isEmpty {
            for name in allNames where name == concept.subject || name.contains(concept.subject) || concept.subject.contains(name) {
                counts[name, default: 0] += 1
            }
        }
        return Set(counts.filter { $0.value >= 2 }.keys)
    }

    private var chosen: [ExamPlanner.Subject] {
        allNames.compactMap { name in
            guard let draft = drafts[name], draft.selected else { return nil }
            let size = min(999, Int(draft.size.filter(\.isNumber)) ?? 0)
            return ExamPlanner.Subject(name: name, size: size, important: draft.important, weak: weakNames.contains(name))
        }
    }

    private var startMinute: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        return (parts.hour ?? 18) * 60 + (parts.minute ?? 0)
    }

    private var result: ExamPlanner.Result {
        ExamPlanner.plan(ExamPlanner.Input(today: Date(), examDate: examDate, subjects: chosen, dailyMinutes: dailyMinutes,
                                           startMinuteOfDay: startMinute, offWeekdays: offDays, reviewTail: reviewTail))
    }

    private var visibleItems: [ExamPlanner.Item] { result.items.filter { !excluded.contains($0.id) } }

    private var examName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? L("시험") : trimmed
    }

    private var existing: [ExamPlanStore.Group] { ExamPlanStore.groups(in: plans) }

    private var tomorrow: Date { Date().startOfDay.adding(days: 1) }

    // MARK: 입력 화면

    private var inputPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(L("시험"))
                    group {
                        TextField("시험 이름", text: $name)
                            .font(.pt(.body))
                            .focused($focus, equals: .name)
                            .submitLabel(.done)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 48)
                        divider
                        row("시험 날짜") {
                            DatePicker("", selection: $examDate, in: tomorrow..., displayedComponents: .date)
                                .labelsHidden()
                                .environment(\.locale, AppLanguage.locale)
                        }
                    }
                }
                .staggerIn(index: 0)

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(L("과목"))
                    group { subjectRows }
                }
                .staggerIn(index: 1)

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(L("시간"))
                    group {
                        Stepper(value: $dailyMinutes, in: 30...480, step: 30) {
                            HStack {
                                Text("하루 공부").font(.pt(.body)).foregroundStyle(Palette.ink)
                                Spacer(minLength: 8)
                                Text(TimeText.durationL(minutes: dailyMinutes))
                                    .font(.pt(.body)).monospacedDigit().foregroundStyle(.secondary)
                                    .numberRoll(Double(dailyMinutes))
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        divider
                        row("시작 시각") {
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .environment(\.locale, AppLanguage.locale)
                        }
                        divider
                        VStack(alignment: .leading, spacing: 10) {
                            Text("쉬는 요일").font(.pt(.body)).foregroundStyle(Palette.ink)
                            weekdayChips
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        divider
                        Toggle("마지막 이틀 복습 위주", isOn: $reviewTail)
                            .font(.pt(.body))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 48)
                        divider
                        Toggle("D-Day로 설정", isOn: $setDDay)
                            .font(.pt(.body))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 48)
                    }
                }
                .staggerIn(index: 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .tint(Theme.accent)
        .background { AppBackground() }
        .navigationTitle("시험 계획")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("닫기")
            }
            if !existing.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(existing) { item in
                            Button(role: .destructive) { deleteTarget = item } label: {
                                Label(L("\(label(for: item)) 지우기 · \(item.count)개"), systemImage: "trash")
                            }
                        }
                    } label: { Image(systemName: "ellipsis") }
                    .accessibilityLabel("시험 계획 지우기")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { openPreview() } label: { Text("미리보기") }
                .buttonStyle(.primaryFill)
                .disabled(chosen.isEmpty)
                .opacity(chosen.isEmpty ? 0.4 : 1)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background { Theme.base.opacity(0.94).ignoresSafeArea() }
        }
        .confirmationDialog(L("시험 계획을 지울까요?"), isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible, presenting: deleteTarget) { target in
            Button("지우기", role: .destructive) {
                ExamPlanStore.delete(target.id, plans: plans, context: context)
                Haptics.success()
            }
        } message: { target in
            Text("\(label(for: target)) 플랜 \(target.count)개가 모두 지워져요.")
        }
    }

    private func label(for group: ExamPlanStore.Group) -> String {
        group.name.isEmpty ? L("시험 계획") : group.name
    }

    @ViewBuilder private var subjectRows: some View {
        ForEach(Array(allNames.enumerated()), id: \.element) { index, subject in
            if index > 0 { divider }
            subjectRow(subject)
        }
        if !allNames.isEmpty { divider }
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.pt(size: 17))
                .foregroundStyle(Theme.secondary)
                .frame(width: 24)
            TextField("과목 추가", text: $newName)
                .font(.pt(.body))
                .focused($focus, equals: .newSubject)
                .submitLabel(.done)
                .onSubmit(addSubject)
            if !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("추가", action: addSubject)
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
    }

    private func subjectRow(_ subject: String) -> some View {
        let draft = drafts[subject] ?? Draft()
        return VStack(spacing: 0) {
            Button {
                withAnimation(Motion.quick) {
                    var next = draft
                    next.selected.toggle()
                    drafts[subject] = next
                }
                Haptics.tap()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: draft.selected ? "checkmark.circle.fill" : "circle")
                        .font(.pt(size: 20))
                        .foregroundStyle(draft.selected ? Theme.accent : Color.secondary.opacity(0.6))
                        .frame(width: 24)
                    Text(subject.loc).font(.pt(.body)).foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    if weakNames.contains(subject) {
                        Text("취약").font(.pt(.caption).weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if draft.selected {
                HStack(spacing: 10) {
                    Text("범위 크기").font(.pt(.footnote)).foregroundStyle(.secondary)
                    TextField("선택", text: sizeBinding(subject))
                        .keyboardType(.numberPad)
                        .font(.pt(.subheadline))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .frame(width: 52, height: 32)
                        .background(Theme.secondaryFill, in: .rect(cornerRadius: Radius.field, style: .continuous))
                    Spacer(minLength: 4)
                    PillSegmentedControl(items: [false, true], selection: importantBinding(subject)) { $0 ? L("중요") : L("보통") }
                        .frame(width: 132)
                }
                .padding(.leading, 52)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
    }

    private var weekdayChips: some View {
        let symbols = AppDateFormat.weekdaySymbols
        return HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                let weekday = index + 1
                let isOff = offDays.contains(weekday)
                Button {
                    withAnimation(Motion.quick) {
                        if isOff { offDays.remove(weekday) } else { offDays.insert(weekday) }
                    }
                    Haptics.tap()
                } label: {
                    Text(index < symbols.count ? symbols[index] : "")
                        .font(.pt(.subheadline).weight(isOff ? .semibold : .regular))
                        .foregroundStyle(isOff ? Theme.onAccent : Palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(isOff ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.secondaryFill),
                                    in: .rect(cornerRadius: Radius.field, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOff ? .isSelected : [])
            }
        }
    }

    private func sizeBinding(_ subject: String) -> Binding<String> {
        Binding(get: { drafts[subject]?.size ?? "" },
                set: { value in
                    var next = drafts[subject] ?? Draft()
                    next.size = String(value.filter(\.isNumber).prefix(3))
                    drafts[subject] = next
                })
    }

    private func importantBinding(_ subject: String) -> Binding<Bool> {
        Binding(get: { drafts[subject]?.important ?? false },
                set: { value in
                    var next = drafts[subject] ?? Draft()
                    next.important = value
                    drafts[subject] = next
                })
    }

    // MARK: 미리보기 화면

    private var previewPage: some View {
        let items = visibleItems
        let summary = ExamPlanner.summarize(items)
        let days = Dictionary(grouping: items, by: \.date).sorted { $0.key < $1.key }
            .map { DayGroup(date: $0.key, items: $0.value.sorted { $0.startMinuteOfDay < $1.startMinuteOfDay }) }
        let colors = Dictionary(categories.map { ($0.name, $0.color) }, uniquingKeysWith: { first, _ in first })

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let reason = result.emptyReason {
                    EmptyStateView(symbol: "calendar.badge.exclamationmark", title: reason.text.loc)
                        .softCardBackground()
                } else {
                    summaryCard(summary)
                    if items.isEmpty {
                        EmptyStateView(symbol: "tray", title: L("남은 플랜이 없어요"))
                            .softCardBackground()
                    }
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        dayCard(day.date, day.items, colors: colors)
                            .staggerIn(index: min(index, 7))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("미리보기")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button { create() } label: { Text("플랜 \(items.count)개 만들기") }
                .buttonStyle(.primaryFill)
                .disabled(items.isEmpty)
                .opacity(items.isEmpty ? 0.4 : 1)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background { Theme.base.opacity(0.94).ignoresSafeArea() }
        }
    }

    private func summaryCard(_ summary: ExamPlanner.Summary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(examName)
                .font(.pt(.subheadline))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(summary.count))
                    .font(.pt(size: 36, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .numberRoll(Double(summary.count))
                Text("개")
                    .font(.pt(size: 15))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(L("\(summary.days)일"))
                    .font(.pt(size: 15))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Text(L("하루 평균 \(summary.averageMinutes)분 · 총 \(ExamPlanner.hoursText(minutes: summary.totalMinutes))시간"))
                .font(.pt(.footnote))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            ForEach(notes, id: \.self) { note in
                Text(note).font(.pt(.footnote)).foregroundStyle(.secondary)
            }
        }
        .softCard()
    }

    private var notes: [String] {
        var list: [String] = []
        if !result.droppedSubjects.isEmpty {
            list.append(L("넣지 못한 과목: \(result.droppedSubjects.map(\.loc).joined(separator: ", "))"))
        }
        if result.trimmedEarlyDays { list.append(L("먼 날은 빼고 가까운 날만 짰어요")) }
        if result.ignoredOffDays { list.append(L("쉬는 요일을 빼면 날이 없어서 모두 넣었어요")) }
        return list
    }

    private func dayCard(_ date: Date, _ items: [ExamPlanner.Item], colors: [String: Color]) -> some View {
        let minutes = items.reduce(0) { $0 + $1.minutes }
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(date.ui("M월 d일 EEE"))
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(TimeText.durationL(minutes: minutes))
                    .font(.pt(.footnote))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button {
                    withAnimation(Motion.quick) { excluded.formUnion(items.map(\.id)) }
                    Haptics.tap()
                } label: {
                    Image(systemName: "trash")
                        .font(.pt(size: 15))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("이 날 빼기")
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(minHeight: 44)
            ForEach(items) { item in
                Rectangle().fill(Palette.line).frame(height: 0.5)
                itemRow(item, color: colors[item.subject] ?? Theme.accent)
            }
        }
        .softCardBackground()
    }

    private func itemRow(_ item: ExamPlanner.Item, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(ExamPlanStore.title(for: item))
                    .font(.pt(.body))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("\(clock(item.startMinuteOfDay))–\(clock(item.endMinuteOfDay))")
                    .font(.pt(.footnote))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(TimeText.durationL(minutes: item.minutes))
                .font(.pt(.subheadline))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button {
                withAnimation(Motion.quick) { _ = excluded.insert(item.id) }
                Haptics.tap()
            } label: {
                Image(systemName: "xmark")
                    .font(.pt(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("빼기")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(minHeight: 52)
    }

    private func clock(_ minute: Int) -> String {
        String(format: "%02d:%02d", (minute / 60) % 24, minute % 60)
    }

    // MARK: 부품

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .softCardBackground()
    }

    private var divider: some View {
        Rectangle().fill(Palette.line).frame(height: 0.5).padding(.leading, 16)
    }

    private func row<Control: View>(_ title: LocalizedStringKey, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            Text(title).font(.pt(.body)).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
    }

    // MARK: 동작

    private func addSubject() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !allNames.contains(trimmed) { extraNames.append(trimmed) }
        var draft = drafts[trimmed] ?? Draft()
        draft.selected = true
        drafts[trimmed] = draft
        newName = ""
        focus = nil
        Haptics.tap()
    }

    private func openPreview() {
        focus = nil
        excluded = []
        showPreview = true
    }

    private func create() {
        let items = visibleItems
        guard !items.isEmpty else { return }
        ExamPlanStore.create(name: examName, examDate: examDate, items: items, categories: categories, setDDay: setDDay, context: context)
        Haptics.success()
        dismiss()
    }

    private func setup() {
        guard !didSetup else { return }
        didSetup = true
        #if DEBUG
        if UIShot.matches(.examPlanSheet, .examPlanPreview) {
            name = "기말고사"
            examDate = Date().startOfDay.adding(days: 23)
            for (subject, size, important) in [("국어", "8", false), ("영어", "6", false), ("수학", "12", true)] {
                drafts[subject] = Draft(selected: true, size: size, important: important)
            }
            offDays = [1]
            if UIShot.matches(.examPlanPreview) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showPreview = true }
            }
        }
        #endif
    }
}
