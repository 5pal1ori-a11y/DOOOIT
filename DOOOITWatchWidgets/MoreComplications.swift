import SwiftUI
import WidgetKit

// 워치 페이스 · 스마트 스택 더: 공부 타이머(실시간) · 다음 일정 · D-Day · 연속 공부일 · 남은 할 일
// 모두 워치 앱이 App Group에 저장한 마지막 상태를 읽음

struct WatchEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshot
    var relevance: TimelineEntryRelevance?

    var accent: Color { Color(complicationHex: snapshot.accentHex) }
}

/// 다시 그릴 때: 지금 · 일정 시작마다 · 공부 중이면 5분마다 · 자정마다
struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: Date(), snapshot: .complicationPreview)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        let saved = WatchSnapshotStore.load(.display)
        let snapshot = context.isPreview && saved.isEmpty ? .complicationPreview : saved.forToday(Date())
        completion(WatchEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let now = Date()
        let saved = WatchSnapshotStore.load(.display)
        let entries = Self.dates(for: saved, now: now).map { date in
            let snapshot = saved.forToday(date)
            return WatchEntry(date: date, snapshot: snapshot, relevance: Self.relevance(snapshot, at: date))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static func dates(for s: WatchSnapshot, now: Date, calendar: Calendar = .current) -> [Date] {
        var dates = [now]
        dates += (s.plans + s.tomorrow).compactMap(\.start).filter { $0 > now && $0 < now.addingTimeInterval(36 * 3600) }
            .map { $0.addingTimeInterval(1) }
        if s.timer.phase == .running {
            dates += (1...24).map { now.addingTimeInterval(Double($0) * 300) }
            if let goal = s.timer.goalDate, goal > now { dates.append(goal.addingTimeInterval(1)) }
        }
        let today = calendar.startOfDay(for: now)
        for day in 1...3 {
            if let midnight = calendar.date(byAdding: .day, value: day, to: today) { dates.append(midnight.addingTimeInterval(30)) }
        }
        return Array(Set(dates)).sorted().prefix(80).map { $0 }
    }

    /// 스마트 스택: 공부 중이거나 일정이 곧이면 위로
    static func relevance(_ s: WatchSnapshot, at date: Date) -> TimelineEntryRelevance? {
        if s.timer.isActive { return TimelineEntryRelevance(score: 80, duration: 300) }
        if let next = s.nextPlan(at: date)?.start, next.timeIntervalSince(date) < 3_600 {
            return TimelineEntryRelevance(score: 60, duration: next.timeIntervalSince(date))
        }
        return TimelineEntryRelevance(score: 10)
    }
}

// MARK: - 공부 타이머 (실시간)

struct TimerLiveView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) private var family

    private var timer: WatchTimerState { entry.snapshot.timer }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryInline:
            inline
        case .accessoryCorner:
            Image(systemName: timer.phase == .running ? "timer" : (timer.phase == .paused ? "pause.fill" : "play.fill"))
                .font(.title3)
                .widgetAccentable()
                .widgetLabel { cornerLabel }
        default:
            rectangular
        }
    }

    @ViewBuilder
    private var circular: some View {
        if timer.phase == .running, let since = timer.runningSince, let goal = timer.goalDate, goal > entry.date {
            ProgressView(timerInterval: since...goal, countsDown: false) {
                Image(systemName: "timer")
            } currentValueLabel: {
                Text(timerInterval: since...goal, countsDown: true)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
            }
            .progressViewStyle(.circular)
            .tint(entry.accent)
            .widgetAccentable()
        } else if timer.phase == .running, let since = timer.runningSince {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "timer").font(.caption2).widgetAccentable()
                    Text(since, style: .timer)
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                }
                .padding(4)
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: timer.phase == .paused ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .widgetAccentable()
                    if timer.phase == .paused {
                        Text(WatchFormat.shortL(Int(timer.pausedElapsed)))
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var inline: some View {
        if timer.phase == .running, let since = timer.runningSince {
            Text(since, style: .timer)
        } else if timer.phase == .paused {
            Text("멈춤 \(WatchFormat.clock(timer.pausedElapsed))")
        } else {
            Text("공부 시작하기")
        }
    }

    @ViewBuilder
    private var cornerLabel: some View {
        if timer.phase == .running, let since = timer.runningSince {
            Text(since, style: .timer)
        } else {
            Text(timer.phase == .paused ? L("멈춤") : L("시작"))
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(timer.isActive ? timer.title : L("공부 타이머"))
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(entry.accent)
                .widgetAccentable()
                .lineLimit(1)
            Group {
                if timer.phase == .running, let since = timer.runningSince {
                    if let goal = timer.goalDate, goal > entry.date {
                        Text(timerInterval: entry.date...goal, countsDown: true)
                    } else {
                        Text(since, style: .timer)
                    }
                } else if timer.phase == .paused {
                    Text(WatchFormat.clock(timer.pausedElapsed))
                } else {
                    Text(WatchFormat.durationL(entry.snapshot.studySeconds(at: entry.date)))
                }
            }
            .font(.system(.title3, design: .rounded).weight(.bold))
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            if timer.phase == .running, let since = timer.runningSince, let goal = timer.goalDate, goal > entry.date {
                ProgressView(timerInterval: since...goal, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    .tint(entry.accent)
            } else {
                Text(timer.phase == .paused ? L("멈춤") : L("눌러서 시작"))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TimerLiveComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchTimerLive", provider: WatchProvider()) { entry in
            TimerLiveView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "motiwatch://timer"))
        }
        .configurationDisplayName("공부 타이머")
        .description("공부 중인 시간을 실시간으로")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 다음 일정

struct NextPlanView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let next = entry.snapshot.nextPlan(at: entry.date)
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: next == nil ? "checkmark" : "calendar")
                        .font(.caption)
                        .widgetAccentable()
                    if let start = next?.start {
                        Text(start, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .minimumScaleFactor(0.6)
                    }
                }
            }
        case .accessoryInline:
            if let next {
                Text("\(next.time) \(next.title)")
            } else {
                Text("남은 일정 없음")
            }
        case .accessoryCorner:
            Image(systemName: "calendar")
                .font(.title3)
                .widgetAccentable()
                .widgetLabel {
                    if let next, let start = next.start {
                        Text(start, style: .relative)
                    } else {
                        Text("없음")
                    }
                }
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text("다음 일정")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(entry.accent)
                    .widgetAccentable()
                if let next {
                    Text(next.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    if let start = next.start {
                        Text("\(next.time) · \(Text(start, style: .relative)) 후")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(entry.snapshot.plans.isEmpty ? L("오늘 일정 없음") : L("오늘 일정 끝!"))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                    if let first = entry.snapshot.tomorrow.first {
                        Text("내일 \(first.time) \(first.title)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct NextPlanComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchNextPlan", provider: WatchProvider()) { entry in
            NextPlanView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "motiwatch://today"))
        }
        .configurationDisplayName("다음 일정")
        .description("곧 할 일과 남은 시간")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular, .accessoryCorner])
    }
}

