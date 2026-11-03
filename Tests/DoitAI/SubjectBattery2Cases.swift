import Foundation

// MARK: - 과목 배터리 2: 더 어려운 시험 문제 모양 (문장 선지, <보기> 항목, 두 빈칸, 음운 변동, 높임법, 시차, 반응식 …)
// - 처음 배터리와 같은 방법으로 풂 (사진 글 → DoitProblemScan → DoitSubjectSolve.solve)
// - 오답은 실패, 못 푼 것은 목록만. 함정(답이 하나로 안 정해지거나 자료로 알 수 없는 것)은 풀면 실패
// - 새 변형(subjectBattery2Fresh)은 규칙을 맞추며 보지 않은 문제: 오답 0만 확인하고 정답 수는 따로 보여 줌

let subjectBattery2: [SubjectBatteryCase] = [
    // MARK: 과학 — 역학적 에너지 보존
    SubjectBatteryCase("과학", "질량 2 kg인 물체를 높이 5 m에서 가만히 떨어뜨렸다. 지면에 닿는 순간의 속력은 몇 m/s인가? (단, 중력 가속도는 10 m/s², 공기 저항은 무시한다.)", "10 m/s"),
    SubjectBatteryCase("과학", "높이 20 m인 곳에서 공을 가만히 놓았다. 지면에 도달하기 직전 공의 속력은? (단, 중력 가속도는 10 m/s²이고 공기 저항은 무시한다.)\n① 10 m/s ② 14 m/s ③ 20 m/s ④ 40 m/s ⑤ 200 m/s", "3"),
    SubjectBatteryCase("과학", "질량 1 kg인 공을 10 m/s의 속력으로 연직 위로 던져 올렸다. 공이 올라갈 수 있는 최고 높이는 몇 m인가? (단, 중력 가속도는 10 m/s²이고 공기 저항은 무시한다.)", "5 m"),
    SubjectBatteryCase("과학", "질량 4 kg인 물체를 높이 5 m에서 떨어뜨렸을 때 지면에 닿기 직전의 운동 에너지는? (단, 공기 저항은 무시한다.)\n① 19.6 J ② 49 J ③ 98 J ④ 196 J ⑤ 392 J", "4"),
    SubjectBatteryCase("과학", "12번) 높이 45m에서 물체를 가만히 떨어뜨렸다 지면에 닿는 순간 속력은 몇 m/s 인가 (단 중력가속도 10m/s², 공기저항 무시)", "30 m/s"),
    SubjectBatteryCase("과학", "공을 20 m/s의 속력으로 연직 위로 던졌을 때 공이 올라가는 최고 높이는? (단, 중력 가속도는 10 m/s², 공기 저항은 무시한다.)\n① 2 m ② 10 m ③ 20 m ④ 40 m ⑤ 400 m", "3"),
    SubjectBatteryCase("과학", "질량 3 kg인 물체를 높이 10 m에서 자유 낙하시켰다. 지면에 닿는 순간 물체의 운동 에너지는 몇 J인가? (단, 중력 가속도는 10 m/s², 공기 저항은 무시)", "300 J"),
    // 일률 = 힘 × 속력
    SubjectBatteryCase("과학", "물체에 20 N의 힘을 작용하여 2 m/s의 일정한 속력으로 끌고 갈 때 일률은 몇 W인가?", "40 W"),
    SubjectBatteryCase("과학", "엘리베이터가 무게 5000 N인 짐을 3 m/s의 일정한 속력으로 들어 올릴 때 일률은?\n① 1500 W ② 5000 W ③ 15000 W ④ 1667 W ⑤ 5003 W", "3"),
    SubjectBatteryCase("과학", "200 N의 힘으로 수레를 0.5 m/s의 일정한 속력으로 밀 때 일률은 몇 W인가?", "100 W"),
    // 렌즈 · 거울
    SubjectBatteryCase("과학", "볼록 렌즈로 물체를 보았더니 물체의 크기가 2 cm, 상의 크기가 6 cm였다. 이 렌즈의 배율은 몇 배인가?", "3배|3"),
    SubjectBatteryCase("과학", "볼록 렌즈에서 물체까지의 거리가 10 cm, 렌즈에서 상까지의 거리가 30 cm일 때 상의 배율은?\n① 0.3배 ② 3배 ③ 20배 ④ 40배 ⑤ 300배", "2"),
    SubjectBatteryCase("과학", "빛이 평면거울에 입사각 30°로 입사할 때 반사각은 몇 °인가?", "30°|30"),
    SubjectBatteryCase("과학", "평면거울에 빛이 거울면과 60°의 각을 이루며 입사하였다. 이때 반사각은 몇 °인가?\n① 30° ② 45° ③ 60° ④ 90° ⑤ 120°", "1"),
    SubjectBatteryCase("과학", "평면거울 앞 2 m 거리에 서 있는 사람과 거울에 비친 상 사이의 거리는 몇 m인가?", "4 m"),
    // 열평형 · 비열
    SubjectBatteryCase("과학", "20 ℃의 물 200 g과 60 ℃의 물 200 g을 섞었을 때 열평형 온도는 몇 ℃인가? (단, 열은 외부로 빠져나가지 않는다.)", "40 ℃"),
    SubjectBatteryCase("과학", "80 ℃의 물 100 g에 20 ℃의 물 200 g을 섞었다. 열평형 상태에서의 온도는?\n① 30 ℃ ② 40 ℃ ③ 50 ℃ ④ 60 ℃ ⑤ 70 ℃", "2"),
    SubjectBatteryCase("과학", "비열이 0.5 J/g℃인 금속 100 g의 온도를 20 ℃ 높이는 데 필요한 열량은 몇 J인가?", "1000 J"),
    SubjectBatteryCase("과학", "어떤 물질 200 g에 4000 J의 열을 가했더니 온도가 10 ℃ 올라갔다. 이 물질의 비열은 몇 J/g℃인가?", "2 J/(g·℃)|2"),
    SubjectBatteryCase("과학", "물 500 g의 온도를 10 ℃에서 30 ℃로 높이는 데 필요한 열량은 몇 kcal인가? (단, 물의 비열은 1 kcal/kg℃이다.)", "10 kcal"),
    // 전기 회로 (직렬 · 병렬)
    SubjectBatteryCase("과학", "저항이 2 Ω, 3 Ω인 두 저항을 직렬로 연결했을 때 합성 저항은 몇 Ω인가?", "5 Ω"),
    SubjectBatteryCase("과학", "6 Ω인 저항 두 개를 병렬로 연결하였다. 합성 저항은?\n① 1 Ω ② 3 Ω ③ 6 Ω ④ 12 Ω ⑤ 36 Ω", "2"),
    SubjectBatteryCase("과학", "4 Ω과 12 Ω의 저항을 병렬 연결하였을 때 전체 저항은 몇 Ω인가?", "3 Ω"),
    SubjectBatteryCase("과학", "10 Ω과 20 Ω의 저항을 직렬로 연결하고 전원 전압 6 V를 걸었다. 회로에 흐르는 전류는 몇 A인가?", "0.2 A"),
    SubjectBatteryCase("과학", "3 Ω, 6 Ω의 저항을 병렬로 연결하고 12 V의 전압을 걸었을 때 회로 전체에 흐르는 전류는 몇 A인가?", "6 A"),
    // 질량 보존 · 화학 반응식
    SubjectBatteryCase("과학", "탄소 12 g이 산소 32 g과 완전히 반응하여 이산화 탄소가 생성되었다. 생성된 이산화 탄소의 질량은 몇 g인가?", "44 g"),
    SubjectBatteryCase("과학", "마그네슘 3 g을 완전히 연소시켰더니 산화 마그네슘 5 g이 생성되었다. 반응한 산소의 질량은 몇 g인가?", "2 g"),
    SubjectBatteryCase("과학", "수소 4 g과 산소 32 g이 완전히 반응하여 물이 생성될 때 생성된 물의 질량은?\n① 28 g ② 32 g ③ 36 g ④ 64 g ⑤ 128 g", "3"),
    SubjectBatteryCase("과학", "철 56 g과 황 32 g이 완전히 반응하여 황화 철이 생성되었다. 생성된 황화 철의 질량은 몇 g인가?", "88 g"),
    SubjectBatteryCase("과학", "다음 화학 반응식에서 a + b + c의 값은?\naH2 + bO2 → cH2O\n① 3 ② 4 ③ 5 ④ 6 ⑤ 7", "3"),
    SubjectBatteryCase("과학", "화학 반응식 N2 + aH2 → bNH3에서 a와 b에 알맞은 수를 차례대로 쓴 것은?\n① 1, 2 ② 2, 2 ③ 3, 2 ④ 3, 3 ⑤ 2, 3", "3"),
    SubjectBatteryCase("과학", "CH4 + 2O2 → CO2 + aH2O에서 a에 알맞은 수는?", "2"),
    SubjectBatteryCase("과학", "프로페인의 연소 반응식 C3H8 + aO2 → 3CO2 + 4H2O에서 a의 값은?\n① 2 ② 3 ③ 4 ④ 5 ⑤ 6", "4"),
    SubjectBatteryCase("과학", "0 ℃, 1기압에서 이산화 탄소 2 mol의 부피는 몇 L인가?", "44.8 L"),
    SubjectBatteryCase("과학", "산소 기체(O2) 64 g은 몇 mol인가? (단, O의 원자량은 16이다.)", "2 mol"),
    // 과학 문장 선지 (옳은 것 · 옳지 않은 것)
    SubjectBatteryCase("과학", "다음 중 광합성에 대한 설명으로 옳은 것은?\n① 뿌리에서 주로 일어난다.\n② 산소를 흡수한다.\n③ 엽록체에서 일어난다.\n④ 밤에만 일어난다.\n⑤ 포도당을 분해한다.", "3"),
    SubjectBatteryCase("과학", "세포 호흡에 대한 설명으로 옳지 않은 것은?\n① 미토콘드리아에서 일어난다.\n② 산소가 사용된다.\n③ 이산화 탄소가 발생한다.\n④ 생명 활동에 필요한 에너지를 얻는다.\n⑤ 빛이 있을 때만 일어난다.", "5"),
    SubjectBatteryCase("과학", "7. 지구형 행성의 특징으로 옳은 것은? ① 고리가 있다 ② 위성이 많다 ③ 표면이 단단한 암석으로 되어 있다 ④ 질량이 크다 ⑤ 평균 밀도가 작다", "3"),
    SubjectBatteryCase("과학", "목성형 행성의 특징으로 옳지 않은 것은?\n① 고리가 있다.\n② 위성 수가 많다.\n③ 반지름이 크다.\n④ 평균 밀도가 크다.\n⑤ 주로 기체로 이루어져 있다.", "4"),
    SubjectBatteryCase("과학", "다음 중 화산암에 대한 설명으로 옳은 것은?\n① 지하 깊은 곳에서 천천히 식어서 만들어졌다.\n② 광물 결정의 크기가 크다.\n③ 지표 근처에서 빠르게 식어서 만들어졌다.\n④ 화강암이 대표적이다.\n⑤ 퇴적물이 쌓이고 굳어서 만들어졌다.", "3"),
    SubjectBatteryCase("과학", "적혈구에 대한 설명으로 옳은 것은?\n① 핵이 있다.\n② 식균 작용을 한다.\n③ 혈액 응고에 관여한다.\n④ 헤모글로빈이 있어 산소를 운반한다.\n⑤ 혈구 중 크기가 가장 크다.", "4"),
    SubjectBatteryCase("과학", "다음 중 백혈구에 대한 설명으로 옳은 것은?\n① 산소를 운반한다.\n② 식균 작용을 한다.\n③ 혈액을 응고시킨다.\n④ 헤모글로빈이 있다.\n⑤ 혈구 중 수가 가장 많다.", "2"),
    SubjectBatteryCase("과학", "산성 용액의 공통적인 성질로 옳은 것은?\n① 붉은색 리트머스 종이를 푸르게 변화시킨다.\n② 페놀프탈레인 용액을 붉게 변화시킨다.\n③ 마그네슘과 반응하여 수소 기체를 발생시킨다.\n④ 단백질을 녹인다.\n⑤ 쓴맛이 난다.", "3"),
    SubjectBatteryCase("과학", "염기성 용액의 성질로 옳지 않은 것은?\n① 붉은색 리트머스 종이를 푸르게 변화시킨다.\n② 페놀프탈레인 용액을 붉게 변화시킨다.\n③ 단백질을 녹인다.\n④ 쓴맛이 난다.\n⑤ 금속과 반응하여 수소 기체를 발생시킨다.", "5"),
    SubjectBatteryCase("과학", "다음 중 대류권에 대한 설명으로 옳은 것은?\n① 오존층이 있다.\n② 높이 올라갈수록 기온이 낮아진다.\n③ 오로라가 나타난다.\n④ 공기가 거의 없다.\n⑤ 기상 현상이 나타나지 않는다.", "2"),
    SubjectBatteryCase("과학", "성층권의 특징으로 옳은 것은?\n① 기상 현상이 나타난다.\n② 높이 올라갈수록 기온이 높아진다.\n③ 대류가 활발하다.\n④ 오로라가 나타난다.\n⑤ 수증기가 가장 많다.", "2"),
    // 생활 속 현상 → 상태 변화 · 물리/화학 변화
    SubjectBatteryCase("과학", "다음 중 기화에 해당하는 현상은?\n① 얼음이 녹는다.\n② 젖은 빨래가 마른다.\n③ 이슬이 맺힌다.\n④ 물이 언다.\n⑤ 드라이아이스가 작아진다.", "2"),
    SubjectBatteryCase("과학", "열을 방출하는 상태 변화의 예로 옳은 것은?\n① 얼음이 녹는다.\n② 젖은 빨래가 마른다.\n③ 촛농이 굳는다.\n④ 드라이아이스가 작아진다.\n⑤ 아이스크림이 녹는다.", "3"),
    SubjectBatteryCase("과학", "다음 중 화학 변화인 것은?\n① 얼음이 녹는다.\n② 종이가 탄다.\n③ 설탕이 물에 녹는다.\n④ 유리컵이 깨진다.\n⑤ 물이 끓는다.", "2"),
    SubjectBatteryCase("과학", "물리 변화에 해당하지 않는 것은? ① 물이 증발한다 ② 철이 녹슨다 ③ 고무줄이 늘어난다 ④ 각설탕이 부서진다 ⑤ 잉크가 물에 퍼진다", "2"),
    // 분류
    SubjectBatteryCase("과학", "다음 중 변온 동물인 것은?\n① 개 ② 참새 ③ 뱀 ④ 고래 ⑤ 사람", "3"),
    SubjectBatteryCase("과학", "다음 중 외떡잎식물인 것은?\n① 벼 ② 콩 ③ 해바라기 ④ 봉숭아 ⑤ 무궁화", "1"),
    SubjectBatteryCase("과학", "쌍떡잎식물에 해당하지 않는 것은?\n① 강낭콩 ② 옥수수 ③ 봉숭아 ④ 장미 ⑤ 해바라기", "2"),
    SubjectBatteryCase("과학", "생태계에서 생산자에 해당하는 것은?\n① 토끼 ② 버섯 ③ 벼 ④ 매 ⑤ 곰팡이", "3"),
    SubjectBatteryCase("과학", "분해자에 해당하는 생물을 <보기>에서 모두 고른 것은?\n<보기>\nㄱ. 곰팡이 ㄴ. 세균 ㄷ. 토끼 ㄹ. 소나무\n① ㄱ ② ㄱ, ㄴ ③ ㄴ, ㄷ ④ ㄷ, ㄹ ⑤ ㄱ, ㄴ, ㄹ", "2"),
    SubjectBatteryCase("과학", "다음 중 전기가 잘 통하는 물질은?\n① 유리 ② 고무 ③ 구리 ④ 나무 ⑤ 플라스틱", "3"),
    SubjectBatteryCase("과학", "다음 중 부도체인 것은? ① 철 ② 알루미늄 ③ 은 ④ 고무 ⑤ 구리", "4"),
    SubjectBatteryCase("과학", "<보기>에서 광합성에 필요한 물질만을 있는 대로 고른 것은?\n<보기>\nㄱ. 이산화 탄소 ㄴ. 산소 ㄷ. 물 ㄹ. 포도당\n① ㄱ ② ㄱ, ㄷ ③ ㄴ, ㄹ ④ ㄱ, ㄴ, ㄷ ⑤ ㄱ, ㄷ, ㄹ", "2"),
    // 과학 사실
    SubjectBatteryCase("과학", "빛이 서로 다른 물질의 경계에서 꺾여 나아가는 현상은?\n① 반사 ② 굴절 ③ 분산 ④ 산란 ⑤ 간섭", "2"),
    SubjectBatteryCase("과학", "빛이 물체에 부딪혀 되돌아 나오는 현상을 무엇이라고 하는가?", "반사"),
    SubjectBatteryCase("과학", "혈액 속에서 영양소와 노폐물, 이산화 탄소를 운반하는 액체 성분은?\n① 적혈구 ② 백혈구 ③ 혈소판 ④ 혈장 ⑤ 헤모글로빈", "4"),
    SubjectBatteryCase("과학", "혈액 속의 노폐물을 걸러 오줌을 만드는 배설 기관은?", "콩팥|신장"),
    SubjectBatteryCase("과학", "달이 지구의 그림자에 가려지는 현상은?\n① 일식 ② 월식 ③ 개기 일식 ④ 보름달 ⑤ 상현달", "2"),
    SubjectBatteryCase("과학", "지구 내부 구조 중 가장 안쪽에 있으며 고체 상태로 추정되는 층은?", "내핵"),
    SubjectBatteryCase("과학", "판과 판이 서로 멀어지는 경계에서 만들어지는 해저 지형은?\n① 해구 ② 해령 ③ 습곡 산맥 ④ 대륙붕 ⑤ 호상 열도", "2"),
    SubjectBatteryCase("과학", "생물의 형질을 결정하는 유전 정보가 저장된 DNA의 특정 부분을 무엇이라고 하는가?", "유전자"),
    SubjectBatteryCase("과학", "물질을 이루는 기본 성분으로 더 이상 다른 물질로 분해되지 않는 것은?", "원소"),
    SubjectBatteryCase("과학", "혈관 중 심장에서 나가는 혈액이 흐르는 혈관은?\n① 정맥 ② 동맥 ③ 모세 혈관 ④ 림프관 ⑤ 대정맥", "2"),
    SubjectBatteryCase("과학", "식물의 잎 뒷면에 많이 있으며 기체가 드나드는 구멍은?\n① 기공 ② 물관 ③ 체관 ④ 뿌리털 ⑤ 엽록체", "1"),

    // MARK: 영어 — 어법상 어색한 문장 · 바른 문장 (문장 선지)
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① She plays the piano every day.\n② They was at home yesterday.\n③ I have lived here since 2015.\n④ He went to the park last Sunday.\n⑤ We are watching TV now.", "2"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 것은?\n① I enjoy swimming in the sea.\n② She wants to be a doctor.\n③ He finished to read the book.\n④ They decided to stay home.\n⑤ We hope to see you again.", "3"),
    SubjectBatteryCase("영어", "15) 어법상 틀린 문장은? ① He can speaks English well. ② She is taller than her sister. ③ I was born in 2010. ④ They are my friends. ⑤ Tom likes apples.", "1"),
    SubjectBatteryCase("영어", "다음 중 어법상 옳은 문장은?\n① He don't like milk.\n② She have a cat.\n③ I has two brothers.\n④ They goes to school by bus.\n⑤ My father reads a newspaper every morning.", "5"),
    SubjectBatteryCase("영어", "다음 중 어법상 바르지 않은 문장은?\n① This is the book which I bought yesterday.\n② The boy who is singing is my brother.\n③ I know the girl which lives next door.\n④ The dog that is running is mine.\n⑤ She is the teacher who teaches us English.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① The window was broken by Tom.\n② This letter was wrote by my mother.\n③ The song is loved by many people.\n④ The house was built in 1990.\n⑤ English is spoken in many countries.", "2"),
    SubjectBatteryCase("영어", "어법상 어색한 문장을 고르시오.\n① She is more taller than me.\n② This is the best movie of the year.\n③ He runs faster than his brother.\n④ My bag is heavier than yours.\n⑤ It is the most beautiful flower in the garden.", "1"),
    SubjectBatteryCase("영어", "다음 중 어법상 틀린 것은?\n① Did you finish your homework?\n② Does she like music?\n③ Did he went to the library?\n④ Do they play soccer?\n⑤ Does your brother have a bike?", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① I have seen the movie yesterday.\n② She has lived in Busan for five years.\n③ He has just finished his work.\n④ We have known each other since 2018.\n⑤ They have never been to Japan.", "1"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① She told me that she was tired.\n② He said that he was hungry.\n③ They told that the store was closed.\n④ I said to him that I was busy.\n⑤ My mom told me to clean my room.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① There are many books on the desk.\n② There is a cat under the table.\n③ There is three apples in the box.\n④ There are two pens in my bag.\n⑤ There was a big tree in the park.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① I bought an umbrella.\n② She is an honest girl.\n③ He ate a apple.\n④ It is a useful book.\n⑤ We waited for an hour.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① My mom made me clean my room.\n② She let me use her phone.\n③ He made me to wait for an hour.\n④ I had my brother fix the computer.\n⑤ They helped me carry the box.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① I am looking forward to seeing you.\n② She gave up smoking.\n③ He avoided answering the question.\n④ We are looking forward to see you.\n⑤ They kept talking.", "4"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① Every student has a locker.\n② Each of the students has a book.\n③ One of my friends lives in Seoul.\n④ Every student are happy.\n⑤ Everyone likes him.", "4"),
    SubjectBatteryCase("영어", "다음 중 어법상 옳은 문장은?\n① She don't know the answer.\n② He didn't went to school.\n③ They was very busy.\n④ I am not a student.\n⑤ We is good friends.", "4"),
    // 영어 — 보기 항목 (a)~e) · ㄱ~ㄹ) 어법 판단
    SubjectBatteryCase("영어", "23번) 다음 중 어법상 바른 것끼리 묶인 것은?\na) Two dollars is enough for the ticket.\nb) He said that practice makes perfect.\nc) She told that she was tired.\nd) I have lived here since 2010.\ne) If I were you, I will go there.\n① a, b ② a, c ③ b, c ④ c, e ⑤ d, e", "1"),
    SubjectBatteryCase("영어", "다음 중 어법상 옳은 것을 모두 고른 것은?\na) She can sings well.\nb) He enjoys playing tennis.\nc) They was late yesterday.\nd) I want to go home.\n① a, b ② a, c ③ b, c ④ b, d ⑤ c, d", "4"),
    SubjectBatteryCase("영어", "어법상 어색한 것끼리 짝지어진 것은?\na) Look! The baby is sleeping.\nb) He goes to school yesterday.\nc) My sister doesn't likes carrots.\nd) We visited the museum last week.\n① a, b ② a, c ③ b, c ④ b, d ⑤ c, d", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 바른 것만을 <보기>에서 있는 대로 고른 것은?\n<보기>\nㄱ. He is the tallest boy in my class.\nㄴ. She is more smarter than her brother.\nㄷ. I have been to Paris twice.\nㄹ. They didn't came to the party.\n① ㄱ, ㄴ ② ㄱ, ㄷ ③ ㄴ, ㄹ ④ ㄱ, ㄷ, ㄹ ⑤ ㄴ, ㄷ, ㄹ", "2"),
    SubjectBatteryCase("영어", "다음 중 어법상 틀린 것을 모두 고르면?\n(A) The book was written by him.\n(B) The cake was ate by my brother.\n(C) She finished doing her homework.\n(D) I decided going abroad.\n① (A), (B) ② (A), (C) ③ (B), (C) ④ (B), (D) ⑤ (C), (D)", "4"),
    SubjectBatteryCase("영어", "다음 중 어법상 옳은 것끼리 바르게 묶은 것은?\na) There is many people in the room.\nb) He has two children.\nc) I have three book.\nd) She is an honest woman.\n① a, b ② a, c ③ b, c ④ b, d ⑤ c, d", "4"),
    // 영어 — 두 빈칸 (A), (B)
    SubjectBatteryCase("영어", "다음 빈칸 (A), (B)에 들어갈 말로 알맞게 짝지어진 것은?\nI have a friend (A) lives in Canada.\nThis is the bag (B) I bought yesterday.\n① who - which ② which - who ③ whose - which ④ who - whose ⑤ which - whose", "1"),
    SubjectBatteryCase("영어", "(A), (B)에 알맞은 말이 바르게 짝지어진 것은?\nShe enjoys (A) pictures.\nHe wants (B) a pilot.\n① draw - be ② drawing - to be ③ to draw - being ④ drawing - being ⑤ to draw - to be", "2"),
    SubjectBatteryCase("영어", "빈칸 (A)와 (B)에 들어갈 말로 가장 알맞은 것은?\nMy brother (A) soccer every Sunday.\nThey (B) to the zoo last weekend.\n① play - go ② plays - went ③ played - go ④ plays - go ⑤ play - went", "2"),
    SubjectBatteryCase("영어", "다음 (A), (B)에 들어갈 말로 알맞은 것은?\nThis box is (A) than that one.\nShe is the (B) girl in our school.\n① heavy - tall ② heavier - taller ③ heavier - tallest ④ heaviest - tallest ⑤ heavy - tallest", "3"),
    SubjectBatteryCase("영어", "(A), (B)에 들어갈 말이 바르게 짝지어진 것은?\nThe picture was painted (A) Picasso.\nI will (B) you tomorrow.\n① by - call ② by - calls ③ in - called ④ with - call ⑤ at - calling", "1"),
    // 영어 — 빈칸 (새 단서: since, 가정법, 금액, every, 수일치)
    SubjectBatteryCase("영어", "다음 빈칸에 들어갈 말로 알맞은 것은?\nI ______ in Seoul since 2010.\n① live ② lived ③ have lived ④ am living ⑤ will live", "3"),
    SubjectBatteryCase("영어", "If I ______ a bird, I would fly to you.\n① am ② is ③ were ④ be ⑤ been", "3"),
    SubjectBatteryCase("영어", "Two dollars ______ enough for a bottle of water.\n① is ② are ③ be ④ were ⑤ being", "1"),
    SubjectBatteryCase("영어", "Every student ______ a uniform at our school.\n① wear ② wears ③ wearing ④ to wear", "2"),
    SubjectBatteryCase("영어", "21. 빈칸에 알맞은 것은? She ______ a doctor since she was 25. ① is ② was ③ has been ④ be ⑤ being", "3"),
    SubjectBatteryCase("영어", "Each of the students ______ a computer.\n① have ② has ③ having ④ to have", "2"),
    SubjectBatteryCase("영어", "My sister and I ______ good friends.\n① am ② is ③ are ④ be ⑤ being", "3"),
    SubjectBatteryCase("영어", "I am looking forward to ______ you soon.\n① see ② saw ③ seeing ④ seen ⑤ sees", "3"),
    SubjectBatteryCase("영어", "My mom made me ______ the dishes.\n① wash ② to wash ③ washing ④ washed ⑤ washes", "1"),
    SubjectBatteryCase("영어", "He ______ his homework already.\n① finish ② finishes ③ has finished ④ finishing ⑤ to finish", "3"),
    SubjectBatteryCase("영어", "Ten minutes ______ not a long time.\n① is ② are ③ were ④ be", "1"),
    SubjectBatteryCase("영어", "She is as ______ as her mother.\n① tall ② taller ③ tallest ④ the tallest ⑤ more tall", "1"),
    SubjectBatteryCase("영어", "Mt. Everest is ______ mountain in the world.\n① high ② higher ③ the highest ④ highest than ⑤ more high", "3"),
    SubjectBatteryCase("영어", "Would you mind ______ the window?\n① open ② to open ③ opening ④ opened ⑤ opens", "3"),
    SubjectBatteryCase("영어", "They ______ to the movies tomorrow.\n① go ② went ③ will go ④ gone ⑤ goes", "3"),
    // 영어 — 단어
    SubjectBatteryCase("영어", "다음 영어 단어의 뜻으로 알맞은 것은?\nborrow\n① 빌려주다 ② 빌리다 ③ 갚다 ④ 사다 ⑤ 팔다", "2"),
    SubjectBatteryCase("영어", "'정직한'을 뜻하는 영어 단어는?\n① kind ② brave ③ honest ④ lazy ⑤ quiet", "3"),
    SubjectBatteryCase("영어", "다음 중 단어와 뜻의 연결이 옳지 않은 것은?\n① apple - 사과 ② library - 도서관 ③ river - 강 ④ hospital - 학교 ⑤ window - 창문", "4"),

    // MARK: 사회 — 시차 · 경도
    SubjectBatteryCase("사회", "동경 135°를 표준 경선으로 쓰는 서울과 경도 0°인 런던의 시차는 몇 시간인가?", "9시간|9"),
    SubjectBatteryCase("사회", "서울(동경 135°)이 오후 3시일 때 런던(0°)은 몇 시인가?\n① 오전 3시 ② 오전 6시 ③ 오후 6시 ④ 자정 ⑤ 오후 12시", "2"),
    SubjectBatteryCase("사회", "동경 120°인 지역과 서경 30°인 지역의 시차는 몇 시간인가?", "10시간|10"),
    SubjectBatteryCase("사회", "동경 135°인 지역이 1월 1일 오전 9시일 때, 동경 75°인 지역은 몇 시인가?\n① 오전 3시 ② 오전 5시 ③ 오전 9시 ④ 오후 1시 ⑤ 오후 3시", "2"),
    // 사회 — 국가 기관 권한
    SubjectBatteryCase("사회", "다음 중 국회의 권한이 아닌 것은?\n① 법률 제정 ② 예산안 심의·확정 ③ 국정 감사 ④ 위헌 법률 심판 ⑤ 탄핵 소추", "4"),
    SubjectBatteryCase("사회", "헌법 재판소의 권한으로 옳은 것은?\n① 법률 제정 ② 탄핵 심판 ③ 예산안 심의 ④ 국정 감사 ⑤ 조약 체결", "2"),
    SubjectBatteryCase("사회", "다음 중 대통령의 권한에 해당하는 것은?\n① 국정 조사 ② 정당 해산 심판 ③ 국군 통수 ④ 법률 제정 ⑤ 명령·규칙 심사", "3"),
    SubjectBatteryCase("사회", "<보기>에서 국회의 권한만을 있는 대로 고른 것은?\n<보기>\nㄱ. 국정 감사 ㄴ. 탄핵 심판 ㄷ. 예산안 의결 ㄹ. 법률안 거부권\n① ㄱ, ㄴ ② ㄱ, ㄷ ③ ㄴ, ㄷ ④ ㄴ, ㄹ ⑤ ㄱ, ㄷ, ㄹ", "2"),
    SubjectBatteryCase("사회", "다음 중 헌법 재판소의 권한이 아닌 것은?\n① 위헌 법률 심판 ② 탄핵 심판 ③ 정당 해산 심판 ④ 권한 쟁의 심판 ⑤ 국정 감사", "5"),
    // 사회 — 역사: 시대 · 인물 연결
    SubjectBatteryCase("사회", "다음 중 고려 시대에 일어난 사건은?\n① 살수 대첩 ② 귀주 대첩 ③ 임진왜란 ④ 병자호란 ⑤ 3·1 운동", "2"),
    SubjectBatteryCase("사회", "다음 중 조선 시대에 일어난 사건이 아닌 것은?\n① 임진왜란 ② 병자호란 ③ 갑신정변 ④ 무신 정변 ⑤ 훈민정음 창제", "4"),
    SubjectBatteryCase("사회", "다음 인물과 관련된 사건의 연결이 옳지 않은 것은?\n① 을지문덕 - 살수 대첩\n② 강감찬 - 귀주 대첩\n③ 이순신 - 한산도 대첩\n④ 권율 - 행주 대첩\n⑤ 왕건 - 위화도 회군", "5"),
    SubjectBatteryCase("사회", "다음 중 삼국 시대의 사건으로 옳은 것은?\n① 귀주 대첩 ② 살수 대첩 ③ 행주 대첩 ④ 병인양요 ⑤ 무신 정변", "2"),
    SubjectBatteryCase("사회", "일제 강점기에 일어난 사건이 아닌 것은?\n① 3·1 운동 ② 청산리 대첩 ③ 광주 학생 항일 운동 ④ 6·10 만세 운동 ⑤ 동학 농민 운동", "5"),
    SubjectBatteryCase("사회", "다음 사건을 일어난 순서대로 할 때 가장 먼저 일어난 것은?\n① 임진왜란 ② 병자호란 ③ 귀주 대첩 ④ 살수 대첩 ⑤ 위화도 회군", "4"),
    SubjectBatteryCase("사회", "고려를 세운 인물은?\n① 이성계 ② 왕건 ③ 궁예 ④ 견훤 ⑤ 김춘추", "2"),
    // 사회 — 경제 개념
    SubjectBatteryCase("사회", "다음 중 대체재 관계인 것끼리 짝지은 것은?\n① 커피 - 설탕 ② 펜 - 잉크 ③ 쌀 - 밀가루 ④ 자동차 - 휘발유 ⑤ 컴퓨터 - 마우스", "3"),
    SubjectBatteryCase("사회", "보완재 관계에 있는 재화로 짝지어진 것은?\n① 버터 - 마가린 ② 콜라 - 사이다 ③ 연필 - 샤프 ④ 자동차 - 휘발유 ⑤ 쌀 - 밀가루", "4"),
    SubjectBatteryCase("사회", "한 나라 안에서 일정 기간 동안 새롭게 생산된 최종 생산물의 시장 가치를 모두 합한 것은?\n① 국민 총소득 ② 국내 총생산 ③ 1인당 국민 소득 ④ 물가 지수 ⑤ 경제 성장률", "2"),
    SubjectBatteryCase("사회", "눈에 보이지 않지만 사람에게 만족을 주는 인간의 활동을 무엇이라고 하는가?\n① 재화 ② 서비스 ③ 자원 ④ 생산 ⑤ 소비", "2"),
    SubjectBatteryCase("사회", "다른 조건이 일정할 때 어떤 상품의 수요가 증가하면 균형 가격은 어떻게 변하는가?\n① 상승한다 ② 하락한다 ③ 변하지 않는다", "1"),
    SubjectBatteryCase("사회", "다른 조건이 일정할 때 공급이 증가하면 균형 가격과 균형 거래량의 변화로 옳은 것은?\n① 가격 상승, 거래량 증가 ② 가격 하락, 거래량 증가 ③ 가격 상승, 거래량 감소 ④ 가격 하락, 거래량 감소 ⑤ 변화 없음", "2"),
    SubjectBatteryCase("사회", "물가가 지속적으로 오르면 화폐의 가치는 어떻게 되는가?\n① 오른다 ② 떨어진다 ③ 변하지 않는다", "2"),
    SubjectBatteryCase("사회", "다음 중 생산 요소에 해당하지 않는 것은?\n① 토지 ② 노동 ③ 자본 ④ 소비 ⑤ 기업가 정신", "4"),
    // 사회 — 지리 · 기후
    SubjectBatteryCase("사회", "적도 부근에 나타나며 일 년 내내 기온이 높고 강수량이 많은 기후는?\n① 열대 우림 기후 ② 사막 기후 ③ 툰드라 기후 ④ 지중해성 기후 ⑤ 서안 해양성 기후", "1"),
    SubjectBatteryCase("사회", "위도가 높아질수록 기온은 대체로 어떻게 변하는가?\n① 높아진다 ② 낮아진다 ③ 변하지 않는다", "2"),
    SubjectBatteryCase("사회", "북반구가 여름일 때 남반구의 계절은?\n① 봄 ② 여름 ③ 가을 ④ 겨울", "4"),
    SubjectBatteryCase("사회", "세계에서 가장 넓은 대양은?\n① 대서양 ② 인도양 ③ 태평양 ④ 북극해 ⑤ 남극해", "3"),
    SubjectBatteryCase("사회", "세계에서 면적이 가장 넓은 대륙은?\n① 아프리카 ② 아시아 ③ 유럽 ④ 남아메리카 ⑤ 오세아니아", "2"),
    SubjectBatteryCase("사회", "경도 0°인 본초 자오선이 지나는 도시는?\n① 파리 ② 런던 ③ 뉴욕 ④ 베를린 ⑤ 로마", "2"),
    SubjectBatteryCase("사회", "사막 한가운데에서 물을 얻을 수 있어 사람들이 모여 사는 곳을 무엇이라 하는가?", "오아시스"),
    SubjectBatteryCase("사회", "여름철 덥고 건조하며 겨울철 온화하고 비가 많이 내리는 기후는?\n① 열대 우림 기후 ② 지중해성 기후 ③ 서안 해양성 기후 ④ 툰드라 기후 ⑤ 스텝 기후", "2"),
    SubjectBatteryCase("사회", "다음 중 남반구에 있는 나라는?\n① 캐나다 ② 일본 ③ 오스트레일리아 ④ 영국 ⑤ 이집트", "3"),
    // 사회 — 정치 · 법
    SubjectBatteryCase("사회", "선거권을 가진 사람이 대리인을 거치지 않고 직접 투표하는 선거의 원칙은?\n① 보통 선거 ② 평등 선거 ③ 직접 선거 ④ 비밀 선거 ⑤ 자유 선거", "3"),
    SubjectBatteryCase("사회", "다음 중 사회권에 해당하지 않는 것은?\n① 교육을 받을 권리 ② 근로의 권리 ③ 환경권 ④ 선거권 ⑤ 인간다운 생활을 할 권리", "4"),
    SubjectBatteryCase("사회", "다른 기본권을 보장하기 위한 수단이 되는 권리로, 재판 청구권·청원권 등이 속하는 기본권은?\n① 자유권 ② 평등권 ③ 참정권 ④ 사회권 ⑤ 청구권", "5"),
    SubjectBatteryCase("사회", "국가 권력을 입법권, 행정권, 사법권으로 나누어 서로 견제하게 하는 원리는?", "권력 분립|삼권 분립|권력분립|삼권분립"),
    SubjectBatteryCase("사회", "다음 중 직접세에 해당하는 것은?\n① 부가 가치세 ② 개별 소비세 ③ 소득세 ④ 주세 ⑤ 관세", "3"),
    SubjectBatteryCase("사회", "우리나라 헌법상 국회의원의 임기는?\n① 2년 ② 4년 ③ 5년 ④ 6년 ⑤ 10년", "2"),
    SubjectBatteryCase("사회", "우리나라 대통령의 임기는?\n① 4년 ② 5년 ③ 6년 ④ 7년", "2"),
    SubjectBatteryCase("사회", "다음 중 아시아에 있는 나라가 아닌 것은?\n① 베트남 ② 태국 ③ 몽골 ④ 페루 ⑤ 인도", "4"),
    SubjectBatteryCase("사회", "다음 중 나라와 수도의 연결이 옳지 않은 것은?\n① 프랑스 - 파리 ② 일본 - 도쿄 ③ 중국 - 베이징 ④ 오스트레일리아 - 시드니 ⑤ 이집트 - 카이로", "4"),

    // MARK: 국어 — 맞춤법 · 띄어쓰기
    SubjectBatteryCase("국어", "다음 중 맞춤법에 맞게 쓴 것은?\n① 찌게 ② 베개 ③ 육계장 ④ 휴계실 ⑤ 계시판", "2"),
    SubjectBatteryCase("국어", "밑줄 친 부분의 맞춤법이 바른 것은?\n① 문을 잠궜다.\n② 김치를 담궜다.\n③ 대가를 치뤘다.\n④ 문을 잠갔다.\n⑤ 시험을 치뤘다.", "4"),
    SubjectBatteryCase("국어", "다음 중 표준어가 아닌 것은?\n① 떡볶이 ② 깍두기 ③ 머릿말 ④ 눈곱 ⑤ 오뚝이", "3"),
    SubjectBatteryCase("국어", "다음 중 맞춤법이 틀린 것은?\n① 희로애락 ② 구레나룻 ③ 앳된 얼굴 ④ 짓궂다 ⑤ 통채로", "5"),
    SubjectBatteryCase("국어", "다음 중 띄어쓰기가 바른 문장은?\n① 나도 할수 있다.\n② 그 일은 할 수 있다.\n③ 먹을것이 많다.\n④ 학교 에 간다.\n⑤ 갈수록 어렵다고 할수도 있다.", "2"),
    SubjectBatteryCase("국어", "맞춤법에 맞는 것은? ① 깡총깡총 ② 우뢰 ③ 나뭇군 ④ 깡충깡충 ⑤ 햇님", "4"),
    SubjectBatteryCase("국어", "다음 중 바르게 쓴 것은?\n① 생각컨대 ② 익숙치 않다 ③ 서슴지 않고 ④ 넉넉치 않다 ⑤ 섭섭치 않게", "3"),
    SubjectBatteryCase("국어", "다음 문장 중 맞춤법이 틀린 것은?\n① 오랜만에 친구를 만났다.\n② 며칠 동안 비가 왔다.\n③ 금세 끝났다.\n④ 웬일로 일찍 왔니?\n⑤ 설겆이를 했다.", "5"),
    // 국어 — 음운 변동
    SubjectBatteryCase("국어", "다음 중 비음화가 일어나는 단어는?\n① 국물 ② 신라 ③ 같이 ④ 국밥 ⑤ 좋고", "1"),
    SubjectBatteryCase("국어", "유음화가 일어나는 단어로 알맞은 것은?\n① 밥물 ② 칼날 ③ 굳이 ④ 놓다 ⑤ 먹고", "2"),
    SubjectBatteryCase("국어", "다음 중 구개음화가 일어나는 것은?\n① 국민 ② 난로 ③ 해돋이 ④ 입학 ⑤ 잡다", "3"),
    SubjectBatteryCase("국어", "거센소리되기(자음 축약)가 일어나는 단어는?\n① 축하 ② 맏이 ③ 신라 ④ 박물관 ⑤ 국수", "1"),
    SubjectBatteryCase("국어", "다음 중 된소리되기가 일어나는 단어는?\n① 국밥 ② 닫는 ③ 설날 ④ 좋다 ⑤ 밭이", "1"),
    SubjectBatteryCase("국어", "다음 중 표준 발음이 바르게 표기된 것은?\n① 국물[국물] ② 신라[신나] ③ 같이[가치] ④ 입학[입학] ⑤ 밥물[밥물]", "3"),
    SubjectBatteryCase("국어", "다음 단어 중 일어나는 음운 변동의 종류가 나머지와 다른 하나는?\n① 국물 ② 밥물 ③ 닫는 ④ 칼날 ⑤ 앞니", "4"),
    SubjectBatteryCase("국어", "13번) 다음 중 비음화가 일어나지 않는 단어는? ① 먹는 ② 겉멋 ③ 잡념 ④ 굳이 ⑤ 국민", "4"),
    SubjectBatteryCase("국어", "다음 중 발음이 바르지 않은 것은?\n① 해돋이[해도지] ② 국민[궁민] ③ 칼날[칼랄] ④ 축하[추카] ⑤ 밥물[밥물]", "5"),
    // 국어 — 높임법
    SubjectBatteryCase("국어", "다음 중 객체 높임법이 쓰인 문장은?\n① 할머니께서 주무신다.\n② 나는 선생님께 책을 드렸다.\n③ 아버지께서 신문을 읽으신다.\n④ 동생이 밥을 먹는다.\n⑤ 친구가 학교에 갔다.", "2"),
    SubjectBatteryCase("국어", "주체 높임법이 쓰인 문장은?\n① 동생이 밥을 먹는다.\n② 나는 할머니를 모시고 병원에 갔다.\n③ 선생님께서 교실에 들어오셨다.\n④ 친구에게 책을 주었다.\n⑤ 형이 축구를 한다.", "3"),
    SubjectBatteryCase("국어", "다음 중 객체 높임의 특수 어휘가 쓰인 문장이 아닌 것은?\n① 할아버지를 모시고 갔다.\n② 선생님께 여쭈어 보았다.\n③ 어머니께 선물을 드렸다.\n④ 선생님을 뵈었다.\n⑤ 동생에게 책을 주었다.", "5"),
    // 국어 — 품사
    SubjectBatteryCase("국어", "다음 중 관형사인 것은?\n① 매우 ② 새 ③ 아이고 ④ 하나 ⑤ 우리", "2"),
    SubjectBatteryCase("국어", "다음 중 품사가 나머지와 다른 하나는?\n① 매우 ② 아주 ③ 빨리 ④ 너무 ⑤ 헌", "5"),
    SubjectBatteryCase("국어", "감탄사에 해당하는 것은?\n① 매우 ② 아이고 ③ 모든 ④ 우리 ⑤ 가장", "2"),
    SubjectBatteryCase("국어", "다음 중 대명사가 아닌 것은?\n① 나 ② 너 ③ 우리 ④ 무엇 ⑤ 여러", "5"),
    // 국어 — 문학 용어 · 표현법
    SubjectBatteryCase("국어", "시에서 시인을 대신하여 시 속에서 말하는 이를 무엇이라고 하는가?\n① 화자 ② 청자 ③ 서술자 ④ 작가 ⑤ 독자", "1"),
    SubjectBatteryCase("국어", "'~처럼', '~같이', '~듯이' 등의 말을 써서 두 대상을 직접 빗대어 표현하는 방법은?\n① 은유법 ② 직유법 ③ 의인법 ④ 과장법 ⑤ 반어법", "2"),
    SubjectBatteryCase("국어", "사람이 아닌 대상을 사람처럼 생각하고 행동하는 것처럼 표현하는 방법은?\n① 직유법 ② 은유법 ③ 의인법 ④ 대구법 ⑤ 설의법", "3"),
    SubjectBatteryCase("국어", "'A는 B이다'처럼 연결어 없이 원관념을 보조 관념에 빗대는 표현법은?\n① 직유법 ② 은유법 ③ 의인법 ④ 반복법 ⑤ 영탄법", "2"),
    SubjectBatteryCase("국어", "소설에서 이야기를 전달하는 사람을 무엇이라고 하는가?\n① 화자 ② 서술자 ③ 주인공 ④ 작가 ⑤ 청자", "2"),
    SubjectBatteryCase("국어", "겉으로 표현한 내용과 속뜻을 반대로 나타내는 표현 방법은?\n① 역설법 ② 반어법 ③ 직유법 ④ 과장법 ⑤ 대구법", "2"),
    SubjectBatteryCase("국어", "겉으로 보기에는 모순되지만 그 속에 진리를 담고 있는 표현 방법은?\n① 반어법 ② 역설법 ③ 은유법 ④ 의인법 ⑤ 점층법", "2"),

    // MARK: 더 — 영어 문장 선지
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① She doesn't like spicy food.\n② Do you have a pen?\n③ He doesn't knows the answer.\n④ I don't eat breakfast.\n⑤ They didn't go out.", "3"),
    SubjectBatteryCase("영어", "어법상 틀린 문장을 고르면? ① I will be there soon. ② She will comes back. ③ We can help you. ④ You must be tired. ⑤ He should go now.", "2"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① I bought many books.\n② She drank much water.\n③ He has many money.\n④ We don't have much time.\n⑤ They have many friends.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① She has two children.\n② I have three brothers.\n③ He has two foots.\n④ There are five men.\n⑤ My teeth are white.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① If it rains tomorrow, I will stay home.\n② If I were you, I would study harder.\n③ If it will rain tomorrow, I will stay home.\n④ If you heat ice, it melts.\n⑤ If I had time, I would help you.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① He is the tallest boy in his class.\n② This is the most interesting book.\n③ She is the most smartest student.\n④ Today is the coldest day of the year.\n⑤ He is the best player on the team.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 것은? ① I know the man who lives there. ② This is the car which my dad bought. ③ I like the dog which has long ears. ④ This is the thing what I wanted. ⑤ He is a boy who likes music.", "4"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① My father goes to work by bus.\n② He watch TV every evening.\n③ She studies English every day.\n④ The sun rises in the east.\n⑤ It rains a lot in summer.", "2"),
    SubjectBatteryCase("영어", "다음 중 어법상 옳은 문장은?\n① She can sings.\n② He will goes.\n③ They must to stay.\n④ I can swim.\n⑤ We should went.", "4"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① They were busy last week.\n② I was sick yesterday.\n③ We was in the library.\n④ She was happy.\n⑤ You were right.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① Is she your sister?\n② Are you a student?\n③ Is they your friends?\n④ Am I late?\n⑤ Was it fun?", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① Does he play the guitar?\n② Do she like cats?\n③ Do they live here?\n④ Did you sleep well?\n⑤ Does it work?", "2"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① He gave up eating junk food.\n② She practiced playing the violin.\n③ They enjoyed to dance at the party.\n④ I don't mind waiting.\n⑤ We finished cleaning the room.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① I want to buy a new bike.\n② She hopes to win the game.\n③ He decided to study abroad.\n④ They planned visiting Paris.\n⑤ We agreed to help them.", "4"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① This song was sung by a famous singer.\n② The cake was made by my sister.\n③ The bridge was build in 1990.\n④ The thief was caught by the police.\n⑤ The book was read by many students.", "3"),
    SubjectBatteryCase("영어", "어법상 바른 문장은?\n① The letter was wrote by Tom.\n② The window was broke by him.\n③ The song was sang by her.\n④ The cake was eaten by them.\n⑤ The car was drove by him.", "4"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① There are a lot of people.\n② There is a book on the desk.\n③ There are a dog in the yard.\n④ There were two cats.\n⑤ There is some milk.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① I have an idea.\n② She is a university student.\n③ He bought an new car.\n④ It is an old house.\n⑤ We need an umbrella.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 옳은 것의 기호를 모두 고른 것은?\na) He go to school every day.\nb) She is reading a book now.\nc) I visited my aunt last week.\nd) We has a dog.\n① a, b ② a, c ③ b, c ④ b, d ⑤ c, d", "3"),
    SubjectBatteryCase("영어", "다음 <보기> 중 어법상 어색한 것끼리 바르게 묶은 것은?\n<보기>\nㄱ. She made me laugh.\nㄴ. He let me to go out.\nㄷ. I enjoy reading books.\nㄹ. They wants to see you.\n① ㄱ, ㄴ ② ㄱ, ㄷ ③ ㄴ, ㄷ ④ ㄴ, ㄹ ⑤ ㄷ, ㄹ", "4"),
    SubjectBatteryCase("영어", "어법상 바른 것을 있는 대로 고른 것은?\n(A) I have lived in Seoul since 2010.\n(B) She has gone to Paris last year.\n(C) They have known each other for ten years.\n① (A) ② (B) ③ (A), (B) ④ (A), (C) ⑤ (B), (C)", "4"),
    SubjectBatteryCase("영어", "(A), (B)에 들어갈 말로 알맞은 것은?\nShe (A) to Busan last year.\nHe (B) in Busan since 2019.\n① goes - lives ② went - has lived ③ went - lived ④ has gone - lives ⑤ goes - has lived", "2"),
    SubjectBatteryCase("영어", "빈칸 (A), (B)에 알맞은 것을 고르면?\nHe is (A) than his brother.\nThis is (B) movie of all.\n① tall - good ② taller - the best ③ tallest - better ④ taller - better ⑤ tall - the best", "2"),
    SubjectBatteryCase("영어", "Two hours ______ enough to finish the work.\n① is ② are ③ were ④ be", "1"),
    SubjectBatteryCase("영어", "My family and I ______ going to visit Jeju next month.\n① am ② is ③ are ④ be ⑤ been", "3"),
    SubjectBatteryCase("영어", "He told me ______ the door.\n① close ② closes ③ to close ④ closing ⑤ closed", "3"),
    SubjectBatteryCase("영어", "I want you ______ me.\n① help ② to help ③ helping ④ helped", "2"),
    SubjectBatteryCase("영어", "She let me ______ her computer.\n① use ② to use ③ using ④ used", "1"),
    // 더 — 국어
    SubjectBatteryCase("국어", "다음 중 맞춤법이 바른 것은? ① 몇일 ② 금새 ③ 며칠 ④ 일부로 ⑤ 설겆이", "3"),
    SubjectBatteryCase("국어", "다음 중 바르게 쓴 문장은?\n① 오늘은 왠지 기분이 좋다.\n② 웬지 슬프다.\n③ 왠일이니?\n④ 오랫만이야.\n⑤ 정말 어의없다.", "1"),
    SubjectBatteryCase("국어", "다음 중 맞춤법이 틀린 것은?\n① 떡볶이 ② 육개장 ③ 찌개 ④ 베게 ⑤ 휴게실", "4"),
    SubjectBatteryCase("국어", "다음 중 표준어인 것은? ① 삭월세 ② 우뢰 ③ 끼여들기 ④ 사글세 ⑤ 깡총깡총", "4"),
    SubjectBatteryCase("국어", "띄어쓰기가 바르지 않은 것은?\n① 할 수 있다\n② 먹을 것이 없다\n③ 갈 데가 없다\n④ 너를 볼수 없다\n⑤ 알 수 없다", "4"),
    SubjectBatteryCase("국어", "'담궜다'를 바르게 고쳐 쓰시오.", "담갔다"),
    SubjectBatteryCase("국어", "'통채로'를 맞춤법에 맞게 고쳐 쓰시오.", "통째로"),
    SubjectBatteryCase("국어", "다음 중 유음화가 일어나지 않는 단어는?\n① 신라 ② 칼날 ③ 난로 ④ 설날 ⑤ 국물", "5"),
    SubjectBatteryCase("국어", "다음 단어의 표준 발음으로 옳은 것은?\n밥물\n① [밥물] ② [밤물] ③ [바물] ④ [밥뭉] ⑤ [방물]", "2"),
    SubjectBatteryCase("국어", "'신라'의 표준 발음을 쓰시오.", "[실라]|실라"),
    SubjectBatteryCase("국어", "다음 중 된소리되기가 일어나지 않는 단어는?\n① 국밥 ② 입고 ③ 먹다 ④ 신라 ⑤ 학교", "4"),
    SubjectBatteryCase("국어", "다음 중 거센소리되기가 일어나지 않는 것은?\n① 좋고 ② 놓다 ③ 축하 ④ 입학 ⑤ 국물", "5"),
    SubjectBatteryCase("국어", "다음 중 구개음화가 일어나지 않는 단어는?\n① 같이 ② 굳이 ③ 맏이 ④ 해돋이 ⑤ 밥물", "5"),
    SubjectBatteryCase("국어", "다음 중 주체 높임이 쓰이지 않은 문장은?\n① 할아버지께서 진지를 잡수신다.\n② 선생님께서 웃으셨다.\n③ 어머니께서 시장에 가셨다.\n④ 나는 동생과 놀았다.\n⑤ 아버지께서 주무신다.", "4"),
    SubjectBatteryCase("국어", "다음 중 객체 높임법이 쓰이지 않은 문장은?\n① 할머니를 모시고 왔다.\n② 선생님께 여쭈어 보았다.\n③ 형이 책을 읽는다.\n④ 아버지께 선물을 드렸다.\n⑤ 교수님을 뵈었다.", "3"),
    SubjectBatteryCase("국어", "다음 중 부사인 것은?\n① 새 ② 헌 ③ 매우 ④ 아이고 ⑤ 우리", "3"),
    SubjectBatteryCase("국어", "다음 중 수사인 것은? ① 셋 ② 새 ③ 매우 ④ 아이고 ⑤ 너", "1"),
    SubjectBatteryCase("국어", "같은 구조의 문장을 짝 지어 나란히 놓는 표현법은?\n① 대구법 ② 반복법 ③ 설의법 ④ 영탄법 ⑤ 점층법", "1"),
    SubjectBatteryCase("국어", "누구나 알 수 있는 내용을 의문의 형식으로 나타내어 강조하는 표현법은?\n① 설의법 ② 반어법 ③ 대구법 ④ 직유법 ⑤ 영탄법", "1"),
    SubjectBatteryCase("국어", "실제보다 훨씬 크게 또는 작게 나타내는 표현 방법을 무엇이라고 하는가?", "과장법"),
    SubjectBatteryCase("국어", "소설의 구성 단계 중 갈등이 최고조에 이르는 단계는?\n① 발단 ② 전개 ③ 위기 ④ 절정 ⑤ 결말", "4"),
    SubjectBatteryCase("국어", "작품 속 인물인 '나'가 주인공이 되어 자신의 이야기를 하는 소설의 시점은?\n① 1인칭 주인공 시점 ② 1인칭 관찰자 시점 ③ 3인칭 관찰자 시점 ④ 전지적 작가 시점", "1"),
    // 더 — 사회
    SubjectBatteryCase("사회", "동경 135°와 서경 45°의 시차는 몇 시간인가?", "12시간|12"),
    SubjectBatteryCase("사회", "우리나라(동경 135°)가 오전 11시일 때 동경 15°인 지역은 몇 시인가?\n① 오전 3시 ② 오전 4시 ③ 오전 5시 ④ 오후 1시 ⑤ 오후 7시", "1"),
    SubjectBatteryCase("사회", "다음 중 법원의 권한이 아닌 것은?\n① 재판 ② 위헌 법률 심판 제청 ③ 명령·규칙·처분 심사 ④ 법률안 거부권", "4"),
    SubjectBatteryCase("사회", "다음 중 대통령의 권한이 아닌 것은?\n① 국군 통수 ② 법률안 거부권 ③ 조약 체결·비준 ④ 사면권 ⑤ 국정 감사", "5"),
    SubjectBatteryCase("사회", "다음 중 조선 시대에 일어난 사건은?\n① 귀주 대첩 ② 살수 대첩 ③ 한산도 대첩 ④ 무신 정변 ⑤ 위화도 회군", "3"),
    SubjectBatteryCase("사회", "다음 중 고려 시대의 사건으로 옳지 않은 것은?\n① 서희의 외교 담판 ② 무신 정변 ③ 삼별초 항쟁 ④ 임진왜란 ⑤ 귀주 대첩", "4"),
    SubjectBatteryCase("사회", "다음 중 보완재 관계인 것은?\n① 연필 - 지우개 ② 쌀 - 밀가루 ③ 버터 - 마가린 ④ 콜라 - 사이다 ⑤ 연필 - 샤프", "1"),
    SubjectBatteryCase("사회", "냉대 기후 지역에 넓게 나타나는 침엽수림을 무엇이라고 하는가?", "타이가"),
    SubjectBatteryCase("사회", "열대 우림 기후 지역에서 오후에 거의 매일 내리는 강한 소나기를 무엇이라고 하는가?", "스콜"),
    SubjectBatteryCase("사회", "건조 기후 중 짧은 풀이 자라는 초원이 나타나는 기후는?\n① 사막 기후 ② 스텝 기후 ③ 툰드라 기후 ④ 사바나 기후 ⑤ 지중해성 기후", "2"),
    SubjectBatteryCase("사회", "다음 중 공공 부조에 해당하는 것은?\n① 국민연금 ② 건강 보험 ③ 고용 보험 ④ 국민 기초 생활 보장 ⑤ 산재 보험", "4"),
    SubjectBatteryCase("사회", "특정 정당이나 후보자에게 유리하도록 선거구를 정하는 것을 무엇이라고 하는가?", "게리맨더링"),
    SubjectBatteryCase("사회", "다음 사건 중 가장 나중에 일어난 것은?\n① 3·1 운동 ② 갑신정변 ③ 임오군란 ④ 강화도 조약 ⑤ 을사늑약", "1"),
    // 더 — 과학
    SubjectBatteryCase("과학", "질량 2 kg인 물체가 높이 20 m에서 자유 낙하할 때, 높이 5 m인 지점을 지나는 순간의 운동 에너지는 몇 J인가? (단, 중력 가속도는 10 m/s², 공기 저항은 무시한다.)", "300 J"),
    SubjectBatteryCase("과학", "일률이 600 W인 기계가 물체를 3 m/s의 일정한 속력으로 끌어당길 때 작용하는 힘은 몇 N인가?", "200 N"),
    SubjectBatteryCase("과학", "다음 중 열을 흡수하는 상태 변화가 아닌 것은?\n① 융해 ② 기화 ③ 끓음 ④ 액화 ⑤ 증발", "4"),
    SubjectBatteryCase("과학", "<보기>에서 척추동물만을 있는 대로 고른 것은?\n<보기>\nㄱ. 개구리 ㄴ. 오징어 ㄷ. 상어 ㄹ. 지렁이\n① ㄱ, ㄴ ② ㄱ, ㄷ ③ ㄴ, ㄹ ④ ㄱ, ㄷ, ㄹ ⑤ ㄴ, ㄷ, ㄹ", "2"),
    SubjectBatteryCase("과학", "다음 중 정온 동물인 것은?\n① 개구리 ② 뱀 ③ 붕어 ④ 참새 ⑤ 도마뱀", "4"),
    SubjectBatteryCase("과학", "소리의 높낮이를 결정하는 것은?\n① 진폭 ② 진동수 ③ 파형 ④ 속력 ⑤ 매질", "2"),
    SubjectBatteryCase("과학", "소리의 세기(크기)를 결정하는 것은?\n① 진폭 ② 진동수 ③ 파장 ④ 주기 ⑤ 매질", "1"),
    SubjectBatteryCase("과학", "자석의 같은 극끼리 서로 밀어내는 힘은?\n① 인력 ② 척력 ③ 마찰력 ④ 중력 ⑤ 탄성력", "2"),
    SubjectBatteryCase("과학", "식물의 잎에서 물이 기공을 통해 수증기 상태로 빠져나가는 현상은?\n① 광합성 ② 호흡 ③ 증산 작용 ④ 삼투 ⑤ 확산", "3"),
    SubjectBatteryCase("과학", "산과 염기가 반응하여 물이 생성되는 반응은?\n① 산화 ② 환원 ③ 중화 반응 ④ 연소 ⑤ 분해", "3"),
    SubjectBatteryCase("과학", "5 Ω인 저항 2개를 직렬로 연결하고 10 V의 전압을 걸었다. 회로에 흐르는 전류는?\n① 0.5 A ② 1 A ③ 2 A ④ 5 A ⑤ 10 A", "2"),
]

