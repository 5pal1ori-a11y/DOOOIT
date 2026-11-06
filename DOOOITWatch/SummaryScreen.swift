import SwiftUI

/// 오늘 한눈에: 공부 시간 고리 · 연속 공부일 · 이번 주 막대 · 다음 일정 · D-Day · 단어/오답
struct SummaryScreen: View {
    @Environment(WatchStore.self) private var store

    private var accent: Color { store.snapshot.accent }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let s = store.snapshot
            ScrollView {
                VStack(spacing: 10) {
                    header(s, now: now)
                    WeekBars(seconds: s.weekSeconds(at: now), goalSeconds: s.goalMinutes * 60, color: accent, now: now)
                    if let next = s.nextPlan(at: now) {
                        nextPlan(next, now: now)
                    }
                    if !s.ddays.isEmpty {
                        ddays(s.ddays, now: now)
                    }
                    stats(s)
                    NavigationLink {
                        SettingsScreen()
                    } label: {
                        Label("설정", systemImage: "gearshape.fill")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 2)
            }
        }
        .navigationTitle("오늘")
    }

    // MARK: 공부 시간 + 연속

    private func header(_ s: WatchSnapshot, now: Date) -> some View {
        let seconds = s.studySeconds(at: now)
        let progress = s.goalProgress(at: now)
        return HStack(spacing: 10) {
            ZStack {
                WatchRing(progress: progress, color: progress >= 1 ? .green : accent, lineWidth: 7)
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(WatchFormat.durationL(seconds))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("목표 \(WatchFormat.durationL(s.goalMinutes * 60))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                let streak = s.streak(at: now)
                Label("\(streak)일 연속", systemImage: "flame.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(streak > 0 ? .orange : .secondary)
                    .labelStyle(.titleAndIcon)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: 다음 일정

    private func nextPlan(_ plan: WatchPlanItem, now: Date) -> some View {
        HStack(spacing: 8) {
            Capsule().fill(Color(watchHex: plan.colorHex)).frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(plan.title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Text("\(plan.time) · \(Self.until(plan.start ?? now, now: now))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(.gray.opacity(0.18), in: .rect(cornerRadius: 12))
        .accessibilityLabel("다음 일정 \(plan.title) \(plan.time)")
    }

    /// 12분 후 · 2시간 후
    static func until(_ date: Date, now: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSince(now) / 60))
        if minutes < 1 { return L("곧") }
        if minutes < 60 { return L("\(minutes)분 후") }
        return L("\(minutes / 60)시간 후")
    }

    // MARK: D-Day

    private func ddays(_ list: [WatchDDay], now: Date) -> some View {
        VStack(spacing: 4) {
            ForEach(list.prefix(3)) { day in
                HStack {
                    Text(day.title)
                        .font(.footnote)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(day.label(from: now))
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(day.days(from: now) <= 7 ? .orange : accent)
                        .monospacedDigit()
                }
            }
        }
        .padding(8)
        .background(.gray.opacity(0.18), in: .rect(cornerRadius: 12))
    }

    // MARK: 단어 · 오답

    private func stats(_ s: WatchSnapshot) -> some View {
        HStack(spacing: 4) {
            stat("\(s.wordsToday)", L("단어"), "character.book.closed.fill", accent)
            stat("\(s.words.count)", L("복습"), "arrow.clockwise", .teal)
            stat("\(s.mistakes)", L("오답"), "xmark.circle.fill", .pink)
        }
    }

    private func stat(_ value: String, _ label: String, _ symbol: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Image(systemName: symbol)
                .font(.caption2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.14), in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

/// 이번 주 막대 그래프 (오늘 칸 강조, 목표 선)
struct WeekBars: View {
    var seconds: [Int]
    var goalSeconds: Int
    var color: Color
    var now: Date

    private static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "E"
        return f
    }()

    var body: some View {
        let top = Double(max(goalSeconds, seconds.max() ?? 0, 60))
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("이번 주")
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text(WatchFormat.shortL(seconds.reduce(0, +)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(seconds.enumerated()), id: \.offset) { i, value in
                    let isToday = i == seconds.count - 1
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(value >= goalSeconds && goalSeconds > 0 ? Color.green : color.opacity(isToday ? 1 : 0.55))
                            .frame(height: max(3, 44 * Double(value) / top))
                        Text(label(i))
                            .font(.system(size: 9, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 58, alignment: .bottom)
        }
        .padding(8)
        .background(.gray.opacity(0.18), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("이번 주 \(WatchFormat.durationL(seconds.reduce(0, +)))")
    }

    private func label(_ i: Int) -> String {
        let back = seconds.count - 1 - i
        let day = Calendar.current.date(byAdding: .day, value: -back, to: now) ?? now
        return Self.weekday.string(from: day)
    }
}
