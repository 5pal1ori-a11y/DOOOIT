import CoreGraphics
import Foundation

// 도형 기호 문제: 선분 윗줄(AB̅), ∠, △, ⊥, ∥(//), °, ≡(합동), ∽(닮음), 호, □ABCD(사각형), π
// 기대하는 글은 앱 표기 (선분 A̅B̅, 각 ∠ABC, 삼각형 △ABC, 평행 ∥, 사각형 ABCD, 호 AB)

/// 선분 조각 (윗줄)
func seg(_ s: String) -> Seg { .over(s) }
/// 앱 표기의 선분 글자
func segText(_ s: String) -> String { s.map { "\($0)\u{305}" }.joined() }

func degs(_ values: [String]) -> [[Seg]] { values.map { [.m($0 + "°")] } }

let geometryContents: [Content] = [
    problem("g-tri-sum", "math-geo", number: "1.", body: [[.m("△ABC"), .t("에서 "), .m("∠A = 50°, ∠B = 60°"), .t("일 때, "), .m("∠C"), .t("의 크기는?")]],
            choices: degs(["60", "70", "80", "90", "100"]), tokens: ["△ABC", "∠A=50°", "∠B=60°", "∠C의크기"]),
    problem("g-pyth", "math-geo", number: "2.", body: [[.t("직각삼각형 ABC에서 "), .m("∠B = 90°, "), seg("AB"), .m(" = 6, "), seg("BC"), .m(" = 8")],
                                                        [.t("일 때, "), seg("AC"), .t("의 길이는?")]],
            choices: ints(["8", "9", "10", "11", "12"]), tokens: ["∠B=90°", segText("AB") + "=6", segText("BC") + "=8", segText("AC") + "의길이"]),
    problem("g-iso", "math-geo", number: "3.", body: [[seg("AB"), .m(" = "), seg("AC"), .t("인 이등변삼각형 ABC에서 "), .m("∠A = 40°")],
                                                       [.t("일 때, "), .m("∠B"), .t("의 크기는?")]],
            choices: degs(["50", "60", "70", "80", "90"]), tokens: [segText("AB") + "=" + segText("AC"), "∠A=40°", "∠B의크기"]),
    problem("g-parallel", "math-geo", number: "4.", body: [[.t("다음 그림에서 "), .m("l ∥ m"), .t("일 때, "), .m("∠x"), .t("의 크기를 구하시오.")]],
            tokens: ["l∥m", "∠x의크기"], checkChoices: false),
    problem("g-parallel-slash", "math-geo", number: "5.", body: [[.t("오른쪽 그림에서 "), .m("l // m"), .t("이고 "), .m("∠a = 65°"), .t("일 때,")], [.m("∠b"), .t("의 크기를 구하시오.")]],
            tokens: ["l∥m", "∠a=65°", "∠b의크기"], checkChoices: false),
    problem("g-perp", "math-geo", number: "6.", body: [[seg("AB"), .m(" ⊥ "), seg("CD"), .t("이고 "), .m("∠ACD = 35°"), .t("일 때, "), .m("∠x"), .t("의 크기는?")]],
            choices: degs(["35", "45", "55", "65", "75"]), tokens: [segText("AB") + "⊥" + segText("CD"), "∠ACD=35°"]),
    problem("g-congruent", "math-geo", number: "7.", body: [[.m("△ABC ≡ △DEF"), .t("일 때, 다음 중 옳지 않은 것은?")]],
            choices: [[seg("AB"), .m(" = "), seg("DE")], [seg("BC"), .m(" = "), seg("EF")], [.m("∠A = ∠D")], [.m("∠B = ∠F")], [.m("∠C = ∠F")]],
            layout: .row32, tokens: ["△ABC≡△DEF"], checkChoices: false),
    problem("g-similar", "math-geo", number: "8.", body: [[.m("△ABC ∽ △DEF"), .t("이고 "), seg("AB"), .m(" = 4, "), seg("DE"), .m(" = 6, "), seg("BC"), .m(" = 6")],
                                                           [.t("일 때, "), seg("EF"), .t("의 길이는?")]],
            choices: ints(["7", "8", "9", "10", "12"]), tokens: ["△ABC∽△DEF", segText("AB") + "=4", segText("EF") + "의길이"]),
    problem("g-inscribed", "math-geo", number: "9.", body: [[.t("원 O에서 중심각 "), .m("∠AOB = 100°"), .t("일 때, 원주각 "), .m("∠APB"), .t("의 크기는?")]],
            choices: degs(["40", "50", "60", "80", "100"]), tokens: ["∠AOB=100°", "∠APB"]),
    problem("g-polygon", "math-geo", number: "10.", body: [[.t("육각형의 내각의 크기의 합은?")]],
            choices: degs(["360", "540", "720", "900", "1080"]), phrases: ["내각의크기의합"]),
    problem("g-exterior", "math-geo", number: "11.", body: [[.m("△ABC"), .t("에서 "), .m("∠A = 45°, ∠B = 70°"), .t("일 때, "), .m("∠C"), .t("의 외각의 크기는?")]],
            choices: degs(["95", "105", "115", "125", "135"]), tokens: ["△ABC", "∠A=45°", "∠B=70°"]),
    problem("g-quad", "math-geo", number: "12.", body: [[.m("□ABCD"), .t("는 평행사변형이다. "), .m("∠A = 110°"), .t("일 때, "), .m("∠B"), .t("의 크기는?")]],
            choices: degs(["60", "70", "80", "90", "110"]), tokens: ["사각형ABCD", "∠A=110°"]),
    problem("g-arc", "math-geo", number: "13.", body: [[.t("원 O에서 "), .arc("AB"), .t("에 대한 원주각의 크기가 "), .m("30°"), .t("일 때, 중심각의 크기는?")]],
            choices: degs(["15", "30", "45", "60", "90"]), tokens: ["30°"], phrases: ["원주각"]),
    problem("g-pi", "math-geo", number: "14.", body: [[.t("반지름의 길이가 3 cm인 원의 넓이는?")]],
            choices: [[.m("3π cm"), .sup("2")], [.m("6π cm"), .sup("2")], [.m("9π cm"), .sup("2")], [.m("12π cm"), .sup("2")], [.m("18π cm"), .sup("2")]],
            tokens: ["9π"], checkChoices: false),
    problem("g-x-deg", "math-geo", number: "15.", body: [[.t("삼각형의 세 내각의 크기가 "), .m("x°, 2x°, 3x°"), .t("일 때, "), .m("x"), .t("의 값은?")]],
            choices: ints(["20", "30", "40", "45", "60"]), tokens: ["x°,2x°,3x°"]),
    problem("g-area-sin", "math-geo", number: "16.", body: [[.m("△ABC"), .t("에서 "), seg("AB"), .m(" = 8, "), seg("AC"), .m(" = 6, ∠A = 30°"), .t("일 때,")],
                                                             [.m("△ABC"), .t("의 넓이는?")]],
            choices: ints(["10", "12", "16", "20", "24"]), tokens: [segText("AB") + "=8", segText("AC") + "=6", "∠A=30°"]),
    problem("g-de-bc", "math-geo", number: "17.", body: [[.m("△ABC"), .t("에서 "), seg("DE"), .m(" ∥ "), seg("BC"), .t("이고 "), seg("AD"), .m(" = 4, "), seg("DB"), .m(" = 2, "), seg("AE"), .m(" = 6")],
                                                          [.t("일 때, "), seg("EC"), .t("의 길이는?")]],
            choices: ints(["1", "2", "3", "4", "5"]), tokens: [segText("DE") + "∥" + segText("BC"), segText("AD") + "=4", segText("EC") + "의길이"]),
    problem("g-right-c", "math-geo", number: "18.", body: [[.m("∠C = 90°"), .t("인 직각삼각형 ABC에서 "), seg("AB"), .m(" = 13, "), seg("BC"), .m(" = 5")],
                                                            [.t("일 때, "), seg("AC"), .t("의 길이는?")]],
            choices: ints(["8", "10", "11", "12", "14"]), tokens: ["∠C=90°", segText("AB") + "=13", segText("AC") + "의길이"]),
    problem("g-ratio", "math-geo", number: "19.", body: [[.m("△ABC"), .t("에서 "), .m("∠A : ∠B : ∠C = 2 : 3 : 4"), .t("일 때, "), .m("∠C"), .t("의 크기는?")]],
            choices: degs(["40", "60", "80", "90", "100"]), tokens: ["∠A:∠B:∠C=2:3:4"]),
    problem("g-angle-x", "math-geo", number: "20.", body: [[.t("맞꼭지각의 성질을 이용하여 "), .m("∠x + ∠y = 130°"), .t("일 때, "), .m("∠x"), .t("의 크기를 구하시오.")]],
            tokens: ["∠x+∠y=130°"], checkChoices: false),
]
