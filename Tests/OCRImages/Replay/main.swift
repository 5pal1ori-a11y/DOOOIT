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
    } else {
        let lines = ocrLines(old.mathLines)
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
