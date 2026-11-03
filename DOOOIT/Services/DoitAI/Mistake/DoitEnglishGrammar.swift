import Foundation

/// 영어 문법 엔진 (다른 화면 · 학습 단원에서 쓰는 작은 창구)
/// - check(sentence:): 확실히 틀린 곳 모두 (없으면 [], 비어 있어도 "바르다"는 뜻은 아니에요)
/// - correct(_:): 확실한 오류가 딱 하나이고 고칠 말을 알 때 고친 문장
/// - topics: 규칙을 학년·단원별로 묶은 목록 (교과 순서)
enum DoitEnglishGrammar {
    typealias Issue = DoitSentenceCheck.Issue

    struct Topic {
        /// "초등~중1" · "중2~중3" · "고1~수능"
        let level: String
        let name: String
        /// 이 단원에 드는 규칙 이름 (Issue.rule)
        let rules: [String]
    }

    static let levels = ["초등~중1", "중2~중3", "고1~수능"]

    static let topics: [Topic] = [
        Topic(level: "초등~중1", name: "be동사 · 일반동사와 주어의 수", rules: ["be동사 수일치", "3인칭 단수", "주어와 동사 수일치", "A and B 주어는 복수", "do/does", "don't/doesn't"]),
        Topic(level: "초등~중1", name: "명사의 수 · 관사", rules: ["불규칙 복수", "명사의 복수형", "명사의 수", "셀 수 없는 명사", "a/an", "many와 much", "지시사와 명사의 수", "one of + 복수 명사"]),
        Topic(level: "초등~중1", name: "인칭대명사 · 소유격", rules: ["인칭대명사의 격", "소유대명사", "소유격", "소유격 its", "it's와 its"]),
        Topic(level: "초등~중1", name: "There is / are", rules: ["there is/are"]),
        Topic(level: "초등~중1", name: "조동사 · 진행형 · 명령문", rules: ["조동사 + 동사원형", "진행형 be + -ing", "상태동사의 진행형", "부정 명령문", "Let's + 동사원형", "명령문은 동사원형", "be동사와 일반동사"]),
        Topic(level: "초등~중1", name: "의문문", rules: ["의문문의 동사원형", "부정문의 동사원형", "의문문의 수일치", "의문사 의문문 어순"]),
        Topic(level: "초등~중1", name: "시제 기본 · 시간 전치사", rules: ["과거 시제", "시간 전치사", "불규칙 동사"]),
        Topic(level: "초등~중1", name: "비교급 · 최상급 기본", rules: ["비교급·최상급", "비교급", "원급 비교", "최상급 앞 the", "원급 비교 as ~ as", "비교급 + than", "비교급 강조"]),
        Topic(level: "중2~중3", name: "현재완료", rules: ["현재완료와 과거 단서", "since와 현재완료", "when과 현재완료", "완료형 have + 과거분사", "현재완료와 just now", "have been to (경험)", "for와 since", "현재완료 (계속)"]),
        Topic(level: "중2~중3", name: "수동태", rules: ["수동태의 과거분사", "자동사는 수동태 ✗", "5형식의 수동태", "be born", "전치사 짝", "수동태 be + p.p."]),
        Topic(level: "중2~중3", name: "to부정사", rules: ["to부정사를 목적어로 쓰는 동사", "to부정사의 의미상 주어", "형용사 + enough to", "so ~ that / too ~ to", "too ~ to의 목적어", "의문사 + to부정사", "to부정사의 형용사적 용법 + 전치사", "to부정사 (to + 동사원형)", "목적격 보어 to부정사"]),
        Topic(level: "중2~중3", name: "동명사", rules: ["동명사를 목적어로 쓰는 동사", "look forward to + -ing", "전치사 + 동명사", "to(전치사) + 동명사", "cannot help + -ing", "be busy + -ing", "have trouble + -ing", "feel like + -ing", "How about + -ing", "be worth + -ing"]),
        Topic(level: "중2~중3", name: "분사 (감정)", rules: ["감정 분사 (사물 주어)", "감정 분사 (사람 주어)", "감정 분사 (목적격 보어)"]),
        Topic(level: "중2~중3", name: "관계대명사 · 관계부사", rules: ["관계대명사", "관계대명사 what", "전치사 + 관계대명사", "계속적 용법", "the way how ✗", "소유격 관계대명사 whose", "전치사 + whom", "관계대명사절의 목적어", "관계부사 where", "관계부사 when", "관계대명사 which", "관계부사 why"]),
        Topic(level: "중2~중3", name: "접속사", rules: ["because / because of", "although / despite", "during / while", "if / whether", "such a + 형용사 + 명사", "unless", "접속사 겹쳐 쓰기", "both A and B", "상관접속사 짝", "상관접속사 수일치 (B에 맞춤)", "A as well as B (A에 맞춤)", "조건·때의 부사절", "때·조건의 부사절"]),
        Topic(level: "중2~중3", name: "간접의문문 · 부가의문문", rules: ["간접의문문 어순", "간접의문문 어순 (think류)", "부가의문문", "의문문 어순", "tell + 사람 + that", "say + (to 사람) + that"]),
        Topic(level: "중2~중3", name: "가정법", rules: ["가정법 과거", "가정법 과거완료", "I wish 가정법"]),
        Topic(level: "중2~중3", name: "사역 · 지각동사", rules: ["사역동사 + 동사원형", "지각동사 + 동사원형/-ing", "사역동사 + 목적어 + p.p."]),
        Topic(level: "중2~중3", name: "수일치 · 시제 일치", rules: ["단수 주어", "the + 형용사 (복수)", "거리·시간·금액은 단수", "a number of + 복수", "the number of + 단수", "역사적 사실은 과거", "변하지 않는 사실은 현재", "부분 표현의 수일치", "동명사 주어는 단수", "to부정사 주어는 단수", "주어와 동사 수일치 (수식어구)"]),
        Topic(level: "고1~수능", name: "분사구문", rules: ["분사구문 (수동)", "with + 명사 + 분사"]),
        Topic(level: "고1~수능", name: "도치 · 강조", rules: ["부정어 도치", "부정어 도치 (Not only)", "So + 형용사 도치", "so / neither", "so / neither + 조동사", "도치된 문장의 수일치", "강조 구문 It ~ that"]),
        Topic(level: "고1~수능", name: "병렬구조 · 동사와 준동사", rules: ["병렬구조", "병렬구조 (동사 시제)", "동사 vs 준동사", "동사가 없는 문장", "주격 관계대명사 뒤 수일치"]),
        Topic(level: "고1~수능", name: "형용사와 부사", rules: ["감각동사 + 형용사", "동사를 꾸미는 부사", "형용사를 꾸미는 부사", "hard / hardly", "late / lately", "목적격 보어는 형용사"]),
        Topic(level: "고1~수능", name: "대명사", rules: ["재귀대명사", "대명사 that / those"]),
        Topic(level: "고1~수능", name: "조동사 심화", rules: ["조동사 + have p.p.", "had better + 동사원형", "would rather + 동사원형", "used to + 동사원형", "used to", "cannot but + 동사원형"]),
        Topic(level: "고1~수능", name: "비교 구문 심화", rules: ["비교급 + than any other + 단수", "라틴어 비교급", "No other + 단수", "prefer A to B", "the 비교급, the 비교급"]),
        Topic(level: "고1~수능", name: "자동사 · 타동사", rules: ["lie / lay", "rise / raise", "타동사 + 목적어", "explain + 사물 + to 사람", "arrive at/in"]),
        Topic(level: "고1~수능", name: "명사절 · 가주어 · 가목적어", rules: ["명사절 what", "명사절 that", "동격의 that", "가목적어 it"])
    ]

