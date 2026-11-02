import Foundation

// 채점: 맥 실행기(사진 → Vision)와 리눅스 다시 채점(저장된 Vision 결과 → 글자 정리)이 함께 씀

struct Check: Codable {
    var name: String
    var ok: Bool
    var detail: String
}

/// Vision이 읽은 줄 그대로 (다시 채점할 때 OCRLine으로 되돌림)
struct DebugLine: Codable {
    var text: String
    var confidence: Float
    var box: [Double]
    /// 글자마다 상자 (원인 찾기용, 빈칸 글자는 [])
    var chars: [[Double]]? = nil
}

struct CaseResult: Codable {
    var id: String
    var category: String
    var degrade: String
    var passed: Bool
    var score: Double
    var seconds: Double
    var checks: [Check]
    var text: String = ""
    var choices: [String] = []
    var straightened = false
    /// 글줄 기울기를 바로잡은 각도 (도)
    var skew: Double? = nil
    /// recognizeMath 결과 (분수·지수·빈칸·동그라미를 끼워 넣은 줄)
    var mathLines: [DebugLine] = []
    var unsure: [String] = []
    var baseText = ""
    /// multiPassRead 결과
    var readings: [String] = []
    var words: [String] = []
    /// 단어장: [원래 사진 읽기, 고대비 사진 읽기]
    var wordLines: [[DebugLine]] = []
    /// 원인 찾기용: 원래 사진을 한국어+영어 / 영어 전용으로 읽은 그대로, 찾은 네모 상자, 동그라미 번호 후보
    var rawKorean: [DebugLine]? = nil
    var rawEnglish: [DebugLine]? = nil
    var rects: [[Double]]? = nil
    var circles: [[Double]]? = nil
    var shapeCount: Int? = nil
}

func rounded(_ r: CGRect) -> [Double] {
    [r.minX, r.minY, r.width, r.height].map { (Double($0) * 100_000).rounded() / 100_000 }
}

/// 비교용: 띄어쓰기 없애고 기호 모양 통일
func norm(_ s: String) -> String {
    var t = s.replacingOccurrences(of: "²", with: "^2").replacingOccurrences(of: "³", with: "^3")
    t = t.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "–", with: "-")
    t = t.replacingOccurrences(of: "＝", with: "=").replacingOccurrences(of: "，", with: ",")
    t = t.filter { !$0.isWhitespace }
    while t.hasSuffix(".") { t.removeLast() }
    return t
}

func debugLines(_ lines: [OCRLine]) -> [DebugLine] {
    lines.map { DebugLine(text: $0.text, confidence: $0.confidence, box: rounded($0.box)) }
}

func ocrLines(_ lines: [DebugLine]) -> [OCRLine] {
    lines.map { OCRLine(text: $0.text, confidence: $0.confidence, box: CGRect(x: $0.box[0], y: $0.box[1], width: $0.box[2], height: $0.box[3])) }
}

/// 문제: 읽은 글 → DoitProblemScan → 정답과 비교
func evaluateProblem(_ spec: CaseSpec, text: String, unsure: [String], result: inout CaseResult) {
    let scan = DoitProblemScan.scan(text, lowConfidence: unsure)
    result.text = text
    result.choices = scan.choices
    let e = spec.expect
    var checks: [Check] = []
    if let expected = e.choices {
        let got = scan.choices.map(norm), want = expected.map(norm)
        if want.isEmpty {
            checks.append(Check(name: "보기 없음", ok: got.isEmpty, detail: got.isEmpty ? "" : "보기가 생김: \(scan.choices)"))
        } else {
            checks.append(Check(name: "보기 \(want.count)개", ok: got.count == want.count, detail: "읽음 \(got.count)개: \(scan.choices)"))
            let same = zip(got, want).filter { $0 == $1 }.count
            checks.append(Check(name: "보기 내용", ok: got == want,
                                detail: got == want ? "" : "기대 \(expected) / 읽음 \(scan.choices) (같음 \(same)/\(want.count))"))
        }
    }
    let flatText = norm(text)
    if e.blank == true {
        checks.append(Check(name: "빈칸 □", ok: text.contains("□"), detail: text.contains("□") ? "" : "□ 없음"))
    }
    for token in e.tokens {
        let ok = flatText.contains(norm(token))
        checks.append(Check(name: "수식 \(token)", ok: ok, detail: ok ? "" : "없음"))
    }
    for phrase in e.phrases {
        let ok = flatText.contains(norm(phrase))
        checks.append(Check(name: "문장 \(phrase)", ok: ok, detail: ok ? "" : "없음"))
    }
    result.checks = checks
}

