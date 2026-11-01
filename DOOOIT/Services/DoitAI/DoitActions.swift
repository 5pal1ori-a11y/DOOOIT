import SwiftData
import SwiftUI

/// 두잇 AI가 실제로 앱을 조작하는 부분 (플랜, 타이머, 단어, 메모, 목표, 통계, 화면 이동)
/// 도구(Tool)는 여기 함수를 부르고, 결과를 짧은 문장으로 AI에게 돌려줌
@MainActor
final class DoitActions {
    static let shared = DoitActions()

    var context: ModelContext?
    /// 이번 답변에서 실제로 한 일 (채팅에 체크 표시로 보여줌)
    private(set) var log: [String] = []

    func drainLog() -> [String] {
        defer { log = [] }
        return log
    }

    private func done(_ text: String) {
        log.append(text)
    }

    private func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context?.fetch(FetchDescriptor<T>())) ?? []
    }

    private func save() {
        try? context?.save()
        if let context { WidgetSync.update(context: context) }
    }

    // MARK: 하루 보기

    func overview(dateText: String?) -> String {
        guard let day = DoitDateParser.date(dateText) else { return "날짜를 이해하지 못했어요: \(dateText ?? "")" }
        let plans = fetch(Plan.self).occurrences(on: day)
        var lines = ["\(day.kr("M월 d일 EEEE"))"]
        if plans.isEmpty {
            lines.append("플랜 없음")
        } else {
            for occurrence in plans {
                let mark = occurrence.isCompleted ? "[완료]" : "[ ]"
                let kind = occurrence.plan.isStudy ? "공부" : "일반"
                lines.append("\(mark) \(occurrence.timeText) \(occurrence.plan.title) (\(kind))")
            }
        }
        if day.isSameDay(as: Date()) {
            let sessions = fetch(StudySession.self).filter { $0.start.isSameDay(as: day) }
            let seconds = sessions.reduce(0) { $0 + $1.seconds } + (StudyTimer.shared.isActive ? Int(StudyTimer.shared.elapsed()) : 0)
            let goal = UserDefaults.standard.object(forKey: SettingsKey.dailyStudyGoalMinutes) as? Int ?? 180
            lines.append("오늘 공부 \(TimeText.duration(seconds: seconds)) / 목표 \(TimeText.duration(minutes: goal))")
            if StudyTimer.shared.isActive { lines.append("타이머 진행 중: \(StudyTimer.shared.title)") }
            let unlearned = fetch(Word.self).filter { !$0.isLearned }.count
            lines.append("안 외운 단어 \(unlearned)개")
        }
        if let dDay = dDayText() { lines.append(dDay) }
        return lines.joined(separator: "\n")
    }

    // MARK: 플랜

    /// 그날 플랜 이름들
    func plans(on day: Date) -> [String] {
        fetch(Plan.self).occurrences(on: day).map(\.plan.title)
    }

    /// 공부 과목 이름들 (공부 플랜인지 판단할 때)
    func studyCategoryNames() -> [String] {
        fetch(PlanCategory.self).filter(\.isStudy).map(\.name).filter { !$0.isEmpty }
    }

    func addPlan(title: String, dateText: String?, timeText: String?, minutes: Int?, isStudy: Bool,
                 allDay: Bool, repeatText: String?) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "플랜 이름이 비어 있어요." }
        guard let day = DoitDateParser.date(dateText) else { return "날짜를 이해하지 못했어요: \(dateText ?? "")" }
        let time = DoitDateParser.time(timeText)
        let isAllDay = allDay || time == nil
        var start = day
        if let time, let date = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day) {
            start = date
        }
        let rule: RepeatRule
        switch (repeatText ?? "").lowercased() {
        case "daily", "매일": rule = .daily
        case "weekly", "매주": rule = .weekly
        case "monthly", "매달", "매월": rule = .monthly
        default: rule = .none
        }
        let categories = fetch(PlanCategory.self).sorted { $0.sortIndex < $1.sortIndex }
        let pool = categories.filter { $0.isStudy == isStudy }
        let category = pool.first { trimmed.contains($0.name) } ?? pool.first
        let plan = Plan(title: trimmed, startDate: start, durationMinutes: max(10, minutes ?? 60), isAllDay: isAllDay,
                        repeatRule: rule, category: category, kind: isStudy ? .study : .general)
        context?.insert(plan)
        save()
        PlanScheduler.shared.rescheduleNotifications()
        let when = isAllDay ? day.kr("M월 d일(E)") + " 종일" : start.kr("M월 d일(E) a h:mm")
        let repeatNote = rule == .none ? "" : " · \(rule.title)"
        done("플랜 추가 · \(when) \(trimmed)\(repeatNote)")
        return "추가 완료: \(when) \(trimmed) \(plan.durationMinutes)분\(repeatNote)"
    }

    func updatePlan(title: String, dateText: String?, action: String) -> String {
        guard let day = DoitDateParser.date(dateText) else { return "날짜를 이해하지 못했어요." }
        let occurrences = fetch(Plan.self).occurrences(on: day)
        let key = title.trimmingCharacters(in: .whitespaces)
        guard let target = occurrences.first(where: { $0.plan.title == key })
                ?? occurrences.first(where: { $0.plan.title.contains(key) || key.contains($0.plan.title) }) else {
            let names = occurrences.map(\.plan.title).joined(separator: ", ")
            return "\(day.kr("M월 d일")) '\(key)' 플랜을 찾지 못했어요. 그날 플랜: \(names.isEmpty ? "없음" : names)"
        }
        switch action {
        case "delete":
            let name = target.plan.title
            context?.delete(target.plan)
            save()
            PlanScheduler.shared.rescheduleNotifications()
            done("플랜 삭제 · \(name)")
            return "삭제 완료: \(name) (반복 플랜이면 전체가 삭제됨)"
        case "uncomplete":
            if target.isCompleted { target.plan.toggleCompleted(on: day) }
            save()
            done("완료 취소 · \(target.plan.title)")
            return "완료 취소: \(target.plan.title)"
        default:
            if !target.isCompleted { target.plan.toggleCompleted(on: day) }
            save()
            done("완료 체크 · \(target.plan.title)")
            return "완료 체크: \(target.plan.title)"
        }
    }

    // MARK: 타이머

    func timer(action: String, title: String?, minutes: Int?) -> String {
        let timer = StudyTimer.shared
        switch action {
        case "stop":
            guard timer.isActive else { return "진행 중인 타이머가 없어요." }
            let seconds = timer.stop()
            AmbientSoundPlayer.shared.stop()
            done("타이머 종료 · \(TimeText.duration(seconds: seconds)) 기록")
            return "타이머 종료, \(TimeText.duration(seconds: seconds)) 기록"
        case "pause":
            guard timer.isActive else { return "진행 중인 타이머가 없어요." }
            timer.togglePause()
            return timer.phase == .paused ? "일시정지했어요." : "다시 시작했어요."
        default:
            if timer.isActive { return "이미 '\(timer.title)' 타이머가 진행 중이에요." }
            let name = (title ?? "").trimmingCharacters(in: .whitespaces)
            let study = fetch(PlanCategory.self).filter(\.isStudy)
            let category = study.first { name.contains($0.name) } ?? study.first
            timer.start(title: name.isEmpty ? "자유 공부" : name, categoryName: category?.name ?? "공부",
                        symbol: category?.symbol ?? "book.fill", targetMinutes: minutes)
            done("타이머 시작 · \(name.isEmpty ? "자유 공부" : name)\(minutes.map { " \($0)분" } ?? "")")
            return "타이머 시작: \(name.isEmpty ? "자유 공부" : name)\(minutes.map { ", 목표 \($0)분" } ?? "")"
        }
    }

    // MARK: 단어

    func addWords(_ pairs: [(String, String)]) -> String {
        let existing = Set(fetch(Word.self).map { $0.term.lowercased() })
        var added: [String] = []
        for (term, meaning) in pairs {
            let t = term.trimmingCharacters(in: .whitespaces)
            let m = meaning.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty, !m.isEmpty, !existing.contains(t.lowercased()) else { continue }
            context?.insert(Word(term: t, meaning: m))
            added.append(t)
        }
        guard !added.isEmpty else { return "새로 추가할 단어가 없어요 (이미 있거나 비어 있음)." }
        save()
        done("단어 \(added.count)개 추가 · \(added.prefix(3).joined(separator: ", "))\(added.count > 3 ? " …" : "")")
        return "단어 \(added.count)개 추가: \(added.joined(separator: ", "))"
    }

    /// 내 단어장에서 단어 뜻 찾기
    func lookupWord(_ term: String) -> String {
        let key = term.lowercased()
        let words = fetch(Word.self)
        if let word = words.first(where: { $0.term.lowercased() == key }) {
            var text = "\(word.term): \(word.meaning)"
            if word.wrongCount > 0 { text += "\n(\(word.wrongCount)번 틀린 단어예요)" }
            return text
        }
        let similar = words.filter { $0.term.lowercased().hasPrefix(String(key.prefix(3))) }.prefix(3)
        if similar.isEmpty { return "'\(term)'은(는) 내 단어장에 없어요. \"단어 추가: \(term) 뜻\" 으로 넣을 수 있어요." }
        return "'\(term)'은(는) 단어장에 없어요. 비슷한 단어: " + similar.map { "\($0.term)(\($0.meaning))" }.joined(separator: ", ")
    }

    // MARK: 기록 보기

    func records(kind: String) -> String {
        switch kind {
        case "words":
            let words = fetch(Word.self)
            let learned = words.filter(\.isLearned).count
            let wrong = words.filter { $0.wrongCount > 0 }.sorted { $0.wrongCount > $1.wrongCount }
            var text = "단어 \(words.count)개, 외운 단어 \(learned)개, 틀린 단어 \(wrong.count)개"
            if !wrong.isEmpty {
                text += "\n자주 틀린 단어: " + wrong.prefix(8).map { "\($0.term)(\($0.meaning))" }.joined(separator: ", ")
            }
            return text
        case "notes":
            let notes = fetch(MathNote.self).sorted { $0.updatedAt > $1.updatedAt }
            let wrong = notes.filter { $0.status == .wrong }.count
            let unsolved = notes.filter { $0.status == .unsolved }.count
            var text = "오답노트 \(notes.count)문제 (오답 \(wrong), 미채점 \(unsolved))"
            if !notes.isEmpty {
                text += "\n최근: " + notes.prefix(6).map { "\($0.title)[\($0.status.title)]" }.joined(separator: ", ")
            }
            return text
        case "memos":
            let memos = fetch(Memo.self).sorted { $0.updatedAt > $1.updatedAt }
            if memos.isEmpty { return "메모 없음" }
            return "메모 \(memos.count)개\n" + memos.prefix(6).map { "- " + String($0.content.prefix(40)) }.joined(separator: "\n")
        default:
            return stats(days: 7)
        }
    }

    func stats(days: Int) -> String {
        let span = min(max(days, 1), 31)
        let from = Calendar.current.date(byAdding: .day, value: -(span - 1), to: Date().startOfDay) ?? Date()
        let sessions = fetch(StudySession.self).filter { $0.start >= from }
        let total = sessions.reduce(0) { $0 + $1.seconds }
        var byCategory: [String: Int] = [:]
        for session in sessions { byCategory[session.categoryName, default: 0] += session.seconds }
        let top = byCategory.sorted { $0.value > $1.value }.prefix(5)
            .map { "\($0.key) \(TimeText.duration(seconds: $0.value))" }.joined(separator: ", ")
        let studiedDays = Set(sessions.filter { $0.seconds >= 60 }.map { $0.start.dayKey }).count
        return "최근 \(span)일: 총 \(TimeText.duration(seconds: total)), 공부한 날 \(studiedDays)일, 하루 평균 \(TimeText.duration(seconds: total / span))\n과목별: \(top.isEmpty ? "기록 없음" : top)"
    }

    // MARK: 오답노트

    /// 채팅에 보낸 문제 사진을 오답노트로 저장 (글자는 AI가 사진을 보고 옮겨 적은 것)
    func addMathNote(title: String?, problem: String, answer: String?, image: UIImage?) -> String {
        let text = problem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || image != nil else { return "저장할 문제가 없어요." }
        let name = (title ?? "").trimmingCharacters(in: .whitespaces)
        let noteTitle = name.isEmpty ? (MathOCRFixer.title(from: text) ?? "두잇 AI 오답") : name
        let note = MathNote(
            title: noteTitle,
            imageData: image?.jpegForStorage(maxDimension: 2000),
            thumbnailData: image?.jpegForStorage(maxDimension: 400, quality: 0.6),
            recognizedText: text,
            correctAnswer: (answer ?? "").trimmingCharacters(in: .whitespaces)
        )
        note.problemImageData = image?.jpegForStorage(maxDimension: 2000, quality: 0.85)
        context?.insert(note)
        save()
        done("오답노트 저장 · \(noteTitle)")
        return "오답노트에 저장: \(noteTitle)"
    }

    // MARK: 메모

    func addMemo(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "메모 내용이 비어 있어요." }
        context?.insert(Memo(content: trimmed))
        save()
        done("메모 저장 · \(String(trimmed.prefix(20)))")
        return "메모 저장 완료"
    }

    func searchMemos(_ query: String) -> String {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let found = fetch(Memo.self).filter { $0.content.lowercased().contains(q) }
        if found.isEmpty { return "'\(query)'가 들어간 메모가 없어요." }
        return found.prefix(5).map { "- " + String($0.content.prefix(80)) }.joined(separator: "\n")
    }

    // MARK: 목표 · D-Day

    func settings(dDayTitle: String?, dDayDate: String?, studyGoalMinutes: Int?, wordGoal: Int?) -> String {
        let defaults = UserDefaults.standard
        var changes: [String] = []
        if let title = dDayTitle?.trimmingCharacters(in: .whitespaces), !title.isEmpty {
            guard let date = DoitDateParser.date(dDayDate) else { return "D-Day 날짜를 이해하지 못했어요." }
            defaults.set(title, forKey: SettingsKey.dDayTitle)
            defaults.set(date.timeIntervalSince1970, forKey: SettingsKey.dDayDate)
            changes.append("D-Day \(title) \(date.kr("yyyy년 M월 d일"))")
        }
        if let minutes = studyGoalMinutes, minutes > 0 {
            defaults.set(min(minutes, 900), forKey: SettingsKey.dailyStudyGoalMinutes)
            changes.append("하루 공부 목표 \(TimeText.duration(minutes: minutes))")
        }
        if let count = wordGoal, count > 0 {
            defaults.set(min(count, 200), forKey: SettingsKey.dailyWordGoal)
            changes.append("하루 단어 목표 \(count)개")
        }
        guard !changes.isEmpty else { return "바꿀 설정이 없어요." }
        if let context { WidgetSync.update(context: context) }
        changes.forEach { done("설정 · \($0)") }
        return "변경 완료: " + changes.joined(separator: ", ")
    }

    private func dDayText() -> String? {
        let defaults = UserDefaults.standard
        guard let title = defaults.string(forKey: SettingsKey.dDayTitle), !title.isEmpty else { return nil }
        let date = Date(timeIntervalSince1970: defaults.double(forKey: SettingsKey.dDayDate))
        let diff = Calendar.current.dateComponents([.day], from: Date().startOfDay, to: date.startOfDay).day ?? 0
        return "D-Day \(title): " + (diff > 0 ? "D-\(diff)" : (diff == 0 ? "D-DAY" : "D+\(-diff)"))
    }

    // MARK: 화면 이동

    func open(_ screen: String) -> String {
        let defaults = UserDefaults.standard
        switch screen {
        case "timer":
            StudyTimer.shared.isPresented = true
        case "planner":
            defaults.set(AppTab.planner.rawValue, forKey: "selectedTab")
        case "study", "words", "notes", "memo":
            defaults.set(AppTab.study.rawValue, forKey: "selectedTab")
        case "account", "settings":
            defaults.set(AppTab.account.rawValue, forKey: "selectedTab")
        default:
            defaults.set(AppTab.home.rawValue, forKey: "selectedTab")
        }
        done("화면 이동 · \(screen)")
        return "이동했어요."
    }
}

