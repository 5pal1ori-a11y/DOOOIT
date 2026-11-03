import Foundation

// 애플 워치 연결: 주고받는 자료(Codable) · 아이폰이 명령을 처리하는 규칙 · 워치가 미리 보여 주는 상태

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
}
