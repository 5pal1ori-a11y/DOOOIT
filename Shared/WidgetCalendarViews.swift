import SwiftUI
import WidgetKit

// 캘린더 위젯: 이번 달 공부 달력(공부한 날 진하게 · 일정 점) · 이번 주 일정 띠

// MARK: - 이번 달 공부 달력

struct MonthCalendarWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    var date = Date()

    private var calendar: Calendar { .current }
    private var grid: [Date] { WidgetMath.monthGrid(for: date) }

    private var monthDays: [Date] { grid.filter { calendar.isDate($0, equalTo: date, toGranularity: .month) } }
    private var monthMinutes: Int { monthDays.reduce(0) { $0 + snapshot.minutes(on: $1) } }
    private var studiedDays: Int { monthDays.filter { snapshot.minutes(on: $0) > 0 }.count }
    private var monthTitle: String { "\(calendar.component(.month, from: date))월" }

    var body: some View {
        if family == .systemMedium {
            medium
        } else {
            large
        }
    }

    // MARK: 큰 위젯: 칸마다 날짜 · 진하기 · 일정 점, 누르면 그날 플래너

    private var large: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(monthTitle).font(.title3.weight(.heavy))
                Text("공부 달력").font(.caption.weight(.bold)).foregroundStyle(snapshot.accent)
                Spacer()
                Label(WidgetMath.compactHours(monthMinutes), systemImage: "clock.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary).monospacedDigit()
                Label("\(studiedDays)일", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            weekdayRow(size: 11)
            let rows = grid.count / 7
            VStack(spacing: 3) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = grid[row * 7 + col]
                            Link(destination: WidgetLink.planner(WidgetMath.dayKey(day))) {
                                largeCell(day, weekday: col)
                            }
                        }
                    }
                }
            }
            legend
        }
    }

    private func largeCell(_ day: Date, weekday: Int) -> some View {
        let key = WidgetMath.dayKey(day)
        let stat = snapshot.day(key)
        let inMonth = calendar.isDate(day, equalTo: date, toGranularity: .month)
        let isToday = calendar.isDate(day, inSameDayAs: date)
        let minutes = snapshot.minutes(on: day)
        let level = inMonth ? WidgetMath.heatLevel(minutes: minutes, goal: snapshot.goalMinutes) : 0
        let strong = level >= 3
        return VStack(spacing: 3) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 13, weight: isToday ? .heavy : .semibold, design: .rounded))
                .foregroundStyle(strong ? Color.white : (weekday == 0 ? WidgetStyle.sunday : Color.primary))
                .monospacedDigit()
            HStack(spacing: 2) {
                ForEach(Array((stat?.colors ?? []).prefix(3).enumerated()), id: \.offset) { _, hex in
                    Circle()
                        .fill(WidgetSnapshot.color(hex))
                        .overlay(Circle().stroke(.white.opacity(strong ? 0.9 : 0), lineWidth: 1))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WidgetStyle.heat(level, accent: snapshot.accent), in: .rect(cornerRadius: 9))
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 9).strokeBorder(strong ? Color.primary.opacity(0.8) : snapshot.accent, lineWidth: 2)
            }
        }
        .opacity(inMonth ? 1 : 0.3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cellLabel(day, minutes: minutes, plans: stat?.planCount ?? 0, isToday: isToday))
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("적게").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3)
                    .fill(WidgetStyle.heat(level, accent: snapshot.accent))
                    .frame(width: 10, height: 10)
            }
            Text("많이").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }

    // MARK: 중간 위젯: 왼쪽 요약 + 오른쪽 작은 달력

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("공부 달력").font(.caption.weight(.heavy)).foregroundStyle(snapshot.accent)
                Text(monthTitle).font(.system(size: 30, weight: .black, design: .rounded))
                Spacer(minLength: 0)
                summary("이번 달", WidgetMath.compactHours(monthMinutes))
                summary("공부한 날", "\(studiedDays)일")
                Label("\(snapshot.streak(at: date))일 연속", systemImage: "flame.fill")
                    .font(.caption2.weight(.bold)).foregroundStyle(WidgetStyle.flame)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 3) {
                weekdayRow(size: 8)
                let rows = grid.count / 7
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { col in
                            smallCell(grid[row * 7 + col], weekday: col)
                        }
                    }
                }
            }
            .frame(width: 166)
        }
    }

    private func smallCell(_ day: Date, weekday: Int) -> some View {
        let inMonth = calendar.isDate(day, equalTo: date, toGranularity: .month)
        let isToday = calendar.isDate(day, inSameDayAs: date)
        let minutes = snapshot.minutes(on: day)
        let level = inMonth ? WidgetMath.heatLevel(minutes: minutes, goal: snapshot.goalMinutes) : 0
        let hasPlan = (snapshot.day(WidgetMath.dayKey(day))?.planCount ?? 0) > 0
        return Text(inMonth ? "\(calendar.component(.day, from: day))" : "")
            .font(.system(size: 8.5, weight: isToday ? .heavy : .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(level >= 3 ? Color.white : (weekday == 0 ? WidgetStyle.sunday : Color.primary.opacity(0.8)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(inMonth ? WidgetStyle.heat(level, accent: snapshot.accent) : .clear, in: .rect(cornerRadius: 4))
            .overlay {
                if isToday { RoundedRectangle(cornerRadius: 4).strokeBorder(level >= 3 ? Color.primary : snapshot.accent, lineWidth: 1.5) }
            }
            .overlay(alignment: .topTrailing) {
                if inMonth && hasPlan {
                    Circle().fill(level >= 3 ? Color.white : snapshot.accent).frame(width: 3, height: 3).padding(2)
                }
            }
            .accessibilityHidden(!inMonth)
            .accessibilityLabel(cellLabel(day, minutes: minutes, plans: snapshot.day(WidgetMath.dayKey(day))?.planCount ?? 0, isToday: isToday))
    }

    private func summary(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.headline.weight(.heavy)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }

    private func weekdayRow(size: CGFloat) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                Text(WidgetStyle.weekdays[i])
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(WidgetStyle.weekdayColor(i, accent: snapshot.accent))
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func cellLabel(_ day: Date, minutes: Int, plans: Int, isToday: Bool) -> String {
        var parts = [day.formatted(.dateTime.month().day())]
        if isToday { parts.append("오늘") }
        parts.append(minutes > 0 ? "\(WidgetMath.durationText(minutes)) 공부" : "공부 안 함")
        if plans > 0 { parts.append("일정 \(plans)개") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - 이번 주 일정 띠

struct WeekPlansWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    var date = Date()

    private var calendar: Calendar { .current }
    private var week: [Date] { WidgetMath.week(containing: date) }

    private var rangeText: String {
        guard let first = week.first, let last = week.last else { return "" }
        let m1 = calendar.component(.month, from: first), m2 = calendar.component(.month, from: last)
        let d1 = calendar.component(.day, from: first), d2 = calendar.component(.day, from: last)
        return m1 == m2 ? "\(m1)월 \(d1)–\(d2)일" : "\(m1)/\(d1)–\(m2)/\(d2)"
    }

    private func items(_ day: Date) -> [WidgetSnapshot.PlanItem] {
        snapshot.day(WidgetMath.dayKey(day))?.items ?? []
    }

    private func count(_ day: Date) -> Int {
        snapshot.day(WidgetMath.dayKey(day))?.planCount ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "이번 주", symbol: "calendar", trailing: rangeText, accent: snapshot.accent)
            if family == .systemLarge {
                largeList
            } else {
                columns
            }
        }
    }

    // MARK: 중간: 요일 7칸, 칸마다 일정 이름 띠

    private var columns: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                Link(destination: WidgetLink.planner(WidgetMath.dayKey(day))) {
                    VStack(spacing: 4) {
                        dayBadge(day, weekday: index, compact: true)
                        let list = items(day)
                        ForEach(Array(list.prefix(3).enumerated()), id: \.offset) { _, item in
                            chip(item)
                        }
                        if count(day) > 3 {
                            Text("+\(count(day) - 3)").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(dayLabel(day))
                }
            }
        }
    }

    private func chip(_ item: WidgetSnapshot.PlanItem) -> some View {
        let color = WidgetSnapshot.color(item.colorHex)
        return Text(item.title)
            .font(.system(size: 8.5, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.leading, 4)
            .padding(.trailing, 1)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(item.isDone ? .secondary : .primary)
            .strikethrough(item.isDone)
            .background(color.opacity(item.isDone ? 0.1 : 0.22), in: .rect(cornerRadius: 4))
            .overlay(alignment: .leading) {
                Rectangle().fill(color).frame(width: 2).clipShape(.rect(cornerRadius: 1))
            }
    }

    // MARK: 큰: 하루 한 줄씩

    private var largeList: some View {
        VStack(spacing: 4) {
            ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                let isToday = calendar.isDate(day, inSameDayAs: date)
                Link(destination: WidgetLink.planner(WidgetMath.dayKey(day))) {
                    HStack(spacing: 10) {
                        dayBadge(day, weekday: index, compact: false)
                            .frame(width: 34)
                        let list = items(day)
                        if list.isEmpty {
                            Text("일정 없음").font(.caption).foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(list.prefix(2).enumerated()), id: \.offset) { _, item in
                                    HStack(spacing: 5) {
                                        Circle().fill(WidgetSnapshot.color(item.colorHex)).frame(width: 6, height: 6)
                                        Text(item.title).font(.caption.weight(.semibold)).lineLimit(1)
                                            .strikethrough(item.isDone)
                                            .foregroundStyle(item.isDone ? .secondary : .primary)
                                        Spacer(minLength: 2)
                                        Text(item.time).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                                    }
                                }
                            }
                            if count(day) > 2 {
                                Text("+\(count(day) - 2)").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(isToday ? snapshot.accent.opacity(0.12) : Color.primary.opacity(0.04), in: .rect(cornerRadius: 10))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(dayLabel(day))
                }
            }
        }
    }

    private func dayBadge(_ day: Date, weekday: Int, compact: Bool) -> some View {
        let isToday = calendar.isDate(day, inSameDayAs: date)
        let minutes = snapshot.minutes(on: day)
        return VStack(spacing: compact ? 2 : 0) {
            Text(WidgetStyle.weekdays[weekday])
                .font(.system(size: compact ? 9 : 10, weight: .bold))
                .foregroundStyle(isToday ? snapshot.accent : WidgetStyle.weekdayColor(weekday, accent: snapshot.accent))
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: compact ? 13 : 15, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .frame(width: compact ? 24 : 28, height: compact ? 24 : 24)
                .background(isToday ? snapshot.accent : Color.clear, in: .circle)
            if compact {
                // 공부한 날: 작은 막대
                Capsule()
                    .fill(minutes > 0 ? snapshot.accent.opacity(isToday ? 1 : 0.55) : Color.primary.opacity(0.1))
                    .frame(width: 14, height: 3)
            }
        }
    }

    private func dayLabel(_ day: Date) -> String {
        let list = items(day)
        var text = day.formatted(.dateTime.month().day().weekday())
        if calendar.isDate(day, inSameDayAs: date) { text += ", 오늘" }
        text += list.isEmpty ? ", 일정 없음" : ", " + list.map { "\($0.time) \($0.title)" }.joined(separator: ", ")
        return text
    }
}
