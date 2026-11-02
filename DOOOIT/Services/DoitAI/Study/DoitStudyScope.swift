import Foundation

/// AI 학습 범위: 과목 · 학교급(학년) · 단원 · 세부 주제
/// 사용자가 고르거나 적은 말을 이 범위로 정확히 맞추고, 모든 학습 자료는 이 범위 안에서만 만들어요.
struct StudyScope: Hashable, Codable {
    /// 학습 자료로 쓰는 교육과정 단원 (학교급 + 단원 이름)
    struct UnitRef: Hashable, Codable {
        var level: SchoolLevel
        var unit: String
    }

    var level: SchoolLevel?
    var grade: Int?
    /// 국어 · 영어 · 수학 · 과학 · 사회
    var subject: String
    /// 화면과 기록에 쓰는 과목 이름 ("중학교 수학", "공통수학1")
    var subjectName: String
    /// 단원 이름 (교육과정 그대로)
    var unit: String
    /// 실제로 자료를 가져오는 단원들 (보통 unit 하나, 공통과목은 여러 개일 수 있음)
    var sources: [UnitRef]
    /// 공통수학처럼 직접 만든 수학 엔진 자료를 쓰는 단원
    var usesMathEngine = false
    /// "이차방정식의 풀이"의 "풀이"처럼 단원 안의 세부 주제
    var subtopic: String?
    /// 사용자가 적은 말이 다른 이름의 단원으로 이어졌을 때 (예: 생명 시스템 → 세포와 유전)
    var inputName: String?

    var key: String { [subjectName, unit, subtopic ?? ""].joined(separator: "|") }

    var levelLabel: String {
        guard let level else { return "" }
        if let grade { return level == .university ? "대학교" : "\(level == .elementary ? "초" : level == .middle ? "중" : "고")\(grade)" }
        return level.rawValue
    }

    /// 화면에 보여줄 범위 ("중3 수학 · 이차방정식 (풀이)")
    var label: String {
        var text = grade != nil && level != nil && !subjectName.hasPrefix("공통") ? "\(levelLabel) \(subject)" : subjectName
        text += " · \(unit)"
        if let subtopic, !subtopic.isEmpty { text += " (\(subtopic))" }
        return text
    }
}

enum DoitStudy {
    enum Resolution: Equatable {
        case resolved(StudyScope)
        /// 여러 단원으로 해석됨 → 사용자에게 골라 달라고 함
        case ambiguous([StudyScope])
        /// 맞는 단원이 없음 (비슷한 단원이 있으면 함께)
        case notFound(message: String, suggestions: [StudyScope])
    }

    // MARK: - 단원 목록 (교육과정 사전 + 고1 공통과목)

    struct CatalogUnit {
        let subjectName: String
        let subject: String
        let level: SchoolLevel
        let chapter: String
        let unit: String
        let sources: [StudyScope.UnitRef]
        let usesMathEngine: Bool
        /// 이 단원으로 이어지는 다른 이름 (교과서마다 다른 단원 이름)
        let aliases: [String]
        /// 단원 안 개념 이름들 (입력에서 단원을 찾을 때 씀)
        let terms: [String]
    }

    /// 고1 공통과목 (2022 개정): 과목 → [(대단원, [단원])]
    static let commonSubjects: [(name: String, subject: String, chapters: [(String, [String])])] = [
        ("공통수학1", "수학", [
            ("다항식", ["다항식의 연산", "항등식과 나머지정리", "인수분해"]),
            ("방정식과 부등식", ["복소수와 이차방정식", "이차방정식과 이차함수", "여러 가지 방정식과 부등식"]),
            ("경우의 수", ["합의 법칙과 곱의 법칙", "순열과 조합"]),
            ("행렬", ["행렬과 그 연산"])
        ]),
        ("공통수학2", "수학", [
            ("도형의 방정식", ["선분의 내분", "두 직선의 평행과 수직", "원의 방정식", "도형의 이동"]),
            ("집합과 명제", ["집합의 연산", "명제와 조건", "절대부등식"]),
            ("함수와 그래프", ["합성함수와 역함수", "유리함수", "무리함수"])
        ]),
        ("공통국어", "국어", [
            ("문학", ["현대시", "고전시가", "현대소설", "고전소설"]),
            ("문법", ["음운의 변동", "품사와 문장 성분", "문장의 짜임"]),
            ("독서", ["비문학 독해 전략", "논증 분석"])
        ]),
        ("공통영어", "영어", [
            ("어법", ["시제와 태", "관계사", "분사와 분사구문", "가정법"]),
            ("독해", ["주제·요지 파악", "빈칸 추론", "글의 순서와 문장 삽입"]),
            ("어휘", ["필수 어휘와 어구"])
        ])
    ]

