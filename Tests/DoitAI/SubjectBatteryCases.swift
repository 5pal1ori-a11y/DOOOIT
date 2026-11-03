import Foundation

// MARK: - 과목 배터리: 과학·영어·사회·국어 시험 문제 모양으로 규칙 풀이(DoitSubjectSolve)의 정답률 재기
// - 앱처럼 사진 글 → 본문·선지 나누기(DoitProblemScan) → DoitSubjectSolve.solve 로 풂
// - 틀린 답은 실패 (확인한 답이라고 보여 주는데 틀리면 안 돼요), 못 푼 문제는 목록만 보여 줌
// - 정답: 객관식은 선지 번호, 단답은 "|"로 여러 모양, "~"로 시작하면 답 글에 그 말이 들어 있으면 정답
//   수와 단위가 있는 답은 수가 같고 단위가 같으면 정답 ("5 m/s"와 "5 m/s (약 18 km/h)")

struct SubjectBatteryCase {
    let subject: String
    let text: String
    let answer: String
    init(_ subject: String, _ text: String, _ answer: String) { self.subject = subject; self.text = text; self.answer = answer }
}

let subjectBattery: [SubjectBatteryCase] = [
    // MARK: 과학 계산 — 속력·가속도
    SubjectBatteryCase("과학", "1. 100 m를 20초 동안 달린 학생의 평균 속력은 몇 m/s인가?\n① 2 ② 4 ③ 5 ④ 10 ⑤ 20", "3"),
    SubjectBatteryCase("과학", "자동차가 3시간 동안 240 km를 이동하였다. 이 자동차의 평균 속력은 몇 km/h인가?", "80 km/h"),
    SubjectBatteryCase("과학", "속력이 15 m/s인 자전거가 4초 동안 이동한 거리는 몇 m인가?", "60 m"),
    SubjectBatteryCase("과학", "시속 60 km로 달리는 버스가 150 km를 가는 데 걸리는 시간은 몇 시간인가?", "2.5 h|2.5시간"),
    SubjectBatteryCase("과학", "정지해 있던 물체가 5초 후 속력이 20 m/s가 되었다. 이 물체의 가속도는 몇 m/s²인가?\n① 2 ② 4 ③ 5 ④ 10 ⑤ 100", "2"),
    SubjectBatteryCase("과학", "속력이 10 m/s에서 30 m/s로 4초 동안 일정하게 증가하였다. 가속도의 크기는?", "5 m/s²"),
    SubjectBatteryCase("과학", "어떤 물체가 4초 동안 12 m를 이동했다. 이 물체의 평균 속력은?\n① 0.33 m/s ② 3 m/s ③ 8 m/s ④ 16 m/s ⑤ 48 m/s", "2"),
    SubjectBatteryCase("과학", "1.2 km를 10분 동안 걸었을 때 평균 속력은 몇 m/s인가?", "2 m/s"),
    SubjectBatteryCase("과학", "36 km/h는 몇 m/s인가?", "10 m/s"),
    SubjectBatteryCase("과학", "소리가 340 m/s의 속력으로 5초 동안 전달된 거리는 몇 m인가?\n① 68 m ② 340 m ③ 1020 m ④ 1700 m ⑤ 3400 m", "4"),
    SubjectBatteryCase("과학", "4. 400m 트랙을 80초에 달렸다 평균 속력은 몇 m/s 인가\n① 2 ② 4 ③ 5 ④ 8 ⑤ 10", "3"),
    // 힘·무게
    SubjectBatteryCase("과학", "질량이 2 kg인 물체에 10 N의 힘을 작용할 때 물체의 가속도는?\n① 2 m/s² ② 5 m/s² ③ 8 m/s² ④ 12 m/s² ⑤ 20 m/s²", "2"),
    SubjectBatteryCase("과학", "질량 4 kg인 물체를 3 m/s²의 가속도로 움직이게 하려면 몇 N의 힘이 필요한가?", "12 N"),
    SubjectBatteryCase("과학", "질량이 5 kg인 물체의 무게는 몇 N인가?", "49 N"),
    SubjectBatteryCase("과학", "질량 3 kg인 물체의 무게는? (단, 질량 1 kg인 물체의 무게는 10 N이다.)\n① 0.3 N ② 3 N ③ 13 N ④ 30 N ⑤ 300 N", "4"),
    SubjectBatteryCase("과학", "5. 질랑 2kg인 물체에 6N의 힘이 작용할때 가속도는?\n①1m/s² ②2m/s² ③3m/s² ④ 4m/s² ⑤ 12m/s²", "3"),
    SubjectBatteryCase("과학", "8 N의 힘을 받아 4 m/s²의 가속도로 운동하는 물체의 질량은 몇 kg인가?", "2 kg"),
    SubjectBatteryCase("과학", "무게가 98 N인 물체의 질량은 몇 kg인가?", "10 kg"),
    // 밀도
    SubjectBatteryCase("과학", "질량이 54 g이고 부피가 20 cm³인 물체의 밀도는 몇 g/cm³인가?\n① 0.37 ② 1.8 ③ 2.7 ④ 27 ⑤ 1080", "3"),
    SubjectBatteryCase("과학", "부피 50 mL, 질량 40 g인 액체의 밀도는 몇 g/mL인가?", "0.8 g/mL|0.8 g/cm³"),
    SubjectBatteryCase("과학", "밀도가 2 g/cm³인 물체의 부피가 15 cm³일 때 이 물체의 질량은?", "30 g"),
    SubjectBatteryCase("과학", "밀도가 8 g/cm³인 금속 40 g의 부피는 몇 cm³인가?", "5 cm³"),
    SubjectBatteryCase("과학", "밀도가 1.2 g/mL인 액체 100 mL의 질량은 몇 g인가?\n① 12 g ② 83 g ③ 100 g ④ 120 g ⑤ 1200 g", "4"),
    SubjectBatteryCase("과학", "질량 30 g, 부피 12 cm³인 돌의 밀도를 구하시오.", "2.5 g/cm³"),
    // 압력
    SubjectBatteryCase("과학", "무게 120 N인 상자가 바닥과 닿는 면적이 0.4 m²일 때, 바닥이 받는 압력은 몇 Pa인가?", "300 Pa"),
    SubjectBatteryCase("과학", "넓이 2 m²인 판에 50 N의 힘이 수직으로 작용할 때 압력은?\n① 25 Pa ② 48 Pa ③ 52 Pa ④ 100 Pa ⑤ 200 Pa", "1"),
    SubjectBatteryCase("과학", "30 N의 힘이 넓이 10 cm²에 수직으로 작용할 때 압력은 몇 Pa인가?", "30000 Pa"),
    SubjectBatteryCase("과학", "무게가 600 N인 사람이 바닥 면적 0.03 m²로 서 있을 때 바닥이 받는 압력은 몇 N/m²인가?\n① 18 ② 200 ③ 2000 ④ 20000 ⑤ 200000", "4"),
    // 일·일률
    SubjectBatteryCase("과학", "물체에 20 N의 힘을 작용하여 힘의 방향으로 3 m 이동시켰을 때 한 일의 양은?", "60 J"),
    SubjectBatteryCase("과학", "질량 2 kg인 물체를 일정한 속력으로 5 m 높이까지 들어 올릴 때 한 일은 몇 J인가?\n① 10 ② 49 ③ 98 ④ 100 ⑤ 196", "3"),
    SubjectBatteryCase("과학", "10 N의 힘으로 벽을 밀었으나 벽이 움직이지 않았다. 이때 한 일은 몇 J인가?", "0 J|0"),
    SubjectBatteryCase("과학", "어떤 사람이 300 J의 일을 10초 동안 하였다. 이 사람의 일률은 몇 W인가?", "30 W"),
    SubjectBatteryCase("과학", "50 N의 힘으로 물체를 4 m 끄는 데 5초가 걸렸다. 이때의 일률은?\n① 10 W ② 40 W ③ 50 W ④ 200 W ⑤ 1000 W", "2"),
    SubjectBatteryCase("과학", "질량 50 kg인 사람이 높이 3 m인 계단을 오르는 데 6초가 걸렸다. 이 사람의 일률은 몇 W인가?", "245 W"),
    SubjectBatteryCase("과학", "무게가 40 N인 물체를 2 m 높이로 들어 올리는 데 한 일은 몇 J인가?\n① 20 J ② 38 J ③ 42 J ④ 80 J ⑤ 160 J", "4"),
    // 에너지
    SubjectBatteryCase("과학", "질량 2 kg인 물체가 3 m/s의 속력으로 운동할 때 운동 에너지는?\n① 3 J ② 6 J ③ 9 J ④ 18 J ⑤ 36 J", "3"),
    SubjectBatteryCase("과학", "질량이 4 kg인 공이 5 m/s로 굴러가고 있다. 이 공의 운동 에너지는 몇 J인가?", "50 J"),
    SubjectBatteryCase("과학", "질량 3 kg인 물체가 지면으로부터 10 m 높이에 있을 때 중력에 의한 위치 에너지는 몇 J인가?", "294 J"),
    SubjectBatteryCase("과학", "질량 2 kg인 물체를 지면에서 4 m 높이로 들어 올렸을 때 물체의 위치 에너지는? (단, 중력 가속도는 10 m/s²이다.)", "80 J"),
    SubjectBatteryCase("과학", "질량이 1 kg인 물체가 높이 20 m에서 가진 위치 에너지는 몇 J인가?\n① 9.8 J ② 20 J ③ 98 J ④ 196 J ⑤ 200 J", "4"),
    SubjectBatteryCase("과학", "운동하는 물체의 속력이 2배가 되면 운동 에너지는 몇 배가 되는가?", "4배|4"),
    // 열량
    SubjectBatteryCase("과학", "물 200 g의 온도를 20℃에서 70℃로 높이는 데 필요한 열량은 몇 kcal인가? (단, 물의 비열은 1 kcal/(kg·℃)이다.)", "10 kcal"),
    SubjectBatteryCase("과학", "비열이 0.2 cal/(g·℃)인 물질 100 g의 온도를 30℃ 높이는 데 필요한 열량은?\n① 60 cal ② 150 cal ③ 600 cal ④ 1500 cal ⑤ 6000 cal", "3"),
    SubjectBatteryCase("과학", "물 500 g이 열을 받아 온도가 10 ℃ 올라갔다. 물이 얻은 열량은 몇 kcal인가? (단, 물의 비열은 1 kcal/kg·℃이다.)", "5 kcal"),
    SubjectBatteryCase("과학", "질량 2 kg인 물체에 8 kcal의 열을 가했더니 온도가 20℃ 올라갔다. 이 물체의 비열은 몇 kcal/(kg·℃)인가?", "0.2 kcal/(kg·℃)"),
    SubjectBatteryCase("과학", "물 1 kg의 온도를 10℃에서 30℃로 높이는 데 필요한 열량은? (물의 비열 4200 J/(kg·℃))\n① 4200 J ② 42000 J ③ 84000 J ④ 126000 J ⑤ 168000 J", "3"),
    SubjectBatteryCase("과학", "20 ℃의 물 100 g과 80 ℃의 물 100 g을 섞었을 때 열평형 온도는 몇 ℃인가?", "50 ℃|50"),
    SubjectBatteryCase("과학", "10 ℃의 물 200 g과 70 ℃의 물 100 g을 섞으면 나중 온도는?\n① 20 ℃ ② 30 ℃ ③ 40 ℃ ④ 50 ℃ ⑤ 60 ℃", "2"),
    // 전기
    SubjectBatteryCase("과학", "저항이 10 Ω인 니크롬선에 2 A의 전류가 흐를 때 니크롬선에 걸리는 전압은?\n① 0.2 V ② 5 V ③ 12 V ④ 20 V ⑤ 40 V", "4"),
    SubjectBatteryCase("과학", "어떤 저항에 6 V의 전압을 걸었더니 0.5 A의 전류가 흘렀다. 이 저항의 크기는 몇 Ω인가?", "12 Ω"),
    SubjectBatteryCase("과학", "전압이 12 V인 전원에 3 Ω의 저항을 연결하면 흐르는 전류는 몇 A인가?", "4 A"),
    SubjectBatteryCase("과학", "전압 220 V에서 5 A의 전류가 흐르는 전기 기구의 소비 전력은 몇 W인가?", "1100 W"),
    SubjectBatteryCase("과학", "소비 전력이 100 W인 전구를 3시간 동안 사용했을 때 전력량은 몇 Wh인가?\n① 33 ② 103 ③ 300 ④ 3000 ⑤ 30000", "3"),
    SubjectBatteryCase("과학", "2 Ω과 3 Ω의 저항을 직렬로 연결했을 때 전체 저항은 몇 Ω인가?", "5 Ω"),
    SubjectBatteryCase("과학", "3 Ω과 6 Ω의 저항을 병렬로 연결했을 때 합성 저항은 몇 Ω인가?", "2 Ω"),
    SubjectBatteryCase("과학", "1 kW의 전열기를 30분 동안 사용했을 때 소비한 전기 에너지는 몇 kWh인가?", "0.5 kWh"),
    SubjectBatteryCase("과학", "전압 3V, 전류 0.2A일때 저항은 몇 Ω 인가", "15 Ω"),
    SubjectBatteryCase("과학", "전열기에 220 V의 전압을 걸었더니 4 A의 전류가 흘렀다. 이 전열기를 2시간 사용할 때 소비한 전력량은 몇 Wh인가?", "1760 Wh"),
    SubjectBatteryCase("과학", "저항 5 Ω에 3 A의 전류가 흐를 때 소비 전력은?\n① 15 W ② 30 W ③ 45 W ④ 75 W ⑤ 90 W", "3"),
    SubjectBatteryCase("과학", "20 Ω의 저항에 걸린 전압이 10 V일 때 흐르는 전류의 세기는?\n① 0.5 A ② 2 A ③ 10 A ④ 30 A ⑤ 200 A", "1"),
    // 농도
    SubjectBatteryCase("과학", "물 90 g에 설탕 10 g을 녹인 설탕물의 퍼센트 농도는?\n① 9 % ② 10 % ③ 11 % ④ 90 % ⑤ 100 %", "2"),
    SubjectBatteryCase("과학", "소금 20 g을 녹여 만든 소금물 200 g의 농도는 몇 %인가?", "10%"),
    SubjectBatteryCase("과학", "농도가 15 %인 소금물 300 g에 녹아 있는 소금의 질량은 몇 g인가?", "45 g"),
    SubjectBatteryCase("과학", "설탕 25 g을 물 100 g에 녹였을 때 설탕물의 농도는 몇 %인가?", "20%"),
    // 몰
    SubjectBatteryCase("과학", "물(H2O) 36 g은 몇 mol인가? (단, H의 원자량은 1, O는 16이다.)", "2 mol"),
    SubjectBatteryCase("과학", "이산화 탄소(CO2) 88 g은 몇 몰인가? (C = 12, O = 16)", "2 mol"),
    SubjectBatteryCase("과학", "0 ℃, 1기압에서 기체 44.8 L는 몇 몰인가?", "2 mol"),
    SubjectBatteryCase("과학", "메테인(CH4) 2 mol의 질량은 몇 g인가? (C = 12, H = 1)\n① 8 g ② 16 g ③ 18 g ④ 32 g ⑤ 64 g", "4"),
    // 파동
    SubjectBatteryCase("과학", "진동수가 5 Hz이고 파장이 2 m인 파동의 속력은 몇 m/s인가?\n① 0.4 ② 2.5 ③ 7 ④ 10 ⑤ 20", "4"),
    SubjectBatteryCase("과학", "속력이 340 m/s인 소리의 진동수가 170 Hz일 때 파장은 몇 m인가?", "2 m"),
    SubjectBatteryCase("과학", "주기가 0.5초인 파동의 진동수는 몇 Hz인가?", "2 Hz"),
    SubjectBatteryCase("과학", "파장이 4 m, 속력이 20 m/s인 파동의 진동수는?", "5 Hz"),

    // MARK: 과학 개념 — 세포·생명
    SubjectBatteryCase("과학", "식물 세포에서 광합성이 일어나는 장소는?\n① 핵 ② 세포막 ③ 엽록체 ④ 미토콘드리아 ⑤ 세포벽", "3"),
    SubjectBatteryCase("과학", "세포 호흡이 일어나 생명 활동에 필요한 에너지를 만드는 세포 소기관은?\n① 핵 ② 엽록체 ③ 미토콘드리아 ④ 액포 ⑤ 세포벽", "3"),
    SubjectBatteryCase("과학", "유전 물질(DNA)이 들어 있어 세포의 생명 활동을 조절하는 곳은?\n① 핵 ② 세포막 ③ 세포질 ④ 엽록체 ⑤ 액포", "1"),
    SubjectBatteryCase("과학", "세포를 둘러싸고 있으며 세포 안팎으로 물질이 드나드는 것을 조절하는 것은?\n① 세포벽 ② 세포막 ③ 핵 ④ 엽록체 ⑤ 미토콘드리아", "2"),
    SubjectBatteryCase("과학", "식물 세포의 모양을 일정하게 유지하고 세포를 보호하는 것은?\n① 세포막 ② 세포벽 ③ 핵 ④ 미토콘드리아 ⑤ 세포질", "2"),
    SubjectBatteryCase("과학", "광합성 결과 만들어지는 기체는?\n① 산소 ② 질소 ③ 수소 ④ 이산화 탄소 ⑤ 헬륨", "1"),
    SubjectBatteryCase("과학", "식물이 광합성을 할 때 필요한 기체는 무엇인가?", "이산화 탄소|이산화탄소"),
    SubjectBatteryCase("과학", "녹말을 검출할 때 사용하는 용액은?\n① 베네딕트 용액 ② 아이오딘 용액 ③ 뷰렛 용액 ④ 수단 Ⅲ 용액 ⑤ 석회수", "2"),
    SubjectBatteryCase("과학", "포도당을 검출할 때 쓰는 용액은?\n① 아이오딘 용액 ② 베네딕트 용액 ③ 뷰렛 용액 ④ 수단 Ⅲ 용액 ⑤ BTB 용액", "2"),
    SubjectBatteryCase("과학", "혈액 성분 중 산소를 운반하는 것은?\n① 혈장 ② 백혈구 ③ 적혈구 ④ 혈소판 ⑤ 림프", "3"),
    SubjectBatteryCase("과학", "상처가 났을 때 혈액을 응고시키는 혈액 성분은?", "혈소판"),
    SubjectBatteryCase("과학", "몸속에 들어온 세균을 잡아먹는 식균 작용을 하는 혈구는?\n① 적혈구 ② 백혈구 ③ 혈소판 ④ 혈장 ⑤ 헤모글로빈", "2"),
    SubjectBatteryCase("과학", "침 속에 들어 있으며 녹말을 엿당으로 분해하는 소화 효소는?\n① 펩신 ② 아밀레이스 ③ 라이페이스 ④ 트립신 ⑤ 쓸개즙", "2"),
    SubjectBatteryCase("과학", "위액에 들어 있어 단백질을 분해하는 소화 효소는?\n① 아밀레이스 ② 라이페이스 ③ 펩신 ④ 쓸개즙 ⑤ 엿당", "3"),
    // 물질·상태 변화
    SubjectBatteryCase("과학", "고체가 액체로 변하는 상태 변화를 무엇이라고 하는가?", "융해"),
    SubjectBatteryCase("과학", "액체가 기체로 변하는 현상은?\n① 융해 ② 응고 ③ 기화 ④ 액화 ⑤ 승화", "3"),
    SubjectBatteryCase("과학", "기체가 액체로 변하는 상태 변화는?", "액화"),
    SubjectBatteryCase("과학", "액체가 고체로 변하는 상태 변화는?\n① 융해 ② 응고 ③ 기화 ④ 액화 ⑤ 승화", "2"),
    SubjectBatteryCase("과학", "고체가 액체 상태를 거치지 않고 바로 기체로 변하는 현상은?", "승화"),
    SubjectBatteryCase("과학", "다음 중 열을 방출하는 상태 변화는?\n① 융해 ② 기화 ③ 응고 ④ 증발 ⑤ 끓음", "3"),
    SubjectBatteryCase("과학", "다음 중 열을 흡수하는 상태 변화가 아닌 것은?\n① 융해 ② 기화 ③ 액화 ④ 증발 ⑤ 끓음", "3"),
    SubjectBatteryCase("과학", "다음 중 혼합물인 것은?\n① 물 ② 산소 ③ 공기 ④ 금 ⑤ 이산화 탄소", "3"),
    SubjectBatteryCase("과학", "다음 중 순물질이 아닌 것은?\n① 증류수 ② 철 ③ 소금물 ④ 산소 ⑤ 설탕", "3"),
    SubjectBatteryCase("과학", "다음 중 산성 물질은?\n① 비눗물 ② 식초 ③ 석회수 ④ 암모니아수 ⑤ 설탕물", "2"),
    SubjectBatteryCase("과학", "다음 중 염기성인 것은?\n① 레몬즙 ② 식초 ③ 탄산음료 ④ 비눗물 ⑤ 염산", "4"),
    SubjectBatteryCase("과학", "<보기>에서 화합물만을 있는 대로 고른 것은?\n<보기>\nㄱ. 물\nㄴ. 산소\nㄷ. 이산화 탄소\n① ㄱ ② ㄴ ③ ㄷ ④ ㄱ, ㄷ ⑤ ㄴ, ㄷ", "4"),
    // 원소
    SubjectBatteryCase("과학", "원소 기호가 Na인 원소는?\n① 질소 ② 나트륨 ③ 네온 ④ 니켈 ⑤ 칼륨", "2"),
    SubjectBatteryCase("과학", "칼슘의 원소 기호는?", "Ca"),
    SubjectBatteryCase("과학", "철의 원소 기호로 옳은 것은?\n① Fe ② F ③ Ir ④ Te ⑤ Pb", "1"),
    SubjectBatteryCase("과학", "다음 중 원소와 원소 기호가 옳게 짝지어진 것은?\n① 구리 - Co ② 칼륨 - Ca ③ 은 - Ag ④ 금 - Ga ⑤ 수소 - He", "3"),
    SubjectBatteryCase("과학", "원자 번호가 8인 원소는?", "산소"),
    SubjectBatteryCase("과학", "원자 번호 11번 원소의 이름은?\n① 나트륨 ② 마그네슘 ③ 칼륨 ④ 리튬 ⑤ 네온", "1"),
    SubjectBatteryCase("과학", "다음 중 금속 원소가 아닌 것은?\n① 나트륨 ② 철 ③ 구리 ④ 황 ⑤ 마그네슘", "4"),
    SubjectBatteryCase("과학", "다음 중 비금속 원소는?\n① 알루미늄 ② 탄소 ③ 금 ④ 칼슘 ⑤ 아연", "2"),
    SubjectBatteryCase("과학", "원소 기호 K가 나타내는 원소는?", "칼륨"),
    // 지구과학
    SubjectBatteryCase("과학", "다음 중 퇴적암인 것은?\n① 현무암 ② 화강암 ③ 사암 ④ 편마암 ⑤ 대리암", "3"),
    SubjectBatteryCase("과학", "다음 중 화성암이 아닌 것은?\n① 현무암 ② 화강암 ③ 안산암 ④ 석회암 ⑤ 반려암", "4"),
    SubjectBatteryCase("과학", "<보기>에서 변성암만을 있는 대로 고른 것은?\n<보기>\nㄱ. 편마암\nㄴ. 셰일\nㄷ. 대리암\n① ㄱ ② ㄴ ③ ㄱ, ㄴ ④ ㄱ, ㄷ ⑤ ㄴ, ㄷ", "4"),
    SubjectBatteryCase("과학", "다음 중 지구형 행성이 아닌 것은?\n① 수성 ② 금성 ③ 화성 ④ 목성 ⑤ 지구", "4"),
    SubjectBatteryCase("과학", "태양계 행성 중 목성형 행성을 <보기>에서 모두 고른 것은?\n<보기>\nㄱ. 토성\nㄴ. 화성\nㄷ. 해왕성\n① ㄱ ② ㄴ ③ ㄷ ④ ㄱ, ㄷ ⑤ ㄴ, ㄷ", "4"),
    SubjectBatteryCase("과학", "지구에서 낮과 밤이 반복되는 까닭은?\n① 지구의 공전 ② 지구의 자전 ③ 달의 공전 ④ 태양의 자전 ⑤ 달의 자전", "2"),
    SubjectBatteryCase("과학", "기상 현상이 나타나는 대기권의 층은?\n① 대류권 ② 성층권 ③ 중간권 ④ 열권 ⑤ 외기권", "1"),
    SubjectBatteryCase("과학", "오존층이 있는 대기권의 층은?", "성층권"),
    SubjectBatteryCase("과학", "지구 내부 구조 중 액체 상태로 추정되는 층은?\n① 지각 ② 맨틀 ③ 외핵 ④ 내핵 ⑤ 모호면", "3"),
    SubjectBatteryCase("과학", "지구 내부에서 가장 큰 부피를 차지하는 층은?\n① 지각 ② 맨틀 ③ 외핵 ④ 내핵 ⑤ 대기", "2"),
    // 생물 분류
    SubjectBatteryCase("과학", "다음 중 척추동물이 아닌 것은?\n① 개구리 ② 고등어 ③ 참새 ④ 지렁이 ⑤ 뱀", "4"),
    SubjectBatteryCase("과학", "다음 중 포유류에 속하는 것은?\n① 펭귄 ② 박쥐 ③ 악어 ④ 상어 ⑤ 도롱뇽", "2"),
    SubjectBatteryCase("과학", "다음 중 곤충이 아닌 것은?\n① 나비 ② 개미 ③ 거미 ④ 메뚜기 ⑤ 잠자리", "3"),
    SubjectBatteryCase("과학", "<보기>에서 양서류만을 있는 대로 고른 것은?\n<보기>\nㄱ. 개구리\nㄴ. 도마뱀\nㄷ. 도롱뇽\n① ㄱ ② ㄴ ③ ㄱ, ㄴ ④ ㄱ, ㄷ ⑤ ㄱ, ㄴ, ㄷ", "4"),
    // 물리 개념
    SubjectBatteryCase("과학", "힘의 단위는?\n① J ② W ③ N ④ Pa ⑤ Hz", "3"),
    SubjectBatteryCase("과학", "전기 저항의 단위는?", "Ω|옴"),
    SubjectBatteryCase("과학", "빨간색 빛과 초록색 빛을 합성하면 어떤 색으로 보이는가?\n① 노란색 ② 자홍색 ③ 청록색 ④ 흰색 ⑤ 검은색", "1"),
    SubjectBatteryCase("과학", "열이 물질을 거치지 않고 직접 이동하는 열의 전달 방식은?\n① 전도 ② 대류 ③ 복사 ④ 단열 ⑤ 증발", "3"),
    SubjectBatteryCase("과학", "액체나 기체에서 물질이 직접 이동하면서 열이 전달되는 방식은?", "대류"),
    SubjectBatteryCase("과학", "물체가 원래의 운동 상태를 계속 유지하려는 성질을 무엇이라 하는가?", "관성"),
    SubjectBatteryCase("과학", "일률의 단위는?\n① N ② J ③ W ④ Pa ⑤ A", "3"),

    // MARK: 영어 — 시제
    SubjectBatteryCase("영어", "다음 빈칸에 알맞은 것은?\nI ______ to the park yesterday.\n① go ② goes ③ went ④ will go ⑤ going", "3"),
    SubjectBatteryCase("영어", "빈칸에 들어갈 말로 알맞은 것은?\nShe ______ soccer every Sunday.\n① play ② plays ③ played ④ playing ⑤ to play", "2"),
    SubjectBatteryCase("영어", "They ______ a movie tomorrow.\n① watch ② watched ③ will watch ④ watches ⑤ watching", "3"),
    SubjectBatteryCase("영어", "Look! The baby ______ now.\n① sleep ② sleeps ③ slept ④ is sleeping ⑤ was sleeping", "4"),
    SubjectBatteryCase("영어", "He ______ his homework last night.\n① do ② does ③ did ④ doing ⑤ will do", "3"),
    SubjectBatteryCase("영어", "My brother ______ breakfast every morning.\n① eat ② eats ③ ate ④ eating ⑤ to eat", "2"),
    SubjectBatteryCase("영어", "We ______ to Busan next week.\n① went ② goes ③ will go ④ going ⑤ gone", "3"),
    SubjectBatteryCase("영어", "Tom ______ a letter two days ago.\n① write ② writes ③ wrote ④ written ⑤ will write", "3"),
    SubjectBatteryCase("영어", "Listen! Someone ______ the piano.\n① play ② plays ③ is playing ④ played ⑤ to play", "3"),
    SubjectBatteryCase("영어", "I ______ very busy now.\n① am ② is ③ are ④ was ⑤ were", "1"),
    SubjectBatteryCase("영어", "They ______ at home yesterday.\n① is ② are ③ was ④ were ⑤ be", "4"),
    SubjectBatteryCase("영어", "It ______ a lot last summer.\n① rain ② rains ③ rained ④ raining ⑤ will rain", "3"),
    SubjectBatteryCase("영어", "He ______ TV every evening.\n① watch ② watches ③ watching ④ to watch ⑤ watched", "2"),
    SubjectBatteryCase("영어", "My father always ______ coffee in the morning.\n① drink ② drinks ③ drank ④ drinking ⑤ to drink", "2"),
    SubjectBatteryCase("영어", "Does she ______ to school by bus?\n① go ② goes ③ went ④ going ⑤ gone", "1"),
    SubjectBatteryCase("영어", "She doesn't ______ meat.\n① eat ② eats ③ ate ④ eating ⑤ eaten", "1"),
    SubjectBatteryCase("영어", "You can ______ my book.\n① borrow ② borrows ③ borrowed ④ borrowing ⑤ to borrow", "1"),
    SubjectBatteryCase("영어", "My mother ______ in a hospital.\n① work ② works ③ worked ④ working ⑤ to work", "2"),
    SubjectBatteryCase("영어", "I will ______ you tomorrow.\n① call ② calls ③ called ④ calling ⑤ to call", "1"),
    SubjectBatteryCase("영어", "We ______ soccer after school yesterday.\n① play ② plays ③ played ④ playing ⑤ will play", "3"),
    SubjectBatteryCase("영어", "She ______ her grandparents last Sunday.\n① visit ② visits ③ visited ④ visiting ⑤ will visit", "3"),
    SubjectBatteryCase("영어", "My sister ______ a shower now.\n① take ② takes ③ took ④ is taking ⑤ was taking", "4"),
    SubjectBatteryCase("영어", "Mr. Kim ______ English at our school every year.\n① teach ② teaches ③ taught ④ teaching ⑤ to teach", "2"),
    SubjectBatteryCase("영어", "He has already ______ his lunch.\n① eat ② ate ③ eaten ④ eating ⑤ eats", "3"),
    SubjectBatteryCase("영어", "I have ______ to Jeju Island twice.\n① be ② was ③ been ④ being ⑤ am", "3"),
    // 비교급·최상급
    SubjectBatteryCase("영어", "This box is ______ than that one.\n① heavy ② heavier ③ heaviest ④ more heavy ⑤ most heavy", "2"),
    SubjectBatteryCase("영어", "Mt. Everest is the ______ mountain in the world.\n① high ② higher ③ highest ④ more high ⑤ most high", "3"),
    SubjectBatteryCase("영어", "My bag is ______ than yours.\n① big ② bigger ③ biggest ④ more big ⑤ most big", "2"),
    SubjectBatteryCase("영어", "This question is ______ than that one.\n① difficult ② difficulter ③ more difficult ④ most difficult ⑤ the most difficult", "3"),
    SubjectBatteryCase("영어", "She is the ______ student in our class.\n① smart ② smarter ③ smartest ④ more smart ⑤ most smart", "3"),
    SubjectBatteryCase("영어", "He is as ______ as his father.\n① tall ② taller ③ tallest ④ more tall ⑤ most tall", "1"),
    SubjectBatteryCase("영어", "Today is ______ than yesterday.\n① good ② better ③ best ④ more good ⑤ most good", "2"),
    SubjectBatteryCase("영어", "This is the ______ day of my life.\n① happy ② happier ③ happiest ④ more happy ⑤ most happy", "3"),
    SubjectBatteryCase("영어", "A cheetah runs ______ than a horse.\n① fast ② faster ③ fastest ④ more fast ⑤ most fast", "2"),
    SubjectBatteryCase("영어", "This movie is ______ than the book.\n① interesting ② more interesting ③ most interesting ④ interestinger ⑤ the most interesting", "2"),
    // 수동태
    SubjectBatteryCase("영어", "This letter was ______ by Tom.\n① write ② wrote ③ written ④ writing ⑤ writes", "3"),
    SubjectBatteryCase("영어", "The window was ______ by the boy.\n① break ② broke ③ broken ④ breaking ⑤ breaks", "3"),
    SubjectBatteryCase("영어", "The house was ______ by my grandfather in 1990.\n① build ② built ③ building ④ builds ⑤ to build", "2"),
    SubjectBatteryCase("영어", "The song is loved ______ many people.\n① by ② at ③ on ④ in ⑤ for", "1"),
    SubjectBatteryCase("영어", "The cake was ______ by my mom.\n① make ② makes ③ made ④ making ⑤ to make", "3"),
    // to부정사·동명사
    SubjectBatteryCase("영어", "I enjoy ______ soccer with my friends.\n① play ② to play ③ playing ④ played ⑤ plays", "3"),
    SubjectBatteryCase("영어", "She wants ______ a doctor.\n① be ② to be ③ being ④ been ⑤ is", "2"),
    SubjectBatteryCase("영어", "He finished ______ his homework.\n① do ② to do ③ doing ④ did ⑤ does", "3"),
    SubjectBatteryCase("영어", "We decided ______ the trip.\n① cancel ② to cancel ③ canceling ④ canceled ⑤ cancels", "2"),
    SubjectBatteryCase("영어", "Would you mind ______ the window?\n① open ② to open ③ opening ④ opened ⑤ opens", "3"),
    SubjectBatteryCase("영어", "I hope ______ you again.\n① see ② to see ③ seeing ④ saw ⑤ seen", "2"),
    SubjectBatteryCase("영어", "He gave up ______.\n① smoke ② to smoke ③ smoking ④ smoked ⑤ smokes", "3"),
    SubjectBatteryCase("영어", "They plan ______ a new house.\n① buy ② to buy ③ buying ④ bought ⑤ buys", "2"),
    SubjectBatteryCase("영어", "My sister avoids ______ junk food.\n① eat ② to eat ③ eating ④ ate ⑤ eats", "3"),
    SubjectBatteryCase("영어", "She promised ______ me.\n① help ② to help ③ helping ④ helped ⑤ helps", "2"),
    // 관계대명사
    SubjectBatteryCase("영어", "I have a friend ______ lives in Canada.\n① who ② which ③ what ④ whose ⑤ where", "1"),
    SubjectBatteryCase("영어", "This is the book ______ I bought yesterday.\n① who ② which ③ whose ④ what ⑤ where", "2"),
    SubjectBatteryCase("영어", "The girl ______ is singing is my sister.\n① which ② who ③ whose ④ what ⑤ when", "2"),
    SubjectBatteryCase("영어", "I know a boy ______ father is a pilot.\n① who ② which ③ whose ④ that ⑤ what", "3"),
    SubjectBatteryCase("영어", "This is the house ______ has a big garden.\n① who ② which ③ whose ④ what ⑤ where", "2"),
    SubjectBatteryCase("영어", "The man ______ I met yesterday was kind.\n① which ② whom ③ whose ④ what ⑤ where", "2"),
    SubjectBatteryCase("영어", "I like the dog ______ has long ears.\n① who ② which ③ whose ④ what ⑤ whom", "2"),
    // 단어 뜻
    SubjectBatteryCase("영어", "다음 단어의 뜻으로 알맞은 것은?\nabundant\n① 부족한 ② 풍부한 ③ 위험한 ④ 정확한 ⑤ 추상적인", "2"),
    SubjectBatteryCase("영어", "'absorb'의 뜻으로 알맞은 것은?\n① 흡수하다 ② 방출하다 ③ 포기하다 ④ 성취하다 ⑤ 동행하다", "1"),
    SubjectBatteryCase("영어", "다음 중 '능력'을 뜻하는 영어 단어는?\n① absence ② ability ③ access ④ accident ⑤ abroad", "2"),
    SubjectBatteryCase("영어", "accident의 뜻을 쓰시오.", "~사고"),
    SubjectBatteryCase("영어", "다음 단어의 뜻으로 알맞은 것은? ancient\n① 고대의 ② 현대의 ③ 미래의 ④ 유명한 ⑤ 다양한", "1"),
    SubjectBatteryCase("영어", "다음 중 단어와 뜻이 바르게 연결된 것은?\n① honest - 공손한 ② famous - 유명한 ③ rare - 흔한 ④ similar - 다른 ⑤ effort - 의견", "2"),
    SubjectBatteryCase("영어", "'환경'을 뜻하는 영어 단어는?\n① environment ② opinion ③ benefit ④ effort ⑤ support", "1"),
    SubjectBatteryCase("영어", "다음 중 enormous의 뜻으로 알맞은 것은?\n① 작은 ② 거대한 ③ 빠른 ④ 느린 ⑤ 정직한", "2"),
    SubjectBatteryCase("영어", "다음 단어의 뜻으로 알맞지 않은 것은? support\n① 지지하다 ② 지지 ③ 반대하다", "3"),
    SubjectBatteryCase("영어", "curious의 우리말 뜻은?\n① 호기심 많은 ② 게으른 ③ 용감한 ④ 친절한 ⑤ 조용한", "1"),

    // MARK: 사회·역사 — 수도·지리
    SubjectBatteryCase("사회", "프랑스의 수도는?\n① 런던 ② 베를린 ③ 파리 ④ 로마 ⑤ 마드리드", "3"),
    SubjectBatteryCase("사회", "캐나다의 수도는 어디인가?", "오타와"),
    SubjectBatteryCase("사회", "다음 중 나라와 수도가 바르게 짝지어진 것은?\n① 일본 - 오사카 ② 중국 - 상하이 ③ 캐나다 - 오타와 ④ 미국 - 뉴욕 ⑤ 브라질 - 리우데자네이루", "3"),
    SubjectBatteryCase("사회", "수도가 하노이인 나라는?\n① 태국 ② 베트남 ③ 필리핀 ④ 캄보디아 ⑤ 라오스", "2"),
    SubjectBatteryCase("사회", "튀르키예의 수도는?", "앙카라"),
    SubjectBatteryCase("사회", "이집트의 수도는?\n① 카이로 ② 나이로비 ③ 리야드 ④ 테헤란 ⑤ 바그다드", "1"),
    SubjectBatteryCase("사회", "다음 중 아시아에 있는 나라가 아닌 것은?\n① 몽골 ② 태국 ③ 칠레 ④ 인도 ⑤ 베트남", "3"),
    SubjectBatteryCase("사회", "다음 중 남아메리카에 위치한 나라는?\n① 멕시코 ② 아르헨티나 ③ 스페인 ④ 이집트 ⑤ 캐나다", "2"),
    SubjectBatteryCase("사회", "독일의 수도는 어디인가?\n① 빈 ② 베를린 ③ 베른 ④ 프라하 ⑤ 브뤼셀", "2"),
    SubjectBatteryCase("사회", "경도 15°마다 몇 시간의 시차가 생기는가?", "1시간|1"),
    SubjectBatteryCase("사회", "우리나라 표준시의 기준이 되는 경선은?\n① 동경 120° ② 동경 127.5° ③ 동경 135° ④ 서경 135° ⑤ 경도 0°", "3"),
    // 역사
    SubjectBatteryCase("사회", "임진왜란이 일어난 해는?\n① 1392년 ② 1446년 ③ 1592년 ④ 1636년 ⑤ 1910년", "3"),
    SubjectBatteryCase("사회", "훈민정음이 반포된 해는?", "1446년|1446"),
    SubjectBatteryCase("사회", "조선이 건국된 해는 언제인가?", "1392년|1392"),
    SubjectBatteryCase("사회", "3·1 운동이 일어난 해는?\n① 1910년 ② 1919년 ③ 1945년 ④ 1950년 ⑤ 1960년", "2"),
    SubjectBatteryCase("사회", "6·25 전쟁이 일어난 해는?", "1950년|1950"),
    SubjectBatteryCase("사회", "다음 사건 중 가장 먼저 일어난 것은?\n① 병자호란 ② 임진왜란 ③ 3·1 운동 ④ 6·25 전쟁 ⑤ 광복", "2"),
    SubjectBatteryCase("사회", "다음 중 가장 나중에 일어난 사건은?\n① 고려 건국 ② 조선 건국 ③ 신라의 삼국 통일 ④ 훈민정음 반포 ⑤ 임진왜란", "5"),
    SubjectBatteryCase("사회", "프랑스 혁명이 일어난 해는?", "1789년|1789"),
    SubjectBatteryCase("사회", "고려를 세운 인물은?\n① 왕건 ② 이성계 ③ 궁예 ④ 견훤 ⑤ 김춘추", "1"),
    SubjectBatteryCase("사회", "대한민국 정부가 수립된 해는?\n① 1945년 ② 1948년 ③ 1950년 ④ 1953년 ⑤ 1960년", "2"),
    SubjectBatteryCase("사회", "광복은 몇 년에 이루어졌는가?", "1945년|1945"),
    SubjectBatteryCase("사회", "조선을 세운 인물은?\n① 왕건 ② 이성계 ③ 정도전 ④ 세종 ⑤ 이방원", "2"),
    // 정치·경제 개념
    SubjectBatteryCase("사회", "어떤 것을 선택함으로써 포기한 것 중 가장 가치가 큰 것을 무엇이라 하는가?\n① 희소성 ② 기회비용 ③ 편익 ④ 매몰 비용 ⑤ 효용", "2"),
    SubjectBatteryCase("사회", "인간의 욕구에 비해 자원이 상대적으로 부족한 현상은?\n① 희귀성 ② 희소성 ③ 기회비용 ④ 인플레이션 ⑤ 실업", "2"),
    SubjectBatteryCase("사회", "물가가 지속적으로 오르는 현상을 무엇이라 하는가?", "인플레이션"),
    SubjectBatteryCase("사회", "국가 권력을 입법권, 행정권, 사법권으로 나누어 서로 견제하게 하는 원리는?\n① 국민 주권 ② 권력 분립 ③ 법치주의 ④ 입헌주의 ⑤ 국민 자치", "2"),
    SubjectBatteryCase("사회", "법을 만드는 입법권을 가진 국가 기관은?\n① 정부 ② 법원 ③ 국회 ④ 헌법 재판소 ⑤ 감사원", "3"),
    SubjectBatteryCase("사회", "재판을 통해 법을 적용하는 사법권을 가진 기관은?", "법원"),
    SubjectBatteryCase("사회", "다음 중 사회권에 해당하는 것은?\n① 선거권 ② 교육을 받을 권리 ③ 재판 청구권 ④ 신체의 자유 ⑤ 종교의 자유", "2"),
    SubjectBatteryCase("사회", "다음 중 참정권이 아닌 것은?\n① 선거권 ② 피선거권 ③ 공무 담임권 ④ 국민 투표권 ⑤ 청원권", "5"),
    SubjectBatteryCase("사회", "한 사람이 한 표씩 투표하는 선거의 원칙은?\n① 보통 선거 ② 평등 선거 ③ 직접 선거 ④ 비밀 선거 ⑤ 자유 선거", "2"),
    SubjectBatteryCase("사회", "다음 중 직접세는?\n① 부가 가치세 ② 개별 소비세 ③ 소득세 ④ 주세 ⑤ 관세", "3"),
    SubjectBatteryCase("사회", "다음 중 사회 보험에 해당하지 않는 것은?\n① 국민연금 ② 건강 보험 ③ 고용 보험 ④ 국민 기초 생활 보장 ⑤ 산업 재해 보상 보험", "4"),
    SubjectBatteryCase("사회", "가격이 오르면 수요량이 감소하는 법칙은?", "수요 법칙|수요의 법칙"),
    SubjectBatteryCase("사회", "다음 중 3차 산업에 해당하는 것은?\n① 농업 ② 어업 ③ 제조업 ④ 금융업 ⑤ 광업", "4"),
    SubjectBatteryCase("사회", "다음 중 재생 에너지가 아닌 것은?\n① 태양광 ② 풍력 ③ 석탄 ④ 지열 ⑤ 조력", "3"),
    SubjectBatteryCase("사회", "자기 문화만 우월하다고 여기고 다른 문화를 낮게 평가하는 태도는?\n① 문화 상대주의 ② 자문화 중심주의 ③ 문화 사대주의 ④ 문화 다양성 ⑤ 세계화", "2"),
    SubjectBatteryCase("사회", "각 문화를 그 사회의 자연환경과 역사적 맥락에서 이해하려는 태도는?", "문화 상대주의"),
    SubjectBatteryCase("사회", "삼권 분립을 주장한 사상가는?\n① 로크 ② 루소 ③ 몽테스키외 ④ 홉스 ⑤ 벤담", "3"),
    SubjectBatteryCase("사회", "<보기>에서 자유권에 해당하는 것만을 있는 대로 고른 것은?\n<보기>\nㄱ. 종교의 자유\nㄴ. 선거권\nㄷ. 거주·이전의 자유\n① ㄱ ② ㄴ ③ ㄱ, ㄴ ④ ㄱ, ㄷ ⑤ ㄴ, ㄷ", "4"),
    SubjectBatteryCase("사회", "물가가 지속적으로 내려가는 현상은?\n① 인플레이션 ② 디플레이션 ③ 스태그플레이션 ④ 실업 ⑤ 환율", "2"),

    // MARK: 국어 — 맞춤법
    SubjectBatteryCase("국어", "다음 중 맞춤법이 바른 문장은?\n① 오늘은 왠지 기분이 좋다. ② 몇일 뒤에 만나자. ③ 숙제를 금새 끝냈다. ④ 그는 일부로 늦게 왔다. ⑤ 설겆이를 했다.", "1"),
    SubjectBatteryCase("국어", "밑줄 친 부분의 맞춤법이 틀린 것은?\n① 오랜만에 친구를 만났다. ② 금세 비가 그쳤다. ③ 그 일은 내가 할께. ④ 굳이 그럴 필요 없다. ⑤ 깨끗이 씻어라.", "3"),
    SubjectBatteryCase("국어", "다음 중 맞춤법이 옳은 것은?\n① 웬일이니? ② 왠일이니? ③ 웬지 ④ 왠만하면", "1"),
    SubjectBatteryCase("국어", "다음 문장 중 맞춤법이 틀린 것은?\n① 역할을 나누었다. ② 희한한 일이 생겼다. ③ 곰곰히 생각했다. ④ 꼼꼼히 확인했다. ⑤ 솔직히 말해.", "3"),
    SubjectBatteryCase("국어", "다음 중 표준어가 아닌 것은?\n① 웃어른 ② 윗사람 ③ 윗층 ④ 위층 ⑤ 아랫니", "3"),
    SubjectBatteryCase("국어", "‘됬다’를 바르게 고쳐 쓰시오.", "됐다"),
    SubjectBatteryCase("국어", "다음 중 맞춤법이 바른 것은?\n① 어떻해 ② 어떡해 ③ 어떡게 ④ 어떻케", "2"),
    SubjectBatteryCase("국어", "다음 중 맞춤법이 틀린 것은?\n① 거예요 ② 돼요 ③ 할게요 ④ 되서 ⑤ 며칠", "4"),
    SubjectBatteryCase("국어", "다음 중 바르게 쓴 것은?\n① 내일 뵈요. ② 내일 봬요. ③ 몇일 뒤 봬요. ④ 금새 뵈요.", "2"),
    SubjectBatteryCase("국어", "다음 중 맞춤법에 맞게 쓴 것은?\n① 설겆이 ② 설거지 ③ 오랫만 ④ 희안하다 ⑤ 역활", "2"),
    SubjectBatteryCase("국어", "다음 중 띄어쓰기가 바른 것은?\n① 할수있다 ② 할 수 있다 ③ 할수 있다 ④ 할 수있다", "2"),
    SubjectBatteryCase("국어", "‘일부로’를 바르게 고치면?", "일부러"),

    // MARK: 다른 말투로 만든 문제 (규칙이 문장 모양에 묶이지 않았는지 보기)
    SubjectBatteryCase("과학", "어떤 자동차가 2시간 동안 120 km를 달렸다. 이 자동차의 속력은?\n① 30 km/h ② 60 km/h ③ 120 km/h ④ 240 km/h ⑤ 600 km/h", "2"),
    SubjectBatteryCase("과학", "10초 동안 50 m를 이동한 물체의 빠르기는 몇 m/s인가?", "5 m/s"),
    SubjectBatteryCase("과학", "질량 10 kg인 수레에 20 N의 힘을 가하면 가속도는 몇 m/s²인가?", "2 m/s²"),
    SubjectBatteryCase("과학", "물체에 작용하는 힘이 15 N이고 물체의 질량이 3 kg일 때 가속도의 크기는?\n①3 ②5 ③12 ④18 ⑤45", "2"),
    SubjectBatteryCase("과학", "부피가 100 cm³이고 질량이 250 g인 금속의 밀도는?", "2.5 g/cm³"),
    SubjectBatteryCase("과학", "어떤 액체 200 mL의 질량이 160 g일 때, 이 액체의 밀도는 몇 g/mL인가?\n① 0.8 ② 1.25 ③ 8 ④ 40 ⑤ 360", "1"),
    SubjectBatteryCase("과학", "1000 N의 힘이 0.5 m² 넓이에 작용할 때의 압력은?", "2000 Pa"),
    SubjectBatteryCase("과학", "15 N의 힘으로 물체를 4 m 끌었다. 물체에 한 일의 양은 몇 J인가?\n① 3.75 ② 11 ③ 19 ④ 60 ⑤ 600", "4"),
    SubjectBatteryCase("과학", "2분 동안 1200 J의 일을 했을 때 일률은 몇 W인가?", "10 W"),
    SubjectBatteryCase("과학", "질량 1 kg인 물체가 10 m/s의 속력으로 날아갈 때 운동 에너지는?", "50 J"),
    SubjectBatteryCase("과학", "질량 5 kg인 물체를 바닥으로부터 2 m 높이에 올려놓았다. 이 물체의 위치 에너지는 몇 J인가? (단, 중력 가속도는 10 m/s²이다.)", "100 J"),
    SubjectBatteryCase("과학", "4 Ω의 저항에 8 V의 전압을 걸었을 때 흐르는 전류는 몇 A인가?\n① 0.5 ② 2 ③ 4 ④ 12 ⑤ 32", "2"),
    SubjectBatteryCase("과학", "전류가 0.5 A, 저항이 20 Ω일 때 전압은?", "10 V"),
    SubjectBatteryCase("과학", "100 V에서 2 A의 전류가 흐르는 전기 기구를 5시간 사용했다. 사용한 전력량은 몇 kWh인가?", "1 kWh"),
    SubjectBatteryCase("과학", "소금 30 g을 물 120 g에 녹였다. 이 소금물의 퍼센트 농도는?\n① 15 % ② 20 % ③ 25 % ④ 30 % ⑤ 80 %", "2"),
    SubjectBatteryCase("과학", "농도가 10 %인 설탕물 500 g 속에 들어 있는 설탕의 질량은 몇 g인가?", "50 g"),
    SubjectBatteryCase("과학", "진동수 2 Hz, 파장 3 m인 파도의 속력은 몇 m/s인가?", "6 m/s"),
    SubjectBatteryCase("과학", "물 2 kg의 온도를 5 ℃ 높이는 데 필요한 열량은 몇 kcal인가? (물의 비열 1 kcal/(kg·℃))", "10 kcal"),
    SubjectBatteryCase("과학", "6. 전압3V 전류 2A 전기기구 전력은몇W", "6 W"),
    SubjectBatteryCase("과학", "질량 600 g인 물체의 무게는 몇 N인가? (단, 1 kg의 무게는 10 N)", "6 N"),
    SubjectBatteryCase("과학", "광합성이 일어나는 세포 속 구조는?\n① 핵 ② 엽록체 ③ 액포 ④ 세포벽 ⑤ 세포막", "2"),
    SubjectBatteryCase("과학", "얼음이 녹아 물이 되는 상태 변화는?\n① 융해 ② 응고 ③ 기화 ④ 액화 ⑤ 승화", "1"),
    SubjectBatteryCase("과학", "다음 중 원소 기호가 Cu인 것은?\n① 탄소 ② 구리 ③ 칼슘 ④ 염소 ⑤ 코발트", "2"),
    SubjectBatteryCase("과학", "산소의 원소 기호를 쓰시오.", "O"),
    SubjectBatteryCase("과학", "다음 중 화성암에 속하는 것은?\n① 사암 ② 셰일 ③ 화강암 ④ 대리암 ⑤ 석회암", "3"),
    SubjectBatteryCase("과학", "다음 중 어류에 해당하는 것은?\n① 고래 ② 상어 ③ 돌고래 ④ 펭귄 ⑤ 거북", "2"),
    SubjectBatteryCase("과학", "다음 중 무척추동물은?\n① 개 ② 문어 ③ 개구리 ④ 뱀 ⑤ 붕어", "2"),
    SubjectBatteryCase("과학", "다음 중 내행성은?\n① 금성 ② 화성 ③ 목성 ④ 토성 ⑤ 해왕성", "1"),
    SubjectBatteryCase("과학", "혈액의 성분 중 혈액 응고 작용을 하는 것은?\n① 적혈구 ② 백혈구 ③ 혈소판 ④ 혈장", "3"),
    SubjectBatteryCase("과학", "전류의 단위는?\n① V ② A ③ Ω ④ W ⑤ J", "2"),
    SubjectBatteryCase("영어", "Jane ______ her room every Saturday.\n① clean ② cleans ③ cleaned ④ cleaning ⑤ to clean", "2"),
    SubjectBatteryCase("영어", "We ______ pizza last Friday.\n① eat ② eats ③ ate ④ eating ⑤ eaten", "3"),
    SubjectBatteryCase("영어", "Be quiet! The students ______ now.\n① study ② studies ③ studied ④ are studying ⑤ is studying", "4"),
    SubjectBatteryCase("영어", "I ______ my grandmother next Sunday.\n① visit ② visited ③ will visit ④ visits ⑤ visiting", "3"),
    SubjectBatteryCase("영어", "My friends ______ tennis every weekend.\n① play ② plays ③ played ④ playing ⑤ is playing", "1"),
    SubjectBatteryCase("영어", "She can ______ three languages.\n① speak ② speaks ③ spoke ④ spoken ⑤ speaking", "1"),
    SubjectBatteryCase("영어", "Mina is ______ than her sister.\n① young ② younger ③ youngest ④ more young ⑤ most young", "2"),
    SubjectBatteryCase("영어", "This is the ______ building in our city.\n① tall ② taller ③ tallest ④ more tall ⑤ most tall", "3"),
    SubjectBatteryCase("영어", "Seoul is ______ than Busan.\n① big ② bigger ③ biggest ④ more big ⑤ most big", "2"),
    SubjectBatteryCase("영어", "The book was ______ by a famous writer.\n① write ② wrote ③ written ④ writing ⑤ writes", "3"),
    SubjectBatteryCase("영어", "I finished ______ the report.\n① write ② to write ③ writing ④ wrote ⑤ written", "3"),
    SubjectBatteryCase("영어", "He wants ______ a new bike.\n① buy ② to buy ③ buying ④ bought ⑤ buys", "2"),
    SubjectBatteryCase("영어", "I have an uncle ______ lives in Japan.\n① who ② which ③ whose ④ what ⑤ where", "1"),
    SubjectBatteryCase("영어", "This is the cake ______ my mom made.\n① who ② which ③ whose ④ what ⑤ where", "2"),
    SubjectBatteryCase("영어", "다음 단어의 뜻으로 알맞은 것은? opinion\n① 의견 ② 노력 ③ 환경 ④ 이익 ⑤ 지지", "1"),
    SubjectBatteryCase("영어", "'decrease'의 뜻은?\n① 증가하다 ② 감소하다 ③ 유지하다 ④ 흡수하다 ⑤ 버리다", "2"),
    SubjectBatteryCase("영어", "Did you ______ the news yesterday?\n① hear ② heard ③ hears ④ hearing ⑤ to hear", "1"),
    SubjectBatteryCase("사회", "일본의 수도는?\n① 오사카 ② 교토 ③ 도쿄 ④ 삿포로 ⑤ 나고야", "3"),
    SubjectBatteryCase("사회", "영국의 수도를 쓰시오.", "런던"),
    SubjectBatteryCase("사회", "다음 중 유럽에 있는 나라는?\n① 브라질 ② 이집트 ③ 독일 ④ 인도 ⑤ 캐나다", "3"),
    SubjectBatteryCase("사회", "한국 전쟁(6·25 전쟁)이 일어난 해는?\n① 1945년 ② 1948년 ③ 1950년 ④ 1953년 ⑤ 1960년", "3"),
    SubjectBatteryCase("사회", "병자호란이 일어난 해는?", "1636년|1636"),
    SubjectBatteryCase("사회", "다음 중 가장 먼저 일어난 사건은?\n① 3·1 운동 ② 광복 ③ 6·25 전쟁 ④ 대한민국 정부 수립", "1"),
    SubjectBatteryCase("사회", "물가가 계속해서 하락하는 현상은?", "디플레이션"),
    SubjectBatteryCase("사회", "다음 중 청구권에 해당하는 것은?\n① 선거권 ② 재판 청구권 ③ 환경권 ④ 종교의 자유 ⑤ 평등권", "2"),
    SubjectBatteryCase("사회", "다음 중 1차 산업에 해당하는 것은?\n① 제조업 ② 농업 ③ 금융업 ④ 건설업 ⑤ 관광업", "2"),
    SubjectBatteryCase("사회", "다음 중 화석 연료가 아닌 것은?\n① 석탄 ② 석유 ③ 천연가스 ④ 풍력", "4"),
    SubjectBatteryCase("사회", "법률을 만드는 기관은?", "국회"),
    SubjectBatteryCase("국어", "다음 중 바르게 쓴 말은?\n① 희안하다 ② 희한하다", "2"),
    SubjectBatteryCase("국어", "다음 문장 중 맞춤법이 틀린 것은?\n① 숙제를 금세 끝냈다. ② 그는 일부러 웃었다. ③ 며칠 동안 비가 왔다. ④ 깨끗히 청소했다.", "4"),

    // MARK: 사진 글 모양 (줄바꿈 선지, (1) 번호, 띄어쓰기 빠짐, 문제 번호)
    SubjectBatteryCase("과학", "12. 질량이 3kg인 물체에 12N의 힘이 작용할 때 물체의 가속도의 크기는?\n① 2m/s²\n② 4m/s²\n③ 9m/s²\n④ 15m/s²\n⑤ 36m/s²", "2"),
    SubjectBatteryCase("과학", "3. 밀도가 0.5g/cm³인 나무 도막의 부피가 40cm³일때 질량은 몇g인가?", "20 g"),
    SubjectBatteryCase("과학", "저항이 6Ω인 전구에 3A의 전류가 흐른다. 전구에 걸린 전압은?\n(1) 2V (2) 3V (3) 9V (4) 18V (5) 36V", "4"),
    SubjectBatteryCase("과학", "07 질량 2 kg인 공이 4 m/s 의 속력으로 움직인다. 이 공의 운동에너지는 몇 J 인가?\n① 4 ② 8 ③ 16 ④ 32 ⑤ 64", "3"),
    SubjectBatteryCase("과학", "물 50g 에 소금 50g을 녹인 소금물의 농도는 몇 % 인가?", "50%"),
    SubjectBatteryCase("과학", "파장이 0.5 m 이고 진동수가 680 Hz 인 소리의 속력은?\n① 170 m/s ② 340 m/s ③ 680 m/s ④ 1360 m/s ⑤ 3400 m/s", "2"),
    SubjectBatteryCase("과학", "다음 중 동물 세포와 식물 세포에 모두 있는 것은?\n① 세포벽 ② 엽록체 ③ 핵 ④ 액포", "3"),
    SubjectBatteryCase("과학", "8. 다음중 비금속원소인것은?\n① 철 ② 구리 ③ 산소 ④ 나트륨 ⑤ 칼슘", "3"),
    SubjectBatteryCase("과학", "다음 중 변성암에 해당하지 않는 것은?\n① 편마암 ② 대리암 ③ 규암 ④ 역암", "4"),
    SubjectBatteryCase("과학", "원자 번호 6번인 원소의 원소 기호는?", "C"),
    SubjectBatteryCase("과학", "다음 중 조류에 속하는 동물은?\n① 박쥐 ② 타조 ③ 거북 ④ 개구리 ⑤ 고래", "2"),
    SubjectBatteryCase("과학", "다음 중 혼합물이 아닌 것은?\n① 공기 ② 바닷물 ③ 우유 ④ 증류수 ⑤ 흙탕물", "4"),
    SubjectBatteryCase("영어", "5. 빈칸에 알맞은 말은? My dad ______ to work by subway every day.\n① go ② goes ③ went ④ going ⑤ gone", "2"),
    SubjectBatteryCase("영어", "괄호 안에 알맞은 것은?\nThey ( ) to the zoo last weekend.\n① go ② goes ③ went ④ will go ⑤ going", "3"),
    SubjectBatteryCase("영어", "다음 빈칸에 들어갈 말로 가장 적절한 것은?\nMy room is ______ than my sister's room.\n(1) small (2) smaller (3) smallest (4) more small (5) most small", "2"),
    SubjectBatteryCase("영어", "The pictures were ______ by Picasso.\n① paint ② painted ③ painting ④ paints ⑤ to paint", "2"),
    SubjectBatteryCase("영어", "Minsu ______ his bike tomorrow.\n① ride ② rode ③ will ride ④ rides ⑤ riding", "3"),
    SubjectBatteryCase("영어", "We enjoyed ______ to music.\n① listen ② to listen ③ listening ④ listened ⑤ listens", "3"),
    SubjectBatteryCase("영어", "She is a singer ______ songs are popular.\n① who ② which ③ whose ④ what ⑤ whom", "3"),
    SubjectBatteryCase("영어", "다음 중 단어와 뜻의 연결이 바른 것은?\n① ancient - 현대의 ② benefit - 이익 ③ available - 불가능한 ④ various - 같은 ⑤ polite - 무례한", "2"),
    SubjectBatteryCase("사회", "4. 다음중 아프리카에 있는 나라는?\n① 케냐 ② 페루 ③ 태국 ④ 스웨덴 ⑤ 멕시코", "1"),
    SubjectBatteryCase("사회", "베트남의 수도로 옳은 것은?\n① 방콕 ② 하노이 ③ 마닐라 ④ 자카르타 ⑤ 프놈펜", "2"),
    SubjectBatteryCase("사회", "임진왜란은 몇 년에 일어났나요?", "1592년|1592"),
    SubjectBatteryCase("사회", "다음 중 가장 나중에 일어난 일은?\n① 임진왜란 ② 병자호란 ③ 훈민정음 반포 ④ 조선 건국", "2"),
    SubjectBatteryCase("사회", "다음 중 간접세에 해당하는 것은?\n① 소득세 ② 법인세 ③ 부가 가치세 ④ 상속세 ⑤ 재산세", "3"),
    SubjectBatteryCase("사회", "다음 중 2차 산업은?\n① 어업 ② 제조업 ③ 상업 ④ 관광업 ⑤ 임업", "2"),
    SubjectBatteryCase("사회", "누구나 일정한 나이가 되면 선거권을 갖는 선거의 원칙은?\n① 보통 선거 ② 평등 선거 ③ 직접 선거 ④ 비밀 선거", "1"),
    SubjectBatteryCase("국어", "다음 중 맞춤법에 맞는 것은?\n① 할께요 ② 할게요 ③ 할깨요 ④ 할개요", "2"),
    SubjectBatteryCase("국어", "밑줄 친 말의 표기가 바른 것은?\n① 오늘 몇일이야? ② 금새 끝났다. ③ 웬일로 왔니? ④ 됬어, 그만해.", "3")
]

