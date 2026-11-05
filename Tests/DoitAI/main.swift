import Foundation

// 모티 AI 엔진 테스트 모음
// - 대화(앱 명령 / 공부 질문 / 일상 대화 / 퀴즈 흐름)
// - 수학 풀이 정답, 문제 생성기 검증, 풀이 과정 채점, 사진 글자 교정, 지식 검색

var passed = 0
var failed: [String] = []

func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    if ok { passed += 1 } else { failed.append("✗ \(name)\n    \(detail())") }
}

// MARK: - 대화

struct ChatCase {
    let name: String
    let inputs: [String]
    var expect: [String] = []      // 마지막 답에 모두 있어야 함
    var reject: [String] = []      // 마지막 답에 없어야 함
    var expectAny: [String] = []   // 하나라도 있으면 됨
}

let chatCases: [ChatCase] = [
    // 앱 명령
    ChatCase(name: "오늘 일정", inputs: ["오늘 할 일 알려줘"], expect: ["[OVERVIEW"]),
    ChatCase(name: "플랜 추가", inputs: ["내일 오후 4시에 수학 공부 2시간 추가해줘"], expect: ["[ADD PLAN] 수학 공부", "time=오후 4시", "min=120"]),
    ChatCase(name: "플랜 추가 (요일)", inputs: ["금요일 오후 7시 영어 학원 추가"], expect: ["[ADD PLAN] 영어 학원", "date=금요일"]),
    ChatCase(name: "플랜 완료", inputs: ["수학 공부 완료했어"], expect: ["[UPDATE complete 수학 공부]"]),
    ChatCase(name: "플랜 삭제", inputs: ["영어 학원 삭제해줘"], expect: ["[UPDATE delete 영어 학원]"]),
    ChatCase(name: "타이머 시작", inputs: ["수학 50분 타이머 시작"], expect: ["[TIMER start 수학 50]"]),
    ChatCase(name: "타이머 이름에 '줄래' 안 붙음", inputs: ["타이머 25분 시작해줄래"], expect: ["[TIMER start - 25]"]),
    ChatCase(name: "타이머 종료", inputs: ["타이머 종료"], expect: ["[TIMER stop"]),
    ChatCase(name: "단어 추가", inputs: ["단어 추가: apple 사과, run 달리다"], expect: ["[ADD WORDS]", "apple", "run"]),
    ChatCase(name: "메모", inputs: ["메모해줘: 수행평가 준비물"], expect: ["메모 저장"]),
    ChatCase(name: "디데이", inputs: ["기말고사 D-Day 12월 10일로 설정해줘"], expect: ["[SETTINGS 기말고사 12월 10일"]),
    ChatCase(name: "목표", inputs: ["하루 공부 목표 4시간"], expect: ["240"]),
    ChatCase(name: "통계", inputs: ["이번 주 공부 통계"], expect: ["[STATS 7]"]),
    ChatCase(name: "주간 리포트", inputs: ["주간 리포트 보여줘"], expect: ["[WEEKLY REPORT]"]),
    // 잘못 가면 안 되는 말
    ChatCase(name: "현재완료는 플랜 완료가 아님", inputs: ["현재완료 설명해줘"], expect: ["have"], reject: ["[UPDATE"]),
    ChatCase(name: "열심히 했어는 플랜 체크 아님", inputs: ["나 오늘 공부 열심히 했어"], reject: ["[UPDATE"]),
    ChatCase(name: "기억이 지워져는 삭제 아님", inputs: ["기억이 자꾸 지워져"], reject: ["[UPDATE"]),
    ChatCase(name: "계획 세우는 법은 일정 보기 아님", inputs: ["계획 세우는 법 알려줘"], expect: ["계획"], reject: ["[OVERVIEW"]),
    ChatCase(name: "abundant 속 UN 오인 없음", inputs: ["abundant 뜻"], expect: ["풍부"], reject: ["국제 연합"]),
    ChatCase(name: "일차방정식 퀴즈 (좀)", inputs: ["일차방정식 문제좀 내줘"], expect: ["퀴즈 1번", "방정식"], reject: ["수도"]),
    ChatCase(name: "연습 문제", inputs: ["인수분해 연습 문제"], expect: ["퀴즈 1번", "인수분해"]),
    ChatCase(name: "문제 없이 풀어줘", inputs: ["이 문제 풀어줘"], expect: ["풀 문제를 보내주세요"]),
    ChatCase(name: "그만 (퀴즈 없음)", inputs: ["그만"], expect: ["알겠어요"]),
    ChatCase(name: "기억해줘", inputs: ["기억해줘: 내 목표 대학은 서울대"], expect: ["기억해 둘게요", "서울대"]),
    ChatCase(name: "배운 거 보여줘", inputs: ["기억해줘: 수학 시험은 금요일", "배운 거 보여줘"], expect: ["배운 내용", "금요일"]),
    ChatCase(name: "고쳐 주기", inputs: ["광합성이 뭐야?", "아니야, 광합성은 잎에서만 일어나는 게 아니야"], expect: ["기억해 둘게요"]),
    ChatCase(name: "아니야 괜찮아는 고치기 아님", inputs: ["광합성이 뭐야?", "아니야 괜찮아 고마워"], reject: ["기억해 둘게요"]),
    // 수학
    ChatCase(name: "일차방정식", inputs: ["2x+3=11"], expect: ["x = 4"]),
    ChatCase(name: "이차방정식", inputs: ["x²-5x+6=0 풀어줘"], expect: ["x = 2 또는 x = 3"]),
    ChatCase(name: "삼차방정식", inputs: ["x^3-6x^2+11x-6=0 풀어줘"], expect: ["x = 1, 2, 3"]),
    ChatCase(name: "연립방정식", inputs: ["x+y=5, x-y=1 풀어줘"], expect: ["x = 3, y = 2"]),
    ChatCase(name: "이차부등식", inputs: ["x^2-5x+6<0"], expect: ["2 < x < 3"]),
    ChatCase(name: "꼭짓점", inputs: ["y=x^2-4x+1 꼭짓점"], expect: ["(2, -3)"]),
    ChatCase(name: "접선", inputs: ["f(x)=x^2+3x x=1에서 접선"], expect: ["y = 5x − 1"]),
    ChatCase(name: "정적분", inputs: ["x^2+2x 0부터 3까지 적분"], expect: ["답: 18"]),
    ChatCase(name: "조합", inputs: ["7명 중 3명을 뽑는 경우의 수"], expect: ["35"]),
    ChatCase(name: "할인", inputs: ["10000원에서 20% 할인"], expect: ["8000"]),
    ChatCase(name: "특수각", inputs: ["sin 30°"], expect: ["1/2"]),
    ChatCase(name: "로그", inputs: ["log2 8"], expect: ["답: 3"]),
    ChatCase(name: "함숫값", inputs: ["f(x)=x^2 에 x=2를 넣어줘"], expect: ["f(2) = 4"]),
    ChatCase(name: "비슷한 문제", inputs: ["x^2-5x+6=0 풀어줘", "비슷한 문제 내줘"], expect: ["비슷한 문제 3개", "정답"]),
    ChatCase(name: "풀 수 있니", inputs: ["이차함수 문제 풀어줄수 있니"], expect: ["풀 수 있어요"]),
    // 영어 · 과학 · 사회
    ChatCase(name: "과거형", inputs: ["go 과거형"], expect: ["went"]),
    ChatCase(name: "문법 검사", inputs: ["He go to school 문법 맞아?"], expect: ["He goes to school."]),
    ChatCase(name: "숙어", inputs: ["look forward to 뜻"], expect: ["기대"]),
    ChatCase(name: "옴의 법칙", inputs: ["전압 12V 저항 4Ω 전류는?"], expect: ["3 A"]),
    ChatCase(name: "화학식량", inputs: ["H2SO4 몰질량"], expect: ["98"]),
    ChatCase(name: "역사", inputs: ["임진왜란 언제 일어났어?"], expect: ["1592"]),
    ChatCase(name: "수도", inputs: ["프랑스 수도"], expect: ["파리"]),
    ChatCase(name: "개념", inputs: ["기회비용이 뭐야?"], expect: ["포기"]),
    // 지식 검색 (설명으로 묻기)
    ChatCase(name: "설명으로 관성", inputs: ["물체가 원래 상태를 유지하려는 성질이 뭐야"], expect: ["관성"]),
    ChatCase(name: "설명으로 인플레이션", inputs: ["물건값이 계속 오르는 현상이 뭐야"], expect: ["인플레이션"]),
    ChatCase(name: "더 자세히", inputs: ["광합성이 뭐야", "더 자세히 알려줘"], expect: ["세포 호흡"]),
    // 일상 대화
    ChatCase(name: "인사", inputs: ["안녕"], expectAny: ["안녕하세요", "좋은 아침", "반가워요", "수고가 많아요"]),
    ChatCase(name: "공감 (힘들어)", inputs: ["너무 힘들어"], expectAny: ["힘들었", "지칠"]),
    ChatCase(name: "위기 신호", inputs: ["죽고 싶어"], expect: ["109", "1388"]),
    ChatCase(name: "집중 안 됨", inputs: ["집중이 안 돼"], expect: ["집중"]),
    ChatCase(name: "공부 시간 칭찬", inputs: ["오늘 3시간 공부했어"], expect: ["3시간"]),
    ChatCase(name: "점수 위로", inputs: ["나 수학 50점 받았어"], expect: ["50점"]),
    ChatCase(name: "시험까지", inputs: ["시험 2주 남았는데 뭐부터 해?"], expect: ["14일"]),
    ChatCase(name: "일정 제안", inputs: ["3시에 학원 가야 돼"], expect: ["학원", "추가"]),
    ChatCase(name: "이름 기억", inputs: ["내 이름은 민지야", "내 이름 뭐야?"], expect: ["민지"]),
    ChatCase(name: "기분 좋음은 칭찬 아님", inputs: ["오늘 기분 최고야"], reject: ["고마워요. 그래도 제일 대단한 건"]),
    ChatCase(name: "주사위", inputs: ["주사위 굴려줘"], expect: ["🎲"]),
    ChatCase(name: "골라줘", inputs: ["피자랑 치킨 중에 골라줘"], expectAny: ["피자", "치킨"]),
    ChatCase(name: "메뉴 추천", inputs: ["점심 메뉴 추천해줘"], expect: ["어때요"]),
    ChatCase(name: "날짜 계산", inputs: ["100일 뒤"], expect: ["100일 뒤는"]),
    ChatCase(name: "남은 날", inputs: ["크리스마스까지 며칠 남았어?"], expect: ["크리스마스까지"]),
    ChatCase(name: "나이", inputs: ["2009년생 몇 살이야"], expect: ["2009년생"]),
    ChatCase(name: "글자 수", inputs: ["글자수 세줘: 오늘은 수학을 공부했다"], expect: ["공백 포함 **12자**", "공백 빼고 **10자**"]),
    ChatCase(name: "모르는 질문은 솔직하게", inputs: ["우리 동네 떡볶이집 사장님 이름이 뭐야?"], expect: ["몰라요"]),
    ChatCase(name: "블랙홀 (교육과정 지식)", inputs: ["블랙홀이 뭐야?"], expect: ["블랙홀", "빛"]),
    ChatCase(name: "영어 인사", inputs: ["How are you?"], expect: ["(저는"]),
    ChatCase(name: "자기소개", inputs: ["너 누구야?"], expect: ["모티 AI"], reject: ["Apple"]),
    ChatCase(name: "공부 싫다", inputs: ["공부하기 너무 싫다"], expectAny: ["5분", "의욕", "1%"]),
    ChatCase(name: "시간 있는 단어 공부는 플랜", inputs: ["매일 오전 7시 영어 단어 30분 추가"], expect: ["[ADD PLAN] 영어 단어", "min=30"]),
    ChatCase(name: "문자 전개", inputs: ["(a+b)^2 전개"], expect: ["a² + 2ab + b²"]),
    ChatCase(name: "제곱 말로", inputs: ["2의 10제곱"], expect: ["1024"]),
    ChatCase(name: "제곱근 간단히", inputs: ["제곱근 50"], expect: ["5√2"]),
    ChatCase(name: "재밌는 사실", inputs: ["재밌는 사실 알려줘"], reject: ["좋은 일이 있었나"]),
    ChatCase(name: "N일 뒤 요일", inputs: ["오늘부터 30일 뒤 무슨 요일"], expect: ["30일 뒤는"]),
    ChatCase(name: "날짜 요일", inputs: ["2027년 1월 1일 무슨 요일"], expect: ["금요일"]),
    ChatCase(name: "수능 날짜 모름", inputs: ["수능까지 며칠"], expect: ["D-Day"]),
    ChatCase(name: "이유 질문은 솔직하게", inputs: ["비가 오는 이유"], expect: ["몰라요"]),
    // 퀴즈 흐름
    ChatCase(name: "퀴즈 시작·그만", inputs: ["수학 퀴즈 내줘", "그만"], expect: ["퀴즈를 마칠게요"]),
    ChatCase(name: "퀴즈 힌트", inputs: ["과학 퀴즈 내줘", "힌트"], expect: ["힌트"]),
    ChatCase(name: "퀴즈 포기하면 정답", inputs: ["사회 퀴즈 내줘", "모르겠어"], expect: ["정답:", "퀴즈 2번"]),
    ChatCase(name: "내 단어 퀴즈", inputs: ["내 단어로 퀴즈 내줘"], expect: ["퀴즈 1번", "내 단어장"]),
    ChatCase(name: "이걸로 퀴즈", inputs: ["기회비용이 뭐야?", "이걸로 퀴즈 내줘"], expect: ["퀴즈 1번"]),
    ChatCase(name: "퀴즈 중 다른 부탁", inputs: ["수학 퀴즈 내줘", "내일 오후 4시에 영어 공부 1시간 추가해줘"], expect: ["[ADD PLAN]"])
]

