import Foundation
import SwiftUI

/// 앱이 홈 화면 위젯에 넘겨주는 오늘의 요약 (App Group으로 공유)
struct WidgetSnapshot: Codable {
    struct PlanItem: Codable, Hashable {
        var title: String
        var time: String
        var colorHex: String
        var isDone: Bool
        var isStudy: Bool
    }

    struct WordItem: Codable, Hashable {
        var term: String
        var meaning: String
    }

    var updatedAt = Date()
    var dayKey = ""
    var plans: [PlanItem] = []
    var dDayTitle = ""
    var dDayDate: Date?
    var words: [WordItem] = []
    var wordsLeft = 0
    var studyMinutes = 0
    var goalMinutes = 180
    var streak = 0
    var accentHex = "#7B68EE"

    static let appGroup = "group.com.bravekoon.dooit"
    private static let key = "widgetSnapshot.v1"

    static func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroup),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }

    /// 오늘 날짜 기준 D-Day 문구 (D-12, D-DAY, D+3)
    func dDayText(on date: Date = Date()) -> String? {
        guard !dDayTitle.isEmpty, let dDayDate else { return nil }
        let calendar = Calendar.current
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: dDayDate)).day ?? 0
        return diff > 0 ? "D-\(diff)" : (diff == 0 ? "D-DAY" : "D+\(-diff)")
    }

    /// 위젯이 늦게 갱신돼서 어제 데이터일 때
    var isStale: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return dayKey != formatter.string(from: Date())
    }

    static func color(_ hex: String) -> Color {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
