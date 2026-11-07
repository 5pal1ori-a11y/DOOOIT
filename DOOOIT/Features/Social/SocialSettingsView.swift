import SwiftUI

/// 친구 설정: 닉네임 · 공부 상태 보여주기 · 코드 다시 만들기 · 차단한 사람 · 내 정보 지우기
struct SocialSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var center = SocialCenter.shared
    @State private var nickname = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var info: String?
    @State private var confirmRegenerate = false
    @State private var confirmDelete = false
    @State private var legal: LegalText.Kind?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(L("닉네임"))
                    HStack(spacing: 8) {
                        TextField(L("닉네임"), text: $nickname)
                            .font(.pt(.body))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .glassField()
                            .onChange(of: nickname) { _, new in
                                if new.count > SocialLimits.nicknameMax { nickname = String(new.prefix(SocialLimits.nicknameMax)) }
                            }
                        Button("저장") { saveNickname() }
                            .font(.pt(.subheadline).weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .disabled(busy || nickname == center.state.nickname || nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("내 공부 상태 보여주기").font(.pt(.body)).foregroundStyle(Palette.ink)
                            Text("끄면 친구에게 닉네임만 보여요").font(.pt(.footnote)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Toggle("", isOn: Binding(get: { center.state.showStatus }, set: { setShow($0) }))
                            .labelsHidden()
                            .tint(Theme.accent)
                            .disabled(busy)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    RowDivider()
                    Button { confirmRegenerate = true } label: {
                        RowLabel(symbol: "arrow.triangle.2.circlepath", title: L("친구 코드 다시 만들기"), value: SocialCode.display(center.state.friendCode), chevron: false)
                    }
                    RowDivider()
                    NavigationLink { SocialBlockedView() } label: {
                        RowLabel(symbol: "nosign", title: L("차단한 사람"), value: center.state.blocked.isEmpty ? nil : "\(center.state.blocked.count)")
                    }
                }
                .buttonStyle(.pressableRow)
                .softCardBackground()

                if let errorText { Text(errorText).font(.pt(.footnote)).foregroundStyle(Palette.danger) }
                if let info { Text(info).font(.pt(.footnote)).foregroundStyle(.secondary) }

                VStack(spacing: 0) {
                    Button { legal = .terms } label: { RowLabel(symbol: "doc.text", title: L("이용약관")) }
                    RowDivider()
                    Button { legal = .privacy } label: { RowLabel(symbol: "lock", title: L("개인정보 처리방침")) }
                }
                .buttonStyle(.pressableRow)
                .softCardBackground()

                VStack(alignment: .leading, spacing: 8) {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        RowLabel(symbol: "trash", color: Palette.danger, title: L("친구 기능 끄고 내 정보 지우기"), chevron: false)
                            .foregroundStyle(Palette.danger)
                    }
                    .buttonStyle(.pressableRow)
                    .softCardBackground()
                    Text("내 프로필, 그룹 멤버 기록, 내가 만든 그룹이 모두 지워져요. 친구에게서도 사라져요.")
                        .font(.pt(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .navigationTitle("친구 설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { nickname = center.state.nickname }
        .sheet(item: $legal) { kind in
            NavigationStack {
                LegalDocumentView(kind: kind)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { legal = nil } } }
            }
        }
        .confirmationDialog("친구 코드를 다시 만들까요?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("다시 만들기") { regenerate() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("예전 코드로는 더 이상 나를 찾을 수 없어요. 이미 친구인 사람은 그대로예요.")
        }
        .confirmationDialog("내 정보를 모두 지울까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("지우기", role: .destructive) { deleteAll() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("되돌릴 수 없어요. 다시 쓰려면 처음부터 시작해야 해요.")
        }
    }

    private func saveNickname() {
        busy = true; errorText = nil; info = nil
        Task {
            do { try await center.setNickname(nickname); info = L("저장했어요") } catch { errorText = SocialText.message(for: error) }
            busy = false
        }
    }

    private func setShow(_ on: Bool) {
        busy = true; errorText = nil; info = nil
        Task {
            do { try await center.setShowStatus(on) } catch { errorText = SocialText.message(for: error) }
            busy = false
        }
    }

    private func regenerate() {
        busy = true; errorText = nil; info = nil
        Task {
            do { try await center.regenerateFriendCode(); info = L("새 코드를 만들었어요") } catch { errorText = SocialText.message(for: error) }
            busy = false
        }
    }

    private func deleteAll() {
        busy = true; errorText = nil; info = nil
        Task {
            do {
                try await center.deleteEverything()
                dismiss()
            } catch {
                errorText = SocialText.message(for: error)
            }
            busy = false
        }
    }
}

/// 차단한 사람 (여기서 풀 수 있어요)
private struct SocialBlockedView: View {
    @State private var center = SocialCenter.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if center.state.blocked.isEmpty {
                    EmptyStateView(symbol: "nosign", title: L("차단한 사람이 없어요")).softCardBackground()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(center.state.blocked.enumerated()), id: \.element.id) { index, ref in
                            if index > 0 { SocialDivider() }
                            HStack(spacing: 12) {
                                SocialAvatar(name: ref.nickname)
                                Text(ref.nickname).font(.pt(.body)).foregroundStyle(Palette.ink).lineLimit(1)
                                Spacer()
                                Button("차단 풀기") { center.engine.unblock(ref.id) }
                                    .font(.pt(.subheadline).weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                    .softCardBackground()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle("차단한 사람")
        .navigationBarTitleDisplayMode(.inline)
    }
}
