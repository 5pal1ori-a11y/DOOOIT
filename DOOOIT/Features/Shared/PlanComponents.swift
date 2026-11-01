import Observation
import SwiftData
import SwiftUI

/// 홈의 주간 달력에서 플래너 하루 타임라인으로 이동할 때 쓰는 공유 상태
enum PlannerMode: String, CaseIterable, Identifiable {
    case month, day
    var id: String { rawValue }
    var title: String { self == .month ? "월간" : "하루 타임라인" }
    var symbol: String { self == .month ? "calendar" : "calendar.day.timeline.left" }
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
                Text(title).foregroundStyle(.secondary)
                Text(diff > 0 ? "D-\(diff)" : (diff == 0 ? "D-DAY" : "D+\(-diff)"))
                    .fontWeight(.heavy)
                    .foregroundStyle(Theme.accent)
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.primary.opacity(0.06), in: .capsule)
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
                        Text(day.kr("E"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(i == 0 ? Palette.danger : (i == 6 ? Theme.accent : Color.secondary))
                        Text("\(cal.component(.day, from: day))")
                            .font(.callout.weight(.bold))
                            .monospacedDigit()
                            .frame(width: 34, height: 34)
                            .foregroundStyle(isSelected ? Color.white : (isToday ? Theme.accent : Color.primary))
                            .background(isSelected ? Theme.accent : Color.clear, in: .circle)
                        HStack(spacing: 3) {
                            ForEach(Array(plans.occurrences(on: day).prefix(3).enumerated()), id: \.offset) { _, o in
                                Circle().fill(o.plan.color).frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.primary.opacity(0.06) : Color.clear, in: .rect(cornerRadius: 18))
                    .contentShape(.rect(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 타임라인 형태의 플랜 행 (홈 · 플래너 공용)

struct PlanTimelineRow: View {
    let occurrence: PlanOccurrence
    var onOpen: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        let plan = occurrence.plan
        let done = occurrence.isCompleted

        HStack(alignment: .top, spacing: 8) {
            Text(plan.isAllDay ? "종일" : occurrence.start.kr("HH:mm"))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
                .padding(.top, 15)

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                Circle()
                    .fill(plan.color)
                    .frame(width: 12, height: 12)
                    .padding(.top, 17)
            }
            .frame(width: 14)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(.body.weight(.semibold))
                        .strikethrough(done)
                        .foregroundStyle(done ? Color.secondary : Color.primary)
                        .lineLimit(1)
                    subtitle
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(.snappy) { plan.toggleCompleted(on: occurrence.day) }
                    try? context.save()
                    Haptics.tap()
                } label: {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(done ? plan.color : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(done ? "완료 취소" : "완료로 표시")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(plan.isStudy ? plan.color.opacity(0.15) : Color.clear, in: .rect(cornerRadius: 16))
            .contentShape(.rect(cornerRadius: 16))
            .onTapGesture(perform: onOpen)
            .padding(.vertical, 3)
        }
    }

    private var subtitle: Text {
        let plan = occurrence.plan
        let name = plan.category?.name ?? (plan.isStudy ? "공부" : "일반")
        if plan.isStudy {
            let base = Text("\(Image(systemName: "timer")) \(name) · \(TimeText.duration(minutes: plan.durationMinutes))")
            return plan.lockApps ? Text("\(base) · \(Image(systemName: "lock.fill")) 앱 잠금") : base
        }
        if plan.isAllDay { return Text(name) }
        return Text("\(name) · \(occurrence.end.kr("a h:mm"))까지")
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
                    .font(.title3)
                    .foregroundStyle(completed ? plan.color : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            RoundedRectangle(cornerRadius: 2)
                .fill(plan.color)
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title)
                    .font(.body.weight(.semibold))
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
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            if plan.isStudy {
                Image(systemName: plan.lockApps ? "lock.fill" : "timer")
                    .font(.caption.weight(.semibold))
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
