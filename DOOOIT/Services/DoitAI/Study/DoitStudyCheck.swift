import Foundation

/// AI 학습 자료 검증: 만든 내용을 그대로 보여주지 않고 따로 검사함
/// - 단원 일치: 고른 단원의 자료에 없는 다른 단원 개념이 섞였는지
/// - 근거: 문장이 학습 자료에 근거하는지, 자료에 없는 숫자를 지어냈는지
/// - 문제: 형식 오류, 정답 번호, 보기 중복, 정답 노출, 해설과 정답 일치, 수학 문제는 직접 다시 풀어서 정답 확인
enum DoitStudyCheck {
    struct Issue: Equatable, CustomStringConvertible {
        enum Kind: String { case scope = "단원 불일치", grounding = "근거 없음", format = "형식 오류", answer = "정답 오류", explanation = "해설 불일치" }
        let kind: Kind
        let detail: String
        var description: String { "\(kind.rawValue): \(detail)" }
    }

    /// 검사에 쓰는 자료 묶음 (단원 자료 + 다른 단원 용어)
    struct Basis {
        let materials: [DoitStudyMaterial]
        /// 자료 전체 글 (정규화)
        let text: String
        /// 자료 문장들의 글자 묶음
        let sentences: [(raw: String, grams: [String: Double])]
        /// 이 단원 개념 이름들
        let ownTerms: [String]
        /// 같은 과목 다른 단원에만 나오는 개념 이름들
        let foreignTerms: [String]
        let numbers: Set<String>

        init(materials: [DoitStudyMaterial], scope: StudyScope) {
            self.materials = materials
            let joined = materials.map { $0.title + "\n" + $0.body }.joined(separator: "\n")
            text = DoitStudyCheck.norm(joined)
            sentences = DoitStudyCheck.split(joined).map { ($0, DoitKnowledge.bigrams(DoitStudyCheck.norm($0))) }
            ownTerms = Array(Set(materials.flatMap(\.names))).sorted { $0.count > $1.count }
            numbers = DoitStudyCheck.numbers(in: joined)
            // 다른 단원 용어: 같은 과목의 다른 단원 개념 이름 중, 이 단원 자료 어디에도 나오지 않는 것
            let ownText = text
            let sourceKeys = Set(scope.sources.map { "\($0.level.rawValue)|\($0.unit)" })
            var foreign = Set<String>()
            for entry in DoitCurriculum.bySubject.first(where: { $0.subject == scope.subject })?.entries ?? [] {
                guard !sourceKeys.contains("\(entry.level.rawValue)|\(entry.unit)") else { continue }
                for name in entry.names {
                    let key = DoitStudyCheck.norm(name)
                    if key.count >= 3, key.unicodeScalars.contains(where: { $0.value >= 0xAC00 }), !ownText.contains(key) { foreign.insert(name) }
                }
            }
            if scope.subject == "수학" {
                // 학교급을 넘는 수학 용어 (예: 중학교 이차방정식에 "근과 계수의 관계")
                for term in ["근과 계수의 관계", "판별식", "허근", "복소수", "허수", "나머지정리", "인수정리", "조립제법", "미분계수", "도함수", "정적분", "부정적분", "로그", "삼각함수", "수열의 극한", "행렬"] {
                    let key = DoitStudyCheck.norm(term)
                    if !ownText.contains(key) { foreign.insert(term) }
                }
            }
            foreignTerms = foreign.sorted { $0.count > $1.count }
        }
    }

    // MARK: - 공통 검사

    /// 다른 단원 개념이 들어 있는지 (이 단원 용어 안에 들어 있는 말은 빼고 봄: "이차방정식" 속 "방정식")
    static func foreignTerms(in text: String, basis: Basis) -> [String] {
        var t = norm(text)
        for own in basis.ownTerms.map(norm) where own.count >= 2 { t = t.replacingOccurrences(of: own, with: "∎") }
        return basis.foreignTerms.filter { t.contains(norm($0)) }
    }

