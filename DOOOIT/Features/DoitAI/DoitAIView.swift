import PhotosUI
import SwiftUI

/// 모티 AI 탭: 채팅으로 앱의 모든 일을 처리 (플랜, 타이머, 단어, 메모, 목표, 기록, 공부 질문)
struct DoitAIView: View {
    @State private var assistant = DoitAssistant.shared
    @State private var input = ""
    @State private var attached: UIImage?
    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    /// 말로 질문하기
    @State private var voice = VoiceQuestion()
    @FocusState private var focused: Bool
    /// 맨 아래를 보고 있을 때만 새 글을 따라 내려감 (위로 올려 읽는 중이면 그대로 둠)
    @State private var atBottom = true
    @State private var lastFollow = Date.distantPast

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        // 대화는 길지 않아서 VStack: LazyVStack은 높이를 어림하다가 스크롤이 튀어요
                        VStack(alignment: .leading, spacing: 16) {
                            // 모티 ZERO(모델 없이)는 한국어로만 답해요: 다른 화면 언어면 맨 위에 한 줄 안내
                            if !AppLanguage.isKorean && DoitBrain.shared.selected == nil {
                                Label(L("모티 ZERO는 한국어로만 답해요. 모티 1·2를 받으면 이 언어로 대화해요."), systemImage: "globe")
                                    .font(.pt(.footnote).weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.accent.opacity(0.1), in: .rect(cornerRadius: 14))
                            }
                            if assistant.messages.isEmpty {
                                welcome
                            }
                            ForEach(assistant.messages) { message in
                                bubble(message)
                                    .id(message.id)
                                    .transition(.opacity)
                            }
                            if assistant.isResponding && !isStreamingText {
                                TypingIndicator(status: assistant.status.loc).id("typing")
                            }
                            Color.clear.frame(height: 1).id(Self.bottomID)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .animation(.snappy, value: assistant.messages.count)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .simultaneousGesture(TapGesture().onEnded { focused = false })
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 80
                    } action: { _, isAtBottom in
                        atBottom = isAtBottom
                    }
                    .onChange(of: assistant.messages.count) {
                        // 내가 보낸 말은 항상 아래로, 답은 아래를 보고 있을 때만
                        guard atBottom || assistant.messages.last?.role == .user else { return }
                        atBottom = true
                        withAnimation(.snappy) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                    }
                    .onChange(of: assistant.isResponding) { _, responding in
                        if responding, atBottom { withAnimation(.snappy) { proxy.scrollTo(Self.bottomID, anchor: .bottom) } }
                    }
                    // 모델이 쓰는 글이 길어지면 따라 내려감: 애니메이션 없이, 자주 하지 않게 (흔들림 방지)
                    .onChange(of: assistant.messages.last?.text.count ?? 0) {
                        guard atBottom, assistant.messages.last?.isStreaming == true, Date().timeIntervalSince(lastFollow) > 0.12 else { return }
                        lastFollow = Date()
                        var quiet = Transaction()
                        quiet.disablesAnimations = true
                        withTransaction(quiet) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                    }
                }
                inputBar
            }
            .background { AppBackground() }
            .navigationTitle("모티 AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ChatGPT·Gemini처럼 위쪽에서 모델 고르기
                ToolbarItem(placement: .principal) {
                    ModelMenu()
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
            // 말하는 동안 글자가 입력창에 바로 보임
            .onChange(of: voice.transcript) { _, text in
                if voice.isListening { input = text }
            }
            .onDisappear { voice.cancel() }
            .alert(voice.problem == .denied ? L("마이크를 켜 주세요") : L("지금은 들을 수 없어요"), isPresented: Binding(
                get: { voice.problem != nil }, set: { if !$0 { voice.problem = nil } })) {
                if voice.problem == .denied {
                    Button("설정 열기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Button("닫기", role: .cancel) {}
            } message: {
                Text(voice.problem == .denied ? L("설정에서 마이크와 음성 인식을 허용하면 말로 물어볼 수 있어요.") : L("잠시 후 다시 해 주세요."))
            }
            #if DEBUG
            .task {
                if UIShot.matches(.voice) { voice.showDemo("이차방정식 근의 공식 알려줘") }
            }
            #endif
        }
    }

    // MARK: 시작 화면

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 70)
            AIOrb(size: 96)
            VStack(spacing: 8) {
                Text("무엇을 도와드릴까요?")
                    .font(.pt(.title2).weight(.bold))
                    .foregroundStyle(Palette.ink)
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
                        .font(.pt(.body))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(Theme.accent, in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22, bottomTrailingRadius: 8, topTrailingRadius: 22))
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
                                        .font(.pt(.caption).weight(.semibold))
                                        .foregroundStyle(Palette.success)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.success.opacity(0.1), in: .rect(cornerRadius: 12))
                        }
                        if message.isStreaming && message.text.isEmpty {
                            Text(assistant.status.isEmpty ? L("생각하는 중…") : assistant.status.loc)
                                .font(.pt(.footnote))
                                .foregroundStyle(.secondary)
                        } else {
                            // 쓰는 중에는 글자마다 겹쳐 바뀌는 효과 없이 (흔들림 방지), 덜 닫힌 **도 닫아서 보여 줌
                            Text(Self.markdown(MathSymbolBar.pretty(message.isStreaming ? Self.closingMarkdown(message.text) : message.text)))
                                .font(.pt(.body))
                                .lineSpacing(3)
                                .foregroundStyle(Palette.ink)
                                .textSelection(.enabled)
                                .transaction { if message.isStreaming { $0.animation = nil } }
                        }
                        if !message.sources.isEmpty && !message.isStreaming {
                            Label(message.sources.joined(separator: " · "), systemImage: "books.vertical")
                                .font(.pt(.caption2))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        if message.learnTopic != nil && !message.isStreaming {
                            feedbackButtons(message)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: message.isStreaming && message.text.isEmpty ? nil : .infinity, alignment: .leading)
                    .background(Palette.card, in: UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 22, bottomTrailingRadius: 22, topTrailingRadius: 22))
                    .overlay(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 22, bottomTrailingRadius: 22, topTrailingRadius: 22)
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
                .font(.pt(.caption))
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
                Label(message.rating > 0 ? L("기억해 둘게요") : L("다음엔 더 잘 찾아볼게요"),
                      systemImage: message.rating > 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .font(.pt(.footnote))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .animation(.snappy, value: message.rating)
    }

    private var isStreamingText: Bool {
        guard let last = assistant.messages.last else { return false }
        return last.isStreaming
    }

    /// 추천 칩 글자: 고른 언어로 보여 줌 (눌렀을 때 보내는 말은 그대로 한국어 — 모티가 알아듣는 말)
    private static let chipPatterns = ["더 자세히 알려줘", "퀴즈 내줘", "설명해줘", "공부법 알려줘", "인터넷에서 다시 찾아줘", "D-Day 설정해줘", "일정 알려줘", "몰질량"]
    static func chipLabel(_ text: String) -> String {
        if AppLanguage.code == "ko" { return text }
        let direct = text.loc
        if direct != text { return direct }
        for suffix in chipPatterns where text.hasSuffix(" " + suffix) {
            let topic = String(text.dropLast(suffix.count + 1))
            let format = "%@ \(suffix)".loc
            if format != "%@ \(suffix)" { return format.replacingOccurrences(of: "%@", with: topic) }
        }
        return text
    }

    private func suggestionChips(_ suggestions: [String]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button { Task { await assistant.send(suggestion) } } label: {
                        Text(Self.chipLabel(suggestion))
                            .font(.pt(.footnote).weight(.semibold))
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
                    Text("사진 속 글자를 읽어서 정리해요").font(.pt(.caption)).foregroundStyle(.secondary)
                    Spacer()
                    Button { self.attached = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.pt(.title3)).foregroundStyle(.secondary)
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
                            .font(.pt(.headline))
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
                        .font(.pt(.headline))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 42, height: 42)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .transition(.scale.combined(with: .opacity))
                }

                HStack(alignment: .bottom, spacing: 6) {
                    TextField(voice.isListening ? L("듣고 있어요…") : L("모티 AI에게 물어보기"), text: $input, axis: .vertical)
                        .submitLabel(.send)
                        .onSubmit { submit() }
                        .lineLimit(1...5)
                        .focused($focused)
                        .padding(.leading, 16)
                        .padding(.vertical, 11)
                        .disabled(voice.isListening)

                    micButton
                        .padding(.bottom, 5)

                    Button { submit() } label: {
                        Image(systemName: "arrow.up")
                            .font(.pt(.subheadline).weight(.bold))
                            .foregroundStyle(.white)
                            .symbolEffect(.bounce, value: assistant.messages.count)
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

    /// 마이크: 누르면 듣기 시작 → 다시 누르거나 말을 멈추면 보내기
    private var micButton: some View {
        Button {
            Haptics.tap()
            focused = false
            Task {
                await voice.toggle { text in
                    input = text
                    if !text.isEmpty { submit() }
                }
            }
        } label: {
            ZStack {
                if voice.isListening {
                    Circle()
                        .fill(Theme.accent.opacity(0.18))
                        .scaleEffect(1 + CGFloat(voice.level) * 0.5)
                        .animation(.easeOut(duration: 0.15), value: voice.level)
                }
                Image(systemName: voice.isListening ? "waveform" : "mic")
                    .font(.pt(.subheadline).weight(voice.isListening ? .bold : .regular))
                    .foregroundStyle(voice.isListening ? .white : Palette.ink)
                    .symbolEffect(.variableColor.iterative, isActive: voice.isListening)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 32, height: 32)
                    .background(voice.isListening ? Theme.accent : Color.clear, in: .circle)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .disabled(assistant.isResponding)
        .accessibilityLabel(voice.isListening ? L("말하기 끝내기") : L("말로 질문하기"))
    }

    /// **굵게** 같은 간단한 마크다운만 적용
    private static let bottomID = "chat-bottom"

    /// 쓰는 중인 글의 덜 닫힌 굵게(**)·기울임(*)·코드(`) 표시를 닫음: 닫히는 순간 글자 폭이 바뀌며 줄이 튀지 않게
    static func closingMarkdown(_ text: String) -> String {
        var out = text
        if out.hasSuffix("*") && !out.hasSuffix("**") { out.removeLast() }
        if out.components(separatedBy: "**").count % 2 == 0 { out += "**" }
        if out.filter({ $0 == "`" }).count % 2 == 1 { out += "`" }
        return out
    }

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
        !assistant.isResponding && !voice.isListening && (!input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attached != nil)
    }
}

// MARK: - 꾸밈

/// 모티 AI 아이콘: 테마 색 그라데이션 원 + 은은한 빛
private struct AIOrb: View {
    var size: CGFloat

    /// 모티 AI 프로필 = 앱 아이콘(DOOIT 로고)을 둥글게
    var body: some View {
        ZStack {
            if size > 50 {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: size * 1.4, height: size * 1.4)
                    .blur(radius: size * 0.2)
            }
            Image(Theme.current.logoName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.circle)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: max(1, size * 0.02)))
                .shadow(color: .black.opacity(0.12), radius: size * 0.08, y: size * 0.03)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("모티 AI")
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
                    Text(status.loc).font(.pt(.footnote)).foregroundStyle(.secondary)
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
