import AuthenticationServices
import SwiftUI

/// 첫 화면: 로그인 / 회원가입 (이메일) + Apple로 계속하기
struct AuthView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "로그인"
        case signUp = "회원가입"
        var id: String { rawValue }
    }

    enum Field: Hashable { case name, email, password, confirm }

    @Environment(AuthManager.self) private var auth
    @Environment(\.colorScheme) private var scheme

    @State private var mode: Mode = .signUp
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var showPassword = false
    @State private var isSubmitting = false
    /// 이메일 로그인/가입 실패
    @State private var errorMessage: String?
    /// Apple 로그인 실패
    @State private var appleErrorMessage: String?
    @State private var shakeTrigger = 0
    @FocusState private var focus: Field?

    var body: some View {
        ZStack {
            BrandBackdrop()

            GeometryReader { geo in
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            Spacer(minLength: 24)
                            content
                            Spacer(minLength: 16)
                        }
                        .frame(maxWidth: 440)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollBounceBehavior(.basedOnSize)
                    .onChange(of: focus) { _, field in
                        guard let field else { return }
                        withAnimation(Motion.spring) { proxy.scrollTo(field, anchor: .center) }
                    }
                }
            }
            .errorAlert($errorMessage, title: mode.rawValue)
        }
        .errorAlert($appleErrorMessage, title: "로그인 실패")
        .onChange(of: mode) {
            // 사라지는 칸에 커서가 있었으면 이메일 칸으로
            if focus == .name || focus == .confirm { focus = .email }
        }
    }

    // MARK: 화면 구성

    private var content: some View {
        VStack(spacing: 0) {
            hero
                .padding(.bottom, 28)
                .appearAnimation()

            PillSegmentedControl(items: Mode.allCases, selection: $mode) { $0.rawValue }
                .disabled(isSubmitting)
                .padding(.bottom, 18)
                .appearAnimation(delay: 0.05)

            fields
                .shake(trigger: shakeTrigger)
                .appearAnimation(delay: 0.1)

            primaryButton
                .padding(.top, 22)
                .appearAnimation(delay: 0.14)

            orDivider
                .padding(.vertical, 18)
                .appearAnimation(delay: 0.18)

            appleButton
                .appearAnimation(delay: 0.18)

            Text("계속하면 이용약관 및 개인정보 처리방침에 동의하게 돼요.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            BrandLogo(size: 84)
                .padding(.bottom, 14)
            Text(mode == .signUp ? "DOOOIT 시작하기" : "다시 만나서 반가워요")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.ink)
                .contentTransition(.opacity)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("오늘 할 일, 끝까지 두잇")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .animation(Motion.spring, value: mode)
    }

    private var fields: some View {
        VStack(spacing: 12) {
            if mode == .signUp {
                AuthField(symbol: "person.fill", isFocused: focus == .name) {
                    TextField("이름 (닉네임)", text: $name)
                        .textContentType(.nickname)
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focus = .email }
                }
                .id(Field.name)
                .transition(fieldTransition)
            }

            AuthField(symbol: "envelope.fill", isFocused: focus == .email, message: emailMessage) {
                TextField("이메일", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
            }
            .id(Field.email)

            AuthField(symbol: "lock.fill", isFocused: focus == .password, message: passwordMessage) {
                passwordInput(mode == .signUp ? "비밀번호 (8자 이상)" : "비밀번호", text: $password, field: .password,
                              contentType: mode == .signUp ? .newPassword : .password)
                    .submitLabel(mode == .signUp ? .next : .go)
                    .onSubmit {
                        if mode == .signUp { focus = .confirm } else { submit() }
                    }
            } trailing: {
                revealButton
            }
            .id(Field.password)

            if mode == .signUp {
                AuthField(symbol: "lock.rotation", isFocused: focus == .confirm, message: confirmMessage) {
                    passwordInput("비밀번호 확인", text: $confirm, field: .confirm, contentType: .newPassword)
                        .submitLabel(.go)
                        .onSubmit { submit() }
                }
                .id(Field.confirm)
                .transition(fieldTransition)
            }
        }
        .animation(Motion.spring, value: mode)
    }

    private var fieldTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
    }

    private func passwordInput(_ placeholder: String, text: Binding<String>, field: Field,
                               contentType: UITextContentType) -> some View {
        Group {
            if showPassword {
                TextField(placeholder, text: text)
            } else {
                SecureField(placeholder, text: text)
            }
        }
        .textContentType(contentType)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($focus, equals: field)
    }

    private var revealButton: some View {
        Button {
            let current = focus
            showPassword.toggle()
            // 보기/숨기기로 칸이 바뀌어도 커서 유지
            if let current { Task { @MainActor in focus = current } }
        } label: {
            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showPassword ? "비밀번호 숨기기" : "비밀번호 보기")
    }

    private var primaryButton: some View {
        Button(action: submit) {
            ZStack {
                Text(mode == .signUp ? "가입하고 시작하기" : "로그인")
                    .contentTransition(.opacity)
                    .opacity(isSubmitting ? 0 : 1)
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .transition(.opacity)
                }
            }
            .animation(Motion.quick, value: isSubmitting)
        }
        .buttonStyle(.primaryFill)
        .shadow(color: Theme.accent.opacity(0.32), radius: 14, y: 6)
        .disabled(isSubmitting)
        .accessibilityLabel(mode == .signUp ? "가입하고 시작하기" : "로그인")
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Capsule().fill(Color.primary.opacity(0.1)).frame(height: 1)
            Text("또는")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Capsule().fill(Color.primary.opacity(0.1)).frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            do {
                try auth.handleAppleSignIn(result)
            } catch {
                appleErrorMessage = error.localizedDescription
            }
        }
        .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
        .frame(height: 52)
        .clipShape(.rect(cornerRadius: 16, style: .continuous))
        .id(scheme) // 다크모드 전환 시 버튼 스타일 갱신
        .disabled(isSubmitting)
    }

    // MARK: 짧은 안내 (입력을 마친 칸에만)

    private var emailMessage: String? {
        let trimmed = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, focus != .email, !AuthManager.isValidEmail(trimmed) else { return nil }
        return "이메일 형식을 확인해 주세요"
    }

    private var passwordMessage: String? {
        guard mode == .signUp, !password.isEmpty, focus != .password, password.count < 8 else { return nil }
        return "8자 이상 입력해 주세요"
    }

    private var confirmMessage: String? {
        guard mode == .signUp, !confirm.isEmpty, confirm != password,
              focus != .confirm || confirm.count >= password.count else { return nil }
        return "비밀번호가 달라요"
    }

    // MARK: 동작

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        let mode = self.mode
        Task { @MainActor in
            // 로딩 표시가 먼저 그려지도록 잠깐 양보 (비밀번호 확인 계산이 무거움)
            try? await Task.sleep(for: .milliseconds(80))
            do {
                switch mode {
                case .signUp:
                    try auth.signUp(name: name, email: email, password: password, confirm: confirm)
                case .signIn:
                    try auth.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
                shakeTrigger += 1
                Haptics.error()
            }
            isSubmitting = false
        }
    }
}

