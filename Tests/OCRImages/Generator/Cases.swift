import CoreGraphics
import Foundation

// 테스트 사진 내용: 수학(객관식·단답형·빈칸·분수·근호·지수), 국어·영어·과학·사회 객관식, 영어 단어장

struct Content {
    var id: String
    var category: String
    var kind: String = "problem"
    var lines: [Line]
    var expect: Expectation
    var style = Style()
    var width = 1600
}

/// 보기 하나의 글 (OCR이 내는 모양: 분수 a/b, 근호 √a, 지수 ^n)
func plain(_ segs: [Seg]) -> String {
    func wrap(_ t: String) -> String { t.count == 1 || t.allSatisfy(\.isNumber) || t.hasPrefix("(") ? t : "(\(t))" }
    return segs.map { seg -> String in
        switch seg {
        case .t(let s), .m(let s), .e(let s), .num(let s): return s
        case .sup(let s): return "^" + s
        case .frac(let n, let d): return wrap(n) + "/" + wrap(d)
        case .sqrt(let s): return "√" + s
        case .blank: return "□"
        case .underline: return "□"
        case .circ: return ""
        case .gap: return " "
        }
    }.joined()
}

enum ChoiceLayout { case row5, row32, stack, row4 }

/// 문제 하나: 번호 + 본문 줄들 + 보기
func problem(_ id: String, _ category: String, number: String?, body: [[Seg]], choices: [[Seg]] = [], layout: ChoiceLayout = .row5,
             blank: Bool? = nil, tokens: [String] = [], phrases: [String] = [], checkChoices: Bool = true) -> Content {
    var lines: [Line] = []
    for (k, segs) in body.enumerated() {
        if k == 0, let number { lines.append(.flow([.num(number), .gap(0.35)] + segs)) } else { lines.append(.flow(segs)) }
    }
    if !choices.isEmpty {
        lines.append(.space(0.3))
        let items = choices.enumerated().map { [Seg.circ($0.offset + 1), .gap(0.1)] + $0.element }
        switch layout {
        case .row5: lines.append(.grid(items, cols: 5))
        case .row4: lines.append(.grid(items, cols: 4))
        case .row32: lines.append(.grid(items, cols: 3))
        case .stack: lines.append(.grid(items, cols: 1))
        }
    }
    let expect = Expectation(choices: checkChoices ? choices.map(plain) : nil, blank: blank, tokens: tokens, phrases: phrases)
    return Content(id: id, category: category, lines: lines, expect: expect)
}

func ints(_ values: [String]) -> [[Seg]] { values.map { [.m($0)] } }
func words(_ values: [String]) -> [[Seg]] { values.map { [.t($0)] } }

