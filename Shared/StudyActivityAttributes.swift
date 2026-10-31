import ActivityKit
import Foundation

/// 앱과 위젯 익스텐션(다이나믹 아일랜드)이 함께 사용하는 Live Activity 모델
struct StudyActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case upcoming   // 일정 시작 전 카운트다운
            case studying   // 공부 타이머 진행 중
            case paused     // 일시정지
        }

        var phase: Phase
        /// upcoming: 일정 시작 시각 / studying: 타이머 기준 시각(현재 - 경과시간)
        var referenceDate: Date
        /// paused 상태일 때 표시할 누적 시간(초)
        var pausedElapsed: TimeInterval
    }

    var title: String
    var categoryName: String
    var symbol: String
    var planKey: String
}

enum ActivityTimeFormat {
    static func clock(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
}
