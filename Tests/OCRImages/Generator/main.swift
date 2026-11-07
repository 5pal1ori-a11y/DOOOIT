import CoreGraphics
import Foundation

// 테스트 사진 만들기: swift Generator/*.swift Shared/CaseSpec.swift → <출력 폴더>/images/*.jpg + cases.json

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ocr-cases")
let imageDir = outDir.appendingPathComponent("images")
try? FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)

/// 내용마다 깨끗한 사진 + 손상 두 가지 (돌아가며)
let problemDegrades: [Degrade] = [.mild, .photo, .lowres, .tilted, .desk]
let wordDegrades: [Degrade] = [.photo, .desk, .lowres, .tilted, .mild]

func variantStyle(_ base: Style, index: Int) -> Style {
    var s = base
    // 동그라미 번호: 글꼴 글자 ①와 직접 그린 원을 번갈아
    if index % 3 == 2 { s.circledGlyph = false }
    // 명조 본문
    if index % 4 == 1 { s.korean = "AppleMyungjo"; s.koreanBold = "AppleMyungjo" }
    // 글자 크기
    s.size = [40, 36, 44, 38][index % 4]
    return s
}

var specs: [CaseSpec] = []
var seed: UInt64 = 7

/// 사진 이름 필터 (읽기 쪽 필터와 같은 규칙: 부분 일치, 앞에 !를 붙이면 제외). 필터에 안 걸리는 사진은 그리지 않음 (손상 씨앗은 그대로 진행하므로
/// 걸린 사진은 필터 없이 만든 것과 똑같음) → 일부만 읽을 때 사진 만드는 시간이 줄어듦
let genFilter = ProcessInfo.processInfo.environment["OCR_GEN_FILTER"] ?? ""
func wanted(_ id: String) -> Bool {
    idMatches(id, filter: genFilter)
}

func emit(_ content: Content, style: Style, degrades: [Degrade]) {
    if !degrades.contains(where: { wanted("\(content.id)__\($0.name)") }) { seed &+= UInt64(degrades.count); return }
    guard let page = renderPage(content.lines, style: style, width: content.width, margin: style.size * 1.4) else {
        print("✗ 그리기 실패: \(content.id)")
        return
    }
    for d in degrades {
        seed &+= 1
        guard wanted("\(content.id)__\(d.name)") else { continue }
        let image = degrade(page, d, seed: seed)
        let name = "\(content.id)__\(d.name).jpg"
        guard writeJPEG(image, to: imageDir.appendingPathComponent(name), quality: d.jpeg) else {
            print("✗ 저장 실패: \(name)")
            continue
        }
        specs.append(CaseSpec(id: "\(content.id)__\(d.name)", category: content.category, kind: content.kind,
                              degrade: d.name, image: "images/\(name)", expect: content.expect))
    }
}

for (k, content) in problemContents.enumerated() {
    let style = variantStyle(content.style, index: k)
    emit(content, style: style, degrades: [.clean, problemDegrades[k % problemDegrades.count], problemDegrades[(k + 2) % problemDegrades.count]])
}
for (k, content) in wordContents.enumerated() {
    emit(content, style: content.style, degrades: [.clean, wordDegrades[k % wordDegrades.count], wordDegrades[(k + 2) % wordDegrades.count]])
}
// 영어·과학 문제 더 (앞 사진들의 손상 씨앗이 바뀌지 않게 맨 뒤에)
for (k, content) in moreSubjectContents.enumerated() {
    let style = variantStyle(content.style, index: k + 1)
    emit(content, style: style, degrades: [.clean, problemDegrades[(k + 1) % problemDegrades.count], problemDegrades[(k + 3) % problemDegrades.count]])
}
// 도형 기호 문제 (∠, △, 선분 윗줄, °, ⊥, ∥ …)
for (k, content) in geometryContents.enumerated() {
    let style = variantStyle(content.style, index: k + 2)
    emit(content, style: style, degrades: [.clean, problemDegrades[(k + 2) % problemDegrades.count], problemDegrades[(k + 4) % problemDegrades.count]])
}

// 학생 필기가 있는 문제 (연필·펜 풀이, 동그라미, 써 넣은 답 …) — 앞 사진들의 손상 씨앗이 바뀌지 않게 맨 뒤에
emitHandwriting(problemContents + moreSubjectContents + geometryContents, degrades: [.photo, .mild, .desk, .lowres, .tilted])

// 미적분 기호 문제 (∑ ∫ lim ′ √ …) — 글꼴(영문·한글)·크기를 바꿔 가며, 맨 뒤에
let calcLatinFonts: [(String, String)] = [("TimesNewRomanPSMT", "TimesNewRomanPS-ItalicMT"), ("Palatino-Roman", "Palatino-Italic"),
                                          ("Georgia", "Georgia-Italic"), ("Helvetica", "Helvetica-Oblique")]
for (k, content) in calculusContents.enumerated() {
    var style = variantStyle(content.style, index: k + 3)
    let font = calcLatinFonts[k % calcLatinFonts.count]
    style.latin = font.0
    style.italic = font.1
    emit(content, style: style, degrades: [.clean, problemDegrades[(k + 1) % problemDegrades.count], problemDegrades[(k + 3) % problemDegrades.count]])
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(specs).write(to: outDir.appendingPathComponent("cases.json"))
print("사진 \(specs.count)장 → \(outDir.path)")
