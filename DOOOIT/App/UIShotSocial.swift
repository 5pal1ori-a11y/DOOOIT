#if DEBUG
import Foundation

/// 화면 사진용 친구 · 그룹 예시: 가짜 클라우드(InMemorySocialBackend)에 사람들을 넣어 둠 (CloudKit · 저장 없음)
@MainActor
enum UIShotSocial {
    static let groupID = "demo-group-1"
    private static var installed = false

    static func installIfNeeded() {
        guard !installed, UIShot.matches(.friends, .friendsAdd, .socialIntro, .groups, .groupDetail) else { return }
        installed = true
        let now = Date()
        let cloud = FakeCloud()
        let day = SocialClock.dayKey(now), week = SocialClock.weekKey(now)

        func person(_ id: String, _ name: String, code: String, today: Int, week weekSeconds: Int, studyingMinutes: Int? = nil, hidden: Bool = false) -> SocialProfile {
            SocialProfile(id: id, nickname: name, friendCode: code, todaySeconds: hidden ? 0 : today, todayKey: day,
                          weekSeconds: hidden ? 0 : weekSeconds, weekKey: week,
                          studyingSince: studyingMinutes.map { now.addingTimeInterval(-Double($0) * 60) },
                          updatedAt: now.addingTimeInterval(-15), isHidden: hidden)
        }
        let people = [
            person("me", "김모티", code: "K7QM3XPR", today: 95 * 60, week: 14 * 3600),
            person("f1", "서연", code: "H4TW9CNB", today: 2 * 3600 + 40 * 60, week: 19 * 3600, studyingMinutes: 42),
            person("f2", "민준", code: "R2ZD8KFE", today: 3600 + 12 * 60, week: 11 * 3600),
            person("f3", "하은", code: "P6VJ5MAX", today: 48 * 60, week: 9 * 3600 + 30 * 60, studyingMinutes: 13),
            person("f4", "지호", code: "N3GU7YQS", today: 0, week: 0, hidden: true),
            person("f5", "수아", code: "C8EL4TWD", today: 25 * 60, week: 6 * 3600)
        ]
        for p in people { cloud.seed(profile: p, creator: p.id) }

        let group = StudyGroup(id: groupID, name: "수능 D-100", inviteCode: "QW7X3N", ownerProfileID: "me", createdAt: now.addingTimeInterval(-86_400 * 12))
        cloud.seed(group: group, creator: "me")
        for id in ["me", "f1", "f2", "f3", "f4"] {
            cloud.seed(member: GroupMember(groupID: groupID, profileID: id, joinedAt: now.addingTimeInterval(-86_400 * 10)), creator: id)
        }
        let second = StudyGroup(id: "demo-group-2", name: "도서관 7시", inviteCode: "M4TB8K", ownerProfileID: "f2", createdAt: now.addingTimeInterval(-86_400 * 30))
        cloud.seed(group: second, creator: "f2")
        for id in ["me", "f2", "f5"] {
            cloud.seed(member: GroupMember(groupID: second.id, profileID: id, joinedAt: now.addingTimeInterval(-86_400 * 20)), creator: id)
        }

        var state = SocialState()
        if !UIShot.matches(.socialIntro) {
            state.enabled = true
            state.profileID = "me"
            state.friendCode = "K7QM3XPR"
            state.nickname = "김모티"
            state.iCloudOwner = "me"
            state.friends = ["f1", "f2", "f3", "f4", "f5"].enumerated().map { i, id in
                FriendRef(id: id, nickname: people.first { $0.id == id }?.nickname ?? "", addedAt: now.addingTimeInterval(-Double(i) * 3600))
            }
            state.groups = [
                JoinedGroup(id: groupID, name: group.name, isOwner: true, joinedAt: now.addingTimeInterval(-86_400 * 10)),
                JoinedGroup(id: second.id, name: second.name, isOwner: false, joinedAt: now.addingTimeInterval(-86_400 * 20))
            ]
        }
        SocialCenter.shared.installDemo(backend: InMemorySocialBackend(cloud: cloud, user: "me"), state: state)
    }
}
#endif