@MainActor
func runChat() async {
    for test in chatCases {
        let assistant = DoitAssistant.shared
        assistant.reset()
        for input in test.inputs { await assistant.send(input) }
        let reply = assistant.messages.last?.text ?? ""
        let ok = test.expect.allSatisfy { reply.contains($0) }
            && !test.reject.contains { reply.contains($0) }
            && (test.expectAny.isEmpty || test.expectAny.contains { reply.contains($0) })
        check("대화: \(test.name)", ok, "입력 \(test.inputs) → \(reply.prefix(240).replacingOccurrences(of: "\n", with: " / "))")
    }
    DoitConversation.userName = nil
}

// MARK: - 수학 풀이

let mathCases: [(String, String)] = [
    ("x^4-5x^2+4=0", "x = 1, -1, 2, -2"), ("6x^2+x-2 인수분해", "(2x − 1)(3x + 2)"), ("x^4+x^2+1 인수분해", "(x² − x + 1)(x² + x + 1)"),
    ("x^2-4x+4>0", "x ≠ 2인 모든 실수"), ("1<2x+3≤7", "-1 < x ≤ 2"), ("|x-2|<3", "-1 < x < 5"), ("|2x-1|≥5", "x ≤ -2 또는 x ≥ 3"),
    ("x+y+z=6, x-y+z=2, 2x+y-z=1", "x = 1, y = 2, z = 3"), ("f(x)=x^3-3x 극값", "극댓값 2"), ("3x^2-2x 적분", "x³ − x² + C"),
    ("f(x)=2x+1, g(x)=x^2 일 때 f(g(2))", "9"), ("f(x)=3x-6의 역함수", "(1/3)x + 2"), ("(2+3i)(1-i)", "5 + i"), ("i^2026", "-1"),
    ("5C2", "10"), ("6명이 원탁에 앉는 경우의 수", "120"), ("2 4 4 5 7 9 분산", "185/36"), ("12와 18의 최대공약수 최소공배수", "최대공약수 6, 최소공배수 36"),
    ("360 소인수분해", "2³ × 3² × 5"), ("30은 120의 몇 %", "25%"), ("두 점 (1,2) (4,6) 사이 거리", "5"), ("A(1,2) B(7,5)를 2:1로 내분", "(5, 4)"),
    ("x^2+y^2-4x+6y-3=0 중심 반지름", "중심 (2, -3), 반지름 4"), ("반지름 3인 원의 넓이", "9π"), ("육각형 내각의 합", "720°"),
    ("첫째항 3 공차 2인 등차수열 10번째 항", "21"), ("n(A)=10, n(B)=8, n(A∩B)=3 일때 n(A∪B)", "15"), ("x>0일 때 x+9/x 최솟값", "6"),
    ("x^2-3x+1=0 α²+β²", "7"), ("x^3-2x+1을 x-2로 나눈 나머지", "5"), ("y=x^2-2x 에서 0 ≤ x ≤ 3 최대 최소", "최댓값 3"),
    ("3+4i 켤레복소수", "3 − 4i"), ("cos 135도", "−√2/2"), ("log 1000", "3"), ("97 소수야?", "소수예요")
]

func runMath() {
    for (q, expected) in mathCases {
        let answer = MathSolver.solve(q)?.answer ?? "(풀지 못함)"
        check("수학: \(q)", answer.contains(expected), "답 \(answer) / 기대 \(expected)")
    }
    // 수학이 아닌 말은 풀지 않아야 함
    for q in ["오늘 할 일 알려줘", "안녕", "영어 단어 25분 타이머 시작해줘", "광합성이 뭐야"] {
        check("수학 아님: \(q)", MathSolver.solve(q) == nil, "\(String(describing: MathSolver.solve(q)?.answer))")
    }
}

// MARK: - 문제 생성기: 정답이 보기에 있고 번호가 맞는지 (각 유형 40번씩)

func runGenerators() {
    for topic in MathProblems.Topic.allCases {
        var bad = 0
        var example = ""
        for i in 0..<40 {
            let p = MathProblems.make(topic: topic, hard: i % 2 == 0)
            let ok = p.choices.count >= 2 && (1...p.choices.count).contains(p.answerNumber)
                && p.choices[p.answerNumber - 1] == p.finalAnswer && Set(p.choices).count == p.choices.count
            if !ok { bad += 1; example = "\(p.question) \(p.choices) → \(p.answerNumber) \(p.finalAnswer)" }
        }
        check("문제 생성: \(topic)", bad == 0, "\(bad)/40 잘못됨: \(example)")
    }
    // 계산 문제는 풀이 엔진으로 다시 풀어서 정답과 비교
    for topic in [MathProblems.Topic.linear, .quadraticEquation, .remainder, .system, .derivative] {
        var mismatch = 0
        var example = ""
        for _ in 0..<30 {
            let p = MathProblems.make(topic: topic, hard: false)
            guard let solved = MathSolver.solve(p.question) else { continue }
            let numbers = DoitMathTopics.numbers(in: solved.answer)
            let expected = Double(p.finalAnswer) ?? .nan
            if !expected.isNaN && !numbers.contains(where: { abs($0 - expected) < 1e-6 }) && topic != .system && topic != .quadraticEquation {
                mismatch += 1; example = "\(p.question) 생성 답 \(p.finalAnswer) / 풀이 답 \(solved.answer)"
            }
        }
        check("생성-풀이 일치: \(topic)", mismatch == 0, example)
    }
}

// MARK: - 풀이 과정 채점

