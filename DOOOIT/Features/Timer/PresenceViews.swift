import SwiftUI
import UIKit

/// 타이머 위에 보이는 작은 칩: "공부 중 · 순공부 42:10" / "자리 비움"
struct PresenceChip: View {
    @State private var monitor = StudyPresenceMonitor.shared

    var body: some View {
        let color = monitor.chipColor
        Button {
            // 멈춘 상태면 다시 켜기, 아니면 카메라 화면 보이기 · 숨기기
            if monitor.status == .suspended || monitor.status.isUnavailable { monitor.resumeNow() } else { monitor.setLive(!monitor.showLive) }
            Haptics.tap()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.pt(.caption).weight(.bold))
                Text(monitor.chipText)
                    .font(.pt(.footnote).weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.16), in: .capsule)
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.25), value: monitor.state)
        .accessibilityLabel("AI 순공부 측정")
        .accessibilityValue(monitor.chipText)
    }

    private var icon: String {
        switch monitor.status {
        case .unavailable, .suspended: "exclamationmark.triangle.fill"
        case .paused: "pause.fill"
        default:
            switch monitor.state {
            case .studying: "pencil.line"
            case .waiting: "viewfinder"
            case .still: "hourglass"
            case .distracted: "iphone.gen3"
            case .away: "figure.walk"
            }
        }
    }
}

/// 측정 중 타이머 화면에 보이는 카메라 화면 (내 모습 + 가이드 박스). 영상은 저장하지 않아요
struct PresenceLiveCard: View {
    @State private var monitor = StudyPresenceMonitor.shared
    @AppStorage(StudyPresenceMonitor.flipKey) private var flipped = false
    @State private var angle: Double = PresenceGuideSheet.angle(for: UIDevice.current.orientation, fallback: 0)

    var body: some View {
        if monitor.status == .measuring && monitor.showLive {
            let rotated = abs(angle) == 90
            let layout = PresenceLayout.make(flipped: flipped)
            GeometryReader { geo in
                let canvasWidth = rotated ? geo.size.height : geo.size.width
                let canvasHeight = canvasWidth * 3 / 4
                PresenceCanvas(image: monitor.previewImage, layout: layout, frame: monitor.previewFrame,
                               observation: monitor.previewObservation, isDemo: false, status: monitor.status)
                    .frame(width: canvasWidth, height: canvasHeight)
                    .rotationEffect(.degrees(angle))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .aspectRatio(rotated ? 3.0 / 4.0 : 4.0 / 3.0, contentMode: .fit)
            .frame(maxWidth: 260)
            .overlay(alignment: .topTrailing) {
                Button {
                    monitor.setLive(false)
                    Haptics.tap()
                } label: {
                    Image(systemName: "eye.slash.fill")
                        .font(.pt(.caption).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.black.opacity(0.55), in: .circle)
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel("카메라 화면 숨기기")
            }
            .animation(.smooth(duration: 0.3), value: angle)
            .onAppear { UIDevice.current.beginGeneratingDeviceOrientationNotifications() }
            .onDisappear { UIDevice.current.endGeneratingDeviceOrientationNotifications() }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                angle = PresenceGuideSheet.angle(for: UIDevice.current.orientation, fallback: angle)
            }
            .transition(.opacity)
        }
    }
}

/// 공부를 마친 뒤 결과 줄: "총 1:00 · 순공부 0:52 · 집중도 87%"
struct PresenceResultView: View {
    let totalSeconds: Int
    let summary: PresenceSummary

