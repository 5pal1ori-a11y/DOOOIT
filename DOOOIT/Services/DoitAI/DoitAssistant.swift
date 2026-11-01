import Observation
import UIKit

/// 두잇 AI 대화: 두잇 AI 엔진(직접 만든 규칙형) + Apple Intelligence(기기 안 모델) 병행
/// - 앱 기능 실행, 수학 풀이, 내장 지식, 퀴즈는 두잇 AI 엔진
/// - 엔진이 알아듣지 못한 자유 대화·질문은 Apple Intelligence (지원 기기에서만)
/// 사진은 기기 안 글자 인식(Vision)으로 읽음. 인터넷은 영어 단어 사전만 씀
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
        /// 누가 답했는지 (두잇 AI 엔진 / Apple Intelligence)
        var source: Source = .doit

        enum Source { case doit, apple }
    }

    /// 진행 중인 퀴즈
    private struct QuizState {
        var source: DoitEngine.QuizSource
        var item: DoitQuizItem
        var asked = 1
        var correct = 0
        var hintUsed = false
    }

    private(set) var messages: [Message] = []
    private(set) var isResponding = false
    private(set) var status = ""

    /// 바로 전에 보낸 사진 (다음 한 번의 말에서 "단어 추가해줘"처럼 이어서 쓸 수 있게)
    @ObservationIgnored private var lastPhoto: DoitEngine.PhotoContext?
    /// 바로 전 검색 답 (주제, 내용) — "더 자세히", "메모로 저장", "이걸로 퀴즈" 이어서 하기용
    @ObservationIgnored private var lastAnswer: (topic: String, text: String)?
    /// 바로 전에 푼 수학 문제 — "비슷한 문제 내줘"
    @ObservationIgnored private var lastMath: String?
    @ObservationIgnored private var quiz: QuizState?
    @ObservationIgnored private var lastQuizSource: DoitEngine.QuizSource?
    /// Apple Intelligence 대화 (이전 대화를 기억)
    @ObservationIgnored private let appleChat = DoitAppleAI.Chat()

    func reset() {
        messages = []
        lastPhoto = nil
        lastAnswer = nil
        lastMath = nil
        quiz = nil
        appleChat.reset()
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

        // 1) 퀴즈 진행 중이면 답으로 채점
        if image == nil, let reply = await continueQuiz(question) {
            messages.append(reply)
            return
        }

        // 2) 바로 전 답에 이어서
        if image == nil, let reply = await followUp(question) {
            messages.append(reply)
            return
        }

        var reply = DoitEngine.respond(to: question, photo: photo)
        // 사진으로 실제 작업을 했으면 그 사진은 더 쓰지 않음
        let actions = DoitActions.shared.drainLog()
        if !actions.isEmpty { lastPhoto = nil }

        switch reply.deferred {
        case .quiz(let source):
            messages.append(await startQuiz(source))
            return
        default:
            break
        }
        lastAnswer = nil
        switch reply.deferred {
        case .dictionary(let word):
            status = "영어 사전에서 찾는 중…"
            if let entry = await DoitEnglish.define(word) {
                reply.text = reply.text.isEmpty ? entry : reply.text + "\n\n" + entry
            } else if reply.text.isEmpty {
                reply.text = "'\(word)'을(를) 사전에서 찾지 못했어요. 철자를 확인하거나 인터넷 연결을 확인해 주세요."
            }
            reply.suggestions = reply.suggestions.filter { !$0.contains("영어 뜻 자세히") }
        case .quiz, nil:
            break
        }
        if reply.text.hasPrefix("**") && reply.suggestions.contains("비슷한 문제 내줘") { lastMath = question }

        // 두잇 AI 엔진이 알아듣지 못한 말: Apple Intelligence가 이어서 대답
        if !reply.understood {
            if DoitAppleAI.isAvailable {
                status = "Apple Intelligence가 생각하는 중…"
                var prompt = question
                if let photo, !photo.text.isEmpty { prompt += "\n[사진에서 읽은 글자]\n\(String(photo.text.prefix(600)))" }
                do {
                    let answer = try await appleChat.reply(prompt, context: contextLine())
                    let topic = String(question.prefix(40))
                    lastAnswer = (topic, answer)
                    reply = DoitEngine.Reply(text: answer, suggestions: ["더 자세히 알려줘", "이걸로 퀴즈 내줘", "메모로 저장해줘"])
                    messages.append(Message(role: .assistant, text: answer, actions: actions, suggestions: reply.suggestions, source: .apple))
                    return
                } catch {
                    reply.text += "\n\n(\(error.localizedDescription))"
                }
            } else if let note = DoitAppleAI.unavailableMessage {
                reply.text += "\n\n💡 \(note)"
            }
        } else if reply.suggestions.contains("더 자세히 알려줘") || reply.text.hasPrefix("**") {
            // 앱 안 지식으로 답한 것도 이어서 묻기·저장할 수 있게
            let topic = reply.text.components(separatedBy: "\n").first?.replacingOccurrences(of: "**", with: "") ?? ""
            lastAnswer = (topic, reply.text)
        }
        messages.append(Message(role: .assistant, text: reply.text, actions: actions, suggestions: reply.suggestions))
    }

    // MARK: - 이어서 하기

    private func followUp(_ question: String) async -> Message? {
        let q = question.replacingOccurrences(of: " ", with: "")
        if let math = lastMath, q.contains("비슷한문제") || q.contains("유사문제") || q.contains("비슷한거") {
            status = "비슷한 문제를 만드는 중…"
            if let made = try? await DoitTutor.similar(to: math) {
                let lines = made.problems.enumerated().map { "\($0.offset + 1). \($0.element.question)" }
                let answers = made.problems.enumerated().map { "\($0.offset + 1)) \($0.element.answer)" }.joined(separator: "  ")
                return Message(role: .assistant, text: "**비슷한 문제 3개** (쉬움 → 어려움)\n" + lines.joined(separator: "\n") + "\n\n정답: \(answers)",
                               suggestions: ["수학 퀴즈 내줘"])
            }
        }
        guard let previous = lastAnswer else { return nil }
        if q.contains("더자세히") || q.contains("자세히알려") || q.contains("더알려") || q == "더" || q.contains("계속") {
            guard DoitAppleAI.isAvailable else {
                return Message(role: .assistant, text: "더 자세한 설명은 Apple Intelligence가 만들어요.\n\(DoitAppleAI.unavailableMessage ?? "")",
                               suggestions: ["이걸로 퀴즈 내줘", "메모로 저장해줘"])
            }
            status = "Apple Intelligence가 더 자세히 정리하는 중…"
            do {
                let more = try await DoitTutor.more(about: previous.topic, previous: previous.text)
                lastAnswer = (previous.topic, more)
                return Message(role: .assistant, text: more, suggestions: ["이걸로 퀴즈 내줘", "메모로 저장해줘"], source: .apple)
            } catch {
                return Message(role: .assistant, text: error.localizedDescription)
            }
        }
        if q.contains("메모") && (q.contains("저장") || q.contains("남겨")) {
            let result = DoitActions.shared.addMemo(previous.text.replacingOccurrences(of: "**", with: ""))
            lastAnswer = nil
            return Message(role: .assistant, text: result, actions: DoitActions.shared.drainLog())
        }
        if q.contains("쉽게") || q.contains("요약") || q.contains("한줄") || q.contains("간단히") {
            let lines = previous.text.components(separatedBy: "\n").filter { !$0.isEmpty && !$0.hasPrefix("출처") }
            let summary = lines.prefix(3).joined(separator: "\n")
            return Message(role: .assistant, text: "**한눈에 보기**\n" + summary, suggestions: ["더 자세히 알려줘", "이걸로 퀴즈 내줘"])
        }
        return nil
    }

    // MARK: - 퀴즈

    private func startQuiz(_ source: DoitEngine.QuizSource) async -> Message {
        status = "문제를 만드는 중…"
        guard let item = await makeQuestion(source) else {
            let text: String
            switch source {
            case .myWords: text = "단어장에 단어가 아직 없어요. \"단어 추가: apple 사과\"처럼 넣거나 단어장 사진을 보내주세요."
            case .lastTopic: text = "퀴즈를 낼 주제가 없어요. 먼저 궁금한 개념을 물어봐 주세요. 예: 광합성이 뭐야?"
            default: text = "문제를 만들지 못했어요. 다른 과목으로 해볼까요?"
            }
            return Message(role: .assistant, text: text, suggestions: ["수학 퀴즈 내줘", "영어 퀴즈 내줘", "과학 퀴즈 내줘", "사회 퀴즈 내줘"])
        }
        quiz = QuizState(source: source, item: item)
        lastQuizSource = source
        return Message(role: .assistant, text: "**퀴즈 1번** (\(label(source)))\n\(item.question)\n\n답을 입력해 주세요.",
                       suggestions: ["힌트", "모르겠어", "그만"])
    }

    /// 퀴즈 중일 때 들어온 말 처리 (퀴즈와 상관없는 부탁이면 nil → 퀴즈를 끝내고 평소처럼)
    private func continueQuiz(_ answer: String) async -> Message? {
        let q = answer.replacingOccurrences(of: " ", with: "")
        // 퀴즈가 끝난 뒤 "다음 문제"
        if quiz == nil, let source = lastQuizSource, ["다음", "다음문제", "한문제더", "또내줘", "다음퀴즈", "퀴즈계속"].contains(q) {
            return await startQuiz(source)
        }
        guard var state = quiz else { return nil }
        if ["그만", "종료", "끝", "그만할래", "퀴즈끝", "stop"].contains(where: { q.hasPrefix($0) }) && q.count <= 8 {
            quiz = nil
            return Message(role: .assistant, text: "퀴즈를 마칠게요. \(state.asked)문제 중 \(state.correct)문제 맞혔어요! 수고했어요.",
                           suggestions: ["다음 문제", "오늘 할 일 알려줘"])
        }
        if q.contains("힌트") && q.count <= 8 {
            state.hintUsed = true
            quiz = state
            return Message(role: .assistant, text: DoitChat.hint(for: state.item), suggestions: ["모르겠어", "그만"])
        }
        let giveUp = ["모르겠", "몰라", "패스", "정답알려", "답알려", "포기", "pass"].contains { q.contains($0) } && q.count <= 10
        // 퀴즈와 상관없는 긴 부탁이면 퀴즈를 끝내고 넘김
        if !giveUp && answer.count > 30 && DoitEngine.quizRequest(answer.lowercased()) == nil {
            quiz = nil
            return nil
        }
        if DoitEngine.quizRequest(answer.lowercased()) != nil && answer.count > 6 {
            quiz = nil
            return nil
        }
        let right = !giveUp && DoitChat.isCorrect(answer, item: state.item)
        if right { state.correct += 1 }
        let headline: String
        if giveUp {
            headline = "괜찮아요! 정답: **\(state.item.answers.first ?? "")**"
        } else if right {
            headline = ["정답이에요! 🎉", "맞았어요! 👍", "정확해요! ✨"].randomElement()! + (state.hintUsed ? " (힌트 사용)" : "")
        } else {
            headline = "아쉬워요. 정답: **\(state.item.answers.first ?? "")**"
        }
        let explanation = state.item.explanation.isEmpty ? "" : "\n\(state.item.explanation)"
        // 다음 문제 바로 내기
        status = "다음 문제를 만드는 중…"
        if state.asked < 10, let next = await makeQuestion(state.source) {
            let nextNumber = state.asked + 1
            quiz = QuizState(source: state.source, item: next, asked: nextNumber, correct: state.correct)
            return Message(role: .assistant,
                           text: "\(headline)\(explanation)\n\n지금까지 \(state.asked)문제 중 \(state.correct)개 정답\n\n**퀴즈 \(nextNumber)번**\n\(next.question)",
                           suggestions: ["힌트", "모르겠어", "그만"])
        }
        quiz = nil
        return Message(role: .assistant, text: "\(headline)\(explanation)\n\n퀴즈 끝! \(state.asked)문제 중 \(state.correct)문제 맞혔어요.",
                       suggestions: ["다음 문제", "오늘 할 일 알려줘"])
    }

    private func label(_ source: DoitEngine.QuizSource) -> String {
        switch source {
        case .math: return "수학"
        case .english: return "영어"
        case .myWords: return "내 단어장"
        case .science: return "과학"
        case .social: return "사회"
        case .lastTopic: return lastAnswer?.topic ?? "방금 주제"
        case .any: return "랜덤"
        }
    }

    private func makeQuestion(_ source: DoitEngine.QuizSource) async -> DoitQuizItem? {
        switch source {
        case .math(let topic):
            let problem: Problem
            if let topic, let made = MathProblems.make(unit: topic, hard: Bool.random()), MathProblems.topic(for: topic) != nil {
                problem = made
            } else {
                problem = MathProblems.make(topic: MathProblems.Topic.allCases.randomElement() ?? .linear, hard: Bool.random())
            }
            let choices = problem.choices.enumerated().map { "\($0.offset + 1)) \($0.element)" }.joined(separator: "   ")
            return DoitQuizItem(question: "\(problem.question)\n\(choices)\n(답을 쓰거나 '\(Int.random(in: 1...5))번'처럼 번호로 입력하세요)",
                                answers: [problem.finalAnswer, "\(problem.answerNumber)번", "\(problem.answerNumber))"],
                                explanation: "풀이: " + problem.steps.joined(separator: " → "))
        case .myWords:
            guard let word = DoitActions.shared.quizWords(1).first else { return nil }
            if Bool.random() {
                return DoitQuizItem(question: "'\(word.term)'의 뜻은?", answers: [word.meaning], explanation: "\(word.term): \(word.meaning)")
            }
            return DoitQuizItem(question: "'\(word.meaning)'을(를) 영어로 쓰면?", answers: [word.term], explanation: "\(word.meaning): \(word.term)")
        case .english(let topic):
            if DoitActions.shared.wordCount >= 5, topic == nil, Bool.random(), let mine = await makeQuestion(.myWords) { return mine }
            return DoitEnglish.quiz(topic: topic)
        case .science(let topic):
            return DoitScience.quiz(topic: topic)
        case .social(let topic):
            return DoitSocial.quiz(topic: topic)
        case .lastTopic:
            guard let topic = lastAnswer?.topic, !topic.isEmpty else { return nil }
            if let set = try? await DoitTutor.ox(subject: "", unit: topic, count: 4), let item = set.items.randomElement() {
                return DoitQuizItem(question: "O/X 퀴즈: \(item.statement)", answers: item.isTrue ? ["O", "맞다", "맞아", "참", "ㅇ"] : ["X", "틀리다", "틀려", "아니", "거짓", "ㄴ"],
                                    explanation: item.explanation)
            }
            // 내장 과학·사회 퀴즈 중 같은 주제
            for item in [DoitScience.quiz(topic: topic), DoitSocial.quiz(topic: topic)].compactMap({ $0 })
            where item.explanation.contains(topic) || item.answers.contains(where: { topic.contains($0) }) {
                return item
            }
            return nil
        case .any:
            let pool: [DoitEngine.QuizSource] = [.math(nil), .english(nil), .science(nil), .social(nil)]
            return await makeQuestion(pool.randomElement() ?? .math(nil))
        }
    }

    /// Apple Intelligence에게 알려줄 오늘 상황
    private func contextLine() -> String {
        let c = DoitActions.shared.chatContext()
        var parts = ["오늘 공부 \(c.todayMinutes)분 / 목표 \(c.goalMinutes)분", "남은 플랜 \(c.remainingPlans)개"]
        if let d = c.dDay { parts.append(d) }
        return parts.joined(separator: ", ")
    }

    /// 사진 읽기: 문제·필기용(검은 글자 위주)과 단어장용(영어-뜻 짝)
    private func read(_ image: UIImage) async -> DoitEngine.PhotoContext {
        let text = await OCRService.readMathProblem(image).text
        let wordLines = (try? await OCRService.recognize(image)) ?? []
        let words = WordParser.parse(wordLines)
        return DoitEngine.PhotoContext(image: image, text: text, words: words)
    }
}
