import SwiftData
import SwiftUI

struct PlanEditorView: View {
    let target: PlanEditorTarget

    private enum TimeField: String, Identifiable {
        case start, end
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanCategory.sortIndex) private var categories: [PlanCategory]

    @AppStorage(SettingsKey.reminderLeadMinutes) private var leadMinutes = 10
    @AppStorage(SettingsKey.autoStartTimer) private var autoStartTimer = true

    @State private var kind: PlanKind = .study
    @State private var title = ""
    @State private var note = ""
    @State private var day = Date()
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var isAllDay = false
    @State private var repeatRule: RepeatRule = .none
    @State private var hasRepeatEnd = false
    @State private var repeatEnd = Date().adding(months: 1)
    @State private var category: PlanCategory?
    @State private var lockApps = false
    @State private var reminderMinutes = 10
    @State private var timeField: TimeField?
    @State private var showDeleteConfirm = false
    @State private var showNewCategory = false
    @State private var lockError: String?
    @State private var didLoad = false
    @FocusState private var titleFocused: Bool

    private var editingPlan: Plan? {
        if case .edit(let plan) = target { return plan }
        return nil
    }

    private var kindCategories: [PlanCategory] {
        categories.filter { $0.isStudy == (kind == .study) }
    }

    var body: some View {
        content.contentFadeIn()
    }

