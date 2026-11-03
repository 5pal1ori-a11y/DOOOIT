import Foundation

// MARK: - 영어 배터리: 시험 모양 어법 문제 (사진 글 → DoitProblemScan → DoitSubjectSolve.solve)
// - 오답은 실패, 못 푼 것은 목록만. 함정(답이 하나로 안 정해지거나 규칙으로 알 수 없는 것)은 풀면 실패
// - 새 문제(englishBatteryFresh)는 규칙을 다 만든 뒤에 쓴 문제: 오답 0만 확인하고 정답 수는 따로 보여 줌

struct EnglishBatteryCase {
    /// 유형: 문장고르기 · 밑줄 · 네모 · 개수 · 고치기 · 빈칸 · 전환 · 보기
    let type: String
    let level: String
    let text: String
    let answer: String
    init(_ type: String, _ level: String, _ text: String, _ answer: String) { self.type = type; self.level = level; self.text = text; self.answer = answer }
}

func runEnglishRuleCases() {
    var wrongMissed: [String] = [], rightFlagged: [String] = [], fixMissed: [String] = []
    var perLevel: [String: (found: Int, total: Int)] = [:]
    for rc in englishRuleCases {
        for (s, fix) in rc.wrong {
            let issues = DoitEnglishGrammar.check(sentence: s)
            var l = perLevel[rc.level] ?? (0, 0)
            l.total += 1
            if issues.isEmpty { wrongMissed.append("[\(rc.topic)] \(s)") } else { l.found += 1 }
            perLevel[rc.level] = l
            check("영어 규칙 [\(rc.topic)] 틀린 곳 찾기 — \(s)", !issues.isEmpty)
            if !fix.isEmpty, !issues.isEmpty {
                let corrected = DoitEnglishGrammar.correct(s) ?? ""
                let fixes = issues.compactMap(\.fix).joined(separator: " | ")
                let ok = corrected.contains(fix) || fixes.contains(fix)
                if !ok { fixMissed.append("[\(rc.topic)] \(s) → '\(corrected)' / \(fixes)") }
                check("영어 규칙 [\(rc.topic)] 고친 말 — \(s)", ok, "'\(corrected)' / \(fixes), 기대 '\(fix)'")
            }
        }
        for s in rc.right {
            let issues = DoitEnglishGrammar.check(sentence: s)
            if let i = issues.first { rightFlagged.append("[\(rc.topic)] \(s) → \(i.rule): \(i.why)") }
            check("영어 규칙 [\(rc.topic)] 바른 문장 그대로 — \(s)", issues.isEmpty, issues.first.map { "\($0.rule): \($0.why)" } ?? "")
        }
    }
    var precisionFlagged: [String] = []
    for s in englishPrecisionSuite {
        let issues = DoitEnglishGrammar.check(sentence: s)
        if let i = issues.first { precisionFlagged.append("\(s) → \(i.rule): \(i.why)") }
        check("영어 정밀도: 바른 문장 — \(s)", issues.isEmpty, issues.first.map { "\($0.rule): \($0.why)" } ?? "")
    }
    check("영어 정밀도 모음 300문장 이상", englishPrecisionSuite.count >= 300, "\(englishPrecisionSuite.count)")
    let rightCount = englishRuleCases.reduce(0) { $0 + $1.right.count }
    print("영어 규칙: 틀린 문장 \(englishRuleCases.reduce(0) { $0 + $1.wrong.count })개 중 못 찾음 \(wrongMissed.count), 닮은 바른 문장 \(rightCount)개 중 잘못 걸림 \(rightFlagged.count)")
    for level in DoitEnglishGrammar.levels { if let l = perLevel[level] { print("  영어 규칙 [\(level)]: 찾음 \(l.found) / \(l.total)") } }
    print("영어 정밀도: 바른 문장 \(englishPrecisionSuite.count)개 중 잘못 걸림 \(precisionFlagged.count)")
    for m in wrongMissed { print("  · 못 찾음: " + m) }
    for f in fixMissed { print("  · 고친 말 다름: " + f) }
    for r in rightFlagged { print("  ✗ 바른 문장이 걸림: " + r) }
    for r in precisionFlagged { print("  ✗ 정밀도: " + r) }
    // 단원 목록: 규칙 이름이 모두 단원에 들어 있는지
    check("영어 문법 단원: 학년 3개", Set(DoitEnglishGrammar.topics.map(\.level)) == Set(DoitEnglishGrammar.levels))
}

