import SwiftData
import SwiftUI
import WidgetKit

/// 앱 데이터로 홈 화면 위젯용 요약을 만들어 App Group에 저장하고 위젯을 새로 그림
@MainActor
enum WidgetSync {
    static func update(context: ModelContext) {
        let now = Date()
        let defaults = UserDefaults.standard
        var snapshot = WidgetSnapshot()
        snapshot.dayKey = now.dayKey

        let themeHex: String
        switch defaults.string(forKey: SettingsKey.themeColor) ?? "" {
        case ThemeColor.sky.rawValue: themeHex = "#3D9BE0"
        case ThemeColor.mint.rawValue: themeHex = "#4CAF63"
        default: themeHex = "#7B68EE"
        }
        snapshot.accentHex = themeHex

        let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        snapshot.plans = plans.occurrences(on: now).map { occurrence in
            WidgetSnapshot.PlanItem(
                title: occurrence.plan.title,
                time: occurrence.plan.isAllDay ? "종일" : occurrence.start.kr("a h:mm"),
                colorHex: occurrence.plan.category?.colorHex ?? themeHex,
                isDone: occurrence.isCompleted,
                isStudy: occurrence.plan.isStudy
            )
        }

        let dDayTitle = defaults.string(forKey: SettingsKey.dDayTitle) ?? ""
        let dDayDate = defaults.double(forKey: SettingsKey.dDayDate)
        if !dDayTitle.isEmpty, dDayDate > 0 {
            snapshot.dDayTitle = dDayTitle
            snapshot.dDayDate = Date(timeIntervalSince1970: dDayDate)
        }

        let words = (try? context.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let unlearned = words.filter { !$0.isLearned }
        let wordGoal = defaults.object(forKey: SettingsKey.dailyWordGoal) as? Int ?? 20
        let doneToday = defaults.string(forKey: SettingsKey.wordGoalDoneKey) == now.dayKey
        snapshot.wordsLeft = doneToday ? 0 : min(wordGoal, unlearned.count)
        snapshot.words = unlearned.prefix(4).map { WidgetSnapshot.WordItem(term: $0.term, meaning: $0.meaning) }

        let sessions = (try? context.fetch(FetchDescriptor<StudySession>())) ?? []
        let saved = sessions.filter { $0.start.isSameDay(as: now) }.reduce(0) { $0 + $1.seconds }
        let running = StudyTimer.shared.isActive ? Int(StudyTimer.shared.elapsed(at: now)) : 0
        snapshot.studyMinutes = (saved + running) / 60
        snapshot.goalMinutes = defaults.object(forKey: SettingsKey.dailyStudyGoalMinutes) as? Int ?? 180

        let studiedDays = Set(sessions.filter { $0.seconds >= 60 }.map { $0.start.dayKey })
        var day = now.startOfDay
        if !studiedDays.contains(day.dayKey) { day = day.adding(days: -1) }
        var streak = 0
        while studiedDays.contains(day.dayKey) {
            streak += 1
            day = day.adding(days: -1)
        }
        snapshot.streak = streak

        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
