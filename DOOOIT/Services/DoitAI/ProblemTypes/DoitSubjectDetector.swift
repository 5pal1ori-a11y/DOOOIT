import Foundation

/// 과목 짐작 결과
struct SubjectGuess: Equatable {
    /// 큰 과목: 국어 · 영어 · 수학 · 과학 · 사회 · 윤리 · 역사 · 기타
    var broad: String
    /// 세부 과목 (물리학, 한국사, 생활과 윤리 …). 확실하지 않으면 nil
    var detail: String?
    /// 0 ~ 1
    var confidence: Double
    /// 근거 (찾은 낱말·단서 몇 개)
    var reasons: [String]

    /// 오답노트에 적을 과목 이름 (수학·국어·영어는 큰 과목, 나머지는 세부 과목이 확실하면 그 이름)
    var noteLabel: String {
        guard let detail, DoitSubjectDetector.noteDetails[broad]?.contains(detail) == true else { return broad }
        return detail
    }
}

/// 문제 글로 과목을 짐작해요 (정해진 목록에 매이지 않고, 세부 과목까지).
/// 낱말 사전(무게) + 영어 문장 비율 + 수식 비율 + 지시문 단서 + 맞는 문제 유형 + 교육과정 사전을 함께 봐요.
/// 확실하지 않으면 nil.
enum DoitSubjectDetector {
    static let broadSubjects: [String] = ["국어", "영어", "수학", "과학", "사회", "윤리", "역사", "기타"]

    /// 문제 글 → 과목 (확실하지 않으면 nil)
    static func detect(_ text: String) -> SubjectGuess? {
        let prepared = DoitProblemTypes.Prepared(text)
        guard !prepared.compact.isEmpty else { return nil }
        return detect(prepared: prepared, raw: DoitProblemTypes.rawScores(prepared))
    }

    /// 수식이 많은 글인지 (과목을 모를 때 수학으로 읽을지 정할 때)
    static func looksMath(_ text: String) -> Bool {
        let p = DoitProblemTypes.Prepared(text)
        return p.mathSignal >= 3 && p.englishWords < 8
    }

    // MARK: - 점수

    struct Tally {
        var broad: [String: Double] = [:]
        var detail: [String: [String: Double]] = [:]
        var reasons: [String: [(String, Double)]] = [:]

        mutating func add(_ b: String, _ d: String?, _ w: Double, _ why: String) {
            broad[b, default: 0] += w
            if let d, !d.isEmpty, d != "-" { detail[b, default: [:]][d, default: 0] += w }
            reasons[b, default: []].append((why, w))
        }
    }

