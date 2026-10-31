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

/// 리퀴드 글라스가 잘 보이도록 은은한 메쉬 그라데이션 배경
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.55, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: scheme == .dark ? Self.dark : Self.light
        )
        .ignoresSafeArea()
    }

    private static let dark: [Color] = [
        .black, Color(hex: "#15122E"), .black,
        Color(hex: "#0D1729"), Color(hex: "#1C1745"), Color(hex: "#09090F"),
        .black, Color(hex: "#0F1A2B"), Color(hex: "#1A1033")
    ]

    private static let light: [Color] = [
        Color(hex: "#F6F6FB"), Color(hex: "#E8E6FF"), Color(hex: "#F6F6FB"),
        Color(hex: "#E2EFFF"), Color(hex: "#F1EEFF"), Color(hex: "#FFFFFF"),
        Color(hex: "#F6F6FB"), Color(hex: "#E9F6FF"), Color(hex: "#F3ECFF")
    ]
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