    /// 공통국어·공통영어 단원 → 같은 내용을 다루는 교육과정 단원
    static let commonSources: [String: [StudyScope.UnitRef]] = [
        "현대시": [.init(level: .middle, unit: "시의 운율과 심상"), .init(level: .middle, unit: "비유와 상징")],
        "고전시가": [.init(level: .high, unit: "고전 시가의 갈래")],
        "현대소설": [.init(level: .middle, unit: "소설의 구성"), .init(level: .high, unit: "소설의 시점과 서술")],
        "고전소설": [.init(level: .high, unit: "고전 산문의 이해")],
        "음운의 변동": [.init(level: .high, unit: "음운의 변동")],
        "품사와 문장 성분": [.init(level: .middle, unit: "품사의 분류"), .init(level: .middle, unit: "문장 성분")],
        "문장의 짜임": [.init(level: .high, unit: "문장의 짜임")],
        "비문학 독해 전략": [.init(level: .high, unit: "독서의 방법")],
        "논증 분석": [.init(level: .middle, unit: "논증 방법")],
        "시제와 태": [.init(level: .middle, unit: "현재와 과거 시제"), .init(level: .middle, unit: "미래와 진행 시제"),
                   .init(level: .high, unit: "완료시제"), .init(level: .middle, unit: "수동태")],
        "관계사": [.init(level: .middle, unit: "관계대명사"), .init(level: .high, unit: "관계사 심화")],
        "분사와 분사구문": [.init(level: .high, unit: "분사와 분사구문")],
        "가정법": [.init(level: .high, unit: "가정법")],
        "주제·요지 파악": [.init(level: .high, unit: "독해 전략")],
        "빈칸 추론": [.init(level: .high, unit: "독해 전략"), .init(level: .high, unit: "수능 영어 유형")],
        "글의 순서와 문장 삽입": [.init(level: .high, unit: "독해 전략"), .init(level: .high, unit: "수능 영어 유형")]
    ]

    /// 교과서마다 다른 단원 이름 → 같은 내용의 교육과정 단원 (학교급, 과목, 단원)
    static let unitAliases: [(alias: String, level: SchoolLevel, subject: String, unit: String)] = [
        ("생명 시스템", .high, "과학", "세포와 유전"),
        ("생명 시스템의 기본 단위", .high, "과학", "세포와 유전"),
        ("역학적 시스템", .high, "과학", "역학과 에너지"),
        ("화학 변화", .high, "과학", "역동적인 화학 반응"),
        ("물질의 규칙성과 결합", .high, "과학", "원자와 화학 결합"),
        ("생물 다양성과 유지", .high, "과학", "생태계와 진화"),
        ("삼국의 발전", .middle, "사회", "삼국의 성립과 발전"),
        ("삼국 시대", .middle, "사회", "삼국의 성립과 발전"),
        // 예전 단원 이름·교과서마다 다른 이름 (중학교 수학)
        ("도형의 성질과 닮음", .middle, "수학", "도형의 닮음"),
        ("도형의 성질", .middle, "수학", "삼각형의 성질"),
        ("이등변삼각형", .middle, "수학", "삼각형의 성질"),
        ("기본 도형", .middle, "수학", "기본 도형과 작도"),
        ("작도와 합동", .middle, "수학", "기본 도형과 작도"),
        ("평면도형의 성질", .middle, "수학", "평면도형과 입체도형"),
        ("입체도형의 성질", .middle, "수학", "평면도형과 입체도형"),
        ("일차방정식", .middle, "수학", "문자와 식"),
        ("문자의 사용과 식의 계산", .middle, "수학", "문자와 식"),
        ("연립방정식", .middle, "수학", "연립일차방정식"),
        ("일차함수", .middle, "수학", "일차함수와 그래프"),
        ("이차함수", .middle, "수학", "이차함수와 그래프"),
        ("피타고라스의 정리", .middle, "수학", "피타고라스 정리"),
        ("실수와 그 연산", .middle, "수학", "제곱근과 실수"),
        ("원주각", .middle, "수학", "원의 성질"),
        // 중학교 과학
        ("지구계의 변화", .middle, "과학", "지권의 변화"),
        ("힘과 운동", .middle, "과학", "여러 가지 힘"),
        ("물질의 상태와 열", .middle, "과학", "물질의 상태 변화"),
        ("태양계와 우주", .middle, "과학", "태양계"),
        ("생물의 다양성", .middle, "과학", "생물의 구성과 다양성"),
        // 중학교 사회·역사
        ("한국사의 흐름", .middle, "사회", "선사 문화와 고대 국가의 형성"),
        ("선사 시대", .middle, "사회", "선사 문화와 고대 국가의 형성"),
        ("남북국 시대", .middle, "사회", "남북국 시대의 전개"),
        ("고려 시대", .middle, "사회", "고려의 성립과 변천"),
        ("조선 시대", .middle, "사회", "조선의 성립과 발전"),
        // 고등 (2022 개정 이름)
        ("미분법", .high, "수학", "여러 가지 미분법"),
        ("적분법", .high, "수학", "여러 가지 적분법"),
        ("도함수의 활용", .high, "수학", "미분"),
        ("평면벡터", .high, "수학", "벡터와 공간도형"),
        ("공간도형과 공간좌표", .high, "수학", "벡터와 공간도형"),
        ("역학 시스템", .high, "과학", "역학과 에너지"),
        ("물질과 규칙성", .high, "과학", "원자와 화학 결합"),
        ("시장 경제와 금융", .high, "사회", "시장과 경제 활동"),
        ("시장 경제와 지속 가능 발전", .high, "사회", "시장과 경제 활동"),
        ("사회 정의와 불평등", .high, "사회", "정의와 사회 불평등")
    ]

