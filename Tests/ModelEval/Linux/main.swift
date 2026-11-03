import Foundation

// 두잇 1·2 모델 비교용 도구 (리눅스·맥, 앱 코드 그대로)
//   dump <eval.json>                     → 배터리에서 문제를 골라 앱의 프롬프트(DoitMind.persona + DoitAutoSolve.modelPrompt)로 만듦
//   score <eval.json> <results.jsonl>... → 모델이 쓴 답을 앱처럼 읽고(DoitMind.answer → DoitAutoSolve.parseModel) 배터리 채점 함수로 채점
// 문제 고르기: 수학 40 (풀이 배터리에서 고르게), 과학·영어·사회·국어 15씩 (과목 배터리에서 고르게)

// 배터리 파일이 쓰는 검사 함수 (여기서는 쓰지 않음)
func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {}

struct EvalItem: Codable {
    let id: String
    let subject: String
    let text: String
    let system: String
    let prompt: String
    let choices: [String]
    let expected: String
    let hasMaterial: Bool
}

struct EvalResult: Codable {
    let model: String
    let id: String
    let raw: String
    let seconds: Double
    let promptTokens: Int?
    let generatedTokens: Int?
    let stop: String?
}

/// 고르게 n개 (앞에서 끝까지 같은 간격)
func spread<T>(_ items: [T], _ n: Int) -> [(Int, T)] {
    guard items.count > n else { return Array(items.enumerated()) }
    let step = Double(items.count) / Double(n)
    return (0..<n).map { k in let i = Int(Double(k) * step); return (i, items[i]) }
}

/// 사진 속 문제 풀기(DoitAssistant.solvePhotoProblem)·AI 풀이 카드(AISolutionCard)와 같은 방법으로 프롬프트 만들기
func makeItem(id: String, subject: String, text: String, expected: String) -> EvalItem {
    let isMath = subject == "수학"
    let detected = DoitSubjectDetector.detect(text)
    let scan = DoitProblemScan.scan(text, math: isMath)
    let choices = scan.choices
    let isChoice = choices.count >= 2
    let type = scan.problemType ?? DoitProblemTypes.classify(text, subjectHint: detected?.broad ?? subject, limit: 1).first?.type
    let body = scan.body.isEmpty ? text : scan.body
    let material = DoitAutoSolve.modelMaterial(text: text, body: scan.body, choices: isChoice ? choices : [], boxItems: scan.boxItems,
                                               subject: NoteSubject.from(subject))
    let prompt = DoitAutoSolve.modelPrompt(problem: body, choices: isChoice ? choices : [], subjectName: subject, problemType: type,
                                           reference: material.reference, hints: material.hints)
    return EvalItem(id: id, subject: subject, text: text, system: DoitMind.persona, prompt: prompt,
                    choices: isChoice ? choices : [], expected: expected,
                    hasMaterial: !material.reference.isEmpty || !material.hints.isEmpty)
}

