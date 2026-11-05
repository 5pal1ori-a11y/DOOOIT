import SwiftUI

// MARK: - 움직임 (애니메이션 공용 도구)

/// 앱 전체에서 같은 느낌으로 쓰는 애니메이션
enum Motion {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let bouncy = Animation.spring(response: 0.38, dampingFraction: 0.62)
    static let quick = Animation.snappy(duration: 0.25)
}

/// 카드·행을 누르면 살짝 작아졌다 돌아오는 버튼 스타일
struct PressableCardStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableCardStyle {
    /// 누르면 살짝 눌리는 카드 버튼
    static var pressable: PressableCardStyle { PressableCardStyle() }
}

/// 화면에 처음 나타날 때 아래에서 살짝 올라오며 나타남 (delay로 순서대로)
private struct AppearAnimation: ViewModifier {
    let delay: Double
    let offset: CGFloat
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : offset)
            .scaleEffect(shown || reduceMotion ? 1 : 0.98)
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(Motion.spring.delay(delay)) { shown = true }
                }
            }
    }
}

extension View {
    /// 처음 나타날 때 부드럽게 올라오기. 목록에서는 index × 0.05 같은 delay로 차례대로
    func appearAnimation(delay: Double = 0, offset: CGFloat = 14) -> some View {
        modifier(AppearAnimation(delay: delay, offset: offset))
    }

    /// 틀렸을 때 좌우로 흔들기 (trigger 값이 바뀔 때마다)
    func shake<T: Equatable>(trigger: T) -> some View {
        modifier(ShakeOnChange(trigger: trigger))
    }
}

/// 좌우로 흔드는 효과
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakes * 2), y: 0))
    }
}

private struct ShakeOnChange<T: Equatable>: ViewModifier {
    let trigger: T
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: progress))
            .onChange(of: trigger) {
                progress = 0
                withAnimation(.linear(duration: 0.4)) { progress = 1 }
            }
    }
}

/// 정답·오답이 정해질 때 잠깐 번쩍이는 테두리
struct FeedbackGlow: ViewModifier {
    /// nil: 아직, true: 정답, false: 오답
    let result: Bool?
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(color, lineWidth: result == nil ? 0 : 2.5)
                    .animation(Motion.quick, value: result)
            }
            .shadow(color: color.opacity(result == nil ? 0 : 0.35), radius: result == nil ? 0 : 12)
            .animation(Motion.spring, value: result)
    }

    private var color: Color {
        switch result {
        case .some(true): return Palette.success
        case .some(false): return Palette.danger
        case .none: return .clear
        }
    }
}

extension View {
    /// 정답이면 초록, 오답이면 빨강으로 테두리가 빛남
    func feedbackGlow(_ result: Bool?, cornerRadius: CGFloat = 18) -> some View {
        modifier(FeedbackGlow(result: result, cornerRadius: cornerRadius))
    }
}

/// 알약 모양 선택기 (선택 표시가 미끄러지듯 이동)
struct PillSegmentedControl<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    @Namespace private var namespace

    init(items: [Item], selection: Binding<Item>, title: @escaping (Item) -> String) {
        self.items = items
        self._selection = selection
        self.title = title
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                let selected = item == selection
                Button {
                    withAnimation(Motion.spring) { selection = item }
                    Haptics.tap()
                } label: {
                    Text(title(item))
                        .font(.pt(.subheadline).weight(.bold))
                        .foregroundStyle(selected ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(AccentGradient.linear)
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                                    .shadow(color: Theme.accent.opacity(0.3), radius: 6, y: 3)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Palette.card, in: .capsule)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

/// 단계 진행 막대 (예: 개념 → 빈칸 → O/X → 문제), 채워지는 부분이 부드럽게 늘어남
struct StepProgressBar: View {
    let titles: [String]
    let current: Int
    var completed: Set<Int> = []

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let fraction = titles.count > 1 ? CGFloat(current) / CGFloat(titles.count - 1) : 1
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.accent.opacity(0.14))
                    Capsule()
                        .fill(AccentGradient.linear)
                        .frame(width: max(8, proxy.size.width * fraction))
                        .animation(Motion.spring, value: current)
                }
            }
            .frame(height: 6)
            HStack {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    HStack(spacing: 3) {
                        if completed.contains(index) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.pt(.caption2))
                                .foregroundStyle(Palette.success)
                                .transition(.scale.combined(with: .opacity))
                        }
                        Text(title)
                            .font(.pt(.caption2).weight(index == current ? .heavy : .semibold))
                            .foregroundStyle(index == current ? Theme.accent : Color.secondary)
                    }
                    if index < titles.count - 1 { Spacer(minLength: 0) }
                }
            }
            .animation(Motion.spring, value: completed)
        }
    }
}

/// 숫자가 바뀔 때 굴러가듯 바뀌는 글자
struct AnimatedNumberText: View {
    let value: Int
    var suffix: String = ""
    var font: Font = .title2.weight(.heavy)
    var color: Color = Palette.ink

    var body: some View {
        Text("\(value)\(suffix)")
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(value)))
            .animation(Motion.spring, value: value)
    }
}
