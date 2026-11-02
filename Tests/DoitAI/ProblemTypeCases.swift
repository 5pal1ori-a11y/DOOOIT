import Foundation

// MARK: - 문제 유형 사전 · 과목 자동 판단 · 오답노트 연결

private struct TypeCase {
    let text: String
    var hint: String? = nil
    /// 맞는 유형 이름에 들어 있어야 하는 말 (여러 개면 모두)
    let expect: [String]
    /// 몇 번째 안에 들면 되는지
    var within: Int = 1
    /// 유형의 큰 과목
    var subject: String? = nil
}

private struct SubjectCase {
    let text: String
    let broad: String
    var detail: String? = nil
}

private let typeCases: [TypeCase] = [
    // 국어 · 독서
    TypeCase(text: "윗글의 내용과 일치하지 않는 것은?", expect: ["내용 일치"], subject: "국어"),
    TypeCase(text: "윗글의 내용과 일치하는 것은?", hint: "국어", expect: ["내용 일치"], subject: "국어"),
    TypeCase(text: "윗글을 이해한 내용으로 적절하지 않은 것은?", expect: ["세부 정보"], subject: "국어"),
    TypeCase(text: "윗글에 대한 이해로 가장 적절한 것은?", expect: ["세부 정보"], subject: "국어"),
    TypeCase(text: "㉠에 대한 설명으로 적절하지 않은 것은?", hint: "국어", expect: ["핵심 개념"]),
    TypeCase(text: "윗글의 서술 방식으로 가장 적절한 것은?", hint: "국어", expect: ["서술"], within: 2),
    TypeCase(text: "윗글을 바탕으로 추론한 내용으로 적절하지 않은 것은?", expect: ["추론"]),
    TypeCase(text: "윗글을 바탕으로 <보기>를 이해한 내용으로 적절하지 않은 것은? [3점]", expect: ["<보기> 적용"]),
    TypeCase(text: "윗글을 바탕으로 〈보 기〉를 이해한 내용으로 가장 적절한 것은?", expect: ["<보기> 적용"]),
    TypeCase(text: "문맥상 의미가 가장 가까운 것은?", expect: ["문맥적 의미"], subject: "국어"),
    TypeCase(text: "문맥상 ⓐ~ⓔ와 바꿔 쓰기에 적절하지 않은 것은?", expect: ["바꿔 쓰기"]),
    TypeCase(text: "윗글에 대한 반응으로 적절하지 않은 것은?", hint: "국어", expect: ["비판·반응"]),
    TypeCase(text: "윗글을 통해 답을 확인할 수 없는 질문은?", expect: ["답할 수 있는 질문"]),
    TypeCase(text: "(가)와 (나)에 대한 설명으로 적절한 것은? (가)와 (나)의 공통점", hint: "국어", expect: ["비교"], within: 2),
    TypeCase(text: "㉠의 사례로 가장 적절한 것은?", hint: "국어", expect: ["구체적 사례"]),
    TypeCase(text: "다음 중 글쓴이의 관점으로 가장 적절한 것은?", hint: "국어", expect: ["관점"]),
    // 국어 · 문학
    TypeCase(text: "윗글의 표현상 특징으로 가장 적절한 것은?", expect: ["표현상 특징"], subject: "국어"),
    TypeCase(text: "윗글의 서술상 특징으로 가장 적절한 것은?", hint: "국어", expect: ["서술상 특징"]),
    TypeCase(text: "<보기>를 바탕으로 윗글을 감상한 내용으로 적절하지 않은 것은?", expect: ["<보기> 감상"]),
    TypeCase(text: "〈보기〉를 참고하여 (가)를 감상한 것으로 적절하지 않은 것은?", expect: ["<보기> 감상"]),
    TypeCase(text: "㉠~㉤에 대한 이해로 적절하지 않은 것은? 시어의 의미와 기능", hint: "국어", expect: ["시어"], within: 2),
    TypeCase(text: "화자의 태도로 가장 적절한 것은?", expect: ["화자"]),
    TypeCase(text: "[A]에 나타난 인물의 심리로 가장 적절한 것은?", hint: "국어", expect: ["인물 심리"]),
    TypeCase(text: "(가)~(다)의 공통점으로 가장 적절한 것은?", hint: "문학", expect: ["공통점"]),
    TypeCase(text: "윗글을 영화로 만들기 위한 연출 계획으로 적절하지 않은 것은? S#12", expect: ["극"]),
    TypeCase(text: "윗글의 상황에 어울리는 한자 성어로 가장 적절한 것은?", expect: ["한자 성어"]),
    // 국어 · 문법 · 화작 · 매체
    TypeCase(text: "<보기>의 음운 변동에 대한 설명으로 옳은 것은? 국물[궁물], 신라[실라]", expect: ["음운 변동"], within: 2),
    TypeCase(text: "다음 중 구개음화가 일어나는 단어는?", expect: ["구개음화"]),
    TypeCase(text: "밑줄 친 단어의 품사가 나머지와 다른 것은?", hint: "국어", expect: ["품사"]),
    TypeCase(text: "다음 문장의 문장 성분에 대한 설명으로 옳은 것은? 서술어의 자릿수", expect: ["문장 성분"]),
    TypeCase(text: "<보기>의 안은문장에 대한 설명으로 적절한 것은? 관형절", expect: ["문장의 짜임"]),
    TypeCase(text: "높임 표현에 대한 설명으로 옳은 것은? 주체 높임과 객체 높임", expect: ["높임"]),
    TypeCase(text: "다음 중세 국어 자료에 대한 설명으로 옳지 않은 것은? 이어적기", expect: ["중세 국어"]),
    TypeCase(text: "다음 중 한글 맞춤법에 맞게 쓴 것은?", expect: ["맞춤법"]),
    TypeCase(text: "밑줄 친 단어 중 파생어가 아닌 것은? 접사와 어근", expect: ["단어 형성"]),
    TypeCase(text: "다음 토론에서 찬성 측 입론에 대한 반대 측의 반론으로 적절한 것은?", expect: ["토론"]),
    TypeCase(text: "다음은 학생의 초고이다. 글쓰기 계획 중 초고에 반영되지 않은 것은?", expect: ["작문 계획"]),
    TypeCase(text: "<조건>을 모두 반영하여 쓴 문장으로 가장 적절한 것은?", hint: "국어", expect: ["조건"]),
    TypeCase(text: "다음은 학생이 작성한 블로그 게시물이다. 매체 자료에 대한 설명으로 적절한 것은?", expect: ["매체"]),
    TypeCase(text: "다음 발표에서 활용한 말하기 방식으로 적절한 것은?", expect: ["말하기 방식"]),
    // 영어 · 독해
    TypeCase(text: "다음 글의 목적으로 가장 적절한 것은?\nDear Mr. Smith, I am writing to inform you that our community center will be closed next week for repairs. We apologize for any inconvenience.", expect: ["글의 목적"], subject: "영어"),
    TypeCase(text: "다음 글에 드러난 Jane의 심경 변화로 가장 적절한 것은? Jane was nervous as she walked onto the stage, but when the audience smiled at her she felt relieved and confident.", expect: ["심경"], subject: "영어"),
    TypeCase(text: "다음 글에서 필자가 주장하는 바로 가장 적절한 것은? We should teach children how to manage their emotions because it helps them build healthy relationships with others.", expect: ["필자 주장"]),
    TypeCase(text: "밑줄 친 a double-edged sword가 다음 글에서 의미하는 바로 가장 적절한 것은? Technology can be a double-edged sword for students who study online.", expect: ["함축 의미"]),
    TypeCase(text: "다음 글의 요지로 가장 적절한 것은? Reading regularly improves not only your vocabulary but also your ability to think critically about the world.", expect: ["요지"]),
    TypeCase(text: "다음 글의 주제로 가장 적절한 것은? Many animals use colors to communicate with each other and to warn predators about danger in the wild.", expect: ["주제"], subject: "영어"),
    TypeCase(text: "다음 글의 제목으로 가장 적절한 것은? People often think that creativity is a gift, but it is actually a skill that anyone can develop through practice.", expect: ["제목"], subject: "영어"),
    TypeCase(text: "다음 도표의 내용과 일치하지 않는 것은? The above graph shows the percentage of students who used smartphones in 2020 and 2023.", expect: ["도표"]),
    TypeCase(text: "Marie Curie에 관한 다음 글의 내용과 일치하지 않는 것은? Marie Curie was born in Warsaw in 1867 and later moved to Paris to study physics.", expect: ["내용 일치(인물)"]),
    TypeCase(text: "Summer Science Camp에 관한 다음 안내문의 내용과 일치하지 않는 것은? Date: July 10 - 14, Fee: $50 per person", expect: ["안내문"]),
    TypeCase(text: "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은? The number of people who [visit] the museum have increased since the new exhibition opened.", expect: ["어법"], subject: "영어"),
    TypeCase(text: "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?", expect: ["어법"]),
    TypeCase(text: "다음 글의 밑줄 친 부분 중, 문맥상 낱말의 쓰임이 적절하지 않은 것은? Plants that receive more light tend to grow faster and produce more fruit.", expect: ["어휘 쓰임"]),
    TypeCase(text: "다음 빈칸에 들어갈 말로 가장 적절한 것은? Scientists have found that people who sleep well are more likely to remember what they learned the day before.", expect: ["빈칸 추론"], subject: "영어"),
    TypeCase(text: "다음 글의 빈칸 (A), (B)에 들어갈 말로 가장 적절한 것은? (A) However (B) For example. The weather was cold. However, we decided to go hiking anyway.", expect: ["연결어"]),
    TypeCase(text: "다음 글에서 전체 흐름과 관계 없는 문장은? Exercise is good for the brain. It increases blood flow and helps new cells grow in the body.", expect: ["무관한 문장"]),
    TypeCase(text: "주어진 글 다음에 이어질 글의 순서로 가장 적절한 것은? (A) Then they moved to the city. (B) At first, the family lived on a farm. (C) Finally, they opened a small shop.", expect: ["글의 순서"]),
    TypeCase(text: "글의 흐름으로 보아, 주어진 문장이 들어가기에 가장 적절한 곳은? This, however, was not the end of the story for the young inventor.", expect: ["문장 삽입"]),
    TypeCase(text: "다음 글의 내용을 한 문장으로 요약하고자 한다. 빈칸 (A), (B)에 들어갈 말로 가장 적절한 것은?", expect: ["요약문"]),
    TypeCase(text: "밑줄 친 she가 가리키는 대상이 나머지 넷과 다른 것은?", expect: ["지칭"]),
    TypeCase(text: "Which of the following is the best title for the passage? Bees are disappearing all over the world because of pesticides and climate change.", expect: ["제목"]),
    TypeCase(text: "What is the main idea of the passage? Learning a second language makes the brain more flexible and helps people solve problems.", expect: ["요지"], within: 2),
    // 영어 · 듣기 · 어휘 · 서술형 · 어법 포인트
    TypeCase(text: "대화를 듣고, 남자가 할 일로 가장 적절한 것을 고르시오.", expect: ["할 일"]),
    TypeCase(text: "대화를 듣고, 여자가 지불할 금액을 고르시오.", expect: ["지불 금액"]),
    TypeCase(text: "다음을 듣고, 여자가 하는 말의 목적으로 가장 적절한 것을 고르시오.", expect: ["듣기 · 목적"]),
    TypeCase(text: "대화를 듣고, 두 사람의 관계를 가장 잘 나타낸 것을 고르시오.", expect: ["관계"]),
    TypeCase(text: "대화를 듣고, 남자의 마지막 말에 대한 여자의 응답으로 가장 적절한 것을 고르시오.", expect: ["응답"]),
    TypeCase(text: "다음 영영 풀이에 해당하는 단어로 알맞은 것은? a person who writes books", expect: ["영영 풀이"]),
    TypeCase(text: "짝지어진 단어의 관계가 나머지와 다른 것은? happy - sad, big - small", expect: ["단어 관계"]),
    TypeCase(text: "주어진 단어를 바르게 배열하여 문장을 완성하시오. (to / want / I / go)", hint: "영어", expect: ["배열"]),
    TypeCase(text: "다음 밑줄 친 관계대명사의 쓰임이 나머지와 다른 것은?", expect: ["관계대명사", "쓰임"]),
    TypeCase(text: "다음 중 어법상 틀린 문장은? 현재완료", expect: ["현재완료"], within: 2),
    TypeCase(text: "밑줄 친 to부정사의 용법이 같은 것은?", expect: ["to부정사"]),
    TypeCase(text: "다음 중 가정법 문장으로 어법상 알맞은 것은?", expect: ["가정법"]),
    // 수학
    TypeCase(text: "함수 f(x) = x^2 - 4x + 3 (0 ≤ x ≤ 3)의 최댓값과 최솟값의 합을 구하시오.", expect: ["최댓값"], subject: "수학"),
    TypeCase(text: "이차함수 y = x² - 6x + k 의 최솟값이 3일 때, 상수 k의 값은?", expect: ["이차함수"], subject: "수학"),
    TypeCase(text: "이차방정식 x² - 5x + 6 = 0 의 두 근의 합을 구하시오.", expect: ["합"], within: 2, subject: "수학"),
    TypeCase(text: "일차방정식 3x + 5 = 2x - 1 의 해를 구하시오.", expect: ["일차방정식"]),
    TypeCase(text: "연립방정식 x + y = 5, x - y = 1 의 해를 구하시오.", expect: ["연립"], within: 2),
    TypeCase(text: "일차부등식 2x - 3 < 5 를 만족하는 자연수 x의 개수를 구하시오.", expect: ["일차부등식"], within: 2),
    TypeCase(text: "두 점 (1, 2), (3, 6)을 지나는 일차함수의 그래프의 기울기를 구하시오.", expect: ["일차함수"]),
    TypeCase(text: "다항식 P(x)를 x - 1로 나누었을 때의 나머지가 3일 때, 나머지정리를 이용하여 a의 값을 구하시오.", expect: ["나머지정리"]),
    TypeCase(text: "다음 중 옳은 것만을 <보기>에서 있는 대로 고른 것은? ㄱ. 모든 실수 x에 대하여 f(x) > 0 ㄴ. 함수 f는 극댓값을 갖는다.", hint: "수학", expect: ["참·거짓"], within: 2),
    TypeCase(text: "다음은 √2가 무리수임을 증명하는 과정이다. (가), (나)에 알맞은 것은?", expect: ["증명"]),
    TypeCase(text: "log₂ 8 + log₂ 4 의 값은? 로그의 값", expect: ["로그"]),
    TypeCase(text: "등차수열 {a_n}에서 a_3 = 7, a_7 = 15일 때, a_10의 값을 구하시오.", expect: ["등차수열"]),
    TypeCase(text: "등비수열의 첫째항부터 제5항까지의 합을 구하시오. 공비가 2", expect: ["등비수열"]),
    TypeCase(text: "lim(x→2) (x² - 4)/(x - 2) 의 극한값을 구하시오.", expect: ["극한"]),
    TypeCase(text: "곡선 y = x³ - 3x 위의 점 (1, -2)에서의 접선의 방정식을 구하시오.", expect: ["접선"]),
    TypeCase(text: "함수 f(x) = x³ - 3x² + 2 의 극댓값과 극솟값의 합을 구하시오.", expect: ["극값"], within: 2),
    TypeCase(text: "곡선 y = x² 과 직선 y = x 로 둘러싸인 부분의 넓이를 구하시오.", expect: ["넓이"]),
    TypeCase(text: "방정식 x³ - 3x + k = 0 이 서로 다른 세 실근을 갖도록 하는 정수 k의 개수는?", expect: ["방정식·부등식과 미분"], within: 2),
    TypeCase(text: "남학생 3명과 여학생 2명을 일렬로 세울 때, 여학생끼리 이웃하는 경우의 수를 구하시오.", expect: ["경우의 수"], within: 3),
    TypeCase(text: "주머니에서 공을 2개 꺼낼 때 두 공이 모두 흰 공일 확률을 구하시오.", expect: ["확률"]),
    TypeCase(text: "두 사건 A, B에 대하여 P(A) = 1/2, P(B|A) = 1/3 일 때 조건부확률을 이용하여 P(A∩B)를 구하시오.", expect: ["조건부확률"]),
    TypeCase(text: "확률변수 X가 이항분포 B(10, 1/2)를 따를 때, E(X)의 값을 구하시오.", expect: ["이항분포"], within: 2),
    TypeCase(text: "정규분포 N(50, 4²)을 따르는 확률변수 X에 대하여 P(X ≥ 54)를 표준정규분포표를 이용하여 구하시오.", expect: ["정규분포"]),
    TypeCase(text: "원 x² + y² - 4x + 2y = 0 의 중심의 좌표와 반지름의 길이를 구하시오.", expect: ["원의 방정식"]),
    TypeCase(text: "sin θ + cos θ = 1/2 일 때, sin θ cos θ 의 값을 구하시오.", expect: ["삼각함수"]),
    TypeCase(text: "삼각형 ABC에서 사인법칙을 이용하여 외접원의 반지름의 길이를 구하시오.", expect: ["사인·코사인법칙"]),
    TypeCase(text: "√12 + √27 - √48 을 간단히 하면? 제곱근", expect: ["제곱근"], within: 2),
    TypeCase(text: "x² - 9 를 인수분해하면?", expect: ["인수분해"]),
    TypeCase(text: "직각삼각형에서 빗변의 길이가 13, 한 변의 길이가 5일 때 피타고라스 정리로 나머지 변의 길이를 구하시오.", expect: ["피타고라스"]),
    TypeCase(text: "다음 자료의 평균과 분산을 구하시오. 3, 5, 7, 9", expect: ["대푯값과 산포도"]),
    TypeCase(text: "두 집합 A = {1, 2, 3}, B = {2, 3, 4}에 대하여 A∪B의 원소의 개수를 구하시오.", expect: ["집합"]),
    TypeCase(text: "명제 'x > 2이면 x > 1이다'의 대우가 참인지 판단하시오. 필요조건과 충분조건", expect: ["명제"]),
    TypeCase(text: "벡터 a = (1, 2), b = (3, -1)에 대하여 두 벡터의 내적을 구하시오.", expect: ["벡터"]),
    TypeCase(text: "타원 x²/25 + y²/9 = 1 의 두 초점 사이의 거리를 구하시오.", expect: ["이차곡선"]),
    // 과학
    TypeCase(text: "그림은 수평면에서 운동하는 물체 A의 속력을 시간에 따라 나타낸 것이다. 가속도의 크기는? 알짜힘", expect: ["힘과 운동"], subject: "과학"),
    TypeCase(text: "그림과 같이 질량이 2kg인 물체가 충돌한 후 정지하였다. 충돌 과정에서 받은 충격량의 크기는? 운동량", expect: ["운동량"]),
    TypeCase(text: "그림은 저항 R1, R2를 전원 장치에 연결한 회로이다. 이에 대한 설명으로 옳은 것만을 <보기>에서 있는 대로 고른 것은? 전류 전압 직렬", expect: ["전기장과 회로"]),
    TypeCase(text: "그림은 솔레노이드에 자석을 가까이 할 때 유도 전류가 흐르는 모습이다. 전자기 유도에 대한 설명으로 옳은 것은?", expect: ["전자기 유도"]),
    TypeCase(text: "다음은 광전 효과 실험이다. 금속판에 비추는 빛의 진동수를 바꾸며 방출되는 광전자를 측정하였다. 실험 결과에 대한 해석으로 옳은 것은?", expect: ["이중성"], within: 2),
    TypeCase(text: "표는 원소 A~D의 원자 반지름과 이온화 에너지를 나타낸 것이다. 이에 대한 설명으로 옳은 것은? 주기율", expect: ["주기적 성질"]),
    TypeCase(text: "다음은 화학 반응식과 양적 관계에 대한 자료이다. 반응 후 남은 반응물의 질량은? 몰수", expect: ["양적 관계"]),
    TypeCase(text: "그림은 HCl 수용액에 NaOH 수용액을 넣을 때 중화 반응에서 이온 수 변화를 나타낸 것이다. 중화점에서", expect: ["산과 염기"]),
    TypeCase(text: "다음 반응에서 산화수가 증가한 원소는? 산화제와 환원제", expect: ["산화 환원"]),
    TypeCase(text: "그림은 어떤 사람의 가계도를 나타낸 것이다. 유전 형질 (가)는 우성인가 열성인가? 대립유전자", expect: ["가계도"], subject: "과학"),
    TypeCase(text: "그림은 어떤 동물의 감수 분열 과정에서 DNA 상대량 변화를 나타낸 것이다. 상동 염색체", expect: ["세포 분열"]),
    TypeCase(text: "그래프는 항원 X를 주사한 후 혈중 항체 농도 변화를 나타낸 것이다. 2차 면역 반응에 대한 설명으로 옳은 것은? 기억 세포", expect: ["면역"]),
    TypeCase(text: "그림은 뉴런에서 흥분이 전도될 때 막전위 변화를 나타낸 것이다. 활동 전위", expect: ["신경계"]),
    TypeCase(text: "그래프는 혈당량 변화에 따른 인슐린과 글루카곤의 분비량을 나타낸 것이다. 항상성", expect: ["항상성"]),
    TypeCase(text: "그림은 생태계에서 에너지 흐름과 물질 순환을 나타낸 것이다. 생산자 소비자 분해자", expect: ["생태계"]),
    TypeCase(text: "그림은 해령 주변 해양 지각의 고지자기 줄무늬를 나타낸 것이다. 판 구조론에 대한 설명으로 옳은 것은? 해양저 확장", expect: ["판 구조론"]),
    TypeCase(text: "그림은 어느 지역의 지층 단면이다. 부정합과 관입이 나타나 있다. 지층의 생성 순서는?", expect: ["지층과 암석"], within: 2),
    TypeCase(text: "그림은 우리나라 주변의 일기도이다. 온대 저기압과 한랭 전선이 통과할 때 날씨 변화로 옳은 것은?", expect: ["대기와 날씨"]),
    TypeCase(text: "그래프는 엘니뇨 시기와 평상시의 동태평양 표층 수온을 나타낸 것이다. 무역풍", expect: ["해수와 해류"]),
    TypeCase(text: "그림은 H-R도에 별 A~D를 나타낸 것이다. 주계열성과 백색 왜성의 광도 비교", expect: ["별의 특성"]),
    TypeCase(text: "그래프는 외부 은하의 거리와 후퇴 속도를 나타낸 것이다. 허블 법칙과 우주 팽창에 대한 설명으로 옳은 것은?", expect: ["우주론"]),
    TypeCase(text: "다음은 물의 상태 변화 실험이다. 얼음을 가열할 때 융해가 일어나는 동안 온도 변화에 대한 설명으로 옳은 것은?", expect: ["상태 변화"]),
    TypeCase(text: "다음은 광합성에 필요한 조건을 알아보는 실험이다. 아이오딘 반응으로 녹말을 확인하였다. 조작 변인과 통제 변인", expect: ["광합성"], within: 2),
    TypeCase(text: "이 실험에서 조작 변인과 통제 변인으로 옳은 것은? 대조군과 실험군", hint: "과학", expect: ["변인"]),
    // 사회
    TypeCase(text: "그래프는 X재 시장의 수요 곡선과 공급 곡선의 이동을 나타낸 것이다. 균형 가격의 변화로 옳은 것은?", expect: ["수요와 공급"], subject: "사회"),
    TypeCase(text: "다음 자료에서 갑이 선택한 대안의 기회비용은? 편익과 비용", expect: ["합리적 선택"]),
    TypeCase(text: "표는 갑국의 경제 성장률과 물가 상승률, 실업률을 나타낸 것이다. 이에 대한 분석으로 옳은 것은?", expect: ["국민 경제"]),
    TypeCase(text: "다음 자료에서 환율 상승이 경상 수지에 미치는 영향으로 옳은 것은? 원화 가치", expect: ["무역과 환율"]),
    TypeCase(text: "다음 사례에 나타난 기본권의 종류로 옳은 것은? 청구권과 사회권", expect: ["헌법과 기본권"]),
    TypeCase(text: "다음 사례에서 미성년자 갑이 법정 대리인의 동의 없이 맺은 계약에 대한 법적 판단으로 옳은 것은?", expect: ["민법"]),
    TypeCase(text: "다음 형사 절차에서 피의자와 피고인의 권리에 대한 설명으로 옳은 것은? 구속 영장", expect: ["형법"]),
    TypeCase(text: "표는 A국과 B국의 정부 형태를 비교한 것이다. 대통령제와 의원 내각제", expect: ["정부 형태"]),
    TypeCase(text: "다음 연구 방법에 대한 설명으로 옳은 것은? 질문지법으로 자료를 수집하여 가설을 검증하였다. 양적 연구", expect: ["연구 방법"]),
    TypeCase(text: "다음 사례에 나타난 문화 이해 태도로 옳은 것은? 자문화 중심주의와 문화 상대주의", expect: ["문화의 이해"]),
    TypeCase(text: "다음 일탈 이론에 대한 설명으로 옳은 것은? 낙인 이론과 차별 교제 이론", expect: ["일탈"]),
    TypeCase(text: "지도의 A~E 지역에 대한 설명으로 옳은 것은? 카르스트 지형과 화산 지형", expect: ["지형"], within: 2),
    TypeCase(text: "다음 기후 그래프는 (가)~(다) 지역의 기온과 강수량을 나타낸 것이다. 지중해성 기후와 서안 해양성 기후", expect: ["세계의 기후"], within: 2),
    TypeCase(text: "그래프는 지역별 노령화 지수와 유소년 부양비를 나타낸 것이다. 인구 구조", expect: ["인구"]),
    TypeCase(text: "다음 지도에 표시된 지역의 종교에 대한 설명으로 옳은 것은? 이슬람교 힌두교", expect: ["문화와 종교"], within: 2),
    // 윤리
    TypeCase(text: "자료에 나타난 사상가의 입장으로 옳은 것은? 사람의 본성은 선하다. 측은지심은 인의 단서이다.", expect: ["사상가 입장"], within: 2, subject: "윤리"),
    TypeCase(text: "갑, 을은 서양 사상가이다. 갑: 도덕 법칙은 정언 명령의 형식이다. 을: 최대 다수의 최대 행복을 추구해야 한다. 갑, 을의 입장으로 옳은 것은?", expect: ["사상가"], within: 2),
    TypeCase(text: "다음 서양 사상가의 입장에서 볼 때 칸트의 정언 명령에 대한 설명으로 옳은 것은?", expect: ["칸트"], within: 3),
    TypeCase(text: "갑, 을의 입장에서 안락사에 대한 설명으로 옳은 것은?", expect: ["생명 윤리"], within: 2),
    TypeCase(text: "다음 가상 대화에서 사상가가 할 말로 적절한 것은? 노자: 무위자연과 소국과민", expect: ["도가"], within: 3),
    TypeCase(text: "(가) 사상가의 입장에서 질문에 대한 답변으로 옳은 것은? (예) (아니요) 롤스의 차등의 원칙", expect: ["정의론"], within: 3),
    TypeCase(text: "그림의 A~C에 해당하는 특징으로 옳은 것은? A는 갑만, B는 갑과 을 모두, C는 을만의 입장이다. 레오폴드 대지 윤리", expect: ["환경 윤리"], within: 3),
    TypeCase(text: "다음 사례에 대해 시민 불복종의 정당화 조건을 적용한 조언으로 적절한 것은? 공개적, 비폭력", expect: ["시민 불복종"], within: 2),
    TypeCase(text: "다음 중 갈퉁의 적극적 평화와 구조적 폭력에 대한 설명으로 옳은 것은?", expect: ["평화"], within: 2),
    TypeCase(text: "불교의 연기설과 사성제, 팔정도에 대한 설명으로 옳은 것은?", expect: ["불교"]),
    // 역사
    TypeCase(text: "(가)~(다)를 시대 순으로 옳게 나열한 것은? (가) 광종이 노비안검법을 실시하였다. (나) 서희가 거란과 담판하였다. (다) 묘청이 서경 천도를 주장하였다.", expect: ["시대 순"], subject: "역사"),
    TypeCase(text: "다음 사건을 일어난 순서대로 나열한 것은? 임오군란, 갑신정변, 동학 농민 운동", expect: ["시대 순"]),
    TypeCase(text: "밑줄 친 '왕'의 업적으로 옳은 것은? 왕은 집현전을 설치하고 훈민정음을 창제하였다.", expect: ["인물·왕"], within: 2),
    TypeCase(text: "(가) 시기에 있었던 사실로 옳은 것은? 3·1 운동과 신간회 창립 사이, 문화 통치", expect: ["시기"], within: 2),
    TypeCase(text: "(가) 단체에 대한 설명으로 옳은 것은? 의열단과 한인 애국단의 활동", expect: ["나라·단체"], within: 2),
    TypeCase(text: "다음 자료의 정책이 실시된 배경으로 옳은 것은? 대동법과 균역법", expect: ["조선 후기"], within: 2),
    TypeCase(text: "다음 문화유산이 만들어진 시대에 대한 설명으로 옳은 것은? 빗살무늬 토기와 간석기", expect: ["선사"], within: 2),
    TypeCase(text: "프랑스 혁명과 나폴레옹 시대에 일어난 사건으로 옳은 것은? 인권 선언", expect: ["시민 혁명"], within: 2),
    TypeCase(text: "다음 중 제1차 세계 대전 이후의 사실로 옳은 것은? 베르사유 체제와 대공황", expect: ["세계 대전"], within: 2),
    // 기타
    TypeCase(text: "다음 프로그램의 실행 결과로 출력되는 값은? for i in range(3): print(i)", expect: ["실행 결과"]),
    TypeCase(text: "다음 한문 문장의 풀이로 바른 것은? 學而時習之", expect: ["한문 해석"]),
]