// 함정: 답이 하나로 안 정해지거나 앱 자료로 알 수 없는 것 → 풀면 안 됨
let subjectBattery2Traps: [SubjectBatteryCase] = [
    SubjectBatteryCase("과학", "높이 10 m에서 공을 던졌을 때 지면에 닿는 순간의 속력은 몇 m/s인가? (단, 중력 가속도는 10 m/s²)", ""),
    SubjectBatteryCase("과학", "마찰이 있는 빗면의 높이 5 m인 곳에서 물체를 놓았을 때 바닥에서의 속력은 몇 m/s인가? (단, 중력 가속도는 10 m/s²)", ""),
    SubjectBatteryCase("과학", "물 100 g과 식용유 100 g을 섞었을 때 나중 온도는 몇 ℃인가?", ""),
    SubjectBatteryCase("과학", "저항 2 Ω과 3 Ω을 연결했을 때 합성 저항은 몇 Ω인가?", ""),
    SubjectBatteryCase("과학", "탄소 12 g과 산소 50 g을 반응시켰다. 생성된 이산화 탄소의 질량은 몇 g인가?", ""),
    SubjectBatteryCase("과학", "다음 중 광합성에 대한 설명으로 옳은 것은?\n① 엽록체에서 일어난다.\n② 산소가 발생한다.\n③ 빛 에너지가 필요하다.\n④ 이산화 탄소를 흡수한다.\n⑤ 밤에만 일어난다.", ""),
    SubjectBatteryCase("과학", "다음 중 세포 호흡에 대한 설명으로 옳은 것은?\n① 효소가 관여한다.\n② 체온 유지에 쓰인다.\n③ 모든 세포에서 일어난다.\n④ 에너지를 저장한다.\n⑤ 물이 생긴다.", ""),
    SubjectBatteryCase("과학", "다음 중 화학 변화인 것은?\n① 김치가 시어진다.\n② 단풍이 든다.\n③ 과일이 익는다.\n④ 철이 녹슨다.\n⑤ 종이가 탄다.", ""),
    SubjectBatteryCase("과학", "다음 중 정온 동물이 아닌 것은?\n① 고래 ② 펭귄 ③ 박쥐 ④ 오리너구리 ⑤ 개", ""),
    SubjectBatteryCase("과학", "볼록 렌즈의 배율은 몇 배인가? (물체의 크기 2 cm)", ""),
    SubjectBatteryCase("과학", "a + b의 값은? aFe + bO2 → Fe2O3 ① 3 ② 4 ③ 5 ④ 6 ⑤ 7", ""),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① I am interesting in music.\n② She is good at tennis.\n③ He has a lot of friends.\n④ They live in Seoul.\n⑤ We like pizza.", ""),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① He put the book on the desk.\n② She read the letter.\n③ I cut the paper.\n④ They hit the ball.\n⑤ We let him go.", ""),
    SubjectBatteryCase("영어", "다음 중 어법상 바른 것끼리 묶인 것은?\na) I wish I had a car.\nb) She suggested that he go home.\nc) The news are good.\nd) It's time we left.\n① a, b ② a, c ③ b, c ④ c, d ⑤ b, d", ""),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① She plays the piano every day.\n② They were at home yesterday.\n③ I have lived here since 2015.\n④ He went to the park last Sunday.\n⑤ We are watching TV now.", ""),
    SubjectBatteryCase("영어", "다음 중 문맥상 어색한 문장은?\n① I was hungry, so I ate lunch.\n② It was raining, so I took an umbrella.\n③ I was tired, so I went to bed early.\n④ He was sick, so he went to school.\n⑤ She was thirsty, so she drank water.", ""),
    SubjectBatteryCase("영어", "(A), (B)에 들어갈 말로 알맞은 것은?\nThe man (A) I met was kind.\nThis is the house (B) I live.\n① who - which ② that - where ③ whom - where ④ which - where ⑤ whose - which", ""),
    SubjectBatteryCase("영어", "I ______ to school.\n① go ② went ③ will go ④ going ⑤ gone", ""),
    SubjectBatteryCase("영어", "The team ______ playing well this season.\n① is ② are ③ be ④ being", ""),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① The man who I met was kind.\n② Thank you for your help.\n③ I don't know if he will come.\n④ When will you come back?\n⑤ She likes reading books.", ""),
    SubjectBatteryCase("영어", "다음 영영풀이에 해당하는 단어는?\na person who teaches students\n① teacher ② doctor ③ pilot ④ farmer ⑤ singer", ""),
    SubjectBatteryCase("사회", "다음 중 세계에서 가장 긴 강은?\n① 나일강 ② 아마존강 ③ 양쯔강 ④ 미시시피강 ⑤ 볼가강", ""),
    SubjectBatteryCase("사회", "우리나라가 속한 기후대는?\n① 열대 ② 건조 기후 ③ 온대 ④ 냉대 ⑤ 한대", ""),
    SubjectBatteryCase("사회", "다음 중 조선 시대에 일어난 사건은?\n① 을사늑약 ② 귀주 대첩 ③ 3·1 운동 ④ 살수 대첩 ⑤ 6·25 전쟁", ""),
    SubjectBatteryCase("사회", "서울이 오후 3시일 때 뉴욕은 몇 시인가?\n① 오전 1시 ② 오전 2시 ③ 오전 3시 ④ 오후 1시 ⑤ 오후 2시", ""),
    SubjectBatteryCase("사회", "다음 중 대체재 관계인 것은?\n① 커피 - 녹차 ② 빵 - 우유 ③ 바늘 - 실 ④ 펜 - 잉크 ⑤ 쌀 - 보리", ""),
    SubjectBatteryCase("사회", "다음 중 국회의 권한으로 옳은 것은?\n① 국정 감사 ② 예산안 의결 ③ 탄핵 소추 ④ 위헌 법률 심판 ⑤ 국군 통수", ""),
    SubjectBatteryCase("사회", "다음 인물과 사건의 연결이 옳은 것은?\n① 세종 - 훈민정음 창제\n② 이순신 - 한산도 대첩\n③ 왕건 - 위화도 회군\n④ 을지문덕 - 귀주 대첩\n⑤ 강감찬 - 살수 대첩", ""),
    SubjectBatteryCase("사회", "환율이 오르면 우리나라 경제에 나타나는 현상으로 옳은 것은?\n① 수출 증가 ② 수입 증가 ③ 해외여행 증가 ④ 외채 부담 감소 ⑤ 물가 하락", ""),
    SubjectBatteryCase("사회", "다음 중 적도가 지나는 나라는?\n① 브라질 ② 인도네시아 ③ 케냐 ④ 에콰도르 ⑤ 일본", ""),
    SubjectBatteryCase("국어", "다음 중 바르게 쓴 것은?\n① 결제 ② 결재", ""),
    SubjectBatteryCase("국어", "다음 중 비음화가 일어나는 단어는?\n① 의견란 ② 신라 ③ 칼날 ④ 난로 ⑤ 설날", ""),
    SubjectBatteryCase("국어", "다음 중 상대 높임법이 쓰인 문장은?\n① 할머니께서 주무십니다.\n② 선생님께 드렸어요.\n③ 밥 먹어라.\n④ 어서 오세요.\n⑤ 안녕히 가십시오.", ""),
    SubjectBatteryCase("국어", "다음 중 형용사인 것은?\n① 크다 ② 밝다 ③ 늦다 ④ 먹다 ⑤ 가다", ""),
    SubjectBatteryCase("국어", "다음 중 된소리되기가 일어나는 단어는?\n① 갈등 ② 발전 ③ 신고 ④ 국밥 ⑤ 안다", ""),
    SubjectBatteryCase("국어", "다음 중 음운 변동의 종류가 다른 하나는?\n① 솜이불 ② 색연필 ③ 국물 ④ 맨입 ⑤ 꽃잎", ""),
    SubjectBatteryCase("국어", "'내 마음은 호수요'에 쓰인 표현법과 같은 것은?\n① 별처럼 빛나는 눈 ② 내 누님같이 생긴 꽃 ③ 소리 없는 아우성 ④ 시간은 금이다 ⑤ 바다가 웃는다", ""),
    SubjectBatteryCase("국어", "다음 중 띄어쓰기가 바른 것은?\n① 이것 저것 ② 날것 ③ 먹을거리 ④ 갈데 ⑤ 볼만하다", ""),
    SubjectBatteryCase("국어", "다음 중 품사가 다른 하나는?\n① 이 ② 그 ③ 저 ④ 새 ⑤ 헌", ""),
    SubjectBatteryCase("국어", "다음 중 맞춤법이 틀린 것은?\n① 색이 바랬다 ② 날씨가 개었다 ③ 문을 잠갔다 ④ 김치를 담갔다 ⑤ 대가를 치렀다", ""),
]

