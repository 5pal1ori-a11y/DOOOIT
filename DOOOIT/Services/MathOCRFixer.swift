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
        (#"(?<=[가-힣])0\|"#, "이")
    ]

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
