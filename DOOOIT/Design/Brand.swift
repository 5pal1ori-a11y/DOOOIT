import SwiftUI

// MARK: - 브랜드 요소 (로고 · 워드마크 · 은은한 배경 빛)

/// 앱 로고 (흰 바탕 아이콘이라 앱 아이콘처럼 둥근 타일로 보여줌)
struct BrandLogo: View {
    var size: CGFloat = 96
    /// 뒤에 테마 색 빛 번짐
    var glow = true

    var body: some View {
        let radius = size * 0.26
        Image("AppLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.75)
            }
            .shadow(color: Theme.accent.opacity(glow ? 0.38 : 0), radius: size * 0.22, y: size * 0.12)
            .shadow(color: .black.opacity(0.08), radius: size * 0.04, y: size * 0.02)
            .accessibilityHidden(true)
    }
}

/// "MOTI" 워드마크 (가운데 OOO만 강조색)
struct BrandWordmark: View {
    var size: CGFloat = 40
    var tracking: CGFloat? = nil

    var body: some View {
        let o = Text("O").foregroundStyle(Theme.accent)
        Text("M\(o)TI")
            .font(.pt(size: size, weight: .heavy))
            .tracking(tracking ?? size * 0.12)
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel("MOTI")
    }
}

/// 바탕 + 테마 색 빛 두 덩이가 아주 천천히 흐르는 배경 (동작 줄이기 설정이면 멈춤)
struct BrandBackdrop: View {
    /// 빛이 천천히 움직이는지
    var animated = true
    /// 빛 세기 (0...1)
    var intensity: Double = 1

    @AppStorage(SettingsKey.themeColor) private var themeRaw = ThemeColor.lavender.rawValue
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        let theme = ThemeColor(rawValue: themeRaw) ?? .lavender
        let strength = (scheme == .dark ? 0.42 : 0.30) * intensity

        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                Theme.base
                glowBlob(theme.accent.opacity(strength), diameter: w * 1.25)
                    .offset(x: drift ? w * 0.22 : -w * 0.18, y: drift ? -geo.size.height * 0.30 : -geo.size.height * 0.22)
                glowBlob((scheme == .dark ? theme.accent : theme.soft).opacity(strength * (scheme == .dark ? 0.6 : 2.2)),
                         diameter: w * 1.1)
                    .offset(x: drift ? -w * 0.25 : w * 0.2, y: drift ? geo.size.height * 0.12 : geo.size.height * 0.2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard animated, !reduceMotion, !drift else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    private func glowBlob(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0)], center: .center,
                                 startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
    }
}

#Preview {
    ZStack {
        BrandBackdrop()
        VStack(spacing: 20) {
            BrandLogo(size: 110)
            BrandWordmark()
        }
    }
}
