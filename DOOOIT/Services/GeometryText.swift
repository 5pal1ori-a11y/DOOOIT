import Foundation

/// 도형 기호를 앱 안에서 한 가지 모양으로 쓰기 (사진 읽기·정밀 인식·직접 고치기·화면 표시·풀이가 모두 이 표기를 씀)
///
/// 앱 표기
///   선분 AB      → A̅B̅          글자마다 윗줄(U+0305)을 붙임. SwiftUI Text에서 두 글자 위로 이어진 줄로 보이고,
///                              풀이는 윗줄을 지운 AB로 읽음 (forSolver). 한 글자에만 붙은 "AB̅"도 A̅B̅로 펼침
///   각 ABC       → ∠ABC, ∠A, ∠x (∠ 뒤는 띄우지 않음)
///   삼각형 ABC   → △ABC (U+25B3, 그리스 Δ·▵는 △로)
///   수직 ⊥, 평행 ∥ (U+2225: 선 이름 사이의 //, ǁ, ‖도 ∥로), 도 ° (U+00B0)
///   합동 ≡ (≅도 ≡), 닮음 ∽ (U+223D: 삼각형 사이의 ~, ∼도 ∽로)
///   호 AB        → 호 AB (⌒AB, LaTeX \overset{\frown}{AB}도 이 모양)
///   사각형 ABCD  → 사각형 ABCD (□ABCD: □는 빈칸으로 쓰니까 꼭짓점 넷이 바로 붙은 □만 글로 바꿈)
///   원주율 π
enum GeometryText {
    static let bar: Character = "\u{305}"
    /// 직접 고치기 바에서 넣는 윗줄 (앞 글자에 붙는 결합 문자)
    static let overlineMark = "\u{305}"

    /// "AB" → "A̅B̅"
    static func segment(_ letters: String) -> String {
        letters.filter { $0 != bar && !$0.isWhitespace }.map { String($0) + "\u{305}" }.joined()
    }

