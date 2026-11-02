import Foundation

// 대화 관련성 검사 (모델 없이 규칙형 엔진만)
// 학생이 실제로 보낼 만한 말 400개 이상을 앱과 같은 길(DoitAssistant.send → 이어 말하기 → DoitEngine.respond → 샌 답 막기)로 보내고,
// 답이 질문과 관련 있는지를 정확한 문장이 아니라 "들어 있어야 할 낱말 / 없어야 할 말 / 답의 종류"로 봐요.
// - 답의 종류: 되묻기(clarify) · 모른다고 하기(unknown) · 앱 명령 실행(command) · 수학 풀이(math) · 퀴즈(quiz) · 가벼운 대화(light)
// - 모든 답: 짧게 (결론·요약 칸 없이), 대화에 지식 사전 짐작("혹시 **…**")이 끼어들지 않게

enum RelKind {
    /// 종류는 보지 않음 (낱말만)
    case any
    /// 짧은 대화 답 (지식 설명·수학 풀이가 아님)
    case light
    /// 짧게 되묻기
    case clarify
    /// 모르는 건 모른다고 짧게 (지어내지 않음)
    case unknown
    /// 앱 기능 실행
    case command
    /// 수학 풀이
    case math
    /// 퀴즈 시작·진행
    case quiz
    /// 내용 있는 답 (모른다는 말이 아님)
    case answer
}

struct RelCase {
    let cat: String
    let inputs: [String]
    var kind: RelKind = .any
    /// 하나라도 들어 있어야 함 (대소문자·띄어쓰기 무시)
    var any: [String] = []
    /// 모두 들어 있어야 함
    var all: [String] = []
    /// 들어 있으면 안 됨
    var none: [String] = []
    /// 최대 글자 수
    var max = 700
}

private let unknownWords = ["몰라요", "모르", "알 수 없", "확인할 수 없", "확인하기 어려", "알기 어려", "찾을 수 없", "없어요", "못해요", "못 해요", "어려워요", "할 수 없"]
private let askWords = ["?", "알려 주세요", "알려주세요", "보내 주세요", "보내주세요", "적어 주세요", "적어주세요", "말해 주세요", "말해주세요", "알려줄래요", "말해줄래요", "적어 줄래요"]

private func squashed(_ s: String) -> String { s.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "*", with: "") }

/// 답의 종류가 맞는지 (맞지 않으면 이유)
private func kindProblem(_ kind: RelKind, _ reply: String) -> String? {
    let guess = reply.contains("혹시 **")
    let dump = reply.hasPrefix("**") && !reply.contains("답:")
    switch kind {
    case .any:
        return nil
    case .light:
        if guess { return "대화에 지식 짐작이 끼어듦" }
        if dump || reply.contains("**답") { return "대화인데 설명·풀이를 함" }
        return reply.count > 320 ? "대화 답이 너무 김" : nil
    case .clarify:
        if guess { return "되묻지 않고 짐작함" }
        if reply.count > 220 { return "되묻는 말이 너무 김" }
        return askWords.contains(where: { reply.contains($0) }) ? nil : "되묻지 않음"
    case .unknown:
        if guess { return "모르는 걸 짐작함" }
        if reply.count > 280 { return "모른다는 말이 너무 김" }
        return unknownWords.contains(where: { reply.contains($0) }) ? nil : "모른다고 하지 않음"
    case .command:
        return reply.contains("[") || reply.contains("메모 저장") ? nil : "명령을 실행하지 않음"
    case .math:
        return reply.contains("답:") || reply.contains("**답") ? nil : "수학 답이 없음"
    case .quiz:
        return reply.contains("퀴즈") ? nil : "퀴즈가 아님"
    case .answer:
        if ["잘 몰라요", "아직 몰라요", "모르겠어요"].contains(where: { reply.contains($0) }) { return "모른다고 함" }
        return nil
    }
}

/// 한 경우의 결과 (통과하면 nil)
private func relevanceProblem(_ test: RelCase, _ reply: String) -> String? {
    let body = squashed(reply)
    if reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "빈 답" }
    if !test.any.isEmpty, !test.any.contains(where: { body.contains(squashed($0)) }) { return "기대 낱말 없음 \(test.any)" }
    if let missing = test.all.first(where: { !body.contains(squashed($0)) }) { return "'\(missing)' 없음" }
    if let bad = test.none.first(where: { reply.contains($0) }) { return "'\(bad)'이(가) 들어 있음" }
    if let problem = kindProblem(test.kind, reply) { return problem }
    // 짧게: 결론·요약 칸 없이, 너무 길지 않게
    if ["**결론", "결론:", "**요약", "요약:"].contains(where: { reply.contains($0) }) { return "결론·요약 칸이 있음" }
    if reply.count > test.max { return "답이 너무 김 (\(reply.count)자)" }
    return nil
}

