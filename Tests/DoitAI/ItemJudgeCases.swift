import Foundation

// MARK: - 보기 항목을 하나씩 O·X로 따져 고르는 문제 ("어법상 바른 것끼리 묶인 것은?")

func runItemJudgeCases() {
    let text = """
    23번) 다음 중 어법상 바른 것끼리 묶인 것은?
    a) Two dollars is enough for the ticket.
    b) He said that practice makes perfect.
    c) She told that she was tired.
    d) I have lived here since 2010.
    e) If I were you, I would go there.
    ① a, b ② a, c ③ b, c ④ c, e ⑤ d, e
    """
    let choices = ["a, b", "a, c", "b, c", "c, e", "d, e"]
    let setup = DoitItemJudge.setup(text: text, body: nil, choices: choices, boxItems: nil)
    check("항목 판단: 항목 5개 찾기", setup?.items.map(\.label) == ["a", "b", "c", "d", "e"], "\(setup?.items.map(\.label) ?? [])")
    check("항목 판단: 바른 것 고르기", setup?.wantTrue == true && setup?.exact == false)
    check("항목 판단: 선지는 항목 모음", setup?.choiceSets.first == ["a", "b"])

    if let setup {
        let raw = "a) O - 금액은 하나로 봐서 단수\nb) O - 속담·진리는 현재\nc) X - told 뒤에 사람\nd) O - since와 현재완료\ne) O - 가정법 과거"
        let parsed = DoitItemJudge.parseVerdicts(raw, labels: ["a", "b", "c", "d", "e"])
        check("항목 판단: O·X 읽기", parsed?.verdicts == ["a": true, "b": true, "c": false, "d": true, "e": true])
        // 바른 것만 든 선지가 ①(a, b)과 ⑤(d, e) 두 개 → 하나로 안 정해지면 답을 내지 않음
        check("항목 판단: 하나로 안 정해지면 답 없음", parsed.map { DoitItemJudge.pickChoice(setup, verdicts: $0.verdicts) } == .some(nil))
        let raw2 = "a) O\nb) X\nc) X\nd) O\ne) X"
        let p2 = DoitItemJudge.parseVerdicts(raw2, labels: ["a", "b", "c", "d", "e"])
        check("항목 판단: 맞는 것만 든 선지 하나", p2.flatMap { DoitItemJudge.pickChoice(setup, verdicts: $0.verdicts) } == nil, "a, d만 맞으면 선지에 없음")
        let raw3 = "a) X\nb) X\nc) X\nd) O\ne) O"
        let p3 = DoitItemJudge.parseVerdicts(raw3, labels: ["a", "b", "c", "d", "e"])
        check("항목 판단: d, e → ⑤", p3.flatMap { DoitItemJudge.pickChoice(setup, verdicts: $0.verdicts) } == 4)
        check("항목 판단: 하나라도 ?면 버림", DoitItemJudge.parseVerdicts("a) O\nb) ?\nc) X\nd) O\ne) O", labels: ["a", "b", "c", "d", "e"]) == nil)
        check("항목 판단: 빠진 항목 있으면 버림", DoitItemJudge.parseVerdicts("a) O\nb) X", labels: ["a", "b", "c", "d", "e"]) == nil)
        check("항목 판단: 두 번 판단이 다르면 안 씀", !DoitItemJudge.agree(["a": true], ["a": false]))
        let prompt = DoitItemJudge.prompt(setup, subjectName: "영어")
        check("항목 판단: 선지 번호를 쓰지 말라고", prompt.contains("선택지 번호") && prompt.contains("a) Two dollars"))
        // 규칙으로 확실한 항목: c(told that)만 틀림 → 모델에게 고정 판단으로 알려 줌
        // c가 든 선지를 지워도 ①(a, b)와 ⑤(d, e)가 남아서 규칙만으로는 답하지 않음
        let fixed = DoitItemJudge.ruleVerdicts(setup)
        check("항목 판단 규칙: 틀린 항목 c", fixed.mapValues(\.verdict) == ["c": false], "\(fixed.mapValues(\.verdict))")
        let fixedPrompt = DoitItemJudge.prompt(setup, subjectName: "영어", fixed: fixed)
        check("항목 판단 규칙: 프롬프트에 확인한 판단", fixedPrompt.contains("[규칙으로 확인한 판단]") && fixedPrompt.contains("c) X"), fixedPrompt)
        check("항목 판단 규칙: 남은 선지가 둘이면 답 없음", DoitSubjectSolve.eliminate(setup, known: fixed.mapValues(\.verdict)) == nil)
        check("항목 판단 규칙: 규칙만으로 풀지 않음", DoitSubjectSolve.solve(text: text, choices: choices, subjectBroad: "영어") == nil)
        // e를 가정법 + will(틀림)로 바꾸면 c, e가 든 선지를 지우고 ①만 남음 → 확인한 답
        let text2 = text.replacingOccurrences(of: "I would go there", with: "I will go there")
        let solved = DoitSubjectSolve.solve(text: text2, choices: choices, subjectBroad: "영어")
        check("항목 판단 규칙: 확인한 답으로 풂 (①)", solved?.finalAnswer == "1" && solved?.source == DoitAutoSolve.engineSource, solved?.finalAnswer ?? "nil")
    }

    // ㄱ·ㄴ·ㄷ, 틀린 것, 있는 대로
    let box = "다음 중 옳지 않은 것만을 있는 대로 고른 것은?\nㄱ. 물은 100℃에서 끓는다.\nㄴ. 소금은 금속이다.\nㄷ. 공기는 혼합물이다."
    let s2 = DoitItemJudge.setup(text: box, body: nil, choices: ["ㄱ", "ㄴ", "ㄱ, ㄴ", "ㄴ, ㄷ", "ㄱ, ㄴ, ㄷ"], boxItems: nil)
    check("항목 판단: 틀린 것 · 있는 대로", s2?.wantTrue == false && s2?.exact == true && s2?.items.count == 3)
    if let s2 {
        let p = DoitItemJudge.parseVerdicts("ㄱ. O\nㄴ. X\nㄷ. O", labels: ["ㄱ", "ㄴ", "ㄷ"])
        check("항목 판단: 틀린 것 ㄴ → ②", p.flatMap { DoitItemJudge.pickChoice(s2, verdicts: $0.verdicts) } == 1)
    }
    // 규칙으로 일부만 알 때: 지워도 선지가 둘 이상 남으면 규칙만으로는 답하지 않음
    let partial = "다음 중 어법상 바른 것끼리 묶인 것은?\na) I am interested in music.\nb) She is good at tennis.\nc) They was late.\nd) He likes apples.\n① a, b ② a, c ③ b, d ④ c, d ⑤ a, d"
    check("항목 판단 규칙: 일부만 알면 규칙 답 없음", DoitSubjectSolve.solve(text: partial, choices: ["a, b", "a, c", "b, d", "c, d", "a, d"], subjectBroad: "영어") == nil)
    // 한 줄에 선지가 붙어도 항목에 선지가 섞이지 않음
    check("항목 판단: 선지 줄의 (B)는 항목이 아님", DoitItemJudge.extractItems("(A) I am happy.\n(B) She are tall.\n① (A), (B) ② (B) ③ (A)").count == 2)
    // 항목이 아닌 보통 객관식은 해당 없음
    check("항목 판단: 보통 객관식은 아님", DoitItemJudge.setup(text: "다음 중 과거형은?\n① went ② go ③ goes", body: nil, choices: ["went", "go", "goes"], boxItems: nil) == nil)
    check("항목 판단: 한 줄에 붙은 항목", DoitItemJudge.extractItems("a) I am happy. b) She are tall.").count == 2)

    // 단어장 유의어·반의어 표시 (동그라미 글자 · 한 글자 괄호)
    for line in ["ⓢ glad, joyful", "Ⓐ sad", "(동) glad", "[비] similar", "비슷한 뜻: glad", "반대 뜻 sad"] {
        check("단어장 유의어 줄 버림: \(line)", WordParser.isSynonymLine(line))
    }
    check("단어장 유의어 제목 줄", WordParser.isSynonymHeading("비슷한 뜻 · 반대 뜻"))
    check("단어장 뜻 속 유의어 지움", !WordParser.normalizeRow("happy 행복한 ⓢ glad ⓐ sad").contains("glad"), WordParser.normalizeRow("happy 행복한 ⓢ glad ⓐ sad"))
    check("단어장 보통 줄은 그대로", !WordParser.isSynonymLine("happy 행복한") && !WordParser.isSynonymLine("run 동 달리다"))

    // 시중 단어장(풀어서 외우는 영단어 같은 쪽): 파생어 +, 예시 구 •, 영영풀이, 복수형, 동사 변화형은 단어가 아님
    for line in ["+ ultimate 형 최종의, 궁극적인 / 유 in the end", "+ impression 명 인상 / 유 remarkable", "• a compact camera 소형 카메라",
                 "영영풀이 small but complete", "복 phenomena", "oversaw-overseen", "· go through a crisis 위기를 겪다"] {
        check("단어장 덧붙인 줄 버림: \(line.prefix(18))", WordParser.isExtraLine(line))
    }
    for line in ["ultimately 부 결국, 궁극적으로", "· apple 사과", "- apple 사과", "well-known 형 잘 알려진", "look after 돌보다"] {
        check("단어장 보통 줄은 그대로: \(line)", !WordParser.isExtraLine(line))
    }
    let cleaned = WordParser.cleanEntries([
        ParsedWord(term: "oversee", meaning: "감독하다"), ParsedWord(term: "oversaw-overseen", meaning: "감독하다"),
        ParsedWord(term: "phenomena", meaning: "영풀이"), ParsedWord(term: "brief d", meaning: "짧은, 간단한"),
        ParsedWord(term: "compact", meaning: "간결한, 소형의"), ParsedWord(term: "a compact camera", meaning: "소형 카메라"), ParsedWord(term: "crisis", meaning: "위기"),
        ParsedWord(term: "go through a crisis", meaning: "위기를 겪다"), ParsedWord(term: "look after", meaning: "돌보다"),
    ])
    check("단어장 정리: 표제어만", cleaned.map(\.term) == ["oversee", "brief", "compact", "crisis", "look after"], "\(cleaned.map(\.term))")

    // 번호 붙은 표제어만 (보내 준 단어장: 541 ultimately … 550 impressive)
    let rows = ["541 ultimately [ʌ́ltimətli] 부 결국, 궁극적으로", "ultimate 형 최종의, 궁극적인 / in the end", "542 compact [kəmpǽkt] 형 간결한, 소형의",
                "a compact camera 소형 카메라", "543 oversee [òuvərsíː] 동 감독하다", "oversaw-overseen", "544 phenomenon [fənɑ́ːminən] 명 현상",
                "546 brief d [briːf] 형 (시간이) 짧은", "in brief 간단히 말해서, 요약하면", "550 impressive 형 인상적인, 감명 깊은", "impression 명 인상"]
    let heads = WordParser.numberedHeads(rows)
    check("단어장 번호 표제어 찾기", heads.isSuperset(of: ["ultimately", "compact", "oversee", "phenomenon", "impressive"]), "\(heads.sorted())")
    let parsedWords = [("Ultimately", "결국, 궁극적으로"), ("ultimate", "최종의, 궁극적인"), ("compact", "간결한, 소형의"), ("a compact camera", "소형 카메라"),
                       ("oversee", "감독하다"), ("phenomenon", "현상"), ("phenomena", "복"), ("brief", "짧은, 간단한"), ("in brief", "간단히 말해서"),
                       ("impressive", "인상적인, 감명 깊은"), ("impression", "인상")].map { ParsedWord(term: $0.0, meaning: $0.1) }
    let kept = WordParser.keepNumberedHeads(WordParser.cleanEntries(parsedWords), heads: heads)
    check("단어장 번호 표제어만 남김", kept.map { $0.term.lowercased() } == ["ultimately", "compact", "oversee", "phenomenon", "brief", "impressive"], "\(kept.map(\.term))")
    // 번호가 드문 목록은 그대로
    let few = WordParser.keepNumberedHeads([ParsedWord(term: "apple", meaning: "사과"), ParsedWord(term: "pear", meaning: "배"), ParsedWord(term: "plum", meaning: "자두")],
                                           heads: ["apple", "kiwi", "fig"])
    check("단어장 번호가 드문 목록은 그대로", few.count == 3)

    // 시험에 자주 나오는 예외 (보내 준 문제: 정답 ⑤)
    let wrongs = ["I heard that Pompeii had been discovered in 1748.", "Six kilometers are too long for me to walk.",
                  "The young is called the hope of the future.", "We were taught that Venus was the hottest planet in the solar system.",
                  "The number of students are increasing.", "A number of people was waiting outside.", "Ten dollars are enough for lunch."]
    for s in wrongs { check("문장 검사 틀림 찾기: \(s.prefix(28))", DoitSentenceCheck.error(in: s) != nil, s) }
    let rights = ["A number of trucks are parked on the street.", "The number of cars is growing.", "The young are the hope of the future.",
                  "Six kilometers is too long for me to walk.", "I heard that Pompeii was discovered in 1748.", "We learned that the earth moves around the sun.",
                  "By 1990, they had built the bridge.", "He said that he had lost his key.", "The young man is my brother.", "Ten dollars were stolen from my bag."]
    for s in rights { check("문장 검사 바른 문장은 그대로: \(s.prefix(28))", DoitSentenceCheck.error(in: s) == nil, "\(DoitSentenceCheck.error(in: s)?.why ?? "")") }
    let pompeii = "8번) 다음 중 어법상 바른 것은?\n① I heard that Pompeii had been discovered in 1748.\n② Six kilometers are too long for me to walk.\n③ The young is called the hope of the future.\n④ We were taught that Venus was the hottest planet in the solar system.\n⑤ A number of trucks are parked on the street."
    let pScan = DoitProblemScan.scan(pompeii, math: false)
    let pSolved = DoitSubjectSolve.solve(text: pompeii, choices: pScan.choices, subjectBroad: "영어", body: pScan.body, boxItems: pScan.boxItems)
    check("보내 준 어법 문제 → ⑤", pSolved?.finalAnswer == "5", "\(pSolved?.finalAnswer ?? "nil") \(pScan.choices.count)")
}
