import Observation
import UIKit

/// 두잇 AI 대화 (직접 만든 규칙형 엔진, 외부 AI·API 없음, 인터넷 불필요)
/// 사진은 기기 안 글자 인식(Vision)으로 읽고, 엔진이 문장을 분석해서 앱 기능을 실행
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
        var suggestions: [String] = []
        var image: UIImage?
    }

    private(set) var messages: [Message] = []
    private(set) var isResponding = false
    private(set) var status = ""

    /// 바로 전에 보낸 사진 (다음 한 번의 말에서 "단어 추가해줘"처럼 이어서 쓸 수 있게)
    @ObservationIgnored private var lastPhoto: DoitEngine.PhotoContext?

    func reset() {
        messages = []
        lastPhoto = nil
    }

    func send(_ text: String, image: UIImage? = nil) async {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isResponding, !question.isEmpty || image != nil else { return }
        messages.append(Message(role: .user, text: question, image: image))
        isResponding = true
        defer { isResponding = false; status = "" }

        var photo = lastPhoto
        lastPhoto = nil
        if let image {
            status = "사진에서 글자를 읽는 중…"
            photo = await read(image)
            lastPhoto = photo
        }

        _ = DoitActions.shared.drainLog()
        let reply = DoitEngine.respond(to: question, photo: photo)
        // 사진으로 실제 작업을 했으면 그 사진은 더 쓰지 않음
        let actions = DoitActions.shared.drainLog()
        if !actions.isEmpty { lastPhoto = nil }
        messages.append(Message(role: .assistant, text: reply.text, actions: actions, suggestions: reply.suggestions))
    }

    /// 사진 읽기: 문제·필기용(검은 글자 위주)과 단어장용(영어-뜻 짝)
    private func read(_ image: UIImage) async -> DoitEngine.PhotoContext {
        let mathLines = (try? await OCRService.recognizeMath(image)) ?? []
        let text = MathOCRFixer.fix(OCRService.printedText(from: mathLines))
        let wordLines = (try? await OCRService.recognize(image)) ?? []
        let words = WordParser.parse(wordLines)
        return DoitEngine.PhotoContext(image: image, text: text, words: words)
    }
}
