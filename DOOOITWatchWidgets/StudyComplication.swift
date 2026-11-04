import SwiftUI
import WidgetKit

// 워치 페이스 · 스마트 스택: 오늘 공부 시간과 목표 고리
// 워치 앱이 App Group에 저장한 마지막 상태를 읽음 (타이머가 돌고 있으면 몇 분마다 늘어나게 그려 둠)

struct StudyEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshot

    var seconds: Int { snapshot.studySeconds(at: date) }
    var progress: Double { snapshot.goalProgress(at: date) }
    var accent: Color { Color(complicationHex: snapshot.accentHex) }
}

struct StudyProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudyEntry {
        StudyEntry(date: Date(), snapshot: .complicationPreview)
    }

    func getSnapshot(in context: Context, completion: @escaping (StudyEntry) -> Void) {
        let saved = WatchSnapshotStore.load(.display)
        completion(StudyEntry(date: Date(), snapshot: context.isPreview && saved.isEmpty ? .complicationPreview : saved.forToday(Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyEntry>) -> Void) {
        let now = Date()
        let snapshot = WatchSnapshotStore.load(.display)
        var entries = [StudyEntry(date: now, snapshot: snapshot.forToday(now))]
        if snapshot.timer.phase == .running {
            // 공부 중: 5분마다 시간 · 고리가 늘어나게 (2시간치)
            for step in 1...24 {
                let date = now.addingTimeInterval(Double(step) * 300)
                entries.append(StudyEntry(date: date, snapshot: snapshot.forToday(date)))
            }
        }
        // 자정이 지나면 0분부터
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400 + 30)
        if !snapshot.timer.isActive { entries.append(StudyEntry(date: midnight, snapshot: snapshot.forToday(midnight))) }
        completion(Timeline(entries: entries.sorted { $0.date < $1.date }, policy: .after(now.addingTimeInterval(snapshot.timer.phase == .running ? 2 * 3600 : 6 * 3600))))
    }
}

struct StudyComplicationView: View {
    let entry: StudyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.progress) {
                Image(systemName: "book.fill")
            } currentValueLabel: {
                Text(WatchFormat.short(entry.seconds))
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(entry.accent)
            .widgetAccentable()
        case .accessoryCorner:
            Image(systemName: entry.snapshot.timer.phase == .running ? "timer" : "book.fill")
                .font(.title3)
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: entry.progress) {
                        Text("공부")
                    } currentValueLabel: {
                        Text(WatchFormat.short(entry.seconds))
                    }
                    .tint(entry.accent)
                }
        case .accessoryInline:
            Text("공부 \(WatchFormat.duration(entry.seconds))")
        default:
            HStack(spacing: 8) {
                Gauge(value: entry.progress) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(Int((entry.progress * 100).rounded()))")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(entry.accent)
                .widgetAccentable()
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.snapshot.timer.phase == .running ? "공부 중" : "오늘 공부")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(entry.accent)
                        .widgetAccentable()
                    Text(WatchFormat.duration(entry.seconds))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .minimumScaleFactor(0.7)
                    Text("목표 \(WatchFormat.duration(entry.snapshot.goalMinutes * 60))")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct StudyComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchStudyTime", provider: StudyProvider()) { entry in
            StudyComplicationView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "motiwatch://summary"))
        }
        .configurationDisplayName("오늘 공부")
        .description("오늘 공부 시간과 목표")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

@main
struct MOTIWatchWidgets: WidgetBundle {
    var body: some Widget {
        StudyComplication()
        TimerLiveComplication()
        NextPlanComplication()
        DDayComplication()
        StreakComplication()
        TasksLeftComplication()
    }
}

extension WatchSnapshot {
    static var complicationPreview: WatchSnapshot {
        var s = WatchSnapshot()
        s.dayKey = WatchLink.dayKey(Date())
        s.updatedAt = Date()
        s.savedSeconds = 95 * 60
        s.goalMinutes = 180
        s.streak = 3
        s.week = [0, 0, 0, 0, 3_600, 7_200, 95 * 60]
        let now = Date()
        s.plans = [
            WatchPlanItem(id: "a", planID: "a", dayKey: s.dayKey, title: "수학 문제집", time: "오후 4:00", colorHex: "#3D9BE0",
                          isDone: true, isStudy: true, start: now.addingTimeInterval(-3_600)),
            WatchPlanItem(id: "b", planID: "b", dayKey: s.dayKey, title: "영어 단어 30개", time: "오후 7:00", colorHex: "#7B68EE",
                          isDone: false, isStudy: true, start: now.addingTimeInterval(1_500))
        ]
        s.ddays = [WatchDDay(id: "x", title: "기말고사", dayKey: WatchLink.dayKey(now.addingTimeInterval(86_400 * 5)))]
        return s
    }
}

extension Color {
    init(complicationHex hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
