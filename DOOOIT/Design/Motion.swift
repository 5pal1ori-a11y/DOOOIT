import SwiftUI
import UIKit

// MARK: - 움직임 (애니메이션 공용 도구)
//
// 원칙: 빠르게(0.2~0.45초), 스프링이어도 튕기지 않게, 애플 순정 앱 같은 절제된 움직임.
// "동작 줄이기"(손쉬운 사용)가 켜져 있으면 움직임 없이 투명도만 바뀌거나 바로 바뀜.

/// 앱 전체에서 같은 느낌으로 쓰는 애니메이션
enum Motion {
    /// 손쉬운 사용의 "동작 줄이기"가 켜져 있는지
    static var reduced: Bool { MainActor.assumeIsolated { UIAccessibility.isReduceMotionEnabled } }

    /// 동작 줄이기일 때 쓰는 아주 짧은 페이드
    static var fade: Animation { .easeOut(duration: 0.15) }
    /// 기본 스프링 (튕김 없음)
    static var spring: Animation { reduced ? fade : .spring(response: 0.4, dampingFraction: 0.9) }
    /// 선택·결과 표시용 (아주 약하게만 되돌아옴)
    static var bouncy: Animation { reduced ? fade : .spring(response: 0.36, dampingFraction: 0.82) }
    /// 작은 상태 바뀜
    static var quick: Animation { reduced ? fade : .snappy(duration: 0.25) }
    /// 숫자가 굴러가는 속도
    static var number: Animation { reduced ? fade : .smooth(duration: 0.35) }
    /// 진행 막대·링이 차오르는 속도
    static var fill: Animation { reduced ? fade : .smooth(duration: 0.45) }
    /// 체크 표시가 그려지는 속도
    static var check: Animation { reduced ? fade : .easeOut(duration: 0.28) }
    /// 등장 시 올라오는 거리와 차례 간격, 차례를 줄 최대 개수
    static let riseDistance: CGFloat = 6
    static let staggerStep: Double = 0.035
    static let staggerCap = 8
}

extension AnyTransition {
    /// 아래에서 살짝 올라오며 나타남 (동작 줄이기면 투명도만)
    static func rise(_ distance: CGFloat = 8) -> AnyTransition {
        Motion.reduced ? .opacity : .opacity.combined(with: .offset(y: distance))
    }
}

/// 카드·행을 누르면 살짝 작아지고 옅어졌다 돌아오는 버튼 스타일
struct PressableCardStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var dimmedOpacity: Double = 0.7

    func makeBody(configuration: Configuration) -> some View {
        PressableLabel(configuration: configuration, scale: scale, dimmedOpacity: dimmedOpacity)
    }
}

/// 버튼 스타일 안에서 "동작 줄이기"를 읽기 위한 작은 뷰
struct PressableLabel: View {
    let configuration: ButtonStyleConfiguration
    var scale: CGFloat
    var dimmedOpacity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? dimmedOpacity : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableCardStyle {
    /// 누르면 살짝 눌리는 카드 버튼 (0.97배 + 옅게)
    static var pressable: PressableCardStyle { PressableCardStyle() }
    /// 카드 안에 묶인 목록 줄용: 눌림이 더 작음
    static var pressableRow: PressableCardStyle { PressableCardStyle(scale: 0.985, dimmedOpacity: 0.6) }
}

/// 화면에 처음 나타날 때 6pt 올라오며 페이드 (한 화면에서 처음 한 번만, 차례대로)
private struct StaggerIn: ViewModifier {
    let delay: Double
    @State private var shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(delay: Double) {
        self.delay = delay
        // 차례 한도 밖이거나 동작 줄이기면 처음부터 보임 (깜빡임 없음)
        _shown = State(initialValue: delay > Double(Motion.staggerCap) * Motion.staggerStep || Motion.reduced)
    }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : Motion.riseDistance)
            .onAppear {
                guard !shown else { return }
                withAnimation(.smooth(duration: 0.4).delay(delay)) { shown = true }
            }
    }
}

extension View {
    /// 목록·카드가 화면에 처음 나타날 때 차례대로(30~40ms 간격) 6pt 올라오며 나타남. 8개째까지만
    func staggerIn(index: Int) -> some View {
        modifier(StaggerIn(delay: Double(max(index, 0)) * Motion.staggerStep))
    }

    /// 처음 나타날 때 부드럽게 올라오기 (예전 이름: staggerIn(index:)과 같은 움직임)
    func appearAnimation(delay: Double = 0, offset: CGFloat = 6) -> some View {
        modifier(StaggerIn(delay: min(delay, Double(Motion.staggerCap) * Motion.staggerStep)))
    }

    /// 숫자가 바뀔 때 자릿수가 굴러가듯 바뀜 (동작 줄이기면 페이드)
    func numberRoll(_ value: Double) -> some View {
        modifier(NumberRoll(value: value))
    }

