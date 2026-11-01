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
        ("삼국 시대", .middle, "사회", "삼국의 성립과 발전")
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
                    let terms = sources.flatMap { ref in
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
    }

    /// "중3 수학 이차방정식의 풀이" → 중학교, 3학년, 수학, "이차방정식의 풀이"
    static func parse(_ raw: String) -> ParsedInput {
        var text = " " + raw.replacingOccurrences(of: "\n", with: " ") + " "
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
        // 학교급 + 학년: 중3, 고1, 초등 5학년, 중학교 2학년
        let levelPatterns: [(String, SchoolLevel)] = [
            ("초등학교", .elementary), ("초등학생", .elementary), ("초등", .elementary),
            ("중학교", .middle), ("중학생", .middle), ("중등", .middle),
            ("고등학교", .high), ("고등학생", .high), ("고등", .high), ("고교", .high),
            ("대학교", .university), ("대학생", .university), ("대학", .university)
        ]
        if let m = text.firstMatch(of: #/(?:^|\s)(초|중|고)\s?([1-6])(?:\s?학년)?(?=\s)/#) {
            let level: SchoolLevel = m.1 == "초" ? .elementary : (m.1 == "중" ? .middle : .high)
            let grade = Int(m.2) ?? 1
            if level == .elementary || grade <= 3 {
                result.level = level
                result.grade = grade
                text.replaceSubrange(m.range, with: " ")
            }
        }
        for (word, level) in levelPatterns where text.contains(word) {
            result.level = result.level ?? level
            text = text.replacingOccurrences(of: word, with: " ")
            break
        }
        if let m = text.firstMatch(of: #/([1-6])\s?학년/#) {
            result.grade = result.grade ?? Int(m.1)
            text.replaceSubrange(m.range, with: " ")
        }
        // 과목: 낱말 단위로 (단원 이름 속 "생물"·"화학" 같은 말은 남기려고 앞쪽 낱말만 봄)
        var words = text.split(separator: " ").map(String.init)
        if result.subject == nil {
            for (index, word) in words.enumerated().prefix(3) {
                let lower = word.lowercased()
                if let hit = subjectAliases.first(where: { lower == $0.0 || lower == $0.0.replacingOccurrences(of: " ", with: "") }) {
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
        text.lowercased().filter { !$0.isWhitespace && !"·,./()'\"?!~-".contains($0) }
    }

    /// 단원 부분에서 붙은 말 떼기 ("이차방정식의 풀이" → 단원 후보 "이차방정식", 세부 "풀이")
    private static let requestWords = ["공부하기", "공부할래", "공부", "알려줘", "설명해줘", "정리해줘", "학습", "개념", "문제", "단원", "배우기", "해줘", "좀"]

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
        var topic = parsed.topic
        for word in requestWords { topic = topic.replacingOccurrences(of: word, with: " ") }
        topic = topic.split(separator: " ").joined(separator: " ")
        parsed.topic = topic
        guard norm(topic).count >= 2 else {
            return .notFound(message: "어떤 단원을 공부할지 함께 적어 주세요. 예: 중3 수학 이차방정식", suggestions: [])
        }
        // 3) 과목·학교급이 맞는 단원만 후보로
        var pool = catalog.filter { item in
            (parsed.subject.map { item.subject == $0 } ?? true) && (parsed.subjectName.map { item.subjectName == $0 } ?? true)
        }
        if let level = parsed.level {
            let sameLevel = pool.filter { $0.level == level }
            if !sameLevel.isEmpty { pool = sameLevel }
        }
        let q = norm(topic)
        var scored: [(item: CatalogUnit, score: Double, subtopic: String?)] = []
        for item in pool {
            let unitKey = norm(item.unit)
            var score = 0.0
            var subtopic: String?
            if q == unitKey || item.aliases.contains(where: { norm($0) == q }) {
                score = 1.0
            } else if let alias = item.aliases.first(where: { q.contains(norm($0)) }) {
                score = 0.92
                subtopic = remainder(of: topic, removing: alias)
            } else if unitKey.count >= 2, q.contains(unitKey) {
                score = 0.9
                subtopic = remainder(of: topic, removing: item.unit)
            } else if q.count >= 2, unitKey.contains(q) {
                score = 0.8
            } else if let term = item.terms.first(where: { norm($0) == q }) {
                score = 0.85
                subtopic = term == item.unit ? nil : term
            } else if let term = item.terms.filter({ norm($0).count >= 3 && q.contains(norm($0)) }).max(by: { $0.count < $1.count }) {
                score = 0.72
                subtopic = term
            } else {
                score = 0.75 * DoitKnowledge.cosine(DoitKnowledge.bigrams(q), DoitKnowledge.bigrams(unitKey))
            }
            if score > 0.3 { scored.append((item, score, subtopic)) }
        }
        scored.sort { $0.score > $1.score }
        let inputName = unitText.isEmpty ? nil : unitText
        guard let best = scored.first, best.score >= 0.6 else {
            let suggestions = scored.prefix(3).map { scope(for: $0.item, grade: parsed.grade) }
            return .notFound(message: "'\(topic)'에 맞는 단원을 찾지 못했어요. 두잇 AI는 자료가 없는 단원의 내용을 지어내지 않아요."
                             + (suggestions.isEmpty ? " 과목과 단원 이름을 확인해 주세요." : " 혹시 아래 단원인가요?"), suggestions: suggestions)
        }
        // 4) 점수가 비슷한 다른 단원이 있으면 골라 달라고 함
        let close = scored.filter { $0.score >= max(0.6, best.score - 0.04) }
        var seen = Set<String>()
        let distinct = close.filter { seen.insert($0.item.subjectName + "|" + $0.item.unit).inserted }
        if distinct.count > 1 {
            return .ambiguous(distinct.prefix(5).map { scope(for: $0.item, grade: parsed.grade, subtopic: cleanSubtopic($0.subtopic)) })
        }
        let mapped = norm(best.item.unit) == q || q.contains(norm(best.item.unit)) ? nil : inputName
        return .resolved(scope(for: best.item, grade: parsed.grade, subtopic: cleanSubtopic(best.subtopic), inputName: mapped))
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
        return norm(t).count >= 2 ? t : nil
    }
}
