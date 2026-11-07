import Foundation

/// 내 프로필을 CloudKit에 올리는 때와 속도 조절 (타이머를 느리게 하지 않게: 계산만 하고, 올리는 일은 뒤에서)
///   - 시작 · 멈춤: 바로 (단, 5초 안에 또 보내지 않음)
///   - 공부 중: 60초마다 한 번 (친구 쪽은 3분 넘게 소식이 없으면 공부 중으로 안 봄)
///   - 하루 합계만 바뀐 경우: 20초 모아서 한 번
///   - 실패: 인터넷 문제면 점점 길게 쉬었다 다시, 너무 자주 보냈다는 답(requestRateLimited)이면 알려 준 시간만큼 기다림
enum PublishReason: Equatable {
    case stateChange
    case totalChange
    case heartbeat
    case retry
}

/// 마지막으로 올린 내용 (같은 내용을 또 올리지 않으려고 비교)
struct PublishedSnapshot: Equatable {
    var studying: Bool
    var todaySeconds: Int
    var weekSeconds: Int
    var todayKey: String
    var hidden: Bool
    var nickname: String
    /// 지금까지 공부한 분 (초대 보상용. 분이 바뀔 때만 다시 올림)
    var totalMinutes: Int = 0
}

struct PublishPolicy {
    var minGap: TimeInterval = 5
    var debounce: TimeInterval = 20
    var heartbeat: TimeInterval = 60
    var maxBackoff: TimeInterval = 300

    private(set) var lastSentAt: Date?
    private(set) var blockedUntil: Date?
    private(set) var failures = 0

    /// 이 이유로 보내려면 지금부터 몇 초 기다려야 하는지
    func delay(for reason: PublishReason, now: Date) -> TimeInterval {
        var wait: TimeInterval = 0
        switch reason {
        case .totalChange: wait = debounce
        case .retry: wait = backoff
        case .stateChange, .heartbeat: wait = 0
        }
        if let lastSentAt { wait = max(wait, lastSentAt.addingTimeInterval(minGap).timeIntervalSince(now)) }
        if let blockedUntil { wait = max(wait, blockedUntil.timeIntervalSince(now)) }
        return max(0, wait)
    }

    /// 실패가 이어진 횟수에 따른 쉬는 시간: 30초, 60초, 120초 … 최대 5분
    var backoff: TimeInterval {
        guard failures > 0 else { return 0 }
        return min(30 * pow(2, Double(failures - 1)), maxBackoff)
    }

    /// 보낼 만한 변화인지
    func shouldSend(_ new: PublishedSnapshot, last: PublishedSnapshot?, reason: PublishReason) -> Bool {
        guard let last else { return true }
        // 공부 중에는 소식이 끊기지 않게 60초마다 같은 내용이라도 보냄
        if new.studying && (reason == .heartbeat || reason == .retry) { return true }
        return new != last
    }

    mutating func recordSuccess(at now: Date) {
        lastSentAt = now
        failures = 0
        blockedUntil = nil
    }

    /// 실패를 기록하고, 다시 시도할 때까지 기다릴 시간을 돌려줌 (다시 시도해도 소용없는 오류는 nil)
    @discardableResult
    mutating func recordFailure(_ error: SocialError, at now: Date) -> TimeInterval? {
        switch error {
        case .rateLimited(let seconds):
            let wait = max(1, seconds)
            blockedUntil = now.addingTimeInterval(wait)
            failures += 1
            return wait
        case .network, .unavailable, .server:
            failures += 1
            return backoff
        default:
            // 로그인 안 됨 · 권한 없음 등은 다시 해도 같음 (다음 변화가 생길 때 다시 시도)
            return nil
        }
    }
}