/// 풀면 안 되는 문제: 단서가 없거나 둘 이상이 맞거나 자료에 없는 것 (규칙 풀이가 nil이어야 함)
let subjectTraps: [SubjectBatteryCase] = [
    SubjectBatteryCase("영어", "I ______ to school.\n① go ② went ③ will go ④ going ⑤ gone", ""),
    SubjectBatteryCase("영어", "She is the teacher ______ everyone likes.\n① who ② which ③ that ④ whose ⑤ what", ""),
    SubjectBatteryCase("영어", "This is the ______ of the two.\n① tall ② taller ③ tallest ④ more tall ⑤ most tall", ""),
    SubjectBatteryCase("영어", "Last night, I ______ TV and my brother ______ a book.\n① watch ② watched ③ watches ④ watching ⑤ will watch", ""),
    SubjectBatteryCase("영어", "Yesterday I ______ a movie, and tomorrow I will see another.\n① see ② saw ③ will see ④ seeing ⑤ seen", ""),
    SubjectBatteryCase("영어", "I like ______ books.\n① read ② reads ③ reading ④ to read ⑤ readed", ""),
    SubjectBatteryCase("과학", "질량이 2 kg인 물체의 운동 에너지는 몇 J인가?\n① 2 J ② 4 J ③ 9.8 J ④ 19.6 J ⑤ 40 J", ""),
    SubjectBatteryCase("과학", "다음 중 광합성에 대한 설명으로 옳은 것은?\n① 밤에만 일어난다. ② 산소를 흡수한다. ③ 엽록체에서 일어난다. ④ 이산화 탄소를 방출한다. ⑤ 뿌리에서 일어난다.", ""),
    SubjectBatteryCase("과학", "다음 중 퇴적암인 것은?\n① 현무암 ② 사암 ③ 석회암 ④ 화강암 ⑤ 편마암", ""),
    SubjectBatteryCase("과학", "다음 중 포유류가 아닌 것은?\n① 고래 ② 박쥐 ③ 오리너구리 ④ 개 ⑤ 소", ""),
    SubjectBatteryCase("과학", "속력이 2 m/s인 물체의 질량은 몇 kg인가?\n① 1 ② 2 ③ 3 ④ 4 ⑤ 5", ""),
    SubjectBatteryCase("과학", "세포 호흡 결과 생성되는 기체는?\n① 미토콘드리아 ② 엽록체 ③ 핵 ④ 세포막 ⑤ 액포", ""),
    SubjectBatteryCase("사회", "임진왜란 이후에 일어난 사건은?\n① 병자호란 ② 고려 건국 ③ 조선 건국 ④ 훈민정음 반포 ⑤ 삼국 통일", ""),
    SubjectBatteryCase("사회", "다음 중 수도가 아닌 도시는?\n① 파리 ② 런던 ③ 뉴욕 ④ 베를린 ⑤ 로마", ""),
    SubjectBatteryCase("국어", "다음 중 맞춤법이 바른 것은?\n① 금세 ② 며칠 ③ 몇일 ④ 금새", ""),
    SubjectBatteryCase("국어", "다음 중 맞춤법이 틀린 것은?\n① 몇일 ② 금새 ③ 며칠 ④ 금세", ""),
    SubjectBatteryCase("과학", "전압이 6 V인 전원에 2 Ω과 4 Ω의 저항을 연결하였다. 흐르는 전류는 몇 A인가?\n① 1 ② 1.5 ③ 2 ④ 3 ⑤ 12", ""),
    SubjectBatteryCase("과학", "1시간 30분 동안 90 km를 이동한 자동차의 속력은 몇 km/h인가?\n① 30 ② 45 ③ 60 ④ 90 ⑤ 135", ""),
    SubjectBatteryCase("영어", "The boys in the park ______ soccer every day.\n① play ② plays ③ played ④ playing ⑤ to play", ""),
    SubjectBatteryCase("영어", "Where ______ you go yesterday?\n① go ② went ③ goes ④ going ⑤ gone", ""),
    SubjectBatteryCase("영어", "There ______ many people at the party yesterday.\n① is ② are ③ was ④ were ⑤ be", ""),
    SubjectBatteryCase("영어", "I would like ______ some coffee.\n① drink ② drinks ③ drinking ④ drank ⑤ drunk", ""),
    SubjectBatteryCase("영어", "다음 중 abundant와 뜻이 반대인 것은?\n① 풍부한 ② 부족한 ③ 거대한 ④ 다양한 ⑤ 드문", ""),
    SubjectBatteryCase("영어", "This is the book ______ students read most.\n① who ② which ③ whose ④ what ⑤ where", ""),
    SubjectBatteryCase("사회", "다음 중 유럽 연합(EU) 회원국이 아닌 것은?\n① 프랑스 ② 독일 ③ 이탈리아 ④ 노르웨이 ⑤ 캐나다", ""),
    SubjectBatteryCase("영어", "This bag is less ______ than that one.\n① expensive ② more expensive ③ most expensive ④ expensiver ⑤ the most expensive", "")
]

