import Foundation

/// 사진에서 읽은 글자 한 줄
struct OCRLine {
    let text: String
    /// 인식 신뢰도 0~1 (손글씨는 보통 낮게 나옴)
    var confidence: Float = 1
    /// Vision 정규화 좌표 (0~1, 원점 왼쪽 아래)
    let box: CGRect
}

/// 읽은 글자 줄 정리 (Vision 없이 글자·위치만 다룸 → 리눅스 테스트에서도 그대로 컴파일)
extension OCRService {
    static func isHangul(_ c: Character) -> Bool {
        c.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) || (0x3131...0x318E).contains($0.value) }
    }

    /// 수식다운 정도: 변수 글자·연산 기호는 +, 숫자 자리의 이상한 글자·낯선 기호는 −
    static func mathScore(_ text: String) -> Int {
        var score = 0
        for c in text {
            if "xyabcknmt".contains(c) { score += 2 }
            else if "+-=×÷^()√<>≤≥/²³".contains(c) { score += 1 }
            else if c.isUppercase && c.isASCII { score -= 1 }
            else if !c.isASCII && !"−·αβγθπ".contains(c) { score -= 2 }
        }
        return score - 3 * mathPenalty(text)
    }

    /// 수식처럼 보이는 줄에서 숫자 자리에 비슷한 글자가 끼어든 정도 (작을수록 좋음)
    static func mathPenalty(_ text: String) -> Int {
        let patterns = [#"[0-9][ZOlISB]"#, #"[ZOlISB][0-9]"#, #"[+\-=×÷(^][ZOlS](?![a-z])"#, #"[|]"#]
        return patterns.reduce(0) { total, pattern in
            total + ((try? NSRegularExpression(pattern: pattern))?.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) ?? 0)
        }
    }

    /// 검은 글자만 읽은 결과가 원래보다 확실히 적으면 (얇은 글씨가 지워진 경우) 원래 결과 사용
    static func chooseInkReading(original: [OCRLine], ink inkLines: [OCRLine]) -> [OCRLine] {
        guard !inkLines.isEmpty else { return original }
        let inkCount = printedText(from: inkLines).count
        let originalCount = printedText(from: original).count
        return inkCount >= originalCount * 7 / 10 ? inkLines : original
    }

    /// 기본 결과와 다른 방법으로 읽은 결과들 중 수식이 가장 자연스러운 쪽
    static func bestReading(base: String, others: [String]) -> (text: String, improved: Bool) {
        let readings = others.map { reading -> String in
            MathOCRFixer.fix(reading.replacingOccurrences(of: "[영어 전용 읽기 · 수식 참고용]\n", with: ""))
        }
        var best = (text: base, score: readingScore(base))
        for reading in readings where reading.count >= base.count * 3 / 4 && reading.count <= base.count * 3 / 2 + 10 {
            let score = readingScore(reading)
            if score > best.score + 3 { best = (reading, score) }
        }
        return (best.text, best.text != base)
    }

    static func unsureLines(_ lines: [OCRLine]) -> [String] {
        lines.filter { $0.confidence < 0.5 && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { MathOCRFixer.fix($0.text) }
    }

    /// 읽은 글이 얼마나 그럴듯한지: 한글 문장은 그대로 두고, 수식 부분은 수식다운 정도로
    static func readingScore(_ text: String) -> Int {
        var score = 0
        for line in text.components(separatedBy: "\n") {
            let hangul = line.filter(isHangul).count
            let formula = String(line.filter { !isHangul($0) })
            score += hangul / 2 + mathScore(formula)
        }
        // 보기 번호를 읽은 쪽을 더 믿음
        score += text.filter { "①②③④⑤".contains($0) }.count * 4
        return score
    }

    static func handwritingRows(_ lines: [OCRLine]) -> [String] {
        let rows = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.box.midY > $1.box.midY }
        // 같은 높이에 나뉘어 읽힌 조각은 한 줄로 합침
        var merged: [(text: String, box: CGRect)] = []
        for line in rows {
            if let last = merged.last, abs(last.box.midY - line.box.midY) < min(last.box.height, line.box.height) * 0.5 {
                let left = last.box.minX <= line.box.minX
                merged[merged.count - 1] = (left ? last.text + " " + line.text : line.text + " " + last.text, last.box.union(line.box))
            } else {
                merged.append((line.text, line.box))
            }
        }
        return merged.map { MathOCRFixer.fix($0.text) }
    }

    /// 여러 번 읽은 글자 줄 → 뜻을 가장 많이 찾은 단어 목록 (빠진 뜻은 다른 쪽에서 채움)
    static func bestWords(_ readings: [[OCRLine]]) -> [ParsedWord] {
        let parsed = readings.map { WordParser.parse($0) }
        func score(_ words: [ParsedWord]) -> Int { words.filter { !$0.meaning.isEmpty }.count * 2 - words.filter(\.unsure).count }
        guard var best = parsed.max(by: { score($0) < score($1) }) else { return [] }
        for other in parsed {
            for i in best.indices where best[i].meaning.isEmpty {
                if let match = other.first(where: { $0.term.lowercased() == best[i].term.lowercased() && !$0.meaning.isEmpty }) {
                    best[i].meaning = match.meaning
                }
            }
        }
        return best
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }

    /// 인쇄된 문제 위주로 남기기: 신뢰도가 낮은 줄(손글씨)과
    /// 한글·보기 번호 없이 숫자/기호만 있는 짧은 줄(풀이 계산 흔적)을 뺌
    static func printedText(from lines: [OCRLine]) -> String {
        // 같은 줄에 띄어서 놓인 보기 조각들("12", "14" …)은 한 줄로 합친 뒤에 거름
        let pieces = lines.filter { $0.confidence >= 0.35 && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let grouped = MathOCRFixer.rows(pieces.map(\.box)).compactMap { row -> OCRLine? in
            guard row.count >= 2, MathOCRFixer.isChoiceRow(row.map { pieces[$0].text }) else { return nil }
            let box = row.map { pieces[$0].box }.reduce(pieces[row[0]].box) { $0.union($1) }
            let confidence = row.map { pieces[$0].confidence }.max() ?? 0
            return OCRLine(text: row.map { pieces[$0].text }.joined(separator: "   "), confidence: max(confidence, 0.5), box: box)
        }
        let usedBoxes = grouped.map(\.box)
        let rest = lines.filter { line in !usedBoxes.contains { $0.contains(CGPoint(x: line.box.midX, y: line.box.midY)) && $0.height < line.box.height * 2.5 } }
        let kept = (grouped + rest).filter { line in
            let text = line.text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, line.confidence >= 0.35 else { return false }
            let hasHangul = text.range(of: "[가-힣]", options: .regularExpression) != nil
            let hasChoice = text.range(of: "[①②③④⑤]", options: .regularExpression) != nil
            // 보기 번호를 "(1) 12", "1) 3", "(2 √3"처럼 읽은 짧은 줄과 빈칸이 있는 줄도 문제의 일부
            let looksChoice = text.range(of: #"^\s*(\([1-5lIZS]\)|\([1-5lIZS](?=\s)|[1-5]\))"#, options: .regularExpression) != nil
            let hasBlank = text.contains(where: { "□口".contains($0) })
            if hasHangul || hasChoice || looksChoice || hasBlank { return true }
            if text.count <= 6 { return false }
            return line.confidence >= 0.5
        }
        return plainText(from: kept)
    }

    /// 위에서 아래 순서로 정렬된 전체 텍스트
    static func plainText(from lines: [OCRLine]) -> String {
        MathOCRFixer.joinRows(lines.map { (text: $0.text, box: $0.box) }).joined(separator: "\n")
    }
}
