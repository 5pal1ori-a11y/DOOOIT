import Foundation

// 다시 채점 (리눅스·맥): 맥에서 저장한 Vision 결과(results.json)를 지금 코드의 글자 정리 단계로 다시 돌려 채점
//   ocr-replay <결과 폴더> [이름 필터]
// - 문제: recognizeMath 줄 → printedText → MathOCRFixer.fix → bestReading(multiPassRead) → DoitProblemScan
// - 단어장: 두 번 읽은 줄 → bestWords (철자 확인은 맥 전용이라 빠짐)
// Vision 단계(분수·지수·빈칸·동그라미 끼워 넣기, OCRCore.merge)를 고친 효과는 맥에서 다시 돌려야 보여요.

let dir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ocr-cases")
let filter = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ""
let specs = try JSONDecoder().decode([CaseSpec].self, from: Data(contentsOf: dir.appendingPathComponent("cases.json")))
let stored = try JSONDecoder().decode([CaseResult].self, from: Data(contentsOf: dir.appendingPathComponent("results.json")))
let specByID = Dictionary(uniqueKeysWithValues: specs.map { ($0.id, $0) })

var results: [CaseResult] = []
var changes: [String] = []
for old in stored where filter.isEmpty || old.id.contains(filter) {
    guard let spec = specByID[old.id] else { continue }
    var result = old
    result.checks = []
    if spec.kind == "words" {
        let words = OCRService.bestWords(old.wordLines.map(ocrLines))
        evaluateWords(spec, words: words, result: &result)
    } else if spec.kind == "subject", let readings = old.subjectReadings {
        // 합치기(두 번 읽은 줄 + 동그라미)부터 지금 코드로
        let merged = readings.map { OCRService.subjectMerge(korean: glyphLines($0.korean), english: glyphLines($0.english), circles: $0.circles.map(rect)) }
        let chosen = OCRService.chooseSubjectReading(merged)
        // 원인 찾기: OCR_DEBUG=<이름> 이면 사진마다 합친 줄을 보여 줌
        if let debug = ProcessInfo.processInfo.environment["OCR_DEBUG"], !debug.isEmpty, old.id.contains(debug) {
            for (k, lines) in merged.enumerated() {
                print("  [\(k)\(k == chosen.index ? " 고름" : "")] 동그라미 \(readings[k].circles.count)개")
                for line in lines { print("    \(String(format: "%.2f", line.confidence)) \(line.text)") }
            }
        }
        result.mathLines = debugLines(chosen.lines)
        result.subjectChosen = chosen.index
        let unsure = chosen.lines.filter { $0.confidence < 0.5 }.map { $0.text.trimmingCharacters(in: .whitespaces) }
        evaluateProblem(spec, text: OCRService.subjectText(chosen.lines), unsure: unsure, result: &result)
    } else if spec.kind == "subject" {
        let lines = ocrLines(old.mathLines)
        evaluateProblem(spec, text: OCRService.subjectText(lines), unsure: old.unsure, result: &result)
    } else {
        // 예전 결과에도 지금 신뢰도 보정을 적용 (같은 값이면 그대로)
        let lines = ocrLines(old.mathLines).map { OCRLine(text: $0.text, confidence: OCRService.adjustedConfidence($0.text, $0.confidence), box: $0.box) }
        let base = MathOCRFixer.fix(OCRService.printedText(from: lines))
        let text = base.isEmpty ? base : OCRService.bestReading(base: base, others: old.readings).text
        result.baseText = base
        evaluateProblem(spec, text: text, unsure: OCRService.unsureLines(lines), result: &result)
    }
    finishScore(&result)
    if result.passed != old.passed { changes.append("\(result.passed ? "＋ 새로 통과" : "－ 새로 실패") \(result.id)") }
    printResult(result)
    results.append(result)
}
print("\n" + summarize(results, title: "다시 채점 (저장된 Vision 결과)"))
print("이전: 통과 \(stored.filter { filter.isEmpty || $0.id.contains(filter) }.filter(\.passed).count)/\(results.count)")
for line in changes { print(line) }