    /// 자료에 근거한 문장인지: 가장 비슷한 자료 문장과 충분히 겹치거나, 핵심 낱말이 대부분 자료에 있음
    static func isGrounded(_ sentence: String, basis: Basis, threshold: Double = 0.42) -> Bool {
        let n = norm(sentence)
        guard n.count >= 4 else { return true }
        let grams = DoitKnowledge.bigrams(n)
        let best = basis.sentences.map { DoitKnowledge.cosine(grams, $0.grams) }.max() ?? 0
        if best >= threshold { return true }
        let words = contentWords(sentence)
        guard words.count >= 2 else { return best >= threshold * 0.8 }
        let covered = words.filter { basis.text.contains(norm($0)) }.count
        return Double(covered) / Double(words.count) >= 0.8
    }

    /// 자료에 없는 숫자를 지어냈는지 (번호·작은 수는 빼고)
    static func inventedNumbers(in sentence: String, basis: Basis) -> [String] {
        numbers(in: sentence).filter { number in
            if let value = Int(number), value <= 10 { return false }
            return !basis.numbers.contains(number)
        }.sorted()
    }

    /// 한 문장 검사 (단원 일치 + 근거 + 숫자)
    static func checkSentence(_ sentence: String, basis: Basis, label: String) -> [Issue] {
        var issues: [Issue] = []
        let foreign = foreignTerms(in: sentence, basis: basis)
        if !foreign.isEmpty { issues.append(Issue(kind: .scope, detail: "\(label)에 다른 단원 개념(\(foreign.prefix(3).joined(separator: ", ")))이 있어요")) }
        if !isGrounded(sentence, basis: basis) { issues.append(Issue(kind: .grounding, detail: "\(label)이(가) 학습 자료에 근거하지 않아요")) }
        let invented = inventedNumbers(in: sentence, basis: basis)
        if !invented.isEmpty { issues.append(Issue(kind: .grounding, detail: "\(label)에 자료에 없는 수(\(invented.prefix(3).joined(separator: ", ")))가 있어요")) }
        return issues
    }

    // MARK: - 자료 종류별 검사

    static func check(_ note: ConceptNote, basis: Basis) -> [Issue] {
        var issues: [Issue] = []
        if note.keyPoints.count < 1 { issues.append(Issue(kind: .format, detail: "학습 포인트가 없어요")) }
        if !note.summary.isEmpty { issues += checkSentence(note.summary, basis: basis, label: "핵심 개념") }
        for (index, point) in note.keyPoints.enumerated() { issues += checkSentence(point, basis: basis, label: "학습 포인트 \(index + 1)") }
        for (index, detail) in note.details.enumerated() { issues += checkSentence(detail, basis: basis, label: "상세 설명 \(index + 1)") }
        for (index, line) in note.principles.enumerated() { issues += checkSentence(line, basis: basis, label: "원리 \(index + 1)") }
        for (index, line) in note.mistakes.enumerated() { issues += checkSentence(line, basis: basis, label: "실수 \(index + 1)") }
        return issues
    }

    static func check(_ item: ClozeItem, basis: Basis) -> [Issue] {
        var issues: [Issue] = []
        let blanks = item.sentence.components(separatedBy: blank).count - 1
        if blanks != 1 { issues.append(Issue(kind: .format, detail: "빈칸이 \(blanks)개예요")) }
        if item.answer.isEmpty || item.sentence.contains(item.answer) { issues.append(Issue(kind: .format, detail: "정답이 문장에 그대로 보여요")) }
        if !basis.text.contains(norm(item.answer)) { issues.append(Issue(kind: .answer, detail: "정답 '\(item.answer)'이 자료에 없어요")) }
        issues += checkSentence(item.sentence.replacingOccurrences(of: blank, with: item.answer), basis: basis, label: "빈칸 문장")
        return issues
    }

