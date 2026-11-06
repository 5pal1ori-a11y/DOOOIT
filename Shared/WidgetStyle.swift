import SwiftUI
import WidgetKit

// 위젯 공통 모양: 색 · 머리글 · 배경 (위젯 확장과 앱의 미리보기 화면이 같이 씀)

extension WidgetSnapshot {
    static func color(_ hex: String) -> Color {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var accent: Color { WidgetSnapshot.color(accentHex) }
}

extension WidgetFamily {
    var isAccessory: Bool {
        switch self {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: return true
        default: return false
        }
    }
}

enum WidgetStyle {
    static var weekdays: [String] { AppDateFormat.weekdaySymbols }
    static let sunday = Color(red: 0.94, green: 0.33, blue: 0.33)
    static let flame = Color(red: 1, green: 0.55, blue: 0.2)
    static let flameDeep = Color(red: 0.96, green: 0.33, blue: 0.24)

    /// 공부 진하기(0~4)에 맞는 칸 색
    static func heat(_ level: Int, accent: Color) -> Color {
        switch level {
        case 0: return Color.primary.opacity(0.06)
        case 1: return accent.opacity(0.25)
        case 2: return accent.opacity(0.45)
        case 3: return accent.opacity(0.7)
        default: return accent
        }
    }

    static func weekdayColor(_ index: Int, accent: Color) -> Color {
        index == 0 ? sunday : (index == 6 ? accent : .secondary)
    }
}

/// 위젯 머리글: 색 있는 짧은 이름 + 오른쪽 작은 글
struct WidgetHeader: View {
    let title: String
    var symbol: String?
    var trailing: String?
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(.caption2.weight(.bold))
            }
            Text(title).font(.caption.weight(.heavy))
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .foregroundStyle(accent)
        .accessibilityElement(children: .combine)
    }
}

/// 점선 목표선
struct WidgetDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// 위젯 종류별 배경 (홈 화면은 그림, 잠금 화면은 투명)
enum WidgetBackgroundStyle {
    case plain, accentGradient, flame, paper

    @ViewBuilder
    func view(accent: Color, family: WidgetFamily) -> some View {
        if family.isAccessory {
            Color.clear
        } else {
            switch self {
            case .plain:
                Rectangle().fill(.background)
            case .accentGradient:
                LinearGradient(colors: [accent, accent.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .flame:
                LinearGradient(colors: [WidgetStyle.flame, WidgetStyle.flameDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .paper:
                Color(red: 1, green: 0.984, blue: 0.937)
            }
        }
    }
}
