import Foundation
import SwiftData

/// 시험 계획을 플래너에 넣고 지우기. 새 저장 항목 없이 기존 Plan만 쓰고,
/// 메모의 `exam-plan:<UUID>` 줄로 한 시험의 플랜을 한꺼번에 찾음.
@MainActor
enum ExamPlanStore {
    struct Group: Identifiable, Equatable {
        let id: UUID
        let name: String
        let count: Int
        let firstDay: Date
        let lastDay: Date
    }

    /// 플랜 이름 (번역해서): "수학 1/6 범위" · "수학 공부" · "수학 복습"
    static func title(for item: ExamPlanner.Item) -> String {
        let name = item.subject.loc
        if item.isReview { return L("\(name) 복습") }
        return item.parts > 1 ? L("\(name) \(item.part)/\(item.parts) 범위") : L("\(name) 공부")
    }

    /// 계획을 플랜으로 저장. 과목 이름에 맞는 공부 과목이 없으면 새로 만듦. 만든 개수를 돌려줌
    @discardableResult
    static func create(name: String, examDate: Date, items: [ExamPlanner.Item], categories: [PlanCategory],
                       setDDay: Bool, context: ModelContext, calendar: Calendar = .current) -> Int {
        guard !items.isEmpty else { return 0 }
        let id = UUID()
        let note = ExamPlanMarker.note(name: name, id: id)
        var byName: [String: PlanCategory] = [:]
        for category in categories where category.isStudy { byName[category.name] = byName[category.name] ?? category }
        var nextIndex = (categories.map(\.sortIndex).max() ?? -1) + 1

        for item in items {
            let category: PlanCategory
            if let found = byName[item.subject] {
                category = found
            } else {
                let made = PlanCategory(name: item.subject, symbol: "book.fill",
                                        colorHex: Palette.swatches[nextIndex % max(Palette.swatches.count, 1)], isStudy: true, sortIndex: nextIndex)
                context.insert(made)
                byName[item.subject] = made
                nextIndex += 1
                category = made
            }
            let start = calendar.date(bySettingHour: item.startMinuteOfDay / 60, minute: item.startMinuteOfDay % 60, second: 0, of: item.date) ?? item.date
            context.insert(Plan(title: title(for: item), startDate: start, durationMinutes: item.minutes,
                                category: category, note: note, kind: .study, lockApps: false))
        }
        if setDDay {
            let defaults = UserDefaults.standard
            defaults.set(name, forKey: SettingsKey.dDayTitle)
            defaults.set(calendar.startOfDay(for: examDate).timeIntervalSince1970, forKey: SettingsKey.dDayDate)
        }
        try? context.save()
        if setDDay { WidgetSync.update(context: context) }
        PlanScheduler.shared.rescheduleNotifications()
        PlanScheduler.shared.tick()
        return items.count
    }

    /// 지금 있는 시험 계획들 (메모 표시 줄로 묶음)
    static func groups(in plans: [Plan]) -> [Group] {
        var found: [UUID: [Plan]] = [:]
        for plan in plans {
            if let id = ExamPlanMarker.id(in: plan.note) { found[id, default: []].append(plan) }
        }
        return found.map { id, list in
            let days = list.map(\.startDate).sorted()
            let name = list.map { ExamPlanMarker.name(in: $0.note) }.first { !$0.isEmpty } ?? ""
            return Group(id: id, name: name, count: list.count, firstDay: days.first ?? Date(), lastDay: days.last ?? Date())
        }
        .sorted { ($0.firstDay, $0.id.uuidString) < ($1.firstDay, $1.id.uuidString) }
    }

    /// 한 시험 계획의 플랜을 모두 지움. 지운 개수를 돌려줌
    @discardableResult
    static func delete(_ id: UUID, plans: [Plan], context: ModelContext) -> Int {
        let targets = plans.filter { ExamPlanMarker.id(in: $0.note) == id }
        for plan in targets { context.delete(plan) }
        try? context.save()
        PlanScheduler.shared.rescheduleNotifications()
        return targets.count
    }
}
