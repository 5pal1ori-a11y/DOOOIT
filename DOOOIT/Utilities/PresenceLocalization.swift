import Foundation

// AI 순공부 측정 화면용 번역 도우미 (StudyPresence.swift의 PresenceText는 Foundation만 쓰는 한국어 그대로: Linux 테스트용)

extension StudyPresenceState {
    /// 화면용 이름 (고른 언어로)
    var labelL: String { label.loc }
}

extension PresenceText {
    /// 타이머 위 칩: "공부 중" / "자리 비움"
    static func chipL(state: StudyPresenceState, netSeconds: Int) -> String {
        if state == .away { return L("자리 비움") }
        return state.label.loc
    }

    /// 결과 한 줄: "총 1:00 · 집중도 87%"
    static func resultL(totalSeconds: Int, summary: PresenceSummary) -> String {
        L("총 \(span(totalSeconds, unit: "초".loc)) · 집중도 \(summary.focusPercent)%")
    }

    /// 순공부가 아닌 시간: "자리 비움 5분 · 멈춤 3분"
    static func breakdownL(_ summary: PresenceSummary) -> String {
        let parts: [(String, Int)] = [("자리 비움", summary.awaySeconds), ("멈춤", summary.stillSeconds), ("딴짓", summary.distractedSeconds)]
        return parts.filter { $0.1 >= 60 }.map { L("\($0.0.loc) \($0.1 / 60)분") }.joined(separator: " · ")
    }
}
