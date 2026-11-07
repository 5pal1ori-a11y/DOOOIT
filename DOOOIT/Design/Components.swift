import SwiftUI

// MARK: - 카드 스타일 (모티 AI 화면과 같은 흰 카드)

extension View {
    /// 카드: 단색 면 + 헤어라인 테두리 (그림자 없음)
    func softCard(cornerRadius: CGFloat = Radius.card, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .softCardBackground(cornerRadius: cornerRadius)
    }

    /// 패딩 없이 카드 배경만 (목록 묶음 등). 예전에 큰 반지름을 넘긴 곳도 한 종류(14)로 맞춤
    func softCardBackground(cornerRadius: CGFloat = Radius.card) -> some View {
        let radius = min(cornerRadius, Radius.card)
        return self
            .background(Palette.card, in: .rect(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
    }
}

extension String {
    /// 선 아이콘 이름: 끝의 ".fill"을 뺌 (작은 아이콘은 탭 바처럼 얇은 선 모양으로 통일)
    var outlineSymbol: String { hasSuffix(".fill") ? String(dropLast(5)) : self }
}

/// 강조 색 (예전엔 그라데이션 — 깔끔하게 한 색으로 통일. 이름은 그대로 두어 모든 화면에 한 번에 적용)
enum AccentGradient {
    /// 테마의 세 색(진한 → 강조 → 밝은 색)이 이어지는 그라데이션
    static var linear: LinearGradient { Theme.current.fill }
}

/// 섹션 제목 (제목 + 우측 액세서리). symbol은 예전 호출 모양을 위해 남겨 두고 그리지 않음
struct SectionHeader<Trailing: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.pt(.headline).weight(.bold))
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

/// 빈 상태 화면: 회색 아이콘 + 한 줄
struct EmptyStateView: View {
    let symbol: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol.outlineSymbol)
                .environment(\.symbolVariants, .none)
                .font(.pt(size: 26, weight: .light))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 4)
            Text(title)
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

/// 아이콘 (예전엔 색 있는 칸 안에 넣었음 → 칸 없이 아이콘만. 카테고리 색처럼 뜻이 있는 색은 그대로)
struct IconBadge: View {
    let symbol: String
    var color: Color = Theme.accent
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol.outlineSymbol)
            .environment(\.symbolVariants, .none)
            .font(.pt(size: size * 0.5, weight: .regular))
            .foregroundStyle(color)
            .frame(width: size * 0.7, height: size * 0.7)
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
        .font(.pt(.caption2).weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color == Theme.accent ? Theme.secondaryFill : color.opacity(0.10),
                    in: .rect(cornerRadius: Radius.chip, style: .continuous))
    }
}

/// 원형 진행률 링
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var color: Color = Theme.accent
    /// 처음 나타날 때 0에서 값까지 차오름 (그 뒤로는 값이 바뀔 때마다 부드럽게)
    @State private var appeared = Motion.reduced

    var body: some View {
        let shown = appeared ? min(max(progress, 0), 1) : 0
        ZStack {
            Circle().stroke(Theme.secondaryFill, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.fill, value: shown)
        }
        .onAppear { appeared = true }
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
                Text(message).font(.pt(.subheadline).weight(.semibold)).foregroundStyle(Palette.ink)
            }
            .padding(28)
            .background(Palette.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
        }
        .transition(.opacity)
    }
}

/// 테마 고르기: 색 세 가지씩 묶은 카드 다섯 (모노 · 캔디 · 포레스트 · 오션 · 선셋)
/// 선셋은 친구 3명을 초대하면 열려요: 잠겨 있으면 자물쇠가 보이고, 누르면 안내만 떠요 (테마는 안 바뀜)
struct ThemePicker: View {
    @AppStorage(SettingsKey.themeColor) private var themeRaw = ThemeColor.standard.rawValue

    /// 잠긴 테마를 눌렀을 때 안내
    @State private var lockedInfo: ThemeColor?
    /// 초대에 성공하면 잠금 표시를 다시 그리기 위한 숫자
    @State private var refresh = 0