// MARK: - D-Day

struct DDayView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let list = entry.snapshot.ddays.filter { $0.days(from: entry.date) >= 0 }
        let first = list.first
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(first?.label(from: entry.date) ?? "D-Day")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .minimumScaleFactor(0.5)
                        .widgetAccentable()
                    Text(first?.title ?? L("없음"))
                        .font(.system(size: 10, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(3)
            }
        case .accessoryInline:
            if let first {
                Text("\(first.title) \(first.label(from: entry.date))")
            } else {
                Text("D-Day 없음")
            }
        case .accessoryCorner:
            Text(first?.label(from: entry.date) ?? "D")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .widgetAccentable()
                .widgetLabel(first?.title ?? "D-Day")
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text("D-Day")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(entry.accent)
                    .widgetAccentable()
                if list.isEmpty {
                    Text("아이폰에서 정해요")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                ForEach(list.prefix(2)) { day in
                    HStack {
                        Text(day.title)
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(day.label(from: entry.date))
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DDayComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchDDay", provider: WatchProvider()) { entry in
            DDayView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "motiwatch://summary"))
        }
        .configurationDisplayName("D-Day")
        .description("시험까지 남은 날")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 연속 공부일

struct StreakView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let streak = entry.snapshot.streak(at: entry.date)
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .widgetAccentable()
                    Text("\(streak)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .minimumScaleFactor(0.5)
                }
            }
        case .accessoryInline:
            Text("\(Image(systemName: "flame.fill")) \(streak)일 연속")
        case .accessoryCorner:
            Image(systemName: "flame.fill")
                .font(.title3)
                .widgetAccentable()
                .widgetLabel("\(streak)일 연속")
        default:
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(streak)일 연속")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                    Text("오늘 \(WatchFormat.durationL(entry.snapshot.studySeconds(at: entry.date)))")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct StreakComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchStreak", provider: WatchProvider()) { entry in
            StreakView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "motiwatch://summary"))
        }
        .configurationDisplayName("연속 공부일")
        .description("며칠째 공부하고 있는지")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 남은 할 일

struct TasksLeftView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let plans = entry.snapshot.plans
        let done = plans.filter(\.isDone).count
        let left = plans.count - done
        let progress = plans.isEmpty ? 0 : Double(done) / Double(plans.count)
        switch family {
        case .accessoryCircular:
            Gauge(value: progress) {
                Image(systemName: "checklist")
            } currentValueLabel: {
                Text("\(left)")
                    .font(.system(.body, design: .rounded).weight(.bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(entry.accent)
            .widgetAccentable()
        case .accessoryInline:
            Text(left == 0 ? L("할 일 끝!") : L("할 일 \(left)개 남음"))
        case .accessoryCorner:
            Text("\(left)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: progress) {
                        Text("할 일")
                    }
                    .tint(entry.accent)
                }
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text("할 일 \(done)/\(plans.count)")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(entry.accent)
                    .widgetAccentable()
                if let next = plans.first(where: { !$0.isDone }) {
                    Text(next.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(left > 1 ? L("외 \(left - 1)개") : next.time)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Text(plans.isEmpty ? L("오늘 할 일 없음") : L("다 했어요!"))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TasksLeftComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchTasksLeft", provider: WatchProvider()) { entry in
            TasksLeftView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "motiwatch://today"))
        }
        .configurationDisplayName("남은 할 일")
        .description("오늘 할 일 몇 개 남았는지")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
