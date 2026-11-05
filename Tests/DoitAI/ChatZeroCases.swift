import Foundation

// 모티 ZERO(모델 없이) 대화 회귀 검사: 학생이 실제로 이상하다고 한 답들과 점검에서 찾은 이상한 답들
// - 욕·손가락 욕("ㅗ")에 "무슨 뜻인지 헷갈려요"가 아니라 짧고 차분하게, 연달아 해도 같은 말 되풀이 없이
// - "너 ○○야"(영어 이름), "너 무슨 AI이야?" → 모티 ZERO 소개 (모델 이름은 말하지 않음)
// - 모르는 낱말 "더 자세히" → 엉뚱한 개념을 붙이지 않고 없다고 짧게
// - 답에 "은(는)", "과(와)" 같은 조사 자리표시가 남지 않음

@MainActor
func runChatZeroCases() async {
    let placeholders = ["은(는)", "이(가)", "을(를)", "과(와)", "와(과)", "(으)로", "(이)라"]
    func last(_ inputs: [String]) async -> (String, [String]) {
        let replies = await zeroConversation(inputs)
        return (replies.last ?? "", replies)
    }

    // 1) "ㅗ" 두 번: 일반 되묻기 말이 아니고, 두 번째도 같은 말이 아님
    var (reply, replies) = await last(["ㅗ", "ㅗ"])
    check("ZERO: 'ㅗ'는 되묻기가 아님", !replies.contains { $0.contains("무슨 뜻인지") || $0.contains("잘 이해했는지") || $0.contains("무슨 말인지") }, replies.joined(separator: " | "))
    check("ZERO: 'ㅗ' 연달아 해도 다른 말", replies[0] != replies[1] && reply.count <= 80, replies.joined(separator: " | "))
    for rude in ["ㅅㅂ", "씨발", "ㅂㅅ", "병신", "꺼져", "ㅈ같네", "좆같아"] {
        (reply, _) = await last([rude])
        check("ZERO: 욕 '\(rude)'에 차분하게", !reply.contains("무슨 말인지") && !reply.contains("좋아요") && !reply.contains("오케이") && reply.count <= 80, reply)
    }
    (reply, _) = await last(["개못하네"])
    check("ZERO: '개못하네'는 맞장구가 아님", !reply.contains("오케이") && !reply.contains("좋아요") && reply.contains("미안"), reply)
    (reply, _) = await last(["아 시발 피곤해"])
    check("ZERO: 욕이 섞인 감정 말은 감정 답", ["피곤", "쉬", "잠", "스트레칭"].contains { reply.contains($0) }, reply)

    // 2) 모티 자신
    for input in ["너 zeta야", "너 무슨 AI이야?", "너 LLM이야?", "너 챗봇이야?", "넌 abc냐", "무슨 모델 써?", "너 AI 맞아?"] {
        (reply, _) = await last([input])
        check("ZERO: '\(input)' → 모티 ZERO 소개", reply.contains("모티 ZERO") && reply.contains("AI 모델 없이") && !reply.lowercased().contains("zeta"), reply)
    }
    for input in ["너 바보야?", "너 천재야?"] {
        (reply, _) = await last([input])
        check("ZERO: '\(input)'는 소개가 아님", !reply.contains("AI 모델 없이"), reply)
    }
    (reply, _) = await last(["너 무슨 AI이야?"])
    check("ZERO: 모티 1·2는 오픈소스 AI 모델", reply.contains("오픈소스 AI 모델"), reply)
    for input in ["모티 1이랑 차이", "모티 ZERO가 뭐야", "모티 2는 뭐가 달라?", "AI 모델 받으면 뭐가 좋아?"] {
        (reply, _) = await last([input])
        check("ZERO: '\(input)' → 모드 설명", reply.contains("모티 ZERO") && reply.contains("모티 1·2"), reply)
    }
    (reply, _) = await last(["너 인터넷 돼?"])
    check("ZERO: 인터넷 질문", reply.contains("인터넷"), reply)
    (reply, _) = await last(["너 말 이상하게 해"])
    check("ZERO: 말이 이상하다는 말엔 사과와 설명", reply.contains("미안") && reply.contains("모티 ZERO"), reply)

    // 3) 모르는 낱말 "더 자세히": 엉뚱한 개념 없이 짧게
    for inputs in [["Zeta 더 자세히 알려줘"], ["너 무슨 AI이야?", "Zeta 더 자세히 알려줘"], ["광합성이 뭐야?", "Zeta 더 자세히 알려줘"]] {
        (reply, _) = await last(inputs)
        check("ZERO: \(inputs) → 모른다고 짧게", reply.contains("몰라") && !reply.contains("함께 알아두면") && !reply.contains("더 알아보기") && !reply.contains("광합성")
              && !reply.contains("가정법") && reply.count <= 90, reply)
    }
    (reply, _) = await last(["광합성이 뭐야?", "더 자세히 알려줘"])
    check("ZERO: 아는 주제 '더 자세히'에 빈 제목 없음", !reply.contains("더 알아보기") && !reply.contains("혈액 순환"), reply)

    // 4) 조사 자리표시 없음 (모르는 말·되묻기·도구 답)
    let probes: [[String]] = [["너 무슨 AI이야?"], ["아인슈타인 누구야"], ["Zeta가 뭐야"], ["광합성이 뭐야?", "왜?"], ["기회비용이 뭐야?", "왜 중요해?"],
                              ["주식 뭐 사?"], ["무지개는 왜 생겨?"], ["맞춤법 검사해줘: 어의없다"], ["임진왜란 언제야", "누가 이겼어?"], ["CPU가 뭐야"], ["피자랑 치킨 중에 골라줘"]]
    for inputs in probes {
        (reply, _) = await last(inputs)
        check("ZERO: \(inputs) 조사 자리표시 없음", !placeholders.contains { reply.contains($0) }, reply)
    }
    check("조사 고르기", DoitRelevance.with("AI", "은") == "AI는" && DoitRelevance.with("Zen", "은") == "Zen은" && DoitRelevance.with("광합성", "이") == "광합성이"
          && DoitRelevance.with("수학", "으로") == "수학으로" && DoitRelevance.with("서울", "으로") == "서울로" && DoitRelevance.with("3", "을") == "3을" && DoitRelevance.with("2", "을") == "2를",
          [DoitRelevance.with("AI", "은"), DoitRelevance.with("Zen", "은"), DoitRelevance.with("서울", "으로"), DoitRelevance.with("2", "을")].joined(separator: ","))

    // 5) 점검에서 찾은 엉뚱한 답
    let fixes: [(inputs: [String], expect: [String], reject: [String])] = [
        (["소수가 뭐야"], ["소수"], ["복소수"]),
        (["뉴턴은 누구야"], ["만유인력"], ["화살표"]),
        (["1인치는 몇 cm"], ["2.54"], ["최소공배수"]),
        (["안 않 구분"], ["아니하"], ["분류"]),
        (["광합성이 뭐야?", "그럼 반대는?"], ["세포 호흡"], ["반대말"]),
        (["관성이 뭐야", "그럼 반대는?"], ["관성"], ["반대말"]),
        (["내일 3시에 수학 1시간 넣어줘", "취소해줘"], ["[UPDATE delete"], ["또 봐요"]),
        (["내일 아침 7시에 일어나야 돼"], ["추가할까요", "기상"], ["[ADD PLAN]"]),
        (["시험 망침"], ["다음"], ["몰라요"]),
        (["오늘 날씨 좋다"], [], ["날씨 정보를 볼 수 없어요", "실시간"]),
        (["D-Day 언제야"], ["D-12"], []),
        (["목표 몇 시간이야?"], ["3시간"], ["숫자로 알려주세요"]),
        (["타이머 ㄱㄱ"], ["[TIMER start - "], ["ㄱㄱ"]),
        (["빛의 분산"], ["프리즘"], ["공분산"]),
        (["y=2x+1"], ["기울기 2"], []),
        (["미토콘드리아"], ["세포 호흡"], ["TCA"]),
        (["원자랑 분자 차이"], ["원자", "분자"], []),
        (["세계에서 제일 큰 나라"], ["러시아"], []),
        (["알람 맞춰줘"], ["플랜"], ["잘 몰라요"]),
        (["파이썬 코딩 알려줘"], ["코딩"], []),
        (["바이"], [], ["무슨 말인지"]),
        (["안뇽"], ["안녕"], []),
        (["머해"], [], ["무슨 뜻", "무슨 말인지"]),
        (["ㅇㅈ"], [], ["무슨 뜻", "무슨 말인지"]),
        (["대박"], [], ["칭찬"]),
        (["현재완료 설명해줘", "예문 들어줘"], ["have"], ["준비된 게 없어요"]),
        (["광복절은 몇 년도"], ["1945"], []),
        (["무지개는 왜 생겨?"], ["굴절"], []),
        (["되 돼 차이"], ["되어"], [])
    ]
    for test in fixes {
        (reply, _) = await last(test.inputs)
        let ok = test.expect.allSatisfy { reply.contains($0) } && !test.reject.contains { reply.contains($0) }
        check("ZERO: \(test.inputs)", ok, reply.prefix(200).replacingOccurrences(of: "\n", with: " / "))
    }

    // 6) 못 알아들은 말이 이어지면 같은 되묻기를 되풀이하지 않음
    (reply, replies) = await last(["ㅁㄴㅇㄹ", "ㅁㄴㅇㄹ"])
    check("ZERO: 못 알아들은 말이 이어지면 다른 안내", replies[0] != replies[1] && replies[1].contains("이렇게 말해 주면"), replies.joined(separator: " | "))

    // 7) 도움말은 짧게
    (reply, _) = await last(["뭐 할 수 있어?"])
    check("ZERO: 도움말 짧게 (\(reply.count)자)", reply.count <= 260 && reply.contains("타이머"), reply)
    DoitConversation.userName = nil
}
