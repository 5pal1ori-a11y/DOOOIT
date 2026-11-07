import SwiftUI

/// 학교 글자 도우미 (번역 포함)
enum SchoolText {
    static func errorMessage(_ error: Error) -> String {
        switch error as? NeisError {
        case .network?: return L("인터넷에 연결되지 않았어요")
        case .limited?: return L("지금은 불러올 수 없어요")
        default: return L("불러오지 못했어요")
        }
    }

    /// "마지막 업데이트 3시간 전"
    static func updated(_ savedAt: Date, now: Date = Date()) -> String {
        switch NeisCache.age(savedAt: savedAt, now: now) {
        case .justNow: return L("마지막 업데이트 방금")
        case .minutes(let n): return L("마지막 업데이트 \(n)분 전")
        case .hours(let n): return L("마지막 업데이트 \(n)시간 전")
        case .days(let n): return L("마지막 업데이트 \(n)일 전")
        }
    }

    /// "11월 3일 – 7일"
    static func weekTitle(_ weekStart: String) -> String {
        guard let start = NeisDate.date(weekStart), let endYMD = NeisDate.addDays(weekStart, 4), let end = NeisDate.date(endYMD) else { return "" }
        let startText = start.ui("M월 d일")
        let sameMonth = NeisDate.calendar.component(.month, from: start) == NeisDate.calendar.component(.month, from: end)
        return startText + " – " + (sameMonth ? end.ui("d일") : end.ui("M월 d일"))
    }
}

/// 학교: 시간표 · 급식 (학교 정보가 있으면 자동으로 불러와요)
struct SchoolView: View {
    enum Mode: Hashable { case timetable, meal }

    @AppStorage(SettingsKey.schoolSelection) private var raw = ""
    @State var mode: Mode = .timetable

    private var selection: SchoolSelection? { SchoolSelection.decode(raw) }

    init(initialMode: Mode = .timetable) {
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        Group {
            if let selection {
                content(selection)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        EmptyStateView(symbol: "graduationcap", title: L("학교를 설정해 주세요"))
                        NavigationLink { SchoolSetupView() } label: { Text("학교 설정") }
                            .buttonStyle(.primaryFill)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                }
            }
        }
        .background { AppBackground() }
        .navigationTitle("학교")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SchoolSetupView() } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("학교 설정")
            }
        }
    }

    private func content(_ selection: SchoolSelection) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selection.school.name)
                        .font(.pt(size: 20, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(L("\(selection.grade)학년 \(selection.classNum)반") + (selection.department.isEmpty ? "" : " · " + selection.department))
                        .font(.pt(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 2)

                PillSegmentedControl(items: [Mode.timetable, Mode.meal], selection: $mode) {
                    $0 == .timetable ? L("시간표") : L("급식")
                }

                switch mode {
                case .timetable: TimetablePane(selection: selection)
                case .meal: MealPane(selection: selection)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - 주 이동 줄

struct WeekBar: View {
    @Binding var offset: Int
    let weekStart: String

    var body: some View {
        HStack(spacing: 4) {
            Button { offset -= 1 } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 36)
            }
            .accessibilityLabel("이전 주")
            Spacer(minLength: 0)
            Button { offset = 0 } label: {
                VStack(spacing: 0) {
                    Text(SchoolText.weekTitle(weekStart))
                        .font(.pt(.subheadline).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                    Text(offset == 0 ? L("이번 주") : L("이번 주로 돌아가기"))
                        .font(.pt(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(offset == 0)
            Spacer(minLength: 0)
            Button { offset += 1 } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 36)
            }
            .accessibilityLabel("다음 주")
        }
        .font(.pt(.subheadline).weight(.semibold))
        .foregroundStyle(Palette.ink)
        .buttonStyle(.plain)
    }
}

// MARK: - 시간표

struct TimetablePane: View {
    let selection: SchoolSelection

    @State private var offset = 0
    @State private var loaded: SchoolStore.Loaded<TimetableWeek>?
    @State private var failure: String?
    @State private var loading = false

    private var weekStart: String { NeisDate.weekStart(offset: offset, from: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WeekBar(offset: $offset, weekStart: weekStart)
            if let week = loaded?.value, week.weekStart == weekStart {
                if week.isEmpty {
                    EmptyStateView(symbol: "calendar", title: weekHoliday(week) ?? L("이 주 시간표가 없어요"))
                        .softCard()
                } else {
                    TimetableGrid(week: week, kind: selection.school.kind)
                        .softCard(padding: 12)
                    notes(week)
                }
            } else if loading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 60)
            } else if let failure {
                EmptyStateView(symbol: "wifi.slash", title: failure)
                    .softCard()
            }
            if let loaded, loaded.value.weekStart == weekStart {
                Text(loaded.offline ? SchoolText.updated(loaded.savedAt) + " · " + L("오프라인") : SchoolText.updated(loaded.savedAt))
                    .font(.pt(.caption))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 2)
            }
        }
        .animation(Motion.quick, value: loading)
        .task(id: "\(selection.school.id)|\(selection.grade)|\(selection.classNum)|\(selection.department)|\(weekStart)") {
            await load(force: false)
        }
        .refreshable { await load(force: true) }
    }

    /// 이 주 칸이 모두 쉬는 날 글이면 그 글 ("재량휴업일" …)
    private func weekHoliday(_ week: TimetableWeek) -> String? {
        week.cells.first { NeisParser.isHolidayText($0.subject) }?.subject
    }

    @ViewBuilder
    private func notes(_ week: TimetableWeek) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if week.departments.count > 1 && selection.department.isEmpty {
                Text("학교 설정에서 학과를 골라요")
            }
            if week.incomplete == true {
                Text("일부 교시가 없어요")
            }
        }
        .font(.pt(.footnote))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 2)
    }

    private func load(force: Bool) async {
        let start = weekStart
        if loaded?.value.weekStart != start { loaded = nil }
        loading = loaded == nil
        failure = nil
        do {
            let result = try await SchoolStore.shared.timetable(for: selection, weekStart: start, refresh: force)
            if Task.isCancelled { return }
            loaded = result
        } catch is CancellationError {
            return
        } catch {
            failure = SchoolText.errorMessage(error)
        }
        loading = false
    }
}

