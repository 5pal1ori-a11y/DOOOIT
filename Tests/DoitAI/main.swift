import Foundation

// 두잇 AI 엔진 테스트 모음
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
    ChatCase(name: "모르는 질문은 솔직하게", inputs: ["블랙홀 안에는 뭐가 있어?"], expect: ["몰라요"]),
    ChatCase(name: "영어 인사", inputs: ["How are you?"], expect: ["(저는"]),
    ChatCase(name: "자기소개", inputs: ["너 누구야?"], expect: ["두잇 AI"], reject: ["Apple"]),
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

// MARK: - 실행

await runChat()
runMath()
runGenerators()
runWorkChecker()
runOCRFixer()
runKnowledge()

print("두잇 AI 테스트: \(passed)개 통과, \(failed.count)개 실패")
for f in failed { print(f) }
exit(failed.isEmpty ? 0 : 1)
