import CoreGraphics
import Foundation
import ImageIO
import MLX
import MLXHuggingFace
import MLXLMCommon
import MLXVLM
import HuggingFace
import Tokenizers
import Vision

// 그림 읽기 확인 (맥): 앱 코드 그대로 세 가지 길로 읽고 정답과 비교
//   FigureEval vision <cases 폴더>
//   FigureEval paddle <cases 폴더> <정밀 인식 모델 폴더>
//   FigureEval vlm    <cases 폴더> <두잇 2 저장소>
// 줄마다 "FIG\t<길>\t<id>\t<점수>\t<초>\t<줄들>" 과 요약표, 메모리(물리 사용량 최댓값)를 로그에 남김

struct Value: Codable { var label: String; var value: Double; var tolerance: Double }
struct Case: Codable {
    var id: String
    var group: String
    var problem: String
    var facts: [String]
    var values: [Value]
    var equation: String?
}

func footprint() -> (now: Double, peak: Double) {
    var info = rusage_info_v4()
    let ok = withUnsafeMutablePointer(to: &info) { ptr in
        ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0) }
    }
    guard ok == 0 else { return (0, 0) }
    return (Double(info.ri_phys_footprint) / 1_048_576, Double(info.ri_lifetime_max_phys_footprint) / 1_048_576)
}

func norm(_ s: String) -> String {
    String(String.UnicodeScalarView(s.lowercased().replacingOccurrences(of: "−", with: "-").unicodeScalars.filter { $0.value != 0x305 && !CharacterSet.whitespaces.contains($0) }))
}

/// 점수: 맞힌 것 / 정답 수
func score(_ c: Case, lines: [String]) -> (hit: Int, total: Int, missed: [String]) {
    let joined = norm(lines.joined(separator: "\n"))
    var hit = 0, total = 0
    var missed: [String] = []
    for f in c.facts {
        total += 1
        if joined.contains(norm(f)) { hit += 1 } else { missed.append(f) }
    }
    if !c.values.isEmpty {
        let series = DoitFigureFacts.series(in: lines)
        for v in c.values {
            total += 1
            let ok = series.contains { s in
                zip(s.labels, s.values).contains { label, value in
                    let l = norm(label), e = norm(v.label)
                    return (l == e || l.hasPrefix(e) || e.hasPrefix(l) && !l.isEmpty) && abs(value - v.value) <= max(v.tolerance, 1e-6)
                }
            }
            if ok { hit += 1 } else { missed.append("\(v.label) \(v.value)") }
        }
    }
    if let eq = c.equation {
        total += 1
        let fitted = DoitFigureFacts.graphEquation(lines, hint: c.problem).map(norm)
        let stated = lines.first { $0.hasPrefix("그래프의 식") }.map { norm($0.replacingOccurrences(of: "그래프의 식은", with: "")) }
        if fitted == norm(eq) || stated == norm(eq) { hit += 1 } else { missed.append(eq) }
    }
    return (hit, total, missed)
}

func loadImage(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func oneLine(_ s: String) -> String { s.replacingOccurrences(of: "\n", with: "⏎") }

// MARK: - 기본 판독 (Vision + 픽셀)

/// 앱(VisionAnalyzer)과 같게: 글자 읽기 + 놓친 작은 글자 다시 읽기
func appLabels(_ image: CGImage) async -> [TextLabel] {
    let base = await FigureVision.textLabels(image, correction: true)
    guard let px = pixels(image) else { return base }
    return base + (await FigureVision.missingLabels(image, pixels: px, known: base))
}

func visionLabels(_ image: CGImage) -> [TextLabel] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["ko-KR", "en-US"]
    try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    let W = Double(image.width), H = Double(image.height)
    var labels: [TextLabel] = []
    for o in request.results ?? [] {
        guard let c = o.topCandidates(1).first else { continue }
        let s = c.string
        var index = s.startIndex
        var words: [TextLabel] = []
        while index < s.endIndex {
            guard let start = s[index...].firstIndex(where: { !$0.isWhitespace }) else { break }
            let end = s[start...].firstIndex(where: { $0.isWhitespace }) ?? s.endIndex
            if let box = try? c.boundingBox(for: start..<end)?.boundingBox {
                words.append(TextLabel(text: String(s[start..<end]), box: VRect(x: box.minX * W, y: (1 - box.maxY) * H, w: box.width * W, h: box.height * H)))
            }
            index = end
        }
        if words.count > 1 { labels += words } else {
            let b = o.boundingBox
            labels.append(TextLabel(text: s, box: VRect(x: b.minX * W, y: (1 - b.maxY) * H, w: b.width * W, h: b.height * H)))
        }
    }
    return labels
}