/// 단답 답이 맞는지: 글이 같거나, 수가 같고 단위가 같으면 (단위 없는 정답은 수만)
func subjectMatches(_ answer: String, expected: String) -> Bool {
    func squash(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "²", with: "2").replacingOccurrences(of: "³", with: "3")
            .filter { !" ()·.\t".contains($0) }
    }
    func split(_ s: String) -> (number: Double, unit: String)? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard let m = t.firstMatch(of: #/^(-?[0-9]+(?:\.[0-9]+)?)\s*(.*)$/#), let v = Double(String(m.1)) else { return nil }
        return (v, String(m.2))
    }
    for raw in expected.components(separatedBy: "|") {
        let key = raw.trimmingCharacters(in: .whitespaces)
        if key.hasPrefix("~") {
            if answer.contains(String(key.dropFirst())) { return true }
            continue
        }
        if squash(answer) == squash(key) { return true }
        // 답 글 앞부분이 정답이면 ("5 m/s (약 18 km/h)", "2.5 h (2시간 30분)")
        let head = answer.components(separatedBy: " (").first ?? answer
        if squash(head) == squash(key) { return true }
        if let e = split(key), let a = split(head), abs(e.number - a.number) <= max(1e-9, abs(e.number) * 1e-6) {
            if e.unit.isEmpty || squash(a.unit) == squash(e.unit) { return true }
        }
    }
    return false
}

