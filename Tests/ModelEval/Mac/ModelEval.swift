import Foundation
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

// 두잇 1·2 모델 확인 (맥): DoitBrain.load / DoitBrain.stream 과 똑같이 불러오고 답을 만듦
//   ModelEval <저장소> <checks.json> <eval.json> <이름표> [문제 수 (0 = 전부)]
// - 확인: 대화 질문 2개를 생각 끔(600토큰, 0.6)·켬(1400토큰, 0.4)으로 → 불러오기 성공, 메모리, 토큰/초, <think> 처리
// - 비교: eval.json 문제를 AI 풀이 카드처럼 (생각 끔, 0.2, 600토큰) → 한 줄 JSON "EVAL\t{...}" 로 출력 (채점은 linux.sh score)

struct EvalItem: Codable {
    let id: String
    let subject: String
    let system: String
    let prompt: String
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

struct Output {
    var raw = ""
    var visible = ""
    var info: GenerateCompletionInfo?
    var seconds = 0.0
    /// 보이는 글이 처음 나온 때 (생각 모드면 생각을 마친 때)
    var firstVisible: Double?
}

func mb(_ bytes: Int) -> String { String(format: "%.0f MB", Double(bytes) / 1_048_576) }

func oneLine(_ s: String) -> String { s.replacingOccurrences(of: "\n", with: "⏎") }

/// DoitBrain.stream 과 같은 설정으로 답 만들기 (seed만 더함: 같은 결과가 다시 나오게)
func generate(_ container: ModelContainer, system: String, prompt: String, maxTokens: Int, temperature: Float, thinking: Bool, seed: UInt64) async throws -> Output {
    var parameters = GenerateParameters(maxTokens: maxTokens, temperature: temperature, topP: 0.9, repetitionPenalty: 1.1)
    parameters.seed = seed
    let session = ChatSession(container, instructions: system, generateParameters: parameters, additionalContext: ["enable_thinking": thinking])
    // 앱(DoitBrain.stream)과 같이: 생각 모드면 '<think>'가 미리 들어간 것으로 보고 시작
    var filter = ThinkFilter(startsInThink: thinking)
    var out = Output()
    let start = Date()
    for try await event in session.streamDetails(to: prompt) {
        switch event {
        case .chunk(let chunk):
            out.raw += chunk
            let visible = filter.feed(chunk)
            if out.firstVisible == nil, !visible.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.firstVisible = Date().timeIntervalSince(start) }
            out.visible += visible
        case .info(let info):
            out.info = info
        default:
            break
        }
    }
    out.seconds = Date().timeIntervalSince(start)
    return out
}

func stopName(_ info: GenerateCompletionInfo?) -> String? {
    guard let info else { return nil }
    switch info.stopReason {
    case .stop: return "stop"
    case .length: return "length"
    case .cancelled: return "cancelled"
    }
}