func dump(_ path: String) throws {
    var items: [EvalItem] = []
    // 수학: 객관식·단답 모두 (풀이 배터리에서 고르게 40)
    for (i, c) in spread(solverBattery, 40) {
        items.append(makeItem(id: "math-\(i)", subject: "수학", text: c.text, expected: c.answer))
    }
    // 과학·영어·사회·국어 15씩: 객관식이나 단답 (정답이 '~포함' 꼴이 아닌 것 먼저)
    for subject in ["과학", "영어", "사회", "국어"] {
        let all = subjectBattery.enumerated().filter { $0.element.subject == subject }
        let preferred = all.filter { !$0.element.answer.hasPrefix("~") }
        let pool = preferred.count >= 15 ? preferred : all
        for (_, pair) in spread(pool, 15) {
            items.append(makeItem(id: "\(subject)-\(pair.offset)", subject: subject, text: pair.element.text, expected: pair.element.answer))
        }
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(items).write(to: URL(fileURLWithPath: path))
    // 불러오기·생각 모드 확인용 대화 질문 (두잇 AI 대화와 같은 프롬프트: DoitMind.answerPrompt)
    let checks = ["광합성에는 왜 빛이 필요해?", "12와 18의 최소공배수는 어떻게 구해?"].enumerated().map { i, q in
        EvalItem(id: "check-\(i)", subject: "대화", text: q, system: DoitMind.persona,
                 prompt: DoitMind.answerPrompt(question: q, context: .init(), history: []), choices: [], expected: "", hasMaterial: false)
    }
    try encoder.encode(checks).write(to: URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent("checks.json"))
    var counts: [String: Int] = [:]
    for item in items { counts[item.subject, default: 0] += 1 }
    print("문제 \(items.count)개:", counts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "),
          "· 참고 자료/확인된 사실 있음 \(items.filter(\.hasMaterial).count)개 · 객관식 \(items.filter { !$0.choices.isEmpty }.count)개")
}

/// 모델 답 채점: 앱이 읽는 그대로 (parseModel이 nil이면 '답 없음')
func grade(_ item: EvalItem, raw: String) -> (answer: String?, right: Bool) {
    guard let solved = DoitAutoSolve.parseModel(DoitMind.answer(raw), problem: item.text, choices: item.choices) else { return (nil, false) }
    let answer = solved.finalAnswer
    if !item.choices.isEmpty { return (answer, answer == item.expected) }
    if item.subject == "수학" { return (answer, batteryMatches(answer, expected: item.expected)) }
    return (answer, subjectMatches(answer, expected: item.expected))
}

func score(_ evalPath: String, _ resultPaths: [String]) throws {
    let items = try JSONDecoder().decode([EvalItem].self, from: Data(contentsOf: URL(fileURLWithPath: evalPath)))
    let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    var results: [EvalResult] = []
    for path in resultPaths {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        for line in text.split(separator: "\n") where line.hasPrefix("{") {
            results.append(try JSONDecoder().decode(EvalResult.self, from: Data(line.utf8)))
        }
    }
    var models: [String] = []
    for r in results where !models.contains(r.model) { models.append(r.model) }
    let subjects = ["수학", "과학", "영어", "사회", "국어"]
    print("| 모델 | " + subjects.joined(separator: " | ") + " | 전체 | 평균 초/문제 | 평균 토큰 | 600토큰에서 잘림 |")
    print("|---|" + subjects.map { _ in "---" }.joined(separator: "|") + "|---|---|---|---|")
    var detail: [String] = []
    for model in models {
        let mine = results.filter { $0.model == model }
        var cells: [String] = []
        var allC = 0, allA = 0, allT = 0
        for subject in subjects {
            let rs = mine.filter { byID[$0.id]?.subject == subject }
            var c = 0, a = 0
            for r in rs {
                guard let item = byID[r.id] else { continue }
                let g = grade(item, raw: r.raw)
                if g.answer != nil { a += 1 }
                if g.right { c += 1 }
                let mark = g.right ? "O" : (g.answer == nil ? "-" : "X")
                detail.append("\(model)\t\(r.id)\t\(mark)\t답 \(g.answer ?? "없음")\t정답 \(item.expected)")
            }
            allC += c; allA += a; allT += rs.count
            cells.append("\(c) / \(a) / \(rs.count)")
        }
        let secs = mine.map(\.seconds).reduce(0, +) / Double(max(1, mine.count))
        let toks = Double(mine.compactMap(\.generatedTokens).reduce(0, +)) / Double(max(1, mine.count))
        let cut = mine.filter { $0.stop == "length" }.count
        print("| \(model) | " + cells.joined(separator: " | ") + " | \(allC) / \(allA) / \(allT) | \(String(format: "%.1f", secs)) | \(String(format: "%.0f", toks)) | \(cut) |")
    }
    print("(칸: 맞음 / 답함 / 전체 — '답함'은 앱의 parseModel이 정답을 읽어 낸 수)")
    print("")
    for line in detail { print(line) }
}

let args = CommandLine.arguments
do {
    switch args.count > 1 ? args[1] : "" {
    case "dump" where args.count == 3: try dump(args[2])
    case "score" where args.count >= 4: try score(args[2], Array(args[3...]))
    default:
        print("사용법: model-eval dump <eval.json> | score <eval.json> <results.jsonl>...")
        exit(2)
    }
} catch {
    print("오류: \(error)")
    exit(1)
}