// 새 변형: 규칙을 맞추며 보지 않은 문제 (오답 0만 확인, 정답 수는 따로)
let subjectBattery2Fresh: [SubjectBatteryCase] = [
    SubjectBatteryCase("과학", "높이 80 m인 건물 옥상에서 돌을 가만히 떨어뜨렸다. 땅에 닿는 순간 돌의 속력은 몇 m/s인가? (단, 중력 가속도는 10 m/s²이고 공기 저항은 무시한다.)", "40 m/s"),
    SubjectBatteryCase("과학", "공을 30 m/s의 속력으로 연직 위로 던졌다. 최고점의 높이는 몇 m인가? (단, 중력 가속도 10 m/s², 공기 저항 무시)", "45 m"),
    SubjectBatteryCase("과학", "50 N의 힘으로 물체를 4 m/s의 일정한 속력으로 당길 때의 일률은 몇 W인가?", "200 W"),
    SubjectBatteryCase("과학", "물체의 크기가 3 cm이고 상의 크기가 12 cm일 때 렌즈의 배율은 몇 배인가?", "4배|4"),
    SubjectBatteryCase("과학", "빛이 평면거울에 입사각 45°로 입사하였다. 반사각은?\n① 0° ② 30° ③ 45° ④ 60° ⑤ 90°", "3"),
    SubjectBatteryCase("과학", "10 ℃의 물 300 g과 50 ℃의 물 100 g을 섞었을 때 열평형 온도는 몇 ℃인가?", "20 ℃"),
    SubjectBatteryCase("과학", "5 Ω, 10 Ω, 15 Ω의 저항을 직렬로 연결하였을 때 합성 저항은 몇 Ω인가?", "30 Ω"),
    SubjectBatteryCase("과학", "2 Ω과 2 Ω의 저항을 병렬로 연결하면 합성 저항은?\n① 0.5 Ω ② 1 Ω ③ 2 Ω ④ 4 Ω ⑤ 8 Ω", "2"),
    SubjectBatteryCase("과학", "구리 8 g을 완전히 연소시켰더니 산화 구리(Ⅱ) 10 g이 생성되었다. 반응한 산소의 질량은 몇 g인가?", "2 g"),
    SubjectBatteryCase("과학", "2CO + O2 → aCO2에서 a의 값은?\n① 1 ② 2 ③ 3 ④ 4 ⑤ 5", "2"),
    SubjectBatteryCase("과학", "다음 중 증발과 같은 상태 변화가 일어나는 현상은?\n① 물웅덩이의 물이 마른다.\n② 고드름이 생긴다.\n③ 눈이 녹는다.\n④ 안경에 김이 서린다.\n⑤ 촛농이 굳는다.", "1"),
    SubjectBatteryCase("과학", "다음 중 혈소판에 대한 설명으로 옳은 것은?\n① 산소를 운반한다.\n② 혈액 응고에 관여한다.\n③ 식균 작용을 한다.\n④ 핵이 있다.\n⑤ 헤모글로빈이 있다.", "2"),
    SubjectBatteryCase("과학", "다음 중 외떡잎식물이 아닌 것은?\n① 벼 ② 옥수수 ③ 보리 ④ 강낭콩 ⑤ 밀", "4"),
    SubjectBatteryCase("과학", "다음 중 전류가 잘 흐르는 도체인 것은?\n① 유리 ② 은 ③ 종이 ④ 고무 ⑤ 나무", "2"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① My brother doesn't like carrots.\n② She want to buy a new bag.\n③ We played soccer yesterday.\n④ I will visit my uncle tomorrow.\n⑤ They are reading books now.", "2"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① I gave up eating sweets.\n② He promised to call me.\n③ She avoided to meet him.\n④ We enjoyed watching the game.\n⑤ They planned to travel.", "3"),
    SubjectBatteryCase("영어", "어법상 옳은 문장은?\n① He must goes now.\n② She can't swims.\n③ You should study hard.\n④ They will went there.\n⑤ I can to play the guitar.", "3"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 것은?\n① The car is washed by my dad.\n② The picture was drew by Mina.\n③ This bridge was built in 2001.\n④ Those cookies were made by her.\n⑤ The door was opened by the wind.", "2"),
    SubjectBatteryCase("영어", "다음 중 어법상 틀린 문장은?\n① He has three childs.\n② She has two cats.\n③ I saw some sheep.\n④ The men are tall.\n⑤ My feet are cold.", "1"),
    SubjectBatteryCase("영어", "다음 중 어법상 바른 것끼리 묶인 것은?\na) She don't eat meat.\nb) He visited Jeju last year.\nc) I have finished my homework.\nd) They was happy.\n① a, b ② a, c ③ b, c ④ b, d ⑤ c, d", "3"),
    SubjectBatteryCase("영어", "(A), (B)에 알맞은 말로 짝지어진 것은?\nI finished (A) the report.\nShe decided (B) a new phone.\n① write - buy ② writing - to buy ③ to write - buying ④ writing - buying ⑤ to write - to buy", "2"),
    SubjectBatteryCase("영어", "We ______ each other since we were children.\n① know ② knew ③ have known ④ are knowing ⑤ will know", "3"),
    SubjectBatteryCase("영어", "If I ______ rich, I would buy a big house.\n① am ② is ③ are ④ were ⑤ be", "4"),
    SubjectBatteryCase("영어", "Five dollars ______ too much for this pen.\n① is ② are ③ be ④ were", "1"),
    SubjectBatteryCase("영어", "Look! The boys ______ in the river.\n① swim ② swims ③ are swimming ④ swam ⑤ is swimming", "3"),
    SubjectBatteryCase("영어", "Tom and Jerry ______ my best friends.\n① is ② are ③ am ④ be", "2"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 것은?\n① He let me go home.\n② She made me laugh.\n③ They let us to play outside.\n④ I had him wash the car.\n⑤ Mom made me study.", "3"),
    SubjectBatteryCase("사회", "동경 135°인 서울이 오전 10시일 때 경도 0°인 런던은 몇 시인가?\n① 오전 1시 ② 오전 4시 ③ 오후 7시 ④ 오후 1시 ⑤ 오후 10시", "1"),
    SubjectBatteryCase("사회", "경도 차이가 45°인 두 지역의 시차는 몇 시간인가?", "3시간|3"),
    SubjectBatteryCase("사회", "다음 중 법원의 권한에 해당하는 것은?\n① 법률 제정 ② 명령·규칙 심사 ③ 국정 감사 ④ 국군 통수 ⑤ 탄핵 소추", "2"),
    SubjectBatteryCase("사회", "다음 중 고려 시대의 사건이 아닌 것은?\n① 무신 정변 ② 귀주 대첩 ③ 위화도 회군 ④ 병자호란 ⑤ 삼별초 항쟁", "4"),
    SubjectBatteryCase("사회", "다음 인물과 사건의 연결이 옳지 않은 것은?\n① 강감찬 - 귀주 대첩\n② 권율 - 행주 대첩\n③ 을지문덕 - 한산도 대첩\n④ 이성계 - 위화도 회군\n⑤ 이순신 - 명량 대첩", "3"),
    SubjectBatteryCase("사회", "다음 중 보완재 관계인 것은?\n① 버터 - 마가린 ② 커피 - 녹차 ③ 바늘 - 실 ④ 쌀 - 밀가루 ⑤ 콜라 - 사이다", "3"),
    SubjectBatteryCase("사회", "세계에서 가장 넓은 대양으로 아시아와 아메리카 사이에 있는 바다는?", "태평양"),
    SubjectBatteryCase("사회", "다음 중 남반구에 있는 나라는?\n① 독일 ② 아르헨티나 ③ 멕시코 ④ 인도 ⑤ 중국", "2"),
    SubjectBatteryCase("사회", "다음 중 간접세가 아닌 것은?\n① 부가 가치세 ② 주세 ③ 관세 ④ 법인세 ⑤ 개별 소비세", "4"),
    SubjectBatteryCase("사회", "다음 중 삼국 시대에 일어난 사건은?\n① 안시성 전투 ② 귀주 대첩 ③ 병인양요 ④ 임진왜란 ⑤ 갑신정변", "1"),
    SubjectBatteryCase("국어", "다음 중 맞춤법이 바른 것은?\n① 찌게 ② 육계장 ③ 휴게실 ④ 베게 ⑤ 계시판", "3"),
    SubjectBatteryCase("국어", "다음 중 유음화가 일어나는 단어는?\n① 국민 ② 난로 ③ 같이 ④ 축하 ⑤ 국밥", "2"),
    SubjectBatteryCase("국어", "다음 중 구개음화가 일어나는 단어는?\n① 굳이 ② 신라 ③ 밥물 ④ 국수 ⑤ 입학", "1"),
    SubjectBatteryCase("국어", "비음화가 일어나는 단어는?\n① 맏이 ② 놓고 ③ 앞마당 ④ 설날 ⑤ 입고", "3"),
    SubjectBatteryCase("국어", "다음 중 발음이 바르게 표기된 것은?\n① 난로[난노] ② 굳이[구디] ③ 국민[궁민] ④ 좋고[좋고] ⑤ 칼날[칼날]", "3"),
    SubjectBatteryCase("국어", "다음 중 객체 높임이 쓰인 문장은?\n① 아버지께서 출근하셨다.\n② 동생이 잔다.\n③ 나는 할아버지께 편지를 드렸다.\n④ 친구가 웃었다.\n⑤ 고양이가 운다.", "3"),
    SubjectBatteryCase("국어", "다음 중 부사가 아닌 것은?\n① 매우 ② 빨리 ③ 몹시 ④ 옛 ⑤ 아주", "4"),
    SubjectBatteryCase("국어", "다음 중 표준어인 것은?\n① 오뚜기 ② 깍뚜기 ③ 눈곱 ④ 머릿말 ⑤ 햇님", "3"),
    SubjectBatteryCase("국어", "다음 중 띄어쓰기가 바른 것은?\n① 할수 있다\n② 갈 수 없다\n③ 볼수 있다\n④ 먹을수 없다\n⑤ 올수 있다", "2"),
    SubjectBatteryCase("국어", "모순되는 표현 속에 진리를 담는 표현 방법은?\n① 반어법 ② 역설법 ③ 직유법 ④ 의인법", "2"),
    SubjectBatteryCase("국어", "다음 중 거센소리되기가 일어나는 단어는?\n① 좋고 ② 국물 ③ 신라 ④ 굳이 ⑤ 밥물", "1"),
    SubjectBatteryCase("영어", "다음 중 단어와 뜻의 연결이 옳지 않은 것은?\n① borrow - 빌리다 ② library - 도서관 ③ river - 산 ④ honest - 정직한 ⑤ window - 창문", "3"),
    SubjectBatteryCase("과학", "다음 중 목성형 행성에 대한 설명으로 옳은 것은?\n① 표면이 단단한 암석으로 되어 있다.\n② 위성이 없거나 적다.\n③ 고리가 있다.\n④ 평균 밀도가 크다.\n⑤ 반지름이 작다.", "3"),
]

// 새 변형 2: 규칙을 다 만든 뒤에 다른 말투로 새로 쓴 문제 (이 문제에 맞춰 규칙을 고치지 않음, 오답 0만 확인)
let subjectBattery2Fresh2: [SubjectBatteryCase] = [
    SubjectBatteryCase("과학", "질량 5 kg인 물체를 20 m 높이에서 가만히 놓았다. 바닥에 닿기 직전 이 물체가 가진 운동 에너지는? (단, 중력 가속도 10 m/s², 공기 저항 무시)\n① 100 J ② 250 J ③ 500 J ④ 1000 J ⑤ 2000 J", "4"),
    SubjectBatteryCase("과학", "공을 위로 똑바로 던졌더니 처음 속력이 10 m/s였다. 공이 올라가는 최고 높이는 몇 m인가? (단, 중력 가속도는 10 m/s², 공기 저항 무시)", "5 m"),
    SubjectBatteryCase("과학", "같은 저항 3개(각 6 Ω)를 병렬로 연결했을 때 합성 저항은 몇 Ω인가?", "2 Ω"),
    SubjectBatteryCase("과학", "8 Ω과 8 Ω의 저항을 병렬로 연결한 뒤 4 V의 전압을 걸었다. 전체 전류는 몇 A인가?", "1 A"),
    SubjectBatteryCase("과학", "황 32 g과 철 56 g이 완전히 반응하였다. 생성된 황화 철은 몇 g인가?", "88 g"),
    SubjectBatteryCase("과학", "다음 중 적혈구의 특징으로 옳은 것은?\n① 식균 작용을 한다.\n② 핵이 없다.\n③ 혈액 응고를 돕는다.\n④ 크기가 가장 크다.\n⑤ 세균을 잡아먹는다.", "2"),
    SubjectBatteryCase("과학", "다음 중 액화의 예로 알맞은 것은?\n① 얼음이 녹는다.\n② 차가운 컵 표면에 물방울이 맺힌다.\n③ 물이 언다.\n④ 빨래가 마른다.\n⑤ 나프탈렌이 작아진다.", "2"),
    SubjectBatteryCase("과학", "다음 중 쌍떡잎식물은?\n① 벼 ② 보리 ③ 옥수수 ④ 해바라기 ⑤ 백합", "4"),
    SubjectBatteryCase("과학", "다음 중 분해자가 아닌 것은?\n① 곰팡이 ② 세균 ③ 버섯 ④ 토끼", "4"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 문장은?\n① He doesn't play baseball.\n② She have three sisters.\n③ We like music.\n④ I am a student.\n⑤ They live in Busan.", "2"),
    SubjectBatteryCase("영어", "다음 중 어법상 바른 문장은?\n① He cans swim.\n② She will be fine.\n③ They was happy.\n④ I has a pen.\n⑤ We goes home.", "2"),
    SubjectBatteryCase("영어", "어법상 틀린 문장은?\n① I didn't saw him.\n② She didn't come.\n③ We don't know.\n④ He doesn't eat meat.\n⑤ They didn't go.", "1"),
    SubjectBatteryCase("영어", "다음 중 어법상 어색한 것은?\n① There is a pen on the desk.\n② There are many students in the room.\n③ There is two cats under the chair.\n④ There was a big tree.\n⑤ There were three boys.", "3"),
    SubjectBatteryCase("영어", "다음 빈칸에 알맞은 것은?\nShe ______ in Seoul since 2015.\n① live ② lives ③ has lived ④ lived ⑤ is living", "3"),
    SubjectBatteryCase("영어", "Three hours ______ a long time to wait.\n① is ② are ③ were ④ be", "1"),
    SubjectBatteryCase("영어", "My brother and my sister ______ students.\n① is ② are ③ am ④ be", "2"),
    SubjectBatteryCase("영어", "We are looking forward to ______ from you.\n① hear ② hearing ③ heard ④ hears", "2"),
    SubjectBatteryCase("영어", "(A), (B)에 알맞은 것은?\nHe avoided (A) the question.\nThey hope (B) the game.\n① answer - win ② answering - to win ③ to answer - winning ④ answering - winning ⑤ to answer - to win", "2"),
    SubjectBatteryCase("영어", "다음 중 어법상 바른 것끼리 묶인 것은?\na) He is taller than me.\nb) She is more prettier than her sister.\nc) This is the best book.\nd) I am as tall as him.\n① a, b ② b, c ③ a, c ④ b, d ⑤ a, b, d", "3"),
    SubjectBatteryCase("사회", "서울(동경 135°)이 오전 8시일 때, 동경 105°인 방콕은 몇 시인가?\n① 오전 4시 ② 오전 5시 ③ 오전 6시 ④ 오전 10시 ⑤ 오전 11시", "3"),
    SubjectBatteryCase("사회", "다음 중 헌법 재판소가 하는 일은?\n① 법률을 만든다 ② 위헌 법률 심판 ③ 예산안 심의 ④ 국군 통수 ⑤ 국정 감사", "2"),
    SubjectBatteryCase("사회", "다음 중 조선 시대에 있었던 사건으로 옳은 것은?\n① 귀주 대첩 ② 행주 대첩 ③ 살수 대첩 ④ 3·1 운동 ⑤ 무신 정변", "2"),
    SubjectBatteryCase("사회", "다음 중 대체재 관계로 짝지어진 것은?\n① 바늘 - 실 ② 펜 - 잉크 ③ 버스 - 지하철 ④ 커피 - 설탕 ⑤ 자동차 - 휘발유", "3"),
    SubjectBatteryCase("사회", "다음 중 보완재가 아닌 것은?\n① 바늘 - 실 ② 커피 - 설탕 ③ 자동차 - 휘발유 ④ 콜라 - 사이다 ⑤ 컴퓨터 - 마우스", "4"),
    SubjectBatteryCase("사회", "다음 중 남반구에 위치한 나라는?\n① 칠레 ② 캐나다 ③ 몽골 ④ 영국 ⑤ 일본", "1"),
    SubjectBatteryCase("국어", "다음 중 비음화가 일어나는 단어는?\n① 접시 ② 닫는다 ③ 놓고 ④ 굳이 ⑤ 신라", "2"),
    SubjectBatteryCase("국어", "다음 중 구개음화가 일어나는 것은?\n① 밭이 ② 밥물 ③ 신라 ④ 국밥 ⑤ 좋다", "1"),
    SubjectBatteryCase("국어", "다음 중 맞춤법이 바른 것은?\n① 웬지 ② 왠일 ③ 금새 ④ 며칠 ⑤ 몇일", "4"),
    SubjectBatteryCase("국어", "다음 중 객체 높임법이 쓰인 문장은?\n① 할아버지께서 신문을 보신다.\n② 나는 할머니를 모시고 시장에 갔다.\n③ 동생이 학교에 간다.\n④ 선생님께서 웃으신다.\n⑤ 친구가 노래를 부른다.", "2"),
    SubjectBatteryCase("국어", "다음 중 품사가 다른 하나는?\n① 새 ② 헌 ③ 옛 ④ 아주 ⑤ 모든", "4"),
    SubjectBatteryCase("국어", "다음 중 감탄사가 아닌 것은?\n① 아이고 ② 어머 ③ 여보세요 ④ 빨리", "4"),
]

func runSubjectBattery2Cases() {
    func runList(_ list: [SubjectBatteryCase], tag: String, hard: Bool) -> (stats: [String: (correct: Int, unsolved: Int, wrong: Int, total: Int)], wrongs: [String], unsolved: [String]) {
        var stats: [String: (correct: Int, unsolved: Int, wrong: Int, total: Int)] = [:]
        var wrongs: [String] = [], unsolvedList: [String] = []
        for item in list {
            let scan = DoitProblemScan.scan(item.text, math: false)
            let choices = scan.choices
            let label = "[\(item.subject)] " + item.text.replacingOccurrences(of: "\n", with: " / ")
            var s = stats[item.subject] ?? (0, 0, 0, 0)
            s.total += 1
            let detected = DoitSubjectDetector.detect(item.text)?.broad
            guard let solution = DoitSubjectSolve.solve(text: item.text, choices: choices, subjectBroad: detected ?? item.subject,
                                                        body: scan.body, boxItems: scan.boxItems) else {
                s.unsolved += 1; stats[item.subject] = s
                unsolvedList.append(label)
                continue
            }
            let answer = solution.finalAnswer
            let right = choices.count >= 2
                ? (DoitGrader.choiceNumber(answer, choices: choices).map { "\($0)" == item.answer } ?? false)
                : subjectMatches(answer, expected: item.answer)
            check("\(tag) 확인된 답: \(label)", solution.source == DoitAutoSolve.engineSource && !solution.steps.isEmpty, "source \(solution.source ?? "-")")
            if right { s.correct += 1 } else { s.wrong += 1; wrongs.append("\(label) → 답 '\(answer)', 정답 '\(item.answer)'") }
            check("\(tag) 오답 없음: \(label)", right, "답 '\(answer)', 정답 '\(item.answer)'")
            stats[item.subject] = s
        }
        return (stats, wrongs, unsolvedList)
    }
    let main = runList(subjectBattery2, tag: "과목 배터리2", hard: true)
    var trapSolved: [String] = []
    for trap in subjectBattery2Traps {
        let scan = DoitProblemScan.scan(trap.text, math: false)
        let solved = DoitSubjectSolve.solve(text: trap.text, choices: scan.choices, subjectBroad: trap.subject, body: scan.body, boxItems: scan.boxItems)
        if let solved { trapSolved.append("\(trap.text.prefix(50).replacingOccurrences(of: "\n", with: " / ")) → '\(solved.finalAnswer)'") }
        check("과목 배터리2 함정은 풀지 않음: \(trap.text.prefix(40))", solved == nil, "답 '\(solved?.finalAnswer ?? "")'")
    }
    check("과목 배터리2: 250문제 이상", subjectBattery2.count >= 250, "\(subjectBattery2.count)문제")
    check("과목 배터리2: 함정 40개", subjectBattery2Traps.count >= 40, "\(subjectBattery2Traps.count)개")
    check("과목 배터리2: 오답 0개", main.wrongs.isEmpty, "오답 \(main.wrongs.count)개")
    for subject in ["과학", "영어", "사회", "국어"] {
        guard let s = main.stats[subject] else { continue }
        print("과목 배터리2 [\(subject)]: 정답 \(s.correct) / 전체 \(s.total), 못 풂 \(s.unsolved), 오답 \(s.wrong)")
    }
    let total = main.stats.values.reduce((0, 0, 0, 0)) { ($0.0 + $1.correct, $0.1 + $1.unsolved, $0.2 + $1.wrong, $0.3 + $1.total) }
    print("과목 배터리2: 정답 \(total.0) / 전체 \(total.3), 못 풂 \(total.1), 오답 \(total.2), 함정 \(subjectBattery2Traps.count)개 중 푼 것 \(trapSolved.count)개")
    for w in main.wrongs { print("  ✗ 오답: " + w) }
    for t in trapSolved { print("  ✗ 함정을 풂: " + t) }
    for u in main.unsolved { print("  · 못 풂: " + u) }
    // 새 변형
    let fresh = runList(subjectBattery2Fresh, tag: "과목 배터리2 새 변형", hard: true)
    let ft = fresh.stats.values.reduce((0, 0, 0, 0)) { ($0.0 + $1.correct, $0.1 + $1.unsolved, $0.2 + $1.wrong, $0.3 + $1.total) }
    print("과목 배터리2 새 변형: 정답 \(ft.0) / 전체 \(ft.3), 못 풂 \(ft.1), 오답 \(ft.2)")
    for w in fresh.wrongs { print("  ✗ 새 변형 오답: " + w) }
    for u in fresh.unsolved { print("  · 새 변형 못 풂: " + u) }
    let fresh2 = runList(subjectBattery2Fresh2, tag: "과목 배터리2 새 변형 2", hard: true)
    let f2 = fresh2.stats.values.reduce((0, 0, 0, 0)) { ($0.0 + $1.correct, $0.1 + $1.unsolved, $0.2 + $1.wrong, $0.3 + $1.total) }
    print("과목 배터리2 새 변형 2: 정답 \(f2.0) / 전체 \(f2.3), 못 풂 \(f2.1), 오답 \(f2.2)")
    for w in fresh2.wrongs { print("  ✗ 새 변형 2 오답: " + w) }
    for u in fresh2.unsolved { print("  · 새 변형 2 못 풂: " + u) }
}
