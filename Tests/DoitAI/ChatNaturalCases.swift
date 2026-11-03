import Foundation

// 대화 말투 테스트 (자연스럽게)
// - 모티 ZERO(규칙형 엔진): 같은 말을 연달아 해도 답이 바뀌는지, 일상 대화 답이 짧은지, 해요체·"당신" 없음,
//   앞 이야기를 이어 받는지 (농담 뒤 "ㅋㅋ", 설명 뒤 "고마워"), 제안한 일에 "응"이라고 하면 그대로 하는지
// - 모델 답 다듬기: 생각 태그·프롬프트 글·혼자 이어 쓴 대화·한자·영어 문장 빼기, "~습니다" → 해요체,
//   "저는 AI라서" 빼기, 뜬금없는 인사·같은 첫마디 빼기, 일상 대화는 짧게, 공부 답은 그대로

@MainActor
func runChatNaturalCases() async {
    let assistant = DoitAssistant.shared
    func say(_ inputs: [String]) async -> [String] {
        var replies: [String] = []
        for input in inputs {
            await assistant.send(input)
            replies.append(assistant.messages.last?.text ?? "")
        }
        return replies
    }
    let casual = ["안녕", "ㅋㅋ", "심심해", "피곤해", "오늘 공부 하기 싫어", "고마워", "졸려", "배고파", "너무 힘들어", "뭐해?", "잘자", "기분 좋아",
                  "짜증나", "ㅠㅠ", "미안해", "사랑해", "응원해줘", "시험 망했어", "그래도 해야겠지?", "그냥 얘기하고 싶어", "응", "그만"]

    // 1) 같은 말을 연달아 해도 같은 답을 되풀이하지 않음
    for input in ["심심해", "고마워", "ㅋㅋ", "피곤해", "오늘 공부 하기 싫어", "안녕", "ㅠㅠ", "배고파", "짜증나", "뭐해?"] {
        assistant.reset()
        let replies = await say([input, input, input])
        let repeated = zip(replies, replies.dropFirst()).contains { $0 == $1 }
        check("말투: '\(input)' 연달아 해도 다른 답", !repeated, replies.joined(separator: " | "))
        // 첫마디도 바로 전 답과 다르게
        let openers = replies.map(DoitTone.opener)
        check("말투: '\(input)' 첫마디 되풀이 없음", !zip(openers, openers.dropFirst()).contains { $0 == $1 && !$0.isEmpty }, openers.joined(separator: " | "))
    }

    // 2) 일상 대화 답: 짧게 (목록·굵은 제목 없이), 해요체, "당신"·딱딱한 말 없음
    for input in casual {
        assistant.reset()
        let reply = await say([input]).last ?? ""
        let sentenceCount = DoitMind.sentences(reply.replacingOccurrences(of: "\n", with: " ")).filter { $0.trimmingCharacters(in: .whitespaces).count >= 2 }.count
        check("말투: '\(input)' 짧게 (\(reply.count)자)", reply.count <= 140 && sentenceCount <= 3, reply)
        check("말투: '\(input)' 목록·제목 없음", !reply.contains("•") && !reply.contains("**") && !reply.contains("\n1."), reply)
        check("말투: '\(input)' 해요체", !["습니다", "입니다", "당신", "무엇을 도와드릴까요"].contains(where: { reply.contains($0) }), reply)
    }

    // 3) 앞 이야기를 이어 받음
    assistant.reset()
    var replies = await say(["농담 해줘", "ㅋㅋ"])
    check("말투: 농담 뒤 'ㅋㅋ'는 농담 이야기", ["웃겼", "개그", "좋아해요"].contains { replies[1].contains($0) }, replies.joined(separator: " | "))
    assistant.reset()
    replies = await say(["광합성이 뭐야", "고마워"])
    check("말투: 설명 뒤 '고마워'는 설명 이야기", ["이해", "헷갈리면", "퀴즈"].contains { replies[1].contains($0) }, replies.joined(separator: " | "))
    assistant.reset()
    replies = await say(["안녕", "안녕"])
    check("말투: 두 번째 인사는 다르게", replies[0] != replies[1] && ["또", "다시"].contains { replies[1].contains($0) }, replies.joined(separator: " | "))
    assistant.reset()
    replies = await say(["너무 힘들어", "진짜 너무 힘들어"])
    check("말투: 힘들다는 말이 이어지면 도움받을 곳", replies[1].contains("1388"), replies.joined(separator: " | "))
    check("말투: 처음 '힘들어'에는 상담 번호를 바로 붙이지 않음", !replies[0].contains("1388"), replies[0])

    // 4) 제안한 일에 "응" → 그대로 해 줌 / 제안이 없으면 그냥 대답
    assistant.reset()
    replies = await say(["집중이 안 돼", "응"])
    check("말투: 타이머 제안에 '응' → 타이머 시작", replies[1].contains("[TIMER start"), replies.joined(separator: " | "))
    for _ in 0..<3 {
        assistant.reset()
        replies = await say(["심심해", "응"])
        check("말투: 심심할 때 제안에 '응' → 그대로 (퀴즈·신기한 사실)", (replies[1].contains("퀴즈") || DoitChat.facts.contains(replies[1])) && !replies[1].contains("사실과 의견"),
              replies.joined(separator: " | "))
    }
    assistant.reset()
    replies = await say(["응"])
    check("말투: 제안 없이 '응'은 그냥 대답", !replies[0].contains("[TIMER") && !replies[0].contains("퀴즈 1번"), replies[0])
    assistant.reset()
    replies = await say(["집중이 안 돼", "광합성이 뭐야", "응"])
    check("말투: 다른 말을 한 뒤의 '응'은 앞 제안이 아님", !replies[2].contains("[TIMER"), replies.joined(separator: " | "))
    // 공부 질문·명령은 그대로
    assistant.reset()
    replies = await say(["심심해", "2x+3=11"])
    check("말투: 잡담 뒤 수학 풀이 그대로", replies[1].contains("x = 4"), replies[1])
    assistant.reset()
    replies = await say(["피곤해", "수학 50분 타이머 시작"])
    check("말투: 잡담 뒤 명령 그대로", replies[1].contains("[TIMER start 수학 50]"), replies[1])
    assistant.reset()

    // 5) 고르기: 모두 다 쓰기 전에는 되풀이하지 않음
    DoitTone.reset()
    let options = ["가 말", "나 말", "다 말", "라 말"]
    let picks = (0..<4).map { _ in DoitTone.pick(options) }
    check("말투: 고르기 앞 절반은 겹치지 않음", Set(picks.prefix(2)).count == 2 && Set(picks.suffix(2)).count == 2 && zip(picks, picks.dropFirst()).allSatisfy { $0 != $1 }, "\(picks)")
    check("말투: 받아들이는 말", DoitTone.isYes("응") && DoitTone.isYes("ㅇㅇ") && DoitTone.isYes("좋아!") && DoitTone.isYes("ㄱㄱ") && !DoitTone.isYes("아니") && !DoitTone.isYes("응 근데 광합성이 뭐야"))
    DoitTone.reset()

    // 6) 모델 답 다듬기
    func casualAnswer(_ raw: String, _ q: String, previous: String? = nil) -> String {
        DoitMind.chatAnswer(raw, question: q, previous: previous, style: .casual)
    }
    let cases: [(String, String, String, String?, String)] = [
        ("생각 태그·뜬금없는 인사", "<think>\n\n</think>\n\n안녕하세요! 피곤하면 10분만 쉬어요.", "피곤해", nil, "피곤하면 10분만 쉬어요."),
        ("혼자 이어 쓴 대화", "푹 쉬어요 😊\n학생: 고마워\n모티: 천만에요!", "졸려", nil, "푹 쉬어요 😊"),
        ("프롬프트 칸 이름", "[질문]\n심심해\n퀴즈 한 판 어때요?", "심심해", nil, "퀴즈 한 판 어때요?"),
        ("AI라서", "저는 AI라서 직접 먹을 수는 없지만, 김치찌개 어때요?", "배고파", nil, "김치찌개 어때요?"),
        ("같은 첫마디", "좋아요! 그럼 영어로 해 봐요.", "그래", "좋아요! 수학 퀴즈를 내 볼게요.", "그럼 영어로 해 봐요."),
        ("영어 문장", "심심하구나! Let's play a fun quiz game together. 퀴즈 한 판 할래요?", "심심해", nil, "심심하구나! 퀴즈 한 판 할래요?"),
        ("목록 빼고 짧게", "피곤할 땐 쉬어요.\n• 물 마시기\n• 스트레칭\n• 낮잠", "피곤해", nil, "피곤할 땐 쉬어요."),
        ("잘린 마지막 문장", "괜찮아요! 오늘은 쉬어도 돼요. 그리고 내일은 수학을", "공부 하기 싫어", nil, "괜찮아요! 오늘은 쉬어도 돼요."),
        ("세 문장까지", "그렇군요. 힘들었겠어요. 잠깐 쉬어요. 물도 마셔요. 그리고 스트레칭해요.", "힘들어", nil, "그렇군요. 힘들었겠어요. 잠깐 쉬어요."),
    ]
    for (name, raw, q, previous, expected) in cases {
        let got = casualAnswer(raw, q, previous: previous)
        check("모델 답 다듬기: \(name)", got == expected, got)
    }
    check("모델 답 다듬기: 해요체로", DoitMind.politeEnding("광합성은 양분을 만드는 과정입니다. 엽록체에서 일어납니다. 사과입니다!") == "광합성은 양분을 만드는 과정이에요. 엽록체에서 일어나요. 사과예요!",
          DoitMind.politeEnding("광합성은 양분을 만드는 과정입니다. 엽록체에서 일어납니다. 사과입니다!"))
    check("모델 답 다듬기: 예문 속 '입니다'는 그대로", DoitMind.politeEnding("'I am a student'는 '나는 학생입니다'라는 뜻이에요.") == "'I am a student'는 '나는 학생입니다'라는 뜻이에요.")
    let mixed = "광합성은 빛으로 양분을 만들어요. 这是非常重要的过程。 엽록체에서 일어나요."
    check("모델 답 다듬기: 한자 문장 빼기", DoitMind.chatAnswer(mixed, question: "광합성이 뭐야?") == "광합성은 빛으로 양분을 만들어요. 엽록체에서 일어나요.", DoitMind.chatAnswer(mixed, question: "광합성이 뭐야?"))
    check("모델 답 다듬기: 공부 답 목록은 그대로", DoitMind.chatAnswer("• 빛 흡수\n• 물 분해", question: "광합성 단계 알려줘") == "• 빛 흡수\n• 물 분해")
    check("모델 답 다듬기: 공부 답의 영어 예문은 그대로", DoitMind.chatAnswer("예문: I have lived here for three years.", question: "현재완료 예문") == "예문: I have lived here for three years.")
    check("모델 답 다듬기: 인사에는 인사 그대로", casualAnswer("안녕하세요! 오늘도 반가워요.", "안녕") == "안녕하세요! 오늘도 반가워요.")
    check("쓸 만한 답: 한국어 질문에 영어로만 답하면 버림", !DoitMind.isUsable("I'm sorry to hear that you are tired. Take a rest.", question: "피곤해"))
    check("쓸 만한 답: 영어로 해 달라면 영어 답 통과", DoitMind.isUsable("Hi! I'm MOTI, your study buddy.", question: "영어로 자기소개 해줘"))
    check("쓸 만한 답: 프롬프트 칸이 남으면 버림", !DoitMind.isUsable("[질문]\n피곤해", question: "피곤해"))

    // 7) 말투 고르기 · 프롬프트
    for q in ["ㅋㅋ", "피곤해", "오늘 공부 하기 싫어", "고마워", "안녕", "심심해", "응", "뭐해?"] {
        check("말투 고르기: '\(q)' 일상 대화", DoitMind.style(for: q, chat: true) == .casual)
    }
    for q in ["광합성이 뭐야?", "12와 18의 최소공배수는 어떻게 구해?", "임진왜란은 왜 일어났어?", "현재완료 설명해줘"] {
        check("말투 고르기: '\(q)' 공부 질문", DoitMind.style(for: q, chat: false) == .study)
    }
    check("말투 고르기: 공부법 상담", DoitMind.style(for: "영어 단어 잘 외우는 법 알려줘", chat: true) == .advice)
    check("말투: 짧은 말에는 짧게", DoitMind.maxTokens(for: .casual) < DoitMind.maxTokens(for: .advice) && DoitMind.maxTokens(for: .advice) < DoitMind.maxTokens(for: .study))
    let casualPrompt = DoitMind.answerPrompt(question: "피곤해", context: DoitMind.Context(app: "오늘 공부 30분"), history: [], style: .casual)
    check("프롬프트: 일상 대화는 1~2문장·공감", casualPrompt.contains("1~2문장") && casualPrompt.contains("공감") && casualPrompt.contains("[질문]\n피곤해"), casualPrompt)
    let studyPrompt = DoitMind.answerPrompt(question: "광합성이 뭐야?", context: DoitMind.Context(), history: [])
    check("프롬프트: 공부 질문은 그대로", studyPrompt.hasSuffix("짧고 간단하게 답해 주세요. 요약이나 결론은 붙이지 마세요."), studyPrompt)
    check("말투 지침: 해요체·되풀이 없음", DoitMind.persona.contains("~습니다") && DoitMind.persona.contains("되풀이하지 않아요"))
}
