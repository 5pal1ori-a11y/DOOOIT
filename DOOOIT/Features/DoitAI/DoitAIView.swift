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
    @State private var showNotes = false

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
                            if assistant.isResponding && !isStreamingText {
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
                    // 모델이 쓰는 글이 길어지면 따라 내려감
                    .onChange(of: assistant.messages.last?.text.count ?? 0) {
                        if assistant.messages.last?.isStreaming == true { proxy.scrollTo(assistant.messages.last?.id, anchor: .bottom) }
                    }
                }
                inputBar
            }
            .background { AppBackground() }
            .navigationTitle("두잇 AI")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showNotes) { LearnedNotesSheet() }
            .toolbar {
                // ChatGPT·Gemini처럼 위쪽에서 모델 고르기
                ToolbarItem(placement: .principal) {
                    ModelMenu(showNotes: $showNotes)
                }
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
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text("두잇 AI로 공부 계획부터 문제 풀이까지 편하게 물어보세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            ModelDownloadCard()
                .padding(.top, 8)
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
                        .background(Theme.accent, in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, bottomTrailingRadius: 6, topTrailingRadius: 20))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 56)
        case .assistant:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    AIOrb(size: 30)
                    VStack(alignment: .leading, spacing: 10) {
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
                        if message.isStreaming && message.text.isEmpty {
                            Text(assistant.status.isEmpty ? "생각하는 중…" : assistant.status)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(Self.markdown(MathSymbolBar.pretty(message.text)))
                                .font(.body)
                                .lineSpacing(3)
                                .foregroundStyle(Palette.ink)
                                .textSelection(.enabled)
                                .contentTransition(.opacity)
                        }
                        if !message.sources.isEmpty && !message.isStreaming {
                            Label(message.sources.joined(separator: " · "), systemImage: "books.vertical")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        if message.learnTopic != nil && !message.isStreaming {
                            feedbackButtons(message)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.card, in: UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 20))
                    .overlay(UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 20)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
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

    /// 👍 / 👎 (모델이 만든 답에만)
    private func feedbackButtons(_ message: DoitAssistant.Message) -> some View {
        HStack(spacing: 14) {
            if message.rating == 0 {
                Button { Haptics.tap(); assistant.rate(message.id, good: true) } label: {
                    Image(systemName: "hand.thumbsup")
                }
                .accessibilityLabel("좋은 답이에요")
                Button { Haptics.tap(); assistant.rate(message.id, good: false) } label: {
                    Image(systemName: "hand.thumbsdown")
                }
                .accessibilityLabel("별로예요")
            } else {
                Label(message.rating > 0 ? "기억해 둘게요" : "다음엔 더 잘 찾아볼게요",
                      systemImage: message.rating > 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .animation(.snappy, value: message.rating)
    }

    private var isStreamingText: Bool {
        guard let last = assistant.messages.last else { return false }
        return last.isStreaming
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
                            .background(Palette.card, in: .capsule)
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
                .background(Palette.card, in: .rect(cornerRadius: 16))
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
                            .font(.subheadline.weight(.bold))
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

    /// 두잇 AI 프로필 = 앱 아이콘(DOOIT 로고)을 둥글게
    var body: some View {
        ZStack {
            if size > 50 {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: size * 1.4, height: size * 1.4)
                    .blur(radius: size * 0.2)
            }
            Image("AppLogo")
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.circle)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: max(1, size * 0.02)))
                .shadow(color: .black.opacity(0.12), radius: size * 0.08, y: size * 0.03)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("두잇 AI")
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
            .background(Palette.card, in: .capsule)
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
