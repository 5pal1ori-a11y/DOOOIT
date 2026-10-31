import AuthenticationServices
import SwiftUI

/// 첫 화면: Apple로 계속하기 / 이메일로 계속하기
struct AuthView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.colorScheme) private var scheme
    @State private var showEmail = false
    @State private var errorMessage: String?
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Text("DOOOIT")
                        .font(.system(size: 58, weight: .black))
                        .kerning(-1.5)
                    Text("계획하고, 집중하고, 해내다.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                Spacer()

                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        FeatureRow(symbol: "calendar.badge.clock",
                                   title: "자동으로 시작되는 공부 타이머",
                                   subtitle: "플랜 시간이 되면 다이나믹 아일랜드로 알려드려요")
                        FeatureRow(symbol: "text.viewfinder",
                                   title: "사진 한 장으로 영어 단어장",
                                   subtitle: "찍기만 하면 단어와 뜻을 자동으로 정리해요")
                        FeatureRow(symbol: "pencil.and.scribble",
                                   title: "필기하는 수학 오답노트",
                                   subtitle: "펜, 형광펜, 텍스트로 풀이를 남겨요")
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)

                Spacer()

                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        do {
                            try auth.handleAppleSignIn(result)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                    .frame(height: 54)
                    .clipShape(Capsule())
                    .id(scheme) // 다크모드 전환 시 버튼 스타일 갱신

                    Button {
                        showEmail = true
                    } label: {
                        Label("이메일로 계속하기", systemImage: "envelope.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)

                    Text("계속하면 서비스 이용약관 및 개인정보 처리방침에 동의하게 됩니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showEmail) {
            EmailAuthView()
        }
        .errorAlert($errorMessage, title: "로그인 실패")
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) { appeared = true }
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(symbol: symbol, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}

/// 이메일 로그인 / 회원가입
struct EmailAuthView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "로그인"
        case signUp = "회원가입"
        var id: String { rawValue }
    }

    enum Field: Hashable { case name, email, password, confirm }

    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signUp
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("모드", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(mode == .signUp ? "DOOOIT 시작하기" : "다시 만나서 반가워요")
                            .font(.title2.weight(.bold))
                        Text(mode == .signUp ? "이메일로 간단하게 가입하세요." : "가입한 이메일로 로그인하세요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 12) {
                        if mode == .signUp {
                            fieldRow(symbol: "person.fill") {
                                TextField("이름 (닉네임)", text: $name)
                                    .textContentType(.nickname)
                                    .focused($focus, equals: .name)
                                    .submitLabel(.next)
                                    .onSubmit { focus = .email }
                            }
                        }
                        fieldRow(symbol: "envelope.fill") {
                            TextField("이메일", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focus, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focus = .password }
                        }
                        fieldRow(symbol: "lock.fill") {
                            SecureField("비밀번호 (8자 이상)", text: $password)
                                .textContentType(mode == .signUp ? .newPassword : .password)
                                .focused($focus, equals: .password)
                                .submitLabel(mode == .signUp ? .next : .go)
                                .onSubmit {
                                    if mode == .signUp { focus = .confirm } else { submit() }
                                }
                        }
                        if mode == .signUp {
                            fieldRow(symbol: "lock.rotation") {
                                SecureField("비밀번호 확인", text: $confirm)
                                    .textContentType(.newPassword)
                                    .focused($focus, equals: .confirm)
                                    .submitLabel(.go)
                                    .onSubmit { submit() }
                            }
                        }
                    }
                    .animation(.smooth, value: mode)

                    Button(action: submit) {
                        Text(mode == .signUp ? "가입하고 시작하기" : "로그인")
                            .font(.body.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .padding(.top, 6)

                    Label("계정 정보는 이 기기 안에 안전하게(Keychain) 저장돼요.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("이메일로 계속하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            .errorAlert($errorMessage, title: mode.rawValue)
        }
    }

    private func fieldRow<Content: View>(symbol: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            content()
        }
        .glassField()
    }

    private func submit() {
        do {
            switch mode {
            case .signUp:
                try auth.signUp(name: name, email: email, password: password, confirm: confirm)
            case .signIn:
                try auth.signIn(email: email, password: password)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Apple 로그인 시 이름을 받지 못한 경우 닉네임 설정
struct NameSetupView: View {
    @Environment(AuthManager.self) private var auth
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 20) {
                Spacer()
                IconBadge(symbol: "hand.wave.fill", size: 56)
                Text("어떻게 불러드릴까요?")
                    .font(.largeTitle.weight(.bold))
                Text("홈 화면에서 \"OO님, 오늘도 힘내보아요!\"처럼 인사해 드릴게요.")
                    .foregroundStyle(.secondary)
                TextField("이름 또는 닉네임", text: $name)
                    .font(.title3)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .glassField()
                Spacer()
                Button(action: save) {
                    Text("시작하기")
                        .font(.body.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(24)
        }
        .onAppear { focused = true }
    }

    private func save() {
        auth.updateName(name)
    }
}