let problemContents: [Content] = [
    // ---- 수학 객관식 (한 줄 5개) ----
    problem("m-linear", "math-choice", number: "1.", body: [[.t("다음 중 일차방정식 "), .m("2x + 3 = 11"), .t("의 해는?")]],
            choices: ints(["2", "3", "4", "5", "6"]), tokens: ["2x+3=11"], phrases: ["일차방정식"]),
    problem("m-quad-neg", "math-choice", number: "2.", body: [[.t("이차방정식 "), .m("x"), .sup("2"), .m(" + x − 2 = 0"), .t("의 두 근 중")], [.t("작은 근은?")]],
            choices: ints(["−3", "−2", "−1", "1", "2"]), tokens: ["x^2+x-2=0"], phrases: ["작은근은"]),
    problem("m-func", "math-choice", number: "07", body: [[.t("일차함수 "), .m("y = 2x − 3"), .t("의 그래프의 "), .m("y"), .t("절편은?")]],
            choices: ints(["−3", "−2", "0", "2", "3"]), tokens: ["y=2x-3"], phrases: ["그래프"]),
    problem("m-decimal", "math-choice", number: "3.", body: [[.m("0.3 × 0.4"), .t("의 값은?")]],
            choices: ints(["0.012", "0.12", "1.2", "12", "0.7"]), tokens: ["0.3×0.4"]),
    problem("m-ineq", "math-choice", number: "12.", body: [[.t("부등식 "), .m("2x − 1 < 5"), .t("의 해는?")]],
            choices: ints(["x < 2", "x < 3", "x > 3", "x ≤ 3", "x > 2"]), tokens: ["2x-1<5"]),
    problem("m-area", "math-choice", number: "5.", body: [[.t("넓이가 "), .m("36 cm"), .sup("2"), .t("인 정사각형의 한 변의 길이는?")]],
            choices: ints(["4 cm", "5 cm", "6 cm", "8 cm", "9 cm"]), phrases: ["정사각형"]),
    problem("m-power", "math-choice", number: "4.", body: [[.m("2"), .sup("3"), .m(" × 2"), .sup("2"), .t("의 값은?")]],
            choices: ints(["10", "12", "16", "32", "64"]), tokens: ["2^3", "2^2"]),
    // ---- 분수·근호 보기 ----
    problem("m-frac-choice", "math-fraction", number: "6.", body: [[.frac("1", "2"), .m(" + "), .frac("1", "3"), .t("의 값은?")]],
            choices: [[.frac("5", "6")], [.frac("2", "5")], [.frac("1", "6")], [.frac("3", "5")], [.frac("7", "6")]], tokens: ["1/2", "1/3"]),
    problem("m-frac-grid", "math-fraction", number: "9.", body: [[.frac("x", "3"), .m(" = "), .frac("2", "5"), .t("일 때, "), .m("x"), .t("의 값은?")]],
            choices: [[.frac("1", "5")], [.frac("2", "5")], [.frac("3", "5")], [.frac("6", "5")], [.frac("5", "6")]], layout: .row32,
            tokens: ["x/3", "2/5"]),
    problem("m-root-simplify", "math-root", number: "8.", body: [[.sqrt("12"), .t("를 간단히 하면?")]],
            choices: [[.m("2"), .sqrt("2")], [.m("2"), .sqrt("3")], [.m("3"), .sqrt("2")], [.m("4"), .sqrt("3")], [.m("6")]], tokens: ["√12"]),
    problem("m-root-choice", "math-root", number: "10.", body: [[.m("x"), .sup("2"), .m(" = 3"), .t("을 만족하는 양수 "), .m("x"), .t("의 값은?")]],
            choices: [[.sqrt("2")], [.sqrt("3")], [.m("3")], [.m("9")], [.m("2"), .sqrt("3")]], tokens: ["x^2=3"]),
    // ---- 3+2, 세로 5줄 ----
    problem("m-grid32", "math-choice", number: "11.", body: [[.m("x = 2"), .t("일 때, 식 "), .m("3x − 1"), .t("의 값과 같은 것은?")]],
            choices: ints(["2 + 3", "4 × 2", "10 − 4", "3 × 3", "15 ÷ 3"]), layout: .row32, tokens: ["3x-1"]),
    problem("m-stack-identity", "math-choice", number: "13.", body: [[.t("다음 중 옳은 것은?")]],
            choices: [[.m("(a + b)"), .sup("2"), .m(" = a"), .sup("2"), .m(" + b"), .sup("2")],
                      [.m("(a − b)"), .sup("2"), .m(" = a"), .sup("2"), .m(" − 2ab + b"), .sup("2")],
                      [.m("a"), .sup("2"), .m(" − b"), .sup("2"), .m(" = (a − b)"), .sup("2")],
                      [.m("(a + b)(a − b) = a"), .sup("2"), .m(" + b"), .sup("2")],
                      [.m("(a + 1)"), .sup("2"), .m(" = a"), .sup("2"), .m(" + 1")]], layout: .stack),
    problem("m-stack-words", "math-choice", number: "14.", body: [[.t("다음 중 옳지 않은 것은?")]],
            choices: words(["모든 정사각형은 직사각형이다.", "모든 마름모는 평행사변형이다.", "모든 직사각형은 정사각형이다.",
                            "정삼각형의 세 각의 크기는 같다.", "원의 지름은 반지름의 2배이다."]), layout: .stack),
    problem("m-row4", "math-choice", number: "15.", body: [[.t("다음 중 소수인 것은?")]],
            choices: ints(["9", "15", "21", "23"]), layout: .row4),
    // ---- 빈칸 □ ----
    problem("m-blank-mul", "math-blank", number: "1.", body: [[.t("다음 "), .blank, .t(" 안에 알맞은 수를 구하시오.")], [.m("3 × "), .blank, .m(" = 24")]],
            blank: true, tokens: ["3×□=24"], phrases: ["알맞은수"]),
    problem("m-blank-add", "math-blank", number: "2.", body: [[.blank, .m(" + 17 = 42")], [.blank, .t(" 안에 알맞은 수를 쓰시오.")]],
            blank: true, tokens: ["□+17=42"]),
    problem("m-blank-choice", "math-blank", number: "16.", body: [[.t("다음 식의 "), .blank, .t(" 안에 알맞은 수는?")], [.m("(x + 3)"), .sup("2"), .m(" = x"), .sup("2"), .m(" + 6x + "), .blank]],
            choices: ints(["3", "6", "9", "12", "18"]), blank: true, tokens: ["+6x+□"]),
    problem("m-blank-div", "math-blank", number: "3.", body: [[.m("56 ÷ "), .blank, .m(" = 8")], [.t("위 식에서 "), .blank, .t("에 들어갈 수를 구하시오.")]],
            blank: true, tokens: ["56÷□=8"]),
    problem("m-blank-frac", "math-blank", number: "4.", body: [[.frac("1", "3"), .m(" + "), .blank, .m(" = 1")], [.blank, .t(" 안에 알맞은 분수를 구하시오.")]],
            blank: true, tokens: ["1/3"]),
    // ---- 단답형 ----
    problem("m-short-quad", "math-short", number: "5.", body: [[.t("이차방정식 "), .m("x"), .sup("2"), .m(" − 5x + 6 = 0"), .t("의 두 근의 합을")], [.t("구하시오.")]],
            choices: [], tokens: ["x^2-5x+6=0"], phrases: ["두근의합"]),
    problem("m-short-frac-eq", "math-short", number: "6.", body: [[.t("방정식 "), .frac("x", "2"), .m(" + 1 = 4"), .t("의 해를 구하시오.")]],
            choices: [], tokens: ["x/2"]),
    problem("m-short-div-frac", "math-short", number: "7.", body: [[.frac("3", "4"), .m(" ÷ "), .frac("1", "2"), .t("의 값을 구하시오.")]],
            choices: [], tokens: ["3/4", "1/2"]),
    problem("m-short-system", "math-short", number: "8.", body: [[.t("연립방정식 "), .m("x + y = 5"), .t(", "), .m("x − y = 1"), .t("의 해를")], [.t("구하시오.")]],
            choices: [], tokens: ["x+y=5", "x-y=1"]),
    problem("m-short-power", "math-short", number: "9.", body: [[.m("2"), .sup("5"), .m(" × 2"), .sup("3"), .t("을 2의 거듭제곱으로 나타내시오.")]],
            choices: [], tokens: ["2^5", "2^3"]),
    problem("m-short-poly", "math-short", number: "10.", body: [[.m("(2x + 1)(x − 3)"), .t("을 전개하시오.")]],
            choices: [], tokens: ["(2x+1)(x-3)"]),
    // ---- 국어 ----
    problem("k-spelling", "korean", number: "1.", body: [[.t("다음 중 맞춤법에 맞게 쓴 것은?")]],
            choices: words(["금새", "웬일", "몇일", "어떻해", "설레임"])),
    problem("k-pos", "korean", number: "2.", body: [[.t("다음 중 품사가 나머지와 다른 하나는?")]],
            choices: words(["빠르다", "예쁘다", "달리다", "높다", "푸르다"]), layout: .row32),
    problem("k-reading", "korean", number: "3.", body: [[.t("윗글의 내용과 일치하지 않는 것은?")]],
            choices: words(["글쓴이는 시골에서 자랐다.", "할머니는 매일 아침 밭에 나가셨다.", "마을 앞에는 큰 강이 흘렀다.",
                            "글쓴이는 도시 생활을 그리워했다.", "가을이면 온 마을이 함께 추수를 했다."]), layout: .stack),
    // ---- 영어 ----
    problem("e-blank", "english", number: "1.", body: [[.t("다음 빈칸에 들어갈 말로 알맞은 것은?")], [.e("She "), .underline(3), .e(" to school every day.")]],
            choices: words(["go", "goes", "going", "gone", "to go"]), phrases: ["toschooleveryday"]),
    problem("e-grammar", "english", number: "2.", body: [[.t("다음 중 어법상 옳은 문장은?")]],
            choices: words(["He don't like apples.", "She has finished her homework.", "They was very happy.",
                            "I am go to school.", "We is good friends."]), layout: .stack),
    problem("e-vocab", "english", number: "3.", body: [[.t("다음 단어의 뜻으로 알맞은 것은?")], [.e("abundant")]],
            choices: words(["부족한", "풍부한", "위험한", "정직한", "조용한"]), phrases: ["abundant"]),
    // ---- 과학 ----
    problem("s-photo", "science", number: "1.", body: [[.t("다음 중 광합성에 필요한 것이 아닌 것은?")]],
            choices: words(["물", "이산화 탄소", "빛", "엽록체", "산소"])),
    problem("s-unit", "science", number: "2.", body: [[.t("다음 중 속력의 단위로 옳은 것은?")]],
            choices: ints(["m/s", "kg", "N", "J", "W"])),
    problem("s-stack", "science", number: "3.", body: [[.t("물질의 상태 변화에 대한 설명으로 옳은 것은?")]],
            choices: words(["얼음이 녹는 것은 응고이다.", "물이 끓는 것은 액화이다.", "드라이아이스가 작아지는 것은 승화이다.",
                            "수증기가 물이 되는 것은 기화이다.", "물이 얼음이 되면 부피가 줄어든다."]), layout: .stack),
    // ---- 사회 ----
    problem("so-joseon", "social", number: "1.", body: [[.t("조선을 건국한 인물은?")]],
            choices: words(["왕건", "이성계", "세종", "정도전", "이방원"])),
    problem("so-city", "social", number: "2.", body: [[.t("다음 중 우리나라의 광역시가 아닌 것은?")]],
            choices: words(["부산", "대구", "수원", "광주", "울산"]), layout: .row32),
    problem("so-stack", "social", number: "3.", body: [[.t("민주 정치의 기본 원리에 대한 설명으로 옳지 않은 것은?")]],
            choices: words(["국민 주권의 원리를 따른다.", "권력 분립으로 권력의 남용을 막는다.", "입헌주의는 헌법에 따라 통치하는 것이다.",
                            "다수결은 소수 의견을 무시하는 것이다.", "국민 자치는 국민이 스스로 다스리는 것이다."]), layout: .stack),
]

