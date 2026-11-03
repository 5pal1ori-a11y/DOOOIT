import Foundation

/// 모티 AI 대화 답 말투 다듬기 (모델이 쓴 답)
/// - 프롬프트 글이 새어 나온 것, 다른 글자(한자·일본어, 일상 대화의 영어 문장), "~습니다", "저는 AI라서",
///   뜬금없는 인사·바로 전과 같은 첫마디를 빼거나 고치고, 일상 대화는 짧게 줄여요.
/// - 정답·풀이 형식을 읽는 곳(AI 풀이, 채점)은 answer만 쓰고, 말투 다듬기는 대화 화면에서만 써요.
extension DoitMind {
    /// 프롬프트에서 새어 나온 글 빼기: "[질문]" 같은 칸 이름, 시킨 말, 혼자 이어 쓴 다음 대화("학생: …")
    static func stripLeaks(_ text: String) -> String {
        let labels = #"^\s*\[(질문|참고 자료|학생의 오늘 상황|이전 대화|앞선 대화|지금 이야기 중인 주제)\]"#
        let orders = ["짧고 간단하게 답해 주세요", "자기 말로 짧고 간단하게", "요약이나 결론은 붙이지 마세요", "친구처럼 1~2문장으로", "가벼운 일상 대화예요", "2~4문장으로 다정하게"]
        var kept: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 모델이 학생 말까지 지어 쓰기 시작하면 거기서 끊음
            if trimmed.range(of: #"^(학생|사용자|User|user)\s*[:：]"#, options: .regularExpression) != nil,
               kept.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { break }
            if trimmed.range(of: labels, options: .regularExpression) != nil { continue }
            if orders.contains(where: { trimmed.contains($0) }) { continue }
            kept.append(line)
        }
        let result = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? text : result
    }

    /// 대화 화면의 모델 답: answer + 다른 글자 빼기, 해요체로 맞추기, "저는 AI라서" 빼기,
    /// 뜬금없는 인사·바로 전 답과 같은 첫마디 빼기, 일상 대화는 짧게
    /// - final: 다 쓴 답 (일상 대화에서 덜 끝난 마지막 문장을 뺌). 쓰는 중에는 false
    static func chatAnswer(_ raw: String, question: String, previous: String? = nil, style: Style = .study, final: Bool = true) -> String {
        let base = answer(raw)
        var t = dropEcho(base, question: question)
        t = dropForeign(t, question: question, strict: style == .casual)
        t = politeEnding(t)
        t = dropDisclaimer(t)
        t = dropRepeatedOpener(t, question: question, previous: previous)
        if style == .casual { t = shortenCasual(t, final: final) }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.count >= 2 ? t : base
    }

    /// 쓸 만한 대화 답인지: isUsable + 한국어로 물었는데 거의 다른 말(영어 등)로 답했거나, 생각 태그·프롬프트 칸 이름이 남았으면 버림
    static func isUsable(_ text: String, question: String) -> Bool {
        guard isUsable(text) else { return false }
        if text.contains("<think") || text.contains("</think") || text.contains("[질문]") || text.contains("[참고 자료]") { return false }
        let q = question.lowercased()
        let wantsEnglish = ["영어로", "영작", "영어 문장", "영어문장", "english", "번역", "예문"].contains { q.contains($0) }
        guard hasHangul(question), !wantsEnglish else { return true }
        let letters = text.unicodeScalars.filter { $0.properties.isAlphabetic }
        let hangul = letters.filter { (0xAC00...0xD7A3).contains($0.value) || (0x3131...0x318E).contains($0.value) }.count
        if letters.count >= 12, Double(hangul) / Double(letters.count) < 0.2 { return false }
        return true
    }

    // MARK: - 도구

    /// 문장 나누기 (끝 기호는 문장에 붙여 둠: 다시 이으면 원래 글)
    static func sentences(_ line: String) -> [String] {
        var out: [String] = []
        var current = ""
        for ch in line {
            current.append(ch)
            if ".!?。！？".contains(ch) { out.append(current); current = "" }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    private static func hasHangul(_ s: String) -> Bool { s.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) } }
    private static func isHan(_ v: UInt32) -> Bool { (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) }
    private static func isKana(_ v: UInt32) -> Bool { (0x3040...0x30FF).contains(v) }

