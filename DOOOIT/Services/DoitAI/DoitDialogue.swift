import Foundation

/// 모티 AI 대화 흐름 (외부 AI 없이)
/// 앞에서 무슨 이야기를 했는지(주제·과목·푼 문제·함수·단위·일정·단어) 짧게 기억해서
/// "그럼 3이면?", "왜?", "다시 설명해줘", "더 쉽게", "그거 단계별로", "다른 예시", "그 다음은?",
/// "그거/이거/그 문제/거기서", "x=3일 때는?", "그럼 독일은?" 같은 이어지는 말을 앞 내용으로 풀어요.
/// 앞 내용이 없어서 알 수 없으면 짐작하지 않고 짧게 되물어요.
enum DoitDialogue {
    /// 어떤 답이었는지
    enum Kind: String {
        /// 수학 풀이
        case math
        /// 숫자가 들어간 과목 계산 (전류, 할인 등)
        case calc
        /// 지식 사전의 개념 설명
        case knowledge
        /// 과목 엔진의 설명 (영어 문법, 역사 등)
        case subject
        /// 모델(DOOOIT 1·2)이 쓴 답
        case model
        /// 일정 추가·체크
        case plan
        /// 영어 단어 뜻
        case word
        /// 일상 대화·도구 답
        case chat
        /// 그 밖의 앱 명령
        case command
        case quiz

        /// 이어 말하기의 기준이 되는 답인지 (인사·퀴즈 답은 앞 주제를 그대로 둠)
        var isSubstantive: Bool { ![.chat, .quiz].contains(self) }
        /// "왜?", "다시 설명해줘", "예시" 같은 설명 이어 말하기를 할 수 있는 답인지
        var isExplainable: Bool { [.knowledge, .subject, .model, .word, .calc].contains(self) }
        /// 주제(개념 이름)가 있는 답인지
        var hasTopic: Bool { [.math, .calc, .knowledge, .subject, .model, .word].contains(self) }
    }

    /// 대화 상태 (최근 주제 중심, 몇 개만)
    struct State: Equatable {
        /// 지금 이야기 중인 주제 ("광합성", "이차방정식")
        var topic: String?
        /// 과목 ("수학", "과학", "영어", …)
        var subject: String?
        /// 마지막으로 의미 있던 답의 종류 (이어 말하기 기준)
        var focus: Kind?
        /// 바로 전 답의 종류
        var last: Kind?
        /// 마지막 의미 있던 질문 (이어 말하기를 풀어 쓴 뒤의 질문)
        var question: String?
        /// 마지막 의미 있던 답
        var answer: String?
        /// 마지막으로 푼 수학 문제
        var mathProblem: String?
        /// 마지막 함수 ("f(x)=x^2+3x")
        var function: String?
        /// 마지막 질문에 나온 단위 ("V", "%", "cm")
        var unit: String?
        /// 날짜·일정·단어 같은 값 ("date", "plan", "word")
        var entities: [String: String] = [:]
        /// 바로 전 답을 모델이 썼는지
        var fromModel = false
        var turns = 0

        var hasContext: Bool { focus != nil || topic != nil }
    }

    /// 이어지는 말의 종류
    enum FollowUp: Equatable {
        /// "그럼 3이면?", "저항이 6이면?", "30%면?"
        case substitute(value: String, name: String?, unit: String?)
        /// "x=3일 때는?", "x가 2면?"
        case variable(name: String, value: String)
        case why, again, simpler, steps, example, next, more
        /// "그럼 독일은?" (앞 질문에서 대상만 바꿈)
        case ellipsis(String)
        /// "그거", "이거", "그 문제", "거기서"
        case pronoun
    }

    enum Resolution: Equatable {
        /// 이어지는 말이 아님
        case none
        /// 앞 내용을 넣어 다시 쓴 질문 (엔진이 이어서 답함)
        case rewrite(String)
        /// 앞 내용으로 바로 만든 답
        case answer(String, [String])
        /// 짐작하지 않고 되묻기
        case clarify(String, [String])
    }

    // MARK: - 이어지는 말 알아보기

    static let connectives = ["그렇다면", "그러면", "그럼", "만약에", "만약", "아그럼", "근데", "그런데"]
    static let pronouns = ["그거", "그것", "이거", "이것", "그건", "이건", "그게", "이게", "그걸", "이걸", "그 문제", "이 문제", "그문제", "이문제",
                           "그 식", "이 식", "거기서", "여기서", "그 개념", "그 단원", "그 단어", "그 일정", "저거", "그때"]

    static func classify(_ raw: String) -> FollowUp? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 40 else { return nil }
        let squashed = text.replacingOccurrences(of: " ", with: "").lowercased()
        let core = squashed.trimmingCharacters(in: CharacterSet(charactersIn: "?？!.~ㅠㅜ"))
        guard !core.isEmpty else { return nil }