func runWorkChecker() {
    let cases: [(String, [String], Int?, Bool?)] = [
        ("2x+3=11", ["2x = 11 - 3", "2x = 8", "x = 4"], nil, true),
        ("2x+3=11", ["2x = 11 + 3", "2x = 14", "x = 7"], 0, false),
        ("3(x-1)=2x+4", ["3x - 3 = 2x + 4", "3x - 2x = 4 - 3", "x = 1"], 1, false),
        ("x²-5x+6=0", ["(x-2)(x-3)=0", "x = 2 또는 x = 3"], nil, true),
        ("x²-5x+6=0", ["(x+2)(x+3)=0", "x = -2, -3"], 0, nil),
        ("x^2-4x+1=0", ["x = (4 ± √12)/2", "x = 2 ± √3"], nil, true),
        ("x+y=5, x-y=1", ["2x = 6", "x = 3", "y = 2"], nil, true),
        ("x+y=5, x-y=1", ["2x = 4", "x = 2", "y = 3"], 0, false),
        ("(x+1)(x-3) 전개", ["x^2 - 3x + x - 3", "= x^2 - 2x + 3"], 1, false)
    ]
    for (problem, work, wrong, final) in cases {
        let r = DoitWorkChecker.check(problem: problem, work: work)
        var ok = r.firstWrongIndex == wrong
        if let final { ok = ok && r.finalCorrect == final }
        check("채점: \(problem) \(work)", ok, "처음 틀린 줄 \(String(describing: r.firstWrongIndex)) / 최종 \(String(describing: r.finalCorrect)) / \(r.verdict)")
    }
    // 앞의 실수가 이어진 줄은 '이어짐'
    let carried = DoitWorkChecker.check(problem: "2x+3=11", work: ["2x = 14", "x = 7"])
    check("채점: 이어진 실수 표시", carried.lines.last?.mark == .carried, "\(carried.lines.map(\.mark))")
}

// MARK: - 사진 글자 교정

// MARK: - 단어장 사진: 예문은 빼고 단어·뜻만

func runWordParser() {
    func page(_ rows: [String]) -> [ParsedWord] {
        // 위에서 아래로 한 줄씩 (Vision 좌표는 아래가 0)
        let lines = rows.enumerated().map { i, text in OCRLine(text: text, box: CGRect(x: 0.05, y: 0.95 - Double(i) * 0.04, width: 0.9, height: 0.03)) }
        return WordParser.parse(lines)
    }
    let words = page([
        "1. brave 용감한",
        "She was brave enough to speak.",
        "그녀는 말할 만큼 충분히 용감했다.",
        "2. give up 포기하다, 그만두다",
        "e.g. Don't give up!",
        "3. abundant adj. 풍부한 There is abundant water here.",
        "4. exact 정확한",
        "5. a lot of 많은",
        "6. example 예, 보기",
        "Ex) I love apples.",
        "나는 사과를 좋아해요.",
        "7. resilient",
        "회복력 있는"
    ])
    let terms = words.map(\.term)
    check("단어장: 단어만 (예문 제외)", terms == ["brave", "give up", "abundant", "exact", "a lot of", "example", "resilient"], "\(terms)")
    check("단어장: 뜻에 예문·해석이 섞이지 않음", words.first { $0.term == "brave" }?.meaning == "용감한"
          && words.first { $0.term == "abundant" }?.meaning == "풍부한"
          && words.first { $0.term == "give up" }?.meaning == "포기하다, 그만두다", "\(words.map { "\($0.term)=\($0.meaning)" })")
    check("단어장: 세로형(뜻이 다음 줄)", words.first { $0.term == "resilient" }?.meaning == "회복력 있는")
    // 시중 단어장 (사진 속 화면처럼: 예시 구 + 해석 + [발음] + 품사 뜻 + 표제어, 파생어, 쪽수)
    let book = page([
        "throughout the whole continent 전 대륙 전역에서",
        "(kántənənt] 명 대륙 continent",
        "in an instant 곧, 당장, 즉시 / instantly 부 즉각, 즉시",
        "instant rewards 즉각적인 보상",
        "바로 그 순간에 불이 꺼졌다.",
        "instant [ínstənt] 형 즉각적인 명 순간",
        "employee 명 종업원, 직원 / employer 명 고용주",
        "employ a new method 새로운 방법을 이용하다",
        "employ [implɔ́i] 동 고용하다, 이용하다",
        "involve 동] 참여하다, 관여하다 / involving (형 ~을 포함하는",
        "without human involvement 인간의 개입 없이",
        "[invɑ́lvmənt] ㄱ, 명 참여, 관여 involvement",
        "an arrogant attitude 오만한 태도",
        "[ǽrəgənt] 형 오만한 arrogant 272",
        "a best-selling author 베스트셀러 작가",
        "[5:0or] 명 작가, 저자 author"
    ])
    let bookTerms = book.map(\.term)
    check("단어장(책): 표제어만", Set(bookTerms) == ["continent", "instantly", "instant", "employee", "employer", "employ", "involve", "involving", "involvement", "arrogant", "author"], "\(bookTerms)")
    func meaning(_ t: String) -> String { book.first { $0.term == t }?.meaning ?? "-" }
    check("단어장(책): 뜻에 발음·쪽수·예문 없음", meaning("continent") == "대륙" && meaning("arrogant") == "오만한" && meaning("author") == "작가, 저자"
          && meaning("instant") == "즉각적인, 순간" && meaning("involvement") == "참여, 관여" && meaning("employ") == "고용하다, 이용하다",
          "\(book.map { "\($0.term)=\($0.meaning)" })")
    let usual = page(["continent [kántənənt] 명 대륙", "throughout the whole continent 전 대륙 전역에서", "author", "[ɔ́:θər] 명 작가, 저자", "a best-selling author 베스트셀러 작가"])
    check("단어장(책): 흔한 배치·표제어만 한 줄", usual.map(\.term) == ["continent", "author"] && usual.first?.meaning == "대륙" && usual.last?.meaning == "작가, 저자",
          "\(usual.map { "\($0.term)=\($0.meaning)" })")
    check("단어장(책): 예시 구는 단어가 아님", !bookTerms.contains { $0.contains(" ") })
    // 두 단 페이지: 왼쪽 단과 오른쪽 단이 같은 높이에 나란히 → 한 줄로 섞이면 안 됨
    var twoColumn: [OCRLine] = []
    let leftRows = ["1. brave 용감한", "2. exact 정확한", "3. resilient 회복력 있는", "4. abundant 풍부한"]
    let rightRows = ["5. author 작가", "6. employ 고용하다", "7. involve 참여하다", "8. arrogant 오만한"]
    for (i, text) in leftRows.enumerated() { twoColumn.append(OCRLine(text: text, box: CGRect(x: 0.05, y: 0.9 - Double(i) * 0.08, width: 0.38, height: 0.03))) }
    for (i, text) in rightRows.enumerated() { twoColumn.append(OCRLine(text: text, confidence: i == 2 ? 0.3 : 1, box: CGRect(x: 0.55, y: 0.9 - Double(i) * 0.08, width: 0.38, height: 0.03))) }
    let columns = WordParser.parse(twoColumn)
    check("단어장: 두 단 페이지는 단마다", columns.map(\.term) == ["brave", "exact", "resilient", "abundant", "author", "employ", "involve", "arrogant"]
          && columns.first { $0.term == "brave" }?.meaning == "용감한" && columns.first { $0.term == "author" }?.meaning == "작가",
          "\(columns.map { "\($0.term)=\($0.meaning)" })")
    check("단어장: 흐리게 읽힌 줄은 확인 필요", columns.first { $0.term == "involve" }?.unsure == true && columns.first { $0.term == "brave" }?.unsure == false)
    // "영어 | 한글" 두 칸 표는 나누지 않음
    var table: [OCRLine] = []
    for (i, pair) in [("apple", "사과"), ("banana", "바나나"), ("cherry", "체리"), ("grape", "포도")].enumerated() {
        table.append(OCRLine(text: pair.0, box: CGRect(x: 0.1, y: 0.9 - Double(i) * 0.08, width: 0.25, height: 0.03)))
        table.append(OCRLine(text: pair.1, box: CGRect(x: 0.6, y: 0.9 - Double(i) * 0.08, width: 0.2, height: 0.03)))
    }
    let tableWords = WordParser.parse(table)
    check("단어장: 영어|한글 표는 한 단", tableWords.map(\.term) == ["apple", "banana", "cherry", "grape"] && tableWords.last?.meaning == "포도",
          "\(tableWords.map { "\($0.term)=\($0.meaning)" })")
    check("단어 철자 교정: 숫자 섞임", WordParser.fixOCRTerm("app1e") == "apple" && WordParser.fixOCRTerm("c0ntinent") == "continent"
          && WordParser.fixOCRTerm("5mall") == "small" && WordParser.fixOCRTerm("272") == "272" && WordParser.fixOCRTerm("3D") == "3D",
          WordParser.fixOCRTerm("app1e"))
    check("예문 판별", WordParser.isExampleSentence("He has been to Paris.") && !WordParser.isExampleSentence("take care of") && !WordParser.isExampleSentence("Take care of"))
}

func runWordReview() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 21))!
    func days(_ date: Date?) -> Int? {
        date.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: $0).day ?? -1 }
    }
    let first = WordReview.afterLearning(now: now, calendar: calendar)
    check("복습: 외운 다음 날 첫 복습", first.stage == 1 && days(first.next) == 1)
    var stage = 1
    var gaps: [Int] = []
    for _ in 0..<4 {
        let next = WordReview.afterReview(stage: stage, correct: true, now: now, calendar: calendar)
        stage = next.stage
        gaps.append(days(next.next) ?? -1)
    }
    check("복습: 맞히면 3·7·14·30일 간격", gaps == [3, 7, 14, 30], "\(gaps)")
    let done = WordReview.afterReview(stage: 5, correct: true, now: now, calendar: calendar)
    check("복습: 30일 복습까지 통과하면 완전히 외움", done.stage == WordReview.mastered && done.next == nil)
    let wrong = WordReview.afterReview(stage: 4, correct: false, now: now, calendar: calendar)
    check("복습: 틀리면 1일 뒤부터 다시", wrong.stage == 1 && days(wrong.next) == 1)
    check("복습: 날짜가 되면 복습 차례", WordReview.isDue(stage: 2, next: now.addingTimeInterval(-60), now: now)
          && !WordReview.isDue(stage: 2, next: now.addingTimeInterval(3600 * 5), now: now)
          && !WordReview.isDue(stage: 0, next: nil, now: now) && !WordReview.isDue(stage: WordReview.mastered, next: nil, now: now))
    check("복습: 날짜 말하기", WordReview.describe(first.next!, now: now, calendar: calendar) == "내일")
}