func runEnglishBatteryCases() {
    runEnglishRuleCases()
    func runList(_ list: [EnglishBatteryCase], tag: String) -> (byType: [String: (Int, Int, Int, Int)], byLevel: [String: (Int, Int, Int, Int)], wrongs: [String], unsolved: [String]) {
        var byType: [String: (Int, Int, Int, Int)] = [:], byLevel: [String: (Int, Int, Int, Int)] = [:]
        var wrongs: [String] = [], unsolved: [String] = []
        for item in list {
            let scan = DoitProblemScan.scan(item.text, math: false)
            let label = "[\(item.type)·\(item.level)] " + item.text.replacingOccurrences(of: "\n", with: " / ")
            var t = byType[item.type] ?? (0, 0, 0, 0), l = byLevel[item.level] ?? (0, 0, 0, 0)
            t.3 += 1; l.3 += 1
            defer { byType[item.type] = t; byLevel[item.level] = l }
            guard let solution = DoitSubjectSolve.solve(text: item.text, choices: scan.choices, subjectBroad: "영어", body: scan.body, boxItems: scan.boxItems) else {
                t.1 += 1; l.1 += 1; unsolved.append(label); continue
            }
            let answer = solution.finalAnswer
            let right = scan.choices.count >= 2
                ? (DoitGrader.choiceNumber(answer, choices: scan.choices).map { "\($0)" == item.answer } ?? false)
                : subjectMatches(answer, expected: item.answer)
            check("\(tag) 확인된 답: \(label)", solution.source == DoitAutoSolve.engineSource && !solution.steps.isEmpty)
            if right { t.0 += 1; l.0 += 1 } else { t.2 += 1; l.2 += 1; wrongs.append("\(label) → 답 '\(answer)', 정답 '\(item.answer)'") }
            check("\(tag) 오답 없음: \(label)", right, "답 '\(answer)', 정답 '\(item.answer)'")
        }
        return (byType, byLevel, wrongs, unsolved)
    }
    let main = runList(englishBattery, tag: "영어 배터리")
    for type in englishBatteryTypes { if let s = main.byType[type] { print("영어 배터리 [\(type)]: 정답 \(s.0) / 전체 \(s.3), 못 풂 \(s.1), 오답 \(s.2)") } }
    for level in DoitEnglishGrammar.levels { if let s = main.byLevel[level] { print("영어 배터리 [\(level)]: 정답 \(s.0) / 전체 \(s.3), 못 풂 \(s.1), 오답 \(s.2)") } }
    let total = main.byType.values.reduce((0, 0, 0, 0)) { ($0.0 + $1.0, $0.1 + $1.1, $0.2 + $1.2, $0.3 + $1.3) }
    var trapSolved: [String] = []
    for trap in englishBatteryTraps {
        let scan = DoitProblemScan.scan(trap.text, math: false)
        let solved = DoitSubjectSolve.solve(text: trap.text, choices: scan.choices, subjectBroad: "영어", body: scan.body, boxItems: scan.boxItems)
        if let solved { trapSolved.append("[\(trap.type)] \(trap.text.prefix(70).replacingOccurrences(of: "\n", with: " / ")) → '\(solved.finalAnswer)'") }
        check("영어 배터리 함정은 풀지 않음: \(trap.text.prefix(50))", solved == nil, "답 '\(solved?.finalAnswer ?? "")'")
    }
    print("영어 배터리: 정답 \(total.0) / 전체 \(total.3), 못 풂 \(total.1), 오답 \(total.2), 함정 \(englishBatteryTraps.count)개 중 푼 것 \(trapSolved.count)개")
    check("영어 배터리: 400문제 이상", englishBattery.count >= 400, "\(englishBattery.count)")
    check("영어 배터리: 함정 60개 이상", englishBatteryTraps.count >= 60, "\(englishBatteryTraps.count)")
    check("영어 배터리: 오답 0개", main.wrongs.isEmpty, "오답 \(main.wrongs.count)개")
    for w in main.wrongs { print("  ✗ 영어 오답: " + w) }
    for t in trapSolved { print("  ✗ 영어 함정을 풂: " + t) }
    for u in main.unsolved { print("  · 영어 못 풂: " + u) }
    let fresh = runList(englishBatteryFresh, tag: "영어 배터리 새 문제")
    let ft = fresh.byType.values.reduce((0, 0, 0, 0)) { ($0.0 + $1.0, $0.1 + $1.1, $0.2 + $1.2, $0.3 + $1.3) }
    print("영어 배터리 새 문제: 정답 \(ft.0) / 전체 \(ft.3), 못 풂 \(ft.1), 오답 \(ft.2)")
    for type in englishBatteryTypes { if let s = fresh.byType[type] { print("  영어 새 문제 [\(type)]: 정답 \(s.0) / 전체 \(s.3), 못 풂 \(s.1), 오답 \(s.2)") } }
    check("영어 배터리 새 문제 50개 이상", englishBatteryFresh.count >= 50, "\(englishBatteryFresh.count)")
    for w in fresh.wrongs { print("  ✗ 영어 새 문제 오답: " + w) }
    for u in fresh.unsolved { print("  · 영어 새 문제 못 풂: " + u) }
}

