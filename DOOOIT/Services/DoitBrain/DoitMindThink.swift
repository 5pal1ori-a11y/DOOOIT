import Foundation

/// 모티 AI 생각 틀: 작은 모델이 질문에 맞는 관점을 한두 개만 골라 짧게 생각한 뒤,
/// 핵심 → 이유 → 쉬운 예시 → 확인 질문 순서로 답하게 하는 짧은 지시글 (작은 모델은 긴 지시에 약해서 짧게)
/// + 아이디어 요청은 서로 다른 관점에서 여러 개를 내게 하는 지시글.
extension DoitMind {
    /// 질문을 바라보는 관점
    enum Angle: String, CaseIterable {
        /// 원인 → 결과
        case cause
        /// 큰 그림 ↔ 세부
        case bigPicture
        /// 비슷한 일상 예시에 빗대기
        case analogy
        /// 반대로 생각하기
        case opposite
        /// '왜?'를 이어 근본 이유까지
        case whyChain

        var phrase: String {
            switch self {
            case .cause: return "원인→결과"
            case .bigPicture: return "큰 그림→세부"
            case .analogy: return "일상 예시에 빗대기"
            case .opposite: return "반대로 생각하기"
            case .whyChain: return "'왜?'를 두세 번 이어 보기"
            }
        }
    }

    /// 질문에 어울리는 관점 1~2개
    static func angles(for question: String) -> [Angle] {
        let t = question.lowercased().replacingOccurrences(of: " ", with: "")
        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }
        if has(["차이", "비교", "다른점", "vs", "구분", "헷갈"]) { return [.bigPicture, .opposite] }
        if has(["왜", "이유", "원인", "때문", "why"]) { return [.whyChain, .cause] }
        if has(["원리", "어떻게", "방법", "과정", "how"]) { return [.cause, .analogy] }
        if has(["풀이", "풀어", "구해", "계산", "증명", "공식"]) { return [.cause, .opposite] }
        if has(["뭐야", "뭔가요", "무엇", "뜻", "의미", "개념", "설명", "이란", "란?", "what"]) { return [.analogy, .bigPicture] }
        return [.analogy, .cause]
    }

    /// 공부 질문에 붙이는 생각 틀 (짧게: 약 200자). 일상 대화에는 붙이지 않음
    static func reasoningScaffold(for question: String, style: Style) -> String? {
        guard style == .study else { return nil }
        let picked = angles(for: question).map(\.phrase).joined(separator: ", ")
        return "답하기 전에 속으로 \(picked) 관점으로 짧게 생각해요. 생각 과정은 쓰지 않고, 핵심 한 문장 → 왜 그런지 한두 문장 → 쉬운 예시 하나 → 마지막에 확인 질문이나 다음에 해 볼 일 한 줄 순서로 이어서 답해요. 제목·번호 없이 5문장 안으로, 모르는 부분은 지어내지 않아요."
    }

    // MARK: - 아이디어

    /// 아이디어·브레인스토밍을 해 달라는 말인지 (뜻을 묻는 말 "브레인스토밍이 뭐야?"는 아님)
    static func wantsIdeas(_ question: String) -> Bool {
        let t = question.lowercased().replacingOccurrences(of: " ", with: "")
        let key = ["아이디어", "브레인스토밍", "발상", "idea", "brainstorm"]
        guard key.contains(where: { t.contains($0) }) else { return false }
        let asksMeaning = ["뭐야", "뭔가요", "무엇", "뜻", "의미", "이란", "란?", "whatis", "meaning"].contains { t.contains($0) }
        let asksToMake = ["줘", "주세요", "내줘", "내봐", "추천", "알려", "없을까", "있을까", "해보자", "해볼까", "같이", "좀", "여러", "다양", "give", "need", "some"].contains { t.contains($0) }
        return !asksMeaning || asksToMake
    }

    /// 아이디어 요청에 붙이는 지시글: 서로 다른 관점 5~8개, 한 줄씩
    static let ideasInstruction = "아이디어를 달라는 요청이에요. 서로 겹치지 않게 6~8개를 내요. 조합(두 가지 섞기), 다른 분야에서 빌려오기, 제약을 기회로 바꾸기, 반대로 생각하기, 작게 쪼개기처럼 관점을 바꿔 가며 내요. 줄마다 • 로 시작해 이름 한 마디와 한 문장 설명만 쓰고, 긴 서론은 쓰지 않아요. 마지막에 가장 끌리는 것을 고르는 질문 한 줄을 붙여요."

    /// 말투와 질문에 따른 답 길이 (아이디어는 여러 개라 조금 길게)
    static func maxTokens(for style: Style, question: String) -> Int {
        if style != .casual, wantsIdeas(question) { return 700 }
        return maxTokens(for: style)
    }
}
