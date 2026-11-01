import Foundation
import SwiftData
import UserNotifications

/// 주간 AI 리포트: 지난 7일 공부 기록을 정리하고 다음 주 계획을 추천
struct WeeklyReport {
    struct Subject: Identifiable {
        let name: String
        let minutes: Int
        let previousMinutes: Int
        var id: String { name }
    }

    struct UnitScore: Identifiable {
        let subject: String
        let unit: String
        let correct: Int
        let total: Int
        var rate: Double { total == 0 ? 0 : Double(correct) / Double(total) }
        var id: String { subject + "/" + unit }
    }

    struct Suggestion: Identifiable {
        let dayText: String      // "다음 주 월요일"
        let timeText: String     // "오후 7시"
        let title: String
        let minutes: Int
        var id: String { dayText + title }
    }

    let start: Date
    let end: Date
    let totalMinutes: Int
    let previousMinutes: Int
    let dailyMinutes: [(day: Date, minutes: Int)]
    let studyDays: Int
    let goalDays: Int
    let goalMinutes: Int
    let streak: Int
    let subjects: [Subject]
    let planDone: Int
    let planTotal: Int
    let quizCorrect: Int
    let quizTotal: Int
    let weakUnits: [UnitScore]
    let strongUnits: [UnitScore]
    let wordsAdded: Int
    let wordsLearned: Int
    let hardWords: [String]
    let notesAdded: Int
    let notesWrong: Int
    let notesCorrect: Int
    let favoriteHour: Int
    let highlights: [String]
    let advice: [String]
    let nextWeek: [Suggestion]

    var change: Double? {
        previousMinutes == 0 ? nil : Double(totalMinutes - previousMinutes) / Double(previousMinutes)
    }
    var quizRate: Double? { quizTotal == 0 ? nil : Double(quizCorrect) / Double(quizTotal) }
    var planRate: Double? { planTotal == 0 ? nil : Double(planDone) / Double(planTotal) }

    static func duration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)분" }
        return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
    }

    /// 두잇 AI 채팅에 보여줄 짧은 글
    var summaryText: String {
        var lines = ["**이번 주 공부 리포트** (\(start.kr("M/d"))~\(end.kr("M/d")))"]
        var timeLine = "• 공부 시간 \(Self.duration(totalMinutes))"
        if let change { timeLine += " (지난주보다 \(change >= 0 ? "+" : "")\(Int((change * 100).rounded()))%)" }
        lines.append(timeLine)
        lines.append("• 공부한 날 \(studyDays)일, 목표 달성 \(goalDays)일, 연속 \(streak)일")
        if let top = subjects.first { lines.append("• 가장 많이 한 과목: \(top.name) \(Self.duration(top.minutes))") }
        if let rate = planRate { lines.append("• 플랜 완료 \(planDone)/\(planTotal) (\(Int((rate * 100).rounded()))%)") }
        if let rate = quizRate { lines.append("• 문제 정답률 \(Int((rate * 100).rounded()))% (\(quizCorrect)/\(quizTotal))") }
        if let weak = weakUnits.first { lines.append("• 보완할 단원: \(weak.subject) \(weak.unit) (\(Int((weak.rate * 100).rounded()))%)") }
        if wordsAdded + wordsLearned > 0 { lines.append("• 단어 \(wordsAdded)개 추가, \(wordsLearned)개 외움") }
        if notesAdded > 0 { lines.append("• 오답노트 \(notesAdded)문제 추가") }
        if !advice.isEmpty { lines.append("\n**다음 주에는**\n" + advice.prefix(3).map { "• " + $0 }.joined(separator: "\n")) }
        return lines.joined(separator: "\n")
    }
}

