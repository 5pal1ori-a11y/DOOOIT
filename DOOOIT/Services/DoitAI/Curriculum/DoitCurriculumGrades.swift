import Foundation

/// 단원이 주로 나오는 학년·학기 (교과서 기준, 2015·2022 개정)
/// 값은 학년 × 10 + 학기 (학기를 정하지 않으면 0). 예: 22 = 2학년 2학기, 30 = 3학년
/// 단원 찾기에서 "중2-2 피타고라스"처럼 학년을 적었을 때 그 학년 단원을 먼저 고르는 데만 써요.
extension DoitCurriculum {
    static let unitGrades: [String: [Int]] = {
        var table: [String: [Int]] = [:]
        func add(_ subject: String, _ level: SchoolLevel, _ codes: [Int], _ units: [String]) {
            for unit in units { table[key(subject, level, unit), default: []] += codes }
        }
        // 초등 수학
        add("수학", .elementary, [10, 20, 30, 40], ["자연수의 계산"])
        add("수학", .elementary, [52], ["수의 범위와 어림하기"])
        add("수학", .elementary, [30, 40, 50, 60], ["분수와 소수", "자료와 그래프"])
        add("수학", .elementary, [51], ["약수와 배수", "규칙과 대응", "다각형의 둘레와 넓이"])
        add("수학", .elementary, [60], ["비와 비율"])
        add("수학", .elementary, [30, 40, 50], ["평면도형"])
        add("수학", .elementary, [62], ["원의 넓이"])
        add("수학", .elementary, [52, 60], ["입체도형"])
        add("수학", .elementary, [61], ["직육면체의 부피와 겉넓이"])
        add("수학", .elementary, [31], ["길이와 시간"])
        add("수학", .elementary, [32], ["들이와 무게"])
        // 중학교 수학
        add("수학", .middle, [11], ["소인수분해", "정수와 유리수", "문자와 식", "좌표평면과 그래프"])
        add("수학", .middle, [12], ["기본 도형과 작도", "평면도형과 입체도형", "자료의 정리와 해석"])
        add("수학", .middle, [21], ["유리수와 순환소수", "식의 계산", "일차부등식", "연립일차방정식", "일차함수와 그래프", "일차함수와 일차방정식의 관계"])
        add("수학", .middle, [22], ["삼각형의 성질", "사각형의 성질", "도형의 닮음", "평행선과 선분의 길이의 비", "삼각형의 무게중심", "피타고라스 정리", "경우의 수와 확률"])
        add("수학", .middle, [31], ["제곱근과 실수", "근호를 포함한 식의 계산", "다항식의 곱셈과 인수분해", "이차방정식", "이차함수와 그래프"])
        add("수학", .middle, [32], ["삼각비", "원의 성질", "대푯값과 산포도", "상관관계"])
        add("수학", .middle, [10], ["대푯값과 산포도"])
        // 고등 수학 (선택 과목: 2·3학년)
        add("수학", .high, [20, 30], ["지수함수와 로그함수", "삼각함수", "수열", "함수의 극한과 연속", "미분", "적분", "수열의 극한", "여러 가지 미분법", "여러 가지 적분법", "경우의 수", "확률", "통계", "이차곡선", "벡터와 공간도형"])

        // 초등 과학
        add("과학", .elementary, [30], ["동식물의 한살이", "자석의 이용", "소리의 성질"])
        add("과학", .elementary, [40], ["물질의 상태", "지층과 화석", "화산과 지진"])
        add("과학", .elementary, [50], ["날씨와 우리 생활", "용해와 용액", "산과 염기", "생물과 환경", "물체의 운동", "생물과 우리 생활"])
        add("과학", .elementary, [60], ["지구와 달의 운동", "빛과 렌즈", "전기의 이용", "우리 몸의 구조와 기능", "계절의 변화", "식물의 구조와 기능", "연소와 소화", "여러 가지 기체"])
        // 중학교 과학
        add("과학", .middle, [10], ["지권의 변화", "여러 가지 힘", "생물의 구성과 다양성", "기체의 성질", "물질의 상태 변화", "빛과 파동"])
        add("과학", .middle, [20], ["물질의 구성", "전기와 자기", "태양계", "식물과 에너지", "동물과 에너지", "물질의 특성", "수권과 해수의 순환", "열과 우리 생활"])
        add("과학", .middle, [30], ["화학 반응의 규칙과 에너지 변화", "기권과 날씨", "운동과 에너지", "자극과 반응", "생식과 유전", "에너지 전환과 보존", "별과 우주"])
        // 고등 과학 (통합과학 1학년, 선택 과목 2·3학년)
        add("과학", .high, [10], ["과학의 기초", "원소의 생성", "자연의 구성 물질", "신소재의 개발과 이용", "지구 시스템", "생태계와 환경", "기후 변화와 에너지", "발전과 신재생 에너지"])
        add("과학", .high, [20, 30], ["역학과 에너지", "물질과 전자기장", "파동과 정보 통신", "화학의 첫걸음", "원자와 화학 결합", "역동적인 화학 반응", "세포와 유전", "항상성과 몸의 기능", "생태계와 진화", "고체 지구", "대기와 해양", "우주"])

        // 중학교 사회·역사
        add("사회", .middle, [10], ["내가 사는 세계", "우리와 다른 기후, 다른 생활", "자연으로 떠나는 여행", "지구 곳곳에서 일어나는 자연재해", "자원을 둘러싼 경쟁과 갈등", "개인과 사회생활", "정치 생활과 민주주의", "정치 과정과 시민 참여", "일상생활과 법"])
        add("사회", .middle, [30], ["인권과 헌법", "헌법과 국가 기관", "경제생활과 선택", "시장 경제와 가격", "국민 경제와 국제 거래", "국제 사회와 국제 정치", "인구 변화와 인구 문제", "사람이 만든 삶터, 도시", "환경 문제와 지속 가능한 환경"])
        add("사회", .middle, [20, 30], ["선사 문화와 고대 국가의 형성", "삼국의 성립과 발전", "남북국 시대의 전개", "고려의 성립과 변천", "조선의 성립과 발전", "조선 사회의 변동", "세계사의 흐름"])
        // 고등 사회 (통합사회·한국사 1학년)
        add("사회", .high, [10], ["인간, 사회, 환경과 행복", "자연환경과 인간", "생활 공간과 사회", "인권 보장과 헌법", "정의와 사회 불평등", "문화와 다양성", "세계화와 평화", "미래와 지속 가능한 삶", "전근대 한국사의 이해", "근대 국민 국가 수립 운동", "일제 식민지 지배와 민족 운동", "대한민국의 발전"])
        return table
    }()

