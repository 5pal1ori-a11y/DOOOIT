import AppKit
import CoreGraphics
import Foundation
import ImageIO

// 사진 테스트 실행: 앱과 같은 OCRCore/MathOCRFixer/WordParser/DoitProblemScan으로 읽고 정답과 비교
//   ocr-runner <cases 폴더> [이름 필터] → 결과를 화면에 + results.json, summary.md

let casesDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ocr-cases")
let filter = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ""
let jobs = Int(ProcessInfo.processInfo.environment["OCR_JOBS"] ?? "") ?? 3

struct Check: Codable {
    var name: String
    var ok: Bool
    var detail: String
}

struct DebugLine: Codable {
    var text: String
    var confidence: Float
    var box: [Double]
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
    var mathLines: [DebugLine] = []
    var baseText = ""
    var readings: [String] = []
    var words: [String] = []
    var wordLines: [[DebugLine]] = []
}

func loadImage(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
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
    lines.map { DebugLine(text: $0.text, confidence: $0.confidence,
                          box: [$0.box.minX, $0.box.minY, $0.box.width, $0.box.height].map { (Double($0) * 1000).rounded() / 1000 }) }
}

/// 앱의 UITextChecker 철자 확인과 같은 일 (맥: NSSpellChecker)
@MainActor
func spellChecked(_ word: ParsedWord) -> ParsedWord {
    let checker = NSSpellChecker.shared
    var result = word
    var term = word.term
    for token in word.term.split(separator: " ").map(String.init) {
        guard token.count >= 3, token.allSatisfy({ $0.isASCII && $0.isLetter }) else { continue }
        let range = checker.checkSpelling(of: token, startingAt: 0, language: "en_US", wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
        guard range.location != NSNotFound else { continue }
        result.unsure = true
        let guesses = checker.guesses(forWordRange: range, in: token, language: "en_US", inSpellDocumentWithTag: 0) ?? []
        if let guess = guesses.first(where: { OCRService.editDistance($0.lowercased(), token.lowercased()) == 1 && !$0.contains(" ") }) {
            let fixed = token.first?.isUppercase == true ? guess : guess.lowercased()
            term = term.replacingOccurrences(of: token, with: fixed)
        }
    }
    result.term = term
    return result
}

func runProblem(_ spec: CaseSpec, image: CGImage, result: inout CaseResult) async {
    // 앱: 앨범 사진은 먼저 반듯하게 편 뒤 readMathProblemDetailed → DoitProblemScan.scan
    let flat = await OCRService.straightened(image)
    result.straightened = flat != nil
    let source = flat ?? OCRService.scaled(image, maxDimension: 3000)
    let lines = (try? await OCRService.recognizeMath(source)) ?? []
    let base = MathOCRFixer.fix(OCRService.printedText(from: lines))
    var text = base
    if !base.isEmpty {
        let readings = await OCRService.multiPassRead(source)
        result.readings = readings
        text = OCRService.bestReading(base: base, others: readings).text
    }
    let scan = DoitProblemScan.scan(text, lowConfidence: OCRService.unsureLines(lines))
    result.mathLines = debugLines(lines)
    result.baseText = base
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

func runWords(_ spec: CaseSpec, image: CGImage, result: inout CaseResult) async {
    let flat = await OCRService.straightened(image)
    result.straightened = flat != nil
    let source = flat ?? OCRService.scaled(image, maxDimension: 3000)
    // 앱: readWords = 원래 사진 + 고대비 사진 읽기 → bestWords → 철자 확인 → 뜻 있는 것만 보여 줌
    let first = (try? await OCRService.recognize(source)) ?? []
    var second: [OCRLine] = []
    if let enhanced = OCRService.enhancedForText(source) { second = (try? await OCRService.recognize(enhanced)) ?? [] }
    let best = OCRService.bestWords([first, second])
    var words = await MainActor.run { best.map(spellChecked) }
    let withMeaning = words.filter { !$0.meaning.trimmingCharacters(in: .whitespaces).isEmpty }
    if !withMeaning.isEmpty { words = withMeaning }
    result.wordLines = [debugLines(first), debugLines(second)]
    result.words = words.map { "\($0.term) = \($0.meaning)\($0.unsure ? " (확인)" : "")" }

    var checks: [Check] = []
    var missing: [String] = []
    var wrong: [String] = []
    for pair in spec.expect.words {
        guard let found = words.first(where: { $0.term.lowercased() == pair.term.lowercased() }) else { missing.append(pair.term); continue }
        if !norm(found.meaning).contains(norm(pair.meaning)) { wrong.append("\(pair.term): \(found.meaning) (기대 \(pair.meaning))") }
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

func run(_ spec: CaseSpec, dir: URL) async -> CaseResult {
    let start = Date()
    var result = CaseResult(id: spec.id, category: spec.category, degrade: spec.degrade, passed: false, score: 0, seconds: 0, checks: [])
    guard let image = loadImage(dir.appendingPathComponent(spec.image)) else {
        result.checks = [Check(name: "사진 열기", ok: false, detail: spec.image)]
        return result
    }
    if spec.kind == "words" { await runWords(spec, image: image, result: &result) } else { await runProblem(spec, image: image, result: &result) }
    let ok = result.checks.filter(\.ok).count
    result.score = result.checks.isEmpty ? 0 : Double(ok) / Double(result.checks.count)
    result.passed = !result.checks.isEmpty && ok == result.checks.count
    result.seconds = Date().timeIntervalSince(start)
    return result
}

let data = try Data(contentsOf: casesDir.appendingPathComponent("cases.json"))
let specs = try JSONDecoder().decode([CaseSpec].self, from: data).filter { filter.isEmpty || $0.id.contains(filter) }
print("사진 \(specs.count)장 · 동시에 \(jobs)장씩")

var results: [CaseResult] = []
await withTaskGroup(of: CaseResult.self) { group in
    var next = 0
    func add() {
        guard next < specs.count else { return }
        let spec = specs[next]
        let dir = casesDir
        next += 1
        group.addTask { await run(spec, dir: dir) }
    }
    for _ in 0..<jobs { add() }
    while let result = await group.next() {
        results.append(result)
        let mark = result.passed ? "✓" : "✗"
        print("\(mark) \(result.id)  \(String(format: "%.0f%%", result.score * 100))  \(String(format: "%.1fs", result.seconds))")
        if !result.passed {
            for check in result.checks where !check.ok { print("    · \(check.name): \(check.detail)") }
            print("    글: \(result.text.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(300))")
            if !result.words.isEmpty { print("    단어: \(result.words.joined(separator: " | ").prefix(400))") }
        }
        add()
    }
}
results.sort { $0.id < $1.id }

// 분류별 · 손상별 합계
func table(_ key: (CaseResult) -> String, title: String) -> String {
    var groups: [String: [CaseResult]] = [:]
    for r in results { groups[key(r), default: []].append(r) }
    var out = "| \(title) | 통과 | 점수 |\n|---|---|---|\n"
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
var summary = "## 사진 OCR 테스트\n\n**통과 \(passCount)/\(results.count)** · 평균 점수 \(String(format: "%.1f%%", overall * 100))\n\n"
summary += table({ $0.category }, title: "분류") + "\n" + table({ $0.degrade }, title: "손상") + "\n"
summary += "### 실패\n\n"
for r in results where !r.passed {
    summary += "- `\(r.id)`: " + r.checks.filter { !$0.ok }.map { "\($0.name) — \($0.detail)" }.joined(separator: "; ") + "\n"
}
print("\n" + summary)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(results).write(to: casesDir.appendingPathComponent("results.json"))
try summary.write(to: casesDir.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
