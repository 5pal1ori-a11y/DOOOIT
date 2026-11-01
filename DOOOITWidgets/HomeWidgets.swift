import SwiftUI
import WidgetKit

// MARK: - 공통 타임라인 (앱이 저장한 요약을 읽고, 자정에 한 번 더 갱신)

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
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400 + 60)
        let entries = [
            SnapshotEntry(date: now, snapshot: snapshot),
            SnapshotEntry(date: midnight, snapshot: snapshot)
        ]
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}

extension WidgetSnapshot {
    static var preview: WidgetSnapshot {
        var snapshot = WidgetSnapshot()
        snapshot.plans = [
            PlanItem(title: "수학 문제집 3단원", time: "오후 4:00", colorHex: "#3D9BE0", isDone: true, isStudy: true),
            PlanItem(title: "영어 단어 30개", time: "오후 7:00", colorHex: "#7B68EE", isDone: false, isStudy: true),
            PlanItem(title: "국어 비문학", time: "오후 9:00", colorHex: "#4CAF63", isDone: false, isStudy: true)
        ]
        snapshot.dDayTitle = "기말고사"
        snapshot.dDayDate = Calendar.current.date(byAdding: .day, value: 12, to: Date())
        snapshot.words = [WordItem(term: "abundant", meaning: "풍부한"), WordItem(term: "resilient", meaning: "회복력 있는")]
        snapshot.wordsLeft = 18
        snapshot.studyMinutes = 95
        snapshot.streak = 6
        return snapshot
    }

    var accent: Color { WidgetSnapshot.color(accentHex) }
}

// MARK: - 1. 오늘의 플랜

