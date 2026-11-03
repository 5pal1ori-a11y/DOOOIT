import Foundation

// 대화 흐름 테스트
// - 이어 말하기 알아보기·풀기 (그럼 3이면? / 왜? / 다시 설명해줘 / 더 쉽게 / 그거 단계별로 / 다른 예시 / 그 다음은? / 그거·이거 / x=3일 때는?)
// - 앞 내용 다시 쓰기, 앞 내용이 없을 때 되묻기, 다른 주제로 샌 답 막기
// - 모델에게 줄 이전 대화 (토큰 예산 · 역할 번갈아)
// - 교육과정에 없는 주제의 AI 학습: 모델 답(미리 적어 둔 글) 읽기 · 검사

private struct ContextCase {
    let name: String
    let inputs: [String]
    var expect: [String] = []
    var reject: [String] = []
}

private let contextCases: [ContextCase] = [
    // 수학: 앞 함수·식·문제를 이어서
    ContextCase(name: "함수 뒤 '그럼 3이면?'", inputs: ["f(x)=x^2+3x", "그럼 3이면?"], expect: ["f(3) = 18"]),
    ContextCase(name: "y=… 뒤 'x=3일 때는?'", inputs: ["y=2x+1", "x=3일 때는?"], expect: ["f(3) = 7"], reject: ["[ADD PLAN]"]),
    ContextCase(name: "함숫값 뒤 다른 값", inputs: ["f(x)=x^2+3x에 x=3을 넣어줘", "x=5이면?"], expect: ["f(5) = 40"]),
    ContextCase(name: "방정식에 값 넣어 보기 (해)", inputs: ["2x+3=11", "x=4이면?"], expect: ["해예요"]),
    ContextCase(name: "방정식에 값 넣어 보기 (해 아님)", inputs: ["2x+3=11", "x가 3이면?"], expect: ["해가 아니에요"]),
    ContextCase(name: "방정식 뒤 '그럼 3이면?'은 되물음", inputs: ["2x+3=11", "그럼 3이면?"], expect: ["x = 3일 때"]),
    ContextCase(name: "그거 단계별로", inputs: ["x^2-5x+6=0 풀어줘", "그거 단계별로"], expect: ["인수분해", "x = 2 또는 x = 3"]),
    ContextCase(name: "수학 뒤 '왜?'", inputs: ["x^2-5x+6=0 풀어줘", "왜?"], expect: ["x = 2 또는 x = 3"], reject: ["이야기였죠"]),
    ContextCase(name: "수학 뒤 '더 쉽게'", inputs: ["x^2-5x+6=0 풀어줘", "더 쉽게"], expect: ["x = 2 또는 x = 3"]),
    ContextCase(name: "수학 뒤 '다른 예시'는 비슷한 문제", inputs: ["x^2-5x+6=0 풀어줘", "다른 예시"], expect: ["비슷한 문제 3개"]),
    ContextCase(name: "그 문제 다시 풀어줘", inputs: ["x^2-5x+6=0 풀어줘", "고마워", "그 문제 다시 풀어줘"], expect: ["x = 2 또는 x = 3"]),
    // 계산: 앞 질문의 값만 바꾸기
    ContextCase(name: "저항이 6이면?", inputs: ["전압 12V 저항 4Ω 전류는?", "저항이 6이면?"], expect: ["2 A"]),
    ContextCase(name: "30%면?", inputs: ["10000원에서 20% 할인", "30%면?"], expect: ["7000원"]),
    ContextCase(name: "200일이면?", inputs: ["100일 뒤", "그럼 200일이면?"], expect: ["200일 뒤는"]),
    ContextCase(name: "타이머 30분이면?", inputs: ["수학 50분 타이머 시작", "그럼 30분이면?"], expect: ["[TIMER start 수학 30]"]),
    // 개념 설명 이어 가기
    ContextCase(name: "다시 설명해줘", inputs: ["광합성이 뭐야", "다시 설명해줘"], expect: ["광합성", "• "]),
    ContextCase(name: "더 쉽게", inputs: ["광합성이 뭐야", "더 쉽게"], expect: ["광합성", "엽록체"]),
    ContextCase(name: "그 다음은?", inputs: ["광합성이 뭐야", "그 다음은?"], expect: ["다음으로"]),
    ContextCase(name: "다른 예시는 같은 주제로 (국어 '예시' 개념으로 새지 않음)", inputs: ["광합성이 뭐야", "다른 예시"], expect: ["광합성"], reject: ["국어"]),
    ContextCase(name: "예를 들면?", inputs: ["기회비용이 뭐야?", "예를 들면?"], expect: ["기회비용"], reject: ["몰라요"]),
    ContextCase(name: "그거 어디서 일어나?", inputs: ["광합성이 뭐야", "그거 어디서 일어나?"], expect: ["엽록체"]),
    ContextCase(name: "개념 뒤 '왜?'는 짧게 되물음", inputs: ["광합성이 뭐야", "왜?"], expect: ["광합성", "궁금"], reject: ["이야기였죠"]),
    ContextCase(name: "인사 끼어도 주제 유지", inputs: ["광합성이 뭐야", "고마워", "더 쉽게"], expect: ["광합성"]),
    ContextCase(name: "주제가 바뀌면 새 주제로", inputs: ["광합성이 뭐야", "블랙홀이 뭐야?", "더 쉽게"], expect: ["블랙홀"], reject: ["엽록체"]),
    // 대상만 바꾸기 ("그럼 독일은?")
    ContextCase(name: "그럼 독일은?", inputs: ["프랑스 수도", "그럼 독일은?"], expect: ["베를린"]),
    ContextCase(name: "그럼 eat은?", inputs: ["go 과거형", "그럼 eat은?"], expect: ["ate"]),
    ContextCase(name: "그럼 내일은?", inputs: ["오늘 할 일 알려줘", "그럼 내일은?"], expect: ["[OVERVIEW 내일"]),
    ContextCase(name: "그럼 어린이날은?", inputs: ["크리스마스까지 며칠 남았어?", "그럼 어린이날은?"], expect: ["어린이날까지"]),
    // 일정 · 단어
    ContextCase(name: "그거 삭제해줘 (방금 넣은 일정)", inputs: ["내일 오후 4시에 수학 공부 2시간 추가해줘", "그거 삭제해줘"], expect: ["[UPDATE delete 수학 공부]"]),
    // 앞 내용이 없으면 짐작하지 않고 되물음
    ContextCase(name: "앞 내용 없이 '그럼 3이면?'", inputs: ["그럼 3이면?"], expect: ["알려줄래요"], reject: ["몰라요"]),
    ContextCase(name: "앞 내용 없이 '다시 설명해줘'", inputs: ["다시 설명해줘"], expect: ["다시 설명할까요"]),
    ContextCase(name: "앞 내용 없이 '왜?'", inputs: ["왜?"], expect: ["궁금한지"]),
    ContextCase(name: "인사 뒤 '그럼 3이면?'", inputs: ["안녕", "그럼 3이면?"], expect: ["알려줄래요"]),
    ContextCase(name: "앞 내용 없는 '이 문제 풀어줘'는 그대로", inputs: ["이 문제 풀어줘"], expect: ["풀 문제를 보내주세요"]),
    ContextCase(name: "재밌는 사실 '하나 더'는 이어 말하기로 안 바뀜", inputs: ["하나 더 알려줘"], reject: ["알려줄래요", "자세히 알려줄까요"]),
    // 다른 주제로 샌 답 막기
    ContextCase(name: "abundant 예문 → 국제 연합으로 새지 않음", inputs: ["abundant 예문"], expect: ["몰라요"], reject: ["국제 연합"]),
    ContextCase(name: "단어 뒤 '그거 예문'은 그 단어로", inputs: ["abundant 뜻", "그거 예문 알려줘"], expect: ["abundant"], reject: ["국제 연합"]),
    // 퀴즈·명령은 그대로
    ContextCase(name: "수학 뒤 앱 명령은 명령", inputs: ["x^2-5x+6=0 풀어줘", "내일 오후 4시에 영어 공부 1시간 추가해줘"], expect: ["[ADD PLAN] 영어 공부"]),
    ContextCase(name: "퀴즈 그만은 그대로", inputs: ["수학 퀴즈 내줘", "그만"], expect: ["퀴즈를 마칠게요"])
]

