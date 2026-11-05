import AppIntents
import SwiftUI
import WidgetKit

// 오늘 위젯 화면: 오늘의 플랜 · D-Day · 오늘의 단어 · 오늘 공부(목표 링)
// family를 직접 받아서 위젯과 앱의 미리보기 화면에서 똑같이 그림

// MARK: - 1. 오늘의 플랜 (체크 버튼으로 바로 완료)

struct TodayPlansView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    var date = Date()

    private var plans: [WidgetSnapshot.PlanItem] { snapshot.isStale(at: date) ? [] : snapshot.plans }
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
                WidgetHeader(title: L("오늘의 플랜"), trailing: "\(done)/\(plans.count)", accent: snapshot.accent)
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

    @ViewBuilder
    private func check(_ plan: WidgetSnapshot.PlanItem) -> some View {
        let icon = Image(systemName: plan.isDone ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(plan.isDone ? WidgetSnapshot.color(plan.colorHex) : .secondary)
        if let id = plan.occurrenceID {
            Button(intent: TogglePlanDoneIntent(occurrenceID: id, done: !plan.isDone)) { icon }
                .buttonStyle(.plain)
                .accessibilityLabel(plan.isDone ? L("\(plan.title) 완료 취소") : L("\(plan.title) 완료"))
        } else {
            icon
        }
    }

    private func row(_ plan: WidgetSnapshot.PlanItem) -> some View {
        HStack(spacing: 8) {
            check(plan)
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

struct DDayView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    var date = Date()

    var body: some View {
        let text = snapshot.dDayText(on: date)
        switch family {
        case .accessoryInline:
            Label(text.map { "\(snapshot.dDayTitle) \($0)" } ?? L("D-Day를 설정하세요"), systemImage: "flag.checkered")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(text ?? "D-?").font(.system(size: 15, weight: .heavy)).minimumScaleFactor(0.6).widgetAccentable()
                    Text(snapshot.dDayTitle.isEmpty ? L("목표") : snapshot.dDayTitle).font(.system(size: 9)).lineLimit(1)
                }
                .padding(4)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(snapshot.dDayTitle.isEmpty ? "D-Day" : snapshot.dDayTitle, systemImage: "flag.checkered")
                    .font(.caption).lineLimit(1)
                Text(text ?? L("앱에서 설정")).font(.title2.weight(.heavy)).widgetAccentable()
                if let dDayDate = snapshot.dDayDate {
                    Text(dDayDate, format: .dateTime.month().day().weekday()).font(.caption2).opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "flag.checkered").font(.headline)
                    Spacer()
                    Text(snapshot.dDayTitle.isEmpty ? "D-Day" : snapshot.dDayTitle)
                        .font(.subheadline.weight(.semibold)).opacity(0.9).lineLimit(1)
                    Text(text ?? L("설정 필요"))
                        .font(.system(size: text == nil ? 22 : 44, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.5).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    if let dDayDate = snapshot.dDayDate {
                        mediumStat(L("목표일"), dDayDate.formatted(.dateTime.month().day().weekday()))
                    }
                    let minutes = snapshot.isStale(at: date) ? 0 : snapshot.studyMinutes
                    mediumStat(L("오늘 공부"), WidgetMath.durationTextL(minutes))
                    let progress = min(Double(minutes) / Double(max(snapshot.goalMinutes, 1)), 1)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("목표 \(Int(progress * 100))%").font(.caption2.weight(.bold)).opacity(0.85)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.25))
                                Capsule().fill(.white).frame(width: max(6, geo.size.width * progress))
                            }
                        }
                        .frame(height: 6)
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
            .foregroundStyle(.white)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "flag.checkered").font(.headline)
                Spacer()
                Text(snapshot.dDayTitle.isEmpty ? "D-Day" : snapshot.dDayTitle)
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.9)
                    .lineLimit(1)
                Text(text ?? L("설정 필요"))
                    .font(.system(size: text == nil ? 22 : 38, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let dDayDate = snapshot.dDayDate {
                    Text(dDayDate, format: .dateTime.month().day().weekday()).font(.caption2).opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func mediumStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption2.weight(.semibold)).opacity(0.75)
            Text(value).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 3. 오늘의 단어

struct TodayWordsView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
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
                Text(snapshot.wordsLeft == 0 && !snapshot.dayKey.isEmpty ? L("오늘 목표 완료!") : L("단어장을 찍어서 시작해요"))
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

// MARK: - 4. 오늘 공부 (목표 링 + 연속 일수)

struct StudyProgressView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    var date = Date()

    private var minutes: Int { snapshot.isStale(at: date) ? 0 : snapshot.studyMinutes }
    private var progress: Double { min(Double(minutes) / Double(max(snapshot.goalMinutes, 1)), 1) }
    private var timeText: String { WidgetMath.durationTextL(minutes) }
    private var percent: Int { Int((Double(minutes) / Double(max(snapshot.goalMinutes, 1)) * 100).rounded(.down)) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: progress) {
                Image(systemName: "book.fill")
            } currentValueLabel: {
                Text("\(min(percent, 999))").font(.system(size: 14, weight: .bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
            .accessibilityLabel("오늘 목표 \(percent)퍼센트, \(timeText) 공부")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                    Text("오늘 공부").fontWeight(.semibold)
                    Spacer(minLength: 0)
                    Text("\(percent)%").fontWeight(.heavy).monospacedDigit()
                }
                .font(.caption)
                .widgetAccentable()
                Text(timeText).font(.title3.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.7)
                Gauge(value: progress) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .widgetAccentable()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Label("오늘 \(timeText) · \(percent)%", systemImage: "book.fill")
        case .systemMedium:
            HStack(spacing: 18) {
                ring(lineWidth: 11, big: true)
                    .frame(width: 112, height: 112)
                VStack(alignment: .leading, spacing: 9) {
                    WidgetHeader(title: L("오늘 공부"), accent: snapshot.accent)
                    stat(L("공부(짧게)"), timeText, color: .primary)
                    stat(L("목표"), WidgetMath.durationTextL(snapshot.goalMinutes), color: .secondary)
                    stat(L("남은"), minutes >= snapshot.goalMinutes ? L("달성!") : WidgetMath.durationTextL(snapshot.goalMinutes - minutes),
                         color: minutes >= snapshot.goalMinutes ? snapshot.accent : .secondary)
                    Label("\(snapshot.streak(at: date))일 연속", systemImage: "flame.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(WidgetStyle.flame)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("오늘 공부").font(.caption.weight(.heavy)).foregroundStyle(snapshot.accent)
                    Spacer()
                    Label("\(snapshot.streak(at: date))일", systemImage: "flame.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }
                ring(lineWidth: 9, big: false)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func ring(lineWidth: CGFloat, big: Bool) -> some View {
        ZStack {
            Circle().stroke(snapshot.accent.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(snapshot.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(percent)%").font(big ? .title2.weight(.heavy) : .headline.weight(.heavy)).monospacedDigit()
                Text(timeText).font(.system(size: big ? 11 : 10)).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 목표 \(percent)퍼센트, \(timeText) 공부")
    }

    private func stat(_ label: String, _ value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).frame(width: 26, alignment: .leading)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}