/// 월~금(토요일 수업이 있으면 토까지) × 교시 표. 오늘 열은 머리글만 강조색, 지금 교시 칸은 옅은 바탕
struct TimetableGrid: View {
    let week: TimetableWeek
    let kind: SchoolKind

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            grid(now: timeline.date)
        }
    }

    private func grid(now: Date) -> some View {
        let days = NeisDate.weekDays(start: week.weekStart, includeSaturday: week.hasSaturday)
        let periods = max(week.maxPeriod, 1)
        let today = NeisDate.ymd(now)
        let nowPeriod = NeisPeriodClock.currentPeriod(minute: NeisPeriodClock.minuteOfDay(now), kind: kind, maxPeriod: periods)

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 24, height: 1)
                ForEach(days, id: \.self) { ymd in
                    let isToday = ymd == today
                    VStack(spacing: 1) {
                        Text((NeisDate.weekdayIndex(ymd: ymd).map { NeisDate.weekdayShort[$0] } ?? "").loc)
                            .font(.pt(.footnote).weight(.semibold))
                        Text("\(NeisDate.dayNumber(ymd) ?? 0)")
                            .font(.pt(.caption2))
                            .monospacedDigit()
                    }
                    .foregroundStyle(isToday ? Theme.accent : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                }
            }
            ForEach(1...periods, id: \.self) { period in
                Rectangle().fill(Palette.line).frame(height: 0.5)
                HStack(spacing: 0) {
                    Text("\(period)")
                        .font(.pt(.caption2))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .frame(width: 24)
                    ForEach(days, id: \.self) { ymd in
                        cell(ymd: ymd, period: period, isNow: ymd == today && nowPeriod == period)
                    }
                }
            }
        }
    }

    private func cell(ymd: String, period: Int, isNow: Bool) -> some View {
        // 쉬는 날은 첫 칸에만 안내 글을 한 번 보여 줌
        let isHolidayDay = week.isHolidayDay(ymd)
        let subject = isHolidayDay ? (period == 1 ? week.holidayText(ymd) : "") : week.subject(ymd, period: period)
        let holiday = isHolidayDay
        return Text(subject.isEmpty ? " " : subject)
            .font(.pt(size: 12, weight: isNow ? .semibold : .regular))
            .foregroundStyle(holiday ? Color.secondary : Palette.ink)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 2)
            .background {
                if isNow { RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.secondaryFill).padding(1) }
            }
    }
}

// MARK: - 급식

struct MealPane: View {
    let selection: SchoolSelection

    @AppStorage(SettingsKey.schoolAllergyLegend) private var showLegend = false
    @State private var offset = 0
    @State private var day = NeisDate.ymd(Date())
    @State private var kind: MealKind = .lunch
    @State private var loaded: SchoolStore.Loaded<MealRange>?
    @State private var failure: String?
    @State private var loading = false

