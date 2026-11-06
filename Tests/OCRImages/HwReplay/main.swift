import Foundation

// 필기 판정 다시 돌리기 (리눅스·맥): 맥 사진 테스트(OCR_HWDUMP=1)가 로그에 남긴 줄·잉크 값으로
// HandwritingFilter.tokens만 지금 코드로 다시 판정해서, 필기를 놓친 곳(누출)과 인쇄를 필기로 본 곳(오탐)을 셈
//   hwreplay <dump.jsonl> [이름 필터] [-v]
// 정답은 사진 정답의 leaks(필기 글)로 줄·조각마다 붙임: 필기 줄 = 줄 글자가 필기 글 하나와 70% 이상 겹침

let args = CommandLine.arguments
let path = args.count > 1 ? args[1] : "dump.jsonl"
let filter = args.count > 2 && args[2] != "-v" ? args[2] : ""
let verbose = args.contains("-v")

struct Dump: Codable {
    var id: String
    var category: String
    var leaks: [String]?
    var answer: String?
    var lines: [HandwritingFilter.Line]
}

func norm(_ s: String) -> String {
    var t = s.replacingOccurrences(of: "²", with: "^2").replacingOccurrences(of: "³", with: "^3")
    t = t.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "–", with: "-")
    t = t.replacingOccurrences(of: "＝", with: "=").replacingOccurrences(of: "，", with: ",")
    return String(t.filter { !$0.isWhitespace }.lowercased())
}

func lcs(_ a: [Character], _ b: [Character]) -> Int {
    guard !a.isEmpty, !b.isEmpty else { return 0 }
    var prev = [Int](repeating: 0, count: b.count + 1)
    for i in 1...a.count {
        var cur = [Int](repeating: 0, count: b.count + 1)
        for j in 1...b.count { cur[j] = a[i - 1] == b[j - 1] ? prev[j - 1] + 1 : max(prev[j], cur[j - 1]) }
        prev = cur
    }
    return prev[b.count]
}

let decoder = JSONDecoder()
let raw = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
var dumps: [Dump] = []
for line in raw.split(separator: "\n") {
    if let d = try? decoder.decode(Dump.self, from: Data(line.utf8)), filter.isEmpty || d.id.contains(filter) { dumps.append(d) }
}
dumps.sort { $0.id < $1.id }

enum Truth { case hand, printed, unknown }

struct Miss { var id: String; var text: String; var score: Double; var reasons: [String] }
var leakPhotos = 0, markedPhotos = 0, fpPhotos = 0, plainPhotos = 0
var leakTokens = 0, handTokens = 0, fpTokens = 0, printedTokens = 0
var misses: [Miss] = [], falses: [Miss] = []
var byGroup: [String: (n: Int, leak: Int)] = [:]
var markedFP = 0

for d in dumps {
    let marked = d.leaks != nil && !d.id.contains("-none__")
    let alts = (d.leaks ?? []).flatMap { $0.split(separator: "|").map { norm(String($0)) } }
    let joined = alts.joined()
    guard let ref = HandwritingFilter.reference(d.lines) else { continue }
    let tokens = HandwritingFilter.tokens(d.lines, reference: ref, mode: .text)
    var photoLeak = false, photoFP = false
    for t in tokens {
        let line = d.lines[t.line]
        let nl = Array(norm(line.text))
        let tn = norm(t.text)
        var truth = Truth.printed
        if marked, !alts.isEmpty {
            let best = alts.map { lcs(nl, Array($0)) }.max() ?? 0
            let lineHand = nl.count >= 2 && Double(best) >= Double(nl.count) * 0.7
            let mixed = alts.contains { nl.count > $0.count && String(nl).contains($0) }
            if lineHand { truth = .hand }
            else if mixed || best >= 3 {
                if tn.count >= 2, alts.contains(where: { $0.contains(tn) }) || joined.contains(tn) { truth = .hand }
                else if tn.count < 2 { truth = .unknown }
            }
        }
        if truth == .hand {
            handTokens += 1
            if !t.hand { leakTokens += 1; photoLeak = true; misses.append(Miss(id: d.id, text: t.text, score: t.score, reasons: t.reasons)) }
        } else if truth == .printed {
            printedTokens += 1
            if t.hand { fpTokens += 1; photoFP = true; falses.append(Miss(id: d.id, text: t.text, score: t.score, reasons: t.reasons)) }
        }
    }
    if marked { markedPhotos += 1; if photoLeak { leakPhotos += 1 }; if photoFP { markedFP += 1 } } else { plainPhotos += 1; if photoFP { fpPhotos += 1 } }
    let group = d.id.hasPrefix("hw-") ? (d.id.components(separatedBy: "__")[0].components(separatedBy: "-").last ?? "?") : "plain"
    var e = byGroup[group] ?? (0, 0); e.n += 1; if photoLeak { e.leak += 1 }; byGroup[group] = e
}

print("필기 사진 \(markedPhotos)장 중 필기가 남은 사진 \(leakPhotos)장 (\(markedPhotos == 0 ? 0 : leakPhotos * 100 / markedPhotos)%) · 필기 조각 \(handTokens)개 중 놓친 것 \(leakTokens)개")
print("필기 사진에서 인쇄를 필기로 본 사진 \(markedFP)장")
print("필기 없는 사진 \(plainPhotos)장 중 인쇄를 필기로 본 사진 \(fpPhotos)장 · 인쇄 조각 \(printedTokens)개 중 필기로 본 것 \(fpTokens)개")
print("펜별:", byGroup.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value.leak)/\($0.value.n)" }.joined(separator: "  "))
if verbose {
    print("\n== 놓친 필기")
    for m in misses { print("  \(m.id)  \(m.text)  \(String(format: "%.1f", m.score)) \(m.reasons.joined(separator: ","))") }
    print("\n== 인쇄를 필기로 봄")
    for m in falses { print("  \(m.id)  \(m.text)  \(String(format: "%.1f", m.score)) \(m.reasons.joined(separator: ","))") }
}
