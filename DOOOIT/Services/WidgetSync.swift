import SwiftData
import SwiftUI
import WidgetKit

/// 앱 데이터로 홈 화면 위젯용 요약을 만들어 App Group에 저장하고 위젯을 새로 그림
@MainActor
enum WidgetSync {
    /// 지금 고른 강조색 (위젯 · 애플 워치)
    static var accentHex: String {
        switch UserDefaults.standard.string(forKey: SettingsKey.themeColor) ?? "" {
        case ThemeColor.sky.rawValue: return "#3D9BE0"
        case ThemeColor.mint.rawValue: return "#4CAF63"
        default: return "#7B68EE"
        }
    }

    static func update(context: ModelContext) {
        // 위젯에서 누른 완료 체크를 먼저 저장 (위젯 확장은 앱 저장소를 못 열어서 적어만 둠)
        WidgetActions.applyPending(context: context)
        makeSnapshot(context: context).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 위젯 하나에 들어갈 일정 모양
    private static func item(_ occurrence: PlanOccurrence, themeHex: String) -> WidgetSnapshot.PlanItem {
        WidgetSnapshot.PlanItem(
            title: occurrence.plan.title,
            time: occurrence.plan.isAllDay ? "종일" : occurrence.start.kr("a h:mm"),
            colorHex: occurrence.plan.category?.colorHex ?? themeHex,
            isDone: occurrence.isCompleted,
            isStudy: occurrence.plan.isStudy,
            planID: occurrence.plan.id.uuidString,
            dayKey: occurrence.day.dayKey,
            start: occurrence.start,
            end: occurrence.end,
            isAllDay: occurrence.plan.isAllDay
        )
    }

    static func makeSnapshot(context: ModelContext, now: Date = Date()) -> WidgetSnapshot {
        let defaults = UserDefaults.standard
        var snapshot = WidgetSnapshot()
        snapshot.updatedAt = now
        snapshot.dayKey = now.dayKey

        let themeHex = accentHex
        snapshot.accentHex = themeHex

        let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        snapshot.plans = plans.occurrences(on: now).map { item($0, themeHex: themeHex) }

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
        let running = StudyTimer.shared.isActive ? Int(StudyTimer.shared.elapsed(at: now)) : 0
        var secondsByDay: [String: Int] = [:]
        for session in sessions {
            secondsByDay[session.start.dayKey, default: 0] += session.seconds
        }
        let saved = secondsByDay[now.dayKey] ?? 0
        snapshot.studyMinutes = (saved + running) / 60
        snapshot.goalMinutes = defaults.object(forKey: SettingsKey.dailyStudyGoalMinutes) as? Int ?? 180

        // 연속 공부: 홈 화면과 같은 규칙 (1분 넘은 기록이 있는 날) · 최고 기록은 배지와 같은 규칙
        let studiedDays = Set(sessions.filter { $0.seconds >= 60 }.map { $0.start.dayKey })
        snapshot.streak = WidgetMath.currentStreak(studiedKeys: studiedDays, today: now)
        var byDay: [Date: Int] = [:]
        for session in sessions { byDay[session.start.startOfDay, default: 0] += session.seconds }
        snapshot.bestStreak = max(snapshot.streak, BadgeBook.bestStreak(days: byDay.filter { $0.value >= 60 }.map(\.key)))

        // 이번 달 달력 칸: 공부 시간 · 일정 수 · 색 (이번 주는 일정 이름까지)
        let week = Set(WidgetMath.week(containing: now).map(\.dayKey))
        snapshot.days = WidgetMath.monthGrid(for: now).map { day in
            let key = day.dayKey
            let occurrences = plans.occurrences(on: day)
            var seconds = secondsByDay[key] ?? 0
            if key == now.dayKey { seconds += running }
            var colors: [String] = []
            for occurrence in occurrences {
                let hex = occurrence.plan.category?.colorHex ?? themeHex
                if !colors.contains(hex) { colors.append(hex) }
                if colors.count == 3 { break }
            }
            return WidgetSnapshot.DayStat(
                key: key,
                minutes: seconds / 60,
                planCount: occurrences.count,
                doneCount: occurrences.filter(\.isCompleted).count,
                colors: colors,
                items: week.contains(key) ? occurrences.prefix(4).map { item($0, themeHex: themeHex) } : nil
            )
        }

        // 다음 일정: 앞으로 7일 안 시간 있는 일정 중 아직 안 끝난 것
        var upcoming: [WidgetSnapshot.PlanItem] = []
        for offset in 0..<7 where upcoming.count < 6 {
            let day = now.startOfDay.adding(days: offset)
            for occurrence in plans.occurrences(on: day)
            where !occurrence.plan.isAllDay && !occurrence.isCompleted && occurrence.end > now && upcoming.count < 6 {
                upcoming.append(item(occurrence, themeHex: themeHex))
            }
        }
        snapshot.upcoming = upcoming
        return snapshot
    }
}