let englishBatteryTypes = ["문장고르기", "밑줄", "네모", "개수", "고치기", "빈칸", "전환", "보기"]

/// 재료 문장으로 만든 시험 문제 (문장 고르기 · 보기 · 고치기 · 개수)
func composedEnglishBattery() -> [EnglishBatteryCase] {
    var out: [EnglishBatteryCase] = []
    let circles = ["①", "②", "③", "④", "⑤"]
    func listing(_ items: [String], inline: Bool) -> String {
        items.indices.map { "\(circles[$0]) \(items[$0])" }.joined(separator: inline ? " " : "\n")
    }
    // 어색한 문장 고르기: 틀린 문장 하나 + 같은 학년 바른 문장 넷
    let wrongPrompts = ["다음 중 어법상 어색한 문장은?", "다음 중 어법상 틀린 것은?", "어법상 바르지 않은 문장을 고르시오.", "다음 중 어법상 적절하지 않은 문장은?"]
    for (k, w) in poolWrong.enumerated() {
        let rights = poolRight.filter { $0.level == w.level && $0.sentence.split(separator: " ").prefix(3) != w.sentence.split(separator: " ").prefix(3) }
        guard rights.count >= 4 else { continue }
        var items = (0..<4).map { rights[(k * 3 + $0 * 7) % rights.count].sentence }
        if Set(items).count < 4 { items = Array(rights.prefix(4).map(\.sentence)) }
        let pos = k % 5
        items.insert(w.sentence, at: pos)
        let style = k % 4
        let text = style == 1 ? "\(k % 30 + 1)번) \(wrongPrompts[style]) " + listing(items, inline: true) : wrongPrompts[style] + "\n" + listing(items, inline: false)
        out.append(EnglishBatteryCase("문장고르기", w.level, text, "\(pos + 1)"))
    }
    // 옳은 문장 고르기: 바른 문장 하나 + 같은 학년 틀린 문장 넷
    for k in stride(from: 0, to: poolRight.count, by: 3) {
        let r = poolRight[k]
        let wrongs = poolWrong.filter { $0.level == r.level }
        guard wrongs.count >= 4 else { continue }
        var items = (0..<4).map { wrongs[(k * 5 + $0 * 11) % wrongs.count].sentence }
        if Set(items).count < 4 { items = Array(wrongs.prefix(4).map(\.sentence)) }
        let pos = (k / 3) % 5
        items.insert(r.sentence, at: pos)
        let prompt = k % 2 == 0 ? "다음 중 어법상 옳은 문장은?" : "어법상 바른 문장을 고르면?"
        out.append(EnglishBatteryCase("문장고르기", r.level, prompt + "\n" + listing(items, inline: k % 6 == 3), "\(pos + 1)"))
    }
    // <보기> 옳은 것끼리 · 틀린 것끼리
    let pairs = [(0, 1), (0, 2), (1, 3), (2, 4), (3, 4)]
    let letters = ["a", "b", "c", "d", "e"]
    for k in 0..<16 {
        let level = DoitEnglishGrammar.levels[k % 3]
        let rights = poolRight.filter { $0.level == level }.map(\.sentence), wrongs = poolWrong.filter { $0.level == level }.map(\.sentence)
        let answer = k % 5
        let wantRight = k % 2 == 0
        var items: [String] = []
        var ri = k * 2, wi = k * 3
        for slot in 0..<5 {
            let inPair = slot == pairs[answer].0 || slot == pairs[answer].1
            if inPair == wantRight { items.append(rights[ri % rights.count]); ri += 1 } else { items.append(wrongs[wi % wrongs.count]); wi += 1 }
        }
        let body = items.indices.map { "\(letters[$0])) \(items[$0])" }.joined(separator: "\n")
        let choices = pairs.indices.map { "\(circles[$0]) \(letters[pairs[$0].0]), \(letters[pairs[$0].1])" }.joined(separator: " ")
        let prompt = wantRight ? "다음 중 어법상 옳은 것끼리 짝지어진 것은?" : "다음 중 어법상 틀린 것끼리 묶인 것은?"
        out.append(EnglishBatteryCase("보기", level, prompt + "\n" + body + "\n" + choices, "\(answer + 1)"))
    }
    // 틀린 부분 고치기 (서술형)
    let fixPrompts = ["다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\n", "위 문장에서 어법상 어색한 부분을 찾아 고쳐 쓰시오.\n", "8번) 다음 문장의 틀린 곳을 고쳐 쓰시오. "]
    var f = 0
    for w in poolWrong where !w.fix.isEmpty {
        let style = f % 3
        let text = style == 1 ? w.sentence + "\n" + fixPrompts[1] : fixPrompts[style] + w.sentence
        out.append(EnglishBatteryCase("고치기", w.level, text, "~→ \(w.fix)"))
        f += 1
    }
    // 틀린(옳은) 문장의 개수: 모두 틀린 문장
    for k in 0..<10 {
        let level = DoitEnglishGrammar.levels[k % 3]
        let wrongs = poolWrong.filter { $0.level == level }.map(\.sentence)
        let items = (0..<4).map { wrongs[(k * 4 + $0) % wrongs.count] }
        let body = items.indices.map { "(\(letters[$0])) \(items[$0])" }.joined(separator: "\n")
        let wantWrong = k % 2 == 0
        let prompt = wantWrong ? "다음 중 어법상 틀린 문장의 개수는?" : "다음 중 어법상 옳은 문장의 개수는?"
        out.append(EnglishBatteryCase("개수", level, prompt + "\n" + body + "\n① 0개 ② 1개 ③ 2개 ④ 3개 ⑤ 4개", wantWrong ? "5" : "1"))
    }
    // 섞인 개수 문제 (맞는 문장이 있으면 규칙으로는 개수를 확정 못 해요 → 못 풂으로 남음)
    for k in 0..<4 {
        let level = DoitEnglishGrammar.levels[k % 3]
        let wrongs = poolWrong.filter { $0.level == level }.map(\.sentence), rights = poolRight.filter { $0.level == level }.map(\.sentence)
        let items = [wrongs[k], rights[k + 3], wrongs[k + 5], rights[k + 8]]
        let body = items.indices.map { "\(letters[$0])) \(items[$0])" }.joined(separator: "\n")
        out.append(EnglishBatteryCase("개수", level, "어법상 틀린 문장은 모두 몇 개인가?\n" + body + "\n① 1개 ② 2개 ③ 3개 ④ 4개 ⑤ 없음", "2"))
    }
    return out
}

let englishBattery: [EnglishBatteryCase] = composedEnglishBattery() + englishHandBattery
