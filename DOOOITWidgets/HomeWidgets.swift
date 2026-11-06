import SwiftUI
import WidgetKit

// 홈 화면 · 잠금 화면 위젯 설정 (그리는 화면은 Shared/Widget*Views.swift: 앱 미리보기와 같이 씀)

// MARK: - 공통 타임라인 (앱이 저장한 요약을 읽고, 일정 시작·끝 · 자정에 다시 그림)

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let saved = WidgetSnapshot.load()
        completion(SnapshotEntry(date: Date(), snapshot: context.isPreview && saved.dayKey.isEmpty ? .preview : saved))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshot.load()
        let entries = WidgetMath.refreshDates(now: now, upcoming: snapshot.upcoming).map {
            SnapshotEntry(date: $0, snapshot: snapshot)
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}

/// 위젯 크기를 읽어서 화면에 넘김
struct FamilyReader<Content: View>: View {
    @Environment(\.widgetFamily) private var family
    @ViewBuilder let content: (WidgetFamily) -> Content

    var body: some View { content(family) }
}

extension View {
    /// 위젯 공통: 둥근 글꼴 · 배경 · 누르면 열 화면
    func widgetChrome(_ style: WidgetBackgroundStyle, snapshot: WidgetSnapshot, family: WidgetFamily, url: URL) -> some View {
        self
            .fontDesign(.rounded)
            // 앱에서 고른 언어 (App Group으로 받음)
            .environment(\.locale, AppLanguage.locale)
            .containerBackground(for: .widget) { style.view(accent: snapshot.accent, family: family) }
            .widgetURL(url)
    }
}

// MARK: - 1. 오늘의 플랜

struct TodayPlansWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayPlans", provider: SnapshotProvider()) { entry in
            FamilyReader { family in
                TodayPlansView(snapshot: entry.snapshot, family: family, date: entry.date)
                    .widgetChrome(.plain, snapshot: entry.snapshot, family: family, url: WidgetLink.planner())
            }
        }
        .configurationDisplayName("오늘의 플랜")
        .description("오늘 할 일을 보고 바로 체크해요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

// MARK: - 2. D-Day

struct DDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DDay", provider: SnapshotProvider()) { entry in
            FamilyReader { family in
                DDayView(snapshot: entry.snapshot, family: family, date: entry.date)
                    .widgetChrome(.accentGradient, snapshot: entry.snapshot, family: family, url: WidgetLink.home)
            }
        }
        .configurationDisplayName("D-Day")
        .description("목표일까지 남은 날을 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - 3. 오늘의 단어

struct TodayWordsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWords", provider: SnapshotProvider()) { entry in
            FamilyReader { family in
                TodayWordsView(snapshot: entry.snapshot, family: family)
                    .widgetChrome(.paper, snapshot: entry.snapshot, family: family, url: WidgetLink.words)
            }
        }
        .configurationDisplayName("오늘의 단어")
        .description("외워야 할 영어 단어를 메모지처럼 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 4. 오늘 공부 (목표 링)

struct StudyProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StudyProgress", provider: SnapshotProvider()) { entry in
            FamilyReader { family in
                StudyProgressView(snapshot: entry.snapshot, family: family, date: entry.date)
                    .widgetChrome(.plain, snapshot: entry.snapshot, family: family, url: WidgetLink.home)
            }
        }
        .configurationDisplayName("오늘 목표")
        .description("오늘 공부 시간과 목표 달성률을 링으로 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
