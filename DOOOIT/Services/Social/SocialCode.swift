import Foundation

/// 친구 코드(8자) · 그룹 초대 코드(6자): 헷갈리는 글자(0 O 1 I L)를 뺀 31글자만 씀
enum SocialCode {
    static let alphabet: [Character] = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    static let friendLength = 8
    static let inviteLength = 6

    /// random: 0..<n 사이 정수를 돌려주는 함수 (테스트에서는 정해 둔 값을 넣음)
    static func generate(length: Int, random: (Int) -> Int = { Int.random(in: 0..<$0) }) -> String {
        String((0..<length).map { _ in alphabet[min(max(0, random(alphabet.count)), alphabet.count - 1)] })
    }

    static func friendCode(random: (Int) -> Int = { Int.random(in: 0..<$0) }) -> String {
        generate(length: friendLength, random: random)
    }

    static func inviteCode(random: (Int) -> Int = { Int.random(in: 0..<$0) }) -> String {
        generate(length: inviteLength, random: random)
    }

    /// 사람이 적은 글을 코드 모양으로: 대문자, 공백 · 줄표 · 눈에 안 보이는 글자 제거
    static func normalize(_ input: String) -> String {
        var out = ""
        for ch in input.uppercased() where ch.isASCII && (ch.isLetter || ch.isNumber) { out.append(ch) }
        return out
    }

    static func isValid(_ code: String, length: Int) -> Bool {
        code.count == length && code.allSatisfy { alphabet.contains($0) }
    }

    static func isValidFriendCode(_ code: String) -> Bool { isValid(code, length: friendLength) }
    static func isValidInviteCode(_ code: String) -> Bool { isValid(code, length: inviteLength) }

    /// 화면용: ABCD-EFGH / ABC-234
    static func display(_ code: String) -> String {
        guard code.count >= 4 else { return code }
        let half = code.count / 2
        return String(code.prefix(half)) + "-" + String(code.dropFirst(half))
    }

    /// 입력(코드만, 또는 공유한 글 전체)에서 친구 코드를 찾음. 없으면 nil
    static func extractFriendCode(from text: String) -> String? { extract(from: text, length: friendLength) }
    static func extractInviteCode(from text: String) -> String? { extract(from: text, length: inviteLength) }

    private static func extract(from text: String, length: Int) -> String? {
        let direct = normalize(text)
        if isValid(direct, length: length) { return direct }
        // 공유한 글 안에서: 앞뒤가 영문·숫자가 아닌 곳에 있는 코드 (가운데 줄표는 있어도 됨)
        let chars = String(alphabet)
        let half = length / 2
        let pattern = "(?<![A-Za-z0-9])([\(chars)]{\(half)})-?([\(chars)]{\(length - half)})(?![A-Za-z0-9])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let upper = text.uppercased()
        let ns = upper as NSString
        guard let m = regex.firstMatch(in: upper, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges == 3 else { return nil }
        let code = ns.substring(with: m.range(at: 1)) + ns.substring(with: m.range(at: 2))
        return isValid(code, length: length) ? code : nil
    }
}
