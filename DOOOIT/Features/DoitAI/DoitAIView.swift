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

    private struct Suggestion: Identifiable {
        let symbol: String
        let text: String
        var id: String { text }
    }

    private let suggestions: [Suggestion] = [
        Suggestion(symbol: "calendar", text: "오늘 할 일 알려줘"),
        Suggestion(symbol: "plus.circle", text: "내일 오후 4시에 수학 공부 2시간 추가해줘"),
        Suggestion(symbol: "timer", text: "영어 단어 25분 타이머 시작해줘"),
        Suggestion(symbol: "function", text: "x³−6x²+11x−6=0 풀어줘"),
        Suggestion(symbol: "character.book.closed", text: "현재완료 설명해줘"),
        Suggestion(symbol: "atom", text: "전압 12V 저항 4Ω 전류는?"),
        Suggestion(symbol: "globe.asia.australia", text: "임진왜란 언제 일어났어?"),
        Suggestion(symbol: "gamecontroller", text: "수학 퀴즈 내줘"),
        Suggestion(symbol: "heart.text.square", text: "집중이 안 돼"),
        Suggestion(symbol: "questionmark.circle", text: "뭐 할 수 있어?")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if assistant.messages.isEmpty {
                                welcome
                            }
                            ForEach(assistant.messages) { message in
                                bubble(message).id(message.id)
                            }
                            if assistant.isResponding {
                                typing.id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)
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
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: .rect(cornerRadius: 18))
                Text("무엇을 도와드릴까요?").font(.title.weight(.heavy))
                Text("말로 시키면 일정, 타이머, 단어, 오답노트, 메모, 목표 설정을 대신 해드려요. 방정식도 풀어요. 사진을 보내면 글자를 읽어서 단어장이나 오답노트로 정리해요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    Button {
                        Task { await assistant.send(suggestion.text) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: suggestion.symbol)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 22)
                            Text(suggestion.text).font(.subheadline).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.7), in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(DoitAppleAI.isAvailable ? "두잇 AI 엔진과 기기 안 Apple Intelligence가 함께 답해요. 대화는 휴대폰 밖으로 나가지 않아요." : "두잇 AI 엔진이 휴대폰 안에서 답해요. Apple Intelligence를 켜면 더 자유롭게 대화할 수 있어요.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
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
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(.rect(cornerRadius: 14))
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.accent, in: .rect(cornerRadius: 20))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 50)
        case .assistant:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: message.source == .apple ? "apple.intelligence" : "sparkles")
                        .font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                    Text(message.source == .apple ? "두잇 AI · Apple Intelligence" : "두잇 AI")
                        .font(.caption.weight(.bold)).foregroundStyle(.secondary)
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
                    .textSelection(.enabled)
                if message.source == .apple {
                    Text(DoitAppleAI.caution)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if !message.suggestions.isEmpty && message.id == assistant.messages.last?.id {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(message.suggestions, id: \.self) { suggestion in
                                Button { Task { await assistant.send(suggestion) } } label: {
                                    Text(suggestion)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.accent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Theme.accent.opacity(0.12), in: .capsule)
                                }
                                .buttonStyle(.plain)
                                .disabled(assistant.isResponding)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .padding(.trailing, 24)
        case .notice:
            Label(message.text, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private var typing: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(assistant.status.isEmpty ? "생각하는 중…" : assistant.status).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(14)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: 입력창

    private var inputBar: some View {
        VStack(spacing: 8) {
            if let attached {
                HStack {
                    Image(uiImage: attached)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(.rect(cornerRadius: 10))
                    Text("사진 속 글자를 읽어서 정리해요").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { self.attached = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
            HStack(alignment: .bottom, spacing: 10) {
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
                        .frame(width: 40, height: 40)
                }
                .glassEffect(.regular.interactive(), in: .circle)

                TextField("두잇 AI에게 부탁하기", text: $input, axis: .vertical)
                    .onSubmit { submit() }
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))

                Button { submit() } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(canSend ? Theme.accent : Color.secondary.opacity(0.4), in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
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
        Task { await assistant.send(text, image: image) }
    }

    private var canSend: Bool {
        !assistant.isResponding && (!input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attached != nil)
    }
}
