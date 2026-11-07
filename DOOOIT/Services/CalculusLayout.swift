import Foundation

/// 미적분 기호 자리 읽기: ∑ ∫ lim 의 위끝·아래끝을 찾아 ∑_{k=1}^{n}, ∫_a^b, lim_{x→a} 로 다시 붙임
/// (Vision 글자 상자 + 큰 기호 모양만 다루는 순수 계산 → 리눅스 테스트 가능. 사진 자르기 읽기는 OCRCore가 closure로 넣어 줌)
///
/// 원칙: 문맥이 분명할 때만 고침. 기호 자리에 읽힌 글자가 비슷한 모양(E, Z, J, f …)이 아니거나
/// 위·아래끝 조각이 식 모양이 아니면 손대지 않음 (틀리게 고치는 것이 안 고치는 것보다 나빠요)
enum CalculusLayout {
    enum Kind: String { case sigma, integral, limit }

    /// 사진에서 찾아 읽은 기호 하나 (Vision 좌표: 0~1, 왼쪽 아래가 원점)
    struct Finding: Equatable {
        var kind: Kind
        /// 큰 기호(또는 lim 낱말) 상자
        var symbol: CGRect
        /// 바꿀 글 (예: "∑_{k=1}^{10}", "∫", "lim_{x→2}")
        var text: String
        /// 위끝·아래끝을 읽은 자리 (이 안의 작은 조각은 따로 읽힌 줄에서 뺌)
        var regions: [CGRect]
        /// 기호 자리 글자를 못 읽었어도 끼워 넣을 만큼 확실한지 (∑ 는 "k=1" 같은 시작 값이 읽혔을 때)
        var strong: Bool
        /// ∫ 의 위끝·아래끝이 붙어 있는 자리까지의 오른쪽 끝 (글자 인식이 묶어서 읽은 조각을 지울 범위)
        var coverMaxX: CGFloat
    }

    /// 줄 속 글자 범위(글자 단위)를 text 로 바꿈
    struct Edit: Equatable {
        var line: Int
        var range: Range<Int>
        var text: String
    }

    struct Plan: Equatable {
        var edits: [Edit] = []
        /// 위끝·아래끝으로 쓰여서 따로 읽은 줄에서 빼야 하는 줄 번호
        var consumed: Set<Int> = []
        /// 위끝·아래끝 자리 (작은 조각을 지울 자리)
        var regions: [CGRect] = []
        var notes: [String] = []
    }

    // MARK: 기호 자리에 잘못 읽히는 글자

    /// ∑ 자리에 읽히는 글자
    static let sigmaLookalikes: Set<Character> = ["∑", "Σ", "E", "Z", "z", "2", "s", "S", "ε", "Ξ", "≡", "ξ", "€", "£", "M", "L", "K", "m", "4", "5", "3"]
    /// ∫ 자리에 읽히는 글자
    static let integralLookalikes: Set<Character> = ["∫", "ʃ", "J", "j", "f", "S", "s", "I", "l", "|", "[", "]", "(", ")", "{", "}", "/", "1", "5", "$", "&", "⌠", "⌡", "r", "T", "}", "i", "7"]
    /// ∫ 위끝·아래끝이 기호에 붙어 읽힌 찌꺼기
    private static let integralJunk: Set<Character> = ["°", "'", "’", "`", "\"", "”", ",", ".", ":", ";", "-", "−", "~", "*", "^", "_", "•", "·"]

    // MARK: 위끝·아래끝 글자 읽기

    private static func clean(_ raw: String) -> String {
        var t = raw.filter { !$0.isWhitespace }
        t = t.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
        return t
    }

    /// 숫자 자리의 비슷한 글자 → 숫자 (l, I, | → 1 / O, o → 0 / S → 5 / Z → 2 / B → 8)
    private static func digits(_ raw: String) -> String? {
        var out = ""
        for c in raw {
            switch c {
            case "0"..."9": out.append(c)
            case "l", "I", "|", "!": out.append("1")
            case "O", "o": out.append("0")
            case "S": out.append("5")
            case "Z": out.append("2")
            case "B": out.append("8")
            default: return nil
            }
        }
        return out.isEmpty ? nil : out
    }

    private static func isInfinity(_ t: String) -> Bool { ["∞", "oo", "OO", "00", "co", "CO", "ꝏ", "ο", "∞∞"].contains(t) }