func pixels(_ image: CGImage) -> PixelImage? {
    let w = image.width, h = image.height
    var rgba = [UInt8](repeating: 255, count: w * h * 4)
    let ok: Bool = rgba.withUnsafeMutableBytes { buf in
        guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return true
    }
    return ok ? PixelImage(width: w, height: h, rgba: rgba) : nil
}

func visionRead(_ c: Case, _ image: CGImage) async -> [String] {
    var route = DoitFigureFacts.route(c.problem)
    // 앱(FigureReader)과 같게: 글이 도형·없음이어도 그림에 좌표축과 곡선이 있으면 그래프로
    if route == .none, let px = pixels(image), GraphReader.findAxes(px) != nil,
       let g = GraphReader.analyze(px, labels: visionLabels(image)), g.kind != .unknown { route = .graph }
    switch route {
    case .table, .chart:
        let tables = await FigureVision.tables(image)
        if let table = tables.first {
            let lines = DoitFigureFacts.tableLines(table, kind: route == .table ? .table : .bar)
            if !lines.isEmpty { return lines }
        }
        guard route == .chart else { return [] }
        return FigureVision.chartLines(visionLabels(image), image: pixels(image), kind: .bar)
    case .graph:
        let labels = await appLabels(image)
        let px = pixels(image)
        var graph: GraphAnalysis?
        if let px, GraphReader.findAxes(px) != nil, let g = GraphReader.analyze(px, labels: labels), g.kind != .unknown { graph = g }
        // 원인 찾기: 글자, 축, 곡선 점 수, 적힌 값
        print("   글자: " + labels.map { "\($0.text)@\(Int($0.box.midX)),\(Int($0.box.midY))" }.joined(separator: " "))
        if let px {
            let axes = GraphReader.findAxes(px)
            let curve = GraphReader.curvePixels(px, axes: axes, labels: labels).points.count
            print("   축: \(axes.map { "x축 y=\(Int($0.xAxisY)) y축 x=\(Int($0.yAxisX))" } ?? "없음") · 곡선 점 \(curve) · 판독 \(graph?.equation ?? "-") · 적힌 값 \(FigureVision.axisLines(labels, pixels: px, problem: c.problem))")
        }
        return FigureVision.graphFacts(labels, pixels: px, graph: graph, problem: c.problem)
    case .geometry, .none:
        guard let px = pixels(image) else { return [] }
        let minArea = Double(px.width * px.height) * 0.03
        let labels = await appLabels(image)
        do { print("   글자: " + labels.map { "\($0.text)@\(Int($0.box.midX)),\(Int($0.box.midY))" }.joined(separator: " ")) }
        let all = ShapeReader.analyze(px, labels: labels)
        let shapes = all.filter { $0.bounds.w * $0.bounds.h >= minArea }
        print("   도형: " + all.prefix(4).map { "\($0.name) \(Int($0.bounds.w))x\(Int($0.bounds.h)) 이름\($0.vertexNames.sorted { $0.key < $1.key }.map(\.value).joined()) 변\($0.sideLabels.count) 각\($0.angleLabels.count) 안\($0.innerNumbers.count)" }.joined(separator: " · "))
        return FigureVision.shapeLines(shapes, problem: c.problem)
    }
}

// MARK: - 실행

let args = CommandLine.arguments
guard args.count >= 3 else { print("FigureEval <vision|paddle|vlm> <cases> [모델]"); exit(2) }
let mode = args[1]
let dir = URL(fileURLWithPath: args[2])
let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: dir.appendingPathComponent("cases.json")))

var rows: [(Case, Int, Int, Double, [String])] = []
func record(_ c: Case, _ lines: [String], _ seconds: Double, raw: String? = nil) {
    let s = score(c, lines: lines)
    rows.append((c, s.hit, s.total, seconds, s.missed))
    print("FIG\t\(mode)\t\(c.id)\t\(s.hit)/\(s.total)\t\(String(format: "%.1f", seconds))s\t\(oneLine(lines.joined(separator: "\n")))")
    if !s.missed.isEmpty { print("   못 읽음: \(s.missed.joined(separator: " · "))") }
    if let raw { print("   원문: \(oneLine(String(raw.prefix(600))))") }
}

