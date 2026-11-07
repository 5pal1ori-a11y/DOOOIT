import Foundation

// 배지 · AI 모의고사 · 집중 사운드 섞기 (화면 없이 계산만)

func runBadgeCases() {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: today)! }

    // 연속 일수: 가장 긴 구간 (같은 날 여러 번은 하루)
    check("배지: 연속 없음", BadgeBook.bestStreak(days: []) == 0)
    check("배지: 하루", BadgeBook.bestStreak(days: [day(0), day(0).addingTimeInterval(3600)]) == 1)
    let streakDays = [day(-10), day(-9), day(-8), day(-5), day(-4), day(-3), day(-2), day(-1)]
    check("배지: 가장 긴 연속", BadgeBook.bestStreak(days: streakDays) == 5, "\(BadgeBook.bestStreak(days: streakDays))")

    // 다시 맞힘: 오답 다음 정답마다 1
    check("배지: 다시 맞힘", BadgeBook.fixedCount([false, true, true, false, false, true, false]) == 2)
    check("배지: 처음부터 정답은 다시 맞힘 아님", BadgeBook.fixedCount([true, true]) == 0)

    // 모의고사 만점: 10문제 이상 다 맞힘
    let mock = BadgeBook.mockCounts([(10, 10), (7, 10), (3, 3), (0, 0)])
    check("배지: 모의고사 횟수", mock.taken == 3 && mock.perfect == 1, "\(mock)")

    // 받기 · 진행률 · 다음 배지
    var stats = BadgeBook.Stats()
    stats.bestStreak = 7
    stats.totalSeconds = 12 * 3600
    stats.learnedWords = 40
    stats.aiSolves = 1
    var result = BadgeBook.refresh(stats: stats, unlocked: [:], now: today)
    let ids = Set(result.new.map(\.id))
    check("배지: 새로 받음", ids == ["streak3", "streak7", "hours10", "firstAI"], "\(ids.sorted())")
    check("배지: 날짜 기록", result.unlocked["streak7"] == today)
    let again = BadgeBook.refresh(stats: stats, unlocked: result.unlocked, now: day(1))
    check("배지: 두 번 축하하지 않음", again.new.isEmpty && again.unlocked["streak7"] == today)
    // 기록이 줄어도 받은 배지는 그대로
    stats.bestStreak = 1
    result = BadgeBook.refresh(stats: stats, unlocked: result.unlocked, now: day(2))
    check("배지: 한 번 받으면 유지", result.unlocked["streak3"] != nil && result.new.isEmpty)
    let words100 = BadgeBook.badge("words100")!
    check("배지: 진행률", abs(words100.progress(stats) - 0.4) < 1e-9 && words100.progressText(stats) == "40 / 100개", words100.progressText(stats))
    check("배지: 다음 배지는 가장 가까운 것", BadgeBook.next(stats: stats, unlocked: result.unlocked)?.id == "words100" || BadgeBook.next(stats: stats, unlocked: result.unlocked)?.id == "day3h",
          BadgeBook.next(stats: stats, unlocked: result.unlocked)?.id ?? "-")
    check("배지: 최근 배지", BadgeBook.latest(unlocked: ["streak3": day(-3), "hours10": day(-1)])?.id == "hours10")
    check("배지: 15~30개", (15...30).contains(BadgeBook.all.count), "\(BadgeBook.all.count)")
    check("배지: 아이디 겹치지 않음", Set(BadgeBook.all.map(\.id)).count == BadgeBook.all.count)
}

