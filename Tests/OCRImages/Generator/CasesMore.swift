import CoreGraphics
import Foundation

// 영어·과학 문제 더: 긴 지문, 빈칸 (A)(B), 지문 속 밑줄 번호, 순서 배열, 문장 넣기, 화학식·이온·단위·그래프·표·<보기>

/// 영어 낱말 보기 (영어 글꼴)
func ewords(_ values: [String]) -> [[Seg]] { values.map { [.e($0)] } }

/// 여러 줄 모양(상자·표·그래프 포함)으로 된 문제: 첫 줄 앞에 번호
func subject(_ id: String, _ category: String, number: String, lines body: [Line], choices: [[Seg]] = [], layout: ChoiceLayout = .row5,
             tokens: [String] = [], phrases: [String] = [], checkChoices: Bool = true, boxItems: [String]? = nil) -> Content {
    var lines: [Line] = []
    for (k, line) in body.enumerated() {
        if k == 0, case .flow(let segs) = line { lines.append(.flow([.num(number), .gap(0.35)] + segs)) } else { lines.append(line) }
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
    var expect = Expectation(choices: checkChoices ? choices.map(plain) : nil, tokens: tokens, phrases: phrases)
    expect.boxItems = boxItems
    return Content(id: id, category: category, kind: "subject", lines: lines, expect: expect)
}

let moreSubjectContents: [Content] = [
    // ---- 영어 ----
    subject("e-passage-blank", "english", number: "4.", lines: [
        .flow([.t("다음 글의 빈칸 (A), (B)에 들어갈 말로 가장 적절한 것은?")]),
        .flow([.e("Many students believe that studying late at night is")]),
        .flow([.e("effective. ( A ), research shows that sleep helps the")]),
        .flow([.e("brain store new information. ( B ), getting enough")]),
        .flow([.e("sleep is an important part of learning.")]),
        .flow([.gap(1.4), .e("(A)"), .gap(4.6), .e("(B)")]),
    ], choices: [[.e("However"), .gap(2.2), .e("Therefore")], [.e("However"), .gap(2.2), .e("Instead")], [.e("Besides"), .gap(2.2), .e("Therefore")],
                 [.e("Similarly"), .gap(2.2), .e("Instead")], [.e("In short"), .gap(2.2), .e("Otherwise")]], layout: .stack,
       phrases: ["effective. ( A ), research shows", "sleep helps the", "brain store new information. ( B )", "an important part of learning."]),
    subject("e-underline", "english", number: "5.", lines: [
        .flow([.t("다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?")]),
        .flow([.e("Many people "), .circ(1), .u("believe"), .e(" that reading books")]),
        .flow([.e("is a waste of time. However, reading "), .circ(2), .u("helps")]),
        .flow([.e("us "), .circ(3), .u("to understand"), .e(" other people. It also")]),
        .flow([.e("makes us "), .circ(4), .u("more creative"), .e(". That is why we")]),
        .flow([.e("should "), .circ(5), .u("reading"), .e(" every day.")]),
    ], phrases: ["Many people ①believe", "②helps", "③to understand", "④more creative", "⑤reading every day", "is a waste of time."], checkChoices: false),
    subject("e-order", "english", number: "6.", lines: [
        .flow([.t("주어진 글 다음에 이어질 글의 순서로 가장 적절한 것은?")]),
        .boxed(nil, [[.e("Plants need sunlight to make their own food.")]]),
        .flow([.e("(A) This process is called photosynthesis.")]),
        .flow([.e("(B) They use the energy of light to change water")]),
        .flow([.e("and carbon dioxide into sugar.")]),
        .flow([.e("(C) As a result, they also produce oxygen for us.")]),
    ], choices: ewords(["(A) - (C) - (B)", "(B) - (A) - (C)", "(B) - (C) - (A)", "(C) - (A) - (B)", "(C) - (B) - (A)"]), layout: .row32,
       phrases: ["Plants need sunlight to make their own food.", "(A) This process is called photosynthesis.", "(C) As a result, they also produce oxygen"]),
    subject("e-insert", "english", number: "7.", lines: [
        .flow([.t("글의 흐름으로 보아, 주어진 문장이 들어가기에 가장 적절한 곳은?")]),
        .boxed(nil, [[.e("But this is not always true.")]]),
        .flow([.e("People often say that practice makes perfect. ( "), .circ(1), .e(" )")]),
        .flow([.e("If you practice the wrong way, you will only repeat")]),
        .flow([.e("your mistakes. ( "), .circ(2), .e(" ) Good practice needs clear goals.")]),
        .flow([.e("( "), .circ(3), .e(" ) It also needs feedback from others. ( "), .circ(4), .e(" ) With")]),
        .flow([.e("both, you can improve quickly. ( "), .circ(5), .e(" )")]),
    ], phrases: ["But this is not always true.", "practice makes perfect. ( ① )", "your mistakes. ( ② )", "( ③ ) It also needs feedback", "( ④ ) With", "improve quickly. ( ⑤ )"], checkChoices: false),
    subject("e-grammar2", "english", number: "8.", lines: [
        .flow([.t("다음 중 어법상 옳은 문장은?")]),
    ], choices: ewords(["I have lived here since 2010.", "If I am you, I would go.", "I'm looking forward to see you.",
                        "Let me know when you will arrive.", "I enjoyed to swim in the lake."]), layout: .stack),
    subject("e-dialog", "english", number: "9.", lines: [
        .flow([.t("다음 대화의 빈칸에 들어갈 말로 알맞은 것은?")]),
        .flow([.e("A: Where "), .underline(3), .e(" you go last weekend?")]),
        .flow([.e("B: I went to the zoo with my family.")]),
    ], choices: ewords(["do", "did", "does", "are", "is"]), phrases: ["you go last weekend?", "B: I went to the zoo with my family."]),
    subject("e-topic", "english", number: "10.", lines: [
        .flow([.t("다음 글의 주제로 가장 적절한 것은?")]),
        .flow([.e("Recycling is one of the easiest ways to protect our")]),
        .flow([.e("environment. When we recycle paper, plastic, and glass,")]),
        .flow([.e("we reduce the amount of waste in landfills. We also")]),
        .flow([.e("save energy, because making new products from old")]),
        .flow([.e("materials uses less power. Small actions at home can")]),
        .flow([.e("make a big difference for the planet.")]),
    ], choices: ewords(["the history of landfills", "the benefits of recycling", "how to make glass", "the cost of new energy", "why plastic is dangerous"]),
       layout: .stack, phrases: ["Recycling is one of the easiest ways", "we reduce the amount of waste in landfills.", "make a big difference for the planet."]),
    subject("e-definition", "english", number: "11.", lines: [
        .flow([.t("다음 영영 풀이에 해당하는 단어로 알맞은 것은?")]),
        .flow([.e("to feel or show that you are thankful for something")]),
    ], choices: ewords(["grateful", "jealous", "curious", "humble", "brave"]), phrases: ["thankful for something"]),

    // ---- 과학 ----
    subject("s-formula", "science", number: "4.", lines: [
        .flow([.t("다음은 물이 만들어지는 반응을 화학 반응식으로 나타낸 것이다.")]),
        .flow([.gap(2), .e("2H"), .sub("2"), .e(" + O"), .sub("2"), .e(" → 2H"), .sub("2"), .e("O")]),
        .flow([.t("이 반응에서 생성되는 물질의 화학식은?")]),
    ], choices: [[.e("H"), .sub("2"), .e("O")], [.e("CO"), .sub("2")], [.e("O"), .sub("2")], [.e("H"), .sub("2")], [.e("N"), .sub("2")]],
       tokens: ["2H₂ + O₂ → 2H₂O"]),
    subject("s-ion", "science", number: "5.", lines: [
        .flow([.t("다음 이온 중 전하의 크기가 가장 큰 것은?")]),
    ], choices: [[.e("Na"), .supText("+")], [.e("Cl"), .supText("−")], [.e("Mg"), .supText("2+")], [.e("Al"), .supText("3+")], [.e("O"), .supText("2−")]]),
    subject("s-units", "science", number: "6.", lines: [
        .flow([.t("다음 중 물리량과 단위를 옳게 짝지은 것은?")]),
    ], choices: [[.t("속력 - "), .e("m/s")], [.t("가속도 - "), .e("m/s"), .supText("2")], [.t("밀도 - "), .e("g/cm"), .supText("3")],
                 [.t("힘 - "), .e("J")], [.t("온도 - "), .e("°C")]], layout: .stack),
    subject("s-graph", "science", number: "7.", lines: [
        .flow([.t("그래프는 직선 위를 운동하는 물체의 속력을 시간에 따라")]),
        .flow([.t("나타낸 것이다. 이 물체의 가속도의 크기는?")]),
        .space(0.4),
        .graph(GraphSpec(xLabel: "시간(s)", yLabel: "속력(m/s)", xTicks: ["0", "1", "2", "3", "4"], yTicks: ["0", "2", "4", "6", "8"],
                         points: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)])),
    ], choices: [[.e("1 m/s"), .supText("2")], [.e("2 m/s"), .supText("2")], [.e("3 m/s"), .supText("2")], [.e("4 m/s"), .supText("2")], [.e("8 m/s"), .supText("2")]],
       phrases: ["시간(s)", "속력(m/s)", "가속도의 크기는?"]),
    subject("s-table", "science", number: "8.", lines: [
        .flow([.t("표는 온도에 따른 질산 칼륨의 용해도를 나타낸 것이다.")]),
        .space(0.3),
        .table([[[.t("온도("), .e("°C"), .t(")")], [.e("0")], [.e("20")], [.e("40")], [.e("60")]],
                [[.t("용해도(g/물 100 g)")], [.e("13")], [.e("32")], [.e("64")], [.e("110")]]],
               [0, 0.42, 0.56, 0.7, 0.84, 1.0]),
        .space(0.3),
        .flow([.t("40 °C 물 100 g에 질산 칼륨 80 g을 넣었을 때 녹지 않고")]),
        .flow([.t("남는 질산 칼륨의 질량은?")]),
    ], choices: ints(["6 g", "16 g", "32 g", "48 g", "64 g"]), phrases: ["온도(°C)", "용해도(g/물100g)", "40 °C 물 100 g에", "질량은?"]),
    subject("s-boki", "science", number: "9.", lines: [
        .flow([.t("광합성에 대한 설명으로 옳은 것만을 <보기>에서 있는")]),
        .flow([.t("대로 고른 것은?")]),
        .space(0.2),
        .boxed("<보기>", [[.t("ㄱ. 엽록체에서 일어난다.")], [.t("ㄴ. 산소를 흡수하고 이산화 탄소를 방출한다.")], [.t("ㄷ. 빛에너지를 화학 에너지로 전환한다.")]]),
    ], choices: words(["ㄱ", "ㄴ", "ㄱ, ㄷ", "ㄴ, ㄷ", "ㄱ, ㄴ, ㄷ"]),
       boxItems: ["ㄱ. 엽록체에서 일어난다.", "ㄴ. 산소를 흡수하고 이산화 탄소를 방출한다.", "ㄷ. 빛에너지를 화학 에너지로 전환한다."]),
    subject("s-boki2", "science", number: "10.", lines: [
        .flow([.t("<보기>에서 화학 변화인 것만을 있는 대로 고른 것은?")]),
        .space(0.2),
        .boxed("<보기>", [[.t("ㄱ. 철이 녹슨다.")], [.t("ㄴ. 얼음이 녹는다.")], [.t("ㄷ. 나무가 탄다.")]]),
    ], choices: words(["ㄱ", "ㄷ", "ㄱ, ㄴ", "ㄱ, ㄷ", "ㄴ, ㄷ"]), layout: .row32,
       boxItems: ["ㄱ. 철이 녹슨다.", "ㄴ. 얼음이 녹는다.", "ㄷ. 나무가 탄다."]),
    subject("s-experiment", "science", number: "11.", lines: [
        .flow([.t("다음은 물의 끓는점을 알아보기 위한 실험이다.")]),
        .flow([.t("(가) 비커에 물 200 mL를 넣고 가열한다.")]),
        .flow([.t("(나) 1분마다 물의 온도를 측정한다.")]),
        .flow([.t("(다) 물이 끓기 시작하면 온도가 100 °C에서 일정하다.")]),
        .flow([.t("이 실험에 대한 설명으로 옳은 것은?")]),
    ], choices: words(["물의 끓는점은 100 °C이다.", "가열하면 물의 질량이 늘어난다.", "끓는 동안 온도가 계속 올라간다.",
                       "물 200 mL의 부피는 변하지 않는다.", "온도계는 1분마다 바꾼다."]), layout: .stack,
       phrases: ["(가) 비커에 물 200 mL를", "100 °C에서 일정하다"]),
    subject("s-electric", "science", number: "12.", lines: [
        .flow([.t("저항이 10 "), .e("Ω"), .t("인 니크롬선에 2 A의 전류가 흐를 때,")]),
        .flow([.t("니크롬선 양 끝에 걸린 전압은?")]),
    ], choices: ints(["5 V", "10 V", "20 V", "40 V", "50 V"]), phrases: ["10 Ω인", "2 A의 전류"]),
    subject("s-equilibrium", "science", number: "13.", lines: [
        .flow([.t("다음은 암모니아가 생성되는 반응의 화학 반응식이다.")]),
        .flow([.gap(2), .e("N"), .sub("2"), .e(" + 3H"), .sub("2"), .e(" ⇌ 2NH"), .sub("3"), .gap(2), .e("ΔH < 0")]),
        .flow([.t("이 반응에서 반응물의 계수의 합은?")]),
    ], choices: ints(["2", "3", "4", "5", "6"]), tokens: ["N₂ + 3H₂ ⇌ 2NH₃", "ΔH < 0"]),
    subject("s-micro", "science", number: "14.", lines: [
        .flow([.t("현미경으로 본 세포의 크기가 약 20 "), .e("μm"), .t("일 때, 이 크기를")]),
        .flow([.e("mm"), .t(" 단위로 나타낸 것은?")]),
    ], choices: ints(["0.002 mm", "0.02 mm", "0.2 mm", "2 mm", "20 mm"]), phrases: ["20 μm일 때"]),
]