/// 단어장: 찾은 단어(앱처럼 뜻 있는 것만) → 정답과 비교
func evaluateWords(_ spec: CaseSpec, words found: [ParsedWord], result: inout CaseResult) {
    var words = found
    let withMeaning = words.filter { !$0.meaning.trimmingCharacters(in: .whitespaces).isEmpty }
    if !withMeaning.isEmpty { words = withMeaning }
    result.words = words.map { "\($0.term) = \($0.meaning)\($0.unsure ? " (확인)" : "")" }
    var checks: [Check] = []
    var missing: [String] = []
    var wrong: [String] = []
    for pair in spec.expect.words {
        guard let hit = words.first(where: { $0.term.lowercased() == pair.term.lowercased() }) else { missing.append(pair.term); continue }
        if !norm(hit.meaning).contains(norm(pair.meaning)) { wrong.append("\(pair.term): \(hit.meaning) (기대 \(pair.meaning))") }
    }
    let total = spec.expect.words.count
    checks.append(Check(name: "단어 \(total)개 찾기", ok: missing.isEmpty, detail: missing.isEmpty ? "" : "못 찾음 \(missing.count)개: \(missing)"))
    checks.append(Check(name: "뜻 맞음", ok: wrong.isEmpty, detail: wrong.joined(separator: " · ")))
    let expectedTerms = Set(spec.expect.words.map { $0.term.lowercased() })
    let extras = words.filter { !expectedTerms.contains($0.term.lowercased()) }
    checks.append(Check(name: "군더더기 없음", ok: extras.isEmpty, detail: extras.map { "\($0.term)=\($0.meaning)" }.joined(separator: " · ")))
    if !spec.expect.notTerms.isEmpty {
        let bad = words.filter { w in spec.expect.notTerms.contains { $0.lowercased() == w.term.lowercased() } }
        checks.append(Check(name: "유의어 제외", ok: bad.isEmpty, detail: bad.map(\.term).joined(separator: ", ")))
    }
    result.checks = checks
}

func finishScore(_ result: inout CaseResult) {
    let ok = result.checks.filter(\.ok).count
    result.score = result.checks.isEmpty ? 0 : Double(ok) / Double(result.checks.count)
    result.passed = !result.checks.isEmpty && ok == result.checks.count
}

func printResult(_ result: CaseResult) {
    let mark = result.passed ? "✓" : "✗"
    print("\(mark) \(result.id)  \(String(format: "%.0f%%", result.score * 100))  \(String(format: "%.1fs", result.seconds))")
    if !result.passed {
        for check in result.checks where !check.ok { print("    · \(check.name): \(check.detail)") }
        print("    글: \(result.text.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(300))")
        if !result.words.isEmpty { print("    단어: \(result.words.joined(separator: " | ").prefix(400))") }
    }
}

/// 분류별 · 손상별 합계 (마크다운)
func summarize(_ results: [CaseResult], title: String) -> String {
    func table(_ key: (CaseResult) -> String, _ header: String) -> String {
        var groups: [String: [CaseResult]] = [:]
        for r in results { groups[key(r), default: []].append(r) }
        var out = "| \(header) | 통과 | 점수 |\n|---|---|---|\n"
        for name in groups.keys.sorted() {
            let rs = groups[name]!
            let pass = rs.filter(\.passed).count
            let score = rs.map(\.score).reduce(0, +) / Double(rs.count)
            out += "| \(name) | \(pass)/\(rs.count) | \(String(format: "%.0f%%", score * 100)) |\n"
        }
        return out
    }
    let passCount = results.filter(\.passed).count
    let overall = results.isEmpty ? 0 : results.map(\.score).reduce(0, +) / Double(results.count)
    var summary = "## \(title)\n\n**통과 \(passCount)/\(results.count)** · 평균 점수 \(String(format: "%.1f%%", overall * 100))\n\n"
    summary += table({ $0.category }, "분류") + "\n" + table({ $0.degrade }, "손상") + "\n"
    summary += "### 실패\n\n"
    for r in results where !r.passed {
        summary += "- `\(r.id)`: " + r.checks.filter { !$0.ok }.map { "\($0.name) — \($0.detail)" }.joined(separator: "; ") + "\n"
    }
    return summary
}
