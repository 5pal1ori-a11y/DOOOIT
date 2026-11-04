import Foundation

// MARK: - 과목 풀이 더하기: 사실표 · 분류 · 설명 문장 판단 · 현상 분류 · 시대 · 인물 · 시차
// - 빠짐없이 아는 것만 표에 넣어요. 선지 하나라도 모르면 답하지 않아요

extension DoitSubjectSolve {
    // MARK: 분류 더하기

    static let moreCategories: [Category] = {
        var list: [Category] = []
        func group(_ subject: String, _ items: [([String], [String])], extra: [String] = []) -> [Category] {
            let universe = Set((items.flatMap(\.1) + extra).map(key))
            return items.map { Category(names: $0.0, members: Set($0.1.map(key)), universe: universe, subject: subject) }
        }
        // 정온 · 변온 동물
        let warm = ["고래", "박쥐", "개", "고양이", "사람", "소", "말", "돌고래", "원숭이", "호랑이", "사자", "토끼", "쥐", "코끼리", "곰", "돼지", "다람쥐",
                    "닭", "참새", "독수리", "펭귄", "타조", "비둘기", "오리", "까치", "앵무새", "부엉이", "제비"]
        let cold = ["뱀", "거북", "도마뱀", "악어", "카멜레온", "개구리", "도롱뇽", "두꺼비", "붕어", "고등어", "상어", "잉어", "연어", "금붕어", "참치",
                    "메뚜기", "나비", "개미", "지렁이", "달팽이"]
        list += group("과학", [(["정온 동물", "항온 동물"], warm), (["변온 동물"], cold)])
        // 외떡잎 · 쌍떡잎 식물
        let monocot = ["벼", "보리", "밀", "옥수수", "백합", "강아지풀", "대나무", "파", "양파", "난초", "붓꽃", "튤립", "마늘", "잔디"]
        let dicot = ["콩", "강낭콩", "완두", "해바라기", "봉숭아", "무궁화", "장미", "민들레", "배추", "무", "고추", "토마토", "국화", "나팔꽃", "호박", "사과나무", "진달래"]
        list += group("과학", [(["외떡잎식물", "외떡잎 식물"], monocot), (["쌍떡잎식물", "쌍떡잎 식물"], dicot)])
        // 생태계 구성 요소 (1차·2차 소비자는 먹이 관계에 따라 달라서 모름)
        let producers = ["벼", "소나무", "풀", "식물 플랑크톤", "해캄", "옥수수", "보리", "참나무", "벼과 식물"]
        let consumers = ["토끼", "매", "뱀", "개구리", "사슴", "사자", "메뚜기", "여우", "늑대", "독수리", "호랑이", "동물 플랑크톤", "참새", "다람쥐", "쥐", "소"]
        let decomposers = ["곰팡이", "세균", "버섯", "푸른곰팡이"]
        list += group("과학", [(["생산자"], producers), (["소비자"], consumers), (["분해자"], decomposers)])
        for name in ["1차 소비자", "2차 소비자", "3차 소비자", "최종 소비자"] { list.append(Category(names: [name], members: [], universe: [], subject: "과학")) }
        // 도체 · 부도체
        let conductors = ["구리", "철", "알루미늄", "은", "금", "흑연", "니켈", "납", "아연", "스테인리스"]
        let insulators = ["유리", "고무", "나무", "플라스틱", "종이", "비닐", "도자기", "스타이로폼", "천", "나무젓가락"]
        list += group("과학", [(["도체", "전기가 잘 통하는", "전류가 잘 흐르는", "전기 전도성이 있는"], conductors), (["부도체", "절연체"], insulators)])
        // 광합성의 재료
        list.append(Category(names: ["광합성에 필요한", "광합성의 재료", "광합성에 쓰이는"], members: Set(["이산화 탄소", "물", "빛", "빛에너지", "빛 에너지"].map(key)),
                             universe: Set(["이산화 탄소", "물", "빛", "빛에너지", "빛 에너지", "산소", "포도당", "녹말", "질소"].map(key)), subject: "과학"))
        // 국가 기관의 권한
        let assembly = ["법률 제정", "법률 제정권", "입법", "입법권", "예산안 심의·확정", "예산안 심의", "예산안 의결", "예산안 확정", "예산안 심의·의결",
                        "국정 감사", "국정 조사", "국정 감사권", "국정 조사권", "국정 감사·조사", "탄핵 소추", "탄핵 소추권", "탄핵 소추 의결",
                        "국무총리 임명 동의", "대법원장 임명 동의", "조약 체결·비준 동의", "조약 비준 동의", "헌법 개정안 의결"]
        let president = ["국군 통수", "국군 통수권", "법률안 거부권", "조약 체결·비준", "조약 체결", "사면권", "사면", "공무원 임면권", "긴급 명령권",
                         "국무총리 임명", "대법원장 임명", "계엄 선포", "계엄 선포권"]
        let court = ["재판", "재판권", "위헌 법률 심판 제청", "위헌 법률 심판 제청권", "명령·규칙 심사", "명령·규칙·처분 심사", "명령·규칙 심사권", "사법권"]
        let constitutional = ["위헌 법률 심판", "탄핵 심판", "정당 해산 심판", "권한 쟁의 심판", "헌법 소원 심판"]
        list += group("사회", [(["국회의 권한", "국회가 가진 권한"], assembly), (["대통령의 권한", "대통령이 가진 권한"], president),
                              (["법원의 권한", "법원이 가진 권한"], court), (["헌법 재판소의 권한", "헌법재판소의 권한"], constitutional)])
        // 대체재 · 보완재 (짝은 양쪽 순서 모두)
        func pairs(_ list: [(String, String)]) -> [String] { list.flatMap { ["\($0.0) - \($0.1)", "\($0.1) - \($0.0)"] } }
        let substitutes = pairs([("쌀", "밀가루"), ("버터", "마가린"), ("콜라", "사이다"), ("연필", "샤프"), ("커피", "녹차"), ("쌀", "보리"),
                                 ("소고기", "돼지고기"), ("버스", "지하철"), ("쌀", "빵"), ("기차", "고속버스")])
        let complements = pairs([("커피", "설탕"), ("펜", "잉크"), ("자동차", "휘발유"), ("컴퓨터", "마우스"), ("바늘", "실"), ("빵", "버터"),
                                 ("연필", "지우개"), ("프린터", "잉크"), ("테니스 라켓", "테니스공"), ("카메라", "필름")])
        list += group("사회", [(["대체재"], substitutes), (["보완재"], complements)])
        // 생산 요소
        list.append(Category(names: ["생산 요소", "생산의 3요소", "생산의 요소"], members: Set(["토지", "노동", "자본", "기업가 정신", "경영"].map(key)),
                             universe: Set(["토지", "노동", "자본", "기업가 정신", "경영", "소비", "분배", "화폐", "저축", "세금"].map(key)), subject: "사회"))
        // 남반구 · 북반구 나라 (적도가 지나는 나라는 넣지 않음)
        let south = ["오스트레일리아", "호주", "뉴질랜드", "아르헨티나", "칠레", "남아프리카 공화국", "남아공", "마다가스카르", "우루과이", "파라과이", "페루", "볼리비아"]
        let north = ["캐나다", "일본", "영국", "이집트", "미국", "중국", "대한민국", "한국", "독일", "프랑스", "러시아", "인도", "멕시코", "이탈리아", "스페인",
                     "몽골", "베트남", "태국", "사우디아라비아", "이란", "튀르키예", "터키", "노르웨이", "스웨덴", "필리핀", "북한", "그리스", "폴란드"]
        list += group("사회", [(["남반구"], south), (["북반구"], north)])
        // 품사 (뜻에 따라 품사가 바뀌는 말은 넣지 않음: 이·그·저, 크다·밝다·늦다, 정말·참 …)
        let followers = ["인", "에", "가", "이", "는", "로", "을", "를", "의", "만", "?"]
        let wordClasses: [(String, [String])] = [
            ("대명사", ["나", "너", "저희", "우리", "그녀", "이것", "그것", "저것", "여기", "거기", "저기", "누구", "무엇", "어디", "자네", "당신"]),
            ("수사", ["하나", "둘", "셋", "넷", "다섯", "여섯", "일곱", "여덟", "아홉"]),
            ("관형사", ["새", "헌", "옛", "온갖", "갖은", "모든", "여러", "무슨", "어느", "웬", "딴"]),
            ("부사", ["매우", "아주", "빨리", "너무", "몹시", "가장", "무척", "꽤", "결코", "과연", "설마", "아마", "반드시", "부디", "제발", "천천히",
                     "열심히", "자주", "항상", "늘", "이미", "벌써", "방금", "곧", "아직", "다시", "겨우", "그리고", "그러나", "그런데"]),
            ("감탄사", ["아이고", "어머", "어머나", "아이코", "여보세요", "어이쿠", "아차", "쉿"]),
            ("동사", ["먹다", "가다", "오다", "뛰다", "읽다", "자다", "웃다", "울다", "달리다", "놀다", "만들다", "배우다", "걷다", "공부하다"]),
            ("형용사", ["예쁘다", "아름답다", "착하다", "슬프다", "기쁘다", "춥다", "덥다", "작다", "높다", "낮다", "넓다", "좁다", "많다", "빠르다",
                      "느리다", "무겁다", "가볍다", "좋다", "싫다", "행복하다", "조용하다", "깨끗하다"])
        ]
        let wordUniverse = Set(wordClasses.flatMap(\.1).map(key))
        for (name, words) in wordClasses {
            list.append(Category(names: [name], members: Set(words.map(key)), universe: wordUniverse, subject: "국어", followers: followers))
        }
        return list
    }()

