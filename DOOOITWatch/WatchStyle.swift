import SwiftUI

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

enum WatchTab: Hashable {
    case timer, today, words
}

struct WatchRootView: View {
    @Environment(WatchStore.self) private var store
    @State private var tab: WatchTab = WatchDemo.tab

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { TimerScreen() }.tag(WatchTab.timer)
            NavigationStack { TodayScreen() }.tag(WatchTab.today)
            NavigationStack { WordsScreen() }.tag(WatchTab.words)
        }
        .tabViewStyle(.verticalPage)
        .tint(store.snapshot.accent)
        .fontDesign(.rounded)
    }
}