        // x=3일 때는? / x가 2면?
        if let m = text.firstMatch(of: #/^(?:그럼|그러면|그렇다면|만약)?\s*([a-zA-Z])\s*(?:=|가|이|에|를|을)\s*(-?\d+(?:\.\d+)?(?:/\d+)?)\s*(?:일\s*때(?:는|의\s*값은|값은|는요)?|이면|라면|이라면|면|에서는|에서|을\s*넣으면|를\s*넣으면|넣으면|대입하면|이면요|면요)?\s*[?？.!]*$/#) {
            return .variable(name: String(m.1).lowercased(), value: String(m.2))
        }
        // 그럼 3이면? / 저항이 6이면? / 30%면?
        if let m = text.firstMatch(of: #/^(?:그럼|그러면|그렇다면|만약)?\s*(?:([가-힣A-Za-z]{1,8}?)\s*(?:이|가|을|를|은|는)?\s+|([가-힣]{1,8}?)(?:이|가))?(-?\d+(?:\.\d+)?)\s*(%|퍼센트|원|개월|개|명|cm|mm|m|km|kg|g|분|초|시간|도|°|일|주|달|년|살|번|층|쪽|배|[A-Za-zΩ]{1,3})?\s*(?:이면|면|이라면|라면|일\s*때는?|일때는?|으로\s*하면|로\s*하면|로\s*바꾸면|으로\s*바꾸면|이면요|면요|이면\s*몇|면\s*몇)\s*[?？.!]*$/#) {
            var name = (m.1 ?? m.2).map(String.init)
            if let n = name, connectives.contains(n) { name = nil }
            if let n = name, n.count == 1, n.first?.isASCII == true, n.first?.isLetter == true {
                return .variable(name: n.lowercased(), value: String(m.3))
            }
            return .substitute(value: String(m.3), name: name, unit: m.4.map(String.init))
        }
        let rest = strippedConnective(core)
        if [core, rest].contains(where: { ["왜", "왜요", "왜그래", "왜그래요", "왜그런데", "왜그런거야", "왜그런거예요", "왜그렇지", "왜그렇게돼", "왜그렇게되는데", "왜그렇게나와",
            "어째서", "어째서요", "이유는", "이유가뭐야", "이유는뭐야", "왜그런지", "왜그렇게", "그건왜", "그게왜", "왜그런가요"].contains($0) }) {
            return .why
        }
        // "왜 중요해?", "그럼 왜 그래?" 처럼 '왜'로 시작하는 짧은 말 (주제 없이)
        if rest.hasPrefix("왜") && rest.count <= 7 {
            return .why
        }
        if has(core, ["단계별", "풀이과정", "과정보여", "과정알려", "어떻게풀었", "어떻게나왔", "어떻게구했", "어떻게구해", "풀이보여", "자세한풀이", "차근차근", "한단계씩"]),
           core.count <= 20 {
            return .steps
        }
        if has(core, ["더쉽게", "쉽게설명", "쉽게말해", "쉽게알려", "쉽게다시", "간단히", "간단하게", "짧게", "한줄로", "요약해"]), core.count <= 16 {
            return .simpler
        }
        if has(core, ["다시설명", "다시알려", "다시말해", "한번더설명", "이해가안", "이해못", "무슨말이야", "무슨말인지", "다시한번", "잘모르겠어", "못알아듣"]) && core.count <= 18
            || ["다시", "다시요", "다시해줘"].contains(core) {
            return .again
        }
        if has(core, ["다른예시", "다른예", "예시", "예를들어", "예를들면", "예제", "예시들어", "예문"]), core.count <= 14,
           !has(core, ["뭐야", "란", "이란", "뜻", "무엇"]) {
            return .example
        }
        if ["그다음은", "그다음", "다음은", "그다음엔", "그다음에는", "다음단계는", "다음단계", "그리고", "그리고는", "또있어", "또뭐있어", "그래서", "그래서요",
            "그다음은뭐야", "다음은뭐야", "그다음엔뭐해", "다음은"].contains(rest) {
            return .next
        }
        if (has(core, ["더자세히", "자세히알려", "자세히설명", "더알려", "더설명"]) && core.count <= 14 && !core.contains("하나더"))
            || ["더", "계속", "계속해", "계속해줘"].contains(core) {
            return .more
        }
        // 그럼 독일은? / 독일은?
        // ("근데 배고파"처럼 '근데'로 시작하는 새 말은 아님: '그럼·그러면'일 때만, 조사가 없으면 짧은 이름만)
        let strong = ["그렇다면", "그러면", "그럼", "만약에", "만약", "아그럼"].contains { core.hasPrefix($0) } && rest != core
        if let m = rest.firstMatch(of: #/^([가-힣A-Za-z][가-힣A-Za-z0-9]{0,11}?)(은|는|이면|면|이라면|라면|의경우는|의경우|도)?$/#),
           (strong && (m.2 != nil || m.1.count <= 6)) || (m.2 != nil && (squashed.hasSuffix("?") || squashed.hasSuffix("？"))) {
            let target = String(m.1)
            let endings = m.2 == nil ? ["해", "줘", "요", "까", "게", "네", "래", "자", "지", "어", "아", "다", "야", "니", "냐"] : ["해", "줘", "요", "까"]
            let verbish = endings.contains { target.hasSuffix($0) }
            let asking = ["뭐", "어떻게", "언제", "어디", "누구", "진짜", "정말", "그래", "알겠", "고마워", "괜찮"].contains { target.hasPrefix($0) }
            // ("그럼 원은?"처럼 조사가 붙은 한 글자 이름도, "그럼 제3법칙은?"처럼 숫자가 든 이름도 — 숫자만 바꾸는 말은 위에서 처리)
            let letters = target.filter { $0.isLetter }.count
            let named = target.count >= 2 ? (!target.contains(where: \.isNumber) || letters >= 2) : (strong && m.2 != nil && letters == 1)
            if named, !pronouns.contains(target), !verbish, !asking {
                return .ellipsis(target)
            }
        }
        if containsPronoun(text), text.count <= 30, !has(squashed, ["퀴즈", "문제내", "문제줘", "문제만들"]) {
            return .pronoun
        }
        return nil
    }

