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
    /// 사진에서 찾은 쌓은 분수 (막대 + 따로 읽은 분자·분모)
    var fractions: [DebugLine]? = nil
    var notes: [String]? = nil
    /// 수학이 아닌 과목: 사진마다 (펜 지운 사진, 원래 사진) 합치기 전 두 번 읽은 줄 + 동그라미 → 리눅스에서 합치기부터 다시 채점
    var subjectReadings: [SubjectReadingDump]? = nil
    var subjectChosen: Int? = nil
    /// 학생 필기 사진: 읽은 글에 섞인 필기, 필기 지우기 기록, 지우기 없이 읽은 결과(전)
    var leaked: [String]? = nil
    var handwriting: [String]? = nil
    var before: BeforeResult? = nil
}

/// 필기 지우기 없이 읽은 결과 (고치기 전과 비교)
struct BeforeResult: Codable {
    var text: String
    var leaked: [String]
    var checks: [Check]
    var score: Double
    var passed: Bool
}

struct SubjectReadingDump: Codable {
    var korean: [DebugLine]
    var english: [DebugLine]
    var circles: [[Double]]
}

func glyphDebug(_ lines: [OCRGlyphLine]) -> [DebugLine] {
    lines.map { DebugLine(text: $0.text, confidence: $0.confidence, box: rounded($0.box), chars: $0.charBoxes.map { $0.map(rounded) ?? [] }) }
}

func rect(_ v: [Double]) -> CGRect { CGRect(x: v[0], y: v[1], width: v[2], height: v[3]) }

func glyphLines(_ lines: [DebugLine]) -> [OCRGlyphLine] {
    lines.map { line in
        OCRGlyphLine(text: line.text, confidence: line.confidence, box: rect(line.box),
                     charBoxes: (line.chars ?? []).map { $0.count == 4 ? rect($0) : nil })
    }
}

func rounded(_ r: CGRect) -> [Double] {
    [r.minX, r.minY, r.width, r.height].map { (Double($0) * 100_000).rounded() / 100_000 }
}