    /// 글자 속 숫자가 바뀔 때 굴러가듯 바뀜 (시간·순위처럼 글자로 만든 숫자용)
    func numberRoll(_ text: String) -> some View {
        modifier(NumberRollText(text: text))
    }

    /// 틀렸을 때 좌우로 흔들기 (trigger 값이 바뀔 때마다. Bool이면 true가 될 때만)
    func shake<T: Equatable>(trigger: T) -> some View {
        modifier(ShakeOnChange(trigger: trigger))
    }

    /// 정답이 되는 순간 1.0 → 1.04 → 1.0으로 한 번 커졌다 돌아옴
    func popOnce(when isOn: Bool) -> some View {
        modifier(PopOnce(isOn: isOn))
    }

    /// 시트·새 화면의 내용이 부드럽게 나타남
    func contentFadeIn() -> some View {
        modifier(ContentFadeIn())
    }
}

private struct NumberRoll: ViewModifier {
    let value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .opacity : .numericText(value: value))
            .animation(Motion.number, value: value)
    }
}

private struct NumberRollText: ViewModifier {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .opacity : .numericText())
            .animation(Motion.number, value: text)
    }
}

private struct PopOnce: ViewModifier {
    let isOn: Bool
    @State private var scale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: isOn) { _, new in
                guard new, !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.12)) { scale = 1.04 }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    withAnimation(.easeInOut(duration: 0.2)) { scale = 1 }
                }
            }
    }
}

private struct ContentFadeIn: ViewModifier {
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .onAppear {
                guard !shown else { return }
                withAnimation(.easeOut(duration: 0.25)) { shown = true }
            }
    }
}

/// 좌우로 흔드는 효과 (6pt, 세 번)
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 6
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakes * 2), y: 0))
    }
}

private struct ShakeOnChange<T: Equatable>: ViewModifier {
    let trigger: T
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: progress))
            .onChange(of: trigger) {
                // true → false(되돌림)일 때는 흔들지 않음
                if let flag = trigger as? Bool, !flag { return }
                guard !reduceMotion else { return }
                progress = 0
                withAnimation(.linear(duration: 0.4)) { progress = 1 }
            }
    }
}

/// 정답·오답이 정해질 때: 테두리와 옅은 색이 부드럽게 나타나고, 정답은 1.0 → 1.04 → 1.0으로 한 번 커졌다 돌아옴
struct FeedbackGlow: ViewModifier {
    /// nil: 아직, true: 정답, false: 오답
    let result: Bool?
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color.opacity(result == nil ? 0 : 0.08))
                    .allowsHitTesting(false)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(color, lineWidth: result == nil ? 0 : 2)
                    }
                    .animation(Motion.quick, value: result)
            }
            .popOnce(when: result == true)
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
    /// 정답이면 초록, 오답이면 빨강으로 테두리와 옅은 색이 나타남 (정답은 살짝 커졌다 돌아옴)
    func feedbackGlow(_ result: Bool?, cornerRadius: CGFloat = 18) -> some View {
        modifier(FeedbackGlow(result: result, cornerRadius: cornerRadius))
    }
}

/// 완료 체크: 동그라미 안이 차오르고 체크 표시가 그려짐 (되돌리면 거꾸로 지워짐)
struct CompletionCheck: View {
    let isOn: Bool
    var size: CGFloat = 24
    var color: Color = Theme.accent
    var offColor: Color = Color.secondary.opacity(0.6)
    @State private var progress: CGFloat

    init(isOn: Bool, size: CGFloat = 24, color: Color = Theme.accent, offColor: Color = Color.secondary.opacity(0.6)) {
        self.isOn = isOn
        self.size = size
        self.color = color
        self.offColor = offColor
        _progress = State(initialValue: isOn ? 1 : 0)
    }

    var body: some View {
        ZStack {
            Circle().strokeBorder(offColor, lineWidth: max(1.2, size * 0.065))
            Circle().fill(color).opacity(progress)
            CheckmarkShape()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: max(1.6, size * 0.085), lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .onChange(of: isOn) { _, on in
            withAnimation(Motion.check) { progress = on ? 1 : 0 }
        }
    }
}

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.29, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.67))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.35))
        return path
    }
}

/// 분할 선택기 (시스템 분할 선택기처럼: 회색 바탕 위에 흰 칸이 미끄러지듯 이동)
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
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                let selected = item == selection
                Button {
                    withAnimation(Motion.quick) { selection = item }
                    Haptics.tap()
                } label: {
                    Text(title(item))
                        .font(.pt(.subheadline).weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Palette.ink : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Palette.card)
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.secondaryFill, in: .rect(cornerRadius: 10, style: .continuous))
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
                    Capsule().fill(Theme.secondaryFill)
                    Capsule()
                        .fill(Theme.accent)
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
            .numberRoll(Double(value))
    }
}
