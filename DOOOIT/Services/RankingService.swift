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
            case .daily: return L("일간")
            case .weekly: return L("주간")
            case .monthly: return L("월간")
            }
        }
        /// 한국 시간 ISO 달력 (월요일 시작 — App Store Connect에 만든 주간 리더보드와 같은 기준)
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .iso8601)
            calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
            calendar.locale = Locale(identifier: "ko_KR")
            return calendar
        }

        /// 리더보드 ID: 일간은 반복 리더보드 하나, 주간·월간은 주·달마다 하나 (예: dooit.study.w2026_45, dooit.study.m2026_11)
        func leaderboardID(back: Int = 0, now: Date = Date()) -> String {
            let calendar = Self.calendar
            let start = fallbackRange(back: back, now: now).start
            switch self {
            case .daily:
                return "dooit.study.daily"
            case .weekly:
                let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start)
                return String(format: "dooit.study.w%04d_%02d", parts.yearForWeekOfYear ?? 0, parts.weekOfYear ?? 0)
            case .monthly:
                let parts = calendar.dateComponents([.year, .month], from: start)
                return String(format: "dooit.study.m%04d_%02d", parts.year ?? 0, parts.month ?? 0)
            }
        }

        /// 기간 (한국 시간 달력)
        func fallbackRange(back: Int, now: Date = Date()) -> (start: Date, end: Date) {
            let calendar = Self.calendar
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
            case .notSignedIn: return L("Game Center에 로그인하면 랭킹을 볼 수 있어요.")
            case .notReady: return L("랭킹을 준비하고 있어요. 잠시 뒤에 다시 열어 주세요.")
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
                service.authMessage = error == nil ? nil : L("Game Center에 로그인하지 못했어요. 설정 › Game Center에서 로그인해 주세요.")
            }
        }
    }

    // MARK: 기록 올리기

    /// 기간마다 그 기간의 공부 시간을 올림. secondsBetween: (시작, 끝) → 그 사이 공부한 초
    func submit(secondsBetween: (Date, Date) -> Int) async {
        guard isJoined, GKLocalPlayer.local.isAuthenticated else { return }
        for period in Period.allCases {
            let id = period.leaderboardID()
            var range = period.fallbackRange(back: 0)
            // 일간 반복 리더보드는 Game Center가 정한 기간을 그대로
            if period == .daily, let board = try? await GKLeaderboard.loadLeaderboards(IDs: [id]).first, let start = board.startDate {
                range = (start, start.addingTimeInterval(board.duration > 0 ? board.duration : 86400))
            }
            let seconds = secondsBetween(range.start, range.end)
            guard seconds > 0 else { continue }
            try? await GKLeaderboard.submitScore(seconds, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [id])
        }
    }

    // MARK: 순위 불러오기

    /// back: 0 = 이번 기간, 1 = 지난 기간 …
    func load(_ period: Period, back: Int = 0, limit: Int = 50) async throws -> Board {
        guard GKLocalPlayer.local.isAuthenticated else { throw RankingError.notSignedIn }
        // 주간·월간은 그 주·그 달의 리더보드, 일간은 반복 리더보드의 지난 회차로 거슬러 감
        let boardID = period == .daily ? period.leaderboardID() : period.leaderboardID(back: back)
        guard var board = (try? await GKLeaderboard.loadLeaderboards(IDs: [boardID]))?.first else { throw RankingError.notReady }
        if period == .daily {
            for _ in 0..<back {
                guard let previous = try? await board.loadPreviousOccurrence() else { break }
                board = previous
            }
        }
        let (local, entries, total) = try await board.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: limit))
        let meID = GKLocalPlayer.local.gamePlayerID
        func convert(_ entry: GKLeaderboard.Entry) -> Entry {
            Entry(id: entry.player.gamePlayerID, rank: entry.rank, name: entry.player.displayName, seconds: entry.score,
                  isMe: entry.player.gamePlayerID == meID)
        }
        let fallback = period.fallbackRange(back: back)
        let recurring = period == .daily ? board.startDate : nil
        let start = recurring ?? fallback.start
        let end = recurring.map { $0.addingTimeInterval(board.duration > 0 ? board.duration : 86400) } ?? fallback.end
        return Board(period: period, start: start, end: end, entries: entries.map(convert), me: local.map(convert), total: total)
    }
}

#if DEBUG
extension RankingService {
    /// 화면 사진용 가짜 순위 (Game Center 없이)
    static func demoBoard(_ period: Period, far: Bool) -> Board {
        let names = ["하늘", "서준", "지민", "도윤", "유나", "민재", "수아", "현우", "채원", "지호", "예린", "태양"]
        let base = period == .daily ? 21_600 : (period == .weekly ? 108_000 : 410_000)
        var entries = names.enumerated().map { i, name in
            Entry(id: "demo\(i)", rank: i + 1, name: name, seconds: base - i * (base / 16) - i * 37, isMe: false)
        }
        let range = period.fallbackRange(back: 0)
        if far {
            let me = Entry(id: "me", rank: 87, name: "김모티", seconds: base / 6, isMe: true)
            return Board(period: period, start: range.start, end: range.end, entries: entries, me: me, total: 412)
        }
        entries[4] = Entry(id: "me", rank: 5, name: "김모티", seconds: entries[4].seconds, isMe: true)
        return Board(period: period, start: range.start, end: range.end, entries: entries, me: entries[4], total: 412)
    }
}
#endif

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
