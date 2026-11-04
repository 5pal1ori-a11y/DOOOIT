import Foundation

// 홈 화면 위젯: 스냅샷 읽기(옛 모양 포함) · 달력 칸 · 연속 공부 · 위젯에서 누른 완료 체크

/// 옛 앱(위젯 4개 시절)이 저장하던 모양
private struct OldWidgetSnapshot: Codable {
    struct PlanItem: Codable { var title: String; var time: String; var colorHex: String; var isDone: Bool; var isStudy: Bool }
    struct WordItem: Codable { var term: String; var meaning: String }
    var updatedAt = Date()
    var dayKey = "2026-11-04"
    var plans = [PlanItem(title: "수학", time: "오후 4:00", colorHex: "#3D9BE0", isDone: true, isStudy: true)]
    var dDayTitle = "기말고사"
    var dDayDate: Date? = Date()
    var words = [WordItem(term: "abundant", meaning: "풍부한")]
    var wordsLeft = 7
    var studyMinutes = 95
    var goalMinutes = 120
    var streak = 4
    var accentHex = "#3D9BE0"
}

func runWidgetCases() {
    let cal = Calendar.current
    func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // 옛 스냅샷도 그대로 읽힘 (새 값은 기본값)
    let oldData = try! JSONEncoder().encode(OldWidgetSnapshot())
    let old = WidgetSnapshot.decode(oldData)
    check("위젯: 옛 스냅샷 읽기", old != nil)
    check("위젯: 옛 스냅샷 값 유지", old?.studyMinutes == 95 && old?.goalMinutes == 120 && old?.streak == 4
          && old?.plans.first?.title == "수학" && old?.plans.first?.planID == nil && old?.words.count == 1 && old?.accentHex == "#3D9BE0")
    check("위젯: 옛 스냅샷 새 값은 비어 있음", old?.days.isEmpty == true && old?.upcoming.isEmpty == true && old?.bestStreak == 0)
    let empty = WidgetSnapshot.decode(Data("{}".utf8))
    check("위젯: 빈 스냅샷도 기본값으로", empty?.goalMinutes == 180 && empty?.accentHex == "#7B68EE" && empty?.dayKey == "")
    let wrongType = WidgetSnapshot.decode(Data(#"{"studyMinutes":"많이","goalMinutes":60}"#.utf8))
    check("위젯: 모양이 틀린 값만 기본값", wrongType?.studyMinutes == 0 && wrongType?.goalMinutes == 60)
    check("위젯: 깨진 자료는 nil", WidgetSnapshot.decode(Data("x".utf8)) == nil)

    // 새 스냅샷 왕복
    let now = day(2026, 11, 4, 15)
    let preview = WidgetSnapshot.preview(now: now)
    let back = WidgetSnapshot.decode(try! JSONEncoder().encode(preview))
    check("위젯: 새 스냅샷 왕복", back == preview)
    check("위젯: 예시 달력 칸 = 그 달 칸", preview.days.count == WidgetMath.monthGrid(for: now).count && preview.days.first?.key == "2026-11-01")
    check("위젯: 예시 이번 주만 일정 이름", preview.days.filter { $0.items != nil }.count == 7)

    // 월간 달력 칸: 일요일부터, 주 단위
    let nov = WidgetMath.monthGrid(for: now)
    check("위젯: 2026년 11월 달력 35칸", nov.count == 35, "\(nov.count)")
    check("위젯: 11월 첫 칸 = 11월 1일(일)", WidgetMath.dayKey(nov[0]) == "2026-11-01" && cal.component(.weekday, from: nov[0]) == 1)
    let feb = WidgetMath.monthGrid(for: day(2026, 2, 10))
    check("위젯: 2026년 2월 딱 4주", feb.count == 28 && WidgetMath.dayKey(feb[27]) == "2026-02-28")
    let aug = WidgetMath.monthGrid(for: day(2026, 8, 31))
    check("위젯: 2026년 8월 6주", aug.count == 42 && WidgetMath.dayKey(aug[0]) == "2026-07-26" && WidgetMath.dayKey(aug[41]) == "2026-09-05")
    check("위젯: 달력 칸은 모두 일요일 시작 줄", stride(from: 0, to: aug.count, by: 7).allSatisfy { cal.component(.weekday, from: aug[$0]) == 1 })
    let augDays = Set(aug.map { WidgetMath.dayKey($0) })
    check("위젯: 그 달 날짜 빠짐없이", (1...31).allSatisfy { augDays.contains(String(format: "2026-08-%02d", $0)) })

    // 이번 주 (일~토)
    let week = WidgetMath.week(containing: now)
    check("위젯: 이번 주 7일", week.count == 7 && WidgetMath.dayKey(week[0]) == "2026-11-01" && WidgetMath.dayKey(week[6]) == "2026-11-07")
    check("위젯: 토요일도 같은 주", WidgetMath.dayKey(WidgetMath.week(containing: day(2026, 11, 7))[0]) == "2026-11-01")

    // 연속 공부
    let keys: Set<String> = ["2026-11-04", "2026-11-03", "2026-11-02", "2026-10-31"]
    check("위젯: 오늘까지 연속 3일", WidgetMath.currentStreak(studiedKeys: keys, today: now) == 3)
    check("위젯: 오늘 아직이면 어제부터", WidgetMath.currentStreak(studiedKeys: ["2026-11-03", "2026-11-02"], today: now) == 2)
    check("위젯: 어제도 안 했으면 0", WidgetMath.currentStreak(studiedKeys: ["2026-11-02"], today: now) == 0)
    check("위젯: 달이 바뀌어도 이어짐", WidgetMath.currentStreak(studiedKeys: ["2026-11-01", "2026-10-31", "2026-10-30"], today: day(2026, 11, 1)) == 3)

    var stale = WidgetSnapshot()
    stale.dayKey = "2026-11-03"
    stale.streak = 5
    stale.studyMinutes = 30
    check("위젯: 하루 늦은 스냅샷 · 그날 공부했으면 연속 유지", stale.streak(at: now) == 5)
    stale.studyMinutes = 0
    check("위젯: 하루 늦은 스냅샷 · 그날 안 했으면 끊김", stale.streak(at: now) == 0)
    stale.dayKey = "2026-11-04"
    check("위젯: 오늘 스냅샷은 그대로", stale.streak(at: now) == 5)
    stale.dayKey = "2026-11-01"
    stale.studyMinutes = 60
    check("위젯: 며칠 늦으면 0", stale.streak(at: now) == 0)
    check("위젯: 날짜가 바뀌면 오래된 자료", stale.isStale(at: now) && !preview.isStale(at: now))

    // 진하기
    check("위젯: 진하기 0", WidgetMath.heatLevel(minutes: 0, goal: 180) == 0)
    check("위젯: 진하기 단계", WidgetMath.heatLevel(minutes: 10, goal: 180) == 1 && WidgetMath.heatLevel(minutes: 60, goal: 180) == 2
          && WidgetMath.heatLevel(minutes: 150, goal: 180) == 3 && WidgetMath.heatLevel(minutes: 180, goal: 180) == 4)
    check("위젯: 목표 0분이어도 안전", WidgetMath.heatLevel(minutes: 5, goal: 0) == 4)

    // 짧은 시간 글
    check("위젯: 시간 글", WidgetMath.durationText(95) == "1시간 35분" && WidgetMath.durationText(120) == "2시간" && WidgetMath.durationText(45) == "45분")
    check("위젯: 그래프 시간 글", WidgetMath.compactHours(45) == "45분" && WidgetMath.compactHours(90) == "1.5시간"
          && WidgetMath.compactHours(120) == "2시간" && WidgetMath.compactHours(725) == "12시간", WidgetMath.compactHours(90))

    // D-Day
    var dday = WidgetSnapshot()
    dday.dDayTitle = "기말고사"
    dday.dDayDate = day(2026, 11, 16, 0)
    check("위젯: D-Day 글", dday.dDayText(on: now) == "D-12" && dday.dDayText(on: day(2026, 11, 16, 23)) == "D-DAY"
          && dday.dDayText(on: day(2026, 11, 19)) == "D+3")

    // 다음 일정: 끝난 것 · 완료한 것 빼고
    var snap = WidgetSnapshot()
    snap.dayKey = "2026-11-04"
    func plan(_ id: String, _ h: Int, _ len: Int, done: Bool = false) -> WidgetSnapshot.PlanItem {
        WidgetSnapshot.PlanItem(title: id, time: "", colorHex: "#000000", isDone: done, isStudy: true, planID: id, dayKey: "2026-11-04",
                                start: day(2026, 11, 4, h), end: day(2026, 11, 4, h).addingTimeInterval(Double(len) * 60), isAllDay: false)
    }
    snap.upcoming = [plan("a", 14, 30), plan("b", 15, 90), plan("c", 16, 60, done: true), plan("d", 18, 60)]
    check("위젯: 다음 일정 = 진행 중부터", snap.nextPlans(at: now).map(\.title) == ["b", "d"], "\(snap.nextPlans(at: now).map(\.title))")
    check("위젯: 다 끝나면 없음", snap.nextPlans(at: day(2026, 11, 4, 20)).isEmpty)

    // 다시 그릴 시각: 지금 + 일정 시작·끝 + 자정 직후, 차례대로
    let refresh = WidgetMath.refreshDates(now: now, upcoming: snap.upcoming)
    check("위젯: 다시 그릴 시각 차례대로", refresh == refresh.sorted() && refresh.first == now)
    check("위젯: 일정 시작에 다시 그림", refresh.contains(day(2026, 11, 4, 18)) && refresh.contains(day(2026, 11, 4, 16).addingTimeInterval(30 * 60)))
    check("위젯: 자정 직후 다시 그림", refresh.contains(day(2026, 11, 5, 0).addingTimeInterval(60)))
    check("위젯: 지난 시각은 빼기", !refresh.contains(day(2026, 11, 4, 14)))

    // 위젯에서 누른 완료 체크
    check("위젯: 일정 이름표 나누기", WidgetPending.split("8E2C-11_2026-11-04").map { "\($0.planID)|\($0.dayKey)" } == "8E2C-11|2026-11-04")
    check("위젯: 잘못된 이름표", WidgetPending.split("abc") == nil && WidgetPending.split("_2026-11-04") == nil && WidgetPending.split("a_어제") == nil)
    var checked = WidgetSnapshot()
    checked.dayKey = "2026-11-04"
    checked.plans = [plan("a", 14, 30), plan("b", 15, 90)]
    checked.days = [WidgetSnapshot.DayStat(key: "2026-11-04", minutes: 30, planCount: 2, doneCount: 0, colors: [], items: checked.plans)]
    let afterDone = checked.settingPlan("b_2026-11-04", done: true)
    check("위젯: 체크하면 바로 완료 모양", afterDone.plans[1].isDone && !afterDone.plans[0].isDone && afterDone.days[0].doneCount == 1
          && afterDone.days[0].items?[1].isDone == true)
    let again = afterDone.settingPlan("b_2026-11-04", done: true)
    check("위젯: 두 번 눌러도 한 번만 셈", again.days[0].doneCount == 1)
    let undone = again.settingPlan("b_2026-11-04", done: false)
    check("위젯: 완료 취소", !undone.plans[1].isDone && undone.days[0].doneCount == 0)
    check("위젯: 없는 일정은 그대로", checked.settingPlan("zzz_2026-11-04", done: true) == checked)

    if let defaults = UserDefaults(suiteName: "widget-cases-\(UUID().uuidString)") {
        WidgetPending.add("a_2026-11-04", done: true, defaults)
        WidgetPending.add("b_2026-11-04", done: true, defaults)
        WidgetPending.add("a_2026-11-04", done: false, defaults)
        check("위젯: 누른 체크 모아 두기 (마지막 상태)", WidgetPending.load(defaults) == ["a_2026-11-04": false, "b_2026-11-04": true])
        WidgetPending.clear(defaults)
        check("위젯: 저장한 뒤 비우기", WidgetPending.load(defaults).isEmpty)
    }
}
