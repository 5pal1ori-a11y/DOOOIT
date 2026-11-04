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
/// lenient: 문장 끝에 붙은 "… 정답: 3"을 줄을 바꿔 읽음 (Qwen3.5는 근거와 정답을 한 줄에 이어 쓰는 일이 많음)
func grade(_ item: EvalItem, raw: String, lenient: Bool = false) -> (answer: String?, right: Bool) {
    var text = DoitMind.answer(raw)
    if lenient { text = text.replacingOccurrences(of: #"([^\n])[ \t]*(정답\s*[:：])"#, with: "$1\n$2", options: .regularExpression) }
    guard let solved = DoitAutoSolve.parseModel(text, problem: item.text, choices: item.choices) else { return (nil, false) }
    let answer = solved.finalAnswer
    if !item.choices.isEmpty { return (answer, answer == item.expected) }
    if item.subject == "수학" { return (answer, batteryMatches(answer, expected: item.expected)) }
    return (answer, subjectMatches(answer, expected: item.expected))
}

func score(_ evalPath: String, _ resultPaths: [String]) throws {
    for lenient in [false, true] {
        print(lenient ? "\n## 정답 줄을 나눠 읽었을 때 (문장 끝 '… 정답: x'도 읽음)" : "## 앱 그대로 (DoitMind.answer → DoitAutoSolve.parseModel)")
        try scoreTable(evalPath, resultPaths, lenient: lenient)
    }
}

func scoreTable(_ evalPath: String, _ resultPaths: [String], lenient: Bool) throws {
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
    print("| 모델 | " + subjects.joined(separator: " | ") + " | 전체 | 자료·힌트 없는 문제 | 평균 초/문제 | 평균 토큰 | 600토큰에서 잘림 |")
    print("|---|" + subjects.map { _ in "---" }.joined(separator: "|") + "|---|---|---|---|---|")
    var detail: [String] = []
    for model in models {
        let mine = results.filter { $0.model == model }
        var cells: [String] = []
        var allC = 0, allA = 0, allT = 0, bareC = 0, bareA = 0, bareT = 0
        for subject in subjects {
            let rs = mine.filter { byID[$0.id]?.subject == subject }
            var c = 0, a = 0
            for r in rs {
                guard let item = byID[r.id] else { continue }
                let g = grade(item, raw: r.raw, lenient: lenient)
                if g.answer != nil { a += 1 }
                if g.right { c += 1 }
                if !item.hasMaterial {
                    bareT += 1
                    if g.answer != nil { bareA += 1 }
                    if g.right { bareC += 1 }
                }
                let mark = g.right ? "O" : (g.answer == nil ? "-" : "X")
                detail.append("\(model)\t\(r.id)\t\(mark)\t답 \(g.answer ?? "없음")\t정답 \(item.expected)")
            }
            allC += c; allA += a; allT += rs.count
            cells.append("\(c) / \(a) / \(rs.count)")
        }
        let secs = mine.map(\.seconds).reduce(0, +) / Double(max(1, mine.count))
        let toks = Double(mine.compactMap(\.generatedTokens).reduce(0, +)) / Double(max(1, mine.count))
        let cut = mine.filter { $0.stop == "length" }.count
        print("| \(model) | " + cells.joined(separator: " | ") + " | \(allC) / \(allA) / \(allT) | \(bareC) / \(bareA) / \(bareT) | \(String(format: "%.1f", secs)) | \(String(format: "%.0f", toks)) | \(cut) |")
    }
    print("(칸: 맞음 / 답함 / 전체 — '답함'은 앱의 parseModel이 정답을 읽어 낸 수)")
    print("")
    if lenient { for line in detail { print(line) } }
}

// MARK: - 대화 말투 비교 (모티 1·2가 일상 대화·공부 질문에 어떻게 답하는지)
// chat <chat.json> [이름표]: DoitAssistant.think와 같은 방법으로 요청을 만듦 (엔진 답 → 말투 → 프롬프트·앞 대화·토큰 수)
// chatshow <chat.json> <로그>...: 맥 로그의 CHAT 줄을 앱처럼 다듬어(DoitMind.chatAnswer) 전·후를 나란히 보여 줌

/// 대화 말투 비교용 장면 (앞 대화 + 이번 말)
struct ChatScene {
    let id: String
    var before: [(String, String)] = []   // (학생 말, 모티 답)
    let question: String
    var topic: String? = nil
}

let chatScenes: [ChatScene] = [
    ChatScene(id: "c01", question: "안녕"),
    ChatScene(id: "c02", question: "ㅋㅋ"),
    ChatScene(id: "c03", question: "심심해"),
    ChatScene(id: "c04", question: "피곤해"),
    ChatScene(id: "c05", question: "오늘 공부 하기 싫어"),
    ChatScene(id: "c06", question: "고마워"),
    ChatScene(id: "c07", question: "졸려"),
    ChatScene(id: "c08", question: "배고파"),
    ChatScene(id: "c09", question: "나 오늘 시험 망했어"),
    ChatScene(id: "c10", question: "너무 힘들어"),
    ChatScene(id: "c11", question: "뭐해?"),
    ChatScene(id: "c12", question: "잘자"),
    ChatScene(id: "c13", question: "기분 좋아!"),
    ChatScene(id: "c14", question: "너 누구야?"),
    ChatScene(id: "c15", question: "짜증나"),
    ChatScene(id: "c16", before: [("광합성이 뭐야?", "광합성은 식물이 빛 에너지로 물과 이산화 탄소를 이용해 포도당을 만드는 과정이에요. 엽록체에서 일어나요.")], question: "고마워"),
    ChatScene(id: "c17", before: [("심심해", "심심할 땐 가볍게 퀴즈 한 판 어때요?")], question: "ㅋㅋ"),
    ChatScene(id: "c18", before: [("안녕", "안녕하세요! 오늘 하루 어땠어요?")], question: "오늘 공부 하기 싫어"),
    ChatScene(id: "c19", before: [("피곤해", "피곤하면 잠깐 쉬어도 괜찮아요. 10분 쉬고 25분만 집중해 볼까요?")], question: "그래도 해야겠지?"),
    ChatScene(id: "c20", before: [("안녕", "안녕하세요! 무엇을 도와드릴까요?"), ("심심해", "퀴즈 한 판 어때요?")], question: "아니 그냥 얘기하고 싶어"),
    ChatScene(id: "s01", question: "광합성이 뭐야?"),
    ChatScene(id: "s02", question: "임진왜란은 왜 일어났어?"),
    ChatScene(id: "s03", question: "현재완료 설명해줘"),
    ChatScene(id: "s04", question: "12와 18의 최소공배수는 어떻게 구해?"),
    ChatScene(id: "s05", question: "관계대명사 who랑 which 차이가 뭐야?"),
    ChatScene(id: "s06", question: "삼투 현상이 뭐야"),
    ChatScene(id: "s07", question: "기회비용 예시 들어줘"),
    ChatScene(id: "s08", question: "물은 왜 100도에서 끓어?"),
    ChatScene(id: "s09", question: "영어 단어 잘 외우는 법 알려줘"),
    ChatScene(id: "s10", before: [("광합성이 뭐야?", "광합성은 식물이 빛 에너지로 포도당을 만드는 과정이에요. 엽록체에서 일어나요.")], question: "그럼 밤에는?", topic: "광합성"),
    ChatScene(id: "s11", question: "블랙홀은 어떻게 생겨?"),
    ChatScene(id: "s12", question: "세종대왕이 한 일 알려줘"),
]

struct ChatItem: Codable {
    let id: String
    let variant: String
    let question: String
    let style: String
    let system: String
    let prompt: String
    let history: [[String]]
    let maxTokens: Int
    let temperature: Double
    let engine: String
}

struct ChatResult: Codable {
    let model: String
    let id: String
    let variant: String
    let raw: String
    let seconds: Double
    let generatedTokens: Int?
    let stop: String?
}

func styleName(_ style: DoitMind.Style) -> String {
    switch style {
    case .casual: return "casual"
    case .advice: return "advice"
    case .study: return "study"
    }
}

@MainActor
func dumpChat(_ path: String, variant: String) throws {
    var items: [ChatItem] = []
    for scene in chatScenes {
        DoitAssistant.shared.reset()
        DoitEngine.conversationTopic = scene.topic
        let reply = DoitEngine.respond(to: scene.question, photo: nil)
        var origin = reply.origin
        var draft: String? = origin == .conversation && !reply.text.hasPrefix("혹시") ? nil : reply.text
        if scene.topic != nil { origin = .knowledge; draft = nil }
        let turns = scene.before.flatMap { [DoitMind.Turn(fromUser: true, text: $0.0), DoitMind.Turn(fromUser: false, text: $0.1)] }
        let history = DoitMind.budgetHistory(turns, maxTokens: 1100)
        let style = scene.topic == nil ? DoitMind.style(for: scene.question, chat: origin == .chat) : .study
        var context = DoitMind.Context(draft: draft, app: origin == .chat && (variant == "before" || DoitMind.wantsSituation(scene.question, style: style)) ? "오늘 공부 95분 (목표 180분)\n남은 일정 2개\nD-Day 기말고사: D-12" : nil)
        context.knowledge = DoitKnowledge.search(scene.question, limit: 3).filter { $0.score >= 0.42 }.map(\.entry)
        let prompt = DoitMind.answerPrompt(question: scene.question, context: context, history: [], summary: history.summary, topic: scene.topic, style: style)
        let temperature = style == .casual ? 0.7 : (origin == .chat || origin == .conversation ? 0.6 : 0.4)
        items.append(ChatItem(id: scene.id, variant: variant, question: scene.question, style: styleName(style), system: DoitMind.persona, prompt: prompt,
                              history: history.recent.map { [$0.fromUser ? "user" : "assistant", $0.text] },
                              maxTokens: DoitMind.maxTokens(for: style), temperature: temperature, engine: reply.text))
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(items).write(to: URL(fileURLWithPath: path))
    print("대화 \(items.count)개")
}

/// 전·후 나란히: 전(before)은 예전처럼 DoitMind.answer, 후(after)는 DoitMind.chatAnswer
func showChat(_ chatPath: String, _ logPaths: [String]) throws {
    let items = try JSONDecoder().decode([ChatItem].self, from: Data(contentsOf: URL(fileURLWithPath: chatPath)))
    var results: [ChatResult] = []
    for path in logPaths {
        for line in try String(contentsOfFile: path, encoding: .utf8).components(separatedBy: "\n") {
            guard let tab = line.range(of: "CHAT\t") else { continue }
            results.append(try JSONDecoder().decode(ChatResult.self, from: Data(line[tab.upperBound...].utf8)))
        }
    }
    func shown(_ item: ChatItem, _ raw: String, model: String) -> String {
        guard item.variant == "after" else { return DoitMind.answer(raw) }
        let style: DoitMind.Style = item.style == "casual" ? .casual : (item.style == "advice" ? .advice : .study)
        // 앱처럼: 모티 1(작은 모델)은 가벼운 일상 대화에 엔진 답을 그대로 씀
        if style == .casual, model.contains("1.7B"), item.id.hasPrefix("c") { return "(엔진 답) " + item.engine }
        let text = DoitMind.chatAnswer(raw, question: item.question, previous: item.history.last(where: { $0.first == "assistant" })?.last, style: style)
        return DoitMind.isUsable(text, question: item.question) ? text : "(버림 → 엔진 답) " + item.engine
    }
    var models: [String] = []
    for r in results where !models.contains(r.model) { models.append(r.model) }
    for model in models {
        print("\n## \(model)")
        var stats: [String: (count: Int, chars: Int, formal: Int, list: Int, foreign: Int)] = [:]
        for id in chatScenes.map(\.id) {
            for variant in ["before", "after"] {
                guard let item = items.first(where: { $0.id == id && $0.variant == variant }),
                      let r = results.first(where: { $0.model == model && $0.id == id && $0.variant == variant }) else { continue }
                let text = shown(item, r.raw, model: model)
                print("\(id) \(variant == "before" ? "전" : "후") [\(item.question)] (\(text.count)자, \(r.generatedTokens ?? -1)토큰, \(String(format: "%.1f", r.seconds))s) \(text.replacingOccurrences(of: "\n", with: "⏎"))")
                var s = stats[variant] ?? (0, 0, 0, 0, 0)
                s.count += 1
                s.chars += text.count
                if text.contains("습니다") || text.contains("입니다") { s.formal += 1 }
                if id.hasPrefix("c"), text.contains("•") || text.contains("\n1.") { s.list += 1 }
                if text.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains($0.value) }) { s.foreign += 1 }
                stats[variant] = s
            }
        }
        for variant in ["before", "after"] {
            guard let s = stats[variant] else { continue }
            print("\(variant): \(s.count)개, 평균 \(s.chars / max(1, s.count))자, ~습니다 \(s.formal), 잡담 목록 \(s.list), 한자 \(s.foreign)")
        }
    }
}

let args = CommandLine.arguments
do {
    switch args.count > 1 ? args[1] : "" {
    case "dump" where args.count == 3: try dump(args[2])
    case "score" where args.count >= 4: try score(args[2], Array(args[3...]))
    case "chat" where args.count >= 3: try MainActor.assumeIsolated { try dumpChat(args[2], variant: args.count > 3 ? args[3] : "after") }
    case "chatshow" where args.count >= 4: try showChat(args[2], Array(args[3...]))
    default:
        print("사용법: model-eval dump <eval.json> | score <eval.json> <results.jsonl>... | chat <chat.json> | chatshow <chat.json> <로그>...")
        exit(2)
    }
} catch {
    print("오류: \(error)")
    exit(1)
}