struct TodayPlansWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayPlans", provider: SnapshotProvider()) { entry in
            TodayPlansView(snapshot: entry.snapshot)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "dooit://planner"))
        }
        .configurationDisplayName("오늘의 플랜")
        .description("오늘 할 일과 완료 여부를 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct TodayPlansView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private var plans: [WidgetSnapshot.PlanItem] { snapshot.isStale ? [] : snapshot.plans }
    private var done: Int { plans.filter(\.isDone).count }

    private var limit: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 3
        case .systemLarge: return 8
        default: return 2
        }
    }

    var body: some View {
        if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 1) {
                Text("오늘 플랜 \(done)/\(plans.count)").font(.headline).widgetAccentable()
                ForEach(plans.filter { !$0.isDone }.prefix(2), id: \.self) { plan in
                    Text("\(plan.time) \(plan.title)").font(.caption).lineLimit(1)
                }
                if plans.isEmpty { Text("등록된 플랜 없음").font(.caption) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
                HStack {
                    Text("오늘의 플랜").font(.caption.weight(.heavy)).foregroundStyle(snapshot.accent)
                    Spacer()
                    Text("\(done)/\(plans.count)").font(.caption.weight(.bold)).foregroundStyle(.secondary).monospacedDigit()
                }
                if plans.isEmpty {
                    Spacer()
                    Text("오늘 등록된 플랜이 없어요").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ForEach(plans.prefix(limit), id: \.self) { plan in
                        row(plan)
                    }
                    if plans.count > limit {
                        Text("+\(plans.count - limit)개 더").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func row(_ plan: WidgetSnapshot.PlanItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: plan.isDone ? "checkmark.circle.fill" : "circle")
                .font(.subheadline)
                .foregroundStyle(plan.isDone ? WidgetSnapshot.color(plan.colorHex) : .secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(plan.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(plan.isDone)
                    .foregroundStyle(plan.isDone ? .secondary : .primary)
                    .lineLimit(1)
                if family != .systemSmall {
                    Text(plan.time).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if family != .systemSmall {
                Capsule().fill(WidgetSnapshot.color(plan.colorHex)).frame(width: 4, height: 22)
            }
        }
    }
}

// MARK: - 2. D-Day

struct DDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DDay", provider: SnapshotProvider()) { entry in
            DDayView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { DDayBackground(snapshot: entry.snapshot) }
                .widgetURL(URL(string: "dooit://home"))
        }
        .configurationDisplayName("D-Day")
        .description("목표일까지 남은 날을 보여줘요.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct DDayBackground: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemSmall {
            LinearGradient(colors: [snapshot.accent, snapshot.accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color.clear
        }
    }
}

struct DDayView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let text = snapshot.dDayText()
        switch family {
        case .accessoryInline:
            Text(text.map { "\(snapshot.dDayTitle) \($0)" } ?? "D-Day를 설정하세요")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(text ?? "D-?").font(.system(size: 15, weight: .heavy)).minimumScaleFactor(0.6)
                    Text(snapshot.dDayTitle.isEmpty ? "목표" : snapshot.dDayTitle).font(.system(size: 9)).lineLimit(1)
                }
                .padding(4)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.dDayTitle.isEmpty ? "D-Day" : snapshot.dDayTitle).font(.caption).lineLimit(1)
                Text(text ?? "앱에서 설정").font(.title2.weight(.heavy)).widgetAccentable()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "flag.checkered").font(.headline)
                Spacer()
                Text(snapshot.dDayTitle.isEmpty ? "D-Day" : snapshot.dDayTitle)
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.9)
                    .lineLimit(1)
                Text(text ?? "설정 필요")
                    .font(.system(size: text == nil ? 22 : 38, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let date = snapshot.dDayDate {
                    Text(date, format: .dateTime.month().day().weekday()).font(.caption2).opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 3. 오늘의 단어

struct TodayWordsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWords", provider: SnapshotProvider()) { entry in
            TodayWordsView(snapshot: entry.snapshot)
                .containerBackground(Color(red: 1, green: 0.984, blue: 0.937), for: .widget)
                .widgetURL(URL(string: "dooit://words"))
        }
        .configurationDisplayName("오늘의 단어")
        .description("외워야 할 영어 단어를 메모지처럼 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayWordsView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family
    private let ink = Color(red: 0.16, green: 0.17, blue: 0.24)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("오늘의 단어").font(.caption.weight(.heavy)).foregroundStyle(ink.opacity(0.55))
                Spacer()
                if snapshot.wordsLeft > 0 {
                    Text("\(snapshot.wordsLeft)개 남음").font(.caption2.weight(.bold)).foregroundStyle(snapshot.accent)
                }
            }
            if snapshot.words.isEmpty {
                Spacer()
                Text(snapshot.wordsLeft == 0 && !snapshot.dayKey.isEmpty ? "오늘 목표 완료!" : "단어장을 찍어서 시작해요")
                    .font(.headline)
                    .foregroundStyle(ink)
                Spacer()
            } else {
                ForEach(snapshot.words.prefix(family == .systemSmall ? 2 : 3), id: \.self) { word in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(word.term)
                            .font(.custom("Noteworthy-Bold", size: family == .systemSmall ? 17 : 19))
                            .foregroundStyle(ink)
                            .lineLimit(1)
                        Text(word.meaning)
                            .font(.caption)
                            .foregroundStyle(ink.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 4. 오늘 공부 (시간 링 + 연속 일수)

struct StudyProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StudyProgress", provider: SnapshotProvider()) { entry in
            StudyProgressView(snapshot: entry.snapshot)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "dooit://home"))
        }
        .configurationDisplayName("오늘 공부")
        .description("오늘 공부 시간과 목표 달성률, 연속 공부 일수를 보여줘요.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct StudyProgressView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private var minutes: Int { snapshot.isStale ? 0 : snapshot.studyMinutes }
    private var progress: Double { min(Double(minutes) / Double(max(snapshot.goalMinutes, 1)), 1) }
    private var timeText: String { minutes >= 60 ? "\(minutes / 60)시간 \(minutes % 60)분" : "\(minutes)분" }

    var body: some View {
        if family == .accessoryCircular {
            Gauge(value: progress) {
                Image(systemName: "book.fill")
            } currentValueLabel: {
                Text("\(Int(progress * 100))").font(.system(size: 14, weight: .bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("오늘 공부").font(.caption.weight(.heavy)).foregroundStyle(snapshot.accent)
                    Spacer()
                    Label("\(snapshot.streak)일", systemImage: "flame.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }
                ZStack {
                    Circle().stroke(snapshot.accent.opacity(0.15), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(snapshot.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(progress * 100))%").font(.headline.weight(.heavy)).monospacedDigit()
                        Text(timeText).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
