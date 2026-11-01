import Foundation

/// 두잇 AI 퀴즈 한 문제 (정답은 여러 개 허용)
struct DoitQuizItem {
    let question: String
    let answers: [String]
    let explanation: String
}

/// 두잇 AI 일상 대화 (외부 AI 없이 직접 만든 규칙형)
/// 인사, 감정 공감, 공부 고민·공부법, 응원, 시간·날짜, 농담·명언 같은 가벼운 대화를 맡음
enum DoitChat {
    struct Context {
        var now = Date()
        var todayMinutes = 0
        var goalMinutes = 180
        var remainingPlans = 0
        var dDay: String?
    }

    struct Answer {
        var text: String
        var suggestions: [String] = []
    }

    // MARK: - 진입점

    static func reply(_ raw: String, context: Context) -> Answer? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let t = squash(text)

        // 0) 위기 신호는 가장 먼저, 진지하게
        if isCrisis(raw) { return crisis() }

        if let special = specialCases(text, t, context) { return special }
        for rule in rules where rule.matches(t, text) {
            return rule.make(text, t, context)
        }
        return nil
    }

    // MARK: - 규칙

    private struct Rule {
        var words: [String]
        var maxLength: Int = 60
        var exclude: [String] = []
        /// 이 말로 시작할 때만 (예: "이름이 뭐야" — "사장님 이름이 뭐야"는 아님)
        var prefixes: [String] = []
        var make: (String, String, Context) -> Answer

        func matches(_ t: String, _ original: String) -> Bool {
            guard t.count <= maxLength, !exclude.contains(where: { t.contains($0) }) else { return false }
            return words.contains { t.contains($0) } || prefixes.contains { t.hasPrefix($0) }
        }
    }

    private static let rules: [Rule] = [
        // 인사
        Rule(words: ["안녕", "하이", "ㅎㅇ", "반가워", "반갑", "hello", "hi", "hey", "좋은아침", "굿모닝", "goodmorning"], maxLength: 14,
             exclude: ["잘자", "안녕히", "잘있어"]) { _, _, c in greeting(c) },
        Rule(words: ["잘자", "굿나잇", "goodnight", "잘게", "자러갈", "자야겠", "이제잘"], maxLength: 20) { _, _, c in goodNight(c) },
        Rule(words: ["안녕히", "잘있어", "바이바이", "bye", "내일봐", "다음에봐", "나갈게", "이만"], maxLength: 16) { _, _, _ in
            Answer(text: pick(["오늘도 수고 많았어요. 다음에 또 불러주세요!", "좋아요, 다음에 봐요. 계획한 건 제가 잘 챙겨둘게요.", "수고했어요! 쉬는 것도 공부의 일부예요."]))
        },
        // 고마움 · 사과 · 칭찬 · 짜증
        Rule(words: ["고마워", "고맙", "감사", "땡큐", "thank", "thx", "ㄱㅅ", "ㄳ"], maxLength: 20) { _, _, _ in
            Answer(text: pick(["천만에요! 또 필요한 거 있으면 말해주세요.", "도움이 됐다니 다행이에요 😊", "언제든지요. 오늘도 같이 힘내봐요!"]),
                   suggestions: ["오늘 할 일 알려줘", "퀴즈 내줘"])
        },
        Rule(words: ["미안", "죄송", "sorry"], maxLength: 20) { _, _, _ in
            Answer(text: pick(["괜찮아요! 신경 쓰지 마세요.", "전혀 괜찮아요. 우리 이어서 해볼까요?"]))
        },
        Rule(words: ["잘했어", "똑똑하", "최고야", "최고다", "대박", "천재", "멋지다", "멋져", "짱이"], maxLength: 20,
             exclude: ["기분", "오늘", "하루", "나", "내가", "날씨", "점수", "성적"]) { _, _, _ in
            Answer(text: pick(["칭찬 고마워요! 더 똑똑해지도록 노력할게요.", "헤헤, 고마워요. 그래도 제일 대단한 건 꾸준히 공부하는 당신이에요!"]))
        },
        Rule(words: ["바보", "멍청", "쓸모없", "짜증나게하", "못알아듣", "이해를못", "답답해너"], maxLength: 30) { _, _, _ in
            Answer(text: "제가 잘 못 알아들었나 봐요. 미안해요! 조금만 다르게 말해주면 다시 해볼게요.\n예: \"내일 오후 3시 영어 공부 추가해줘\", \"x² − 4 = 0 풀어줘\", \"광합성이 뭐야?\"",
                   suggestions: ["뭐 할 수 있어?"])
        },
        Rule(words: ["사랑해", "좋아해너", "너좋아", "너가좋"], maxLength: 16) { _, _, _ in
            Answer(text: pick(["저도 당신과 공부하는 시간이 좋아요! 오늘도 같이 힘내요.", "고마워요 😊 그 마음으로 오늘 목표까지 같이 가봐요!"]))
        },
        // 두잇 AI 자신
        Rule(words: ["너누구", "넌누구", "너는누구", "너이름", "니이름", "네이름", "너의이름", "당신이름", "넌이름", "너는이름", "넌뭐야", "너뭐야", "자기소개", "너누가만", "넌누가만", "두잇누가만", "whoareyou"], maxLength: 24,
             exclude: ["내이름", "제이름", "나이름"], prefixes: ["이름이뭐", "이름뭐", "누가만들었", "누가만든", "누가널", "누가너"]) { _, _, _ in
            Answer(text: "저는 **두잇 AI**예요. DOOOIT 안에서 일정·타이머·단어·메모를 관리하고, 수학 풀이와 영어·과학·사회 개념 설명, 퀴즈를 도와드려요.\n외부 AI 없이 앱 안에서 직접 만든 엔진으로 대화하고, 사진 속 문제·그래프·도형도 읽어요. 대화는 휴대폰 밖으로 나가지 않아요.",
                   suggestions: ["뭐 할 수 있어?", "퀴즈 내줘"])
        },
        Rule(words: ["사람이야", "ai야", "로봇이야", "진짜사람", "gpt야", "챗gpt"], maxLength: 20) { _, _, _ in
            Answer(text: "저는 사람은 아니고, DOOOIT에 들어 있는 규칙형 AI 도우미예요. 대신 공부할 땐 누구보다 성실하게 옆에 있을게요!")
        },
        Rule(words: ["뭐해", "뭐하고있", "모해"], maxLength: 12) { _, _, c in
            Answer(text: "당신이 부르기를 기다리고 있었어요! " + (c.remainingPlans > 0 ? "오늘 남은 플랜이 \(c.remainingPlans)개 있어요. 같이 하나씩 해치워볼까요?" : "오늘 할 일을 정리해 드릴까요?"),
                   suggestions: ["오늘 할 일 알려줘", "25분 타이머 시작해줘"])
        },
        Rule(words: ["기분어때", "잘지냈", "잘지내", "오늘어때", "컨디션어때"], maxLength: 16) { _, _, _ in
            Answer(text: "저는 언제나 쌩쌩해요! 당신은 오늘 어때요? 피곤하면 피곤하다고, 힘들면 힘들다고 편하게 말해줘요.")
        },

        // 감정 · 컨디션
        Rule(words: ["피곤", "졸려", "졸리", "잠와", "잠온", "잠이와", "잠이온", "꾸벅"]) { _, _, c in tired(c) },
        Rule(words: ["힘들", "지쳤", "지친다", "지침", "버거", "벅차", "포기하고싶", "그만두고싶", "번아웃"]) { _, _, c in hardTime(c) },
        Rule(words: ["스트레스", "짜증나", "짜증난", "화나", "열받", "빡쳐", "빡친"]) { _, _, _ in stressed() },
        Rule(words: ["우울", "슬퍼", "슬프", "외로", "눈물", "울고싶", "울었", "속상"]) { _, _, _ in sad() },
        Rule(words: ["불안", "긴장", "떨려", "걱정돼", "걱정된", "무서워"]) { _, t, _ in anxious(t) },
        Rule(words: ["망했", "망쳤", "망함", "떨어졌", "못봤", "성적이안", "점수가안", "등급떨어", "점수떨어"], exclude: ["안망", "잘봤"]) { _, _, _ in exam_bad() },
        Rule(words: ["잘봤", "100점", "만점", "1등급", "올랐어", "성적올", "합격", "붙었"], exclude: ["어떻게", "방법"]) { _, _, _ in
            Answer(text: pick(["와, 정말 축하해요! 🎉 꾸준히 해온 노력이 결과로 나온 거예요.", "대단해요! 오늘은 스스로를 충분히 칭찬해 주세요. 이 기세 그대로 다음 목표도 잡아볼까요?"]),
                   suggestions: ["다음 시험 D-Day 설정해줘", "이번 주 공부 통계"])
        },
        Rule(words: ["기분좋", "행복", "신나", "최고의날", "좋은일"], maxLength: 30) { _, _, _ in
            Answer(text: pick(["좋은 일이 있었군요! 저까지 기분이 좋아져요 😊", "행복한 기분, 오늘 공부에도 살짝 써볼까요? 기분 좋을 때 집중이 더 잘 돼요."]))
        },
        Rule(words: ["심심", "할거없", "할게없", "지루", "노잼"], maxLength: 24) { _, _, _ in
            Answer(text: "심심할 땐 가볍게 퀴즈 한 판 어때요? 수학·영어·과학·사회 중에서 골라도 되고, 내 단어장으로 단어 퀴즈도 낼 수 있어요.",
                   suggestions: ["수학 퀴즈 내줘", "영어 퀴즈 내줘", "과학 퀴즈 내줘", "사회 퀴즈 내줘"])
        },
        Rule(words: ["배고파", "배고프", "출출", "뭐먹지", "뭐먹을까"], maxLength: 20) { _, _, _ in
            Answer(text: pick(["밥은 꼭 챙겨 먹어요! 뇌도 에너지가 있어야 일해요. 너무 배부르게 먹으면 졸릴 수 있으니 적당히가 좋아요.",
                               "출출할 땐 견과류나 바나나처럼 가벼운 간식이 집중에 도움이 돼요. 먹고 나서 다시 달려볼까요?"]))
        },

        // 공부 의욕 · 공부법
        Rule(words: ["공부하기싫", "공부싫", "하기싫어", "의욕없", "의욕이없", "동기부여", "귀찮", "공부안돼", "공부가안돼", "놀고싶"]) { _, _, c in motivation(c) },
        Rule(words: ["집중이안", "집중안", "집중이잘안", "집중력", "딴생각", "폰을자꾸", "핸드폰을자꾸", "휴대폰을자꾸", "산만"]) { _, _, _ in focusTips() },
        Rule(words: ["슬럼프"]) { _, _, _ in slump() },
        Rule(words: ["암기법", "외우는법", "외우는방법", "암기잘", "잘외우", "기억이안", "까먹", "외워지지"]) { _, _, _ in memorize() },
        Rule(words: ["수학공부법", "수학공부어떻게", "수학잘하", "수학어떻게공부", "수학못해", "수학이어려", "수학포기"]) { _, _, _ in studyMethod("수학") },
        Rule(words: ["영어공부법", "영어공부어떻게", "영어잘하", "영어어떻게공부", "영어못해", "영어가어려", "단어외우는법", "단어암기"]) { _, _, _ in studyMethod("영어") },
        Rule(words: ["국어공부법", "국어공부어떻게", "국어잘하", "국어어떻게공부", "국어가어려", "비문학공부", "문학공부"]) { _, _, _ in studyMethod("국어") },
        Rule(words: ["과학공부법", "과학공부어떻게", "과학잘하", "과학어떻게공부", "과학이어려"]) { _, _, _ in studyMethod("과학") },
        Rule(words: ["사회공부법", "사회공부어떻게", "사회잘하", "역사공부법", "한국사공부", "사회어떻게공부", "암기과목"]) { _, _, _ in studyMethod("사회") },
        Rule(words: ["공부법", "공부방법", "공부어떻게해", "공부어떻게하", "공부잘하는법", "효율적으로공부", "공부팁"]) { _, _, _ in generalStudy() },
        Rule(words: ["시험기간", "시험계획", "시험공부계획", "시험준비어떻게", "내신준비", "시험대비"]) { _, _, c in examPlan(c) },
        Rule(words: ["벼락치기", "시험전날", "내일시험", "내일이시험", "시험하루전"]) { _, _, _ in cramTips() },
        Rule(words: ["오답노트쓰는", "오답노트어떻게", "오답정리"]) { _, _, _ in
            Answer(text: "**오답노트 잘 쓰는 법**\n1. 문제를 찍어 저장하고, 틀린 이유를 한 줄로 적어요 (계산 실수 / 개념 몰라서 / 문제 잘못 읽음).\n2. 해설을 보기 전에 한 번 더 혼자 풀어봐요.\n3. 3일 뒤, 1주일 뒤에 다시 풀어서 맞으면 '맞음'으로 바꿔요.\n4. 같은 유형을 2~3문제 더 풀면 완전히 내 것이 돼요. 오답노트의 '비슷한 문제'를 활용해 보세요!",
                   suggestions: ["오답노트 현황 알려줘"])
        },
        Rule(words: ["플래너쓰는", "계획세우는법", "계획어떻게세", "계획을못지", "계획을안지", "작심삼일"]) { _, _, _ in planning() },
        Rule(words: ["몇시간자", "잠을몇", "수면시간", "밤새", "밤샘", "새벽공부"]) { _, _, _ in
            Answer(text: "**잠과 공부**\n자는 동안 뇌가 낮에 배운 걸 정리해서 기억으로 옮겨요. 그래서 밤새우는 것보다 6~8시간 자는 게 시험에 훨씬 유리해요.\n• 시험 전날에도 최소 5~6시간은 자기\n• 잠들기 전 20분은 오늘 외운 것 훑어보기 (기억이 잘 남아요)\n• 낮잠은 20분 이내로")
        },
        Rule(words: ["쉬는시간", "얼마나쉬", "몇분쉬", "휴식"], maxLength: 30) { _, _, _ in
            Answer(text: "집중 25~50분 + 휴식 5~10분이 좋아요 (뽀모도로). 쉴 땐 휴대폰보다 스트레칭, 물 마시기, 창밖 보기가 머리를 더 잘 식혀줘요.",
                   suggestions: ["25분 타이머 시작해줘"])
        },
        Rule(words: ["뽀모도로", "pomodoro"]) { _, _, _ in
            Answer(text: "**뽀모도로 공부법**\n25분 집중 → 5분 휴식을 한 세트로, 4세트마다 15~30분 길게 쉬어요. 타이머가 돌아가는 동안은 한 가지 과목만 해요.",
                   suggestions: ["25분 타이머 시작해줘"])
        },
        Rule(words: ["진로", "꿈이없", "뭐가되고싶", "하고싶은게없", "대학어디", "무슨과"]) { _, _, _ in
            Answer(text: "진로 고민은 누구나 해요. 아직 정하지 못한 게 늦은 게 아니에요.\n• 내가 시간 가는 줄 모르고 한 일 3가지를 적어보기\n• 관심 있는 직업 2~3개를 골라 실제로 하는 일을 찾아보기 (커리어넷 같은 진로 사이트)\n• 담임·진로 선생님과 한 번 이야기해 보기\n지금 성실하게 쌓는 공부 습관은 어떤 길을 가도 힘이 돼요.")
        },
        Rule(words: ["친구랑싸", "친구가싫", "친구관계", "왕따", "따돌", "친구가없", "친구없어"]) { _, _, _ in
            Answer(text: "친구 문제로 마음이 많이 쓰이겠어요. 혼자 끙끙 앓지 않아도 돼요.\n• 감정이 가라앉은 뒤 '나는 ~해서 속상했어'처럼 내 마음을 중심으로 이야기해 보기\n• 괴롭힘이나 따돌림이라면 꼭 부모님·선생님께 알리기 (학교폭력 신고 117)\n• 털어놓을 곳이 필요하면 청소년상담 1388도 있어요.")
        },
        Rule(words: ["부모님이", "엄마가", "아빠가", "잔소리"], maxLength: 40, exclude: ["추가", "일정", "메모"]) { _, _, _ in
            Answer(text: "가족이랑 부딪히면 마음이 복잡하죠. 부모님도 걱정하는 마음이 서툴게 나올 때가 많아요. 기분이 가라앉았을 때 '이렇게 말해주면 좋겠어'라고 차분히 전해보는 건 어때요? 공부 계획을 플래너로 보여드리는 것도 믿음을 주는 데 도움이 돼요.")
        },

        // 오늘 공부 피드백
        Rule(words: ["나오늘잘했", "오늘열심히했", "공부열심히했", "오늘공부다했", "오늘다끝냈", "나잘하고있"], maxLength: 30) { _, _, c in praise(c) },

        // 시간 · 날짜
        Rule(words: ["몇시야", "몇시예요", "지금몇시", "현재시간", "지금시간"], maxLength: 16) { _, _, c in
            Answer(text: "지금은 \(format(c.now, "a h시 m분"))이에요." + (c.remainingPlans > 0 ? " 오늘 남은 플랜이 \(c.remainingPlans)개 있어요." : ""))
        },
        Rule(words: ["오늘며칠", "오늘몇일", "오늘날짜", "무슨요일", "오늘요일", "몇월며칠"], maxLength: 16,
             exclude: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "뒤", "후에", "전에", "까지"]) { _, _, c in
            Answer(text: "오늘은 \(format(c.now, "yyyy년 M월 d일 EEEE"))이에요." + (c.dDay.map { " (\($0))" } ?? ""))
        },
        Rule(words: ["날씨"], maxLength: 20) { _, _, _ in
            Answer(text: "아쉽지만 저는 날씨 정보를 볼 수 없어요. 날씨 앱을 확인해 주세요! 비 오는 날엔 타이머의 빗소리를 켜고 공부해 보는 것도 좋아요.")
        },

        // 재미
        Rule(words: ["농담", "개그", "웃긴얘기", "웃겨줘", "재밌는얘기", "재미있는얘기", "아재"], maxLength: 20) { _, _, _ in
            let joke = pick(jokes)
            return Answer(text: joke, suggestions: ["하나 더", "퀴즈 내줘"])
        },
        Rule(words: ["명언", "좋은말", "힘이되는말", "응원해줘", "응원좀", "격려", "한마디해줘"], maxLength: 20) { _, _, _ in
            Answer(text: pick(quotes), suggestions: ["하나 더", "오늘 할 일 알려줘"])
        },
        Rule(words: ["하나더", "또해줘", "한개더", "더해줘"], maxLength: 5) { _, _, _ in
            Answer(text: Bool.random() ? pick(jokes) : pick(quotes), suggestions: ["하나 더"])
        },
        Rule(words: ["노래추천", "공부음악", "공부할때들을", "백색소음", "집중음악"], maxLength: 24) { _, _, _ in
            Answer(text: "가사가 없는 소리가 집중에 좋아요. DOOOIT 타이머에서 빗소리, 파도, 백색·핑크·브라운 소음을 켤 수 있어요. 타이머 화면의 소리 버튼을 눌러보세요!",
                   suggestions: ["타이머 화면 열어줘"])
        },

        // 짧은 맞장구
        Rule(words: ["ㅋㅋ", "ㅎㅎ", "하하", "lol"], maxLength: 8) { _, _, _ in
            Answer(text: pick(["ㅎㅎ 기분 좋아 보여서 다행이에요!", "웃으면서 공부하면 더 잘 외워진대요 😄"]))
        },
        Rule(words: ["ㅠㅠ", "ㅜㅜ", "흑흑"], maxLength: 8) { _, _, _ in
            Answer(text: "무슨 일 있어요? 편하게 이야기해 줘요. 공부 고민이면 같이 방법을 찾아볼게요.")
        },
        Rule(words: ["응", "ㅇㅇ", "그래", "좋아", "알겠어", "오케이", "ok", "okay", "넵", "네"], maxLength: 5) { _, _, _ in
            Answer(text: "좋아요! 무엇부터 할까요?", suggestions: ["오늘 할 일 알려줘", "25분 타이머 시작해줘", "퀴즈 내줘"])
        },
        Rule(words: ["그만", "됐어", "괜찮아", "멈춰", "취소"], maxLength: 6) { _, _, _ in
            Answer(text: "알겠어요. 필요할 때 언제든 불러주세요!")
        },
        Rule(words: ["아니", "ㄴㄴ", "싫어", "별로"], maxLength: 5) { _, _, _ in
            Answer(text: "알겠어요. 다른 게 필요하면 언제든 말해주세요.")
        }
    ]

    // MARK: - 숫자가 들어간 대화 (공부 시간, 점수, 남은 기간, 과목이 어려움)

    private static func specialCases(_ text: String, _ t: String, _ c: Context) -> Answer? {
        // "이 문제 풀어줘" 인데 문제가 없을 때
        if has(t, ["풀어줘", "풀어줄래", "풀어봐", "풀어주세요"]), !t.contains(where: { $0.isNumber || ($0.isASCII && $0.isLetter) }) {
            return Answer(text: "풀 문제를 보내주세요! 식으로 써도 되고, 아래 + 버튼으로 문제 사진을 찍어 보내도 돼요.\n예: \"x² − 5x + 6 = 0 풀어줘\", \"y = x² − 4x + 1 꼭짓점\"",
                          suggestions: ["x² − 5x + 6 = 0 풀어줘"])
        }
        // "이차함수 문제 풀어줄 수 있니?", "영어 문법 도와줄 수 있어?"
        if has(t, ["줄수있", "줄수있니", "줄래", "해줄수", "할수있니", "할수있어", "가능해", "가능하니", "되니", "돼?"]),
           has(t, ["풀어", "풀이", "문제", "도와", "알려", "설명", "가르쳐", "수학", "영어", "과학", "사회", "함수", "방정식", "문법", "단어"]),
           !has(t, ["추가", "일정", "타이머", "메모", "퀴즈"]) {
            return capability(t)
        }
        // "오늘 3시간 공부했어", "2시간 반 공부함"
        if has(t, ["공부했", "공부함", "공부한거", "공부를했"]), !has(t, ["추가", "기록해", "타이머"]),
           let m = t.firstMatch(of: #/(\d+)시간(반)?|(\d+)분/#) {
            var minutes = 0
            if let h = m.1.flatMap({ Int(String($0)) }) { minutes = h * 60 + (m.2 == nil ? 0 : 30) }
            if let mm = m.3.flatMap({ Int(String($0)) }) { minutes = mm }
            let goal = c.goalMinutes
            var line = minutes >= goal && goal > 0 ? "하루 목표 \(duration(goal))을 넘겼네요! 정말 대단해요 🎉" : minutes >= 120 ? "꾸준히 오래 집중했네요. 정말 잘했어요!" : "좋아요, 그 시간이 다 실력으로 쌓여요!"
            if c.todayMinutes + 10 < minutes {
                line += "\n타이머로 재면 기록에 자동으로 남아서 통계에서 확인할 수 있어요."
            }
            return Answer(text: "\(duration(minutes)) 공부했군요. \(line)", suggestions: ["오늘 공부 통계", "내일 할 일 알려줘"])
        }
        // "공부하기 너무 싫다", "공부 진짜 하기 싫어"
        if t.contains("공부") && has(t, ["싫", "하기싫", "안하고싶", "때려치", "귀찮"]) && !has(t, ["추가", "일정"]) {
            return motivation(c)
        }
        // "수학 50점 받았어", "영어 92점"
        if let m = t.firstMatch(of: #/(\d{1,3})점/#), let score = Int(String(m.1)), score <= 100,
           has(t, ["받았", "나왔", "맞았", "떴", "이야", "이에요", "임", "받음"]) {
            if score >= 90 {
                return Answer(text: "\(score)점이라니, 정말 축하해요! 🎉 노력한 만큼 결과가 나왔네요. 틀린 문제만 오답노트로 정리하면 완벽해요.",
                              suggestions: ["오답노트 현황 알려줘"])
            }
            if score >= 70 {
                return Answer(text: "\(score)점, 잘했어요! 조금만 더 다듬으면 더 올라갈 수 있어요. 틀린 문제를 유형별로 나눠 보면 어디를 보완할지 보여요.",
                              suggestions: ["오답노트 현황 알려줘", "수학 공부법"])
            }
            return Answer(text: "\(score)점이라 속상하겠어요. 그래도 지금이 제일 많이 오를 수 있는 때예요.\n1. 틀린 문제를 오답노트에 저장\n2. 틀린 이유를 '개념 / 실수 / 시간'으로 나누기\n3. 개념이 부족한 단원부터 'AI 학습'으로 다시 보기\n다음 시험에서 꼭 오를 거예요!",
                          suggestions: ["오답노트 현황 알려줘", "다음 시험 D-Day 설정해줘"])
        }
        // "시험 2주 남았는데 뭐부터 해?", "시험까지 5일 남았어"
        if has(t, ["시험", "모의고사", "중간고사", "기말고사", "수능"]), has(t, ["남았", "남음", "남은"]),
           let m = t.firstMatch(of: #/(\d+)(일|주|달|개월)/#), let n = Int(String(m.1)) {
            let unit = String(m.2)
            let days = unit == "주" ? n * 7 : (unit == "일" ? n : n * 30)
            return examCountdown(days: days)
        }
        // "수학이 너무 어려워", "영어 못하겠어"
        let subjects = ["수학", "영어", "국어", "과학", "사회", "역사", "한국사"]
        if let subject = subjects.first(where: { t.contains($0) }), has(t, ["어려", "모르겠", "못하겠", "포기", "자신없", "싫어", "막막", "안돼", "안 돼"]),
           !has(t, ["추가", "일정", "타이머", "퀴즈", "문제내"]) {
            let key = subject == "역사" || subject == "한국사" ? "사회" : subject
            var answer = studyMethod(key)
            answer.text = "\(subject)\(["수학", "과학"].contains(subject) ? "이" : "가") 어렵게 느껴질 때는 누구나 있어요. 처음부터 다 잘할 필요 없어요. 한 단원, 한 문제씩 가봐요.\n\n" + answer.text
            return answer
        }
        return nil
    }

    /// "~할 수 있어?" 에 대한 답: 할 수 있다고 하고 바로 쓸 수 있는 예시를 보여줌
    private static func capability(_ t: String) -> Answer {
        if has(t, ["영어", "문법", "단어", "영단어"]) {
            return Answer(text: "네, 할 수 있어요! 문법 개념, 동사 변화, 문장 고치기, 단어 뜻을 바로 알려드려요.\n예: \"현재완료 설명해줘\", \"write 과거분사\", \"He go to school 문법 맞아?\"",
                          suggestions: ["현재완료 설명해줘", "영어 퀴즈 내줘"])
        }
        if has(t, ["과학", "물리", "화학", "생명", "원소"]) {
            return Answer(text: "네, 할 수 있어요! 공식 계산, 원소, 화학식량, 단위 변환, 개념 설명을 도와드려요.\n예: \"전압 12V 저항 4Ω 전류는?\", \"H2SO4 몰질량\", \"광합성이 뭐야?\"",
                          suggestions: ["광합성이 뭐야?", "과학 퀴즈 내줘"])
        }
        if has(t, ["사회", "역사", "한국사", "경제", "지리"]) {
            return Answer(text: "네, 할 수 있어요! 역사 사건과 연도, 나라와 수도, 사회 개념을 알려드려요.\n예: \"임진왜란 언제 일어났어?\", \"기회비용이 뭐야?\"",
                          suggestions: ["기회비용이 뭐야?", "사회 퀴즈 내줘"])
        }
        var example = "\"x² − 5x + 6 = 0 풀어줘\", \"x+y=5, x−y=1\""
        var chips = ["y = x² − 4x + 1 꼭짓점", "수학 퀴즈 내줘"]
        if has(t, ["이차함수", "함수"]) {
            example = "\"y = x² − 4x + 1 의 꼭짓점\", \"y = −2x² + 8x − 3 최댓값\", \"y = x² − 2x 에서 0 ≤ x ≤ 3 최대 최소\""
            chips = ["y = x² − 4x + 1 꼭짓점", "y = x² − 2x 에서 0 ≤ x ≤ 3 최대 최소"]
        } else if has(t, ["미분", "적분"]) {
            example = "\"f(x) = x³ − 3x 극값\", \"x² + 2x 0부터 3까지 적분\""
            chips = ["f(x) = x³ − 3x 극값"]
        }
        return Answer(text: "네, 풀 수 있어요! 문제를 식으로 보내주면 단계별로 풀어드려요. 문제 사진을 + 버튼으로 보내도 돼요.\n예: \(example)",
                      suggestions: chips)
    }

    private static func examCountdown(days: Int) -> Answer {
        let plan: String
        switch days {
        case ..<2:
            plan = "**시험 직전**\n• 새로운 것 말고 오답노트·핵심 정리만\n• 자주 틀린 공식·용어 한 장 정리\n• 꼭 5~6시간은 자기"
        case 2...7:
            plan = "**\(days)일 계획**\n• 1~\(max(1, days - 2))일차: 과목별 핵심 개념 + 대표 문제\n• 다음 날: 기출·문제집으로 실전 연습\n• 마지막 날: 오답노트와 암기 내용 최종 점검\n• 매일 아침에 전날 공부한 것 10분 복습"
        case 8...21:
            plan = "**\(days)일 계획 (3회독)**\n• 앞의 40%: 1회독 — 교과서·개념 정리, 단원별 기본 문제\n• 다음 40%: 2회독 — 문제집·기출, 틀린 문제 오답노트\n• 마지막 20%: 3회독 — 오답 다시 풀기, 암기 과목 집중\n• 하루에 2~3과목을 섞어서 (한 과목만 몰아서 하지 않기)"
        default:
            plan = "**\(days)일 계획**\n• 지금은 개념을 탄탄히: 하루 1~2단원씩 개념 + 기본 문제\n• 주말마다 그 주에 배운 것 복습\n• 시험 3주 전부터 기출 위주 3회독으로 전환\n• 약한 과목은 매일 30분이라도 꾸준히"
        }
        return Answer(text: "시험까지 \(days)일 남았군요. 이렇게 해봐요.\n\(plan)\n\nD-Day를 설정하면 홈에서 남은 날을 계속 보여줘요.",
                      suggestions: ["기말고사 D-Day 12월 10일로 설정해줘", "내일 오후 7시 수학 공부 2시간 추가해줘"])
    }

    // MARK: - 답변 만들기

    private static func greeting(_ c: Context) -> Answer {
        let hour = Calendar.current.component(.hour, from: c.now)
        let line: String
        switch hour {
        case 5..<11: line = pick(["좋은 아침이에요! ☀️", "안녕하세요, 상쾌한 아침이에요!"])
        case 11..<14: line = "안녕하세요! 점심은 챙겨 먹었어요?"
        case 14..<18: line = pick(["안녕하세요! 오후도 힘내봐요.", "반가워요! 나른한 오후, 같이 집중해봐요."])
        case 18..<23: line = "안녕하세요! 오늘 하루 어땠어요?"
        default: line = "늦은 시간까지 수고가 많아요. 너무 무리하지 말아요!"
        }
        var status = ""
        if c.todayMinutes > 0 { status = " 오늘 벌써 \(duration(c.todayMinutes)) 공부했어요." }
        if c.remainingPlans > 0 { status += " 남은 플랜은 \(c.remainingPlans)개예요." }
        return Answer(text: "\(line)\(status)\n무엇을 도와드릴까요?", suggestions: ["오늘 할 일 알려줘", "뭐 할 수 있어?", "퀴즈 내줘"])
    }

    private static func goodNight(_ c: Context) -> Answer {
        var text = "오늘도 정말 수고 많았어요. 푹 자야 오늘 공부한 게 머릿속에 잘 저장돼요. 잘 자요 🌙"
        if c.todayMinutes > 0 { text = "오늘 \(duration(c.todayMinutes)) 공부했어요. " + text }
        return Answer(text: text, suggestions: ["내일 일정 알려줘"])
    }

    private static func tired(_ c: Context) -> Answer {
        let hour = Calendar.current.component(.hour, from: c.now)
        if hour >= 23 || hour < 5 {
            return Answer(text: "많이 늦었어요. 지금은 억지로 버티기보다 자는 게 더 남는 장사예요. 자는 동안 뇌가 오늘 공부한 걸 정리해 줘요. 남은 건 내일 아침 플랜으로 옮겨둘까요?",
                          suggestions: ["내일 오전 8시 복습 추가해줘", "타이머 종료해줘"])
        }
        return Answer(text: pick([
            "졸릴 땐 이렇게 해봐요.\n• 찬물로 세수하거나 물 한 잔 마시기\n• 일어서서 2~3분 스트레칭\n• 15~20분 짧은 낮잠 (그 이상은 더 피곤해져요)\n• 소리 내서 읽거나 손으로 쓰는 공부로 바꾸기",
            "피곤하면 잠깐 쉬어도 괜찮아요. 10분 쉬고 25분만 집중해 보는 건 어때요? 짧게 끊어 하면 훨씬 덜 지쳐요."
        ]), suggestions: ["25분 타이머 시작해줘"])
    }

    private static func hardTime(_ c: Context) -> Answer {
        var text = pick([
            "많이 힘들었겠어요. 여기까지 온 것만으로도 충분히 잘하고 있는 거예요.",
            "지칠 만큼 열심히 했다는 뜻이에요. 잠깐 숨 돌려도 괜찮아요."
        ])
        text += "\n\n지금은 큰 목표 말고 **딱 하나, 10분짜리**만 해봐요. 작은 걸 끝내면 다시 힘이 생겨요."
        if c.todayMinutes > 0 { text += "\n오늘 이미 \(duration(c.todayMinutes))이나 공부했어요. 대단해요." }
        text += "\n혼자 감당하기 어려울 만큼 힘들면 믿을 수 있는 어른이나 청소년상담 1388에 이야기해 보세요."
        return Answer(text: text, suggestions: ["10분 타이머 시작해줘", "명언 하나 알려줘"])
    }

    private static func stressed() -> Answer {
        Answer(text: "스트레스 받을 땐 몸부터 풀어줘요.\n**4-7-8 호흡**: 4초 들이마시고 → 7초 멈추고 → 8초 내쉬기를 3번 해봐요.\n그다음 지금 머릿속에 있는 걱정을 메모에 적어두면 머리가 한결 가벼워져요. 적어둔 건 제가 보관해 둘게요.",
               suggestions: ["메모해줘: ", "5분 타이머 시작해줘"])
    }

    private static func sad() -> Answer {
        Answer(text: "마음이 많이 힘들었군요. 그런 날도 있어요. 억지로 괜찮은 척 안 해도 돼요.\n좋아하는 음악을 듣거나 잠깐 산책하는 것도 도움이 돼요. 그리고 마음을 털어놓을 사람이 있다면 꼭 이야기해 보세요. 친구, 가족, 선생님, 아니면 청소년상담 **1388**(전화·문자·카카오톡)도 언제든 들어줘요.\n저도 여기 있을게요.")
    }

    private static func anxious(_ t: String) -> Answer {
        if t.contains("시험") || t.contains("발표") || t.contains("면접") {
            return Answer(text: "긴장되는 건 그만큼 잘하고 싶다는 뜻이에요.\n• 천천히 숨 쉬기: 4초 들이마시고 6초 내쉬기\n• '긴장된다' 대신 '설렌다'라고 말해보기 (실제로 효과가 있어요)\n• 시험 직전엔 새로운 것 말고 오답노트와 핵심 정리만 훑어보기\n준비한 만큼 충분히 해낼 수 있어요!",
                          suggestions: ["오답노트 현황 알려줘", "명언 하나 알려줘"])
        }
        return Answer(text: "불안할 땐 걱정을 구체적으로 적어보는 게 도움이 돼요. '내가 지금 할 수 있는 것'과 '어쩔 수 없는 것'을 나눠 보고, 할 수 있는 것 하나부터 해봐요. 필요하면 메모로 남겨둘게요.",
               suggestions: ["메모해줘: "])
    }

    private static func exam_bad() -> Answer {
        Answer(text: "속상하겠어요. 그래도 한 번의 시험이 당신을 다 말해주진 않아요.\n이렇게 다시 시작해 봐요.\n1. 틀린 문제를 오답노트에 저장 (사진 한 장이면 돼요)\n2. 틀린 이유를 '개념 / 실수 / 시간 부족'으로 나누기\n3. 다음 시험 D-Day를 정하고 약한 단원부터 플랜 잡기\n다음엔 분명 더 잘할 거예요.",
               suggestions: ["다음 시험 D-Day 설정해줘", "오답노트 현황 알려줘"])
    }

    private static func motivation(_ c: Context) -> Answer {
        var text = pick([
            "하기 싫은 날이 있는 게 정상이에요. 그럴 땐 '딱 5분만' 해봐요. 시작하는 게 제일 어렵고, 5분 지나면 생각보다 계속하게 돼요.",
            "의욕은 하다 보면 생겨요. 지금 책상에 앉아 책을 펴기만 해도 절반은 한 거예요!",
            "오늘의 작은 공부가 쌓여서 나중의 큰 차이를 만들어요. 1%만 해도 0%보단 훨씬 나아요."
        ])
        if c.goalMinutes > 0 {
            let left = max(0, c.goalMinutes - c.todayMinutes)
            text += left > 0 ? "\n오늘 목표까지 \(duration(left)) 남았어요." : "\n그리고 오늘 목표는 이미 달성했어요! 🎉"
        }
        return Answer(text: text, suggestions: ["5분 타이머 시작해줘", "명언 하나 알려줘"])
    }

    private static func focusTips() -> Answer {
        Answer(text: "**집중이 안 될 때**\n1. 휴대폰은 다른 방이나 가방 속에 (보이기만 해도 집중력이 떨어져요)\n2. 25분 타이머를 켜고 그동안 한 과목만 하기\n3. 시작 전에 '이번 25분 동안 할 일'을 한 줄로 정하기\n4. 책상 위에는 지금 공부할 것만\n5. 백색소음이나 빗소리 켜기 (타이머 화면)\n공부 플랜의 '다른 앱 잠금'을 쓰면 정해둔 시간 동안 다른 앱을 막을 수도 있어요.",
               suggestions: ["25분 타이머 시작해줘", "타이머 화면 열어줘"])
    }

    private static func slump() -> Answer {
        Answer(text: "슬럼프는 열심히 달려온 사람에게 오는 거예요.\n• 목표를 잠깐 낮추기: 하루 목표를 평소의 절반으로\n• 잘하는 과목·쉬운 문제로 '해냈다'는 느낌 되찾기\n• 공부 장소나 시간 바꿔보기\n• 충분히 자고, 운동 조금 하기\n1~2주 안에 대부분 지나가요. 꾸준히 기록하는 것만으로도 다시 올라올 수 있어요.",
               suggestions: ["하루 공부 목표 2시간", "이번 주 공부 통계"])
    }

    private static func memorize() -> Answer {
        Answer(text: "**잘 외우는 방법**\n1. **간격 반복**: 외운 날 → 1일 뒤 → 3일 뒤 → 1주일 뒤에 다시 보기\n2. **떠올리기 연습**: 책을 덮고 백지에 기억나는 걸 써보기 (그냥 읽는 것보다 훨씬 효과적)\n3. **나만의 연결**: 앞 글자 따기, 이야기 만들기, 그림으로 그리기\n4. **소리 내서 설명하기**: 친구에게 가르치듯 말해보기\n5. **자기 전에 복습**: 자는 동안 기억이 정리돼요\nDOOOIT의 단어 학습과 퀴즈가 1, 2번을 도와줘요.",
               suggestions: ["영어 퀴즈 내줘", "틀린 단어 알려줘"])
    }

    private static func studyMethod(_ subject: String) -> Answer {
        switch subject {
        case "수학":
            return Answer(text: "**수학 공부법**\n1. **개념 먼저**: 공식을 외우기 전에 왜 그런지 교과서 설명을 이해하기\n2. **예제 → 유제**: 예제를 보고 이해한 뒤, 비슷한 문제를 혼자 풀기\n3. **풀이 과정 쓰기**: 머리로만 풀지 말고 한 줄씩 적기 (실수가 줄어요)\n4. **오답 다시 풀기**: 틀린 문제는 3일 뒤에 해설 없이 다시\n5. **시간 재고 풀기**: 시험 전엔 실제 시간처럼\n모르는 식은 저에게 \"x² − 5x + 6 = 0 풀어줘\"처럼 물어봐요.",
                          suggestions: ["수학 퀴즈 내줘", "오답노트 현황 알려줘"])
        case "영어":
            return Answer(text: "**영어 공부법**\n1. **단어는 매일 조금씩**: 하루 20~30개, 간격 반복으로\n2. **문장으로 외우기**: 단어만 말고 예문과 함께\n3. **문법은 예문 중심**: 규칙 + 예문 2개를 같이 기억\n4. **독해는 주제문 찾기**: 첫 문장과 마지막 문장, 역접(However, But) 뒤를 주목\n5. **소리 내어 읽기**: 발음 연습 기능도 써보세요\n문법이 궁금하면 \"현재완료 설명해줘\", \"go 과거형\"처럼 물어봐요.",
                          suggestions: ["영어 퀴즈 내줘", "관계대명사 설명해줘"])
        case "국어":
            return Answer(text: "**국어 공부법**\n1. **문학**: 화자·상황·정서·표현법을 작품마다 정리\n2. **비문학**: 문단마다 핵심 한 줄 요약, 글의 구조(문제-해결, 비교-대조) 파악\n3. **문법**: 개념 정리 후 예시를 직접 분석해 보기\n4. **기출 분석**: 선택지가 왜 틀렸는지 근거를 지문에서 찾기\n5. **시간 관리**: 지문당 시간을 정해두고 연습",
                          suggestions: ["음운의 변동이 뭐야?"])
        case "과학":
            return Answer(text: "**과학 공부법**\n1. **원리 이해**: 현상 → 원인 → 결과를 이야기처럼 연결\n2. **그림·그래프 그리기**: 실험 과정과 그래프를 직접 그려보기\n3. **공식은 단위와 함께**: F = ma 에서 N = kg·m/s² 처럼\n4. **개념어 정확히**: 비슷한 용어(확산/삼투, 산화/환원) 비교표 만들기\n5. **계산 문제는 반복**: 저에게 \"질량 2kg 가속도 3m/s² 힘은?\"처럼 물어봐요",
                          suggestions: ["과학 퀴즈 내줘", "광합성이 뭐야?"])
        default:
            return Answer(text: "**사회·역사 공부법**\n1. **흐름 먼저**: 시대 순서나 큰 틀(원인 → 사건 → 결과)을 먼저 잡기\n2. **연표·지도 활용**: 사건은 연도와 함께, 지리는 지도 위에서\n3. **개념은 사례와 함께**: '기회비용' → 실제 생활 예시 떠올리기\n4. **백지 복습**: 단원 제목만 보고 아는 걸 다 써보기\n5. **시사와 연결**: 뉴스 속 개념 찾아보기\n저에게 \"임진왜란 언제 일어났어?\", \"프랑스 수도\"처럼 물어봐요.",
                          suggestions: ["사회 퀴즈 내줘", "삼권분립이 뭐야?"])
        }
    }

    private static func generalStudy() -> Answer {
        Answer(text: "**효율적으로 공부하는 법**\n1. **계획**: 하루 할 일을 플래너에 시간과 함께 적기\n2. **집중**: 25~50분 집중 + 5~10분 휴식\n3. **떠올리기**: 읽기만 하지 말고 덮고 써보기·문제 풀기\n4. **간격 반복**: 1일·3일·7일 뒤 복습\n5. **오답 관리**: 틀린 문제는 오답노트로\n6. **잠**: 6~8시간 자야 기억이 정리돼요\n과목별 방법이 궁금하면 \"수학 공부법\", \"영어 공부법\"처럼 물어봐요.",
               suggestions: ["수학 공부법", "영어 공부법", "암기법 알려줘"])
    }

    private static func examPlan(_ c: Context) -> Answer {
        var text = "**시험 기간 계획 세우기**\n1. **D-Day 정하기**: 시험 날짜를 설정해요\n2. **범위 나누기**: 과목별 범위를 단원 단위로 쪼개기\n3. **3회독 계획**: 1회독(개념) → 2회독(문제) → 3회독(오답·암기)\n4. **약한 과목 먼저**: 시간이 많이 걸리는 과목을 앞쪽에\n5. **시험 전 3일**: 새로운 것 대신 복습과 오답만\n6. **매일 플래너 체크**: 못 한 건 다음 날로 옮기기"
        if let d = c.dDay { text += "\n\n지금 설정된 목표: \(d)" }
        return Answer(text: text, suggestions: ["기말고사 D-Day 12월 10일로 설정해줘", "내일 오후 7시 수학 공부 2시간 추가해줘"])
    }

    private static func cramTips() -> Answer {
        Answer(text: "**시험 전날 이렇게 해요**\n1. 새로운 내용보다 **핵심 정리 + 오답노트** 위주\n2. 자주 나오는 공식·용어를 한 장에 모아 반복해서 보기\n3. 문제는 쉬운 것부터 풀어 자신감 챙기기\n4. **최소 5~6시간은 자기** (밤새우면 아는 것도 실수해요)\n5. 아침에 30분, 정리 노트만 한 번 더\n할 수 있어요! 💪",
               suggestions: ["오답노트 현황 알려줘", "틀린 단어 알려줘"])
    }

    private static func planning() -> Answer {
        Answer(text: "**계획을 잘 지키는 법**\n1. **작게 쪼개기**: '수학 공부' 대신 '수학 2단원 예제 10문제'\n2. **시간 정하기**: 할 일마다 시작 시간을 정해두면 실행률이 올라가요 (공부 플랜은 시간이 되면 타이머가 자동으로 켜져요)\n3. **80%만 채우기**: 계획을 꽉 채우면 무너지기 쉬워요. 여유 시간을 남겨요\n4. **밤에 체크**: 한 건 완료, 못 한 건 내일로\n5. **작심삼일도 괜찮아요**: 3일마다 다시 시작하면 돼요!",
               suggestions: ["오늘 할 일 알려줘", "내일 오후 4시에 영어 공부 1시간 추가해줘"])
    }

    private static func praise(_ c: Context) -> Answer {
        if c.todayMinutes <= 0 {
            return Answer(text: "그 마음가짐 좋아요! 타이머로 기록하면 제가 공부 시간도 같이 챙겨드릴게요.", suggestions: ["25분 타이머 시작해줘"])
        }
        let ratio = c.goalMinutes > 0 ? Double(c.todayMinutes) / Double(c.goalMinutes) : 0
        let comment = ratio >= 1 ? "오늘 목표를 달성했어요! 정말 대단해요 🎉" : ratio >= 0.5 ? "목표의 절반을 넘었어요. 이 페이스 좋아요!" : "시작이 반이에요. 조금만 더 가봐요!"
        return Answer(text: "오늘 \(duration(c.todayMinutes)) 공부했어요. \(comment)", suggestions: ["오늘 공부 통계"])
    }

    /// 위기 신호 (이 답은 두뇌가 바꾸지 않고 상담 번호를 그대로 알려줌)
    static func isCrisis(_ text: String) -> Bool {
        let t = squash(text)
        return ["죽고싶", "자살", "자해", "죽어버리", "살기싫", "사라지고싶", "목숨", "극단적선택"].contains { t.contains($0) }
    }

    private static func crisis() -> Answer {
        Answer(text: "그런 생각이 들 만큼 많이 힘들었군요. 이야기해 줘서 고마워요. 지금 그 마음, 혼자 견디지 않았으면 좋겠어요.\n\n지금 바로 이야기할 수 있는 곳이 있어요.\n• **자살예방상담전화 109** (24시간)\n• **청소년상담 1388** (전화·문자·카카오톡, 24시간)\n• 위급하면 **112** 또는 **119**\n\n가까운 가족이나 선생님, 친구에게도 꼭 알려주세요. 당신은 소중한 사람이에요.")
    }

    // MARK: - 재료

    static let jokes = [
        "세상에서 가장 가난한 왕은? 최저임금 👑",
        "수학책이 슬픈 이유는? 문제가 너무 많아서 😢",
        "왕이 넘어지면? 킹콩 🦍",
        "바나나가 웃으면? 바나나킥 🍌",
        "자동차를 톡 치면? 카톡 🚗",
        "소금의 유통기한은? 천일염 (천 일) 🧂",
        "세상에서 가장 뜨거운 과일은? 천도복숭아 🍑",
        "컴퓨터가 싫어하는 술은? 버그주 🍺",
        "물고기의 반대말은? 불고기 🐟",
        "가장 무서운 수학 기호는? 루트... 끝까지 안 풀려서 √",
        "영어 선생님이 좋아하는 음료는? 티(tea)처 ☕",
        "피자가 웃으면? 피자헛 🍕"
    ]

    static let quotes = [
        "\"성공은 매일 반복한 작은 노력들의 합이다.\" — 로버트 콜리어",
        "\"천천히 가는 것을 두려워하지 말고, 멈추는 것을 두려워하라.\" — 중국 속담",
        "\"오늘 할 수 있는 일에 최선을 다하라. 그러면 내일 한 걸음 더 나아갈 수 있다.\" — 아이작 뉴턴",
        "\"배움에는 왕도가 없다.\" — 유클리드",
        "\"천재는 1%의 영감과 99%의 노력으로 이루어진다.\" — 토머스 에디슨",
        "\"시작이 반이다.\" — 아리스토텔레스",
        "\"넘어지는 것은 부끄러운 일이 아니다. 일어나지 않는 것이 부끄러운 일이다.\"",
        "\"할 수 있다고 믿든, 할 수 없다고 믿든, 당신 말이 맞다.\" — 헨리 포드",
        "\"작은 기회로부터 종종 위대한 업적이 시작된다.\" — 데모스테네스",
        "\"노력은 배신하지 않는다. 다만 시간이 조금 걸릴 뿐이다.\""
    ]

    // MARK: - 도구

    static func squash(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace && !"?!.,~…".contains($0) }
    }

    private static func has(_ t: String, _ words: [String]) -> Bool { words.contains { t.contains($0) } }

    private static func pick(_ list: [String]) -> String { list.randomElement() ?? "" }

    private static func duration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)분" }
        return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    // MARK: - 퀴즈 채점

    /// 정답 비교용으로 정리 (띄어쓰기·기호·끝말 제거)
    static func normalizeAnswer(_ text: String) -> String {
        var t = text.lowercased().filter { !$0.isWhitespace }
        for (from, to) in [("−", "-"), ("–", "-"), ("×", "*"), ("²", "^2"), ("³", "^3")] { t = t.replacingOccurrences(of: from, with: to) }
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: ".!?~\"'`"))
        for suffix in ["입니다", "이에요", "예요", "이요", "요", "인것같아", "같아", "일걸", "일듯"] where t.hasSuffix(suffix) && t.count > suffix.count {
            t.removeLast(suffix.count)
        }
        for prefix in ["정답은", "답은", "답:", "정답:", "x="] where t.hasPrefix(prefix) && t.count > prefix.count {
            t.removeFirst(prefix.count)
        }
        return t
    }

    static func isCorrect(_ given: String, item: DoitQuizItem) -> Bool {
        let g = normalizeAnswer(given)
        guard !g.isEmpty else { return false }
        for answer in item.answers {
            let options = answer.split(whereSeparator: { $0 == "," || $0 == "/" || $0 == ";" }).map { normalizeAnswer(String($0)) } + [normalizeAnswer(answer)]
            for option in options where !option.isEmpty {
                if g == option { return true }
                if let a = Double(g), let b = Double(option), abs(a - b) < 1e-9 { return true }
                // 뜻 문제: 핵심 낱말이 들어 있으면 정답 (예: "풍부한" ↔ "풍부하다")
                if option.count >= 2, g.count >= 2, option.range(of: "^[가-힣]+$", options: .regularExpression) != nil {
                    let stem = String(option.prefix(max(2, option.count - 1)))
                    if g.hasPrefix(stem) || option.hasPrefix(String(g.prefix(max(2, g.count - 1)))) { return true }
                }
            }
        }
        return false
    }

    /// 힌트: 정답의 첫 글자와 글자 수
    static func hint(for item: DoitQuizItem) -> String {
        guard let answer = item.answers.first?.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespaces), let first = answer.first else {
            return "힌트를 만들 수 없어요."
        }
        return "힌트: '\(first)'(으)로 시작하고 \(answer.filter { !$0.isWhitespace }.count)글자예요."
    }
}
