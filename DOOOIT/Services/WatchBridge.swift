import Foundation
import SwiftData
import WatchConnectivity

/// 애플 워치 연결: 오늘 상태(공부 시간 · 목표 · 타이머 · 할 일 · 복습 단어 · 이번 주 · D-Day)를 워치에 보내고,
/// 워치에서 누른 명령을 기존 타이머 · 플랜 · 단어 복습 · 모티 AI 규칙으로 저장
/// 워치가 없거나 워치 앱을 설치하지 않았으면 아무것도 하지 않음 (안내 화면 없음)
@MainActor
final class WatchBridge: NSObject {
    static let shared = WatchBridge()

    private var container: ModelContainer?
    private var recent: WatchBridgeLogic.Recent
    private var pushTask: Task<Void, Never>?
    private var saveObserver: NSObjectProtocol?
    private var lastSent: Data?
    private var lastComplicationPush: Date = .distantPast
    private var lastTimerPhase: WatchTimerPhase?
    /// 워치에서 모티에게 물어본 마지막 답
    private var lastAnswer: WatchAnswer?
    private let recentKey = "dooit.watch.appliedCommands"

    private override init() {
        recent = WatchBridgeLogic.Recent(UserDefaults.standard.stringArray(forKey: recentKey) ?? [])
        super.init()
    }

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    /// 앱을 켤 때 · 계정을 바꿀 때 (지금 계정 저장소로 연결)
    func start(container: ModelContainer) {
        self.container = container
        guard let session else { return }
        if session.delegate == nil {
            session.delegate = self
            session.activate()
            observeTimer()
            // 플랜 체크 · 단어 · 공부 기록이 저장되면 워치도 새로
            saveObserver = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { _ in
                Task { @MainActor in WatchBridge.shared.setNeedsPush() }
            }
        }
        lastSent = nil
        setNeedsPush()
    }