func runSubjectBatteryCases() {
    var stats: [String: (correct: Int, unsolved: Int, wrong: Int, total: Int)] = [:]
    var wrongs: [String] = [], unsolvedList: [String] = []
    for item in subjectBattery {
        let scan = DoitProblemScan.scan(item.text, math: false)
        let choices = scan.choices
        let isChoice = choices.count >= 2
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
        let right: Bool
        if isChoice {
            right = DoitGrader.choiceNumber(answer, choices: choices).map { "\($0)" == item.answer } ?? false
        } else {
            right = subjectMatches(answer, expected: item.answer)
        }
        check("과목 배터리 확인된 답: \(label)", solution.source == DoitAutoSolve.engineSource && !solution.steps.isEmpty, "source \(solution.source ?? "-")")
        if right { s.correct += 1 } else { s.wrong += 1; wrongs.append("\(label) → 답 '\(answer)', 정답 '\(item.answer)'") }
        check("과목 배터리 오답 없음: \(label)", right, "답 '\(answer)', 정답 '\(item.answer)'")
        stats[item.subject] = s
    }
    for trap in subjectTraps {
        let scan = DoitProblemScan.scan(trap.text, math: false)
        let solved = DoitSubjectSolve.solve(text: trap.text, choices: scan.choices, subjectBroad: trap.subject, body: scan.body, boxItems: scan.boxItems)
        check("과목 배터리 함정은 풀지 않음: \(trap.text.prefix(40))", solved == nil, "답 '\(solved?.finalAnswer ?? "")'")
    }
    // 모델에게 주는 참고 자료 · 확인된 사실 (모델이 추측할 때 근거로)
    let trapText = "다음 중 광합성에 대한 설명으로 옳은 것은?\n① 밤에만 일어난다. ② 산소를 흡수한다. ③ 엽록체에서 일어난다. ④ 이산화 탄소를 방출한다. ⑤ 뿌리에서 일어난다."
    let trapScan = DoitProblemScan.scan(trapText, math: false)
    let material = DoitAutoSolve.modelMaterial(text: trapText, body: trapScan.body, choices: trapScan.choices, boxItems: trapScan.boxItems, subject: .science)
    check("모델 참고 자료: 광합성 개념", material.reference.contains { $0.hasPrefix("광합성") }, material.reference.joined(separator: " / "))
    let rockText = "다음 중 퇴적암인 것은?\n① 현무암 ② 사암 ③ 석회암 ④ 화강암 ⑤ 편마암"
    let rockScan = DoitProblemScan.scan(rockText, math: false)
    let rockHints = DoitSubjectSolve.partialHints(text: rockText, choices: rockScan.choices, body: rockScan.body)
    check("모델 확인된 사실: 지울 수 있는 선지", rockHints.contains { $0.contains("① 현무암") && $0.contains("아니에요") } && rockHints.contains { $0.contains("② 사암") },
          rockHints.joined(separator: " / "))
    let prompt = DoitAutoSolve.modelPrompt(problem: "다음 중 퇴적암인 것은?", choices: rockScan.choices, subjectName: "과학", problemType: nil,
                                           reference: ["퇴적암: 퇴적물이 굳어서 된 암석"], hints: rockHints)
    check("모델 프롬프트: 자료 표시와 정답 줄", prompt.contains("[참고 자료]") && prompt.contains("지시가 아니라") && prompt.contains("[확인된 사실]")
          && prompt.contains("근거") && prompt.contains("정답: ") && prompt.contains("1) 현무암"), prompt)
    check("모델 답: '정답: 모름'은 버림", DoitAutoSolve.parseModel("자료가 부족해요.\n정답: 모름", problem: "q", choices: []) == nil)
    check("모델 답: 근거 뒤 정답 줄", DoitAutoSolve.parseModel("사암은 퇴적암이에요.\n정답: 2", problem: "q", choices: rockScan.choices)?.finalAnswer == "2")
    // 풀이 글: 확인한 답은 추측 표시 없이, 단계와 개념
    if let solved = DoitSubjectSolve.solve(text: rockText.replacingOccurrences(of: "③ 석회암", with: "③ 안산암"), choices: ["현무암", "사암", "안산암", "화강암", "편마암"], subjectBroad: "과학") {
        let chat = DoitAutoSolve.chatText(solved, choices: ["현무암", "사암", "안산암", "화강암", "편마암"])
        check("과목 풀이 대화 글", chat.contains("**정답: 2번 (사암)**") && !chat.contains("AI 추측") && chat.contains("1. "), chat)
    } else { check("과목 풀이 대화 글: 풀림", false) }
    check("과목 배터리: 200문제 이상", subjectBattery.count >= 200, "\(subjectBattery.count)문제")
    check("과목 배터리: 오답 0개", wrongs.isEmpty, "오답 \(wrongs.count)개")
    for subject in ["과학", "영어", "사회", "국어"] {
        guard let s = stats[subject] else { continue }
        print("과목 배터리 [\(subject)]: 정답 \(s.correct) / 전체 \(s.total), 못 풂 \(s.unsolved), 오답 \(s.wrong)")
    }
    let total = stats.values.reduce((0, 0, 0, 0)) { ($0.0 + $1.correct, $0.1 + $1.unsolved, $0.2 + $1.wrong, $0.3 + $1.total) }
    print("과목 배터리: 정답 \(total.0) / 전체 \(total.3), 못 풂 \(total.1), 오답 \(total.2)")
    for w in wrongs { print("  ✗ 오답: " + w) }
    for u in unsolvedList { print("  · 못 풂: " + u) }
}