    var body: some View {
        VStack(spacing: 6) {
            Label(PresenceText.resultL(totalSeconds: totalSeconds, summary: summary), systemImage: "viewfinder")
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(Color(hex: "#34C759"))
                .monospacedDigit()
            let rest = PresenceText.breakdownL(summary)
            if !rest.isEmpty {
                Text(rest)
                    .font(.pt(.footnote))
                    .foregroundStyle(Color(white: 0.55))
            }
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - 가이드 화면

/// 처음 켤 때(또는 다시 볼 때) 보이는 안내: 폰을 가로로 세우고, 카메라에 몸과 팔이 가이드 박스에 맞게
struct PresenceGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StudyPresenceMonitor.enabledKey) private var enabled = false
    @AppStorage(StudyPresenceMonitor.cameraKey) private var cameraRaw = PresenceCameraPosition.back.rawValue
    @AppStorage(StudyPresenceMonitor.flipKey) private var flipped = false
    @State private var monitor = StudyPresenceMonitor.shared
    @State private var angle: Double = PresenceGuideSheet.angle(for: UIDevice.current.orientation, fallback: 0)

    private let green = Color(hex: "#34C759")
    private let panel = Color(white: 0.11)

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                steps
                canvas
                statusLine
                controls
                privacyLine
                buttons
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .task { await monitor.startPreview() }
        .onDisappear { monitor.stopPreview() }
        .onAppear { UIDevice.current.beginGeneratingDeviceOrientationNotifications() }
        .onDisappear { UIDevice.current.endGeneratingDeviceOrientationNotifications() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            angle = Self.angle(for: UIDevice.current.orientation, fallback: angle)
        }
        .onChange(of: cameraRaw) { monitor.settingsChanged() }
        .onChange(of: flipped) { monitor.settingsChanged() }
    }

