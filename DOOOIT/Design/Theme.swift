import SwiftUI
import UIKit

// MARK: - Colors

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

extension UIColor {
    convenience init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    /// 밝은 화면 / 어두운 화면(다크 모드)에서 다른 색
    init(light: String, dark: String) {
        let lightColor = UIColor(hex: light), darkColor = UIColor(hex: dark)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? darkColor : lightColor })
    }
}

/// 화면 모드 (시스템 설정 따르기 / 밝게 / 어둡게)
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return L("시스템 설정")
        case .light: return L("밝게")
        case .dark: return L("어둡게")
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    static let key = "appearanceMode"
}

/// 모서리 반지름 (한 종류씩만 씀)
enum Radius {
    static let card: CGFloat = 14
    static let field: CGFloat = 10
    static let button: CGFloat = 14
    static let chip: CGFloat = 6
}

enum Palette {
    static let swatches = [
        "#6C63FF", "#3B82F6", "#06B6D4", "#10B981", "#84CC16", "#F59E0B",
        "#F97316", "#EF4444", "#EC4899", "#A855F7", "#64748B", "#1F2937"
    ]
    static let paper = Color(hex: "#FFFBEF")
    static let paperLine = Color(hex: "#CFDCEC")
    static let paperMargin = Color(hex: "#F2A7A7")
    static let notePage = Color(hex: "#FFFFFF")
    static let noteGrid = Color(hex: "#E7ECF3")
    /// 글자 색 (다크 모드에서는 밝게)
    static var ink: Color { Theme.current.ink }
    /// 카드 바탕 (흰색 / 다크 모드 진회색)
    static let card = Color(light: "#FFFFFF", dark: "#1C1C1E")
    /// 카드 안 한 단계 더 들어간 칸
    static let cardInset = Color(light: "#F2F3F6", dark: "#2C2C2E")
    /// 줄 · 카드 테두리 (헤어라인)
    static var line: Color { Theme.current.line }
    static let success = Color(hex: "#22C55E")
    static let danger = Color(hex: "#EF4444")
    static let warning = Color(hex: "#F59E0B")

    // 아기자기한 파스텔 포인트 (아이콘 색 · 보라 강조색 옆에 함께 씀)
    static let mint = Color(hex: "#2FBF8F")
    static let peach = Color(hex: "#FF8A5C")
    static let pink = Color(hex: "#F2709C")
    static let butter = Color(hex: "#F2B233")
    static let sky = Color(hex: "#4FA3F7")
}

extension Color {
    /// 옅은 색 바탕 (어두운 화면에서는 조금 더 옅게)
    var pastel: Color {
        let base = UIColor(self)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? base.withAlphaComponent(0.16) : base.withAlphaComponent(0.14) })
    }
}

// MARK: - Background

/// 테마 다섯: 모노(옅은 회색 · 하양 · 검정) · 캔디(노랑 · 핑크 · 찐한 핑크) · 포레스트 · 오션 · 선셋(코랄 오렌지 · 옅은 복숭아 · 짙은 갈색 글자)
/// 선셋은 친구 3명을 초대하면 열려요 (InviteRewards). 잠겨 있으면 모노로 보여 줘요
/// 색은 "역할"별로 나눠 화면 곳곳에 씀 (한 가지 강조색에 몰아 쓰지 않음)
/// - primary(accent): 주요 버튼 · 선택 · 진행 채움 · 링크 글자 (이 위의 글자는 onAccent)
/// - secondary: 아이콘 · 보조 칩 · 진행 중간 색 · 그래프의 지난 값
/// - highlight: 오늘 표시 · 랭킹의 내 줄 · 달성 표시 (이 위의 글자는 onHighlight)
/// - 바탕(base) · 글자(ink) · 선(line)도 테마마다 다름
enum ThemeColor: String, CaseIterable, Identifiable {
    case mono, candy, forest, ocean
    /// 친구 초대 보상 테마
    case sunset
    /// 예전 테마 값: 지우지 않고 가장 비슷한 새 테마로 이어서 씀 (보라 계열은 모노로)
    case midnight, twilight, lavender, sky, mint