// MARK: - 영어 단어장

let wordSet1: [(String, String)] = [
    ("abandon", "버리다"), ("benefit", "이익"), ("curious", "호기심이 많은"), ("decline", "감소하다"), ("efficient", "효율적인"),
    ("generous", "관대한"), ("hesitate", "망설이다"), ("ignore", "무시하다"), ("journey", "여행"), ("knowledge", "지식"),
    ("maintain", "유지하다"), ("necessary", "필요한")
]
let wordSet2: [(String, String)] = [
    ("observe", "관찰하다"), ("permanent", "영구적인"), ("quality", "품질"), ("recover", "회복하다"), ("satisfy", "만족시키다"),
    ("tradition", "전통"), ("urgent", "긴급한"), ("valuable", "귀중한"), ("wander", "돌아다니다"), ("achieve", "성취하다"),
    ("borrow", "빌리다"), ("compare", "비교하다"), ("describe", "묘사하다"), ("environment", "환경")
]
let wordSet3: [(String, String)] = [
    ("anxious", "불안한"), ("brave", "용감한"), ("cheerful", "쾌활한"), ("delicate", "섬세한"), ("eager", "열망하는"),
    ("fragile", "깨지기 쉬운"), ("grateful", "감사하는"), ("humble", "겸손한")
]

