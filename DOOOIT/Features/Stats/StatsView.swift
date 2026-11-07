import Charts
import SwiftData
import SwiftUI

enum StatPeriod: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }
    var title: String {
        switch self {
        case .day: return L("일간")
        case .week: return L("주간")
        case .month: return L("월간")
        }
    }
    var previousName: String {
        switch self {
        case .day: return L("어제")
        case .week: return L("지난주")
        case .month: return L("지난달")
        }
    }
}

/// 공부 통계: 과목별 시간, 이전 기간과 비교, 추이, 집중 시간대
struct StatsView: View {
    @Environment(StudyTimer.self) private var studyTimer
    @Query private var sessions: [StudySession]
    @Query private var categories: [PlanCategory]
    @State private var period: StatPeriod = .week
    /// 과목 막대가 처음 나타날 때 왼쪽에서 차오름
    @State private var barShown = Motion.reduced

    private struct Entry {
        let category: String
        let start: Date
        let seconds: Int
    }

    private struct SubjectTotal: Identifiable {
        let name: String
        let seconds: Int
        var id: String { name }
    }

    private struct Point: Identifiable {
        let id: Int
        let label: String
        let minutes: Int
        let isCurrent: Bool
    }

    var body: some View {
        let range = Self.range(period, offset: 0)
        let current = entries(in: range)
        let total = current.reduce(0) { $0 + $1.seconds }
        let previous = entries(in: Self.range(period, offset: -1)).reduce(0) { $0 + $1.seconds }
        let bySubject = Dictionary(grouping: current, by: \.category)
            .map { SubjectTotal(name: $0.key, seconds: $0.value.reduce(0) { $0 + $1.seconds }) }
            .sorted { $0.seconds > $1.seconds }

        ScrollView {
            VStack(spacing: 24) {
                WeeklyReportLink()
                tabs

                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(label(for: range))
                            .font(.pt(.subheadline))
                            .foregroundStyle(.secondary)
                        Text("총 \(bigTime(total)) 집중했어요")
                            .font(.pt(.subheadline).weight(.semibold))
                            .foregroundStyle(Palette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .numberRoll(Double(total))

                    if total == 0 {
                        EmptyStateView(symbol: "chart.pie", title: L("아직 공부 기록이 없어요"))
                    } else {
                        subjectBar(bySubject, total: total)
                    }
                }
                .softCard(cornerRadius: 24, padding: 20)
                .staggerIn(index: 0)

                if total > 0 {
                    subjectList(bySubject, total: total)
                        .staggerIn(index: 1)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                comparison(total: total, previous: previous)
                    .softCard(cornerRadius: 24, padding: 20)
                    .staggerIn(index: 2)

                if total > 0 {
                    hourHeat(current)
                        .softCard(cornerRadius: 24, padding: 20)
                        .staggerIn(index: 3)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .animation(Motion.spring, value: period)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("공부 통계")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Pieces

    private var tabs: some View {
        PillSegmentedControl(items: StatPeriod.allCases, selection: $period) { $0.title }
    }

    private func bigTime(_ seconds: Int) -> Text {
        let minutes = Int((Double(seconds) / 60).rounded())
        let big = Font.pt(size: 36, weight: .black)
        return Text("\(Text("\(minutes / 60)").font(big).foregroundStyle(Theme.accent))\(Text("시간 ").foregroundStyle(Theme.accent))\(Text("\(minutes % 60)").font(big).foregroundStyle(Theme.accent))\(Text("분").foregroundStyle(Theme.accent))")
    }

    private func color(for name: String) -> Color {
        categories.first { $0.name == name }?.color ?? .gray
    }

    private func subjectBar(_ items: [SubjectTotal], total: Int) -> some View {
        GeometryReader { geo in
            let gaps = CGFloat(max(items.count - 1, 0)) * 2
            HStack(spacing: 2) {
                ForEach(items) { item in
                    Rectangle()
                        .fill(color(for: item.name))
                        .frame(width: barShown ? max(2, (geo.size.width - gaps) * CGFloat(item.seconds) / CGFloat(total)) : 2)
                }
            }
            .animation(Motion.fill, value: barShown)
            .animation(Motion.fill, value: items.map(\.seconds))
        }
        .frame(height: 16)
        .clipShape(Capsule())
        .onAppear { barShown = true }
    }

    private func subjectList(_ items: [SubjectTotal], total: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                let index = items.firstIndex { $0.id == item.id } ?? 0
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: item.name))
                        .frame(width: 4, height: 22)
                    Text(item.name.loc).font(.pt(.body).weight(.semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text("\(Int((Double(item.seconds) / Double(total) * 100).rounded()))%")
                        .font(.pt(.caption))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .numberRoll(Double(item.seconds))
                    Text(TimeText.durationL(seconds: item.seconds))
                        .font(.pt(.body).weight(.bold))
                        .monospacedDigit()
                        .frame(minWidth: 90, alignment: .trailing)
                        .numberRoll(Double(item.seconds))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                if index < items.count - 1 { Divider().padding(.leading, 32) }
            }
        }
        .softCardBackground(cornerRadius: 22)
    }

    private func comparison(total: Int, previous: Int) -> some View {
        let diff = total - previous
        let points: [Point] = (-5...0).map { offset in
            let r = Self.range(period, offset: offset)
            let seconds = entries(in: r).reduce(0) { $0 + $1.seconds }
            return Point(id: offset, label: shortLabel(r.0), minutes: seconds / 60, isCurrent: offset == 0)
        }

        return VStack(spacing: 6) {
            Text("집중 시간이 \(period.previousName)보다")
                .font(.pt(.subheadline))
                .foregroundStyle(.secondary)
            if diff == 0 {
                Text("똑같아요").font(.pt(.title2).weight(.bold))
            } else {
                Text("\(bigTime(abs(diff))) \(diff > 0 ? L("늘었어요") : L("줄었어요"))")
                    .font(.pt(.subheadline).weight(.semibold))
            }

            Chart(points) { point in
                LineMark(x: .value("기간", point.label), y: .value("분", point.minutes))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.accent)
                PointMark(x: .value("기간", point.label), y: .value("분", point.minutes))
                    .symbolSize(point.isCurrent ? 110 : 55)
                    .foregroundStyle(point.isCurrent ? Theme.accent : Theme.secondary.opacity(0.6))
                    .annotation(position: .top, spacing: 6) {
                        Text(String(format: "%02d:%02d", point.minutes / 60, point.minutes % 60))
                            .font(.pt(.caption2).weight(point.isCurrent ? .heavy : .regular))
                            .foregroundStyle(point.isCurrent ? Theme.accent : Color.secondary)
                    }
            }
            .chartYAxis(.hidden)
            .frame(height: 190)
            .padding(.top, 8)
        }
    }

    private func hourHeat(_ items: [Entry]) -> some View {
        var hours = Array(repeating: 0, count: 24)
        for item in items { hours[Calendar.current.component(.hour, from: item.start)] += item.seconds }
        let maxValue = max(hours.max() ?? 1, 1)
        let best = hours.firstIndex(of: hours.max() ?? 0) ?? 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("언제 집중했나요").font(.pt(.title3).weight(.bold)).foregroundStyle(Palette.ink)
                Spacer()
                Text("가장 많이 공부한 시간 \(best)시")
                    .font(.pt(.caption))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accent.opacity(hours[hour] == 0 ? 0.08 : 0.25 + 0.75 * Double(hours[hour]) / Double(maxValue)))
                }
            }
            .frame(height: 34)
            HStack {
                ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                    Text(L("\(hour)시"))
                    if hour != 24 { Spacer() }
                }
            }
            .font(.pt(.caption2))
            .foregroundStyle(.secondary)
        }
    }

    // MARK: Data

    private func entries(in range: (Date, Date)) -> [Entry] {
        var list = sessions
            .filter { $0.start >= range.0 && $0.start < range.1 }
            .map { Entry(category: $0.categoryName.isEmpty ? "기타" : $0.categoryName, start: $0.start, seconds: $0.seconds) }
        if studyTimer.isActive, let started = studyTimer.startedAt, started >= range.0, started < range.1 {
            list.append(Entry(category: studyTimer.categoryName, start: started, seconds: Int(studyTimer.elapsed())))
        }
        return list
    }

    static func range(_ period: StatPeriod, offset: Int) -> (Date, Date) {
        let cal = Calendar.current
        let today = Date().startOfDay
        switch period {
        case .day:
            let start = today.adding(days: offset)
            return (start, start.adding(days: 1))
        case .week:
            let weekStart = today.adding(days: -(cal.component(.weekday, from: today) - 1) + offset * 7)
            return (weekStart, weekStart.adding(days: 7))
        case .month:
            let start = today.startOfMonth.adding(months: offset)
            return (start, start.adding(months: 1))
        }
    }

    private func label(for range: (Date, Date)) -> String {
        switch period {
        case .day: return range.0.ui("M월 d일 EEEE")
        case .week: return L("\(range.0.ui("M월 d일")) – \(range.1.adding(days: -1).ui("M월 d일"))")
        case .month: return range.0.ui("yyyy년 M월")
        }
    }

    private func shortLabel(_ date: Date) -> String {
        period == .month ? date.ui("M월") : date.ui("M/d")
    }
}
