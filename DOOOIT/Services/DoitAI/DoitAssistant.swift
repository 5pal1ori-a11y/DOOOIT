import FoundationModels
import Observation
import UIKit

/// 두잇 AI 대화: Apple 기기 안 AI + 앱 기능 도구 (무료, 인터넷 불필요)
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

    @ObservationIgnored private var session: LanguageModelSession?
    @ObservationIgnored private var sessionDay = ""

    var unavailableMessage: String? { AITutor.unavailableMessage }

    func reset() {
        messages = []
        session = nil
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
        defer { isResponding = false }

        var prompt = question.isEmpty ? "이 사진의 문제를 설명해줘." : question
        if let image {
            let lines = (try? await OCRService.recognizeMath(image)) ?? []
            let read = MathOCRFixer.fix(OCRService.plainText(from: lines))
            if !read.isEmpty {
                prompt += "\n\n[사진에서 읽은 글자 · 글자 인식이라 틀린 곳이 있을 수 있음]\n" + String(read.prefix(900))
            }
        }

        _ = DoitActions.shared.drainLog()
        do {
            let reply = try await respond(prompt)
            messages.append(Message(role: .assistant, text: reply, actions: DoitActions.shared.drainLog()))
        } catch {
            let actions = DoitActions.shared.drainLog()
            let reason = AITutorError.describe(error).errorDescription ?? "다시 시도해주세요."
            if actions.isEmpty {
                messages.append(Message(role: .notice, text: reason))
            } else {
                messages.append(Message(role: .assistant, text: "요청한 작업은 처리했어요.", actions: actions))
            }
        }
    }

    /// 대화가 길어져 기기 AI가 감당하지 못하면 새 대화로 이어서 한 번 더
    private func respond(_ prompt: String) async throws -> String {
        let today = Date().dayKey
        if session == nil || sessionDay != today {
            session = makeSession()
            sessionDay = today
        }
        do {
            return try await session!.respond(to: prompt).content
        } catch {
            guard String(describing: error).contains("exceededContext") else { throw error }
            session = makeSession()
            messages.append(Message(role: .notice, text: "대화가 길어져서 새 대화로 이어갈게요."))
            return try await session!.respond(to: prompt).content
        }
    }

    private func makeSession() -> LanguageModelSession {
        let now = Date()
        let instructions = """
        너는 공부 앱 DOOOIT의 비서 '두잇 AI'야. 한국 고등학생을 돕고, 짧고 친절한 한국어로 답해.
        오늘은 \(now.kr("yyyy년 M월 d일 EEEE")), 지금 \(now.kr("a h:mm"))야.
        - 일정 추가·완료·삭제, 타이머, 단어 추가, 메모, 목표·D-Day, 기록 확인, 화면 이동은 반드시 도구를 써서 실제로 처리해.
        - 날짜와 시간은 사용자가 말한 그대로(예: 내일, 다음주 월요일, 오후 3시) 도구에 넘겨.
        - 도구 결과에 있는 내용만 사실로 말하고, 하지 않은 일을 했다고 말하지 마.
        - 공부 질문(개념 설명, 문제 풀이, 영어 문장 해석 등)은 직접 단계별로 설명해. 확실하지 않으면 모른다고 말해.
        - 수식은 x², √(…), (분자)/(분모)처럼 써.
        """
        return LanguageModelSession(tools: DoitTools.all, instructions: instructions)
    }
}