    /// 품사 표 (품사가 다른 하나 고르기용)
    static let wordClassOf: [String: String] = {
        var map: [String: String] = [:]
        for cat in moreCategories where cat.subject == "국어" { for m in cat.members { map[m] = cat.names[0] } }
        return map
    }()

    /// "다음 중 품사가 나머지와 다른 하나는?"
    static func oddWordClass(_ p: Problem) -> Found? {
        let c = p.compact
        guard p.isChoice, c.contains("품사"), matches(c, #"(다른하나|다른것)"#) else { return nil }
        let classes = p.choices.map { wordClassOf[key($0)] }
        guard classes.allSatisfy({ $0 != nil }) else { return nil }
        let counts = Dictionary(grouping: classes.compactMap { $0 }, by: { $0 }).mapValues(\.count)
        guard counts.count == 2, let odd = counts.first(where: { $0.value == 1 })?.key, counts.values.contains(p.choices.count - 1) else { return nil }
        guard let index = classes.firstIndex(of: odd) else { return nil }
        let steps = p.choices.indices.map { SolutionStep(hint: "", work: "\(circled($0 + 1)) \(p.choices[$0]): \(classes[$0]!)") }
        return pick(p, index: index, concept: "품사", steps: steps)
    }

    // MARK: 사실표 더하기

    static let moreFacts: [Fact] = [
        // 과학
        Fact(answers: ["굴절"], patterns: [#"빛이?.{0,20}경계에서.{0,6}꺾"#], why: "빛이 다른 물질로 들어갈 때 경계에서 꺾이는 현상은 굴절이에요."),
        Fact(answers: ["반사"], patterns: [#"빛이?.{0,10}부딪(혀|쳐|힌).{0,6}(되돌아|튕겨)"#], why: "빛이 물체에 부딪혀 되돌아 나오는 현상은 반사예요."),
        Fact(answers: ["혈장"], patterns: [#"혈액.{0,20}(영양소|노폐물).{0,25}운반하는.{0,4}액체"#], why: "혈장은 혈액의 액체 성분으로 영양소·노폐물·이산화 탄소를 운반해요."),
        Fact(answers: ["콩팥", "신장"], patterns: [#"(노폐물을?걸러|오줌을?만드).{0,15}(기관|배설기관)"#], why: "콩팥(신장)은 혈액 속 노폐물을 걸러 오줌을 만들어요."),
        Fact(answers: ["월식"], patterns: [#"달이?지구의?그림자에?가려"#], why: "달이 지구의 그림자 속으로 들어가 가려지는 현상은 월식이에요."),
        Fact(answers: ["일식"], patterns: [#"달이?태양을?가리|태양이?달에?가려"#], why: "달이 태양을 가리는 현상은 일식이에요."),
        Fact(answers: ["내핵"], patterns: [#"가장안쪽.{0,25}고체"#], why: "지구의 가장 안쪽 내핵은 고체 상태로 추정돼요."),
        Fact(answers: ["해령"], patterns: [#"판(과판)?이?(서로)?멀어지는경계.{0,25}(해저지형|지형)"#], why: "판이 멀어지는 경계에서 마그마가 올라와 해령이 만들어져요."),
        Fact(answers: ["유전자"], patterns: [#"DNA의?특정부분"#], why: "유전자는 형질을 결정하는 유전 정보가 저장된 DNA의 특정 부분이에요."),
        Fact(answers: ["원소"], patterns: [#"더이상다른물질로분해되지않"#], why: "더 이상 다른 물질로 분해되지 않는 기본 성분은 원소예요."),
        Fact(answers: ["동맥"], patterns: [#"심장에서나가는혈액이?흐르는혈관"#], why: "심장에서 나가는 혈액이 흐르는 혈관은 동맥이에요."),
        Fact(answers: ["정맥"], patterns: [#"심장으로들어가는혈액이?흐르는혈관"#], why: "심장으로 들어가는 혈액이 흐르는 혈관은 정맥이에요."),
        Fact(answers: ["기공"], patterns: [#"(잎|잎의뒷면|잎뒷면).{0,15}기체가?드나드는"#], why: "기공은 잎의 표피(주로 뒷면)에 있어 기체가 드나드는 구멍이에요."),
        Fact(answers: ["진동수"], patterns: [#"소리의?높낮이.{0,6}(결정|좌우)"#], why: "소리의 높낮이는 진동수가 결정해요 (진동수가 클수록 높은 소리)."),
        Fact(answers: ["진폭"], patterns: [#"소리의?(세기|크기).{0,10}(결정|좌우)"#], why: "소리의 세기(크기)는 진폭이 결정해요."),
        Fact(answers: ["척력"], patterns: [#"같은극끼리.{0,10}(밀어내|미는)"#], why: "자석의 같은 극끼리는 서로 밀어내는 힘(척력)이 작용해요."),
        Fact(answers: ["인력"], patterns: [#"다른극끼리.{0,10}(끌어당|당기)"#], why: "자석의 다른 극끼리는 서로 끌어당기는 힘(인력)이 작용해요."),
        Fact(answers: ["증산 작용", "증산"], patterns: [#"물이?.{0,10}기공을?통해.{0,10}(수증기|기체)"#], why: "잎의 기공을 통해 물이 수증기로 빠져나가는 현상은 증산 작용이에요."),
        Fact(answers: ["중화 반응", "중화"], patterns: [#"산과염기가?반응하여.{0,6}물이?생성"#], why: "산과 염기가 반응하여 물이 생기는 반응은 중화 반응이에요."),
        // 사회
        Fact(answers: ["국내 총생산", "GDP"], patterns: [#"한나라안에서.{0,25}최종생산물의?시장가치"#], why: "국내 총생산(GDP): 한 나라 안에서 일정 기간 새로 생산된 최종 생산물의 시장 가치 합"),
        Fact(answers: ["서비스", "용역"], patterns: [#"눈에보이지않.{0,20}(만족|효용).{0,20}(활동|행위)"#], why: "서비스는 눈에 보이지 않지만 만족을 주는 사람의 활동이에요."),
        Fact(answers: ["직접 선거"], patterns: [#"대리인을?(거치지|통하지)않고.{0,6}(직접|본인이)"#], why: "대리인 없이 본인이 직접 투표하는 원칙은 직접 선거예요."),
        Fact(answers: ["청구권"], patterns: [#"(다른)?기본권을?보장하기위한수단"#], why: "청구권은 다른 기본권을 보장하기 위한 수단적 권리예요(재판 청구권, 청원권 …)."),
        Fact(answers: ["오아시스"], patterns: [#"사막.{0,25}물을?얻을수있"#], why: "사막에서 물을 얻을 수 있는 곳은 오아시스예요."),
        Fact(answers: ["타이가"], patterns: [#"냉대.{0,20}침엽수림"#], why: "냉대 기후 지역의 넓은 침엽수림은 타이가예요."),
        Fact(answers: ["스콜"], patterns: [#"열대.{0,30}(오후|매일).{0,20}소나기"#], why: "열대 지역에서 오후에 거의 매일 내리는 강한 소나기는 스콜이에요."),
        Fact(answers: ["게리맨더링"], patterns: [#"유리하(게|도록)선거구를?(정|획정|나누)"#], why: "특정 정당·후보에게 유리하게 선거구를 정하는 것은 게리맨더링이에요."),
        Fact(answers: ["열대 우림 기후"], patterns: [#"적도부근.{0,30}(기온이높|덥).{0,20}강수량이?많"#], why: "적도 부근은 일 년 내내 기온이 높고 비가 많은 열대 우림 기후예요."),
        Fact(answers: ["지중해성 기후"], patterns: [#"여름.{0,6}(덥고)?건조.{0,25}겨울.{0,10}(온화|비가많)"#], why: "여름에 덥고 건조, 겨울에 온화하고 비가 많은 기후는 지중해성 기후예요."),
        Fact(answers: ["스텝 기후"], patterns: [#"건조기후.{0,25}(짧은풀|초원)"#], why: "건조 기후 중 짧은 풀이 자라는 초원이 나타나는 기후는 스텝 기후예요."),
        Fact(answers: ["런던"], patterns: [#"(경도0°?|본초자오선).{0,15}(지나는|통과하는)(도시|곳)"#], why: "경도 0°인 본초 자오선은 영국 런던(그리니치 천문대)을 지나요."),
        Fact(answers: ["태평양"], patterns: [#"가장(넓은|큰)대양"#], why: "세계에서 가장 넓은 대양은 태평양이에요."),
        Fact(answers: ["아시아"], patterns: [#"(면적이?)?가장(넓은|큰)대륙"#], why: "면적이 가장 넓은 대륙은 아시아예요."),
        Fact(answers: ["겨울"], patterns: [#"북반구가?여름일때남반구"#], why: "북반구와 남반구는 계절이 반대예요."),
        Fact(answers: ["여름"], patterns: [#"북반구가?겨울일때남반구"#], why: "북반구와 남반구는 계절이 반대예요."),
        Fact(answers: ["낮아진다", "낮아짐", "낮아져요"], patterns: [#"위도가?높아질수록기온은?.{0,10}(어떻게|변)"#], why: "위도가 높을수록 태양 에너지를 적게 받아 기온이 대체로 낮아요."),
        Fact(answers: ["상승한다", "오른다", "상승"], patterns: [#"수요가?증가하면.{0,10}균형가격은"#], why: "수요가 증가하면 수요 곡선이 오른쪽으로 이동해 균형 가격이 올라요."),
        Fact(answers: ["가격 하락, 거래량 증가"], patterns: [#"공급이?증가하면.{0,10}균형가격과.{0,4}균형?거래량"#], why: "공급이 증가하면 균형 가격은 내리고 균형 거래량은 늘어요."),
        Fact(answers: ["가격 상승, 거래량 증가"], patterns: [#"수요가?증가하면.{0,10}균형가격과.{0,4}균형?거래량"#], why: "수요가 증가하면 균형 가격과 균형 거래량이 모두 늘어요."),
        Fact(answers: ["떨어진다", "하락한다", "낮아진다"], patterns: [#"물가가?.{0,10}(오르|상승하)면.{0,10}화폐의?가치"#], why: "물가가 오르면 같은 돈으로 살 수 있는 것이 줄어 화폐 가치가 떨어져요."),
        Fact(answers: ["4년"], patterns: [#"국회의원의?임기"#], why: "우리나라 국회의원의 임기는 4년이에요."),
        Fact(answers: ["5년"], patterns: [#"(?<!국회의원)대통령의?임기"#], why: "우리나라 대통령의 임기는 5년(단임)이에요."),
        // 국어
        Fact(answers: ["화자", "시적 화자", "말하는 이"], patterns: [#"시.{0,20}말하는이를?"#], why: "시 속에서 말하는 이는 화자예요."),
        Fact(answers: ["서술자"], patterns: [#"소설.{0,10}이야기를?전달하는(사람|이)"#], why: "소설에서 이야기를 전달하는 사람은 서술자예요."),
        Fact(answers: ["직유법"], patterns: [#"(처럼|같이|듯이).{0,40}직접빗대"#], why: "'~처럼, ~같이, ~듯이'로 직접 빗대는 것은 직유법이에요."),
        Fact(answers: ["은유법"], patterns: [#"연결어(없이|를쓰지않고).{0,30}빗대"#], why: "연결어 없이 'A는 B이다'처럼 빗대는 것은 은유법이에요."),
        Fact(answers: ["의인법"], patterns: [#"사람이아닌.{0,20}사람처럼"#], why: "사람이 아닌 것을 사람처럼 나타내는 것은 의인법이에요."),
        Fact(answers: ["반어법"], patterns: [#"(표현한|겉으로나타낸)?내용과?속뜻을?반대로"#], why: "겉으로 한 말과 속뜻을 반대로 나타내는 것은 반어법이에요."),
        Fact(answers: ["역설법"], patterns: [#"모순.{0,25}진리"#], why: "겉으로는 모순되지만 속에 진리를 담는 것은 역설법이에요."),
        Fact(answers: ["대구법"], patterns: [#"(같은|비슷한)구조.{0,20}(짝|나란히)"#], why: "비슷한 구조의 문장을 짝 지어 나란히 놓는 것은 대구법이에요."),
        Fact(answers: ["설의법"], patterns: [#"의문의?형식.{0,15}강조"#], why: "누구나 아는 내용을 의문 형식으로 강조하는 것은 설의법이에요."),
        Fact(answers: ["과장법"], patterns: [#"실제보다.{0,10}(크게|작게|부풀)"#], why: "실제보다 크게 또는 작게 나타내는 것은 과장법이에요."),
        Fact(answers: ["절정"], patterns: [#"갈등이?최고조"#], why: "소설에서 갈등이 최고조에 이르는 단계는 절정이에요."),
        Fact(answers: ["1인칭 주인공 시점"], patterns: [#"'?나'?가?주인공이되어.{0,10}자신의?이야기"#], why: "작품 속 '나'가 주인공으로 자기 이야기를 하면 1인칭 주인공 시점이에요.")
    ]

    // MARK: 설명 문장 판단 ("광합성에 대한 설명으로 옳은 것은?")

    /// 개념 하나에 대해 맞는 말 · 틀린 말의 꼴 (띄어쓰기 뺀 선지 글에 맞춰 봄)
    struct Claim {
        let topics: [String]
        let truths: [String]
        let falsehoods: [String]
    }

    static let claims: [Claim] = [
        Claim(topics: ["광합성"],
              truths: [#"엽록체에서"#, #"(산소|O2)(가|를)?(발생|방출|생성|만들|내보내)"#, #"이산화탄소를?(흡수|사용|이용|필요)"#, #"빛(에너지)?(이|가|를)?(필요|이용|사용|흡수)"#,
                       #"(포도당|양분|녹말)(을|를)?(만든|만들|합성|생성)"#, #"물(을|이)?(필요|이용|사용)"#, #"빛이있을때(만)?일어"#],
              falsehoods: [#"뿌리에서"#, #"산소를?(흡수|사용)"#, #"이산화탄소를?(방출|내보내|발생)"#, #"밤에(만)?일어"#, #"미토콘드리아"#, #"포도당을?분해"#,
                           #"에너지를?(방출|얻)"#, #"모든세포에서"#]),
        Claim(topics: ["세포 호흡", "세포호흡"],
              truths: [#"미토콘드리아"#, #"산소(가|를)?(사용|필요|이용|흡수)"#, #"이산화탄소(가|를)?(발생|방출|생성|생긴)"#, #"에너지를?(얻|생성|방출|만든)"#,
                       #"포도당을?분해"#, #"(낮과밤|밤낮|항상|24시간)"#],
              falsehoods: [#"빛이있을때만"#, #"엽록체"#, #"산소를?(발생|방출|만든)"#, #"이산화탄소를?흡수"#, #"낮에만"#, #"밤에만"#, #"포도당을?(만든|합성)"#]),
        Claim(topics: ["지구형 행성", "지구형행성"],
              truths: [#"표면이?.{0,6}(단단|암석)"#, #"밀도가?크"#, #"질량이?작"#, #"반지름이?작"#, #"위성이?(없거나적|적|없)"#, #"고리가?없"#],
              falsehoods: [#"고리가?있"#, #"위성(이|의수가|수가)?많"#, #"질량이?크"#, #"밀도가?작"#, #"반지름이?크"#, #"기체로"#]),
        Claim(topics: ["목성형 행성", "목성형행성"],
              truths: [#"고리가?있"#, #"위성(이|의수가|수가)?많"#, #"질량이?크"#, #"밀도가?작"#, #"반지름이?크"#, #"기체로"#],
              falsehoods: [#"표면이?.{0,6}(단단|암석)"#, #"밀도가?크"#, #"질량이?작"#, #"반지름이?작"#, #"위성이?(없거나적|적|없)"#, #"고리가?없"#]),
        Claim(topics: ["화산암"],
              truths: [#"지표.{0,8}(빠르게|빨리)"#, #"결정(의크기)?(가|이)?작"#, #"(현무암|안산암|유문암)(이|가)?대표"#],
              falsehoods: [#"지하깊은"#, #"천천히"#, #"결정(의크기)?(가|이)?크"#, #"화강암"#, #"퇴적물"#]),
        Claim(topics: ["심성암"],
              truths: [#"지하깊은"#, #"천천히"#, #"결정(의크기)?(가|이)?크"#, #"(화강암|반려암|섬록암)(이|가)?대표"#],
              falsehoods: [#"지표.{0,8}(빠르게|빨리)"#, #"결정(의크기)?(가|이)?작"#, #"현무암"#, #"퇴적물"#]),
        Claim(topics: ["적혈구"],
              truths: [#"헤모글로빈"#, #"산소를?운반"#, #"핵이?없"#, #"수가?가장많"#, #"가운데가?오목"#],
              falsehoods: [#"핵이?있"#, #"식균"#, #"응고"#, #"크기가?가장크"#, #"세균"#]),
        Claim(topics: ["백혈구"],
              truths: [#"식균"#, #"세균을?(잡아|제거|물리)"#, #"핵이?있"#, #"크기가?가장크"#],
              falsehoods: [#"산소를?운반"#, #"헤모글로빈"#, #"응고"#, #"핵이?없"#, #"수가?가장많"#]),
        Claim(topics: ["혈소판"],
              truths: [#"응고"#, #"출혈을?멈"#, #"크기가?가장작"#],
              falsehoods: [#"산소를?운반"#, #"식균"#, #"헤모글로빈"#, #"핵이?있"#, #"수가?가장많"#]),
        Claim(topics: ["산성 용액", "산성용액", "산의 공통", "산성"],
              truths: [#"푸른색?리트머스.{0,8}붉"#, #"(금속|마그네슘|아연|철).{0,10}반응.{0,12}수소"#, #"수소기체를?발생"#, #"신맛"#,
                       #"페놀프탈레인.{0,10}(변화가?없|변하지않|무색)"#, #"BTB.{0,8}노란"#],
              falsehoods: [#"붉은색?리트머스.{0,8}푸르"#, #"페놀프탈레인.{0,10}붉"#, #"단백질을?녹"#, #"쓴맛"#, #"미끈"#, #"BTB.{0,8}파란"#]),
        Claim(topics: ["염기성 용액", "염기성용액", "염기의 공통", "염기성"],
              truths: [#"붉은색?리트머스.{0,8}푸르"#, #"페놀프탈레인.{0,10}붉"#, #"단백질을?녹"#, #"쓴맛"#, #"미끈"#, #"BTB.{0,8}파란"#],
              falsehoods: [#"푸른색?리트머스.{0,8}붉"#, #"(금속|마그네슘|아연|철).{0,10}반응.{0,12}수소"#, #"수소기체를?발생"#, #"신맛"#, #"BTB.{0,8}노란"#]),
        Claim(topics: ["대류권"],
              truths: [#"기상현상이?(나타나|나타난|일어나|일어난|있)(?!지않)"#, #"올라갈수록기온이?(낮|내려|떨어|감소)"#, #"대류가?(일어나|활발|있)(?!지않)"#, #"수증기가?(대부분|가장많)"#],
              falsehoods: [#"오존층"#, #"오로라"#, #"올라갈수록기온이?(높|올라|증가)"#, #"기상현상이?(나타나지않|없|일어나지않)"#, #"공기가?거의없"#]),
        Claim(topics: ["성층권"],
              truths: [#"오존층"#, #"올라갈수록기온이?(높|올라|증가)"#, #"대기가?안정"#, #"대류가?(일어나지않|없)"#],
              falsehoods: [#"기상현상이?(나타나|나타난|일어나|일어난)(?!지않)"#, #"대류가?(활발|일어난다)"#, #"오로라"#, #"올라갈수록기온이?(낮|내려|감소)"#, #"수증기가?가장많"#])
    ]

    /// 설명 문장 하나 → 맞음(true) · 틀림(false) · 모름(nil)
    static func judgeClaim(_ claim: Claim, _ sentence: String) -> Bool? {
        let s = sentence.filter { !$0.isWhitespace }
        let t = claim.truths.contains { matches(s, $0) }, f = claim.falsehoods.contains { matches(s, $0) }
        guard t != f else { return nil }
        return t
    }

    /// 문제가 묻는 개념 (하나만)
    static func askedClaim(_ stem: String) -> Claim? {
        let c = stem.filter { !$0.isWhitespace }
        let hits = (claims + claims3).filter { claim in
            claim.topics.contains { topic in
                let k = topic.filter { !$0.isWhitespace }
                return matches(c, NSRegularExpression.escapedPattern(for: k) + #"(에대한|에관한|의특징|의성질|의공통|의공통적인|용액의|을설명|에서일어나는)"#)
            }
        }
        // 더 긴 이름이 같은 개념을 가리키면 하나로
        guard let first = hits.first, hits.allSatisfy({ $0.topics == first.topics }) || hits.count == 1 else {
            // "산성"과 "산성 용액"처럼 같은 개념이 둘로 걸린 경우는 위에서 같은 Claim이라 하나
            return nil
        }
        return first
    }

    /// 설명으로 옳은 것 · 옳지 않은 것 고르기
    static func statements(_ p: Problem) -> Found? {
        guard p.isChoice, p.box.isEmpty, let claim = askedClaim(p.stem) else { return nil }
        var verdicts: [Bool] = []
        for choice in p.choices {
            guard let v = judgeClaim(claim, choice) else { return nil }
            verdicts.append(v)
        }
        let wanted = !p.negated
        let hits = verdicts.indices.filter { verdicts[$0] == wanted }
        guard hits.count == 1 else { return nil }
        let steps = p.choices.indices.map { SolutionStep(hint: "", work: "\(circled($0 + 1)) \(p.choices[$0]) → \(verdicts[$0] ? "맞아요" : "틀려요")") }
        return pick(p, index: hits[0], concept: "\(claim.topics[0])의 특징", steps: steps)
    }

    // MARK: 현상 분류 (상태 변화 · 물리 변화와 화학 변화)

    /// 생활 속 현상 → 상태 변화
    static let phenomenonPatterns: [(kind: String, patterns: [String])] = [
        ("융해", [#"(얼음|아이스크림|버터|초콜릿|눈|고드름|양초)(이|가)?.{0,4}녹(는|았|아|기|음|다)"#]),
        ("응고", [#"(물|촛농|용암|쇳물|초콜릿|녹인버터)(이|가)?.{0,6}(언다|얼었|얼어|얼음이된|굳는|굳었|굳어|굳다)"#, #"고드름이?(생|만들어)"#]),
        ("기화", [#"(젖은빨래|빨래|물웅덩이|머리카락|어항의물|웅덩이의물|젖은머리)(가|이|의물이)?.{0,4}(마른|마르|말라|줄어)"#, #"(아세톤|알코올|물|에탄올)(이|가)?.{0,4}(증발|끓는|끓었|끓어|끓다)"#]),
        ("액화", [#"(이슬이?맺|김이?서리|물방울이?맺|안경에김|안경이?뿌옇)"#]),
        ("승화(고체→기체)", [#"(드라이아이스|나프탈렌|좀약).{0,6}(작아|사라|없어|줄어)"#]),
        ("승화(기체→고체)", [#"(서리가?내리|서리가?생기|성에가?생기|성에가?낀)"#])
    ]

    static let changePatterns: [(kind: String, patterns: [String])] = [
        ("화학 변화", [#"(종이|나무|양초|초|숯|가스|장작)(가|이)?.{0,4}(탄다|타는|탔|연소)"#, #"철(이|가)?.{0,4}(녹슨|녹이슨|녹슬)"#, #"(깎은사과|사과의깎은면|사과를깎아).{0,10}갈색"#,
                     #"(우유|음식)(가|이)?.{0,4}(상한|상했|썩)"#, #"김치가?.{0,4}시어"#, #"(단풍이?든|과일이?익)"#, #"(빵|반죽)(이|가)?.{0,4}부풀"#, #"폭죽이?터"#]),
        ("물리 변화", [#"(얼음|아이스크림|버터|초콜릿)(이|가)?.{0,4}녹(는|았|아|다)"#, #"물(이|가)?.{0,4}(증발|끓|언다|얼)"#, #"설탕이?.{0,6}물에.{0,4}녹"#, #"(유리컵|유리|접시)(이|가)?.{0,4}깨"#,
                     #"각설탕이?.{0,4}부서"#, #"고무줄이?.{0,4}늘어"#, #"잉크가?.{0,6}(퍼진|퍼져|퍼지)"#, #"(종이를?자르|종이를?접|철사를?구부)"#, #"젖은빨래가?.{0,4}마"#])
    ]

    private static func classify(_ text: String, _ table: [(kind: String, patterns: [String])]) -> String? {
        let s = text.filter { !$0.isWhitespace }
        let kinds = table.filter { $0.patterns.contains { matches(s, $0) } }.map(\.kind)
        return kinds.count == 1 ? kinds[0] : nil
    }

    /// "다음 중 기화에 해당하는 현상은?", "열을 방출하는 상태 변화의 예는?", "화학 변화인 것은?"
    static func phenomena(_ p: Problem) -> Found? {
        guard p.isChoice, p.box.isEmpty, p.choices.allSatisfy({ $0.filter { DoitSubjectNote.isHangul($0) }.count >= 4 }) else { return nil }
        let c = p.compact
        var test: ((String) -> Bool?)?
        var concept = ""
        if matches(c, #"화학(적)?변화"#) != matches(c, #"물리(적)?변화"#) {
            let chemical = matches(c, #"화학(적)?변화"#)
            test = { text in classify(text, changePatterns).map { ($0 == "화학 변화") == chemical } }
            concept = "물리 변화와 화학 변화"
        } else if let asked = c.firstMatch(of: #/(융해|응고|기화|증발|액화|승화)(와|과)?(에|같은|와같은|과같은|가|이)/#) {
            let kind = asked.1 == "증발" ? "기화" : String(asked.1)
            guard kind != "승화" else { return nil }
            test = { text in classify(text, phenomenonPatterns).map { $0 == kind } }
            concept = "상태 변화"
        } else if matches(c, #"열(에너지)?을?(흡수|방출)하는.{0,4}상태변화"#) {
            let absorb = matches(c, #"열(에너지)?을?흡수"#)
            let absorbing: Set<String> = ["융해", "기화", "승화(고체→기체)"]
            test = { text in classify(text, phenomenonPatterns).map { absorbing.contains($0) == absorb } }
            concept = "상태 변화와 열에너지"
        }
        guard let test else { return nil }
        var verdicts: [Bool] = []
        for choice in p.choices {
            guard let v = test(choice) else { return nil }
            verdicts.append(v)
        }
        let hits = verdicts.indices.filter { verdicts[$0] != p.negated }
        guard hits.count == 1 else { return nil }
        let steps = p.choices.indices.map { i -> SolutionStep in
            let kind = classify(p.choices[i], concept == "물리 변화와 화학 변화" ? changePatterns : phenomenonPatterns) ?? ""
            return SolutionStep(hint: "", work: "\(circled(i + 1)) \(p.choices[i]) → \(kind)")
        }
        return pick(p, index: hits[0], concept: concept, steps: steps)
    }

    // MARK: 역사: 시대 · 인물

    /// 우리 역사의 시대 (경계에 걸치는 해는 모름)
    static let koreanEras: [(names: [String], from: Int, to: Int)] = [
        (["고조선"], -2333, -109), (["삼국 시대", "삼국"], -56, 667), (["통일 신라", "남북국 시대"], 677, 917),
        (["고려 시대", "고려"], 937, 1391), (["조선 시대", "조선"], 1393, 1896), (["대한 제국"], 1898, 1909),
        (["일제 강점기", "일제강점기"], 1911, 1944)
    ]

    /// 한국사 사건 하나 (이름이 꼭 맞을 때)
    static func koreanEvent(_ choice: String) -> (year: Int, end: Int, names: [String], who: String?)? {
        let k = key(choice).replacingOccurrences(of: "의", with: "")
        let hits = DoitSocial.eventDetails.filter { e in !e.approx && !e.world && e.names.contains { key($0).replacingOccurrences(of: "의", with: "") == k } }
        guard let first = hits.first, Set(hits.map(\.year)).count == 1 else { return nil }
        return (first.year, first.end ?? first.year, first.names, first.who)
    }

    /// "다음 중 고려 시대에 일어난 사건은?"
    static func eraQuestion(_ p: Problem) -> Found? {
        guard p.isChoice, p.box.isEmpty else { return nil }
        let c = key(p.stem)
        let asked = koreanEras.filter { era in era.names.contains { c.contains(key($0) + "시대") || c.contains(key($0) + "에일어난") || c.contains(key($0) + "때") } }
        guard asked.count == 1, let era = asked.first, matches(p.compact, #"(사건|일어난|있었던)"#) else { return nil }
        var verdicts: [Bool] = []
        var steps: [SolutionStep] = []
        for (i, choice) in p.choices.enumerated() {
            guard let e = koreanEvent(choice) else { return nil }
            // 대한 제국 시기(1897~1910)는 조선에 넣는 책과 안 넣는 책이 있어서 모름
            if era.names[0] == "조선 시대", e.year >= 1897, e.year <= 1910 { return nil }
            // 사건 기간이 시대 하나 안에 다 들어가야 판단 (경계에 걸치면 모름)
            let inside = e.year >= era.from && e.end <= era.to
            let outside = koreanEras.contains { other in other.names != era.names && e.year >= other.from && e.end <= other.to } || e.year > 1945
            guard inside != outside else { return nil }
            verdicts.append(inside)
            steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(choice): \(yearText(e.year))" + (inside ? " → \(era.names[0])" : "")))
        }
        let hits = verdicts.indices.filter { verdicts[$0] != p.negated }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: "\(era.names[0])의 사건", steps: steps)
    }

    /// "인물과 사건의 연결이 옳지 않은 것은?" (사건의 인물이 한 사람으로 정해진 것만)
    static func personEvent(_ p: Problem) -> Found? {
        guard p.isChoice, matches(p.compact, #"(인물|사람).{0,12}(연결|짝)"#),
              p.choices.allSatisfy({ $0.contains("-") || $0.contains("–") || $0.contains(":") }) else { return nil }
        var verdicts: [Bool] = []
        var steps: [SolutionStep] = []
        for (i, choice) in p.choices.enumerated() {
            let parts = choice.components(separatedBy: CharacterSet(charactersIn: "-–:")).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, let e = koreanEvent(parts[1]) ?? koreanEvent(parts[0]), let who = e.who, !who.contains(",") else { return nil }
            let person = koreanEvent(parts[1]) != nil ? parts[0] : parts[1]
            let names = who.components(separatedBy: CharacterSet(charactersIn: "()")).map { key($0) }.filter { !$0.isEmpty }
            let ok = names.contains(key(person))
            verdicts.append(ok)
            steps.append(SolutionStep(hint: "", work: "\(circled(i + 1)) \(e.names[0]) (\(yearText(e.year))): \(who)" + (ok ? " ✓" : "")))
        }
        let hits = verdicts.indices.filter { verdicts[$0] != p.negated }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: "역사 인물과 사건", steps: steps)
    }

    // MARK: 지리: 경도와 시차

    /// 글 속 경도 (동경 +, 서경 −, "경도 0°"·"(0°)"는 0)
    static func longitudes(_ text: String) -> [(value: Double, position: Int)] {
        var out: [(Double, Int)] = []
        let ns = text as NSString
        if let regex = try? NSRegularExpression(pattern: #"(동경|서경)\s*([0-9]+(?:\.[0-9]+)?)\s*(°|도)?|(?:경도\s*|\()0\s*°|본초\s*자오선"#) {
            for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                if m.range(at: 1).location != NSNotFound, let v = Double(ns.substring(with: m.range(at: 2))) {
                    out.append((ns.substring(with: m.range(at: 1)) == "동경" ? v : -v, m.range.location))
                } else {
                    out.append((0, m.range.location))
                }
            }
        }
        return out
    }

    static func timeZone(_ p: Problem) -> Found? {
        let c = p.compact
        guard !matches(c, #"(서머타임|일광절약|날짜변경선)"#) else { return nil }
        let rule = SolutionStep(hint: "경도와 시차", work: "지구는 24시간에 360° 돌아서 경도 15°마다 1시간 차이가 나요. 동쪽(경도가 큰 동경)일수록 시각이 빨라요.")
        // 경도 차이만 주어진 경우
        if let m = c.firstMatch(of: #/경도(의)?차이가?([0-9]+)°?(도)?인?/#), let d = Double(String(m.2)), c.contains("시차") {
            let hours = d / 15
            return answerValue(p, value: hours, unit: "시간", dimension: nil, concept: "경도와 시차", steps: [rule, SolutionStep(hint: "계산", work: "\(DoitScience.fmt(d))° ÷ 15° = \(DoitScience.fmt(hours))시간")])
        }
        let lons = longitudes(p.stem)
        guard lons.count == 2 else { return nil }
        let diff = lons[1].value - lons[0].value
        let hours = diff / 15
        guard hours == hours.rounded() else { return nil }
        let lonText = { (v: Double) -> String in v == 0 ? "0°" : (v > 0 ? "동경 \(DoitScience.fmt(v))°" : "서경 \(DoitScience.fmt(-v))°") }
        let calc = SolutionStep(hint: "경도 차이", work: "\(lonText(lons[0].value))와 \(lonText(lons[1].value)): \(DoitScience.fmt(abs(diff)))° ÷ 15° = \(DoitScience.fmt(abs(hours)))시간")
        // 시차를 묻는 경우
        if c.contains("시차"), !matches(c, #"(오전|오후)[0-9]+시일때"#) {
            return answerValue(p, value: abs(hours), unit: "시간", dimension: nil, concept: "경도와 시차", steps: [rule, calc])
        }
        // 한 곳의 시각 → 다른 곳의 시각 (주어진 시각이 두 경도 사이에 있어야 첫째 곳의 시각)
        let ns = p.stem as NSString
        guard let regex = try? NSRegularExpression(pattern: #"(오전|오후)\s*([0-9]{1,2})\s*시"#),
              let m = regex.firstMatch(in: p.stem, range: NSRange(location: 0, length: ns.length)),
              m.range.location > lons[0].position, m.range.location < lons[1].position, matches(c, #"(몇시|시각은|시각을|시각이)"#) else { return nil }
        guard let h = Int(ns.substring(with: m.range(at: 2))), h >= 1, h <= 12 else { return nil }
        let given = (ns.substring(with: m.range(at: 1)) == "오후" ? (h % 12) + 12 : h % 12)
        let target = given + Int(hours)
        guard target >= 0, target < 24 else { return nil }   // 날짜가 바뀌면 풀지 않음
        func show(_ t: Int) -> String { t == 0 ? "오전 0시(자정)" : t < 12 ? "오전 \(t)시" : t == 12 ? "오후 12시(정오)" : "오후 \(t - 12)시" }
        func parse(_ s: String) -> Int? {
            let k = s.filter { !$0.isWhitespace }
            if k == "자정" { return 0 }
            if k == "정오" { return 12 }
            guard let mm = k.firstMatch(of: #/^(오전|오후)([0-9]{1,2})시/#), let n = Int(String(mm.2)), n <= 12 else { return nil }
            return mm.1 == "오후" ? (n == 12 ? 12 : n + 12) : (n == 12 ? nil : n)
        }
        let steps = [rule, calc, SolutionStep(hint: "시각", work: "\(show(given)) \(hours >= 0 ? "+" : "−") \(Int(abs(hours)))시간 = \(show(target))")]
        if p.isChoice {
            let values = p.choices.map(parse)
            guard values.allSatisfy({ $0 != nil }) else { return nil }
            let hits = values.indices.filter { values[$0] == target }
            guard hits.count == 1 else { return nil }
            return pick(p, index: hits[0], concept: "경도와 시차", steps: steps)
        }
        return Found(answer: show(target), concept: "경도와 시차", steps: steps)
    }
}
