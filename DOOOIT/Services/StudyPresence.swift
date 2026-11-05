import Foundation

// AI 순공부 측정: 순수 계산 부분 (카메라 · Vision 없이 Foundation만 씀 → 리눅스 테스트에서 그대로 돌려 봄)
//
// 흐름: Vision이 프레임마다 뽑은 점(손목 · 얼굴 · 몸) → PresenceFrame
//       → PresenceFrameAnalyzer가 프레임마다 "사람 있음 · 손이 팔 칸 안 · 움직임 · 얼굴 근처" 요약
//       → PresenceAggregator가 1초마다 PresenceSample 하나로 묶음
//       → StudyPresenceEngine이 상태(공부 중 · 멈춤 · 딴짓 · 자리 비움)와 순공부 초를 셈
// 영상은 어디에도 저장하지 않고, 여기서 나오는 것은 초 단위 숫자뿐이에요.

// MARK: - 좌표 · 가이드 칸

/// 사진 속 위치 (0...1, 왼쪽 위가 원점)
struct PresencePoint: Equatable, Codable {
    var x: Double
    var y: Double

    func distance(to other: PresencePoint) -> Double {
        let dx = x - other.x, dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// 가이드 칸 (0...1, 왼쪽 위가 원점)
struct PresenceBox: Equatable, Codable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    var center: PresencePoint { PresencePoint(x: x + w / 2, y: y + h / 2) }

    /// margin만큼 바깥까지 넉넉하게 안으로 쳐 줌
    func contains(_ p: PresencePoint, margin: Double = 0) -> Bool {
        p.x >= x - margin && p.x <= x + w + margin && p.y >= y - margin && p.y <= y + h + margin
    }

    /// 좌우를 뒤집은 칸
    var mirrored: PresenceBox { PresenceBox(x: 1 - x - w, y: y, w: w, h: h) }
}

/// 몸 칸 + 팔 칸 (옆에서 가로로 찍은 화면 기준)
struct PresenceLayout: Equatable, Codable {
    var body: PresenceBox
    var arm: PresenceBox

    /// 기본 배치: 몸은 왼쪽, 팔(책상 위 손)은 오른쪽 아래
    static let standard = PresenceLayout(
        body: PresenceBox(x: 0.04, y: 0.06, w: 0.42, h: 0.88),
        arm: PresenceBox(x: 0.40, y: 0.42, w: 0.56, h: 0.52)
    )

    /// 사람이 반대쪽에 앉았을 때
    var mirrored: PresenceLayout { PresenceLayout(body: body.mirrored, arm: arm.mirrored) }

    static func make(flipped: Bool) -> PresenceLayout { flipped ? standard.mirrored : standard }
}

// MARK: - 규칙 (숫자는 모두 여기서 바꿈)

struct PresenceRules: Equatable {
    /// 손목이 이만큼(몸 크기 대비 비율) 움직여야 "움직임"
    var motionThreshold = 0.04
    /// 몸 크기를 못 잴 때 쓰는 기준 길이 (사진 너비 대비)
    var defaultScale = 0.25
    /// 사진 너비의 이 비율 안쪽으로 얼굴과 손목이 가까우면 "얼굴 근처" (몸 크기 대비)
    var faceDistance = 0.45
    /// 몸 칸에 사람이 없는 채로 이만큼 지나면 자리 비움
    var awayAfter = 10.0
    /// 자리 비움에서 돌아오려면 이만큼 계속 보여야 함
    var returnConfirm = 3.0
    /// 사람은 있는데 팔 칸에서 움직임이 없는 채로 이만큼 지나면 멈춤
    var stillAfter = 45.0
    /// 손이 얼굴 근처에 이만큼 계속 있으면 딴짓 (휴대폰 보는 자세)
    var distractedAfter = 8.0
    /// 딴짓에서 벗어나려면 얼굴에서 이만큼 떨어져 있어야 함
    var distractedExit = 2.0
    /// 멈춤 · 자리 비움 · 딴짓에서 공부 중으로 돌아오려면: 최근 entryWindow초 안에 움직인 초가 entryCount번 이상
    var entryWindow = 4
    var entryCount = 2
    /// 한 번에 세는 시간의 최대 (앱이 멈췄다 돌아와도 한꺼번에 늘어나지 않게)
    var maxStep = 3.0
    /// 숨은 프레임 하나가 이 비율 이상 얼굴 근처면 그 초는 얼굴 근처
    var faceMajority = 0.5

