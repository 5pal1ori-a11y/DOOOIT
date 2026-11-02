import SwiftData
import SwiftUI

enum PlanEditorTarget: Identifiable {
    case new(Date)
    case edit(Plan)

    var id: String {
        switch self {
        case .new(let date): return "new-\(date.timeIntervalSince1970)"
        case .edit(let plan): return plan.id.uuidString
        }
    }
}

struct PlannerView: View {
    @Environment(\.modelContext) private var context
    @Environment(PlannerRouter.self) private var router
    @Query(sort: \Plan.startDate) private var plans: [Plan]

    @State private var month = Date().startOfMonth
    @State private var editorTarget: PlanEditorTarget?
    @State private var showCategories = false
    @State private var slideEdge: Edge = .trailing

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        Group {
                            if router.mode == .month {
                                monthContent
                                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                            } else {
                                dayContent
                                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        .animation(Motion.spring, value: router.mode)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 110)
                }
                .scrollIndicators(.hidden)
                .onChange(of: router.scrollRequest) { _, _ in scrollToNow(proxy) }
                .onChange(of: router.mode) { _, mode in if mode == .day { scrollToNow(proxy) } }
                .onAppear { if router.mode == .day { scrollToNow(proxy) } }
            }
            .background { AppBackground() }
            .navigationTitle("플래너")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DDayChip()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCategories = true } label: { Image(systemName: "tag") }
                        .accessibilityLabel("카테고리 관리")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    editorTarget = .new(router.selectedDate)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .padding(20)
                .accessibilityLabel("플랜 추가")
            }
            .sheet(item: $editorTarget) { target in
                PlanEditorView(target: target)
            }
            .sheet(isPresented: $showCategories) {
                NavigationStack { CategoryManagerView() }
            }
            .onChange(of: router.selectedDate) { _, date in
                if !date.isSameMonth(as: month) { month = date.startOfMonth }
            }
        }
    }

    private func scrollToNow(_ proxy: ScrollViewProxy) {
        let isToday = router.selectedDate.isSameDay(as: Date())
        let hour = isToday ? max(0, Calendar.current.component(.hour, from: Date()) - 1) : 7
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.smooth) { proxy.scrollTo("hour-\(hour)", anchor: .top) }
        }
    }

    // MARK: Header (큰 달 이름 + 월간/하루 전환)

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text(month.kr("yyyy년"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(month.kr("M월"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
            }
            Spacer()
            if !router.selectedDate.isSameDay(as: Date()) {
                Button("오늘") {
                    withAnimation(.smooth) {
                        month = Date().startOfMonth
                        router.selectedDate = Date().startOfDay
                    }
                    Haptics.tap()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color.white, in: .capsule)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
            }
            modeToggle
        }
        .padding(.horizontal, 4)
    }

    /// 월간 / 하루 아이콘 두 개짜리 작은 전환 버튼
    private var modeToggle: some View {
        HStack(spacing: 2) {
            ForEach(PlannerMode.allCases) { mode in
                let isOn = router.mode == mode
                Button {
                    withAnimation(.smooth) { router.mode = mode }
                    Haptics.tap()
                } label: {
                    Image(systemName: mode.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOn ? Color.white : Color.secondary)
                        .frame(width: 40, height: 30)
                        .background(isOn ? Theme.accent : Color.clear, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.title)
            }
        }
        .padding(2)
        .background(Color.white, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
    }

    // MARK: Month

    private var monthContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 0) {
                HStack {
                    Button { changeMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 40, height: 36) }
                        .accessibilityLabel("이전 달")
                    Spacer()
                    Text("밀어서 다른 달 보기")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button { changeMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 40, height: 36) }
                        .accessibilityLabel("다음 달")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

                CalendarGrid(month: month, selected: Binding(get: { router.selectedDate }, set: { router.selectedDate = $0 }), plans: plans)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 10)
                    .id(month)
                    .transition(.asymmetric(insertion: .move(edge: slideEdge).combined(with: .opacity), removal: .opacity))
            }
            .softCardBackground(cornerRadius: 22)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30).onEnded { value in
                    if value.translation.width < -50 { changeMonth(1) }
                    if value.translation.width > 50 { changeMonth(-1) }
                }
            )

            daySection
        }
    }

    private func changeMonth(_ delta: Int) {
        slideEdge = delta > 0 ? .trailing : .leading
        withAnimation(.smooth(duration: 0.35)) {
            month = month.adding(months: delta).startOfMonth
            if !router.selectedDate.isSameMonth(as: month) {
                router.selectedDate = month.isSameMonth(as: Date()) ? Date().startOfDay : month
            }
        }
    }

    private var daySection: some View {
        let selected = router.selectedDate
        let occurrences = plans.occurrences(on: selected)
        return VStack(alignment: .leading, spacing: 10) {
            DaySummaryHeader(day: selected, occurrences: occurrences) {
                Button { editorTarget = .new(selected) } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 32, height: 32)
                        .background(Theme.accent.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("이 날 할 일 추가")
            }
            if occurrences.isEmpty {
                Button { editorTarget = .new(selected) } label: {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "calendar.badge.plus", size: 40)
                        Text("일정이 없어요. 눌러서 추가해 보세요")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .softCard(cornerRadius: 20, padding: 16)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                PlanListCard(occurrences: occurrences) { occurrence in
                    PlanTimelineRow(occurrence: occurrence) { editorTarget = .edit(occurrence.plan) }
                        .contextMenu {
                            Button { editorTarget = .edit(occurrence.plan) } label: { Label("수정", systemImage: "pencil") }
                            Button(role: .destructive) {
                                context.delete(occurrence.plan)
                                try? context.save()
                                PlanScheduler.shared.rescheduleNotifications()
                            } label: {
                                Label(occurrence.plan.repeatRule == .none ? "삭제" : "반복 일정 전체 삭제", systemImage: "trash")
                            }
                        }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: Day timeline

    private var dayContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 4) {
                Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left").frame(width: 28, height: 40) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("이전 주")
                WeekStrip(selected: router.selectedDate) { day in
                    withAnimation(.snappy) { router.selectedDate = day.startOfDay }
                }
                Button { shiftWeek(1) } label: { Image(systemName: "chevron.right").frame(width: 28, height: 40) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("다음 주")
            }
            .padding(.vertical, 8)
            .softCardBackground(cornerRadius: 20)
            DaySummaryHeader(day: router.selectedDate, occurrences: plans.occurrences(on: router.selectedDate)) { EmptyView() }
            DayTimelineView(day: router.selectedDate, plans: plans) { plan in
                editorTarget = .edit(plan)
            }
            .softCard(cornerRadius: 20, padding: 14)
        }
    }

    private func shiftWeek(_ delta: Int) {
        withAnimation(.snappy) {
            router.selectedDate = router.selectedDate.adding(days: delta * 7)
        }
    }
}

// MARK: - Day timeline

struct DayTimelineView: View {
    let day: Date
    let plans: [Plan]
    var onOpen: (Plan) -> Void

    private let hourHeight: CGFloat = 58
    private let labelWidth: CGFloat = 56

    var body: some View {
        let occurrences = plans.occurrences(on: day)
        let allDay = occurrences.filter { $0.plan.isAllDay }
        let timed = occurrences.filter { !$0.plan.isAllDay }
        let layout = Self.columns(for: timed)

        VStack(alignment: .leading, spacing: 12) {
            if !allDay.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        Text("종일").font(.caption).foregroundStyle(.secondary)
                        ForEach(allDay) { occurrence in
                            Button { onOpen(occurrence.plan) } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(occurrence.plan.color).frame(width: 8, height: 8)
                                    Text(occurrence.plan.title)
                                }
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(occurrence.plan.color.opacity(0.12), in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            ZStack(alignment: .topLeading) {
                ForEach(0...24, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 4) {
                        Text(Self.hourLabel(hour))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .frame(width: labelWidth - 4, alignment: .leading)
                        DashedLine()
                            .padding(.top, 6)
                    }
                    .offset(y: CGFloat(hour) * hourHeight - 6)
                }

                // 스크롤 위치용 앵커 (offset은 레이아웃 위치를 바꾸지 않으므로 별도 배치)
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        Color.clear.frame(height: hourHeight).id("hour-\(hour)")
                    }
                }
                .allowsHitTesting(false)

                GeometryReader { geo in
                    let width = geo.size.width - labelWidth
                    let columns = CGFloat(max(layout.count, 1))
                    ForEach(timed) { occurrence in
                        let column = CGFloat(layout.column[occurrence.id] ?? 0)
                        let startMinutes = Self.minutes(of: occurrence.start)
                        let length = min(occurrence.end.timeIntervalSince(occurrence.start) / 60, Double(1440 - startMinutes))
                        let height = max(30, CGFloat(length) / 60 * hourHeight)
                        TimelineBlock(occurrence: occurrence, compact: height < 46)
                            .frame(width: width / columns - 4, height: height - 3)
                            .offset(x: labelWidth + column * width / columns, y: CGFloat(startMinutes) / 60 * hourHeight)
                            .onTapGesture { onOpen(occurrence.plan) }
                    }

                    if day.isSameDay(as: Date()) {
                        TimelineView(.everyMinute) { context in
                            let y = CGFloat(Self.minutes(of: context.date)) / 60 * hourHeight
                            HStack(spacing: 0) {
                                Text(context.date.kr("HH:mm"))
                                    .font(.system(size: 10, weight: .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Palette.danger, in: .rect(cornerRadius: 6))
                                Rectangle().fill(Palette.danger).frame(height: 2)
                            }
                            .offset(y: y - 8)
                        }
                    }
                }
            }
            .frame(height: 24 * hourHeight + 10)

            if occurrences.isEmpty {
                Text("이 날은 일정이 없어요. + 버튼으로 추가해보세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func minutes(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0, 24: return "자정"
        case 12: return "정오"
        case 1..<12: return "오전 \(hour)시"
        default: return "오후 \(hour - 12)시"
        }
    }

    /// 겹치는 일정은 옆 칸으로
    static func columns(for items: [PlanOccurrence]) -> (column: [String: Int], count: Int) {
        var lanes: [[PlanOccurrence]] = []
        var map: [String: Int] = [:]
        for item in items {
            var lane = 0
            while lane < lanes.count && lanes[lane].contains(where: { $0.end > item.start && $0.start < item.end }) {
                lane += 1
            }
            if lane == lanes.count { lanes.append([]) }
            lanes[lane].append(item)
            map[item.id] = lane
        }
        return (map, lanes.count)
    }
}

struct TimelineBlock: View {
    let occurrence: PlanOccurrence
    let compact: Bool

    var body: some View {
        let plan = occurrence.plan
        let time = "\(occurrence.start.kr("HH:mm"))–\(occurrence.end.kr("HH:mm"))"
        Group {
            if compact {
                HStack(spacing: 6) {
                    Text(plan.title).font(.caption.weight(.bold)).lineLimit(1)
                    Text(time).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title).font(.footnote.weight(.bold)).lineLimit(1)
                    Text(plan.isStudy ? "\(time) · \(TimeText.duration(minutes: plan.durationMinutes))" : time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 20)
        .padding(.vertical, compact ? 3 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: compact ? .leading : .topLeading)
        .background(plan.color.opacity(plan.isStudy ? 0.24 : 0.12))
        .overlay(alignment: .leading) { Rectangle().fill(plan.color).frame(width: 4) }
        .overlay(alignment: .topTrailing) {
            if plan.isStudy {
                Image(systemName: plan.lockApps ? "lock.fill" : "timer")
                    .font(.caption2)
                    .foregroundStyle(plan.color)
                    .padding(6)
            }
        }
        .clipShape(.rect(cornerRadius: 10))
        .opacity(occurrence.isCompleted ? 0.55 : 1)
        .contentShape(.rect(cornerRadius: 10))
    }
}

// MARK: - Calendar grid

struct CalendarGrid: View {
    let month: Date
    @Binding var selected: Date
    let plans: [Plan]

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var days: [Date] {
        let cal = Calendar.current
        let first = month.startOfMonth
        let weekday = cal.component(.weekday, from: first)
        let start = first.adding(days: -(weekday - 1))
        let daysInMonth = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let rows = Int(ceil(Double(weekday - 1 + daysInMonth) / 7.0))
        return (0..<(rows * 7)).map { start.adding(days: $0) }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(index == 0 ? Palette.danger : (index == 6 ? Theme.accent : Color.secondary))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(days, id: \.self) { day in
                    DayCell(
                        day: day,
                        inMonth: day.isSameMonth(as: month),
                        isSelected: day.isSameDay(as: selected),
                        isToday: day.isSameDay(as: Date()),
                        events: plans.occurrences(on: day).map { DayCell.Event(title: $0.plan.title, color: $0.plan.color, done: $0.isCompleted) }
                    )
                    .onTapGesture {
                        withAnimation(.snappy) { selected = day.startOfDay }
                        Haptics.tap()
                    }
                }
            }
        }
    }
}

/// 달력 한 칸: 날짜 숫자 + 일정 이름 띠 두 개까지 (+n)
private struct DayCell: View {
    struct Event {
        let title: String
        let color: Color
        let done: Bool
    }

    let day: Date
    let inMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let events: [Event]

    var body: some View {
        let weekday = Calendar.current.component(.weekday, from: day)
        VStack(spacing: 3) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.footnote.weight(isToday || isSelected ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(textColor(weekday: weekday))
                .frame(width: 26, height: 26)
                .background {
                    if isSelected {
                        Circle().fill(Theme.accent)
                    } else if isToday {
                        Circle().fill(Theme.accent.opacity(0.14))
                    }
                }

            VStack(spacing: 2) {
                ForEach(Array(events.prefix(2).enumerated()), id: \.offset) { _, event in
                    Text(event.title)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .strikethrough(event.done)
                        .foregroundStyle(event.color)
                        .padding(.horizontal, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 14)
                        .background(event.color.opacity(0.14), in: .rect(cornerRadius: 3))
                        .opacity(event.done ? 0.5 : 1)
                }
                if events.count > 2 {
                    Text("+\(events.count - 2)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(height: 10)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .top)
        .background(isSelected ? Theme.accent.opacity(0.06) : Color.clear, in: .rect(cornerRadius: 10))
        .opacity(inMonth ? 1 : 0.3)
        .contentShape(Rectangle())
    }

    private func textColor(weekday: Int) -> Color {
        if isSelected { return .white }
        if isToday { return Theme.accent }
        if weekday == 1 { return Palette.danger }
        if weekday == 7 { return Theme.accent }
        return Palette.ink
    }
}

/// 고른 날 머리말: "11월 2일 월요일 · 오늘" + "할 일 3 · 완료 1 · 공부 2시간" + 완료 막대
private struct DaySummaryHeader<Trailing: View>: View {
    let day: Date
    let occurrences: [PlanOccurrence]
    @ViewBuilder var trailing: Trailing

    var body: some View {
        let done = occurrences.filter(\.isCompleted).count
        let studyMinutes = occurrences.filter { $0.plan.isStudy }.reduce(0) { $0 + $1.plan.durationMinutes }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(day.kr("M월 d일 EEEE"))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Palette.ink)
                        if day.isSameDay(as: Date()) {
                            Text("오늘")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Theme.accent.opacity(0.12), in: .capsule)
                        }
                    }
                    if !occurrences.isEmpty {
                        Text(summary(done: done, studyMinutes: studyMinutes))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            if !occurrences.isEmpty {
                LinearProgressBar(value: Double(done) / Double(occurrences.count), height: 5)
            }
        }
        .padding(.horizontal, 4)
    }

    private func summary(done: Int, studyMinutes: Int) -> String {
        var parts = ["할 일 \(occurrences.count)개", "완료 \(done)개"]
        if studyMinutes > 0 { parts.append("공부 \(TimeText.duration(minutes: studyMinutes))") }
        return parts.joined(separator: " · ")
    }
}
