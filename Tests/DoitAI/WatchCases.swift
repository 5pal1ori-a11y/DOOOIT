import Foundation

// 애플 워치 연결: 주고받는 자료(Codable) · 아이폰이 명령을 처리하는 규칙 · 워치가 미리 보여 주는 상태

@MainActor
func runWatchCases() {
    let cal = Calendar.current
    let now = Date()
    let today = WatchLink.dayKey(now)

    // 날짜 키는 앱과 같은 모양
    check("워치: 날짜 키", today == now.dayKey, "\(today) vs \(now.dayKey)")
    check("워치: 날짜 키 되돌리기", WatchLink.date(fromDayKey: today).map { cal.isDate($0, inSameDayAs: now) } == true)

    // 스냅샷 주고받기 (메시지 사전 → 다시 읽기)
    var snap = WatchSnapshot()
    snap.updatedAt = now
    snap.dayKey = today
    snap.savedSeconds = 3_000
    snap.goalMinutes = 100
    snap.timer = WatchTimerState.make(phase: .running, title: "자유 공부", targetSeconds: 1_500, elapsed: 600, now: now)
    snap.plans = [WatchPlanItem(id: "p_\(today)", planID: "p", dayKey: today, title: "수학", time: "오후 4:00", colorHex: "#3D9BE0", isDone: false, isStudy: true)]
    snap.words = [WatchWordItem(id: "w1", term: "abundant", meaning: "풍부한"), WatchWordItem(id: "w2", term: "rapid", meaning: "빠른")]
    let back = WatchSnapshot.from(snap.message)
    check("워치: 스냅샷 왕복", back == snap)
    check("워치: 잘못된 메시지는 무시", WatchSnapshot.from(["snapshot": Data("x".utf8)]) == nil && WatchSnapshot.from([:]) == nil)

    // 타이머 시간 계산
    check("워치: 흐르는 타이머 지난 시간", abs(snap.timer.elapsed(at: now) - 600) < 0.01)
    check("워치: 남은 시간", abs((snap.timer.remaining(at: now) ?? 0) - 900) < 0.01)
    check("워치: 목표 시각", snap.timer.goalDate.map { abs($0.timeIntervalSince(now) - 900) < 0.01 } == true)
    check("워치: 오늘 공부 = 저장 + 진행 중", snap.studySeconds(at: now) == 3_600, "\(snap.studySeconds(at: now))")
    check("워치: 목표 진행률", abs(snap.goalProgress(at: now) - 0.6) < 0.001, "\(snap.goalProgress(at: now))")
    let paused = WatchTimerState.make(phase: .paused, title: "t", targetSeconds: nil, elapsed: 120, now: now)
    check("워치: 멈춘 타이머는 그대로", paused.elapsed(at: now.addingTimeInterval(500)) == 120 && paused.goalDate == nil && paused.progress(at: now) == nil)
    check("워치: 끝난 타이머 0", WatchTimerState.make(phase: .idle, title: "t", targetSeconds: 60, elapsed: 99, now: now) == WatchTimerState())

    // 어제 자료는 오늘 0분부터
    var yesterday = snap
    yesterday.dayKey = WatchLink.dayKey(now.addingTimeInterval(-86_400 * 2))
    yesterday.timer = WatchTimerState()
    let fresh = yesterday.forToday(now)
    check("워치: 지난 날 자료 비움", fresh.savedSeconds == 0 && fresh.plans.isEmpty && fresh.words.isEmpty && fresh.dayKey == today)
    check("워치: 지난 날 공부 시간은 안 셈", yesterday.studySeconds(at: now) == 0)

    // 크라운 목표 고르기: ∞ + 5분 단위
    let choices = WatchTimerState.targetChoices
    check("워치: 목표 첫 칸은 ∞", choices.first! == nil && WatchTimerState.targetLabel(nil) == "∞")
    check("워치: 목표 5분 단위", choices[1] == 5 && choices[2] == 10 && choices.last! == 240)
    check("워치: 목표 글", WatchTimerState.targetLabel(25) == "25분" && WatchTimerState.targetLabel(60) == "1시간" && WatchTimerState.targetLabel(90) == "1시간 30분")
    check("워치: 시계 글", WatchFormat.clock(65) == "01:05" && WatchFormat.clock(3_909) == "1:05:09" && WatchFormat.clock(-3) == "00:00")
    check("워치: 공부 시간 글", WatchFormat.duration(5_700) == "1시간 35분" && WatchFormat.duration(2_400) == "40분" && WatchFormat.duration(7_200) == "2시간")
    check("워치: 좁은 칸 글", WatchFormat.short(5_700) == "1:35" && WatchFormat.short(600) == "10분")

    // 명령 주고받기
    let commands: [WatchCommand.Action] = [
        .startTimer(targetMinutes: 25), .startTimer(targetMinutes: nil), .pauseTimer, .resumeTimer, .stopTimer,
        .setPlanDone(planID: "p", dayKey: today, done: true), .gradeWord(wordID: "w1", known: false), .refresh
    ]
    for action in commands {
        let command = WatchCommand(action)
        check("워치: 명령 왕복 \(action)", WatchCommand.from(command.message) == command)
    }
    check("워치: 할 일 명령 대상", WatchCommand(.setPlanDone(planID: "p", dayKey: today, done: true)).targetID == "p_\(today)")

    // 아이폰: 타이머 명령은 지금 상태에 맞을 때만
    typealias L = WatchBridgeLogic
    check("아이폰: 쉬는 중 시작", L.timerAction(for: .startTimer(targetMinutes: 25), phase: .idle) == .start(targetMinutes: 25))
    check("아이폰: 이미 공부 중이면 새로 시작 안 함", L.timerAction(for: .startTimer(targetMinutes: 25), phase: .running) == .none)
    check("아이폰: 멈춤 중 시작도 무시", L.timerAction(for: .startTimer(targetMinutes: nil), phase: .paused) == .none)
    check("아이폰: 멈춤", L.timerAction(for: .pauseTimer, phase: .running) == .pause && L.timerAction(for: .pauseTimer, phase: .paused) == .none)
    check("아이폰: 다시 시작", L.timerAction(for: .resumeTimer, phase: .paused) == .resume && L.timerAction(for: .resumeTimer, phase: .idle) == .none)
    check("아이폰: 끝", L.timerAction(for: .stopTimer, phase: .running) == .stop && L.timerAction(for: .stopTimer, phase: .paused) == .stop
          && L.timerAction(for: .stopTimer, phase: .idle) == .none)
    check("아이폰: 목표 시간 범위", L.timerAction(for: .startTimer(targetMinutes: 0), phase: .idle) == .start(targetMinutes: 1)
          && L.timerAction(for: .startTimer(targetMinutes: 99_999), phase: .idle) == .start(targetMinutes: 720))
    check("아이폰: 할 일 명령은 다른 처리", L.timerAction(for: .refresh, phase: .running) == .none)

    // 늦게 온 명령은 누른 시각으로 (미래 · 너무 옛날은 자름)
    check("아이폰: 누른 시각", L.effectiveTime(sentAt: now.addingTimeInterval(-30), now: now) == now.addingTimeInterval(-30))
    check("아이폰: 미래 시각 자름", L.effectiveTime(sentAt: now.addingTimeInterval(60), now: now) == now)
    check("아이폰: 옛날 시각 자름", L.effectiveTime(sentAt: now.addingTimeInterval(-86_400), now: now) == now.addingTimeInterval(-6 * 3600))

    // 오늘 공부 시간 (오늘 기록만)
    let sessions: [(start: Date, seconds: Int)] = [(now, 600), (now.addingTimeInterval(-60), 300), (now.addingTimeInterval(-86_400 * 2), 9_999)]
    check("아이폰: 오늘 공부 시간", L.todaySeconds(sessions, now: now) == 900)

    // 복습 단어 카드: 차례가 된 것만, 오래 기다린 것부터
    let words = [
        L.WordInfo(id: "a", term: "late", meaning: "늦은", reviewStage: 2, nextReviewAt: now.addingTimeInterval(-3_600)),
        L.WordInfo(id: "b", term: "early", meaning: "이른", reviewStage: 1, nextReviewAt: now.addingTimeInterval(-86_400)),
        L.WordInfo(id: "c", term: "future", meaning: "미래", reviewStage: 3, nextReviewAt: now.addingTimeInterval(86_400)),
        L.WordInfo(id: "d", term: "new", meaning: "새", reviewStage: 0, nextReviewAt: nil),
        L.WordInfo(id: "e", term: "done", meaning: "끝", reviewStage: WordReview.mastered, nextReviewAt: nil),
        L.WordInfo(id: "f", term: " ", meaning: "빈칸", reviewStage: 1, nextReviewAt: now.addingTimeInterval(-10))
    ]
    let deck = L.reviewDeck(words, now: now)
    check("아이폰: 복습 카드", deck.map(\.id) == ["b", "a"], "\(deck.map(\.id))")
    check("아이폰: 복습 카드 개수 제한", L.reviewDeck(Array(repeating: words[0], count: 40), now: now).count == 15)

    // 알아요/몰라요 → 앱과 같은 복습 일정
    let due = L.WordState(reviewStage: 2, nextReviewAt: now.addingTimeInterval(-60), correctCount: 3, wrongCount: 1)
    let known = L.graded(due, known: true, now: now)
    let expectKnown = WordReview.afterReview(stage: 2, correct: true, now: now)
    check("아이폰: 알아요 → 다음 간격", known?.reviewStage == expectKnown.stage && known?.nextReviewAt == expectKnown.next && known?.correctCount == 4 && known?.wrongCount == 1)
    let unknown = L.graded(due, known: false, now: now)
    let expectUnknown = WordReview.afterReview(stage: 2, correct: false, now: now)
    check("아이폰: 몰라요 → 내일부터 다시", unknown?.reviewStage == 1 && unknown?.nextReviewAt == expectUnknown.next && unknown?.wrongCount == 2)
    check("아이폰: 같은 결과 두 번은 한 번만", known.flatMap { L.graded($0, known: true, now: now) } == nil)
    let last = L.WordState(reviewStage: WordReview.intervals.count, nextReviewAt: now.addingTimeInterval(-1), correctCount: 0, wrongCount: 0)
    check("아이폰: 마지막 복습 통과 → 완전히 외움", L.graded(last, known: true, now: now)?.reviewStage == WordReview.mastered)

    // 할 일 체크는 바뀔 때만
    check("아이폰: 할 일 체크", L.needsToggle(isCompleted: false, wantDone: true) && !L.needsToggle(isCompleted: true, wantDone: true))

    // 같은 명령 두 번 막기 (최근 것만 기억)
    var recent = L.Recent(limit: 3)
    check("아이폰: 처음 명령", recent.insert("a") && recent.insert("b"))
    check("아이폰: 같은 명령 거절", !recent.insert("a"))
    _ = recent.insert("c"); _ = recent.insert("d")
    check("아이폰: 오래된 id는 잊음", recent.ids == ["b", "c", "d"] && !recent.contains("a"))

    // 워치가 미리 보여 주기: 보낸 명령을 아이폰 답 전에 반영
    var base = WatchSnapshot()
    base.updatedAt = now
    base.dayKey = today
    base.savedSeconds = 600
    base.plans = snap.plans
    base.words = snap.words
    let t0 = now.addingTimeInterval(-300)
    let start = WatchCommand(.startTimer(targetMinutes: 25), sentAt: t0)
    let shown = base.applying([start])
    check("워치: 시작 바로 보임", shown.timer.phase == .running && shown.timer.targetSeconds == 1_500 && abs(shown.timer.elapsed(at: now) - 300) < 0.01)
    let pause = WatchCommand(.pauseTimer, sentAt: now.addingTimeInterval(-60))
    let pausedShown = base.applying([start, pause])
    check("워치: 멈춤 바로 보임", pausedShown.timer.phase == .paused && abs(pausedShown.timer.pausedElapsed - 240) < 0.01)
    let resume = WatchCommand(.resumeTimer, sentAt: now.addingTimeInterval(-30))
    let resumed = base.applying([start, pause, resume])
    check("워치: 다시 시작 (멈춘 시간 빼고)", resumed.timer.phase == .running && abs(resumed.timer.elapsed(at: now) - 270) < 0.01)
    let stop = WatchCommand(.stopTimer, sentAt: now)
    let stopped = base.applying([start, pause, resume, stop])
    check("워치: 끝 → 오늘 시간에 더함", stopped.timer.phase == .idle && stopped.savedSeconds == 870, "\(stopped.savedSeconds)")
    var running = base
    running.timer = WatchTimerState.make(phase: .running, title: "수학", targetSeconds: nil, elapsed: 100, now: now)
    check("워치: 아이폰 타이머가 돌면 시작은 무시", running.applying([start]).timer == running.timer)
    let plan = WatchCommand(.setPlanDone(planID: "p", dayKey: today, done: true))
    let word = WatchCommand(.gradeWord(wordID: "w1", known: true))
    let both = base.applying([plan, word])
    check("워치: 할 일 체크 바로 보임", both.plans.first?.isDone == true)
    check("워치: 단어 카드 넘김", both.words.map(\.id) == ["w2"])

    // 아이폰이 처리한 명령은 다시 반영하지 않음
    var appliedSnap = base
    appliedSnap.applied = [plan.id]
    check("워치: 처리된 명령 건너뜀", appliedSnap.applying([plan]).plans.first?.isDone == false)
    check("워치: 처리된 명령 지움", appliedSnap.stillPending([plan, word], now: now).map(\.id) == [word.id])
    let old = WatchCommand(.refresh, sentAt: now.addingTimeInterval(-7 * 3600))
    check("워치: 오래된 명령 지움", base.stillPending([old], now: now).isEmpty)
    var later = base
    later.updatedAt = now.addingTimeInterval(900)
    check("워치: 아이폰 상태가 한참 뒤면 지움", later.stillPending([word], now: now).isEmpty)

    runWatchMoreCases(now: now, base: base, snap: snap, word: word, words: words, t0: t0)
}