    static let standard = PresenceRules()
}

// MARK: - 프레임 → 1초 요약

/// Vision이 한 프레임에서 뽑은 점들 (모두 PresenceLayout과 같은 좌표)
struct PresenceFrame: Equatable {
    /// 손목 (몸 자세 + 손 자세에서 나온 것 모두)
    var wrists: [PresencePoint] = []
    /// 코 · 귀 · 눈
    var facePoints: [PresencePoint] = []
    /// 어깨 · 목 · 엉덩이 등 몸 점
    var bodyPoints: [PresencePoint] = []
    /// 사람 사각형 (VNDetectHumanRectangles)
    var humanRects: [PresenceBox] = []
    /// 몸 크기 (어깨 너비 등, 사진 너비 대비). 모르면 nil
    var scale: Double?
}

/// 프레임 하나를 요약한 값
struct FrameObservation: Equatable {
    var present: Bool
    var handInArm: Bool
    var nearFace: Bool
    /// 팔 칸 안 손목의 이동량 (몸 크기 대비)
    var motion: Double
}

/// 프레임마다 "사람 있음 · 손 위치 · 움직임 · 얼굴 근처"를 판단 (이전 프레임의 손목을 기억)
struct PresenceFrameAnalyzer {
    var layout: PresenceLayout
    var rules: PresenceRules
    private var previousWrists: [PresencePoint] = []

    init(layout: PresenceLayout = .standard, rules: PresenceRules = .standard) {
        self.layout = layout
        self.rules = rules
    }

    mutating func reset() { previousWrists = [] }

    mutating func observe(_ frame: PresenceFrame) -> FrameObservation {
        let scale = min(max(frame.scale ?? rules.defaultScale, 0.08), 0.6)
        let armWrists = frame.wrists.filter { layout.arm.contains($0, margin: 0.03) }
        let handInArm = !armWrists.isEmpty

        // 움직임: 팔 칸 안 손목마다 이전 프레임에서 가장 가까운 손목과의 거리 (가장 큰 값)
        var motion = 0.0
        if !previousWrists.isEmpty {
            for wrist in armWrists {
                if let nearest = previousWrists.map({ wrist.distance(to: $0) }).min() {
                    motion = max(motion, min(nearest / scale, 1.5))
                }
            }
        }
        previousWrists = frame.wrists

        // 얼굴 근처: 손목이 코 · 귀에서 몸 크기의 faceDistance 안
        var nearFace = false
        outer: for wrist in frame.wrists {
            for face in frame.facePoints where wrist.distance(to: face) <= rules.faceDistance * scale {
                nearFace = true
                break outer
            }
        }

        return FrameObservation(present: Self.isPersonPresent(frame, layout: layout, handInArm: handInArm),
                                handInArm: handInArm, nearFace: nearFace, motion: motion)
    }

    /// 몸 칸 안에 사람이 있는지: 몸 점 2개 이상 · 사람 사각형 중심 · (몸이 안 보여도) 팔 칸 안 손
    static func isPersonPresent(_ frame: PresenceFrame, layout: PresenceLayout, handInArm: Bool) -> Bool {
        if handInArm { return true }
        let insideBody = frame.bodyPoints.filter { layout.body.contains($0, margin: 0.04) }.count
        if insideBody >= 2 { return true }
        if frame.humanRects.contains(where: { layout.body.contains($0.center, margin: 0.1) }) { return true }
        // 얼굴 점만 보여도 몸 칸 안이면 사람
        if frame.facePoints.contains(where: { layout.body.contains($0, margin: 0.04) }) { return true }
        return false
    }
}

/// 1초 요약
struct PresenceSample: Equatable {
    var present: Bool
    var handInArm: Bool
    var nearFace: Bool
    var motion: Double
}

/// 프레임 요약을 1초씩 묶어서 PresenceSample로 (프레임이 한 장도 없는 초는 만들지 않음 → 세지도 않음)
struct PresenceAggregator {
    var rules: PresenceRules
    private var second: Int?
    private var frames = 0
    private var presentFrames = 0
    private var armFrames = 0
    private var faceFrames = 0
    private var motion = 0.0

