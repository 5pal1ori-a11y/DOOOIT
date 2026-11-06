import SwiftData
import SwiftUI

/// 공부 랭킹: 기간 선택 → 날짜 → 내 순위 요약 → 순위 목록 (순위 · 이름 · 공부 시간, 내 줄만 강조색 바탕)
struct RankingView: View {
    @Query private var sessions: [StudySession]
    @State private var ranking = RankingService.shared
    @State private var period: RankingService.Period = .daily
    @State private var back = 0
    @State private var board: RankingService.Board?
    @State private var loading = false
    @State private var message: String?

    /// 화면 사진용: Game Center 없이 가짜 순위를 보여 줌 (Debug 빌드에서만)
    private var isDemo: Bool {
        #if DEBUG
        return UIShot.matches(.ranking, .rankingFar)
        #else
        return false
        #endif
    }
    private var authed: Bool { ranking.isAuthenticated || isDemo }
    private var joined: Bool { ranking.isJoined || isDemo }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PillSegmentedControl(items: RankingService.Period.allCases, selection: $period) { $0.title }
                dateBar
                if !authed {
                    signInCard
                } else if !joined {
                    joinCard
                }
                if let board {
                    if board.entries.isEmpty {
                        EmptyStateView(symbol: "trophy", title: L("아직 기록이 없어요"))
                            .softCard()
                    } else {
                        mySummary(board)
                        list(board)
                    }
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if let message {
                    Text(message)
                        .font(.pt(.subheadline))
                        .foregroundStyle(.secondary)
                        .softCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 내가 목록 밖(아래쪽 순위)이면 내 줄을 아래에 고정
            if let board, let me = board.me, !board.entries.contains(where: { $0.isMe }) {
                row(me)
                    .background(Palette.card)
                    .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 0.5) }
            }
        }
        .navigationTitle("모티 랭킹")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload(submit: true) }
        .task { ranking.authenticate(); await reload(submit: true) }
        .onChange(of: ranking.isAuthenticated) { Task { await reload(submit: true) } }
        .onChange(of: period) { back = 0; Task { await reload(submit: false) } }
        .onChange(of: back) { Task { await reload(submit: false) } }
    }

    // MARK: 위쪽

    /// 날짜 이동: ‹ 11월 6일 ›
    private var dateBar: some View {
        let range = board.map { ($0.start, $0.end) } ?? period.fallbackRange(back: back)
        return HStack(spacing: 0) {
            Button { back += 1 } label: { Image(systemName: "chevron.left").frame(width: 40, height: 36) }
            Text(dateText(range.0, range.1))
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
            Button { back = max(0, back - 1) } label: { Image(systemName: "chevron.right").frame(width: 40, height: 36) }
                .disabled(back == 0)
        }
        .font(.pt(.subheadline).weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func dateText(_ start: Date, _ end: Date) -> String {
        switch period {
        case .daily: return start.ui("M월 d일")
        case .weekly: return L("\(start.ui("M월 d일")) ~ \(end.addingTimeInterval(-1).ui("M월 d일"))")
        case .monthly: return start.ui("yyyy년 M월")
        }
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Game Center에 로그인해 주세요").font(.pt(.headline))
            Text(ranking.authMessage ?? L("모티 랭킹은 Apple Game Center로 순위를 모아요. 로그인하면 다른 학생들과 공부 시간을 겨룰 수 있어요."))
                .font(.pt(.footnote))
                .foregroundStyle(.secondary)
            Button("로그인") { ranking.authenticate() }
                .buttonStyle(.primaryFill)
                .padding(.top, 4)
        }
        .softCard()
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("랭킹에 참여할까요?").font(.pt(.headline))
            Text("참여하면 \(ranking.playerName.isEmpty ? L("내 Game Center 닉네임") : "'\(ranking.playerName)'")과 공부 시간이 다른 사람에게 보여요. 언제든 끌 수 있어요.")
                .font(.pt(.footnote))
                .foregroundStyle(.secondary)
            Button("참여하기") {
                ranking.isJoined = true
                Task { await reload(submit: true) }
            }
            .buttonStyle(.primaryFill)
            .padding(.top, 4)
        }
        .softCard()
    }

    // MARK: 내 순위

    /// 내 순위 요약: 큰 순위 숫자 + 상위 % · 내 공부 시간 (참여 인원은 아래 목록 머리글)
    @ViewBuilder
    private func mySummary(_ board: RankingService.Board) -> some View {
        if let me = board.me {
            VStack(alignment: .leading, spacing: 4) {
                Text("내 등수").font(.pt(.footnote)).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(L("\(me.rank.formatted())등"))
                        .font(.pt(size: 36, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TimeText.durationL(seconds: me.seconds))
                            .font(.pt(.headline))
                            .foregroundStyle(Palette.ink)
                            .monospacedDigit()
                        if let percent = board.topPercent {
                            Text(L("상위 \(percent)%"))
                                .font(.pt(.footnote))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .softCard()
        } else if joined {
            Text("이 기간에 공부하면 내 등수가 나와요")
                .font(.pt(.subheadline))
                .foregroundStyle(.secondary)
                .softCard()
        }
    }

    // MARK: 목록

    private func list(_ board: RankingService.Board) -> some View {
        let allRows = board.entries
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L("참여 \(board.total.formatted())명"))
                Spacer()
                Text("공부 시간")
            }
            .font(.pt(.footnote))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(allRows.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Rectangle().fill(Palette.line).frame(height: 0.5).padding(.leading, 52)
                    }
                    row(entry)
                }
            }
            .background(Palette.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
            .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
        }
    }

    /// 한 줄: 순위(1~3위만 강조색) · 이름 · 공부 시간 (오른쪽 정렬 숫자)
    private func row(_ entry: RankingService.Entry) -> some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(.pt(size: 17, weight: entry.rank <= 3 ? .bold : .regular))
                .foregroundStyle(entry.isMe ? Theme.onHighlight : (entry.rank <= 3 ? Theme.accent : Color.secondary))
                .monospacedDigit()
                .frame(width: 28, alignment: .trailing)
            Text(entry.isMe ? L("\(entry.name) (나)") : entry.name)
                .font(.pt(.body).weight(entry.isMe ? .semibold : .regular))
                .foregroundStyle(entry.isMe ? Theme.onHighlight : Palette.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(TimeText.durationL(seconds: entry.seconds))
                .font(.pt(.body).weight(entry.rank == 1 ? .bold : .regular))
                .foregroundStyle(entry.isMe ? Theme.onHighlight : Palette.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(entry.isMe ? Theme.highlight : .clear)
    }

    // MARK: 불러오기

    private func secondsBetween(_ start: Date, _ end: Date) -> Int {
        sessions.filter { $0.start >= start && $0.start < end }.reduce(0) { $0 + $1.seconds }
    }

    private func reload(submit: Bool) async {
        #if DEBUG
        if isDemo { board = RankingService.demoBoard(period, far: UIShot.matches(.rankingFar)); return }
        #endif
        guard ranking.isAuthenticated else { board = nil; return }
        loading = true
        defer { loading = false }
        if submit { await ranking.submit(secondsBetween: secondsBetween) }
        do {
            board = try await ranking.load(period, back: back)
            message = nil
        } catch {
            board = nil
            message = (error as? RankingService.RankingError)?.errorDescription ?? RankingService.RankingError.notReady.errorDescription
        }
    }
}
