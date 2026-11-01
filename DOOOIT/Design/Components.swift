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
            .background(Color.white, in: .rect(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

/// 테마 색 그라데이션 (강조 카드·버튼용)
enum AccentGradient {
    static var linear: LinearGradient {
        LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
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

/// 공책 느낌의 배경 (줄 + 빨간 여백선)
struct NotePaperBackground: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.paper))
            var y: CGFloat = 56
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(line, with: .color(Palette.paperLine), lineWidth: 1)
                y += 36
            }
            var margin = Path()
            margin.move(to: CGPoint(x: 34, y: 0))
            margin.addLine(to: CGPoint(x: 34, y: size.height))
            ctx.stroke(margin, with: .color(Palette.paperMargin), lineWidth: 1.5)
        }
    }
}

/// 메모지 카드
struct NotePaperCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 280)
            .padding(.vertical, 30)
            .padding(.leading, 50)
            .padding(.trailing, 24)
            .background { NotePaperBackground() }
            .clipShape(.rect(cornerRadius: 22))
            .overlay(alignment: .top) {
                // 테이프
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.accent.opacity(0.35))
                    .frame(width: 86, height: 22)
                    .rotationEffect(.degrees(-3))
                    .offset(y: -10)
            }
            .shadow(color: .black.opacity(0.2), radius: 18, y: 10)
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
            .background(Color.white, in: .rect(cornerRadius: 26))
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
            Label {
                Text("테마 색")
            } icon: {
                Image(systemName: "circle.fill").foregroundStyle(current.accent)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: themeRaw) { Haptics.tap() }
    }
}
