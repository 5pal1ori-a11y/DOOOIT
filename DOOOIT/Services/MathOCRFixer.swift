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

    static func fix(_ text: String) -> String {
        var result = text
        for rule in rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.anchorsMatchLines]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: rule.template)
        }
        return result
    }
}