    /// 다른 글자로 샌 문장 빼기: 한자·일본어가 섞인 문장 (질문에 없을 때), 일상 대화에서 한국어 질문에 영어로만 쓴 문장
    /// (빼고 나서 너무 많이 줄면 그대로 두고 isUsable이 판단)
    static func dropForeign(_ text: String, question: String, strict: Bool) -> String {
        let questionScalars = question.unicodeScalars
        let allowHan = questionScalars.contains { isHan($0.value) || isKana($0.value) }
        let koreanQuestion = hasHangul(question) && !questionScalars.contains { $0.isASCII && $0.properties.isAlphabetic }
        var lines: [String] = []
        var dropped = 0
        for line in text.components(separatedBy: "\n") {
            var kept = ""
            for sentence in sentences(line) {
                let scalars = sentence.unicodeScalars
                let foreign = !allowHan && scalars.contains { isHan($0.value) || isKana($0.value) }
                let latin = scalars.filter { $0.isASCII && $0.properties.isAlphabetic }.count
                let english = strict && koreanQuestion && !hasHangul(sentence) && latin >= 8 && sentence.split(separator: " ").count >= 3
                if foreign || english { dropped += sentence.count; continue }
                kept += sentence
            }
            if !kept.trimmingCharacters(in: .whitespaces).isEmpty || line.trimmingCharacters(in: .whitespaces).isEmpty { lines.append(kept) }
        }
        guard dropped > 0 else { return text }
        let result = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.filter({ $0.isLetter }).count >= 4 ? result : text
    }

    /// 첫 줄에 질문을 그대로 되풀이했으면 빼기
    static func dropEcho(_ text: String, question: String) -> String {
        let key: (String) -> String = { $0.filter { $0.isLetter || $0.isNumber }.lowercased() }
        var lines = text.components(separatedBy: "\n")
        guard lines.count >= 2, let first = lines.first, !key(question).isEmpty, key(first) == key(question) else { return text }
        lines.removeFirst()
        let rest = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.isEmpty ? text : rest
    }

    /// "~습니다/~입니다"를 해요체로 (문장 끝에서만: 따옴표 안 예문 "나는 학생입니다"는 그대로)
    static func politeEnding(_ text: String) -> String {
        guard text.contains("니다") || text.contains("니까") || text.contains("십시오") else { return text }
        let end = #"(?=[.!?~,)\s]|$)"#
        // 받침에 따라 "입니다" → "이에요" / "예요"
        var t = replaceEach(text, pattern: #"([가-힣])입니다"# + end) { prev in
            let batchim = prev.unicodeScalars.first.map { ($0.value - 0xAC00) % 28 != 0 } ?? true
            return prev + (batchim ? "이에요" : "예요")
        }
        let pairs: [(String, String)] = [
            ("아닙니다", "아니에요"), ("입니까", "인가요"), ("있습니까", "있나요"), ("없습니까", "없나요"), ("합니까", "하나요"), ("됩니까", "되나요"),
            ("했습니다", "했어요"), ("됐습니다", "됐어요"), ("였습니다", "였어요"), ("었습니다", "었어요"), ("았습니다", "았어요"), ("겠습니다", "겠어요"),
            ("있습니다", "있어요"), ("없습니다", "없어요"), ("같습니다", "같아요"), ("좋습니다", "좋아요"), ("많습니다", "많아요"), ("적습니다", "적어요"),
            ("높습니다", "높아요"), ("낮습니다", "낮아요"), ("작습니다", "작아요"), ("않습니다", "않아요"), ("싶습니다", "싶어요"),
            ("합니다", "해요"), ("됩니다", "돼요"), ("줍니다", "줘요"), ("드립니다", "드려요"), ("바랍니다", "바라요"), ("갑니다", "가요"),
            ("납니다", "나요"), ("냅니다", "내요"), ("봅니다", "봐요"), ("집니다", "져요"), ("킵니다", "켜요"), ("립니다", "려요"), ("십시오", "세요")
        ]
        for (from, to) in pairs {
            t = t.replacingOccurrences(of: from + end, with: to, options: .regularExpression)
        }
        return t
    }

