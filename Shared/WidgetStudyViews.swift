import SwiftUI
import WidgetKit

// 공부 위젯: 이번 주 그래프 · 연속 공부 · 다음 일정 · 빠른 타이머

// MARK: - 이번 주 공부 그래프 (요일별 막대 + 목표선)

struct WeekChartWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    var date = Date()

    private var calendar: Calendar { .current }
    private var week: [Date] { WidgetMath.week(containing: date) }
    private var values: [Int] { week.map { snapshot.minutes(on: $0) } }
    private var total: Int { values.reduce(0, +) }
    private var todayIndex: Int { week.firstIndex { calendar.isDate($0, inSameDayAs: date) } ?? 0 }
    private var goalDays: Int { values.filter { $0 >= snapshot.goalMinutes && $0 > 0 }.count }
    private var average: Int { total / max(todayIndex + 1, 1) }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                    Text("이번 주 \(WidgetMath.compactHours(total))").fontWeight(.semibold)
                }
                .font(.caption)
                .widgetAccentable()
                bars(labels: false, values: false, goalLine: false, spacing: 4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summaryLabel)
        case .systemMedium:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeader(title: "이번 주 공부", accent: snapshot.accent)
                    Text(WidgetMath.compactHours(total))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                    stat("하루 평균", WidgetMath.durationText(average))
                    stat("목표 달성", "\(goalDays)일")
                }
                .frame(width: 104, alignment: .leading)
                .accessibilityElement(children: .combine)
                bars(labels: true, values: true, goalLine: true, spacing: 7)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(title: "이번 주", trailing: WidgetMath.compactHours(total), accent: snapshot.accent)
                bars(labels: true, values: false, goalLine: true, spacing: 5)
            }
        }
    }

    private var summaryLabel: String {
        "이번 주 공부 \(WidgetMath.durationText(total)), 목표 달성 \(goalDays)일"
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    /// 막대 그래프: 오늘은 진하게, 앞으로 올 날은 흐리게, 점선은 하루 목표
    private func bars(labels: Bool, values showValues: Bool, goalLine: Bool, spacing: CGFloat) -> some View {
        let goal = max(snapshot.goalMinutes, 1)
        let top = Double(max(values.max() ?? 0, goal)) * 1.1
        return VStack(spacing: 3) {
            GeometryReader { geo in
                let height = geo.size.height
                ZStack(alignment: .bottom) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(values.enumerated()), id: \.offset) { index, minutes in
                            let ratio = Double(minutes) / top
                            let isToday = index == todayIndex
                            let isFuture = index > todayIndex
                            VStack(spacing: 2) {
                                if showValues && minutes > 0 {
                                    Text(minutes >= 60 ? String(format: "%.1f", Double(minutes) / 60) : "\(minutes)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(isToday ? snapshot.accent : .secondary)
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(barColor(minutes: minutes, goal: goal, isToday: isToday, isFuture: isFuture))
                                    .frame(height: max(minutes > 0 ? 4 : 3, height * 0.86 * ratio))
                                    .widgetAccentable(isToday)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                    if goalLine {
                        WidgetDashedLine()
                            .stroke(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(height: 1)
                            .offset(y: -height * 0.86 * Double(goal) / top)
                    }
                }
            }
            if labels {
                HStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(WidgetStyle.weekdays[i])
                            .font(.system(size: 9, weight: i == todayIndex ? .heavy : .semibold))
                            .foregroundStyle(i == todayIndex ? snapshot.accent : WidgetStyle.weekdayColor(i, accent: snapshot.accent).opacity(0.8))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summaryLabel)
    }

    private func barColor(minutes: Int, goal: Int, isToday: Bool, isFuture: Bool) -> Color {
        if minutes == 0 { return Color.primary.opacity(isFuture ? 0.05 : 0.1) }
        if isToday || minutes >= goal { return snapshot.accent }
        return snapshot.accent.opacity(0.45)
    }
}

// MARK: - 연속 공부

struct StreakWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    var date = Date()

    private var calendar: Calendar { .current }
    private var streak: Int { snapshot.streak(at: date) }
    private var best: Int { max(snapshot.bestStreak, streak) }
    private var week: [Date] { WidgetMath.week(containing: date) }
    private var studiedToday: Bool { snapshot.minutes(on: date) > 0 }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -1) {
                    Image(systemName: "flame.fill").font(.system(size: 14, weight: .bold)).widgetAccentable()
                    Text("\(streak)").font(.system(size: 20, weight: .heavy, design: .rounded)).minimumScaleFactor(0.5)
                    Text("일").font(.system(size: 9, weight: .bold))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak)일 연속 공부")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("\(streak)일 연속").font(.headline)
                }
                .widgetAccentable()
                Text(studiedToday ? "오늘도 완료!" : "오늘 이어가요").font(.caption)
                weekDots(size: 9, on: .primary, off: .primary.opacity(0.25))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        case .accessoryInline:
            Label("\(streak)일 연속 공부", systemImage: "flame.fill")
        default:
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "flame.fill").font(.title3.weight(.bold))
                    Spacer()
                    Text("최고 \(best)일").font(.caption2.weight(.bold)).opacity(0.85)
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(streak)").font(.system(size: 46, weight: .black, design: .rounded)).monospacedDigit()
                        .minimumScaleFactor(0.5).lineLimit(1)
                    Text("일").font(.title3.weight(.heavy))
                }
                Text(streak == 0 ? "오늘 시작해요" : (studiedToday ? "연속 공부 중" : "오늘 이어가요"))
                    .font(.caption.weight(.semibold)).opacity(0.9)
                weekDots(size: 12, on: .white, off: .white.opacity(0.3))
                    .padding(.top, 6)
            }
            .foregroundStyle(.white)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak)일 연속 공부, 최고 \(best)일")
        }
    }

    /// 이번 주 공부한 날 점 (일~토)
    private func weekDots(size: CGFloat, on: Color, off: Color) -> some View {
        HStack(spacing: size * 0.45) {
            ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                let studied = snapshot.minutes(on: day) > 0
                let isToday = calendar.isDate(day, inSameDayAs: date)
                VStack(spacing: 2) {
                    Circle()
                        .fill(studied ? on : off)
                        .overlay {
                            if isToday && !studied { Circle().strokeBorder(on, lineWidth: 1.5) }
                        }
                        .frame(width: size, height: size)
                    if size >= 12 {
                        Text(WidgetStyle.weekdays[index]).font(.system(size: 8, weight: .bold)).opacity(0.85)
                    }
                }
            }
        }
    }
}

