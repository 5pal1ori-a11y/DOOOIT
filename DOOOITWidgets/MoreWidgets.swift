import SwiftUI
import WidgetKit

// 더 많은 위젯: 공부 달력 · 이번 주 일정 · 이번 주 그래프 · 연속 공부 · 다음 일정 · 바로 공부

// MARK: - 5. 공부 달력 (이번 달)

struct MonthCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MonthCalendar", provider: SnapshotProvider()) { entry in
            FamilyReader { family in
                MonthCalendarWidgetView(snapshot: entry.snapshot, family: family, date: entry.date)
                    .widgetChrome(.plain, snapshot: entry.snapshot, family: family, url: WidgetLink.planner())
            }
        }
        .configurationDisplayName("공부 달력")
        .description("공부한 날은 진하게, 일정은 점으로 보여줘요.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - 6. 이번 주 일정

struct WeekPlansWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeekPlans", provider: SnapshotProvider()) { entry in
            FamilyReader { family in
                WeekPlansWidgetView(snapshot: entry.snapshot, family: family, date: entry.date)
                    .widgetChrome(.plain, snapshot: entry.snapshot, family: family, url: WidgetLink.planner())
            }
        }
        .configurationDisplayName("이번 주 일정")
        .description("이번 주 요일별 일정을 한눈에 봐요.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - 7. 이번 주 공부 그래프

struct WeekChartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeekChart", provider: SnapshotProvider()) { entry in
            FamilyReader { family in
                WeekChartWidgetView(snapshot: entry.snapshot, family: family, date: entry.date)
                    .widgetChrome(.plain, snapshot: entry.snapshot, family: family, url: WidgetLink.weeklyReport)
            }
        }
        .configurationDisplayName("이번 주 공부")
        .description("요일별 공부 시간과 하루 목표선을 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - 8. 연속 공부

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Streak", provider: SnapshotProvider()) { entry in
            FamilyReader { family in
                StreakWidgetView(snapshot: entry.snapshot, family: family, date: entry.date)
                    .widgetChrome(.flame, snapshot: entry.snapshot, family: family, url: WidgetLink.home)
            }
        }
        .configurationDisplayName("연속 공부")
        .description("며칠째 이어서 공부하는지 보여줘요.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - 9. 다음 일정

struct NextPlanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextPlan", provider: SnapshotProvider()) { entry in
            FamilyReader { family in
                NextPlanWidgetView(snapshot: entry.snapshot, family: family, date: entry.date)
                    .widgetChrome(.plain, snapshot: entry.snapshot, family: family,
                                  url: WidgetLink.planner(entry.snapshot.nextPlans(at: entry.date).first?.dayKey))
            }
        }
        .configurationDisplayName("다음 일정")
        .description("다음 일정과 남은 시간을 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - 10. 바로 공부 (타이머 빠른 시작)

struct QuickTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickTimer", provider: SnapshotProvider()) { entry in
            FamilyReader { family in
                QuickTimerWidgetView(snapshot: entry.snapshot, family: family, date: entry.date)
                    .widgetChrome(family == .systemMedium ? .plain : .accentGradient, snapshot: entry.snapshot, family: family,
                                  url: family == .systemMedium ? WidgetLink.timer() : WidgetLink.timer(minutes: 25))
            }
        }
        .configurationDisplayName("바로 공부")
        .description("눌러서 공부 타이머를 바로 시작해요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
