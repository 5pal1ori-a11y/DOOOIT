import SwiftUI
import WatchKit

/// 할 일: 오늘 · 내일. 눌러서 완료, 왼쪽에서 밀어 타이머 시작, 말하거나 손글씨로 추가 (아이폰 플래너에 바로 반영)
struct TodayScreen: View {
    @Environment(WatchStore.self) private var store
    @AppStorage(WatchPrefs.targetKey) private var targetIndex = 5
    @State private var todayDraft = ""
    @State private var tomorrowDraft = ""

    private var plans: [WatchPlanItem] { store.snapshot.plans }
    private var tomorrow: [WatchPlanItem] { store.snapshot.tomorrow }
    private var accent: Color { store.snapshot.accent }
    private var tomorrowKey: String {
        WatchLink.dayKey(Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    }

    var body: some View {
        List {
            Section {
                if plans.isEmpty {
                    WatchEmpty(symbol: "sparkles", text: L("오늘 할 일이 없어요"), color: accent)
                        .listRowBackground(Color.clear)
                }
                ForEach(plans) { plan in
                    row(plan, canStart: true)
                }
                addField($todayDraft, prompt: "할 일 추가", dayKey: WatchLink.dayKey(Date()))
            } header: {
                if !plans.isEmpty {
                    Text("\(plans.filter(\.isDone).count)/\(plans.count) 완료")
                }
            }

            Section("내일") {
                ForEach(tomorrow) { plan in
                    row(plan, canStart: false)
                }
                addField($tomorrowDraft, prompt: "내일 할 일", dayKey: tomorrowKey)
            }
        }
        .navigationTitle("할 일")
    }

    private func row(_ plan: WatchPlanItem, canStart: Bool) -> some View {
        let color = Color(watchHex: plan.colorHex)
        return Button {
            guard !plan.isSending else { return }
            store.send(.setPlanDone(planID: plan.planID, dayKey: plan.dayKey, done: !plan.isDone))
            WatchHaptics.play(plan.isDone ? .click : .success)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: plan.isSending ? "arrow.up.circle" : (plan.isDone ? "checkmark.circle.fill" : "circle"))
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
        .opacity(plan.isSending ? 0.6 : 1)
        .swipeActions(edge: .leading) {
            if canStart && !plan.isDone && !plan.isSending && !store.snapshot.timer.isActive {
                Button {
                    let choices = WatchTimerState.targetChoices
                    store.start(minutes: choices[min(max(targetIndex, 0), choices.count - 1)], plan: plan)
                } label: {
                    Label("시작", systemImage: "play.fill")
                }
                .tint(accent)
            }
        }
        .accessibilityLabel("\(plan.title), \(plan.isDone ? "완료" : "할 일")")
    }

    /// 누르면 받아쓰기 · 손글씨 · 키보드 ("4시 수학 1시간"처럼 말하면 시간도 들어감)
    private func addField(_ text: Binding<String>, prompt: String, dayKey: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(accent)
            TextField(prompt, text: text)
                .font(.footnote)
                .submitLabel(.done)
                .onSubmit {
                    let value = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    text.wrappedValue = ""
                    guard !value.isEmpty, !dayKey.isEmpty else { return }
                    store.send(.addPlan(text: value, dayKey: dayKey))
                    WatchHaptics.play(.success)
                }
        }
    }
}
