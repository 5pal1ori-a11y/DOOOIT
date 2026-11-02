import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Vision

// 사진 테스트 실행 (맥): 앱과 같은 OCRCore/OCRText/MathOCRFixer/WordParser/DoitProblemScan으로 읽고 정답과 비교
//   ocr-runner <cases 폴더> [이름 필터] → 결과를 화면에 + results.json, summary.md

let casesDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ocr-cases")
let filter = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ""
let jobs = Int(ProcessInfo.processInfo.environment["OCR_JOBS"] ?? "") ?? 3

func loadImage(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
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

/// 앱: 앨범 사진은 먼저 반듯하게 편 뒤 readMathProblemDetailed → DoitProblemScan.scan
func runProblem(_ spec: CaseSpec, image: CGImage, result: inout CaseResult) async {
    let flat = await OCRService.straightened(image)
    result.straightened = flat != nil
    let source = flat ?? OCRService.scaled(image, maxDimension: 3000)
    let trace = await OCRService.readMathProblemTrace(source)
    result.skew = trace.skew
    result.mathLines = debugLines(trace.lines)
    result.unsure = trace.unsure
    result.baseText = trace.base
    result.readings = trace.readings
    await rawDump(await OCRService.deskewed(source), result: &result)
    evaluateProblem(spec, text: trace.text, unsure: trace.unsure, result: &result)
}

/// 원인 찾기용: Vision이 읽은 그대로 (merge 전)
func rawDump(_ image: CGImage, result: inout CaseResult) async {
    let prepared = OCRService.scaled(image, maxDimension: 3000)
    async let korean = try? OCRService.observe(prepared, languages: ["ko-KR", "en-US"], correction: true)
    async let english = try? OCRService.observe(prepared, languages: ["en-US"], correction: false)
    async let rects = OCRService.detectRectangles(prepared)
    async let shapes = OCRService.detectCircles(prepared)
    func dump(_ observations: [VNRecognizedTextObservation]) -> [DebugLine] {
        observations.compactMap { o in
            guard let c = o.topCandidates(1).first else { return nil }
            let text = c.string
            var chars: [[Double]] = []
            var index = text.startIndex
            while index < text.endIndex {
                let next = text.index(after: index)
                if text[index].isWhitespace { chars.append([]) } else {
                    chars.append(((try? c.boundingBox(for: index..<next))?.map { rounded($0.boundingBox) }) ?? [])
                }
                index = next
            }
            return DebugLine(text: text, confidence: c.confidence, box: rounded(o.boundingBox), chars: chars)
        }
    }
    let k = await korean ?? []
    result.rawKorean = dump(k)
    result.rawEnglish = dump(await english ?? [])
    result.rects = await rects.map(rounded)
    let all = await shapes
    let heights = k.map(\.boundingBox.height).sorted()
    let median = heights.isEmpty ? 0 : heights[heights.count / 2]
    result.shapeCount = all.count
    result.circles = all.filter { MathOCRFixer.isChoiceCircle($0, lineHeight: median) }.map { rounded($0.box) }
    result.fractions = await OCRService.stackedFractions(prepared, lines: k.map(\.boundingBox))
        .map { DebugLine(text: $0.text, confidence: 1, box: rounded($0.box)) }
}

/// 앱: readWords = 바로 세우기 → 원래 사진 + 고대비 사진 읽기 → bestWords → 철자 확인 → 뜻 있는 것만 보여 줌
func runWords(_ spec: CaseSpec, image: CGImage, result: inout CaseResult) async {
    let flat = await OCRService.straightened(image)
    result.straightened = flat != nil
    let source = flat ?? OCRService.scaled(image, maxDimension: 3000)
    let trace = await OCRService.readWordsTrace(source)
    result.skew = trace.skew
    let best = trace.words
    let first = trace.plain, second = trace.contrast
    let words = await MainActor.run { best.map(spellChecked) }
    result.wordLines = [debugLines(first), debugLines(second)]
    evaluateWords(spec, words: words, result: &result)
}

func run(_ spec: CaseSpec, dir: URL) async -> CaseResult {
    let start = Date()
    var result = CaseResult(id: spec.id, category: spec.category, degrade: spec.degrade, passed: false, score: 0, seconds: 0, checks: [])
    guard let image = loadImage(dir.appendingPathComponent(spec.image)) else {
        result.checks = [Check(name: "사진 열기", ok: false, detail: spec.image)]
        return result
    }
    if spec.kind == "words" { await runWords(spec, image: image, result: &result) } else { await runProblem(spec, image: image, result: &result) }
    finishScore(&result)
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
        printResult(result)
        add()
    }
}
results.sort { $0.id < $1.id }

let summary = summarize(results, title: "사진 OCR 테스트")
print("\n" + summary)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(results).write(to: casesDir.appendingPathComponent("results.json"))
try summary.write(to: casesDir.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
