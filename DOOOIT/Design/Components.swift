import SwiftUI

// MARK: - 카드 스타일 (두잇 AI 화면과 같은 흰 카드)

extension View {
    /// 흰 카드: 얇은 테두리 + 아주 옅은 그림자 + 둥근 모서리 (또렷하고 가볍게)
    func softCard(cornerRadius: CGFloat = 20, padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .softCardBackground(cornerRadius: cornerRadius)
    }

    /// 패딩 없이 흰 카드 배경만 (목록 묶음 등)
    func softCardBackground(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(Palette.card, in: .rect(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

/// 강조 색 (예전엔 그라데이션 — 깔끔하게 한 색으로 통일. 이름은 그대로 두어 모든 화면에 한 번에 적용)
enum AccentGradient {
    static var linear: LinearGradient {
        LinearGradient(colors: [Theme.accent, Theme.accent], startPoint: .top, endPoint: .bottom)
    }
}

/// 섹션 제목 (아이콘 + 제목 + 우측 액세서리)
struct SectionHeader<Trailing: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(AccentGradient.linear, in: .rect(cornerRadius: 7))
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String, symbol: String) {
        self.init(title: title, symbol: symbol) { EmptyView() }
    }
}

/// 빈 상태 화면
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 68, height: 68)
                .background(Theme.accent.opacity(0.12), in: .circle)
                .padding(.bottom, 2)
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

/// 아이콘이 들어간 원형 배지
struct IconBadge: View {
    let symbol: String
    var color: Color = Theme.accent
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: .rect(cornerRadius: size * 0.32))
    }
}

/// 작은 상태 배지
struct TagLabel: View {
    let text: String
    var symbol: String? = nil
    var color: Color = Theme.accent

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.13), in: .capsule)
    }
}

/// 원형 진행률 링
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var color: Color = Theme.accent

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: progress)
        }
    }
}

/// 단어 카드 (예전 메모지 모양 → 깔끔한 흰 카드)
struct NotePaperCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 280)
            .padding(.vertical, 30)
            .padding(.horizontal, 24)
            .softCardBackground(cornerRadius: 24)
    }
}

/// 모눈 노트 배경 (오답노트용)
struct GridPaperBackground: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.notePage))
            let step: CGFloat = 22
            var x: CGFloat = 0
            while x < size.width {
                var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(p, with: .color(Palette.noteGrid), lineWidth: 0.7)
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(Palette.noteGrid), lineWidth: 0.7)
                y += step
            }
        }
    }
}

/// 처리 중 오버레이
struct ProcessingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
            }
            .padding(28)
            .background(Palette.card, in: .rect(cornerRadius: 26))
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        }
        .transition(.opacity)
    }
}

/// 테마 색 고르기 (연보라 / 연하늘 / 연두)
struct ThemePicker: View {
    @AppStorage(SettingsKey.themeColor) private var themeRaw = ThemeColor.lavender.rawValue

    private var current: ThemeColor { ThemeColor(rawValue: themeRaw) ?? .lavender }

    var body: some View {
        Picker(selection: $themeRaw) {
            ForEach(ThemeColor.allCases) { theme in
                Text(theme.title).tag(theme.rawValue)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 29, height: 29)
                    .background(current.accent, in: .rect(cornerRadius: 7))
                Text("테마 색")
            }
        }
        .pickerStyle(.menu)
        .onChange(of: themeRaw) { Haptics.tap() }
    }
}

// MARK: - 화면 공통 부품 (토스·애플 건강 앱처럼: 흰 카드, 큰 숫자, 목록 줄, 한 가지 강조색)

/// 구역 제목 + 오른쪽 작은 버튼 ("오늘의 플랜 · 전체 보기")
struct SectionTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            trailing
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// 목록 한 줄: 아이콘 · 제목 · 설명 · 오른쪽 값 · 꺾쇠
struct RowLabel: View {
    let symbol: String
    var color: Color = Theme.accent
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var chevron = true

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12), in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
            }
            if chevron {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// 카드 안 줄 사이 구분선 (아이콘 너비만큼 들여씀)
struct RowDivider: View {
    var body: some View { Divider().padding(.leading, 70) }
}

/// 큰 숫자 + 작은 설명 (요약 카드 아래 칸)
struct StatColumn: View {
    let value: String
    let label: String
    var color: Color = Palette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 가로 진행 막대 (둥근 끝)
struct LinearProgressBar: View {
    let value: Double
    var color: Color = Theme.accent
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.14))
                Capsule().fill(color).frame(width: max(height, geo.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: height)
        .animation(.smooth, value: value)
    }
}

/// 꽉 찬 강조 버튼 (화면에서 가장 중요한 동작 하나)
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.accent, in: .rect(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primaryFill: PrimaryButtonStyle { PrimaryButtonStyle() }
}
