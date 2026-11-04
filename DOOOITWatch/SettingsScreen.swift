import SwiftUI

/// 워치 설정: 진동 · 30분마다 진동 · 기본 목표 · 뽀모도로 길이
struct SettingsScreen: View {
    @Environment(WatchStore.self) private var store
    @AppStorage(WatchPrefs.hapticsKey) private var haptics = true
    @AppStorage(WatchPrefs.milestonesKey) private var milestones = true
    @AppStorage(WatchPrefs.targetKey) private var targetIndex = 5
    @AppStorage(WatchPrefs.focusKey) private var focusMinutes = 25
    @AppStorage(WatchPrefs.restKey) private var restMinutes = 5

    private var choices: [Int?] { WatchTimerState.targetChoices }

    var body: some View {
        List {
            Section {
                Toggle("진동", isOn: $haptics)
                Toggle("30분마다 진동", isOn: $milestones)
                    .disabled(!haptics)
            }
            Section("기본 목표") {
                Picker("목표", selection: $targetIndex) {
                    ForEach(choices.indices, id: \.self) { i in
                        Text(WatchTimerState.targetLabel(choices[i])).tag(i)
                    }
                }
            }
            Section("뽀모도로") {
                Picker("집중 · 휴식", selection: Binding(
                    get: { WatchPrefs.focusChoices.firstIndex { $0.focus == focusMinutes && $0.rest == restMinutes } ?? 0 },
                    set: { i in
                        focusMinutes = WatchPrefs.focusChoices[i].focus
                        restMinutes = WatchPrefs.focusChoices[i].rest
                    })) {
                    ForEach(WatchPrefs.focusChoices.indices, id: \.self) { i in
                        Text("\(WatchPrefs.focusChoices[i].focus)분 · \(WatchPrefs.focusChoices[i].rest)분").tag(i)
                    }
                }
            }
        }
        .tint(store.snapshot.accent)
        .navigationTitle("설정")
    }
}