func runOCRFixer() {
    let cases: [(String, String)] = [
        ("Zx + 3", "2x + 3"), ("xZ - 5x + 6 = 0", "x² - 5x + 6 = 0"), ("x^Z+1", "x^2+1"), ("1O+5", "10+5"), ("3l4", "314"),
        ("0x²+6x+c=0", "ax²+6x+c=0"), ("실수 06에 대하여", "실수 ab에 대하여"), ("2×+3=7", "2x+3=7"), ("x'+2x+1", "x²+2x+1"),
        ("x?-5x+6=0", "x²-5x+6=0"), ("x9 - 5x + 6 = 0", "x² - 5x + 6 = 0"), ("복소수 2 = 3+4i 일 때", "복소수 z = 3+4i"),
        ("J= 2x", "y= 2x"), ("x2+y2=25", "x²+y²=25")
    ]
    for (input, expected) in cases {
        let fixed = MathOCRFixer.fix(input)
        check("글자 교정: \(input)", fixed.contains(expected), "결과 \(fixed) / 기대 \(expected)")
    }
    // 분수: 분자 "1"(위) / 분모 "2"(아래), 그 사이 높이에 "x = 일 때" 줄
    let line = CGRect(x: 0.1, y: 0.50, width: 0.6, height: 0.04)
    let fractions = MathOCRFixer.stackedFractions(pieces: [("1", CGRect(x: 0.3, y: 0.535, width: 0.02, height: 0.03)),
                                                           ("2", CGRect(x: 0.3, y: 0.475, width: 0.02, height: 0.03))], hosts: [line])
    check("분수 조각 합치기", fractions.first?.text == "1/2" && fractions.first?.host == 0, "\(fractions)")
    let fractionAB = MathOCRFixer.stackedFractions(pieces: [("x+1", CGRect(x: 0.3, y: 0.535, width: 0.05, height: 0.03)),
                                                            ("3", CGRect(x: 0.31, y: 0.475, width: 0.02, height: 0.03))], hosts: [line])
    check("분수 조각: 괄호", fractionAB.first?.text == "(x+1)/3", "\(fractionAB)")
    // 문제 번호처럼 위아래로 떨어진 숫자 (사이에 문장 줄 없음) → 분수 아님
    let notFraction = MathOCRFixer.stackedFractions(pieces: [("1", CGRect(x: 0.02, y: 0.80, width: 0.02, height: 0.03)),
                                                             ("2", CGRect(x: 0.02, y: 0.76, width: 0.02, height: 0.03))], hosts: [line])
    check("분수 아님: 사이에 줄 없음", notFraction.isEmpty)
    // 바뀌면 안 되는 것
    for keep in ["x=0", "10x+3", "0.6x", "f(x)=2x+1", "z = 1+2i", "2x + 9 = 0"] {
        check("글자 교정 유지: \(keep)", MathOCRFixer.fix(keep) == keep, MathOCRFixer.fix(keep))
    }
}

// MARK: - 지식 검색

func runKnowledge() {
    let cases: [(String, String)] = [
        ("물체가 원래 상태를 유지하려는 성질", "관성"), ("물가가 계속 오르는 현상", "인플레이션"), ("광합성", "광합성"),
        ("관계대명사", "관계대명사"), ("인수분해", "인수분해"), ("수요 공급", "수요")
    ]
    for (q, expected) in cases {
        let top = DoitKnowledge.search(q, limit: 1).first?.entry.title ?? "(없음)"
        check("지식 검색: \(q)", top.contains(expected), "1위 \(top)")
    }
    check("지식 사전 크기", DoitKnowledge.entries.count >= 150, "\(DoitKnowledge.entries.count)개")
}

// MARK: - 두뇌 (기기 안 언어 모델) 주변 — 모델 없이 검사할 수 있는 부분

