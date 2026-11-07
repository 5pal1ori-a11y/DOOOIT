import SwiftUI
import UIKit

/// 친구 탭: 내 친구 코드 · 친구 목록(공부 중 먼저) · 추가 · 신고 · 차단
struct SocialFriendsTab: View {
    @State private var center = SocialCenter.shared
    @State private var rows: [FriendRow] = []
    @State private var loaded = false
    @State private var loading = false
    @State private var errorText: String?
    @State private var showAdd: Bool = {
        #if DEBUG
        return UIShot.matches(.friendsAdd)
        #else
        return false
        #endif
    }()
    @State private var reporting: ReportTarget?
    @State private var removing: FriendRef?
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                myCodeCard
                if center.publishFailing {
                    Text("내 상태를 아직 올리지 못했어요. 연결되면 다시 올려요.")
                        .font(.pt(.footnote))
                        .foregroundStyle(.secondary)
                }
                friendsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .refreshable { await load() }
        .task {
            center.screenOpened()
            await load()
            // 이 화면이 보이는 동안만 30초마다 새로 불러옴 (화면을 떠나면 자동으로 멈춤)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { break }
                await load()
            }
        }
        .sheet(isPresented: $showAdd) {
            AddFriendSheet { await load() }
        }
        .sheet(item: $reporting) { target in
            ReportSheet(target: target) { reason in
                await center.engine.report(profileID: target.id, nickname: target.nickname, reason: reason)
                await load()
            }
        }
        .confirmationDialog("친구에서 삭제할까요?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                if let removing { center.engine.removeFriend(removing.id); rows.removeAll { $0.id == removing.id } }
                removing = nil
            }
            Button("취소", role: .cancel) { removing = nil }
        }
    }

    // MARK: 내 코드

    private var myCodeCard: some View {
        let code = center.state.friendCode
        let shareText = L("MOTI에서 같이 공부해요! 내 친구 코드: \(SocialCode.display(code))")
        return VStack(alignment: .leading, spacing: 12) {
            Text("내 친구 코드").font(.pt(.footnote)).foregroundStyle(.secondary)
            Text(SocialCode.display(code))
                .font(.pt(size: 34, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            HStack(spacing: 8) {
                Button {
                    UIPasteboard.general.string = shareText
                    copied = true
                    Haptics.tap()
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                } label: {
                    Label(copied ? L("복사했어요") : L("복사"), systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.pt(.subheadline).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Palette.cardInset, in: .rect(cornerRadius: Radius.field, style: .continuous))
                }
                .buttonStyle(.pressable)
                ShareLink(item: shareText) {
                    Label("공유", systemImage: "square.and.arrow.up")
                        .font(.pt(.subheadline).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Palette.cardInset, in: .rect(cornerRadius: Radius.field, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
            .foregroundStyle(Palette.ink)
        }
        .softCard()
    }

    // MARK: 친구 목록

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("친구 \(center.state.friends.count)")
                    .font(.pt(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Button { showAdd = true } label: {
                    Text("친구 추가").font(.pt(.subheadline).weight(.semibold))
                }
                .foregroundStyle(Theme.accent)
            }
            if let errorText {
                Text(errorText).font(.pt(.footnote)).foregroundStyle(.secondary)
            }
            if center.state.friends.isEmpty {
                VStack(spacing: 12) {
                    EmptyStateView(symbol: "person.2", title: L("아직 친구가 없어요"), message: L("친구 코드를 입력하면 같이 공부할 수 있어요"))
                    Button("친구 추가") { showAdd = true }.buttonStyle(.primaryFill)
                        .padding(.horizontal, 16).padding(.bottom, 16)
                }
                .softCardBackground()
            } else if !loaded && loading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 32)
            } else {
                let sorted = sortedRows
                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { SocialDivider() }
                        friendRow(row)
                    }
                }
                .softCardBackground()
            }
        }
    }

    private var sortedRows: [FriendRow] {
        let now = Date()
        let order = SocialPresence.sortedForList(rows.compactMap(\.profile), now: now).map(\.id)
        let known = order.compactMap { id in rows.first { $0.id == id } }
        return known + rows.filter { $0.profile == nil }
    }

    private func friendRow(_ row: FriendRow) -> some View {
        let now = Date()
        let name = row.profile?.nickname ?? row.ref.nickname
        let state = row.profile.map { SocialPresence.state(of: $0, now: now) }
        let seconds = row.profile.flatMap { SocialPresence.todaySeconds(of: $0, todayKey: SocialClock.dayKey(now)) }
        return SocialPersonRow(name: name, state: state, seconds: seconds) {
            Button { reporting = ReportTarget(id: row.id, nickname: name) } label: {
                Label("신고하기", systemImage: "exclamationmark.bubble")
            }
            Button(role: .destructive) {
                center.engine.block(profileID: row.id, nickname: name)
                rows.removeAll { $0.id == row.id }
            } label: {
                Label("차단하기", systemImage: "nosign")
            }
            Button(role: .destructive) { removing = row.ref } label: {
                Label("친구 삭제", systemImage: "person.badge.minus")
            }
        }
    }

    private func load() async {
        guard center.isEnabled, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            rows = try await center.engine.refreshFriends()
            errorText = nil
        } catch {
            errorText = SocialText.message(for: error)
        }
        loaded = true
    }
}

