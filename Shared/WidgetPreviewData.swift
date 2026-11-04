import Foundation

extension WidgetSnapshot {
    /// 위젯 고르기 화면 · 앱 데이터가 아직 없을 때 보여 줄 예시
    static var preview: WidgetSnapshot { preview(now: Date()) }

    static func preview(now: Date, calendar: Calendar = .current) -> WidgetSnapshot {
        var snapshot = WidgetSnapshot()
        let today = calendar.startOfDay(for: now)
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let d = calendar.date(byAdding: .day, value: day, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: d) ?? d
        }
        let key = WidgetMath.dayKey(today)
        snapshot.updatedAt = now
        snapshot.dayKey = key
        snapshot.plans = [
            PlanItem(title: "수학 문제집 3단원", time: "오후 4:00", colorHex: "#3D9BE0", isDone: true, isStudy: true,
                     planID: "preview-1", dayKey: key, start: at(0, 16), end: at(0, 17), isAllDay: false),
            PlanItem(title: "영어 단어 30개", time: "오후 7:00", colorHex: "#7B68EE", isDone: false, isStudy: true,
                     planID: "preview-2", dayKey: key, start: at(0, 19), end: at(0, 19, 30), isAllDay: false),
            PlanItem(title: "국어 비문학", time: "오후 9:00", colorHex: "#4CAF63", isDone: false, isStudy: true,
                     planID: "preview-3", dayKey: key, start: at(0, 21), end: at(0, 22), isAllDay: false)
        ]
        snapshot.upcoming = [
            PlanItem(title: "영어 단어 30개", time: "오후 7:00", colorHex: "#7B68EE", isDone: false, isStudy: true,
                     planID: "preview-2", dayKey: key, start: at(0, 19), end: at(0, 19, 30), isAllDay: false),
            PlanItem(title: "국어 비문학", time: "오후 9:00", colorHex: "#4CAF63", isDone: false, isStudy: true,
                     planID: "preview-3", dayKey: key, start: at(0, 21), end: at(0, 22), isAllDay: false),
            PlanItem(title: "스터디 모임", time: "오후 6:00", colorHex: "#F59E0B", isDone: false, isStudy: false,
                     planID: "preview-4", dayKey: WidgetMath.dayKey(at(1, 0)), start: at(1, 18), end: at(1, 20), isAllDay: false)
        ]
        snapshot.dDayTitle = "기말고사"
        snapshot.dDayDate = calendar.date(byAdding: .day, value: 12, to: today)
        snapshot.words = [WordItem(term: "abundant", meaning: "풍부한"), WordItem(term: "resilient", meaning: "회복력 있는")]
        snapshot.wordsLeft = 18
        snapshot.studyMinutes = 95
        snapshot.streak = 6
        snapshot.bestStreak = 12

        // 달력: 지난날은 공부 시간이 들쭉날쭉, 오늘까지 6일 연속
        let pattern = [0, 40, 75, 130, 200, 20, 95, 160, 0, 60, 185, 110, 45, 0]
        let colors = ["#3D9BE0", "#7B68EE", "#4CAF63", "#F59E0B"]
        let week = Set(WidgetMath.week(containing: now, calendar: calendar).map { WidgetMath.dayKey($0) })
        snapshot.days = WidgetMath.monthGrid(for: now, calendar: calendar).map { day in
            let k = WidgetMath.dayKey(day)
            let offset = WidgetMath.daysBetween(today, day, calendar: calendar)
            var minutes = 0
            if offset == 0 { minutes = 95 }
            else if offset < 0 && offset >= -5 { minutes = [120, 60, 185, 45, 150][(-offset - 1) % 5] }
            else if offset < -6 { minutes = pattern[(-offset) % pattern.count] }
            let n = abs(offset * 7 + 3) % 4
            let dayColors = Array(colors.prefix(n == 3 ? 3 : n))
            var items: [PlanItem]?
            if week.contains(k) {
                items = dayColors.enumerated().map { i, hex in
                    PlanItem(title: ["수학 오답", "영어 단어", "국어 문학"][i], time: ["오후 4:00", "오후 7:00", "오후 9:00"][i],
                             colorHex: hex, isDone: offset < 0, isStudy: true)
                }
                if offset == 0 { items = snapshot.plans }
            }
            return DayStat(key: k, minutes: minutes, planCount: offset == 0 ? 3 : dayColors.count,
                           doneCount: offset < 0 ? dayColors.count : (offset == 0 ? 1 : 0),
                           colors: offset == 0 ? ["#3D9BE0", "#7B68EE", "#4CAF63"] : dayColors, items: items)
        }
        return snapshot
    }
}
