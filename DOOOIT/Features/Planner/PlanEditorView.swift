import SwiftData
import SwiftUI

struct PlanEditorView: View {
    let target: PlanEditorTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanCategory.sortIndex) private var categories: [PlanCategory]

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
    @State private var showDeleteConfirm = false
    @State private var showCategories = false
    @State private var didLoad = false
    @FocusState private var titleFocused: Bool

    private var editingPlan: Plan? {
        if case .edit(let plan) = target { return plan }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("할 일 (예: 수학 공부)", text: $title)
                        .font(.headline)
                        .focused($titleFocused)

                    Picker(selection: $category) {
                        Text("없음").tag(PlanCategory?.none)
                        ForEach(categories) { item in
                            Label(item.name, systemImage: item.symbol)
                                .tag(PlanCategory?.some(item))
                        }
                    } label: {
                        Label("카테고리", systemImage: "tag")
                    }

                    Button { showCategories = true } label: {
                        Label("카테고리 관리", systemImage: "slider.horizontal.3")
                    }
                } footer: {
                    if category?.isStudy == true {
                        Label("공부 카테고리예요. 시작 \(AppSettings.leadMinutes)분 전에 다이나믹 아일랜드로 알려드리고, 시간이 되면 공부 타이머가 자동으로 시작돼요.",
                              systemImage: "timer")
                    }
                }

                Section("시간") {
                    DatePicker(selection: $day, displayedComponents: .date) {
                        Label("날짜", systemImage: "calendar")
                    }
                    Toggle(isOn: $isAllDay.animation()) {
                        Label("하루 종일", systemImage: "sun.max")
                    }
                    if !isAllDay {
                        DatePicker(selection: $startTime, displayedComponents: .hourAndMinute) {
                            Label("시작", systemImage: "clock")
                        }
                        DatePicker(selection: $endTime, displayedComponents: .hourAndMinute) {
                            Label("종료", systemImage: "clock.badge.checkmark")
                        }
                        LabeledContent("소요 시간", value: TimeText.duration(minutes: durationMinutes))
                            .foregroundStyle(.secondary)
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
                            Label("반복 종료일", systemImage: "calendar.badge.minus")
                        }
                        if hasRepeatEnd {
                            DatePicker("종료일", selection: $repeatEnd, in: day..., displayedComponents: .date)
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
            .navigationTitle(editingPlan == nil ? "새 플랜" : "플랜 수정")
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
            .confirmationDialog("플랜을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { delete() }
            } message: {
                if editingPlan?.repeatRule != RepeatRule.none {
                    Text("반복되는 모든 일정이 함께 삭제돼요.")
                }
            }
            .sheet(isPresented: $showCategories) {
                NavigationStack { CategoryManagerView() }
            }
            .onAppear(perform: load)
        }
    }

    private var durationMinutes: Int {
        let cal = Calendar.current
        let s = cal.dateComponents([.hour, .minute], from: startTime)
        let e = cal.dateComponents([.hour, .minute], from: endTime)
        var minutes = ((e.hour ?? 0) * 60 + (e.minute ?? 0)) - ((s.hour ?? 0) * 60 + (s.minute ?? 0))
        if minutes <= 0 { minutes += 24 * 60 }
        return minutes
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        switch target {
        case .new(let date):
            day = date.startOfDay
            // 다음 정시로 기본 설정
            let cal = Calendar.current
            let thisHour = cal.date(from: cal.dateComponents([.year, .month, .day, .hour], from: Date())) ?? Date()
            let nextHour = thisHour.addingTimeInterval(3600)
            startTime = nextHour
            endTime = nextHour.addingTimeInterval(3600)
            category = categories.first(where: \.isStudy)
            titleFocused = true

        case .edit(let plan):
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
        }
    }

    private func save() {
        let start = isAllDay ? day.startOfDay : day.combined(withTime: startTime)
        let duration = isAllDay ? 24 * 60 : durationMinutes
        let end: Date? = (repeatRule != .none && hasRepeatEnd) ? repeatEnd : nil
        let trimmed = title.trimmingCharacters(in: .whitespaces)

        if let plan = editingPlan {
            plan.title = trimmed
            plan.note = note
            plan.startDate = start
            plan.durationMinutes = duration
            plan.isAllDay = isAllDay
            plan.repeatRule = repeatRule
            plan.repeatEnd = end
            plan.category = category
        } else {
            let plan = Plan(title: trimmed, startDate: start, durationMinutes: duration, isAllDay: isAllDay,
                            repeatRule: repeatRule, repeatEnd: end, category: category, note: note)
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