@MainActor
enum WeeklyReportBuilder {
    static func build(context: ModelContext, now: Date = Date()) -> WeeklyReport {
        let calendar = Calendar.current
        let end = now.startOfDay
        let start = end.adding(days: -6)
        let previousStart = start.adding(days: -7)
        let afterEnd = end.adding(days: 1)

        let sessions = (try? context.fetch(FetchDescriptor<StudySession>())) ?? []
        let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        let records = (try? context.fetch(FetchDescriptor<QuizRecord>())) ?? []
        let words = (try? context.fetch(FetchDescriptor<Word>())) ?? []
        let notes = (try? context.fetch(FetchDescriptor<MathNote>())) ?? []
        let goal = UserDefaults.standard.object(forKey: SettingsKey.dailyStudyGoalMinutes) as? Int ?? 180

        let week = sessions.filter { $0.start >= start && $0.start < afterEnd }
        let lastWeek = sessions.filter { $0.start >= previousStart && $0.start < start }
        let total = week.reduce(0) { $0 + $1.seconds } / 60
        let previous = lastWeek.reduce(0) { $0 + $1.seconds } / 60

        // 날마다
        var daily: [(day: Date, minutes: Int)] = []
        for offset in 0..<7 {
            let day = start.adding(days: offset)
            let minutes = week.filter { $0.start.isSameDay(as: day) }.reduce(0) { $0 + $1.seconds } / 60
            daily.append((day, minutes))
        }
        let studyDays = daily.filter { $0.minutes > 0 }.count
        let goalDays = daily.filter { $0.minutes >= goal }.count

        // 연속 공부한 날 (오늘 또는 어제부터 거꾸로)
        var streak = 0
        var cursor = end
        if !sessions.contains(where: { $0.start.isSameDay(as: cursor) }) { cursor = cursor.adding(days: -1) }
        while sessions.contains(where: { $0.start.isSameDay(as: cursor) }) && streak < 366 {
            streak += 1
            cursor = cursor.adding(days: -1)
        }

        // 과목별
        func name(_ s: StudySession) -> String { s.categoryName.isEmpty ? (s.title.isEmpty ? "기타" : s.title) : s.categoryName }
        let now7 = Dictionary(grouping: week, by: name).mapValues { $0.reduce(0) { $0 + $1.seconds } / 60 }
        let prev7 = Dictionary(grouping: lastWeek, by: name).mapValues { $0.reduce(0) { $0 + $1.seconds } / 60 }
        let subjects = now7.map { WeeklyReport.Subject(name: $0.key, minutes: $0.value, previousMinutes: prev7[$0.key] ?? 0) }
            .sorted { $0.minutes > $1.minutes }

        // 플랜 완료율
        var planDone = 0, planTotal = 0
        for offset in 0..<7 {
            let occurrences = plans.occurrences(on: start.adding(days: offset))
            planTotal += occurrences.count
            planDone += occurrences.filter(\.isCompleted).count
        }

        // 문제 풀이 기록 (AI 학습 퀴즈)
        let weekRecords = records.filter { $0.date >= start && $0.date < afterEnd }
        let quizCorrect = weekRecords.reduce(0) { $0 + $1.correct }
        let quizTotal = weekRecords.reduce(0) { $0 + $1.total }
        // 단원 점수는 최근 4주까지 봐서 약한 단원을 찾음
        let recent = records.filter { $0.date >= end.adding(days: -27) }
        let units = Dictionary(grouping: recent, by: { $0.subject + "|" + $0.unit }).compactMap { _, list -> WeeklyReport.UnitScore? in
            guard let first = list.first else { return nil }
            return WeeklyReport.UnitScore(subject: first.subject, unit: first.unit,
                                          correct: list.reduce(0) { $0 + $1.correct }, total: list.reduce(0) { $0 + $1.total })
        }
        let weak = units.filter { $0.total >= 3 && $0.rate < 0.7 }.sorted { $0.rate < $1.rate }
        let strong = units.filter { $0.total >= 3 && $0.rate >= 0.85 }.sorted { $0.rate > $1.rate }

        // 단어 · 오답노트
        let wordsAdded = words.filter { $0.createdAt >= start && $0.createdAt < afterEnd }.count
        let wordsLearned = words.filter { ($0.learnedAt ?? .distantPast) >= start }.count
        let hardWords = words.filter { $0.wrongCount > 0 && !$0.isLearned }.sorted { $0.wrongCount > $1.wrongCount }.prefix(5).map(\.term)
        let weekNotes = notes.filter { $0.createdAt >= start && $0.createdAt < afterEnd }
        let notesWrongAll = notes.filter { $0.status == .wrong }.count

        // 주로 공부하는 시간대 (없으면 저녁 7시)
        let hours = sessions.filter { $0.start >= end.adding(days: -27) }.map { calendar.component(.hour, from: $0.start) }
        let favoriteHour = Dictionary(grouping: hours, by: { $0 }).max { $0.value.count < $1.value.count }?.key ?? 19

        // 잘한 점
        var highlights: [String] = []
        if previous > 0, total > previous { highlights.append("지난주보다 \(WeeklyReport.duration(total - previous)) 더 공부했어요") }
        if streak >= 3 { highlights.append("\(streak)일 연속으로 공부하고 있어요") }
        if goalDays >= 3 { highlights.append("하루 목표를 \(goalDays)일이나 달성했어요") }
        if let best = strong.first { highlights.append("\(best.unit) 정답률 \(Int((best.rate * 100).rounded()))%로 탄탄해요") }
        if planTotal > 0, Double(planDone) / Double(planTotal) >= 0.8 { highlights.append("플랜을 \(Int(Double(planDone) / Double(planTotal) * 100))% 지켰어요") }
        if wordsLearned >= 20 { highlights.append("단어를 \(wordsLearned)개 외웠어요") }
        if highlights.isEmpty && total > 0 { highlights.append("이번 주에 \(WeeklyReport.duration(total)) 공부했어요. 시작이 반이에요!") }

        // 다음 주 조언
        var advice: [String] = []
        if studyDays < 5 { advice.append("공부한 날이 \(studyDays)일이에요. 짧게라도 매일 하는 습관을 만들어 봐요 (하루 30분부터).") }
        if goalDays == 0 && total > 0 {
            let average = total / max(studyDays, 1)
            advice.append("하루 평균 \(WeeklyReport.duration(average))로 목표(\(WeeklyReport.duration(goal)))보다 적어요. 목표를 조금 낮추거나 공부 플랜에 시간을 정해 두세요.")
        }
        for unit in weak.prefix(2) {
            advice.append("\(unit.subject) '\(unit.unit)' 정답률이 \(Int((unit.rate * 100).rounded()))%예요. AI 학습에서 개념부터 다시 보고 문제를 풀어봐요.")
        }
        if let rate = planTotal > 0 ? Double(planDone) / Double(planTotal) : nil, rate < 0.6 {
            advice.append("플랜 완료율이 \(Int(rate * 100))%예요. 계획을 80% 정도만 채우고 작게 쪼개 보세요.")
        }
        if notesWrongAll > 0 { advice.append("아직 '오답'인 문제가 \(notesWrongAll)개 있어요. 하루 2문제씩 다시 풀어봐요.") }
        if !hardWords.isEmpty { advice.append("자주 틀린 단어(\(hardWords.prefix(3).joined(separator: ", ")))를 퀴즈로 복습해요.") }
        if let lowest = subjects.last, subjects.count >= 2, lowest.minutes < (subjects.first?.minutes ?? 0) / 4 {
            advice.append("\(lowest.name) 공부 시간이 적어요. 다음 주에 한두 번 더 넣어봐요.")
        }
        if total == 0 { advice.append("이번 주 기록이 없어요. 타이머로 공부하면 시간이 자동으로 기록돼요.") }

        // 다음 주 추천 플랜: 약한 단원·적게 한 과목을 월·수·금에
        var targets: [(String, Int)] = weak.prefix(2).map { ("\($0.subject) \($0.unit) 복습", 50) }
        if notesWrongAll > 0 { targets.append(("오답노트 다시 풀기", 30)) }
        if !hardWords.isEmpty { targets.append(("틀린 단어 복습", 20)) }
        if let lowest = subjects.last, subjects.count >= 2 { targets.append(("\(lowest.name) 공부", 60)) }
        if targets.isEmpty { targets = [("수학 문제 풀이", 60), ("영어 단어", 30), ("오늘 배운 내용 복습", 40)] }
        let days = ["월요일", "수요일", "금요일", "화요일", "목요일"]
        let hour = max(6, min(favoriteHour, 22))
        let timeText = hour < 12 ? "오전 \(hour)시" : "오후 \(hour == 12 ? 12 : hour - 12)시"
        let nextWeek = targets.prefix(4).enumerated().map { index, target in
            WeeklyReport.Suggestion(dayText: "다음 주 " + days[index % days.count], timeText: timeText, title: target.0, minutes: target.1)
        }

        return WeeklyReport(start: start, end: end, totalMinutes: total, previousMinutes: previous, dailyMinutes: daily,
                            studyDays: studyDays, goalDays: goalDays, goalMinutes: goal, streak: streak, subjects: subjects,
                            planDone: planDone, planTotal: planTotal, quizCorrect: quizCorrect, quizTotal: quizTotal,
                            weakUnits: Array(weak.prefix(5)), strongUnits: Array(strong.prefix(3)),
                            wordsAdded: wordsAdded, wordsLearned: wordsLearned, hardWords: Array(hardWords),
                            notesAdded: weekNotes.count, notesWrong: notesWrongAll, notesCorrect: notes.filter { $0.status == .correct }.count,
                            favoriteHour: favoriteHour, highlights: highlights, advice: advice, nextWeek: Array(nextWeek))
    }

    /// 매주 일요일 저녁 8시 리포트 알림 (일정 알림을 다시 예약할 때 같이)
    nonisolated static func scheduleNotification() {
        guard AppSettings.notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "이번 주 공부 리포트가 준비됐어요"
        content.body = "한 주 동안 얼마나 공부했는지, 다음 주엔 무엇을 하면 좋을지 확인해 보세요."
        content.sound = .default
        content.userInfo = ["weeklyReport": true]
        var components = DateComponents()
        components.weekday = 1
        components.hour = 20
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "weekly.report", content: content, trigger: trigger))
    }
}