    /// 고르는 화면에 보이는 테마 (예전 값은 제외)
    static var allCases: [ThemeColor] { [.mono, .candy, .forest, .ocean, .sunset] }
    /// 처음 쓰는 테마
    static let standard: ThemeColor = .mono

    var id: String { resolved.rawValue }

    /// 이 테마 색으로 만든 앱 로고 (Assets의 AppLogo-테마이름)
    var logoName: String { "AppLogo-\(resolved.rawValue)" }

    /// 예전 값을 새 테마로 바꾼 것
    var resolved: ThemeColor {
        switch self {
        case .midnight, .twilight, .lavender: return .mono
        case .sky: return .ocean
        case .mint: return .forest
        default: return self
        }
    }

    /// 저장된 글자 → 테마 (모르는 값이면 기본 · 아직 잠긴 테마(예: 복원한 백업)도 기본)
    static func from(_ raw: String) -> ThemeColor {
        let theme = (ThemeColor(rawValue: raw) ?? .standard).resolved
        return theme.isLocked ? .standard : theme
    }

    /// 초대로 여는 테마라면 그 보상 (아니면 nil)
    var rewardTheme: InviteRewards.RewardTheme? {
        resolved == .sunset ? .newTheme : nil
    }

    /// 아직 못 쓰는 테마인지 (친구를 더 초대해야 함)
    var isLocked: Bool {
        guard let reward = rewardTheme else { return false }
        return !InviteRewards.isThemeUnlocked(reward)
    }

    /// 잠긴 테마가 열릴 때까지 남은 친구 수 (열려 있으면 0)
    var invitesRemaining: Int {
        rewardTheme.map { InviteRewards.remaining(for: $0) } ?? 0
    }

    var title: String {
        switch resolved {
        case .mono: return L("모노")
        case .candy: return L("캔디")
        case .forest: return L("포레스트")
        case .sunset: return L("선셋")
        default: return L("오션")
        }
    }

    private func pick(mono: (String, String), candy: (String, String), forest: (String, String), ocean: (String, String),
                      sunset: (String, String)) -> Color {
        let v: (String, String)
        switch resolved {
        case .mono: v = mono
        case .candy: v = candy
        case .forest: v = forest
        case .sunset: v = sunset
        default: v = ocean
        }
        return Color(light: v.0, dark: v.1)
    }

    // MARK: 바탕 · 글자 · 선

    /// 화면 바탕
    var base: Color {
        pick(mono: ("#F2F2F4", "#000000"), candy: ("#FFF7FA", "#0D0709"),
             forest: ("#F5F6F8", "#000000"), ocean: ("#F5F6F8", "#000000"),
             sunset: ("#FFF6EF", "#0E0907"))
    }

    /// 글자 색
    var ink: Color {
        pick(mono: ("#111111", "#F2F3F7"), candy: ("#1A1418", "#F7F1F4"),
             forest: ("#1F2433", "#F2F3F7"), ocean: ("#1F2433", "#F2F3F7"),
             sunset: ("#2B1810", "#FBEFE6"))
    }

    /// 카드 테두리 · 구분선 (헤어라인)
    var line: Color {
        pick(mono: ("#E0E0E4", "#2E2E31"), candy: ("#F3DCE6", "#33222B"),
             forest: ("#E3E5EA", "#2E2E31"), ocean: ("#E3E5EA", "#2E2E31"),
             sunset: ("#F1DCCB", "#34241C"))
    }

    // MARK: 역할 색

    /// 주요 버튼 · 선택 표시 · 진행 채움 (모노: 밝게 검정 / 어둡게 흰색)
    var accent: Color {
        pick(mono: ("#111111", "#FFFFFF"), candy: ("#D81B60", "#D81B60"),
             forest: ("#1E9E74", "#1E9E74"), ocean: ("#2E8FE6", "#2E8FE6"),
             sunset: ("#C2410D", "#FF7F50"))
    }

    /// accent 위에 얹는 글자 · 아이콘 색 (모노 어둡게만 검정)
    var onAccent: Color {
        pick(mono: ("#FFFFFF", "#111111"), candy: ("#FFFFFF", "#FFFFFF"),
             forest: ("#FFFFFF", "#FFFFFF"), ocean: ("#FFFFFF", "#FFFFFF"),
             sunset: ("#FFFFFF", "#2A1007"))
    }