    /// ∑ 아래끝: "k=1", "n=1", "i=0", "k=-2" (색인 글자 = 시작 값). 아니면 nil
    static func sigmaBelow(_ raw: String) -> String? {
        let t = clean(raw)
        guard let eq = t.firstIndex(where: { "=＝".contains($0) }) else { return nil }
        let name = String(t[..<eq]), value = String(t[t.index(after: eq)...])
        guard name.count == 1, let n = name.first, n.isLetter, n.isASCII, n.isLowercase || n == "K" || n == "N" || n == "I" else { return nil }
        let variable = String(n).lowercased()
        var v = value
        let negative = v.hasPrefix("-")
        if negative { v.removeFirst() }
        guard let digit = digits(v), digit.count <= 3 else { return nil }
        return "\(variable)=\(negative ? "-" : "")\(digit)"
    }

    /// 위끝(∑·∫)·아래끝(∫): 숫자, 글자 하나, ∞, n+1, 2n, e, π, -1, 1/2 …
    static func bound(_ raw: String) -> String? {
        let t = clean(raw)
        guard !t.isEmpty, t.count <= 6 else { return nil }
        if isInfinity(t) { return "∞" }
        if t == "-∞" || t == "-oo" || t == "-00" { return "-∞" }
        if let d = digits(t), d.count <= 4 { return d }
        if t.hasPrefix("-"), let d = digits(String(t.dropFirst())), d.count <= 3 { return "-" + d }
        if t.range(of: #"^[0-9]{0,2}[a-zA-Zπ]$"#, options: .regularExpression) != nil { return t }
        if t.range(of: #"^[0-9]{0,2}[a-z][+\-][0-9]{1,2}$"#, options: .regularExpression) != nil { return t }
        if t.range(of: #"^[0-9]{0,2}π/[0-9]{1,2}$"#, options: .regularExpression) != nil { return t }
        if t.range(of: #"^[0-9]{1,2}/[0-9]{1,2}$"#, options: .regularExpression) != nil { return t }
        return nil
    }

    /// ∫ 위끝·아래끝을 자른 사진에서 읽은 글: ∫ 줄기·고리가 앞에 J, f, |, ), r 로 읽혀 붙을 수 있어 앞 찌꺼기를 걷어 냄
    static func integralBound(_ raw: String) -> String? {
        var t = clean(raw)
        if let b = bound(t), t.count > 1 || t.first?.isNumber == true { return b }
        // 앞쪽 줄기·고리 찌꺼기 한두 글자 걷기 (뒤에 읽은 것이 숫자·글자 하나일 때만)
        for _ in 0..<2 where t.count >= 2 {
            guard let first = t.first, integralLookalikes.contains(first) || integralJunk.contains(first) || first == "∫" else { break }
            t.removeFirst()
            if t.first == "-", t.count >= 2 { if let b = bound(t) { return b } }
            if let b = bound(t), t.first?.isNumber == true || t.first == "-" { return b }
        }
        return nil
    }

    /// lim 아래끝: "x→2", "x→∞", "n→∞", "h→0", "x→0+", "x→a", "x-2"(화살표를 빼기로 읽음), "x->2". 앞부분만 맞아도 됨 ("x→∞ x2 -3" → x→∞)
    static func limitBelow(_ raw: String) -> String? {
        for candidate in [raw] + raw.split(whereSeparator: { $0.isWhitespace }).map(String.init).prefix(1) {
            if let v = limitBelowWhole(candidate) { return v }
        }
        return nil
    }

    private static func limitBelowWhole(_ raw: String) -> String? {
        let t = clean(raw)
        guard let m = try? NSRegularExpression(pattern: #"^([a-zA-Zθ])(?:→|->|-->|-?>|⟶|-|~)([-+]?)([^-+→]{1,5}?)([-+]?)$"#).firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
              m.numberOfRanges == 5 else { return nil }
        func group(_ i: Int) -> String { Range(m.range(at: i), in: t).map { String(t[$0]) } ?? "" }
        let rawVariable = group(1), sign = group(2), target = group(3), side = group(4)
        // 극한 변수는 소문자 (x 를 X 로 읽은 것 바로잡기), θ 는 그대로
        let variable = rawVariable == "θ" ? rawVariable : rawVariable.lowercased()
        let value: String
        if isInfinity(target) { value = "∞" }
        else if let d = digits(target), d.count <= 3 { value = d }
        else if target.range(of: #"^[0-9]{0,2}[a-zA-Zπ]$"#, options: .regularExpression) != nil { value = target }
        else { return nil }
        // 부호가 앞뒤 모두 있으면 모호함
        guard sign.isEmpty || side.isEmpty else { return nil }
        return "\(variable)→\(sign)\(value)\(side)"
    }

    /// "lim" 낱말이 든 줄 둘레(줄 아래 한 줄 높이까지): 필기 지우기가 극한 아래 x→a 를 풀이로 오인해 지우지 않게 지킬 자리
    static func limitGuardRects(lines: [OCRGlyphLine]) -> [CGRect] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<![A-Za-z])(?:lim|Iim|1im|llm|Ilm|iim|lm|lirn|Iirn|tim|Lim|1imp|limp)(?![A-Za-z])"#) else { return [] }
        return lines.compactMap { line in
            let range = NSRange(line.text.startIndex..., in: line.text)
            guard regex.firstMatch(in: line.text, range: range) != nil else { return nil }
            let b = line.box
            return CGRect(x: b.minX - b.height * 0.5, y: b.minY - b.height * 1.2, width: b.width + b.height, height: b.height * 2.2)
        }
    }

    /// 위끝·아래끝 글을 식에 붙일 모양으로 (한 글자면 중괄호 없이)
    static func script(_ mark: String, _ value: String) -> String {
        value.count == 1 ? "\(mark)\(value)" : "\(mark){\(value)}"
    }

    // MARK: 찾은 기호를 줄에 적용

    /// lines: 한국어 인식 줄 (글자마다 상자 포함), findings: 사진에서 찾아 읽은 기호, lineHeight: 보통 줄 높이(0~1)
    static func plan(lines: [OCRGlyphLine], findings: [Finding], lineHeight: CGFloat) -> Plan {
        var plan = Plan()
        guard lineHeight > 0, !lines.isEmpty else { return plan }
        let chars: [[Character]] = lines.map { Array($0.text) }
        var taken: [(line: Int, range: Range<Int>)] = []

        /// 줄 속 글자 하나의 가로 범위
        func xRange(_ line: Int, _ i: Int) -> ClosedRange<CGFloat>? {
            guard i < lines[line].charBoxes.count, let b = lines[line].charBoxes[i] else { return nil }
            return b.minX...b.maxX
        }

        /// 기호 상자와 같은 높이에서 가로로 이어지는 글 줄 (기호 가운데가 줄 가로 범위 안인 쪽 먼저)
        func hostLine(for a: CGRect) -> Int? {
            func score(_ i: Int) -> CGFloat {
                let b = lines[i].box
                let inside = b.minX - lineHeight * 0.3 <= a.midX && a.midX <= b.maxX + lineHeight * 0.3
                return (inside ? 10 : 0) - abs(b.midY - a.midY)
            }
            return lines.indices.filter { i in
                let b = lines[i].box
                let overlapY = min(b.maxY, a.maxY) - max(b.minY, a.minY)
                return overlapY >= min(b.height, a.height) * 0.4
                    && b.maxX >= a.midX - lineHeight * 0.3 && b.minX <= a.midX + lineHeight * 1.5
                    && lines[i].text.contains(where: { !$0.isWhitespace })
            }.max { score($0) < score($1) }
        }

        for f in findings.sorted(by: { $0.symbol.minX < $1.symbol.minX }) {
            guard let host = hostLine(for: f.symbol) else { continue }
            let a = f.symbol
            var range: Range<Int>?
            switch f.kind {
            case .limit:
                // lim 낱말(글자 인식이 lim, Iim, 1im …으로 읽은 것)
                let string = String(chars[host])
                if let regex = try? NSRegularExpression(pattern: #"(?<![A-Za-z])(?:lim|Iim|1im|llm|Ilm|iim|lm|lirn|Iirn|tim|Lim)(?![A-Za-z])"#) {
                    for m in regex.matches(in: string, range: NSRange(string.startIndex..., in: string)) {
                        guard let sr = Range(m.range, in: string) else { continue }
                        let start = string.distance(from: string.startIndex, to: sr.lowerBound)
                        let end = string.distance(from: string.startIndex, to: sr.upperBound)
                        guard let first = xRange(host, start), let last = xRange(host, end - 1) else { continue }
                        // 이 기호(낱말) 상자와 같은 자리의 낱말인지
                        if abs((first.lowerBound + last.upperBound) / 2 - a.midX) <= max(a.width, lineHeight) * 0.6 { range = start..<end; break }
                    }
                }
            case .sigma, .integral:
                let lookalikes = f.kind == .sigma ? sigmaLookalikes : integralLookalikes
                let maxX = f.kind == .integral ? max(a.maxX, f.coverMaxX) : a.maxX
                let minX = a.minX - a.width * 0.1
                var near: [Int] = []
                for i in chars[host].indices where !chars[host][i].isWhitespace {
                    guard let r = xRange(host, i) else { continue }
                    let mid = (r.lowerBound + r.upperBound) / 2
                    if mid >= minX, mid <= maxX + (f.kind == .sigma ? a.width * 0.1 : 0) { near.append(i) }
                }
                // 기호 자리에 읽힌 글자: 비슷한 모양 글자 하나(∫ 는 위끝·아래끝 찌꺼기까지) 일 때만 바꿈
                let symbolLike = near.filter { lookalikes.contains(chars[host][$0]) }
                if f.kind == .sigma {
                    if symbolLike.count == 1, near.count <= 2 { range = symbolLike[0]..<(symbolLike[0] + 1) }
                    else if f.strong, symbolLike.isEmpty {
                        // "k=1" 같은 시작 값이 읽혀 ∑ 가 확실한데 기호 자리에 엉뚱한 글자(n, 9, 한 글자)가 읽힌 경우: 기호 상자 안에 든 글자 하나만 바꿈
                        let inside = near.filter { i in
                            guard let r = xRange(host, i) else { return false }
                            let mid = (r.lowerBound + r.upperBound) / 2
                            return mid >= a.minX - a.width * 0.15 && mid <= a.maxX + a.width * 0.15 && chars[host][i].isASCII
                        }
                        if inside.count == 1 { range = inside[0]..<(inside[0] + 1) }
                    }
                } else if let first = symbolLike.first {
                    // ∫: 첫 비슷한 글자부터 기호 오른쪽 끝(위끝·아래끝 자리)까지의 찌꺼기 글자
                    var last = first
                    for i in near where i > first && (integralJunk.contains(chars[host][i]) || chars[host][i].isNumber || lookalikes.contains(chars[host][i])) { last = i }
                    range = first..<(last + 1)
                }
                if range == nil, near.isEmpty, f.strong || f.kind == .integral {
                    // 글자가 아예 안 읽힘 → 기호 오른쪽 첫 글자 앞에 끼워 넣음
                    var at = 0
                    var best: CGFloat = -1
                    for i in chars[host].indices where !chars[host][i].isWhitespace {
                        guard let r = xRange(host, i), r.upperBound <= a.minX + a.width * 0.2, r.upperBound > best else { continue }
                        best = r.upperBound
                        at = i + 1
                    }
                    range = at..<at
                }
            }
            guard let range else { continue }
            if taken.contains(where: { $0.line == host && $0.range.overlaps(range) }) { continue }
            // ∫ 는 기호를 직접 읽었거나 뒤에 d변수가 있을 때만 (괄호·막대를 ∫ 로 잘못 보지 않게)
            if f.kind == .integral {
                let readExact = range.contains { chars[host][$0] == "∫" || chars[host][$0] == "ʃ" }
                guard readExact || f.strong || hasDifferential(chars, host: host, after: range.upperBound, lines: lines) else { continue }
            }
            plan.edits.append(Edit(line: host, range: range, text: f.text))
            taken.append((host, range))
            plan.regions += f.regions
            plan.notes.append("\(f.kind.rawValue) \(f.text) 줄\(host)")
            // 위끝·아래끝 자리에서 따로 읽힌 작은 조각은 빼기
            for i in lines.indices where i != host {
                let b = lines[i].box
                guard b.height <= lineHeight * 1.1, lines[i].text.count <= 10, !hasHangul(lines[i].text) else { continue }
                if f.regions.contains(where: { $0.insetBy(dx: -$0.width * 0.05, dy: -$0.height * 0.05).contains(CGPoint(x: b.midX, y: b.midY)) }) { plan.consumed.insert(i) }
            }
        }
        return plan
    }

    /// 기호 뒤(같은 줄·이어지는 줄)에 dx, dt 같은 미분이 있는지
    private static func hasDifferential(_ chars: [[Character]], host: Int, after: Int, lines: [OCRGlyphLine]) -> Bool {
        var rest = after < chars[host].count ? String(chars[host][after...]) : ""
        // 같은 높이 오른쪽에 따로 읽힌 줄
        for i in lines.indices where i != host {
            let b = lines[i].box, h = lines[host].box
            if min(b.maxY, h.maxY) - max(b.minY, h.minY) >= min(b.height, h.height) * 0.5, b.minX >= h.midX { rest += " " + lines[i].text }
        }
        return rest.range(of: #"(?<![A-Za-z])d\s?[xytrchka](?![A-Za-z])"#, options: .regularExpression) != nil
    }
}

private func hasHangul(_ s: String) -> Bool {
    s.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) || (0x3131...0x318E).contains($0.value) }
}