@MainActor
private func buildRelevanceCases() -> [RelCase] {
    var list: [RelCase] = []
    var cat = ""
    func t(_ input: String, _ kind: RelKind = .any, any: [String] = [], all: [String] = [], none: [String] = [], max: Int = 700) {
        list.append(RelCase(cat: cat, inputs: [input], kind: kind, any: any, all: all, none: none, max: max))
    }
    func m(_ inputs: [String], _ kind: RelKind = .any, any: [String] = [], all: [String] = [], none: [String] = [], max: Int = 700) {
        list.append(RelCase(cat: cat, inputs: inputs, kind: kind, any: any, all: all, none: none, max: max))
    }

    // MARK: 인사·잡담·감정
    cat = "인사·감정"
    t("안녕", .light, any: ["안녕", "반가"])
    t("안녕하세요", .light, any: ["안녕", "반가"])
    t("ㅎㅇ", .light, any: ["안녕", "반가"])
    t("하이", .light, any: ["안녕", "반가"])
    t("좋은 아침", .light, any: ["아침", "안녕", "좋은"])
    t("잘자", .light, any: ["잘 자", "푹", "굿나잇", "내일", "잘자"])
    t("고마워", .light, any: ["천만", "고마", "언제든", "별말", "도움"])
    t("고마워요!", .light, any: ["천만", "고마", "언제든", "별말", "도움"])
    t("ㄱㅅ", .light, any: ["천만", "고마", "언제든", "별말", "도움"])
    t("너 누구야?", .light, any: ["두잇", "DOOOIT"])
    t("너 이름이 뭐야", .light, any: ["두잇", "DOOOIT"])
    t("넌 뭘 할 수 있어?", any: ["일정", "수학", "타이머"], max: 1400)
    t("공부하기 싫어", .light, any: ["공부", "마음", "조금", "쉬", "분"])
    t("아 진짜 공부하기 싫다", .light, any: ["공부", "마음", "조금", "쉬", "분"])
    t("피곤해", .light, any: ["피곤", "쉬", "잠", "휴식", "스트레칭"])
    t("오늘 너무 피곤하다", .light, any: ["피곤", "쉬", "잠", "휴식", "스트레칭"])
    t("졸려", .light, any: ["졸", "잠", "쉬", "스트레칭", "물", "세수"])
    t("너무 힘들어", .light, any: ["힘들", "괜찮", "들을", "마음", "쉬"])
    t("우울해", .light, any: ["우울", "마음", "괜찮", "들을", "이야기"])
    t("스트레스 받아", .light, any: ["스트레스", "숨", "쉬", "마음", "괜찮"])
    t("짜증나", .light, any: ["짜증", "숨", "쉬", "마음", "괜찮", "화"])
    t("배고파", .light, any: ["배고", "먹", "간식", "밥"])
    t("심심해", .light, any: ["심심", "퀴즈", "재밌", "놀"])
    t("기분 좋아", .light, any: ["좋", "기분", "행복"])
    t("시험 망했어", .light, any: ["괜찮", "망", "다음", "속상", "수고", "오답"])
    t("시험 잘 봤어!", .light, any: ["축하", "잘", "대단", "수고", "멋"])
    t("나 오늘 100점 맞았어", .light, any: ["축하", "대단", "멋", "잘"])
    t("집중이 안 돼", .light, any: ["집중", "타이머", "분", "폰"])
    t("긴장돼", .light, any: ["긴장", "괜찮", "숨", "떨", "불안", "걱정"])
    t("불안해", .light, any: ["불안", "괜찮", "숨", "걱정"])
    t("외로워", .light, any: ["외로", "이야기", "마음"])
    t("친구랑 싸웠어", .light, any: ["친구", "속상", "마음", "이야기"])
    t("엄마한테 혼났어", .light, any: ["속상", "혼", "마음", "이야기"])
    t("쉬고 싶어", .light, any: ["쉬", "휴식", "분"])
    t("넌 사람이야?", .light, any: ["AI", "인공지능", "두잇", "사람"])
    t("사랑해", .light, any: ["사랑", "고마", "좋아", "💛", "❤"])
    t("너 똑똑하다", .light, any: ["고마", "헤헤", "칭찬", "덕분"])
    t("바보야", .light)
    t("재밌는 얘기 해줘", .light)
    t("농담 해줘", .light)
    t("명언 하나 알려줘", .light)
    t("응원해줘", .light, any: ["응원", "할 수", "힘", "화이팅", "파이팅", "잘하"])
    t("동기부여 좀 해줘", .light)
    t("오늘 며칠이야?", .light, any: ["월", "일"])
    t("지금 몇 시야?", .light, any: ["시"])
    t("오늘 무슨 요일이야", .light, any: ["요일"])
    t("잘 지냈어?", .light)
    t("뭐해?", .light)
    t("나 내일 시험이야", .light, any: ["시험", "응원", "잘", "복습", "잠", "화이팅"])
    t("공부 왜 해야 돼?", .light, any: ["공부"])
    t("놀고 싶다", .light, any: ["놀", "쉬", "타이머", "분"])
    t("자고 싶어", .light, any: ["잠", "자", "쉬"])
    t("오늘 공부 열심히 했어", .light, any: ["수고", "잘", "대단", "멋", "칭찬", "열심", "공부했"])
    t("너무 졸린데 어떡해", .light, any: ["졸", "잠", "쉬", "스트레칭", "물", "세수"])
    t("하기 싫다 ㅠㅠ", .light)
    t("미안해", .light, any: ["괜찮", "미안"])
    t("잘 있어", .light, any: ["안녕", "다음", "또", "잘", "수고"])
    t("나 오늘 생일이야", .light, any: ["생일", "축하"])

    // MARK: 앱 명령
    cat = "앱 명령"
    t("내일 3시에 영어 학원 추가해줘", .command, all: ["[ADD PLAN] 영어 학원", "date=내일"])
    t("모레 오후 2시 수학 학원 일정 추가", .command, all: ["[ADD PLAN] 수학 학원", "date=모레"])
    t("토요일 오전 10시 도서관 가기 추가", .command, all: ["[ADD PLAN]", "도서관"])
    t("오늘 저녁 8시 국어 숙제 1시간 넣어줘", .command, all: ["[ADD PLAN] 국어 숙제", "min=60"])
    t("매일 밤 9시 영어 단어 30분 추가", .command, all: ["[ADD PLAN]", "영어 단어", "min=30"])
    t("다음주 월요일 과학 수행평가 추가", .command, all: ["[ADD PLAN]", "과학 수행평가"])
    t("12월 3일 기말고사 일정 등록해줘", .command, all: ["[ADD PLAN]", "기말고사", "12월 3일"])
    t("내일오후4시수학공부추가", .command, all: ["[ADD PLAN]", "수학"])
    t("일정 추가 내일 7시 운동", .command, all: ["[ADD PLAN]", "운동"])
    t("금요일에 친구 생일파티 일정 넣어줘", .command, all: ["[ADD PLAN]", "생일파티"])
    t("오늘 일정 알려줘", .command, any: ["[OVERVIEW"])
    t("내일 할 일 뭐야", .command, any: ["[OVERVIEW 내일"])
    t("이번 주 일정 보여줘", .command, any: ["[OVERVIEW"])
    t("오늘 뭐 해야 돼?", .command, any: ["[OVERVIEW"])
    t("오늘할일", .command, any: ["[OVERVIEW"])
    t("스케줄 알려줘", .command, any: ["[OVERVIEW"])
    t("내일 일정", .command, any: ["[OVERVIEW 내일"])
    t("영어 학원 일정 삭제해줘", .command, any: ["[UPDATE delete 영어 학원]"])
    t("수학 공부 지워줘", .command, any: ["[UPDATE delete 수학 공부]"])
    t("오늘 수학 공부 일정 빼줘", .command, any: ["[UPDATE delete 수학 공부]"])
    t("일정 삭제해줘", .clarify, any: ["어떤", "이름"])
    t("수학 공부 다 했어", .command, any: ["[UPDATE complete 수학 공부]"])
    t("영어 학원 끝났어", .command, any: ["[UPDATE complete 영어 학원]"])
    t("수학공부완료", .command, any: ["[UPDATE complete 수학 공부]"])
    t("수학 공부 완료 취소", .command, any: ["[UPDATE uncomplete 수학 공부]"])
    t("타이머 25분", .command, any: ["[TIMER start - 25]"])
    t("25분 타이머 맞춰줘", .command, any: ["[TIMER start"], all: ["25"])
    t("영어 30분 타이머 켜줘", .command, any: ["[TIMER start 영어 30]"])
    t("타이머 꺼줘", .command, any: ["[TIMER stop"])
    t("타이머 멈춰", .command, any: ["[TIMER stop"])
    t("타이머 일시정지", .command, any: ["[TIMER pause"])
    t("공부 시작할게", .command, any: ["[TIMER start"])
    t("타이머25분시작", .command, any: ["[TIMER start - 25]"])
    t("타이머 화면 열어줘", .command, any: ["[OPEN timer]"])
    t("플래너 열어줘", .command, any: ["[OPEN planner]"])
    t("설정 화면 열어줘", .command, any: ["[OPEN account]"])
    t("단어 추가: banana 바나나", .command, all: ["[ADD WORDS]", "banana"])
    t("단어장에 happy 행복한 추가해줘", .command, all: ["[ADD WORDS]", "happy"])
    t("apple 사과 단어 추가", .command, all: ["[ADD WORDS]", "apple"])
    t("단어 추가해줘", .clarify, any: ["예:", "알려주세요"])
    t("단어 몇 개 외웠어?", .command, any: ["[RECORDS words"])
    t("메모해줘: 내일 체육복 챙기기", .command, all: ["메모 저장", "체육복"])
    t("메모 남겨줘 수행평가 준비물 풀", .command, all: ["메모 저장", "수행평가"])
    t("메모 보여줘", .command, any: ["[RECORDS memos"])
    t("준비물 메모 찾아줘", .command, any: ["[SEARCH 준비물"])
    t("메모해줘", .clarify, any: ["메모할 내용"])
    t("수능 디데이 11월 19일로 설정", .command, any: ["[SETTINGS 수능 11월 19일"])
    t("중간고사 D-day 10월 20일", .command, any: ["[SETTINGS 중간고사 10월 20일"])
    t("디데이 설정해줘", .clarify, any: ["날짜"])
    t("하루 목표 3시간으로 해줘", .command, any: ["180"])
    t("공부 목표 2시간 30분", .command, any: ["150"])
    t("단어 목표 50개", .command, any: ["[SETTINGS - - -1 50]"])
    t("목표 설정해줘", .clarify, any: ["목표"])
    t("오늘 공부 얼마나 했어?", .command, any: ["[STATS 1]"])
    t("이번 달 공부 시간", .command, any: ["[STATS 30]"])
    t("공부 통계 보여줘", .command, any: ["[STATS"])
    t("주간 리포트", .command, any: ["[WEEKLY REPORT]"])
    t("오답노트 몇 개야", .command, any: ["[RECORDS notes"])
    t("3시에 학원 가야 돼", any: ["추가할까요"])
    t("수학 퀴즈 내줘", .quiz, any: ["퀴즈 1번"])
    t("영어 단어 퀴즈", .quiz, any: ["퀴즈 1번"])
    t("내 단어로 시험 봐줘", .quiz, any: ["퀴즈 1번"])
    t("과학 문제 내줘", .quiz, any: ["퀴즈 1번"])
    t("역사 퀴즈", .quiz, any: ["퀴즈 1번"])
    t("문제 하나 내봐", .quiz, any: ["퀴즈 1번"])
    t("퀴즈 내줘", .quiz, any: ["퀴즈 1번"])
    m(["수학 퀴즈 내줘", "모르겠어"], any: ["정답"])
    m(["영어 퀴즈 내줘", "그만"], any: ["퀴즈를 마칠게요"])
    m(["사회 퀴즈 내줘", "힌트"], .light, none: ["퀴즈를 마칠게요"])

    // MARK: 수학
    cat = "수학"
    t("2x+3=11 풀어줘", .math, any: ["x = 4"], max: 1500)
    t("x^2-5x+6=0", .math, any: ["x = 2 또는 x = 3"], max: 1500)
    t("3+5*2", .math, any: ["13"], max: 1500)
    t("12 곱하기 7", .math, any: ["84"], max: 1500)
    t("100 나누기 4는?", .math, any: ["25"], max: 1500)
    t("15의 약수", .math, any: ["1, 3, 5, 15"], max: 1500)
    t("12와 18의 최대공약수", .math, any: ["6"], max: 1500)
    t("4와 6의 최소공배수", .math, any: ["12"], max: 1500)
    t("x^2+2x+1 인수분해", .math, any: ["(x+1)", "(x + 1)"], max: 1500)
    t("x^3 미분", .math, any: ["3x"], max: 1500)
    t("반지름이 3인 원의 넓이", .math, any: ["9π", "28.2"], max: 1500)
    t("2의 10제곱", .math, any: ["1024"], max: 1500)
    t("루트 16", .math, any: ["4"], max: 1500)
    t("sin 30도", .math, any: ["1/2", "0.5"], max: 1500)
    t("10000원에서 20% 할인하면?", any: ["8000", "8,000"], max: 1500)
    t("직각삼각형 두 변이 3, 4일 때 빗변", .math, any: ["5"], max: 1500)
    t("80 90 100 평균", .math, any: ["90"], max: 1500)
    t("5! 계산해줘", .math, any: ["120"], max: 1500)
    t("2x+5=x+9", .math, any: ["x = 4"], max: 1500)
    t("x+y=5, x-y=1", .math, any: ["x = 3"], max: 1500)
    t("2x > 6", .math, any: ["x > 3"], max: 1500)
    t("y=x^2-4x+3 꼭짓점", .math, any: ["(2, -1)", "(2, −1)", "(2,-1)"], max: 1500)
    t("1/3 + 1/6", .math, any: ["1/2"], max: 1500)
    t("2x+3=11풀어줘", .math, any: ["x = 4"], max: 1500)
    t("x^2-4=0풀어", .math, any: ["x = -2", "x = −2", "±2", "x = 2"], max: 1500)
    t("삼각형 넓이 밑변 6 높이 4", .math, any: ["12"], max: 1500)
    t("이 문제 풀어줘", .clarify, any: ["보내"])
    t("풀어줘", .clarify, any: ["문제", "보내", "식"])
    t("인수분해가 뭐야", .answer, any: ["인수분해"])
    t("미분이 뭐야?", .answer, any: ["미분"])
    t("함수가 뭐야", .answer, any: ["함수"])
    t("소수가 뭐야", .answer, any: ["소수"])
    t("확률이 뭐야", .answer, any: ["확률"])
    t("피타고라스 정리 설명해줘", .answer, any: ["피타고라스"])
    t("근의 공식 알려줘", .answer, any: ["근의 공식", "b²", "b^2"])
    t("일차함수 기울기 구하는 법", any: ["기울기"], max: 1500)
    t("로그가 뭐야", .answer, any: ["로그"])
    t("삼각형 내각의 합은?", any: ["180"], max: 1500)
    t("원주율이 뭐야", .answer, any: ["원주율", "π", "3.14"])
    t("적분이 뭐야", .answer, any: ["적분"])
    t("집합이 뭐야?", .answer, any: ["집합"])
    t("유리수랑 무리수 차이", .answer, any: ["유리수", "무리수"])
    t("수학 문제 어떻게 풀어?", .light, any: ["문제", "개념", "보내", "수학"])
    m(["x^2-5x+6=0 풀어줘", "왜?"], any: ["x = 2"], max: 1500)
    m(["f(x)=x^2+1", "x=2일 때는?"], any: ["f(2) = 5"], max: 1500)
    m(["2x+3=11 풀어줘", "그럼 2x+3=15는?"], any: ["x = 6"], max: 1500)
    m(["x^2-5x+6=0 풀어줘", "다른 예시"], any: ["비슷한 문제"], max: 1500)

    // MARK: 과학 개념
    cat = "과학"
    t("광합성이 뭐야", .answer, any: ["광합성"])
    t("세포 호흡이 뭐야", .answer, any: ["호흡"])
    t("뉴턴 운동 제2법칙", .answer, any: ["가속도", "F = ma", "F=ma"])
    t("관성이 뭐야", .answer, any: ["관성"])
    t("원자 구조 알려줘", .answer, any: ["원자", "전자", "원자핵"])
    t("산화 환원이 뭐야", .answer, any: ["산화"])
    t("DNA가 뭐야", .answer, any: ["DNA", "유전"])
    t("블랙홀이 뭐야?", .answer, any: ["블랙홀"])
    t("지구 자전이 뭐야", .answer, any: ["자전"])
    t("판 구조론 설명해줘", .answer, any: ["판"])
    t("삼투 현상이 뭐야", .answer, any: ["삼투"])
    t("미토콘드리아 역할", .answer, any: ["미토콘드리아"])
    t("옴의 법칙", .answer, any: ["전압", "옴"])
    t("화산은 왜 생겨?", .answer, any: ["화산", "마그마"])
    t("계절이 생기는 이유", .answer, any: ["계절", "자전축", "기울"])
    t("이온이 뭐야", .answer, any: ["이온"])
    t("중력이 뭐야", .answer, any: ["중력"])
    t("에너지 보존 법칙", .answer, any: ["에너지"])
    t("기압이 뭐야", .answer, any: ["기압"])
    t("효소가 뭐야", .answer, any: ["효소"])
    t("먹이 사슬이 뭐야", .answer, any: ["먹이"])
    t("물의 순환", .answer, any: ["물", "순환"])
    t("빛의 굴절", .answer, any: ["굴절"])
    t("달의 위상 변화", .answer, any: ["달", "위상"])
    t("주기율표가 뭐야", .answer, any: ["주기율표", "원소"])
    t("전압 12V 저항 4Ω 전류는?", any: ["3 A", "3A"])
    t("H2O 몰질량", any: ["18"])
    t("하늘은 왜 파래?", any: ["산란", "파란", "빛", "하늘"])
    t("세포 분열이 뭐야", .answer, any: ["분열"])
    t("유전자가 뭐야", .answer, any: ["유전"])

    // MARK: 사회·역사
    cat = "사회·역사"
    t("임진왜란 언제야", .answer, any: ["1592"])
    t("세종대왕 업적", .answer, any: ["훈민정음", "한글", "세종"])
    t("3.1운동이 뭐야", .answer, any: ["3·1", "3.1", "1919"])
    t("6.25 전쟁 언제 일어났어?", .answer, any: ["1950"])
    t("고려는 언제 세워졌어?", .answer, any: ["918", "고려"])
    t("조선 건국", .answer, any: ["1392", "이성계"])
    t("프랑스 혁명이 뭐야", .answer, any: ["프랑스 혁명", "1789"])
    t("산업 혁명", .answer, any: ["산업 혁명", "산업혁명"])
    t("민주주의가 뭐야", .answer, any: ["민주주의"])
    t("삼권 분립이 뭐야", .answer, any: ["삼권", "입법"])
    t("기회비용이 뭐야?", .answer, any: ["기회비용"])
    t("수요와 공급", .answer, any: ["수요", "공급"])
    t("인플레이션이 뭐야", .answer, any: ["인플레이션", "물가"])
    t("GDP가 뭐야", .answer, any: ["GDP", "국내 총생산", "국내총생산"])
    t("프랑스 수도", .answer, any: ["파리"])
    t("일본 수도는?", .answer, any: ["도쿄"])
    t("갑오개혁", .answer, any: ["갑오개혁"])
    t("동학 농민 운동", .answer, any: ["동학"])
    t("훈민정음은 언제 만들어졌어?", .answer, any: ["1443", "1446"])
    t("냉전이 뭐야", .answer, any: ["냉전"])
    t("헌법이 뭐야", .answer, any: ["헌법"])
    t("선거의 4대 원칙", .answer, any: ["보통", "평등", "직접", "비밀"])
    t("지구 온난화 원인", .answer, any: ["온난화", "온실"])
    t("1592년에 무슨 일 있었어?", .answer, any: ["임진왜란"])
    t("이순신 장군", .answer, any: ["이순신"])
    t("병자호란 언제야", .answer, any: ["1636", "병자호란"])
    t("세계 2차 대전", .answer, any: ["제2차 세계 대전", "2차 세계", "1939"])
    t("광복절이 언제야", any: ["8월 15일", "광복"])
    t("미국 수도 어디야", .answer, any: ["워싱턴"])
    t("시장 경제가 뭐야", .answer, any: ["시장"])

    // MARK: 윤리·철학
    cat = "윤리·철학"
    t("칸트 정언명령 설명해줘", .answer, any: ["정언"])
    t("공리주의가 뭐야", .answer, any: ["공리주의"])
    t("소크라테스가 누구야", .answer, any: ["소크라테스"])
    t("맹자 성선설", .answer, any: ["성선설", "맹자"])
    t("순자 성악설", .answer, any: ["성악설", "순자"])
    t("아리스토텔레스 중용", .answer, any: ["중용"])
    t("사회 계약설", .answer, any: ["사회 계약", "사회계약"])
    t("롤스 정의론", .answer, any: ["롤스", "정의"])
    t("벤담이랑 밀 차이", .answer, any: ["벤담", "밀"])
    t("공자 인 사상", .answer, any: ["공자", "인"])

    // MARK: 국어
    cat = "국어"
    t("은유법이 뭐야", .answer, any: ["은유"])
    t("직유법 예시", .answer, any: ["직유", "처럼", "같이"])
    t("반어법이 뭐야", .answer, any: ["반어"])
    t("설의법", .answer, any: ["설의"])
    t("1인칭 주인공 시점", .answer, any: ["1인칭", "주인공"])
    t("품사 종류 알려줘", .answer, any: ["품사", "명사"])
    t("비음화가 뭐야", .answer, any: ["비음"])
    t("형태소가 뭐야", .answer, any: ["형태소"])
    t("높임법", .answer, any: ["높임"])
    t("김소월 진달래꽃", .answer, any: ["진달래꽃", "김소월"])
    t("논설문이 뭐야", .answer, any: ["논설문"])
    t("맞춤법 되 돼 차이", any: ["되", "돼"])

    // MARK: 영어
    cat = "영어"
    t("apple 뜻", any: ["사과"])
    t("abundant 뜻이 뭐야", any: ["풍부"])
    t("resilient 무슨 뜻", any: ["회복"])
    t("go 과거형", any: ["went"])
    t("eat 과거분사", any: ["eaten"])
    t("run의 과거형", any: ["ran"])
    t("good 비교급", any: ["better"])
    t("사과를 영어로", any: ["apple"])
    t("행복하다 영어로 뭐야", any: ["happy"])
    t("책 영어로", any: ["book"])
    t("학교 영어로 뭐야", any: ["school"])
    t("He go to school 문법 맞아?", any: ["goes"])
    t("I has a pen 틀린 곳 알려줘", any: ["have"])
    t("look forward to 뜻", any: ["기대", "고대"])
    t("give up 뜻", any: ["포기"])
    t("thank you 뜻", any: ["고마", "감사"])
    t("현재완료 설명해줘", .answer, any: ["have"])
    t("현재완료 진행형", .answer, any: ["have been", "been"])
    t("관계대명사 설명해줘", .answer, any: ["관계대명사"])
    t("to부정사 용법", .answer, any: ["to부정사", "to 부정사"])
    t("수동태 만드는 법", .answer, any: ["수동태", "be"])
    t("가정법 과거", .answer, any: ["가정법"])
    t("동명사랑 to부정사 차이", .answer, any: ["동명사"])
    t("비교급 만드는 법", .answer, any: ["비교급", "er"])
    t("be동사가 뭐야", .answer, any: ["am", "is", "are", "be"])
    t("children 단수", any: ["child"])
    t("mouse 복수형", any: ["mice"])
    t("make 과거형", any: ["made"])
    t("a와 the 차이", any: ["the", "관사"])
    t("How are you?", .light)
    t("What's your name?", .light, any: ["두잇", "DOOOIT"])
    t("영어 공부 어떻게 해?", .light, any: ["영어"])
    t("영어 단어 잘 외우는 법", .light, any: ["단어", "반복", "예문"])
    t("beautiful 뜻", any: ["아름다"])
    t("can과 could 차이", any: ["could", "can"])
    t("현재진행형 만드는 법", .answer, any: ["ing", "진행"])
    t("study 과거형", any: ["studied"])
    t("happy 반대말", any: ["unhappy", "sad", "반대"])

    // MARK: 공부 상담
    cat = "공부 상담"
    t("시험 2주 남았는데 어떻게 공부해?", .light, any: ["2주", "계획", "복습", "기출", "주"])
    t("시험 기간 계획 어떻게 세워?", .light, any: ["계획"])
    t("수학 공부법 알려줘", .light, any: ["수학"])
    t("국어 비문학 어떻게 공부해", .light, any: ["비문학", "지문", "독해", "국어"])
    t("암기 잘하는 법", .light, any: ["암기", "반복", "외우", "기억"])
    t("공부 계획 짜줘", .light, any: ["계획", "플래너", "시간"])
    t("벼락치기 해도 돼?", .light, any: ["벼락", "밤", "잠", "복습"])
    t("밤새서 공부해도 될까", .light, any: ["잠", "밤"])
    t("집중력 높이는 법", .light, any: ["집중"])
    t("공부할 때 음악 들어도 돼?", .light, any: ["음악", "가사", "소음"])
    t("하루에 공부 몇 시간 해야 돼?", .light, any: ["시간"])
    t("오답노트 어떻게 써?", .light, any: ["오답"])
    t("수학 개념이 이해가 안 돼", .light, any: ["개념", "수학"])
    t("모의고사 성적이 안 올라", .light, any: ["성적", "모의고사", "기출", "오답", "괜찮"])
    t("수능 공부 언제부터 해야 돼?", .light, any: ["수능", "지금", "계획"])
    t("중간고사 준비 어떻게 해", .light, any: ["중간", "시험", "계획", "복습"])
    t("과학 외울 게 너무 많아", .light, any: ["과학", "외우", "암기"])
    t("공부하는데 자꾸 폰 봐", .light, any: ["폰", "휴대폰", "핸드폰"])
    t("슬럼프 왔어", .light, any: ["슬럼프", "쉬", "괜찮"])
    t("인강이랑 학원 중에 뭐가 나아?", .light, any: ["인강", "학원"])
    t("공부법 추천해줘", .light, any: ["공부"])
    t("효율적으로 공부하는 방법", .light, any: ["공부"])
    t("복습은 언제 해야 돼?", .light, any: ["복습"])
    t("예습 꼭 해야돼?", .light, any: ["예습"])
    t("수학 문제 틀리면 어떻게 해?", .light, any: ["틀린", "오답", "다시"])
    t("시험 전날 뭐 해야 돼", .light, any: ["전날", "잠", "복습", "시험"])
    t("하루에 영어 단어 몇 개 외워야 돼?", .light, any: ["단어", "개"])
    t("영어 듣기 실력 늘리는 법", .light, any: ["듣기", "영어"])
    t("공부 순서 어떻게 정해?", .light, any: ["순서", "계획", "공부"])
    t("시험 일주일 남았어", .light, any: ["일주일", "계획", "복습", "시험", "7일"])

    // MARK: 문제 유형
    cat = "문제 유형"
    t("이 문제 무슨 유형이야?", .clarify, any: ["문제 글", "사진", "보내"])
    t("영어 문제 유형 알려줘", any: ["영어 문제 유형"])
    t("수학 문제 유형 뭐 있어?", any: ["수학"], all: ["유형"])
    t("국어 문제 유형", any: ["국어"], all: ["유형"])
    t("과학 문제 유형 알려줘", any: ["과학"], all: ["유형"])
    t("사회 문제 유형", any: ["사회"], all: ["유형"])
    t("다음 글의 주제로 가장 적절한 것은? 이거 무슨 유형이야", any: ["주제"])
    t("빈칸에 들어갈 말로 가장 적절한 것은 무슨 유형이야", any: ["빈칸"])
    t("윗글의 내용과 일치하지 않는 것은? 유형 알려줘", any: ["일치"])
    t("주어진 글 다음에 이어질 글의 순서로 가장 적절한 것은? 무슨 유형", any: ["순서"])
    t("이거 무슨 과목이야", .clarify, any: ["보내"])
    m(["x^2-5x+6=0 풀어줘", "이 문제 무슨 유형이야?"], any: ["방정식", "유형"])
    t("밑줄 친 부분이 가리키는 대상이 나머지와 다른 것은? 유형", any: ["가리키", "지칭", "대상"])
    t("이차방정식 x^2-3x+2=0의 두 근의 합은? 무슨 유형이야", any: ["근", "방정식"])

    // MARK: 애매한 말
    cat = "애매한 말"
    t("그거", .clarify)
    t("이거", .clarify)
    t("그거 뭐였지", .clarify)
    t("음", .light)
    t("음...", .light)
    t("ㅋㅋ", .light)
    t("ㅋㅋㅋㅋㅋ", .light)
    t("ㅎㅎ", .light)
    t("ㅠㅠ", .light)
    t("?", .clarify)
    t("...", .light)
    t("아", .light)
    t("흠", .light)
    t("어", .light)
    t("그래", .light)
    t("그렇구나", .light)
    t("아하", .light)
    t("알려줘", .clarify)
    t("설명해줘", .clarify)
    t("뭐야", .clarify)
    t("왜", .clarify)
    t("어떻게", .clarify)
    t("그거 해줘", .clarify)
    t("아까 그거", .clarify)
    t("그 문제", .clarify)
    t("뭐라고?", .light)
    t("다시", .clarify)
    t("더", .light)
    t("그래서?", .light)
    t("ㄴㄴ", .light)
    t("ㅇㅋ", .light)
    t("ok", .light)
    t("네", .light)
    t("아니요", .light)
    t("그냥", .light)
    t("응", .light)
    t("ㅇㅇ", .light)
    t("몰라", .light)
    t("됐어", .light)
    t("알겠어", .light)
    t("수학", any: ["수학"])
    t("영어", any: ["영어"])
    t("과학", any: ["과학"])
    t("시험", any: ["시험"])
    t("공부", any: ["공부"])
    t("아무거나", .light)
    t("헐", .light)
    t("대박", .light)
    t("진짜?", .light)
    t("에휴", .light)

    // MARK: 모르는 것 (지어내지 않기)
    cat = "모르는 것"
    t("오늘 날씨 어때?", .unknown)
    t("내일 비 와?", .unknown)
    t("오늘 뉴스 알려줘", .unknown)
    t("요즘 주식 어때", .unknown)
    t("비트코인 가격 알려줘", .unknown)
    t("환율 알려줘", .unknown)
    t("손흥민 오늘 골 넣었어?", .unknown)
    t("지금 대통령 누구야", .unknown)
    t("내 생일 언제야?", .unknown)
    t("우리 학교 급식 메뉴 뭐야", .unknown)
    t("내 성적 몇 점이야", .unknown)
    t("우리 선생님 이름 알아?", .unknown)
    t("BTS 신곡 언제 나와?", .unknown)
    t("아이폰 18 언제 출시해?", .unknown)
    t("지금 서울 기온", .unknown)
    t("어제 축구 경기 결과", .unknown)
    t("내 친구 민수 전화번호 알려줘", .unknown)
    t("우리 집 주소 알아?", .unknown)
    t("삼성전자 주가", .unknown)
    t("다음 주 날씨", .unknown)
    t("올해 노벨상 누가 받았어?", .unknown)
    t("요즘 유행하는 노래 뭐야", .unknown)
    t("내일 시험 문제 뭐 나와?", .unknown)
    t("버스 언제 와?", .unknown)
    t("근처 맛집 추천해줘", .unknown)
    t("오늘 로또 1등 번호", .unknown)
    t("넷플릭스 뭐 볼까", .light, none: ["혹시 **"])
    t("최신 영화 추천해줘", .light, any: ["몰라"])
    t("롤 티어 올리는 법", .light, none: ["혹시 **"])
    t("내 키 몇이야", .unknown)
    t("우리 반 1등 누구야", .unknown)
    t("이번 주 토요일에 비 와?", .unknown)
    t("지금 미국 몇 시야", any: ["미국", "몰라", "시차", "시"])
    t("오늘 코스피 얼마야", .unknown)
    t("엄마 지금 어디 있어?", .unknown)
    t("어제 무슨 일 있었는지 알아?", .unknown)

    // MARK: 오타·띄어쓰기
    cat = "오타·붙여쓰기"
    t("광합성이머야", .answer, any: ["광합성"])
    t("임진왜란언제야", .answer, any: ["1592"])
    t("피타고라스정리알려줘", .answer, any: ["피타고라스"])
    t("내일3시영어학원추가", .command, any: ["[ADD PLAN]"])
    t("오늘일정알려줘", .command, any: ["[OVERVIEW"])
    t("타이머30분", .command, any: ["[TIMER start - 30]"])
    t("수학퀴즈내줘", .quiz, any: ["퀴즈 1번"])
    t("apple뜻", any: ["사과"])
    t("공부하기시러", .light)
    t("피곤해ㅠㅠ", .light, any: ["피곤", "쉬", "잠", "휴식"])
    t("졸려죽겠다", .light, any: ["졸", "잠", "쉬", "스트레칭", "물"])
    t("광합성 이 뭐 야", .answer, any: ["광합성"])
    t("세포호흡이뭐야", .answer, any: ["호흡"])
    t("관계 대명사 알려줘", .answer, any: ["관계대명사", "관계 대명사"])
    t("현재 완료 설명", .answer, any: ["have"])
    t("미분 이 뭐야", .answer, any: ["미분"])
    t("기회 비용", .answer, any: ["기회비용", "기회 비용"])
    t("인플레 뭐임", .answer, any: ["인플레이션", "물가"])
    t("칸트 정언명령", .answer, any: ["정언"])
    t("산화환원반응", .answer, any: ["산화"])
    t("6.25전쟁 언제", .answer, any: ["1950"])
    t("삼일운동", .answer, any: ["3·1", "3.1", "1919"])
    t("뉴턴제2법칙", .answer, any: ["가속도", "F = ma", "F=ma"])
    t("옴의법칙", .answer, any: ["전압", "옴"])
    t("가정법과거", .answer, any: ["가정법"])
    t("to 부정사", .answer, any: ["to부정사", "to 부정사"])
    t("수동태가머임", .answer, any: ["수동태"])
    t("go과거형", any: ["went"])
    t("미토콘드리아가 머임", .answer, any: ["미토콘드리아"])
    t("세종대왕업적", .answer, any: ["훈민정음", "한글", "세종"])
    t("광합썽이 뭐야", any: ["광합성", "몰라", "?"])
    t("민주주의가머야?", .answer, any: ["민주주의"])
    t("인수분해머야", .answer, any: ["인수분해"])
    t("공부하기실타", .light)
    t("시험기간계획어떻게세워", .light, any: ["계획"])
    t("집중안돼", .light, any: ["집중"])

    // MARK: 이어 말하기
    cat = "이어 말하기"
    m(["광합성이 뭐야", "그럼 호흡은?"], any: ["호흡"])
    m(["임진왜란 언제야", "그럼 병자호란은?"], any: ["병자호란", "1636"])
    m(["프랑스 수도", "일본은?"], any: ["도쿄"])
    m(["go 과거형", "그럼 see는?"], any: ["saw"])
    m(["광합성이 뭐야", "더 쉽게 설명해줘"], any: ["광합성"])
    m(["관성이 뭐야", "예를 들면?"], any: ["관성"])
    m(["민주주의가 뭐야", "왜 중요해?"], any: ["민주주의", "중요"])
    m(["안녕", "광합성이 뭐야"], .answer, any: ["광합성"])
    m(["공부하기 싫어", "그래도 해야겠지?"], .light)
    m(["피곤해", "그래도 공부해야 돼"], .light)
    m(["내일 오후 4시 수학 공부 추가해줘", "그거 삭제해줘"], .command, any: ["[UPDATE delete 수학 공부]"])
    m(["오늘 일정 알려줘", "내일은?"], .command, any: ["[OVERVIEW 내일"])
    m(["광합성이 뭐야", "고마워"], .light, any: ["천만", "고마", "언제든", "별말", "도움"])
    m(["광합성이 뭐야", "음"], .light)
    m(["abundant 뜻", "예문 알려줘"], any: ["abundant"])
    m(["관계대명사 설명해줘", "예시 들어줘"], any: ["who", "which", "that", "관계대명사"])
    m(["세포 호흡이 뭐야", "그거 어디서 일어나?"], any: ["미토콘드리아"])
    m(["수학 퀴즈 내줘", "광합성이 뭐야"], any: ["광합성"], none: ["정답"])
    m(["영어 퀴즈 내줘", "오늘 일정 알려줘"], .command, any: ["[OVERVIEW"])
    m(["피곤해", "광합성이 뭐야"], .answer, any: ["광합성"])
    m(["칸트 정언명령 설명해줘", "공리주의랑 차이는?"], any: ["공리주의"])
    m(["뉴턴 제2법칙", "그럼 제3법칙은?"], any: ["작용", "반작용", "제3법칙"])
    m(["삼각형 넓이 구하는 법", "그럼 원은?"], any: ["원", "π", "반지름"])
    m(["안녕", "그거"], .clarify)
    m(["타이머 25분 시작", "멈춰"], any: ["[TIMER"])
    m(["광합성이 뭐야", "시험에 나와?"], any: ["광합성", "시험"])
    m(["광합성이 뭐야", "ㅋㅋ"], .light)
    m(["2x+3=11 풀어줘", "고마워"], .light, any: ["천만", "고마", "언제든", "별말", "도움"])
    m(["기회비용이 뭐야?", "예를 들면?"], any: ["기회비용"])
    m(["광합성이 뭐야", "다시 설명해줘"], any: ["광합성"])
    m(["피곤해", "그거"], .clarify)
    m(["x^2-5x+6=0 풀어줘", "그거 단계별로"], any: ["x = 2 또는 x = 3"], max: 1500)
    m(["오늘 일정 알려줘", "그럼 모레는?"], .command, any: ["[OVERVIEW 모레"])
    m(["수학 퀴즈 내줘", "그만", "광합성이 뭐야"], .answer, any: ["광합성"])
    m(["심심해", "퀴즈 내줘"], .quiz, any: ["퀴즈 1번"])

    // MARK: 새 말 (조정한 뒤에 따로 써 본 말: 특정 문장에 맞춘 게 아닌지 확인)
    cat = "새 말"
    t("안녕 두잇", .light, any: ["안녕", "반가"])
    t("오늘 기분 별로야", .light, any: ["힘들", "마음", "이야기", "괜찮"])
    t("머리 아파", .light, none: ["잘 몰라요"])
    t("오늘 너무 지친다", .light, any: ["힘들", "지칠", "쉬"])
    t("나 방금 시험 끝났어", .light, any: ["수고", "쉬"])
    t("공부할 맛이 안 나", .light, any: ["5분", "의욕", "1%", "시작"])
    t("짜증나 죽겠어", .light, any: ["호흡", "숨", "풀어"])
    t("너 뭐 할 줄 알아?", any: ["일정", "수학"], max: 1400)
    t("영어 단어가 안 외워져", .light, any: ["반복", "외우"], none: ["낱말"])
    t("엽록체가 뭐야", .answer, any: ["엽록체"])
    t("대동법이 뭐야", .answer, any: ["대동법"])
    t("흥선대원군 업적", .answer, any: ["흥선"])
    t("삼국통일 언제", .answer, any: ["676"])
    t("지구의 공전", .answer, any: ["공전"])
    t("pH가 뭐야", .answer, any: ["pH"])
    t("평행사변형 넓이", .answer, any: ["평행사변형"])
    t("산과 염기", .answer, any: ["산", "염기"])
    t("지진은 왜 일어나?", .answer, any: ["지진"])
    t("갑신정변 언제 일어났어", .answer, any: ["1884"])
    t("명예혁명", .answer, any: ["명예혁명", "1688"])
    t("비교 우위가 뭐야", .answer, any: ["비교 우위"])
    t("플라톤 이데아", .answer, any: ["플라톤", "이데아"])
    t("의성어 의태어 차이", .answer, any: ["의성어"])
    t("관형사가 뭐야", .answer, any: ["관형사"])
    t("receive 뜻", any: ["받다"])
    t("고양이 영어로", any: ["cat"])
    t("빠르다 영어로 뭐야", any: ["fast"])
    t("사랑하다 영어로", any: ["love"])
    t("see 과거분사", any: ["seen"])
    t("I am go to school 맞아?", any: ["going"])
    t("x^2+5x+6 인수분해", .math, any: ["(x+2)", "(x + 2)"], max: 1500)
    t("2x-7=3", .math, any: ["x = 5"], max: 1500)
    t("원의 둘레 반지름 5", .math, any: ["10π"], max: 1500)
    t("시험 3일 남았어", .light, any: ["3일"], none: ["1~1일차"])
    t("기말고사 한 달 남았어", .light, any: ["30일"])
    t("수행평가 준비 어떻게 해", .light, any: ["수행평가", "기준"])
    t("공부 계획 세워줘", .light, any: ["계획"], none: ["[ADD PLAN]"])
    t("새벽에 공부하는 거 괜찮아?", .light, any: ["잠", "자"])
    t("공부 시간 늘리는 법", .light, any: ["25분", "습관"])
    t("내일 아침 7시 영어 단어 외우기 추가", .command, all: ["[ADD PLAN]", "영어 단어"])
    t("매주 토요일 오후 3시 수학 과외 추가해줘", .command, all: ["[ADD PLAN] 수학 과외"])
    t("타이머 1시간 시작", .command, any: ["[TIMER start - 60]"])
    t("이번 주 공부 얼마나 했어", .command, any: ["[STATS 7]"])
    t("오늘 미세먼지 어때", .unknown)
    t("내일 날씨 알려줘", .unknown)
    t("요즘 핫한 게임 뭐야", .unknown, none: ["요즘핫한"])
    t("축구 누가 이겼어?", .unknown)
    t("우리 엄마 생일 언제야", .unknown)
    t("내 친구 생일 알아?", .unknown, any: ["친구"])
    t("선생님 몇 살이야?", .unknown, none: ["아기 AI"])
    t("내 MBTI 뭐야", .unknown)
    t("그거 말고", .clarify)
    t("아까 말한 거 다시", .clarify)
    t("이거 무슨 뜻이야", .clarify)
    t("??", .clarify)
    t("ㅇㅋㅇㅋ", .light)
    m(["광합성이 뭐야", "그럼 증산 작용은?"], .answer, any: ["증산"])
    m(["임진왜란 언제야", "누가 이겼어?"], any: ["임진왜란"], none: ["1592~1598년 설명해줘"])
    m(["2x+3=11", "x=5이면?"], any: ["해가 아니에요"])
    m(["세포 호흡이 뭐야", "광합성이랑 차이는?"], any: ["광합성"])
    m(["수학 퀴즈 내줘", "임진왜란 언제야?"], any: ["1592"])
    m(["피곤해", "근데 수학 숙제 해야 돼"], .light, any: ["타이머", "플래너"])
    m(["타이머 30분", "그만"], .command, any: ["[TIMER stop"])
    m(["관성이 뭐야", "예시 들어줘"], any: ["관성"])

    return list
}