    static func check(_ item: OXItem, basis: Basis) -> [Issue] {
        var issues: [Issue] = []
        if item.statement.count < 8 { issues.append(Issue(kind: .format, detail: "문장이 너무 짧아요")) }
        if item.explanation.isEmpty { issues.append(Issue(kind: .explanation, detail: "해설이 없어요")) }
        let foreign = foreignTerms(in: item.statement, basis: basis)
        if !foreign.isEmpty { issues.append(Issue(kind: .scope, detail: "O/X 문장에 다른 단원 개념(\(foreign.prefix(3).joined(separator: ", ")))이 있어요")) }
        if item.isTrue {
            // 맞는 문장은 자료와 거의 같아야 함
            if !isGrounded(item.statement, basis: basis, threshold: 0.55) { issues.append(Issue(kind: .answer, detail: "'맞다'고 한 문장이 자료로 확인되지 않아요")) }
            let invented = inventedNumbers(in: item.statement, basis: basis)
            if !invented.isEmpty { issues.append(Issue(kind: .answer, detail: "맞는 문장에 자료에 없는 수가 있어요")) }
        } else {
            // 틀린 문장도 자료의 한 문장에서 나와야 함 (엉뚱한 문장 금지)
            if !isGrounded(item.statement, basis: basis, threshold: 0.35) { issues.append(Issue(kind: .grounding, detail: "'틀리다'고 한 문장이 단원 자료와 관련이 없어요")) }
            // 자료 문장과 완전히 같으면 사실은 맞는 문장
            if basis.sentences.contains(where: { norm($0.raw) == norm(item.statement) }) { issues.append(Issue(kind: .answer, detail: "'틀리다'고 한 문장이 자료와 똑같아요")) }
        }
        return issues
    }

    /// 객관식 검사. solver: 수학 문제를 직접 풀어 정답을 돌려주는 함수 (풀 수 없으면 nil)
    static func check(_ problem: Problem, basis: Basis, solver: ((String) -> String?)? = nil) -> [Issue] {
        var issues: [Issue] = []
        let choices = problem.choices.map { $0.trimmingCharacters(in: .whitespaces) }
        if choices.count < 3 { issues.append(Issue(kind: .format, detail: "보기가 \(choices.count)개뿐이에요")) }
        if Set(choices.map(norm)).count != choices.count { issues.append(Issue(kind: .format, detail: "같은 보기가 있어요")) }
        guard (1...max(1, choices.count)).contains(problem.answerNumber), problem.answerNumber <= choices.count else {
            return issues + [Issue(kind: .answer, detail: "정답 번호(\(problem.answerNumber))가 보기 범위를 벗어나요")]
        }
        let correct = choices[problem.answerNumber - 1]
        if !problem.finalAnswer.contains(correct) && !problem.finalAnswer.contains("\(problem.answerNumber)번") {
            issues.append(Issue(kind: .explanation, detail: "정답 표시가 정답 보기와 달라요"))
        }
        // 해설이 다른 보기를 정답이라고 하지 않는지
        let explanation = problem.steps.joined(separator: " ")
        if explanation.isEmpty { issues.append(Issue(kind: .explanation, detail: "해설이 없어요")) }
        for (index, choice) in choices.enumerated() where index != problem.answerNumber - 1 {
            if explanation.contains("정답은 \(index + 1)번") || explanation.contains("정답은 '\(choice)'") { issues.append(Issue(kind: .explanation, detail: "해설이 다른 보기를 정답이라고 해요")) }
        }
        if let solver, let solved = solver(problem.question) {
            // 수학: 직접 풀어서 정답 보기와 같은지
            if !sameAnswer(solved, correct) { issues.append(Issue(kind: .answer, detail: "다시 풀어 보니 정답은 \(solved)이에요 (표시된 정답 \(correct))")) }
        } else if problem.question.contains("옳지 않은 것") {
            // 틀린 것 고르기: 정답(틀린 문장)은 자료와 달라야 하고, 나머지(맞는 문장)는 자료로 확인돼야 함
            if basis.sentences.contains(where: { norm($0.raw) == norm(correct) }) { issues.append(Issue(kind: .answer, detail: "정답으로 고른 '틀린 문장'이 자료와 똑같아요")) }
            for (index, choice) in choices.enumerated() where index != problem.answerNumber - 1 {
                if !isGrounded(choice, basis: basis, threshold: 0.55) { issues.append(Issue(kind: .answer, detail: "\(index + 1)번 보기가 맞는 문장인지 자료로 확인되지 않아요")) }
            }
            let foreign = foreignTerms(in: choices.joined(separator: " "), basis: basis)
            if !foreign.isEmpty { issues.append(Issue(kind: .scope, detail: "보기에 다른 단원 개념(\(foreign.prefix(3).joined(separator: ", ")))이 있어요")) }
        } else if problem.question.contains("(   )") || problem.question.hasPrefix("다음 설명") {
            // 개념 문제: 정답 보기가 자료의 개념이어야 하고, 문제에 정답이 드러나지 않아야 함
            if !basis.text.contains(norm(correct)) { issues.append(Issue(kind: .answer, detail: "정답 보기 '\(correct)'가 자료에 없어요")) }
            if norm(problem.question).contains(norm(correct)) { issues.append(Issue(kind: .format, detail: "문제에 정답이 그대로 보여요")) }
            if problem.question.components(separatedBy: blank).count - 1 > 1 { issues.append(Issue(kind: .format, detail: "빈칸이 여러 개라 헷갈려요")) }
            // 오답 보기 이름이 문제 글에 나오면 헷갈림
            for (index, choice) in choices.enumerated() where index != problem.answerNumber - 1 && choice.count >= 2 && problem.question.contains(choice) {
                issues.append(Issue(kind: .format, detail: "\(index + 1)번 보기 '\(choice)'가 문제 글에 나와 헷갈려요"))
            }
            let foreign = foreignTerms(in: problem.question + " " + choices.joined(separator: " "), basis: basis)
            if !foreign.isEmpty { issues.append(Issue(kind: .scope, detail: "문제에 다른 단원 개념(\(foreign.prefix(3).joined(separator: ", ")))이 있어요")) }
        }
        return issues
    }

