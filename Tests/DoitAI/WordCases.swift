import Foundation

// MARK: - 단어장 사진 100가지 (Vision이 실제로 돌려주는 모양 흉내)
// Vision 좌표는 0~1, 아래가 0 → 위쪽 줄일수록 y가 큼

/// 한 줄 = 글자 상자 하나 (위에서 아래로)
private func wcLines(_ rows: [String], confidence: [Int: Float] = [:]) -> [OCRLine] {
    rows.enumerated().map { i, text in
        OCRLine(text: text, confidence: confidence[i] ?? 1, box: CGRect(x: 0.05, y: 0.95 - Double(i) * 0.04, width: 0.9, height: 0.03))
    }
}

/// 표: 한 줄에 칸(상자)이 여러 개. xs = 칸마다 왼쪽 x, jitter = 짝수 번째가 아닌 칸의 높이 흔들림
private func wcTable(_ rows: [[String]], xs: [Double], confidence: [String: Float] = [:], jitter: Double = 0, top: Double = 0.9) -> [OCRLine] {
    var lines: [OCRLine] = []
    for (r, cells) in rows.enumerated() {
        for (c, text) in cells.enumerated() where !text.isEmpty {
            let x = xs[c]
            let right = c + 1 < xs.count ? xs[c + 1] - 0.03 : min(0.95, x + 0.3)
            let y = top - Double(r) * 0.06 + (c % 2 == 1 ? jitter : 0)
            lines.append(OCRLine(text: text, confidence: confidence[text] ?? 1,
                                 box: CGRect(x: x, y: y, width: max(0.05, right - x), height: c % 2 == 1 ? 0.03 + abs(jitter) : 0.03)))
        }
    }
    return lines
}

/// 두 단 페이지: 왼쪽 단과 오른쪽 단이 같은 높이에 나란히
private func wcColumns(_ left: [String], _ right: [String], spacing: Double = 0.07) -> [OCRLine] {
    var lines: [OCRLine] = []
    for (i, text) in left.enumerated() { lines.append(OCRLine(text: text, box: CGRect(x: 0.05, y: 0.88 - Double(i) * spacing, width: 0.38, height: 0.03))) }
    for (i, text) in right.enumerated() { lines.append(OCRLine(text: text, box: CGRect(x: 0.55, y: 0.88 - Double(i) * spacing, width: 0.38, height: 0.03))) }
    return lines
}

private func wcFormat(_ words: [ParsedWord]) -> String {
    words.map { "\($0.term)=\($0.meaning)" }.joined(separator: " | ")
}

private struct WordPhotoCase {
    let name: String
    let lines: [OCRLine]
    let expect: String
    init(_ name: String, _ lines: [OCRLine], _ expect: String) {
        self.name = name; self.lines = lines; self.expect = expect
    }
    init(_ name: String, rows: [String], _ expect: String) {
        self.init(name, wcLines(rows), expect)
    }
}