    private var weekStart: String { NeisDate.weekStart(offset: offset, from: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WeekBar(offset: $offset, weekStart: weekStart)
            dayBar
            if let range = loaded?.value, range.fromYMD == weekStart {
                mealCard(range)
            } else if loading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 60)
            } else if let failure {
                EmptyStateView(symbol: "wifi.slash", title: failure).softCard()
            }
            if let loaded, loaded.value.fromYMD == weekStart {
                Text(loaded.offline ? SchoolText.updated(loaded.savedAt) + " · " + L("오프라인") : SchoolText.updated(loaded.savedAt))
                    .font(.pt(.caption))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 2)
            }
        }
        .animation(Motion.quick, value: "\(day)-\(kind)-\(loading)")
        .task(id: "\(selection.school.id)|\(weekStart)") { await load(force: false) }
        .refreshable { await load(force: true) }
        .onChange(of: offset) { _, _ in
            // 주를 옮기면 그 주의 첫 평일 (이번 주면 오늘)
            let days = NeisDate.weekDays(start: weekStart)
            let today = NeisDate.ymd(Date())
            day = days.contains(today) ? today : (days.first ?? day)
        }
        .onAppear {
            let days = NeisDate.weekDays(start: weekStart, includeSaturday: false)
            if !days.contains(day) { day = days.first ?? day }
        }
    }

    // 요일 고르기: 월~금 (선택한 날만 진하게, 오늘 날짜는 강조색 글자)
    private var dayBar: some View {
        let days = NeisDate.weekDays(start: weekStart)
        let today = NeisDate.ymd(Date())
        return HStack(spacing: 4) {
            ForEach(days, id: \.self) { ymd in
                let selected = ymd == day
                Button {
                    withAnimation(Motion.quick) { day = ymd }
                    Haptics.tap()
                } label: {
                    VStack(spacing: 2) {
                        Text((NeisDate.weekdayIndex(ymd: ymd).map { NeisDate.weekdayShort[$0] } ?? "").loc)
                            .font(.pt(.footnote).weight(selected ? .semibold : .regular))
                        Text("\(NeisDate.dayNumber(ymd) ?? 0)")
                            .font(.pt(.subheadline).weight(selected ? .bold : .regular))
                            .monospacedDigit()
                    }
                    .foregroundStyle(ymd == today ? Theme.accent : (selected ? Palette.ink : Color.secondary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.card)
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.secondaryFill, in: .rect(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func mealCard(_ range: MealRange) -> some View {
        let mealDay = range.day(day)
        let kinds = MealKind.allCases.filter { mealDay?.meal($0) != nil }
        if let mealDay, !kinds.isEmpty {
            let shown = kinds.contains(kind) ? kind : (kinds.contains(.lunch) ? .lunch : kinds[0])
            VStack(alignment: .leading, spacing: 12) {
                if kinds.count > 1 {
                    PillSegmentedControl(items: kinds, selection: Binding(get: { shown }, set: { kind = $0 })) { $0.title.loc }
                }
                if let meal = mealDay.meal(shown) {
                    MealCard(meal: meal, showLegend: $showLegend)
                }
            }
        } else if loading {
            EmptyView()
        } else {
            EmptyStateView(symbol: "fork.knife", title: L("이날 급식이 없어요"))
                .softCard()
        }
    }

    private func load(force: Bool) async {
        let start = weekStart
        if loaded?.value.fromYMD != start { loaded = nil }
        loading = loaded == nil
        failure = nil
        do {
            let result = try await SchoolStore.shared.meals(for: selection.school, weekStart: start, refresh: force)
            if Task.isCancelled { return }
            loaded = result
        } catch is CancellationError {
            return
        } catch {
            failure = SchoolText.errorMessage(error)
        }
        loading = false
    }
}

/// 한 끼: 요리 줄들(알레르기 번호는 작은 회색) · 열량/영양 한 줄 · 알레르기 안내 펼침
struct MealCard: View {
    let meal: Meal
    @Binding var showLegend: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(meal.dishes.enumerated()), id: \.offset) { index, dish in
                if index > 0 { Rectangle().fill(Palette.line).frame(height: 0.5) }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(dish.name)
                        .font(.pt(.body))
                        .foregroundStyle(Palette.ink)
                    if !dish.allergies.isEmpty {
                        Text(dish.allergies.map(String.init).joined(separator: "."))
                            .font(.pt(.caption2))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 9)
            }
            if !nutritionLine.isEmpty {
                Rectangle().fill(Palette.line).frame(height: 0.5)
                Text(nutritionLine)
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.top, 10)
            }
            Rectangle().fill(Palette.line).frame(height: 0.5).padding(.top, 10)
            Button {
                withAnimation(Motion.quick) { showLegend.toggle() }
            } label: {
                HStack {
                    Text("알레르기 번호 보기").font(.pt(.footnote)).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: showLegend ? "chevron.up" : "chevron.down")
                        .font(.pt(.caption).weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showLegend {
                Text(Allergen.legend.map { "\($0.number) \($0.name.loc)" }.joined(separator: " · "))
                    .font(.pt(.caption))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .softCard()
    }

    /// "696.8 kcal · 탄수화물 95.3g · 단백질 29.0g · 지방 20.7g"
    private var nutritionLine: String {
        var parts: [String] = []
        let calories = meal.calories.replacingOccurrences(of: "Kcal", with: "kcal")
        if !calories.isEmpty { parts.append(calories) }
        for (label, short) in [("탄수화물", "탄수화물"), ("단백질", "단백질"), ("지방", "지방")] {
            if let line = meal.nutrients.first(where: { $0.label.hasPrefix(label) }) {
                parts.append("\(short.loc) \(line.value)g")
            }
        }
        return parts.joined(separator: " · ")
    }
}
