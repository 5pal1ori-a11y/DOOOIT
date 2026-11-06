import Foundation

// 모티 AI 생각 틀 · 아이디어 · AI 학습 설명(원리·실수·확인 문제) 테스트

func runThinkCases() async {
    // 1) 관점 고르기: 질문에 어울리는 1~2개
    func names(_ q: String) -> [DoitMind.Angle] { DoitMind.angles(for: q) }
    check("관점: 왜 → 왜 이어 보기 + 원인결과", names("임진왜란은 왜 일어났어?") == [.whyChain, .cause])
    check("관점: 차이 → 큰 그림 + 반대", names("원자랑 분자 차이가 뭐야?") == [.bigPicture, .opposite])
    check("관점: 뭐야 → 예시 + 큰 그림", names("광합성이 뭐야?") == [.analogy, .bigPicture])
    check("관점: 원리/방법 → 원인결과 + 예시", names("엘리베이터는 어떻게 움직여?") == [.cause, .analogy])
    check("관점: 항상 1~2개", ["", "ㅁ", "블랙홀", "12와 18의 최소공배수 구하는 법", "why is the sky blue"].allSatisfy { (1...2).contains(names($0).count) })

    // 2) 생각 틀: 공부 질문에만, 짧게 (작은 모델용: 600자 미만)
    let scaffold = DoitMind.reasoningScaffold(for: "임진왜란은 왜 일어났어?", style: .study) ?? ""
    check("생각 틀: 핵심 → 이유 → 예시 → 확인 순서", scaffold.contains("핵심 한 문장") && scaffold.contains("왜 그런지") && scaffold.contains("쉬운 예시") && scaffold.contains("확인 질문"), scaffold)
    check("생각 틀: 600자 미만", scaffold.count > 0 && scaffold.count < 600, "\(scaffold.count)")
    check("생각 틀: 일상 대화·상담에는 없음", DoitMind.reasoningScaffold(for: "피곤해", style: .casual) == nil && DoitMind.reasoningScaffold(for: "공부 계획 짜줘", style: .advice) == nil)
    check("생각 틀: 모델 이름 없음", !scaffold.contains("Qwen") && !DoitMind.ideasInstruction.contains("Qwen"))

    // 3) 프롬프트에 들어가는 위치
    let study = DoitMind.answerPrompt(question: "임진왜란은 왜 일어났어?", context: DoitMind.Context(), history: [])
    check("프롬프트: 생각 틀이 질문 뒤·마지막 지시 앞", study.contains("[질문]\n임진왜란은 왜 일어났어?") && study.contains("답하기 전에 속으로")
          && study.hasSuffix("짧고 간단하게 답해 주세요. 요약이나 결론은 붙이지 마세요."), study)
    let casual = DoitMind.answerPrompt(question: "피곤해", context: DoitMind.Context(), history: [], style: .casual)
    check("프롬프트: 일상 대화에는 생각 틀 없음", !casual.contains("답하기 전에 속으로") && !casual.contains("아이디어를 달라는"))
    DoitMind.replyLanguage = "en"
    let english = DoitMind.answerPrompt(question: "Why is the sky blue?", context: DoitMind.Context(), history: [])
    check("프롬프트: 다른 언어는 끝에 언어 지시 유지", english.hasSuffix("Always answer in English."), english)
    let englishIdeas = DoitMind.answerPrompt(question: "give me ideas for a science fair", context: DoitMind.Context(), history: [])
    check("프롬프트: 아이디어도 끝에 언어 지시 유지", englishIdeas.hasSuffix("Always answer in English.") && englishIdeas.contains("아이디어를 달라는"), englishIdeas)
    DoitMind.replyLanguage = "ko"
    check("프롬프트: 한국어 성격 줄은 그대로", DoitMind.chatPersona == DoitMind.persona)

    // 4) 새어 나온 지시글은 답에서 지움
    let leaked = "답하기 전에 속으로 원인→결과 관점으로 짧게 생각해요. 생각 과정은 쓰지 않고, 핵심 한 문장 → 왜 그런지\n임진왜란은 일본이 조선을 침략해서 일어났어요."
    check("새어 나온 생각 틀 지시 지우기", DoitMind.answer(leaked) == "임진왜란은 일본이 조선을 침략해서 일어났어요.", DoitMind.answer(leaked))
    let leakedIdeas = "아이디어를 달라는 요청이에요. 서로 겹치지 않게 6~8개를 내요.\n• 조합: 게임과 섞기"
    check("새어 나온 아이디어 지시 지우기", DoitMind.answer(leakedIdeas) == "• 조합: 게임과 섞기", DoitMind.answer(leakedIdeas))

    // 5) 아이디어 요청 알아보기
    for q in ["발표 잘하는 아이디어 좀 줘", "동아리 홍보 브레인스토밍 해줘", "과학 전시회 아이디어 추천해줘", "give me ideas for a project", "공부 재밌게 하는 아이디어 없을까?"] {
        check("아이디어 요청: '\(q)'", DoitMind.wantsIdeas(q))
    }
    for q in ["브레인스토밍이 뭐야?", "아이디어의 뜻", "광합성이 뭐야?", "안녕", "오늘 할 일 알려줘"] {
        check("아이디어 요청 아님: '\(q)'", !DoitMind.wantsIdeas(q))
    }
    let ideasPrompt = DoitMind.answerPrompt(question: "발표 잘하는 아이디어 좀 줘", context: DoitMind.Context(), history: [])
    check("아이디어 프롬프트: 관점 5가지·6~8개·한 줄씩", ideasPrompt.contains("6~8개") && ideasPrompt.contains("조합") && ideasPrompt.contains("다른 분야") && ideasPrompt.contains("제약") && ideasPrompt.contains("반대로") && ideasPrompt.contains("작게 쪼개기"), ideasPrompt)
    check("아이디어 프롬프트: 600자 미만 지시", DoitMind.ideasInstruction.count < 600, "\(DoitMind.ideasInstruction.count)")
    check("아이디어는 답 길이를 늘림", DoitMind.maxTokens(for: .study, question: "발표 아이디어 좀 줘") > DoitMind.maxTokens(for: .study, question: "광합성이 뭐야?")
          && DoitMind.maxTokens(for: .casual, question: "ㅋㅋ") == DoitMind.maxTokens(for: .casual))

    // 6) 아이디어 엔진: 주제를 뽑아 관점별 질문으로 (사실을 말하지 않음)
    check("주제 뽑기: 군말 빼기", DoitIdeas.topic(from: "발표 잘하는 아이디어 좀 줘") == "발표 잘하는", DoitIdeas.topic(from: "발표 잘하는 아이디어 좀 줘") ?? "nil")
    check("주제 뽑기: 에 대한", DoitIdeas.topic(from: "동아리 홍보에 대한 아이디어 알려줘") == "동아리 홍보", DoitIdeas.topic(from: "동아리 홍보에 대한 아이디어 알려줘") ?? "nil")
    check("주제 뽑기: '더위'·'좀비' 같은 낱말은 안 깨짐", DoitIdeas.topic(from: "더위 피하는 아이디어 줘") == "더위 피하는" && DoitIdeas.topic(from: "좀비 게임 아이디어 줘") == "좀비 게임")
    check("주제 뽑기: 주제가 없으면 nil", DoitIdeas.topic(from: "아이디어 줘") == nil && DoitIdeas.topic(from: "좋은 아이디어 좀 줘!") == nil)
    let ideas = await DoitEngine.respond(to: "발표 잘하는 아이디어 좀 줘", photo: nil)
    let bullets = ideas.text.components(separatedBy: "\n").filter { $0.hasPrefix("• ") }
    check("아이디어 답: 서로 다른 관점 6개", bullets.count == 6 && ["조합", "다른 분야", "제약", "반대로", "작게 쪼개기", "다른 사람"].allSatisfy { key in bullets.contains { $0.contains(key) } }, ideas.text)
    check("아이디어 답: 주제 포함·모델이 이어 쓰는 경로", ideas.text.contains("‘발표 잘하는’") && ideas.origin == .conversation, ideas.text)
    check("아이디어 답: 다음 제안", ideas.suggestions.first?.contains("아이디어") == true, "\(ideas.suggestions)")
    let bare = await DoitEngine.respond(to: "아이디어 줘", photo: nil)
    check("아이디어 답: 주제 없으면 기존 추천", bare.text.contains("추천") && !bare.text.contains("여섯 방향"), bare.text)
    let meaning = await DoitEngine.respond(to: "브레인스토밍이 뭐야?", photo: nil)
    check("아이디어 답: 뜻을 묻는 말은 아이디어 목록이 아님", !meaning.text.contains("여섯 방향"), meaning.text)
    let math = await DoitEngine.respond(to: "2x + 3 = 11", photo: nil)
    check("아이디어 훅이 수학 풀이를 건드리지 않음", math.origin != .conversation && !math.text.contains("여섯 방향"), math.text)

    // 7) AI 학습: 개념 → 원리 → 예시 → 실수 → 확인 문제
    let scope = StudyScope(level: .middle, subject: "과학", subjectName: "중학교 과학", unit: "광합성", sources: [])
    let model = DoitStudy.parseConcept("""
    핵심 개념: 광합성은 식물이 빛 에너지로 양분을 만드는 과정이에요.
    상세 설명:
    - 엽록체에서 일어나요.
    학습 포인트:
    - 식물이 빛 에너지로 양분을 만드는 과정이에요.
    - 이산화 탄소와 물이 필요해요.
    왜 그런지:
    - 엽록체에 빛을 받는 엽록소가 있어서 빛 에너지를 쓸 수 있어요.
    예제: 햇빛을 받은 잎에서 녹말이 만들어져요.
    자주 하는 실수:
    - 광합성과 호흡을 서로 바꿔 생각하기 쉬워요.
    """, scope: scope)
    check("개념 정리 읽기: 원리·실수 칸", model?.principles.count == 1 && model?.mistakes.count == 1 && model?.keyPoints.count == 2 && model?.example.contains("녹말") == true, "\(String(describing: model))")
    let prompt = DoitStudy.conceptPrompt(scope: scope, basis: DoitStudyCheck.Basis(materials: DoitStudy.materials(for: (try? DoitStudy.scope(subject: "중학교 과학", unit: "물질의 구성")) ?? scope), scope: scope), booster: false)
    check("개념 프롬프트: 왜 그런지·자주 하는 실수·생각 틀", prompt.contains("왜 그런지:") && prompt.contains("자주 하는 실수:") && prompt.contains("속으로"), prompt)

    var rich = 0, checked = 0, total = 0
    var detail: [String] = []
    let units: [(String, String)] = [("중학교 과학", "물질의 구성"), ("중학교 과학", "광합성"), ("중학교 사회", "삼국의 성립과 발전"), ("중학교 수학", "이차방정식"),
                                    ("초등학교 과학", "식물의 한살이"), ("고등학교 사회", "시장과 경제")]
    for (subject, unit) in units {
        guard let pack = try? await DoitStudy.makePack(subject: subject, unit: unit, booster: false) else { continue }
        total += 1
        let note = pack.concept
        // 새로 채운 원리·실수·확인 문제도 자료 근거 검사를 통과해야 함
        let issues = DoitStudyCheck.check(note, basis: pack.basis)
        check("AI 학습 \(subject) \(unit): 원리·실수가 검증 통과", issues.isEmpty, "\(issues)")
        if !note.principles.isEmpty || !note.mistakes.isEmpty { rich += 1 }
        if !note.checkQuestion.isEmpty && !note.checkAnswer.isEmpty { checked += 1 }
        detail.append("\(unit): 원리 \(note.principles.count) 실수 \(note.mistakes.count) 확인 \(note.checkQuestion.isEmpty ? "없음" : "있음")")
        // 확인 문제의 정답은 O/X 표시로 시작
        if !note.checkAnswer.isEmpty { check("AI 학습 \(unit): 확인 문제 정답 표시", note.checkAnswer.hasPrefix("O") || note.checkAnswer.hasPrefix("X"), note.checkAnswer) }
    }
    check("AI 학습: 확인 문제가 대부분 단원에 붙음", total >= 4 && checked * 3 >= total * 2, detail.joined(separator: " / "))
    check("AI 학습: 원리·실수가 일부 단원에 붙음", rich >= 1, detail.joined(separator: " / "))
    print("  [AI 학습 설명 보강] \(detail.joined(separator: " | "))")

    // 8) 예전에 저장한 개념 정리·새 형식 저장/읽기
    let old = #"{"title":"광합성","keyPoints":["빛으로 양분을 만들어요"],"example":"잎"}"#
    let decodedOld = try? JSONDecoder().decode(ConceptNote.self, from: Data(old.utf8))
    check("예전 개념 정리: 새 칸은 빈 값", decodedOld?.principles == [] && decodedOld?.mistakes == [] && decodedOld?.checkQuestion == "")
    var note = ConceptNote(title: "광합성", keyPoints: ["양분을 만들어요"], example: "잎")
    note.principles = ["엽록소가 빛을 받아요"]; note.mistakes = ["호흡과 헷갈려요"]; note.checkQuestion = "광합성은 빛이 필요해요"; note.checkAnswer = "O · 맞아요"
    let again = (try? JSONEncoder().encode(note)).flatMap { try? JSONDecoder().decode(ConceptNote.self, from: $0) }
    check("새 개념 정리: 저장 후 그대로 읽힘", again?.principles == note.principles && again?.mistakes == note.mistakes && again?.checkAnswer == "O · 맞아요")

    // 9) 자유 주제 학습: 새 칸 읽기
    let free = DoitStudy.parseFreeConcept("""
    핵심 개념: 블록체인은 거래 기록을 여러 컴퓨터가 함께 나눠 저장하는 기술이에요.
    학습 포인트:
    - 블록에는 거래 기록이 담겨요.
    - 블록들이 사슬처럼 이어져요.
    왜 그런지: 기록이 여러 곳에 있어서 한 곳만 고쳐서는 바꿀 수 없어요.
    예제: 반 친구 모두가 같은 출석부를 한 권씩 갖고 있는 것과 비슷해요.
    자주 하는 실수: 블록체인과 암호화폐를 같은 것으로 생각하기 쉬워요.
    """, topic: "블록체인")
    check("자유 주제: 원리·실수 읽기", free?.principles.count == 1 && free?.mistakes.count == 1 && free?.example.contains("출석부") == true, "\(String(describing: free))")
    let freePrompt = DoitStudy.freeConceptPrompt(topic: "블록체인", references: "")
    check("자유 주제 프롬프트: 왜 그런지·실수 칸", freePrompt.contains("왜 그런지:") && freePrompt.contains("자주 하는 실수:"), freePrompt)

    // 물어보는 말은 일정 추가가 아님 ("몇 ml 넣어야 해?" → 플랜 추가로 가던 오류)
    for question in ["몇미리 넣어야해", "몇ml넣어? 데리야끼 소수레시피", "소금은 언제 넣어?", "간장 얼마나 넣어야 돼"] {
        let reply = await DoitEngine.respond(to: question, photo: nil)
        check("일정 아님: \(question)", !reply.text.contains("[ADD PLAN]") && !reply.text.contains("하루 종일 일정"), reply.text)
    }
    let added = await DoitEngine.respond(to: "내일 오후 4시에 영어 공부 1시간 추가해줘", photo: nil)
    check("일정 추가는 그대로", added.text.contains("[ADD PLAN]"), added.text)
}
