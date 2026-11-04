import SwiftData
import SwiftUI

/// 홈 화면 위젯에서 누른 것 처리: 플랜 완료 체크 (기존 Plan.toggleCompleted 규칙 그대로)
@MainActor
enum WidgetActions {
    /// 지금 계정 저장소 (앱을 켤 때 · 계정을 바꿀 때 연결)
    static var container: ModelContainer?

    static func attach(_ container: ModelContainer) {
        self.container = container
        // 위젯 버튼이 앱에서 실행될 때 바로 저장하도록 연결
        WidgetIntentBridge.setPlanDone = { occurrenceID, done in
            guard let context = WidgetActions.container?.mainContext else { return false }
            guard setPlanDone(occurrenceID, done: done, context: context) else { return false }
            WidgetSync.update(context: context)
            return true
        }
    }

    /// 일정 하나 완료 상태 맞추기 (이미 그 상태면 그대로)
    @discardableResult
    static func setPlanDone(_ occurrenceID: String, done: Bool, context: ModelContext) -> Bool {
        guard let parts = WidgetPending.split(occurrenceID),
              let id = UUID(uuidString: parts.planID),
              let day = KoreanDate.dayKeyFormatter.date(from: parts.dayKey) else { return false }
        let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        guard let plan = plans.first(where: { $0.id == id }), plan.occurs(on: day) else { return false }
        if plan.isCompleted(on: day) != done {
            plan.toggleCompleted(on: day)
            try? context.save()
        }
        return true
    }

    /// 위젯 확장에서 적어 둔 완료 체크를 저장
    static func applyPending(context: ModelContext) {
        let pending = WidgetPending.load()
        guard !pending.isEmpty else { return }
        WidgetPending.clear()
        for (occurrenceID, done) in pending {
            setPlanDone(occurrenceID, done: done, context: context)
        }
    }
}
