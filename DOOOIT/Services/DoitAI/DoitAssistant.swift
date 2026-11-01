import Observation
import UIKit

/// 두잇 AI 대화: 서버 AI가 사진을 직접 보고 답하고, 필요하면 앱 기능(도구)을 불러서 실제로 처리
/// 도구 실행은 휴대폰 안에서 하고, 결과를 다시 AI에게 알려주는 과정을 답이 끝날 때까지 반복
@MainActor
@Observable
final class DoitAssistant {
    static let shared = DoitAssistant()

    struct Message: Identifiable, Equatable {
        enum Role { case user, assistant, notice }
        let id = UUID()
        let role: Role
        var text: String
        var actions: [String] = []
        var image: UIImage?
    }

    private(set) var messages: [Message] = []
    private(set) var isResponding = false
    private(set) var status = ""

    /// 서버로 보내는 대화 기록 (Anthropic 메시지 형식)
    @ObservationIgnored private var history: [[String: Any]] = []
    /// 가장 최근에 보낸 사진 (오답노트 저장 도구가 씀)
    @ObservationIgnored private var lastImage: UIImage?

    private static let maxToolRounds = 6
    private static let maxHistory = 24

    var unavailableMessage: String? { AITutor.unavailableMessage }

    func reset() {
        messages = []
        history = []
        lastImage = nil
    }

    func send(_ text: String, image: UIImage? = nil) async {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isResponding, !question.isEmpty || image != nil else { return }
        messages.append(Message(role: .user, text: question, image: image))

        if let message = unavailableMessage {
            messages.append(Message(role: .notice, text: message))
            return
        }

        isResponding = true
        status = image == nil ? "생각하는 중…" : "사진을 보는 중…"
        defer { isResponding = false; status = "" }

        var content: [[String: Any]] = []
        if let image {
            lastImage = image
            for encoded in ClaudeReader.encode([image]) {
                content.append(["type": "image",
                                "source": ["type": "base64", "media_type": encoded["mediaType"] ?? "image/jpeg",
                                           "data": encoded["data"] ?? ""]])
            }
        }
        content.append(["type": "text", "text": question.isEmpty ? "이 사진을 보고 도와줘." : question])
        stripOldImages()
        history.append(["role": "user", "content": content])
        trimHistory()

        _ = DoitActions.shared.drainLog()
        var replyText = ""
        do {
            for _ in 0..<Self.maxToolRounds {
                let data = try await ClaudeReader.post("chat", body: [
                    "system": systemPrompt(),
                    "messages": history,
                    "tools": DoitToolSpecs.all
                ])
                guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let blocks = response["content"] as? [[String: Any]] else {
                    throw AITutorError.failed("답을 읽지 못했어요.")
                }
                // 다시 보낼 때는 필요한 값만 남김
                let cleaned: [[String: Any]] = blocks.compactMap { block in
                    switch block["type"] as? String {
                    case "text":
                        return ["type": "text", "text": block["text"] as? String ?? ""]
                    case "tool_use":
                        return ["type": "tool_use", "id": block["id"] ?? "", "name": block["name"] ?? "",
                                "input": block["input"] ?? [String: Any]()]
                    default:
                        return nil
                    }
                }
                history.append(["role": "assistant", "content": cleaned.isEmpty ? [["type": "text", "text": "..."]] : cleaned])

                let texts = blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
                if !texts.isEmpty { replyText = texts.joined(separator: "\n") }

                let toolCalls = blocks.filter { $0["type"] as? String == "tool_use" }
                guard (response["stop_reason"] as? String) == "tool_use", !toolCalls.isEmpty else { break }

                status = "앱에서 처리하는 중…"
                var results: [[String: Any]] = []
                for call in toolCalls {
                    let name = call["name"] as? String ?? ""
                    let input = call["input"] as? [String: Any] ?? [:]
                    let output = DoitToolSpecs.run(name: name, input: input, image: lastImage)
                    results.append(["type": "tool_result", "tool_use_id": call["id"] as? String ?? "", "content": output])
                }
                history.append(["role": "user", "content": results])
                status = "정리하는 중…"
            }
            let actions = DoitActions.shared.drainLog()
            let finalText = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
            messages.append(Message(role: .assistant, text: finalText.isEmpty ? "처리했어요." : finalText, actions: actions))
        } catch {
            let actions = DoitActions.shared.drainLog()
            // 대화 기록이 꼬이지 않게 이번 질문을 기록에서 되돌림 (이미 한 일은 화면에 표시)
            rollbackToLastUserTurn()
            if actions.isEmpty {
                messages.append(Message(role: .notice, text: AITutorError.describe(error).errorDescription ?? "다시 시도해주세요."))
            } else {
                messages.append(Message(role: .assistant, text: "요청한 작업은 처리했지만 답을 마저 쓰지 못했어요.", actions: actions))
            }
        }
    }