    /// 보조: 아이콘 · 칩 · 그래프의 지난 값 · 진행 중간 색
    var secondary: Color {
        pick(mono: ("#8E8E93", "#8E8E93"), candy: ("#FF6FA5", "#FF7FB0"),
             forest: ("#5BAF88", "#5BAF88"), ocean: ("#70B4F0", "#70B4F0"),
             sunset: ("#D9703F", "#FF9C73"))
    }

    /// 보조 색 바탕 (칩 · 진행 막대 바탕 · 옅은 칸)
    var secondaryFill: Color {
        pick(mono: ("#E4E4E7", "#2C2C2E"), candy: ("#FFE0EC", "#2B1A22"),
             forest: ("#E3EEDD", "#1F2E25"), ocean: ("#E0F0FD", "#1A2C3E"),
             sunset: ("#FFEBDD", "#2E1C14"))
    }

    /// 하이라이트: 오늘 · 내 줄 · 달성 (캔디는 노랑, 모노는 회색 바탕)
    var highlight: Color {
        pick(mono: ("#E4E4E7", "#3A3A3C"), candy: ("#FFD84D", "#FFD84D"),
             forest: ("#CFE3B8", "#2E4A3A"), ocean: ("#CFE6FB", "#1F3C5E"),
             sunset: ("#FFCFA0", "#5E361D"))
    }

    /// highlight 위의 글자
    var onHighlight: Color {
        pick(mono: ("#111111", "#F2F3F7"), candy: ("#1A1418", "#1A1418"),
             forest: ("#14301F", "#E6F2DD"), ocean: ("#0E2A55", "#E1EEFB"),
             sunset: ("#3A1D08", "#FFE9DA"))
    }

    // MARK: 예전 이름 (역할 색에서 유도 · 계속 동작)

    /// 진한 색 (그라데이션 시작)
    var deep: Color {
        pick(mono: ("#111111", "#FFFFFF"), candy: ("#D81B60", "#D81B60"),
             forest: ("#14532D", "#14532D"), ocean: ("#10306B", "#10306B"),
             sunset: ("#B0370A", "#F2683A"))
    }

    /// 연한 색 (견본 · 옅은 칸)
    var light: Color {
        pick(mono: ("#D1D1D6", "#3A3A3C"), candy: ("#FFB3D1", "#FFB3D1"),
             forest: ("#B7C9A8", "#B7C9A8"), ocean: ("#D4ECFF", "#D4ECFF"),
             sunset: ("#FFC9A8", "#FFB48C"))
    }

    /// 그라데이션 끝 색 (흰 글자가 올라가는 곳의 세 번째 색)
    var lift: Color {
        pick(mono: ("#6B6B72", "#C7C7CC"), candy: ("#F27AA8", "#F27AA8"),
             forest: ("#5BAF88", "#5BAF88"), ocean: ("#70B4F0", "#70B4F0"),
             sunset: ("#E96F2F", "#FFA27A"))
    }

    /// 그라데이션 가운데 색
    private var mid: Color {
        pick(mono: ("#34343A", "#E4E4E7"), candy: ("#E8407F", "#E8407F"),
             forest: ("#1E9E74", "#1E9E74"), ocean: ("#2E8FE6", "#2E8FE6"),
             sunset: ("#D9531C", "#FF7F50"))
    }

    /// 항상 어두운 화면(타이머)에서 쓰는 강조색 (위의 글자는 검정)
    var timerAccent: Color {
        switch resolved {
        case .mono: return Color(hex: "#FFFFFF")
        case .candy: return Color(hex: "#FF5C93")
        case .forest: return Color(hex: "#3DD68C")
        case .sunset: return Color(hex: "#FF8A57")
        default: return Color(hex: "#4DA3FF")
        }
    }

