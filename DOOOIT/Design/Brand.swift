import SwiftUI

// MARK: - 브랜드 요소 (로고 · 워드마크 · 은은한 배경 빛)

/// 앱 로고 (흰 바탕 아이콘이라 앱 아이콘처럼 둥근 타일로 보여줌)
struct BrandLogo: View {
    var size: CGFloat = 96
    /// 뒤에 테마 색 빛 번짐
    var glow = false

    var body: some View {
        let radius = size * 0.26
        Image(Theme.current.logoName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 0.5)
            }
            .shadow(color: Theme.accent.opacity(glow ? 0.2 : 0), radius: size * 0.12, y: size * 0.05)
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

/// 바탕: 단색 + 맨 위에만 테마 색이 아주 옅게 (예전엔 빛 두 덩이가 흘렀음 → 움직임 없음)
struct BrandBackdrop: View {
    /// 예전 호출 모양을 위해 남김 (움직이지 않음)
    var animated = false
    /// 색조 세기 (0...1)
    var intensity: Double = 1

    @AppStorage(SettingsKey.themeColor) private var themeRaw = ThemeColor.standard.rawValue
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = ThemeColor.from(themeRaw)
        ZStack(alignment: .top) {
            Theme.base
            LinearGradient(colors: [theme.secondary.opacity((scheme == .dark ? 0.16 : 0.10) * intensity), theme.secondary.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 260)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
