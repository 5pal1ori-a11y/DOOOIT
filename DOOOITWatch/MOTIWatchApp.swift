import SwiftUI
import WatchConnectivity

@main
struct MOTIWatchApp: App {
    @State private var store = WatchStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WatchStore.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refresh() }
        }
        // 앱이 꺼져 있을 때 아이폰이 보낸 상태를 받음 (컴플리케이션 새로 그리기)
        .backgroundTask(.watchConnectivity) {
            await MainActor.run { WatchStore.shared.activate() }
            for _ in 0..<20 where WCSession.default.hasContentPending {
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }
}