print("▶ \(mode): 그림 \(cases.count)장, 시작 메모리 \(Int(footprint().now)) MB")
switch mode {
case "vision":
    for c in cases {
        guard let image = loadImage(dir.appendingPathComponent("images/\(c.id).png")) else { continue }
        let t0 = Date()
        let lines = await visionRead(c, image)
        record(c, lines, Date().timeIntervalSince(t0))
    }
case "paddle":
    let engine = PaddleOCREngine()
    let t0 = Date()
    try await engine.load(from: URL(fileURLWithPath: args[3]))
    print("정밀 인식 올림: \(String(format: "%.1f", Date().timeIntervalSince(t0)))s, 메모리 \(Int(footprint().now)) MB")
    for c in cases {
        guard let image = loadImage(dir.appendingPathComponent("images/\(c.id).png")) else { continue }
        let route = DoitFigureFacts.route(c.problem)
        guard route == .chart || route == .table else { continue }
        for instruction in [route == .table ? "Table Recognition:" : "Chart Recognition:"] {
            let t1 = Date()
            do {
                let reading = try await engine.read(image, instruction: instruction, maxTokens: 600, timeout: 120)
                let table = DoitFigureFacts.parseTable(reading.text)
                let lines = DoitFigureFacts.tableLines(table, kind: route == .table ? .table : .bar)
                record(c, lines, Date().timeIntervalSince(t1), raw: "[\(instruction)] " + reading.text)
            } catch {
                print("FIG\tpaddle\t\(c.id)\t실패 \(error)")
            }
        }
    }
case "vlm":
    let repo = args[3]
    let t0 = Date()
    let downloader = #hubDownloader()
    let folder = try await downloader.download(id: repo, revision: nil, matching: ["*.safetensors", "*.json", "*.jinja"], useLatest: false, progressHandler: { _ in })
    print("받기: \(String(format: "%.0f", Date().timeIntervalSince(t0)))s → \(folder.path)")
    print("폴더 파일: \(((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted().joined(separator: ", "))")
    let before = footprint().now
    let t1 = Date()
    let container: ModelContainer
    do {
        container = try await DoitVisionEngine.load(directory: folder)
    } catch {
        print("VLM 올리기 실패: \(error)")
        exit(1)
    }
    let loaded = footprint()
    print("VLM 올림: \(String(format: "%.1f", Date().timeIntervalSince(t1)))s, 메모리 \(Int(before)) → \(Int(loaded.now)) MB (최대 \(Int(loaded.peak)) MB)")
    MLX.Memory.cacheLimit = 64 * 1024 * 1024
    print("사진 크기(긴 변): \(ProcessInfo.processInfo.environment["FIG_SIDE"] ?? String(Int(DoitVisionEngine.imageSide)))")
    for c in cases {
        guard let image = loadImage(dir.appendingPathComponent("images/\(c.id).png")) else { continue }
        do {
            let side = CGFloat(Double(ProcessInfo.processInfo.environment["FIG_SIDE"] ?? "") ?? Double(DoitVisionEngine.imageSide))
            let reading = try await DoitVisionEngine.read(container, image: image, side: side)
            let parsed = DoitFigureFacts.parseVision(reading.text)
            record(c, parsed?.lines ?? [], reading.seconds, raw: reading.text)
            print("   토큰: 프롬프트 \(reading.promptTokens), 생성 \(reading.generatedTokens), 메모리 \(Int(footprint().now)) MB")
        } catch {
            print("FIG\tvlm\t\(c.id)\t실패 \(error)")
        }
    }
default:
    print("모르는 길: \(mode)"); exit(2)
}

// 요약
print("\n== \(mode) 요약 (그림 종류별 맞힌 사실 / 전체, 평균 초)")
for group in ["geometry", "graph", "chart", "table"] {
    let g = rows.filter { $0.0.group == group }
    guard !g.isEmpty else { print("SUMMARY\t\(mode)\t\(group)\t-"); continue }
    let hit = g.map(\.1).reduce(0, +), total = g.map(\.2).reduce(0, +)
    let perfect = g.filter { $0.1 == $0.2 }.count
    let secs = g.map(\.3).reduce(0, +) / Double(g.count)
    print("SUMMARY\t\(mode)\t\(group)\t사실 \(hit)/\(total) (\(total == 0 ? 0 : hit * 100 / total)%)\t다 맞은 그림 \(perfect)/\(g.count)\t\(String(format: "%.1f", secs))s/장")
}
let mem = footprint()
print("MEMORY\t\(mode)\t지금 \(Int(mem.now)) MB\t최대 \(Int(mem.peak)) MB")