    /// 조금 기다렸다가 한 번에 보냄 (연달아 바뀔 때)
    func setNeedsPush(after delay: Duration = .milliseconds(600)) {
        pushTask?.cancel()
        pushTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self.push()
        }
    }

    private var canSend: Bool {
        guard let session, session.activationState == .activated else { return false }
        return session.isPaired && session.isWatchAppInstalled
    }

    private func push() {
        guard canSend, let session, container != nil else { return }
        let snapshot = makeSnapshot()
        var comparable = snapshot
        comparable.updatedAt = Date(timeIntervalSince1970: 0)
        let data = WatchLink.encode(comparable)
        let timerChanged = lastTimerPhase != snapshot.timer.phase
        lastTimerPhase = snapshot.timer.phase
        guard data != lastSent else { return }
        lastSent = data
        let message = snapshot.message
        try? session.updateApplicationContext(message)
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else if session.isComplicationEnabled,
                  timerChanged || Date().timeIntervalSince(lastComplicationPush) > 20 * 60,
                  session.remainingComplicationUserInfoTransfers > 5 {
            // 워치 앱이 꺼져 있어도 컴플리케이션이 새 공부 시간을 보이게 (하루 횟수 제한이 있어 아껴 씀)
            lastComplicationPush = Date()
            session.transferCurrentComplicationUserInfo(message)
        }
    }

    // MARK: 타이머 변화 감시

    private func observeTimer() {
        let timer = StudyTimer.shared
        withObservationTracking {
            _ = (timer.phase, timer.title, timer.targetSeconds, timer.startedAt)
        } onChange: {
            Task { @MainActor in
                WatchBridge.shared.setNeedsPush(after: .milliseconds(200))
                WatchBridge.shared.observeTimer()
            }
        }
    }

    // MARK: 상태 만들기

    func makeSnapshot(now: Date = Date()) -> WatchSnapshot {
        var snapshot = WatchSnapshot()
        snapshot.updatedAt = now
        snapshot.dayKey = now.dayKey
        snapshot.accentHex = WidgetSync.accentHex
        snapshot.goalMinutes = UserDefaults.standard.object(forKey: SettingsKey.dailyStudyGoalMinutes) as? Int ?? 180
        snapshot.applied = Array(recent.ids.suffix(30))

        let timer = StudyTimer.shared
        let phase = WatchTimerPhase(rawValue: timer.phase.rawValue) ?? .idle
        snapshot.timer = WatchTimerState.make(phase: phase, title: timer.title, targetSeconds: timer.targetSeconds,
                                              elapsed: timer.elapsed(at: now), now: now)

        guard let context = container?.mainContext else { return snapshot }
        snapshot.answer = lastAnswer
        let sessions = ((try? context.fetch(FetchDescriptor<StudySession>())) ?? []).map { (start: $0.start, seconds: $0.seconds) }
        snapshot.savedSeconds = WatchBridgeLogic.todaySeconds(sessions, now: now)
        snapshot.week = WatchBridgeLogic.weekSeconds(sessions, now: now)
        snapshot.streak = WatchBridgeLogic.streak(sessions, now: now)

        let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        let accent = snapshot.accentHex
        func items(on day: Date, limit: Int) -> [WatchPlanItem] {
            plans.occurrences(on: day).prefix(limit).map { occurrence in
                WatchPlanItem(
                    id: occurrence.id,
                    planID: occurrence.plan.id.uuidString,
                    dayKey: occurrence.day.dayKey,
                    title: String(occurrence.plan.title.prefix(40)),
                    time: occurrence.plan.isAllDay ? "종일" : occurrence.start.kr("a h:mm"),
                    colorHex: occurrence.plan.category?.colorHex ?? accent,
                    isDone: occurrence.isCompleted,
                    isStudy: occurrence.plan.isStudy,
                    start: occurrence.plan.isAllDay ? nil : occurrence.start
                )
            }
        }
        snapshot.plans = items(on: now, limit: 25)
        snapshot.tomorrow = items(on: now.adding(days: 1), limit: 10)

        // D-Day: 설정에서 정한 것 + 시험 계획
        var ddays: [(id: String, title: String, date: Date)] = []
        let defaults = UserDefaults.standard
        let dDayTitle = defaults.string(forKey: SettingsKey.dDayTitle) ?? ""
        let dDayDate = defaults.double(forKey: SettingsKey.dDayDate)
        if !dDayTitle.isEmpty, dDayDate > 0 {
            ddays.append((id: "dday", title: dDayTitle, date: Date(timeIntervalSince1970: dDayDate)))
        }
        let exams = (try? context.fetch(FetchDescriptor<ExamPlan>())) ?? []
        ddays += exams.map { (id: $0.id.uuidString, title: $0.name.isEmpty ? "시험" : $0.name, date: $0.examDate) }
        snapshot.ddays = WatchBridgeLogic.ddays(ddays, now: now)

        let wrongRaw = NoteStatus.wrong.rawValue
        snapshot.mistakes = (try? context.fetchCount(FetchDescriptor<MathNote>(predicate: #Predicate { $0.statusRaw == wrongRaw }))) ?? 0

        let words = (try? context.fetch(FetchDescriptor<Word>())) ?? []
        let infos = words.map {
            WatchBridgeLogic.WordInfo(id: $0.id.uuidString, term: String($0.term.prefix(40)), meaning: String($0.meaning.prefix(40)),
                                      reviewStage: $0.reviewStage, nextReviewAt: $0.nextReviewAt)
        }
        let meanings = infos.map(\.meaning)
        let day = now.dayKey
        let due = WatchBridgeLogic.reviewDeck(infos, now: now)
        snapshot.words = WatchBridgeLogic.withChoices(due, meanings: meanings, day: day)
        snapshot.practice = WatchBridgeLogic.withChoices(
            WatchBridgeLogic.practiceDeck(infos, excluding: Set(due.map(\.id)), now: now), meanings: meanings, day: day)
            .filter { $0.choices != nil }
        snapshot.wordsToday = words.filter {
            ($0.learnedAt.map { $0.isSameDay(as: now) } ?? false)
                || WatchBridgeLogic.reviewedToday(stage: $0.reviewStage, next: $0.nextReviewAt, now: now)
        }.count
        return snapshot
    }

    // MARK: 워치 명령 처리

    func apply(_ command: WatchCommand) {
        guard recent.insert(command.id) else { return }
        UserDefaults.standard.set(recent.ids, forKey: recentKey)
        let now = Date()
        let at = WatchBridgeLogic.effectiveTime(sentAt: command.effectiveDate, now: now)
        let context = container?.mainContext

        switch command.action {
        case .startTimer, .startSession, .pauseTimer, .resumeTimer, .stopTimer:
            let timer = StudyTimer.shared
            // 워치가 앱을 뒤에서 깨운 경우에도 기록이 저장되게 지금 저장소에 연결
            if let context { timer.attach(context: context) }
            let phase = WatchTimerPhase(rawValue: timer.phase.rawValue) ?? .idle
            switch WatchBridgeLogic.timerAction(for: command.action, phase: phase) {
            case .start(let minutes):
                var request = WatchStart()
                if case .startSession(let start) = command.action { request = start }
                // 할 일에 붙여 시작: 그 일정 이름 · 과목 · 일정 키로 기록 (플래너의 자동 시작과 같은 모양)
                if let planID = request.planID, let id = UUID(uuidString: planID),
                   let plan = ((try? context?.fetch(FetchDescriptor<Plan>())) ?? []).first(where: { $0.id == id }) {
                    let day = request.dayKey.flatMap(WatchLink.date(fromDayKey:)) ?? at
                    timer.start(title: plan.title, categoryName: plan.category?.name ?? "공부", symbol: plan.symbol,
                                planKey: "\(plan.id.uuidString)_\(day.dayKey)", targetMinutes: minutes, at: at)
                } else {
                    let study = ((try? context?.fetch(FetchDescriptor<PlanCategory>())) ?? [])
                        .filter(\.isStudy).sorted { $0.sortIndex < $1.sortIndex }
                    let title = request.title?.trimmingCharacters(in: .whitespaces) ?? ""
                    timer.start(title: title.isEmpty ? "자유 공부" : String(title.prefix(40)), categoryName: study.first?.name ?? "공부",
                                symbol: study.first?.symbol ?? "book.fill", targetMinutes: minutes, at: at)
                }
            case .pause: timer.pause(at: at)
            case .resume: timer.resume(at: at)
            case .stop:
                timer.stop(at: at)
                AmbientSoundPlayer.shared.stop()
            case .none: break
            }
        case .setPlanDone(let planID, let dayKey, let done):
            guard let context, let id = UUID(uuidString: planID), let day = WatchLink.date(fromDayKey: dayKey) else { break }
            let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
            if let plan = plans.first(where: { $0.id == id }),
               WatchBridgeLogic.needsToggle(isCompleted: plan.isCompleted(on: day), wantDone: done) {
                plan.toggleCompleted(on: day)
                try? context.save()
            }
        case .gradeWord(let wordID, let known):
            guard let context, let id = UUID(uuidString: wordID) else { break }
            let words = (try? context.fetch(FetchDescriptor<Word>())) ?? []
            if let word = words.first(where: { $0.id == id }) {
                let state = WatchBridgeLogic.WordState(reviewStage: word.reviewStage, nextReviewAt: word.nextReviewAt,
                                                       correctCount: word.correctCount, wrongCount: word.wrongCount)
                if let next = WatchBridgeLogic.graded(state, known: known, now: at) {
                    word.reviewStage = next.reviewStage
                    word.nextReviewAt = next.nextReviewAt
                    word.correctCount = next.correctCount
                    word.wrongCount = next.wrongCount
                    try? context.save()
                }
            }
        case .addPlan(let text, let dayKey):
            // 모티 AI가 플랜을 넣는 것과 같은 길 (카테고리 고르기 · 알림 다시 잡기)
            guard let context, let plan = WatchBridgeLogic.quickPlan(String(text.prefix(120)), dayKey: dayKey) else { break }
            if DoitActions.shared.context == nil { DoitActions.shared.context = context }
            _ = DoitActions.shared.addPlan(title: plan.title, dateText: plan.dateText, timeText: plan.timeText,
                                           minutes: plan.minutes, isStudy: plan.isStudy, allDay: plan.timeText == nil, repeatText: nil)
            _ = DoitActions.shared.drainLog()
        case .ask(let text):
            // 인터넷 · 모델 없이 도는 규칙형 모티 엔진으로만 답함
            let question = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
            guard !question.isEmpty else { break }
            if let context {
                StudyTimer.shared.attach(context: context)
                if DoitActions.shared.context == nil { DoitActions.shared.context = context }
            }
            let reply = DoitEngine.respond(to: question, photo: nil)
            _ = DoitActions.shared.drainLog()
            let answer = reply.deferred == nil ? reply.text : "이건 아이폰 모티에게 물어봐 주세요"
            lastAnswer = WatchAnswer(id: command.id, question: question, text: WatchBridgeLogic.shortAnswer(answer))
        case .refresh:
            break
        }
        if let context, !command.isRefresh { WidgetSync.update(context: context) }
        lastSent = nil
    }

    fileprivate func handle(_ message: [String: Any]) -> [String: Any] {
        if let command = WatchCommand.from(message) { apply(command) }
        lastSent = nil
        setNeedsPush(after: .milliseconds(300))
        return makeSnapshot().message
    }
}

private extension WatchCommand {
    var isRefresh: Bool { action == .refresh }
}

// MARK: - WCSessionDelegate (아무 스레드에서나 불려서 메인으로 넘김)

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in WatchBridge.shared.setNeedsPush() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // 다른 워치로 바꾸면 새 워치와 다시 연결
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            WatchBridge.shared.lastSent = nil
            WatchBridge.shared.setNeedsPush()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in
            WatchBridge.shared.lastSent = nil
            WatchBridge.shared.setNeedsPush()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in _ = WatchBridge.shared.handle(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in replyHandler(WatchBridge.shared.handle(message)) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in _ = WatchBridge.shared.handle(userInfo) }
    }
}
