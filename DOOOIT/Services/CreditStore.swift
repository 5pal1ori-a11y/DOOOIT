import Foundation
import Observation

/// AI 크레딧
/// - 매일 처음 열 때 100 크레딧 지급 (쌓임)
/// - AI 기능 1회(문제 1개) = 100 크레딧, 실패하면 차감하지 않음
/// - 보상형 광고 1회 = 50 크레딧, 하루 10회까지
/// 기기 Keychain에 저장해서 앱을 지웠다 깔아도 유지됨
@MainActor
@Observable
final class CreditStore {
    static let shared = CreditStore()

    static let costPerUse = 100
    static let dailyGrant = 100
    static let adReward = 50
    static let adDailyLimit = 10
    static let studyRewardPerHour = 20
    static let studyRewardMaxHours = 5

    enum Use: String, Codable {
        case readProblem, solution, askAI, unitStudy

        var title: String {
            switch self {
            case .readProblem: return "문제 사진 읽기"
            case .solution: return "AI 단계별 풀이"
            case .askAI: return "AI에게 질문"
            case .unitStudy: return "AI 학습 (단원 1개)"
            }
        }

        var symbol: String {
            switch self {
            case .readProblem: return "doc.text.viewfinder"
            case .solution: return "list.number"
            case .askAI: return "questionmark.bubble.fill"
            case .unitStudy: return "sparkles"
            }
        }
    }

    struct Entry: Codable, Identifiable {
        var id = UUID()
        var date = Date()
        var amount: Int
        var title: String
    }

    private struct State: Codable {
        var balance = 0
        var dailyKey = ""
        var adsKey = ""
        var adsCount = 0
        var paidUnits: [String] = []
        var history: [Entry] = []
        // 나중에 추가된 값은 옵셔널 (예전에 저장된 크레딧을 그대로 읽기 위해)
        var studyKey: String?
        var studyHours: Int?
    }

    private static let storageKey = "dooit.credits.v1"
    private var state: State

    var balance: Int { state.balance }
    var history: [Entry] { state.history }
    var adsWatchedToday: Int { state.adsKey == Date().dayKey ? state.adsCount : 0 }
    var adsLeftToday: Int { max(0, Self.adDailyLimit - adsWatchedToday) }
    var receivedDailyToday: Bool { state.dailyKey == Date().dayKey }
    /// 오늘 공부 보상을 받은 시간 수
    var studyHoursRewardedToday: Int { state.studyKey == Date().dayKey ? (state.studyHours ?? 0) : 0 }

    private init() {
        if let data = Keychain.get(Self.storageKey),
           let saved = try? JSONDecoder().decode(State.self, from: data) {
            state = saved
        } else {
            state = State()
        }
    }

    /// 오늘 처음이면 무료 크레딧 지급. 지급했으면 그 양을 돌려줌
    @discardableResult
    func grantDailyIfNeeded() -> Int? {
        let today = Date().dayKey
        guard state.dailyKey != today else { return nil }
        state.dailyKey = today
        add(Self.dailyGrant, title: "오늘의 무료 크레딧")
        return Self.dailyGrant
    }

    func canAfford(_ cost: Int = CreditStore.costPerUse) -> Bool {
        state.balance >= cost
    }

    /// AI 사용이 끝난 뒤 차감 (실패한 요청은 부르지 않음)
    func charge(_ use: Use, cost: Int = CreditStore.costPerUse) {
        add(-cost, title: use.title)
    }

    /// 단원 학습은 단원마다 한 번만 차감
    func isUnitPaid(_ key: String) -> Bool { state.paidUnits.contains(key) }

    /// 이번 실행에서 "진행"을 눌렀던 단원 (첫 자료가 만들어지는 동안 다른 단계에서 또 묻지 않게)
    @ObservationIgnored private var confirmedUnits: Set<String> = []
    func confirmUnit(_ key: String) { confirmedUnits.insert(key) }
    func isUnitConfirmed(_ key: String) -> Bool { isUnitPaid(key) || confirmedUnits.contains(key) }

    func chargeUnit(_ key: String) {
        guard !isUnitPaid(key) else { return }
        state.paidUnits.append(key)
        if state.paidUnits.count > 300 { state.paidUnits.removeFirst(state.paidUnits.count - 300) }
        charge(.unitStudy)
    }

    /// 공부 시간 보상: 오늘 총 공부 시간이 1시간 넘을 때마다 +20 (하루 5시간까지). 새로 받은 양을 돌려줌
    @discardableResult
    func rewardStudyTime(todaySeconds: Int) -> Int {
        let today = Date().dayKey
        if state.studyKey != today {
            state.studyKey = today
            state.studyHours = 0
        }
        let hours = min(todaySeconds / 3600, Self.studyRewardMaxHours)
        let already = state.studyHours ?? 0
        guard hours > already else { return 0 }
        let amount = (hours - already) * Self.studyRewardPerHour
        state.studyHours = hours
        add(amount, title: "공부 \(hours)시간 달성")
        return amount
    }

    /// 광고 보상
    func rewardForAd() {
        let today = Date().dayKey
        if state.adsKey != today {
            state.adsKey = today
            state.adsCount = 0
        }
        guard state.adsCount < Self.adDailyLimit else { return }
        state.adsCount += 1
        add(Self.adReward, title: "광고 보상")
    }

    private func add(_ amount: Int, title: String) {
        state.balance = max(0, state.balance + amount)
        state.history.insert(Entry(amount: amount, title: title), at: 0)
        if state.history.count > 50 { state.history.removeLast(state.history.count - 50) }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            Keychain.set(data, for: Self.storageKey)
        }
    }
}
