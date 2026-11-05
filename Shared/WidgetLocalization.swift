import Foundation

// 위젯 화면용 번역 (WidgetSnapshot.swift의 한국어 계산은 테스트 그대로 두고, 화면에는 고른 언어로)

extension WidgetMath {
    /// 1시간 20분 / 1h 20m / 1小时20分钟 / 1時間20分
    static func durationTextL(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return L("\(h)시간 \(m)분") }
        if h > 0 { return L("\(h)시간") }
        return L("\(m)분")
    }

    /// 그래프 숫자용 아주 짧은 표기
    static func compactHoursL(_ minutes: Int) -> String {
        if minutes < 60 { return L("\(minutes)분") }
        let hours = Double(minutes) / 60
        if hours >= 10 || minutes % 60 == 0 { return L("\(Int(hours.rounded()))시간") }
        let text = String(format: "%.1f", hours)
        return L("\(text)시간")
    }
}