    static func detect(prepared p: DoitProblemTypes.Prepared, raw: [(Int, Double)]) -> SubjectGuess? {
        var t = Tally()

        // 1) 낱말 사전 (같은 말이 여러 번 나오면 조금 더)
        for entry in lexicon where p.has(entry.term) {
            var w = entry.weight
            let extra = min(p.compact.components(separatedBy: entry.term).count - 2, 3)
            if extra > 0 { w += Double(extra) * entry.weight * 0.25 }
            t.add(entry.broad, entry.detail, w, entry.term)
        }

        // 2) 영어 문장 비율 (긴 영어 지문이면 영어)
        if p.englishWords >= 12 {
            t.add("영어", "독해", min(Double(p.englishWords) / 3, 14), "영어 문장 \(p.englishWords)단어")
        } else if p.englishWords >= 5 && p.hangul < 60 {
            t.add("영어", nil, Double(p.englishWords) / 2, "영어 낱말 \(p.englishWords)개")
        }

        // 3) 수식 비율
        if p.mathSignal >= 3 {
            t.add("수학", nil, min(Double(p.mathSignal) * 0.7, 9), "수식 기호 \(p.mathSignal)개")
        }

        // 4) 지시문 단서 ("윗글", "<보기>"는 어느 과목에나 나와서 보지 않음)
        for cue in cues where cue.pattern.weight(in: p) > 0 {
            t.add(cue.broad, cue.detail, cue.weight, cue.label)
        }

        // 5) 맞는 문제 유형: 과목마다 가장 높은 유형 점수의 일부 (주제 낱말까지 맞은 유형이 크게)
        var bestByBroad: [String: (Double, ProblemType)] = [:]
        for (index, score) in raw {
            let type = DoitProblemTypes.store.types[index]
            if score > (bestByBroad[type.subject]?.0 ?? 0) { bestByBroad[type.subject] = (score, type) }
        }
        let topRaw = bestByBroad.values.map(\.0).max() ?? 0
        for (broad, best) in bestByBroad where best.0 >= topRaw * 0.75 && best.0 >= 3 {
            // 다른 과목도 거의 같은 점수면(공통 지시문) 덜 믿음
            let rivals = bestByBroad.values.filter { $0.0 >= best.0 * 0.9 }.count
            let anyRival = bestByBroad.values.contains { $0.1.subject != broad && $0.0 >= best.0 * 0.5 }
            // 그 과목에만 있는 지시문이면 크게 (예: "윗글을 바탕으로 <보기>를 이해한" → 국어)
            let w = !anyRival ? min(best.0, 8) * 0.8 : min(best.0, 8) * 0.45 / Double(max(rivals, 1))
            let detail = best.1.topics.isEmpty && best.1.detail == broad ? nil : best.1.detail
            t.add(broad, detail, w, "유형: \(best.1.name)")
        }

        // 6) 교육과정 사전 이름 (약한 단서). 사회 사전에는 역사·윤리도 있어서 그 셋 중 앞선 과목에 줌
        var curriculum: [String: (Double, String)] = [:]
        for item in curriculumTerms where p.has(item.term) {
            let key = item.subject == "사회" ? "사회계열" : item.subject
            curriculum[key] = ((curriculum[key]?.0 ?? 0) + 0.4, item.term)
        }
        for (key, value) in curriculum {
            var subject = key
            if key == "사회계열" {
                let leader = ["사회", "윤리", "역사"].max { (t.broad[$0] ?? 0) < (t.broad[$1] ?? 0) } ?? "사회"
                subject = (t.broad[leader] ?? 0) > 0 ? leader : "사회"
            }
            t.add(subject, nil, min(value.0, 3), value.1)
        }

        // 결정
        let ranked = t.broad.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        guard let top = ranked.first, top.value >= 2.5 else { return nil }
        let second = ranked.count > 1 ? ranked[1].value : 0
        let confidence = top.value / (top.value + second + 1.5)
        guard confidence >= 0.5 else { return nil }

        var detail: String?
        if var details = t.detail[top.key] {
            // "지리" 단서는 한국지리·세계지리 중 앞선 쪽에 더함
            if let geo = details["지리"] {
                let k = details["한국지리"] ?? 0, w = details["세계지리"] ?? 0
                if k > 0 || w > 0 { details[k >= w ? "한국지리" : "세계지리", default: 0] += geo; details["지리"] = nil }
            }
            let d = details.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            if let first = d.first, first.value >= 1.5, first.value >= (d.count > 1 ? d[1].value : 0) * 1.4 { detail = first.key }
        }
        let reasons = (t.reasons[top.key] ?? []).sorted { $0.1 > $1.1 }.map(\.0)
        var unique: [String] = []
        for r in reasons where !unique.contains(r) { unique.append(r); if unique.count >= 4 { break } }
        return SubjectGuess(broad: top.key, detail: detail, confidence: (min(confidence, 0.99) * 100).rounded() / 100, reasons: unique)
    }

    // MARK: - 저장된 과목 이름 → 큰 과목