@MainActor
func runBrain() {
    // 생각 과정 거르기: 조각으로 나뉘어 와도
    var filter = ThinkFilter()
    let pieces = ["<thi", "nk>속으로 생각</th", "ink>\n\n광합성은 ", "빛으로 양분을 만드는 <", "일이에요."]
    let streamed = pieces.map { filter.feed($0) }.joined()
    check("생각 과정 거르기", streamed.trimmingCharacters(in: .whitespacesAndNewlines) == "광합성은 빛으로 양분을 만드는 <일이에요.", streamed)
    // Qwen3.5 생각 모드: 대화 형식이 '<think>'를 미리 넣어서 모델 글은 생각부터 나오고 '</think>'로 끝남
    var prefilled = ThinkFilter(startsInThink: true)
    let prefilledOut = ["Thinking Process:\n1. 분석", "…</thi", "nk>\n\n빛 에너지로 ", "양분을 만들어요."].map { prefilled.feed($0) }.joined()
    check("생각 과정 거르기: <think>가 미리 들어간 경우", prefilledOut.trimmingCharacters(in: .whitespacesAndNewlines) == "빛 에너지로 양분을 만들어요.", prefilledOut)
    var plain = ThinkFilter()
    check("생각 태그 없을 때 그대로", plain.feed("a < b 이고 ") + plain.feed("b > c") == "a < b 이고 b > c")

    // 답 다듬기·검사
    check("답 다듬기", DoitMind.clean("<think>\n</think>\n\n모티: ### 핵심\n- 하나\n- 둘") == "**핵심**\n• 하나\n• 둘", DoitMind.clean("<think>\n</think>\n\n모티: ### 핵심\n- 하나\n- 둘"))
    let fluffy = "좋은 질문이에요! 광합성은 식물이 빛으로 양분을 만드는 과정이에요.\n엽록체에서 일어나요.\n\n**요약**\n• 빛 → 양분\n\n더 궁금한 게 있으면 언제든 물어봐 주세요!"
    check("군더더기 빼기: 칭찬·요약·끝인사", DoitMind.answer(fluffy) == "광합성은 식물이 빛으로 양분을 만드는 과정이에요.\n엽록체에서 일어나요.", DoitMind.answer(fluffy))
    let conclusion = "물은 100도에서 끓어요.\n결론적으로, 물은 100도에서 끓는다는 거예요."
    check("군더더기 빼기: 결론 문장", DoitMind.answer(conclusion) == "물은 100도에서 끓어요.", DoitMind.answer(conclusion))
    check("군더더기 빼기: 본문은 그대로", DoitMind.answer("정리는 물건을 제자리에 두는 거예요.") == "정리는 물건을 제자리에 두는 거예요."
          && DoitMind.answer("• 하나\n• 둘") == "• 하나\n• 둘")
    check("추론 질문 판별", DoitMind.needsReasoning("왜 하늘은 파란색이야?") && !DoitMind.needsReasoning("안녕 반가워"))
    check("한자로 샌 답은 버림", !DoitMind.isUsable("光合作用是植物利用光能的过程，这个很重要。"))
    check("되풀이하는 답은 버림", !DoitMind.isUsable("좋아요 정말 좋아요. 좋아요 정말 좋아요. 좋아요 정말 좋아요. 끝"))
    check("정상 답은 통과", DoitMind.isUsable("광합성은 식물이 빛 에너지로 포도당을 만드는 과정이에요."))

    // 검색어 만들기
    check("검색어: 뭐야", DoitWeb.searchQuery(from: "광합성이 뭐야?") == "광합성", DoitWeb.searchQuery(from: "광합성이 뭐야?"))
    check("검색어: 왜", DoitWeb.searchQuery(from: "임진왜란은 왜 일어났어") == "임진왜란 원인", DoitWeb.searchQuery(from: "임진왜란은 왜 일어났어"))
    check("검색어: 인터넷에서 찾아줘", DoitWeb.searchQuery(from: "블랙홀 인터넷에서 찾아줘") == "블랙홀", DoitWeb.searchQuery(from: "블랙홀 인터넷에서 찾아줘"))

    // 인터넷을 찾아볼지
    check("모르는 질문은 인터넷", DoitMind.shouldSearchWeb(question: "양자 얽힘이 뭐야?", bestKnowledgeScore: 0.2, hasMemory: false, disliked: false))
    check("아는 개념은 인터넷 안 감", !DoitMind.shouldSearchWeb(question: "광합성이 뭐야?", bestKnowledgeScore: 0.9, hasMemory: false, disliked: false))
    check("인사는 인터넷 안 감", !DoitMind.shouldSearchWeb(question: "안녕 뭐해?", bestKnowledgeScore: 0, hasMemory: false, disliked: false))
    check("찾아달라면 인터넷", DoitMind.shouldSearchWeb(question: "광합성 검색해줘", bestKnowledgeScore: 0.9, hasMemory: true, disliked: false))
    check("👎 받은 주제는 다시 찾음", DoitMind.shouldSearchWeb(question: "광합성", bestKnowledgeScore: 0.9, hasMemory: true, disliked: true))

    // 근거가 프롬프트에 들어가는지
    var context = DoitMind.Context()
    context.knowledge = DoitKnowledge.search("광합성", limit: 1).map(\.entry)
    context.web = [DoitWeb.Source(title: "광합성", url: "https://ko.wikipedia.org/wiki/광합성", text: "광합성은 빛 에너지를 화학 에너지로 바꾸는 과정이다.", language: "ko")]
    let prompt = DoitMind.answerPrompt(question: "광합성이 뭐야?", context: context, history: [DoitMind.Turn(fromUser: true, text: "안녕")])
    check("프롬프트: 참고 자료·이전 대화·질문", prompt.contains("[참고 자료]") && prompt.contains("위키백과") && prompt.contains("학생: 안녕") && prompt.contains("[질문]\n광합성이 뭐야?"), prompt)
    check("출처 표시", context.sourceLabels.contains { $0.contains("위키백과(한국어) 「광합성」") }, "\(context.sourceLabels)")

    // 일반 인터넷 검색: DuckDuckGo 결과 읽기 (html 형식)
    let ddgHTML = """
    <div class="result results_links result--ad"><a rel="nofollow" class="result__a" href="https://duckduckgo.com/y.js?ad_domain=shop.com">광고 상품</a></div>
    <div class="result results_links"><h2 class="result__title"><a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fwww.example.org%2Fphoto%3Fid%3D1&amp;rut=abc">광합성 <b>원리</b> &amp; 과정</a></h2>
    <a class="result__snippet" href="x">식물이 <b>빛</b>으로 양분을 만드는 과정이에요.</a></div>
    <div class="result"><a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fblog.naver.com%2Fsci%2F123&amp;rut=x">네이버 블로그 글</a>
    <a class="result__snippet" href="y">엽록체에서 일어나요</a></div>
    <div class="result"><a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=http%3A%2F%2Finsecure.com%2F&amp;rut=x">http 사이트</a></div>
    """
    let ddg = DoitWeb.parseDuckDuckGo(ddgHTML)
    check("웹 검색 결과 읽기 (광고·http 제외)", ddg.count == 2 && ddg.first?.title == "광합성 원리 & 과정" && ddg.first?.url == "https://www.example.org/photo?id=1",
          "\(ddg)")
    check("웹 검색 스니펫", ddg.first?.snippet == "식물이 빛 으로 양분을 만드는 과정이에요." || ddg.first?.snippet == "식물이 빛으로 양분을 만드는 과정이에요.", ddg.first?.snippet ?? "")
    check("네이버 블로그는 모바일 주소로", ddg.last?.url == "https://m.blog.naver.com/sci/123", ddg.last?.url ?? "")
    check("사이트 이름", ddg.last?.site == "네이버 블로그" && ddg.first?.site == "example.org", "\(ddg.map(\.site))")
    // lite 형식
    let lite = DoitWeb.parseDuckDuckGo("""
    <tr><td><a rel="nofollow" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fnamu.wiki%2Fw%2Fabc&amp;rut=1" class='result-link'>블랙홀 - 나무위키</a></td></tr>
    <tr><td class='result-snippet'>중력이 매우 강한 천체</td></tr>
    """)
    check("웹 검색 결과 읽기 (lite 형식)", lite.count == 1 && lite[0].site == "나무위키" && lite[0].snippet == "중력이 매우 강한 천체", "\(lite)")
    check("읽지 않을 페이지", !DoitWeb.isUseful("https://www.youtube.com/watch?v=1") && !DoitWeb.isUseful("https://a.com/file.pdf") && DoitWeb.isUseful("https://namu.wiki/w/x"))
    // 페이지 본문 고르기
    let page = """
    <html><head><title>광합성</title><script>var ignore = "광합성 스크립트 내용이 여기에 길게 들어 있어요 무시해야 해요";</script><style>.a{}</style></head>
    <body><nav><a>홈</a> | <a>과학</a> | <a>로그인</a></nav>
    <p>광합성은 식물이 빛 에너지를 이용해 이산화 탄소와 물로 포도당을 만드는 과정이에요.</p>
    <div>오늘의 인기 글 목록과 추천 게시물을 확인해 보세요 여기는 광고 영역</div>
    <p>이 과정은 잎의 엽록체에서 일어나며 부산물로 산소가 나와요. &lt;중요&gt; &#54620;&#44544;도 풀려요.</p>
    <footer>Copyright 2026 All rights reserved 무단 전재 금지 광합성 사이트</footer></body></html>
    """
    let body = DoitWeb.readableText(page, query: "광합성", maxChars: 600)
    check("페이지 본문 고르기", body.contains("포도당") && !body.contains("스크립트") && !body.contains("Copyright") && !body.contains("로그인"), body)
    check("HTML 기호 풀기", body.contains("<중요>") && body.contains("한글도"), body)
    check("웹 자료 출처 표시", DoitWeb.Source(title: "블랙홀", url: "https://namu.wiki/w/x", text: "t", language: "web", site: "나무위키").label == "나무위키 「블랙홀」")

    // AI 학습 형식 읽기
    let scopeForParse = StudyScope(level: .middle, subject: "과학", subjectName: "중학교 과학", unit: "광합성", sources: [])
    let concept = DoitStudy.parseConcept("""
    핵심 개념: 광합성은 식물이 빛 에너지로 양분을 만드는 과정이에요.
    상세 설명:
    - 엽록체에서 일어나요.
    학습 포인트:
    - 식물이 빛 에너지로 양분을 만드는 과정이에요.
    - 이산화 탄소와 물이 필요해요.
    예제: 햇빛을 받은 잎에서 녹말이 만들어져요.
    """, scope: scopeForParse)
    check("개념 정리 읽기", concept?.summary.contains("광합성") == true && concept?.keyPoints.count == 2 && concept?.details.count == 1 && concept?.example.contains("녹말") == true, "\(String(describing: concept))")
    check("개념 정리: 형식이 틀리면 버림", DoitStudy.parseConcept("광합성은 좋은 것이에요.", scope: scopeForParse) == nil)

    let ox = DoitMind.parseOX("""
    1. O | 광합성은 엽록체에서 일어난다. | 맞아요.
    X | 광합성에는 산소가 원료로 필요하다. | 산소는 만들어지는 물질이에요.
    아무 말
    """)
    check("O/X 읽기", ox?.items.count == 2 && ox?.items.first?.isTrue == true && ox?.items.last?.isTrue == false, "\(String(describing: ox))")

    let cloze = DoitMind.parseCloze("""
    광합성은 (   )에서 일어나요. | 엽록체
    광합성의 결과 산소가 나와요. | 산소
    정답이 그대로 남은 엽록체 문장 (   ) | 엽록체
    """)
    check("빈칸 읽기", cloze?.items.count == 2 && cloze?.items[1].sentence == "광합성의 결과 (   )가 나와요.", "\(String(describing: cloze))")

    let problems = DoitMind.parseProblems("""
    문제: 광합성이 일어나는 곳은?
    1) 미토콘드리아
    2) 엽록체
    3) 핵
    4) 리보솜
    5) 세포막
    정답: 2
    해설: 엽록체에 엽록소가 있어요.

    문제: 보기가 모자란 문제
    1) 가
    2) 나
    정답: 1
    """)
    check("객관식 읽기 (모자란 문제는 버림)", problems?.items.count == 1 && problems?.items.first?.answerNumber == 2 && problems?.items.first?.finalAnswer == "2번 엽록체", "\(String(describing: problems))")

    // 기억 떠올리기
    let notes = [
        DoitMemory.Note(kind: .learned, topic: "블랙홀", summary: "중력이 아주 커서 빛도 빠져나오지 못하는 천체예요."),
        DoitMemory.Note(kind: .userFact, topic: "내 시험 범위", summary: "기말고사 범위는 3단원부터 5단원까지"),
        DoitMemory.Note(kind: .learned, topic: "광합성", summary: "식물이 빛으로 양분을 만드는 과정", score: -2)
    ]
    check("기억: 비슷한 주제", DoitMemory.rank(notes, for: "블랙홀이 뭐야?").first?.topic == "블랙홀")
    check("기억: 사용자 사실", DoitMemory.rank(notes, for: "내 시험 범위 알려줘").first?.topic == "내 시험 범위")
    check("기억: 👎 많이 받은 건 안 씀", DoitMemory.rank(notes, for: "광합성").isEmpty)
    check("기억 자르기", DoitMemory.trimmed(String(repeating: "가나다라요. ", count: 50), max: 40).hasSuffix("요."))

    // 두뇌가 없을 때는 규칙형 엔진 그대로 (테스트 환경)
    check("테스트 환경에서는 두뇌 꺼짐", !DoitBrain.shared.isAvailable)
}

// MARK: - 교육과정 단원 (AI 학습) — 모든 단원에서 검증된 자료가 나오는지

func runCurriculum() async {
    var units = 0
    var failures: [String] = []
    var noProblem: [String] = []
    for item in DoitCurriculum.studySubjects {
        for unit in item.units {
            units += 1
            let subject = item.name
            do {
                let note = try await DoitTutor.concept(subject: subject, unit: unit, booster: false)
                if note.keyPoints.isEmpty || note.checks.isEmpty { failures.append("\(item.name)/\(unit): 개념 비어 있음") }
            } catch { failures.append("\(item.name)/\(unit): 개념 \(error.localizedDescription.prefix(40))") }
            if (try? await DoitTutor.ox(subject: subject, unit: unit, count: 4))?.items.isEmpty ?? true { failures.append("\(item.name)/\(unit): O/X") }
            if (try? await DoitTutor.cloze(subject: subject, unit: unit, count: 4))?.items.isEmpty ?? true { failures.append("\(item.name)/\(unit): 빈칸") }
            if (try? await DoitTutor.problems(subject: subject, unit: unit, count: 3, hard: false)) == nil { noProblem.append("\(item.name)/\(unit)") }
        }
    }
    check("교육과정 단원 수", units >= 150, "\(units)개")
    check("모든 단원에서 개념·O/X·빈칸 생성 (검증 통과)", failures.count <= units / 20, "\(failures.count)곳 실패: " + failures.prefix(12).joined(separator: " | "))
    // 객관식은 개념이 둘뿐이고 서로 얽힌 단원만 못 만들 수 있음 (다른 단원 개념을 끌어오지 않으려고)
    check("객관식을 못 만드는 단원은 아주 적음", noProblem.count <= units / 12, "\(noProblem.count)곳: " + noProblem.prefix(10).joined(separator: " | "))
    let mixed = DoitKnowledge.entries(inUnit: "문장의 짜임", subject: "초등 국어").filter { $0.level != .elementary }
    check("같은 단원 이름이라도 학교급 구분", mixed.isEmpty && !DoitKnowledge.entries(inUnit: "문장의 짜임", subject: "초등 국어").isEmpty, "\(mixed.map(\.title))")
    let levels = Set(DoitCurriculum.studySubjects.map(\.level))
    check("초등~대학교 모두 있음", levels.count == SchoolLevel.allCases.count, "\(levels)")
    // 공통과목 단원이 가리키는 교육과정 단원이 실제로 있는지
    for (unit, refs) in DoitStudy.commonSources {
        for ref in refs {
            check("공통과목 자료 단원: \(unit) → \(ref.unit)", DoitStudy.catalog.contains { $0.level == ref.level && $0.unit == ref.unit && !$0.subjectName.hasPrefix("공통") })
        }
    }
    for alias in DoitStudy.unitAliases {
        check("단원 별명: \(alias.alias) → \(alias.unit)", DoitStudy.catalog.contains { $0.level == alias.level && $0.subject == alias.subject && $0.unit == alias.unit })
    }
}

