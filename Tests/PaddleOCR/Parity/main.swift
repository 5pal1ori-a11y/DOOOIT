import CoreGraphics
import Foundation
import ImageIO

// 정밀 인식 맥 비교: 앱의 Swift 코드(PaddleOCREngine)로 테스트 사진을 읽고, 같은 사진을 파이썬 mlx-vlm(비교 실험에서 129/141)으로
// 읽은 글과 견줌 (토큰 수 · 글이 같은지 · 앱 글 모양으로 바꾼 뒤 같은지)
//   PaddleParity <cases 폴더> <ids.json> <모델 폴더> <출력 swift.json> [python.json]

struct Case: Decodable { var id: String; var kind: String; var image: String }
struct Reading: Codable {
    var id: String
    var text: String
    var seconds: Double
    var promptTokens: Int?
    var generationTokens: Int?
    var error: String?
}
struct Run: Codable { var meta: [String: String]; var cases: [Reading] }

let args = CommandLine.arguments
guard args.count >= 5 else {
    print("PaddleParity <cases 폴더> <ids.json> <모델 폴더> <출력 swift.json> [python.json]")
    exit(2)
}
let dir = URL(fileURLWithPath: args[1])
let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: dir.appendingPathComponent("cases.json")))
let ids = try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
let byID = Dictionary(uniqueKeysWithValues: cases.map { ($0.id, $0) })
let engine = PaddleOCREngine()

let t0 = Date()
try await engine.load(from: URL(fileURLWithPath: args[3]))
let loadSeconds = Date().timeIntervalSince(t0)
print(String(format: "모델 불러오기 %.1fs", loadSeconds))

var run = Run(meta: ["backend": "swift (DOOOIT PaddleOCREngine)", "load_s": String(format: "%.1f", loadSeconds)], cases: [])
for (k, id) in ids.enumerated() {
    guard let spec = byID[id] else { continue }
    let url = dir.appendingPathComponent(spec.image)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        run.cases.append(Reading(id: id, text: "", seconds: 0, error: "사진을 열지 못함"))
        continue
    }
    do {
        let r = try await engine.read(image, maxTokens: 1024, timeout: 300)
        run.cases.append(Reading(id: id, text: r.text, seconds: r.seconds, promptTokens: r.promptTokens, generationTokens: r.generatedTokens))
        print("[\(k + 1)/\(ids.count)] \(id)  \(String(format: "%.1fs", r.seconds))  \(r.promptTokens)→\(r.generatedTokens) tok\(r.repetitionStopped ? " (되풀이 멈춤)" : "")  \(r.text.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(300))")
    } catch {
        run.cases.append(Reading(id: id, text: "", seconds: 0, error: "\(error)"))
        print("[\(k + 1)/\(ids.count)] \(id)  ✗ \(error)")
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(run).write(to: URL(fileURLWithPath: args[4]))
}

// 파이썬 결과와 비교
guard args.count >= 6, let data = try? Data(contentsOf: URL(fileURLWithPath: args[5])),
      let python = try? JSONDecoder().decode(Run.self, from: data) else {
    print("파이썬 결과 없음 — 비교 생략")
    exit(0)
}
let pyByID = Dictionary(uniqueKeysWithValues: python.cases.map { ($0.id, $0) })
var exact = 0, sameApp = 0, sameTokens = 0, compared = 0, errors = 0
var report = "## 정밀 인식: Swift(앱 코드) vs 파이썬 mlx-vlm\n\n"
var diffs = ""
for swift in run.cases {
    guard let py = pyByID[swift.id] else { continue }
    compared += 1
    if swift.error != nil { errors += 1 }
    if swift.promptTokens == py.promptTokens { sameTokens += 1 }
    let a = swift.text.trimmingCharacters(in: .whitespacesAndNewlines), b = py.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if a == b { exact += 1 }
    let kind = byID[swift.id]?.kind ?? "problem"
    let appA = kind == "subject" ? PaddleOCRText.subjectText(a) : PaddleOCRText.mathText(a)
    let appB = kind == "subject" ? PaddleOCRText.subjectText(b) : PaddleOCRText.mathText(b)
    let squash = { (s: String) in s.filter { !$0.isWhitespace } }
    if squash(appA) == squash(appB) { sameApp += 1 } else {
        diffs += "- `\(swift.id)` (토큰 \(swift.promptTokens ?? -1) / \(py.promptTokens ?? -1))\n  - Swift: `\(appA.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(240))`\n  - 파이썬: `\(appB.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(240))`\n"
    }
}
let swiftSeconds = run.cases.map(\.seconds).filter { $0 > 0 }
let pySeconds = python.cases.filter { pyByID[$0.id] != nil && ids.contains($0.id) }.map(\.seconds)
func avg(_ xs: [Double]) -> String { xs.isEmpty ? "-" : String(format: "%.2fs", xs.reduce(0, +) / Double(xs.count)) }
report += "| 항목 | 값 |\n|---|---|\n"
report += "| 비교한 사진 | \(compared) |\n| 프롬프트 토큰 수 같음 | \(sameTokens)/\(compared) |\n| 모델 글 그대로 같음 | \(exact)/\(compared) |\n"
report += "| 앱 글 모양으로 바꾼 뒤 같음 (띄어쓰기 무시) | \(sameApp)/\(compared) |\n| Swift 오류 | \(errors) |\n"
report += "| 평균 시간 (Swift / 파이썬) | \(avg(swiftSeconds)) / \(avg(pySeconds)) |\n\n"
if !diffs.isEmpty { report += "### 다른 사진\n\n" + diffs }
print("\n" + report)
try report.write(to: URL(fileURLWithPath: args[4]).deletingLastPathComponent().appendingPathComponent("parity.md"), atomically: true, encoding: .utf8)
// 앱 글 기준으로 90% 넘게 같아야 통과 (부동소수 순서 차이로 가끔 한두 글자 갈릴 수 있음)
exit(compared > 0 && errors == 0 && Double(sameApp) >= Double(compared) * 0.9 ? 0 : 1)
