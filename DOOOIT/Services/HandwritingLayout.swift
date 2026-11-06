import Foundation

/// 필기 판정의 자리 단서 (HandwritingFilter.tokens가 씀): 잉크 색이 인쇄와 같은 검정 펜 풀이·메모를 가를 때,
/// 글자 모양이 아니라 줄이 놓인 자리로 봄. 픽셀 없이 줄 상자만 다루므로 리눅스 테스트에서 그대로 검사
///
/// 원칙: 인쇄 문제는 번호(1.), 보기(①~⑤ 또는 가로로 늘어선 보기), 본문 문장 꼴이고 줄이 서로 맞물려 있음.
/// 학생 글은 그 구조 밖(마지막 보기 아래 빈 자리, 줄 끝 옆 여백, 문장 사이 틈)에 놓임.
/// 자리 단서는 단독으론 지우지 않을 만큼만 점수를 줌 (임계값 1.8 아래) → 다른 단서와 겹칠 때만 필기
extension HandwritingFilter {
    /// 줄 하나에 대한 자리 단서
    struct LineCue: Equatable {
        /// 같은 높이 바로 왼쪽에 더 긴 인쇄 줄이 있고 이 줄은 짧은 글 (문제 줄 끝에 덧붙인 답·메모)
        var sideNote = false
        /// 줄머리 기호(- → ∴ ∵ ⇒ ㄴ)로 시작하는 메모
        var bullet = false
        /// 위아래 인쇄 줄과 멀리 떨어져 홀로 선 줄
        var isolated = false
        /// 보기가 2×2·2×3 격자로 놓인 문제의 아랫줄 (번호를 못 읽었어도 윗줄 보기와 세로 칸이 둘 이상 맞음)
        var gridChoice = false
    }

    static let circledNumbers: Set<Character> = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩"]

