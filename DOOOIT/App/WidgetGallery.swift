#if DEBUG
import SwiftData
import SwiftUI
import WidgetKit

/// 화면 사진 찍기용 위젯 미리보기 (Debug · -uiShot widgets…)
/// 실제 위젯과 같은 화면(Shared/Widget*Views.swift)을 예시 데이터로 만든 스냅샷으로 그림
struct WidgetGalleryView: View {
    let page: UIShotScreen
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @State private var snapshot: WidgetSnapshot?

    private let now = Date()

    var body: some View {
        ZStack {
            wallpaper.ignoresSafeArea()
            if let snapshot {
                VStack(spacing: 14) {
                    content(snapshot)
                }
                .padding(.top, 8)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .task {
            // 앱이 실제로 위젯에 넘기는 스냅샷 그대로 (UIShot 예시 저장소로 만듦)
            snapshot = WidgetSync.makeSnapshot(context: context, now: now)
        }
    }

    private var wallpaper: some View {
        let accent = WidgetSnapshot.color(WidgetSync.accentHex)
        return Group {
            if page == .widgetsLock {
                LinearGradient(colors: [Color(red: 0.1, green: 0.12, blue: 0.24), accent.opacity(0.9), Color(red: 0.95, green: 0.55, blue: 0.45)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(colors: scheme == .dark
                               ? [Color(red: 0.08, green: 0.08, blue: 0.14), accent.opacity(0.45)]
                               : [accent.opacity(0.35), Color(red: 0.85, green: 0.92, blue: 1)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    @ViewBuilder
    private func content(_ s: WidgetSnapshot) -> some View {
        switch page {
        case .widgets:
            tile(.systemLarge, .plain, s) { MonthCalendarWidgetView(snapshot: s, family: $0, date: now) }
            tile(.systemMedium, .plain, s) { MonthCalendarWidgetView(snapshot: s, family: $0, date: now) }
        case .widgets2:
            tile(.systemMedium, .plain, s) { WeekPlansWidgetView(snapshot: s, family: $0, date: now) }
            tile(.systemMedium, .plain, s) { WeekChartWidgetView(snapshot: s, family: $0, date: now) }
            tile(.systemMedium, .plain, s) { NextPlanWidgetView(snapshot: s, family: $0, date: now) }
            HStack(spacing: 24) {
                tile(.systemSmall, .flame, s) { StreakWidgetView(snapshot: s, family: $0, date: now) }
                tile(.systemSmall, .accentGradient, s) { QuickTimerWidgetView(snapshot: s, family: $0, date: now) }
            }
        case .widgets3:
            tile(.systemLarge, .plain, s) { WeekPlansWidgetView(snapshot: s, family: $0, date: now) }
            HStack(spacing: 24) {
                tile(.systemSmall, .plain, s) { WeekChartWidgetView(snapshot: s, family: $0, date: now) }
                tile(.systemSmall, .plain, s) { NextPlanWidgetView(snapshot: s, family: $0, date: now) }
            }
        case .widgets4:
            tile(.systemMedium, .plain, s) { TodayPlansView(snapshot: s, family: $0, date: now) }
            tile(.systemMedium, .plain, s) { StudyProgressView(snapshot: s, family: $0, date: now) }
            tile(.systemMedium, .accentGradient, s) { DDayView(snapshot: s, family: $0, date: now) }
            tile(.systemMedium, .plain, s) { QuickTimerWidgetView(snapshot: s, family: $0, date: now) }
        default:
            lockScreen(s)
        }
    }

    /// 잠금 화면: 동그라미 4개 · 네모 · 한 줄
    private func lockScreen(_ s: WidgetSnapshot) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                inline { StreakWidgetView(snapshot: s, family: .accessoryInline, date: now) }
                inline { NextPlanWidgetView(snapshot: s, family: .accessoryInline, date: now) }
                Text(now, format: .dateTime.hour().minute())
                    .font(.system(size: 84, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
            }
            HStack(spacing: 14) {
                accessory(.accessoryCircular) { StudyProgressView(snapshot: s, family: $0, date: now) }
                accessory(.accessoryCircular) { StreakWidgetView(snapshot: s, family: $0, date: now) }
                accessory(.accessoryCircular) { DDayView(snapshot: s, family: $0, date: now) }
                accessory(.accessoryCircular) { QuickTimerWidgetView(snapshot: s, family: $0, date: now) }
            }
            HStack(spacing: 14) {
                accessory(.accessoryRectangular) { StudyProgressView(snapshot: s, family: $0, date: now) }
                accessory(.accessoryRectangular) { NextPlanWidgetView(snapshot: s, family: $0, date: now) }
            }
            HStack(spacing: 14) {
                accessory(.accessoryRectangular) { StreakWidgetView(snapshot: s, family: $0, date: now) }
                accessory(.accessoryRectangular) { WeekChartWidgetView(snapshot: s, family: $0, date: now) }
            }
            HStack(spacing: 14) {
                accessory(.accessoryRectangular) { DDayView(snapshot: s, family: $0, date: now) }
                accessory(.accessoryRectangular) { TodayPlansView(snapshot: s, family: $0, date: now) }
            }
            inline { StudyProgressView(snapshot: s, family: .accessoryInline, date: now) }
            inline { DDayView(snapshot: s, family: .accessoryInline, date: now) }
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: 칸 그리기 (아이폰 17 Pro 위젯 크기)

    private func size(_ family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: return CGSize(width: 170, height: 170)
        case .systemMedium: return CGSize(width: 364, height: 170)
        case .systemLarge: return CGSize(width: 364, height: 382)
        case .accessoryCircular: return CGSize(width: 72, height: 72)
        case .accessoryRectangular: return CGSize(width: 172, height: 76)
        default: return CGSize(width: 300, height: 22)
        }
    }

    private func tile<V: View>(_ family: WidgetFamily, _ style: WidgetBackgroundStyle, _ s: WidgetSnapshot,
                               @ViewBuilder _ view: (WidgetFamily) -> V) -> some View {
        let box = size(family)
        return view(family)
            .padding(16)
            .frame(width: box.width, height: box.height)
            .background { style.view(accent: s.accent, family: family) }
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
            .fontDesign(.rounded)
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private func accessory<V: View>(_ family: WidgetFamily, @ViewBuilder _ view: (WidgetFamily) -> V) -> some View {
        let box = size(family)
        return view(family)
            .frame(width: box.width, height: box.height)
            .foregroundStyle(.white)
            .fontDesign(.rounded)
    }

    private func inline<V: View>(@ViewBuilder _ view: () -> V) -> some View {
        view()
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .fontDesign(.rounded)
    }
}
#endif
