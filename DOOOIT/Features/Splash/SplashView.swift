import SwiftUI

/// 앱 실행 화면: 로고가 부드럽게 떠오르고 → 워드마크 → 한 줄 문구 → 다음 화면으로 (약 1.1초)
/// 화면 위에 덮이는 장식일 뿐이라 앱 시작 작업을 막지 않음
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showLogo = false
    @State private var showWordmark = false
    @State private var showTagline = false
    @State private var bloom = false
    @State private var finished = false

    var body: some View {
        ZStack {
            BrandBackdrop(animated: false, intensity: bloom ? 1 : 0.35)

            // 로고 뒤로 퍼지는 빛
            Circle()
                .fill(RadialGradient(colors: [Theme.accent.opacity(0.45), Theme.accent.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 170))
                .frame(width: 340, height: 340)
                .scaleEffect(reduceMotion ? 1 : (bloom ? 1.15 : 0.5))
                .opacity(bloom ? 0.9 : 0)
                .offset(y: -44)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                BrandLogo(size: 112)
                    .scaleEffect(reduceMotion ? 1 : (showLogo ? 1 : 0.82))
                    .opacity(showLogo ? 1 : 0)
                    .blur(radius: reduceMotion || showLogo ? 0 : 14)
                    .padding(.bottom, 28)

                BrandWordmark(size: 40)
                    .scaleEffect(reduceMotion ? 1 : (showWordmark ? 1 : 0.94))
                    .opacity(showWordmark ? 1 : 0)
                    .blur(radius: reduceMotion || showWordmark ? 0 : 8)
                    .offset(y: reduceMotion || showWordmark ? 0 : 8)
                    .padding(.bottom, 10)

                Text("오늘 할 일, 끝까지 두잇")
                    .font(.subheadline.weight(.medium))
                    .tracking(0.3)
                    .foregroundStyle(.secondary)
                    .opacity(showTagline ? 1 : 0)
                    .offset(y: reduceMotion || showTagline ? 0 : 6)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("DOOOIT, 오늘 할 일, 끝까지 두잇")
        .task { await play() }
    }

    private func play() async {
        if reduceMotion {
            // 움직임 없이 짧게 나타났다가 넘어감
            withAnimation(.easeOut(duration: 0.25)) {
                showLogo = true
                showWordmark = true
                showTagline = true
                bloom = true
            }
            try? await Task.sleep(for: .milliseconds(750))
            finish()
            return
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { showLogo = true }
        withAnimation(.easeOut(duration: 0.7)) { bloom = true }

        try? await Task.sleep(for: .milliseconds(160))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { showWordmark = true }

        try? await Task.sleep(for: .milliseconds(160))
        withAnimation(.easeOut(duration: 0.35)) { showTagline = true }

        try? await Task.sleep(for: .milliseconds(780))
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