    /// 앞 대화를 이어 가는 말인지 (모델이 쓴 대화를 이어 갈 때 규칙형 엔진이 가로채지 않게)
    static func continuesConversation(_ raw: String) -> Bool {
        if classify(raw) != nil { return true }
        let core = raw.replacingOccurrences(of: " ", with: "")
        if strippedConnective(core) != core { return true }
        return raw.count <= 14 && containsPronoun(raw)
    }

    /// 앱 기능 명령이나 식이 분명한 수학 문제 (어떤 대화 중이어도 엔진이 처리)
    static func isCommand(_ raw: String) -> Bool {
        let t = raw.lowercased()
        let commands = ["추가", "일정", "타이머", "메모", "삭제", "지워", "알림", "디데이", "d-day", "퀴즈", "통계", "열어", "목표", "완료", "플랜", "기억해", "스톱워치"]
        if commands.contains(where: { t.contains($0) }) { return true }
        let expression = DoitAlgebra.extract(raw, extra: "<>≤≥")
        let operators = expression.filter { "+-*/^=×÷−²³√<>≤≥".contains($0) }.count
        return operators >= 1 && expression.contains(where: \.isNumber) && expression.count >= 3
    }

    // MARK: - 이어지는 말 풀기

    static func resolve(_ raw: String, state current: State) -> Resolution {
        // 타이머를 켠 뒤 "멈춰", "그만", "꺼줘" → 타이머에게
        let compact = raw.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "?!.~"))
        if current.last == .command, current.question?.contains("타이머") == true,
           ["멈춰", "멈춰줘", "그만", "그만해", "꺼", "꺼줘", "종료", "종료해줘", "끝", "끝내", "끝내줘", "정지", "일시정지", "잠깐", "잠깐만", "중지", "다시시작", "재개"].contains(compact) {
            return .rewrite("타이머 " + compact)
        }
        // 앞 주제와 비교하는 말 ("광합성이랑 차이는?", "그럼 공리주의랑 다른 점은?") → "세포 호흡과 광합성의 차이"
        if let topic = current.topic, current.focus?.isExplainable == true,
           let m = compact.firstMatch(of: #/^(?:그럼|그러면|근데)?([가-힣A-Za-z0-9]{1,12}?)(?:이랑|랑|와|과|하고|이랑은|랑은|과는|와는)(?:의)?(?:차이|차이점|다른점|비교|공통점)(?:은|는|이|가)?(?:뭐야|뭐지|알려줘|뭔데|있어)?$/#) {
            let other = String(m.1)
            if other != topic, !pronouns.contains(other) {
                let joined = DoitRelevance.particleFits("과", after: topic.last ?? "가") ? "과" : "와"
                return .rewrite("\(topic)\(joined) \(other)의 차이")
            }
        }
        guard let follow = classify(raw) else { return .none }
        var state = current
        // "광합성 다른 예시"처럼 주제를 직접 말했으면 그 주제로 (앞 주제와 다르면 지식 사전에서 찾아서, 없으면 엔진에 맡김)
        let explanatory: [FollowUp] = [.why, .again, .simpler, .steps, .example, .next, .more]
        if explanatory.contains(follow), let own = ownTopic(raw),
           state.topic.map({ DoitStudyCheck.norm($0) != DoitStudyCheck.norm(own) }) ?? true {
            guard let entry = DoitKnowledge.entry(named: own)
                    ?? DoitKnowledge.search(own, limit: 1).first.flatMap({ $0.score >= 0.6 ? $0.entry : nil }) else { return .none }
            state = State(topic: entry.title, focus: .knowledge, last: .knowledge, question: own,
                          answer: "**\(entry.title)** (\(entry.label))\n\(entry.body)")
        }
        // 앞 내용이 없을 때 "더 알려줘", "그 다음은?", "이 문제 풀어줘"는 원래 답(재밌는 사실 하나 더, 풀 문제 보내 달라는 말)에 맡김
        if !state.hasContext, [.more, .next, .pronoun].contains(follow) { return .none }
        // 앞 내용이 없는 "일본 수도는?", "삼각형 내각의 합은?"은 이어 말하기가 아니라 새 질문
        if case .ellipsis = follow, state.question == nil || state.focus == nil { return .none }
        // "왜 공부해야 돼?"처럼 앞 내용 없이 '왜'로 시작하는 말은 새 질문 ("왜?"만 보낸 말은 되물음)
        if follow == .why, !state.hasContext, strippedConnective(compact) != "왜", compact.count > 3 { return .none }
        let focus = state.focus
        let topic = state.topic
        switch follow {
        case .variable(let name, let value):
            if let fn = state.function, focus == .math || focus == .calc || state.mathProblem != nil {
                return .rewrite(functionCall(fn, name: name, value: value))
            }
            if let problem = state.mathProblem, let checked = checkSubstitution(problem, name: name, value: value) {
                return .answer(checked, ["비슷한 문제 내줘"])
            }
            return .clarify("어떤 식에 \(name) = \(value)을(를) 넣을까요? 식을 같이 적어 주세요.", [])

        case .substitute(let value, let name, let unit):
            if focus == .math, name == nil, unit == nil, let fn = state.function {
                return .rewrite(functionCall(fn, name: "x", value: value))
            }
            if focus == .math, name == nil, unit == nil, let problem = state.mathProblem, problem.contains("=") {
                var chips = ["x=\(value)이면?"]
                if let replaced = replaceNumbers(in: problem, value: value, name: nil, unit: nil).last { chips.append(replaced) }
                return .clarify("x = \(value)일 때를 볼까요, 아니면 식의 숫자를 \(value)(으)로 바꿀까요?", chips)
            }
            if focus == .math || focus == .calc || focus == .command, let question = focus == .math ? state.mathProblem : state.question {
                let candidates = replaceNumbers(in: question, value: value, name: name, unit: unit)
                if candidates.count == 1 { return .rewrite(candidates[0]) }
                if candidates.count > 1 { return .clarify("어떤 값을 \(value)(으)로 바꿀까요?", Array(candidates.prefix(3))) }
            }
            return .clarify("무엇을 \(value)(으)로 바꿀지 문제와 같이 알려줄래요?", [])

        case .why:
            if focus == .math, let solved = state.mathProblem.flatMap(MathSolver.solve) {
                return .answer(reason(for: solved), ["단계별로 보여줘", "비슷한 문제 내줘"])
            }
            if let topic, let answer = state.answer, focus?.isExplainable == true, focus != .word {
                if let reason = reasonText(answer: answer) { return .answer(reason, ["다시 설명해줘", "이걸로 퀴즈 내줘"]) }
                return .clarify("'\(topic)'에서 어떤 점이 왜 궁금해요? 예: \"\(topic)은(는) 왜 중요해?\"", ["\(topic) 더 자세히 알려줘"])
            }
            return .clarify("어떤 게 왜 궁금한지 알려줄래요?", [])

        case .steps, .again:
            if focus == .math, let solved = state.mathProblem.flatMap(MathSolver.solve) {
                return .answer(stepsText(solved), ["왜?", "비슷한 문제 내줘"])
            }
            if focus == .calc, let question = state.question {
                return .rewrite(question)
            }
            if let topic, let answer = state.answer, focus?.isExplainable == true {
                return .answer(bulletText(topic: topic, answer: answer), ["더 쉽게", "이걸로 퀴즈 내줘"])
            }
            return .clarify(follow == .steps ? "어떤 걸 단계별로 볼까요? 문제를 같이 적어 주세요." : "어떤 걸 다시 설명할까요?", [])

        case .simpler:
            if focus == .math, let solved = state.mathProblem.flatMap(MathSolver.solve) {
                let concept = solved.concept.isEmpty ? "" : solved.concept + "\n"
                return .answer(concept + "그래서 답은 **\(solved.answer)**예요.", ["단계별로 보여줘"])
            }
            if let topic, let answer = state.answer, focus?.isExplainable == true {
                return .answer(simpleText(topic: topic, answer: answer), ["더 자세히 알려줘", "이걸로 퀴즈 내줘"])
            }
            return .clarify("어떤 걸 쉽게 설명할까요?", [])

        case .example, .next:
            if focus == .math, state.mathProblem != nil {
                return .rewrite("비슷한 문제 내줘")
            }
            if follow == .example, focus == .word, let word = state.entities["word"] {
                return .rewrite("\(word) 영어 뜻 자세히")
            }
            if let topic, focus?.isExplainable == true {
                if follow == .example {
                    if let example = example(for: topic, answer: state.answer) { return .answer(example, ["이걸로 퀴즈 내줘"]) }
                    return .answer("'\(topic)'의 다른 예시는 아직 준비된 게 없어요.", ["\(topic) 더 자세히 알려줘", "이걸로 퀴즈 내줘"])
                }
                if let next = DoitKnowledge.related(to: topic, limit: 2).first {
                    let line = next.body.components(separatedBy: "\n").first ?? ""
                    return .answer("다음으로 **\(next.title)**을(를) 알아 두면 좋아요.\n\(DoitMemory.trimmed(line, max: 140))", ["\(next.title) 설명해줘", "이걸로 퀴즈 내줘"])
                }
                return .answer("'\(topic)' 다음엔 퀴즈로 확인해 볼까요?", ["이걸로 퀴즈 내줘"])
            }
            return .clarify(follow == .example ? "어떤 것의 예시가 필요해요?" : "어떤 것의 다음이 궁금해요?", [])

        case .more:
            if focus == .math, let solved = state.mathProblem.flatMap(MathSolver.solve) {
                return .answer(stepsText(solved), ["왜?", "비슷한 문제 내줘"])
            }
            if let topic, focus?.isExplainable == true {
                return .answer(DoitTutor.more(about: topic, previous: state.answer ?? ""), ["이걸로 퀴즈 내줘", "메모로 저장해줘"])
            }
            return .clarify("어떤 걸 더 자세히 알려줄까요?", [])

        case .ellipsis(let target):
            if let question = state.question, focus != nil, focus != .plan,
               let anchor = anchor(in: question, target: target, state: state), anchor != target {
                return .rewrite(question.replacingOccurrences(of: anchor, with: target))
            }
            return .clarify("'\(target)'의 무엇이 궁금해요?", ["\(target) 설명해줘"])

        case .pronoun:
            let compact = raw.replacingOccurrences(of: " ", with: "")
            if focus == .math, let problem = state.mathProblem {
                if has(compact, ["풀어", "답", "풀이", "다시"]) { return .rewrite(problem) }
                if let fn = state.function, let m = raw.firstMatch(of: #/([a-zA-Z])\s*=\s*(-?\d+(?:\.\d+)?)/#) {
                    return .rewrite(functionCall(fn, name: String(m.1), value: String(m.2)))
                }
            }
            if focus == .word, let word = state.entities["word"], has(compact, ["예문", "예시", "자세히", "발음"]) {
                return .rewrite("\(word) 영어 뜻 자세히")
            }
            let entity: String?
            switch focus {
            case .plan: entity = state.entities["plan"]
            case .word: entity = state.entities["word"] ?? topic
            case .math: entity = state.mathProblem
            case nil: entity = nil
            default: entity = topic
            }
            guard let entity, !entity.isEmpty else { return .clarify("'그거'가 무엇인지 알려줄래요?", []) }
            let replaced = replacePronoun(in: raw, with: entity)
            return replaced == raw ? .none : .rewrite(replaced)
        }
    }

    // MARK: - 상태 바꾸기

    /// 답을 하나 할 때마다 상태를 새로 고침 (도구·인사 답은 주제를 지우지 않음)
    static func update(_ state: inout State, question: String, reply: String, kind: Kind, topic: String? = nil, fromModel: Bool = false) {
        state.turns += 1
        state.last = kind
        state.fromModel = fromModel
        // 함수만 적어 둔 말 ("y=2x+1")도 다음 "x=3일 때는?"에 쓰게
        if kind != .math, let fn = function(in: question) {
            state.function = fn
            state.mathProblem = question
            state.focus = .math
            state.subject = "수학"
        }
        guard kind.isSubstantive else { return }
        state.focus = kind
        state.question = question
        state.answer = reply
        if kind.hasTopic, let topic = topic ?? self.topic(fromReply: reply), !topic.isEmpty { state.topic = topic }
        if let subject = subject(of: question + "\n" + reply) { state.subject = subject }
        if let unit = units(in: question).last { state.unit = unit }
        switch kind {
        case .math:
            state.mathProblem = question
            state.subject = "수학"
            if let fn = function(in: question) { state.function = fn } else if !question.contains("f(") { state.function = nil }
        case .calc:
            state.mathProblem = nil
        case .word:
            if let word = question.firstMatch(of: #/[A-Za-z][A-Za-z\- ']{0,30}[A-Za-z]|[A-Za-z]/#) {
                state.entities["word"] = String(word.0).trimmingCharacters(in: .whitespaces)
                state.topic = state.entities["word"]
            }
        default:
            break
        }
    }

    // MARK: - 다른 주제로 샌 답 막기

    /// 질문의 핵심 낱말이 답에 하나도 없으면 다른 주제로 샌 답 (예: "광합성 다른 예시" → 국어 '예시' 개념)
    static func isOffTopic(question: String, reply: String) -> Bool {
        let words = keywords(question)
        guard !words.isEmpty else { return false }
        // 답 제목 개념의 다른 이름도 봄 ("뉴턴 제2법칙" → '가속도 법칙', "논설문" → '주장하는 글')
        let body = DoitRelevance.expanded(reply)
        if words.contains(where: { body.contains($0) }) { return false }
        // 글자 두 개 묶음이 꽤 겹치면 같은 이야기 ("물건값" ↔ "물가")
        let qGrams = Set(words.flatMap { word -> [String] in
            let chars = Array(word)
            return chars.count < 2 ? [word] : (0..<(chars.count - 1)).map { String(chars[$0...$0 + 1]) }
        })
        guard !qGrams.isEmpty else { return false }
        let shared = qGrams.filter { body.contains($0) }.count
        return Double(shared) / Double(qGrams.count) < 0.34
    }

    /// 질문의 핵심 낱말 (조사·물음말·부탁말은 뺌)
    static func keywords(_ raw: String) -> [String] {
        let stop: Set<String> = ["뭐", "뭐야", "뭐지", "무엇", "무엇인가요", "어떻게", "왜", "언제", "어디", "누구", "알려", "알려줘", "설명", "설명해", "설명해줘",
                                 "해줘", "좀", "진짜", "정말", "그럼", "그러면", "그래서", "그래도", "아까", "저번에", "말고", "누가", "누구야", "이거", "그거", "이건", "그건", "오늘", "내", "나", "너", "저", "제", "있어", "없어",
                                 "하는", "되는", "이유", "원리", "뜻", "의미", "방법", "대해", "대해서", "관해", "관련", "말해", "말해줘", "궁금해", "궁금", "가르쳐",
                                 "가르쳐줘", "줘", "주세요", "해", "할", "수", "것", "거", "게", "더", "다시", "쉽게", "자세히", "간단히", "그리고", "근데", "혹시",
                                 "뭔가요", "뭔데", "인가요", "이야", "예요", "이에요", "있나요", "어때", "어떤", "무슨", "얼마", "몇", "개념", "일어나", "일어났어",
                                 "다른", "들어줘", "보여줘", "줄래", "해줄래", "그럼요", "그러면", "그렇다면", "들면", "들어", "들어서", "보면", "해봐", "알려줄래", "주라", "볼래",
                                 // 무엇을 알고 싶은지 나타내는 말 (주제가 아님): "광합성 예시" → 광합성
                                 "예시", "예문", "예제", "특징", "종류", "장점", "단점", "차이점", "차이", "정의", "구하는", "방법", "하는법", "구하는법", "뭐임", "머임", "머야",
                                 "the", "a", "an", "is", "are", "what", "how", "why", "to", "of", "in", "do", "does"]
        let endings = ["이란게", "이란", "란게", "에대해서", "에대해", "에관해", "이라는게", "라는게", "이라는", "라는", "에서는", "에서", "으로는", "으로", "까지는",
                       "까지", "부터", "에게", "한테", "이랑", "랑", "하고", "이에요", "예요", "이야", "인가", "이다", "은", "는", "이", "가", "을", "를", "의",
                       "에", "로", "와", "과", "도", "만", "야", "란"]
        // 무엇으로 답할지 나타내는 말 (주제가 아님): "책 영어로" → 책
        let asking: Set<String> = ["영어로", "한국어로", "우리말로", "영단어로", "영어로는", "한글로", "숫자로", "그림으로", "표로"]
        var result: [String] = []
        // 영어와 한글이 붙어 있으면 나눔 ("a와" → "a" + "와", "to부정사"는 그대로)
        let spaced = raw.lowercased().replacingOccurrences(of: #"([a-z]{1,3})([가-힣])"#, with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: #"\bto ([가-힣])"#, with: "to$1", options: .regularExpression)
        let tokens = spaced.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        for token in tokens {
            var word = token
            if stop.contains(word) || asking.contains(word) { continue }
            let hangul = word.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
            if hangul {
                // 받침에 맞는 조사만 뗌 ("수행평가"의 '가'는 그대로)
                for ending in endings where word.count > ending.count + 1 && word.hasSuffix(ending) {
                    guard let last = word.dropLast(ending.count).last, DoitRelevance.particleFits(ending, after: last) else { continue }
                    word.removeLast(ending.count)
                    break
                }
                // "오르는" → "오르", "유지하려는" → "유지"
                for verb in ["하려는", "하는", "되는", "하려", "해서", "했어", "할까", "인지", "는"] where word.count > verb.count + 1 && word.hasSuffix(verb) {
                    word.removeLast(verb.count)
                    break
                }
            }
            guard word.count >= 2, !stop.contains(word), !word.allSatisfy(\.isNumber) else { continue }
            if !result.contains(word) { result.append(word) }
        }
        return result
    }

    // MARK: - 도우미

    /// 이어 말하기 속에서 직접 말한 주제 ("광합성 다른 예시" → 광합성)
    static func ownTopic(_ raw: String) -> String? {
        let triggers = ["예시", "예제", "예를", "쉽게", "간단", "짧게", "요약", "다시", "설명", "단계", "과정", "풀이", "자세히", "다음", "이유", "어째서",
                        "계속", "다른", "이해", "무슨말", "한줄", "차근", "어떻게"]
        return keywords(raw).first { word in !triggers.contains { word.contains($0) } && !pronouns.contains(word) }
    }

    static func has(_ text: String, _ words: [String]) -> Bool { words.contains { text.contains($0) } }

    static func containsPronoun(_ text: String) -> Bool {
        let spaced = " " + text + " "
        return pronouns.contains { p in
            guard let range = spaced.range(of: p) else { return false }
            // "그거" 앞이 글자면 다른 낱말의 일부 ("이것저것"은 괜찮지만 "고이거"는 아님)
            let before = spaced[spaced.index(before: range.lowerBound)]
            return before == " " || !before.isLetter
        }
    }

    static func strippedConnective(_ compact: String) -> String {
        for c in connectives where compact.hasPrefix(c) && compact.count > c.count { return String(compact.dropFirst(c.count)) }
        return compact
    }

    static func replacePronoun(in text: String, with entity: String) -> String {
        var result = text
        for p in pronouns.sorted(by: { $0.count > $1.count }) where result.contains(p) {
            // "그거 뜻" → "광합성 뜻", "그걸로" → "광합성으로"는 어색해서 조사 붙은 말은 통째로
            result = result.replacingOccurrences(of: p, with: entity)
            break
        }
        for c in connectives where result.hasPrefix(c + " ") { result = String(result.dropFirst(c.count + 1)) }
        return result
    }

    /// "f(x)=x^2+3x"에 x=3 → 엔진이 아는 말로 ("y=…"는 f(x)로)
    static func functionCall(_ fn: String, name: String, value: String) -> String {
        "\(fn) 에 \(name)=\(value)를 넣어줘"
    }

    /// 문장 속 함수 ("f(x) = x^2+3x", "y=2x+1") → "f(x)=…"
    static func function(in text: String) -> String? {
        guard let m = text.firstMatch(of: #/(?:f\s*\(\s*x\s*\)|\by)\s*=\s*([0-9a-zA-Z\^\+\-−\*/\(\)\.²³√ ]+)/#) else { return nil }
        var body = String(m.1)
        // "x^2+3x x=1에서" → 뒤의 "x=1"은 함수가 아님
        if let cut = body.range(of: #"\s+[a-zA-Z]\s*$"#, options: .regularExpression) { body = String(body[..<cut.lowerBound]) }
        body = body.trimmingCharacters(in: .whitespaces)
        guard body.contains("x"), !body.isEmpty else { return nil }
        return "f(x)=" + body
    }

    /// 방정식에 값을 넣어 보기: "2x+3=11"에 x=3 → 좌변 9, 우변 11
    static func checkSubstitution(_ problem: String, name: String, value: String) -> String? {
        let expression = DoitAlgebra.extract(problem, extra: "")
        let sides = expression.components(separatedBy: "=")
        guard sides.count == 2, name == "x", let v = number(value),
              let left = DoitMath.polynomial(sides[0]), let right = DoitMath.polynomial(sides[1]) else { return nil }
        let l = DoitMath.value(left, at: v), r = DoitMath.value(right, at: v)
        let ls = DoitMath.format(l), rs = DoitMath.format(r)
        if abs(l - r) < 1e-9 {
            return "x = \(value)을(를) 넣으면 좌변 \(ls), 우변 \(rs)로 같아요.\n그래서 **x = \(value)은(는) 해예요.**"
        }
        return "x = \(value)을(를) 넣으면 좌변 \(ls), 우변 \(rs)로 달라요.\n그래서 **x = \(value)은(는) 해가 아니에요.**"
    }

    private static func number(_ s: String) -> Double? {
        if s.contains("/") {
            let parts = s.split(separator: "/").compactMap { Double($0) }
            return parts.count == 2 && parts[1] != 0 ? parts[0] / parts[1] : nil
        }
        return Double(s)
    }

    /// 앞 질문의 숫자를 바꾼 질문들 (이름·단위가 있으면 그 숫자만)
    static func replaceNumbers(in question: String, value: String, name: String?, unit: String?) -> [String] {
        let pattern = #"-?\d+(?:\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = question as NSString
        let matches = regex.matches(in: question, range: NSRange(location: 0, length: ns.length))
        var candidates: [String] = []
        for match in matches {
            let before = ns.substring(to: match.range.location)
            let after = ns.substring(from: match.range.location + match.range.length)
            // 식 안의 숫자(x^2의 2 등)는 빼고, 수 옆에 단위·낱말이 있는 값만
            if let prev = before.last, "^xyabc".contains(prev) { continue }
            if let name {
                let key = name.replacingOccurrences(of: " ", with: "")
                let near = before.replacingOccurrences(of: " ", with: "").suffix(key.count + 2)
                guard near.contains(key) else { continue }
            }
            if let unit {
                let u = unit == "퍼센트" ? "%" : unit
                guard after.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix(u.lowercased()) else { continue }
            }
            candidates.append(before + value + after)
        }
        return candidates
    }

    /// 질문에 나온 단위들
    static func units(in text: String) -> [String] {
        text.matches(of: #/\d\s*(%|cm|mm|km|kg|m|g|V|A|Ω|W|J|N|원|개|명|분|초|시간|°)/#).map { String($0.1) }
    }

    /// 앞 질문에서 바꿀 대상 (주제 → 단어 → 첫 낱말)
    static let dateWords = ["오늘", "내일", "모레", "어제", "그저께", "이번 주", "이번주", "다음 주", "다음주", "지난주", "주말", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일", "일요일"]

    static func anchor(in question: String, target: String, state: State) -> String? {
        // "오늘 할 일 알려줘" → "그럼 내일은?" (날짜는 날짜끼리)
        if dateWords.contains(target) || target.firstMatch(of: #/^\d{1,2}월\d{1,2}일$/#) != nil {
            if let date = dateWords.sorted(by: { $0.count > $1.count }).first(where: { question.contains($0) }) { return date }
            if let m = question.firstMatch(of: #/\d{1,2}\s*월\s*\d{1,2}\s*일/#) { return String(m.0) }
        }
        if let topic = state.topic, question.contains(topic) { return topic }
        if let word = state.entities["word"], question.contains(word) { return word }
        // 바꿀 대상과 가장 비슷한 낱말 ("뉴턴 제2법칙" → "그럼 제3법칙은?"이면 '제2법칙'), 없으면 첫 낱말
        let words = keywords(question)
        guard !words.isEmpty else { return nil }
        let targetGrams = Set(DoitKnowledge.bigrams(target.lowercased()).keys)
        let similar = words.map { w in (w, Set(DoitKnowledge.bigrams(w).keys).intersection(targetGrams).count) }.max { $0.1 < $1.1 }
        let chosen = (similar?.1 ?? 0) > 0 ? similar!.0 : words[0]
        // 낱말이 원래 글자 그대로 들어 있는 부분 (대소문자)
        if let range = question.range(of: chosen, options: .caseInsensitive) { return String(question[range]) }
        return nil
    }

    /// 답 첫 줄의 굵은 글씨 ("**광합성** (과학)", "혹시 **관성**(…)") → 주제
    static func topic(fromReply reply: String) -> String? {
        guard let first = reply.components(separatedBy: "\n").first, let m = first.firstMatch(of: #/\*\*([^*]{1,30})\*\*/#) else { return nil }
        var topic = String(m.1).trimmingCharacters(in: .whitespaces)
        for suffix in [" 자세히", " 더 알아보기"] where topic.hasSuffix(suffix) { topic.removeLast(suffix.count) }
        if topic.hasPrefix("답:") || topic.hasPrefix("퀴즈") { return nil }
        // "임진왜란: 1592~1598년" → "임진왜란"
        if let colon = topic.range(of: ": ") ?? topic.range(of: ":"), colon.lowerBound > topic.startIndex {
            topic = String(topic[..<colon.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return topic
    }

    static func subject(of text: String) -> String? {
        let t = text.lowercased()
        if has(t, ["수학", "방정식", "함수", "인수분해", "미분", "적분", "확률", "넓이", "부피"]) { return "수학" }
        if has(t, ["과학", "광합성", "세포", "전류", "전압", "원소", "화학", "물리", "지구", "에너지"]) { return "과학" }
        if has(t, ["영어", "문법", "과거형", "동사", "english"]) { return "영어" }
        if has(t, ["역사", "사회", "수도", "경제", "정치", "왕", "조선", "고려"]) { return "사회" }
        if has(t, ["국어", "문학", "시", "소설", "맞춤법"]) { return "국어" }
        return nil
    }

    // MARK: - 앞 답으로 만든 답

    static func stepsText(_ solved: MathSolver.Solved) -> String {
        var lines: [String] = []
        for (index, step) in solved.steps.enumerated() {
            let work = step.work.trimmingCharacters(in: .whitespaces)
            lines.append("\(index + 1). \(step.hint)" + (work.isEmpty ? "" : "\n   → \(work)"))
        }
        lines.append("**답: \(solved.answer)**")
        return lines.joined(separator: "\n")
    }

    static func reason(for solved: MathSolver.Solved) -> String {
        var lines: [String] = []
        if !solved.concept.isEmpty { lines.append(solved.concept) }
        let key = solved.steps.suffix(2).map { step -> String in
            let work = step.work.trimmingCharacters(in: .whitespaces)
            return "• " + (work.isEmpty ? step.hint : work)
        }
        lines += key
        lines.append("그래서 답이 **\(solved.answer)**예요.")
        return lines.joined(separator: "\n")
    }

    /// 앞 답의 본문 문장들 (첫 줄 제목·"함께 보면 좋아요"·출처는 뺌)
    static func bodySentences(_ answer: String) -> [String] {
        var lines = answer.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let first = lines.first, first.hasPrefix("**") || first.hasPrefix("혹시") { lines.removeFirst() }
        lines = lines.filter { !$0.hasPrefix("함께 보면") && !$0.hasPrefix("함께 알아두면") && !$0.hasPrefix("출처") && !$0.hasPrefix("비슷한 개념") && !$0.hasPrefix("예:") }
        let text = lines.joined(separator: " ").replacingOccurrences(of: "**", with: "")
        return DoitStudy.sentences(of: text)
    }

    /// 앞 답에서 이유를 말한 문장 (없으면 nil → 무엇이 왜 궁금한지 되물음)
    static func reasonText(answer: String) -> String? {
        let sentences = bodySentences(answer)
        let signals = ["때문", "이유", "그래서", "따라서", "므로", "원리", "덕분", "위해", "해서", "려고"]
        let reasons = sentences.filter { s in signals.contains { s.contains($0) } }
        return reasons.isEmpty ? nil : reasons.prefix(2).joined(separator: " ")
    }

    static func bulletText(topic: String, answer: String) -> String {
        let sentences = bodySentences(answer)
        guard !sentences.isEmpty else { return DoitTutor.more(about: topic, previous: answer) }
        return "**\(topic)**\n" + sentences.prefix(5).map { "• " + $0 }.joined(separator: "\n")
    }

    static func simpleText(topic: String, answer: String) -> String {
        let sentences = bodySentences(answer)
        guard let first = sentences.first else { return "**\(topic)**" }
        return "**\(topic)**\n" + DoitMemory.trimmed(first, max: 120)
    }

    /// 주제의 예시 (앞 답이나 지식 사전의 "예:" 부분)
    static func example(for topic: String, answer: String?) -> String? {
        var pool: [String] = []
        for text in [answer ?? "", DoitKnowledge.entry(named: topic)?.body ?? ""] {
            for part in text.components(separatedBy: "예:").dropFirst() {
                let line = part.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces) ?? ""
                if line.count >= 4, !pool.contains(line) { pool.append(line) }
            }
        }
        guard !pool.isEmpty else { return nil }
        // 앞 답에 이미 보여준 예시는 뒤로
        let fresh = pool.filter { !(answer ?? "").contains($0) }
        return "**\(topic)** 예시\n• " + (fresh.isEmpty ? pool : fresh).prefix(2).joined(separator: "\n• ")
    }
}
