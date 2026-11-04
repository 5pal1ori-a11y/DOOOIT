import Observation
import UIKit

/// 모티 AI 대화 (외부 AI·서버 없음)
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
    /// 대화 흐름 (주제·푼 문제·함수·일정·단어) — "그럼 3이면?", "왜?", "그거 단계별로" 같은 이어 말하기용
    @ObservationIgnored private(set) var dialogue = DoitDialogue.State()
    /// 이번 말에 대한 답의 종류 (답한 뒤 대화 흐름에 기록)
    @ObservationIgnored private var turn = TurnNote()

    private struct TurnNote {
        var question = ""
        var kind: DoitDialogue.Kind = .chat
        var topic: String?
        var fromModel = false
        var plan: String?
        var start = 0
    }

    func reset() {
        messages = []
        lastPhoto = nil
        lastAnswer = nil
        lastMath = nil
        quiz = nil
        dialogue = DoitDialogue.State()
        DoitEngine.conversationTopic = nil
        DoitTone.reset()
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
        var question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isResponding, !question.isEmpty || image != nil else { return }
        // 바로 전 모티 답 (규칙형 엔진이 앞 이야기를 이어 받을 때 씀)
        DoitTone.lastShown = messages.last(where: { $0.role == .assistant && !$0.isStreaming })?.text
        messages.append(Message(role: .user, text: question, image: image))
        isResponding = true
        // 바로 전 답에서 제안한 일("퀴즈 한 판 할까요?")에 "응"이라고 하면 그 일을 그대로 (화면에는 학생 말 그대로)
        if image == nil, let accepted = DoitTone.acceptedOffer(question) { question = accepted }
        turn = TurnNote(question: question, start: messages.count)
        defer { isResponding = false; status = "" }
        defer { rememberTurn() }

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
            turn.kind = .quiz
            messages.append(reply)
            return
        }

        // 2) 기억해 달라는 말, 틀렸다고 고쳐 주는 말
        if image == nil, let reply = await memoryCommand(question) {
            messages.append(reply)
            return
        }

        // 3) 모델이 쓴 대화를 이어 가는 말 ("그럼 그건 왜?", "그거 예시는?")은 규칙형 엔진이 가로채지 않고 모델이 앞 대화를 보고 답함
        //    (일정 추가·타이머 같은 앱 명령, 식이 분명한 수학 문제는 그대로 엔진이)
        if image == nil, DoitMind.isAvailable, dialogue.fromModel, DoitDialogue.continuesConversation(question), !DoitDialogue.isCommand(question) {
            await think(question: question, draft: nil, origin: .knowledge, suggestions: ["이걸로 퀴즈 내줘"], topic: dialogue.topic)
            return
        }
        // 바로 전 답에 이어서 (모델이 있으면 모델이 더 자세히·쉽게)
        if image == nil, let previous = lastAnswer, DoitMind.isAvailable, dialogue.focus != .math, let request = brainFollowUp(question, topic: previous.topic) {
            await think(question: request, draft: previous.text, origin: .knowledge, suggestions: ["이걸로 퀴즈 내줘", "메모로 저장해줘"], topic: previous.topic)
            return
        }
        if image == nil, let reply = await followUp(question) {
            messages.append(reply)
            return
        }

        // 4) 앞 대화로 풀리는 이어 말하기 ("그럼 3이면?", "왜?", "그거 단계별로", "x=3일 때는?", "그럼 독일은?")
        var routed = question
        if image == nil, dialogue.last != .quiz {
            switch DoitDialogue.resolve(question, state: dialogue) {
            case .none:
                break
            case .rewrite(let rewritten):
                if let reply = await followUp(rewritten) {
                    messages.append(reply)
                    return
                }
                routed = rewritten
                turn.question = rewritten
            case .answer(let text, let chips):
                // 설명을 이어 가는 말은 모델이 있으면 앞 대화를 보고 자기 말로 (수학·계산은 엔진 답 그대로)
                if DoitMind.isAvailable, dialogue.focus != .math, dialogue.focus != .calc {
                    await think(question: question, draft: dialogue.answer, origin: .knowledge, suggestions: chips, fallback: text, topic: dialogue.topic)
                    return
                }
                messages.append(Message(role: .assistant, text: text, suggestions: chips))
                return
            case .clarify(let text, let chips):
                if DoitMind.isAvailable, dialogue.hasContext {
                    await think(question: question, draft: nil, origin: .conversation, suggestions: chips, topic: dialogue.topic)
                    return
                }
                messages.append(Message(role: .assistant, text: text, suggestions: chips))
                return
            }
        }

        // 4-2) 문제 유형·과목 묻기: "이 문제 무슨 유형이야?", "이거 무슨 과목?", "영어 문제 유형 알려줘"
        if let reply = problemTypeReply(routed, photo: photo) {
            messages.append(reply)
            return
        }

        // 4-3) 사진 속 문제 풀기: 사진만 보냈는데 문제처럼 보이거나, "풀어줘"·"답 알려줘" (바로 전 사진도)
        if let reply = await solvePhotoProblem(routed, photo: photo, fresh: image != nil) {
            messages.append(reply)
            return
        }

        // 5) 사진: 그래프·도형·일반 사진·QR·문서는 그림 분석으로 답함 (문제 사진·단어장·저장 부탁은 아래 엔진이 처리)
        if let image, let analyzed = await analyzePhoto(image, question: question, photo: photo) {
            messages.append(analyzed)
            return
        }

        var reply = DoitEngine.respond(to: routed, photo: photo)
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
        if reply.text.hasPrefix("**") && reply.suggestions.contains("비슷한 문제 내줘") { lastMath = routed }
        noteKind(of: reply, question: routed, actions: actions)

        // 다른 주제로 샌 답 막기 (질문의 핵심 낱말이 답에 하나도 없음): 모델이 있으면 모델이, 없으면 짐작하지 않고 되물음
        if image == nil, actions.isEmpty, isGuardable(reply), DoitDialogue.isOffTopic(question: routed, reply: reply.text) {
            if DoitMind.isAvailable {
                await think(question: routed, draft: nil, origin: .knowledge, suggestions: [], topic: dialogue.topic)
                return
            }
            turn.kind = .chat
            let guarded = DoitRelevance.dontKnow(routed)
            messages.append(Message(role: .assistant, text: guarded.text, suggestions: guarded.suggestions))
            return
        }

        // 설명·대화는 모델이 근거를 읽고 자기 말로 (앱 기능·계산·수학 풀이는 엔진 답 그대로)
        if image == nil, actions.isEmpty, shouldThink(reply, question: routed) {
            await think(question: routed, draft: reply.origin == .conversation && !reply.text.hasPrefix("혹시") ? nil : reply.text,
                        origin: reply.origin, suggestions: reply.suggestions, fallback: reply.text)
            return
        }

        if reply.suggestions.contains("더 자세히 알려줘") || reply.text.hasPrefix("**") {
            // 앱 안 지식으로 답한 것도 이어서 묻기·저장할 수 있게
            let firstLine = reply.text.components(separatedBy: "\n").first ?? ""
            // "**광합성** (과학)" → "광합성"
            let title = firstLine.components(separatedBy: "**").dropFirst().first ?? firstLine.replacingOccurrences(of: "**", with: "")
            // "임진왜란: 1592~1598년" → "임진왜란"
            let topic = DoitDialogue.topic(fromReply: reply.text) ?? title
            lastAnswer = (topic, reply.text)
            DoitEngine.conversationTopic = topic
        }
        messages.append(Message(role: .assistant, text: reply.text, actions: actions, suggestions: reply.suggestions))
    }

    // MARK: - 대화 흐름

    /// 엔진 답의 종류를 이번 말에 적어 둠 (답한 뒤 대화 흐름에 기록)
    private func noteKind(of reply: DoitEngine.Reply, question: String, actions: [String]) {
        if reply.text.contains("**답:") || reply.text.contains("\n**답 ") {
            turn.kind = .math
        } else if actions.contains(where: { $0.hasPrefix("플랜 추가") }) || reply.text.hasPrefix("[ADD PLAN]") {
            turn.kind = .plan
            turn.plan = DoitEngine.planTitle(from: question)
        } else if !actions.isEmpty {
            turn.kind = .command
        } else if question.contains("뜻"), DoitEnglish.lookupWord(in: question) != nil {
            turn.kind = .word
        } else {
            switch reply.origin {
            case .subject: turn.kind = question.contains(where: \.isNumber) ? .calc : .subject
            case .knowledge: turn.kind = .knowledge
            case .conversation: turn.kind = reply.text.hasPrefix("혹시") ? .knowledge : .chat
            case .command, .math: turn.kind = .command
            case .chat: turn.kind = .chat
            }
        }
    }

    /// 다른 주제로 샜는지 볼 답 (개념 설명·과목 설명·"혹시 …" 짐작). 앱 명령·수학 풀이·일상 대화는 보지 않음
    private func isGuardable(_ reply: DoitEngine.Reply) -> Bool {
        guard reply.deferred == nil, !reply.text.contains("**답:") else { return false }
        switch reply.origin {
        case .knowledge, .subject: return true
        case .conversation: return reply.text.hasPrefix("혹시")
        case .chat, .command, .math: return false
        }
    }

    /// 답한 뒤: 대화 흐름 기록
    private func rememberTurn() {
        guard messages.count > turn.start, let reply = messages.last, reply.role == .assistant, !reply.isStreaming else { return }
        DoitDialogue.update(&dialogue, question: turn.question, reply: reply.text, kind: turn.kind, topic: turn.topic, fromModel: turn.fromModel)
        if turn.kind == .plan, let plan = turn.plan { dialogue.entities["plan"] = plan }
    }

    // MARK: - 모델

    private func shouldThink(_ reply: DoitEngine.Reply, question: String) -> Bool {
        guard DoitMind.isAvailable, reply.deferred == nil else { return false }
        switch reply.origin {
        case .command, .math: return false
        // 과목 엔진의 계산(전압·전류 등)은 숫자가 정확해야 해서 그대로
        case .subject: return !question.contains(where: \.isNumber)
        // 가벼운 일상 대화("ㅋㅋ", "고마워")는 모티 1(작은 모델)보다 엔진이 고른 답이 더 자연스러워서 그대로
        // (모델 비교: 작은 모델은 잡담에 엉뚱한 말·이상한 말투가 자주 나옴)
        case .chat: return !(DoitBrain.shared.selected == .dooit1 && DoitMind.style(for: question, chat: true) == .casual)
        case .knowledge, .conversation: return true
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
    /// topic: 지금 이야기 중인 주제 (이어 말하기일 때 모델이 앞 이야기를 잇게)
    private func think(question: String, draft: String?, origin: DoitEngine.Origin, suggestions: [String], fallback: String? = nil, topic hint: String? = nil) async {
        // 이전 대화: 학생·모티 역할 그대로, 토큰 예산 안에서 최근 것부터 (넘친 오래된 대화는 짧게 요약)
        let turns = messages.dropLast().compactMap { message -> DoitMind.Turn? in
            guard !message.isStreaming, !message.text.isEmpty else { return nil }
            switch message.role {
            case .user: return DoitMind.Turn(fromUser: true, text: message.text)
            case .assistant: return DoitMind.Turn(fromUser: false, text: message.text)
            case .notice: return nil
            }
        }
        let history = DoitMind.budgetHistory(Array(turns), maxTokens: DoitBrain.shared.historyBudget)
        let topicHint = hint ?? (DoitDialogue.continuesConversation(question) ? dialogue.topic : nil)
        // 말투: 가벼운 일상 대화는 1~2문장, 상담은 2~4문장, 공부 질문은 필요한 만큼 (짧은 말에는 짧게)
        let style = topicHint == nil ? DoitMind.style(for: question, chat: origin == .chat) : .study
        let previous = turns.last(where: { !$0.fromUser })?.text
        let wantsWeb = origin != .chat && style != .casual
        status = wantsWeb ? "자료를 찾아 읽는 중…" : "생각하는 중…"
        // "왜?"처럼 짧은 이어 말하기는 주제를 붙여서 자료를 찾음
        let searchQuestion = topicHint.map { DoitDialogue.continuesConversation(question) ? "\($0) \(question)" : question } ?? question
        let situation = origin == .chat && DoitMind.wantsSituation(question, style: style) ? appSituation() : nil
        let context = await DoitMind.gather(question: searchQuestion, draft: draft, app: situation, allowWeb: wantsWeb, casual: style == .casual)
        status = context.web.isEmpty ? "생각하는 중…" : "찾은 자료를 정리하는 중…"
        messages.append(Message(role: .assistant, text: "", isStreaming: true))
        let index = messages.count - 1
        let id = messages[index].id
        var raw = ""
        var shown = Date.distantPast
        // 이유·원리·계산 질문은 DOOOIT 2가 먼저 속으로 생각(추론)한 뒤 답함 (생각 과정은 안 보여 줌)
        let reasoning = origin != .chat && style != .casual && DoitBrain.shared.selected == .dooit2 && DoitMind.needsReasoning(question)
        if reasoning { status = "깊게 생각하는 중…" }
        do {
            for try await chunk in DoitBrain.shared.stream(system: DoitMind.persona,
                                                           prompt: DoitMind.answerPrompt(question: question, context: context, history: [],
                                                                                         summary: history.summary, topic: topicHint, style: style),
                                                           history: history.recent,
                                                           maxTokens: reasoning ? 1400 : DoitMind.maxTokens(for: style),
                                                           temperature: style == .casual ? 0.7 : (origin == .chat || origin == .conversation ? 0.6 : 0.4),
                                                           thinking: reasoning) {
                raw += chunk
                // 화면은 조금씩 모아서 고침 (낱말 조각마다 다시 그리면 말풍선이 흔들림)
                guard Date().timeIntervalSince(shown) > 0.06 else { continue }
                shown = Date()
                if messages.indices.contains(index), messages[index].id == id {
                    messages[index].text = DoitMind.chatAnswer(raw, question: question, previous: previous, style: style, final: false)
                }
            }
        } catch {
            raw = ""
        }
        guard messages.indices.contains(index), messages[index].id == id else { return }
        let text = DoitMind.chatAnswer(raw, question: question, previous: previous, style: style)
        messages[index].isStreaming = false
        guard DoitMind.isUsable(text, question: question) else {
            // 모델 답이 비었거나 이상하면 엔진 답으로
            messages[index].text = fallback ?? draft ?? "답을 만들지 못했어요. 다시 한 번 물어봐 줄래요?"
            messages[index].suggestions = suggestions
            return
        }
        let topic = DoitMind.topic(for: question, context: context)
        // 모델이 쓴 답도 말투 기록에 남김 (엔진이 만들어 둔 제안은 보이지 않았으니 지움)
        DoitTone.remember(text, kind: origin == .chat ? "chat" : "study")
        turn.fromModel = true
        turn.kind = origin == .chat ? .chat : .model
        turn.topic = DoitDialogue.continuesConversation(question) ? (topicHint ?? topic) : topic
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
            return Message(role: .assistant, text: "**모티 AI가 배운 내용** (\(DoitMemory.shared.notes.count)개)\n" + lines.joined(separator: "\n") + "\n\n위쪽 모델 메뉴 > 배운 내용에서 관리할 수 있어요.")
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
        // 수학 풀이 뒤 "더 쉽게"는 대화 흐름(DoitDialogue)이 개념·답으로 짧게
        if dialogue.focus != .math, q.contains("쉽게") || q.contains("요약") || q.contains("한줄") || q.contains("간단히") {
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
        // 답이 아니라 새 질문 ("광합성이 뭐야", "임진왜란 언제야?")이면 퀴즈를 끝내고 그 질문에 답함
        let asking = ["뭐야", "뭐지", "뭔데", "뭐예요", "설명", "알려", "어떻게", "왜", "언제야", "누구야", "어디야", "이란", "뜻이"].contains { q.contains($0) }
        if !giveUp, asking, !DoitChat.isCorrect(answer, item: state.item) {
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

    /// 사진 속 문제를 읽고 풀기: 수학은 풀이 엔진(계산으로 확인), 못 풀면 · 다른 과목은 모티 1·2 모델 (추측 표시)
    private func solvePhotoProblem(_ question: String, photo: DoitEngine.PhotoContext?, fresh: Bool) async -> Message? {
        guard let photo, !photo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let asked = DoitAutoSolve.asksToSolve(question)
        // 사진만 보냈으면 문제처럼 보일 때만 (단어장 사진은 단어 처리로)
        guard asked || (fresh && question.isEmpty && photo.words.count < 3) else { return nil }
        let text = photo.text
        let subject = DoitSubjectDetector.detect(text)
        let isMath = subject?.broad == "수학" || (subject == nil && (DoitMath.looksLikeMath(text) || DoitSubjectDetector.looksMath(text)))
        let scan = DoitProblemScan.scan(text, math: isMath)
        guard asked || DoitAutoSolve.looksLikeProblem(text, scan: scan) else { return nil }
        let choices = scan.choices
        let isChoice = choices.count >= 2
        let type = scan.problemType ?? DoitProblemTypes.classify(text, subjectHint: subject?.broad, limit: 1).first?.type
        status = "문제를 푸는 중…"
        turn.kind = .chat

        var solution: WrittenSolution?
        var mathSolved = false
        if isMath || DoitMath.looksLikeMath(text) {
            solution = DoitAutoSolve.engine(text: text, choices: choices, isChoice: isChoice, body: scan.body)
            mathSolved = solution != nil
        }
        // 규칙·자료로 확인한 답 (과학 계산은 수학처럼 보여도 여기서 풀림: 과학 공식, 영어 문법, 분류·사실·연표, 맞춤법)
        if solution == nil {
            solution = DoitSubjectSolve.solve(text: text, choices: isChoice ? choices : [], subjectBroad: subject?.broad, body: scan.body, boxItems: scan.boxItems)
        }
        // 모델은 수학이 아닌 과목만 (작은 모델의 수학 답은 자주 틀려서 계산으로 확인한 답만)
        // 보기 항목을 하나씩 따지는 문제: 항목마다 O·X, 선지는 앱이 (두 번 물어 같을 때만)
        var judged = false
        if !isMath, solution == nil, DoitMind.isAvailable, isChoice,
           let setup = DoitItemJudge.setup(text: text, body: scan.body, choices: choices, boxItems: scan.boxItems) {
            status = "모티 AI가 항목을 하나씩 따지는 중…"
            solution = await DoitItemJudge.run(setup, subjectName: subject?.noteLabel ?? "모름", problem: text)
            judged = true
        }
        if !isMath, !judged, solution == nil, DoitMind.isAvailable {
            status = "모티 AI가 문제를 푸는 중…"
            let body = scan.body.isEmpty ? text : scan.body
            let material = DoitAutoSolve.modelMaterial(text: text, body: scan.body, choices: isChoice ? choices : [], boxItems: scan.boxItems,
                                                       subject: NoteSubject.from(subject?.broad ?? "기타"))
            let prompt = DoitAutoSolve.modelPrompt(problem: body, choices: isChoice ? choices : [],
                                                   subjectName: subject?.noteLabel ?? (isMath ? "수학" : "모름"), problemType: type,
                                                   reference: material.reference, hints: material.hints)
            if let raw = try? await DoitBrain.shared.complete(system: DoitMind.persona, prompt: prompt, maxTokens: 600, temperature: 0.2),
               let guess = DoitAutoSolve.parseModel(DoitMind.answer(raw), problem: text, choices: isChoice ? choices : []),
               solution == nil {
                solution = guess
            }
        }
        var suggestions = ["오답노트에 저장해줘"]
        if let solution {
            if isMath, mathSolved { lastMath = scan.body.isEmpty ? text : scan.body; suggestions.append("비슷한 문제 내줘") }
            suggestions.append("이 문제 무슨 유형이야?")
            let answer = DoitAutoSolve.chatText(solution, choices: choices, typeName: type?.name)
            // 그림에서 읽은 것을 먼저 보여 줌 (기계가 읽은 값이라 틀렸으면 고쳐서 다시 보내게)
            let seen = DoitFigureFacts.chatBlock(text).map { $0 + "\n\n" } ?? ""
            return Message(role: .assistant, text: seen + answer, suggestions: suggestions)
        }
        // 못 풀었으면: 읽은 문제 + 푸는 법 (정답을 지어내지 않음)
        var lines = ["이 문제는 제가 확실하게 풀지 못했어요."]
        if let type {
            lines.append("📌 \(type.name) 문제예요. \(type.asks)")
            if !type.steps.isEmpty { lines.append("푸는 법 · " + type.steps.prefix(3).joined(separator: " → ")) }
        }
        if let seen = DoitFigureFacts.chatBlock(text) { lines.append("\n" + seen) }
        lines.append("\n읽은 문제\n" + MathSymbolBar.pretty(String(DoitFigureFacts.split(text).problem.prefix(400))))
        if isMath { lines.append("\n틀린 답을 보여 주지 않으려고 계산으로 확인한 답만 알려 줘요. 글자가 잘못 읽혔으면 고쳐서 보내 주세요.") }
        else if !DoitMind.isAvailable { lines.append("\n위쪽 메뉴에서 모티 모델을 받으면 다른 과목 문제도 풀어 봐요.") }
        else { lines.append("\n글자가 잘못 읽혔으면 고쳐서 보내 주세요.") }
        return Message(role: .assistant, text: lines.joined(separator: "\n"), suggestions: suggestions)
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
    /// 문제 유형 사전으로 "무슨 유형/과목인지" 답하기 (문제 글은 질문 속 글 → 사진 → 바로 전 문제 순)
    private func problemTypeReply(_ question: String, photo: DoitEngine.PhotoContext?) -> Message? {
        // "취약 유형 학습" 같은 말은 빼고, 유형을 묻는 말일 때만
        let asksType = question.range(of: #"(무슨|어떤|어느|뭔|무엇)\s*(문제\s*)?유형|유형\s*(이|은|는|을|좀)?\s*(뭐|알려|말해|설명)|문제\s*유형|[?？.]\s*유형\s*[?？]*$"#, options: .regularExpression) != nil
        let asksSubject = question.range(of: #"(무슨|어떤|어느|뭔)\s*과목"#, options: .regularExpression) != nil
        guard asksType || asksSubject else { return nil }
        // 묻는 말을 빼고 남은 문제 글
        var target = question.replacingOccurrences(
            of: #"(이|그|위|이번|저)?\s*(문제|거|건|것)?\s*(는|은|의)?\s*(무슨|어떤|어느|뭔|무엇)?\s*(문제\s*)?(유형|과목)\s*(이야|이에요|인가요|인지|야|이지|일까|은|는|을|를|좀)?\s*(알려\s*줘|알려\s*주세요|말해\s*줘|뭐야|봐\s*줘)?\s*[?？.!]*"#,
            with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        if target.count < 8, let text = photo?.text, !text.isEmpty { target = text }
        if target.count < 8, let math = lastMath { target = math }

        // 문제 없이 과목만 말하면 그 과목의 유형 목록 ("영어 문제 유형 알려줘")
        let subjects = ["국어", "영어", "수학", "과학", "사회", "역사", "윤리", "물리학", "화학", "생명과학", "지구과학", "한국사", "세계사", "한국지리", "세계지리", "경제", "정치와 법", "사회·문화", "생활과 윤리", "윤리와 사상", "도덕", "문학", "독서", "문법"]
        if asksType, target.count < 14, let subject = subjects.first(where: { question.contains($0) }) {
            let list = DoitProblemTypes.types(subject: subject)
            guard !list.isEmpty else { return nil }
            var seen = Set<String>()
            let names = list.map(\.name).filter { seen.insert($0).inserted }
            let shown = names.prefix(20).map { "· " + $0 }.joined(separator: "\n")
            return Message(role: .assistant, text: "\(subject) 문제 유형 \(names.count)가지 중 자주 나오는 것\n\(shown)\n\n문제를 보내면 어떤 유형인지와 푸는 법을 알려줄게요.",
                           suggestions: ["이 문제 무슨 유형이야?"])
        }
        guard target.count >= 8 else {
            return Message(role: .assistant, text: "문제 글이나 사진을 같이 보내 주세요. 유형과 푸는 법을 알려줄게요.")
        }
        let guess = DoitSubjectDetector.detect(target)
        let matches = DoitProblemTypes.classify(target, subjectHint: guess?.broad)
        guard let best = matches.first else {
            if let guess, asksSubject {
                return Message(role: .assistant, text: "과목 · \(guess.noteLabel)")
            }
            return Message(role: .assistant, text: "어떤 유형인지 확실하지 않아요. 문제의 질문 부분(예: \"~로 가장 적절한 것은?\")까지 보내 주세요.")
        }
        var lines: [String] = []
        if let guess { lines.append("과목 · \(guess.noteLabel)") }
        lines.append(DoitProblemTypes.explain(best))
        if matches.count > 1, matches[1].score >= best.score - 0.08, matches[1].type.name != best.type.name {
            lines.append("비슷한 유형 · \(matches[1].type.name)")
        }
        return Message(role: .assistant, text: lines.joined(separator: "\n"), suggestions: ["이 유형 문제 푸는 팁 더 알려줘"])
    }

    private func read(_ image: UIImage) async -> DoitEngine.PhotoContext {
        var text = await OCRService.readMathProblem(image).text
        let wordLines = (try? await OCRService.recognize(image)) ?? []
        let words = WordParser.parse(wordLines)
        // 그림·그래프·표가 있는 문제: 그림에서 읽은 사실을 블록으로 붙임 (풀기 전에 학생에게 보여 줌)
        if words.count < 3, DoitFigureFacts.mentionsFigure(text) {
            status = "그림을 읽는 중…"
            if let figure = await FigureReader.read(image, problemText: text) { text = DoitFigureFacts.attach(figure, to: text) }
        }
        return DoitEngine.PhotoContext(image: image, text: text, words: words)
    }
}
