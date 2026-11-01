import StoreKit
import SwiftUI

/// 크레딧: 잔액, 광고 보고 받기, 공부로 받기, 크레딧 상점(충전·플랜), 최근 내역
struct CreditsView: View {
    @Environment(CreditStore.self) private var credits
    @State private var ads = RewardedAdManager.shared
    @State private var message: String?
    @State private var bump = 0
    @State private var showHistory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                balanceCard
                adCard
                studyCard
                shopLink
                historyCard
            }
            .padding(20)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("크레딧")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            credits.grantDailyIfNeeded()
            ads.start()
        }
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
                Text(credits.isUnlimited ? "무제한" : "\(credits.balance)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .scaleEffect(1)
                    .animation(.snappy, value: bump)
                Text(credits.plan.map { "\($0.title) 이용 중" } ?? "AI 한 번 = \(CreditStore.costPerUse) 크레딧 · 매일 \(CreditStore.dailyGrant) 크레딧 무료")
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

    // MARK: 광고

    private var adCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconBadge(symbol: "play.rectangle.fill", color: Palette.warning, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("광고 보고 크레딧 얻기").font(.headline)
                    Text("끝까지 보면 +\(CreditStore.adReward) 크레딧 · 오늘 \(credits.adsWatchedToday)/\(CreditStore.adDailyLimit)회")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task { await watchAd() }
            } label: {
                HStack {
                    if ads.isLoading || ads.isShowing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(adButtonTitle)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.glassProminent)
            .disabled(credits.adsLeftToday == 0 || ads.isShowing)

            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary).transition(.opacity)
            } else if let error = ads.lastError {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
            if RewardedAdManager.isTestAd {
                Text("지금은 테스트 광고예요. AdMob 광고 ID를 연결하면 실제 광고가 나와요.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .glassCard()
    }

    private var adButtonTitle: String {
        if credits.adsLeftToday == 0 { return "오늘은 모두 받았어요" }
        if ads.isShowing { return "광고 보는 중" }
        if ads.isLoading && !ads.isReady { return "광고 불러오는 중" }
        return "광고 보고 +\(CreditStore.adReward) 받기"
    }

    private func watchAd() async {
        withAnimation { message = nil }
        let rewarded = await ads.show()
        if rewarded {
            withAnimation(.snappy) {
                credits.rewardForAd()
                bump += 1
            }
            Haptics.success()
            withAnimation { message = "+\(CreditStore.adReward) 크레딧을 받았어요!" }
        } else if ads.lastError == nil {
            withAnimation { message = "광고를 끝까지 봐야 크레딧을 받을 수 있어요." }
        }
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

    // MARK: 크레딧 상점 (누르면 상점 화면)

    private var shopLink: some View {
        NavigationLink { CreditShopView() } label: {
            HStack(spacing: 14) {
                Image(systemName: "cart.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        LinearGradient(colors: [Color(hex: "#FF8A3D"), Color(hex: "#F5536B")], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: .rect(cornerRadius: 14)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text("크레딧 상점").font(.headline)
                    Text(credits.canUseFirstPurchaseDeal ? "첫 구매 특가 · 100크레딧당 125원" : "크레딧 충전 · 무제한 / 매일 지급 플랜")
                        .font(.caption)
                        .foregroundStyle(credits.canUseFirstPurchaseDeal ? Color(hex: "#F5536B") : .secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .glassCard(interactive: true)
        }
        .buttonStyle(.plain)
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
                Text("AI 한 번에 \(CreditStore.costPerUse) 크레딧이 필요해요. 지금 \(credits.balance) 크레딧이 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            NavigationLink { CreditsView() } label: {
                Label("크레딧 얻기", systemImage: "play.rectangle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.glassProminent)
            NavigationLink { CreditShopView() } label: {
                Label("크레딧 상점에서 충전하기", systemImage: "cart.fill")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

/// 크레딧 상점: 첫 구매 특가, 충전, 플랜
struct CreditShopView: View {
    @Environment(CreditStore.self) private var credits
    @State private var store = StoreManager.shared
    @State private var showManageSubscription = false

    var body: some View {
        ScrollView {
            shopSection
                .padding(20)
                .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("크레딧 상점")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("구매 복원") { Task { await store.restore() } }
            }
        }
        .onAppear { store.start() }
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        .alert("크레딧 상점", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(store.message ?? "")
        }
    }

    private var shopSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.circle.fill").foregroundStyle(Theme.accent)
                Text(credits.isUnlimited ? "무제한 플랜 이용 중" : "내 크레딧 \(credits.balance)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.accent.opacity(0.12), in: .capsule)

            if credits.canUseFirstPurchaseDeal {
                firstDealCard
            }

            VStack(spacing: 0) {
                ForEach(Array(StoreManager.ID.packs.enumerated()), id: \.offset) { index, id in
                    if index > 0 { Divider().padding(.leading, 60) }
                    packRow(id)
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 22))

            Text("플랜").font(.headline).padding(.top, 6)
            planCard(id: StoreManager.ID.unlimited, title: "크레딧 무제한 플랜", symbol: "infinity",
                     detail: "모든 AI 기능을 크레딧 차감 없이 마음껏", color: Theme.accent)
            planCard(id: StoreManager.ID.daily, title: "매일 지급 플랜", symbol: "calendar.badge.plus",
                     detail: "매일 \(CreditStore.dailyPlanGrant) 크레딧 추가 지급 (무료 \(CreditStore.dailyGrant)과 별도)", color: Palette.success)

            if store.activePlanID != nil {
                Button("구독 관리 · 해지") { showManageSubscription = true }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }

            Text("구독은 매월 자동 갱신되며, 갱신 24시간 전까지 App Store 계정 설정에서 해지할 수 있어요. 구매한 크레딧은 이 기기의 DOOOIT에서 쓸 수 있어요.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var firstDealCard: some View {
        let id = StoreManager.ID.firstPack
        return Button { Task { await store.purchase(id) } } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("첫 구매 특가 · 50% 할인")
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.25), in: .capsule)
                    Text("1,000 크레딧").font(.title2.weight(.black))
                    Text("100크레딧당 125원 · 한 번만 살 수 있어요").font(.caption).opacity(0.9)
                }
                Spacer()
                buyLabel(id, onDark: true)
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(
                LinearGradient(colors: [Color(hex: "#FF8A3D"), Color(hex: "#F5536B")], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: 22)
            )
            .shadow(color: Color(hex: "#F5536B").opacity(0.3), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(store.purchasingID != nil)
    }

    private func packRow(_ id: String) -> some View {
        let amount = StoreManager.credits[id] ?? 0
        return Button { Task { await store.purchase(id) } } label: {
            HStack(spacing: 14) {
                Image(systemName: "bolt.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(amount.formatted()) 크레딧").font(.headline)
                    Text("100크레딧당 250원 · AI \(amount / CreditStore.costPerUse)번").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                buyLabel(id, onDark: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.purchasingID != nil)
    }

    private func planCard(id: String, title: String, symbol: String, detail: String, color: Color) -> some View {
        let isActive = store.activePlanID == id
        return Button { Task { await store.purchase(id) } } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(color.gradient, in: .rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title).font(.headline)
                        if isActive {
                            Text("이용 중")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(color, in: .capsule)
                        }
                    }
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                    Text("\(store.price(id)) / 월").font(.subheadline.weight(.bold)).foregroundStyle(color)
                }
                Spacer(minLength: 0)
                if !isActive {
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                }
            }
            .glassCard(interactive: !isActive)
            .overlay {
                if isActive { RoundedRectangle(cornerRadius: 26).stroke(color, lineWidth: 2) }
            }
        }
        .buttonStyle(.plain)
        .disabled(isActive || store.purchasingID != nil)
    }

    @ViewBuilder
    private func buyLabel(_ id: String, onDark: Bool) -> some View {
        if store.purchasingID == id {
            ProgressView().tint(onDark ? .white : Theme.accent)
                .frame(minWidth: 70)
        } else {
            Text(store.price(id))
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(onDark ? Color(hex: "#F5536B") : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(onDark ? Color.white : Theme.accent, in: .capsule)
        }
    }
}