// MARK: - 대화·퀴즈용 정보

extension DoitActions {
    /// 일상 대화에 쓰는 오늘 상황 (공부 시간, 남은 플랜, D-Day)
    func chatContext() -> DoitChat.Context {
        let today = Date()
        let sessions = fetch(StudySession.self).filter { $0.start.isSameDay(as: today) }
        let seconds = sessions.reduce(0) { $0 + $1.seconds } + (StudyTimer.shared.isActive ? Int(StudyTimer.shared.elapsed()) : 0)
        let goal = UserDefaults.standard.object(forKey: SettingsKey.dailyStudyGoalMinutes) as? Int ?? 180
        let remaining = fetch(Plan.self).occurrences(on: today).filter { !$0.isCompleted }.count
        return DoitChat.Context(now: today, todayMinutes: seconds / 60, goalMinutes: goal, remainingPlans: remaining, dDay: dDayText())
    }

    /// 단어 퀴즈용: 틀린 단어와 안 외운 단어를 먼저
    func quizWords(_ count: Int) -> [(term: String, meaning: String)] {
        let words = fetch(Word.self).filter { !$0.term.isEmpty && !$0.meaning.isEmpty }
        let weighted = words.sorted { ($0.wrongCount, $0.isLearned ? 0 : 1) > ($1.wrongCount, $1.isLearned ? 0 : 1) }
        let pool = Array(weighted.prefix(max(count * 3, 12))).shuffled()
        return pool.prefix(count).map { ($0.term, $0.meaning) }
    }

    var wordCount: Int { fetch(Word.self).count }

    /// 내 단어장에 있는 뜻 (없으면 nil)
    func savedMeaning(of term: String) -> String? {
        let key = term.lowercased()
        return fetch(Word.self).first { $0.term.lowercased() == key }?.meaning
    }
}