@main
struct ModelEvalMain {
    static func main() async {
        let args = CommandLine.arguments
        guard args.count >= 5 else {
            print("사용법: ModelEval <저장소> <checks.json> <eval.json> <이름표> [문제 수]")
            exit(2)
        }
        let repository = args[1], label = args[4]
        let limit = args.count > 5 ? Int(args[5]) ?? 0 : 0
        do {
            let checks = try JSONDecoder().decode([EvalItem].self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
            var items = try JSONDecoder().decode([EvalItem].self, from: Data(contentsOf: URL(fileURLWithPath: args[3])))
            if limit > 0, items.count > limit { items = Array(items.prefix(limit)) }

            // 1) 불러오기 (DoitBrain.load 와 똑같이)
            print("=== LOAD \(label) \(repository)")
            let loadStart = Date()
            let configuration = ModelConfiguration(id: repository, defaultPrompt: "", extraEOSTokens: ["<|im_end|>"])
            let container = try await #huggingFaceLoadModelContainer(configuration: configuration, progressHandler: { _ in })
            let loadSeconds = Date().timeIntervalSince(loadStart)
            let modelType = await container.perform { (context: ModelContext) in String(describing: type(of: context.model)) }
            print("LOAD OK \(label): \(String(format: "%.1f", loadSeconds))s (다운로드 포함), 모델 클래스 \(modelType), 불러온 뒤 메모리 \(mb(Memory.activeMemory)), 최고 \(mb(Memory.peakMemory))")
            // 대화 형식 끝부분 (enable_thinking 이 어떻게 들어가는지)
            for thinking in [false, true] {
                let tail = try await container.perform { (context: ModelContext) -> String in
                    let ids = try context.tokenizer.applyChatTemplate(
                        messages: [["role": "system", "content": "S"], ["role": "user", "content": "Q"]], tools: nil,
                        additionalContext: ["enable_thinking": thinking])
                    return context.tokenizer.decode(tokenIds: ids, skipSpecialTokens: false)
                }
                print("TEMPLATE thinking=\(thinking): \(oneLine(String(tail.suffix(120))))")
            }

            // 2) 대화 질문: 생각 끔·켬
            for check in checks {
                // (생각 끔 600) · (생각 켬 1400 = 앱) · 마지막 질문만 (생각 켬 4000: 생각을 언제 마치는지)
                var runs: [(Bool, Int)] = [(false, 600), (true, 1400)]
                if check.id == checks.last?.id { runs.append((true, 4000)) }
                for (thinking, budget) in runs {
                    Memory.peakMemory = 0
                    let out = try await generate(container, system: check.system, prompt: check.prompt,
                                                 maxTokens: budget, temperature: thinking ? 0.4 : 0.6, thinking: thinking, seed: 7)
                    let info = out.info
                    print("=== CHECK \(label) \(check.id) thinking=\(thinking) maxTokens=\(budget) 첫 글자 \(out.firstVisible.map { String(format: "%.1fs", $0) } ?? "없음")")
                    print("질문: \(oneLine(check.prompt))")
                    print("속도: 프롬프트 \(info?.promptTokenCount ?? -1)토큰 \(String(format: "%.1f", info?.promptTokensPerSecond ?? 0)) tok/s · 생성 \(info?.generationTokenCount ?? -1)토큰 \(String(format: "%.1f", info?.tokensPerSecond ?? 0)) tok/s · \(String(format: "%.1f", out.seconds))s · 멈춤 \(stopName(info) ?? "-") · 최고 메모리 \(mb(Memory.peakMemory))")
                    print("원문에 <think> \(out.raw.contains("<think>")) · </think> \(out.raw.contains("</think>")) | 걸러낸 글에 <think> \(out.visible.contains("<think>")) · </think> \(out.visible.contains("</think>"))")
                    print("원문: \(oneLine(out.raw))")
                    print("보이는 글(ThinkFilter): \(oneLine(out.visible))")
                }
            }

            // 3) 문제 풀기 (AI 풀이 카드와 같은 설정)
            print("=== EVAL \(label) \(items.count)문제")
            Memory.peakMemory = 0
            let evalStart = Date()
            var genTokens = 0, genTime = 0.0
            for (i, item) in items.enumerated() {
                let out = try await generate(container, system: item.system, prompt: item.prompt, maxTokens: 600, temperature: 0.2, thinking: false, seed: UInt64(1000 + i))
                let result = EvalResult(model: label, id: item.id, raw: out.raw, seconds: out.seconds,
                                        promptTokens: out.info?.promptTokenCount, generatedTokens: out.info?.generationTokenCount, stop: stopName(out.info))
                genTokens += out.info?.generationTokenCount ?? 0
                genTime += out.info?.generateTime ?? 0
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
                let line = String(decoding: try encoder.encode(result), as: UTF8.self)
                print("[\(i + 1)/\(items.count)] \(item.id) \(String(format: "%.1f", out.seconds))s \(out.info?.generationTokenCount ?? -1)tok 멈춤 \(stopName(out.info) ?? "-")")
                print("EVAL\t" + line)
            }
            let total = Date().timeIntervalSince(evalStart)
            print("=== EVAL DONE \(label): \(items.count)문제 \(String(format: "%.0f", total))s, 평균 \(String(format: "%.1f", total / Double(max(1, items.count))))s/문제, 생성 \(String(format: "%.1f", Double(genTokens) / max(genTime, 0.001))) tok/s, 최고 메모리 \(mb(Memory.peakMemory))")
        } catch {
            print("FAIL \(label) \(repository): \(error)")
            exit(1)
        }
    }
}