@MainActor
func runChatRelevanceCases() async {
    let cases = buildRelevanceCases()
    var byCat: [String: (pass: Int, total: Int)] = [:]
    var order: [String] = []
    var failures: [String] = []
    var lengths: [(String, Int)] = []
    let assistant = DoitAssistant.shared
    for test in cases {
        assistant.reset()
        for input in test.inputs { await assistant.send(input) }
        let reply = assistant.messages.last?.role == .assistant ? (assistant.messages.last?.text ?? "") : ""
        let problem = relevanceProblem(test, reply)
        lengths.append((test.inputs.joined(separator: " → "), reply.contains("답:") ? 0 : reply.count))
        if byCat[test.cat] == nil { order.append(test.cat) }
        byCat[test.cat, default: (0, 0)].total += 1
        if problem == nil { byCat[test.cat, default: (0, 0)].pass += 1 }
        let shown = reply.prefix(200).replacingOccurrences(of: "\n", with: " / ")
        if let problem { failures.append("[\(test.cat)] \(test.inputs) → \(problem)\n      답: \(shown)") }
        check("대화 관련성 [\(test.cat)] \(test.inputs.joined(separator: " → "))", problem == nil, "\(problem ?? "") | 답: \(shown)")
    }
    assistant.reset()
    let passedCount = cases.count - failures.count
    let rate = Double(passedCount) / Double(max(1, cases.count)) * 100
    print("대화 관련성: \(passedCount)/\(cases.count) 통과 (\(String(format: "%.1f", rate))%)")
    for name in order {
        let s = byCat[name]!
        print("  · \(name): \(s.pass)/\(s.total)")
    }
    if ProcessInfo.processInfo.environment["RELEVANCE_VERBOSE"] != nil {
        for f in failures { print("  ✗ " + f) }
    }
    if let limit = ProcessInfo.processInfo.environment["RELEVANCE_LONG"].flatMap(Int.init) {
        for (input, count) in lengths where count > limit { print("  긴 답 \(count)자: \(input)") }
    }
}
