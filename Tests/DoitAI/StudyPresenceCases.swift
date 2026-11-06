import Foundation

// AI 순공부 측정: 상태 · 깜빡임 막기 · 순공부 시간 · 프레임 요약 · 저장 테스트

private let move = PresenceSample(present: true, handInArm: true, nearFace: false, motion: 0.2)
private let still = PresenceSample(present: true, handInArm: true, nearFace: false, motion: 0.0)
private let gone = PresenceSample(present: false, handInArm: false, nearFace: false, motion: 0.0)
private let phone = PresenceSample(present: true, handInArm: false, nearFace: true, motion: 0.3)

/// 샘플을 n초 넣음
private func run(_ engine: inout StudyPresenceEngine, _ sample: PresenceSample, _ seconds: Int) {
    for _ in 0..<seconds { engine.feed(sample) }
}

func runStudyPresenceCases() {
    // 처음엔 준비 중, 움직임이 두 번 보이면 공부 중
    do {
        var e = StudyPresenceEngine()
        check("처음은 준비 중", e.state == .waiting)
        e.feed(move)
        check("움직임 한 번은 아직 준비 중 (깜빡임 막기)", e.state == .waiting && e.netSeconds == 0, "\(e.state) \(e.netSeconds)")
        e.feed(move)
        check("움직임 두 번이면 공부 중", e.state == .studying && e.netSeconds == 1, "\(e.state) \(e.netSeconds)")
        run(&e, move, 8)
        check("계속 쓰면 순공부가 쌓임", e.state == .studying && e.netSeconds == 9, "\(e.netSeconds)")
        check("잰 시간은 10초", e.measuredSeconds == 10)
    }

    // 필기가 잠깐 멈춰도(문제 읽는 중) 멈춤으로 안 바뀜
    do {
        var e = StudyPresenceEngine()
        run(&e, move, 5)
        run(&e, still, 30)
        check("30초 가만히 있어도 공부 중", e.state == .studying, "\(e.state)")
        run(&e, still, 14)
        check("44초 가만히 있어도 아직 공부 중", e.state == .studying, "\(e.state)")
        e.feed(still)
        check("45초 가만히 있으면 멈춤", e.state == .still, "\(e.state)")
        let net = e.netSeconds
        run(&e, still, 20)
        check("멈춤 동안은 순공부 안 늘어남", e.netSeconds == net && e.totals.still >= 20, "\(e.netSeconds) vs \(net)")
        // 다시 쓰기 시작
        e.feed(move)
        check("움직임 한 번으로는 아직 멈춤", e.state == .still)
        e.feed(move)
        check("다시 쓰면 공부 중", e.state == .studying, "\(e.state)")
    }

    // 자리 비움: 10초 넘게 없을 때만
    do {
        var e = StudyPresenceEngine()
        run(&e, move, 10)
        run(&e, gone, 9)
        check("9초 안 보여도 공부 중 (깜빡임 막기)", e.state == .studying, "\(e.state)")
        e.feed(gone)
        check("10초 안 보이면 자리 비움", e.state == .away, "\(e.state)")
        let net = e.netSeconds
        run(&e, gone, 60)
        check("자리 비움 동안 순공부 그대로", e.netSeconds == net, "\(e.netSeconds) vs \(net)")
        check("자리 비움 시간 기록", e.totals.away >= 60, "\(e.totals.away)")
        // 돌아와도 3초는 봐야 풀림
        e.feed(move)
        e.feed(move)
        check("돌아온 직후엔 아직 자리 비움", e.state == .away, "\(e.state)")
        e.feed(move)
        check("3초 보이면 자리 비움 끝, 움직임 있으니 공부 중", e.state == .studying, "\(e.state)")
    }

    // 잠깐 안 보였다가 돌아옴: 상태 유지
    do {
        var e = StudyPresenceEngine()
        run(&e, move, 6)
        run(&e, gone, 3)
        run(&e, move, 3)
        check("잠깐 가려졌다 돌아와도 공부 중", e.state == .studying)
        let flips = e.transitions.filter { $0.to == .away || $0.to == .still }.count
        check("잠깐 가려졌을 때 상태가 바뀌지 않음", flips == 0, "\(e.transitions)")
    }

    // 딴짓: 손이 얼굴 근처 8초 이상
    do {
        var e = StudyPresenceEngine()
        run(&e, move, 6)
        run(&e, phone, 7)
        check("7초는 아직 공부 중", e.state == .studying, "\(e.state)")
        e.feed(phone)
        check("8초 얼굴 근처면 딴짓", e.state == .distracted, "\(e.state)")
        let net = e.netSeconds
        run(&e, phone, 10)
        check("딴짓 동안 순공부 안 늘어남", e.netSeconds == net)
        e.feed(move)
        check("얼굴에서 떨어져도 1초는 딴짓 유지", e.state == .distracted, "\(e.state)")
        e.feed(move)
        e.feed(move)
        check("떨어져서 다시 쓰면 공부 중", e.state == .studying, "\(e.state)")
    }

    // 얼굴 근처가 스쳐 지나가는 건(이마 짚기 등) 딴짓 아님
    do {
        var e = StudyPresenceEngine()
        run(&e, move, 4)
        for _ in 0..<5 {
            run(&e, phone, 3)
            run(&e, move, 2)
        }
        check("얼굴 근처 3초씩 끊기면 딴짓 아님", !e.transitions.contains { $0.to == .distracted }, "\(e.transitions)")
        check("계속 공부 중", e.state == .studying)
    }

    // 팔 칸 밖의 움직임은 공부로 안 침 (휴대폰 · 딴손)
    do {
        var e = StudyPresenceEngine()
        let outside = PresenceSample(present: true, handInArm: false, nearFace: false, motion: 0.5)
        run(&e, outside, 20)
        check("팔 칸 밖 움직임은 공부 아님", e.netSeconds == 0 && e.state == .waiting, "\(e.state) \(e.netSeconds)")
        run(&e, outside, 30)
        check("45초 지나면 멈춤", e.state == .still, "\(e.state)")
    }

    // 작은 흔들림(문턱 아래)은 움직임 아님
    do {
        var e = StudyPresenceEngine()
        let jitter = PresenceSample(present: true, handInArm: true, nearFace: false, motion: 0.01)
        run(&e, jitter, 60)
        check("손 흔들림 정도는 공부 아님", e.netSeconds == 0 && e.state == .still, "\(e.state) \(e.netSeconds)")
    }

    // 순공부 합계와 한계값
    do {
        var e = StudyPresenceEngine()
        run(&e, move, 60)
        run(&e, gone, 70)   // 10초는 유예로 공부 중, 60초는 자리 비움
        let s = e.summary(startedAt: Date(timeIntervalSince1970: 1_000))
        check("합계: 잰 시간 130초", s.measuredSeconds == 130, "\(s.measuredSeconds)")
        check("합계: 순공부 = 60 - 1(처음 대기) + 9 = 68초 안팎", s.netSeconds >= 67 && s.netSeconds <= 70, "\(s.netSeconds)")
        check("합계: 자리 비움 61초 안팎", s.awaySeconds >= 60 && s.awaySeconds <= 62, "\(s.awaySeconds)")
        check("집중도는 순공부/잰 시간", s.focusPercent == Int((Double(s.netSeconds) / 130 * 100).rounded()), "\(s.focusPercent)")
        let c = s.clamped(totalSeconds: 100)
        check("타이머 전체 시간보다 길지 않게 맞춤", c.measuredSeconds == 100 && c.netSeconds <= 100 && c.awaySeconds <= 100, "\(c)")
        let z = PresenceSummary(startedAt: Date(), totals: PresenceTotals()).clamped(totalSeconds: -5)
        check("0초 / 음수는 0으로", z.measuredSeconds == 0 && z.netSeconds == 0 && z.focusPercent == 0)
    }

    // dt 한계: 앱이 멈췄다 돌아와도 한꺼번에 늘어나지 않음
    do {
        var e = StudyPresenceEngine()
        e.feed(move)
        e.feed(move)
        e.feed(move, dt: 600)
        check("dt는 maxStep으로 잘림", e.measuredSeconds <= 2 + Int(PresenceRules.standard.maxStep), "\(e.measuredSeconds)")
        let before = e.measuredSeconds
        e.feed(move, dt: -4)
        e.feed(move, dt: 0)
        check("음수 · 0 시간은 무시", e.measuredSeconds == before)
    }

    // 이어 하기 (앱을 껐다 켠 뒤)
    do {
        var e = StudyPresenceEngine(resuming: PresenceTotals(measured: 600, net: 500, away: 40, still: 30, distracted: 30))
        run(&e, move, 5)
        check("저장한 값에서 이어 셈", e.measuredSeconds == 605 && e.netSeconds >= 503, "\(e.measuredSeconds) \(e.netSeconds)")
    }

    // 프레임 요약: 사람 있음
    do {
        var a = PresenceFrameAnalyzer()
        let nobody = a.observe(PresenceFrame())
        check("프레임: 아무것도 없으면 사람 없음", !nobody.present && !nobody.handInArm)
        let body = PresenceFrame(bodyPoints: [PresencePoint(x: 0.2, y: 0.3), PresencePoint(x: 0.22, y: 0.6)])
        check("프레임: 몸 점 2개가 몸 칸 안이면 사람", a.observe(body).present)
        let far = PresenceFrame(bodyPoints: [PresencePoint(x: 0.9, y: 0.1), PresencePoint(x: 0.92, y: 0.2)])
        check("프레임: 몸 칸 밖의 사람은 아님", !a.observe(far).present)
        let rect = PresenceFrame(humanRects: [PresenceBox(x: 0.1, y: 0.1, w: 0.3, h: 0.8)])
        check("프레임: 사람 사각형 중심이 몸 칸 안이면 사람", a.observe(rect).present)
        let hand = PresenceFrame(wrists: [PresencePoint(x: 0.7, y: 0.7)])
        let h = a.observe(hand)
        check("프레임: 팔 칸 안 손이 보이면 사람 + 손 있음", h.present && h.handInArm)
        let handOut = PresenceFrame(wrists: [PresencePoint(x: 0.1, y: 0.1)])
        check("프레임: 팔 칸 밖 손은 손 없음으로", !a.observe(handOut).handInArm)
    }

    // 프레임 요약: 움직임 · 얼굴 근처
    do {
        var a = PresenceFrameAnalyzer()
        let f1 = a.observe(PresenceFrame(wrists: [PresencePoint(x: 0.70, y: 0.70)], scale: 0.2))
        check("프레임: 첫 프레임은 움직임 0", f1.motion == 0)
        let f2 = a.observe(PresenceFrame(wrists: [PresencePoint(x: 0.70, y: 0.70)], scale: 0.2))
        check("프레임: 같은 자리는 움직임 0", f2.motion < 0.001, "\(f2.motion)")
        let f3 = a.observe(PresenceFrame(wrists: [PresencePoint(x: 0.74, y: 0.70)], scale: 0.2))
        check("프레임: 0.04 이동 / 몸 0.2 = 0.2", abs(f3.motion - 0.2) < 0.01, "\(f3.motion)")
        let big = a.observe(PresenceFrame(wrists: [PresencePoint(x: 0.95, y: 0.70)], scale: 0.2))
        check("프레임: 움직임은 1.5에서 잘림", big.motion <= 1.5)

        var b = PresenceFrameAnalyzer()
        let face = PresencePoint(x: 0.25, y: 0.2)
        let near = b.observe(PresenceFrame(wrists: [PresencePoint(x: 0.3, y: 0.25)], facePoints: [face], scale: 0.2))
        check("프레임: 손목이 얼굴 곁이면 얼굴 근처", near.nearFace)
        let desk = b.observe(PresenceFrame(wrists: [PresencePoint(x: 0.7, y: 0.8)], facePoints: [face], scale: 0.2))
        check("프레임: 책상 위 손은 얼굴 근처 아님", !desk.nearFace)
    }

    // 1초 묶기
    do {
        var g = PresenceAggregator()
        let a = FrameObservation(present: true, handInArm: true, nearFace: false, motion: 0.1)
        let b = FrameObservation(present: false, handInArm: false, nearFace: true, motion: 0.3)
        check("묶기: 같은 초 안에서는 안 나옴", g.add(a, at: 10.0) == nil && g.add(b, at: 10.4) == nil)
        let first = g.add(a, at: 11.1)
        check("묶기: 초가 바뀌면 지난 초 요약이 나옴", first != nil)
        check("묶기: 사람은 한 프레임이라도 있으면 있음", first?.present == true)
        check("묶기: 손 한 프레임이라도 있으면 있음", first?.handInArm == true)
        check("묶기: 움직임은 가장 큰 값", first?.motion == 0.3, "\(String(describing: first?.motion))")
        check("묶기: 얼굴 근처는 절반 넘어야 (1/2는 아님)", first?.nearFace == false)
        _ = g.add(b, at: 11.5)
        _ = g.add(b, at: 11.8)
        let second = g.add(b, at: 12.2)
        check("묶기: 얼굴 근처 프레임이 3중 2면 얼굴 근처", second?.nearFace == true && second?.present == true, "\(String(describing: second))")
        // 프레임이 끊긴 구간은 샘플을 만들지 않음
        var h = PresenceAggregator()
        _ = h.add(a, at: 1.0)
        let gap = h.add(a, at: 30.0)
        check("묶기: 끊긴 시간은 한 초로만 침", gap != nil)
        h.reset()
        check("묶기: reset 뒤에는 이전 초가 안 나옴", h.add(a, at: 100.0) == nil)
    }

    // 프레임 → 엔진: 필기 시나리오 (3fps)
    do {
        var analyzer = PresenceFrameAnalyzer()
        var agg = PresenceAggregator()
        var engine = StudyPresenceEngine()
        var t = 0.0
        // 20초 필기: 손목이 좌우로 0.02씩 움직임, 몸 보임
        for i in 0..<60 {
            let x = 0.70 + (i % 2 == 0 ? 0.0 : 0.02)
            let frame = PresenceFrame(wrists: [PresencePoint(x: x, y: 0.7)],
                                      facePoints: [PresencePoint(x: 0.2, y: 0.2)],
                                      bodyPoints: [PresencePoint(x: 0.2, y: 0.35), PresencePoint(x: 0.22, y: 0.7)],
                                      scale: 0.2)
            if let s = agg.add(analyzer.observe(frame), at: t) { engine.feed(s) }
            t += 1.0 / 3
        }
        check("필기 시나리오: 공부 중", engine.state == .studying, "\(engine.state)")
        check("필기 시나리오: 순공부 17초 이상", engine.netSeconds >= 17, "\(engine.netSeconds)")
        // 15초 자리 비움: 아무것도 안 보임
        for _ in 0..<45 {
            if let s = agg.add(analyzer.observe(PresenceFrame()), at: t) { engine.feed(s) }
            t += 1.0 / 3
        }
        check("자리 비움 시나리오: 자리 비움", engine.state == .away, "\(engine.state)")
    }

    // 저장소
    do {
        let suite = "study.presence.test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            check("저장소: 테스트용 저장소 만들기", false)
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PresenceStore(defaults: defaults)
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let a = PresenceSummary(startedAt: day, totals: PresenceTotals(measured: 3600, net: 3120, away: 300, still: 120, distracted: 60))
        let b = PresenceSummary(startedAt: day.addingTimeInterval(7200), totals: PresenceTotals(measured: 1800, net: 1500, away: 0, still: 300, distracted: 0))
        store.save(a)
        store.save(b)
        check("저장소: 시작 시각으로 찾기", store.summary(forStart: day)?.netSeconds == 3120)
        check("저장소: 집중도 87%", store.summary(forStart: day)?.focusPercent == 87, "\(String(describing: store.summary(forStart: day)?.focusPercent))")
        var a2 = a
        a2.netSeconds = 3000
        store.save(a2)
        check("저장소: 같은 공부는 덮어씀", store.records().count == 2 && store.summary(forStart: day)?.netSeconds == 3000)
        let total = store.totals(from: day.addingTimeInterval(-10), to: day.addingTimeInterval(86_400))
        check("저장소: 기간 합계", total.net == 4500 && total.measured == 5400 && total.count == 2, "\(total)")
        let none = store.totals(from: day.addingTimeInterval(86_400), to: day.addingTimeInterval(172_800))
        check("저장소: 기간 밖은 0", none.count == 0 && none.net == 0)
        check("저장소: 없는 기록은 nil", store.summary(forStart: day.addingTimeInterval(1)) == nil)
        store.saveLive(b)
        check("저장소: 진행 중 값 읽기", store.live() == b)
        store.clearLive()
        check("저장소: 진행 중 값 지우기", store.live() == nil)
        for i in 0..<(PresenceStore.maxRecords + 5) {
            store.save(PresenceSummary(startedAt: day.addingTimeInterval(Double(10_000 + i * 60)), totals: PresenceTotals(measured: 60, net: 30)))
        }
        check("저장소: 오래된 기록은 정리", store.records().count == PresenceStore.maxRecords, "\(store.records().count)")
    }

    // 글자
    do {
        check("글자: 52초", PresenceText.clock(52) == "0:52")
        check("글자: 42분 10초", PresenceText.clock(42 * 60 + 10) == "42:10")
        check("글자: 1시간 5분 10초", PresenceText.clock(3600 + 5 * 60 + 10) == "1:05:10")
        check("글자: 음수는 0:00", PresenceText.clock(-3) == "0:00")
        check("글자: 칩 공부 중", PresenceText.chip(state: .studying, netSeconds: 42 * 60 + 10) == "공부 중 · 순공부 42:10")
        check("글자: 칩 자리 비움", PresenceText.chip(state: .away, netSeconds: 100) == "자리 비움")
        let s = PresenceSummary(startedAt: Date(), totals: PresenceTotals(measured: 3600, net: 3120))
        check("글자: 결과 줄", PresenceText.result(totalSeconds: 3600, summary: s) == "총 1:00 · 순공부 0:52 · 집중도 87%", PresenceText.result(totalSeconds: 3600, summary: s))
        let short = PresenceSummary(startedAt: Date(), totals: PresenceTotals(measured: 57, net: 40, away: 0, still: 17, distracted: 0))
        check("글자: 1분 안 되는 공부는 초로", PresenceText.result(totalSeconds: 57, summary: short) == "총 57초 · 순공부 40초 · 집중도 70%", PresenceText.result(totalSeconds: 57, summary: short))
        check("글자: 시간:분", PresenceText.hm(3 * 3600 + 7 * 60 + 59) == "3:07" && PresenceText.hm(30) == "0:00" && PresenceText.hm(-1) == "0:00")
        let parts = PresenceSummary(startedAt: Date(), totals: PresenceTotals(measured: 3600, net: 3000, away: 300, still: 200, distracted: 30))
        check("글자: 나머지 시간 (1분 안 되는 건 뺌)", PresenceText.breakdown(parts) == "자리 비움 5분 · 멈춤 3분", PresenceText.breakdown(parts))
    }

    // 가이드 칸
    do {
        let l = PresenceLayout.standard
        check("칸: 몸 칸은 왼쪽", l.body.center.x < 0.5 && l.arm.center.x > 0.5)
        let m = l.mirrored
        check("칸: 뒤집으면 몸 칸이 오른쪽", m.body.center.x > 0.5 && m.arm.center.x < 0.5)
        check("칸: 두 번 뒤집으면 원래대로", abs(m.mirrored.body.x - l.body.x) < 1e-9 && abs(m.mirrored.arm.w - l.arm.w) < 1e-9)
        check("칸: make(flipped:)", PresenceLayout.make(flipped: true) == m && PresenceLayout.make(flipped: false) == l)
        let boxes: [PresenceBox] = [l.body, l.arm, m.body, m.arm]
        var inside = true
        for box in boxes {
            let right: Double = box.x + box.w
            let bottom: Double = box.y + box.h
            if box.x < 0 || box.y < 0 || right > 1 || bottom > 1 { inside = false }
        }
        check("칸: 모두 0...1 안", inside)
        check("칸: 상태 이름", StudyPresenceState.allCases.map(\.label) == ["준비 중", "공부 중", "멈춤", "딴짓", "자리 비움"])
    }
}