    private var current: ThemeColor { ThemeColor.from(themeRaw) }
    /// 아직 잠긴 테마 (안내 글을 보여 줄 것)
    private var lockedTheme: ThemeColor? { ThemeColor.allCases.first { $0.isLocked } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "paintpalette")
                    .font(.pt(size: 17, weight: .regular))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 24)
                Text("테마")
                Spacer(minLength: 0)
                Text(current.title)
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                ForEach(ThemeColor.allCases) { theme in
                    card(theme)
                }
            }
            if let lockedTheme {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.pt(size: 11, weight: .semibold))
                    Text(verbatim: "\(lockedTheme.title) · " + L("친구 \(lockedTheme.rewardTheme?.requiredInvites ?? 0)명 초대하면 열려요"))
                        .font(.pt(.caption))
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onChange(of: themeRaw) {
            Haptics.tap()
            AppIconSwitcher.apply(ThemeColor.from(themeRaw))
        }
        .onReceive(NotificationCenter.default.publisher(for: InviteRewards.changed)) { _ in refresh += 1 }
        .alert(lockedInfo.map { L("\($0.title) 테마는 아직 잠겨 있어요") } ?? "", isPresented: Binding(
            get: { lockedInfo != nil }, set: { if !$0 { lockedInfo = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            if let theme = lockedInfo {
                Text(L("초대한 친구 \(theme.rewardTheme?.requiredInvites ?? 0)명이 1시간 이상 공부하면 열려요. 지금은 \(InviteRewards.count())명이에요."))
            }
        }
    }

    private func card(_ theme: ThemeColor) -> some View {
        let isOn = theme == current
        let isLocked = theme.isLocked
        return Button {
            if isLocked {
                Haptics.tap()
                lockedInfo = theme
            } else {
                withAnimation(Motion.quick) { themeRaw = theme.rawValue }
            }
        } label: {
            VStack(spacing: 7) {
                // 진한 색 · 강조색 · 연한 색 세 줄
                HStack(spacing: 0) {
                    ForEach(Array(theme.swatches.enumerated()), id: \.offset) { _, color in
                        Rectangle().fill(color)
                    }
                }
                .frame(height: 38)
                .clipShape(.rect(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isOn ? theme.accent : Palette.line, lineWidth: isOn ? 2 : 0.5))
                .overlay {
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.pt(size: 11, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 24, height: 24)
                            .background(Palette.card.opacity(0.9), in: .circle)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isOn {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.pt(size: 15, weight: .bold))
                            .foregroundStyle(theme.onAccent, theme.accent)
                            .offset(x: 5, y: -5)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                Text(theme.title)
                    .font(.pt(.caption2).weight(isOn ? .bold : .medium))
                    .foregroundStyle(isOn ? Palette.ink : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(isLocked ? L("\(theme.title) 테마 (잠김)") : L("\(theme.title) 테마"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
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
                .font(.pt(size: 20, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            trailing
                .font(.pt(.subheadline))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// 목록 한 줄: 단색 아이콘 · 제목 · 설명 · 오른쪽 값 · 꺾쇠
/// (color는 예전 호출 모양 그대로 받지만, 빨강(위험)만 쓰고 나머지는 단색으로 맞춤)
struct RowLabel: View {
    let symbol: String
    var color: Color = Theme.accent
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var chevron = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol.outlineSymbol)
                .environment(\.symbolVariants, .none)
                .font(.pt(size: 18, weight: .regular))
                .foregroundStyle(color == Palette.danger ? color : Theme.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.pt(.body)).foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(subtitle).font(.pt(.footnote)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value).font(.pt(.subheadline)).foregroundStyle(.secondary).monospacedDigit()
            }
            if chevron {
                Image(systemName: "chevron.right").font(.pt(.footnote).weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

/// 카드 안 줄 사이 구분선 (아이콘 너비만큼 들여씀)
struct RowDivider: View {
    var body: some View { Rectangle().fill(Palette.line).frame(height: 0.5).padding(.leading, 52) }
}

/// 큰 숫자 + 작은 설명 (요약 카드 아래 칸)
struct StatColumn: View {
    let value: String
    let label: String
    var color: Color = Palette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.pt(size: 22, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .numberRoll(value)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(.pt(.footnote)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 가로 진행 막대 (둥근 끝)
struct LinearProgressBar: View {
    let value: Double
    var color: Color = Theme.accent
    var height: CGFloat = 8

    /// 처음 나타날 때 0에서 값까지 차오름
    @State private var appeared = Motion.reduced

    var body: some View {
        let shown = appeared ? min(max(value, 0), 1) : 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.secondaryFill)
                Capsule().fill(color).frame(width: max(height, geo.size.width * shown))
            }
        }
        .frame(height: height)
        .animation(Motion.fill, value: shown)
        .onAppear { appeared = true }
    }
}

/// 꽉 찬 강조 버튼 (화면에서 가장 중요한 동작 하나)
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pt(.body).weight(.semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.current.fill, in: .rect(cornerRadius: Radius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primaryFill: PrimaryButtonStyle { PrimaryButtonStyle() }
}


/// 바탕화면 앱 아이콘을 테마 색에 맞춰 바꿈 (모노가 기본 아이콘, 나머지는 대체 아이콘 · 잠긴 테마는 기본 아이콘)
/// iOS가 바꿀 때마다 "아이콘을 변경했습니다" 안내를 한 번 보여 줘요
enum AppIconSwitcher {
    static func iconName(for theme: ThemeColor) -> String? {
        // 잠긴 테마(복원한 백업 등)의 아이콘은 쓰지 않고 기본(모노) 아이콘
        let shown = theme.isLocked ? ThemeColor.standard : theme.resolved
        return shown == .mono ? nil : "AppIcon-\(shown.rawValue)"
    }

    @MainActor static func apply(_ theme: ThemeColor) {
        let app = UIApplication.shared
        let wanted = iconName(for: theme)
        guard app.supportsAlternateIcons, app.alternateIconName != wanted else { return }
        app.setAlternateIconName(wanted) { _ in }
    }
}
