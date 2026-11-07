import Foundation

/// 닉네임 · 그룹 이름 검사: 길이와 뻔한 욕설만 걸러요 (완벽하진 않아서 신고 · 차단이 따로 있어요)
enum NicknameFilter {
    enum Result: Equatable {
        case ok(String)
        case empty
        case tooLong
        case profanity
    }

    /// 아주 뻔한 욕설과 성적인 말 (띄어쓰기 · 기호를 넣어 피하는 것도 막으려고 정리한 글자에서 찾음)
    static let blocked: [String] = [
        "시발", "씨발", "씨팔", "시팔", "ㅅㅂ", "ㅆㅂ", "병신", "븅신", "ㅂㅅ", "지랄", "ㅈㄹ", "좆", "존나",
        "개새끼", "개세끼", "개자식", "씹새", "씹할", "씹창", "미친놈", "미친년", "썅", "창녀", "창년", "걸레년",
        "섹스", "섹시녀", "야동", "느금", "니애미", "애미뒤", "엿먹", "한남충", "김치녀", "일베", "운지",
        "fuck", "shit", "bitch", "cunt", "pussy", "porn", "nigg", "faggot", "whore", "slut", "asshole", "bastard"
    ]

    /// 비교용으로 정리: 소문자 · 공백/기호 제거 · 자주 쓰는 숫자/기호 바꿔치기 되돌림
    static func canonical(_ text: String) -> String {
        var out = ""
        for ch in text.lowercased() {
            switch ch {
            case "0": out.append("o")
            case "1", "!": out.append("i")
            case "3": out.append("e")
            case "4", "@": out.append("a")
            case "5", "$": out.append("s")
            default:
                if ch.isLetter || ch.isNumber { out.append(ch) }
                // 한글 자모(ㅅㅂ 같은)는 isLetter가 참이라 그대로 남음
            }
        }
        return out
    }

    static func containsProfanity(_ text: String) -> Bool {
        let c = canonical(text)
        guard !c.isEmpty else { return false }
        return blocked.contains { c.contains($0) }
    }

    /// 앞뒤 공백 · 줄바꿈을 정리하고 연속 공백은 하나로
    static func clean(_ raw: String) -> String {
        let parts = raw.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    static func validateNickname(_ raw: String) -> Result {
        validate(raw, max: SocialLimits.nicknameMax)
    }

    static func validateGroupName(_ raw: String) -> Result {
        validate(raw, max: SocialLimits.groupNameMax)
    }

    private static func validate(_ raw: String, max: Int) -> Result {
        let text = clean(raw)
        if text.isEmpty { return .empty }
        if text.count > max { return .tooLong }
        if text.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) { return .empty }
        if containsProfanity(text) { return .profanity }
        return .ok(text)
    }

    /// 남이 올린 닉네임을 보일 때: 욕설이면 가림 (nil이면 화면에서 대신 쓸 글자를 씀)
    static func displayName(_ raw: String) -> String? {
        let text = clean(raw)
        if text.isEmpty || containsProfanity(text) { return nil }
        return String(text.prefix(SocialLimits.nicknameMax))
    }
}