    /// 견본 세 칸 (고르는 화면)
    var swatches: [Color] {
        switch resolved {
        case .mono: return [Color(hex: "#111111"), Color(hex: "#E4E4E7"), Color(hex: "#FFFFFF")]
        case .candy: return [Color(hex: "#D81B60"), Color(hex: "#FF6FA5"), Color(hex: "#FFD84D")]
        case .sunset: return [Color(hex: "#C2410D"), Color(hex: "#F59B6B"), Color(hex: "#FFD9BF")]
        default: return [deep, accent, light]
        }
    }

    /// 세 색이 이어지는 그라데이션 (진한 → 강조 → 연한)
    var spectrum: LinearGradient {
        LinearGradient(colors: [deep, mid, lift], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 꽉 찬 버튼 바탕: 세 색 그라데이션 (진한 → 가운데 → 끝 색). 위의 글자는 onAccent
    var fill: LinearGradient {
        LinearGradient(stops: [.init(color: deep, location: 0), .init(color: mid, location: 0.58), .init(color: lift, location: 1)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 배경에 은은하게 깔리는 색
    var soft: Color { secondaryFill }

    var softer: Color {
        pick(mono: ("#EEEEF0", "#1C1C1E"), candy: ("#FFF0F6", "#2A121C"),
             forest: ("#EEF5EA", "#18241D"), ocean: ("#EDF7FE", "#15222F"),
             sunset: ("#FFF1E7", "#1F130E"))
    }

    /// 위젯·워치에 넘기는 강조색 (모노 #111111 · 캔디 #D81B60 · 선셋 #C2410D)
    var accentHex: String {
        switch resolved {
        case .mono: return "#111111"
        case .candy: return "#D81B60"
        case .forest: return "#1E9E74"
        case .sunset: return "#C2410D"
        default: return "#2E8FE6"
        }
    }
}

enum Theme {
    /// 화면 바탕 (테마마다 다름)
    static var base: Color { current.base }

    static var current: ThemeColor {
        ThemeColor.from(UserDefaults.standard.string(forKey: SettingsKey.themeColor) ?? "")
    }

    static var accent: Color { current.accent }
    static var onAccent: Color { current.onAccent }
    static var secondary: Color { current.secondary }
    static var secondaryFill: Color { current.secondaryFill }
    static var highlight: Color { current.highlight }
    static var onHighlight: Color { current.onHighlight }
}

/// 바탕: 단색 (빛 번짐 없음). 카드와 헤어라인이 또렷하게 보이도록 밝은 회색 / 검정
struct AppBackground: View {
    /// 테마를 고르면 바로 바뀌도록 구독
    @AppStorage(SettingsKey.themeColor) private var themeRaw = ThemeColor.standard.rawValue

    var body: some View {
        ThemeColor.from(themeRaw).base.ignoresSafeArea()
    }
}

// MARK: - Glass helpers

func makeGlass(tint: Color? = nil, interactive: Bool = false) -> Glass {
    var glass: Glass = .regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

extension View {
    /// 카드 (이름은 예전 그대로 · 이제는 유리 대신 단색 카드 + 헤어라인). tint가 있으면 아주 옅게 깔림
    func glassCard(cornerRadius: CGFloat = 14, padding: CGFloat = 16, tint: Color? = nil, interactive: Bool = false) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if let tint { RoundedRectangle(cornerRadius: min(cornerRadius, Radius.card), style: .continuous).fill(tint.opacity(0.08)) }
            }
            .softCardBackground(cornerRadius: cornerRadius)
    }

    /// 입력 필드: 회색 칸 (유리 아님)
    func glassField() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Palette.cardInset, in: .rect(cornerRadius: Radius.field, style: .continuous))
    }

    func errorAlert(_ message: Binding<String?>, title: String? = nil) -> some View {
        alert(
            title ?? L("알림"),
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

// MARK: - Haptics

enum Haptics {
    /// 맞았을 때: 진동 + 효과음 (효과음은 설정에서 끌 수 있음)
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task { @MainActor in SoundFX.shared.play(.correct) }
    }
    /// 틀렸을 때
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        Task { @MainActor in SoundFX.shared.play(.wrong) }
    }
    /// 한 세트를 끝냈을 때
    static func celebrate() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task { @MainActor in SoundFX.shared.play(.complete) }
    }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