    // MARK: - 도우미

    static let blank = "(   )"

    static func norm(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace && !"·,.()'\"?!~:;[]「」*".contains($0) }
    }

    static func split(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: "\n"))
            .flatMap { $0.components(separatedBy: ". ") }
            .flatMap { $0.components(separatedBy: "요. ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 6 }
    }

    static func numbers(in text: String) -> Set<String> {
        Set(text.matches(of: #/\d+(?:\.\d+)?/#).map { String($0.output) })
    }

    /// 조사를 뗀 핵심 낱말들 (두 글자 이상)
    static func contentWords(_ text: String) -> [String] {
        let particles = ["에서는", "으로는", "이라고", "에서", "으로", "에게", "까지", "부터", "이며", "이고", "이다", "예요", "이에요", "해요", "돼요",
                         "은", "는", "이", "가", "을", "를", "의", "에", "와", "과", "도", "로", "만", "요"]
        let stop: Set<String> = ["있어요", "있다", "때문", "경우", "하는", "있는", "되는", "한다", "된다", "그리고", "또는", "이런", "어떤", "다음", "같은", "모든", "때는"]
        return text.split(whereSeparator: { $0.isWhitespace || ",.()·:;\"'".contains($0) }).compactMap { piece -> String? in
            var w = String(piece)
            for p in particles where w.count > p.count + 1 && w.hasSuffix(p) { w.removeLast(p.count); break }
            return w.count >= 2 && !stop.contains(w) ? w : nil
        }
    }

    /// 수학 답이 같은지 (공백·기호·"x =" 차이 무시, 수는 값으로 비교)
    static func sameAnswer(_ a: String, _ b: String) -> Bool {
        func clean(_ s: String) -> String {
            s.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "x=", with: "").replacingOccurrences(of: "답:", with: "").lowercased()
        }
        let x = clean(a), y = clean(b)
        if x == y { return true }
        if let p = Double(x), let q = Double(y) { return abs(p - q) < 1e-6 }
        // "x = 2 또는 x = 3" 과 "2, 3"
        let nx = numbers(in: x), ny = numbers(in: y)
        return !nx.isEmpty && nx == ny && x.filter({ $0 == "-" }).count == y.filter({ $0 == "-" }).count
    }
}
