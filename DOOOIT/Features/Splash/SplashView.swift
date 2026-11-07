import SwiftUI

/// 앱 실행 화면: 단색 바탕 가운데에 로고만 (약 0.9초 뒤 다음 화면으로)
/// 화면 위에 덮이는 장식일 뿐이라 앱 시작 작업을 막지 않음
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showLogo = false
    @State private var finished = false

    var body: some View {
        ZStack {
            Theme.base.ignoresSafeArea()
            BrandLogo(size: 96, glow: false)
                .scaleEffect(reduceMotion ? 1 : (showLogo ? 1 : 0.96))
                .opacity(showLogo ? 1 : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MOTI")
        .task { await play() }
    }

    private func play() async {
        withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.45)) { showLogo = true }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 600 : 900))
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

#Preview {
    SplashView {}
}