// MARK: - AI 학습: 입력 분석 → 단원 범위 → 섞임 없는 자료 → 검증

func resolved(_ subject: String, _ unit: String) -> StudyScope? {
    if case .resolved(let scope) = DoitStudy.resolve(subject: subject, unit: unit) { return scope }
    return nil
}

func runStudy() async {
    // 1) 직접 입력 분석
    let s1 = resolved("", "중3 수학 이차방정식의 풀이")
    check("입력: 중3 수학 이차방정식의 풀이", s1?.subjectName == "중학교 수학" && s1?.unit == "이차방정식" && s1?.grade == 3 && s1?.subtopic == "풀이", "\(String(describing: s1))")
    let s2 = resolved("", "수학 이차방정식")
    check("입력: 수학 이차방정식", s2?.subjectName == "중학교 수학" && s2?.unit == "이차방정식", "\(String(describing: s2))")
    let s3 = resolved("", "고등학교 통합과학 생명 시스템")
    check("입력: 통합과학 생명 시스템 → 세포와 유전", s3?.subjectName == "고등학교 과학" && s3?.unit == "세포와 유전" && s3?.inputName != nil, "\(String(describing: s3))")
    let s4 = resolved("", "중학교 2학년 역사 삼국의 성립과 발전")
    check("입력: 중2 역사 삼국의 성립과 발전", s4?.subjectName == "중학교 사회" && s4?.unit == "삼국의 성립과 발전" && s4?.grade == 2, "\(String(describing: s4))")
    let s5 = resolved("공통수학1", "복소수와 이차방정식")
    check("목록에서 고른 단원", s5?.subjectName == "공통수학1" && s5?.unit == "복소수와 이차방정식" && s5?.usesMathEngine == true, "\(String(describing: s5))")
    if case .ambiguous(let options) = DoitStudy.resolve(subject: "국어", unit: "문장의 짜임") {
        check("모호한 입력은 골라 달라고 함", options.count >= 2 && Set(options.map(\.subjectName)).count == options.count, "\(options.map(\.label))")
    } else { check("모호한 입력은 골라 달라고 함", false, "\(DoitStudy.resolve(subject: "국어", unit: "문장의 짜임"))") }
    if case .resolved(let scope) = DoitStudy.resolve(subject: "초등 국어", unit: "문장의 짜임") {
        check("학교급을 적으면 하나로", scope.level == .elementary, scope.label)
    } else { check("학교급을 적으면 하나로", false) }
    if case .notFound = DoitStudy.resolve(subject: "수학", unit: "") { check("단원 없이 과목만", true) } else { check("단원 없이 과목만", false) }
    if case .notFound = DoitStudy.resolve(subject: "수학", unit: "김치찌개 끓이는 법") { check("없는 단원은 지어내지 않음", true) } else {
        check("없는 단원은 지어내지 않음", false, "\(DoitStudy.resolve(subject: "수학", unit: "김치찌개 끓이는 법"))")
    }
    let parsed = DoitStudy.parse("고1 공통수학2 원의 방정식")
    check("입력 분석: 공통수학2", parsed.subjectName == "공통수학2" && parsed.level == .high && parsed.topic == "원의 방정식", "\(parsed)")

    // 2) 단원 범위 안의 자료만 (예전 문제: 이차방정식에 일차함수·연립방정식, 생명 시스템에 지리 정보 시스템)
    func everything(_ subject: String, _ unit: String) async -> String {
        var text = ""
        if let n = try? await DoitTutor.concept(subject: subject, unit: unit, booster: false) { text += ([n.summary] + n.keyPoints + n.details + [n.example]).joined(separator: "\n") }
        for _ in 0..<3 {
            if let p = try? await DoitTutor.problems(subject: subject, unit: unit, count: 4, hard: false) { text += p.items.map { $0.question + $0.choices.joined() + $0.steps.joined() }.joined() }
            if let o = try? await DoitTutor.ox(subject: subject, unit: unit, count: 4) { text += o.items.map(\.statement).joined() }
            if let c = try? await DoitTutor.cloze(subject: subject, unit: unit, count: 4) { text += c.items.map(\.sentence).joined() }
        }
        return text
    }
    let quad = await everything("중학교 수학", "이차방정식")
    let leak = ["일차함수", "연립", "근과 계수", "α + β", "αβ", "허근", "복소수"].filter { quad.contains($0) }
    check("중학교 이차방정식: 다른 단원·고등 내용 없음", leak.isEmpty && quad.contains("이차방정식"), "섞인 말: \(leak)")
    let life = await everything("", "고등학교 통합과학 생명 시스템")
    check("통합과학 생명 시스템: 지리 정보 시스템 안 나옴", !life.contains("지리 정보") && (life.contains("세포") || life.contains("DNA")), String(life.prefix(120)))
    let samguk = await everything("중학교 사회", "삼국의 성립과 발전")
    check("삼국의 성립과 발전: 삼국 내용", samguk.contains("고구려") && !samguk.contains("구석기") && !samguk.contains("실학"), String(samguk.prefix(120)))

    // 3) 검증기가 잘못된 내용을 잡는지
    guard let quadScope = resolved("중학교 수학", "이차방정식") else { check("검증 준비", false); return }
    let basis = DoitStudyCheck.Basis(materials: DoitStudy.materials(for: quadScope), scope: quadScope)
    check("검증: 다른 단원 개념(일차함수) 잡기", !DoitStudyCheck.foreignTerms(in: "이차방정식은 일차함수의 그래프와 같아요", basis: basis).isEmpty)
    check("검증: 이 단원 용어는 통과", DoitStudyCheck.foreignTerms(in: "이차방정식은 근의 공식으로 풀 수 있어요", basis: basis).isEmpty)
    check("검증: 고등 용어(근과 계수의 관계) 잡기", !DoitStudyCheck.foreignTerms(in: "근과 계수의 관계를 이용해요", basis: basis).isEmpty)
    check("검증: 근거 없는 문장 잡기", !DoitStudyCheck.isGrounded("이차방정식은 1592년 이순신 장군이 처음 만들었어요", basis: basis))
    check("검증: 자료에 없는 숫자 잡기", !DoitStudyCheck.inventedNumbers(in: "이차방정식의 해는 항상 1592개예요", basis: basis).isEmpty)
    let badNote = ConceptNote(title: "이차방정식", keyPoints: ["일차함수 y = ax + b의 기울기는 a예요"], example: "")
    check("검증: 섞인 개념 정리 잡기", DoitStudyCheck.check(badNote, basis: basis).contains { $0.kind == .scope })
    let wrongNumber = Problem(question: "다음 설명에 해당하는 개념은?\n(   )", choices: ["이차방정식", "근의 공식", "인수분해"], answerNumber: 5, steps: ["x"], finalAnswer: "5번")
    check("검증: 정답 번호 오류 잡기", DoitStudyCheck.check(wrongNumber, basis: basis).contains { $0.kind == .answer })
    let wrongMath = Problem(question: "방정식 2x + 3 = 11 의 해는?", choices: ["2", "3", "4", "5", "6"], answerNumber: 1, steps: ["x = 2"], finalAnswer: "2")
    check("검증: 수학 정답을 다시 풀어서 잡기", DoitStudyCheck.check(wrongMath, basis: basis, solver: { MathSolver.solve($0)?.answer }).contains { $0.kind == .answer })
    let rightMath = Problem(question: "방정식 2x + 3 = 11 의 해는?", choices: ["2", "3", "4", "5", "6"], answerNumber: 3, steps: ["x = 4"], finalAnswer: "4")
    check("검증: 맞는 수학 정답은 통과", DoitStudyCheck.check(rightMath, basis: basis, solver: { MathSolver.solve($0)?.answer }).isEmpty,
          "\(DoitStudyCheck.check(rightMath, basis: basis, solver: { MathSolver.solve($0)?.answer }))")
    let leaky = Problem(question: "다음 설명에 해당하는 개념은?\n이차방정식은 ax² + bx + c = 0 꼴이에요", choices: ["이차방정식", "근의 공식", "인수분해"], answerNumber: 1, steps: ["정답은 1번"], finalAnswer: "1번 이차방정식")
    check("검증: 정답이 문제에 보이면 잡기", DoitStudyCheck.check(leaky, basis: basis).contains { $0.kind == .format })
    let fakeTrue = OXItem(statement: "이차방정식은 항상 해가 세 개예요", isTrue: true, explanation: "x")
    check("검증: 자료로 확인 안 되는 O 문장 잡기", !DoitStudyCheck.check(fakeTrue, basis: basis).isEmpty)
    let badExplain = Problem(question: "다음 설명에 해당하는 개념은?\n(   ): x", choices: ["근의 공식", "이차방정식", "중근"], answerNumber: 1, steps: ["정답은 2번이에요"], finalAnswer: "2번 이차방정식")
    check("검증: 해설·정답 불일치 잡기", DoitStudyCheck.check(badExplain, basis: basis).contains { $0.kind == .explanation })

    check("조사: 받침 맞추기", DoitStudy.josa("원의 넓이", "을", "를") == "원의 넓이를" && DoitStudy.josa("논리적 오류", "을", "를") == "논리적 오류를"
          && DoitStudy.josa("세포막", "을", "를") == "세포막을" && DoitStudy.josa("'신라'", "은", "는") == "'신라'는" && DoitStudy.josa("DNA", "을", "를") == "DNA을(를)")
    let confusing = Problem(question: "다음 설명에 해당하는 개념은?\n신라는 당과 연합해 백제를 무너뜨렸어요.", choices: ["신라", "백제", "신라의 삼국 통일"], answerNumber: 3,
                            steps: ["정답은 3번"], finalAnswer: "3번 신라의 삼국 통일")
    check("검증: 오답 보기가 문제 글에 나오면 잡기", DoitStudyCheck.check(confusing, basis: basis).contains { $0.detail.contains("헷갈") })
    if let samgukSet = try? await DoitTutor.problems(subject: "중학교 사회", unit: "삼국의 성립과 발전", count: 4, hard: false) {
        let clear = samgukSet.items.allSatisfy { p in p.choices.enumerated().allSatisfy { i, c in i == p.answerNumber - 1 || !p.question.contains(c) } }
        check("삼국 문제: 헷갈리는 보기 없음", clear, "\(samgukSet.items.map { $0.question + " " + $0.choices.joined(separator: "/") })")
    }

    let twoBlanks = Problem(question: "다음 설명에 해당하는 개념은?\n(   )와 (   )이 있어요.", choices: ["이차방정식", "근의 공식", "중근"], answerNumber: 1, steps: ["정답은 1번"], finalAnswer: "1번 이차방정식")
    check("검증: 빈칸 여러 개 잡기", DoitStudyCheck.check(twoBlanks, basis: basis).contains { $0.kind == .format })

    // 4) 재생성은 실패한 것만, 최대 횟수까지
    var calls = 0
    let kept = await DoitStudy.verified(count: 3, attempts: DoitStudy.maxRetries + 1) { missing -> [Int] in
        calls += 1
        return Array(repeating: calls == 1 ? -1 : 7, count: missing)
    } check: { $0 > 0 }
    check("재생성: 통과한 것만 모으고 부족한 만큼만 다시", kept == [7, 7, 7] && calls == 2, "\(kept) calls=\(calls)")
    calls = 0
    let never = await DoitStudy.verified(count: 2, attempts: DoitStudy.maxRetries + 1) { missing -> [Int] in calls += 1; return Array(repeating: -1, count: missing) } check: { $0 > 0 }
    check("재생성: 무한 반복 없이 최대 \(DoitStudy.maxRetries + 1)번", never.isEmpty && calls == DoitStudy.maxRetries + 1, "calls=\(calls)")

    // 5) 개념 → 문제 연결: 문제의 정답이 개념 정리에 나온 개념인지
    if let pack = try? await DoitStudy.makePack(subject: "중학교 과학", unit: "물질의 구성", booster: false) {
        let problems = DoitStudy.ruleProblems(pack: pack, count: 4, hard: false)
        let titles = Set(pack.materials.map(\.title))
        let linked = problems.allSatisfy { p in titles.contains(p.choices[p.answerNumber - 1]) || p.question.contains("옳지 않은") }
        check("문제는 개념 정리의 개념으로", !problems.isEmpty && linked, "\(problems.map { $0.choices[$0.answerNumber - 1] }) / \(titles)")
        check("개념 정리: 핵심 개념·상세 설명·포인트·근거", !pack.concept.summary.isEmpty && !pack.concept.details.isEmpty && !pack.concept.keyPoints.isEmpty && !pack.concept.sources.isEmpty)
    } else { check("문제는 개념 정리의 개념으로", false, "묶음 없음") }
    let math = try? await DoitTutor.problems(subject: "중학교 수학", unit: "이차방정식", count: 4, hard: true)
    check("중학교 이차방정식 문제: 계산 문제·정답 일치", (math?.items.count ?? 0) >= 3 && math!.items.allSatisfy { $0.choices[$0.answerNumber - 1] == $0.finalAnswer || $0.finalAnswer.contains("번") },
          "\(math?.items.map(\.question) ?? [])")

    // 6) 예전에 저장한 개념 정리도 읽힘 (기존 데이터 보존)
    let old = #"{"title":"광합성","keyPoints":["빛으로 양분을 만들어요"],"example":"잎"}"#
    let decoded = try? JSONDecoder().decode(ConceptNote.self, from: Data(old.utf8))
    check("예전 형식 개념 정리 읽기", decoded?.title == "광합성" && decoded?.summary == "" && decoded?.checks == [])

    // 7) 대화에서 "이걸로 퀴즈": 그 개념의 단원으로
    let quick = DoitStudy.quickOX(topic: "광합성")
    check("대화 퀴즈: 광합성 O/X", quick != nil && !(quick?.statement.contains("지리") ?? true), "\(String(describing: quick))")
}