    /// 번호(1.)·보기(①)·(A) 따위로 시작하는 구조 줄인지
    static func isStructuredStart(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        if let c = t.first, circledNumbers.contains(c) { return true }
        if t.range(of: #"^\d+\s*[.)]"#, options: .regularExpression) != nil { return true }
        return t.range(of: #"^\([A-Ea-e가-라]\)"#, options: .regularExpression) != nil
    }

    static func nonSpaceCount(_ text: String) -> Int { text.filter { !$0.isWhitespace }.count }

    /// 줄 높이에 맞는 가로 한 줄 (y 가운데가 가까움)
    private static func sameRow(_ a: Line, _ b: Line, tolerance: Double) -> Bool {
        abs(Double(a.box.midY) - Double(b.box.midY)) <= tolerance
    }

    /// 번호(①)를 못 읽었어도 가로로 늘어선 보기 줄: 짧은 줄 셋 이상이 한 높이에 나란히 (360° 540° 720° 900° 1080°, -3 2 -2 0 4)
    /// 위에 문제 문장이 있어야 함. 그 줄들이 끝나는 아래(맨 아래 y)를 돌려줌
    static func choiceRowBottom(_ lines: [Line], lineHeight lh: Double) -> Double? {
        let short = lines.filter { line in
            let n = nonSpaceCount(line.text)
            return n >= 1 && n <= 10 && !isStructuredStart(line.text) && Double(line.box.height) <= lh * 2.2
        }
        var best: Double?
        // 가로 줄이 셋 넘게 쌓이면 보기가 아니라 표 (표 아래 글을 보기 아래로 보지 않게)
        var rowTops: [Double] = []
        for anchor in short where short.filter({ sameRow(anchor, $0, tolerance: lh * 0.45) }).count >= 3 {
            let y = Double(anchor.box.midY)
            if !rowTops.contains(where: { abs($0 - y) <= lh * 0.6 }) { rowTops.append(y) }
        }
        guard rowTops.count <= 2 else { return nil }
        for anchor in short {
            let row = short.filter { sameRow(anchor, $0, tolerance: lh * 0.45) }
            guard row.count >= 3 else { continue }
            // 서로 겹치지 않고 띄엄띄엄 놓여야 보기 (겹치면 한 식이 쪼개진 것)
            let sorted = row.sorted { $0.box.minX < $1.box.minX }
            let gaps = zip(sorted, sorted.dropFirst()).map { Double($1.box.minX - $0.box.maxX) }
            guard gaps.allSatisfy({ $0 >= lh * 0.8 }) else { continue }
            let top = Double(anchor.box.minY)
            let stem = lines.contains { line in
                Double(line.box.maxY) <= top + lh * 0.2 && Double(line.box.maxY) >= top - lh * 5
                    && nonSpaceCount(line.text) >= 8 && line.text.filter(isHangul).count >= 3
            }
            guard stem else { continue }
            let bottom = row.map { Double($0.box.maxY) }.max() ?? Double(anchor.box.maxY)
            best = max(best ?? bottom, bottom)
        }
        return best
    }

    /// 격자 보기의 아랫줄: 윗줄 보기(번호로 시작하는 줄)의 세로 칸(번호 왼쪽 끝, 번호 뒤 내용 왼쪽 끝)에 맞춰 같은 높이에 둘 이상 놓인 짧은 줄
    /// 학생 풀이는 한 칸에 한 줄씩 쓰므로 같은 높이에서 서로 다른 두 칸에 맞는 일이 거의 없음. 맞는 줄의 차례를 돌려줌
    static func gridChoiceLines(_ lines: [Line], lineHeight lh: Double) -> Set<Int> {
        let tol = lh * 0.4
        // 윗줄 보기: 번호로 시작하는 줄 → 칸 위치 후보 (줄 왼쪽 끝, 번호 뒤 내용 왼쪽 끝), 번호 없이 읽힌 짧은 보기도 줄 왼쪽 끝
        var columns: [(x: Double, bottom: Double)] = []
        for line in lines {
            let t = line.text.trimmingCharacters(in: .whitespaces)
            guard nonSpaceCount(t) <= 14 else { continue }
            columns.append((Double(line.box.minX), Double(line.box.maxY)))
            if let first = t.first, circledNumbers.contains(first),
               let content = line.glyphs.first(where: { !$0.char.isWhitespace && !circledNumbers.contains($0.char) })?.box {
                columns.append((Double(content.minX), Double(line.box.maxY)))
            }
        }
        var result: Set<Int> = []
        let candidates = lines.indices.filter { nonSpaceCount(lines[$0].text) <= 12 && !isStructuredStart(lines[$0].text) }
        for i in candidates {
            let row = candidates.filter { abs(Double(lines[$0].box.midY) - Double(lines[i].box.midY)) <= lh * 0.45 }
            guard row.count >= 2 else { continue }
            // 이 줄 바로 위(한 줄 반 안)에 있는 줄의 칸에 맞는 줄만
            let aligned = row.filter { j in
                columns.contains { col in
                    abs(col.x - Double(lines[j].box.minX)) <= tol && col.bottom <= Double(lines[j].box.minY) + lh * 0.3
                        && Double(lines[j].box.minY) - col.bottom <= lh * 2.2
                }
            }
            if aligned.count >= 2, aligned.contains(i) { result.insert(i) }
        }
        return result
    }

    private static let bulletStarts = ["->", "→", "⇒", "∴", "∵", "ㄴ", "-", "–", "−"]

    /// 줄머리 기호 메모: "- 기울기 3", "→ 개념 부족" (한글·영문 글이 이어져야 함. "-3" 같은 음수는 아님)
    static func bulletNote(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard let mark = bulletStarts.first(where: { t.hasPrefix($0) }) else { return false }
        let rest = t.dropFirst(mark.count).trimmingCharacters(in: .whitespaces)
        return rest.filter(isHangul).count >= 2 || rest.range(of: #"^[A-Za-z]{2,}"#, options: .regularExpression) != nil
    }

    /// 줄마다 자리 단서 (lines와 같은 차례). lh: 인쇄 줄 높이
    static func layoutCues(_ lines: [Line], lineHeight lh: Double) -> [LineCue] {
        var cues = [LineCue](repeating: LineCue(), count: lines.count)
        // 믿을 만한 인쇄 줄 후보: 신뢰도가 높거나 구조 줄이거나 문장 꼴로 긴 줄
        func printedLike(_ line: Line) -> Bool {
            let n = nonSpaceCount(line.text)
            return n >= 10 && (line.confidence >= 0.5 || isStructuredStart(line.text)) && Double(line.box.height) <= lh * 1.5
        }
        for (i, line) in lines.enumerated() {
            let n = nonSpaceCount(line.text)
            cues[i].bullet = bulletNote(line.text)
            // 줄 끝 옆 메모: 오른쪽이 아닌 바로 오른쪽 빈 곳, 같은 높이에 더 긴 인쇄 줄이 왼쪽에 있음
            if n <= 8, !isStructuredStart(line.text) {
                let ownTop = Double(line.box.minY), ownBottom = Double(line.box.maxY)
                for other in lines where other.box != line.box && printedLike(other) && nonSpaceCount(other.text) >= n + 6 {
                    let overlap = min(ownBottom, Double(other.box.maxY)) - max(ownTop, Double(other.box.minY))
                    let gap = Double(line.box.minX - other.box.maxX)
                    if overlap >= Double(min(line.box.height, other.box.height)) * 0.5, gap >= -lh * 0.2, gap <= lh * 3 {
                        cues[i].sideNote = true
                        break
                    }
                }
            }
        }
        // 홀로 선 줄: 위·아래 가장 가까운 줄과 모두 줄 높이만큼 이상 떨어짐 (인쇄 문단은 줄 간격이 고름)
        let order = lines.indices.sorted { lines[$0].box.minY < lines[$1].box.minY }
        for (rank, i) in order.enumerated() {
            let line = lines[i]
            guard !isStructuredStart(line.text), nonSpaceCount(line.text) <= 16 else { continue }
            func gapTo(_ j: Int) -> Double? {
                let o = lines[j]
                // 가로로 겹치는 줄만 (옆 열은 이웃이 아님)
                let hx = min(line.box.maxX, o.box.maxX) - max(line.box.minX, o.box.minX)
                guard hx > 0 else { return nil }
                return abs(Double(o.box.midY) - Double(line.box.midY)) - Double(o.box.height + line.box.height) / 2
            }
            var up: Double?, down: Double?
            for j in order[..<rank].reversed() { if let g = gapTo(j) { up = g; break } }
            for j in order[(rank + 1)...] { if let g = gapTo(j) { down = g; break } }
            if let up, let down, up >= lh * 0.5, down >= lh * 0.5 { cues[i].isolated = true }
        }
        for i in gridChoiceLines(lines, lineHeight: lh) { cues[i].gridChoice = true }
        return cues
    }
}
