import SwiftUI

/// 앱 실행 화면: 깔끔한 바탕 위로 로고가 떠오르고 → 워드마크 자간이 좁혀지며 또렷해지고 → 한 줄 문구 → 다음 화면으로 (약 1.1초)
/// 화면 위에 덮이는 장식일 뿐이라 앱 시작 작업을 막지 않음
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showLogo = false
    @State private var showWordmark = false
    @State private var showTagline = false
    @State private var finished = false

    var body: some View {
        ZStack {
            // 바탕: 큰 보라 빛 대신 아주 옅은 세로 그라데이션 (깔끔하게)
            Theme.base.ignoresSafeArea()
            LinearGradient(colors: [Theme.accent.opacity(0.07), .clear, Theme.accent.opacity(0.04)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                BrandLogo(size: 92, glow: false)
                    .shadow(color: .black.opacity(0.10), radius: 22, y: 12)
                    .scaleEffect(reduceMotion ? 1 : (showLogo ? 1 : 0.9))
                    .opacity(showLogo ? 1 : 0)
                    .offset(y: reduceMotion || showLogo ? 0 : 10)
                    .padding(.bottom, 30)

                // 워드마크: 굵고 둥근 글씨 대신 가늘고 넓은 자간 → 자간이 좁혀지며 또렷해짐
                wordmark
                    .opacity(showWordmark ? 1 : 0)
                    .blur(radius: reduceMotion || showWordmark ? 0 : 6)
                    .padding(.bottom, 12)

                Text("오늘 할 일, 끝까지 함께")
                    .font(.footnote.weight(.medium))
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
                    .opacity(showTagline ? 1 : 0)
            }
            .offset(y: -12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MOTI, 오늘 할 일, 끝까지 함께")
        .task { await play() }
    }

    private var wordmark: some View {
        let o = Text("O").foregroundStyle(Theme.accent)
        return Text("M\(o)TI")
            .font(.system(size: 30, weight: .semibold))
            .tracking(reduceMotion || showWordmark ? 11 : 22)
            .foregroundStyle(Palette.ink)
            .fixedSize()
            // 자간 때문에 생긴 오른쪽 여백을 맞춰 가운데로
            .padding(.leading, reduceMotion || showWordmark ? 11 : 22)
    }

    private func play() async {
        if reduceMotion {
            // 움직임 없이 짧게 나타났다가 넘어감
            withAnimation(.easeOut(duration: 0.25)) {
                showLogo = true
                showWordmark = true
                showTagline = true
            }
            try? await Task.sleep(for: .milliseconds(750))
            finish()
            return
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) { showLogo = true }

        try? await Task.sleep(for: .milliseconds(180))
        withAnimation(.easeOut(duration: 0.7)) { showWordmark = true }

        try? await Task.sleep(for: .milliseconds(260))
        withAnimation(.easeOut(duration: 0.4)) { showTagline = true }

        try? await Task.sleep(for: .milliseconds(700))
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