    // MARK: 대화 기록 관리

    /// 예전 사진은 글자로 바꿔서 보내는 양을 줄임 (최근 사진만 AI가 직접 봄)
    private func stripOldImages() {
        for index in history.indices {
            guard history[index]["role"] as? String == "user",
                  var content = history[index]["content"] as? [[String: Any]],
                  content.contains(where: { $0["type"] as? String == "image" }) else { continue }
            content = content.map { $0["type"] as? String == "image" ? ["type": "text", "text": "[이전에 보낸 사진]"] : $0 }
            history[index]["content"] = content
        }
    }

    /// 너무 길어지면 앞부분을 잘라냄 (사용자가 직접 쓴 메시지에서 시작하도록)
    private func trimHistory() {
        guard history.count > Self.maxHistory else { return }
        var start = history.count - Self.maxHistory
        while start < history.count - 1 && !isPlainUserTurn(history[start]) { start += 1 }
        history = Array(history[start...])
    }

    private func rollbackToLastUserTurn() {
        guard let index = history.lastIndex(where: isPlainUserTurn) else { return }
        history = Array(history[..<index])
    }

    private func isPlainUserTurn(_ message: [String: Any]) -> Bool {
        guard message["role"] as? String == "user", let content = message["content"] as? [[String: Any]] else { return false }
        return !content.contains { $0["type"] as? String == "tool_result" }
    }

    private func systemPrompt() -> String {
        let now = Date()
        return """
        너는 공부 앱 DOOOIT 안에 있는 AI 비서 '두잇 AI'야. 한국 중고등학생을 돕고, 친절하고 간결한 한국어로 답해.
        지금은 \(now.kr("yyyy년 M월 d일 EEEE a h:mm"))야.

        할 수 있는 일:
        - 플랜(일정) 확인·추가·완료·삭제, 공부 타이머, 영어 단어 추가, 수학 오답노트 저장, 메모, D-Day·목표 설정, 공부 기록 확인, 화면 이동은 반드시 도구로 실제로 처리해.
        - 날짜와 시간은 사용자가 말한 표현 그대로(예: 내일, 다음주 월요일, 오후 3시) 도구에 넘겨. 앱이 계산해.
        - 사진이 오면 직접 보고 분석해: 문제 풀이, 단어장 → add_words, "오답노트에 넣어줘" → save_wrong_note(인쇄된 검은 글자만 정확히 옮겨 적기), 필기·시간표·프린트 정리 등.
        - 공부 질문(개념 설명, 문제 풀이, 영어 해석, 글쓰기 첨삭 등)은 직접 단계별로 설명해. 2022 개정 교육과정 수준에 맞춰.

        규칙:
        - 도구 결과에 나온 내용만 사실로 말해. 하지 않은 일을 했다고 말하지 마.
        - 지우기처럼 되돌리기 어려운 일은 사용자가 분명히 요청했을 때만 해.
        - 수식은 x², √(…), (분자)/(분모)처럼 쓰고, 강조는 **굵게**만 써. 표나 제목(#)은 쓰지 마.
        - 확실하지 않으면 모른다고 말해.
        """
    }
}
