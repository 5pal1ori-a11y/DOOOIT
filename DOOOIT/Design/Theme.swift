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

/// 포인트 색 테마 (연보라 / 연하늘 / 연두). 바탕은 눈부시지 않은 흰색으로 고정
enum ThemeColor: String, CaseIterable, Identifiable {
    case lavender, sky, mint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lavender: return L("연보라")
        case .sky: return L("연하늘")
        case .mint: return L("연두")
        }
    }

    /// 버튼·강조에 쓰는 색 (흰 글자가 읽히도록 살짝 진하게)
    var accent: Color {
        switch self {
        case .lavender: return Color(hex: "#7B68EE")
        case .sky: return Color(hex: "#3D9BE0")
        case .mint: return Color(hex: "#4CAF63")
        }
    }

    /// 배경에 은은하게 깔리는 색
    var soft: Color {
        switch self {
        case .lavender: return Color(hex: "#ECE8FF")
        case .sky: return Color(hex: "#E2F1FC")
        case .mint: return Color(hex: "#E6F5E1")
        }
    }

    var softer: Color {
        switch self {
        case .lavender: return Color(hex: "#F4F1FF")
        case .sky: return Color(hex: "#EEF7FD")
        case .mint: return Color(hex: "#F0F9EC")
        }
    }
}

enum Theme {
    /// 눈부시지 않은 흰색 바탕
    static let base = Color(light: "#F5F6F8", dark: "#000000")

    static var current: ThemeColor {
        ThemeColor(rawValue: UserDefaults.standard.string(forKey: SettingsKey.themeColor) ?? "") ?? .lavender
    }

    static var accent: Color { current.accent }
}

/// 깔끔한 바탕: 차분한 회색 위에, 맨 위에만 테마 색이 아주 옅게 (카드가 또렷하게 보이도록)
struct AppBackground: View {
    @AppStorage(SettingsKey.themeColor) private var themeRaw = ThemeColor.lavender.rawValue

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = ThemeColor(rawValue: themeRaw) ?? .lavender
        ZStack(alignment: .top) {
            Theme.base
            if scheme == .dark {
                // 어두운 화면: 테마 색을 아주 살짝만
                LinearGradient(colors: [theme.accent.opacity(0.16), theme.accent.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 320)
            } else {
                LinearGradient(colors: [theme.soft.opacity(0.9), theme.softer.opacity(0.5), Theme.base.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
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
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