    /// 규칙 이름 → 학년 (모르면 nil)
    static func level(of rule: String) -> String? { topics.first { $0.rules.contains(rule) }?.level }
    static func topic(of rule: String) -> String? { topics.first { $0.rules.contains(rule) }?.name }

    /// 확실히 틀린 곳 모두
    static func check(sentence: String) -> [Issue] { DoitSentenceCheck.errors(in: sentence) }

    /// 확실한 오류가 딱 하나이고 고칠 말을 알면 고친 문장 (아니면 nil)
    static func correct(_ sentence: String) -> String? {
        let issues = check(sentence: sentence)
        guard issues.count == 1, let issue = issues.first, let at = issue.at, let fix = issue.fix else { return nil }
        return apply(fix, at: at, length: issue.length, to: sentence)
    }

    /// 문장의 at번째 낱말(구두점 뺀 번호)부터 length개를 fix로 바꾸기 (구두점은 그대로)
    static func apply(_ fix: String, at: Int, length: Int, to sentence: String) -> String? {
        var pieces = sentence.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var map: [Int] = []   // 낱말 번호 → 조각 번호
        for (k, piece) in pieces.enumerated() {
            let core = piece.replacingOccurrences(of: "’", with: "'").trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"“”()"))
            if !core.isEmpty { map.append(k) }
        }
        guard at >= 0, at + length <= map.count else { return nil }
        let first = map[at]
        let piece = pieces[first]
        let lead = String(piece.prefix { ".,!?;:\"“”()".contains($0) })
        let lastPiece = pieces[map[at + length - 1]]
        let trail = String(lastPiece.reversed().prefix { ".,!?;:\"“”()".contains($0) }.reversed())
        var word = fix
        if at == 0, let c = word.first { word = c.uppercased() + word.dropFirst() }
        else if let c = word.first, piece.dropFirst(lead.count).first?.isUppercase == true, word != "i" { word = c.uppercased() + word.dropFirst() }
        let replacement = word.isEmpty ? (trail.isEmpty ? "" : trail) : lead + word + trail
        let removeRange = first...map[at + length - 1]
        pieces.replaceSubrange(removeRange, with: replacement.isEmpty ? [] : [replacement])
        var out = pieces.joined(separator: " ")
        out = out.replacingOccurrences(of: " ,", with: ",").replacingOccurrences(of: " .", with: ".").replacingOccurrences(of: " ?", with: "?")
        // 문장 처음이 지워졌으면 다음 낱말을 대문자로
        if at == 0, word.isEmpty, let c = out.first { out = c.uppercased() + out.dropFirst() }
        return out
    }
}