    static func key(_ subject: String, _ level: SchoolLevel, _ unit: String) -> String { "\(subject)|\(level.rawValue)|\(unit)" }

    /// 그 단원이 나오는 학년·학기 (모르면 빈 배열)
    static func grades(subject: String, level: SchoolLevel, unit: String) -> [Int] {
        unitGrades[key(subject, level, unit)] ?? []
    }

    /// 학년이 맞는지 (0: 정보 없음, 1: 학년만 맞음, 2: 학년·학기 모두 맞음, -1: 다른 학년)
    static func gradeMatch(subject: String, level: SchoolLevel, unit: String, grade: Int?, semester: Int?) -> Int {
        guard let grade else { return 0 }
        let codes = grades(subject: subject, level: level, unit: unit)
        guard !codes.isEmpty else { return 0 }
        let same = codes.filter { $0 / 10 == grade }
        guard !same.isEmpty else { return -1 }
        if let semester, same.contains(where: { $0 % 10 == semester }) { return 2 }
        return 1
    }

    /// 화면에 보여줄 단원 순서: 학년·학기 순 (정보 없는 단원은 원래 순서대로 뒤에)
    static func orderedByGrade(_ units: [String], level: SchoolLevel, subject: String) -> [String] {
        let indexed = units.enumerated().map { (offset: $0.offset, unit: $0.element, code: grades(subject: subject, level: level, unit: $0.element).min()) }
        guard indexed.contains(where: { $0.code != nil }) else { return units }
        return indexed.sorted { a, b in
            switch (a.code, b.code) {
            case let (x?, y?): return x != y ? x < y : a.offset < b.offset
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.offset < b.offset
            }
        }.map(\.unit)
    }
}
