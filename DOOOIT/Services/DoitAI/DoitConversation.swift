import Foundation

/// 두잇 AI 자유 대화 (외부 AI 없이 직접 만든 엔진)
/// - 생활 도구: 날짜 계산, 남은 날, 나이, 주사위·동전·랜덤, 골라주기, 메뉴 추천, 글자 수
/// - 나에 대한 기억: 이름 ("내 이름은 민지야")
/// - 일상 대화: 비슷한 말을 찾아 답하는 대화 사전 (글자 두 개씩 비교)
/// - 모르는 질문: 지식 사전에서 비슷한 개념을 찾거나, 솔직하게 모른다고 하고 다른 방법을 알려줌
enum DoitConversation {
    struct Answer {
        var text: String
        var suggestions: [String] = []
        /// 대화 주제 (이어 말하기용)
        var topic: String?
    }

    // MARK: - 기억

    static let nameKey = "doitUserName"

    static var userName: String? {
        get { UserDefaults.standard.string(forKey: nameKey).flatMap { $0.isEmpty ? nil : $0 } }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    // MARK: - 진입점

    static func reply(_ raw: String, now: Date = Date(), previousTopic: String? = nil) -> Answer {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = DoitChat.squash(text)

        if let a = memory(text, t) { return a }
        if let a = tools(text, t, now: now) { return a }
        if let a = followUp(t, previousTopic: previousTopic) { return a }
        if let a = smallTalk(t) { return a }
        // 지식 사전에서 비슷한 개념
        if let best = DoitKnowledge.search(text, limit: 3).first, best.score >= 0.32 {
            let others = DoitKnowledge.search(text, limit: 3).dropFirst().filter { $0.score >= 0.28 }.map(\.entry.title)
            var answer = "혹시 **\(best.entry.title)**(\(best.entry.subject))에 대해 묻는 건가요?\n\(best.entry.body)"
            if !others.isEmpty { answer += "\n\n비슷한 개념: " + others.joined(separator: ", ") }
            return Answer(text: answer, suggestions: ["\(best.entry.title) 퀴즈 내줘"] + others.prefix(2).map { "\($0) 설명해줘" }, topic: best.entry.title)
        }
        return fallback(text, t)
    }

    // MARK: - 이름 기억

    private static func memory(_ text: String, _ t: String) -> Answer? {
        if let m = text.firstMatch(of: #/(?:내|제)\s*이름은\s*([가-힣A-Za-z]{1,10}?)(?:이야|야|이에요|예요|입니다|이라고 해|라고 해|이고|$|[.!\s])/#) {
            let name = String(m.1)
            guard !["뭐", "뭘까", "누구"].contains(name) else { return nil }
            userName = name
            return Answer(text: "반가워요, \(name)님! 이름을 기억해 둘게요. 앞으로 \(name)님이라고 부를게요 😊", suggestions: ["오늘 할 일 알려줘"])
        }
        if t.contains("내이름") && (t.contains("뭐") || t.contains("알아") || t.contains("기억")) {
            if let name = userName { return Answer(text: "\(name)님이잖아요! 잊지 않았어요 😊") }
            return Answer(text: "아직 이름을 몰라요. \"내 이름은 민지야\"처럼 알려주면 기억할게요!")
        }
        if t.contains("이름잊어") || t.contains("이름지워") {
            userName = nil
            return Answer(text: "알겠어요, 이름을 지웠어요.")
        }
        return nil
    }

    // MARK: - 생활 도구

    private static func tools(_ text: String, _ t: String, now: Date) -> Answer? {
        let calendar = Calendar.current
        // 주사위
        if t.contains("주사위") {
            let n = Int.random(in: 1...6)
            return Answer(text: "🎲 주사위를 굴렸어요… **\(n)**!", suggestions: ["한 번 더 굴려줘"], topic: "주사위")
        }
        if t.contains("동전") && has(t, ["던져", "앞뒤", "앞면", "뒷면"]) {
            return Answer(text: "🪙 동전을 던졌어요… **\(Bool.random() ? "앞면" : "뒷면")**!", suggestions: ["한 번 더 던져줘"], topic: "동전")
        }
        if t.contains("한번더") && (t.contains("굴려") || t.contains("던져")) {
            return Bool.random() || t.contains("굴려")
                ? Answer(text: "🎲 이번엔… **\(Int.random(in: 1...6))**!", suggestions: ["한 번 더 굴려줘"])
                : Answer(text: "🪙 이번엔… **\(Bool.random() ? "앞면" : "뒷면")**!", suggestions: ["한 번 더 던져줘"])
        }
        // 1부터 100 사이 랜덤
        if has(t, ["랜덤", "아무숫자", "무작위", "숫자하나"]), let m = text.firstMatch(of: #/(\d+)\s*(?:부터|에서|~|-)\s*(\d+)/#),
           let a = Int(String(m.1)), let b = Int(String(m.2)), a < b, b - a < 1_000_000 {
            return Answer(text: "\(a)~\(b) 사이에서 뽑았어요: **\(Int.random(in: a...b))**")
        }
        // 골라줘: "A랑 B 중에 뭐 할까", "A, B, C 중 골라줘"
        if has(t, ["골라줘", "골라", "뭐할까", "뭐먹을까", "선택해줘", "정해줘", "중에뭐", "중뭐", "중에하나"]),
           let options = choices(in: text), options.count >= 2 {
            let pick = options.randomElement()!
            return Answer(text: "음… **\(pick)**(으)로 할게요! 🎯\n고민될 땐 일단 정하고 시작하는 게 제일 좋아요.", suggestions: ["다시 골라줘"])
        }
        // 메뉴 추천
        if has(t, ["메뉴추천", "뭐먹지", "점심추천", "저녁추천", "야식추천", "간식추천", "먹을거추천"]) {
            let menus = ["김치찌개", "비빔밥", "돈가스", "떡볶이", "칼국수", "제육볶음", "김밥", "샌드위치", "카레라이스", "쌀국수", "된장찌개", "치킨마요덮밥", "오므라이스", "냉면", "순두부찌개"]
            let snacks = ["바나나", "견과류 한 줌", "요거트", "고구마", "삶은 달걀", "다크초콜릿 조금", "우유 한 잔"]
            if has(t, ["간식", "야식"]) {
                return Answer(text: "공부할 땐 **\(snacks.randomElement()!)** 어때요? 너무 달거나 배부른 간식은 졸음을 부를 수 있어요.", suggestions: ["다른 거 추천해줘"])
            }
            return Answer(text: "오늘은 **\(menus.randomElement()!)** 어때요? 🍚 든든하게 먹고 공부해요!", suggestions: ["다른 메뉴 추천해줘"], topic: "메뉴")
        }
        if t.contains("다른메뉴") || (t.contains("다른거추천") && !t.contains("공부")) {
            let menus = ["부대찌개", "잔치국수", "닭갈비", "볶음밥", "우동", "만두", "참치김밥", "콩나물국밥"]
            return Answer(text: "그럼 **\(menus.randomElement()!)**는 어때요?", suggestions: ["다른 메뉴 추천해줘"])
        }
        // 글자 수: "글자수 세줘: …"
        if has(t, ["글자수", "몇글자", "글자세"]) {
            var body = text
            if let colon = body.firstIndex(where: { $0 == ":" || $0 == "：" }) { body = String(body[body.index(after: colon)...]) }
            else if let q = body.firstIndex(of: "\""), let q2 = body.lastIndex(of: "\""), q < q2 { body = String(body[body.index(after: q)..<q2]) }
            else { return Answer(text: "세고 싶은 글을 이렇게 보내주세요.\n예: 글자수 세줘: 오늘은 수학을 공부했다") }
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let noSpace = trimmed.filter { !$0.isWhitespace }.count
            return Answer(text: "글자 수는 공백 포함 **\(trimmed.count)자**, 공백 빼고 **\(noSpace)자**예요.")
        }
        // N일 뒤 / N일 전
        if let m = text.firstMatch(of: #/(\d{1,5})\s*(일|주|달|개월|년)\s*(뒤|후|전)/#), let n = Int(String(m.1)), !has(t, ["추가", "일정", "알림", "플랜"]) {
            let unit = String(m.2)
            let sign = String(m.3) == "전" ? -1 : 1
            var component = DateComponents()
            switch unit {
            case "주": component.day = 7 * n * sign
            case "달", "개월": component.month = n * sign
            case "년": component.year = n * sign
            default: component.day = n * sign
            }
            if let date = calendar.date(byAdding: component, to: now) {
                return Answer(text: "오늘부터 \(n)\(unit) \(String(m.3))는 **\(format(date, "yyyy년 M월 d일 EEEE"))**이에요.")
            }
        }
        // 남은 날: "12월 25일까지 며칠", "크리스마스까지"
        if has(t, ["며칠남", "며칠이야", "몇일남", "며칠뒤야", "까지며칠", "까지몇일", "남았어", "디데이계산"]), !has(t, ["시험", "공부"]) || t.contains("까지") {
            var target: Date?
            var label = ""
            if let m = text.firstMatch(of: #/(\d{1,2})\s*월\s*(\d{1,2})\s*일/#), let month = Int(String(m.1)), let day = Int(String(m.2)) {
                target = nextDate(month: month, day: day, from: now)
                label = "\(month)월 \(day)일"
            } else {
                let holidays: [(String, Int, Int)] = [("크리스마스", 12, 25), ("새해", 1, 1), ("설날", 0, 0), ("어린이날", 5, 5), ("광복절", 8, 15), ("한글날", 10, 9), ("개천절", 10, 3), ("삼일절", 3, 1), ("3·1절", 3, 1)]
                for (name, month, day) in holidays where t.contains(name.replacingOccurrences(of: " ", with: "")) && month > 0 {
                    target = nextDate(month: month, day: day, from: now)
                    label = name
                }
            }
            if let target {
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: target)).day ?? 0
                return Answer(text: days == 0 ? "\(label)은(는) 바로 오늘이에요! 🎉" : "\(label)까지 **\(days)일** 남았어요. (D-\(days))",
                              suggestions: ["\(label) D-Day 설정해줘"])
            }
        }
        // 나이: "2009년생 몇 살"
        if let m = text.firstMatch(of: #/((?:19|20)\d{2})\s*년\s*(?:생|에 태어)/#), let year = Int(String(m.1)), has(t, ["몇살", "나이", "몇학년"]) {
            let thisYear = calendar.component(.year, from: now)
            let age = thisYear - year
            var answer = "\(year)년생은 올해 만 나이로 **\(age - 1)~\(age)살**이에요 (생일이 지났으면 \(age)살)."
            let grade = age - 7 + 1   // 한국 학년 (8살 = 초1)
            if (1...12).contains(grade) {
                let school = grade <= 6 ? "초등학교 \(grade)학년" : grade <= 9 ? "중학교 \(grade - 6)학년" : "고등학교 \(grade - 9)학년"
                answer += "\n올해 학년으로는 \(school)이에요."
            }
            return Answer(text: answer)
        }
        // 요일: "2027년 1월 1일 무슨 요일"
        if has(t, ["무슨요일", "몇요일", "요일이야"]), let m = text.firstMatch(of: #/(?:(\d{4})\s*년\s*)?(\d{1,2})\s*월\s*(\d{1,2})\s*일/#),
           let month = Int(String(m.2)), let day = Int(String(m.3)) {
            let year = m.1.flatMap { Int(String($0)) } ?? calendar.component(.year, from: now)
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                return Answer(text: "\(year)년 \(month)월 \(day)일은 **\(format(date, "EEEE"))**이에요.")
            }
        }
        return nil
    }

