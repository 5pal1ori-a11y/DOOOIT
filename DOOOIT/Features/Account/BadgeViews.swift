import SwiftData
import SwiftUI

extension BadgeBook.Badge {
    var color: Color { Color(hex: colorHex) }
}

/// 배지 진열장: 받은 배지는 파스텔, 아직이면 회색 테두리 + 진행률
struct BadgeShelfView: View {
    @Environment(\.modelContext) private var context
    @State private var center = BadgeCenter.shared
    @State private var selected: BadgeBook.Badge?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                summary
                    .appearAnimation()
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(BadgeBook.all) { badge in
                        Button { selected = badge } label: {
                            BadgeTile(badge: badge, unlockedAt: center.unlocked[badge.id], stats: center.stats)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .appearAnimation(delay: 0.08)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("배지")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { center.check(context: context) }
        .sheet(item: $selected) { badge in
            BadgeDetailSheet(badge: badge, unlockedAt: center.unlocked[badge.id], stats: center.stats)
                .presentationDetents([.height(320)])
                .presentationCornerRadius(32)
        }
    }

    /// 모은 개수 + 다음 배지까지
    private var summary: some View {
        let count = BadgeBook.all.filter { center.isUnlocked($0) }.count
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(count)")
                    .font(.pt(size: 34, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text("/ \(BadgeBook.all.count)개 모았어요")
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let next = center.next {
                HStack(spacing: 12) {
                    IconBadge(symbol: next.symbol, color: next.color, size: 40)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("다음 · \(next.title)").font(.pt(.subheadline).weight(.bold)).foregroundStyle(Palette.ink)
                            Spacer()
                            Text(next.progressText(center.stats)).font(.pt(.caption).weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
                        }
                        LinearProgressBar(value: next.progress(center.stats), color: next.color, height: 7)
                    }
                }
            }
        }
        .softCard(cornerRadius: 24, padding: 18)
    }
}

/// 배지 하나 (동그란 네모 + 이름 + 날짜 또는 진행)
struct BadgeTile: View {
    let badge: BadgeBook.Badge
    let unlockedAt: Date?
    let stats: BadgeBook.Stats
    var size: CGFloat = 76

    var body: some View {
        let isOn = unlockedAt != nil
        VStack(spacing: 7) {
            BadgeMedal(badge: badge, isOn: isOn, size: size)
            Text(badge.title)
                .font(.pt(.caption).weight(.bold))
                .foregroundStyle(isOn ? Palette.ink : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Group {
                if let unlockedAt {
                    Text(unlockedAt.kr("M.d"))
                } else {
                    Text(badge.progressText(stats))
                }
            }
            .font(.pt(.caption2))
            .foregroundStyle(.tertiary)
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// 배지 그림: 받으면 파스텔 바탕 + 색 아이콘, 아직이면 회색 테두리 + 회색 아이콘 (진행만큼 아래에서 옅게 차오름)
struct BadgeMedal: View {
    let badge: BadgeBook.Badge
    let isOn: Bool
    var size: CGFloat = 76
    var bounce = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
        Image(systemName: badge.symbol)
            .environment(\.symbolVariants, .none)
            .font(.pt(size: size * 0.38, weight: .regular))
            .foregroundStyle(isOn ? badge.color : Color.secondary.opacity(0.55))
            .symbolEffect(.bounce, value: bounce)
            .frame(width: size, height: size)
            .background {
                if isOn {
                    shape.fill(badge.color.pastel)
                    shape.strokeBorder(badge.color.opacity(0.25), lineWidth: 1)
                } else {
                    shape.strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                }
            }
    }
}

/// 배지를 누르면: 큰 그림 + 받는 방법 + 날짜 또는 진행
struct BadgeDetailSheet: View {
    let badge: BadgeBook.Badge
    let unlockedAt: Date?
    let stats: BadgeBook.Stats
    @State private var bounce = 0

    var body: some View {
        VStack(spacing: 14) {
            BadgeMedal(badge: badge, isOn: unlockedAt != nil, size: 96, bounce: bounce)
                .padding(.top, 28)
            Text(badge.title).font(.pt(.title3).weight(.bold)).foregroundStyle(Palette.ink)
            Text(badge.detail).font(.pt(.subheadline)).foregroundStyle(.secondary)
            if let unlockedAt {
                TagLabel(text: unlockedAt.kr("yyyy년 M월 d일"), symbol: "checkmark", color: badge.color)
            } else {
                VStack(spacing: 6) {
                    LinearProgressBar(value: badge.progress(stats), color: badge.color, height: 8)
                    Text(badge.progressText(stats)).font(.pt(.caption).weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
                }
                .frame(width: 200)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .onAppear { if unlockedAt != nil { bounce += 1 } }
    }
}

/// 새 배지 축하: 위에서 살짝 내려오는 카드 (누르면 닫힘)
struct BadgeToastHost: View {
    @State private var center = BadgeCenter.shared
    @State private var bounce = 0

    var body: some View {
        ZStack {
            if let toast = center.toast {
                Button { center.dismissToast() } label: {
                    HStack(spacing: 12) {
                        BadgeMedal(badge: toast.badge, isOn: true, size: 46, bounce: bounce)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("새 배지!").font(.pt(.caption).weight(.semibold)).foregroundStyle(toast.badge.color)
                            Text(toast.badge.title).font(.pt(.headline)).foregroundStyle(Palette.ink)
                        }
                        Spacer(minLength: 0)
                        if toast.more > 0 {
                            TagLabel(text: "+\(toast.more)", color: toast.badge.color)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .softCardBackground(cornerRadius: 22)
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                .task(id: toast.id) {
                    try? await Task.sleep(for: .milliseconds(350))
                    bounce += 1
                    try? await Task.sleep(for: .milliseconds(900))
                    bounce += 1
                }
                .accessibilityLabel("새 배지 \(toast.badge.title)")
            }
        }
        .animation(Motion.bouncy, value: center.toast)
    }
}

/// 홈의 작은 "최근 배지" 칩
struct RecentBadgeChip: View {
    @State private var center = BadgeCenter.shared

    var body: some View {
        if let badge = center.latest {
            NavigationLink { BadgeShelfView() } label: {
                HStack(spacing: 10) {
                    BadgeMedal(badge: badge, isOn: true, size: 30)
                    Text("최근 배지").font(.pt(.subheadline)).foregroundStyle(.secondary)
                    Text(badge.title).font(.pt(.subheadline).weight(.bold)).foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                    Text("\(center.unlocked.count)/\(BadgeBook.all.count)")
                        .font(.pt(.caption).weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
                    Image(systemName: "chevron.right").font(.pt(.caption).weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .softCardBackground(cornerRadius: 18)
            }
            .buttonStyle(.pressable)
        }
    }
}