func runWordCases() {
    var cases: [WordPhotoCase] = []
    func add(_ name: String, _ rows: [String], _ expect: String) { cases.append(WordPhotoCase(name, rows: rows, expect)) }
    func add(_ name: String, lines: [OCRLine], _ expect: String) { cases.append(WordPhotoCase(name, lines, expect)) }

    // MARK: 단순 목록
    add("기본 목록", ["apple 사과", "banana 바나나", "cherry 체리"], "apple=사과 | banana=바나나 | cherry=체리")
    add("번호 점", ["1. apple 사과", "2. banana 바나나", "3. cherry 체리"], "apple=사과 | banana=바나나 | cherry=체리")
    add("번호 괄호 여러 모양", ["1) apple 사과", "(2) banana 바나나", "[3] cherry 체리"], "apple=사과 | banana=바나나 | cherry=체리")
    add("0 채운 번호", ["01 apple 사과", "02 banana 바나나", "003 cherry 체리"], "apple=사과 | banana=바나나 | cherry=체리")
    add("체크박스 여러 모양", ["□ apple 사과", "☐ banana 바나나", "■ cherry 체리", "☑ grape 포도"], "apple=사과 | banana=바나나 | cherry=체리 | grape=포도")
    add("번호 + 체크박스", ["1 □ apple 사과", "2 □ banana 바나나", "3 □ cherry 체리"], "apple=사과 | banana=바나나 | cherry=체리")
    add("체크박스 + 번호", ["□ 1. apple 사과", "□ 2. banana 바나나"], "apple=사과 | banana=바나나")
    add("하이픈·대시 구분", ["apple - 사과", "banana – 바나나", "cherry — 체리"], "apple=사과 | banana=바나나 | cherry=체리")
    add("콜론 구분", ["apple : 사과", "banana: 바나나", "cherry ：체리"], "apple=사과 | banana=바나나 | cherry=체리")
    add("등호 구분 (뜻이 한글)", ["apple = 사과", "banana = 바나나"], "apple=사과 | banana=바나나")
    add("글머리표 여러 모양", ["• apple 사과", "· banana 바나나", "- cherry 체리", "* grape 포도", "✓ melon 멜론"],
        "apple=사과 | banana=바나나 | cherry=체리 | grape=포도 | melon=멜론")
    add("띄어쓰기 없이 붙음", ["apple사과", "banana바나나"], "apple=사과 | banana=바나나")
    add("여분 공백·탭", ["  apple     사과  ", "banana\t바나나", "cherry  체리 ,  버찌"], "apple=사과 | banana=바나나 | cherry=체리, 버찌")
    add("뜻 끝 문장부호", ["apple 사과.", "banana 바나나;", "cherry 체리,"], "apple=사과 | banana=바나나 | cherry=체리")
    add("단어 끝 문장부호", ["apple. 사과", "banana, 바나나", "cherry: 체리"], "apple=사과 | banana=바나나 | cherry=체리")
    add("따옴표 친 단어", ["“apple” 사과", "'banana' 바나나"], "apple=사과 | banana=바나나")
    add("대문자 고유명사 유지", ["Monday 월요일", "Korea 한국"], "Monday=월요일 | Korea=한국")
    add("영국식 철자", ["colour 색깔", "favourite 가장 좋아하는", "centre 중심"], "colour=색깔 | favourite=가장 좋아하는 | centre=중심")
    add("영국식 병기 (= colour)", ["color (= colour) 색깔", "center (= centre) 중심"], "color=색깔 | center=중심")
    add("하이픈 단어", ["well-known 잘 알려진", "self-esteem 자존감", "up-to-date 최신의"], "well-known=잘 알려진 | self-esteem=자존감 | up-to-date=최신의")
    add("아포스트로피 단어", ["o'clock ~시 (정각)", "don't ~하지 마라"], "o'clock=~시 (정각) | don't=~하지 마라")
    add("숫자 섞인 철자 교정", ["app1e 사과", "c0ntinent 대륙", "5mall 작은", "inf1uence 영향"], "apple=사과 | continent=대륙 | small=작은 | influence=영향")
    add("뜻 속 숫자는 그대로", ["century 세기, 100년", "decade 10년", "dozen 12개, 다스"], "century=세기, 100년 | decade=10년 | dozen=12개, 다스")
    add("뜻 속 영어 설명 괄호", ["child 아이 (복수형 children)", "mouse 쥐 (복수형 mice)"], "child=아이 (복수형 children) | mouse=쥐 (복수형 mice)")

    // MARK: 표 테두리·잡음
    add("표 테두리 | 띄어 있음", ["apple | 사과", "| banana | 바나나 |", "cherry |체리"], "apple=사과 | banana=바나나 | cherry=체리")
    add("표 테두리 | 단어에 붙음", ["|apple 사과", "|banana 바나나|", "cherry| 체리"], "apple=사과 | banana=바나나 | cherry=체리")
    add("머리말·꼬리말 영어", ["Word List", "DAY 01", "apple 사과", "banana 바나나", "Check up"], "apple=사과 | banana=바나나")
    add("Unit 머리말 + 세로형", ["Unit 3", "lettuce", "상추", "vitamin", "비타민"], "lettuce=상추 | vitamin=비타민")
    add("Unit 제목 머리말", ["Unit 3 Food and Health", "lettuce 상추", "vitamin 비타민"], "lettuce=상추 | vitamin=비타민")
    add("Lesson·Chapter 머리말 중간", ["Lesson 2", "apple 사과", "Chapter 5", "banana 바나나", "Part 1", "cherry 체리"], "apple=사과 | banana=바나나 | cherry=체리")
    add("출판사·쪽수 꼬리말", ["apple 사과", "banana 바나나", "© 2024 Doit Books", "p. 34"], "apple=사과 | banana=바나나")
    add("쪽수 여러 모양", ["- 12 -", "apple 사과", "banana 바나나", "12 / 80", "www.doitbooks.com"], "apple=사과 | banana=바나나")
    add("한글 머리말·꼬리말", ["단어 뜻", "apple 사과", "banana 바나나", "1일차"], "apple=사과 | banana=바나나")
    add("Vocabulary 머리말 + 세로형 단어", ["Vocabulary", "apple 사과", "review", "복습하다"], "apple=사과 | review=복습하다")

    // MARK: 품사
    add("영어 품사 한 줄", ["apple n. 사과"], "apple=n. 사과")
    add("영어 품사 여러 줄", ["apple n. 사과", "run v. 달리다", "happy adj. 행복한", "quickly adv. 빨리"],
        "apple=n. 사과 | run=v. 달리다 | happy=adj. 행복한 | quickly=adv. 빨리")
    add("전치사·접속사 영어 품사", ["during prep. ~동안", "although conj. 비록 ~이지만"], "during=prep. ~동안 | although=conj. 비록 ~이지만")
    add("한글 품사", ["apple 명 사과", "run 동 달리다", "happy 형 행복한", "quickly 부 빨리"], "apple=명 사과 | run=동 달리다 | happy=형 행복한 | quickly=부 빨리")
    add("한글 품사 전·접", ["during 전 ~동안", "although 접 비록 ~이지만"], "during=전 ~동안 | although=접 비록 ~이지만")
    add("대괄호 품사 [명]", ["apple [명] 사과", "run [동] 달리다"], "apple=명 사과 | run=동 달리다")
    add("소괄호 품사 (동)", ["apple (명) 사과", "run (동) 달리다"], "apple=명 사과 | run=동 달리다")
    add("영어 품사 괄호 (n.)", ["apple (n.) 사과", "run (v.) 달리다"], "apple=n. 사과 | run=v. 달리다")
    add("한 단어 품사 두 개", ["record [rékɔːrd] 명 기록 동 기록하다"], "record=명 기록, 동 기록하다")
    add("한 단어 영어 품사 두 개", ["run [rʌn] v. 달리다 n. 달리기"], "run=v. 달리다, n. 달리기")
    add("영어 품사 + 괄호 뜻", ["employ v. (사람을) 고용하다"], "employ=v. (사람을) 고용하다")
    add("단어 줄에 품사, 뜻은 다음 줄", ["apple n.", "사과", "run v.", "달리다"], "apple=n. 사과 | run=v. 달리다")

    // MARK: 발음 기호
    add("대괄호 발음 + 뜻", ["apple [ǽpl] 사과", "banana [bənǽnə] 바나나"], "apple=사과 | banana=바나나")
    add("슬래시 발음 + 품사", ["apple /ǽpl/ 명 사과", "banana /bənǽnə/ 명 바나나"], "apple=명 사과 | banana=명 바나나")
    add("슬래시 발음 (품사 없음)", ["apple /ǽpl/ 사과", "banana /bənǽnə/ 바나나"], "apple=사과 | banana=바나나")
    add("깨진 괄호 발음", ["apple [aepl) 명 사과", "banana (bənǽnə] 명 바나나"], "apple=명 사과 | banana=명 바나나")
    add("발음만 단어 줄, 뜻 다음 줄", ["apple [ǽpl]", "사과", "banana [bənǽnə]", "바나나"], "apple=사과 | banana=바나나")
    add("발음 하나뿐인 목록", ["abandon [əbǽndən] 동 버리다", "give up 포기하다", "take part in ~에 참가하다"],
        "abandon=동 버리다 | give up=포기하다 | take part in=~에 참가하다")

    // MARK: 뜻 여러 개
    add("원문자 뜻", ["apple ① 사과 ② 사과나무", "bank ① 은행 ② 둑"], "apple=사과, 사과나무 | bank=은행, 둑")
    add("번호 뜻", ["run 1. 달리다 2. 운영하다", "bank 1) 은행 2) 둑"], "run=달리다, 운영하다 | bank=은행, 둑")
    add("괄호 번호 뜻", ["run (1) 달리다 (2) 운영하다"], "run=달리다, 운영하다")
    add("세미콜론 뜻", ["bright 밝은; 영리한", "light 빛; 가벼운"], "bright=밝은, 영리한 | light=빛, 가벼운")
    add("원문자 + 품사 (책)", ["bank [bæŋk] 명 ① 은행 ② 둑", "fine [fain] 형 ① 좋은 ② 미세한 명 벌금"], "bank=명 은행, 둑 | fine=형 좋은, 미세한, 명 벌금")
    add("긴 뜻 (괄호 설명)", ["procrastinate (해야 할 일을) 미루다, 꾸물거리다, 질질 끌다"], "procrastinate=(해야 할 일을) 미루다, 꾸물거리다, 질질 끌다")
    add("긴 뜻 네 개", ["accommodate 수용하다, 공간을 제공하다, (요구 등을) 들어주다, 숙박시키다"], "accommodate=수용하다, 공간을 제공하다, (요구 등을) 들어주다, 숙박시키다")
    add("괄호로 시작하는 뜻", ["employ (사람을) 고용하다", "attend (회의 등에) 참석하다"], "employ=(사람을) 고용하다 | attend=(회의 등에) 참석하다")
    add("물결 뜻", ["hire ~을 고용하다", "depend on ~에 의존하다", "instead of ~ 대신에"], "hire=~을 고용하다 | depend on=~에 의존하다 | instead of=~ 대신에")

    // MARK: 숙어·구동사
    add("숙어 기본", ["give up 포기하다", "put off 미루다, 연기하다", "take care of ~을 돌보다", "a lot of 많은"],
        "give up=포기하다 | put off=미루다, 연기하다 | take care of=~을 돌보다 | a lot of=많은")
    add("be동사 숙어", ["be good at ~을 잘하다", "be interested in ~에 관심이 있다", "be afraid of ~을 두려워하다"],
        "be good at=~을 잘하다 | be interested in=~에 관심이 있다 | be afraid of=~을 두려워하다")
    add("~ing 숙어", ["look forward to ~ing ~을 고대하다", "be used to ~ing ~에 익숙하다"], "look forward to ~ing=~을 고대하다 | be used to ~ing=~에 익숙하다")
    add("one's 숙어", ["make up one's mind 결심하다", "do one's best 최선을 다하다"], "make up one's mind=결심하다 | do one's best=최선을 다하다")
    add("A B 자리 숙어", ["not only A but also B A뿐만 아니라 B도", "both A and B A와 B 둘 다"], "not only A but also B=A뿐만 아니라 B도 | both A and B=A와 B 둘 다")
    add("sb/sth 숙어", ["take sth for granted ~을 당연하게 여기다", "pick sb up ~을 차에 태우러 가다"], "take sth for granted=~을 당연하게 여기다 | pick sb up=~을 차에 태우러 가다")
    add("다섯 낱말 숙어", ["have nothing to do with ~와 관계가 없다", "as soon as possible 가능한 한 빨리"], "have nothing to do with=~와 관계가 없다 | as soon as possible=가능한 한 빨리")
    add("숙어 + 예문", ["give up 포기하다", "Never give up your dream.", "절대 꿈을 포기하지 마.", "put off 미루다"], "give up=포기하다 | put off=미루다")

    // MARK: 파생어·유의어·반의어
    add("파생어 슬래시 (책)", ["happy 형 행복한 / happiness 명 행복", "kind 형 친절한 / kindness 명 친절"], "happy=형 행복한 | happiness=명 행복 | kind=형 친절한 | kindness=명 친절")
    add("파생어 슬래시 (목록)", ["happy 행복한 / happiness 행복", "kind 친절한 / kindness 친절"], "happy=행복한 | happiness=행복 | kind=친절한 | kindness=친절")
    add("파생어 '파' 표시", ["create 동 창조하다", "파 creation 명 창조", "파 creative 형 창의적인"], "create=동 창조하다 | creation=명 창조 | creative=형 창의적인")
    add("유의어·반의어 기호 줄", ["happy 행복한", "= glad", "↔ sad", "brave 용감한"], "happy=행복한 | brave=용감한")
    add("유의어·반의어 한글 표시 줄", ["happy 행복한", "유 glad", "반 sad", "brave 용감한"], "happy=행복한 | brave=용감한")
    add("유의어 같은 줄 (목록)", ["happy 행복한 (= glad)", "brave 용감한 ↔ cowardly"], "happy=행복한 | brave=용감한")
    add("유의어 같은 줄 (책)", ["happy 형 행복한 = glad ↔ sad", "brave 형 용감한 유 courageous"], "happy=형 행복한 | brave=형 용감한")
    add("유의어 줄 (책, 발음)", ["happy [hǽpi] 형 행복한", "= glad, pleased", "↔ sad", "brave [breiv] 형 용감한", "반 cowardly"], "happy=형 행복한 | brave=형 용감한")
    add("cf. 참고 표시", ["affect [əfékt] 동 영향을 미치다 cf. effect 명 영향", "effort [éfərt] 명 노력"], "affect=동 영향을 미치다 | effort=명 노력")
    add("cf. 참고 (목록)", ["affect 영향을 미치다 cf. effect", "effort 노력"], "affect=영향을 미치다 | effort=노력")

    // MARK: 예문·해석
    add("예문 + 해석 줄", ["brave 용감한", "She was very brave.", "그녀는 매우 용감했다.", "calm 차분한"], "brave=용감한 | calm=차분한")
    add("ex) 예문", ["polite 예의 바른", "ex) He is always polite.", "그는 항상 예의 바르다.", "rude 무례한"], "polite=예의 바른 | rude=무례한")
    add("예) 예문", ["polite 예의 바른", "예) Be polite to others.", "다른 사람에게 예의 바르게 대해라.", "rude 무례한"], "polite=예의 바른 | rude=무례한")
    add("질문 예문", ["curious 호기심 많은", "Are you curious about it?", "너는 그것이 궁금하니?", "eager 열망하는"], "curious=호기심 많은 | eager=열망하는")
    add("뜻 뒤 같은 줄 예문", ["patient 참을성 있는 Be patient with your brother.", "honest 정직한"], "patient=참을성 있는 | honest=정직한")
    add("예문 + 해석 한 줄", ["kind 친절한", "She is kind to everyone. 그녀는 모두에게 친절하다.", "smart 똑똑한"], "kind=친절한 | smart=똑똑한")
    add("긴 예문 + 해석 한 줄", ["quit 그만두다", "I quit smoking last year. 나는 작년에 담배를 끊었다.", "smoke 담배를 피우다"], "quit=그만두다 | smoke=담배를 피우다")
    add("빈칸 예문", ["arrive 도착하다", "We ______ at the station at 7.", "우리는 7시에 역에 도착했다.", "depart 출발하다"], "arrive=도착하다 | depart=출발하다")
    add("따옴표 예문", ["recommend 추천하다", "“I recommend this book,” she said.", "\"이 책을 추천해,\" 그녀가 말했다.", "suggest 제안하다"], "recommend=추천하다 | suggest=제안하다")
    add("괄호 친 해석", ["borrow 빌리다", "Can I borrow your pen?", "(펜 좀 빌려도 될까?)", "lend 빌려주다"], "borrow=빌리다 | lend=빌려주다")

    // MARK: 뜻이 다음 줄 (세로형)
    add("세로형 기본", ["apple", "사과", "banana", "바나나"], "apple=사과 | banana=바나나")
    add("세로형 번호", ["1. resilient", "회복력 있는", "2. abundant", "풍부한"], "resilient=회복력 있는 | abundant=풍부한")
    add("세로형 뜻 여러 줄", ["run", "1. 달리다", "2. 운영하다", "walk", "걷다"], "run=달리다, 운영하다 | walk=걷다")
    add("세로형 + 예문", ["brave", "용감한", "She was brave.", "그녀는 용감했다.", "calm", "차분한"], "brave=용감한 | calm=차분한")
    add("가운데 단어 뜻 없음", ["apple 사과", "banana", "cherry 체리"], "apple=사과 | banana= | cherry=체리")
    add("마지막 단어 뜻 없음", ["apple 사과", "banana 바나나", "cherry"], "apple=사과 | banana=바나나 | cherry=")
    add("한글 먼저 목록", ["사과 - apple", "바나나 - banana", "체리 - cherry"], "apple=사과 | banana=바나나 | cherry=체리")
    add("한 줄에 두 쌍", ["apple 사과 banana 바나나", "cherry 체리 grape 포도"], "apple=사과 | banana=바나나 | cherry=체리 | grape=포도")

    // MARK: 같은 단어 합치기
    add("같은 단어 다른 줄 뜻 합침", ["apple 사과", "banana 바나나", "apple 능금"], "apple=사과, 능금 | banana=바나나")
    add("완전히 같은 줄 두 번", ["apple 사과", "apple 사과", "banana 바나나"], "apple=사과 | banana=바나나")
    add("대소문자만 다른 중복", ["Apple 사과", "apple 능금"], "Apple=사과, 능금")

    // MARK: 시중 단어장 (책)
    add("책: 예시 구 + 해석", ["apple [ǽpl] 명 사과", "an apple a day 하루에 사과 한 개", "I ate an apple. 나는 사과를 먹었다.", "banana [bənǽnə] 명 바나나"],
        "apple=명 사과 | banana=명 바나나")
    add("책: 영어 품사 + 예문", ["abandon [əbǽndən] v. 버리다", "She abandoned her car. 그녀는 차를 버렸다.", "ability [əbíləti] n. 능력", "the ability to swim 수영하는 능력"],
        "abandon=v. 버리다 | ability=n. 능력")
    add("책: 품사·뜻이 다음 줄", ["abandon [əbǽndən]", "동 버리다, 포기하다", "abundant [əbʌ́ndənt]", "형 풍부한"], "abandon=동 버리다, 포기하다 | abundant=형 풍부한")
    add("책: 뜻이 다음 줄로 이어짐", ["abandon [əbǽndən] 동 버리다,", "포기하다", "abundant [əbʌ́ndənt] 형 풍부한"], "abandon=동 버리다, 포기하다 | abundant=형 풍부한")
    add("책: 영어 품사 뜻 이어짐", ["accommodate [əkɑ́mədèit] v. 수용하다,", "숙박시키다", "accompany [əkʌ́mpəni] v. 동반하다"], "accommodate=v. 수용하다, 숙박시키다 | accompany=v. 동반하다")
    add("책: 표제어가 오른쪽", ["[ǽpl] 명 사과 apple", "[bənǽnə] 명 바나나 banana"], "apple=명 사과 | banana=명 바나나")
    add("책: 머리말·번호·쪽수", ["DAY 01", "001 abandon [əbǽndən] 동 버리다", "002 abundant [əbʌ́ndənt] 형 풍부한", "003 accept [æksépt] 동 받아들이다", "12"],
        "abandon=동 버리다 | abundant=형 풍부한 | accept=동 받아들이다")
    add("책: 표제어 + 체크박스 숙어", ["001 abandon [əbǽndən] 동 버리다, 포기하다", "abandon a plan 계획을 포기하다", "002 abundant [əbʌ́ndənt] 형 풍부한",
                                "abundant resources 풍부한 자원", "□ give up 포기하다", "□ be good at ~을 잘하다"],
        "abandon=동 버리다, 포기하다 | abundant=형 풍부한 | give up=포기하다 | be good at=~을 잘하다")
    add("책: 표제어·발음 다른 상자", lines: wcTable([["abandon", "[əbǽndən]"], ["동 버리다"], ["ability", "[əbíləti]"], ["명 능력"]], xs: [0.1, 0.4]),
        "abandon=동 버리다 | ability=명 능력")

    // MARK: 표 (같은 줄에 상자 여러 개)
    add("표: 단어 | 뜻 (영어 머리줄)", lines: wcTable([["Word", "Meaning"], ["apple", "사과"], ["banana", "바나나"], ["cherry", "체리"]], xs: [0.1, 0.5]),
        "apple=사과 | banana=바나나 | cherry=체리")
    add("표: 단어 | 뜻 (한글 머리줄)", lines: wcTable([["영어", "뜻"], ["apple", "사과"], ["banana", "바나나"], ["cherry", "체리"]], xs: [0.1, 0.5]),
        "apple=사과 | banana=바나나 | cherry=체리")
    add("표: 번호 | 단어 | 뜻", lines: wcTable([["1", "apple", "사과"], ["2", "banana", "바나나"], ["3", "cherry", "체리"], ["4", "grape", "포도"]], xs: [0.05, 0.15, 0.55]),
        "apple=사과 | banana=바나나 | cherry=체리 | grape=포도")
    add("표: 단어 | 품사 | 뜻", lines: wcTable([["apple", "n.", "사과"], ["run", "v.", "달리다"], ["happy", "adj.", "행복한"]], xs: [0.1, 0.4, 0.55]),
        "apple=n. 사과 | run=v. 달리다 | happy=adj. 행복한")
    add("표: 단어 | 뜻 | 예문", lines: wcTable([["apple", "사과", "I eat an apple every day."], ["run", "달리다", "He runs fast."]], xs: [0.05, 0.3, 0.55]),
        "apple=사과 | run=달리다")
    add("표: 뜻 칸이 두 상자로 나뉨", lines: wcTable([["apple", "사과,", "능금"], ["bank", "은행,", "둑"]], xs: [0.1, 0.5, 0.65]),
        "apple=사과, 능금 | bank=은행, 둑")
    add("표: 높이 흔들림", lines: wcTable([["apple", "사과"], ["banana", "바나나"], ["cherry", "체리"], ["grape", "포도"]], xs: [0.1, 0.55], jitter: 0.008),
        "apple=사과 | banana=바나나 | cherry=체리 | grape=포도")
    add("표: 한글 | 영어 (뜻 먼저)", lines: wcTable([["사과", "apple"], ["바나나", "banana"], ["체리", "cherry"]], xs: [0.1, 0.5]),
        "apple=사과 | banana=바나나 | cherry=체리")
    let shuffled: [OCRLine] = {
        let table = wcTable([["apple", "사과"], ["banana", "바나나"], ["cherry", "체리"], ["grape", "포도"]], xs: [0.1, 0.5])
        return [5, 0, 7, 2, 4, 1, 6, 3].map { table[$0] }
    }()
    add("표: Vision 순서가 뒤섞임", lines: shuffled, "apple=사과 | banana=바나나 | cherry=체리 | grape=포도")

    // MARK: 두 단 페이지
    add("두 단: 번호 없음, 개수 다름", lines: wcColumns(["apple 사과", "banana 바나나", "cherry 체리", "grape 포도", "melon 멜론"],
                                                   ["lemon 레몬", "peach 복숭아", "pear 배", "plum 자두"]),
        "apple=사과 | banana=바나나 | cherry=체리 | grape=포도 | melon=멜론 | lemon=레몬 | peach=복숭아 | pear=배 | plum=자두")
    var headed = wcColumns(["1. brave 용감한", "2. calm 차분한", "3. eager 열망하는", "4. honest 정직한", "5. polite 예의 바른"],
                           ["6. rude 무례한", "7. shy 수줍은", "8. smart 똑똑한", "9. kind 친절한", "10. wise 현명한"])
    headed.append(OCRLine(text: "DAY 03", box: CGRect(x: 0.42, y: 0.95, width: 0.16, height: 0.03)))
    add("두 단: 가운데 머리말", lines: headed,
        "brave=용감한 | calm=차분한 | eager=열망하는 | honest=정직한 | polite=예의 바른 | rude=무례한 | shy=수줍은 | smart=똑똑한 | kind=친절한 | wise=현명한")
    add("두 단: 단마다 단어 | 뜻 상자", lines: wcTable([["apple", "사과", "lemon", "레몬"], ["banana", "바나나", "peach", "복숭아"],
                                                   ["cherry", "체리", "pear", "배"], ["grape", "포도", "plum", "자두"]], xs: [0.05, 0.25, 0.55, 0.75]),
        "apple=사과 | banana=바나나 | cherry=체리 | grape=포도 | lemon=레몬 | peach=복숭아 | pear=배 | plum=자두")
    add("두 단: 단마다 세로형", lines: wcColumns(["apple", "사과", "banana", "바나나"], ["cherry", "체리", "grape", "포도"], spacing: 0.05),
        "apple=사과 | banana=바나나 | cherry=체리 | grape=포도")

    for (n, c) in cases.enumerated() {
        let got = wcFormat(WordParser.parse(c.lines))
        check("단어 사진 \(n + 1). \(c.name)", got == c.expect, "결과 \(got)\n    기대 \(c.expect)")
    }

    // MARK: 확인 필요 (흐리게 읽힘·철자 교정)
    func unsure(_ words: [ParsedWord]) -> String { words.map { "\($0.term)=\($0.unsure)" }.joined(separator: " | ") }
    let blurry = WordParser.parse(wcLines(["apple 사과", "banana 바나나", "cherry 체리"], confidence: [1: 0.3, 2: 0.9]))
    check("단어 사진: 흐린 줄만 확인 필요", unsure(blurry) == "apple=false | banana=true | cherry=false", unsure(blurry))
    let partial = WordParser.parse(wcLines(["run 달리다", "brunch 브런치"], confidence: [1: 0.3]))
    check("단어 사진: 다른 단어 속 글자로 확인 필요 오판 없음", unsure(partial) == "run=false | brunch=true", unsure(partial))
    let blurryCell = WordParser.parse(wcTable([["apple", "사과"], ["banana", "바나나"], ["cherry", "체리"]], xs: [0.1, 0.5], confidence: ["banana": 0.2]))
    check("단어 사진: 표에서 단어 칸만 흐림", unsure(blurryCell) == "apple=false | banana=true | cherry=false", unsure(blurryCell))
    let corrected = WordParser.parse(wcLines(["app1e 사과", "banana 바나나"]))
    check("단어 사진: 숫자를 고친 단어는 확인 필요", unsure(corrected) == "apple=true | banana=false", unsure(corrected))
    let vertical = WordParser.parse(wcLines(["resilient", "회복력 있는", "abundant", "풍부한"], confidence: [0: 0.4]))
    check("단어 사진: 세로형 단어 줄 흐림", unsure(vertical) == "resilient=true | abundant=false", unsure(vertical))
}