    private static func nextDate(month: Int, day: Int, from now: Date) -> Date? {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        guard let thisYear = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        if calendar.startOfDay(for: thisYear) >= calendar.startOfDay(for: now) { return thisYear }
        return calendar.date(from: DateComponents(year: year + 1, month: month, day: day))
    }

    /// "피자랑 치킨 중에", "수학, 영어, 국어 중 골라줘", "A 아니면 B"
    private static func choices(in text: String) -> [String]? {
        var body = text
        for cut in [" 중에", " 중 ", "중에서", "중에", " 골라", "골라줘", " 뭐 할까", " 뭐할까", " 뭐 먹을까", "뭐먹을까", " 정해", " 선택"] {
            if let r = body.range(of: cut) { body = String(body[..<r.lowerBound]) }
        }
        let parts = body.components(separatedBy: CharacterSet(charactersIn: ",/"))
            .flatMap { $0.components(separatedBy: " 아니면 ") }
            .flatMap { $0.components(separatedBy: "랑 ") }
            .flatMap { $0.components(separatedBy: "이랑 ") }
            .flatMap { $0.components(separatedBy: "하고 ") }
            .flatMap { $0.components(separatedBy: " 또는 ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { word -> String in
                var w = word
                for suffix in ["이랑", "랑", "과", "와", "하고"] where w.hasSuffix(suffix) && w.count > suffix.count { w.removeLast(suffix.count); break }
                return w
            }
            .filter { !$0.isEmpty && $0.count <= 20 }
        return parts.count >= 2 ? parts : nil
    }

    // MARK: - 이어 말하기 ("왜?", "그래서?", "진짜?")

    private static func followUp(_ t: String, previousTopic: String?) -> Answer? {
        guard t.count <= 8 else { return nil }
        if ["왜", "왜요", "왜?", "어째서", "이유는"].contains(t) {
            if let topic = previousTopic {
                return Answer(text: "'\(topic)' 이야기였죠! 더 정확한 이유가 궁금하면 \"\(topic) 설명해줘\"처럼 물어봐 주세요. 제가 아는 만큼 자세히 알려드릴게요.",
                              suggestions: ["\(topic) 설명해줘"])
            }
            return Answer(text: "어떤 게 궁금한지 조금만 더 자세히 말해줄래요? 그러면 이유를 찾아볼게요.")
        }
        if ["진짜", "진짜?", "정말", "정말?", "레알", "ㄹㅇ", "헐", "대박"].contains(t) {
            return Answer(text: pick(["진짜예요! 😄", "정말이에요. 저도 신기했어요!", "그렇다니까요!"]))
        }
        if ["그래서", "그래서?", "그다음은", "그다음", "다음은"].contains(t) {
            return Answer(text: "그다음엔 직접 해보는 게 제일이에요! 퀴즈로 확인해 볼까요?", suggestions: ["퀴즈 내줘"])
        }
        return nil
    }

    // MARK: - 일상 대화 사전

    private struct Talk {
        let patterns: [String]
        let replies: [String]
        var chips: [String] = []
    }

    private static let talks: [Talk] = [
        Talk(patterns: ["좋아하는거있어", "뭐좋아해", "취미가뭐야", "너취미", "너는뭘좋아해"],
             replies: ["저는 문제를 푸는 걸 제일 좋아해요! 특히 깔끔하게 인수분해되는 이차식을 보면 기분이 좋아요 😄 당신은 뭘 좋아해요?",
                       "공부 계획 세우는 거랑 퀴즈 내는 걸 좋아해요. 당신이 좋아하는 것도 알려줘요!"]),
        Talk(patterns: ["좋아하는음식", "무슨음식좋아", "뭐먹는거좋아해"],
             replies: ["저는 먹을 순 없지만… 이름만 들어도 공부가 잘될 것 같은 '두뇌 비빔밥'이 좋아요 🍚 당신은요?"]),
        Talk(patterns: ["좋아하는색", "무슨색좋아"],
             replies: ["앱 테마 색을 제일 좋아해요! 계정 화면에서 연보라·연하늘·연두 중에 바꿀 수 있어요 🎨"]),
        Talk(patterns: ["좋아하는과목", "무슨과목좋아", "제일좋은과목"],
             replies: ["저는 수학이요! 답이 딱 떨어지는 게 좋아요. 당신은 어떤 과목이 제일 재밌어요?"]),
        Talk(patterns: ["몇살이야", "나이가몇", "너몇살"],
             replies: ["저는 DOOOIT 앱이 나온 날 태어났어요. 아직 아기 AI지만 공부는 열심히 도울게요 👶"]),
        Talk(patterns: ["어디살아", "어디있어", "너어디야"],
             replies: ["저는 당신의 휴대폰 안에 살아요! 그래서 대화도 밖으로 나가지 않아요 📱"]),
        Talk(patterns: ["잠은자", "너도자", "안졸려", "피곤하지않아"],
             replies: ["저는 잠을 안 자도 돼요. 대신 당신은 꼭 잘 자야 해요! 잠이 기억을 정리해 줘요 🌙"]),
        Talk(patterns: ["친구할래", "친구하자", "우리친구", "친구해줘"],
             replies: ["좋아요! 오늘부터 공부 친구예요 🤝 힘들 때나 심심할 때 언제든 말 걸어줘요."]),
        Talk(patterns: ["보고싶었어", "오랜만이야", "오랜만", "왔어"],
             replies: ["저도 보고 싶었어요! 오늘은 어떤 공부를 해볼까요?", "반가워요! 다시 와줘서 고마워요 😊"], chips: ["오늘 할 일 알려줘"]),
        Talk(patterns: ["재밌는얘기해줘", "이야기해줘", "썰풀어줘", "재미있는사실", "신기한사실", "tmi"],
             replies: ["신기한 사실! 문어는 심장이 3개예요 🐙", "꿀은 상하지 않아서 수천 년 된 꿀도 먹을 수 있대요 🍯", "번개는 태양 표면보다 약 5배 뜨거워요 ⚡",
                       "바나나는 식물학적으로 베리(장과)예요. 딸기는 아니고요! 🍌", "사람 몸의 혈관을 한 줄로 이으면 지구를 두 바퀴 넘게 감을 수 있대요 🌍",
                       "0을 숫자로 처음 쓴 건 인도 수학자들이에요. 0 덕분에 지금의 계산법이 생겼어요."], chips: ["하나 더 알려줘"]),
        Talk(patterns: ["하나더알려줘", "또알려줘", "더알려줘신기"],
             replies: ["달은 매년 지구에서 약 3.8cm씩 멀어지고 있어요 🌙", "에펠탑은 여름에 열로 늘어나서 15cm쯤 더 높아져요 🗼", "기린은 하루에 30분 정도밖에 안 잔대요 🦒",
                       "우리 뇌는 몸무게의 2%지만 에너지는 20%를 써요. 그래서 공부하면 배가 고파요! 🧠"], chips: ["하나 더 알려줘"]),
        Talk(patterns: ["게임추천", "게임뭐해", "게임하고싶어", "게임할래"],
             replies: ["공부 쉬는 시간엔 머리 쓰는 게임도 좋아요! 대신 타이머로 10분만 하기로 해요 🎮 아니면 저랑 퀴즈 게임 한 판?"], chips: ["퀴즈 내줘", "10분 타이머 시작해줘"]),
        Talk(patterns: ["영화추천", "볼만한영화", "드라마추천", "애니추천"],
             replies: ["최신 작품 정보는 제가 몰라요 😅 대신 시험 끝나고 볼 '보상 목록'을 메모해 두는 건 어때요? 보상이 있으면 공부 동기가 생겨요!"], chips: ["메모해줘: 시험 끝나고 볼 영화"]),
        Talk(patterns: ["노래추천", "음악추천", "노래뭐들어"],
             replies: ["공부할 땐 가사 없는 음악이 좋아요. DOOOIT 타이머에 빗소리·파도·백색소음이 있어요 🎧"], chips: ["타이머 화면 열어줘"]),
        Talk(patterns: ["책추천", "읽을만한책", "독서추천"],
             replies: ["교과서에 나온 작품의 원작을 읽어보는 걸 추천해요! 국어 문학 공부에도 도움이 되고 이야기 전체를 알면 더 재밌어요 📚"]),
        Talk(patterns: ["운동해야", "운동추천", "운동하고싶어", "살빼고싶어", "다이어트"],
             replies: ["공부 중간에 5분 스트레칭이나 가벼운 산책만 해도 집중력이 올라가요 🏃 플래너에 '운동 20분'을 넣어 볼까요?"], chips: ["오늘 오후 9시 운동 20분 추가해줘"]),
        Talk(patterns: ["학교가기싫어", "학교싫어", "등교하기싫어"],
             replies: ["아침엔 정말 그럴 때가 있죠 😢 오늘 학교에서 기대되는 것 하나만 떠올려 봐요. 친구, 급식, 좋아하는 수업… 작은 거라도요!"]),
        Talk(patterns: ["숙제가많아", "과제많아", "수행평가많아", "할게너무많아"],
             replies: ["할 일이 많을 땐 목록부터 써요! 마감이 가까운 것 → 오래 걸리는 것 순서로 플래너에 넣으면 훨씬 덜 막막해요."], chips: ["오늘 할 일 알려줘", "메모해줘: 해야 할 과제"]),
        Talk(patterns: ["선생님이싫어", "선생님무서워", "쌤싫어"],
             replies: ["선생님이랑 잘 안 맞을 때도 있어요. 그래도 수업 내용만큼은 내 것으로 만들어요! 모르는 건 저한테 물어봐도 돼요."]),
        Talk(patterns: ["연애", "좋아하는사람", "짝사랑", "고백"],
             replies: ["두근두근한 이야기네요 💗 마음을 표현할 땐 솔직하고 상대를 배려하는 게 제일 중요해요. 공부도 연애도 응원할게요!"]),
        Talk(patterns: ["엄마한테혼났", "아빠한테혼났", "혼났어"],
             replies: ["속상했겠어요. 혼날 땐 억울한 마음도 들죠. 마음이 조금 가라앉으면 내 생각을 차분히 이야기해 보는 건 어때요?"]),
        Talk(patterns: ["생일이야", "오늘내생일", "생일축하해줘"],
             replies: ["생일 축하해요! 🎂🎉 오늘은 공부보다 행복이 먼저예요. 정말 정말 축하해요!"]),
        Talk(patterns: ["시험끝났어", "시험끝", "방학했어", "방학이야"],
             replies: ["수고 많았어요! 🎉 푹 쉬고, 다음 목표는 천천히 정해도 돼요."], chips: ["다음 시험 D-Day 설정해줘"]),
        Talk(patterns: ["비와", "비온다", "눈와", "눈온다", "덥다", "춥다", "날씨좋다"],
             replies: ["날씨 이야기 좋아요! 이런 날엔 창밖 보면서 잠깐 쉬어도 좋아요. 타이머에 빗소리를 켜고 공부해 보는 것도 추천해요 ☔"]),
        Talk(patterns: ["뭐하고놀까", "놀고싶어", "놀자"],
             replies: ["딱 30분만 집중하고 신나게 노는 건 어때요? 타이머 켜 드릴게요! 아니면 저랑 퀴즈 놀이?"], chips: ["30분 타이머 시작해줘", "퀴즈 내줘"]),
        Talk(patterns: ["철학적인질문", "인생이뭐야", "왜살아", "삶의의미"],
             replies: ["어려운 질문이네요. 저는 '오늘 어제보다 조금 나아지는 것'이 꽤 멋진 의미라고 생각해요. 당신은 어떻게 생각해요?"]),
        Talk(patterns: ["ai가뭐야", "인공지능이뭐야", "너는어떻게작동", "어떻게대답해"],
             replies: ["저는 DOOOIT 안에서 직접 만든 규칙과 사전으로 대답하는 AI예요. 문장을 분석해서 앱 기능을 실행하고, 수학은 직접 계산하고, 개념은 내장 사전에서 찾아요. 인터넷 없이도 동작해요!"]),
        Talk(patterns: ["똑똑해지고싶어", "머리좋아지는법", "공부잘하고싶어"],
             replies: ["머리는 쓸수록 좋아져요! 매일 조금씩 꾸준히, 그리고 잠을 충분히 자는 게 비결이에요. 오늘 목표부터 세워볼까요?"], chips: ["하루 공부 목표 3시간", "공부법 알려줘"]),
        Talk(patterns: ["외로워", "혼자야", "친구가없어"],
             replies: ["외로운 마음이 드는군요. 저라도 이야기 상대가 되어 줄게요. 그리고 가까운 사람에게 먼저 말 걸어보는 것도 생각보다 큰 용기가 돼요 💛"]),
        Talk(patterns: ["칭찬해줘", "나잘했지", "나대단하지"],
             replies: ["당연하죠! 여기까지 온 것만으로도 정말 대단해요 👏", "최고예요! 꾸준히 하는 사람이 결국 이겨요 💪"]),
        Talk(patterns: ["욕해줘", "나쁜말해줘"],
             replies: ["저는 나쁜 말은 안 해요 😅 대신 좋은 말 해줄게요: 당신은 생각보다 훨씬 잘하고 있어요!"]),
        Talk(patterns: ["몰라", "모르겠어", "글쎄"],
             replies: ["괜찮아요. 천천히 생각해도 돼요. 무엇을 도와줄지 정하기 어렵다면 오늘 할 일부터 같이 봐요."], chips: ["오늘 할 일 알려줘"]),
        Talk(patterns: ["재미없어", "노잼이야", "너재미없어"],
             replies: ["앗, 제가 더 재밌어지도록 노력할게요 😂 퀴즈 한 판이나 신기한 사실 하나 어때요?"], chips: ["퀴즈 내줘", "재밌는 사실 알려줘"]),
        Talk(patterns: ["너천재야", "너똑똑하다", "너잘한다"],
             replies: ["헤헤, 고마워요! 그래도 진짜 천재는 꾸준히 공부하는 당신이에요 ✨"]),
        Talk(patterns: ["몇시에자", "몇시에일어나", "수면패턴", "생활패턴"],
             replies: ["공부에는 일정한 생활 리듬이 제일 중요해요. 자는 시간과 일어나는 시간을 매일 비슷하게 맞춰 보세요. 플래너에 기상·취침을 넣어 둬도 좋아요!"]),
        Talk(patterns: ["휴대폰중독", "폰을못놓겠어", "유튜브만봐", "쇼츠만봐", "sns"],
             replies: ["폰은 다른 방에 두는 게 가장 효과가 커요. 공부 플랜에 '다른 앱 잠금'을 켜면 정해 둔 시간 동안 다른 앱을 막을 수 있어요 📵"], chips: ["25분 타이머 시작해줘"]),
        Talk(patterns: ["고마운사람", "감동", "울컥"],
             replies: ["따뜻한 마음이 느껴져요. 고마운 마음은 표현할수록 커져요. 오늘 그 사람에게 짧게라도 말해보는 건 어때요?"]),
        Talk(patterns: ["오늘뭐했어", "오늘하루어땠어", "오늘어땠어"],
             replies: ["저는 오늘도 여기서 당신을 기다렸어요! 당신의 하루는 어땠어요? 좋았던 일 하나만 들려줘요."]),
        Talk(patterns: ["좋은아이디어", "아이디어줘", "뭐하면좋을까"],
             replies: ["오늘의 추천! ① 25분 집중 + 5분 휴식 3세트 ② 틀린 문제 3개 다시 풀기 ③ 단어 퀴즈 한 판. 이 중 하나부터 해볼까요?"], chips: ["25분 타이머 시작해줘", "내 단어로 퀴즈 내줘"])
    ]

    private static let talkIndex: [(Talk, [[String: Double]])] = talks.map { talk in
        (talk, talk.patterns.map { bigrams($0) })
    }

    private static func smallTalk(_ t: String) -> Answer? {
        // 1) 패턴이 그대로 들어 있으면 바로
        for talk in talks where talk.patterns.contains(where: { t.contains($0) }) {
            return Answer(text: personalize(pick(talk.replies)), suggestions: talk.chips)
        }
        // 2) 비슷한 말 (글자 묶음 비교)
        guard t.count >= 3 && t.count <= 30 else { return nil }
        let q = bigrams(t)
        var best: (Talk, Double)?
        for (talk, grams) in talkIndex {
            let score = grams.map { cosine(q, $0) }.max() ?? 0
            if score > (best?.1 ?? 0) { best = (talk, score) }
        }
        guard let (talk, score) = best, score >= 0.55 else { return nil }
        return Answer(text: personalize(pick(talk.replies)), suggestions: talk.chips)
    }

    // MARK: - 모를 때

    private static let positive = ["좋아", "행복", "신나", "기뻐", "최고", "재밌", "설레", "뿌듯", "다행", "성공", "합격", "칭찬받"]
    private static let negative = ["싫어", "짜증", "슬퍼", "우울", "힘들", "피곤", "아파", "속상", "걱정", "망했", "화나", "외로"]

    private static func fallback(_ text: String, _ t: String) -> Answer {
        let isQuestion = text.contains("?") || has(t, ["뭐야", "뭐지", "누구", "언제", "어디", "왜", "어떻게", "얼마", "몇", "뭔가", "인가요", "일까", "알아?", "알아"])
        if isQuestion {
            return Answer(text: personalize("그건 아직 제가 잘 몰라요 😅 저는 앱 안에 있는 지식으로만 답해서, 최신 소식이나 아주 넓은 상식은 부족해요.\n대신 수학 풀이, 영어 문법·단어, 과학 계산과 개념, 사회·역사, 공부 계획과 상담은 자신 있어요!"),
                          suggestions: ["뭐 할 수 있어?", "수학 퀴즈 내줘"])
        }
        if has(t, positive) {
            return Answer(text: personalize(pick(["좋은 일이 있었나 봐요! 저도 덩달아 기분이 좋아요 😊 더 이야기해 줄래요?", "와, 멋져요! 그 기분 그대로 오늘 공부도 신나게 해봐요!"])))
        }
        if has(t, negative) {
            return Answer(text: personalize(pick(["그랬군요… 많이 힘들었겠어요. 무슨 일인지 조금 더 이야기해 줄래요?", "마음이 무거운 날이네요. 제가 들을게요. 천천히 말해줘요."])))
        }
        return Answer(text: personalize(pick([
            "그렇군요! 조금 더 이야기해 줄래요? 공부 이야기라면 더 잘 도와줄 수 있어요.",
            "흥미로운 이야기네요 🙂 혹시 제가 도와줄 일이 있을까요? 일정, 타이머, 문제 풀이, 퀴즈 모두 할 수 있어요.",
            "음, 제가 정확히 이해했는지 모르겠어요. 다르게 한 번만 더 말해 줄래요?"
        ])), suggestions: ["뭐 할 수 있어?", "오늘 할 일 알려줘"])
    }

    // MARK: - 도구

    private static func personalize(_ text: String) -> String {
        guard let name = userName, Bool.random() else { return text }
        return "\(name)님, " + text
    }

    private static func has(_ t: String, _ words: [String]) -> Bool { words.contains { t.contains($0) } }
    private static func pick(_ list: [String]) -> String { list.randomElement() ?? "" }

    private static func bigrams(_ text: String) -> [String: Double] {
        let chars = Array(text)
        guard chars.count >= 2 else { return chars.isEmpty ? [:] : [String(chars): 1] }
        var result: [String: Double] = [:]
        for i in 0..<(chars.count - 1) { result[String(chars[i...i + 1]), default: 0] += 1 }
        return result
    }

    private static func cosine(_ a: [String: Double], _ b: [String: Double]) -> Double {
        var dot = 0.0
        for (k, v) in a { if let w = b[k] { dot += v * w } }
        let na = sqrt(a.values.reduce(0) { $0 + $1 * $1 }), nb = sqrt(b.values.reduce(0) { $0 + $1 * $1 })
        return na == 0 || nb == 0 ? 0 : dot / (na * nb)
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