@MainActor
func runChatContextCases() async {
    // 1) 대화로 확인
    for test in contextCases {
        let assistant = DoitAssistant.shared
        assistant.reset()
        for input in test.inputs { await assistant.send(input) }
        let reply = assistant.messages.last?.text ?? ""
        let ok = test.expect.allSatisfy { reply.contains($0) } && !test.reject.contains { reply.contains($0) }
        check("대화 흐름: \(test.name)", ok, "입력 \(test.inputs) → \(reply.prefix(240).replacingOccurrences(of: "\n", with: " / "))")
    }
    DoitAssistant.shared.reset()

    // 2) 이어 말하기 알아보기
    typealias F = DoitDialogue.FollowUp
    let follows: [(String, F?)] = [
        ("그럼 3이면?", .substitute(value: "3", name: nil, unit: nil)),
        ("저항이 6이면?", .substitute(value: "6", name: "저항", unit: nil)),
        ("30%면?", .substitute(value: "30", name: nil, unit: "%")),
        ("x=3일 때는?", .variable(name: "x", value: "3")),
        ("x가 2면?", .variable(name: "x", value: "2")),
        ("왜?", .why), ("그럼 왜?", .why), ("다시 설명해줘", .again), ("더 쉽게", .simpler), ("그거 단계별로", .steps),
        ("다른 예시", .example), ("그 다음은?", .next), ("더 자세히", .more), ("그럼 독일은?", .ellipsis("독일")), ("독일은?", .ellipsis("독일")),
        ("그거 뜻이 뭐야?", .pronoun),
        // 이어 말하기가 아닌 말
        ("광합성이 뭐야", nil), ("x^2-5x+6=0 풀어줘", nil), ("비가 오는 이유", nil), ("안녕", nil), ("How are you?", nil), ("너 누구야?", nil),
        ("왜 하늘은 파란색이야?", nil), ("그만", nil), ("예시가 뭐야?", nil), ("이걸로 퀴즈 내줘", nil),
        ("근데 배고파", nil), ("그럼 그렇게 할게", nil), ("그럼 됐어", nil), ("너는?", nil)
    ]
    for (input, expected) in follows {
        let got = DoitDialogue.classify(input)
        check("이어 말하기 알아보기: \(input)", got == expected, "\(String(describing: got)) (기대 \(String(describing: expected)))")
    }
    check("하나 더 알려줘는 '더 자세히' 아님", DoitDialogue.classify("하나 더 알려줘") != .more)

    // 3) 앞 내용 없이 풀기 → 되묻기 / 원래 답에 맡기기
    let empty = DoitDialogue.State()
    if case .clarify = DoitDialogue.resolve("그럼 3이면?", state: empty) { check("앞 내용 없음: 그럼 3이면? 되물음", true) } else { check("앞 내용 없음: 그럼 3이면? 되물음", false) }
    if case .clarify = DoitDialogue.resolve("왜?", state: empty) { check("앞 내용 없음: 왜? 되물음", true) } else { check("앞 내용 없음: 왜? 되물음", false) }
    check("앞 내용 없음: 이 문제 풀어줘는 엔진에", DoitDialogue.resolve("이 문제 풀어줘", state: empty) == .none)
    check("이어 말하기 아님은 그대로", DoitDialogue.resolve("광합성이 뭐야", state: empty) == .none)

    // 4) 상태 기록 → 앞 내용으로 다시 쓰기
    var state = DoitDialogue.State()
    DoitDialogue.update(&state, question: "f(x)=x^2+3x", reply: "**답: …**", kind: .math)
    check("상태: 함수 기억", state.function == "f(x)=x^2+3x" && state.focus == .math, "\(state)")
    if case .rewrite(let q) = DoitDialogue.resolve("그럼 3이면?", state: state) {
        check("함수에 값 넣기로 다시 씀", q.contains("f(x)=x^2+3x") && q.contains("x=3"), q)
    } else { check("함수에 값 넣기로 다시 씀", false) }
    DoitDialogue.update(&state, question: "고마워", reply: "천만에요", kind: .chat)
    check("인사는 주제를 지우지 않음", state.focus == .math && state.function != nil && state.last == .chat)
    DoitDialogue.update(&state, question: "광합성이 뭐야", reply: "**광합성** (과학)\n식물이 빛으로 양분을 만들어요.", kind: .knowledge)
    check("상태: 새 주제", state.topic == "광합성" && state.subject == "과학" && state.focus == .knowledge, "\(state)")
    if case .rewrite(let q) = DoitDialogue.resolve("그거 어디서 일어나?", state: state) {
        check("그거 → 주제로", q.contains("광합성") && !q.contains("그거"), q)
    } else { check("그거 → 주제로", false) }
    DoitDialogue.update(&state, question: "y=2x+1", reply: "흥미로운 이야기네요", kind: .chat)
    check("함수만 적은 말도 기억", state.function == "f(x)=2x+1" && state.focus == .math, "\(state)")

    check("함수 읽기 (뒤 조건은 뺌)", DoitDialogue.function(in: "f(x)=x^2+3x x=1에서 접선") == "f(x)=x^2+3x", DoitDialogue.function(in: "f(x)=x^2+3x x=1에서 접선") ?? "nil")
    check("방정식에 값 넣기", DoitDialogue.checkSubstitution("2x+3=11", name: "x", value: "4")?.contains("해예요") == true)
    check("이름 붙은 값만 바꾸기", DoitDialogue.replaceNumbers(in: "전압 12V 저항 4Ω 전류는?", value: "6", name: "저항", unit: nil) == ["전압 12V 저항 6Ω 전류는?"],
          "\(DoitDialogue.replaceNumbers(in: "전압 12V 저항 4Ω 전류는?", value: "6", name: "저항", unit: nil))")
    check("단위가 같은 값만 바꾸기", DoitDialogue.replaceNumbers(in: "10000원에서 20% 할인", value: "30", name: nil, unit: "%") == ["10000원에서 30% 할인"])
    check("값이 여럿이면 후보 여러 개", DoitDialogue.replaceNumbers(in: "10000원에서 20% 할인", value: "5", name: nil, unit: nil).count == 2)

    // 5) 다른 주제로 샌 답 막기
    check("핵심 낱말", DoitDialogue.keywords("광합성이 뭐야?") == ["광합성"], "\(DoitDialogue.keywords("광합성이 뭐야?"))")
    check("샌 답: abundant → 국제 연합", DoitDialogue.isOffTopic(question: "abundant 예문", reply: "**국제 연합** (사회)\n1945년 국제 평화와 안전 유지를 위해 만들어진 국제기구예요."))
    check("샌 답: 광합성 예시 → 국어 예시", DoitDialogue.isOffTopic(question: "광합성 다른 예시", reply: "**예시** (중학교 국어)\n예시는 구체적인 예를 들어 설명하는 방법이에요."))
    check("맞는 답은 통과", !DoitDialogue.isOffTopic(question: "광합성이 뭐야", reply: "**광합성** (과학)\n식물이 빛에너지로 포도당을 만들어요."))
    check("설명으로 물어도 통과", !DoitDialogue.isOffTopic(question: "물건값이 계속 오르는 현상이 뭐야", reply: "**인플레이션**\n물가가 계속 오르는 현상이에요."))
    check("낱말 없는 말은 보지 않음", !DoitDialogue.isOffTopic(question: "왜?", reply: "아무 말"))

    // 6) 모델 길: 이어 가는 말 / 앱 명령
    check("모델 대화 이어 가기: 그럼 그건 왜?", DoitDialogue.continuesConversation("그럼 그건 왜?"))
    check("모델 대화 이어 가기: 그거 예시는?", DoitDialogue.continuesConversation("그거 예시는?"))
    check("새 질문은 이어 가기 아님", !DoitDialogue.continuesConversation("블랙홀은 어떻게 생겨?"))
    check("앱 명령은 엔진이", DoitDialogue.isCommand("내일 4시 수학 공부 추가해줘") && DoitDialogue.isCommand("2x+3=11 풀어줘") && !DoitDialogue.isCommand("그럼 왜?"))

    // 7) 모델에게 줄 이전 대화 (토큰 예산, 최근 것부터, 학생 말로 시작, 번갈아)
    check("토큰 어림 (한글)", DoitMind.estimateTokens("가나다") == 3 && DoitMind.estimateTokens("abcdefg") == 2)
    var turns: [DoitMind.Turn] = []
    for i in 1...8 {
        turns.append(DoitMind.Turn(fromUser: true, text: "질문 \(i): " + String(repeating: "광합성 ", count: 20)))
        turns.append(DoitMind.Turn(fromUser: false, text: "답 \(i): " + String(repeating: "엽록체에서 일어나요. ", count: 10)))
    }
    turns.append(DoitMind.Turn(fromUser: true, text: "마지막 질문"))
    turns.append(DoitMind.Turn(fromUser: true, text: "이어서"))
    let budget = DoitMind.budgetHistory(turns, maxTokens: 300)
    let cost = budget.recent.reduce(0) { $0 + DoitMind.estimateTokens($1.text) + 4 }
    let alternates = zip(budget.recent, budget.recent.dropFirst()).allSatisfy { $0.fromUser != $1.fromUser }
    check("이전 대화: 예산 안", cost <= 300 && !budget.recent.isEmpty, "\(cost)")
    check("이전 대화: 학생 말로 시작·번갈아", budget.recent.first?.fromUser == true && alternates)
    check("이전 대화: 가장 최근 말 포함 (같은 역할은 합침)", budget.recent.last?.text.contains("마지막 질문") == true && budget.recent.last?.text.contains("이어서") == true)
    check("이전 대화: 오래된 말은 요약", budget.summary?.contains("질문 1") == true || budget.summary?.contains("질문") == true, budget.summary ?? "nil")
    let short = DoitMind.budgetHistory([DoitMind.Turn(fromUser: false, text: "안녕하세요"), DoitMind.Turn(fromUser: true, text: "광합성이 뭐야?"),
                                        DoitMind.Turn(fromUser: false, text: "**광합성**은 빛으로 양분을 만드는 거예요.")], maxTokens: 500)
    check("이전 대화: 모티 말로 시작하면 뺌, 굵은 글씨 정리", short.recent.count == 2 && short.recent[0].fromUser && !short.recent[1].text.contains("**"))
    let prompt = DoitMind.answerPrompt(question: "왜?", context: DoitMind.Context(), history: [], summary: "학생이 앞에서 물은 것: 광합성", topic: "광합성")
    check("프롬프트: 앞선 대화 요약·주제", prompt.contains("[앞선 대화]") && prompt.contains("[지금 이야기 중인 주제] 광합성") && prompt.contains("[질문]\n왜?") && !prompt.contains("[이전 대화]"), prompt)

    // 8) 교육과정에 없는 주제: 모델 답 읽기 · 검사
    check("주제 정리", DoitStudy.normalizedTopic("  블록체인   원리?! ") == "블록체인 원리" && DoitStudy.freeKey("블록 체인") == DoitStudy.freeKey(" 블록체인 "))
    let conceptRaw = """
    <think>
    </think>
    핵심 개념: 블록체인은 거래 기록을 여러 컴퓨터가 함께 나눠 저장하는 기술이에요.
    학습 포인트:
    - 블록에는 거래 기록이 담겨요.
    - 블록은 앞 블록과 사슬처럼 이어져요.
    - 블록에는 거래 기록이 담겨요.
    - 기록을 바꾸기 어려워서 믿을 수 있어요.
    예제: 비트코인은 블록체인으로 거래를 기록해요.
    """
    let concept = DoitStudy.parseFreeConcept(conceptRaw, topic: "블록체인")
    check("AI 학습 개념: 줄 형식 읽기 (같은 포인트는 한 번)", concept?.keyPoints.count == 3 && concept?.summary.hasPrefix("블록체인은") == true && concept?.example.contains("비트코인") == true,
          "\(String(describing: concept))")
    let conceptJSON = #"```json {"summary": "블록체인은 기록을 나눠 저장하는 기술이에요.", "points": ["블록이 사슬처럼 이어져요.", "기록을 바꾸기 어려워요."], "example": "비트코인"} ```"#
    check("AI 학습 개념: JSON 읽기", DoitStudy.parseFreeConcept(conceptJSON, topic: "블록체인")?.keyPoints.count == 2)
    check("AI 학습 개념: 한자 섞인 답 버림", DoitStudy.parseFreeConcept("核心概念: 区块链是一种技术。\n学习要点:\n- 区块\n- 链", topic: "블록체인") == nil)
    check("AI 학습 개념: 다른 주제 답 버림", DoitStudy.parseFreeConcept("핵심 개념: 광합성은 식물이 양분을 만드는 과정이에요.\n학습 포인트:\n- 엽록체에서 일어나요.\n- 빛이 필요해요.", topic: "블록체인") == nil)

    let clozeRaw = """
    1. 블록체인은 거래 기록을 여러 (   )가 나눠 저장해요. | 컴퓨터
    2. 블록은 앞 블록과 (   )처럼 이어져요. | 사슬
    3. 블록은 앞 블록과 (   )처럼 이어져요. | 사슬
    4. 정답이 보이는 문장 블록체인 (   ) 블록체인 | 블록체인
    5. The (   ) is a ledger. | block
    """
    let cloze = DoitStudy.parseFreeCloze(clozeRaw)
    check("AI 학습 빈칸: 중복·정답 노출·영어 문장 버림", cloze.map(\.answer) == ["컴퓨터", "사슬"], "\(cloze)")
    check("AI 학습 빈칸: JSON", DoitStudy.parseFreeCloze(#"[{"sentence": "블록은 해시로 (   )돼요.", "answer": "연결"}, {"문장": "기록을 바꾸기 (   ).", "정답": "어려워요"}]"#).count == 2)

    let oxRaw = """
    O | 블록체인은 기록을 여러 곳에 나눠 저장해요. | 맞아요.
    X | 블록체인은 한 컴퓨터에만 기록을 저장해요. | 여러 컴퓨터에 저장해요.
    O | 블록체인은 기록을 여러 곳에 나눠 저장해요. | 중복
    O | Blockchain stores records in many places. | english
    """
    let ox = DoitStudy.parseFreeOX(oxRaw)
    check("AI 학습 O/X: 중복·영어 버림, O와 X", ox.count == 2 && ox.contains { $0.isTrue } && ox.contains { !$0.isTrue }, "\(ox)")

    let problemRaw = """
    문제: 블록체인에서 블록을 서로 잇는 데 쓰는 값은?
    1) 해시
    2) 비밀번호
    3) 주소
    4) 이름
    5) 날짜
    정답: 1
    해설: 앞 블록의 해시로 이어져요.
    문제: 블록체인 기록의 특징은?
    ① 쉽게 바뀐다
    ② 바꾸기 어렵다
    ③ 한 곳에만 있다
    ④ 지워진다
    정답: ②
    해설: 여러 곳에 있어 바꾸기 어려워요.
    문제: 비트코인이 쓰는 기술은?
    1) 블록체인
    2) 인공지능
    3) 가상현실
    4) 로봇
    5) 드론
    정답: 블록체인
    문제: 보기에 없는 정답
    1) 가
    2) 나
    3) 다
    4) 라
    5) 마
    정답: 바
    문제: 보기가 겹치는 문제예요
    1) 해시
    2) 해시
    3) 주소
    4) 이름
    5) 날짜
    정답: 1
    문제: 해설과 정답이 다른 문제예요
    1) 가나
    2) 다라
    3) 마바
    4) 사아
    5) 자차
    정답: 2
    해설: 정답은 4번이에요.
    """
    let problems = DoitStudy.parseFreeProblems(problemRaw)
    check("AI 학습 객관식: 번호·원문자·보기 글 정답, 보기 4개도", problems.map(\.answerNumber) == [1, 2, 1] && problems[1].choices.count == 4, "\(problems.map { ($0.question, $0.answerNumber) })")
    check("AI 학습 객관식: 정답은 보기 안에", problems.allSatisfy { $0.choices.indices.contains($0.answerNumber - 1) && $0.finalAnswer.contains($0.choices[$0.answerNumber - 1]) })
    let problemJSON = #"[{"question": "블록체인에서 블록을 잇는 값은?", "choices": ["해시", "주소", "이름", "날짜", "번호"], "answer": 1, "explanation": "해시로 이어요."}]"#
    check("AI 학습 객관식: JSON", DoitStudy.parseFreeProblems(problemJSON).first?.answerNumber == 1)
    check("정답 번호와 보기 글이 다르면 그 글의 번호", DoitStudy.answerNumber("1) 주소", choices: ["해시", "주소", "이름", "날짜"]) == 2)
    check("정답이 보기에 없으면 버림", DoitStudy.answerNumber("6", choices: ["가", "나", "다", "라", "마"]) == nil)

    // 9) 모델이 없으면 만들지 않음 (테스트 환경)
    do {
        _ = try await DoitTutor.concept(subject: DoitStudy.freeSubject, unit: "블록체인", booster: false)
        check("모델 없으면 AI 학습 안 만듦", false)
    } catch {
        check("모델 없으면 AI 학습 안 만듦", (error as? DoitStudy.FreeError).map { if case .needsModel = $0 { return true } else { return false } } ?? false, "\(error)")
    }
}
