import SwiftUI

/// 홈의 학교 카드: 학교가 있으면 "오늘 시간표" 한 줄 + "오늘 급식", 없으면 설정 안내 한 줄
/// 꾹 누르면 홈에서 숨기고, 계정 → 학교 정보에서 다시 켤 수 있어요
struct SchoolHomeSection: View {
    @AppStorage(SettingsKey.schoolSelection) private var raw = ""
    @AppStorage(SettingsKey.schoolHomeHidden) private var hidden = false

    var body: some View {
        if !hidden {
            Group {
                if let selection = SchoolSelection.decode(raw) {
                    SchoolTodayCard(selection: selection)
                } else {
                    NavigationLink { SchoolSetupView() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "graduationcap")
                                .font(.pt(size: 18, weight: .regular))
                                .foregroundStyle(Theme.secondary)
                            Text("학교를 설정하면 시간표와 급식이 나와요")
                                .font(.pt(.subheadline))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer(minLength: 4)
                            Text("설정").font(.pt(.subheadline).weight(.semibold)).foregroundStyle(Theme.accent)
                        }
                        .softCard(padding: 14)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .contextMenu {
                Button { hidden = true } label: { Label("홈에서 숨기기", systemImage: "eye.slash") }
            }
        }
    }
}

private struct SchoolTodayCard: View {
    let selection: SchoolSelection

    @State private var timetable: TimetableWeek?
    @State private var meals: MealRange?

    /// 오늘이 평일이면 오늘, 주말이면 다음 월요일
    private var target: (ymd: String, isToday: Bool, weekStart: String) {
        let now = Date()
        let index = NeisDate.weekdayIndex(now)
        if index < 5 { return (NeisDate.ymd(now), true, NeisDate.weekStart(containing: now)) }
        let monday = NeisDate.weekStart(offset: 1, from: now)
        return (monday, false, monday)
    }

    var body: some View {
        let t = target
        NavigationLink { SchoolView(initialMode: .timetable) } label: {
            VStack(alignment: .leading, spacing: 0) {
                timetableRow(t)
                Rectangle().fill(Palette.line).frame(height: 0.5).padding(.vertical, 12)
                mealRows(t)
            }
            .softCard(padding: 14)
        }
        .buttonStyle(.pressable)
        .task(id: "\(selection.school.id)|\(selection.grade)|\(selection.classNum)|\(selection.department)|\(t.weekStart)") {
            await load(weekStart: t.weekStart)
        }
    }

    private func timetableRow(_ t: (ymd: String, isToday: Bool, weekStart: String)) -> some View {
        let items = timetable?.day(t.ymd) ?? []
        let holiday = timetable?.holidayText(t.ymd) ?? ""
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t.isToday ? L("오늘 시간표") : L("다음 시간표"))
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(selection.school.name)
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if !holiday.isEmpty {
                Text(holiday).font(.pt(.subheadline)).foregroundStyle(.secondary)
            } else if items.isEmpty {
                Text(timetable == nil ? " " : L("시간표가 없어요"))
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
            } else {
                Text(items.map { "\($0.period) \($0.subject)" }.joined(separator: " · "))
                    .font(.pt(.subheadline))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private func mealRows(_ t: (ymd: String, isToday: Bool, weekStart: String)) -> some View {
        let day = meals?.day(t.ymd)
        let meal = day?.meal(.lunch) ?? day?.meals.first
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t.isToday ? L("오늘 급식") : L("다음 급식"))
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                if let meal, meal.kind != .lunch {
                    Text(meal.kind.title.loc).font(.pt(.footnote)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let meal, !meal.calories.isEmpty {
                    Text(meal.calories.replacingOccurrences(of: "Kcal", with: "kcal"))
                        .font(.pt(.footnote))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            if let meal {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(meal.dishes.prefix(4).enumerated()), id: \.offset) { _, dish in
                        Text(dish.name).font(.pt(.subheadline)).foregroundStyle(Palette.ink).lineLimit(1)
                    }
                    if meal.dishes.count > 4 {
                        Text("외 \(meal.dishes.count - 4)가지").font(.pt(.footnote)).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(meals == nil ? " " : L("급식이 없어요")).font(.pt(.subheadline)).foregroundStyle(.secondary)
            }
        }
    }

    private func load(weekStart: String) async {
        async let tt = try? SchoolStore.shared.timetable(for: selection, weekStart: weekStart)
        async let ml = try? SchoolStore.shared.meals(for: selection.school, weekStart: weekStart)
        let (a, b) = await (tt, ml)
        if Task.isCancelled { return }
        timetable = a?.value
        meals = b?.value
    }
}
