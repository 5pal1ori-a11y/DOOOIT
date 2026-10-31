import SwiftUI

/// 앱 실행 애니메이션: D O O O I T → 세 개의 O가 하나로 합쳐짐 → D O I T
struct SplashView: View {
    var onFinish: () -> Void

    @State private var appeared = false
    @State private var merged = false
    @State private var pulse = false
    @State private var showTagline = false
    @State private var glow = false

    private let fontSize: CGFloat = 72

    private var oWidth: CGFloat { fontSize * 0.80 }
    private var dWidth: CGFloat { fontSize * 0.72 }
    private var iWidth: CGFloat { fontSize * 0.30 }
    private var tWidth: CGFloat { fontSize * 0.64 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 합쳐질 때 퍼지는 빛
            Circle()
                .fill(
                    RadialGradient(colors: [Color.white.opacity(0.35), .clear],
                                   center: .center, startRadius: 0, endRadius: 180)
                )
                .frame(width: 360, height: 360)
                .scaleEffect(glow ? 1.2 : 0.2)
                .opacity(glow ? 0 : (merged ? 0.9 : 0))

            VStack(spacing: 22) {
                HStack(spacing: 0) {
                    letter("D", width: dWidth, index: 0, x: merged ? oWidth : 0)
                    letter("O", width: oWidth, index: 1, x: merged ? oWidth : 0)
                    letter("O", width: oWidth, index: 2, x: 0)
                        .scaleEffect(pulse ? 1.16 : 1)
                    letter("O", width: oWidth, index: 3, x: merged ? -oWidth : 0)
                    letter("I", width: iWidth, index: 4, x: merged ? -oWidth : 0)
                    letter("T", width: tWidth, index: 5, x: merged ? -oWidth : 0)
                }

                Text("계획하고, 집중하고, 해내다.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(showTagline ? 1 : 0)
                    .offset(y: showTagline ? 0 : 8)
            }
        }
        .task { await play() }
    }

    private func letter(_ character: String, width: CGFloat, index: Int, x: CGFloat) -> some View {
        Text(character)
            .font(.system(size: fontSize, weight: .black))
            .foregroundStyle(.white)
            .frame(width: width)
            .offset(x: x, y: appeared ? 0 : 34)
            .opacity(appeared ? 1 : 0)
            .blur(radius: appeared ? 0 : 10)
            .animation(.spring(response: 0.55, dampingFraction: 0.72).delay(Double(index) * 0.07), value: appeared)
            .animation(.spring(response: 0.62, dampingFraction: 0.8), value: merged)
    }

    private func play() async {
        try? await Task.sleep(for: .milliseconds(200))
        appeared = true

        try? await Task.sleep(for: .milliseconds(1100))
        merged = true

        try? await Task.sleep(for: .milliseconds(520))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) { pulse = true }
        withAnimation(.easeOut(duration: 0.9)) { glow = true }

        try? await Task.sleep(for: .milliseconds(220))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            pulse = false
            showTagline = true
        }

        try? await Task.sleep(for: .milliseconds(1000))
        onFinish()
    }
}

#Preview {
    SplashView {}
}
