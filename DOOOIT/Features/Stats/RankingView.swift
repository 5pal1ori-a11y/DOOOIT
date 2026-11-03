import SwiftData
import SwiftUI

/// 공부 랭킹: 일간·주간·월간 → 날짜 → Top3 메달 → 참여 인원·내 등수 → 순위 목록 (1등 대비 막대)
struct RankingView: View {
    @Query private var sessions: [StudySession]
    @State private var ranking = RankingService.shared
    @State private var period: RankingService.Period = .daily
    @State private var back = 0
    @State private var board: RankingService.Board?
    @State private var loading = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                periodTabs
                dateBar
                if !ranking.isAuthenticated {
                    signInCard
                } else if !ranking.isJoined {
                    joinCard
                }
                if let board {
                    if board.entries.isEmpty {
                        EmptyStateView(symbol: "trophy", title: "아직 기록이 없어요")
                            .softCard()
                    } else {
                        topThree(board)
                        summaryLine(board)
                        Divider()
                        list(board)
                    }
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if let message {
                    Label(message, systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .softCard()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Palette.card)
        .navigationTitle("모티 랭킹")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload(submit: true) }
        .task { ranking.authenticate(); await reload(submit: true) }
        .onChange(of: ranking.isAuthenticated) { Task { await reload(submit: true) } }
        .onChange(of: period) { back = 0; Task { await reload(submit: false) } }
        .onChange(of: back) { Task { await reload(submit: false) } }
    }

    // MARK: 위쪽

    private var periodTabs: some View {
        HStack(spacing: 0) {
            ForEach(RankingService.Period.allCases) { item in
                Button {
                    withAnimation(.snappy) { period = item }
                    Haptics.tap()
                } label: {
                    VStack(spacing: 8) {
                        Text(item.title)
                            .font(.body.weight(period == item ? .bold : .regular))
                            .foregroundStyle(period == item ? Palette.ink : .secondary)
                        Capsule()
                            .fill(period == item ? Palette.ink : .clear)
                            .frame(width: 28, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 8)
    }

    private var dateBar: some View {
        let range = board.map { ($0.start, $0.end) } ?? period.fallbackRange(back: back)
        return HStack {
            Button { back += 1 } label: { Image(systemName: "chevron.left").frame(width: 44, height: 40) }
            Spacer()
            Text(dateText(range.0, range.1)).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
            Spacer()
            Button { back = max(0, back - 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 40) }
                .disabled(back == 0)
        }
        .foregroundStyle(.secondary)
        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
    }

    private func dateText(_ start: Date, _ end: Date) -> String {
        switch period {
        case .daily: return start.kr("M월 d일")
        case .weekly: return "\(start.kr("M월 d일")) ~ \(end.addingTimeInterval(-1).kr("M월 d일"))"
        case .monthly: return start.kr("yyyy년 M월")
        }
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Game Center에 로그인해 주세요", systemImage: "gamecontroller.fill").font(.headline)
            Text(ranking.authMessage ?? "모티 랭킹은 Apple Game Center로 순위를 모아요. 로그인하면 다른 학생들과 공부 시간을 겨룰 수 있어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("로그인") { ranking.authenticate() }
                .buttonStyle(.primaryFill)
        }
        .softCard()
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("랭킹에 참여할까요?", systemImage: "trophy.fill").font(.headline)
            Text("참여하면 \(ranking.playerName.isEmpty ? "내 Game Center 닉네임" : "'\(ranking.playerName)'")과 공부 시간이 다른 사람에게 보여요. 언제든 끌 수 있어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("참여하기") {
                ranking.isJoined = true
                Task { await reload(submit: true) }
            }
            .buttonStyle(.primaryFill)
        }
        .softCard()
    }

    // MARK: Top3

    private func topThree(_ board: RankingService.Board) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(period.title) Top3").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(board.entries.prefix(3))) { entry in
                    VStack(spacing: 6) {
                        Medal(rank: entry.rank)
                        Text(entry.name).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                        Text(clock(entry.seconds)).font(.footnote).foregroundStyle(Theme.accent).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func summaryLine(_ board: RankingService.Board) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("참여 \(board.total.formatted())명").font(.subheadline).foregroundStyle(Palette.ink)
            if let me = board.me {
                HStack(spacing: 4) {
                    Text("내 등수").foregroundStyle(Palette.ink)
                    Text("\(me.rank.formatted())등").foregroundStyle(Theme.accent)
                    if let percent = board.topPercent {
                        Text("  상위").foregroundStyle(Palette.ink)
                        Text("\(percent)%").foregroundStyle(Theme.accent)
                    }
                }
                .font(.subheadline)
            } else if ranking.isJoined {
                Text("이 기간에 공부하면 내 등수가 나와요").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: 목록

    private func list(_ board: RankingService.Board) -> some View {
        let best = max(board.entries.first?.seconds ?? 1, 1)
        var rows = board.entries
        if let me = board.me, !rows.contains(where: { $0.isMe }) { rows.append(me) }
        return VStack(spacing: 22) {
            ForEach(rows) { entry in
                HStack(alignment: .center, spacing: 14) {
                    ZStack(alignment: .top) {
                        Circle()
                            .strokeBorder(Theme.accent, lineWidth: 1.5)
                            .frame(width: 40, height: 40)
                            .overlay(Text("\(entry.rank)").font(.headline).foregroundStyle(Theme.accent))
                        if entry.rank == 1 {
                            Image(systemName: "crown.fill").font(.caption2).foregroundStyle(Theme.accent).offset(y: -10)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.isMe ? "\(entry.name) (나)" : entry.name)
                                .font(.body.weight(entry.isMe ? .bold : .regular))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Spacer()
                            Text(clock(entry.seconds)).font(.body).foregroundStyle(Theme.accent).monospacedDigit()
                        }
                        LinearProgressBar(value: Double(entry.seconds) / Double(best), height: 5)
                    }
                }
                .padding(entry.isMe ? 10 : 0)
                .background(entry.isMe ? Theme.accent.opacity(0.06) : .clear, in: .rect(cornerRadius: 14))
            }
        }
    }

    private func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }

    // MARK: 불러오기

    private func secondsBetween(_ start: Date, _ end: Date) -> Int {
        sessions.filter { $0.start >= start && $0.start < end }.reduce(0) { $0 + $1.seconds }
    }

    private func reload(submit: Bool) async {
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

/// 금·은·동 메달
private struct Medal: View {
    let rank: Int

    private var colors: [Color] {
        switch rank {
        case 1: return [Color(hex: "#FFD54F"), Color(hex: "#F5B300")]
        case 2: return [Color(hex: "#E0E0E0"), Color(hex: "#B8B8B8")]
        default: return [Color(hex: "#F0A07A"), Color(hex: "#D9774B")]
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 리본
            HStack(spacing: 4) {
                Capsule().fill(colors[1].opacity(0.45)).frame(width: 10, height: 26).rotationEffect(.degrees(18))
                Capsule().fill(colors[1].opacity(0.45)).frame(width: 10, height: 26).rotationEffect(.degrees(-18))
            }
            Circle()
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 60, height: 60)
                .overlay(Text("\(rank)").font(.title2.weight(.semibold)).foregroundStyle(.white.opacity(0.9)))
                .padding(.top, 16)
        }
        .frame(height: 80)
    }
}