// MARK: - AI 오답노트: 문제 인식 → 채점 → 원인 분석 → 풀이 → 유사 문제 → 숙련도

func runMistakeNote() async {
    // 1) 문제 나누기
    let scanned = DoitProblemScan.scan("""
    3. 이차방정식 x² - 5x + 6 = 0 의 두 근 중 큰 근은? (단, x는 자연수)
    ① 1 ② 2 ③ 3 ④ 4 ⑤ 5
    정답: ③
    """)
    check("인식: 선택지 5개", scanned.choices == ["1", "2", "3", "4", "5"], "\(scanned.choices)")
    check("인식: 객관식으로 판단", scanned.kind == .multipleChoice)
    check("인식: 사진의 정답 표기", scanned.printedAnswer == "③", scanned.printedAnswer ?? "-")
    check("인식: 조건 찾기", scanned.conditions.contains { $0.contains("자연수") }, "\(scanned.conditions)")
    check("인식: 질문 핵심", scanned.question.contains("큰 근은"), scanned.question)
    check("인식: 수식 찾기", scanned.formulas.contains { $0.contains("x") && $0.contains("=") }, "\(scanned.formulas)")
    let lineChoices = DoitProblemScan.scan("다음 중 소수는?\n1) 4\n2) 6\n3) 7\n4) 9\n5) 10")
    check("인식: 줄마다 쓴 선택지", lineChoices.choices == ["4", "6", "7", "9", "10"], "\(lineChoices.choices)")
    check("인식: 문제 번호는 선택지 아님", DoitProblemScan.scan("3. 2x + 3 = 11 을 푸시오").choices.isEmpty)
    let doubtful = DoitProblemScan.scan("(x + 2 = 5 의 해는?", lowConfidence: ["흐린 줄"])
    check("인식: 불확실한 곳 표시", doubtful.doubts.contains { $0.reason.contains("괄호") } && doubtful.doubts.contains { $0.text == "흐린 줄" }, "\(doubtful.doubts)")
    let graph = DoitProblemScan.scan("다음 그래프에서 꼭짓점의 좌표를 구하시오.")
    check("인식: 읽지 못한 그래프는 지어내지 않고 표시", graph.doubts.contains { $0.text.contains("그래프") } && graph.graphNote == nil)
    let table = DoitProblemScan.scan("다음 표를 보고 평균을 구하시오.\n이름 | 국어 | 수학\n민지 | 80 | 90\n준호 | 70 | 85")
    check("인식: 표", table.table.count == 3 && table.table[1] == ["민지", "80", "90"], "\(table.table)")
    check("인식: 서술형 판단", DoitProblemScan.scan("광합성이 일어나는 과정을 서술하시오.").kind == .essay)

    // 2) 채점
    func g(_ kind: ProblemKind, _ student: String, _ key: String, choices: [String] = [], problem: String = "") -> GradeResult.Verdict {
        DoitGrader.grade(.init(kind: kind, student: student, answerKey: key, choices: choices, problem: problem)).verdict
    }
    let five = ["1", "2", "3", "4", "5"]
    check("채점(객관식): ③ = 3번", g(.multipleChoice, "3번", "③", choices: five) == .correct)
    check("채점(객관식): 보기 글로 답해도", g(.multipleChoice, "3", "③", choices: ["ㄱ", "ㄴ", "3", "ㄹ", "ㅁ"]) == .correct)
    check("채점(객관식): 오답", g(.multipleChoice, "②", "③", choices: five) == .wrong)
    check("채점(단답): 띄어쓰기·기호 무시", g(.shortAnswer, "광 합성.", "광합성") == .correct)
    check("채점(단답): 복수 정답", g(.shortAnswer, "탄소 동화 작용", "광합성 | 탄소 동화 작용") == .correct)
    check("채점(단답): 끝말 정리", g(.shortAnswer, "엽록체입니다", "엽록체") == .correct)
    check("채점(단답): 한 글자 차이는 확인 요청", g(.shortAnswer, "미토콘드리야", "미토콘드리아") == .needsReview)
    check("채점(단답): 오답", g(.shortAnswer, "핵", "엽록체") == .wrong)
    check("채점(수학): 분수 = 소수", g(.math, "0.5", "1/2") == .correct)
    check("채점(수학): 근호 정리", g(.math, "√8", "2√2") == .correct)
    check("채점(수학): 해 순서 무시", g(.math, "3, 2", "x = 2 또는 x = 3") == .correct)
    check("채점(수학): ± 표기", g(.math, "1±√2", "1+√2, 1-√2") == .correct)
    check("채점(수학): 같은 식 (전개)", g(.math, "x^2+2x+1", "(x+1)^2") == .correct)
    check("채점(수학): 다른 식", g(.math, "x^2+1", "(x+1)^2") == .wrong)
    check("채점(수학): 연립 해 순서 무시", g(.math, "y=2, x=1", "x=1, y=2") == .correct)
    check("채점(수학): 순서쌍은 순서 중요", g(.math, "(2, 1)", "(1, 2)") == .wrong)
    check("채점(수학): 부등식 방향", g(.math, "2<x", "x>2") == .correct)
    check("채점(수학): 해 일부만 → 부분 정답", g(.math, "2", "x = 2 또는 x = 3") == .partial)
    check("채점(수학): 정답 없으면 직접 풀어서", g(.math, "4", "", problem: "2x + 3 = 11") == .correct && g(.math, "5", "", problem: "2x + 3 = 11") == .wrong)
    check("채점(수학): 읽을 수 없는 답은 확인 요청", g(.math, "모르겠음", "4") == .needsReview)
    check("채점: 정답을 모르면 확정하지 않음", g(.shortAnswer, "엽록체", "") == .needsReview)
    let essay = DoitGrader.grade(.init(kind: .essay, student: "식물은 빛 에너지를 이용해 포도당을 만든다.", answerKey: "식물은 빛 에너지를 이용한다. 이산화 탄소와 물로 포도당을 만든다. 산소가 발생한다."))
    check("채점(서술형): 부분 점수 + 근거, 확정하지 않음", essay.verdict == .partial && essay.score > 0 && essay.score < 1 && essay.reasons.contains { $0.hasPrefix("✗") }, "\(essay)")

    // 3) 오답 원인
    func analyze(_ problem: String, _ student: String, kind: ProblemKind = .math, key: String = "", conditions: [String] = [], work: [String]? = nil) -> MistakeAnalysis? {
        let grade = DoitGrader.grade(.init(kind: kind, student: student, answerKey: key, problem: problem))
        return DoitMistake.analyze(.init(problem: problem, kind: kind, student: student, grade: grade, conditions: conditions,
                                         work: work.map { DoitWorkChecker.check(problem: problem, work: $0) }))
    }
    let sign = analyze("2x + 3 = 11", "-4")
    check("원인: 부호 반대 → 계산 실수(추정)", sign?.cause == .calculation && sign?.certainty == .estimated, "\(String(describing: sign))")
    let partialRoots = analyze("x^2 - 5x + 6 = 0", "2")
    check("원인: 해 일부만 → 풀이 과정 오류", partialRoots?.cause == .process, "\(String(describing: partialRoots?.cause))")
    let byWork = analyze("2x + 3 = 11", "7", work: ["2x = 14", "x = 7"])
    check("원인: 풀이 과정으로 확인 (확인됨)", byWork?.certainty == .confirmed && byWork?.evidence.first?.contains("1번째 줄") == true, "\(String(describing: byWork))")
    let unknown = analyze("2x + 3 = 11", "13")
    check("원인: 근거 없으면 판단 불가", unknown?.cause == .unknown && unknown?.certainty == .unknown, "\(String(describing: unknown?.cause))")
    check("원인: 복습·다음 학습·놓친 개념", (unknown?.review.isEmpty == false) && (unknown?.next.isEmpty == false) && unknown?.missedConcepts.contains("일차방정식") == true, "\(String(describing: unknown))")
    check("원인: 정답이면 분석 안 함", analyze("2x + 3 = 11", "4") == nil)
    let confused = analyze("식물 세포에서 광합성이 일어나는 곳은?", "미토콘드리아", kind: .shortAnswer, key: "엽록체")
    check("원인: 다른 개념과 헷갈림 → 개념 이해 부족(추정)", confused?.cause == .concept && confused?.certainty == .estimated, "\(String(describing: confused))")
    check("원인: 개념 오답은 1단계부터", confused?.startLevel == 1)

    // 4) 단계별 풀이: 개념·이유·다음 단계 (풀이 엔진이 푼 것만)
    if let solved = MathSolver.solve("x^2 - 5x + 6 = 0") {
        let written = DoitSolutionWriter.write(solved)
        check("풀이: 단계마다 다음 단계 안내", written.steps.allSatisfy { !$0.next.isEmpty } && written.steps.last?.next.contains(written.finalAnswer) == true)
        check("풀이: 쓰는 개념·이유", written.steps.contains { !$0.concept.isEmpty } && written.steps.contains { !$0.reason.isEmpty }, "\(written.steps)")
    } else { check("풀이: 이차방정식", false) }
    let oldStep = try? JSONDecoder().decode(SolutionStep.self, from: Data(#"{"hint":"이항하면","work":"2x = 8"}"#.utf8))
    check("예전 풀이 형식 읽기", oldStep?.hint == "이항하면" && oldStep?.reason == "")

    // 5) 유사 문제 단계
    let basis = DoitPractice.basis(problem: "x^2 - 5x + 6 = 0")
    check("유사 문제: 개념 찾기", basis.concept == "이차방정식의 풀이" && basis.level == .middle, "\(basis.concept)")
    var levels: [Int: PracticeItem] = [:]
    var asked: [String] = []
    for level in 1...5 {
        if let item = await DoitPractice.makeItem(level: level, basis: basis, avoid: asked) { levels[level] = item; asked.append(item.question) }
    }
    check("유사 문제: 1~5단계 모두", levels.count == 5, "\(levels.keys.sorted())")
    check("유사 문제: 1단계는 개념 확인", levels[1]?.kind != .math, levels[1]?.question ?? "")
    check("유사 문제: 원래 문제·서로 같은 문제 없음", Set(asked).count == asked.count && !asked.contains("x^2 - 5x + 6 = 0"))
    check("유사 문제: 중학교 문제에 고등 유형 없음", !asked.joined().contains("α") && !asked.joined().contains("허근"), asked.joined(separator: " / "))
    let templates = Set(asked.filter { !$0.contains("O, 틀리면") }.map(DoitPractice.templateKey))
    check("유사 문제: 숫자만 바꾼 반복이 아님 (모양이 여러 가지)", templates.count >= 2, "\(templates)")
    if let item = levels[2] {
        check("유사 문제: 정답으로 채점", DoitPractice.grade(item, answer: item.answer).verdict == .correct)
        var ladder = PracticeLadder(level: 2)
        DoitPractice.advance(&ladder, item: item, answer: item.answer, result: DoitPractice.grade(item, answer: item.answer), reminder: basis.reminder)
        check("단계: 맞히면 올라감", ladder.level == 3 && ladder.streak == 1 && ladder.reminder == nil)
        let wrong = PracticeItem(level: 3, kind: .math, question: "q", answer: "4", explanation: [], concept: "c")
        DoitPractice.advance(&ladder, item: wrong, answer: "9", result: DoitPractice.grade(wrong, answer: "9"), reminder: basis.reminder)
        check("단계: 틀리면 개념 설명 + 한 단계 쉽게", ladder.level == 2 && ladder.streak == 0 && ladder.reminder != nil)
    }

    // 6) 숙련도: 한 번 맞혔다고 익힘이 아님
    var mastery = 0.2
    var records: [DoitMastery.Record] = [.init(date: Date(), correct: false, level: 3, source: "오답노트")]
    mastery = DoitMastery.updated(mastery, correct: true, level: 5)
    records.append(.init(date: Date(), correct: true, level: 5, source: "유사 문제"))
    check("숙련도: 한 번 맞혀도 익힘 아님", DoitMastery.state(mastery: mastery, records: records, wrongCount: 1) != .mastered)
    for _ in 0..<6 { mastery = DoitMastery.updated(mastery, correct: true, level: 4); records.append(.init(date: Date(), correct: true, level: 4, source: "유사 문제")) }
    check("숙련도: 같은 날만 맞히면 익힘 아님", DoitMastery.state(mastery: mastery, records: records, wrongCount: 1) != .mastered)
    records.append(.init(date: Date().addingTimeInterval(-3 * 86400), correct: true, level: 4, source: "재도전"))
    records.sort { $0.date < $1.date }
    records.append(.init(date: Date(), correct: true, level: 4, source: "재도전"))
    check("숙련도: 여러 날 연속 정답이면 익힘", DoitMastery.state(mastery: mastery, records: records, wrongCount: 1) == .mastered, "\(mastery)")
    check("숙련도: 틀리면 크게 내려감", DoitMastery.updated(0.9, correct: false, level: 3) < 0.6)
    check("취약 개념: 반복 오답", DoitMastery.isWeak(mastery: 0.4, wrongCount: 2) && !DoitMastery.isWeak(mastery: 0.7, wrongCount: 1))
    for kind in MathSolver.Kind.allCases {
        if let info = DoitMathConceptMap.info(for: kind) {
            check("개념 지도: \(kind) → \(info.subject) \(info.unit)", DoitStudy.catalog.contains { $0.subjectName == info.subject && $0.unit == info.unit })
        }
    }
}

// MARK: - 실행

await runChat()
runMath()
runGenerators()
runWorkChecker()
runOCRFixer()
runWordParser()
runWordReview()
runWordCases()
runPartOfSpeechCases()
runProblemSplitCases()
runOCRCases()
runSolverCases()
runSolverCases2()
runKnowledge()
runBrain()
await runCurriculum()
await runStudy()
await runMistakeNote()
runMistakeSubjectCases()
runStudyScopeCases()
await runChatContextCases()
runProblemTypeCases()

await runChatRelevanceCases()
await runChatNaturalCases()

runGuidedSolveCases()
runPaddleOCRCases()
runAutoSolveCases()
runItemJudgeCases()
runSolverBatteryCases()
runMathBattery3Cases()
runSubjectBatteryCases()
runSubjectBattery2Cases()
runSubjectBattery3Cases()
runSentenceCheckCases()
runEnglishBatteryCases()
runGeometryCases()
runFigureCases()
runHandwritingCases()
runBadgeCases()
runSoundMixCases()
runMockExamCases()
await runEnglishCurriculumCases()
runWatchCases()
runWidgetCases()

print("모티 AI 테스트: \(passed)개 통과, \(failed.count)개 실패")
for f in failed { print(f) }
exit(failed.isEmpty ? 0 : 1)
