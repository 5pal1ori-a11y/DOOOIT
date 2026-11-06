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
    static let ink = Color(light: "#1F2433", dark: "#F2F3F7")
    /// 카드 바탕 (흰색 / 다크 모드 진회색)
    static let card = Color(light: "#FFFFFF", dark: "#1C1C1E")
    /// 카드 안 한 단계 더 들어간 칸
    static let cardInset = Color(light: "#F2F3F6", dark: "#2C2C2E")
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
    /// 아이콘 바탕용 옅은 파스텔 (어두운 화면에서는 조금 더 옅게)
    var pastel: Color {
        let base = UIColor(self)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? base.withAlphaComponent(0.16) : base.withAlphaComponent(0.14) })
    }
}

// MARK: - Background

/// 테마: 색 세 가지씩 (진한 색 · 강조색 · 연한 색). 바탕은 눈부시지 않은 흰색으로 고정
/// - 진한 색: 버튼 그라데이션의 어두운 쪽 · 강조색: 버튼·아이콘·그래프 · 연한 색: 바탕 빛 번짐·옅은 칸
enum ThemeColor: String, CaseIterable, Identifiable {
    case midnight, forest, twilight, ocean
    /// 예전(한 가지 색) 테마 값: 지금 값을 지우지 않고 가장 비슷한 새 테마로 이어서 씀
    case lavender, sky, mint

    /// 고르는 화면에 보이는 테마 (예전 값은 제외)
    static var allCases: [ThemeColor] { [.midnight, .forest, .twilight, .ocean] }
    /// 처음 쓰는 테마 (앱 로고와 같은 보라 계열)
    static let standard: ThemeColor = .twilight

    var id: String { resolved.rawValue }

    /// 이 테마 색으로 만든 앱 로고 (Assets의 AppLogo-테마이름)
    var logoName: String { "AppLogo-\(resolved.rawValue)" }

    /// 예전 값을 새 테마로 바꾼 것
    var resolved: ThemeColor {
        switch self {
        case .lavender: return .twilight
        case .sky: return .ocean
        case .mint: return .forest
        default: return self
        }
    }

    /// 저장된 글자 → 테마 (모르는 값이면 기본)
    static func from(_ raw: String) -> ThemeColor {
        (ThemeColor(rawValue: raw) ?? .standard).resolved
    }

    var title: String {
        switch resolved {
        case .midnight: return L("미드나잇")
        case .forest: return L("포레스트")
        case .twilight: return L("트와일라이트")
        default: return L("오션")
        }
    }

    /// 진한 색 (딥네이비 · 다크그린 · 차콜 · 네이비)
    var deep: Color {
        switch resolved {
        case .midnight: return Color(hex: "#151B52")
        case .forest: return Color(hex: "#14532D")
        case .twilight: return Color(hex: "#2B2B3D")
        default: return Color(hex: "#10306B")
        }
    }

    /// 버튼·강조에 쓰는 색 (인디고 · 민트 · 퍼플 · 스카이블루, 흰 글자가 읽히도록 살짝 진하게)
    var accent: Color {
        switch resolved {
        case .midnight: return Color(hex: "#4F5BD5")
        case .forest: return Color(hex: "#1E9E74")
        case .twilight: return Color(hex: "#7C4DDB")
        default: return Color(hex: "#2E8FE6")
        }
    }

    /// 연한 색 (라벤더 · 세이지 · 라이트 바이올렛 · 아이스)
    var light: Color {
        switch resolved {
        case .midnight: return Color(hex: "#B8B5F5")
        case .forest: return Color(hex: "#B7C9A8")
        case .twilight: return Color(hex: "#CBB8F7")
        default: return Color(hex: "#D4ECFF")
        }
    }

    /// 세 색이 이어지는 그라데이션 (진한 → 강조 → 연한)
    var spectrum: LinearGradient {
        LinearGradient(colors: [deep, accent, light], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 연한 색을 강조색에 40%쯤 섞은 색 (흰 글자가 올라가는 곳의 세 번째 색)
    var lift: Color {
        switch resolved {
        case .midnight: return Color(hex: "#797FE2")
        case .forest: return Color(hex: "#5BAF88")
        case .twilight: return Color(hex: "#9C72E6")
        default: return Color(hex: "#70B4F0")
        }
    }

    /// 꽉 찬 버튼 바탕: 세 색 그라데이션 (진한 → 강조 → 살짝 밝은 색). 흰 글자가 읽히도록 밝은 색은 끝에만
    var fill: LinearGradient {
        LinearGradient(stops: [.init(color: deep, location: 0), .init(color: accent, location: 0.58), .init(color: lift, location: 1)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 배경에 은은하게 깔리는 색
    var soft: Color {
        switch resolved {
        case .midnight: return Color(hex: "#E7E6FB")
        case .forest: return Color(hex: "#E3EEDD")
        case .twilight: return Color(hex: "#EEE8FC")
        default: return Color(hex: "#E0F0FD")
        }
    }

    var softer: Color {
        switch resolved {
        case .midnight: return Color(hex: "#F1F0FD")
        case .forest: return Color(hex: "#EEF5EA")
        case .twilight: return Color(hex: "#F6F2FE")
        default: return Color(hex: "#EDF7FE")
        }
    }

    /// 위젯·워치에 넘기는 강조색
    var accentHex: String {
        switch resolved {
        case .midnight: return "#4F5BD5"
        case .forest: return "#1E9E74"
        case .twilight: return "#7C4DDB"
        default: return "#2E8FE6"
        }
    }
}

enum Theme {
    /// 눈부시지 않은 흰색 바탕
    static let base = Color(light: "#F5F6F8", dark: "#000000")

    static var current: ThemeColor {
        ThemeColor.from(UserDefaults.standard.string(forKey: SettingsKey.themeColor) ?? "")
    }

    static var accent: Color { current.accent }
}

/// 깔끔한 바탕: 차분한 회색 위에, 맨 위에만 테마 색이 아주 옅게 (카드가 또렷하게 보이도록)
struct AppBackground: View {
    @AppStorage(SettingsKey.themeColor) private var themeRaw = ThemeColor.standard.rawValue

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = ThemeColor.from(themeRaw)
        ZStack(alignment: .top) {
            Theme.base
            if scheme == .dark {
                // 어두운 화면: 테마 색을 아주 살짝만 (왼쪽 강조색 · 오른쪽 진한 색)
                LinearGradient(colors: [theme.accent.opacity(0.18), theme.deep.opacity(0.22), theme.accent.opacity(0)],
                               startPoint: .topLeading, endPoint: .bottom)
                    .frame(height: 340)
            } else {
                // 밝은 화면: 옅은 바탕 위에 연한 색 빛이 오른쪽 위에서 번짐
                LinearGradient(colors: [theme.soft.opacity(0.9), theme.softer.opacity(0.5), Theme.base.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 320)
                RadialGradient(colors: [theme.light.opacity(0.45), theme.light.opacity(0)],
                               center: .topTrailing, startRadius: 0, endRadius: 280)
                    .frame(height: 320)
            }
        }
        .ignoresSafeArea()
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
    /// 리퀴드 글라스 카드
    func glassCard(cornerRadius: CGFloat = 26, padding: CGFloat = 18, tint: Color? = nil, interactive: Bool = false) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(makeGlass(tint: tint, interactive: interactive), in: .rect(cornerRadius: cornerRadius))
    }

    /// 리퀴드 글라스 입력 필드
    func glassField() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
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
