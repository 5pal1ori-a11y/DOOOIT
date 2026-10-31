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
    @Query(sort: \Plan.startDate) private var plans: [Plan]

    @State private var month = Date().startOfMonth
    @State private var selected = Date().startOfDay
    @State private var editorTarget: PlanEditorTarget?
    @State private var showCategories = false
    @State private var slideEdge: Edge = .trailing

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    monthHeader

                    CalendarGrid(month: month, selected: $selected, plans: plans)
                        .id(month)
                        .transition(.asymmetric(
                            insertion: .move(edge: slideEdge).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .glassCard(padding: 14)
                        .gesture(
                            DragGesture(minimumDistance: 30)
                                .onEnded { value in
                                    if value.translation.width < -50 { changeMonth(1) }
                                    if value.translation.width > 50 { changeMonth(-1) }
                                }
                        )

                    dayList
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { AppBackground() }
            .navigationTitle("플래너")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showCategories = true } label: {
                        Image(systemName: "tag")
                    }
                    .accessibilityLabel("카테고리 관리")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editorTarget = .new(selected) } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("플랜 추가")
                }
            }
            .sheet(item: $editorTarget) { target in
                PlanEditorView(target: target)
            }
            .sheet(isPresented: $showCategories) {
                NavigationStack { CategoryManagerView() }
            }
        }
    }

    // MARK: Month header

    private var monthHeader: some View {
        HStack(spacing: 10) {
            Text(month.kr("yyyy년 M월"))
                .font(.title2.weight(.bold))
                .contentTransition(.numericText())
            Spacer()
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button { changeMonth(-1) } label: {
                        Image(systemName: "chevron.left").frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)

                    Button {
                        withAnimation(.smooth) {
                            month = Date().startOfMonth
                            selected = Date().startOfDay
                        }
                    } label: {
                        Text("오늘")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)

                    Button { changeMonth(1) } label: {
                        Image(systemName: "chevron.right").frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func changeMonth(_ delta: Int) {
        slideEdge = delta > 0 ? .trailing : .leading
        withAnimation(.smooth(duration: 0.35)) {
            month = month.adding(months: delta).startOfMonth
            if !selected.isSameMonth(as: month) {
                selected = month.isSameMonth(as: Date()) ? Date().startOfDay : month
            }
        }
    }

    // MARK: Day list

    private var dayList: some View {
        let occurrences = plans.occurrences(on: selected)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selected.kr("M월 d일 EEEE"))
                    .font(.headline)
                if selected.isSameDay(as: Date()) {
                    TagLabel(text: "오늘")
                }
                Spacer()
                Text("\(occurrences.count)개 일정")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            if occurrences.isEmpty {
                Button { editorTarget = .new(selected) } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title)
                            .foregroundStyle(Color.accentColor)
                        Text("일정이 없어요").font(.headline)
                        Text("눌러서 할 일을 추가해보세요").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .glassCard(interactive: true)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(occurrences) { occurrence in
                    PlanRow(occurrence: occurrence)
                        .glassCard(cornerRadius: 22, padding: 14)
                        .contentShape(.rect(cornerRadius: 22))
                        .onTapGesture { editorTarget = .edit(occurrence.plan) }
                        .contextMenu {
                            Button { editorTarget = .edit(occurrence.plan) } label: {
                                Label("수정", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                context.delete(occurrence.plan)
                                try? context.save()
                                PlanScheduler.shared.rescheduleNotifications()
                            } label: {
                                Label(occurrence.plan.repeatRule == .none ? "삭제" : "반복 일정 전체 삭제", systemImage: "trash")
                            }
                        }
                }
            }
        }
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
        let weekday = cal.component(.weekday, from: first) // 1 = 일요일
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
                        .foregroundStyle(index == 0 ? Color.red.opacity(0.85) : (index == 6 ? Color.blue.opacity(0.85) : Color.secondary))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    DayCell(
                        day: day,
                        inMonth: day.isSameMonth(as: month),
                        isSelected: day.isSameDay(as: selected),
                        isToday: day.isSameDay(as: Date()),
                        colors: plans.occurrences(on: day).prefix(3).map { $0.plan.color }
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

private struct DayCell: View {
    let day: Date
    let inMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let colors: [Color]

    var body: some View {
        let weekday = Calendar.current.component(.weekday, from: day)
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.callout.weight(isToday || isSelected ? .bold : .regular))
                .foregroundStyle(textColor(weekday: weekday))
                .frame(width: 36, height: 36)
                .background {
                    if isSelected {
                        Circle().fill(Color.accentColor)
                    } else if isToday {
                        Circle().stroke(Color.accentColor, lineWidth: 1.5)
                    }
                }

            HStack(spacing: 3) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    Circle().fill(color).frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .opacity(inMonth ? 1 : 0.3)
        .contentShape(Rectangle())
    }

    private func textColor(weekday: Int) -> Color {
        if isSelected { return .white }
        if isToday { return .accentColor }
        if weekday == 1 { return .red.opacity(0.85) }
        if weekday == 7 { return .blue.opacity(0.85) }
        return .primary
    }
}