    private var content: some View {
        NavigationStack {
            Form {
                Section {
                    kindPicker
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    TextField(kind == .study ? L("공부할 내용 (예: 수학 문제집 3단원)") : L("할 일 (예: 친구랑 점심)"), text: $title)
                        .font(.pt(.headline))
                        .focused($titleFocused)
                }

                Section(kind == .study ? L("과목") : L("카테고리")) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(kindCategories) { item in
                                let isOn = category?.id == item.id
                                Button { category = item } label: {
                                    Label(item.name, systemImage: item.symbol)
                                        .font(.pt(.subheadline).weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(isOn ? Color.white : Color.primary)
                                        .background(isOn ? item.color : Color.primary.opacity(0.06), in: .capsule)
                                }
                                .buttonStyle(.pressable)
                            }
                            Button { showNewCategory = true } label: {
                                Label(kind == .study ? L("과목 추가") : L("추가"), systemImage: "plus")
                                    .font(.pt(.subheadline).weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.primary.opacity(0.06), in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }

                Section("시간") {
                    DatePicker(selection: $day, displayedComponents: .date) {
                        Label("날짜", systemImage: "calendar")
                    }
                    if kind == .general {
                        Toggle(isOn: $isAllDay.animation()) {
                            Label("하루 종일", systemImage: "sun.max")
                        }
                    }
                    if kind == .study || !isAllDay {
                        timeRow(L("시작"), symbol: "clock", value: startTime) { timeField = .start }
                        timeRow(L("종료"), symbol: "clock.fill", value: endTime) { timeField = .end }
                        LabeledContent(kind == .study ? L("공부 시간") : L("소요 시간")) {
                            Text(TimeText.durationL(minutes: durationMinutes))
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }

                Section("반복") {
                    Picker(selection: $repeatRule.animation()) {
                        ForEach(RepeatRule.allCases) { rule in
                            Text(rule.title).tag(rule)
                        }
                    } label: {
                        Label("반복", systemImage: "repeat")
                    }
                    if repeatRule != .none {
                        Toggle(isOn: $hasRepeatEnd.animation()) {
                            Label("반복 종료일", systemImage: "calendar")
                        }
                        if hasRepeatEnd {
                            DatePicker("종료일", selection: $repeatEnd, in: day..., displayedComponents: .date)
                        }
                    }
                }

                if kind == .study {
                    Section {
                        LabeledContent {
                            Text(autoStartTimer ? L("켜짐") : L("꺼짐 (계정 설정)")).foregroundStyle(.secondary)
                        } label: {
                            Label("시작 시간에 타이머 자동 실행", systemImage: "timer")
                        }
                        Toggle(isOn: lockBinding) {
                            Label {
                                Text("다른 앱 잠금")
                            } icon: {
                                Image(systemName: "lock.fill")
                            }
                        }
                    } header: {
                        Text("공부 설정")
                    } footer: {
                        if lockApps {
                            Text("\(startTime.ui("a h:mm")) ~ \(endTime.ui("a h:mm")) 잠금")
                        } else {
                            Text("\(leadMinutes)분 전 알림 · 타이머 자동 시작")
                        }
                    }
                } else {
                    Section("알림") {
                        Picker(selection: $reminderMinutes) {
                            Text("없음").tag(-1)
                            Text("정시").tag(0)
                            Text("5분 전").tag(5)
                            Text("10분 전").tag(10)
                            Text("30분 전").tag(30)
                            Text("1시간 전").tag(60)
                        } label: {
                            Label("알림", systemImage: "bell")
                        }
                    }
                }

                Section("메모") {
                    TextField("메모 (선택)", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }

                if editingPlan != nil {
                    Section {
                        Button("플랜 삭제", role: .destructive) { showDeleteConfirm = true }
                    }
                }
            }
            .navigationTitle(editingPlan == nil ? L("새 플랜") : L("플랜 수정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Image(systemName: "checkmark") }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(item: $timeField) { field in
                TimePickerSheet(title: field == .start ? L("시작 시간") : L("종료 시간"),
                                initial: field == .start ? startTime : endTime) { picked in
                    apply(picked, to: field)
                }
                .presentationDetents([.height(360)])
            }
            .sheet(isPresented: $showNewCategory) {
                CategoryEditorView(category: nil, nextIndex: categories.count, initialIsStudy: kind == .study)
            }
            .confirmationDialog("플랜을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { delete() }
            } message: {
                if editingPlan?.repeatRule != RepeatRule.none {
                    Text("반복되는 모든 일정이 함께 삭제돼요.")
                }
            }
            .errorAlert($lockError, title: L("앱 잠금"))
            .onAppear(perform: load)
            .onChange(of: categories.count) { oldCount, newCount in
                // 방금 추가한 과목/카테고리를 바로 선택
                if newCount > oldCount, let newest = kindCategories.max(by: { $0.sortIndex < $1.sortIndex }) {
                    category = newest
                }
            }
        }
    }

    // MARK: Pieces

    private var kindPicker: some View {
        HStack(spacing: 10) {
            ForEach(PlanKind.allCases) { item in
                let isOn = kind == item
                Button {
                    withAnimation(.snappy) { switchKind(to: item) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.pt(.title3))
                            .foregroundStyle(isOn ? Theme.accent : Color.secondary)
                        Text(item.title).font(.pt(.headline))
                        Text(item.subtitle).font(.pt(.caption)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(isOn ? Theme.accent.opacity(0.14) : Color.primary.opacity(0.05), in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isOn ? Theme.accent : Color.clear, lineWidth: 2)
                    }
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private func timeRow(_ title: String, symbol: String, value: Date, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol)
                    .foregroundStyle(Color.primary)
                Spacer()
                Text(value.ui("a h:mm"))
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.07), in: .rect(cornerRadius: 10))
            }
        }
    }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { lockApps },
            set: { newValue in
                guard newValue else { lockApps = false; return }
                Task {
                    if await AppLockManager.shared.requestAuthorization() {
                        lockApps = true
                    } else {
                        lockError = L("앱 잠금을 쓰려면 스크린 타임 권한이 필요해요. 설정 > 스크린 타임에서 MOTI를 허용해주세요. (개발자: README의 '앱 잠금 켜기' 참고)")
                    }
                }
            }
        )
    }

    private var durationMinutes: Int {
        let cal = Calendar.current
        let s = cal.dateComponents([.hour, .minute], from: startTime)
        let e = cal.dateComponents([.hour, .minute], from: endTime)
        var minutes = ((e.hour ?? 0) * 60 + (e.minute ?? 0)) - ((s.hour ?? 0) * 60 + (s.minute ?? 0))
        if minutes <= 0 { minutes += 24 * 60 }
        return minutes
    }

    private func apply(_ picked: Date, to field: TimeField) {
        switch field {
        case .start:
            // 시작을 바꾸면 길이를 유지한 채 종료도 함께 이동
            let length = durationMinutes
            startTime = picked
            endTime = picked.addingTimeInterval(Double(length) * 60)
        case .end:
            endTime = picked
        }
    }

    private func switchKind(to newKind: PlanKind) {
        guard kind != newKind else { return }
        kind = newKind
        category = kindCategories.first
        if newKind == .study { isAllDay = false } else { lockApps = false }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        switch target {
        case .new(let date):
            day = date.startOfDay
            let cal = Calendar.current
            let thisHour = cal.date(from: cal.dateComponents([.year, .month, .day, .hour], from: Date())) ?? Date()
            startTime = thisHour.addingTimeInterval(3600)
            endTime = startTime.addingTimeInterval(3600)
            kind = .study
            category = categories.first(where: \.isStudy)
            titleFocused = true

        case .edit(let plan):
            kind = plan.kind
            title = plan.title
            note = plan.note
            day = plan.startDate.startOfDay
            startTime = plan.startDate
            endTime = plan.startDate.addingTimeInterval(Double(plan.durationMinutes) * 60)
            isAllDay = plan.isAllDay
            repeatRule = plan.repeatRule
            hasRepeatEnd = plan.repeatEnd != nil
            repeatEnd = plan.repeatEnd ?? day.adding(months: 1)
            category = plan.category
            lockApps = plan.lockApps
            reminderMinutes = plan.reminderMinutes
        }
    }

    private func save() {
        let allDay = kind == .general && isAllDay
        let start = allDay ? day.startOfDay : day.combined(withTime: startTime)
        let duration = allDay ? 24 * 60 : durationMinutes
        let end: Date? = (repeatRule != .none && hasRepeatEnd) ? repeatEnd : nil
        let trimmed = title.trimmingCharacters(in: .whitespaces)

        if let plan = editingPlan {
            plan.title = trimmed
            plan.note = note
            plan.startDate = start
            plan.durationMinutes = duration
            plan.isAllDay = allDay
            plan.repeatRule = repeatRule
            plan.repeatEnd = end
            plan.category = category
            plan.kind = kind
            plan.lockApps = kind == .study && lockApps
            plan.reminderMinutes = reminderMinutes
        } else {
            let plan = Plan(title: trimmed, startDate: start, durationMinutes: duration, isAllDay: allDay,
                            repeatRule: repeatRule, repeatEnd: end, category: category, note: note,
                            kind: kind, lockApps: lockApps, reminderMinutes: reminderMinutes)
            context.insert(plan)
        }
        try? context.save()
        PlanScheduler.shared.rescheduleNotifications()
        PlanScheduler.shared.tick()
        Haptics.success()
        dismiss()
    }

    private func delete() {
        if let plan = editingPlan {
            context.delete(plan)
            try? context.save()
            PlanScheduler.shared.rescheduleNotifications()
        }
        dismiss()
    }
}

/// 휠로 시간을 고르고 "완료"를 눌러야 반영되는 시간 선택 시트
struct TimePickerSheet: View {
    let title: String
    let initial: Date
    var onDone: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                DatePicker("", selection: $value, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, AppLanguage.locale)
            }
            .padding(.horizontal)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        onDone(value)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .onAppear { value = initial }
    }
}
