import Observation
import SwiftData
import SwiftUI

/// 홈의 주간 달력에서 플래너 하루 타임라인으로 이동할 때 쓰는 공유 상태
enum PlannerMode: String, CaseIterable, Identifiable {
    case month, day
    var id: String { rawValue }
    var title: String { self == .month ? L("월간") : L("하루 타임라인") }
    var symbol: String { self == .month ? "calendar" : "list.bullet" }
}

@MainActor
@Observable
final class PlannerRouter {
    var selectedDate: Date = Date().startOfDay
    var mode: PlannerMode = .month
    var scrollRequest = 0
}

// MARK: - D-Day 칩

struct DDayChip: View {
    @AppStorage(SettingsKey.dDayTitle) private var title = ""
    @AppStorage(SettingsKey.dDayDate) private var date: Double = 0

    var body: some View {
        if !title.isEmpty && date > 0 {
            let diff = Calendar.current.dateComponents([.day], from: Date().startOfDay,
                                                       to: Date(timeIntervalSince1970: date).startOfDay).day ?? 0
            HStack(spacing: 5) {
                Text(title).foregroundStyle(Theme.onHighlight.opacity(0.7))
                Text(diff > 0 ? "D-\(diff)" : (diff == 0 ? "D-DAY" : "D+\(-diff)"))
                    .fontWeight(.heavy)
                    .foregroundStyle(Theme.onHighlight)
            }
            .font(.pt(.caption).weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(Theme.highlight, in: .capsule)
        }
    }
}

// MARK: - 주간 달력 스트립

struct WeekStrip: View {
    let selected: Date
    var onSelect: (Date) -> Void

    @Query private var plans: [Plan]

    var body: some View {
        let cal = Calendar.current
        let start = selected.startOfDay.adding(days: -(cal.component(.weekday, from: selected) - 1))
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                let day = start.adding(days: i)
                let isSelected = day.isSameDay(as: selected)
                let isToday = day.isSameDay(as: Date())
                Button {
                    onSelect(day)
                } label: {
                    VStack(spacing: 5) {
                        Text(day.ui("E"))
                            .font(.pt(.caption2).weight(.semibold))
                            .foregroundStyle(i == 0 ? Palette.danger : (i == 6 ? Theme.accent : Color.secondary))
                        Text("\(cal.component(.day, from: day))")
                            .font(.pt(.callout).weight(.bold))
                            .monospacedDigit()
                            .frame(width: 34, height: 34)
                            .foregroundStyle(isSelected ? Theme.onAccent : (isToday ? Theme.onHighlight : Palette.ink))
                            .background(isSelected ? AnyShapeStyle(Theme.accent) : (isToday ? AnyShapeStyle(Theme.highlight) : AnyShapeStyle(Color.clear)), in: .circle)
                            .overlay(Circle().strokeBorder(isToday && !isSelected ? Theme.accent.opacity(0.4) : Color.clear, lineWidth: 1.5))
                        HStack(spacing: 3) {
                            ForEach(Array(plans.occurrences(on: day).prefix(3).enumerated()), id: \.offset) { _, o in
                                Circle().fill(o.plan.color).frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(.rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .softCardBackground(cornerRadius: 22)
    }
}

// MARK: - 타임라인 형태의 플랜 행 (홈 · 플래너 공용)

/// 할 일 한 줄 (체크리스트처럼): 체크 원 · 제목 · 시간과 카테고리 · 색 표시
struct PlanTimelineRow: View {
    let occurrence: PlanOccurrence
    var onOpen: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        let plan = occurrence.plan
        let done = occurrence.isCompleted

        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { plan.toggleCompleted(on: occurrence.day) }
                try? context.save()
                Haptics.tap()
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.pt(.title2))
                    .foregroundStyle(done ? plan.color : Color.secondary.opacity(0.6))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? L("완료 취소") : L("완료로 표시"))

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title)
                    .font(.pt(.body).weight(.medium))
                    .strikethrough(done)
                    .foregroundStyle(done ? Color.secondary : Palette.ink)
                    .lineLimit(1)
                subtitle
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Capsule()
                .fill(plan.color)
                .frame(width: 4, height: 26)
                .opacity(done ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    private var subtitle: Text {
        let plan = occurrence.plan
        let name = plan.category?.name.loc ?? (plan.isStudy ? L("공부") : L("일반"))
        let time = plan.isAllDay ? L("종일") : "\(occurrence.start.ui("a h:mm")) – \(occurrence.end.ui("h:mm"))"
        if plan.isStudy {
            let base = Text("\(time) · \(name) · \(TimeText.durationL(minutes: plan.durationMinutes))")
            return plan.lockApps ? Text("\(base) · \(Image(systemName: "lock.fill"))") : base
        }
        return Text("\(time) · \(name)")
    }
}

/// 할 일 목록 카드 (줄 사이 구분선)
struct PlanListCard<Row: View>: View {
    let occurrences: [PlanOccurrence]
    @ViewBuilder var row: (PlanOccurrence) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(occurrences.enumerated()), id: \.element.id) { index, occurrence in
                row(occurrence)
                if index < occurrences.count - 1 { Divider().padding(.leading, 52) }
            }
        }
        .softCardBackground(cornerRadius: 20)
    }
}

// MARK: - 기존 리스트형 행 (오늘의 플랜 전체 보기에서 사용)

struct PlanRow: View {
    let occurrence: PlanOccurrence
    @Environment(\.modelContext) private var context

    var body: some View {
        let plan = occurrence.plan
        let completed = occurrence.isCompleted

        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { plan.toggleCompleted(on: occurrence.day) }
                try? context.save()
                Haptics.tap()
            } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.pt(.title3))
                    .foregroundStyle(completed ? plan.color : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            RoundedRectangle(cornerRadius: 2)
                .fill(plan.color)
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title)
                    .font(.pt(.body).weight(.semibold))
                    .strikethrough(completed)
                    .foregroundStyle(completed ? Color.secondary : Color.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(occurrence.timeText)
                    if let category = plan.category {
                        Label(category.name, systemImage: category.symbol)
                    }
                    if plan.repeatRule != .none {
                        Image(systemName: "repeat")
                    }
                }
                .font(.pt(.caption))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            if plan.isStudy {
                Image(systemName: plan.lockApps ? "lock.fill" : "timer")
                    .font(.pt(.caption).weight(.semibold))
                    .foregroundStyle(plan.color)
            }
        }
    }
}

/// 오늘의 플랜 전체 보기
struct TodayPlansSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Plan.startDate) private var plans: [Plan]
    @State private var editing: Plan?

    var body: some View {
        NavigationStack {
            let occurrences = plans.occurrences(on: Date())
            List {
                Section {
                    ForEach(occurrences) { occurrence in
                        PlanRow(occurrence: occurrence)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = occurrence.plan }
                    }
                } footer: {
                    Text("완료 \(occurrences.filter(\.isCompleted).count) / \(occurrences.count)")
                }
            }
            .navigationTitle("오늘의 플랜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "checkmark") }
                }
            }
            .sheet(item: $editing) { plan in
                PlanEditorView(target: .edit(plan))
            }
        }
    }
}