    /// 공통수학 단원 안 개념 이름 (수학 엔진 단원이라 교육과정 사전에 없음 → 개념 이름으로도 찾게)
    static let commonTerms: [String: [String]] = [
        "다항식의 연산": ["다항식의 덧셈과 뺄셈", "다항식의 나눗셈", "곱셈 공식의 변형", "내림차순", "오름차순"],
        "항등식과 나머지정리": ["항등식", "미정계수법", "계수비교법", "수치대입법", "나머지정리", "인수정리", "조립제법"],
        "인수분해": ["삼차식의 인수분해", "복이차식", "인수분해 공식의 활용"],
        "복소수와 이차방정식": ["복소수", "허수", "허수단위", "켤레복소수", "판별식", "근과 계수의 관계", "허근"],
        "이차방정식과 이차함수": ["이차함수의 최대·최소", "이차함수의 최대 최소", "이차함수와 직선의 위치 관계", "이차방정식과 이차함수의 관계"],
        "여러 가지 방정식과 부등식": ["삼차방정식", "사차방정식", "고차방정식", "연립이차방정식", "연립일차부등식", "이차부등식", "절댓값을 포함한 부등식"],
        "합의 법칙과 곱의 법칙": ["합의 법칙", "곱의 법칙"],
        "순열과 조합": ["순열", "조합", "팩토리얼", "nPr", "nCr"],
        "행렬과 그 연산": ["행렬", "행렬의 덧셈", "행렬의 곱셈", "영행렬", "단위행렬"],
        "선분의 내분": ["두 점 사이의 거리", "내분점", "선분의 내분점", "무게중심의 좌표"],
        "두 직선의 평행과 수직": ["직선의 방정식", "점과 직선 사이의 거리", "두 직선의 위치 관계"],
        "원의 방정식": ["원과 직선의 위치 관계", "원의 접선의 방정식"],
        "도형의 이동": ["평행이동", "대칭이동", "점의 평행이동", "원점에 대한 대칭이동"],
        "집합의 연산": ["집합", "부분집합", "합집합", "교집합", "여집합", "차집합", "드모르간의 법칙"],
        "명제와 조건": ["명제", "진리집합", "대우", "필요조건", "충분조건", "필요충분조건", "귀류법"],
        "절대부등식": ["산술평균과 기하평균의 관계", "코시-슈바르츠 부등식", "산술평균", "기하평균"],
        "합성함수와 역함수": ["일대일함수", "일대일대응", "합성함수", "역함수", "정의역", "치역", "공역"],
        "유리함수": ["유리식", "유리함수의 그래프", "점근선"],
        "무리함수": ["무리식", "무리함수의 그래프"]
    ]

    /// 고등 선택 과목 → 그 과목의 단원 (고등학교 단원 중에서). 이름은 띄어쓰기를 뺀 꼴로도 비교
    static let courses: [(names: [String], subject: String, units: [String])] = [
        (["대수", "수학1"], "수학", ["지수함수와 로그함수", "삼각함수", "수열"]),
        (["미적분1", "수학2"], "수학", ["함수의 극한과 연속", "미분", "적분"]),
        (["미적분2", "미적분"], "수학", ["수열의 극한", "여러 가지 미분법", "여러 가지 적분법"]),
        (["확률과 통계", "확통"], "수학", ["경우의 수", "확률", "통계"]),
        (["기하", "기하와 벡터"], "수학", ["이차곡선", "벡터와 공간도형"]),
        (["통합과학", "통합과학1", "통합과학2"], "과학", ["과학의 기초", "원소의 생성", "자연의 구성 물질", "신소재의 개발과 이용", "지구 시스템", "생태계와 환경",
                                               "기후 변화와 에너지", "발전과 신재생 에너지", "역학과 에너지", "원자와 화학 결합", "역동적인 화학 반응", "세포와 유전", "생태계와 진화"]),
        (["물리학1", "물리학", "물리1", "물리"], "과학", ["역학과 에너지", "물질과 전자기장", "파동과 정보 통신"]),
        (["화학1", "화학"], "과학", ["화학의 첫걸음", "원자와 화학 결합", "역동적인 화학 반응"]),
        (["생명과학1", "생명과학", "생물1", "생물"], "과학", ["세포와 유전", "항상성과 몸의 기능", "생태계와 진화"]),
        (["지구과학1", "지구과학", "지학"], "과학", ["고체 지구", "대기와 해양", "우주"]),
        (["통합사회", "통합사회1", "통합사회2"], "사회", ["인간, 사회, 환경과 행복", "자연환경과 인간", "생활 공간과 사회", "인권 보장과 헌법", "정의와 사회 불평등",
                                               "문화와 다양성", "세계화와 평화", "미래와 지속 가능한 삶", "시장과 경제 활동"]),
        (["한국사", "한국사1", "한국사2"], "사회", ["전근대 한국사의 이해", "근대 국민 국가 수립 운동", "일제 식민지 지배와 민족 운동", "대한민국의 발전"]),
        (["세계사"], "사회", ["제국주의와 두 차례 세계 대전"]),
        (["한국지리", "지리"], "사회", ["국토 인식과 지리 정보"]),
        (["정치와 법", "법과 사회", "정치"], "사회", ["민주주의와 헌법", "개인 생활과 법"]),
        (["경제"], "사회", ["시장과 경제 활동"]),
        (["사회·문화", "사회문화"], "사회", ["개인과 사회 구조"]),
        (["생활과 윤리", "윤리와 사상", "윤리"], "사회", ["생활과 윤리"])
    ]