    // MARK: 위쪽

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "viewfinder")
                .font(.pt(size: 30, weight: .semibold))
                .foregroundStyle(green)
            Text("AI 순공부 측정")
                .font(.pt(.title2).weight(.bold))
            Text("공부한 시간만 똑똑하게 재요")
                .font(.pt(.subheadline))
                .foregroundStyle(Color(white: 0.6))
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            step("iphone.landscape", "휴대폰을 가로로 세워 책상 옆에 두세요")
            step("person.crop.rectangle", "측면에서 팔과 몸이 보이게")
            step("square.dashed", "가이드 박스에 맞춰 주세요")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(panel, in: .rect(cornerRadius: 14))
    }

    private func step(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(green)
                .frame(width: 24)
            Text(text.loc)
                .font(.pt(.subheadline))
        }
    }

    // MARK: 미리보기

    private var layout: PresenceLayout { PresenceLayout.make(flipped: flipped) }

    /// 폰이 눕혀져 있어도 미리보기가 똑바로 보이도록 돌림 (앱은 세로 고정이라 화면 내용만 돌림)
    private var canvas: some View {
        let rotated = abs(angle) == 90
        return GeometryReader { geo in
            let canvasWidth = rotated ? geo.size.height : geo.size.width
            let canvasHeight = canvasWidth * 3 / 4
            PresenceCanvas(image: monitor.previewImage, layout: layout, frame: monitor.previewFrame,
                           observation: monitor.previewObservation, isDemo: monitor.isDemo, status: monitor.status)
                .frame(width: canvasWidth, height: canvasHeight)
                .rotationEffect(.degrees(angle))
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(rotated ? 3.0 / 4.0 : 4.0 / 3.0, contentMode: .fit)
        .animation(.smooth(duration: 0.3), value: angle)
    }

    @ViewBuilder
    private var statusLine: some View {
        if case .unavailable(let message) = monitor.status {
            VStack(spacing: 8) {
                Label(message.loc, systemImage: "exclamationmark.triangle.fill")
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(Palette.warning)
                if PresenceCameraController.authorization == .denied {
                    Button("설정 열기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(green)
                }
            }
        } else if let obs = monitor.previewObservation, obs.present, obs.handInArm {
            Label("좋아요, 잘 보여요", systemImage: "checkmark.circle.fill")
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(green)
        } else {
            Text("몸과 팔을 박스에 맞춰 주세요")
                .font(.pt(.subheadline))
                .foregroundStyle(Color(white: 0.6))
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Picker("카메라", selection: $cameraRaw) {
                Text("후면").tag(PresenceCameraPosition.back.rawValue)
                Text("전면").tag(PresenceCameraPosition.front.rawValue)
            }
            .pickerStyle(.segmented)

            Button {
                flipped.toggle()
                Haptics.tap()
            } label: {
                Label("좌우", systemImage: "arrow.left.arrow.right")
                    .font(.pt(.subheadline).weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(panel, in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }

    private var privacyLine: some View {
        Label("영상은 저장하지 않고, 기기 안에서만 처리해요", systemImage: "lock.shield.fill")
            .font(.pt(.footnote))
            .foregroundStyle(Color(white: 0.55))
            .multilineTextAlignment(.center)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button {
                enabled = true
                Haptics.success()
                dismiss()
            } label: {
                Text("시작")
                    .font(.pt(.body).weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(green, in: .capsule)
            }
            .buttonStyle(.pressable)

            Button("측정 끄기") {
                enabled = false
                dismiss()
            }
            .font(.pt(.subheadline))
            .foregroundStyle(Color(white: 0.55))
        }
    }

    /// 기기 방향 → 화면 내용을 돌릴 각도 (눕혔을 때 똑바로 보이게). 평평하거나 모르면 그대로
    static func angle(for orientation: UIDeviceOrientation, fallback: Double) -> Double {
        switch orientation {
        case .landscapeLeft: 90
        case .landscapeRight: -90
        case .portraitUpsideDown: 180
        case .portrait: 0
        default: fallback
        }
    }
}

/// 카메라 미리보기 + 가이드 박스 두 개 (몸 · 팔). 박스 안에 잡히면 초록색으로 바뀜
struct PresenceCanvas: View {
    let image: UIImage?
    let layout: PresenceLayout
    let frame: PresenceFrame?
    let observation: FrameObservation?
    let isDemo: Bool
    let status: StudyPresenceMonitor.Status

    private let bodyColor = Color(hex: "#4FA3F7")
    private let armColor = Color(hex: "#FFB020")
    private let okColor = Color(hex: "#34C759")

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Color(white: 0.09)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else if isDemo {
                    PresenceDemoScene()
                } else {
                    placeholder
                }

                guideBox(layout.body, label: "몸", color: bodyColor, ok: observation?.present == true, in: size)
                guideBox(layout.arm, label: "팔", color: armColor, ok: observation?.handInArm == true, in: size)

                if let frame {
                    ForEach(Array(frame.wrists.enumerated()), id: \.offset) { _, wrist in
                        Circle()
                            .fill(okColor)
                            .frame(width: 10, height: 10)
                            .position(x: wrist.x * size.width, y: wrist.y * size.height)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(white: 0.22), lineWidth: 1)
        }
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "video.slash.fill")
                .font(.pt(size: 26, weight: .semibold))
            if case .unavailable(let message) = status {
                Text(message.loc).font(.pt(.footnote))
            } else {
                Text("카메라 준비 중…").font(.pt(.footnote))
            }
        }
        .foregroundStyle(Color(white: 0.45))
    }

    private func guideBox(_ box: PresenceBox, label: String, color: Color, ok: Bool, in size: CGSize) -> some View {
        let tint = ok ? okColor : color
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint, style: StrokeStyle(lineWidth: ok ? 3 : 2, dash: ok ? [] : [7, 5]))
                .background(tint.opacity(ok ? 0.12 : 0.05), in: .rect(cornerRadius: 10, style: .continuous))
            HStack(spacing: 3) {
                if ok { Image(systemName: "checkmark").font(.pt(.caption2).weight(.bold)) }
                Text(label.loc).font(.pt(.caption).weight(.bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint, in: .capsule)
            .padding(6)
        }
        .frame(width: box.w * size.width, height: box.h * size.height)
        .position(x: (box.x + box.w / 2) * size.width, y: (box.y + box.h / 2) * size.height)
    }
}

/// 카메라가 없는 곳(화면 사진용)에서 보이는 가짜 장면: 책상에 앉은 사람의 옆모습
struct PresenceDemoScene: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: [Color(white: 0.20), Color(white: 0.12)], startPoint: .top, endPoint: .bottom)
                // 책상
                Rectangle()
                    .fill(Color(white: 0.27))
                    .frame(width: w, height: h * 0.1)
                    .position(x: w / 2, y: h * 0.86)
                Image(systemName: "figure.seated.side")
                    .font(.system(size: h * 0.62))
                    .foregroundStyle(Color(white: 0.42))
                    .position(x: w * 0.30, y: h * 0.52)
                Image(systemName: "book.pages.fill")
                    .font(.system(size: h * 0.16))
                    .foregroundStyle(Color(white: 0.36))
                    .position(x: w * 0.70, y: h * 0.75)
            }
        }
    }
}