private let subjectCases: [SubjectCase] = [
    // 윤리 · 도덕
    SubjectCase(text: "갑, 을은 동양 사상가이다. 갑: 사람의 본성은 선하며 사단을 확충해야 한다. 을: 본성은 악하므로 예로 교화해야 한다.", broad: "윤리", detail: "윤리와 사상"),
    SubjectCase(text: "다음 서양 사상가의 입장으로 옳은 것은? 선의지만이 무조건적으로 선하며, 도덕 법칙은 정언 명령의 형식을 띤다.", broad: "윤리", detail: "윤리와 사상"),
    SubjectCase(text: "벤담과 밀의 공리주의에 대한 설명으로 옳은 것은? 최대 다수의 최대 행복", broad: "윤리", detail: "윤리와 사상"),
    SubjectCase(text: "노자의 무위자연과 소국과민 사상에 대한 설명으로 옳은 것은?", broad: "윤리", detail: "윤리와 사상"),
    SubjectCase(text: "주희의 성즉리와 왕수인의 심즉리를 비교한 것으로 옳은 것은?", broad: "윤리", detail: "윤리와 사상"),
    SubjectCase(text: "롤스는 원초적 입장에서 무지의 베일을 쓴 사람들이 정의의 원칙을 선택한다고 본다. 노직은 소유 권리론을 주장한다.", broad: "윤리"),
    SubjectCase(text: "적극적 안락사에 대한 찬성 입장과 반대 입장을 비교한 것으로 옳은 것은? 생명의 존엄성과 자율성", broad: "윤리", detail: "생활과 윤리"),
    SubjectCase(text: "레오폴드의 대지 윤리와 테일러의 생명 중심주의에 대한 설명으로 옳은 것은?", broad: "윤리", detail: "생활과 윤리"),
    SubjectCase(text: "사형 제도에 대한 갑, 을의 입장으로 옳은 것은? 갑: 응보주의 관점에서 살인자는 사형에 처해야 한다. 을: 베카리아", broad: "윤리", detail: "생활과 윤리"),
    SubjectCase(text: "시민 불복종이 정당화되려면 공개적이고 비폭력적이며 처벌을 감수해야 한다는 입장으로 옳은 것은?", broad: "윤리", detail: "생활과 윤리"),
    SubjectCase(text: "싱어와 레건의 동물 중심주의 윤리에 대한 설명으로 옳은 것은?", broad: "윤리", detail: "생활과 윤리"),
    SubjectCase(text: "도덕적 추론 과정에서 도덕 원리와 사실 판단을 찾아 도덕 판단을 내려 보자. 양심에 따라 성찰하는 삶", broad: "윤리", detail: "도덕"),
    SubjectCase(text: "불교의 연기설과 자비, 원효의 화쟁 사상과 지눌의 돈오점수", broad: "윤리"),
    SubjectCase(text: "칸트의 영구 평화론과 갈퉁의 적극적 평화, 해외 원조 의무에 대한 싱어와 롤스의 입장", broad: "윤리"),
    // 역사
    SubjectCase(text: "(가)~(다)를 시대 순으로 옳게 나열한 것은? (가) 광종이 노비안검법을 실시하였다. (나) 서희가 거란과 담판하였다. (다) 묘청이 서경 천도를 주장하였다.", broad: "역사", detail: "한국사"),
    SubjectCase(text: "밑줄 친 '왕'의 업적으로 옳은 것은? 왕은 집현전을 설치하고 훈민정음을 창제하였으며 4군 6진을 개척하였다.", broad: "역사", detail: "한국사"),
    SubjectCase(text: "다음 자료의 사건 이후에 일어난 사실로 옳은 것은? 흥선대원군이 척화비를 세우고 병인양요와 신미양요를 겪었다.", broad: "역사", detail: "한국사"),
    SubjectCase(text: "일제의 무단 통치 시기에 토지 조사 사업과 회사령이 실시되었다. 이 시기의 모습으로 옳은 것은?", broad: "역사", detail: "한국사"),
    SubjectCase(text: "4·19 혁명과 5·18 민주화 운동, 6월 민주 항쟁에 대한 설명으로 옳은 것은?", broad: "역사", detail: "한국사"),
    SubjectCase(text: "고구려 광개토대왕과 장수왕, 백제 근초고왕, 신라 진흥왕의 업적을 비교한 것으로 옳은 것은?", broad: "역사", detail: "한국사"),
    SubjectCase(text: "프랑스 혁명과 나폴레옹의 등장, 빈 체제의 성립 순서로 옳은 것은?", broad: "역사", detail: "세계사"),
    SubjectCase(text: "제1차 세계 대전 이후 베르사유 체제와 대공황, 뉴딜 정책에 대한 설명으로 옳은 것은?", broad: "역사", detail: "세계사"),
    SubjectCase(text: "르네상스와 종교 개혁, 루터와 칼뱅의 주장에 대한 설명으로 옳은 것은?", broad: "역사", detail: "세계사"),
    SubjectCase(text: "동아시아의 책봉과 조공 관계, 조선 통신사와 왜관을 통한 교류에 대한 설명으로 옳은 것은?", broad: "역사", detail: "동아시아사"),
    // 지리 · 사회
    SubjectCase(text: "지도의 A~E 지역에 대한 설명으로 옳은 것은? 영남 지방의 공업 도시와 호남 지방의 평야, 낙동강 하구의 삼각주", broad: "사회", detail: "한국지리"),
    SubjectCase(text: "우리나라의 기후에 대한 설명으로 옳은 것은? 기온의 연교차가 크고 장마와 높새바람이 나타난다.", broad: "사회", detail: "한국지리"),
    SubjectCase(text: "다음 기후 그래프의 (가)~(다)는 열대 우림, 사막 기후, 툰드라 기후 지역이다. 아프리카와 남아메리카", broad: "사회", detail: "세계지리"),
    SubjectCase(text: "지도에 표시된 서남아시아와 북부 아프리카의 이슬람교 문화와 석유 자원에 대한 설명으로 옳은 것은?", broad: "사회", detail: "세계지리"),
    SubjectCase(text: "그래프는 X재 시장의 수요 곡선과 공급 곡선을 나타낸 것이다. 균형 가격과 균형 거래량, 소비자 잉여의 변화로 옳은 것은?", broad: "사회", detail: "경제"),
    SubjectCase(text: "표는 갑국의 국내 총생산(GDP)과 물가 상승률, 실업률을 나타낸 것이다. 인플레이션과 중앙은행의 기준 금리", broad: "사회", detail: "경제"),
    SubjectCase(text: "다음 사례에서 미성년자 갑이 법정 대리인의 동의 없이 맺은 계약은 취소할 수 있다. 민법상 손해 배상 책임", broad: "사회", detail: "정치와 법"),
    SubjectCase(text: "대통령제와 의원 내각제를 비교한 것으로 옳은 것은? 국회의 탄핵 소추와 내각 불신임, 법률안 거부권", broad: "사회", detail: "정치와 법"),
    SubjectCase(text: "헌법재판소의 위헌 법률 심판과 헌법 소원, 기본권 제한의 요건에 대한 설명으로 옳은 것은?", broad: "사회", detail: "정치와 법"),
    SubjectCase(text: "다음 연구에서 연구자는 질문지법을 활용하여 양적 연구를 하였다. 독립 변수와 종속 변수, 가설의 수용 여부", broad: "사회", detail: "사회·문화"),
    SubjectCase(text: "1차 집단과 2차 집단, 내집단과 준거 집단, 공식 조직과 비공식 조직에 대한 설명으로 옳은 것은?", broad: "사회", detail: "사회·문화"),
    SubjectCase(text: "자문화 중심주의와 문화 상대주의, 문화 사대주의의 태도를 비교한 것으로 옳은 것은? 하위문화와 반문화", broad: "사회", detail: "사회·문화"),
    // 과학
    SubjectCase(text: "그림은 수평면에서 질량이 2kg인 물체 A가 등가속도 운동을 할 때 속력을 시간에 따라 나타낸 것이다. 알짜힘의 크기는?", broad: "과학", detail: "물리학"),
    SubjectCase(text: "그림은 저항과 전구를 직렬로 연결한 회로이다. 전류와 전압, 소비 전력에 대한 설명으로 옳은 것은?", broad: "과학", detail: "물리학"),
    SubjectCase(text: "파동의 굴절과 전반사, 광섬유의 원리에 대한 설명으로 옳은 것은? 굴절률이 큰 매질", broad: "과학", detail: "물리학"),
    SubjectCase(text: "특수 상대성 이론에서 시간 지연과 길이 수축에 대한 설명으로 옳은 것은? 광속", broad: "과학", detail: "물리학"),
    SubjectCase(text: "표는 원소 A~D의 전자 배치와 이온화 에너지, 원자 반지름을 나타낸 것이다. 주기율표에서 같은 주기 원소의 성질", broad: "과학", detail: "화학"),
    SubjectCase(text: "그림은 HCl 수용액에 NaOH 수용액을 넣을 때의 중화 반응을 나타낸 것이다. 수소 이온과 수산화 이온의 수, pH 변화", broad: "과학", detail: "화학"),
    SubjectCase(text: "화학 반응식 2H2 + O2 → 2H2O 에서 반응물과 생성물의 몰수와 질량 관계, 아보가드로수", broad: "과학", detail: "화학"),
    SubjectCase(text: "공유 결합과 이온 결합, 분자의 결합각과 극성 분자에 대한 설명으로 옳은 것은? 비공유 전자쌍", broad: "과학", detail: "화학"),
    SubjectCase(text: "그림은 어떤 가족의 가계도를 나타낸 것이다. 유전 형질 (가)는 X 염색체에 있는 대립유전자에 의해 결정되며 열성이다.", broad: "과학", detail: "생명과학"),
    SubjectCase(text: "그림은 뉴런에서 흥분이 전도될 때 막전위 변화와 시냅스에서의 흥분 전달을 나타낸 것이다. 활동 전위", broad: "과학", detail: "생명과학"),
    SubjectCase(text: "혈당량이 증가하면 이자에서 인슐린이 분비되고 감소하면 글루카곤이 분비된다. 음성 피드백과 항상성", broad: "과학", detail: "생명과학"),
    SubjectCase(text: "세포 호흡은 미토콘드리아에서 일어나며 ATP를 생성한다. 광합성은 엽록체에서 일어난다. 효소와 물질대사", broad: "과학", detail: "생명과학"),
    SubjectCase(text: "해령에서 멀어질수록 해양 지각의 나이가 많아지고 고지자기 줄무늬가 대칭으로 나타난다. 판 구조론과 맨틀 대류", broad: "과학", detail: "지구과학"),
    SubjectCase(text: "H-R도에서 주계열성과 적색 거성, 백색 왜성의 광도와 표면 온도, 절대 등급을 비교한 것으로 옳은 것은?", broad: "과학", detail: "지구과학"),
    SubjectCase(text: "엘니뇨 시기에는 무역풍이 약해지고 동태평양 표층 수온이 높아지며 용승이 약해진다. 해수의 순환", broad: "과학", detail: "지구과학"),
    SubjectCase(text: "온대 저기압이 통과할 때 한랭 전선과 온난 전선 주변의 날씨 변화, 일기도 해석", broad: "과학", detail: "지구과학"),
    // 국어
    SubjectCase(text: "윗글의 화자에 대한 설명으로 적절한 것은? 시적 화자는 감각적 이미지와 의인법을 활용하여 애상적 정서를 드러낸다.", broad: "국어", detail: "문학"),
    SubjectCase(text: "<보기>를 바탕으로 윗글을 감상한 내용으로 적절하지 않은 것은? 이 작품은 서술자가 사건에 개입하며 인물의 내적 갈등을 드러낸다.", broad: "국어", detail: "문학"),
    SubjectCase(text: "<보기>의 음운 변동에 대한 설명으로 옳은 것은? 비음화와 유음화, 구개음화와 된소리되기가 나타난다.", broad: "국어", detail: "문법"),
    SubjectCase(text: "밑줄 친 부분의 문장 성분과 품사에 대한 설명으로 옳은 것은? 관형절을 안은문장, 선어말 어미", broad: "국어", detail: "문법"),
    SubjectCase(text: "다음 토론에서 찬성 측 입론에 대한 반대 측 반론으로 적절한 것은? 발표자는 청중의 반응을 고려한다.", broad: "국어", detail: "화법과 작문"),
    SubjectCase(text: "문맥상 ⓐ~ⓔ와 바꿔 쓰기에 적절하지 않은 것은? 윗글을 바탕으로 추론한 내용으로 적절한 것은?", broad: "국어"),
    // 영어
    SubjectCase(text: "다음 빈칸에 들어갈 말로 가장 적절한 것은? Many people believe that success comes from talent. However, research shows that the most important factor is persistence and daily practice.", broad: "영어"),
    SubjectCase(text: "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?", broad: "영어", detail: "어법"),
    SubjectCase(text: "대화를 듣고, 여자가 남자에게 부탁한 일로 가장 적절한 것을 고르시오.", broad: "영어", detail: "듣기"),
    SubjectCase(text: "The Industrial Revolution changed the way people lived and worked. Factories replaced small workshops, and many families moved to cities to find jobs.", broad: "영어"),
    SubjectCase(text: "다음 밑줄 친 관계대명사의 쓰임이 나머지와 다른 것은? to부정사와 동명사, 현재완료", broad: "영어", detail: "어법"),
    // 수학
    SubjectCase(text: "함수 f(x) = x^2 - 4x + 3 (0 ≤ x ≤ 3)의 최댓값과 최솟값의 합을 구하시오.", broad: "수학"),
    SubjectCase(text: "이차방정식 x² - 5x + 6 = 0 의 두 근을 α, β라 할 때, α + β 의 값은?", broad: "수학"),
    SubjectCase(text: "등차수열 {a_n}에서 a_3 = 7, a_7 = 15일 때, a_10의 값을 구하시오.", broad: "수학"),
    SubjectCase(text: "삼각형 ABC에서 각의 크기와 변의 길이를 이용하여 넓이를 구하시오. 직각삼각형의 빗변", broad: "수학"),
    SubjectCase(text: "주머니에 흰 공 3개와 검은 공 2개가 있다. 공을 2개 꺼낼 때 모두 흰 공일 확률을 구하시오.", broad: "수학"),
    SubjectCase(text: "lim(x→1) (x² - 1)/(x - 1) 의 값은?", broad: "수학"),
    // 기타
    SubjectCase(text: "다음 파이썬 프로그램의 실행 결과로 출력되는 값은? 반복문과 조건문, 알고리즘", broad: "기타", detail: "정보"),
]

