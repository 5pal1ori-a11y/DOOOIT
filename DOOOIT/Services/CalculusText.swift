import Foundation

/// 미적분·수열 기호 글자 교정 (Foundation만 씀 → 리눅스 테스트 가능)
/// 글자 인식이 ∑ ∫ lim ′ → ∞ 를 다른 글자로 읽는 대표 패턴을, 문맥이 분명할 때만 바로잡음.
/// 확신이 없으면 읽은 그대로 둠 (틀리게 고치는 것이 안 고치는 것보다 나빠요)
enum CalculusText {
    /// 미적분 문맥인지: 이 단서가 있어야 f′, 아랫첨자 같은 애매한 교정을 함
    static func hasCalculusCue(_ text: String) -> Bool {
        text.range(of: #"미분|도함수|접선|순간변화율|평균변화율|미분계수|적분|극한|극값|극대|극소|∫|∑|Σ|lim|dy|dx|f′|f'\(|y′|y'\s*[=\s]"#, options: .regularExpression) != nil
    }

    /// 수열 문맥인지 (aₙ, Sₙ 같은 아랫첨자 교정의 단서)
    static func hasSequenceCue(_ text: String) -> Bool {
        text.range(of: #"수열|일반항|등차|등비|공차|공비|첫째항|제\s*n\s*항|[0-9n]\s*항|∑|Σ|a_|S_|\{\s*a"#, options: .regularExpression) != nil
    }

    private static func replace(_ text: String, _ pattern: String, _ template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }

    /// 무한대 비슷한 글자: ∞ ← oo, 00, co, OO, ∞ (→ 바로 뒤나 ^ 위끝 자리에서만)
    private static let infinityLookalike = #"(?:∞|oo|OO|00|co|CO|ο|ꝏ)"#

    /// 문맥이 분명한 기호만 바로잡음 (MathOCRFixer.fix 안에서 지수 규칙보다 먼저)
    static func fixEarly(_ input: String) -> String {
        var t = input
        // 화살표: -> → ⟶
        t = replace(t, #"(?<=[A-Za-z0-9)′'])\s*(?:-{1,2}|−|–|—)\s*>\s*(?=[A-Za-z0-9∞(+\-−π])"#, "→")
        t = t.replacingOccurrences(of: "⟶", with: "→").replacingOccurrences(of: "⟼", with: "→").replacingOccurrences(of: "➔", with: "→")
        // 합의 기호: Σ(그리스 대문자)는 수학 문제에서 ∑
        t = t.replacingOccurrences(of: "Σ", with: "∑")
        // lim 비슷한 글자: 극한 식 앞에서만
        t = replace(t, #"(?<![A-Za-z])(?:Iim|1im|llm|Ilm|iim|lim|lm|lirn|Iirn|tim|Lim|LIM)(?=\s*_?\s*[\{\(]?\s*[a-zA-Zθ]\s*(?:→|->|-{1,2}>?|−)\s*[-+−0-9a-zA-Z∞(])"#, "lim")
        t = replace(t, #"(?<![A-Za-z])(?:Iim|1im)(?![A-Za-z])"#, "lim")
        // 극한값의 무한대: → 뒤
        t = replace(t, "(→\\s*[+\\-−]?\\s*)" + infinityLookalike, "$1∞")
        // 합의 위끝 ^oo
        t = replace(t, "(∑[^\\n]{0,12}?\\^\\s*\\{?\\s*)" + infinityLookalike, "$1∞")
        // 도함수 ′: f'(x), g'(x), F'(x) (영어 소유격과 달리 바로 뒤에 괄호)
        t = replace(t, #"(?<![A-Za-z])([fgFGhH])\s?(['’`´ʹ′]{1,2})(?=\s*\()"#) { _, groups in
            groups[0] + String(repeating: "′", count: groups[1].count)
        }
        // y' 도 문맥이 있을 때 (미분 문제의 y′ = …)
        if hasCalculusCue(t) {
            t = replace(t, #"(?<![A-Za-z])([yvaxP])['’`´ʹ](?=\s*(?:=|\(|,|\)|의|를|은|는|을|이|가|$))"#, "$1′")
        }
        // d/(dx) → d/dx, (dy)/(dx) → dy/dx
        t = replace(t, #"(?<![A-Za-z])d\s*/\s*\(\s*d\s*([xyt])\s*\)"#, "d/d$1")
        t = replace(t, #"\(\s*d\s*([xyt])\s*\)\s*/\s*\(\s*d\s*([xyt])\s*\)"#, "d$1/d$2")
        t = replace(t, #"(?<![A-Za-z])d([xyt])\s*/\s*\(\s*d\s*([xyt])\s*\)"#, "d$1/d$2")
        // 수열 아랫첨자: 수열 문맥에서 aₙ, aₖ, Sₙ (a n, an → a_n)
        if hasSequenceCue(t) {
            t = replace(t, #"\{\s*([a-zA-Z])\s*([nk])\s*\}"#, "{$1_$2}")
            t = replace(t, #"(?<![A-Za-z가-힣0-9_])([abcST])([nk])(?![A-Za-z0-9_])"#, "$1_$2")
        }
        return t
    }

    /// 마지막 정리: 극한 아래 식을 lim_{x→a} 로 (MathOCRFixer.fix 끝에서)
    static func fixLate(_ input: String) -> String {
        var t = input
        // lim x→2, lim(x→2), lim_x→2, lim_{x→2}, lim x - 2 (이미 → 로 바뀐 것) → lim_{x→2}
        t = replace(t, #"lim\s*_?\s*[\{\(]?\s*([a-zA-Zθ])\s*→\s*([+\-−]?\s*(?:∞|[0-9]+(?:\.[0-9]+)?(?:/[0-9]+)?|[a-zA-Zπ]))([+\-−](?![0-9A-Za-z(]))?\s*[\}\)]?"#) { _, groups in
            let target = groups[1].replacingOccurrences(of: " ", with: "")
            let side = groups[2]
            return "lim_{\(groups[0])→\(target)\(side)}"
        }
        // 이미 만든 lim_{…} 속 공백 정리
        t = replace(t, #"lim_\{\s*([a-zA-Zθ])\s*→\s*([^}]*?)\s*\}"#) { _, groups in
            "lim_{\(groups[0])→\(groups[1].replacingOccurrences(of: " ", with: ""))}"
        }
        return t
    }

    private static func replace(_ text: String, _ pattern: String, _ transform: (NSTextCheckingResult, [String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return text }
        let ns = text as NSString
        var result = ""
        var last = 0
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            var groups: [String] = []
            for g in 1..<max(1, m.numberOfRanges) {
                let r = m.range(at: g)
                groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            result += transform(m, groups)
            last = m.range.location + m.range.length
        }
        result += ns.substring(from: last)
        return result
    }
}
