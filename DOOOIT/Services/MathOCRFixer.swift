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

    static func fix(_ text: String) -> String {
        var result = text
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
        return result
    }
}
