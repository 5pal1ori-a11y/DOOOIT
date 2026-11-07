import SwiftUI

/// 친구 · 그룹 첫 화면: 처음이면 안내(약관 포함) → 켠 뒤에는 "친구 | 그룹"
struct SocialHubView: View {
    enum Tab: Hashable { case friends, groups }

    @State private var center = SocialCenter.shared
    @State private var tab: Tab

    init(tab: Tab = .friends) {
        _tab = State(initialValue: tab)
    }

    var body: some View {
        Group {
            if center.isEnabled {
                VStack(spacing: 0) {
                    PillSegmentedControl(items: [Tab.friends, Tab.groups], selection: $tab) {
                        $0 == .friends ? L("친구") : L("그룹")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    switch tab {
                    case .friends: SocialFriendsTab()
                    case .groups: SocialGroupsTab()
                    }
                }
                .background { AppBackground() }
            } else {
                SocialIntroView()
            }
        }
        .navigationTitle("친구")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if center.isEnabled {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SocialSettingsView() } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("친구 설정")
                }
            }
        }
        .task { await center.refreshAccountStatus() }
    }
}

// MARK: - 처음 안내 (약관 · 닉네임)

private struct SocialIntroView: View {
    @Environment(AuthManager.self) private var auth
    @State private var center = SocialCenter.shared
    @State private var nickname = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var legal: LegalText.Kind?

    private var noAccount: Bool { center.accountStatus == .noAccount || center.accountStatus == .restricted }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.pt(size: 28, weight: .light))
                        .foregroundStyle(Theme.secondary)
                    Text("친구와 같이 공부해요")
                        .font(.pt(size: 28, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("누가 지금 공부 중인지, 오늘 얼마나 했는지 볼 수 있어요.")
                        .font(.pt(.subheadline))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    bullet("eye", L("친구에게는 닉네임과 공부 시간만 보여요"))
                    RowDivider()
                    bullet("number", L("친구 코드를 아는 사람만 나를 찾을 수 있어요"))
                    RowDivider()
                    bullet("hand.raised", L("신고와 차단은 언제든 할 수 있어요"))
                    RowDivider()
                    bullet("trash", L("설정에서 내 정보를 모두 지울 수 있어요"))
                }
                .softCardBackground()

                VStack(alignment: .leading, spacing: 8) {
                    Text("닉네임").font(.pt(.footnote)).foregroundStyle(.secondary)
                    TextField(L("친구에게 보일 이름"), text: $nickname)
                        .font(.pt(.body))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .glassField()
                        .onChange(of: nickname) { _, new in
                            if new.count > SocialLimits.nicknameMax { nickname = String(new.prefix(SocialLimits.nicknameMax)) }
                        }
                }

                if noAccount {
                    Text("iCloud에 로그인하면 친구와 같이 공부할 수 있어요")
                        .font(.pt(.footnote))
                        .foregroundStyle(Palette.danger)
                } else if let errorText {
                    Text(errorText).font(.pt(.footnote)).foregroundStyle(Palette.danger)
                }

                Button {
                    start()
                } label: {
                    if busy { ProgressView().tint(Theme.onAccent) } else { Text("시작하기") }
                }
                .buttonStyle(.primaryFill)
                .disabled(busy || noAccount || nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(noAccount ? 0.5 : 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text("시작하면 아래에 동의한 것으로 봐요.")
                    HStack(spacing: 12) {
                        Button("이용약관") { legal = .terms }
                        Button("개인정보 처리방침") { legal = .privacy }
                    }
                    .foregroundStyle(Theme.accent)
                }
                .font(.pt(.caption))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .sheet(item: $legal) { kind in
            NavigationStack {
                LegalDocumentView(kind: kind)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { legal = nil } } }
            }
        }
        .onAppear {
            if nickname.isEmpty, let name = auth.currentUser?.name, auth.currentUser?.provider != .guest {
                nickname = String(name.prefix(SocialLimits.nicknameMax))
            }
        }
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        RowLabel(symbol: symbol, title: text, chevron: false)
    }

    private func start() {
        busy = true
        errorText = nil
        Task {
            do {
                try await center.setUp(nickname: nickname)
            } catch {
                errorText = SocialText.message(for: error)
            }
            busy = false
        }
    }
}

// MARK: - 글자 · 시간 모양

