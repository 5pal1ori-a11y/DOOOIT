import Foundation

// 시험 D-day 자동 계획 (ExamPlanner): 과목 비율 · 쉬는 요일 · 짧은 기간 · 시험 당일/지난 시험 · 개수 제한 · 같은 결과 · 하루 한도 · 마지막 복습

private func examCalendar(_ zone: String = "Asia/Seoul") -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: zone)!
    return cal
}

private func examDay(_ cal: Calendar, _ y: Int, _ m: Int, _ d: Int, hour: Int = 0, minute: Int = 0) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
}

private func subjects(_ names: [String]) -> [ExamPlanner.Subject] { names.map { ExamPlanner.Subject(name: $0) } }

@MainActor
func runExamPlannerCases() async {
    let cal = examCalendar()
    // 2026-11-02 (월) 부터 2026-11-23 (월) 시험 → 21일
    let start = examDay(cal, 2026, 11, 2)
    let exam = examDay(cal, 2026, 11, 23)
    func make(_ list: [ExamPlanner.Subject], daily: Int = 180, startMinute: Int = 18 * 60, off: Set<Int> = [], review: Bool = true,
              today: Date? = nil, examDate: Date? = nil, calendar: Calendar? = nil) -> ExamPlanner.Result {
        ExamPlanner.plan(ExamPlanner.Input(today: today ?? start, examDate: examDate ?? exam, subjects: list, dailyMinutes: daily,
                                           startMinuteOfDay: startMinute, offWeekdays: off, reviewTail: review, calendar: calendar ?? cal))
    }
    func perDay(_ items: [ExamPlanner.Item]) -> [Date: [ExamPlanner.Item]] { Dictionary(grouping: items, by: \.date) }
    func minutesBySubject(_ items: [ExamPlanner.Item]) -> [String: Int] {
        Dictionary(grouping: items, by: \.subject).mapValues { $0.reduce(0) { $0 + $1.minutes } }
    }

    // 1) 기본: 21일, 3과목, 하루 3시간
    let base = make(subjects(["국어", "영어", "수학"]))
    check("시험계획: 기본 결과가 있음", !base.items.isEmpty && base.emptyReason == nil)
    check("시험계획: 시험 당일은 넣지 않음", base.items.allSatisfy { $0.date < exam }, "마지막 \(String(describing: base.items.last?.date))")
    check("시험계획: 첫 날은 오늘", base.items.first?.date == cal.startOfDay(for: start))
    check("시험계획: 21일 모두 사용", Set(base.items.map(\.date)).count == 21, "\(Set(base.items.map(\.date)).count)일")
    check("시험계획: 블록은 25~90분", base.items.allSatisfy { $0.minutes >= 25 && $0.minutes <= 90 }, "\(base.items.map(\.minutes).min() ?? 0)~\(base.items.map(\.minutes).max() ?? 0)")
    check("시험계획: 개수 제한 이내", base.items.count <= ExamPlanner.maxItems)
    check("시험계획: 아이디가 겹치지 않음", Set(base.items.map(\.id)).count == base.items.count)

    // 2) 하루 한도를 넘지 않음 (여러 설정)
    for daily in [25, 30, 55, 90, 100, 150, 180, 240, 300, 480, 720] {
        for startMinute in [0, 9 * 60, 18 * 60, 22 * 60, 23 * 60 + 30] {
            let r = make(subjects(["국어", "영어", "수학", "과학", "사회"]), daily: daily, startMinute: startMinute)
            let days = perDay(r.items)
            let over = days.values.contains { $0.reduce(0) { $0 + $1.minutes } > daily }
            let past = r.items.contains { $0.endMinuteOfDay > 1440 }
            let overlap = days.values.contains { day in
                let sorted = day.sorted { $0.startMinuteOfDay < $1.startMinuteOfDay }
                return zip(sorted, sorted.dropFirst()).contains { $0.endMinuteOfDay > $1.startMinuteOfDay }
            }
            check("시험계획: 하루 \(daily)분 · 시작 \(startMinute)분 → 한도·자정·겹침 문제 없음", !r.items.isEmpty && !over && !past && !overlap, "over=\(over) past=\(past) overlap=\(overlap)")
        }
    }
    let full = make(subjects(["국어", "영어", "수학"]), daily: 180)
    check("시험계획: 하루 180분을 다 채움", perDay(full.items).values.allSatisfy { $0.reduce(0) { $0 + $1.minutes } == 180 })

    // 3) 비율: 수학이 중요 + 범위 큼 → 가장 많이, 같은 비율이면 비슷하게
    let equal = make(subjects(["국어", "영어", "수학"]), review: false)
    var counts = minutesBySubject(equal.items)
    let spread = (counts.values.max() ?? 0) - (counts.values.min() ?? 0)
    check("시험계획: 같은 비율이면 과목 시간이 비슷함", spread <= 120, "\(counts)")
    let weighted = make([
        ExamPlanner.Subject(name: "국어"), ExamPlanner.Subject(name: "영어"),
        ExamPlanner.Subject(name: "수학", size: 12, important: true)
    ], review: false)
    counts = minutesBySubject(weighted.items)
    check("시험계획: 중요 과목 + 큰 범위가 가장 많음", (counts["수학"] ?? 0) > (counts["국어"] ?? 0) && (counts["수학"] ?? 0) > (counts["영어"] ?? 0), "\(counts)")
    let ratio = Double(counts["수학"] ?? 0) / Double(max(1, counts["국어"] ?? 1))
    check("시험계획: 중요 과목 비율이 1.2~3배", ratio > 1.2 && ratio < 3, "\(ratio)")
    let weakOne = make([ExamPlanner.Subject(name: "국어"), ExamPlanner.Subject(name: "수학", weak: true)], review: false)
    counts = minutesBySubject(weakOne.items)
    check("시험계획: 취약 과목은 조금 더 (너무 많지는 않게)", (counts["수학"] ?? 0) >= (counts["국어"] ?? 0) && (counts["수학"] ?? 0) <= Int(Double(counts["국어"] ?? 1) * 1.5), "\(counts)")
    check("시험계획: 과목마다 한 번 이상", Set(weighted.items.map(\.subject)) == ["국어", "영어", "수학"])

    // 4) 과목이 번갈아 나옴: 하루 마지막 과목이 늘 같지 않고, 같은 과목이 연달아 오지 않음
    let lastSubjects = Set(perDay(equal.items).values.compactMap { $0.sorted { $0.startMinuteOfDay < $1.startMinuteOfDay }.last?.subject })
    check("시험계획: 하루의 마지막 과목이 돌아가며 바뀜", lastSubjects.count >= 2, "\(lastSubjects)")
    let repeats = perDay(equal.items).values.reduce(0) { total, day in
        let sorted = day.sorted { $0.startMinuteOfDay < $1.startMinuteOfDay }
        return total + zip(sorted, sorted.dropFirst()).filter { $0.subject == $1.subject }.count
    }
    check("시험계획: 같은 과목이 연달아 거의 안 나옴", repeats <= 2, "\(repeats)번")

    // 5) 이름: "수학 1/6 범위" 모양, 번호가 차례대로
    let math = equal.items.filter { $0.subject == "수학" }.sorted { ($0.date, $0.startMinuteOfDay) < ($1.date, $1.startMinuteOfDay) }
    check("시험계획: 이름 모양", math.first?.label == "수학 1/\(math.count) 범위", "\(math.first?.label ?? "-")")
    check("시험계획: 번호가 차례대로", math.enumerated().allSatisfy { $0.element.part == $0.offset + 1 && $0.element.parts == math.count })

    // 6) 쉬는 요일: 일요일(1) · 토요일(7) 쉬기
    let off = make(subjects(["국어", "영어", "수학"]), off: [1, 7])
    check("시험계획: 쉬는 요일에는 없음", off.items.allSatisfy { ![1, 7].contains(cal.component(.weekday, from: $0.date)) })
    check("시험계획: 쉬는 요일 빼고 날짜 수", Set(off.items.map(\.date)).count == 15, "\(Set(off.items.map(\.date)).count)일")
    let allOff = make(subjects(["국어"]), off: Set(1...7))
    check("시험계획: 전부 쉬는 날이어도 계획은 만들고 알려 줌", !allOff.items.isEmpty && allOff.ignoredOffDays)

    // 7) 짧은 기간
    for days in 1...4 {
        let examDate = start.addingTimeInterval(TimeInterval(86_400 * days))
        let r = make(subjects(["국어", "영어", "수학"]), examDate: examDate)
        let covered = Set(r.items.map(\.subject))
        check("시험계획: \(days)일 남아도 모든 과목을 다룸", !r.items.isEmpty && covered == ["국어", "영어", "수학"], "\(covered) \(r.droppedSubjects)")
        check("시험계획: \(days)일 남아도 하루 한도 이내", perDay(r.items).values.allSatisfy { $0.reduce(0) { $0 + $1.minutes } <= 180 })
        check("시험계획: \(days)일 남아도 시험 당일 없음", r.items.allSatisfy { $0.date < examDate })
    }
    let oneDayMany = make(subjects(["a", "b", "c", "d", "e", "f", "g", "h"]), daily: 60, examDate: start.addingTimeInterval(86_400))
    check("시험계획: 하루에 과목이 너무 많으면 일부만 넣고 알려 줌", !oneDayMany.items.isEmpty && !oneDayMany.droppedSubjects.isEmpty
          && Set(oneDayMany.items.map(\.subject)).count + oneDayMany.droppedSubjects.count == 8, "\(oneDayMany.droppedSubjects)")

    // 8) 시험 당일 · 지난 시험 · 과목 없음
    let today = make(subjects(["수학"]), examDate: start)
    check("시험계획: 시험이 오늘이면 비어 있고 이유 있음", today.items.isEmpty && today.emptyReason == .examToday && !today.emptyReason!.text.isEmpty)
    let todayLater = make(subjects(["수학"]), today: examDay(cal, 2026, 11, 2, hour: 15), examDate: examDay(cal, 2026, 11, 2, hour: 9))
    check("시험계획: 같은 날이면 시각이 달라도 오늘", todayLater.emptyReason == .examToday)
    let past = make(subjects(["수학"]), examDate: examDay(cal, 2026, 10, 30))
    check("시험계획: 지난 시험이면 비어 있고 이유 있음", past.items.isEmpty && past.emptyReason == .examPassed)
    let none = make([])
    check("시험계획: 과목이 없으면 비어 있음", none.items.isEmpty && none.emptyReason == .noSubjects)
    let blank = make(subjects(["  ", ""]))
    check("시험계획: 이름이 빈 과목은 무시", blank.emptyReason == .noSubjects)
    let dup = make(subjects(["수학", " 수학 ", "국어"]))
    check("시험계획: 같은 이름 과목은 하나로", Set(dup.items.map(\.subject)) == ["수학", "국어"])
    let tomorrow = make(subjects(["수학"]), examDate: start.addingTimeInterval(86_400))
    check("시험계획: 내일이 시험이면 오늘만", Set(tomorrow.items.map(\.date)).count == 1)

    // 9) 오늘 계획은 지금 이후부터
    let late = make(subjects(["국어", "영어"]), daily: 120, startMinute: 9 * 60, today: examDay(cal, 2026, 11, 2, hour: 20, minute: 3))
    let todayItems = late.items.filter { $0.date == cal.startOfDay(for: start) }
    check("시험계획: 오늘 계획은 지금보다 뒤에 시작", todayItems.allSatisfy { $0.startMinuteOfDay >= 20 * 60 + 10 }, "\(todayItems.map(\.startMinuteOfDay))")
    let tooLate = make(subjects(["국어"]), today: examDay(cal, 2026, 11, 2, hour: 23, minute: 50))
    check("시험계획: 너무 늦은 오늘은 건너뜀", tooLate.items.allSatisfy { $0.date > cal.startOfDay(for: start) } && !tooLate.items.isEmpty)

    // 10) 개수 제한
    let long = make(subjects(["국어", "영어", "수학", "과학", "사회"]), daily: 480, startMinute: 6 * 60, examDate: examDay(cal, 2027, 6, 1))
    check("시험계획: 아주 긴 기간도 250개 이내", long.items.count <= 250 && long.trimmedEarlyDays && !long.items.isEmpty, "\(long.items.count)개 \(long.trimmedEarlyDays)")
    check("시험계획: 개수를 줄일 땐 먼 날을 뺌 (시험 가까운 날은 유지)", (long.items.map(\.date).max() ?? .distantPast) == cal.startOfDay(for: examDay(cal, 2027, 5, 31)))
    let farFuture = make(subjects(["수학"]), examDate: examDay(cal, 2036, 1, 1))
    check("시험계획: 10년 뒤 시험도 멈추지 않고 250개 이내", farFuture.items.count <= 250 && !farFuture.items.isEmpty)

    // 11) 같은 입력은 같은 결과
    let mixed = [ExamPlanner.Subject(name: "국어", size: 5), ExamPlanner.Subject(name: "영어", important: true), ExamPlanner.Subject(name: "수학", weak: true)]
    check("시험계획: 같은 입력은 같은 결과", make(mixed, off: [1]) == make(mixed, off: [1]))

    // 12) 마지막 이틀 복습
    let withReview = make(subjects(["국어", "영어", "수학"]))
    let dates = Array(Set(withReview.items.map(\.date))).sorted()
    let lastTwo = Set(dates.suffix(2))
    check("시험계획: 마지막 이틀은 전부 복습", withReview.items.filter { lastTwo.contains($0.date) }.allSatisfy(\.isReview))
    check("시험계획: 그 전에는 복습이 없음", withReview.items.filter { !lastTwo.contains($0.date) }.allSatisfy { !$0.isReview })
    check("시험계획: 복습 이름", withReview.items.last?.label.hasSuffix(" 복습") == true, "\(withReview.items.last?.label ?? "-")")
    check("시험계획: 복습에도 모든 과목이 나옴", Set(withReview.items.filter(\.isReview).map(\.subject)) == ["국어", "영어", "수학"])
    let noReview = make(subjects(["국어", "영어", "수학"]), review: false)
    check("시험계획: 복습을 끄면 복습이 없음", noReview.items.allSatisfy { !$0.isReview })
    let reviewShort = make(subjects(["국어", "영어", "수학"]), examDate: start.addingTimeInterval(86_400 * 4))
    check("시험계획: 4일이면 마지막 하루만 복습", Set(reviewShort.items.filter(\.isReview).map(\.date)).count == 1 && reviewShort.items.last?.isReview == true)
    let reviewTiny = make(subjects(["국어", "영어", "수학"]), examDate: start.addingTimeInterval(86_400 * 2))
    check("시험계획: 2일이면 복습은 마지막 날 뒷부분만", reviewTiny.items.contains { $0.isReview } && reviewTiny.items.contains { !$0.isReview })

    // 13) 시간대 · 서머타임 (2026-03-08 뉴욕 서머타임 시작)
    let ny = examCalendar("America/New_York")
    let nyExam = examDay(ny, 2026, 3, 12)
    let nyPlan = ExamPlanner.plan(ExamPlanner.Input(today: examDay(ny, 2026, 3, 5), examDate: nyExam, subjects: subjects(["수학", "영어"]), dailyMinutes: 120,
                                                    startMinuteOfDay: 19 * 60, offWeekdays: [], reviewTail: false, calendar: ny))
    let nyDays = Set(nyPlan.items.map(\.date)).sorted()
    check("시험계획: 서머타임 걸쳐도 날짜 7일", nyDays.count == 7, "\(nyDays.count)")
    check("시험계획: 서머타임 걸쳐도 매일 0시 기준", nyDays.allSatisfy { ny.startOfDay(for: $0) == $0 })
    check("시험계획: 서머타임 걸쳐도 시작 시각 그대로", nyPlan.items.allSatisfy { $0.startMinuteOfDay >= 19 * 60 })
    check("시험계획: 달력 시간대에 맞춰 시험 당일 제외", nyPlan.items.allSatisfy { $0.date < nyExam })

    // 14) 요약
    let sum = ExamPlanner.summarize(full.items)
    check("시험계획: 요약 숫자", sum.days == 21 && sum.totalMinutes == 21 * 180 && sum.averageMinutes == 180 && sum.count == full.items.count, "\(sum)")
    check("시험계획: 요약 글", ExamPlanner.summaryText(sum) == "하루 평균 180분 · 총 63시간", ExamPlanner.summaryText(sum))
    check("시험계획: 시간 글자", ExamPlanner.hoursText(minutes: 90) == "1.5" && ExamPlanner.hoursText(minutes: 120) == "2" && ExamPlanner.hoursText(minutes: 0) == "0")
    check("시험계획: 빈 요약", ExamPlanner.summarize([]) == ExamPlanner.Summary())

    // 15) 나눔 · 배분 도우미
    for total in stride(from: 25, through: 720, by: 5) {
        let n = ExamPlanner.blockCount(total)
        let parts = ExamPlanner.split(total, into: n)
        check("시험계획: \(total)분 나누기", parts.reduce(0, +) == total && parts.allSatisfy { $0 >= 25 && $0 <= 90 } && parts.count == n, "\(parts)")
    }
    check("시험계획: 배분 합계", ExamPlanner.allocate(total: 17, weights: [1, 2, 3.5]).reduce(0, +) == 17)
    check("시험계획: 배분은 0개 과목 없음", !ExamPlanner.allocate(total: 4, weights: [10, 1, 1]).contains(0), "\(ExamPlanner.allocate(total: 4, weights: [10, 1, 1]))")

    // 16) 표시 줄
    let id = UUID()
    let note = ExamPlanMarker.note(name: "기말고사", id: id)
    check("시험계획: 표시 줄 읽기", ExamPlanMarker.id(in: note) == id && ExamPlanMarker.name(in: note) == "기말고사", note)
    check("시험계획: 표시 줄 앞에 다른 메모가 있어도", ExamPlanMarker.id(in: "메모\n" + ExamPlanMarker.prefix + id.uuidString) == id)
    check("시험계획: 일반 메모는 해당 없음", ExamPlanMarker.id(in: "수학 3단원") == nil && ExamPlanMarker.id(in: "exam-plan:not-a-uuid") == nil && ExamPlanMarker.id(in: "") == nil)
    check("시험계획: 이름에 줄바꿈 있어도 한 줄", ExamPlanMarker.id(in: ExamPlanMarker.note(name: "중간\n고사", id: id)) == id)

    // 17) 채팅: 시험 계획 짜 달라고 하면 시험 계획 화면을 알려 줌 (자동으로 만들지 않음)
    for q in ["다음 달 15일 수학 시험 계획 짜줘", "시험 계획 짜줘", "내신 시험 대비 계획 짜줘"] {
        let assistant = DoitAssistant.shared
        assistant.reset()
        await assistant.send(q)
        let reply = assistant.messages.last?.text ?? ""
        check("시험계획 채팅: \(q)", reply.contains("시험 계획") && reply.contains("플래너") && !reply.contains("[ADD PLAN]"), reply.prefix(200).replacingOccurrences(of: "\n", with: " / "))
    }
}
