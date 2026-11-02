import Foundation
#if canImport(AppKit)
import AppKit
#endif

// PaddleOCR-VL 비교 채점 (맥·리눅스): PaddleOCR-VL이 읽은 글을 앱이 OCR 다음에 쓰는 코드 그대로 돌려 Vision 결과와 비교
//   ocr-paddle-score <cases 폴더> <Vision results.json | -> <이름=paddle.json>... → 표를 화면에 + comparison.md, paddle-results.json
// 방법(variant)
// - app:   LaTeX → 앱 글 모양 → 수학: MathOCRFixer.fix / 과목: 보기 번호 정리(subjectText와 같은 단계) → DoitProblemScan
//          단어장: "Spotting:" 줄 상자 + "OCR:" 글 두 읽기 → WordParser(bestWords, 앱의 두 번 읽기와 같음) + 철자 확인
// - latex: LaTeX → 앱 글 모양만 (앱 교정 없이) → DoitProblemScan / 단어장: "OCR:" 글(표는 칸마다 상자) → WordParser
// - raw:   모델 글 그대로 → DoitProblemScan / 단어장: "OCR:" 글 줄마다 → WordParser

struct PaddleReading: Codable {
    var id: String
    var text: String
    var seconds: Double
    var promptTokens: Int?
    var generationTokens: Int?
    var peakGB: Double?
    var error: String?
    /// 단어장: "Spotting:"으로 읽은 글자+자리 (<|LOC_n|>)
    var spot: String?
    var spotSeconds: Double?
    var spotTokens: Int?
    var spotError: String?
}

struct PaddleRun: Codable {
    var meta: [String: String]
    var cases: [PaddleReading]
}

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("ocr-paddle-score <cases 폴더> <Vision results.json | -> <이름=paddle.json>...")
    exit(2)
}
let dir = URL(fileURLWithPath: args[1])
let specs = try JSONDecoder().decode([CaseSpec].self, from: Data(contentsOf: dir.appendingPathComponent("cases.json")))
let vision: [CaseResult] = args[2] == "-" ? [] : (try JSONDecoder().decode([CaseResult].self, from: Data(contentsOf: URL(fileURLWithPath: args[2]))))
var engines: [(name: String, run: PaddleRun)] = []
for arg in args.dropFirst(3) {
    let parts = arg.split(separator: "=", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { continue }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: parts[1])),
          let run = try? JSONDecoder().decode(PaddleRun.self, from: data) else {
        print("✗ 읽지 못함: \(parts[1])")
        continue
    }
    engines.append((parts[0], run))
}

#if canImport(AppKit)
/// 앱의 UITextChecker 철자 확인과 같은 일 (Runner/main.swift와 같음)
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
        if let guess = guesses.first(where: { OCRService.isLikelyMisread(token: token, guess: $0) }) {
            let fixed = token.first?.isUppercase == true ? guess : guess.lowercased()
            term = term.replacingOccurrences(of: token, with: fixed)
        }
    }
    result.term = term
    return result
}
let spellCheck = true
#else
func spellChecked(_ word: ParsedWord) -> ParsedWord { word }
let spellCheck = false
#endif

let variants = ["app", "latex", "raw"]

func score(_ spec: CaseSpec, _ reading: PaddleReading, variant: String) -> CaseResult {
    var result = CaseResult(id: spec.id, category: spec.category, degrade: spec.degrade, passed: false, score: 0, seconds: reading.seconds, checks: [])
    if let error = reading.error {
        result.checks = [Check(name: "읽기", ok: false, detail: error)]
        return result
    }
    let raw = reading.text
    if spec.kind == "words" {
        let rows: [[String]] = variant == "raw"
            ? raw.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { [$0] }
            : PaddleText.rows(raw)
        // app: 앱처럼 두 번 읽은 것(Spotting 줄 상자 + OCR 글)을 bestWords로 (더 많이 찾은 쪽, 빠진 뜻은 다른 쪽에서)
        var readings = [PaddleText.lines(rows)]
        if variant == "app", let spot = reading.spot {
            let spotted = PaddleText.spotLines(spot)
            if !spotted.isEmpty { readings.insert(spotted, at: 0) }
        }
        var words = OCRService.bestWords(readings)
        if variant == "app" { words = MainActor.assumeIsolated { words.map(spellChecked) } }
        evaluateWords(spec, words: words, result: &result)
        result.text = raw
    } else {
        let text: String
        switch variant {
        case "raw": text = raw
        case "latex": text = PaddleText.toApp(raw)
        default:
            let converted = PaddleText.toApp(raw)
            text = spec.kind == "subject"
                ? MathOCRFixer.cleanChoiceMarks(MathOCRFixer.normalizeChoices(converted))
                : MathOCRFixer.fix(converted)
        }
        evaluateProblem(spec, text: text, unsure: [], result: &result)
    }
    finishScore(&result)
    return result
}

/// 표의 묶음: 과목 분류(단어장은 하나로) + 사진 손상
func group(_ r: CaseResult) -> [String] {
    [r.category.hasPrefix("words") ? "words" : r.category, "손상: " + r.degrade, "전체"]
}
let groupOrder = ["math-choice", "math-blank", "math-short", "math-fraction", "math-root", "korean", "english", "science", "social", "words",
                  "손상: clean", "손상: mild", "손상: lowres", "손상: photo", "손상: desk", "손상: tilted", "전체"]

