import Foundation
import GameKit
import Observation
import UIKit

/// 공부 랭킹 (Apple Game Center 리더보드 — 따로 서버 없이 Apple이 순위를 모아 줌)
/// - 일간·주간·월간 리더보드에 "그 기간에 공부한 시간(초)"을 올림 (BEST_SCORE라 기간 안에서 가장 큰 값 = 누적 시간)
/// - "랭킹 참여"를 켠 사람만 올림. 이름은 Game Center 닉네임으로 보여요
@MainActor
@Observable
final class RankingService {
    static let shared = RankingService()

    enum Period: String, CaseIterable, Identifiable {
        case daily, weekly, monthly
        var id: String { rawValue }
        var title: String {
            switch self {
            case .daily: return "일간"
            case .weekly: return "주간"
            case .monthly: return "월간"
            }
        }
        var leaderboardID: String { "dooit.study.\(rawValue)" }

        /// Game Center에서 기간을 못 받았을 때 쓰는 기간 (한국 달력)
        func fallbackRange(back: Int, now: Date = Date()) -> (start: Date, end: Date) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "ko_KR")
            calendar.firstWeekday = 2
            let component: Calendar.Component = self == .daily ? .day : (self == .weekly ? .weekOfYear : .month)
            let base = calendar.dateInterval(of: component, for: now) ?? DateInterval(start: now, duration: 86400)
            let start = calendar.date(byAdding: component, value: -back, to: base.start) ?? base.start
            let end = calendar.date(byAdding: component, value: 1, to: start) ?? base.end
            return (start, end)
        }
    }

    struct Entry: Identifiable, Equatable {
        let id: String
        let rank: Int
        let name: String
        let seconds: Int
        let isMe: Bool
    }

    struct Board: Equatable {
        var period: Period
        var start: Date
        var end: Date
        var entries: [Entry]
        var me: Entry?
        var total: Int
        /// 상위 몇 %인지 (내 기록이 있을 때)
        var topPercent: Int? {
            guard let me, total > 0 else { return nil }
            return max(1, Int((Double(me.rank) / Double(total) * 100).rounded(.up)))
        }
    }

    enum RankingError: LocalizedError {
        case notSignedIn, notReady
        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "Game Center에 로그인하면 랭킹을 볼 수 있어요."
            case .notReady: return "랭킹을 준비하고 있어요. 잠시 뒤에 다시 열어 주세요."
            }
        }
    }

    private(set) var isAuthenticated = GKLocalPlayer.local.isAuthenticated
    private(set) var authMessage: String?
    private(set) var playerName: String = GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.displayName : ""

    private let joinedKey = "ranking.joined"
    /// 랭킹에 내 공부 시간을 올릴지 (처음엔 꺼짐 — 사용자가 직접 켬)
    var isJoined: Bool {
        get { access(keyPath: \.isJoined); return UserDefaults.standard.bool(forKey: joinedKey) }
        set { withMutation(keyPath: \.isJoined) { UserDefaults.standard.set(newValue, forKey: joinedKey) } }
    }

    @ObservationIgnored private var authStarted = false

    // MARK: 로그인

    func authenticate() {
        guard !authStarted else { return }
        authStarted = true
        GKLocalPlayer.local.authenticateHandler = { controller, error in
            Task { @MainActor in
                let service = RankingService.shared
                if let controller {
                    // Game Center 로그인 화면
                    UIApplication.shared.topViewController?.present(controller, animated: true)
                    return
                }
                service.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                service.playerName = GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.displayName : ""
                service.authMessage = error == nil ? nil : "Game Center에 로그인하지 못했어요. 설정 › Game Center에서 로그인해 주세요."
            }
        }
    }

    // MARK: 기록 올리기

    /// 기간마다 그 기간의 공부 시간을 올림. secondsBetween: (시작, 끝) → 그 사이 공부한 초
    func submit(secondsBetween: (Date, Date) -> Int) async {
        guard isJoined, GKLocalPlayer.local.isAuthenticated else { return }
        for period in Period.allCases {
            let range: (start: Date, end: Date)
            if let board = try? await GKLeaderboard.loadLeaderboards(IDs: [period.leaderboardID]).first, let start = board.startDate {
                range = (start, start.addingTimeInterval(board.duration > 0 ? board.duration : 86400))
            } else {
                range = period.fallbackRange(back: 0)
            }
            let seconds = secondsBetween(range.start, range.end)
            guard seconds > 0 else { continue }
            try? await GKLeaderboard.submitScore(seconds, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [period.leaderboardID])
        }
    }

    // MARK: 순위 불러오기

    /// back: 0 = 이번 기간, 1 = 지난 기간 …
    func load(_ period: Period, back: Int = 0, limit: Int = 50) async throws -> Board {
        guard GKLocalPlayer.local.isAuthenticated else { throw RankingError.notSignedIn }
        guard var board = try await GKLeaderboard.loadLeaderboards(IDs: [period.leaderboardID]).first else { throw RankingError.notReady }
        for _ in 0..<back {
            guard let previous = try? await board.loadPreviousOccurrence() else { break }
            board = previous
        }
        let (local, entries, total) = try await board.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: limit))
        let meID = GKLocalPlayer.local.gamePlayerID
        func convert(_ entry: GKLeaderboard.Entry) -> Entry {
            Entry(id: entry.player.gamePlayerID, rank: entry.rank, name: entry.player.displayName, seconds: entry.score,
                  isMe: entry.player.gamePlayerID == meID)
        }
        let fallback = period.fallbackRange(back: back)
        let start = board.startDate ?? fallback.start
        let end = board.startDate.map { $0.addingTimeInterval(board.duration > 0 ? board.duration : 86400) } ?? fallback.end
        return Board(period: period, start: start, end: end, entries: entries.map(convert), me: local.map(convert), total: total)
    }
}

extension UIApplication {
    /// 지금 맨 위에 보이는 화면 (Game Center 로그인 화면을 띄울 곳)
    var topViewController: UIViewController? {
        let scene = connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            ?? connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