    init(rules: PresenceRules = .standard) { self.rules = rules }

    mutating func reset() {
        second = nil
        clear()
    }

    private mutating func clear() {
        frames = 0; presentFrames = 0; armFrames = 0; faceFrames = 0; motion = 0
    }

    /// t: 프레임 시각(초). 끝난 1초가 있으면 그 요약을 돌려줌
    mutating func add(_ obs: FrameObservation, at t: TimeInterval) -> PresenceSample? {
        let sec = Int(t.rounded(.down))
        var finished: PresenceSample?
        if let current = second, sec != current {
            finished = closeBucket()
        }
        second = sec
        frames += 1
        if obs.present { presentFrames += 1 }
        if obs.handInArm { armFrames += 1 }
        if obs.nearFace { faceFrames += 1 }
        motion = max(motion, obs.motion)
        return finished
    }

    private mutating func closeBucket() -> PresenceSample? {
        defer { clear() }
        guard frames > 0 else { return nil }
        return PresenceSample(
            present: presentFrames > 0,
            handInArm: armFrames > 0,
            nearFace: Double(faceFrames) / Double(frames) > rules.faceMajority,
            motion: motion
        )
    }
}

// MARK: - 상태

enum StudyPresenceState: String, Codable, CaseIterable {
    /// 막 시작: 아직 손 움직임을 못 봄
    case waiting
    case studying
    /// 사람은 있는데 손이 한참 안 움직임
    case still
    /// 손이 얼굴 근처 (휴대폰 보는 자세)
    case distracted
    /// 몸 칸에 사람이 없음
    case away

    /// 화면에 보이는 짧은 이름
    var label: String {
        switch self {
        case .waiting: "준비 중"
        case .studying: "공부 중"
        case .still: "멈춤"
        case .distracted: "딴짓"
        case .away: "자리 비움"
        }
    }

    var countsAsStudy: Bool { self == .studying }
}

struct StudyPresenceTransition: Equatable {
    /// 측정을 시작하고 몇 초째인지
    var at: Double
    var from: StudyPresenceState
    var to: StudyPresenceState
}

/// 상태별로 모은 시간(초)
struct PresenceTotals: Equatable, Codable {
    var measured = 0.0
    var net = 0.0
    var away = 0.0
    var still = 0.0
    var distracted = 0.0
}

// MARK: - 엔진

/// 1초 요약을 받아 상태를 바꾸고 순공부 시간을 셈
/// - 공부 중: 사람이 있고 + 팔 칸에서 손이 최근에 움직임 (필기 · 책장 넘기기)
/// - 자리 비움: 몸 칸에 사람이 awayAfter초 넘게 없음
/// - 멈춤: 사람은 있는데 움직임이 stillAfter초 넘게 없음
/// - 딴짓: 손이 얼굴 근처에 distractedAfter초 넘게 있음
/// 상태가 바뀌려면 위의 시간이 지나야 해서 깜빡임이 없고, 공부 중으로 돌아올 때는 움직임이 두 번은 보여야 해요.
struct StudyPresenceEngine {
    let rules: PresenceRules
    private(set) var state: StudyPresenceState = .waiting
    private(set) var totals = PresenceTotals()
    private(set) var transitions: [StudyPresenceTransition] = []

    private var absentRun = 0.0
    private var presentRun = 0.0
    private var faceRun = 0.0
    private var notFaceRun = 0.0
    private var sinceMotion = 0.0
    private var recentMotion: [Bool] = []

    init(rules: PresenceRules = .standard, resuming totals: PresenceTotals = PresenceTotals()) {
        self.rules = rules
        self.totals = totals
    }

    var netSeconds: Int { Int(totals.net) }
    var measuredSeconds: Int { Int(totals.measured) }