    private static func replaceEach(_ text: String, pattern: String, _ make: (String) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            result += make(ns.substring(with: match.range(at: 1)))
            last = match.range.location + match.range.length
        }
        return result + ns.substring(from: last)
    }

    /// "저는 AI라서 직접 먹을 수는 없지만, …" → "…"
    static func dropDisclaimer(_ text: String) -> String {
        let pattern = #"(^|(?<=[.!?] )|(?<=\n))(저는 |제가 |저도 )?(AI|인공지능|언어 ?모델|챗봇)(이라서|라서|이기 때문에|이므로|라|로서|여서|이어서)[^.!?\n]{0,40}?(지만|는데)\s*,?\s*"#
        let result = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4 ? result : text
    }

    /// 인사하지 않았는데 "안녕하세요!"로 시작하거나, 바로 전 답과 같은 첫 문장으로 시작하면 그 문장 빼기
    static func dropRepeatedOpener(_ text: String, question: String, previous: String?) -> String {
        let lines = text.components(separatedBy: "\n")
        guard let first = lines.first, let opening = sentences(first).first else { return text }
        let rest = (String(first.dropFirst(opening.count)) + (lines.count > 1 ? "\n" + lines.dropFirst().joined(separator: "\n") : ""))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard rest.count >= 4 else { return text }
        let q = question.replacingOccurrences(of: " ", with: "").lowercased()
        let greeted = ["안녕", "하이", "ㅎㅇ", "반가", "hello", "hi", "좋은아침", "굿모닝"].contains { q.contains($0) }
        let core = opening.trimmingCharacters(in: .whitespaces)
        if !greeted, core.hasPrefix("안녕"), core.count <= 16 { return rest }
        if let previous, let prevOpening = sentences(previous.components(separatedBy: "\n").first ?? "").first {
            let a = core.filter { $0.isLetter }, b = prevOpening.filter { $0.isLetter }
            if a.count >= 2, a == b { return rest }
        }
        return text
    }

    /// 일상 대화는 짧게: 제목·목록 줄 빼고 세 문장(160자)까지, 굵게 표시 빼기, 덜 끝난 마지막 문장 빼기
    static func shortenCasual(_ text: String, final: Bool) -> String {
        var lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let isList: (String) -> Bool = { line in
            line.hasPrefix("•") || line.hasPrefix("·") || line.range(of: #"^(\d+[.)]|\*\*[^*]+\*\*$)"#, options: .regularExpression) != nil
        }
        if lines.contains(where: { !isList($0) }) { lines = lines.filter { !isList($0) } }
        var kept: [String] = []
        var count = 0
        outer: for line in lines {
            for sentence in sentences(line.replacingOccurrences(of: "**", with: "")) {
                let s = sentence.trimmingCharacters(in: .whitespaces)
                guard !s.isEmpty else { continue }
                if kept.count >= 3 || (kept.count >= 1 && count + s.count > 160) { break outer }
                kept.append(s)
                count += s.count
            }
        }
        // 다 쓴 답의 마지막 문장이 끝맺지 못했으면 뺌 (토큰이 다 돼서 잘린 문장)
        if final, kept.count >= 2, let last = kept.last, !endsNaturally(last) { kept.removeLast() }
        return kept.joined(separator: " ")
    }

    /// 문장이 끝맺었는지 (끝 기호·이모지·웃음, 또는 "~요", "~죠" 같은 끝말)
    static func endsNaturally(_ sentence: String) -> Bool {
        guard let ch = sentence.trimmingCharacters(in: .whitespaces).last else { return true }
        if ".!?~)…ㅋㅎㅠㅜ^。！？".contains(ch) { return true }
        if ch.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) { return true }
        return ["요", "다", "죠", "까", "네", "지", "야", "어", "아", "게", "래", "자", "걸"].contains(String(ch))
    }
}
