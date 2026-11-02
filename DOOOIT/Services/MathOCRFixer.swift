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
        // 괄호 뒤 지수가 띄어 읽힘: (x+3) 2 = → (x+3)² =
        (#"\)\s2(?=\s*[=+\-−<>])"#, ")²"),
        // 루트: V5, V(…) → √5, √(…) / 작은 v, ~ 로 읽힌 √: 2v3, 4~3, ~2 → 2√3, 4√3, √2
        (#"(^|[^A-Za-z])V(?=\d|\()"#, "$1√"),
        (#"(^|[0-9\s(=+\-−×÷,①②③④⑤])v(?=[0-9])"#, "$1√"),
        (#"(^|[0-9\s(=+\-−×÷,①②③④⑤])~(?=[0-9])"#, "$1√"),
        // 숫자 사이 띄어 쓴 x 는 곱셈: 0.3 x 0.4 → 0.3 × 0.4
        (#"(?<=[0-9])\s+x\s+(?=[0-9])"#, " × "),
        // 계수 뒤 x 를 r, * 로 읽음: 2r- 3, 3*- 1 → 2x- 3, 3x- 1
        (#"(?<=[0-9])[r*](?=\s*[+\-−=<>)])"#, "x"),
        // 영어 문장의 대문자 I 를 l 로 읽음: "l am" → "I am"
        (#"(^|[①②③④⑤]\s?|[.?!]\s)l(?=\s[a-z])"#, "$1I"),
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
        let text = bareNumberChoices(text)
        if text.filter({ circledDigits.contains($0) }).count >= 4 { return text }
        // 번호 후보: "(n)", "(n", "n)" (앞은 줄 처음이나 빈칸)
        let pattern = #"(?:^|(?<=[\s,]))(?:\(([1-5lIZSD])\)|\(([1-5lIZSD])(?=\s)|([1-5])\))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return text }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        func number(_ m: NSTextCheckingResult) -> Int? {
            for group in [1, 2, 3] where m.range(at: group).location != NSNotFound {
                switch ns.substring(with: m.range(at: group)) {
                case "1", "l", "I", "D": return 1
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

    // MARK: 글줄 기울기

    /// 글줄 상자(네 꼭짓점, Vision 좌표 0~1·아래가 0)들의 기울기 (도, 반시계 +). 고칠 만큼 기울지 않았거나 모르면 nil
    /// width, height: 사진 픽셀 크기 (가로·세로 비율을 맞추려고)
    static func skewAngle(quads: [(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint)],
                          width: Double, height: Double) -> Double? {
        var samples: [(angle: Double, weight: Double)] = []
        for q in quads {
            let dx = Double(q.topRight.x - q.topLeft.x) * width, dy = Double(q.topRight.y - q.topLeft.y) * height
            let dx2 = Double(q.bottomRight.x - q.bottomLeft.x) * width, dy2 = Double(q.bottomRight.y - q.bottomLeft.y) * height
            let length = hypot(dx, dy)
            let side = hypot(Double(q.topLeft.x - q.bottomLeft.x) * width, Double(q.topLeft.y - q.bottomLeft.y) * height)
            // 글자 서너 개 이상인 가로로 긴 줄만 (짧은 조각은 기울기가 부정확)
            guard length > side * 3, length > 40, dx > 0, dx2 > 0 else { continue }
            let angle = (atan2(dy, dx) + atan2(dy2, dx2)) / 2 * 180 / .pi
            guard abs(angle) < 15 else { continue }
            samples.append((angle, length))
        }
        guard samples.count >= 2 else { return nil }
        // 길이로 무게를 준 가운데 값
        let sorted = samples.sorted { $0.angle < $1.angle }
        let total = sorted.reduce(0) { $0 + $1.weight }
        var running = 0.0
        var median = sorted[0].angle
        for s in sorted {
            running += s.weight
            if running >= total / 2 { median = s.angle; break }
        }
        // 줄들이 같은 쪽으로 비슷하게 기울어야 함 (무게의 절반 이상이 가운데 값 ±1° 안)
        let agreeing = sorted.filter { abs($0.angle - median) <= 1 }.reduce(0) { $0 + $1.weight }
        guard agreeing >= total * 0.5, abs(median) >= 0.5 else { return nil }
        return median
    }

    // MARK: 보기 번호 동그라미 (사진에서 직접 찾기)

    /// 사진 속 윤곽선 하나의 모양 (글자 인식이 ①~⑤를 아예 못 읽거나 "1", "@", "(D"로 읽을 때 대신 찾음)
    struct Shape {
        /// Vision 좌표 (0~1, 아래가 0)
        var box: CGRect
        /// 가로/세로 (픽셀 기준)
        var aspect: Double
        /// 윤곽 넓이 / 상자 넓이 (원 ≈ 0.785, 네모 ≈ 1)
        var fill: Double
        /// 안쪽 윤곽들의 상자 (바깥 상자를 0~1로 본 좌표, 가로/세로는 픽셀 비율)
        var inner: [CGRect]
    }

    /// 동그라미 번호(①, ❶)처럼 생겼는지: 동그란 바깥 + 가운데 숫자 모양 안쪽
    /// lineHeight: 글자 줄 높이 (Vision 좌표)
    static func isChoiceCircle(_ shape: Shape, lineHeight: CGFloat) -> Bool {
        guard lineHeight > 0,
              shape.box.height >= lineHeight * 0.5, shape.box.height <= lineHeight * 1.7,
              shape.aspect >= 0.82, shape.aspect <= 1.22,
              shape.fill >= 0.66, shape.fill <= 0.88 else { return false }
        func centered(_ r: CGRect) -> Bool { abs(r.midX - 0.5) <= 0.2 && abs(r.midY - 0.5) <= 0.2 }
        // 숫자: 가운데, 바깥의 30~72% 높이, 세로로 긴 모양 (ㅇ·O의 둥근 구멍과 구별)
        let digits = shape.inner.filter { centered($0) && $0.height >= 0.28 && $0.height <= 0.72 && $0.width <= $0.height * 0.88 && $0.width >= $0.height * 0.12 }
        guard !digits.isEmpty else { return false }
        // 테두리만 있는 ①: 둥근 큰 구멍 안에 숫자. 속이 찬 ❶: 큰 구멍 없이 숫자 모양 구멍
        let holes = shape.inner.filter { centered($0) && $0.height >= 0.62 && $0.width >= $0.height * 0.8 && $0.width <= $0.height * 1.25 }
        if let hole = holes.max(by: { $0.height < $1.height }) {
            return digits.contains { $0.height <= hole.height * 0.82 }
        }
        return shape.aspect >= 0.88 && shape.aspect <= 1.14
    }

    /// 상자들을 같은 줄끼리 묶음 (위 줄부터, 줄 안은 왼쪽부터)
    static func rows(_ boxes: [CGRect]) -> [[Int]] {
        let order = boxes.indices.sorted { boxes[$0].midY > boxes[$1].midY }
        var rows: [[Int]] = []
        for i in order {
            let b = boxes[i]
            if let r = rows.indices.last(where: { r in
                rows[r].contains { j in
                    let o = boxes[j]
                    let overlap = min(o.maxY, b.maxY) - max(o.minY, b.minY)
                    return overlap >= min(o.height, b.height) * 0.5
                }
            }) {
                rows[r].append(i)
            } else {
                rows.append([i])
            }
        }
        return rows.map { $0.sorted { boxes[$0].minX < boxes[$1].minX } }
    }

    /// 찾은 동그라미들에 번호 매기기: 읽는 순서(위→아래, 왼→오른)대로 1, 2, 3…
    /// 5개를 넘거나 줄 사이가 크게 벌어지면 다음 문제의 보기로 보고 1부터 다시. 3개 미만인 묶음은 번호가 아님(0)
    /// anchors: 글자 인식이 이미 읽은 번호 (동그라미 순서 → 번호), 묶음의 시작 번호를 맞출 때 씀
    static func numberCircles(_ boxes: [CGRect], lineHeight: CGFloat, anchors: [Int: Int] = [:]) -> [Int] {
        var numbers = Array(repeating: 0, count: boxes.count)
        var groups: [[Int]] = []
        var lastRowY: CGFloat?
        for row in rows(boxes) {
            let y = row.map { boxes[$0].midY }.reduce(0, +) / CGFloat(row.count)
            let far = lastRowY.map { $0 - y > lineHeight * 5 } ?? true
            if far || groups.isEmpty { groups.append([]) }
            for i in row {
                if groups[groups.count - 1].count >= 5 { groups.append([]) }
                groups[groups.count - 1].append(i)
            }
            lastRowY = y
        }
        for group in groups where group.count >= 3 {
            // 이미 읽은 번호가 있으면 그 번호에 맞춰 시작 번호를 정함 (모두 같은 시작을 가리킬 때만)
            let starts = Set(group.enumerated().compactMap { k, i in anchors[i].map { $0 - k } })
            let start = starts.count == 1 ? starts.first! : 1
            guard start >= 1, start + group.count - 1 <= 5 else { continue }
            for (k, i) in group.enumerated() { numbers[i] = start + k }
        }
        return numbers
    }

    /// 한 줄에 띄어서 놓인 조각들이 보기 줄인지 (두 단 편집의 긴 문장끼리는 합치지 않음)
    static func isChoiceRow(_ texts: [String]) -> Bool {
        guard texts.count >= 2 else { return false }
        if texts.contains(where: { $0.contains(where: { circledDigits.contains($0) }) || isChoiceMarker(String($0.trimmingCharacters(in: .whitespaces).prefix(3))) }) { return true }
        let long = texts.filter { text in text.count > 30 || text.filter({ ("가"..."힣").contains($0) }).count > 10 }
        return long.count <= 1 && texts.count - long.count >= 2
    }

    /// 글자 줄들 → 위에서 아래 순서의 글. 같은 높이에 띄어서 놓인 보기 조각은 왼쪽부터 한 줄로
    static func joinRows(_ items: [(text: String, box: CGRect)]) -> [String] {
        var result: [[String]] = []
        for row in rows(items.map(\.box)) {
            let texts = row.map { items[$0].text }
            if row.count >= 2, isChoiceRow(texts) {
                result.append(texts)
            } else {
                for i in row.sorted(by: { items[$0].box.midY > items[$1].box.midY }) { result.append([items[i].text]) }
            }
        }
        // 크게 띄운 곳(세 칸 이상)도 조각으로 나눠서 번호 없는 보기를 찾음
        let split = result.map { row in
            row.flatMap { $0.components(separatedBy: "   ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        }
        return labelUnmarkedChoices(split).map { $0.joined(separator: "   ") }
    }

    /// 보기 번호가 하나도 안 읽혔을 때: 질문 줄("…것은?") 아래에 짧은 조각 4~5개가 띄어져 있으면 ①~⑤를 붙임
    /// rows: 위→아래 줄마다, 줄 안의 조각들(왼→오른)
    static func labelUnmarkedChoices(_ rows: [[String]]) -> [[String]] {
        let all = rows.flatMap { $0 }.joined(separator: " ")
        guard !all.contains(where: { circledDigits.contains($0) }) else { return rows }
        guard let q = rows.lastIndex(where: { row in
            let line = row.joined(separator: " ")
            return line.range(of: #"(\?|？|고르시오|고르면|것은|값은)\s*$"#, options: .regularExpression) != nil
        }), q + 1 < rows.count else { return rows }
        let tail = rows[(q + 1)...]
        let parts = tail.flatMap { $0 }
        guard (4...5).contains(parts.count), tail.contains(where: { $0.count >= 2 }) || tail.count == parts.count else { return rows }
        // 번호를 숫자로만 읽은 보기 "1 12", "2 14" … → 숫자를 떼고 번호 붙임
        let bare = parts.enumerated().allSatisfy { k, part in part.hasPrefix("\(k + 1) ") && part.count > 2 }
        for part in parts where !bare {
            let t = part.trimmingCharacters(in: .whitespaces)
            // 보기 하나는 짧음 (긴 한글 문장이면 보기가 아님), 이미 번호처럼 시작하면 건너뜀
            guard !t.isEmpty, t.count <= 24, t.filter({ ("가"..."힣").contains($0) }).count <= 10,
                  !isChoiceMarker(String(t.prefix(3))) else { return rows }
        }
        var result = rows
        var n = 0
        for r in (q + 1)..<rows.count {
            result[r] = rows[r].map { part in
                defer { n += 1 }
                let body = bare ? String(part.dropFirst(2)) : part
                return "\(circledDigits[n]) " + body.trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }

    /// 동그라미 번호를 숫자로만 읽은 줄: "1 12 2 14 3 16 4 18 5 20" → "① 12 ② 14 …"
    /// 한글이 없는 이어진 줄들에서 "1 값 2 값 3 값 4 값 (5 값)"이 빠짐없이 맞을 때만
    static func bareNumberChoices(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        var removed = Set<Int>()
        func plain(_ line: String) -> Bool {
            !line.trimmingCharacters(in: .whitespaces).isEmpty && !line.contains(where: { ("가"..."힣").contains($0) })
        }
        var i = 0
        while i < lines.count {
            var tokens: [(line: Int, token: String)] = []
            var j = i
            var matched = false
            while j < lines.count, j - i < 5, plain(lines[j]) {
                tokens += lines[j].split(separator: " ").map { (j, String($0)) }
                j += 1
                let count = tokens.count
                guard count == 8 || count == 10 else { if count > 10 { break } else { continue } }
                // 마지막 줄까지 다 썼고, 다음 줄이 이어지는 번호가 아닐 때
                let ok = stride(from: 0, to: count, by: 2).allSatisfy { tokens[$0].token == String($0 / 2 + 1) }
                    && stride(from: 1, to: count, by: 2).allSatisfy { !isChoiceMarker(tokens[$0].token) && tokens[$0].token.count <= 12 }
                if ok, count == 10 || !(j < lines.count && lines[j].hasPrefix("5 ")) {
                    var rebuilt: [Int: [String]] = [:]
                    for k in stride(from: 0, to: count, by: 2) {
                        rebuilt[tokens[k].line, default: []].append("\(circledDigits[k / 2]) \(tokens[k + 1].token)")
                    }
                    for line in i..<j {
                        if let parts = rebuilt[line] { lines[line] = parts.joined(separator: " ") } else { removed.insert(line) }
                    }
                    matched = true
                    break
                }
            }
            i = matched ? j : i + 1
        }
        return lines.enumerated().filter { !removed.contains($0.offset) }.map(\.element).joined(separator: "\n")
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
        // 맨 앞 빈칸: 짧은 식 줄이 연산 기호로 시작 "+ 4 = 9", "2. + 17 = 42" → "□ + 4 = 9" (긴 식이 줄바꿈된 경우는 제외)
        // 네모를 L, D, [, | 로 읽은 경우도: "D+ 17=42" → "□ + 17=42"
        let shortTail = #"(?=\d[^A-Za-z가-힣\n]{0,16}=[^A-Za-z가-힣\n]{0,10}$)"#
        t = t.replacingOccurrences(of: #"(?m)^([ \t]*(?:\d{1,2}\.[ \t]+)?)(?:[LD\[|]|ㅁ)[ \t]*([+\-−×÷])[ \t]*"# + shortTail, with: "$1□ $2 ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?m)^([ \t]*(?:\d{1,2}\.[ \t]+)?)([+×÷*/])[ \t]*"# + shortTail, with: "$1□ $2 ", options: .regularExpression)
        // 맨 끝 빈칸을 [ 나 | 로 읽음: "x² + 6x + [" → "x² + 6x + □"
        t = t.replacingOccurrences(of: #"(?m)([+\-−×÷=])[ \t]*[\[|][ \t]*$"#, with: "$1 □", options: .regularExpression)
        // "□ 안에 알맞은"의 □를 못 읽거나 _, •, [ 로 읽음: "다음 안에 알맞은 수", "식의 _ 안에" → "다음 □ 안에 …"
        t = t.replacingOccurrences(of: #"(?m)(^|다음|의|에서|\d\.)[ \t]*(?:[_•·\[\]|]|L|D)?[ \t]*(?=안에\s*(?:알맞은|들어갈|넣을))"#, with: "$1 □ ", options: .regularExpression)
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

    /// 쌓은 분수를 한 글자 분수(½, ⅓ …)로 읽은 것 → a/b
    static func expandVulgarFractions(_ text: String) -> String {
        let map: [Character: String] = ["½": "1/2", "⅓": "1/3", "⅔": "2/3", "¼": "1/4", "¾": "3/4", "⅕": "1/5", "⅖": "2/5",
                                        "⅗": "3/5", "⅘": "4/5", "⅙": "1/6", "⅚": "5/6", "⅐": "1/7", "⅛": "1/8", "⅜": "3/8",
                                        "⅝": "5/8", "⅞": "7/8", "⅑": "1/9", "⅒": "1/10"]
        guard text.contains(where: { map[$0] != nil }) else { return text }
        var out = ""
        for c in text {
            if let f = map[c] {
                // 앞이 숫자면 대분수(2½ → 2 1/2)라 띄움
                if let last = out.last, last.isNumber { out.append(" ") }
                out += f
            } else {
                out.append(c)
            }
        }
        return out
    }

    /// 동그라미 번호 바로 뒤에 남은 번호 찌꺼기 지우기: "① O 0.012", "③ 3 1.2", "② @ 12" → "① 0.012" …
    /// 같은 번호가 겹친 "④ ④ 어떻해" → "④ 어떻해"
    static func cleanChoiceMarks(_ text: String) -> String {
        guard text.contains(where: { circledDigits.contains($0) }) else { return text }
        var lines = text.components(separatedBy: "\n")
        for li in lines.indices {
            var tokens = lines[li].split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            let before = tokens.count
            var i = 0
            while i < tokens.count {
                guard tokens[i].count == 1, let c = tokens[i].first, let n = circledDigits.firstIndex(of: c) else { i += 1; continue }
                // 같은 번호가 겹침
                if i + 1 < tokens.count, tokens[i + 1] == tokens[i] { tokens.remove(at: i + 1); continue }
                // 다음 토큰이 번호 찌꺼기이고, 그 뒤에 이 보기의 내용이 더 있을 때만 지움
                if i + 2 < tokens.count {
                    let junk = tokens[i + 1]
                    let number = String(n + 1)
                    let lookalike: [Int: [String]] = [1: ["l", "I", "|"], 2: ["Z"], 5: ["S"]]
                    let isJunk = ["O", "o", "@", "©", "®", "*", "D", "Ⓒ", "ⓒ", "•", "·"].contains(junk)
                        || junk == number || junk == "(\(number))" || junk == "\(number))" || junk == "(\(number)"
                        || (lookalike[n + 1] ?? []).contains(junk)
                    let after = tokens[i + 2]
                    let afterIsChoice = after.count == 1 && after.first.map { circledDigits.contains($0) } == true
                    if isJunk, !afterIsChoice { tokens.remove(at: i + 1); continue }
                }
                i += 1
            }
            // 고친 줄만 다시 붙임 (보기 사이 큰 띄어쓰기는 그대로)
            if tokens.count != before { lines[li] = tokens.joined(separator: " ") }
        }
        return lines.joined(separator: "\n")
    }

    static func fix(_ text: String) -> String {
        var result = normalizeBlanks(expandVulgarFractions(text))
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
        return cleanChoiceMarks(normalizeChoices(result))
    }
}
