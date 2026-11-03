import SwiftUI
import WatchKit

/// 오늘 할 일: 눌러서 완료 (아이폰 플래너에 바로 반영)
struct TodayScreen: View {
    @Environment(WatchStore.self) private var store

    private var plans: [WatchPlanItem] { store.snapshot.plans }

    var body: some View {
        List {
            if plans.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(store.snapshot.accent)
                    Text("오늘 할 일이 없어요")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(plans) { plan in
                        row(plan)
                    }
                } header: {
                    Text("\(plans.filter(\.isDone).count)/\(plans.count) 완료")
                }
            }
        }
        .navigationTitle("오늘 할 일")
    }

    private func row(_ plan: WatchPlanItem) -> some View {
        let color = Color(watchHex: plan.colorHex)
        return Button {
            store.send(.setPlanDone(planID: plan.planID, dayKey: plan.dayKey, done: !plan.isDone))
            WKInterfaceDevice.current().play(plan.isDone ? .click : .success)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: plan.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(plan.isDone ? color : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 1) {
                    Text(plan.title)
                        .font(.footnote.weight(.semibold))
                        .strikethrough(plan.isDone)
                        .foregroundStyle(plan.isDone ? .secondary : .primary)
                        .lineLimit(2)
                    Text(plan.time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Capsule().fill(color).frame(width: 3, height: 20)
            }
        }
        .accessibilityLabel("\(plan.title), \(plan.isDone ? "완료" : "할 일")")
    }
}
