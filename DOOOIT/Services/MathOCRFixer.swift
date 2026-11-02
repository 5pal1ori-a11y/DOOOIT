import Foundation

/// 기기 안 글자 인식이 기울어진 수식 문자(x, y, a, b)를 숫자로 착각하는 대표 패턴을 바로잡음
/// (한국 수학 문제 문장에서 거의 항상 맞는 규칙만 사용)
enum MathOCRFixer {
    private static let rules: [(pattern: String, template: String)] = [
        // J= / V= → y=
        (#"(^|[^A-Za-z0-9])[JV](\s*=)"#, "$1y$2"),
        // J축, V축 → y축 / 2축 → x축
        (#"[JV]축"#, "y축"),
        (#"(^|[^0-9])2축"#, "$1x축"),
        // 실수 0, 6 / 상수 0, 6 → 실수 a, b
        (#"(실수|상수|자연수|정수)\s*[0oO]\s*,\s*[6bB](\s*에)"#, "$1 a, b$2"),
        // a+6의 값 / 0+6의 값 → a+b의 값
        (#"[a0oO]\s*\+\s*6(\s*의\s*값)"#, "a+b$1"),
        (#"[a0oO]\s*-\s*6(\s*의\s*값)"#, "a-b$1"),
        (#"[a0oO]\s*[x×]\s*6(\s*의\s*값)"#, "ab$1"),
        // 3ax + 6의 그래프 → 3ax + b의
        (#"(ax\s*\+\s*)6(\s*의)"#, "$1b$2"),
        // 함수 이름: sln, s1n → sin / c0s → cos / l0g, 1og → log / Iim, 1im → lim
        (#"(^|[^A-Za-z])s[l1]n(?=[^A-Za-z]|$)"#, "$1sin"),
        (#"(^|[^A-Za-z])c0s(?=[^A-Za-z]|$)"#, "$1cos"),
        (#"(^|[^A-Za-z])(?:l0g|1og|I0g|Iog)(?=[^A-Za-z]|$)"#, "$1log"),
        (#"(^|[^A-Za-z])(?:Iim|1im)(?=[^A-Za-z]|$)"#, "$1lim"),
        // 0|차함수, 01차함수 → 이차함수
        (#"(?:0\||01|0l)차"#, "이차"),
        // 한글 사이에 낀 0| → 이 (예: 넓0|, 길0|)
        (#"(?<=[가-힣])0\|"#, "이"),
        // = 0이 → = 001, = 00| (예: "-20=001 정수인" → "-20=0이 정수인")
        (#"(=\s*-?\d+?)(?:01|0\||0l)(?=\s*[가-힣])"#, "$1이"),
        // 상수 0, 6, c / 실수 0의 값 / 2에 대한 항등식
        (#"(실수|상수)\s*[0oO]\s*,\s*[6bB]\s*,\s*[cCe]"#, "$1 a, b, c"),
        (#"(실수|상수)\s*[0oO](\s*의\s*값)"#, "$1 a$2"),
        (#"(^|\s)2(에\s*대한)"#, "$1x$2"),
        // J의 값 / J는 → y
        (#"(^|[^A-Za-z])J(?=\s*[의에는은이가와])"#, "$1y"),
        // 두 근 x1, x2 / α1, α2 는 첨자 (지수로 바꾸기 전에 먼저)
        (#"(^|[^A-Za-z])([xyab])1\s*,\s*\2\s*2(?![0-9])"#, "$1$2₁, $2₂"),
        (#"(^|[^A-Za-z])([xyab])1(?![0-9])"#, "$1$2₁"),
        // 변수·괄호 바로 뒤 2, 3, 4 → 지수 (x2+1 → x²+1, (x+1)2 → (x+1)²)
        (#"(^|[^A-Za-z])([xyabcnkt])2(?![0-9])"#, "$1$2²"),
        (#"(^|[^A-Za-z])([xyabcnkt])3(?![0-9])"#, "$1$2³"),
        (#"(^|[^A-Za-z])([xyabcnkt])4(?![0-9])"#, "$1$2⁴"),
        (#"\)2(?![0-9])"#, ")²"),
        (#"\)3(?![0-9])"#, ")³"),
        // 루트: V5, V(…) → √5, √(…)
        (#"(^|[^A-Za-z])V(?=\d|\()"#, "$1√"),
        // 부등호·기호
        (#"<="#, "≤"),
        (#">="#, "≥"),
        (#"!="#, "≠"),
        (#"\+-"#, "±"),
        (#"ß"#, "β"),
        // 선택지 (1) -11 → ① -11 (줄 처음이나 공백 뒤에서만)
        (#"(^|\s)\(1\)(?=\s*[-+−√0-9a-z])"#, "$1①"),
        (#"(^|\s)\(2\)(?=\s*[-+−√0-9a-z])"#, "$1②"),
        (#"(^|\s)\(3\)(?=\s*[-+−√0-9a-z])"#, "$1③"),
        (#"(^|\s)\(4\)(?=\s*[-+−√0-9a-z])"#, "$1④"),
        (#"(^|\s)\(5\)(?=\s*[-+−√0-9a-z])"#, "$1⑤"),
        // 극한 x-1 → x→1 (lim 뒤에서만)
        (#"(lim\s*[a-z])\s*-\s*>?\s*"#, "$1→")
    ]

    /// 목록에 보일 제목: 첫 줄에서 수식 부분이 나오기 전까지의 한글 문장만 (예: "이차함수 3/= 202+" → "이차함수")
    static func title(from text: String) -> String? {
        for line in text.split(separator: "\n") {
            let cleaned = line.replacingOccurrences(of: "|", with: " ").trimmingCharacters(in: .whitespaces)
            var words: [Substring] = []
            for word in cleaned.split(separator: " ") {
                let isKorean = word.unicodeScalars.allSatisfy { (0xAC00...0xD7A3).contains($0.value) || ",.?".unicodeScalars.contains($0) }
                if !isKorean { break }
                words.append(word)
            }
            let title = words.joined(separator: " ")
            if title.count >= 2 { return String(title.prefix(24)) }
        }
        return nil
    }

    /// 숫자 자리에 끼어든 비슷한 글자 → 숫자 (Z→2, O→0, l·I·|→1, S→5, B→8)
    private static let digitRules: [(pattern: String, template: String)] = [
        // 숫자 옆의 Z: 2Z → 22, Z3 → 23, 1Z+ → 12+
        (#"(?<=[0-9])Z|Z(?=[0-9])"#, "2"),
        // 계수 자리: Zx, -Zy, (Za → 2x, -2y, (2a
        (#"(^|[\s+\-−=×÷(,])Z(?=[xyabk(√])"#, "$12"),
        // 변수·괄호 뒤의 Z/z: xZ, (x+1)Z → x2, (x+1)2 (뒤에서 x², (x+1)² 로 바뀜)
        (#"(?<=[xyab)])[Zz](?![A-Za-z가-힣])"#, "2"),
        // 식 안에 홀로 있는 Z: + Z, = Z, (Z) → 2
        (#"(?<=[+\-−=×÷(]\s?)Z(?=\s?[+\-−=×÷),]|\s*$)"#, "2"),
        // 지수 자리: x^Z → x^2
        (#"(?<=\^)[Zz]"#, "2"),
        // 숫자 사이의 O, l, I, |, S, B
        (#"(?<=[0-9])[Oo](?=[0-9])"#, "0"),
        (#"(?<=[0-9.])[lI|](?=[0-9])"#, "1"),
        (#"(?<=[0-9])S(?=[0-9])"#, "5"),
        (#"(?<=[0-9])B(?=[0-9])"#, "8"),
        // 숫자 뒤 바로 O+연산자 (예: 1O+ → 10+)
        (#"(?<=[0-9])[Oo](?=\s*[+\-−=×÷)])"#, "0")
    ]

    /// 수식 글자 a, b, x와 지수 ²를 숫자·기호로 잘못 읽은 것 되돌리기
    private static let letterRules: [(pattern: String, template: String)] = [
        // 0x → ax (계수 0은 쓰지 않으니 a), 06 → ab, 0b → ab, a6 → ab
        (#"(?<![0-9.])0(?=[xy](?![a-z]))"#, "a"),
        (#"(?<![0-9.])06(?![0-9.])"#, "ab"),
        (#"(?<![0-9.A-Za-z])0b(?![a-z])"#, "ab"),
        (#"(?<![A-Za-z])a6(?![0-9.])"#, "ab"),
        // 곱셈 기호로 읽힌 x: 2×+3, 3×², ×=2 → x
        (#"(?<=[0-9])×(?=\s*[+\-−=)<>≤≥]|\s*$)"#, "x"),
        (#"×(?=[²³⁴])"#, "x"),
        (#"(^|[\s(=+\-−,])×(?=\s*[+\-−=)<>]|[²³])"#, "$1x"),
        // 대문자 X, 그리스 χ → x
        (#"(?<=[0-9+\-−=(\s])[Xχ](?=[0-9²³+\-−=)\s<>]|$)"#, "x"),
        // 지수가 ' ° ’ ? " ” * 로 읽힘: x' → x², a° → a²
        (#"(?<![A-Za-z])([xyab])[°'’?"”*](?![0-9A-Za-z])"#, "$1²"),
        // 지수 숫자가 빠진 ^: x^ + 1 → x² + 1
        (#"(?<![A-Za-z])([xyab)])\^(?=\s*[+\-−=)<>]|\s*$)"#, "$1²"),
        // 이차식인데 첫 항 지수 2가 9 로 읽힘: x9 - 5x → x² - 5x (x9 는 거의 안 씀)
        (#"(?<![A-Za-z0-9])([xy])9(?=\s*[+\-−=])"#, "$1²"),
        // 지수 2가 떨어져 읽힘: x 2 + → x² +
        (#"(?<![A-Za-z])([xy])\s2(?=\s*[+\-−=)<>]|\s*$)"#, "$1²"),
        // a, b 를 α, β로 읽은 경우 (두 근 α, β 문제가 아니면)
        (#"(실수|상수|자연수|정수)\s*α\s*,\s*β"#, "$1 a, b")
    ]

    /// 복소수 문제에서는 z가 변수: "복소수 2 = 3+4i" 처럼 z를 2로 읽은 것을 되돌림
    private static let complexRules: [(pattern: String, template: String)] = [
        (#"복소수\s*2(?=\s*[=에의는가를와,])"#, "복소수 z"),
        (#"(^|[\s,(])2(\s*=\s*[^=\n]*[0-9)]\s*i)"#, "$1z$2"),
        (#"(^|[\s(])2(\s*[+\-]\s*2̄|̄)"#, "$1z$2"),
        (#"(^|[\s(])2(?=의\s*켤레|\s*의\s*켤레|z̄)"#, "$1z"),
        (#"(^|[\s(])Z(?=[\s=+\-)의는가를에]|$)"#, "$1z")
    ]

    // MARK: 분수 (분자·분모가 따로 읽힌 조각)

    struct Fraction: Equatable {
        let text: String
        let box: CGRect
        /// 쓰인 조각 번호 (분자, 분모)
        let used: [Int]
        /// 끼워 넣을 줄 번호
        let host: Int
    }

    /// 글자 인식은 분수를 "분자 줄 / 분모 줄" 두 조각으로 따로 읽음 → 위아래로 붙은 짧은 조각 두 개를 "a/b"로 합침.
    /// 엉뚱하게 합치지 않도록, 두 조각 사이 높이에 문장 줄(host)이 지나가야만 분수로 봄 (Vision 좌표: 아래가 0)
    static func stackedFractions(pieces: [(text: String, box: CGRect)], hosts: [CGRect]) -> [Fraction] {
        func isShort(_ text: String) -> Bool {
            // 보기 번호 "(1)", "2)" 같은 조각은 분수가 아님
            guard !isChoiceMarker(text) else { return false }
            return text.range(of: #"^[0-9a-zA-Z+\-−√π()]{1,7}$"#, options: .regularExpression) != nil
        }
        var used = Set<Int>()
        var result: [Fraction] = []
        let order = pieces.indices.sorted { pieces[$0].box.midY > pieces[$1].box.midY }
        for top in order where !used.contains(top) && isShort(pieces[top].text.trimmingCharacters(in: .whitespaces)) {
            let a = pieces[top].box
            var best: (index: Int, gap: CGFloat)?
            for bottom in order where bottom != top && !used.contains(bottom) && isShort(pieces[bottom].text.trimmingCharacters(in: .whitespaces)) {
                let b = pieces[bottom].box
                guard b.midY < a.midY else { continue }
                let height = max(a.height, b.height)
                guard min(a.height, b.height) * 1.8 >= height, a.width < 0.2, b.width < 0.2 else { continue }
                let gap = a.minY - b.maxY
                guard gap > -height * 0.25, gap < height * 1.2 else { continue }
                let overlap = min(a.maxX, b.maxX) - max(a.minX, b.minX)
                guard overlap >= min(a.width, b.width) * 0.6 else { continue }
                if best == nil || gap < best!.gap { best = (bottom, gap) }
            }
            guard let bottom = best?.index else { continue }
            let b = pieces[bottom].box
            let union = a.union(b)
            // 분수 가운데 높이를 지나가는 문장 줄 (분수 바로 왼쪽이나 오른쪽에 글이 있어야 함)
            let middle = (a.minY + b.maxY) / 2
            guard let host = hosts.indices.first(where: { index in
                let line = hosts[index]
                return line.minY <= middle && line.maxY >= middle
                    && union.minX >= line.minX - 0.03 && union.maxX <= line.maxX + 0.08
                    && !(line.minX >= union.minX - 0.005 && line.maxX <= union.maxX + 0.005)
            }) else { continue }
            func wrap(_ raw: String) -> String {
                let t = raw.trimmingCharacters(in: .whitespaces)
                return t.count == 1 || t.allSatisfy(\.isNumber) || t.hasPrefix("(") ? t : "(\(t))"
            }
            used.insert(top)
            used.insert(bottom)
            result.append(Fraction(text: wrap(pieces[top].text) + "/" + wrap(pieces[bottom].text), box: union, used: [top, bottom], host: host))
        }
        return result
    }

    // MARK: 보기 번호 ①~⑤

    private static let circledDigits: [Character] = ["①", "②", "③", "④", "⑤"]

    /// 보기 번호처럼 생긴 조각인지 ("①", "(1)", "1)", "(1")
    static func isChoiceMarker(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespaces)
        if t.count == 1, let c = t.first, circledDigits.contains(c) { return true }
        return t.range(of: #"^(\([1-5lIZS]\)?|[1-5]\))$"#, options: .regularExpression) != nil
    }

    /// 글자 인식이 ①~⑤를 다르게 읽은 것 → 원래 번호로.
    /// "(1) 12 (2) 14 (3) 16 (4) 18 (5) 20", "1) 3  2) 5 …", 사이에 낀 "©", "®", "@" 같은 기호까지.
    /// 소문항 (1)(2)와 헷갈리지 않도록 번호가 1부터 차례로 4개 이상이고 보기 내용이 짧을 때만 바꿈
    static func normalizeChoices(_ text: String) -> String {
        if text.filter({ circledDigits.contains($0) }).count >= 4 { return fillCircledGaps(text) }
        // 번호 후보: "(n)", "(n", "n)" (앞은 줄 처음이나 빈칸)
        let pattern = #"(?:^|(?<=[\s,]))(?:\(([1-5lIZS])\)|\(([1-5lIZS])(?=\s)|([1-5])\))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return text }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        func number(_ m: NSTextCheckingResult) -> Int? {
            for group in [1, 2, 3] where m.range(at: group).location != NSNotFound {
                switch ns.substring(with: m.range(at: group)) {
                case "1", "l", "I": return 1
                case "2", "Z": return 2
                case "3": return 3
                case "4": return 4
                case "5", "S": return 5
                default: return nil
                }
            }
            return nil
        }
        // 1부터 차례로 이어지는 가장 긴 줄
        var chain: [(range: NSRange, n: Int)] = []
        for m in matches {
            guard let n = number(m) else { continue }
            if n == (chain.last?.n ?? 0) + 1 { chain.append((m.range, n)) } else if n == 1 { chain = [(m.range, 1)] }
        }
        guard chain.count >= 4, chain.first?.n == 1 else { return fillCircledGaps(text) }
        // 보기 내용이 짧아야 함 (소문항은 "…구하시오" 같은 긴 문장)
        for (i, item) in chain.enumerated() {
            let start = item.range.location + item.range.length
            let end = i + 1 < chain.count ? chain[i + 1].range.location : ns.length
            let content = ns.substring(with: NSRange(location: start, length: max(0, end - start)))
                .components(separatedBy: "\n").first ?? ""
            if content.count > 40 || content.range(of: #"(시오|하라|인가|는가)"#, options: .regularExpression) != nil { return text }
        }
        var result = text
        for item in chain.reversed() {
            guard let range = Range(item.range, in: result) else { continue }
            result.replaceSubrange(range, with: String(circledDigits[item.n - 1]))
        }
        return fillCircledGaps(result)
    }

    /// ①②④⑤처럼 하나가 빠졌는데 그 자리에 "©", "®", "@", "0", "O" 같은 기호가 있으면 빠진 번호로
    private static func fillCircledGaps(_ text: String) -> String {
        var result = text
        for k in 1..<4 {   // 빠진 번호: ②, ③, ④ (양옆 번호가 있을 때)
            let before = circledDigits[k - 1], missing = circledDigits[k], after = circledDigits[k + 1]
            guard !result.contains(missing), let lower = result.firstIndex(of: before),
                  let upper = result[lower...].firstIndex(of: after) else { continue }
            let segment = result[result.index(after: lower)..<upper]
            // 보기 값 뒤 빈칸 다음에 오는 낯선 기호 하나
            if let m = segment.range(of: #"(?<=\s)[©®@Ⓒⓒ®OD](?=\s)"#, options: .regularExpression) {
                result.replaceSubrange(m, with: String(missing))
            }
        }
        return result
    }

    // MARK: 빈칸 □

    /// 빈칸 상자를 다르게 읽은 것 → "□": 口, 사이 빈 괄호·대괄호, 밑줄, 연산 기호 사이에서 빠진 칸
    static func normalizeBlanks(_ text: String) -> String {
        var t = text
        // 한자 口, 네모 기호들
        t = t.replacingOccurrences(of: #"[口☐▢◻⬜]"#, with: "□", options: .regularExpression)
        // 식 안의 낱자 ㅁ (한글 낱말의 일부가 아닐 때)
        t = t.replacingOccurrences(of: #"(?<![가-힣ㄱ-ㅎ])ㅁ(?![가-힣ㄱ-ㅎ])"#, with: "□", options: .regularExpression)
        // [ ], [], (   ) — 식 안이나 "( ) 안에 알맞은" 처럼 빈 괄호
        t = t.replacingOccurrences(of: #"\[\s*\]"#, with: "□", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\(\s{2,}\)|\(\s*\)(?=\s*(안에|에\s*알맞은|[=+\-×÷*/:<>]))|(?<=[=+\-×÷*/:]\s?)\(\s*\)"#, with: "□", options: .regularExpression)
        // 밑줄 빈칸 ___
        t = t.replacingOccurrences(of: #"_{3,}"#, with: "□", options: .regularExpression)
        // 연산 기호 사이에서 빈칸이 통째로 빠진 경우: "3 + = 7" → "3 + □ = 7", "45 ÷ = 9", "3 : 4 = : 20"
        t = t.replacingOccurrences(of: #"([+×÷*/:=])[ \t]*(?=[=×÷*/:]|\+(?!\d))"#, with: "$1 □ ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"([\-−])[ \t]+(?==)"#, with: "$1 □ ", options: .regularExpression)
        // 맨 앞 빈칸: 짧은 식 줄이 연산 기호로 시작 "+ 4 = 9" → "□ + 4 = 9" (긴 식이 줄바꿈된 경우는 제외)
        t = t.replacingOccurrences(of: #"(?m)^([ \t]*)([+×÷*/])[ \t]*(?=\d[^A-Za-z가-힣\n]{0,16}=[^A-Za-z가-힣\n]{0,10}$)"#, with: "$1□ $2 ", options: .regularExpression)
        t = t.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
        return t
    }

    /// 사진에서 찾은 빈 네모 상자 중 글자와 겹치지 않고 문장 줄 높이에 있는 것 → 그 줄에 □를 끼워 넣을 자리
    /// rects: 찾은 상자들, lines: 줄 상자들, letters: 글자 상자들 (모두 Vision 좌표, 아래가 0)
    static func blankBoxes(rects: [CGRect], lines: [CGRect], letters: [CGRect]) -> [(box: CGRect, host: Int)] {
        let heights = lines.map(\.height).sorted()
        guard !heights.isEmpty else { return [] }
        let median = heights[heights.count / 2]
        var result: [(box: CGRect, host: Int)] = []
        for rect in rects {
            // 글자 한두 칸 크기의 네모 (너무 크면 그림·표, 너무 작으면 점)
            guard rect.height >= median * 0.6, rect.height <= median * 2.6,
                  rect.width >= rect.height * 0.6, rect.width <= rect.height * 4 else { continue }
            // 안이 비어 있어야 함 (글자와 겹치면 글자를 감싼 테두리)
            let inner = rect.insetBy(dx: rect.width * 0.15, dy: rect.height * 0.15)
            if letters.contains(where: { $0.intersects(inner) && $0.width < rect.width * 1.5 }) { continue }
            // 높이가 맞는 줄
            guard let host = lines.indices.min(by: { abs(lines[$0].midY - rect.midY) < abs(lines[$1].midY - rect.midY) }),
                  abs(lines[host].midY - rect.midY) <= max(lines[host].height, rect.height) * 0.6 else { continue }
            if result.contains(where: { $0.box.intersects(rect) }) { continue }
            result.append((rect, host))
        }
        return result
    }

    static func fix(_ text: String) -> String {
        var result = normalizeBlanks(text)
        let isComplex = text.contains("복소수") || text.contains("켤레") || text.range(of: #"[0-9)]\s*i(?![a-z])"#, options: .regularExpression) != nil
        for rule in (isComplex ? complexRules : digitRules) {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.anchorsMatchLines]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: rule.template)
        }
        if !isComplex {
            // 복소수 문제가 아니면 숫자 옆 소문자 z도 2
            result = result.replacingOccurrences(of: #"(?<=[0-9])z|z(?=[0-9])"#, with: "2", options: .regularExpression)
        } else {
            // 복소수 문제여도 숫자 사이의 O, l 은 숫자
            for rule in digitRules.suffix(5) {
                guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.anchorsMatchLines]) else { continue }
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: rule.template)
            }
        }
        for rule in letterRules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.anchorsMatchLines]) else { continue }
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: rule.template)
        }
        for rule in rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.anchorsMatchLines]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: rule.template)
        }
        return normalizeChoices(result)
    }
}