// MARK: - 입력 칸

/// 아이콘 + 입력 + (선택) 오른쪽 버튼, 포커스되면 강조색 테두리, 아래에 짧은 안내
private struct AuthField<Content: View, Trailing: View>: View {
    let symbol: String
    let isFocused: Bool
    let message: String?
    let content: Content
    let trailing: Trailing

    init(symbol: String, isFocused: Bool, message: String? = nil,
         @ViewBuilder content: () -> Content, @ViewBuilder trailing: () -> Trailing) {
        self.symbol = symbol
        self.isFocused = isFocused
        self.message = message
        self.content = content()
        self.trailing = trailing()
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }

    private var borderColor: Color {
        if message != nil { return Palette.danger.opacity(0.85) }
        return isFocused ? Theme.accent : Color.primary.opacity(0.08)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(message != nil ? Palette.danger : (isFocused ? Theme.accent : Color.secondary))
                    .frame(width: 22)
                    .accessibilityHidden(true)
                content
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                trailing
            }
            .padding(.leading, 16)
            .padding(.trailing, Trailing.self == EmptyView.self ? 16 : 6)
            .frame(height: 54)
            .background(Palette.card, in: shape)
            .overlay(shape.strokeBorder(borderColor, lineWidth: isFocused || message != nil ? 1.5 : 0.75))
            .shadow(color: isFocused ? Theme.accent.opacity(0.18) : .black.opacity(0.04),
                    radius: isFocused ? 12 : 6, y: isFocused ? 4 : 2)

            if let message {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.danger)
                    .padding(.leading, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(Motion.quick, value: isFocused)
        .animation(Motion.spring, value: message)
    }
}

extension AuthField where Trailing == EmptyView {
    init(symbol: String, isFocused: Bool, message: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(symbol: symbol, isFocused: isFocused, message: message, content: content, trailing: { EmptyView() })
    }
}

// MARK: - 이름 설정

/// Apple 로그인 시 이름을 받지 못한 경우 닉네임 설정
struct NameSetupView: View {
    @Environment(AuthManager.self) private var auth
    /// 테마를 고르면 이 화면의 강조 색도 바로 바뀌도록 구독
    @AppStorage(SettingsKey.themeColor) private var themeRaw = ThemeColor.lavender.rawValue
    @State private var name = ""
    @FocusState private var focused: Bool

    private var isEmpty: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            BrandBackdrop()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 24)

                BrandLogo(size: 64)
                    .padding(.bottom, 22)
                    .appearAnimation()

                VStack(alignment: .leading, spacing: 6) {
                    Text("어떻게 불러드릴까요?")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("홈에서 이름으로 인사해 드려요")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 26)
                .appearAnimation(delay: 0.05)

                AuthField(symbol: "person.fill", isFocused: focused) {
                    TextField("이름 또는 닉네임", text: $name)
                        .textContentType(.nickname)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
                .appearAnimation(delay: 0.1)

                Text("테마 색")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                    .padding(.leading, 6)

                ThemePicker()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(height: 54)
                    .background(Palette.card, in: .rect(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75))
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                    .appearAnimation(delay: 0.14)

                Spacer(minLength: 24)

                Button(action: save) {
                    Text("시작하기")
                }
                .buttonStyle(.primaryFill)
                .shadow(color: Theme.accent.opacity(isEmpty ? 0 : 0.32), radius: 14, y: 6)
                .opacity(isEmpty ? 0.5 : 1)
                .disabled(isEmpty)
                .animation(Motion.quick, value: isEmpty)
                .id(themeRaw) // 테마 색을 바꾸면 버튼 색도 바로 갱신
            }
            .frame(maxWidth: 440)
            .padding(24)
        }
        .onAppear { focused = true }
    }

    private func save() {
        auth.updateName(name)
    }
}
