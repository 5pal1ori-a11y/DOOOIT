import Foundation

/// 글자 인식 결과 한 줄 + 글자마다 상자 (Vision 없이 다룰 수 있게 꺼낸 것 → 리눅스 테스트·다시 채점에서도 같은 코드)
struct OCRGlyphLine {
    var text: String
    var confidence: Float
    /// Vision 정규화 좌표 (0~1, 원점 왼쪽 아래)
    var box: CGRect
    /// 글자(Character)마다 상자. 빈칸이나 상자를 모르는 글자는 nil
    var charBoxes: [CGRect?]
}

// MARK: - 수학이 아닌 과목: 두 번 읽은 결과 합치기 (한국어+영어 / 영어 전용)

/// 국어·영어·과학·사회 문제 사진: 한국어 인식은 한글 문장을 잘 읽지만 영어 낱말을 한글로("go" → "영"),
/// 단위·기호를 엉뚱한 글자로("m/s" → "m/$", "N" → "~") 읽기도 함. 영어 전용 인식은 그 반대.
/// → 줄을 글자 종류(한글 / 그 밖)로 나눈 조각마다 더 그럴듯한 쪽을 고름 (영어가 대부분인 줄의 한글 조각은 영어로)
extension OCRService {
    private static let circledChoices: [Character] = ["①", "②", "③", "④", "⑤"]

    /// 동그라미 번호 자리 정하기: 줄마다 (지울 글자 범위, 번호)
    /// circles: 동그라미 번호로 판정한 모양들의 상자 (겹친 것 포함 가능)
    static func choiceCircleEdits(lines: [OCRGlyphLine], circles: [CGRect], lineHeight: CGFloat,
                                  minGap: CGFloat = 0.2) -> [Int: [(remove: Range<Int>, number: Int)]] {
        // 겹친 것(테두리 안팎 윤곽)은 하나로
        var boxes: [CGRect] = []
        for box in circles.sorted(by: { $0.height > $1.height }) where !boxes.contains(where: { $0.intersects(box.insetBy(dx: box.width * 0.2, dy: box.height * 0.2)) }) {
            boxes.append(box)
        }
        var places: [(line: Int, remove: Range<Int>, anchor: Int?)?] = []
        for box in boxes {
            let sameRow = lines.indices.filter { i in
                let line = lines[i].box
                let overlap = min(line.maxY, box.maxY) - max(line.minY, box.minY)
                return overlap >= min(line.height, box.height) * 0.5
            }
            let inside = sameRow.first { lines[$0].box.insetBy(dx: -0.004, dy: 0).contains(CGPoint(x: box.midX, y: lines[$0].box.midY)) }
            let right = sameRow.filter { lines[$0].box.minX >= box.midX && lines[$0].box.minX - box.maxX <= lineHeight * 2.5 }
                .min { lines[$0].box.minX < lines[$1].box.minX }
            guard let li = inside ?? right else { places.append(nil); continue }
            let line = lines[li]
            let chars = Array(line.text)
            func charBox(_ i: Int) -> CGRect? { i < line.charBoxes.count ? line.charBoxes[i] : nil }
            let zone = box.insetBy(dx: -box.width * 0.15, dy: -box.height * 0.15)
            var covered: [Int] = []
            var insertAt = 0
            var anchor: Int?
            for i in chars.indices where !chars[i].isWhitespace {
                guard let cb = charBox(i) else { continue }
                if zone.contains(CGPoint(x: cb.midX, y: cb.midY)), cb.width < box.width * 1.3 {
                    covered.append(i)
                    if let n = circledChoices.firstIndex(of: chars[i]) { anchor = n + 1 }
                } else if cb.maxX <= box.midX {
                    insertAt = i + 1
                }
            }
            // 왼쪽 글자가 너무 붙어 있으면 낱말 속 글자(점 O 등)라서 번호가 아님
            if covered.isEmpty, insertAt > 0, let left = charBox(insertAt - 1), box.minX - left.maxX < lineHeight * minGap {
                places.append(nil)
                continue
            }
            // 낱말 한가운데 글자("don't", "homework"의 o)는 번호가 아님
            if let first = covered.min(), let last = covered.max(), first > 0, last + 1 < chars.count,
               chars[first - 1].isLetter, chars[last + 1].isLetter {
                places.append(nil)
                continue
            }
            // 바로 옆에 이미 읽힌 ①~⑤가 있으면 그 글자가 이 동그라미 (번호를 두 번 넣지 않게)
            if covered.isEmpty {
                var right = insertAt
                while right < chars.count, chars[right].isWhitespace { right += 1 }
                var left = insertAt - 1
                while left >= 0, chars[left].isWhitespace { left -= 1 }
                for k in [right, left] where k >= 0 && k < chars.count {
                    if let n = circledChoices.firstIndex(of: chars[k]) { covered = [k]; anchor = n + 1; break }
                }
            }
            let range = covered.isEmpty ? insertAt..<insertAt : (covered.min()!)..<(covered.max()! + 1)
            places.append((li, range, anchor))
        }
        var anchors: [Int: Int] = [:]
        for (k, place) in places.enumerated() { if let a = place?.anchor { anchors[k] = a } }
        let valid = boxes.indices.filter { places[$0] != nil }
        let numbers = MathOCRFixer.numberCircles(valid.map { boxes[$0] }, lineHeight: lineHeight,
                                                 anchors: Dictionary(uniqueKeysWithValues: valid.enumerated().compactMap { k, i in anchors[i].map { (k, $0) } }))
        var edits: [Int: [(remove: Range<Int>, number: Int)]] = [:]
        for (k, i) in valid.enumerated() where numbers[k] > 0 {
            guard let place = places[i] else { continue }
            // 동그라미 자리를 다른 숫자 하나("9", "6")로 또렷이 읽었으면 그건 보기 값의 숫자 (모양만 둥근 것)
            if place.remove.count == 1 {
                let c = Array(lines[place.line].text)[place.remove.lowerBound]
                if c.isASCII, c.isNumber, !"10".contains(c), String(c) != String(numbers[k]) { continue }
            }
            // 같은 자리를 두 번 고치지 않음
            if edits[place.line]?.contains(where: { $0.remove.overlaps(place.remove) || ($0.remove.isEmpty && $0.remove.lowerBound == place.remove.lowerBound) }) == true { continue }
            edits[place.line, default: []].append((place.remove, numbers[k]))
        }
        return edits
    }