    /// "" → 수학, "생활과 윤리" → 윤리, "한국사" → 역사, "중학교 과학" → 과학, "물리학" → 과학, "미술" → 기타
    static func broad(ofStored stored: String) -> String {
        let t = stored.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return "수학" }
        if broadSubjects.contains(t) { return t }
        if ["윤리", "도덕", "사상"].contains(where: { t.contains($0) }) { return "윤리" }
        if ["역사", "한국사", "세계사", "동아시아사", "국사"].contains(where: { t.contains($0) }) { return "역사" }
        switch NoteSubject.from(t) {
        case .math: return "수학"
        case .english: return "영어"
        case .korean: return "국어"
        case .science: return "과학"
        case .social: return "사회"
        case .other: return "기타"
        }
    }

    // MARK: - 사전 (처음 쓸 때 한 번만)

    struct Term {
        let term: String
        let broad: String
        let detail: String?
        let weight: Double
    }

    struct Cue {
        let pattern: DoitProblemTypes.Pattern
        let broad: String
        let detail: String?
        let weight: Double
        let label: String
    }

    /// 두 글자 낱말 중 다른 뜻으로 흔히 쓰이는 말 (주제 사전에서 가져올 때 뺌)
    static let ambiguous: Set<String> = ["독립", "종속", "연속", "운동", "위치", "평균", "문화", "가사", "사단", "성선", "성악", "부여", "고려", "가야",
                                         "의상", "순종", "장자", "순자", "이이", "선조", "연기", "무위", "자비", "로그", "수렴", "발산", "이동", "성분",
                                         "원소", "표본", "위도", "경도", "무역", "증가하는", "감소하는", "속도", "속력", "적분", "극한", "집합", "함수",
                                         "명제", "정부", "국가", "단체", "중력", "전류", "저항", "전압", "생식", "소화", "호흡", "효소", "식물", "동물",
                                         "인권", "통일", "국제법", "의석", "투표율", "예금", "주식", "채권", "보험", "석유", "석탄", "난민", "종교"]

    static let lexicon: [Term] = {
        var map: [String: Term] = [:]
        func put(_ term: String, _ broad: String, _ detail: String?, _ weight: Double) {
            let key = DoitProblemTypes.compact(term)
            let ascii = key.allSatisfy { $0.isASCII }
            guard key.count >= (ascii ? 3 : 2) else { return }
            if let old = map[key], old.weight >= weight { return }
            map[key] = Term(term: key, broad: broad, detail: detail == "-" ? nil : detail, weight: weight)
        }
        // 주제 사전의 낱말 (무게 1). 중학 과학은 8번째 칸의 세부 과목으로
        let groups: [(String, String)] = [(DoitProblemTypes.mathTopics, "수학"), (DoitProblemTypes.scienceTopics, "과학"),
                                          (DoitProblemTypes.socialTopics, "사회"), (DoitProblemTypes.ethicsTopics, "윤리"),
                                          (DoitProblemTypes.historyTopics, "역사"), (DoitProblemTypes.englishGrammarTopics, "영어")]
        for (text, broad) in groups {
            for f in DoitProblemTypes.lines(text) where f.count >= 7 {
                let detail: String? = broad == "수학" ? nil : (f.count >= 8 ? f[7] : f[1])
                for word in DoitProblemTypes.topicList(f[3]) where !ambiguous.contains(word) {
                    put(word, broad, detail, 1)
                }
            }
        }
        // 직접 적은 낱말 사전 (더 무거운 쪽이 이김)
        for f in DoitProblemTypes.lines(lexiconText) where f.count >= 4 {
            let weight = Double(f[2]) ?? 1
            for word in f[3].components(separatedBy: ",") {
                let w = word.trimmingCharacters(in: .whitespaces)
                if !w.isEmpty { put(w, f[0], f[1], weight) }
            }
        }
        return map.values.sorted { $0.term < $1.term }
    }()

    /// 지시문 단서
    static let cues: [Cue] = {
        let list: [(String, String, String?, Double, String)] = [
            (#"시대순|시기순|일어난순서|연대순|먼저일어난"#, "역사", nil, 3.5, "시대 순"),
            (#"사상가|사상의입장|사상가의"#, "윤리", "윤리와 사상", 4, "사상가"),
            (#"갑,을은.{0,6}(입장|관점|주장)|을의입장"#, "윤리", nil, 1.2, "갑·을 입장"),
            (#"어법상|어법에맞"#, "영어", "어법", 5, "어법"),
            (#"(대화|담화)를듣고|다음을듣고"#, "영어", "듣기", 5, "듣기"),
            (#"낱말의쓰임|영영풀이"#, "영어", "어휘", 4, "어휘"),
            (#"실험|탐구과정|변인|대조군"#, "과학", nil, 1.5, "실험"),
            (#"지도에|지도의|지도는|지도를"#, "사회", "지리", 2.5, "지도"),
            (#"구하시오|구하여라|값은\?"#, "수학", nil, 1.2, "값 구하기"),
            (#"시적화자|화자의|서술자|작품"#, "국어", "문학", 2.5, "작품"),
            (#"음운|형태소|품사|문장성분"#, "국어", "문법", 3, "문법 용어"),
            (#"실행결과|출력(결과|값)|알고리즘"#, "기타", "정보", 4, "프로그램"),
            (#"한문|한자의(음|뜻|훈)|독음|훈과음"#, "기타", "한문", 2.5, "한문"),
            (#"바꿔쓰기|바꾸어쓰기|바꿔쓴것|바탕으로<보기>를(이해|분석|탐구|평가)|문맥(상|적)의미가"#, "국어", "독서", 8, "독서 지시문"),
            (#"추론한내용으로|윗글을바탕으로"#, "국어", "독서", 3, "독서 지시문"),
            (#"적절하지않은것은|가장적절한것은|적절한것은"#, "국어", nil, 2, "'적절한' 지시문"),
            (#"적절하지않은것은|가장적절한것은|적절한것은"#, "영어", nil, 2, "'적절한' 지시문"),
            (#"다음시|이시의|시의화자|화자에대한|윗글의화자"#, "국어", "문학", 3, "시"),
            (#"몇(명|개|원|cm|km|분|시간|살|권|장|일|g|kg|l|번|배|자루|마리)(인가|일까|입니까|인지|이에요|을|를|이|가|\?)"#, "수학", nil, 3, "몇 개·몇 원"),
            (#"갑:.{4,200}을:"#, "윤리", nil, 1, "갑·을 대화"),
        ]
        return list.map { Cue(pattern: DoitProblemTypes.Pattern($0.0), broad: $0.1, detail: $0.2, weight: $0.3, label: $0.4) }
    }()

    /// 교육과정 사전 이름 → 과목 (세 글자 이상만)
    static let curriculumTerms: [(term: String, subject: String)] = {
        var seen = Set<String>()
        var result: [(String, String)] = []
        for (subject, entries) in DoitCurriculum.bySubject {
            for entry in entries {
                for name in entry.names {
                    let key = DoitProblemTypes.compact(name)
                    guard key.count >= 3, !key.contains("~"), seen.insert(key).inserted else { continue }
                    result.append((key, subject))
                }
            }
        }
        return result
    }()
}