    private static func re(_ t: String, _ pattern: String, _ template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return t }
        return regex.stringByReplacingMatches(in: t, range: NSRange(t.startIndex..., in: t), withTemplate: template)
    }

    private static let symbolChars: Set<Character> = ["∠", "△", "⊥", "∥", "≡", "∽", "°", "⌒", "Δ", "∆", "▵", "≅", "ǁ", "‖", "□"]

    /// 윗줄이 한 글자에만 붙었거나("AB̅") 마크론(U+0304)으로 쓴 선분 → 두 글자 모두 U+0305 ("A̅B̅")
    /// 윗줄이 하나도 없는 대문자 두 글자와 세 글자 이상 이어진 대문자는 그대로 (복소수 z̄ 같은 소문자도 그대로)
    static func spreadOverlines(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: { $0.value == 0x305 || $0.value == 0x304 }) else { return text }
        let o = Array(text.unicodeScalars)
        func isUpper(_ s: Unicode.Scalar) -> Bool { s.value >= 65 && s.value <= 90 }
        func isMark(_ s: Unicode.Scalar) -> Bool { s.value == 0x305 || s.value == 0x304 }
        func isLetterish(_ s: Unicode.Scalar) -> Bool { isUpper(s) || (s.value >= 97 && s.value <= 122) || isMark(s) }
        var out = String.UnicodeScalarView()
        var i = 0
        while i < o.count {
            // 앞이 글자가 아닌 곳에서 시작하는 대문자 두 개 (+윗줄)
            if isUpper(o[i]), i == 0 || !isLetterish(o[i - 1]) {
                var j = i + 1, barred = false
                if j < o.count, isMark(o[j]) { barred = true; j += 1 }
                if j < o.count, isUpper(o[j]) {
                    var k = j + 1
                    if k < o.count, isMark(o[k]) { barred = true; k += 1 }
                    if barred, k >= o.count || !isLetterish(o[k]) {
                        out.append(o[i]); out.append("\u{305}"); out.append(o[j]); out.append("\u{305}")
                        i = k
                        continue
                    }
                }
            }
            // 대문자 뒤 마크론은 윗줄로
            if o[i].value == 0x304, i > 0, isUpper(o[i - 1]) { out.append("\u{305}") } else { out.append(o[i]) }
            i += 1
        }
        return String(out)
    }

    /// 앱 표기로 맞추기 (정밀 인식 변환 뒤, 사진 글자 교정 끝, 화면 표시에 씀). 이미 앱 표기인 글은 그대로
    static func canonical(_ text: String) -> String {
        guard text.contains(where: { symbolChars.contains($0) }) || text.contains("//") || text.contains("~") || text.contains("∼")
                || text.unicodeScalars.contains(where: { $0.value == 0x305 || $0.value == 0x304 }) else { return text }
        var t = spreadOverlines(text)
        // Δ, ∆, ▵ + 꼭짓점 셋 → △
        t = re(t, #"[Δ∆▵](?=[ \t]?[A-Z]{3}(?![A-Za-z]))"#, "△")
        // "△ ABC", "∠ ABC" → 붙여 씀
        t = re(t, #"([△∠])[ \t]+(?=[A-Za-z])"#, "$1")
        // □ABCD → 사각형 ABCD (빈칸 □와 헷갈리지 않게 꼭짓점 넷이 바로 붙은 것만, 띄어 읽었으면 사각형 낱말이 있을 때만)
        t = re(t, #"□(?=[A-Z]{4}(?![A-Za-z]))"#, "사각형 ")
        if t.range(of: "사각형|마름모|사다리꼴|평행사변형", options: .regularExpression) != nil {
            t = re(t, #"□[ \t](?=[A-Z]{4}(?![A-Za-z]))"#, "사각형 ")
        }
        // 평행: ǁ ‖ → ∥, 선 이름 사이의 // → ∥ (http:// 같은 것은 앞이 글자가 아니라 그대로)
        t = t.replacingOccurrences(of: "ǁ", with: "∥").replacingOccurrences(of: "‖", with: "∥")
        t = re(t, "(?<=[A-Za-z]|[A-Z]\u{305})[ \t]*//[ \t]*(?=[A-Za-z])", " ∥ ")
        // 합동 ≅ → ≡
        t = t.replacingOccurrences(of: "≅", with: "≡")
        // 닮음: 삼각형 사이의 ~, ∼ → ∽
        t = re(t, #"(△[A-Z]{3})[ \t]*[~∼][ \t]*(?=△)"#, "$1 ∽ ")
        // 호: ⌒AB → 호 AB ("호 ⌒AB"도 한 번만)
        t = re(t, #"(?:호[ \t]*)?⌒[ \t]*(?=[A-Z]{2}(?![A-Za-z]))"#, "호 ")
        return t
    }

    /// 풀이 엔진에 넘길 글: 앱 표기 + 선분 윗줄을 지움 (A̅B̅ = 6 → AB = 6)
    static func forSolver(_ text: String) -> String {
        let t = canonical(text)
        guard t.unicodeScalars.contains(where: { $0.value == 0x305 }) else { return t }
        return String(String.UnicodeScalarView(t.unicodeScalars.filter { $0.value != 0x305 }))
    }

    /// 도형 문제 같은지: 도형 기호나 도형 낱말이 있을 때 (사진 글자 교정 규칙을 이때만 씀)
    static func isGeometric(_ text: String) -> Bool {
        if text.contains(where: { "∠△⊥∥≡∽⌒".contains($0) }) { return true }
        // 숫자 뒤 °는 각도 (x°처럼 글자 뒤 °는 지수 ²를 잘못 읽은 것일 수도 있어서 넣지 않음)
        if text.range(of: #"[0-9]\s?°"#, options: .regularExpression) != nil { return true }
        return text.range(of: #"삼각형|사각형|각형|선분|이등변|평행|수직|원주각|중심각|내각|외각|맞꼭지각|동위각|엇각|닮음|합동|꼭짓점|대각선|반직선|각의\s*크기|이등분선|외접원|내접원|부채꼴|중점|빗변|원\s*[O0]|의\s*크기(?:는|를|가)|(?<![A-Za-z])[A-Z]{3,4}(?![A-Za-z])"#,
                          options: .regularExpression) != nil
    }

    /// 각을 다루는 문제인지 (° 교정은 이때만: "1O"를 "1°"로 바꾸지 않게)
    static func isAngular(_ text: String) -> Bool {
        text.range(of: #"[∠°]|각의\s*크기|내각|외각|원주각|중심각|맞꼭지각|동위각|엇각|크기의\s*합"#, options: .regularExpression) != nil
    }

    // MARK: 사진 글자 교정 (Vision이 도형 기호를 다르게 읽은 것)

    /// 도형 문제에서만 쓰는 교정. MathOCRFixer.fix가 숫자·변수 규칙보다 먼저 부름
    /// (∠x를 "Zx"로 읽은 것을 먼저 고쳐야 "2x"로 바뀌지 않음)
    static func fixOCR(_ text: String) -> String {
        guard isGeometric(text) else { return piFix(text) }
        var t = text
        // 원 O를 "원 0"으로 읽음
        t = re(t, #"원[ \t]*0(?=[ \t]*(?:에서|의|위|과|와|이|은|는|을|$))"#, "원 O")
        // 삼각형 △ABC를 "ΔABC", "AABC", "4ABC", "▵ABC"로 읽음 (꼭짓점 셋 앞)
        t = re(t, #"(?<![A-Za-z0-9.])(?:[Δ∆▵▲]|4)[ \t]?(?=[A-Z]{3}(?![A-Za-z]))"#, "△")
        t = re(t, #"(?<![A-Za-z0-9.])A(?=A[A-Z]{2}(?![A-Za-z]))"#, "△")
        // 닮음 ∽을 "S", "~"로 읽음 (뒤 삼각형의 △도 "A"로): △ABC S ADEF → △ABC ∽ △DEF
        t = re(t, #"(△[A-Z]{3})[ \t]*[S~∼∽][ \t]*(?:[A4Δ△][ \t]?)?([A-Z]{3})(?![A-Za-z])"#, "$1 ∽ △$2")
        // 합동 ≡을 "="로 읽음: △ABC = ADEF → △ABC ≡ △DEF (넓이를 견주는 글이 아닐 때)
        if !t.contains("넓이") {
            t = re(t, #"(△[A-Z]{3})[ \t]*[=≡][ \t]*(?:[A4Δ△][ \t]?)?([A-Z]{3})(?![A-Za-z0-9])"#, "$1 ≡ △$2")
        }
        // 사각형 □ABCD를 "DABCD", "OABCD", "ㅁABCD"로 읽음 (사각형 낱말이 있을 때만)
        if t.range(of: "사각형|마름모|사다리꼴|평행사변형", options: .regularExpression) != nil {
            t = re(t, #"(?<![A-Za-z0-9])[DOㅁ口□][ \t]?(?=([A-Z])(?!\1)([A-Z])(?!\1|\2)([A-Z])(?!\1|\2|\3)[A-Z](?![A-Za-z]))"#, "사각형 ")
        }
        // 각 ∠ABC, ∠A를 "LABC", "ZABC", "<ABC", "≤B", "2A", "CB"로 읽음
        //   꼭짓점 셋 앞이면 바로, 한 글자 앞이면 뒤에 = 값·의 크기·: 비·+ 가 올 때만
        t = re(t, #"(?<![A-Za-z0-9])[LZz<≤][ \t]?(?=[A-Z]{3}(?![A-Za-z]))"#, "∠")
        t = re(t, #"(?<![A-Za-z0-9])[LZz<≤][ \t]?(?=[A-Z](?![A-Za-z])[ \t]*(?:=|의[ \t]*(?:크기|외각|이등분선)|:|\+|,|와|과|는|은))"#, "∠")
        //   "2A = 40°", "CB의 크기": 숫자 2·글자 C는 값이 °로 끝나거나 "의 크기"가 올 때만
        t = re(t, #"(?<![A-Za-z0-9.])[2C][ \t]?(?=[A-Z](?![A-Za-z])[ \t]*=[ \t]*[0-9]{1,3}(?:\.[0-9]+)?[ \t]*[°º])"#, "∠")
        t = re(t, #"(?<![A-Za-z0-9.])[2C(][ \t]?(?=[A-Za-z](?![A-Za-z])[ \t]*의[ \t]*(?:크기|외각))"#, "∠")
        //   "∠A = LD" 처럼 = 오른쪽에 온 각 (보기 "∠B = ∠F")
        t = re(t, #"(?<=∠[A-Z][ \t]?=[ \t]?)[LZz<≤C2](?=[A-Z](?![A-Za-z]))"#, "∠")
        //   ∠A를 "<4"로 읽음 (A를 4로)
        t = re(t, #"(?<![A-Za-z0-9])[<L≤]4(?=[ \t]*=[ \t]*[0-9])"#, "∠A")
        //   ∠x, ∠a: 소문자 각 이름 (Zx, Lx, <x) — 뒤에 = 값·의 크기·+ 가 올 때만
        t = re(t, #"(?<![A-Za-z0-9])[LZ<≤][ \t]?(?=[a-hxyz](?![A-Za-z])[ \t]*(?:=|의[ \t]*크기|\+|-|−|:|,|와|과|는|은))"#, "∠")
        //   비 ∠A : ∠B : ∠C의 뒤쪽 각: "∠B : 4C" → "∠B : ∠C"
        for _ in 0..<2 { t = re(t, #"(?<=∠[A-Z][ \t]?:[ \t]?)[4LZ<2]?(?=[A-Z](?![A-Za-z]))"#, "∠") }
        //   ∠가 있는 글에서 각 값 자리의 "24 = 45°"(∠A), ", 8 = 70°"(∠B)
        if t.contains("∠") {
            t = re(t, #"(?<=에서[ \t]|,[ \t])24(?=[ \t]*=[ \t]*[0-9]{1,3}(?:\.[0-9]+)?°)"#, "∠A")
            t = re(t, #"(?<=에서[ \t]|,[ \t])8(?=[ \t]*=[ \t]*[0-9]{1,3}(?:\.[0-9]+)?°)"#, "∠B")
        }
        //   각 크기 자리에서 ∠를 놓침: "∠A = 45°, B = 70°" → ∠B (∠가 이미 있는 글에서만)
        if t.contains("∠") {
            t = re(t, #"(?<![A-Za-z0-9∠△□\x{305}])([A-Z])(?=[ \t]*=[ \t]*[0-9]{1,3}(?:\.[0-9]+)?[ \t]*[°º])"#, "∠$1")
        }
        // 평행: 선 이름 사이의 "ll", "||", "I", "/", "11" (l ∥ m, AB ∥ CD)
        t = re(t, #"(?<![A-Za-z])([lmn])[ \t]+(?:ll|\|\||11|//|II)[ \t]+([lmn])(?![A-Za-z])"#, "$1 ∥ $2")
        t = re(t, #"(?<![A-Za-z])([lmn])[ \t]*//[ \t]*([lmn])(?![A-Za-z])"#, "$1 ∥ $2")
        //   "l // m"의 l을 I, 1로 읽음: "I/ m이고", "/ 1/ m일 때"
        t = re(t, #"(?<![A-Za-z0-9])(?:/[ \t]*)?[Il1|]{1,2}[ \t]*/{1,2}[ \t]*m(?![A-Za-z])(?=[ \t]*(?:일|이고|이면|이다|이므로|,|\)))"#, "l ∥ m")
        //   "그림에서 11 m일 때": 길이 11 m와 헷갈리지 않게 "…에서" 바로 뒤, 각을 묻는 글에서만
        if t.contains("∠") {
            t = re(t, #"(?<=에서[ \t])(?:ll|11|Il|lI|II|\|\|)[ \t]*m(?![A-Za-z])(?=[ \t]*(?:일|이고|이면))"#, "l ∥ m")
        }
        //   선분 이름(윗줄이 있어도) 사이
        let segL = #"(?<=[A-Z]\x{305}?[A-Z]\x{305}?)"#, segR = #"(?=[A-Z]\x{305}?[A-Z]\x{305}?(?![A-Za-z]))"#
        t = re(t, segL + #"[ \t]*(?:\|\||ll|II|//)[ \t]*"# + segR, " ∥ ")
        t = re(t, segL + #"[ \t]+(?:I|\||/)[ \t]+"# + segR, " ∥ ")
        // 수직: 선분 사이의 "1", "L", "⊥" → ⊥ (AB 1 CD)
        t = re(t, segL + #"[ \t]+[1L⊥][ \t]+"# + segR, " ⊥ ")
        t = re(t, #"(?<![A-Za-z])([lmn])[ \t]+[1L][ \t]+([lmn])(?![A-Za-z])"#, "$1 ⊥ $2")
        // 문제 번호 바로 뒤 "ABC에서"는 △ABC (△를 놓침)
        t = re(t, #"(?<=^[0-9]{1,2}\.[ \t]|^[0-9]{1,2}[ \t])([A-Z])(?!\1)([A-Z])(?!\1|\2)[A-Z](?=에서)"#, "△$0")
        // 선분 이름의 B를 8로 읽음: "8C = 5" (= 값 앞)
        t = re(t, #"(?<![A-Za-z0-9.∠])8(?=[A-Z](?![A-Za-z])[ \t]*=[ \t]*[0-9](?![0-9]*[ \t]*[°º]))"#, "B")
        // 선분 이름의 A를 4로 읽음: "4C = 6", "4E의 길이" (뒤 글자가 대문자 하나이고 = 값·의 길이가 올 때)
        t = re(t, #"(?<![A-Za-z0-9.∠])4(?=[B-Z](?![A-Za-z])[ \t]*(?:=[ \t]*[0-9](?![0-9]*[ \t]*[°º])|의[ \t]*길이))"#, "A")
        // 도 °를 "o", "O", "º", "^0"으로 읽음: 30o → 30°  (각 값 자리: = 뒤, 쉼표·조사 앞)
        if isAngular(t) {
            t = re(t, #"(?<=[0-9])(?:[oOº˚]|\^0)(?![0-9A-Za-z])"#, "°")
            // 80°의 0을 °로 읽음: 8°° → 80°
            t = re(t, #"(?<=[0-9])°°"#, "0°")
            // x°를 "xo"로 읽음 (각 크기 x°, 2x°)
            t = re(t, #"(?<![A-Za-z])([0-9]{0,3}[xyab])[oº˚](?![0-9A-Za-z])"#, "$1°")
            //   3x°의 x를 r로 읽음 (x°, 2x° 가 함께 있을 때)
            if t.contains("x°") { t = re(t, #"(?<=[0-9])r°"#, "x°") }
            // ∠B = 609: 각의 값 뒤 °를 9로 읽음 (10 이상, 끝자리 0·5인 값 + 9)
            t = re(t, #"(∠[A-Za-z]{1,3}[ \t]*=[ \t]*)([1-9][0-9]?[05])9(?![0-9°])"#, "$1$2°")
            t = degreeChoices(t)
        }
        // 원주율 π를 T로 읽음 (원·부채꼴 문제의 수 뒤): 9T cm² → 9π cm²
        t = piFix(t)
        // 선분: 윗줄을 놓친 두 꼭짓점 이름 → A̅B̅ (= 값, 의 길이, ⊥, ∥, 비 앞에서. 직선·선분·호 뒤는 그대로)
        t = restoreSegments(t)
        return t
    }

    /// 원·부채꼴·구 문제의 원주율 π를 "T", "TT", "ㅠ"로 읽은 것 (수 바로 뒤나 보기 자리에서만)
    static func piFix(_ text: String) -> String {
        guard text.range(of: "원|부채꼴|반지름|지름|구의|원기둥|원뿔|호의", options: .regularExpression) != nil else { return text }
        var t = re(text, #"(?<=[0-9①②③④⑤ \t(])(?:TT|T|ㅠ)(?=[ \t]*(?:cm|m|$|\)|,|[+\-−²³]|[ \t]))"#, "π")
        //   수 바로 뒤 n, m (3ncm?, 12m cm')는 보기 줄에서 단위 cm 앞일 때만
        t = re(t, #"(?<=[①②③④⑤][ \t]?[0-9]{1,3})[nm](?=[ \t]*cm)"#, "π")
        t = re(t, #"(?<=π)[ \t]*(cm|m)'"#, " $1²")
        // 넓이 단위 cm² 의 ²를 ?로 읽음 (π 뒤)
        t = re(t, #"(?<=π)[ \t]*(cm|m)\?"#, " $1²")
        return t
    }

    /// 각도 보기 줄: 다른 보기가 모두 °로 끝나는데 한 보기만 "1050", "700", "609"처럼 °를 0·9로 읽었으면
    /// 앞뒤 보기 값 사이에 맞는 쪽으로 (105°가 95°와 115° 사이) — 어느 쪽인지 분명할 때만 고침
    static func degreeChoices(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        for li in lines.indices {
            let line = lines[li]
            guard line.contains(where: { "①②③④⑤".contains($0) }), let regex = try? NSRegularExpression(pattern: #"([①②③④⑤])[ \t]*([0-9]{1,4})(°|\.(?![0-9]))?(?![0-9.°])"#) else { continue }
            let ns = line as NSString
            let ms = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
            guard ms.count >= 4 else { continue }
            let values = ms.map { Int(ns.substring(with: $0.range(at: 2))) ?? -1 }
            let hasDeg = ms.map { $0.range(at: 3).location != NSNotFound && ns.substring(with: $0.range(at: 3)) == "°" }
            guard hasDeg.filter({ $0 }).count >= ms.count - 1, hasDeg.contains(false) else { continue }
            var result = line
            for k in ms.indices.reversed() where !hasDeg[k] {
                let raw = values[k]
                let prev = k > 0 ? values[k - 1] : nil, next = k + 1 < values.count ? values[k + 1] : nil
                func fits(_ v: Int) -> Bool { (prev.map { v > $0 } ?? true) && (next.map { v < $0 } ?? true) && v > 0 && v <= 3600 }
                let dropped = raw % 10 == 0 || raw % 10 == 9 ? raw / 10 : -1
                let keep = fits(raw), drop = dropped > 0 && fits(dropped) && raw >= 100
                let value: Int
                if drop && !keep { value = dropped } else if keep && !drop { value = raw } else { continue }
                // 숫자 뒤 "." 도 °를 잘못 읽은 것 (60. → 60°)
                let mark = ms[k].range(at: 3)
                let end = mark.location != NSNotFound ? mark.location + mark.length : ms[k].range(at: 2).location + ms[k].range(at: 2).length
                guard let range = Range(NSRange(location: ms[k].range(at: 2).location, length: end - ms[k].range(at: 2).location), in: result) else { continue }
                result.replaceSubrange(range, with: "\(value)°")
            }
            lines[li] = result
        }
        return lines.joined(separator: "\n")
    }

    /// 도형 문제에서 윗줄 없이 읽힌 선분 이름 되살리기: "AB = 6", "AC의 길이", "AB ⊥ CD", "AD : DB"
    static func restoreSegments(_ text: String) -> String {
        let pattern = "(?<![A-Za-z0-9가-힣∠△□\u{305}])(?<!선분 )(?<!직선 )(?<!반직선 )(?<!호 )(?<!현 )(?<!점 )([A-Z])([A-Z])(?![A-Za-z\u{305}])"
            + #"(?=[ \t]*(?:=|:|\+|⊥|∥|//|<|>|≤|≥|의[ \t]*(?:길이|중점|수직이등분선|연장선)|와|과|은|는|이고|이다|이므로|이면|인|일[ \t]*때|를|을|,|\)|[①②③④⑤]|$))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return text }
        let ns = text as NSString
        var result = text
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let a = ns.substring(with: m.range(at: 1)), b = ns.substring(with: m.range(at: 2))
            // 같은 글자 두 개(AA)는 선분이 아님
            guard a != b, let range = Range(m.range, in: result) else { continue }
            result.replaceSubrange(range, with: segment(a + b))
        }
        return result
    }
}
