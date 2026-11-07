import SwiftUI
import UIKit

/// 그룹 탭: 들어간 그룹 목록 · 만들기 · 코드로 들어가기
struct SocialGroupsTab: View {
    @State private var center = SocialCenter.shared
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if center.state.groups.isEmpty {
                    VStack(spacing: 4) {
                        EmptyStateView(symbol: "person.3", title: L("그룹이 없어요"))
                        Button("그룹 만들기") { showCreate = true }
                            .buttonStyle(.primaryFill)
                            .padding(.horizontal, 16)
                        Button { showJoin = true } label: {
                            Text("코드로 들어가기")
                                .font(.pt(.subheadline).weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.pressable)
                        .padding(.bottom, 8)
                    }
                    .softCardBackground()
                    .staggerIn(index: 0)
                } else {
                    HStack(spacing: 8) {
                        actionButton(L("그룹 만들기"), "plus") { showCreate = true }
                        actionButton(L("코드로 들어가기"), "number") { showJoin = true }
                    }
                    .staggerIn(index: 0)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("그룹")
                                .font(.pt(size: 20, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            Text("\(center.state.groups.count)")
                                .font(.pt(size: 17, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        ForEach(Array(center.state.groups.enumerated()), id: \.element.id) { index, group in
                            NavigationLink { SocialGroupDetailView(groupID: group.id) } label: {
                                groupCard(group)
                            }
                            .buttonStyle(.pressable)
                            .staggerIn(index: index + 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showCreate) { GroupNameSheet() }
        .sheet(isPresented: $showJoin) { GroupJoinSheet() }
    }

    /// 그룹 한 장: 이니셜 칸 · 이름 · 방장 표시
    private func groupCard(_ group: JoinedGroup) -> some View {
        HStack(spacing: 12) {
            Text(String(group.name.prefix(1)))
                .font(.pt(size: 18, weight: .semibold))
                .foregroundStyle(Theme.secondary)
                .frame(width: 44, height: 44)
                .background(Palette.cardInset, in: .rect(cornerRadius: Radius.field, style: .continuous))
            Text(group.name)
                .font(.pt(.body).weight(.semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            if group.isOwner { TagLabel(text: L("방장")) }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.pt(.footnote).weight(.semibold)).foregroundStyle(.tertiary)
        }
        .softCard(padding: 14)
    }

    private func actionButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Palette.card, in: .rect(cornerRadius: Radius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - 만들기 · 들어가기

private struct GroupNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var center = SocialCenter.shared
    @State private var name = ""
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("그룹 이름").font(.pt(.subheadline)).foregroundStyle(.secondary)
                TextField(L("예: 수능 D-100"), text: $name)
                    .font(.pt(.body))
                    .glassField()
                    .onChange(of: name) { _, new in
                        if new.count > SocialLimits.groupNameMax { name = String(new.prefix(SocialLimits.groupNameMax)) }
                    }
                if let errorText { Text(errorText).font(.pt(.footnote)).foregroundStyle(Palette.danger) }
                Spacer(minLength: 0)
                Button {
                    busy = true
                    errorText = nil
                    Task {
                        do { try await center.engine.createGroup(name: name); dismiss() } catch { errorText = SocialText.message(for: error) }
                        busy = false
                    }
                } label: {
                    if busy { ProgressView().tint(Theme.onAccent) } else { Text("만들기") }
                }
                .buttonStyle(.primaryFill)
                .disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(16)
            .background { AppBackground() }
            .navigationTitle("그룹 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

private struct GroupJoinSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var center = SocialCenter.shared
    @State private var text = ""
    @State private var busy = false
    @State private var errorText: String?

    private var valid: Bool { SocialCode.extractInviteCode(from: text) != nil }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("초대 코드").font(.pt(.subheadline)).foregroundStyle(.secondary)
                TextField("ABC-234", text: $text)
                    .font(.pt(size: 24, weight: .semibold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .glassField()
                if let errorText { Text(errorText).font(.pt(.footnote)).foregroundStyle(Palette.danger) }
                Spacer(minLength: 0)
                Button {
                    busy = true
                    errorText = nil
                    Task {
                        do { try await center.engine.joinGroup(code: text); dismiss() } catch { errorText = SocialText.message(for: error) }
                        busy = false
                    }
                } label: {
                    if busy { ProgressView().tint(Theme.onAccent) } else { Text("들어가기") }
                }
                .buttonStyle(.primaryFill)
                .disabled(busy || !valid)
                .opacity(valid ? 1 : 0.5)
            }
            .padding(16)
            .background { AppBackground() }
            .navigationTitle("코드로 들어가기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 그룹 화면

struct SocialGroupDetailView: View {
    enum Period: Hashable { case today, week }

    let groupID: String
    @Environment(\.dismiss) private var dismiss
    @State private var center = SocialCenter.shared
    @State private var detail: GroupDetail?
    @State private var period: Period = .today
    @State private var errorText: String?
    @State private var loading = false
    @State private var reporting: ReportTarget?
    @State private var confirmLeave = false
    @State private var removeTarget: GroupMemberRow?
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let detail {
                    PillSegmentedControl(items: [Period.today, Period.week], selection: $period) {
                        $0 == .today ? L("오늘") : L("이번 주")
                    }
                    summary(detail)
                        .staggerIn(index: 0)
                    if let errorText { Text(errorText).font(.pt(.footnote)).foregroundStyle(.secondary) }
                    memberList(detail)
                        .staggerIn(index: 1)
                    inviteCard(detail.group)
                        .staggerIn(index: 2)
                } else if let errorText {
                    Text(errorText).font(.pt(.subheadline)).foregroundStyle(.secondary).softCard()
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
            .animation(Motion.quick, value: period)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle(detail?.group.name ?? center.state.groups.first { $0.id == groupID }?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) { confirmLeave = true } label: {
                        if isOwner { Label("그룹 삭제", systemImage: "trash") } else { Label("그룹 나가기", systemImage: "rectangle.portrait.and.arrow.right") }
                    }
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("더보기")
            }
        }
        .refreshable { await load() }
        .task {
            await load()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { break }
                await load()
            }
        }
        .sheet(item: $reporting) { target in
            ReportSheet(target: target) { reason in
                await center.engine.report(profileID: target.id, nickname: target.nickname, reason: reason)
                await load()
            }
        }
        .confirmationDialog(isOwner ? L("그룹을 삭제할까요?") : L("그룹에서 나갈까요?"), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(isOwner ? L("삭제") : L("나가기"), role: .destructive) { leave() }
            Button("취소", role: .cancel) {}
        } message: {
            if isOwner { Text("모든 멤버의 그룹이 없어져요.") }
        }
        .confirmationDialog("그룹에서 내보낼까요?", isPresented: Binding(get: { removeTarget != nil }, set: { if !$0 { removeTarget = nil } }), titleVisibility: .visible) {
            Button("내보내기", role: .destructive) {
                if let row = removeTarget { removeMember(row) }
                removeTarget = nil
            }
            Button("취소", role: .cancel) { removeTarget = nil }
        }
    }

    private var isOwner: Bool { detail?.iAmOwner ?? center.state.groups.first { $0.id == groupID }?.isOwner ?? false }

    // MARK: 위쪽

    private func summary(_ detail: GroupDetail) -> some View {
        let now = Date()
        let profiles = detail.members.map(\.profile)
        let total = period == .today ? GroupMath.totalToday(profiles, now: now) : GroupMath.totalWeek(profiles, now: now)
        let studying = GroupMath.studyingCount(profiles, now: now)
        return VStack(alignment: .leading, spacing: 8) {
            Text(period == .today ? L("오늘 합계") : L("이번 주 합계"))
                .font(.pt(.footnote)).foregroundStyle(.secondary)
            SocialTimeText(seconds: total, big: 40, small: 17)
            Rectangle().fill(Palette.line).frame(height: 0.5).padding(.vertical, 4)
            HStack(spacing: 6) {
                if studying > 0 { SocialLiveDot(size: 8) }
                Text("\(studying)명 공부 중")
                    .foregroundStyle(studying > 0 ? Palette.success : Color.secondary)
                Spacer()
                Text("\(detail.members.count)/\(detail.group.maxMembers)명")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.pt(.footnote))
        }
        .softCard()
    }

    private func inviteCard(_ group: StudyGroup) -> some View {
        let shareText = L("MOTI 그룹 '\(group.name)'에 같이 들어와요! 초대 코드: \(SocialCode.display(group.inviteCode))")
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("초대 코드").font(.pt(.footnote)).foregroundStyle(.secondary)
                Text(SocialCode.display(group.inviteCode))
                    .font(.pt(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.ink)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = shareText
                copied = true
                Haptics.tap()
                Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 40, height: 40)
                    .background(Palette.cardInset, in: .rect(cornerRadius: Radius.field, style: .continuous))
                    .popOnce(when: copied)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("복사")
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 40, height: 40)
                    .background(Palette.cardInset, in: .rect(cornerRadius: Radius.field, style: .continuous))
            }
            .buttonStyle(.pressable)
        }
        .foregroundStyle(Palette.ink)
        .softCard()
    }

    // MARK: 멤버

    private func memberList(_ detail: GroupDetail) -> some View {
        let now = Date()
        let byID = Dictionary(uniqueKeysWithValues: detail.members.map { ($0.id, $0) })
        var entries: [MemberEntry] = []
        if period == .today {
            let today = SocialClock.dayKey(now)
            let sorted = GroupMath.sortedByToday(detail.members.map(\.profile), now: now)
            for p in sorted {
                guard let row = byID[p.id] else { continue }
                let seconds = SocialPresence.todaySeconds(of: p, todayKey: today)
                // 시간을 알 수 있는 사람만 순위 (비공개는 순위 없이 아래에)
                var rank: Int?
                if let seconds {
                    // 같은 시간이면 같은 순위 (주간 순위와 같은 규칙)
                    if let last = entries.last, let lastRank = last.rank, last.seconds == seconds { rank = lastRank } else { rank = entries.count + 1 }
                }
                entries.append(MemberEntry(row: row, seconds: seconds, rank: rank))
            }
        } else {
            let ranking = GroupMath.weeklyRanking(detail.members.map(\.profile), now: now)
            for e in ranking {
                if let row = byID[e.profile.id] { entries.append(MemberEntry(row: row, seconds: e.seconds, rank: e.rank)) }
            }
            // 숨긴 사람은 순위 없이 아래에
            let ranked = Set(ranking.map(\.id))
            for m in detail.members where !ranked.contains(m.id) { entries.append(MemberEntry(row: m, seconds: nil, rank: nil)) }
        }
        return VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 { SocialDivider(leading: entry.rank == nil ? 68 : 102) }
                memberRow(entry.row, seconds: entry.seconds, rank: entry.rank, now: now, detail: detail)
            }
        }
        .softCardBackground()
    }

    private struct MemberEntry: Identifiable {
        let row: GroupMemberRow
        let seconds: Int?
        let rank: Int?
        var id: String { row.id }
    }

    private func memberRow(_ row: GroupMemberRow, seconds: Int?, rank: Int?, now: Date, detail: GroupDetail) -> some View {
        let name = row.profile.nickname
        return SocialPersonRow(name: name, state: SocialPresence.state(of: row.profile, now: now), seconds: seconds,
                               highlight: row.isMe, tag: row.isOwner ? L("방장") : nil, rank: rank, showMenu: !row.isMe) {
            Button { reporting = ReportTarget(id: row.id, nickname: name) } label: {
                Label("신고하기", systemImage: "exclamationmark.bubble")
            }
            Button(role: .destructive) {
                center.engine.block(profileID: row.id, nickname: name)
                Task { await load() }
            } label: {
                Label("차단하기", systemImage: "nosign")
            }
            if detail.iAmOwner {
                Button(role: .destructive) { removeTarget = row } label: {
                    Label("그룹에서 내보내기", systemImage: "person.badge.minus")
                }
            }
        }
    }

    // MARK: 동작

    private func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            detail = try await center.engine.loadGroup(groupID)
            errorText = nil
        } catch let e as SocialError where e == .groupGone || e == .removedFromGroup {
            dismiss()
        } catch {
            errorText = SocialText.message(for: error)
        }
    }

    private func leave() {
        Task {
            do {
                try await center.engine.leaveGroup(groupID)
                dismiss()
            } catch {
                errorText = SocialText.message(for: error)
            }
        }
    }

    private func removeMember(_ row: GroupMemberRow) {
        Task {
            do {
                try await center.engine.removeMember(groupID: groupID, profileID: row.id)
                detail?.members.removeAll { $0.id == row.id }
            } catch {
                errorText = SocialText.message(for: error)
            }
        }
    }
}
