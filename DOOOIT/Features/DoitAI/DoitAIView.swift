import PhotosUI
import SwiftUI

/// 두잇 AI 탭: 채팅으로 앱의 모든 일을 처리 (플랜, 타이머, 단어, 메모, 목표, 기록, 공부 질문)
struct DoitAIView: View {
    @State private var assistant = DoitAssistant.shared
    @State private var input = ""
    @State private var attached: UIImage?
    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if assistant.messages.isEmpty {
                                welcome
                            }
                            ForEach(assistant.messages) { message in
                                bubble(message)
                                    .id(message.id)
                                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                            }
                            if assistant.isResponding {
                                TypingIndicator(status: assistant.status).id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .animation(.snappy, value: assistant.messages.count)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .simultaneousGesture(TapGesture().onEnded { focused = false })
                    .onChange(of: assistant.messages.count) {
                        withAnimation { proxy.scrollTo(assistant.messages.last?.id, anchor: .bottom) }
                    }
                    .onChange(of: assistant.isResponding) { _, responding in
                        if responding { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                    }
                }
                inputBar
            }
            .background { AppBackground() }
            .navigationTitle("두잇 AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !assistant.messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { withAnimation { assistant.reset() } } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel("새 대화")
                        .disabled(assistant.isResponding)
                    }
                }
            }
            .imageInput(showScanner: $showScanner, showPhotoPicker: $showPhotoPicker, photoItems: $photoItems, maxPhotos: 1) { images in
                attached = images.first
            }
        }
    }

    // MARK: 시작 화면

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 70)
            AIOrb(size: 96)
            VStack(spacing: 8) {
                Text("무엇을 도와드릴까요?")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Palette.ink)
                Text("두잇 AI로 공부 계획부터 문제 풀이까지 편하게 물어보세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if DoitAppleAI.isAvailable {
                Label("Apple Intelligence와 함께", systemImage: "apple.intelligence")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.1), in: .capsule)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: 말풍선

    @ViewBuilder
    private func bubble(_ message: DoitAssistant.Message) -> some View {
        switch message.role {
        case .user:
            VStack(alignment: .trailing, spacing: 6) {
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 210, maxHeight: 210)
                        .clipShape(.rect(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, bottomTrailingRadius: 6, topTrailingRadius: 20)
                        )
                        .shadow(color: Theme.accent.opacity(0.25), radius: 8, y: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 56)
        case .assistant:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    AIOrb(size: 30, symbol: message.source == .apple ? "apple.intelligence" : "sparkles")
                    VStack(alignment: .leading, spacing: 10) {
                        if message.source == .apple {
                            Text("Apple Intelligence")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.accent)
                        }
                        if !message.actions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(message.actions, id: \.self) { action in
                                    Label(action, systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Palette.success)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.success.opacity(0.1), in: .rect(cornerRadius: 12))
                        }
                        Text(Self.markdown(MathSymbolBar.pretty(message.text)))
                            .font(.body)
                            .lineSpacing(3)
                            .foregroundStyle(Palette.ink)
                            .textSelection(.enabled)
                        if message.source == .apple {
                            Text(DoitAppleAI.caution)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 20))
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                }
                .padding(.trailing, 18)
                if !message.suggestions.isEmpty && message.id == assistant.messages.last?.id {
                    suggestionChips(message.suggestions)
                }
            }
        case .notice:
            Label(message.text, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private func suggestionChips(_ suggestions: [String]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button { Task { await assistant.send(suggestion) } } label: {
                        Text(suggestion)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(Color.white, in: .capsule)
                            .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(assistant.isResponding)
                }
            }
            .padding(.leading, 40)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: 입력창

    private var inputBar: some View {
        VStack(spacing: 8) {
            if let attached {
                HStack(spacing: 10) {
                    Image(uiImage: attached)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(.rect(cornerRadius: 12))
                    Text("사진 속 글자를 읽어서 정리해요").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { self.attached = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.white, in: .rect(cornerRadius: 16))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(alignment: .bottom, spacing: 8) {
                if focused {
                    // 키보드 내리기
                    Button {
                        focused = false
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("키보드 내리기")
                    .transition(.scale.combined(with: .opacity))
                } else {
                Menu {
                    Button { showScanner = DocumentScanner.isSupported; showPhotoPicker = !DocumentScanner.isSupported } label: {
                        Label("문제 촬영", systemImage: "camera")
                    }
                    Button { showPhotoPicker = true } label: {
                        Label("앨범에서 선택", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                        .frame(width: 42, height: 42)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .transition(.scale.combined(with: .opacity))
                }

                HStack(alignment: .bottom, spacing: 6) {
                    TextField("두잇 AI에게 물어보기", text: $input, axis: .vertical)
                        .submitLabel(.send)
                        .onSubmit { submit() }
                        .lineLimit(1...5)
                        .focused($focused)
                        .padding(.leading, 16)
                        .padding(.vertical, 11)

                    Button { submit() } label: {
                        Image(systemName: "arrow.up")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(canSend ? Theme.accent : Color.secondary.opacity(0.35), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .padding(.trailing, 5)
                    .padding(.bottom, 5)
                }
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .animation(.snappy, value: attached != nil)
        .animation(.snappy, value: focused)
    }

    /// **굵게** 같은 간단한 마크다운만 적용
    private static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }

    private func submit() {
        guard canSend else { return }
        let text = input
        let image = attached
        input = ""
        attached = nil
        Haptics.tap()
        Task { await assistant.send(text, image: image) }
    }

    private var canSend: Bool {
        !assistant.isResponding && (!input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attached != nil)
    }
}

// MARK: - 꾸밈

/// 두잇 AI 아이콘: 테마 색 그라데이션 원 + 은은한 빛
private struct AIOrb: View {
    var size: CGFloat
    var symbol = "sparkles"

    var body: some View {
        ZStack {
            if size > 50 {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: size * 1.4, height: size * 1.4)
                    .blur(radius: size * 0.2)
            }
            Circle()
                .fill(AngularGradient(colors: [Theme.accent, Theme.accent.opacity(0.55), Color.white.opacity(0.9), Theme.accent],
                                      center: .center))
                .frame(width: size, height: size)
            Circle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center))
                .frame(width: size, height: size)
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
        }
        .frame(width: size, height: size)
    }
}

/// 답을 만드는 동안: 점 세 개가 차례로 튀는 표시 + 상태 문구
private struct TypingIndicator: View {
    var status: String
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            AIOrb(size: 30)
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 7, height: 7)
                            .offset(y: phase == index ? -3 : 0)
                            .opacity(phase == index ? 1 : 0.45)
                    }
                }
                if !status.isEmpty {
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white, in: .capsule)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(320))
                withAnimation(.easeInOut(duration: 0.25)) { phase = (phase + 1) % 3 }
            }
        }
    }
}
