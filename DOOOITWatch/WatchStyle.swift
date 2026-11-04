import SwiftUI
import WatchKit

extension Color {
    init(watchHex hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        self.init(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255, opacity: 1)
    }
}

extension WatchSnapshot {
    /// 아이폰에서 고른 강조색 (기본 라벤더)
    var accent: Color { Color(watchHex: accentHex) }
}

/// 워치에서만 쓰는 설정 (진동 · 뽀모도로 길이)
enum WatchPrefs {
    static let hapticsKey = "watch.haptics"
    static let milestonesKey = "watch.milestones"
    static let focusKey = "watch.focusMinutes"
    static let restKey = "watch.restMinutes"
    static let targetKey = "watch.targetIndex"

    static var haptics: Bool { UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true }
    static var milestones: Bool { UserDefaults.standard.object(forKey: milestonesKey) as? Bool ?? true }
    static var focusMinutes: Int { UserDefaults.standard.object(forKey: focusKey) as? Int ?? 25 }
    static var restMinutes: Int { UserDefaults.standard.object(forKey: restKey) as? Int ?? 5 }

    /// 뽀모도로 고르기 (집중/휴식 분)
    static let focusChoices: [(focus: Int, rest: Int)] = [(25, 5), (50, 10), (15, 3)]
}

/// 진동 (설정에서 끌 수 있음)
enum WatchHaptics {
    static func play(_ type: WKHapticType) {
        guard WatchPrefs.haptics else { return }
        WKInterfaceDevice.current().play(type)
    }
}

/// 둥근 진행 고리 (공부 목표 · 타이머)
struct WatchRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 9

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.4), value: progress)
        }
    }
}

/// 작은 둥근 칩 버튼 (25 · 50 · 90분)
struct WatchChip: View {
    var label: String
    var systemImage: String?
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                } else {
                    Text(label)
                }
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(color.opacity(0.22), in: .capsule)
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// 빈 화면 안내 (짧게)
struct WatchEmpty: View {
    var symbol: String
    var text: String
    var color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

enum WatchTab: String, Hashable {
    case timer, summary, today, words, ask
}

struct WatchRootView: View {
    @Environment(WatchStore.self) private var store
    @State private var tab: WatchTab = WatchDemo.tab

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { TimerScreen() }.tag(WatchTab.timer)
            NavigationStack {
                if WatchDemo.screen == "settings" { SettingsScreen() } else { SummaryScreen() }
            }
            .tag(WatchTab.summary)
            NavigationStack { TodayScreen() }.tag(WatchTab.today)
            NavigationStack { WordsScreen() }.tag(WatchTab.words)
            NavigationStack { AskScreen() }.tag(WatchTab.ask)
        }
        .tabViewStyle(.verticalPage)
        .tint(store.snapshot.accent)
        .fontDesign(.rounded)
        // 컴플리케이션을 누르면 그 화면으로 (motiwatch://timer 등)
        .onOpenURL { url in
            if let target = WatchTab(rawValue: url.host() ?? "") { tab = target }
        }
    }
}
