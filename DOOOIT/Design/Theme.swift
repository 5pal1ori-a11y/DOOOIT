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
    static let ink = Color(hex: "#1F2433")
    static let success = Color(hex: "#22C55E")
    static let danger = Color(hex: "#EF4444")
    static let warning = Color(hex: "#F59E0B")
}

// MARK: - Background

/// 포인트 색 테마 (연보라 / 연하늘 / 연두). 바탕은 눈부시지 않은 흰색으로 고정
enum ThemeColor: String, CaseIterable, Identifiable {
    case lavender, sky, mint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lavender: return "연보라"
        case .sky: return "연하늘"
        case .mint: return "연두"
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
    static let base = Color(hex: "#F5F6F8")

    static var current: ThemeColor {
        ThemeColor(rawValue: UserDefaults.standard.string(forKey: SettingsKey.themeColor) ?? "") ?? .lavender
    }

    static var accent: Color { current.accent }
}

/// 깔끔한 바탕: 차분한 회색 위에, 맨 위에만 테마 색이 아주 옅게 (카드가 또렷하게 보이도록)
struct AppBackground: View {
    @AppStorage(SettingsKey.themeColor) private var themeRaw = ThemeColor.lavender.rawValue

    var body: some View {
        let theme = ThemeColor(rawValue: themeRaw) ?? .lavender
        ZStack(alignment: .top) {
            Theme.base
            LinearGradient(colors: [theme.soft.opacity(0.9), theme.softer.opacity(0.5), Theme.base.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 320)
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

    func errorAlert(_ message: Binding<String?>, title: String = "알림") -> some View {
        alert(
            title,
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
