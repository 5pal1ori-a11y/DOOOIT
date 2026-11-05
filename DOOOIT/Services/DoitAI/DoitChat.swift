import Foundation

/// 모티 AI 퀴즈 한 문제 (정답은 여러 개 허용)
struct DoitQuizItem {
    let question: String
    let answers: [String]
    let explanation: String
}

/// 모티 AI 일상 대화 (외부 AI 없이 직접 만든 규칙형)
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
        /// 답의 종류 ("joke", "greeting" …): 다음 말에서 앞 이야기를 이어 받을 때 씀
        var kind: String? = nil
        /// 답에서 제안한 일 ("퀴즈 한 판 할까요?" → "퀴즈 내줘"): 학생이 "응"이라고 하면 그대로 함
        var offer: String? = nil
    }

    // MARK: - 진입점

    static func reply(_ raw: String, context: Context) -> Answer? {
        guard let answer = route(raw, context: context) else { return nil }
        DoitTone.remember(answer.text, kind: answer.kind, offer: answer.offer)
        return answer
    }

    private static func route(_ raw: String, context: Context) -> Answer? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let t = squash(text)

        // 0) 위기 신호는 가장 먼저, 진지하게
        if isCrisis(raw) { return crisis() }

        // 1) 욕·무례한 말: 훈계하지 않고 짧게, 차분하게
        if let rude = rude(t) { return rude }
        // 2) 모티 자신에 대한 질문 (어떤 AI인지, 모티 1·2·ZERO 차이, 인터넷, 말이 이상하다는 말)
        if let meta = meta(t) { return meta }
        // 3) 짧은 줄임말·맞장구 ("ㅇㅈ", "헐", "바이", "그냥") — 낱말이 통째로 같을 때만
        if let short = shortTalk(t, context) { return short }
        if let special = specialCases(text, t, context) { return special }
        for rule in rules where rule.matches(t, text) {
            return rule.make(text, t, context)
        }
        return nil
    }

    /// 여러 답 중 하나 (답마다 제안하는 일이 다를 때)
    private static func pick(_ options: [(String, String?)]) -> (text: String, offer: String?) {
        let text = DoitTone.pick(options.map(\.0))
        return (text, options.first { $0.0 == text }?.1 ?? nil)
    }

    // MARK: - 규칙

    private struct Rule {
        var words: [String]
        var maxLength: Int = 60
        var exclude: [String] = []
        /// 이 말로 시작할 때만 (예: "이름이 뭐야" — "사장님 이름이 뭐야"는 아님)
        var prefixes: [String] = []
        /// 말 전체가 이 말과 같을 때만 ("네"가 "개못하네" 속에서 맞장구로 잡히지 않게)
        var exact: Set<String> = []
        var make: (String, String, Context) -> Answer

        func matches(_ t: String, _ original: String) -> Bool {
            guard t.count <= maxLength, !exclude.contains(where: { t.contains($0) }) else { return false }
            if exact.contains(t.trimmingCharacters(in: CharacterSet(charactersIn: "ㅎㅋ~^"))) { return true }
            return words.contains { DoitChat.contains(t, original, $0) } || prefixes.contains { t.hasPrefix($0) }
        }
    }

    private static let rules: [Rule] = [
        // 인사
        Rule(words: ["안녕", "하이", "ㅎㅇ", "반가워", "반갑", "hello", "hi", "hey", "좋은아침", "굿모닝", "goodmorning", "안뇽", "안냥", "하잉", "하이루", "방가", "헬로", "좋은저녁", "굿이브닝", "좋은오후"], maxLength: 14,
             exclude: ["잘자", "안녕히", "잘있어"]) { _, t, c in
            // "좋은 아침"에는 시간과 상관없이 아침 인사로
            greeting(c, morning: ["좋은아침", "굿모닝", "goodmorning"].contains(where: { t.contains($0) }),
                     evening: ["좋은저녁", "굿이브닝"].contains(where: { t.contains($0) }))
        },
        Rule(words: ["잘자", "굿나잇", "goodnight", "잘게", "자러갈", "자야겠", "이제잘", "굿밤", "자러감", "자러가"], maxLength: 20) { _, _, c in goodNight(c) },
        Rule(words: ["안녕히", "잘있어", "바이바이", "bye", "내일봐", "다음에봐", "나갈게", "이만"], maxLength: 16) { _, _, _ in
            Answer(text: pick(["오늘도 수고 많았어요. 또 봐요!", "좋아요, 다음에 봐요. 계획한 건 제가 잘 챙겨 둘게요.", "수고했어요! 쉬는 것도 공부의 일부예요.", "다음에 또 와요! 기다릴게요 😊"]))
        },
        // 고마움 · 사과 · 칭찬 · 짜증
        Rule(words: ["고마워", "고맙", "감사", "땡큐", "thank", "thx", "ㄱㅅ", "ㄳ"], maxLength: 20) { _, _, _ in
            // 바로 전에 설명·풀이를 했으면 그 이야기를 이어 받음
            if DoitTone.previousKind == "study" {
                return Answer(text: pick(["도움이 됐다니 다행이에요! 헷갈리면 또 물어봐요.", "천만에요! 이해됐다니 저도 뿌듯해요 😊", "별말을요. 퀴즈로 한 번 확인해 봐도 좋아요."]),
                              suggestions: ["이걸로 퀴즈 내줘", "오늘 할 일 알려줘"], kind: "thanks")
            }
            return Answer(text: pick(["천만에요! 😊", "별말을요. 또 필요하면 불러 줘요.", "도움이 됐다니 다행이에요.", "언제든요! 오늘도 같이 힘내요."]),
                          suggestions: ["오늘 할 일 알려줘", "퀴즈 내줘"], kind: "thanks")
        },
        Rule(words: ["미안", "죄송", "sorry"], maxLength: 20) { _, _, _ in
            Answer(text: pick(["괜찮아요! 신경 쓰지 마요.", "전혀 괜찮아요. 이어서 해 볼까요?", "괜찮아요, 그럴 수도 있죠 😊"]))
        },
        Rule(words: ["잘했어", "똑똑하", "최고야", "최고다", "너대박", "천재", "멋지다", "멋져", "짱이"], maxLength: 20,
             exclude: ["기분", "오늘", "하루", "나", "내가", "날씨", "점수", "성적"]) { _, _, _ in
            Answer(text: pick(["칭찬 고마워요! 더 잘해 볼게요 😊", "헤헤, 고마워요. 그래도 꾸준히 공부하는 쪽이 진짜 대단한 거예요!", "앗, 칭찬받으니까 기분 좋네요 ㅎㅎ 고마워요!"]))
        },
        Rule(words: ["바보", "멍청", "쓸모없", "짜증나게하", "못알아듣", "이해를못", "답답해너"], maxLength: 30) { _, _, _ in
            Answer(text: pick(["앗, 제가 잘못 알아들었나 봐요. 미안해요! 조금 다르게 말해 주면 다시 해 볼게요.\n예: \"내일 오후 3시 영어 공부 추가해줘\", \"x² − 4 = 0 풀어줘\", \"광합성이 뭐야?\"",
                               "미안해요, 제가 헛짚었나 봐요. 하고 싶은 걸 한 번만 더 말해 줄래요?"]),
                   suggestions: ["뭐 할 수 있어?"])
        },
        Rule(words: ["사랑해", "좋아해너", "너좋아", "너가좋"], maxLength: 16) { _, _, _ in
            Answer(text: pick(["저도요! 같이 공부하는 시간이 좋아요 😊", "고마워요 💛 그 마음으로 오늘 목표까지 같이 가 봐요!", "헤헤, 저도 좋아해요!"]))
        },
        // 모티 AI 자신
        Rule(words: ["누가널만", "누가너만", "너누가만", "넌누가만", "모티누가만", "너만든사람", "모티만든사람", "이앱누가", "앱누가만"], maxLength: 16,
             prefixes: ["누가만들었어", "누가만든거야", "누가만들었냐", "누가만듦"]) { _, _, _ in
            Answer(text: "저는 MOTI 앱에 들어 있는 도우미라 MOTI를 만든 사람들이 만들었어요. 그 이상 자세한 건 저도 몰라요.", suggestions: ["너 누구야?"], kind: "meta")
        },
        Rule(words: ["너누구", "넌누구", "너는누구", "너이름", "니이름", "네이름", "너의이름", "당신이름", "넌이름", "너는이름", "넌뭐야", "너뭐야", "자기소개", "whoareyou"], maxLength: 24,
             exclude: ["내이름", "제이름", "나이름"], prefixes: ["이름이뭐", "이름뭐"]) { _, _, _ in
            Answer(text: identity() + "\n일정·타이머·단어를 챙기고, 수학 풀이와 과목 질문, 퀴즈를 도와줘요.",
                   suggestions: ["뭐 할 수 있어?", "모티 1이랑 뭐가 달라?"], kind: "meta")
        },
        Rule(words: ["사람이야", "로봇이야", "진짜사람"], maxLength: 20) { _, _, _ in
            Answer(text: "저는 사람은 아니고, MOTI에 들어 있는 AI 도우미예요. 대신 공부할 땐 누구보다 성실하게 옆에 있을게요!")
        },
        Rule(words: ["뭐해", "뭐하고있", "모해", "머해", "뭐하냐", "머하냐", "모하냐", "뭐함", "머함", "뭐하니"], maxLength: 12, exclude: ["뭐해야", "뭐해줄", "뭐해줘", "뭐해도"]) { _, _, c in
            let opener = pick(["불러 주기만 기다리고 있었어요!", "저야 늘 여기 있죠 ㅎㅎ", "마침 심심하던 참이었어요!"])
            let rest = c.remainingPlans > 0 ? pick(["오늘 남은 플랜이 \(c.remainingPlans)개 있는데, 하나 같이 해치울까요?", "남은 플랜 \(c.remainingPlans)개, 하나씩 해 볼까요?"])
                                            : pick(["뭐 하고 있었어요?", "오늘은 뭐 할 거예요?"])
            return Answer(text: "\(opener) \(rest)", suggestions: ["오늘 할 일 알려줘", "25분 타이머 시작해줘"],
                          offer: c.remainingPlans > 0 ? "오늘 할 일 알려줘" : nil)
        },
        Rule(words: ["기분어때", "잘지냈", "잘지내", "오늘어때", "컨디션어때"], maxLength: 16) { _, _, _ in
            Answer(text: pick(["저는 늘 쌩쌩해요! 오늘은 어때요?", "잘 지냈죠! 요즘 공부는 할 만해요?", "저야 언제나 좋아요 ㅎㅎ 오늘 컨디션은 어때요?"]))
        },

        // 감정 · 컨디션
        Rule(words: ["피곤", "졸려", "졸리", "졸린", "졸음", "잠와", "잠온", "잠이와", "잠이온", "꾸벅", "자고싶", "잠자고싶"]) { _, t, c in tired(t, c) },
        Rule(words: ["힘들", "지쳤", "지친다", "지침", "버거", "벅차", "포기하고싶", "그만두고싶", "번아웃"]) { _, t, c in hardTime(t, c) },
        Rule(words: ["스트레스", "짜증나", "짜증난", "화나", "열받", "빡쳐", "빡친"]) { _, t, _ in stressed(t) },
        Rule(words: ["우울", "슬퍼", "슬프", "외로", "눈물", "울고싶", "울었", "속상"]) { _, t, _ in sad(t) },
        Rule(words: ["불안", "긴장", "떨려", "걱정돼", "걱정된", "무서워"]) { _, t, _ in anxious(t) },
        Rule(words: ["망했", "망쳤", "망함", "망침", "망쳐", "조졌", "말아먹", "떨어졌", "못봤", "성적이안", "점수가안", "등급떨어", "점수떨어"], exclude: ["안망", "잘봤"]) { _, _, _ in exam_bad() },
        Rule(words: ["잘봤", "100점", "만점", "1등급", "올랐어", "성적올", "합격", "붙었"], exclude: ["어떻게", "방법"]) { _, _, _ in
            Answer(text: pick(["와, 정말 축하해요! 🎉 꾸준히 해 온 게 결과로 나온 거예요.", "대단해요! 오늘은 스스로를 마음껏 칭찬해 줘요.", "역시 잘했어요! 노력한 보람이 있네요 👏 이 기세로 다음 목표도 잡아 볼까요?"]),
                   suggestions: ["다음 시험 D-Day 설정해줘", "이번 주 공부 통계"])
        },
        Rule(words: ["기분좋", "행복", "신나", "최고의날", "좋은일"], maxLength: 30) { _, _, _ in
            Answer(text: pick(["좋은 일이 있었군요! 저까지 기분이 좋아져요 😊", "오, 무슨 좋은 일 있었어요? 궁금해요!", "기분 좋은 날엔 공부도 잘돼요. 이 기세 그대로 가 봐요!"]))
        },
        Rule(words: ["심심", "할거없", "할게없", "지루", "노잼"], maxLength: 24) { _, _, _ in
            let (text, offer) = pick([("심심할 땐 퀴즈 한 판 어때요? 과목만 골라 줘요.", "퀴즈 내줘"),
                                      ("그럼 신기한 사실 하나 들려줄까요? 퀴즈도 좋고요.", "신기한 사실 알려줘"),
                                      ("심심하면 저랑 단어 퀴즈 한 판 해요! 시간 금방 가요.", "내 단어로 퀴즈 내줘")])
            return Answer(text: text, suggestions: ["수학 퀴즈 내줘", "영어 퀴즈 내줘", "재밌는 사실 알려줘"], offer: offer)
        },
        Rule(words: ["배고파", "배고프", "출출"], maxLength: 20) { _, _, _ in
            Answer(text: pick(["밥은 꼭 챙겨 먹어요! 뇌도 에너지가 있어야 일해요.",
                               "출출하면 바나나나 견과류처럼 가벼운 간식 어때요? 먹고 다시 달려 봐요.",
                               "배고프면 집중이 안 되죠. 뭐라도 먹고 와요 ㅎㅎ"]))
        },
        // "그냥 얘기하고 싶어", "수다 떨자"
        Rule(words: ["얘기하고싶", "이야기하고싶", "대화하고싶", "수다떨", "얘기하자", "이야기하자", "얘기좀하자", "말동무"], maxLength: 24) { _, _, _ in
            Answer(text: pick(["좋아요, 얘기해요! 오늘 뭐 했어요?", "그럼요! 요즘 제일 신경 쓰이는 게 뭐예요?", "좋죠 ㅎㅎ 아무 얘기나 해 줘요. 다 들을게요."]))
        },

        // 공부 의욕 · 공부법
        Rule(words: ["공부하기싫", "공부싫", "하기싫어", "의욕없", "의욕이없", "동기부여", "귀찮", "공부안돼", "공부가안돼", "놀고싶", "공부할맛", "공부할기분", "공부가손에", "공부가안잡"]) { _, _, c in motivation(c) },
        Rule(words: ["집중이안", "집중안", "집중이잘안", "집중력", "딴생각", "폰을자꾸", "핸드폰을자꾸", "휴대폰을자꾸", "산만", "자꾸폰", "폰만봐", "폰봐", "폰보게", "핸드폰만", "휴대폰만", "유튜브만"]) { _, t, _ in focusTips(t) },
        Rule(words: ["슬럼프"]) { _, _, _ in slump() },
        Rule(words: ["암기법", "외우는법", "외우는방법", "암기잘", "잘외우", "기억이안", "까먹", "외워지지", "안외워", "외워지질", "외워져", "외울게너무", "외울거너무", "외울게많", "외울거많", "암기할게많", "암기할거많"]) { _, _, _ in memorize() },
        Rule(words: ["몇개외워", "몇개씩외", "몇개를외", "하루에몇개", "단어몇개외"], exclude: ["추가", "목표"]) { _, _, _ in
            Answer(text: "단어는 하루 20~30개 정도가 적당해요. 새 단어보다 복습이 더 중요해서, 1일·3일·7일 뒤에 다시 보는 게 좋아요. 단어 목표를 정해 두면 매일 챙겨 드릴게요.",
                   suggestions: ["단어 목표 30개", "내 단어로 퀴즈 내줘"])
        },
        Rule(words: ["몇시간해야", "몇시간공부", "공부몇시간", "몇시간이적당", "몇시간정도해"], exclude: ["추가", "목표", "통계"]) { _, _, _ in
            Answer(text: "정답은 없지만, 평일엔 학교 수업 외에 2~4시간이 많이 쓰는 기준이에요. 시간보다 집중한 시간과 꾸준함이 더 중요해요. 하루 목표를 정해 두면 타이머로 챙겨 드릴게요.",
                   suggestions: ["하루 공부 목표 3시간", "25분 타이머 시작해줘"])
        },
        Rule(words: ["복습언제", "언제복습", "복습은언제", "복습주기", "복습어떻게", "복습은어떻게", "복습해야"]) { _, _, _ in
            Answer(text: "복습은 배운 날 10분 → 1일 뒤 → 3일 뒤 → 1주일 뒤에 다시 보는 게 가장 오래 남아요. 책을 덮고 떠올려 보는 방식이면 더 좋아요.",
                   suggestions: ["내일 오후 7시 복습 30분 추가해줘"])
        },
        Rule(words: ["숙제해야", "과제해야", "숙제를해야", "과제를해야", "공부해야돼", "공부해야해", "공부해야되", "수행평가해야", "숙제많", "할게많아"], maxLength: 30, exclude: ["추가", "일정", "어떻게", "왜", "몇"]) { _, _, _ in
            Answer(text: "할 일이 있군요! 지금 바로 할 거면 타이머를 켜고, 나중에 할 거면 시간을 말해 주면 플래너에 넣어 드릴게요.",
                   suggestions: ["25분 타이머 시작해줘", "오늘 오후 8시 숙제 1시간 추가해줘"])
        },
        Rule(words: ["수행평가준비", "수행평가어떻게", "수행평가잘", "발표준비", "보고서어떻게", "보고서쓰는"], exclude: ["추가", "일정"]) { _, _, _ in
            Answer(text: "수행평가는 평가 기준표부터 확인해요. 기준마다 필요한 걸 체크리스트로 만들고, 마감 2~3일 전에 끝내도록 단계별로 플래너에 나눠 넣으면 여유가 생겨요.",
                   suggestions: ["메모해줘: 수행평가 체크리스트", "오늘 할 일 알려줘"])
        },
        Rule(words: ["공부시간늘", "공부시간을늘", "오래앉아", "공부습관", "오래공부"], exclude: ["추가", "통계", "목표"]) { _, _, c in
            var answer = motivation(c)
            answer.text = "처음부터 오래 하려 하기보다 25분씩 늘려 가는 게 좋아요. 같은 시간·같은 자리에서 시작하면 습관이 금방 붙어요.\n" + answer.text.components(separatedBy: "\n").first!
            return answer
        },
        Rule(words: ["예습"], maxLength: 30, exclude: ["추가", "일정"]) { _, _, _ in
            Answer(text: "예습은 꼭 길게 안 해도 돼요. 수업 전에 10분만 제목·그림·굵은 글씨를 훑어 두면 수업이 훨씬 잘 들어와요. 시간이 부족하면 예습보다 복습이 먼저예요.")
        },
        Rule(words: ["틀리면어떻게", "틀리면어떡", "자꾸틀려", "계속틀려", "또틀렸", "틀린문제어떻게"]) { _, _, _ in
            Answer(text: "틀린 문제는 오히려 기회예요. 틀린 이유(개념 / 실수 / 문제 잘못 읽음)를 한 줄 적고, 해설 없이 다시 풀어 봐요. 3일 뒤 한 번 더 풀어서 맞으면 내 것이 돼요.",
                   suggestions: ["오답노트 어떻게 써?", "오답노트 현황 알려줘"])
        },
        Rule(words: ["음악들어", "음악들으면", "노래들어도", "노래들으면", "음악틀어", "노래틀어놓", "음악들으며"]) { _, _, _ in
            Answer(text: "가사 있는 노래는 글을 읽거나 외울 때 방해가 될 수 있어요. 들을 거면 가사 없는 음악이나 백색소음이 좋아요. 타이머 화면에서 빗소리·파도 소리를 켤 수 있어요.",
                   suggestions: ["타이머 화면 열어줘"])
        },
        Rule(words: ["수학공부법", "수학공부어떻게", "수학잘하", "수학어떻게공부", "수학못해", "수학이어려", "수학포기"]) { _, _, _ in studyMethod("수학") },
        Rule(words: ["영어공부법", "영어공부어떻게", "영어잘하", "영어어떻게공부", "영어못해", "영어가어려", "단어외우는법", "단어암기", "영어듣기", "듣기실력", "리스닝", "영어실력", "영단어외우"]) { _, _, _ in studyMethod("영어") },
        Rule(words: ["국어공부법", "국어공부어떻게", "국어잘하", "국어어떻게공부", "국어가어려", "비문학공부", "문학공부", "비문학어떻게", "문학어떻게", "독해력"]) { _, _, _ in studyMethod("국어") },
        Rule(words: ["과학공부법", "과학공부어떻게", "과학잘하", "과학어떻게공부", "과학이어려"]) { _, _, _ in studyMethod("과학") },
        Rule(words: ["사회공부법", "사회공부어떻게", "사회잘하", "역사공부법", "한국사공부", "사회어떻게공부", "암기과목"]) { _, _, _ in studyMethod("사회") },
        Rule(words: ["공부법", "공부방법", "공부어떻게해", "공부어떻게하", "공부잘하는법", "효율적으로공부", "공부팁"]) { _, _, _ in generalStudy() },
        Rule(words: ["시험기간", "시험계획", "시험공부계획", "시험준비어떻게", "내신준비", "시험대비", "중간고사준비", "기말고사준비", "중간고사어떻게", "기말고사어떻게",
                     "시험준비는어떻게", "시험공부어떻게"]) { _, _, c in examPlan(c) },
        Rule(words: ["공부왜해야", "왜공부해야", "공부하는이유", "공부를왜", "공부는왜", "왜공부를해", "공부해야하는이유"], maxLength: 24) { _, _, _ in
            Answer(text: "공부는 나중에 고를 수 있는 길을 넓혀 줘요. 지금 배우는 건 생각하는 힘과 끈기도 길러 주고요. 너무 막막하면 오늘 할 공부 하나만 정해서 해 봐요.",
                   suggestions: ["25분 타이머 시작해줘", "공부법 알려줘"])
        },
        Rule(words: ["문제어떻게풀", "문제푸는법", "문제잘푸는", "문제푸는방법", "문제어떻게접근"], maxLength: 24, exclude: ["추가", "일정"]) { _, _, _ in
            Answer(text: "문제는 이렇게 풀어 봐요.\n• 구하는 것과 주어진 조건에 밑줄\n• 비슷한 예제의 풀이 방법 떠올리기\n• 식을 세워 계산하고, 답을 넣어 확인\n막히는 문제는 식이나 사진으로 보내 주면 단계별로 풀어 줄게요.",
                   suggestions: ["x² − 5x + 6 = 0 풀어줘", "수학 퀴즈 내줘"])
        },
        Rule(words: ["수능공부언제", "수능준비언제", "수능언제부터", "수능공부는언제", "수능공부어떻게", "수능준비어떻게"], maxLength: 24) { _, _, _ in
            Answer(text: "수능 공부는 따로 시작하기보다 지금 학교에서 배우는 개념을 탄탄히 하는 게 시작이에요. 학년이 올라가면 기출 문제를 조금씩 풀어 보며 계획을 세우면 돼요.",
                   suggestions: ["수능 D-Day 설정해줘", "공부법 알려줘"])
        },
        Rule(words: ["공부순서", "과목순서", "뭐부터공부", "어떤과목부터", "무슨과목부터"], maxLength: 24) { _, _, _ in
            Answer(text: "공부 순서는 이렇게 정해 봐요.\n• 시험·마감이 가까운 것 먼저\n• 어려운 과목은 집중이 잘 되는 시간에\n• 암기 과목은 자기 전에 짧게 복습",
                   suggestions: ["오늘 할 일 알려줘", "25분 타이머 시작해줘"])
        },
        Rule(words: ["벼락치기", "시험전날", "내일시험", "내일이시험", "시험하루전", "시험이내일"]) { _, _, _ in cramTips() },
        Rule(words: ["오답노트쓰는", "오답노트어떻게", "오답정리"]) { _, _, _ in
            Answer(text: "오답노트는 이렇게 써요.\n• 문제를 찍어 저장하고 틀린 이유(실수 / 개념 / 문제 잘못 읽음)를 한 줄로\n• 해설 보기 전에 한 번 더 혼자 풀기\n• 3일·1주일 뒤 다시 풀고, 비슷한 문제로 확인",
                   suggestions: ["오답노트 현황 알려줘"])
        },
        Rule(words: ["플래너쓰는", "계획세우는법", "계획어떻게세", "계획을못지", "계획을안지", "작심삼일", "계획짜", "계획좀짜", "계획세워줘", "계획만들어"]) { _, _, _ in planning() },
        Rule(words: ["몇시간자", "잠을몇", "수면시간", "밤새", "밤샘", "새벽공부", "새벽에공부", "새벽까지", "늦게까지공부", "밤늦게공부"]) { _, _, _ in
            Answer(text: "밤새우는 것보다 6~8시간 자는 게 시험에 훨씬 유리해요. 자는 동안 뇌가 낮에 배운 걸 기억으로 옮겨 주거든요. 시험 전날에도 최소 5~6시간은 자고, 잠들기 전 20분만 훑어보세요.")
        },
        Rule(words: ["쉬는시간", "얼마나쉬", "몇분쉬", "휴식", "쉬고싶", "좀쉴래", "쉬어도돼", "쉬어야"], maxLength: 30) { _, _, _ in
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
        Rule(words: ["친구랑싸", "친구가싫", "친구관계", "왕따", "따돌", "친구가없", "친구없어", "친구가무시", "친구가나무시", "친구들이무시", "무시당", "친구가나를", "친구가날"]) { _, _, _ in
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
        Rule(words: ["날씨"], maxLength: 20, exclude: ["좋다", "좋네", "좋아", "덥다", "덥네", "춥다", "춥네", "맑다", "맑네", "흐리다", "흐리네", "최고"]) { _, _, _ in
            Answer(text: "아쉽지만 저는 날씨 정보를 볼 수 없어요. 날씨 앱을 확인해 주세요! 비 오는 날엔 타이머의 빗소리를 켜고 공부해 보는 것도 좋아요.")
        },

        // 재미
        Rule(words: ["농담", "개그", "웃긴얘기", "웃겨줘", "재밌는얘기", "재미있는얘기", "아재"], maxLength: 20) { _, _, _ in
            Answer(text: pick(jokes), suggestions: ["하나 더", "퀴즈 내줘"], kind: "joke")
        },
        Rule(words: ["응원해줘", "응원좀", "응원해", "격려해", "힘내라고", "화이팅해줘", "파이팅해줘"], maxLength: 20) { _, _, c in
            let goal = c.goalMinutes > c.todayMinutes ? " 오늘 목표까지 \(duration(c.goalMinutes - c.todayMinutes)) 남았어요." : ""
            return Answer(text: pick(["항상 응원해요! 지금처럼 한 걸음씩이면 충분해요 💪", "할 수 있어요! 어제보다 조금만 더 하면 그걸로 대단한 거예요.", "화이팅! 끝까지 옆에서 응원할게요."]) + goal,
                          suggestions: ["25분 타이머 시작해줘", "명언 하나 알려줘"])
        },
        Rule(words: ["명언", "좋은말", "힘이되는말", "격려", "한마디해줘"], maxLength: 20) { _, _, _ in
            Answer(text: pick(quotes), suggestions: ["하나 더", "오늘 할 일 알려줘"], kind: "quote")
        },
        // 신기한 사실 (지식 사전의 '사실과 의견'으로 가지 않게 여기서)
        Rule(words: ["재밌는사실", "재미있는사실", "신기한사실", "신기한거알려", "재밌는거알려", "tmi"], maxLength: 20) { _, _, _ in
            Answer(text: pick(facts), suggestions: ["하나 더", "퀴즈 내줘"], kind: "fact")
        },
        Rule(words: ["하나더", "또해줘", "한개더", "더해줘"], maxLength: 5) { _, _, _ in
            if DoitTone.previousKind == "fact" { return Answer(text: pick(facts), suggestions: ["하나 더"], kind: "fact") }
            // 바로 전에 한 것과 같은 걸로 (농담 뒤엔 농담, 명언 뒤엔 명언)
            let joke = DoitTone.previousKind == "joke" || (DoitTone.previousKind != "quote" && Bool.random())
            return Answer(text: joke ? pick(jokes) : pick(quotes), suggestions: ["하나 더"], kind: joke ? "joke" : "quote")
        },
        Rule(words: ["노래추천", "공부음악", "공부할때들을", "백색소음", "집중음악"], maxLength: 24) { _, _, _ in
            Answer(text: "가사가 없는 소리가 집중에 좋아요. MOTI 타이머에서 빗소리, 파도, 백색·핑크·브라운 소음을 켤 수 있어요. 타이머 화면의 소리 버튼을 눌러보세요!",
                   suggestions: ["타이머 화면 열어줘"])
        },

        // 짧은 맞장구
        Rule(words: ["ㅋㅋ", "ㅎㅎ", "하하", "lol"], maxLength: 8) { _, _, _ in
            // 농담 뒤의 웃음은 농담 이야기로
            if DoitTone.previousKind == "joke" {
                let (text, offer) = pick([("ㅋㅋ 웃겼다니 다행이에요! 하나 더 해 줄까요?", "농담 하나 더 해줘"), ("ㅎㅎ 제 개그 통했네요!", nil), ("ㅋㅋㅋ 저도 이거 좋아해요.", nil)])
                return Answer(text: text, suggestions: ["하나 더"], offer: offer)
            }
            return Answer(text: pick(["ㅋㅋ 뭐가 그렇게 웃겨요?", "ㅎㅎ 기분 좋아 보여서 다행이에요!", "ㅋㅋㅋ 저도 덩달아 웃게 되네요.", "웃으면서 공부하면 더 잘 외워진대요 😄"]))
        },
        Rule(words: ["ㅠㅠ", "ㅜㅜ", "흑흑"], maxLength: 8) { _, _, _ in
            Answer(text: pick(["무슨 일 있어요? 편하게 말해 줘요.", "왜요, 무슨 일이에요? 들을게요.", "토닥토닥… 무슨 일인지 말해 줄래요?"]))
        },
        Rule(words: [], maxLength: 5, prefixes: [], exact: ["응", "응응", "웅", "엉", "어", "ㅇ", "ㅇㅇ", "ㅇㅇㅇ", "ㅇㅋ", "ㅇㅋㅇㅋ", "그래", "좋아", "알겠어", "오케이", "ok", "okay", "넵", "네", "네네", "예", "알겠습니다", "콜", "ㄱㄱ", "ㄱ", "고고", "가자"]) { _, _, _ in
            Answer(text: pick(["좋아요! 뭐부터 해 볼까요?", "좋아요 😊 하고 싶은 거 말해 줘요.", "오케이! 뭐 도와줄까요?"]),
                   suggestions: ["오늘 할 일 알려줘", "25분 타이머 시작해줘", "퀴즈 내줘"])
        },
        Rule(words: ["그만", "됐어", "괜찮아", "멈춰", "취소"], maxLength: 6) { _, _, _ in
            Answer(text: pick(["알겠어요. 필요할 때 언제든 불러 줘요!", "알겠어요! 쉬고 싶으면 쉬어요.", "네, 알겠어요. 또 봐요 😊"]))
        },
        Rule(words: [], maxLength: 5, exact: ["아니", "아니요", "아니야", "ㄴㄴ", "ㄴ", "싫어", "별로", "놉", "노노"]) { _, _, _ in
            Answer(text: pick(["알겠어요. 다른 게 필요하면 말해 줘요.", "앗, 그럼 다른 거 해 볼까요?", "알겠어요! 그럼 편하게 있어요."]))
        },
        // "그래도 해야겠지?", "해 볼게" 같은 다짐
        Rule(words: ["해야겠지", "해야겠다", "해야겠어", "해야겠네", "해야지", "해볼게", "해볼까", "해야되겠", "해야하겠"], maxLength: 16,
             exclude: ["추가", "일정", "타이머", "퀴즈", "그만", "안해", "뭐"]) { _, _, c in
            let (text, offer) = pick([("그 마음이면 충분해요! 25분만 같이 해 볼까요?", "25분 타이머 시작해줘"),
                                      ("좋아요, 시작이 반이에요. 딱 하나만 정해서 해 봐요.", nil),
                                      ("멋져요! 부담 갖지 말고 조금만 해 봐요. 옆에서 응원할게요.", nil)])
            return Answer(text: text, suggestions: ["25분 타이머 시작해줘", "오늘 할 일 알려줘"], offer: offer)
        }
    ]

    /// 낱말이 들어 있는지 (영어 낱말은 따로 떨어진 낱말일 때만: "children" 속 "hi"는 인사가 아님)
    static func contains(_ t: String, _ original: String, _ word: String) -> Bool {
        guard word.allSatisfy({ $0.isASCII && $0.isLetter }), word.count < 6 else { return t.contains(word) }
        let tokens = original.lowercased().split(whereSeparator: { !($0.isASCII && $0.isLetter) }).map(String.init)
        return tokens.contains { $0 == word || (word.count >= 5 && $0.hasPrefix(word)) }
    }

    // MARK: - 숫자가 들어간 대화 (공부 시간, 점수, 남은 기간, 과목이 어려움)

    private static func specialCases(_ text: String, _ t: String, _ c: Context) -> Answer? {
        // "이 문제 풀어줘" 인데 문제가 없을 때
        if has(t, ["풀어줘", "풀어줄래", "풀어봐", "풀어주세요"]), !t.contains(where: { $0.isNumber || ($0.isASCII && $0.isLetter) }) {
            return Answer(text: "풀 문제를 보내주세요! 식으로 써도 되고, 아래 + 버튼으로 문제 사진을 찍어 보내도 돼요.\n예: \"x² − 5x + 6 = 0 풀어줘\", \"y = x² − 4x + 1 꼭짓점\"",
                          suggestions: ["x² − 5x + 6 = 0 풀어줘"])
        }
        // "숙제 도와줘", "과제 좀 도와줄래?" → 문제를 보내 달라고
        if has(t, ["숙제", "과제", "문제집", "공부"]), has(t, ["도와줘", "도와줄래", "도와주세요", "도와줄수", "봐줘", "봐줄래"]), t.count <= 16,
           !has(t, ["추가", "일정", "타이머"]) {
            return Answer(text: "좋아요! 어떤 문제예요? 문제를 적어 주거나 + 버튼으로 사진을 보내 주면 같이 풀어 볼게요.",
                          suggestions: ["x² − 5x + 6 = 0 풀어줘", "광합성이 뭐야?"])
        }
        // "공부 뭐부터 해?", "뭐부터 할까" → 오늘 남은 플랜부터
        if has(t, ["뭐부터", "무엇부터", "뭘먼저", "뭐먼저", "어떤거부터", "어떤것부터", "뭐해야할지", "뭘해야할지"]), !has(t, ["시험", "남았", "추가", "일정"]), t.count <= 20 {
            let text = c.remainingPlans > 0
                ? "오늘 남은 플랜 \(c.remainingPlans)개 중 마감이 가까운 것부터 해요. 25분만 집중하고 쉬는 식으로 하나씩 끝내 봐요."
                : "오늘 남은 플랜이 없으면, 어제 배운 걸 10분 복습하고 틀린 문제를 다시 풀어 보는 것부터 해요."
            return Answer(text: text, suggestions: ["오늘 할 일 알려줘", "25분 타이머 시작해줘"])
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
        // "수학 숙제 너무 많아", "외울 게 산더미야"
        if has(t, ["숙제", "과제", "수행평가", "할일", "할게", "공부할게", "시험범위"]), !has(t, ["외울", "암기"]), has(t, ["많아", "많다", "많네", "많은데", "쌓였", "밀렸", "산더미"]),
           !has(t, ["추가", "일정", "어떻게", "왜"]) {
            return Answer(text: "할 일이 많을 땐 목록부터 써요! 마감이 가까운 것 → 오래 걸리는 것 순서로 플래너에 넣으면 훨씬 덜 막막해요.",
                          suggestions: ["오늘 할 일 알려줘", "메모해줘: 해야 할 과제"])
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
           let days = t.firstMatch(of: #/(\d+)(일|주|달|개월)/#).flatMap({ m -> Int? in
               guard let n = Int(String(m.1)) else { return nil }
               let unit = String(m.2)
               return unit == "주" ? n * 7 : (unit == "일" ? n : n * 30)
           }) ?? [("일주일", 7), ("한주", 7), ("보름", 15), ("한달", 30), ("두달", 60), ("하루", 1), ("이틀", 2), ("사흘", 3)].first(where: { t.contains($0.0) })?.1 {
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

    // MARK: - 욕·무례한 말

    /// 욕·손가락 욕 ("ㅗ", "ㅅㅂ", "씨발", "ㅂㅅ", "꺼져"…): 말 대부분이 욕일 때만 (욕을 빼고 남은 말이 거의 없을 때)
    /// ("시발 피곤해", "아 짜증나" 같은 말은 감정 쪽 답으로)
    static let rudeWords = ["ㅗ", "ㅅㅂ", "ㅆㅂ", "ㅅㅂㄹㅁ", "시발", "씨발", "씨바", "시바", "씹", "ㅂㅅ", "ㅄ", "병신", "븅신", "빙신", "꺼져", "닥쳐", "닥치", "미친놈", "미친년", "미친",
                            "ㅁㅊ", "개새", "ㄱㅅㄲ", "새끼", "ㅅㄲ", "ㅈ같", "좆", "ㅈㄹ", "지랄", "엿먹", "fuck", "shit", "ㅗㅗ"]
    /// 모티한테 하는 핀잔 ("개못하네", "쓰레기네", "노답")
    private static let botInsults = ["못하네", "개못", "쓰레기", "구려", "노답", "쓸데없", "답답하네", "왜이래", "한심"]

    /// 엔진이 과목 질문보다 먼저 볼 말 (욕, 모티 자신에 대한 질문)
    static func earlyReply(_ raw: String) -> Answer? {
        let t = squash(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !t.isEmpty, !isCrisis(raw), let answer = rude(t) ?? meta(t) else { return nil }
        DoitTone.remember(answer.text, kind: answer.kind, offer: answer.offer)
        return answer
    }

    private static func rude(_ t: String) -> Answer? {
        var rest = t
        var swore = false
        for word in rudeWords.sorted(by: { $0.count > $1.count }) where rest.contains(word) {
            rest = rest.replacingOccurrences(of: word, with: "")
            swore = true
        }
        let insult = botInsults.contains { t.contains($0) } && t.count <= 12
        for filler in ["너", "넌", "니가", "아", "야", "진짜", "개", "존나", "졸라", "네", "냐", "같네", "같아", "같다", "ㅋ", "ㅎ", "ㅡ", "-", "!", "?"] {
            rest = rest.replacingOccurrences(of: filler, with: "")
        }
        guard (swore && rest.count <= 2) || (insult && rest.count <= 6) else { return nil }
        // 같은 말이 이어지면 짧게만 (훈계하지 않음)
        if DoitTone.previousKind == "rude" {
            return Answer(text: pick(["괜찮아요. 마음이 좀 풀리면 그때 말 걸어 줘요.", "알겠어요. 저는 여기 있을게요. 필요하면 불러 줘요."]),
                          suggestions: ["재밌는 사실 알려줘", "오늘 할 일 알려줘"], kind: "rude")
        }
        if insult || t.contains("너") || t.contains("넌") {
            return Answer(text: pick(["앗, 제가 답을 잘 못 했나 봐요. 미안해요. 한 번만 다르게 말해 주면 다시 해 볼게요.",
                                      "미안해요, 제가 헛짚었나 봐요. 짧게 다시 말해 주면 제대로 해 볼게요."]),
                          suggestions: ["뭐 할 수 있어?"], kind: "rude")
        }
        return Answer(text: pick(["앗, 기분 안 좋은 일 있었어요? 공부하다 막힌 거면 같이 풀어 봐요.",
                                  "많이 짜증 났나 봐요. 무슨 일인지 말해 주면 들을게요.",
                                  "화날 땐 잠깐 숨 고르고 와도 괜찮아요. 제가 잘못 답했으면 다시 말해 줘요."]),
                      suggestions: ["5분 타이머 시작해줘", "재밌는 사실 알려줘"], kind: "rude")
    }

    // MARK: - 모티 자신

    /// 지금 답하는 모드 ("모티 ZERO", "모티 1", "모티 2") — DoitAssistant가 말을 받을 때마다 알려 줌
    static var modeName = "모티 ZERO"

    /// "저는 모티 AI예요 …" (지금 모드에 맞게, 모델 이름은 쓰지 않음)
    static func identity() -> String {
        if modeName == "모티 ZERO" {
            return "저는 **모티 AI**예요. 지금은 **모티 ZERO**라서 AI 모델 없이 앱 안의 규칙과 자료로 답해요."
        }
        return "저는 **모티 AI**예요. 지금은 **\(modeName)**로, 휴대폰 안에서 돌아가는 오픈소스 AI 모델이 답해요."
    }

    /// 모티 1·2·ZERO가 어떻게 다른지
    static let modesText = "**모티 ZERO**는 AI 모델 없이 규칙과 앱 안 자료로 빠르게 답해요. 앱 기능·계산·정해진 개념은 정확하지만 대화는 조금 딱딱해요.\n**모티 1·2**는 휴대폰 안에서 돌아가는 오픈소스 AI 모델이에요. 설명과 대화가 더 자연스럽고, 모티 2가 더 커서 더 똑똑해요. 위쪽 모델 메뉴에서 받을 수 있어요."

    /// 모티 자신에 대한 질문 (어떤 AI인지, 모드 차이, 인터넷, 말이 이상하다는 말)
    private static func meta(_ t: String) -> Answer? {
        let toBot = has(t, ["너", "넌", "니가", "네가", "당신", "모티", "여기", "이앱"]) || t.count <= 8
        let modelNames = ["qwen", "큐웬", "퀜", "gpt", "지피티", "chatgpt", "챗지피티", "제미나이", "gemini", "클로드", "claude", "llama", "클로바",
                          "llm", "언어모델", "ai모델", "인공지능모델", "무슨ai", "어떤ai", "무슨인공지능", "어떤인공지능", "무슨모델", "어떤모델", "모델뭐", "모델이뭐",
                          "ai야", "ai이야", "ai냐", "ai임", "ai맞", "ai지", "ai니", "인공지능이야", "인공지능이냐", "인공지능맞"]
        let modes = ["모티1", "모티2", "모티zero", "모티제로", "제로모드", "zero모드", "모티원", "모티투", "모티영"]
        let complaint = ["말이상", "이상하게말", "말을이상", "대답이이상", "답이이상", "제대로대답", "제대로답", "엉뚱", "동문서답", "말귀를", "못알아들", "말이안통", "왜이렇게말", "로봇같"]
        if has(t, modes) || (has(t, ["모델받", "모델다운", "모델설치", "모델깔", "ai모델받"]) && !has(t, ["추가", "일정"])) {
            return Answer(text: modesText, suggestions: ["뭐 할 수 있어?"], kind: "meta")
        }
        if has(t, complaint), t.count <= 24 {
            let text = modeName == "모티 ZERO"
                ? "미안해요. 모티 ZERO는 AI 모델 없이 정해진 규칙으로 답해서 엉뚱할 때가 있어요. 짧고 분명하게 물어보면 더 잘 알아들어요. 모티 1·2를 받으면 대화가 더 자연스러워요."
                : "미안해요, 제가 잘못 알아들었나 봐요. 한 번만 다르게 말해 줄래요?"
            return Answer(text: text, suggestions: ["모티 1이랑 뭐가 달라?", "뭐 할 수 있어?"], kind: "meta")
        }
        // ("Qwen이 뭐야", "Qwen 더 자세히"처럼 그 낱말 자체를 물으면 소개가 아님: 모티를 부르거나 "~야?", "~써?"로 물을 때만)
        let explicit = has(t, ["너", "넌", "니가", "네가", "당신", "모티"])
        let asksIs = (t.hasSuffix("야") && !t.hasSuffix("뭐야")) || t.hasSuffix("냐") || t.hasSuffix("임") || has(t, ["맞아", "맞지", "써", "쓰는", "기반"])
        if has(t, modelNames), explicit || asksIs, t.count <= 24, !has(t, ["자세히", "설명해", "알려줘"]) || explicit {
            return Answer(text: identity() + (modeName == "모티 ZERO" ? " 모티 1·2를 받으면 오픈소스 AI 모델로 더 자연스럽게 대화해요." : ""),
                          suggestions: ["모티 1이랑 뭐가 달라?", "뭐 할 수 있어?"], kind: "meta")
        }
        if has(t, ["인터넷돼", "인터넷되", "인터넷연결", "인터넷검색", "인터넷써", "검색돼", "검색할수있", "검색해줄수", "와이파이없"]), toBot || t.count <= 14 {
            let text = modeName == "모티 ZERO"
                ? "모티 ZERO는 인터넷 검색 없이 앱 안 자료로만 답해요. 그래서 날씨·뉴스 같은 최신 정보는 몰라요."
                : "모르는 개념은 인터넷(위키백과)에서 찾아보기도 해요. 날씨·뉴스 같은 실시간 정보는 몰라요."
            return Answer(text: text, suggestions: ["뭐 할 수 있어?"], kind: "meta")
        }
        if has(t, ["똑똑해", "똑똑하냐", "똑똑하니", "머리좋아", "얼마나똑똑"]), has(t, ["너", "넌", "니"]) || t.count <= 6, !has(t, ["나똑똑", "내가"]) {
            return Answer(text: "앱 안 자료 안에서는 꽤 정확해요! 수학 계산과 앱 기능은 자신 있고, 모르는 건 모른다고 할게요.",
                          suggestions: ["x^2-5x+6=0 풀어줘", "광합성이 뭐야?"], kind: "meta")
        }
        return nil
    }

    // MARK: - 짧은 줄임말 · 맞장구

    /// 말 전체가 짧은 줄임말일 때 ("ㅇㅈ", "헐", "대박", "바이", "그냥", "음")
    private static func shortTalk(_ t: String, _ c: Context) -> Answer? {
        let core = t.trimmingCharacters(in: CharacterSet(charactersIn: "~^ㅋㅎ"))
        let word = core.isEmpty ? t : core
        switch word {
        case "ㅇㅈ", "인정", "ㅇㅈㅇㅈ", "ㄹㅇㅇㅈ":
            return Answer(text: pick(["그쵸? ㅎㅎ", "인정해 줘서 고마워요 ㅎㅎ", "역시 통했네요!"]))
        case "헐", "헐ㄹ", "헉", "헐대박", "와", "우와", "와우", "오":
            if DoitTone.previousKind == "fact" { return Answer(text: pick(["그쵸? 신기하죠!", "저도 처음 알았을 때 놀랐어요 ㅎㅎ"]), suggestions: ["하나 더"]) }
            return Answer(text: pick(["헉, 무슨 일이에요?", "왜요, 놀랄 일 있었어요?", "오, 뭔데요? 궁금해요!"]))
        case "대박", "대박이다", "대박사건":
            if DoitTone.previousKind == "fact" { return Answer(text: pick(["그쵸? 신기하죠!", "대박이죠 ㅎㅎ 하나 더 알려 줄까요?"]), suggestions: ["하나 더"]) }
            return Answer(text: pick(["오, 뭐가 대박이에요? 궁금해요!", "무슨 좋은 일 있어요?"]))
        case "바이", "ㅂㅂ", "ㅂㅇ", "ㅃㅇ", "빠이", "빠빠이", "잘가", "잘있어", "ㅂㅂㅇ", "바이바이":
            return Answer(text: pick(["오늘도 수고 많았어요. 또 봐요!", "좋아요, 다음에 봐요!", "다음에 또 와요! 기다릴게요 😊"]))
        case "모티", "모티야", "모티아", "모티씨", "저기", "저기요", "있잖아":
            return Answer(text: pick(["네, 불렀어요? 무엇을 도와줄까요?", "네! 여기 있어요. 뭐 할까요?"]), suggestions: ["오늘 할 일 알려줘", "뭐 할 수 있어?"])
        case "아무거나", "아무거나해줘", "아무거나해", "아무말", "아무말이나":
            return Answer(text: pick(["그럼 퀴즈 한 판 어때요? 과목은 제가 골라 볼게요.", "그럼 신기한 사실 하나 들려줄까요?"]),
                          suggestions: ["퀴즈 내줘", "재밌는 사실 알려줘"], offer: "퀴즈 내줘")
        case "그냥", "그냥요", "그냥ㅎ", "그냥그래":
            return Answer(text: pick(["그럴 때도 있죠 ㅎㅎ 심심하면 퀴즈 한 판 어때요?", "그냥 들렀군요! 편하게 아무 말이나 해요."]),
                          suggestions: ["퀴즈 내줘", "재밌는 사실 알려줘"], offer: "퀴즈 내줘")
        case "음", "음음", "흠", "흠흠", "음…", "음..", "으음":
            return Answer(text: pick(["천천히 생각해도 돼요. 궁금한 게 생기면 말해 줘요.", "고민 중이에요? 같이 정해 볼까요?"]),
                          suggestions: ["오늘 할 일 알려줘", "뭐 할 수 있어?"])
        case "뭐", "뭐?", "모", "머", "엥", "응?":
            return Answer(text: pick(["네? 무엇이 궁금한지 말해 줄래요?", "음, 뭐가 궁금해요? 편하게 물어봐요."]), suggestions: ["뭐 할 수 있어?"])
        default:
            return nil
        }
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
            plan = "• 새로운 것 말고 오답노트·핵심 정리만\n• 자주 틀린 공식·용어를 한 장에 정리\n• 꼭 5~6시간은 자기"
        case 2...7:
            plan = "• \(days - 2 <= 1 ? "1일차" : "1~\(days - 2)일차"): 과목별 핵심 개념 + 대표 문제\n• 다음 날: 기출로 실전 연습\n• 마지막 날: 오답노트와 암기 내용 점검"
        case 8...21:
            plan = "• 앞 40%: 1회독, 개념 정리와 기본 문제\n• 다음 40%: 2회독, 기출과 오답노트\n• 마지막 20%: 3회독, 오답 다시 풀기와 암기"
        default:
            plan = "• 지금은 하루 1~2단원씩 개념 + 기본 문제\n• 주말마다 그 주 복습\n• 시험 3주 전부터 기출 위주 3회독"
        }
        return Answer(text: "시험까지 \(days)일 남았군요. 이렇게 해봐요.\n\(plan)",
                      suggestions: ["기말고사 D-Day 12월 10일로 설정해줘", "내일 오후 7시 수학 공부 2시간 추가해줘"])
    }

    // MARK: - 답변 만들기

    private static func greeting(_ c: Context, morning: Bool = false, evening: Bool = false) -> Answer {
        let chips = ["오늘 할 일 알려줘", "뭐 할 수 있어?", "퀴즈 내줘"]
        // 방금 인사했는데 또 인사하면 같은 인사를 되풀이하지 않음
        if DoitTone.previousKind == "greeting" {
            return Answer(text: pick(["또 만났네요, 반가워요! 😊", "ㅎㅎ 다시 안녕하세요! 뭐 하다 왔어요?", "반가워요, 또 왔네요!"]), suggestions: chips, kind: "greeting")
        }
        let hour = Calendar.current.component(.hour, from: c.now)
        let hi = DoitTone.nameToCall().map { "안녕하세요, \($0)님!" } ?? "안녕하세요!"
        let line: String
        if evening {
            line = pick(["\(hi) 좋은 저녁이에요.", "좋은 저녁이에요, 저녁은 먹었어요?"])
        } else if morning || (5..<11).contains(hour) {
            line = pick(["\(hi) 좋은 아침이에요 ☀️", "좋은 아침이에요, 잘 잤어요?", "\(hi) 상쾌한 아침이에요."])
        } else {
            switch hour {
            case 11..<14: line = pick(["\(hi) 점심은 챙겨 먹었어요?", "반가워요! 점심 먹고 나른하죠?"])
            case 14..<18: line = pick(["\(hi) 오후도 같이 힘내 봐요.", "반가워요! 나른한 오후네요."])
            case 18..<23: line = pick(["\(hi) 오늘 하루 어땠어요?", "반가워요! 저녁은 먹었어요?"])
            default: line = pick(["\(hi) 늦은 시간까지 수고가 많아요.", "반가워요! 이 시간까지 깨어 있었네요."])
            }
        }
        // 아침 인사에 "안녕"이 없으면 (좋은 아침 말고 "안녕"이라고 했을 때) 안녕을 붙임
        let opened = !morning && !line.contains("안녕") && !line.contains("반가") ? "안녕하세요! " + line : line
        // 오늘 상황은 한 가지만 짧게
        var status = ""
        if c.todayMinutes > 0 {
            status = pick([" 오늘 벌써 \(duration(c.todayMinutes)) 공부했네요.", " 오늘 \(duration(c.todayMinutes))이나 했어요, 멋져요."])
        } else if c.remainingPlans > 0 {
            status = " 오늘 남은 플랜이 \(c.remainingPlans)개 있어요."
        }
        return Answer(text: opened + status, suggestions: chips, kind: "greeting")
    }

    private static func goodNight(_ c: Context) -> Answer {
        var text = pick(["오늘도 수고 많았어요. 잘 자요 🌙", "푹 자요! 자는 동안 오늘 공부한 게 머리에 정리돼요 🌙", "굿나잇! 내일 또 봐요."])
        if c.todayMinutes > 0 { text = "오늘 \(duration(c.todayMinutes))이나 했네요. " + text }
        return Answer(text: text, suggestions: ["내일 일정 알려줘"])
    }

    private static func tired(_ t: String, _ c: Context) -> Answer {
        let hour = Calendar.current.component(.hour, from: c.now)
        if hour >= 23 || hour < 5 {
            return Answer(text: pick(["많이 늦었어요. 지금은 버티는 것보다 잠을 자는 게 남는 거예요. 남은 건 내일 아침으로 미뤄 둘까요?",
                                      "이 시간엔 쉬는 게 이기는 거예요. 자는 동안 오늘 공부한 게 정리되니까 푹 자요 🌙"]),
                          suggestions: ["내일 오전 8시 복습 추가해줘", "타이머 종료해줘"])
        }
        let options: [(String, String?)]
        if has(t, ["졸", "잠", "꾸벅", "자고싶"]) {
            options = [("졸릴 땐 찬물 세수나 2~3분 스트레칭이 직빵이에요. 그래도 안 깨면 15분만 자요.", nil),
                       ("많이 졸리죠… 일어나서 물 한 잔 마시고 소리 내서 읽어 봐요. 잠이 좀 깨요.", nil),
                       ("졸음이 오면 15~20분 짧은 낮잠이 오히려 나아요. 20분 타이머 맞춰 줄까요?", "20분 타이머 시작해줘")]
        } else if c.todayMinutes >= 60 {
            options = [("오늘 벌써 \(duration(c.todayMinutes))이나 했으니 피곤할 만해요. 10분만 쉬었다 할까요?", "10분 타이머 시작해줘"),
                       ("\(duration(c.todayMinutes)) 했으면 피곤한 게 당연해요. 잠깐 스트레칭하고 물 한 잔 마셔요.", nil)]
        } else {
            options = [("피곤하구나… 10분만 쉬고 25분만 더 해 볼까요?", "25분 타이머 시작해줘"),
                       ("많이 피곤하죠. 잠깐 스트레칭하고 물 한 잔 마셔요.", nil),
                       ("피곤할 땐 억지로 하는 것보다 잠깐 쉬는 게 나아요. 10분 뒤에 다시 시작해요.", nil)]
        }
        let (text, offer) = pick(options)
        return Answer(text: text, suggestions: ["25분 타이머 시작해줘"], offer: offer)
    }

    private static func hardTime(_ t: String, _ c: Context) -> Answer {
        var answer = pick(["많이 힘들었겠어요. 여기까지 버틴 것만으로도 잘하고 있는 거예요.",
                           "지칠 만큼 열심히 했다는 거예요. 잠깐 숨 돌려도 괜찮아요.",
                           "많이 힘들었죠… 무슨 일 있었는지 말해 줄래요? 들을게요."])
        // (묻는 말이 아니면 작은 한 걸음을 권함)
        if !answer.contains("?") { answer += " 오늘은 딱 10분짜리 하나만 해 봐요." }
        // 크게 지쳤거나 힘들다는 말이 이어지면 도움받을 곳도 알려 줌
        if has(t, ["포기하고싶", "그만두고싶", "번아웃", "버거", "벅차"]) || DoitTone.previousKind == "hard" {
            answer += "\n혼자 버티기 힘들면 믿을 수 있는 어른이나 청소년상담 1388에 꼭 이야기해요."
        }
        return Answer(text: answer, suggestions: ["10분 타이머 시작해줘", "명언 하나 알려줘"], kind: "hard")
    }

    private static func stressed(_ t: String) -> Answer {
        if has(t, ["짜증", "화나", "열받", "빡"]) {
            return Answer(text: pick(["짜증 날 만하죠. 일단 숨 한번 크게 쉬고 어깨 좀 풀어요. 뭐 때문에 그래요?",
                                      "화날 땐 잠깐 자리에서 일어나 숨 크게 쉬어요. 그리고 무슨 일인지 말해 줘요, 들을게요.",
                                      "으, 짜증 나죠. 물 한 잔 마시고 숨 고르면 한결 나아요."]),
                          suggestions: ["메모해줘: ", "5분 타이머 시작해줘"])
        }
        return Answer(text: pick(["스트레스 받을 땐 숨부터 크게 쉬어요. 4초 들이마시고 8초 내쉬기, 세 번만 해 봐요.",
                                  "많이 쌓였나 봐요. 머릿속 걱정을 메모로 적어 두면 한결 가벼워져요. 숨도 한번 크게 쉬고요.",
                                  "스트레스 받을 땐 5분만 걷거나 스트레칭해도 머리가 풀려요. 무슨 일인지 말해 줄래요?"]),
                      suggestions: ["메모해줘: ", "5분 타이머 시작해줘"])
    }

    private static func sad(_ t: String) -> Answer {
        if t.contains("외로") {
            return Answer(text: pick(["외로운 마음이 드는군요. 저라도 이야기 상대가 되어 줄게요. 오늘 무슨 일 있었어요?",
                                      "외로울 때 말 걸어 줘서 고마워요. 마음이 조금 나아질 때까지 저랑 이야기해요."]))
        }
        if has(t, ["속상", "눈물", "울고싶", "울었"]) {
            return Answer(text: pick(["속상했겠어요. 무슨 일이었는지 이야기해 줄래요? 들을게요.",
                                      "마음이 많이 상했군요. 울고 싶으면 울어도 괜찮아요. 저 여기 있을게요."]))
        }
        var text = pick(["마음이 많이 무거운가 봐요. 억지로 괜찮은 척 안 해도 돼요. 무슨 일인지 말해 주면 들을게요.",
                         "그런 날도 있어요. 오늘은 스스로에게 조금 다정해져도 괜찮아요. 이야기하고 싶으면 언제든요."])
        if t.contains("우울") {
            text += "\n털어놓을 곳이 필요하면 청소년상담 **1388**(전화·문자·카톡)도 늘 열려 있어요."
        }
        return Answer(text: text)
    }

    private static func anxious(_ t: String) -> Answer {
        if t.contains("시험") || t.contains("발표") || t.contains("면접") {
            return Answer(text: pick(["긴장되는 건 그만큼 잘하고 싶다는 뜻이에요. 4초 들이마시고 6초 내쉬기를 몇 번 해 봐요. 준비한 만큼 충분히 할 수 있어요!",
                                      "떨리죠. 직전엔 새로운 것 말고 오답노트만 훑어봐요. '긴장된다' 대신 '설렌다'고 말해 보는 것도 효과 있어요."]),
                          suggestions: ["오답노트 현황 알려줘", "명언 하나 알려줘"])
        }
        return Answer(text: pick(["불안할 땐 걱정을 적어 보는 게 도움이 돼요. 그중 지금 할 수 있는 것 하나부터 해 봐요.",
                                  "걱정되는 마음 이해해요. 숨 한번 크게 쉬고, 뭐가 제일 걱정인지 말해 줄래요?"]),
                      suggestions: ["메모해줘: "])
    }

    private static func exam_bad() -> Answer {
        Answer(text: pick(["속상하겠어요. 그래도 시험 한 번이 전부는 아니에요. 틀린 문제만 오답노트에 모아 두면 다음엔 분명 달라져요.",
                           "많이 아쉽죠… 오늘은 푹 쉬고, 내일 틀린 문제부터 오답노트로 같이 봐요. 다음 시험은 더 잘할 거예요."]),
               suggestions: ["다음 시험 D-Day 설정해줘", "오답노트 현황 알려줘"])
    }

    private static func motivation(_ c: Context) -> Answer {
        let (base, offer) = pick([("하기 싫은 날도 있죠. 딱 5분만 해 봐요, 시작만 하면 생각보다 계속하게 돼요.", "5분 타이머 시작해줘"),
                                  ("의욕은 공부를 시작하면 따라와요. 일단 책상에 앉아 책만 펴 봐도 절반은 한 거예요!", nil),
                                  ("오늘은 조금만 해도 괜찮아요. 1%라도 0%보단 훨씬 나아요.", nil)])
        var text = base
        if c.goalMinutes > 0, c.todayMinutes >= c.goalMinutes {
            text += " 그리고 오늘 목표는 이미 채웠어요! 🎉"
        } else if c.todayMinutes > 0, DoitTone.previousKind != "motivation" {
            text += " 오늘 벌써 \(duration(c.todayMinutes)) 했잖아요."
        }
        return Answer(text: text, suggestions: ["5분 타이머 시작해줘", "명언 하나 알려줘"], kind: "motivation", offer: offer)
    }

    private static func focusTips(_ t: String) -> Answer {
        // 폰 이야기를 했으면 폰 이야기로
        let phone = has(t, ["폰", "유튜브", "쇼츠", "sns"])
        let text = phone ? pick(["폰은 다른 방이나 가방 속에 넣어 두는 게 제일 효과 커요. 25분 타이머 켜고 그동안만 참아 봐요.",
                                 "폰이 자꾸 손에 가죠. 공부 플랜에서 '다른 앱 잠금'을 켜 두면 정한 시간 동안 막아 줘요."])
                         : pick(["집중이 안 될 땐 폰부터 멀리 두고, 25분 타이머 켜서 한 과목만 해 봐요.",
                                 "집중 안 되는 날 있죠. 이번 25분 동안 할 일 딱 하나만 정하고 시작해 볼까요?"])
        return Answer(text: text, suggestions: ["25분 타이머 시작해줘", "타이머 화면 열어줘"], offer: "25분 타이머 시작해줘")
    }

    private static func slump() -> Answer {
        Answer(text: "슬럼프는 열심히 달려온 사람에게 와요. 하루 목표를 평소의 절반으로 낮추고, 쉬운 문제로 '해냈다'는 느낌부터 되찾아 봐요. 잠과 가벼운 운동도 챙기면 1~2주 안에 대부분 지나가요.",
               suggestions: ["하루 공부 목표 2시간", "이번 주 공부 통계"])
    }

    private static func memorize() -> Answer {
        Answer(text: "잘 외우려면 간격 반복이 최고예요. 1일 → 3일 → 1주일 뒤에 다시 보고, 책을 덮고 떠올려 써 봐요. 앞 글자 따기나 이야기로 묶어도 잘 외워져요.",
               suggestions: ["영어 퀴즈 내줘", "틀린 단어 알려줘"])
    }

    private static func studyMethod(_ subject: String) -> Answer {
        switch subject {
        case "수학":
            return Answer(text: "수학은 이렇게 해봐요.\n• 공식보다 개념이 왜 그런지 먼저 이해하기\n• 예제를 본 뒤 비슷한 문제를 혼자 풀기\n• 틀린 문제는 3일 뒤 해설 없이 다시\n모르는 식은 \"x² − 5x + 6 = 0 풀어줘\"처럼 물어봐요.",
                          suggestions: ["수학 퀴즈 내줘", "오답노트 현황 알려줘"])
        case "영어":
            return Answer(text: "영어는 이렇게 해봐요.\n• 단어는 하루 20~30개, 예문과 함께 반복\n• 문법은 규칙 하나에 예문 두 개\n• 듣기·독해는 매일 조금씩 소리 내어 따라 하기\n문법은 \"현재완료 설명해줘\"처럼 물어봐요.",
                          suggestions: ["영어 퀴즈 내줘", "관계대명사 설명해줘"])
        case "국어":
            return Answer(text: "국어는 이렇게 해봐요.\n• 비문학: 문단마다 핵심 한 줄 요약, 글의 구조 파악\n• 문학: 화자·상황·정서·표현법 정리\n• 기출: 선택지가 틀린 근거를 지문에서 찾기",
                          suggestions: ["음운의 변동이 뭐야?"])
        case "과학":
            return Answer(text: "과학은 이렇게 해봐요.\n• 현상 → 원인 → 결과를 이야기처럼 연결하기\n• 실험 과정과 그래프를 직접 그려 보기\n• 비슷한 용어(확산/삼투, 산화/환원)는 비교표로",
                          suggestions: ["과학 퀴즈 내줘", "광합성이 뭐야?"])
        default:
            return Answer(text: "사회·역사는 이렇게 해봐요.\n• 원인 → 사건 → 결과 흐름을 먼저 잡기\n• 연표·지도와 함께 외우기\n• 단원 제목만 보고 백지에 아는 걸 다 써 보기",
                          suggestions: ["사회 퀴즈 내줘", "삼권분립이 뭐야?"])
        }
    }

    private static func generalStudy() -> Answer {
        Answer(text: "효율적으로 공부하려면\n• 25~50분 집중 + 5~10분 휴식\n• 읽기만 말고 덮고 떠올려 쓰기·문제 풀기\n• 1일·3일·7일 뒤 복습, 틀린 문제는 오답노트로\n과목별 방법은 \"수학 공부법\"처럼 물어봐요.",
               suggestions: ["수학 공부법", "영어 공부법", "암기법 알려줘"])
    }

    private static func examPlan(_ c: Context) -> Answer {
        var text = "시험 계획은 이렇게 세워 봐요.\n• D-Day를 정하고 과목별 범위를 단원으로 쪼개기\n• 1회독 개념 → 2회독 문제 → 3회독 오답·암기\n• 마지막 3일은 새로운 것 대신 복습과 오답만"
        if let d = c.dDay { text += "\n지금 목표: \(d)" }
        return Answer(text: text, suggestions: ["기말고사 D-Day 12월 10일로 설정해줘", "내일 오후 7시 수학 공부 2시간 추가해줘"])
    }

    private static func cramTips() -> Answer {
        Answer(text: "시험 전날엔 이렇게 해요.\n• 새로운 내용보다 핵심 정리와 오답노트 위주\n• 자주 나오는 공식·용어를 한 장에 모아 반복\n• 밤새우지 말고 최소 5~6시간은 자기\n할 수 있어요! 💪",
               suggestions: ["오답노트 현황 알려줘", "틀린 단어 알려줘"])
    }

    private static func planning() -> Answer {
        Answer(text: "계획은 이렇게 세우면 잘 지켜져요.\n• '수학 공부' 대신 '수학 2단원 예제 10문제'처럼 작게\n• 할 일마다 시작 시간 정하기\n• 하루를 꽉 채우지 말고 80%만\n원하는 시간을 말해 주면 플래너에 바로 넣어 드릴게요.",
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

    /// 위기 신호 (이 답은 모델이 바꾸지 않고 상담 번호를 그대로 알려줌)
    static func isCrisis(_ text: String) -> Bool {
        let t = squash(text)
        return ["죽고싶", "자살", "자해", "죽어버리", "살기싫", "사라지고싶", "목숨", "극단적선택"].contains { t.contains($0) }
    }

    private static func crisis() -> Answer {
        Answer(text: "그런 생각이 들 만큼 많이 힘들었군요. 이야기해 줘서 고마워요. 지금 그 마음, 혼자 견디지 않았으면 좋겠어요.\n\n지금 바로 이야기할 수 있는 곳이 있어요.\n• **자살예방상담전화 109** (24시간)\n• **청소년상담 1388** (전화·문자·카카오톡, 24시간)\n• 위급하면 **112** 또는 **119**\n\n가까운 가족이나 선생님, 친구에게도 꼭 알려 주세요. 정말 소중한 사람이니까요.")
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

    static let facts = [
        "신기한 사실! 문어는 심장이 3개예요 🐙", "꿀은 상하지 않아서 수천 년 된 꿀도 먹을 수 있대요 🍯", "번개는 태양 표면보다 약 5배 뜨거워요 ⚡",
        "바나나는 식물학적으로 베리(장과)예요. 딸기는 아니고요! 🍌", "사람 몸의 혈관을 한 줄로 이으면 지구를 두 바퀴 넘게 감을 수 있대요 🌍",
        "0을 숫자로 처음 쓴 건 인도 수학자들이에요. 0 덕분에 지금의 계산법이 생겼어요.", "달은 매년 지구에서 약 3.8cm씩 멀어지고 있어요 🌙",
        "에펠탑은 여름에 열로 늘어나서 15cm쯤 더 높아져요 🗼", "기린은 하루에 30분 정도밖에 안 잔대요 🦒",
        "우리 뇌는 몸무게의 2%지만 에너지는 20%를 써요. 그래서 공부하면 배가 고파요! 🧠"
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

    /// 여러 말 중 하나 (최근에 한 말·바로 전 답과 같은 첫마디는 피함)
    private static func pick(_ list: [String]) -> String { DoitTone.pick(list) }

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
        return "힌트: '\(first)'\(DoitRelevance.josa(String(first), "으로")) 시작하고 \(answer.filter { !$0.isWhitespace }.count)글자예요."
    }
}