// MARK: - 다음 일정 (남은 시간)

struct NextPlanWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    var date = Date()

    private var next: [WidgetSnapshot.PlanItem] { snapshot.nextPlans(at: date) }

    var body: some View {
        let first = next.first
        switch family {
        case .accessoryInline:
            if let first {
                Label("\(first.time) \(first.title)", systemImage: "clock")
            } else {
                Label("남은 일정 없음", systemImage: "checkmark")
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                if let first {
                    Label(dayPrefix(first) + first.time, systemImage: "clock.fill").font(.caption).widgetAccentable()
                    Text(first.title).font(.headline).lineLimit(1)
                    countdown(first).font(.caption)
                } else {
                    Label("다음 일정", systemImage: "clock.fill").font(.caption).widgetAccentable()
                    Text("남은 일정 없음").font(.headline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(spacing: 14) {
                main(first)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if next.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("그다음").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                        ForEach(next.dropFirst().prefix(3), id: \.self) { item in
                            HStack(spacing: 6) {
                                Capsule().fill(WidgetSnapshot.color(item.colorHex)).frame(width: 3, height: 24)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(item.title).font(.caption.weight(.semibold)).lineLimit(1)
                                    Text(dayPrefix(item) + item.time).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: 130, alignment: .leading)
                }
            }
        default:
            main(first)
        }
    }

    @ViewBuilder
    private func main(_ item: WidgetSnapshot.PlanItem?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetHeader(title: "다음 일정", symbol: "clock.fill", accent: snapshot.accent)
            Spacer(minLength: 0)
            if let item {
                let color = WidgetSnapshot.color(item.colorHex)
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 7, height: 7)
                    Text(dayPrefix(item) + item.time).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
                Text(item.title)
                    .font(.headline.weight(.heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                countdown(item)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                if isOngoing(item), let start = item.start, let end = item.end, end > start {
                    ProgressView(timerInterval: start...end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                        .tint(color)
                }
            } else {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(snapshot.accent)
                Text("남은 일정 없음").font(.headline.weight(.heavy))
                Text("푹 쉬어요").font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func isOngoing(_ item: WidgetSnapshot.PlanItem) -> Bool {
        guard let start = item.start else { return false }
        return start <= date
    }

    /// 오늘이 아니면 "내일 " · "금 " 을 앞에
    private func dayPrefix(_ item: WidgetSnapshot.PlanItem) -> String {
        guard let start = item.start else { return "" }
        let diff = WidgetMath.daysBetween(date, start)
        switch diff {
        case 0: return ""
        case 1: return "내일 "
        default:
            let weekday = Calendar.current.component(.weekday, from: start)
            return "\(WidgetStyle.weekdays[weekday - 1]) "
        }
    }

    /// 시작 전: "2시간 10분 후" 처럼 줄어드는 시간 · 진행 중: "진행 중"
    @ViewBuilder
    private func countdown(_ item: WidgetSnapshot.PlanItem) -> some View {
        if isOngoing(item) {
            Text("진행 중")
        } else if let start = item.start {
            Text("\(Text(start, style: .relative)) 후")
        }
    }
}

// MARK: - 빠른 타이머

struct QuickTimerWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    var date = Date()

    private var minutes: Int { snapshot.isStale(at: date) ? 0 : snapshot.studyMinutes }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "play.fill").font(.system(size: 16, weight: .bold)).widgetAccentable()
                    Text("25분").font(.system(size: 11, weight: .heavy))
                }
            }
            .accessibilityLabel("25분 공부 시작")
        case .systemMedium:
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: "바로 공부", symbol: "timer", trailing: "오늘 \(WidgetMath.durationText(minutes))", accent: snapshot.accent)
                HStack(spacing: 8) {
                    button(25, symbol: "leaf.fill")
                    button(50, symbol: "flame.fill")
                    button(0, symbol: "infinity")
                }
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("바로 공부").font(.caption.weight(.heavy)).opacity(0.9)
                    Spacer()
                    Image(systemName: "timer").font(.caption.weight(.bold))
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().fill(.white.opacity(0.22))
                    Circle().fill(.white).padding(8)
                    Image(systemName: "play.fill")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(snapshot.accent)
                        .offset(x: 2)
                }
                .frame(width: 70, height: 70)
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                Text("25분 집중").font(.headline.weight(.heavy))
                Text("오늘 \(WidgetMath.durationText(minutes))").font(.caption2.weight(.semibold)).opacity(0.85)
            }
            .foregroundStyle(.white)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("25분 공부 시작, 오늘 \(WidgetMath.durationText(minutes)) 공부")
        }
    }

    /// 0분 = 시간 제한 없이
    private func button(_ target: Int, symbol: String) -> some View {
        Link(destination: WidgetLink.timer(minutes: target)) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.title3.weight(.bold))
                Text(target == 0 ? "자유" : "\(target)분").font(.subheadline.weight(.heavy))
            }
            .foregroundStyle(target == 25 ? Color.white : snapshot.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(target == 25 ? snapshot.accent : snapshot.accent.opacity(0.13), in: .rect(cornerRadius: 16))
        }
        .accessibilityLabel(target == 0 ? "시간 제한 없이 공부 시작" : "\(target)분 공부 시작")
    }
}
