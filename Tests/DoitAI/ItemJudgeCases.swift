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
    }

    // ㄱ·ㄴ·ㄷ, 틀린 것, 있는 대로
    let box = "다음 중 옳지 않은 것만을 있는 대로 고른 것은?\nㄱ. 물은 100℃에서 끓는다.\nㄴ. 소금은 금속이다.\nㄷ. 공기는 혼합물이다."
    let s2 = DoitItemJudge.setup(text: box, body: nil, choices: ["ㄱ", "ㄴ", "ㄱ, ㄴ", "ㄴ, ㄷ", "ㄱ, ㄴ, ㄷ"], boxItems: nil)
    check("항목 판단: 틀린 것 · 있는 대로", s2?.wantTrue == false && s2?.exact == true && s2?.items.count == 3)
    if let s2 {
        let p = DoitItemJudge.parseVerdicts("ㄱ. O\nㄴ. X\nㄷ. O", labels: ["ㄱ", "ㄴ", "ㄷ"])
        check("항목 판단: 틀린 것 ㄴ → ②", p.flatMap { DoitItemJudge.pickChoice(s2, verdicts: $0.verdicts) } == 1)
    }
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
}