    static let catalog: [CatalogUnit] = {
        var list: [CatalogUnit] = []
        for (subject, entries) in DoitCurriculum.bySubject {
            var order: [(SchoolLevel, String)] = []
            var terms: [String: [String]] = [:]
            for entry in entries {
                let key = "\(entry.level.rawValue)|\(entry.unit)"
                if terms[key] == nil { order.append((entry.level, entry.unit)) }
                terms[key, default: []] += entry.names
            }
            // 학교급 안에서는 학년·학기 순서로
            order = SchoolLevel.allCases.flatMap { lvl in
                DoitCurriculum.orderedByGrade(order.filter { $0.0 == lvl }.map(\.1), level: lvl, subject: subject).map { (lvl, $0) }
            }
            for (level, unit) in order {
                let aliases = unitAliases.filter { $0.level == level && $0.subject == subject && $0.unit == unit }.map(\.alias)
                list.append(CatalogUnit(subjectName: "\(level.rawValue) \(subject)", subject: subject, level: level, chapter: "\(level.rawValue) \(subject)",
                                        unit: unit, sources: [.init(level: level, unit: unit)], usesMathEngine: false,
                                        aliases: aliases, terms: terms["\(level.rawValue)|\(unit)"] ?? []))
            }
        }
        for common in commonSubjects {
            for (chapter, units) in common.chapters {
                for unit in units {
                    let sources = commonSources[unit] ?? []
                    let engine = common.subject == "수학"
                    let terms = (commonTerms[unit] ?? []) + sources.flatMap { ref in
                        DoitCurriculum.bySubject.first { $0.subject == common.subject }?.entries
                            .filter { $0.level == ref.level && $0.unit == ref.unit }.flatMap(\.names) ?? []
                    }
                    list.append(CatalogUnit(subjectName: common.name, subject: common.subject, level: .high, chapter: chapter, unit: unit,
                                            sources: sources, usesMathEngine: engine, aliases: [], terms: terms))
                }
            }
        }
        return list
    }()

    static func scope(for item: CatalogUnit, grade: Int? = nil, subtopic: String? = nil, inputName: String? = nil) -> StudyScope {
        StudyScope(level: item.level, grade: grade ?? (item.subjectName.hasPrefix("공통") ? 1 : nil), subject: item.subject, subjectName: item.subjectName,
                   unit: item.unit, sources: item.sources, usesMathEngine: item.usesMathEngine, subtopic: subtopic, inputName: inputName)
    }

    // MARK: - 입력 분석

    /// 과목 별명 → 교과 (긴 말부터 확인)
    static let subjectAliases: [(String, String)] = [
        ("공통수학", "수학"), ("확률과 통계", "수학"), ("확통", "수학"), ("미적분", "수학"), ("기하", "수학"), ("대수", "수학"), ("산수", "수학"), ("수학", "수학"), ("math", "수학"),
        ("통합과학", "과학"), ("생명과학", "과학"), ("지구과학", "과학"), ("물리학", "과학"), ("물리", "과학"), ("화학", "과학"), ("생물", "과학"), ("과학", "과학"), ("science", "과학"),
        ("통합사회", "사회"), ("한국사", "사회"), ("세계사", "사회"), ("역사", "사회"), ("지리", "사회"), ("정치와 법", "사회"), ("정치", "사회"), ("경제", "사회"),
        ("윤리", "사회"), ("도덕", "사회"), ("사회문화", "사회"), ("사회", "사회"),
        ("공통국어", "국어"), ("언어와 매체", "국어"), ("화법과 작문", "국어"), ("문학", "국어"), ("문법", "국어"), ("독서", "국어"), ("국어", "국어"),
        ("공통영어", "영어"), ("영문법", "영어"), ("영어", "영어"), ("english", "영어")
    ]


    struct ParsedInput: Equatable {
        var level: SchoolLevel?
        var grade: Int?
        var subject: String?
        /// "공통수학1"처럼 과목 이름 자체를 적었을 때
        var subjectName: String?
        /// 과목·학년을 뺀 단원 부분
        var topic: String
        /// "2-2", "2학기"처럼 학기를 적었을 때 (1 또는 2)
        var semester: Int? = nil
        /// "미적분Ⅰ", "확률과 통계", "물리학"처럼 고등 선택 과목을 적었을 때 (courses의 첫 이름)
        var course: String? = nil
        /// 과목 이름으로 떼어 낸 낱말 ("화학 반응의 규칙"의 "화학"처럼 단원 이름의 일부일 수도 있음)
        var courseWord: String? = nil
    }