/// 비교용: 띄어쓰기 없애고 기호 모양 통일
func norm(_ s: String) -> String {
    var t = s.replacingOccurrences(of: "²", with: "^2").replacingOccurrences(of: "³", with: "^3")
    t = t.replacingOccurrences(of: "⁺", with: "^+").replacingOccurrences(of: "⁻", with: "^-").replacingOccurrences(of: "¹", with: "^1")
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
    let scan = DoitProblemScan.scan(text, lowConfidence: unsure, math: spec.kind != "subject")
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
    if let leaks = e.leaks {
        let flat = flatText.lowercased()
        let found = leaks.filter { leak in leak.split(separator: "|").contains { flat.contains(norm(String($0)).lowercased()) } }
        result.leaked = found
        checks.append(Check(name: "필기 안 섞임", ok: found.isEmpty, detail: found.isEmpty ? "" : "섞인 필기: \(found)"))
    }
    if let hand = e.handAnswer {
        let printed = spec.kind == "subject" ? DoitSubjectNote.printedAnswer(in: text) : MathGrader.extractAnswer(from: text)
        let caught = printed.map { norm($0).hasPrefix(norm(hand)) } ?? false
        checks.append(Check(name: "필기 답 안 잡힘", ok: !caught, detail: caught ? "정답으로 잡힘: \(printed ?? "")" : ""))
    }
    if let items = e.boxItems {
        let got = (scan.boxItems ?? []).map(norm), want = items.map(norm)
        checks.append(Check(name: "<보기> \(want.count)개", ok: got == want, detail: got == want ? "" : "읽음 \(scan.boxItems ?? [])"))
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
    // 필기가 없는 사진인데 지운 것이 있으면 (잘못 지운 것 찾기)
    if !result.category.hasPrefix("hw-"), let hw = result.handwriting, let last = hw.last, !last.hasPrefix("지움 0px") {
        for line in hw { print("    필기?: \(line)") }
    }
    // 학생 필기 사진: 지우기 판단과 지우기 전 결과 (기준 맞추기용)
    if result.category.hasPrefix("hw-") {
        for line in result.handwriting ?? [] { print("    필기: \(line)") }
        if let b = result.before {
            print("    전: \(b.passed ? "✓" : "✗") 섞임 \(b.leaked) 글: \(b.text.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(240))")
        }
        if result.passed { print("    글: \(result.text.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(240))") }
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

// MARK: - 학생 필기 사진 요약 (전: 필기 지우기 없이 · 후: 지금 코드)

func editDistance(_ a: [Character], _ b: [Character]) -> Int {
    guard !a.isEmpty else { return b.count }
    guard !b.isEmpty else { return a.count }
    var previous = Array(0...b.count)
    for i in 1...a.count {
        var current = [i] + Array(repeating: 0, count: b.count)
        for j in 1...b.count {
            current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
        }
        previous = current
    }
    return previous[b.count]
}

func handwritingSummary(_ results: [CaseResult]) -> String {
    let hw = results.filter { $0.category.hasPrefix("hw-") }
    guard !hw.isEmpty else { return "" }
    let marked = hw.filter { !$0.id.contains("-none__") }
    let plain = hw.filter { $0.id.contains("-none__") }
    func base(_ id: String) -> String {
        // hw-<문제>-<필기>__<손상> → hw-<문제>-none__clean
        let head = id.components(separatedBy: "__")[0]
        let parts = head.components(separatedBy: "-")
        return parts.dropLast().joined(separator: "-") + "-none__clean"
    }
    let reference = Dictionary(plain.map { ($0.id, norm($0.text)) }, uniquingKeysWith: { a, _ in a })
    func printedRate(_ checks: [[Check]]) -> (Int, Int) {
        let printed = checks.flatMap { $0.filter { !$0.name.hasPrefix("필기") } }
        return (printed.filter(\.ok).count, printed.count)
    }
    func leakRate(_ leaked: [[String]]) -> Int { leaked.filter { !$0.isEmpty }.count }
    func answerCaught(_ checks: [[Check]]) -> Int { checks.filter { $0.contains { $0.name == "필기 답 안 잡힘" && !$0.ok } }.count }
    func diff(_ texts: [(String, String)]) -> Double {
        let rates = texts.compactMap { id, text -> Double? in
            guard let ref = reference[base(id)], !ref.isEmpty else { return nil }
            return Double(editDistance(Array(norm(text)), Array(ref))) / Double(ref.count)
        }
        return rates.isEmpty ? 0 : rates.reduce(0, +) / Double(rates.count)
    }
    let afterChecks = marked.map(\.checks), beforeChecks = marked.compactMap { $0.before?.checks }
    let pa = printedRate(afterChecks), pb = printedRate(beforeChecks)
    let leakTotal = marked.map { ($0.leaked ?? []).count }.reduce(0, +)
    let leakTokens = marked.compactMap { r -> Int? in r.checks.contains { $0.name == "필기 안 섞임" } ? 1 : nil }.count
    let beforeLeakTotal = marked.compactMap { $0.before?.leaked.count }.reduce(0, +)
    let withAnswer = marked.filter { $0.checks.contains { $0.name == "필기 답 안 잡힘" } }.count
    let plainPrinted = printedRate(plain.map(\.checks)), plainBefore = printedRate(plain.compactMap { $0.before?.checks })
    func pct(_ a: Int, _ b: Int) -> String { b == 0 ? "-" : String(format: "%.1f%%", Double(a) * 100 / Double(b)) }
    var out = "## 학생 필기 사진 (필기 \(marked.count)장 · 필기 없는 같은 문제 \(plain.count)장)\n\n"
    out += "| | 전 (지우기 없음) | 후 |\n|---|---|---|\n"
    out += "| 필기 글이 섞인 사진 | \(leakRate(marked.compactMap { $0.before?.leaked }))/\(marked.count) (\(pct(leakRate(marked.compactMap { $0.before?.leaked }), marked.count))) | \(leakRate(marked.map { $0.leaked ?? [] }))/\(marked.count) (\(pct(leakRate(marked.map { $0.leaked ?? [] }), marked.count))) |\n"
    out += "| 섞인 필기 조각 | \(beforeLeakTotal) | \(leakTotal) |\n"
    out += "| 써 넣은 답이 정답으로 잡힘 | \(answerCaught(beforeChecks))/\(withAnswer) | \(answerCaught(afterChecks))/\(withAnswer) |\n"
    out += "| 인쇄 검사 (필기 사진) | \(pb.0)/\(pb.1) (\(pct(pb.0, pb.1))) | \(pa.0)/\(pa.1) (\(pct(pa.0, pa.1))) |\n"
    out += "| 인쇄 검사 (필기 없는 사진) | \(plainBefore.0)/\(plainBefore.1) | \(plainPrinted.0)/\(plainPrinted.1) |\n"
    out += "| 필기 없는 읽기와 글자 차이 | \(String(format: "%.1f%%", diff(marked.compactMap { r in r.before.map { (r.id, $0.text) } }) * 100)) | \(String(format: "%.1f%%", diff(marked.map { ($0.id, $0.text) }) * 100)) |\n"
    out += "\n필기 검사가 있는 사진 \(leakTokens)장\n\n### 필기가 섞인 사진 (후)\n\n"
    for r in marked where !(r.leaked ?? []).isEmpty { out += "- `\(r.id)`: \(r.leaked ?? [])\n" }
    // 펜·손상별
    var byTag: [String: (n: Int, before: Int, after: Int)] = [:]
    for r in marked {
        let head = r.id.components(separatedBy: "__")
        let tag = (head[0].components(separatedBy: "-").last ?? "") + "/" + (head.count > 1 ? head[1] : "")
        var e = byTag[tag] ?? (0, 0, 0)
        e.n += 1
        if !(r.before?.leaked ?? []).isEmpty { e.before += 1 }
        if !(r.leaked ?? []).isEmpty { e.after += 1 }
        byTag[tag] = e
    }
    out += "\n| 필기/손상 | 사진 | 섞임 전 | 섞임 후 |\n|---|---|---|---|\n"
    for (tag, e) in byTag.sorted(by: { $0.key < $1.key }) { out += "| \(tag) | \(e.n) | \(e.before) | \(e.after) |\n" }
    return out
}