func wordExpect(_ pairs: [(String, String)], notTerms: [String] = []) -> Expectation {
    Expectation(words: pairs.map { WordPair(term: $0.0, meaning: $0.1) }, notTerms: notTerms)
}

/// 두 칸 표: 단어 | 뜻
func wordTable(_ id: String, _ pairs: [(String, String)], extraMeaning: [String: String] = [:], style: Style = Style()) -> Content {
    var lines: [Line] = [.flow([.t("Day 07  필수 영단어")]), .rule]
    for (term, meaning) in pairs {
        let full = extraMeaning[term].map { meaning + ", " + $0 } ?? meaning
        lines.append(.columns([([.e(term)], 0.02), ([.t(full)], 0.45)]))
    }
    var c = Content(id: id, category: "words-table", kind: "words", lines: lines, expect: wordExpect(pairs), style: style)
    c.style.leading = 1.6
    return c
}

/// 번호 목록: "1. abandon   버리다"
func wordNumbered(_ id: String, _ pairs: [(String, String)], style: Style = Style()) -> Content {
    var lines: [Line] = [.flow([.t("단어 시험 범위")]), .space(0.3)]
    for (k, pair) in pairs.enumerated() {
        lines.append(.columns([([.e("\(k + 1). "), .e(pair.0)], 0.0), ([.t(pair.1)], 0.42)]))
    }
    return Content(id: id, category: "words-numbered", kind: "words", lines: lines, expect: wordExpect(pairs), style: style)
}

