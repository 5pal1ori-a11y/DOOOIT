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
        Suggestion(symbol: "character.book.closed", text: "단어 추가해줘: abundant 풍부한, resilient 회복력 있는"),
        Suggestion(symbol: "chart.bar", text: "이번 주 공부 통계 보여줘"),
        Suggestion(symbol: "flag.checkered", text: "기말고사 D-Day 12월 10일로 설정해줘"),
        Suggestion(symbol: "function", text: "이차함수 꼭짓점 구하는 법 설명해줘"),
        Suggestion(symbol: "camera", text: "사진 속 문제 풀어주고 오답노트에 넣어줘"),
        Suggestion(symbol: "note.text", text: "메모해줘: 수행평가 준비물 챙기기")
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
                Text("말로 시키면 일정 추가, 타이머, 단어, 오답노트, 메모, 목표 설정까지 대신 해드려요. 사진을 보내면 문제 풀이, 단어장 정리도 해요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let message = assistant.unavailableMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Palette.warning)
                    .padding(14)
                    .background(Palette.warning.opacity(0.12), in: .rect(cornerRadius: 16))
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
            Text("인터넷이 필요해요. AI 답은 틀릴 수 있어요.")
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
                    Image(systemName: "sparkles").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                    Text("두잇 AI").font(.caption.weight(.bold)).foregroundStyle(.secondary)
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
                    Text("사진을 두잇 AI가 직접 보고 분석해요").font(.caption).foregroundStyle(.secondary)
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
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))

                Button {
                    let text = input
                    let image = attached
                    input = ""
                    attached = nil
                    Task { await assistant.send(text, image: image) }
                } label: {
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

    private var canSend: Bool {
        !assistant.isResponding && (!input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attached != nil)
    }
}
