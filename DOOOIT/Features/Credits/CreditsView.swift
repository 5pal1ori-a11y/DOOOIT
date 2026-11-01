import SwiftUI

/// 크레딧: 잔액, 공부로 받기, 최근 내역
struct CreditsView: View {
    @Environment(CreditStore.self) private var credits
    @State private var showHistory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                balanceCard
                studyCard
                historyCard
            }
            .padding(20)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("크레딧")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { credits.grantDailyIfNeeded() }
    }

    // MARK: 잔액

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.circle.fill")
                    .font(.title2)
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.2), in: .circle)
                Spacer()
                Label(credits.receivedDailyToday ? "오늘 무료 크레딧 받음" : "내일 또 받아요",
                      systemImage: credits.receivedDailyToday ? "checkmark" : "clock")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2), in: .capsule)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("내 크레딧").font(.subheadline).opacity(0.85)
                Text("\(credits.balance)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("AI 한 번 = \(CreditStore.costPerUse) 크레딧 · 매일 \(CreditStore.dailyGrant) 크레딧 무료 · 두잇 AI 채팅은 무료")
                    .font(.caption)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(
            LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 28)
        )
        .shadow(color: Theme.accent.opacity(0.3), radius: 18, y: 10)
    }

    // MARK: 공부로 얻기

    private var studyCard: some View {
        let earned = credits.studyHoursRewardedToday
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconBadge(symbol: "timer", color: Palette.success, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("공부하고 크레딧 얻기").font(.headline)
                    Text("타이머로 하루 공부 1시간마다 +\(CreditStore.studyRewardPerHour) · 하루 \(CreditStore.studyRewardMaxHours)시간까지")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                ForEach(1...CreditStore.studyRewardMaxHours, id: \.self) { hour in
                    VStack(spacing: 4) {
                        Capsule()
                            .fill(hour <= earned ? Palette.success : Color.primary.opacity(0.08))
                            .frame(height: 8)
                        Text("\(hour)시간").font(.caption2).foregroundStyle(hour <= earned ? Palette.success : .secondary)
                    }
                }
            }
            Text(earned >= CreditStore.studyRewardMaxHours
                 ? "오늘 공부 보상을 모두 받았어요!"
                 : "오늘 +\(earned * CreditStore.studyRewardPerHour) 받음 · 타이머를 끝내면 자동으로 들어와요")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    // MARK: 내역

    @ViewBuilder
    private var historyCard: some View {
        if !credits.history.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.snappy) { showHistory.toggle() }
                } label: {
                    HStack {
                        Label("최근 내역", systemImage: "clock.arrow.circlepath").font(.headline)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(showHistory ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showHistory {
                ForEach(credits.history.prefix(30)) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.title).font(.subheadline)
                            Text(entry.date.kr("M월 d일 a h:mm")).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.amount > 0 ? "+\(entry.amount)" : "\(entry.amount)")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(entry.amount > 0 ? Palette.success : Color.secondary)
                    }
                    .transition(.opacity)
                }
                }
            }
            .glassCard()
        }
    }
}

/// 어디서나 쓰는 작은 크레딧 표시 (누르면 크레딧 화면)
struct CreditChip: View {
    @Environment(CreditStore.self) private var credits

    var body: some View {
        NavigationLink { CreditsView() } label: {
            Label("\(credits.balance)", systemImage: "bolt.circle.fill")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.accent.opacity(0.12), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("크레딧 \(credits.balance)")
    }
}

/// 크레딧이 모자랄 때 보여주는 안내
struct NotEnoughCreditsView: View {
    @Environment(CreditStore.self) private var credits

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.slash.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Palette.warning)
            VStack(spacing: 4) {
                Text("크레딧이 부족해요").font(.headline)
                Text("AI 한 번에 \(CreditStore.costPerUse) 크레딧이 필요해요. 지금 \(credits.balance) 크레딧이 있어요.\n매일 \(CreditStore.dailyGrant) 크레딧을 받고, 타이머로 공부하면 1시간마다 +\(CreditStore.studyRewardPerHour) 받아요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            NavigationLink { CreditsView() } label: {
                Label("크레딧 보기", systemImage: "bolt.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
