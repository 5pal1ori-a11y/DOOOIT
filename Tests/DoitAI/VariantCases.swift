import Foundation

// MARK: - 기출 유형 · 변형 문제 (정답은 엔진이 다시 확인한 것만) + 구조화된 답

// ---- 독립 재계산 도우미 (엔진 코드를 쓰지 않고 문제 글에서 직접 읽어 다시 계산) ----

private func vNorm(_ s: String) -> String { s.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: " ", with: "") }

/// "2x² − 4x + 1" → [차수: 계수]
private func vPoly(_ text: String) -> [Int: Double]? {
    let s = Array(vNorm(text))
    var coeffs: [Int: Double] = [:]
    var i = 0
    while i < s.count {
        var sign = 1.0
        if s[i] == "+" { i += 1 } else if s[i] == "-" { sign = -1; i += 1 }
        var digits = ""
        while i < s.count, s[i].isNumber || s[i] == "." { digits.append(s[i]); i += 1 }
        var degree = 0
        if i < s.count, s[i] == "x" {
            degree = 1
            i += 1
            if i < s.count, s[i] == "²" { degree = 2; i += 1 } else if i < s.count, s[i] == "³" { degree = 3; i += 1 }
        } else if digits.isEmpty {
            return nil
        }
        guard digits.isEmpty ? degree > 0 : Double(digits) != nil else { return nil }
        coeffs[degree, default: 0] += sign * (digits.isEmpty ? 1 : Double(digits)!)
    }
    return coeffs
}

private func vEval(_ p: [Int: Double], _ x: Double) -> Double {
    p.reduce(0) { $0 + $1.value * pow(x, Double($1.key)) }
}

private func vGcd(_ a: Int, _ b: Int) -> Int { b == 0 ? abs(a) : vGcd(b, a % b) }

private func vChoose(_ n: Int, _ r: Int) -> Int {
    guard r >= 0, r <= n else { return 0 }
    var result = 1
    for k in 0..<r { result = result * (n - k) / (k + 1) }
    return result
}