func stats(_ results: [CaseResult]) -> [String: (pass: Int, count: Int, score: Double)] {
    var groups: [String: [CaseResult]] = [:]
    for r in results { for g in group(r) { groups[g, default: []].append(r) } }
    return groups.mapValues { rs in (rs.filter(\.passed).count, rs.count, rs.map(\.score).reduce(0, +) / Double(max(rs.count, 1))) }
}

func cell(_ s: (pass: Int, count: Int, score: Double)?) -> String {
    guard let s else { return "-" }
    return "\(s.pass)/\(s.count) · \(String(format: "%.0f%%", s.score * 100))"
}

var all: [String: [CaseResult]] = [:]
var report = "## PaddleOCR-VL vs Vision\n\n"
let specByID = Dictionary(uniqueKeysWithValues: specs.map { ($0.id, $0) })
for engine in engines {
    report += "- **\(engine.name)**: " + engine.run.meta.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ") + "\n"
    for variant in variants {
        let results = engine.run.cases.compactMap { reading in specByID[reading.id].map { score($0, reading, variant: variant) } }
        all["\(engine.name)/\(variant)"] = results.sorted { $0.id < $1.id }
    }
}
// Vision은 PaddleOCR-VL이 읽은 사진만 (같은 사진끼리 비교)
let readIDs = Set(engines.flatMap { $0.run.cases.map(\.id) })
let visionSame = vision.filter { readIDs.isEmpty || readIDs.contains($0.id) }
report += "- 철자 확인(단어장 app): \(spellCheck ? "NSSpellChecker" : "없음 (리눅스)")\n\n"

var columns: [(String, [CaseResult])] = []
if !visionSame.isEmpty { columns.append(("Vision (앱)", visionSame)) }
for engine in engines { for variant in variants { columns.append(("\(engine.name) \(variant)", all["\(engine.name)/\(variant)"] ?? [])) } }
let table = columns.map { ($0.0, stats($0.1)) }
report += "| 묶음 | " + table.map(\.0).joined(separator: " | ") + " |\n"
report += "|---|" + table.map { _ in "---" }.joined(separator: "|") + "|\n"
for g in groupOrder where table.contains(where: { $0.1[g] != nil }) {
    report += "| \(g) | " + table.map { cell($0.1[g]) }.joined(separator: " | ") + " |\n"
}

// 속도
report += "\n### 속도 (사진 한 장)\n\n| 엔진 | 평균 | 중앙값 | 최대 | 첫 장 제외 평균 |\n|---|---|---|---|---|\n"
func speedRow(_ name: String, _ seconds: [Double]) -> String {
    guard !seconds.isEmpty else { return "| \(name) | - | - | - | - |\n" }
    let sorted = seconds.sorted()
    let rest = seconds.count > 1 ? Array(seconds.dropFirst()) : seconds
    return "| \(name) | \(String(format: "%.2fs", seconds.reduce(0, +) / Double(seconds.count))) | \(String(format: "%.2fs", sorted[sorted.count / 2])) | \(String(format: "%.2fs", sorted.last!)) | \(String(format: "%.2fs", rest.reduce(0, +) / Double(rest.count))) |\n"
}
if !visionSame.isEmpty { report += speedRow("Vision (앱)", visionSame.map(\.seconds)) }
for engine in engines {
    report += speedRow(engine.name + " OCR:", engine.run.cases.map(\.seconds))
    let spot = engine.run.cases.compactMap(\.spotSeconds)
    if !spot.isEmpty { report += speedRow(engine.name + " Spotting: (단어장)", spot) }
}
for engine in engines {
    let tokens = engine.run.cases.compactMap(\.generationTokens)
    let prompt = engine.run.cases.compactMap(\.promptTokens)
    if !tokens.isEmpty {
        report += "\n\(engine.name): 평균 입력 토큰 \(prompt.reduce(0, +) / max(prompt.count, 1)), 평균 출력 토큰 \(tokens.reduce(0, +) / tokens.count), 최대 출력 \(tokens.max() ?? 0)"
    }
}
report += "\n"

// 엇갈린 결과 (원인 보기)
for engine in engines {
    let app = all["\(engine.name)/app"] ?? []
    let visionByID = Dictionary(uniqueKeysWithValues: visionSame.map { ($0.id, $0) })
    let paddleOnly = app.filter { $0.passed && visionByID[$0.id]?.passed == false }.map(\.id)
    let visionOnly = app.filter { !$0.passed && visionByID[$0.id]?.passed == true }.map(\.id)
    report += "\n### \(engine.name) app: Vision은 틀리고 PaddleOCR-VL만 맞힘 (\(paddleOnly.count))\n\n" + paddleOnly.map { "`\($0)`" }.joined(separator: " ") + "\n"
    report += "\n### \(engine.name) app: Vision만 맞힘 (\(visionOnly.count))\n\n" + visionOnly.map { "`\($0)`" }.joined(separator: " ") + "\n"
}

// 사진마다 (실패만): 무엇을 틀렸는지 + 모델 원래 글
for engine in engines {
    print("\n===== \(engine.name) (app) 사진마다 =====")
    let byID = Dictionary(uniqueKeysWithValues: engine.run.cases.map { ($0.id, $0) })
    for r in all["\(engine.name)/app"] ?? [] {
        printResult(r)
        if !r.passed, let raw = byID[r.id]?.text {
            print("    원문: \(raw.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(500))")
        }
    }
}
print("\n" + report)
try report.write(to: dir.appendingPathComponent("comparison.md"), atomically: true, encoding: .utf8)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(all).write(to: dir.appendingPathComponent("paddle-results.json"))
