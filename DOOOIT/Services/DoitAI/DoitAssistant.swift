import Observation
import UIKit

/// 두잇 AI 대화 (외부 AI·서버 없음)
/// - 규칙형 엔진: 앱 기능 실행, 수학 풀이, 계산, 퀴즈, 사진 분석 (정확해야 하는 일)
/// - 모델(기기 안 언어 모델, 받아 두었을 때): 설명·대화를 근거(앱 지식·배운 기억·인터넷)를 읽고 자기 말로
/// 사진은 기기 안 글자 인식(Vision)으로 읽음
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
        /// 모델이 참고한 자료 (앱 지식, 배운 내용, 위키백과)
        var sources: [String] = []
        /// 👍/👎를 받을 주제 (모델이 만든 답만)
        var learnTopic: String?
        /// 1 = 👍, -1 = 👎
        var rating = 0
        /// 모델이 아직 쓰는 중
        var isStreaming = false
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

    func reset() {
        messages = []
        lastPhoto = nil
        lastAnswer = nil
        lastMath = nil
        quiz = nil
        DoitEngine.conversationTopic = nil
    }

    /// 답 평가 (👍는 그 설명을 기억, 👎는 다음에 인터넷에서 다시 찾아봄)
    func rate(_ id: UUID, good: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == id }), let topic = messages[index].learnTopic,
              messages[index].rating == 0 else { return }
        messages[index].rating = good ? 1 : -1
        DoitMemory.shared.feedback(topic: topic, answer: messages[index].text, good: good)
        if !good { messages[index].suggestions = ["\(topic) 인터넷에서 다시 찾아줘"] + messages[index].suggestions.prefix(1) }
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

        // 2) 기억해 달라는 말, 틀렸다고 고쳐 주는 말
        if image == nil, let reply = await memoryCommand(question) {
            messages.append(reply)
            return
        }

        // 3) 바로 전 답에 이어서 (모델이 있으면 모델이 더 자세히·쉽게)
        if image == nil, let previous = lastAnswer, DoitMind.isAvailable, let request = brainFollowUp(question, topic: previous.topic) {
            await think(question: request, draft: previous.text, origin: .knowledge, suggestions: ["이걸로 퀴즈 내줘", "메모로 저장해줘"])
            return
        }
        if image == nil, let reply = await followUp(question) {
            messages.append(reply)
            return
        }

        // 4) 사진: 그래프·도형·일반 사진·QR·문서는 그림 분석으로 답함 (문제 사진·단어장·저장 부탁은 아래 엔진이 처리)
        if let image, let analyzed = await analyzePhoto(image, question: question, photo: photo) {
            messages.append(analyzed)
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

        // 설명·대화는 모델이 근거를 읽고 자기 말로 (앱 기능·계산·수학 풀이는 엔진 답 그대로)
        if image == nil, actions.isEmpty, shouldThink(reply, question: question) {
            await think(question: question, draft: reply.origin == .conversation && !reply.text.hasPrefix("혹시") ? nil : reply.text,
                        origin: reply.origin, suggestions: reply.suggestions, fallback: reply.text)
            return
        }

        if reply.suggestions.contains("더 자세히 알려줘") || reply.text.hasPrefix("**") {
            // 앱 안 지식으로 답한 것도 이어서 묻기·저장할 수 있게
            let firstLine = reply.text.components(separatedBy: "\n").first ?? ""
            // "**광합성** (과학)" → "광합성"
            let topic = firstLine.components(separatedBy: "**").dropFirst().first ?? firstLine.replacingOccurrences(of: "**", with: "")
            lastAnswer = (topic, reply.text)
            DoitEngine.conversationTopic = topic
        }
        messages.append(Message(role: .assistant, text: reply.text, actions: actions, suggestions: reply.suggestions))
    }

    // MARK: - 모델

    private func shouldThink(_ reply: DoitEngine.Reply, question: String) -> Bool {
        guard DoitMind.isAvailable, reply.deferred == nil else { return false }
        switch reply.origin {
        case .command, .math: return false
        // 과목 엔진의 계산(전압·전류 등)은 숫자가 정확해야 해서 그대로
        case .subject: return !question.contains(where: \.isNumber)
        case .chat, .knowledge, .conversation: return true
        }
    }

    /// "더 자세히" / "쉽게" / "요약" → 모델에게 줄 부탁
    private func brainFollowUp(_ question: String, topic: String) -> String? {
        let q = question.replacingOccurrences(of: " ", with: "")
        if q.contains("더자세히") || q.contains("자세히알려") || q.contains("더알려") || q == "더" || q.contains("계속") {
            return "\(topic)에 대해 앞에서 말한 것보다 더 깊이, 예시를 들어 자세히 알려줘"
        }
        if q.contains("쉽게") || q.contains("요약") || q.contains("한줄") || q.contains("간단히") {
            return "\(topic)을(를) 초등학생도 알 수 있게 한두 문장으로 쉽게 말해줘"
        }
        if q.contains("예시") || q.contains("예를") {
            return "\(topic)의 쉬운 예시를 두세 개 들어줘"
        }
        return nil
    }

    /// 근거를 모으고, 모델이 쓰는 답을 조금씩 보여줌. 답이 이상하면 엔진 답(fallback)으로 바꿈
    private func think(question: String, draft: String?, origin: DoitEngine.Origin, suggestions: [String], fallback: String? = nil) async {
        let history = messages.dropLast().suffix(6).compactMap { message -> DoitMind.Turn? in
            switch message.role {
            case .user: return message.text.isEmpty ? nil : DoitMind.Turn(fromUser: true, text: message.text)
            case .assistant: return message.text.isEmpty ? nil : DoitMind.Turn(fromUser: false, text: message.text)
            case .notice: return nil
            }
        }
        let wantsWeb = origin != .chat
        status = wantsWeb ? "자료를 찾아 읽는 중…" : "생각하는 중…"
        let context = await DoitMind.gather(question: question, draft: draft, app: origin == .chat ? appSituation() : nil, allowWeb: wantsWeb)
        status = context.web.isEmpty ? "생각하는 중…" : "찾은 자료를 정리하는 중…"
        messages.append(Message(role: .assistant, text: "", isStreaming: true))
        let index = messages.count - 1
        let id = messages[index].id
        var raw = ""
        // 이유·원리·계산 질문은 DOOOIT 2가 먼저 속으로 생각(추론)한 뒤 답함 (생각 과정은 안 보여 줌)
        let reasoning = origin != .chat && DoitBrain.shared.selected == .dooit2 && DoitMind.needsReasoning(question)
        if reasoning { status = "깊게 생각하는 중…" }
        do {
            for try await chunk in DoitBrain.shared.stream(system: DoitMind.persona,
                                                           prompt: DoitMind.answerPrompt(question: question, context: context, history: Array(history)),
                                                           maxTokens: reasoning ? 1400 : 600,
                                                           temperature: origin == .chat || origin == .conversation ? 0.6 : 0.4,
                                                           thinking: reasoning) {
                raw += chunk
                if messages.indices.contains(index), messages[index].id == id { messages[index].text = DoitMind.answer(raw) }
            }
        } catch {
            raw = ""
        }
        guard messages.indices.contains(index), messages[index].id == id else { return }
        let text = DoitMind.answer(raw)
        messages[index].isStreaming = false
        guard DoitMind.isUsable(text) else {
            // 모델 답이 비었거나 이상하면 엔진 답으로
            messages[index].text = fallback ?? draft ?? "답을 만들지 못했어요. 다시 한 번 물어봐 줄래요?"
            messages[index].suggestions = suggestions
            return
        }
        let topic = DoitMind.topic(for: question, context: context)
        messages[index].text = text
        messages[index].sources = context.sourceLabels
        messages[index].suggestions = suggestions
        if origin != .chat {
            messages[index].learnTopic = topic
            lastAnswer = (topic, text)
            DoitEngine.conversationTopic = topic
        }
        DoitMind.learn(question: question, answer: text, context: context)
    }

    /// 일상 대화에 쓰는 오늘 상황
    private func appSituation() -> String {
        let c = DoitActions.shared.chatContext()
        var lines = ["오늘 공부 \(c.todayMinutes)분 (목표 \(c.goalMinutes)분)", "남은 일정 \(c.remainingPlans)개"]
        if let dDay = c.dDay { lines.append(dDay) }
        if let name = DoitConversation.userName { lines.append("학생 이름: \(name)") }
        return lines.joined(separator: "\n")
    }

    // MARK: - 기억

    /// "기억해줘: …", "배운 거 보여줘", 바로 전 답을 "아니야, …"로 고쳐 주기
    private func memoryCommand(_ question: String) async -> Message? {
        let q = question.replacingOccurrences(of: " ", with: "")
        if let m = question.firstMatch(of: #/^(?:기억해\s*줘|기억해|외워\s*둬|기억할래)\s*[:：]?\s*(.{2,})$/#) ?? question.firstMatch(of: #/^(.{4,}?)\s*(?:라고|이라고)?\s*기억해\s*줘[.!]?$/#) {
            let fact = String(m.1).trimmingCharacters(in: .whitespacesAndNewlines)
            let topic = DoitWeb.searchQuery(from: fact)
            DoitMemory.shared.remember(topic: topic.isEmpty ? String(fact.prefix(20)) : topic, summary: fact, kind: .userFact)
            return Message(role: .assistant, text: "기억해 둘게요! 다음에 관련된 이야기를 하면 이 내용을 떠올릴게요.\n• \(fact)",
                           suggestions: ["배운 거 보여줘"])
        }
        if ["배운거보여", "배운것보여", "기억한거보여", "기억목록", "뭘배웠어", "뭐배웠어", "배운내용"].contains(where: { q.contains($0) }) {
            let notes = DoitMemory.shared.notes.sorted { $0.updatedAt > $1.updatedAt }.prefix(8)
            guard !notes.isEmpty else {
                return Message(role: .assistant, text: "아직 따로 배운 내용이 없어요. 궁금한 걸 물어보거나 \"기억해줘: …\"라고 알려주면 차곡차곡 배울게요.")
            }
            let lines = notes.map { note -> String in
                let mark = note.kind == .learned ? "📘" : (note.kind == .correction ? "✏️" : "📝")
                return "\(mark) **\(note.topic)**: \(DoitMemory.trimmed(note.summary.replacingOccurrences(of: "\n", with: " "), max: 60))"
            }
            return Message(role: .assistant, text: "**두잇 AI가 배운 내용** (\(DoitMemory.shared.notes.count)개)\n" + lines.joined(separator: "\n") + "\n\n위쪽 모델 메뉴 > 배운 내용에서 관리할 수 있어요.")
        }
        // "아니야 괜찮아", "아니 됐어" 같은 말은 고쳐 주는 말이 아님
        let casual = ["괜찮", "됐어", "고마워", "그냥", "아무것도", "몰라", "ㅋㅋ", "알겠어", "아니야아니야"]
        if let previous = lastAnswer, q.count >= 9, !casual.contains(where: { q.contains($0) }),
           ["아니야", "아니에요", "틀렸어", "틀렸어요", "그게아니라", "잘못알고", "사실은"].contains(where: { q.hasPrefix($0) }) {
            DoitMemory.shared.remember(topic: previous.topic, summary: question, kind: .correction)
            if DoitMind.isAvailable {
                await think(question: "학생이 앞의 설명을 이렇게 고쳐 줬어요: \"\(question)\". 고쳐 준 내용이 맞는지 생각해 보고 \(previous.topic)을(를) 다시 설명해줘",
                            draft: previous.text, origin: .knowledge, suggestions: ["이걸로 퀴즈 내줘"])
                // think가 넣은 답을 꺼내 돌려줌 (send가 다시 넣음)
                return messages.popLast()
            }
            return Message(role: .assistant, text: "알려줘서 고마워요! '\(previous.topic)'에 대해 고쳐 준 내용을 기억해 둘게요.")
        }
        return nil
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
            return Message(role: .assistant, text: DoitTutor.more(about: previous.topic, previous: previous.text),
                           suggestions: ["이걸로 퀴즈 내줘", "메모로 저장해줘"])
        }
        if q.contains("메모") && (q.contains("저장") || q.contains("남겨")) {
            let result = DoitActions.shared.addMemo(previous.text.replacingOccurrences(of: "**", with: ""))
            lastAnswer = nil
            return Message(role: .assistant, text: result, actions: DoitActions.shared.drainLog())
        }
        if q.contains("쉽게") || q.contains("요약") || q.contains("한줄") || q.contains("간단히") {
            let lines = previous.text.components(separatedBy: "\n").filter { !$0.isEmpty && !$0.hasPrefix("출처") }
            let summary = lines.prefix(3).joined(separator: "\n")
            return Message(role: .assistant, text: summary, suggestions: ["더 자세히 알려줘", "이걸로 퀴즈 내줘"])
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
        // 퀴즈와 상관없는 부탁(일정 추가, 타이머, 설명 등)이면 퀴즈를 끝내고 넘김
        let commandWords = ["추가해", "타이머", "일정", "플랜", "메모", "삭제", "알려줘", "설명해", "풀어줘", "뜻", "통계", "열어줘", "보여줘", "디데이", "d-day"]
        if !giveUp && answer.count > 8 && commandWords.contains(where: { answer.lowercased().contains($0) }) {
            quiz = nil
            return nil
        }
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
            if let item = DoitStudy.quickOX(topic: topic) {
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

    /// 사진 분석 (그래프 식, 도형 계산, 사진 속 사물, QR, 문서)
    private func analyzePhoto(_ image: UIImage, question: String, photo: DoitEngine.PhotoContext?) async -> Message? {
        let q = question.replacingOccurrences(of: " ", with: "")
        // 저장·단어·풀이 부탁은 기존 처리 (오답노트, 단어장, 메모, 수학 풀이)
        let commands = ["오답", "노트", "저장", "단어", "메모", "풀어", "풀이", "계산"]
        if commands.contains(where: { q.contains($0) }) { return nil }
        status = "사진을 분석하는 중…"
        let analysis = await VisionAnalyzer.analyze(image)
        switch analysis.kind {
        case .mathProblem, .empty:
            return nil
        case .document:
            // 글이 많은 사진: 단어장이면 기존 처리, 아니면 읽은 글 + 할 수 있는 일
            if let photo, photo.words.count >= 3 { return nil }
            var suggestions = ["메모로 저장해줘"]
            if let photo, !photo.text.isEmpty, DoitMath.looksLikeMath(photo.text) { suggestions.insert("이 식 풀어줘", at: 0) }
            return Message(role: .assistant, text: analysis.message, suggestions: suggestions)
        case .graph:
            var suggestions: [String] = []
            if let graph = analysis.graph, let equation = graph.equation {
                switch graph.kind {
                case .quadratic: suggestions = ["\(equation) 꼭짓점", "\(equation) 최솟값"]
                case .linear: suggestions = ["\(equation) 기울기"]
                case .cubic: suggestions = ["f(x) = \(equation.replacingOccurrences(of: "y = ", with: "")) 극값"]
                default: break
                }
                lastMath = equation
            }
            return Message(role: .assistant, text: analysis.message, suggestions: suggestions + ["비슷한 문제 내줘"])
        case .figure:
            return Message(role: .assistant, text: analysis.message, suggestions: ["도형 퀴즈 내줘"])
        case .photo, .qrCode:
            return Message(role: .assistant, text: analysis.message)
        }
    }

    /// 사진 읽기: 문제·필기용(검은 글자 위주)과 단어장용(영어-뜻 짝)
    private func read(_ image: UIImage) async -> DoitEngine.PhotoContext {
        let text = await OCRService.readMathProblem(image).text
        let wordLines = (try? await OCRService.recognize(image)) ?? []
        let words = WordParser.parse(wordLines)
        return DoitEngine.PhotoContext(image: image, text: text, words: words)
    }
}