/// 문제 글을 직접 읽고 다시 계산한 답 (읽을 수 없는 글은 nil)
private func vRecompute(_ question: String) -> Double? {
    func int(_ s: Substring) -> Int { Int(s.replacingOccurrences(of: "−", with: "-")) ?? 0 }
    if let m = question.firstMatch(of: #/^이차방정식 (.+) = 0 의 두 근 중 큰 근은\?/#), let p = vPoly(String(m.1)) {
        return (-300...300).map(Double.init).filter { abs(vEval(p, $0)) < 1e-9 }.max()
    }
    if let m = question.firstMatch(of: #/^방정식 (.+) = (.+) 의 해는\?/#), let l = vPoly(String(m.1)), let r = vPoly(String(m.2)) {
        let a = (l[1] ?? 0) - (r[1] ?? 0), b = (l[0] ?? 0) - (r[0] ?? 0)
        return a == 0 ? nil : -b / a
    }
    if let m = question.firstMatch(of: #/^(\d+)명 중에서 회장 1명, 부회장 1명(, 총무 1명)?을 뽑는/#) {
        let n = int(m.1)
        return Double(m.2 == nil ? n * (n - 1) : n * (n - 1) * (n - 2))
    }
    if let m = question.firstMatch(of: #/^(\d+)명 중에서 대표 (\d+)명을 뽑는/#) { return Double(vChoose(int(m.1), int(m.2))) }
    if let m = question.firstMatch(of: #/A\((-?\d+), (-?\d+)\), B\((-?\d+), (-?\d+)\) 사이의 거리는\?/#) {
        let dx = Double(int(m.3) - int(m.1)), dy = Double(int(m.4) - int(m.2))
        return (dx * dx + dy * dy).squareRoot()
    }
    if let m = question.firstMatch(of: #/^(\d+)원짜리 물건을 (\d+)% 할인하면/#) { return Double(int(m.1)) * Double(100 - int(m.2)) / 100 }
    if let m = question.firstMatch(of: #/^(\d+)와 (\d+)의 최대공약수는\?/#) { return Double(vGcd(int(m.1), int(m.2))) }
    if let m = question.firstMatch(of: #/^(\d+)와 (\d+)의 최소공배수는\?/#) { return Double(int(m.1) / vGcd(int(m.1), int(m.2)) * int(m.2)) }
    if let m = question.firstMatch(of: #/^자료 ([\d, ]+)의 평균은\?/#) {
        let values = String(m.1).components(separatedBy: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
    if let m = question.firstMatch(of: #/첫째항이 (-?\d+), 공차가 (-?\d+)인 등차수열의 제(\d+)항은/#) { return Double(int(m.1) + (int(m.3) - 1) * int(m.2)) }
    if let m = question.firstMatch(of: #/첫째항이 (-?\d+), 공비가 (-?\d+)인 등비수열의 제(\d+)항은/#) { return Double(int(m.1)) * pow(Double(int(m.2)), Double(int(m.3) - 1)) }
    if let m = question.firstMatch(of: #/^f\(x\) = (.+) 일 때 f'\((-?\d+)\)의 값은\?/#), let p = vPoly(String(m.1)) {
        let a = Double(int(m.2))
        return p.reduce(0) { $0 + ($1.key == 0 ? 0 : Double($1.key) * $1.value * pow(a, Double($1.key - 1))) }
    }
    if let m = question.firstMatch(of: #/^다항식 f\(x\) = (.+) 를 x ([+−-]) (\d+)로 나눈 나머지는\?/#), let p = vPoly(String(m.1)) {
        let c = Double(int(m.3))
        return vEval(p, m.2 == "+" ? -c : c)
    }
    if let m = question.firstMatch(of: #/^\((\d*)x ([+−-]) (\d+)\)\(x ([+−-]) (\d+)\) 를 전개했을 때 x의 계수는/#) {
        let lead = m.1.isEmpty ? 1 : int(m.1)
        let p = int(m.3) * (m.2 == "+" ? 1 : -1), q = int(m.5) * (m.4 == "+" ? 1 : -1)
        return Double(lead * q + p)
    }
    if let m = question.firstMatch(of: #/^연립방정식 (.+), (.+) 의 해를 x = p, y = q 라 할 때 p \+ q 의 값은\?/#) {
        func parse(_ s: Substring) -> (Double, Double, Double)? {
            guard let e = vNorm(String(s)).firstMatch(of: #/^([+-]?\d*)x([+-])(\d*)y=(-?\d+)$/#) else { return nil }
            func coef(_ t: Substring) -> Double { t.isEmpty || t == "+" ? 1 : (t == "-" ? -1 : Double(String(t)) ?? 0) }
            let b = Double(e.3.isEmpty ? "1" : String(e.3)) ?? 1
            return (coef(e.1), e.2 == "-" ? -b : b, Double(String(e.4)) ?? 0)
        }
        guard let (a1, b1, c1) = parse(m.1), let (a2, b2, c2) = parse(m.2) else { return nil }
        let det = a1 * b2 - a2 * b1
        guard det != 0 else { return nil }
        return (c1 * b2 - c2 * b1) / det + (a1 * c2 - a2 * c1) / det
    }
    if let m = question.firstMatch(of: #/^이차함수 y = (.+) 의 (꼭짓점의 좌표|최댓값|최솟값)는\?/#), let p = vPoly(String(m.1)), let a = p[2], a != 0 {
        let h = -(p[1] ?? 0) / (2 * a), k = vEval(p, h)
        return m.2 == "꼭짓점의 좌표" ? nil : k
    }
    return nil
}

/// 좌표 답 "(h, k)" 를 문제 글에서 다시 계산
private func vRecomputeVertex(_ question: String) -> (Double, Double)? {
    guard let m = question.firstMatch(of: #/^이차함수 y = (.+) 의 꼭짓점의 좌표는\?/#), let p = vPoly(String(m.1)), let a = p[2], a != 0 else { return nil }
    let h = -(p[1] ?? 0) / (2 * a)
    return (h, vEval(p, h))
}

private func vNumber(_ answer: String) -> Double? { Double(answer.replacingOccurrences(of: "−", with: "-")) }

@MainActor
func runVariantCases() async {
    let chapterTopics = MathProblems.Topic.allCases
    // 1) 수학 목록: 확인할 수 없는 주제는 나오지 않음
    var offeredMath = Set<String>()
    for level in [SchoolLevel.elementary, .middle, .high] {
        for t in DoitVariants.topics(subject: .math, level: level) {
            if case .math(let list) = t.source { list.forEach { offeredMath.insert("\($0)") } }
        }
    }
    let unverifiable: [MathProblems.Topic] = [.sumProduct, .matrix, .proposition, .inverse, .rational, .irrational]
    for topic in unverifiable {
        check("변형 문제: 확인 못 하는 주제는 안 냄 (\(topic))", !offeredMath.contains("\(topic)"))
        let hidden = VariantTopic(subject: .math, level: .high, title: "\(topic)", detail: "", source: .math([topic]))
        check("변형 문제: 확인 못 하는 주제는 문제도 안 만듦 (\(topic))", !DoitVariants.isOffered(hidden) && DoitVariants.makeSet(topic: hidden, level: 1).isEmpty)
    }
    check("변형 문제: 수학 주제 \(offeredMath.count)개 (중학교 \(DoitVariants.topics(subject: .math, level: .middle).count) · 고등 \(DoitVariants.topics(subject: .math, level: .high).count))",
          offeredMath.count >= 20 && chapterTopics.count > offeredMath.count)
    check("변형 문제: 초등 수학은 없음 (풀이 엔진이 확인하는 주제가 없어요)", DoitVariants.topics(subject: .math, level: .elementary).isEmpty)
    let bogusGrammar = VariantTopic(subject: .english, level: .middle, title: "없는 단원", detail: "", source: .grammar(subjectName: "중학교 영어", unit: "없는 단원"))
    let bogusKnowledge = VariantTopic(subject: .science, level: .middle, title: "없는 단원", detail: "", source: .knowledge(subjectName: "중학교 과학", unit: "없는 단원"))
    check("변형 문제: 자료에 없는 단원은 안 냄", !DoitVariants.isOffered(bogusGrammar) && !DoitVariants.isOffered(bogusKnowledge)
          && DoitVariants.makeSet(topic: bogusGrammar, level: 1).isEmpty && DoitVariants.makeSet(topic: bogusKnowledge, level: 2).isEmpty)

    // 2) 수학 변형 문제 전수 검사: 주제 × 단계 × 많은 번
    var mathItems = 0, recomputed = 0, wrong = 0, ungradable = 0
    var perTopic: [String: Int] = [:]
    var wrongLines: [String] = []
    for level in [SchoolLevel.middle, .high] {
        for t in DoitVariants.topics(subject: .math, level: level) {
            guard case .math(let list) = t.source else { continue }
            check("변형 문제: \(level.rawValue) \(t.title) 단계 수 1~2", (1...2).contains(DoitVariants.levelCount(t)))
            for lv in 1...DoitVariants.levelCount(t) {
                var made = 0
                for _ in 0..<45 {
                    guard let item = DoitVariants.makeItem(topic: t, level: lv) else { continue }
                    made += 1
                    mathItems += 1
                    // 정답을 넣으면 정답, 다른 보기·엉뚱한 값은 오답
                    let right = DoitPractice.grade(item, answer: item.answer).verdict == .correct
                    var rejectsWrong = true
                    if item.kind == .multipleChoice, let n = Int(item.answer) {
                        for other in 1...item.choices.count where other != n && DoitPractice.grade(item, answer: "\(other)").verdict == .correct { rejectsWrong = false }
                    } else if DoitPractice.grade(item, answer: "123456").verdict == .correct { rejectsWrong = false }
                    if !right || !rejectsWrong { ungradable += 1; wrongLines.append("채점 불가: \(item.question) → \(item.answer)") }
                    if item.explanation.isEmpty || item.concept.isEmpty { ungradable += 1; wrongLines.append("해설/개념 없음: \(item.question)") }
                    // 독립 재계산
                    var shownAnswer = item.answer
                    if item.kind == .multipleChoice, let n = Int(item.answer), n >= 1, n <= item.choices.count { shownAnswer = item.choices[n - 1] }
                    if let expected = vRecompute(item.question) {
                        recomputed += 1
                        perTopic["\(list[0])", default: 0] += 1
                        if let got = vNumber(shownAnswer), abs(got - expected) < 1e-6 {} else { wrong += 1; wrongLines.append("재계산 불일치: \(item.question) → \(shownAnswer) (기대 \(expected))") }
                    } else if let (h, k) = vRecomputeVertex(item.question) {
                        recomputed += 1
                        perTopic["\(list[0])", default: 0] += 1
                        let nums = DoitVariants.values(shownAnswer)
                        if nums.count == 2, abs(nums[0] - h) < 1e-6, abs(nums[1] - k) < 1e-6 {} else { wrong += 1; wrongLines.append("꼭짓점 불일치: \(item.question) → \(shownAnswer) (기대 \(h), \(k))") }
                    }
                }
                check("변형 문제: \(level.rawValue) \(t.title) \(DoitVariants.levelName(lv, of: t)) 문제를 만들 수 있음", made >= 15, "\(made)/45")
            }
            let set = DoitVariants.makeSet(topic: t, level: 1)
            check("변형 문제: \(level.rawValue) \(t.title) 5개 세트 · 서로 다른 문제", set.count == DoitVariants.setSize && Set(set.map { DoitPractice.questionKey($0.question) }).count == set.count, "\(set.count)")
        }
    }
    for line in wrongLines.prefix(12) { check("변형 문제(수학): \(line)", false) }
    check("변형 문제(수학): 독립 재계산으로 확인한 문제 \(recomputed)개 (\(perTopic.count)개 주제)", recomputed >= 400 && perTopic.count >= 12, "\(recomputed) / \(perTopic)")
    check("변형 문제(수학): 오답 0", wrong == 0 && ungradable == 0, "재계산 \(wrong) · 채점 \(ungradable)")
    print("[변형 문제] 수학 \(mathItems)문제 · 독립 재계산 \(recomputed)개 · 오답 \(wrong + ungradable)")

    // 2-2) 전개 문제 확인기
    check("변형 문제: 식에서 x의 계수 읽기", DoitVariants.coefficientOfX(in: "x² − 4x − 21") == -4 && DoitVariants.coefficientOfX(in: "2x² + 22x + 7") == 22
          && DoitVariants.coefficientOfX(in: "x² − 36") == 0 && DoitVariants.coefficientOfX(in: "x + 5") == 1)
    let badExpand = Problem(question: "(x + 3)(x − 7) 를 전개했을 때 x의 계수는?", choices: [], answerNumber: 0, steps: ["x 계수 = 1×-7 + 3", "= -3"], finalAnswer: "-3")
    check("변형 문제: 틀린 정답은 걸러냄 (전개)", !DoitVariants.confirmed(badExpand, topic: .expand))
    let goodExpand = Problem(question: "(x + 3)(x − 7) 를 전개했을 때 x의 계수는?", choices: [], answerNumber: 0, steps: ["x 계수 = 1×-7 + 3", "= -4"], finalAnswer: "-4")
    check("변형 문제: 맞는 정답은 통과 (전개)", DoitVariants.confirmed(goodExpand, topic: .expand))
    let badLinear = Problem(question: "방정식 2x + 3 = 11 의 해는?", choices: [], answerNumber: 0, steps: ["2x = 8", "x = 5"], finalAnswer: "5")
    check("변형 문제: 틀린 정답은 걸러냄 (일차방정식)", !DoitVariants.confirmed(badLinear, topic: .linear))
    let badSteps = Problem(question: "방정식 2x + 3 = 11 의 해는?", choices: [], answerNumber: 0, steps: ["2x = 8", "x = 5"], finalAnswer: "4")
    check("변형 문제: 풀이 줄과 정답이 다르면 걸러냄", !DoitVariants.confirmed(badSteps, topic: .linear))

    // 3) 영어 문법 · 과학 · 사회: 문제 은행에서 (정답을 넣으면 정답 · 다른 보기는 오답)
    var bankItems = 0, bankBad = 0
    var bankTopics = 0
    var bankLines: [String] = []
    for subject in [VariantTopic.Subject.english, .science, .social] {
        for level in [SchoolLevel.elementary, .middle, .high] {
            let list = DoitVariants.topics(subject: subject, level: level)
            check("변형 문제: \(subject.rawValue) \(level.rawValue) 주제가 있음", !list.isEmpty, "\(list.count)")
            var ids = Set<String>()
            for t in list {
                bankTopics += 1
                check("변형 문제: 주제 id가 겹치지 않음 \(t.id)", ids.insert(t.id).inserted)
                let pool = DoitVariants.pool(t)
                check("변형 문제: \(subject.rawValue) \(t.title) 문제 은행 \(DoitVariants.setSize)개 이상", pool.count >= DoitVariants.setSize, "\(pool.count)")
                for lv in 1...DoitVariants.levelCount(t) {
                    let set = DoitVariants.makeSet(topic: t, level: lv)
                    if set.count != DoitVariants.setSize { bankBad += 1; bankLines.append("\(t.title) \(lv)단계 \(set.count)개") }
                    if Set(set.map { DoitPractice.questionKey($0.question) }).count != set.count { bankBad += 1; bankLines.append("\(t.title) 겹치는 문제") }
                    for item in set {
                        bankItems += 1
                        if !DoitVariants.verified(item, topic: t) { bankBad += 1; bankLines.append("확인 실패: \(item.question)") }
                        if DoitPractice.grade(item, answer: item.answer.contains("|") ? (DoitGrader.alternatives(item.answer).first ?? item.answer) : item.answer).verdict != .correct {
                            bankBad += 1; bankLines.append("정답 채점 실패: \(item.question)")
                        }
                        if item.explanation.isEmpty { bankBad += 1; bankLines.append("해설 없음: \(item.question)") }
                    }
                }
            }
        }
    }
    for line in bankLines.prefix(12) { check("변형 문제(문제 은행): \(line)", false) }
    check("변형 문제(문제 은행): \(bankTopics)개 주제 · \(bankItems)문제 · 오답 0", bankBad == 0 && bankTopics >= 100 && bankItems >= 1500, "\(bankBad) / \(bankTopics) / \(bankItems)")
    print("[변형 문제] 영어·과학·사회 \(bankTopics)개 주제 · \(bankItems)문제 · 오답 \(bankBad)")

    // 4) 단계: 고른 단계의 문제를 먼저 · 이미 낸 문제는 피함
    if let past = DoitVariants.topics(subject: .english, level: .middle).first(where: { $0.title == "과거시제" }) {
        for lv in 1...3 {
            let set = DoitVariants.makeSet(topic: past, level: lv)
            check("변형 문제: 과거시제 \(lv)단계는 \(lv)단계 문제부터", set.count == 5 && set.allSatisfy { $0.level == lv }, "\(set.map(\.level))")
        }
        let first = DoitVariants.makeSet(topic: past, level: 1)
        let again = DoitVariants.makeSet(topic: past, level: 1, avoid: Set(first.map { DoitPractice.questionKey($0.question) }))
        check("변형 문제: 비슷한 문제 한 번 더는 새 문제", again.count == 5 && Set(again.map { DoitPractice.questionKey($0.question) }).isDisjoint(with: Set(first.map { DoitPractice.questionKey($0.question) })))
        let all = Set(DoitVariants.pool(past).map { DoitPractice.questionKey($0.question) })
        check("변형 문제: 다 풀면 더 낼 문제가 없음 (지어내지 않음)", DoitVariants.makeSet(topic: past, level: 1, avoid: all).isEmpty)
    } else {
        check("변형 문제: 중학교 영어 과거시제가 목록에 있음", false)
    }
    if let quad = DoitVariants.topics(subject: .math, level: .high).first(where: { $0.title == "이차방정식" }) {
        let a = DoitVariants.makeSet(topic: quad, level: 1)
        let b = DoitVariants.makeSet(topic: quad, level: 2, avoid: Set(a.map { DoitPractice.questionKey($0.question) }))
        check("변형 문제: 수학 한 단계 어렵게 → 심화(단답)", b.count == 5 && b.allSatisfy { $0.level == 2 && $0.kind == .math })
        check("변형 문제: 수학 기본은 객관식 · 서로 다른 문제", a.count == 5 && a.allSatisfy { $0.level == 1 })
        check("변형 문제: 겹치지 않음", Set(a.map { DoitPractice.questionKey($0.question) }).isDisjoint(with: Set(b.map { DoitPractice.questionKey($0.question) })))
    } else {
        check("변형 문제: 고등 이차방정식이 목록에 있음", false)
    }

    // 5) 오답노트로 담을 글
    let mc = PracticeItem(level: 1, kind: .multipleChoice, question: "2 + 3 은?", choices: ["4", "5", "6"], answer: "2", explanation: ["2 + 3 = 5"], concept: "덧셈")
    check("변형 문제: 오답노트 글에 보기 번호", DoitVariants.noteText(mc) == "2 + 3 은?\n① 4 ② 5 ③ 6")
    check("변형 문제: 단답 오답노트 글은 문제 그대로", DoitVariants.noteText(PracticeItem(level: 2, kind: .math, question: "1 + 1 은?", answer: "2", explanation: ["2"], concept: "덧셈")) == "1 + 1 은?")

    // 6) 대화에서 주제 찾기
    check("변형 문제: 이차방정식 풀이에서 → 이차방정식", DoitVariants.topic(forProblem: "x²-5x+6=0 풀어줘")?.title == "이차방정식")
    check("변형 문제: 현재완료 → 영어 문법", DoitVariants.topic(forConcept: "현재완료")?.subject == .english)
    check("변형 문제: 알 수 없는 말은 주제 없음", DoitVariants.topic(forConcept: "아무말대잔치") == nil && DoitVariants.topic(forProblem: "오늘 날씨 어때") == nil)

    // 7) 구조화된 답
    await runStructuredCases()
}

@MainActor
private func runStructuredCases() async {
    let assistant = DoitAssistant.shared

    // 7-1) 수학 풀이: 한 줄 답 + 핵심 + 풀이, 추천 칩은 엔진이 할 수 있는 것만
    assistant.reset()
    await assistant.send("x²-5x+6=0 풀어줘")
    let math = assistant.messages.last
    check("구조화: 수학 풀이는 구조로", math?.structured != nil, math?.text ?? "")
    if let s = math?.structured {
        check("구조화: 수학 한 줄 답", s.headline == "x = 2 또는 x = 3" && s.headlineLabel == "답", s.headline)
        check("구조화: 수학 핵심 · 풀이 칸", s.sections.map(\.label) == ["핵심", "풀이"], "\(s.sections.map(\.label))")
        check("구조화: 풀이 줄이 원래 풀이와 같음", (s.sections.last?.lines.count ?? 0) >= 3 && s.sections.last?.lines.allSatisfy { math?.text.contains($0.components(separatedBy: " → ").first ?? "") == true } == true)
        check("구조화: 수학 변형 문제 주제", s.practice?.title == "이차방정식", s.practice?.title ?? "없음")
    }
    let mathChips = math?.suggestions ?? []
    check("구조화: 추천 칩은 2~3개이고 변형 문제가 앞", (2...3).contains(mathChips.count) && mathChips.first == DoitStructured.practiceChip, "\(mathChips)")
    check("구조화: 변형 문제 칩이 있으면 '비슷한 문제 내줘' 칩은 겹치지 않음", !mathChips.contains("비슷한 문제 내줘"), "\(mathChips)")
    // 칩을 실제로 보내면 모두 답이 나옴 (되묻기 · 모름이 아님)
    for chip in mathChips where chip != DoitStructured.practiceChip {
        assistant.reset()
        await assistant.send("x²-5x+6=0 풀어줘")
        await assistant.send(chip)
        let reply = assistant.messages.last?.text ?? ""
        check("구조화: 추천 칩 '\(chip)'을 보내면 답이 나옴", !reply.isEmpty && !reply.contains("어떤 걸") && !reply.contains("알려줄래요"), reply)
    }
    // 다음 말: 변형 문제 열기 (이차방정식 풀이 뒤)
    assistant.reset()
    await assistant.send("x²-5x+6=0 풀어줘")
    await assistant.send(DoitStructured.practiceChip)
    check("구조화: '변형 문제 풀기'로 주제를 엶", assistant.practiceRequest?.title == "이차방정식", assistant.practiceRequest?.title ?? "없음")
    assistant.practiceRequest = nil

    // 7-2) 개념 설명: 한 줄 답 + 나눈 칸. 칸의 글은 모두 원래 답이나 앱 자료에 있는 글
    let asks = ["광합성이 뭐야?", "현재완료 설명해줘", "to부정사 설명", "수동태가 뭐야", "삼권분립이 뭐야", "이차방정식이 뭐야", "임진왜란 언제야", "순물질이 뭐야"]
    var structuredCount = 0
    for ask in asks {
        assistant.reset()
        await assistant.send(ask)
        guard let message = assistant.messages.last else { check("구조화: \(ask) 답이 있음", false); continue }
        guard let s = message.structured else { continue }
        structuredCount += 1
        let source = message.text.replacingOccurrences(of: "• ", with: "")
        let grammar = DoitGrammar.find(s.title.components(separatedBy: " (").first ?? s.title).first
        let allowedExtra = ((grammar?.traps ?? []) + (grammar?.examples ?? []))
        var foreign: [String] = []
        // (표의 한 줄 제목은 줄 이름을 이어 붙인 것)
        if let table = s.table { check("구조화: '\(ask)' 표 제목은 줄 이름", s.headline == table.rows.map { $0[0] }.joined(separator: " · "), s.headline) }
        for line in (s.table == nil ? [s.headline] : []) + s.sections.flatMap(\.lines) + (s.table?.rows.flatMap { $0 } ?? []) {
            let plain = line.replacingOccurrences(of: "• ", with: "")
            if !source.contains(plain) && !allowedExtra.contains(plain) { foreign.append(plain) }
        }
        check("구조화: '\(ask)' 칸의 글은 모두 원래 답이나 단원 자료에 있음 (지어낸 글 0)", foreign.isEmpty, "\(foreign)")
        check("구조화: '\(ask)' 한 줄 답이 비어 있지 않음 · 칩 3개 이하", !s.headline.isEmpty && message.suggestions.count <= 3, "\(message.suggestions)")
        if s.practice != nil { check("구조화: '\(ask)' 변형 문제 칩은 주제를 낼 수 있을 때만", message.suggestions.contains(DoitStructured.practiceChip) && DoitVariants.isOffered(s.practice!)) }
        else { check("구조화: '\(ask)' 변형 문제 주제가 없으면 칩도 없음", !message.suggestions.contains(DoitStructured.practiceChip)) }
    }
    check("구조화: 개념 설명 \(asks.count)개 중 \(structuredCount)개가 구조로", structuredCount >= 5, "\(structuredCount)")

    // 7-3) 영문법 단원: 주의(자주 틀리는 곳)는 단원 자료에서
    assistant.reset()
    await assistant.send("현재완료 설명해줘")
    if let s = assistant.messages.last?.structured {
        check("구조화: 현재완료 핵심 · 주의 · 예시 · 변형 문제", s.sections.map(\.label).contains("핵심") && s.sections.map(\.label).contains("주의") && s.practice?.subject == .english, "\(s.sections.map(\.label))")
    } else {
        check("구조화: 현재완료는 구조로", false)
    }

    // 7-4) 비교 표 (이름이 있는 줄)
    assistant.reset()
    await assistant.send("순물질이 뭐야")
    if let s = assistant.messages.last?.structured, let table = s.table {
        check("구조화: 순물질 · 혼합물 비교 표", table.rows.count == 2 && table.rows[0][0] == "순물질" && table.rows[1][0] == "혼합물", "\(table)")
    } else {
        check("구조화: 순물질 · 혼합물 비교 표", false)
    }

    // 7-5) A와 B의 차이: 두 단원 자료로 표
    assistant.reset()
    await assistant.send("현재완료와 과거시제 차이")
    let compared = assistant.messages.last
    if let table = compared?.structured?.table {
        let a = DoitGrammar.find("현재완료").first!, b = DoitGrammar.find("과거시제").first!
        check("구조화: 현재완료 vs 과거시제 표 머리글", table.header == ["", "현재완료", "과거시제"], "\(table.header)")
        let fromA = [a.summary] + a.points + a.examples + a.traps, fromB = [b.summary] + b.points + b.examples + b.traps
        check("구조화: 비교 표의 모든 칸은 두 단원 자료의 글", table.rows.allSatisfy { fromA.contains($0[1]) && fromB.contains($0[2]) }, "\(table.rows)")
        check("구조화: 비교 표 줄 2개 이상 · 변형 문제 칩", table.rows.count >= 2 && compared?.structured?.practice != nil)
    } else {
        check("구조화: 현재완료와 과거시제 차이는 표로", false, compared?.text ?? "")
    }
    let n1 = DoitStructured.comparedNames(in: "현재완료와 과거시제의 차이"), n2 = DoitStructured.comparedNames(in: "순물질이랑 혼합물 차이점 알려줘")
    check("구조화: 이름 읽기 (A와 B의 차이)", n1?.0 == "현재완료" && n1?.1 == "과거시제" && n2?.0 == "순물질" && n2?.1 == "혼합물"
          && DoitStructured.comparedNames(in: "광합성이 뭐야") == nil, "\(String(describing: n1)) \(String(describing: n2))")
    check("구조화: 자료에 없는 이름의 차이는 표를 지어내지 않음", DoitStructured.comparison("아무말과 대잔치의 차이") == nil && DoitStructured.comparison("현재완료와 대잔치의 차이") == nil)
    assistant.reset()
    await assistant.send("아무말과 대잔치의 차이")
    check("구조화: 모르는 차이 질문은 표 없이 기존 답", assistant.messages.last?.structured?.table == nil)

    // 7-6) 구조로 바꾸지 않는 말
    for ask in ["안녕", "내일 오후 4시에 수학 공부 추가해줘", "고마워", "오늘 할 일 알려줘"] {
        assistant.reset()
        await assistant.send(ask)
        check("구조화: '\(ask)'는 구조로 안 바꿈", assistant.messages.last?.structured == nil)
    }

    // 7-7) 변형 문제 열기 말
    assistant.reset()
    await assistant.send("현재완료 변형 문제")
    check("변형 문제 열기: '현재완료 변형 문제'", assistant.practiceRequest?.title == "현재완료", assistant.practiceRequest?.title ?? "없음")
    assistant.practiceRequest = nil
    assistant.reset()
    await assistant.send("변형 문제 풀기")
    check("변형 문제 열기: 주제 없으면 짐작하지 않고 되물음", assistant.practiceRequest == nil && assistant.messages.last?.text.contains("어떤 주제") == true, assistant.messages.last?.text ?? "")
    assistant.reset()
    await assistant.send("현재완료 설명해줘")
    await assistant.send("변형 문제 풀기")
    check("변형 문제 열기: 바로 전 주제로", assistant.practiceRequest?.title == "현재완료", assistant.practiceRequest?.title ?? "없음")
    assistant.practiceRequest = nil
    assistant.reset()
    await assistant.send("변형 문제가 뭐야?")
    check("변형 문제 열기: 변형 문제가 뭐냐는 질문은 열지 않음", assistant.practiceRequest == nil)

    // 7-8) 이어 말하기: 예시 · 쉽게
    typealias F = DoitDialogue.FollowUp
    for (input, expected) in [("예 하나만", F.example), ("예 하나만 보여줘", F.example), ("예시 보여줘", F.example), ("더 쉽게 설명해줘", F.simpler), ("왜 그래?", F.why)] as [(String, F)] {
        check("이어 말하기 알아보기: \(input)", DoitDialogue.classify(input) == expected, "\(String(describing: DoitDialogue.classify(input)))")
    }
    assistant.reset()
    await assistant.send("광합성이 뭐야?")
    await assistant.send("예 하나만")
    check("이어 말하기: 광합성 → 예 하나만", assistant.messages.last?.text.isEmpty == false && assistant.messages.last?.text.contains("어떤 것의 예시") == false, assistant.messages.last?.text ?? "")
    assistant.reset()
}