    /// 1초 요약 하나를 넣음. dt: 이 요약이 덮는 시간(초, 보통 1). 바뀐 뒤 상태를 돌려줌
    @discardableResult
    mutating func feed(_ sample: PresenceSample, dt: Double = 1) -> StudyPresenceState {
        let step = min(max(dt, 0), rules.maxStep)
        guard step > 0 else { return state }

        // 연속 시간 세기
        if sample.present {
            absentRun = 0
            presentRun += step
        } else {
            absentRun += step
            presentRun = 0
        }
        if sample.present && sample.nearFace {
            faceRun += step
            notFaceRun = 0
        } else {
            faceRun = 0
            notFaceRun += step
        }
        let moving = sample.present && sample.handInArm && sample.motion >= rules.motionThreshold
        if moving { sinceMotion = 0 } else { sinceMotion += step }
        recentMotion.append(moving)
        if recentMotion.count > rules.entryWindow { recentMotion.removeFirst(recentMotion.count - rules.entryWindow) }

        let next = nextState(moving: moving)
        if next != state {
            transitions.append(StudyPresenceTransition(at: totals.measured, from: state, to: next))
            if transitions.count > 200 { transitions.removeFirst(transitions.count - 200) }
            state = next
        }

        // 시간 쌓기
        totals.measured += step
        switch state {
        case .studying: totals.net += step
        case .away: totals.away += step
        case .still: totals.still += step
        case .distracted: totals.distracted += step
        case .waiting: break
        }
        return state
    }

    private func nextState(moving: Bool) -> StudyPresenceState {
        // 자리 비움
        if absentRun >= rules.awayAfter { return .away }
        if state == .away && presentRun < rules.returnConfirm { return .away }
        // 잠깐 안 보인 것(awayAfter 전)은 상태를 그대로 둠
        if absentRun > 0 { return state }
        // 딴짓
        if faceRun >= rules.distractedAfter { return .distracted }
        if state == .distracted && notFaceRun < rules.distractedExit { return .distracted }

        if state == .studying {
            return sinceMotion >= rules.stillAfter ? .still : .studying
        }
        // 멈춤 · 대기 · 딴짓/자리 비움에서 나온 직후: 최근 움직임이 충분해야 공부 중
        if recentMotion.filter({ $0 }).count >= rules.entryCount { return .studying }
        if state == .waiting { return sinceMotion >= rules.stillAfter ? .still : .waiting }
        return .still
    }

    /// 지금까지의 결과 (타이머 총 시간보다 길지 않게 맞춰 돌려줌)
    func summary(startedAt: Date, totalSeconds: Int? = nil) -> PresenceSummary {
        PresenceSummary(startedAt: startedAt, totals: totals).clamped(totalSeconds: totalSeconds)
    }
}

// MARK: - 결과 · 저장

/// 공부 한 번의 측정 결과 (초 단위 숫자만, 영상 · 사진은 없음)
struct PresenceSummary: Equatable, Codable {
    var startedAt: Date
    var measuredSeconds: Int
    var netSeconds: Int
    var awaySeconds: Int
    var stillSeconds: Int
    var distractedSeconds: Int

    init(startedAt: Date, totals: PresenceTotals) {
        self.startedAt = startedAt
        measuredSeconds = Int(totals.measured)
        netSeconds = Int(totals.net)
        awaySeconds = Int(totals.away)
        stillSeconds = Int(totals.still)
        distractedSeconds = Int(totals.distracted)
    }

    /// 순공부 시간 / 잰 시간 (%, 잰 시간이 0이면 0)
    var focusPercent: Int {
        guard measuredSeconds > 0 else { return 0 }
        return min(100, Int((Double(netSeconds) / Double(measuredSeconds) * 100).rounded()))
    }

    /// 타이머 전체 시간을 넘지 않게
    func clamped(totalSeconds: Int?) -> PresenceSummary {
        var copy = self
        copy.netSeconds = max(0, copy.netSeconds)
        copy.measuredSeconds = max(copy.measuredSeconds, copy.netSeconds)
        if let total = totalSeconds {
            let cap = max(0, total)
            copy.measuredSeconds = min(copy.measuredSeconds, cap)
            copy.netSeconds = min(copy.netSeconds, copy.measuredSeconds)
            copy.awaySeconds = min(copy.awaySeconds, copy.measuredSeconds)
            copy.stillSeconds = min(copy.stillSeconds, copy.measuredSeconds)
            copy.distractedSeconds = min(copy.distractedSeconds, copy.measuredSeconds)
        }
        return copy
    }