    /// 학교급 낱말 → 학교급 (첫 글자로 구분)
    private static func schoolLevel(_ word: Substring) -> SchoolLevel {
        word.hasPrefix("초") ? .elementary : (word.hasPrefix("중") ? .middle : .high)
    }

    private static func validGrade(_ grade: Int, _ level: SchoolLevel?) -> Bool {
        guard let level else { return (1...6).contains(grade) }
        return level == .elementary ? (1...6).contains(grade) : (1...3).contains(grade)
    }

    /// 입력 다듬기: 줄바꿈·대시·로마 숫자, "공통 수학 1" → "공통수학1", "수학(상)" → "공통수학1"
    private static func normalizeInput(_ raw: String) -> String {
        var t = " " + raw.replacingOccurrences(of: "\n", with: " ") + " "
        for dash in ["–", "—", "‐", "－"] { t = t.replacingOccurrences(of: dash, with: "-") }
        t = t.replacingOccurrences(of: "Ⅰ", with: "1").replacingOccurrences(of: "Ⅱ", with: "2")
        t = t.replacing(#/공통\s*수학\s*([12])/#) { "공통수학\($0.1)" }
        t = t.replacing(#/(\s)수학\s*\(?\s*(상|하)\s*\)?(?=\s)/#) { "\($0.1)공통수학\($0.2 == "상" ? "1" : "2")" }
        t = t.replacing(#/(\s)(미적분|수학|물리학|물리|화학|생명과학|지구과학|통합과학|통합사회|한국사)\s+([12])(?=\s)/#) { "\($0.1)\($0.2)\($0.3)" }
        return t
    }

    /// "중3 수학 이차방정식의 풀이" → 중학교, 3학년, 수학, "이차방정식의 풀이"
    /// "중 2-2 피타고라스의 정리", "중2 2학기", "중학교 2학년 2학기", "고1-1", "초5-2"처럼 학년·학기도 읽어요.
    static func parse(_ raw: String) -> ParsedInput {
        var text = normalizeInput(raw)
        var result = ParsedInput(topic: "")
        // 공통과목 이름
        for common in commonSubjects.map(\.name).sorted(by: { $0.count > $1.count }) where text.contains(common) {
            result.subjectName = common
            result.level = .high
            result.grade = 1
            result.subject = commonSubjects.first { $0.name == common }?.subject
            text = text.replacingOccurrences(of: common, with: " ")
        }
        if text.contains("통합과학") || text.contains("통합사회") { result.level = .high; result.grade = result.grade ?? 1 }
        // 학교급 + 학년 + 학기: 중 2-2, 중2-2, 고1-1, 초5-2학기
        if let m = text.firstMatch(of: #/(?:^|\s)(초등학교|초등|초|중학교|중학|중등|중|고등학교|고등|고교|고)\s*([1-6])\s*-\s*([12])(?:\s*학기)?(?=\s)/#),
           let grade = Int(m.2), validGrade(grade, schoolLevel(m.1)) {
            result.level = schoolLevel(m.1); result.grade = grade; result.semester = Int(m.3)
            text.replaceSubrange(m.range, with: " ")
        }
        // 중2 2학기, 중학교 2학년 2학기
        if let m = text.firstMatch(of: #/(?:^|\s)(초등학교|초등|초|중학교|중학|중등|중|고등학교|고등|고교|고)\s*([1-6])\s*(?:학년)?\s*([12])\s*학기(?=\s)/#),
           let grade = Int(m.2), validGrade(grade, schoolLevel(m.1)) {
            result.level = schoolLevel(m.1); result.grade = grade; result.semester = Int(m.3)
            text.replaceSubrange(m.range, with: " ")
        }
        // 중3, 고1, 초5, 초등 5학년
        if let m = text.firstMatch(of: #/(?:^|\s)(초등|초|중|고)\s?([1-6])(?:\s?학년)?(?=\s)/#),
           let grade = Int(m.2), validGrade(grade, schoolLevel(m.1)) {
            if result.subjectName == nil { result.level = schoolLevel(m.1) }
            result.grade = result.subjectName == nil ? (result.grade ?? grade) : result.grade
            text.replaceSubrange(m.range, with: " ")
        }
        let levelPatterns: [(String, SchoolLevel)] = [
            ("초등학교", .elementary), ("초등학생", .elementary), ("초등", .elementary),
            ("중학교", .middle), ("중학생", .middle), ("중등", .middle), ("중학", .middle),
            ("고등학교", .high), ("고등학생", .high), ("고등", .high), ("고교", .high),
            ("대학교", .university), ("대학생", .university), ("대학", .university)
        ]
        for (word, level) in levelPatterns where text.contains(word) {
            result.level = result.level ?? level
            text = text.replacingOccurrences(of: word, with: " ")
            break
        }
        // 학년·학기만 따로: 2학년 2학기, 2-2, 2학기
        if let m = text.firstMatch(of: #/([1-6])\s*학년\s*([12])\s*학기/#), let grade = Int(m.1), validGrade(grade, result.level) {
            result.grade = result.grade ?? grade
            result.semester = result.semester ?? Int(m.2)
            text.replaceSubrange(m.range, with: " ")
        }
        if let m = text.firstMatch(of: #/([1-6])\s?학년/#) {
            result.grade = result.grade ?? Int(m.1)
            text.replaceSubrange(m.range, with: " ")
        }
        if result.grade == nil, let m = text.firstMatch(of: #/(?:^|\s)([1-6])\s*-\s*([12])(?:\s*학기)?(?=\s)/#), let grade = Int(m.1), validGrade(grade, result.level) {
            result.grade = grade
            result.semester = Int(m.2)
            text.replaceSubrange(m.range, with: " ")
        }
        if let m = text.firstMatch(of: #/(?:^|\s)([12])\s*학기(?=\s)/#) {
            result.semester = result.semester ?? Int(m.1)
            text.replaceSubrange(m.range, with: " ")
        }
        var words = text.split(separator: " ").map(String.init)
        // 고등 선택 과목 (앞쪽 낱말만, 두 낱말 과목 "확률과 통계"도)
        if result.subjectName == nil {
            search: for index in 0..<min(3, words.count) {
                for span in [2, 1] where index + span <= words.count {
                    let phrase = words[index..<index + span].joined().lowercased()
                    if let course = courses.first(where: { $0.names.contains { $0.replacingOccurrences(of: " ", with: "") == phrase } }) {
                        result.course = course.names[0]
                        result.courseWord = words[index..<index + span].joined(separator: " ")
                        result.subject = result.subject ?? course.subject
                        words.removeSubrange(index..<index + span)
                        break search
                    }
                }
            }
        }
        // 과목: 낱말 단위로 (단원 이름 속 "생물"·"화학" 같은 말은 남기려고 앞쪽 낱말만 봄)
        if result.subject == nil || result.course != nil {
            for (index, word) in words.enumerated().prefix(3) {
                let lower = word.lowercased()
                if let hit = subjectAliases.first(where: { lower == $0.0 || lower == $0.0.replacingOccurrences(of: " ", with: "") }),
                   result.subject == nil || result.subject == hit.1 {
                    result.subject = hit.1
                    words.remove(at: index)
                    break
                }
            }
        }
        if result.subject == nil {
            // "정치와 법" 같은 두 낱말 과목
            let joined = words.joined(separator: " ")
            if let hit = subjectAliases.filter({ $0.0.contains(" ") }).first(where: { joined.hasPrefix($0.0) }) {
                result.subject = hit.1
                words = joined.dropFirst(hit.0.count).split(separator: " ").map(String.init)
            }
        }
        result.topic = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return result
    }

    // MARK: - 단원 찾기

    private static func norm(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace && !"·,./()'\"?!~-「」『』".contains($0) }
    }

    /// 조사 "의"를 뺀 비교용 글자 ("피타고라스의 정리" == "피타고라스 정리")
    private static func loose(_ text: String) -> String {
        norm(text).replacingOccurrences(of: "의", with: "")
    }

    /// 단원 부분에서 붙은 말 떼기 ("이차방정식의 풀이" → 단원 후보 "이차방정식", 세부 "풀이")
    private static let requestWords = ["공부하기", "공부할래", "공부", "알려줘", "설명해줘", "정리해줘", "학습", "개념", "문제", "단원", "배우기", "해줘", "좀"]

    /// 요청 말 떼기 ("피타고라스 정리 개념 알려줘" → "피타고라스 정리")
    private static func withoutRequests(_ text: String) -> String {
        var t = text
        for word in requestWords { t = t.replacingOccurrences(of: word, with: " ") }
        return t.split(separator: " ").joined(separator: " ")
    }

    /// 끝에 붙은 조사·말 떼기 ("피타고라스 정리에 대해" → "피타고라스 정리")
    private static func withoutTrailingParticles(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespaces)
        for _ in 0..<2 {
            let before = t
            t = t.replacing(#/\s*(에\s*대해서|에\s*대해|에\s*대한|에\s*관해서|에\s*관해|에\s*관한|이란|이라는\s*것|란|를|을)\s*$/#, with: "")
            t = t.replacing(#/\s*의\s*$/#, with: "")
            if t == before { break }
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// 단원 하나의 점수 (0~1)와 세부 주제
    private static func score(_ item: CatalogUnit, query text: String) -> (score: Double, subtopic: String?) {
        let q = loose(text)
        guard q.count >= 2 else { return (0, nil) }
        let unitKey = loose(item.unit)
        var best: (score: Double, subtopic: String?) = (0, nil)
        func take(_ s: Double, _ sub: String?) { if s > best.score { best = (s, sub) } }
        if q == unitKey || item.aliases.contains(where: { loose($0) == q }) { take(1.0, nil) }
        if let alias = item.aliases.filter({ loose($0).count >= 2 && q.contains(loose($0)) }).max(by: { $0.count < $1.count }) {
            take(loose(alias).count * 2 >= q.count ? 0.92 : 0.7, remainder(of: text, removing: alias))
        }
        if unitKey.count >= 2, q.contains(unitKey) { take(0.9, remainder(of: text, removing: item.unit)) }
        if unitKey.contains(q) { take(0.8, nil) }
        if let term = item.terms.first(where: { loose($0) == q }) { take(0.85, term == item.unit ? nil : term) }
        if let term = item.terms.filter({ loose($0).count >= 3 && q.contains(loose($0)) }).max(by: { loose($0).count < loose($1).count }) {
            take(0.72, term)
        }
        if q.count >= 3, let term = item.terms.filter({ loose($0).contains(q) && q.count * 2 >= loose($0).count }).min(by: { $0.count < $1.count }) {
            take(0.74, term)
        }
        take(0.75 * DoitKnowledge.cosine(DoitKnowledge.bigrams(q), DoitKnowledge.bigrams(unitKey)), nil)
        return best
    }

    /// 오타·띄어쓰기가 조금 다른 개념 이름 (글자 두 개씩 묶어 비교)
    private static func fuzzyScore(_ item: CatalogUnit, query text: String) -> (score: Double, subtopic: String?) {
        let q = loose(text)
        guard q.count >= 3 else { return (0, nil) }
        let qb = DoitKnowledge.bigrams(q)
        var best: (Double, String?) = (0, nil)
        for name in [item.unit] + item.aliases + item.terms {
            let c = DoitKnowledge.cosine(qb, DoitKnowledge.bigrams(loose(name)))
            if c > best.0 { best = (c, name == item.unit ? nil : name) }
        }
        return best
    }

    private static func gradeCodes(_ item: CatalogUnit) -> [Int] {
        item.subjectName.hasPrefix("공통") ? [10] : DoitCurriculum.grades(subject: item.subject, level: item.level, unit: item.unit)
    }

    /// 학년·학기가 맞는 단원에 덤 점수 (순위에만 씀)
    private static func gradeBonus(_ item: CatalogUnit, _ parsed: ParsedInput) -> Double {
        guard let grade = parsed.grade else { return 0 }
        let codes = gradeCodes(item)
        guard !codes.isEmpty else { return 0 }
        let same = codes.filter { $0 / 10 == grade }
        if same.isEmpty { return -0.03 }
        if let semester = parsed.semester, same.contains(where: { $0 % 10 == semester }) { return 0.06 }
        return 0.04
    }

    /// 범위에 넣을 학년: 적은 학년이 그 단원 학년과 다르면 단원의 학년으로
    private static func scopeGrade(_ item: CatalogUnit, _ parsed: ParsedInput) -> Int? {
        guard let grade = parsed.grade else { return nil }
        let grades = Set(gradeCodes(item).map { $0 / 10 })
        if grades.isEmpty || grades.contains(grade) { return grade }
        return grades.count == 1 ? grades.first : nil
    }

    private struct Scored {
        let item: CatalogUnit
        let base: Double
        let rank: Double
        let subtopic: String?
    }

    private static func rank(_ pool: [CatalogUnit], queries: [String], parsed: ParsedInput, fuzzy: Bool = false) -> [Scored] {
        var list: [Scored] = []
        for item in pool {
            var best: (score: Double, subtopic: String?) = (0, nil)
            for query in queries {
                let s = fuzzy ? fuzzyScore(item, query: query) : score(item, query: query)
                if s.score > best.score { best = s }
            }
            if fuzzy {
                // 개념 이름과 아주 비슷할 때만 (0.72 이상 → 0.6 ~ 0.85)
                guard best.score >= 0.72 else { continue }
                best.score = 0.6 + (best.score - 0.72) * 0.9
            }
            guard best.score > 0.3 else { continue }
            list.append(Scored(item: item, base: best.score, rank: best.score + (best.score >= 0.6 ? gradeBonus(item, parsed) : 0), subtopic: best.subtopic))
        }
        return list.sorted { $0.rank > $1.rank }
    }

    /// 고른 과목·단원 또는 직접 적은 말을 정확한 학습 범위로
    static func resolve(subject rawSubject: String, unit rawUnit: String) -> Resolution {
        let subjectText = rawSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        let unitText = rawUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        // 1) 목록에서 고른 그대로면 바로
        if let exact = catalog.first(where: { $0.subjectName == subjectText && $0.unit == unitText }) {
            return .resolved(scope(for: exact))
        }
        // 2) 적은 말 분석
        var parsed = parse(subjectText + " " + unitText)
        let rawTopic = parsed.topic
        let topic = withoutRequests(rawTopic)
        parsed.topic = topic
        guard norm(topic).count >= 2 else {
            return .notFound(message: "어떤 단원을 공부할지 함께 적어 주세요. 예: 중3 수학 이차방정식", suggestions: [])
        }
        var queries = [topic, withoutTrailingParticles(topic), rawTopic]
        queries = queries.filter { norm($0).count >= 2 }
        // 3) 과목·학교급이 맞는 단원만 후보로
        let bySubject = catalog.filter { item in
            (parsed.subject.map { item.subject == $0 } ?? true) && (parsed.subjectName.map { item.subjectName == $0 } ?? true)
        }
        var pool = bySubject
        if let level = parsed.level {
            let sameLevel = pool.filter { $0.level == level }
            if !sameLevel.isEmpty { pool = sameLevel }
        }
        // 선택 과목을 적었으면 그 과목 단원부터, 없으면 과목·학교급 전체에서 (과목 이름이 단원 이름의 일부일 수도 있어 다시 붙여서도 봄)
        var tiers: [(pool: [CatalogUnit], queries: [String])] = []
        if let course = parsed.course, let units = courses.first(where: { $0.names[0] == course })?.units, parsed.level == nil || parsed.level == .high {
            let coursePool = pool.filter { $0.level == .high && !$0.subjectName.hasPrefix("공통") && units.contains($0.unit) }
            if !coursePool.isEmpty { tiers.append((coursePool, queries)) }
        }
        var wide = queries
        if let word = parsed.courseWord { wide.append(word + " " + rawTopic) }
        tiers.append((pool, wide))
        let inputName = unitText.isEmpty ? nil : unitText
        for tier in tiers {
            let scored = rank(tier.pool, queries: tier.queries, parsed: parsed)
            if let best = scored.first, best.base >= 0.6 { return decide(scored, parsed: parsed, query: topic, inputName: inputName) }
        }
        // 4) 단원 이름에 없으면 단원 안 개념 이름으로 (오타·띄어쓰기 차이 포함): "외심" → 삼각형의 성질
        let fuzzy = rank(pool, queries: wide, parsed: parsed, fuzzy: true)
        if let best = fuzzy.first, best.base >= 0.6 { return decide(fuzzy, parsed: parsed, query: topic, inputName: inputName) }
        // 5) 못 찾음: 다른 학교급·과목에서 비슷한 단원을 제안
        let suggestions = suggest(parsed: parsed, queries: wide, subjectPool: bySubject)
        return .notFound(message: "'\(topic)'에 맞는 단원을 찾지 못했어요. 두잇 AI는 자료가 없는 단원의 내용을 지어내지 않아요."
                         + (suggestions.isEmpty ? " 과목과 단원 이름을 확인해 주세요." : " 혹시 아래 단원인가요?"), suggestions: suggestions)
    }

    private static func decide(_ scored: [Scored], parsed: ParsedInput, query: String, inputName: String?) -> Resolution {
        guard let best = scored.first else { return .notFound(message: "", suggestions: []) }
        // 점수가 비슷한 다른 단원이 있으면 골라 달라고 함
        let close = scored.filter { $0.base >= 0.6 && $0.rank >= best.rank - 0.04 }
        var seen = Set<String>()
        let distinct = close.filter { seen.insert($0.item.subjectName + "|" + $0.item.unit).inserted }
        if distinct.count > 1 {
            return .ambiguous(distinct.prefix(5).map { scope(for: $0.item, grade: scopeGrade($0.item, parsed), subtopic: cleanSubtopic($0.subtopic)) })
        }
        let q = loose(query), unitKey = loose(best.item.unit)
        let mapped = unitKey == q || q.contains(unitKey) ? nil : inputName
        return .resolved(scope(for: best.item, grade: scopeGrade(best.item, parsed), subtopic: cleanSubtopic(best.subtopic), inputName: mapped))
    }

    /// 비슷한 단원 제안 (같은 과목 → 모든 과목, 학교급은 가리지 않음)
    private static func suggest(parsed: ParsedInput, queries: [String], subjectPool: [CatalogUnit]) -> [StudyScope] {
        var candidates: [(item: CatalogUnit, score: Double)] = []
        for pool in [subjectPool, catalog] {
            for item in pool {
                var s = 0.0
                for query in queries {
                    s = max(s, score(item, query: query).score, fuzzyScore(item, query: query).score * 0.8)
                }
                if parsed.level == item.level { s += 0.03 }
                if s >= 0.4 { candidates.append((item, s)) }
            }
            if !candidates.isEmpty { break }
        }
        var seen = Set<String>()
        return candidates.sorted { $0.score > $1.score }
            .filter { seen.insert($0.item.subjectName + "|" + $0.item.unit).inserted }
            .prefix(3)
            .map { scope(for: $0.item, grade: scopeGrade($0.item, parsed)) }
    }

    private static func remainder(of text: String, removing name: String) -> String? {
        var rest = text
        if let range = rest.range(of: name) ?? rest.range(of: name.replacingOccurrences(of: " ", with: "")) {
            rest.removeSubrange(range)
        } else { return nil }
        return cleanSubtopic(rest)
    }

    private static func cleanSubtopic(_ text: String?) -> String? {
        guard var t = text?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        // 단원 이름 바로 뒤에 붙은 조사 떼기 ("의 풀이" → "풀이")
        // ("광합성 과정"의 "과정"은 그대로: 조사 뒤에 띄어쓰기가 있을 때만)
        for particle in ["에서", "의", "와", "과"] where t.hasPrefix(particle + " ") {
            t = String(t.dropFirst(particle.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        t = withoutTrailingParticles(t)
        return norm(t).count >= 2 ? t : nil
    }
}
