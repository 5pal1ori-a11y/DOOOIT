import Foundation

/// 아이디어 요청 ("발표 잘하는 아이디어 줘", "동아리 홍보 브레인스토밍"):
/// 사실을 말하는 게 아니라 생각을 여는 일이라 틀릴 일이 없는 '관점별 질문'으로 답해요.
/// (조합 · 다른 분야 빌리기 · 제약을 기회로 · 반대로 생각 · 작게 쪼개기 · 다른 사람 눈)
/// 모델을 쓸 수 있으면 이 관점들을 참고해 모델이 구체적인 아이디어를 6~8개 내요.
enum DoitIdeas {
    struct Result {
        let text: String
        let suggestions: [String]
        let topic: String
    }

    /// 아이디어 요청이고 주제가 있으면 답 (주제가 없으면 nil → 기존 추천 답)
    static func answer(_ raw: String) -> Result? {
        guard DoitMind.wantsIdeas(raw), let topic = topic(from: raw) else { return nil }
        let name = "‘\(topic)’"
        let lines = [
            "• 조합: \(name)에 좋아하는 것(게임·음악·운동 같은)을 하나 섞으면 어떤 모습일까요?",
            "• 다른 분야 빌리기: 요리·스포츠·게임에서 쓰는 방식을 \(name)에 그대로 가져오면?",
            "• 제약을 기회로: 시간이 10분뿐이라면, 돈이 0원이라면 \(name)을(를) 어떻게 할까요?",
            "• 반대로 생각: \(name)을(를) 일부러 가장 나쁘게 하는 법을 떠올린 뒤 그 반대로 해 봐요.",
            "• 작게 쪼개기: \(name)을(를) 5분짜리 세 조각으로 나누면 첫 조각은 뭘까요?",
            "• 다른 사람 눈으로: 친구나 선생님이라면 \(name)에서 무엇을 가장 먼저 바꿀까요?"
        ]
        let text = "\(name) 생각을 여섯 방향으로 열어 봤어요. 정답이 아니라 떠올리기 위한 질문이에요.\n" + lines.joined(separator: "\n")
            + "\n\n끌리는 방향을 골라 주면 같이 구체적으로 만들어 볼게요."
        return Result(text: text, suggestions: ["\(topic) 아이디어 더 줘"], topic: topic)
    }

    /// 요청에서 주제만 뽑기 ("발표 잘하는 아이디어 좀 줘" → "발표 잘하는"). 너무 짧으면 nil
    static func topic(from raw: String) -> String? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 긴 말은 어디에 붙어 있어도 빼고, 짧은 군말은 낱말 하나일 때만 뺌 ("더위", "좀비"가 깨지지 않게)
        for word in ["아이디어를", "아이디어", "브레인스토밍을", "브레인스토밍", "브레인 스토밍", "알려줘", "알려 줘", "알려주세요", "내줘", "내 줘", "내봐", "줘봐", "해줘", "해 줘", "주세요", "추천해줘", "추천해 줘", "여러 가지", "여러가지", "여러 개", "여러개"] {
            t = t.replacingOccurrences(of: word, with: " ")
        }
        t = t.replacingOccurrences(of: #"[?!.~…,]"#, with: " ", options: .regularExpression)
        let filler: Set<String> = ["줄래", "추천", "같이", "다양한", "다양하게", "새로운", "좋은", "좀", "더", "많이", "없을까", "있을까", "있어", "줘", "발상", "좀만", "하나"]
        t = t.split(whereSeparator: \.isWhitespace).map(String.init).filter { !filler.contains($0) }.joined(separator: " ")
        // 끝에 남은 조사·어미 ("동아리 홍보에 대한", "발표를") 다듬기
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        for tail in ["에 대한", "에 대해서", "에 대해", "관련해서", "관련된", "관련", "에 관한", "을 위한", "를 위한", "에 쓸", "을", "를", "에", "은", "는", "이", "가", "의", "도", "만", "좀"] where t.hasSuffix(" " + tail) {
            t = String(t.dropLast(tail.count + 1)).trimmingCharacters(in: .whitespaces)
        }
        for tail in ["에 대한", "에 대해", "에 관한", "을 위한", "를 위한"] where t.hasSuffix(tail) && t.count > tail.count + 1 {
            t = String(t.dropLast(tail.count)).trimmingCharacters(in: .whitespaces)
        }
        guard t.count >= 2, t.count <= 40, t.unicodeScalars.contains(where: { $0.properties.isAlphabetic || $0.properties.numericType != nil }) else { return nil }
        return t
    }
}
