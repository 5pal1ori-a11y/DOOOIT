import AppIntents
import Foundation
import WidgetKit

/// 앱 안에서만 채워지는 연결 (위젯 확장에서는 비어 있음)
enum WidgetIntentBridge {
    /// 일정 이름표(플랜ID_날짜), 완료 상태 → 저장했으면 true
    @MainActor static var setPlanDone: ((String, Bool) -> Bool)?
}

/// 위젯의 체크 버튼: 플랜 완료 / 완료 취소
/// - 앱 안에서 실행되면 바로 저장 (LiveActivityIntent는 앱과 위젯 둘 다에 들어 있으면 앱에서 실행됨)
/// - 위젯 확장에서 실행되면 App Group에 적어 두고, 앱이 다음에 켜질 때 저장 · 위젯은 바로 체크된 모양으로
struct TogglePlanDoneIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "플랜 완료"
    static let description = IntentDescription("위젯에서 오늘 플랜을 완료로 체크해요.")
    static let isDiscoverable = false

    @Parameter(title: "일정")
    var occurrenceID: String

    @Parameter(title: "완료")
    var done: Bool

    init() {}

    init(occurrenceID: String, done: Bool) {
        self.occurrenceID = occurrenceID
        self.done = done
    }

    func perform() async throws -> some IntentResult {
        let id = occurrenceID
        let want = done
        let saved = await MainActor.run { WidgetIntentBridge.setPlanDone?(id, want) ?? false }
        if !saved {
            WidgetPending.add(id, done: want)
            WidgetSnapshot.load().settingPlan(id, done: want).save()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 위젯을 누르면 여는 앱 화면 (RootView의 onOpenURL이 처리)
enum WidgetLink {
    static let home = URL(string: "dooit://home")!
    static let words = URL(string: "dooit://words")!
    static let weeklyReport = URL(string: "dooit://weekly-report")!

    /// 플래너 (날짜를 주면 그날로)
    static func planner(_ dayKey: String? = nil) -> URL {
        guard let dayKey else { return URL(string: "dooit://planner")! }
        return URL(string: "dooit://planner?date=\(dayKey)")!
    }

    /// 공부 타이머 (분을 주면 바로 시작, 0이면 시간 제한 없이 시작, nil이면 타이머 화면만)
    static func timer(minutes: Int? = nil) -> URL {
        guard let minutes else { return URL(string: "dooit://timer")! }
        return URL(string: "dooit://timer?start=\(minutes)")!
    }
}