/// 과목을 정하기 어려운 글 (nil이어야 함)
private let ambiguousTexts: [String] = [
    "윗글의 내용과 일치하지 않는 것은?",
    "다음 중 옳은 것만을 <보기>에서 있는 대로 고른 것은?",
    "오늘 날씨가 좋다",
    "다음 중 옳은 것은?",
    "밑줄 친 부분의 의미로 가장 적절한 것은?",
    "가장 적절한 것은?",
    "1번 문제",
    "다음 설명 중 옳지 않은 것은?",
    "<보기>",
    "다음 글을 읽고 물음에 답하시오.",
]

func runProblemTypeCases() {
    // 1) 사전
    let all = DoitProblemTypes.all
    check("유형 사전: 1000개 이상", all.count >= 1000, "\(all.count)")
    check("유형 사전: id 겹치지 않음", Set(all.map(\.id)).count == all.count, "\(all.count - Set(all.map(\.id)).count)개 겹침")
    check("유형 사전: 정규식 오류 없음", DoitProblemTypes.store.brokenPatterns.isEmpty, "\(DoitProblemTypes.store.brokenPatterns.prefix(5))")
    let minimum: [String: Int] = ["국어": 70, "영어": 100, "수학": 250, "과학": 150, "사회": 100, "윤리": 80, "역사": 100, "기타": 5]
    for (subject, least) in minimum.sorted(by: { $0.key < $1.key }) {
        let n = DoitProblemTypes.types(subject: subject).count
        check("유형 사전: \(subject) \(least)개 이상", n >= least, "\(n)")
    }
    check("유형 사전: 모두 이름·묻는 것·지시문 있음", all.allSatisfy { !$0.name.isEmpty && !$0.asks.isEmpty && !$0.patterns.isEmpty },
          all.first { $0.name.isEmpty || $0.asks.isEmpty || $0.patterns.isEmpty }?.id ?? "")
    check("유형 사전: 푸는 법 2~4단계", all.allSatisfy { (2...4).contains($0.steps.count) }, all.first { !(2...4).contains($0.steps.count) }.map { "\($0.id) \($0.steps)" } ?? "")
    check("유형 사전: 함정 있음", all.allSatisfy { !$0.traps.isEmpty }, all.first { $0.traps.isEmpty }?.id ?? "")
    check("유형 사전: 큰 과목은 정해진 8개", Set(all.map(\.subject)).isSubset(of: Set(DoitSubjectDetector.broadSubjects)))
    check("유형 사전: 이름이 짧음 (22자 이하)", all.allSatisfy { $0.name.count <= 22 }, all.first { $0.name.count > 22 }?.name ?? "")
    check("유형 사전: 이름 겹침 없음 (같은 세부 과목 안)", Set(all.map { $0.detail + "/" + $0.name }).count == all.count,
          Dictionary(grouping: all, by: { $0.detail + "/" + $0.name }).filter { $0.value.count > 1 }.keys.prefix(3).joined(separator: ", "))
    check("유형 사전: 세부 과목 고르기", DoitProblemTypes.types(subject: "생활과 윤리").allSatisfy { $0.detail == "생활과 윤리" }
          && !DoitProblemTypes.types(subject: "생활과 윤리").isEmpty)
    check("유형 사전: 큰 과목 고르기", DoitProblemTypes.types(subject: "윤리").allSatisfy { $0.subject == "윤리" })
    check("유형 사전: 물리학 유형", DoitProblemTypes.types(subject: "물리학").count >= 30, "\(DoitProblemTypes.types(subject: "물리학").count)")
    check("유형 사전: id로 찾기", DoitProblemTypes.type(id: "ko.read.match")?.name == "내용 일치")

    // 2) 설명
    if let m = DoitProblemTypes.classify("다음 빈칸에 들어갈 말로 가장 적절한 것은?", subjectHint: "영어").first {
        let text = DoitProblemTypes.explain(m)
        check("설명: 유형 · 묻는 것 · 푸는 법", text.contains("유형 · 빈칸 추론") && text.contains("묻는 것 ·") && text.contains("푸는 법 · ①"), text)
        check("설명: 짧음 (5줄 이하)", text.components(separatedBy: "\n").count <= 5, text)
    } else {
        check("설명: 빈칸 추론 찾기", false)
    }

    // 3) 유형 분류
    for c in typeCases {
        let matches = DoitProblemTypes.classify(c.text, subjectHint: c.hint, limit: max(c.within, 1))
        let found = matches.prefix(c.within).first { m in c.expect.allSatisfy { m.type.name.contains($0) } }
        let detail = matches.map { "\($0.type.name)[\($0.type.subject)] \($0.score)" }.joined(separator: " / ")
        check("유형: \(c.text.prefix(28)) → \(c.expect.joined(separator: "+"))", found != nil, detail)
        if let subject = c.subject, let found {
            check("유형 과목: \(c.text.prefix(20)) → \(subject)", found.type.subject == subject, found.type.subject)
        }
    }
    check("유형: 아무 문제도 아닌 글은 빈 결과", DoitProblemTypes.classify("오늘 날씨가 좋다").isEmpty)
    check("유형: 빈 글", DoitProblemTypes.classify("   ").isEmpty)
    check("유형: 띄어쓰기가 틀려도", DoitProblemTypes.classify("윗 글의 내 용과 일치하지 않는것은?").first?.type.name == "내용 일치")
    check("유형: 점수 높은 순", { let m = DoitProblemTypes.classify("윗글의 표현상 특징으로 가장 적절한 것은?"); return zip(m, m.dropFirst()).allSatisfy { $0.score >= $1.score } }())
    let hinted = DoitProblemTypes.classify("다음 중 옳은 것만을 <보기>에서 있는 대로 고른 것은?", subjectHint: "생명과학").first
    check("유형: 과목 힌트 (생명과학 → 과학 유형)", hinted?.type.subject == "과학", hinted?.type.name ?? "-")
    let hintedEthics = DoitProblemTypes.classify("다음 중 옳은 것만을 <보기>에서 있는 대로 고른 것은?", subjectHint: "윤리").first
    check("유형: 과목 힌트 (윤리 → 윤리 유형)", hintedEthics?.type.subject == "윤리", hintedEthics?.type.name ?? "-")
    let blankKo = DoitProblemTypes.classify("㉠에 들어갈 말로 가장 적절한 것은?", subjectHint: "국어").first
    check("유형: 국어 빈칸은 국어 유형", blankKo?.type.subject == "국어", blankKo?.type.name ?? "-")

    // 4) 과목 판단
    for c in subjectCases {
        let guess = DoitSubjectDetector.detect(c.text)
        let ok = guess?.broad == c.broad && (c.detail == nil || guess?.detail == c.detail)
        check("과목: \(c.text.prefix(26)) → \(c.broad)\(c.detail.map { "/" + $0 } ?? "")", ok,
              guess.map { "\($0.broad)/\($0.detail ?? "-") \($0.confidence) \($0.reasons)" } ?? "nil")
    }
    for text in ambiguousTexts {
        let guess = DoitSubjectDetector.detect(text)
        check("과목: 애매하면 nil — \(text.prefix(20))", guess == nil, guess.map { "\($0.broad) \($0.confidence) \($0.reasons)" } ?? "")
    }
    if let g = DoitSubjectDetector.detect("갑, 을은 서양 사상가이다. 갑: 선의지와 정언 명령. 을: 최대 다수의 최대 행복") {
        check("과목: 근거를 알려 줌", !g.reasons.isEmpty && g.reasons.count <= 4, "\(g.reasons)")
        check("과목: 확신도 0~1", g.confidence > 0.5 && g.confidence < 1, "\(g.confidence)")
    }
    check("과목: 노트 이름 (세부 과목)", DoitSubjectDetector.detect("레오폴드의 대지 윤리와 테일러의 생명 중심주의, 싱어의 동물 해방론")?.noteLabel == "생활과 윤리")
    check("과목: 노트 이름 (수학은 큰 과목)", DoitSubjectDetector.detect("이차방정식 x² - 5x + 6 = 0 의 해를 구하시오.")?.noteLabel == "수학")
    check("과목: 수식이 많으면 수학으로 읽기", DoitSubjectDetector.looksMath("x^2 + 2x + 1 = 0, y = 3x - 2") && !DoitSubjectDetector.looksMath("다음 글을 읽고 물음에 답하시오."))
    check("과목: using·blog는 수식이 아님", !DoitSubjectDetector.looksMath("I am using my blog to share a single story about the cost of living."))

    // 5) 저장된 과목 이름 → 큰 과목
    let stored: [(String, String)] = [("", "수학"), ("수학", "수학"), ("미적분", "수학"), ("윤리", "윤리"), ("생활과 윤리", "윤리"), ("윤리와 사상", "윤리"),
                                      ("도덕", "윤리"), ("한국사", "역사"), ("세계사", "역사"), ("동아시아사", "역사"), ("한국지리", "사회"), ("정치와 법", "사회"),
                                      ("경제", "사회"), ("사회·문화", "사회"), ("물리학", "과학"), ("지구과학", "과학"), ("중학교 과학", "과학"), ("문법", "국어"),
                                      ("화법과 작문", "국어"), ("영어", "영어"), ("정보", "기타"), ("미술", "기타")]
    for (name, broad) in stored {
        check("큰 과목: '\(name)' → \(broad)", DoitSubjectDetector.broad(ofStored: name) == broad, DoitSubjectDetector.broad(ofStored: name))
    }
    check("과목 채점 방식: 윤리는 사회처럼", NoteSubject.from("윤리와 사상") == .social && NoteSubject.from("세계사") == .social && NoteSubject.from("문법") == .korean)

    // 6) 오답노트 연결 (자동 과목 · 칩 · 유형 · 예전 노트)
    var scan = DoitProblemScan.scan("윗글의 내용과 일치하지 않는 것은?", math: false)
    check("자동 과목: 예전 노트(표시 없음)는 바꾸지 않음", !DoitSubjectNote.isAutoSubject(stored: "", scan: scan))
    check("자동 과목: 예전 노트는 다시 정하지 않음", DoitSubjectNote.redetectedSubject(text: "벤담의 공리주의와 칸트의 정언 명령", stored: "", scan: scan) == nil)
    scan.autoSubject = ""
    check("자동 과목: 자동으로 정한 그대로면 다시 정함", DoitSubjectNote.redetectedSubject(text: "갑, 을은 서양 사상가이다. 칸트의 정언 명령과 벤담의 공리주의", stored: "", scan: scan) == "윤리와 사상",
          DoitSubjectNote.redetectedSubject(text: "갑, 을은 서양 사상가이다. 칸트의 정언 명령과 벤담의 공리주의", stored: "", scan: scan) ?? "nil")
    check("자동 과목: 직접 고른 과목은 그대로", DoitSubjectNote.redetectedSubject(text: "칸트의 정언 명령과 벤담의 공리주의", stored: "국어", scan: scan) == nil)
    var autoMath = DoitProblemScan.scan("x² - 9 를 인수분해하시오.")
    autoMath.autoSubject = ""
    check("자동 과목: 수학은 빈 값으로 (예전 노트와 같게)", DoitSubjectNote.redetectedSubject(text: "x² - 9 를 인수분해하시오.", stored: "", scan: autoMath) == nil)
    check("자동 과목: 모르면 기타 · 수식이면 수학", DoitSubjectNote.fallbackSubject("다음 글을 읽고 물음에 답하시오.") == "기타" && DoitSubjectNote.fallbackSubject("x + 3 = 5, y = 2x") == "")
    check("자동 과목: '수학' → 빈 값으로 저장", DoitSubjectNote.storedValue("수학") == "" && DoitSubjectNote.storedValue("윤리") == "윤리")
    let groups = DoitSubjectNote.subjectGroups(["", "수학", "윤리", "생활과 윤리", "생활과 윤리", "한국사", "영어", "미술"])
    check("과목 칩: 있는 과목만 큰 과목별로", groups.map(\.broad) == ["영어", "수학", "윤리", "역사", "기타"], "\(groups.map(\.broad))")
    check("과목 칩: 세부 과목 묶음 (많은 순)", groups.first { $0.broad == "윤리" }.map { $0.total == 3 && $0.details.first?.label == "생활과 윤리" } == true)
    check("과목 칩: 빈 값과 '수학'은 같은 칩", groups.first { $0.broad == "수학" }.map { $0.total == 2 && $0.details.count == 1 } == true)
    check("과목 이름: 빈 값은 수학", DoitSubjectNote.displayName("") == "수학" && DoitSubjectNote.displayName(" 윤리 ") == "윤리")
    check("과목 고르기: 세부 과목 목록", DoitSubjectNote.subjectOptions.first { $0.broad == "윤리" }?.details.contains("생활과 윤리") == true
          && DoitSubjectNote.subjectOptions.allSatisfy { option in option.details.allSatisfy { DoitSubjectDetector.broad(ofStored: $0) == option.broad } })
    check("과목 색: 윤리·역사 따로", DoitSubjectNote.colorHex(broad: "윤리") != DoitSubjectNote.colorHex(broad: "사회") && DoitSubjectNote.colorHex(broad: "역사") != DoitSubjectNote.colorHex(broad: "사회"))

    // 예전 노트 JSON (새 칸 없이)도 그대로 읽힘
    let old = #"{"body":"문제","formulas":[],"choices":["a","b"],"conditions":[],"table":[],"question":"?","kind":"multipleChoice","doubts":[]}"#
    let decoded = try? JSONDecoder().decode(ProblemScan.self, from: Data(old.utf8))
    check("예전 노트: 문제 나누기 결과 그대로 읽힘", decoded?.choices == ["a", "b"] && decoded?.autoSubject == nil && decoded?.typeID == nil)
    var tagged = DoitProblemScan.scan("윗글의 표현상 특징으로 가장 적절한 것은?", math: false)
    tagged.typeID = DoitProblemTypes.bestID(for: "윗글의 표현상 특징으로 가장 적절한 것은?", subject: "국어")
    let roundTrip = (try? JSONEncoder().encode(tagged)).flatMap { try? JSONDecoder().decode(ProblemScan.self, from: $0) }
    check("유형 저장: 저장 후 다시 읽어도 유형 이름", roundTrip?.problemType?.name == "표현상 특징", roundTrip?.problemType?.name ?? "-")
    let summary = DoitSubjectNote.typeSummary(DoitProblemTypes.type(id: "en.rd.blank")!)
    check("유형 칩: 묻는 것 · 푸는 법 · 함정이 짧게", !summary.asks.isEmpty && summary.steps.contains("→") && summary.trap != nil && summary.steps.count < 120, summary.steps)
    let prompt = DoitSubjectNote.explainPrompt(problem: "윗글의 표현상 특징으로 가장 적절한 것은?", choices: [], correct: "③", mine: "", subject: .korean, concepts: [],
                                               subjectName: "문학", problemType: DoitProblemTypes.type(id: "ko.lit.expression"))
    check("AI 해설: 과목 이름과 문제 유형을 알려 줌", prompt.contains("[과목] 문학") && prompt.contains("[문제 유형] 표현상 특징"), prompt)

    // 7) 속도: 긴 지문도 빨리
    let long = String(repeating: "Many people believe that success comes from talent, but research shows that persistence matters more. ", count: 20)
    let start = Date()
    _ = DoitProblemTypes.classify(long)
    _ = DoitSubjectDetector.detect(long)
    check("속도: 긴 지문 분류 0.5초 안", Date().timeIntervalSince(start) < 0.5, "\(Date().timeIntervalSince(start))")
}