enum SocialText {
    /// 오류를 짧은 안내 글로
    static func message(for error: Error) -> String {
        guard let e = error as? SocialError else { return L("문제가 생겼어요. 잠시 뒤에 다시 해 주세요") }
        switch e {
        case .noAccount: return L("iCloud에 로그인하면 친구와 같이 공부할 수 있어요")
        case .restricted: return L("이 기기에서는 iCloud를 쓸 수 없어요")
        case .network: return L("인터넷 연결을 확인해 주세요")
        case .rateLimited: return L("요청이 많아요. 잠시 뒤에 다시 해 주세요")
        case .unavailable: return L("지금은 친구 기능을 쓸 수 없어요. 나중에 다시 해 주세요")
        case .server: return L("문제가 생겼어요. 잠시 뒤에 다시 해 주세요")
        case .notFound, .groupGone: return L("그룹이 없어졌어요")
        case .permissionDenied: return L("이 작업을 할 수 없어요")
        case .notSetUp: return L("먼저 친구 기능을 켜 주세요")
        case .nicknameEmpty: return L("닉네임을 입력해 주세요")
        case .nicknameTooLong: return L("닉네임은 \(SocialLimits.nicknameMax)자까지 쓸 수 있어요")
        case .nicknameRejected: return L("쓸 수 없는 이름이에요")
        case .invalidCode: return L("코드를 다시 확인해 주세요")
        case .codeNotFound: return L("이 코드를 찾을 수 없어요")
        case .selfCode: return L("내 코드예요")
        case .alreadyFriend: return L("이미 친구예요")
        case .blockedUser: return L("차단한 사람이에요. 설정에서 풀 수 있어요")
        case .friendLimit: return L("친구는 \(SocialLimits.friendMax)명까지 추가할 수 있어요")
        case .groupNameInvalid: return L("그룹 이름을 확인해 주세요 (\(SocialLimits.groupNameMax)자까지)")
        case .groupLimit: return L("그룹은 \(SocialLimits.joinedGroupMax)개까지 들어갈 수 있어요")
        case .groupFull: return L("그룹이 가득 찼어요")
        case .alreadyMember: return L("이미 들어간 그룹이에요")
        case .notOwner: return L("만든 사람만 할 수 있어요")
        case .removedFromGroup: return L("이 그룹에서 나가게 됐어요")
        }
    }

    /// "1시간 20분" / "45분" / "0분"
    static func time(_ seconds: Int) -> String { TimeText.durationL(seconds: seconds) }

    static func presence(_ state: SocialPresenceState) -> String {
        switch state {
        case .studying(let minutes): return L("공부 중 · \(TimeText.durationL(minutes: minutes))째")
        case .idle: return L("쉬는 중")
        case .hidden: return L("비공개")
        }
    }

    static func isStudying(_ state: SocialPresenceState) -> Bool {
        if case .studying = state { return true }
        return false
    }
}

/// 목록 줄 사이 선 (왼쪽을 아바타 뒤로 들여씀)
struct SocialDivider: View {
    var leading: CGFloat = 64
    var body: some View { Rectangle().fill(Palette.line).frame(height: 0.5).padding(.leading, leading) }
}

/// 닉네임 첫 글자를 담은 회색 동그라미
struct SocialAvatar: View {
    let name: String
    var size: CGFloat = 36

    var body: some View {
        Text(String(name.prefix(1)))
            .font(.pt(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Theme.secondary)
            .frame(width: size, height: size)
            .background(Palette.cardInset, in: Circle())
    }
}

/// 사람 한 줄: 이름 · 지금 상태 · 오늘 공부 시간 (오른쪽) · 더보기 메뉴
struct SocialPersonRow<MenuContent: View>: View {
    let name: String
    let state: SocialPresenceState?
    /// nil이면 시간을 알 수 없음(비공개 · 못 불러옴)
    let seconds: Int?
    var highlight = false
    var tag: String? = nil
    var rank: Int? = nil
    var showMenu = true
    @ViewBuilder var menu: MenuContent

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text("\(rank)")
                    .font(.pt(.subheadline).weight(rank <= 3 ? .bold : .regular))
                    .foregroundStyle(rank <= 3 ? Theme.accent : Color.secondary)
                    .monospacedDigit()
                    .frame(width: 22, alignment: .trailing)
            }
            SocialAvatar(name: name)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(.pt(.body)).foregroundStyle(Palette.ink).lineLimit(1)
                    if let tag { TagLabel(text: tag) }
                }
                if let state {
                    HStack(spacing: 5) {
                        if SocialText.isStudying(state) {
                            Circle().fill(Palette.success).frame(width: 6, height: 6)
                        }
                        Text(SocialText.presence(state))
                            .font(.pt(.footnote))
                            .foregroundStyle(SocialText.isStudying(state) ? Palette.success : Color.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("불러오지 못했어요").font(.pt(.footnote)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(seconds.map { SocialText.time($0) } ?? "–")
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(seconds == nil ? Color.secondary : Palette.ink)
                .monospacedDigit()
                .numberRoll(seconds.map { SocialText.time($0) } ?? "–")
                .lineLimit(1)
            if showMenu {
                Menu {
                    menu
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.pt(.subheadline))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("더보기")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(highlight ? Theme.accent.opacity(0.08) : Color.clear)
    }
}