// MARK: - 친구 추가

private struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var center = SocialCenter.shared
    @State private var text = ""
    @State private var busy = false
    @State private var errorText: String?
    @FocusState private var focused: Bool
    let onAdded: () async -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("친구가 알려 준 코드를 입력해 주세요")
                    .font(.pt(.subheadline))
                    .foregroundStyle(.secondary)
                TextField("ABCD-EFGH", text: $text)
                    .font(.pt(size: 24, weight: .semibold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .glassField()
                    .submitLabel(.done)
                    .onSubmit { add() }
                if let errorText {
                    Text(errorText).font(.pt(.footnote)).foregroundStyle(Palette.danger)
                }
                Spacer(minLength: 0)
                Button {
                    add()
                } label: {
                    if busy { ProgressView().tint(Theme.onAccent) } else { Text("추가") }
                }
                .buttonStyle(.primaryFill)
                .disabled(busy || SocialCode.extractFriendCode(from: text) == nil)
                .opacity(SocialCode.extractFriendCode(from: text) == nil ? 0.5 : 1)
            }
            .padding(16)
            .background { AppBackground() }
            .navigationTitle("친구 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } } }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }

    private func add() {
        guard !busy, SocialCode.extractFriendCode(from: text) != nil else { return }
        busy = true
        errorText = nil
        Task {
            do {
                try await center.addFriend(code: text)
                Haptics.tap()
                await onAdded()
                dismiss()
            } catch {
                errorText = SocialText.message(for: error)
            }
            busy = false
        }
    }
}

// MARK: - 신고

struct ReportTarget: Identifiable {
    let id: String
    let nickname: String
}

extension ReportReason {
    var title: String {
        switch self {
        case .inappropriateName: return L("부적절한 이름")
        case .harassment: return L("괴롭힘 · 욕설")
        case .spam: return L("스팸 · 광고")
        case .other: return L("기타")
        }
    }
}

struct ReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let target: ReportTarget
    let onSubmit: (ReportReason) async -> Void
    @State private var busy = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("'\(target.nickname)'님을 신고할까요?")
                    .font(.pt(.headline))
                    .foregroundStyle(Palette.ink)
                Text("신고하면 이 사람은 바로 숨겨져요. 신고 내용은 운영자가 확인해요.")
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(ReportReason.allCases.enumerated()), id: \.element) { index, reason in
                        if index > 0 { SocialDivider(leading: 16) }
                        Button {
                            busy = true
                            Task { await onSubmit(reason); busy = false; dismiss() }
                        } label: {
                            HStack {
                                Text(reason.title).font(.pt(.body)).foregroundStyle(Palette.ink)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressableRow)
                        .disabled(busy)
                    }
                }
                .softCardBackground()
                Spacer(minLength: 0)
            }
            .padding(16)
            .background { AppBackground() }
            .navigationTitle("신고")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