/// 유의어 줄이 섞인 단어장
func wordSynonyms(_ id: String, style: Style = Style()) -> Content {
    let pairs: [(String, String)] = [("happy", "행복한"), ("begin", "시작하다"), ("difficult", "어려운"), ("quickly", "빠르게"), ("purchase", "구입하다"), ("huge", "거대한")]
    let synonyms: [String: String] = ["happy": "= glad, joyful", "begin": "= start", "difficult": "= hard", "purchase": "= buy", "huge": "= enormous"]
    var lines: [Line] = [.flow([.t("Unit 3  Words")]), .rule]
    for (term, meaning) in pairs {
        lines.append(.columns([([.e(term)], 0.02), ([.t(meaning)], 0.45)]))
        if let syn = synonyms[term] { lines.append(.columns([([.e(syn)], 0.08)])) }
    }
    return Content(id: id, category: "words-synonym", kind: "words", lines: lines,
                   expect: wordExpect(pairs, notTerms: ["glad", "joyful", "start", "hard", "buy", "enormous"]), style: style)
}

/// 두 단 편집: 왼쪽 단 / 오른쪽 단에 각각 단어 + 뜻
func wordTwoColumn(_ id: String, _ pairs: [(String, String)], style: Style = Style()) -> Content {
    var lines: [Line] = [.flow([.t("Vocabulary Check")]), .rule]
    let half = (pairs.count + 1) / 2
    for k in 0..<half {
        var cells: [([Seg], CGFloat)] = [([.e(pairs[k].0)], 0.0), ([.t(pairs[k].1)], 0.24)]
        if k + half < pairs.count { cells += [([.e(pairs[k + half].0)], 0.53), ([.t(pairs[k + half].1)], 0.77)] }
        lines.append(.columns(cells))
    }
    var c = Content(id: id, category: "words-2col", kind: "words", lines: lines, expect: wordExpect(pairs), style: style)
    c.style.size = 34
    return c
}

/// 발음·품사가 있는 시중 단어장 줄: "abandon [əbǽndən]  v. 버리다"
func wordDictionary(_ id: String, style: Style = Style()) -> Content {
    let entries: [(String, String, String, String)] = [
        ("abandon", "əbǽndən", "v.", "버리다"), ("benefit", "bénəfit", "n.", "이익"), ("curious", "kjúəriəs", "a.", "호기심이 많은"),
        ("decline", "dikláin", "v.", "감소하다"), ("efficient", "ifíʃənt", "a.", "효율적인"), ("generous", "dʒénərəs", "a.", "관대한"),
        ("hesitate", "hézətèit", "v.", "망설이다"), ("journey", "dʒə́ːrni", "n.", "여행")
    ]
    var lines: [Line] = [.flow([.t("DAY 01")]), .rule]
    for e in entries {
        lines.append(.columns([([.e(e.0)], 0.0), ([.e("[\(e.1)]")], 0.26), ([.e(e.2), .gap(0.3), .t(e.3)], 0.55)]))
    }
    return Content(id: id, category: "words-dict", kind: "words", lines: lines, expect: wordExpect(entries.map { ($0.0, $0.3) }), style: style)
}

let wordContents: [Content] = {
    var serif = Style()
    serif.korean = "AppleMyungjo"
    serif.koreanBold = "AppleMyungjo"
    var sans = Style()
    sans.latin = "HelveticaNeue"
    sans.italic = "HelveticaNeue"
    return [
        wordTable("w-table-1", wordSet1, extraMeaning: ["abandon": "포기하다", "decline": "거절하다"]),
        wordTable("w-table-2", wordSet2, style: sans),
        wordNumbered("w-num-1", wordSet1),
        wordNumbered("w-num-2", wordSet3, style: serif),
        wordSynonyms("w-syn-1"),
        wordSynonyms("w-syn-2", style: sans),
        wordTwoColumn("w-2col-1", wordSet2),
        wordTwoColumn("w-2col-2", wordSet1, style: serif),
        wordDictionary("w-dict-1"),
    ]
}()