// MARK: - 워치 기능 더하기 (이번 주 · 연속 · D-Day · 퀴즈 · 할 일 추가 · 모티 · 뽀모도로)

@MainActor
private func runWatchMoreCases(now: Date, base: WatchSnapshot, snap: WatchSnapshot, word: WatchCommand,
                               words: [WatchBridgeLogic.WordInfo], t0: Date) {
    typealias L = WatchBridgeLogic
    let today = WatchLink.dayKey(now)
    let cal = Calendar.current
    let todayStart = cal.startOfDay(for: now)

    // 옛 버전 스냅샷(새 칸 없음)도 읽음
    let oldJSON = "{\"version\":1,\"updatedAt\":0,\"dayKey\":\"\(today)\",\"savedSeconds\":60,\"goalMinutes\":90,\"accentHex\":\"#7B68EE\","
        + "\"timer\":{\"phase\":\"idle\",\"title\":\"\",\"pausedElapsed\":0},"
        + "\"plans\":[{\"id\":\"x\",\"planID\":\"x\",\"dayKey\":\"\(today)\",\"title\":\"t\",\"time\":\"종일\",\"colorHex\":\"#000000\",\"isDone\":false,\"isStudy\":false}],"
        + "\"words\":[{\"id\":\"w\",\"term\":\"a\",\"meaning\":\"b\"}],\"applied\":[]}"
    let oldSnap = WatchSnapshot.from(["snapshot": Data(oldJSON.utf8)])
    check("워치+: 옛 스냅샷 읽기", oldSnap?.savedSeconds == 60 && oldSnap?.goalMinutes == 90 && oldSnap?.plans.first?.start == nil
          && oldSnap?.week == [] && oldSnap?.answer == nil && oldSnap?.words.first?.choices == nil, "\(String(describing: oldSnap))")
    check("워치+: 빈 스냅샷도 기본값", WatchSnapshot.from(["snapshot": Data("{}".utf8)]) == WatchSnapshot())

    // 새 칸 왕복
    var rich = snap
    rich.week = [0, 600, 1_200, 0, 3_600, 60, 3_000]
    rich.streak = 4
    rich.ddays = [WatchDDay(id: "d", title: "수능", dayKey: WatchLink.dayKey(now.addingTimeInterval(86_400 * 3)))]
    rich.tomorrow = [WatchPlanItem(id: "q_\(WatchLink.dayKey(now.addingTimeInterval(86_400)))", planID: "q", dayKey: WatchLink.dayKey(now.addingTimeInterval(86_400)), title: "영어",
                                   time: "오전 9:00", colorHex: "#000000", isDone: false, isStudy: true, start: now.addingTimeInterval(86_400))]
    rich.words[0].choices = ["풍부한", "빠른", "느린", "작은"]
    rich.practice = [WatchWordItem(id: "p1", term: "calm", meaning: "고요한", choices: ["고요한", "a", "b", "c"])]
    rich.wordsToday = 7
    rich.mistakes = 3
    rich.answer = WatchAnswer(id: "c1", question: "q", text: "a")
    check("워치+: 새 칸 왕복", WatchSnapshot.from(rich.message) == rich)

    // D-Day 글
    check("워치+: D-Day 글", rich.ddays[0].label(from: now) == "D-3"
          && WatchDDay(id: "", title: "", dayKey: today).label(from: now) == "D-Day"
          && WatchDDay(id: "", title: "", dayKey: WatchLink.dayKey(now.addingTimeInterval(-86_400 * 2))).label(from: now) == "D+2")

    // 이번 주 · 연속 (오늘 칸은 진행 중 타이머 포함)
    check("워치+: 이번 주 오늘 칸", rich.weekSeconds(at: now).last == 3_600 && rich.weekSeconds(at: now).count == 7)
    var noWeek = WatchSnapshot(); noWeek.dayKey = today; noWeek.savedSeconds = 120
    check("워치+: 주 자료 없으면 오늘만", noWeek.weekSeconds(at: now) == [120])
    var streakSnap = WatchSnapshot(); streakSnap.dayKey = today; streakSnap.streak = 2; streakSnap.week = [0, 0, 0, 0, 600, 600, 0]
    check("워치+: 오늘 아직이면 그대로", streakSnap.streak(at: now) == 2)
    streakSnap.timer = WatchTimerState.make(phase: .running, title: "t", targetSeconds: nil, elapsed: 90, now: now)
    check("워치+: 오늘 시작하면 +1", streakSnap.streak(at: now) == 3)

    // 다음 일정 · 남은 할 일 · 목표 닿는 시각
    var day = WatchSnapshot(); day.dayKey = today; day.goalMinutes = 60; day.savedSeconds = 1_800
    func item(_ id: String, _ title: String, done: Bool = false, _ offset: TimeInterval?) -> WatchPlanItem {
        WatchPlanItem(id: id, planID: id, dayKey: today, title: title, time: "", colorHex: "", isDone: done, isStudy: true,
                      start: offset.map { now.addingTimeInterval($0) })
    }
    day.plans = [item("1", "지난", -60), item("2", "나중", 7_200), item("3", "곧", 600), item("4", "끝낸", done: true, 300), item("5", "종일", nil)]
    check("워치+: 다음 일정", day.nextPlan(at: now)?.title == "곧")
    check("워치+: 남은 할 일", day.remainingCount == 4)
    check("워치+: 쉬는 중엔 목표 시각 없음", day.dailyGoalDate(at: now) == nil)
    day.timer = WatchTimerState.make(phase: .running, title: "t", targetSeconds: nil, elapsed: 600, now: now)
    check("워치+: 오늘 목표 닿는 시각", day.dailyGoalDate(at: now).map { abs($0.timeIntervalSince(now) - 1_200) < 0.01 } == true)

    // 하루 지나면: 내일 할 일 → 오늘, 주 막대 밀기, 연속 유지
    var eve = WatchSnapshot()
    eve.dayKey = WatchLink.dayKey(now.addingTimeInterval(-86_400))
    eve.savedSeconds = 900
    eve.week = [1, 2, 3, 4, 5, 6, 900]
    eve.streak = 5
    eve.plans = [WatchPlanItem(id: "old", planID: "o", dayKey: eve.dayKey, title: "어제", time: "", colorHex: "", isDone: false, isStudy: false)]
    eve.tomorrow = [WatchPlanItem(id: "t_\(today)", planID: "t", dayKey: today, title: "오늘 것", time: "", colorHex: "", isDone: false, isStudy: false)]
    let morning = eve.forToday(now)
    check("워치+: 하루 지나면 내일 할 일이 오늘", morning.plans.map(\.title) == ["오늘 것"] && morning.tomorrow.isEmpty)
    check("워치+: 주 막대 하루 밀기", morning.week == [2, 3, 4, 5, 6, 900, 0], "\(morning.week)")
    check("워치+: 어제 공부했으면 연속 유지", morning.streak == 5)
    var lazy = eve; lazy.week = [0, 0, 0, 0, 0, 0, 0]
    check("워치+: 어제 안 했으면 연속 0", lazy.forToday(now).streak == 0)
    var gap = eve; gap.dayKey = WatchLink.dayKey(now.addingTimeInterval(-86_400 * 3))
    let gapped = gap.forToday(now)
    check("워치+: 며칠 지나면 비움", gapped.plans.isEmpty && gapped.streak == 0 && gapped.week == [4, 5, 6, 900, 0, 0, 0], "\(gapped.week)")

    // 새 명령 왕복 + 미리 보이기
    let planAction = WatchCommand.Action.startSession(WatchStart(targetMinutes: 50, planID: "p", dayKey: today, title: nil))
    let pomoAction = WatchCommand.Action.startSession(WatchStart(targetMinutes: 25, planID: nil, dayKey: nil, title: "뽀모도로"))
    let newActions: [WatchCommand.Action] = [planAction, pomoAction, .addPlan(text: "내일 4시 수학", dayKey: today), .ask(text: "오늘 할 일 알려줘")]
    for action in newActions {
        let command = WatchCommand(action, at: now)
        check("워치+: 새 명령 왕복 \(action)", WatchCommand.from(command.message) == command)
    }
    let oldCommand = "{\"id\":\"z\",\"sentAt\":0,\"action\":{\"pauseTimer\":{}}}"
    check("워치+: 옛 명령도 읽음", WatchCommand.from(["command": Data(oldCommand.utf8)])?.action == .pauseTimer)
    check("워치+: 할 일 시작도 타이머 명령", WatchCommand(planAction).isTimer && !WatchCommand(newActions[2]).isTimer)

    let planStart = base.applying([WatchCommand(planAction, sentAt: t0)])
    check("워치+: 할 일에 붙여 시작 → 그 이름", planStart.timer.title == "수학" && planStart.timer.targetSeconds == 3_000)
    let pomoStart = base.applying([WatchCommand(pomoAction, sentAt: t0)])
    check("워치+: 이름 붙여 시작", pomoStart.timer.title == "뽀모도로" && pomoStart.timer.phase == .running)
    let late = WatchCommand(.stopTimer, sentAt: now, at: t0.addingTimeInterval(120))
    let lateStopped = base.applying([WatchCommand(pomoAction, sentAt: t0), late])
    check("워치+: 일어난 시각으로 끝 (늦게 보내도 2분만)", lateStopped.savedSeconds == 600 + 120, "\(lateStopped.savedSeconds)")
    let tomorrowKey = WatchLink.dayKey(now.addingTimeInterval(86_400))
    let added = base.applying([WatchCommand(.addPlan(text: " 국어 숙제 ", dayKey: today)), WatchCommand(.addPlan(text: "영어", dayKey: tomorrowKey)),
                               WatchCommand(.addPlan(text: "  ", dayKey: today))])
    check("워치+: 추가한 할 일 바로 보임", added.plans.last?.title == "국어 숙제" && added.plans.last?.isSending == true
          && added.plans.count == base.plans.count + 1)
    check("워치+: 내일 할 일 추가", added.tomorrow.map(\.title) == ["영어"])
    var withTomorrow = base; withTomorrow.tomorrow = rich.tomorrow
    let tDone = withTomorrow.applying([WatchCommand(.setPlanDone(planID: "q", dayKey: rich.tomorrow[0].dayKey, done: true))])
    check("워치+: 내일 할 일 체크", tDone.tomorrow.first?.isDone == true, "\(tDone.tomorrow)")
    check("워치+: 단어 넘기면 오늘 개수 +1", base.applying([word]).wordsToday == base.wordsToday + 1)

    // 아이폰: 이번 주 · 연속
    func at(_ daysBack: Int, _ hour: Int = 10) -> Date {
        cal.date(byAdding: .hour, value: hour, to: cal.date(byAdding: .day, value: -daysBack, to: todayStart)!)!
    }
    let hist: [(start: Date, seconds: Int)] = [(at(0), 300), (at(0, 12), 300), (at(1), 30), (at(1, 11), 40), (at(2), 600), (at(3), 59), (at(9), 999)]
    check("아이폰+: 이번 주 막대", L.weekSeconds(hist, now: now) == [0, 0, 0, 59, 600, 70, 600], "\(L.weekSeconds(hist, now: now))")
    check("아이폰+: 연속 (하루 합이 1분 넘으면)", L.streak(hist, now: now) == 3, "\(L.streak(hist, now: now))")
    check("아이폰+: 오늘 안 했으면 어제부터", L.streak(Array(hist.dropFirst(2)), now: now) == 2)
    check("아이폰+: 기록 없으면 0", L.streak([], now: now) == 0)

    // 아이폰: D-Day
    let dd = L.ddays([
        (id: "a", title: "기말", date: now.addingTimeInterval(86_400 * 10)),
        (id: "b", title: "지난 시험", date: now.addingTimeInterval(-86_400 * 2)),
        (id: "c", title: "모의고사", date: now.addingTimeInterval(86_400 * 2)),
        (id: "d", title: "모의고사", date: now.addingTimeInterval(86_400 * 2)),
        (id: "e", title: " ", date: now.addingTimeInterval(86_400)),
        (id: "f", title: "오늘 시험", date: todayStart)
    ], now: now)
    check("아이폰+: D-Day 가까운 것부터 · 지난 것 · 같은 것 뺌", dd.map(\.id) == ["f", "c", "a"], "\(dd.map(\.id))")

    // 아이폰: 4지선다
    let pool = ["풍부한", "빠른", "느린", "작은", "큰", "빠른", " "]
    let choices = L.quizChoices(answer: "풍부한", pool: pool, seed: "d1w1")
    check("아이폰+: 보기 4개 · 정답 하나 · 겹치지 않음", choices?.count == 4 && choices?.filter { $0 == "풍부한" }.count == 1
          && Set(choices ?? []).count == 4, "\(String(describing: choices))")
    check("아이폰+: 보기 늘 같음", L.quizChoices(answer: "풍부한", pool: pool, seed: "d1w1") == choices)
    check("아이폰+: 단어가 적으면 보기 없음", L.quizChoices(answer: "a", pool: ["a", "b", "c"], seed: "x") == nil)
    let positions = Set((0..<40).compactMap { L.quizChoices(answer: "풍부한", pool: pool, seed: "s\($0)")?.firstIndex(of: "풍부한") })
    check("아이폰+: 정답 자리 골고루", positions.count >= 3, "\(positions)")
    let practice = L.practiceDeck(words, excluding: ["b", "a"], now: now, limit: 3)
    check("아이폰+: 연습 단어 (복습 단어 · 빈칸 빼고)", practice.count == 3 && !practice.contains { ["a", "b", "f"].contains($0.id) }, "\(practice.map(\.id))")

    // 아이폰: 오늘 외운 단어 (복습 규칙 거꾸로)
    let learnedNow = WordReview.afterLearning(now: now)
    let reviewedNow = WordReview.afterReview(stage: 3, correct: true, now: now)
    let reviewedBefore = WordReview.afterReview(stage: 3, correct: true, now: now.addingTimeInterval(-86_400 * 2))
    check("아이폰+: 오늘 외운 단어", L.reviewedToday(stage: learnedNow.stage, next: learnedNow.next, now: now)
          && L.reviewedToday(stage: reviewedNow.stage, next: reviewedNow.next, now: now)
          && !L.reviewedToday(stage: reviewedBefore.stage, next: reviewedBefore.next, now: now)
          && !L.reviewedToday(stage: WordReview.mastered, next: nil, now: now))

    // 아이폰: 할 일 말로 넣기 (모티와 같은 해석)
    let qp = L.quickPlan("내일 오후 4시 수학 문제집 1시간", dayKey: today)
    check("아이폰+: 말로 할 일", qp?.dateText == "내일" && qp?.timeText == "오후 4시" && qp?.minutes == 60 && qp?.title == "수학 문제집"
          && qp?.isStudy == true, "\(String(describing: qp))")
    let qp2 = L.quickPlan("엄마 생일 선물", dayKey: today)
    check("아이폰+: 날짜 없으면 고른 날 · 종일", qp2?.dateText == today && qp2?.timeText == nil && qp2?.minutes == nil
          && qp2?.title == "엄마 생일 선물" && qp2?.isStudy == false, "\(String(describing: qp2))")
    let qp3 = L.quickPlan("3시 30분 영어", dayKey: today)
    check("아이폰+: 3시 30분은 시작 시각", qp3?.timeText == "3시 30분" && qp3?.minutes == nil, "\(String(describing: qp3))")
    check("아이폰+: 빈 말은 무시", L.quickPlan("   ", dayKey: today) == nil)
    check("아이폰+: 할 일 시작 목표 범위", L.timerAction(for: .startSession(WatchStart(targetMinutes: 0)), phase: .idle) == .start(targetMinutes: 1)
          && L.timerAction(for: .startSession(WatchStart()), phase: .running) == .none)

    // 아이폰: 모티 답 다듬기
    check("아이폰+: 답 다듬기", L.shortAnswer("**오늘**\n\n\n\n할 일 `3개`") == "오늘\n\n할 일 3개" && L.shortAnswer("  ") == "잘 모르겠어요")
    let longAnswer = L.shortAnswer(String(repeating: "가", count: 1_000))
    check("아이폰+: 긴 답 자름", longAnswer.count == 400 && longAnswer.hasSuffix("…"))

    // 크기: 꽉 채워도 applicationContext 한도(약 65KB)보다 훨씬 작게
    var big = WatchSnapshot()
    big.dayKey = today
    let longTitle = String(repeating: "긴제목이", count: 10)
    big.plans = (0..<25).map { _ in
        WatchPlanItem(id: "\(UUID().uuidString)_\(today)", planID: UUID().uuidString, dayKey: today, title: longTitle, time: "오후 10:00",
                      colorHex: "#7B68EE", isDone: false, isStudy: true, start: now)
    }
    big.tomorrow = Array(big.plans.prefix(10))
    let longMeaning = String(repeating: "뜻", count: 40)
    big.words = (0..<15).map { _ in
        WatchWordItem(id: UUID().uuidString, term: String(repeating: "w", count: 40), meaning: longMeaning, choices: Array(repeating: longMeaning, count: 4))
    }
    big.practice = Array(big.words.prefix(6))
    big.applied = (0..<30).map { _ in UUID().uuidString }
    big.week = Array(repeating: 99_999, count: 7)
    big.ddays = (0..<5).map { _ in WatchDDay(id: UUID().uuidString, title: longTitle, dayKey: today) }
    big.answer = WatchAnswer(id: UUID().uuidString, question: String(repeating: "질", count: 200), text: String(repeating: "답", count: 400))
    check("워치+: 스냅샷 크기", big.byteSize < 40_000, "\(big.byteSize)B")

    // 뽀모도로: 집중 끝 → 휴식 → 다음 집중, 네 번째엔 길게
    var cycle = WatchFocusCycle()
    let focusStart = now.addingTimeInterval(-25 * 60 - 10)
    let focusTimer = WatchTimerState(phase: .running, title: "뽀모도로", targetSeconds: 25 * 60, runningSince: focusStart)
    var early = cycle
    check("뽀모: 집중 중엔 그대로", early.update(timer: focusTimer, now: focusStart.addingTimeInterval(60)) == nil && early.stage == .focus)
    check("뽀모: 다음 진동은 집중 끝", cycle.nextEventDate(timer: focusTimer) == focusStart.addingTimeInterval(1_500))
    let focusEnd = focusStart.addingTimeInterval(1_500)
    check("뽀모: 집중 끝 (끝난 시각으로)", cycle.update(timer: focusTimer, now: now) == .focusDone(at: focusEnd) && cycle.stage == .rest
          && cycle.restUntil == focusEnd.addingTimeInterval(300))
    check("뽀모: 쉬는 중", cycle.update(timer: WatchTimerState(), now: now) == nil && cycle.nextEventDate(timer: WatchTimerState()) == cycle.restUntil)
    check("뽀모: 휴식 끝", cycle.update(timer: WatchTimerState(), now: focusEnd.addingTimeInterval(301)) == .restDone && cycle.stage == .ready)
    cycle.nextFocus()
    check("뽀모: 다음 집중", cycle.round == 2 && cycle.stage == .focus && cycle.restUntil == nil)
    var other = cycle
    check("뽀모: 다른 타이머면 그만",
          other.update(timer: WatchTimerState.make(phase: .running, title: "수학", targetSeconds: nil, elapsed: 5, now: now), now: now) == .cancelled)
    var stoppedCycle = cycle
    check("뽀모: 직접 끝내면 그만", stoppedCycle.update(timer: WatchTimerState(), now: now) == .cancelled)
    var pausedCycle = cycle
    let pausedFocus = WatchTimerState.make(phase: .paused, title: "뽀모도로", targetSeconds: 1_500, elapsed: 1_600, now: now)
    check("뽀모: 멈춰 있으면 기다림", pausedCycle.update(timer: pausedFocus, now: now) == nil)
    var fourth = WatchFocusCycle(); fourth.round = 4
    check("뽀모: 네 번째엔 길게 쉼", fourth.restLength == 15 && fourth.isLongRest && WatchFocusCycle().restLength == 5)
    var away = WatchFocusCycle()
    check("뽀모: 휴식까지 지나 돌아오면 바로 다음 준비",
          away.update(timer: focusTimer, now: focusEnd.addingTimeInterval(3_600)) == .focusDone(at: focusEnd) && away.stage == .ready)
    var skip = WatchFocusCycle(); skip.stage = .rest; skip.restUntil = now.addingTimeInterval(100); skip.skipRest()
    check("뽀모: 휴식 건너뛰기", skip.stage == .ready)
    var coffee = WatchFocusCycle.rest(minutes: 10, now: now)
    check("뽀모: 휴식만", coffee.restOnly && coffee.restLength == 10 && coffee.restUntil == now.addingTimeInterval(600)
          && coffee.update(timer: WatchTimerState(), now: now.addingTimeInterval(601)) == .restDone)
    check("뽀모: 저장 왕복", WatchLink.decode(WatchFocusCycle.self, WatchLink.encode(coffee)) == coffee)
}