func runSoundMixCases() {
    var mix = SoundMix()
    check("소리: 처음엔 꺼짐", mix.isEmpty && mix.gain(.rain) == 0)
    mix.toggle(.rain)
    mix.toggle(.cafe)
    check("소리: 여러 개 켜기", mix.isOn(.rain) && mix.isOn(.cafe) && mix.activeKinds == [.rain, .cafe])
    mix.setLevel(.cafe, 0.5)
    mix.setMaster(0.8)
    check("소리: 음량 = 소리 × 전체", abs(mix.gain(.cafe) - 0.4) < 1e-6 && abs(mix.gain(.rain) - SoundMix.defaultLevel * 0.8) < 1e-6)
    mix.setLevel(.rain, 3)
    check("소리: 음량 범위", mix.level(.rain) == 1)
    mix.toggle(.rain)
    check("소리: 끄면 0, 음량은 기억", mix.gain(.rain) == 0 && mix.level(.rain) == 1)
    for kind in [SoundKind.waves, .fire, .forest, .clock, .library] { mix.toggle(kind) }
    check("소리: 최대 \(SoundMix.maxOn)개 (먼저 켠 것부터 끔)", mix.on.count == SoundMix.maxOn && !mix.isOn(.cafe), "\(mix.on)")
    let restored = SoundMix.decode(mix.encoded())
    check("소리: 저장 · 불러오기", restored == mix)
    let broken = SoundMix.decode(#"{"levels":{},"on":["rain","nope"],"master":4}"#.data(using: .utf8))
    check("소리: 모르는 소리 버림", broken.on == ["rain"] && broken.master == 1)
    check("소리: 저장 없으면 기본", SoundMix.decode(nil) == SoundMix())
    mix.setLevel(.waves, 0)
    mix.toggle(.waves); mix.toggle(.waves)
    check("소리: 0으로 내린 소리를 다시 켜면 들림", mix.level(.waves) > 0.05)

    // 소리 만들기: 켠 소리만 나고, 모두 -1...1, 소리마다 실제로 들림
    let rate: Float = 22_050
    let quiet = AmbientSynth(sampleRate: rate)
    var silent = true
    for _ in 0..<2_000 where quiet.next() != 0 { silent = false }
    check("소리: 아무것도 안 켜면 조용", silent)
    for kind in SoundKind.allCases {
        let synth = AmbientSynth(sampleRate: rate)
        synth.set(kind, 1)
        var sum: Float = 0, peak: Float = 0, finite = true
        let frames = Int(rate * 5)
        for _ in 0..<frames {
            let x = synth.next()
            if !x.isFinite { finite = false }
            sum += x * x
            peak = max(peak, abs(x))
        }
        let rms = (sum / Float(frames)).squareRoot()
        check("소리 \(kind.title): 들리고 찢어지지 않음", finite && peak <= 1 && rms > 0.003, "rms \(rms) peak \(peak)")
    }
    // 여러 개를 크게 섞어도 -1...1
    let loud = AmbientSynth(sampleRate: rate)
    for kind in SoundKind.allCases { loud.set(kind, 1) }
    var over = false
    for _ in 0..<Int(rate * 2) where abs(loud.next()) > 1 { over = true }
    check("소리: 모두 섞어도 넘치지 않음", !over)
    check("소리: 리미터는 작은 소리를 그대로", AmbientSynth.limit(0.3) == 0.3 && AmbientSynth.limit(5) <= 1 && AmbientSynth.limit(5) > 0.9 && AmbientSynth.limit(-5) >= -1)
}

func runMockExamCases() {
    let weak = [
        MockExamSource(key: "공통수학1|복소수와 이차방정식|근과 계수의 관계", subject: "공통수학1", unit: "복소수와 이차방정식",
                       concept: "근과 계수의 관계", problem: "x² - 5x + 6 = 0 의 두 근을 α, β라 할 때, α² + β² 의 값은?", mastery: 0.25, wrongCount: 3),
        MockExamSource(key: "영어|to부정사|too ~ to 구문", subject: "영어", unit: "to부정사", concept: "too ~ to 구문", mastery: 0.35, wrongCount: 2),
        MockExamSource(key: "중학교 수학|일차함수|x절편", subject: "중학교 수학", unit: "일차함수", concept: "x절편 · y절편", mastery: 0.5, wrongCount: 1),
        MockExamSource(key: "공통수학1|인수분해|인수분해", subject: "공통수학1", unit: "인수분해", concept: "인수분해", mastery: 0.4, wrongCount: 2)
    ]
    check("모의고사: 과목 목록", DoitMockExam.subjects(in: weak) == [.math, .english], "\(DoitMockExam.subjects(in: weak))")
    check("모의고사: 약한 순서", DoitMockExam.ordered(weak).first?.unit == "복소수와 이차방정식")

    for round in 0..<3 {
        let exam = DoitMockExam.assemble(weak: weak, recent: [MockExamSource(subject: "공통영어", unit: "관계사")])
        let qs = exam.questions
        check("모의고사 \(round): 10문제", qs.count == 10, "\(qs.count)")
        check("모의고사 \(round): 겹치는 문제 없음", Set(qs.map { DoitPractice.questionKey($0.item.question) }).count == qs.count)
        check("모의고사 \(round): 객관식 · 단답 섞임", qs.contains { $0.isChoice } && qs.contains { !$0.isChoice },
              qs.map { $0.item.kind.rawValue }.joined(separator: ","))
        check("모의고사 \(round): 취약 개념으로", qs.filter { !$0.sourceKey.isEmpty }.count >= 7 && !exam.usedFallback,
              "\(qs.filter { !$0.sourceKey.isEmpty }.count)")
        // 정답을 넣으면 정답, 다른 답이면 오답
        for q in qs {
            check("모의고사 \(round): 정답 채점 · \(q.item.question.prefix(30))", DoitMockExam.isCorrect(q, answer: q.item.answer), q.item.answer)
            check("모의고사 \(round): 빈 답은 오답", !DoitMockExam.isCorrect(q, answer: " "))
            let wrong = q.isChoice ? "\(Int(q.item.answer)! % q.item.choices.count + 1)" : "가나다라123"
            check("모의고사 \(round): 틀린 답은 오답 · \(q.item.question.prefix(30))", !DoitMockExam.isCorrect(q, answer: wrong), wrong)
            check("모의고사 \(round): 해설 있음", !q.item.explanation.isEmpty)
        }
    }

    // 과목만
    let english = DoitMockExam.assemble(weak: weak, scope: .english)
    check("모의고사: 영어만", english.questions.count == 10 && english.questions.allSatisfy { NoteSubject.from($0.subject) == .english },
          english.questions.map(\.subject).joined(separator: ","))
    check("모의고사: 영어 취약 개념이 적으면 다른 단원도", english.usedFallback)
    let math = DoitMockExam.assemble(weak: weak, scope: .math)
    check("모의고사: 수학만", math.questions.count == 10 && math.questions.allSatisfy { NoteSubject.from($0.subject) == .math })

    // 취약 개념이 없을 때: 교육과정 단원으로
    let empty = DoitMockExam.assemble(weak: [])
    check("모의고사: 취약 개념 없음 → 교육과정", empty.questions.count == 10 && empty.usedFallback, "\(empty.questions.count)")

    // 점수 묶기
    let qs = DoitMockExam.assemble(weak: weak).questions
    let results = qs.indices.map { $0 % 3 != 0 }
    let groups = DoitMockExam.groups(qs, results: results)
    check("모의고사: 단원별 점수 합", groups.reduce(0) { $0 + $1.total } == qs.count && groups.reduce(0) { $0 + $1.correct } == results.filter { $0 }.count)
    check("모의고사: 기록 과목 이름", groups.allSatisfy { ["수학", "영어", "국어", "과학", "사회", "기타"].contains($0.subject) }, groups.map(\.subject).joined(separator: ","))
    let ox = PracticeItem(level: 2, kind: .multipleChoice, question: "q", choices: ["O", "X"], answer: "2", explanation: ["e"], concept: "c")
    check("모의고사: 정답 글", DoitMockExam.answerText(ox) == "② X")
    check("모의고사: 한마디", DoitMockExam.cheer(correct: 10, total: 10).contains("만점"))
}
