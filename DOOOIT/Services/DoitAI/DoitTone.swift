import Foundation

/// 모티 AI 말투 도우미 (모델 없이 규칙형 엔진이 답할 때)
/// - 여러 말 중에서 돌려 가며 골라 같은 말을 연달아 하지 않음 (바로 전 답과 같은 첫마디도 피함)
/// - 이름은 가끔만 불러 줌 (매번 부르면 어색해요)
/// - 바로 전 답이 무엇이었는지 기억해서 "ㅋㅋ"·"고마워"·"응"에 앞 이야기를 이어 답함
/// - 제안한 일("퀴즈 한 판 할까요?")을 기억해 두었다가 "응"이라고 하면 그대로 해 줌
enum DoitTone {
    /// 엔진이 한 답과 그 답의 종류 (최근 몇 개)
    private struct Said {
        let text: String
        let kind: String?
    }

    private static var said: [Said] = []
    /// 목록마다 최근에 고른 번호 (목록 첫 말을 열쇠로)
    private static var used: [String: [Int]] = [:]
    /// 제안한 일과 그 제안을 담은 답
    private static var offer: (request: String, reply: String)?
    /// 이름을 부른 뒤 지난 답 수
    private static var sinceNamed = 99
    /// 화면에 보인 바로 전 모티 답 (DoitAssistant가 말을 받을 때마다 알려 줌)
    static var lastShown: String?

    // MARK: - 고르기

    /// 여러 말 중 하나: 최근에 고른 말과 바로 전 답과 같은 첫마디는 피함
    static func pick(_ options: [String]) -> String {
        guard options.count > 1 else { return options.first ?? "" }
        let key = options[0]
        let recent = used[key] ?? []
        var pool = options.indices.filter { !recent.contains($0) }
        if pool.isEmpty { pool = options.indices.filter { $0 != recent.last } }
        let previous = said.last.map { opener($0.text) }
        let fresh = pool.filter { opener(options[$0]) != previous }
        let choice = (fresh.isEmpty ? pool : fresh).randomElement() ?? 0
        var next = recent + [choice]
        // 절반쯤 고르고 나면 다시 처음부터 (모두 다 쓰기 전에는 되풀이하지 않음)
        let keep = max(1, (options.count + 1) / 2)
        if next.count > keep { next.removeFirst(next.count - keep) }
        used[key] = next
        return options[choice]
    }

    /// 첫마디 (앞 기호·이모지 빼고 첫 낱말, 4글자까지)
    static func opener(_ text: String) -> String {
        let letters = text.drop { !($0.isLetter || $0.isNumber) }
        let word = letters.prefix { $0.isLetter || $0.isNumber }
        return String(word.prefix(4))
    }

    // MARK: - 이름

    /// 이름을 알면 가끔(세 번에 한 번쯤, 연달아 부르지 않게) "민지님, "을 앞에 붙임
    static func address(_ text: String) -> String {
        guard let name = DoitConversation.userName, !text.contains(name), sinceNamed >= 3, Bool.random() else { return text }
        sinceNamed = 0
        return "\(name)님, " + text
    }

    /// 이름 (부를 수 있을 때만: 바로 전에 불렀으면 nil)
    static func nameToCall() -> String? {
        guard let name = DoitConversation.userName, sinceNamed >= 3 else { return nil }
        sinceNamed = 0
        return name
    }

    // MARK: - 앞 대화

    /// 엔진이 한 답 기록 (kind: "joke", "greeting", "thanks" 같은 답의 종류)
    static func remember(_ text: String, kind: String? = nil, offer request: String? = nil) {
        said.append(Said(text: text, kind: kind))
        if said.count > 6 { said.removeFirst(said.count - 6) }
        sinceNamed += 1
        offer = request.map { ($0, text) }
    }

    /// 바로 전 답의 종류: 엔진의 대화 답이면 그 종류, 다른 긴 답(설명·풀이)이면 "study", 모르면 nil
    static var previousKind: String? {
        guard let shown = lastShown?.trimmingCharacters(in: .whitespacesAndNewlines), !shown.isEmpty else { return nil }
        if let last = said.last, last.text == shown { return last.kind }
        return shown.count >= 60 || shown.contains("**") ? "study" : nil
    }

    /// 같은 답을 바로 전에도 했는지
    static func repeatsLast(_ text: String) -> Bool { said.last?.text == text }

    /// "응", "좋아", "ㄱㄱ"처럼 받아들이는 짧은 말
    static func isYes(_ raw: String) -> Bool {
        let t = DoitChat.squash(raw).trimmingCharacters(in: CharacterSet(charactersIn: "ㅎㅋ!~^"))
        let yes: Set<String> = ["응", "응응", "웅", "엉", "어", "ㅇㅇ", "ㅇㅋ", "ㅇㅋㅇㅋ", "그래", "그래그래", "그래요", "좋아", "좋아요", "좋지", "좋아좋아", "콜", "오케이", "ok", "okay",
                                "넵", "네", "네네", "예", "ㄱㄱ", "고고", "가자", "해줘", "해줘요", "해볼래", "할래", "당연하지", "응해줘", "응좋아", "좋아해줘", "그래해줘", "ㅇㅇ해줘"]
        return yes.contains(t)
    }

    /// 바로 전 답에서 제안한 일을 "응"으로 받아들였으면 그 부탁 (한 번만)
    static func acceptedOffer(_ raw: String) -> String? {
        guard let offer, isYes(raw), let shown = lastShown, shown == offer.reply else { return nil }
        self.offer = nil
        return offer.request
    }

    /// 테스트용: 기억 비우기
    static func reset() {
        said = []
        used = [:]
        offer = nil
        sinceNamed = 99
        lastShown = nil
    }
}
