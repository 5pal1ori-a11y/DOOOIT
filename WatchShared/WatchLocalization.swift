import Foundation

// 워치 · 워치 위젯 화면용 번역 (WatchProtocol.swift의 한국어 계산은 테스트 그대로 두고, 화면에는 그 기기 언어로)

extension WatchFormat {
    /// 1시간 35분 · 40분 (그 언어로)
    static func durationL(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return L("\(m)분") }
        return m == 0 ? L("\(h)시간") : L("\(h)시간 \(m)분")
    }

    /// 1:35 (좁은 칸용 시:분)
    static func shortL(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return minutes >= 60 ? String(format: "%d:%02d", minutes / 60, minutes % 60) : L("\(minutes)분")
    }
}

extension WatchTimerState {
    static func targetLabelL(_ minutes: Int?) -> String {
        guard let minutes else { return "∞" }
        if minutes < 60 { return L("\(minutes)분") }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? L("\(h)시간") : L("\(h)시간 \(m)분")
    }
}