    /// 영어·기호 조각이 얼마나 그럴듯한지 (클수록 좋음)
    static func latinScore(_ text: String) -> Int {
        var score = 0
        let chars = Array(text)
        let scienceMarks: Set<Character> = ["°", "²", "³", "₂", "₃", "₄", "⁺", "⁻", "→", "⇌", "Δ", "μ", "Ω", "·", "℃", "←", "↑", "↓"]
        let plainMarks: Set<Character> = [".", ",", "'", "\"", "?", "!", ":", ";", "(", ")", "-", "/", "%", "=", "+", "<", ">", "[", "]", "’", "‘", "“", "”"]
        for (i, c) in chars.enumerated() {
            let prev: Character? = i > 0 ? chars[i - 1] : nil
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            if c.isWhitespace {
                continue
            } else if c.isASCII && c.isLetter {
                score += 2
            } else if c.isASCII && c.isNumber {
                // 소문자 낱말 속 숫자("g0", "he1p")는 잘못 읽은 것
                if (prev.map { $0.isASCII && $0.isLowercase } ?? false) || (next.map { $0.isASCII && $0.isLowercase } ?? false) {
                    score -= 2
                } else {
                    score += 2
                }
            } else if scienceMarks.contains(c) {
                score += 2
            } else if plainMarks.contains(c) {
                score += 1
            } else if isHangul(c) {
                score -= 4
            } else {
                // §, ₩, $, ~, ©, |, 낯선 기호
                score -= 3
            }
        }
        // 낱말 하나로 선 "l", "|"는 대개 I
        if text == "l" || text == "|" { score -= 3 }
        return score
    }