    var totals: PresenceTotals {
        PresenceTotals(measured: Double(measuredSeconds), net: Double(netSeconds), away: Double(awaySeconds),
                       still: Double(stillSeconds), distracted: Double(distractedSeconds))
    }
}

/// 공부 기록(StudySession)과 따로 두는 가벼운 저장소: 공부를 시작한 시각(초)이 열쇠.
/// 기록의 seconds는 그대로 두고, AI가 잰 순공부 시간만 여기에 둠.
struct PresenceStore {
    private let defaults: UserDefaults
    private let recordsKey: String
    private let liveKey: String
    static let maxRecords = 800

    init(defaults: UserDefaults = .standard, keyPrefix: String = "study.presence") {
        self.defaults = defaults
        recordsKey = keyPrefix + ".records"
        liveKey = keyPrefix + ".live"
    }

    static func key(for start: Date) -> Int { Int(start.timeIntervalSince1970) }

    // 끝난 기록

    func records() -> [PresenceSummary] {
        guard let data = defaults.data(forKey: recordsKey),
              let list = try? JSONDecoder().decode([PresenceSummary].self, from: data) else { return [] }
        return list
    }

    func save(_ summary: PresenceSummary) {
        var list = records().filter { Self.key(for: $0.startedAt) != Self.key(for: summary.startedAt) }
        list.append(summary)
        list.sort { $0.startedAt < $1.startedAt }
        if list.count > Self.maxRecords { list.removeFirst(list.count - Self.maxRecords) }
        if let data = try? JSONEncoder().encode(list) { defaults.set(data, forKey: recordsKey) }
    }

    func summary(forStart start: Date) -> PresenceSummary? {
        records().first { Self.key(for: $0.startedAt) == Self.key(for: start) }
    }

    /// [from, to) 안에서 시작한 공부의 순공부 · 잰 시간 합 (주간 리포트용)
    func totals(from: Date, to: Date) -> (net: Int, measured: Int, count: Int) {
        let hits = records().filter { $0.startedAt >= from && $0.startedAt < to }
        return (hits.reduce(0) { $0 + $1.netSeconds }, hits.reduce(0) { $0 + $1.measuredSeconds }, hits.count)
    }

    // 진행 중인 측정 (앱이 꺼졌다 켜져도 이어 가도록)

    func saveLive(_ summary: PresenceSummary) {
        if let data = try? JSONEncoder().encode(summary) { defaults.set(data, forKey: liveKey) }
    }

    func live() -> PresenceSummary? {
        guard let data = defaults.data(forKey: liveKey) else { return nil }
        return try? JSONDecoder().decode(PresenceSummary.self, from: data)
    }

    func clearLive() { defaults.removeObject(forKey: liveKey) }
}

// MARK: - 글자

enum PresenceText {
    /// 0:52 처럼 짧게 (1시간 넘으면 1:05:10)
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// 타이머 위 칩: "공부 중 · 순공부 42:10"
    static func chip(state: StudyPresenceState, netSeconds: Int) -> String {
        switch state {
        case .waiting: "준비 중 · 순공부 \(clock(netSeconds))"
        case .studying, .still, .distracted: "\(state.label) · 순공부 \(clock(netSeconds))"
        case .away: "자리 비움"
        }
    }

    /// 시간:분 — 3720초 → "1:02" (초는 버림)
    static func hm(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 3600, (s % 3600) / 60)
    }

    /// 결과 한 줄: "총 1:00 · 순공부 0:52 · 집중도 87%"
    static func result(totalSeconds: Int, summary: PresenceSummary) -> String {
        "총 \(hm(totalSeconds)) · 순공부 \(hm(summary.netSeconds)) · 집중도 \(summary.focusPercent)%"
    }

    /// 순공부가 아닌 시간 요약: "자리 비움 5분 · 멈춤 3분" (1분이 안 되는 것은 뺌)
    static func breakdown(_ summary: PresenceSummary) -> String {
        let parts: [(String, Int)] = [("자리 비움", summary.awaySeconds), ("멈춤", summary.stillSeconds), ("딴짓", summary.distractedSeconds)]
        return parts.filter { $0.1 >= 60 }.map { "\($0.0) \($0.1 / 60)분" }.joined(separator: " · ")
    }
}