    /// 한국어+영어 인식 줄들과 영어 전용 인식 줄들 → 합친 줄
    /// circles: 동그라미 번호로 판정한 모양 상자 (MathOCRFixer.isChoiceCircle 통과한 것)
    static func subjectMerge(korean: [OCRGlyphLine], english: [OCRGlyphLine], circles: [CGRect]) -> [OCRLine] {
        let heights = korean.map(\.box.height).sorted()
        let lineHeight = heights.isEmpty ? 0 : heights[heights.count / 2]
        let edits = choiceCircleEdits(lines: korean, circles: circles, lineHeight: lineHeight)
        let circleZones = circles.map { $0.insetBy(dx: -$0.width * 0.1, dy: -$0.height * 0.1) }

        // 영어 전용 결과를 낱말 단위로 (Vision은 영어 전용 인식의 글자 상자를 낱말 상자로 주기도 해서 낱말끼리 맞춤).
        // 동그라미 자리 글자("1", "(1)")는 뺌
        struct EnglishWord { let text: String; let box: CGRect; let confidence: Float }
        var englishWords: [EnglishWord] = []
        for line in english {
            let chars = Array(line.text)
            var i = 0
            while i < chars.count {
                guard !chars[i].isWhitespace else { i += 1; continue }
                var j = i
                while j < chars.count, !chars[j].isWhitespace { j += 1 }
                // 동그라미 안 글자 빼기 (글자 상자가 따로 있을 때)
                var kept: [(Character, CGRect)] = []
                for k in i..<j {
                    guard k < line.charBoxes.count, let box = line.charBoxes[k] else { continue }
                    kept.append((chars[k], box))
                }
                let distinct = Set(kept.map { "\($0.1.minX),\($0.1.width)" }).count > 1
                if distinct {
                    kept.removeAll { item in circleZones.contains { $0.contains(CGPoint(x: item.1.midX, y: item.1.midY)) } }
                }
                if let first = kept.first {
                    var text = String(kept.map(\.0))
                    let box = kept.dropFirst().reduce(first.1) { $0.union($1.1) }
                    if !distinct, circleZones.contains(where: { $0.intersects(box) }) {
                        // 낱말 상자뿐이면 앞에 붙은 번호 모양만 떼어 냄 ("1go" → "go"), 번호 하나뿐이면 버림
                        if text.range(of: #"^(?:\(?[1-5lI]\)?|[①②③④⑤@©®])$"#, options: .regularExpression) != nil { text = "" }
                        text = text.replacingOccurrences(of: #"^(?:\(?[1-5lI]\)|[1-5]|[①②③④⑤@©®])(?=[A-Za-z])"#, with: "", options: .regularExpression)
                    }
                    if !text.isEmpty { englishWords.append(EnglishWord(text: text, box: box, confidence: line.confidence)) }
                }
                i = j
            }
        }
        /// 낱말과 상자가 가로로 겹친 길이 (세로로 같은 줄일 때만)
        func overlapX(_ w: EnglishWord, _ box: CGRect) -> CGFloat {
            let overlapY = min(w.box.maxY, box.maxY) - max(w.box.minY, box.minY)
            guard overlapY >= min(w.box.height, box.height) * 0.5 else { return 0 }
            return max(0, min(w.box.maxX, box.maxX) - max(w.box.minX, box.minX))
        }
        func englishText(_ picked: Set<Int>) -> (text: String, confidence: Float)? {
            let words = picked.map { englishWords[$0] }.sorted { $0.box.minX < $1.box.minX }
            guard !words.isEmpty else { return nil }
            return (words.map(\.text).joined(separator: " "), words.map(\.confidence).min() ?? 0)
        }

        // 줄(같은 높이 조각들)마다 영어가 대부분인지
        let rows = MathOCRFixer.rows(korean.map(\.box))
        var rowOf: [Int: Int] = [:]
        for (r, row) in rows.enumerated() { for i in row { rowOf[i] = r } }
        func counts(_ line: Int) -> (letters: Int, hangul: Int) {
            let covered = Set((edits[line] ?? []).flatMap { Array($0.remove) })
            var letters = 0, hangul = 0
            for (i, c) in korean[line].text.enumerated() where !covered.contains(i) {
                if c.isASCII && c.isLetter { letters += 1 } else if isHangul(c) { hangul += 1 }
            }
            return (letters, hangul)
        }
        let lineCounts = korean.indices.map(counts)
        let choiceLines = korean.indices.filter { edits[$0] != nil || korean[$0].text.contains(where: { circledChoices.contains($0) }) }
        func englishMajority(row: Int, excludingHangul: Int, line: Int) -> Bool {
            var letters = rows[row].reduce(0) { $0 + lineCounts[$1].letters }
            var hangul = rows[row].reduce(0) { $0 + lineCounts[$1].hangul } - excludingHangul
            // 보기 줄 하나에 보기 하나뿐이면 ("① go") 다른 보기 줄들까지 함께 봄
            if letters < 3, choiceLines.contains(line) {
                letters = choiceLines.reduce(0) { $0 + lineCounts[$1].letters }
                hangul = choiceLines.reduce(0) { $0 + lineCounts[$1].hangul } - excludingHangul
            }
            return letters >= 3 && letters >= hangul * 3
        }

        var result: [OCRLine] = []
        for (li, line) in korean.enumerated() {
            let chars = Array(line.text)
            func charBox(_ i: Int) -> CGRect? { i < line.charBoxes.count ? line.charBoxes[i] : nil }
            let lineEdits = edits[li] ?? []
            let covered = Set(lineEdits.flatMap { Array($0.remove) })
            // 조각: 빈칸·동그라미 자리로 끊고, 한글 / 그 밖 글자로 나눔
            var segments: [Range<Int>] = []
            var start: Int?
            for i in chars.indices {
                let breaks = chars[i].isWhitespace || covered.contains(i)
                    || lineEdits.contains(where: { $0.remove.isEmpty && $0.remove.lowerBound == i })
                    || (start.map { isHangul(chars[$0]) != isHangul(chars[i]) } ?? false)
                if breaks, let s = start { segments.append(s..<i); start = nil }
                if !chars[i].isWhitespace && !covered.contains(i) && start == nil { start = i }
            }
            if let s = start { segments.append(s..<chars.count) }

            var replacements: [(range: Range<Int>, text: String)] = []
            var usedEnglish = false
            var englishConfidence: Float = 0
            // 영어 전용 낱말마다 가장 많이 겹친 한국어 조각 하나에 줌. 낱말 하나가 글자 있는 조각 여럿에 걸치면("B )," ↔ "B),")
            // 그 조각들을 한 덩어리로 (같은 낱말이 두 번 들어가지 않게)
            let segmentBoxes: [CGRect?] = segments.map { segment in
                let boxes = segment.compactMap(charBox)
                guard let first = boxes.first else { return nil }
                return boxes.dropFirst().reduce(first) { $0.union($1) }
            }
            var owner: [Int: Int] = [:]          // 낱말 → 조각
            var touching: [Int: Set<Int>] = [:]  // 낱말 → 걸친 조각들
            for (w, word) in englishWords.enumerated() {
                var best: (segment: Int, overlap: CGFloat)?
                for (k, box) in segmentBoxes.enumerated() {
                    guard let box else { continue }
                    let o = overlapX(word, box)
                    guard o > 0 else { continue }
                    if o >= min(word.box.width, box.width) * 0.25 { touching[w, default: []].insert(k) }
                    if o > (best?.overlap ?? 0) { best = (k, o) }
                }
                guard let best, let box = segmentBoxes[best.segment],
                      best.overlap >= word.box.width * 0.5 || (word.box.midX >= box.minX && word.box.midX <= box.maxX)
                        || best.overlap >= box.width * 0.6 else { continue }
                owner[w] = best.segment
            }
            // 글자 있는 조각 (보기 번호 ①~⑤는 숫자로 치지 않음)
            func wordy(_ k: Int) -> Bool {
                chars[segments[k]].contains { $0.isASCII && ($0.isLetter || $0.isNumber) }
                    && !chars[segments[k]].contains(where: { isHangul($0) || circledChoices.contains($0) })
            }
            var units: [(range: Range<Int>, picked: Set<Int>)] = []
            var unitOf: [Int] = []
            for k in segments.indices {
                let picked = Set(owner.filter { $0.value == k }.map(\.key))
                // 괄호·문장 부호만 있는 조각("(")은 옆 글자 조각과 함께 (영어 전용이 "(B),"처럼 한 낱말로 읽었을 때)
                func joinable(_ k: Int) -> Bool { wordy(k) || chars[segments[k]].allSatisfy { "()[]{}.,'\"!?:;-".contains($0) } }
                if k > 0, let last = units.last, joinable(k), joinable(k - 1), wordy(k) || wordy(k - 1), unitOf.last == units.count - 1,
                   touching.values.contains(where: { $0.contains(k) && $0.contains(k - 1) }),
                   !(segments[k - 1].upperBound..<segments[k].lowerBound).contains(where: { covered.contains($0) || !chars[$0].isWhitespace }) {
                    units[units.count - 1] = (last.range.lowerBound..<segments[k].upperBound, last.picked.union(picked))
                } else {
                    units.append((segments[k], picked))
                }
                unitOf.append(units.count - 1)
            }
            for (segment, picked) in units {
                let original = String(chars[segment])
                let hangul = original.contains(where: isHangul)
                // 보기 번호 ①~⑤는 그대로
                if original.contains(where: { circledChoices.contains($0) }) { continue }
                guard let found = englishText(picked), found.text != original else { continue }
                let rep = found.text
                let touchesHangul = (segment.lowerBound > 0 && isHangul(chars[segment.lowerBound - 1]))
                    || (segment.upperBound < chars.count && isHangul(chars[segment.upperBound]))
                let alone = (segment.lowerBound == 0 || chars[segment.lowerBound - 1].isWhitespace || covered.contains(segment.lowerBound - 1)
                             || (chars[segment.lowerBound - 1].isASCII && chars[segment.lowerBound - 1].isNumber && hangul)
                             || lineEdits.contains(where: { $0.remove.isEmpty && $0.remove.lowerBound == segment.lowerBound }))
                    && (segment.upperBound == chars.count || chars[segment.upperBound].isWhitespace || covered.contains(segment.upperBound)
                        || ".,?!".contains(chars[segment.upperBound]))
                if hangul {
                    // 한글 조각: 영어가 대부분인 줄에서 낱말 하나로 떨어져 있을 때만 영어로 ("go" → "영")
                    let count = original.filter(isHangul).count
                    guard alone, let row = rowOf[li], englishMajority(row: row, excludingHangul: count, line: li),
                          found.confidence >= 0.3,
                          rep.allSatisfy({ ($0.isASCII && $0.isLetter) || "'-.,?! ".contains($0) }),
                          rep.contains(where: { "aeiouyAEIOUY".contains($0) }) || rep == "I",
                          rep.count <= count * 6 + 2 else { continue }
                    replacements.append((segment, rep))
                } else {
                    guard rep.count * 2 >= original.count, rep.count <= original.count * 2 + 2 else { continue }
                    // 기호만 있는 조각은 낱말로 떨어진 낯선 기호("~", "§")일 때만
                    if !original.contains(where: { $0.isLetter || $0.isNumber }), !(alone && latinScore(original) < 0) { continue }
                    // 한글에 붙은 조각("CO2를"의 CO2)은 글자 수가 같을 때만 (옆 한글을 영어로 읽은 찌꺼기가 섞이지 않게)
                    if touchesHangul, rep.count != original.count { continue }
                    let a = latinScore(rep), b = latinScore(original)
                    let sameShape = original.allSatisfy(\.isASCII) && rep.allSatisfy(\.isASCII) && rep.count == original.count
                    // 띄어쓰기만 다르면 영어 전용 쪽 ("IfI" → "If I")
                    let spacing = rep.filter { !$0.isWhitespace } == original.filter { !$0.isWhitespace }
                        && rep.filter(\.isWhitespace).count > original.filter(\.isWhitespace).count
                    // 영어 줄의 영어 낱말끼리는 영어 전용 인식을 믿음 (한국어 인식이 "are"를 "ares"로 바꾸기도 해서), 크게 나쁘지 않으면
                    let plainWords = { (t: String) in t.allSatisfy { $0.isASCII && ($0.isLetter || " '.,?!".contains($0)) } }
                    let englishRow = rowOf[li].map { englishMajority(row: $0, excludingHangul: 0, line: li) } ?? false
                    let trustEnglish = englishRow && plainWords(rep) && plainWords(original) && a >= b - 2 && found.confidence >= 0.5
                        && rep.split(separator: " ").count == original.split(separator: " ").count
                    guard a > b || (a == b && (sameShape || spacing)) || trustEnglish else { continue }
                    replacements.append((segment, rep))
                }
                usedEnglish = true
                englishConfidence = max(englishConfidence, found.confidence)
            }

            var out = chars
            var all: [(start: Int, end: Int, text: String)] = replacements.map { ($0.range.lowerBound, $0.range.upperBound, $0.text) }
            all += lineEdits.map { ($0.remove.lowerBound, $0.remove.upperBound, " \(circledChoices[$0.number - 1]) ") }
            for edit in all.sorted(by: { $0.start != $1.start ? $0.start > $1.start : $0.end > $1.end }) {
                out.replaceSubrange(edit.start..<edit.end, with: Array(edit.text))
            }
            let text = String(out).replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            var confidence = line.confidence
            // 영어 줄: 한국어 인식은 영어 문장의 신뢰도를 낮게 주기도 해서 영어 전용 인식의 신뢰도도 봄
            if usedEnglish || (rowOf[li].map { englishMajority(row: $0, excludingHangul: 0, line: li) } ?? false) {
                let overlapping = english.filter { overlapRatio($0.box, line.box) > 0.5 }.map(\.confidence).max() ?? 0
                confidence = max(confidence, min(max(englishConfidence, overlapping), 0.9))
            }
            result.append(OCRLine(text: text, confidence: adjustedConfidence(text, confidence), box: line.box))
        }
        // 한국어 인식이 통째로 놓친 영어 줄
        for line in english where line.confidence >= 0.6 {
            let letters = line.text.filter { $0.isASCII && $0.isLetter }.count
            guard letters >= 4, Double(letters) >= Double(line.text.filter { !$0.isWhitespace }.count) * 0.6,
                  !korean.contains(where: { overlapRatio($0.box, line.box) > 0.2 }) else { continue }
            result.append(OCRLine(text: line.text, confidence: line.confidence, box: line.box))
        }
        return result
    }

    /// 여러 사진(펜 지운 사진, 원래 사진)을 읽은 줄들 중 더 잘 읽힌 쪽 (흐린 줄·빈 줄은 뺌)
    static func chooseSubjectReading(_ readings: [[OCRLine]]) -> (index: Int, lines: [OCRLine]) {
        var best: (index: Int, lines: [OCRLine]) = (0, [])
        var bestScore = -1.0
        for (k, lines) in readings.enumerated() {
            let kept = lines.filter { $0.confidence >= 0.3 && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            let score = subjectReadingScore(kept)
            if score > bestScore { best = (k, kept); bestScore = score }
        }
        return best
    }

    /// 읽은 줄들이 얼마나 많이·또렷이 읽혔는지 (원본 / 펜 지운 사진 중 고를 때)
    static func subjectReadingScore(_ lines: [OCRLine]) -> Double {
        lines.reduce(0.0) { total, line in
            let marks = line.text.filter { circledChoices.contains($0) }.count
            return total + Double(line.text.count) * Double(line.confidence) + Double(marks) * 3
        }
    }
}

// MARK: - 수학이 아닌 과목: 글자 정리 (영어 · 과학 기호)

enum SubjectTextFixer {
    /// 영어 낱말 + 과학 기호 정리 (한글 문장은 그대로)
    static func fix(_ text: String) -> String {
        // 화학 문제(화학식·반응식·이온): 첨자·전하를 닮은 글자로 읽은 것까지 고침
        let chemistry = ["화학", "반응식", "이온", "분자", "원소", "→", "⇌"].contains { text.contains($0) }
        let lines = text.components(separatedBy: "\n").map { line in
            var l = fixEnglish(line)
            if chemistry { l = chemistryLookalikes(l) }
            l = fixScience(l)
            // 문장 넣기 자리: 번호가 괄호 앞으로 빠져나온 것 "① ( )" → "( ① )"
            l = l.replacingOccurrences(of: #"([①②③④⑤]) ?\( ?\)"#, with: "( $1 )", options: .regularExpression)
            return l
        }
        return passageCircles(lines.joined(separator: "\n"))
    }

    /// 지문 속 번호 ①~⑤ 중 몇 개를 "@", "©", "S" 같은 기호로 읽은 것: 진짜 번호와 함께 읽는 순서로 1~5가 빠짐없이 맞을 때만 바꿈
    static func passageCircles(_ text: String) -> String {
        let circled: [Character] = ["①", "②", "③", "④", "⑤"]
        let common: Set<String> = ["@", "©", "®", "§", "*", "(D", "Ⓒ", "ⓒ", "•"]
        let lookalike: [Int: Set<String>] = [1: ["(1", "(1)", "1)", "(l)"], 2: ["(2", "(2)", "2)"], 3: ["(3", "(3)", "3)"],
                                             4: ["(4", "(4)", "4)"], 5: ["S", "(5", "(5)", "5)", "(S"]]
        var lines = text.components(separatedBy: "\n").map { $0.components(separatedBy: " ") }
        var marks: [(line: Int, token: Int, real: Int?)] = []
        for (li, tokens) in lines.enumerated() {
            for (ti, token) in tokens.enumerated() {
                if token.count == 1, let n = circled.firstIndex(of: token.first!) { marks.append((li, ti, n + 1)) }
                else if common.contains(token) || lookalike.values.contains(where: { $0.contains(token) }) { marks.append((li, ti, nil)) }
            }
        }
        // 진짜 번호가 있고, 기호를 차례대로 채우면 1~5가 정확히 한 번씩
        guard marks.count == 5, marks.contains(where: { $0.real != nil }), marks.contains(where: { $0.real == nil }) else { return text }
        for (k, mark) in marks.enumerated() {
            if let real = mark.real { guard real == k + 1 else { return text } }
            else {
                let token = lines[mark.line][mark.token]
                guard common.contains(token) || lookalike[k + 1]?.contains(token) == true else { return text }
            }
        }
        for (k, mark) in marks.enumerated() where mark.real == nil { lines[mark.line][mark.token] = String(circled[k]) }
        return lines.map { $0.joined(separator: " ") }.joined(separator: "\n")
    }

    // MARK: 영어

    /// 자주 쓰는 m 낱말 ("rn"을 m으로 읽은 것 되돌리기 — 고친 낱말이 여기 있고 원래 낱말이 없을 때만)
    static let mWords = Set<String>([
        "from", "some", "time", "make", "come", "them", "more", "my", "me", "him", "am", "may", "much", "must", "many", "most", "man", "men",
        "made", "home", "number", "small", "name", "mother", "school", "game", "summer", "important", "problem", "remember", "family",
        "information", "same", "seem", "seems", "something", "sometimes", "become", "came", "money", "moment", "music", "mind", "minute",
        "minutes", "morning", "month", "months", "member", "members", "message", "might", "mean", "means", "meet", "meeting", "movie", "move",
        "market", "matter", "maybe", "make", "makes", "making", "model", "modern", "myself", "himself", "themselves", "team", "room", "form",
        "farm", "warm", "arm", "arms", "dream", "dreams", "climb", "smile", "smell", "smart", "amount", "among", "animal", "animals", "example",
        "simple", "system", "almost", "communicate", "community", "common", "company", "computer", "environment", "human", "humans",
        "improve", "machine", "medicine", "memory", "method", "middle", "milk", "million", "mistake", "mistakes", "mountain", "museum",
        "natural", "normal", "person", "programs", "program", "promise", "same", "temperature", "whom", "women", "woman", "mom", "him",
        "them", "time", "times", "come", "comes", "coming", "welcome", "become", "becomes", "mammal", "magnet", "mass", "measure", "metal",
        "matter", "molecule", "motion", "muscle", "climate", "emotion", "emotions", "impossible", "imagine", "image", "immediately",
    ] as [String])
    /// 첫 글자 l을 I로 읽은 낱말 ("Iike" → "like")
    static let lWords = Set<String>([
        "like", "likes", "little", "look", "looks", "looked", "looking", "live", "lives", "lived", "living", "last", "let", "long", "lot",
        "lots", "love", "loves", "loved", "learn", "learned", "learning", "leave", "life", "light", "line", "list", "listen", "later", "large",
        "less", "left", "language", "late", "lead", "leader", "level", "library", "lie", "low", "lunch", "lucky", "lose", "lost", "letter",
    ] as [String])

    static func fixEnglish(_ line: String) -> String {
        let latin = line.filter { $0.isASCII && $0.isLetter }.count
        guard latin >= 2 else { return line }
        var tokens = line.components(separatedBy: " ")
        let englishLine = latin >= 4 && latin >= line.filter { OCRService.isHangul($0) }.count * 2
        for (i, token) in tokens.enumerated() where !token.isEmpty {
            var t = token
            // 따옴표 모양 통일 (영어 낱말 속 ’ → ')
            t = t.replacingOccurrences(of: #"(?<=[A-Za-z])[’‘`´](?=[A-Za-z])"#, with: "'", options: .regularExpression)
            // 낱말 하나로 선 l, | → I ("l am", "l'm")
            if englishLine {
                let next = i + 1 < tokens.count ? tokens[i + 1] : ""
                let prev = i > 0 ? tokens[i - 1] : ""
                let wordNext = next.first.map { $0.isASCII && $0.isLetter } ?? false
                let wordPrev = prev.last.map { ($0.isASCII && $0.isLetter) || ".,?!".contains($0) } ?? false
                if (t == "l" || t == "|") && (wordNext || wordPrev) { t = "I" }
                if let m = t.firstMatch(of: #/^[l|]('(?:m|ve|ll|d))([.,!?]?)$/#) { t = "I" + m.1 + m.2 }
            }
            t = fixWord(t)
            tokens[i] = t
        }
        var result = tokens.joined(separator: " ")
        // 영어 낱말 뒤 문장 부호 앞 빈칸 ("apples ." → "apples.")
        result = result.replacingOccurrences(of: #"(?<=[A-Za-z]) +([.,!?;:])(?=\s|$)"#, with: "$1", options: .regularExpression)
        return result
    }

    /// 낱말 하나 (앞뒤 문장 부호 포함)
    static func fixWord(_ token: String) -> String {
        guard let core = token.firstMatch(of: #/^([("']*)([A-Za-z0-9|]+(?:'[A-Za-z]+)?)([.,!?;:)"']*)$/#) else { return token }
        let lead = String(core.1), tail = String(core.3)
        var word = String(core.2)
        let letters = word.filter { $0.isASCII && $0.isLetter }.count
        guard letters >= 1 else { return token }
        // vv → w
        if word.contains("vv"), letters >= 3 { word = word.replacingOccurrences(of: "vv", with: "w") }
        // 소문자 낱말 속 0 → o, 1 → l ("g0" → "go", "t0" → "to", "he1p" → "help")
        let digits = word.filter(\.isNumber)
        if !digits.isEmpty, digits.allSatisfy({ "01".contains($0) }) {
            var chars = Array(word)
            var changed = false
            for k in chars.indices where chars[k] == "0" || chars[k] == "1" {
                let prev: Character? = k > 0 ? chars[k - 1] : nil
                let next: Character? = k + 1 < chars.count ? chars[k + 1] : nil
                let lowerPrev = prev.map { $0.isASCII && $0.isLowercase } ?? false
                let lowerNext = next.map { $0.isASCII && $0.isLowercase } ?? false
                if chars[k] == "0", lowerPrev || lowerNext, !(prev?.isNumber ?? false), !(next?.isNumber ?? false) {
                    chars[k] = "o"; changed = true
                } else if chars[k] == "1", lowerPrev && lowerNext {
                    chars[k] = "l"; changed = true
                }
            }
            // 서수(1st, 2nd)·단위(10cm)는 그대로: 숫자로 시작하면 건너뜀 ("0f" → "of"는 고침)
            if changed, !(word.first?.isNumber ?? false) || word.first == "0" {
                word = String(chars)
            }
        }
        if word.allSatisfy({ $0.isASCII && $0.isLetter }) {
            let lower = word.lowercased()
            // rn → m (고친 낱말이 흔한 낱말일 때만)
            if lower.contains("rn") {
                let fixed = lower.replacingOccurrences(of: "rn", with: "m")
                if mWords.contains(fixed), !mWords.contains(lower) { word = matchCase(fixed, like: word) }
            }
            // 첫 글자 I → l ("Iike" → "like")
            if word.count >= 3, word.first == "I", word.dropFirst().allSatisfy(\.isLowercase), lWords.contains("l" + word.dropFirst()) {
                word = "l" + word.dropFirst()
            }
        }
        return lead + word + tail
    }

    private static func matchCase(_ word: String, like original: String) -> String {
        original.first?.isUppercase == true ? word.prefix(1).uppercased() + word.dropFirst() : word
    }

    // MARK: 과학 (화학식 · 이온 · 단위 · 기호)

    /// 화학식에 쓸 원소 기호 (낱말과 헷갈리는 No, In, As, At, V, W 등은 뺌)
    static let elements: Set<String> = [
        "H", "He", "Li", "Be", "B", "C", "N", "O", "F", "Ne", "Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar", "K", "Ca", "Ti", "Cr", "Mn",
        "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge", "Se", "Br", "Kr", "Rb", "Sr", "Ag", "Sn", "I", "Xe", "Cs", "Ba", "Pt", "Au", "Hg", "Pb", "U",
    ]
    /// 원소 하나뿐인 분자 (H₂, O₂ …)
    static let molecules: Set<String> = ["H2", "O2", "N2", "Cl2", "F2", "Br2", "I2", "O3"]

    static let subscripts: [Character: Character] = ["0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉"]
    static let superscripts: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "+": "⁺", "-": "⁻", "−": "⁻"]

    /// 화학 문제에서 첨자·전하를 닮은 글자로 읽은 것: "c02" → "CO2", "02-" → "O2-", "Hz" → "H2", "H,O" → "H2O", "Nat" → "Na+", "Mg'+" → "Mg2+"
    static func chemistryLookalikes(_ line: String) -> String {
        var r = line
        r = r.replacingOccurrences(of: #"(?<![A-Za-z0-9])c(?=[O0]\d)"#, with: "C", options: .regularExpression)
        r = r.replacingOccurrences(of: #"(?<![A-Za-z0-9])cl(?![A-Za-z])"#, with: "Cl", options: .regularExpression)
        // 개수 1은 쓰지 않으니 원소 기호 뒤 1은 l ("C1" → "Cl")
        r = r.replacingOccurrences(of: #"(?<![A-Za-z0-9])C1(?![0-9])"#, with: "Cl", options: .regularExpression)
        r = r.replacingOccurrences(of: #"(?<![A-Za-z0-9.,])0(?=[A-Z]|\d?[+\-−](?![\d])|\d(?![\d.,]))"#, with: "O", options: .regularExpression)
        r = r.replacingOccurrences(of: #"(?<=[A-Z]|[A-Z][a-z])z(?![A-Za-z])"#, with: "2", options: .regularExpression)
        r = r.replacingOccurrences(of: #"(?<=[A-Z]),(?=[A-Z])"#, with: "2", options: .regularExpression)
        r = r.replacingOccurrences(of: #"(?<=[A-Z]|[A-Z][a-z])['’}`](?=[+\-−])"#, with: "2", options: .regularExpression)
        // 원소 기호 뒤 t는 + ("Nat" → "Na+"), 낱말로 선 것만
        r = r.replacingOccurrences(of: #"(?<![A-Za-z])(Na|K|H|Li|Ag|Cu|NH4)t(?![A-Za-z0-9])"#, with: "$1+", options: .regularExpression)
        // 반응식의 "=" 는 ⇌ (이미 화살표가 없고 + 가 있는 줄)
        if !r.contains("→"), !r.contains("⇌"), r.contains("+"), r.range(of: #"[A-Z][a-z]?\d?\s?\+\s?\d?[A-Z]"#, options: .regularExpression) != nil {
            r = r.replacingOccurrences(of: #"(?<=[A-Za-z0-9₀-₉])\s?=+\s?(?=\d?[A-Z])"#, with: " ⇌ ", options: .regularExpression)
        }
        return r
    }

    static func fixScience(_ line: String) -> String {
        var result = line
        result = result.replacingOccurrences(of: "µ", with: "μ")
        // 위 첨자 2를 ?, ', ° 로 읽은 단위 ("m/s'" → "m/s²")
        result = result.replacingOccurrences(of: #"(?<![A-Za-z])m/s['’°"](?![A-Za-z0-9])"#, with: "m/s²", options: .regularExpression)
        if line.contains(where: { "①②③④⑤".contains($0) }) {
            result = result.replacingOccurrences(of: #"(?<![A-Za-z])m/s\?(?=\s|$)"#, with: "m/s²", options: .regularExpression)
        }
        result = result.replacingOccurrences(of: "시간(S)", with: "시간(s)")
        // 기호 모양 통일
        result = result.replacingOccurrences(of: "℃", with: "°C")
        result = result.replacingOccurrences(of: #"(?<=\d)\s?[º˚]\s?C(?![A-Za-z])"#, with: " °C", options: .regularExpression)
        result = result.replacingOccurrences(of: #"(?<=\d)\s?°\s?[cC](?![A-Za-z])"#, with: " °C", options: .regularExpression)
        result = result.replacingOccurrences(of: #"(?<=\d) ?o ?C(?![A-Za-z])"#, with: " °C", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s?(?:<-+>|<=>|⇄|⇋)\s?"#, with: " ⇌ ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s?(?<!<)(?:-|—|–|=)+>\s?"#, with: " → ", options: .regularExpression)
        result = result.replacingOccurrences(of: "△", with: "Δ")
        // Δ를 A로 읽은 것: "AH < 0", "AT = 5"
        result = result.replacingOccurrences(of: #"(?<![A-Za-z])A([HTtEV])(?=\s?[<>=≤≥])"#, with: "Δ$1", options: .regularExpression)
        // 단위
        result = result.replacingOccurrences(of: #"(?<![A-Za-z])m/\$"#, with: "m/s", options: .regularExpression)
        result = result.replacingOccurrences(of: #"(?<![A-Za-z])[Il|]?(k?m)[l|I]([sh])(?![A-Za-z])"#, with: "$1/$2", options: .regularExpression)
        // 위 첨자 3을 ', ), ° 로 읽은 단위 ("g/cm'" → "g/cm³")
        result = result.replacingOccurrences(of: #"(?<![A-Za-z])(g|kg)/(c?m)['’)°](?![A-Za-z0-9])"#, with: "$1/$2³", options: .regularExpression)
        // 짝짓기 보기의 겹친 줄표 "밀도 - -g/cm³"
        result = result.replacingOccurrences(of: #"(?<=\s)- ?-(?=\S)"#, with: "- ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"(?<![A-Za-z])m/s\^?2(?![0-9])"#, with: "m/s²", options: .regularExpression)
        result = result.replacingOccurrences(of: #"(?<![A-Za-z])(g|kg)/(c?m)\^?3(?![0-9])"#, with: "$1/$2³", options: .regularExpression)
        result = result.replacingOccurrences(of: #"(?<=\d)(\s?)([kcm]?m)\^?2(?![0-9A-Za-z])"#, with: "$1$2²", options: .regularExpression)
        result = result.replacingOccurrences(of: #"(?<=\d)(\s?)([kcm]?m)\^?3(?![0-9A-Za-z])"#, with: "$1$2³", options: .regularExpression)
        // Ω를 Q로, μ를 u로 읽은 것 (숫자 뒤 단위 자리에서만)
        result = result.replacingOccurrences(of: #"(?<=\d)(\s?)(k|M)?Q(?![A-Za-z])"#, with: "$1$2Ω", options: .regularExpression)
        result = result.replacingOccurrences(of: #"(?<=\d)(\s?)u([mAgLs])(?![A-Za-z])"#, with: "$1μ$2", options: .regularExpression)
        // 저항 문제에서 Ω를 2로 읽은 것: "저항이 10 2인" → "10 Ω인"
        if line.contains("저항") {
            result = result.replacingOccurrences(of: #"(?<=\d) (?:2|Q|O)(?=[인의이을짜])"#, with: " Ω", options: .regularExpression)
        }
        // 보기 값 "5 V"의 5를 S로 읽은 것
        result = result.replacingOccurrences(of: #"(?<=[①②③④⑤] )S ?(V|A|W|J|N|g|kg|mm|cm|m|mL|L)(?![A-Za-z])"#, with: "5 $1", options: .regularExpression)
        return fixFormulas(result)
    }

    /// 화학식 숫자 → 아래 첨자, 이온 전하 → 위 첨자 ("H2O" → "H₂O", "C02" → "CO₂", "Ca2+" → "Ca²⁺", "SO42-" → "SO₄²⁻")
    static func fixFormulas(_ line: String) -> String {
        guard line.contains(where: { $0.isASCII && $0.isUppercase }) else { return line }
        // 전하 + 뒤에 다른 화학식이 오면 반응식의 + ("N2+ 3H2")
        let pattern = #"(?<![A-Za-z0-9₀-₉])(\d{0,2})([A-Z(][A-Za-z0-9()]*?)(\d?[+\-−](?!\s*\d*[A-Z(]))?(?![A-Za-z0-9])(?![+\-−][A-Za-z0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return line }
        let ns = line as NSString
        var result = line
        for m in regex.matches(in: line, range: NSRange(location: 0, length: ns.length)).reversed() {
            let coefficient = ns.substring(with: m.range(at: 1))
            let body = ns.substring(with: m.range(at: 2))
            let charge = m.range(at: 3).location == NSNotFound ? "" : ns.substring(with: m.range(at: 3))
            guard let formatted = formula(body, charge: charge), let range = Range(m.range, in: result) else { continue }
            result.replaceSubrange(range, with: coefficient + formatted)
        }
        return result
    }

    /// 화학식 하나를 첨자로 (화학식이 아니거나 바뀔 게 없으면 nil)
    static func formula(_ body: String, charge rawCharge: String) -> String? {
        // 원소 · 괄호 · 개수로 나누기 (개수 자리의 0은 O)
        enum Part { case element(String), open, close, count(String) }
        var parts: [Part] = []
        let chars = Array(body)
        var i = 0
        var zeroFixed = false
        while i < chars.count {
            let c = chars[i]
            if c == "(" { parts.append(.open); i += 1; continue }
            if c == ")" { parts.append(.close); i += 1; continue }
            if c.isUppercase || (c == "0" && i > 0) {
                let letter: Character = c == "0" ? "O" : c
                // "AI" → Al (A는 원소가 아님)
                if c == "A", i + 1 < chars.count, chars[i + 1] == "I" { parts.append(.element("Al")); i += 2; zeroFixed = true; continue }
                if c == "0" { zeroFixed = true }
                if i + 1 < chars.count, chars[i + 1].isLowercase, elements.contains(String(letter) + String(chars[i + 1])) {
                    parts.append(.element(String(letter) + String(chars[i + 1])))
                    i += 2
                } else if elements.contains(String(letter)) {
                    parts.append(.element(String(letter)))
                    i += 1
                } else {
                    return nil
                }
                continue
            }
            // 개수 1은 쓰지 않음 → 원소 기호의 l ("C1" → Cl)
            if c == "1", case .element(let e)? = parts.last, e.count == 1, elements.contains(e + "l"),
               !(i + 1 < chars.count && chars[i + 1].isNumber) {
                parts[parts.count - 1] = .element(e + "l")
                zeroFixed = true
                i += 1
                continue
            }
            if c.isNumber {
                // 개수: 0으로 시작하지 않음. "20"처럼 0으로 끝나는 두 자리는 개수 + O (단, 10은 개수)
                var digits = String(c)
                if i + 1 < chars.count, chars[i + 1].isNumber, chars[i + 1] != "0" || c == "1" { digits.append(chars[i + 1]) }
                guard c != "0" else { return nil }
                if case .count = parts.last { return nil }
                guard !parts.isEmpty else { return nil }
                parts.append(.count(digits))
                i += digits.count
                continue
            }
            return nil
        }
        let elementCount = parts.filter { if case .element = $0 { return true } else { return false } }.count
        guard elementCount >= 1 else { return nil }
        var charge = rawCharge
        // 전하 앞 숫자: 원소 하나짜리 이온("Ca2+", "O2-")이나 개수 뒤("SO42-", "CO32-")면 전하,
        // 여러 원소 이온의 마지막 원소 바로 뒤("NH4+", "NO3-")면 그 원소의 개수
        if charge.count == 2, case .element? = parts.last, !(elementCount == 1 && parts.count == 1) {
            parts.append(.count(String(charge.prefix(1))))
            charge = String(charge.suffix(1))
        }
        let plain = parts.map { part -> String in
            switch part {
            case .element(let e): return e
            case .open: return "("
            case .close: return ")"
            case .count(let d): return d
            }
        }.joined()
        let hasCount = parts.contains { if case .count = $0 { return true } else { return false } }
        // 화학식으로 볼 때: 원소 둘 이상, 또는 H₂·O₂ 같은 분자, 또는 이온
        guard elementCount >= 2 || molecules.contains(plain) || (!charge.isEmpty && elementCount >= 1) else { return nil }
        guard hasCount || !charge.isEmpty || zeroFixed else { return nil }
        // 바뀐 게 없는 낱말 같은 것("He", "I")은 건너뜀
        var out = ""
        for part in parts {
            switch part {
            case .element(let e): out += e
            case .open: out += "("
            case .close: out += ")"
            case .count(let d): out += String(d.compactMap { subscripts[$0] })
            }
        }
        if !charge.isEmpty {
            // "1+"는 그냥 "+"
            let sign = charge.last!
            let number = charge.dropLast()
            out += (number == "1" ? "" : String(number.compactMap { superscripts[$0] })) + String(superscripts[sign] ?? sign)
        }
        return out == body + rawCharge ? nil : out
    }
}
